-- Safe recovery for Auth users whose public user_profiles row was removed.
-- Does not create or delete Auth accounts, change passwords, or alter
-- existing profiles. Restored rows are always inactive pending Employees;
-- only an Admin may assign another role and approve them.

insert into public.user_profiles (
  id, auth_user_id, name, email, role, department, phone, location, is_active, registration_status
)
select
  auth_user.id::text,
  auth_user.id,
  left(coalesce(nullif(btrim(auth_user.raw_user_meta_data ->> 'name'), ''), 'New User'), 120),
  lower(btrim(auth_user.email)),
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
    where profile.auth_user_id = auth_user.id
       or (
         profile.auth_user_id is null
         and lower(btrim(profile.email)) = lower(btrim(auth_user.email))
       )
  )
on conflict do nothing;
