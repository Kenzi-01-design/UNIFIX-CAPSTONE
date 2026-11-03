begin;
select plan(7);

insert into public.locations (id, building, floor, room, is_active)
values
  ('a6100000-0000-4000-8000-000000000001', 'QR Feed Oval', '', '', true),
  ('a6100000-0000-4000-8000-000000000002', 'QR Feed Inactive', '', '', false),
  ('a6100000-0000-4000-8000-000000000003', 'QR Feed Room', 'Floor 1', 'Room 10', true);

insert into public.reports (
  id, title, description, category, location, reporter, reporter_email, report_date, status
) values
  ('QR-FEED-OPEN-REPORT', 'Open light fixture issue', 'Private report details', 'Electrical',
   'QR Feed Oval · Floor 1 · Room 10', 'Private Reporter', 'private@example.edu', 'Oct 08, 2026', 'in-progress'),
  ('QR-FEED-CLOSED-REPORT', 'Closed light fixture issue', 'Private report details', 'Electrical',
   'QR Feed Oval', 'Private Reporter', 'private@example.edu', 'Oct 07, 2026', 'resolved'),
  ('QR-FEED-ROOM-MATCH', 'Room 10 report', 'Private report details', 'Electrical',
   'QR Feed Room · Floor 1 · Room 10', 'Private Reporter', 'private@example.edu', 'Oct 08, 2026', 'pending'),
  ('QR-FEED-ROOM-SIBLING', 'Room 11 report', 'Private report details', 'Electrical',
   'QR Feed Room · Floor 1 · Room 11', 'Private Reporter', 'private@example.edu', 'Oct 08, 2026', 'pending');

insert into public.requests (
  id, title, category, department, details, requester, request_date, status
) values
  ('QR-FEED-OPEN-REQUEST', 'Classroom chair repair', 'Furniture', 'QR Feed Oval · Room 10',
   'Private request details', 'Private Requester', 'Oct 08, 2026', 'submitted'),
  ('QR-FEED-CLOSED-REQUEST', 'Completed chair repair', 'Furniture', 'QR Feed Oval',
   'Private request details', 'Private Requester', 'Oct 07, 2026', 'action-taken'),
  ('QR-FEED-ROOM-MATCH-REQUEST', 'Room 10 request', 'Furniture', 'QR Feed Room · Room 10',
   'Private request details', 'Private Requester', 'Oct 08, 2026', 'submitted'),
  ('QR-FEED-ROOM-SIBLING-REQUEST', 'Room 11 request', 'Furniture', 'QR Feed Room · Room 11',
   'Private request details', 'Private Requester', 'Oct 08, 2026', 'submitted');

set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);

select is(
  jsonb_array_length((public.get_public_facility_issues('a6100000-0000-4000-8000-000000000001', 0, 0, 50))->'reports'),
  2,
  'Public facility feed includes current and completed reports'
);
select is(
  jsonb_array_length((public.get_public_facility_issues('a6100000-0000-4000-8000-000000000001', 0, 0, 50))->'requests'),
  2,
  'Public facility feed includes current and completed requests'
);
select ok(
  exists (
    select 1
    from jsonb_array_elements(public.get_public_facility_issues('a6100000-0000-4000-8000-000000000001', 0, 0, 50)->'reports') as issues(issue)
    where issue ->> 'status' = 'resolved'
  )
  and exists (
    select 1
    from jsonb_array_elements(public.get_public_facility_issues('a6100000-0000-4000-8000-000000000001', 0, 0, 50)->'requests') as requests(request)
    where request ->> 'status' = 'action-taken'
  ),
  'Public facility feed preserves completed work statuses'
);
select is(
  jsonb_array_length((public.get_public_facility_issues('a6100000-0000-4000-8000-000000000003', 0, 0, 50))->'reports'),
  1,
  'Room facility feed excludes reports from sibling rooms'
);
select is(
  jsonb_array_length((public.get_public_facility_issues('a6100000-0000-4000-8000-000000000003', 0, 0, 50))->'requests'),
  1,
  'Room facility feed matches requests by their room location'
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
