-- ติดตามเคสให้คำปรึกษา + ครูแนะแนว/admin อ่านเคสได้ทุกคน (4 พ.ย. 2569)
-- ครูกลุ่มสาระ/นักเรียน/anon ไม่เห็น; แก้ได้เฉพาะบันทึกของตัวเอง

-- 1) คอลัมน์ใหม่
alter table public.counseling_logs
  add column if not exists next_appointment_date date,
  add column if not exists referral_to text,
  add column if not exists referral_note text,
  add column if not exists closed_at timestamptz;

alter table public.counseling_logs
  drop constraint if exists counseling_logs_referral_len_check;
alter table public.counseling_logs
  add constraint counseling_logs_referral_len_check
  check ((referral_to is null or char_length(referral_to) <= 120)
     and (referral_note is null or char_length(referral_note) <= 500));

-- 2) กฎของสถานะเคส (ตรวจที่ฐานข้อมูล ไม่พึ่งหน้าเว็บ)
create or replace function public.counseling_case_guard()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.referral_to   := nullif(btrim(new.referral_to), '');
  new.referral_note := nullif(btrim(new.referral_note), '');

  if tg_op = 'UPDATE' and old.status = 'ปิดเคส' and new.status is distinct from old.status then
    raise exception 'เคสที่ปิดแล้วเปลี่ยนสถานะไม่ได้ ถ้าบันทึกผิดให้ลบแล้วบันทึกใหม่' using errcode = '23514';
  end if;

  if new.next_appointment_date is not null and new.next_appointment_date < new.session_date then
    raise exception 'วันนัดครั้งถัดไปต้องไม่ก่อนวันที่ให้คำปรึกษา' using errcode = '23514';
  end if;

  if new.status = 'นัดครั้งถัดไป' and new.next_appointment_date is null then
    raise exception 'กรุณาใส่วันนัดครั้งถัดไป' using errcode = '23514';
  end if;

  if new.status = 'ส่งต่อ' and new.referral_to is null then
    raise exception 'กรุณาบอกว่าส่งต่อไปที่ใด' using errcode = '23514';
  end if;

  if new.status = 'ปิดเคส' then
    new.next_appointment_date := null;
    if tg_op = 'UPDATE' and old.status = 'ปิดเคส' then
      new.closed_at := coalesce(old.closed_at, now());
    else
      new.closed_at := now();
    end if;
  else
    new.closed_at := null;
  end if;

  return new;
end $$;

drop trigger if exists trg_counseling_case_guard on public.counseling_logs;
create trigger trg_counseling_case_guard
  before insert or update on public.counseling_logs
  for each row execute function public.counseling_case_guard();

-- 3) ดัชนีสำหรับ "งานค้าง" และไทม์ไลน์รายนักเรียน
create index if not exists counseling_logs_open_idx
  on public.counseling_logs (counselor_id, next_appointment_date)
  where deleted_at is null and status in ('ติดตามต่อ', 'นัดครั้งถัดไป');
create index if not exists counseling_logs_student_idx
  on public.counseling_logs (student_id, session_date desc)
  where deleted_at is null;

-- 4) สิทธิ์: อ่าน = ครูแนะแนว/admin (ของตัวเองอ่านได้เสมอ), เขียน/แก้ = เฉพาะของตัวเองและต้องเป็นครูแนะแนว/admin
drop policy if exists "counselor selects own logs" on public.counseling_logs;
drop policy if exists "counselor inserts own logs" on public.counseling_logs;
drop policy if exists "counselor updates own logs" on public.counseling_logs;

create policy "staff select counseling logs" on public.counseling_logs
  for select to authenticated
  using (
    counselor_id = (select auth.uid())
    or (deleted_at is null and (select public.iv_is_staff()))
  );

create policy "staff insert own counseling logs" on public.counseling_logs
  for insert to authenticated
  with check (
    counselor_id = (select auth.uid())
    and (select public.iv_is_staff())
  );

create policy "staff update own counseling logs" on public.counseling_logs
  for update to authenticated
  using (counselor_id = (select auth.uid()) and (select public.iv_is_staff()))
  with check (counselor_id = (select auth.uid()) and (select public.iv_is_staff()));

-- รูปแนบ: ครูแนะแนว/admin ดูได้ทุกโฟลเดอร์ (เขียน/ลบยังเฉพาะเจ้าของโฟลเดอร์ตาม policy เดิม)
drop policy if exists "staff read counseling photos" on storage.objects;
create policy "staff read counseling photos" on storage.objects
  for select to authenticated
  using (bucket_id = 'counseling-photos' and (select public.iv_is_staff()));

-- 5) ถอนสิทธิ์ที่ไม่จำเป็นกับตารางนี้
revoke truncate, references, trigger on public.counseling_logs from authenticated, anon;

-- 6) สรุปภาพรวม (ไม่ระบุตัวตน): เพิ่มจำนวนเคสเกินนัด + แยกตามสถานะ (ซ่อนกลุ่ม < 3)
create or replace function public.counseling_overview()
returns jsonb
language plpgsql
stable security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_empty jsonb := jsonb_build_object(
    'totals', jsonb_build_object('total_all_time',0,'total_this_month',0,'total_open',0,'total_overdue',0),
    'categories', '[]'::jsonb, 'rooms', '[]'::jsonb,
    'statuses', '[]'::jsonb, 'hidden_status_cases', 0);
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
            where l.deleted_at is null group by p.class_room having count(*) >= 3) r), '[]'::jsonb),
    'statuses', coalesce((select jsonb_agg(jsonb_build_object('status', s.st, 'total', s.n) order by s.n desc, s.st)
      from (select status st, count(*)::int n from public.counseling_logs
            where deleted_at is null group by status having count(*) >= 3) s), '[]'::jsonb),
    'hidden_status_cases', coalesce((select sum(n) from (select count(*)::int n from public.counseling_logs
            where deleted_at is null group by status having count(*) < 3) h), 0));
end $function$;
