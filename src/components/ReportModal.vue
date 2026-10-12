<template>
  <div id="report-modal" class="modal" :class="{ open: isOpen }" :aria-hidden="!isOpen">
    <div class="modal-overlay" @click="$emit('close')"></div>
    <div class="modal-content" v-if="report">
      <div class="modal-header">
        <div>
          <div class="modal-id">{{ report.trackingCode || report.id }}</div>
          <h3>{{ report.title }}</h3>
          <div class="modal-meta">{{ report.cat }} · {{ report.loc }}</div>
        </div>
        <button class="modal-close" @click="$emit('close')">✖</button>
      </div>

      <div class="modal-body">
        <div class="modal-row">
          <strong>Status:</strong>
          <span :class="['tag', report.status]">{{ formatStatus(report.status) }}</span>
        </div>
        <div class="modal-row">
          <strong>Risk Level:</strong>
          <span :class="['tag', report.risk]">{{ capitalize(report.risk) }}</span>
        </div>
        <div class="modal-row">
          <strong>Assigned Tech:</strong> 
          <span>{{ report.assignedTo || 'Unassigned' }}</span>
        </div>
        <div class="modal-row">
          <strong>Submitted By:</strong> 
          <span>{{ report.reporter || 'Unknown' }}</span>
        </div>
        <div class="modal-row">
          <strong>Date Reported:</strong> 
          <span>{{ report.date }}</span>
        </div>
        <div class="modal-row loc">
          <strong>Location:</strong> 
          <span>{{ report.loc }}</span>
        </div>
        <div class="modal-desc">{{ report.desc || report.description || 'No description provided.' }}</div>
        <section v-if="currentRole === 'Admin' && canAdminResolve" class="verification-review">
          <strong>Review completed work</strong>
          <p>Verify the repair or return it for rework with a clear reason.</p>
          <label class="sr-only" :for="`report-rejection-${report.id}`">Reason for rejecting verification</label>
          <textarea
            :id="`report-rejection-${report.id}`"
            v-model="rejectionReason"
            rows="3"
            maxlength="500"
            placeholder="Reason for rework (5–500 characters)"
          ></textarea>
        </section>
        <div v-if="report.adminRemark" class="admin-remark-note">
          <strong>Administrator remark:</strong>
          <p>{{ report.adminRemark }}</p>
        </div>

        <div v-if="report.photo || report.photoAttachments?.length" class="modal-photo-section">
          <PhotoGallery
            :attachments="report.photoAttachments || []"
            :legacy-photo="report.photo || ''"
            :title="report.title"
          />
        </div>
        <PhotoPicker
          v-if="currentRole === 'Personnel' && isAssignedToCurrentUser && report.techState === 'started'"
          v-model="completionPhotos"
          :max-photos="3"
          label="Required after photos"
          required
          @processing-change="completionPhotosProcessing = $event"
        />

        <section v-if="isOwnCompletedReport" class="report-feedback">
          <strong>Rate this completed work</strong>
          <p v-if="feedbackLoading" class="photo-message">Loading feedback status…</p>
          <p v-else-if="feedbackError" class="photo-message photo-error" role="alert">{{ feedbackError }}</p>
          <p v-else-if="hasFeedbackForReport(report.id)" class="feedback-thanks">Your rating has been recorded. Thank you.</p>
          <template v-else>
            <label class="sr-only" :for="`report-rating-${report.id}`">Rating from 1 to 5</label>
            <select :id="`report-rating-${report.id}`" v-model.number="rating">
              <option :value="0" disabled>Select a rating</option>
              <option v-for="value in 5" :key="value" :value="value">{{ value }} {{ value === 1 ? 'star' : 'stars' }}</option>
            </select>
            <textarea v-model="feedbackComment" maxlength="500" rows="3" placeholder="Optional comment (up to 500 characters)"></textarea>
            <button class="btn-primary" type="button" :disabled="feedbackSubmitting || feedbackLoading" @click="submitFeedback">
              {{ feedbackSubmitting ? 'Submitting…' : 'Submit rating' }}
            </button>
          </template>
        </section>
        <form v-if="canReopenOwnReport" class="report-feedback" @submit.prevent="reopenOwnWorkItem">
          <strong>Reopen this report</strong>
          <p>Available for 7 days after verification. Provide a reason so staff can continue the work.</p>
          <label class="sr-only" :for="`reopen-reason-${report.id}`">Reason for reopening</label>
          <textarea
            :id="`reopen-reason-${report.id}`"
            v-model="reopenReason"
            maxlength="500"
            minlength="5"
            rows="3"
            placeholder="Reason for reopening (5–500 characters)"
            required
          ></textarea>
          <p v-if="reopenError" class="photo-message photo-error" role="alert">{{ reopenError }}</p>
          <p v-if="reopenSucceeded" class="feedback-thanks">Report reopened and returned to In Progress.</p>
          <button class="btn-primary" type="submit" :disabled="reopening || reopenReason.trim().length < 5">
            {{ reopening ? 'Reopening…' : 'Reopen report' }}
          </button>
        </form>
      </div>

      <div class="modal-actions">
        <button class="btn-secondary" @click="$emit('close')">Close</button>

        <!-- Admin Specific Actions -->
        <template v-if="currentRole === 'Admin'">
          <button class="btn-primary" @click="$emit('assign', report.id)">
            {{ report.assignedTo ? 'Reassign' : 'Assign' }}
          </button>
          <button
            v-if="canAdminResolve"
            class="admin-action-btn resolve"
            title="Verify that the personnel work is complete"
            @click="$emit('resolve', report.id)"
          >
            Verify & Close
          </button>
          <button
            v-if="canAdminResolve"
            class="admin-action-btn report-reject"
            :disabled="rejectionReason.trim().length < 5 || rejectionReason.trim().length > 500"
            @click="$emit('reject', report.id, rejectionReason.trim())"
          >
            Reject & Request Rework
          </button>
        </template>

        <!-- Assigned Personnel Lifecycle Actions -->
        <template v-if="currentRole === 'Personnel' && isAssignedToCurrentUser">
          <button
            v-if="report.techState === 'assigned'"
            class="btn-primary"
            @click="$emit('tech-accept', report.id)"
          >
            Accept Job
          </button>
          <button
            v-if="report.techState === 'accepted'"
            class="btn-secondary"
            @click="$emit('tech-start', report.id)"
          >
            Start Work
          </button>
          <button
            v-if="report.techState === 'started'"
            class="admin-action-btn resolve"
            :disabled="completionPhotosProcessing || !completionPhotos.length"
            @click="emit('tech-complete', report.id, completionPhotos)"
          >
            {{ completionPhotosProcessing ? 'Preparing photos…' : 'Submit for Verification' }}
          </button>
          <span
            v-if="report.techState === 'completed'"
            style="font-weight: 700; color: var(--green); margin-left: auto;"
          >
            Job Completed ✅
          </span>
        </template>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed, ref, watch } from 'vue';
import PhotoPicker from './PhotoPicker.vue';
import PhotoGallery from './PhotoGallery.vue';
import { useReportFeedback } from '../composables/useReportFeedback.js';
import { useReports } from '../composables/useReports.js';

const props = defineProps({
  isOpen: {
    type: Boolean,
    default: false
  },
  report: {
    type: Object,
    default: null
  },
  currentRole: {
    type: String,
    default: 'Admin'
  },
  activeUserName: {
    type: String,
    default: ''
  }
});

const { loadReportFeedback, submitReportFeedback, hasFeedbackForReport } = useReportFeedback();
const { reopenOwnReport } = useReports();
const rejectionReason = ref('');
const feedbackLoading = ref(false);
const feedbackSubmitting = ref(false);
const feedbackError = ref('');
const rating = ref(0);
const feedbackComment = ref('');
const reopenReason = ref('');
const reopenError = ref('');
const reopenSucceeded = ref(false);
const reopening = ref(false);
const completionPhotos = ref([]);
const completionPhotosProcessing = ref(false);
const emit = defineEmits([
  'close',
  'assign',
  'resolve',
  'reject',
  'tech-accept',
  'tech-start',
  'tech-complete'
]);

watch(() => [props.report?.id, props.isOpen], () => {
  rejectionReason.value = '';
  completionPhotos.value = [];
  completionPhotosProcessing.value = false;
});

const isOwnCompletedReport = computed(() => Boolean(
  props.report
  && props.report.reporter?.toLowerCase() === props.activeUserName.toLowerCase()
  && ['closed', 'resolved'].includes(props.report.status)
));
const canReopenOwnReport = computed(() => {
  if (props.report?.status !== 'closed' || !props.report?.completedAt) return false;
  const completedAt = new Date(props.report.completedAt).getTime();
  return Number.isFinite(completedAt) && completedAt >= Date.now() - 7 * 24 * 60 * 60 * 1000;
});

async function reopenOwnWorkItem() {
  reopenError.value = '';
  reopenSucceeded.value = false;
  reopening.value = true;
  try {
    if (!await reopenOwnReport(props.report.id, reopenReason.value)) {
      throw new Error('This report is no longer eligible to reopen.');
    }
    reopenReason.value = '';
    reopenSucceeded.value = true;
  } catch (error) {
    reopenError.value = error.message || 'Unable to reopen this report.';
  } finally {
    reopening.value = false;
  }
}

watch(
  () => [props.report?.id, props.isOpen, isOwnCompletedReport.value],
  async ([reportId, isOpen, canFeedback]) => {
    feedbackError.value = '';
    rating.value = 0;
    feedbackComment.value = '';
    reopenReason.value = '';
    reopenError.value = '';
    reopenSucceeded.value = false;
    if (!reportId || !isOpen || !canFeedback) return;
    feedbackLoading.value = true;
    try {
      await loadReportFeedback();
    } catch (error) {
      feedbackError.value = error.message || 'Unable to load feedback status.';
    } finally {
      feedbackLoading.value = false;
    }
  },
  { immediate: true }
);

async function submitFeedback() {
  feedbackError.value = '';
  feedbackSubmitting.value = true;
  try {
    await submitReportFeedback(props.report, rating.value, feedbackComment.value);
  } catch (error) {
    feedbackError.value = error.message || 'Unable to submit feedback.';
  } finally {
    feedbackSubmitting.value = false;
  }
}

const isAssignedToCurrentUser = computed(() => {
  if (!props.report) return false;
  const assigned = Array.isArray(props.report.assignedPersonnel)
    ? props.report.assignedPersonnel
    : (props.report.assignedTo || '').split(',').map((name) => name.trim());
  return assigned.includes(props.activeUserName);
});

const canAdminResolve = computed(() => {
  if (!props.report) return false;
  const hasPersonnel = Array.isArray(props.report.assignedPersonnel)
    ? props.report.assignedPersonnel.length > 0
    : Boolean(props.report.assignedTo);
  return hasPersonnel && props.report.status === 'for-verification' && props.report.techState === 'completed';
});

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
.modal-photo-section {
  margin-top: 14px;
}
.verification-review {
  margin-top: 10px;
  padding: 16px;
  border: 1px solid var(--border);
  border-radius: 10px;
  background: var(--surface-2);
}
.verification-review > strong { font-size: 14px; }
.verification-review > p { margin: 7px 0 12px; color: var(--text-2); font-size: 12px; line-height: 1.5; }
.verification-review textarea {
  display: block;
  width: 100%;
  resize: vertical;
  padding: 11px 12px;
  border: 1px solid var(--border-dark);
  border-radius: 8px;
  background: var(--surface);
  color: var(--text);
  font: inherit;
  font-size: 13px;
  line-height: 1.5;
}
.report-reject { color: var(--red); }
.modal-body > .modal-row {
  display: grid;
  grid-template-columns: minmax(130px, 0.35fr) minmax(0, 1fr);
  align-items: center;
  gap: 14px;
  padding: 9px 0;
  border-bottom: 1px solid var(--border);
}
.modal-body > .modal-row > strong { color: var(--text-3); font-weight: 600; }
.modal-body > .modal-row > span { min-width: 0; overflow-wrap: anywhere; }
.modal-desc {
  margin-top: 8px;
  padding: 16px;
  border-radius: 10px;
  background: var(--surface-2);
  color: var(--text);
  line-height: 1.65;
  white-space: pre-wrap;
  overflow-wrap: anywhere;
}
.modal-tracking-code { margin-top: 4px; color: var(--text-3); font: 700 10px 'DM Mono', monospace; }
.admin-remark-note {
  margin-top: 14px;
  padding: 12px;
  border: 1px solid var(--border, #e2e8f0);
  border-left: 4px solid var(--accent, #f59e0b);
  border-radius: 8px;
  background: var(--surface-2, #f8fafc);
}
.admin-remark-note p { margin: 5px 0 0; white-space: pre-wrap; }
.photo-message { margin-top: 7px; font-size: 11px; color: var(--text-3); }
.photo-error { color: var(--red); }
.report-feedback { margin-top: 16px; padding: 13px; border: 1px solid var(--border); border-radius: 8px; background: var(--surface-2); }
.report-feedback strong { font-size: 13px; }
.report-feedback select, .report-feedback textarea { display: block; width: 100%; margin-top: 9px; padding: 9px; border: 1px solid var(--border-dark); border-radius: 6px; background: var(--surface); color: var(--text); font: inherit; font-size: 12px; }
.report-feedback button { margin-top: 9px; }
.feedback-thanks { margin-top: 8px; color: var(--primary); font-size: 12px; }
.sr-only { position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0,0,0,0); white-space: nowrap; }
@media (max-width: 560px) {
  .modal-body > .modal-row { grid-template-columns: 1fr; gap: 5px; }
}
</style>
