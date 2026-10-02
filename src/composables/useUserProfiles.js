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

function toProfile(row) {
  return {
    id: row.id,
    name: row.name,
    email: row.email,
    role: row.role,
    department: row.department || '',
    phone: row.phone || '',
    location: row.location || 'Main Campus',
    isActive: row.is_active ?? row.isActive ?? true
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
    updated_at: new Date().toISOString()
  };
}

async function loadProfiles() {
  if (!isSupabaseConfigured) return;
  const { data, error } = await supabase.from('user_profiles').select('*').order('name');
  if (error) {
    console.warn('Failed loading user profiles from Supabase', error);
    return;
  }
  if (data?.length) profiles.value = data.map(toProfile).filter((profile) => profile.role !== 'Student');
}

function saveLocal() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(profiles.value));
}

async function addProfile(profileData) {
  const profile = {
    id: crypto.randomUUID(),
    ...profileData,
    isActive: true
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
  profile.isActive = isActive;
  saveLocal();
  if (isSupabaseConfigured) {
    const { error } = await supabase.from('user_profiles').update({ is_active: isActive, updated_at: new Date().toISOString() }).eq('id', profileId);
    if (error) throw error;
  }
  return profile;
}

export function useUserProfiles() {
  return { profiles, roles, loadProfiles, addProfile, updateProfile, setProfileActive };
}
