import { isDemoMode, isSupabaseConfigured, supabase } from '../lib/supabase.js';
import { getEvaluationSubmissionErrorMessage } from '../lib/evaluationErrors.js';

export const UTAUT_CONSTRUCTS = Object.freeze({
  performanceExpectancy: {
    label: 'Performance Expectancy (PE)',
    description: 'The degree to which you believe using the system helps you perform your tasks better.'
  },
  effortExpectancy: {
    label: 'Effort Expectancy (EE)',
    description: 'The degree of ease associated with using the system.'
  },
  socialInfluence: {
    label: 'Social Influence (SI)',
    description: 'The degree to which you perceive that important others believe you should use the system.'
  },
  facilitatingConditions: {
    label: 'Facilitating Conditions (FC)',
    description: 'The degree to which you believe organizational and technical support exists for using the system.'
  },
  behavioralIntention: {
    label: 'Behavioral Intention (BI)',
    description: 'The degree to which you intend to keep using the system.'
  },
  useBehavior: {
    label: 'Use Behavior (UB)',
    description: 'Your actual use of the system.'
  }
});

export const UTAUT_QUESTIONS = Object.freeze({
  performanceExpectancy: [
    { code: 'PE1', statement: 'I find the system useful in my work or studies.' },
    { code: 'PE2', statement: 'Using the system helps me accomplish tasks more quickly.' },
    { code: 'PE3', statement: 'Using the system increases my productivity.' },
    { code: 'PE4', statement: 'Using the system improves the quality of my output.' }
  ],
  effortExpectancy: [
    { code: 'EE1', statement: 'My interaction with the system is clear and understandable.' },
    { code: 'EE2', statement: 'It was easy for me to become skillful at using the system.' },
    { code: 'EE3', statement: 'I find the system easy to use.' },
    { code: 'EE4', statement: 'Learning to operate the system is easy for me.' }
  ],
  socialInfluence: [
    { code: 'SI1', statement: 'People who are important to me think that I should use the system.' },
    { code: 'SI2', statement: 'People who influence my behavior think that I should use the system.' },
    { code: 'SI3', statement: 'My supervisors or teachers have been helpful in my use of the system.' },
    { code: 'SI4', statement: 'In general, my institution has supported the use of the system.' }
  ],
  facilitatingConditions: [
    { code: 'FC1', statement: 'I have the resources necessary to use the system (device, internet, account access).' },
    { code: 'FC2', statement: 'I have the knowledge necessary to use the system.' },
    { code: 'FC3', statement: 'The system is compatible with other systems I use.' },
    { code: 'FC4', statement: 'A specific person or group is available to help me with difficulties using the system.' }
  ],
  behavioralIntention: [
    { code: 'BI1', statement: 'I intend to use the system in the coming months.' },
    { code: 'BI2', statement: 'I predict I will use the system in the coming months.' },
    { code: 'BI3', statement: 'I plan to use the system in the coming months.' }
  ],
  useBehavior: [
    { code: 'UB1', statement: 'I use the system regularly for the tasks it supports.' },
    { code: 'UB2', statement: 'I rely on the system to complete those tasks.' }
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

const STORAGE_KEY = 'unifix-anonymous-evaluation-v3';

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
    throw new Error('UTAUT requires all listed answers using the 1–5 scale.');
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
