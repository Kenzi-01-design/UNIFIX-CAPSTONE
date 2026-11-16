alter table public.evaluation_responses
  add column if not exists utaut_answers jsonb;

alter table public.evaluation_responses
  alter column sus_answers drop not null;

alter table public.evaluation_responses
  drop constraint if exists evaluation_responses_answers_valid;

create or replace function public.utaut_answers_are_valid(
  p_utaut_answers jsonb,
  p_iso_answers jsonb
)
returns boolean
language sql
immutable
set search_path = pg_catalog
as $$
  select
    case when jsonb_typeof(p_utaut_answers) = 'object' then
      (select count(*) = 5 from jsonb_object_keys(p_utaut_answers))
      and (select count(*) = 5 from jsonb_each(p_utaut_answers) answer
           where answer.key in (
             'performanceExpectancy', 'effortExpectancy', 'socialInfluence',
             'facilitatingConditions', 'behavioralIntention'
           )
           and case
             when jsonb_typeof(answer.value) = 'array' then
               jsonb_array_length(answer.value) = 3
               and not exists (
                 select 1
                 from jsonb_array_elements_text(answer.value) item(value)
                 where item.value !~ '^[1-5]$'
               )
             else false
           end)
    else false end
    and case when jsonb_typeof(p_iso_answers) = 'object' then
      (select count(*) = 8 from jsonb_object_keys(p_iso_answers))
      and (select count(*) = 8 from jsonb_each_text(p_iso_answers) answer
           where answer.key in (
             'functionalSuitability', 'performanceEfficiency', 'compatibility', 'usability',
             'reliability', 'security', 'maintainability', 'portability'
           ) and answer.value ~ '^[1-5]$')
    else false end;
$$;

revoke all on function public.utaut_answers_are_valid(jsonb, jsonb) from public, anon, authenticated;
grant execute on function public.utaut_answers_are_valid(jsonb, jsonb) to service_role;

alter table public.evaluation_responses
  add constraint evaluation_responses_answers_valid
  check (
    (sus_answers is not null and utaut_answers is null
      and public.evaluation_answers_are_valid(sus_answers, iso_answers))
    or
    (sus_answers is null and utaut_answers is not null
      and public.utaut_answers_are_valid(utaut_answers, iso_answers))
  );

create or replace function public.get_evaluation_summary()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  result jsonb;
begin
  if not public.has_admin_access() then
    raise exception 'Only administrators may view evaluation results';
  end if;

  select jsonb_build_object(
    'responseCount', (select count(*) from public.evaluation_responses where utaut_answers is not null),
    'utautMeans', coalesce((
      select jsonb_object_agg(construct, mean_score)
      from (
        select construct, round(avg(answer.value::numeric), 2) as mean_score
        from public.evaluation_responses response
        cross join lateral unnest(array[
          'performanceExpectancy', 'effortExpectancy', 'socialInfluence',
          'facilitatingConditions', 'behavioralIntention'
        ]) construct
        cross join lateral jsonb_array_elements_text(response.utaut_answers -> construct) answer(value)
        where response.utaut_answers is not null
        group by construct
      ) means
    ), '{}'::jsonb),
    'isoMeans', coalesce((
      select jsonb_object_agg(characteristic, mean_score)
      from (
        select characteristic, round(avg((response.iso_answers ->> characteristic)::numeric), 2) as mean_score
        from public.evaluation_responses response
        cross join lateral unnest(array[
          'functionalSuitability', 'performanceEfficiency', 'compatibility', 'usability',
          'reliability', 'security', 'maintainability', 'portability'
        ]) characteristic
        where response.utaut_answers is not null
        group by characteristic
      ) means
    ), '{}'::jsonb),
    'respondentsByRole', coalesce((
      select jsonb_object_agg(respondent_role, role_count)
      from (
        select respondent_role, count(*) as role_count
        from public.evaluation_responses
        where utaut_answers is not null
        group by respondent_role
      ) roles
    ), '{}'::jsonb)
  ) into result;

  return result;
end;
$$;

revoke all on function public.get_evaluation_summary() from public, anon;
grant execute on function public.get_evaluation_summary() to authenticated;

notify pgrst, 'reload schema';
