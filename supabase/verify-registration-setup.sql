-- Run after applying the migrations. Each row reports one setup check.
with checks as (
  select
    'registration trigger'::text as check_name,
    exists (
      select 1
      from pg_trigger trigger_row
      join pg_proc function_row on function_row.oid = trigger_row.tgfoid
      join pg_namespace function_schema on function_schema.oid = function_row.pronamespace
      where trigger_row.tgrelid = 'auth.users'::regclass
        and trigger_row.tgname = 'on_auth_user_registered'
        and not trigger_row.tgisinternal
        and trigger_row.tgenabled <> 'D'
        and function_schema.nspname = 'public'
        and function_row.proname = 'handle_new_user_registration'
        and function_row.prosecdef
        and 'search_path=public' = any(function_row.proconfig)
    ) as passed,
    'on_auth_user_registered must call the SECURITY DEFINER function with search_path=public'::text as detail
  union all
  select
    'profile RLS enabled',
    coalesce((select relrowsecurity from pg_class where oid = 'public.user_profiles'::regclass), false),
    'public.user_profiles must have row-level security enabled'
  union all
  select
    'reports RLS enabled',
    coalesce((select relrowsecurity from pg_class where oid = 'public.reports'::regclass), false),
    'public.reports must have row-level security enabled'
  union all
  select
    'requests RLS enabled',
    coalesce((select relrowsecurity from pg_class where oid = 'public.requests'::regclass), false),
    'public.requests must have row-level security enabled'
  union all
  select
    'Auth users have profiles',
    not exists (
      select 1
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
    ),
    'No Auth user with an email may be missing a linked or legacy-matched profile'
)
select check_name, passed, detail
from checks
order by check_name;

-- To inspect rows that still need manual review:
select
  auth_user.id as auth_user_id,
  auth_user.email,
  auth_user.created_at as auth_created_at
from auth.users auth_user
where auth_user.email is not null
  and not exists (
    select 1 from public.user_profiles profile
    where profile.auth_user_id = auth_user.id
       or (
         profile.auth_user_id is null
         and lower(btrim(profile.email)) = lower(btrim(auth_user.email))
       )
  )
order by auth_user.created_at;

select
  (select count(*)
   from auth.users auth_user
   where auth_user.email is not null
     and not exists (
       select 1 from public.user_profiles profile
       where profile.auth_user_id = auth_user.id
          or (profile.auth_user_id is null
              and lower(btrim(profile.email)) = lower(btrim(auth_user.email)))
     )) as auth_users_without_profile,
  (select count(*)
   from public.user_profiles profile
   where profile.auth_user_id is null
     and not exists (
       select 1 from auth.users auth_user
       where lower(btrim(auth_user.email)) = lower(btrim(profile.email))
     )) as profiles_without_auth_user_match;
