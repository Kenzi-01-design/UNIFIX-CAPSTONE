<template>
  <section v-if="photos.length || legacyPhoto || loading || error" class="photo-gallery">
    <strong>{{ label }}</strong>
    <p v-if="loading" class="photo-gallery-state">Loading private photos…</p>
    <p v-if="error" class="photo-gallery-error" role="alert">{{ error }}</p>
    <div v-for="photo in photos" :key="photo.key" class="photo-tile">
      <img :src="photo.url" :alt="`${photo.phase} photo of ${title}`" />
      <span>{{ photo.phase === 'after' ? 'After work' : 'Before work' }}</span>
    </div>
    <div v-if="legacyPhoto && !attachments.length" class="photo-tile">
      <img :src="legacyPhoto" :alt="title" />
      <span>Attached photo</span>
    </div>
  </section>
</template>

<script setup>
import { onBeforeUnmount, ref, watch } from 'vue';
import { resolvePhotoUrl } from '../lib/photos.js';

const props = defineProps({
  attachments: { type: Array, default: () => [] },
  legacyPhoto: { type: String, default: '' },
  title: { type: String, default: 'Work item' },
  label: { type: String, default: 'Attached photos' }
});
const photos = ref([]);
const loading = ref(false);
const error = ref('');
let generation = 0;

watch(
  () => props.attachments,
  async (attachments) => {
    const currentGeneration = ++generation;
    photos.value = [];
    error.value = '';
    if (!attachments.length) return;
    loading.value = true;
    try {
      const resolved = await Promise.all(attachments.map(async (attachment, index) => ({
        key: attachment.path || `${attachment.name || 'photo'}-${index}`,
        phase: attachment.phase || 'before',
        url: await resolvePhotoUrl(attachment)
      })));
      if (currentGeneration === generation) photos.value = resolved;
    } catch (resolveError) {
      if (currentGeneration === generation) error.value = resolveError.message || 'Unable to load attached photos.';
    } finally {
      if (currentGeneration === generation) loading.value = false;
    }
  },
  { immediate: true, deep: true }
);

onBeforeUnmount(() => { generation += 1; });
</script>

<style scoped>
.photo-gallery { display: flex; flex-wrap: wrap; align-items: flex-start; gap: 9px; margin-top: 11px; }
.photo-gallery > strong { flex: 0 0 100%; font-size: 12px; }
.photo-gallery-state, .photo-gallery-error { flex: 0 0 100%; color: var(--text-3); font-size: 11px; }
.photo-gallery-error { color: var(--red); }
.photo-tile { width: min(160px, 45%); overflow: hidden; border: 1px solid var(--border); border-radius: 8px; background: var(--surface); }
.photo-tile img { display: block; width: 100%; aspect-ratio: 1; object-fit: cover; }
.photo-tile span { display: block; padding: 5px 8px; color: var(--text-2); font-size: 10px; }
</style>
