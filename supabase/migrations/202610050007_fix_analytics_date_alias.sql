create or replace function public.get_unifix_analytics(
  p_from_date date,
  p_to_date date,
  p_category text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  result jsonb;
begin
  if coalesce(public.current_user_role(), '') not in ('Admin', 'Assistant') then
    raise exception 'Analytics are available to administrators and assistants only';
  end if;
  if p_from_date is null or p_to_date is null or p_from_date > p_to_date
     or p_to_date > current_date + 1 then
    raise exception 'Choose a valid analytics date range';
  end if;

  with work as (
    select r.id, r.category, r.location, r.priority, r.status, r.due_at,
           r.created_at, r.completed_at, r.rework_count,
           case when jsonb_typeof(r.assigned_personnel) = 'array' then r.assigned_personnel else '[]'::jsonb end as assigned_personnel
      from public.reports r
    union all
    select q.id, q.category, q.department, q.priority, q.status, q.due_at,
           q.created_at, q.completed_at, q.rework_count,
           case when jsonb_typeof(q.assigned_personnel) = 'array' then q.assigned_personnel else '[]'::jsonb end
      from public.requests q
  ), filtered as (
    select * from work
     where created_at::date between p_from_date and p_to_date
       and (p_category is null or p_category = '' or category = p_category)
  ), personnel as (
    select person.name,
           count(*) filter (where f.status not in ('closed', 'resolved', 'action-taken')) as open_count,
           count(*) filter (where f.status in ('closed', 'resolved', 'action-taken')) as completed_count
      from filtered f
      cross join lateral jsonb_array_elements_text(f.assigned_personnel) person(name)
     group by person.name
  )
  select jsonb_build_object(
    'stats', jsonb_build_object(
      'total', (select count(*) from filtered),
      'open', (select count(*) from filtered where status not in ('closed', 'resolved', 'action-taken')),
      'overdue', (select count(*) from filtered where status not in ('closed', 'resolved', 'action-taken') and due_at < now()),
      'completed', (select count(*) from work where completed_at::date between p_from_date and p_to_date
                    and (p_category is null or p_category = '' or category = p_category)),
      'avgResolutionDays', (select round(avg(extract(epoch from (completed_at - created_at)) / 86400)::numeric, 2)
                            from filtered where completed_at is not null and completed_at >= created_at),
      'slaCompliance', coalesce((select round(100.0 * count(*) filter (where completed_at <= due_at) / nullif(count(*), 0), 1)
                                 from filtered where completed_at is not null and due_at is not null), 0),
      'averageRating', (select round(avg(fb.rating)::numeric, 2)
                        from public.report_feedback fb join public.reports r on r.id = fb.report_id
                        where r.created_at::date between p_from_date and p_to_date
                          and (p_category is null or p_category = '' or r.category = p_category)),
      'reworkRate', coalesce((select round(100.0 * count(*) filter (where rework_count > 0) / nullif(count(*), 0), 1)
                              from filtered), 0)
    ),
    'categories', coalesce((select jsonb_agg(jsonb_build_object('name', category, 'count', amount) order by amount desc)
                            from (select category, count(*) amount from filtered group by category) c), '[]'::jsonb),
    'locations', coalesce((select jsonb_agg(jsonb_build_object('name', location, 'count', amount) order by amount desc)
                           from (select location, count(*) amount from filtered group by location order by amount desc limit 10) l), '[]'::jsonb),
    'trend', coalesce((select jsonb_agg(jsonb_build_object('date', trend_date, 'count', amount) order by trend_date)
                       from (select created_at::date as trend_date, count(*) amount from filtered group by created_at::date) t), '[]'::jsonb),
    'priorities', coalesce((select jsonb_agg(jsonb_build_object('name', priority, 'count', amount) order by amount desc)
                            from (select priority, count(*) amount from filtered group by priority) p), '[]'::jsonb),
    'personnel', coalesce((select jsonb_agg(jsonb_build_object('name', name, 'open', open_count, 'completed', completed_count) order by open_count desc)
                           from personnel), '[]'::jsonb)
  ) into result;
  return result;
end;
$$;
revoke all on function public.get_unifix_analytics(date, date, text) from public, anon;
grant execute on function public.get_unifix_analytics(date, date, text) to authenticated;
