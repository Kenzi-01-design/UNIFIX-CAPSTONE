insert into public.tracking_code_counters (tracking_year, last_number)
values (extract(year from now())::integer, 99)
on conflict (tracking_year) do update
set last_number = 99;
