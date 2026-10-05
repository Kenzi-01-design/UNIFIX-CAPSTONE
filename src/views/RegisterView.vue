<template>
  <div id="register-page" class="page active">
    <div class="register-card">
      <button type="button" class="register-back" @click="$emit('back')">← Back</button>
      <span class="eyebrow">NUEVA VIZCAYA STATE UNIVERSITY</span>
      <h1>Create your UNIFIX account</h1>
      <p class="register-intro">Submit your details for administrator review. Your account stays inactive until approved.</p>

      <div v-if="submitted" class="register-success" role="status">
        <h2>Registration submitted</h2>
        <p>If email confirmation is enabled, confirm your address using the message Supabase sends. An administrator must also approve your account before you can sign in.</p>
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
        </div>
        <div class="form-group">
          <label for="registration-department">Department / office</label>
          <input id="registration-department" v-model.trim="form.department" maxlength="160" autocomplete="organization" />
        </div>
        <div class="form-group">
          <label for="registration-phone">Phone</label>
          <input id="registration-phone" v-model.trim="form.phone" type="tel" maxlength="40" autocomplete="tel" />
        </div>
        <div class="form-group">
          <label for="registration-location">Campus / location</label>
          <input id="registration-location" v-model.trim="form.location" maxlength="160" autocomplete="address-level2" />
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
import { reactive, ref } from 'vue';
import { isDemoMode, isSupabaseConfigured, supabase } from '../lib/supabase.js';

defineEmits(['back', 'open-login']);

const form = reactive({
  name: '',
  email: '',
  department: '',
  phone: '',
  location: 'Main Campus',
  password: '',
  confirmPassword: ''
});
const submitting = ref(false);
const submitted = ref(false);
const error = ref('');

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
    error.value = registrationError.message || 'Unable to submit your registration.';
  } finally {
    submitting.value = false;
  }
}
</script>

<style scoped>
#register-page { min-height:100vh; display:grid; place-items:center; padding:28px 16px; background:var(--bg); }
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
