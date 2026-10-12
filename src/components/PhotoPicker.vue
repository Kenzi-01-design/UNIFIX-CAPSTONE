<template>
  <div class="photo-picker">
    <label class="photo-picker-label" :for="inputId">
      {{ label }}
      <span v-if="required" aria-hidden="true"> *</span>
      <span class="photo-picker-hint">JPG, PNG, or WebP · up to {{ maxPhotos }} photos · originals up to 25 MB, compressed to 5 MB each</span>
    </label>
    <input
      :id="inputId"
      type="file"
      accept="image/jpeg,image/png,image/webp"
      multiple
      :aria-required="required ? 'true' : undefined"
      :disabled="files.length >= maxPhotos || processing"
      @change="handleSelection"
    />
    <p v-if="required && !files.length" class="photo-picker-required" aria-live="polite">Attach at least one photo before submitting.</p>
    <p v-if="processing" class="photo-picker-status" aria-live="polite">Compressing photos…</p>
    <p v-if="error" class="photo-picker-error" role="alert">{{ error }}</p>
    <div v-if="files.length" class="photo-picker-previews">
      <figure v-for="(photo, index) in previews" :key="photo.key">
        <img :src="photo.url" :alt="photo.name" />
        <figcaption>{{ photo.name }}</figcaption>
        <button type="button" :aria-label="`Remove ${photo.name}`" @click="removePhoto(index)">Remove</button>
      </figure>
    </div>
  </div>
</template>

<script setup>
import { computed, onBeforeUnmount, ref, useId, watch } from 'vue';
import { compressPhoto, MAX_PHOTO_COUNT } from '../lib/photos.js';

const props = defineProps({
  modelValue: { type: Array, default: () => [] },
  label: { type: String, default: 'Photos (optional)' },
  maxPhotos: { type: Number, default: MAX_PHOTO_COUNT },
  required: { type: Boolean, default: false }
});
const emit = defineEmits(['update:modelValue', 'processing-change']);
const inputId = useId();
const processing = ref(false);
const error = ref('');
const previews = ref([]);
const files = computed(() => props.modelValue);

watch(
  () => props.modelValue,
  (selected) => {
    previews.value.forEach((photo) => URL.revokeObjectURL(photo.url));
    previews.value = selected.map((file) => ({
      key: `${file.name}-${file.lastModified}`,
      name: file.name,
      url: URL.createObjectURL(file)
    }));
  },
  { immediate: true }
);

async function handleSelection(event) {
  const incoming = Array.from(event.target.files || []);
  event.target.value = '';
  if (!incoming.length) return;
  error.value = '';

  const remaining = props.maxPhotos - files.value.length;
  if (incoming.length > remaining) {
    error.value = `You can attach up to ${props.maxPhotos} photos.`;
    return;
  }

  processing.value = true;
  emit('processing-change', true);
  try {
    const optimized = [];
    for (const file of incoming) optimized.push(await compressPhoto(file));
    emit('update:modelValue', [...files.value, ...optimized]);
  } catch (selectionError) {
    error.value = selectionError.message || 'Unable to prepare the selected photos.';
  } finally {
    processing.value = false;
    emit('processing-change', false);
  }
}

function removePhoto(index) {
  emit('update:modelValue', files.value.filter((_, fileIndex) => fileIndex !== index));
  error.value = '';
}

onBeforeUnmount(() => {
  previews.value.forEach((photo) => URL.revokeObjectURL(photo.url));
});
</script>

<style scoped>
.photo-picker { margin: 16px 0; padding: 14px; border: 1px solid var(--border); border-radius: var(--radius-sm); background: var(--surface-2); }
.photo-picker-label { display: block; margin-bottom: 8px; font-size: 13px; font-weight: 700; cursor: pointer; }
.photo-picker-hint { display: block; color: var(--text-3); font-size: 11px; font-weight: 400; }
.photo-picker input { max-width: 100%; font: inherit; font-size: 12px; }
.photo-picker-status, .photo-picker-error, .photo-picker-required { margin-top: 7px; font-size: 12px; }
.photo-picker-error { color: var(--red); }
.photo-picker-required { color: var(--text-3); }
.photo-picker-previews { display: grid; grid-template-columns: repeat(auto-fill, minmax(105px, 1fr)); gap: 10px; margin-top: 12px; }
.photo-picker figure { min-width: 0; padding: 7px; border: 1px solid var(--border); border-radius: 8px; background: var(--surface); }
.photo-picker img { display: block; width: 100%; aspect-ratio: 1; object-fit: cover; border-radius: 5px; }
.photo-picker figcaption { overflow: hidden; margin: 5px 0; color: var(--text-2); font-size: 10px; text-overflow: ellipsis; white-space: nowrap; }
.photo-picker button { border: 0; background: transparent; color: var(--red); font: inherit; font-size: 11px; font-weight: 700; cursor: pointer; }
</style>
