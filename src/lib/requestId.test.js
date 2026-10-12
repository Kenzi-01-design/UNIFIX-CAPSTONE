import { afterEach, describe, expect, it, vi } from 'vitest';
import { createReportId, createRequestId } from './requestId.js';

describe('work item ID generators', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('creates distinct report and request primary keys with consistent prefixes', () => {
    vi.stubGlobal('crypto', {
      randomUUID: vi.fn()
        .mockReturnValueOnce('a847c4f0-1ba8-4fe2-8c29-226bc3111094')
        .mockReturnValueOnce('f43d7f5c-140f-420b-977d-0adbc69d0b21')
    });

    expect(createReportId()).toBe('#RPT-a847c4f0-1ba8-4fe2-8c29-226bc3111094');
    expect(createRequestId()).toBe('#REQ-f43d7f5c-140f-420b-977d-0adbc69d0b21');
  });

  it('reports when secure ID generation is unavailable', () => {
    vi.stubGlobal('crypto', {});

    expect(() => createRequestId()).toThrow('Secure work item ID generation is unavailable');
    expect(() => createReportId()).toThrow('Secure work item ID generation is unavailable');
  });
});
