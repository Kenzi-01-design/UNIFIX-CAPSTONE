# UNIFIX Environment Reference

This file documents the expected environment variables for the project and which are safe to expose to the browser.

## Frontend/public variables (`VITE_*`)

| Variable | Required | Safe in browser | Notes |
| --- | --- | --- | --- |
| `VITE_SUPABASE_URL` | Yes | Yes | Public project URL for Supabase API access. |
| `VITE_SUPABASE_ANON_KEY` | Yes | Yes | Public anon key; RLS must remain enforced. |
| `VITE_TURNSTILE_SITE_KEY` | Yes in production | Yes | Public Turnstile site key. |
| `VITE_ERROR_REPORT_URL` | Optional | Yes | Optional public ingestion endpoint for sanitized error reports. |
| `VITE_SMS_NOTIFICATIONS_ENABLED` | Optional | Yes | Must be `true` only when the backend SMS provider is configured. |
| `VITE_DEMO_MODE` | Optional | Yes | Must remain `false` in production. |

## Server-side variables (never expose to the client)

| Variable | Required | Secret | Notes |
| --- | --- | --- | --- |
| `SUPABASE_SERVICE_ROLE_KEY` | Only in server code | Yes | Never in the frontend or public config. |
| `TURNSTILE_SECRET_KEY` | Yes for public validation | Yes | Used by the captcha verification flow. |
| `TURNSTILE_ALLOWED_HOSTNAME` | Yes | No | Public host allowed by captcha validation. |
| `PUBLIC_APP_ORIGIN` | Yes for public functions | No | Production origin used to validate request behavior. |
| `NOTIFICATION_WEBHOOK_SECRET` | Yes for notifications | Yes | Shared secret for notification webhooks. |
| `RESEND_API_KEY` | Optional | Yes | Email delivery provider key. |
| `NOTIFICATION_FROM_EMAIL` | Optional | No | Sender identity for outbound email. |
| `SEMAPHORE_API_KEY` | Optional | Yes | SMS provider key. |
| `SEMAPHORE_SENDER_NAME` | Optional | No | SMS sender name. |

## Deployment note

The project intentionally fails closed when required public configuration is missing. Never place server-only credentials in the frontend bundle or in repository files that are committed to source control.
