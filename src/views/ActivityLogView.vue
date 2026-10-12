<template>
  <div class="view active" id="view-activity-log">
    <div class="panel">
      <div class="panel-header">
        <span class="panel-title">Activity & Login History</span>
        <span class="panel-action">{{ activityEntries.length }} items</span>
      </div>

      <div class="responsive-table-scroll responsive-table-scroll--activity" style="overflow-x: auto">
        <table>
          <thead>
            <tr>
              <th>Type</th>
              <th>Reference ID</th>
              <th>Subject</th>
              <th>Date</th>
              <th>Current State</th>
              <th>Details / Note</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="item in activityEntries" :key="item.id">
              <td>
                <span style="font-weight: 700; font-size: 11px;">{{ item.type }}</span>
              </td>
              <td>
                <span style="font-family:'DM Mono',monospace; font-size:12px; color:var(--text-3)">{{ item.id }}</span>
              </td>
              <td style="font-weight: 600; font-size: 13px;">{{ item.title }}</td>
              <td style="font-size: 12px; color: var(--text-3)">{{ item.date }}</td>
              <td>
                <span :class="['tag', item.statusClass]">{{ item.statusLabel }}</span>
              </td>
              <td style="font-size: 12px; color: var(--text-2); max-width: 250px;">
                {{ item.details }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue';
import { useReports } from '../composables/useReports.js';
import { useRequests } from '../composables/useRequests.js';
import { useAuth } from '../composables/useAuth.js';

const { reports } = useReports();
const { requests } = useRequests();
const { activeUserName, currentRole, loginEvents } = useAuth();

const activityEntries = computed(() => {
  const user = activeUserName.value.toLowerCase();

  const userReports = reports.value
    .filter((r) => (r.reporter || '').toLowerCase() === user)
    .map((r) => ({
      id: r.trackingCode || r.id,
      type: 'REPORT',
      title: r.title,
      date: r.date,
      statusClass: r.status,
      statusLabel: r.status === 'in-progress' ? 'In Progress' : r.status,
      details: [r.desc || r.loc, r.adminRemark ? `Administrator remark: ${r.adminRemark}` : ''].filter(Boolean).join(' · ')
    }));

  const userRequests = requests.value
    .filter((req) => (req.requester || '').toLowerCase() === user)
    .map((req) => ({
      id: req.trackingCode || req.id,
      type: 'REQUEST',
      title: req.title,
      date: req.date,
      statusClass: req.status === 'action-taken' ? 'resolved' : 'pending',
      statusLabel: req.status === 'action-taken' ? 'Action Taken' : 'Submitted',
      details: [req.details, req.adminRemark ? `Administrator remark: ${req.adminRemark}` : '', req.adminResponse ? `Action taken: ${req.adminResponse}` : ''].filter(Boolean).join(' · ')
    }));

  const loginHistory = currentRole.value === 'Admin'
    ? loginEvents.value.map((event) => ({
        ...event,
        details: event.details || 'Successful sign in'
      }))
    : [];

  return [...userReports, ...userRequests, ...loginHistory].sort(
    (a, b) => (b.timestamp || 0) - (a.timestamp || 0)
  );
});
</script>
