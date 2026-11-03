-- ลงทะเบียนการ์ดเกมห้องหนีในเมนูระบบ (external_systems)
insert into public.external_systems (title, description, url, icon, visible_to, sort_order, category, student_grades)
select 'เกมห้องหนี', 'เล่นเกมไขประตูหนีห้องลับกับเพื่อนในห้อง เมื่อครูเปิดรอบเล่น', 'https://timemachine68.github.io/treasury/escape-room.html', '🔐', array['student'], 18, null, array['ม.1']
where not exists (select 1 from public.external_systems where url = 'https://timemachine68.github.io/treasury/escape-room.html');

insert into public.external_systems (title, description, url, icon, visible_to, sort_order, category, student_grades)
select 'เกมห้องหนี (หน้าครู)', 'สร้างชุดคำถาม เปิดรอบเล่นรายห้อง ดูผลสด และฉายขึ้นจอ', 'https://timemachine68.github.io/treasury/escape-room-teacher.html', '🔐', array['teacher'], 19, null, null
where not exists (select 1 from public.external_systems where url = 'https://timemachine68.github.io/treasury/escape-room-teacher.html');
