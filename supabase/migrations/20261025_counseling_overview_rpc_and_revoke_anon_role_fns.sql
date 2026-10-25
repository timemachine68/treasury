-- ชุดแก้ความปลอดภัย (1) สรุปภาพรวมการให้คำปรึกษา (2) ปิดสิทธิ์คนไม่ล็อกอินเรียก get_my_role/get_my_room
--
-- (1) วิว counseling_overview_* เป็น SECURITY DEFINER (ข้าม RLS ของ counseling_logs โดยตั้งใจ เพื่อให้ครูเห็นสรุปรวมทุกคน)
--     แต่ตั้ง security_invoker=true ไม่ได้ เพราะครูจะเห็นสรุปเฉพาะของตัวเอง
--     จึงเปลี่ยนเป็นฟังก์ชันที่เช็กสิทธิ์ในตัวและคืนเฉพาะตัวเลขรวม (ไม่มีรายแถว ไม่มีชื่อนักเรียน)
--     ห้องที่มีบันทึกน้อยกว่า 3 รายการไม่แสดง (กันระบุตัวนักเรียน) ตามวิวเดิม
-- ขั้นถัดไป (หลังหน้าเว็บใหม่ขึ้นแล้ว): ลบวิวเก่า — ดูไฟล์ 20261025_drop_counseling_overview_views.sql

create or replace function public.counseling_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_empty jsonb := jsonb_build_object(
    'totals', jsonb_build_object('total_all_time',0,'total_this_month',0,'total_open',0),
    'categories', '[]'::jsonb,
    'rooms', '[]'::jsonb);
begin
  -- ครูและแอดมินเท่านั้น คนอื่นได้ค่าว่าง (เหมือนวิวเดิม)
  if coalesce(public.get_my_role(), '') not in ('teacher','admin') then
    return v_empty;
  end if;

  return jsonb_build_object(
    'totals', (
      select jsonb_build_object(
        'total_all_time',   count(*),
        'total_this_month', count(*) filter (where date_trunc('month', session_date::timestamptz) = date_trunc('month', current_date::timestamptz)),
        'total_open',       count(*) filter (where status in ('ติดตามต่อ','นัดครั้งถัดไป')))
      from public.counseling_logs where deleted_at is null),
    'categories', coalesce((
      select jsonb_agg(jsonb_build_object('category', c.cat, 'total', c.n) order by c.n desc, c.cat)
      from (select cat, count(*)::int n
              from public.counseling_logs l, lateral unnest(l.categories) cat
             where l.deleted_at is null group by cat) c), '[]'::jsonb),
    'rooms', coalesce((
      select jsonb_agg(jsonb_build_object('room', r.room, 'total', r.n) order by r.n desc, r.room)
      from (select p.class_room room, count(*)::int n
              from public.counseling_logs l join public.profiles p on p.id = l.student_id
             where l.deleted_at is null group by p.class_room having count(*) >= 3) r), '[]'::jsonb)
  );
end $$;

revoke all on function public.counseling_overview() from public, anon;
grant execute on function public.counseling_overview() to authenticated;

-- (2) คนไม่ล็อกอินไม่ต้องเรียกสองฟังก์ชันนี้ (policy ที่ใช้งานกับผู้ใช้ล็อกอินไม่กระทบ)
revoke execute on function public.get_my_role() from public, anon;
revoke execute on function public.get_my_room() from public, anon;
grant  execute on function public.get_my_role() to authenticated;
grant  execute on function public.get_my_room() to authenticated;
