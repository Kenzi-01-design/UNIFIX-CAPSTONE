<template>
  <section class="panel sla-settings">
    <div class="panel-header">
      <span class="panel-title">Priority resolution targets</span>
      <span class="panel-action">Administrators only</span>
    </div>
    <div class="sla-content">
      <p>Set the target time used to calculate deadlines when a work item's priority is set.</p>
      <div v-if="loading" class="sla-state" aria-live="polite">Loading SLA settings…</div>
      <div v-else-if="loadError" class="sla-error" role="alert">
        {{ loadError }}
        <button type="button" class="btn-secondary" @click="loadSlaSettings">Retry</button>
      </div>
      <form v-else @submit.prevent="save">
        <div v-for="item in priorities" :key="item.priority" class="sla-setting-row">
          <label :for="`sla-${item.priority}`">{{ item.label }}</label>
          <div>
            <input :id="`sla-${item.priority}`" v-model.number="targets[item.priority]" type="number" min="1" max="8760" required />
            <span>hours</span>
          </div>
        </div>
        <p v-if="saveError" class="sla-error" role="alert">{{ saveError }}</p>
        <p v-if="saved" class="sla-saved" role="status">Resolution targets saved.</p>
        <button class="btn-primary" type="submit" :disabled="saving">{{ saving ? 'Saving…' : 'Save SLA settings' }}</button>
      </form>
    </div>
  </section>
</template>

<script setup>
import { onMounted, reactive, ref, watch } from 'vue';
import { useSlaSettings } from '../composables/useSlaSettings.js';

const priorities = [
  { priority: 'low', label: 'Low' },
  { priority: 'medium', label: 'Medium' },
  { priority: 'high', label: 'High' },
  { priority: 'urgent', label: 'Urgent' }
];
const { settings, loading, loadError, loadSlaSettings, saveSlaSettings } = useSlaSettings();
const targets = reactive({ low: 168, medium: 72, high: 24, urgent: 4 });
const saving = ref(false);
const saveError = ref('');
const saved = ref(false);

watch(settings, (items) => {
  items.forEach((item) => { targets[item.priority] = item.target_hours; });
}, { deep: true, immediate: true });

onMounted(() => { void loadSlaSettings(); });

async function save() {
  saving.value = true;
  saveError.value = '';
  saved.value = false;
  try {
    await saveSlaSettings(targets);
    saved.value = true;
  } catch (error) {
    saveError.value = error.message || 'Unable to save SLA settings.';
  } finally {
    saving.value = false;
  }
}
</script>

<style scoped>
.sla-content { padding: 18px; }
.sla-content > p { margin-bottom: 14px; color: var(--text-2); font-size: 12px; }
.sla-state, .sla-error, .sla-saved { margin: 12px 0; font-size: 12px; }
.sla-error { color: var(--red); }
.sla-error button { margin-left: 8px; }
.sla-saved { color: var(--primary); }
.sla-setting-row { display: flex; flex-wrap: wrap; justify-content: space-between; align-items: center; gap: 8px; padding: 11px 0; border-top: 1px solid var(--border); font-size: 13px; font-weight: 700; }
.sla-setting-row div { display: flex; align-items: center; gap: 7px; color: var(--text-3); font-size: 11px; }
.sla-setting-row input { width: 110px; padding: 8px; border: 1px solid var(--border-dark); border-radius: 6px; font: inherit; }
.sla-content form > button { margin-top: 12px; }
</style>
