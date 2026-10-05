-- The shared update-scope trigger must only access email columns that exist
-- on the triggering work-item table.
do $$
declare
  function_definition text;
  revised_definition text;
  old_text text;
  new_text text;
begin
  function_definition := pg_get_functiondef('public.enforce_role_update_scope()'::regprocedure);
  old_text := $old$      or new.reporter_email is distinct from old.reporter_email
      or new.requester_email is distinct from old.requester_email then$old$;
  new_text := $new$      or (case
        when tg_table_name = 'reports'
          then new.reporter_email is distinct from old.reporter_email
        else new.requester_email is distinct from old.requester_email
      end) then$new$;

  if position(old_text in function_definition) = 0 then
    if position(new_text in function_definition) > 0 then
      return;
    end if;
    raise exception 'Could not locate the expected contact-email check in enforce_role_update_scope()';
  end if;

  revised_definition := replace(function_definition, old_text, new_text);
  if revised_definition = function_definition then
    raise exception 'Failed to update contact-email check in enforce_role_update_scope()';
  end if;
  execute revised_definition;
end
$$;
