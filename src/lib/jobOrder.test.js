import { describe, expect, it } from 'vitest';
import { isJobOrderVerified, printJobOrder } from './jobOrder.js';

describe('job order verification', () => {
  it('allows printing only after successful verification and closure', () => {
    expect(isJobOrderVerified({
      status: 'closed',
      techState: 'completed',
      verifiedAt: '2026-10-05T10:00:00.000Z'
    })).toBe(true);
  });

  it('does not allow printing while work is awaiting verification', () => {
    expect(isJobOrderVerified({
      status: 'for-verification',
      techState: 'completed',
      verifiedAt: null
    })).toBe(false);
  });

  it('does not allow printing before the verification save succeeds', () => {
    expect(isJobOrderVerified({
      status: 'closed',
      techState: 'completed',
      verifiedAt: null
    })).toBe(false);
  });

  it('does not allow printing when the request is not complete', () => {
    expect(isJobOrderVerified({
      status: 'closed',
      techState: 'in-progress',
      verifiedAt: '2026-10-05T10:00:00.000Z'
    })).toBe(false);
  });

  it('guards direct print calls as well as disabled UI controls', () => {
    expect(() => printJobOrder({
      id: 'REQ-1',
      title: 'Repair request',
      status: 'for-verification',
      techState: 'completed'
    })).toThrow('available after the request has been verified and closed');
  });
});
