<template>
  <span
    class="brand-mark"
    :style="{ width: `${size}px`, height: `${size}px` }"
    role="img"
    aria-label="UNIFIX campus care logo with the NVSU seal"
  >
    <svg
      class="brand-mark-campus"
      viewBox="0 0 48 48"
      fill="none"
      aria-hidden="true"
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
    <img class="brand-mark-seal" src="/nvsu-seal.png" alt="" decoding="async" />
  </span>
</template>

<script setup>
defineProps({
  size: { type: Number, default: 40 }
});
</script>

<style scoped>
.brand-mark {
  position: relative;
  display: inline-block;
  flex: 0 0 auto;
  vertical-align: middle;
}

.brand-mark-campus {
  display: block;
  width: 100%;
  height: 100%;
}

.brand-mark-seal {
  position: absolute;
  right: -4%;
  bottom: -2%;
  width: 58%;
  height: 58%;
  border: 2px solid #fff;
  border-radius: 50%;
  background: #fff;
  box-shadow: 0 2px 5px rgba(15, 44, 27, 0.28);
  object-fit: cover;
}
</style>
