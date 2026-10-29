<template>
  <div class="modal request-modal" :class="{ open: isOpen }" :aria-hidden="!isOpen">
    <div class="modal-overlay" @click="$emit('close')"></div>
    <section v-if="request" class="modal-content" role="dialog" aria-modal="true" :aria-label="`Request details: ${request.title}`">
      <header class="modal-header">
        <div>
          <div class="modal-id">{{ request.trackingCode || request.id }}</div>
          <h3>{{ request.title }}</h3>
          <div class="modal-meta">{{ request.cat || 'General' }} · {{ request.dept || 'Department not specified' }}</div>
        </div>
        <button class="modal-close" type="button" aria-label="Close request details" @click="$emit('close')">✖</button>
      </header>

      <div class="modal-body request-modal-body">
        <div class="modal-row"><strong>Status</strong><span :class="['tag', request.status]">{{ formatStatus(request.status) }}</span></div>
        <div class="modal-row"><strong>Priority</strong><span>{{ capitalize(request.risk || 'low') }}</span></div>
        <div class="modal-row"><strong>Requested by</strong><span>{{ request.requester || 'Unknown requester' }}</span></div>
        <div class="modal-row"><strong>Assigned personnel</strong><span>{{ request.assignedTo || 'Unassigned' }}</span></div>
        <div class="modal-row"><strong>Date submitted</strong><span>{{ request.date || 'Not recorded' }}</span></div>
        <div v-if="request.completedAt" class="modal-row"><strong>Completed</strong><span>{{ formatDate(request.completedAt) }}</span></div>
        <div v-if="request.verifiedAt" class="modal-row"><strong>Verified</strong><span>{{ formatDate(request.verifiedAt) }}</span></div>
        <section class="request-modal-section">
          <strong>Request details</strong>
          <p>{{ request.details || 'No additional details provided.' }}</p>
        </section>
        <section v-if="request.adminResponse" class="request-modal-section">
          <strong>Administrator response</strong>
          <p>{{ request.adminResponse }}</p>
        </section>
        <section v-if="request.adminRemark" class="request-modal-section">
          <strong>Administrator remark</strong>
          <p>{{ request.adminRemark }}</p>
        </section>
        <section v-if="request.feedback" class="request-modal-section">
          <strong>Employee feedback<span v-if="request.feedbackDate"> · {{ request.feedbackDate }}</span></strong>
          <p>{{ request.feedback }}</p>
        </section>
        <PhotoGallery :attachments="request.photoAttachments || []" :title="request.title" />
        <section v-if="hasAdminAccess(currentRole) && canReviewRequest" class="request-review">
          <strong>Review completed work</strong>
          <p>Verify the personnel’s work or return it for rework with a clear reason.</p>
          <label class="sr-only" :for="`request-rejection-${request.id}`">Reason for rejecting verification</label>
          <textarea
            :id="`request-rejection-${request.id}`"
            v-model="rejectionReason"
            rows="3"
            maxlength="500"
            placeholder="Reason for rework (5–500 characters)"
          ></textarea>
        </section>
      </div>

      <footer class="modal-actions">
        <button class="btn-secondary" type="button" @click="$emit('close')">Close</button>
        <button
          v-if="hasAdminAccess(currentRole)"
          class="btn-primary"
          type="button"
          @click="$emit('assign', request.id)"
        >
          {{ request.assignedTo ? 'Reassign' : 'Assign' }}
        </button>
        <button
          v-if="hasAdminAccess(currentRole) && canReviewRequest"
          class="btn-primary"
          type="button"
          @click="$emit('verify', request.id)"
        >
          Verify & Close
        </button>
        <button
          v-if="hasAdminAccess(currentRole) && canReviewRequest"
          class="btn-secondary request-reject"
          type="button"
          :disabled="rejectionReason.trim().length < 5 || rejectionReason.trim().length > 500"
          @click="rejectVerification"
        >
          Reject & Request Rework
        </button>
      </footer>
    </section>
  </div>
</template>

<script setup>
import { computed, ref, watch } from 'vue';
import PhotoGallery from './PhotoGallery.vue';
import { hasAdminAccess } from '../lib/access.js';

const props = defineProps({
  isOpen: { type: Boolean, default: false },
  request: { type: Object, default: null },
  currentRole: { type: String, default: 'Admin' }
});
defineEmits(['close', 'assign', 'verify', 'reject']);
const rejectionReason = ref('');
const canReviewRequest = computed(() => (
  props.request?.status === 'for-verification'
  && props.request?.techState === 'completed'
));

watch(() => [props.request?.id, props.isOpen], () => {
  rejectionReason.value = '';
});

function rejectVerification() {
  emit('reject', props.request.id, rejectionReason.value.trim());
}

function formatStatus(status) {
  return String(status || 'submitted').replaceAll('-', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase());
}

function capitalize(value) {
  return String(value || '').replace(/\b\w/g, (letter) => letter.toUpperCase());
}

function formatDate(value) {
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? value : date.toLocaleString();
}
</script>

<style scoped>
.request-modal .modal-content { width:min(760px, 96%); }
.request-modal-body { display:block; padding:22px 26px; }
.request-modal-body .modal-row { display:grid; grid-template-columns:minmax(145px, 0.4fr) minmax(0, 1fr); align-items:center; gap:16px; padding:10px 0; border-bottom:1px solid var(--border); }
.request-modal-body .modal-row > strong { color:var(--text-3); font-weight:600; }
.request-modal-body .modal-row > span { min-width:0; overflow-wrap:anywhere; }
.request-modal-section { margin-top:20px; padding:16px; border:1px solid var(--border); border-radius:10px; background:var(--surface-2); }
.request-modal-section > strong { color:var(--text); font-size:13px; }
.request-modal-section p { margin:9px 0 0; color:var(--text-2); font-size:13px; line-height:1.65; white-space:pre-wrap; overflow-wrap:anywhere; }
.request-review { margin-top:20px; padding:16px; border:1px solid var(--border); border-radius:10px; background:var(--surface-2); }
.request-review > strong { font-size:14px; }
.request-review > p { margin:7px 0 12px; color:var(--text-2); font-size:12px; line-height:1.5; }
.request-review textarea { display:block; width:100%; resize:vertical; padding:11px 12px; border:1px solid var(--border-dark); border-radius:8px; background:var(--surface); color:var(--text); font:inherit; font-size:13px; line-height:1.5; }
.request-reject { color:var(--red); }
.sr-only { position:absolute; width:1px; height:1px; overflow:hidden; clip:rect(0,0,0,0); white-space:nowrap; }
@media (max-width:560px) {
  .request-modal-body { padding:18px; }
  .request-modal-body .modal-row { grid-template-columns:1fr; gap:5px; }
}
</style>
