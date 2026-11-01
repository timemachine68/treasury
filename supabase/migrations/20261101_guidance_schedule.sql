-- ตารางแนะแนวรายคาบ + สัปดาห์สถาบันที่เข้าแนะแนว (ม.3 / ม.6)
-- อ่าน: ทุกคนที่ login (นักเรียนและครู)
-- แก้ไข: iv_is_staff() (admin + ครูแนะแนว)

-- 1) สัปดาห์ที่สถาบันเข้าแนะแนว
create table if not exists public.guidance_week_institutions (
  id          uuid primary key default gen_random_uuid(),
  level       text not null check (level in ('m3','m6')),
  week_no     int  not null check (week_no between 1 and 60),
  date_start  date not null,
  date_end    date not null,
  institution text,                       -- ว่าง = ยังไม่ระบุ
  updated_by  uuid references auth.users(id) on delete set null,
  updated_at  timestamptz not null default now(),
  constraint gwi_dates_chk check (date_end >= date_start),
  constraint gwi_level_week_uq unique (level, week_no)
);

-- 2) คาบเรียน (เพิ่ม/ลบ/แก้เวลาได้อิสระ)
create table if not exists public.guidance_periods (
  level     text not null check (level in ('m3','m6')),
  period_no int  not null check (period_no between 0 and 20),
  label     text not null,
  time_text text,
  primary key (level, period_no)
);

-- 3) ช่องในตาราง: วัน x คาบ
create table if not exists public.guidance_slots (
  level      text not null,
  day_no     int  not null check (day_no between 1 and 5),   -- 1=จันทร์ ... 5=ศุกร์
  period_no  int  not null,
  class_room text,
  note       text,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  primary key (level, day_no, period_no),
  foreign key (level, period_no)
    references public.guidance_periods(level, period_no) on delete cascade
);

-- trigger: บันทึกผู้แก้และเวลาแก้ไขอัตโนมัติ
create or replace function public.guidance_schedule_touch()
returns trigger language plpgsql
set search_path = public
as $$
begin
  new.updated_by := auth.uid();
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists gwi_touch on public.guidance_week_institutions;
create trigger gwi_touch before insert or update on public.guidance_week_institutions
  for each row execute function public.guidance_schedule_touch();

drop trigger if exists gslots_touch on public.guidance_slots;
create trigger gslots_touch before insert or update on public.guidance_slots
  for each row execute function public.guidance_schedule_touch();

-- RLS
alter table public.guidance_week_institutions enable row level security;
alter table public.guidance_periods           enable row level security;
alter table public.guidance_slots             enable row level security;

revoke all on public.guidance_week_institutions from anon;
revoke all on public.guidance_periods           from anon;
revoke all on public.guidance_slots             from anon;

drop policy if exists gwi_read on public.guidance_week_institutions;
create policy gwi_read on public.guidance_week_institutions
  for select to authenticated using (true);
drop policy if exists gwi_write on public.guidance_week_institutions;
create policy gwi_write on public.guidance_week_institutions
  for all to authenticated using (public.iv_is_staff()) with check (public.iv_is_staff());

drop policy if exists gp_read on public.guidance_periods;
create policy gp_read on public.guidance_periods
  for select to authenticated using (true);
drop policy if exists gp_write on public.guidance_periods;
create policy gp_write on public.guidance_periods
  for all to authenticated using (public.iv_is_staff()) with check (public.iv_is_staff());

drop policy if exists gs_read on public.guidance_slots;
create policy gs_read on public.guidance_slots
  for select to authenticated using (true);
drop policy if exists gs_write on public.guidance_slots;
create policy gs_write on public.guidance_slots
  for all to authenticated using (public.iv_is_staff()) with check (public.iv_is_staff());

-- ข้อมูลเริ่มต้น: ม.3 สัปดาห์ที่ 1–20 (ตามเอกสารรายชื่อสถาบัน ภาคเรียนที่ 1/2569 ถึงต้นภาคเรียนที่ 2)
insert into public.guidance_week_institutions (level, week_no, date_start, date_end, institution) values
  ('m3', 1,  '2026-11-02', '2026-11-06', null),
  ('m3', 2,  '2026-11-09', '2026-11-13', 'วิทยาลัยเทคโนโลยีเกษมสันต์บริหารธุรกิจ'),
  ('m3', 3,  '2026-11-16', '2026-11-20', 'วิทยาลัยเทคโนโลยีบริหารธุรกิจสมุทรปราการ (Sam Tech)'),
  ('m3', 4,  '2026-11-23', '2026-11-27', null),
  ('m3', 5,  '2026-11-30', '2026-12-04', 'วิทยาลัยเทคโนโลยีสุวรรณภูมิบริหารธุรกิจ'),
  ('m3', 6,  '2026-12-07', '2026-12-11', null),
  ('m3', 7,  '2026-12-14', '2026-12-18', null),
  ('m3', 8,  '2026-12-21', '2026-12-25', null),
  ('m3', 9,  '2026-12-28', '2027-01-01', null),
  ('m3', 10, '2027-01-04', '2027-01-08', null),
  ('m3', 11, '2027-01-11', '2027-01-15', 'เกริกวิทยาลัย'),
  ('m3', 12, '2027-01-18', '2027-01-22', null),
  ('m3', 13, '2027-01-25', '2027-01-29', null),
  ('m3', 14, '2027-02-01', '2027-02-05', null),
  ('m3', 15, '2027-02-08', '2027-02-12', null),
  ('m3', 16, '2027-02-15', '2027-02-19', null),
  ('m3', 17, '2027-02-22', '2027-02-26', null),
  ('m3', 18, '2027-03-01', '2027-03-05', null),
  ('m3', 19, '2027-03-08', '2027-03-12', null),
  ('m3', 20, '2027-03-15', '2027-03-19', null)
on conflict (level, week_no) do nothing;

-- ข้อมูลเริ่มต้น: คาบเรียน ม.3 (เวลาตามหัวตารางในเอกสาร ไม่รวมพักเที่ยง)
insert into public.guidance_periods (level, period_no, label, time_text) values
  ('m3', 1, 'คาบ 1', '08.30–09.20'),
  ('m3', 2, 'คาบ 2', '09.20–10.10'),
  ('m3', 3, 'คาบ 3', '10.10–11.00'),
  ('m3', 4, 'คาบ 4', '11.00–11.50'),
  ('m3', 5, 'คาบ 5', '12.40–13.30'),
  ('m3', 6, 'คาบ 6', '13.30–14.20'),
  ('m3', 7, 'คาบ 7', '14.20–15.10'),
  ('m3', 8, 'คาบ 8', '15.10–16.00')
on conflict (level, period_no) do nothing;
