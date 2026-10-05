# UNIFIX Known Limitations

This document records the known limitations and scope boundaries for the UNIFIX capstone implementation and deployment preparation.

## 1. Live backend verification remains external

The project was validated locally with build, unit tests, and client-side security checks. Real Supabase Postgres/RLS execution, storage policy validation, Edge Function deployment, and provider integrations were not run against a live project in this environment.

## 2. Real-world provider setup is required externally

The following items depend on external accounts and dashboard steps that are outside this repository and require account setup by the project owner:

- Supabase production project and database configuration
- Cloudflare Turnstile site/secret key setup
- Resend or SMTP email provider configuration
- Optional Semaphore SMS provider access
- DNS and custom-domain configuration on the hosting provider

## 3. Cron and scheduled jobs are environment-dependent

Preventive maintenance generation and overdue sweeps rely on supported scheduling features in the target Supabase or hosting environment. These were implemented to be deployable, but final execution must be validated in the production project.

## 4. Privacy and data-retention policy are outside the code scope

The system stores names, contact information, and image attachments. The code provides the technical controls, but legal and institutional policy decisions regarding retention, consent, and compliance remain the responsibility of the deploying organization.

## 5. Demo mode is intentionally separate from production

The app includes a local demo mode to keep development and demonstrations usable without a live backend. Demo mode must never be activated in production and should be explicitly disabled on live deployments.

## 6. Human validation is required for final release

The final go-live decision still requires manual checks for UI role gating, live RLS behavior, browser route protection, public submission, and provider delivery flows in a real staging or production environment.

## 7. Scope boundary for this thesis project

This implementation covers the campus maintenance reporting workflows, role-based access, operational dashboards, and production-hardening documentation needed for a capstone evaluation. It does not replace formal institutional IT compliance procedures or a full-scale production operations environment.
