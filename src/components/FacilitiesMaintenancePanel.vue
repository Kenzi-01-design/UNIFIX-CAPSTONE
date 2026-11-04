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
          <span class="panel-title">{{ locationForm.id ? `Editing ${locationForm.building}` : 'Manage facility locations' }}</span>
          <button class="btn-secondary" type="button" :disabled="qrLoading || !activeLocations.length" @click="printQrSheets">
            {{ qrLoading ? 'Preparing…' : 'Print all facility signs' }}
          </button>
        </div>
        <form class="facility-form" @submit.prevent="createLocation">
          <label>Building *
            <input ref="locationBuildingInput" v-model="locationForm.building" maxlength="120" required placeholder="e.g., Engineering Building" />
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
              <div class="facility-qr-link">
                <template v-if="location.isActive">
                  <code>/facility?location={{ encodeURIComponent(location.id) }}</code>
                  <a :href="facilityStatusUrl(location)" target="_blank" rel="noopener noreferrer">View facility status</a>
                </template>
                <small v-else>Facility QR unavailable while inactive</small>
              </div>
            </div>
            <button class="btn-secondary" type="button" @click="editLocation(location)">Edit</button>
            <button
              class="btn-secondary"
              type="button"
              :disabled="!location.isActive || qrLoading || !qrCodes[location.id]"
              @click="printFacilitySign(location)"
            >
              Print sign
            </button>
            <button class="btn-secondary" type="button" @click="toggleLocation(location)">
              {{ location.isActive ? 'Deactivate' : 'Activate' }}
            </button>
            <button
              class="btn-secondary"
              type="button"
              :disabled="deletingLocationId === location.id"
              @click="removeLocation(location)"
            >
              {{ deletingLocationId === location.id ? 'Deleting…' : 'Delete' }}
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
import { computed, nextTick, onMounted, reactive, ref, watch } from 'vue';
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
const deletingLocationId = ref('');
const locationError = ref('');
const scheduleError = ref('');
const locationBuildingInput = ref(null);
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
const { locations, activeLocations, loading: locationLoading, loadError: locationLoadError, loadLocations, addLocation, updateLocation, setLocationActive, deleteLocation, toLocationLabel } = useLocations();
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

function facilityStatusUrl(location) {
  const url = new URL('/facility', window.location.origin);
  url.searchParams.set('location', location.id);
  return url.toString();
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
      generated[location.id] = await toDataURL(facilityStatusUrl(location), {
        width: 220,
        margin: 1,
        errorCorrectionLevel: 'H'
      });
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

async function editLocation(location) {
  Object.assign(locationForm, {
    id: location.id,
    building: location.building,
    floor: location.floor,
    room: location.room
  });
  locationError.value = '';
  await nextTick();
  window.scrollTo({ top: 0, behavior: 'smooth' });
  locationBuildingInput.value?.focus({ preventScroll: true });
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

async function removeLocation(location) {
  const label = locationLabel(location);
  const confirmed = window.confirm(
    `Permanently delete ${label}? Reports and requests will be kept, but maintenance schedules will be detached from this location. This cannot be undone.`
  );
  if (!confirmed) return;

  deletingLocationId.value = location.id;
  locationError.value = '';
  try {
    await deleteLocation(location.id);
    if (locationForm.id === location.id) resetLocationForm();
    showToast(`${label} deleted.`, 'success');
  } catch (error) {
    locationError.value = error.message || 'The location could not be deleted.';
  } finally {
    deletingLocationId.value = '';
  }
}

function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, (character) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
  })[character]);
}

function printFacilitySign(location) {
  if (!location.isActive || !qrCodes.value[location.id]) {
    locationError.value = 'There are no generated QR codes to print yet.';
    return;
  }

  printFacilitySigns([location]);
}

function printQrSheets() {
  if (!activeLocations.value.length || !activeLocations.value.every((location) => qrCodes.value[location.id])) {
    locationError.value = 'Facility QR codes are still being generated. Try again when they are ready.';
    return;
  }

  printFacilitySigns(activeLocations.value);
}

function printFacilitySigns(facilities) {
  const printWindow = window.open('', '_blank');
  if (!printWindow) {
    locationError.value = 'The print window was blocked. Allow pop-ups and try again.';
    return;
  }
  printWindow.opener = null;
  const sealUrl = new URL('/nvsu-seal.png', window.location.origin).href;
  const signs = facilities.map((location) => `
    <article class="sign">
      <header class="brand">
        <div class="brand-mark" role="img" aria-label="UNIFIX and NVSU logo">
          <svg viewBox="0 0 48 48" aria-hidden="true">
            <path d="M24 3.5 42 10v12.8c0 10.3-6.9 18-18 22.2C12.9 40.8 6 33.1 6 22.8V10l18-6.5Z" fill="#0F6B3D"/>
            <path d="M12.5 19.5h8v-4h7v4h8v15h-23v-15Z" fill="#FFFDF7"/>
            <path d="M16 23h3v3h-3zm6 0h3v3h-3zm6 0h3v3h-3zM22 29h5v5h-5z" fill="#0F6B3D"/>
            <circle cx="35.5" cy="34.5" r="8" fill="#DEA510" stroke="#FFFDF7" stroke-width="2"/>
            <path d="m31.8 34.4 2.4 2.4 5-5.1" fill="none" stroke="#0A4F2D" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
          </svg>
          <img src="${escapeHtml(sealUrl)}" alt="">
        </div>
        <div><strong>UNIFIX</strong><span>CAMPUS FACILITY CARE</span></div>
      </header>
      <div class="gold-rule"><span></span><i></i><span></span></div>
      <p class="eyebrow">FACILITY ASSISTANCE</p>
      <h1>Report a facility issue</h1>
      <p class="facility-name">${escapeHtml(locationLabel(location))}</p>
      <p class="intro">Scan the QR code to view current issues or submit a report.</p>
      <div class="qr-frame"><img src="${escapeHtml(qrCodes.value[location.id])}" alt="QR code for ${escapeHtml(locationLabel(location))}"></div>
      <p class="scan-label">SCAN HERE</p>
      <ol class="steps">
        <li>
          <b>1</b>
          <svg viewBox="0 0 24 24" aria-hidden="true"><rect x="7" y="3" width="10" height="18" rx="2"/><path d="M10 6h4M11 18h2"/></svg>
          <span>Scan the code</span>
        </li>
        <li>
          <b>2</b>
          <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 20h9"/><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L8 18l-4 1 1-4Z"/></svg>
          <span>Describe the issue</span>
        </li>
        <li>
          <b>3</b>
          <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M14 5h-4l-2 2H5a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2h-3Z"/><circle cx="12" cy="13" r="3"/></svg>
          <span>Add a photo and submit</span>
        </li>
      </ol>
      <footer><span class="footer-icon">✓</span> Helping keep our campus safe, comfortable, and working.</footer>
    </article>`).join('');
  printWindow.document.write(`<!doctype html><html><head><meta charset="utf-8"><title>UNIFIX Facility Signs</title><style>
    *{box-sizing:border-box}
    body{margin:0;background:#eef2ef;color:#1a1f36;font:14px/1.45 Arial,Helvetica,sans-serif}
    .sign{position:relative;display:flex;flex-direction:column;align-items:center;width:100%;min-height:190mm;padding:10mm 12mm 8mm;overflow:hidden;background:#fff;text-align:center;break-after:page}
    .sign:last-child{break-after:auto}
    .brand{display:flex;align-items:center;gap:10px;align-self:flex-start;color:#0f6b3d;text-align:left}
    .brand-mark{position:relative;display:block;width:40px;height:40px;flex:none}
    .brand-mark svg{display:block;width:100%;height:100%}
    .brand-mark img{position:absolute;right:-2px;bottom:-1px;width:23px;height:23px;border:2px solid #fff;border-radius:50%;background:#fff;object-fit:cover}
    .brand strong,.brand span{display:block}.brand strong{font-size:19px;letter-spacing:1.5px}.brand span{font-size:8px;font-weight:700;letter-spacing:1px}
    .gold-rule{display:flex;align-items:center;gap:2mm;width:100%;margin-top:5mm}
    .gold-rule span{height:.35mm;flex:1;background:#e6d7a8}.gold-rule i{width:2mm;height:2mm;transform:rotate(45deg);background:#dea510}
    .eyebrow{margin:13mm 0 2mm;color:#9e7400;font-size:9px;font-weight:800;letter-spacing:2px}
    h1{max-width:125mm;margin:0;color:#0a4f2d;font-size:25px;line-height:1.1;text-transform:uppercase}
    .facility-name{margin:4mm 0 0;color:#1a1f36;font-size:19px;font-weight:700}
    .intro{max-width:105mm;margin:2mm 0 5mm;color:#4a5568;font-size:12px}
    .qr-frame{display:grid;place-items:center;width:76mm;height:76mm;padding:4mm;border:1.5px solid #dce8df;border-radius:5mm;background:#fff}
    .qr-frame img{display:block;width:100%;height:100%;object-fit:contain}
    .scan-label{margin:2mm 0 4mm;color:#0f6b3d;font-size:10px;font-weight:800;letter-spacing:2px}
    .steps{display:grid;gap:2mm;width:100%;max-width:105mm;margin:0;padding:0;list-style:none;text-align:left}
    .steps li{display:flex;align-items:center;gap:3mm;color:#1a1f36;font-size:11px}
    .steps b{display:grid;place-items:center;width:7mm;height:7mm;border-radius:50%;background:#e9f6ee;color:#0f6b3d;font-size:10px}
    .steps svg{width:5mm;height:5mm;fill:none;stroke:#0f6b3d;stroke-width:1.7;stroke-linecap:round;stroke-linejoin:round}
    footer{display:flex;align-items:center;gap:2mm;margin-top:auto;padding-top:5mm;color:#6f7e75;font-size:9px}
    .footer-icon{display:grid;place-items:center;width:5mm;height:5mm;border-radius:50%;background:#e9f6ee;color:#0f6b3d;font-size:9px;font-weight:800}
    @page{size:A5 portrait;margin:0}
    @media screen{body{padding:12px}.sign{max-width:148mm;min-height:210mm;margin:0 auto 12px;box-shadow:0 2px 12px #0002}}
    @media print{body{background:#fff}.sign{min-height:210mm}}
    </style></head><body>${signs}<script>window.onload=()=>window.print()<\/script></body></html>`);
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
.facility-qr-link { display:grid; gap:3px; min-width:0; }
.facility-qr-link a { color:var(--primary); font-size:11px; font-weight:700; overflow-wrap:anywhere; }
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
