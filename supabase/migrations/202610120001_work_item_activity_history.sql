begin;

create table if not exists public.work_item_activity (
  id bigint generated always as identity primary key,
  entity_type text not null check (entity_type in ('report', 'request')),
  entity_id text not null,
  tracking_code text,
  entity_title text not null,
  submitter_email text,
  action text not null,
  current_status text,
  summary text not null,
  actor_name text,
  actor_email text,
  actor_role text,
  old_value jsonb,
  new_value jsonb,
  created_at timestamptz not null default now()
);

create index if not exists work_item_activity_created_at_idx
  on public.work_item_activity (created_at desc, id desc);
create index if not exists work_item_activity_entity_idx
  on public.work_item_activity (entity_type, entity_id, created_at desc);
create unique index if not exists work_item_activity_submission_idx
  on public.work_item_activity (entity_type, entity_id)
  where action = 'submitted';

alter table public.work_item_activity enable row level security;
alter table public.work_item_activity replica identity full;
revoke all on public.work_item_activity from public, anon, authenticated;
grant select on public.work_item_activity to authenticated;

drop policy if exists "Admins and submitters can read work item activity" on public.work_item_activity;
create policy "Admins and submitters can read work item activity"
  on public.work_item_activity
  for select to authenticated
  using (
    public.current_user_role() = 'Admin'
    or (
      submitter_email is not null
      and coalesce(auth.jwt() ->> 'email', '') <> ''
      and lower(submitter_email) = lower(auth.jwt() ->> 'email')
    )
  );

create or replace function public.capture_work_item_activity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  entity_kind text := case when tg_table_name = 'reports' then 'report' else 'request' end;
  item_record jsonb := to_jsonb(new);
  previous_record jsonb;
  item_name text;
  item_email text;
  submitter_email_value text;
  actor_name_value text;
  actor_email_value text;
  actor_role_value text;
  field_name text;
  old_snapshot jsonb;
  new_snapshot jsonb;
  action_value text;
  summary_value text;
begin
  item_name := coalesce(
    nullif(item_record ->> 'reporter', ''),
    nullif(item_record ->> 'requester', ''),
    'Unknown user'
  );
  item_email := coalesce(
    nullif(item_record ->> 'reporter_email', ''),
    nullif(item_record ->> 'requester_email', '')
  );
  submitter_email_value := item_email;
  actor_name_value := coalesce(nullif(public.current_user_profile_name(), ''), item_name);
  actor_email_value := coalesce(
    nullif(auth.jwt() ->> 'email', ''),
    item_email
  );
  actor_role_value := coalesce(
    public.current_user_role(),
    case when actor_email_value is null then 'Unknown' else 'Public' end
  );

  if tg_op = 'INSERT' then
    insert into public.work_item_activity (
      entity_type, entity_id, tracking_code, entity_title, submitter_email,
      action, current_status, summary, actor_name, actor_email, actor_role
    ) values (
      entity_kind, new.id, new.tracking_code, new.title, submitter_email_value,
      'submitted', new.status, initcap(entity_kind) || ' submitted',
      actor_name_value, actor_email_value, actor_role_value
    )
    on conflict (entity_type, entity_id) where action = 'submitted' do nothing;
    return new;
  end if;

  previous_record := to_jsonb(old);
  foreach field_name in array array[
    'status',
    'technician_state',
    'title',
    'description',
    'category',
    'location',
    'details',
    'department',
    'assigned_personnel',
    'assigned_to',
    'assignment_note',
    'target_date',
    'admin_response',
    'admin_remark',
    'photo_attachments',
    'completion_photo',
    'photo',
    'feedback',
    'rejection_reason',
    'reopen_reason'
  ]
  loop
    if previous_record -> field_name is not distinct from item_record -> field_name then
      continue;
    end if;
    if field_name = 'assigned_to'
      and previous_record -> 'assigned_personnel' is distinct from item_record -> 'assigned_personnel' then
      continue;
    end if;

    action_value := case field_name
      when 'status' then 'status_changed'
      when 'technician_state' then 'work_stage_changed'
      when 'title' then 'title_changed'
      when 'description' then 'description_changed'
      when 'category' then 'category_changed'
      when 'location' then 'location_changed'
      when 'details' then 'details_changed'
      when 'department' then 'department_changed'
      when 'assigned_personnel' then 'assignment_changed'
      when 'assigned_to' then 'assignment_changed'
      when 'assignment_note' then 'instructions_changed'
      when 'target_date' then 'target_date_changed'
      when 'admin_response' then 'response_changed'
      when 'admin_remark' then 'remark_changed'
      when 'photo_attachments' then 'photos_changed'
      when 'completion_photo' then 'completion_photo_changed'
      when 'photo' then 'photo_changed'
      when 'feedback' then 'feedback_changed'
      when 'rejection_reason' then 'rejection_reason_changed'
      when 'reopen_reason' then 'reopened'
      else 'updated'
    end;

    old_snapshot := previous_record -> field_name;
    new_snapshot := item_record -> field_name;
    if field_name in ('assigned_personnel', 'assigned_to') then
      old_snapshot := jsonb_build_object(
        'assigned_to', previous_record -> 'assigned_to',
        'assigned_personnel', previous_record -> 'assigned_personnel'
      );
      new_snapshot := jsonb_build_object(
        'assigned_to', item_record -> 'assigned_to',
        'assigned_personnel', item_record -> 'assigned_personnel'
      );
    elsif field_name in ('photo_attachments', 'completion_photo', 'photo') then
      old_snapshot := jsonb_build_object('present', previous_record -> field_name is not null
        and previous_record -> field_name <> 'null'::jsonb);
      new_snapshot := jsonb_build_object('present', item_record -> field_name is not null
        and item_record -> field_name <> 'null'::jsonb);
    end if;

    summary_value := case field_name
      when 'status' then 'Status changed from ' ||
        coalesce(previous_record ->> field_name, 'unknown') || ' to ' ||
        coalesce(item_record ->> field_name, 'unknown')
      when 'technician_state' then 'Work stage changed from ' ||
        coalesce(previous_record ->> field_name, 'unknown') || ' to ' ||
        coalesce(item_record ->> field_name, 'unknown')
      when 'title' then 'Title changed'
      when 'description' then 'Description changed'
      when 'category' then 'Category changed'
      when 'location' then 'Location changed'
      when 'details' then 'Details changed'
      when 'department' then 'Department changed'
      when 'assigned_personnel' then 'Assigned personnel changed'
      when 'assigned_to' then 'Assigned personnel changed'
      when 'reopen_reason' then 'Work item reopened'
      else initcap(replace(action_value, '_', ' '))
    end;

    insert into public.work_item_activity (
      entity_type, entity_id, tracking_code, entity_title, submitter_email,
      action, current_status, summary, actor_name, actor_email, actor_role,
      old_value, new_value
    ) values (
      entity_kind, new.id, new.tracking_code, new.title, submitter_email_value,
      action_value, new.status, summary_value, actor_name_value, actor_email_value,
      actor_role_value, old_snapshot, new_snapshot
    );
  end loop;

  return new;
end;
$$;

revoke all on function public.capture_work_item_activity() from public, anon, authenticated;

drop trigger if exists capture_report_activity on public.reports;
create trigger capture_report_activity
  after insert or update on public.reports
  for each row execute function public.capture_work_item_activity();
drop trigger if exists capture_request_activity on public.requests;
create trigger capture_request_activity
  after insert or update on public.requests
  for each row execute function public.capture_work_item_activity();

insert into public.work_item_activity (
  entity_type, entity_id, tracking_code, entity_title, submitter_email,
  action, current_status, summary, actor_name, actor_email, actor_role, created_at
)
select
  item.entity_type,
  item.id,
  item.tracking_code,
  item.title,
  nullif(item.item_email, ''),
  'submitted',
  item.status,
  initcap(item.entity_type) || ' submitted (prior updates were not recorded)',
  item.item_name,
  item.item_email,
  'Unknown',
  item.created_at
from (
  select 'report'::text as entity_type, id, tracking_code, title, status, reporter as item_name,
    to_jsonb(reports) ->> 'reporter_email' as item_email, created_at
  from public.reports
  union all
  select 'request'::text, id, tracking_code, title, status, requester,
    to_jsonb(requests) ->> 'requester_email', created_at
  from public.requests
) item
on conflict (entity_type, entity_id) where action = 'submitted' do nothing;

do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    raise exception 'Supabase Realtime publication is missing; enable Realtime for this Supabase project first';
  end if;

  if not exists (
    select 1
    from pg_publication_rel publication_table
    join pg_class relation on relation.oid = publication_table.prrelid
    join pg_namespace relation_schema on relation_schema.oid = relation.relnamespace
    join pg_publication publication on publication.oid = publication_table.prpubid
    where publication.pubname = 'supabase_realtime'
      and relation_schema.nspname = 'public'
      and relation.relname = 'work_item_activity'
  ) then
    alter publication supabase_realtime add table public.work_item_activity;
  end if;
end
$$;

notify pgrst, 'reload schema';

commit;
