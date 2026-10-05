import { ref } from 'vue';
import { isSupabaseConfigured, supabase } from '../lib/supabase.js';

const STORAGE_KEY = 'unifix-user-profiles-v1';
const roles = ['Admin', 'Assistant', 'Employee', 'Personnel'];

const demoProfiles = [
  { id: 'admin-user', name: 'Admin User', email: 'admin.user@nvsu.edu.ph', role: 'Admin', department: 'Campus Administration', phone: '', location: 'Main Campus', isActive: true },
  { id: 'admin-assistant', name: 'Admin Assistant', email: 'admin.assistant@nvsu.edu.ph', role: 'Assistant', department: 'Campus Administration', phone: '', location: 'Main Campus', isActive: true },
  { id: 'employee-user', name: 'Prof. Reyes', email: 'prof.reyes@nvsu.edu.ph', role: 'Employee', department: 'College of Engineering', phone: '', location: 'Main Campus', isActive: true },
  { id: 'personnel-user', name: 'Juan dela Cruz', email: 'juan.delacruz@nvsu.edu.ph', role: 'Personnel', department: 'Maintenance Operations', phone: '', location: 'Main Campus', isActive: true }
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

function toProfile(row) {
  return {
    id: row.id,
    name: row.name,
    email: row.email,
    role: row.role,
    department: row.department || '',
    phone: row.phone || '',
    location: row.location || 'Main Campus',
    isActive: row.is_active ?? row.isActive ?? true,
    registrationStatus: row.registration_status || row.registrationStatus || 'approved'
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
    location: profile.location,
    is_active: profile.isActive,
    registration_status: profile.registrationStatus || 'approved',
    updated_at: new Date().toISOString()
  };
}

async function loadProfiles() {
  if (!isSupabaseConfigured) return;
  const { data, error } = await supabase.from('user_profiles').select('*').order('name');
  if (error) {
    profilesLoadError.value = error.message || 'User profiles could not be loaded.';
    console.warn('Failed loading user profiles from Supabase', error);
    throw error;
  }
  profilesLoadError.value = '';
  profiles.value = (data || []).map(toProfile).filter((profile) => profile.role !== 'Student');
}

function saveLocal() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(profiles.value));
}

async function addProfile(profileData) {
  const profile = {
    id: crypto.randomUUID(),
    ...profileData,
    isActive: true,
    registrationStatus: 'approved'
  };
  profiles.value.push(profile);
  saveLocal();
  if (isSupabaseConfigured) {
    const { error } = await supabase.from('user_profiles').insert(toDatabaseProfile(profile));
    if (error) throw error;
  }
  return profile;
}

async function updateProfile(profileData) {
  const index = profiles.value.findIndex((profile) => profile.id === profileData.id);
  if (index === -1) return null;
  profiles.value[index] = { ...profiles.value[index], ...profileData };
  saveLocal();
  if (isSupabaseConfigured) {
    const { error } = await supabase.from('user_profiles').update(toDatabaseProfile(profiles.value[index])).eq('id', profileData.id);
    if (error) throw error;
  }
  return profiles.value[index];
}

async function setProfileActive(profileId, isActive) {
  const profile = profiles.value.find((item) => item.id === profileId);
  if (!profile) return null;
  const changes = {
    is_active: isActive,
    ...(isActive ? { registration_status: 'approved' } : {}),
    updated_at: new Date().toISOString()
  };
  if (isSupabaseConfigured) {
    const { error } = await supabase.from('user_profiles').update(changes).eq('id', profileId);
    if (error) throw error;
  }
  profile.isActive = isActive;
  if (isActive) profile.registrationStatus = 'approved';
  saveLocal();
  return profile;
}

async function reviewRegistration(profileId, status, role) {
  if (!['approved', 'rejected'].includes(status)) {
    throw new Error('Choose whether to approve or reject this registration.');
  }
  if (status === 'approved' && !roles.includes(role)) {
    throw new Error('Choose a valid role before approving this account.');
  }
  const profile = profiles.value.find((item) => item.id === profileId);
  if (!profile || profile.registrationStatus !== 'pending') return null;

  const changes = {
    registration_status: status,
    is_active: status === 'approved',
    ...(status === 'approved' ? { role } : {}),
    updated_at: new Date().toISOString()
  };
  if (isSupabaseConfigured) {
    const { error } = await supabase.from('user_profiles').update(changes).eq('id', profileId);
    if (error) throw error;
  }

  profile.registrationStatus = status;
  profile.isActive = status === 'approved';
  if (status === 'approved') profile.role = role;
  saveLocal();
  return profile;
}

export function useUserProfiles() {
  return { profiles, profilesLoadError, roles, loadProfiles, addProfile, updateProfile, setProfileActive, reviewRegistration };
}
