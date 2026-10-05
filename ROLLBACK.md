# UNIFIX Rollback Guide

This document describes how to revert the main components of the UNIFIX deployment safely.

## 1. Roll back the frontend

### Option A: redeploy a previous build

1. Open the Vercel or Netlify project dashboard.
2. Navigate to the deployment history.
3. Select the last known-good production deployment.
4. Promote or redeploy that version.
5. Verify the DNS, custom domain, and env vars are still pointing to the correct project.

### Option B: revert the Git branch

1. Identify the last stable commit.
2. Revert the problematic merge or commit with `git revert <sha>`.
3. Push the revert to the default branch.
4. Trigger a fresh production build.

### Validation

- Confirm the frontend loads over HTTPS.
- Confirm the app renders the homepage without a white-screen failure.
- Confirm critical routes and auth flows still work.

## 2. Roll back a database migration

Database rollback should be handled carefully because application data may depend on a migration.

### Safe practice

1. Back up the production database before applying a new migration.
2. If a migration is reversible, run the reverse SQL in a transaction or a dedicated rollback script.
3. If the migration introduced schema changes that would break the app, restore from the nearest valid backup.

### Example recovery pattern

- Use Supabase database backups or manual exports.
- Restore the database to the last known good snapshot.
- Re-run the earlier stable migration chain if required.
- Recheck RLS policies and triggers after restore.

## 3. Roll back an Edge Function

1. Open the Supabase project dashboard.
2. Navigate to Edge Functions.
3. Redeploy the last known-good version or disable the failing function.
4. Confirm the environment secrets are still valid.
5. Re-test the public or admin paths that depend on the function.

If the function is not working because of a secret issue, restore the correct secret values first, then redeploy.

## 4. Roll back configuration changes

If a production issue is caused by environment or host config:

1. Restore the previous env variables.
2. Revert custom header or rewrite settings.
3. Verify the CORS and CSP rules are still valid.
4. Confirm the domain's SSL cert and redirect rules are still in place.

## 5. Operational checklist after rollback

- [ ] Verify homepage loads
- [ ] Verify public report flow works
- [ ] Verify login and role routes work
- [ ] Verify notifications still fire correctly
- [ ] Verify audit history and SLA logic remain consistent
- [ ] Check if any partial or duplicate records were created during the incident
- [ ] Communicate the rollback to stakeholders and note the impacted window

## 6. Recovery principle

The safest rollback is usually:

1. freeze the release,
2. revert the frontend,
3. restore the correct database state,
4. redeploy the last good Edge Function,
5. verify the application critical path before reopening production access.
