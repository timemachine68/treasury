-- เปิด/ปิดการมองเห็นตารางแนะแนวของนักเรียน ต่อระดับชั้น (ม.3 / ม.6)
-- ครู/admin เห็นเสมอ นักเรียนเห็นเฉพาะระดับที่เปิดไว้ (กันที่ฐานข้อมูล ไม่ใช่แค่ซ่อนปุ่ม)
-- รันแล้วใน Supabase เมื่อ 1 พ.ย. 2569 (policy อ่านใช้ ALTER POLICY เพื่อไม่ให้ช่วงว่างสิทธิ์)

create table if not exists public.guidance_schedule_settings (
  level             text primary key check (level in ('m3','m6')),
  show_to_students  boolean not null default true,
  updated_by        uuid references auth.users(id) on delete set null,
  updated_at        timestamptz not null default now()
);
insert into public.guidance_schedule_settings (level, show_to_students) values ('m3', true), ('m6', true) on conflict (level) do nothing;
create trigger gss_touch before insert or update on public.guidance_schedule_settings for each row execute function public.guidance_schedule_touch();
alter table public.guidance_schedule_settings enable row level security;
revoke all on public.guidance_schedule_settings from anon;
create policy gss_read on public.guidance_schedule_settings for select to authenticated using (true);
create policy gss_write on public.guidance_schedule_settings for all to authenticated using (public.iv_is_staff()) with check (public.iv_is_staff());

-- ตัดสินว่าผู้ใช้คนนี้อ่านข้อมูลของระดับนี้ได้หรือไม่
create or replace function public.guidance_can_read(p_level text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role in ('admin','teacher')
  )
  or coalesce(
    (select s.show_to_students from public.guidance_schedule_settings s where s.level = p_level),
    true
  );
$$;
revoke all on function public.guidance_can_read(text) from public, anon;
grant execute on function public.guidance_can_read(text) to authenticated;

-- เปลี่ยน policy อ่านของตารางข้อมูลให้เช็คการตั้งค่า
alter policy gwi_read on public.guidance_week_institutions using (public.guidance_can_read(level));
alter policy gp_read  on public.guidance_periods            using (public.guidance_can_read(level));
alter policy gcp_read on public.guidance_class_periods      using (public.guidance_can_read(level));
alter policy gvs_read on public.guidance_visit_slots        using (exists (select 1 from public.guidance_week_institutions w where w.id = week_id and public.guidance_can_read(w.level)));
