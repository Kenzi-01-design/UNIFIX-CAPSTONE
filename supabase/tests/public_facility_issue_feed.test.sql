begin;
select plan(4);

insert into public.locations (id, building, floor, room, is_active)
values
  ('a6100000-0000-4000-8000-000000000001', 'QR Feed Oval', '', '', true),
  ('a6100000-0000-4000-8000-000000000002', 'QR Feed Inactive', '', '', false);

insert into public.reports (
  id, title, description, category, location, reporter, reporter_email, report_date, status
) values
  ('QR-FEED-OPEN-REPORT', 'Open light fixture issue', 'Private report details', 'Electrical',
   'QR Feed Oval · Floor 1 · Room 10', 'Private Reporter', 'private@example.edu', 'Oct 08, 2026', 'in-progress'),
  ('QR-FEED-CLOSED-REPORT', 'Closed light fixture issue', 'Private report details', 'Electrical',
   'QR Feed Oval', 'Private Reporter', 'private@example.edu', 'Oct 07, 2026', 'resolved');

insert into public.requests (
  id, title, category, department, details, requester, request_date, status
) values
  ('QR-FEED-OPEN-REQUEST', 'Classroom chair repair', 'Furniture', 'QR Feed Oval · Room 10',
   'Private request details', 'Private Requester', 'Oct 08, 2026', 'submitted'),
  ('QR-FEED-CLOSED-REQUEST', 'Completed chair repair', 'Furniture', 'QR Feed Oval',
   'Private request details', 'Private Requester', 'Oct 07, 2026', 'action-taken');

set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);

select is(
  jsonb_array_length((public.get_public_facility_issues('a6100000-0000-4000-8000-000000000001', 0, 0, 50))->'reports'),
  1,
  'Public facility feed includes current reports and excludes completed reports'
);
select is(
  jsonb_array_length((public.get_public_facility_issues('a6100000-0000-4000-8000-000000000001', 0, 0, 50))->'requests'),
  1,
  'Public facility feed includes current requests and excludes completed requests'
);
select ok(
  not (
    (public.get_public_facility_issues('a6100000-0000-4000-8000-000000000001', 0, 0, 50)->'reports'->0)
    ?| array['id', 'description', 'reporter', 'reporterEmail']
  )
  and not (
    (public.get_public_facility_issues('a6100000-0000-4000-8000-000000000001', 0, 0, 50)->'requests'->0)
    ?| array['id', 'details', 'requester', 'requesterEmail']
  ),
  'Public facility feed does not expose identifiers, descriptions, or reporter identities'
);
select is(
  public.get_public_facility_issues('a6100000-0000-4000-8000-000000000002', 0, 0, 50),
  null::jsonb,
  'Public facility feed is unavailable for inactive locations'
);

select * from finish();
rollback;
