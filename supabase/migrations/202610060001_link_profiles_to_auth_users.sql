alter table public.user_profiles
  add column if not exists auth_user_id uuid;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.user_profiles'::regclass
      and conname = 'user_profiles_auth_user_id_fkey'
  ) then
    alter table public.user_profiles
      add constraint user_profiles_auth_user_id_fkey
      foreign key (auth_user_id) references auth.users(id) on delete cascade;
  end if;
end;
$$;

create unique index if not exists user_profiles_auth_user_id_uidx
  on public.user_profiles (auth_user_id)
  where auth_user_id is not null;

with candidates as (
  select
    auth_user.id as auth_id,
    profile.id as profile_id,
    row_number() over (
      partition by auth_user.id
      order by profile.created_at nulls last, profile.id
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
    select 1
    from public.user_profiles linked
    where linked.auth_user_id = candidates.auth_id
  );

do $$
declare
  unmatched_auth_users bigint;
  unmatched_profiles bigint;
begin
  select count(*) into unmatched_auth_users
  from auth.users auth_user
  where auth_user.email is not null
    and not exists (
      select 1 from public.user_profiles profile
      where profile.auth_user_id = auth_user.id
         or (profile.auth_user_id is null
             and lower(btrim(profile.email)) = lower(btrim(auth_user.email)))
    );

  select count(*) into unmatched_profiles
  from public.user_profiles profile
  where profile.auth_user_id is null
    and not exists (
      select 1 from auth.users auth_user
      where lower(btrim(auth_user.email)) = lower(btrim(profile.email))
    );

  raise notice 'Auth users without a matching profile: %; profile rows not linked to Auth: %',
    unmatched_auth_users, unmatched_profiles;
end;
$$;

create or replace function public.current_user_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select profile.role
  from public.user_profiles profile
  where profile.is_active
    and profile.registration_status = 'approved'
    and (
      profile.auth_user_id = auth.uid()
      or (
        profile.auth_user_id is null
        and lower(btrim(profile.email)) = lower(btrim(coalesce(auth.jwt() ->> 'email', '')))
      )
    )
  order by (profile.auth_user_id = auth.uid()) desc nulls last
  limit 1;
$$;

create or replace function public.current_user_profile_name()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select profile.name
  from public.user_profiles profile
  where profile.is_active
    and profile.registration_status = 'approved'
    and (
      profile.auth_user_id = auth.uid()
      or (
        profile.auth_user_id is null
        and lower(btrim(profile.email)) = lower(btrim(coalesce(auth.jwt() ->> 'email', '')))
      )
    )
  order by (profile.auth_user_id = auth.uid()) desc nulls last
  limit 1;
$$;
revoke all on function public.current_user_profile_name() from public, anon;
grant execute on function public.current_user_profile_name() to authenticated;

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
        and not (
          old.auth_user_id = auth.uid()
          and new.auth_user_id = old.auth_user_id
        )
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

drop trigger if exists enforce_profile_update_scope on public.user_profiles;
create trigger enforce_profile_update_scope
  before update on public.user_profiles
  for each row execute function public.enforce_profile_update_scope();

drop policy if exists "Users can read own profile" on public.user_profiles;
create policy "Users can read own profile" on public.user_profiles
  for select to authenticated
  using (
    auth_user_id = auth.uid()
    or (
      auth_user_id is null
      and lower(btrim(email)) = lower(btrim(coalesce(auth.jwt() ->> 'email', '')))
    )
  );

drop policy if exists "Users can update own profile" on public.user_profiles;
create policy "Users can update own profile" on public.user_profiles
  for update to authenticated
  using (
    auth_user_id = auth.uid()
    or (
      auth_user_id is null
      and lower(btrim(email)) = lower(btrim(coalesce(auth.jwt() ->> 'email', '')))
    )
  )
  with check (
    auth_user_id = auth.uid()
    or (
      auth_user_id is null
      and lower(btrim(email)) = lower(btrim(coalesce(auth.jwt() ->> 'email', '')))
    )
  );

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
       or (
         auth_user_id is null
         and lower(btrim(email)) = lower(btrim(old.email))
       );
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

create or replace function public.handle_new_user_registration()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.email is not null then
    insert into public.user_profiles (
      id, auth_user_id, name, email, role, department, phone, location,
      is_active, registration_status
    ) values (
      new.id::text,
      new.id,
      left(coalesce(nullif(btrim(new.raw_user_meta_data ->> 'name'), ''), 'New User'), 120),
      lower(btrim(new.email)),
      'Employee',
      left(coalesce(nullif(btrim(new.raw_user_meta_data ->> 'department'), ''), ''), 160),
      left(coalesce(nullif(btrim(new.raw_user_meta_data ->> 'phone'), ''), ''), 40),
      left(coalesce(nullif(btrim(new.raw_user_meta_data ->> 'location'), ''), 'Main Campus'), 160),
      false,
      'pending'
    )
    on conflict (email) do update
      set auth_user_id = excluded.auth_user_id,
          role = 'Employee',
          is_active = false,
          registration_status = 'pending',
          updated_at = now()
      where public.user_profiles.auth_user_id is null
         or public.user_profiles.auth_user_id = excluded.auth_user_id;
  end if;
  return new;
end;
$$;
revoke all on function public.handle_new_user_registration() from public, anon, authenticated;
drop trigger if exists on_auth_user_registered on auth.users;
create trigger on_auth_user_registered
  after insert on auth.users
  for each row execute function public.handle_new_user_registration();

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
        and profile.role = 'Personnel'
        and lower(btrim(profile.name)) = lower(btrim(coalesce(p_name, '')))
    )
    and exists (
      select 1
      from public.user_profiles profile
      where profile.is_active
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
      select 1 from jsonb_array_elements_text(old.assigned_personnel) assigned(name)
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
      select 1 from jsonb_array_elements_text(old.assigned_personnel) assigned(name)
      where lower(assigned.name) = lower(public.current_user_profile_name())
    )
    or new.assigned_to is distinct from old.assigned_to
    or new.assigned_personnel is distinct from old.assigned_personnel
    or (new.technician_state = 'completed' and old.technician_state <> 'started')
    or to_jsonb(new) - array['technician_state', 'assignment_note', 'completion_photo', 'photo_attachments']
       <> to_jsonb(old) - array['technician_state', 'assignment_note', 'completion_photo', 'photo_attachments'] then
      raise exception 'Personnel may update only the state and completion photos of requests assigned to them';
    end if;
  elsif public.current_user_role() is distinct from 'Admin' then
    raise exception 'This role cannot update this record';
  end if;
  return new;
end;
$$;

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
        ) assigned(name)
        where lower(assigned.name) = lower(public.current_user_profile_name())
      )
    )
    or lower(reporter) = lower(public.current_user_profile_name())
  );

drop policy if exists "Users can create own reports" on public.reports;
create policy "Users can create own reports" on public.reports
  for insert to authenticated
  with check (
    public.current_user_role() in ('Admin', 'Assistant', 'Employee', 'Student', 'Personnel')
    and lower(reporter) = lower(public.current_user_profile_name())
    and status = 'pending'
    and risk = 'low'
    and technician_state = 'unassigned'
    and coalesce(assigned_to, '') = ''
    and assigned_personnel = '[]'::jsonb
    and admin_remark is null
    and assignment_note is null
    and lower(coalesce(reporter_email, '')) in ('', lower(auth.jwt() ->> 'email'))
  );

drop policy if exists "Personnel can update assigned reports" on public.reports;
create policy "Personnel can update assigned reports" on public.reports
  for update to authenticated
  using (
    public.current_user_role() = 'Personnel'
    and exists (
      select 1 from jsonb_array_elements_text(assigned_personnel) assigned(name)
      where lower(assigned.name) = lower(public.current_user_profile_name())
    )
  )
  with check (
    public.current_user_role() = 'Personnel'
    and exists (
      select 1 from jsonb_array_elements_text(assigned_personnel) assigned(name)
      where lower(assigned.name) = lower(public.current_user_profile_name())
    )
  );

drop policy if exists "Authenticated users can read requests" on public.requests;
create policy "Authenticated users can read requests" on public.requests
  for select to authenticated
  using (
    public.current_user_role() in ('Admin', 'Assistant')
    or (
      public.current_user_role() = 'Personnel'
      and exists (
        select 1 from jsonb_array_elements_text(assigned_personnel) assigned(name)
        where lower(assigned.name) = lower(public.current_user_profile_name())
      )
    )
    or lower(requester) = lower(public.current_user_profile_name())
  );

drop policy if exists "Users can create own requests" on public.requests;
create policy "Users can create own requests" on public.requests
  for insert to authenticated
  with check (
    public.current_user_role() in ('Admin', 'Employee')
    and lower(requester) = lower(public.current_user_profile_name())
    and status = 'submitted'
    and risk = 'low'
    and technician_state = 'unassigned'
    and coalesce(assigned_to, '') = ''
    and assigned_personnel = '[]'::jsonb
    and admin_response is null
    and admin_remark is null
    and lower(coalesce(requester_email, '')) in ('', lower(auth.jwt() ->> 'email'))
  );

drop policy if exists "Users can submit feedback on own requests" on public.requests;
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

drop policy if exists "Personnel can update assigned requests" on public.requests;
create policy "Personnel can update assigned requests" on public.requests
  for update to authenticated
  using (
    public.current_user_role() = 'Personnel'
    and exists (
      select 1 from jsonb_array_elements_text(assigned_personnel) assigned(name)
      where lower(assigned.name) = lower(public.current_user_profile_name())
    )
  )
  with check (
    public.current_user_role() = 'Personnel'
    and exists (
      select 1 from jsonb_array_elements_text(assigned_personnel) assigned(name)
      where lower(assigned.name) = lower(public.current_user_profile_name())
    )
  );

drop policy if exists "Reporters can submit feedback for their completed reports" on public.report_feedback;
create policy "Reporters can submit feedback for their completed reports" on public.report_feedback
  for insert to authenticated
  with check (
    public.current_user_role() in ('Admin', 'Assistant', 'Employee', 'Personnel', 'Student')
    and lower(reporter_email) = lower(auth.jwt() ->> 'email')
    and exists (
      select 1 from public.reports report
      where report.id = report_id
        and lower(report.reporter) = lower(public.current_user_profile_name())
        and (report.status = 'resolved' or report.technician_state = 'completed')
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
            and lower(assigned.personnel_name) = lower(public.current_user_profile_name())
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
            and lower(assigned.personnel_name) = lower(public.current_user_profile_name())
          )
        )
      )
    )
  );

notify pgrst, 'reload schema';
