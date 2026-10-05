-- Shared triggers are attached to both reports and requests, which do not have
-- the same contact-email column. Read the row as JSON so absent fields resolve
-- to NULL instead of raising "record NEW has no field ...".
do $$
declare
  function_signature text;
  function_definition text;
  revised_definition text;
begin
  foreach function_signature in array array[
    'public.audit_work_item_changes()',
    'public.notify_work_item_changes()',
    'public.enforce_role_update_scope()'
  ]
  loop
    function_definition := pg_get_functiondef(function_signature::regprocedure);
    revised_definition := function_definition;
    revised_definition := replace(revised_definition, 'new.reporter_email', '(to_jsonb(new) ->> ''reporter_email'')');
    revised_definition := replace(revised_definition, 'old.reporter_email', '(to_jsonb(old) ->> ''reporter_email'')');
    revised_definition := replace(revised_definition, 'new.requester_email', '(to_jsonb(new) ->> ''requester_email'')');
    revised_definition := replace(revised_definition, 'old.requester_email', '(to_jsonb(old) ->> ''requester_email'')');

    if revised_definition <> function_definition then
      execute revised_definition;
    end if;
  end loop;
end
$$;

notify pgrst, 'reload schema';
