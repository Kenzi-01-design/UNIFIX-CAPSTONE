drop policy if exists "Staff can read report photos" on storage.objects;
create policy "Staff can read report photos" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'report-photos'
    and (
      public.current_user_role() in ('Admin', 'Assistant')
      or (
        public.current_user_role() = 'Personnel'
        and (
          exists (
            select 1
            from public.reports report
            cross join lateral jsonb_array_elements_text(
              case when jsonb_typeof(report.assigned_personnel) = 'array'
                then report.assigned_personnel else '[]'::jsonb end
            ) assigned(personnel_name)
            where report.id in (
              case
                when (storage.foldername(name))[2] = 'reports' then replace((storage.foldername(name))[3], '%23', '#')
                when (storage.foldername(name))[1] = 'public'
                  and (storage.foldername(name))[2] = 'reports' then replace((storage.foldername(name))[3], '%23', '#')
                else null
              end,
              '#' || case
                when (storage.foldername(name))[2] = 'reports' then replace((storage.foldername(name))[3], '%23', '#')
                when (storage.foldername(name))[1] = 'public'
                  and (storage.foldername(name))[2] = 'reports' then replace((storage.foldername(name))[3], '%23', '#')
                else null
              end
            )
            and public.is_current_assigned_personnel(assigned.personnel_name)
          )
          or exists (
            select 1
            from public.requests request
            cross join lateral jsonb_array_elements_text(
              case when jsonb_typeof(request.assigned_personnel) = 'array'
                then request.assigned_personnel else '[]'::jsonb end
            ) assigned(personnel_name)
            where request.id in (
              case
                when (storage.foldername(name))[2] = 'requests' then replace((storage.foldername(name))[3], '%23', '#')
                when (storage.foldername(name))[1] = 'public'
                  and (storage.foldername(name))[2] = 'requests' then replace((storage.foldername(name))[3], '%23', '#')
                else null
              end,
              '#' || case
                when (storage.foldername(name))[2] = 'requests' then replace((storage.foldername(name))[3], '%23', '#')
                when (storage.foldername(name))[1] = 'public'
                  and (storage.foldername(name))[2] = 'requests' then replace((storage.foldername(name))[3], '%23', '#')
                else null
              end
            )
            and public.is_current_assigned_personnel(assigned.personnel_name)
          )
        )
      )
    )
  );
