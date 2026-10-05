import { describe, expect, it } from 'vitest';
import { canRejectForRework, canSubmitWorkForVerification, canVerifyCompletedWork } from './workflow.js';
import { validateReportInput, validateRequestInput } from './validation.js';
import { calculateSusScore } from '../composables/useEvaluation.js';

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

    describe('System Usability Scale scoring', () => {
      it('converts the ten raw answers to a 0–100 SUS score', () => {
        expect(calculateSusScore(Array(10).fill(3))).toBe(50);
        expect(calculateSusScore(Array(10).fill(5))).toBe(50);
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
