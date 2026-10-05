import { ref } from 'vue';
import { isDemoMode, isSupabaseConfigured, supabase } from '../lib/supabase.js';
import { useReports } from './useReports.js';

const STORAGE_KEY = 'unifix-maintenance-schedules-v1';
const schedules = ref([]);
const loading = ref(false);
const loadError = ref('');
let demoSchedulesLoaded = false;

function mapSchedule(row) {
  return {
    id: row.id,
    title: row.title,
    locationId: row.location_id || '',
    locationLabel: row.location_label || '',
    category: row.category,
    frequency: row.frequency,
    customIntervalDays: row.custom_interval_days || '',
    nextDue: row.next_due,
    defaultAssignee: row.default_assignee || '',
    checklistItems: Array.isArray(row.checklist_items) ? row.checklist_items : [],
    isActive: row.is_active
  };
}

function loadDemoSchedules() {
  if (demoSchedulesLoaded) return;
  demoSchedulesLoaded = true;
  try {
    schedules.value = JSON.parse(localStorage.getItem(STORAGE_KEY) || '[]');
  } catch (error) {
    console.warn('Could not read preventive schedules from local storage.', error);
    loadError.value = 'Saved demo schedules could not be read.';
    throw new Error(loadError.value);
  }
}

function saveDemoSchedules() {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(schedules.value));
  } catch (error) {
    console.warn('Could not save preventive schedules to local storage.', error);
    throw new Error('Could not save the schedule in this browser.');
  }
}

function validateSchedule(input) {
  const result = {
    title: String(input.title || '').trim(),
    locationId: input.locationId || null,
    locationLabel: String(input.locationLabel || '').trim(),
    category: String(input.category || '').trim(),
    frequency: input.frequency,
    customIntervalDays: input.frequency === 'custom' ? Number(input.customIntervalDays) : null,
    nextDue: input.nextDue,
    defaultAssignee: String(input.defaultAssignee || '').trim(),
    checklistItems: Array.isArray(input.checklistItems)
      ? input.checklistItems.map((item) => String(item).trim()).filter(Boolean).slice(0, 30)
      : []
  };
  if (!result.title || result.title.length > 180 || !result.category || result.category.length > 80) {
    throw new Error('Provide a schedule title and category within the allowed lengths.');
  }
  if (!['weekly', 'monthly', 'quarterly', 'yearly', 'custom'].includes(result.frequency)) {
    throw new Error('Choose a valid maintenance frequency.');
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(result.nextDue) || Number.isNaN(Date.parse(`${result.nextDue}T00:00:00`))) {
    throw new Error('Choose a valid next-due date.');
  }
  if (result.frequency === 'custom'
      && (!Number.isInteger(result.customIntervalDays) || result.customIntervalDays < 1 || result.customIntervalDays > 3650)) {
    throw new Error('Custom schedules must repeat every 1 to 3650 days.');
  }
  return result;
}

function databasePayload(schedule) {
  return {
    title: schedule.title,
    location_id: schedule.locationId,
    location_label: schedule.locationLabel,
    category: schedule.category,
    frequency: schedule.frequency,
    custom_interval_days: schedule.customIntervalDays,
    next_due: schedule.nextDue,
    default_assignee: schedule.defaultAssignee,
    checklist_items: schedule.checklistItems,
    is_active: schedule.isActive ?? true
  };
}

async function loadSchedules() {
  if (!isSupabaseConfigured || isDemoMode) {
    loadDemoSchedules();
    return schedules.value;
  }
  loading.value = true;
  loadError.value = '';
  try {
    const { data, error } = await supabase.from('maintenance_schedules')
      .select('*').order('next_due');
    if (error) throw error;
    schedules.value = (data || []).map(mapSchedule);
    return schedules.value;
  } catch (error) {
    loadError.value = error.message || 'Maintenance schedules could not be loaded.';
    console.error('Failed to load preventive maintenance schedules.', error);
    throw error;
  } finally {
    loading.value = false;
  }
}

async function addSchedule(input) {
  const schedule = validateSchedule(input);
  if (isSupabaseConfigured && !isDemoMode) {
    const { data, error } = await supabase.from('maintenance_schedules')
      .insert(databasePayload(schedule)).select('*').single();
    if (error) throw error;
    schedules.value = [...schedules.value, mapSchedule(data)].sort((a, b) => a.nextDue.localeCompare(b.nextDue));
    return data;
  }
  const created = { id: crypto.randomUUID(), ...schedule, isActive: true };
  schedules.value = [...schedules.value, created].sort((a, b) => a.nextDue.localeCompare(b.nextDue));
  saveDemoSchedules();
  return created;
}

async function updateSchedule(id, input) {
  const schedule = schedules.value.find((item) => item.id === id);
  if (!schedule) throw new Error('The selected schedule could not be found.');
  const updated = validateSchedule(input);
  const previous = { ...schedule };
  Object.assign(schedule, updated);
  try {
    if (isSupabaseConfigured && !isDemoMode) {
      const { data, error } = await supabase.from('maintenance_schedules')
        .update(databasePayload({ ...schedule, ...updated }))
        .eq('id', id).select('*').single();
      if (error) throw error;
      Object.assign(schedule, mapSchedule(data));
    } else {
      saveDemoSchedules();
    }
    schedules.value = [...schedules.value].sort((a, b) => a.nextDue.localeCompare(b.nextDue));
    return schedule;
  } catch (error) {
    Object.assign(schedule, previous);
    throw error;
  }
}

async function setScheduleActive(id, isActive) {
  const schedule = schedules.value.find((item) => item.id === id);
  if (!schedule) throw new Error('The selected schedule could not be found.');
  const previous = schedule.isActive;
  schedule.isActive = isActive;
  try {
    if (isSupabaseConfigured && !isDemoMode) {
      const { error } = await supabase.from('maintenance_schedules').update({ is_active: isActive }).eq('id', id);
      if (error) throw error;
    } else {
      saveDemoSchedules();
    }
  } catch (error) {
    schedule.isActive = previous;
    throw error;
  }
}

function nextDueDate(schedule, date) {
  const current = new Date(`${date}T00:00:00Z`);
  if (schedule.frequency === 'weekly') current.setUTCDate(current.getUTCDate() + 7);
  else if (schedule.frequency === 'custom') current.setUTCDate(current.getUTCDate() + Number(schedule.customIntervalDays));
  else {
    const day = current.getUTCDate();
    const months = schedule.frequency === 'quarterly' ? 3 : schedule.frequency === 'yearly' ? 12 : 1;
    current.setUTCDate(1);
    current.setUTCMonth(current.getUTCMonth() + months);
    current.setUTCDate(Math.min(day, new Date(Date.UTC(current.getUTCFullYear(), current.getUTCMonth() + 1, 0)).getUTCDate()));
  }
  return current.toISOString().slice(0, 10);
}

async function generateDueWorkOrders() {
  if (isSupabaseConfigured && !isDemoMode) {
    const { data, error } = await supabase.rpc('generate_due_maintenance_work_orders');
    if (error) throw error;
    await loadSchedules();
    return Number(data) || 0;
  }

  const { addReport } = useReports();
  const today = new Date().toISOString().slice(0, 10);
  let generated = 0;
  for (const schedule of schedules.value.filter((item) => item.isActive && item.nextDue <= today)) {
    const description = [
      'Scheduled preventive maintenance.',
      schedule.checklistItems.length ? `Checklist: ${schedule.checklistItems.join('; ')}` : ''
    ].filter(Boolean).join(' ');
    await addReport({
      title: `[Preventive] ${schedule.title}`,
      desc: description,
      cat: schedule.category,
      loc: schedule.locationLabel || 'Campus',
      reporter: 'Preventive Maintenance',
      priority: 'medium'
    });
    do {
      schedule.nextDue = nextDueDate(schedule, schedule.nextDue);
    } while (schedule.nextDue <= today);
    generated += 1;
  }
  saveDemoSchedules();
  return generated;
}

export function useMaintenanceSchedules() {
  return {
    schedules,
    loading,
    loadError,
    loadSchedules,
    addSchedule,
    updateSchedule,
    setScheduleActive,
    generateDueWorkOrders
  };
}
