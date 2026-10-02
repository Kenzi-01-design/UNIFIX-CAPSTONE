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
              <span :class="['tag', req.status === 'action-taken' ? 'resolved' : 'pending']">
                {{ req.status === 'action-taken' ? 'Action Taken' : 'Submitted' }}
              </span>
            </div>
            <div class="rc-title">{{ req.title }}</div>
            <div class="request-meta">{{ req.dept }} · {{ req.date }}</div>
            <p class="request-details">{{ req.details }}</p>

            <div v-if="req.status === 'action-taken'" class="admin-acknowledgment">
              <strong>Admin Acknowledgment ({{ req.actionDate }}):</strong>
              <div>{{ req.adminResponse }}</div>
            </div>
          </div>
        </template>
        <div v-else class="empty-requisitions">No official requisitions submitted yet.</div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue';
import { useRequests } from '../composables/useRequests.js';
import { useAuth } from '../composables/useAuth.js';

const { requests } = useRequests();
const { activeUserName } = useAuth();

const myRequests = computed(() => {
  const user = (activeUserName.value || '').toLowerCase();
  return requests.value.filter((request) => (request.requester || '').toLowerCase() === user);
});
</script>

<style scoped>
.requisitions-panel { max-width: 900px; }
.requisitions-content { padding: 16px; max-height: 640px; overflow-y: auto; }
.requisition-card { margin-bottom: 14px; border-left: 4px solid var(--primary); }
.rc-title { margin-top: 6px; }
.request-id { font-family: 'DM Mono', monospace; font-size: 12px; color: var(--text-3); }
.request-meta { font-size: 11px; color: var(--text-3); margin-top: 2px; }
.request-details { font-size: 13px; color: var(--text-2); margin: 8px 0 0; }
.admin-acknowledgment { background: #e8f5e9; border: 1px solid #c8e6c9; border-radius: 6px; padding: 10px; margin-top: 10px; font-size: 12px; color: #2e7d32; }
.empty-requisitions { color: var(--text-3); font-size: 13px; text-align: center; padding: 36px 0; }
</style>
