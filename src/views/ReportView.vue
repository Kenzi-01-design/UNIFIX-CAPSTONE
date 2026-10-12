<template>
  <div class="view active" id="view-reports">
    <div class="filter-bar">
      <div class="search-wrap">
        <span class="search-icon"><UiIcon name="search" /></span>
        <input
          type="text"
          v-model="searchQuery"
          placeholder="Search by ID, title, category, or reporter..."
        />
      </div>

      <select v-model="filterCategory" class="filter-select">
        <option value="">All Categories</option>
        <option value="Electrical">Electrical</option>
        <option value="Plumbing">Plumbing</option>
        <option value="Furniture">Furniture</option>
        <option value="HVAC">HVAC</option>
        <option value="Network">Network</option>
        <option value="Civil">Civil / Structural</option>
        <option value="Security">Security</option>
      </select>

      <select v-model="filterStatus" class="filter-select">
        <option value="">All Status</option>
        <option value="pending">Pending</option>
        <option value="in-progress">In Progress</option>
        <option value="for-verification">For Verification</option>
        <option value="closed">Closed</option>
        <option value="resolved">Resolved</option>
        <option value="urgent">Urgent</option>
      </select>

      <select v-model="filterDate" class="filter-select">
        <option value="">All Dates</option>
        <option value="today">Today</option>
        <option value="week">This Week</option>
        <option value="month">This Month</option>
      </select>

      <!-- Scope Switcher for non-admin accounts -->
      <select v-if="!['Admin', 'Employee', 'Personnel'].includes(currentRole)" v-model="scopeFilter" class="filter-select">
        <option value="my">My Submissions</option>
        <option value="all">All Campus Reports</option>
      </select>
    </div>

    <div class="reports-cards" id="reports-container">
      <template v-if="filteredReports.length">
        <div
          v-for="r in filteredReports"
          :key="r.id"
          :class="['report-card', r.risk]"
          @click="$emit('open-report', r.id)"
        >
          <div class="rc-top">
            <div class="rc-cat">
              <div class="rc-cat-icon" :style="{ background: r.catBg || '#fff4e6' }">
                <UiIcon :name="r.cat" />
              </div>
              <div>
                <div class="rc-cat-name">{{ r.cat }}</div>
                <div style="font-size:10px;color:var(--text-3);font-family:'DM Mono',monospace">
                  {{ r.trackingCode || r.id }}
                </div>
              </div>
            </div>
            <span :class="['tag', r.status]">{{ formatStatus(r.status) }}</span>
          </div>

          <div class="rc-title">{{ r.title }}</div>
          <div class="rc-location"><UiIcon name="location" :size="15" /> {{ r.loc }}</div>

          <div class="rc-footer">
            <span class="rc-reporter">
              <UiIcon name="reporter" :size="15" /> {{ r.reporter }}{{ r.assignedTo ? ` · ${r.assignedTo}` : '' }}
            </span>
            <span :class="['tag', r.risk]">{{ capitalize(r.risk) }}</span>
            <span class="rc-date">{{ r.date }}</span>
          </div>
        </div>
      </template>

      <div v-else class="report-card low">
        <div class="rc-title">No matching reports found.</div>
        <div class="rc-location">Try clearing your search query or loosening filter settings.</div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch } from 'vue';
import { useReports } from '../composables/useReports.js';
import { useAuth } from '../composables/useAuth.js';
import UiIcon from '../components/UiIcon.vue';

const props = defineProps({
  initialFilter: {
    type: Object,
    default: () => ({})
  }
});

defineEmits(['open-report']);

const { reports, isAssignedTo } = useReports();
const { currentRole, activeUserName, activeUserEmail } = useAuth();

const searchQuery = ref(props.initialFilter.search || '');
const filterCategory = ref(props.initialFilter.category || '');
const filterStatus = ref(props.initialFilter.status || '');
const filterDate = ref(props.initialFilter.date || '');
const scopeFilter = ref(['Admin', 'Assistant', 'Personnel'].includes(currentRole.value) ? 'all' : 'my');

function isCurrentUsersReport(report) {
  if (report.reporterEmail && activeUserEmail.value) {
    return report.reporterEmail.toLowerCase() === activeUserEmail.value.toLowerCase();
  }
  return report.reporter === activeUserName.value;
}

watch(
  () => props.initialFilter,
  (newVal) => {
    if (newVal.category !== undefined) filterCategory.value = newVal.category;
    if (newVal.status !== undefined) filterStatus.value = newVal.status;
    if (newVal.date !== undefined) filterDate.value = newVal.date;
    if (newVal.search !== undefined) searchQuery.value = newVal.search;
  },
  { deep: true }
);

function parseReportDate(dateStr) {
  const d = new Date(dateStr);
  return isNaN(d.getTime()) ? null : d;
}

function matchesDate(dateStr) {
  if (!filterDate.value) return true;
  const target = parseReportDate(dateStr);
  if (!target) return true;

  const now = new Date();
  const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const targetDay = new Date(target.getFullYear(), target.getMonth(), target.getDate());

  const oneDay = 86400000;
  const diff = now.getTime() - target.getTime();

  if (filterDate.value === 'today') return targetDay.getTime() === startOfToday.getTime();
  if (filterDate.value === 'week') return diff >= 0 && diff <= 7 * oneDay;
  if (filterDate.value === 'month') return diff >= 0 && diff <= 31 * oneDay;
  return true;
}

const filteredReports = computed(() => {
  const q = searchQuery.value.trim().toLowerCase();

  return reports.value.filter((r) => {
    if (currentRole.value === 'Personnel' && !isAssignedTo(r, activeUserName.value)) {
      return false;
    }
    if (currentRole.value === 'Employee' && !isCurrentUsersReport(r)) {
      return false;
    }
    if (scopeFilter.value === 'my' && !isCurrentUsersReport(r)) {
      return false;
    }

    if (filterCategory.value && !r.cat.toLowerCase().includes(filterCategory.value.toLowerCase())) {
      return false;
    }

    if (filterStatus.value && r.status.toLowerCase() !== filterStatus.value.toLowerCase()) {
      return false;
    }

    if (q) {
      const haystack = `${r.id} ${r.trackingCode || ''} ${r.title} ${r.loc} ${r.cat} ${r.reporter} ${r.assignedTo || ''}`.toLowerCase();
      if (!haystack.includes(q)) return false;
    }

    if (!matchesDate(r.date)) return false;

    return true;
  }).sort((a, b) => new Date(b.updatedAt || b.date || 0) - new Date(a.updatedAt || a.date || 0));
});

function formatStatus(status) {
  if (!status) return '';
  return String(status).replaceAll('-', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase());
}

function capitalize(str) {
  if (!str) return '';
  return str.charAt(0).toUpperCase() + str.slice(1);
}
</script>

<style scoped>
</style>
