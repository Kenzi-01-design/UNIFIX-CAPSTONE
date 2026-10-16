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

  it('grants Admin and Assistant the same administrative routes', () => {
    const adminViews = ['dashboard', 'submit', 'reports', 'requests', 'admin', 'activity-log', 'user-management', 'profile', 'settings', 'evaluation-results'];
    for (const view of adminViews) {
      expect(canAccessView('Admin', view)).toBe(true);
      expect(canAccessView('Assistant', view)).toBe(true);
    }
    for (const role of ['Employee', 'Personnel']) {
      for (const view of ['user-management', 'activity-log', 'evaluation-results']) {
        expect(canAccessView(role, view)).toBe(false);
      }
    }
  });

  it('limits employee, assistant, and personnel to their intended screens', () => {
    expect(canAccessView('Employee', 'my-requisitions')).toBe(true);
    expect(canAccessView('Employee', 'submit')).toBe(false);
    expect(canAccessView('Personnel', 'tasks')).toBe(true);
    expect(canAccessView('Personnel', 'reports')).toBe(true);
    expect(canAccessView('Personnel', 'requests')).toBe(true);
    expect(canAccessView('Personnel', 'submit')).toBe(false);
  });
});
