<template>
  <div id="login-page" class="page active">
    <div class="login-visual">
      <div class="orb"></div>
      <div class="orb"></div>
      <div class="orb"></div>
      <div class="login-brand">
        <div class="brand-icon"><UiIcon name="work" :size="28" /></div>
        <h1>UNIFIX</h1>
        <p>Nueva Vizcaya State University Maintenance Operations — faster repairs, safer campuses.</p>
      </div>
      <div class="login-features">
        <div class="login-feature">
          <div class="feat-icon"><UiIcon name="zap" /></div>
          <span>Real-time status tracking on campus facilities</span>
        </div>
        <div class="login-feature">
          <div class="feat-icon"><UiIcon name="notification" /></div>
          <span>Instant personnel dispatching & notification updates</span>
        </div>
        <div class="login-feature">
          <div class="feat-icon"><UiIcon name="analytics" /></div>
          <span>Operational load management for administration</span>
        </div>
      </div>
    </div>

    <div class="login-form-wrap">
      <button v-if="showBack" class="login-back" type="button" @click="$emit('back')" aria-label="Back to home">
        <span>←</span> Back to home
      </button>
      <form v-if="passwordRecoveryMode" class="recovery-form" @submit.prevent="submitRecovery">
        <h2>Set a new password</h2>
        <p class="sub">Choose a new password for your UNIFIX account.</p>
        <div class="form-group">
          <label for="recovery-password">New password</label>
          <input id="recovery-password" v-model="recoveryPassword" type="password" autocomplete="new-password" minlength="8" required />
        </div>
        <div class="form-group">
          <label for="recovery-confirm-password">Confirm new password</label>
          <input id="recovery-confirm-password" v-model="recoveryConfirmPassword" type="password" autocomplete="new-password" minlength="8" required />
        </div>
        <button class="btn-primary" type="submit" :disabled="recoveryWorking">
          {{ recoveryWorking ? 'Updating…' : 'Update Password' }}
        </button>
      </form>
      <template v-else>
      <h2>Welcome back</h2>
      <p class="sub">Sign in with your NVSU institutional account.</p>
      <p v-if="authNotice" class="login-auth-notice" role="alert">{{ authNotice }}</p>
      
      <div style="margin-bottom: 24px">
        <label style="font-size: 13px; font-weight: 700; color: var(--text-2); display: block; margin-bottom: 8px;">
          Select Portal Role
        </label>
        <div class="role-tabs">
          <button
            class="role-tab"
            :class="{ active: selectedRole === 'Employee' }"
            @click="setRole('Employee')"
          >
            <UiIcon name="reporter" :size="20" /><span>Employee</span>
          </button>
          <button
            class="role-tab"
            :class="{ active: selectedRole === 'Admin' }"
            @click="setRole('Admin')"
          >
            <UiIcon name="admin" :size="20" /><span>Admin</span>
          </button>
          <button
            class="role-tab"
            :class="{ active: selectedRole === 'Assistant' }"
            @click="setRole('Assistant')"
          >
            <UiIcon name="activity" :size="20" /><span>Assistant</span>
          </button>
          <button
            class="role-tab"
            :class="{ active: selectedRole === 'Personnel' }"
            @click="setRole('Personnel')"
          >
            <UiIcon name="tasks" :size="20" /><span>Personnel</span>
          </button>
        </div>
        <small class="role-hint">The role assigned to your account controls access; this selection does not grant a role.</small>
      </div>

      <div class="form-group">
        <label>University Email</label>
        <input
          type="email"
          v-model="email"
          placeholder="your.name@nvsu.edu.ph"
          @keyup.enter="handleLogin"
        />
      </div>

      <div class="form-group">
        <label>Password</label>
        <input
          type="password"
          v-model="password"
          placeholder="••••••••"
          @keyup.enter="handleLogin"
        />
      </div>

      <div class="login-password-help">
        <small v-if="authNoticeCode === 'wrong-credentials'">
          If an administrator invited you, open the invitation email and set your password first.
        </small>
        <button type="button" @click="handlePasswordReset">
          {{ authNoticeCode === 'wrong-credentials' ? 'Reset your password' : 'Forgot password?' }}
        </button>
      </div>

      <button class="btn-primary" :disabled="signingIn" @click="handleLogin">
        {{ signingIn ? 'Signing in…' : 'Sign In to UNIFIX' }}
      </button>
      <div v-if="authNoticeCode === 'rejected'" class="login-state-action">
        <button type="button" class="btn-secondary" :disabled="reapplying" @click="requestReapplication">
          {{ reapplying ? 'Submitting…' : 'Request a new application review' }}
        </button>
        <small>This request is limited to once every 30 days and must be reopened by an administrator. Enter your password above.</small>
      </div>

      <p class="login-register-link">
        Need an account?
        <button type="button" @click="$emit('register')">Submit a registration request</button>
      </p>

      <p style="margin-top: 20px; font-size: 12px; color: var(--text-3); text-align: center;">
        Need technical assistance? Contact
        <strong style="color: var(--text-2)">ict@nvsu.edu.ph</strong>
      </p>
      </template>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue';
import { useAuth } from '../composables/useAuth.js';
import { useReports } from '../composables/useReports.js';
import { useToast } from '../composables/useToast.js';
import { useNotifications } from '../composables/useNotifications.js';
import { isDemoMode, isSupabaseConfigured } from '../lib/supabase.js';
import UiIcon from '../components/UiIcon.vue';

defineProps({ showBack: Boolean });
const emit = defineEmits(['logged-in', 'back', 'register']);

const {
  login, loadSettings, sendPasswordReset,
  requestRegistrationReapplication, completePasswordRecovery, activeUserName, authNotice, authNoticeCode,
  passwordRecoveryMode
} = useAuth();
const { technicians } = useReports();
const { showToast } = useToast();
const { refreshNotifications } = useNotifications();

const selectedRole = ref('Admin');
const email = ref(isDemoMode ? 'admin.user@nvsu.edu.ph' : '');
const password = ref(isDemoMode ? 'password123' : '');
const signingIn = ref(false);
const reapplying = ref(false);
const recoveryPassword = ref('');
const recoveryConfirmPassword = ref('');
const recoveryWorking = ref(false);

const roleEmailMap = {
  Employee: 'prof.reyes@nvsu.edu.ph',
  Assistant: 'admin.assistant@nvsu.edu.ph',
  Admin: 'admin.user@nvsu.edu.ph',
  Personnel: 'juan.delacruz@nvsu.edu.ph'
};

function setRole(role) {
  selectedRole.value = role;
  email.value = roleEmailMap[role] || '';
}

async function handleLogin() {
  if (!email.value.trim()) {
    showToast('Please enter your university email.', 'error');
    return;
  }
  if (!password.value.trim()) {
    showToast('Please enter your password.', 'error');
    return;
  }

  signingIn.value = true;
  try {
    const authenticatedRole = await login(email.value, password.value, selectedRole.value, technicians);
    const role = isSupabaseConfigured ? authenticatedRole : selectedRole.value;
    const settings = loadSettings();
    const landing = role === 'Assistant'
      ? 'admin'
      : role === 'Personnel'
      ? 'tasks'
      : (settings.landing || 'dashboard');

    refreshNotifications(role, activeUserName.value);
    showToast(`Signed in as ${activeUserName.value}`, 'success');
    emit('logged-in', landing);
  } catch (error) {
    if (!authNotice.value) showToast(error.message || 'Unable to sign in.', 'error');
  } finally {
    signingIn.value = false;
  }
}

async function handlePasswordReset() {
  if (!email.value.trim()) {
    showToast('Enter your university email first.', 'error');
    return;
  }
  try {
    await sendPasswordReset(email.value);
    showToast('If the address is registered, a password recovery link will be sent.', 'success');
  } catch (error) {
    showToast(error.message || 'Unable to send password recovery email.', 'error');
  }
}

async function requestReapplication() {
  if (!password.value) {
    showToast('Enter your password to verify your account before requesting a new review.', 'error');
    return;
  }
  reapplying.value = true;
  try {
    await requestRegistrationReapplication(email.value, password.value);
    password.value = '';
  } catch (error) {
    showToast(error.message || 'Unable to request another application review.', 'error');
  } finally {
    reapplying.value = false;
  }
}

async function submitRecovery() {
  if (recoveryPassword.value !== recoveryConfirmPassword.value) {
    showToast('The passwords do not match.', 'error');
    return;
  }
  recoveryWorking.value = true;
  try {
    await completePasswordRecovery(recoveryPassword.value);
    recoveryPassword.value = '';
    recoveryConfirmPassword.value = '';
    showToast('Password updated. Sign in with your new password.', 'success');
  } catch (error) {
    showToast(error.message || 'Unable to update the password.', 'error');
  } finally {
    recoveryWorking.value = false;
  }
}

</script>

<style scoped>
.login-back { align-self: flex-start; display: inline-flex; align-items: center; gap: 7px; margin-bottom: 24px; padding: 0; border: 0; background: transparent; color: var(--primary); font: inherit; font-size: 13px; font-weight: 700; cursor: pointer; }
.login-back span { display: grid; place-items: center; width: 24px; height: 24px; padding-bottom: 1px; border: 1px solid var(--border); border-radius: 50%; background: var(--surface); font-size: 16px; line-height: 1; transition: var(--transition); }.login-back:hover span { transform: translateX(-3px); background: var(--primary-bg); }
.login-register-link { margin:16px 0 0; color:var(--text-2); text-align:center; font-size:13px; }
.login-register-link button { padding:0; border:0; background:none; color:var(--primary); font:inherit; font-weight:700; cursor:pointer; }
.login-auth-notice { margin:0 0 18px; padding:12px 14px; border-radius:var(--radius); background:var(--amber-bg); color:var(--amber); line-height:1.5; }
.role-hint { display:block; margin-top:8px; color:var(--text-3); }
.login-password-help { display:grid; justify-items:end; gap:6px; margin:0 0 24px; }
.login-password-help small { color:var(--text-3); text-align:right; line-height:1.4; }
.login-password-help button { padding:0; border:0; background:transparent; font:inherit; font-size:13px; color:var(--primary); font-weight:600; cursor:pointer; }
.login-state-action { display:grid; gap:8px; margin:0 0 18px; }
.login-state-action .btn-secondary { width:100%; }
.login-state-action small { color:var(--text-3); line-height:1.5; }
.recovery-form { display:grid; gap:14px; }
.recovery-form h2 { margin:0; }
.recovery-form .form-group { margin:0; }
.recovery-form .btn-primary { width:100%; }
</style>
