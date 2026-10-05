-- Safe recovery for Auth users whose public user_profiles row was removed.
-- Does not create or delete Auth accounts, change passwords, or alter
-- existing profiles. Restored accounts require Admin approval before login.

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
