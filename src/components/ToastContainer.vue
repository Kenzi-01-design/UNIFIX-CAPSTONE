<template>
  <div class="toast-container" id="toast-container">
    <div
      v-for="toast in toasts"
      :key="toast.id"
      :class="['toast', toast.type, { out: toast.isLeaving }]"
    >
      <span><UiIcon :name="icons[toast.type] || 'info'" :size="18" /></span>
      {{ toast.message }}
    </div>
  </div>
</template>

<script setup>
defineProps({
  toasts: {
    type: Array,
    default: () => []
  }
});

import UiIcon from './UiIcon.vue';
const icons = { success: 'success', error: 'error', info: 'info' };
</script>
