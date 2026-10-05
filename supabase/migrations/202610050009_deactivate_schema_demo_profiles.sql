update public.user_profiles
set is_active = false,
    updated_at = now()
where (id, lower(email)) in (
  ('admin-user', 'admin.user@nvsu.edu.ph'),
  ('admin-assistant', 'admin.assistant@nvsu.edu.ph'),
  ('employee-user', 'prof.reyes@nvsu.edu.ph'),
  ('student-user', 'student.user@nvsu.edu.ph'),
  ('personnel-user', 'juan.delacruz@nvsu.edu.ph'),
  ('personnel-maria', 'maria.santos@nvsu.edu.ph')
);
