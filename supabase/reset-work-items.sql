-- DESTRUCTIVE: permanently removes all reports and requests, along with
-- notifications and notification deliveries linked to those work items.
-- Report feedback is removed by its ON DELETE CASCADE foreign key.
-- Also removes all anonymous evaluation responses.
-- This does not remove Storage objects; clear the report-photos bucket
-- separately in Supabase Storage after reviewing the scope.
-- All Auth accounts, profiles, preferences, login history, locations,
-- maintenance schedules, and their settings are preserved. Auth accounts
-- that lack a profile are restored as pending/inactive Employees for Admin review.

begin;

delete from public.evaluation_responses;

delete from public.notification_deliveries delivery
where exists (
  select 1
  from public.reports report
  where delivery.entity_type = 'report'
    and (
      delivery.entity_id = report.id
      or (report.tracking_code is not null and delivery.tracking_code = report.tracking_code)
    )
)
or exists (
  select 1
  from public.requests request
  where delivery.entity_type = 'request'
    and (
      delivery.entity_id = request.id
      or (request.tracking_code is not null and delivery.tracking_code = request.tracking_code)
    )
);

delete from public.notifications notification
where exists (
  select 1
  from public.reports report
  where notification.entity_type = 'report'
    and (
      notification.entity_id = report.id
      or (report.tracking_code is not null and notification.tracking_code = report.tracking_code)
    )
)
or exists (
  select 1
  from public.requests request
  where notification.entity_type = 'request'
    and (
      notification.entity_id = request.id
      or (request.tracking_code is not null and notification.tracking_code = request.tracking_code)
    )
);

delete from public.reports;
delete from public.requests;

insert into public.user_profiles (
  id, name, email, role, department, phone, location, is_active, registration_status
)
select
  auth_user.id::text,
  left(coalesce(nullif(btrim(auth_user.raw_user_meta_data ->> 'name'), ''), 'New User'), 120),
  lower(auth_user.email),
  'Employee',
  left(coalesce(nullif(btrim(auth_user.raw_user_meta_data ->> 'department'), ''), ''), 160),
  left(coalesce(nullif(btrim(auth_user.raw_user_meta_data ->> 'phone'), ''), ''), 40),
  left(coalesce(nullif(btrim(auth_user.raw_user_meta_data ->> 'location'), ''), 'Main Campus'), 160),
  false,
  'pending'
from auth.users auth_user
where auth_user.email is not null
  and not exists (
    select 1
    from public.user_profiles profile
    where lower(profile.email) = lower(auth_user.email)
  )
on conflict (email) do nothing;

commit;
