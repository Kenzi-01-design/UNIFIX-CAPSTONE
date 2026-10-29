<template>
  <div class="view active" id="view-submit-request">
    <TrackingCodeNotice v-if="submissionCode" :code="submissionCode" title="Your service request has been submitted" />
    <div style="margin-bottom: 20px;">
      
      <!-- Request form tabs -->
      <div class="req-form-tabs">
        <button
          class="req-tab-btn"
          :class="{ active: activeTab === 'rwss' }"
          @click="activeTab = 'rwss'"
        >
          <UiIcon name="plumbing" :size="16" /> 1. Water & Sewerage (RWSS)
        </button>
        <button
          class="req-tab-btn"
          :class="{ active: activeTab === 'reas' }"
          @click="activeTab = 'reas'"
        >
          <UiIcon name="zap" :size="16" /> 2. Electrical & Air-Conditioning (REAS)
        </button>
        <button
          class="req-tab-btn"
          :class="{ active: activeTab === 'carpentry' }"
          @click="activeTab = 'carpentry'"
        >
          <UiIcon name="work" :size="16" /> 3. Carpentry Inspection & Maintenance
        </button>
      </div>
      <p v-if="locationsLoading" class="location-options-state" role="status">Loading managed campus locations…</p>
      <p v-else-if="locationsError" class="location-options-error" role="alert">{{ locationsError }} Built-in building options are available.</p>
    </div>

    <PhotoPicker
      v-model="selectedPhotos"
      label="Attach photos to this request"
      required
      @processing-change="photosProcessing = $event"
    />

    <div class="grid-2">
      <!-- LEFT COLUMN: FORM CARD -->
      <div>
        <!-- FORM 1: RWSS -->
        <div v-if="activeTab === 'rwss'" class="form-card official-form-panel">
          <div class="form-doc-header">
            <h3>REQUEST FOR WATER AND SEWERAGE SERVICES</h3>
            <small>Bayombong, Nueva Vizcaya · PPSDS</small>
          </div>

          <div class="form-row">
            <div class="form-group">
              <label>Name of Building / Office *</label>
              <select v-model="rwss.building">
                <option value="">Select Building / Office...</option>
                <option v-for="b in buildings" :key="b" :value="b">{{ b }}</option>
              </select>
            </div>
            <div class="form-group">
              <label>Room / Specific Area</label>
              <input type="text" v-model="rwss.room" placeholder="e.g., 2nd Floor, Restroom A" />
            </div>
          </div>

          <div class="form-row">
            <div class="form-group">
              <label>Nature of Repair Target (Dropdown) *</label>
              <select v-model="rwss.repairTarget">
                <option value="">Select Defective Fixture...</option>
                <option value="Faucet">Faucet</option>
                <option value="Fixtures">Fixtures</option>
                <option value="Pump">Water Pump</option>
                <option value="Toilet Bowl">Toilet Bowl</option>
                <option value="Lavatory">Lavatory</option>
                <option value="Floor Drain">Floor Drain</option>
                <option value="Others">Others (specify)</option>
              </select>
            </div>
            <div class="form-group" v-if="rwss.repairTarget === 'Others'">
              <label>Specify Fixture *</label>
              <input type="text" v-model="rwss.otherTarget" placeholder="Specify fixture name..." />
            </div>
          </div>

          <div class="form-group">
            <label>Initial Assessment Classification by PPSDS *</label>
            <select v-model="rwss.classification">
              <option value="Repair Works">Repair Works</option>
              <option value="Maintenance Work">Maintenance Work</option>
              <option value="New Installation">New</option>
              <option value="Emergency Repair">Emergency Repair</option>
              <option value="Requires Labor and Materials">Requires Labor and Materials</option>
              <option value="Requires Labor/Manpower">Requires Labor/Manpower to complete repair</option>
              <option value="Major Repair">Major Repair (requires plan, program of work)</option>
            </select>
          </div>

          <div class="form-group">
            <label>Nature of Defect / Complaint or Request *</label>
            <textarea
              v-model="rwss.defect"
              rows="3"
              placeholder="Describe the complaint in detail..."
            ></textarea>
          </div>

          <div class="form-row">
            <div class="form-group">
              <label>Requested By</label>
              <input type="text" v-model="rwss.requester" disabled />
            </div>
            <div class="form-group">
              <label>Designation</label>
              <input type="text" v-model="rwss.designation" placeholder="Faculty / Department Chair" />
            </div>
          </div>

          <div class="form-actions">
            <button class="btn-accent" :disabled="isSubmitting || photosProcessing" @click="submitRWSS">Submit Water & Sewerage Request</button>
          </div>
          <div class="form-doc-footer">
            <span class="doc-code">NVSU-FR-PPS-10-00 (020822)</span>
          </div>
        </div>

        <!-- FORM 2: REAS -->
        <div v-else-if="activeTab === 'reas'" class="form-card official-form-panel">
          <div class="form-doc-header">
            <h3>REQUEST FOR ELECTRICAL AND AIR-CONDITIONING SERVICES</h3>
            <small>Bayombong, Nueva Vizcaya · Unit Head-GSU</small>
          </div>

          <div class="form-row triple">
            <div class="form-group">
              <label>Location (Building / Office) *</label>
              <select v-model="reas.location">
                <option value="">Select Target Location...</option>
                <option v-for="b in buildings" :key="b" :value="b">{{ b }}</option>
              </select>
            </div>
            <div class="form-group">
              <label>Room / Specific Area</label>
              <input type="text" v-model="reas.room" placeholder="e.g., 2nd Floor, Room 204" />
            </div>
            <div class="form-group">
              <label>Service Classification *</label>
              <select v-model="reas.category" @change="reas.item = ''">
                <option value="ELECTRICAL">1. Electrical Lighting / Materials</option>
                <option value="COOLING">2. Cooling Appliances</option>
              </select>
            </div>
          </div>

          <!-- Electrical Items Dropdown -->
          <div class="form-row" v-if="reas.category === 'ELECTRICAL'">
            <div class="form-group">
              <label>Damage / Defective Item *</label>
              <select v-model="reas.item">
                <option value="">Select Electrical Item...</option>
                <option value="1.1 Fluorescent Lamp & LED Tube">1.1 Fluorescent Lamp & LED Tube</option>
                <option value="1.2 Circular Lamp">1.2 Circular Lamp</option>
                <option value="1.3 Compact Fluorescent Lamp (FCL) & LED Bulb">1.3 Compact Fluorescent Lamp (FCL) & LED Bulb</option>
                <option value="1.4 Breakers">1.4 Breakers</option>
                <option value="1.5 Switches">1.5 Switches</option>
                <option value="1.6 Outlets">1.6 Outlets</option>
                <option value="1.7 Wires">1.7 Wires</option>
                <option value="1.8 Solar Panels">1.8 Solar Panels</option>
                <option value="1.9 Others">1.9 Others (specify)</option>
              </select>
            </div>
            <div class="form-group" v-if="reas.item === '1.9 Others'">
              <label>Specify Other Item *</label>
              <input type="text" v-model="reas.customItem" placeholder="Specify item name..." />
            </div>
          </div>

          <!-- Cooling Appliances Dropdown -->
          <div class="form-row" v-if="reas.category === 'COOLING'">
            <div class="form-group">
              <label>Damage / Defective Appliance *</label>
              <select v-model="reas.item">
                <option value="">Select Cooling Appliance...</option>
                <option value="2.1 Air-con">2.1 Air-con</option>
                <option value="2.2 Electric Fan">2.2 Electric Fan</option>
                <option value="2.3 Refrigerator">2.3 Refrigerator</option>
                <option value="2.4 Others">2.4 Others (specify)</option>
              </select>
            </div>
            <div class="form-group" v-if="reas.item === '2.4 Others'">
              <label>Specify Other Appliance *</label>
              <input type="text" v-model="reas.customItem" placeholder="Specify appliance name..." />
            </div>
          </div>

          <!-- Cooling Appliance Details -->
          <div class="form-row triple" v-if="reas.category === 'COOLING' && reas.item && reas.item !== '2.4 Others'">
            <div class="form-group">
              <label>Brand</label>
              <input type="text" v-model="reas.brand" placeholder="e.g., Carrier" />
            </div>
            <div class="form-group">
              <label>Model</label>
              <input type="text" v-model="reas.model" placeholder="e.g., Inverter 2.0HP" />
            </div>
            <div class="form-group">
              <label>Serial</label>
              <input type="text" v-model="reas.serial" placeholder="Serial Number" />
            </div>
          </div>

          <div class="form-row">
            <div class="form-group">
              <label>Number of Defective Items *</label>
              <input type="number" min="1" v-model.number="reas.quantity" />
            </div>
            <div class="form-group">
              <label>Service Schedule</label>
              <input type="date" v-model="reas.schedule" />
            </div>
          </div>

          <div class="form-group">
            <label>Nature of Damage *</label>
            <textarea
              v-model="reas.damage"
              rows="3"
              placeholder="Describe the nature of damage or technical observations..."
            ></textarea>
          </div>

          <div class="form-group">
            <label>Requesting Official</label>
            <input type="text" v-model="reas.official" disabled />
          </div>

          <div class="form-actions">
            <button class="btn-secondary" :disabled="isSubmitting || photosProcessing" @click="clearREAS">Clear</button>
            <button class="btn-accent" :disabled="isSubmitting || photosProcessing" @click="submitREAS">Submit Electrical / AC Request</button>
          </div>

          <div class="form-doc-footer">
            <span class="doc-code">NVSU-FR-PPS-03-01 (092524)</span>
          </div>
        </div>

        <!-- FORM 3: Carpentry Inspection and Maintenance -->
        <div v-else class="form-card official-form-panel">
          <div class="form-doc-header">
            <h3>CARPENTRY INSPECTION AND MAINTENANCE FORM</h3>
            <small>Bayombong, Nueva Vizcaya · Building Maintenance Unit</small>
          </div>

          <div class="form-row">
            <div class="form-group">
              <label>Name of Building / Office *</label>
              <select v-model="carpentry.building">
                <option value="">Select Building / Office...</option>
                <option v-for="b in buildings" :key="b" :value="b">{{ b }}</option>
              </select>
            </div>
            <div class="form-group">
              <label>Room / Specific Area *</label>
              <input type="text" v-model="carpentry.area" placeholder="e.g., Faculty Office 204" />
            </div>
          </div>

          <div class="form-row">
            <div class="form-group">
              <label>Inspection Type *</label>
              <select v-model="carpentry.inspectionType">
                <option value="">Select Inspection Type...</option>
                <option value="Routine inspection">Routine inspection</option>
                <option value="Reported damage">Reported damage</option>
                <option value="Preventive maintenance">Preventive maintenance</option>
                <option value="Safety inspection">Safety inspection</option>
              </select>
            </div>
            <div class="form-group">
              <label>Carpentry Item *</label>
              <select v-model="carpentry.item">
                <option value="">Select Item...</option>
                <option value="Door / Door frame">Door / Door frame</option>
                <option value="Window / Window frame">Window / Window frame</option>
                <option value="Cabinet / Shelf">Cabinet / Shelf</option>
                <option value="Desk / Table / Chair">Desk / Table / Chair</option>
                <option value="Wall / Ceiling / Floor">Wall / Ceiling / Floor</option>
                <option value="Roofing / Fascia">Roofing / Fascia</option>
                <option value="Other carpentry fixture">Other carpentry fixture</option>
              </select>
            </div>
          </div>

          <div class="form-row">
            <div class="form-group">
              <label>Observed Condition *</label>
              <select v-model="carpentry.condition">
                <option value="">Select Condition...</option>
                <option value="Good">Good</option>
                <option value="Needs minor repair">Needs minor repair</option>
                <option value="Needs major repair">Needs major repair</option>
                <option value="Unsafe / urgent attention">Unsafe / urgent attention</option>
              </select>
            </div>
            <div class="form-group">
              <label>Preferred Inspection Date</label>
              <input type="date" v-model="carpentry.schedule" />
            </div>
          </div>

          <div class="form-group">
            <label>Inspection Findings / Requested Maintenance *</label>
            <textarea
              v-model="carpentry.findings"
              rows="4"
              placeholder="Describe the observed condition, measurements, safety concern, or requested carpentry work..."
            ></textarea>
          </div>

          <div class="form-row">
            <div class="form-group">
              <label>Requested By</label>
              <input type="text" v-model="carpentry.requester" disabled />
            </div>
            <div class="form-group">
              <label>Designation</label>
              <input type="text" v-model="carpentry.designation" placeholder="Faculty / Department Chair" />
            </div>
          </div>

          <div class="form-actions">
            <button class="btn-secondary" :disabled="isSubmitting || photosProcessing" @click="clearCarpentry">Clear</button>
            <button class="btn-accent" :disabled="isSubmitting || photosProcessing" @click="submitCarpentry">Submit Carpentry Request</button>
          </div>

          <div class="form-doc-footer">
            <span class="doc-code">NVSU-FR-PPS-CM-01</span>
          </div>
        </div>
      </div>

    </div>
  </div>
</template>

<script setup>
import { computed, onMounted, ref, reactive, watch } from 'vue';
import { useRequests } from '../composables/useRequests.js';
import { useAuth } from '../composables/useAuth.js';
import { useToast } from '../composables/useToast.js';
import UiIcon from '../components/UiIcon.vue';
import PhotoPicker from '../components/PhotoPicker.vue';
import TrackingCodeNotice from '../components/TrackingCodeNotice.vue';
import { useLocations } from '../composables/useLocations.js';

const { addRequest } = useRequests();
const { activeUserName } = useAuth();
const { showToast } = useToast();
const {
  activeLocations,
  loading: locationsLoading,
  loadError: locationLoadError,
  loadLocations,
  demoBuildings
} = useLocations();
const locationsError = ref('');

const activeTab = ref('rwss');
const selectedPhotos = ref([]);
const photosProcessing = ref(false);
const submissionCode = ref('');
const isSubmitting = ref(false);

const buildings = computed(() => activeLocations.value.length
  ? [...new Set(activeLocations.value.map((location) => location.building))]
  : demoBuildings);

onMounted(() => {
  void loadLocations().catch((error) => {
    locationsError.value = locationLoadError.value || error.message || 'Managed campus locations could not be loaded.';
  });
});

// 1. RWSS Form State
const rwss = reactive({
  building: '',
  room: '',
  repairTarget: '',
  otherTarget: '',
  classification: 'Repair Works',
  defect: '',
  requester: activeUserName.value || 'Faculty Member',
  designation: 'Faculty'
});

// 2. REAS Form State
const reas = reactive({
  location: '',
  room: '',
  category: 'ELECTRICAL',
  item: '',
  customItem: '',
  brand: '',
  model: '',
  serial: '',
  quantity: 1,
  schedule: '',
  damage: '',
  official: activeUserName.value || 'Faculty Member'
});

// 3. Carpentry Inspection and Maintenance Form State
const carpentry = reactive({
  building: '',
  area: '',
  inspectionType: '',
  item: '',
  condition: '',
  schedule: '',
  findings: '',
  requester: activeUserName.value || 'Faculty Member',
  designation: 'Faculty'
});

watch(activeUserName, (newVal) => {
  rwss.requester = newVal;
  reas.official = newVal;
  carpentry.requester = newVal;
});

function clearRWSS() {
  rwss.building = '';
  rwss.room = '';
  rwss.repairTarget = '';
  rwss.otherTarget = '';
  rwss.defect = '';
}

function clearREAS() {
  reas.location = '';
  reas.room = '';
  reas.item = '';
  reas.customItem = '';
  reas.brand = '';
  reas.model = '';
  reas.serial = '';
  reas.quantity = 1;
  reas.schedule = '';
  reas.damage = '';
}

function clearCarpentry() {
  carpentry.building = '';
  carpentry.area = '';
  carpentry.inspectionType = '';
  carpentry.item = '';
  carpentry.condition = '';
  carpentry.schedule = '';
  carpentry.findings = '';
}

async function submitRWSS() {
  const target = rwss.repairTarget === 'Others' ? rwss.otherTarget : rwss.repairTarget;
  if (!rwss.building || !target || !rwss.defect.trim()) {
    showToast('Please fill out all required fields for RWSS.', 'error');
    return;
  }

  await submitRequest({
    title: `[RWSS] Water & Sewerage: ${target}`,
    cat: 'Plumbing',
    dept: rwss.building + (rwss.room ? ` · ${rwss.room}` : ''),
    details: `[${rwss.classification}] ${rwss.defect} (Designation: ${rwss.designation})`,
    requester: rwss.requester
  }, clearRWSS, 'Water and Sewerage Requisition submitted! ✅');
}

async function submitREAS() {
  const item = reas.item === '1.9 Others' || reas.item === '2.4 Others' ? reas.customItem : reas.item;
  if (!reas.location || !item || !reas.damage.trim()) {
    showToast('Please fill out all required fields for REAS.', 'error');
    return;
  }

  let desc = `Item: ${item} (Qty: ${reas.quantity}). Defect: ${reas.damage}.`;
  if (reas.category === 'COOLING' && reas.brand) {
    desc += ` [Specs: Brand: ${reas.brand}, Model: ${reas.model || 'N/A'}, Serial: ${reas.serial || 'N/A'}]`;
  }
  if (reas.schedule) {
    desc += ` Preferred Date: ${reas.schedule}.`;
  }

  await submitRequest({
    title: `[REAS] ${reas.category === 'COOLING' ? 'Cooling' : 'Electrical'}: ${item}`,
    cat: reas.category === 'COOLING' ? 'HVAC' : 'Electrical',
    dept: reas.location + (reas.room ? ` · ${reas.room}` : ''),
    details: desc,
    requester: reas.official
  }, clearREAS, 'Electrical & AC Requisition submitted! ✅');
}

async function submitCarpentry() {
  if (
    !carpentry.building ||
    !carpentry.area.trim() ||
    !carpentry.inspectionType ||
    !carpentry.item ||
    !carpentry.condition ||
    !carpentry.findings.trim()
  ) {
    showToast('Please fill out all required fields for Carpentry Inspection and Maintenance.', 'error');
    return;
  }

  const schedule = carpentry.schedule ? ` Preferred inspection date: ${carpentry.schedule}.` : '';
  await submitRequest({
    title: `[CARPENTRY] ${carpentry.item} inspection`,
    cat: 'Carpentry',
    dept: carpentry.building + ` · ${carpentry.area}`,
    details: `[${carpentry.inspectionType}] Condition: ${carpentry.condition}. ${carpentry.findings} (Designation: ${carpentry.designation}).${schedule}`,
    requester: carpentry.requester
  }, clearCarpentry, 'Carpentry Inspection and Maintenance request submitted! ✅');
}

async function submitRequest(requestData, clearForm, successMessage) {
  if (photosProcessing.value) {
    showToast('Wait for photo processing to finish before submitting.', 'info');
    return;
  }
  if (!selectedPhotos.value.length) {
    showToast('Attach at least one photo before submitting the request.', 'error');
    return;
  }
  isSubmitting.value = true;
  try {
    const created = await addRequest(requestData, selectedPhotos.value);
    submissionCode.value = created.trackingCode;
    selectedPhotos.value = [];
    clearForm();
    showToast(successMessage, 'success');
  } catch (error) {
    showToast(error.message || 'Unable to submit the request. Please try again.', 'error');
  } finally {
    isSubmitting.value = false;
  }
}
</script>

<style scoped>
.location-options-state,.location-options-error { margin-top:8px; font-size:12px; }
.location-options-state { color:var(--text-3); }
.location-options-error { color:var(--red); }
.req-form-tabs {
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
}

.grid-2 {
  grid-template-columns: 1fr;
}

.req-tab-btn {
  padding: 9px 16px;
  border-radius: 8px;
  border: 1px solid var(--border, #cbd5e1);
  background: var(--surface, #ffffff);
  color: var(--text-2, #475569);
  font-weight: 600;
  cursor: pointer;
  font-size: 13px;
  transition: all 0.2s;
}

.req-tab-btn.active {
  background: var(--primary, #1e3a8a);
  color: #ffffff;
  border-color: var(--primary, #1e3a8a);
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
}

.official-form-panel {
  border-top: 4px solid var(--primary, #1e3a8a);
}

.form-doc-header {
  border-bottom: 1px solid var(--border, #e2e8f0);
  padding-bottom: 12px;
  margin-bottom: 16px;
}

.doc-code {
  display: inline-block;
  font-family: 'DM Mono', monospace;
  font-size: 11px;
  background: var(--surface-2, #f1f5f9);
  color: var(--text-3, #64748b);
  padding: 2px 6px;
  border-radius: 4px;
  font-weight: 700;
  margin-bottom: 6px;
}

.form-doc-header h3 {
  font-size: 15px;
  font-weight: 700;
  color: var(--text, #0f172a);
  margin: 0;
}

.form-doc-header small {
  color: var(--text-3, #64748b);
  font-size: 12px;
}
</style>
