do $$
declare
  function_definition text;
  revised_definition text;
  old_text text := $old$array['technician_state', 'assignment_note', 'completion_photo', 'photo_attachments']$old$;
  new_text text := $new$array['status', 'technician_state', 'assignment_note', 'completion_photo', 'photo_attachments']$new$;
begin
  function_definition := pg_get_functiondef('public.enforce_role_update_scope()'::regprocedure);
  if length(function_definition) - length(replace(function_definition, old_text, '')) <> length(old_text) * 2 then
    raise exception 'Expected request update field allowlist in enforce_role_update_scope() exactly twice';
  end if;

  revised_definition := replace(function_definition, old_text, new_text);
  if revised_definition = function_definition then
    raise exception 'Request status was not added to the Personnel update allowlist';
  end if;

  execute revised_definition;
end;
$$;

notify pgrst, 'reload schema';
