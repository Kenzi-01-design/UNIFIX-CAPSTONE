do $$
declare
  old_location record;
  replacement_id uuid;
  replacement_building text;
begin
  for old_location in
    select id, building, floor, room
    from public.locations
    where position('Bldg' in building) > 0
    order by id
  loop
    replacement_building := replace(old_location.building, 'Bldg', 'Building');

    select id into replacement_id
    from public.locations
    where id <> old_location.id
      and lower(building) = lower(replacement_building)
      and lower(floor) = lower(old_location.floor)
      and lower(room) = lower(old_location.room)
    limit 1;

    if replacement_id is null then
      update public.locations
      set building = replacement_building,
          updated_at = now()
      where id = old_location.id;
    else
      update public.maintenance_schedules
      set location_id = replacement_id
      where location_id = old_location.id;

      delete from public.locations
      where id = old_location.id;
    end if;
  end loop;
end;
$$;

update public.reports
set location = replace(location, 'Bldg', 'Building')
where position('Bldg' in location) > 0;

update public.requests
set department = replace(department, 'Bldg', 'Building')
where position('Bldg' in department) > 0;
