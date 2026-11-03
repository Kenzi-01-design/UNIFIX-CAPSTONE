create or replace function public.work_item_location_matches_facility(
  p_work_location text,
  p_building text,
  p_floor text default null,
  p_room text default null
)
returns boolean
language sql
immutable
set search_path = pg_catalog
as $$
  with facility_path as (
    select
      lower(btrim(coalesce(p_work_location, ''))) as work_location,
      lower(btrim(coalesce(p_building, ''))) as building,
      nullif(lower(btrim(coalesce(p_floor, ''))), '') as floor,
      nullif(lower(btrim(coalesce(p_room, ''))), '') as room
  ),
  prefixes as (
    select
      work_location,
      building,
      concat_ws(' · ', building, floor, room) as full_prefix,
      array_remove(array[
        building,
        case when floor is not null then concat_ws(' · ', building, floor) end,
        case when room is not null then concat_ws(' · ', building, floor, room) end
      ], null) as exact_prefixes,
      case
        when floor is not null and room is not null then concat_ws(' · ', building, room)
      end as room_only_prefix
    from facility_path
  )
  select work_location <> ''
    and building <> ''
    and (
      work_location = any(exact_prefixes)
      or left(work_location, length(full_prefix || ' · ')) = full_prefix || ' · '
      or (
        room_only_prefix is not null
        and left(work_location, length(room_only_prefix || ' · ')) = room_only_prefix || ' · '
      )
    )
  from prefixes;
$$;
revoke all on function public.work_item_location_matches_facility(text, text, text, text) from public, anon, authenticated;

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

  select count(*) into report_count
  from public.reports report
  where public.work_item_location_matches_facility(
      report.location, facility.building, facility.floor, facility.room
    )
    and lower(btrim(coalesce(report.status, ''))) not in ('closed', 'resolved', 'action-taken');

  select count(*) into request_count
  from public.requests request
  where public.work_item_location_matches_facility(
      request.department, facility.building, facility.floor, facility.room
    )
    and lower(btrim(coalesce(request.status, ''))) not in ('closed', 'resolved', 'action-taken');

  select coalesce(jsonb_agg(page.issue order by page.created_at desc, page.id desc), '[]'::jsonb)
  into public_reports
  from (
    select jsonb_build_object(
      'title', report.title,
      'category', report.category,
      'status', report.status,
      'risk', report.risk,
      'date', report.report_date,
      'area', report.location
    ) as issue, report.created_at, report.id
    from public.reports report
    where public.work_item_location_matches_facility(
        report.location, facility.building, facility.floor, facility.room
      )
      and lower(btrim(coalesce(report.status, ''))) not in ('closed', 'resolved', 'action-taken')
    order by report.created_at desc, report.id desc
    limit safe_limit offset safe_report_offset
  ) page;

  select coalesce(jsonb_agg(page.issue order by page.created_at desc, page.id desc), '[]'::jsonb)
  into public_requests
  from (
    select jsonb_build_object(
      'title', request.title,
      'category', request.category,
      'status', request.status,
      'risk', request.risk,
      'date', request.request_date,
      'area', request.department
    ) as issue, request.created_at, request.id
    from public.requests request
    where public.work_item_location_matches_facility(
        request.department, facility.building, facility.floor, facility.room
      )
      and lower(btrim(coalesce(request.status, ''))) not in ('closed', 'resolved', 'action-taken')
    order by request.created_at desc, request.id desc
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
