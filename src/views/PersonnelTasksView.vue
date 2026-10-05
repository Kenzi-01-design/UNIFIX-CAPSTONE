<template>
  <div class="view active" id="view-tasks">
    <div class="personnel-hero panel">
      <div>
        <div class="personnel-kicker">Maintenance Operations Desk</div>
        <h2>Ready for your next assignment</h2>
        <p>
          Review assigned university work orders, accept jobs, and update real-time progress.
        </p>
        <div class="personnel-meta">
          <span>Assigned to <strong>{{ activeUserName }}</strong></span>
          <span>{{ activeLoadCount }} active tickets</span>
          <span>{{ completedCount }} completed</span>
        </div>
      </div>
      <div class="personnel-hero-actions">
        <button class="btn-secondary" @click="resetFilters">
          Reset filters
        </button>
        <button
          class="btn-primary"
          @click="showToast('Accept tasks to move them into your active queue, then mark them resolved once work completes.', 'info')"
        >
          Workflow Guide
        </button>
      </div>
    </div>

    <div class="personnel-metrics">
      <div class="personnel-metric">
        <span class="personnel-metric-label">Assigned</span>
        <strong class="personnel-metric-value">{{ assignedReports.length }}</strong>
      </div>
      <div class="personnel-metric">
        <span class="personnel-metric-label">Waiting</span>
        <strong class="personnel-metric-value">{{ waitingCount }}</strong>
      </div>
      <div class="personnel-metric">
        <span class="personnel-metric-label">Active Work</span>
        <strong class="personnel-metric-value">{{ inProgressWorkCount }}</strong>
      </div>
      <div class="personnel-metric">
        <span class="personnel-metric-label">Completed</span>
        <strong class="personnel-metric-value">{{ completedCount }}</strong>
      </div>
    </div>

    <div class="filter-bar personnel-filter-bar">
      <div class="search-wrap personnel-search-wrap">
        <span class="search-icon"><UiIcon name="search" /></span>
        <input
          type="text"
          v-model="searchQuery"
          placeholder="Search assigned tickets, locations, or IDs..."
        />
      </div>
      <select v-model="filterStatus" class="filter-select">
        <option value="all">All tasks</option>
        <option value="waiting">Waiting acceptance</option>
        <option value="active">Active work</option>
        <option value="completed">Completed</option>
        <option value="urgent">Urgent</option>
      </select>
      <button class="btn-secondary" @click="resetFilters">
        Clear
      </button>
    </div>

    <div class="personnel-grid">
      <div class="panel">
        <div class="panel-header">
          <span class="panel-title">Assigned Tickets</span>
          <span class="panel-action">{{ filteredTasks.length }} shown</span>
        </div>
        <div style="padding:18px">
          <div class="reports-cards">
            <template v-if="filteredTasks.length">
              <div
                v-for="r in filteredTasks"
                :key="r.id"
                :class="['report-card', r.risk]"
              >
                <div class="rc-top">
                  <div class="rc-cat">
                    <div class="rc-cat-icon" :style="{ background: r.catBg || '#fff4e6' }">
                      <UiIcon :name="r.cat" />
                    </div>
                    <div>
                      <div class="rc-cat-name">{{ r.cat }}</div>
                      <div style="font-size:10px;color:var(--text-3);font-family:'DM Mono',monospace">
                        {{ r.id }}
                      </div>
                    </div>
                  </div>
                  <span :class="['tag', r.status]">{{ formatStatus(r.status) }}</span>
                </div>

                <div class="rc-title">{{ r.title }}</div>
                <div :class="['task-stage', r.techState]">
                  {{ getNextStepLabel(r.techState) }}
                </div>
                <div class="rc-location"><UiIcon name="location" :size="15" /> {{ r.loc }}</div>
                <PhotoGallery :attachments="r.photoAttachments || []" :title="r.title" />
                <div class="task-deadline">
                  <span :class="['tag', `priority-${r.priority || 'low'}`]">{{ capitalize(r.priority || 'low') }} priority</span>
                  <SlaBadge :due-at="r.dueAt" :completed="r.techState === 'completed'" />
                </div>

                <div class="rc-footer">
                  <span class="rc-reporter"><UiIcon name="reporter" :size="15" /> {{ r.reporter }}</span>
                  <span :class="['tag', r.risk]">{{ capitalize(r.risk) }}</span>
                  <span class="rc-date">{{ r.date }}</span>
                </div>

                <div style="padding:12px 18px 0; display:flex; gap:10px; flex-wrap:wrap">
                  <PhotoPicker
                    v-if="['accepted', 'started'].includes(r.techState) && (r.photoAttachments?.length || 0) < 3"
                    :model-value="completionPhotos[r.id] || []"
                    :max-photos="Math.max(0, 3 - (r.photoAttachments?.length || 0))"
                    label="After photos (optional)"
                    @update:model-value="completionPhotos[r.id] = $event"
                  >
                  </PhotoPicker>
                  <button
                    v-if="r.techState === 'assigned'"
                    class="btn-primary"
                    @click="handleAccept(r)"
                  >
                    Accept Work
                  </button>
                  <template v-if="r.techState === 'accepted'">
                    <button class="btn-secondary" @click="handleStart(r)">
                      Start Work
                    </button>
                  </template>
                  <button
                    v-if="r.techState === 'started'"
                    class="admin-action-btn resolve"
                    @click="handleComplete(r)"
                  >
                    Mark Resolved
                  </button>
                  <span
                    v-if="r.techState === 'completed'"
                    style="font-weight:700; color:var(--green);"
                  >
                    Completed ✅
                  </span>
                </div>
              </div>
            </template>

            <div v-else class="report-card low personnel-empty">
              <div class="rc-title">No matching tasks found.</div>
              <div class="rc-location">Your queue is clear or adjust active filter criteria.</div>
            </div>
          </div>
        </div>
      </div>

      <div class="panel personnel-sidebar">
        <div class="panel-header">
          <span class="panel-title">Shift Overview</span>
          <span class="panel-action">Today</span>
        </div>
        <div class="personnel-side-list">
          <div class="personnel-side-item">
            <span>Waiting acceptance</span>
            <strong>{{ waitingCount }}</strong>
          </div>
          <div class="personnel-side-item">
            <span>Active in-progress</span>
            <strong>{{ inProgressWorkCount }}</strong>
          </div>
          <div class="personnel-side-item">
            <span>Unresolved tickets</span>
            <strong>{{ activeLoadCount }}</strong>
          </div>
          <div class="personnel-side-item">
            <span>Completed tickets</span>
            <strong>{{ completedCount }}</strong>
          </div>
        </div>
        <div class="personnel-side-note">
          Keep tickets moving by accepting new assignments immediately upon notification.
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed } from 'vue';
import { useReports } from '../composables/useReports.js';
import { useRequests } from '../composables/useRequests.js';
import { useAuth } from '../composables/useAuth.js';
import { useToast } from '../composables/useToast.js';
import UiIcon from '../components/UiIcon.vue';
import PhotoPicker from '../components/PhotoPicker.vue';
import SlaBadge from '../components/SlaBadge.vue';
import PhotoGallery from '../components/PhotoGallery.vue';

const { reports, techAccept, techStart, techComplete, isAssignedTo } = useReports();
const { requests, requestAccept, requestStart, requestComplete, isAssignedTo: isRequestAssignedTo } = useRequests();
const { activeUserName } = useAuth();
const { showToast } = useToast();

const searchQuery = ref('');
const filterStatus = ref('all');
const completionPhotos = reactive({});

const assignedReports = computed(() => {
  return reports.value
    .filter((r) => isAssignedTo(r, activeUserName.value))
    .map((report) => ({ ...report, kind: 'report' }));
});

const assignedRequests = computed(() => {
  return requests.value
    .filter((request) => isRequestAssignedTo(request, activeUserName.value))
    .map((request) => ({
      ...request,
      kind: 'request',
      catBg: '#e8f5e9',
      loc: request.dept,
      reporter: request.requester,
      risk: request.risk || 'low',
      status: request.techState === 'completed'
        ? 'resolved'
        : ['accepted', 'started'].includes(request.techState)
          ? 'in-progress'
          : 'pending',
      techState: request.techState || 'unassigned'
    }));
});

const assignedTasks = computed(() => [...assignedReports.value, ...assignedRequests.value]);

const waitingCount = computed(() => assignedTasks.value.filter((r) => r.techState === 'assigned').length);
const inProgressWorkCount = computed(
  () => assignedTasks.value.filter((r) => r.techState === 'accepted' || r.techState === 'started').length
);
const completedCount = computed(() => assignedTasks.value.filter((r) => r.techState === 'completed').length);
const activeLoadCount = computed(() => assignedTasks.value.filter((r) => r.techState !== 'completed').length);

const filteredTasks = computed(() => {
  const q = searchQuery.value.trim().toLowerCase();
  return assignedTasks.value.filter((r) => {
    const haystack = `${r.id} ${r.title} ${r.loc} ${r.cat} ${r.status} ${r.risk}`.toLowerCase();
    if (q && !haystack.includes(q)) return false;

    if (filterStatus.value === 'waiting' && r.techState !== 'assigned') return false;
    if (filterStatus.value === 'active' && !(r.techState === 'accepted' || r.techState === 'started')) return false;
    if (filterStatus.value === 'completed' && r.techState !== 'completed') return false;
    if (filterStatus.value === 'urgent' && r.status !== 'urgent') return false;

    return true;
  });
});

function getNextStepLabel(state) {
  switch (state) {
    case 'completed': return 'Completed';
    case 'started': return 'Work in progress';
    case 'accepted': return 'Ready to begin';
    default: return 'Awaiting acceptance';
  }
}

async function handleAccept(task) {
  const accepted = task.kind === 'request'
    ? await requestAccept(task.id, activeUserName.value)
    : await techAccept(task.id, activeUserName.value);
  if (accepted) {
    showToast(`${task.id} accepted. Proceed when ready.`, 'success');
  } else {
    showToast('Unable to save acceptance. Check your assignment and Supabase access.', 'error');
  }
}

async function handleStart(task) {
  const started = task.kind === 'request'
    ? await requestStart(task.id, activeUserName.value)
    : await techStart(task.id, activeUserName.value);
  if (started) {
    showToast(`${task.id} marked In Progress.`, 'info');
  } else {
    showToast('Unable to save the start status. Check your Supabase access.', 'error');
  }
}

async function handleComplete(task) {
  let completed;
  try {
    const photos = completionPhotos[task.id] || [];
    completed = task.kind === 'request'
      ? await requestComplete(task.id, activeUserName.value, photos)
      : await techComplete(task.id, activeUserName.value, photos);
  } catch (error) {
    showToast(error.message || 'Unable to upload completion photos.', 'error');
    return;
  }
  if (completed) {
    completionPhotos[task.id] = [];
    showToast(`${task.id} marked resolved ✅`, 'success');
  } else {
    showToast('Unable to save completion. Check your Supabase access.', 'error');
  }
}

function resetFilters() {
  searchQuery.value = '';
  filterStatus.value = 'all';
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
.task-deadline { display: flex; flex-wrap: wrap; align-items: center; gap: 6px; margin-top: 8px; }
</style>
