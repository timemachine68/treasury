-- ตารางแนะแนวรายคาบ v2 (รันแล้วใน Supabase เมื่อ 1 พ.ย. 2569)
-- 1) เพิ่มคาบของ ม.6 และแก้เลขคาบ ม.3 ให้ตรงตารางแนะแนว (คาบ 5 = พักเที่ยง)
-- 2) guidance_class_periods: คาบแนะแนวปกติของแต่ละห้อง (หนึ่งช่องมีได้หลายห้อง)
-- 3) guidance_visit_slots: ตารางที่สถาบันเข้าแนะแนวของแต่ละสัปดาห์ เพิ่ม/ลบได้อิสระ
-- 4) ข้อมูลคาบของ ม.3 (15 ห้อง) และ ม.6 (9 ห้อง) จากตารางสอน ภาคเรียนที่ 2/2569
-- หมายเหตุ: ตาราง guidance_slots จาก migration แรกไม่ใช้แล้ว (ว่างเปล่า) ลบทิ้งได้ภายหลัง

alter table public.guidance_periods add column if not exists is_break boolean not null default false;

insert into public.guidance_periods (level, period_no, label, time_text, is_break) values
  ('m6', 1, 'คาบ 1',     '08.30–09.20', false),
  ('m6', 2, 'คาบ 2',     '09.20–10.10', false),
  ('m6', 3, 'คาบ 3',     '10.10–11.00', false),
  ('m6', 4, 'คาบ 4',     '11.00–11.50', false),
  ('m6', 5, 'พักเที่ยง', '11.50–12.40', true),
  ('m6', 6, 'คาบ 6',     '12.40–13.30', false),
  ('m6', 7, 'คาบ 7',     '13.30–14.20', false),
  ('m6', 8, 'คาบ 8',     '14.20–15.10', false)
on conflict (level, period_no) do nothing;

-- แก้คาบ 5–8 ของ ม.3 (เดิมเลื่อนเลขผิด)
update public.guidance_periods p
set label = v.label, time_text = v.t, is_break = v.b
from (values
  (5, 'พักเที่ยง', '11.50–12.40', true),
  (6, 'คาบ 6',     '12.40–13.30', false),
  (7, 'คาบ 7',     '13.30–14.20', false),
  (8, 'คาบ 8',     '14.20–15.10', false)
) as v(n, label, t, b)
where p.level = 'm3' and p.period_no = v.n;

create table if not exists public.guidance_class_periods (
  id         uuid primary key default gen_random_uuid(),
  level      text not null,
  day_no     int  not null check (day_no between 1 and 5),   -- 1=จันทร์ ... 5=ศุกร์
  period_no  int  not null,
  class_room text not null check (length(btrim(class_room)) > 0),
  room_no    text,
  note       text,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  constraint gcp_cell_uq unique (level, day_no, period_no, class_room),
  constraint gcp_period_fk foreign key (level, period_no)
    references public.guidance_periods(level, period_no) on delete cascade
);

create table if not exists public.guidance_visit_slots (
  id         uuid primary key default gen_random_uuid(),
  week_id    uuid not null references public.guidance_week_institutions(id) on delete cascade,
  day_no     int  not null check (day_no between 1 and 5),
  period_no  int  not null check (period_no between 0 and 20),
  class_room text not null check (length(btrim(class_room)) > 0),
  room_no    text,
  note       text,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  constraint gvs_cell_uq unique (week_id, day_no, period_no, class_room)
);
create index if not exists gvs_week_idx on public.guidance_visit_slots (week_id);

create trigger gcp_touch before insert or update on public.guidance_class_periods
  for each row execute function public.guidance_schedule_touch();
create trigger gvs_touch before insert or update on public.guidance_visit_slots
  for each row execute function public.guidance_schedule_touch();

-- RLS: ทุกคนที่ login อ่านได้ / แก้ได้เฉพาะ admin และครูแนะแนว (iv_is_staff)
alter table public.guidance_class_periods enable row level security;
alter table public.guidance_visit_slots   enable row level security;
revoke all on public.guidance_class_periods from anon;
revoke all on public.guidance_visit_slots   from anon;

create policy gcp_read on public.guidance_class_periods
  for select to authenticated using (true);
create policy gcp_write on public.guidance_class_periods
  for all to authenticated using (public.iv_is_staff()) with check (public.iv_is_staff());
create policy gvs_read on public.guidance_visit_slots
  for select to authenticated using (true);
create policy gvs_write on public.guidance_visit_slots
  for all to authenticated using (public.iv_is_staff()) with check (public.iv_is_staff());

insert into public.guidance_class_periods (level, day_no, period_no, class_room, room_no) values
  ('m3', 1, 2, '3/1',  '315'),
  ('m3', 1, 2, '3/15', 'การงาน3'),
  ('m3', 1, 7, '3/8',  '443'),
  ('m3', 2, 2, '3/9',  '444'),
  ('m3', 2, 3, '3/6',  '441'),
  ('m3', 2, 6, '3/11', '446'),
  ('m3', 2, 6, '3/5',  '438'),
  ('m3', 3, 2, '3/10', '445'),
  ('m3', 4, 4, '3/12', '447'),
  ('m3', 4, 6, '3/3',  '436'),
  ('m3', 4, 7, '3/2',  '435'),
  ('m3', 5, 1, '3/4',  '437'),
  ('m3', 5, 2, '3/7',  '442'),
  ('m3', 5, 6, '3/13', '448'),
  ('m3', 5, 6, '3/14', 'การงาน1'),
  ('m6', 1, 4, '6/8',  '142'),
  ('m6', 1, 6, '6/7',  '141'),
  ('m6', 3, 4, '6/6',  '135'),
  ('m6', 3, 7, '6/3',  '132'),
  ('m6', 4, 1, '6/9',  '143'),
  ('m6', 4, 3, '6/4',  '133'),
  ('m6', 4, 4, '6/5',  '134'),
  ('m6', 4, 6, '6/1',  '324'),
  ('m6', 4, 7, '6/2',  '131');
