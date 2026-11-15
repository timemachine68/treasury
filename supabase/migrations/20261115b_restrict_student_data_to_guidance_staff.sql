-- 15 พ.ย. 2569 — ข้อมูลนักเรียนรายคน เห็นได้เฉพาะเจ้าของ + ครูแนะแนว + แอดมิน (iv_is_staff)
-- รันบนฐานข้อมูลจริงแล้ว ไฟล์นี้เก็บไว้เป็นประวัติ
drop policy if exists "read own or staff read all" on public.profiles;
create policy "read own or guidance staff read all" on public.profiles
  for select using (id = (select auth.uid()) or (select public.iv_is_staff()));

drop policy if exists "see assessments" on public.strength_assessments;
create policy "see assessments" on public.strength_assessments
  for select using (student_id = (select auth.uid()) or (select public.iv_is_staff()));

drop policy if exists "see tags" on public.strength_tags;
create policy "see tags" on public.strength_tags
  for select using (student_id = (select auth.uid()) or (select public.iv_is_staff()));

drop policy if exists "staff give tags" on public.strength_tags;
create policy "staff give tags" on public.strength_tags
  for insert with check ((select public.iv_is_staff()) and tagged_by = (select auth.uid()));

drop policy if exists "avatar read own or staff" on storage.objects;
create policy "avatar read own or guidance staff" on storage.objects
  for select to authenticated using (
    bucket_id = 'profile-photos' and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or (select public.iv_is_staff())));
