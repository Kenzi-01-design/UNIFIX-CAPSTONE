alter table public.user_preferences
  add column if not exists notification_email text,
  add column if not exists notification_email_verified boolean not null default false;

create extension if not exists pgcrypto with schema extensions;

alter table public.user_preferences
  alter column email_notifications set default false;

update public.user_preferences
set email_notifications = false
where notification_email_verified = false;

create table if not exists public.notification_email_verifications (
  auth_user_id uuid primary key references auth.users(id) on delete cascade,
  login_email text not null,
  notification_email text not null,
  token_hash text not null,
  requested_at timestamptz not null default now(),
  expires_at timestamptz not null,
  attempt_count integer not null default 0
);
alter table public.notification_email_verifications enable row level security;
revoke all on public.notification_email_verifications from public, anon, authenticated;
grant all on public.notification_email_verifications to service_role;

drop function if exists public.begin_notification_email_verification(text);
create or replace function public.begin_notification_email_verification(p_email text, p_auth_user_id uuid)
returns table (token text, notification_email text)
language plpgsql
security definer
set search_path = public
as $$
declare
  current_auth_user_id uuid := p_auth_user_id;
  login_email text;
  normalized_notification_email text := lower(btrim(coalesce(p_email, '')));
  token_value text;
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'Notification email verification must be requested through the verification service.';
  end if;
  select lower(btrim(auth_user.email)) into login_email
  from auth.users auth_user
  where auth_user.id = current_auth_user_id
    and auth_user.email is not null;
  if current_auth_user_id is null or login_email is null or not exists (
    select 1 from public.user_profiles profile
    where profile.auth_user_id = current_auth_user_id
      and profile.is_active
      and profile.registration_status = 'approved'
  ) then
    raise exception 'Sign in with an active, approved account to verify a notification email.';
  end if;
  if length(normalized_notification_email) > 254
    or normalized_notification_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
    raise exception 'Enter a valid notification email address.';
  end if;
  if exists (
    select 1 from public.notification_email_verifications verification
    where verification.auth_user_id = current_auth_user_id
      and verification.requested_at > now() - interval '1 minute'
  ) then
    raise exception 'Please wait one minute before requesting another verification email.';
  end if;

  token_value := replace(gen_random_uuid()::text, '-', '')
    || replace(gen_random_uuid()::text, '-', '')
    || replace(gen_random_uuid()::text, '-', '')
    || replace(gen_random_uuid()::text, '-', '');

  insert into public.notification_email_verifications (
    auth_user_id, login_email, notification_email, token_hash, requested_at, expires_at, attempt_count
  ) values (
    current_auth_user_id,
    login_email,
    normalized_notification_email,
    encode(extensions.digest(convert_to(token_value, 'UTF8'), 'sha256'), 'hex'),
    now(),
    now() + interval '30 minutes',
    0
  )
  on conflict (auth_user_id) do update
  set login_email = excluded.login_email,
      notification_email = excluded.notification_email,
      token_hash = excluded.token_hash,
      requested_at = excluded.requested_at,
      expires_at = excluded.expires_at,
      attempt_count = 0;

  insert into public.user_preferences (
    user_email, notification_email, notification_email_verified, email_notifications
  ) values (
    login_email, normalized_notification_email, false, false
  )
  on conflict (user_email) do update
  set notification_email = excluded.notification_email,
      notification_email_verified = false,
      email_notifications = false,
      updated_at = now();

  return query select token_value, normalized_notification_email;
end;
$$;
revoke all on function public.begin_notification_email_verification(text, uuid) from public, anon, authenticated;
grant execute on function public.begin_notification_email_verification(text, uuid) to service_role;

create or replace function public.complete_notification_email_verification(p_token_hash text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  verification public.notification_email_verifications%rowtype;
begin
  select * into verification
  from public.notification_email_verifications
  where token_hash = p_token_hash
  for update;
  if not found or verification.expires_at <= now() or verification.attempt_count >= 5 then
    raise exception 'This verification link is invalid or expired. Request a new one in Settings.';
  end if;

  update public.user_preferences
  set notification_email_verified = true,
      email_notifications = false,
      updated_at = now()
  where lower(user_email) = verification.login_email
    and lower(notification_email) = verification.notification_email;
  if not found then
    delete from public.notification_email_verifications
    where auth_user_id = verification.auth_user_id;
    raise exception 'The notification email changed. Request a new verification link in Settings.';
  end if;

  delete from public.notification_email_verifications
  where auth_user_id = verification.auth_user_id;
  return verification.notification_email;
end;
$$;
revoke all on function public.complete_notification_email_verification(text) from public, anon, authenticated;
grant execute on function public.complete_notification_email_verification(text) to service_role;

create or replace function public.enforce_notification_email_verification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    if tg_op = 'INSERT' then
      new.notification_email_verified := false;
      if new.notification_email is not null then
        new.email_notifications := false;
      end if;
      return new;
    end if;
    if new.notification_email_verified is distinct from old.notification_email_verified
      and new.notification_email_verified then
      raise exception 'Notification email verification must be completed through the verification link.';
    end if;
    if new.notification_email is distinct from old.notification_email then
      new.notification_email_verified := false;
      new.email_notifications := false;
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.enforce_notification_email_verification() from public, anon, authenticated;
drop trigger if exists enforce_notification_email_verification on public.user_preferences;
create trigger enforce_notification_email_verification
  before insert or update on public.user_preferences
  for each row execute function public.enforce_notification_email_verification();

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
  recipient_email text := normalized_email;
  inapp_enabled boolean;
  email_enabled boolean;
  notification_email_verified boolean;
  sms_enabled boolean;
  phone_number text;
  account_profile_active boolean;
  item_updated_at timestamptz;
  event_key text;
  account_profile_found boolean := false;
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

  select
    coalesce(preferences.inapp_notifications, true),
    coalesce(preferences.email_notifications, false),
    coalesce(preferences.notification_email_verified, false),
    coalesce(preferences.sms_notifications, false),
    nullif(btrim(profile.phone), ''),
    nullif(lower(btrim(preferences.notification_email)), ''),
    profile.is_active and profile.registration_status = 'approved'
  into
    inapp_enabled, email_enabled, notification_email_verified, sms_enabled, phone_number,
    recipient_email, account_profile_active
  from public.user_profiles profile
  left join public.user_preferences preferences
    on lower(preferences.user_email) = lower(profile.email)
  where lower(profile.email) = normalized_email
  limit 1;
  account_profile_found := found;

  if account_profile_found then
    inapp_enabled := coalesce(inapp_enabled, false) and account_profile_active;
    email_enabled := coalesce(email_enabled, false) and notification_email_verified and account_profile_active;
    sms_enabled := coalesce(sms_enabled, false) and account_profile_active;
    if not notification_email_verified or recipient_email is null then
      email_enabled := false;
    end if;
  else
    recipient_email := normalized_email;
    email_enabled := true;
  end if;

  if inapp_enabled then
    insert into public.notifications (
      user_email, event_type, title, message, entity_type, entity_id, tracking_code, dedupe_key
    ) values (
      normalized_email, p_event_type, p_title, p_message, p_entity_type, p_entity_id,
      p_tracking_code, event_key || ':inapp'
    )
    on conflict (dedupe_key) do nothing;
  end if;

  if coalesce(email_enabled, false) then
    insert into public.notification_deliveries (
      channel, recipient, subject, body, event_type, entity_type, entity_id, tracking_code, dedupe_key
    ) values (
      'email', recipient_email, p_title,
      p_message || case when p_tracking_code is null then '' else E'\n\nTracking code: ' || p_tracking_code end,
      p_event_type, p_entity_type, p_entity_id, p_tracking_code, event_key || ':email'
    )
    on conflict (dedupe_key) do nothing;
  end if;

  if sms_enabled and phone_number is not null and p_sms_message is not null then
    insert into public.notification_deliveries (
      channel, recipient, body, event_type, entity_type, entity_id, tracking_code, dedupe_key
    ) values (
      'sms', phone_number, p_sms_message, p_event_type, p_entity_type, p_entity_id,
      p_tracking_code, event_key || ':sms'
    )
    on conflict (dedupe_key) do nothing;
  end if;
end;
$$;
revoke all on function public.create_work_item_notification(text, text, text, text, text, text, text, text)
  from public, anon, authenticated;

notify pgrst, 'reload schema';
