-- ระบบซ้อมสัมภาษณ์ (iv_*): เพิ่มโครงสร้างสำหรับ
--  1) ซ้อมต่อจากที่ค้างไว้: iv_sessions.plan_question_ids = รายการคำถามที่สุ่มไว้ตอนเริ่มเซ็ต
--  2) ตัวช่วยตรวจเบื้องต้น: iv_questions.keywords = คำสำคัญของแต่ละคำถาม (ยกโครงสร้างมาจากคลังคำถามของระบบซ้อมสัมภาษณ์ฉบับสาธารณะ)
-- ไม่เพิ่มตารางใหม่ จึงใช้ RLS เดิมของ iv_sessions / iv_questions ได้เลย
--   iv_sessions : นักเรียนแก้ได้เฉพาะเซ็ตที่ยังเป็นฉบับร่างของตัวเอง
--   iv_questions: ทุกคนที่ล็อกอินอ่านได้ แก้ได้เฉพาะครูแนะแนว/แอดมิน

alter table public.iv_sessions
  add column if not exists plan_question_ids uuid[];

alter table public.iv_sessions
  add constraint iv_sessions_plan_len
  check (plan_question_ids is null or cardinality(plan_question_ids) <= 20);

comment on column public.iv_sessions.plan_question_ids is
  'รายการ id คำถามที่สุ่มไว้ตอนเริ่มเซ็ต (เรียงตามลำดับข้อ) ใช้ให้นักเรียนซ้อมต่อได้ถ้าออกจากหน้าไปก่อนตอบครบ';

alter table public.iv_questions
  add column if not exists keywords text[] not null default '{}';

alter table public.iv_questions
  add constraint iv_questions_keywords_len
  check (cardinality(keywords) <= 20);

comment on column public.iv_questions.keywords is
  'คำสำคัญ 3-6 คำ ใช้ตรวจเบื้องต้นว่าคำตอบแตะประเด็นสำคัญหรือยัง (เป็นตัวช่วย ไม่ใช่คะแนนจริง)';
