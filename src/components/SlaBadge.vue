<template>
  <span v-if="dueAt" :class="['sla-badge', { overdue: overdue && !completed }]" :title="`Target: ${new Date(dueAt).toLocaleString()}`">
    {{ completed ? 'Completed' : formatTimeRemaining(dueAt, now) }}
  </span>
</template>

<script setup>
import { onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { formatTimeRemaining, isOverdue } from '../lib/sla.js';

const props = defineProps({
  dueAt: { type: String, default: '' },
  completed: { type: Boolean, default: false }
});
const now = ref(Date.now());
const overdue = ref(isOverdue(props.dueAt, now.value));
let timer;

function updateCountdown() {
  now.value = Date.now();
  overdue.value = isOverdue(props.dueAt, now.value);
}

watch(() => props.dueAt, updateCountdown);

onMounted(() => {
  timer = window.setInterval(updateCountdown, 60_000);
});

onBeforeUnmount(() => window.clearInterval(timer));
</script>

<style scoped>
.sla-badge { display: inline-flex; align-items: center; padding: 3px 8px; border-radius: 999px; background: var(--yellow-bg); color: var(--yellow); font-size: 10px; font-weight: 800; white-space: nowrap; }
.sla-badge.overdue { background: var(--red-bg); color: var(--red); }
</style>
