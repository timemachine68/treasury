-- ค่าปรับรูปการ์ดแสดงความยินดี (ครูแนะแนวตั้ง) แยกตาราง เพื่อไม่ให้นักเรียนแก้เองได้
-- ใช้กับ card-photo-fx.js (จัดกรอบตามหน้า / ปรับแสง / เปลี่ยนพื้นหลัง) — ใช้งานบน Supabase แล้ว 9 พ.ย. 2569
create table if not exists public.survey_card_photo_fx (
  response_id uuid primary key references public.survey_responses(id) on delete cascade,
  photo_path  text not null,          -- รูปต้นฉบับที่ใช้ปรับ ถ้านักเรียนเปลี่ยนรูป ค่านี้ไม่ตรง = ไม่ใช้
  fx          jsonb not null check (pg_column_size(fx) < 4000),
  mask_path   text,                   -- <student_id>/fx-<response_id>.png (เมื่อเปลี่ยนพื้นหลัง)
  updated_by  uuid references public.profiles(id) on delete set null,
  updated_at  timestamptz not null default now()
);
alter table public.survey_card_photo_fx enable row level security;

drop policy if exists "read own or staff photo fx" on public.survey_card_photo_fx;
create policy "read own or staff photo fx" on public.survey_card_photo_fx
  for select to authenticated using (
    (select public.iv_is_staff())
    or exists (select 1 from public.survey_responses s where s.id = response_id and s.student_id = (select auth.uid()))
  );
drop policy if exists "staff insert photo fx" on public.survey_card_photo_fx;
create policy "staff insert photo fx" on public.survey_card_photo_fx
  for insert to authenticated with check (
    (select public.iv_is_staff())
    and (mask_path is null or mask_path = (select s.student_id::text from public.survey_responses s where s.id = response_id) || '/fx-' || response_id::text || '.png')
  );
drop policy if exists "staff update photo fx" on public.survey_card_photo_fx;
create policy "staff update photo fx" on public.survey_card_photo_fx
  for update to authenticated using ((select public.iv_is_staff())) with check (
    (select public.iv_is_staff())
    and (mask_path is null or mask_path = (select s.student_id::text from public.survey_responses s where s.id = response_id) || '/fx-' || response_id::text || '.png')
  );
drop policy if exists "staff delete photo fx" on public.survey_card_photo_fx;
create policy "staff delete photo fx" on public.survey_card_photo_fx
  for delete to authenticated using ((select public.iv_is_staff()));
revoke all on public.survey_card_photo_fx from anon;
grant select, insert, update, delete on public.survey_card_photo_fx to authenticated;

-- ครูแนะแนวเขียนไฟล์ mask (fx-*.png) ลงโฟลเดอร์นักเรียนได้ นักเรียนอ่านผ่านนโยบายเดิม (โฟลเดอร์ตัวเอง)
drop policy if exists "staff write card fx mask" on storage.objects;
create policy "staff write card fx mask" on storage.objects
  for insert to authenticated with check (bucket_id = 'survey-photos' and storage.filename(name) like 'fx-%.png' and (select public.iv_is_staff()));
drop policy if exists "staff update card fx mask" on storage.objects;
create policy "staff update card fx mask" on storage.objects
  for update to authenticated using (bucket_id = 'survey-photos' and storage.filename(name) like 'fx-%.png' and (select public.iv_is_staff()));
drop policy if exists "staff delete card fx mask" on storage.objects;
create policy "staff delete card fx mask" on storage.objects
  for delete to authenticated using (bucket_id = 'survey-photos' and storage.filename(name) like 'fx-%.png' and (select public.iv_is_staff()));
