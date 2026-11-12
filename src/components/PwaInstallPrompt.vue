<template>
  <Transition name="install-prompt">
    <aside
      v-if="visible"
      class="install-prompt"
      :class="{ 'install-prompt--above-navigation': props.hasMobileNavigation }"
      aria-label="Install UNIFIX"
    >
      <div class="install-prompt-icon" aria-hidden="true">
        <UiIcon name="download" :size="21" />
      </div>
      <div class="install-prompt-copy">
        <strong>Install UNIFIX</strong>
        <span v-if="!showIosInstructions">Quick access to campus maintenance</span>
        <span v-else>Tap Share, then choose “Add to Home Screen.”</span>
      </div>
      <button class="install-prompt-action" type="button" @click="handleInstall">
        <UiIcon v-if="!showIosInstructions" name="download" :size="16" />
        {{ deferredPrompt ? 'Install' : showIosInstructions ? 'Got it' : 'How to install' }}
      </button>
      <button
        class="install-prompt-dismiss"
        type="button"
        aria-label="Dismiss install prompt"
        @click="dismissPrompt"
      >
        <UiIcon name="close" :size="18" />
      </button>
    </aside>
  </Transition>
</template>

<script setup>
import { onBeforeUnmount, onMounted, ref } from 'vue';
import UiIcon from './UiIcon.vue';

const props = defineProps({
  hasMobileNavigation: { type: Boolean, default: false }
});

const dismissedKey = 'unifix-install-prompt-dismissed';
const deferredPrompt = ref(null);
const visible = ref(false);
const showIosInstructions = ref(false);

function isInstalled() {
  return window.matchMedia('(display-mode: standalone)').matches || navigator.standalone === true;
}

function isIosDevice() {
  return /iPad|iPhone|iPod/.test(navigator.userAgent)
    || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
}

function wasDismissed() {
  try {
    return sessionStorage.getItem(dismissedKey) === 'true';
  } catch (error) {
    console.warn('Could not read the UNIFIX install prompt preference.', error);
    return false;
  }
}

function updateVisibility() {
  visible.value = !isInstalled() && !wasDismissed() && (Boolean(deferredPrompt.value) || isIosDevice());
}

function handleBeforeInstallPrompt(event) {
  event.preventDefault();
  deferredPrompt.value = event;
  updateVisibility();
}

function handleAppInstalled() {
  visible.value = false;
  deferredPrompt.value = null;
}

async function handleInstall() {
  if (!deferredPrompt.value) {
    showIosInstructions.value = !showIosInstructions.value;
    return;
  }

  const installPrompt = deferredPrompt.value;
  deferredPrompt.value = null;

  try {
    await installPrompt.prompt();
    const choice = await installPrompt.userChoice;
    if (choice.outcome === 'accepted') {
      visible.value = false;
      return;
    }
    dismissPrompt();
  } catch (error) {
    deferredPrompt.value = installPrompt;
    console.error('Could not open the UNIFIX install prompt.', error);
  }
}

function dismissPrompt() {
  visible.value = false;
  showIosInstructions.value = false;
  try {
    sessionStorage.setItem(dismissedKey, 'true');
  } catch (error) {
    console.warn('Could not save the UNIFIX install prompt preference.', error);
  }
}

onMounted(() => {
  window.addEventListener('beforeinstallprompt', handleBeforeInstallPrompt);
  window.addEventListener('appinstalled', handleAppInstalled);
  updateVisibility();
});

onBeforeUnmount(() => {
  window.removeEventListener('beforeinstallprompt', handleBeforeInstallPrompt);
  window.removeEventListener('appinstalled', handleAppInstalled);
});
</script>

<style scoped>
.install-prompt {
  position: fixed;
  z-index: 9998;
  right: 24px;
  bottom: 24px;
  left: 24px;
  display: flex;
  align-items: center;
  gap: 14px;
  width: min(560px, calc(100vw - 48px));
  margin-inline: auto;
  padding: 12px 14px;
  border: 1px solid rgba(255, 255, 255, 0.12);
  border-radius: 20px;
  background: #14251c;
  color: #fff;
  box-shadow: 0 14px 36px rgba(10, 25, 16, 0.28);
}

.install-prompt-icon {
  display: grid;
  flex: 0 0 44px;
  width: 44px;
  height: 44px;
  place-items: center;
  border-radius: 14px;
  background: rgba(99, 211, 166, 0.16);
  color: #6fe0b0;
}

.install-prompt-copy {
  display: grid;
  flex: 1;
  min-width: 0;
  line-height: 1.35;
}

.install-prompt-copy strong {
  font-size: 14px;
  font-weight: 750;
}

.install-prompt-copy span {
  color: #b7c8be;
  font-size: 12px;
}

.install-prompt-action {
  display: inline-flex;
  flex: 0 0 auto;
  align-items: center;
  justify-content: center;
  gap: 7px;
  min-height: 44px;
  padding: 0 17px;
  border: 0;
  border-radius: 13px;
  background: #63d3a6;
  color: #10251b;
  font-size: 14px;
  font-weight: 750;
  cursor: pointer;
  transition: background-color 160ms ease, transform 160ms ease;
}

.install-prompt-action:hover {
  transform: translateY(-1px);
  background: #7be2b9;
}

.install-prompt-dismiss {
  display: grid;
  flex: 0 0 32px;
  width: 32px;
  height: 40px;
  place-items: center;
  border: 0;
  border-radius: 8px;
  background: transparent;
  color: #afbeb5;
  cursor: pointer;
}

.install-prompt-dismiss:hover {
  background: rgba(255, 255, 255, 0.1);
  color: #fff;
}

.install-prompt-enter-active,
.install-prompt-leave-active {
  transition: opacity 180ms ease, transform 180ms ease;
}

.install-prompt-enter-from,
.install-prompt-leave-to {
  opacity: 0;
  transform: translateY(12px);
}

@media (max-width: 600px) {
  .install-prompt {
    right: 12px;
    bottom: 24px;
    left: 12px;
    gap: 10px;
    width: auto;
    padding: 10px;
    border-radius: 17px;
  }

  .install-prompt--above-navigation {
    bottom: calc(88px + env(safe-area-inset-bottom));
  }

  .install-prompt-icon {
    flex-basis: 40px;
    width: 40px;
    height: 40px;
  }

  .install-prompt-copy strong {
    font-size: 13px;
  }

  .install-prompt-copy span {
    font-size: 11px;
  }

  .install-prompt-action {
    min-height: 40px;
    padding-inline: 12px;
    font-size: 12px;
  }

  .install-prompt-dismiss {
    flex-basis: 26px;
    width: 26px;
  }
}

@media (prefers-reduced-motion: reduce) {
  .install-prompt-enter-active,
  .install-prompt-leave-active {
    transition: none;
  }
}
</style>
