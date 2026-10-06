begin;
select plan(36);

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('a6100000-0000-4000-8000-000000000001', 'authenticated', 'authenticated',
   'flow-pending@nvsu.edu.ph', '', now(), '{}'::jsonb,
   '{"name":"Pending Flow User","role":"Admin"}'::jsonb, now(), now()),
  ('a6100000-0000-4000-8000-000000000002', 'authenticated', 'authenticated',
   'flow-reactivation@nvsu.edu.ph', '', now(), '{}'::jsonb,
   '{"name":"Reactivation Flow User"}'::jsonb, now(), now()),
  ('a6100000-0000-4000-8000-000000000003', 'authenticated', 'authenticated',
   'flow-bootstrap-admin@nvsu.edu.ph', '', now(), '{}'::jsonb,
   '{"name":"Flow Admin"}'::jsonb, now(), now()),
  ('a6100000-0000-4000-8000-000000000004', 'authenticated', 'authenticated',
   'flow-approval@nvsu.edu.ph', '', now(), '{}'::jsonb,
   '{"name":"Approval Flow User"}'::jsonb, now(), now()),
  ('a6100000-0000-4000-8000-000000000005', 'authenticated', 'authenticated',
   'flow-email-sync@nvsu.edu.ph', '', now(), '{}'::jsonb,
   '{"name":"Email Sync Flow User"}'::jsonb, now(), now());

select throws_ok(
  $$insert into auth.users (
      id, aud, role, email, encrypted_password, raw_user_meta_data, created_at, updated_at
    ) values (
      'a6100000-0000-4000-8000-000000000006', 'authenticated', 'authenticated',
      'flow-outsider@example.net', '', '{}'::jsonb, now(), now()
    )$$,
  'P0001',
  'Auth rejects registration for a non-allowed email domain'
);

select is(
  (select role from public.user_profiles where auth_user_id = 'a6100000-0000-4000-8000-000000000001'),
  'Employee',
  'Signup ignores role metadata and creates an Employee profile'
);
select is(
  (select registration_status from public.user_profiles where auth_user_id = 'a6100000-0000-4000-8000-000000000001'),
  'pending',
  'Signup creates a pending profile'
);
select is(
  (select is_active from public.user_profiles where auth_user_id = 'a6100000-0000-4000-8000-000000000001'),
  false,
  'Signup creates an inactive profile'
);
select is(
  public.current_user_role(),
  null::text,
  'Unauthenticated role lookup does not grant access'
);
select set_config(
  'request.jwt.claims',
  '{"role":"authenticated","sub":"a6100000-0000-4000-8000-000000000005","email":"flow-email-sync@nvsu.edu.ph"}',
  true
);
update auth.users
set email = 'flow-email-sync-updated@nvsu.edu.ph'
where id = 'a6100000-0000-4000-8000-000000000005';
select is(
  (select email from public.user_profiles where auth_user_id = 'a6100000-0000-4000-8000-000000000005'),
  'flow-email-sync-updated@nvsu.edu.ph',
  'Auth email changes update the linked profile email'
);
select is(
  (select auth_user_id from public.user_profiles where email = 'flow-email-sync-updated@nvsu.edu.ph'),
  'a6100000-0000-4000-8000-000000000005'::uuid,
  'Auth email changes preserve the profile Auth ID link'
);
select set_config('request.jwt.claims', '{"role":"anon"}', true);

insert into public.user_profiles (id, name, email, role, department, is_active, registration_status)
values ('flow-legacy-profile', 'Legacy Flow User', 'flow-legacy@nvsu.edu.ph', 'Employee', 'Testing', true, 'approved');
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"role":"authenticated","sub":"a6100000-0000-4000-8000-000000000099","email":"flow-legacy@nvsu.edu.ph"}',
  true
);
select is(public.current_user_role(), 'Employee', 'Legacy unlinked profiles still resolve by email');
reset role;

insert into public.reports (
  id, title, category, location, reporter, reporter_email, report_date
) values (
  'flow-pending-report', 'Pending access test', 'Other', 'Test location',
  'Pending Flow User', 'flow-pending@nvsu.edu.ph', 'Oct 06, 2026'
);
insert into public.requests (
  id, title, category, department, details, requester, requester_email, request_date
) values (
  'flow-pending-request', 'Pending access test', 'Other', 'Testing',
  'Pending access test fixture', 'Pending Flow User', 'flow-pending@nvsu.edu.ph', 'Oct 06, 2026'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"role":"authenticated","sub":"a6100000-0000-4000-8000-000000000001","email":"flow-pending@nvsu.edu.ph"}',
  true
);
select is((select count(*) from public.reports where id = 'flow-pending-report'), 0::bigint,
  'Pending users cannot read work reports');
select is((select count(*) from public.requests where id = 'flow-pending-request'), 0::bigint,
  'Pending users cannot read work requests');
select throws_ok(
  $$insert into public.reports (id, title, category, location, reporter, report_date)
    values ('flow-pending-write', 'Pending write test', 'Other', 'Test location', 'Pending Flow User', 'Oct 06, 2026')$$,
  '42501',
  'Pending users cannot write work items'
);
select throws_ok(
  $$insert into public.requests (id, title, category, department, details, requester, request_date)
    values ('flow-pending-request-write', 'Pending write test', 'Other', 'Testing', 'Pending write test', 'Pending Flow User', 'Oct 06, 2026')$$,
  '42501',
  'Pending users cannot write requests'
);
select throws_ok(
  $$update public.user_profiles set role = 'Admin' where auth_user_id = 'a6100000-0000-4000-8000-000000000001'$$,
  'P0001',
  'A user cannot update their own role'
);
select throws_ok(
  $$update public.user_profiles set registration_status = 'approved', is_active = true where auth_user_id = 'a6100000-0000-4000-8000-000000000001'$$,
  'P0001',
  'A user cannot approve their own registration'
);
reset role;

select set_config('request.jwt.claims', '{"role":"service_role"}', true);
update public.user_profiles
set registration_status = 'approved', is_active = false
where auth_user_id = 'a6100000-0000-4000-8000-000000000002';
update public.user_profiles
set role = 'Admin', registration_status = 'approved', is_active = true
where auth_user_id = 'a6100000-0000-4000-8000-000000000003';

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"role":"authenticated","sub":"a6100000-0000-4000-8000-000000000002","email":"flow-reactivation@nvsu.edu.ph"}',
  true
);
select throws_ok(
  $$update public.user_profiles set is_active = true where auth_user_id = 'a6100000-0000-4000-8000-000000000002'$$,
  'P0001',
  'A user cannot reactivate their own account'
);
select is(
  (select is_active from public.user_profiles where auth_user_id = 'a6100000-0000-4000-8000-000000000002'),
  false,
  'The rejected self-reactivation leaves the profile inactive'
);
select is(
  (select count(*) from public.reports where id = 'flow-pending-report'),
  0::bigint,
  'Deactivated users cannot read work items'
);
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"role":"authenticated","sub":"a6100000-0000-4000-8000-000000000003","email":"flow-bootstrap-admin@nvsu.edu.ph"}',
  true
);
update public.user_profiles
set is_active = true
where auth_user_id = 'a6100000-0000-4000-8000-000000000002';
select is(
  (select is_active from public.user_profiles where auth_user_id = 'a6100000-0000-4000-8000-000000000002'),
  true,
  'An Admin can reactivate an approved account'
);
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"role":"authenticated","sub":"a6100000-0000-4000-8000-000000000002","email":"flow-reactivation@nvsu.edu.ph"}',
  true
);
update public.user_profiles
set registration_status = 'approved', is_active = true
where auth_user_id = 'a6100000-0000-4000-8000-000000000004';
select is(
  (select registration_status from public.user_profiles where auth_user_id = 'a6100000-0000-4000-8000-000000000004'),
  'pending',
  'A non-Admin cannot approve another account'
);
update public.user_profiles
set registration_status = 'rejected', is_active = false, rejection_reason = 'Unauthorized rejection'
where auth_user_id = 'a6100000-0000-4000-8000-000000000001';
select is(
  (select registration_status from public.user_profiles where auth_user_id = 'a6100000-0000-4000-8000-000000000001'),
  'pending',
  'A non-Admin cannot reject another account'
);
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"role":"authenticated","sub":"a6100000-0000-4000-8000-000000000003","email":"flow-bootstrap-admin@nvsu.edu.ph"}',
  true
);
update public.user_profiles
set registration_status = 'rejected', is_active = false, rejection_reason = 'Application test rejection'
where auth_user_id = 'a6100000-0000-4000-8000-000000000001';
select is(
  (select registration_status from public.user_profiles where auth_user_id = 'a6100000-0000-4000-8000-000000000001'),
  'rejected',
  'An Admin can reject an application'
);
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"role":"authenticated","sub":"a6100000-0000-4000-8000-000000000003","email":"flow-bootstrap-admin@nvsu.edu.ph"}',
  true
);
select throws_ok(
  $$select public.reopen_rejected_registration('a6100000-0000-4000-8000-000000000001')$$,
  'P0001',
  'An Admin cannot reopen an application before the applicant reapplies'
);
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"role":"authenticated","sub":"a6100000-0000-4000-8000-000000000001","email":"flow-pending@nvsu.edu.ph"}',
  true
);
select is((select count(*) from public.reports where id = 'flow-pending-report'), 0::bigint,
  'Rejected users cannot read reports');
select is((select count(*) from public.requests where id = 'flow-pending-request'), 0::bigint,
  'Rejected users cannot read requests');
select throws_ok(
  $$insert into public.reports (id, title, category, location, reporter, report_date)
    values ('flow-rejected-report-write', 'Rejected write test', 'Other', 'Test location', 'Pending Flow User', 'Oct 06, 2026')$$,
  '42501',
  'Rejected users cannot write reports'
);
select throws_ok(
  $$insert into public.requests (id, title, category, department, details, requester, request_date)
    values ('flow-rejected-write', 'Rejected write test', 'Other', 'Testing', 'Rejected write test', 'Pending Flow User', 'Oct 06, 2026')$$,
  '42501',
  'Rejected users cannot write work items'
);
select is(
  public.request_registration_reapplication() is not null,
  true,
  'A rejected user may request another review'
);
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"role":"authenticated","sub":"a6100000-0000-4000-8000-000000000003","email":"flow-bootstrap-admin@nvsu.edu.ph"}',
  true
);
select public.reopen_rejected_registration('a6100000-0000-4000-8000-000000000001');
select is(
  (select registration_status from public.user_profiles where auth_user_id = 'a6100000-0000-4000-8000-000000000001'),
  'pending',
  'An Admin can explicitly reopen a rejected application'
);
update public.user_profiles
set registration_status = 'approved', is_active = true, role = 'Assistant'
where auth_user_id = 'a6100000-0000-4000-8000-000000000004';
select is(
  (select role from public.user_profiles where auth_user_id = 'a6100000-0000-4000-8000-000000000004'),
  'Assistant',
  'An Admin can approve a pending user and assign a role'
);
select ok(
  exists (
    select 1 from public.account_audit_log
    where actor_auth_user_id = 'a6100000-0000-4000-8000-000000000003'
      and target_auth_user_id = 'a6100000-0000-4000-8000-000000000004'
      and action in ('user_role_changed', 'registration_approved')
      and created_at is not null
  ),
  'Admin approval and role assignment are audited with actor and timestamp'
);
select throws_ok(
  $$select * from public.begin_notification_email_verification(
    'updates@example.com', 'a6100000-0000-4000-8000-000000000003'
  )$$,
  '42501',
  'An authenticated client cannot retrieve the notification verification token'
);
insert into public.user_preferences (
  user_email, notification_email, notification_email_verified, email_notifications
) values (
  'flow-bootstrap-admin@nvsu.edu.ph', 'updates@example.com', true, true
);
select is(
  (select notification_email_verified from public.user_preferences
   where user_email = 'flow-bootstrap-admin@nvsu.edu.ph'),
  false,
  'A client cannot mark a notification email verified on insert'
);
select is(
  (select email_notifications from public.user_preferences
   where user_email = 'flow-bootstrap-admin@nvsu.edu.ph'),
  false,
  'Email updates remain off for an unverified notification email'
);
select throws_ok(
  $$update public.user_preferences
    set notification_email_verified = true
    where user_email = 'flow-bootstrap-admin@nvsu.edu.ph'$$,
  'P0001',
  'A client cannot mark a notification email verified on update'
);
reset role;

select set_config('request.jwt.claims', '{"role":"service_role"}', true);
update public.user_profiles
set role = 'Assistant'
where role = 'Admin'
  and is_active
  and auth_user_id is distinct from 'a6100000-0000-4000-8000-000000000003';
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"role":"authenticated","sub":"a6100000-0000-4000-8000-000000000003","email":"flow-bootstrap-admin@nvsu.edu.ph"}',
  true
);
select throws_ok(
  $$update public.user_profiles set is_active = false where auth_user_id = 'a6100000-0000-4000-8000-000000000003'$$,
  'P0001',
  'The last active Admin cannot be deactivated'
);
reset role;
select throws_ok(
  $$delete from auth.users where id = 'a6100000-0000-4000-8000-000000000003'$$,
  'P0001',
  'The last active Admin cannot be deleted'
);

select * from finish();
rollback;
