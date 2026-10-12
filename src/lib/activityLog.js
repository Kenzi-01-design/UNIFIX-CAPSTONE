const statusLabels = {
  'action-taken': 'Action Taken',
  'for-verification': 'For Verification',
  'in-progress': 'In Progress',
  closed: 'Closed',
  pending: 'Pending',
  resolved: 'Resolved',
  submitted: 'Submitted',
  urgent: 'Urgent'
};

function statusClass(status) {
  if (['action-taken', 'closed', 'resolved'].includes(status)) return 'resolved';
  if (['for-verification', 'in-progress'].includes(status)) return 'in-progress';
  if (status === 'urgent') return 'urgent';
  return 'pending';
}

function formatDate(timestamp) {
  const date = new Date(timestamp);
  return Number.isNaN(date.getTime()) ? 'Unknown date' : date.toLocaleString();
}

function formatAuditValue(value) {
  if (value === null || value === undefined) return 'empty';
  if (typeof value === 'object' && !Array.isArray(value)) {
    if (typeof value.present === 'boolean') return value.present ? 'attached' : 'removed';
    if (Array.isArray(value.assigned_personnel)) {
      return value.assigned_personnel.join(', ') || 'unassigned';
    }
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) return value.join(', ') || 'none';
  return String(value).slice(0, 160);
}

export function mapWorkItemActivity(event) {
  const timestamp = new Date(event.created_at).getTime();
  const status = event.current_status || '';
  const actor = [event.actor_name, event.actor_role].filter(Boolean).join(' · ');
  const changeDetails = ['status_changed', 'work_stage_changed', 'reopened'].includes(event.action)
    || event.old_value === null && event.new_value === null
    ? ''
    : `From ${formatAuditValue(event.old_value)} to ${formatAuditValue(event.new_value)}`;

  return {
    id: `activity-${event.id}`,
    type: String(event.entity_type || 'work item').toUpperCase(),
    referenceId: event.tracking_code || event.entity_id,
    title: event.entity_title,
    timestamp: Number.isNaN(timestamp) ? 0 : timestamp,
    date: formatDate(event.created_at),
    statusClass: statusClass(status),
    statusLabel: statusLabels[status] || status || 'Unknown',
    details: [event.summary, changeDetails, actor ? `By ${actor}` : ''].filter(Boolean).join(' · ')
  };
}

export function mergeActivityEntries(workItemEvents, loginEvents = []) {
  return [
    ...workItemEvents.map(mapWorkItemActivity),
    ...loginEvents.map((event) => ({
      ...event,
      referenceId: event.referenceId || event.id,
      timestamp: Number(event.timestamp) || 0,
      details: event.details || 'Successful sign in'
    }))
  ].sort((left, right) => right.timestamp - left.timestamp);
}
