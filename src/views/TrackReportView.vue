<template>
  <main class="tracking-page">
    <button class="back-link" type="button" @click="$emit('back')">← Back to home</button>
    <section class="tracking-card">
      <span class="eyebrow">PUBLIC STATUS LOOKUP</span>
      <h1>Track a report or request</h1>
      <p class="tracking-intro">Enter the UNIFIX tracking code shown when your report or request was submitted.</p>
      <form class="tracking-form" @submit.prevent="lookup">
        <label for="tracking-code">Tracking code</label>
        <div class="tracking-form-row">
          <input
            id="tracking-code"
            v-model="codeDraft"
            maxlength="32"
            autocomplete="off"
            placeholder="UNI-2026-0042"
            required
          />
          <button class="btn-primary" type="submit" :disabled="loading">
            {{ loading ? 'Searching…' : 'Track status' }}
          </button>
        </div>
      </form>

      <p v-if="error" class="tracking-error" role="alert">{{ error }}</p>
      <p v-else-if="loading" class="tracking-loading" aria-live="polite">Looking up your report securely…</p>
      <p v-else-if="hasSearched && !result" class="tracking-empty">No report is currently displayed. Check the code and try again.</p>

      <article v-if="result" class="tracking-result">
        <div class="tracking-result-heading">
          <div>
            <span class="tracking-code">{{ result.trackingCode }}</span>
            <h2>{{ result.status }}</h2>
          </div>
          <span class="status-pill">{{ result.status }}</span>
        </div>
        <p class="last-updated">Last updated: {{ formatDate(result.lastUpdated) }}</p>
        <p v-if="result.assignedTeam" class="assigned-team">
          Assigned team: <strong>{{ result.assignedTeam }}</strong>
        </p>

        <ol class="tracking-timeline" aria-label="Report status timeline">
          <li v-for="step in result.timeline" :key="step.label" :class="{ complete: step.complete, current: step.label === result.status }">
            <span class="timeline-marker" aria-hidden="true"></span>
            <span class="timeline-content">
              <strong>{{ step.label }}</strong>
              <time v-if="step.at" :datetime="step.at">{{ formatDate(step.at) }}</time>
              <small v-else>Waiting</small>
            </span>
          </li>
        </ol>

        <section v-if="result.completed && result.feedbackEligible" class="tracking-feedback">
          <h3>Rate the completed work</h3>
          <p v-if="result.feedbackSubmitted" class="feedback-thanks">Thank you. Feedback has already been recorded for this report.</p>
          <template v-else>
            <label for="public-rating">Rating (1–5)</label>
            <select id="public-rating" v-model.number="rating">
              <option :value="0" disabled>Select a rating</option>
              <option v-for="value in 5" :key="value" :value="value">{{ value }} {{ value === 1 ? 'star' : 'stars' }}</option>
            </select>
            <label for="public-comment">Comment (optional)</label>
            <textarea id="public-comment" v-model="comment" maxlength="500" rows="3"></textarea>
            <button class="btn-primary" type="button" :disabled="submittingFeedback" @click="submitFeedback">
              {{ submittingFeedback ? 'Submitting…' : 'Submit feedback' }}
            </button>
          </template>
        </section>
      </article>
    </section>
  </main>
</template>

<script setup>
import { onMounted, ref } from 'vue';
import { lookupPublicReport, isSupabaseConfigured } from '../lib/supabase.js';
import { useReports } from '../composables/useReports.js';
import { useRequests } from '../composables/useRequests.js';
import { useReportFeedback } from '../composables/useReportFeedback.js';

defineEmits(['back']);

const { reports } = useReports();
const { requests } = useRequests();
const { loadReportFeedback, submitReportFeedback, hasFeedbackForReport } = useReportFeedback();
const codeDraft = ref('');
const loading = ref(false);
const submittingFeedback = ref(false);
const error = ref('');
const result = ref(null);
const hasSearched = ref(false);
const rating = ref(0);
const comment = ref('');
let localAttemptTimes = [];

onMounted(() => {
  if (!isSupabaseConfigured) void loadReportFeedback();
});

async function lookup() {
  error.value = '';
  result.value = null;
  hasSearched.value = true;
  const code = codeDraft.value.trim().toUpperCase();
  if (!/^UNI-\d{4}-\d{4,}$/.test(code)) {
    error.value = 'Enter a valid UNIFIX tracking code, such as UNI-2026-0042.';
    return;
  }

  if (!isSupabaseConfigured) {
    const now = Date.now();
    localAttemptTimes = localAttemptTimes.filter((time) => now - time < 60_000);
    if (localAttemptTimes.length >= 10) {
      error.value = 'Too many tracking attempts. Please wait one minute.';
      return;
    }
    localAttemptTimes.push(now);
  }

  loading.value = true;
  try {
    if (isSupabaseConfigured) {
      result.value = await lookupPublicReport(code);
    } else {
      const report = reports.value.find((item) => item.trackingCode?.toUpperCase() === code);
      const request = requests.value.find((item) => item.trackingCode?.toUpperCase() === code);
      const workItem = report || request;
      if (!workItem) throw new Error('No report or request was found for that tracking code.');
      const isComplete = workItem.status === 'resolved' || workItem.status === 'action-taken' || workItem.techState === 'completed';
      const hasAssignment = Boolean(workItem.assignedTo);
      const stageDates = [
        workItem.date || null,
        workItem.reviewedAt || (workItem.status !== 'pending' && workItem.status !== 'urgent' && workItem.status !== 'submitted' ? workItem.updatedAt : null),
        workItem.assignedAt || (hasAssignment ? workItem.updatedAt : null),
        workItem.inProgressAt || (workItem.status === 'in-progress' ? workItem.updatedAt : null),
        workItem.completedAt || (isComplete ? workItem.updatedAt : null)
      ];
      result.value = {
        trackingCode: workItem.trackingCode,
        status: isComplete ? 'Completed' : workItem.techState === 'started' || workItem.status === 'in-progress' ? 'In progress' : hasAssignment ? 'Assigned' : 'Submitted',
        assignedTeam: hasAssignment ? 'Campus Maintenance Team' : null,
        lastUpdated: workItem.updatedAt || workItem.date,
        completed: isComplete,
        feedbackSubmitted: Boolean(report && hasFeedbackForReport(report.id)),
        feedbackEligible: Boolean(report),
        reportId: report?.id,
        timeline: ['Submitted', 'Reviewed', 'Assigned', 'In progress', 'Completed'].map((label, index) => ({
          label,
          at: stageDates[index],
          complete: Boolean(stageDates[index])
        }))
      };
    }
  } catch (lookupError) {
    error.value = lookupError.message || 'Unable to look up this report.';
  } finally {
    loading.value = false;
  }
}

async function submitFeedback() {
  if (!result.value?.completed || !result.value?.feedbackEligible || rating.value < 1 || rating.value > 5) {
    error.value = 'Choose a rating from 1 to 5.';
    return;
  }
  error.value = '';
  submittingFeedback.value = true;
  try {
    const demoReport = { id: result.value.reportId, status: 'resolved', techState: 'completed' };
    await submitReportFeedback(demoReport, rating.value, comment.value, result.value.trackingCode);
    result.value.feedbackSubmitted = true;
    comment.value = '';
  } catch (feedbackError) {
    error.value = feedbackError.message || 'Unable to save feedback.';
  } finally {
    submittingFeedback.value = false;
  }
}

function formatDate(value) {
  if (!value) return 'Not recorded';
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? String(value) : date.toLocaleString();
}
</script>

<style scoped>
.tracking-page { min-height: 100vh; padding: 26px clamp(18px, 6vw, 80px) 54px; background: var(--surface-2); }
.back-link { margin: 0 0 18px; border: 0; background: transparent; color: var(--primary); font: inherit; font-weight: 700; cursor: pointer; }
.tracking-card { max-width: 760px; margin: 0 auto; padding: clamp(20px, 5vw, 40px); border: 1px solid var(--border); border-radius: var(--radius-lg); background: var(--surface); box-shadow: var(--shadow); }
.eyebrow { color: var(--primary); font-size: 10px; font-weight: 800; letter-spacing: .14em; }
h1 { margin-top: 7px; font-size: clamp(28px, 5vw, 38px); letter-spacing: -1px; }
.tracking-intro { margin-top: 6px; color: var(--text-2); font-size: 13px; }
.tracking-form { margin-top: 24px; }
.tracking-form label, .tracking-feedback label { display: block; margin: 10px 0 6px; font-size: 12px; font-weight: 700; }
.tracking-form-row { display: flex; flex-wrap: wrap; gap: 8px; }
.tracking-form-row input { flex: 1 1 210px; min-width: 0; padding: 11px 12px; border: 1px solid var(--border-dark); border-radius: var(--radius-sm); font: inherit; text-transform: uppercase; }
.tracking-error { margin-top: 12px; color: var(--red); font-size: 12px; }
.tracking-loading, .tracking-empty { margin-top: 14px; color: var(--text-3); font-size: 12px; }
.tracking-result { margin-top: 24px; padding-top: 22px; border-top: 1px solid var(--border); }
.tracking-result-heading { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 10px; }
.tracking-code { color: var(--text-3); font: 700 11px 'DM Mono', monospace; }
.tracking-result h2 { margin-top: 3px; font-size: 23px; }
.status-pill { padding: 5px 10px; border-radius: 999px; background: var(--primary-bg); color: var(--primary-dark); font-size: 11px; font-weight: 800; }
.last-updated, .assigned-team { margin-top: 7px; color: var(--text-2); font-size: 12px; }
.tracking-timeline { list-style: none; margin: 23px 0; }
.tracking-timeline li { position: relative; display: flex; gap: 12px; min-height: 54px; color: var(--text-3); }
.tracking-timeline li:not(:last-child)::before { position: absolute; top: 14px; bottom: -1px; left: 6px; width: 2px; background: var(--border); content: ''; }
.tracking-timeline li.complete { color: var(--primary-dark); }
.tracking-timeline li.complete:not(:last-child)::before { background: var(--primary-light); }
.timeline-marker { z-index: 1; width: 14px; height: 14px; flex: 0 0 14px; margin-top: 2px; border: 2px solid var(--border-dark); border-radius: 50%; background: var(--surface); }
.complete .timeline-marker { border-color: var(--primary); background: var(--primary); }
.timeline-content strong, .timeline-content time, .timeline-content small { display: block; }
.timeline-content strong { font-size: 13px; }
.timeline-content time, .timeline-content small { margin-top: 2px; color: var(--text-3); font-size: 10px; }
.tracking-feedback { padding: 16px; border: 1px solid var(--border); border-radius: var(--radius-sm); background: var(--surface-2); }
.tracking-feedback h3 { font-size: 14px; }
.tracking-feedback select, .tracking-feedback textarea { width: 100%; padding: 9px; border: 1px solid var(--border-dark); border-radius: 6px; background: var(--surface); color: var(--text); font: inherit; }
.tracking-feedback button { margin-top: 10px; }
.feedback-thanks { margin-top: 7px; color: var(--primary); font-size: 12px; }
@media(max-width: 540px) { .tracking-form-row button { width: 100%; } }
</style>
