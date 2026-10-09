<template>
  <div id="login-page" class="page active">
    <div class="login-visual">
      <div class="orb"></div>
      <div class="orb"></div>
      <div class="orb"></div>
      <svg class="login-campus-art" viewBox="0 0 1440 1000" preserveAspectRatio="xMidYMid slice" aria-hidden="true">
        <defs>
          <linearGradient id="morning-sky" x1="720" y1="0" x2="720" y2="790" gradientUnits="userSpaceOnUse">
            <stop stop-color="#9ABBC1" />
            <stop offset=".48" stop-color="#E4D5B2" />
            <stop offset="1" stop-color="#E9C98D" />
          </linearGradient>
          <linearGradient id="morning-campus" x1="720" y1="310" x2="720" y2="1000" gradientUnits="userSpaceOnUse">
            <stop stop-color="#638B72" />
            <stop offset="1" stop-color="#174B37" />
          </linearGradient>
          <linearGradient id="morning-path" x1="720" y1="680" x2="720" y2="1000" gradientUnits="userSpaceOnUse">
            <stop stop-color="#EBD9B3" />
            <stop offset="1" stop-color="#D6C39F" />
          </linearGradient>
          <radialGradient id="morning-sun" cx="0" cy="0" r="1" gradientTransform="matrix(0 220 -300 0 1110 205)" gradientUnits="userSpaceOnUse">
            <stop stop-color="#FFF4D7" stop-opacity=".9" />
            <stop offset="1" stop-color="#F5D99F" stop-opacity="0" />
          </radialGradient>
          <filter id="foliage-soften" x="-10%" y="-20%" width="120%" height="140%">
            <feGaussianBlur stdDeviation="8" />
          </filter>
        </defs>
        <path fill="url(#morning-sky)" d="M0 0h1440v1000H0z" />
        <path fill="url(#morning-sun)" d="M0 0h1440v600H0z" />
        <circle cx="1110" cy="207" r="61" fill="#F8E4B8" fill-opacity=".62" />

        <path fill="#718D8A" fill-opacity=".68" d="m0 494 116-88 86 49 149-151 118 126 119-103 124 103 126-166 139 145 114-77 154 115v250H0V494Z" />
        <path fill="#536F68" fill-opacity=".72" d="m0 556 137-81 126 49 153-107 123 91 135-73 122 78 147-116 136 87 127-75 134 70v210H0V556Z" />
        <path fill="#9EB293" fill-opacity=".76" d="M0 662c181-40 293-36 446-7 167 32 268-8 426-23 208-20 361 37 568 4v364H0V662Z" />
        <path fill="#6D9273" fill-opacity=".88" d="M0 733c190-35 347-11 494 27 178 46 335-8 508-23 157-13 293 21 438-10v273H0V733Z" />

        <path fill="url(#morning-campus)" d="M0 636c139-28 270-11 403 20 159 38 277 15 424-14 224-45 394-36 613 11v347H0V636Z" />
        <path fill="#E8D8B5" fill-opacity=".58" d="m0 690 165-22 120 13v237H0V690Zm1150-4 133 8 157 33v191h-290V686Z" />

        <g class="campus-building-scene">
          <path fill="#264D3D" fill-opacity=".25" d="M309 607h827v238H309z" />
          <path fill="#D8D1B8" d="M351 480h740v278H351z" />
          <path fill="#EDE4CB" d="M390 420h663v52H390z" />
          <path fill="#466B55" d="M332 448h778v31H332z" />
          <path fill="#E8D8B5" fill-opacity=".88" d="M373 454h696v12H373z" />
          <path fill="#315B47" d="M405 504h632v254H405z" />
          <path fill="#D1C7AA" d="M438 528h566v230H438z" />
          <path fill="#416B54" d="M474 548h494v210H474z" />
          <path fill="#EADBB9" d="M507 570h428v188H507z" />
          <path fill="#355E49" d="M554 596h334v162H554z" />
          <path fill="#BCD0C0" fill-opacity=".68" d="M583 623h276v135H583z" />
          <path fill="none" stroke="#F3E8CE" stroke-width="9" d="M721 299v459M373 452h696" />
          <path fill="none" stroke="#B9B194" stroke-width="4" d="M438 528v230m566-230v230M507 570v188m428-188v188M583 623v135m276-135v135" />
          <path fill="#E2C27C" d="M708 700a13 13 0 0 1 26 0v58h-26z" />
          <path fill="#D5C8A8" d="M277 570h141v188H277zM1022 570h141v188h-141z" />
          <path fill="#456B53" d="M260 561h177v22H260zm745 0h177v22h-177z" />
          <path fill="#BFCDB6" d="M300 598h95v160h-95zm745 0h95v160h-95z" />
        </g>

        <path fill="url(#morning-path)" d="M0 1000v-71c225-60 398-91 544-111 77-11 127-53 177-115 47 62 96 104 174 115 147 20 320 51 545 111v71H0Z" />
        <path fill="none" stroke="#F8EED8" stroke-opacity=".66" stroke-width="5" d="M721 706c-22 86-72 136-141 181M719 706c22 86 72 136 141 181" />

        <g class="campus-trees" fill="#1C5139">
          <path d="M77 764c-13-44 5-87 29-112-2-42 15-78 40-96 31 24 42 61 37 97 26 29 37 68 24 111l35 236H45l32-236Zm1110-15c-14-40 3-80 27-104-2-38 13-72 37-91 29 22 40 57 35 91 24 27 35 63 22 104l33 251h-183l29-251Z" />
          <path d="M240 816c-11-33 2-64 22-84-1-31 11-58 31-74 23 18 32 46 28 73 19 23 28 51 17 85l26 184H214l26-184Zm917-4c-10-31 2-59 21-77-1-29 10-54 29-69 22 17 30 43 27 68 18 21 26 47 16 78l24 186h-161l24-186Z" />
        </g>
        <g filter="url(#foliage-soften)" fill="#174B37" fill-opacity=".76">
          <ellipse cx="81" cy="962" rx="178" ry="118" />
          <ellipse cx="1372" cy="964" rx="200" ry="126" />
        </g>
        <path fill="none" stroke="#FFF5DC" stroke-opacity=".32" stroke-width="2" d="M0 805c112-24 199-24 300-7m840-9c105-23 198-18 300 8" />
      </svg>
      <div class="login-brand">
        <div class="login-campus-label">
          <span class="login-campus-label-icon"><UiIcon name="building" :size="14" /></span>
          <span>NVSU CAMPUS SERVICES</span>
          <i></i>
          <span>REPORT · ROUTE · RESTORE</span>
        </div>
        <div class="brand-icon"><BrandMark :size="36" /></div>
        <h1>UNIFIX</h1>
        <p>Care for our campus, built on community and pride.</p>
      </div>
      <div class="login-showcase" aria-hidden="true">
        <div class="login-showcase-topline">
          <span><i></i> CAMPUS OPERATIONS</span>
          <span>NVSU · SERVICE WORKFLOW</span>
        </div>
        <div class="login-showcase-status">
          <div class="login-showcase-icon"><UiIcon name="building" :size="21" /></div>
          <div>
            <strong>Campus care, connected</strong>
            <span>Every issue gets to the right team.</span>
          </div>
          <span class="login-showcase-check"><UiIcon name="success" :size="17" /></span>
        </div>
        <div class="login-showcase-track"><span></span></div>
        <div class="login-showcase-footer">
          <span><UiIcon name="zap" :size="15" /> Real-time updates</span>
          <span><UiIcon name="tasks" :size="15" /> Faster repairs</span>
        </div>
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
      <div class="login-form-brand" aria-label="UNIFIX, NVSU Campus Maintenance">
        <span class="login-form-brand-icon"><BrandMark :size="27" /></span>
        <span>
          <strong>UNIFIX</strong>
          <small>NVSU Campus Maintenance</small>
        </span>
      </div>
      <h2>Welcome back, Nueva Vizcayano.</h2>
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
      </div>

      <div class="form-group">
        <label for="login-email">University Email</label>
        <input
          id="login-email"
          type="email"
          v-model="email"
          placeholder="your.name@nvsu.edu.ph"
          autocomplete="username"
          required
          @keyup.enter="handleLogin"
        />
      </div>

      <div class="form-group">
        <label for="login-password">Password</label>
        <input
          id="login-password"
          type="password"
          v-model="password"
          placeholder="••••••••"
          autocomplete="current-password"
          required
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
import BrandMark from '../components/BrandMark.vue';

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
