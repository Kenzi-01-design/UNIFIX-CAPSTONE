<template>
  <main class="password-recovery-page">
    <section class="password-recovery-card" aria-labelledby="password-recovery-title">
      <button class="back-link public-back-button" type="button" @click="$emit('back')">
        <UiIcon name="arrow-left" :size="16" /> Back to sign in
      </button>
      <span class="eyebrow">ACCOUNT RECOVERY</span>
      <h1 id="password-recovery-title">Reset your password</h1>
      <p class="password-recovery-intro">
        Enter the Gmail address you previously added and verified in Settings. We’ll send a secure recovery link there.
      </p>

      <form v-if="!sent" class="password-recovery-form" @submit.prevent="requestRecovery">
        <label for="recovery-email">Verified Gmail address</label>
        <input
          id="recovery-email"
          v-model.trim="email"
          type="email"
          autocomplete="email"
          maxlength="254"
          placeholder="name@gmail.com"
          required
        />
        <p v-if="error" class="password-recovery-error" role="alert">{{ error }}</p>
        <button class="btn-primary" type="submit" :disabled="sending">
          {{ sending ? 'Sending…' : 'Send recovery link' }}
        </button>
      </form>

      <div v-else class="password-recovery-result" role="status">
        <h2>Check your inbox</h2>
        <p>If that Gmail address is verified for an account, a password recovery link will be sent to it.</p>
        <button class="btn-primary" type="button" @click="$emit('back')">Back to sign in</button>
      </div>
    </section>
  </main>
</template>

<script setup>
import { ref } from 'vue';
import { useAuth } from '../composables/useAuth.js';
import UiIcon from '../components/UiIcon.vue';

defineEmits(['back']);

const { sendPasswordReset } = useAuth();
const email = ref('');
const sending = ref(false);
const sent = ref(false);
const error = ref('');

async function requestRecovery() {
  sending.value = true;
  error.value = '';
  try {
    await sendPasswordReset(email.value);
    sent.value = true;
  } catch (requestError) {
    error.value = requestError.message || 'The recovery email could not be sent. Please try again later.';
  } finally {
    sending.value = false;
  }
}
</script>

<style scoped>
.password-recovery-page {
  display: grid;
  min-height: 100vh;
  place-items: center;
  padding: 24px;
  background: var(--bg);
}
.password-recovery-card {
  width: min(100%, 480px);
  padding: clamp(22px, 5vw, 36px);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  background: var(--surface);
  box-shadow: var(--shadow);
}
.back-link { margin: 0 0 24px; }
.password-recovery-card h1 { margin: 8px 0; font-size: clamp(24px, 6vw, 30px); }
.password-recovery-intro,
.password-recovery-result p { margin: 0 0 22px; color: var(--text-2); line-height: 1.6; }
.password-recovery-form { display: grid; gap: 12px; }
.password-recovery-form label { font-size: 13px; font-weight: 700; }
.password-recovery-form input {
  width: 100%;
  min-height: 48px;
  padding: 12px;
  border: 1px solid var(--border-dark);
  border-radius: var(--radius-sm);
  background: var(--surface);
  color: var(--text);
  font: inherit;
}
.password-recovery-error { margin: 0; color: var(--red); font-size: 13px; }
.password-recovery-form .btn-primary,
.password-recovery-result .btn-primary { width: 100%; }
.password-recovery-result h2 { margin: 0 0 8px; font-size: 20px; }
@media (max-width: 600px) {
  .password-recovery-page { min-height: 100dvh; padding: 16px; }
}
</style>
