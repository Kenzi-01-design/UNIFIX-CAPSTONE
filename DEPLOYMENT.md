# UNIFIX production deployment

This guide deploys the Vue/Vite frontend to Vercel or Netlify and uses Supabase
for authentication, Postgres, Storage, and Edge Functions.

## 1. Prepare Supabase

1. Create a production Supabase project and enable email/password authentication.
   In **Authentication → URL Configuration**, set **Site URL** to the canonical
   production frontend origin (for example, `https://unifix.example.edu`). Add
   that origin and only the exact callback URLs used by the app to **Redirect
   URLs**. Add the local development origin only to a non-production project.
   Password recovery and account registration callbacks must return to the
   frontend origin; never use a wildcard redirect. Sign-up email confirmation
   must be disabled as described below; notification email verification is a
   separate optional Settings flow.
2. For an existing project, apply every migration in
   `supabase/migrations/` in ascending filename order. The current repository
   sequence ends at `202610130001_preserve_tracking_code_counter.sql`; do not stop at an
   older migration cutoff. Confirm the applied migration list against the
   project before applying anything. Migration
   `202610060016_start_tracking_codes_at_100.sql` sets the current-year
   counter to 99 and can lower an existing counter. Never clear reports or
   requests to apply it. After the earlier migrations, apply
   `202610130001_preserve_tracking_code_counter.sql`; it only raises the
   counter to at least 99 and preserves higher current-year values found in
   either the counter table or existing report/request tracking codes. Review
   the resulting counter and codes in staging before production.
   For a new project, run the complete `supabase/schema.sql` script instead of
   replaying the migration history. It requests a PostgREST schema-cache reload
   after creating database objects.
3. Review RLS and Storage policies in the Dashboard. Do not enable broad anonymous read access to reports, requests, user profiles, notifications, or photos.
4. For self-registration, apply the registration and account-flow migrations before opening registration. In **Authentication → Providers → Email**, turn **Confirm email** off, then save. Applicants may request Employee, Assistant, or Personnel; all new accounts are still created inactive and pending. An Admin must confirm or change the requested role in User Management before approval activates the account. Admin cannot be requested during public signup. Never trust client-submitted roles.
5. Configure Cloudflare Turnstile with the production host name.

## 2. Set frontend environment variables

Copy `.env.example` to `.env.local` for local development. In the hosting provider's
production environment, configure:

| Variable | Purpose |
| --- | --- |
| `VITE_SUPABASE_URL` | Public Supabase project URL |
| `VITE_SUPABASE_ANON_KEY` | Supabase publishable/anon key; RLS must remain enabled |
| `VITE_TURNSTILE_SITE_KEY` | Public Cloudflare Turnstile site key |
| `VITE_ALLOWED_EMAIL_DOMAINS` | Comma-separated allowed domains shown in registration UX; align with `public.account_security_settings` in Supabase |
| `VITE_ERROR_REPORT_URL` | Optional public HTTPS error-ingestion endpoint; no credential belongs in this variable |
| `VITE_SMS_NOTIFICATIONS_ENABLED` | `true` only when the server-side SMS provider is configured |
| `VITE_DEMO_MODE` | Keep `false` in production |

Only public/publishable values belong in `VITE_` variables. **Never add
`SUPABASE_SERVICE_ROLE_KEY`, provider secrets, webhook secrets, or the Turnstile
secret to frontend variables.** The service-role key is used only by Supabase
Edge Functions.

Production startup fails closed if Supabase or Turnstile public configuration is
missing, the Supabase URL is not HTTPS, or `VITE_DEMO_MODE=true`. For a custom
error-ingestion endpoint, allow its HTTPS origin in the deployed Content Security
Policy `connect-src`. Client reports omit stack traces and full URLs; validate the
endpoint's CORS, retention, and access controls before enabling it.

## 3. Configure and deploy Edge Functions

Set backend secrets in the Supabase project:

```bash
supabase secrets set TURNSTILE_SECRET_KEY=your-turnstile-secret
supabase secrets set TURNSTILE_ALLOWED_HOSTNAME=unifix.example.edu
supabase secrets set PUBLIC_APP_ORIGINS=https://unifix.example.edu
supabase secrets set NOTIFICATION_WEBHOOK_SECRET=replace-with-a-long-random-secret
supabase secrets set RESEND_API_KEY=your-resend-key
supabase secrets set NOTIFICATION_FROM_EMAIL="UNIFIX <notifications@example.edu>"
supabase secrets set ADMIN_APP_ORIGINS=https://unifix.example.edu
supabase secrets set NOTIFICATION_APP_ORIGINS=https://unifix.example.edu
```

Optional SMS settings (only if SMS is enabled):

```bash
supabase secrets set SEMAPHORE_API_KEY=your-semaphore-key
supabase secrets set SEMAPHORE_SENDER_NAME=UNIFIX
```

Deploy the functions:

```bash
supabase functions deploy submit-public-report
supabase functions deploy track-report
supabase functions deploy swift-worker
supabase functions deploy deliver-notification
supabase functions deploy admin-create-user
supabase functions deploy notification-email-verification
```

The complete per-function environment-variable matrix is in
[ENV_REFERENCE.md](ENV_REFERENCE.md). Supabase supplies `SUPABASE_URL` and
`SUPABASE_ANON_KEY` to Edge Functions; keep `SUPABASE_SERVICE_ROLE_KEY` in the
server-side Supabase environment only. Never copy it into a frontend host
variable or a `VITE_` variable.
The public functions use `PUBLIC_APP_ORIGINS`; the singular
`PUBLIC_APP_ORIGIN` is supported only as a legacy fallback. Function-specific
requirements are:

| Function | Required configuration |
| --- | --- |
| `submit-public-report` | Supabase URL/service-role key, `PUBLIC_APP_ORIGINS`, `TURNSTILE_ALLOWED_HOSTNAME`, `TURNSTILE_SECRET_KEY` |
| `track-report` | Supabase URL/service-role key, `PUBLIC_APP_ORIGINS` |
| `swift-worker` | Supabase URL/anon/service-role keys, `PUBLIC_APP_ORIGINS` |
| `deliver-notification` | Supabase URL/service-role key, `NOTIFICATION_WEBHOOK_SECRET`; Resend settings for email and Semaphore settings for optional SMS |
| `admin-create-user` | Supabase URL/service-role key, `ADMIN_APP_ORIGINS` |
| `notification-email-verification` | Supabase URL/anon/service-role keys, Resend settings, `NOTIFICATION_APP_ORIGINS` (or its `ADMIN_APP_ORIGINS` fallback) |

`swift-worker` also handles public and Employee evaluation submissions; its
checked-in handler validates the evaluation payload and respondent role.

Turn off sign-up confirmation in **Authentication → Providers → Email → Confirm email**.
New registrations then use email as their login ID without requiring an Auth
confirmation message. Users who opt into work-update emails must separately
verify a notification address from **Settings**. The verification function
requires the existing Resend settings above and exact frontend origins. The
registration email is still the account's sign-in ID; this setting does not
verify or change that ID.

`submit-public-report`, `track-report`, and `swift-worker` validate the
request origin, bound request sizes, and use database-backed rate limits. The
first and last functions write through the server-side service role; neither key
is sent to the browser. Public evaluations do not collect identity fields.
Deploy from the linked production project. For local browser testing against
that project, add the exact local origin used by the dev server to
`PUBLIC_APP_ORIGINS` (for example, append
`,http://127.0.0.1:4173`); remove local origins after testing. Do not use `*`.
The function must be deployed before the evaluation form can submit.

In **Database → Webhooks**, configure the Phase 2 `INSERT` notification webhook
and its `x-notification-secret` header. Configure a scheduled job only for
preventive-maintenance generation if automatic scheduling is required.

## 4. Build and deploy

Run the checks before publishing:

```bash
pnpm install --frozen-lockfile
pnpm test
pnpm build
pnpm security:check
```

- **Vercel:** import the repository, set the build command to `pnpm build`, the
  output directory to `dist`, and configure the environment variables above.
  The included `vercel.json` supplies SPA rewrites and security headers.
- **Netlify:** set the build command to `pnpm build` and the publish directory
  to `dist`. The included `public/_redirects` and `public/_headers` are copied
  into the publish directory and provide SPA routing and security headers.

The SPA fallback is needed for `/report?location=<id>` and application routes.
Serve the site over HTTPS so the PWA service worker can register. Verify the
Content Security Policy still permits the configured Supabase project host and
Cloudflare Turnstile if either is customized. Hashed assets are configured for
immutable caching; the HTML entry point is configured not to be cached. The
static `/health.json` endpoint checks frontend hosting only, not Supabase health.

## 5. CI and post-deployment smoke tests

GitHub Actions runs frozen dependency installation, Vitest, the production build,
and the client-secret scan on pushes and pull requests. To run the optional local
Supabase/RLS suite, manually dispatch the workflow with **run_rls** enabled.

For a safe staging smoke test, set `SMOKE_BASE_URL`, `VITE_SUPABASE_URL`, and
`VITE_SUPABASE_ANON_KEY`, then optionally provide dedicated staging account
pairs `SMOKE_EMPLOYEE_EMAIL`/`SMOKE_EMPLOYEE_PASSWORD`,
`SMOKE_ASSISTANT_EMAIL`/`SMOKE_ASSISTANT_PASSWORD`,
`SMOKE_PERSONNEL_EMAIL`/`SMOKE_PERSONNEL_PASSWORD`, and
`SMOKE_ADMIN_EMAIL`/`SMOKE_ADMIN_PASSWORD`. Run:

```bash
pnpm smoke:post-deploy
```

To create a test report and photo, set `SMOKE_TEST_WRITES=true`; report
submission additionally requires a fresh `SMOKE_TEST_CAPTCHA_TOKEN`. Optionally
set `SMOKE_TEST_REPORTER_EMAIL` for the generated report. The report is a real
database record and must be closed/removed through the approved staging
workflow. Eligible public/employee evaluation smoke tests also create
anonymized response rows. The script checks tracking, photo upload/cleanup,
role sign-in/profile, evaluation API eligibility, report notification creation
when an Admin test account is configured, and a read-only due-schedule query.
Browser route visibility and actual cron execution still require the manual
checks in the final section. Do not run write-enabled smoke tests on production.
The complete smoke-test variable list, including which values are test-only,
is in [ENV_REFERENCE.md](ENV_REFERENCE.md).

## 6. Post-deployment checklist

- Confirm public reporting rejects an invalid Turnstile token and accepts a valid one.
- Verify tracking results expose milestones and a generic assigned-team label only.
- Test Employee, Assistant, Personnel, and Admin accounts against the permission matrix in `README.md`.
- Install the PWA, open it once online, then test its offline fallback and queued report drafts.
- Submit a test survey and check the Admin-only aggregated results; ensure no personal identifiers appear.
- Run the SQL RLS suite against a disposable/staging project with `pnpm test:rls`.
- Inspect browser requests and built assets; the Supabase service-role key must never appear.
- Check backups, project-level MFA, Auth redirect URLs, Turnstile allowed hostnames, and notification webhook configuration.

Do not run the demo seed script against production. It is intended for a disposable
defense/demo project only.
