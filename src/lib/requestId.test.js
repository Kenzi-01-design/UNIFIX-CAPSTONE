import { afterEach, describe, expect, it, vi } from 'vitest';
import { createRequestId } from './requestId.js';

describe('createRequestId', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('creates distinct request primary keys without relying on the loaded request count', () => {
    vi.stubGlobal('crypto', {
      randomUUID: vi.fn()
        .mockReturnValueOnce('a847c4f0-1ba8-4fe2-8c29-226bc3111094')
        .mockReturnValueOnce('f43d7f5c-140f-420b-977d-0adbc69d0b21')
    });

    expect(createRequestId()).toBe('#REQ-a847c4f0-1ba8-4fe2-8c29-226bc3111094');
    expect(createRequestId()).toBe('#REQ-f43d7f5c-140f-420b-977d-0adbc69d0b21');
  });

  it('reports when secure ID generation is unavailable', () => {
    vi.stubGlobal('crypto', {});

    expect(() => createRequestId()).toThrow('Secure request ID generation is unavailable');
  });
});
