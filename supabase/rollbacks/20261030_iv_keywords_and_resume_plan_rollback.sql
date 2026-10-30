-- ย้อนกลับ 20261030_iv_keywords_and_resume_plan.sql (และข้อมูลคำสำคัญที่เติมไว้ในไฟล์ _backfill)
alter table public.iv_questions drop constraint if exists iv_questions_keywords_len;
alter table public.iv_questions drop column if exists keywords;
alter table public.iv_sessions drop constraint if exists iv_sessions_plan_len;
alter table public.iv_sessions drop column if exists plan_question_ids;
