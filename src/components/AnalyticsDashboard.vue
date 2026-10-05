<template>
  <section class="analytics-dashboard panel" aria-labelledby="analytics-title">
    <div class="analytics-heading">
      <div>
        <span class="eyebrow">Operations insight</span>
        <h2 id="analytics-title">Service performance</h2>
        <p>Reports and requests in the selected period.</p>
      </div>
      <div class="analytics-actions">
        <button type="button" class="btn-secondary" :disabled="loading" @click="exportCsv">Export CSV</button>
        <button type="button" class="btn-secondary" :disabled="loading || !data" @click="printSummary">Print / PDF</button>
      </div>
    </div>

    <div class="analytics-filters">
      <label>From <input v-model="fromDate" type="date" :max="toDate" @change="loadAnalytics" /></label>
      <label>To <input v-model="toDate" type="date" :min="fromDate" @change="loadAnalytics" /></label>
      <label>Category
        <select v-model="category" @change="loadAnalytics">
          <option value="">All categories</option>
          <option v-for="item in categories" :key="item" :value="item">{{ item }}</option>
        </select>
      </label>
      <button type="button" class="btn-primary" :disabled="loading" @click="loadAnalytics">
        {{ loading ? 'Loading…' : 'Apply filters' }}
      </button>
    </div>

    <div v-if="error" class="analytics-state analytics-error" role="alert">
      <strong>Analytics could not be loaded.</strong>
      <span>{{ error }}</span>
      <button type="button" class="btn-secondary" @click="loadAnalytics">Retry</button>
    </div>
    <div v-else-if="loading && !data" class="analytics-state" role="status">Loading service performance…</div>
    <div v-else-if="!data" class="analytics-state">No analytics are available for this period.</div>
    <template v-else>
      <div class="analytics-kpis">
        <article v-for="item in kpis" :key="item.label" class="analytics-kpi" :class="item.tone">
          <span>{{ item.label }}</span>
          <strong>{{ item.value }}</strong>
        </article>
      </div>

      <div class="analytics-charts">
        <article class="analytics-chart-card">
          <h3>Reports by category</h3>
          <div v-if="!data.categories.length" class="analytics-chart-empty">No records in this range.</div>
          <div v-for="item in bars(data.categories)" :key="item.name" class="analytics-bar-row">
            <span :title="item.name">{{ item.name }}</span>
            <div class="analytics-bar-track"><i :style="{ width: `${item.percent}%` }"></i></div>
            <b>{{ item.count }}</b>
          </div>
        </article>
        <article class="analytics-chart-card">
          <h3>Priority distribution</h3>
          <div v-if="!data.priorities.length" class="analytics-chart-empty">No records in this range.</div>
          <div v-for="item in bars(data.priorities)" :key="item.name" class="analytics-bar-row">
            <span>{{ item.name || 'Unspecified' }}</span>
            <div class="analytics-bar-track priority"><i :style="{ width: `${item.percent}%` }"></i></div>
            <b>{{ item.count }}</b>
          </div>
        </article>
        <article class="analytics-chart-card">
          <h3>Top recurring locations</h3>
          <div v-if="!data.locations.length" class="analytics-chart-empty">No records in this range.</div>
          <div v-for="item in bars(data.locations)" :key="item.name" class="analytics-bar-row">
            <span :title="item.name">{{ item.name }}</span>
            <div class="analytics-bar-track"><i :style="{ width: `${item.percent}%` }"></i></div>
            <b>{{ item.count }}</b>
          </div>
        </article>
        <article class="analytics-chart-card">
          <h3>Submission trend</h3>
          <div v-if="!data.trend.length" class="analytics-chart-empty">No records in this range.</div>
          <div v-else class="analytics-trend" aria-label="Daily submissions">
            <div v-for="item in trendBars" :key="item.name" :title="`${item.name}: ${item.count}`">
              <i :style="{ height: `${item.percent}%` }"></i>
            </div>
          </div>
          <div v-if="data.trend.length" class="analytics-trend-labels">
            <span>{{ data.trend[0].date }}</span><span>{{ data.trend[data.trend.length - 1].date }}</span>
          </div>
        </article>
        <article class="analytics-chart-card analytics-workload">
          <h3>Personnel workload</h3>
          <div v-if="!data.personnel.length" class="analytics-chart-empty">No assigned work in this range.</div>
          <div v-for="item in data.personnel" :key="item.name" class="analytics-person-row">
            <strong>{{ item.name }}</strong>
            <div class="analytics-workload-track" :title="`${item.open} open, ${item.completed} completed`">
              <i :style="{ width: `${workloadWidth(item)}%` }"></i>
            </div>
            <small>{{ item.open }} open · {{ item.completed }} completed</small>
          </div>
        </article>
      </div>
      <p class="analytics-footnote">SLA compliance is based on completed work with a recorded deadline. Rework rate is the share of work items rejected at least once.</p>
    </template>
  </section>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue';
import { isDemoMode, isSupabaseConfigured, supabase } from '../lib/supabase.js';
import { useReports } from '../composables/useReports.js';
import { useRequests } from '../composables/useRequests.js';
import { useReportFeedback } from '../composables/useReportFeedback.js';

const { reports } = useReports();
const { requests } = useRequests();
const { feedback, loadReportFeedback } = useReportFeedback();
const loading = ref(false);
const error = ref('');
const data = ref(null);
const today = new Date();
const toDate = ref(today.toISOString().slice(0, 10));
const fromDate = ref(new Date(today.getTime() - 364 * 86400000).toISOString().slice(0, 10));
const category = ref('');
let requestId = 0;

const categories = computed(() => [...new Set([
  ...reports.value.map((item) => item.cat),
  ...requests.value.map((item) => item.cat)
].filter(Boolean))].sort());

function isClosed(status) {
  return ['closed', 'resolved', 'action-taken'].includes(status);
}

function parseDate(value) {
  const parsed = new Date(value || '');
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function inPeriod(value) {
  const parsed = parseDate(value);
  return parsed && parsed.toISOString().slice(0, 10) >= fromDate.value
    && parsed.toISOString().slice(0, 10) <= toDate.value;
}

function localAnalytics() {
  const all = [
    ...reports.value.map((item) => ({ ...item, category: item.cat, location: item.loc, assignees: item.assignedPersonnel || (item.assignedTo ? item.assignedTo.split(',').map((name) => name.trim()) : []) })),
    ...requests.value.map((item) => ({ ...item, category: item.cat, location: item.dept, assignees: item.assignedPersonnel || (item.assignedTo ? item.assignedTo.split(',').map((name) => name.trim()) : []) }))
  ];
  const rows = all.filter((item) => inPeriod(item.date) && (!category.value || item.category === category.value));
  const active = rows.filter((item) => !isClosed(item.status));
  const completed = all.filter((item) => inPeriod(item.completedAt) && (!category.value || item.category === category.value));
  const elapsed = rows.map((item) => {
    const created = parseDate(item.date);
    const done = parseDate(item.completedAt);
    return created && done && done >= created ? (done - created) / 86400000 : null;
  }).filter((value) => value !== null);
  const feedbackRows = feedback.value.filter((item) => {
    const report = reports.value.find((candidate) => candidate.id === item.report_id);
    return report && inPeriod(report.date) && (!category.value || report.cat === category.value);
  });
  const countBy = (key) => Object.entries(rows.reduce((result, item) => {
    const name = item[key] || 'Unspecified';
    result[name] = (result[name] || 0) + 1;
    return result;
  }, {})).map(([name, count]) => ({ name, count })).sort((a, b) => b.count - a.count);
  const trend = Object.entries(rows.reduce((result, item) => {
    const date = parseDate(item.date)?.toISOString().slice(0, 10);
    if (date) result[date] = (result[date] || 0) + 1;
    return result;
  }, {})).map(([date, count]) => ({ date, count })).sort((a, b) => a.date.localeCompare(b.date));
  const assigned = new Map();
  rows.forEach((item) => item.assignees.filter(Boolean).forEach((name) => {
    const value = assigned.get(name) || { name, open: 0, completed: 0 };
    value[isClosed(item.status) ? 'completed' : 'open'] += 1;
    assigned.set(name, value);
  }));
  const doneWithSla = completed.filter((item) => item.dueAt && item.completedAt);
  return {
    stats: {
      total: rows.length,
      open: active.length,
      overdue: active.filter((item) => item.dueAt && new Date(item.dueAt) < new Date()).length,
      completed: completed.length,
      avgResolutionDays: elapsed.length ? Math.round(elapsed.reduce((sum, value) => sum + value, 0) / elapsed.length * 100) / 100 : null,
      slaCompliance: doneWithSla.length ? Math.round(doneWithSla.filter((item) => new Date(item.completedAt) <= new Date(item.dueAt)).length / doneWithSla.length * 1000) / 10 : 0,
      averageRating: feedbackRows.length ? Math.round(feedbackRows.reduce((sum, item) => sum + Number(item.rating), 0) / feedbackRows.length * 100) / 100 : null,
      reworkRate: rows.length ? Math.round(rows.filter((item) => Number(item.reworkCount) > 0).length / rows.length * 1000) / 10 : 0
    },
    categories: countBy('category'),
    locations: countBy('location').slice(0, 10),
    trend,
    priorities: countBy('priority'),
    personnel: [...assigned.values()].sort((a, b) => b.open - a.open)
  };
}

async function loadAnalytics() {
  const currentRequest = ++requestId;
  loading.value = true;
  error.value = '';
  try {
    if (fromDate.value > toDate.value) throw new Error('The start date must not be after the end date.');
    if (isSupabaseConfigured && !isDemoMode) {
      const { data: result, error: rpcError } = await supabase.rpc('get_unifix_analytics', {
        p_from_date: fromDate.value,
        p_to_date: toDate.value,
        p_category: category.value || null
      });
      if (rpcError) throw rpcError;
      if (currentRequest === requestId) data.value = result;
    } else {
      await loadReportFeedback();
      if (currentRequest === requestId) data.value = localAnalytics();
    }
  } catch (caught) {
    if (currentRequest === requestId) {
      error.value = caught.message || 'Unable to load analytics.';
      console.error('Failed to load analytics.', caught);
    }
  } finally {
    if (currentRequest === requestId) loading.value = false;
  }
}

function bars(items = []) {
  const max = Math.max(...items.map((item) => Number(item.count) || 0), 1);
  return items.map((item) => ({ ...item, percent: Math.max(4, Math.round(Number(item.count) / max * 100)) }));
}

const trendBars = computed(() => {
  const max = Math.max(...(data.value?.trend || []).map((item) => Number(item.count) || 0), 1);
  return (data.value?.trend || []).map((item) => ({ ...item, percent: Math.max(5, Math.round(Number(item.count) / max * 100)) }));
});

function workloadWidth(item) {
  const max = Math.max(...(data.value?.personnel || []).map((row) => Number(row.open) + Number(row.completed)), 1);
  return Math.max(4, Math.round((Number(item.open) + Number(item.completed)) / max * 100));
}

const kpis = computed(() => {
  const stats = data.value?.stats || {};
  return [
    { label: 'Total work items', value: stats.total ?? 0, tone: 'blue' },
    { label: 'Open', value: stats.open ?? 0, tone: 'orange' },
    { label: 'Overdue', value: stats.overdue ?? 0, tone: 'red' },
    { label: 'Completed in period', value: stats.completed ?? 0, tone: 'green' },
    { label: 'Avg. resolution', value: stats.avgResolutionDays == null ? '—' : `${stats.avgResolutionDays} d`, tone: 'blue' },
    { label: 'SLA compliance', value: `${stats.slaCompliance ?? 0}%`, tone: 'green' },
    { label: 'Average rating', value: stats.averageRating == null ? '—' : `${stats.averageRating} / 5`, tone: 'orange' },
    { label: 'Rework rate', value: `${stats.reworkRate ?? 0}%`, tone: 'red' }
  ];
});

function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, (character) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
  })[character]);
}

function download(filename, content, type) {
  const link = document.createElement('a');
  link.href = URL.createObjectURL(new Blob([content], { type }));
  link.download = filename;
  link.click();
  URL.revokeObjectURL(link.href);
}

function exportCsv() {
  if (!data.value) return;
  const rows = [
    ['Metric', 'Value'],
    ...kpis.value.map((item) => [item.label, item.value]),
    [],
    ['Category', 'Count'],
    ...(data.value.categories || []).map((item) => [item.name, item.count]),
    [],
    ['Priority', 'Count'],
    ...(data.value.priorities || []).map((item) => [item.name, item.count]),
    [],
    ['Location', 'Count'],
    ...(data.value.locations || []).map((item) => [item.name, item.count]),
    [],
    ['Date', 'Submissions'],
    ...(data.value.trend || []).map((item) => [item.date, item.count]),
    [],
    ['Personnel', 'Open', 'Completed'],
    ...(data.value.personnel || []).map((item) => [item.name, item.open, item.completed])
  ];
  const csv = rows.map((row) => row.map((value) => `"${String(value ?? '').replaceAll('"', '""')}"`).join(',')).join('\r\n');
  download('unifix-analytics.csv', csv, 'text/csv;charset=utf-8');
}

function printSummary() {
  if (!data.value) return;
  const printWindow = window.open('', '_blank');
  if (!printWindow) {
    error.value = 'The print window was blocked. Allow pop-ups and try again.';
    return;
  }
  printWindow.opener = null;
  const kpiRows = kpis.value.map((item) => `<tr><th>${escapeHtml(item.label)}</th><td>${escapeHtml(item.value)}</td></tr>`).join('');
  const categoryRows = (data.value.categories || []).map((item) => `<tr><td>${escapeHtml(item.name)}</td><td>${escapeHtml(item.count)}</td></tr>`).join('');
  const priorityRows = (data.value.priorities || []).map((item) => `<tr><td>${escapeHtml(item.name)}</td><td>${escapeHtml(item.count)}</td></tr>`).join('');
  const locationRows = (data.value.locations || []).map((item) => `<tr><td>${escapeHtml(item.name)}</td><td>${escapeHtml(item.count)}</td></tr>`).join('');
  const trendRows = (data.value.trend || []).map((item) => `<tr><td>${escapeHtml(item.date)}</td><td>${escapeHtml(item.count)}</td></tr>`).join('');
  const personnelRows = (data.value.personnel || []).map((item) => `<tr><td>${escapeHtml(item.name)}</td><td>${escapeHtml(item.open)}</td><td>${escapeHtml(item.completed)}</td></tr>`).join('');
  printWindow.document.write(`<!doctype html><html><head><title>UNIFIX Analytics Summary</title><style>
    body{font:14px Arial,sans-serif;color:#18231d;margin:28px}h1{color:#0f6b3d;margin:0 0 6px}
    p{color:#52635a;margin:0 0 22px}h2{font-size:16px;margin:24px 0 8px}
    table{border-collapse:collapse;width:100%;margin-bottom:16px}th,td{border:1px solid #cbd5ce;padding:8px;text-align:left}
    th{background:#edf4ef}@media print{body{margin:16mm}}
    </style></head><body><h1>UNIFIX Service Performance</h1>
    <p>${escapeHtml(fromDate.value)} to ${escapeHtml(toDate.value)}${category.value ? ` · ${escapeHtml(category.value)}` : ' · All categories'}</p>
    <h2>Key performance indicators</h2><table>${kpiRows}</table>
    <h2>Reports by category</h2><table><tr><th>Category</th><th>Count</th></tr>${categoryRows}</table>
    <h2>Priority distribution</h2><table><tr><th>Priority</th><th>Count</th></tr>${priorityRows}</table>
    <h2>Top recurring locations</h2><table><tr><th>Location</th><th>Count</th></tr>${locationRows}</table>
    <h2>Submission trend</h2><table><tr><th>Date</th><th>Submissions</th></tr>${trendRows}</table>
    <h2>Personnel workload</h2><table><tr><th>Personnel</th><th>Open</th><th>Completed</th></tr>${personnelRows}</table>
    <script>window.onload=()=>window.print()<\/script></body></html>`);
  printWindow.document.close();
}

onMounted(() => { void loadAnalytics(); });
</script>

<style scoped>
.analytics-dashboard { margin-bottom: 22px; padding: 22px; }
.analytics-heading,.analytics-actions,.analytics-filters { display:flex; align-items:center; justify-content:space-between; gap:12px; flex-wrap:wrap; }
.analytics-heading h2 { margin:3px 0; color:var(--text); font-size:21px; }
.analytics-heading p,.analytics-footnote { color:var(--text-3); font-size:12px; }
.analytics-actions button,.analytics-filters button { margin-top:0; }
.analytics-filters { justify-content:flex-start; margin:20px 0; padding:14px; border:1px solid var(--border); border-radius:var(--radius-sm); background:var(--surface-2); }
.analytics-filters label { display:grid; gap:4px; color:var(--text-2); font-size:11px; font-weight:700; }
.analytics-filters input,.analytics-filters select { min-height:38px; padding:7px 9px; border:1px solid var(--border-dark); border-radius:6px; background:var(--surface); color:var(--text); font:inherit; }
.analytics-kpis { display:grid; grid-template-columns:repeat(4,minmax(0,1fr)); gap:10px; }
.analytics-kpi { display:grid; gap:8px; padding:14px; border:1px solid var(--border); border-left:4px solid var(--primary); border-radius:9px; background:var(--surface-2); }
.analytics-kpi span { color:var(--text-3); font-size:11px; font-weight:700; }
.analytics-kpi strong { color:var(--text); font-size:24px; line-height:1.1; }
.analytics-kpi.orange { border-left-color:var(--accent); }.analytics-kpi.red { border-left-color:var(--red); }.analytics-kpi.green { border-left-color:var(--green); }
.analytics-charts { display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:12px; margin-top:14px; }
.analytics-chart-card { min-width:0; padding:16px; border:1px solid var(--border); border-radius:10px; background:var(--surface); }
.analytics-chart-card h3 { margin-bottom:12px; font-size:13px; }
.analytics-bar-row { display:grid; grid-template-columns:minmax(70px,32%) 1fr 28px; align-items:center; gap:8px; margin:8px 0; font-size:11px; }
.analytics-bar-row>span { overflow:hidden; color:var(--text-2); text-overflow:ellipsis; white-space:nowrap; }
.analytics-bar-row>b { text-align:right; }.analytics-bar-track,.analytics-workload-track { height:9px; overflow:hidden; border-radius:10px; background:var(--surface-3); }
.analytics-bar-track i,.analytics-workload-track i { display:block; height:100%; border-radius:inherit; background:var(--primary-light); }
.analytics-bar-track.priority i { background:var(--accent-light); }
.analytics-trend { display:flex; height:128px; align-items:flex-end; gap:3px; padding:8px 0; border-bottom:1px solid var(--border); }
.analytics-trend>div { display:flex; height:100%; min-width:3px; flex:1; align-items:flex-end; }
.analytics-trend i { display:block; width:100%; min-height:3px; border-radius:3px 3px 0 0; background:var(--primary-light); }
.analytics-trend-labels { display:flex; justify-content:space-between; margin-top:6px; color:var(--text-3); font-size:10px; }
.analytics-person-row { display:grid; grid-template-columns:minmax(90px,28%) 1fr; gap:5px 10px; align-items:center; margin:9px 0; font-size:11px; }
.analytics-person-row>strong { overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
.analytics-person-row small { grid-column:2; color:var(--text-3); }
.analytics-workload-track i { background:var(--accent-light); }
.analytics-chart-empty { padding:24px 8px; color:var(--text-3); font-size:12px; text-align:center; }
.analytics-state { display:grid; justify-items:start; gap:8px; padding:22px; color:var(--text-2); font-size:13px; }
.analytics-error { border:1px solid #f2c5c5; border-radius:9px; background:var(--red-bg); color:var(--red); }
.analytics-footnote { margin-top:12px; }
@media(max-width:800px){.analytics-kpis{grid-template-columns:repeat(2,minmax(0,1fr))}.analytics-charts{grid-template-columns:1fr}}
@media(max-width:480px){.analytics-dashboard{padding:14px}.analytics-kpi strong{font-size:20px}.analytics-heading{align-items:flex-start}.analytics-filters label{width:100%}.analytics-filters input,.analytics-filters select{width:100%}}
</style>
