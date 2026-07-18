-- เฟส 2: checklist เตรียมตัวสอบสัมภาษณ์ (รายการกลาง + สถานะติ๊กรายนักเรียน)
-- หมายเหตุ: migration นี้ถูก apply กับโปรเจกต์ guidance-library แล้วเมื่อ 2026-07-18
-- (seed รายการตั้งต้น 22 รายการอยู่ในฐานข้อมูลแล้ว)

create table public.iv_checklist_items (
  id uuid primary key default gen_random_uuid(),
  group_name text not null,
  title text not null,
  detail text,
  sort_order int not null default 0,
  is_active boolean not null default true,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.iv_checklist_done (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.iv_checklist_items(id) on delete cascade,
  student_id uuid not null references public.profiles(id) on delete cascade,
  done_at timestamptz not null default now(),
  unique (item_id, student_id)
);
create index iv_checklist_done_student_idx on public.iv_checklist_done(student_id);

alter table public.iv_checklist_items enable row level security;
alter table public.iv_checklist_done enable row level security;

create policy "authenticated read iv_checklist_items" on public.iv_checklist_items
  for select to authenticated using (true);
create policy "staff write iv_checklist_items" on public.iv_checklist_items
  for all to authenticated
  using (get_my_role() in ('teacher','admin'))
  with check (get_my_role() in ('teacher','admin'));

create policy "own or staff read iv_checklist_done" on public.iv_checklist_done
  for select to authenticated
  using (student_id = auth.uid() or get_my_role() in ('teacher','admin'));
create policy "student check own" on public.iv_checklist_done
  for insert to authenticated
  with check (student_id = auth.uid());
create policy "student uncheck own" on public.iv_checklist_done
  for delete to authenticated
  using (student_id = auth.uid());
