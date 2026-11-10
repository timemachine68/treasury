-- บันทึกนักเรียนที่ได้โควตาเอง (ครูบันทึกเพิ่ม) — ลงฐานข้อมูลจริงแล้วผ่าน apply_migration
-- ดูนิยามฟังก์ชันล่าสุดได้ที่ pg_get_functiondef: compute_quota_scores, quota_set_status, quota_on_seat_freed,
-- quota_add_manual, quota_remove_manual
-- สรุป: เพิ่มคอลัมน์ quota_applications.is_manual; compute/ที่นั่ง/auto-promote ข้ามรายการ manual;
-- quota_add_manual (เจ้าหน้าที่เท่านั้น, status=approved) และ quota_remove_manual (ลบได้เฉพาะ manual)
alter table public.quota_applications add column if not exists is_manual boolean not null default false;
