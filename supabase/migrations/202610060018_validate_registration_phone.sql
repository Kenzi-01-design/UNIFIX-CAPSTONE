create or replace function public.validate_registration_phone()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
declare
  phone text := coalesce(new.raw_user_meta_data ->> 'phone', '');
begin
  if phone <> '' and phone !~ '^[0-9]{11}$' then
    raise exception 'Registration phone numbers must contain exactly 11 digits.';
  end if;
  return new;
end;
$$;

revoke all on function public.validate_registration_phone() from public, anon, authenticated;

drop trigger if exists validate_registration_phone on auth.users;
create trigger validate_registration_phone
  before insert on auth.users
  for each row execute function public.validate_registration_phone();
