begin;

do $$
declare
  current_tracking_year integer := extract(year from now())::integer;
  highest_existing_number bigint;
begin
  select greatest(
    99,
    coalesce((
      select max(substring(
        tracking_code
        from char_length('UNI-' || current_tracking_year::text || '-') + 1
      )::bigint)
      from public.reports
      where tracking_code ~ ('^UNI-' || current_tracking_year::text || '-[0-9]+$')
    ), 0),
    coalesce((
      select max(substring(
        tracking_code
        from char_length('UNI-' || current_tracking_year::text || '-') + 1
      )::bigint)
      from public.requests
      where tracking_code ~ ('^UNI-' || current_tracking_year::text || '-[0-9]+$')
    ), 0)
  )
  into highest_existing_number;

  insert into public.tracking_code_counters (tracking_year, last_number)
  values (current_tracking_year, highest_existing_number)
  on conflict (tracking_year) do update
  set last_number = greatest(
    public.tracking_code_counters.last_number,
    excluded.last_number
  );
end;
$$;

commit;
