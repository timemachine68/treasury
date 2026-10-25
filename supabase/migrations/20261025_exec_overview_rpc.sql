-- ภาพรวมสำหรับผู้บริหาร: ตัวเลขนับรวมทั้งระบบ (ไม่มีข้อมูลรายบุคคล)
-- เรียกได้เฉพาะ role = admin หรือ is_guidance = true
create or replace function public.exec_overview()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_ok boolean;
begin
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and (p.role = 'admin' or p.is_guidance = true)
  ) into v_ok;

  if not v_ok then
    raise exception 'ไม่มีสิทธิ์ดูภาพรวมนี้' using errcode = '42501';
  end if;

  return jsonb_build_object(
    'generated_at', now(),
    'modules', (
      select coalesce(jsonb_agg(to_jsonb(m) order by m.ord), '[]'::jsonb) from (
        select 'students' as module, 'นักเรียนในระบบ' as name, 'บัญชีนักเรียน' as measure, count(*)::int as n, 1 as ord from public.profiles where role = 'student'
        union all select 'teachers', 'ครูและผู้ดูแล', 'บัญชีครูและแอดมิน', count(*)::int, 2 from public.profiles where role in ('teacher','admin')
        union all select 'scholarship', 'ทุนการศึกษา', 'ใบสมัครทั้งหมด', count(*)::int, 3 from public.applications
        union all select 'scholarship_ok', 'ทุนการศึกษา', 'อนุมัติแล้ว', count(*)::int, 4 from public.applications where status::text = 'approved'
        union all select 'quota', 'โควตา', 'ใบสมัครทั้งหมด', count(*)::int, 5 from public.quota_applications
        union all select 'chang', 'โครงการช้างเผือก', 'ใบสมัครทั้งหมด', count(*)::int, 6 from public.chang_phueak_applications
        union all select 'awards', 'ผลงานนักเรียน (TCASVerified)', 'ผลงานที่บันทึก', count(*)::int, 7 from public.award_events
        union all select 'identity', 'ทะเบียนข้อมูลนักเรียน', 'นักเรียนที่ลงทะเบียนแล้ว', count(*)::int, 8 from public.student_identity
        union all select 'strength', 'ค้นจุดแข็ง', 'ครั้งที่ประเมิน', count(*)::int, 9 from public.strength_assessments
        union all select 'submissions', 'ส่งงานในคลังแนะแนว', 'งานที่ส่ง', count(*)::int, 10 from public.submissions
        union all select 'interview', 'ฝึกสัมภาษณ์', 'รอบที่ฝึก', count(*)::int, 11 from public.iv_sessions
        union all select 'counseling', 'บันทึกให้คำปรึกษา', 'บันทึกทั้งหมด', count(*)::int, 12 from public.counseling_logs
        union all select 'workpermit', 'หนังสืออนุญาตทำงาน', 'คำขอทั้งหมด', count(*)::int, 13 from public.work_permit_requests
        union all select 'mou', 'เอกสาร MOU', 'ฉบับที่บันทึก', count(*)::int, 14 from public.mou_agreements
      ) m
    ),
    'levels', (
      select coalesce(jsonb_agg(jsonb_build_object('level', l.level, 'n', l.n) order by l.level), '[]'::jsonb) from (
        select left(coalesce(class_room, '-'), 3) as level, count(*)::int as n
        from public.profiles where role = 'student' group by 1
      ) l
    ),
    'app_status', (
      select coalesce(jsonb_agg(to_jsonb(a) order by a.ord, a.n desc), '[]'::jsonb) from (
        select 'ทุนการศึกษา' as sys,
               case status::text when 'approved' then 'อนุมัติแล้ว' when 'shortlisted' then 'อยู่ในรายชื่อพิจารณา' else status::text end as st,
               count(*)::int as n, 1 as ord
        from public.applications group by 2
        union all
        select 'โควตา',
               case status::text when 'submitted' then 'ส่งใบสมัครแล้ว' when 'under_review' then 'กำลังพิจารณา' when 'withdrawn' then 'ถอนใบสมัคร' else status::text end,
               count(*)::int, 2
        from public.quota_applications group by 2
        union all
        select 'ช้างเผือก',
               case status::text when 'submitted' then 'ส่งใบสมัครแล้ว' else status::text end,
               count(*)::int, 3
        from public.chang_phueak_applications group by 2
      ) a
    )
  );
end;
$$;

revoke all on function public.exec_overview() from public, anon;
grant execute on function public.exec_overview() to authenticated;
