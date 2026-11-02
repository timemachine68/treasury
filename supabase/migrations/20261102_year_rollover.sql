-- เปลี่ยนปีการศึกษา: เลื่อนชั้น (ห้องเดิม) / ม.3 และ ม.6 จบ / เก็บบัญชีคนจบ 1 ปีแล้วปิดล็อกอิน
-- ไม่ลบข้อมูลใด ๆ (ผลสำรวจ ทุน ผลงาน ยังอยู่ครบสำหรับรายงานย้อนหลัง)

alter table public.profiles
  add column if not exists status text not null default 'active',
  add column if not exists graduated_at date,
  add column if not exists graduated_year int;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'profiles_status_chk') then
    alter table public.profiles add constraint profiles_status_chk check (status in ('active', 'graduated', 'closed'));
  end if;
end $$;
create index if not exists profiles_status_idx on public.profiles (status) where role = 'student';

-- ห้องเรียนของนักเรียนแต่ละปี (บันทึกตอนเปลี่ยนปี ใช้เป็นฐานคิดรายงานย้อนหลัง)
create table if not exists public.student_year_rooms (
  academic_year int not null,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  class_room text not null,
  primary key (academic_year, profile_id)
);
alter table public.student_year_rooms enable row level security;
drop policy if exists syr_staff_read on public.student_year_rooms;
create policy syr_staff_read on public.student_year_rooms for select to authenticated using (public.iv_is_staff());
revoke all on public.student_year_rooms from public, anon;
grant select on public.student_year_rooms to authenticated;

-- ประวัติการเปลี่ยนปี (กันกดซ้ำ)
create table if not exists public.academic_rollovers (
  academic_year int primary key,
  run_at timestamptz not null default now(),
  run_by uuid references public.profiles(id) on delete set null,
  promoted int not null default 0,
  graduated int not null default 0,
  closed int not null default 0,
  skipped int not null default 0
);
alter table public.academic_rollovers enable row level security;
drop policy if exists ar_staff_read on public.academic_rollovers;
create policy ar_staff_read on public.academic_rollovers for select to authenticated using (public.iv_is_staff());
revoke all on public.academic_rollovers from public, anon;
grant select on public.academic_rollovers to authenticated;

-- ปิดบัญชีคนจบที่ครบ 1 ปี (ไม่ลบข้อมูล แค่ปิดล็อกอิน)
create or replace function public.close_old_graduates()
returns int language plpgsql security definer set search_path = public, pg_temp as $$
declare v_ids uuid[]; v_n int;
begin
  if not public.iv_is_staff() then raise exception 'ไม่มีสิทธิ์' using errcode = '42501'; end if;
  with c as (
    update public.profiles set status = 'closed'
    where role = 'student' and status = 'graduated' and graduated_at <= current_date - interval '1 year'
    returning id)
  select coalesce(array_agg(id), '{}') into v_ids from c;
  v_n := coalesce(array_length(v_ids, 1), 0);
  if v_n > 0 then
    update auth.users set banned_until = now() + interval '100 years' where id = any(v_ids);
  end if;
  return v_n;
end $$;

create or replace function public.rollover_preview()
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
declare v_cur int := public.th_academic_year(now());
begin
  if not public.iv_is_staff() then raise exception 'ไม่มีสิทธิ์' using errcode = '42501'; end if;
  return jsonb_build_object(
    'current_year', v_cur,
    'next_year', v_cur + 1,
    'can_run_next', now() >= make_date(v_cur + 1 - 543, 4, 1),
    'last_rollover', (select max(academic_year) from public.academic_rollovers),
    'levels', (select coalesce(jsonb_agg(jsonb_build_object('level', lv, 'n', n, 'rooms', rooms) order by lv), '[]'::jsonb)
               from (select split_part(class_room, '/', 1) lv, count(*)::int n, count(distinct class_room)::int rooms
                     from public.profiles where role = 'student' and status = 'active' and class_room ~ '^ม\.[1-6]/' group by 1) t),
    'odd', (select count(*)::int from public.profiles where role = 'student' and status = 'active' and (class_room is null or class_room !~ '^ม\.[1-6]/')),
    'graduated_now', (select count(*)::int from public.profiles where role = 'student' and status = 'graduated'),
    'closable', (select count(*)::int from public.profiles where role = 'student' and status = 'graduated' and graduated_at <= current_date - interval '1 year'),
    'closed', (select count(*)::int from public.profiles where role = 'student' and status = 'closed'),
    'history', (select coalesce(jsonb_agg(to_jsonb(r) order by r.academic_year desc), '[]'::jsonb) from (select academic_year, run_at, promoted, graduated, closed, skipped from public.academic_rollovers order by academic_year desc limit 10) r)
  );
end $$;

create or replace function public.rollover_commit(p_year int, p_confirm text)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare v_cur int := public.th_academic_year(now()); v_grad int; v_prom int; v_skip int; v_closed int;
begin
  if not public.iv_is_staff() then raise exception 'ไม่มีสิทธิ์' using errcode = '42501'; end if;
  if p_confirm is distinct from ('เปลี่ยนปี ' || p_year) then raise exception 'พิมพ์ข้อความยืนยันไม่ตรง'; end if;
  if p_year is null or p_year not in (v_cur, v_cur + 1) then raise exception 'ปีการศึกษาที่เลือกไม่ถูกต้อง'; end if;
  if p_year = v_cur + 1 and now() < make_date(p_year - 543, 4, 1) then raise exception 'ยังไม่ถึงเวลาเปลี่ยนปี (เริ่มทำได้ตั้งแต่ 1 เมษายน)'; end if;
  perform pg_advisory_xact_lock(570001);
  if exists (select 1 from public.academic_rollovers where academic_year >= p_year) then
    raise exception 'เปลี่ยนปีการศึกษา % ไปแล้ว', p_year;
  end if;

  -- 1) บันทึกห้องของปีที่กำลังจบ
  insert into public.student_year_rooms (academic_year, profile_id, class_room)
    select p_year - 1, id, class_room from public.profiles
    where role = 'student' and status = 'active' and class_room ~ '^ม\.[1-6]/'
    on conflict do nothing;
  -- 2) ปิดบัญชีคนจบที่ครบ 1 ปี
  v_closed := public.close_old_graduates();
  -- 3) ม.3 และ ม.6 จบ (คงห้องเดิมไว้)
  update public.profiles set status = 'graduated', graduated_at = current_date, graduated_year = p_year - 1
    where role = 'student' and status = 'active' and class_room ~ '^ม\.[36]/';
  get diagnostics v_grad = row_count;
  -- 4) ม.1 ม.2 ม.4 ม.5 เลื่อนชั้น ห้องเดิม
  update public.profiles
    set class_room = 'ม.' || (substring(class_room from 3 for 1)::int + 1) || substring(class_room from 4)
    where role = 'student' and status = 'active' and class_room ~ '^ม\.[1245]/';
  get diagnostics v_prom = row_count;
  select count(*)::int into v_skip from public.profiles
    where role = 'student' and status = 'active' and (class_room is null or class_room !~ '^ม\.[1-6]/');
  insert into public.academic_rollovers (academic_year, run_by, promoted, graduated, closed, skipped)
    values (p_year, auth.uid(), v_prom, v_grad, v_closed, v_skip);
  return jsonb_build_object('year', p_year, 'promoted', v_prom, 'graduated', v_grad, 'closed', v_closed, 'skipped', v_skip);
end $$;

revoke all on function public.close_old_graduates() from public, anon;
revoke all on function public.rollover_preview() from public, anon;
revoke all on function public.rollover_commit(int, text) from public, anon;
grant execute on function public.close_old_graduates() to authenticated;
grant execute on function public.rollover_preview() to authenticated;
grant execute on function public.rollover_commit(int, text) to authenticated;

-- รายงาน: นับเฉพาะนักเรียนที่ยังเรียนอยู่ และใช้ห้องที่บันทึกไว้ตอนเปลี่ยนปีสำหรับปีเก่า
do $$
declare d text;
begin
  d := pg_get_functiondef('public.exec_overview()'::regprocedure);
  if position('status = ''active''' in d) = 0 then
    d := replace(d, 'from public.profiles where role = ''student''', 'from public.profiles where role = ''student'' and status = ''active''');
    d := replace(d, 'count(*)::int, 8 from public.student_identity', 'count(*)::int, 8 from public.student_identity si join public.profiles pa on pa.id = si.profile_id and pa.status = ''active''');
    execute d;
  end if;

  d := pg_get_functiondef('public.usage_summary(integer)'::regprocedure);
  if position('status = ''active''' in d) = 0 then
    d := replace(d, 'count(*) filter (where role = ''student''),', 'count(*) filter (where role = ''student'' and status = ''active''),');
    d := replace(d, 'where role = ''student'' and class_room like ''ม.%'' group by 1', 'where role = ''student'' and status = ''active'' and class_room like ''ม.%'' group by 1');
    execute d;
  end if;

  d := pg_get_functiondef('public.report_survey(text)'::regprocedure);
  if position('student_year_rooms' in d) = 0 then
    d := replace(d, 's.tcas_round, s.university_id, p.class_room', 's.tcas_round, s.university_id, coalesce(sn.class_room, p.class_room) as class_room');
    d := replace(d, 'left join public.profiles p on p.id = s.student_id', 'left join public.profiles p on p.id = s.student_id left join public.student_year_rooms sn on sn.profile_id = s.student_id and sn.academic_year::text = r.academic_year');
    d := replace(d, 'from public.profiles where role = ''student'' and class_room like ''ม.%/%''',
      'from (select class_room from public.student_year_rooms where academic_year::text = v_year union all select pr.class_room from public.profiles pr where pr.role = ''student'' and pr.status = ''active'' and not exists (select 1 from public.student_year_rooms where academic_year::text = v_year)) x where class_room like ''ม.%/%''');
    execute d;
  end if;
end $$;

-- การ์ดเมนู "เปลี่ยนปีการศึกษา" ใน "ระบบของเรา" (ครูแนะแนวที่ใช้ appsOnly ต้องเพิ่ม id การ์ดด้วย)
with n as (
  insert into public.external_systems (title, description, url, icon, visible_to, sort_order)
  select 'เปลี่ยนปีการศึกษา', 'เลื่อนชั้น ม.1 ม.2 ม.4 ม.5 (ห้องเดิม) ม.3 และ ม.6 จบการศึกษา เก็บบัญชีคนจบ 1 ปีแล้วปิดล็อกอิน — ทำปีละครั้ง',
         'https://timemachine68.github.io/treasury/year-rollover.html', '🎓', '{teacher}', 16
  where not exists (select 1 from public.external_systems where title = 'เปลี่ยนปีการศึกษา')
  returning id)
update public.profiles p set menu_permissions = jsonb_set(menu_permissions, '{appsOnly}', (menu_permissions->'appsOnly') || to_jsonb((select id::text from n)))
where p.role = 'teacher' and p.is_guidance and jsonb_typeof(menu_permissions->'appsOnly') = 'array' and exists (select 1 from n);
