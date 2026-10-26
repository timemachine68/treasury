-- หน้าแรก (home.html): ปฏิทินกำหนดการ + ปักหมุดข่าว + ปิดไม่ให้คนนอกอ่านข่าว
-- 26 ต.ค. 2569

-- 1) ตารางกำหนดการ (สอบระดับชาติ / TCAS / งานแนะแนว / อื่น ๆ)
create table if not exists public.calendar_events (
  id          uuid primary key default gen_random_uuid(),
  title       text not null check (char_length(btrim(title)) between 1 and 200),
  category    text not null check (category in ('national','tcas','guidance','other')),
  start_date  date not null,
  end_date    date,
  link_url    text check (link_url is null or link_url ~* '^https?://'),
  note        text check (note is null or char_length(note) <= 1000),
  created_by  uuid references public.profiles(id) on delete set null default auth.uid(),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint calendar_events_dates_ok check (end_date is null or end_date >= start_date)
);

-- กันกรอกซ้ำ: ชื่อเดียวกัน (ไม่สนตัวพิมพ์/ช่องว่างหัวท้าย) + วันเริ่มเดียวกัน
create unique index if not exists calendar_events_no_dup
  on public.calendar_events (lower(btrim(title)), start_date);
create index if not exists calendar_events_dates on public.calendar_events (start_date, end_date);

create or replace function public.calendar_events_touch()
returns trigger language plpgsql set search_path = public as $$
begin
  new.updated_at := now();
  new.created_by := old.created_by;   -- เปลี่ยนเจ้าของไม่ได้
  new.created_at := old.created_at;
  return new;
end $$;
drop trigger if exists calendar_events_touch on public.calendar_events;
create trigger calendar_events_touch before update on public.calendar_events
  for each row execute function public.calendar_events_touch();

alter table public.calendar_events enable row level security;

drop policy if exists "cal read logged in" on public.calendar_events;
create policy "cal read logged in" on public.calendar_events
  for select to authenticated using ((select auth.uid()) is not null);

drop policy if exists "cal staff insert" on public.calendar_events;
create policy "cal staff insert" on public.calendar_events
  for insert to authenticated with check ((select public.iv_is_staff()));

drop policy if exists "cal staff update" on public.calendar_events;
create policy "cal staff update" on public.calendar_events
  for update to authenticated using ((select public.iv_is_staff())) with check ((select public.iv_is_staff()));

drop policy if exists "cal staff delete" on public.calendar_events;
create policy "cal staff delete" on public.calendar_events
  for delete to authenticated using ((select public.iv_is_staff()));

revoke all on public.calendar_events from anon;
grant select, insert, update, delete on public.calendar_events to authenticated;

-- 2) ปักหมุดข่าว
alter table public.announcements
  add column if not exists is_pinned boolean not null default false,
  add column if not exists pinned_until date;

-- 3) ข่าวเห็นเฉพาะคนที่เข้าสู่ระบบแล้ว (เดิมคนนอกที่มี key หน้าเว็บอ่านได้)
drop policy if exists "see active announcements" on public.announcements;
create policy "see active announcements" on public.announcements
  for select to authenticated
  using ((is_active = true) or (select public.can_manage_announcements()));

revoke all on public.announcements from anon;
revoke all on public.announcement_reads from anon;

drop policy if exists "auth read announcement files" on storage.objects;
create policy "auth read announcement files" on storage.objects
  for select to authenticated using (bucket_id = 'announcements');
