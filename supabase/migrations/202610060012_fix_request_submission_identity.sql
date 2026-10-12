drop policy if exists "Users can create own requests" on public.requests;
create policy "Users can create own requests" on public.requests
  for insert to authenticated
  with check (
    public.current_user_role() in ('Admin', 'Employee')
    and nullif(btrim(requester), '') is not null
    and lower(btrim(coalesce(requester_email, ''))) =
      lower(btrim(coalesce(auth.jwt() ->> 'email', '')))
    and nullif(btrim(auth.jwt() ->> 'email'), '') is not null
    and status = 'submitted'
    and risk = 'low'
    and technician_state = 'unassigned'
    and coalesce(assigned_to, '') = ''
    and assigned_personnel = '[]'::jsonb
    and admin_response is null
    and admin_remark is null
  );
