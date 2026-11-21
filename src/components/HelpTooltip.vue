<template>
  <span class="help-tooltip">
    <button
      class="help-tooltip-trigger"
      type="button"
      :aria-label="`Help: ${label}`"
      :aria-describedby="tooltipId"
      @click="open = !open"
      @mouseenter="open = true"
      @mouseleave="open = false"
      @focus="open = true"
      @blur="open = false"
      @keydown.escape="open = false"
    >
      i
    </button>
    <span
      v-if="open"
      :id="tooltipId"
      class="help-tooltip-content"
      role="tooltip"
    >
      {{ text }}
    </span>
  </span>
</template>

<script setup>
import { ref, useId } from 'vue';

defineProps({
  label: { type: String, required: true },
  text: { type: String, required: true }
});

const open = ref(false);
const tooltipId = `help-tooltip-${useId()}`;
</script>

<style scoped>
.help-tooltip {
  position: relative;
  display: inline-flex;
  align-items: center;
  vertical-align: middle;
}

.help-tooltip-trigger {
  display: inline-grid;
  width: 22px;
  height: 22px;
  margin: 0 0 0 6px;
  padding: 0;
  place-items: center;
  border: 1px solid #7fa28d;
  border-radius: 50%;
  background: #fff;
  color: #17633e;
  font-size: 12px;
  font-weight: 800;
  line-height: 1;
  cursor: help;
}

.help-tooltip-trigger:focus-visible {
  outline: 3px solid rgba(23, 99, 62, 0.22);
  outline-offset: 2px;
}

.help-tooltip-content {
  position: absolute;
  z-index: 50;
  bottom: calc(100% + 8px);
  left: 50%;
  width: min(260px, 70vw);
  transform: translateX(-50%);
  padding: 10px 12px;
  border-radius: 8px;
  background: #173a27;
  color: #fff;
  box-shadow: 0 8px 24px rgba(10, 35, 21, 0.22);
  font-size: 12px;
  font-weight: 500;
  line-height: 1.45;
  text-align: left;
}

.help-tooltip-content::after {
  content: '';
  position: absolute;
  top: 100%;
  left: 50%;
  width: 8px;
  height: 8px;
  transform: translate(-50%, -50%) rotate(45deg);
  background: #173a27;
}
</style>
