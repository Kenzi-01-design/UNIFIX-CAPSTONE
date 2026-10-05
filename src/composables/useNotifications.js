import { ref } from 'vue';
import { isSupabaseConfigured, supabase } from '../lib/supabase.js';

const notifications = ref([]);
const loading = ref(false);
let channel = null;
let activeEmail = '';
let activeDemoKey = '';

function demoKey(role, name) {
  return `unifix-notifications-${(role + '-' + name).toLowerCase().replace(/[^a-z0-9]+/g, '-')}`;
}

function readDemoFeed(key) {
  try {
    const saved = localStorage.getItem(key);
    const parsed = saved ? JSON.parse(saved) : [];
    return Array.isArray(parsed) ? parsed : [];
  } catch (error) {
    console.warn('Failed loading demo notifications.', error);
    return [];
  }
}

function saveDemoFeed(key, entries) {
  try {
    localStorage.setItem(key, JSON.stringify(entries.slice(0, 50)));
  } catch (error) {
    console.warn('Failed saving demo notifications.', error);
  }
}

function normalizeNotification(item) {
  const date = new Date(item.created_at);
  return {
    id: item.id,
    eventType: item.event_type,
    title: item.title,
    text: item.message,
    time: Number.isNaN(date.getTime()) ? item.created_at : date.toLocaleString(),
    createdAt: item.created_at,
    read: Boolean(item.read_at),
    entityType: item.entity_type,
    entityId: item.entity_id,
    trackingCode: item.tracking_code
  };
}

async function loadProductionFeed(email) {
  const { data, error } = await supabase
    .from('notifications')
    .select('id,event_type,title,message,entity_type,entity_id,tracking_code,created_at,read_at')
    .eq('user_email', email)
    .order('created_at', { ascending: false })
    .limit(50);
  if (error) throw error;
  notifications.value = (data || []).map(normalizeNotification);
}

function stopNotifications() {
  if (channel) {
    void supabase.removeChannel(channel);
    channel = null;
  }
  activeEmail = '';
  activeDemoKey = '';
}

export function useNotifications() {
  async function refreshNotifications(currentRole, activeUserName) {
    loading.value = true;
    try {
      if (isSupabaseConfigured) {
        const { data, error } = await supabase.auth.getUser();
        if (error) throw error;
        const email = data.user?.email?.toLowerCase();
        if (!email) {
          notifications.value = [];
          stopNotifications();
          return;
        }
        if (activeEmail !== email) {
          stopNotifications();
          activeEmail = email;
          channel = supabase
            .channel(`notifications:${email}`)
            .on('postgres_changes', {
              event: '*',
              schema: 'public',
              table: 'notifications',
              filter: `user_email=eq.${email}`
            }, () => {
              void loadProductionFeed(email).catch((error) => {
                console.error('Failed refreshing realtime notifications.', error);
              });
            })
            .subscribe();
        }
        await loadProductionFeed(email);
        return;
      }

      const key = demoKey(currentRole, activeUserName);
      activeDemoKey = key;
      notifications.value = readDemoFeed(key);
    } finally {
      loading.value = false;
    }
  }

  function pushTechAssignmentNotification(techName, report, status) {
    if (isSupabaseConfigured) return;
    const key = demoKey('Personnel', techName);
    const statusLabel = status === 'in-progress'
      ? 'In Progress'
      : status.replaceAll('-', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase());
    const entries = readDemoFeed(key);
    const entityType = report.entityType || (report.dept ? 'request' : 'report');
    entries.unshift({
      id: crypto.randomUUID(),
      eventType: 'new_assignment',
      title: 'New work assigned',
      text: `${report.id} assigned to you: ${report.title} (${statusLabel})`,
      time: new Date().toLocaleString(),
      createdAt: new Date().toISOString(),
      read: false,
      entityType,
      entityId: report.id
    });
    saveDemoFeed(key, entries);
    if (activeDemoKey === key) notifications.value = entries;
  }

  function pushDemoNotification(role, userName, event) {
    if (isSupabaseConfigured) return;
    const key = demoKey(role, userName);
    const entries = readDemoFeed(key);
    entries.unshift({
      id: crypto.randomUUID(),
      eventType: event.eventType || 'status_changed',
      title: event.title,
      text: event.message,
      time: new Date().toLocaleString(),
      createdAt: new Date().toISOString(),
      read: false,
      entityType: event.entityType,
      entityId: event.entityId
    });
    saveDemoFeed(key, entries);
    if (activeDemoKey === key) notifications.value = entries;
  }

  async function markAllRead(currentRole, activeUserName) {
    if (isSupabaseConfigured) {
      const { error } = await supabase.rpc('mark_all_notifications_read');
      if (error) throw error;
      notifications.value = notifications.value.map((item) => ({
        ...item,
        read: true
      }));
      return;
    }
    const key = activeDemoKey || demoKey(currentRole, activeUserName);
    const updated = readDemoFeed(key).map((item) => ({ ...item, read: true }));
    saveDemoFeed(key, updated);
    notifications.value = updated;
  }

  return {
    notifications,
    loading,
    refreshNotifications,
    pushTechAssignmentNotification,
    pushDemoNotification,
    markAllRead,
    stopNotifications
  };
}
