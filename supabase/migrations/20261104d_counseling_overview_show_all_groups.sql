-- ภาพรวม/รายงานการให้คำปรึกษา: แสดงทุกห้อง/ทุกสถานะ ไม่ซ่อนกลุ่มที่น้อยกว่า 3 ราย (4 พ.ย. 2569)
-- เหตุผล: ผู้เรียกได้ต้องเป็นครูแนะแนว/admin ซึ่งเห็นเคสรายคนได้อยู่แล้ว
create or replace function public.counseling_overview()
returns jsonb
language plpgsql
stable security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_empty jsonb := jsonb_build_object(
    'totals', jsonb_build_object('total_all_time',0,'total_this_month',0,'total_open',0,'total_overdue',0),
    'categories', '[]'::jsonb, 'rooms', '[]'::jsonb, 'statuses', '[]'::jsonb);
begin
  if not public.iv_is_staff() then return v_empty; end if;
  return jsonb_build_object(
    'totals', (select jsonb_build_object(
        'total_all_time', count(*),
        'total_this_month', count(*) filter (where date_trunc('month', session_date::timestamptz) = date_trunc('month', current_date::timestamptz)),
        'total_open', count(*) filter (where status in ('ติดตามต่อ','นัดครั้งถัดไป')),
        'total_overdue', count(*) filter (where status = 'นัดครั้งถัดไป'
            and next_appointment_date < (now() at time zone 'Asia/Bangkok')::date))
      from public.counseling_logs where deleted_at is null),
    'categories', coalesce((select jsonb_agg(jsonb_build_object('category', c.cat, 'total', c.n) order by c.n desc, c.cat)
      from (select cat, count(*)::int n from public.counseling_logs l, lateral unnest(l.categories) cat
            where l.deleted_at is null group by cat) c), '[]'::jsonb),
    'rooms', coalesce((select jsonb_agg(jsonb_build_object('room', r.room, 'total', r.n) order by r.n desc, r.room)
      from (select p.class_room room, count(*)::int n from public.counseling_logs l
            join public.profiles p on p.id = l.student_id
            where l.deleted_at is null group by p.class_room) r), '[]'::jsonb),
    'statuses', coalesce((select jsonb_agg(jsonb_build_object('status', s.st, 'total', s.n) order by s.n desc, s.st)
      from (select status st, count(*)::int n from public.counseling_logs
            where deleted_at is null group by status) s), '[]'::jsonb));
end $function$;

create or replace function public.counseling_annual_report(p_academic_year integer)
returns json language plpgsql security definer set search_path to 'public' as $function$
declare
  v_start date; v_end date; v_result json;
begin
  if not public.iv_is_staff() then
    raise exception 'ไม่มีสิทธิ์เข้าถึงรายงานนี้' using errcode = '42501';
  end if;
  v_start := make_date(p_academic_year - 543, 5, 16);
  v_end   := make_date(p_academic_year - 543 + 1, 3, 31);
  select json_build_object(
    'academic_year', p_academic_year, 'period_start', v_start, 'period_end', v_end,
    'total_cases', (select count(*) from counseling_logs where deleted_at is null and session_date between v_start and v_end),
    'total_students', (select count(distinct student_id) from counseling_logs where deleted_at is null and session_date between v_start and v_end),
    'by_status', (select coalesce(json_agg(t order by t.total desc), '[]'::json) from (
        select status, count(*) as total from counseling_logs
        where deleted_at is null and session_date between v_start and v_end group by status) t),
    'by_category', (select coalesce(json_agg(t order by t.total desc), '[]'::json) from (
        select cat as category, count(*) as total from counseling_logs, unnest(categories) as cat
        where deleted_at is null and session_date between v_start and v_end group by cat) t),
    'by_month', (select coalesce(json_agg(t order by t.month), '[]'::json) from (
        select to_char(date_trunc('month', session_date), 'YYYY-MM') as month, count(*) as total
        from counseling_logs where deleted_at is null and session_date between v_start and v_end group by 1) t),
    'by_room', (select coalesce(json_agg(t order by t.total desc), '[]'::json) from (
        select p.class_room as room, count(*) as total from counseling_logs cl
        join profiles p on p.id = cl.student_id
        where cl.deleted_at is null and cl.session_date between v_start and v_end
        group by p.class_room) t)
  ) into v_result;
  return v_result;
end; $function$;

revoke all on function public.counseling_annual_report(integer) from public, anon;
revoke all on function public.counseling_overview() from public, anon;
grant execute on function public.counseling_annual_report(integer) to authenticated;
grant execute on function public.counseling_overview() to authenticated;
