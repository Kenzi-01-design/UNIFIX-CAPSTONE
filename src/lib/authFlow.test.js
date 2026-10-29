import { describe, expect, it } from 'vitest';
import {
  accountAccessState,
  authStateMessage,
  canTransitionRegistrationStatus,
  classifyAuthError
} from './authFlow.js';

describe('account sign-in state handling', () => {
  it.each([
    [null, 'profile-missing'],
    [{ registration_status: 'pending', is_active: false }, 'pending'],
    [{ registration_status: 'rejected', is_active: false }, 'rejected'],
    [{ registration_status: 'approved', is_active: false }, 'deactivated'],
    [{ registration_status: 'approved', is_active: true }, 'active']
  ])('resolves %o to %s', (profile, expected) => {
    expect(accountAccessState(profile)).toBe(expected);
  });

  it('does not let the login role selection grant access', () => {
    const profile = { registration_status: 'approved', is_active: true, role: 'Employee' };
    expect(accountAccessState(profile)).toBe('active');
    expect(authStateMessage('pending')).toContain('administrator approval');
  });

  it('provides a clear rejection reason when one is available', () => {
    expect(authStateMessage('rejected', { rejection_reason: 'Missing department approval.' }))
      .toContain('Missing department approval.');
  });

  it.each([
    [{ code: 'email_not_confirmed', message: 'Email not confirmed' }, 'email-unconfirmed'],
    [{ message: 'Invalid login credentials' }, 'wrong-credentials'],
    [{ message: 'Failed to fetch' }, 'network-error'],
    [{ message: 'Unexpected server response' }, 'unknown']
  ])('classifies Auth failures as %s', (error, expected) => {
    expect(classifyAuthError(error)).toBe(expected);
  });
});

describe('registration status transitions', () => {
  it.each([
    ['pending', 'approved', true],
    ['pending', 'rejected', true],
    ['rejected', 'pending', true],
    ['approved', 'pending', false],
    ['rejected', 'approved', false],
    ['pending', 'rejected', true],
    ['approved', 'approved', true]
  ])('allows %s -> %s: %s', (from, to, allowed) => {
    expect(canTransitionRegistrationStatus(from, to)).toBe(allowed);
  });
});
