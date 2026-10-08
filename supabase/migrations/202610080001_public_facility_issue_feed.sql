create or replace function public.get_public_facility_issues(
  p_location_id uuid,
  p_report_offset integer default 0,
  p_request_offset integer default 0,
  p_limit integer default 50
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  facility public.locations%rowtype;
  building_prefix text;
  safe_report_offset integer := greatest(coalesce(p_report_offset, 0), 0);
  safe_request_offset integer := greatest(coalesce(p_request_offset, 0), 0);
  safe_limit integer := greatest(1, least(coalesce(p_limit, 50), 50));
  report_count bigint;
  request_count bigint;
  public_reports jsonb;
  public_requests jsonb;
begin
  if p_location_id is null then
    return null;
  end if;

  select * into facility
  from public.locations
  where id = p_location_id
    and is_active;

  if not found then
    return null;
  end if;

  building_prefix := lower(btrim(facility.building));

  select count(*) into report_count
  from public.reports report
  where (lower(btrim(report.location)) = building_prefix
    or left(lower(btrim(report.location)), length(building_prefix || ' · ')) = building_prefix || ' · ')
    and lower(coalesce(report.status, '')) not in ('closed', 'resolved', 'action-taken');

  select count(*) into request_count
  from public.requests request
  where (lower(btrim(request.department)) = building_prefix
    or left(lower(btrim(request.department)), length(building_prefix || ' · ')) = building_prefix || ' · ')
    and lower(coalesce(request.status, '')) not in ('closed', 'resolved', 'action-taken');

  select coalesce(jsonb_agg(page.issue order by page.created_at desc), '[]'::jsonb)
  into public_reports
  from (
    select jsonb_build_object(
      'title', report.title,
      'category', report.category,
      'status', report.status,
      'risk', report.risk,
      'date', report.report_date
    ) as issue, report.created_at
    from public.reports report
    where (lower(btrim(report.location)) = building_prefix
      or left(lower(btrim(report.location)), length(building_prefix || ' · ')) = building_prefix || ' · ')
      and lower(coalesce(report.status, '')) not in ('closed', 'resolved', 'action-taken')
    order by report.created_at desc
    limit safe_limit offset safe_report_offset
  ) page;

  select coalesce(jsonb_agg(page.issue order by page.created_at desc), '[]'::jsonb)
  into public_requests
  from (
    select jsonb_build_object(
      'title', request.title,
      'category', request.category,
      'status', request.status,
      'risk', request.risk,
      'date', request.request_date,
      'area', request.department
    ) as issue, request.created_at
    from public.requests request
    where (lower(btrim(request.department)) = building_prefix
      or left(lower(btrim(request.department)), length(building_prefix || ' · ')) = building_prefix || ' · ')
      and lower(coalesce(request.status, '')) not in ('closed', 'resolved', 'action-taken')
    order by request.created_at desc
    limit safe_limit offset safe_request_offset
  ) page;

  return jsonb_build_object(
    'facility', jsonb_build_object(
      'id', facility.id,
      'building', facility.building,
      'floor', facility.floor,
      'room', facility.room
    ),
    'reports', public_reports,
    'requests', public_requests,
    'reportCount', report_count,
    'requestCount', request_count
  );
end;
$$;

revoke all on function public.get_public_facility_issues(uuid, integer, integer, integer) from public;
grant execute on function public.get_public_facility_issues(uuid, integer, integer, integer) to anon, authenticated;
