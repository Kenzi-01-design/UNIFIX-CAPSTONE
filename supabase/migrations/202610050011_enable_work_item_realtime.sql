-- Ensure assignments and workflow changes reach Admin and Personnel clients
-- for projects created by applying migrations rather than schema.sql.
alter table public.reports replica identity full;
alter table public.requests replica identity full;

do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    raise exception 'Supabase Realtime publication is missing; enable Realtime for this Supabase project first';
  end if;

  if not exists (
    select 1
    from pg_publication_rel pr
    join pg_class c on c.oid = pr.prrelid
    join pg_namespace n on n.oid = c.relnamespace
    join pg_publication p on p.oid = pr.prpubid
    where p.pubname = 'supabase_realtime'
      and n.nspname = 'public'
      and c.relname = 'reports'
  ) then
    alter publication supabase_realtime add table public.reports;
  end if;

  if not exists (
    select 1
    from pg_publication_rel pr
    join pg_class c on c.oid = pr.prrelid
    join pg_namespace n on n.oid = c.relnamespace
    join pg_publication p on p.oid = pr.prpubid
    where p.pubname = 'supabase_realtime'
      and n.nspname = 'public'
      and c.relname = 'requests'
  ) then
    alter publication supabase_realtime add table public.requests;
  end if;
end
$$;

notify pgrst, 'reload schema';
