<template>
  <div class="view active" id="view-settings">
    <div class="account-grid">
      <div class="panel">
        <div class="panel-header">
          <span class="panel-title">Notification & Session Preferences</span>
          <span class="panel-action" @click="handleReset">Use Defaults</span>
        </div>
        <div class="account-content">
          <label class="setting-row">
            <span>Email Updates on Work Orders
              <small v-if="!settings.notificationEmailVerified">Verify a notification email below before enabling email updates.</small>
            </span>
            <input type="checkbox" v-model="settings.email" :disabled="!settings.notificationEmailVerified" />
          </label>
          <div class="form-group notification-email-setting">
            <label for="notification-email">Notification email</label>
            <input
              id="notification-email"
              v-model.trim="settings.notificationEmail"
              type="email"
              autocomplete="email"
              maxlength="254"
              placeholder="name@example.com"
            />
            <small v-if="settings.notificationEmailVerified">
              Verified: {{ settings.notificationEmail }}
            </small>
            <small v-else>A verification link will be sent to this address. It is separate from your sign-in email.</small>
            <button
              type="button"
              class="btn-secondary"
              :disabled="sendingVerification || !settings.notificationEmail.trim()"
              @click="handleVerifyNotificationEmail"
            >{{ sendingVerification ? 'Sending…' : settings.notificationEmailVerified ? 'Verify another email' : 'Send verification link' }}</button>
          </div>
          <label class="setting-row">
            <span>In-App Toast Alerts</span>
            <input type="checkbox" v-model="settings.inapp" />
          </label>
          <label class="setting-row">
            <span>SMS Notifications <small>{{ smsEnabled ? 'Add a mobile number to your profile to receive texts.' : 'SMS is not enabled for this deployment.' }}</small></span>
            <input type="checkbox" v-model="settings.sms" :disabled="!smsEnabled" />
          </label>
          <label class="setting-row">
            <span>Urgent Facility Alerts</span>
            <input type="checkbox" v-model="settings.urgentAlerts" />
          </label>

          <div class="form-row" style="margin-top: 10px">
            <div class="form-group">
              <label>Default Landing Page</label>
              <select v-model="settings.landing">
                <option value="dashboard">Dashboard</option>
                <option value="submit">Submit Report</option>
                <option value="reports">All Reports</option>
                <option value="profile">Profile</option>
              </select>
            </div>
            <div class="form-group">
              <label>Auto-Logout Inactivity Timer</label>
              <select v-model="settings.timeout">
                <option value="15">15 minutes</option>
                <option value="30">30 minutes</option>
                <option value="60">1 hour</option>
                <option value="0">Never</option>
              </select>
            </div>

            <div class="panel">
              <div class="panel-header">
                <span class="panel-title">Change Password</span>
              </div>
              <form class="account-content" @submit.prevent="handlePasswordChange">
                <div class="form-group">
                  <label for="new-password">New password</label>
                  <input id="new-password" v-model="newPassword" type="password" autocomplete="new-password" minlength="8" required />
                </div>
                <div class="form-group">
                  <label for="confirm-new-password">Confirm new password</label>
                  <input id="confirm-new-password" v-model="confirmNewPassword" type="password" autocomplete="new-password" minlength="8" required />
                </div>
                <div class="form-actions">
                  <button class="btn-primary" type="submit" :disabled="changingPassword">
                    {{ changingPassword ? 'Changing…' : 'Update Password' }}
                  </button>
                </div>
                <small>Password changes are available for Supabase accounts. Use Forgot password on the sign-in page if you cannot sign in.</small>
              </form>
            </div>
          </div>

          <div class="form-actions">
            <button class="btn-secondary" @click="handleReset">
              Reset Defaults
            </button>
            <button class="btn-primary" @click="handleSave">
              Save Settings
            </button>
          </div>
        </div>
      </div>

      <div class="panel">
        <div class="panel-header">
          <span class="panel-title">Active Configuration</span>
        </div>
        <div class="account-content">
          <div class="account-stat">
            <span>Email Notifications</span>
            <strong>{{ settings.email ? 'Enabled' : 'Disabled' }}</strong>
          </div>
          <div class="account-stat">
            <span>In-App Alerts</span>
            <strong>{{ settings.inapp ? 'Enabled' : 'Disabled' }}</strong>
          </div>
          <div class="account-stat">
            <span>SMS Notifications</span>
            <strong>{{ settings.sms ? 'Enabled' : 'Disabled' }}</strong>
          </div>
          <div class="account-stat">
            <span>Urgent Alerts</span>
            <strong>{{ settings.urgentAlerts ? 'Enabled' : 'Disabled' }}</strong>
          </div>
          <div class="account-stat">
            <span>Initial Screen</span>
            <strong>{{ landingLabel }}</strong>
          </div>
          <div class="account-stat">
            <span>Session Timeout</span>
            <strong>{{ settings.timeout === '0' ? 'Disabled' : `${settings.timeout} minutes` }}</strong>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { reactive, computed, onMounted, onBeforeUnmount, ref, watch } from 'vue';
import { useAuth } from '../composables/useAuth.js';
import { useToast } from '../composables/useToast.js';

const {
  loadSettings, fetchSettings, saveSettings, resetSettings, changePassword,
  requestNotificationEmailVerification
} = useAuth();
const { showToast } = useToast();
const newPassword = ref('');
const confirmNewPassword = ref('');
const changingPassword = ref(false);
const sendingVerification = ref(false);

const settings = reactive(loadSettings());
const verifiedNotificationEmail = ref(
  settings.notificationEmailVerified ? settings.notificationEmail.trim().toLowerCase() : ''
);
const smsEnabled = import.meta.env.VITE_SMS_NOTIFICATIONS_ENABLED === 'true';

const landingLabelMap = {
  dashboard: 'Dashboard',
  submit: 'Submit Report',
  reports: 'Reports',
  profile: 'Profile'
};

const landingLabel = computed(() => landingLabelMap[settings.landing] || 'Dashboard');

onMounted(async () => {
  try {
    Object.assign(settings, await fetchSettings());
    verifiedNotificationEmail.value = settings.notificationEmailVerified
      ? settings.notificationEmail.trim().toLowerCase()
      : '';
  } catch (error) {
    showToast('Could not load saved settings; using local values.', 'error');
  }
});

watch(() => settings.notificationEmail, (email) => {
  if (settings.notificationEmailVerified
    && email.trim().toLowerCase() !== verifiedNotificationEmail.value) {
    settings.notificationEmailVerified = false;
    settings.email = false;
  }
});

function onNotificationEmailVerified(event) {
  const email = String(event.detail?.email || '');
  if (email.toLowerCase() === settings.notificationEmail.trim().toLowerCase()) {
    verifiedNotificationEmail.value = email.toLowerCase();
    settings.notificationEmailVerified = true;
    settings.email = false;
    showToast('Notification email verified. Enable email updates and save your settings to receive work updates.', 'success');
  }
}

window.addEventListener('notification-email-verified', onNotificationEmailVerified);
onBeforeUnmount(() => window.removeEventListener('notification-email-verified', onNotificationEmailVerified));

async function handleSave() {
  try {
    if (!smsEnabled) settings.sms = false;
    await saveSettings(settings);
    showToast('Settings saved successfully.', 'success');
  } catch (error) {
    showToast(error.message || 'Unable to save settings.', 'error');
  }
}

async function handleVerifyNotificationEmail() {
  sendingVerification.value = true;
  try {
    await requestNotificationEmailVerification(settings.notificationEmail);
    verifiedNotificationEmail.value = '';
    settings.notificationEmailVerified = false;
    settings.email = false;
    showToast('Verification link sent. Check your notification email, then return to Settings.', 'success');
  } catch (error) {
    showToast(error.message || 'Unable to send the verification email.', 'error');
  } finally {
    sendingVerification.value = false;
  }
}

function handleReset() {
  const defaults = resetSettings();
  Object.assign(settings, defaults);
  showToast('Settings restored to defaults.', 'info');
}

async function handlePasswordChange() {
  if (newPassword.value !== confirmNewPassword.value) {
    showToast('The passwords do not match.', 'error');
    return;
  }
  changingPassword.value = true;
  try {
    await changePassword(newPassword.value);
    newPassword.value = '';
    confirmNewPassword.value = '';
    showToast('Password changed successfully.', 'success');
  } catch (error) {
    showToast(error.message || 'Unable to change password.', 'error');
  } finally {
    changingPassword.value = false;
  }
}
</script>
