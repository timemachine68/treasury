-- ย้อนกลับ: นิยาม student_profile_360 เดิม (ก่อนรวมภาพรวม 360°)
create or replace function public.student_profile_360(p_profile_id uuid)
returns jsonb
language plpgsql
stable security definer
set search_path to 'public', 'pg_temp'
as $$
declare
  v_p public.profiles%rowtype;
begin
  if not public.iv_is_staff() then
    raise exception 'ไม่มีสิทธิ์ใช้หน้านี้' using errcode = '42501';
  end if;
  select * into v_p from public.profiles where id = p_profile_id and role = 'student';
  if not found then return null; end if;

  return jsonb_build_object(
    'student', jsonb_build_object(
      'id', v_p.id, 'display_name', v_p.display_name, 'nickname', v_p.nickname,
      'student_id', v_p.student_id, 'class_room', v_p.class_room, 'status', v_p.status,
      'graduated_year', v_p.graduated_year, 'previous_school', v_p.previous_school),

    'year_rooms', coalesce((select jsonb_agg(jsonb_build_object('academic_year', y.academic_year, 'class_room', y.class_room) order by y.academic_year desc)
        from (select * from public.student_year_rooms where profile_id = p_profile_id order by academic_year desc limit 20) y), '[]'::jsonb),

    'awards', coalesce((select jsonb_agg(to_jsonb(a) order by a.end_date desc nulls last)
        from (select e.title, e.level::text as level, e.category::text as category, e.academic_year,
                     e.end_date, ap.prize_name
              from public.award_participants ap
              join public.award_events e on e.id = ap.event_id
              where ap.profile_id = p_profile_id and e.status = 'verified'
              order by e.end_date desc nulls last limit 200) a), '[]'::jsonb),

    'scholarships', coalesce((select jsonb_agg(to_jsonb(s) order by s.academic_year desc)
        from (select sc.name, sc.provider, sc.academic_year, ap.status::text as status,
                     public.scholarship_amount_for(sc.amount_per_grant, sc.amount_lower, sc.amount_upper, v_p.class_room) as amount
              from public.applications ap
              join public.scholarships sc on sc.id = ap.scholarship_id
              where ap.profile_id = p_profile_id and ap.status in ('approved', 'shortlisted')
              order by sc.academic_year desc limit 100) s), '[]'::jsonb),

    'quotas', coalesce((select jsonb_agg(to_jsonb(q) order by q.submitted_at desc nulls last)
        from (select qt.name, qt.university, qt.faculty, qa.applied_faculty, qa.applied_major,
                     qa.status::text as status, qa.rank, qa.disqualified, qa.submitted_at
              from public.quota_applications qa
              join public.quotas qt on qt.id = qa.quota_id
              where qa.profile_id = p_profile_id
              order by qa.submitted_at desc nulls last limit 100) q), '[]'::jsonb),

    'chang_phueak', coalesce((select jsonb_agg(to_jsonb(c) order by c.academic_year desc)
        from (select pg.academic_year, ca.track::text as track, ca.major_choice_1, ca.major_choice_2, ca.status::text as status
              from public.chang_phueak_applications ca
              join public.chang_phueak_programs pg on pg.id = ca.program_id
              where ca.profile_id = p_profile_id
              order by pg.academic_year desc limit 20) c), '[]'::jsonb),

    'surveys', coalesce((select jsonb_agg(jsonb_build_object(
          'title', r.title, 'grade', r.grade, 'academic_year', r.academic_year,
          'status', sr.status, 'institution', sr.institution, 'program', sr.program,
          'tcas_round', sr.tcas_round, 'submitted_at', sr.submitted_at,
          'admissions', coalesce((select jsonb_agg(jsonb_build_object(
                'institution', ad.institution, 'faculty', ad.faculty, 'major', ad.major,
                'campus', ad.campus, 'admit_round', ad.admit_round, 'is_chosen', ad.is_chosen)
                order by ad.is_chosen desc, ad.created_at)
              from public.survey_admissions ad where ad.response_id = sr.id), '[]'::jsonb))
          order by r.academic_year desc, sr.submitted_at desc nulls last)
        from public.survey_responses sr
        join public.survey_rounds r on r.id = sr.round_id
        where sr.student_id = p_profile_id), '[]'::jsonb),

    'work_permits', coalesce((select jsonb_agg(to_jsonb(w) order by w.created_at desc)
        from (select employer_name, job_description, work_start_date, work_end_date,
                     status::text as status, request_type::text as request_type, created_at
              from public.work_permit_requests where student_id = p_profile_id
              order by created_at desc limit 50) w), '[]'::jsonb),

    'work_experiences', coalesce((select jsonb_agg(to_jsonb(x) order by x.start_date desc nulls last)
        from (select job_title, start_date, end_date from public.student_work_experiences
              where student_id = p_profile_id order by start_date desc nulls last limit 50) x), '[]'::jsonb),

    'tgat', coalesce((select jsonb_agg(to_jsonb(t) order by t.completed_at desc)
        from (select percentage, correct_count, question_count, completed_at
              from public.tgat_prep_attempts where student_id = p_profile_id
              order by completed_at desc limit 20) t), '[]'::jsonb),

    'assignments', (
      select jsonb_build_object(
        'total', count(*),
        'done', count(*) filter (where s.id is not null),
        'late', coalesce(jsonb_agg(jsonb_build_object('title', a.title, 'due_at', a.due_at) order by a.due_at)
                  filter (where s.id is null and a.due_at < now()), '[]'::jsonb))
      from public.assignments a
      left join lateral (select su.id from public.submissions su
                         where su.assignment_id = a.id and su.student_id = p_profile_id limit 1) s on true
      where v_p.class_room is not null and v_p.class_room = any(a.class_rooms)),

    'cases', coalesce((select jsonb_agg(jsonb_build_object(
          'id', c.id, 'session_date', c.session_date, 'status', c.status, 'categories', c.categories,
          'counselor', coalesce(cp.display_name, 'ไม่ทราบชื่อครู'), 'note', c.note, 'other_detail', c.other_detail,
          'next_appointment_date', c.next_appointment_date, 'referral_to', c.referral_to, 'referral_note', c.referral_note)
          order by c.session_date desc, c.created_at desc)
        from (select * from public.counseling_logs
              where student_id = p_profile_id and deleted_at is null
              order by session_date desc, created_at desc limit 100) c
        left join public.profiles cp on cp.id = c.counselor_id), '[]'::jsonb)
  );
end $$;

revoke all on function public.student_profile_360(uuid) from public, anon;
grant execute on function public.student_profile_360(uuid) to authenticated;
