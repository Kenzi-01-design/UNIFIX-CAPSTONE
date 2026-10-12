create or replace function public.is_current_assigned_personnel(p_name text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_user_role() = 'Personnel', false)
    and (
      select count(*) = 1
      from public.user_profiles profile
      where profile.is_active
        and profile.registration_status = 'approved'
        and profile.role = 'Personnel'
        and lower(btrim(profile.name)) = lower(btrim(coalesce(p_name, '')))
    )
    and exists (
      select 1
      from public.user_profiles profile
      where profile.is_active
        and profile.registration_status = 'approved'
        and profile.role = 'Personnel'
        and (
          profile.auth_user_id = auth.uid()
          or (
            profile.auth_user_id is null
            and lower(btrim(profile.email)) = lower(btrim(coalesce(auth.jwt() ->> 'email', '')))
          )
        )
        and lower(btrim(profile.name)) = lower(btrim(coalesce(p_name, '')))
    );
$$;
revoke all on function public.is_current_assigned_personnel(text) from public, anon;
grant execute on function public.is_current_assigned_personnel(text) to authenticated;

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
        ) assigned(name)
        where public.is_current_assigned_personnel(assigned.name)
      )
    )
    or lower(reporter) = lower(public.current_user_profile_name())
  );

drop policy if exists "Personnel can update assigned reports" on public.reports;
create policy "Personnel can update assigned reports" on public.reports
  for update to authenticated
  using (
    public.current_user_role() = 'Personnel'
    and exists (
      select 1
      from jsonb_array_elements_text(
        case when jsonb_typeof(assigned_personnel) = 'array'
          then assigned_personnel else '[]'::jsonb end
      ) assigned(name)
      where public.is_current_assigned_personnel(assigned.name)
    )
  )
  with check (
    public.current_user_role() = 'Personnel'
    and exists (
      select 1
      from jsonb_array_elements_text(
        case when jsonb_typeof(assigned_personnel) = 'array'
          then assigned_personnel else '[]'::jsonb end
      ) assigned(name)
      where public.is_current_assigned_personnel(assigned.name)
    )
  );

drop policy if exists "Authenticated users can read requests" on public.requests;
create policy "Authenticated users can read requests" on public.requests
  for select to authenticated
  using (
    public.current_user_role() in ('Admin', 'Assistant')
    or (
      public.current_user_role() = 'Employee'
      and lower(requester_email) = lower(auth.jwt() ->> 'email')
    )
    or (
      public.current_user_role() = 'Personnel'
      and exists (
        select 1
        from jsonb_array_elements_text(
          case when jsonb_typeof(assigned_personnel) = 'array'
            then assigned_personnel else '[]'::jsonb end
        ) assigned(name)
        where public.is_current_assigned_personnel(assigned.name)
      )
    )
  );

drop policy if exists "Personnel can update assigned requests" on public.requests;
create policy "Personnel can update assigned requests" on public.requests
  for update to authenticated
  using (
    public.current_user_role() = 'Personnel'
    and exists (
      select 1
      from jsonb_array_elements_text(
        case when jsonb_typeof(assigned_personnel) = 'array'
          then assigned_personnel else '[]'::jsonb end
      ) assigned(name)
      where public.is_current_assigned_personnel(assigned.name)
    )
  )
  with check (
    public.current_user_role() = 'Personnel'
    and exists (
      select 1
      from jsonb_array_elements_text(
        case when jsonb_typeof(assigned_personnel) = 'array'
          then assigned_personnel else '[]'::jsonb end
      ) assigned(name)
      where public.is_current_assigned_personnel(assigned.name)
    )
  );

create or replace function public.enforce_role_update_scope()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_table_name = 'reports'
    and new.status = 'resolved'
    and new.technician_state <> 'completed' then
    raise exception 'Reports can be resolved only after personnel completes the work';
  elsif tg_table_name = 'requests'
    and new.status = 'action-taken'
    and new.technician_state <> 'completed' then
    raise exception 'Requests can be acknowledged only after personnel completes the work';
  elsif public.current_user_role() = 'Personnel' and tg_table_name = 'reports' then
    if not exists (
      select 1
      from jsonb_array_elements_text(
        case when jsonb_typeof(old.assigned_personnel) = 'array'
          then old.assigned_personnel else '[]'::jsonb end
      ) assigned(name)
      where public.is_current_assigned_personnel(assigned.name)
    )
    or new.assigned_to is distinct from old.assigned_to
    or new.assigned_personnel is distinct from old.assigned_personnel
    or (new.technician_state = 'completed' and old.technician_state <> 'started')
    or to_jsonb(new) - array['status', 'technician_state', 'assignment_note', 'photo', 'photo_attachments']
       <> to_jsonb(old) - array['status', 'technician_state', 'assignment_note', 'photo', 'photo_attachments'] then
      raise exception 'Personnel may update only the state and completion photos of work assigned to them';
    end if;
    if old.status in ('closed', 'resolved', 'action-taken') then
      raise exception 'Closed work cannot be restarted by maintenance personnel';
    end if;
    if new.status is distinct from old.status or new.technician_state is distinct from old.technician_state then
      if not (
        (old.technician_state = 'assigned'
          and new.technician_state = 'accepted'
          and new.status = 'in-progress')
        or (old.technician_state = 'accepted'
          and new.technician_state = 'started'
          and old.status = 'in-progress'
          and new.status = 'in-progress')
        or (old.technician_state = 'started'
          and new.technician_state = 'completed'
          and old.status = 'in-progress'
          and new.status = 'for-verification')
      ) then
        raise exception 'Personnel work must follow assignment, acceptance, start, and verification in order';
      end if;
    end if;
  elsif public.current_user_role() = 'Employee' and tg_table_name = 'requests' then
    if old.status <> 'action-taken'
      or new.status <> old.status
      or to_jsonb(new) - array['feedback', 'feedback_date']
         <> to_jsonb(old) - array['feedback', 'feedback_date'] then
      raise exception 'Employees may update only feedback on acknowledged requests';
    end if;
  elsif public.current_user_role() = 'Personnel' and tg_table_name = 'requests' then
    if not exists (
      select 1
      from jsonb_array_elements_text(
        case when jsonb_typeof(old.assigned_personnel) = 'array'
          then old.assigned_personnel else '[]'::jsonb end
      ) assigned(name)
      where public.is_current_assigned_personnel(assigned.name)
    )
    or new.assigned_to is distinct from old.assigned_to
    or new.assigned_personnel is distinct from old.assigned_personnel
    or (new.technician_state = 'completed' and old.technician_state <> 'started')
    or to_jsonb(new) - array['status', 'technician_state', 'assignment_note', 'completion_photo', 'photo_attachments']
       <> to_jsonb(old) - array['status', 'technician_state', 'assignment_note', 'completion_photo', 'photo_attachments'] then
      raise exception 'Personnel may update only the state and completion photos of requests assigned to them';
    end if;
    if old.status in ('closed', 'resolved', 'action-taken') then
      raise exception 'Closed work cannot be restarted by maintenance personnel';
    end if;
    if new.status is distinct from old.status or new.technician_state is distinct from old.technician_state then
      if not (
        (old.technician_state = 'assigned'
          and new.technician_state = 'accepted'
          and new.status = 'in-progress')
        or (old.technician_state = 'accepted'
          and new.technician_state = 'started'
          and old.status = 'in-progress'
          and new.status = 'in-progress')
        or (old.technician_state = 'started'
          and new.technician_state = 'completed'
          and old.status = 'in-progress'
          and new.status = 'for-verification')
      ) then
        raise exception 'Personnel work must follow assignment, acceptance, start, and verification in order';
      end if;
    end if;
  elsif public.current_user_role() is distinct from 'Admin' then
    raise exception 'This role cannot update this record';
  end if;
  return new;
end;
$$;

revoke all on function public.enforce_role_update_scope() from public, anon, authenticated;
grant execute on function public.enforce_role_update_scope() to authenticated;

notify pgrst, 'reload schema';
