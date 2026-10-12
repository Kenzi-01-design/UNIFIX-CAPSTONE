<template>
  <div class="view active" id="view-requests">
    <div class="filter-bar">
      <div class="search-wrap">
        <span class="search-icon"><UiIcon name="search" /></span>
        <input
          v-model="searchQuery"
          type="search"
          placeholder="Search by ID, title, category, requester, or department..."
          aria-label="Search requests"
        />
      </div>

      <select v-model="filterCategory" class="filter-select" aria-label="Filter requests by category">
        <option value="">All Categories</option>
        <option v-for="category in categories" :key="category" :value="category">{{ category }}</option>
      </select>

      <select v-model="filterStatus" class="filter-select" aria-label="Filter requests by status">
        <option value="">All Status</option>
        <option value="submitted">Submitted</option>
        <option value="in-progress">In Progress</option>
        <option value="for-verification">For Verification</option>
        <option value="closed">Closed</option>
      </select>

      <select v-model="filterDate" class="filter-select" aria-label="Filter requests by date">
        <option value="">All Dates</option>
        <option value="today">Today</option>
        <option value="week">This Week</option>
        <option value="month">This Month</option>
      </select>
    </div>

    <div class="reports-cards" id="requests-container">
      <template v-if="filteredRequests.length">
        <article
          v-for="request in filteredRequests"
          :key="request.id"
          :class="['report-card', request.risk || 'low']"
          role="button"
          tabindex="0"
          :aria-label="`View request ${request.trackingCode || request.id}: ${request.title}`"
          @click="$emit('open-request', request.id)"
          @keydown.enter.prevent="$emit('open-request', request.id)"
          @keydown.space.prevent="$emit('open-request', request.id)"
        >
          <div class="rc-top">
            <div class="rc-cat">
              <div class="rc-cat-icon" :style="{ background: '#eef4ff' }">
                <UiIcon :name="request.cat || 'requests'" />
              </div>
              <div>
                <div class="rc-cat-name">{{ request.cat || 'General' }}</div>
                <div class="request-id">{{ request.trackingCode || request.id }}</div>
              </div>
            </div>
            <span :class="['tag', request.status]">{{ formatStatus(request.status) }}</span>
          </div>

          <div class="rc-title">{{ request.title }}</div>
          <div class="request-meta"><UiIcon name="building" :size="14" /> {{ request.dept || 'Department not specified' }}</div>
          <p v-if="request.details" class="request-details">{{ request.details }}</p>
          <div v-if="currentRole === 'Admin' && request.feedback" class="request-feedback">
            <strong>Employee feedback<span v-if="request.feedbackDate"> · {{ request.feedbackDate }}</span></strong>
            <p>{{ request.feedback }}</p>
          </div>

          <div class="rc-footer">
            <span class="rc-reporter"><UiIcon name="reporter" :size="14" /> {{ request.requester || 'Unknown requester' }}</span>
            <span v-if="request.assignedTo" class="request-assignee">Assigned: {{ request.assignedTo }}</span>
            <span v-else class="request-unassigned">Unassigned</span>
            <span class="rc-date">{{ request.date }}</span>
          </div>
        </article>
      </template>

      <div v-else class="report-card low empty-request-card">
        <div class="rc-title">{{ requests.length ? 'No matching requests found.' : 'No requests have been submitted yet.' }}</div>
        <div class="rc-location">
          {{ requests.length ? 'Try clearing your search or changing the filters.' : 'New service requests will appear here for review.' }}
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed, ref } from 'vue';
import { useRequests } from '../composables/useRequests.js';
import { useAuth } from '../composables/useAuth.js';
import UiIcon from '../components/UiIcon.vue';

const { requests, isAssignedTo } = useRequests();
const { currentRole, activeUserName } = useAuth();
const props = defineProps({
  initialStatus: {
    type: String,
    default: ''
  }
});
defineEmits(['open-request']);
const searchQuery = ref('');
const filterCategory = ref('');
const filterStatus = ref(props.initialStatus);
const filterDate = ref('');

const categories = computed(() => [...new Set(requests.value.map((request) => request.cat).filter(Boolean))].sort());

function parseRequestDate(value) {
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

function matchesDate(value) {
  if (!filterDate.value) return true;
  const date = parseRequestDate(value);
  if (!date) return true;

  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const requestDay = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  const age = now.getTime() - date.getTime();

  if (filterDate.value === 'today') return requestDay.getTime() === today.getTime();
  if (filterDate.value === 'week') return age >= 0 && age <= 7 * 86_400_000;
  if (filterDate.value === 'month') return age >= 0 && age <= 31 * 86_400_000;
  return true;
}

function matchesStatus(requestStatus) {
  if (!filterStatus.value) return true;
  if (filterStatus.value === 'closed') {
    return ['closed', 'resolved', 'action-taken'].includes(requestStatus);
  }
  return requestStatus === filterStatus.value;
}

const filteredRequests = computed(() => {
  const query = searchQuery.value.trim().toLowerCase();

  return requests.value.filter((request) => {
    if (currentRole.value === 'Personnel' && !isAssignedTo(request, activeUserName.value)) return false;
    if (filterCategory.value && request.cat !== filterCategory.value) return false;
    if (!matchesStatus(request.status)) return false;
    if (query) {
      const searchable = [
        request.id,
        request.trackingCode,
        request.title,
        request.cat,
        request.dept,
        request.requester,
        request.assignedTo,
        request.details
      ].join(' ').toLowerCase();
      if (!searchable.includes(query)) return false;
    }
    return matchesDate(request.date);
  }).sort((a, b) => new Date(b.updatedAt || b.date || 0) - new Date(a.updatedAt || a.date || 0));
});

function formatStatus(status) {
  return String(status || 'submitted').replaceAll('-', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase());
}

</script>

<style scoped>
.request-id { font-family: 'DM Mono', monospace; font-size: 10px; color: var(--text-3); }
.request-meta { display: flex; align-items: center; gap: 5px; margin-top: 4px; font-size: 11px; color: var(--text-3); }
.request-details { margin: 8px 0 0; color: var(--text-2); font-size: 12px; line-height: 1.5; }
.request-feedback { margin-top: 12px; padding: 11px 13px; border-left: 3px solid var(--primary); border-radius: 6px; background: var(--surface-2); color: var(--text-2); font-size: 12px; line-height: 1.5; }
.request-feedback strong { color: var(--text); }
.request-feedback p { margin: 4px 0 0; white-space: pre-wrap; overflow-wrap: anywhere; }
.request-assignee, .request-unassigned { font-size: 10px; color: var(--text-3); }
.request-unassigned { color: var(--red); font-weight: 700; }
.reports-cards > article[role="button"] { cursor:pointer; }
.reports-cards > article[role="button"]:focus-visible { outline:3px solid var(--primary); outline-offset:2px; }
.empty-request-card { grid-column: 1 / -1; }
</style>
