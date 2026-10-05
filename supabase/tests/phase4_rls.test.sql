begin;
select plan(13);

insert into public.user_profiles (id, name, email, role, department)
values
  ('phase4-rls-admin', 'Phase 4 Admin', 'admin.user@nvsu.edu.ph', 'Admin', 'Testing'),
  ('phase4-rls-employee', 'Prof. Reyes', 'prof.reyes@nvsu.edu.ph', 'Employee', 'Testing'),
  ('phase4-rls-personnel', 'Juan dela Cruz', 'juan.delacruz@nvsu.edu.ph', 'Personnel', 'Testing'),
  ('phase4-rls-target', 'Test Role Target', 'phase4-target@nvsu.edu.ph', 'Employee', 'Testing')
on conflict (email) do update set
  name = excluded.name,
  role = excluded.role,
  department = excluded.department,
  is_active = true;

insert into public.reports (id, title, description, category, location, reporter, report_date, assigned_personnel)
values
  ('phase4-rls-own-report', 'RLS own report fixture', 'A sample report for isolation testing.', 'Other', 'Test location', 'Prof. Reyes', 'Oct 05, 2026', '[]'::jsonb),
  ('phase4-rls-assigned-report', 'RLS assigned report fixture', 'A sample assigned report for isolation testing.', 'Other', 'Test location', 'Other Reporter', 'Oct 05, 2026', '["Juan dela Cruz"]'::jsonb),
  ('phase4-rls-unassigned-report', 'RLS unassigned report fixture', 'A sample unassigned report for isolation testing.', 'Other', 'Test location', 'Other Reporter', 'Oct 05, 2026', '[]'::jsonb);

insert into public.requests (id, title, category, department, details, requester, request_date)
values ('phase4-rls-other-request', 'RLS other request fixture', 'Other', 'Other Department', 'A sample request for isolation testing.', 'Other Employee', 'Oct 05, 2026');

set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select is((select count(*) from public.reports), 0::bigint, 'Public callers cannot read reports directly');
reset role;

set local role authenticated;
select set_config('request.jwt.claims', '{"role":"authenticated","email":"prof.reyes@nvsu.edu.ph"}', true);
select is((select count(*) from public.reports where id = 'phase4-rls-own-report'), 1::bigint, 'Employees can read their own report');
select is((select count(*) from public.reports where id = 'phase4-rls-assigned-report'), 0::bigint, 'Employees cannot read another reporter''s report');
select is((select count(*) from public.requests where id = 'phase4-rls-other-request'), 0::bigint, 'Employees cannot read another requester''s request');
update public.sla_settings set target_hours = target_hours + 1 where priority = 'urgent';
select is((select target_hours from public.sla_settings where priority = 'urgent'), 4, 'Employee cannot change the SLA target');
select throws_ok(
  $$update public.user_profiles set role = 'Admin' where lower(email) = 'prof.reyes@nvsu.edu.ph'$$,
  'P0001',
  'Employee cannot promote their own role'
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
update public.sla_settings set target_hours = 5 where priority = 'urgent';
select is((select target_hours from public.sla_settings where priority = 'urgent'), 5, 'Admin can change SLA targets');
update public.user_profiles set role = 'Assistant' where email = 'phase4-target@nvsu.edu.ph';
select is((select role from public.user_profiles where email = 'phase4-target@nvsu.edu.ph'), 'Assistant', 'Admin can change user roles');
reset role;

set local role authenticated;
select set_config('request.jwt.claims', '{"role":"authenticated","email":"juan.delacruz@nvsu.edu.ph"}', true);
select is((select count(*) from public.reports where id = 'phase4-rls-assigned-report'), 1::bigint, 'Personnel can read assigned reports');
select is((select count(*) from public.reports where id = 'phase4-rls-unassigned-report'), 0::bigint, 'Personnel cannot read unassigned reports');
reset role;

select * from finish();
rollback;
