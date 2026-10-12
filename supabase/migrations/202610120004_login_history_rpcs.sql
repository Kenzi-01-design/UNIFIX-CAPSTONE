begin;

create or replace function public.record_login_event()
returns setof public.login_events
language plpgsql
security definer
set search_path = public
as $$
declare
  login_role text := public.current_user_role();
  login_name text := public.current_user_profile_name();
  login_email text := lower(btrim(coalesce(auth.jwt() ->> 'email', '')));
  login_row public.login_events%rowtype;
begin
  if auth.uid() is null then
    raise exception 'An authenticated user is required to record a login event';
  end if;

  if login_role is null
    or login_role not in ('Admin', 'Employee', 'Assistant', 'Personnel')
    or login_name is null
    or login_email = '' then
    raise exception 'The authenticated user does not have an approved staff profile';
  end if;

  insert into public.login_events (id, user_name, role, email, logged_in_at)
  values (
    'LOGIN-' || auth.uid()::text || '-' || gen_random_uuid()::text,
    login_name,
    login_role,
    login_email,
    clock_timestamp()
  )
  returning * into login_row;

  return next login_row;
end;
$$;

create or replace function public.get_admin_login_history()
returns setof public.login_events
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or public.current_user_role() is distinct from 'Admin' then
    raise exception 'Only an authenticated Admin can read login history';
  end if;

  return query
    select *
    from public.login_events
    order by logged_in_at desc nulls last, id desc
    limit 500;
end;
$$;

revoke all on function public.record_login_event() from public, anon;
revoke all on function public.get_admin_login_history() from public, anon;
grant execute on function public.record_login_event() to authenticated;
grant execute on function public.get_admin_login_history() to authenticated;

notify pgrst, 'reload schema';

commit;
