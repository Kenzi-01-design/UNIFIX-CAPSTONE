# UNIFIX Operations Runbook

This runbook covers the most common operational tasks for a live UNIFIX deployment.

## 1. Add a user

1. Create the user in Supabase Auth.
2. Confirm the email and verify their account if the project requires it.
3. Insert or update the matching row in `user_profiles`.
4. Set the user's role to the correct value: `public`, `employee`, `assistant`, `personnel`, or `admin`.
5. Verify they can sign in and see only their permitted navigation.

## 2. Deactivate a user

1. Freeze the account in Supabase Auth or disable sign-in for that account.
2. Update the profile to an inactive state if the schema supports it.
3. Confirm the user no longer receives notifications or assignment updates.
4. Review any still-open work items to reassign or close them.

## 3. Reset a password

1. Use the Supabase Auth password reset flow.
2. Verify the user receives the reset email from the configured provider.
3. Confirm the user can sign in and continue without losing their profile role.
4. Review the audit trail for the action if required.

## 5. Restore a backup

1. Locate the latest database backup or dump for the environment.
2. Confirm the restore is for the correct project and time window.
3. Restore the database to a disposable staging environment first when possible.
4. If production is impacted, restore the database to the last known-good point, then reapply any necessary post-restore data fixes.
5. Confirm RLS settings, triggers, and functions remain intact after restore.

## 6. Rotate secrets and API keys

1. In the Supabase dashboard, update the relevant secrets for Turnstile, Resend, webhook headers, and notification providers.
2. Redeploy affected Edge Functions.
3. Verify the frontend still loads and the backend functions can authenticate with the new secrets.
4. Remove old keys from any temporary or historical env files.

## 7. Check failed notifications

1. Review the `notifications` and `notification_deliveries` tables for recent failed records.
2. Check Edge Function logs for the `deliver-notification` function.
3. Confirm whether the failure is due to provider configuration, invalid email, auth, or rate limits.
4. Retry or requeue the failing records if the process supports it.
5. Re-check user preferences to ensure only enabled channels are used.

## 8. Monitor health

- Check the frontend health endpoint.
- Review Supabase logs for auth and database errors.
- Review Edge Function invocations for rate-limit, timeout, and secret errors.
- Review the app dashboard for operational errors and workflow backlogs.

## 9. Reassign or resolve an item after incident

1. Open the relevant report or request.
2. Confirm the current owner and status.
3. Reassign to the responsible team or personnel if needed.
4. Update status and audit entries through the standard workflow.
5. Verify the assigned user sees the item and the notification recipients match the intended role.

## 10. Final note

All operational changes should be logged and tied back to the relevant ticket or maintenance event. If the issue affects public data, privacy, or security, escalate before any broad corrective action.
