import { isDemoMode, isSupabaseConfigured, supabase } from '../lib/supabase.js';
import { getEvaluationSubmissionErrorMessage } from '../lib/evaluationErrors.js';

export const SUS_QUESTIONS = [
  'I think that I would like to use this system frequently.',
  'I found the system unnecessarily complex.',
  'I thought the system was easy to use.',
  'I think that I would need the support of a technical person to be able to use this system.',
  'I found the various functions in this system were well integrated.',
  'I thought there was too much inconsistency in this system.',
  'I would imagine that most people would learn to use this system very quickly.',
  'I found the system very cumbersome to use.',
  'I felt very confident using the system.',
  'I needed to learn a lot of things before I could get going with this system.'
];

export const ISO_CHARACTERISTICS = Object.freeze({
  functionalSuitability: 'Functional suitability',
  performanceEfficiency: 'Performance efficiency',
  compatibility: 'Compatibility',
  usability: 'Usability',
  reliability: 'Reliability',
  security: 'Security',
  maintainability: 'Maintainability',
  portability: 'Portability'
});

export const ISO_QUESTIONS = Object.freeze({
  functionalSuitability: 'UNIFIX provides the functions I need to report and manage maintenance work.',
  performanceEfficiency: 'UNIFIX responds quickly and uses resources efficiently.',
  compatibility: 'UNIFIX works well with the devices and browsers I use.',
  usability: 'UNIFIX is easy to learn and use for my role.',
  reliability: 'UNIFIX is available and behaves consistently when I need it.',
  security: 'I feel that UNIFIX protects my information and access appropriately.',
  maintainability: 'UNIFIX changes and updates appear consistent and well managed.',
  portability: 'I can use UNIFIX across the devices and environments available to me.'
});

const STORAGE_KEY = 'unifix-anonymous-evaluation-v1';

function validateSubmission(submission) {
  if (!Array.isArray(submission.susAnswers) || submission.susAnswers.length !== 10
    || submission.susAnswers.some((answer) => !Number.isInteger(answer) || answer < 1 || answer > 5)) {
    throw new Error('Answer all 10 usability questions using the 1–5 scale.');
  }
  const isoKeys = Object.keys(ISO_CHARACTERISTICS);
  if (!submission.isoAnswers || Object.keys(submission.isoAnswers).length !== isoKeys.length
    || isoKeys.some((key) => !Number.isInteger(submission.isoAnswers[key])
      || submission.isoAnswers[key] < 1 || submission.isoAnswers[key] > 5)) {
    throw new Error('Answer all eight quality-characteristic questions using the 1–5 scale.');
  }
  if (!['Public', 'Employee'].includes(submission.respondentRole)) {
    throw new Error('Select the respondent role.');
  }
}

export function calculateSusScore(answers) {
  if (!Array.isArray(answers) || answers.length !== 10
    || answers.some((answer) => !Number.isInteger(answer) || answer < 1 || answer > 5)) {
    throw new Error('SUS requires exactly 10 answers from 1 to 5.');
  }
  return Number((answers.reduce((score, answer, index) => (
    score + (index % 2 === 0 ? answer - 1 : 5 - answer)
  ), 0) * 2.5).toFixed(2));
}

function readDemoResponses() {
  try {
    const saved = JSON.parse(localStorage.getItem(STORAGE_KEY) || '[]');
    if (!Array.isArray(saved)) throw new Error('Unexpected survey storage format.');
    return saved;
  } catch (error) {
    console.error('Could not read local evaluation responses.', error);
    throw new Error('Saved evaluation data could not be read from this browser.');
  }
}

function buildDemoSummary(responses) {
  const roleCounts = {};
  const isoTotals = Object.fromEntries(Object.keys(ISO_CHARACTERISTICS).map((key) => [key, 0]));
  const isoCounts = Object.fromEntries(Object.keys(ISO_CHARACTERISTICS).map((key) => [key, 0]));
  const scores = [];

  for (const response of responses) {
    scores.push(calculateSusScore(response.susAnswers));
    roleCounts[response.respondentRole] = (roleCounts[response.respondentRole] || 0) + 1;
    for (const key of Object.keys(ISO_CHARACTERISTICS)) {
      isoTotals[key] += response.isoAnswers[key];
      isoCounts[key] += 1;
    }
  }

  return {
    responseCount: responses.length,
    susAverage: scores.length
      ? Number((scores.reduce((total, score) => total + score, 0) / scores.length).toFixed(2))
      : null,
    isoMeans: Object.fromEntries(Object.keys(ISO_CHARACTERISTICS).map((key) => [
      key,
      isoCounts[key] ? Number((isoTotals[key] / isoCounts[key]).toFixed(2)) : null
    ])),
    respondentsByRole: roleCounts
  };
}

export function useEvaluation() {
  async function submitEvaluation(submission) {
    validateSubmission(submission);
    if (isSupabaseConfigured && !isDemoMode) {
      if (!navigator.onLine) throw new Error('Reconnect to submit the anonymous evaluation.');
      const { data, error } = await supabase.functions.invoke('swift-worker', {
        body: { ...submission, submissionKey: crypto.randomUUID() }
      });
      if (error) throw new Error(await getEvaluationSubmissionErrorMessage(error));
      if (!data?.submitted) throw new Error('The evaluation service returned an invalid response.');
      return data;
    }

    const responses = readDemoResponses();
    responses.push({
      respondentRole: submission.respondentRole,
      susAnswers: [...submission.susAnswers],
      isoAnswers: { ...submission.isoAnswers }
    });
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(responses));
    } catch (error) {
      console.error('Could not save a local evaluation response.', error);
      throw new Error('The anonymous response could not be saved in this browser.');
    }
    return { submitted: true };
  }

  async function loadEvaluationSummary() {
    if (isSupabaseConfigured && !isDemoMode) {
      const { data, error } = await supabase.rpc('get_evaluation_summary');
      if (error) throw error;
      if (!data || typeof data !== 'object') throw new Error('The evaluation summary is unavailable.');
      return data;
    }
    return buildDemoSummary(readDemoResponses());
  }

  return { submitEvaluation, loadEvaluationSummary };
}
