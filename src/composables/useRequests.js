import { ref } from 'vue';
import { useNotifications } from './useNotifications.js';
import { isDemoMode, isSupabaseConfigured, supabase } from '../lib/supabase.js';
import { createDemoTrackingCode } from '../lib/tracking.js';
import { calculateDueAt } from '../lib/sla.js';
import { removeUploadedPhotos, uploadPhotoFiles } from '../lib/photos.js';
import { useSlaSettings } from './useSlaSettings.js';

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
    feedback: '',
    feedbackDate: '',
    assignedTo: '',
    assignedPersonnel: [],
    techState: 'unassigned',
    assignNote: '',
    targetDate: '',
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
    feedback: '',
    feedbackDate: '',
    assignedTo: '',
    assignedPersonnel: [],
    techState: 'unassigned',
    assignNote: '',
    targetDate: '',
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
  return isDemoMode ? initialRequests : [];
}

const requests = ref(loadPersistedRequests());
let requestsChannel = null;

function toDatabaseRequest(request) {
  return {
    id: request.id,
    title: request.title,
    category: request.cat,
    department: request.dept,
    details: request.details,
    requester: request.requester,
    risk: request.risk || 'low',
    priority: request.priority || 'low',
    status: request.status,
    admin_response: request.adminResponse || null,
    admin_remark: request.adminRemark || null,
    action_date: request.actionDate || null,
    feedback: request.feedback || null,
    feedback_date: request.feedbackDate || null,
    assigned_to: request.assignedTo || null,
    assigned_personnel: Array.isArray(request.assignedPersonnel) ? request.assignedPersonnel : [],
    technician_state: request.techState || 'unassigned',
    assignment_note: request.assignNote || null,
    target_date: request.targetDate || null,
    completion_photo: request.completionPhoto || null,
    photo_attachments: request.photoAttachments || [],
    request_date: request.date
  };
}

function syncRequest(request, allowInsert = false) {
  if (!isSupabaseConfigured) return Promise.resolve();
  const payload = toDatabaseRequest(request);
  const query = allowInsert
    ? supabase.from('requests').insert(payload).select('*').single()
    : supabase.from('requests').update(payload).eq('id', request.id);
  return query.then(({ data, error }) => {
    if (error) throw error;
    return data;
  });
}

function syncRequestInBackground(request, allowInsert = false) {
  void syncRequest(request, allowInsert).catch((error) => {
    console.warn('Failed syncing request to Supabase', error);
  });
}

async function loadRequestsFromSupabase() {
  if (!isSupabaseConfigured) return;
  const { data, error } = await supabase.from('requests').select('*').order('created_at', { ascending: false });
  if (error) {
    console.warn('Failed loading requests from Supabase', error);
    return;
  }
  requests.value = (data || []).map((request) => ({
      id: request.id,
      trackingCode: request.tracking_code,
      title: request.title,
      cat: request.category,
      dept: request.department,
      details: request.details,
      requester: request.requester,
      risk: request.risk || 'low',
      priority: request.priority || 'low',
      dueAt: request.due_at || '',
      updatedAt: request.updated_at || request.created_at,
      reviewedAt: request.reviewed_at || '',
      assignedAt: request.assigned_at || '',
      inProgressAt: request.in_progress_at || '',
      completedAt: request.completed_at || '',
      status: request.status,
      adminResponse: request.admin_response || '',
      adminRemark: request.admin_remark || '',
      actionDate: request.action_date || '',
      feedback: request.feedback || '',
      feedbackDate: request.feedback_date || '',
      assignedTo: request.assigned_to || '',
      assignedPersonnel: Array.isArray(request.assigned_personnel) ? request.assigned_personnel : [],
      techState: request.technician_state || 'unassigned',
      assignNote: request.assignment_note || '',
      targetDate: request.target_date || '',
      completionPhoto: request.completion_photo || '',
      photoAttachments: Array.isArray(request.photo_attachments) ? request.photo_attachments : [],
      date: request.request_date
    }));
}

function subscribeToRequests() {
  if (!isSupabaseConfigured || requestsChannel) return;
  requestsChannel = supabase
    .channel('requests-live-updates')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'requests' }, () => {
      void loadRequestsFromSupabase();
    })
    .subscribe((status) => {
      if (status === 'SUBSCRIBED') void loadRequestsFromSupabase();
      if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT') {
        console.warn(`Requests realtime channel status: ${status}`);
        requestsChannel = null;
      }
    });
}

void loadRequestsFromSupabase();

export function useRequests() {
  const { settings: slaSettings } = useSlaSettings();
  function saveRequests() {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(requests.value));
    } catch (e) {
      console.warn('Failed saving requests', e);
    }
  }

  async function addRequest(reqData, photoFiles = []) {
    const nextId = `#REQ-${200 + requests.value.length + 1}`;
    const newReq = {
      id: nextId,
      trackingCode: createDemoTrackingCode(),
      ...reqData,
      risk: reqData.risk || 'low',
      priority: reqData.priority || 'low',
      status: 'submitted',
      adminResponse: '',
      adminRemark: '',
      actionDate: '',
      feedback: '',
      feedbackDate: '',
      assignedTo: '',
      assignedPersonnel: [],
      techState: 'unassigned',
      assignNote: '',
      targetDate: '',
      completionPhoto: '',
      photoAttachments: [],
      date: new Date().toLocaleDateString('en-US', {
        month: 'short',
        day: 'numeric',
        year: 'numeric'
      })
    };
    newReq.dueAt = calculateDueAt(newReq.priority, slaSettings.value);
    if (photoFiles.length) {
      newReq.photoAttachments = await uploadPhotoFiles(photoFiles, {
        entityType: 'requests',
        entityId: newReq.id,
        phase: 'before'
      });
    }
    requests.value.unshift(newReq);
    saveRequests();
    if (!isSupabaseConfigured) return newReq;

    try {
      const saved = await syncRequest(newReq, true);
      Object.assign(newReq, {
        trackingCode: saved.tracking_code,
        dueAt: saved.due_at,
        updatedAt: saved.updated_at
      });
      saveRequests();
      return newReq;
    } catch (error) {
      requests.value = requests.value.filter((request) => request !== newReq);
      saveRequests();
      try {
        await removeUploadedPhotos(newReq.photoAttachments);
      } catch (cleanupError) {
        console.warn('Unable to clean up request photos after submission failed.', cleanupError);
      }
      throw error;
    }
  }

  function acknowledgeRequest(requestId, responseNote) {
    const req = requests.value.find((r) => r.id.toLowerCase() === requestId.toLowerCase());
    if (!req || req.techState !== 'completed') return null;

    req.status = 'action-taken';
    req.adminResponse = responseNote || 'Action taken by Campus Administration.';
    req.actionDate = new Date().toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric'
    });
    saveRequests();
    syncRequestInBackground(req);
    return req;
  }

  function setRequestRisk(requestId, risk) {
    const allowedRisks = ['low', 'medium', 'urgent'];
    if (!allowedRisks.includes(risk)) return null;
    const request = requests.value.find((item) => item.id.toLowerCase() === requestId.toLowerCase());
    if (!request) return null;

    request.risk = risk;
    saveRequests();
    syncRequestInBackground(request);
    return request;
  }

  async function setRequestPriority(requestId, priority) {
    if (!['low', 'medium', 'high', 'urgent'].includes(priority)) return null;
    const request = requests.value.find((item) => item.id.toLowerCase() === requestId.toLowerCase());
    if (!request) return null;
    const previousPriority = request.priority;
    const previousDueAt = request.dueAt;
    request.priority = priority;
    request.dueAt = calculateDueAt(priority, slaSettings.value);
    saveRequests();
    try {
      await syncRequest(request);
    } catch (error) {
      request.priority = previousPriority;
      request.dueAt = previousDueAt;
      saveRequests();
      throw error;
    }
    return request;
  }

  function setRequestRemark(requestId, remark) {
    const request = requests.value.find((item) => item.id.toLowerCase() === requestId.toLowerCase());
    if (!request) return null;
    request.adminRemark = (remark || '').trim();
    saveRequests();
    syncRequestInBackground(request);
    return request;
  }

  function setRequestFeedback(requestId, feedback) {
    const request = requests.value.find((item) => item.id.toLowerCase() === requestId.toLowerCase());
    const trimmedFeedback = (feedback || '').trim();
    if (!request || !trimmedFeedback || request.status !== 'action-taken') return null;

    request.feedback = trimmedFeedback;
    request.feedbackDate = new Date().toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric'
    });
    saveRequests();
    syncRequestInBackground(request);
    return request;
  }

  function assignRequest(requestId, personnel, note = '', targetDate = '') {
    const request = requests.value.find((item) => item.id.toLowerCase() === requestId.toLowerCase());
    if (!request) return null;

    request.assignedPersonnel = [...new Set((Array.isArray(personnel) ? personnel : [personnel]).filter(Boolean))];
    request.assignedTo = request.assignedPersonnel.join(', ');
    request.techState = 'assigned';
    request.assignNote = note;
    request.targetDate = targetDate;
    saveRequests();
    syncRequestInBackground(request);
    return request;
  }

  function isAssignedTo(request, name) {
    const assigned = Array.isArray(request.assignedPersonnel)
      ? request.assignedPersonnel
      : (request.assignedTo || '').split(',').map((item) => item.trim()).filter(Boolean);
    return assigned.includes(name);
  }

  async function requestAccept(requestId, currentPersonnel) {
    const request = requests.value.find((item) => item.id === requestId);
    if (!request || !isAssignedTo(request, currentPersonnel)) return false;
    const previousState = request.techState;
    request.techState = 'accepted';
    saveRequests();
    try {
      await syncRequest(request);
      return true;
    } catch (error) {
      request.techState = previousState;
      saveRequests();
      console.warn('Failed saving request acceptance', error);
      return false;
    }
  }

  async function requestStart(requestId, currentPersonnel) {
    const request = requests.value.find((item) => item.id === requestId);
    if (!request || !isAssignedTo(request, currentPersonnel)) return false;
    const previousState = request.techState;
    request.techState = 'started';
    saveRequests();
    try {
      await syncRequest(request);
      return true;
    } catch (error) {
      request.techState = previousState;
      saveRequests();
      console.warn('Failed saving request start', error);
      return false;
    }
  }

  async function requestComplete(requestId, currentPersonnel, completionPhotos = []) {
    const request = requests.value.find((item) => item.id === requestId);
    if (!request || request.techState !== 'started' || !isAssignedTo(request, currentPersonnel)) return false;
    const previousState = request.techState;
    const previousAttachments = request.photoAttachments || [];
    request.techState = 'completed';
    try {
      if (completionPhotos.length) {
        request.photoAttachments = await uploadPhotoFiles(completionPhotos, {
          entityType: 'requests',
          entityId: request.id,
          phase: 'after',
          previous: previousAttachments
        });
      }
    } catch (error) {
      request.techState = previousState;
      throw error;
    }
    saveRequests();
    try {
      await syncRequest(request);
      return true;
    } catch (error) {
      const newAttachments = request.photoAttachments.filter(
        (attachment) => !previousAttachments.includes(attachment)
      );
      request.techState = previousState;
      request.photoAttachments = previousAttachments;
      saveRequests();
      try {
        await removeUploadedPhotos(newAttachments);
      } catch (cleanupError) {
        console.warn('Unable to clean up request completion photos after saving failed.', cleanupError);
      }
      console.warn('Failed saving request completion', error);
      return false;
    }
  }

  return {
    requests,
    loadRequests: loadRequestsFromSupabase,
    subscribeToRequests,
    addRequest,
    acknowledgeRequest,
    setRequestRisk,
    setRequestPriority,
    setRequestRemark,
    setRequestFeedback,
    assignRequest,
    isAssignedTo,
    requestAccept,
    requestStart,
    requestComplete
  };
}
