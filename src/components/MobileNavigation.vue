<template>
  <nav class="mobile-navigation" aria-label="Mobile primary navigation">
    <button
      v-for="item in items"
      :key="item.view"
      class="mobile-navigation-item"
      :class="{ active: currentView === item.view }"
      type="button"
      :aria-current="currentView === item.view ? 'page' : undefined"
      @click="$emit('navigate', item.view)"
    >
      <span class="mobile-navigation-icon">
        <UiIcon :name="item.icon" :size="20" />
        <span v-if="item.badgeCount" class="mobile-navigation-badge">
          {{ item.badgeCount > 99 ? '99+' : item.badgeCount }}
        </span>
      </span>
      <span class="mobile-navigation-label">{{ item.label }}</span>
    </button>
    <button
      class="mobile-navigation-item"
      type="button"
      aria-controls="app-navigation"
      :aria-expanded="drawerOpen"
      aria-label="More navigation options"
      @click="$emit('open-drawer')"
    >
      <span class="mobile-navigation-icon"><UiIcon name="menu" :size="20" /></span>
      <span class="mobile-navigation-label">More</span>
    </button>
  </nav>
</template>

<script setup>
import { computed } from 'vue';
import UiIcon from './UiIcon.vue';
import { getMobilePrimaryNavigation } from '../lib/navigation.js';

const props = defineProps({
  currentRole: { type: String, default: 'Employee' },
  currentView: { type: String, default: 'dashboard' },
  reportsBadgeCount: { type: Number, default: 0 },
  requestsBadgeCount: { type: Number, default: 0 },
  drawerOpen: { type: Boolean, default: false }
});

defineEmits(['navigate', 'open-drawer']);

const items = computed(() => getMobilePrimaryNavigation(props.currentRole, {
  reports: props.reportsBadgeCount,
  requests: props.requestsBadgeCount
}));
</script>
