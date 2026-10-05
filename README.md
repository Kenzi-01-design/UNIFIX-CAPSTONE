# UNIFIX

UNIFIX is a Vue and Vite campus maintenance reporting application. Supabase provides its production backend (Postgres, authentication, and row-level authorization).

## Development

```bash
pnpm install
pnpm dev
```

## Supabase setup

Supabase is prepared as the database layer for reports, requests, and login events.

1. Create a Supabase project.
2. Copy `.env.example` to `.env.local`.
3. Set `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` from the project API settings.
4. Run `supabase/schema.sql` in the Supabase SQL Editor for a new project. For an existing project, apply the relevant additive scripts in `supabase/migrations/`.
5. Create the matching accounts in **Authentication → Users** using the emails in `user_profiles`.
6. Deploy the public and notification Edge Functions after setting the CAPTCHA, allowed-origin, and notification values below.

### Phase 1 capabilities

- Report and request images are compressed in the browser and stored in the private `report-photos` bucket (up to three JPG/PNG/WebP images per work item, at most 5 MB each).
- Every report and request receives a database-generated tracking code. The public tracking page reveals only milestone status, a generic assigned team label, and the last update time.
- Administrators can set Low, Medium, High, and Urgent SLA target times. Active report and request lists show remaining or overdue time.
- A reporter can submit one 1–5 rating and optional comment after a report is completed. Administrators and assistants can see report average ratings.

### Public report CAPTCHA

The public report form uses Cloudflare Turnstile. Add the widget's **site key** to
`VITE_TURNSTILE_SITE_KEY` and configure the allowed hostname in the Turnstile dashboard.
Then deploy the included Edge Function and store the Turnstile **secret key** only
in Supabase (never in `.env.local` or the frontend):

```bash
supabase secrets set TURNSTILE_SECRET_KEY=your-turnstile-secret-key
supabase secrets set TURNSTILE_ALLOWED_HOSTNAME=unifix.nvsu.edu.ph
supabase secrets set PUBLIC_APP_ORIGIN=https://your-production-hostname
supabase functions deploy submit-public-report
supabase functions deploy track-report
```

The function verifies each token with Cloudflare before inserting the anonymous
report with its service role. `supabase/config.toml` deliberately allows this
function to be called without a user JWT; Turnstile verification is the gate.

### Phase 2 notifications and workflow

- Reports and requests now move from **In progress** to **For verification** when personnel submit completed work. Admins or assistants can verify and close the item, or reject it with a reason to return it for rework. The submitter can reopen a closed item within seven days using its tracking code; authenticated callers can also use an owner-checked reopen RPC.
- In-app notification feeds are private to each signed-in email and update through Supabase Realtime. Notification settings separately control in-app, email, and SMS delivery.
- Status, assignment, priority, and submission events are recorded in the append-only `audit_log`. Staff can see per-report activity; administrators can filter and export the global audit history.
- Email uses Resend. SMS uses the optional Semaphore adapter and stays disabled in the UI unless `VITE_SMS_NOTIFICATIONS_ENABLED=true` is set in the deployed frontend and the matching provider credentials are configured in Supabase.

Apply `supabase/migrations/202610050002_phase2_notifications_audit_verification.sql` to an existing project, or use the updated `supabase/schema.sql` for a fresh project. Set the server-only provider credentials (never put these in a `VITE_` variable):

```bash
supabase secrets set NOTIFICATION_WEBHOOK_SECRET=replace-with-a-long-random-secret
supabase secrets set RESEND_API_KEY=replace-with-resend-key
supabase secrets set NOTIFICATION_FROM_EMAIL="UNIFIX <notifications@example.edu>"
# Optional SMS provider:
supabase secrets set SEMAPHORE_API_KEY=replace-with-semaphore-key
supabase secrets set SEMAPHORE_SENDER_NAME=UNIFIX
supabase functions deploy deliver-notification
```

In **Database → Webhooks**, create an `INSERT` webhook on `public.notification_deliveries` targeting
`https://<project-ref>.supabase.co/functions/v1/deliver-notification`. Add the
`x-notification-secret` HTTP header with the same secret stored as
`NOTIFICATION_WEBHOOK_SECRET`. The Edge Function authenticates this shared-secret
header; its JWT verification is disabled in `supabase/config.toml`.

To notify administrators about overdue work, enable `pg_cron`, `pg_net`, and Vault
for the Supabase project. In the SQL Editor, store the function URL and the same
webhook secret in Vault, then schedule an hourly `POST` (replace the placeholders
before running this SQL):

```sql
select vault.create_secret(
  'https://<project-ref>.supabase.co/functions/v1/deliver-notification',
  'unifix_notification_function_url'
);
select vault.create_secret('<same-random-secret>', 'unifix_notification_webhook_secret');

select cron.schedule(
  'unifix-overdue-sweep',
  '0 * * * *',
  $job$
    select net.http_post(
      url := (select decrypted_secret from vault.decrypted_secrets
              where name = 'unifix_notification_function_url'),
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-notification-secret', (select decrypted_secret from vault.decrypted_secrets
                                  where name = 'unifix_notification_webhook_secret')
      ),
      body := '{"action":"overdue-sweep"}'::jsonb
    );
  $job$
);
```

The sweep deduplicates overdue alerts by work item, administrator, and calendar
day. Failed email/SMS deliveries are retried on the next sweep.

The schema migration backfills requester contact emails where a profile can be
matched. Public report status emails are optional and sent only when the reporter
provides an email address. Public tracking remains limited to milestone dates,
the generic maintenance-team label, and the last update; it never returns names,
contact details, or internal remarks.

The app uses local demo data whenever `VITE_DEMO_MODE=true`, even if local Supabase values are present. Never commit `.env.local`.

For local-only demo mode without Supabase, explicitly set `VITE_DEMO_MODE=true`. Do not enable this in a deployed environment; the demo data is intentionally client-side and is not an authentication boundary.

### Backend behavior

The schema creates reports, requests, login events, user profiles, and persisted user preferences. It also enables Row Level Security:

- authenticated reporters can create and view their own reports/requests;
- administrators manage all records and user profiles;
- assistants can adjust risk and review submissions;
- assigned personnel can progress only their own work orders; and
- users can edit only their own contact details and notification preferences.

The Phase 1 migration creates the private `report-photos` bucket and its storage policies, the `sla_settings` and `report_feedback` tables, tracking-code/deadline triggers, and a private rate-limit store used by `track-report`. The tracking function requires the existing `PUBLIC_APP_ORIGIN` (or `PUBLIC_APP_ORIGINS`) Supabase secret to allow the deployed frontend origin.

Create the matching Supabase Auth users before signing in. Profile records use the same email address as the Auth user; roles are never accepted from the browser in production.

## Security note

The database policies require Supabase Auth and match authenticated email addresses to `user_profiles`. Roles are loaded from the database after sign-in; the role picker is shown only in explicitly enabled local demo mode. The open demo policies have been removed from the schema.
