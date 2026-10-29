<template>
  <main class="password-recovery-page">
    <section class="password-recovery-card" aria-labelledby="password-recovery-title">
      <button class="back-link public-back-button" type="button" @click="$emit('back')">
        <UiIcon name="arrow-left" :size="16" /> Back to sign in
      </button>
      <span class="eyebrow">ACCOUNT RECOVERY</span>
      <h1 id="password-recovery-title">Reset your password</h1>
      <p class="password-recovery-intro">
        Choose how you’d like to verify your account and reset your password.
      </p>

      <div v-if="!sent && !phoneReset" class="recovery-method-tabs" role="group" aria-label="Recovery method">
        <button type="button" :class="{ active: method === 'email' }" @click="method = 'email'">Email</button>
        <button type="button" :class="{ active: method === 'phone' }" @click="method = 'phone'">Phone</button>
      </div>

      <form v-if="!sent && method === 'email'" class="password-recovery-form" @submit.prevent="requestRecovery">
        <p class="recovery-method-description">Enter the Gmail address you added and verified in Settings. We’ll send a secure recovery link there.</p>
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

      <form
        v-else-if="!phoneChallengeId && !phoneReset && method === 'phone'"
        class="password-recovery-form"
        @submit.prevent="requestPhoneRecovery"
      >
        <p class="recovery-method-description">We’ll send a verification code to the phone number on your account.</p>
        <label for="recovery-phone">Phone number used during registration</label>
        <input
          id="recovery-phone"
          v-model.trim="phone"
          type="tel"
          inputmode="numeric"
          autocomplete="tel"
          maxlength="11"
          pattern="[0-9]{11}"
          placeholder="09XXXXXXXXX"
          required
        />
        <p v-if="error" class="password-recovery-error" role="alert">{{ error }}</p>
        <button class="btn-primary" type="submit" :disabled="sending">
          {{ sending ? 'Sending…' : 'Send verification code' }}
        </button>
      </form>

      <form
        v-else-if="phoneChallengeId && !phoneReset"
        class="password-recovery-form"
        @submit.prevent="completePhoneRecovery"
      >
        <p class="recovery-method-description">If the number matches an active account, a code will arrive by SMS. Enter it below with your new password.</p>
        <label for="recovery-code">Verification code</label>
        <input
          id="recovery-code"
          v-model.trim="code"
          type="text"
          inputmode="numeric"
          autocomplete="one-time-code"
          maxlength="6"
          pattern="[0-9]{6}"
          placeholder="6-digit code"
          required
        />
        <label for="recovery-new-password">New password</label>
        <input
          id="recovery-new-password"
          v-model="newPassword"
          type="password"
          autocomplete="new-password"
          minlength="8"
          maxlength="128"
          required
        />
        <label for="recovery-confirm-password">Confirm new password</label>
        <input
          id="recovery-confirm-password"
          v-model="confirmPassword"
          type="password"
          autocomplete="new-password"
          minlength="8"
          maxlength="128"
          required
        />
        <p v-if="error" class="password-recovery-error" role="alert">{{ error }}</p>
        <button class="btn-primary" type="submit" :disabled="sending">
          {{ sending ? 'Resetting…' : 'Reset password' }}
        </button>
        <button class="recovery-secondary-action" type="button" :disabled="sending" @click="startPhoneRecoveryOver">
          Use another number or request a new code
        </button>
      </form>

      <div v-else class="password-recovery-result" role="status">
        <template v-if="phoneReset">
          <h2>Password updated</h2>
          <p>Your password has been reset. You can now sign in with your new password.</p>
        </template>
        <template v-else>
          <h2>Check your inbox</h2>
          <p>If that Gmail address is verified for an account, a password recovery link will be sent to it.</p>
        </template>
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

const { sendPasswordReset, requestPhonePasswordRecovery, resetPasswordWithPhoneCode } = useAuth();
const method = ref('email');
const email = ref('');
const phone = ref('');
const phoneChallengeId = ref('');
const code = ref('');
const newPassword = ref('');
const confirmPassword = ref('');
const sending = ref(false);
const sent = ref(false);
const phoneReset = ref(false);
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

async function requestPhoneRecovery() {
  sending.value = true;
  error.value = '';
  try {
    phoneChallengeId.value = await requestPhonePasswordRecovery(phone.value);
  } catch (requestError) {
    error.value = requestError.message || 'The verification code could not be sent. Please try again later.';
  } finally {
    sending.value = false;
  }
}

async function completePhoneRecovery() {
  error.value = '';
  if (newPassword.value.length < 8) {
    error.value = 'Your password must contain at least 8 characters.';
    return;
  }
  if (newPassword.value !== confirmPassword.value) {
    error.value = 'The passwords do not match.';
    return;
  }
  sending.value = true;
  try {
    await resetPasswordWithPhoneCode(phoneChallengeId.value, code.value, newPassword.value);
    phoneReset.value = true;
  } catch (requestError) {
    error.value = requestError.message || 'The password could not be reset. Please try again.';
  } finally {
    sending.value = false;
  }
}

function startPhoneRecoveryOver() {
  phoneChallengeId.value = '';
  code.value = '';
  newPassword.value = '';
  confirmPassword.value = '';
  error.value = '';
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
.recovery-method-tabs { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; margin-bottom: 16px; }
.recovery-method-tabs button {
  min-height: 42px;
  border: 1px solid var(--border);
  border-radius: var(--radius-sm);
  background: var(--surface);
  color: var(--text-2);
  font: inherit;
  font-weight: 700;
  cursor: pointer;
}
.recovery-method-tabs button.active { border-color: var(--primary); background: var(--primary); color: #fff; }
.recovery-method-description { margin: 0 0 8px; color: var(--text-2); font-size: 13px; line-height: 1.5; }
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
.recovery-secondary-action { border: 0; background: transparent; color: var(--primary); font: inherit; font-size: 13px; cursor: pointer; }
.password-recovery-form .btn-primary,
.password-recovery-result .btn-primary { width: 100%; }
.password-recovery-result h2 { margin: 0 0 8px; font-size: 20px; }
@media (max-width: 600px) {
  .password-recovery-page { min-height: 100dvh; padding: 16px; }
}
</style>
