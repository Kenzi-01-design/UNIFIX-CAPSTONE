const roleViews = Object.freeze({
  Employee: new Set(['dashboard', 'submit-request', 'my-requisitions', 'reports', 'profile', 'settings', 'evaluation']),
  Assistant: new Set(['dashboard', 'reports', 'admin', 'profile', 'settings']),
  Personnel: new Set(['dashboard', 'reports', 'tasks', 'profile', 'settings']),
  Admin: new Set(['dashboard', 'submit', 'reports', 'admin', 'activity-log', 'user-management', 'profile', 'settings', 'evaluation-results'])
});

export function canAccessView(role, view) {
  return roleViews[role]?.has(view) ?? false;
}

export function canSubmitEvaluation(role) {
  return role === 'Public' || role === 'Employee';
}
