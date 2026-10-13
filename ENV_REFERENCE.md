# UNIFIX Environment Reference

This file documents the expected environment variables for the project and which are safe to expose to the browser.

## Frontend/public variables (`VITE_*`)

| Variable | Required | Safe in browser | Notes |
| --- | --- | --- | --- |
| `VITE_SUPABASE_URL` | Yes | Yes | Public project URL for Supabase API access. |
| `VITE_SUPABASE_ANON_KEY` | Yes | Yes | Public anon key; RLS must remain enforced. |
| `VITE_TURNSTILE_SITE_KEY` | Yes in production | Yes | Public Turnstile site key. |
| `VITE_ALLOWED_EMAIL_DOMAINS` | Optional | Yes | Comma-separated registration domains shown in the UI; must match the server-side `account_security_settings` value. Defaults to `nvsu.edu.ph` for UX only. |
| `VITE_ERROR_REPORT_URL` | Optional | Yes | Optional public ingestion endpoint for sanitized error reports. |
| `VITE_SMS_NOTIFICATIONS_ENABLED` | Optional | Yes | Must be `true` only when the backend SMS provider is configured. |
| `VITE_DEMO_MODE` | Optional | Yes | Must remain `false` in production. |

## Server-side variables (never expose to the client)

Supabase Edge Functions also receive `SUPABASE_URL` and `SUPABASE_ANON_KEY`
from the Supabase platform. These are project configuration values, not
`VITE_` variables; the anon key is public by design and remains subject to RLS.

| Variable | Required | Secret | Notes |
| --- | --- | --- | --- |
| `SUPABASE_SERVICE_ROLE_KEY` | Platform-provided; required by functions that perform privileged database operations | Yes | Never expose in frontend code, browser variables, or logs. |
| `TURNSTILE_SECRET_KEY` | `submit-public-report` | Yes | Verifies public report CAPTCHA tokens. |
| `TURNSTILE_ALLOWED_HOSTNAME` | `submit-public-report` | No | Allowed production hostname for CAPTCHA validation. |
| `PUBLIC_APP_ORIGINS` | Public functions | No | Comma-separated exact origins accepted by public functions. `PUBLIC_APP_ORIGIN` is a legacy singular fallback. Do not use `*`. |
| `PUBLIC_APP_ORIGIN` | Legacy fallback for public functions | No | Use `PUBLIC_APP_ORIGINS` for new deployments. |
| `NOTIFICATION_WEBHOOK_SECRET` | `deliver-notification` | Yes | Shared secret expected in the notification webhook header. |
| `RESEND_API_KEY` | Email delivery/verification | Yes | Resend provider key. |
| `NOTIFICATION_FROM_EMAIL` | Email delivery/verification | No | Verified sender identity used for outgoing mail. |
| `NOTIFICATION_APP_ORIGINS` | `notification-email-verification` | No | Comma-separated exact frontend origins. Falls back to `ADMIN_APP_ORIGINS`. |
| `ADMIN_APP_ORIGINS` | `admin-create-user` | No | Comma-separated exact frontend origins. Also the fallback for notification verification. |
| `SEMAPHORE_API_KEY` | Optional SMS delivery | Yes | Semaphore provider key; required only if SMS sending is enabled. |
| `SEMAPHORE_SENDER_NAME` | Optional SMS delivery | No | Sender name configured with Semaphore. |

## Post-deployment smoke-test variables

These are local operator environment variables for `pnpm smoke:post-deploy`;
they are not Vite settings and must not be configured as public frontend
variables. Run the script against staging only.

| Variable | Required | Notes |
| --- | --- | --- |
| `SMOKE_BASE_URL` | Yes | Deployed staging frontend origin. |
| `VITE_SUPABASE_URL` | Yes | Staging Supabase URL supplied to the test script. |
| `VITE_SUPABASE_ANON_KEY` | Yes | Staging public anon key supplied to the test script. |
| `SMOKE_EMPLOYEE_EMAIL`, `SMOKE_EMPLOYEE_PASSWORD` | Optional | Dedicated staging Employee test account. |
| `SMOKE_ASSISTANT_EMAIL`, `SMOKE_ASSISTANT_PASSWORD` | Optional | Dedicated staging Assistant test account. |
| `SMOKE_PERSONNEL_EMAIL`, `SMOKE_PERSONNEL_PASSWORD` | Optional | Dedicated staging Personnel test account. |
| `SMOKE_ADMIN_EMAIL`, `SMOKE_ADMIN_PASSWORD` | Optional | Dedicated staging Admin test account. |
| `SMOKE_TEST_WRITES` | Optional | Set to `true` only when approved to create test rows and upload/delete a temporary Storage object in staging. Do not set for production. |
| `SMOKE_TEST_CAPTCHA_TOKEN` | Required for write-enabled public report test | Fresh Turnstile token for the staging hostname. |
| `SMOKE_TEST_REPORTER_EMAIL` | Optional | Email attached to the generated staging test report. |

## Edge Function inventory

| Function | Required project settings/secrets |
| --- | --- |
| `submit-public-report` | Platform `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`; `PUBLIC_APP_ORIGINS` (or legacy `PUBLIC_APP_ORIGIN`); `TURNSTILE_ALLOWED_HOSTNAME`; `TURNSTILE_SECRET_KEY`. |
| `track-report` | Platform `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`; `PUBLIC_APP_ORIGINS` (or legacy `PUBLIC_APP_ORIGIN`). |
| `swift-worker` | Platform `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`; `PUBLIC_APP_ORIGINS` (or legacy `PUBLIC_APP_ORIGIN`). Also handles public and Employee evaluation submissions with role and payload validation. |
| `deliver-notification` | Platform `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`; `NOTIFICATION_WEBHOOK_SECRET`. Configure `RESEND_API_KEY` and `NOTIFICATION_FROM_EMAIL` for email; configure both Semaphore values only if SMS is used. |
| `admin-create-user` | Platform `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`; `ADMIN_APP_ORIGINS`. |
| `notification-email-verification` | Platform `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`; `RESEND_API_KEY`, `NOTIFICATION_FROM_EMAIL`, and `NOTIFICATION_APP_ORIGINS` (or `ADMIN_APP_ORIGINS`). |

## Deployment note

New account registration expects Supabase Email **Confirm email** to be disabled.
Notification-email verification uses the Resend credentials and sender identity
already used by `deliver-notification`; set `NOTIFICATION_APP_ORIGINS` to the
exact production frontend origin.

The project intentionally fails closed when required public configuration is missing. Never place server-only credentials in the frontend bundle or in repository files that are committed to source control.
