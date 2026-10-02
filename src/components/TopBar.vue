<template>
  <header class="topbar">
    <div class="topbar-title">{{ title }}</div>

    <div class="topbar-right" ref="topbarRightRef">
      <button
        class="icon-btn"
        @click="toggleNotif"
        id="notif-btn"
        title="Notifications"
      >
        <UiIcon name="notification" />
        <span v-if="hasUnread" class="notif-dot" id="notif-indicator"></span>
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
          <span class="notif-mark" @click="$emit('mark-all-read')">Mark all read</span>
        </div>
        <div id="notif-list">
          <template v-if="notifications.length">
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
          <div v-else class="notif-item">
            <div style="width: 8px; flex-shrink: 0"></div>
            <div>
              <div class="notif-item-text">No notifications yet.</div>
              <div class="notif-item-time">Just now</div>
            </div>
          </div>
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
  }
});

defineEmits(['trigger-search', 'mark-all-read']);

const notifOpen = ref(false);
const topbarRightRef = ref(null);

const hasUnread = computed(() => {
  return props.notifications.some((n) => !n.read);
});

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
