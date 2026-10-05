<template>
  <div class="view active" id="view-submit" :class="{ 'public-submit-page': publicMode }">
    <button v-if="publicMode" class="back-link" @click="$emit('back')">← Back to home</button>
    <div v-if="publicMode" class="public-report-heading">
      <h2>Submit a Facility Report</h2>
      <p>Describe the issue and complete the verification to send it to UNIFIX.</p>
    </div>
   
    <section v-if="submission" class="form-card submission-confirmation">
      <TrackingCodeNotice :code="submission.trackingCode" title="Your report has been submitted" />
      <p>Your report was received. Keep the tracking code to check its progress on the UNIFIX home page.</p>
      <div class="form-actions">
        <button v-if="!publicMode" class="btn-secondary" @click="$emit('view-reports')">View reports</button>
        <button class="btn-accent" @click="startAnotherReport">Submit another report</button>
      </div>
    </section>

    <div v-else class="submit-layout">
      <div class="form-card">
        <div v-if="publicMode" class="public-report-warning" role="note">
          <UiIcon name="error" :size="20" />
          <div>
            <strong>False reports are prohibited.</strong>
            <p>Each submission is recorded and reviewed. Submitting misleading or non-genuine reports may result in appropriate university action.</p>
          </div>
        </div>
        <div class="form-group">
          <label>Issue Title *</label>
          <input
            type="text"
            v-model="form.title"
            placeholder="e.g., Flickering lights in Room 204"
          />
        </div>
        <div class="form-group">
          <label>Description *</label>
          <textarea
            v-model="form.desc"
            placeholder="Describe the issue in detail. Include when it started and any safety concerns..."
          ></textarea>
        </div>
        <div class="form-row">
          <div class="form-group">
            <label>Category *</label>
            <select v-model="form.cat">
              <option value="">Select category...</option>
              <option value="Electrical">⌁ Electrical</option>
              <option value="Plumbing">⌇ Plumbing</option>
              <option value="Furniture">▣ Furniture</option>
              <option value="HVAC">❄ HVAC / AC</option>
              <option value="Network">◎ Network / IT</option>
              <option value="Civil">▦ Structural / Civil</option>
              <option value="Security">◇ Security / Locks</option>
              <option value="Sanitation">✦ Sanitation</option>
              <option value="Other">□ Other</option>
            </select>
          </div>
          <div class="form-group">
            <label>Building *</label>
            <select v-model="locationSelectValue">
              <option value="">Select building...</option>
              <option v-for="location in activeLocations" :key="location.id" :value="location.id">
                {{ toLocationLabel(location) }}
              </option>
              <option v-if="!activeLocations.length" v-for="building in demoBuildings" :key="building" :value="building">
                {{ building }}
              </option>
            </select>
            <small v-if="locationLoading">Loading managed campus locations…</small>
            <small v-else-if="locationError" class="form-inline-error">{{ locationError }} Using built-in building options.</small>
          </div>
        </div>
        <div class="form-row triple">
          <div class="form-group">
            <label>Floor</label>
            <select v-model="form.floor">
              <option value="">Select floor...</option>
              <option>Ground Floor (GF)</option>
              <option>Floor 1</option>
              <option>Floor 2</option>
              <option>Floor 3</option>
              <option>Floor 4</option>
              <option>Basement</option>
              <option>Rooftop</option>
            </select>
          </div>
          <div class="form-group">
            <label>Room / Area</label>
            <input type="text" v-model="form.room" placeholder="e.g., Room 204" />
          </div>
          <div class="form-group">
            <label>Specific Landmark</label>
            <input type="text" v-model="form.landmark" placeholder="e.g., Near staircase" />
          </div>
        </div>

        <div v-if="publicMode" class="form-group">
          <label>Email for status updates (optional)</label>
          <input
            type="email"
            v-model="form.email"
            maxlength="254"
            autocomplete="email"
            placeholder="you@example.com"
          />
          <small>Providing an email opts you in to updates about this report and its tracking code.</small>
        </div>

        <PhotoPicker v-model="selectedPhotos" label="Attach photos of the issue (optional)" />

        <section v-if="duplicatePrompt" class="duplicate-prompt" aria-live="polite">
          <strong>Similar open reports</strong>
          <p>Check whether one of these reports already describes this issue before submitting a new one.</p>
          <label v-if="similarReports.length" class="duplicate-note-label">
            Optional note for the existing report (up to 500 characters)
            <textarea v-model="duplicateNote" rows="2" maxlength="500" placeholder="Add useful details for the maintenance team…"></textarea>
          </label>
          <div v-if="duplicateLoading" class="duplicate-state" role="status">Checking for similar reports…</div>
          <div v-else-if="duplicateError" class="duplicate-error" role="alert">
            Similar reports could not be checked: {{ duplicateError }}
          </div>
          <div v-else-if="similarReports.length" class="duplicate-list">
            <article v-for="match in similarReports" :key="match.id" class="duplicate-item">
              <span><strong>{{ match.title }}</strong><small>{{ match.id }} · {{ match.loc }} · {{ formatStatus(match.status) }}</small></span>
              <button type="button" class="btn-primary" :disabled="isSubmitting" @click="addDuplicateVote(match)">
                Same issue — add vote / note
              </button>
            </article>
          </div>
          <div v-else class="duplicate-state">No similar open reports were found.</div>
          <div class="duplicate-prompt-actions">
            <button type="button" class="btn-secondary" @click="continueAsDifferent">
              {{ duplicateError ? 'Continue without a duplicate check' : 'Different issue — continue' }}
            </button>
          </div>
        </section>
        <div v-if="duplicateSaved" class="duplicate-saved" role="status">
          Your vote and note were added to <strong>{{ duplicateSaved.title }}</strong>. No second report was created.
          <button type="button" class="btn-secondary" @click="startAnotherReport">Check another issue</button>
        </div>

        <div v-if="captchaRequired" class="captcha-box">
          <label>Security verification *</label>
          <TurnstileWidget
            v-if="turnstileSiteKey"
            ref="captchaWidget"
            :site-key="turnstileSiteKey"
            @success="captchaToken = $event"
            @expired="captchaToken = ''"
            @error="handleCaptchaError"
          />
          <p v-else class="captcha-error">CAPTCHA is not configured. Add VITE_TURNSTILE_SITE_KEY to .env.local.</p>
        </div>
        <div class="form-actions">
          <button class="btn-secondary" :disabled="isSubmitting" @click="clearForm">Clear Form</button>
          <button class="btn-accent" :disabled="isSubmitting" @click="handleSubmit">
            <UiIcon v-if="!isSubmitting" name="report" :size="16" /> {{ isSubmitting ? 'Submitting…' : 'Submit Report' }}
          </button>
        </div>
      </div>

      <aside class="submit-side">
        <div class="submit-info-card">
          <div class="submit-info-title">What Happens Next</div>
          <div class="submit-steps">
            <div class="submit-step">
              <span>1</span>
              <p>UNIFIX validates your incident report.</p>
            </div>
            <div class="submit-step">
              <span>2</span>
              <p>PPSDS & Admin assigns the right maintenance technician.</p>
            </div>
            <div class="submit-step">
              <span>3</span>
              <p>Track live progress under Reports and Activity Log.</p>
            </div>
          </div>
        </div>
      </aside>
    </div>
  </div>
</template>

<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue';
import TurnstileWidget from '../components/TurnstileWidget.vue';
import UiIcon from '../components/UiIcon.vue';
import PhotoPicker from '../components/PhotoPicker.vue';
import TrackingCodeNotice from '../components/TrackingCodeNotice.vue';
import { useReports } from '../composables/useReports.js';
import { useAuth } from '../composables/useAuth.js';
import { useToast } from '../composables/useToast.js';
import { isSupabaseConfigured, submitPublicReport } from '../lib/supabase.js';
import { photoToDataUrl } from '../lib/photos.js';
import { useLocations } from '../composables/useLocations.js';
import { useDuplicateReports } from '../composables/useDuplicateReports.js';

const props = defineProps({
  publicMode: Boolean,
  captchaRequired: Boolean,
  prefillLocationId: { type: String, default: '' }
});
const emit = defineEmits(['report-submitted', 'back', 'view-reports']);

const { addReport } = useReports();
const { activeUserName } = useAuth();
const { showToast } = useToast();
const turnstileSiteKey = import.meta.env.VITE_TURNSTILE_SITE_KEY;
const captchaToken = ref('');
const captchaWidget = ref(null);
const isSubmitting = ref(false);
const selectedPhotos = ref([]);
const submission = ref(null);
const selectedLocationId = ref('');
const locationError = ref('');
const duplicatePrompt = ref(false);
const duplicateChoice = ref('');
const duplicateNote = ref('');
const duplicateSaved = ref(null);
const duplicateSearchSignature = ref('');
const {
  activeLocations,
  loading: locationLoading,
  loadLocations,
  toLocationLabel,
  demoBuildings
} = useLocations();
const {
  similarReports,
  loading: duplicateLoading,
  error: duplicateError,
  findSimilarOpenReports,
  clearSimilarReports,
  voteForDuplicate
} = useDuplicateReports();

function resetCaptcha() {
  captchaToken.value = '';
  captchaWidget.value?.reset();
}

function handleCaptchaError() {
  captchaToken.value = '';
  showToast('Security verification could not load. Please refresh and try again.', 'error');
}

const form = reactive({
  title: '',
  desc: '',
  cat: '',
  bldg: '',
  floor: '',
  room: '',
  landmark: '',
  email: ''
});

const catMeta = {
  Electrical: { icon: '⌁', bg: '#fff4e6' },
  Plumbing: { icon: '⌇', bg: '#e8f5e9' },
  Furniture: { icon: '▣', bg: '#e8eaf6' },
  HVAC: { icon: '❄', bg: '#fbe9e7' },
  Network: { icon: '◎', bg: '#e3f2fd' },
  Civil: { icon: '▦', bg: '#ede7f6' },
  Security: { icon: '◇', bg: '#fce4ec' },
  Sanitation: { icon: '✦', bg: '#e8f5e9' },
  Other: { icon: '□', bg: '#f7faf7' }
};

function clearForm() {
  form.title = '';
  form.desc = '';
  form.cat = '';
  form.bldg = '';
  form.floor = '';
  form.room = '';
  form.landmark = '';
  form.email = '';
  selectedLocationId.value = '';
  selectedPhotos.value = [];
  duplicatePrompt.value = false;
  duplicateChoice.value = '';
  duplicateNote.value = '';
  duplicateSaved.value = null;
}

function startAnotherReport() {
  submission.value = null;
  duplicateSaved.value = null;
  clearForm();
}

const locationSelectValue = computed({
  get: () => selectedLocationId.value || form.bldg,
  set: (value) => {
    const selected = activeLocations.value.find((location) => location.id === value);
    selectedLocationId.value = selected?.id || '';
    form.bldg = selected?.building || value;
    if (selected) {
      form.floor = selected.floor;
      form.room = selected.room;
    }
    duplicateChoice.value = '';
  }
});

const reportLocation = computed(() => {
  const selected = activeLocations.value.find((location) => location.id === selectedLocationId.value);
  const parts = [selected?.building || form.bldg];
  if (form.floor) parts.push(form.floor);
  if (form.room) parts.push(form.room);
  if (form.landmark) parts.push(`(${form.landmark})`);
  return parts.filter(Boolean).join(' · ');
});

function applyLocationPrefill() {
  if (!props.prefillLocationId) return;
  const selected = activeLocations.value.find((location) => location.id === props.prefillLocationId);
  if (!selected) return;
  selectedLocationId.value = selected.id;
  form.bldg = selected.building;
  form.floor = selected.floor;
  form.room = selected.room;
}

watch(activeLocations, applyLocationPrefill, { deep: true, immediate: true });
watch(() => props.prefillLocationId, applyLocationPrefill);
watch(
  () => [form.title, form.cat, form.bldg, form.floor, form.room, form.landmark],
  () => {
    duplicateChoice.value = '';
    duplicatePrompt.value = false;
    duplicateSaved.value = null;
    duplicateSearchSignature.value = '';
    clearSimilarReports();
  }
);

onMounted(() => {
  void loadLocations().catch((error) => {
    locationError.value = error.message || 'Managed campus locations could not be loaded.';
  });
});
function continueAsDifferent() {
  duplicateChoice.value = 'different';
  duplicatePrompt.value = false;
  duplicateError.value = '';
}

async function addDuplicateVote(match) {
  isSubmitting.value = true;
  try {
    await voteForDuplicate(match.id, duplicateNote.value);
    duplicateSaved.value = match;
    duplicatePrompt.value = false;
    showToast('Your vote and note were added to the existing report.', 'success');
  } catch (error) {
    showToast(error.message || 'The duplicate vote could not be saved.', 'error');
  } finally {
    isSubmitting.value = false;
  }
}

function formatStatus(status) {
  return String(status || 'pending').replaceAll('-', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase());
}

async function handleSubmit() {
  if (!form.title.trim() || !form.desc.trim() || !form.cat || !form.bldg) {
    showToast('Please fill in all required fields.', 'error');
    return;
  }
  if (props.captchaRequired && !captchaToken.value) {
    showToast('Please complete the security verification.', 'error');
    return;
  }
  if (form.email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email.trim())) {
    showToast('Enter a valid email address for status updates.', 'error');
    return;
  }
  const searchSignature = JSON.stringify([form.cat, reportLocation.value, form.title.trim()]);
  if (!duplicateChoice.value && duplicateSearchSignature.value !== searchSignature) {
    if (duplicateLoading.value) return;
    duplicatePrompt.value = true;
    try {
      await findSimilarOpenReports({
        category: form.cat,
        location: reportLocation.value,
        title: form.title
      });
      if (JSON.stringify([form.cat, reportLocation.value, form.title.trim()]) !== searchSignature) return;
      duplicateSearchSignature.value = searchSignature;
    } catch {
      return;
    }
    if (duplicateError.value || similarReports.value.length) return;
    duplicatePrompt.value = false;
    duplicateChoice.value = 'different';
  } else if (duplicateError.value && duplicateChoice.value !== 'different') {
    duplicatePrompt.value = true;
    return;
  }
  if (!duplicateChoice.value && (duplicateError.value || similarReports.value.length)) {
    duplicatePrompt.value = true;
    return;
  }

  const meta = catMeta[form.cat] || { icon: 'other', bg: '#f7faf7' };

  const reportData = {
    title: form.title.trim(),
    desc: form.desc.trim(),
    cat: form.cat,
    catIcon: meta.icon,
    catBg: meta.bg,
    loc: reportLocation.value,
    reporter: activeUserName.value || 'Public Reporter',
    reporterEmail: props.publicMode ? form.email.trim() : ''
  };

  isSubmitting.value = true;
  try {
    const encodedPhotos = props.captchaRequired && isSupabaseConfigured
      ? await Promise.all(selectedPhotos.value.map(photoToDataUrl))
      : [];
    // Authenticated reports retain the existing user-bound RLS workflow. Public
    // reports are created only by the Edge Function after server verification.
    const created = props.captchaRequired && isSupabaseConfigured
      ? await submitPublicReport(reportData, captchaToken.value, encodedPhotos)
      : await addReport(reportData, selectedPhotos.value);

    clearForm();
    if (props.captchaRequired) resetCaptcha();
    submission.value = created;
    showToast('Report submitted successfully! ✅', 'success');
    emit('report-submitted', created);
  } catch (error) {
    console.error('Public report submission failed', error);
    resetCaptcha();
    showToast(error.message || 'Could not submit the report. Please try again.', 'error');
  } finally {
    isSubmitting.value = false;
  }
}
</script>

<style scoped>
.public-submit-page { max-width: 1240px; margin: 0 auto; padding: 42px clamp(24px, 6vw, 88px) 56px; }
.back-link { border: 0; background: transparent; color: var(--primary); font: inherit; font-weight: 700; cursor: pointer; margin-bottom: 18px; }
.public-report-heading { margin-bottom: 20px; }
.public-report-heading h2 { font-size: 25px; }
.public-report-heading p { margin-top: 4px; color: var(--text-3); font-size: 13px; }
.public-report-warning { display: flex; gap: 10px; margin-bottom: 20px; padding: 13px 14px; border: 1px solid #f2c46d; border-radius: var(--radius-sm); background: #fff8e8; color: #855700; }
.public-report-warning svg { flex: 0 0 auto; margin-top: 1px; }
.public-report-warning strong { display: block; font-size: 13px; }
.public-report-warning p { margin: 3px 0 0; font-size: 12px; line-height: 1.45; }
.captcha-box { margin-top: 20px; padding: 14px; border: 1px solid var(--border); border-radius: var(--radius-sm); background: var(--surface-2); }
.captcha-box label { display: block; margin-bottom: 8px; color: var(--text-2); font-size: 13px; font-weight: 700; }
.captcha-error { color: var(--red); font-size: 12px; }
.form-actions button:disabled { cursor: wait; opacity: .7; }
.submission-confirmation { max-width: 760px; margin: 28px auto; }
.submission-confirmation > p { color: var(--text-2); font-size: 13px; }
.form-inline-error { color: var(--red); }
.duplicate-prompt,.duplicate-saved { display:grid; gap:10px; margin-top:16px; padding:16px; border:1px solid var(--border); border-radius:var(--radius-sm); background:var(--surface-2); }
.duplicate-prompt>p,.duplicate-state,.duplicate-item small { color:var(--text-3); font-size:12px; }
.duplicate-note-label { display:grid; gap:5px; color:var(--text-2); font-size:12px; font-weight:700; }
.duplicate-note-label textarea { width:100%; padding:9px; border:1px solid var(--border-dark); border-radius:6px; font:inherit; resize:vertical; }
.duplicate-list { display:grid; gap:8px; }
.duplicate-item { display:flex; justify-content:space-between; align-items:center; gap:12px; padding:10px; border:1px solid var(--border); border-radius:7px; background:var(--surface); }
.duplicate-item>span { display:grid; gap:3px; min-width:0; }
.duplicate-item small { overflow-wrap:anywhere; }
.duplicate-item button,.duplicate-prompt-actions button,.duplicate-saved button { flex:none; margin-top:0; }
.duplicate-prompt-actions { display:flex; justify-content:flex-end; }
.duplicate-error { color:var(--red); font-size:12px; }
.duplicate-saved { border-color:#b7ddc5; background:var(--green-bg); color:var(--primary-dark); font-size:13px; }
.duplicate-saved button { justify-self:start; }
@media (max-width: 600px) { .public-submit-page { padding: 24px 20px 40px; } }
@media(max-width:560px){.duplicate-item{align-items:stretch;flex-direction:column}.duplicate-item button{width:100%}}
</style>
