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
