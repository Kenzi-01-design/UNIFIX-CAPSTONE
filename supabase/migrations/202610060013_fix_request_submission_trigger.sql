create or replace function public.prepare_request_submission()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  profile_name text;
begin
  if auth.uid() is null or public.current_user_role() not in ('Admin', 'Employee') then
    return new;
  end if;

  profile_name := public.current_user_profile_name();
  if profile_name is null or btrim(profile_name) = '' then
    return new;
  end if;

  new.requester := profile_name;
  new.requester_email := auth.jwt() ->> 'email';
  new.status := 'submitted';
  new.risk := 'low';
  new.technician_state := 'unassigned';
  new.assigned_to := null;
  new.assigned_personnel := '[]'::jsonb;
  new.admin_response := null;
  new.admin_remark := null;

  return new;
end;
$$;

revoke all on function public.prepare_request_submission() from public, anon, authenticated;
