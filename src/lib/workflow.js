export function canSubmitWorkForVerification(item, personnelName) {
  const assigned = Array.isArray(item?.assignedPersonnel)
    ? item.assignedPersonnel
    : String(item?.assignedTo || '').split(',').map((name) => name.trim()).filter(Boolean);
  return item?.status === 'in-progress'
    && item?.techState === 'started'
    && assigned.some((name) => name.toLowerCase() === String(personnelName || '').trim().toLowerCase());
}

export function canVerifyCompletedWork(item) {
  return item?.status === 'for-verification' && item?.techState === 'completed';
}

export function canRejectForRework(item, reason) {
  const safeReason = String(reason || '').trim();
  return canVerifyCompletedWork(item) && safeReason.length >= 5 && safeReason.length <= 500;
}
