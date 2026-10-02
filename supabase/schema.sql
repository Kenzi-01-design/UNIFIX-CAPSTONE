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
    action_date text,
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
        drop policy if exists "Authenticated users can read requests" on public.requests;
        drop policy if exists "Users can create own requests" on public.requests;
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

        create policy "Assistants can update report risk" on public.reports
            for update to authenticated
            using (public.current_user_role() = 'Assistant')
            with check (public.current_user_role() = 'Assistant');

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
                or lower(requester) = lower((select name from public.user_profiles where lower(email) = lower(auth.jwt() ->> 'email') limit 1))
            );

        create policy "Users can create own requests" on public.requests
            for insert to authenticated
            with check (
                public.current_user_role() in ('Admin', 'Employee')
                and lower(requester) = lower((select name from public.user_profiles where lower(email) = lower(auth.jwt() ->> 'email') limit 1))
            );

        create policy "Admins can manage requests" on public.requests
            for all to authenticated
            using (public.current_user_role() = 'Admin')
            with check (public.current_user_role() = 'Admin');

        create policy "Assistants can update request risk" on public.requests
            for update to authenticated
            using (public.current_user_role() = 'Assistant')
            with check (public.current_user_role() = 'Assistant');

        create or replace function public.enforce_role_update_scope()
        returns trigger
        language plpgsql
        security definer
        set search_path = public
        as $$
        begin
            if public.current_user_role() = 'Assistant' then
                if tg_table_name = 'reports' then
                      if to_jsonb(new) - 'risk' <> to_jsonb(old) - 'risk' then
                        raise exception 'Assistants may update risk only';
                    end if;
                elsif tg_table_name = 'requests' then
                      if to_jsonb(new) - 'risk' <> to_jsonb(old) - 'risk' then
                        raise exception 'Assistants may update risk only';
                    end if;
                end if;
            elsif public.current_user_role() = 'Personnel' and tg_table_name = 'reports' then
                -- Technicians can advance only work assigned to them; assignment,
                -- report content, priority, and reporter identity remain immutable.
                if not exists (
                    select 1 from jsonb_array_elements_text(old.assigned_personnel) as assigned(name)
                    where lower(assigned.name) = lower((select name from public.user_profiles where lower(email) = lower(auth.jwt() ->> 'email') limit 1))
                  )
                  or new.assigned_to is distinct from old.assigned_to
                  or new.assigned_personnel is distinct from old.assigned_personnel
                  or to_jsonb(new) - array['status', 'technician_state', 'assignment_note']
                     <> to_jsonb(old) - array['status', 'technician_state', 'assignment_note'] then
                    raise exception 'Personnel may update only the state of work assigned to them';
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
