export async function getPublicFunctionErrorMessage(functionName, error) {
  if (error?.context?.status === 404) {
    return `The ${functionName} Edge Function is not deployed to this Supabase project. Deploy it with "supabase functions deploy ${functionName}".`;
  }

  if (error?.name === 'FunctionsFetchError'
    || error?.message === 'Failed to send a request to the Edge Function') {
    const originSecret = functionName === 'password-recovery'
      ? 'PASSWORD_RECOVERY_APP_ORIGINS'
      : 'PUBLIC_APP_ORIGINS';
    return `Could not reach the ${functionName} Edge Function. Confirm it is deployed and this site's exact origin is included in Supabase's ${originSecret} secret.`;
  }

  if (error?.context) {
    try {
      const body = await error.context.clone().json();
      if (typeof body?.error === 'string' && body.error) return body.error;
      if (typeof body?.message === 'string' && body.message) return body.message;
    } catch {
      // Keep the client error when the function response is not JSON.
    }
  }

  return error?.message || `The ${functionName} Edge Function request failed.`;
}
