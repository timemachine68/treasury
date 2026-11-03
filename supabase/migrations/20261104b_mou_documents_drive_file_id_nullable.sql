-- ลิงก์เอกสาร MOU ที่วางเข้ามาอาจไม่ใช่รูปแบบ Drive (หาไฟล์ไอดีไม่ได้) จึงไม่บังคับ drive_file_id
-- (หน้า mou.html เดิมไม่ส่ง drive_file_id ทำให้เพิ่มลิงก์เอกสารไม่ได้: null value ... violates not-null constraint)
alter table public.mou_documents alter column drive_file_id drop not null;
