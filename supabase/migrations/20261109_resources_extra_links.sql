-- คลังแนะแนว: เพิ่มช่องเก็บ "ลิงก์เพิ่มเติม" หลายลิงก์ต่อรายการ [{label,url}] สูงสุด 10
-- RLS เดิมของ resources ใช้ต่อได้ (อ่าน: ผู้ล็อกอิน / เพิ่ม-แก้-ลบ: ครูเจ้าของหรือแอดมิน)
alter table public.resources
  add column if not exists extra_links jsonb not null default '[]'::jsonb;
alter table public.resources
  drop constraint if exists resources_extra_links_is_array;
alter table public.resources
  add constraint resources_extra_links_is_array
  check (jsonb_typeof(extra_links) = 'array' and jsonb_array_length(extra_links) <= 10);
