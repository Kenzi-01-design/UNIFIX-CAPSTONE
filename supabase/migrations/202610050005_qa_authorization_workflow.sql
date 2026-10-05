-- Tighten role-scoped reads and work-item state transitions found during QA.

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
        and profile.role = 'Personnel'
        and lower(btrim(profile.name)) = lower(btrim(coalesce(p_name, '')))
    )
    and exists (
      select 1
      from public.user_profiles profile
      where profile.is_active
        and profile.role = 'Personnel'
        and lower(profile.email) = lower(auth.jwt() ->> 'email')
        and lower(btrim(profile.name)) = lower(btrim(coalesce(p_name, '')))
    );
$$;
revoke all on function public.is_current_assigned_personnel(text) from public, anon;
grant execute on function public.is_current_assigned_personnel(text) to authenticated;

create or replace function public.create_work_item_notification(
  p_email text,
  p_event_type text,
  p_title text,
  p_message text,
  p_entity_type text,
  p_entity_id text,
  p_tracking_code text default null,
  p_sms_message text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_email text := lower(btrim(coalesce(p_email, '')));
  inapp_enabled boolean;
  email_enabled boolean;
  sms_enabled boolean;
  phone_number text;
  item_updated_at timestamptz;
  event_key text;
begin
  if normalized_email = '' then return; end if;

  if p_entity_type = 'report' then
    select updated_at into item_updated_at from public.reports where id = p_entity_id;
  elsif p_entity_type = 'request' then
    select updated_at into item_updated_at from public.requests where id = p_entity_id;
  end if;
  event_key := md5(concat_ws('|',
    normalized_email, p_event_type, p_entity_type, p_entity_id,
    coalesce(p_tracking_code, ''), coalesce(item_updated_at::text, ''),
    coalesce(p_title, ''), coalesce(p_message, '')
  ));

  select coalesce(preferences.inapp_notifications, true),
    coalesce(preferences.email_notifications, true),
    coalesce(preferences.sms_notifications, false),
    nullif(btrim(profile.phone), '')
  into inapp_enabled, email_enabled, sms_enabled, phone_number
  from public.user_profiles profile
  left join public.user_preferences preferences
    on lower(preferences.user_email) = lower(profile.email)
  where lower(profile.email) = normalized_email
    and profile.is_active
  limit 1;

  if inapp_enabled then
    insert into public.notifications (
      user_email, event_type, title, message, entity_type, entity_id, tracking_code, dedupe_key
    )
    values (
      normalized_email, p_event_type, p_title, p_message, p_entity_type, p_entity_id,
      p_tracking_code, event_key || ':inapp'
    )
    on conflict (dedupe_key) do nothing;
  end if;

  if coalesce(email_enabled, true) then
    insert into public.notification_deliveries (
      channel, recipient, subject, body, event_type, entity_type, entity_id, tracking_code, dedupe_key
    )
    values (
      'email', normalized_email, p_title,
      p_message || case when p_tracking_code is null then '' else E'\n\nTracking code: ' || p_tracking_code end,
      p_event_type, p_entity_type, p_entity_id, p_tracking_code, event_key || ':email'
    )
    on conflict (dedupe_key) do nothing;
  end if;

  if sms_enabled and phone_number is not null and p_sms_message is not null then
    insert into public.notification_deliveries (
      channel, recipient, body, event_type, entity_type, entity_id, tracking_code, dedupe_key
    )
    values (
      'sms', phone_number, p_sms_message, p_event_type, p_entity_type, p_entity_id,
      p_tracking_code, event_key || ':sms'
    )
    on conflict (dedupe_key) do nothing;
  end if;
end;
$$;
revoke all on function public.create_work_item_notification(text, text, text, text, text, text, text, text)
  from public, anon, authenticated;

drop policy if exists "Authenticated users can read reports" on public.reports;
create policy "Authenticated users can read reports" on public.reports
  for select to authenticated
  using (
    public.current_user_role() in ('Admin', 'Assistant')
    or (
      public.current_user_role() in ('Employee', 'Student')
      and lower(reporter_email) = lower(auth.jwt() ->> 'email')
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
            and public.is_current_assigned_personnel(assigned.personnel_name)
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
            and public.is_current_assigned_personnel(assigned.personnel_name)
          )
        )
      )
    )
  );

do $$
declare
  function_definition text;
  revised_definition text;
  old_text text;
  new_text text;
begin
  function_definition := pg_get_functiondef('public.enforce_role_update_scope()'::regprocedure);
  revised_definition := function_definition;

  old_text := $old$  close_status text;$old$;
  new_text := $new$  close_status text;
  allow_duplicate_status boolean := false;$new$;
  if length(revised_definition) - length(replace(revised_definition, old_text, '')) <> length(old_text) then
    raise exception 'QA workflow trigger did not contain exactly one duplicate-status variable target';
  end if;
  revised_definition := replace(revised_definition, old_text, new_text);
  if position(new_text in revised_definition) = 0 then
    raise exception 'QA workflow trigger duplicate-status variable was not added';
  end if;

  old_text := $old$  start_status := old.status;$old$;
  new_text := $new$  start_status := old.status;
  if tg_table_name = 'reports'
    and user_role = 'Admin'
    and new.status = 'resolved'
      and new.duplicate_of is distinct from old.duplicate_of
      and old.status not in ('closed', 'resolved', 'action-taken')
      and exists (
        select 1 from public.reports parent
        where parent.id = new.duplicate_of
          and parent.status not in ('closed', 'resolved', 'action-taken')
      ) then
    allow_duplicate_status := true;
  end if;$new$;
  if length(revised_definition) - length(replace(revised_definition, old_text, '')) <> length(old_text) then
    raise exception 'QA workflow trigger did not contain exactly one duplicate-status calculation target';
  end if;
  revised_definition := replace(revised_definition, old_text, new_text);
  if position(new_text in revised_definition) = 0 then
    raise exception 'QA workflow trigger duplicate-status calculation was not applied';
  end if;

  old_text := $old$  if auth.role() = 'service_role' then
    return new;
  end if;$old$;
  new_text := $new$  if auth.role() = 'service_role' then
    return new;
  end if;

  if tg_table_name = 'reports'
    and pg_trigger_depth() > 1
    and new.duplicate_of is not null
    and exists (
      select 1 from public.reports parent
      where parent.id = new.duplicate_of and parent.status = new.status
    ) then
    return new;
  end if;$new$;
  if length(revised_definition) - length(replace(revised_definition, old_text, '')) <> length(old_text) then
    raise exception 'QA workflow trigger did not contain exactly one duplicate propagation target';
  end if;
  revised_definition := replace(revised_definition, old_text, new_text);
  if position(new_text in revised_definition) = 0 then
    raise exception 'QA workflow trigger duplicate propagation guard was not applied';
  end if;

  old_text := $old$  if tg_table_name = 'reports' and new.status = 'resolved' and new.technician_state <> 'completed' then
    raise exception 'Reports can be completed only after personnel submits work for verification';
  elsif tg_table_name = 'requests' and new.status = 'action-taken' and new.technician_state <> 'completed' then
    raise exception 'Requests can be completed only after personnel submits work for verification';
  end if;$old$;
  new_text := $new$  if tg_table_name = 'reports' and new.status = 'resolved'
    and new.technician_state <> 'completed' and not allow_duplicate_status then
      raise exception 'Reports can be completed only after personnel submits work for verification';
  elsif tg_table_name = 'requests' and new.status = 'action-taken' and new.technician_state <> 'completed' then
    raise exception 'Requests can be completed only after personnel submits work for verification';
  end if;$new$;
  if length(revised_definition) - length(replace(revised_definition, old_text, '')) <> length(old_text) then
    raise exception 'QA workflow trigger did not contain exactly one duplicate-resolution guard target';
  end if;
  revised_definition := replace(revised_definition, old_text, new_text);
  if position(new_text in revised_definition) = 0 then
    raise exception 'QA workflow trigger duplicate-resolution guard was not applied';
  end if;

  old_text := $old$  if user_role in ('Admin', 'Assistant') then$old$;
  new_text := $new$  if user_role in ('Admin', 'Assistant') then
    if old.status in ('closed', 'resolved', 'action-taken')
      and (new.assigned_personnel is distinct from old.assigned_personnel
        or new.assigned_to is distinct from old.assigned_to
        or new.technician_state is distinct from old.technician_state) then
      raise exception 'Completed work cannot be assigned; use the requester reopen workflow';
    end if;$new$;
  if length(revised_definition) - length(replace(revised_definition, old_text, '')) <> length(old_text) then
    raise exception 'QA workflow trigger did not contain exactly one admin assignment guard target';
  end if;
  revised_definition := replace(revised_definition, old_text, new_text);
  if position(new_text in revised_definition) = 0 then
    raise exception 'QA workflow trigger admin assignment guard was not applied';
  end if;

  old_text := $old$where lower(assigned.name) = lower(($old$;
  new_text := $new$where public.is_current_assigned_personnel(assigned.name)
      and lower(assigned.name) = lower(($new$;
  if length(revised_definition) - length(replace(revised_definition, old_text, '')) <> length(old_text) then
    raise exception 'QA workflow trigger did not contain exactly one personnel identity guard target';
  end if;
  revised_definition := replace(revised_definition, old_text, new_text);
  if position(new_text in revised_definition) = 0 then
    raise exception 'QA workflow trigger personnel identity guard was not applied';
  end if;

  old_text := $old$    if new.status is distinct from old.status and new.status not in ('in-progress', 'for-verification') then
      raise exception 'Personnel cannot verify or close work';
    end if;
    return new;$old$;
  new_text := $new$    if old.status in ('closed', 'resolved', 'action-taken') then
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
    return new;$new$;
  if length(revised_definition) - length(replace(revised_definition, old_text, '')) <> length(old_text) then
    raise exception 'QA workflow trigger did not contain exactly one personnel transition target';
  end if;
  revised_definition := replace(revised_definition, old_text, new_text);
  if position(new_text in revised_definition) = 0 then
    raise exception 'QA workflow trigger personnel transition guard was not applied';
  end if;

  execute revised_definition;
end;
$$;
