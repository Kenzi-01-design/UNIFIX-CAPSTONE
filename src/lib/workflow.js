export function isAssignedToPersonnel(item, personnelName) {
  const assigned = Array.isArray(item?.assignedPersonnel)
    ? item.assignedPersonnel
    : String(item?.assignedTo || '').split(',').map((name) => name.trim()).filter(Boolean);
  const currentName = String(personnelName || '').trim().toLowerCase();
  return Boolean(currentName)
    && assigned.some((name) => String(name || '').trim().toLowerCase() === currentName);
}

export function canSubmitWorkForVerification(item, personnelName) {
  return item?.status === 'in-progress'
    && item?.techState === 'started'
    && isAssignedToPersonnel(item, personnelName);
}

export function canVerifyCompletedWork(item) {
  return item?.status === 'for-verification' && item?.techState === 'completed';
}

export function canRejectForRework(item, reason) {
  const safeReason = String(reason || '').trim();
  return canVerifyCompletedWork(item) && safeReason.length >= 5 && safeReason.length <= 500;
}
