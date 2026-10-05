-- Phase 3: analytics, duplicate management, locations, and preventive maintenance.
create extension if not exists pg_trgm;

do $$
declare
  trigram_schema text;
begin
  select n.nspname into trigram_schema
    from pg_extension e
    join pg_namespace n on n.oid = e.extnamespace
   where e.extname = 'pg_trgm';
  execute format(
    'create index if not exists reports_title_trgm_idx on public.reports using gin (lower(title) %I.gin_trgm_ops)',
    trigram_schema
  );
end;
$$;

alter table public.reports
  add column if not exists duplicate_of text references public.reports(id) on delete set null;

create table if not exists public.locations (
  id uuid primary key default gen_random_uuid(),
  building text not null check (char_length(btrim(building)) between 1 and 120),
  floor text not null default '',
  room text not null default '',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists locations_building_floor_room_unique
  on public.locations (lower(building), lower(floor), lower(room));
alter table public.locations enable row level security;
revoke all on public.locations from public, anon, authenticated;
grant select on public.locations to anon, authenticated;
grant insert, update, delete on public.locations to authenticated;
drop policy if exists "Public can read active report locations" on public.locations;
create policy "Public can read active report locations" on public.locations
  for select to anon using (is_active);
drop policy if exists "Authenticated roles can read locations" on public.locations;
drop policy if exists "Admins can read locations" on public.locations;
create policy "Admins can read locations" on public.locations
  for select to authenticated using (public.current_user_role() = 'Admin');
drop policy if exists "Assistants can read locations" on public.locations;
create policy "Assistants can read locations" on public.locations
  for select to authenticated using (public.current_user_role() = 'Assistant');
drop policy if exists "Employees can read locations" on public.locations;
create policy "Employees can read locations" on public.locations
  for select to authenticated using (public.current_user_role() = 'Employee');
drop policy if exists "Students can read locations" on public.locations;
create policy "Students can read locations" on public.locations
  for select to authenticated using (public.current_user_role() = 'Student');
drop policy if exists "Personnel can read locations" on public.locations;
create policy "Personnel can read locations" on public.locations
  for select to authenticated using (public.current_user_role() = 'Personnel');
drop policy if exists "Admins can create locations" on public.locations;
create policy "Admins can create locations" on public.locations
  for insert to authenticated with check (public.current_user_role() = 'Admin');
drop policy if exists "Admins can update locations" on public.locations;
create policy "Admins can update locations" on public.locations
  for update to authenticated using (public.current_user_role() = 'Admin')
  with check (public.current_user_role() = 'Admin');
drop policy if exists "Admins can delete locations" on public.locations;
create policy "Admins can delete locations" on public.locations
  for delete to authenticated using (public.current_user_role() = 'Admin');

insert into public.locations (building)
values
  ('Administration Building'),
  ('Academic Classroom Building'),
  ('Engineering Building'),
  ('Gymnasium'),
  ('Library')
on conflict do nothing;

create table if not exists public.report_duplicate_votes (
  id uuid primary key default gen_random_uuid(),
  report_id text not null references public.reports(id) on delete cascade,
  voter_hash text not null,
  note text not null default '' check (char_length(note) <= 500),
  created_at timestamptz not null default now(),
  unique (report_id, voter_hash)
);
alter table public.report_duplicate_votes enable row level security;
revoke all on public.report_duplicate_votes from public, anon, authenticated;
drop policy if exists "Admins can read duplicate report notes" on public.report_duplicate_votes;
create policy "Admins can read duplicate report notes" on public.report_duplicate_votes
  for select to authenticated using (public.current_user_role() = 'Admin');
drop policy if exists "Assistants can read duplicate report notes" on public.report_duplicate_votes;
create policy "Assistants can read duplicate report notes" on public.report_duplicate_votes
  for select to authenticated using (public.current_user_role() = 'Assistant');

create or replace function public.find_similar_open_reports(
  p_category text,
  p_location text,
  p_title text,
  p_anonymous_id text default null
)
returns table (id text, title text, location text, status text, similarity real)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  request_key text;
begin
  if char_length(btrim(coalesce(p_category, ''))) not between 1 and 80
     or char_length(btrim(coalesce(p_location, ''))) not between 1 and 300
     or char_length(btrim(coalesce(p_title, ''))) not between 3 and 180 then
    raise exception 'A valid category, location, and title are required';
  end if;
  if coalesce(auth.jwt() ->> 'email', '') <> '' then
    request_key := md5('duplicate-search:user:' || lower(auth.jwt() ->> 'email'));
  elsif coalesce(p_anonymous_id, '') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    request_key := md5('duplicate-search:anonymous:' || lower(p_anonymous_id));
  else
    raise exception 'A valid anonymous search identifier is required';
  end if;
  if not public.consume_public_endpoint_rate_limit(request_key, 30) then
    raise exception 'Too many duplicate searches. Wait a minute before trying again.';
  end if;

  return query
  select r.id, r.title, r.location, r.status,
         similarity(lower(r.title), lower(btrim(p_title))) as similarity
  from public.reports r
  where lower(r.category) = lower(btrim(p_category))
    and lower(r.location) = lower(btrim(p_location))
    and r.duplicate_of is null
    and r.status not in ('closed', 'resolved', 'action-taken')
    and similarity(lower(r.title), lower(btrim(p_title))) >= 0.20
  order by 5 desc, r.created_at desc
  limit 5;
end;
$$;
revoke all on function public.find_similar_open_reports(text, text, text, text) from public;
grant execute on function public.find_similar_open_reports(text, text, text, text) to anon, authenticated;

create or replace function public.add_report_duplicate_vote(
  p_report_id text,
  p_note text default '',
  p_anonymous_id text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  voter_hash text;
begin
  if char_length(btrim(coalesce(p_note, ''))) > 500 then
    raise exception 'The note must be 500 characters or fewer';
  end if;
  if not exists (
    select 1 from public.reports
    where id = p_report_id and status not in ('closed', 'resolved', 'action-taken')
      and duplicate_of is null
  ) then
    raise exception 'The selected report is no longer open';
  end if;
  if coalesce(auth.jwt() ->> 'email', '') <> '' then
    voter_hash := md5('user:' || lower(auth.jwt() ->> 'email'));
  elsif coalesce(p_anonymous_id, '') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    voter_hash := md5('anonymous:' || lower(p_anonymous_id));
  else
    raise exception 'A valid anonymous vote identifier is required';
  end if;
  if not public.consume_public_endpoint_rate_limit(md5('duplicate-vote:' || voter_hash), 5) then
    raise exception 'Too many votes. Wait a minute before trying again.';
  end if;

  insert into public.report_duplicate_votes (report_id, voter_hash, note)
  values (p_report_id, voter_hash, btrim(coalesce(p_note, '')))
  on conflict (report_id, voter_hash)
  do update set note = excluded.note, created_at = now();
end;
$$;
revoke all on function public.add_report_duplicate_vote(text, text, text) from public;
grant execute on function public.add_report_duplicate_vote(text, text, text) to anon, authenticated;

create or replace function public.get_report_duplicate_notes(p_report_id text)
returns table (note text, created_at timestamptz)
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(public.current_user_role(), '') not in ('Admin', 'Assistant') then
    raise exception 'Only staff can read duplicate-report notes';
  end if;
  return query
    select vote.note, vote.created_at
      from public.report_duplicate_votes vote
     where vote.report_id = p_report_id
     order by vote.created_at desc;
end;
$$;
revoke all on function public.get_report_duplicate_notes(text) from public, anon;
grant execute on function public.get_report_duplicate_notes(text) to authenticated;

create or replace function public.merge_duplicate_reports(p_parent_id text, p_child_id text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  parent_report public.reports%rowtype;
  child_report public.reports%rowtype;
begin
  if coalesce(public.current_user_role(), '') <> 'Admin' then
    raise exception 'Only administrators can merge reports';
  end if;
  if p_parent_id = p_child_id then
    raise exception 'A report cannot be merged into itself';
  end if;
  select * into parent_report from public.reports where id = p_parent_id for update;
  select * into child_report from public.reports where id = p_child_id for update;
  if parent_report.id is null or child_report.id is null
     or parent_report.duplicate_of is not null or child_report.duplicate_of is not null
     or lower(parent_report.category) <> lower(child_report.category)
     or lower(parent_report.location) <> lower(child_report.location)
     or parent_report.status in ('closed', 'resolved', 'action-taken')
     or child_report.status in ('closed', 'resolved', 'action-taken') then
    raise exception 'Choose two open, unmerged reports with the same category and location';
  end if;
  update public.reports set duplicate_of = p_parent_id, status = 'resolved' where id = p_child_id;
  return true;
end;
$$;
revoke all on function public.merge_duplicate_reports(text, text) from public, anon;
grant execute on function public.merge_duplicate_reports(text, text) to authenticated;

create or replace function public.propagate_duplicate_report_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.duplicate_of is null and new.status is distinct from old.status then
    update public.reports
       set status = new.status
     where duplicate_of = new.id
       and status is distinct from new.status;
  end if;
  return new;
end;
$$;
drop trigger if exists reports_propagate_duplicate_status on public.reports;
create trigger reports_propagate_duplicate_status
  after update of status on public.reports
  for each row execute function public.propagate_duplicate_report_status();

create table if not exists public.maintenance_schedules (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(btrim(title)) between 1 and 180),
  location_id uuid references public.locations(id) on delete set null,
  location_label text not null default '',
  category text not null check (char_length(btrim(category)) between 1 and 80),
  frequency text not null check (frequency in ('weekly', 'monthly', 'quarterly', 'yearly', 'custom')),
  custom_interval_days integer check (custom_interval_days between 1 and 3650),
  next_due date not null,
  default_assignee text not null default '',
  checklist_items jsonb not null default '[]'::jsonb check (jsonb_typeof(checklist_items) = 'array'),
  is_active boolean not null default true,
  created_by text not null default coalesce(auth.jwt() ->> 'email', 'system'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (frequency <> 'custom' or custom_interval_days is not null)
);
alter table public.maintenance_schedules enable row level security;
revoke all on public.maintenance_schedules from public, anon, authenticated;
grant select, insert, update, delete on public.maintenance_schedules to authenticated;
drop policy if exists "Staff can read maintenance schedules" on public.maintenance_schedules;
drop policy if exists "Admins can read maintenance schedules" on public.maintenance_schedules;
create policy "Admins can read maintenance schedules" on public.maintenance_schedules
  for select to authenticated using (public.current_user_role() = 'Admin');
drop policy if exists "Assistants can read maintenance schedules" on public.maintenance_schedules;
create policy "Assistants can read maintenance schedules" on public.maintenance_schedules
  for select to authenticated using (public.current_user_role() = 'Assistant');
drop policy if exists "Personnel can read maintenance schedules" on public.maintenance_schedules;
create policy "Personnel can read maintenance schedules" on public.maintenance_schedules
  for select to authenticated using (public.current_user_role() = 'Personnel');
drop policy if exists "Admins can create maintenance schedules" on public.maintenance_schedules;
create policy "Admins can create maintenance schedules" on public.maintenance_schedules
  for insert to authenticated with check (public.current_user_role() = 'Admin');
drop policy if exists "Admins can update maintenance schedules" on public.maintenance_schedules;
create policy "Admins can update maintenance schedules" on public.maintenance_schedules
  for update to authenticated using (public.current_user_role() = 'Admin')
  with check (public.current_user_role() = 'Admin');
drop policy if exists "Admins can delete maintenance schedules" on public.maintenance_schedules;
create policy "Admins can delete maintenance schedules" on public.maintenance_schedules
  for delete to authenticated using (public.current_user_role() = 'Admin');

create or replace function public.generate_due_maintenance_work_orders()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  schedule public.maintenance_schedules%rowtype;
  due_date date;
  work_id text;
  generated integer := 0;
  assignees jsonb;
begin
  if coalesce(public.current_user_role(), '') <> 'Admin'
     and coalesce(auth.jwt() ->> 'role', '') <> 'service_role'
     and session_user not in ('postgres', 'supabase_admin') then
    raise exception 'Only administrators or the maintenance scheduler can run due schedules';
  end if;

  for schedule in
    select * from public.maintenance_schedules
     where is_active and next_due <= current_date
     order by next_due
     for update
  loop
    work_id := '#PM-' || upper(substr(md5(schedule.id::text || schedule.next_due::text), 1, 10));
    assignees := case when schedule.default_assignee = '' then '[]'::jsonb
                      else jsonb_build_array(schedule.default_assignee) end;
    insert into public.reports (
      id, title, description, category, location, risk, priority, status,
      assigned_to, assigned_personnel, technician_state, reporter, report_date
    )
    values (
      work_id, '[Preventive] ' || schedule.title,
      'Scheduled preventive maintenance. Checklist: ' || coalesce(schedule.checklist_items::text, '[]'),
      schedule.category,
      coalesce(nullif(schedule.location_label, ''), (
        select concat_ws(' · ', building, nullif(floor, ''), nullif(room, ''))
          from public.locations where id = schedule.location_id
      ), 'Campus'),
      'low', 'medium', 'pending',
      nullif(schedule.default_assignee, ''), assignees,
      case when schedule.default_assignee = '' then 'unassigned' else 'assigned' end,
      'Preventive Maintenance', current_date::text
    )
    on conflict (id) do nothing;
    if found then generated := generated + 1; end if;

    due_date := schedule.next_due;
    loop
      due_date := case schedule.frequency
        when 'weekly' then due_date + interval '7 days'
        when 'monthly' then due_date + interval '1 month'
        when 'quarterly' then due_date + interval '3 months'
        when 'yearly' then due_date + interval '1 year'
        else due_date + make_interval(days => schedule.custom_interval_days)
      end;
      exit when due_date > current_date;
    end loop;
    update public.maintenance_schedules
       set next_due = due_date, updated_at = now()
     where id = schedule.id;
  end loop;
  return generated;
end;
$$;
revoke all on function public.generate_due_maintenance_work_orders() from public, anon;
grant execute on function public.generate_due_maintenance_work_orders() to authenticated, service_role;

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
    select r.id, r.category, r.location, r.priority, r.status, r.due_at,
           r.created_at, r.completed_at, r.rework_count,
           case when jsonb_typeof(r.assigned_personnel) = 'array' then r.assigned_personnel else '[]'::jsonb end as assigned_personnel
      from public.reports r
    union all
    select q.id, q.category, q.department, q.priority, q.status, q.due_at,
           q.created_at, q.completed_at, q.rework_count,
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
      'overdue', (select count(*) from filtered where status not in ('closed', 'resolved', 'action-taken') and due_at < now()),
      'completed', (select count(*) from work where completed_at::date between p_from_date and p_to_date
                    and (p_category is null or p_category = '' or category = p_category)),
      'avgResolutionDays', (select round(avg(extract(epoch from (completed_at - created_at)) / 86400)::numeric, 2)
                            from filtered where completed_at is not null and completed_at >= created_at),
      'slaCompliance', coalesce((select round(100.0 * count(*) filter (where completed_at <= due_at) / nullif(count(*), 0), 1)
                                 from filtered where completed_at is not null and due_at is not null), 0),
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
    'priorities', coalesce((select jsonb_agg(jsonb_build_object('name', priority, 'count', amount) order by amount desc)
                            from (select priority, count(*) amount from filtered group by priority) p), '[]'::jsonb),
    'personnel', coalesce((select jsonb_agg(jsonb_build_object('name', name, 'open', open_count, 'completed', completed_count) order by open_count desc)
                           from personnel), '[]'::jsonb)
  ) into result;
  return result;
end;
$$;
revoke all on function public.get_unifix_analytics(date, date, text) from public, anon;
grant execute on function public.get_unifix_analytics(date, date, text) to authenticated;
