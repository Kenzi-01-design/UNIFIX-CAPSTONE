import { afterEach, describe, expect, it, vi } from 'vitest';
import { createDemoTrackingCode } from './tracking.js';

describe('demo tracking codes', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('starts report and request codes at 100 and increments their shared counter', () => {
    const storage = new Map();
    vi.stubGlobal('localStorage', {
      getItem: (key) => storage.get(key) ?? null,
      setItem: (key, value) => storage.set(key, value)
    });
    const year = new Date().getFullYear();

    expect(createDemoTrackingCode()).toBe(`UNI-${year}-0100`);
    expect(createDemoTrackingCode()).toBe(`UNI-${year}-0101`);
  });

  it('continues above 100 when a higher demo counter is already saved', () => {
    const year = new Date().getFullYear();
    const storage = new Map([[`unifix-tracking-counter-${year}`, '125']]);
    vi.stubGlobal('localStorage', {
      getItem: (key) => storage.get(key) ?? null,
      setItem: (key, value) => storage.set(key, value)
    });

    expect(createDemoTrackingCode()).toBe(`UNI-${year}-0126`);
  });
});
