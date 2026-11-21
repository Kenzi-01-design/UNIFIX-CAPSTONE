<template>
  <Teleport to="body">
    <div v-if="visible" class="first-use-tour" role="dialog" aria-modal="true" :aria-label="`Guide step ${currentIndex + 1} of ${steps.length}`">
      <div class="tour-backdrop" aria-hidden="true">
        <div class="tour-shade" :style="shadeTop"></div>
        <div class="tour-shade" :style="shadeLeft"></div>
        <div class="tour-shade" :style="shadeRight"></div>
        <div class="tour-shade" :style="shadeBottom"></div>
      </div>
      <div class="tour-highlight" :style="highlightStyle" aria-hidden="true"></div>
      <section class="tour-card" :style="cardStyle" role="document">
        <div class="tour-progress" aria-label="Guide progress">
          <span
            v-for="(_, index) in steps"
            :key="index"
            :class="{ active: index === currentIndex }"
          ></span>
        </div>
        <strong class="tour-title">{{ currentStep.title }}</strong>
        <p class="tour-description">{{ currentStep.description }}</p>
        <div class="tour-actions">
          <button type="button" class="tour-skip" @click="finish">Skip</button>
          <button type="button" class="tour-next" @click="next">
            {{ currentIndex === steps.length - 1 ? 'Got it' : 'Next' }}
          </button>
        </div>
      </section>
    </div>
  </Teleport>
</template>

<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue';

const props = defineProps({
  storageKey: { type: String, required: true },
  steps: { type: Array, required: true },
  autoStart: { type: Boolean, default: true }
});

const visible = ref(false);
const currentIndex = ref(0);
const highlightStyle = ref({});
const cardStyle = ref({});
const shadeTop = ref({ left: '0', top: '0', width: '100%', height: '100%' });
const shadeLeft = ref({ display: 'none' });
const shadeRight = ref({ display: 'none' });
const shadeBottom = ref({ display: 'none' });

const currentStep = computed(() => props.steps[currentIndex.value] || props.steps[0]);

function wasDismissed() {
  try {
    return localStorage.getItem(props.storageKey) === 'true';
  } catch {
    return false;
  }
}

function finish() {
  visible.value = false;
  try {
    localStorage.setItem(props.storageKey, 'true');
  } catch (error) {
    console.warn('Could not save the first-use guide preference.', error);
  }
}

async function start() {
  currentIndex.value = 0;
  visible.value = true;
  await nextTick();
  await positionGuide();
}

function next() {
  if (currentIndex.value >= props.steps.length - 1) {
    finish();
    return;
  }
  currentIndex.value += 1;
}

async function positionGuide() {
  if (!visible.value || !currentStep.value) return;

  await nextTick();
  const target = document.querySelector(currentStep.value.target);
  if (!target) {
    cardStyle.value = {
      left: '50%',
      top: 'auto',
      bottom: '24px',
      transform: 'translateX(-50%)'
    };
    highlightStyle.value = { display: 'none' };
    shadeTop.value = { left: '0', top: '0', width: '100%', height: '100%' };
    shadeLeft.value = { display: 'none' };
    shadeRight.value = { display: 'none' };
    shadeBottom.value = { display: 'none' };
    return;
  }

  target.scrollIntoView({ behavior: 'smooth', block: 'center' });
  await new Promise((resolve) => window.setTimeout(resolve, 180));

  const rect = target.getBoundingClientRect();
  const padding = 6;
  highlightStyle.value = {
    left: `${Math.max(8, rect.left - padding)}px`,
    top: `${Math.max(8, rect.top - padding)}px`,
    width: `${rect.width + padding * 2}px`,
    height: `${rect.height + padding * 2}px`
  };
  const spotlightLeft = Math.max(8, rect.left - padding);
  const spotlightTop = Math.max(8, rect.top - padding);
  const right = Math.min(window.innerWidth - 8, rect.right + padding);
  const bottom = Math.min(window.innerHeight - 8, rect.bottom + padding);

  shadeTop.value = { left: '0', top: '0', width: '100%', height: `${spotlightTop}px` };
  shadeLeft.value = {
    left: '0',
    top: `${spotlightTop}px`,
    width: `${spotlightLeft}px`,
    height: `${bottom - spotlightTop}px`
  };
  shadeRight.value = {
    left: `${right}px`,
    top: `${spotlightTop}px`,
    width: `${window.innerWidth - right}px`,
    height: `${bottom - spotlightTop}px`
  };
  shadeBottom.value = {
    left: '0',
    top: `${bottom}px`,
    width: '100%',
    height: `${window.innerHeight - bottom}px`
  };

  const cardWidth = Math.min(340, window.innerWidth - 32);
  let left = rect.left + rect.width / 2 - cardWidth / 2;
  left = Math.max(16, Math.min(left, window.innerWidth - cardWidth - 16));

  const estimatedCardHeight = 190;
  const below = rect.bottom + 14;
  let top = below;
  if (below + estimatedCardHeight > window.innerHeight - 16) {
    top = Math.max(16, rect.top - estimatedCardHeight - 14);
  }

  cardStyle.value = {
    left: `${left}px`,
    top: `${top}px`,
    width: `${cardWidth}px`
  };
}

watch(currentIndex, positionGuide);
watch(() => props.storageKey, () => {
  if (!props.autoStart) return;
  currentIndex.value = 0;
  visible.value = !wasDismissed();
  if (visible.value) positionGuide();
});

function handleKeydown(event) {
  if (event.key === 'Escape') finish();
}

onMounted(() => {
  visible.value = props.autoStart ? !wasDismissed() : false;
  if (visible.value) positionGuide();
  window.addEventListener('resize', positionGuide);
  window.addEventListener('scroll', positionGuide, true);
  window.addEventListener('keydown', handleKeydown);
});

onBeforeUnmount(() => {
  window.removeEventListener('resize', positionGuide);
  window.removeEventListener('scroll', positionGuide, true);
  window.removeEventListener('keydown', handleKeydown);
});

defineExpose({ start, finish });
</script>

<style scoped>
.first-use-tour,
.tour-backdrop,
.tour-highlight {
  position: fixed;
  inset: 0;
}

.first-use-tour {
  z-index: 10000;
  pointer-events: none;
}

.tour-backdrop {
  pointer-events: auto;
}

.tour-shade {
  position: absolute;
  background: rgba(4, 18, 10, 0.68);
}

.tour-highlight {
  inset: auto;
  z-index: 10001;
  border: 3px solid #fff;
  border-radius: 12px;
  box-shadow: 0 8px 28px rgba(0, 0, 0, 0.24);
  pointer-events: none;
  transition: left 180ms ease, top 180ms ease, width 180ms ease, height 180ms ease;
}

.tour-card {
  position: fixed;
  z-index: 10002;
  box-sizing: border-box;
  padding: 18px;
  border: 1px solid rgba(255, 255, 255, 0.14);
  border-radius: 16px;
  background: #fff;
  color: #17251d;
  box-shadow: 0 16px 44px rgba(5, 28, 14, 0.28);
  pointer-events: auto;
  transition: left 180ms ease, top 180ms ease;
}

.tour-progress {
  display: flex;
  gap: 5px;
  margin-bottom: 12px;
}

.tour-progress span {
  width: 18px;
  height: 4px;
  border-radius: 999px;
  background: #dce7e0;
}

.tour-progress span.active {
  width: 30px;
  background: #147b49;
}

.tour-title {
  display: block;
  margin-bottom: 5px;
  font-size: 16px;
  font-weight: 800;
}

.tour-description {
  margin: 0;
  color: #536159;
  font-size: 13px;
  line-height: 1.55;
}

.tour-actions {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
  margin-top: 15px;
}

.tour-actions button {
  min-height: 44px;
  border-radius: 9px;
  font-weight: 750;
  cursor: pointer;
}

.tour-skip {
  border: 0;
  background: transparent;
  color: #657268;
  padding: 0 12px;
}

.tour-next {
  min-width: 96px;
  border: 0;
  background: #147b49;
  color: #fff;
  padding: 0 16px;
}

.tour-next:focus-visible,
.tour-skip:focus-visible {
  outline: 3px solid rgba(20, 123, 73, 0.24);
  outline-offset: 2px;
}
</style>
