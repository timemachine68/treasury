-- งานมอบหมาย: เพิ่มวิธีส่ง "ลิงก์ Canva" และ "ไฟล์ PDF/รูป ไป Google Drive" (31 ต.ค. 2569)
--
-- เป้าหมาย: ไม่ให้นักเรียนส่งไฟล์เข้า Supabase Storage (กินพื้นที่โปรเจ็ค)
--   - canva : เก็บแค่ลิงก์ใน submissions.external_url
--   - drive : ไฟล์ไปอยู่ใน Drive บัญชีโรงเรียนผ่าน Apps Script, เก็บแค่ drive_file_id ในตาราง
-- งานเดิม (text / file / link / any) และข้อมูลเดิมไม่ถูกแตะ

-- 1) ชนิดการส่งงานใหม่
alter table public.assignments drop constraint if exists assignments_submission_type_check;
alter table public.assignments add constraint assignments_submission_type_check
  check (submission_type in ('text','file','link','any','canva','drive'));

-- 2) คอลัมน์ไฟล์ใน Drive (ว่างทั้งหมดสำหรับแถวเดิม)
alter table public.submissions
  add column if not exists drive_file_id text,
  add column if not exists drive_mime text,
  add column if not exists drive_size integer;

alter table public.submissions drop constraint if exists submissions_drive_shape_check;
alter table public.submissions add constraint submissions_drive_shape_check
  check (
    drive_file_id is null
    or (
      drive_file_id ~ '^[A-Za-z0-9_-]{15,100}$'
      and drive_mime in ('application/pdf','image/jpeg','image/png')
      and drive_size between 1 and 10485760
      and file_path is null and external_url is null and text_answer is null
    )
  );

-- 3) ตรวจรูปแบบตามชนิดงาน (ตรวจเฉพาะแถวที่เพิ่ม/แก้ — แถวเดิมไม่ถูกตรวจย้อนหลัง)
--    drive_file_id เขียนได้เฉพาะผ่าน RPC drive_submit_record (กันนักเรียนยัดรหัสไฟล์เองผ่าน API ตรง)
create or replace function public.submissions_validate_by_type()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare v_type text;
begin
  select submission_type into v_type from public.assignments where id = new.assignment_id;

  if (tg_op = 'INSERT' and new.drive_file_id is not null)
     or (tg_op = 'UPDATE' and new.drive_file_id is not null
         and new.drive_file_id is distinct from old.drive_file_id) then
    if coalesce(current_setting('app.drive_rpc', true), '') <> '1' then
      raise exception 'การส่งไฟล์ไป Drive ต้องกดปุ่มส่งงานในระบบเท่านั้นค่ะ';
    end if;
  end if;

  if v_type = 'canva' then
    if new.external_url is null
       or new.external_url !~* '^https://((www\.)?canva\.com/design/|canva\.link/)[A-Za-z0-9_-]+' then
      raise exception 'ลิงก์ต้องเป็นลิงก์ Canva (ขึ้นต้นด้วย https://www.canva.com/design/ หรือ https://canva.link/) ค่ะ';
    end if;
  elsif v_type = 'drive' then
    if new.drive_file_id is null then
      raise exception 'งานนี้ต้องส่งเป็นไฟล์ PDF หรือรูป ผ่านปุ่มส่งงานค่ะ';
    end if;
  elsif new.drive_file_id is not null then
    raise exception 'งานนี้ไม่ได้ให้ส่งเป็นไฟล์ไป Drive ค่ะ';
  end if;
  return new;
end $$;

drop trigger if exists submissions_validate_by_type on public.submissions;
create trigger submissions_validate_by_type
  before insert or update on public.submissions
  for each row execute function public.submissions_validate_by_type();

revoke all on function public.submissions_validate_by_type() from public, anon, authenticated;

-- 4) RPC ที่ Apps Script เรียกด้วย token ของนักเรียน/ครู (SECURITY INVOKER = RLS เดิมทำงานเต็มที่)

-- 4.1 นักเรียนขอส่งงาน: ตรวจว่าเป็นนักเรียน งานนี้ถูกมอบหมายให้ห้องตัวเอง และเป็นงานชนิด drive
create or replace function public.drive_submit_context(p_assignment_id uuid)
returns jsonb
language plpgsql
stable
security invoker
set search_path = public
as $$
declare
  v_me record;
  v_a record;
  v_old text;
begin
  select id, role, username, student_id, display_name, class_room
    into v_me from public.profiles where id = auth.uid();
  if v_me.id is null or v_me.role <> 'student' then
    raise exception 'เฉพาะนักเรียนเท่านั้นที่ส่งงานได้ค่ะ';
  end if;

  -- RLS ของ assignments: นักเรียนเห็นเฉพาะงานของห้องตัวเอง
  select id, title, submission_type into v_a from public.assignments where id = p_assignment_id;
  if v_a.id is null then
    raise exception 'ไม่พบงานนี้ หรืองานนี้ไม่ได้มอบหมายให้ห้องของเรา ลองโหลดหน้าใหม่ค่ะ';
  end if;
  if v_a.submission_type <> 'drive' then
    raise exception 'งานนี้ไม่ได้ให้ส่งเป็นไฟล์ PDF/รูปค่ะ';
  end if;

  select drive_file_id into v_old from public.submissions
   where assignment_id = p_assignment_id and student_id = v_me.id;

  return jsonb_build_object(
    'student_code', coalesce(nullif(v_me.student_id,''), v_me.username),
    'display_name', v_me.display_name,
    'class_room',   coalesce(nullif(v_me.class_room,''), 'ไม่ระบุห้อง'),
    'assignment_title', v_a.title,
    'old_drive_file_id', v_old
  );
end $$;

-- 4.2 บันทึกว่าส่งแล้ว (เรียกหลัง Apps Script เก็บไฟล์ลง Drive สำเร็จ) — ส่งใหม่ = แทนที่ของเดิม
create or replace function public.drive_submit_record(
  p_assignment_id uuid, p_drive_file_id text, p_file_name text,
  p_mime text, p_size integer, p_note text default null)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_ctx jsonb;
  v_id uuid;
begin
  v_ctx := public.drive_submit_context(p_assignment_id);
  perform set_config('app.drive_rpc', '1', true);

  insert into public.submissions
    (assignment_id, student_id, drive_file_id, drive_mime, drive_size, file_name, note, submitted_at)
  values
    (p_assignment_id, auth.uid(), p_drive_file_id, p_mime, p_size,
     left(coalesce(p_file_name,'ไฟล์งาน'), 200), nullif(left(coalesce(p_note,''), 500), ''), now())
  on conflict (assignment_id, student_id) do update set
    drive_file_id = excluded.drive_file_id,
    drive_mime    = excluded.drive_mime,
    drive_size    = excluded.drive_size,
    file_name     = excluded.file_name,
    note          = excluded.note,
    submitted_at  = now(),
    file_path = null, external_url = null, text_answer = null
  returning id into v_id;

  perform set_config('app.drive_rpc', '', true);
  return jsonb_build_object('submission_id', v_id, 'old_drive_file_id', v_ctx->>'old_drive_file_id');
end $$;

-- 4.3 ขอเปิดไฟล์: คืนรหัสไฟล์ได้เฉพาะเจ้าของงานหรือครู/แอดมิน (ตาม RLS ของ submissions)
create or replace function public.drive_view_check(p_submission_id uuid)
returns jsonb
language plpgsql
stable
security invoker
set search_path = public
as $$
declare v record;
begin
  select drive_file_id, drive_mime, file_name into v
    from public.submissions where id = p_submission_id;
  if v.drive_file_id is null then
    raise exception 'ไม่พบไฟล์นี้ หรือไม่มีสิทธิ์เปิดดูค่ะ';
  end if;
  return jsonb_build_object('drive_file_id', v.drive_file_id, 'mime', v.drive_mime, 'file_name', v.file_name);
end $$;

revoke all on function public.drive_submit_context(uuid) from public, anon;
revoke all on function public.drive_submit_record(uuid, text, text, text, integer, text) from public, anon;
revoke all on function public.drive_view_check(uuid) from public, anon;
grant execute on function public.drive_submit_context(uuid) to authenticated;
grant execute on function public.drive_submit_record(uuid, text, text, text, integer, text) to authenticated;
grant execute on function public.drive_view_check(uuid) to authenticated;
