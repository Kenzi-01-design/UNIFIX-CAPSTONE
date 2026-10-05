<template>
  <aside class="sidebar">
    <div class="sidebar-header">
      <div class="sidebar-logo">
        <div class="logo-icon"><UiIcon name="work" :size="22" /></div>
        <div class="logo-text">UNI<span>FIX</span></div>
      </div>
      <div
        class="sidebar-user"
        role="button"
        tabindex="0"
        aria-label="Open profile settings"
        @click="$emit('navigate', 'profile')"
        @keyup.enter="$emit('navigate', 'profile')"
        @keyup.space.prevent="$emit('navigate', 'profile')"
      >
        <div class="user-avatar">{{ userInitials }}</div>
        <div class="user-info">
          <div class="user-name">{{ userName }}</div>
          <div class="user-role">{{ currentRole }}</div>
        </div>
        <span class="profile-edit-icon" aria-hidden="true">✎</span>
      </div>
    </div>

    <nav class="sidebar-nav">
      <div class="nav-label">Main</div>

      <!-- FACULTY SPECIFIC NAVIGATION ORDER -->
      <template v-if="currentRole === 'Employee'">
        <div
          class="nav-item"
          :class="{ active: currentView === 'dashboard' }"
          @click="$emit('navigate', 'dashboard')"
        >
          <span class="nav-icon"><UiIcon name="dashboard" /></span> Dashboard
        </div>
        <div
          class="nav-item"
          :class="{ active: currentView === 'submit-request' }"
          @click="$emit('navigate', 'submit-request')"
        >
          <span class="nav-icon"><UiIcon name="request" /></span> Submit Request
        </div>
        <div
          class="nav-item"
          :class="{ active: currentView === 'my-requisitions' }"
          @click="$emit('navigate', 'my-requisitions')"
        >
          <span class="nav-icon"><UiIcon name="requests" /></span> Requestitions
        </div>
      </template>

      <template v-else-if="currentRole === 'Assistant'">
        <div
          class="nav-item"
          :class="{ active: currentView === 'dashboard' }"
          @click="$emit('navigate', 'dashboard')"
        >
          <span class="nav-icon"><UiIcon name="dashboard" /></span> Dashboard
        </div>
        <div
          class="nav-item"
          :class="{ active: currentView === 'reports' }"
          @click="$emit('navigate', 'reports')"
        >
          <span class="nav-icon"><UiIcon name="reports" /></span> Reports
          <span class="nav-badge">{{ reportsBadgeCount }}</span>
        </div>
        <div class="nav-label">Administration</div>
        <div
          class="nav-item"
          :class="{ active: currentView === 'admin' }"
          @click="$emit('navigate', 'admin')"
        >
          <span class="nav-icon"><UiIcon name="activity" /></span> Review Submissions
        </div>
      </template>

      <!-- ADMIN & PERSONNEL DEFAULT NAVIGATION -->
      <template v-else>
        <div
          class="nav-item"
          :class="{ active: currentView === 'dashboard' }"
          @click="$emit('navigate', 'dashboard')"
        >
          <span class="nav-icon"><UiIcon name="dashboard" /></span> Dashboard
        </div>
        <div
          class="nav-item"
          :class="{ active: currentView === 'submit' }"
          @click="$emit('navigate', 'submit')"
        >
          <span class="nav-icon"><UiIcon name="add" /></span> Submit Report
        </div>
        <div
          class="nav-item"
          :class="{ active: currentView === 'reports' }"
          @click="$emit('navigate', 'reports')"
        >
          <span class="nav-icon"><UiIcon name="reports" /></span> Reports
          <span class="nav-badge">{{ reportsBadgeCount }}</span>
        </div>
        <div
          v-if="currentRole === 'Personnel'"
          class="nav-item"
          :class="{ active: currentView === 'tasks' }"
          @click="$emit('navigate', 'tasks')"
        >
          <span class="nav-icon"><UiIcon name="tasks" /></span> Tasks
        </div>

        <template v-if="currentRole === 'Admin'">
          <div class="nav-label">Administration</div>
          <div
            class="nav-item"
            :class="{ active: currentView === 'admin' }"
            @click="$emit('navigate', 'admin')"
          >
            <span class="nav-icon"><UiIcon name="admin" /></span> Admin Panel
          </div>
          <div
            class="nav-item"
            :class="{ active: currentView === 'activity-log' }"
            @click="$emit('navigate', 'activity-log')"
          >
            <span class="nav-icon"><UiIcon name="activity" /></span> Activity Log
          </div>
          <div
            class="nav-item"
            :class="{ active: currentView === 'user-management' }"
            @click="$emit('navigate', 'user-management')"
          >
            <span class="nav-icon"><UiIcon name="users" /></span> User Management
          </div>
        </template>
      </template>

      <!-- ACCOUNT SECTION: Profile removed, Settings retained -->
      <div class="nav-label">Account</div>
      <div
        class="nav-item"
        :class="{ active: currentView === 'evaluation' }"
        @click="$emit('navigate', 'evaluation')"
      >
        <span class="nav-icon"><UiIcon name="success" /></span> System Evaluation
      </div>
      <div
        v-if="currentRole === 'Admin'"
        class="nav-item"
        :class="{ active: currentView === 'evaluation-results' }"
        @click="$emit('navigate', 'evaluation-results')"
      >
        <span class="nav-icon"><UiIcon name="activity" /></span> Evaluation Results
      </div>
      <div
        class="nav-item"
        :class="{ active: currentView === 'settings' }"
        @click="$emit('navigate', 'settings')"
      >
        <span class="nav-icon"><UiIcon name="settings" /></span> Settings
      </div>
    </nav>

    <div class="sidebar-footer">
      <button class="btn-logout" @click="$emit('logout')"><UiIcon name="logout" :size="16" /> Sign Out</button>
    </div>
  </aside>
</template>

<script setup>
import { computed } from 'vue';
import UiIcon from './UiIcon.vue';

const props = defineProps({
  currentRole: {
    type: String,
    default: 'Admin'
  },
  userName: {
    type: String,
    default: 'Admin User'
  },
  currentView: {
    type: String,
    default: 'dashboard'
  },
  reportsBadgeCount: {
    type: Number,
    default: 0
  }
});

defineEmits(['navigate', 'logout']);

const userInitials = computed(() => {
  return (
    props.userName
      .split(' ')
      .filter(Boolean)
      .slice(0, 2)
      .map((part) => part[0].toUpperCase())
      .join('') || 'AU'
  );
});
</script>
