-- Remove SLA/deadline and audit-history features while preserving workflow metadata.
begin;

drop trigger if exists audit_reports_changes on public.reports;
drop trigger if exists audit_requests_changes on public.requests;

drop policy if exists "Users can create own reports" on public.reports;
create policy "Users can create own reports" on public.reports
  for insert to authenticated
  with check (
    public.current_user_role() in ('Admin', 'Assistant', 'Employee', 'Student', 'Personnel')
    and lower(reporter) = lower((
      select name from public.user_profiles
      where lower(email) = lower(auth.jwt() ->> 'email')
      limit 1
    ))
    and status = 'pending'
    and risk = 'low'
    and technician_state = 'unassigned'
    and coalesce(assigned_to, '') = ''
    and assigned_personnel = '[]'::jsonb
    and admin_remark is null
    and assignment_note is null
    and lower(coalesce(reporter_email, '')) in ('', lower(auth.jwt() ->> 'email'))
  );

drop policy if exists "Users can create own requests" on public.requests;
create policy "Users can create own requests" on public.requests
  for insert to authenticated
  with check (
    public.current_user_role() in ('Admin', 'Employee')
    and lower(requester) = lower((
      select name from public.user_profiles
      where lower(email) = lower(auth.jwt() ->> 'email')
      limit 1
    ))
    and status = 'submitted'
    and risk = 'low'
    and technician_state = 'unassigned'
    and coalesce(assigned_to, '') = ''
    and assigned_personnel = '[]'::jsonb
    and admin_response is null
    and admin_remark is null
    and lower(coalesce(requester_email, '')) in ('', lower(auth.jwt() ->> 'email'))
  );

create or replace function public.set_phase1_work_item_metadata()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tracking_year integer;
  tracking_number bigint;
  work_status text;
  technician_status text;
  assignees jsonb;
begin
  work_status := coalesce(new.status, '');
  technician_status := coalesce(new.technician_state, '');
  assignees := coalesce(new.assigned_personnel, '[]'::jsonb);

  if tg_op = 'INSERT' or new.tracking_code is null or btrim(new.tracking_code) = '' then
    v_tracking_year := extract(year from coalesce(new.created_at, now()))::integer;
    insert into public.tracking_code_counters (tracking_year, last_number)
    values (v_tracking_year, 1)
    on conflict (tracking_year) do update
      set last_number = public.tracking_code_counters.last_number + 1
    returning last_number into tracking_number;
    new.tracking_code := 'UNI-' || v_tracking_year::text || '-' || lpad(tracking_number::text, 4, '0');
  elsif new.tracking_code is distinct from old.tracking_code then
    new.tracking_code := old.tracking_code;
  end if;

  new.updated_at := now();
  if tg_op = 'INSERT' then
    if work_status not in ('pending', 'urgent', 'submitted', '') then new.reviewed_at := now(); end if;
    if jsonb_array_length(assignees) > 0 then new.assigned_at := now(); end if;
    if technician_status in ('accepted', 'started') or work_status = 'in-progress' then new.in_progress_at := now(); end if;
    if technician_status = 'completed' or work_status in ('resolved', 'action-taken') then new.completed_at := now(); end if;
  else
    if new.status is distinct from old.status and work_status not in ('pending', 'urgent', 'submitted', '') then
      new.reviewed_at := coalesce(old.reviewed_at, now());
    end if;
    if new.assigned_personnel is distinct from old.assigned_personnel
      and jsonb_array_length(assignees) > 0 then
      new.assigned_at := coalesce(old.assigned_at, now());
    end if;
    if (new.technician_state is distinct from old.technician_state and technician_status in ('accepted', 'started'))
      or (new.status is distinct from old.status and work_status = 'in-progress') then
      new.in_progress_at := coalesce(old.in_progress_at, now());
    end if;
    if (new.technician_state is distinct from old.technician_state and technician_status = 'completed')
      or (new.status is distinct from old.status and work_status in ('resolved', 'action-taken')) then
      new.completed_at := coalesce(old.completed_at, now());
    end if;
  end if;
  return new;
end;
$$;

do $$
declare
  definition text;
begin
  definition := pg_get_functiondef('public.enforce_role_update_scope()'::regprocedure);
  definition := replace(definition, E'\n      or new.priority is distinct from old.priority', '');
  if position('new.priority' in definition) > 0 then
    raise exception 'Unexpected priority dependency in enforce_role_update_scope()';
  end if;
  execute definition;

  definition := pg_get_functiondef('public.generate_due_maintenance_work_orders()'::regprocedure);
  definition := replace(definition, 'risk, priority, status,', 'risk, status,');
  definition := replace(definition, '''low'', ''medium'', ''pending'',', '''low'', ''pending'',');
  if position('priority' in definition) > 0 then
    raise exception 'Unexpected priority dependency in generate_due_maintenance_work_orders()';
  end if;
  execute definition;
end;
$$;

create or replace function public.get_unifix_analytics(
  p_from_date date,
  p_to_date date,
  p_category text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  result jsonb;
begin
  if coalesce(public.current_user_role(), '') not in ('Admin', 'Assistant') then
    raise exception 'Analytics are available to administrators and assistants only';
  end if;
  if p_from_date is null or p_to_date is null or p_from_date > p_to_date
     or p_to_date > current_date + 1 then
    raise exception 'Choose a valid analytics date range';
  end if;

  with work as (
    select r.id, r.category, r.location, r.status, r.created_at, r.completed_at, r.rework_count,
           case when jsonb_typeof(r.assigned_personnel) = 'array' then r.assigned_personnel else '[]'::jsonb end as assigned_personnel
      from public.reports r
    union all
    select q.id, q.category, q.department, q.status, q.created_at, q.completed_at, q.rework_count,
           case when jsonb_typeof(q.assigned_personnel) = 'array' then q.assigned_personnel else '[]'::jsonb end
      from public.requests q
  ), filtered as (
    select * from work
     where created_at::date between p_from_date and p_to_date
       and (p_category is null or p_category = '' or category = p_category)
  ), personnel as (
    select person.name,
           count(*) filter (where f.status not in ('closed', 'resolved', 'action-taken')) as open_count,
           count(*) filter (where f.status in ('closed', 'resolved', 'action-taken')) as completed_count
      from filtered f
      cross join lateral jsonb_array_elements_text(f.assigned_personnel) person(name)
     group by person.name
  )
  select jsonb_build_object(
    'stats', jsonb_build_object(
      'total', (select count(*) from filtered),
      'open', (select count(*) from filtered where status not in ('closed', 'resolved', 'action-taken')),
      'completed', (select count(*) from work where completed_at::date between p_from_date and p_to_date
                    and (p_category is null or p_category = '' or category = p_category)),
      'avgResolutionDays', (select round(avg(extract(epoch from (completed_at - created_at)) / 86400)::numeric, 2)
                            from filtered where completed_at is not null and completed_at >= created_at),
      'averageRating', (select round(avg(fb.rating)::numeric, 2)
                        from public.report_feedback fb join public.reports r on r.id = fb.report_id
                        where r.created_at::date between p_from_date and p_to_date
                          and (p_category is null or p_category = '' or r.category = p_category)),
      'reworkRate', coalesce((select round(100.0 * count(*) filter (where rework_count > 0) / nullif(count(*), 0), 1)
                              from filtered), 0)
    ),
    'categories', coalesce((select jsonb_agg(jsonb_build_object('name', category, 'count', amount) order by amount desc)
                            from (select category, count(*) amount from filtered group by category) c), '[]'::jsonb),
    'locations', coalesce((select jsonb_agg(jsonb_build_object('name', location, 'count', amount) order by amount desc)
                           from (select location, count(*) amount from filtered group by location order by amount desc limit 10) l), '[]'::jsonb),
    'trend', coalesce((select jsonb_agg(jsonb_build_object('date', trend_date, 'count', amount) order by trend_date)
                       from (select created_at::date as trend_date, count(*) amount from filtered group by created_at::date) t), '[]'::jsonb),
    'personnel', coalesce((select jsonb_agg(jsonb_build_object('name', name, 'open', open_count, 'completed', completed_count) order by open_count desc)
                           from personnel), '[]'::jsonb)
  ) into result;
  return result;
end;
$$;
revoke all on function public.get_unifix_analytics(date, date, text) from public, anon;
grant execute on function public.get_unifix_analytics(date, date, text) to authenticated;

drop index if exists public.reports_due_at_open_idx;
drop index if exists public.requests_due_at_open_idx;
alter table public.reports drop constraint if exists reports_priority_check;
alter table public.requests drop constraint if exists requests_priority_check;
alter table public.reports drop column if exists priority, drop column if exists due_at;
alter table public.requests drop column if exists priority, drop column if exists due_at;
drop table if exists public.sla_settings;

drop table if exists public.audit_log;
drop function if exists public.audit_work_item_changes();

notify pgrst, 'reload schema';
commit;
