-- นักเรียนลบคำขอของตัวเองได้เฉพาะที่ครูยังไม่รับเรื่อง (ยื่นแล้ว/ยกเลิก)
create policy work_permit_student_delete on public.work_permit_requests
  for delete to authenticated
  using (student_id = auth.uid() and status in ('submitted','cancelled'));

-- ครูแนะแนว/แอดมิน ลบได้ทุกคำขอ
create policy work_permit_teacher_delete on public.work_permit_requests
  for delete to authenticated
  using (get_my_role() = 'admin' or (select is_guidance from public.profiles where id = auth.uid()));
