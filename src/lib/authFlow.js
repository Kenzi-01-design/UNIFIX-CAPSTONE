export function accountAccessState(profile) {
  if (!profile) return 'profile-missing';
  if (profile.registration_status === 'pending') return 'pending';
  if (profile.registration_status === 'rejected') return 'rejected';
  if (profile.registration_status !== 'approved' || !profile.is_active) return 'deactivated';
  return 'active';
}

export function canTransitionRegistrationStatus(from, to) {
  if (from === to) return true;
  return (from === 'pending' && ['approved', 'rejected'].includes(to))
    || (from === 'rejected' && to === 'pending');
}

export function authStateMessage(state, profile = null) {
  switch (state) {
    case 'profile-missing':
      return 'Your account is awaiting setup. Contact the administrator.';
    case 'pending':
      return 'Your registration is awaiting administrator approval. Email confirmation is not required for new accounts.';
    case 'rejected':
      return `Your registration was not approved.${profile?.rejection_reason ? ` Reason: ${profile.rejection_reason}` : ''}`;
    case 'deactivated':
      return 'Your account is deactivated. Contact the administrator for help.';
    case 'email-unconfirmed':
      return 'This older account still requires email confirmation. Contact the administrator for help; new registrations do not require email confirmation.';
    case 'wrong-credentials':
      return 'The email or password is incorrect.';
    case 'network-error':
      return 'UNIFIX could not reach the authentication service. Check your connection and try again.';
    case 'profile-service-unavailable':
      return 'UNIFIX could not check your university profile. Check your connection and try again.';
    case 'reapplication-requested':
      return 'Your request for a new application review was sent. An administrator must reopen the application.';
    default:
      return 'Unable to sign in right now. Please try again later.';
  }
}

export function classifyAuthError(error) {
  const message = String(error?.message || '').toLowerCase();
  const code = String(error?.code || '').toLowerCase();
  if (code === 'email_not_confirmed' || message.includes('email not confirmed')) return 'email-unconfirmed';
  if (/invalid login credentials|invalid credentials|wrong password|user not found/.test(message)) return 'wrong-credentials';
  if (/failed to fetch|network|fetch error|connection|timeout/.test(message)) return 'network-error';
  return 'unknown';
}

export function passwordRecoveryErrorMessage(error, redirectUrl) {
  const message = String(error?.message || '').toLowerCase();
  const code = String(error?.code || '').toLowerCase();

  if (
    code === 'redirect_to_url_not_allowed'
    || /redirect.{0,40}(not allowed|allowlist|whitelist)/.test(message)
  ) {
    return `Password recovery is blocked because ${redirectUrl} is not an allowed Supabase redirect URL. Add this exact URL under Authentication → URL Configuration → Redirect URLs.`;
  }
  if (
    code === 'over_email_send_rate_limit'
    || error?.status === 429
    || /email.{0,30}rate limit|too many requests/.test(message)
  ) {
    return 'Too many recovery email requests were made. Wait a few minutes, then try again.';
  }
  if (code === 'email_address_not_authorized') {
    return 'Supabase is not authorized to send email to this address. Configure a custom SMTP provider in Supabase Auth, then try again.';
  }
  if (['email_provider_disabled', 'smtp_error'].includes(code) || /smtp|email provider/.test(message)) {
    return 'Supabase could not send the recovery email. Check that the email provider is enabled and its SMTP settings are valid.';
  }
  if (code === 'email_address_invalid' || /invalid email/.test(message)) {
    return 'Enter a valid university email address and try again.';
  }
  if (classifyAuthError(error) === 'network-error') return authStateMessage('network-error');
  return 'The recovery email could not be sent. Check Supabase Auth email-provider and redirect-URL settings.';
}
