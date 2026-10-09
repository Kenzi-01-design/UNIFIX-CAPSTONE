<template>
  <svg
    class="brand-mark"
    :width="size"
    :height="size"
    viewBox="0 0 48 48"
    fill="none"
    role="img"
    aria-label="UNIFIX campus care mark"
    focusable="false"
  >
    <path
      d="M24 3.5 42 10v12.8c0 10.3-6.9 18-18 22.2C12.9 40.8 6 33.1 6 22.8V10l18-6.5Z"
      fill="#0F6B3D"
    />
    <path
      d="M12.5 19.5h8v-4h7v4h8v15h-23v-15Z"
      fill="#FFFDF7"
      stroke="#FFFDF7"
      stroke-linejoin="round"
    />
    <path
      d="M16 23h3v3h-3zm6 0h3v3h-3zm6 0h3v3h-3zM22 29h5v5h-5z"
      fill="#0F6B3D"
    />
    <circle cx="35.5" cy="34.5" r="8" fill="#DEA510" stroke="#FFFDF7" stroke-width="2" />
    <path d="m31.8 34.4 2.4 2.4 5-5.1" stroke="#0A4F2D" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
  </svg>
</template>

<script setup>
defineProps({
  size: { type: Number, default: 40 }
});
</script>
