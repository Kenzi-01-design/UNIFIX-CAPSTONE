import { isSupabaseConfigured, supabase } from './supabase.js';

export const MAX_PHOTO_COUNT = 3;
export const MAX_TOTAL_PHOTO_COUNT = MAX_PHOTO_COUNT * 2;
export const MAX_PHOTO_SIZE = 5 * 1024 * 1024;
const ALLOWED_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp']);
const MAX_SOURCE_PHOTO_SIZE = 25 * 1024 * 1024;
const BUCKET = 'report-photos';

export function encodeStoragePathForUrl(path) {
  return String(path)
    .split('/')
    .map((segment) => {
      try {
        return encodeURIComponent(decodeURIComponent(segment));
      } catch (error) {
        if (!(error instanceof URIError)) throw error;
        return encodeURIComponent(segment);
      }
    })
    .join('/');
}

export function getPhotoStorageEntitySegment(entityId) {
  return encodeURIComponent(String(entityId).replace(/^#/, ''));
}

function validatePhotoType(file) {
  if (!ALLOWED_TYPES.has(file.type)) {
    throw new Error('Photos must be JPG, PNG, or WebP images.');
  }
}

export function validatePhotoFile(file) {
  validatePhotoType(file);
  if (file.size > MAX_PHOTO_SIZE) {
    throw new Error('Each photo must be 5 MB or smaller.');
  }
}

export async function compressPhoto(file) {
  validatePhotoType(file);
  if (file.size > MAX_SOURCE_PHOTO_SIZE) {
    throw new Error('Each original photo must be 25 MB or smaller.');
  }

  let bitmap;
  let imageUrl;
  let image;
  try {
    if (typeof createImageBitmap === 'function') {
      bitmap = await createImageBitmap(file);
    }
  } catch {
    // Fall back to the browser image decoder below.
  }

  if (!bitmap) {
    imageUrl = URL.createObjectURL(file);
    image = new Image();
    try {
      await new Promise((resolve, reject) => {
        image.onload = resolve;
        image.onerror = reject;
        image.src = imageUrl;
      });
    } catch {
      URL.revokeObjectURL(imageUrl);
      throw new Error('The selected image could not be decoded. Save it as a JPG, PNG, or WebP image and try again.');
    }
  }

  const source = bitmap || image;
  const width = source.width || source.naturalWidth;
  const height = source.height || source.naturalHeight;
  if (!width || !height) {
    bitmap?.close();
    if (imageUrl) URL.revokeObjectURL(imageUrl);
    throw new Error('The selected image could not be decoded. Save it as a JPG, PNG, or WebP image and try again.');
  }

  try {
    let scale = Math.min(1, 1920 / Math.max(width, height));
    const canvas = document.createElement('canvas');
    let context;

    let blob;
    for (let attempt = 0; attempt < 5; attempt += 1) {
      canvas.width = Math.max(1, Math.round(width * scale));
      canvas.height = Math.max(1, Math.round(height * scale));
      context = canvas.getContext('2d');
      if (!context) throw new Error('Unable to process the selected photo.');
      context.fillStyle = '#fff';
      context.fillRect(0, 0, canvas.width, canvas.height);
      context.drawImage(source, 0, 0, canvas.width, canvas.height);
      const quality = Math.max(0.5, 0.82 - attempt * 0.08);
      blob = await new Promise((resolve, reject) => {
        canvas.toBlob(
          (result) => result ? resolve(result) : reject(new Error('Unable to compress the selected photo.')),
          'image/jpeg',
          quality
        );
      });
      if (blob.type !== 'image/jpeg') {
        throw new Error('This browser could not prepare the selected image. Try a current browser.');
      }
      if (blob.size <= MAX_PHOTO_SIZE) break;
      scale *= 0.8;
    }
    if (!blob || blob.size > MAX_PHOTO_SIZE) {
      throw new Error('The compressed photo is still over 5 MB. Select a smaller image.');
    }

    const baseName = file.name.replace(/\.[^.]+$/, '') || 'photo';
    return new File([blob], `${baseName}.jpg`, { type: 'image/jpeg', lastModified: Date.now() });
  } finally {
    bitmap?.close();
    if (imageUrl) URL.revokeObjectURL(imageUrl);
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
  if (selected.length > MAX_PHOTO_COUNT || selected.length + previous.length > MAX_TOTAL_PHOTO_COUNT) {
    throw new Error(`Attach no more than ${MAX_PHOTO_COUNT} photos for each submission.`);
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
      const extension = file.type === 'image/jpeg' ? 'jpg' : file.type.slice('image/'.length);
      const path = `${userData.user.id}/${entityType}/${getPhotoStorageEntitySegment(entityId)}/${phase}/${id}.${extension}`;
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

  const path = encodeStoragePathForUrl(attachment.path);
  const { data, error } = await supabase.storage.from(BUCKET).createSignedUrl(path, 3600);
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
