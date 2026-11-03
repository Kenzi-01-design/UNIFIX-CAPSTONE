alter table public.user_profiles
  add column if not exists specialty text not null default '';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.user_profiles'::regclass
      and conname = 'user_profiles_specialty_check'
  ) then
    alter table public.user_profiles
      add constraint user_profiles_specialty_check
      check (specialty in (
        '', 'Electrical', 'Plumbing', 'Sewerage', 'Furniture', 'HVAC', 'Network',
        'Civil', 'Carpentry', 'Security', 'Sanitation', 'Other'
      ));
  end if;
end;
$$;

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
  specialty text := case
    when new.raw_user_meta_data ->> 'specialty' in (
      'Electrical', 'Plumbing', 'Sewerage', 'Furniture', 'HVAC', 'Network',
      'Civil', 'Carpentry', 'Security', 'Sanitation', 'Other'
    ) then new.raw_user_meta_data ->> 'specialty'
    else ''
  end;
begin
  if new.email is not null then
    if requested_role = 'Personnel' and specialty = '' then
      raise exception 'A valid work specialty is required for Personnel registration.';
    end if;

    insert into public.user_profiles (
      id, auth_user_id, name, email, role, requested_role, specialty, department, phone, location,
      is_active, registration_status
    ) values (
      new.id::text,
      new.id,
      left(coalesce(nullif(btrim(new.raw_user_meta_data ->> 'name'), ''), 'New User'), 120),
      lower(btrim(new.email)),
      'Employee',
      requested_role,
      specialty,
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
          specialty = excluded.specialty,
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

notify pgrst, 'reload schema';
