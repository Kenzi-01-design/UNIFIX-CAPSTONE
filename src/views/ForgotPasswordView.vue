<template>
  <main class="forgot-password-page">
    <section class="forgot-password-card">
      <div class="forgot-password-brand" aria-label="UNIFIX, NVSU Campus Maintenance">
        <BrandMark :size="36" />
        <span><strong>UNIFIX</strong><small>NVSU Campus Maintenance</small></span>
      </div>
      <h1>Forgot password?</h1>
      <p>Visit the campus office for assistance from an Admin.</p>
      <button class="btn-primary" type="button" @click="$emit('back')">
        Back to sign in
      </button>
    </section>
  </main>
</template>

<script setup>
import BrandMark from '../components/BrandMark.vue';

defineEmits(['back']);
</script>

<style scoped>
.forgot-password-page {
  min-height: 100vh;
  min-height: 100dvh;
  display: grid;
  place-items: center;
  padding: 24px 16px;
  background: var(--bg);
}
.forgot-password-card {
  width: min(100%, 440px);
  padding: 32px;
  border: 1px solid var(--border);
  border-radius: var(--radius-lg);
  background: var(--surface);
  box-shadow: var(--shadow);
}
.forgot-password-brand {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 28px;
  color: var(--text);
}
.forgot-password-brand > span {
  display: grid;
  gap: 2px;
}
.forgot-password-brand strong {
  color: var(--primary);
  font-size: 17px;
}
.forgot-password-brand small {
  color: var(--text-3);
  font-size: 11px;
}
.forgot-password-card h1 {
  margin: 0 0 8px;
  color: var(--text);
  font-size: 26px;
}
.forgot-password-card p {
  margin: 0 0 24px;
  color: var(--text-2);
  line-height: 1.6;
}
.forgot-password-card .btn-primary {
  width: 100%;
  min-height: 46px;
}
@media (max-width: 520px) {
  .forgot-password-card {
    padding: 24px;
  }
}
</style>
