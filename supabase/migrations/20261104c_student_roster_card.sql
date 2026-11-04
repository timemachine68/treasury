-- การ์ด "ทำเนียบนักเรียน" ในหน้า "ระบบของเรา" (เห็นเฉพาะแอดมิน เหมือนการ์ดโปรไฟล์นักเรียนรวม)
insert into public.external_systems (title, description, url, icon, visible_to, sort_order)
select 'ทำเนียบนักเรียน',
       'ดูรูป ชื่อ-สกุล ชื่อเล่น เป็นรายห้อง และพิมพ์ใบติดบอร์ดห้อง A4',
       'https://timemachine68.github.io/treasury/student-roster.html',
       '🌼', array['admin'], 19
where not exists (select 1 from public.external_systems where url like '%student-roster.html');
