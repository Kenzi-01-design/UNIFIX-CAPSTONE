<template>
  <header class="topbar">
    <button
      class="icon-btn navigation-toggle"
      type="button"
      :aria-expanded="drawerOpen"
      aria-controls="app-navigation"
      :aria-label="drawerOpen ? 'Close navigation' : 'Open navigation'"
      @click="$emit('toggle-navigation', $event)"
    >
      <UiIcon :name="drawerOpen ? 'close' : 'menu'" />
    </button>
    <div class="topbar-title">{{ title }}</div>

    <div class="topbar-right" ref="topbarRightRef">
      <button
        class="icon-btn"
        @click="toggleNotif"
        id="notif-btn"
        title="Notifications"
      >
        <UiIcon name="notification" />
        <span v-if="unreadCount" class="notification-count" id="notif-indicator">
          {{ unreadCount > 99 ? '99+' : unreadCount }}
        </span>
      </button>

      <button
        class="icon-btn"
        @click="$emit('trigger-search')"
        title="Search Reports"
      >
        <UiIcon name="search" />
      </button>

      <!-- Dropdown Notification Drawer -->
      <div class="notif-panel" :class="{ open: notifOpen }" id="notif-panel">
        <div class="notif-panel-header">
          <span class="notif-panel-title">Notifications</span>
          <button class="notif-mark" type="button" :disabled="!unreadCount" @click="$emit('mark-all-read')">Mark all read</button>
        </div>
        <div id="notif-list">
          <p v-if="loading" class="notif-empty" aria-live="polite">Loading notifications…</p>
          <template v-else-if="notifications.length">
            <div
              v-for="(item, idx) in notifications"
              :key="idx"
              :class="['notif-item', { unread: !item.read }]"
            >
              <div
                :class="[item.read ? '' : 'notif-dot-sm']"
                :style="item.read ? 'width: 8px; flex-shrink: 0' : ''"
              ></div>
              <div>
                <div class="notif-item-text">{{ item.text }}</div>
                <div class="notif-item-time">{{ item.time }}</div>
              </div>
            </div>
          </template>
          <p v-else class="notif-empty">No notifications yet.</p>
        </div>
      </div>
    </div>
  </header>
</template>

<script setup>
import { ref, computed, onMounted, onBeforeUnmount } from 'vue';
import UiIcon from './UiIcon.vue';

const props = defineProps({
  title: {
    type: String,
    default: 'Dashboard'
  },
  notifications: {
    type: Array,
    default: () => []
  },
  loading: {
    type: Boolean,
    default: false
  },
  drawerOpen: {
    type: Boolean,
    default: false
  }
});

defineEmits(['trigger-search', 'mark-all-read', 'toggle-navigation']);

const notifOpen = ref(false);
const topbarRightRef = ref(null);

const unreadCount = computed(() => props.notifications.filter((item) => !item.read).length);

function toggleNotif() {
  notifOpen.value = !notifOpen.value;
}

function handleOutsideClick(e) {
  if (topbarRightRef.value && !topbarRightRef.value.contains(e.target)) {
    notifOpen.value = false;
  }
}

onMounted(() => {
  document.addEventListener('click', handleOutsideClick);
});

onBeforeUnmount(() => {
  document.removeEventListener('click', handleOutsideClick);
});
</script>
