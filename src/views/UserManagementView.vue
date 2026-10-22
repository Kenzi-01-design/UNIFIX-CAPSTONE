<template>
  <div class="view active" id="view-user-management">
    <div class="user-management-header">
      <div>
        <span class="eyebrow">Administration</span>
        <h2>User Management</h2>
        <p>Review registration requests, verify details, and manage university account access.</p>
      </div>
      <span class="user-count-badge">{{ profiles.length }} users</span>
    </div>
    <div v-if="profilesLoadError" class="profile-load-error" role="alert">
      <span>User profiles could not be loaded: {{ profilesLoadError }}</span>
      <button type="button" class="btn-secondary" :disabled="loadingProfiles" @click="refreshProfiles">
        {{ loadingProfiles ? 'Loading…' : 'Retry' }}
      </button>
    </div>

    <div class="admin-tabs user-management-tabs" role="tablist" aria-label="User management sections">
      <button
        class="admin-tab"
        :class="{ active: activeTab === 'approvals' }"
        type="button"
        role="tab"
        :aria-selected="activeTab === 'approvals'"
        @click="activeTab = 'approvals'"
      >
        Pending Approvals <span class="tab-count">{{ pendingProfiles.length }}</span>
      </button>
      <button
        class="admin-tab"
        :class="{ active: activeTab === 'invite' }"
        type="button"
        role="tab"
        :aria-selected="activeTab === 'invite'"
        @click="activeTab = 'invite'"
      >
        {{ editingId ? 'Edit User Profile' : 'Invite User' }}
      </button>
      <button
        class="admin-tab"
        :class="{ active: activeTab === 'users' }"
        type="button"
        role="tab"
        :aria-selected="activeTab === 'users'"
        @click="activeTab = 'users'"
      >
        University Users <span class="tab-count">{{ profiles.length }}</span>
      </button>
    </div>

    <div class="user-management-layout">
      <section v-if="activeTab === 'approvals'" class="panel user-list-panel">
        <div class="panel-header">
          <span class="panel-title">Registration Requests</span>
          <span class="panel-action">{{ pendingProfiles.length }} pending</span>
          <button type="button" class="btn-secondary" :disabled="loadingProfiles" @click="refreshProfiles">
            {{ loadingProfiles ? 'Refreshing…' : 'Refresh requests' }}
          </button>
        </div>
        <p v-if="reapplicationsLoadError" class="user-form-note" role="status">
          Registration requests loaded, but re-application details could not be loaded.
        </p>
        <div class="user-table-wrap responsive-table-scroll responsive-table-scroll--approvals">
          <table>
            <thead>
              <tr><th>Applicant</th><th>Requested role</th><th>Department</th><th>Contact</th><th>Confirm / assign role</th><th>Rejection reason</th><th>Review</th></tr>
            </thead>
            <tbody>
              <tr v-for="user in pendingProfiles" :key="user.id">
                <td>
                  <strong>{{ user.name }}</strong><small>{{ user.email }}</small>
                  <small v-if="user.rejectionReason">Reason: {{ user.rejectionReason }}</small>
                  <small v-if="user.reapplicationRequestedAt">Re-application requested {{ new Date(user.reapplicationRequestedAt).toLocaleString() }}</small>
                </td>
                <td>{{ user.requestedRole }}</td>
                <td>{{ user.department || 'Not set' }}</td>
                <td>{{ user.phone || 'Not provided' }}</td>
                <td>
                  <select
                    :value="approvalRoles[user.id] || user.requestedRole || 'Employee'"
                    :aria-label="`Role for ${user.name}`"
                    @change="approvalRoles[user.id] = $event.target.value"
                  >
                    <option v-for="role in roles" :key="role" :value="role">{{ role }}</option>
                  </select>
                </td>
                <td>
                  <textarea
                    v-model.trim="rejectionReasons[user.id]"
                    rows="2"
                    maxlength="500"
                    :aria-label="`Required rejection reason for ${user.name}`"
                    placeholder="Required only when rejecting"
                  ></textarea>
                </td>
                <td class="user-actions">
                  <button type="button" class="admin-action-btn resolve" :disabled="reviewingUserId === user.id" @click="reviewUser(user, 'approved')">Approve</button>
                  <button type="button" class="admin-action-btn assign" :disabled="reviewingUserId === user.id || !rejectionReasons[user.id]?.trim()" @click="reviewUser(user, 'rejected')">Reject</button>
                </td>
              </tr>
              <tr v-if="!pendingProfiles.length">
                <td colspan="7" class="empty-users">
                  {{ loadingProfiles ? 'Loading registration requests…' : 'There are no pending registration requests.' }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
        <p class="user-form-note">Applicants can request Employee, Assistant, or Personnel. Confirm or change the requested role before approving; accounts remain inactive until an Admin or Assistant approves them. Rejected accounts remain inactive, and applicants may request a new review once every 30 days.</p>
      </section>

      <section v-else-if="activeTab === 'invite'" class="panel user-form-panel">
        <div class="panel-header">
          <span class="panel-title">{{ editingId ? 'Edit User Profile' : 'Invite User' }}</span>
        </div>
        <form class="user-form" @submit.prevent="saveUser">
          <div class="form-group">
            <label>Full Name *</label>
            <input v-model.trim="form.name" required placeholder="e.g., Maria Santos" />
          </div>
          <div class="form-group">
            <label>University Email *</label>
            <input v-model.trim="form.email" type="email" required :readonly="Boolean(editingId)" placeholder="name@nvsu.edu.ph" />
          </div>
          <div v-if="!editingId || form.registrationStatus === 'approved'" class="form-group">
            <label>Role *</label>
            <select v-model="form.role" required>
              <option v-for="role in roles" :key="role" :value="role">{{ role }}</option>
            </select>
          </div>
          <div class="form-group">
            <label>Department / Office</label>
            <select v-model="form.department">
              <option value="">Select a department</option>
              <option v-for="department in departments" :key="department" :value="department">{{ department }}</option>
            </select>
          </div>
          <div class="form-group">
            <label>Phone</label>
            <input v-model.trim="form.phone" type="tel" placeholder="Optional contact number" />
          </div>
          <div class="form-group">
            <label>Location</label>
            <select v-model="form.location">
              <option value="Bambang Campus">Bambang Campus</option>
            </select>
          </div>
          <div class="form-actions">
            <button v-if="editingId" type="button" class="btn-secondary" @click="resetForm">Cancel</button>
            <button type="submit" class="btn-primary" :disabled="savingUser">
              {{ savingUser ? 'Sending…' : editingId ? 'Save Changes' : 'Send Invitation' }}
            </button>
          </div>
        </form>
        <p class="user-form-note">The invitee receives an email link to set a password. Their account becomes active with the role selected here. Demo mode only simulates the invite; no email is sent.</p>
      </section>

      <section v-else class="panel user-list-panel">
        <div class="panel-header">
          <span class="panel-title">University Users</span>
          <span class="panel-action">{{ activeUsers }} active</span>
        </div>
        <div class="user-table-wrap responsive-table-scroll responsive-table-scroll--users">
          <table>
            <thead>
              <tr><th>User</th><th>Role</th><th>Department</th><th>Approval</th><th>Access</th><th>Actions</th></tr>
            </thead>
            <tbody>
              <tr v-for="user in profiles" :key="user.id">
                <td><strong>{{ user.name }}</strong><small>{{ user.email }}</small></td>
                <td><span class="user-role-pill">{{ user.role }}</span></td>
                <td>{{ user.department || 'Not set' }}</td>
                <td>{{ formatRegistrationStatus(user.registrationStatus) }}</td>
                <td><span :class="['tag', user.isActive ? 'resolved' : 'pending']">{{ user.isActive ? 'Active' : 'Inactive' }}</span></td>
                <td class="user-actions">
                  <button class="admin-action-btn assign" @click="editUser(user)">Edit</button>
                  <button
                    v-if="user.registrationStatus === 'rejected' && (user.reapplicationRequestedAt || isDemoMode)"
                    class="admin-action-btn assign"
                    :disabled="reopeningUserId === user.id"
                    @click="reopenUser(user)"
                  >
                    {{ reopeningUserId === user.id ? 'Reopening…' : 'Re-open application' }}
                  </button>
                  <button
                    v-else-if="user.registrationStatus === 'approved'"
                    class="admin-action-btn"
                    :class="user.isActive ? 'resolve' : 'assign'"
                    :disabled="user.isActive && reviewingUserId === user.id"
                    @click="toggleUser(user)"
                  >
                    {{ user.isActive ? 'Deactivate' : 'Reactivate' }}
                  </button>
                </td>
              </tr>
              <tr v-if="!profiles.length"><td colspan="6" class="empty-users">No user profiles found.</td></tr>
            </tbody>
          </table>
        </div>
      </section>
    </div>
  </div>
</template>

<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { isDemoMode } from '../lib/supabase.js';
import { useUserProfiles } from '../composables/useUserProfiles.js';
import { useToast } from '../composables/useToast.js';
import { resolveApprovalRole } from '../lib/registrationRoles.js';

const {
  profiles, profilesLoadError, reapplicationsLoadError, roles, loadProfiles, inviteUser, updateProfile,
  setProfileActive, reviewRegistration, reopenRegistration
} = useUserProfiles();
const { showToast } = useToast();
const activeTab = ref('approvals');
const loadingProfiles = ref(false);
const savingUser = ref(false);
const editingId = ref('');
const reviewingUserId = ref('');
const reopeningUserId = ref('');
const departments = ['CIT', 'CAS', 'COE', 'CTE'];
const form = reactive({ name: '', email: '', role: 'Employee', department: '', phone: '', location: 'Bambang Campus' });
const activeUsers = computed(() => profiles.value.filter((user) => user.isActive).length);
const pendingProfiles = computed(() => profiles.value.filter((user) => user.registrationStatus === 'pending'));
const approvalRoles = reactive({});
const rejectionReasons = reactive({});

onMounted(refreshProfiles);

async function refreshProfiles() {
  loadingProfiles.value = true;
  try {
    await loadProfiles();
  } catch {
    showToast('Could not load university users. Check database permissions and retry.', 'error');
  } finally {
    loadingProfiles.value = false;
  }
}

function resetForm() {
  editingId.value = '';
  Object.assign(form, { name: '', email: '', role: 'Employee', department: '', phone: '', location: 'Bambang Campus' });
}

function editUser(user) {
  editingId.value = user.id;
  Object.assign(form, user);
  activeTab.value = 'invite';
}

async function saveUser() {
  savingUser.value = true;
  try {
    if (editingId.value) {
      await updateProfile({ id: editingId.value, ...form });
      showToast('User profile updated.', 'success');
    } else {
      await inviteUser(form);
      showToast(
        isDemoMode ? 'Demo invite simulated. No email was sent.' : 'Invitation email sent.',
        'success'
      );
    }
    resetForm();
    activeTab.value = 'users';
  } catch (error) {
    showToast(error.message || 'Unable to save user profile.', 'error');
  } finally {
    savingUser.value = false;
  }
}

async function toggleUser(user) {
  try {
    await setProfileActive(user.id, !user.isActive);
    showToast(`${user.name} is now ${user.isActive ? 'active' : 'inactive'}.`, 'success');
  } catch (error) {
    showToast(error.message || 'Unable to update account access.', 'error');
  }
}

async function reviewUser(user, decision) {
  reviewingUserId.value = user.id;
  try {
    const status = decision === 'approved' ? 'approved' : 'rejected';
    await reviewRegistration(
      user.id,
      status,
      resolveApprovalRole(approvalRoles[user.id], user.requestedRole),
      rejectionReasons[user.id] || ''
    );
    showToast(
      status === 'approved' ? `${user.name} was approved.` : `${user.name}'s registration was rejected.`,
      'success'
    );
  } catch (error) {
    showToast(error.message || 'Unable to review this registration.', 'error');
  } finally {
    reviewingUserId.value = '';
  }
}

async function reopenUser(user) {
  reopeningUserId.value = user.id;
  try {
    await reopenRegistration(user.id);
    showToast(`${user.name}'s application is pending Admin review again.`, 'success');
  } catch (error) {
    showToast(error.message || 'Unable to reopen this application.', 'error');
  } finally {
    reopeningUserId.value = '';
  }
}

function formatRegistrationStatus(status) {
  return String(status || 'approved').replace(/\b\w/g, (letter) => letter.toUpperCase());
}
</script>
