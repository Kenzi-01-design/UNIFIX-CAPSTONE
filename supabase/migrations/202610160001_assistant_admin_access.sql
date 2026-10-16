begin;

create or replace function public.has_admin_access()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.current_user_role() in ('Admin', 'Assistant');
$$;
revoke all on function public.has_admin_access() from public, anon;
grant execute on function public.has_admin_access() to authenticated;

create policy "Assistants full access to reports" on public.reports
  for all to authenticated
  using (public.current_user_role() = 'Assistant')
  with check (public.current_user_role() = 'Assistant');

create policy "Assistants full access to requests" on public.requests
  for all to authenticated
  using (public.current_user_role() = 'Assistant')
  with check (public.current_user_role() = 'Assistant');

create policy "Assistants full access to locations" on public.locations
  for all to authenticated
  using (public.current_user_role() = 'Assistant')
  with check (public.current_user_role() = 'Assistant');

create policy "Assistants full access to maintenance schedules" on public.maintenance_schedules
  for all to authenticated
  using (public.current_user_role() = 'Assistant')
  with check (public.current_user_role() = 'Assistant');

create policy "Assistants can read all login events" on public.login_events
  for select to authenticated
  using (public.current_user_role() = 'Assistant');

create policy "Assistants can read account audit log" on public.account_audit_log
  for select to authenticated
  using (public.current_user_role() = 'Assistant');

create policy "Assistants can read reapplication requests" on public.account_reapplication_requests
  for select to authenticated
  using (public.current_user_role() = 'Assistant');

create policy "Assistants can read all profiles" on public.user_profiles
  for select to authenticated
  using (public.current_user_role() = 'Assistant');

create policy "Assistants can update profiles" on public.user_profiles
  for update to authenticated
  using (public.current_user_role() = 'Assistant')
  with check (public.current_user_role() = 'Assistant');

create policy "Assistants can read work item activity"
  on public.work_item_activity
  for select to authenticated
  using (public.current_user_role() = 'Assistant');

do $$
begin
  if to_regclass('public.audit_log') is not null then
    execute 'create policy "Assistants can read global audit log" on public.audit_log
      for select to authenticated using (public.current_user_role() = ''Assistant'')';
  end if;
end;
$$;

do $$
declare
  patch record;
  function_oid regprocedure;
  definition text;
  revised_definition text;
  occurrence_count integer;
begin
  for patch in
    select * from (values
      (
        'public.enforce_profile_update_scope()',
        $old$and public.current_user_role() is distinct from 'Admin'$old$,
        $new$and not public.has_admin_access()$new$
      ),
      (
        'public.enforce_role_update_scope()',
        $old$elsif public.current_user_role() is distinct from 'Admin' then$old$,
        $new$elsif not public.has_admin_access() then$new$
      ),
      (
        'public.enforce_user_profile_state_transition()',
        $old$admin_call boolean := public.current_user_role() = 'Admin';$old$,
        $new$admin_call boolean := public.has_admin_access();$new$
      ),
      (
        'public.enforce_user_profile_state_transition()',
        $old$if old.role = 'Admin' and old.is_active$old$,
        $new$if not service_call and not bootstrap_call
    and (
      old.auth_user_id = auth.uid()
      or (
        old.auth_user_id is null
        and lower(btrim(old.email)) = lower(btrim(coalesce(auth.jwt() ->> 'email', '')))
      )
    )
    and (
      new.role is distinct from old.role
      or new.is_active is distinct from old.is_active
    ) then
    raise exception 'You cannot change your own role or account access.';
  end if;

  if old.role = 'Admin' and old.is_active$new$
      ),
      (
        'public.reopen_rejected_registration(text)',
        $old$if public.current_user_role() is distinct from 'Admin' then$old$,
        $new$if not public.has_admin_access() then$new$
      ),
      (
        'public.get_admin_login_history()',
        $old$public.current_user_role() is distinct from 'Admin'$old$,
        $new$not public.has_admin_access()$new$
      ),
      (
        'public.merge_duplicate_reports(text, text)',
        $old$coalesce(public.current_user_role(), '') <> 'Admin'$old$,
        $new$not public.has_admin_access()$new$
      ),
      (
        'public.get_evaluation_summary()',
        $old$coalesce(public.current_user_role(), '') <> 'Admin'$old$,
        $new$not public.has_admin_access()$new$
      ),
      (
        'public.generate_due_maintenance_work_orders()',
        $old$coalesce(public.current_user_role(), '') <> 'Admin'$old$,
        $new$not public.has_admin_access()$new$
      ),
      (
        'public.notify_pending_account_registration()',
        $old$where role = 'Admin' and is_active$old$,
        $new$where role in ('Admin', 'Assistant') and is_active$new$
      )
    ) as patches(signature, old_text, new_text)
  loop
    function_oid := to_regprocedure(patch.signature);
    if function_oid is null then
      raise exception 'Assistant permission migration requires function %', patch.signature;
    end if;

    definition := pg_get_functiondef(function_oid);
    occurrence_count :=
      (length(definition) - length(replace(definition, patch.old_text, '')))
      / length(patch.old_text);
    if occurrence_count <> 1 then
      raise exception 'Expected one permission target in %, found %', patch.signature, occurrence_count;
    end if;

    revised_definition := replace(definition, patch.old_text, patch.new_text);
    execute revised_definition;
  end loop;

  function_oid := to_regprocedure('public.enforce_role_update_scope()');
  definition := pg_get_functiondef(function_oid);
  occurrence_count :=
    (length(definition) - length(replace(definition, $old$and user_role = 'Admin'$old$, '')))
    / length($old$and user_role = 'Admin'$old$);
  if occurrence_count > 1 then
    raise exception 'Expected at most one duplicate-resolution permission target, found %', occurrence_count;
  elsif occurrence_count = 1 then
    revised_definition := replace(
      definition,
      $old$and user_role = 'Admin'$old$,
      $new$and user_role in ('Admin', 'Assistant')$new$
    );
    execute revised_definition;
  end if;
end;
$$;

notify pgrst, 'reload schema';

commit;
