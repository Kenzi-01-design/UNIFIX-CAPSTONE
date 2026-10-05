<template>
  <div class="view active" id="view-my-requisitions">
    <div class="panel requisitions-panel">
      <div class="panel-header">
        <span class="panel-title">Requestitions</span>
        <span class="panel-action">{{ myRequests.length }} records</span>
      </div>

      <div class="requisitions-content">
        <template v-if="myRequests.length">
          <div v-for="req in myRequests" :key="req.id" class="report-card requisition-card">
            <div class="rc-top">
              <span class="request-id">{{ req.id }}</span>
              <span :class="['tag', req.status]">{{ formatStatus(req.status) }}</span>
            </div>
            <div class="job-order-actions">
              <button class="btn-secondary" type="button" :disabled="!isJobOrderVerified(req)" @click="openJobOrder(req, 'print')">Print job order</button>
              <button class="btn-secondary" type="button" :disabled="!isJobOrderVerified(req)" @click="openJobOrder(req, 'pdf')">Download PDF</button>
            </div>
            <p v-if="!isJobOrderVerified(req)" class="job-order-hint">Available after the request is verified and closed.</p>
            <div class="rc-title">{{ req.title }}</div>
            <div class="request-meta">{{ req.dept }} · {{ req.date }}</div>
            <p class="request-details">{{ req.details }}</p>
            <PhotoGallery :attachments="req.photoAttachments || []" :title="req.title" />

            <div v-if="req.adminRemark" class="admin-acknowledgment">
              <strong>Administrator remark:</strong>
              <div>{{ req.adminRemark }}</div>
            </div>

            <div v-if="req.status === 'closed'" class="admin-acknowledgment">
              <strong>Admin Acknowledgment ({{ req.actionDate }}):</strong>
              <div>{{ req.adminResponse }}</div>
            </div>

            <div v-if="req.status === 'closed'" class="request-feedback">
              <template v-if="req.feedback">
                <strong>Your feedback ({{ req.feedbackDate }}):</strong>
                <div>{{ req.feedback }}</div>
              </template>
              <template v-else>
                <label :for="`feedback-${req.id}`">Share feedback</label>
                <textarea
                  :id="`feedback-${req.id}`"
                  v-model="feedbackDrafts[req.id]"
                  rows="3"
                  maxlength="500"
                  placeholder="Tell us how this request was handled..."
                ></textarea>
                <button class="btn-primary feedback-submit" @click="submitFeedback(req.id)">
                  Submit Feedback
                </button>
              </template>
            </div>
            <form
              v-if="canReopen(req)"
              class="request-feedback"
              @submit.prevent="reopenRequest(req.id)"
            >
              <strong>Reopen this request</strong>
              <label :for="`reopen-${req.id}`">Reason (5–500 characters)</label>
              <textarea
                :id="`reopen-${req.id}`"
                v-model="reopenDrafts[req.id]"
                rows="3"
                maxlength="500"
                minlength="5"
                required
                placeholder="Explain why this request needs further work..."
              ></textarea>
              <button
                class="btn-primary feedback-submit"
                type="submit"
                :disabled="(reopenDrafts[req.id] || '').trim().length < 5"
              >
                Reopen Request
              </button>
            </form>
          </div>
        </template>
        <div v-else class="empty-requisitions">No official requisitions submitted yet.</div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed, reactive } from 'vue';
import { useRequests } from '../composables/useRequests.js';
import { useAuth } from '../composables/useAuth.js';
import { useToast } from '../composables/useToast.js';
import PhotoGallery from '../components/PhotoGallery.vue';
import { isJobOrderVerified, printJobOrder } from '../lib/jobOrder.js';

const { requests, setRequestFeedback, reopenOwnRequest } = useRequests();
const { activeUserName } = useAuth();
const { showToast } = useToast();
const feedbackDrafts = reactive({});
const reopenDrafts = reactive({});

const myRequests = computed(() => {
  const user = (activeUserName.value || '').toLowerCase();
  return requests.value.filter((request) => (request.requester || '').toLowerCase() === user);
});

function submitFeedback(requestId) {
  const updated = setRequestFeedback(requestId, feedbackDrafts[requestId]);
  if (!updated) {
    showToast('Please add feedback before submitting.', 'error');
    return;
  }
  feedbackDrafts[requestId] = '';
  showToast('Feedback submitted. Thank you.', 'success');
}

function canReopen(request) {
  if (request.status !== 'closed' || !request.completedAt) return false;
  const completedAt = new Date(request.completedAt).getTime();
  return Number.isFinite(completedAt) && completedAt >= Date.now() - 7 * 24 * 60 * 60 * 1000;
}

async function reopenRequest(requestId) {
  try {
    const reopened = await reopenOwnRequest(requestId, reopenDrafts[requestId]);
    if (!reopened) {
      showToast('This request is no longer eligible to reopen.', 'error');
      return;
    }
    reopenDrafts[requestId] = '';
    showToast('Request reopened and returned to In Progress.', 'success');
  } catch (error) {
    showToast(error.message || 'Unable to reopen this request.', 'error');
  }
}

function formatStatus(status) {
  return String(status || 'submitted').replaceAll('-', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase());
}

function openJobOrder(request, action) {
  try {
    printJobOrder(request, action);
  } catch (error) {
    showToast(error.message || 'The job order could not be opened.', 'error');
  }
}
</script>

<style scoped>
.requisitions-panel { width: 100%; max-width: none; min-height: calc(100vh - 48px); display: flex; flex-direction: column; }
.requisitions-content { flex: 1; padding: 16px; min-height: 0; overflow-y: auto; }
.requisition-card { margin-bottom: 14px; border-left: 4px solid var(--primary); }
.job-order-actions { display:flex; gap:8px; flex-wrap:wrap; margin-top:10px; }
.job-order-actions button { margin-top:0; padding:7px 10px; font-size:11px; }
.job-order-actions button:disabled { opacity:.55; cursor:not-allowed; }
.job-order-hint { margin:6px 0 0; color:var(--text-3); font-size:11px; }
.rc-title { margin-top: 6px; }
.request-id { font-family: 'DM Mono', monospace; font-size: 12px; color: var(--text-3); }
.request-meta { font-size: 11px; color: var(--text-3); margin-top: 2px; }
.request-details { font-size: 13px; color: var(--text-2); margin: 8px 0 0; }
.admin-acknowledgment { background: #e8f5e9; border: 1px solid #c8e6c9; border-radius: 6px; padding: 10px; margin-top: 10px; font-size: 12px; color: #2e7d32; }
.request-feedback { background: var(--surface-2); border: 1px solid var(--border); border-radius: 6px; padding: 12px; margin-top: 10px; font-size: 12px; color: var(--text-2); }
.request-feedback label { display: block; font-weight: 700; color: var(--text); margin-bottom: 6px; }
.request-feedback textarea { display: block; width: 100%; padding: 9px 10px; border: 1px solid var(--border); border-radius: var(--radius-sm); background: var(--surface); color: var(--text); font: inherit; resize: vertical; outline: none; }
.request-feedback textarea:focus { border-color: var(--primary); box-shadow: 0 0 0 3px rgba(15, 107, 61, 0.12); }
.feedback-submit { margin-top: 8px; padding: 8px 12px; font-size: 12px; }
.empty-requisitions { color: var(--text-3); font-size: 13px; text-align: center; padding: 36px 0; }
</style>
