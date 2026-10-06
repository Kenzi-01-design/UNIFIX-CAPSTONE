<template>
  <div id="register-page" class="page active">
    <div class="register-card">
      <button type="button" class="register-back" @click="$emit('back')">← Back</button>
      <span class="eyebrow">NUEVA VIZCAYA STATE UNIVERSITY</span>
      <h1>Create your UNIFIX account</h1>
      <p class="register-intro">Submit your details for administrator review. Email confirmation is not required to sign in; your account stays inactive until approved.</p>

      <div v-if="submitted" class="register-success" role="status">
        <h2>Registration submitted</h2>
        <p>Your account is ready for sign-in after an administrator approves it. You can optionally add and verify a notification email in Settings to receive updates about your reports and requests.</p>
        <button type="button" class="btn-primary" @click="$emit('open-login')">Return to sign in</button>
      </div>

      <form v-else class="register-form" @submit.prevent="submitRegistration">
        <div class="form-group">
          <label for="registration-name">Full name *</label>
          <input id="registration-name" v-model.trim="form.name" autocomplete="name" maxlength="120" required />
        </div>
        <div class="form-group">
          <label for="registration-email">University email *</label>
          <input id="registration-email" v-model.trim="form.email" type="email" autocomplete="email" maxlength="254" required />
          <small v-if="emailDomainError" class="register-error" role="alert">{{ emailDomainError }}</small>
          <small v-else>Allowed domain{{ allowedEmailDomains.length === 1 ? '' : 's' }}: {{ allowedEmailDomains.map((domain) => `@${domain}`).join(', ') }}</small>
        </div>
        <div class="form-group">
          <label for="registration-department">Department / office</label>
          <select id="registration-department" v-model="form.department" autocomplete="organization">
            <option value="">Select a department</option>
            <option v-for="department in departments" :key="department" :value="department">{{ department }}</option>
          </select>
        </div>
        <div class="form-group">
          <label for="registration-phone">Phone</label>
          <input id="registration-phone" v-model.trim="form.phone" type="tel" maxlength="40" autocomplete="tel" />
        </div>
        <div class="form-group">
          <label for="registration-location">Campus / location</label>
          <select id="registration-location" v-model="form.location" autocomplete="address-level2">
            <option value="Bambang Campus">Bambang Campus</option>
          </select>
        </div>
        <div class="form-group">
          <label for="registration-password">Password *</label>
          <input id="registration-password" v-model="form.password" type="password" autocomplete="new-password" minlength="8" required />
          <small>Use at least 8 characters.</small>
        </div>
        <div class="form-group">
          <label for="registration-confirm-password">Confirm password *</label>
          <input id="registration-confirm-password" v-model="form.confirmPassword" type="password" autocomplete="new-password" minlength="8" required />
        </div>
        <p v-if="error" class="register-error" role="alert">{{ error }}</p>
        <button class="btn-primary" type="submit" :disabled="submitting">
          {{ submitting ? 'Submitting…' : 'Submit for approval' }}
        </button>
      </form>
      <p v-if="!submitted" class="register-login">Already have an account? <button type="button" @click="$emit('open-login')">Sign in</button></p>
    </div>
  </div>
</template>

<script setup>
import { computed, reactive, ref } from 'vue';
import { isDemoMode, isSupabaseConfigured, supabase } from '../lib/supabase.js';

defineEmits(['back', 'open-login']);

const form = reactive({
  name: '',
  email: '',
  department: '',
  phone: '',
  location: 'Bambang Campus',
  password: '',
  confirmPassword: ''
});
const submitting = ref(false);
const submitted = ref(false);
const error = ref('');
const departments = ['CIT', 'CAS', 'COE', 'CTE'];
// If no UX domains are configured, show the same initial default as the server migration.
const allowedEmailDomains = (import.meta.env.VITE_ALLOWED_EMAIL_DOMAINS || 'nvsu.edu.ph')
  .split(',')
  .map((domain) => domain.trim().toLowerCase().replace(/^@/, ''))
  .filter(Boolean);
const emailDomainError = computed(() => {
  const normalizedEmail = form.email.trim().toLowerCase();
  if (!normalizedEmail || !normalizedEmail.includes('@')) return '';
  const domain = normalizedEmail.slice(normalizedEmail.lastIndexOf('@') + 1);
  if (allowedEmailDomains.includes(domain)) return '';
  return `Use an email address from ${allowedEmailDomains.map((item) => `@${item}`).join(', ')}.`;
});

async function submitRegistration() {
  error.value = '';
  if (!isSupabaseConfigured || isDemoMode || !supabase) {
    error.value = 'Account registration is unavailable in demo mode. Configure Supabase and try again.';
    return;
  }
  if (form.password.length < 8) {
    error.value = 'Your password must contain at least 8 characters.';
    return;
  }
  if (form.password !== form.confirmPassword) {
    error.value = 'The passwords do not match.';
    return;
  }
  if (emailDomainError.value) {
    error.value = emailDomainError.value;
    return;
  }

  submitting.value = true;
  try {
    const { error: signUpError } = await supabase.auth.signUp({
      email: form.email,
      password: form.password,
      options: {
        data: {
          name: form.name,
          department: form.department,
          phone: form.phone,
          location: form.location
        },
        emailRedirectTo: window.location.origin
      }
    });
    if (signUpError) throw signUpError;
    submitted.value = true;
  } catch (registrationError) {
    const message = registrationError.message || '';
    if (/already registered|user already exists|already been registered/i.test(message)) {
      error.value = 'We could not create this registration. If you already have an account, sign in or reset your password.';
    } else if (/rate limit|too many requests/i.test(message)) {
      error.value = 'Too many attempts. Please wait a while before trying again.';
    } else {
      error.value = message || 'Unable to submit your registration.';
    }
  } finally {
    submitting.value = false;
  }
}
</script>

<style scoped>
#register-page { min-height:100vh; min-height:100dvh; display:grid; place-items:center; padding:28px 16px; background:var(--bg); }
.register-card { width:min(100%,560px); padding:32px; border:1px solid var(--border); border-radius:var(--radius-lg); background:var(--surface); box-shadow:var(--shadow); }
.register-back { display:block; margin:0 0 22px; padding:0; border:0; background:none; color:var(--primary); font:inherit; font-weight:700; cursor:pointer; }
.register-card h1 { margin:8px 0; color:var(--text); font-size:clamp(24px,4vw,32px); }
.register-intro,.register-success p { color:var(--text-2); line-height:1.6; }
.register-form { display:grid; gap:14px; margin-top:22px; }
.register-form .form-group { margin:0; }
.register-form input { width:100%; }
.register-form small { display:block; margin-top:5px; color:var(--text-3); }
.register-form .btn-primary,.register-success .btn-primary { width:100%; margin-top:4px; }
.register-error { margin:0; color:var(--red); font-size:13px; }
.register-success { margin-top:24px; padding:18px; border-radius:var(--radius); background:var(--green-bg); }
.register-login { margin:20px 0 0; color:var(--text-2); text-align:center; font-size:13px; }
.register-login button { padding:0; border:0; background:none; color:var(--primary); font:inherit; font-weight:700; cursor:pointer; }
@media(max-width:520px) { .register-card { padding:22px; } }
</style>
