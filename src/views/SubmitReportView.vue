<template>
  <div class="view active" id="view-submit" :class="{ 'public-submit-page': publicMode }">
    <button v-if="publicMode" class="back-link" @click="$emit('back')">← Back to home</button>
    <div v-if="publicMode" class="public-report-heading">
      <h2>Submit a Facility Report</h2>
      <p>Describe the issue and complete the verification to send it to UNIFIX.</p>
    </div>
   
    <div class="submit-layout">
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
            <select v-model="form.bldg">
              <option value="">Select building...</option>
              <option>Main Building</option>
              <option>Engineering Building</option>
              <option>Science Building</option>
              <option>Arts & Humanities Building</option>
              <option>Administration Building</option>
              <option>Dormitory A</option>
              <option>Dormitory B</option>
              <option>Gymnasium</option>
              <option>Library</option>
              <option>Cafeteria</option>
            </select>
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
import { reactive, ref } from 'vue';
import TurnstileWidget from '../components/TurnstileWidget.vue';
import UiIcon from '../components/UiIcon.vue';
import { useReports } from '../composables/useReports.js';
import { useAuth } from '../composables/useAuth.js';
import { useToast } from '../composables/useToast.js';
import { isSupabaseConfigured, submitPublicReport } from '../lib/supabase.js';

const props = defineProps({ publicMode: Boolean, captchaRequired: Boolean });
const emit = defineEmits(['report-submitted', 'back']);

const { addReport } = useReports();
const { activeUserName } = useAuth();
const { showToast } = useToast();
const turnstileSiteKey = import.meta.env.VITE_TURNSTILE_SITE_KEY;
const captchaToken = ref('');
const captchaWidget = ref(null);
const isSubmitting = ref(false);

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
  landmark: ''
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

  const meta = catMeta[form.cat] || { icon: 'other', bg: '#f7faf7' };
  const locParts = [form.bldg];
  if (form.floor) locParts.push(form.floor);
  if (form.room) locParts.push(form.room);
  if (form.landmark) locParts.push(`(${form.landmark})`);

  const reportData = {
    title: form.title.trim(),
    desc: form.desc.trim(),
    cat: form.cat,
    catIcon: meta.icon,
    catBg: meta.bg,
    loc: locParts.join(' · '),
    reporter: activeUserName.value || 'Public Reporter'
  };

  isSubmitting.value = true;
  try {
    // Authenticated reports retain the existing user-bound RLS workflow. Public
    // reports are created only by the Edge Function after server verification.
    const created = props.captchaRequired && isSupabaseConfigured
      ? await submitPublicReport(reportData, captchaToken.value)
      : addReport(reportData);

    clearForm();
    if (props.captchaRequired) resetCaptcha();
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
@media (max-width: 600px) { .public-submit-page { padding: 24px 20px 40px; } }
</style>
