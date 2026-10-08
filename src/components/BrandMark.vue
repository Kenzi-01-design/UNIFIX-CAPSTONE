<template>
  <svg
    class="brand-mark"
    :width="size"
    :height="size"
    viewBox="0 0 48 48"
    fill="none"
    aria-hidden="true"
    focusable="false"
  >
    <rect x="2" y="2" width="44" height="44" rx="15" fill="#0F6B3D" />
    <rect x="3" y="3" width="42" height="42" rx="14" stroke="white" stroke-opacity=".18" />
    <path d="M10 21.5 24 12l14 9.5" stroke="#F0C56A" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" />
    <path d="M13 21v16h22V21L24 13.5 13 21Z" fill="white" />
    <path d="M18 24h4v4h-4zM26 24h4v4h-4z" fill="#0F6B3D" />
    <path d="M21 37v-7h6v7" fill="#DDEEE1" />
    <path d="M36.5 9.5v5M34 12h5" stroke="#F0C56A" stroke-width="1.8" stroke-linecap="round" />
    <circle cx="36.5" cy="12" r="5.5" stroke="#F0C56A" stroke-opacity=".42" />
  </svg>
</template>

<script setup>
defineProps({
  size: { type: Number, default: 40 }
});
</script>
