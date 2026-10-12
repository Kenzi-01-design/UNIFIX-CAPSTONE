<template>
  <img
    class="brand-mark"
    src="/nvsu-seal.png"
    :width="size"
    :height="size"
    alt="Nueva Vizcaya State University seal"
    decoding="async"
  />
</template>

<script setup>
defineProps({
  size: { type: Number, default: 40 }
});
</script>

<style scoped>
.brand-mark {
  display: block;
  flex: 0 0 auto;
  border-radius: 50%;
  background: #fff;
  object-fit: contain;
  padding: 2px;
}
</style>
