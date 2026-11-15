-- แอป PA (pa-app.html): เก็บหลักฐาน PA ทุกชนิด + เกียรติบัตรการอบรม/พัฒนาตนเอง (ID Plan)
-- ไฟล์จริงอยู่ใน Google Drive (Apps Script ตัวเดียวกับส่งงานนักเรียน) ฐานข้อมูลเก็บแค่รายละเอียด
-- ทุกอย่างเห็นเฉพาะเจ้าของ (ไม่มีสิทธิ์ผู้ประเมิน/ครูแนะแนวคนอื่น/admin อ่านข้อมูลคนอื่น)

-- ───────── pa_cycles: 1 เล่มต่อคนต่อปีงบ ─────────
create unique index if not exists pa_cycles_owner_fy_uq
  on public.pa_cycles (owner_id, fiscal_year) where deleted_at is null;
alter table public.pa_cycles
  add constraint pa_cycles_data_size check (pg_column_size(data) < 1500000);

-- ───────── pa_trainings: การอบรม/พัฒนาตนเอง ─────────
create table public.pa_trainings (
  id            uuid primary key default gen_random_uuid(),
  owner_id      uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title         text not null check (char_length(btrim(title)) between 3 and 300),
  organizer     text check (organizer is null or char_length(organizer) <= 200),
  kind          text not null default 'อบรม'
                check (kind in ('อบรม','ประชุมเชิงปฏิบัติการ','สัมมนา','ศึกษาดูงาน','PLC','ศึกษาด้วยตนเอง','อื่น ๆ')),
  mode          text not null default 'onsite' check (mode in ('onsite','online','hybrid')),
  start_date    date not null,
  end_date      date not null,
  hours         numeric(5,1) not null default 0 check (hours >= 0 and hours <= 500),
  fiscal_year   smallint generated always as
                ((extract(year from start_date)::int + case when extract(month from start_date) >= 10 then 1 else 0 end + 543)::smallint) stored,
  indicators    text[] not null default array['3.1']
                check (indicators <@ array['1.1','1.2','1.3','1.4','1.5','1.6','1.7','1.8','2.1','2.2','2.3','2.4','3.1','3.2','3.3']),
  idplan_topic  text check (idplan_topic is null or char_length(idplan_topic) <= 60),
  applied_note  text check (applied_note is null or char_length(applied_note) <= 2000),
  cert_no       text check (cert_no is null or char_length(cert_no) <= 100),
  link_url      text check (link_url is null or (link_url ~* '^https?://' and char_length(link_url) <= 1000)),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz,
  check (end_date >= start_date and end_date - start_date <= 366),
  check (start_date >= date '2015-01-01')
);
comment on table public.pa_trainings is 'การอบรม/พัฒนาตนเองของครู (แอป PA) — เห็นเฉพาะเจ้าของ';

-- กันบันทึกซ้ำ: เรื่องเดียวกัน วันเริ่มเดียวกัน
create unique index pa_trainings_dup_uq
  on public.pa_trainings (owner_id, lower(btrim(title)), start_date) where deleted_at is null;
create index pa_trainings_owner_fy_idx on public.pa_trainings (owner_id, fiscal_year) where deleted_at is null;

create trigger pa_trainings_touch before update on public.pa_trainings
  for each row execute function public.pa_set_updated_at();

-- เจ้าของเปลี่ยนไม่ได้
create or replace function public.pa_trainings_guard()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.owner_id is distinct from old.owner_id then
    raise exception 'เปลี่ยนเจ้าของรายการไม่ได้ค่ะ';
  end if;
  return new;
end $$;
create trigger pa_trainings_guard before update on public.pa_trainings
  for each row execute function public.pa_trainings_guard();

alter table public.pa_trainings enable row level security;

create policy "pa trainings select own" on public.pa_trainings
  for select to authenticated using (owner_id = (select auth.uid()));
create policy "pa trainings insert own" on public.pa_trainings
  for insert to authenticated with check (
    owner_id = (select auth.uid())
    and (select public.get_my_role()) = any (array['teacher','admin']));
create policy "pa trainings update own" on public.pa_trainings
  for update to authenticated using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

-- ───────── pa_evidence: ทะเบียนไฟล์ใน Drive (ตารางยังว่าง ปรับโครงได้) ─────────
alter table public.pa_evidence drop constraint if exists pa_evidence_check;
alter table public.pa_evidence drop constraint if exists pa_evidence_kind_check;
alter table public.pa_evidence drop constraint if exists pa_evidence_indicator_check;
alter table public.pa_evidence alter column cycle_id drop not null;
alter table public.pa_evidence alter column indicator drop not null;
alter table public.pa_evidence
  add column training_id   uuid references public.pa_trainings(id) on delete cascade,
  add column item_id       text check (item_id is null or char_length(item_id) <= 40),
  add column drive_file_id text,
  add column file_name     text check (file_name is null or char_length(file_name) <= 200),
  add column size_bytes    integer check (size_bytes is null or (size_bytes > 0 and size_bytes <= 10485760)),
  add column is_shared     boolean not null default false;
alter table public.pa_evidence
  add constraint pa_evidence_kind_check check (kind in ('photo','cert','file')),
  add constraint pa_evidence_indicator_check check (indicator is null or indicator = any
      (array['1.1','1.2','1.3','1.4','1.5','1.6','1.7','1.8','2.1','2.2','2.3','2.4','3.1','3.2','3.3'])),
  add constraint pa_evidence_parent_check check (num_nonnulls(cycle_id, training_id) = 1),
  add constraint pa_evidence_drive_check check (drive_file_id is not null and drive_file_id ~ '^[A-Za-z0-9_-]{10,200}$'),
  add constraint pa_evidence_mime_check check (mime in ('image/jpeg','image/png','application/pdf'));
create unique index pa_evidence_item_uq on public.pa_evidence (owner_id, item_id)
  where deleted_at is null and item_id is not null;
create index pa_evidence_cycle_idx on public.pa_evidence (cycle_id) where deleted_at is null;
create index pa_evidence_training_idx on public.pa_evidence (training_id) where deleted_at is null;

-- เขียนไฟล์ได้เฉพาะผ่าน RPC (กันอ้าง drive_file_id ของคนอื่น); เปลี่ยนเจ้าของ/ที่อยู่ไม่ได้
create or replace function public.pa_evidence_guard()
returns trigger language plpgsql set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    if coalesce(current_setting('app.pa_drive_rpc', true), '') <> '1' then
      raise exception 'เพิ่มไฟล์หลักฐานได้จากปุ่มในแอป PA เท่านั้นค่ะ';
    end if;
  else
    if new.drive_file_id is distinct from old.drive_file_id
       or new.owner_id is distinct from old.owner_id
       or new.cycle_id is distinct from old.cycle_id
       or new.training_id is distinct from old.training_id
       or new.kind is distinct from old.kind
       or new.mime is distinct from old.mime then
      raise exception 'แก้ไขข้อมูลไฟล์นี้ไม่ได้ค่ะ';
    end if;
    if new.is_shared is distinct from old.is_shared
       and coalesce(current_setting('app.pa_drive_rpc', true), '') <> '1' then
      raise exception 'เปิด/ปิดการแชร์ได้จากปุ่มในแอป PA เท่านั้นค่ะ';
    end if;
  end if;
  return new;
end $$;
create trigger pa_evidence_guard before insert or update on public.pa_evidence
  for each row execute function public.pa_evidence_guard();

drop policy if exists "pa owner inserts own evidence" on public.pa_evidence;
create policy "pa owner inserts own evidence" on public.pa_evidence
  for insert to authenticated with check (
    owner_id = (select auth.uid())
    and (select public.get_my_role()) = any (array['teacher','admin'])
    and (
      (cycle_id is not null and exists (select 1 from public.pa_cycles c
         where c.id = pa_evidence.cycle_id and c.owner_id = (select auth.uid()) and c.deleted_at is null))
      or
      (training_id is not null and exists (select 1 from public.pa_trainings t
         where t.id = pa_evidence.training_id and t.owner_id = (select auth.uid()) and t.deleted_at is null))
    ));

-- ───────── สิทธิ์ระดับตาราง ─────────
revoke all on public.pa_cycles, public.pa_evidence, public.pa_trainings from anon, public;
revoke delete, truncate, references, trigger on public.pa_cycles, public.pa_evidence, public.pa_trainings from authenticated;
grant select, insert, update on public.pa_cycles, public.pa_evidence, public.pa_trainings to authenticated;

-- ───────── RPC สำหรับ Apps Script (SECURITY INVOKER — RLS ตัดสินสิทธิ์) ─────────

-- ตรวจว่าผู้เรียกเป็นเจ้าของเล่ม/รายการอบรม และคืนชื่อโฟลเดอร์
create or replace function public.pa_drive_context(p_cycle_id uuid, p_training_id uuid)
returns jsonb language plpgsql stable set search_path = 'public' as $$
declare v_name text; v_fy int; v_title text; v_role text;
begin
  if auth.uid() is null then raise exception 'กรุณาเข้าสู่ระบบก่อนค่ะ'; end if;
  select role into v_role from public.profiles where id = auth.uid();
  if v_role is null or v_role not in ('teacher','admin') then
    raise exception 'แอป PA ใช้ได้เฉพาะบัญชีครูค่ะ';
  end if;
  if num_nonnulls(p_cycle_id, p_training_id) <> 1 then raise exception 'ข้อมูลไม่ถูกต้องค่ะ'; end if;
  select coalesce(nullif(btrim(display_name), ''), 'ครู') into v_name from public.profiles where id = auth.uid();
  if p_cycle_id is not null then
    select fiscal_year into v_fy from public.pa_cycles where id = p_cycle_id and deleted_at is null;
    if v_fy is null then raise exception 'ไม่พบเล่ม PA ปีนี้ ลองโหลดหน้าใหม่ค่ะ'; end if;
    if (select count(*) from public.pa_evidence where cycle_id = p_cycle_id and deleted_at is null) >= 400 then
      raise exception 'เล่มนี้มีไฟล์หลักฐานครบ 400 ไฟล์แล้ว ลบไฟล์ที่ไม่ใช้ก่อนนะคะ';
    end if;
  else
    select fiscal_year, title into v_fy, v_title from public.pa_trainings where id = p_training_id and deleted_at is null;
    if v_fy is null then raise exception 'ไม่พบรายการอบรมนี้ ลองโหลดหน้าใหม่ค่ะ'; end if;
    if (select count(*) from public.pa_evidence where training_id = p_training_id and deleted_at is null) >= 15 then
      raise exception 'รายการอบรมนี้มีไฟล์ครบ 15 ไฟล์แล้วค่ะ';
    end if;
  end if;
  return jsonb_build_object('owner_name', v_name, 'owner_key', left(auth.uid()::text, 8),
                            'fiscal_year', v_fy, 'training_title', v_title);
end $$;

-- บันทึกไฟล์ที่อัปโหลดแล้ว (Apps Script เรียกหลังสร้างไฟล์ใน Drive)
create or replace function public.pa_drive_record(
  p_cycle_id uuid, p_training_id uuid, p_item_id text, p_kind text, p_indicator text,
  p_drive_file_id text, p_file_name text, p_mime text, p_size integer,
  p_width integer default null, p_height integer default null)
returns jsonb language plpgsql set search_path = 'public' as $$
declare v_id uuid;
begin
  perform public.pa_drive_context(p_cycle_id, p_training_id);
  perform set_config('app.pa_drive_rpc', '1', true);
  insert into public.pa_evidence (cycle_id, training_id, owner_id, item_id, kind, indicator,
      drive_file_id, file_name, mime, size_bytes, width, height, storage_path, url)
  values (p_cycle_id, p_training_id, auth.uid(), nullif(left(p_item_id, 40), ''), p_kind,
      nullif(p_indicator, ''), p_drive_file_id, left(coalesce(p_file_name, 'หลักฐาน'), 200), p_mime, p_size,
      p_width, p_height, null, null)
  returning id into v_id;
  perform set_config('app.pa_drive_rpc', '', true);
  return jsonb_build_object('id', v_id);
exception when unique_violation then
  perform set_config('app.pa_drive_rpc', '', true);
  raise exception 'ไฟล์นี้บันทึกไว้แล้วค่ะ';
end $$;

-- ขอเปิดไฟล์ (เจ้าของเท่านั้น)
create or replace function public.pa_drive_check(p_evidence_id uuid)
returns jsonb language plpgsql stable set search_path = 'public' as $$
declare r record;
begin
  select drive_file_id, file_name, mime into r from public.pa_evidence
   where id = p_evidence_id and owner_id = auth.uid() and deleted_at is null;
  if r.drive_file_id is null then raise exception 'ไม่พบไฟล์นี้ หรือไม่มีสิทธิ์เปิดค่ะ'; end if;
  return jsonb_build_object('drive_file_id', r.drive_file_id, 'file_name', r.file_name, 'mime', r.mime);
end $$;

-- นำไฟล์ออก (ซ่อนในระบบ แล้ว Apps Script ย้ายไฟล์ลงถังขยะ Drive)
create or replace function public.pa_drive_remove(p_evidence_id uuid)
returns jsonb language plpgsql set search_path = 'public' as $$
declare v_file text;
begin
  update public.pa_evidence set deleted_at = now()
   where id = p_evidence_id and owner_id = auth.uid() and deleted_at is null
  returning drive_file_id into v_file;
  if v_file is null then raise exception 'ไม่พบไฟล์นี้ หรือนำออกไปแล้วค่ะ'; end if;
  return jsonb_build_object('drive_file_id', v_file);
end $$;

-- เปิด/ปิด "ทุกคนที่มีลิงก์ดูได้" (ใช้ทำ QR ในรูปเล่ม)
create or replace function public.pa_drive_set_shared(p_evidence_id uuid, p_shared boolean)
returns jsonb language plpgsql set search_path = 'public' as $$
declare v_file text;
begin
  perform set_config('app.pa_drive_rpc', '1', true);
  update public.pa_evidence set is_shared = coalesce(p_shared, false)
   where id = p_evidence_id and owner_id = auth.uid() and deleted_at is null
  returning drive_file_id into v_file;
  perform set_config('app.pa_drive_rpc', '', true);
  if v_file is null then raise exception 'ไม่พบไฟล์นี้ หรือไม่มีสิทธิ์ค่ะ'; end if;
  return jsonb_build_object('drive_file_id', v_file);
end $$;

revoke all on function public.pa_drive_context(uuid, uuid) from public, anon;
revoke all on function public.pa_drive_record(uuid, uuid, text, text, text, text, text, text, integer, integer, integer) from public, anon;
revoke all on function public.pa_drive_check(uuid) from public, anon;
revoke all on function public.pa_drive_remove(uuid) from public, anon;
revoke all on function public.pa_drive_set_shared(uuid, boolean) from public, anon;
revoke all on function public.pa_evidence_guard() from public, anon;
revoke all on function public.pa_trainings_guard() from public, anon;
grant execute on function public.pa_drive_context(uuid, uuid) to authenticated;
grant execute on function public.pa_drive_record(uuid, uuid, text, text, text, text, text, text, integer, integer, integer) to authenticated;
grant execute on function public.pa_drive_check(uuid) to authenticated;
grant execute on function public.pa_drive_remove(uuid) to authenticated;
grant execute on function public.pa_drive_set_shared(uuid, boolean) to authenticated;
