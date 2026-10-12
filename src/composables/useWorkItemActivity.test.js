import { beforeEach, describe, expect, it, vi } from 'vitest';

const mocks = vi.hoisted(() => ({
  from: vi.fn(),
  channel: {
    on: vi.fn(),
    subscribe: vi.fn()
  },
  removeChannel: vi.fn(),
  queryResult: { data: [], error: null },
  changeHandler: null,
  statusHandler: null
}));

vi.mock('../lib/supabase.js', () => ({
  isSupabaseConfigured: true,
  supabase: {
    from: mocks.from,
    channel: vi.fn(() => mocks.channel),
    removeChannel: mocks.removeChannel
  }
}));

describe('useWorkItemActivity', () => {
  beforeEach(() => {
    vi.resetModules();
    vi.clearAllMocks();
    mocks.queryResult = { data: [], error: null };
    mocks.removeChannel.mockResolvedValue('ok');
    mocks.channel.on.mockImplementation((event, _filter, handler) => {
      mocks.changeHandler = handler;
      return mocks.channel;
    });
    mocks.channel.subscribe.mockImplementation((handler) => {
      mocks.statusHandler = handler;
      return mocks.channel;
    });
    mocks.from.mockImplementation(() => {
      const query = {
        select: vi.fn(() => query),
        order: vi.fn(() => query),
        limit: vi.fn(() => Promise.resolve(mocks.queryResult))
      };
      return query;
    });
  });

  it('loads stored activity and applies realtime inserts immediately', async () => {
    const { useWorkItemActivity } = await import('./useWorkItemActivity.js');
    const activity = useWorkItemActivity();
    activity.start();
    await Promise.resolve();

    expect(mocks.from).toHaveBeenCalledWith('work_item_activity');
    mocks.changeHandler({
      new: { id: 12, created_at: '2026-10-12T10:00:00.000Z', summary: 'Work assigned' }
    });
    expect(activity.events.value[0].id).toBe(12);

    activity.stop();
    expect(mocks.removeChannel).toHaveBeenCalledWith(mocks.channel);
  });

  it('exposes database read failures rather than presenting stale history as current', async () => {
    mocks.queryResult = { data: null, error: new Error('permission denied') };
    const { useWorkItemActivity } = await import('./useWorkItemActivity.js');
    const activity = useWorkItemActivity();

    await activity.reload();

    expect(activity.error.value).toMatch(/could not be loaded/i);
  });
});
