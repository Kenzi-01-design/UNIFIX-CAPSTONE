import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

vi.mock('../lib/supabase.js', () => ({
  isDemoMode: false,
  isSupabaseConfigured: false,
  supabase: null
}));

async function loadProfiles() {
  vi.resetModules();
  const { useUserProfiles } = await import('./useUserProfiles.js');
  return useUserProfiles();
}

describe('local user profiles', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  beforeEach(() => {
    vi.stubGlobal('localStorage', {
      getItem: vi.fn(() => null),
      setItem: vi.fn()
    });
  });

  it('does not create built-in demo accounts when local profiles are empty', async () => {
    const { profiles } = await loadProfiles();

    expect(profiles.value).toEqual([]);
  });

  it('removes old built-in demo accounts but preserves saved user accounts', async () => {
    const savedProfiles = [
      { id: 'admin-user', name: 'Admin User', role: 'Admin' },
      { id: 'personnel-user', name: 'Juan dela Cruz', role: 'Personnel' },
      { id: 'actual-admin-id', name: 'Campus Administrator', role: 'Admin' },
      { id: 'actual-employee-id', name: 'Campus Employee', role: 'Employee' },
      { id: 'actual-personnel-id', name: 'Campus Personnel', role: 'Personnel' }
    ];
    localStorage.getItem.mockReturnValue(JSON.stringify(savedProfiles));

    const { profiles } = await loadProfiles();

    expect(profiles.value.map((profile) => profile.id)).toEqual([
      'actual-admin-id',
      'actual-employee-id',
      'actual-personnel-id'
    ]);
  });
});
