-- กรองคำไม่เหมาะสมในชื่อเล่น
-- เก็บคำต้องห้ามในตาราง nickname_blocklist (ครู/admin แก้ได้ผ่าน admin เท่านั้น)
-- กติกา:
--   * คำไทย: ตรงกับชื่อเล่นทั้งชื่อหลังตัดช่องว่าง/สัญลักษณ์ออก (กัน false positive เช่น "ห่าง" มี "ห่า")
--   * คำอังกฤษ (>= 4 ตัว): ถ้าชื่อเล่นมีคำนี้อยู่ข้างใน ก็บล็อก
-- ตั้งใจให้ฟังก์ชันตรวจเป็น security definer และไม่ให้ใคร execute ตรง ๆ เพื่อไม่ให้ใครไล่ดูรายการคำได้

create table if not exists public.nickname_blocklist (
  word text primary key check (word = lower(word) and char_length(word) between 2 and 30)
);

alter table public.nickname_blocklist enable row level security;

drop policy if exists "admin manage nickname blocklist" on public.nickname_blocklist;
create policy "admin manage nickname blocklist" on public.nickname_blocklist
  for all to authenticated
  using (get_my_role() = 'admin')
  with check (get_my_role() = 'admin');

insert into public.nickname_blocklist (word) values
  ('ควย'),('หี'),('เย็ด'),('เย็ดแม่'),('สัส'),('เหี้ย'),('ห่า'),('ชาติหมา'),
  ('ระยำ'),('แม่ง'),('อีดอก'),('อีสัตว์'),('ไอ้สัตว์'),('ไอ้เวร'),('กระหรี่'),
  ('ส้นตีน'),('ตีน'),('อีเหี้ย'),('อีสาด'),('ไอ้สาด'),('ควาย'),('สันดาน'),('จู๋'),
  ('fuck'),('shit'),('bitch'),('asshole'),('dick'),('pussy'),('cunt'),('nigger'),('faggot')
on conflict (word) do nothing;

create or replace function public.nickname_is_blocked(p_text text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  with norm as (
    select lower(regexp_replace(coalesce(p_text, ''), '[^[:alnum:]ก-๙]', '', 'g')) as t
  )
  select exists (
    select 1 from public.nickname_blocklist b, norm
    where norm.t <> ''
      and (
        norm.t = b.word
        or (b.word ~ '^[a-z0-9]+$' and char_length(b.word) >= 4 and position(b.word in norm.t) > 0)
      )
  );
$$;

revoke all on function public.nickname_is_blocked(text) from public, anon, authenticated;

-- อัปเดตฟังก์ชันตั้งชื่อเล่นให้ตรวจคำต้องห้ามด้วย (คงสิทธิ์เดิม: execute ได้เฉพาะ authenticated)
create or replace function public.update_my_nickname(new_nick text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v text := nullif(btrim(new_nick), '');
begin
  if auth.uid() is null then
    raise exception 'กรุณาเข้าสู่ระบบก่อน';
  end if;
  if v is not null and char_length(v) > 20 then
    raise exception 'ชื่อเล่นต้องไม่เกิน 20 ตัวอักษร';
  end if;
  if v is not null and v ~ '[[:cntrl:]]' then
    raise exception 'ชื่อเล่นมีตัวอักษรที่ใช้ไม่ได้';
  end if;
  if v is not null and public.nickname_is_blocked(v) then
    raise exception 'ชื่อเล่นนี้ไม่เหมาะสม กรุณาตั้งชื่อใหม่';
  end if;
  update public.profiles set nickname = v where id = auth.uid();
end;
$$;

-- ล้างชื่อเล่นเดิมที่เข้าข่ายคำต้องห้าม (ที่ตั้งไว้ก่อนมีตัวกรอง)
update public.profiles
   set nickname = null
 where nickname is not null
   and public.nickname_is_blocked(nickname);
