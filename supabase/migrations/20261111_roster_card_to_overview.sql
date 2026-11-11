-- ย้ายทางเข้า "ทำเนียบนักเรียน" จากหน้า "ระบบของเรา" ไปไว้ที่ปุ่มในหน้า "ภาพรวมนักเรียน" (index.html)
delete from public.external_systems where url like '%student-roster.html';
