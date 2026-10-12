<template>
  <main class="home-page">
    <div class="ambient ambient-one"></div>
    <div class="ambient ambient-two"></div>
    <header class="home-header">
      <div class="home-logo" aria-label="UNIFIX"><BrandMark :size="38" /><span class="home-wordmark"><b>UNI</b>FIX</span></div>
      <div class="home-actions">
        <nav class="hero-tabs" aria-label="Home actions">
          <button class="hero-tab report-tab" @click="$emit('open-report')">
            <span class="report-label-desktop">Submit a Report</span>
            <UiIcon name="arrow-up-right" :size="16" />
          </button>
          <button class="hero-tab track-tab" @click="$emit('open-track')">Track a Report</button>
          <button class="hero-tab evaluation-tab" @click="$emit('open-evaluation')">Evaluate</button>
        </nav>
        <button class="hero-tab login-tab" @click="$emit('open-login')">Sign Up / Sign In</button>
      </div>
    </header>
    <section class="home-hero">
      <div class="hero-copy-block">
        <p class="eyebrow">NUEVA VIZCAYA STATE UNIVERSITY</p>
        <h1>Better spaces begin<br />with a better <em>response.</em></h1>
        <p class="hero-copy">UNIFIX is NVSU’s campus maintenance platform. Report an issue in seconds, then let the right team receive, manage, and resolve it.</p>
        <button class="hero-cta" @click="$emit('open-report')">Report an issue <UiIcon name="arrow-right" :size="18" /></button>
        <div class="mobile-work-actions" aria-label="Report and track actions">
          <button class="mobile-report-action" @click="$emit('open-report')">Report an issue <UiIcon name="arrow-up-right" :size="16" /></button>
          <button class="mobile-track-action" @click="$emit('open-track')">Track a Report</button>
        </div>
      </div>
      <div class="visual-column">
        <div class="maintenance-visual" aria-hidden="true">
          <UiIcon class="visual-spark spark-one" name="sparkles" :size="18" />
          <UiIcon class="visual-spark spark-two" name="sparkles" :size="16" />
          <div class="building-icon"><UiIcon name="building" :size="39" /></div>
          <div class="tool-chip tool-chip-one"><UiIcon name="work" :size="18" /></div><div class="tool-chip tool-chip-two"><UiIcon name="electrical" :size="18" /></div><div class="tool-chip tool-chip-three"><UiIcon name="plumbing" :size="18" /></div>
        </div>
        <div class="flow-card" aria-label="How UNIFIX works">
        <div class="flow-card-title">How it works</div>
        <div class="flow-step"><b><UiIcon name="request" :size="16" /></b><span><strong>Tell us what happened</strong><small>Share the location and details.</small></span></div>
        <div class="flow-line"></div>
        <div class="flow-step"><b><UiIcon name="success" :size="16" /></b><span><strong>Verify your report</strong><small>A quick check keeps reports reliable.</small></span></div>
        <div class="flow-line"></div>
        <div class="flow-step"><b><UiIcon name="settings" :size="16" /></b><span><strong>We route the work</strong><small>Maintenance teams take it from there.</small></span></div>
        </div>
      </div>
    </section>
  </main>
</template>

<script setup>
import UiIcon from '../components/UiIcon.vue';
import BrandMark from '../components/BrandMark.vue';
defineEmits(['open-report', 'open-login', 'open-track', 'open-evaluation']);
</script>

<style scoped>
.home-page { position: relative; min-height: 100vh; overflow: hidden; padding: 28px clamp(24px, 7vw, 112px) 52px; background: #f7faf7; }
.ambient { position: absolute; border-radius: 999px; pointer-events: none; filter: blur(1px); }.ambient-one { width: 520px; height: 520px; top: -280px; right: -110px; background: #d9f0df; }.ambient-two { width: 360px; height: 360px; bottom: -180px; left: -130px; background: #fff0bd; }
.home-header { position: relative; z-index: 1; display: flex; align-items: center; justify-content: space-between; max-width: 1240px; margin: auto; }
.home-logo { display: flex; align-items: center; gap: 9px; color: var(--primary-dark); font-size: 22px; font-weight: 800; letter-spacing: -.9px; }.home-logo b { color: var(--text); }.home-logo .brand-mark { flex: 0 0 auto; filter: drop-shadow(0 6px 10px rgba(15,107,61,.2)); }
.home-actions { display: flex; align-items: center; gap: 10px; }.hero-tabs { display: flex; gap: 10px; }.hero-tab { min-height: 42px; padding: 0 16px; border: 1px solid transparent; border-radius: 999px; background: transparent; color: var(--text-2); font: inherit; font-size: 13px; font-weight: 700; cursor: pointer; transition: var(--transition); }.hero-tab:hover { transform: translateY(-1px); }.report-tab { display: inline-flex; align-items: center; gap: 5px; background: var(--primary); color: #fff; box-shadow: 0 8px 18px rgba(15,107,61,.2); }.track-tab, .login-tab,.evaluation-tab { border-color: var(--border-dark); background: rgba(255,255,255,.62); }.mobile-work-actions { display: none; }
.home-hero { position: relative; z-index: 1; display: grid; grid-template-columns: minmax(0, 1.1fr) minmax(310px, .72fr); align-items: center; gap: clamp(50px, 9vw, 150px); max-width: 1100px; min-height: calc(100vh - 118px); margin: auto; }.eyebrow { color: var(--primary); font-size: 11px; font-weight: 800; letter-spacing: .15em; }.hero-copy-block h1 { max-width: 660px; margin: 15px 0 19px; color: var(--text); font-size: clamp(42px, 5vw, 69px); line-height: .99; letter-spacing: -3.2px; }.hero-copy-block h1 em { color: var(--primary); font-family: Georgia, serif; font-weight: 500; }.hero-copy { max-width: 560px; color: var(--text-2); font-size: 16px; line-height: 1.75; }.hero-cta { display: inline-flex; align-items: center; gap: 12px; margin-top: 29px; padding: 13px 5px; border: 0; border-bottom: 2px solid var(--primary); background: transparent; color: var(--primary-dark); font: inherit; font-size: 14px; font-weight: 800; cursor: pointer; }.hero-cta svg { transition: transform .2s; }.hero-cta:hover svg { transform: translateX(5px); }
.visual-column { position: relative; padding-top: 140px; }.maintenance-visual { position: absolute; z-index: 2; top: 0; left: 50%; width: 205px; height: 122px; transform: translateX(-50%); border: 1px solid rgba(255,255,255,.9); border-radius: 22px; background: linear-gradient(135deg, #e9f6ee, #fff8dc); box-shadow: 0 18px 35px rgba(26,31,54,.1); }.building-icon { display: grid; place-items: center; width: 76px; height: 76px; margin: 23px auto; border-radius: 19px; background: rgba(255,255,255,.72); font-size: 39px; }.tool-chip { position: absolute; display: grid; place-items: center; width: 38px; height: 38px; border: 1px solid rgba(255,255,255,.9); border-radius: 12px; background: #fff; box-shadow: 0 7px 15px rgba(26,31,54,.1); font-size: 18px; }.tool-chip-one { top: 19px; left: -17px; }.tool-chip-two { right: -18px; bottom: 15px; }.tool-chip-three { right: 23px; top: -15px; }.visual-spark { position: absolute; color: var(--accent); }.spark-one { left: 26px; top: 18px; }.spark-two { bottom: 15px; right: 53px; color: var(--primary-light); }
.flow-card { padding: 28px; border: 1px solid rgba(220,232,223,.9); border-radius: 20px; background: rgba(255,255,255,.78); box-shadow: 0 24px 60px rgba(26,31,54,.09); backdrop-filter: blur(8px); }.flow-card-title { margin-bottom: 24px; color: var(--text); font-size: 15px; font-weight: 800; }.flow-step { display: flex; gap: 15px; align-items: flex-start; }.flow-step b { display: grid; place-items: center; flex: 0 0 33px; width: 33px; height: 33px; border-radius: 50%; background: var(--primary-bg); color: var(--primary); font-size: 14px; }.flow-step strong, .flow-step small { display: block; }.flow-step strong { padding-top: 1px; color: var(--text); font-size: 13px; }.flow-step small { margin-top: 2px; color: var(--text-3); font-size: 11px; line-height: 1.4; }.flow-line { width: 1px; height: 25px; margin: 5px 0 5px 16px; background: var(--border-dark); }
@media (max-width: 600px) { .home-page { padding: 16px 16px calc(28px + env(safe-area-inset-bottom)); }.home-header { display: grid; grid-template-columns: minmax(0, 1fr) auto auto; align-items: center; gap: 12px 8px; }.home-logo { grid-column: 1; grid-row: 1; width: max-content; }.home-actions,.home-actions > .hero-tabs { display: contents; }.home-actions .evaluation-tab { grid-column: 2; grid-row: 1; padding-inline: 9px; font-size: 11px; white-space: nowrap; }.home-actions > .login-tab { grid-column: 3; grid-row: 1; padding-inline: 9px; font-size: 11px; white-space: nowrap; }.hero-tabs > .report-tab,.hero-tabs > .track-tab { display: none; }.hero-tab { min-width: 0; min-height: 44px; padding-inline: 8px; font-size: 11px; line-height: 1.25; }.home-hero { grid-template-columns: 1fr; gap: 28px; padding: 44px 0 24px; }.hero-copy-block h1 { font-size: clamp(36px, 10.5vw, 52px); }.hero-cta { display: none; }.mobile-work-actions { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px; width: min(100%, 380px); margin: 22px auto 0; }.mobile-work-actions button { display: inline-flex; min-width: 0; min-height: 46px; align-items: center; justify-content: center; gap: 5px; padding: 0 10px; border: 1px solid var(--border-dark); border-radius: 999px; background: rgba(255,255,255,.78); color: var(--text-2); font: inherit; font-size: 12px; font-weight: 700; cursor: pointer; }.mobile-work-actions .mobile-report-action { border-color: var(--primary); background: var(--primary); color: #fff; box-shadow: 0 8px 18px rgba(15,107,61,.2); }.mobile-work-actions svg { flex: 0 0 auto; }.visual-column { padding-top: 96px; } }
@media (max-width: 360px) { .home-header { column-gap: 5px; }.home-logo { gap: 5px; font-size: 18px; }.home-logo .brand-mark { width: 32px; height: 32px; }.home-actions .evaluation-tab,.home-actions > .login-tab { padding-inline: 6px; font-size: 9px; } }
@media (min-width: 601px) and (max-width: 760px) { .home-page { padding: 20px 22px 42px; }.home-hero { grid-template-columns: 1fr; gap: 46px; padding: 70px 0 28px; }.hero-copy-block h1 { font-size: clamp(42px, 13vw, 59px); }.flow-card { max-width: 480px; }.hero-tab { padding: 0 12px; font-size: 11px; }.report-tab { font-size: 12px; } }
</style>
