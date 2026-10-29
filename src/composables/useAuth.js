import { ref, computed } from 'vue';
import { isDemoMode, isSupabaseConfigured, supabase } from '../lib/supabase.js';
import { hasAdminAccess } from '../lib/access.js';
import {
  accountAccessState,
  authStateMessage,
  classifyAuthError
} from '../lib/authFlow.js';
import { getPublicFunctionErrorMessage } from '../lib/publicFunctionErrors.js';

// Private module-level state
const _currentRole = ref('Admin');
const _activeUserName = ref('');
const _activeUserEmail = ref('');
const _activeUserProfile = ref(null);
const _isAuthenticated = ref(false);
const _authNotice = ref('');
const _authNoticeCode = ref('');
const loginHistoryError = ref('');
const LOGIN_EVENTS_KEY = 'unifix-login-events-v1';
const LOGIN_HISTORY_POLL_INTERVAL = 10_000;
let authProfileGeneration = 0;
let profileChannel = null;
let suppressAuthProfileLoad = false;
let loginEventsChannel = null;
let loginEventsRetryTimer = null;
let loginEventsPollTimer = null;
let loginEventsRetryAttempt = 0;
let loginEventsSubscriptionWanted = false;
let loginEventsLoadGeneration = 0;
let loginEventsRequestGeneration = 0;
const LOGIN_HISTORY_TIME_ZONE = 'Asia/Manila';

function loadLoginEvents() {
  try {
    const saved = localStorage.getItem(LOGIN_EVENTS_KEY);
    return saved ? JSON.parse(saved) : [];
  } catch (e) {
    console.warn('Failed loading login events', e);
    return [];
  }
}

const loginEvents = ref(isSupabaseConfigured ? [] : loadLoginEvents());

function mapLoginEvent(event) {
  const timestamp = new Date(event.logged_in_at).getTime();
  const date = Number.isNaN(timestamp)
    ? 'Unknown date'
    : new Intl.DateTimeFormat(undefined, {
        year: 'numeric',
        month: 'short',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit',
        timeZone: LOGIN_HISTORY_TIME_ZONE,
        timeZoneName: 'short'
      }).format(timestamp);
  return {
    id: event.id,
    type: 'LOGIN',
    title: event.user_name,
    date,
    timestamp: Number.isNaN(timestamp) ? 0 : timestamp,
    statusClass: 'resolved',
    statusLabel: 'Successful',
    details: `${event.role} signed in with ${event.email}`
  };
}

function upsertLoginEvent(event) {
  if (!event?.id || !event.logged_in_at) return;
  loginEventsRequestGeneration += 1;
  const mappedEvent = mapLoginEvent(event);
  loginEvents.value = [mappedEvent, ...loginEvents.value.filter((item) => item.id !== mappedEvent.id)]
    .sort((left, right) => right.timestamp - left.timestamp)
    .slice(0, 500);
}

function applyRealtimeLoginEvent(event) {
  upsertLoginEvent(event);
  if (!event?.id || !event.logged_in_at) return;
  void loadLoginEventsFromSupabase().catch((error) => {
    console.error('Could not refresh login history after a realtime update.', error);
  });
}

async function loadLoginEventsFromSupabase() {
  if (!isSupabaseConfigured) return;
  const generation = ++loginEventsLoadGeneration;
  const requestGeneration = ++loginEventsRequestGeneration;
  const { data, error } = await supabase.rpc('get_admin_login_history');
  if (error) {
    if (generation === loginEventsLoadGeneration && requestGeneration === loginEventsRequestGeneration) {
      loginHistoryError.value = 'Login history could not be loaded. Please retry.';
    }
    throw error;
  }
  if (generation !== loginEventsLoadGeneration || requestGeneration !== loginEventsRequestGeneration) return;
  loginHistoryError.value = '';
  const history = new Map(loginEvents.value.map((event) => [event.id, event]));
  for (const event of data || []) {
    const mappedEvent = mapLoginEvent(event);
    history.set(mappedEvent.id, mappedEvent);
  }
  loginEvents.value = [...history.values()]
    .sort((left, right) => right.timestamp - left.timestamp)
    .slice(0, 500);
}

function stopLoginEventsSubscription() {
  loginEventsSubscriptionWanted = false;
  loginEventsRetryAttempt = 0;
  if (loginEventsRetryTimer) {
    clearTimeout(loginEventsRetryTimer);
    loginEventsRetryTimer = null;
  }
  if (loginEventsPollTimer) {
    clearTimeout(loginEventsPollTimer);
    loginEventsPollTimer = null;
  }
  if (loginEventsChannel) {
    void supabase.removeChannel(loginEventsChannel).catch((error) => {
      console.error('Could not stop the login events realtime subscription.', error);
    });
    loginEventsChannel = null;
  }
}

async function refreshLoginEvents() {
  try {
    await loadLoginEventsFromSupabase();
  } catch (error) {
    console.error('Could not refresh login history.', error);
  }
}

function scheduleLoginEventsRefresh() {
  if (!loginEventsSubscriptionWanted || loginEventsPollTimer) return;
  loginEventsPollTimer = setTimeout(async () => {
    loginEventsPollTimer = null;
    if (!loginEventsSubscriptionWanted || !hasAdminAccess(_currentRole.value) || !_isAuthenticated.value) return;
    await refreshLoginEvents();
    scheduleLoginEventsRefresh();
  }, LOGIN_HISTORY_POLL_INTERVAL);
}

function scheduleLoginEventsRetry() {
  if (!loginEventsSubscriptionWanted || loginEventsRetryTimer) return;
  const delay = Math.min(1000 * (2 ** loginEventsRetryAttempt), 30_000);
  loginEventsRetryAttempt += 1;
  loginEventsRetryTimer = setTimeout(() => {
    loginEventsRetryTimer = null;
    subscribeToLoginEvents();
  }, delay);
}

function subscribeToLoginEvents() {
  loginEventsSubscriptionWanted = true;
  if (!isSupabaseConfigured || !hasAdminAccess(_currentRole.value) || !_isAuthenticated.value || loginEventsChannel) return;
  scheduleLoginEventsRefresh();

  const channel = supabase
    .channel('login-events-live-updates')
    .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'login_events' }, (payload) => {
      applyRealtimeLoginEvent(payload.new);
    })
    .subscribe((status) => {
      if (status === 'SUBSCRIBED') {
        loginEventsRetryAttempt = 0;
        void loadLoginEventsFromSupabase().catch((error) => {
          console.error('Could not load login history after subscribing to updates.', error);
        });
      }
      if (['CHANNEL_ERROR', 'TIMED_OUT', 'CLOSED'].includes(status)) {
        console.error(`Login events realtime subscription lost: ${status}. Reconnecting.`);
        if (loginEventsChannel === channel) loginEventsChannel = null;
        void supabase.removeChannel(channel).catch((error) => {
          console.error('Could not remove the failed login events realtime channel.', error);
        });
        scheduleLoginEventsRetry();
      }
    });
  loginEventsChannel = channel;
}

async function recordLoginEvent(profile) {
  const { data, error } = await supabase.rpc('record_login_event');
  if (error) {
    loginHistoryError.value = 'This sign-in could not be added to login history.';
    console.error('Could not record the successful login in the activity log.', error);
    throw error;
  }
  if (hasAdminAccess(profile.role)) {
    const event = Array.isArray(data) ? data[0] : data;
    if (event) upsertLoginEvent(event);
    void loadLoginEventsFromSupabase().catch((loadError) => {
      console.error('Could not refresh login history after recording the Admin sign-in.', loadError);
    });
  }
}

const roleInitials = {
  Student: 'S',
  Employee: 'E',
  Assistant: 'A',
  Admin: 'A',
  Personnel: 'P'
};

const defaultSettings = {
  email: false,
  notificationEmail: '',
  notificationEmailVerified: false,
  inapp: true,
  sms: false,
  urgentAlerts: false,
  landing: 'dashboard',
  timeout: '30'
};

async function loadAuthenticatedProfile() {
  if (!isSupabaseConfigured) return;
  const generation = ++authProfileGeneration;
  const { data: sessionData, error: sessionError } = await supabase.auth.getSession();
  if (sessionError) throw sessionError;
  const user = sessionData.session?.user;
  if (!user) {
    if (generation === authProfileGeneration) {
      _isAuthenticated.value = false;
      _activeUserEmail.value = '';
      _activeUserProfile.value = null;
      _currentRole.value = 'Admin';
      _activeUserName.value = '';
    }
    return;
  }

  const { profile, error } = await findProfileForUser(user);
  if (generation !== authProfileGeneration) return;
  if (error) {
    await endSessionWithNotice('profile-service-unavailable');
    return;
  }
  const state = accountAccessState(profile);
  if (state !== 'active') {
    endNotice(state, profile);
    await endLocalSession();
    return;
  }
  _currentRole.value = profile.role;
  _activeUserName.value = profile.name;
  _activeUserEmail.value = user.email || '';
  _activeUserProfile.value = profile;
  _isAuthenticated.value = true;
  clearNotice();
  subscribeToProfile(user);
  if (hasAdminAccess(_currentRole.value)) subscribeToLoginEvents();
  else stopLoginEventsSubscription();
}

if (isSupabaseConfigured) {
  supabase.auth.onAuthStateChange((event, session) => {
    if (event === 'SIGNED_OUT' || !session?.user) {
      authProfileGeneration += 1;
      _isAuthenticated.value = false;
      _activeUserEmail.value = '';
      _activeUserProfile.value = null;
      _currentRole.value = 'Admin';
      _activeUserName.value = '';
      stopProfileSubscription();
      stopLoginEventsSubscription();
      return;
    }
    if (event === 'PASSWORD_RECOVERY') {
      _authNoticeCode.value = 'password-recovery-disabled';
      _authNotice.value = 'Password recovery is handled in person by campus administration. Visit the campus office for assistance.';
      _isAuthenticated.value = false;
      _currentRole.value = 'Admin';
      _activeUserName.value = '';
      _activeUserEmail.value = session.user.email || '';
      _activeUserProfile.value = null;
      queueMicrotask(() => {
        void supabase.auth.signOut({ scope: 'local' })
          .then(({ error }) => {
            if (error) console.error('Could not end a retired password recovery session.', error);
          })
          .catch((error) => console.error('Could not end a retired password recovery session.', error));
      });
      return;
    }
    if (suppressAuthProfileLoad) return;
    if (['INITIAL_SESSION', 'SIGNED_IN', 'TOKEN_REFRESHED', 'USER_UPDATED'].includes(event)) {
      queueMicrotask(() => {
        void loadAuthenticatedProfile().catch((error) => {
          console.error('Could not restore the signed-in UNIFIX profile.', error);
          void endSessionWithNotice('profile-service-unavailable');
        });
      });
    }
  });
}

async function findProfileForUser(user) {
  let { data: profile, error } = await supabase
    .from('user_profiles')
    .select('name,email,role,department,phone,location,is_active,registration_status,rejection_reason,auth_user_id')
    .eq('auth_user_id', user.id)
    .maybeSingle();
  if (!error && !profile && user.email) {
    const legacyResult = await supabase
      .from('user_profiles')
      .select('name,email,role,department,phone,location,is_active,registration_status,rejection_reason,auth_user_id')
      .is('auth_user_id', null)
      .eq('email', user.email)
      .maybeSingle();
    profile = legacyResult.data;
    error = legacyResult.error;
  }
  return { profile, error };
}

function endNotice(code, profile = null) {
  _authNoticeCode.value = code;
  _authNotice.value = authStateMessage(code, profile);
}

function clearNotice() {
  _authNoticeCode.value = '';
  _authNotice.value = '';
}

async function endLocalSession() {
  const { error } = await supabase.auth.signOut({ scope: 'local' });
  if (error) {
    console.error('Could not end an inactive UNIFIX session.', error);
    endNotice('profile-service-unavailable');
  }
}

async function endSessionWithNotice(code, profile = null) {
  endNotice(code, profile);
  await endLocalSession();
}

function stopProfileSubscription() {
  if (profileChannel) {
    void supabase.removeChannel(profileChannel);
    profileChannel = null;
  }
}

function subscribeToProfile(user) {
  stopProfileSubscription();
  profileChannel = supabase
    .channel(`unifix-profile:${user.id || user.email}`)
    .on('postgres_changes', {
      event: '*',
      schema: 'public',
      table: 'user_profiles',
      filter: `auth_user_id=eq.${user.id}`
    }, () => {
      void loadAuthenticatedProfile().catch((error) => {
        console.error('Could not refresh the signed-in UNIFIX profile.', error);
        void endSessionWithNotice('profile-service-unavailable');
      });
    })
    .on('postgres_changes', {
      event: '*',
      schema: 'public',
      table: 'user_profiles',
      filter: `email=eq.${user.email}`
    }, () => {
      void loadAuthenticatedProfile().catch((error) => {
        console.error('Could not refresh the signed-in UNIFIX profile.', error);
        void endSessionWithNotice('profile-service-unavailable');
      });
    })
    .subscribe();
}

export function useAuth() {
  const userInitials = computed(() => {
    return (
      _activeUserName.value
        .split(' ')
        .filter(Boolean)
        .slice(0, 2)
        .map((part) => part[0].toUpperCase())
        .join('') || roleInitials[_currentRole.value] || 'AU'
    );
  });

  function displayNameFromEmail(email) {
    return String(email || '')
      .split('@')[0]
      .split(/[._-]+/)
      .filter(Boolean)
      .map((part) => `${part.charAt(0).toUpperCase()}${part.slice(1).toLowerCase()}`)
      .join(' ');
  }

  async function login(email, password, role) {
    clearNotice();
    if (isSupabaseConfigured) {
      authProfileGeneration += 1;
      stopProfileSubscription();
      suppressAuthProfileLoad = true;
      try {
        const { data, error } = await supabase.auth.signInWithPassword({
          email: email.trim(),
          password
        });
        if (error) {
          const state = classifyAuthError(error);
          endNotice(state);
          throw new Error(authStateMessage(state));
        }

        const { profile, error: profileError } = await findProfileForUser(data.user);
        if (profileError) {
          await endSessionWithNotice('profile-service-unavailable');
          throw new Error(authStateMessage('profile-service-unavailable'));
        }
        const state = accountAccessState(profile);
        if (state !== 'active') {
          await endSessionWithNotice(state, profile);
          throw new Error(authStateMessage(state, profile));
        }
        _currentRole.value = profile.role;
        _activeUserName.value = profile.name;
        _activeUserEmail.value = data.user.email || '';
        _activeUserProfile.value = profile;
        _isAuthenticated.value = true;
        clearNotice();
        subscribeToProfile(data.user);
        if (hasAdminAccess(profile.role)) {
          subscribeToLoginEvents();
          void recordLoginEvent(profile).catch((error) => {
            console.error('Could not record the successful login in the activity log.', error);
          });
        } else {
          stopLoginEventsSubscription();
          void recordLoginEvent(profile).catch((error) => {
            console.error('Could not record the successful login in the activity log.', error);
          });
        }
        return profile.role;
      } finally {
        suppressAuthProfileLoad = false;
      }
    }

    if (!isDemoMode) {
      endNotice('network-error');
      throw new Error(authStateMessage('network-error'));
    }

    _currentRole.value = role;
    _activeUserName.value = displayNameFromEmail(email) || 'User';
    _activeUserEmail.value = email.trim().toLowerCase();
    _activeUserProfile.value = null;
    _isAuthenticated.value = true;

    const event = {
      id: `LOGIN-${Date.now()}`,
      type: 'LOGIN',
      title: _activeUserName.value,
      date: new Date().toLocaleString(),
      timestamp: Date.now(),
      statusClass: 'resolved',
      statusLabel: 'Successful',
      details: `${role} signed in with ${email.trim()}`
    };
    loginEvents.value.unshift(event);
    loginEvents.value = loginEvents.value.slice(0, 100);
    localStorage.setItem(LOGIN_EVENTS_KEY, JSON.stringify(loginEvents.value));
  }

  async function requestRegistrationReapplication(email, password) {
    if (!isSupabaseConfigured || !supabase) throw new Error('Re-application is unavailable.');
    suppressAuthProfileLoad = true;
    let signedInForRequest = false;
    try {
      const { data, error } = await supabase.auth.signInWithPassword({ email: email.trim(), password });
      if (error) {
        const state = classifyAuthError(error);
        endNotice(state);
        throw new Error(authStateMessage(state));
      }
      signedInForRequest = true;
      const { profile, error: profileError } = await findProfileForUser(data.user);
      if (profileError) throw new Error(authStateMessage('profile-service-unavailable'));
      if (accountAccessState(profile) !== 'rejected') {
        throw new Error('Only rejected applications may request another review.');
      }
      const { error: requestError } = await supabase.rpc('request_registration_reapplication');
      if (requestError) {
        throw new Error(/30 days/i.test(requestError.message || '')
          ? 'You may request another application review once every 30 days.'
          : 'Your re-application request could not be submitted. Try again later.');
      }
      endNotice('reapplication-requested');
    } finally {
      try {
        if (signedInForRequest) {
          const { error: signOutError } = await supabase.auth.signOut({ scope: 'local' });
          if (signOutError) {
            console.error('Could not end the temporary re-application session.', signOutError);
            endNotice('profile-service-unavailable');
          }
        }
      } catch (signOutError) {
        console.error('Could not end the temporary re-application session.', signOutError);
        endNotice('profile-service-unavailable');
      } finally {
        suppressAuthProfileLoad = false;
      }
    }
  }

  async function changePassword(password) {
    if (!isSupabaseConfigured || !supabase) throw new Error('Password changes are unavailable.');
    if (password.length < 8) throw new Error('Use a password with at least 8 characters.');
    const { error } = await supabase.auth.updateUser({ password });
    if (error) {
      const state = classifyAuthError(error);
      throw new Error(state === 'network-error'
        ? authStateMessage(state)
        : 'The password could not be changed. Please try again.');
    }
  }

  async function logout() {
    if (isSupabaseConfigured) {
      const { error } = await supabase.auth.signOut({ scope: 'local' });
      if (error) throw error;
    }
    _isAuthenticated.value = false;
    _activeUserEmail.value = '';
    _activeUserProfile.value = null;
    _currentRole.value = 'Admin';
    _activeUserName.value = '';
    clearNotice();
    stopProfileSubscription();
  }

  function getProfileKey() {
    return `unifix-profile-${_activeUserEmail.value.toLowerCase()}-${_currentRole.value}`;
  }

  function getSettingsKey() {
    return `unifix-settings-${_activeUserEmail.value.toLowerCase()}-${_currentRole.value}`;
  }

  function loadProfile() {
    let savedProfile = {};
    try {
      const saved = localStorage.getItem(getProfileKey());
      if (saved) savedProfile = JSON.parse(saved);
    } catch (e) {
      console.warn('Failed loading profile', e);
    }
    const userProfile = _activeUserProfile.value;
    return {
      ...savedProfile,
      name: userProfile?.name || savedProfile.name || _activeUserName.value,
      email: _activeUserEmail.value || userProfile?.email || savedProfile.email || '',
      phone: userProfile?.phone ?? savedProfile.phone ?? '',
      dept: userProfile?.department ?? savedProfile.dept ?? '',
      location: userProfile?.location || savedProfile.location || 'Bambang Campus',
      updatedAt: savedProfile.updatedAt || 'Not yet'
    };
  }

  async function saveProfile(profileData) {
    const updated = {
      ...profileData,
      updatedAt: new Date().toLocaleString()
    };
    _activeUserName.value = updated.name;
    _activeUserProfile.value = {
      ..._activeUserProfile.value,
      name: updated.name,
      email: updated.email,
      department: updated.dept,
      phone: updated.phone,
      location: updated.location
    };
    localStorage.setItem(getProfileKey(), JSON.stringify(updated));

    if (isSupabaseConfigured) {
      const { data: sessionData, error: sessionError } = await supabase.auth.getSession();
      if (sessionError) throw sessionError;
      const authUser = sessionData.session?.user;
      if (!authUser) throw new Error('No signed-in user found.');
      const { data, error } = await supabase
        .from('user_profiles')
        .update({ name: updated.name, phone: updated.phone || '', location: 'Bambang Campus' })
        .eq('auth_user_id', authUser.id)
        .select('id')
        .maybeSingle();
      if (error) throw error;
      if (!data) {
        const { error: legacyError } = await supabase
          .from('user_profiles')
          .update({ name: updated.name, phone: updated.phone || '', location: 'Bambang Campus' })
          .is('auth_user_id', null)
          .eq('email', authUser.email || '')
          .select('id')
          .maybeSingle();
        if (legacyError) throw legacyError;
      }
    }
    return updated;
  }

  function loadSettings() {
    try {
      const saved = localStorage.getItem(getSettingsKey());
      if (saved) {
        const parsed = JSON.parse(saved);
        return {
          ...defaultSettings,
          ...parsed,
          urgentAlerts: parsed.urgentAlerts ?? parsed.sms ?? false,
          sms: parsed.urgentAlerts === undefined ? false : (parsed.sms ?? false)
        };
      }
    } catch (e) {
      console.warn('Failed loading settings', e);
    }
    return { ...defaultSettings };
  }

  async function fetchSettings() {
    if (!isSupabaseConfigured) return loadSettings();
    const { data: sessionData } = await supabase.auth.getSession();
    const email = sessionData.session?.user?.email;
    if (!email) return loadSettings();

    const { data, error } = await supabase
      .from('user_preferences')
      .select('*')
      .eq('user_email', email)
      .maybeSingle();
    if (error) throw error;
    if (!data) return loadSettings();

    const settings = {
      email: data.email_notifications,
      notificationEmail: data.notification_email || '',
      notificationEmailVerified: data.notification_email_verified === true,
      inapp: data.inapp_notifications,
      sms: data.sms_notifications ?? false,
      urgentAlerts: data.urgent_alerts,
      landing: data.landing_page,
      timeout: data.session_timeout
    };
    localStorage.setItem(getSettingsKey(), JSON.stringify(settings));
    return settings;
  }

  async function saveSettings(settingsData) {
    if (!isSupabaseConfigured) {
      localStorage.setItem(getSettingsKey(), JSON.stringify(settingsData));
      return;
    }
    const { data: sessionData } = await supabase.auth.getSession();
    const email = sessionData.session?.user?.email;
    if (!email) throw new Error('No signed-in user found.');
    if (settingsData.email && !settingsData.notificationEmailVerified) {
      throw new Error('Verify your notification email before enabling email updates.');
    }
    const { error } = await supabase.from('user_preferences').upsert({
      user_email: email,
      notification_email: settingsData.notificationEmail?.trim().toLowerCase() || null,
      email_notifications: settingsData.email,
      inapp_notifications: settingsData.inapp,
      urgent_alerts: settingsData.urgentAlerts,
      sms_notifications: settingsData.sms,
      landing_page: settingsData.landing,
      session_timeout: settingsData.timeout
    });
    if (error) throw error;
    localStorage.setItem(getSettingsKey(), JSON.stringify(settingsData));
  }

  async function requestNotificationEmailVerification(email) {
    if (!isSupabaseConfigured || !supabase) throw new Error('Notification email verification is unavailable.');
    const normalizedEmail = email.trim().toLowerCase();
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(normalizedEmail) || normalizedEmail.length > 254) {
      throw new Error('Enter a valid notification email address.');
    }
    const { error } = await supabase.functions.invoke('notification-email-verification', {
      body: { action: 'request', email: normalizedEmail }
    });
    if (error) {
      let message = error.message;
      if (error.context) {
        try {
          const response = await error.context.clone().json();
          if (response?.error) message = response.error;
        } catch {
          // Preserve the Functions error when its response is not JSON.
        }
      }
      throw new Error(message || 'Could not send the notification email verification link.');
    }
  }

  async function verifyNotificationEmail(token) {
    if (!isSupabaseConfigured || !supabase) throw new Error('Notification email verification is unavailable.');
    const { data, error } = await supabase.functions.invoke('notification-email-verification', {
      body: { action: 'verify', token }
    });
    if (error || !data?.verified) {
      let message = error?.message;
      if (error?.context) {
        try {
          const response = await error.context.clone().json();
          if (response?.error) message = response.error;
        } catch {
          // Preserve the Functions error when its response is not JSON.
        }
      }
      throw new Error(message || 'This verification link is invalid or expired. Request a new one in Settings.');
    }
    return data.email;
  }

  function resetSettings() {
    localStorage.removeItem(getSettingsKey());
    return { ...defaultSettings };
  }

  return {
    currentRole: _currentRole,
    activeUserName: _activeUserName,
    activeUserEmail: _activeUserEmail,
    authNotice: _authNotice,
    authNoticeCode: _authNoticeCode,
    isAuthenticated: _isAuthenticated,
    userInitials,
    login,
    requestRegistrationReapplication,
    requestNotificationEmailVerification,
    verifyNotificationEmail,
    changePassword,
    logout,
    loadProfile,
    saveProfile,
    loadSettings,
    fetchSettings,
    saveSettings,
    resetSettings,
    loginEvents,
    loginHistoryError,
    refreshLoginEvents,
  };
}
