import { ref, computed } from 'vue';
import { isSupabaseConfigured, supabase } from '../lib/supabase.js';

// Private module-level state
const _currentRole = ref('Admin');
const _activeUserName = ref('Admin User');
const _isAuthenticated = ref(false);
const LOGIN_EVENTS_KEY = 'unifix-login-events-v1';

function loadLoginEvents() {
  try {
    const saved = localStorage.getItem(LOGIN_EVENTS_KEY);
    return saved ? JSON.parse(saved) : [];
  } catch (e) {
    console.warn('Failed loading login events', e);
    return [];
  }
}

const loginEvents = ref(loadLoginEvents());

async function loadLoginEventsFromSupabase() {
  if (!isSupabaseConfigured) return;
  const { data, error } = await supabase
    .from('login_events')
    .select('*')
    .order('logged_in_at', { ascending: false })
    .limit(100);
  if (error) {
    console.warn('Failed loading login events from Supabase', error);
    return;
  }
  if (data?.length) {
    loginEvents.value = data.map((event) => ({
      id: event.id,
      type: 'LOGIN',
      title: event.user_name,
      date: new Date(event.logged_in_at).toLocaleString(),
      timestamp: new Date(event.logged_in_at).getTime(),
      statusClass: 'resolved',
      statusLabel: 'Successful',
      details: `${event.role} signed in with ${event.email}`
    }));
  }
}

void loadLoginEventsFromSupabase();

const roleNames = {
  Employee: 'Prof. Reyes',
  Assistant: 'Admin Assistant',
  Admin: 'Admin User',
  Personnel: 'Juan dela Cruz'
};

const roleInitials = {
  Employee: 'PR',
  Assistant: 'AA',
  Admin: 'AU',
  Personnel: 'JD'
};

const roleEmails = {
  Employee: 'prof.reyes@nvsu.edu.ph',
  Assistant: 'admin.assistant@nvsu.edu.ph',
  Admin: 'admin.user@nvsu.edu.ph',
  Personnel: 'juan.delacruz@nvsu.edu.ph'
};

const roleDepts = {
  Employee: 'College of Engineering',
  Assistant: 'Campus Administration',
  Admin: 'Campus Administration',
  Personnel: 'Maintenance Operations'
};

const defaultSettings = {
  email: true,
  inapp: true,
  sms: false,
  landing: 'dashboard',
  timeout: '30'
};

async function loadAuthenticatedProfile() {
  if (!isSupabaseConfigured) return;
  const { data: sessionData } = await supabase.auth.getSession();
  const user = sessionData.session?.user;
  if (!user) return;

  const { data: profile, error } = await supabase
    .from('user_profiles')
    .select('name, email, role, is_active')
    .eq('email', user.email)
    .single();
  if (error || !profile?.is_active) {
    await supabase.auth.signOut();
    return;
  }
  _currentRole.value = profile.role;
  _activeUserName.value = profile.name;
  _isAuthenticated.value = true;
}

void loadAuthenticatedProfile();

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

  function resolvePersonnelName(email, technicians = []) {
    const typed = (email || '').trim().toLowerCase();
    const match = technicians.find((t) => {
      const normalized = `${t.name.toLowerCase().replace(/\s+/g, '.')}@nvsu.edu.ph`;
      return normalized === typed;
    });
    return match ? match.name : roleNames.Personnel;
  }

  async function login(email, password, role, technicians = []) {
    if (isSupabaseConfigured) {
      const { data, error } = await supabase.auth.signInWithPassword({
        email: email.trim(),
        password
      });
      if (error) throw error;

      const { data: profile, error: profileError } = await supabase
        .from('user_profiles')
        .select('name, role, is_active')
        .eq('email', data.user.email)
        .single();
      if (profileError || !profile || !profile.is_active) {
        await supabase.auth.signOut();
        throw new Error('This account has no active university profile.');
      }
      if (profile.role === 'Student') {
        await supabase.auth.signOut();
        throw new Error('Student accounts submit reports from the UNIFIX home page.');
      }

      _currentRole.value = profile.role;
      _activeUserName.value = profile.name;
      _isAuthenticated.value = true;
      return profile.role;
    }

    _currentRole.value = role;
    _activeUserName.value =
      role === 'Personnel'
        ? resolvePersonnelName(email, technicians)
        : roleNames[role] || 'User';
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

  async function logout() {
    if (isSupabaseConfigured) await supabase.auth.signOut();
    _isAuthenticated.value = false;
  }

  function getProfileKey() {
    return `unifix-profile-${_currentRole.value}`;
  }

  function getSettingsKey() {
    return `unifix-settings-${_currentRole.value}`;
  }

  function loadProfile() {
    try {
      const saved = localStorage.getItem(getProfileKey());
      if (saved) return JSON.parse(saved);
    } catch (e) {
      console.warn('Failed loading profile', e);
    }
    return {
      name: _activeUserName.value,
      email:
        _currentRole.value === 'Personnel'
          ? `${_activeUserName.value.toLowerCase().replace(/\s+/g, '.')}@nvsu.edu.ph`
          : roleEmails[_currentRole.value] || `${_activeUserName.value.toLowerCase().replace(/\s+/g, '.')}@nvsu.edu.ph`,
      phone: '',
      dept: roleDepts[_currentRole.value] || '',
      location: 'Main Campus',
      updatedAt: 'Not yet'
    };
  }

  async function saveProfile(profileData) {
    const updated = {
      ...profileData,
      updatedAt: new Date().toLocaleString()
    };
    _activeUserName.value = updated.name;
    localStorage.setItem(getProfileKey(), JSON.stringify(updated));

    if (isSupabaseConfigured) {
      const { error } = await supabase
        .from('user_profiles')
        .update({ name: updated.name, phone: updated.phone || '', location: updated.location || 'Main Campus' })
        .eq('email', updated.email);
      if (error) throw error;
    }
    return updated;
  }

  function loadSettings() {
    try {
      const saved = localStorage.getItem(getSettingsKey());
      if (saved) return JSON.parse(saved);
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
      inapp: data.inapp_notifications,
      sms: data.urgent_alerts,
      landing: data.landing_page,
      timeout: data.session_timeout
    };
    localStorage.setItem(getSettingsKey(), JSON.stringify(settings));
    return settings;
  }

  async function saveSettings(settingsData) {
    localStorage.setItem(getSettingsKey(), JSON.stringify(settingsData));
    if (!isSupabaseConfigured) return;
    const { data: sessionData } = await supabase.auth.getSession();
    const email = sessionData.session?.user?.email;
    if (!email) throw new Error('No signed-in user found.');
    const { error } = await supabase.from('user_preferences').upsert({
      user_email: email,
      email_notifications: settingsData.email,
      inapp_notifications: settingsData.inapp,
      urgent_alerts: settingsData.sms,
      landing_page: settingsData.landing,
      session_timeout: settingsData.timeout
    });
    if (error) throw error;
  }

  function resetSettings() {
    localStorage.removeItem(getSettingsKey());
    return { ...defaultSettings };
  }

  return {
    currentRole: _currentRole,
    activeUserName: _activeUserName,
    isAuthenticated: _isAuthenticated,
    userInitials,
    login,
    logout,
    loadProfile,
    saveProfile,
    loadSettings,
    fetchSettings,
    saveSettings,
    resetSettings,
    loginEvents,
  };
}
