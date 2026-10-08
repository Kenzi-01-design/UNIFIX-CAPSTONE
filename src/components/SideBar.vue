<template>
  <aside
    id="app-navigation"
    ref="sidebarElement"
    class="sidebar"
    :class="{ 'sidebar-drawer-open': drawerOpen }"
    :role="drawerOpen ? 'dialog' : 'complementary'"
    :aria-modal="drawerOpen ? 'true' : undefined"
    :aria-hidden="drawerMode && !drawerOpen ? 'true' : undefined"
    :inert="drawerMode && !drawerOpen"
    aria-label="Application navigation"
    tabindex="-1"
  >
    <div class="sidebar-header">
      <div class="sidebar-logo">
        <BrandMark class="logo-icon" :size="36" />
        <div class="logo-text">UNI<span>FIX</span></div>
        <button
          v-if="drawerOpen"
          class="sidebar-close"
          type="button"
          aria-label="Close navigation"
          @click="$emit('close-drawer')"
        >
          <UiIcon name="close" :size="20" />
        </button>
      </div>
      <button
        class="sidebar-user"
        type="button"
        aria-label="Open profile settings"
        @click="$emit('navigate', 'profile')"
      >
        <span class="user-avatar">{{ userInitials }}</span>
        <span class="user-info">
          <span class="user-name">{{ userName }}</span>
          <span class="user-role">{{ currentRole }}</span>
        </span>
        <span class="profile-edit-icon" aria-hidden="true">✎</span>
      </button>
    </div>

    <nav class="sidebar-nav" aria-label="Application pages">
      <section v-for="group in navigation" :key="group.label" class="sidebar-nav-group">
        <h2 class="nav-label">{{ group.label }}</h2>
        <button
          v-for="item in group.items"
          :key="item.view"
          class="nav-item"
          :class="{ active: currentView === item.view }"
          type="button"
          :aria-current="currentView === item.view ? 'page' : undefined"
          @click="$emit('navigate', item.view)"
        >
          <span class="nav-icon"><UiIcon :name="item.icon" /></span>
          <span class="nav-item-label">{{ item.label }}</span>
          <span v-if="item.badgeCount" class="nav-badge">
            {{ item.badgeCount > 99 ? '99+' : item.badgeCount }}
          </span>
        </button>
      </section>
    </nav>

    <div class="sidebar-footer">
      <button class="btn-logout" type="button" @click="$emit('logout')">
        <UiIcon name="logout" :size="16" /> Sign Out
      </button>
    </div>
  </aside>
</template>

<script setup>
import { computed, ref } from 'vue';
import UiIcon from './UiIcon.vue';
import BrandMark from './BrandMark.vue';
import { getRoleNavigation } from '../lib/navigation.js';

const props = defineProps({
  currentRole: { type: String, default: 'Admin' },
  userName: { type: String, default: 'Admin User' },
  currentView: { type: String, default: 'dashboard' },
  reportsBadgeCount: { type: Number, default: 0 },
  requestsBadgeCount: { type: Number, default: 0 },
  drawerOpen: { type: Boolean, default: false },
  drawerMode: { type: Boolean, default: false }
});

defineEmits(['navigate', 'logout', 'close-drawer']);

const sidebarElement = ref(null);
const navigation = computed(() => getRoleNavigation(props.currentRole, {
  reports: props.reportsBadgeCount,
  requests: props.requestsBadgeCount
}));
const userInitials = computed(() => props.userName
  .split(' ')
  .filter(Boolean)
  .slice(0, 2)
  .map((part) => part[0].toUpperCase())
  .join('') || 'AU');

defineExpose({ sidebarElement });
</script>
