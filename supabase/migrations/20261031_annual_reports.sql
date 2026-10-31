-- รายงานประจำปี 3 เรื่อง: แบบสำรวจเรียนต่อ / โควตา / ผลงานนักเรียน
-- SECURITY INVOKER: RLS ของตารางเดิมทำงานเต็ม + เช็ค iv_is_staff() (แอดมิน + ครูแนะแนว)
-- คืนเฉพาะยอดรวม ไม่มีชื่อนักเรียน

-- ---------- 1) แบบสำรวจเรียนต่อ ----------
create or replace function public.report_survey(p_year text default null)
returns jsonb
language plpgsql
stable
security invoker
set search_path = public, pg_temp
as $$
declare
  v_year text;
  v_study text[] := array['ต่อ ม.4 โรงเรียนเดิม','ต่อ ม.4 โรงเรียนอื่น','ปวช.','กศน.','มหาวิทยาลัย','ปวส./ปวช.ต่อเนื่อง'];
  v jsonb;
begin
  if not public.iv_is_staff() then
    raise exception 'ไม่มีสิทธิ์ดูรายงานนี้' using errcode = '42501';
  end if;
  v_year := coalesce(nullif(trim(p_year), ''), (select max(academic_year) from public.survey_rounds));

  with resp as (
    select distinct on (s.student_id, r.grade)
           r.grade, s.student_id, coalesce(nullif(trim(s.status), ''), 'ไม่ระบุ') as status,
           nullif(trim(s.institution), '') as institution, nullif(trim(s.program), '') as program,
           s.tcas_round, s.university_id, p.class_room
    from public.survey_responses s
    join public.survey_rounds r on r.id = s.round_id
    left join public.profiles p on p.id = s.student_id
    where r.academic_year = v_year
    order by s.student_id, r.grade, s.submitted_at desc nulls last
  ),
  grades as (select distinct grade from public.survey_rounds where academic_year = v_year),
  roster as (
    select split_part(class_room, '/', 1) as grade, class_room, count(*)::int as n
    from public.profiles where role = 'student' and class_room like 'ม.%/%'
    group by 1, 2
  )
  select jsonb_build_object(
    'year', v_year,
    'years', (select coalesce(jsonb_agg(y order by y desc), '[]'::jsonb) from (select distinct academic_year y from public.survey_rounds) t),
    'study_status', to_jsonb(v_study),
    'grades', (select coalesce(jsonb_agg(jsonb_build_object(
        'grade', g.grade,
        'students', (select coalesce(sum(n), 0) from roster where roster.grade = g.grade),
        'responded', (select count(*) from resp where resp.grade = g.grade),
        'study', (select count(*) from resp where resp.grade = g.grade and resp.status = any(v_study))
      ) order by g.grade), '[]'::jsonb) from grades g),
    'status', (select coalesce(jsonb_agg(jsonb_build_object('grade', grade, 'status', status, 'n', n) order by grade, n desc, status), '[]'::jsonb)
      from (select grade, status, count(*)::int n from resp group by 1, 2) t),
    'tcas', (select coalesce(jsonb_agg(jsonb_build_object('round', rnd, 'n', n) order by rnd), '[]'::jsonb)
      from (select coalesce(nullif(trim(tcas_round), ''), 'ไม่ระบุรอบ') rnd, count(*)::int n
            from resp where grade = 'ม.6' and status = 'มหาวิทยาลัย' group by 1) t),
    'universities', (select coalesce(jsonb_agg(jsonb_build_object('name', name, 'n', n) order by n desc, name), '[]'::jsonb)
      from (select coalesce(u.name, resp.institution, 'ไม่ระบุ') name, count(*)::int n
            from resp left join public.iv_universities u on u.id = resp.university_id
            where resp.grade = 'ม.6' and resp.status = 'มหาวิทยาลัย'
            group by 1 order by 2 desc, 1 limit 20) t),
    'programs', (select coalesce(jsonb_agg(jsonb_build_object('name', program, 'n', n) order by n desc, program), '[]'::jsonb)
      from (select program, count(*)::int n from resp
            where grade = 'ม.6' and status = 'มหาวิทยาลัย' and program is not null
            group by 1 order by 2 desc, 1 limit 15) t),
    'schools_m3', (select coalesce(jsonb_agg(jsonb_build_object('name', institution, 'n', n) order by n desc, institution), '[]'::jsonb)
      from (select institution, count(*)::int n from resp
            where grade = 'ม.3' and institution is not null
            group by 1 order by 2 desc, 1 limit 15) t),
    'rooms', (select coalesce(jsonb_agg(jsonb_build_object('room', class_room, 'grade', grade, 'students', students, 'responded', responded)
                order by grade, rn nulls last, class_room), '[]'::jsonb)
      from (select ro.grade, ro.class_room, ro.n students,
                   (select count(*) from resp where resp.class_room = ro.class_room and resp.grade = ro.grade)::int responded,
                   nullif(regexp_replace(split_part(ro.class_room, '/', 2), '\D', '', 'g'), '')::int rn
            from roster ro join grades g on g.grade = ro.grade) t),
    'trend', (select coalesce(jsonb_agg(jsonb_build_object('year', y, 'grade', grade, 'responded', n, 'study', st, 'university', un)
                order by y, grade), '[]'::jsonb)
      from (select r.academic_year y, r.grade,
                   count(distinct s.student_id)::int n,
                   count(distinct s.student_id) filter (where s.status = any(v_study))::int st,
                   count(distinct s.student_id) filter (where s.status = 'มหาวิทยาลัย')::int un
            from public.survey_rounds r join public.survey_responses s on s.round_id = r.id
            group by 1, 2) t)
  ) into v;
  return v;
end;
$$;

-- ---------- 2) โควตา ----------
create or replace function public.report_quota(p_year text default null)
returns jsonb
language plpgsql
stable
security invoker
set search_path = public, pg_temp
as $$
declare
  v_year text;
  v jsonb;
begin
  if not public.iv_is_staff() then
    raise exception 'ไม่มีสิทธิ์ดูรายงานนี้' using errcode = '42501';
  end if;
  v_year := coalesce(nullif(trim(p_year), ''), (select max(academic_year) from public.quotas where status <> 'draft'));

  with q as (select * from public.quotas where academic_year = v_year and status <> 'draft'),
  a as (
    select qa.quota_id, qa.profile_id, qa.status::text st, p.class_room
    from public.quota_applications qa join q on q.id = qa.quota_id
    left join public.profiles p on p.id = qa.profile_id
  )
  select jsonb_build_object(
    'year', v_year,
    'years', (select coalesce(jsonb_agg(y order by y desc), '[]'::jsonb) from (select distinct academic_year y from public.quotas where status <> 'draft' and academic_year is not null) t),
    'kpi', jsonb_build_object(
      'quotas', (select count(*) from q),
      'seats', (select coalesce(sum(seats), 0) from q),
      'universities', (select count(distinct coalesce(nullif(trim(university), ''), '-')) from q),
      'applications', (select count(*) from a where st <> 'withdrawn'),
      'applicants', (select count(distinct profile_id) from a where st <> 'withdrawn'),
      'selected', (select count(*) from a where st in ('approved', 'promoted')),
      'selected_students', (select count(distinct profile_id) from a where st in ('approved', 'promoted')),
      'waitlisted', (select count(*) from a where st = 'waitlisted'),
      'pending', (select count(*) from a where st in ('submitted', 'under_review', 'shortlisted')),
      'withdrawn', (select count(*) from a where st = 'withdrawn')),
    'status', (select coalesce(jsonb_agg(jsonb_build_object('status', st, 'n', n) order by n desc), '[]'::jsonb)
      from (select st, count(*)::int n from a group by 1) t),
    'by_quota', (select coalesce(jsonb_agg(jsonb_build_object(
        'name', q.name, 'university', coalesce(nullif(trim(q.university), ''), '-'), 'faculty', coalesce(nullif(trim(q.faculty), ''), '-'),
        'type', coalesce(q.quota_type, '-'), 'status', q.status::text, 'seats', coalesce(q.seats, 0),
        'applicants', (select count(*) from a where a.quota_id = q.id and st <> 'withdrawn'),
        'selected', (select count(*) from a where a.quota_id = q.id and st in ('approved', 'promoted')),
        'waitlisted', (select count(*) from a where a.quota_id = q.id and st = 'waitlisted'))
      order by q.university, q.faculty, q.name), '[]'::jsonb) from q),
    'by_university', (select coalesce(jsonb_agg(jsonb_build_object('university', u, 'quotas', nq, 'seats', seats, 'applicants', ap, 'selected', sel)
                order by ap desc, u), '[]'::jsonb)
      from (select coalesce(nullif(trim(q.university), ''), '-') u, count(*)::int nq, coalesce(sum(q.seats), 0)::int seats,
                   sum((select count(*) from a where a.quota_id = q.id and st <> 'withdrawn'))::int ap,
                   sum((select count(*) from a where a.quota_id = q.id and st in ('approved', 'promoted')))::int sel
            from q group by 1) t),
    'by_level', (select coalesce(jsonb_agg(jsonb_build_object('level', lv, 'applicants', n) order by lv), '[]'::jsonb)
      from (select coalesce(nullif(split_part(class_room, '/', 1), ''), 'ไม่ระบุ') lv, count(distinct profile_id)::int n
            from a where st <> 'withdrawn' group by 1) t),
    'trend', (select coalesce(jsonb_agg(jsonb_build_object('year', y, 'quotas', nq, 'seats', seats, 'applicants', ap, 'selected', sel) order by y), '[]'::jsonb)
      from (select qq.academic_year y, count(distinct qq.id)::int nq,
                   (select coalesce(sum(seats), 0) from public.quotas x where x.academic_year = qq.academic_year and x.status <> 'draft')::int seats,
                   count(qa.id) filter (where qa.status::text <> 'withdrawn')::int ap,
                   count(qa.id) filter (where qa.status::text in ('approved', 'promoted'))::int sel
            from public.quotas qq left join public.quota_applications qa on qa.quota_id = qq.id
            where qq.status <> 'draft' and qq.academic_year is not null
            group by 1) t)
  ) into v;
  return v;
end;
$$;

-- ---------- 3) ผลงานนักเรียน ----------
create or replace function public.report_awards(p_year int default null)
returns jsonb
language plpgsql
stable
security invoker
set search_path = public, pg_temp
as $$
declare
  v_year int;
  v jsonb;
begin
  if not public.iv_is_staff() then
    raise exception 'ไม่มีสิทธิ์ดูรายงานนี้' using errcode = '42501';
  end if;
  v_year := coalesce(p_year, (select max(academic_year) from public.award_events));

  with e as (select * from public.award_events where academic_year = v_year),
  ve as (select * from e where status = 'verified'),
  pa as (
    select ap.event_id, ve.subject_group_id, ve.level, ve.tcas_type, ve.category,
           coalesce(ap.profile_id::text, lower(trim(coalesce(ap.first_name_snapshot, '') || ' ' || coalesce(ap.last_name_snapshot, '')))) as who,
           p.class_room
    from public.award_participants ap join ve on ve.id = ap.event_id
    left join public.profiles p on p.id = ap.profile_id
  )
  select jsonb_build_object(
    'year', v_year,
    'years', (select coalesce(jsonb_agg(y order by y desc), '[]'::jsonb) from (select distinct academic_year y from public.award_events where academic_year is not null) t),
    'kpi', jsonb_build_object(
      'events', (select count(*) from ve),
      'participations', (select count(*) from pa),
      'students', (select count(distinct who) from pa),
      'groups', (select count(distinct subject_group_id) from ve),
      'high_level', (select count(*) from ve where level in ('international', 'national', 'region')),
      'pending', (select count(*) from e where status = 'submitted'),
      'returned', (select count(*) from e where status = 'returned'),
      'draft', (select count(*) from e where status = 'draft')),
    'by_group', (select coalesce(jsonb_agg(jsonb_build_object('group', g.name_th, 'events', ev, 'participations', np, 'students', ns)
                order by g.sort_order, g.id), '[]'::jsonb)
      from public.subject_groups g
      cross join lateral (select (select count(*) from ve where ve.subject_group_id = g.id)::int ev,
                                 (select count(*) from pa where pa.subject_group_id = g.id)::int np,
                                 (select count(distinct who) from pa where pa.subject_group_id = g.id)::int ns) c
      where g.is_active or c.ev > 0),
    'by_level', (select coalesce(jsonb_agg(jsonb_build_object('level', lv::text, 'label', coalesce(m.label_th, lv::text), 'events', ev, 'participations', np)
                order by lv), '[]'::jsonb)
      from (select level lv, count(distinct ve.id)::int ev,
                   (select count(*) from pa where pa.level = ve.level)::int np
            from ve group by level) t left join public.award_level_map m on m.level = t.lv),
    'by_type', (select coalesce(jsonb_agg(jsonb_build_object('type', ty, 'events', ev, 'participations', np) order by ty), '[]'::jsonb)
      from (select tcas_type::text ty, count(*)::int ev,
                   (select count(*) from pa where pa.tcas_type = ve.tcas_type)::int np
            from ve group by tcas_type) t),
    'by_class_level', (select coalesce(jsonb_agg(jsonb_build_object('level', lv, 'students', n) order by lv), '[]'::jsonb)
      from (select coalesce(nullif(split_part(class_room, '/', 1), ''), 'ไม่ระบุ') lv, count(distinct who)::int n from pa group by 1) t),
    'top_events', (select coalesce(jsonb_agg(jsonb_build_object('title', title, 'level', coalesce(m.label_th, lv::text), 'group', gname, 'type', ty, 'participations', np)
                order by lv, np desc, title), '[]'::jsonb)
      from (select ve.title, ve.level lv, ve.tcas_type::text ty, g.name_th gname,
                   (select count(*) from pa where pa.event_id = ve.id)::int np
            from ve left join public.subject_groups g on g.id = ve.subject_group_id
            order by ve.level, 5 desc, ve.title limit 15) t left join public.award_level_map m on m.level = t.lv),
    'trend', (select coalesce(jsonb_agg(jsonb_build_object('year', y, 'events', ev, 'participations', np, 'students', ns) order by y), '[]'::jsonb)
      from (select x.academic_year y, count(distinct x.id)::int ev, count(ap.id)::int np,
                   count(distinct coalesce(ap.profile_id::text, ap.first_name_snapshot || ' ' || ap.last_name_snapshot))::int ns
            from public.award_events x left join public.award_participants ap on ap.event_id = x.id
            where x.status = 'verified' group by 1) t)
  ) into v;
  return v;
end;
$$;

revoke all on function public.report_survey(text) from public, anon;
revoke all on function public.report_quota(text) from public, anon;
revoke all on function public.report_awards(int) from public, anon;
grant execute on function public.report_survey(text) to authenticated;
grant execute on function public.report_quota(text) to authenticated;
grant execute on function public.report_awards(int) to authenticated;
