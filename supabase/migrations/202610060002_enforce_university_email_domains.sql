  -- The server-side default is nvsu.edu.ph. An empty configured array rejects
-- all new registrations and Auth email changes (fail closed).
create table if not exists public.account_security_settings (
  singleton boolean primary key default true check (singleton),
  allowed_email_domains text[] not null default array['nvsu.edu.ph']::text[],
  updated_at timestamptz not null default now()
);

insert into public.account_security_settings (singleton, allowed_email_domains)
values (true, array['nvsu.edu.ph']::text[])
on conflict (singleton) do nothing;

alter table public.account_security_settings enable row level security;
revoke all on public.account_security_settings from public, anon, authenticated;
drop policy if exists "No client access to account security settings" on public.account_security_settings;
create policy "No client access to account security settings" on public.account_security_settings
  for all to anon, authenticated
  using (false)
  with check (false);

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
