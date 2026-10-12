import { ref } from 'vue';
import { isSupabaseConfigured, supabase } from '../lib/supabase.js';

const HISTORY_LIMIT = 500;

export function useWorkItemActivity() {
  const events = ref([]);
  const isLoading = ref(false);
  const error = ref('');
  let channel = null;
  let retryTimer = null;
  let retryAttempt = 0;
  let subscriptionWanted = false;
  let generation = 0;
  let queryGeneration = 0;

  async function reload() {
    if (!isSupabaseConfigured) {
      events.value = [];
      error.value = '';
      return;
    }

    const lifecycleGeneration = generation;
    const requestId = ++queryGeneration;
    isLoading.value = true;
    try {
      const { data, error: queryError } = await supabase
        .from('work_item_activity')
        .select('*')
        .order('created_at', { ascending: false })
        .order('id', { ascending: false })
        .limit(HISTORY_LIMIT);
      if (queryError) throw queryError;
      if (lifecycleGeneration === generation && requestId === queryGeneration) {
        const history = new Map((data || []).map((event) => [event.id, event]));
        for (const event of events.value) history.set(event.id, event);
        events.value = [...history.values()]
          .sort((left, right) => new Date(right.created_at).getTime() - new Date(left.created_at).getTime())
          .slice(0, HISTORY_LIMIT);
        error.value = '';
      }
    } catch (loadError) {
      if (lifecycleGeneration === generation && requestId === queryGeneration) {
        error.value = 'Work item activity could not be loaded. Please retry.';
      }
      console.error('Could not load work item activity.', loadError);
    } finally {
      if (lifecycleGeneration === generation && requestId === queryGeneration) isLoading.value = false;
    }
  }

  function scheduleRetry() {
    if (!subscriptionWanted || retryTimer) return;
    const delay = Math.min(1000 * (2 ** retryAttempt), 30_000);
    retryAttempt += 1;
    retryTimer = setTimeout(() => {
      retryTimer = null;
      subscribe();
    }, delay);
  }

  function subscribe() {
    if (!isSupabaseConfigured || !subscriptionWanted || channel) return;
    const newChannel = supabase
      .channel(`work-item-activity-${Date.now()}`)
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'work_item_activity'
      }, ({ new: event }) => {
        if (!event?.id) return;
        events.value = [event, ...events.value.filter((item) => item.id !== event.id)]
          .sort((left, right) => new Date(right.created_at).getTime() - new Date(left.created_at).getTime())
          .slice(0, HISTORY_LIMIT);
      })
      .subscribe((status) => {
        if (status === 'SUBSCRIBED') {
          retryAttempt = 0;
          void reload();
        } else if (['CHANNEL_ERROR', 'TIMED_OUT', 'CLOSED'].includes(status)) {
          error.value = 'Live work item activity updates were interrupted. Reconnecting.';
          if (channel === newChannel) channel = null;
          void supabase.removeChannel(newChannel).catch((removeError) => {
            console.error('Could not remove the failed work item activity channel.', removeError);
          });
          scheduleRetry();
        }
      });
    channel = newChannel;
  }

  function start() {
    if (subscriptionWanted) return;
    generation += 1;
    subscriptionWanted = true;
    void reload();
    subscribe();
  }

  function stop() {
    subscriptionWanted = false;
    generation += 1;
    if (retryTimer) {
      clearTimeout(retryTimer);
      retryTimer = null;
    }
    if (channel) {
      const oldChannel = channel;
      channel = null;
      void supabase.removeChannel(oldChannel).catch((removeError) => {
        console.error('Could not stop the work item activity subscription.', removeError);
      });
    }
  }

  return { events, isLoading, error, reload, start, stop };
}
