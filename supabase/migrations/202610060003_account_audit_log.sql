create table if not exists public.account_audit_log (
  id bigint generated always as identity primary key,
  actor_auth_user_id uuid,
  actor_email text not null,
  action text not null,
  target_auth_user_id uuid,
  target_email text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists account_audit_log_created_at_idx
  on public.account_audit_log (created_at desc);
create index if not exists account_audit_log_target_idx
  on public.account_audit_log (target_auth_user_id, created_at desc);

alter table public.account_audit_log enable row level security;
revoke all on public.account_audit_log from public, anon, authenticated;
grant select on public.account_audit_log to authenticated;
grant insert, select on public.account_audit_log to service_role;

drop policy if exists "Admins can read account audit log" on public.account_audit_log;
create policy "Admins can read account audit log" on public.account_audit_log
  for select to authenticated
  using (public.current_user_role() = 'Admin');
