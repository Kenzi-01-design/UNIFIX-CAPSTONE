# UNIFIX account-flow manual test script

Run this only in a non-production Supabase project with disposable test
accounts. Keep `Actual` and `Pass/Fail` blank until the manual run is complete.

Account deletion is intentionally refused when reports, requests, or assignments
reference the account, preserving business history rather than cascading or
anonymizing it. If deletion is permitted, the Auth account, profile, and
account-specific preferences/notifications are removed; the account audit trail
is retained.

| Test case | Steps | Expected | Actual | Pass/Fail |
|---|---|---|---|---|
| Valid registration | Register with a new allowed-domain email, then inspect User Management and sign in before approval. | Signup sends no confirmation email; a linked profile appears as inactive, pending `Employee`, and sign-in is blocked only for pending approval. |  |  |
| Bad domain | Attempt registration with an address outside the configured domain list. | Inline validation prevents submission; direct server-side registration is rejected with a friendly error. |  |  |
| Duplicate email | Submit a registration using an existing address. | No duplicate profile is created; the UI gives a generic sign-in/reset-password message without account enumeration. |  |  |
| Notification email verification | Sign in to an approved account, enter a notification email in Settings, request verification, and open its verification link. | The separate notification address becomes verified; email updates remain off until the user enables and saves them. |  |  |
| Notification opt-in | Change the notification email after verification, then try to enable email updates. | Editing the address clears its verified state and disables email updates until that new address is verified. |  |  |
| Sign-up email confirmation setting | Register a valid new account with Email → Confirm email disabled in Supabase. | Supabase does not require an email confirmation; the account still waits for Admin or Assistant approval. |  |  |
| Pending login | Register a new applicant and sign in before the profile is approved. | Sign-in ends locally and explains that administrative approval is pending; no email confirmation is requested. |  |  |
| Approve then login | As Admin, approve the pending profile with a role; then sign in as the applicant. | Approval is audited; the assigned profile role controls navigation and sign-in succeeds. |  |  |
| Reject then login | As Admin, reject a pending profile with a reason; sign in as that applicant. | The account remains inactive; the applicant sees rejection and the configured reason. |  |  |
| Re-apply | As a rejected applicant, request another review; as Admin, reopen the application. | Request is rate-limited to once every 30 days; only the Admin action returns it to pending. |  |  |
| Deactivate then login | As Admin, deactivate an approved account; sign in as that user. | The profile remains approved but inactive; sign-in is denied with a deactivation message. |  |  |
| Reactivate | As Admin, reactivate the same approved account; sign in again. | The account is active and can sign in with its profile role. |  |  |
| Admin invite and set-password | As Admin, invite a new allowed-domain user with a non-Admin role; open the invite link and set a password. | A real Auth user and active approved profile are created, an invitation email is sent, and the assigned role is enforced. |  |  |
| Forgot password | Request a reset from Login, use the email link, enter and confirm a new password. | The recovery view appears, password update succeeds, and the user returns to sign-in. |  |  |
| Role change while logged in | Keep a user signed in while an Admin changes that profile's role. | Realtime/token refresh applies the new role and navigation, or access is ended if the profile is no longer active. |  |  |
| Last-Admin protection | With one active Admin remaining, attempt to deactivate, demote, or delete that account. | Each operation is rejected; at least one active Admin remains. |  |  |
