-- Phase 4: anonymized evaluation storage and least-privilege report reads.
create or replace function public.validate_work_item_input()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  content_changed boolean;
begin
  if tg_table_name = 'reports' then
    if tg_op = 'INSERT' then
      content_changed := true;
    else
      content_changed := new.description is distinct from old.description;
    end if;
    if char_length(btrim(coalesce(new.title, ''))) not between 1 and 160
      or char_length(coalesce(new.description, '')) > 4000
      or (content_changed
        and char_length(btrim(coalesce(new.description, ''))) not between 1 and 4000)
      or char_length(btrim(coalesce(new.category, ''))) not between 1 and 80
      or char_length(btrim(coalesce(new.location, ''))) not between 1 and 300
      or char_length(btrim(coalesce(new.reporter, ''))) not between 1 and 120
      or (new.reporter_email is not null and (
        char_length(new.reporter_email) > 254
        or new.reporter_email !~* '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
      )) then
      raise exception 'The report contains invalid or oversized fields';
    end if;
  else
    if tg_op = 'INSERT' then
      content_changed := true;
    else
      content_changed := new.details is distinct from old.details;
    end if;
    if char_length(btrim(coalesce(new.title, ''))) not between 1 and 160
      or char_length(btrim(coalesce(new.category, ''))) not between 1 and 80
      or char_length(btrim(coalesce(new.department, ''))) not between 1 and 300
      or char_length(coalesce(new.details, '')) > 4000
      or (content_changed
        and char_length(btrim(coalesce(new.details, ''))) not between 1 and 4000)
      or char_length(btrim(coalesce(new.requester, ''))) not between 1 and 120
      or (new.requester_email is not null and (
        char_length(new.requester_email) > 254
        or new.requester_email !~* '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
      )) then
      raise exception 'The request contains invalid or oversized fields';
    end if;
  end if;

  if jsonb_typeof(coalesce(new.photo_attachments, '[]'::jsonb)) <> 'array'
    or jsonb_array_length(coalesce(new.photo_attachments, '[]'::jsonb)) > 3 then
    raise exception 'Attach no more than three valid photos';
  end if;
  return new;
end;
$$;

drop trigger if exists validate_report_input on public.reports;
create trigger validate_report_input
  before insert or update on public.reports
  for each row execute function public.validate_work_item_input();
drop trigger if exists validate_request_input on public.requests;
create trigger validate_request_input
  before insert or update on public.requests
  for each row execute function public.validate_work_item_input();
revoke all on function public.validate_work_item_input() from public, anon, authenticated;

drop policy if exists "Users can create own reports" on public.reports;
create policy "Users can create own reports" on public.reports
  for insert to authenticated
  with check (
    public.current_user_role() in ('Admin', 'Assistant', 'Employee', 'Student', 'Personnel')
    and lower(reporter) = lower((
      select name from public.user_profiles
      where lower(email) = lower(auth.jwt() ->> 'email')
      limit 1
    ))
    and status = 'pending'
    and priority = 'low'
    and risk = 'low'
    and technician_state = 'unassigned'
    and coalesce(assigned_to, '') = ''
    and assigned_personnel = '[]'::jsonb
    and admin_remark is null
    and assignment_note is null
    and lower(coalesce(reporter_email, '')) in ('', lower(auth.jwt() ->> 'email'))
  );

drop policy if exists "Users can create own requests" on public.requests;
create policy "Users can create own requests" on public.requests
  for insert to authenticated
  with check (
    public.current_user_role() in ('Admin', 'Employee')
    and lower(requester) = lower((
      select name from public.user_profiles
      where lower(email) = lower(auth.jwt() ->> 'email')
      limit 1
    ))
    and status = 'submitted'
    and priority = 'low'
    and risk = 'low'
    and technician_state = 'unassigned'
    and coalesce(assigned_to, '') = ''
    and assigned_personnel = '[]'::jsonb
    and admin_response is null
    and admin_remark is null
    and lower(coalesce(requester_email, '')) in ('', lower(auth.jwt() ->> 'email'))
  );

drop policy if exists "Staff can read report photos" on storage.objects;
create policy "Staff can read report photos" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'report-photos'
    and (
      public.current_user_role() in ('Admin', 'Assistant')
      or (
        public.current_user_role() = 'Personnel'
        and (
          exists (
            select 1
            from public.reports report
            cross join lateral jsonb_array_elements_text(
              case when jsonb_typeof(report.assigned_personnel) = 'array'
                then report.assigned_personnel else '[]'::jsonb end
            ) assigned(personnel_name)
            where report.id = case
              when (storage.foldername(name))[2] = 'reports' then replace((storage.foldername(name))[3], '%23', '#')
              when (storage.foldername(name))[1] = 'public'
                and (storage.foldername(name))[2] = 'reports' then replace((storage.foldername(name))[3], '%23', '#')
              else null
            end
            and lower(assigned.personnel_name) = lower((
              select profile.name from public.user_profiles profile
              where lower(profile.email) = lower(auth.jwt() ->> 'email')
              limit 1
            ))
          )
          or exists (
            select 1
            from public.requests request
            cross join lateral jsonb_array_elements_text(
              case when jsonb_typeof(request.assigned_personnel) = 'array'
                then request.assigned_personnel else '[]'::jsonb end
            ) assigned(personnel_name)
            where request.id = case
              when (storage.foldername(name))[2] = 'requests' then replace((storage.foldername(name))[3], '%23', '#')
              when (storage.foldername(name))[1] = 'public'
                and (storage.foldername(name))[2] = 'requests' then replace((storage.foldername(name))[3], '%23', '#')
              else null
            end
            and lower(assigned.personnel_name) = lower((
              select profile.name from public.user_profiles profile
              where lower(profile.email) = lower(auth.jwt() ->> 'email')
              limit 1
            ))
          )
        )
      )
    )
  );

create or replace function public.evaluation_answers_are_valid(
  p_sus_answers smallint[],
  p_iso_answers jsonb
)
returns boolean
language sql
immutable
set search_path = pg_catalog
as $$
  select
    coalesce(array_ndims(p_sus_answers) = 1 and array_length(p_sus_answers, 1) = 10, false)
    and not exists (
      select 1 from unnest(coalesce(p_sus_answers, array[]::smallint[])) answer
      where answer not between 1 and 5
    )
    and jsonb_typeof(p_iso_answers) = 'object'
    and (select count(*) = 8 from jsonb_object_keys(p_iso_answers))
    and (select count(*) = 8 from jsonb_each_text(p_iso_answers) answer
         where answer.key in (
           'functionalSuitability', 'performanceEfficiency', 'compatibility', 'usability',
           'reliability', 'security', 'maintainability', 'portability'
         ) and answer.value ~ '^[1-5]$');
$$;

create table if not exists public.evaluation_responses (
  id uuid primary key default gen_random_uuid(),
  submission_key uuid not null unique,
  respondent_role text not null
    check (respondent_role in ('Public', 'Employee', 'Assistant', 'Personnel', 'Admin', 'Student')),
  sus_answers smallint[] not null,
  iso_answers jsonb not null,
  created_at timestamptz not null default now(),
  constraint evaluation_responses_answers_valid
    check (public.evaluation_answers_are_valid(sus_answers, iso_answers))
);

alter table public.evaluation_responses enable row level security;
revoke all on public.evaluation_responses from public, anon, authenticated;
grant insert on public.evaluation_responses to service_role;
revoke all on function public.evaluation_answers_are_valid(smallint[], jsonb) from public, anon, authenticated;
grant execute on function public.evaluation_answers_are_valid(smallint[], jsonb) to service_role;
drop policy if exists "Anonymous callers cannot access raw evaluation responses" on public.evaluation_responses;
create policy "Anonymous callers cannot access raw evaluation responses" on public.evaluation_responses
  for all to anon using (false) with check (false);
drop policy if exists "Admins cannot access raw evaluation responses" on public.evaluation_responses;
create policy "Admins cannot access raw evaluation responses" on public.evaluation_responses
  for all to authenticated using (public.current_user_role() = 'Admin' and false) with check (false);
drop policy if exists "Assistants cannot access raw evaluation responses" on public.evaluation_responses;
create policy "Assistants cannot access raw evaluation responses" on public.evaluation_responses
  for all to authenticated using (public.current_user_role() = 'Assistant' and false) with check (false);
drop policy if exists "Employees cannot access raw evaluation responses" on public.evaluation_responses;
create policy "Employees cannot access raw evaluation responses" on public.evaluation_responses
  for all to authenticated using (public.current_user_role() = 'Employee' and false) with check (false);
drop policy if exists "Personnel cannot access raw evaluation responses" on public.evaluation_responses;
create policy "Personnel cannot access raw evaluation responses" on public.evaluation_responses
  for all to authenticated using (public.current_user_role() = 'Personnel' and false) with check (false);
drop policy if exists "Students cannot access raw evaluation responses" on public.evaluation_responses;
create policy "Students cannot access raw evaluation responses" on public.evaluation_responses
  for all to authenticated using (public.current_user_role() = 'Student' and false) with check (false);

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
  if coalesce(public.current_user_role(), '') <> 'Admin' then
    raise exception 'Only administrators may view evaluation results';
  end if;

  with sus_scores as (
    select response.id,
      sum(case when answer.ordinality % 2 = 1
        then answer.value::integer - 1
        else 5 - answer.value::integer end) * 2.5 as score
    from public.evaluation_responses response
    cross join lateral unnest(response.sus_answers) with ordinality answer(value, ordinality)
    group by response.id
  )
  select jsonb_build_object(
    'responseCount', (select count(*) from public.evaluation_responses),
    'susAverage', (select round(avg(score)::numeric, 2) from sus_scores),
    'isoMeans', coalesce((
      select jsonb_object_agg(characteristic, mean_score)
      from (
        select characteristic, round(avg((response.iso_answers ->> characteristic)::numeric), 2) as mean_score
        from public.evaluation_responses response
        cross join lateral unnest(array[
          'functionalSuitability', 'performanceEfficiency', 'compatibility', 'usability',
          'reliability', 'security', 'maintainability', 'portability'
        ]) characteristic
        group by characteristic
      ) means
    ), '{}'::jsonb),
    'respondentsByRole', coalesce((
      select jsonb_object_agg(respondent_role, role_count)
      from (
        select respondent_role, count(*) as role_count
        from public.evaluation_responses
        group by respondent_role
      ) roles
    ), '{}'::jsonb)
  ) into result;

  return result;
end;
$$;

revoke all on function public.get_evaluation_summary() from public, anon;
grant execute on function public.get_evaluation_summary() to authenticated;

drop policy if exists "Authenticated users can read reports" on public.reports;
create policy "Authenticated users can read reports" on public.reports
  for select to authenticated
  using (
    public.current_user_role() in ('Admin', 'Assistant')
    or (
      public.current_user_role() = 'Personnel'
      and exists (
        select 1
        from jsonb_array_elements_text(
          case when jsonb_typeof(assigned_personnel) = 'array'
            then assigned_personnel else '[]'::jsonb end
        ) as assigned(name)
        where lower(assigned.name) = lower((
          select name from public.user_profiles
          where lower(email) = lower(auth.jwt() ->> 'email')
          limit 1
        ))
      )
    )
    or lower(reporter) = lower((
      select name from public.user_profiles
      where lower(email) = lower(auth.jwt() ->> 'email')
      limit 1
    ))
  );
