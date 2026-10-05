import { ref } from 'vue';
import { useNotifications } from './useNotifications.js';
import { isDemoMode, isSupabaseConfigured, supabase } from '../lib/supabase.js';
import { createDemoTrackingCode } from '../lib/tracking.js';
import { calculateDueAt } from '../lib/sla.js';
import { removeUploadedPhotos, uploadPhotoFiles } from '../lib/photos.js';
import { useSlaSettings } from './useSlaSettings.js';
import { recordDemoAudit } from './useAuditLog.js';
import { canRejectForRework, canSubmitWorkForVerification, canVerifyCompletedWork } from '../lib/workflow.js';
import { validateRequestInput } from '../lib/validation.js';

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
    status: 'closed',
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
    if (raw) return JSON.parse(raw).map((request) => ({
      ...request,
      risk: request.risk || 'low',
      status: request.status === 'action-taken' ? 'closed' : request.status
    }));
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
    requester_email: request.requesterEmail || null,
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
    request_date: request.date,
    rejection_reason: request.rejectionReason || null,
    reopen_reason: request.reopenReason || null,
    rework_count: request.reworkCount || 0
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
      requesterEmail: request.requester_email || '',
      risk: request.risk || 'low',
      priority: request.priority || 'low',
      dueAt: request.due_at || '',
      updatedAt: request.updated_at || request.created_at,
      reviewedAt: request.reviewed_at || '',
      assignedAt: request.assigned_at || '',
      inProgressAt: request.in_progress_at || '',
      completedAt: request.completed_at || '',
      forVerificationAt: request.for_verification_at || '',
      verifiedAt: request.verified_at || '',
      rejectionReason: request.rejection_reason || '',
      reopenReason: request.reopen_reason || '',
      reopenedAt: request.reopened_at || '',
      reworkCount: request.rework_count || 0,
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
  const { pushDemoNotification, pushTechAssignmentNotification } = useNotifications();
  function notifyDemoRequester(request, eventType, title, message) {
    if (isSupabaseConfigured || !request.requester) return;
    pushDemoNotification('Employee', request.requester, {
      eventType,
      title,
      message,
      entityType: 'request',
      entityId: request.id
    });
  }
  function saveRequests() {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(requests.value));
    } catch (e) {
      console.warn('Failed saving requests', e);
    }
  }

  async function addRequest(reqData, photoFiles = []) {
    validateRequestInput(reqData);
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
      requesterEmail: reqData.requesterEmail || '',
      reworkCount: 0,
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
    recordDemoAudit({
      entityType: 'request',
      entityId: newReq.id,
      action: 'created',
      newValue: { status: newReq.status, priority: newReq.priority }
    });
    if (!isSupabaseConfigured) {
      ['Admin', 'Assistant'].forEach((role) => pushDemoNotification(role, role === 'Admin' ? 'Admin User' : 'Admin Assistant', {
        eventType: 'work_received',
        title: 'New request received',
        message: `A new request is ready for review: ${newReq.title}`,
        entityType: 'request',
        entityId: newReq.id
      }));
      return newReq;
    }

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

  async function acknowledgeRequest(requestId, responseNote) {
    const req = requests.value.find((r) => r.id.toLowerCase() === requestId.toLowerCase());
    if (!req || !canVerifyCompletedWork(req)) return null;

    const previousStatus = req.status;
    const previousCompletedAt = req.completedAt;
    const previousAdminResponse = req.adminResponse;
    const previousActionDate = req.actionDate;
    req.status = 'closed';
    req.completedAt = new Date().toISOString();
    req.adminResponse = responseNote || 'Action taken by Campus Administration.';
    req.actionDate = new Date().toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric'
    });
    saveRequests();
    try {
      await syncRequest(req);
      recordDemoAudit({
        entityType: 'request',
        entityId: req.id,
        action: 'status_changed',
        oldValue: { status: previousStatus },
        newValue: { status: 'closed' }
      });
      notifyDemoRequester(req, 'work_completed', 'Request completed', `Your request ${req.id} has been verified and closed.`);
    } catch (error) {
      req.status = previousStatus;
      req.completedAt = previousCompletedAt;
      req.adminResponse = previousAdminResponse;
      req.actionDate = previousActionDate;
      saveRequests();
      throw error;
    }
    return req;
  }

  async function rejectRequest(requestId, reason) {
    const request = requests.value.find((item) => item.id.toLowerCase() === requestId.toLowerCase());
    const safeReason = String(reason || '').trim();
    if (!request || !canRejectForRework(request, safeReason)) return false;
    const previous = {
      status: request.status,
      techState: request.techState,
      rejectionReason: request.rejectionReason,
      reworkCount: request.reworkCount
    };
    request.status = 'in-progress';
    request.techState = 'started';
    request.rejectionReason = safeReason;
    request.reworkCount = (request.reworkCount || 0) + 1;
    saveRequests();
    try {
      await syncRequest(request);
      notifyDemoRequester(request, 'status_changed', 'Rework requested', `Your request ${request.id} was returned for further work.`);
      recordDemoAudit({
        entityType: 'request',
        entityId: request.id,
        action: 'status_changed',
        oldValue: { status: 'for-verification' },
        newValue: { status: 'in-progress', rejection_reason: safeReason }
      });
      return true;
    } catch (error) {
      Object.assign(request, previous);
      saveRequests();
      throw error;
    }
  }

  async function reopenOwnRequest(requestId, reason) {
    const request = requests.value.find((item) => item.id.toLowerCase() === requestId.toLowerCase());
    const safeReason = String(reason || '').trim();
    if (!request || request.status !== 'closed' || safeReason.length < 5 || safeReason.length > 500) return false;
    const completedTime = new Date(request.completedAt || request.updatedAt || '').getTime();
    if (!Number.isFinite(completedTime) || completedTime < Date.now() - 7 * 24 * 60 * 60 * 1000) return false;
    if (isSupabaseConfigured) {
      const { error } = await supabase.rpc('reopen_own_work_item', {
        p_entity_type: 'request',
        p_entity_id: request.id,
        p_reason: safeReason
      });
      if (error) throw error;
    }
    request.status = 'in-progress';
    request.reopenReason = safeReason;
    request.reopenedAt = new Date().toISOString();
    request.reworkCount = (request.reworkCount || 0) + 1;
    recordDemoAudit({
      entityType: 'request',
      entityId: request.id,
      action: 'status_changed',
      oldValue: { status: 'closed' },
      newValue: { status: 'in-progress', reopen_reason: safeReason }
    });
    request.techState = request.assignedPersonnel?.length ? 'assigned' : 'unassigned';
    saveRequests();
    notifyDemoRequester(request, 'status_changed', 'Request reopened', `Your request ${request.id} was reopened for further work.`);
    return true;
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
    recordDemoAudit({
      entityType: 'request',
      entityId: request.id,
      action: 'priority_changed',
      oldValue: { priority: previousPriority },
      newValue: { priority }
    });
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
    if (!request || !trimmedFeedback || request.status !== 'closed') return null;

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

    const previousAssignees = request.assignedPersonnel || [];
    request.assignedPersonnel = [...new Set((Array.isArray(personnel) ? personnel : [personnel]).filter(Boolean))];
    request.assignedTo = request.assignedPersonnel.join(', ');
    request.techState = 'assigned';
    request.assignNote = note;
    request.targetDate = targetDate;
    request.assignedPersonnel.forEach((name) => pushTechAssignmentNotification(name, request, 'assigned'));
    recordDemoAudit({
      entityType: 'request',
      entityId: request.id,
      action: 'assignment_changed',
      oldValue: { assigned_personnel: previousAssignees },
      newValue: { assigned_personnel: request.assignedPersonnel }
    });
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
    const previousStatus = request.status;
    request.techState = 'accepted';
    request.status = 'in-progress';
    saveRequests();
    try {
      await syncRequest(request);
      notifyDemoRequester(request, 'status_changed', 'Request accepted', `Personnel accepted request ${request.id}.`);
      return true;
    } catch (error) {
      request.techState = previousState;
      request.status = previousStatus;
      saveRequests();
      console.warn('Failed saving request acceptance', error);
      return false;
    }
  }

  async function requestStart(requestId, currentPersonnel) {
    const request = requests.value.find((item) => item.id === requestId);
    if (!request || !isAssignedTo(request, currentPersonnel)) return false;
    const previousState = request.techState;
    const previousStatus = request.status;
    request.techState = 'started';
    request.status = 'in-progress';
    saveRequests();
    try {
      await syncRequest(request);
      notifyDemoRequester(request, 'status_changed', 'Request in progress', `Personnel started work on request ${request.id}.`);
      return true;
    } catch (error) {
      request.techState = previousState;
      request.status = previousStatus;
      saveRequests();
      console.warn('Failed saving request start', error);
      return false;
    }
  }

  async function requestComplete(requestId, currentPersonnel, completionPhotos = []) {
    const request = requests.value.find((item) => item.id === requestId);
    if (!request || !canSubmitWorkForVerification(request, currentPersonnel)) return false;
    const previousState = request.techState;
    const previousStatus = request.status;
    const previousAttachments = request.photoAttachments || [];
    request.techState = 'completed';
    request.status = 'for-verification';
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
      request.status = previousStatus;
      throw error;
    }
    saveRequests();
    try {
      await syncRequest(request);
      recordDemoAudit({
        entityType: 'request',
        entityId: request.id,
        action: 'status_changed',
        oldValue: { status: previousStatus },
        newValue: { status: 'for-verification' }
      });
      notifyDemoRequester(request, 'status_changed', 'Request awaiting verification', `Personnel submitted request ${request.id} for verification.`);
      return true;
    } catch (error) {
      const newAttachments = request.photoAttachments.filter(
        (attachment) => !previousAttachments.includes(attachment)
      );
      request.techState = previousState;
      request.status = previousStatus;
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
    rejectRequest,
    reopenOwnRequest,
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
