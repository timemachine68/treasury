-- รวม "ภาพรวมนักเรียน 360°" (โมดัลใน index.html) เข้ากับ "โปรไฟล์นักเรียนรวม" (student-profile.html) — 13 พ.ย. 2569
-- เปลี่ยนจากเดิม:
--   • ทุนการศึกษา: แสดงทุกสถานะ (เดิมเฉพาะ approved/shortlisted) ให้ครบเท่าที่ภาพรวม 360° เคยแสดง
--   • ตัดโครงการช้างเผือกออกจากโปรไฟล์
--   • งานมอบหมาย: งานที่ไม่ระบุห้อง (class_rooms ว่าง) นับเป็นงานของทุกห้อง + ส่งรายการงานรายชิ้นพร้อมเนื้อหาที่ส่ง (ใช้คัดลอกให้ AI)
--   • เพิ่ม: ฝึกซ้อมสัมภาษณ์, ทะเบียนกลุ่มเปราะบาง (เฉพาะระดับความเร่งด่วน/สถานะยืนยัน), จุดแข็ง RIASEC, รางวัลที่ครูบันทึกเอง
-- สิทธิ์: เหมือนเดิม — iv_is_staff() (admin หรือครูที่ is_guidance) ซึ่งเป็นกลุ่มเดียวกับที่ RLS ของตารางเหล่านี้อนุญาตอยู่แล้ว
-- ไม่ดึงเลขบัตรประชาชน และไม่ดึงรายละเอียดฐานะครอบครัวของทะเบียนกลุ่มเปราะบาง

create or replace function public.student_profile_360(p_profile_id uuid)
returns jsonb
language plpgsql
stable security definer
set search_path to 'public', 'pg_temp'
as $function$
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
      'student_id', v_p.student_id, 'username', v_p.username, 'class_room', v_p.class_room, 'status', v_p.status,
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

    -- รางวัลที่ครู/นักเรียนบันทึกในระบบจุดแข็ง (strength_tags type='award', note = ชื่อ|ระดับ|ปี|หมายเหตุ)
    'award_tags', coalesce((select jsonb_agg(to_jsonb(t) order by t.created_at desc)
        from (select note, tagger_name, (tagged_by = student_id) as self_recorded, created_at
              from public.strength_tags
              where student_id = p_profile_id and type = 'award'
              order by created_at desc limit 200) t), '[]'::jsonb),

    'scholarships', coalesce((select jsonb_agg(to_jsonb(s) order by s.academic_year desc, s.submitted_at desc nulls last)
        from (select sc.name, sc.provider, sc.academic_year, ap.status::text as status, ap.submitted_at,
                     public.scholarship_amount_for(sc.amount_per_grant, sc.amount_lower, sc.amount_upper, v_p.class_room) as amount
              from public.applications ap
              join public.scholarships sc on sc.id = ap.scholarship_id
              where ap.profile_id = p_profile_id
              order by sc.academic_year desc, ap.submitted_at desc nulls last limit 100) s), '[]'::jsonb),

    'quotas', coalesce((select jsonb_agg(to_jsonb(q) order by q.submitted_at desc nulls last)
        from (select qt.name, qt.university, qt.faculty, qa.applied_faculty, qa.applied_major,
                     qa.status::text as status, qa.rank, qa.disqualified, qa.submitted_at
              from public.quota_applications qa
              join public.quotas qt on qt.id = qa.quota_id
              where qa.profile_id = p_profile_id
              order by qa.submitted_at desc nulls last limit 100) q), '[]'::jsonb),

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
        from (select percentage, correct_count, question_count, subjects, raw_score, max_score, completed_at
              from public.tgat_prep_attempts where student_id = p_profile_id
              order by completed_at desc limit 20) t), '[]'::jsonb),
    'tgat_total', (select count(*) from public.tgat_prep_attempts where student_id = p_profile_id),

    -- งานมอบหมาย: งานที่ไม่ระบุห้อง = ทุกห้อง (ตรงกับที่หน้าคลังงานแสดง)
    'assignments', (
      select jsonb_build_object(
        'total', count(*),
        'done', count(*) filter (where s.id is not null),
        'late', coalesce(jsonb_agg(jsonb_build_object('title', a.title, 'due_at', a.due_at) order by a.due_at)
                  filter (where s.id is null and a.due_at < now()), '[]'::jsonb),
        'items', coalesce(jsonb_agg(jsonb_build_object(
                    'title', a.title, 'due_at', a.due_at, 'submitted', s.id is not null,
                    'submitted_at', s.submitted_at, 'text_answer', s.text_answer,
                    'file_name', s.file_name, 'external_url', s.external_url)
                  order by a.due_at nulls last, a.created_at), '[]'::jsonb))
      from public.assignments a
      left join lateral (select su.id, su.submitted_at, su.text_answer, su.file_name, su.external_url
                         from public.submissions su
                         where su.assignment_id = a.id and su.student_id = p_profile_id
                         order by su.submitted_at desc limit 1) s on true
      where v_p.class_room is not null
        and (a.class_rooms is null or cardinality(a.class_rooms) = 0 or v_p.class_room = any(a.class_rooms))),

    'interviews', coalesce((select jsonb_agg(to_jsonb(i) order by i.at desc nulls last)
        from (select coalesce(c.name, 'ฝึกสัมภาษณ์') as category, c.emoji, s.kind, s.status,
                     coalesce(s.submitted_at, s.created_at) as at
              from public.iv_sessions s
              left join public.iv_categories c on c.id = s.category_id
              where s.student_id = p_profile_id
              order by coalesce(s.submitted_at, s.created_at) desc nulls last limit 50) i), '[]'::jsonb),

    -- ทะเบียนกลุ่มเปราะบาง: ส่งแค่ว่าอยู่ในทะเบียน + ระดับความเร่งด่วน + ยืนยันแล้วหรือยัง (ไม่ส่งรายได้/ข้อมูลครอบครัว)
    'vulnerable', (select jsonb_build_object('academic_year', v.academic_year, 'urgency_level', v.urgency_level,
                                             'verified', v.verified_at is not null)
        from public.vulnerable_profiles v where v.profile_id = p_profile_id
        order by v.academic_year desc nulls last, v.created_at desc limit 1),

    'strength', jsonb_build_object(
      'assessment', (select jsonb_build_object('scores', sa.scores, 'done_at', sa.done_at)
          from public.strength_assessments sa where sa.student_id = p_profile_id
          order by sa.done_at desc nulls last limit 1),
      'tags', coalesce((select jsonb_agg(to_jsonb(t) order by t.created_at desc)
          from (select type, note, tagger_name, created_at from public.strength_tags
                where student_id = p_profile_id and type in ('R','I','A','S','E','C')
                order by created_at desc limit 100) t), '[]'::jsonb)),

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
end $function$;

revoke all on function public.student_profile_360(uuid) from public, anon;
grant execute on function public.student_profile_360(uuid) to authenticated;
