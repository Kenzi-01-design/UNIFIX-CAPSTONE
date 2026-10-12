begin;
select plan(26);

insert into public.user_profiles (id, name, email, role, department)
values
  ('phase4-rls-admin', 'Phase 4 Admin', 'admin.user@nvsu.edu.ph', 'Admin', 'Testing'),
  ('phase4-rls-assistant', 'Phase 4 Assistant', 'assistant.user@nvsu.edu.ph', 'Assistant', 'Testing'),
  ('phase4-rls-employee', 'Prof. Reyes', 'prof.reyes@nvsu.edu.ph', 'Employee', 'Testing'),
  ('phase4-rls-personnel', 'Juan dela Cruz', 'juan.delacruz@nvsu.edu.ph', 'Personnel', 'Testing'),
  ('phase4-rls-target', 'Test Role Target', 'phase4-target@nvsu.edu.ph', 'Employee', 'Testing'),
  ('phase5-rls-same-name', 'Other Employee', 'phase5-same-name@nvsu.edu.ph', 'Employee', 'Testing')
on conflict (email) do update set
  name = excluded.name,
  role = excluded.role,
  department = excluded.department,
  is_active = true;

insert into public.reports (
  id, title, description, category, location, reporter, reporter_email, report_date,
  assigned_personnel, assigned_to, status, technician_state
)
values
  ('phase4-rls-own-report', 'RLS own report fixture', 'A sample report for isolation testing.', 'Other', 'Test location', 'Prof. Reyes', 'prof.reyes@nvsu.edu.ph', 'Oct 05, 2026', '[]'::jsonb, null, 'pending', 'unassigned'),
  ('phase4-rls-assigned-report', 'RLS assigned report fixture', 'A sample assigned report for isolation testing.', 'Other', 'Test location', 'Other Reporter', null, 'Oct 05, 2026', '["Juan dela Cruz"]'::jsonb, 'Juan dela Cruz', 'in-progress', 'assigned'),
  ('phase4-rls-unassigned-report', 'RLS unassigned report fixture', 'A sample unassigned report for isolation testing.', 'Other', 'Test location', 'Juan dela Cruz', 'juan.delacruz@nvsu.edu.ph', 'Oct 05, 2026', '[]'::jsonb, null, 'pending', 'unassigned'),
  ('phase5-rls-closed-assignment', 'Closed assignment fixture', 'A closed report cannot be assigned.', 'Other', 'Test location', 'Other Reporter', null, 'Oct 05, 2026', '[]'::jsonb, null, 'closed', 'completed'),
  ('phase5-rls-duplicate-parent', 'Duplicate parent fixture', 'A parent report for merge testing.', 'Other', 'Merge location', 'Other Reporter', null, 'Oct 05, 2026', '[]'::jsonb, null, 'for-verification', 'completed'),
  ('phase5-rls-duplicate-child', 'Duplicate child fixture', 'A child report for merge testing.', 'Other', 'Merge location', 'Other Reporter', null, 'Oct 05, 2026', '[]'::jsonb, null, 'pending', 'unassigned');

insert into public.requests (id, title, category, department, details, requester, requester_email, request_date, assigned_personnel, assigned_to, technician_state)
values
  ('phase4-rls-other-request', 'RLS other request fixture', 'Other', 'Other Department', 'A sample request for isolation testing.', 'Other Employee', 'other-employee@nvsu.edu.ph', 'Oct 05, 2026', '[]'::jsonb, null, 'unassigned'),
  ('phase4-rls-assigned-request', 'RLS assigned request fixture', 'Other', 'Testing', 'A sample assigned request for personnel workflow testing.', 'Other Employee', 'other-employee@nvsu.edu.ph', 'Oct 05, 2026', '["Juan dela Cruz"]'::jsonb, 'Juan dela Cruz', 'assigned');

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  'a6050000-0000-4000-8000-000000000001',
  'authenticated',
  'authenticated',
  'new-personnel@nvsu.edu.ph',
  '',
  now(),
  '{}'::jsonb,
  '{"name":"New Personnel User","requested_role":"Personnel"}'::jsonb,
  now(),
  now()
);

update public.user_profiles
set role = 'Personnel', requested_role = 'Personnel',
    is_active = true, registration_status = 'approved'
where auth_user_id = 'a6050000-0000-4000-8000-000000000001';

insert into public.reports (
  id, title, description, category, location, reporter, report_date,
  assigned_personnel, assigned_to, status, technician_state
) values (
  'phase4-rls-new-personnel-report', 'New personnel report fixture',
  'A report assigned to a newly registered Personnel account.', 'Other',
  'Test location', 'Other Reporter', 'Oct 05, 2026',
  '[" New Personnel User "]'::jsonb, 'New Personnel User', 'in-progress', 'assigned'
);

insert into public.requests (
  id, title, category, department, details, requester, request_date,
  assigned_personnel, assigned_to, status, technician_state
) values (
  'phase4-rls-new-personnel-request', 'New personnel request fixture',
  'Other', 'Testing', 'A request assigned to a newly registered Personnel account.',
  'Other Employee', 'Oct 05, 2026',
  '[" New Personnel User "]'::jsonb, 'New Personnel User', 'in-progress', 'assigned'
);

set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select is((select count(*) from public.reports), 0::bigint, 'Public callers cannot read reports directly');
reset role;

set local role authenticated;
select set_config('request.jwt.claims', '{"role":"authenticated","sub":"a6050000-0000-4000-8000-000000000010","email":"prof.reyes@nvsu.edu.ph"}', true);
select is((select count(*) from public.reports where id = 'phase4-rls-own-report'), 1::bigint, 'Employees can read their own report');
select is((select count(*) from public.reports where id = 'phase4-rls-assigned-report'), 0::bigint, 'Employees cannot read another reporter''s report');
select is((select count(*) from public.requests where id = 'phase4-rls-other-request'), 0::bigint, 'Employees cannot read another requester''s request');
insert into public.requests (
  id, title, category, department, details, requester, request_date, assigned_personnel
) values (
  'phase4-rls-own-new-request', 'Own request submission fixture', 'Other', 'Testing',
  'A request submitted with a stale display name.', 'Old Display Name', 'Oct 05, 2026', '[]'::jsonb
);
select is(
  (select requester from public.requests where id = 'phase4-rls-own-new-request'),
  'Prof. Reyes',
  'Request submissions use the authenticated Employee profile name'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claims', '{"role":"authenticated","email":"phase5-same-name@nvsu.edu.ph"}', true);
select is((select count(*) from public.requests where id = 'phase4-rls-other-request'), 0::bigint, 'Same-name employees cannot read requests owned by another email');
reset role;

set local role authenticated;
select set_config('request.jwt.claims', '{"role":"authenticated","email":"prof.reyes@nvsu.edu.ph"}', true);
select throws_ok(
  $$update public.user_profiles set role = 'Admin' where lower(email) = 'prof.reyes@nvsu.edu.ph'$$,
  'P0001',
  'Employee cannot promote their own role'
);
select throws_ok(
  $$update public.user_profiles set registration_status = 'approved' where lower(email) = 'prof.reyes@nvsu.edu.ph'$$,
  'P0001',
  'Employee cannot approve their own registration'
);
select throws_ok(
  $$insert into public.requests (id, title, category, department, details, requester, request_date, assigned_personnel)
    values ('phase4-rls-forged-assignment', 'Forged assignment', 'Other', 'Test', 'A valid description.', 'Prof. Reyes', 'Oct 05, 2026', '["Juan dela Cruz"]'::jsonb)$$,
  '42501',
  'Employee cannot assign a request during submission'
);
select throws_ok(
  $$insert into public.reports (id, title, category, location, reporter, report_date)
    values ('phase4-rls-oversized-report', repeat('x', 161), 'Other', 'Test', 'Prof. Reyes', 'Oct 05, 2026')$$,
  'P0001',
  'Database rejects an oversized report title'
);
select throws_ok(
  $$select public.get_evaluation_summary()$$,
  'P0001',
  'Evaluation summary is restricted to administrators'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claims', '{"role":"authenticated","email":"admin.user@nvsu.edu.ph"}', true);
update public.user_profiles set role = 'Assistant' where email = 'phase4-target@nvsu.edu.ph';
select is((select role from public.user_profiles where email = 'phase4-target@nvsu.edu.ph'), 'Assistant', 'Admin can change user roles');
select throws_ok(
  $$update public.reports set assigned_personnel = '["Juan dela Cruz"]'::jsonb, assigned_to = 'Juan dela Cruz', technician_state = 'assigned' where id = 'phase5-rls-closed-assignment'$$,
  'P0001',
  'Admin cannot assign a closed report'
);
update public.reports set duplicate_of = 'phase5-rls-duplicate-parent', status = 'resolved'
where id = 'phase5-rls-duplicate-child';
select is(
  (select status from public.reports where id = 'phase5-rls-duplicate-child'),
  'resolved',
  'Admin can merge an open duplicate without marking its work completed'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claims', '{"role":"authenticated","email":"assistant.user@nvsu.edu.ph"}', true);
update public.reports set status = 'closed'
where id = 'phase5-rls-duplicate-parent';
select is(
  (select status from public.reports where id = 'phase5-rls-duplicate-child'),
  'closed',
  'Merged child inherits the parent status without bypassing verification'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claims', '{"role":"authenticated","email":"juan.delacruz@nvsu.edu.ph"}', true);
select is((select count(*) from public.reports where id = 'phase4-rls-assigned-report'), 1::bigint, 'Personnel can read assigned reports');
select is((select count(*) from public.reports where id = 'phase4-rls-unassigned-report'), 0::bigint, 'Personnel cannot read unassigned reports');
update public.reports set status = 'in-progress', technician_state = 'accepted'
where id = 'phase4-rls-assigned-report';
select is(
  (select technician_state from public.reports where id = 'phase4-rls-assigned-report'),
  'accepted',
  'Personnel can accept an assigned report without accessing request-only email fields'
);
update public.requests set status = 'in-progress', technician_state = 'accepted'
where id = 'phase4-rls-assigned-request';
select is(
  (select technician_state from public.requests where id = 'phase4-rls-assigned-request'),
  'accepted',
  'Personnel can accept an assigned request without accessing report-only email fields'
);
select is(
  (select status from public.requests where id = 'phase4-rls-assigned-request'),
  'in-progress',
  'Accepting an assigned request also updates its status to in-progress'
);
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"role":"authenticated","sub":"a6050000-0000-4000-8000-000000000001","email":"new-personnel@nvsu.edu.ph"}',
  true
);
select is(public.current_user_role(), 'Personnel', 'A newly approved Auth-linked account resolves to Personnel');
select is((select count(*) from public.reports where id = 'phase4-rls-new-personnel-report'), 1::bigint,
  'New Personnel can read work assigned with whitespace around their profile name');
select is((select count(*) from public.requests where id = 'phase4-rls-new-personnel-request'), 1::bigint,
  'New Personnel can read an assigned request');
update public.reports set status = 'in-progress', technician_state = 'accepted'
where id = 'phase4-rls-new-personnel-report';
select is((select technician_state from public.reports where id = 'phase4-rls-new-personnel-report'), 'accepted',
  'New Personnel can accept an assigned report');
update public.requests set status = 'in-progress', technician_state = 'accepted'
where id = 'phase4-rls-new-personnel-request';
select is((select technician_state from public.requests where id = 'phase4-rls-new-personnel-request'), 'accepted',
  'New Personnel can accept an assigned request');
select throws_ok(
  $$update public.reports set status = 'for-verification', technician_state = 'completed' where id = 'phase4-rls-assigned-report'$$,
  'P0001',
  'Personnel cannot skip acceptance and work start'
);
reset role;

select * from finish();
rollback;
