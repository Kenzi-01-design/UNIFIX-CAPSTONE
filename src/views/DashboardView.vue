<template>
  <div class="view active" id="view-dashboard">
    <!-- Analytics are available to administrators only. -->
    <div v-if="currentRole === 'Admin'" class="stats-grid">
      <div class="stat-card blue" @click="$emit('filter-reports', {})">
        <div class="stat-header">
          <span class="stat-label">Total Reports</span>
          <div class="stat-icon"><UiIcon name="analytics" /></div>
        </div>
        <div class="stat-value">{{ totalCount }}</div>
        <div class="stat-delta up">↑ Active tracking</div>
      </div>

      <div class="stat-card orange" @click="$emit('filter-reports', { status: 'pending' })">
        <div class="stat-header">
          <span class="stat-label">Pending</span>
          <div class="stat-icon"><UiIcon name="work" /></div>
        </div>
        <div class="stat-value">{{ pendingCount }}</div>
        <div class="stat-delta down">Awaiting review</div>
      </div>

      <div class="stat-card green" @click="$emit('filter-reports', { status: 'resolved' })">
        <div class="stat-header">
          <span class="stat-label">Resolved</span>
          <div class="stat-icon"><UiIcon name="work" /></div>
        </div>
        <div class="stat-value">{{ resolvedCount }}</div>
        <div class="stat-delta up">{{ resolvedPercentage }}% resolved</div>
      </div>

      <div class="stat-card red" @click="$emit('filter-reports', { status: 'urgent' })">
        <div class="stat-header">
          <span class="stat-label">Urgent</span>
          <div class="stat-icon"><UiIcon name="work" /></div>
        </div>
        <div class="stat-value">{{ urgentCount }}</div>
        <div class="stat-delta down">Needs immediate action</div>
      </div>
    </div>

    <section v-if="currentRole !== 'Admin'" class="role-dashboard-intro">
      <div>
        <span class="eyebrow">{{ currentRole === 'Personnel' ? 'Maintenance workspace' : 'Campus services' }}</span>
        <h2>{{ currentRole === 'Personnel' ? 'Your assigned work, at a glance.' : 'Keep your campus moving.' }}</h2>
        <p>{{ currentRole === 'Personnel' ? 'Review your queue and keep every repair moving forward.' : 'Report an issue or check the progress of something you have already raised.' }}</p>
      </div>
      <div class="dashboard-intro-mark"><UiIcon :name="currentRole === 'Personnel' ? 'tasks' : 'building'" :size="42" /></div>
    </section>

    <div v-if="currentRole !== 'Admin'" class="quick-actions-grid">
      <button v-if="currentRole !== 'Employee'" class="quick-action primary" @click="$emit('navigate', 'submit')">
        <span class="quick-action-icon"><UiIcon name="add" /></span>
        <span><strong>{{ currentRole === 'Personnel' ? 'Report an Issue' : 'Submit a Report' }}</strong><small>Tell maintenance what needs attention</small></span>
        <span class="quick-action-arrow">→</span>
      </button>
      <button v-if="currentRole === 'Employee'" class="quick-action" @click="$emit('navigate', 'submit-request')">
        <span class="quick-action-icon"><UiIcon name="request" /></span>
        <span><strong>Submit a Request</strong><small>Open a facilities requisition</small></span>
        <span class="quick-action-arrow">→</span>
      </button>
      <button v-if="currentRole === 'Personnel'" class="quick-action" @click="$emit('navigate', 'tasks')">
        <span class="quick-action-icon"><UiIcon name="tasks" /></span>
        <span><strong>Open Tasks</strong><small>View and update assigned repairs</small></span>
        <span class="quick-action-arrow">→</span>
      </button>
      <button class="quick-action" @click="$emit('navigate', 'reports')">
        <span class="quick-action-icon"><UiIcon name="reports" /></span>
        <span><strong>Browse Reports</strong><small>Find reported campus issues</small></span>
        <span class="quick-action-arrow">→</span>
      </button>
    </div>

    <div v-if="currentRole !== 'Admin'" class="work-summary-grid">
      <div v-for="item in workSummary" :key="item.label" class="work-summary-card" :class="item.tone">
        <span class="work-summary-icon"><UiIcon :name="item.icon" /></span>
        <strong>{{ item.value }}</strong>
        <span>{{ item.label }}</span>
      </div>
    </div>

    <!-- Main Content Panels (Recent Reports & Category Breakdown) -->
    <div class="grid-2">
      <div v-if="currentRole === 'Admin'" class="panel">
        <div class="panel-header">
          <span class="panel-title">Recent Reports</span>
          <span class="panel-action" @click="$emit('navigate', 'reports')">View all →</span>
        </div>
        <div class="report-list">
          <div
            v-for="report in recentReports"
            :key="report.id"
            class="report-row"
            @click="$emit('open-report', report.id)"
          >
            <div class="report-cat-icon" :style="{ background: report.catBg || '#f0f0f0' }">
              <UiIcon :name="report.cat" />
            </div>
            <div class="report-info">
              <div class="title">{{ report.title }}</div>
              <div class="meta">{{ report.loc }}</div>
            </div>
            <span :class="['tag', report.status]">{{ formatStatus(report.status) }}</span>
          </div>
        </div>
      </div>

      <div v-if="currentRole === 'Admin'" class="panel">
        <div class="panel-header">
          <span class="panel-title">Reports By Category</span>
          <span class="panel-action">Volume Breakdown</span>
        </div>
        <div class="mini-chart">
          <div class="chart-bars">
            <div
              v-for="cat in categoryBars"
              :key="cat.name"
              class="bar-wrap"
              :class="{ accent: cat.accent }"
            >
              <div
                class="bar"
                :style="{ height: `${cat.heightPercent}%` }"
                :title="`${cat.name}: ${cat.count}`"
                @click="$emit('filter-reports', { category: cat.name })"
              ></div>
              <span class="bar-label">{{ cat.label }}</span>
            </div>
          </div>
        </div>

        <div style="padding: 0 22px 18px">
          <div style="font-size: 12px; color: var(--text-3); margin-bottom: 10px; font-weight: 600;">
            Maintenance Operations Overview
          </div>
          <div style="display: flex; gap: 16px">
            <div style="flex: 1; background: var(--surface-2); border-radius: var(--radius-sm); padding: 12px; text-align: center;">
              <div style="font-size: 22px; font-weight: 800; color: var(--primary); letter-spacing: -1px;">
                2.4
              </div>
              <div style="font-size: 11px; color: var(--text-3); font-weight: 600;">
                days avg
              </div>
            </div>
            <div style="flex: 1; background: var(--surface-2); border-radius: var(--radius-sm); padding: 12px; text-align: center;">
              <div style="font-size: 22px; font-weight: 800; color: var(--green); letter-spacing: -1px;">
                {{ resolvedPercentage }}%
              </div>
              <div style="font-size: 11px; color: var(--text-3); font-weight: 600;">
                resolved
              </div>
            </div>
            <div style="flex: 1; background: var(--surface-2); border-radius: var(--radius-sm); padding: 12px; text-align: center;">
              <div style="font-size: 22px; font-weight: 800; color: var(--accent); letter-spacing: -1px;">
                {{ technicians.length }}
              </div>
              <div style="font-size: 11px; color: var(--text-3); font-weight: 600;">
                active staff
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue';
import { useReports } from '../composables/useReports.js';
import { useRequests } from '../composables/useRequests.js';
import { useAuth } from '../composables/useAuth.js';
import UiIcon from '../components/UiIcon.vue';

const props = defineProps({
  currentRole: {
    type: String,
    default: 'Faculty'
  }
});

defineEmits(['navigate', 'open-report', 'filter-reports']);

const { reports, technicians, isAssignedTo } = useReports();
const { requests } = useRequests();
const { activeUserName } = useAuth();

const myReports = computed(() => reports.value.filter((report) => report.reporter === activeUserName.value));
const assignedReports = computed(() => reports.value.filter((report) => isAssignedTo(report, activeUserName.value)));
const roleRecentReports = computed(() => (props.currentRole === 'Personnel' ? assignedReports.value : myReports.value).slice(0, 5));

const workSummary = computed(() => {
  if (props.currentRole === 'Personnel') {
    return [
      { label: 'Assigned repairs', value: assignedReports.value.filter((report) => report.status !== 'resolved').length, icon: 'tasks', tone: 'blue' },
      { label: 'Waiting acceptance', value: assignedReports.value.filter((report) => report.techState === 'assigned').length, icon: 'work', tone: 'orange' },
      { label: 'In progress', value: assignedReports.value.filter((report) => ['accepted', 'started'].includes(report.techState)).length, icon: 'work', tone: 'green' }
    ];
  }

  return [
    { label: 'My open reports', value: myReports.value.filter((report) => report.status !== 'resolved').length, icon: 'report', tone: 'blue' },
    { label: 'Resolved reports', value: myReports.value.filter((report) => report.status === 'resolved').length, icon: 'work', tone: 'green' },
    { label: 'Pending requests', value: requests.value.filter((request) => request.requester === activeUserName.value && request.status === 'submitted').length, icon: 'request', tone: 'orange' }
  ];
});

const totalCount = computed(() => reports.value.length);

const pendingCount = computed(() => reports.value.filter(r => r.status === 'pending').length);
const resolvedCount = computed(() => reports.value.filter(r => r.status === 'resolved').length);
const urgentCount = computed(() => reports.value.filter(r => r.status === 'urgent').length);
const inProgressCount = computed(() => reports.value.filter(r => r.status === 'in-progress').length);

const resolvedPercentage = computed(() => {
  if (!totalCount.value) return 0;
  return Math.round((resolvedCount.value / totalCount.value) * 100);
});

const recentReports = computed(() => reports.value.slice(0, 5));

const categoriesTracked = [
  { name: 'Electrical', label: 'Elec' },
  { name: 'Plumbing', label: 'Plumb', accent: true },
  { name: 'Furniture', label: 'Furn' },
  { name: 'HVAC', label: 'HVAC' },
  { name: 'Network', label: 'Net', accent: true },
  { name: 'Civil', label: 'Civil' },
  { name: 'Other', label: 'Other' }
];

const categoryBars = computed(() => {
  const counts = categoriesTracked.map(cat => {
    const count = reports.value.filter(r =>
      r.cat.toLowerCase().includes(cat.name.toLowerCase())
    ).length;
    return { ...cat, count };
  });
  const max = Math.max(...counts.map(c => c.count), 1);
  return counts.map(c => ({
    ...c,
    heightPercent: Math.max(Math.round((c.count / max) * 100), 10)
  }));
});

function formatStatus(status) {
  if (!status) return '';
  return status === 'in-progress' ? 'In Progress' : status.charAt(0).toUpperCase() + status.slice(1);
}
</script>
