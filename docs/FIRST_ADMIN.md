# First Admin bootstrap

Use this one-time database procedure only when the project has no active Admin.
The first person must first register through UNIFIX with an allowed university
email address. Their profile stays pending until the database promotion below.
New account registration does not require email confirmation. Do not promote an
account by editing a client-side role or by exposing a service-role key.

1. In the Supabase Dashboard, open **SQL Editor** and create a new query.
2. Confirm there is no active Admin:

   ```sql
   select id, email
   from public.user_profiles
   where role = 'Admin' and is_active;
   ```

   Continue only when this returns no rows.

3. Replace the placeholder with the exact registered university email and run:

   ```sql
   select public.bootstrap_first_admin('<CONFIRMED_UNIVERSITY_EMAIL>');
   ```

   The procedure accepts only an Auth account whose linked profile is pending
   and whose domain is in the server-side allowed-domain
   configuration. It promotes that one profile to active Admin and writes the
   account-state audit event. It fails if another active Admin already exists.

4. Verify the result:

   ```sql
   select auth_user_id, email, role, is_active, registration_status
   from public.user_profiles
   where lower(btrim(email)) = lower(btrim('<CONFIRMED_UNIVERSITY_EMAIL>'));
   ```

   The row should show `Admin`, `true`, and `approved`. The bootstrap function
   is not executable by `anon`, `authenticated`, or `service_role`; run it only
   from the trusted SQL Editor session. Once the Admin signs in, all later role
   changes must use the Admin UI and normal audited approval flow.

Never put a real password, API key, or service-role key in this document.
