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
        auth_user_id uuid unique references auth.users(id) on delete cascade,
        name text not null,
        email text not null unique,
        role text not null check (role in ('Admin', 'Assistant', 'Employee', 'Student', 'Personnel')),
        requested_role text not null default 'Employee'
          constraint user_profiles_requested_role_check
          check (requested_role in ('Employee', 'Assistant', 'Personnel')),
        department text not null default '',
        phone text not null default '',
        location text not null default 'Main Campus',
        is_active boolean not null default true,
        registration_status text not null default 'approved'
          check (registration_status in ('pending', 'approved', 'rejected')),
        rejection_reason text,
        created_at timestamptz not null default now(),
        updated_at timestamptz not null default now()
        );
    create table if not exists public.account_audit_log (
      id bigint generated always as identity primary key,
      actor_auth_user_id uuid,
      actor_email text not null,
      action text not null,
      target_auth_user_id uuid,
      target_email text,
      details jsonb not null default '{}'::jsonb,
      created_at timestamptz not null default now()
    );
    create index if not exists account_audit_log_created_at_idx
      on public.account_audit_log (created_at desc);
    create index if not exists account_audit_log_target_idx
      on public.account_audit_log (target_auth_user_id, created_at desc);
    alter table public.user_profiles
      add column if not exists auth_user_id uuid references auth.users(id) on delete cascade;
    alter table public.user_profiles
      add column if not exists rejection_reason text;
    alter table public.user_profiles
      add column if not exists requested_role text not null default 'Employee'
      constraint user_profiles_requested_role_check
      check (requested_role in ('Employee', 'Assistant', 'Personnel'));
    create unique index if not exists user_profiles_auth_user_id_uidx
      on public.user_profiles (auth_user_id) where auth_user_id is not null;
    alter table public.user_profiles
      add column if not exists registration_status text not null default 'approved'
      check (registration_status in ('pending', 'approved', 'rejected'));

    create table if not exists public.account_security_settings (
      singleton boolean primary key default true check (singleton),
      allowed_email_domains text[] not null default array['nvsu.edu.ph']::text[],
      updated_at timestamptz not null default now()
    );
    insert into public.account_security_settings (singleton, allowed_email_domains)
      values (true, array['nvsu.edu.ph']::text[]) on conflict (singleton) do nothing;

    -- Per-user UI preferences belong on the server too.  Keeping these separate
    -- from the identity profile makes it safe to extend them without granting
    -- users permission to change their role or department.
    create table if not exists public.user_preferences (
        user_email text primary key,
        email_notifications boolean not null default false,
        notification_email text,
        notification_email_verified boolean not null default false,
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

    alter table public.reports enable row level security;
    alter table public.requests enable row level security;
    alter table public.login_events enable row level security;
        alter table public.user_profiles enable row level security;
        alter table public.user_preferences enable row level security;
        alter table public.account_security_settings enable row level security;
        alter table public.account_audit_log enable row level security;
        revoke all on public.account_security_settings from public, anon, authenticated;
        revoke all on public.account_audit_log from public, anon, authenticated;
        grant select on public.account_audit_log to authenticated;
        grant insert, select on public.account_audit_log to service_role;
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
                and registration_status = 'approved'
                and (
                  auth_user_id = auth.uid()
                  or (
                    auth_user_id is null
                    and lower(btrim(email)) = lower(btrim(coalesce(auth.jwt() ->> 'email', '')))
                  )
                )
            order by (auth_user_id = auth.uid()) desc nulls last
            limit 1;
        $$;

        revoke all on function public.current_user_role() from public;
        grant execute on function public.current_user_role() to authenticated;

        create or replace function public.current_user_profile_name()
        returns text
        language sql
        stable
        security definer
        set search_path = public
        as $$
            select name
            from public.user_profiles
            where is_active
              and registration_status = 'approved'
              and (
                auth_user_id = auth.uid()
                or (
                  auth_user_id is null
                  and lower(btrim(email)) = lower(btrim(coalesce(auth.jwt() ->> 'email', '')))
                )
              )
            order by (auth_user_id = auth.uid()) desc nulls last
            limit 1;
        $$;
        revoke all on function public.current_user_profile_name() from public, anon;
        grant execute on function public.current_user_profile_name() to authenticated;

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
        drop policy if exists "No client access to account security settings" on public.account_security_settings;
        create policy "No client access to account security settings" on public.account_security_settings
            for all to anon, authenticated using (false) with check (false);
        drop policy if exists "Admins can read account audit log" on public.account_audit_log;
        create policy "Admins can read account audit log" on public.account_audit_log
            for select to authenticated using (public.current_user_role() = 'Admin');

        create policy "Authenticated users can read reports" on public.reports
            for select to authenticated
            using (
                public.current_user_role() in ('Admin', 'Assistant', 'Personnel')
                or lower(reporter) = lower(public.current_user_profile_name())
            );

        create policy "Users can create own reports" on public.reports
            for insert to authenticated
            with check (
                public.current_user_role() in ('Admin', 'Assistant', 'Employee', 'Student', 'Personnel')
                and lower(reporter) = lower(public.current_user_profile_name())
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
                  where lower(assigned.name) = lower(public.current_user_profile_name())
                )
            )
            with check (
                public.current_user_role() = 'Personnel'
                and exists (
                  select 1 from jsonb_array_elements_text(assigned_personnel) as assigned(name)
                  where lower(assigned.name) = lower(public.current_user_profile_name())
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
                                        where lower(assigned.name) = lower(public.current_user_profile_name())
                                    )
                                )
                or lower(requester) = lower(public.current_user_profile_name())
            );

        create policy "Users can create own requests" on public.requests
            for insert to authenticated
            with check (
                public.current_user_role() in ('Admin', 'Employee')
                and lower(requester) = lower(public.current_user_profile_name())
            );

        create policy "Users can submit feedback on own requests" on public.requests
            for update to authenticated
            using (
                public.current_user_role() = 'Employee'
                and status = 'action-taken'
                and lower(requester) = lower(public.current_user_profile_name())
            )
            with check (
                public.current_user_role() = 'Employee'
                and status = 'action-taken'
                and lower(requester) = lower(public.current_user_profile_name())
            );

        create policy "Personnel can update assigned requests" on public.requests
            for update to authenticated
            using (
                public.current_user_role() = 'Personnel'
                and exists (
                    select 1 from jsonb_array_elements_text(assigned_personnel) as assigned(name)
                    where lower(assigned.name) = lower(public.current_user_profile_name())
                )
            )
            with check (
                public.current_user_role() = 'Personnel'
                and exists (
                    select 1 from jsonb_array_elements_text(assigned_personnel) as assigned(name)
                    where lower(assigned.name) = lower(public.current_user_profile_name())
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
                -- report content and reporter identity remain immutable.
                if not exists (
                    select 1 from jsonb_array_elements_text(old.assigned_personnel) as assigned(name)
                    where lower(assigned.name) = lower(public.current_user_profile_name())
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
                    where lower(assigned.name) = lower(public.current_user_profile_name())
                  )
                  or new.assigned_to is distinct from old.assigned_to
                  or new.assigned_personnel is distinct from old.assigned_personnel
                  or (new.technician_state = 'completed' and old.technician_state <> 'started')
                        or to_jsonb(new) - array['technician_state', 'assignment_note', 'completion_photo']
                            <> to_jsonb(old) - array['technician_state', 'assignment_note', 'completion_photo'] then
                    raise exception 'Personnel may update only the state of requests assigned to them';
                end if;
            elsif public.current_user_role() is distinct from 'Admin' then
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
            using (
              auth_user_id = auth.uid()
              or (auth_user_id is null and lower(btrim(email)) = lower(btrim(coalesce(auth.jwt() ->> 'email', ''))))
            );

        -- A user may maintain only their contact details.  The trigger below
        -- prevents privilege fields from being changed even if a client submits
        -- a broader update payload.
        create policy "Users can update own profile" on public.user_profiles
            for update to authenticated
            using (
              auth_user_id = auth.uid()
              or (auth_user_id is null and lower(btrim(email)) = lower(btrim(coalesce(auth.jwt() ->> 'email', ''))))
            )
            with check (
              auth_user_id = auth.uid()
              or (auth_user_id is null and lower(btrim(email)) = lower(btrim(coalesce(auth.jwt() ->> 'email', ''))))
            );

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
        declare
          bootstrap_call boolean := coalesce(current_setting('unifix.first_admin_bootstrap', true) = 'on', false)
          and not exists (
            select 1 from public.user_profiles
            where role = 'Admin' and is_active
          );
          email_sync_call boolean;
        begin
          email_sync_call :=
          coalesce(current_setting('unifix.auth_email_sync_user_id', true) = new.auth_user_id::text, false)
          and old.auth_user_id is null
          and new.auth_user_id is not null
          and new.id = old.id
          and new.name = old.name
          and new.role = old.role
          and new.department = old.department
          and new.phone = old.phone
          and new.location = old.location
          and new.is_active = old.is_active
          and new.registration_status = old.registration_status
          and new.rejection_reason is not distinct from old.rejection_reason;
          if coalesce(auth.role(), '') <> 'service_role'
          and public.current_user_role() is distinct from 'Admin'
          and not bootstrap_call
          and not email_sync_call then
            if new.id <> old.id
              or new.auth_user_id is distinct from old.auth_user_id
              or (
                new.email is distinct from old.email
                and not (old.auth_user_id = auth.uid() and new.auth_user_id = old.auth_user_id)
              )
              or new.role <> old.role
              or new.department <> old.department
              or new.is_active <> old.is_active
              or new.registration_status <> old.registration_status then
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

        create or replace function public.handle_new_user_registration()
        returns trigger
        language plpgsql
        security definer
        set search_path = public
        as $$
        begin
          if new.email is not null then
            insert into public.user_profiles (
              id, auth_user_id, name, email, role, requested_role, department, phone, location, is_active, registration_status
            ) values (
              new.id::text,
              new.id,
              left(coalesce(nullif(btrim(new.raw_user_meta_data ->> 'name'), ''), 'New User'), 120),
              lower(btrim(new.email)),
              'Employee',
              case
                when new.raw_user_meta_data ->> 'requested_role' in ('Employee', 'Assistant', 'Personnel')
                  then new.raw_user_meta_data ->> 'requested_role'
                else 'Employee'
              end,
              left(coalesce(nullif(btrim(new.raw_user_meta_data ->> 'department'), ''), ''), 160),
              left(coalesce(nullif(btrim(new.raw_user_meta_data ->> 'phone'), ''), ''), 40),
              left(coalesce(nullif(btrim(new.raw_user_meta_data ->> 'location'), ''), 'Main Campus'), 160),
              false,
              'pending'
            )
            on conflict (email) do update
              set auth_user_id = excluded.auth_user_id,
                  role = 'Employee',
                  requested_role = excluded.requested_role,
                  is_active = false,
                  registration_status = 'pending',
                  updated_at = now()
              where public.user_profiles.auth_user_id is null
                 or public.user_profiles.auth_user_id = excluded.auth_user_id;
          end if;
          return new;
        end;
        $$;

        create or replace function public.is_university_email_allowed(p_email text)
        returns boolean
        language sql
        stable
        security definer
        set search_path = public
        as $$
          select exists (
            select 1
            from public.account_security_settings settings
            cross join lateral unnest(settings.allowed_email_domains) allowed(domain)
            where settings.singleton
              and lower(btrim(coalesce(p_email, ''))) ~ '^[^[:space:]@]+@[^[:space:]@]+$'
              and lower(split_part(btrim(p_email), '@', 2)) = lower(btrim(allowed.domain))
          );
        $$;
        revoke all on function public.is_university_email_allowed(text) from public, anon, authenticated;

        create or replace function public.enforce_university_email_domain()
        returns trigger
        language plpgsql
        security definer
        set search_path = public
        as $$
        begin
          if new.email is not null and not public.is_university_email_allowed(new.email) then
            raise exception 'Registration is only available to approved university email domains.';
          end if;
          return new;
        end;
        $$;
        revoke all on function public.enforce_university_email_domain() from public, anon, authenticated;
        drop trigger if exists enforce_university_email_domain on auth.users;
        create trigger enforce_university_email_domain
          before insert or update of email on auth.users
          for each row execute function public.enforce_university_email_domain();

        revoke all on function public.handle_new_user_registration() from public, anon, authenticated;
        drop trigger if exists on_auth_user_registered on auth.users;
        create trigger on_auth_user_registered
          after insert on auth.users
          for each row execute function public.handle_new_user_registration();

        create or replace function public.sync_user_profile_email_from_auth()
        returns trigger
        language plpgsql
        security definer
        set search_path = public
        as $$
        begin
          if new.email is distinct from old.email then
            perform set_config('unifix.auth_email_sync_user_id', new.id::text, true);
            update public.user_profiles
            set email = lower(btrim(new.email)),
                auth_user_id = new.id
            where auth_user_id = new.id
               or (auth_user_id is null and lower(btrim(email)) = lower(btrim(old.email)));
            perform set_config('unifix.auth_email_sync_user_id', 'off', true);
          end if;
          return new;
        end;
        $$;
        revoke all on function public.sync_user_profile_email_from_auth() from public, anon, authenticated;
        drop trigger if exists sync_user_profile_email_from_auth on auth.users;
        create trigger sync_user_profile_email_from_auth
          after update of email on auth.users
          for each row execute function public.sync_user_profile_email_from_auth();

        with candidates as (
          select auth_user.id as auth_id, profile.id as profile_id,
            row_number() over (
              partition by auth_user.id order by profile.created_at nulls last, profile.id
            ) as candidate_rank
          from auth.users auth_user
          join public.user_profiles profile
            on lower(btrim(profile.email)) = lower(btrim(auth_user.email))
          where profile.auth_user_id is null
        )
        update public.user_profiles profile
        set auth_user_id = candidates.auth_id
        from candidates
        where candidates.candidate_rank = 1
          and profile.id = candidates.profile_id
          and not exists (
            select 1 from public.user_profiles linked
            where linked.auth_user_id = candidates.auth_id
          );

        insert into public.user_profiles (
          id, auth_user_id, name, email, role, requested_role, department, phone, location,
          is_active, registration_status
        )
        select
          auth_user.id::text,
          auth_user.id,
          left(coalesce(nullif(btrim(auth_user.raw_user_meta_data ->> 'name'), ''), 'New User'), 120),
          lower(btrim(auth_user.email)),
          'Employee',
          case
            when auth_user.raw_user_meta_data ->> 'requested_role' in ('Employee', 'Assistant', 'Personnel')
              then auth_user.raw_user_meta_data ->> 'requested_role'
            else 'Employee'
          end,
          left(coalesce(nullif(btrim(auth_user.raw_user_meta_data ->> 'department'), ''), ''), 160),
          left(coalesce(nullif(btrim(auth_user.raw_user_meta_data ->> 'phone'), ''), ''), 40),
          left(coalesce(nullif(btrim(auth_user.raw_user_meta_data ->> 'location'), ''), 'Main Campus'), 160),
          false,
          'pending'
        from auth.users auth_user
        where auth_user.email is not null
          and not exists (
            select 1 from public.user_profiles profile
            where profile.auth_user_id = auth_user.id
               or (profile.auth_user_id is null
                   and lower(btrim(profile.email)) = lower(btrim(auth_user.email)))
          )
        on conflict do nothing;

        revoke all on function public.enforce_profile_update_scope() from public;
        grant execute on function public.enforce_profile_update_scope() to authenticated;

-- Phase 1 add-ons for tracking, photos, and feedback.
alter table public.reports
  add column if not exists tracking_code text,
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists reviewed_at timestamptz,
  add column if not exists assigned_at timestamptz,
  add column if not exists in_progress_at timestamptz,
  add column if not exists completed_at timestamptz,
  add column if not exists photo_attachments jsonb not null default '[]'::jsonb;

alter table public.requests
  add column if not exists tracking_code text,
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists reviewed_at timestamptz,
  add column if not exists assigned_at timestamptz,
  add column if not exists in_progress_at timestamptz,
  add column if not exists completed_at timestamptz,
  add column if not exists photo_attachments jsonb not null default '[]'::jsonb;

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
  reviewed_at = case when status not in ('pending', 'urgent') then coalesce(reviewed_at, created_at) else reviewed_at end,
  assigned_at = case when jsonb_array_length(assigned_personnel) > 0 then coalesce(assigned_at, created_at) else assigned_at end,
  in_progress_at = case when technician_state in ('accepted', 'started') or status = 'in-progress' then coalesce(in_progress_at, created_at) else in_progress_at end,
  completed_at = case when technician_state = 'completed' or status in ('resolved', 'action-taken') then coalesce(completed_at, created_at) else completed_at end
where tracking_code is null;
update public.requests set
  tracking_code = null,
  reviewed_at = case when status not in ('submitted', '') then coalesce(reviewed_at, created_at) else reviewed_at end,
  assigned_at = case when jsonb_array_length(assigned_personnel) > 0 then coalesce(assigned_at, created_at) else assigned_at end,
  in_progress_at = case when technician_state in ('accepted', 'started') or status = 'in-progress' then coalesce(in_progress_at, created_at) else in_progress_at end,
  completed_at = case when technician_state = 'completed' or status in ('resolved', 'action-taken') then coalesce(completed_at, created_at) else completed_at end
where tracking_code is null;

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
      where lower(assigned.name) = lower(public.current_user_profile_name())
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
      where lower(assigned.name) = lower(public.current_user_profile_name())
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
          where profile.auth_user_id = auth.uid()
             or (profile.auth_user_id is null and lower(btrim(profile.email)) = lower(btrim(coalesce(auth.jwt() ->> 'email', ''))))
          limit 1
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
-- Phase 2: notifications and verified completion workflow.

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

notify pgrst, 'reload schema';

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
    item_owner_email := coalesce(to_jsonb(new) ->> 'reporter_email', to_jsonb(new) ->> 'requester_email');
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

  item_owner_email := coalesce(to_jsonb(new) ->> 'reporter_email', to_jsonb(new) ->> 'requester_email');
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
    close_status := 'closed';
  else
    close_status := 'closed';
  end if;
  owner_email := coalesce(to_jsonb(new) ->> 'reporter_email', to_jsonb(new) ->> 'requester_email');
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
        where profile.auth_user_id = auth.uid()
           or (profile.auth_user_id is null and lower(btrim(profile.email)) = lower(btrim(coalesce(auth.jwt() ->> 'email', ''))))
        limit 1
      ))
    ) or new.assigned_to is distinct from old.assigned_to
      or new.assigned_personnel is distinct from old.assigned_personnel
      or new.rework_count is distinct from old.rework_count
      or coalesce(to_jsonb(new) ->> 'reporter_email', to_jsonb(new) ->> 'requester_email')
        is distinct from coalesce(to_jsonb(old) ->> 'reporter_email', to_jsonb(old) ->> 'requester_email') then
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
      id, title, description, category, location, risk, status,
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
      'low', 'pending',
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
    select r.id, r.category, r.location, r.status,
           r.created_at, r.completed_at, r.rework_count,
           case when jsonb_typeof(r.assigned_personnel) = 'array' then r.assigned_personnel else '[]'::jsonb end as assigned_personnel
      from public.reports r
    union all
    select q.id, q.category, q.department, q.status,
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

-- Phase 4: anonymized evaluation storage and least-privilege report reads.
create or replace function public.validate_work_item_input()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  content_changed boolean;
begin
  if tg_table_name = 'reports' then
    if tg_op = 'INSERT' then
      content_changed := true;
    else
      content_changed := new.description is distinct from old.description;
    end if;
    if char_length(btrim(coalesce(new.title, ''))) not between 1 and 160
      or char_length(coalesce(new.description, '')) > 4000
      or (content_changed
        and char_length(btrim(coalesce(new.description, ''))) not between 1 and 4000)
      or char_length(btrim(coalesce(new.category, ''))) not between 1 and 80
      or char_length(btrim(coalesce(new.location, ''))) not between 1 and 300
      or char_length(btrim(coalesce(new.reporter, ''))) not between 1 and 120
      or (new.reporter_email is not null and (
        char_length(new.reporter_email) > 254
        or new.reporter_email !~* '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
      )) then
      raise exception 'The report contains invalid or oversized fields';
    end if;
  else
    if tg_op = 'INSERT' then
      content_changed := true;
    else
      content_changed := new.details is distinct from old.details;
    end if;
    if char_length(btrim(coalesce(new.title, ''))) not between 1 and 160
      or char_length(btrim(coalesce(new.category, ''))) not between 1 and 80
      or char_length(btrim(coalesce(new.department, ''))) not between 1 and 300
      or char_length(coalesce(new.details, '')) > 4000
      or (content_changed
        and char_length(btrim(coalesce(new.details, ''))) not between 1 and 4000)
      or char_length(btrim(coalesce(new.requester, ''))) not between 1 and 120
      or (new.requester_email is not null and (
        char_length(new.requester_email) > 254
        or new.requester_email !~* '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
      )) then
      raise exception 'The request contains invalid or oversized fields';
    end if;
  end if;

  if jsonb_typeof(coalesce(new.photo_attachments, '[]'::jsonb)) <> 'array'
    or jsonb_array_length(coalesce(new.photo_attachments, '[]'::jsonb)) > 3 then
    raise exception 'Attach no more than three valid photos';
  end if;
  return new;
end;
$$;

drop trigger if exists validate_report_input on public.reports;
create trigger validate_report_input
  before insert or update on public.reports
  for each row execute function public.validate_work_item_input();
drop trigger if exists validate_request_input on public.requests;
create trigger validate_request_input
  before insert or update on public.requests
  for each row execute function public.validate_work_item_input();
revoke all on function public.validate_work_item_input() from public, anon, authenticated;

drop policy if exists "Users can create own reports" on public.reports;
create policy "Users can create own reports" on public.reports
  for insert to authenticated
  with check (
    public.current_user_role() in ('Admin', 'Assistant', 'Employee', 'Student', 'Personnel')
    and lower(reporter) = lower((
      select name from public.user_profiles
      where auth_user_id = auth.uid()
         or (auth_user_id is null and lower(btrim(email)) = lower(btrim(coalesce(auth.jwt() ->> 'email', ''))))
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
      where auth_user_id = auth.uid()
         or (auth_user_id is null and lower(btrim(email)) = lower(btrim(coalesce(auth.jwt() ->> 'email', ''))))
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

drop policy if exists "Staff can read report photos" on storage.objects;
create policy "Staff can read report photos" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'report-photos'
    and (
      public.current_user_role() in ('Admin', 'Assistant')
      or (
        public.current_user_role() = 'Personnel'
        and (
          exists (
            select 1
            from public.reports report
            cross join lateral jsonb_array_elements_text(
              case when jsonb_typeof(report.assigned_personnel) = 'array'
                then report.assigned_personnel else '[]'::jsonb end
            ) assigned(personnel_name)
            where report.id = case
              when (storage.foldername(name))[2] = 'reports' then replace((storage.foldername(name))[3], '%23', '#')
              when (storage.foldername(name))[1] = 'public'
                and (storage.foldername(name))[2] = 'reports' then replace((storage.foldername(name))[3], '%23', '#')
              else null
            end
            and lower(assigned.personnel_name) = lower((
              select profile.name from public.user_profiles profile
              where profile.auth_user_id = auth.uid()
                 or (profile.auth_user_id is null and lower(btrim(profile.email)) = lower(btrim(coalesce(auth.jwt() ->> 'email', ''))))
              limit 1
            ))
          )
          or exists (
            select 1
            from public.requests request
            cross join lateral jsonb_array_elements_text(
              case when jsonb_typeof(request.assigned_personnel) = 'array'
                then request.assigned_personnel else '[]'::jsonb end
            ) assigned(personnel_name)
            where request.id = case
              when (storage.foldername(name))[2] = 'requests' then replace((storage.foldername(name))[3], '%23', '#')
              when (storage.foldername(name))[1] = 'public'
                and (storage.foldername(name))[2] = 'requests' then replace((storage.foldername(name))[3], '%23', '#')
              else null
            end
            and lower(assigned.personnel_name) = lower((
              select profile.name from public.user_profiles profile
              where profile.auth_user_id = auth.uid()
                 or (profile.auth_user_id is null and lower(btrim(profile.email)) = lower(btrim(coalesce(auth.jwt() ->> 'email', ''))))
              limit 1
            ))
          )
        )
      )
    )
  );

create or replace function public.evaluation_answers_are_valid(
  p_sus_answers smallint[],
  p_iso_answers jsonb
)
returns boolean
language sql
immutable
set search_path = pg_catalog
as $$
  select
    coalesce(array_ndims(p_sus_answers) = 1 and array_length(p_sus_answers, 1) = 10, false)
    and not exists (
      select 1 from unnest(coalesce(p_sus_answers, array[]::smallint[])) answer
      where answer not between 1 and 5
    )
    and jsonb_typeof(p_iso_answers) = 'object'
    and (select count(*) = 8 from jsonb_object_keys(p_iso_answers))
    and (select count(*) = 8 from jsonb_each_text(p_iso_answers) answer
         where answer.key in (
           'functionalSuitability', 'performanceEfficiency', 'compatibility', 'usability',
           'reliability', 'security', 'maintainability', 'portability'
         ) and answer.value ~ '^[1-5]$');
$$;

create table if not exists public.evaluation_responses (
  id uuid primary key default gen_random_uuid(),
  submission_key uuid not null unique,
  respondent_role text not null
    check (respondent_role in ('Public', 'Employee', 'Assistant', 'Personnel', 'Admin', 'Student')),
  sus_answers smallint[] not null,
  iso_answers jsonb not null,
  created_at timestamptz not null default now(),
  constraint evaluation_responses_answers_valid
    check (public.evaluation_answers_are_valid(sus_answers, iso_answers))
);

alter table public.evaluation_responses enable row level security;
revoke all on public.evaluation_responses from public, anon, authenticated;
grant insert on public.evaluation_responses to service_role;
revoke all on function public.evaluation_answers_are_valid(smallint[], jsonb) from public, anon, authenticated;
grant execute on function public.evaluation_answers_are_valid(smallint[], jsonb) to service_role;
drop policy if exists "Anonymous callers cannot access raw evaluation responses" on public.evaluation_responses;
create policy "Anonymous callers cannot access raw evaluation responses" on public.evaluation_responses
  for all to anon using (false) with check (false);
drop policy if exists "Admins cannot access raw evaluation responses" on public.evaluation_responses;
create policy "Admins cannot access raw evaluation responses" on public.evaluation_responses
  for all to authenticated using (public.current_user_role() = 'Admin' and false) with check (false);
drop policy if exists "Assistants cannot access raw evaluation responses" on public.evaluation_responses;
create policy "Assistants cannot access raw evaluation responses" on public.evaluation_responses
  for all to authenticated using (public.current_user_role() = 'Assistant' and false) with check (false);
drop policy if exists "Employees cannot access raw evaluation responses" on public.evaluation_responses;
create policy "Employees cannot access raw evaluation responses" on public.evaluation_responses
  for all to authenticated using (public.current_user_role() = 'Employee' and false) with check (false);
drop policy if exists "Personnel cannot access raw evaluation responses" on public.evaluation_responses;
create policy "Personnel cannot access raw evaluation responses" on public.evaluation_responses
  for all to authenticated using (public.current_user_role() = 'Personnel' and false) with check (false);
drop policy if exists "Students cannot access raw evaluation responses" on public.evaluation_responses;
create policy "Students cannot access raw evaluation responses" on public.evaluation_responses
  for all to authenticated using (public.current_user_role() = 'Student' and false) with check (false);

create or replace function public.get_evaluation_summary()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  result jsonb;
begin
  if coalesce(public.current_user_role(), '') <> 'Admin' then
    raise exception 'Only administrators may view evaluation results';
  end if;

  with sus_scores as (
    select response.id,
      sum(case when answer.ordinality % 2 = 1
        then answer.value::integer - 1
        else 5 - answer.value::integer end) * 2.5 as score
    from public.evaluation_responses response
    cross join lateral unnest(response.sus_answers) with ordinality answer(value, ordinality)
    group by response.id
  )
  select jsonb_build_object(
    'responseCount', (select count(*) from public.evaluation_responses),
    'susAverage', (select round(avg(score)::numeric, 2) from sus_scores),
    'isoMeans', coalesce((
      select jsonb_object_agg(characteristic, mean_score)
      from (
        select characteristic, round(avg((response.iso_answers ->> characteristic)::numeric), 2) as mean_score
        from public.evaluation_responses response
        cross join lateral unnest(array[
          'functionalSuitability', 'performanceEfficiency', 'compatibility', 'usability',
          'reliability', 'security', 'maintainability', 'portability'
        ]) characteristic
        group by characteristic
      ) means
    ), '{}'::jsonb),
    'respondentsByRole', coalesce((
      select jsonb_object_agg(respondent_role, role_count)
      from (
        select respondent_role, count(*) as role_count
        from public.evaluation_responses
        group by respondent_role
      ) roles
    ), '{}'::jsonb)
  ) into result;

  return result;
end;
$$;

revoke all on function public.get_evaluation_summary() from public, anon;
grant execute on function public.get_evaluation_summary() to authenticated;

drop policy if exists "Authenticated users can read reports" on public.reports;
create policy "Authenticated users can read reports" on public.reports
  for select to authenticated
  using (
    public.current_user_role() in ('Admin', 'Assistant')
    or (
      public.current_user_role() = 'Personnel'
      and exists (
        select 1
        from jsonb_array_elements_text(
          case when jsonb_typeof(assigned_personnel) = 'array'
            then assigned_personnel else '[]'::jsonb end
        ) as assigned(name)
        where lower(assigned.name) = lower((
          select name from public.user_profiles
          where auth_user_id = auth.uid()
             or (auth_user_id is null and lower(btrim(email)) = lower(btrim(coalesce(auth.jwt() ->> 'email', ''))))
          limit 1
        ))
      )
    )
    or lower(reporter) = lower((
      select name from public.user_profiles
      where auth_user_id = auth.uid()
         or (auth_user_id is null and lower(btrim(email)) = lower(btrim(coalesce(auth.jwt() ->> 'email', ''))))
      limit 1
    ))
  );

-- Keep fresh installs aligned with 202610050005_qa_authorization_workflow.sql.
-- Tighten role-scoped reads and work-item state transitions found during QA.

create or replace function public.is_current_assigned_personnel(p_name text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_user_role() = 'Personnel', false)
    and (
      select count(*) = 1
      from public.user_profiles profile
      where profile.is_active
        and profile.registration_status = 'approved'
        and profile.role = 'Personnel'
        and lower(btrim(profile.name)) = lower(btrim(coalesce(p_name, '')))
    )
    and exists (
      select 1
      from public.user_profiles profile
      where profile.is_active
        and profile.registration_status = 'approved'
        and profile.role = 'Personnel'
        and (
          profile.auth_user_id = auth.uid()
          or (
            profile.auth_user_id is null
            and lower(btrim(profile.email)) = lower(btrim(coalesce(auth.jwt() ->> 'email', '')))
          )
        )
        and lower(btrim(profile.name)) = lower(btrim(coalesce(p_name, '')))
    );
$$;
revoke all on function public.is_current_assigned_personnel(text) from public, anon;
grant execute on function public.is_current_assigned_personnel(text) to authenticated;

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
  item_updated_at timestamptz;
  event_key text;
begin
  if normalized_email = '' then return; end if;

  if p_entity_type = 'report' then
    select updated_at into item_updated_at from public.reports where id = p_entity_id;
  elsif p_entity_type = 'request' then
    select updated_at into item_updated_at from public.requests where id = p_entity_id;
  end if;
  event_key := md5(concat_ws('|',
    normalized_email, p_event_type, p_entity_type, p_entity_id,
    coalesce(p_tracking_code, ''), coalesce(item_updated_at::text, ''),
    coalesce(p_title, ''), coalesce(p_message, '')
  ));

  select coalesce(preferences.inapp_notifications, true),
    coalesce(preferences.email_notifications, true),
    coalesce(preferences.sms_notifications, false),
    nullif(btrim(profile.phone), '')
  into inapp_enabled, email_enabled, sms_enabled, phone_number
  from public.user_profiles profile
  left join public.user_preferences preferences
    on lower(preferences.user_email) = lower(profile.email)
  where lower(profile.email) = normalized_email
    and profile.is_active
  limit 1;

  if inapp_enabled then
    insert into public.notifications (
      user_email, event_type, title, message, entity_type, entity_id, tracking_code, dedupe_key
    )
    values (
      normalized_email, p_event_type, p_title, p_message, p_entity_type, p_entity_id,
      p_tracking_code, event_key || ':inapp'
    )
    on conflict (dedupe_key) do nothing;
  end if;

  if coalesce(email_enabled, true) then
    insert into public.notification_deliveries (
      channel, recipient, subject, body, event_type, entity_type, entity_id, tracking_code, dedupe_key
    )
    values (
      'email', normalized_email, p_title,
      p_message || case when p_tracking_code is null then '' else E'\n\nTracking code: ' || p_tracking_code end,
      p_event_type, p_entity_type, p_entity_id, p_tracking_code, event_key || ':email'
    )
    on conflict (dedupe_key) do nothing;
  end if;

  if sms_enabled and phone_number is not null and p_sms_message is not null then
    insert into public.notification_deliveries (
      channel, recipient, body, event_type, entity_type, entity_id, tracking_code, dedupe_key
    )
    values (
      'sms', phone_number, p_sms_message, p_event_type, p_entity_type, p_entity_id,
      p_tracking_code, event_key || ':sms'
    )
    on conflict (dedupe_key) do nothing;
  end if;
end;
$$;
revoke all on function public.create_work_item_notification(text, text, text, text, text, text, text, text)
  from public, anon, authenticated;

drop policy if exists "Authenticated users can read reports" on public.reports;
create policy "Authenticated users can read reports" on public.reports
  for select to authenticated
  using (
    public.current_user_role() in ('Admin', 'Assistant')
    or (
      public.current_user_role() in ('Employee', 'Student')
      and lower(reporter_email) = lower(auth.jwt() ->> 'email')
    )
    or (
      public.current_user_role() = 'Personnel'
      and exists (
        select 1
        from jsonb_array_elements_text(
          case when jsonb_typeof(assigned_personnel) = 'array'
            then assigned_personnel else '[]'::jsonb end
        ) assigned(name)
        where public.is_current_assigned_personnel(assigned.name)
      )
    )
  );

drop policy if exists "Authenticated users can read requests" on public.requests;
create policy "Authenticated users can read requests" on public.requests
  for select to authenticated
  using (
    public.current_user_role() in ('Admin', 'Assistant')
    or (
      public.current_user_role() = 'Employee'
      and lower(requester_email) = lower(auth.jwt() ->> 'email')
    )
    or (
      public.current_user_role() = 'Personnel'
      and exists (
        select 1
        from jsonb_array_elements_text(
          case when jsonb_typeof(assigned_personnel) = 'array'
            then assigned_personnel else '[]'::jsonb end
        ) assigned(name)
        where public.is_current_assigned_personnel(assigned.name)
      )
    )
  );

drop policy if exists "Staff can read report photos" on storage.objects;
create policy "Staff can read report photos" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'report-photos'
    and (
      public.current_user_role() in ('Admin', 'Assistant')
      or (
        public.current_user_role() = 'Personnel'
        and (
          exists (
            select 1
            from public.reports report
            cross join lateral jsonb_array_elements_text(
              case when jsonb_typeof(report.assigned_personnel) = 'array'
                then report.assigned_personnel else '[]'::jsonb end
            ) assigned(personnel_name)
            where report.id = case
              when (storage.foldername(name))[2] = 'reports' then replace((storage.foldername(name))[3], '%23', '#')
              when (storage.foldername(name))[1] = 'public'
                and (storage.foldername(name))[2] = 'reports' then replace((storage.foldername(name))[3], '%23', '#')
              else null
            end
            and public.is_current_assigned_personnel(assigned.personnel_name)
          )
          or exists (
            select 1
            from public.requests request
            cross join lateral jsonb_array_elements_text(
              case when jsonb_typeof(request.assigned_personnel) = 'array'
                then request.assigned_personnel else '[]'::jsonb end
            ) assigned(personnel_name)
            where request.id = case
              when (storage.foldername(name))[2] = 'requests' then replace((storage.foldername(name))[3], '%23', '#')
              when (storage.foldername(name))[1] = 'public'
                and (storage.foldername(name))[2] = 'requests' then replace((storage.foldername(name))[3], '%23', '#')
              else null
            end
            and public.is_current_assigned_personnel(assigned.personnel_name)
          )
        )
      )
    )
  );

do $$
declare
  function_definition text;
  revised_definition text;
  old_text text;
  new_text text;
begin
  function_definition := pg_get_functiondef('public.enforce_role_update_scope()'::regprocedure);
  revised_definition := function_definition;

  old_text := $old$  close_status text;$old$;
  new_text := $new$  close_status text;
  allow_duplicate_status boolean := false;$new$;
  if length(revised_definition) - length(replace(revised_definition, old_text, '')) <> length(old_text) then
    raise exception 'QA workflow trigger did not contain exactly one duplicate-status variable target';
  end if;
  revised_definition := replace(revised_definition, old_text, new_text);
  if position(new_text in revised_definition) = 0 then
    raise exception 'QA workflow trigger duplicate-status variable was not added';
  end if;

  old_text := $old$  start_status := old.status;$old$;
  new_text := $new$  start_status := old.status;
  if tg_table_name = 'reports'
    and user_role = 'Admin'
    and new.status = 'resolved'
      and (to_jsonb(new) ->> 'duplicate_of') is distinct from (to_jsonb(old) ->> 'duplicate_of')
      and old.status not in ('closed', 'resolved', 'action-taken')
      and exists (
        select 1 from public.reports parent
        where parent.id = (to_jsonb(new) ->> 'duplicate_of')
          and parent.status not in ('closed', 'resolved', 'action-taken')
      ) then
    allow_duplicate_status := true;
  end if;$new$;
  if length(revised_definition) - length(replace(revised_definition, old_text, '')) <> length(old_text) then
    raise exception 'QA workflow trigger did not contain exactly one duplicate-status calculation target';
  end if;
  revised_definition := replace(revised_definition, old_text, new_text);
  if position(new_text in revised_definition) = 0 then
    raise exception 'QA workflow trigger duplicate-status calculation was not applied';
  end if;

  old_text := $old$  if auth.role() = 'service_role' then
    return new;
  end if;$old$;
  new_text := $new$  if auth.role() = 'service_role' then
    return new;
  end if;

  if tg_table_name = 'reports'
    and pg_trigger_depth() > 1
    and (to_jsonb(new) ->> 'duplicate_of') is not null
    and exists (
      select 1 from public.reports parent
      where parent.id = (to_jsonb(new) ->> 'duplicate_of') and parent.status = new.status
    ) then
    return new;
  end if;$new$;
  if length(revised_definition) - length(replace(revised_definition, old_text, '')) <> length(old_text) then
    raise exception 'QA workflow trigger did not contain exactly one duplicate propagation target';
  end if;
  revised_definition := replace(revised_definition, old_text, new_text);
  if position(new_text in revised_definition) = 0 then
    raise exception 'QA workflow trigger duplicate propagation guard was not applied';
  end if;

  old_text := $old$  if tg_table_name = 'reports' and new.status = 'resolved' and new.technician_state <> 'completed' then
    raise exception 'Reports can be completed only after personnel submits work for verification';
  elsif tg_table_name = 'requests' and new.status = 'action-taken' and new.technician_state <> 'completed' then
    raise exception 'Requests can be completed only after personnel submits work for verification';
  end if;$old$;
  new_text := $new$  if tg_table_name = 'reports' and new.status = 'resolved'
    and new.technician_state <> 'completed' and not allow_duplicate_status then
      raise exception 'Reports can be completed only after personnel submits work for verification';
  elsif tg_table_name = 'requests' and new.status = 'action-taken' and new.technician_state <> 'completed' then
    raise exception 'Requests can be completed only after personnel submits work for verification';
  end if;$new$;
  if length(revised_definition) - length(replace(revised_definition, old_text, '')) <> length(old_text) then
    raise exception 'QA workflow trigger did not contain exactly one duplicate-resolution guard target';
  end if;
  revised_definition := replace(revised_definition, old_text, new_text);
  if position(new_text in revised_definition) = 0 then
    raise exception 'QA workflow trigger duplicate-resolution guard was not applied';
  end if;

  old_text := $old$  if user_role in ('Admin', 'Assistant') then$old$;
  new_text := $new$  if user_role in ('Admin', 'Assistant') then
    if old.status in ('closed', 'resolved', 'action-taken')
      and (new.assigned_personnel is distinct from old.assigned_personnel
        or new.assigned_to is distinct from old.assigned_to
        or new.technician_state is distinct from old.technician_state) then
      raise exception 'Completed work cannot be assigned; use the requester reopen workflow';
    end if;$new$;
  if length(revised_definition) - length(replace(revised_definition, old_text, '')) <> length(old_text) then
    raise exception 'QA workflow trigger did not contain exactly one admin assignment guard target';
  end if;
  revised_definition := replace(revised_definition, old_text, new_text);
  if position(new_text in revised_definition) = 0 then
    raise exception 'QA workflow trigger admin assignment guard was not applied';
  end if;

  old_text := $old$where lower(assigned.name) = lower(($old$;
  new_text := $new$where public.is_current_assigned_personnel(assigned.name)
      and lower(assigned.name) = lower(($new$;
  if length(revised_definition) - length(replace(revised_definition, old_text, '')) <> length(old_text) then
    raise exception 'QA workflow trigger did not contain exactly one personnel identity guard target';
  end if;
  revised_definition := replace(revised_definition, old_text, new_text);
  if position(new_text in revised_definition) = 0 then
    raise exception 'QA workflow trigger personnel identity guard was not applied';
  end if;

  old_text := $old$    if new.status is distinct from old.status and new.status not in ('in-progress', 'for-verification') then
      raise exception 'Personnel cannot verify or close work';
    end if;
    return new;$old$;
  new_text := $new$    if old.status in ('closed', 'resolved', 'action-taken') then
      raise exception 'Closed work cannot be restarted by maintenance personnel';
    end if;
    if new.status is distinct from old.status or new.technician_state is distinct from old.technician_state then
      if not (
        (old.technician_state = 'assigned'
          and new.technician_state = 'accepted'
          and new.status = 'in-progress')
        or (old.technician_state = 'accepted'
          and new.technician_state = 'started'
          and old.status = 'in-progress'
          and new.status = 'in-progress')
        or (old.technician_state = 'started'
          and new.technician_state = 'completed'
          and old.status = 'in-progress'
          and new.status = 'for-verification')
      ) then
        raise exception 'Personnel work must follow assignment, acceptance, start, and verification in order';
      end if;
    end if;
    return new;$new$;
  if length(revised_definition) - length(replace(revised_definition, old_text, '')) <> length(old_text) then
    raise exception 'QA workflow trigger did not contain exactly one personnel transition target';
  end if;
  revised_definition := replace(revised_definition, old_text, new_text);
  if position(new_text in revised_definition) = 0 then
    raise exception 'QA workflow trigger personnel transition guard was not applied';
  end if;

  execute revised_definition;
end;
$$;

create index if not exists reports_created_at_idx on public.reports (created_at desc);
create index if not exists reports_status_created_at_idx on public.reports (status, created_at desc);
create index if not exists reports_assigned_to_idx on public.reports (assigned_to)
  where assigned_to is not null;
create index if not exists requests_created_at_idx on public.requests (created_at desc);
create index if not exists requests_status_created_at_idx on public.requests (status, created_at desc);
create index if not exists requests_assigned_to_idx on public.requests (assigned_to)
  where assigned_to is not null;
create index if not exists maintenance_schedules_active_due_idx
  on public.maintenance_schedules (next_due) where is_active;
create index if not exists user_profiles_active_role_idx
  on public.user_profiles (role) where is_active;
create index if not exists user_profiles_email_lower_idx
  on public.user_profiles (lower(email));

create table if not exists public.account_reapplication_requests (
  auth_user_id uuid primary key references auth.users(id) on delete cascade,
  profile_id text references public.user_profiles(id) on delete cascade,
  requested_at timestamptz not null default now(),
  reviewed_at timestamptz
);
alter table public.account_reapplication_requests
  add column if not exists profile_id text;
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.account_reapplication_requests'::regclass
      and conname = 'account_reapplication_requests_profile_id_fkey'
  ) then
    alter table public.account_reapplication_requests
      add constraint account_reapplication_requests_profile_id_fkey
      foreign key (profile_id) references public.user_profiles(id) on delete cascade;
  end if;
end;
$$;
create index if not exists account_reapplication_requests_profile_id_idx
  on public.account_reapplication_requests (profile_id);
update public.account_reapplication_requests request
set profile_id = profile.id
from public.user_profiles profile
where request.profile_id is null
  and request.auth_user_id = profile.auth_user_id;
alter table public.account_reapplication_requests enable row level security;
revoke all on public.account_reapplication_requests from public, anon, authenticated;
grant select on public.account_reapplication_requests to authenticated;
drop policy if exists "Admins can read reapplication requests" on public.account_reapplication_requests;
create policy "Admins can read reapplication requests" on public.account_reapplication_requests
  for select to authenticated
  using (public.current_user_role() = 'Admin');

drop policy if exists "Admins can manage profiles" on public.user_profiles;
drop policy if exists "Admins can read all profiles" on public.user_profiles;
create policy "Admins can read all profiles" on public.user_profiles
  for select to authenticated
  using (public.current_user_role() = 'Admin');
drop policy if exists "Admins can update profiles" on public.user_profiles;
create policy "Admins can update profiles" on public.user_profiles
  for update to authenticated
  using (public.current_user_role() = 'Admin')
  with check (public.current_user_role() = 'Admin');
revoke insert, delete on public.user_profiles from public, anon, authenticated;
grant select, update on public.user_profiles to authenticated;

create or replace function public.request_registration_reapplication()
returns timestamptz
language plpgsql
security definer
set search_path = public
as $$
declare
  profile_status text;
  profile_id text;
  request_timestamp timestamptz;
begin
  if auth.uid() is null then raise exception 'Sign in to request a new application review.'; end if;
  select id, registration_status into profile_id, profile_status
  from public.user_profiles
  where auth_user_id = auth.uid()
     or (auth_user_id is null
         and lower(btrim(email)) = lower(btrim(coalesce(auth.jwt() ->> 'email', ''))))
  order by (auth_user_id = auth.uid()) desc nulls last
  limit 1;
  if profile_status is distinct from 'rejected' then
    raise exception 'Only rejected applications may request a new review.';
  end if;
  insert into public.account_reapplication_requests (auth_user_id, profile_id, requested_at, reviewed_at)
  values (auth.uid(), profile_id, now(), null)
  on conflict (auth_user_id) do update
    set profile_id = excluded.profile_id, requested_at = now(), reviewed_at = null
    where public.account_reapplication_requests.requested_at <= now() - interval '30 days'
  returning requested_at into request_timestamp;
  if request_timestamp is null then
    raise exception 'You may request another application review once every 30 days.';
  end if;
  return request_timestamp;
end;
$$;
revoke all on function public.request_registration_reapplication() from public, anon;
grant execute on function public.request_registration_reapplication() to authenticated;

create or replace function public.reopen_rejected_registration(p_profile_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.current_user_role() is distinct from 'Admin' then
    raise exception 'Only an active Admin may reopen an application.';
  end if;
  if not exists (
    select 1 from public.account_reapplication_requests
    where profile_id = p_profile_id and reviewed_at is null
  ) then
    raise exception 'The applicant must request a new review before the application is reopened.';
  end if;
  perform set_config('unifix.admin_reopen', 'on', true);
  update public.user_profiles
  set registration_status = 'pending', is_active = false,
      rejection_reason = null, updated_at = now()
  where id = p_profile_id and registration_status = 'rejected';
  if not found then raise exception 'This application is no longer rejected.'; end if;
  perform set_config('unifix.admin_reopen', 'off', true);
  update public.account_reapplication_requests
  set reviewed_at = now()
  where profile_id = p_profile_id;
end;
$$;
revoke all on function public.reopen_rejected_registration(text) from public, anon;
grant execute on function public.reopen_rejected_registration(text) to authenticated;

create or replace function public.enforce_user_profile_state_transition()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  service_call boolean := coalesce(auth.role(), '') = 'service_role';
  admin_call boolean := public.current_user_role() = 'Admin';
  bootstrap_call boolean := coalesce(current_setting('unifix.first_admin_bootstrap', true) = 'on', false)
    and not exists (
      select 1 from public.user_profiles
      where role = 'Admin' and is_active
    );
  email_sync_call boolean;
  other_active_admins bigint;
begin
  email_sync_call :=
    coalesce(current_setting('unifix.auth_email_sync_user_id', true) = new.auth_user_id::text, false)
    and old.auth_user_id is null
    and new.auth_user_id is not null
    and new.id = old.id
    and new.name = old.name
    and new.role = old.role
    and new.department = old.department
    and new.phone = old.phone
    and new.location = old.location
    and new.is_active = old.is_active
    and new.registration_status = old.registration_status
    and new.rejection_reason is not distinct from old.rejection_reason;
  if not service_call and not admin_call and not bootstrap_call then
    if new.role is distinct from old.role
      or new.is_active is distinct from old.is_active
      or new.registration_status is distinct from old.registration_status
      or new.rejection_reason is distinct from old.rejection_reason then
      raise exception 'Only an active Admin may change account access or registration state.';
    end if;
    return new;
  end if;
  if new.auth_user_id is distinct from old.auth_user_id then
    if not email_sync_call then
      raise exception 'The Auth user link cannot be changed.';
    end if;
  end if;

  if new.registration_status is distinct from old.registration_status then
    if old.registration_status = 'pending' and new.registration_status = 'approved' then
      if not new.is_active or new.role not in ('Admin', 'Assistant', 'Employee', 'Personnel')
        or new.rejection_reason is not null then
        raise exception 'Approved registrations must have an allowed role and active access.';
      end if;
    elsif old.registration_status = 'pending' and new.registration_status = 'rejected' then
      if new.is_active or nullif(btrim(new.rejection_reason), '') is null then
        raise exception 'A rejection reason is required and rejected accounts must remain inactive.';
      end if;
    elsif old.registration_status = 'rejected' and new.registration_status = 'pending' then
      if not admin_call or current_setting('unifix.admin_reopen', true) is distinct from 'on'
        or new.is_active or new.rejection_reason is not null then
        raise exception 'Rejected applications may be reopened only by an Admin action.';
      end if;
    else
      raise exception 'This registration status transition is not allowed.';
    end if;
  elsif new.registration_status = 'pending' then
    if new.role is distinct from old.role or new.is_active or new.rejection_reason is not null then
      raise exception 'Pending accounts must remain inactive and cannot be reassigned before approval.';
    end if;
  elsif new.registration_status = 'rejected' then
    if new.role is distinct from old.role or new.is_active then
      raise exception 'Rejected accounts must remain inactive with their assigned role unchanged.';
    end if;
  elsif new.registration_status = 'approved' then
    if new.rejection_reason is not null then raise exception 'Approved accounts cannot have a rejection reason.'; end if;
    if new.role not in ('Admin', 'Assistant', 'Employee', 'Personnel') then
      raise exception 'Choose a valid university role.';
    end if;
  end if;

  if old.role = 'Admin' and old.is_active
    and (new.role is distinct from 'Admin' or not new.is_active) then
    if old.auth_user_id = auth.uid()
      or (old.auth_user_id is null
          and lower(btrim(old.email)) = lower(btrim(coalesce(auth.jwt() ->> 'email', '')))) then
      raise exception 'You cannot deactivate or demote your own Admin account.';
    end if;
    perform pg_advisory_xact_lock(hashtext('unifix-active-admin-count'));
    select count(*) into other_active_admins
    from public.user_profiles profile
    where profile.role = 'Admin' and profile.is_active and profile.id <> old.id;
    if other_active_admins < 1 then
      raise exception 'The last active Admin account cannot be deactivated or demoted.';
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists enforce_user_profile_state_transition on public.user_profiles;
create trigger enforce_user_profile_state_transition
  before update on public.user_profiles
  for each row execute function public.enforce_user_profile_state_transition();
revoke all on function public.enforce_user_profile_state_transition() from public, anon, authenticated;

create or replace function public.prevent_last_admin_auth_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_profile public.user_profiles%rowtype;
  other_active_admins bigint;
begin
  select * into target_profile
  from public.user_profiles
  where auth_user_id = old.id;
  if found and target_profile.role = 'Admin' and target_profile.is_active then
    perform pg_advisory_xact_lock(hashtext('unifix-active-admin-count'));
    select count(*) into other_active_admins
    from public.user_profiles profile
    where profile.role = 'Admin'
      and profile.is_active
      and profile.auth_user_id is distinct from old.id;
    if other_active_admins < 1 then
      raise exception 'The last active Admin account cannot be deleted.';
    end if;
  end if;
  return old;
end;
$$;
revoke all on function public.prevent_last_admin_auth_delete() from public, anon, authenticated;
drop trigger if exists prevent_last_admin_auth_delete on auth.users;
create trigger prevent_last_admin_auth_delete
  before delete on auth.users
  for each row execute function public.prevent_last_admin_auth_delete();

create or replace function public.bootstrap_first_admin(p_email text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  bootstrap_profile public.user_profiles%rowtype;
begin
  perform pg_advisory_xact_lock(hashtext('unifix-active-admin-count'));
  if exists (
    select 1 from public.user_profiles
    where role = 'Admin' and is_active
  ) then
    raise exception 'An active Admin already exists.';
  end if;

  select profile.* into bootstrap_profile
  from public.user_profiles profile
  join auth.users auth_user on auth_user.id = profile.auth_user_id
  where lower(btrim(profile.email)) = lower(btrim(p_email))
    and profile.registration_status = 'pending'
    and auth_user.email_confirmed_at is not null
    and public.is_university_email_allowed(auth_user.email)
  for update of profile;
  if not found then
    raise exception 'Choose a confirmed university account with a pending profile.';
  end if;

  perform set_config('unifix.first_admin_bootstrap', 'on', true);
  update public.user_profiles
  set role = 'Admin',
      is_active = true,
      registration_status = 'approved',
      rejection_reason = null,
      updated_at = now()
  where id = bootstrap_profile.id;
  perform set_config('unifix.first_admin_bootstrap', 'off', true);
end;
$$;
revoke all on function public.bootstrap_first_admin(text) from public, anon, authenticated, service_role;

create or replace function public.account_user_has_work_history(p_auth_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.user_profiles profile
    where profile.auth_user_id = p_auth_user_id
      and (
        exists (
          select 1 from public.reports report
          where lower(coalesce(report.reporter_email, '')) = lower(profile.email)
             or lower(report.reporter) = lower(profile.name)
             or exists (
               select 1 from jsonb_array_elements_text(
                 case when jsonb_typeof(report.assigned_personnel) = 'array'
                   then report.assigned_personnel else '[]'::jsonb end
               ) assigned(name) where lower(assigned.name) = lower(profile.name)
             )
        )
        or exists (
          select 1 from public.requests request
          where lower(coalesce(request.requester_email, '')) = lower(profile.email)
             or lower(request.requester) = lower(profile.name)
             or exists (
               select 1 from jsonb_array_elements_text(
                 case when jsonb_typeof(request.assigned_personnel) = 'array'
                   then request.assigned_personnel else '[]'::jsonb end
               ) assigned(name) where lower(assigned.name) = lower(profile.name)
             )
        )
      )
  );
$$;
revoke all on function public.account_user_has_work_history(uuid) from public, anon, authenticated;
grant execute on function public.account_user_has_work_history(uuid) to service_role;

create or replace function public.audit_user_profile_state_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare action_name text;
begin
  if coalesce(auth.role(), '') = 'service_role' then return new; end if;
  if old.role is distinct from new.role then action_name := 'user_role_changed';
  elsif old.registration_status is distinct from new.registration_status then
    action_name := 'registration_' || new.registration_status;
  elsif old.is_active is distinct from new.is_active then
    action_name := case when new.is_active then 'user_reactivated' else 'user_deactivated' end;
  else return new;
  end if;
  insert into public.account_audit_log (
    actor_auth_user_id, actor_email, action, target_auth_user_id, target_email, details
  ) values (
    auth.uid(), coalesce(auth.jwt() ->> 'email', 'system'), action_name,
    new.auth_user_id, new.email,
    jsonb_build_object(
      'old_role', old.role, 'new_role', new.role,
      'old_status', old.registration_status, 'new_status', new.registration_status,
      'old_is_active', old.is_active, 'new_is_active', new.is_active,
      'rejection_reason', new.rejection_reason
    )
  );
  return new;
end;
$$;
revoke all on function public.audit_user_profile_state_change() from public, anon, authenticated;
drop trigger if exists audit_user_profile_state_change on public.user_profiles;
create trigger audit_user_profile_state_change
  after update on public.user_profiles
  for each row execute function public.audit_user_profile_state_change();

do $$
begin
  if not exists (
    select 1
    from pg_publication_rel publication_table
    join pg_class relation_row on relation_row.oid = publication_table.prrelid
    join pg_namespace relation_schema on relation_schema.oid = relation_row.relnamespace
    join pg_publication publication_row on publication_row.oid = publication_table.prpubid
    where publication_row.pubname = 'supabase_realtime'
      and relation_schema.nspname = 'public'
      and relation_row.relname = 'user_profiles'
  ) then
    execute 'alter publication supabase_realtime add table public.user_profiles';
  end if;
end;
$$;

create or replace function public.notify_pending_account_registration()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  invited_at_value timestamptz;
  administrator record;
  new_user_id text := coalesce(new.auth_user_id::text, new.id);
begin
  if new.registration_status <> 'pending' or new.is_active then
    return new;
  end if;
  if tg_op = 'UPDATE' and old.registration_status is not distinct from new.registration_status then
    return new;
  end if;
  if tg_op = 'INSERT' then
    select invited_at into invited_at_value
    from auth.users
    where id = new.auth_user_id;
    if invited_at_value is not null then
      return new;
    end if;
  end if;

  for administrator in
    select auth_user_id, email
    from public.user_profiles
    where role = 'Admin' and is_active
  loop
    insert into public.notifications (
      user_email, event_type, title, message, dedupe_key
    ) values (
      administrator.email,
      'account_registration_pending',
      'New account awaiting approval',
      new.name || ' (' || new.email || ') submitted an account registration.',
      'account-registration-pending:' || new_user_id || ':' || coalesce(new.updated_at::text, now()::text)
        || ':' || coalesce(administrator.auth_user_id::text, lower(administrator.email))
    )
    on conflict (dedupe_key) do nothing;
  end loop;
  return new;
end;
$$;
revoke all on function public.notify_pending_account_registration() from public, anon, authenticated;
drop trigger if exists notify_pending_account_registration on public.user_profiles;
create trigger notify_pending_account_registration
  after insert or update of registration_status on public.user_profiles
  for each row execute function public.notify_pending_account_registration();

create or replace function public.notify_account_registration_decision()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  event_key text;
  notification_title text;
  notification_message text;
begin
  if new.registration_status is not distinct from old.registration_status
    or new.registration_status not in ('approved', 'rejected') then
    return new;
  end if;

  notification_title := case
    when new.registration_status = 'approved' then 'UNIFIX account approved'
    else 'UNIFIX registration decision'
  end;
  notification_message := case
    when new.registration_status = 'approved'
      then 'Your UNIFIX account has been approved. You can now sign in.'
    else 'Your UNIFIX registration was not approved.'
      || case when nullif(btrim(new.rejection_reason), '') is null
        then '' else ' Reason: ' || btrim(new.rejection_reason) end
  end;
  event_key := 'account-registration:' || coalesce(new.auth_user_id::text, new.id)
    || ':' || new.registration_status || ':' || coalesce(new.updated_at::text, now()::text);

  insert into public.notifications (
    user_email, event_type, title, message, dedupe_key
  ) values (
    new.email,
    'account_registration_' || new.registration_status,
    notification_title,
    notification_message,
    event_key || ':inapp'
  )
  on conflict (dedupe_key) do nothing;

  insert into public.notification_deliveries (
    channel, recipient, subject, body, event_type, dedupe_key
  ) values (
    'email',
    new.email,
    notification_title,
    notification_message,
    'account_registration_' || new.registration_status,
    event_key || ':email'
  )
  on conflict (dedupe_key) do nothing;
  return new;
end;
$$;
revoke all on function public.notify_account_registration_decision() from public, anon, authenticated;
drop trigger if exists notify_account_registration_decision on public.user_profiles;
create trigger notify_account_registration_decision
  after update of registration_status on public.user_profiles
  for each row execute function public.notify_account_registration_decision();

notify pgrst, 'reload schema';

alter table public.user_preferences
  add column if not exists notification_email text,
  add column if not exists notification_email_verified boolean not null default false;
create extension if not exists pgcrypto with schema extensions;
alter table public.user_preferences
  alter column email_notifications set default false;
update public.user_preferences
set email_notifications = false
where notification_email_verified = false;

create table if not exists public.notification_email_verifications (
  auth_user_id uuid primary key references auth.users(id) on delete cascade,
  login_email text not null,
  notification_email text not null,
  token_hash text not null,
  requested_at timestamptz not null default now(),
  expires_at timestamptz not null,
  attempt_count integer not null default 0
);
alter table public.notification_email_verifications enable row level security;
revoke all on public.notification_email_verifications from public, anon, authenticated;
grant all on public.notification_email_verifications to service_role;

drop function if exists public.begin_notification_email_verification(text);
create or replace function public.begin_notification_email_verification(p_email text, p_auth_user_id uuid)
returns table (token text, notification_email text)
language plpgsql
security definer
set search_path = public
as $$
declare
  current_auth_user_id uuid := p_auth_user_id;
  login_email text;
  normalized_notification_email text := lower(btrim(coalesce(p_email, '')));
  token_value text;
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'Notification email verification must be requested through the verification service.';
  end if;
  select lower(btrim(auth_user.email)) into login_email
  from auth.users auth_user
  where auth_user.id = current_auth_user_id
    and auth_user.email is not null;
  if current_auth_user_id is null or login_email is null or not exists (
    select 1 from public.user_profiles profile
    where profile.auth_user_id = current_auth_user_id
      and profile.is_active
      and profile.registration_status = 'approved'
  ) then
    raise exception 'Sign in with an active, approved account to verify a notification email.';
  end if;
  if length(normalized_notification_email) > 254
    or normalized_notification_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
    raise exception 'Enter a valid notification email address.';
  end if;
  if exists (
    select 1 from public.notification_email_verifications verification
    where verification.auth_user_id = current_auth_user_id
      and verification.requested_at > now() - interval '1 minute'
  ) then
    raise exception 'Please wait one minute before requesting another verification email.';
  end if;

  token_value := replace(gen_random_uuid()::text, '-', '')
    || replace(gen_random_uuid()::text, '-', '')
    || replace(gen_random_uuid()::text, '-', '')
    || replace(gen_random_uuid()::text, '-', '');

  insert into public.notification_email_verifications (
    auth_user_id, login_email, notification_email, token_hash, requested_at, expires_at, attempt_count
  ) values (
    current_auth_user_id,
    login_email,
    normalized_notification_email,
    encode(extensions.digest(convert_to(token_value, 'UTF8'), 'sha256'), 'hex'),
    now(),
    now() + interval '30 minutes',
    0
  )
  on conflict (auth_user_id) do update
  set login_email = excluded.login_email,
      notification_email = excluded.notification_email,
      token_hash = excluded.token_hash,
      requested_at = excluded.requested_at,
      expires_at = excluded.expires_at,
      attempt_count = 0;

  insert into public.user_preferences (
    user_email, notification_email, notification_email_verified, email_notifications
  ) values (
    login_email, normalized_notification_email, false, false
  )
  on conflict (user_email) do update
  set notification_email = excluded.notification_email,
      notification_email_verified = false,
      email_notifications = false,
      updated_at = now();

  return query select token_value, normalized_notification_email;
end;
$$;
revoke all on function public.begin_notification_email_verification(text, uuid) from public, anon, authenticated;
grant execute on function public.begin_notification_email_verification(text, uuid) to service_role;

create or replace function public.complete_notification_email_verification(p_token_hash text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  verification public.notification_email_verifications%rowtype;
begin
  select * into verification
  from public.notification_email_verifications
  where token_hash = p_token_hash
  for update;
  if not found or verification.expires_at <= now() or verification.attempt_count >= 5 then
    raise exception 'This verification link is invalid or expired. Request a new one in Settings.';
  end if;

  update public.user_preferences
  set notification_email_verified = true,
      email_notifications = false,
      updated_at = now()
  where lower(user_email) = verification.login_email
    and lower(notification_email) = verification.notification_email;
  if not found then
    delete from public.notification_email_verifications
    where auth_user_id = verification.auth_user_id;
    raise exception 'The notification email changed. Request a new verification link in Settings.';
  end if;

  delete from public.notification_email_verifications
  where auth_user_id = verification.auth_user_id;
  return verification.notification_email;
end;
$$;
revoke all on function public.complete_notification_email_verification(text) from public, anon, authenticated;
grant execute on function public.complete_notification_email_verification(text) to service_role;

create or replace function public.enforce_notification_email_verification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    if tg_op = 'INSERT' then
      new.notification_email_verified := false;
      if new.notification_email is not null then
        new.email_notifications := false;
      end if;
      return new;
    end if;
    if new.notification_email_verified is distinct from old.notification_email_verified
      and new.notification_email_verified then
      raise exception 'Notification email verification must be completed through the verification link.';
    end if;
    if new.notification_email is distinct from old.notification_email then
      new.notification_email_verified := false;
      new.email_notifications := false;
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.enforce_notification_email_verification() from public, anon, authenticated;
drop trigger if exists enforce_notification_email_verification on public.user_preferences;
create trigger enforce_notification_email_verification
  before insert or update on public.user_preferences
  for each row execute function public.enforce_notification_email_verification();

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
  recipient_email text := normalized_email;
  inapp_enabled boolean;
  email_enabled boolean;
  notification_email_verified boolean;
  sms_enabled boolean;
  phone_number text;
  account_profile_active boolean;
  item_updated_at timestamptz;
  event_key text;
  account_profile_found boolean := false;
begin
  if normalized_email = '' then return; end if;

  if p_entity_type = 'report' then
    select updated_at into item_updated_at from public.reports where id = p_entity_id;
  elsif p_entity_type = 'request' then
    select updated_at into item_updated_at from public.requests where id = p_entity_id;
  end if;
  event_key := md5(concat_ws('|',
    normalized_email, p_event_type, p_entity_type, p_entity_id,
    coalesce(p_tracking_code, ''), coalesce(item_updated_at::text, ''),
    coalesce(p_title, ''), coalesce(p_message, '')
  ));

  select
    coalesce(preferences.inapp_notifications, true),
    coalesce(preferences.email_notifications, false),
    coalesce(preferences.notification_email_verified, false),
    coalesce(preferences.sms_notifications, false),
    nullif(btrim(profile.phone), ''),
    nullif(lower(btrim(preferences.notification_email)), ''),
    profile.is_active and profile.registration_status = 'approved'
  into
    inapp_enabled, email_enabled, notification_email_verified, sms_enabled, phone_number,
    recipient_email, account_profile_active
  from public.user_profiles profile
  left join public.user_preferences preferences
    on lower(preferences.user_email) = lower(profile.email)
  where lower(profile.email) = normalized_email
  limit 1;
  account_profile_found := found;

  if account_profile_found then
    inapp_enabled := coalesce(inapp_enabled, false) and account_profile_active;
    email_enabled := coalesce(email_enabled, false) and notification_email_verified and account_profile_active;
    sms_enabled := coalesce(sms_enabled, false) and account_profile_active;
    if not notification_email_verified or recipient_email is null then
      email_enabled := false;
    end if;
  else
    recipient_email := normalized_email;
    email_enabled := true;
  end if;

  if inapp_enabled then
    insert into public.notifications (
      user_email, event_type, title, message, entity_type, entity_id, tracking_code, dedupe_key
    ) values (
      normalized_email, p_event_type, p_title, p_message, p_entity_type, p_entity_id,
      p_tracking_code, event_key || ':inapp'
    )
    on conflict (dedupe_key) do nothing;
  end if;

  if coalesce(email_enabled, false) then
    insert into public.notification_deliveries (
      channel, recipient, subject, body, event_type, entity_type, entity_id, tracking_code, dedupe_key
    ) values (
      'email', recipient_email, p_title,
      p_message || case when p_tracking_code is null then '' else E'\n\nTracking code: ' || p_tracking_code end,
      p_event_type, p_entity_type, p_entity_id, p_tracking_code, event_key || ':email'
    )
    on conflict (dedupe_key) do nothing;
  end if;

  if sms_enabled and phone_number is not null and p_sms_message is not null then
    insert into public.notification_deliveries (
      channel, recipient, body, event_type, entity_type, entity_id, tracking_code, dedupe_key
    ) values (
      'sms', phone_number, p_sms_message, p_event_type, p_entity_type, p_entity_id,
      p_tracking_code, event_key || ':sms'
    )
    on conflict (dedupe_key) do nothing;
  end if;
end;
$$;
revoke all on function public.create_work_item_notification(text, text, text, text, text, text, text, text)
  from public, anon, authenticated;
