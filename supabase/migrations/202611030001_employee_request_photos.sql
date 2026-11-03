-- Let employees view photos for their own requisitions, including photos uploaded
-- by assigned personnel, and allow up to three before-work plus three after-work photos.
drop policy if exists "Employees can read photos for own requests" on storage.objects;
create policy "Employees can read photos for own requests" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'report-photos'
    and public.current_user_role() = 'Employee'
    and (storage.foldername(name))[2] = 'requests'
    and exists (
      select 1
      from public.requests request
      where request.id in (
        replace((storage.foldername(name))[3], '%23', '#'),
        '#' || replace((storage.foldername(name))[3], '%23', '#')
      )
      and lower(request.requester_email) = lower(auth.jwt() ->> 'email')
    )
  );

create or replace function public.validate_work_item_input()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  content_changed boolean;
begin
  if tg_table_name = 'reports' then
    if tg_op = 'INSERT' then
      content_changed := true;
    else
      content_changed := new.description is distinct from old.description;
    end if;
    if char_length(btrim(coalesce(new.title, ''))) not between 1 and 160
      or char_length(coalesce(new.description, '')) > 4000
      or (content_changed
        and char_length(btrim(coalesce(new.description, ''))) not between 1 and 4000)
      or char_length(btrim(coalesce(new.category, ''))) not between 1 and 80
      or char_length(btrim(coalesce(new.location, ''))) not between 1 and 300
      or char_length(btrim(coalesce(new.reporter, ''))) not between 1 and 120
      or (new.reporter_email is not null and (
        char_length(new.reporter_email) > 254
        or new.reporter_email !~* '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
      )) then
      raise exception 'The report contains invalid or oversized fields';
    end if;
  else
    if tg_op = 'INSERT' then
      content_changed := true;
    else
      content_changed := new.details is distinct from old.details;
    end if;
    if char_length(btrim(coalesce(new.title, ''))) not between 1 and 160
      or char_length(btrim(coalesce(new.category, ''))) not between 1 and 80
      or char_length(btrim(coalesce(new.department, ''))) not between 1 and 300
      or char_length(coalesce(new.details, '')) > 4000
      or (content_changed
        and char_length(btrim(coalesce(new.details, ''))) not between 1 and 4000)
      or char_length(btrim(coalesce(new.requester, ''))) not between 1 and 120
      or (new.requester_email is not null and (
        char_length(new.requester_email) > 254
        or new.requester_email !~* '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
      )) then
      raise exception 'The request contains invalid or oversized fields';
    end if;
  end if;

  if jsonb_typeof(coalesce(new.photo_attachments, '[]'::jsonb)) <> 'array' then
    raise exception 'Photo attachments must be a list';
  end if;
  if jsonb_array_length(coalesce(new.photo_attachments, '[]'::jsonb)) > 6
    or (
      select count(*)
      from jsonb_array_elements(coalesce(new.photo_attachments, '[]'::jsonb)) as photos(photo)
      where coalesce(photo ->> 'phase', 'before') <> 'after'
    ) > 3
    or (
      select count(*)
      from jsonb_array_elements(coalesce(new.photo_attachments, '[]'::jsonb)) as photos(photo)
      where photo ->> 'phase' = 'after'
    ) > 3 then
    raise exception 'Attach no more than three photos per work phase (six total)';
  end if;
  return new;
end;
$$;

revoke all on function public.validate_work_item_input() from public, anon, authenticated;
