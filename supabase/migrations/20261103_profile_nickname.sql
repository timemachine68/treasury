-- ชื่อเล่น: นักเรียน (และครู) ตั้งชื่อเล่นของตัวเองได้ที่หน้า profile.html เหมือนการเปลี่ยนรูปโปรไฟล์
-- ไม่เปิด policy update ทั้งแถวให้เจ้าของบัญชี (กันแก้ role/class_room ของตัวเอง)
-- ใช้ฟังก์ชัน security definer ที่แก้ได้เฉพาะคอลัมน์ nickname ของ auth.uid() ตัวเองเท่านั้น (แบบเดียวกับ update_my_avatar)

alter table public.profiles add column if not exists nickname text;

alter table public.profiles drop constraint if exists profiles_nickname_check;
alter table public.profiles add constraint profiles_nickname_check
  check (nickname is null or (char_length(nickname) between 1 and 20 and nickname !~ '[[:cntrl:]]'));

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
  update public.profiles set nickname = v where id = auth.uid();
end;
$$;

revoke all on function public.update_my_nickname(text) from public, anon;
grant execute on function public.update_my_nickname(text) to authenticated;
