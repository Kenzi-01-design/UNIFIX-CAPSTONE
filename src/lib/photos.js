import { isSupabaseConfigured, supabase } from './supabase.js';

export const MAX_PHOTO_COUNT = 3;
export const MAX_PHOTO_SIZE = 5 * 1024 * 1024;
const ALLOWED_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp']);
const BUCKET = 'report-photos';

export function validatePhotoFile(file) {
  if (!ALLOWED_TYPES.has(file.type)) {
    throw new Error('Photos must be JPG, PNG, or WebP images.');
  }
  if (file.size > MAX_PHOTO_SIZE) {
    throw new Error('Each photo must be 5 MB or smaller.');
  }
}

export async function compressPhoto(file) {
  validatePhotoFile(file);
  if (typeof createImageBitmap !== 'function') {
    throw new Error('This browser cannot process image attachments. Try a current browser.');
  }

  const bitmap = await createImageBitmap(file);
  try {
    const scale = Math.min(1, 1920 / Math.max(bitmap.width, bitmap.height));
    const canvas = document.createElement('canvas');
    canvas.width = Math.max(1, Math.round(bitmap.width * scale));
    canvas.height = Math.max(1, Math.round(bitmap.height * scale));
    const context = canvas.getContext('2d');
    if (!context) throw new Error('Unable to process the selected photo.');
    context.drawImage(bitmap, 0, 0, canvas.width, canvas.height);

    const blob = await new Promise((resolve, reject) => {
      canvas.toBlob(
        (result) => result ? resolve(result) : reject(new Error('Unable to compress the selected photo.')),
        'image/webp',
        0.82
      );
    });
    if (blob.size > MAX_PHOTO_SIZE) {
      throw new Error('The compressed photo is still over 5 MB. Select a smaller image.');
    }

    const baseName = file.name.replace(/\.[^.]+$/, '') || 'photo';
    return new File([blob], `${baseName}.webp`, { type: 'image/webp', lastModified: Date.now() });
  } finally {
    bitmap.close();
  }
}

export function photoToDataUrl(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => {
      if (typeof reader.result !== 'string') {
        reject(new Error('Unable to read the selected photo.'));
        return;
      }
      resolve(reader.result);
    };
    reader.onerror = () => reject(new Error('Unable to read the selected photo.'));
    reader.readAsDataURL(file);
  });
}

export async function uploadPhotoFiles(files, { entityType, entityId, phase = 'before', previous = [] }) {
  const selected = Array.from(files || []);
  if (!selected.length) return previous;
  if (selected.length + previous.length > MAX_PHOTO_COUNT) {
    throw new Error(`Attach no more than ${MAX_PHOTO_COUNT} photos.`);
  }
  selected.forEach(validatePhotoFile);

  if (!isSupabaseConfigured) {
    const attachments = await Promise.all(selected.map(async (file) => ({
      name: file.name,
      phase,
      url: await photoToDataUrl(file)
    })));
    return [...previous, ...attachments];
  }

  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError) throw userError;
  if (!userData.user) throw new Error('Sign in before uploading photos.');

  const uploadedPaths = [];
  try {
    const attachments = [];
    for (const file of selected) {
      const id = crypto.randomUUID();
      const path = `${userData.user.id}/${entityType}/${encodeURIComponent(entityId)}/${phase}/${id}.webp`;
      const { error } = await supabase.storage.from(BUCKET).upload(path, file, {
        cacheControl: '3600',
        contentType: file.type,
        upsert: false
      });
      if (error) throw error;
      uploadedPaths.push(path);
      attachments.push({ name: file.name, phase, path });
    }
    return [...previous, ...attachments];
  } catch (error) {
    if (uploadedPaths.length) {
      const { error: cleanupError } = await supabase.storage.from(BUCKET).remove(uploadedPaths);
      if (cleanupError) console.warn('Unable to remove partially uploaded photos.', cleanupError);
    }
    throw error;
  }
}

export async function resolvePhotoUrl(attachment) {
  if (attachment?.url) return attachment.url;
  if (!attachment?.path || !isSupabaseConfigured) {
    throw new Error('The photo attachment is not available.');
  }

  const { data, error } = await supabase.storage.from(BUCKET).createSignedUrl(attachment.path, 3600);
  if (error) throw error;
  if (!data?.signedUrl) throw new Error('The photo service did not return a view link.');
  return data.signedUrl;
}

export async function removeUploadedPhotos(attachments) {
  if (!isSupabaseConfigured) return;
  const paths = (attachments || []).map((photo) => photo.path).filter(Boolean);
  if (!paths.length) return;
  const { error } = await supabase.storage.from(BUCKET).remove(paths);
  if (error) throw error;
}
