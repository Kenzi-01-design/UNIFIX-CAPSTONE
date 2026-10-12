<template>
  <main class="facility-public-page">
    <header class="facility-public-header">
      <button class="public-back-button" type="button" @click="$emit('back')">
        <UiIcon name="arrow-left" :size="16" />
        <span>Back to UNIFIX</span>
      </button>
      <span class="facility-public-brand">UNIFIX · Campus Facility Status</span>
    </header>

    <section class="facility-public-hero">
      <span class="eyebrow">FACILITY STATUS</span>
      <h1>{{ facility ? facility.building : 'Facility issues' }}</h1>
      <p v-if="facility" class="facility-public-location">
        {{ [facility.floor, facility.room].filter(Boolean).join(' · ') || 'Nueva Vizcaya State University' }}
      </p>
      <p>See active maintenance reports and service requests for this facility.</p>
      <a v-if="facility" class="btn-primary facility-report-link" :href="reportUrl">
        Report an issue here
      </a>
    </section>

    <p v-if="loading && !facility" class="facility-public-state" role="status">Loading facility status…</p>
    <section v-else-if="error && !facility" class="facility-public-error" role="alert">
      <p>{{ error }}</p>
      <button class="btn-secondary" type="button" :disabled="loading" @click="loadIssues()">
        {{ loading ? 'Loading…' : 'Try again' }}
      </button>
    </section>
    <template v-else-if="facility">
      <section class="facility-public-summary" aria-label="Active issue totals">
        <article>
          <span>Open reports</span>
          <strong>{{ reportCount }}</strong>
        </article>
        <article>
          <span>Open requests</span>
          <strong>{{ requestCount }}</strong>
        </article>
      </section>

      <div class="facility-issue-grid">
        <section class="facility-issue-section">
          <header>
            <div>
              <h2>Current reports</h2>
              <p>Issues reported in this building</p>
            </div>
            <span class="facility-issue-count">{{ reportCount }}</span>
          </header>
          <div v-if="!reports.length" class="facility-issue-empty">No active reports for this facility.</div>
          <article v-for="(issue, index) in reports" :key="`${issue.title}-${issue.date}-${index}`" class="facility-issue-card">
            <div class="facility-issue-card-top">
              <span class="facility-issue-category">{{ issue.category || 'General' }}</span>
              <span :class="['facility-status', statusClass(issue.status)]">{{ formatStatus(issue.status) }}</span>
            </div>
            <h3>{{ issue.title }}</h3>
            <div class="facility-issue-meta">
              <span v-if="issue.risk && issue.risk !== 'low'" class="facility-issue-risk">{{ formatStatus(issue.risk) }} priority</span>
              <time>{{ issue.date || 'Date unavailable' }}</time>
            </div>
          </article>
        </section>

        <section class="facility-issue-section">
          <header>
            <div>
              <h2>Current service requests</h2>
              <p>Requests associated with this building</p>
            </div>
            <span class="facility-issue-count">{{ requestCount }}</span>
          </header>
          <div v-if="!requests.length" class="facility-issue-empty">No active service requests for this facility.</div>
          <article v-for="(issue, index) in requests" :key="`${issue.title}-${issue.date}-${index}`" class="facility-issue-card">
            <div class="facility-issue-card-top">
              <span class="facility-issue-category">{{ issue.category || 'General' }}</span>
              <span :class="['facility-status', statusClass(issue.status)]">{{ formatStatus(issue.status) }}</span>
            </div>
            <h3>{{ issue.title }}</h3>
            <div class="facility-issue-meta">
              <span v-if="issue.area">{{ issue.area }}</span>
              <span v-if="issue.risk && issue.risk !== 'low'" class="facility-issue-risk">{{ formatStatus(issue.risk) }} priority</span>
              <time>{{ issue.date || 'Date unavailable' }}</time>
            </div>
          </article>
        </section>
      </div>

      <div v-if="hasMore" class="facility-load-more">
        <button class="btn-secondary" type="button" :disabled="loading" @click="loadIssues(true)">
          {{ loading ? 'Loading…' : 'Load more issues' }}
        </button>
      </div>
      <section v-if="error" class="facility-public-error" role="alert">
        <p>{{ error }}</p>
        <button class="btn-secondary" type="button" :disabled="loading" @click="loadIssues(true)">
          {{ loading ? 'Loading…' : 'Try again' }}
        </button>
      </section>
    </template>
  </main>
</template>

<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import UiIcon from '../components/UiIcon.vue';
import { getPublicFacilityIssues, isDemoMode, isSupabaseConfigured } from '../lib/supabase.js';
import { useReports } from '../composables/useReports.js';
import { useRequests } from '../composables/useRequests.js';

const props = defineProps({
  locationId: { type: String, default: '' }
});
defineEmits(['back']);

const { reports: localReports } = useReports();
const { requests: localRequests } = useRequests();
const facility = ref(null);
const reports = ref([]);
const requests = ref([]);
const reportCount = ref(0);
const requestCount = ref(0);
const loading = ref(false);
const error = ref('');
const reportUrl = computed(() => `/report?location=${encodeURIComponent(props.locationId)}&new=1`);
const hasMore = computed(() => reports.value.length < reportCount.value || requests.value.length < requestCount.value);

function matchesBuilding(value, building) {
  const location = String(value || '').trim().toLowerCase();
  const prefix = String(building || '').trim().toLowerCase();
  return location === prefix || location.startsWith(`${prefix} · `);
}

function formatStatus(status) {
  return String(status || 'pending').replaceAll('-', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase());
}

function statusClass(status) {
  return String(status || 'pending').toLowerCase().replaceAll(' ', '-');
}

function localFacilityFeed() {
  const selectedLocation = localStorage.getItem('unifix-locations-v1');
  const locations = selectedLocation ? JSON.parse(selectedLocation) : [];
  const currentFacility = locations.find((location) => location.id === props.locationId && location.isActive);
  if (!currentFacility) return null;
  const open = (status) => !['closed', 'resolved', 'action-taken'].includes(String(status || '').toLowerCase());
  const facilityReports = localReports.value
    .filter((item) => matchesBuilding(item.loc, currentFacility.building) && open(item.status))
    .map((item) => ({ title: item.title, category: item.cat, status: item.status, risk: item.risk, date: item.date }));
  const facilityRequests = localRequests.value
    .filter((item) => matchesBuilding(item.dept, currentFacility.building) && open(item.status))
    .map((item) => ({ title: item.title, category: item.cat, status: item.status, risk: item.risk, date: item.date, area: item.dept }));
  return {
    facility: currentFacility,
    reports: facilityReports,
    requests: facilityRequests,
    reportCount: facilityReports.length,
    requestCount: facilityRequests.length
  };
}

async function loadIssues(append = false) {
  if (!props.locationId || loading.value) return;
  loading.value = true;
  error.value = '';
  if (!append) {
    reports.value = [];
    requests.value = [];
  }
  try {
    let data;
    if (isSupabaseConfigured) {
      data = await getPublicFacilityIssues(
        props.locationId,
        reports.value.length,
        requests.value.length,
        50
      );
    } else if (isDemoMode) {
      data = localFacilityFeed();
    } else {
      throw new Error('Facility status is temporarily unavailable.');
    }

    if (!data?.facility) throw new Error('This facility link is invalid or the location is no longer active.');
    facility.value = data.facility;
    reports.value = append ? [...reports.value, ...(data.reports || [])] : (data.reports || []);
    requests.value = append ? [...requests.value, ...(data.requests || [])] : (data.requests || []);
    reportCount.value = Number(data.reportCount || 0);
    requestCount.value = Number(data.requestCount || 0);
  } catch (caught) {
    error.value = caught.message || 'Facility status could not be loaded.';
  } finally {
    loading.value = false;
  }
}

watch(() => props.locationId, () => {
  facility.value = null;
  void loadIssues();
});

onMounted(() => {
  void loadIssues();
});
</script>

<style scoped>
.facility-public-page { width:min(1128px,100%); margin:0 auto; padding:24px 24px 48px; color:var(--text); }
.facility-public-header { display:flex; align-items:center; justify-content:space-between; gap:16px; margin-bottom:24px; }
.facility-public-header .public-back-button { margin-bottom:0; }
.facility-public-brand { color:var(--text-3); font-size:13px; font-weight:700; }
.facility-public-hero { padding:28px; border:1px solid var(--border); border-radius:16px; background:var(--surface); box-shadow:var(--shadow-sm); }
.facility-public-hero h1 { margin:8px 0; font-size:clamp(26px,4vw,38px); }
.facility-public-hero p { color:var(--text-2); line-height:1.6; }
.facility-public-location { font-weight:700; }
.facility-report-link { display:inline-flex; align-items:center; justify-content:center; min-height:44px; margin-top:8px; text-decoration:none; }
.facility-public-summary { display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:12px; margin:18px 0; }
.facility-public-summary article { display:flex; align-items:center; justify-content:space-between; padding:16px 18px; border:1px solid var(--border); border-radius:12px; background:var(--surface); }
.facility-public-summary span { color:var(--text-2); font-size:14px; font-weight:700; }
.facility-public-summary strong { font-size:24px; }
.facility-issue-grid { display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); align-items:start; gap:16px; }
.facility-issue-section { display:grid; gap:10px; min-width:0; }
.facility-issue-section > header { display:flex; align-items:center; justify-content:space-between; gap:12px; padding:4px 2px; }
.facility-issue-section h2 { margin:0; font-size:19px; }
.facility-issue-section header p { margin:4px 0 0; color:var(--text-3); font-size:13px; }
.facility-issue-count { display:grid; min-width:32px; height:32px; padding:0 8px; place-items:center; border-radius:999px; background:var(--surface); color:var(--primary); font-weight:800; }
.facility-issue-card,.facility-issue-empty { padding:16px; border:1px solid var(--border); border-radius:12px; background:var(--surface); }
.facility-issue-card h3 { margin:10px 0; font-size:16px; line-height:1.45; overflow-wrap:anywhere; }
.facility-issue-card-top,.facility-issue-meta { display:flex; align-items:center; justify-content:space-between; gap:8px; }
.facility-issue-card-top { flex-wrap:wrap; }
.facility-issue-category,.facility-issue-meta { color:var(--text-3); font-size:12px; }
.facility-issue-meta { flex-wrap:wrap; justify-content:flex-start; }
.facility-status { padding:4px 8px; border-radius:999px; background:var(--surface-2); color:var(--text-2); font-size:11px; font-weight:800; }
.facility-status.in-progress,.facility-status.assigned { background:#e7f4ec; color:#165c36; }
.facility-status.urgent,.facility-status.high { background:#fce8e6; color:#8a1c13; }
.facility-issue-risk { color:#9a4a00; font-weight:800; }
.facility-issue-empty,.facility-public-state,.facility-public-error { color:var(--text-2); }
.facility-public-error { padding:20px; border:1px solid var(--red); border-radius:12px; background:var(--surface); }
.facility-public-error p { line-height:1.5; }
.facility-load-more { display:flex; justify-content:center; margin-top:20px; }
@media(max-width:767px) {
  .facility-public-page { padding:16px 14px calc(32px + env(safe-area-inset-bottom)); }
  .facility-public-header { align-items:flex-start; flex-direction:column; gap:10px; margin-bottom:16px; }
  .facility-public-header .public-back-button { margin-bottom:0; }
  .facility-public-brand { padding-left:2px; }
  .facility-public-hero { padding:18px 16px; }
  .facility-report-link { width:100%; }
  .facility-public-summary { gap:8px; margin:14px 0; }
  .facility-public-summary article { align-items:flex-start; flex-direction:column-reverse; gap:6px; padding:12px 10px; }
  .facility-public-summary span { font-size:12px; line-height:1.35; }
  .facility-public-summary strong { font-size:21px; }
  .facility-issue-grid { grid-template-columns:1fr; }
  .facility-issue-section > header { align-items:flex-start; }
  .facility-issue-section h2 { font-size:17px; line-height:1.35; }
  .facility-issue-section header p { line-height:1.45; }
  .facility-issue-card,.facility-issue-empty { padding:14px; }
  .facility-issue-card-top,.facility-issue-meta { align-items:flex-start; }
  .facility-issue-meta time { overflow-wrap:anywhere; }
  .facility-load-more button,.facility-public-error button { min-height:44px; }
}
</style>
