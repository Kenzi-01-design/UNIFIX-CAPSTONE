import { describe, expect, it } from 'vitest';
import { canAccessView, canSubmitEvaluation } from './access.js';

describe('role access', () => {
  it('limits evaluation submission to public reporters and employees', () => {
    expect(canSubmitEvaluation('Public')).toBe(true);
    expect(canSubmitEvaluation('Employee')).toBe(true);
    for (const role of ['Assistant', 'Personnel', 'Admin', 'Student', 'unknown']) {
      expect(canSubmitEvaluation(role)).toBe(false);
    }
  });

  it('keeps administrative routes out of non-admin navigation', () => {
    for (const role of ['Employee', 'Assistant', 'Personnel']) {
      for (const view of ['user-management', 'activity-log', 'evaluation-results']) {
        expect(canAccessView(role, view)).toBe(false);
      }
    }
    expect(canAccessView('Admin', 'user-management')).toBe(true);
    expect(canAccessView('Admin', 'evaluation-results')).toBe(true);
    expect(canAccessView('Admin', 'requests')).toBe(true);
    expect(canAccessView('Assistant', 'requests')).toBe(false);
  });

  it('limits employee, assistant, and personnel to their intended screens', () => {
    expect(canAccessView('Employee', 'my-requisitions')).toBe(true);
    expect(canAccessView('Employee', 'submit')).toBe(false);
    expect(canAccessView('Assistant', 'admin')).toBe(true);
    expect(canAccessView('Assistant', 'settings')).toBe(true);
    expect(canAccessView('Personnel', 'tasks')).toBe(true);
    expect(canAccessView('Personnel', 'reports')).toBe(true);
    expect(canAccessView('Personnel', 'requests')).toBe(true);
    expect(canAccessView('Personnel', 'submit')).toBe(false);
  });
});
