do $$
begin
  if not exists (
    select 1
    from pg_publication_rel publication_table
    join pg_class relation_row on relation_row.oid = publication_table.prrelid
    join pg_namespace relation_schema on relation_schema.oid = relation_row.relnamespace
    join pg_publication publication_row on publication_row.oid = publication_table.prpubid
    where publication_row.pubname = 'supabase_realtime'
      and relation_schema.nspname = 'public'
      and relation_row.relname = 'user_profiles'
  ) then
    execute 'alter publication supabase_realtime add table public.user_profiles';
  end if;
end;
$$;

create or replace function public.notify_pending_account_registration()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  invited_at_value timestamptz;
  administrator record;
  new_user_id text := coalesce(new.auth_user_id::text, new.id);
begin
  if new.registration_status <> 'pending' or new.is_active then
    return new;
  end if;
  if tg_op = 'UPDATE' and old.registration_status is not distinct from new.registration_status then
    return new;
  end if;
  if tg_op = 'INSERT' then
    select invited_at into invited_at_value
    from auth.users
    where id = new.auth_user_id;
    if invited_at_value is not null then
      return new;
    end if;
  end if;

  for administrator in
    select auth_user_id, email
    from public.user_profiles
    where role = 'Admin' and is_active
  loop
    insert into public.notifications (
      user_email, event_type, title, message, dedupe_key
    ) values (
      administrator.email,
      'account_registration_pending',
      'New account awaiting approval',
      new.name || ' (' || new.email || ') submitted an account registration.',
      'account-registration-pending:' || new_user_id || ':' || coalesce(new.updated_at::text, now()::text)
        || ':' || coalesce(administrator.auth_user_id::text, lower(administrator.email))
    )
    on conflict (dedupe_key) do nothing;
  end loop;
  return new;
end;
$$;
revoke all on function public.notify_pending_account_registration() from public, anon, authenticated;
drop trigger if exists notify_pending_account_registration on public.user_profiles;
create trigger notify_pending_account_registration
  after insert or update of registration_status on public.user_profiles
  for each row execute function public.notify_pending_account_registration();

create or replace function public.notify_account_registration_decision()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  event_key text;
  notification_title text;
  notification_message text;
begin
  if new.registration_status is not distinct from old.registration_status
    or new.registration_status not in ('approved', 'rejected') then
    return new;
  end if;

  notification_title := case
    when new.registration_status = 'approved' then 'UNIFIX account approved'
    else 'UNIFIX registration decision'
  end;
  notification_message := case
    when new.registration_status = 'approved'
      then 'Your UNIFIX account has been approved. You can now sign in.'
    else 'Your UNIFIX registration was not approved.'
      || case when nullif(btrim(new.rejection_reason), '') is null
        then '' else ' Reason: ' || btrim(new.rejection_reason) end
  end;
  event_key := 'account-registration:' || coalesce(new.auth_user_id::text, new.id)
    || ':' || new.registration_status || ':' || coalesce(new.updated_at::text, now()::text);

  insert into public.notifications (
    user_email, event_type, title, message, dedupe_key
  ) values (
    new.email,
    'account_registration_' || new.registration_status,
    notification_title,
    notification_message,
    event_key || ':inapp'
  )
  on conflict (dedupe_key) do nothing;

  insert into public.notification_deliveries (
    channel, recipient, subject, body, event_type, dedupe_key
  ) values (
    'email',
    new.email,
    notification_title,
    notification_message,
    'account_registration_' || new.registration_status,
    event_key || ':email'
  )
  on conflict (dedupe_key) do nothing;
  return new;
end;
$$;
revoke all on function public.notify_account_registration_decision() from public, anon, authenticated;
drop trigger if exists notify_account_registration_decision on public.user_profiles;
create trigger notify_account_registration_decision
  after update of registration_status on public.user_profiles
  for each row execute function public.notify_account_registration_decision();
