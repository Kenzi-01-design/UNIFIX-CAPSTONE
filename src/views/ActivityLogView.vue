<template>
  <div class="view active" id="view-activity-log">
    <div class="panel">
      <div class="panel-header">
        <span class="panel-title">Activity Log</span>
        <span class="panel-action">{{ visibleEntries.length }} items</span>
      </div>

      <p v-if="activeTab !== 'login' && activityError" class="activity-log-notice" role="alert">
        {{ activityError }}
        <button type="button" class="btn btn-secondary btn-sm" @click="refreshActivity">Retry</button>
      </p>
      <p v-else-if="activityLoading && activeTab !== 'login' && !visibleEntries.length" class="activity-log-notice" aria-live="polite">
        Loading activity history…
      </p>
      <p v-if="activeTab === 'login' && !hasAdminAccess(currentRole)" class="activity-log-notice">
        Login history is available to Admins and Assistants.
      </p>
      <p v-if="activeTab === 'login' && hasAdminAccess(currentRole) && loginHistoryError" class="activity-log-notice" role="alert">
        {{ loginHistoryError }}
        <button type="button" class="btn btn-secondary btn-sm" @click="refreshLoginEvents">Retry login history</button>
      </p>

      <div class="activity-tabs" role="tablist" aria-label="Activity history type">
        <button
          v-for="tab in tabs"
          :key="tab.id"
          type="button"
          class="activity-tab"
          :class="{ active: activeTab === tab.id }"
          :id="`activity-tab-${tab.id}`"
          role="tab"
          :aria-selected="activeTab === tab.id"
          :aria-controls="`activity-panel-${tab.id}`"
          @click="activeTab = tab.id"
        >
          {{ tab.label }}
          <span class="activity-tab-count">{{ tab.entries.length }}</span>
        </button>
      </div>

      <div
        v-if="activeTab !== 'login' || hasAdminAccess(currentRole)"
        class="responsive-table-scroll responsive-table-scroll--activity"
        style="overflow-x: auto"
      >
        <table
          :id="`activity-panel-${activeTab}`"
          role="tabpanel"
          :aria-labelledby="`activity-tab-${activeTab}`"
        >
          <thead>
            <tr>
              <th v-if="activeTab !== 'login'">Type</th>
              <th>Reference ID</th>
              <th>Subject</th>
              <th>Date</th>
              <th>Current State</th>
              <th>Details / Note</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="item in visibleEntries" :key="item.id">
              <td v-if="activeTab !== 'login'">
                <span style="font-weight: 700; font-size: 11px;">{{ item.type }}</span>
              </td>
              <td>
                <span style="font-family:'DM Mono',monospace; font-size:12px; color:var(--text-3)">{{ item.referenceId }}</span>
              </td>
              <td style="font-weight: 600; font-size: 13px;">{{ item.title }}</td>
              <td style="font-size: 12px; color: var(--text-3)">{{ item.date }}</td>
              <td>
                <span :class="['tag', item.statusClass]">{{ item.statusLabel }}</span>
              </td>
              <td style="font-size: 12px; color: var(--text-2); max-width: 250px;">
                {{ item.details }}
              </td>
            </tr>
            <tr v-if="!activityLoading && !visibleEntries.length">
              <td :colspan="activeTab === 'login' ? 5 : 6" class="activity-log-empty">
                {{ emptyMessage }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import { useAuth } from '../composables/useAuth.js';
import { useWorkItemActivity } from '../composables/useWorkItemActivity.js';
import { mergeActivityEntries } from '../lib/activityLog.js';
import { hasAdminAccess } from '../lib/access.js';

const { currentRole, loginEvents, loginHistoryError, refreshLoginEvents } = useAuth();
const { events, isLoading: activityLoading, error: activityError, reload, start, stop } = useWorkItemActivity();

const activeTab = ref('reports');
const workItemEntries = computed(() => mergeActivityEntries(events.value));
const reportEntries = computed(() => workItemEntries.value.filter((item) => item.type === 'REPORT'));
const requestEntries = computed(() => workItemEntries.value.filter((item) => item.type === 'REQUEST'));
const loginEntries = computed(() => hasAdminAccess(currentRole.value) ? loginEvents.value : []);
const tabs = computed(() => [
  { id: 'reports', label: 'Reports', entries: reportEntries.value },
  { id: 'requests', label: 'Requests', entries: requestEntries.value },
  { id: 'login', label: 'Login', entries: loginEntries.value }
]);
const visibleEntries = computed(() => {
  if (activeTab.value === 'login') return loginEntries.value;
  if (activeTab.value === 'requests') return requestEntries.value;
  return reportEntries.value;
});
const emptyMessage = computed(() => activeTab.value === 'login'
  ? 'No login history is available yet.'
  : `No ${activeTab.value} history is available yet.`);

function refreshActivity() {
  void reload();
}

onMounted(() => {
  start();
  if (hasAdminAccess(currentRole.value)) void refreshLoginEvents();
});
onBeforeUnmount(stop);
</script>

<style scoped>
.activity-tabs {
  display: flex;
  gap: 8px;
  overflow-x: auto;
  padding: 0 16px 12px;
  border-bottom: 1px solid var(--border);
}

.activity-tab {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  flex: 0 0 auto;
  padding: 9px 14px;
  border: 1px solid var(--border);
  border-radius: 8px;
  background: var(--surface);
  color: var(--text-2);
  font: inherit;
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
}

.activity-tab.active {
  border-color: var(--primary);
  background: var(--primary-bg);
  color: var(--primary);
}

.activity-tab-count {
  min-width: 20px;
  padding: 2px 6px;
  border-radius: 999px;
  background: var(--surface-2, var(--border));
  font-size: 11px;
  text-align: center;
}

.activity-log-notice {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin: 12px 16px;
  color: var(--text-2);
}

.activity-log-empty {
  padding: 24px;
  text-align: center;
  color: var(--text-3);
}
</style>
