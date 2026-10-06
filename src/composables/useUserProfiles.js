import { ref } from 'vue';
import { isDemoMode, isSupabaseConfigured, supabase } from '../lib/supabase.js';
import { canTransitionRegistrationStatus } from '../lib/authFlow.js';

const STORAGE_KEY = 'unifix-user-profiles-v1';
const roles = ['Admin', 'Assistant', 'Employee', 'Personnel'];

const demoProfiles = [
  { id: 'admin-user', name: 'Admin User', email: 'admin.user@nvsu.edu.ph', role: 'Admin', department: 'CIT', phone: '', location: 'Bambang Campus', isActive: true },
  { id: 'admin-assistant', name: 'Admin Assistant', email: 'admin.assistant@nvsu.edu.ph', role: 'Assistant', department: 'CAS', phone: '', location: 'Bambang Campus', isActive: true },
  { id: 'employee-user', name: 'Prof. Reyes', email: 'prof.reyes@nvsu.edu.ph', role: 'Employee', department: 'COE', phone: '', location: 'Bambang Campus', isActive: true },
  { id: 'personnel-user', name: 'Juan dela Cruz', email: 'juan.delacruz@nvsu.edu.ph', role: 'Personnel', department: 'CTE', phone: '', location: 'Bambang Campus', isActive: true }
];

function loadLocalProfiles() {
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    return saved ? JSON.parse(saved).filter((profile) => profile.role !== 'Student') : demoProfiles;
  } catch (error) {
    console.warn('Failed loading local user profiles', error);
    return demoProfiles;
  }
}

const profiles = ref(loadLocalProfiles());
const profilesLoadError = ref('');
const reapplicationsLoadError = ref('');

function toProfile(row) {
  return {
    id: row.id,
    authUserId: row.auth_user_id || null,
    name: row.name,
    email: row.email,
    role: row.role,
    requestedRole: row.requested_role || 'Employee',
    department: ['CIT', 'CAS', 'COE', 'CTE'].includes(row.department) ? row.department : '',
    phone: row.phone || '',
    location: 'Bambang Campus',
    isActive: row.is_active ?? row.isActive ?? true,
    registrationStatus: row.registration_status || row.registrationStatus || 'approved',
    rejectionReason: row.rejection_reason || '',
    reapplicationRequestedAt: row.reapplicationRequestedAt || ''
  };
}

function toDatabaseProfile(profile) {
  return {
    id: profile.id,
    name: profile.name,
    email: profile.email,
    role: profile.role,
    department: profile.department,
    phone: profile.phone,
    location: 'Bambang Campus',
    is_active: profile.isActive,
    registration_status: profile.registrationStatus || 'approved',
    updated_at: new Date().toISOString()
  };
}

async function loadProfiles() {
  if (!isSupabaseConfigured) {
    profilesLoadError.value = '';
    reapplicationsLoadError.value = '';
    return;
  }
  const { data, error } = await supabase.from('user_profiles').select('*').order('name');
  if (error) {
    profilesLoadError.value = error.message || 'User profiles could not be loaded.';
    console.warn('Failed loading user profiles from Supabase', error);
    throw error;
  }
  profiles.value = (data || [])
    .map(toProfile)
    .filter((profile) => profile.role !== 'Student');
  profilesLoadError.value = '';

  const { data: reapplications, error: reapplicationError } = await supabase
    .from('account_reapplication_requests')
    .select('auth_user_id,profile_id,requested_at,reviewed_at')
    .is('reviewed_at', null);
  if (reapplicationError) {
    reapplicationsLoadError.value = reapplicationError.message || 'Re-application details could not be loaded.';
    console.warn('Failed loading re-application requests from Supabase', reapplicationError);
    return;
  }
  reapplicationsLoadError.value = '';
  const requestedAtByProfile = new Map((reapplications || []).map((request) => [
    request.profile_id,
    request.requested_at
  ]));
  profiles.value = profiles.value.map((profile) => ({
    ...profile,
    reapplicationRequestedAt: requestedAtByProfile.get(profile.id) || ''
  }));
}

function saveLocal() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(profiles.value));
}

async function inviteUser(profileData) {
  if (isDemoMode) {
    const profile = {
      id: crypto.randomUUID(),
      ...profileData,
      isActive: true,
      registrationStatus: 'approved',
      demoInvite: true
    };
    profiles.value.push(profile);
    saveLocal();
    return profile;
  }
  if (!isSupabaseConfigured || !supabase) {
    throw new Error('User invitations are unavailable until Supabase is configured.');
  }
  const { data, error } = await supabase.functions.invoke('admin-create-user', {
    body: {
      name: profileData.name,
      email: profileData.email,
      role: profileData.role,
      department: profileData.department,
      phone: profileData.phone,
      location: profileData.location
    }
  });
  if (error) {
    let message = error.message;
    if (error.context) {
      try {
        const response = await error.context.clone().json();
        if (response?.error) message = response.error;
      } catch {
        // Preserve the Supabase Function error when its response is not JSON.
      }
    }
    throw new Error(message || 'Unable to send the invitation.');
  }
  await loadProfiles();
  return data;
}

async function updateProfile(profileData) {
  const index = profiles.value.findIndex((profile) => profile.id === profileData.id);
  if (index === -1) return null;
  const updatedProfile = { ...profiles.value[index], ...profileData };
  if (isSupabaseConfigured) {
    const { error } = await supabase.from('user_profiles').update(toDatabaseProfile(updatedProfile)).eq('id', profileData.id);
    if (error) throw error;
  }
  profiles.value[index] = updatedProfile;
  saveLocal();
  return updatedProfile;
}

async function setProfileActive(profileId, isActive) {
  const profile = profiles.value.find((item) => item.id === profileId);
  if (!profile) return null;
  if (isActive && profile.registrationStatus !== 'approved') {
    throw new Error('Only an approved account can be reactivated. Rejected applications must be reopened first.');
  }
  const changes = { is_active: isActive, updated_at: new Date().toISOString() };
  if (isSupabaseConfigured) {
    const { error } = await supabase.from('user_profiles').update(changes).eq('id', profileId);
    if (error) throw error;
  }
  profile.isActive = isActive;
  saveLocal();
  return profile;
}

async function reviewRegistration(profileId, status, role, rejectionReason = '') {
  if (!['approved', 'rejected'].includes(status)) {
    throw new Error('Choose whether to approve or reject this registration.');
  }
  if (!canTransitionRegistrationStatus('pending', status)) {
    throw new Error('This registration cannot make that status transition.');
  }
  if (status === 'approved' && !roles.includes(role)) {
    throw new Error('Choose a valid role before approving this account.');
  }
  if (status === 'rejected' && !rejectionReason.trim()) {
    throw new Error('A reason is required when rejecting an application.');
  }
  const profile = profiles.value.find((item) => item.id === profileId);
  if (!profile || profile.registrationStatus !== 'pending') return null;

  const changes = {
    registration_status: status,
    is_active: status === 'approved',
    ...(status === 'approved' ? { role } : {}),
    rejection_reason: status === 'rejected' ? rejectionReason.trim() : null,
    updated_at: new Date().toISOString()
  };
  if (isSupabaseConfigured) {
    const { error } = await supabase.from('user_profiles').update(changes).eq('id', profileId);
    if (error) throw error;
  }

  profile.registrationStatus = status;
  profile.isActive = status === 'approved';
  profile.rejectionReason = status === 'rejected' ? rejectionReason.trim() : '';
  if (status === 'approved') profile.role = role;
  saveLocal();
  return profile;
}

async function reopenRegistration(profileId) {
  const profile = profiles.value.find((item) => item.id === profileId);
  if (!profile || !canTransitionRegistrationStatus(profile.registrationStatus, 'pending')) {
    throw new Error('Only a rejected application can be reopened.');
  }
  if (!isDemoMode && !profile.reapplicationRequestedAt) {
    throw new Error('The applicant must request a new review before the application is reopened.');
  }
  if (isDemoMode) {
    profile.registrationStatus = 'pending';
    profile.isActive = false;
    profile.rejectionReason = '';
    profile.reapplicationRequestedAt = '';
    saveLocal();
    return profile;
  }
  if (!isSupabaseConfigured || !supabase) throw new Error('Application review is unavailable.');
  const { error } = await supabase.rpc('reopen_rejected_registration', { p_profile_id: profileId });
  if (error) throw error;
  await loadProfiles();
  return profiles.value.find((item) => item.id === profileId) || null;
}

async function deleteUserAccount(authUserId, profileId) {
  if (isDemoMode) {
    profiles.value = profiles.value.filter((profile) => profile.id !== profileId);
    saveLocal();
    return { deleted: true, demo: true };
  }
  if (!isSupabaseConfigured || !supabase) throw new Error('Account deletion is unavailable.');
  const { error } = await supabase.functions.invoke('admin-create-user', {
    body: { action: 'delete', authUserId }
  });
  if (error) {
    let message = error.message;
    if (error.context) {
      try {
        const response = await error.context.clone().json();
        if (response?.error) message = response.error;
      } catch {
        // Keep the original Functions error if the response is not JSON.
      }
    }
    throw new Error(message || 'Unable to delete this account.');
  }
  await loadProfiles();
  return { deleted: true, demo: false };
}

export function useUserProfiles() {
  return {
    profiles,
    profilesLoadError,
    reapplicationsLoadError,
    roles,
    loadProfiles,
    inviteUser,
    updateProfile,
    setProfileActive,
    reviewRegistration,
    reopenRegistration,
    deleteUserAccount
  };
}
