<template>
  <div class="view active" id="view-admin">
    <div class="admin-toolbar">
      <div v-if="currentRole === 'Admin'" class="admin-toolbar-actions">
        <button class="btn-secondary admin-toolbar-button" @click="exportCSV">
          <UiIcon name="export" :size="16" /> Export CSV
        </button>
        <button class="btn-secondary admin-toolbar-button" @click="generatePrintableReport">
          <UiIcon name="print" :size="16" /> Print Summary Report
        </button>
      </div>
    </div>

    <div class="admin-tabs admin-panel-tabs" role="tablist" aria-label="Admin panel sections">
      <button
        type="button"
        class="admin-tab"
        :class="{ active: activeAdminTab === 'reports' }"
        role="tab"
        :aria-selected="activeAdminTab === 'reports'"
        @click="activeAdminTab = 'reports'"
      >
        All Reports <span class="tab-count">{{ reports.length }}</span>
      </button>
      <button
        type="button"
        class="admin-tab"
        :class="{ active: activeAdminTab === 'requests' }"
        role="tab"
        :aria-selected="activeAdminTab === 'requests'"
        @click="activeAdminTab = 'requests'"
      >
        All Requests <span class="tab-count">{{ requests.length }}</span>
      </button>
      <button
        v-if="currentRole === 'Admin'"
        type="button"
        class="admin-tab"
        :class="{ active: activeAdminTab === 'assignment' }"
        role="tab"
        :aria-selected="activeAdminTab === 'assignment'"
        @click="activeAdminTab = 'assignment'"
      >
        Assign Personnel <span class="tab-count">{{ unassignedQueue.length }}</span>
      </button>
      <button
        v-if="currentRole === 'Admin'"
        type="button"
        class="admin-tab"
        :class="{ active: activeAdminTab === 'sla' }"
        role="tab"
        :aria-selected="activeAdminTab === 'sla'"
        @click="activeAdminTab = 'sla'"
      >
        SLA Settings
      </button>
    </div>

    <div class="admin-grid">
      <!-- 1. Maintenance Reports Table -->
      <div v-if="activeAdminTab === 'reports'" class="report-table-wrap">
        <div class="panel-header">
          <span class="panel-title">{{ currentRole === 'Admin' ? 'All Reports — Manage & Assign' : 'Review Reports' }}</span>
          <div class="admin-panel-header-actions">
            <span class="panel-action">{{ reports.length }} total</span>
          </div>
        </div>
        <div style="overflow-x: auto">
          <table>
            <thead>
              <tr>
                <th>#ID</th>
                <th>Title</th>
                <th>Category</th>
                <th>Location</th>
                <th>Priority / Deadline</th>
                <th>Rating</th>
                <th>Risk</th>
                <th v-if="currentRole !== 'Assistant'">Status</th>
                <th>Assigned To</th>
                <th v-if="currentRole === 'Admin'">Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="r in orderedReports" :key="r.id" :class="{ 'sla-overdue-row': r.status !== 'resolved' && isOverdue(r.dueAt) }">
                <td><span style="font-family:'DM Mono',monospace;font-size:12px;color:var(--text-3)">{{ r.id }}</span></td>
                <td><span style="font-weight:600;font-size:13px">{{ truncate(r.title, 28) }}</span></td>
                <td><UiIcon :name="r.cat" :size="16" /> {{ r.cat }}</td>
                <td style="font-size:12px;color:var(--text-3)">{{ r.loc.split('·')[0] }}</td>
                <td>
                  <select
                    v-if="currentRole === 'Admin'"
                    class="risk-select"
                    :value="r.priority || 'low'"
                    @change="handleReportPriority(r.id, $event.target.value)"
                  >
                    <option value="low">Low</option>
                    <option value="medium">Medium</option>
                    <option value="high">High</option>
                    <option value="urgent">Urgent</option>
                  </select>
                  <span v-else :class="['tag', `priority-${r.priority || 'low'}`]">{{ capitalize(r.priority || 'low') }}</span>
                  <SlaBadge :due-at="r.dueAt" :completed="r.status === 'resolved'" />
                </td>
                <td>{{ formatRating(r.id) }}</td>
                <td>
                  <select
                    v-if="currentRole === 'Admin'"
                    class="risk-select"
                    :value="normalizeRisk(r.risk)"
                    @change="handleReportRisk(r.id, $event.target.value)"
                  >
                    <option value="low">Low</option>
                    <option value="medium">Medium</option>
                    <option value="urgent">Urgent</option>
                  </select>
                  <span v-else :class="['tag', r.risk]">{{ capitalize(r.risk) }}</span>
                </td>
                <td v-if="currentRole !== 'Assistant'"><span :class="['tag', r.status]">{{ formatStatus(r.status) }}</span></td>
                <td style="font-size:12px">
                  <span v-if="r.assignedTo">{{ r.assignedTo }}</span>
                  <span v-else style="color:var(--red);font-weight:700">Unassigned</span>
                </td>
                <td v-if="currentRole === 'Admin'" style="display:flex;gap:6px;flex-wrap:wrap">
                  <button class="admin-action-btn assign" @click="pickForAssignment(r.id)">
                    {{ r.assignedTo ? '+ Personnel' : 'Assign' }}
                  </button>
                  <button
                    class="admin-action-btn resolve"
                    :disabled="!canResolveReport(r)"
                    :title="canResolveReport(r) ? 'Mark report as resolved' : 'Personnel must accept or start this report first'"
                    @click="handleResolve(r.id)"
                  >
                    Resolve
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- 2. Assignment Panel -->
      <div v-if="currentRole === 'Admin' && activeAdminTab === 'assignment'" class="analytics-panel">
        <div ref="assignmentPanel" class="panel">
          <div class="panel-header">
            <span class="panel-title">Assign Personnel</span>
          </div>
          <div style="padding: 18px" class="assign-flow">
            <div class="assign-selected">
              {{ selectedWorkItemLabel }}
            </div>
            <div class="form-group">
              <label>Report ID</label>
              <input ref="assignmentIdInput" type="text" v-model="assignForm.id" placeholder="#1045 or #REQ-201" @input="syncFormWithWorkItem" />
            </div>
            <div class="form-group">
              <label>Assigned Personnel</label>
              <div class="assigned-personnel-list" aria-label="Selected personnel">
                <span v-if="!assignForm.techs.length" class="assigned-personnel-empty">No personnel selected</span>
                <span v-for="name in assignForm.techs" :key="name" class="personnel-chip">
                  {{ name }}
                  <button type="button" :aria-label="`Remove ${name}`" @click="removeTechnician(name)">×</button>
                </span>
              </div>
              <div class="personnel-list" aria-label="Available personnel">
                <button
                  v-for="t in technicians"
                  :key="t.name"
                  type="button"
                  class="personnel-list-item"
                  :class="{ selected: assignForm.techs.includes(t.name) }"
                  @click="toggleTechnician(t.name)"
                >
                  <span><strong>{{ t.name }}</strong><small>{{ t.specialty }} · {{ getActiveLoad(t.name) }} active</small></span>
                  <b>{{ assignForm.techs.includes(t.name) ? '✓' : '+' }}</b>
                </button>
              </div>
            </div>
            <div class="form-group">
              <label>Update Status</label>
              <select v-model="assignForm.status">
                <option value="pending">Pending</option>
                <option value="in-progress">In Progress</option>
                <option value="resolved">Resolved</option>
                <option value="urgent">Urgent</option>
              </select>
            </div>
            <div class="form-group">
              <label>Target Completion Date</label>
              <input type="date" v-model="assignForm.targetDate" />
            </div>
            <div class="form-group">
              <label>Admin Instructions</label>
              <textarea v-model="assignForm.note" placeholder="Add work instructions or priority details..." rows="3"></textarea>
            </div>
            <div class="assign-btns">
              <button class="btn-secondary" style="flex: 1" @click="handleAutoPick">
                Auto-Pick Next
              </button>
              <button class="btn-primary" style="flex: 1; margin-top: 0" @click="handleAssign">
                Assign Ticket
              </button>
            </div>
            <div class="assign-queue-wrap">
              <div class="assign-queue-head">
                <span>Unassigned Queue</span>
                <span>{{ unassignedQueue.length }} open</span>
              </div>
              <div class="assign-queue">
                <template v-if="unassignedQueue.length">
                  <button
                    v-for="q in unassignedQueue"
                    :key="q.id"
                    class="assign-queue-item"
                    @click="pickForAssignment(q.id)"
                  >
                    <strong>{{ q.id }}</strong>
                    <span>{{ q.title }}</span>
                    <em>{{ q.risk.toUpperCase() }} · {{ q.status }}</em>
                  </button>
                </template>
                <div v-else class="assign-queue-empty">
                  All reports currently have assigned technicians.
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <SlaSettingsPanel v-if="currentRole === 'Admin' && activeAdminTab === 'sla'" />

      <!-- 3. Faculty Requisitions & Action Taken Panel -->
      <div v-if="activeAdminTab === 'requests'" class="panel admin-requests-panel">
        <div class="panel-header">
          <span class="panel-title">All Requests</span>
          <span class="panel-action">{{ requests.length }} total</span>
        </div>

        <div style="overflow-x: auto">
          <table>
            <thead>
              <tr>
                <th>#ID</th>
                <th>Faculty</th>
                <th>Category</th>
                <th>Title & Details</th>
                <th>Date</th>
                <th>Status</th>
                <th>Priority / Deadline</th>
                <th>Risk</th>
                <th v-if="currentRole === 'Admin'">Admin Remark</th>
                <th v-if="currentRole === 'Admin'">Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="req in orderedRequests" :key="req.id" :class="{ 'sla-overdue-row': req.techState !== 'completed' && req.status !== 'action-taken' && isOverdue(req.dueAt) }">
                <td>
                  <span style="font-family:'DM Mono',monospace; font-size:12px; color:var(--text-3)">{{ req.id }}</span>
                </td>
                <td>
                  <strong>{{ req.requester }}</strong><br />
                  <small style="color:var(--text-3)">{{ req.dept }}</small>
                </td>
                <td>{{ req.cat }}</td>
                <td>
                  <strong>{{ req.title }}</strong>
                  <div style="font-size: 12px; color: var(--text-2); margin-top: 4px;">{{ req.details }}</div>
                  <PhotoGallery :attachments="req.photoAttachments || []" :title="req.title" />
                </td>
                <td style="font-size: 12px; color: var(--text-3)">{{ req.date }}</td>
                <td>
                  <span :class="['tag', req.status === 'action-taken' ? 'resolved' : 'pending']">
                    {{ req.status === 'action-taken' ? 'Action Taken' : 'Submitted' }}
                  </span>
                </td>
                <td>
                  <select
                    v-if="currentRole === 'Admin'"
                    class="risk-select"
                    :value="req.priority || 'low'"
                    @change="handleRequestPriority(req.id, $event.target.value)"
                  >
                    <option value="low">Low</option>
                    <option value="medium">Medium</option>
                    <option value="high">High</option>
                    <option value="urgent">Urgent</option>
                  </select>
                  <span v-else :class="['tag', `priority-${req.priority || 'low'}`]">{{ capitalize(req.priority || 'low') }}</span>
                  <SlaBadge :due-at="req.dueAt" :completed="req.techState === 'completed' || req.status === 'action-taken'" />
                </td>
                <td>
                  <select
                    v-if="currentRole === 'Admin'"
                    class="risk-select"
                    :value="req.risk || 'low'"
                    @change="handleRequestRisk(req.id, $event.target.value)"
                  >
                    <option value="low">Low</option>
                    <option value="medium">Medium</option>
                    <option value="urgent">Urgent</option>
                  </select>
                  <span v-else :class="['tag', req.risk || 'low']">{{ capitalize(req.risk || 'low') }}</span>
                </td>
                <td v-if="currentRole === 'Admin'" style="min-width: 240px;">
                  <textarea v-model="req.adminRemark" rows="2" maxlength="1000" placeholder="Explain delay or resource issue..." style="width:100%;"></textarea>
                  <button class="admin-action-btn assign" @click="handleRequestRemark(req.id, req.adminRemark)">Save Remark</button>
                </td>
                <td v-if="currentRole === 'Admin'" style="display:flex;gap:6px;flex-wrap:wrap">
                  <button class="admin-action-btn assign" @click="pickRequestForAssignment(req.id)">
                    {{ req.assignedTo ? 'Reassign' : 'Assign' }}
                  </button>
                  <button
                    v-if="req.status !== 'action-taken' && req.techState === 'completed'"
                    class="admin-action-btn resolve"
                    @click="handleAcknowledge(req.id)"
                  >
                    Action Taken
                  </button>
                  <span v-else style="font-weight: 700; color: var(--green); font-size: 12px;">
                    {{ req.status === 'action-taken' ? 'Acknowledged ✅' : 'Awaiting personnel' }}
                  </span>
                </td>
              </tr>
              <tr v-if="!requests.length">
                <td :colspan="currentRole === 'Admin' ? 10 : 8" style="text-align: center; color: var(--text-3); padding: 24px;">
                  No faculty requests submitted yet.
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed, nextTick, onMounted } from 'vue';
import { useReports } from '../composables/useReports.js';
import { useRequests } from '../composables/useRequests.js';
import { useToast } from '../composables/useToast.js';
import UiIcon from '../components/UiIcon.vue';
import SlaBadge from '../components/SlaBadge.vue';
import SlaSettingsPanel from '../components/SlaSettingsPanel.vue';
import PhotoGallery from '../components/PhotoGallery.vue';
import { useReportFeedback } from '../composables/useReportFeedback.js';
import { isOverdue } from '../lib/sla.js';

const props = defineProps({
  currentRole: {
    type: String,
    default: 'Admin'
  }
});

const {
  reports,
  technicians,
  getActiveLoad,
  findRecommendedTech,
  assignReport,
  resolveReport,
  assignNextInQueue,
  setReportRisk,
  setReportPriority,
  setReportRemark
} = useReports();
const { requests, acknowledgeRequest, setRequestRisk, setRequestPriority, setRequestRemark, assignRequest } = useRequests();
const { feedback, loading: feedbackLoading, loadError: feedbackLoadError, loadReportFeedback } = useReportFeedback();
const { showToast } = useToast();

const activeAdminTab = ref('reports');
const assignmentPanel = ref(null);
const assignmentIdInput = ref(null);

const currentRole = computed(() => props.currentRole);

onMounted(() => { void loadReportFeedback(); });

async function focusAssignmentForm() {
  activeAdminTab.value = 'assignment';
  await nextTick();
  assignmentPanel.value?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  setTimeout(() => assignmentIdInput.value?.focus(), 350);
}

function normalizeRisk(risk) {
  return risk === 'high' ? 'urgent' : (risk || 'low');
}

function handleReportRisk(id, risk) {
  if (currentRole.value !== 'Admin') return;
  setReportRisk(id, risk);
  showToast(`${id} risk marked ${capitalize(risk)}.`, 'success');
}

function handleRequestRisk(id, risk) {
  if (currentRole.value !== 'Admin') return;
  setRequestRisk(id, risk);
  showToast(`${id} risk marked ${capitalize(risk)}.`, 'success');
}

async function handleReportPriority(id, priority) {
  if (currentRole.value !== 'Admin') return;
  try {
    const updated = await setReportPriority(id, priority);
    if (updated) showToast(`${id} priority set to ${capitalize(priority)}.`, 'success');
  } catch (error) {
    showToast(error.message || `Unable to update ${id}'s priority.`, 'error');
  }
}

async function handleRequestPriority(id, priority) {
  if (currentRole.value !== 'Admin') return;
  try {
    const updated = await setRequestPriority(id, priority);
    if (updated) showToast(`${id} priority set to ${capitalize(priority)}.`, 'success');
  } catch (error) {
    showToast(error.message || `Unable to update ${id}'s priority.`, 'error');
  }
}

function formatRating(reportId) {
  if (feedbackLoadError.value) return 'Unavailable';
  if (feedbackLoading.value) return 'Loading…';
  const ratings = feedback.value.filter((item) => item.report_id === reportId);
  if (!ratings.length) return 'No ratings';
  const average = ratings.reduce((sum, item) => sum + item.rating, 0) / ratings.length;
  return `${average.toFixed(1)} / 5 (${ratings.length})`;
}

const orderedReports = computed(() => [...reports.value].sort((a, b) =>
  Number(b.status !== 'resolved' && isOverdue(b.dueAt))
  - Number(a.status !== 'resolved' && isOverdue(a.dueAt))
));
const orderedRequests = computed(() => [...requests.value].sort((a, b) =>
  Number(b.techState !== 'completed' && b.status !== 'action-taken' && isOverdue(b.dueAt))
  - Number(a.techState !== 'completed' && a.status !== 'action-taken' && isOverdue(a.dueAt))
));

function handleReportRemark(id, remark) {
  if (currentRole.value !== 'Admin') return;
  if (setReportRemark(id, remark)) showToast(`Remark saved for ${id}.`, 'success');
}

function handleRequestRemark(id, remark) {
  if (currentRole.value !== 'Admin') return;
  if (setRequestRemark(id, remark)) showToast(`Remark saved for ${id}.`, 'success');
}

const assignForm = reactive({
  id: '',
  techs: [],
  status: 'in-progress',
  targetDate: '',
  note: ''
});

const unassignedQueue = computed(() => {
  return reports.value
    .filter((r) => !r.assignedTo && r.status !== 'resolved')
    .sort((a, b) => {
      const riskWeight = { high: 3, medium: 2, low: 1 };
      return (riskWeight[b.risk] || 1) - (riskWeight[a.risk] || 1);
    });
});

const selectedReport = computed(() => {
  return reports.value.find((r) => r.id.toLowerCase() === assignForm.id.trim().toLowerCase());
});

const selectedRequest = computed(() => {
  return requests.value.find((request) => request.id.toLowerCase() === assignForm.id.trim().toLowerCase());
});

const selectedWorkItem = computed(() => selectedReport.value || selectedRequest.value);

const selectedWorkItemLabel = computed(() => {
  if (!selectedWorkItem.value) return 'Select a report or request from the table or queue to begin.';
  return `${selectedWorkItem.value.id} · ${selectedWorkItem.value.title} (${selectedWorkItem.value.cat || 'Request'})`;
});

function pickForAssignment(reportId) {
  activeAdminTab.value = 'assignment';
  assignForm.id = reportId;
  syncFormWithWorkItem();
}

function pickRequestForAssignment(requestId) {
  activeAdminTab.value = 'assignment';
  assignForm.id = requestId;
  syncFormWithWorkItem();
}

function syncFormWithWorkItem() {
  if (selectedReport.value) {
    const recommended = findRecommendedTech(selectedReport.value);
    assignForm.techs = Array.isArray(selectedReport.value.assignedPersonnel)
      ? [...selectedReport.value.assignedPersonnel]
      : (selectedReport.value.assignedTo ? selectedReport.value.assignedTo.split(',').map((name) => name.trim()) : [recommended.name]);
    assignForm.status = selectedReport.value.status === 'pending' ? 'in-progress' : selectedReport.value.status;
    assignForm.note = selectedReport.value.assignNote || '';
    assignForm.targetDate = selectedReport.value.targetDate || '';
  } else if (selectedRequest.value) {
    assignForm.techs = Array.isArray(selectedRequest.value.assignedPersonnel)
      ? [...selectedRequest.value.assignedPersonnel]
      : (selectedRequest.value.assignedTo ? selectedRequest.value.assignedTo.split(',').map((name) => name.trim()) : []);
    assignForm.status = 'in-progress';
    assignForm.note = selectedRequest.value.assignNote || '';
    assignForm.targetDate = selectedRequest.value.targetDate || '';
  }
}

function addTechnician(name) {
  if (!name || assignForm.techs.includes(name)) return;
  assignForm.techs.push(name);
}

function toggleTechnician(name) {
  if (assignForm.techs.includes(name)) {
    removeTechnician(name);
    return;
  }
  addTechnician(name);
}

function removeTechnician(name) {
  assignForm.techs = assignForm.techs.filter((tech) => tech !== name);
}

function handleAssign() {
  if (!assignForm.id.trim()) {
    showToast('Please specify a Report or Request ID.', 'error');
    return;
  }
  if (!assignForm.techs.length) {
    showToast('Add at least one personnel member.', 'error');
    return;
  }
  const updated = selectedReport.value
    ? assignReport(assignForm.id, assignForm.techs, assignForm.status, assignForm.note, assignForm.targetDate)
    : assignRequest(assignForm.id, assignForm.techs, assignForm.note, assignForm.targetDate);
  if (updated) {
    showToast(`${updated.id} assigned to ${assignForm.techs.join(', ')} ✅`, 'success');
  } else {
    showToast('Report or Request ID not found.', 'error');
  }
}

function handleAutoPick() {
  const result = assignNextInQueue();
  if (result) {
    showToast(`${result.report.id} auto-assigned to ${result.tech.name}`, 'success');
  } else {
    showToast('No unassigned reports currently in queue.', 'info');
  }
}

function handleResolve(id) {
  if (resolveReport(id)) {
    showToast(`${id} marked resolved ✅`, 'success');
  } else {
    showToast('Assign personnel and wait for acceptance before resolving this report.', 'info');
  }
}

function canResolveReport(report) {
  return Boolean(report?.assignedTo) && ['accepted', 'started'].includes(report.techState);
}

function handleAcknowledge(id) {
  const updated = acknowledgeRequest(id, 'Action taken by administration.');
  if (updated) {
    showToast(`${id} updated with Action Taken ✅`, 'success');
  } else {
    showToast('Request ID not found.', 'error');
  }
}

function generatePrintableReport() {
  const printWindow = window.open('', '_blank');
  if (!printWindow) {
    showToast('Please enable pop-ups to print reports.', 'error');
    return;
  }
  const rows = reports.value
    .map(
      (r) => `
    <tr>
      <td>${r.id}</td>
      <td>${r.title}</td>
      <td>${r.cat}</td>
      <td>${r.loc}</td>
      <td>${r.risk}</td>
      <td>${r.status}</td>
      <td>${r.assignedTo || 'Unassigned'}</td>
      <td>${r.date}</td>
    </tr>`
    )
    .join('');

  printWindow.document.write(`
    <html>
      <head>
        <title>UNIFIX Maintenance Summary Report</title>
        <style>
          body { font-family: sans-serif; padding: 24px; color: #1e293b; }
          h2 { margin-bottom: 4px; }
          p { color: #64748b; font-size: 13px; margin-top: 0; }
          table { width: 100%; border-collapse: collapse; margin-top: 16px; font-size: 12px; }
          th, td { border: 1px solid #cbd5e1; padding: 8px 12px; text-align: left; }
          th { background: #f1f5f9; }
        </style>
      </head>
      <body>
        <h2>UNIFIX - Campus Maintenance Summary Report</h2>
        <p>Generated on ${new Date().toLocaleString()} · Nueva Vizcaya State University</p>
        <table>
          <thead>
            <tr>
              <th>ID</th><th>Title</th><th>Category</th><th>Location</th><th>Risk</th><th>Status</th><th>Assigned</th><th>Date</th>
            </tr>
          </thead>
          <tbody>${rows}</tbody>
        </table>
      </body>
    </html>
  `);
  printWindow.document.close();
  printWindow.focus();
  setTimeout(() => {
    printWindow.print();
  }, 500);
}

function exportCSV() {
  const headers = ['ID', 'Title', 'Category', 'Location', 'Risk', 'Status', 'Assigned To', 'Date'];
  const rows = reports.value.map((r) => [
    r.id,
    `"${r.title.replace(/"/g, '""')}"`,
    r.cat,
    `"${r.loc.replace(/"/g, '""')}"`,
    r.risk,
    r.status,
    r.assignedTo || 'Unassigned',
    r.date
  ]);
  const csvContent =
    'data:text/csv;charset=utf-8,' +
    [headers.join(','), ...rows.map((e) => e.join(','))].join('\n');
  const encodedUri = encodeURI(csvContent);
  const link = document.createElement('a');
  link.setAttribute('href', encodedUri);
  link.setAttribute('download', `unifix_reports_${new Date().toISOString().slice(0, 10)}.csv`);
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  showToast('Reports CSV exported successfully.', 'success');
}

function truncate(str, len) {
  return str.length > len ? str.slice(0, len) + '…' : str;
}

function formatStatus(status) {
  if (!status) return '';
  return status === 'in-progress' ? 'In Progress' : capitalize(status);
}

function capitalize(str) {
  if (!str) return '';
  return str.charAt(0).toUpperCase() + str.slice(1);
}
</script>

<style scoped>
.assigned-personnel-list { display: flex; flex-wrap: wrap; gap: 6px; min-height: 30px; margin-bottom: 8px; }
.assigned-personnel-empty { color: var(--text-3); font-size: 12px; padding: 6px 0; }
.personnel-chip { display: inline-flex; align-items: center; gap: 5px; padding: 4px 8px; border-radius: 999px; background: #e8f5e9; color: var(--primary); font-size: 12px; font-weight: 700; }
.personnel-chip button { border: 0; background: transparent; color: inherit; font: inherit; font-size: 17px; line-height: 1; cursor: pointer; padding: 0; }
.personnel-list { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px; }
.personnel-list-item { display: flex; align-items: center; justify-content: space-between; gap: 8px; padding: 10px; border: 1px solid var(--border); border-radius: var(--radius-sm); background: var(--surface); color: var(--text); cursor: pointer; text-align: left; }
.personnel-list-item:hover, .personnel-list-item.selected { border-color: var(--primary); background: #f0f9f2; }
.personnel-list-item strong, .personnel-list-item small { display: block; }
.personnel-list-item strong { font-size: 12px; }
.personnel-list-item small { margin-top: 2px; color: var(--text-3); font-size: 11px; }
.personnel-list-item b { display: grid; place-items: center; width: 23px; height: 23px; border-radius: 50%; background: var(--primary); color: #fff; font-size: 17px; }
@media (max-width: 520px) { .personnel-list { grid-template-columns: 1fr; } }
</style>
