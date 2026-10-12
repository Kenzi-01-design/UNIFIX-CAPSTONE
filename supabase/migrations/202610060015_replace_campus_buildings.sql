with requested_buildings(building) as (
  values
    ('Oval'),
    ('Gymnasium'),
    ('Boys Dorm'),
    ('Ladies Dorm'),
    ('Motorpool'),
    ('5 Star CR'),
    ('Food Court'),
    ('Alumni Bldg'),
    ('Administration Bldg'),
    ('College of Arts & Sciences Bldg'),
    ('Campus Quadrangle'),
    ('College of Teacher Education Bldg'),
    ('Boys Shop Building'),
    ('ROTC Building'),
    ('Rotary'),
    ('ROTC Bldg'),
    ('Mechanical Engineering Laboratory Bldg'),
    ('Engineering Science Lab Bldg'),
    ('Academic Classroom Bldg'),
    ('Engineering Bldg'),
    ('Stalls'),
    ('Graphic Arts & Bldg'),
    ('Technology Lab Bldg'),
    ('IT Lab Bldg'),
    ('RAC Bldg'),
    ('Auto Service Center'),
    ('Technician Institute'),
    ('CBA Bldg'),
    ('Cafeteria'),
    ('HRM Bldg'),
    ('Training Center')
)
update public.locations location
set building = requested.building,
    is_active = true,
    updated_at = now()
from requested_buildings requested
where lower(btrim(location.building)) = lower(requested.building);

with requested_buildings(building) as (
  values
    ('Oval'),
    ('Gymnasium'),
    ('Boys Dorm'),
    ('Ladies Dorm'),
    ('Motorpool'),
    ('5 Star CR'),
    ('Food Court'),
    ('Alumni Bldg'),
    ('Administration Bldg'),
    ('College of Arts & Sciences Bldg'),
    ('Campus Quadrangle'),
    ('College of Teacher Education Bldg'),
    ('Boys Shop Building'),
    ('ROTC Building'),
    ('Rotary'),
    ('ROTC Bldg'),
    ('Mechanical Engineering Laboratory Bldg'),
    ('Engineering Science Lab Bldg'),
    ('Academic Classroom Bldg'),
    ('Engineering Bldg'),
    ('Stalls'),
    ('Graphic Arts & Bldg'),
    ('Technology Lab Bldg'),
    ('IT Lab Bldg'),
    ('RAC Bldg'),
    ('Auto Service Center'),
    ('Technician Institute'),
    ('CBA Bldg'),
    ('Cafeteria'),
    ('HRM Bldg'),
    ('Training Center')
)
update public.locations location
set is_active = false,
    updated_at = now()
where location.is_active
  and not exists (
    select 1
    from requested_buildings requested
    where lower(btrim(location.building)) = lower(requested.building)
  );

with requested_buildings(building) as (
  values
    ('Oval'),
    ('Gymnasium'),
    ('Boys Dorm'),
    ('Ladies Dorm'),
    ('Motorpool'),
    ('5 Star CR'),
    ('Food Court'),
    ('Alumni Bldg'),
    ('Administration Bldg'),
    ('College of Arts & Sciences Bldg'),
    ('Campus Quadrangle'),
    ('College of Teacher Education Bldg'),
    ('Boys Shop Building'),
    ('ROTC Building'),
    ('Rotary'),
    ('ROTC Bldg'),
    ('Mechanical Engineering Laboratory Bldg'),
    ('Engineering Science Lab Bldg'),
    ('Academic Classroom Bldg'),
    ('Engineering Bldg'),
    ('Stalls'),
    ('Graphic Arts & Bldg'),
    ('Technology Lab Bldg'),
    ('IT Lab Bldg'),
    ('RAC Bldg'),
    ('Auto Service Center'),
    ('Technician Institute'),
    ('CBA Bldg'),
    ('Cafeteria'),
    ('HRM Bldg'),
    ('Training Center')
)
insert into public.locations (building)
select requested.building
from requested_buildings requested
where not exists (
  select 1
  from public.locations location
  where lower(btrim(location.building)) = lower(requested.building)
);
