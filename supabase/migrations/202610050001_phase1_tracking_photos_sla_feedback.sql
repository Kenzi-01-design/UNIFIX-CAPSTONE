-- Phase 1: tracking codes, private report photos, SLA deadlines, and report feedback.

alter table public.reports
  add column if not exists tracking_code text,
  add column if not exists priority text not null default 'low',
  add column if not exists due_at timestamptz,
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists reviewed_at timestamptz,
  add column if not exists assigned_at timestamptz,
  add column if not exists in_progress_at timestamptz,
  add column if not exists completed_at timestamptz,
  add column if not exists photo_attachments jsonb not null default '[]'::jsonb;

alter table public.requests
  add column if not exists tracking_code text,
  add column if not exists priority text not null default 'low',
  add column if not exists due_at timestamptz,
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists reviewed_at timestamptz,
  add column if not exists assigned_at timestamptz,
  add column if not exists in_progress_at timestamptz,
  add column if not exists completed_at timestamptz,
  add column if not exists photo_attachments jsonb not null default '[]'::jsonb;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'reports_priority_check') then
    alter table public.reports add constraint reports_priority_check
      check (priority in ('low', 'medium', 'high', 'urgent'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'requests_priority_check') then
    alter table public.requests add constraint requests_priority_check
      check (priority in ('low', 'medium', 'high', 'urgent'));
  end if;
end $$;

create table if not exists public.sla_settings (
  priority text primary key check (priority in ('low', 'medium', 'high', 'urgent')),
  target_hours integer not null check (target_hours > 0 and target_hours <= 8760),
  updated_at timestamptz not null default now()
);

insert into public.sla_settings (priority, target_hours)
values ('low', 168), ('medium', 72), ('high', 24), ('urgent', 4)
on conflict (priority) do nothing;

alter table public.sla_settings enable row level security;
revoke all on public.sla_settings from anon, authenticated;
grant select on public.sla_settings to authenticated;
grant insert, update, delete on public.sla_settings to authenticated;

drop policy if exists "Authenticated roles can read SLA settings" on public.sla_settings;
create policy "Authenticated roles can read SLA settings" on public.sla_settings
  for select to authenticated
  using (public.current_user_role() in ('Admin', 'Assistant', 'Employee', 'Personnel', 'Student'));

drop policy if exists "Admins can manage SLA settings" on public.sla_settings;
create policy "Admins can manage SLA settings" on public.sla_settings
  for all to authenticated
  using (public.current_user_role() = 'Admin')
  with check (public.current_user_role() = 'Admin');

create table if not exists public.tracking_code_counters (
  tracking_year integer primary key,
  last_number bigint not null check (last_number > 0)
);
alter table public.tracking_code_counters enable row level security;
revoke all on public.tracking_code_counters from public, anon, authenticated;
drop policy if exists "No client access to tracking code counters" on public.tracking_code_counters;
create policy "No client access to tracking code counters" on public.tracking_code_counters
  for all to anon, authenticated
  using (false)
  with check (false);

create or replace function public.set_phase1_work_item_metadata()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  work_priority text;
  target_hours integer;
  tracking_year integer;
  tracking_number bigint;
  work_status text;
  technician_status text;
  assignees jsonb;
begin
  work_priority := coalesce(new.priority, 'low');
  work_status := coalesce(new.status, '');
  technician_status := coalesce(new.technician_state, '');
  assignees := coalesce(new.assigned_personnel, '[]'::jsonb);

  if tg_op = 'INSERT' or new.tracking_code is null or btrim(new.tracking_code) = '' then
    tracking_year := extract(year from coalesce(new.created_at, now()))::integer;
    insert into public.tracking_code_counters (tracking_year, last_number)
    values (tracking_year, 1)
    on conflict (tracking_year) do update
      set last_number = public.tracking_code_counters.last_number + 1
    returning last_number into tracking_number;
    new.tracking_code := 'UNI-' || tracking_year::text || '-' || lpad(tracking_number::text, 4, '0');
  elsif new.tracking_code is distinct from old.tracking_code then
    new.tracking_code := old.tracking_code;
  end if;

  if tg_op = 'INSERT' then
    select settings.target_hours into target_hours
    from public.sla_settings settings
    where settings.priority = work_priority;
    new.due_at := now() + make_interval(hours => coalesce(target_hours, 168));
  elsif new.priority is distinct from old.priority or new.due_at is null then
    select settings.target_hours into target_hours
    from public.sla_settings settings
    where settings.priority = work_priority;
    new.due_at := now() + make_interval(hours => coalesce(target_hours, 168));
  end if;

  new.updated_at := now();

  if tg_op = 'INSERT' then
    if work_status not in ('pending', 'urgent', 'submitted', '') then new.reviewed_at := now(); end if;
    if jsonb_array_length(assignees) > 0 then new.assigned_at := now(); end if;
    if technician_status in ('accepted', 'started') or work_status = 'in-progress' then new.in_progress_at := now(); end if;
    if technician_status = 'completed' or work_status in ('resolved', 'action-taken') then new.completed_at := now(); end if;
  else
    if new.status is distinct from old.status
      and work_status not in ('pending', 'urgent', 'submitted', '') then
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

revoke all on function public.set_phase1_work_item_metadata() from public, anon, authenticated;

drop trigger if exists set_phase1_report_metadata on public.reports;
create trigger set_phase1_report_metadata
  before insert or update on public.reports
  for each row execute function public.set_phase1_work_item_metadata();

drop trigger if exists set_phase1_request_metadata on public.requests;
create trigger set_phase1_request_metadata
  before insert or update on public.requests
  for each row execute function public.set_phase1_work_item_metadata();

create unique index if not exists reports_tracking_code_unique on public.reports (tracking_code);
create unique index if not exists requests_tracking_code_unique on public.requests (tracking_code);

update public.reports set
  tracking_code = null,
  due_at = null,
  reviewed_at = case when status not in ('pending', 'urgent') then coalesce(reviewed_at, created_at) else reviewed_at end,
  assigned_at = case when jsonb_array_length(assigned_personnel) > 0 then coalesce(assigned_at, created_at) else assigned_at end,
  in_progress_at = case when technician_state in ('accepted', 'started') or status = 'in-progress' then coalesce(in_progress_at, created_at) else in_progress_at end,
  completed_at = case when technician_state = 'completed' or status in ('resolved', 'action-taken') then coalesce(completed_at, created_at) else completed_at end
where tracking_code is null or due_at is null;
update public.requests set
  tracking_code = null,
  due_at = null,
  reviewed_at = case when status not in ('submitted', '') then coalesce(reviewed_at, created_at) else reviewed_at end,
  assigned_at = case when jsonb_array_length(assigned_personnel) > 0 then coalesce(assigned_at, created_at) else assigned_at end,
  in_progress_at = case when technician_state in ('accepted', 'started') or status = 'in-progress' then coalesce(in_progress_at, created_at) else in_progress_at end,
  completed_at = case when technician_state = 'completed' or status in ('resolved', 'action-taken') then coalesce(completed_at, created_at) else completed_at end
where tracking_code is null or due_at is null;

-- Keep the existing role guard, allowing assigned personnel to attach completion photos.
create or replace function public.enforce_role_update_scope()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_table_name = 'reports'
    and new.status = 'resolved'
    and new.technician_state <> 'completed' then
    raise exception 'Reports can be resolved only after personnel completes the work';
  elsif tg_table_name = 'requests'
    and new.status = 'action-taken'
    and new.technician_state <> 'completed' then
    raise exception 'Requests can be acknowledged only after personnel completes the work';
  elsif public.current_user_role() = 'Personnel' and tg_table_name = 'reports' then
    if not exists (
      select 1 from jsonb_array_elements_text(old.assigned_personnel) as assigned(name)
      where lower(assigned.name) = lower((select name from public.user_profiles where lower(email) = lower(auth.jwt() ->> 'email') limit 1))
    )
    or new.assigned_to is distinct from old.assigned_to
    or new.assigned_personnel is distinct from old.assigned_personnel
    or (new.technician_state = 'completed' and old.technician_state <> 'started')
    or to_jsonb(new) - array['status', 'technician_state', 'assignment_note', 'photo', 'photo_attachments']
       <> to_jsonb(old) - array['status', 'technician_state', 'assignment_note', 'photo', 'photo_attachments'] then
      raise exception 'Personnel may update only the state and completion photos of work assigned to them';
    end if;
  elsif public.current_user_role() = 'Employee' and tg_table_name = 'requests' then
    if old.status <> 'action-taken'
      or new.status <> old.status
      or to_jsonb(new) - array['feedback', 'feedback_date']
         <> to_jsonb(old) - array['feedback', 'feedback_date'] then
      raise exception 'Employees may update only feedback on acknowledged requests';
    end if;
  elsif public.current_user_role() = 'Personnel' and tg_table_name = 'requests' then
    if not exists (
      select 1 from jsonb_array_elements_text(old.assigned_personnel) as assigned(name)
      where lower(assigned.name) = lower((select name from public.user_profiles where lower(email) = lower(auth.jwt() ->> 'email') limit 1))
    )
    or new.assigned_to is distinct from old.assigned_to
    or new.assigned_personnel is distinct from old.assigned_personnel
    or (new.technician_state = 'completed' and old.technician_state <> 'started')
    or to_jsonb(new) - array['technician_state', 'assignment_note', 'completion_photo', 'photo_attachments']
       <> to_jsonb(old) - array['technician_state', 'assignment_note', 'completion_photo', 'photo_attachments'] then
      raise exception 'Personnel may update only the state and completion photos of requests assigned to them';
    end if;
  elsif public.current_user_role() <> 'Admin' then
    raise exception 'This role cannot update this record';
  end if;
  return new;
end;
$$;

create table if not exists public.report_feedback (
  id uuid primary key default gen_random_uuid(),
  report_id text not null unique references public.reports(id) on delete cascade,
  reporter_email text,
  rating smallint not null check (rating between 1 and 5),
  comment text not null default '' check (char_length(comment) <= 500),
  created_at timestamptz not null default now()
);
alter table public.report_feedback enable row level security;
revoke all on public.report_feedback from public, anon, authenticated;
grant select, insert on public.report_feedback to authenticated;

drop policy if exists "Reporters can submit feedback for their completed reports" on public.report_feedback;
create policy "Reporters can submit feedback for their completed reports" on public.report_feedback
  for insert to authenticated
  with check (
    public.current_user_role() in ('Admin', 'Assistant', 'Employee', 'Personnel', 'Student')
    and lower(reporter_email) = lower(auth.jwt() ->> 'email')
    and exists (
      select 1 from public.reports r
      where r.id = report_id
        and lower(r.reporter) = lower((
          select profile.name from public.user_profiles profile
          where lower(profile.email) = lower(auth.jwt() ->> 'email') limit 1
        ))
        and (r.status = 'resolved' or r.technician_state = 'completed')
    )
  );

drop policy if exists "Reporters and staff can read report feedback" on public.report_feedback;
create policy "Reporters and staff can read report feedback" on public.report_feedback
  for select to authenticated
  using (
    public.current_user_role() in ('Admin', 'Assistant')
    or lower(reporter_email) = lower(auth.jwt() ->> 'email')
  );

-- Lookup throttling is private and callable only by the Edge Function's service role.
create table if not exists public.public_endpoint_rate_limits (
  key_hash text primary key,
  window_started_at timestamptz not null,
  request_count integer not null check (request_count >= 0)
);
alter table public.public_endpoint_rate_limits enable row level security;
revoke all on public.public_endpoint_rate_limits from public, anon, authenticated;
grant all on public.public_endpoint_rate_limits to service_role;
drop policy if exists "No client access to public endpoint rate limits" on public.public_endpoint_rate_limits;
create policy "No client access to public endpoint rate limits" on public.public_endpoint_rate_limits
  for all to anon, authenticated
  using (false)
  with check (false);

create or replace function public.consume_public_endpoint_rate_limit(p_key_hash text, p_limit integer default 10)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  current_count integer;
begin
  delete from public.public_endpoint_rate_limits
  where window_started_at < now() - interval '1 minute';

  insert into public.public_endpoint_rate_limits (key_hash, window_started_at, request_count)
  values (p_key_hash, now(), 1)
  on conflict (key_hash) do update
  set window_started_at = case
        when public.public_endpoint_rate_limits.window_started_at <= now() - interval '1 minute' then now()
        else public.public_endpoint_rate_limits.window_started_at
      end,
      request_count = case
        when public.public_endpoint_rate_limits.window_started_at <= now() - interval '1 minute' then 1
        else public.public_endpoint_rate_limits.request_count + 1
      end
  returning request_count into current_count;
  return current_count <= p_limit;
end;
$$;
revoke all on function public.consume_public_endpoint_rate_limit(text, integer) from public, anon, authenticated;
grant execute on function public.consume_public_endpoint_rate_limit(text, integer) to service_role;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('report-photos', 'report-photos', false, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Staff can read report photos" on storage.objects;
create policy "Staff can read report photos" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'report-photos'
    and public.current_user_role() in ('Admin', 'Assistant', 'Personnel')
  );

drop policy if exists "Users can read their own report photos" on storage.objects;
create policy "Users can read their own report photos" on storage.objects
  for select to authenticated
  using (bucket_id = 'report-photos' and owner_id = auth.uid()::text);

drop policy if exists "Authenticated users can upload their own report photos" on storage.objects;
create policy "Authenticated users can upload their own report photos" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'report-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
    and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png', 'webp')
    and coalesce((metadata ->> 'size')::bigint, 0) between 1 and 5242880
    and coalesce(metadata ->> 'mimetype', '') in ('image/jpeg', 'image/png', 'image/webp')
  );

drop policy if exists "Users can delete their own report photos" on storage.objects;
create policy "Users can delete their own report photos" on storage.objects
  for delete to authenticated
  using (bucket_id = 'report-photos' and owner_id = auth.uid()::text);
