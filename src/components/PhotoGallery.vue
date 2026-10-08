<template>
  <section v-if="photos.length || legacyPhoto || loading || error" class="photo-gallery">
    <strong>{{ label }}</strong>
    <p v-if="loading" class="photo-gallery-state">Loading private photos…</p>
    <p v-if="error" class="photo-gallery-error" role="alert">{{ error }}</p>
    <div v-for="photo in photos" :key="photo.key" class="photo-tile">
      <button
        class="photo-thumbnail"
        type="button"
        :aria-label="`View ${photo.phase} photo of ${title}`"
        @click="selectedPhoto = photo"
      >
        <img :src="photo.url" :alt="`${photo.phase} photo of ${title}`" />
      </button>
      <span>{{ photo.phase === 'after' ? 'After work' : 'Before work' }}</span>
      <button class="photo-open-button" type="button" @click="selectedPhoto = photo">View photo details</button>
    </div>
    <div v-if="legacyPhoto && !attachments.length" class="photo-tile">
      <button
        class="photo-thumbnail"
        type="button"
        :aria-label="`View attached photo of ${title}`"
        @click="selectedPhoto = { url: legacyPhoto, name: 'Attached photo', phase: 'before' }"
      >
        <img :src="legacyPhoto" :alt="title" />
      </button>
      <span>Attached photo</span>
      <button
        class="photo-open-button"
        type="button"
        @click="selectedPhoto = { url: legacyPhoto, name: 'Attached photo', phase: 'before' }"
      >View photo details</button>
    </div>

    <Teleport to="body">
      <div
        v-if="selectedPhoto"
        class="photo-lightbox"
        role="dialog"
        aria-modal="true"
        :aria-label="`Photo details: ${title}`"
        @click.self="selectedPhoto = null"
      >
        <section class="photo-lightbox-panel">
          <header class="photo-lightbox-header">
            <div>
              <strong>{{ title }}</strong>
              <span>{{ selectedPhoto.phase === 'after' ? 'After work' : selectedPhoto.phase === 'before' ? 'Before work' : 'Attached photo' }}</span>
            </div>
            <button
              class="photo-lightbox-close"
              type="button"
              aria-label="Close photo details"
              ref="closeButton"
              @click="selectedPhoto = null"
            >×</button>
          </header>
          <img class="photo-lightbox-image" :src="selectedPhoto.url" :alt="`${selectedPhoto.name || 'Attached photo'}: ${title}`" />
          <p v-if="selectedPhoto.name" class="photo-lightbox-filename">{{ selectedPhoto.name }}</p>
        </section>
      </div>
    </Teleport>
  </section>
</template>

<script setup>
import { nextTick, onBeforeUnmount, ref, watch } from 'vue';
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
const selectedPhoto = ref(null);
const closeButton = ref(null);
let generation = 0;
let returnFocusElement = null;

function handleLightboxKeydown(event) {
  if (event.key === 'Escape') {
    event.stopPropagation();
    selectedPhoto.value = null;
  } else if (event.key === 'Tab') {
    event.preventDefault();
    closeButton.value?.focus();
  }
}

watch(selectedPhoto, async (photo) => {
  if (photo) {
    returnFocusElement = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    window.addEventListener('keydown', handleLightboxKeydown);
    await nextTick();
    closeButton.value?.focus();
    return;
  }

  window.removeEventListener('keydown', handleLightboxKeydown);
  returnFocusElement?.focus();
  returnFocusElement = null;
});

watch(
  () => props.attachments,
  async (attachments) => {
    const currentGeneration = ++generation;
    photos.value = [];
    error.value = '';
    selectedPhoto.value = null;
    if (!attachments.length) {
      loading.value = false;
      return;
    }
    loading.value = true;
    try {
      const resolved = await Promise.all(attachments.map(async (attachment, index) => ({
        key: attachment.path || `${attachment.name || 'photo'}-${index}`,
        phase: attachment.phase || 'before',
        name: attachment.name || '',
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

onBeforeUnmount(() => {
  generation += 1;
  window.removeEventListener('keydown', handleLightboxKeydown);
  selectedPhoto.value = null;
});
</script>

<style scoped>
.photo-gallery { display: flex; flex-wrap: wrap; align-items: flex-start; gap: 9px; margin-top: 11px; }
.photo-gallery > strong { flex: 0 0 100%; font-size: 12px; }
.photo-gallery-state, .photo-gallery-error { flex: 0 0 100%; color: var(--text-3); font-size: 11px; }
.photo-gallery-error { color: var(--red); }
.photo-tile { width: min(160px, 45%); overflow: hidden; border: 1px solid var(--border); border-radius: 8px; background: var(--surface); }
.photo-thumbnail { display: block; width: 100%; padding: 0; border: 0; background: transparent; cursor: zoom-in; }
.photo-thumbnail:focus-visible, .photo-open-button:focus-visible, .photo-lightbox-close:focus-visible { outline: 3px solid var(--primary); outline-offset: 2px; }
.photo-thumbnail img { display: block; width: 100%; aspect-ratio: 1; object-fit: cover; }
.photo-tile span { display: block; padding: 5px 8px; color: var(--text-2); font-size: 10px; }
.photo-open-button { display: block; padding: 0 8px 7px; border: 0; background: transparent; color: var(--primary); font: inherit; font-size: 11px; font-weight: 600; cursor: pointer; }
.photo-lightbox { position: fixed; inset: 0; z-index: 10001; display: grid; place-items: center; padding: 20px; background: rgba(8, 15, 11, .88); }
.photo-lightbox-panel { display: flex; flex-direction: column; width: min(1100px, 96vw); max-height: 94vh; overflow: hidden; border: 1px solid rgba(255, 255, 255, .18); border-radius: 12px; background: var(--surface, #fff); box-shadow: 0 24px 80px rgba(0, 0, 0, .4); }
.photo-lightbox-header { display: flex; align-items: flex-start; justify-content: space-between; gap: 20px; padding: 14px 18px; color: var(--text, #17211b); }
.photo-lightbox-header strong, .photo-lightbox-header span { display: block; }
.photo-lightbox-header span, .photo-lightbox-filename { margin: 4px 0 0; color: var(--text-3, #66736b); font-size: 12px; }
.photo-lightbox-close { flex: 0 0 auto; width: 36px; height: 36px; border: 1px solid var(--border, #dce8df); border-radius: 8px; background: var(--surface-2, #f7faf7); color: var(--text, #17211b); font-size: 24px; line-height: 1; cursor: pointer; }
.photo-lightbox-image { display: block; width: 100%; min-height: 0; max-height: calc(94vh - 105px); object-fit: contain; background: #101412; }
.photo-lightbox-filename { padding: 0 18px 12px; overflow-wrap: anywhere; }
@media (max-width: 1023px) {
  .photo-lightbox-close { width: 44px; height: 44px; }
  .photo-open-button { min-height: 44px; padding: 8px; text-align: center; }
}
</style>
