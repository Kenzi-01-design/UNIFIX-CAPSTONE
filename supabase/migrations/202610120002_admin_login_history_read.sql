begin;

alter table public.login_events enable row level security;
grant select on public.login_events to authenticated;

drop policy if exists "Admins can read login events" on public.login_events;
create policy "Admins can read login events"
  on public.login_events
  for select to authenticated
  using (public.current_user_role() = 'Admin');

notify pgrst, 'reload schema';

commit;
