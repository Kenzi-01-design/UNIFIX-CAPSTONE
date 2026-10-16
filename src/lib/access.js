const roleViews = Object.freeze({
  Employee: new Set(['dashboard', 'submit-request', 'my-requisitions', 'reports', 'profile', 'settings', 'evaluation']),
  Assistant: new Set(['dashboard', 'submit', 'reports', 'requests', 'admin', 'activity-log', 'user-management', 'profile', 'settings', 'evaluation-results']),
  Personnel: new Set(['dashboard', 'reports', 'requests', 'tasks', 'profile', 'settings']),
  Admin: new Set(['dashboard', 'submit', 'reports', 'requests', 'admin', 'activity-log', 'user-management', 'profile', 'settings', 'evaluation-results'])
});

export function hasAdminAccess(role) {
  return role === 'Admin' || role === 'Assistant';
}

export function canAccessView(role, view) {
  return roleViews[role]?.has(view) ?? false;
}

export function canSubmitEvaluation(role) {
  return role === 'Public' || role === 'Employee';
}
