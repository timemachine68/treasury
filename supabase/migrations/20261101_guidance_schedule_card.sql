-- ลงทะเบียนการ์ด "ตารางแนะแนวรายคาบ" ในเมนูระบบ (external_systems)
insert into public.external_systems (title, description, url, icon, visible_to, sort_order, category, student_grades)
select 'ตารางแนะแนวรายคาบ', 'ดูสัปดาห์ที่สถาบันเข้าแนะแนวและตารางคาบของ ม.3 และ ม.6 (ครูแนะแนวแก้ไขได้)', 'https://timemachine68.github.io/treasury/guidance-schedule.html', '🗓', array['teacher','student'], 17, null, array['ม.3','ม.6']
where not exists (select 1 from public.external_systems where url = 'https://timemachine68.github.io/treasury/guidance-schedule.html');
