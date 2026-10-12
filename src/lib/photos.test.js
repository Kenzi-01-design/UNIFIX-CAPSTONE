import { afterEach, describe, expect, it, vi } from 'vitest';
import { compressPhoto, encodeStoragePathForUrl, getPhotoStorageEntitySegment } from './photos.js';

afterEach(() => {
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});

describe('storage photo paths', () => {
  it('uses a hash-free work item segment for new storage objects', () => {
    expect(getPhotoStorageEntitySegment('#REQ-ce50b732-3c4f-4e4e-8bac-e27088499b14'))
      .toBe('REQ-ce50b732-3c4f-4e4e-8bac-e27088499b14');
    expect(getPhotoStorageEntitySegment('#1042')).toBe('1042');
  });

  it('encodes reserved characters in raw path segments', () => {
    expect(encodeStoragePathForUrl(
      'user-id/requests/#REQ-adb15209-80eb-48c7-8a3b-59fb472b4553/before/photo.webp'
    )).toBe('user-id/requests/%23REQ-adb15209-80eb-48c7-8a3b-59fb472b4553/before/photo.webp');
  });

  it('preserves already encoded path segments without double encoding', () => {
    expect(encodeStoragePathForUrl('user-id/requests/%23REQ-123/before/photo.webp'))
      .toBe('user-id/requests/%23REQ-123/before/photo.webp');
  });
});

describe('photo compression', () => {
  it('falls back to the image element decoder and writes a correctly typed JPEG', async () => {
    const canvas = {
      width: 0,
      height: 0,
      getContext: () => ({
        fillRect: vi.fn(),
        drawImage: vi.fn()
      }),
      toBlob: vi.fn((callback) => callback(new Blob(['compressed'], { type: 'image/jpeg' })))
    };
    class ImageFallback {
      naturalWidth = 2;
      naturalHeight = 3;

      set src(value) {
        queueMicrotask(() => this.onload());
      }
    }

    vi.stubGlobal('createImageBitmap', vi.fn().mockRejectedValue(
      new DOMException('The source image could not be decoded.', 'EncodingError')
    ));
    vi.stubGlobal('Image', ImageFallback);
    vi.stubGlobal('document', { createElement: () => canvas });
    const createObjectUrl = vi.spyOn(URL, 'createObjectURL').mockReturnValue('blob:source-image');
    const revokeObjectUrl = vi.spyOn(URL, 'revokeObjectURL').mockImplementation(() => {});

    const source = new File(['source'], 'campus.png', { type: 'image/png' });
    const compressed = await compressPhoto(source);

    expect(compressed.name).toBe('campus.jpg');
    expect(compressed.type).toBe('image/jpeg');
    expect(canvas.toBlob).toHaveBeenCalledWith(expect.any(Function), 'image/jpeg', expect.any(Number));
    expect(createObjectUrl).toHaveBeenCalledWith(source);
    expect(revokeObjectUrl).toHaveBeenCalledWith('blob:source-image');
  });
});
