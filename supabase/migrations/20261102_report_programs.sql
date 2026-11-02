-- รายงานผู้บริหารแบบรวม: ส่วนที่เพิ่มใหม่ (ทุน / หนังสือฝึกงาน / ซ้อมสัมภาษณ์ / MOU / แนะแนวรายคาบ / ให้คำปรึกษา)
-- คืนเฉพาะยอดรวม ไม่มีชื่อนักเรียน · เฉพาะ iv_is_staff() (แอดมิน + ครูแนะแนว)
-- ปีการศึกษา (พ.ศ.) เริ่ม 16 พ.ค. ของทุกปี ตรงกับ counseling_annual_report เดิม

-- ---------- 0) ตัวช่วยหาปีการศึกษาจากวันที่ ----------
create or replace function public.th_academic_year(t timestamptz)
returns int
language sql
stable
set search_path = public, pg_temp
as $$
  select (extract(year from (t at time zone 'Asia/Bangkok'))::int + 543)
       - case when (extract(month from (t at time zone 'Asia/Bangkok'))::int,
                    extract(day   from (t at time zone 'Asia/Bangkok'))::int) < (5, 16) then 1 else 0 end
$$;

-- ---------- 1) ทุน + หนังสือฝึกงาน + ซ้อมสัมภาษณ์ + MOU + แนะแนวรายคาบ ----------
-- SECURITY INVOKER: RLS ของตารางเดิมทำงานเต็ม + เช็ค iv_is_staff()
create or replace function public.report_programs(p_year text default null)
returns jsonb
language plpgsql
stable
security invoker
set search_path = public, pg_temp
as $$
declare
  v_year int;
  v_sum jsonb;
  v jsonb;
begin
  if not public.iv_is_staff() then
    raise exception 'ไม่มีสิทธิ์ดูรายงานนี้' using errcode = '42501';
  end if;

  v_year := case when coalesce(trim(p_year), '') ~ '^[0-9]{4}$' then trim(p_year)::int
                 else public.th_academic_year(now()) end;

  -- ยอดทุนที่ได้รับจริง (ตามชั้นของนักเรียน) จากฟังก์ชันเดิมของหน้าสรุปทุนประจำปี
  v_sum := coalesce((public.scholarship_annual_summary())::jsonb -> 'summary', '[]'::jsonb);

  with
  sm as (
    select (e->>'scholarship_id')::uuid sid, e->>'academic_year' ay, e->>'class_level' lv,
           coalesce((e->>'awarded_count')::int, 0) n, coalesce((e->>'total_amount')::numeric, 0) amt
    from jsonb_array_elements(v_sum) e
  ),
  sch as (select * from public.scholarships where academic_year = v_year::text and status::text <> 'draft'),
  app as (
    select a.scholarship_id, a.profile_id, a.status::text st
    from public.applications a join sch on sch.id = a.scholarship_id
  ),
  wp as (select r.*, public.th_academic_year(r.created_at) ay from public.work_permit_requests r),
  ivs as (select s.*, public.th_academic_year(s.created_at) ay from public.iv_sessions s),
  ivy as (select * from ivs where ay = v_year),
  ivd as (select * from ivy where status in ('submitted', 'reviewed'))
  select jsonb_build_object(
    'year', v_year,
    'years', (
      select coalesce(jsonb_agg(y order by y desc), '[]'::jsonb) from (
        select public.th_academic_year(now()) y
        union select academic_year::int from public.scholarships where academic_year ~ '^[0-9]{4}$'
        union select ay from wp
        union select ay from ivs
      ) t where y is not null),

    'scholarship', jsonb_build_object(
      'scholarships', (select count(*) from sch),
      'seats', (select coalesce(sum(quota), 0) from sch),
      'applications', (select count(*) from app where st <> 'withdrawn'),
      'applicants', (select count(distinct profile_id) from app where st <> 'withdrawn'),
      'awarded', (select coalesce(sum(n), 0) from sm where ay = v_year::text),
      'amount', (select coalesce(sum(amt), 0) from sm where ay = v_year::text),
      'awarded_lower', (select coalesce(sum(n), 0) from sm where ay = v_year::text and lv in ('ม.1', 'ม.2', 'ม.3')),
      'awarded_upper', (select coalesce(sum(n), 0) from sm where ay = v_year::text and lv in ('ม.4', 'ม.5', 'ม.6')),
      'amount_lower', (select coalesce(sum(amt), 0) from sm where ay = v_year::text and lv in ('ม.1', 'ม.2', 'ม.3')),
      'amount_upper', (select coalesce(sum(amt), 0) from sm where ay = v_year::text and lv in ('ม.4', 'ม.5', 'ม.6')),
      'by_scholarship', (
        select coalesce(jsonb_agg(jsonb_build_object(
            'name', s.name, 'provider', coalesce(nullif(trim(s.provider), ''), '-'), 'status', s.status::text,
            'seats', coalesce(s.quota, 0),
            'applicants', (select count(distinct profile_id) from app where app.scholarship_id = s.id and st <> 'withdrawn'),
            'awarded', (select coalesce(sum(n), 0) from sm where sm.sid = s.id),
            'amount', (select coalesce(sum(amt), 0) from sm where sm.sid = s.id))
          order by s.name), '[]'::jsonb) from sch s),
      'trend', (
        select coalesce(jsonb_agg(jsonb_build_object('year', ay, 'scholarships', nsch, 'awarded', n, 'amount', amt) order by ay), '[]'::jsonb)
        from (select x.academic_year ay,
                     (select count(*) from public.scholarships z where z.academic_year = x.academic_year and z.status::text <> 'draft') nsch,
                     coalesce(sum(sm.n), 0) n, coalesce(sum(sm.amt), 0) amt
              from (select distinct academic_year from public.scholarships where status::text <> 'draft' and academic_year is not null) x
              left join sm on sm.ay = x.academic_year
              group by x.academic_year) t)
    ),

    'workpermit', jsonb_build_object(
      'total', (select count(*) from wp where ay = v_year),
      'students', (select count(distinct student_id) from wp where ay = v_year),
      'cancelled', (select count(*) from wp where ay = v_year and status::text = 'cancelled'),
      'done', (select count(*) from wp where ay = v_year and status::text in ('ready', 'received')),
      'by_type', (select coalesce(jsonb_agg(jsonb_build_object('type', ty, 'n', n) order by n desc), '[]'::jsonb)
                  from (select request_type::text ty, count(*)::int n from wp where ay = v_year group by 1) t),
      'by_status', (select coalesce(jsonb_agg(jsonb_build_object('status', st, 'n', n) order by n desc), '[]'::jsonb)
                    from (select status::text st, count(*)::int n from wp where ay = v_year group by 1) t),
      'by_month', (select coalesce(jsonb_agg(jsonb_build_object('month', m, 'n', n) order by m), '[]'::jsonb)
                   from (select to_char(created_at at time zone 'Asia/Bangkok', 'YYYY-MM') m, count(*)::int n
                         from wp where ay = v_year group by 1) t),
      'trend', (select coalesce(jsonb_agg(jsonb_build_object('year', ay, 'n', n, 'students', ns) order by ay), '[]'::jsonb)
                from (select ay, count(*)::int n, count(distinct student_id)::int ns from wp group by 1) t)
    ),

    'interview', jsonb_build_object(
      'sessions', (select count(*) from ivy),
      'done', (select count(*) from ivd),
      'reviewed', (select count(*) from ivy where status = 'reviewed'),
      'draft', (select count(*) from ivy where status = 'draft'),
      'students', (select count(distinct student_id) from ivd),
      'by_status', (select coalesce(jsonb_agg(jsonb_build_object('status', st, 'n', n) order by n desc), '[]'::jsonb)
                    from (select status st, count(*)::int n from ivy group by 1) t),
      'criteria', (
        select coalesce(jsonb_agg(jsonb_build_object(
            'code', c.code, 'title', c.title,
            'teacher_avg', t.ta, 'teacher_n', t.tn, 'self_avg', t.sa, 'self_n', t.sn)
          order by c.sort_order), '[]'::jsonb)
        from public.iv_rubric_criteria c
        cross join lateral (
          select round((avg(sc.score) filter (where sc.scorer_role = 'teacher'))::numeric, 2) ta,
                 count(*) filter (where sc.scorer_role = 'teacher')::int tn,
                 round((avg(sc.score) filter (where sc.scorer_role = 'self'))::numeric, 2) sa,
                 count(*) filter (where sc.scorer_role = 'self')::int sn
          from public.iv_scores sc join ivy on ivy.id = sc.session_id
          where sc.criteria_id = c.id) t
        where c.is_active),
      'by_level', (select coalesce(jsonb_agg(jsonb_build_object('level', lv, 'students', n) order by lv), '[]'::jsonb)
                   from (select coalesce(nullif(split_part(p.class_room, '/', 1), ''), 'ไม่ระบุ') lv, count(distinct d.student_id)::int n
                         from ivd d left join public.profiles p on p.id = d.student_id group by 1) t),
      'by_category', (select coalesce(jsonb_agg(jsonb_build_object('name', nm, 'n', n) order by n desc, nm), '[]'::jsonb)
                      from (select coalesce(c.name, 'ไม่ระบุหมวด') nm, count(*)::int n
                            from ivd d left join public.iv_categories c on c.id = d.category_id group by 1) t),
      'trend', (select coalesce(jsonb_agg(jsonb_build_object('year', ay, 'sessions', n, 'students', ns) order by ay), '[]'::jsonb)
                from (select ay, count(*)::int n, count(distinct student_id)::int ns
                      from ivs where status in ('submitted', 'reviewed') group by 1) t)
    ),

    'mou', jsonb_build_object(
      'agreements', (select count(*) from public.mou_agreements),
      'active', (select count(*) from public.mou_agreements where status::text = 'active'),
      'pending', (select count(*) from public.mou_agreements where status::text = 'pending_signature'),
      'expired', (select count(*) from public.mou_agreements where status::text = 'expired'),
      'expiring', (select count(*) from public.mou_agreements
                   where status::text = 'active' and end_date between current_date and current_date + 90),
      'institutions', (select count(*) from public.mou_institutions),
      'signed_in_year', (select count(*) from public.mou_agreements
                         where signed_date is not null and public.th_academic_year(signed_date::timestamptz) = v_year),
      'by_type', (select coalesce(jsonb_agg(jsonb_build_object('type', ty, 'n', n) order by n desc), '[]'::jsonb)
                  from (select type::text ty, count(*)::int n from public.mou_institutions group by 1) t),
      'by_category', (select coalesce(jsonb_agg(jsonb_build_object('name', nm, 'n', n) order by n desc, nm), '[]'::jsonb)
                      from (select activity_category nm, count(*)::int n from public.mou_agreements
                            where nullif(trim(activity_category), '') is not null group by 1) t)
    ),

    'schedule', (
      select coalesce(jsonb_agg(jsonb_build_object(
          'level', g.level, 'weeks', g.weeks, 'assigned', g.assigned, 'institutions', g.insts,
          'grid', g.grid) order by g.level), '[]'::jsonb)
      from (select level, count(*)::int weeks,
                   count(*) filter (where nullif(trim(institution), '') is not null)::int assigned,
                   coalesce(jsonb_agg(trim(institution) order by week_no) filter (where nullif(trim(institution), '') is not null), '[]'::jsonb) insts,
                   jsonb_agg(jsonb_build_object('w', week_no, 'i', nullif(trim(institution), '')) order by week_no) grid
            from public.guidance_week_institutions group by level) g)
  ) into v;
  return v;
end;
$$;

-- ---------- 2) บันทึกให้คำปรึกษา (สรุปไม่ระบุชื่อ) ----------
-- SECURITY DEFINER เพราะ counseling_logs ให้ครูเห็นเฉพาะของตัวเอง; เช็คสิทธิ์ในฟังก์ชัน
-- กลุ่มที่มีน้อยกว่า 3 ราย ไม่แสดงรายกลุ่ม (รวมเป็นยอด "ไม่แสดง")
create or replace function public.report_counseling(p_year text default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_year int;
  v_start date;
  v_end date;
  v jsonb;
begin
  if not public.iv_is_staff() then
    raise exception 'ไม่มีสิทธิ์ดูรายงานนี้' using errcode = '42501';
  end if;

  v_year := case when coalesce(trim(p_year), '') ~ '^[0-9]{4}$' then trim(p_year)::int
                 else public.th_academic_year(now()) end;
  v_start := make_date(v_year - 543, 5, 16);
  v_end   := make_date(v_year - 543 + 1, 5, 15);

  with
  allx as (select cl.*, public.th_academic_year(cl.session_date::timestamptz) ay
           from public.counseling_logs cl where cl.deleted_at is null),
  l as (
    select a.id, a.student_id, a.categories, coalesce(nullif(trim(a.status), ''), 'ไม่ระบุ') status, a.session_date, p.class_room
    from allx a left join public.profiles p on p.id = a.student_id
    where a.ay = v_year
  ),
  cats as (select cat, count(*)::int n from l, unnest(l.categories) cat group by cat),
  sts as (select status st, count(*)::int n from l group by 1),
  lvl as (select case when split_part(class_room, '/', 1) in ('ม.1', 'ม.2', 'ม.3') then 'ม.ต้น'
                      when split_part(class_room, '/', 1) in ('ม.4', 'ม.5', 'ม.6') then 'ม.ปลาย'
                      else 'ไม่ระบุ' end lv, count(*)::int n from l group by 1)
  select jsonb_build_object(
    'year', v_year,
    'min_group', 3,
    'total_cases', (select count(*) from l),
    'students', (select count(distinct student_id) from l),
    'open_cases', (select count(*) from l where status in ('ติดตามต่อ', 'นัดครั้งถัดไป')),
    'by_category', (select coalesce(jsonb_agg(jsonb_build_object('category', cat, 'n', n) order by n desc, cat), '[]'::jsonb) from cats where n >= 3),
    'hidden_category_cases', (select coalesce(sum(n), 0) from cats where n < 3),
    'by_status', (select coalesce(jsonb_agg(jsonb_build_object('status', st, 'n', n) order by n desc, st), '[]'::jsonb) from sts where n >= 3),
    'hidden_status_cases', (select coalesce(sum(n), 0) from sts where n < 3),
    'by_level', (select coalesce(jsonb_agg(jsonb_build_object('level', lv, 'n', n) order by lv), '[]'::jsonb) from lvl where n >= 3),
    'hidden_level_cases', (select coalesce(sum(n), 0) from lvl where n < 3),
    'by_month', (select coalesce(jsonb_agg(jsonb_build_object('month', m, 'n', n) order by m), '[]'::jsonb)
                 from (select to_char(session_date, 'YYYY-MM') m, count(*)::int n from l group by 1) t),
    'trend', (select coalesce(jsonb_agg(jsonb_build_object('year', ay, 'n', n, 'students', ns) order by ay), '[]'::jsonb)
              from (select ay, count(*)::int n, count(distinct student_id)::int ns from allx group by 1) t)
  ) into v;
  return v;
end;
$$;

revoke all on function public.th_academic_year(timestamptz) from public, anon;
revoke all on function public.report_programs(text) from public, anon;
revoke all on function public.report_counseling(text) from public, anon;
grant execute on function public.th_academic_year(timestamptz) to authenticated;
grant execute on function public.report_programs(text) to authenticated;
grant execute on function public.report_counseling(text) to authenticated;

-- ---------- 3) รวมการ์ดเมนู: ภาพรวมผู้บริหาร + รายงานประจำปี -> การ์ดเดียว ----------
update public.external_systems
   set title = 'รายงานผู้บริหาร',
       description = 'ภาพรวมระบบ รายงานประจำปี ทุน ฝึกงาน ซ้อมสัมภาษณ์ และอื่น ๆ ในหน้าเดียว พิมพ์ได้ ดาวน์โหลด Word ได้ (เฉพาะครูแนะแนวและแอดมิน)',
       url = 'https://timemachine68.github.io/treasury/executive-report.html',
       sort_order = 15
 where id = '37b93001-edfa-4601-b6b6-5bb278ae2c34';

delete from public.external_systems where id = '39e12c02-f459-4b4f-8730-2a72a201f8e9';

-- ครูแนะแนวที่จำกัดเมนู: เอาไอดีการ์ดรายงานประจำปีเดิมออก แล้วเพิ่มการ์ดรวมถ้ายังไม่มี
update public.profiles
   set menu_permissions = jsonb_set(
         menu_permissions, '{appsOnly}',
         (select coalesce(jsonb_agg(x), '[]'::jsonb)
            from (select distinct x from jsonb_array_elements_text(menu_permissions->'appsOnly' || '["37b93001-edfa-4601-b6b6-5bb278ae2c34"]'::jsonb) x
                   where x <> '39e12c02-f459-4b4f-8730-2a72a201f8e9') s))
 where role = 'teacher' and is_guidance = true
   and jsonb_typeof(menu_permissions->'appsOnly') = 'array';
