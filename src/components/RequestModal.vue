<template>
  <div class="modal request-modal" :class="{ open: isOpen }" :aria-hidden="!isOpen">
    <div class="modal-overlay" @click="$emit('close')"></div>
    <section v-if="request" class="modal-content" role="dialog" aria-modal="true" :aria-label="`Request details: ${request.title}`">
      <header class="modal-header">
        <div>
          <div class="modal-id">{{ request.id }}</div>
          <h3>{{ request.title }}</h3>
          <div class="modal-meta">{{ request.cat || 'General' }} · {{ request.dept || 'Department not specified' }}</div>
          <div v-if="request.trackingCode" class="modal-tracking-code">Tracking: {{ request.trackingCode }}</div>
        </div>
        <button class="modal-close" type="button" aria-label="Close request details" @click="$emit('close')">✖</button>
      </header>

      <div class="modal-body request-modal-body">
        <div class="modal-row"><strong>Status:</strong><span :class="['tag', request.status]">{{ formatStatus(request.status) }}</span></div>
        <div class="modal-row"><strong>Priority:</strong><span>{{ capitalize(request.risk || 'low') }}</span></div>
        <div class="modal-row"><strong>Requested by:</strong><span>{{ request.requester || 'Unknown requester' }}</span></div>
        <div class="modal-row"><strong>Assigned personnel:</strong><span>{{ request.assignedTo || 'Unassigned' }}</span></div>
        <div class="modal-row"><strong>Date submitted:</strong><span>{{ request.date || 'Not recorded' }}</span></div>
        <div v-if="request.completedAt" class="modal-row"><strong>Completed:</strong><span>{{ formatDate(request.completedAt) }}</span></div>
        <div v-if="request.verifiedAt" class="modal-row"><strong>Verified:</strong><span>{{ formatDate(request.verifiedAt) }}</span></div>
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
      </div>

      <footer class="modal-actions">
        <button class="btn-secondary" type="button" @click="$emit('close')">Close</button>
      </footer>
    </section>
  </div>
</template>

<script setup>
import PhotoGallery from './PhotoGallery.vue';

defineProps({
  isOpen: { type: Boolean, default: false },
  request: { type: Object, default: null }
});
defineEmits(['close']);

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
.request-modal-body { display:block; }
.request-modal-body .modal-row { display:flex; align-items:center; justify-content:space-between; gap:14px; }
.request-modal-section { margin-top:15px; padding:12px; border:1px solid var(--border); border-radius:8px; background:var(--surface-2); }
.request-modal-section > strong { color:var(--text); font-size:13px; }
.request-modal-section p { margin:6px 0 0; color:var(--text-2); font-size:13px; line-height:1.5; white-space:pre-wrap; overflow-wrap:anywhere; }
</style>
