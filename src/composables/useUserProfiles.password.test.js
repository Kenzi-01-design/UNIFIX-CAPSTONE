import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

const mocks = vi.hoisted(() => ({
  invoke: vi.fn()
}));

vi.mock('../lib/supabase.js', () => ({
  isDemoMode: false,
  isSupabaseConfigured: true,
  supabase: {
    functions: { invoke: mocks.invoke }
  }
}));

async function loadProfiles() {
  vi.resetModules();
  const { useUserProfiles } = await import('./useUserProfiles.js');
  return useUserProfiles();
}

describe('Admin user password updates', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('updates a user password through the Admin Edge Function', async () => {
    mocks.invoke.mockResolvedValue({ data: { updated: true }, error: null });
    const { setUserPassword } = await loadProfiles();

    await expect(setUserPassword('auth-user-id', 'campus-password')).resolves.toBeUndefined();
    expect(mocks.invoke).toHaveBeenCalledWith('admin-set-user-password', {
      body: { targetAuthUserId: 'auth-user-id', password: 'campus-password' }
    });
  });

  it('rejects passwords that are too short before calling the function', async () => {
    const { setUserPassword } = await loadProfiles();

    await expect(setUserPassword('auth-user-id', 'short'))
      .rejects.toThrow('The new password must be between 8 and 128 characters.');
    expect(mocks.invoke).not.toHaveBeenCalled();
  });

  it('surfaces the Admin function error without hiding its reason', async () => {
    mocks.invoke.mockResolvedValue({
      data: null,
      error: {
        message: 'Function returned an error',
        context: { clone: () => ({ json: async () => ({ error: 'Only an active Admin may update user passwords.' }) }) }
      }
    });
    const { setUserPassword } = await loadProfiles();

    await expect(setUserPassword('auth-user-id', 'campus-password'))
      .rejects.toThrow('Only an active Admin may update user passwords.');
  });
});
