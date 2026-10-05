import { describe, expect, it } from 'vitest';
import { getEvaluationSubmissionErrorMessage } from './evaluationErrors.js';

describe('evaluation submission errors', () => {
  it('explains when the Edge Function is not deployed', async () => {
    await expect(getEvaluationSubmissionErrorMessage({
      context: new Response('{"code":"NOT_FOUND"}', { status: 404 })
    })).resolves.toContain('not deployed');
  });

  it('shows a useful message for an origin or network failure', async () => {
    await expect(getEvaluationSubmissionErrorMessage({
      name: 'FunctionsFetchError',
      message: 'Failed to send a request to the Edge Function'
    })).resolves.toContain('app origin is allowed');
  });

  it('prefers a safe error message returned by the function', async () => {
    await expect(getEvaluationSubmissionErrorMessage({
      context: new Response('{"error":"Too many evaluation submissions."}', { status: 429 })
    })).resolves.toBe('Too many evaluation submissions.');
  });
});
