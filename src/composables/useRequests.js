import { ref } from 'vue';
import { useNotifications } from './useNotifications.js';
import { isSupabaseConfigured, supabase } from '../lib/supabase.js';

const STORAGE_KEY = 'unifix-requests-v1';

const initialRequests = [
  {
    id: '#REQ-201',
    title: 'Request for 10 Additional Armchairs',
    cat: 'Furniture',
    dept: 'College of Engineering',
    requester: 'Prof. Reyes',
    details: 'Need 10 additional wooden tablet armchairs for Lecture Hall 1.',
    date: 'Mar 18, 2026',
    status: 'action-taken',
    adminResponse: 'Delivered 10 armchairs from storage depot B.',
    actionDate: 'Mar 19, 2026',
    risk: 'medium'
  },
  {
    id: '#REQ-202',
    title: 'Wall Outlet Installation for Lab 3',
    cat: 'Electrical',
    dept: 'College of Engineering',
    requester: 'Prof. Reyes',
    details: 'Requesting two additional duplex wall sockets along the south workstation row.',
    date: 'Mar 20, 2026',
    status: 'submitted',
    adminResponse: '',
    actionDate: '',
    risk: 'low'
  }
];

function loadPersistedRequests() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) return JSON.parse(raw).map((request) => ({ ...request, risk: request.risk || 'low' }));
  } catch (e) {
    console.warn('Failed loading requests from localStorage', e);
  }
  return initialRequests;
}

const requests = ref(loadPersistedRequests());

function toDatabaseRequest(request) {
  return {
    id: request.id,
    title: request.title,
    category: request.cat,
    department: request.dept,
    details: request.details,
    requester: request.requester,
    risk: request.risk || 'low',
    status: request.status,
    admin_response: request.adminResponse || null,
    action_date: request.actionDate || null,
    request_date: request.date
  };
}

function syncRequest(request) {
  if (!isSupabaseConfigured) return;
  supabase.from('requests').upsert(toDatabaseRequest(request)).then(({ error }) => {
    if (error) console.warn('Failed syncing request to Supabase', error);
  });
}

async function loadRequestsFromSupabase() {
  if (!isSupabaseConfigured) return;
  const { data, error } = await supabase.from('requests').select('*').order('created_at', { ascending: false });
  if (error) {
    console.warn('Failed loading requests from Supabase', error);
    return;
  }
  if (data?.length) {
    requests.value = data.map((request) => ({
      id: request.id,
      title: request.title,
      cat: request.category,
      dept: request.department,
      details: request.details,
      requester: request.requester,
      risk: request.risk || 'low',
      status: request.status,
      adminResponse: request.admin_response || '',
      actionDate: request.action_date || '',
      date: request.request_date
    }));
  }
}

void loadRequestsFromSupabase();

export function useRequests() {
  function saveRequests() {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(requests.value));
    } catch (e) {
      console.warn('Failed saving requests', e);
    }
  }

  function addRequest(reqData) {
    const nextId = `#REQ-${200 + requests.value.length + 1}`;
    const newReq = {
      id: nextId,
      ...reqData,
      risk: reqData.risk || 'low',
      status: 'submitted',
      adminResponse: '',
      actionDate: '',
      date: new Date().toLocaleDateString('en-US', {
        month: 'short',
        day: 'numeric',
        year: 'numeric'
      })
    };
    requests.value.unshift(newReq);
    saveRequests();
    syncRequest(newReq);
    return newReq;
  }

  function acknowledgeRequest(requestId, responseNote) {
    const req = requests.value.find((r) => r.id.toLowerCase() === requestId.toLowerCase());
    if (!req) return null;

    req.status = 'action-taken';
    req.adminResponse = responseNote || 'Action taken by Campus Administration.';
    req.actionDate = new Date().toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric'
    });
    saveRequests();
    syncRequest(req);
    return req;
  }

  function setRequestRisk(requestId, risk) {
    const allowedRisks = ['low', 'medium', 'urgent'];
    if (!allowedRisks.includes(risk)) return null;
    const request = requests.value.find((item) => item.id.toLowerCase() === requestId.toLowerCase());
    if (!request) return null;

    request.risk = risk;
    saveRequests();
    syncRequest(request);
    return request;
  }

  return {
    requests,
    addRequest,
    acknowledgeRequest,
    setRequestRisk
  };
}