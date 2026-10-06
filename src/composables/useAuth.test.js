import { beforeEach, describe, expect, it, vi } from 'vitest';

const mocks = vi.hoisted(() => ({
  auth: {
    getSession: vi.fn(),
    onAuthStateChange: vi.fn(),
    signInWithPassword: vi.fn(),
    signOut: vi.fn()
  },
  functions: {
    invoke: vi.fn()
  },
  from: vi.fn(),
  channel: {
    on: vi.fn(),
    subscribe: vi.fn()
  },
  removeChannel: vi.fn(),
  profileResult: { data: null, error: null }
}));

vi.mock('../lib/supabase.js', () => ({
  isDemoMode: false,
  isSupabaseConfigured: true,
  supabase: {
    auth: mocks.auth,
    functions: mocks.functions,
    from: mocks.from,
    channel: vi.fn(() => mocks.channel),
    removeChannel: mocks.removeChannel
  }
}));

async function loadAuth() {
  vi.resetModules();
  const { useAuth } = await import('./useAuth.js');
  return useAuth();
}

describe('useAuth sign-in handling', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.stubGlobal('localStorage', {
      getItem: vi.fn(() => null),
      setItem: vi.fn(),
      removeItem: vi.fn()
    });
    mocks.profileResult = { data: null, error: null };
    mocks.auth.signInWithPassword.mockResolvedValue({
      data: { user: { id: 'auth-user-1', email: 'employee@nvsu.edu.ph' } },
      error: null
    });
    mocks.auth.signOut.mockResolvedValue({ error: null });
    mocks.auth.onAuthStateChange.mockReturnValue({ data: { subscription: { unsubscribe: vi.fn() } } });
    mocks.channel.on.mockReturnValue(mocks.channel);
    mocks.channel.subscribe.mockReturnValue(mocks.channel);
    mocks.from.mockImplementation((table) => {
      const query = {
        select: vi.fn(() => query),
        order: vi.fn(() => query),
        limit: vi.fn(() => Promise.resolve({ data: [], error: null })),
        eq: vi.fn(() => query),
        is: vi.fn(() => query),
        maybeSingle: vi.fn(() => Promise.resolve(mocks.profileResult)),
        upsert: vi.fn(() => Promise.resolve({ error: null }))
      };
      return query;
    });
  });

  it('uses the profile role, not the selected login tab', async () => {
    mocks.profileResult = {
      data: {
        auth_user_id: 'auth-user-1',
        name: 'Employee User',
        role: 'Employee',
        is_active: true,
        registration_status: 'approved'
      },
      error: null
    };
    const auth = await loadAuth();

    await expect(auth.login('employee@nvsu.edu.ph', 'password', 'Admin')).resolves.toBe('Employee');
    expect(auth.currentRole.value).toBe('Employee');
    expect(auth.isAuthenticated.value).toBe(true);
  });

  it('signs out a pending account and reports its review state', async () => {
    mocks.profileResult = {
      data: {
        auth_user_id: 'auth-user-1',
        name: 'Employee User',
        role: 'Employee',
        is_active: false,
        registration_status: 'pending'
      },
      error: null
    };
    const auth = await loadAuth();

    await expect(auth.login('employee@nvsu.edu.ph', 'password', 'Employee'))
      .rejects.toThrow('awaiting administrator approval');
    expect(mocks.auth.signOut).toHaveBeenCalledWith({ scope: 'local' });
    expect(auth.isAuthenticated.value).toBe(false);
  });

  it('signs out an Auth user who has no profile and gives setup guidance', async () => {
    const auth = await loadAuth();

    await expect(auth.login('employee@nvsu.edu.ph', 'password', 'Employee'))
      .rejects.toThrow('awaiting setup');
    expect(mocks.auth.signOut).toHaveBeenCalledWith({ scope: 'local' });
  });

  it('maps invalid credentials to a friendly message', async () => {
    mocks.auth.signInWithPassword.mockResolvedValue({
      data: { user: null },
      error: { message: 'Invalid login credentials' }
    });
    const auth = await loadAuth();

    await expect(auth.login('employee@nvsu.edu.ph', 'wrong', 'Employee'))
      .rejects.toThrow('email or password is incorrect');
    expect(auth.authNoticeCode.value).toBe('wrong-credentials');
  });

  it('requires notification email verification before enabling work-update email', async () => {
    mocks.auth.getSession.mockResolvedValue({
      data: { session: { user: { email: 'employee@nvsu.edu.ph' } } },
      error: null
    });
    const auth = await loadAuth();

    await expect(auth.saveSettings({
      email: true,
      notificationEmail: 'updates@example.com',
      notificationEmailVerified: false
    })).rejects.toThrow('Verify your notification email');
    expect(mocks.from).not.toHaveBeenCalledWith('user_preferences');
  });

  it('requests notification verification through the Edge Function', async () => {
    mocks.functions.invoke.mockResolvedValue({ data: { sent: true }, error: null });
    const auth = await loadAuth();

    await expect(auth.requestNotificationEmailVerification(' Updates@Example.com '))
      .resolves.toBeUndefined();
    expect(mocks.functions.invoke).toHaveBeenCalledWith('notification-email-verification', {
      body: { action: 'request', email: 'updates@example.com' }
    });
  });

  it('does not send a client-controlled verified flag when saving notification preferences', async () => {
    mocks.auth.getSession.mockResolvedValue({
      data: { session: { user: { email: 'employee@nvsu.edu.ph' } } },
      error: null
    });
    const auth = await loadAuth();

    await auth.saveSettings({
      email: false,
      notificationEmail: 'updates@example.com',
      notificationEmailVerified: false,
      inapp: true,
      sms: false,
      urgentAlerts: false,
      landing: 'dashboard',
      timeout: '30'
    });

    const payload = mocks.from.mock.results.at(-1).value.upsert.mock.calls[0][0];
    expect(payload.notification_email).toBe('updates@example.com');
    expect(payload).not.toHaveProperty('notification_email_verified');
  });
});
