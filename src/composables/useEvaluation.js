import { isDemoMode, isSupabaseConfigured, supabase } from '../lib/supabase.js';
import { getEvaluationSubmissionErrorMessage } from '../lib/evaluationErrors.js';

export const UTAUT_CONSTRUCTS = Object.freeze({
  performanceExpectancy: 'Performance expectancy',
  effortExpectancy: 'Effort expectancy',
  socialInfluence: 'Social influence',
  facilitatingConditions: 'Facilitating conditions',
  behavioralIntention: 'Behavioral intention'
});

export const UTAUT_QUESTIONS = Object.freeze({
  performanceExpectancy: [
    'Using UNIFIX helps me accomplish what I need to do more quickly.',
    'Using UNIFIX improves my effectiveness when reporting or managing maintenance needs.',
    'UNIFIX is useful for my interactions with the institution.'
  ],
  effortExpectancy: [
    'Learning to use UNIFIX is easy for me.',
    'It is easy for me to become skillful at using UNIFIX.',
    'I find UNIFIX easy to use.'
  ],
  socialInfluence: [
    'People who influence my work think I should use UNIFIX.',
    'People important to me support my use of UNIFIX.',
    'My institution encourages the use of UNIFIX for maintenance-related tasks.'
  ],
  facilitatingConditions: [
    'I have the resources needed to use UNIFIX.',
    'I have the knowledge needed to use UNIFIX.',
    'UNIFIX is compatible with the devices and systems I use.'
  ],
  behavioralIntention: [
    'I intend to use UNIFIX when I need to report or follow up on a maintenance issue.',
    'I expect to continue using UNIFIX in the future.',
    'I will make an effort to use UNIFIX in my work or interactions with the institution.'
  ]
});

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

const STORAGE_KEY = 'unifix-anonymous-evaluation-v2';

function validateSubmission(submission) {
  const utautKeys = Object.keys(UTAUT_CONSTRUCTS);
  if (!submission.utautAnswers || Object.keys(submission.utautAnswers).length !== utautKeys.length
    || utautKeys.some((key) => !Array.isArray(submission.utautAnswers[key])
      || submission.utautAnswers[key].length !== UTAUT_QUESTIONS[key].length
      || submission.utautAnswers[key].some((answer) => !Number.isInteger(answer) || answer < 1 || answer > 5))) {
    throw new Error('Answer all UTAUT questions using the 1–5 scale.');
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

export function calculateUtautMeans(answers) {
  const keys = Object.keys(UTAUT_CONSTRUCTS);
  if (!answers || Object.keys(answers).length !== keys.length
    || keys.some((key) => !Array.isArray(answers[key])
      || answers[key].length !== UTAUT_QUESTIONS[key].length
      || answers[key].some((answer) => !Number.isInteger(answer) || answer < 1 || answer > 5))) {
    throw new Error('UTAUT requires three answers per construct using the 1–5 scale.');
  }
  return Object.fromEntries(keys.map((key) => [
    key,
    Number((answers[key].reduce((total, answer) => total + answer, 0) / answers[key].length).toFixed(2))
  ]));
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
  const utautTotals = Object.fromEntries(Object.keys(UTAUT_CONSTRUCTS).map((key) => [key, 0]));

  for (const response of responses) {
    const means = calculateUtautMeans(response.utautAnswers);
    roleCounts[response.respondentRole] = (roleCounts[response.respondentRole] || 0) + 1;
    for (const key of Object.keys(UTAUT_CONSTRUCTS)) utautTotals[key] += means[key];
    for (const key of Object.keys(ISO_CHARACTERISTICS)) {
      isoTotals[key] += response.isoAnswers[key];
      isoCounts[key] += 1;
    }
  }

  return {
    responseCount: responses.length,
    utautMeans: Object.fromEntries(Object.keys(UTAUT_CONSTRUCTS).map((key) => [
      key,
      responses.length ? Number((utautTotals[key] / responses.length).toFixed(2)) : null
    ])),
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
      utautAnswers: Object.fromEntries(Object.entries(submission.utautAnswers).map(([key, answers]) => [key, [...answers]])),
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
