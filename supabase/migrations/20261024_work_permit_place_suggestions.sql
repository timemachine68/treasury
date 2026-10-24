-- รายชื่อสถานที่ที่เคยมีผู้ขอ (เฉพาะชื่อสถานที่ ไม่มีข้อมูลนักเรียน) ใช้ช่วยพิมพ์ในฟอร์มนักเรียน
create or replace function public.work_permit_place_suggestions()
returns table(place text)
language sql
stable
security definer
set search_path = public
as $$
  select min(btrim(regexp_replace(employer_name, '\s+', ' ', 'g'))) as place
  from public.work_permit_requests
  where status <> 'cancelled' and btrim(employer_name) <> ''
  group by lower(btrim(regexp_replace(employer_name, '\s+', ' ', 'g')))
  order by count(*) desc, 1
  limit 300;
$$;

revoke execute on function public.work_permit_place_suggestions() from public, anon;
grant execute on function public.work_permit_place_suggestions() to authenticated;
