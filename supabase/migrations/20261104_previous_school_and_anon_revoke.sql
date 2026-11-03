-- 1) ปิดสิทธิ์เขียนของ role anon ทั้งสคีมา public
--    anon key อยู่ในหน้าเว็บ (สาธารณะ) เดิม anon มีสิทธิ์ TRUNCATE/DELETE/INSERT/UPDATE บนเกือบทุกตาราง
--    TRUNCATE ไม่ถูก RLS ควบคุม จึงล้างตารางได้ทั้งตาราง. policy ที่มีอยู่ทุกตัวตรวจ auth.uid()/get_my_role()
--    ซึ่งเป็น null สำหรับ anon อยู่แล้ว จึงไม่มีการเขียนของ anon ที่ถูกต้องตามกฎใดที่ต้องเสียไป
--    คงสิทธิ์ SELECT ของ anon ไว้ (RLS ยังกรองอยู่)
revoke insert, update, delete, truncate, references, trigger on all tables in schema public from anon;

-- 2) ชื่อโรงเรียนเดิมของนักเรียน (นักเรียนกรอกเอง ที่หน้า profile.html)
alter table public.profiles add column if not exists previous_school text;

alter table public.profiles drop constraint if exists profiles_previous_school_check;
alter table public.profiles add constraint profiles_previous_school_check
  check (previous_school is null or (char_length(previous_school) between 1 and 100 and previous_school !~ '[[:cntrl:]]'));

-- แก้ได้เฉพาะแถวของตัวเอง และเฉพาะนักเรียน (แบบเดียวกับ update_my_nickname)
create or replace function public.update_my_previous_school(p_school text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v text := nullif(btrim(p_school), '');
begin
  if auth.uid() is null then
    raise exception 'กรุณาเข้าสู่ระบบก่อน';
  end if;
  if get_my_role() is distinct from 'student' then
    raise exception 'ฟังก์ชันนี้สำหรับนักเรียนเท่านั้น';
  end if;
  if v is not null and char_length(v) > 100 then
    raise exception 'ชื่อโรงเรียนต้องไม่เกิน 100 ตัวอักษร';
  end if;
  if v is not null and v ~ '[[:cntrl:]]' then
    raise exception 'ชื่อโรงเรียนมีตัวอักษรที่ใช้ไม่ได้';
  end if;
  update public.profiles set previous_school = v where id = auth.uid();
end;
$$;

revoke all on function public.update_my_previous_school(text) from public, anon;
grant execute on function public.update_my_previous_school(text) to authenticated;
