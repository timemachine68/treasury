-- แบบสำรวจเรียนต่อ: เก็บทุกที่ที่ติด + ที่ที่เลือกเรียน 1 ที่ + สถานะตรวจการ์ดแสดงความยินดี (31 ต.ค. 2569)
-- หลักการ: ที่ที่เลือก (is_chosen) จะถูกคัดลอกกลับไปที่ survey_responses (status/institution/program/tcas_round/university_id)
-- อัตโนมัติ เพื่อให้รายงานประจำปี หน้าภาพรวม และของเดิมที่อ่าน survey_responses ใช้ต่อได้โดยไม่ต้องแก้

-- ───────── 1) ตารางที่ที่ติด ─────────
create table public.survey_admissions (
  id uuid primary key default gen_random_uuid(),
  response_id uuid not null references public.survey_responses(id) on delete cascade,
  student_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null check (kind in ('university','higher_voc','m4_here','m4_other','vocational','nfe','other')),
  institution text not null check (char_length(institution) between 2 and 150),
  university_id uuid references public.iv_universities(id) on delete set null,
  faculty text check (faculty is null or char_length(faculty) <= 150),
  major text check (major is null or char_length(major) <= 150),
  admit_round text check (admit_round is null or char_length(admit_round) <= 60),
  is_chosen boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
comment on table public.survey_admissions is 'ทุกที่ที่นักเรียนติด (แบบสำรวจเรียนต่อ) — is_chosen = ที่ที่เลือกเรียน ได้ 1 ที่ต่อคำตอบ';
create index survey_admissions_response_idx on public.survey_admissions(response_id);
create index survey_admissions_student_idx on public.survey_admissions(student_id);
create unique index survey_admissions_one_chosen on public.survey_admissions(response_id) where is_chosen;
create unique index survey_admissions_no_dup on public.survey_admissions
  (response_id, kind, public.norm_th(institution), coalesce(public.norm_th(faculty), ''), coalesce(public.norm_th(major), ''));

-- ───────── 2) คอลัมน์สถานะการ์ดในคำตอบ ─────────
alter table public.survey_responses
  add column card_status text check (card_status in ('pending','approved','returned')),
  add column card_note text check (card_note is null or char_length(card_note) <= 300),
  add column card_changed boolean not null default false,
  add column card_snapshot jsonb,
  add column card_reviewed_by uuid references public.profiles(id) on delete set null,
  add column card_reviewed_at timestamptz;

-- ข้อมูลที่การ์ดใช้ (ใช้เทียบว่าเปลี่ยนไปหลังครูตรวจหรือไม่)
create or replace function public.survey_card_key(p_inst text, p_program text, p_photo text)
returns jsonb language sql immutable set search_path = public, pg_temp
as $$ select jsonb_build_object('inst', coalesce(p_inst,''), 'program', coalesce(p_program,''), 'photo', coalesce(p_photo,'')) $$;

-- ───────── 3) ตรวจ/จัดข้อมูลก่อนบันทึกที่ที่ติด ─────────
create or replace function public.survey_admissions_guard()
returns trigger language plpgsql set search_path = public, pg_temp
as $$
declare v_grade text; v_owner uuid; v_uname text; v_n int;
begin
  if tg_op = 'UPDATE' and (new.response_id <> old.response_id) then
    raise exception 'ย้ายข้อมูลไปคำตอบอื่นไม่ได้';
  end if;
  select s.student_id, r.grade into v_owner, v_grade
    from public.survey_responses s join public.survey_rounds r on r.id = s.round_id
   where s.id = new.response_id;
  if v_owner is null then raise exception 'ไม่พบคำตอบแบบสำรวจ'; end if;
  new.student_id := v_owner;

  new.institution := nullif(btrim(regexp_replace(coalesce(new.institution,''), '\s+', ' ', 'g')), '');
  new.faculty     := nullif(btrim(regexp_replace(coalesce(new.faculty,''), '\s+', ' ', 'g')), '');
  new.major       := nullif(btrim(regexp_replace(coalesce(new.major,''), '\s+', ' ', 'g')), '');
  new.admit_round := nullif(btrim(coalesce(new.admit_round,'')), '');

  if v_grade = 'ม.6' and new.kind not in ('university','higher_voc') then
    raise exception 'ประเภทไม่ตรงกับ ม.6';
  elsif v_grade = 'ม.3' and new.kind not in ('m4_here','m4_other','vocational','nfe','other') then
    raise exception 'ประเภทไม่ตรงกับ ม.3';
  end if;

  if new.kind = 'm4_here' then new.institution := 'โรงเรียนพูลเจริญวิทยาคม'; end if;
  if new.institution is null then raise exception 'กรุณาใส่ชื่อสถานศึกษา'; end if;

  if new.kind = 'university' then
    if tg_op = 'UPDATE' and new.institution is distinct from old.institution
       and new.university_id is not distinct from old.university_id then
      new.university_id := null;
    end if;
    if new.university_id is null then new.university_id := public.match_university(new.institution); end if;
    if new.university_id is not null then
      select name into v_uname from public.iv_universities where id = new.university_id;
      if v_uname is null then new.university_id := null; else new.institution := v_uname; end if;
    end if;
  else
    new.university_id := null;
  end if;

  if tg_op = 'INSERT' then
    select count(*) into v_n from public.survey_admissions where response_id = new.response_id;
    if v_n >= 15 then raise exception 'ใส่ได้ไม่เกิน 15 ที่ต่อคน'; end if;
  end if;

  -- เลือกที่ใหม่ → ปลดที่เดิมออกก่อน (เลือกได้ที่เดียว)
  if new.is_chosen and (tg_op = 'INSERT' or not old.is_chosen) then
    update public.survey_admissions set is_chosen = false
     where response_id = new.response_id and id <> new.id and is_chosen;
  end if;

  new.updated_at := now();
  if tg_op = 'INSERT' then new.created_at := now(); end if;
  return new;
end $$;

create trigger survey_admissions_guard before insert or update on public.survey_admissions
  for each row execute function public.survey_admissions_guard();

-- ───────── 4) ให้คำตอบตามที่ที่เลือก + คำนวณสถานะการ์ด ─────────
create or replace function public.survey_responses_zz_admission_card()
returns trigger language plpgsql set search_path = public, pg_temp
as $$
declare a record; v_grade text; v_key jsonb; v_ok boolean;
begin
  select * into a from public.survey_admissions where response_id = new.id and is_chosen limit 1;

  if a.id is not null then
    new.status := case a.kind
      when 'university' then 'มหาวิทยาลัย'
      when 'higher_voc' then 'ปวส./ปวช.ต่อเนื่อง'
      when 'm4_here' then 'ต่อ ม.4 โรงเรียนเดิม'
      when 'm4_other' then 'ต่อ ม.4 โรงเรียนอื่น'
      when 'vocational' then 'ปวช.'
      when 'nfe' then 'กศน.'
      else 'อื่นๆ' end;
    new.institution := a.institution;
    new.program := nullif(btrim(concat_ws(' ', a.faculty, a.major)), '');
    new.tcas_round := case when a.kind = 'university' then a.admit_round else null end;
    new.university_id := a.university_id;
  else
    -- ยังไม่ได้เลือกที่เรียน (หรือไม่เรียนต่อ) → ไม่มีสถานศึกษาในคำตอบ กันข้อมูลค้างจากที่เคยเลือก
    new.institution := null; new.program := null; new.tcas_round := null; new.university_id := null;
  end if;

  select grade into v_grade from public.survey_rounds where id = new.round_id;
  v_ok := v_grade = 'ม.6' and new.photo_consent and new.photo_path is not null and a.id is not null;
  v_key := public.survey_card_key(new.institution, new.program, new.photo_path);

  -- card_changed = เคยอนุมัติแล้วแต่ข้อมูลเปลี่ยน (ครูต้องดูซ้ำ) · เคลียร์ได้โดยการตรวจของครูเท่านั้น
  if not v_ok then
    -- ยังทำการ์ดไม่ได้ชั่วคราว (เช่น กำลังสลับที่เลือก ไม่ติ๊กยินยอม) จำไว้ว่าเคยอนุมัติ
    if new.card_status = 'approved' then new.card_changed := true; end if;
    new.card_status := null;
  elsif new.card_status is null then
    if new.card_changed and new.card_snapshot = v_key then
      new.card_status := 'approved'; new.card_changed := false;   -- กลับมาเหมือนตอนที่ครูอนุมัติทุกอย่าง
    else
      new.card_status := 'pending';
    end if;
  elsif new.card_status in ('approved','returned') and new.card_snapshot is distinct from v_key then
    new.card_changed := new.card_changed or (new.card_status = 'approved');
    new.card_status := 'pending';
  elsif new.card_status = 'pending' and new.card_changed and new.card_snapshot = v_key then
    new.card_status := 'approved'; new.card_changed := false;     -- แก้กลับเป็นแบบเดิมที่อนุมัติไว้
  end if;
  return new;
end $$;

create trigger survey_responses_zz_admission_card before insert or update on public.survey_responses
  for each row execute function public.survey_responses_zz_admission_card();

-- ที่ที่ติดเปลี่ยน → แตะคำตอบให้คำนวณใหม่ (DEFINER เพราะนักเรียนไม่มีสิทธิ์แก้ช่องการ์ดเอง)
create or replace function public.survey_admissions_touch_response()
returns trigger language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  update public.survey_responses set id = id
   where id = case when tg_op = 'DELETE' then old.response_id else new.response_id end;
  return null;
end $$;
revoke execute on function public.survey_admissions_touch_response() from public, anon, authenticated;

create trigger survey_admissions_touch_response after insert or update or delete on public.survey_admissions
  for each row execute function public.survey_admissions_touch_response();

-- ───────── 5) สิทธิ์ ─────────
alter table public.survey_admissions enable row level security;

create policy "see admissions" on public.survey_admissions for select to authenticated
  using (student_id = (select auth.uid()) or (select public.iv_is_staff()));

create policy "student add admission while open" on public.survey_admissions for insert to authenticated
  with check (
    student_id = (select auth.uid())
    and (select public.get_my_role()) = 'student'
    and exists (select 1 from public.survey_responses s join public.survey_rounds r on r.id = s.round_id
                 where s.id = response_id and s.student_id = (select auth.uid()) and r.is_open));

create policy "student edit admission while open" on public.survey_admissions for update to authenticated
  using (student_id = (select auth.uid()))
  with check (
    student_id = (select auth.uid())
    and exists (select 1 from public.survey_responses s join public.survey_rounds r on r.id = s.round_id
                 where s.id = response_id and r.is_open));

create policy "student delete admission while open" on public.survey_admissions for delete to authenticated
  using (
    student_id = (select auth.uid())
    and exists (select 1 from public.survey_responses s join public.survey_rounds r on r.id = s.round_id
                 where s.id = response_id and r.is_open));

revoke all on public.survey_admissions from anon;
revoke all on public.survey_admissions from authenticated;
grant select, delete on public.survey_admissions to authenticated;
grant insert (response_id, student_id, kind, institution, university_id, faculty, major, admit_round, is_chosen)
  on public.survey_admissions to authenticated;
grant update (kind, institution, university_id, faculty, major, admit_round, is_chosen)
  on public.survey_admissions to authenticated;

-- คำตอบ: นักเรียนแก้ได้เฉพาะช่องของตัวเอง ช่องการ์ดแก้ได้ผ่านฟังก์ชันครูเท่านั้น
revoke insert, update on public.survey_responses from anon, authenticated;
grant insert (round_id, student_id, status, institution, program, tcas_round, other_detail, submitted_at, photo_path, photo_consent, university_id)
  on public.survey_responses to authenticated;
grant update (status, institution, program, tcas_round, other_detail, submitted_at, photo_path, photo_consent, university_id)
  on public.survey_responses to authenticated;

-- ───────── 6) ครูตรวจการ์ด ─────────
create or replace function public.survey_card_review(p_response_ids uuid[], p_action text, p_note text default null)
returns integer language plpgsql security definer set search_path = public, pg_temp
as $$
declare n int; v_note text := nullif(btrim(coalesce(p_note,'')), '');
begin
  if not public.iv_is_staff() then raise exception 'เฉพาะครูแนะแนวและผู้ดูแลระบบ' using errcode = '42501'; end if;
  if p_action not in ('approve','return') then raise exception 'คำสั่งไม่ถูกต้อง'; end if;
  if coalesce(array_length(p_response_ids, 1), 0) = 0 then return 0; end if;
  if array_length(p_response_ids, 1) > 500 then raise exception 'ตรวจได้ครั้งละไม่เกิน 500 คน'; end if;
  if p_action = 'return' and v_note is null then raise exception 'กรุณาบอกนักเรียนว่าต้องแก้อะไร'; end if;
  if char_length(coalesce(v_note,'')) > 300 then raise exception 'ข้อความยาวเกินไป'; end if;

  update public.survey_responses s
     set card_status = case when p_action = 'approve' then 'approved' else 'returned' end,
         card_note = case when p_action = 'approve' then null else v_note end,
         card_changed = false,
         card_snapshot = public.survey_card_key(s.institution, s.program, s.photo_path),
         card_reviewed_by = (select auth.uid()),
         card_reviewed_at = now()
   where s.id = any(p_response_ids)
     and s.card_status is not null
     and (p_action = 'return' or s.card_status <> 'approved');
  get diagnostics n = row_count;
  return n;
end $$;
revoke execute on function public.survey_card_review(uuid[], text, text) from public, anon;
grant execute on function public.survey_card_review(uuid[], text, text) to authenticated;

-- จัดชื่อมหาวิทยาลัยที่พิมพ์เอง: ทำกับที่ที่ติดด้วย
create or replace function public.survey_map_university(p_text text, p_university_id uuid)
returns integer language plpgsql security definer set search_path = public, pg_temp
as $$
declare n integer; m integer; t text := btrim(coalesce(p_text,''));
begin
  if not public.iv_is_staff() then raise exception 'เฉพาะครูแนะแนวและผู้ดูแลระบบ'; end if;
  if t = '' or not exists (select 1 from public.iv_universities where id = p_university_id) then
    raise exception 'ข้อมูลไม่ครบ';
  end if;
  update public.survey_admissions set university_id = p_university_id
   where kind = 'university' and university_id is null and institution = t;
  get diagnostics m = row_count;
  update public.survey_responses set university_id = p_university_id
   where status = 'มหาวิทยาลัย' and university_id is null and institution = t;
  get diagnostics n = row_count;
  update public.iv_universities
     set aliases = array_append(coalesce(aliases,'{}'), t)
   where id = p_university_id and not (t = any(coalesce(aliases,'{}'))) and public.norm_th(name) <> public.norm_th(t);
  return greatest(n, m);
end $$;
revoke execute on function public.survey_map_university(text, uuid) from public, anon;
grant execute on function public.survey_map_university(text, uuid) to authenticated;

-- ───────── 7) ย้ายคำตอบเดิม: ที่ที่กรอกไว้ = ที่ที่เลือก 1 แถว ─────────
insert into public.survey_admissions (response_id, student_id, kind, institution, university_id, faculty, admit_round, is_chosen)
select s.id, s.student_id,
       case s.status
         when 'มหาวิทยาลัย' then 'university'
         when 'ปวส./ปวช.ต่อเนื่อง' then 'higher_voc'
         when 'ต่อ ม.4 โรงเรียนเดิม' then 'm4_here'
         when 'ต่อ ม.4 โรงเรียนอื่น' then 'm4_other'
         when 'ปวช.' then 'vocational'
         when 'กศน.' then 'nfe' end,
       btrim(s.institution), s.university_id, nullif(btrim(s.program), ''),
       case when s.status = 'มหาวิทยาลัย' then s.tcas_round end, true
  from public.survey_responses s
  join public.survey_rounds r on r.id = s.round_id
 where nullif(btrim(s.institution), '') is not null
   and ((r.grade = 'ม.6' and s.status in ('มหาวิทยาลัย','ปวส./ปวช.ต่อเนื่อง'))
     or (r.grade = 'ม.3' and s.status in ('ต่อ ม.4 โรงเรียนเดิม','ต่อ ม.4 โรงเรียนอื่น','ปวช.','กศน.')));

-- report_survey: นับ "เรียนต่อ (รอผล/ยังไม่เลือกที่)" เป็นกลุ่มศึกษาต่อ
do $$
declare d text;
begin
  select pg_get_functiondef('public.report_survey(text)'::regprocedure) into d;
  if d not like '%รอผล/ยังไม่เลือกที่%' then
    d := replace(d, '''ปวส./ปวช.ต่อเนื่อง'']', '''ปวส./ปวช.ต่อเนื่อง'',''เรียนต่อ (รอผล/ยังไม่เลือกที่)'']');
    execute d;
  end if;
end $$;
