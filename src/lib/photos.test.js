import { describe, expect, it } from 'vitest';
import { encodeStoragePathForUrl } from './photos.js';

describe('storage photo paths', () => {
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
