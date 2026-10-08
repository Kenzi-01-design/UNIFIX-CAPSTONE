<template>
  <div class="view active evaluation-page">
    <button v-if="publicMode" type="button" class="back-link" @click="$emit('back')">← Back to home</button>

    <template v-if="adminMode">
      <header class="evaluation-header">
        <p class="evaluation-eyebrow">SYSTEM QUALITY</p>
        <h1>Evaluation results</h1>
        <p>Anonymous SUS and ISO/IEC 25010 responses. No names, emails, or account identifiers are stored.</p>
      </header>
      <div v-if="loading" class="evaluation-state" role="status">Loading evaluation results…</div>
      <div v-else-if="error" class="evaluation-state evaluation-error" role="alert">{{ error }}</div>
      <template v-else-if="summary">
        <div class="evaluation-results-toolbar">
          <span>{{ summary.responseCount }} response{{ summary.responseCount === 1 ? '' : 's' }}</span>
          <button class="btn-secondary" type="button" :disabled="!summary.responseCount" @click="exportCsv">Export CSV</button>
        </div>
        <div v-if="!summary.responseCount" class="evaluation-state">
          No responses yet. Share the evaluation page with system users to collect feedback.
        </div>
        <div v-else class="evaluation-results-grid">
          <section class="evaluation-result-card sus-result">
            <h2>System Usability Scale</h2>
            <strong>{{ summary.susAverage ?? '—' }}<small>/ 100</small></strong>
            <p v-if="summary.susAverage !== null">{{ susInterpretation(summary.susAverage) }} (average SUS score)</p>
            <p>Standard SUS scoring is applied: odd questions score 0–4; even questions are reverse-scored.</p>
          </section>
          <section class="evaluation-result-card">
            <h2>ISO/IEC 25010 characteristics</h2>
            <p class="result-caption">Mean response on a 1–5 agreement scale</p>
            <div v-for="(label, key) in ISO_CHARACTERISTICS" :key="key" class="mean-row">
              <span>{{ label }}</span>
              <div class="mean-track"><i :style="{ width: `${(summary.isoMeans?.[key] || 0) * 20}%` }"></i></div>
              <strong>{{ summary.isoMeans?.[key] ?? '—' }}</strong>
            </div>
          </section>
          <section class="evaluation-result-card">
            <h2>Respondent counts by role</h2>
            <ul v-if="Object.keys(summary.respondentsByRole || {}).length" class="role-count-list">
              <li v-for="(count, role) in summary.respondentsByRole" :key="role"><span>{{ role }}</span><strong>{{ count }}</strong></li>
            </ul>
            <p v-else class="result-caption">No role counts are available.</p>
          </section>
        </div>
      </template>
    </template>

    <template v-else>
      <header class="evaluation-header">
        <p class="evaluation-eyebrow">OPTIONAL · ANONYMOUS</p>
        <h1>Help us evaluate UNIFIX</h1>
        <p>Your answers are stored without your name, email, or account ID. All items use a 1–5 scale, from Strongly disagree to Strongly agree.</p>
      </header>
      <div v-if="submitted" class="evaluation-state evaluation-success" role="status">
        <h2>Thank you for your feedback</h2>
        <p>Your anonymous response has been recorded.</p>
        <button v-if="publicMode" class="btn-secondary" type="button" @click="$emit('back')">Return to home</button>
      </div>
      <form v-else class="evaluation-form" @submit.prevent="submit">
        <div class="form-group respondent-role">
          <label>Respondent role</label>
          <p>{{ respondentRole }}</p>
          <small>This role is used only for aggregated respondent counts.</small>
        </div>
        <section class="evaluation-section">
          <h2>System Usability Scale (SUS)</h2>
          <p>Choose how much you agree with each statement about UNIFIX.</p>
          <fieldset v-for="(question, index) in SUS_QUESTIONS" :key="question" class="evaluation-question">
            <legend>{{ index + 1 }}. {{ question }}</legend>
            <div class="rating-options">
              <label v-for="rating in ratings" :key="rating">
                <input v-model.number="susAnswers[index]" type="radio" :name="`sus-${index}`" :value="rating" required />
                <span>{{ rating }}</span>
              </label>
            </div>
          </fieldset>
        </section>
        <section class="evaluation-section">
          <h2>ISO/IEC 25010 quality characteristics</h2>
          <p>Rate UNIFIX for each software-quality characteristic.</p>
          <fieldset v-for="(label, key) in ISO_CHARACTERISTICS" :key="key" class="evaluation-question">
            <legend><strong>{{ label }}.</strong> {{ ISO_QUESTIONS[key] }}</legend>
            <div class="rating-options">
              <label v-for="rating in ratings" :key="rating">
                <input v-model.number="isoAnswers[key]" type="radio" :name="`iso-${key}`" :value="rating" required />
                <span>{{ rating }}</span>
              </label>
            </div>
          </fieldset>
        </section>
        <p v-if="error" class="evaluation-error" role="alert">{{ error }}</p>
        <div class="evaluation-submit">
          <p>Submitting is optional. Your response contains only answers and the role you selected.</p>
          <button class="btn-accent" type="submit" :disabled="submitting">
            {{ submitting ? 'Submitting…' : 'Submit anonymous evaluation' }}
          </button>
        </div>
      </form>
    </template>
  </div>
</template>

<script setup>
import { onMounted, reactive, ref } from 'vue';
import {
  ISO_CHARACTERISTICS,
  ISO_QUESTIONS,
  SUS_QUESTIONS,
  useEvaluation
} from '../composables/useEvaluation.js';
import { useToast } from '../composables/useToast.js';

const props = defineProps({
  adminMode: { type: Boolean, default: false },
  publicMode: { type: Boolean, default: false },
  respondentRole: { type: String, default: 'Public' }
});
defineEmits(['back']);

const ratings = [1, 2, 3, 4, 5];
const susAnswers = ref(Array(10).fill(null));
const isoAnswers = reactive(Object.fromEntries(Object.keys(ISO_CHARACTERISTICS).map((key) => [key, null])));
const respondentRole = ref(props.publicMode ? 'Public' : props.respondentRole);
const submitted = ref(false);
const submitting = ref(false);
const loading = ref(false);
const error = ref('');
const summary = ref(null);
const { showToast } = useToast();
const { submitEvaluation, loadEvaluationSummary } = useEvaluation();

onMounted(() => {
  if (props.adminMode) void loadSummary();
});

async function loadSummary() {
  loading.value = true;
  error.value = '';
  try {
    summary.value = await loadEvaluationSummary();
  } catch (loadError) {
    error.value = loadError.message || 'Evaluation results could not be loaded.';
  } finally {
    loading.value = false;
  }
}

async function submit() {
  submitting.value = true;
  error.value = '';
  try {
    await submitEvaluation({
      respondentRole: respondentRole.value,
      susAnswers: susAnswers.value,
      isoAnswers: { ...isoAnswers }
    });
    submitted.value = true;
    showToast('Anonymous evaluation submitted.', 'success');
  } catch (submissionError) {
    error.value = submissionError.message || 'Your evaluation could not be submitted.';
  } finally {
    submitting.value = false;
  }
}

function susInterpretation(score) {
  if (score >= 80.3) return 'Excellent';
  if (score >= 68) return 'Good';
  if (score >= 51) return 'Fair';
  return 'Needs improvement';
}

function exportCsv() {
  const lines = [
    ['Measure', 'Value'],
    ['Respondent count', summary.value.responseCount],
    ['Average SUS score', summary.value.susAverage ?? ''],
    ...Object.entries(ISO_CHARACTERISTICS).map(([key, label]) => [label, summary.value.isoMeans?.[key] ?? '']),
    ...Object.entries(summary.value.respondentsByRole || {}).map(([role, count]) => [`Respondents · ${role}`, count])
  ];
  const csv = lines.map((row) => row.map((cell) => `"${String(cell).replaceAll('"', '""')}"`).join(',')).join('\r\n');
  const url = URL.createObjectURL(new Blob([csv], { type: 'text/csv;charset=utf-8' }));
  const link = document.createElement('a');
  link.href = url;
  link.download = 'unifix-evaluation-results.csv';
  link.click();
  URL.revokeObjectURL(url);
}
</script>

<style scoped>
.evaluation-page{max-width:1040px;margin:0 auto;padding:24px 0 48px}.evaluation-header{margin:0 0 22px}.evaluation-header h1{font-size:clamp(26px,4vw,36px);letter-spacing:-.8px}.evaluation-header>p:last-child{max-width:760px;margin-top:7px;color:var(--text-2);font-size:13px}.evaluation-eyebrow{color:var(--primary);font-size:10px;font-weight:800;letter-spacing:.14em}.evaluation-form,.evaluation-result-card{padding:20px;border:1px solid var(--border);border-radius:var(--radius);background:var(--surface);box-shadow:var(--shadow-sm)}.respondent-role{max-width:430px;margin-bottom:20px}.respondent-role small,.result-caption{display:block;margin-top:4px;color:var(--text-3);font-size:11px}.evaluation-section{margin-top:20px;padding:18px;border:1px solid var(--border);border-radius:var(--radius-sm);background:var(--surface-2)}.evaluation-section h2,.evaluation-result-card h2{font-size:16px}.evaluation-section>p{margin:4px 0 14px;color:var(--text-3);font-size:12px}.evaluation-question{min-width:0;margin:0;padding:13px 0;border:0;border-top:1px solid var(--border)}.evaluation-question legend{width:100%;font-size:13px;font-weight:600;line-height:1.5}.rating-options{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:8px;margin-top:10px}.rating-options label{position:relative;display:grid;place-items:center;min-height:38px;border:1px solid var(--border-dark);border-radius:7px;background:var(--surface);cursor:pointer}.rating-options input{position:absolute;inset:0;width:100%;height:100%;opacity:0;cursor:pointer}.rating-options label:has(input:checked){border-color:var(--primary);background:var(--primary-bg);color:var(--primary-dark);font-weight:800}.rating-options label:has(input:focus-visible){outline:3px solid var(--accent-light);outline-offset:2px}.evaluation-submit{display:flex;align-items:center;justify-content:space-between;gap:16px;margin-top:18px}.evaluation-submit p{max-width:520px;color:var(--text-3);font-size:11px}.evaluation-submit button{flex:none}.evaluation-state{padding:24px;border:1px solid var(--border);border-radius:var(--radius);background:var(--surface);color:var(--text-2);font-size:13px}.evaluation-success{border-color:#b7ddc5;background:var(--green-bg);color:var(--primary-dark)}.evaluation-success h2{font-size:18px}.evaluation-success p{margin:4px 0 14px}.evaluation-error{color:var(--red)}.evaluation-results-toolbar{display:flex;align-items:center;justify-content:space-between;margin-bottom:14px;color:var(--text-3);font-size:12px}.evaluation-results-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px}.evaluation-result-card>h2{margin-bottom:12px}.sus-result>strong{display:block;color:var(--primary);font-size:42px;line-height:1.1}.sus-result>strong small{font-size:16px}.sus-result>p{margin-top:8px;color:var(--text-2);font-size:12px}.mean-row{display:grid;grid-template-columns:minmax(130px,1fr) minmax(70px,1.4fr) 36px;align-items:center;gap:10px;margin:11px 0;font-size:11px}.mean-track{height:9px;overflow:hidden;border-radius:8px;background:var(--surface-3)}.mean-track i{display:block;height:100%;border-radius:inherit;background:var(--primary)}.mean-row>strong{text-align:right}.role-count-list{list-style:none}.role-count-list li{display:flex;justify-content:space-between;padding:9px 0;border-bottom:1px solid var(--border);font-size:12px}.back-link{border:0;background:transparent;color:var(--primary);font:inherit;font-weight:700;cursor:pointer;margin-bottom:16px}
@media(max-width:1023px){
  .evaluation-page{width:min(100%,1040px);padding:clamp(16px,3vw,24px) clamp(16px,3vw,24px) 40px}
  .back-link{display:inline-flex;align-items:center;min-height:44px;margin:0 0 18px;padding:0 8px}
  .evaluation-header{min-width:0;margin-bottom:20px}
  .evaluation-header h1{line-height:1.2;overflow-wrap:anywhere}
  .evaluation-header>p:last-child{margin-top:10px;font-size:14px;line-height:1.65;overflow-wrap:anywhere}
  .evaluation-eyebrow{display:inline-block;margin:0 0 8px;padding:6px 10px;border-radius:999px;background:var(--primary-bg);letter-spacing:.1em;line-height:1.4}
}
@media(max-width:680px){
  .evaluation-page{padding:14px 14px 32px}
  .evaluation-results-grid{grid-template-columns:1fr}
  .evaluation-form,.evaluation-result-card{padding:16px}
  .evaluation-section{margin-top:16px;padding:14px}
  .evaluation-section h2,.evaluation-result-card h2{line-height:1.35}
  .evaluation-section>p{font-size:13px;line-height:1.6}
  .evaluation-question legend{font-size:14px;line-height:1.55}
  .evaluation-submit{align-items:stretch;flex-direction:column}
  .evaluation-submit p{font-size:12px;line-height:1.6}
  .evaluation-submit button{width:100%;min-height:48px}
  .mean-row{grid-template-columns:minmax(105px,1fr) minmax(55px,1.2fr) 32px}
  .rating-options{gap:6px}
  .rating-options label{min-height:44px}
}
</style>
