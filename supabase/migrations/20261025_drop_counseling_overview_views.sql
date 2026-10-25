-- รันหลังจาก counseling-log.html เวอร์ชันที่เรียก counseling_overview() ขึ้นเว็บจริงแล้วเท่านั้น
-- (ถ้ารันก่อน หน้าสรุปภาพรวมเวอร์ชันเก่าจะโหลดไม่ได้)
drop view if exists public.counseling_overview_totals;
drop view if exists public.counseling_overview_categories;
drop view if exists public.counseling_overview_by_room;
