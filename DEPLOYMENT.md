# UNIFIX production deployment

This guide deploys the Vue/Vite frontend to Vercel or Netlify and uses Supabase
for authentication, Postgres, Storage, and Edge Functions.

## 1. Prepare Supabase

1. Create a production Supabase project and confirm that email/password authentication is enabled.
2. In the SQL Editor, apply the migrations in order:
   `202610050001_phase1_tracking_photos_sla_feedback.sql`,
   `202610050002_phase2_notifications_audit_verification.sql`,
   `202610050003_phase3_analytics_duplicates_locations_maintenance.sql`, and
   `202610050004_phase4_evaluation_security.sql`.
   For a new project, `supabase/schema.sql` contains the current full schema.
3. Review RLS and Storage policies in the Dashboard. Do not enable broad anonymous read access to reports, requests, user profiles, notifications, or photos.
4. Create Auth accounts and matching active `user_profiles` rows. Assign roles in the database; never accept a role from client-controlled registration.
5. Configure Cloudflare Turnstile with the production host name.

## 2. Set frontend environment variables

Copy `.env.example` to `.env.local` for local development. In the hosting provider's
production environment, configure:

| Variable | Purpose |
| --- | --- |
| `VITE_SUPABASE_URL` | Public Supabase project URL |
| `VITE_SUPABASE_ANON_KEY` | Supabase publishable/anon key; RLS must remain enabled |
| `VITE_TURNSTILE_SITE_KEY` | Public Cloudflare Turnstile site key |
| `VITE_SMS_NOTIFICATIONS_ENABLED` | `true` only when the server-side SMS provider is configured |
| `VITE_DEMO_MODE` | Keep `false` in production |

Only public/publishable values belong in `VITE_` variables. **Never add
`SUPABASE_SERVICE_ROLE_KEY`, provider secrets, webhook secrets, or the Turnstile
secret to frontend variables.** The service-role key is used only by Supabase
Edge Functions.

## 3. Configure and deploy Edge Functions

Set backend secrets in the Supabase project:

```bash
supabase secrets set TURNSTILE_SECRET_KEY=your-turnstile-secret
supabase secrets set TURNSTILE_ALLOWED_HOSTNAME=unifix.example.edu
supabase secrets set PUBLIC_APP_ORIGIN=https://unifix.example.edu
supabase secrets set NOTIFICATION_WEBHOOK_SECRET=replace-with-a-long-random-secret
supabase secrets set RESEND_API_KEY=your-resend-key
supabase secrets set NOTIFICATION_FROM_EMAIL="UNIFIX <notifications@example.edu>"
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
supabase functions deploy submit-evaluation
supabase functions deploy deliver-notification
```

`submit-public-report`, `track-report`, and `submit-evaluation` validate the
request origin, bound request sizes, and use database-backed rate limits. The
first and last functions write through the server-side service role; neither key
is sent to the browser. Public evaluations do not collect identity fields.

In **Database → Webhooks**, configure the Phase 2 `INSERT` notification webhook
and its `x-notification-secret` header. Use the cron setup for overdue alerts
and preventive work orders in `README.md` if automatic scheduling is required.

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
Cloudflare Turnstile if either is customized.

## 5. Post-deployment checklist

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
