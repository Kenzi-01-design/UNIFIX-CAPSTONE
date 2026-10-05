alter table public.user_profiles
  add column if not exists registration_status text not null default 'approved'
  check (registration_status in ('pending', 'approved', 'rejected'));

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
      or new.is_active <> old.is_active
      or new.registration_status <> old.registration_status then
      raise exception 'Only contact details may be updated';
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.handle_new_user_registration()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.email is not null then
    if exists (
      select 1
      from public.user_profiles profile
      where lower(profile.email) = lower(new.email)
        and profile.id <> new.id::text
    ) then
      raise exception 'A university profile already exists for this email address';
    end if;

    insert into public.user_profiles (
      id, name, email, role, department, phone, location, is_active, registration_status
    ) values (
      new.id::text,
      left(coalesce(nullif(btrim(new.raw_user_meta_data ->> 'name'), ''), 'New User'), 120),
      lower(new.email),
      'Employee',
      left(coalesce(nullif(btrim(new.raw_user_meta_data ->> 'department'), ''), ''), 160),
      left(coalesce(nullif(btrim(new.raw_user_meta_data ->> 'phone'), ''), ''), 40),
      left(coalesce(nullif(btrim(new.raw_user_meta_data ->> 'location'), ''), 'Main Campus'), 160),
      false,
      'pending'
    )
    on conflict (email) do nothing;
  end if;
  return new;
end;
$$;

revoke all on function public.handle_new_user_registration() from public, anon, authenticated;

drop trigger if exists on_auth_user_registered on auth.users;
create trigger on_auth_user_registered
  after insert on auth.users
  for each row execute function public.handle_new_user_registration();

insert into public.user_profiles (
  id, name, email, role, department, phone, location, is_active, registration_status
)
select
  auth_user.id::text,
  left(coalesce(nullif(btrim(auth_user.raw_user_meta_data ->> 'name'), ''), 'New User'), 120),
  lower(auth_user.email),
  'Employee',
  left(coalesce(nullif(btrim(auth_user.raw_user_meta_data ->> 'department'), ''), ''), 160),
  left(coalesce(nullif(btrim(auth_user.raw_user_meta_data ->> 'phone'), ''), ''), 40),
  left(coalesce(nullif(btrim(auth_user.raw_user_meta_data ->> 'location'), ''), 'Main Campus'), 160),
  false,
  'pending'
from auth.users auth_user
where auth_user.email is not null
  and not exists (
    select 1
    from public.user_profiles profile
    where lower(profile.email) = lower(auth_user.email)
  )
on conflict (email) do nothing;

notify pgrst, 'reload schema';
