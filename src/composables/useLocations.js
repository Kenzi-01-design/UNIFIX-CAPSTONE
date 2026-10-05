import { computed, ref } from 'vue';
import { isDemoMode, isSupabaseConfigured, supabase } from '../lib/supabase.js';

const STORAGE_KEY = 'unifix-locations-v1';
const demoBuildings = [
  '5 Star CR', 'Academic Classroom Building', 'Administration Building', 'Alumni Building',
  'Arts and Cultural Office', 'Auto Service Center', "Boy's Shop Building", 'Cafeteria',
  'Campus Quadrangle', 'CBA Building', 'CIT Office', 'COE office',
  'College of Arts and Sciences Office', 'College of Arts & Science Building', 'CTE Office',
  'College of Teacher Education Building', 'Electronics Building', 'Engineering Building',
  'Engineering Science Lab Building', 'Food Court', 'Graphic Arts Building', 'Gymnasium',
  'HRM Building', 'IT Lab Building', 'Ladies Dorm',
  'Mechanical Engineering Laboratory Building', 'Motorpool', 'MRF', 'Oval',
  "Oval's Bleachers", 'RAC building', 'Rotary', 'ROTC building',
  'Stalls and Classrooms', 'Technician Institute', 'Technology Lab Building', 'Training Center'
];

function initialDemoLocations() {
  return demoBuildings.map((building, index) => ({
    id: `demo-location-${index + 1}`,
    building,
    floor: '',
    room: '',
    isActive: true
  }));
}

function readDemoLocations() {
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    return saved ? JSON.parse(saved) : initialDemoLocations();
  } catch (error) {
    console.warn('Could not read demo locations from local storage.', error);
    return initialDemoLocations();
  }
}

const locations = ref(!isSupabaseConfigured || isDemoMode ? readDemoLocations() : []);
const loading = ref(false);
const loadError = ref('');

function fromDatabase(row) {
  return {
    id: row.id,
    building: row.building,
    floor: row.floor || '',
    room: row.room || '',
    isActive: row.is_active
  };
}

function persistDemoLocations() {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(locations.value));
  } catch (error) {
    console.warn('Could not save demo locations to local storage.', error);
    throw new Error('Could not save the location in this browser.');
  }
}

function toLocationLabel(location) {
  return [location.building, location.floor, location.room].filter(Boolean).join(' · ');
}

async function loadLocations() {
  if (!isSupabaseConfigured || isDemoMode) return locations.value;
  loading.value = true;
  loadError.value = '';
  try {
    const { data, error } = await supabase.from('locations')
      .select('id, building, floor, room, is_active')
      .order('building')
      .order('floor')
      .order('room');
    if (error) throw error;
    locations.value = (data || []).map(fromDatabase);
    return locations.value;
  } catch (error) {
    loadError.value = error.message || 'Locations could not be loaded.';
    console.error('Failed to load report locations.', error);
    throw error;
  } finally {
    loading.value = false;
  }
}

async function addLocation({ building, floor = '', room = '' }) {
  const entry = {
    building: String(building || '').trim(),
    floor: String(floor || '').trim(),
    room: String(room || '').trim()
  };
  if (!entry.building || entry.building.length > 120 || entry.floor.length > 80 || entry.room.length > 80) {
    throw new Error('Enter a building and keep floor and room labels within 80 characters.');
  }

  if (isSupabaseConfigured && !isDemoMode) {
    const { data, error } = await supabase.from('locations').insert(entry)
      .select('id, building, floor, room, is_active').single();
    if (error) throw error;
    locations.value = [...locations.value, fromDatabase(data)].sort((a, b) => a.building.localeCompare(b.building));
    return data;
  }

  const exists = locations.value.some((location) =>
    location.building.toLowerCase() === entry.building.toLowerCase()
    && location.floor.toLowerCase() === entry.floor.toLowerCase()
    && location.room.toLowerCase() === entry.room.toLowerCase()
  );
  if (exists) throw new Error('That building, floor, and room combination already exists.');
  const location = { id: crypto.randomUUID(), ...entry, isActive: true };
  locations.value = [...locations.value, location].sort((a, b) => a.building.localeCompare(b.building));
  persistDemoLocations();
  return location;
}

async function updateLocation(locationId, { building, floor = '', room = '' }) {
  const location = locations.value.find((item) => item.id === locationId);
  if (!location) throw new Error('The selected location could not be found.');
  const entry = {
    building: String(building || '').trim(),
    floor: String(floor || '').trim(),
    room: String(room || '').trim()
  };
  if (!entry.building || entry.building.length > 120 || entry.floor.length > 80 || entry.room.length > 80) {
    throw new Error('Enter a building and keep floor and room labels within 80 characters.');
  }
  const duplicate = locations.value.some((item) => item.id !== locationId
    && item.building.toLowerCase() === entry.building.toLowerCase()
    && item.floor.toLowerCase() === entry.floor.toLowerCase()
    && item.room.toLowerCase() === entry.room.toLowerCase());
  if (duplicate) throw new Error('That building, floor, and room combination already exists.');
  const previous = { ...location };
  Object.assign(location, entry);
  try {
    if (isSupabaseConfigured && !isDemoMode) {
      const { data, error } = await supabase.from('locations').update(entry).eq('id', locationId)
        .select('id, building, floor, room, is_active').single();
      if (error) throw error;
      Object.assign(location, fromDatabase(data));
    } else {
      persistDemoLocations();
    }
    locations.value = [...locations.value].sort((a, b) => a.building.localeCompare(b.building));
    return location;
  } catch (error) {
    Object.assign(location, previous);
    throw error;
  }
}

async function setLocationActive(locationId, isActive) {
  const location = locations.value.find((item) => item.id === locationId);
  if (!location) throw new Error('The selected location could not be found.');
  const previousValue = location.isActive;
  location.isActive = isActive;
  try {
    if (isSupabaseConfigured && !isDemoMode) {
      const { error } = await supabase.from('locations').update({ is_active: isActive }).eq('id', locationId);
      if (error) throw error;
    } else {
      persistDemoLocations();
    }
  } catch (error) {
    location.isActive = previousValue;
    throw error;
  }
}

async function deleteLocation(locationId) {
  if (isSupabaseConfigured && !isDemoMode) {
    const { error } = await supabase.from('locations').delete().eq('id', locationId);
    if (error) throw error;
  }
  locations.value = locations.value.filter((location) => location.id !== locationId);
  if (isDemoMode || !isSupabaseConfigured) persistDemoLocations();
}

export function useLocations() {
  return {
    locations,
    activeLocations: computed(() => locations.value.filter((location) => location.isActive)),
    loading,
    loadError,
    loadLocations,
    addLocation,
    updateLocation,
    setLocationActive,
    deleteLocation,
    toLocationLabel,
    demoBuildings
  };
}
