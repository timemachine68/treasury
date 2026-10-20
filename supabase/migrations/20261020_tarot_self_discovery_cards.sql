-- การ์ดสำรวจใจ: ตารางใหม่ (เพิ่มอย่างเดียว ไม่แตะตารางเดิม)
-- ใช้รูปแบบเดียวกับตารางเดิมของ "แนะให้แนว": get_my_role(), student_id = auth.uid()

-- 1) ความยินยอม (นักเรียนติ๊กยืนยันเอง; ครู/แอดมินบันทึกแทนได้)
create table public.tarot_consents (
  student_id uuid primary key references public.profiles(id) on delete cascade,
  consented boolean not null default false,
  consented_by text not null default 'student' check (consented_by in ('student','staff')),
  text_version text,
  recorded_by uuid references public.profiles(id),
  note text,
  recorded_at timestamptz not null default now()
);

-- 2) การเล่น 1 ครั้ง (ผลแนวโน้ม + ไพ่) ครูเห็นได้
create table public.tarot_sessions (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.profiles(id) on delete cascade,
  level smallint not null check (level in (3,6)),
  mbti text not null check (mbti ~ '^[EI][SN][TF][JP]$'),
  mbti_adjusted boolean not null default false,
  survey_answers jsonb not null,
  cards jsonb not null,
  resonated_position smallint check (resonated_position between 0 and 2),
  next_action text,
  created_at timestamptz not null default now()
);
create index on public.tarot_sessions (student_id, created_at desc);

-- 3) บันทึกสะท้อนคิด (ส่วนตัวเป็นค่าเริ่มต้น ครูอ่านได้เมื่อนักเรียนกดแชร์เท่านั้น)
create table public.tarot_reflections (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null unique references public.tarot_sessions(id) on delete cascade,
  student_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  shared_with_teacher boolean not null default false,
  created_at timestamptz not null default now()
);

-- 4) แบบวัดก่อน-หลัง (ความรู้จักตนเอง / ความมั่นใจในการเลือกเส้นทาง) สำหรับหลักฐานวิทยฐานะ
create table public.tarot_prepost (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.profiles(id) on delete cascade,
  round_label text not null,                      -- เช่น '2569-1'
  phase text not null check (phase in ('pre','post')),
  level smallint not null check (level in (3,6)),
  items jsonb not null,                           -- คะแนนรายข้อ (ลิเคิร์ต 1-5)
  total numeric(5,2) not null,
  created_at timestamptz not null default now(),
  unique (student_id, round_label, phase)
);

alter table public.tarot_consents    enable row level security;
alter table public.tarot_sessions    enable row level security;
alter table public.tarot_reflections enable row level security;
alter table public.tarot_prepost     enable row level security;

-- ความยินยอม: นักเรียนเห็น/บันทึก/ถอนของตัวเองได้, ครู/แอดมินเห็นและบันทึกได้
create policy "see consents" on public.tarot_consents for select to authenticated
  using (student_id = auth.uid() or get_my_role() in ('teacher','admin'));
create policy "staff write consents" on public.tarot_consents for insert to authenticated
  with check (get_my_role() in ('teacher','admin') and recorded_by = auth.uid());
create policy "student insert own consent" on public.tarot_consents for insert to authenticated
  with check (student_id = auth.uid() and consented_by = 'student');
create policy "student update own consent" on public.tarot_consents for update to authenticated
  using (student_id = auth.uid()) with check (student_id = auth.uid());
create policy "staff update consents" on public.tarot_consents for update to authenticated
  using (get_my_role() in ('teacher','admin'));

-- การเล่น: นักเรียนบันทึกได้เมื่อยินยอมแล้วเท่านั้น
create policy "see sessions" on public.tarot_sessions for select to authenticated
  using (student_id = auth.uid() or get_my_role() in ('teacher','admin'));
create policy "student insert session" on public.tarot_sessions for insert to authenticated
  with check (student_id = auth.uid()
    and exists (select 1 from public.tarot_consents c where c.student_id = auth.uid() and c.consented));

-- บันทึกสะท้อนคิด: ครูเห็นเฉพาะที่นักเรียนกดแชร์
create policy "see reflections" on public.tarot_reflections for select to authenticated
  using (student_id = auth.uid()
    or (shared_with_teacher and get_my_role() in ('teacher','admin')));
create policy "student insert reflection" on public.tarot_reflections for insert to authenticated
  with check (student_id = auth.uid()
    and exists (select 1 from public.tarot_sessions s where s.id = session_id and s.student_id = auth.uid()));
create policy "student update reflection" on public.tarot_reflections for update to authenticated
  using (student_id = auth.uid()) with check (student_id = auth.uid());

-- แบบวัดก่อน-หลัง
create policy "see prepost" on public.tarot_prepost for select to authenticated
  using (student_id = auth.uid() or get_my_role() in ('teacher','admin'));
create policy "student insert prepost" on public.tarot_prepost for insert to authenticated
  with check (student_id = auth.uid()
    and exists (select 1 from public.tarot_consents c where c.student_id = auth.uid() and c.consented));

-- 5) สรุปรายห้องสำหรับครู (ไม่มีชื่อ ไม่มีบันทึก) ใช้สิทธิ์ของผู้เรียก
create view public.tarot_class_summary with (security_invoker = true) as
select p.class_room, s.level, s.mbti, count(*) as plays
from public.tarot_sessions s
join public.profiles p on p.id = s.student_id
group by p.class_room, s.level, s.mbti;

create view public.tarot_prepost_summary with (security_invoker = true) as
select pp.round_label, pp.level, p.class_room, pp.phase,
       count(*) as n, round(avg(pp.total),2) as mean_total, round(stddev_samp(pp.total),2) as sd_total
from public.tarot_prepost pp
join public.profiles p on p.id = pp.student_id
group by pp.round_label, pp.level, p.class_room, pp.phase;

-- ปิดช่อง anon (โปรเจกต์นี้มี default privilege ให้ anon)
revoke all on public.tarot_consents, public.tarot_sessions, public.tarot_reflections, public.tarot_prepost, public.tarot_class_summary, public.tarot_prepost_summary from anon;
revoke all on public.tarot_class_summary, public.tarot_prepost_summary from public;
