import { reactive, ref } from 'vue';
import { useNotifications } from './useNotifications.js';
import { isDemoMode, isSupabaseConfigured, supabase } from '../lib/supabase.js';
import { createDemoTrackingCode } from '../lib/tracking.js';
import { createReportId } from '../lib/requestId.js';
import { removeUploadedPhotos, uploadPhotoFiles } from '../lib/photos.js';
import { canRejectForRework, canSubmitWorkForVerification, canVerifyCompletedWork, isAssignedToPersonnel } from '../lib/workflow.js';
import { validateReportInput } from '../lib/validation.js';

const STORAGE_KEY = 'unifix-reports-v2';

const initialReports = [
  {
    id: '#1048',
    title: 'Flickering lights in Lab 204',
    cat: 'Electrical',
    catIcon: 'Electrical',
    catBg: '#fff4e6',
    loc: 'Engineering Bldg · Fl 2 · Rm 204',
    risk: 'high',
    status: 'urgent',
    assignedTo: '',
    techState: 'unassigned',
    reporter: 'Prof. Reyes',
    date: 'Mar 20, 2026',
    desc: 'Lights flickering rapidly in Lab 204, potential ballast issue.',
    photo: null
  },
  {
    id: '#1047',
    title: 'Leaking pipe near restroom A',
    cat: 'Plumbing',
    catIcon: 'Plumbing',
    catBg: '#e8f5e9',
    loc: 'Main Hall · Ground Floor',
    risk: 'medium',
    status: 'in-progress',
    assignedTo: 'Pedro Reyes',
    techState: 'assigned',
    reporter: 'Juan dela Cruz',
    date: 'Mar 19, 2026',
    desc: 'Puddle accumulating near Restroom A entrance from ceiling pipe.',
    photo: null
  },
  {
    id: '#1046',
    title: 'Broken chair armrest in Room 112',
    cat: 'Furniture',
    catIcon: 'Furniture',
    catBg: '#e8eaf6',
    loc: 'Arts Bldg · Fl 1 · Rm 112',
    risk: 'low',
    status: 'pending',
    assignedTo: '',
    techState: 'unassigned',
    reporter: 'Anna Reyes',
    date: 'Mar 18, 2026',
    desc: 'Wood armrest snapped off desk chair.',
    photo: null
  },
  {
    id: '#1045',
    title: 'AC not cooling in Faculty Office',
    cat: 'HVAC',
    catIcon: 'HVAC',
    catBg: '#fbe9e7',
    loc: 'Science Bldg · Fl 3 · Rm 305',
    risk: 'medium',
    status: 'in-progress',
    assignedTo: 'Ana Torres',
    techState: 'started',
    reporter: 'Prof. Santos',
    date: 'Mar 17, 2026',
    desc: 'Unit blowing room temperature air only.',
    photo: null
  },
  {
    id: '#1044',
    title: 'Projector bulb burned out',
    cat: 'Electrical',
    catIcon: 'Electrical',
    catBg: '#fff4e6',
    loc: 'Main Bldg · Fl 2 · Rm 201',
    risk: 'low',
    status: 'closed',
    assignedTo: 'Juan dela Cruz',
    techState: 'completed',
    reporter: 'Prof. Reyes',
    date: 'Mar 16, 2026',
    desc: 'Replacement bulb installed and tested.',
    photo: null
  },
  {
    id: '#1043',
    title: 'Network switch failure in Library',
    cat: 'Network',
    catIcon: 'Network',
    catBg: '#e3f2fd',
    loc: 'Library · Ground Floor',
    risk: 'high',
    status: 'in-progress',
    assignedTo: 'Carlo Mendoza',
    techState: 'started',
    reporter: 'IT Admin',
    date: 'Mar 15, 2026',
    desc: 'Port 1-12 offline affecting library workstations.',
    photo: null
  },
  {
    id: '#1042',
    title: 'Flooded basement after rain',
    cat: 'Civil',
    catIcon: 'Civil',
    catBg: '#ede7f6',
    loc: 'Science Bldg · Basement',
    risk: 'high',
    status: 'urgent',
    assignedTo: '',
    techState: 'unassigned',
    reporter: 'Security Guard',
    date: 'Mar 14, 2026',
    desc: 'Sump pump failed, 2 inches of standing water.',
    photo: null
  },
  {
    id: '#1041',
    title: 'Broken door lock — Office 402',
    cat: 'Security',
    catIcon: 'Security',
    catBg: '#fce4ec',
    loc: 'Admin Bldg · Fl 4 · Office 402',
    risk: 'medium',
    status: 'pending',
    assignedTo: '',
    techState: 'unassigned',
    reporter: 'Prof. Reyes',
    date: 'Mar 13, 2026',
    desc: 'Key turns completely without engaging bolt.',
    photo: null
  },
  {
    id: '#1040',
    title: 'No hot water in Dormitory A',
    cat: 'Plumbing',
    catIcon: 'Plumbing',
    catBg: '#e8f5e9',
    loc: 'Dormitory A · Fl 1',
    risk: 'medium',
    status: 'closed',
    assignedTo: 'Pedro Reyes',
    techState: 'completed',
    reporter: 'Dormitory Staff',
    date: 'Mar 12, 2026',
    desc: 'Thermostat reset on water heater 2.',
    photo: null
  }
];

const DEMO_TECHNICIANS = [
  { name: 'Juan dela Cruz', specialty: 'Electrical' },
  { name: 'Pedro Reyes', specialty: 'Plumbing' },
  { name: 'Ana Torres', specialty: 'HVAC' },
  { name: 'Carlo Mendoza', specialty: 'Network' },
  { name: 'Liza Cruz', specialty: 'Civil' },
  { name: 'Maria Santos', specialty: 'Sanitation' }
];
const technicians = reactive(DEMO_TECHNICIANS.map((technician) => ({ ...technician })));

function loadPersistedReports() {
  if (isSupabaseConfigured) return [];
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) {
      const parsed = JSON.parse(raw);
      return parsed.map((r) => ({
        ...r,
        techState: r.techState || (r.assignedTo ? 'assigned' : 'unassigned')
      }));
    }
  } catch (e) {
    console.warn('Failed loading reports from localStorage', e);
  }
  return isDemoMode ? initialReports : [];
}

const reports = ref(loadPersistedReports());
let reportsChannel = null;
let reportsLoadGeneration = 0;
let reportsSubscriptionWanted = false;
let reportsRetryTimer = null;
let reportsRetryAttempt = 0;

function stopReportsSubscription() {
  reportsSubscriptionWanted = false;
  reportsRetryAttempt = 0;
  if (reportsRetryTimer) {
    clearTimeout(reportsRetryTimer);
    reportsRetryTimer = null;
  }
  if (reportsChannel) {
    const channel = reportsChannel;
    reportsChannel = null;
    void supabase.removeChannel(channel).catch((error) => {
      console.error('Could not stop the reports realtime subscription.', error);
    });
  }
}

function clearReportsForAccountChange() {
  reportsLoadGeneration += 1;
  reports.value = [];
  if (isSupabaseConfigured) {
    try {
      localStorage.removeItem(STORAGE_KEY);
    } catch (error) {
      console.warn('Could not clear cached reports for the previous account.', error);
    }
  }
}

function normalizePersonnel(report) {
  if (Array.isArray(report.assignedPersonnel)) return report.assignedPersonnel;
  return report.assignedTo ? report.assignedTo.split(',').map((name) => name.trim()).filter(Boolean) : [];
}

function syncAssignmentLabel(report) {
  report.assignedPersonnel = [...new Set(normalizePersonnel(report))];
  report.assignedTo = report.assignedPersonnel.join(', ');
}

function toDatabaseReport(report) {
  return {
    id: report.id,
    title: report.title,
    description: report.desc || '',
    category: report.cat,
    category_icon: report.catIcon || null,
    category_background: report.catBg || null,
    location: report.loc,
    risk: report.risk || 'low',
    status: report.status,
    assigned_to: report.assignedTo || null,
    assigned_personnel: normalizePersonnel(report),
    technician_state: report.techState || 'unassigned',
    reporter: report.reporter,
    reporter_email: report.reporterEmail || null,
    report_date: report.date,
    photo: report.photo || null,
    photo_attachments: report.photoAttachments || [],
    assignment_note: report.assignNote || null,
    target_date: report.targetDate || null,
    admin_remark: report.adminRemark || null,
    rejection_reason: report.rejectionReason || null,
    reopen_reason: report.reopenReason || null,
    rework_count: report.reworkCount || 0
  };
}

function syncReport(report, allowInsert = false) {
  if ((!isSupabaseConfigured || isDemoMode) && report.duplicateOf == null) {
    reports.value
      .filter((child) => child.duplicateOf === report.id)
      .forEach((child) => { child.status = report.status; });
  }
  if (!isSupabaseConfigured) return Promise.resolve();
  const payload = toDatabaseReport(report);
  const query = allowInsert
    ? supabase.from('reports').insert(payload).select('*').single()
    : supabase.from('reports').update(payload).eq('id', report.id).select('id').maybeSingle();
  return query.then(({ data, error }) => {
    if (error) throw error;
    if (!allowInsert && !data) {
      throw new Error('The report was not updated. Check that your account can manage this report.');
    }
    return data;
  });
}

function syncReportInBackground(report, allowInsert = false) {
  void syncReport(report, allowInsert).catch((error) => {
    console.warn('Failed syncing report to Supabase', error);
  });
}

async function loadReportsFromSupabase() {
  const generation = ++reportsLoadGeneration;
  if (!isSupabaseConfigured) {
    reports.value = loadPersistedReports();
    return;
  }
  const { data, error } = await supabase.from('reports').select('*').order('created_at', { ascending: false });
  if (generation !== reportsLoadGeneration) return;
  if (error) {
    console.warn('Failed loading reports from Supabase', error);
    reports.value = [];
    throw error;
  }
  reports.value = (data || []).map((report) => ({
      id: report.id,
      trackingCode: report.tracking_code,
      title: report.title,
      desc: report.description,
      cat: report.category,
      catIcon: report.category_icon,
      catBg: report.category_background,
      loc: report.location,
      risk: report.risk,
      updatedAt: report.updated_at || report.created_at,
      reviewedAt: report.reviewed_at || '',
      assignedAt: report.assigned_at || '',
      inProgressAt: report.in_progress_at || '',
      completedAt: report.completed_at || '',
      forVerificationAt: report.for_verification_at || '',
      verifiedAt: report.verified_at || '',
      rejectionReason: report.rejection_reason || '',
      reopenReason: report.reopen_reason || '',
      reopenedAt: report.reopened_at || '',
      reworkCount: report.rework_count || 0,
      status: report.status,
      duplicateOf: report.duplicate_of || '',
      assignedTo: report.assigned_to || '',
      assignedPersonnel: Array.isArray(report.assigned_personnel) ? report.assigned_personnel : [],
      techState: report.technician_state || 'unassigned',
      reporter: report.reporter,
      reporterEmail: report.reporter_email || '',
      date: report.report_date,
      photo: report.photo,
      photoAttachments: Array.isArray(report.photo_attachments) ? report.photo_attachments : [],
      assignNote: report.assignment_note || '',
      targetDate: report.target_date || '',
      adminRemark: report.admin_remark || ''
    }));
}

function scheduleReportsRetry() {
  if (!reportsSubscriptionWanted || reportsRetryTimer) return;
  const delay = Math.min(1000 * (2 ** reportsRetryAttempt), 30_000);
  reportsRetryAttempt += 1;
  reportsRetryTimer = setTimeout(() => {
    reportsRetryTimer = null;
    subscribeToReports();
  }, delay);
}

function subscribeToReports() {
  reportsSubscriptionWanted = true;
  if (!isSupabaseConfigured || reportsChannel) return;
  const channel = supabase
    .channel('reports-live-updates')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'reports' }, () => {
      void loadReportsFromSupabase().catch((error) => {
        console.error('Could not refresh reports after a realtime update.', error);
      });
    })
    .subscribe((status) => {
      if (status === 'SUBSCRIBED') {
        reportsRetryAttempt = 0;
        void loadReportsFromSupabase().catch((error) => {
          console.error('Could not load reports after subscribing to updates.', error);
        });
      }
      if (['CHANNEL_ERROR', 'TIMED_OUT', 'CLOSED'].includes(status)) {
        console.error(`Reports realtime subscription lost: ${status}. Reconnecting.`);
        if (reportsChannel === channel) reportsChannel = null;
        void supabase.removeChannel(channel).catch((error) => {
          console.error('Could not remove the failed reports realtime channel.', error);
        });
        scheduleReportsRetry();
      }
    });
  reportsChannel = channel;
}

void loadReportsFromSupabase().catch((error) => {
  console.error('Could not load reports from Supabase.', error);
});

export function useReports() {
  const { pushTechAssignmentNotification, pushDemoNotification } = useNotifications();
  function notifyDemoReporter(report, eventType, title, message) {
    if (isSupabaseConfigured || !report.reporter || report.reporter === 'Public Reporter') return;
    pushDemoNotification('Employee', report.reporter, {
      eventType,
      title,
      message,
      entityType: 'report',
      entityId: report.id
    });
  }

  async function loadTechnicians() {
    if (!isSupabaseConfigured) return technicians;
    const { data, error } = await supabase
      .from('user_profiles')
      .select('name, department')
      .eq('role', 'Personnel')
      .eq('is_active', true)
      .order('name', { ascending: true });
    if (error) throw error;
    technicians.splice(
      0,
      technicians.length,
      ...(data || []).map((profile) => ({
        name: profile.name,
        specialty: profile.department || 'Maintenance'
      }))
    );
    return technicians;
  }

  function saveReports() {
      if (isSupabaseConfigured) return;
      try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(reports.value));
    } catch (e) {
      console.warn('Failed saving reports to localStorage', e);
    }
  }

  function getActiveLoad(techName) {
    return reports.value.filter(
      (r) => normalizePersonnel(r).includes(techName) && r.status !== 'resolved'
    ).length;
  }

  function findRecommendedTech(report) {
    if (!report || !technicians.length) return technicians[0] || null;
    const ranked = [...technicians]
      .map((tech) => {
        const specialtyMatch = report.cat
          ? report.cat.toLowerCase().includes(tech.specialty.toLowerCase())
          : false;
        const load = getActiveLoad(tech.name);
        return {
          tech,
          score: (specialtyMatch ? 100 : 0) - load * 10
        };
      })
      .sort((a, b) => b.score - a.score);
    return ranked[0].tech;
  }

  async function addReport(newReportData, photoFiles = []) {
    validateReportInput(newReportData);
    if (!photoFiles.length) throw new Error('Attach at least one photo before submitting the report.');
    const report = {
      ...newReportData,
      id: createReportId(),
      trackingCode: createDemoTrackingCode(),
      risk: newReportData.risk || 'low',
      status: 'pending',
      assignedTo: '',
      techState: 'unassigned',
      photoAttachments: [],
      date: new Date().toLocaleDateString('en-US', {
        month: 'short',
        day: 'numeric',
        year: 'numeric'
      })
    };
    if (photoFiles.length) {
      report.photoAttachments = await uploadPhotoFiles(photoFiles, {
        entityType: 'reports',
        entityId: report.id,
        phase: 'before'
      });
    }
    reports.value.unshift(report);
    saveReports();
    if (!isSupabaseConfigured) {
      ['Admin', 'Assistant'].forEach((role) => pushDemoNotification(role, role === 'Admin' ? 'Admin User' : 'Admin Assistant', {
        eventType: 'work_received',
        title: 'New report received',
        message: `A new report is ready for review: ${report.title}`,
        entityType: 'report',
        entityId: report.id
      }));
      return report;
    }

    try {
      const saved = await syncReport(report, true);
      Object.assign(report, {
        trackingCode: saved.tracking_code,
        updatedAt: saved.updated_at
      });
      saveReports();
      return report;
    } catch (error) {
      reports.value = reports.value.filter((item) => item !== report);
      saveReports();
      try {
        await removeUploadedPhotos(report.photoAttachments);
      } catch (cleanupError) {
        console.warn('Unable to clean up report photos after submission failed.', cleanupError);
      }
      throw error;
    }
  }

  async function mergeDuplicateReports(parentId, childId) {
    if (isSupabaseConfigured && !isDemoMode) {
      const { error } = await supabase.rpc('merge_duplicate_reports', {
        p_parent_id: parentId,
        p_child_id: childId
      });
      if (error) throw error;
      await loadReportsFromSupabase();
      return true;
    }
    const parent = reports.value.find((report) => report.id === parentId);
    const child = reports.value.find((report) => report.id === childId);
    if (!parent || !child || parent === child || parent.duplicateOf || child.duplicateOf
        || parent.cat.toLowerCase() !== child.cat.toLowerCase()
        || parent.loc.toLowerCase() !== child.loc.toLowerCase()
        || ['closed', 'resolved', 'action-taken'].includes(parent.status)
        || ['closed', 'resolved', 'action-taken'].includes(child.status)) {
      throw new Error('Choose two open reports with the same category and location.');
    }
    const previousStatus = child.status;
    child.duplicateOf = parent.id;
    child.status = 'resolved';
    saveReports();
    return true;
  }

  function setReportRisk(reportId, risk) {
    const allowedRisks = ['low', 'medium', 'urgent'];
    if (!allowedRisks.includes(risk)) return null;
    const report = reports.value.find((r) => r.id.toLowerCase() === reportId.toLowerCase());
    if (!report) return null;

    report.risk = risk;
    saveReports();
    syncReportInBackground(report);
    return report;
  }

  function setReportRemark(reportId, remark) {
    const report = reports.value.find((r) => r.id.toLowerCase() === reportId.toLowerCase());
    if (!report) return null;
    report.adminRemark = (remark || '').trim();
    saveReports();
    syncReportInBackground(report);
    return report;
  }

  async function assignReport(reportId, techNames, status = 'in-progress', note = '', targetDate = '') {
    const report = reports.value.find((r) => r.id.toLowerCase() === reportId.toLowerCase());
    if (!report || ['closed', 'resolved', 'action-taken', 'for-verification'].includes(report.status)) return null;

    const previousAssignees = normalizePersonnel(report);
    const previous = {
      assignedPersonnel: [...previousAssignees],
      assignedTo: report.assignedTo,
      techState: report.techState,
      status: report.status,
      assignNote: report.assignNote,
      targetDate: report.targetDate
    };
    report.assignedPersonnel = [...new Set((Array.isArray(techNames) ? techNames : [techNames]).filter(Boolean))];
    syncAssignmentLabel(report);
    report.techState = 'assigned';
    report.status = status;
    report.assignNote = note;
    report.targetDate = targetDate;
    saveReports();
    try {
      await syncReport(report);
    } catch (error) {
      Object.assign(report, previous);
      saveReports();
      throw error;
    }
    report.assignedPersonnel.forEach((name) => pushTechAssignmentNotification(name, report, report.status));
    return report;
  }

  async function resolveReport(reportId) {
    const report = reports.value.find((r) => r.id.toLowerCase() === reportId.toLowerCase());
    if (!report || !canVerifyCompletedWork(report)) return false;
    const previous = {
      status: report.status,
      completedAt: report.completedAt,
      verifiedAt: report.verifiedAt,
      assignNote: report.assignNote
    };
    report.status = 'closed';
    report.techState = 'completed';
    report.completedAt = new Date().toISOString();
    report.verifiedAt = new Date().toISOString();
    report.assignNote = `Verified and closed on ${new Date().toLocaleDateString()}`;
    saveReports();
    try {
      await syncReport(report);
      notifyDemoReporter(report, 'work_completed', 'Report completed', `Your report ${report.id} has been verified and closed.`);
      normalizePersonnel(report).forEach((name) => pushTechAssignmentNotification(name, report, 'closed'));
      return true;
    } catch (error) {
      Object.assign(report, previous);
      saveReports();
      throw error;
    }
  }

  async function rejectReport(reportId, reason) {
    const report = reports.value.find((item) => item.id.toLowerCase() === reportId.toLowerCase());
    const safeReason = String(reason || '').trim();
    if (!report || !canRejectForRework(report, safeReason)) return false;
    const previous = {
      status: report.status,
      techState: report.techState,
      rejectionReason: report.rejectionReason,
      reworkCount: report.reworkCount
    };
    report.status = 'in-progress';
    report.techState = 'started';
    report.rejectionReason = safeReason;
    report.reworkCount = (report.reworkCount || 0) + 1;
    saveReports();
    try {
      await syncReport(report);
      notifyDemoReporter(report, 'status_changed', 'Rework requested', `Your report ${report.id} was returned for further work.`);
      return true;
    } catch (error) {
      Object.assign(report, previous);
      saveReports();
      throw error;
    }
  }

  async function reopenOwnReport(reportId, reason) {
    const report = reports.value.find((item) => item.id.toLowerCase() === reportId.toLowerCase());
    const safeReason = String(reason || '').trim();
    if (!report || report.status !== 'closed' || safeReason.length < 5 || safeReason.length > 500) return false;
    const completedTime = new Date(report.completedAt || report.updatedAt || '').getTime();
    if (!Number.isFinite(completedTime) || completedTime < Date.now() - 7 * 24 * 60 * 60 * 1000) return false;
    if (isSupabaseConfigured) {
      const { error } = await supabase.rpc('reopen_own_work_item', {
        p_entity_type: 'report',
        p_entity_id: report.id,
        p_reason: safeReason
      });
      if (error) throw error;
    }
    report.status = 'in-progress';
    report.reopenReason = safeReason;
    report.reopenedAt = new Date().toISOString();
    report.reworkCount = (report.reworkCount || 0) + 1;
    report.techState = normalizePersonnel(report).length ? 'assigned' : 'unassigned';
    saveReports();
    notifyDemoReporter(report, 'status_changed', 'Report reopened', `Your report ${report.id} was reopened for further work.`);
    return true;
  }

  async function assignNextInQueue() {
    const queue = reports.value
      .filter((r) => !r.assignedTo && !['closed', 'resolved'].includes(r.status))
      .sort((a, b) => {
        const riskWeight = { high: 3, medium: 2, low: 1 };
        const statusWeight = { urgent: 3, 'in-progress': 2, pending: 1 };
        const aScore = (riskWeight[a.risk] || 1) + (statusWeight[a.status] || 0);
        const bScore = (riskWeight[b.risk] || 1) + (statusWeight[b.status] || 0);
        return bScore - aScore;
      });

    if (!queue.length) return null;

    const top = queue[0];
    const recommended = findRecommendedTech(top);
    const status = top.status === 'urgent' ? 'in-progress' : top.status;
    const report = await assignReport(top.id, [recommended.name], status, top.assignNote, top.targetDate);
    return report ? { report, tech: recommended } : null;
  }

  async function techAccept(reportId, currentTechName) {
    const report = reports.value.find((r) => r.id === reportId);
    if (!report || !isAssignedToPersonnel(report, currentTechName)) return false;

    const previousState = report.techState;
    const previousStatus = report.status;
    report.techState = 'accepted';
    report.status = 'in-progress';
    saveReports();
    try {
      await syncReport(report);
      return true;
    } catch (error) {
      report.techState = previousState;
      report.status = previousStatus;
      saveReports();
      throw error;
    }
  }

  async function techStart(reportId, currentTechName) {
    const report = reports.value.find((r) => r.id === reportId);
    if (!report || !isAssignedToPersonnel(report, currentTechName)) return false;

    const previousState = report.techState;
    const previousStatus = report.status;
    report.techState = 'started';
    report.status = 'in-progress';
    saveReports();
    try {
      await syncReport(report);
      return true;
    } catch (error) {
      report.techState = previousState;
      report.status = previousStatus;
      saveReports();
      console.warn('Failed saving report start', error);
      return false;
    }
  }

  async function techComplete(reportId, currentTechName, completionPhotos = []) {
    const report = reports.value.find((r) => r.id === reportId);
    if (!report || !canSubmitWorkForVerification(report, currentTechName)) return false;
    if (!completionPhotos.length) throw new Error('Attach at least one after photo before submitting the report for verification.');

    const previousState = report.techState;
    const previousStatus = report.status;
    const previousAttachments = report.photoAttachments || [];
    report.techState = 'completed';
    report.status = 'for-verification';
    try {
      report.photoAttachments = await uploadPhotoFiles(completionPhotos, {
        entityType: 'reports',
        entityId: report.id,
        phase: 'after',
        previous: previousAttachments
      });
    } catch (error) {
      report.techState = previousState;
      report.status = previousStatus;
      throw error;
    }
    saveReports();
    try {
      await syncReport(report);
      notifyDemoReporter(report, 'status_changed', 'Report awaiting verification', `Personnel submitted report ${report.id} for verification.`);
      return true;
    } catch (error) {
      const newAttachments = report.photoAttachments.filter(
        (attachment) => !previousAttachments.includes(attachment)
      );
      report.techState = previousState;
      report.status = previousStatus;
      report.photoAttachments = previousAttachments;
      saveReports();
      try {
        await removeUploadedPhotos(newAttachments);
      } catch (cleanupError) {
        console.warn('Unable to clean up report completion photos after saving failed.', cleanupError);
      }
      console.warn('Failed saving report completion', error);
      return false;
    }
  }

  return {
    reports,
    technicians,
    loadReports: loadReportsFromSupabase,
    loadTechnicians,
    subscribeToReports,
    stopReportsSubscription,
    clearReportsForAccountChange,
    getActiveLoad,
    isAssignedTo: isAssignedToPersonnel,
    findRecommendedTech,
    addReport,
    mergeDuplicateReports,
    setReportRisk,
    setReportRemark,
    assignReport,
    resolveReport,
    assignNextInQueue,
    rejectReport,
    reopenOwnReport,
    techAccept,
    techStart,
    techComplete
  };
}
