-- Avoid setting pg_trgm.similarity_threshold in the function definition:
-- Supabase roles do not have permission to change this extension parameter.
-- Keep the same minimum similarity using similarity() directly.
create or replace function public.find_similar_open_reports(
  p_category text,
  p_location text,
  p_title text,
  p_anonymous_id text default null
)
returns table (id text, title text, location text, status text, similarity real)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  request_key text;
begin
  if char_length(btrim(coalesce(p_category, ''))) not between 1 and 80
     or char_length(btrim(coalesce(p_location, ''))) not between 1 and 300
     or char_length(btrim(coalesce(p_title, ''))) not between 3 and 180 then
    raise exception 'A valid category, location, and title are required';
  end if;
  if coalesce(auth.jwt() ->> 'email', '') <> '' then
    request_key := md5('duplicate-search:user:' || lower(auth.jwt() ->> 'email'));
  elsif coalesce(p_anonymous_id, '') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    request_key := md5('duplicate-search:anonymous:' || lower(p_anonymous_id));
  else
    raise exception 'A valid anonymous search identifier is required';
  end if;
  if not public.consume_public_endpoint_rate_limit(request_key, 30) then
    raise exception 'Too many duplicate searches. Wait a minute before trying again.';
  end if;

  return query
  select r.id, r.title, r.location, r.status,
         similarity(lower(r.title), lower(btrim(p_title))) as similarity
  from public.reports r
  where lower(r.category) = lower(btrim(p_category))
    and lower(r.location) = lower(btrim(p_location))
    and r.duplicate_of is null
    and r.status not in ('closed', 'resolved', 'action-taken')
    and similarity(lower(r.title), lower(btrim(p_title))) >= 0.20
  order by 5 desc, r.created_at desc
  limit 5;
end;
$$;

revoke all on function public.find_similar_open_reports(text, text, text, text) from public;
grant execute on function public.find_similar_open_reports(text, text, text, text) to anon, authenticated;

notify pgrst, 'reload schema';
