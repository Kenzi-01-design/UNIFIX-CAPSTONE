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
            <span>Email Updates on Work Orders</span>
            <input type="checkbox" v-model="settings.email" />
          </label>
          <label class="setting-row">
            <span>In-App Toast Alerts</span>
            <input type="checkbox" v-model="settings.inapp" />
          </label>
          <label class="setting-row">
            <span>Urgent Facility Alerts</span>
            <input type="checkbox" v-model="settings.sms" />
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
            <span>Urgent Alerts</span>
            <strong>{{ settings.sms ? 'Enabled' : 'Disabled' }}</strong>
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
import { reactive, computed, onMounted } from 'vue';
import { useAuth } from '../composables/useAuth.js';
import { useToast } from '../composables/useToast.js';

const { loadSettings, fetchSettings, saveSettings, resetSettings } = useAuth();
const { showToast } = useToast();

const settings = reactive(loadSettings());

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
  } catch (error) {
    showToast('Could not load saved settings; using local values.', 'error');
  }
});

async function handleSave() {
  try {
    await saveSettings(settings);
    showToast('Settings saved successfully.', 'success');
  } catch (error) {
    showToast(error.message || 'Unable to save settings.', 'error');
  }
}

function handleReset() {
  const defaults = resetSettings();
  Object.assign(settings, defaults);
  showToast('Settings restored to defaults.', 'info');
}
</script>
