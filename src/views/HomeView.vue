<template>
  <main class="home-page">
    <div class="ambient ambient-one"></div>
    <div class="ambient ambient-two"></div>
    <header class="home-header">
      <div class="home-logo" aria-label="UNIFIX"><span><UiIcon name="work" :size="19" /></span><b>UNI</b>FIX</div>
      <nav class="hero-tabs" aria-label="Home actions">
        <button class="hero-tab report-tab" @click="$emit('open-report')">Submit a Report <span>↗</span></button>
        <button class="hero-tab track-tab" @click="$emit('open-track')">Track a Report</button>
        <button class="hero-tab evaluation-tab" @click="$emit('open-evaluation')">Evaluate</button>
        <button class="hero-tab login-tab" @click="$emit('open-register')">Create account</button>
        <button class="hero-tab login-tab" @click="$emit('open-login')">Login</button>
      </nav>
    </header>
    <section class="home-hero">
      <div class="hero-copy-block">
        <p class="eyebrow">NUEVA VIZCAYA STATE UNIVERSITY</p>
        <h1>Better spaces begin<br />with a better <em>response.</em></h1>
        <p class="hero-copy">UNIFIX is NVSU’s campus maintenance platform. Report an issue in seconds, then let the right team receive, manage, and resolve it.</p>
        <button class="hero-cta" @click="$emit('open-report')">Report an issue <span>→</span></button>
      </div>
      <div class="visual-column">
        <div class="maintenance-visual" aria-hidden="true">
          <div class="visual-spark spark-one">✦</div><div class="visual-spark spark-two">✦</div>
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
defineEmits(['open-report', 'open-login', 'open-track', 'open-evaluation', 'open-register']);
</script>

<style scoped>
.home-page { position: relative; min-height: 100dvh; overflow: hidden; padding: 20px clamp(16px, 5vw, 72px) 40px; background: var(--surface-2); color: var(--text); }
.ambient { position: absolute; border-radius: 999px; pointer-events: none; filter: blur(1px); opacity: .6; }.ambient-one { width: 520px; height: 520px; top: -280px; right: -110px; background: var(--primary-bg); }.ambient-two { width: 360px; height: 360px; bottom: -180px; left: -130px; background: var(--accent-bg); }
.home-header { position: relative; z-index: 1; display: flex; align-items: center; justify-content: space-between; gap: 18px; max-width: 1240px; margin: auto; }
.home-logo { display: flex; flex: 0 0 auto; align-items: center; color: var(--primary-dark); font-size: 22px; font-weight: 800; letter-spacing: -.9px; }.home-logo b { color: var(--text); }.home-logo span { display: inline-grid; place-items: center; width: 40px; height: 40px; margin-right: 9px; border-radius: 12px; background: var(--primary); color: #fff; box-shadow: var(--shadow-sm); font-size: 18px; }
.hero-tabs { display: flex; flex-wrap: wrap; justify-content: flex-end; gap: 8px; }.hero-tab { min-height: 44px; padding: 0 14px; border: 1px solid var(--border); border-radius: 999px; background: var(--surface); color: var(--text-2); font: inherit; font-size: 13px; font-weight: 700; cursor: pointer; transition: var(--transition); }.hero-tab:hover { transform: translateY(-1px); border-color: var(--primary); }.report-tab { border-color: var(--primary); background: var(--primary); color: #fff; box-shadow: var(--shadow-sm); }.report-tab span { margin-left: 5px; font-size: 16px; }
.home-hero { position: relative; z-index: 1; display: grid; grid-template-columns: minmax(0, 1fr); align-items: center; gap: 36px; max-width: 1100px; min-height: calc(100dvh - 100px); margin: auto; padding-block: 40px; }.eyebrow { color: var(--primary); font-size: 11px; font-weight: 800; letter-spacing: .15em; }.hero-copy-block h1 { max-width: 660px; margin: 14px 0 18px; color: var(--text); font-size: clamp(38px, 10vw, 64px); line-height: 1.02; letter-spacing: -.045em; }.hero-copy-block h1 em { color: var(--primary); font-family: Georgia, serif; font-weight: 500; }.hero-copy { max-width: 560px; color: var(--text-2); font-size: clamp(15px, 2vw, 17px); line-height: 1.7; }.hero-cta { display: inline-flex; align-items: center; justify-content: center; min-height: 48px; margin-top: 24px; padding: 0 20px; border: 1px solid var(--primary); border-radius: 12px; background: var(--primary); color: #fff; font: inherit; font-size: 15px; font-weight: 800; cursor: pointer; box-shadow: var(--shadow-sm); transition: var(--transition); }.hero-cta:hover { transform: translateY(-1px); box-shadow: var(--shadow); }.hero-cta span { margin-left: 12px; font-size: 19px; }
.visual-column { position: relative; padding-top: 104px; }.maintenance-visual { position: absolute; z-index: 2; top: 0; left: 50%; width: 180px; height: 108px; transform: translateX(-50%); border: 1px solid var(--border); border-radius: 18px; background: linear-gradient(135deg, var(--primary-bg), var(--accent-bg)); box-shadow: var(--shadow); }.building-icon { display: grid; place-items: center; width: 66px; height: 66px; margin: 20px auto; border-radius: 16px; background: var(--surface); font-size: 34px; }.tool-chip { position: absolute; display: grid; place-items: center; width: 40px; height: 40px; border: 1px solid var(--border); border-radius: 13px; background: var(--surface); box-shadow: var(--shadow-sm); font-size: 18px; }.tool-chip-one { top: 19px; left: -17px; }.tool-chip-two { right: -18px; bottom: 15px; }.tool-chip-three { right: 23px; top: -15px; }.visual-spark { position: absolute; color: var(--accent); font-size: 16px; }.spark-one { left: 26px; top: 18px; }.spark-two { bottom: 15px; right: 53px; color: var(--primary-light); }
.flow-card { display: grid; grid-template-columns: 1fr; gap: 16px; padding: clamp(18px, 4vw, 28px); border: 1px solid var(--border); border-radius: var(--radius-lg); background: var(--surface); box-shadow: var(--shadow); }.flow-card-title { color: var(--text); font-size: 16px; font-weight: 800; }.flow-step { display: flex; gap: 12px; align-items: flex-start; min-width: 0; }.flow-step b { display: grid; place-items: center; flex: 0 0 40px; width: 40px; height: 40px; border-radius: 50%; background: var(--primary-bg); color: var(--primary-dark); font-size: 14px; }.flow-step strong, .flow-step small { display: block; }.flow-step strong { padding-top: 1px; color: var(--text); font-size: 13px; }.flow-step small { margin-top: 2px; color: var(--text-3); font-size: 12px; line-height: 1.45; }.flow-line { width: 1px; height: 14px; margin-left: 19px; background: var(--border-dark); }
@media (max-width: 600px) { .home-page { padding: 16px 16px calc(28px + env(safe-area-inset-bottom)); }.home-header { align-items: flex-start; flex-direction: column; gap: 14px; }.hero-tabs { width: 100%; justify-content: flex-start; gap: 6px; }.hero-tab { min-height: 44px; padding-inline: 10px; font-size: 12px; }.home-hero { gap: 28px; padding: 44px 0 24px; }.hero-copy-block h1 { font-size: clamp(36px, 10.5vw, 52px); }.hero-cta { width: 100%; position: sticky; bottom: calc(12px + env(safe-area-inset-bottom)); z-index: 3; }.visual-column { padding-top: 96px; } }
@media (min-width: 601px) { .home-page { padding-top: 26px; }.home-hero { grid-template-columns: minmax(0, 1.1fr) minmax(300px, .8fr); gap: clamp(32px, 6vw, 88px); padding-block: 56px; } }
@media (min-width: 1024px) { .home-hero { min-height: calc(100dvh - 100px); grid-template-columns: minmax(0, 1.1fr) minmax(380px, .8fr); }.flow-card { grid-template-columns: repeat(3, minmax(0, 1fr)); column-gap: 20px; }.flow-card-title { grid-column: 1 / -1; }.flow-line { display: none; }.hero-copy-block h1 { font-size: clamp(52px, 5vw, 72px); } }
</style>
