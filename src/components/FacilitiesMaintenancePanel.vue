<template>
  <section class="facilities-panel">
    <div class="admin-tabs" role="tablist" aria-label="Facilities and maintenance">
      <button type="button" class="admin-tab" :class="{ active: activeTab === 'locations' }" @click="activeTab = 'locations'">
        Facility locations
      </button>
      <button type="button" class="admin-tab" :class="{ active: activeTab === 'schedules' }" @click="activeTab = 'schedules'">
        Preventive schedules
      </button>
    </div>

    <template v-if="activeTab === 'locations'">
      <div class="panel facilities-card">
        <div class="panel-header">
          <span class="panel-title">Manage facility locations</span>
          <button class="btn-secondary" type="button" :disabled="qrLoading || !activeLocations.length" @click="printQrSheets">
            {{ qrLoading ? 'Preparing…' : 'Print QR sheets' }}
          </button>
        </div>
        <form class="facility-form" @submit.prevent="createLocation">
          <label>Building *
            <input v-model="locationForm.building" maxlength="120" required placeholder="e.g., Engineering Building" />
          </label>
          <label>Floor
            <input v-model="locationForm.floor" maxlength="80" placeholder="e.g., Floor 2" />
          </label>
          <label>Room / area
            <input v-model="locationForm.room" maxlength="80" placeholder="e.g., Room 204" />
          </label>
          <div class="facility-form-actions">
            <button v-if="locationForm.id" class="btn-secondary" type="button" @click="resetLocationForm">Cancel edit</button>
            <button class="btn-primary" type="submit" :disabled="saving">{{ saving ? 'Saving…' : locationForm.id ? 'Save changes' : 'Add location' }}</button>
          </div>
        </form>
        <p v-if="locationError" class="facility-error" role="alert">{{ locationError }}</p>
        <div v-if="locationLoading" class="facility-state" role="status">Loading locations…</div>
        <div v-else-if="!locations.length" class="facility-state">No locations yet. Add the first campus facility above.</div>
        <div v-else class="facility-location-list">
          <article v-for="location in locations" :key="location.id" class="facility-location">
            <img v-if="qrCodes[location.id]" :src="qrCodes[location.id]" :alt="`QR code for ${locationLabel(location)}`" />
            <div v-else class="facility-qr-placeholder" aria-hidden="true">QR</div>
            <div class="facility-location-details">
              <strong>{{ locationLabel(location) }}</strong>
              <small>{{ location.isActive ? 'Available in report forms' : 'Inactive' }}</small>
              <code>/report?location={{ location.id }}</code>
            </div>
            <button class="btn-secondary" type="button" @click="editLocation(location)">Edit</button>
            <button class="btn-secondary" type="button" @click="toggleLocation(location)">
              {{ location.isActive ? 'Deactivate' : 'Activate' }}
            </button>
          </article>
        </div>
      </div>
    </template>

    <template v-else>
      <div class="panel facilities-card">
        <div class="panel-header">
          <span class="panel-title">{{ scheduleForm.id ? 'Edit preventive schedule' : 'Create preventive schedule' }}</span>
          <div class="facility-toolbar">
            <span class="panel-action">{{ dueScheduleCount }} due</span>
            <button class="btn-primary" type="button" :disabled="generating || dueScheduleCount === 0" @click="runDueSchedules">
              {{ generating ? 'Generating…' : 'Generate due work orders' }}
            </button>
          </div>
        </div>
        <form class="facility-form schedule-form" @submit.prevent="saveSchedule">
          <label>Schedule title *
            <input v-model="scheduleForm.title" maxlength="180" required placeholder="e.g., Quarterly classroom AC inspection" />
          </label>
          <label>Location
            <select v-model="scheduleForm.locationId">
              <option value="">Select a location</option>
              <option v-for="item in activeLocations" :key="item.id" :value="item.id">{{ locationLabel(item) }}</option>
            </select>
          </label>
          <label>Category *
            <select v-model="scheduleForm.category" required>
              <option value="">Select a category</option>
              <option v-for="item in categories" :key="item" :value="item">{{ item }}</option>
            </select>
          </label>
          <label>Frequency *
            <select v-model="scheduleForm.frequency">
              <option value="weekly">Weekly</option><option value="monthly">Monthly</option>
              <option value="quarterly">Quarterly</option><option value="yearly">Yearly</option>
              <option value="custom">Custom interval</option>
            </select>
          </label>
          <label v-if="scheduleForm.frequency === 'custom'">Repeat every (days) *
            <input v-model.number="scheduleForm.customIntervalDays" type="number" min="1" max="3650" required />
          </label>
          <label>Next due *
            <input v-model="scheduleForm.nextDue" type="date" required />
          </label>
          <label>Default assignee
            <select v-model="scheduleForm.defaultAssignee">
              <option value="">Unassigned</option>
              <option v-for="person in technicians" :key="person.name" :value="person.name">{{ person.name }}</option>
            </select>
          </label>
          <label class="facility-checklist">Checklist items (one per line)
            <textarea v-model="checklistText" maxlength="3000" rows="3" placeholder="Inspect for leaks&#10;Test safety controls"></textarea>
          </label>
          <div class="facility-form-actions">
            <button v-if="scheduleForm.id" class="btn-secondary" type="button" @click="resetScheduleForm">Cancel edit</button>
            <button class="btn-primary" type="submit" :disabled="saving">{{ saving ? 'Saving…' : scheduleForm.id ? 'Save changes' : 'Add schedule' }}</button>
          </div>
        </form>
        <p v-if="scheduleError" class="facility-error" role="alert">{{ scheduleError }}</p>
        <div v-if="schedulesLoading" class="facility-state" role="status">Loading preventive schedules…</div>
        <div v-else-if="!schedules.length" class="facility-state">No preventive schedules have been created.</div>
        <div v-else class="facility-schedule-list">
          <article v-for="schedule in schedules" :key="schedule.id" class="facility-schedule">
            <div>
              <strong>{{ schedule.title }}</strong>
              <p>{{ schedule.locationLabel || locationName(schedule.locationId) || 'Campus' }} · {{ schedule.category }} · {{ frequencyName(schedule) }}</p>
              <small :class="{ 'facility-overdue': schedule.isActive && schedule.nextDue <= today }">
                {{ schedule.isActive && schedule.nextDue <= today ? 'Due' : 'Next due' }} {{ schedule.nextDue }}
                <span v-if="schedule.defaultAssignee"> · {{ schedule.defaultAssignee }}</span>
              </small>
            </div>
            <div class="facility-schedule-actions">
              <button class="btn-secondary" type="button" @click="editSchedule(schedule)">Edit</button>
              <button class="btn-secondary" type="button" @click="toggleSchedule(schedule)">
                {{ schedule.isActive ? 'Pause' : 'Resume' }}
              </button>
            </div>
          </article>
        </div>
      </div>
      <p class="facility-note">For automatic generation, schedule the documented database function <code>generate_due_maintenance_work_orders()</code> daily. The button above runs due schedules immediately.</p>
    </template>
  </section>
</template>

<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useLocations } from '../composables/useLocations.js';
import { useMaintenanceSchedules } from '../composables/useMaintenanceSchedules.js';
import { useReports } from '../composables/useReports.js';
import { useToast } from '../composables/useToast.js';

const categories = ['Electrical', 'Plumbing', 'Furniture', 'HVAC', 'Network', 'Civil', 'Carpentry', 'Security', 'Sanitation', 'Other'];
const activeTab = ref('locations');
const qrCodes = ref({});
const qrLoading = ref(false);
const saving = ref(false);
const generating = ref(false);
const locationError = ref('');
const scheduleError = ref('');
const locationForm = reactive({ id: '', building: '', floor: '', room: '' });
const scheduleForm = reactive({
  id: '',
  title: '',
  locationId: '',
  locationLabel: '',
  category: '',
  frequency: 'monthly',
  customIntervalDays: 30,
  nextDue: new Date().toISOString().slice(0, 10),
  defaultAssignee: ''
});
const checklistText = ref('');
const { locations, activeLocations, loading: locationLoading, loadError: locationLoadError, loadLocations, addLocation, updateLocation, setLocationActive, toLocationLabel } = useLocations();
const { schedules, loading: schedulesLoading, loadError: schedulesLoadError, loadSchedules, addSchedule, updateSchedule, setScheduleActive, generateDueWorkOrders } = useMaintenanceSchedules();
const { technicians } = useReports();
const { showToast } = useToast();
const today = new Date().toISOString().slice(0, 10);
const dueScheduleCount = computed(() => schedules.value.filter((schedule) => schedule.isActive && schedule.nextDue <= today).length);

function locationLabel(location) {
  return toLocationLabel(location);
}

function locationName(id) {
  return locations.value.find((location) => location.id === id)?.building || '';
}

async function refreshLocations() {
  locationError.value = '';
  try {
    await loadLocations();
    await generateQrCodes();
  } catch (error) {
    locationError.value = locationLoadError.value || error.message || 'Locations could not be loaded.';
  }
}

async function generateQrCodes() {
  qrLoading.value = true;
  try {
    const { toDataURL } = await import('qrcode');
    const generated = {};
    for (const location of activeLocations.value) {
      const url = new URL('/report', window.location.origin);
      url.searchParams.set('location', location.id);
      generated[location.id] = await toDataURL(url.toString(), { width: 220, margin: 1, errorCorrectionLevel: 'M' });
    }
    qrCodes.value = generated;
  } catch (error) {
    locationError.value = error.message || 'QR codes could not be generated.';
    console.error('Failed to generate facility QR codes.', error);
  } finally {
    qrLoading.value = false;
  }
}

watch(activeLocations, () => { void generateQrCodes(); }, { deep: true });

async function createLocation() {
  saving.value = true;
  locationError.value = '';
  const wasEditing = Boolean(locationForm.id);
  try {
    if (wasEditing) await updateLocation(locationForm.id, locationForm);
    else await addLocation(locationForm);
    resetLocationForm();
    showToast(wasEditing ? 'Facility location updated.' : 'Facility location added.', 'success');
  } catch (error) {
    locationError.value = error.message || 'The location could not be saved.';
  } finally {
    saving.value = false;
  }
}

function editLocation(location) {
  Object.assign(locationForm, {
    id: location.id,
    building: location.building,
    floor: location.floor,
    room: location.room
  });
  locationError.value = '';
}

function resetLocationForm() {
  Object.assign(locationForm, { id: '', building: '', floor: '', room: '' });
}

async function toggleLocation(location) {
  try {
    await setLocationActive(location.id, !location.isActive);
    showToast(`${locationLabel(location)} ${location.isActive ? 'activated' : 'deactivated'}.`, 'success');
  } catch (error) {
    locationError.value = error.message || 'The location could not be updated.';
  }
}

function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, (character) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
  })[character]);
}

function printQrSheets() {
  if (!activeLocations.value.length || !Object.keys(qrCodes.value).length) {
    locationError.value = 'There are no generated QR codes to print yet.';
    return;
  }
  const printWindow = window.open('', '_blank');
  if (!printWindow) {
    locationError.value = 'The print window was blocked. Allow pop-ups and try again.';
    return;
  }
  printWindow.opener = null;
  const cards = activeLocations.value.map((location) => `
    <article><img src="${qrCodes.value[location.id]}" alt="QR code">
      <h2>${escapeHtml(locationLabel(location))}</h2><small>Scan to report an issue at this facility</small>
    </article>`).join('');
  printWindow.document.write(`<!doctype html><html><head><title>UNIFIX Facility QR Codes</title><style>
    body{font:12px Arial,sans-serif;margin:12mm}.sheet{display:grid;grid-template-columns:repeat(3,1fr);gap:10mm}
    article{border:1px solid #bbc9bf;border-radius:6px;padding:8mm;text-align:center;break-inside:avoid}
    img{width:38mm;height:38mm}h2{font-size:13px;margin:5px 0}small{color:#52635a}
    @page{size:A4;margin:12mm}@media print{body{margin:0}}
    </style></head><body><main class="sheet">${cards}</main><script>window.onload=()=>window.print()<\/script></body></html>`);
  printWindow.document.close();
}

function resetScheduleForm() {
  Object.assign(scheduleForm, {
    id: '', title: '', locationId: '', locationLabel: '', category: '',
    frequency: 'monthly', customIntervalDays: 30,
    nextDue: new Date().toISOString().slice(0, 10), defaultAssignee: ''
  });
  checklistText.value = '';
}

function editSchedule(schedule) {
  Object.assign(scheduleForm, {
    ...schedule,
    customIntervalDays: schedule.customIntervalDays || 30
  });
  checklistText.value = schedule.checklistItems.join('\n');
  scheduleError.value = '';
  activeTab.value = 'schedules';
}

async function saveSchedule() {
  saving.value = true;
  scheduleError.value = '';
  const selected = locations.value.find((location) => location.id === scheduleForm.locationId);
  const payload = {
    ...scheduleForm,
    locationLabel: selected ? locationLabel(selected) : scheduleForm.locationLabel,
    checklistItems: checklistText.value.split(/\r?\n/).map((item) => item.trim()).filter(Boolean)
  };
  try {
    if (scheduleForm.id) await updateSchedule(scheduleForm.id, payload);
    else await addSchedule(payload);
    resetScheduleForm();
    showToast('Preventive maintenance schedule saved.', 'success');
  } catch (error) {
    scheduleError.value = error.message || 'The schedule could not be saved.';
  } finally {
    saving.value = false;
  }
}

function frequencyName(schedule) {
  return schedule.frequency === 'custom'
    ? `Every ${schedule.customIntervalDays} days`
    : schedule.frequency.charAt(0).toUpperCase() + schedule.frequency.slice(1);
}

async function toggleSchedule(schedule) {
  try {
    await setScheduleActive(schedule.id, !schedule.isActive);
    showToast(`Schedule ${schedule.isActive ? 'resumed' : 'paused'}.`, 'success');
  } catch (error) {
    scheduleError.value = error.message || 'The schedule could not be updated.';
  }
}

async function runDueSchedules() {
  generating.value = true;
  scheduleError.value = '';
  try {
    const count = await generateDueWorkOrders();
    showToast(`${count} preventive work order${count === 1 ? '' : 's'} generated.`, 'success');
  } catch (error) {
    scheduleError.value = error.message || 'Due schedules could not be generated.';
  } finally {
    generating.value = false;
  }
}

onMounted(async () => {
  await Promise.all([
    refreshLocations(),
    loadSchedules().catch((error) => {
      scheduleError.value = schedulesLoadError.value || error.message || 'Maintenance schedules could not be loaded.';
    })
  ]);
});
</script>

<style scoped>
.facilities-panel { display:grid; gap:14px; }
.facilities-card { padding:18px; }
.facilities-card .panel-header { gap:12px; flex-wrap:wrap; }
.facilities-card .panel-header button,.facility-toolbar button { margin-top:0; }
.facility-form { display:grid; grid-template-columns:repeat(4,minmax(0,1fr)); gap:12px; padding:16px; border:1px solid var(--border); border-radius:var(--radius-sm); background:var(--surface-2); }
.facility-form label { display:grid; gap:5px; color:var(--text-2); font-size:11px; font-weight:700; }
.facility-form input,.facility-form select,.facility-form textarea { width:100%; min-height:38px; padding:8px 10px; border:1px solid var(--border-dark); border-radius:6px; background:var(--surface); color:var(--text); font:inherit; }
.facility-form button { align-self:end; margin-top:0; }
.facility-location-list,.facility-schedule-list { display:grid; gap:9px; margin-top:14px; }
.facility-location,.facility-schedule { display:flex; align-items:center; gap:14px; padding:12px; border:1px solid var(--border); border-radius:8px; }
.facility-location img,.facility-qr-placeholder { width:74px; height:74px; flex:none; object-fit:contain; }
.facility-qr-placeholder { display:grid; place-items:center; border:1px dashed var(--border-dark); color:var(--text-3); font-weight:700; }
.facility-location-details { display:grid; flex:1; gap:3px; min-width:0; }
.facility-location-details small,.facility-location-details code,.facility-schedule p,.facility-schedule small { color:var(--text-3); font-size:11px; }
.facility-location-details code { overflow:hidden; text-overflow:ellipsis; }
.facility-location button,.facility-schedule-actions button { margin-top:0; white-space:nowrap; }
.facility-toolbar,.facility-schedule-actions { display:flex; align-items:center; gap:8px; }
.facility-toolbar { margin-left:auto; flex-wrap:wrap; }
.schedule-form { grid-template-columns:repeat(3,minmax(0,1fr)); }
.facility-checklist { grid-column:span 2; }
.facility-checklist textarea { resize:vertical; }
.facility-form-actions { display:flex; justify-content:flex-end; align-items:end; gap:8px; grid-column:1/-1; }
.facility-form-actions button { margin-top:0; }
.facility-schedule { justify-content:space-between; }
.facility-schedule p { margin:4px 0; }
.facility-overdue { color:var(--red)!important; font-weight:800; }
.facility-state { padding:28px 12px; color:var(--text-3); font-size:13px; text-align:center; }
.facility-error { margin-top:10px; color:var(--red); font-size:12px; }
.facility-note { color:var(--text-3); font-size:12px; }
@media(max-width:800px){.facility-form,.schedule-form{grid-template-columns:repeat(2,minmax(0,1fr))}}
@media(max-width:560px){.facility-form,.schedule-form{grid-template-columns:1fr}.facility-checklist{grid-column:auto}.facility-location,.facility-schedule{align-items:flex-start;flex-wrap:wrap}.facility-location button,.facility-schedule-actions{margin-left:auto}.facility-location img,.facility-qr-placeholder{width:56px;height:56px}.facility-toolbar{width:100%;margin-left:0}}
</style>
