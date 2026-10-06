alter table public.user_profiles
  add column if not exists requested_role text not null default 'Employee'
  check (requested_role in ('Employee', 'Assistant', 'Personnel'));

create or replace function public.handle_new_user_registration()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  requested_role text := case
    when new.raw_user_meta_data ->> 'requested_role' in ('Employee', 'Assistant', 'Personnel')
      then new.raw_user_meta_data ->> 'requested_role'
    else 'Employee'
  end;
begin
  if new.email is not null then
    insert into public.user_profiles (
      id, auth_user_id, name, email, role, requested_role, department, phone, location,
      is_active, registration_status
    ) values (
      new.id::text,
      new.id,
      left(coalesce(nullif(btrim(new.raw_user_meta_data ->> 'name'), ''), 'New User'), 120),
      lower(btrim(new.email)),
      'Employee',
      requested_role,
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

revoke all on function public.handle_new_user_registration() from public, anon, authenticated;

drop trigger if exists on_auth_user_registered on auth.users;
create trigger on_auth_user_registered
  after insert on auth.users
  for each row execute function public.handle_new_user_registration();

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
    select 1
    from public.user_profiles profile
    where profile.auth_user_id = auth_user.id
       or lower(btrim(profile.email)) = lower(btrim(auth_user.email))
  )
on conflict do nothing;

notify pgrst, 'reload schema';
