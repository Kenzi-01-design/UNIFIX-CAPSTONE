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
      <h2>Welcome back</h2>
      <p class="sub">Sign in with your NVSU institutional account.</p>
      
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

      <div style="display: flex; justify-content: flex-end; margin-bottom: 24px">
        <button type="button" @click="handlePasswordReset" style="padding: 0; border: 0; background: transparent; font: inherit; font-size: 13px; color: var(--primary); font-weight: 600; cursor: pointer;">
          Forgot password?
        </button>
      </div>

      <button class="btn-primary" @click="handleLogin">
        Sign In to UNIFIX
      </button>

      <p style="margin-top: 20px; font-size: 12px; color: var(--text-3); text-align: center;">
        Need technical assistance? Contact
        <strong style="color: var(--text-2)">ict@nvsu.edu.ph</strong>
      </p>
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
const emit = defineEmits(['logged-in', 'back']);

const { login, loadSettings, sendPasswordReset, activeUserName } = useAuth();
const { technicians } = useReports();
const { showToast } = useToast();
const { refreshNotifications } = useNotifications();

const selectedRole = ref('Admin');
const email = ref(isDemoMode ? 'admin.user@nvsu.edu.ph' : '');
const password = ref(isDemoMode ? 'password123' : '');

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
    showToast(error.message || 'Unable to sign in.', 'error');
  }
}

async function handlePasswordReset() {
  if (!email.value.trim()) {
    showToast('Enter your university email first.', 'error');
    return;
  }
  try {
    await sendPasswordReset(email.value);
    showToast('Password recovery link sent to your email.', 'success');
  } catch (error) {
    showToast(error.message || 'Unable to send password recovery email.', 'error');
  }
}
</script>

<style scoped>
.login-back { align-self: flex-start; display: inline-flex; align-items: center; gap: 7px; margin-bottom: 24px; padding: 0; border: 0; background: transparent; color: var(--primary); font: inherit; font-size: 13px; font-weight: 700; cursor: pointer; }
.login-back span { display: grid; place-items: center; width: 24px; height: 24px; padding-bottom: 1px; border: 1px solid var(--border); border-radius: 50%; background: var(--surface); font-size: 16px; line-height: 1; transition: var(--transition); }.login-back:hover span { transform: translateX(-3px); background: var(--primary-bg); }
</style>
