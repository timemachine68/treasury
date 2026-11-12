-- ลิงก์ประชาสัมพันธ์แนบกับแต่ละงาน Open House: [{"label":"ชื่อปุ่ม","url":"https://..."}] สูงสุด 5 ลิงก์
-- รับเฉพาะ http/https เพื่อกันลิงก์อันตราย เช่น javascript:
-- หมายเหตุ: regex ของ PostgreSQL นับซ้ำได้ไม่เกิน 255 จึงใช้ (.{250}){2} แทน .{500}
-- สิทธิ์: ใช้ policy เดิมของ open_house_events (ทุกคนที่ login อ่านได้, ครูแนะแนว/แอดมินแก้ได้)
alter table public.open_house_events
  add column info_links jsonb not null default '[]'::jsonb;

alter table public.open_house_events
  add constraint open_house_events_info_links_check check (
    jsonb_typeof(info_links) = 'array'
    and jsonb_array_length(info_links) <= 5
    and not jsonb_path_exists(info_links,
      '$[*] ? (@.type() != "object" || !exists(@.label) || !exists(@.url)
               || @.label.type() != "string" || @.url.type() != "string"
               || @.label like_regex "^\\s*$" || @.label like_regex "^.{61,}"
               || !(@.url like_regex "^https?://") || @.url like_regex "\\s"
               || @.url like_regex "^(.{250}){2}.")')
  );

comment on column public.open_house_events.info_links is
  'ลิงก์ประชาสัมพันธ์ของงาน [{"label":"ชื่อปุ่ม","url":"https://..."}] สูงสุด 5 รายการ รับเฉพาะ http/https';
