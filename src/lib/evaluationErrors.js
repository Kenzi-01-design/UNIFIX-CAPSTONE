export async function getEvaluationSubmissionErrorMessage(error) {
  const status = error?.context?.status;
  if (status === 404) {
    return 'The evaluation service is not deployed to this Supabase project. Deploy the swift-worker Edge Function and try again.';
  }

  if (error?.context) {
    try {
      const body = await error.context.clone().json();
      if (typeof body?.error === 'string' && body.error) return body.error;
    } catch {
      // Keep the client error when the response body is not JSON.
    }
  }

  if (error?.name === 'FunctionsFetchError'
    || error?.message === 'Failed to send a request to the Edge Function') {
    return 'Could not reach the evaluation service. Check that swift-worker is deployed and this app origin is allowed, then try again.';
  }

  return error?.message || 'Your evaluation could not be submitted.';
}
