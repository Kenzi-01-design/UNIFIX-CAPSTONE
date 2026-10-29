import { describe, expect, it, vi } from 'vitest';
import { getPublicFunctionErrorMessage } from './publicFunctionErrors.js';

describe('getPublicFunctionErrorMessage', () => {
  it('explains how to deploy a missing Edge Function', async () => {
    const message = await getPublicFunctionErrorMessage('track-report', {
      context: { status: 404 }
    });

    expect(message).toContain('track-report Edge Function is not deployed');
    expect(message).toContain('supabase functions deploy track-report');
  });

  it('points to deployment and origin configuration for network failures', async () => {
    const message = await getPublicFunctionErrorMessage('track-report', {
      name: 'FunctionsFetchError',
      message: 'Failed to send a request to the Edge Function'
    });

    expect(message).toContain('track-report Edge Function');
    expect(message).toContain('PUBLIC_APP_ORIGINS');
  });

  it('shows safe function error details from JSON responses', async () => {
    const context = { clone: vi.fn(() => ({ json: async () => ({ error: 'Invalid tracking code.' }) })) };

    await expect(getPublicFunctionErrorMessage('track-report', { context }))
      .resolves.toBe('Invalid tracking code.');
  });

  it('uses the response message when an error field is absent', async () => {
    const context = { clone: vi.fn(() => ({ json: async () => ({ message: 'Function unavailable.' }) })) };

    await expect(getPublicFunctionErrorMessage('track-report', { context }))
      .resolves.toBe('Function unavailable.');
  });

  it('falls back to the client message for non-JSON errors', async () => {
    const context = { clone: vi.fn(() => ({ json: async () => { throw new Error('not JSON'); } })) };

    await expect(getPublicFunctionErrorMessage('track-report', { message: 'Request failed.', context }))
      .resolves.toBe('Request failed.');
  });
});
