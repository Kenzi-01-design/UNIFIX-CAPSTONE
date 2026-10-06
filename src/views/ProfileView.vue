<template>
  <div class="view active" id="view-profile">
    <div class="account-grid">
      <div class="panel">
        <div class="panel-header">
          <span class="panel-title">Profile Information</span>
          <span class="panel-action" @click="resetForm">Reset</span>
        </div>
        <div class="account-content">
          <div class="profile-hero">
            <div class="profile-avatar">{{ userInitials }}</div>
            <div>
              <div class="profile-name">{{ profile.name }}</div>
              <div class="profile-role">{{ currentRole }} Account</div>
            </div>
          </div>

          <div class="form-row">
            <div class="form-group">
              <label>Full Name</label>
              <input type="text" v-model="profile.name" />
            </div>
            <div class="form-group">
              <label>University Email</label>
              <input type="email" v-model="profile.email" readonly />
            </div>
          </div>

          <div class="form-row">
            <div class="form-group">
              <label>Contact Phone</label>
              <input
                type="text"
                v-model="profile.phone"
                placeholder="e.g., 09XX XXX XXXX"
              />
            </div>
            <div class="form-group">
              <label>Department / Office</label>
              <input type="text" v-model="profile.dept" readonly />
            </div>
          </div>

          <div class="form-group">
            <label>Designated Campus / Location</label>
            <select v-model="profile.location">
              <option value="Bambang Campus">Bambang Campus</option>
            </select>
          </div>

          <div class="form-actions">
            <button class="btn-secondary" @click="resetForm">
              Reset Changes
            </button>
            <button class="btn-primary" @click="handleSave">
              Save Profile
            </button>
          </div>
        </div>
      </div>

      <div class="panel">
        <div class="panel-header">
          <span class="panel-title">Account Statistics</span>
        </div>
        <div class="account-content">
          <div class="account-stat">
            <span>Account Role</span>
            <strong>{{ currentRole }}</strong>
          </div>
          <div class="account-stat">
            <span>Reports Submitted</span>
            <strong>{{ submittedCount }}</strong>
          </div>
          <div class="account-stat">
            <span>Last Update</span>
            <strong>{{ profile.updatedAt }}</strong>
          </div>
          <button
            class="btn-secondary"
            style="width: 100%"
            @click="showToast('Password reset link sent to your email.', 'success')"
          >
            Send Password Reset Link
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { reactive, computed } from 'vue';
import { useAuth } from '../composables/useAuth.js';
import { useReports } from '../composables/useReports.js';
import { useToast } from '../composables/useToast.js';

const { currentRole, userInitials, loadProfile, saveProfile } = useAuth();
const { reports } = useReports();
const { showToast } = useToast();

const profile = reactive(loadProfile());

const submittedCount = computed(() => {
  return reports.value.filter((r) => r.reporter === profile.name).length;
});

function resetForm() {
  const loaded = loadProfile();
  Object.assign(profile, loaded);
  showToast('Profile form reset.', 'info');
}

async function handleSave() {
  if (!profile.name.trim() || !profile.email.trim()) {
    showToast('Name and university email are required.', 'error');
    return;
  }
  try {
    const updated = await saveProfile(profile);
    Object.assign(profile, updated);
    showToast('Profile saved successfully.', 'success');
  } catch (error) {
    showToast(error.message || 'Unable to save profile.', 'error');
  }
}
</script>
