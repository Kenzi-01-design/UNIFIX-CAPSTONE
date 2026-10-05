<template>
  <div class="view active" id="view-user-management">
    <div class="user-management-header">
      <div>
        <span class="eyebrow">Administration</span>
        <h2>User Management</h2>
        <p>Manage university profiles and account access.</p>
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
        :class="{ active: activeTab === 'profile' }"
        type="button"
        role="tab"
        :aria-selected="activeTab === 'profile'"
        @click="activeTab = 'profile'"
      >
        {{ editingId ? 'Edit User Profile' : 'Add User Profile' }}
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
        </div>
        <div class="user-table-wrap">
          <table>
            <thead>
              <tr><th>Applicant</th><th>Department</th><th>Contact</th><th>Assign role</th><th>Review</th></tr>
            </thead>
            <tbody>
              <tr v-for="user in pendingProfiles" :key="user.id">
                <td><strong>{{ user.name }}</strong><small>{{ user.email }}</small></td>
                <td>{{ user.department || 'Not set' }}</td>
                <td>{{ user.phone || 'Not provided' }}</td>
                <td>
                  <select
                    :value="approvalRoles[user.id] || 'Employee'"
                    :aria-label="`Role for ${user.name}`"
                    @change="approvalRoles[user.id] = $event.target.value"
                  >
                    <option v-for="role in roles" :key="role" :value="role">{{ role }}</option>
                  </select>
                </td>
                <td class="user-actions">
                  <button type="button" class="admin-action-btn resolve" @click="reviewUser(user, 'approved')">Approve</button>
                  <button type="button" class="admin-action-btn assign" @click="reviewUser(user, 'rejected')">Reject</button>
                </td>
              </tr>
              <tr v-if="!pendingProfiles.length">
                <td colspan="5" class="empty-users">There are no pending registration requests.</td>
              </tr>
            </tbody>
          </table>
        </div>
        <p class="user-form-note">Approved users can sign in after any required email confirmation. Rejected accounts remain inactive.</p>
      </section>

      <section v-else-if="activeTab === 'profile'" class="panel user-form-panel">
        <div class="panel-header">
          <span class="panel-title">{{ editingId ? 'Edit User Profile' : 'Add User Profile' }}</span>
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
          <div class="form-group">
            <label>Role *</label>
            <select v-model="form.role" required>
              <option v-for="role in roles" :key="role" :value="role">{{ role }}</option>
            </select>
          </div>
          <div class="form-group">
            <label>Department / Office</label>
            <input v-model.trim="form.department" placeholder="e.g., Campus Administration" />
          </div>
          <div class="form-group">
            <label>Phone</label>
            <input v-model.trim="form.phone" type="tel" placeholder="Optional contact number" />
          </div>
          <div class="form-group">
            <label>Location</label>
            <input v-model.trim="form.location" placeholder="Main Campus" />
          </div>
          <div class="form-actions">
            <button v-if="editingId" type="button" class="btn-secondary" @click="resetForm">Cancel</button>
            <button type="submit" class="btn-primary">{{ editingId ? 'Save Changes' : 'Add User' }}</button>
          </div>
        </form>
        <p class="user-form-note">This manages the profile record. Create the matching login in Supabase Authentication.</p>
      </section>

      <section v-else class="panel user-list-panel">
        <div class="panel-header">
          <span class="panel-title">University Users</span>
          <span class="panel-action">{{ activeUsers }} active</span>
        </div>
        <div class="user-table-wrap">
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
                  <button class="admin-action-btn" :class="user.isActive ? 'resolve' : 'assign'" @click="toggleUser(user)">
                    {{ user.isActive ? 'Deactivate' : 'Activate' }}
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
import { useUserProfiles } from '../composables/useUserProfiles.js';
import { useToast } from '../composables/useToast.js';

const { profiles, profilesLoadError, roles, loadProfiles, addProfile, updateProfile, setProfileActive, reviewRegistration } = useUserProfiles();
const { showToast } = useToast();
const activeTab = ref('profile');
const loadingProfiles = ref(false);
const editingId = ref('');
const form = reactive({ name: '', email: '', role: 'Employee', department: '', phone: '', location: 'Main Campus' });
const activeUsers = computed(() => profiles.value.filter((user) => user.isActive).length);
const pendingProfiles = computed(() => profiles.value.filter((user) => user.registrationStatus === 'pending'));
const approvalRoles = reactive({});

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
  Object.assign(form, { name: '', email: '', role: 'Employee', department: '', phone: '', location: 'Main Campus' });
}

function editUser(user) {
  editingId.value = user.id;
  Object.assign(form, user);
  activeTab.value = 'profile';
}

async function saveUser() {
  try {
    if (editingId.value) {
      await updateProfile({ id: editingId.value, ...form });
      showToast('User profile updated.', 'success');
    } else {
      await addProfile(form);
      showToast('User profile added. Create its Auth account in Supabase.', 'success');
    }
    resetForm();
    activeTab.value = 'users';
  } catch (error) {
    showToast(error.message || 'Unable to save user profile.', 'error');
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
  try {
    const status = decision === 'approved' ? 'approved' : 'rejected';
    await reviewRegistration(user.id, status, approvalRoles[user.id] || 'Employee');
    showToast(
      status === 'approved' ? `${user.name} was approved.` : `${user.name}'s registration was rejected.`,
      'success'
    );
  } catch (error) {
    showToast(error.message || 'Unable to review this registration.', 'error');
  }
}

function formatRegistrationStatus(status) {
  return String(status || 'approved').replace(/\b\w/g, (letter) => letter.toUpperCase());
}
</script>
