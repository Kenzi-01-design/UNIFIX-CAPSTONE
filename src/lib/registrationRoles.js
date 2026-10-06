export const REQUESTABLE_REGISTRATION_ROLES = ['Employee', 'Assistant', 'Personnel'];

const APPROVABLE_ROLES = ['Admin', ...REQUESTABLE_REGISTRATION_ROLES];

export function resolveApprovalRole(selectedRole, requestedRole) {
  if (APPROVABLE_ROLES.includes(selectedRole)) return selectedRole;
  if (REQUESTABLE_REGISTRATION_ROLES.includes(requestedRole)) return requestedRole;
  return 'Employee';
}
