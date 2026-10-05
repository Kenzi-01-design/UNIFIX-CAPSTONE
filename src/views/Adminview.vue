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
      <button
        v-if="currentRole === 'Admin'"
        type="button"
        class="admin-tab"
        :class="{ active: activeAdminTab === 'audit' }"
        role="tab"
        :aria-selected="activeAdminTab === 'audit'"
        @click="activeAdminTab = 'audit'"
      >
        Audit Log
      </button>
      <button
        v-if="currentRole === 'Admin'"
        type="button"
        class="admin-tab"
        :class="{ active: activeAdminTab === 'duplicates' }"
        role="tab"
        :aria-selected="activeAdminTab === 'duplicates'"
        @click="activeAdminTab = 'duplicates'"
      >
        Merge Duplicates
      </button>
      <button
        v-if="currentRole === 'Admin'"
        type="button"
        class="admin-tab"
        :class="{ active: activeAdminTab === 'facilities' }"
        role="tab"
        :aria-selected="activeAdminTab === 'facilities'"
        @click="activeAdminTab = 'facilities'"
      >
        Locations & Maintenance
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
                <th>Status</th>
                <th>Assigned To</th>
                <th v-if="['Admin', 'Assistant'].includes(currentRole)">Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="r in orderedReports" :key="r.id" :class="{ 'sla-overdue-row': !['closed', 'resolved'].includes(r.status) && isOverdue(r.dueAt) }">
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
                  <SlaBadge :due-at="r.dueAt" :completed="['closed', 'resolved'].includes(r.status)" />
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
                <td><span :class="['tag', r.status]">{{ formatStatus(r.status) }}</span></td>
                <td style="font-size:12px">
                  <span v-if="r.assignedTo">{{ r.assignedTo }}</span>
                  <span v-else style="color:var(--red);font-weight:700">Unassigned</span>
                </td>
                <td v-if="['Admin', 'Assistant'].includes(currentRole)" class="verification-actions">
                  <button v-if="currentRole === 'Admin' && !['closed', 'resolved', 'action-taken', 'for-verification'].includes(r.status)" class="admin-action-btn assign" @click="pickForAssignment(r.id)">
                    {{ r.assignedTo ? '+ Personnel' : 'Assign' }}
                  </button>
                  <button
                    v-if="r.status === 'for-verification'"
                    class="admin-action-btn resolve"
                    :disabled="!canVerifyReport(r)"
                    @click="handleResolve(r.id)"
                  >
                    Verify & Close
                  </button>
                  <template v-if="r.status === 'for-verification'">
                    <textarea v-model="rejectionReasons[r.id]" rows="2" maxlength="500" placeholder="Reason for rework (required)"></textarea>
                    <button class="admin-action-btn" :disabled="(rejectionReasons[r.id] || '').trim().length < 5" @click="handleRejectReport(r.id)">Reject for Rework</button>
                  </template>
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
                <th v-if="['Admin', 'Assistant'].includes(currentRole)">Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="req in orderedRequests" :key="req.id" :class="{ 'sla-overdue-row': !['closed', 'action-taken'].includes(req.status) && isOverdue(req.dueAt) }">
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
                  <span :class="['tag', req.status]">{{ formatStatus(req.status) }}</span>
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
                  <SlaBadge :due-at="req.dueAt" :completed="['closed', 'action-taken'].includes(req.status)" />
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
                <td v-if="['Admin', 'Assistant'].includes(currentRole)" class="verification-actions">
                  <button class="admin-action-btn assign" @click="openRequestJobOrder(req, 'print')">Print Job Order</button>
                  <button class="admin-action-btn assign" @click="openRequestJobOrder(req, 'pdf')">Download PDF</button>
                  <button v-if="currentRole === 'Admin' && !['closed', 'resolved', 'action-taken', 'for-verification'].includes(req.status)" class="admin-action-btn assign" @click="pickRequestForAssignment(req.id)">
                    {{ req.assignedTo ? 'Reassign' : 'Assign' }}
                  </button>
                  <button
                    v-if="req.status === 'for-verification' && req.techState === 'completed'"
                    class="admin-action-btn resolve"
                    @click="handleAcknowledge(req.id)"
                  >
                    Verify & Close
                  </button>
                  <template v-if="req.status === 'for-verification'">
                    <textarea v-model="rejectionReasons[req.id]" rows="2" maxlength="500" placeholder="Reason for rework (required)"></textarea>
                    <button class="admin-action-btn" :disabled="(rejectionReasons[req.id] || '').trim().length < 5" @click="handleRejectRequest(req.id)">Reject for Rework</button>
                  </template>
                </td>
              </tr>
              <tr v-if="!requests.length">
                <td :colspan="currentRole === 'Admin' ? 10 : 9" style="text-align: center; color: var(--text-3); padding: 24px;">
                  No faculty requests submitted yet.
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
      <div v-if="activeAdminTab === 'audit' && currentRole === 'Admin'" class="panel admin-audit-panel">
        <div class="panel-header">
          <span class="panel-title">Global Audit Log</span>
          <span class="panel-action">Administrative history</span>
        </div>
        <AuditLogPanel global />
      </div>

      <section v-if="activeAdminTab === 'duplicates' && currentRole === 'Admin'" class="panel duplicate-merge-panel">
        <div class="panel-header">
          <span class="panel-title">Merge duplicate open reports</span>
          <span class="panel-action">Merged reports follow the primary report's status</span>
        </div>
        <p class="duplicate-merge-intro">Choose two open reports with the same category and location. The selected secondary report is marked as a duplicate and future status changes follow the primary report.</p>
        <div v-if="!mergeableReports.length" class="facility-empty-state">There are no open reports eligible for merging.</div>
        <form v-else class="duplicate-merge-form" @submit.prevent="mergeReports">
          <label>Primary report
            <select v-model="mergeParentId" required @change="mergeChildId = ''">
              <option value="">Select the report to keep</option>
              <option v-for="report in mergeableReports" :key="report.id" :value="report.id">
                {{ report.id }} · {{ report.title }} · {{ report.loc }}
              </option>
            </select>
          </label>
          <label>Duplicate report
            <select v-model="mergeChildId" required :disabled="!mergeParentId">
              <option value="">Select the duplicate</option>
              <option v-for="report in mergeChildren" :key="report.id" :value="report.id">
                {{ report.id }} · {{ report.title }}
              </option>
            </select>
          </label>
          <button class="btn-primary" type="submit" :disabled="!mergeParentId || !mergeChildId || merging">
            {{ merging ? 'Merging…' : 'Merge selected reports' }}
          </button>
        </form>
        <div v-if="selectedMergeParent" class="duplicate-notes">
          <h3>Reporter votes / notes for {{ selectedMergeParent.id }}<span v-if="!notesLoading"> · {{ duplicateNotes.length }} vote{{ duplicateNotes.length === 1 ? '' : 's' }}</span></h3>
          <p v-if="notesLoading" role="status">Loading reporter notes…</p>
          <p v-else-if="notesError" class="duplicate-merge-error" role="alert">{{ notesError }}</p>
          <p v-else-if="!duplicateNotes.length">No reporter votes have been added to this report.</p>
          <ul v-else>
            <li v-for="(item, index) in duplicateNotes" :key="`${item.created_at}-${index}`">
              <span>{{ item.note || 'Reporter confirmed this is the same issue.' }}</span><small>{{ formatDate(item.created_at) }}</small>
            </li>
          </ul>
        </div>
        <p v-if="mergeError" class="duplicate-merge-error" role="alert">{{ mergeError }}</p>
      </section>

      <FacilitiesMaintenancePanel v-if="activeAdminTab === 'facilities' && currentRole === 'Admin'" />
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed, nextTick, onMounted, watch } from 'vue';
import { useReports } from '../composables/useReports.js';
import { useRequests } from '../composables/useRequests.js';
import { useToast } from '../composables/useToast.js';
import UiIcon from '../components/UiIcon.vue';
import SlaBadge from '../components/SlaBadge.vue';
import SlaSettingsPanel from '../components/SlaSettingsPanel.vue';
import PhotoGallery from '../components/PhotoGallery.vue';
import AuditLogPanel from '../components/AuditLogPanel.vue';
import FacilitiesMaintenancePanel from '../components/FacilitiesMaintenancePanel.vue';
import { useReportFeedback } from '../composables/useReportFeedback.js';
import { isOverdue } from '../lib/sla.js';
import { printJobOrder } from '../lib/jobOrder.js';
import { useDuplicateReports } from '../composables/useDuplicateReports.js';
import { encodeCsv } from '../lib/csv.js';

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
  rejectReport,
  mergeDuplicateReports,
  assignNextInQueue,
  setReportRisk,
  setReportPriority,
  setReportRemark
} = useReports();
const {
  requests,
  acknowledgeRequest,
  rejectRequest,
  setRequestRisk,
  setRequestPriority,
  setRequestRemark,
  assignRequest
} = useRequests();
const { feedback, loading: feedbackLoading, loadError: feedbackLoadError, loadReportFeedback } = useReportFeedback();
const { showToast } = useToast();
const {
  duplicateNotes,
  notesLoading,
  notesError,
  loadDuplicateNotes
} = useDuplicateReports();

const activeAdminTab = ref('reports');
const assignmentPanel = ref(null);
const assignmentIdInput = ref(null);
const rejectionReasons = reactive({});
const mergeParentId = ref('');
const mergeChildId = ref('');
const merging = ref(false);
const mergeError = ref('');

const currentRole = computed(() => props.currentRole);
const mergeableReports = computed(() => reports.value.filter((report) =>
  report.duplicateOf == null || report.duplicateOf === ''
).filter((report) => !['closed', 'resolved', 'action-taken'].includes(report.status)));
const selectedMergeParent = computed(() => mergeableReports.value.find((report) => report.id === mergeParentId.value));
const mergeChildren = computed(() => {
  const parent = selectedMergeParent.value;
  if (!parent) return [];
  return mergeableReports.value.filter((report) =>
    report.id !== parent.id
    && report.cat.toLowerCase() === parent.cat.toLowerCase()
    && report.loc.toLowerCase() === parent.loc.toLowerCase()
  );
});
watch(mergeParentId, (reportId) => {
  void loadDuplicateNotes(reportId).catch(() => {});
});

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
  Number(!['closed', 'resolved'].includes(b.status) && isOverdue(b.dueAt))
  - Number(!['closed', 'resolved'].includes(a.status) && isOverdue(a.dueAt))
));
const orderedRequests = computed(() => [...requests.value].sort((a, b) =>
  Number(!['closed', 'action-taken'].includes(b.status) && isOverdue(b.dueAt))
  - Number(!['closed', 'action-taken'].includes(a.status) && isOverdue(a.dueAt))
));

function handleReportRemark(id, remark) {
  if (currentRole.value !== 'Admin') return;
  if (setReportRemark(id, remark)) showToast(`Remark saved for ${id}.`, 'success');
}

function handleRequestRemark(id, remark) {
  if (currentRole.value !== 'Admin') return;
  if (setRequestRemark(id, remark)) showToast(`Remark saved for ${id}.`, 'success');
}

async function mergeReports() {
  merging.value = true;
  mergeError.value = '';
  try {
    await mergeDuplicateReports(mergeParentId.value, mergeChildId.value);
    mergeParentId.value = '';
    mergeChildId.value = '';
    showToast('Duplicate report merged successfully.', 'success');
  } catch (error) {
    mergeError.value = error.message || 'The reports could not be merged.';
  } finally {
    merging.value = false;
  }
}

function openRequestJobOrder(request, action) {
  try {
    printJobOrder(request, action);
  } catch (error) {
    showToast(error.message || 'The job order could not be opened.', 'error');
  }
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
    .filter((r) => !r.assignedTo && !['closed', 'resolved'].includes(r.status))
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

async function handleResolve(id) {
  try {
    if (await resolveReport(id)) {
      showToast(`${id} verified and closed.`, 'success');
    } else {
      showToast('This report is not awaiting verification.', 'info');
    }
  } catch (error) {
    showToast(error.message || 'Unable to verify this report.', 'error');
  }
}

function canVerifyReport(report) {
  return report?.status === 'for-verification' && report.techState === 'completed';
}

async function handleAcknowledge(id) {
  try {
    const updated = await acknowledgeRequest(id, 'Verified and closed by administration.');
    if (updated) showToast(`${id} verified and closed.`, 'success');
    else showToast('This request is not awaiting verification.', 'info');
  } catch (error) {
    showToast(error.message || 'Unable to verify this request.', 'error');
  }
}

async function handleRejectReport(id) {
  try {
    const rejected = await rejectReport(id, rejectionReasons[id]);
    if (!rejected) {
      showToast('Provide a rework reason of at least 5 characters.', 'error');
      return;
    }
    rejectionReasons[id] = '';
    showToast(`${id} returned for rework.`, 'success');
  } catch (error) {
    showToast(error.message || 'Unable to reject this report for rework.', 'error');
  }
}

async function handleRejectRequest(id) {
  try {
    const rejected = await rejectRequest(id, rejectionReasons[id]);
    if (!rejected) {
      showToast('Provide a rework reason of at least 5 characters.', 'error');
      return;
    }
    rejectionReasons[id] = '';
    showToast(`${id} returned for rework.`, 'success');
  } catch (error) {
    showToast(error.message || 'Unable to reject this request for rework.', 'error');
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
    r.title,
    r.cat,
    r.loc,
    r.risk,
    r.status,
    r.assignedTo || 'Unassigned',
    r.date
  ]);
  const csvContent = encodeCsv([headers, ...rows]);
  const encodedUri = `data:text/csv;charset=utf-8,${encodeURIComponent(csvContent)}`;
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
  return ({
    'in-progress': 'In Progress',
    'for-verification': 'For Verification',
    closed: 'Closed',
    resolved: 'Closed',
    'action-taken': 'Closed'
  })[status] || capitalize(status);
}

function capitalize(str) {
  if (!str) return '';
  return str.charAt(0).toUpperCase() + str.slice(1);
}

function formatDate(value) {
  const date = new Date(value || '');
  return Number.isNaN(date.getTime()) ? 'Date unavailable' : date.toLocaleString();
}
</script>

<style scoped>
.assigned-personnel-list { display: flex; flex-wrap: wrap; gap: 6px; min-height: 30px; margin-bottom: 8px; }
.admin-panel-tabs { overflow-x:auto; }
.admin-panel-tabs .admin-tab { min-width:120px; flex:0 0 auto; }
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
.verification-actions { min-width: 180px; display: flex; flex-direction: column; align-items: stretch; gap: 6px; }
.verification-actions textarea { width: 100%; min-height: 48px; padding: 7px; border: 1px solid var(--border); border-radius: var(--radius-sm); background: var(--surface); color: var(--text); font: inherit; font-size: 11px; }
.duplicate-merge-panel { padding:18px; }
.duplicate-merge-intro { margin-bottom:14px; color:var(--text-2); font-size:13px; }
.duplicate-merge-form { display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:12px; }
.duplicate-merge-form label { display:grid; gap:5px; color:var(--text-2); font-size:12px; font-weight:700; }
.duplicate-merge-form select { width:100%; min-height:40px; padding:8px; border:1px solid var(--border-dark); border-radius:6px; background:var(--surface); color:var(--text); font:inherit; }
.duplicate-merge-form button { grid-column:1/-1; justify-self:start; margin-top:0; }
.duplicate-merge-error { margin-top:10px; color:var(--red); font-size:12px; }
.duplicate-notes { margin-top:18px; padding:14px; border-radius:8px; background:var(--surface-2); }
.duplicate-notes h3 { margin-bottom:8px; font-size:13px; }
.duplicate-notes p,.duplicate-notes small { color:var(--text-3); font-size:12px; }
.duplicate-notes ul { display:grid; gap:8px; list-style:none; }
.duplicate-notes li { display:grid; gap:3px; padding:9px; border:1px solid var(--border); border-radius:6px; background:var(--surface); font-size:12px; }
.facility-empty-state { padding:22px; color:var(--text-3); font-size:13px; text-align:center; }
@media (max-width: 520px) { .personnel-list { grid-template-columns: 1fr; } }
@media(max-width:620px){.duplicate-merge-form{grid-template-columns:1fr}.duplicate-merge-form button{grid-column:auto}}
</style>
