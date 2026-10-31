-- งานที่นักเรียนส่ง: เห็นได้เฉพาะเจ้าของงาน + ครูแนะแนว + แอดมิน (บัญชีกลุ่มสาระไม่เห็น) — 31 ต.ค. 2569
drop policy if exists "see submissions" on public.submissions;
create policy "see submissions" on public.submissions
  for select to authenticated
  using (student_id = (select auth.uid()) or (select public.iv_is_staff()));

-- ไฟล์ในบักเก็ต submissions (ไฟล์แบบเดิม): เจ้าของโฟลเดอร์ + ครูแนะแนว + แอดมิน
drop policy if exists "read submissions files" on storage.objects;
create policy "read submissions files" on storage.objects
  for select to authenticated
  using (bucket_id = 'submissions' and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or (select public.iv_is_staff())));
