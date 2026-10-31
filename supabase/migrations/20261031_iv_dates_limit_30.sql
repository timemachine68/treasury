-- ซ้อมสัมภาษณ์: ขยายจำนวนวันสัมภาษณ์ที่ยังไม่ถึงต่อคน จาก 10 เป็น 30
create or replace function public.iv_dates_guard() returns trigger
language plpgsql security invoker set search_path = '' as $$
declare today date := (now() at time zone 'Asia/Bangkok')::date; n int;
begin
  new.target_university := nullif(btrim(coalesce(new.target_university,'')), '');
  new.target_faculty := nullif(btrim(coalesce(new.target_faculty,'')), '');
  if tg_op = 'INSERT' or new.interview_date is distinct from old.interview_date then
    if new.interview_date < today then
      raise exception 'เลือกวันที่ย้อนหลังไม่ได้ ถ้าสัมภาษณ์ไปแล้วให้ลบหรือไม่ต้องตั้งวัน';
    end if;
    if new.interview_date > today + 730 then
      raise exception 'วันที่ไกลเกินไป เลือกภายใน 2 ปีข้างหน้า';
    end if;
  end if;
  if tg_op = 'INSERT' then
    select count(*) into n from public.iv_interview_dates
      where student_id = new.student_id and interview_date >= today;
    if n >= 30 then
      raise exception 'ตั้งวันสัมภาษณ์ที่ยังไม่ถึงได้ไม่เกิน 30 วัน ลบอันที่ผ่านแล้วหรือไม่ใช้ก่อน';
    end if;
  end if;
  return new;
end $$;
