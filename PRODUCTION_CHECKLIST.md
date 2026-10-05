# UNIFIX Production Checklist

This checklist is intended for the final pre-launch review before a real Supabase production deployment.

## 1. Project and repository readiness

- [ ] Repository is clean and only approved changes are committed.
- [ ] Build, unit tests, and client secret checks are passing in CI and locally.
- [ ] No accidental debug code remains (`console.log`, `alert()`, test credentials, mock admin code in production paths).
- [ ] `.env.local` is not committed and `.env.example` is complete.
- [ ] Lockfile is committed and dependency versions are tracked.

## 2. Supabase production setup

- [ ] Production Supabase project exists in the correct region.
- [ ] Email/password auth is enabled and configured.
- [ ] Auth redirect/site URLs include the production host and correct callback paths.
- [ ] RLS is enabled on all client-accessible tables, including reports, requests, notifications, evaluation responses, locations, and maintenance schedules.
- [ ] Final migration chain has been run in order against the production project.
- [ ] Storage bucket `report-photos` exists as private and has appropriate policies.
- [ ] File type and size limits match the app design.
- [ ] `user_profiles` rows exist for each active user and admin roles are assigned only through trusted database workflow.
- [ ] Only a trusted admin bootstrap flow creates the first administrator.

## 3. Security and secrets

- [ ] No service-role key is present in client code or frontend env variables.
- [ ] Only public values are in `VITE_*` variables.
- [ ] Turnstile secret, provider keys, SMTP credentials, and webhook secrets are configured in the Supabase dashboard or server environment only.
- [ ] Content-Security-Policy, frame protections, and caching headers are validated on the live host.
- [ ] Public endpoints are rate-limited and do not leak internal data.
- [ ] Public tracking page reveals only allowed fields and never reporter identity or internal notes.
- [ ] No feature or policy uses `using (true)` or trusts client-supplied role values.

## 4. Frontend and deployment

- [ ] Vercel or Netlify project is connected to the repo.
- [ ] Production env vars are set exactly as required by `.env.example`.
- [ ] Build command is `pnpm build`; output directory is `dist`.
- [ ] SPA rewrite rules are enabled for deep links and query-string routes.
- [ ] HTTPS is enforced and custom domain is configured.
- [ ] PWA manifest, icons, and offline fallback have been validated.
- [ ] Offline drafts are scoped to each user/session and do not auto-submit.
- [ ] App boots correctly with missing/invalid config in a non-production environment.

## 5. Edge Functions and scheduled jobs

- [ ] `submit-public-report` is deployed and uses server-side CAPTCHA verification.
- [ ] `track-report` is deployed with rate limits and restricted payload fields.
- [ ] `swift-worker` is deployed and only allows eligible public/employee roles.
- [ ] `deliver-notification` is deployed with correct secret header checks.
- [ ] Webhooks are configured against the notification delivery table.
- [ ] Cron or scheduled jobs are configured for:
  - [ ] preventive maintenance generation
- [ ] Scheduled jobs are idempotent and do not create duplicate records when retried.

## 6. Workflow and data integrity checks

- [ ] Status transitions follow the approved state machine.
- [ ] Rework and verification flow works from completion to verification to closed or rejected.
- [ ] Reopen requests are limited to the seven-day window.
- [ ] Notification preferences are respected.
- [ ] Duplicate detection / merge logic is tested in staging.

## 7. User validation by role

- [ ] Public reporter can submit a report and receive a tracking number.
- [ ] Public reporter can track the case without seeing internal user data.
- [ ] Employee can submit service requests and view only permitted content.
- [ ] Assistant can review work and verify/close items without admin-only controls.
- [ ] Personnel can access assigned work but not unassigned or unrelated work.
- [ ] Admin can manage users, facilities, maintenance, and analytics while restricted routes remain locked for others.

## 8. Final sign-off

- [ ] Smoke test script has been run against a staging project.
- [ ] Browser route protection and role-based navigation have been verified in production-like conditions.
- [ ] PHI/privacy records and public consent language are in place for the context of use.
- [ ] Backup, restore, and incident escalation steps are documented.
- [ ] Stakeholder sign-off is completed and deployment is approved.

## Manual note

This checklist is intentionally strict and should be followed before any public production release. If any item is unchecked, the release should be treated as not ready for deployment.
