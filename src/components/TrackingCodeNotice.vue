<template>
  <div v-if="code" class="tracking-notice" role="status">
    <div>
      <strong>{{ title }}</strong>
      <p>Save this code to check the latest status of your submission.</p>
    </div>
    <div class="tracking-code-row">
      <code>{{ code }}</code>
      <button type="button" class="btn-secondary" @click="copyCode">{{ copied ? 'Copied' : 'Copy code' }}</button>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue';

const props = defineProps({
  code: { type: String, default: '' },
  title: { type: String, default: 'Submission received' }
});
const copied = ref(false);

async function copyCode() {
  try {
    await navigator.clipboard.writeText(props.code);
    copied.value = true;
    window.setTimeout(() => { copied.value = false; }, 2000);
  } catch (error) {
    console.warn('Clipboard access was unavailable.', error);
  }
}
</script>

<style scoped>
.tracking-notice { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 14px; margin: 16px 0; padding: 16px; border: 1px solid #b7dfc6; border-radius: var(--radius-sm); background: var(--primary-bg); color: var(--text); }
.tracking-notice strong { font-size: 15px; }
.tracking-notice p { margin-top: 3px; color: var(--text-2); font-size: 12px; }
.tracking-code-row { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; }
.tracking-code-row code { padding: 8px 10px; border-radius: 6px; background: white; color: var(--primary-dark); font-family: 'DM Mono', monospace; font-size: 14px; font-weight: 800; }
</style>
