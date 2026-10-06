import { describe, expect, it } from 'vitest';
import { REQUESTABLE_REGISTRATION_ROLES, resolveApprovalRole } from './registrationRoles.js';

describe('registration roles', () => {
  it('allows applicants to request non-admin roles only', () => {
    expect(REQUESTABLE_REGISTRATION_ROLES).toEqual(['Employee', 'Assistant', 'Personnel']);
    expect(REQUESTABLE_REGISTRATION_ROLES).not.toContain('Admin');
  });

  it('defaults approval to the requested role while allowing an Admin to override it', () => {
    expect(resolveApprovalRole('', 'Personnel')).toBe('Personnel');
    expect(resolveApprovalRole('Assistant', 'Personnel')).toBe('Assistant');
    expect(resolveApprovalRole('Admin', 'Personnel')).toBe('Admin');
    expect(resolveApprovalRole('', 'Invalid')).toBe('Employee');
  });
});
