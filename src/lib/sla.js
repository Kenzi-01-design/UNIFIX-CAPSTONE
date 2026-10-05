export const DEFAULT_SLA_SETTINGS = Object.freeze([
  { priority: 'low', target_hours: 168 },
  { priority: 'medium', target_hours: 72 },
  { priority: 'high', target_hours: 24 },
  { priority: 'urgent', target_hours: 4 }
]);

export function calculateDueAt(priority = 'low', settings = DEFAULT_SLA_SETTINGS, now = Date.now()) {
  const target = settings.find((item) => item.priority === priority);
  const targetHours = Number(target?.target_hours) || 168;
  return new Date(now + targetHours * 60 * 60 * 1000).toISOString();
}

export function isOverdue(dueAt, now = Date.now()) {
  const dueTime = Date.parse(dueAt || '');
  return Number.isFinite(dueTime) && dueTime < now;
}

export function formatTimeRemaining(dueAt, now = Date.now()) {
  const dueTime = Date.parse(dueAt || '');
  if (!Number.isFinite(dueTime)) return 'No deadline';
  const difference = dueTime - now;
  const totalMinutes = Math.ceil(Math.abs(difference) / 60_000);
  const days = Math.floor(totalMinutes / 1440);
  const hours = Math.floor((totalMinutes % 1440) / 60);
  const minutes = totalMinutes % 60;
  const remaining = days ? `${days}d ${hours}h` : hours ? `${hours}h ${minutes}m` : `${minutes}m`;
  return difference < 0 ? `${remaining} overdue` : `${remaining} left`;
}
