<template>
  <div class="view active" id="view-activity-log">
    <div class="panel">
      <div class="panel-header">
        <span class="panel-title">Activity & Login History</span>
        <span class="panel-action">{{ activityEntries.length }} items</span>
      </div>

      <p v-if="activityError" class="activity-log-notice" role="alert">
        {{ activityError }}
        <button type="button" class="btn btn-secondary btn-sm" @click="refreshActivity">Retry</button>
      </p>
      <p v-else-if="activityLoading && !activityEntries.length" class="activity-log-notice" aria-live="polite">
        Loading activity history…
      </p>
      <p v-if="currentRole === 'Admin' && loginHistoryError" class="activity-log-notice" role="alert">
        {{ loginHistoryError }}
        <button type="button" class="btn btn-secondary btn-sm" @click="refreshLoginEvents">Retry login history</button>
      </p>

      <div class="responsive-table-scroll responsive-table-scroll--activity" style="overflow-x: auto">
        <table>
          <thead>
            <tr>
              <th>Type</th>
              <th>Reference ID</th>
              <th>Subject</th>
              <th>Date</th>
              <th>Current State</th>
              <th>Details / Note</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="item in activityEntries" :key="item.id">
              <td>
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
            <tr v-if="!activityLoading && !activityEntries.length">
              <td colspan="6" class="activity-log-empty">No activity history is available yet.</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue';
import { onBeforeUnmount, onMounted } from 'vue';
import { useAuth } from '../composables/useAuth.js';
import { useWorkItemActivity } from '../composables/useWorkItemActivity.js';
import { mergeActivityEntries } from '../lib/activityLog.js';

const { currentRole, loginEvents, loginHistoryError, refreshLoginEvents } = useAuth();
const { events, isLoading: activityLoading, error: activityError, reload, start, stop } = useWorkItemActivity();

const activityEntries = computed(() => mergeActivityEntries(
  events.value,
  currentRole.value === 'Admin' ? loginEvents.value : []
));

function refreshActivity() {
  void reload();
}

onMounted(() => {
  start();
  if (currentRole.value === 'Admin') void refreshLoginEvents();
});
onBeforeUnmount(stop);
</script>

<style scoped>
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
