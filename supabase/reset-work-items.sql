-- DESTRUCTIVE: permanently removes all reports, requests, anonymous
-- evaluation responses, and the work-item history/notifications associated
-- with reports and requests.
--
-- Preserves all Auth accounts, profiles, account notifications, login
-- history, preferences, locations, maintenance schedules, and settings.
-- Report feedback and duplicate votes are removed by their ON DELETE CASCADE
-- foreign keys. Report photo files in the report-photos Storage bucket are
-- not removed by SQL; delete those through Supabase Storage after reviewing
-- that the bucket contains only files intended to be cleared.

begin;

delete from public.evaluation_responses;

delete from public.work_item_activity
where entity_type in ('report', 'request');

do $$
begin
  if to_regclass('public.audit_log') is not null then
    execute $delete$
      delete from public.audit_log
      where entity_type in ('report', 'request')
    $delete$;
  end if;
end;
$$;

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

commit;
