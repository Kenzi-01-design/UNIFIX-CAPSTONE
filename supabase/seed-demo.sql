-- Demo/defense seed data only. Run manually against a disposable project.
-- The script is repeatable and deliberately creates overdue, open, assigned,
-- in-verification, completed, and rated work for the analytics dashboard.
insert into public.reports (
  id, title, description, category, location, reporter, reporter_email,
  report_date, priority, status, assigned_personnel, technician_state, created_at
)
values
  ('DEMO-SEED-RPT-01', 'Water leak by Library west restroom', 'Water pools near the west restroom entrance after use.', 'Plumbing', 'Library · Ground Floor · West Restroom', 'Prof. Reyes', 'prof.reyes@nvsu.edu.ph', to_char(now() - interval '23 days', 'Mon DD, YYYY'), 'urgent', 'pending', '[]'::jsonb, 'unassigned', now() - interval '23 days'),
  ('DEMO-SEED-RPT-02', 'Flickering lights in Engineering Lab 204', 'Several ceiling lights flicker during afternoon classes.', 'Electrical', 'Engineering Building · Floor 2 · Room 204', 'Prof. Santos', 'prof.santos@nvsu.edu.ph', to_char(now() - interval '18 days', 'Mon DD, YYYY'), 'high', 'in-progress', '["Juan dela Cruz"]'::jsonb, 'started', now() - interval '18 days'),
  ('DEMO-SEED-RPT-03', 'Air conditioner not cooling in Room 305', 'The unit runs but does not cool the classroom.', 'HVAC', 'Science Building · Floor 3 · Room 305', 'Anna Reyes', 'anna.reyes@nvsu.edu.ph', to_char(now() - interval '13 days', 'Mon DD, YYYY'), 'medium', 'for-verification', '["Maria Santos"]'::jsonb, 'completed', now() - interval '13 days'),
  ('DEMO-SEED-RPT-04', 'Broken chair armrest in Room 112', 'Replace or repair the damaged chair in the front row.', 'Furniture', 'Academic Classroom Building · Floor 1 · Room 112', 'Prof. Reyes', 'prof.reyes@nvsu.edu.ph', to_char(now() - interval '11 days', 'Mon DD, YYYY'), 'low', 'closed', '["Juan dela Cruz"]'::jsonb, 'completed', now() - interval '11 days'),
  ('DEMO-SEED-RPT-05', 'Network connection intermittent in Library', 'Several study-area devices lose Wi-Fi intermittently.', 'Network', 'Library · Ground Floor', 'IT Admin', 'it.admin@nvsu.edu.ph', to_char(now() - interval '9 days', 'Mon DD, YYYY'), 'high', 'in-progress', '["Maria Santos"]'::jsonb, 'started', now() - interval '9 days'),
  ('DEMO-SEED-RPT-06', 'Door lock sticks at Administration Office', 'The main office door lock needs repeated attempts to engage.', 'Security', 'Administration Building · Ground Floor', 'Campus Security', null, to_char(now() - interval '7 days', 'Mon DD, YYYY'), 'medium', 'pending', '[]'::jsonb, 'unassigned', now() - interval '7 days'),
  ('DEMO-SEED-RPT-07', 'Drainage grate blocked after rain', 'Leaves and sediment are blocking the path drain.', 'Civil', 'Gymnasium · East Entrance', 'Student Affairs', null, to_char(now() - interval '4 days', 'Mon DD, YYYY'), 'urgent', 'in-progress', '["Juan dela Cruz", "Maria Santos"]'::jsonb, 'started', now() - interval '4 days'),
  ('DEMO-SEED-RPT-08', 'Overflowing bin near Library west restroom', 'The bin is frequently full during the lunch period.', 'Sanitation', 'Library · Ground Floor · West Restroom', 'Prof. Santos', 'prof.santos@nvsu.edu.ph', to_char(now() - interval '2 days', 'Mon DD, YYYY'), 'low', 'closed', '["Maria Santos"]'::jsonb, 'completed', now() - interval '2 days')
on conflict (id) do update set
  title = excluded.title,
  description = excluded.description,
  category = excluded.category,
  location = excluded.location,
  reporter = excluded.reporter,
  reporter_email = excluded.reporter_email,
  report_date = excluded.report_date,
  priority = excluded.priority,
  status = excluded.status,
  assigned_personnel = excluded.assigned_personnel,
  technician_state = excluded.technician_state,
  created_at = excluded.created_at;

update public.reports
set due_at = case
      when id = 'DEMO-SEED-RPT-01' then now() - interval '2 days'
      when id = 'DEMO-SEED-RPT-07' then now() - interval '1 hour'
      else created_at + interval '3 days'
    end,
    completed_at = case
      when status = 'closed' then created_at + interval '1 day'
      when status = 'for-verification' then now() - interval '2 hours'
      else null
    end
where id like 'DEMO-SEED-RPT-%';

insert into public.requests (
  id, title, category, department, details, requester, requester_email,
  request_date, priority, status, assigned_personnel, technician_state, created_at
)
values
  ('DEMO-SEED-REQ-01', 'Replace faulty projector in Lecture Hall A', 'Equipment', 'College of Engineering', 'Projector shuts down after several minutes.', 'Prof. Reyes', 'prof.reyes@nvsu.edu.ph', to_char(now() - interval '16 days', 'Mon DD, YYYY'), 'high', 'in-progress', '["Juan dela Cruz"]'::jsonb, 'started', now() - interval '16 days'),
  ('DEMO-SEED-REQ-02', 'Repair office water dispenser', 'Plumbing', 'Campus Administration', 'Dispenser is leaking at the bottle connection.', 'Admin Assistant', 'admin.assistant@nvsu.edu.ph', to_char(now() - interval '8 days', 'Mon DD, YYYY'), 'medium', 'closed', '["Maria Santos"]'::jsonb, 'completed', now() - interval '8 days'),
  ('DEMO-SEED-REQ-03', 'Install additional power outlet', 'Electrical', 'Library', 'Add a safe outlet at the new service counter.', 'Library Staff', null, to_char(now() - interval '3 days', 'Mon DD, YYYY'), 'low', 'submitted', '[]'::jsonb, 'unassigned', now() - interval '3 days')
on conflict (id) do update set
  title = excluded.title,
  category = excluded.category,
  department = excluded.department,
  details = excluded.details,
  requester = excluded.requester,
  requester_email = excluded.requester_email,
  request_date = excluded.request_date,
  priority = excluded.priority,
  status = excluded.status,
  assigned_personnel = excluded.assigned_personnel,
  technician_state = excluded.technician_state,
  created_at = excluded.created_at;

update public.requests
set due_at = case when id = 'DEMO-SEED-REQ-01' then now() - interval '1 day' else created_at + interval '4 days' end,
    completed_at = case when status = 'closed' then created_at + interval '2 days' else null end
where id like 'DEMO-SEED-REQ-%';

insert into public.report_feedback (report_id, reporter_email, rating, comment)
values
  ('DEMO-SEED-RPT-04', 'prof.reyes@nvsu.edu.ph', 5, 'The repair was completed promptly.'),
  ('DEMO-SEED-RPT-08', 'prof.santos@nvsu.edu.ph', 4, 'Resolved; thank you for the quick response.')
on conflict (report_id) do update set
  reporter_email = excluded.reporter_email,
  rating = excluded.rating,
  comment = excluded.comment;
