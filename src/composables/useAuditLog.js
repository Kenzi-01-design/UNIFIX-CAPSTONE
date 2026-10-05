import { ref } from 'vue';
import { isSupabaseConfigured, supabase } from '../lib/supabase.js';

const DEMO_AUDIT_KEY = 'unifix-audit-log-v1';
const entries = ref([]);
const loading = ref(false);
const loadError = ref('');

function readDemoEntries() {
  try {
    const saved = JSON.parse(localStorage.getItem(DEMO_AUDIT_KEY) || '[]');
    return Array.isArray(saved) ? saved : [];
  } catch (error) {
    console.warn('Failed loading demo audit history.', error);
    return [];
  }
}

export function recordDemoAudit({ entityType, entityId, action, oldValue = null, newValue = null }) {
  if (isSupabaseConfigured) return;
  const history = readDemoEntries();
  history.unshift({
    id: crypto.randomUUID(),
    entity_type: entityType,
    entity_id: entityId,
    action,
    actor_role: 'Demo',
    old_value: oldValue,
    new_value: newValue,
    created_at: new Date().toISOString()
  });
  try {
    localStorage.setItem(DEMO_AUDIT_KEY, JSON.stringify(history.slice(0, 500)));
  } catch (error) {
    console.warn('Failed saving demo audit history.', error);
  }
}

export function useAuditLog() {
  async function loadAuditLog({ entityType = '', entityId = '', limit = 500 } = {}) {
    loading.value = true;
    loadError.value = '';
    try {
      if (!isSupabaseConfigured) {
        entries.value = readDemoEntries()
          .filter((item) => (!entityType || item.entity_type === entityType) && (!entityId || item.entity_id === entityId))
          .slice(0, limit);
        return entries.value;
      }
      let query = supabase
        .from('audit_log')
        .select('id,entity_type,entity_id,action,actor_email,actor_role,old_value,new_value,created_at')
        .order('created_at', { ascending: false })
        .limit(limit);
      if (entityType) query = query.eq('entity_type', entityType);
      if (entityId) query = query.eq('entity_id', entityId);
      const { data, error } = await query;
      if (error) throw error;
      entries.value = data || [];
      return entries.value;
    } catch (error) {
      loadError.value = error.message || 'Unable to load audit history.';
      throw error;
    } finally {
      loading.value = false;
    }
  }

  return { entries, loading, loadError, loadAuditLog };
}
