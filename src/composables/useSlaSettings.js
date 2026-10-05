import { ref } from 'vue';
import { isSupabaseConfigured, supabase } from '../lib/supabase.js';
import { DEFAULT_SLA_SETTINGS } from '../lib/sla.js';

const STORAGE_KEY = 'unifix-sla-settings-v1';
const settings = ref(DEFAULT_SLA_SETTINGS.map((item) => ({ ...item })));
const loading = ref(false);
const loadError = ref('');
let loaded = false;

function loadDemoSettings() {
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (saved) {
      const parsed = JSON.parse(saved);
      if (Array.isArray(parsed) && parsed.length === DEFAULT_SLA_SETTINGS.length) {
        settings.value = parsed;
      }
    }
  } catch (error) {
    console.warn('Failed loading demo SLA settings.', error);
  }
}

export function useSlaSettings() {
  async function loadSlaSettings() {
    if (loaded || loading.value) return;
    loading.value = true;
    loadError.value = '';
    try {
      if (!isSupabaseConfigured) {
        loadDemoSettings();
      } else {
        const { data, error } = await supabase.from('sla_settings').select('priority, target_hours');
        if (error) throw error;
        if (!data || data.length !== DEFAULT_SLA_SETTINGS.length) {
          throw new Error('SLA settings are incomplete. Apply the Phase 1 database migration.');
        }
        settings.value = data;
      }
      loaded = true;
    } catch (error) {
      loadError.value = error.message || 'Unable to load SLA settings.';
    } finally {
      loading.value = false;
    }
  }

  async function saveSlaSettings(values) {
    const normalized = DEFAULT_SLA_SETTINGS.map(({ priority }) => {
      const targetHours = Number(values[priority]);
      if (!Number.isInteger(targetHours) || targetHours < 1 || targetHours > 8760) {
        throw new Error('Enter a target resolution time between 1 and 8760 hours for every priority.');
      }
      return { priority, target_hours: targetHours };
    });

    if (isSupabaseConfigured) {
      const { error } = await supabase.from('sla_settings').upsert(normalized, { onConflict: 'priority' });
      if (error) throw error;
    } else {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(normalized));
    }
    settings.value = normalized;
    loaded = true;
  }

  return { settings, loading, loadError, loadSlaSettings, saveSlaSettings };
}
