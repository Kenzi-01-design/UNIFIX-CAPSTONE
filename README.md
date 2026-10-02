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
4. Run `supabase/schema.sql` in the Supabase SQL Editor. It is safe to re-run when upgrading an existing project.
5. Create the matching accounts in **Authentication → Users** using the emails in `user_profiles`.

### Public report CAPTCHA

The public report form uses Cloudflare Turnstile. Add the widget's **site key** to
`VITE_TURNSTILE_SITE_KEY` and configure the allowed hostname in the Turnstile dashboard.
Then deploy the included Edge Function and store the Turnstile **secret key** only
in Supabase (never in `.env.local` or the frontend):

```bash
supabase secrets set TURNSTILE_SECRET_KEY=your-turnstile-secret-key
supabase functions deploy submit-public-report
```

The function verifies each token with Cloudflare before inserting the anonymous
report with its service role. `supabase/config.toml` deliberately allows this
function to be called without a user JWT; Turnstile verification is the gate.

The app continues to use its local demo data until the Supabase project credentials are configured. Never commit `.env.local`.

### Backend behavior

The schema creates reports, requests, login events, user profiles, and persisted user preferences. It also enables Row Level Security:

- authenticated reporters can create and view their own reports/requests;
- administrators manage all records and user profiles;
- assistants can change priority only;
- assigned personnel can progress only their own work orders; and
- users can edit only their own contact details and notification preferences.

Create the matching Supabase Auth users before signing in. Profile records use the same email address as the Auth user; roles are never accepted from the browser in production.

## Security note

The database policies require Supabase Auth and match authenticated email addresses to `user_profiles`. Roles are loaded from the database after sign-in; the role picker is shown only when Supabase is not configured for local demo mode. The open demo policies have been removed from the schema.
