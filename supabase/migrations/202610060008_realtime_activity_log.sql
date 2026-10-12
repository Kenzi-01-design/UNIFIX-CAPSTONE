alter table public.login_events replica identity full;
grant insert on public.login_events to authenticated;

drop policy if exists "Users can record own login events" on public.login_events;
create policy "Users can record own login events" on public.login_events
  for insert to authenticated
  with check (
    user_name = public.current_user_profile_name()
    and role = public.current_user_role()
    and lower(btrim(email)) = lower(btrim(coalesce(auth.jwt() ->> 'email', '')))
    and logged_in_at between now() - interval '1 minute' and now() + interval '1 minute'
  );

do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    raise exception 'Supabase Realtime publication is missing; enable Realtime for this Supabase project first';
  end if;

  if not exists (
    select 1
    from pg_publication_rel publication_table
    join pg_class relation on relation.oid = publication_table.prrelid
    join pg_namespace relation_schema on relation_schema.oid = relation.relnamespace
    join pg_publication publication on publication.oid = publication_table.prpubid
    where publication.pubname = 'supabase_realtime'
      and relation_schema.nspname = 'public'
      and relation.relname = 'login_events'
  ) then
    alter publication supabase_realtime add table public.login_events;
  end if;
end
$$;

notify pgrst, 'reload schema';
