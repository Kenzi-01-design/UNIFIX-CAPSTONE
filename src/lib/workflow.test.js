import { describe, expect, it } from 'vitest';
import { canRejectForRework, canSubmitWorkForVerification, canVerifyCompletedWork, isAssignedToPersonnel } from './workflow.js';
import { validateReportInput, validateRequestInput } from './validation.js';
import { calculateUtautMeans, UTAUT_QUESTIONS } from '../composables/useEvaluation.js';

describe('work verification transitions', () => {
  const startedAssignment = {
    status: 'in-progress',
    techState: 'started',
    assignedPersonnel: ['Juan dela Cruz']
  };

  it('allows assigned personnel to submit started work for verification', () => {
    expect(canSubmitWorkForVerification(startedAssignment, 'juan dela cruz')).toBe(true);
    expect(canSubmitWorkForVerification(startedAssignment, 'Other technician')).toBe(false);
  });

  it('matches assigned personnel despite casing or surrounding whitespace', () => {
    expect(isAssignedToPersonnel({ assignedPersonnel: ['  Juan dela Cruz  '] }, 'juan DELA CRUZ')).toBe(true);
    expect(isAssignedToPersonnel({ assignedTo: 'Ana Torres, Juan dela Cruz' }, ' JUAN DELA CRUZ ')).toBe(true);
    expect(isAssignedToPersonnel({ assignedPersonnel: ['Juan dela Cruz'] }, '')).toBe(false);
  });

  describe('work item input validation', () => {
    it('accepts a report within database limits and rejects oversized titles', () => {
      expect(() => validateReportInput({
        title: 'Leaking faucet',
        desc: 'Water is pooling near the sink.',
        cat: 'Plumbing',
        loc: 'Library · Ground Floor',
        reporter: 'Campus Reporter'
      })).not.toThrow();
      expect(() => validateReportInput({
        title: 'x'.repeat(161),
        desc: 'Issue',
        cat: 'Plumbing',
        loc: 'Library',
        reporter: 'Campus Reporter'
      })).toThrow(/oversized/);
    });

    describe('UTAUT construct summaries', () => {
      it('includes the specified items for all six constructs', () => {
        expect(Object.values(UTAUT_QUESTIONS).map((questions) => questions.map(({ code }) => code))).toEqual([
          ['PE1', 'PE2', 'PE3', 'PE4'],
          ['EE1', 'EE2', 'EE3', 'EE4'],
          ['SI1', 'SI2', 'SI3', 'SI4'],
          ['FC1', 'FC2', 'FC3', 'FC4'],
          ['BI1', 'BI2', 'BI3'],
          ['UB1', 'UB2']
        ]);
      });

      it('calculates a 1–5 mean for each construct', () => {
        expect(calculateUtautMeans({
          performanceExpectancy: [1, 3, 5, 3],
          effortExpectancy: [2, 2, 2, 2],
          socialInfluence: [3, 3, 3, 3],
          facilitatingConditions: [4, 4, 4, 4],
          behavioralIntention: [1, 2, 3],
          useBehavior: [4, 5]
        })).toEqual({
          performanceExpectancy: 3,
          effortExpectancy: 2,
          socialInfluence: 3,
          facilitatingConditions: 4,
          behavioralIntention: 2,
          useBehavior: 4.5
        });
      });

      it('rejects incomplete or out-of-range construct answers', () => {
        expect(() => calculateUtautMeans({
          performanceExpectancy: [1, 3, 5, 3],
          effortExpectancy: [2, 2],
          socialInfluence: [3, 3, 3, 3],
          facilitatingConditions: [4, 4, 4, 4],
          behavioralIntention: [1, 2, 3],
          useBehavior: [4, 5]
        })).toThrow(/UTAUT requires/);
        expect(() => calculateUtautMeans({
          performanceExpectancy: [1, 3, 5, 3],
          effortExpectancy: [2, 2, 2, 2],
          socialInfluence: [3, 3, 3, 3],
          facilitatingConditions: [4, 4, 4, 4],
          behavioralIntention: [1, 2, 3],
          useBehavior: [4, 6]
        })).toThrow(/UTAUT requires/);
      });
    });

    it('rejects an invalid request update email', () => {
      expect(() => validateRequestInput({
        title: 'Repair faucet',
        cat: 'Plumbing',
        dept: 'Library',
        details: 'The faucet leaks.',
        requester: 'Campus Employee',
        requesterEmail: 'not-an-email'
      })).toThrow(/valid email/);
    });
  });

  it('rejects completion when the work is not in progress', () => {
    expect(canSubmitWorkForVerification({ ...startedAssignment, status: 'pending' }, 'Juan dela Cruz')).toBe(false);
  });

  it('allows only completed work to be verified or returned for rework', () => {
    const completed = { status: 'for-verification', techState: 'completed' };
    expect(canVerifyCompletedWork(completed)).toBe(true);
    expect(canRejectForRework(completed, 'Please recheck the repair')).toBe(true);
    expect(canRejectForRework(completed, 'bad')).toBe(false);
    expect(canVerifyCompletedWork({ ...completed, techState: 'started' })).toBe(false);
  });
});
