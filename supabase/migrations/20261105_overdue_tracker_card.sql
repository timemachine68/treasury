-- การ์ด "ติดตามงานเลยกำหนด" ในหน้า "ระบบของเรา" (ครูแนะแนวและแอดมินเห็น ผ่านหน้าที่ตรวจสิทธิ์เอง; การ์ดแสดงเฉพาะแอดมินเหมือนทำเนียบนักเรียน)
insert into public.external_systems (title, description, url, icon, visible_to, sort_order)
select 'ติดตามงานเลยกำหนด',
       'ดูว่านักเรียนคนไหนยังไม่ส่งงานที่เลยกำหนด แยกตามห้อง คัดลอกหรือพิมพ์รายชื่อได้',
       'https://timemachine68.github.io/treasury/overdue-tracker.html',
       '⏰', array['admin'], 20
where not exists (select 1 from public.external_systems where url like '%overdue-tracker.html');
