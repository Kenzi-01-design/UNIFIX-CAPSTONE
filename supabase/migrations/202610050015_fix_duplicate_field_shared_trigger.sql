-- enforce_role_update_scope() is shared by reports and requests. Requests do
-- not have duplicate_of, so access this optional report-only field via JSON.
do $$
declare
  function_definition text;
  revised_definition text;
begin
  function_definition := pg_get_functiondef('public.enforce_role_update_scope()'::regprocedure);
  revised_definition := replace(function_definition, 'new.duplicate_of', '(to_jsonb(new) ->> ''duplicate_of'')');
  revised_definition := replace(revised_definition, 'old.duplicate_of', '(to_jsonb(old) ->> ''duplicate_of'')');

  if revised_definition = function_definition then
    if function_definition like '%duplicate_of%' then
      raise exception 'Could not safely update duplicate_of references in enforce_role_update_scope()';
    end if;
    return;
  end if;

  execute revised_definition;
end
$$;

notify pgrst, 'reload schema';
