-- สรุปทุนการศึกษาประจำปี: เดิมหน้า scholarship-annual-summary.html ดึงข้อมูลจาก
-- v_scholarship_awards / v_scholarship_annual_summary ตรงๆ ด้วย anon key ซึ่งสอง view
-- นี้ถูก grant SELECT ให้ anon ไว้ (query ตรงๆ ได้โดยไม่ต้อง login เลย) — รั่วชื่อ-สกุล
-- และเลขประจำตัวนักเรียนที่ได้รับทุนออกสู่สาธารณะ
--
-- ย้ายมาใช้ฟังก์ชัน security definer ที่เช็คสิทธิ์ role แบบเดียวกับ counseling_annual_report
-- แล้วปิดการเข้าถึง view ทั้งสองตรงๆ จาก anon/authenticated เพื่อบังคับให้ผ่าน RPC นี้เท่านั้น

create or replace function public.scholarship_annual_summary()
returns json
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_result json;
begin
  if coalesce(public.get_my_role(), '') not in ('teacher', 'admin') then
    raise exception 'ไม่มีสิทธิ์เข้าถึงรายงานนี้';
  end if;

  select json_build_object(
    'summary', (
      select coalesce(json_agg(t), '[]'::json) from (
        select academic_year, scholarship_id, scholarship_name, provider,
               amount_per_grant, class_level, awarded_count, total_amount, avg_score
        from public.v_scholarship_annual_summary
        order by academic_year desc, scholarship_name
      ) t
    ),
    'awards', (
      select coalesce(json_agg(t), '[]'::json) from (
        select application_id, scholarship_id, academic_year, scholarship_name, provider,
               amount_per_grant, profile_id, display_name, student_id, class_room, class_level,
               total_score, awarded_at
        from public.v_scholarship_awards
        order by awarded_at desc
      ) t
    )
  ) into v_result;

  return v_result;
end;
$function$;

-- หมายเหตุ: ต้อง revoke จาก anon ตรงๆ ด้วย เพราะ default privileges ของโปรเจกต์นี้
-- grant EXECUTE ให้ anon ทุกฟังก์ชันใหม่โดยอัตโนมัติ แค่ revoke from public เฉยๆ ไม่พอ
revoke all on function public.scholarship_annual_summary() from public, anon;
grant execute on function public.scholarship_annual_summary() to authenticated;

revoke all on public.v_scholarship_awards from anon, authenticated;
revoke all on public.v_scholarship_annual_summary from anon, authenticated;
