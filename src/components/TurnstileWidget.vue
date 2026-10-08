<template>
  <div ref="container" class="turnstile-widget"></div>
</template>

<script setup>
import { onBeforeUnmount, onMounted, ref } from 'vue';

const props = defineProps({ siteKey: { type: String, required: true } });
const emit = defineEmits(['success', 'expired', 'error']);
const container = ref(null);
let widgetId = null;

function loadScript() {
  return new Promise((resolve, reject) => {
    if (window.turnstile) return resolve();
    const existing = document.querySelector('script[data-turnstile-script]');
    if (existing) {
      existing.addEventListener('load', resolve, { once: true });
      existing.addEventListener('error', reject, { once: true });
      return;
    }
    const script = document.createElement('script');
    script.src = 'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit';
    script.async = true;
    script.defer = true;
    script.dataset.turnstileScript = 'true';
    script.onload = resolve;
    script.onerror = reject;
    document.head.appendChild(script);
  });
}

async function render() {
  try {
    await loadScript();
    widgetId = window.turnstile.render(container.value, {
      sitekey: props.siteKey,
      theme: 'light',
      size: window.matchMedia('(max-width: 767px)').matches ? 'flexible' : 'normal',
      callback: (token) => emit('success', token),
      'expired-callback': () => emit('expired'),
      'error-callback': (code) => emit('error', code)
    });
  } catch {
    emit('error', 'load-failed');
  }
}

function reset() {
  if (widgetId !== null && window.turnstile) window.turnstile.reset(widgetId);
}

onMounted(render);
onBeforeUnmount(() => {
  if (widgetId !== null && window.turnstile) window.turnstile.remove(widgetId);
});

defineExpose({ reset });
</script>

<style scoped>
.turnstile-widget { min-height: 65px; }
</style>
