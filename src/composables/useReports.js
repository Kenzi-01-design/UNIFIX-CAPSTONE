import { ref } from 'vue';
import { useNotifications } from './useNotifications.js';
import { isSupabaseConfigured, supabase } from '../lib/supabase.js';

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
    status: 'resolved',
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
    status: 'resolved',
    assignedTo: 'Pedro Reyes',
    techState: 'completed',
    reporter: 'Dormitory Staff',
    date: 'Mar 12, 2026',
    desc: 'Thermostat reset on water heater 2.',
    photo: null
  }
];

const technicians = [
  { name: 'Juan dela Cruz', specialty: 'Electrical' },
  { name: 'Pedro Reyes', specialty: 'Plumbing' },
  { name: 'Ana Torres', specialty: 'HVAC' },
  { name: 'Carlo Mendoza', specialty: 'Network' },
  { name: 'Liza Cruz', specialty: 'Civil' },
  { name: 'Maria Santos', specialty: 'Sanitation' }
];

function loadPersistedReports() {
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
  return initialReports;
}

const reports = ref(loadPersistedReports());

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
    report_date: report.date,
    photo: report.photo || null,
    assignment_note: report.assignNote || null,
    target_date: report.targetDate || null
  };
}

function syncReport(report) {
  if (!isSupabaseConfigured) return;
  supabase.from('reports').upsert(toDatabaseReport(report)).then(({ error }) => {
    if (error) console.warn('Failed syncing report to Supabase', error);
  });
}

async function loadReportsFromSupabase() {
  if (!isSupabaseConfigured) return;
  const { data, error } = await supabase.from('reports').select('*').order('created_at', { ascending: false });
  if (error) {
    console.warn('Failed loading reports from Supabase', error);
    return;
  }
  if (data?.length) {
    reports.value = data.map((report) => ({
      id: report.id,
      title: report.title,
      desc: report.description,
      cat: report.category,
      catIcon: report.category_icon,
      catBg: report.category_background,
      loc: report.location,
      risk: report.risk,
      status: report.status,
      assignedTo: report.assigned_to || '',
      assignedPersonnel: Array.isArray(report.assigned_personnel) ? report.assigned_personnel : [],
      techState: report.technician_state || 'unassigned',
      reporter: report.reporter,
      date: report.report_date,
      photo: report.photo,
      assignNote: report.assignment_note || '',
      targetDate: report.target_date || ''
    }));
  }
}

void loadReportsFromSupabase();

export function useReports() {
  const { pushTechAssignmentNotification } = useNotifications();

  function saveReports() {
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
    if (!report) return technicians[0];
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

  function addReport(newReportData) {
    const nextNumericId = 1040 + reports.value.length + 1;
    const report = {
      id: `#${nextNumericId}`,
      ...newReportData,
      risk: newReportData.risk || 'low',
      status: 'pending',
      assignedTo: '',
      techState: 'unassigned',
      date: new Date().toLocaleDateString('en-US', {
        month: 'short',
        day: 'numeric',
        year: 'numeric'
      })
    };
    reports.value.unshift(report);
    saveReports();
    syncReport(report);
    return report;
  }

  function setReportRisk(reportId, risk) {
    const allowedRisks = ['low', 'medium', 'urgent'];
    if (!allowedRisks.includes(risk)) return null;
    const report = reports.value.find((r) => r.id.toLowerCase() === reportId.toLowerCase());
    if (!report) return null;

    report.risk = risk;
    saveReports();
    syncReport(report);
    return report;
  }

  function assignReport(reportId, techNames, status = 'in-progress', note = '', targetDate = '') {
    const report = reports.value.find((r) => r.id.toLowerCase() === reportId.toLowerCase());
    if (!report) return null;

    report.assignedPersonnel = [...new Set((Array.isArray(techNames) ? techNames : [techNames]).filter(Boolean))];
    syncAssignmentLabel(report);
    report.techState = 'assigned';
    report.status = status;
    report.assignNote = note;
    report.targetDate = targetDate;

    report.assignedPersonnel.forEach((name) => pushTechAssignmentNotification(name, report, status));
    saveReports();
    syncReport(report);
    return report;
  }

  function resolveReport(reportId) {
    const report = reports.value.find((r) => r.id.toLowerCase() === reportId.toLowerCase());
    if (!report) return null;

    report.status = 'resolved';
    report.techState = 'completed';
    if (!normalizePersonnel(report).length) {
      report.assignedPersonnel = [findRecommendedTech(report).name];
      syncAssignmentLabel(report);
    }
    report.assignNote = `Resolved on ${new Date().toLocaleDateString()}`;

    normalizePersonnel(report).forEach((name) => pushTechAssignmentNotification(name, report, 'resolved'));
    saveReports();
    syncReport(report);
    return report;
  }

  function assignNextInQueue() {
    const queue = reports.value
      .filter((r) => !r.assignedTo && r.status !== 'resolved')
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
    top.assignedPersonnel = [recommended.name];
    syncAssignmentLabel(top);
    top.techState = 'assigned';
    if (top.status === 'urgent') top.status = 'in-progress';

    pushTechAssignmentNotification(recommended.name, top, top.status);
    saveReports();
    syncReport(top);
    return { report: top, tech: recommended };
  }

  function techAccept(reportId, currentTechName) {
    const report = reports.value.find((r) => r.id === reportId);
    if (!report || !normalizePersonnel(report).includes(currentTechName)) return false;

    report.techState = 'accepted';
    report.status = 'in-progress';
    saveReports();
    syncReport(report);
    return true;
  }

  function techStart(reportId, currentTechName) {
    const report = reports.value.find((r) => r.id === reportId);
    if (!report || !normalizePersonnel(report).includes(currentTechName)) return false;

    report.techState = 'started';
    report.status = 'in-progress';
    saveReports();
    syncReport(report);
    return true;
  }

  function techComplete(reportId, currentTechName) {
    const report = reports.value.find((r) => r.id === reportId);
    if (!report || !normalizePersonnel(report).includes(currentTechName)) return false;

    report.techState = 'completed';
    report.status = 'resolved';
    saveReports();
    syncReport(report);
    return true;
  }

  return {
    reports,
    technicians,
    getActiveLoad,
    isAssignedTo: (report, name) => normalizePersonnel(report).includes(name),
    findRecommendedTech,
    addReport,
    setReportRisk,
    assignReport,
    resolveReport,
    assignNextInQueue,
    techAccept,
    techStart,
    techComplete
  };
}
