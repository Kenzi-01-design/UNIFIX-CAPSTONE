create index if not exists reports_created_at_idx on public.reports (created_at desc);
create index if not exists reports_status_created_at_idx on public.reports (status, created_at desc);
create index if not exists reports_due_at_open_idx on public.reports (due_at)
  where due_at is not null and status not in ('closed', 'resolved', 'action-taken');
create index if not exists reports_assigned_to_idx on public.reports (assigned_to)
  where assigned_to is not null;
create index if not exists requests_created_at_idx on public.requests (created_at desc);
create index if not exists requests_status_created_at_idx on public.requests (status, created_at desc);
create index if not exists requests_due_at_open_idx on public.requests (due_at)
  where due_at is not null and status not in ('closed', 'resolved', 'action-taken');
create index if not exists requests_assigned_to_idx on public.requests (assigned_to)
  where assigned_to is not null;
create index if not exists maintenance_schedules_active_due_idx
  on public.maintenance_schedules (next_due) where is_active;
create index if not exists user_profiles_active_role_idx
  on public.user_profiles (role) where is_active;
create index if not exists user_profiles_email_lower_idx
  on public.user_profiles (lower(email));
