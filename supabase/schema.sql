    -- UNIFIX Supabase schema
    -- Run this script in Supabase SQL Editor before enabling database persistence.

    create table if not exists public.reports (
    id text primary key,
    title text not null,
    description text,
    category text not null,
    category_icon text,
    category_background text,
    location text not null,
    risk text not null default 'low' check (risk in ('low', 'medium', 'urgent')),
    status text not null default 'pending',
    assigned_to text,
    assigned_personnel jsonb not null default '[]'::jsonb,
    technician_state text not null default 'unassigned',
    reporter text not null,
    report_date text not null,
    photo text,
    assignment_note text,
    admin_remark text,
    target_date text,
    created_at timestamptz not null default now()
    );

    create table if not exists public.requests (
    id text primary key,
    title text not null,
    category text not null,
    department text not null,
    details text,
    requester text not null,
    risk text not null default 'low' check (risk in ('low', 'medium', 'urgent')),
    status text not null default 'submitted',
    admin_response text,
    admin_remark text,
    action_date text,
    feedback text,
    feedback_date text,
    request_date text not null,
    created_at timestamptz not null default now()
    );

    create table if not exists public.login_events (
    id text primary key,
    user_name text not null,
    role text not null,
    email text not null,
    logged_in_at timestamptz not null default now()
    );

    create table if not exists public.user_profiles (
        id text primary key,
        name text not null,
        email text not null unique,
        role text not null check (role in ('Admin', 'Assistant', 'Employee', 'Student', 'Personnel')),
        department text not null default '',
        phone text not null default '',
        location text not null default 'Main Campus',
        is_active boolean not null default true,
        created_at timestamptz not null default now(),
        updated_at timestamptz not null default now()
        );

    -- Per-user UI preferences belong on the server too.  Keeping these separate
    -- from the identity profile makes it safe to extend them without granting
    -- users permission to change their role or department.
    create table if not exists public.user_preferences (
        user_email text primary key,
        email_notifications boolean not null default true,
        inapp_notifications boolean not null default true,
        urgent_alerts boolean not null default false,
        landing_page text not null default 'dashboard',
        session_timeout text not null default '30',
        updated_at timestamptz not null default now(),
        constraint user_preferences_landing_page_check
          check (landing_page in ('dashboard', 'submit', 'reports', 'profile')),
        constraint user_preferences_session_timeout_check
          check (session_timeout in ('0', '15', '30', '60'))
    );

    alter table public.reports add column if not exists assigned_personnel jsonb not null default '[]'::jsonb;
    alter table public.reports add column if not exists admin_remark text;
    alter table public.requests add column if not exists admin_remark text;
    alter table public.requests add column if not exists feedback text;
    alter table public.requests add column if not exists feedback_date text;
    alter table public.requests add column if not exists assigned_to text;
    alter table public.requests add column if not exists assigned_personnel jsonb not null default '[]'::jsonb;
    alter table public.requests add column if not exists technician_state text not null default 'unassigned';
    alter table public.requests add column if not exists assignment_note text;
    alter table public.requests add column if not exists target_date text;
    alter table public.requests add column if not exists completion_photo text;
    alter table public.reports replica identity full;
    alter table public.requests replica identity full;

        do $$
        begin
            if not exists (
                select 1
                from pg_publication_rel pr
                join pg_class c on c.oid = pr.prrelid
                join pg_namespace n on n.oid = c.relnamespace
                join pg_publication p on p.oid = pr.prpubid
                where p.pubname = 'supabase_realtime'
                    and n.nspname = 'public'
                    and c.relname = 'reports'
            ) then
                execute 'alter publication supabase_realtime add table public.reports';
            end if;
            if not exists (
                select 1
                from pg_publication_rel pr
                join pg_class c on c.oid = pr.prrelid
                join pg_namespace n on n.oid = c.relnamespace
                join pg_publication p on p.oid = pr.prpubid
                where p.pubname = 'supabase_realtime'
                    and n.nspname = 'public'
                    and c.relname = 'requests'
            ) then
                execute 'alter publication supabase_realtime add table public.requests';
            end if;
        end $$;
    update public.reports
      set assigned_personnel = to_jsonb(array[assigned_to])
      where assigned_to is not null
        and assigned_to <> ''
        and assigned_personnel = '[]'::jsonb;

        alter table public.user_profiles add column if not exists is_active boolean not null default true;

        insert into public.user_profiles (id, name, email, role, department)
        values
            ('admin-user', 'Admin User', 'admin.user@nvsu.edu.ph', 'Admin', 'Campus Administration'),
            ('admin-assistant', 'Admin Assistant', 'admin.assistant@nvsu.edu.ph', 'Assistant', 'Campus Administration'),
            ('employee-user', 'Prof. Reyes', 'prof.reyes@nvsu.edu.ph', 'Employee', 'College of Engineering'),
            ('student-user', 'Student User', 'student.user@nvsu.edu.ph', 'Student', 'Student Affairs'),
            ('personnel-user', 'Juan dela Cruz', 'juan.delacruz@nvsu.edu.ph', 'Personnel', 'Maintenance Operations')
            ,('personnel-maria', 'Maria Santos', 'maria.santos@nvsu.edu.ph', 'Personnel', 'Maintenance Operations')
        on conflict (id) do update set
            name = excluded.name,
            email = excluded.email,
            role = excluded.role,
            department = excluded.department,
            updated_at = now();

    alter table public.reports enable row level security;
    alter table public.requests enable row level security;
    alter table public.login_events enable row level security;
        alter table public.user_profiles enable row level security;
        alter table public.user_preferences enable row level security;
        -- Role lookup runs with the function owner's privileges to avoid recursive RLS checks.
        create or replace function public.current_user_role()
        returns text
        language sql
        stable
        security definer
        set search_path = public
        as $$
            select role
            from public.user_profiles
            where is_active
                and lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
            limit 1;
        $$;

        revoke all on function public.current_user_role() from public;
        grant execute on function public.current_user_role() to authenticated;

        drop policy if exists "Allow demo report access" on public.reports;
        drop policy if exists "Allow demo request access" on public.requests;
        drop policy if exists "Allow demo login event access" on public.login_events;
        drop policy if exists "Allow demo user profile access" on public.user_profiles;
        drop policy if exists "Authenticated users can read reports" on public.reports;
        drop policy if exists "Users can create own reports" on public.reports;
        drop policy if exists "Admins can manage reports" on public.reports;
        drop policy if exists "Assistants can update report risk" on public.reports;
        drop policy if exists "Personnel can update assigned reports" on public.reports;
        drop policy if exists "Assistants can update report risk" on public.reports;
        drop policy if exists "Authenticated users can read requests" on public.requests;
        drop policy if exists "Users can create own requests" on public.requests;
        drop policy if exists "Users can submit feedback on own requests" on public.requests;
        drop policy if exists "Personnel can update assigned requests" on public.requests;
        drop policy if exists "Assistants can update request risk" on public.requests;
        drop policy if exists "Admins can manage requests" on public.requests;
        drop policy if exists "Assistants can update request risk" on public.requests;
        drop policy if exists "Admins can read login events" on public.login_events;
        drop policy if exists "Users can read own profile" on public.user_profiles;
        drop policy if exists "Users can update own profile" on public.user_profiles;
        drop policy if exists "Admins can manage profiles" on public.user_profiles;
        drop policy if exists "Users can manage own preferences" on public.user_preferences;

        create policy "Authenticated users can read reports" on public.reports
            for select to authenticated
            using (
                public.current_user_role() in ('Admin', 'Assistant', 'Personnel')
                or lower(reporter) = lower((select name from public.user_profiles where lower(email) = lower(auth.jwt() ->> 'email') limit 1))
            );

        create policy "Users can create own reports" on public.reports
            for insert to authenticated
            with check (
                public.current_user_role() in ('Admin', 'Assistant', 'Employee', 'Student', 'Personnel')
                and lower(reporter) = lower((select name from public.user_profiles where lower(email) = lower(auth.jwt() ->> 'email') limit 1))
            );

        create policy "Admins can manage reports" on public.reports
            for all to authenticated
            using (public.current_user_role() = 'Admin')
            with check (public.current_user_role() = 'Admin');

        create policy "Personnel can update assigned reports" on public.reports
            for update to authenticated
            using (
                public.current_user_role() = 'Personnel'
                and exists (
                  select 1 from jsonb_array_elements_text(assigned_personnel) as assigned(name)
                  where lower(assigned.name) = lower((select name from public.user_profiles where lower(email) = lower(auth.jwt() ->> 'email') limit 1))
                )
            )
            with check (
                public.current_user_role() = 'Personnel'
                and exists (
                  select 1 from jsonb_array_elements_text(assigned_personnel) as assigned(name)
                  where lower(assigned.name) = lower((select name from public.user_profiles where lower(email) = lower(auth.jwt() ->> 'email') limit 1))
                )
            );

        create policy "Authenticated users can read requests" on public.requests
            for select to authenticated
            using (
                public.current_user_role() in ('Admin', 'Assistant')
                                or (
                                    public.current_user_role() = 'Personnel'
                                    and exists (
                                        select 1 from jsonb_array_elements_text(assigned_personnel) as assigned(name)
                                        where lower(assigned.name) = lower((select name from public.user_profiles where lower(email) = lower(auth.jwt() ->> 'email') limit 1))
                                    )
                                )
                or lower(requester) = lower((select name from public.user_profiles where lower(email) = lower(auth.jwt() ->> 'email') limit 1))
            );

        create policy "Users can create own requests" on public.requests
            for insert to authenticated
            with check (
                public.current_user_role() in ('Admin', 'Employee')
                and lower(requester) = lower((select name from public.user_profiles where lower(email) = lower(auth.jwt() ->> 'email') limit 1))
            );

        create policy "Users can submit feedback on own requests" on public.requests
            for update to authenticated
            using (
                public.current_user_role() = 'Employee'
                and status = 'action-taken'
                and lower(requester) = lower((select name from public.user_profiles where lower(email) = lower(auth.jwt() ->> 'email') limit 1))
            )
            with check (
                public.current_user_role() = 'Employee'
                and status = 'action-taken'
                and lower(requester) = lower((select name from public.user_profiles where lower(email) = lower(auth.jwt() ->> 'email') limit 1))
            );

        create policy "Personnel can update assigned requests" on public.requests
            for update to authenticated
            using (
                public.current_user_role() = 'Personnel'
                and exists (
                    select 1 from jsonb_array_elements_text(assigned_personnel) as assigned(name)
                    where lower(assigned.name) = lower((select name from public.user_profiles where lower(email) = lower(auth.jwt() ->> 'email') limit 1))
                )
            )
            with check (
                public.current_user_role() = 'Personnel'
                and exists (
                    select 1 from jsonb_array_elements_text(assigned_personnel) as assigned(name)
                    where lower(assigned.name) = lower((select name from public.user_profiles where lower(email) = lower(auth.jwt() ->> 'email') limit 1))
                )
            );

        create policy "Admins can manage requests" on public.requests
            for all to authenticated
            using (public.current_user_role() = 'Admin')
            with check (public.current_user_role() = 'Admin');

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
                -- Technicians can advance only work assigned to them; assignment,
                -- report content, priority, and reporter identity remain immutable.
                if not exists (
                    select 1 from jsonb_array_elements_text(old.assigned_personnel) as assigned(name)
                    where lower(assigned.name) = lower((select name from public.user_profiles where lower(email) = lower(auth.jwt() ->> 'email') limit 1))
                  )
                  or new.assigned_to is distinct from old.assigned_to
                  or new.assigned_personnel is distinct from old.assigned_personnel
                  or (new.technician_state = 'completed' and old.technician_state <> 'started')
                        or to_jsonb(new) - array['status', 'technician_state', 'assignment_note', 'photo']
                            <> to_jsonb(old) - array['status', 'technician_state', 'assignment_note', 'photo'] then
                    raise exception 'Personnel may update only the state of work assigned to them';
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
                        or to_jsonb(new) - array['technician_state', 'assignment_note', 'completion_photo']
                            <> to_jsonb(old) - array['technician_state', 'assignment_note', 'completion_photo'] then
                    raise exception 'Personnel may update only the state of requests assigned to them';
                end if;
            elsif public.current_user_role() <> 'Admin' then
                raise exception 'This role cannot update this record';
            end if;
            return new;
        end;
        $$;

        drop trigger if exists enforce_report_update_scope on public.reports;
        drop trigger if exists enforce_request_update_scope on public.requests;
        create trigger enforce_report_update_scope
            before update on public.reports
            for each row execute function public.enforce_role_update_scope();
        create trigger enforce_request_update_scope
            before update on public.requests
            for each row execute function public.enforce_role_update_scope();

        revoke all on function public.enforce_role_update_scope() from public;
        grant execute on function public.enforce_role_update_scope() to authenticated;

        create policy "Admins can read login events" on public.login_events
            for select to authenticated
            using (public.current_user_role() = 'Admin');

        create policy "Users can read own profile" on public.user_profiles
            for select to authenticated
            using (lower(email) = lower(auth.jwt() ->> 'email'));

        -- A user may maintain only their contact details.  The trigger below
        -- prevents privilege fields from being changed even if a client submits
        -- a broader update payload.
        create policy "Users can update own profile" on public.user_profiles
            for update to authenticated
            using (lower(email) = lower(auth.jwt() ->> 'email'))
            with check (lower(email) = lower(auth.jwt() ->> 'email'));

        create policy "Admins can manage profiles" on public.user_profiles
            for all to authenticated
            using (public.current_user_role() = 'Admin')
            with check (public.current_user_role() = 'Admin');

        create policy "Users can manage own preferences" on public.user_preferences
            for all to authenticated
            using (lower(user_email) = lower(auth.jwt() ->> 'email'))
            with check (lower(user_email) = lower(auth.jwt() ->> 'email'));

        create or replace function public.set_updated_at()
        returns trigger
        language plpgsql
        as $$
        begin
          new.updated_at = now();
          return new;
        end;
        $$;

        create or replace function public.enforce_profile_update_scope()
        returns trigger
        language plpgsql
        security definer
        set search_path = public
        as $$
        begin
          if public.current_user_role() <> 'Admin' then
            if new.id <> old.id
              or new.email <> old.email
              or new.role <> old.role
              or new.department <> old.department
              or new.is_active <> old.is_active then
              raise exception 'Only contact details may be updated';
            end if;
          end if;
          return new;
        end;
        $$;

        drop trigger if exists set_user_profiles_updated_at on public.user_profiles;
        create trigger set_user_profiles_updated_at
          before update on public.user_profiles
          for each row execute function public.set_updated_at();

        drop trigger if exists set_user_preferences_updated_at on public.user_preferences;
        create trigger set_user_preferences_updated_at
          before update on public.user_preferences
          for each row execute function public.set_updated_at();

        drop trigger if exists enforce_profile_update_scope on public.user_profiles;
        create trigger enforce_profile_update_scope
          before update on public.user_profiles
          for each row execute function public.enforce_profile_update_scope();

        revoke all on function public.enforce_profile_update_scope() from public;
        grant execute on function public.enforce_profile_update_scope() to authenticated;

-- Phase 1 add-ons. Keep this block aligned with
-- supabase/migrations/202610050001_phase1_tracking_photos_sla_feedback.sql.
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
-- Phase 2: notifications, audit history, and verified completion workflow.

alter table public.reports
  add column if not exists reporter_email text,
  add column if not exists for_verification_at timestamptz,
  add column if not exists verified_at timestamptz,
  add column if not exists rejection_reason text,
  add column if not exists reopen_reason text,
  add column if not exists reopened_at timestamptz,
  add column if not exists rework_count integer not null default 0;

alter table public.requests
  add column if not exists requester_email text,
  add column if not exists for_verification_at timestamptz,
  add column if not exists verified_at timestamptz,
  add column if not exists rejection_reason text,
  add column if not exists reopen_reason text,
  add column if not exists reopened_at timestamptz,
  add column if not exists rework_count integer not null default 0;

alter table public.user_preferences
  add column if not exists sms_notifications boolean not null default false;

update public.reports r
set reporter_email = lower(p.email)
from public.user_profiles p
where r.reporter_email is null
  and lower(r.reporter) = lower(p.name);

update public.requests q
set requester_email = lower(p.email)
from public.user_profiles p
where q.requester_email is null
  and lower(q.requester) = lower(p.name);

update public.reports
set status = 'closed'
where status = 'resolved' and technician_state = 'completed';
update public.requests
set status = 'closed'
where status = 'action-taken' and technician_state = 'completed';

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_email text not null,
  event_type text not null,
  title text not null,
  message text not null,
  entity_type text check (entity_type in ('report', 'request')),
  entity_id text,
  tracking_code text,
  dedupe_key text unique,
  created_at timestamptz not null default now(),
  read_at timestamptz
);
create index if not exists notifications_user_created_idx
  on public.notifications (lower(user_email), created_at desc);
alter table public.notifications enable row level security;
revoke all on public.notifications from public, anon, authenticated;
grant select on public.notifications to authenticated;
drop policy if exists "Users can read their own notifications" on public.notifications;
create policy "Users can read their own notifications" on public.notifications
  for select to authenticated
  using (lower(user_email) = lower(auth.jwt() ->> 'email'));
drop policy if exists "Users can update read state of own notifications" on public.notifications;

create table if not exists public.notification_deliveries (
  id uuid primary key default gen_random_uuid(),
  channel text not null check (channel in ('email', 'sms')),
  recipient text not null,
  subject text not null default '',
  body text not null,
  event_type text not null,
  entity_type text check (entity_type in ('report', 'request')),
  entity_id text,
  tracking_code text,
  dedupe_key text unique,
  status text not null default 'pending' check (status in ('pending', 'processing', 'sent', 'failed')),
  attempt_count integer not null default 0,
  last_error text,
  created_at timestamptz not null default now(),
  sent_at timestamptz
);
create index if not exists notification_deliveries_pending_idx
  on public.notification_deliveries (created_at) where status in ('pending', 'failed');
alter table public.notification_deliveries enable row level security;
revoke all on public.notification_deliveries from public, anon, authenticated;
grant all on public.notification_deliveries to service_role;

create table if not exists public.audit_log (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null check (entity_type in ('report', 'request')),
  entity_id text not null,
  action text not null,
  actor_email text,
  actor_role text,
  old_value jsonb,
  new_value jsonb,
  created_at timestamptz not null default now()
);
create index if not exists audit_log_entity_created_idx
  on public.audit_log (entity_type, entity_id, created_at);
create index if not exists audit_log_created_idx on public.audit_log (created_at desc);
alter table public.audit_log enable row level security;
revoke all on public.audit_log from public, anon, authenticated;
grant select on public.audit_log to authenticated;
drop policy if exists "Admins can read global audit log" on public.audit_log;
create policy "Admins can read global audit log" on public.audit_log
  for select to authenticated using (public.current_user_role() = 'Admin');
drop policy if exists "Users can read relevant work item audit history" on public.audit_log;
drop policy if exists "Staff can read relevant work item audit history" on public.audit_log;
create policy "Staff can read relevant work item audit history" on public.audit_log
  for select to authenticated using (
    public.current_user_role() in ('Admin', 'Assistant')
    or (
      public.current_user_role() = 'Personnel'
      and (
        (entity_type = 'report' and exists (
          select 1 from public.reports r
          where r.id = entity_id
            and exists (
              select 1 from jsonb_array_elements_text(r.assigned_personnel) assigned(name)
              join public.user_profiles p on lower(p.name) = lower(assigned.name)
              where lower(p.email) = lower(auth.jwt() ->> 'email')
            )
        ))
        or
        (entity_type = 'request' and exists (
          select 1 from public.requests q
          where q.id = entity_id
            and exists (
              select 1 from jsonb_array_elements_text(q.assigned_personnel) assigned(name)
              join public.user_profiles p on lower(p.name) = lower(assigned.name)
              where lower(p.email) = lower(auth.jwt() ->> 'email')
            )
        ))
      )
    )
  );

drop policy if exists "Assistants can verify reports" on public.reports;
create policy "Assistants can verify reports" on public.reports
  for update to authenticated
  using (public.current_user_role() = 'Assistant' and status = 'for-verification')
  with check (public.current_user_role() = 'Assistant' and status in ('for-verification', 'closed', 'in-progress'));
drop policy if exists "Assistants can verify requests" on public.requests;
create policy "Assistants can verify requests" on public.requests
  for update to authenticated
  using (public.current_user_role() = 'Assistant' and status = 'for-verification')
  with check (public.current_user_role() = 'Assistant' and status in ('for-verification', 'closed', 'in-progress'));

drop policy if exists "Users can submit feedback on own requests" on public.requests;
create policy "Users can submit feedback on own requests" on public.requests
  for update to authenticated
  using (
    public.current_user_role() = 'Employee'
    and status = 'closed'
    and lower(requester_email) = lower(auth.jwt() ->> 'email')
  )
  with check (
    public.current_user_role() = 'Employee'
    and status = 'closed'
    and lower(requester_email) = lower(auth.jwt() ->> 'email')
  );
drop policy if exists "Employees can reopen own requests" on public.requests;
create policy "Employees can reopen own requests" on public.requests
  for update to authenticated
  using (
    public.current_user_role() = 'Employee'
    and status = 'closed'
    and lower(requester_email) = lower(auth.jwt() ->> 'email')
  )
  with check (
    public.current_user_role() = 'Employee'
    and status = 'in-progress'
    and lower(requester_email) = lower(auth.jwt() ->> 'email')
  );

create or replace function public.create_work_item_notification(
  p_email text,
  p_event_type text,
  p_title text,
  p_message text,
  p_entity_type text,
  p_entity_id text,
  p_tracking_code text default null,
  p_sms_message text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_email text := lower(btrim(coalesce(p_email, '')));
  inapp_enabled boolean;
  email_enabled boolean;
  sms_enabled boolean;
  phone_number text;
begin
  if normalized_email = '' then return; end if;

  select   coalesce(p.inapp_notifications, true),
         coalesce(p.email_notifications, true),
         coalesce(p.sms_notifications, false),
         nullif(btrim(profile.phone), '')
    into inapp_enabled, email_enabled, sms_enabled, phone_number
  from public.user_profiles profile
  left join public.user_preferences p on lower(p.user_email) = lower(profile.email)
  where lower(profile.email) = normalized_email
    and profile.is_active
  limit 1;

  if inapp_enabled then
    insert into public.notifications (user_email, event_type, title, message, entity_type, entity_id, tracking_code)
    values (normalized_email, p_event_type, p_title, p_message, p_entity_type, p_entity_id, p_tracking_code);
  end if;

  -- An explicitly supplied reporter email is an opt-in, even without an account.
  if coalesce(email_enabled, true) then
    insert into public.notification_deliveries
      (channel, recipient, subject, body, event_type, entity_type, entity_id, tracking_code)
    values (
      'email', normalized_email, p_title,
      p_message || case when p_tracking_code is null then '' else E'\n\nTracking code: ' || p_tracking_code end,
      p_event_type, p_entity_type, p_entity_id, p_tracking_code
    );
  end if;

  if sms_enabled and phone_number is not null and p_sms_message is not null then
    insert into public.notification_deliveries
      (channel, recipient, body, event_type, entity_type, entity_id, tracking_code)
    values ('sms', phone_number, p_sms_message, p_event_type, p_entity_type, p_entity_id, p_tracking_code);
  end if;
end;
$$;
revoke all on function public.create_work_item_notification(text, text, text, text, text, text, text, text)
  from public, anon, authenticated;

create or replace function public.notify_work_item_staff(
  p_event_type text,
  p_title text,
  p_message text,
  p_entity_type text,
  p_entity_id text,
  p_tracking_code text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  recipient record;
begin
  for recipient in
    select email from public.user_profiles
    where is_active and role in ('Admin', 'Assistant')
  loop
    perform public.create_work_item_notification(
      recipient.email, p_event_type, p_title, p_message,
      p_entity_type, p_entity_id, p_tracking_code, null
    );
  end loop;
end;
$$;
revoke all on function public.notify_work_item_staff(text, text, text, text, text, text)
  from public, anon, authenticated;

create or replace function public.audit_work_item_changes()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.audit_log (entity_type, entity_id, action, actor_email, actor_role, new_value)
    values (
      case when tg_table_name = 'reports' then 'report' else 'request' end,
      new.id, 'created',
      coalesce(auth.jwt() ->> 'email', case when tg_table_name = 'reports' then new.reporter_email else new.requester_email end),
      coalesce(public.current_user_role(), case when auth.role() = 'service_role' then 'Public' else null end),
      jsonb_build_object('status', new.status, 'priority', new.priority)
    );
    return new;
  end if;

  if new.status is distinct from old.status then
    insert into public.audit_log (entity_type, entity_id, action, actor_email, actor_role, old_value, new_value)
    values (
      case when tg_table_name = 'reports' then 'report' else 'request' end,
      new.id, 'status_changed',
      coalesce(auth.jwt() ->> 'email', case when tg_table_name = 'reports' then new.reporter_email else new.requester_email end),
      coalesce(public.current_user_role(), case when auth.role() = 'service_role' then 'Public' else null end),
      jsonb_build_object('status', old.status), jsonb_build_object('status', new.status)
    );
  end if;
  if new.assigned_personnel is distinct from old.assigned_personnel
      or new.assigned_to is distinct from old.assigned_to then
    insert into public.audit_log (entity_type, entity_id, action, actor_email, actor_role, old_value, new_value)
    values (
      case when tg_table_name = 'reports' then 'report' else 'request' end,
      new.id, 'assignment_changed',
      coalesce(auth.jwt() ->> 'email', case when tg_table_name = 'reports' then new.reporter_email else new.requester_email end),
      coalesce(public.current_user_role(), case when auth.role() = 'service_role' then 'Public' else null end),
      jsonb_build_object('assigned_count', jsonb_array_length(coalesce(old.assigned_personnel, '[]'::jsonb))),
      jsonb_build_object('assigned_count', jsonb_array_length(coalesce(new.assigned_personnel, '[]'::jsonb)))
    );
  end if;
  if new.priority is distinct from old.priority then
    insert into public.audit_log (entity_type, entity_id, action, actor_email, actor_role, old_value, new_value)
    values (
      case when tg_table_name = 'reports' then 'report' else 'request' end,
      new.id, 'priority_changed',
      coalesce(auth.jwt() ->> 'email', case when tg_table_name = 'reports' then new.reporter_email else new.requester_email end),
      coalesce(public.current_user_role(), case when auth.role() = 'service_role' then 'Public' else null end),
      jsonb_build_object('priority', old.priority), jsonb_build_object('priority', new.priority)
    );
  end if;
  return new;
end;
$$;
revoke all on function public.audit_work_item_changes() from public, anon, authenticated;

create or replace function public.notify_work_item_changes()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  entity_kind text := case when tg_table_name = 'reports' then 'report' else 'request' end;
  item_title text := new.title;
  item_owner_email text;
  assigned_name text;
  person_email text;
  assignment_names jsonb;
begin
  if tg_op = 'INSERT' then
    item_owner_email := case when tg_table_name = 'reports' then new.reporter_email else new.requester_email end;
    perform public.notify_work_item_staff(
      'work_received', 'New work item received',
      'A new ' || entity_kind || ' is ready for review: ' || item_title,
      entity_kind, new.id, new.tracking_code
    );
    if item_owner_email is not null then
      perform public.create_work_item_notification(
        item_owner_email, 'work_received', 'Submission received',
        'Your ' || entity_kind || ' was received and is awaiting review.',
        entity_kind, new.id, new.tracking_code, 'UNIFIX received your submission.'
      );
    end if;
    return new;
  end if;

  item_owner_email := case when tg_table_name = 'reports' then new.reporter_email else new.requester_email end;
  if new.assigned_personnel is distinct from old.assigned_personnel
      or new.assigned_to is distinct from old.assigned_to then
    assignment_names := coalesce(new.assigned_personnel, '[]'::jsonb);
    for assigned_name in select jsonb_array_elements_text(assignment_names)
    loop
      select email into person_email from public.user_profiles
      where is_active and role = 'Personnel' and lower(name) = lower(assigned_name)
      limit 1;
      if person_email is not null then
        if not exists (
          select 1 from jsonb_array_elements_text(coalesce(old.assigned_personnel, '[]'::jsonb)) previous(name)
          where lower(previous.name) = lower(assigned_name)
        ) then
        perform public.create_work_item_notification(
          person_email, 'new_assignment', 'New work assigned',
          'You have been assigned ' || entity_kind || ' ' || new.id || ': ' || item_title,
          entity_kind, new.id, new.tracking_code,
          'UNIFIX assigned you ' || new.id || '.'
        );
        end if;
      end if;
    end loop;
    if item_owner_email is not null then
      perform public.create_work_item_notification(
        item_owner_email, 'work_assigned', 'Work item assigned',
        'Your ' || entity_kind || ' has been assigned to the maintenance team.',
        entity_kind, new.id, new.tracking_code, 'UNIFIX assigned your work item.'
      );
    end if;
  end if;

  if new.status is distinct from old.status and item_owner_email is not null then
    perform public.create_work_item_notification(
      item_owner_email,
      case when new.status = 'closed' then 'work_completed' else 'status_changed' end,
      case when new.status = 'closed' then 'Work completed' else 'Work status updated' end,
      'Your ' || entity_kind || ' ' || new.id || ' status is now ' || replace(new.status, '-', ' ') || '.',
      entity_kind, new.id, new.tracking_code,
      'UNIFIX ' || new.id || ' status: ' || replace(new.status, '-', ' ') || '.'
    );
  end if;
  return new;
end;
$$;
revoke all on function public.notify_work_item_changes() from public, anon, authenticated;

drop trigger if exists audit_reports_changes on public.reports;
create trigger audit_reports_changes after insert or update on public.reports
  for each row execute function public.audit_work_item_changes();
drop trigger if exists audit_requests_changes on public.requests;
create trigger audit_requests_changes after insert or update on public.requests
  for each row execute function public.audit_work_item_changes();
drop trigger if exists notify_reports_changes on public.reports;
create trigger notify_reports_changes after insert or update on public.reports
  for each row execute function public.notify_work_item_changes();
drop trigger if exists notify_requests_changes on public.requests;
create trigger notify_requests_changes after insert or update on public.requests
  for each row execute function public.notify_work_item_changes();

create or replace function public.enforce_role_update_scope()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  user_role text := public.current_user_role();
  owner_email text;
  start_status text;
  close_status text;
begin
  if tg_table_name = 'reports' then
    owner_email := new.reporter_email;
    close_status := 'closed';
  else
    owner_email := new.requester_email;
    close_status := 'closed';
  end if;
  start_status := old.status;

  if auth.role() = 'service_role' then
    return new;
  end if;

  if tg_table_name = 'reports' and new.status = 'resolved' and new.technician_state <> 'completed' then
    raise exception 'Reports can be completed only after personnel submits work for verification';
  elsif tg_table_name = 'requests' and new.status = 'action-taken' and new.technician_state <> 'completed' then
    raise exception 'Requests can be completed only after personnel submits work for verification';
  end if;

  if user_role = 'Assistant' then
    if old.status <> 'for-verification'
      or new.status not in ('closed', 'in-progress')
      or to_jsonb(new) - array[
        'status', 'technician_state', 'verified_at', 'completed_at',
        'for_verification_at', 'rejection_reason', 'rework_count', 'updated_at',
        'admin_response', 'action_date'
      ] <> to_jsonb(old) - array[
        'status', 'technician_state', 'verified_at', 'completed_at',
        'for_verification_at', 'rejection_reason', 'rework_count', 'updated_at',
        'admin_response', 'action_date'
      ] then
      raise exception 'Assistants may only verify or reject completed work';
    end if;
  end if;

  if user_role in ('Admin', 'Assistant') then
    if new.status = close_status and old.status <> 'for-verification' then
      raise exception 'Work can be closed only after personnel submits it for verification';
    end if;
    if new.status = 'in-progress' and old.status = 'for-verification' then
      if nullif(btrim(new.rejection_reason), '') is null then
        raise exception 'A reason is required when rejecting completed work';
      end if;
      new.rework_count := old.rework_count + 1;
      new.technician_state := 'started';
    elsif new.status = close_status and old.status = 'for-verification' then
      new.verified_at := now();
    end if;
    return new;
  end if;

  if user_role = 'Personnel' then
    if not exists (
      select 1 from jsonb_array_elements_text(old.assigned_personnel) assigned(name)
      where lower(assigned.name) = lower((
        select profile.name from public.user_profiles profile
        where lower(profile.email) = lower(auth.jwt() ->> 'email') limit 1
      ))
    ) or new.assigned_to is distinct from old.assigned_to
      or new.assigned_personnel is distinct from old.assigned_personnel
      or new.rework_count is distinct from old.rework_count
      or new.priority is distinct from old.priority
      or new.reporter_email is distinct from old.reporter_email
      or new.requester_email is distinct from old.requester_email then
      raise exception 'Personnel may update only assigned work and its completion details';
    end if;
    if tg_table_name = 'reports' then
      if to_jsonb(new) - array['status', 'technician_state', 'assignment_note', 'photo', 'photo_attachments', 'completion_photo']
         <> to_jsonb(old) - array['status', 'technician_state', 'assignment_note', 'photo', 'photo_attachments', 'completion_photo'] then
        raise exception 'Personnel may update only the state and completion photos of assigned reports';
      end if;
    elsif to_jsonb(new) - array['status', 'technician_state', 'assignment_note', 'completion_photo', 'photo_attachments']
       <> to_jsonb(old) - array['status', 'technician_state', 'assignment_note', 'completion_photo', 'photo_attachments'] then
      raise exception 'Personnel may update only the state and completion photos of assigned requests';
    end if;
    if new.technician_state = 'completed' and old.technician_state <> 'started' then
      raise exception 'Personnel must start work before submitting it for verification';
    end if;
    if new.technician_state = 'completed' and new.status <> 'for-verification' then
      raise exception 'Personnel completion must enter verification';
    end if;
    if new.status is distinct from old.status and new.status not in ('in-progress', 'for-verification') then
      raise exception 'Personnel cannot verify or close work';
    end if;
    return new;
  end if;

  if user_role = 'Employee' and tg_table_name = 'requests' then
    if old.status = 'closed'
      and new.status = 'in-progress'
      and lower(owner_email) = lower(auth.jwt() ->> 'email')
      and old.completed_at >= now() - interval '7 days'
      and char_length(btrim(coalesce(new.reopen_reason, ''))) between 5 and 500 then
      new.rework_count := old.rework_count + 1;
      new.reopened_at := now();
      new.technician_state := case when jsonb_array_length(old.assigned_personnel) > 0 then 'assigned' else 'unassigned' end;
      return new;
    end if;
    if old.status <> 'closed'
      or new.status <> old.status
      or to_jsonb(new) - array['feedback', 'feedback_date']
         <> to_jsonb(old) - array['feedback', 'feedback_date'] then
      raise exception 'Employees may submit feedback on closed requests or reopen their own request within 7 days';
    end if;
    return new;
  end if;

  if user_role in ('Employee', 'Student') and tg_table_name = 'reports'
    and old.status = 'closed'
    and new.status = 'in-progress'
    and lower(owner_email) = lower(auth.jwt() ->> 'email')
    and old.completed_at >= now() - interval '7 days'
    and char_length(btrim(coalesce(new.reopen_reason, ''))) between 5 and 500 then
    new.rework_count := old.rework_count + 1;
    new.reopened_at := now();
    new.technician_state := case when jsonb_array_length(old.assigned_personnel) > 0 then 'assigned' else 'unassigned' end;
    return new;
  end if;

  raise exception 'This role cannot update this record';
end;
$$;
revoke all on function public.enforce_role_update_scope() from public;
grant execute on function public.enforce_role_update_scope() to authenticated;

create or replace function public.capture_work_item_contact_email()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.role() <> 'service_role' then
    if tg_table_name = 'reports' then
      new.reporter_email := lower(auth.jwt() ->> 'email');
    else
      new.requester_email := lower(auth.jwt() ->> 'email');
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.capture_work_item_contact_email() from public, anon, authenticated;
drop trigger if exists capture_report_contact_email on public.reports;
create trigger capture_report_contact_email before insert on public.reports
  for each row execute function public.capture_work_item_contact_email();
drop trigger if exists capture_request_contact_email on public.requests;
create trigger capture_request_contact_email before insert on public.requests
  for each row execute function public.capture_work_item_contact_email();

create or replace function public.set_phase2_workflow_metadata()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status is distinct from old.status then
    if new.status = 'for-verification' then
      new.for_verification_at := now();
      new.completed_at := null;
      new.verified_at := null;
      new.rejection_reason := null;
    elsif new.status = 'closed' then
      new.completed_at := now();
      new.verified_at := now();
    elsif new.status = 'in-progress' and old.status = 'for-verification' then
      new.for_verification_at := null;
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.set_phase2_workflow_metadata() from public, anon, authenticated;
drop trigger if exists set_phase2_report_workflow_metadata on public.reports;
create trigger set_phase2_report_workflow_metadata before update on public.reports
  for each row execute function public.set_phase2_workflow_metadata();
drop trigger if exists set_phase2_request_workflow_metadata on public.requests;
create trigger set_phase2_request_workflow_metadata before update on public.requests
  for each row execute function public.set_phase2_workflow_metadata();

create or replace function public.reopen_own_work_item(
  p_entity_type text,
  p_entity_id text,
  p_reason text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_count integer;
begin
  if p_entity_type not in ('report', 'request') or char_length(btrim(coalesce(p_reason, ''))) not between 5 and 500 then
    raise exception 'Choose a report or request and provide a reason of 5 to 500 characters';
  end if;

  if p_entity_type = 'report' then
    update public.reports
    set status = 'in-progress', reopen_reason = btrim(p_reason)
    where id = p_entity_id and status = 'closed'
      and lower(reporter_email) = lower(auth.jwt() ->> 'email')
      and completed_at >= now() - interval '7 days';
  else
    update public.requests
    set status = 'in-progress', reopen_reason = btrim(p_reason)
    where id = p_entity_id and status = 'closed'
      and lower(requester_email) = lower(auth.jwt() ->> 'email')
      and completed_at >= now() - interval '7 days';
  end if;
  get diagnostics updated_count = row_count;
  if updated_count = 0 then
    raise exception 'This work item is not eligible to reopen';
  end if;
  return true;
end;
$$;
revoke all on function public.reopen_own_work_item(text, text, text) from public, anon;
grant execute on function public.reopen_own_work_item(text, text, text) to authenticated;

drop policy if exists "Reporters can submit feedback for their completed reports" on public.report_feedback;
create policy "Reporters can submit feedback for their completed reports" on public.report_feedback
  for insert to authenticated
  with check (
    lower(reporter_email) = lower(auth.jwt() ->> 'email')
    and exists (
      select 1 from public.reports r
      where r.id = report_id
        and lower(r.reporter_email) = lower(auth.jwt() ->> 'email')
        and r.status = 'closed'
    )
  );

create or replace function public.mark_notification_read(p_notification_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  changed integer;
begin
  update public.notifications
  set read_at = coalesce(read_at, now())
  where id = p_notification_id
    and lower(user_email) = lower(auth.jwt() ->> 'email');
  get diagnostics changed = row_count;
  return changed = 1;
end;
$$;
revoke all on function public.mark_notification_read(uuid) from public, anon;
grant execute on function public.mark_notification_read(uuid) to authenticated;

create or replace function public.mark_all_notifications_read()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  changed integer;
begin
  update public.notifications
  set read_at = now()
  where lower(user_email) = lower(auth.jwt() ->> 'email')
    and read_at is null;
  get diagnostics changed = row_count;
  return changed;
end;
$$;
revoke all on function public.mark_all_notifications_read() from public, anon;
grant execute on function public.mark_all_notifications_read() to authenticated;

drop policy if exists "Reporters and staff can read report feedback" on public.report_feedback;
create policy "Reporters and staff can read report feedback" on public.report_feedback
  for select to authenticated
  using (
    public.current_user_role() in ('Admin', 'Assistant')
    or lower(reporter_email) = lower(auth.jwt() ->> 'email')
  );

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
    and not exists (
      select 1 from pg_publication_rel pr
      join pg_class c on c.oid = pr.prrelid
      join pg_namespace n on n.oid = c.relnamespace
      join pg_publication p on p.oid = pr.prpubid
      where p.pubname = 'supabase_realtime' and n.nspname = 'public' and c.relname = 'notifications'
    ) then
    execute 'alter publication supabase_realtime add table public.notifications';
  end if;
end $$;

-- The notification-delivery Edge Function handles queued email/SMS delivery.
-- Configure a Database Webhook on INSERT to public.notification_deliveries.
