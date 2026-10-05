<template>
  <section class="audit-panel" :aria-label="global ? 'Global audit log' : 'Work item activity timeline'">
    <div v-if="global" class="audit-filters">
      <label>
        Search
        <input v-model="query" type="search" placeholder="Work item ID or action" />
      </label>
      <label>
        Type
        <select v-model="typeFilter">
          <option value="">All work</option>
          <option value="report">Reports</option>
          <option value="request">Requests</option>
        </select>
      </label>
      <label>
        Since
        <input v-model="startDate" type="date" />
      </label>
      <label>
        Until
        <input v-model="endDate" type="date" />
      </label>
      <button class="btn-secondary audit-export" type="button" :disabled="!filteredEntries.length" @click="exportCsv">
        Export CSV
      </button>
    </div>

    <p v-if="loading" class="audit-state" aria-live="polite">Loading audit history…</p>
    <p v-else-if="loadError" class="audit-state audit-error" role="alert">{{ loadError }}</p>
    <p v-else-if="!filteredEntries.length" class="audit-state">No activity recorded yet.</p>
    <ol v-else class="audit-timeline">
      <li v-for="item in filteredEntries" :key="item.id">
        <time :datetime="item.created_at">{{ formatDate(item.created_at) }}</time>
        <div class="audit-event">
          <strong>{{ actionLabel(item.action) }}</strong>
          <span v-if="global" class="audit-entity">{{ item.entity_type }} · {{ item.entity_id }}</span>
          <span v-if="item.actor_role || (global && item.actor_email)" class="audit-actor">
            {{ [item.actor_role, global ? item.actor_email : ''].filter(Boolean).join(' · ') }}
          </span>
          <p v-if="describeChange(item)">{{ describeChange(item) }}</p>
        </div>
      </li>
    </ol>
  </section>
</template>

<script setup>
import { computed, ref, watch } from 'vue';
import { useAuditLog } from '../composables/useAuditLog.js';
import { encodeCsv } from '../lib/csv.js';

const props = defineProps({
  entityType: { type: String, default: '' },
  entityId: { type: String, default: '' },
  global: { type: Boolean, default: false }
});

const { entries, loading, loadError, loadAuditLog } = useAuditLog();
const query = ref('');
const typeFilter = ref('');
const startDate = ref('');
const endDate = ref('');

const filteredEntries = computed(() => entries.value.filter((item) => {
  if (typeFilter.value && item.entity_type !== typeFilter.value) return false;
  const date = new Date(item.created_at);
  if (startDate.value && date < new Date(`${startDate.value}T00:00:00`)) return false;
  if (endDate.value && date > new Date(`${endDate.value}T23:59:59.999`)) return false;
  const needle = query.value.trim().toLowerCase();
  return !needle || `${item.entity_id} ${item.action} ${item.entity_type} ${item.actor_email || ''}`.toLowerCase().includes(needle);
}));

watch(
  () => [props.entityType, props.entityId, props.global],
  () => {
    if (props.global || props.entityId) {
      void loadAuditLog({
        entityType: props.global ? '' : props.entityType,
        entityId: props.global ? '' : props.entityId,
        limit: props.global ? 500 : 100
      }).catch(() => {});
    }
  },
  { immediate: true }
);

function actionLabel(action) {
  return ({
    created: 'Work item submitted',
    status_changed: 'Status changed',
    assignment_changed: 'Assignment changed',
    priority_changed: 'Priority changed'
  })[action] || action.replaceAll('_', ' ');
}

function formatDate(value) {
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? value : date.toLocaleString();
}

function describeChange(item) {
  const oldValue = JSON.stringify(item.old_value || {});
  const newValue = JSON.stringify(item.new_value || {});
  if (oldValue === '{}' && newValue === '{}') return '';
  return `${oldValue === '{}' ? '—' : oldValue} → ${newValue === '{}' ? '—' : newValue}`;
}

function exportCsv() {
  const rows = [
    ['Timestamp', 'Type', 'ID', 'Action', 'Actor', 'Role', 'Old value', 'New value'],
    ...filteredEntries.value.map((item) => [
      item.created_at,
      item.entity_type,
      item.entity_id,
      item.action,
      item.actor_email || '',
      item.actor_role || '',
      JSON.stringify(item.old_value || ''),
      JSON.stringify(item.new_value || '')
    ])
  ];
  const blob = new Blob([encodeCsv(rows)], { type: 'text/csv;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement('a');
  anchor.href = url;
  anchor.download = `unifix-audit-${new Date().toISOString().slice(0, 10)}.csv`;
  anchor.click();
  URL.revokeObjectURL(url);
}
</script>

<style scoped>
.audit-panel { padding: 16px; }
.audit-filters { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 10px; align-items: end; margin-bottom: 18px; }
.audit-filters label { display: grid; gap: 5px; color: var(--text-2); font-size: 11px; font-weight: 700; }
.audit-filters input, .audit-filters select { width: 100%; min-height: 38px; padding: 8px; border: 1px solid var(--border); border-radius: var(--radius-sm); background: var(--surface); color: var(--text); font: inherit; }
.audit-export { min-height: 38px; }
.audit-state { padding: 24px 10px; color: var(--text-3); font-size: 13px; text-align: center; }
.audit-error { color: var(--red); }
.audit-timeline { display: grid; gap: 12px; margin: 0; padding: 0; list-style: none; }
.audit-timeline li { display: grid; grid-template-columns: minmax(125px, 180px) 1fr; gap: 12px; padding-bottom: 12px; border-bottom: 1px solid var(--border); }
.audit-timeline time, .audit-actor, .audit-entity { color: var(--text-3); font-size: 11px; }
.audit-event { display: grid; gap: 4px; font-size: 12px; }
.audit-event p { margin: 0; color: var(--text-2); overflow-wrap: anywhere; }
.audit-entity { text-transform: capitalize; }
@media (max-width: 560px) { .audit-timeline li { grid-template-columns: 1fr; gap: 5px; } }
</style>
