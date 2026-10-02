<template>
  <div class="view active" id="view-submit-request">
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
      </div>
    </div>

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
            <button class="btn-accent" @click="submitRWSS">Submit Water & Sewerage Request</button>
          </div>
          <div class="form-doc-footer">
            <span class="doc-code">NVSU-FR-PPS-10-00 (020822)</span>
          </div>
        </div>

        <!-- FORM 2: REAS -->
        <div v-else class="form-card official-form-panel">
          <div class="form-doc-header">
            <h3>REQUEST FOR ELECTRICAL AND AIR-CONDITIONING SERVICES</h3>
            <small>Bayombong, Nueva Vizcaya · Unit Head-GSU</small>
          </div>

          <div class="form-row">
            <div class="form-group">
              <label>Location (Building / Office) *</label>
              <select v-model="reas.location">
                <option value="">Select Target Location...</option>
                <option v-for="b in buildings" :key="b" :value="b">{{ b }}</option>
              </select>
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
            <button class="btn-secondary" @click="clearREAS">Clear</button>
            <button class="btn-accent" @click="submitREAS">Submit Electrical / AC Request</button>
          </div>

          <div class="form-doc-footer">
            <span class="doc-code">NVSU-FR-PPS-03-01 (092524)</span>
          </div>
        </div>
      </div>

    </div>
  </div>
</template>

<script setup>
import { ref, reactive, watch } from 'vue';
import { useRequests } from '../composables/useRequests.js';
import { useAuth } from '../composables/useAuth.js';
import { useToast } from '../composables/useToast.js';
import UiIcon from '../components/UiIcon.vue';

const { addRequest } = useRequests();
const { activeUserName } = useAuth();
const { showToast } = useToast();

const activeTab = ref('rwss');

const buildings = [
  'Main Building',
  'Engineering Building',
  'Science Building',
  'Arts & Humanities Building',
  'Administration Building',
  'Library',
  'Gymnasium',
  'Dormitory A',
  'Dormitory B',
  'Cafeteria'
];

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

watch(activeUserName, (newVal) => {
  rwss.requester = newVal;
  reas.official = newVal;
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
  reas.item = '';
  reas.customItem = '';
  reas.brand = '';
  reas.model = '';
  reas.serial = '';
  reas.quantity = 1;
  reas.schedule = '';
  reas.damage = '';
}

function submitRWSS() {
  const target = rwss.repairTarget === 'Others' ? rwss.otherTarget : rwss.repairTarget;
  if (!rwss.building || !target || !rwss.defect.trim()) {
    showToast('Please fill out all required fields for RWSS.', 'error');
    return;
  }

  addRequest({
    title: `[RWSS] Water & Sewerage: ${target}`,
    cat: 'Plumbing',
    dept: rwss.building + (rwss.room ? ` · ${rwss.room}` : ''),
    details: `[${rwss.classification}] ${rwss.defect} (Designation: ${rwss.designation})`,
    requester: rwss.requester
  });

  clearRWSS();
  showToast('Water and Sewerage Requisition submitted! ✅', 'success');
}

function submitREAS() {
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

  addRequest({
    title: `[REAS] ${reas.category === 'COOLING' ? 'Cooling' : 'Electrical'}: ${item}`,
    cat: reas.category === 'COOLING' ? 'HVAC' : 'Electrical',
    dept: reas.location,
    details: desc,
    requester: reas.official
  });

  clearREAS();
  showToast('Electrical & AC Requisition submitted! ✅', 'success');
}
</script>

<style scoped>
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
