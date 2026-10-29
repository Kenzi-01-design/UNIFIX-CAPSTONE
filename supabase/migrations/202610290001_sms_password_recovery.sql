create table if not exists public.password_recovery_challenges (
  challenge_id uuid primary key,
  auth_user_id uuid not null unique references auth.users(id) on delete cascade,
  code_hash text not null,
  expires_at timestamptz not null,
  attempt_count integer not null default 0 check (attempt_count between 0 and 5),
  created_at timestamptz not null default now()
);

alter table public.password_recovery_challenges enable row level security;
revoke all on public.password_recovery_challenges from public, anon, authenticated;
grant all on public.password_recovery_challenges to service_role;

create or replace function public.consume_password_recovery_challenge(
  p_challenge_id uuid,
  p_code_hash text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  challenge public.password_recovery_challenges%rowtype;
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'Password recovery must be completed through the recovery service.';
  end if;

  select * into challenge
  from public.password_recovery_challenges
  where challenge_id = p_challenge_id
  for update;

  if not found then
    return null;
  end if;
  if challenge.expires_at <= now() or challenge.attempt_count >= 5 then
    delete from public.password_recovery_challenges
    where challenge_id = p_challenge_id;
    return null;
  end if;
  if challenge.code_hash is distinct from p_code_hash then
    update public.password_recovery_challenges
    set attempt_count = attempt_count + 1
    where challenge_id = p_challenge_id;
    return null;
  end if;

  delete from public.password_recovery_challenges
  where challenge_id = p_challenge_id;
  return challenge.auth_user_id;
end;
$$;

revoke all on function public.consume_password_recovery_challenge(uuid, text) from public, anon, authenticated;
grant execute on function public.consume_password_recovery_challenge(uuid, text) to service_role;
