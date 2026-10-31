-- ซ้อมสัมภาษณ์: วันสัมภาษณ์ของนักเรียน (ไม่บังคับ, ตั้งได้หลายวัน) + เป้าหมายจำนวนเซ็ต
-- นักเรียนเห็น/แก้เฉพาะของตัวเอง | ครูแนะแนว+แอดมินอ่านวันสัมภาษณ์ได้อย่างเดียว | เป้าหมายส่วนตัวครูไม่เห็น

-- 1) วันสัมภาษณ์
create table public.iv_interview_dates (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.profiles(id) on delete cascade,
  interview_date date not null,
  university_id uuid references public.iv_universities(id) on delete set null,
  target_university text check (target_university is null or char_length(target_university) <= 100),
  target_faculty text check (target_faculty is null or char_length(target_faculty) <= 100),
  round_label text check (round_label is null or round_label in ('portfolio','quota','direct','admission','other')),
  created_at timestamptz not null default now()
);
alter table public.iv_interview_dates enable row level security;

create index iv_interview_dates_student_idx on public.iv_interview_dates(student_id, interview_date);
create index iv_interview_dates_date_idx on public.iv_interview_dates(interview_date);
-- กันบันทึกซ้ำ (วันเดียวกัน ที่เดียวกัน คณะเดียวกัน)
create unique index iv_interview_dates_no_dup on public.iv_interview_dates
  (student_id, interview_date, lower(btrim(coalesce(target_university,''))), lower(btrim(coalesce(target_faculty,''))));

-- 2) เป้าหมายของนักเรียนเอง (ครูไม่เห็น)
create table public.iv_student_goals (
  student_id uuid primary key references public.profiles(id) on delete cascade,
  goal_sets integer not null default 5 check (goal_sets between 1 and 30),
  updated_at timestamptz not null default now()
);
alter table public.iv_student_goals enable row level security;

-- 3) ตัวกันข้อมูลเสีย: วันที่ต้องไม่ย้อนหลัง/ไม่ไกลเกิน 2 ปี และมีวันที่ยังไม่ถึงได้ไม่เกิน 10 วัน
create function public.iv_dates_guard() returns trigger
language plpgsql security invoker set search_path = '' as $$
declare today date := (now() at time zone 'Asia/Bangkok')::date; n int;
begin
  new.target_university := nullif(btrim(coalesce(new.target_university,'')), '');
  new.target_faculty := nullif(btrim(coalesce(new.target_faculty,'')), '');
  if tg_op = 'INSERT' or new.interview_date is distinct from old.interview_date then
    if new.interview_date < today then
      raise exception 'เลือกวันที่ย้อนหลังไม่ได้ ถ้าสัมภาษณ์ไปแล้วให้ลบหรือไม่ต้องตั้งวัน';
    end if;
    if new.interview_date > today + 730 then
      raise exception 'วันที่ไกลเกินไป เลือกภายใน 2 ปีข้างหน้า';
    end if;
  end if;
  if tg_op = 'INSERT' then
    select count(*) into n from public.iv_interview_dates
      where student_id = new.student_id and interview_date >= today;
    if n >= 10 then
      raise exception 'ตั้งวันสัมภาษณ์ที่ยังไม่ถึงได้ไม่เกิน 10 วัน ลบอันที่ผ่านแล้วหรือไม่ใช้ก่อน';
    end if;
  end if;
  return new;
end $$;
create trigger iv_dates_guard_trg before insert or update on public.iv_interview_dates
  for each row execute function public.iv_dates_guard();

create function public.iv_goals_touch() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin new.updated_at := now(); return new; end $$;
create trigger iv_goals_touch_trg before update on public.iv_student_goals
  for each row execute function public.iv_goals_touch();

-- 4) สิทธิ์ตาราง
revoke all on public.iv_interview_dates, public.iv_student_goals from anon, public;
revoke all on public.iv_interview_dates, public.iv_student_goals from authenticated;
grant select, delete on public.iv_interview_dates to authenticated;
grant insert (student_id, interview_date, university_id, target_university, target_faculty, round_label)
  on public.iv_interview_dates to authenticated;
grant update (interview_date, university_id, target_university, target_faculty, round_label)
  on public.iv_interview_dates to authenticated;
grant select on public.iv_student_goals to authenticated;
grant insert (student_id, goal_sets) on public.iv_student_goals to authenticated;
grant update (goal_sets) on public.iv_student_goals to authenticated;

-- 5) นโยบาย RLS
create policy "own or staff read iv_dates" on public.iv_interview_dates
  for select to authenticated
  using (student_id = (select auth.uid()) or (select public.iv_is_staff()));
create policy "student insert own iv_dates" on public.iv_interview_dates
  for insert to authenticated
  with check (student_id = (select auth.uid()) and (select public.get_my_role()) = 'student');
create policy "student update own iv_dates" on public.iv_interview_dates
  for update to authenticated
  using (student_id = (select auth.uid()))
  with check (student_id = (select auth.uid()));
create policy "student delete own iv_dates" on public.iv_interview_dates
  for delete to authenticated using (student_id = (select auth.uid()));

create policy "student read own iv_goals" on public.iv_student_goals
  for select to authenticated using (student_id = (select auth.uid()));
create policy "student insert own iv_goals" on public.iv_student_goals
  for insert to authenticated
  with check (student_id = (select auth.uid()) and (select public.get_my_role()) = 'student');
create policy "student update own iv_goals" on public.iv_student_goals
  for update to authenticated
  using (student_id = (select auth.uid()))
  with check (student_id = (select auth.uid()));

-- 6) สรุปสำหรับครูแนะแนว: นักเรียนที่ตั้งวันสัมภาษณ์ไว้ + ความก้าวหน้าจริง (ไม่รวมเป้าหมายส่วนตัว)
--    SECURITY INVOKER: ใช้สิทธิ์ของผู้เรียก ครูกลุ่มสาระอื่นเรียกแล้วไม่ได้ข้อมูล
create function public.iv_upcoming_interviews(p_days integer default 30)
returns table (
  date_id uuid, student_id uuid, display_name text, class_room text,
  interview_date date, days_left integer,
  target_university text, target_faculty text, round_label text,
  sets_sent integer, sets_pending integer,
  last_teacher_avg numeric, prev_teacher_avg numeric,
  checklist_done integer, checklist_total integer
)
language plpgsql stable security invoker set search_path = '' as $$
declare today date := (now() at time zone 'Asia/Bangkok')::date;
begin
  if not public.iv_is_staff() then
    raise exception 'เฉพาะครูแนะแนวเท่านั้นที่ดูหน้านี้ได้';
  end if;
  return query
  select d.id, d.student_id, p.display_name, p.class_room,
    d.interview_date, (d.interview_date - today)::int,
    coalesce(d.target_university, u.name), d.target_faculty, d.round_label,
    (select count(*)::int from public.iv_sessions s where s.student_id = d.student_id and s.status in ('submitted','reviewed')),
    (select count(*)::int from public.iv_sessions s where s.student_id = d.student_id and s.status = 'submitted'),
    (select t.a from (select avg(sc.score) a, s.reviewed_at from public.iv_sessions s
        join public.iv_scores sc on sc.session_id = s.id and sc.scorer_role = 'teacher'
        where s.student_id = d.student_id and s.status = 'reviewed'
        group by s.id, s.reviewed_at order by s.reviewed_at desc limit 1) t),
    (select t.a from (select avg(sc.score) a, s.reviewed_at from public.iv_sessions s
        join public.iv_scores sc on sc.session_id = s.id and sc.scorer_role = 'teacher'
        where s.student_id = d.student_id and s.status = 'reviewed'
        group by s.id, s.reviewed_at order by s.reviewed_at desc limit 1 offset 1) t),
    (select count(*)::int from public.iv_checklist_done c
        join public.iv_checklist_items ci on ci.id = c.item_id and ci.is_active
        where c.student_id = d.student_id),
    (select count(*)::int from public.iv_checklist_items where is_active)
  from public.iv_interview_dates d
  join public.profiles p on p.id = d.student_id
  left join public.iv_universities u on u.id = d.university_id
  where d.interview_date >= today
    and (p_days is null or d.interview_date <= today + p_days)
  order by d.interview_date, p.class_room, p.display_name
  limit 500;
end $$;
revoke all on function public.iv_upcoming_interviews(integer) from public, anon;
grant execute on function public.iv_upcoming_interviews(integer) to authenticated;
