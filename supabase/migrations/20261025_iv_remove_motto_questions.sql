-- ระบบซ้อมสัมภาษณ์: ลบคำถามที่อ้างปรัชญา/คติพจน์/คำขวัญของมหาวิทยาลัย (13 ข้อ)
-- (ใช้กับฐานข้อมูลจริงแล้วเมื่อ 24 ต.ค. 2569 — ตรวจแล้วว่าไม่มีคำตอบของนักเรียนผูกกับข้อเหล่านี้)
delete from public.iv_questions q
using public.iv_universities u
where u.id = q.university_id
  and (q.question_text ~ 'ปรัชญา|คติพจน์|คำขวัญ|ปณิธาน|ค่านิยม|พระบรมราโชวาท|motto|philosophy|slogan'
       or q.question_text ~ 'คติของ|ศาสตร์แห่งแผ่นดิน|ฉันรักธรรมศาสตร์'
       or coalesce(q.guide_answer,'') ~ 'ปรัชญา|คติพจน์|คำขวัญ|motto|ปณิธาน')
  and not exists (select 1 from public.iv_answers a where a.question_id = q.id);
