-- หมวดหมู่ข่าวประชาสัมพันธ์ (ใช้เป็นแท็บในหน้าหลัก)
alter table public.announcements add column if not exists category text;
alter table public.announcements drop constraint if exists announcements_category_check;
alter table public.announcements add constraint announcements_category_check
  check (category is null or category in ('quota','tcas','scholarship','award'));

-- จัดหมวดข่าวเดิม
update public.announcements set category='scholarship' where category is null and title like 'ทุน%';
update public.announcements set category='tcas' where category is null and (title like '%คะแนน%' or title like '%เกณฑ์ประกาศรับสมัคร%' or title ilike '%TCAS%');
