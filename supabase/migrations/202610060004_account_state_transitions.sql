alter table public.user_profiles
  add column if not exists rejection_reason text;

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
  if auth.uid() is null then
    raise exception 'Sign in to request a new application review.';
  end if;

  select id, registration_status into profile_id, profile_status
  from public.user_profiles
  where auth_user_id = auth.uid()
     or (
       auth_user_id is null
       and lower(btrim(email)) = lower(btrim(coalesce(auth.jwt() ->> 'email', '')))
     )
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
  set   registration_status = 'pending',
  is_active = false,
  rejection_reason = null,
  updated_at = now()
  where id = p_profile_id
    and registration_status = 'rejected';
  if not found then
    raise exception 'This application is no longer rejected.';
  end if;
  perform set_config('unifix.admin_reopen', 'off', true);

  update public.account_reapplication_requests request
  set reviewed_at = now()
  where request.profile_id = p_profile_id;
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
      if not new.is_active
        or new.role not in ('Admin', 'Assistant', 'Employee', 'Personnel')
        or new.rejection_reason is not null then
        raise exception 'Approved registrations must have an allowed role and active access.';
      end if;
    elsif old.registration_status = 'pending' and new.registration_status = 'rejected' then
      if new.is_active or nullif(btrim(new.rejection_reason), '') is null then
        raise exception 'A rejection reason is required and rejected accounts must remain inactive.';
      end if;
    elsif old.registration_status = 'rejected' and new.registration_status = 'pending' then
      if not admin_call
        or current_setting('unifix.admin_reopen', true) is distinct from 'on'
        or new.is_active
        or new.rejection_reason is not null then
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
    if new.rejection_reason is not null then
      raise exception 'Approved accounts cannot have a rejection reason.';
    end if;
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
    where profile.role = 'Admin'
      and profile.is_active
      and profile.id <> old.id;
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
    select 1
    from public.user_profiles profile
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
               ) assigned(name)
               where lower(assigned.name) = lower(profile.name)
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
               ) assigned(name)
               where lower(assigned.name) = lower(profile.name)
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
declare
  action_name text;
begin
  if coalesce(auth.role(), '') = 'service_role' then
    return new;
  end if;
  if old.role is distinct from new.role then
    action_name := 'user_role_changed';
  elsif old.registration_status is distinct from new.registration_status then
    action_name := 'registration_' || new.registration_status;
  elsif old.is_active is distinct from new.is_active then
    action_name := case when new.is_active then 'user_reactivated' else 'user_deactivated' end;
  else
    return new;
  end if;

  insert into public.account_audit_log (
    actor_auth_user_id, actor_email, action, target_auth_user_id, target_email, details
  ) values (
    auth.uid(),
    coalesce(auth.jwt() ->> 'email', 'system'),
    action_name,
    new.auth_user_id,
    new.email,
    jsonb_build_object(
      'old_role', old.role,
      'new_role', new.role,
      'old_status', old.registration_status,
      'new_status', new.registration_status,
      'old_is_active', old.is_active,
      'new_is_active', new.is_active,
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
