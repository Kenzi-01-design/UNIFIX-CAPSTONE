import { describe, expect, it } from 'vitest';
import { mapWorkItemActivity, mergeActivityEntries } from './activityLog.js';

describe('activity log entries', () => {
  it('maps an audited work item change with its actor and event timestamp', () => {
    const event = mapWorkItemActivity({
      id: 14,
      entity_type: 'request',
      entity_id: 'REQ-14',
      tracking_code: 'UNX-2026-0014',
      entity_title: 'Repair a projector',
      current_status: 'in-progress',
      summary: 'Status changed from submitted to in-progress',
      action: 'status_changed',
      actor_name: 'Alex Admin',
      actor_role: 'Admin',
      created_at: '2026-10-12T09:30:00.000Z'
    });

    expect(event).toMatchObject({
      id: 'activity-14',
      type: 'REQUEST',
      referenceId: 'UNX-2026-0014',
      title: 'Repair a projector',
      timestamp: Date.parse('2026-10-12T09:30:00.000Z'),
      statusClass: 'in-progress',
      statusLabel: 'In Progress',
      details: 'Status changed from submitted to in-progress · By Alex Admin · Admin'
    });
  });

  it('includes the actual old and new values for audited edits', () => {
    const event = mapWorkItemActivity({
      id: 15,
      entity_type: 'report',
      entity_id: 'R-15',
      entity_title: 'Broken window',
      action: 'assignment_changed',
      summary: 'Assigned personnel changed',
      old_value: { assigned_personnel: [] },
      new_value: { assigned_personnel: ['Sam Technician'] },
      created_at: '2026-10-12T09:30:00.000Z'
    });

    expect(event.details).toContain('From unassigned to Sam Technician');
  });

  it('merges login and work-item activity in newest-first order', () => {
    const entries = mergeActivityEntries([
      {
        id: 1,
        entity_type: 'report',
        entity_id: 'R-1',
        entity_title: 'Broken window',
        created_at: '2026-10-12T08:00:00.000Z',
        summary: 'Report submitted'
      }
    ], [{
      id: 'LOGIN-1',
      type: 'LOGIN',
      timestamp: Date.parse('2026-10-12T09:00:00.000Z')
    }]);

    expect(entries.map((entry) => entry.type)).toEqual(['LOGIN', 'REPORT']);
    expect(entries[0].referenceId).toBe('LOGIN-1');
  });
});
