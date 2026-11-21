<template>
  <main id="login-page" class="page active">
    <section class="login-brand-panel" aria-label="UNIFIX campus maintenance">
      <div class="login-brand-grid" aria-hidden="true"></div>
      <div class="login-brand-blobs" aria-hidden="true">
        <span></span>
        <span></span>
        <span></span>
      </div>

      <svg class="login-vines" viewBox="0 0 760 900" fill="none" aria-hidden="true">
        <path d="M-30 690C76 642 114 548 90 448c-22-91 25-154 108-188 67-27 112-78 122-154" />
        <path d="M740 790c-96-48-132-126-108-220 22-86-17-150-100-190-82-39-116-111-102-216" />
        <g>
          <path d="M92 448c-30-5-48-24-55-57 33 2 55 20 55 57Zm36-105c-27-13-39-36-35-68 31 9 46 32 35 68Zm5 72c27-15 57-10 82 13-21 23-50 19-82-13Z" />
          <path d="M632 570c27-15 57-10 82 13-21 23-50 19-82-13Zm-48-90c-30-5-48-24-55-57 33 2 55 20 55 57Zm30-98c28 13 41 38 35 69-30-10-44-34-35-69Z" />
        </g>
        <g class="login-blueprint-icons">
          <circle cx="92" cy="194" r="28" />
          <path d="M82 194h20m-10-10v20" />
          <circle cx="682" cy="254" r="28" />
          <path d="m672 254 6 6 13-16" />
          <circle cx="120" cy="742" r="26" />
          <path d="m110 732 20 20m0-20-20 20" />
        </g>
      </svg>

      <div class="login-brand-content">
        <div class="login-brand-header">
          <BrandMark :size="54" />
          <span>UNIFIX</span>
        </div>

        <div class="login-brand-copy">
          <span class="login-eyebrow"><i></i> NVSU CAMPUS CARE</span>
          <h1>Fix it. Track it.<br /><em>Keep NVSU thriving.</em></h1>
          <p>One clear place to report campus concerns and keep every repair moving forward.</p>
        </div>

        <div class="login-status-stack" aria-label="Campus maintenance status examples">
          <article class="login-status-card login-status-card-primary">
            <div class="login-status-icon"><UiIcon name="plumbing" :size="19" /></div>
            <div>
              <span>Building A · Plumbing</span>
              <strong>Leaking faucet</strong>
            </div>
            <span class="login-status-badge progress">In progress</span>
          </article>
          <article class="login-status-card">
            <div class="login-status-icon gold"><UiIcon name="electrical" :size="19" /></div>
            <div>
              <span>Library · Electrical</span>
              <strong>Broken light</strong>
            </div>
            <span class="login-status-badge resolved">Resolved</span>
          </article>
        </div>

        <div class="login-campus-tip" aria-live="polite">
          <span class="login-tip-icon"><UiIcon name="lightbulb" :size="18" /></span>
          <div>
            <small>Campus Care Tip</small>
            <p>{{ campusTips[campusTipIndex] }}</p>
          </div>
        </div>

        <div class="login-resolved-count">
          <strong>{{ resolvedCount.toLocaleString() }}</strong>
          <span>issues resolved this semester</span>
        </div>
      </div>
    </section>

    <section class="login-form-panel" aria-label="UNIFIX sign in">
      <div class="login-form-sun-glow" aria-hidden="true"></div>
      <svg class="login-form-landscape" viewBox="0 0 520 180" aria-hidden="true">
        <path d="M-20 172C58 132 102 148 158 126c72-28 112-9 166-31 74-31 128-5 216-46" />
        <path d="M-10 180c92-30 138-18 198-48 74-37 118-18 171-42 72-32 118-17 181-43" />
      </svg>
      <div class="login-form-leaves" aria-hidden="true">
        <span></span><span></span><span></span><span></span>
      </div>
      <div class="login-form-topbar">
        <button
          v-if="showBack"
          class="login-back"
          type="button"
          @click="$emit('back')"
          aria-label="Back to home"
        >
          <UiIcon name="arrow-left" :size="18" />
          <span>Back to home</span>
        </button>
      </div>

      <form
        class="login-form"
        :class="{ 'login-form-shake': formShake }"
        novalidate
        @submit.prevent="handleLogin"
      >
        <div class="login-form-heading login-enter" style="--enter-delay: 0ms">
          <span class="login-eyebrow-chip"><i></i>NVSU CAMPUS SERVICES</span>
          <h2>{{ greeting }}<span class="login-greeting-swash" aria-hidden="true"></span></h2>
          <p>Sign in with your NVSU institutional account.</p>
        </div>

        <p v-if="authNotice" class="login-auth-notice login-enter" role="alert" style="--enter-delay: 60ms">
          {{ authNotice }}
        </p>

        <div class="login-field login-enter" style="--enter-delay: 120ms">
          <div class="login-input-wrap" :class="{ 'has-error': emailError }">
            <svg class="login-leading-icon" viewBox="0 0 24 24" aria-hidden="true">
              <rect x="3" y="5" width="18" height="14" rx="3" />
              <path d="m4 7 8 6 8-6" />
            </svg>
            <input
              id="login-email"
              v-model="email"
              type="email"
              placeholder=" "
              autocomplete="username"
              :aria-invalid="Boolean(emailError)"
              aria-describedby="login-email-error"
              @blur="validateEmail"
              @input="emailError = ''"
              @keyup.enter="handleLogin"
            />
            <label for="login-email">University Email</label>
          </div>
          <p v-if="emailError" id="login-email-error" class="login-field-error" aria-live="polite">{{ emailError }}</p>
        </div>

        <div class="login-field login-enter" style="--enter-delay: 180ms">
          <div class="login-input-wrap" :class="{ 'has-error': passwordError }">
            <svg class="login-leading-icon" viewBox="0 0 24 24" aria-hidden="true">
              <rect x="4" y="10" width="16" height="11" rx="3" />
              <path d="M8 10V7a4 4 0 0 1 8 0v3" />
            </svg>
            <input
              id="login-password"
              v-model="password"
              :type="passwordVisible ? 'text' : 'password'"
              placeholder=" "
              autocomplete="current-password"
              :aria-invalid="Boolean(passwordError)"
              aria-describedby="login-password-error"
              @blur="validatePassword"
              @input="passwordError = ''"
              @keyup.enter="handleLogin"
            />
            <label for="login-password">Password</label>
            <button
              class="login-password-toggle"
              type="button"
              :aria-label="passwordVisible ? 'Hide password' : 'Show password'"
              :aria-pressed="passwordVisible"
              @click="passwordVisible = !passwordVisible"
            >
              <svg v-if="!passwordVisible" viewBox="0 0 24 24" aria-hidden="true">
                <path d="M2 12s3.5-6 10-6 10 6 10 6-3.5 6-10 6S2 12 2 12Z" />
                <circle cx="12" cy="12" r="2.5" />
              </svg>
              <svg v-else viewBox="0 0 24 24" aria-hidden="true">
                <path d="M3 3l18 18M10.7 6.1A9.7 9.7 0 0 1 12 6c6.5 0 10 6 10 6a16 16 0 0 1-2.2 2.8M6.3 6.3C3.6 8 2 12 2 12s3.5 6 10 6c1.1 0 2.1-.2 3-.5M9.8 9.8a3 3 0 0 0 4.4 4.4" />
              </svg>
            </button>
          </div>
          <p v-if="passwordError" id="login-password-error" class="login-field-error" aria-live="polite">{{ passwordError }}</p>
        </div>

        <div class="login-password-help login-enter" style="--enter-delay: 240ms">
          <small v-if="authNoticeCode === 'wrong-credentials'">
            For invited accounts, use the password from your invitation email.
          </small>
          <button type="button" @click="$emit('forgot-password')">Forgot password?</button>
        </div>

        <button
          class="login-submit login-enter"
          :class="{ 'is-loading': signingIn, 'is-success': signInSuccess }"
          type="submit"
          :disabled="signingIn"
          style="--enter-delay: 300ms"
        >
          <span v-if="signInSuccess" class="login-submit-check" aria-hidden="true">✓</span>
          <span v-else-if="signingIn" class="login-spinner" aria-hidden="true"></span>
          <span>{{ signInSuccess ? 'Signed in' : signingIn ? 'Signing in…' : 'Sign in to UNIFIX' }}</span>
          <svg v-if="!signingIn && !signInSuccess" class="login-submit-arrow" viewBox="0 0 24 24" aria-hidden="true">
            <path d="M5 12h14m-5-5 5 5-5 5" />
          </svg>
        </button>

        <div v-if="authNoticeCode === 'rejected'" class="login-state-action" aria-live="polite">
          <button type="button" class="login-secondary-button" :disabled="reapplying" @click="requestReapplication">
            {{ reapplying ? 'Submitting…' : 'Request a new application review' }}
          </button>
          <small>Reapplication requests are limited to once every 30 days.</small>
        </div>

        <div class="login-create-account login-enter" style="--enter-delay: 360ms">
          <span>New to UNIFIX?</span>
          <button type="button" @click="$emit('register')">Create account</button>
        </div>

        <footer class="login-support login-enter" style="--enter-delay: 420ms">
          <span>Need help?</span>
          <a href="mailto:ict@nvsu.edu.ph">ict@nvsu.edu.ph</a>
        </footer>
      </form>
    </section>
  </main>
</template>

<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import BrandMark from '../components/BrandMark.vue';
import UiIcon from '../components/UiIcon.vue';
import { useAuth } from '../composables/useAuth.js';
import { useToast } from '../composables/useToast.js';
import { useNotifications } from '../composables/useNotifications.js';

defineProps({ showBack: Boolean });
const emit = defineEmits(['logged-in', 'back', 'register', 'forgot-password']);

const {
  login, loadSettings,
  requestRegistrationReapplication, activeUserName, authNotice, authNoticeCode
} = useAuth();
const { showToast } = useToast();
const { refreshNotifications } = useNotifications();

const email = ref('');
const password = ref('');
const passwordVisible = ref(false);
const signingIn = ref(false);
const signInSuccess = ref(false);
const reapplying = ref(false);
const emailError = ref('');
const passwordError = ref('');
const formShake = ref(false);
const campusTipIndex = ref(0);
const resolvedCount = ref(1248);
const greeting = computed(() => {
  const hour = new Date().getHours();
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
});
let campusTipTimer = null;
let resolvedCountTimer = null;

const campusTips = [
  'Add a clear photo and exact location for faster repairs.',
  'Use the tracking code to follow a report after submission.',
  'Only report genuine campus issues to keep maintenance efficient.'
];

function validateEmail() {
  const value = email.value.trim();
  if (!value) {
    emailError.value = 'Please enter your university email.';
  } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) {
    emailError.value = 'Enter a valid email address, such as name@nvsu.edu.ph.';
  } else {
    emailError.value = '';
  }
  return !emailError.value;
}

function validatePassword() {
  if (!password.value) {
    passwordError.value = 'Please enter your password.';
  } else {
    passwordError.value = '';
  }
  return !passwordError.value;
}

function triggerFormShake() {
  formShake.value = false;
  requestAnimationFrame(() => {
    formShake.value = true;
    window.setTimeout(() => {
      formShake.value = false;
    }, 420);
  });
}

async function handleLogin() {
  const emailValid = validateEmail();
  const passwordValid = validatePassword();
  if (!emailValid || !passwordValid) {
    triggerFormShake();
    return;
  }

  signingIn.value = true;
  signInSuccess.value = false;
  try {
    const role = await login(email.value, password.value);
    const settings = loadSettings();
    const landing = role === 'Assistant'
      ? 'admin'
      : role === 'Personnel'
        ? 'tasks'
        : (settings.landing || 'dashboard');

    refreshNotifications(role, activeUserName.value);
    signingIn.value = false;
    signInSuccess.value = true;
    showToast(`Signed in as ${activeUserName.value}`, 'success');
    window.setTimeout(() => emit('logged-in', landing), 520);
  } catch (error) {
    signingIn.value = false;
    triggerFormShake();
    if (!authNotice.value) showToast(error.message || 'Unable to sign in. Please try again.', 'error');
  }
}

async function requestReapplication() {
  if (!password.value) {
    passwordError.value = 'Enter your password to verify your account.';
    triggerFormShake();
    return;
  }
  reapplying.value = true;
  try {
    await requestRegistrationReapplication(email.value, password.value);
    password.value = '';
  } catch (error) {
    showToast(error.message || 'Unable to request another application review.', 'error');
  } finally {
    reapplying.value = false;
  }
}

onMounted(() => {
  campusTipTimer = window.setInterval(() => {
    campusTipIndex.value = (campusTipIndex.value + 1) % campusTips.length;
  }, 6000);
  resolvedCountTimer = window.setInterval(() => {
    resolvedCount.value += 1;
  }, 12000);
});

onBeforeUnmount(() => {
  window.clearInterval(campusTipTimer);
  window.clearInterval(resolvedCountTimer);
});
</script>

<style scoped>
#login-page,
.login-brand-panel,
.login-form-panel,
.login-form {
  box-sizing: border-box;
}

#login-page {
  width: 100%;
  min-height: 100vh;
  min-height: 100dvh;
  display: grid;
  grid-template-columns: 55% 45%;
  background: #f7faf8;
  font-family: "Plus Jakarta Sans", "Outfit", "Sora", sans-serif;
  overflow: hidden;
}

.login-brand-panel {
  position: relative;
  min-height: 100vh;
  min-height: 100dvh;
  overflow: hidden;
  color: #fff;
  background:
    radial-gradient(circle at 18% 16%, rgba(89, 190, 132, 0.28), transparent 24%),
    radial-gradient(circle at 86% 78%, rgba(242, 184, 75, 0.13), transparent 22%),
    linear-gradient(145deg, #0b3d2e 0%, #145a3a 54%, #1e8a52 100%);
}

.login-brand-grid {
  position: absolute;
  inset: 0;
  opacity: 0.15;
  background-image:
    linear-gradient(rgba(255,255,255,.22) 1px, transparent 1px),
    linear-gradient(90deg, rgba(255,255,255,.22) 1px, transparent 1px);
  background-size: 44px 44px;
  mask-image: linear-gradient(135deg, #000 5%, transparent 78%);
}

.login-brand-blobs span {
  position: absolute;
  border-radius: 999px;
  filter: blur(2px);
  background: rgba(155, 218, 178, 0.11);
  animation: login-blobs 10s ease-in-out infinite alternate;
}
.login-brand-blobs span:nth-child(1) { width: 280px; height: 280px; top: -110px; right: 5%; }
.login-brand-blobs span:nth-child(2) { width: 210px; height: 210px; bottom: 4%; left: -90px; animation-delay: -3s; }
.login-brand-blobs span:nth-child(3) { width: 110px; height: 110px; top: 42%; right: 8%; animation-delay: -6s; }

.login-vines {
  position: absolute;
  z-index: 1;
  inset: 0;
  width: 100%;
  height: 100%;
  opacity: 0.13;
  stroke: #d8eddf;
  stroke-width: 2;
  stroke-linecap: round;
  stroke-linejoin: round;
  pointer-events: none;
}
.login-vines g:first-of-type path { fill: #d8eddf; stroke: none; }
.login-vines .login-blueprint-icons { fill: none; stroke-width: 1.5; }

.login-brand-content {
  position: relative;
  z-index: 2;
  width: min(680px, 82%);
  height: 100%;
  min-height: 100vh;
  min-height: 100dvh;
  margin: 0 auto;
  display: flex;
  flex-direction: column;
  justify-content: center;
  padding: 48px 0;
}

.login-brand-header {
  position: absolute;
  top: 38px;
  left: 0;
  display: flex;
  align-items: center;
  gap: 12px;
  font-size: 19px;
  font-weight: 800;
  letter-spacing: 0.06em;
}

.login-brand-copy {
  max-width: 650px;
  margin-top: -30px;
}
.login-eyebrow {
  display: inline-flex;
  align-items: center;
  gap: 9px;
  margin-bottom: 16px;
  color: #dbeade;
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.16em;
}
.login-eyebrow i {
  width: 32px;
  height: 1px;
  background: #f2b84b;
}
.login-brand-copy h1 {
  margin: 0;
  max-width: 620px;
  font-size: clamp(46px, 5.2vw, 74px);
  line-height: 0.98;
  letter-spacing: -0.055em;
}
.login-brand-copy h1 em {
  color: #f2d58c;
  font-style: normal;
  font-weight: 600;
}
.login-brand-copy > p {
  max-width: 520px;
  margin: 20px 0 0;
  color: #d6e7db;
  font-size: clamp(14px, 1.25vw, 17px);
  line-height: 1.65;
}

.login-status-stack {
  width: min(520px, 78%);
  margin-top: 32px;
  display: grid;
  gap: 10px;
}
.login-status-card {
  display: grid;
  grid-template-columns: 42px minmax(0, 1fr) auto;
  align-items: center;
  gap: 12px;
  min-height: 68px;
  padding: 10px 12px;
  border: 1px solid rgba(255,255,255,.16);
  border-radius: 18px;
  background: rgba(255,255,255,.11);
  box-shadow: 0 14px 34px rgba(4, 38, 24, 0.12);
  backdrop-filter: blur(14px);
}
.login-status-card-primary { transform: translateX(22px); }
.login-status-icon {
  display: grid;
  width: 42px;
  height: 42px;
  place-items: center;
  border-radius: 12px;
  background: rgba(255,255,255,.14);
  color: #fff;
}
.login-status-icon.gold { color: #f2b84b; }
.login-status-card div:nth-child(2) { display: grid; gap: 3px; min-width: 0; }
.login-status-card div:nth-child(2) span { color: #cfe0d4; font-size: 10px; }
.login-status-card div:nth-child(2) strong { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; font-size: 13px; }
.login-status-badge {
  padding: 6px 9px;
  border-radius: 999px;
  font-size: 9px;
  font-weight: 800;
  white-space: nowrap;
}
.login-status-badge.progress { background: #f2b84b; color: #3c300f; }
.login-status-badge.resolved { background: #bfe8cc; color: #174d31; }

.login-campus-tip {
  width: min(520px, 78%);
  margin-top: 14px;
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 12px;
  border-top: 1px solid rgba(255,255,255,.12);
  border-bottom: 1px solid rgba(255,255,255,.12);
}
.login-tip-icon {
  display: grid;
  width: 34px;
  height: 34px;
  flex: 0 0 34px;
  place-items: center;
  border-radius: 50%;
  background: rgba(242,184,75,.16);
  color: #f2b84b;
}
.login-campus-tip div { min-width: 0; }
.login-campus-tip small { color: #f2d58c; font-size: 9px; font-weight: 800; text-transform: uppercase; letter-spacing: .12em; }
.login-campus-tip p { min-height: 32px; margin: 2px 0 0; color: #dcebe0; font-size: 11px; line-height: 1.45; }

.login-resolved-count {
  position: absolute;
  right: 0;
  bottom: 42px;
  display: grid;
  text-align: right;
}
.login-resolved-count strong { color: #f2d58c; font-size: 20px; }
.login-resolved-count span { color: #d2e1d6; font-size: 9px; }

.login-form-panel {
  position: relative;
  min-height: 100vh;
  min-height: 100dvh;
  display: grid;
  place-items: center;
  padding: 42px clamp(28px, 4vw, 68px);
  overflow: hidden;
  border-top-left-radius: 48px;
  border-bottom-left-radius: 48px;
  background: linear-gradient(180deg, #fbf7ec 0%, #f4eedc 100%);
  box-shadow: -18px 0 38px rgba(12, 67, 43, 0.10), -1px 0 0 #e2b64d;
  isolation: isolate;
}
.login-form-panel::after {
  content: "";
  position: absolute;
  inset: 0;
  z-index: 1;
  opacity: 0.038;
  pointer-events: none;
  background-image: url("data:image/svg+xml,%3Csvg viewBox='0 0 180 180' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='.8' numOctaves='2' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)' opacity='.28'/%3E%3C/svg%3E");
}
.login-form-sun-glow {
  position: absolute;
  z-index: 0;
  top: -110px;
  right: -130px;
  width: 340px;
  height: 340px;
  border-radius: 50%;
  background: radial-gradient(circle, rgba(226,182,77,.20), rgba(226,182,77,.07) 38%, transparent 68%);
  pointer-events: none;
}
.login-form-landscape {
  position: absolute;
  z-index: 0;
  right: -2%;
  bottom: -8px;
  width: 92%;
  height: auto;
  fill: none;
  stroke: #9db8a0;
  stroke-width: 1.2;
  opacity: 0.25;
  pointer-events: none;
  mask-image: linear-gradient(to top, #000 62%, transparent 100%);
}
.login-form-leaves span {
  position: absolute;
  z-index: 0;
  width: 18px;
  height: 10px;
  border: 1px solid rgba(72,124,86,.25);
  border-radius: 100% 0 100% 0;
  opacity: .55;
  pointer-events: none;
  animation: login-leaf-drift 16s ease-in-out infinite alternate;
}
.login-form-leaves span:nth-child(1) { top: 18%; left: 7%; transform: rotate(-28deg); }
.login-form-leaves span:nth-child(2) { top: 34%; right: 7%; transform: rotate(36deg); animation-delay: -5s; }
.login-form-leaves span:nth-child(3) { bottom: 19%; left: 9%; transform: rotate(52deg); animation-delay: -9s; }
.login-form-leaves span:nth-child(4) { bottom: 31%; right: 9%; transform: rotate(-48deg); animation-delay: -12s; }
@keyframes login-leaf-drift {
  to { translate: 5px -8px; rotate: 8deg; }
}

.login-form-topbar {
  position: absolute;
  z-index: 3;
  top: 28px;
  left: clamp(28px, 4vw, 68px);
  right: clamp(28px, 4vw, 68px);
  display: flex;
  justify-content: flex-start;
}
.login-back {
  min-height: 42px;
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 0;
  border: 0;
  border-radius: 0;
  background: transparent;
  color: #53685b;
  font: inherit;
  font-size: 12px;
  font-weight: 700;
  cursor: pointer;
  transition: 200ms ease-out;
}
.login-back:hover { border: 0; color: #14783f; transform: translateX(-2px); }
.login-mobile-brand { display: none; }

.login-form {
  position: relative;
  z-index: 2;
  width: min(430px, 100%);
  margin-top: 18px;
}
.login-form-heading { margin-bottom: 28px; }
.login-eyebrow-chip {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 14px;
  padding: 7px 10px;
  border: 1px solid #dbe8d9;
  border-radius: 999px;
  background: #edf4e9;
  color: #28543a;
  font-size: 9px;
  font-weight: 900;
  letter-spacing: .12em;
}
.login-eyebrow-chip i {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: #e2b64d;
  box-shadow: 0 0 0 3px rgba(226,182,77,.14);
}
.login-heading-mark {
  display: grid;
  width: 42px;
  height: 42px;
  margin-bottom: 18px;
  place-items: center;
  border: 1px solid #d7e8dc;
  border-radius: 13px;
  background: #edf6ef;
  color: #14783f;
}
.login-form-heading h2 {
  margin: 0 0 8px;
  color: #0f3b2a;
  font-family: "Fraunces", "Playfair Display", Georgia, serif;
  font-size: clamp(36px, 3.4vw, 40px);
  font-weight: 600;
  line-height: 1.08;
  letter-spacing: -0.045em;
}
.login-greeting-swash {
  display: block;
  width: 72px;
  height: 8px;
  margin-top: 2px;
  border-bottom: 3px solid #e2b64d;
  border-radius: 50%;
  transform: rotate(-2deg);
}
.login-form-heading p {
  margin: 0;
  color: #6b7c72;
  font-size: 14px;
  line-height: 1.55;
}

.login-auth-notice {
  margin: -8px 0 18px;
  padding: 11px 13px;
  border: 1px solid #edcf9a;
  border-radius: 12px;
  background: #fff7e7;
  color: #79551a;
  font-size: 12px;
  line-height: 1.45;
}

.login-field { margin-bottom: 17px; }
.login-input-wrap {
  position: relative;
  height: 54px;
  border: 1px solid rgba(110,137,119,.24);
  border-radius: 16px;
  background: rgba(255,255,255,.80);
  box-shadow: 0 8px 20px rgba(55,83,64,.055), inset 0 1px 0 rgba(255,255,255,.86);
  transition: 200ms ease-out;
}
.login-input-wrap:hover { border-color: #bdcfc3; }
.login-input-wrap:focus-within {
  border-color: #14783f;
  box-shadow: 0 0 0 4px rgba(20,120,63,.10), 0 8px 18px rgba(20,80,48,.06);
  transform: translateY(-1px);
}
.login-input-wrap.has-error { border-color: #c65d55; box-shadow: 0 0 0 3px rgba(198,93,85,.08); }
.login-leading-icon {
  position: absolute;
  z-index: 2;
  top: 15px;
  left: 16px;
  width: 20px;
  height: 20px;
  fill: none;
  stroke: #7e9185;
  stroke-width: 1.7;
  stroke-linecap: round;
  stroke-linejoin: round;
  pointer-events: none;
}
.login-input-wrap input {
  width: 100%;
  height: 100%;
  box-sizing: border-box;
  padding: 16px 48px 5px 48px;
  border: 0;
  border-radius: 14px;
  outline: 0;
  background: transparent;
  color: #14231b;
  font: inherit;
  font-size: 14px;
  font-weight: 600;
}
.login-input-wrap label {
  position: absolute;
  z-index: 1;
  top: 15px;
  left: 48px;
  color: #7a8980;
  font-size: 13px;
  line-height: 20px;
  pointer-events: none;
  transition: 180ms ease-out;
}
.login-input-wrap input:focus + label,
.login-input-wrap input:not(:placeholder-shown) + label {
  top: 7px;
  font-size: 10px;
  font-weight: 800;
  color: #14783f;
}
.login-password-toggle {
  position: absolute;
  z-index: 3;
  top: 8px;
  right: 8px;
  display: grid;
  width: 36px;
  height: 36px;
  padding: 8px;
  place-items: center;
  border: 0;
  border-radius: 9px;
  background: transparent;
  color: #718177;
  cursor: pointer;
}
.login-password-toggle:hover { background: #edf5ef; color: #14783f; }
.login-password-toggle:focus-visible { outline: 3px solid rgba(20,120,63,.22); outline-offset: 1px; }
.login-password-toggle svg { width: 19px; height: 19px; fill: none; stroke: currentColor; stroke-width: 1.8; stroke-linecap: round; stroke-linejoin: round; }
.login-field-error {
  margin: 6px 4px 0;
  color: #b34e47;
  font-size: 11px;
  line-height: 1.35;
}

.login-password-help {
  min-height: 38px;
  display: flex;
  align-items: flex-start;
  justify-content: flex-end;
  margin: -4px 0 12px;
}
.login-password-help small { max-width: 260px; margin-right: auto; color: #b34e47; font-size: 10px; line-height: 1.4; }
.login-password-help button {
  margin: 0;
  padding: 3px 0;
  border: 0;
  background: transparent;
  color: #14783f;
  font: inherit;
  font-size: 12px;
  font-weight: 800;
  cursor: pointer;
}
.login-password-help button:hover { text-decoration: underline; text-underline-offset: 3px; }

.login-submit {
  width: 100%;
  height: 54px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 9px;
  border: 0;
  border-radius: 16px;
  background: linear-gradient(135deg, #14783f 0%, #0f6637 100%);
  color: #fff;
  box-shadow: 0 10px 24px rgba(20,120,63,.22), 0 3px 8px rgba(20,80,48,.10);
  font: inherit;
  font-size: 14px;
  font-weight: 800;
  cursor: pointer;
  transition: 200ms ease-out;
}
.login-submit:hover:not(:disabled) { transform: translateY(-2px); box-shadow: 0 14px 30px rgba(20,120,63,.28), 0 4px 10px rgba(20,80,48,.12); }
.login-submit:active:not(:disabled) { transform: scale(.98); }
.login-submit:focus-visible { outline: 3px solid rgba(20,120,63,.24); outline-offset: 3px; }
.login-submit:disabled { cursor: wait; }
.login-submit.is-success { background: #14783f; }
.login-submit-arrow { width: 18px; height: 18px; fill: none; stroke: currentColor; stroke-width: 2; stroke-linecap: round; stroke-linejoin: round; transition: transform 200ms ease-out; }
.login-submit:hover .login-submit-arrow { transform: translateX(4px); }
.login-spinner { width: 18px; height: 18px; border: 2px solid rgba(255,255,255,.38); border-top-color: #fff; border-radius: 50%; animation: login-spin .75s linear infinite; }
.login-submit-check { display: grid; width: 21px; height: 21px; place-items: center; border-radius: 50%; background: #fff; color: #14783f; font-size: 13px; }

.login-create-account {
  display: grid;
  grid-template-columns: auto auto;
  justify-content: center;
  align-items: center;
  gap: 7px;
  margin-top: 16px;
  color: #6b7c72;
  font-size: 12px;
}
.login-create-account button {
  min-height: 36px;
  padding: 0 12px;
  border: 1.5px solid #bcd1c2;
  border-radius: 10px;
  background: #fff;
  color: #14783f;
  font: inherit;
  font-size: 12px;
  font-weight: 800;
  cursor: pointer;
  transition: 200ms ease-out;
}
.login-create-account button:hover { border-color: #14783f; background: #edf6ef; }
.login-support {
  display: flex;
  justify-content: center;
  gap: 5px;
  margin: 14px 0 0;
  color: #849188;
  font-size: 10px;
}
.login-support a { color: #14783f; font-weight: 800; text-decoration: none; }
.login-support a:hover { text-decoration: underline; }

.login-state-action {
  display: grid;
  gap: 7px;
  margin-top: 12px;
  text-align: center;
  color: #849188;
  font-size: 10px;
}
.login-secondary-button {
  min-height: 42px;
  border: 1.5px solid #cbdacf;
  border-radius: 12px;
  background: #fff;
  color: #14783f;
  font: inherit;
  font-weight: 800;
  cursor: pointer;
}

.login-enter {
  opacity: 0;
  animation: login-fade-up 480ms cubic-bezier(.2,.7,.2,1) forwards;
  animation-delay: var(--enter-delay, 0ms);
}
.login-form-shake { animation: login-shake 380ms ease-out; }

@keyframes login-fade-up {
  from { opacity: 0; transform: translateY(10px); }
  to { opacity: 1; transform: translateY(0); }
}
@keyframes login-shake {
  0%,100% { transform: translateX(0); }
  25% { transform: translateX(-7px); }
  50% { transform: translateX(6px); }
  75% { transform: translateX(-3px); }
}
@keyframes login-spin { to { transform: rotate(360deg); } }
@keyframes login-blobs {
  from { transform: translate3d(0,0,0) scale(1); }
  to { transform: translate3d(18px,-12px,0) scale(1.08); }
}

@media (max-width: 1100px) {
  #login-page { grid-template-columns: 52% 48%; }
  .login-brand-content { width: 84%; }
  .login-status-stack,
  .login-campus-tip { width: 90%; }
  .login-brand-copy h1 { font-size: clamp(42px, 5.2vw, 60px); }
}

@media (max-width: 767px) {
  #login-page { display: block; overflow: auto; background: #f7faf8; }
  .login-brand-panel {
    min-height: 168px;
    height: 168px;
  }
  .login-brand-content {
    width: 100%;
    min-height: 168px;
    height: 168px;
    margin: 0;
    justify-content: flex-end;
    padding: 20px 22px;
  }
  .login-brand-header { top: 18px; left: 22px; }
  .login-brand-header :deep(.brand-mark) { width: 42px !important; height: 42px !important; }
  .login-brand-header span { font-size: 16px; }
  .login-brand-copy { margin: 0; }
  .login-eyebrow,
  .login-brand-copy > p,
  .login-status-stack,
  .login-campus-tip,
  .login-resolved-count,
  .login-vines,
  .login-brand-grid { display: none; }
  .login-brand-copy h1 {
    max-width: 290px;
    font-size: 26px;
    line-height: 1.05;
  }
  .login-brand-copy h1 br { display: none; }
  .login-brand-copy h1 em { display: block; font-size: 16px; margin-top: 5px; }

  .login-form-panel {
    min-height: calc(100dvh - 168px);
    display: block;
    padding: 24px 20px 28px;
    border-top-left-radius: 36px;
    border-top-right-radius: 36px;
    border-bottom-left-radius: 0;
    box-shadow: 0 -14px 32px rgba(12,67,43,.10), -1px 0 0 #e2b64d;
  }
  .login-form-panel::after { display: none; }
  .login-form-topbar { top: 10px; left: 20px; right: 20px; justify-content: flex-end; }
  .login-back { min-height: 38px; }
  .login-mobile-brand { display: none; }
  .login-form { width: min(430px, 100%); margin: 50px auto 0; }
  .login-form-heading { margin-bottom: 22px; }
  .login-heading-mark { display: none; }
  .login-form-heading h2 { font-size: 32px; }
  .login-field { margin-bottom: 14px; }
  .login-password-help { margin-bottom: 10px; }
  .login-support { margin-bottom: 0; }
}

@media (max-width: 420px) {
  .login-brand-panel { height: 150px; min-height: 150px; }
  .login-brand-content { height: 150px; min-height: 150px; padding: 16px 18px; }
  .login-brand-header { top: 14px; left: 18px; }
  .login-brand-copy h1 { font-size: 23px; }
  .login-brand-copy h1 em { font-size: 14px; }
  .login-form-panel { min-height: calc(100dvh - 150px); padding-inline: 16px; }
  .login-form-topbar { left: 16px; right: 16px; }
  .login-back span { display: none; }
  .login-back { width: 38px; justify-content: center; padding: 0; }
  .login-form { margin-top: 42px; }
  .login-form-heading h2 { font-size: 29px; }
  .login-create-account { flex-wrap: wrap; }
}

@media (prefers-reduced-motion: reduce) {
  .login-enter,
  .login-brand-blobs span,
  .login-spinner,
  .login-form-shake {
    animation: none !important;
  }
  .login-submit,
  .login-input-wrap,
  .login-back,
  .login-create-account button {
    transition: none;
  }
}
</style>
