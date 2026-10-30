-- ทุนการศึกษา: ตั้งจำนวนเงินแยก ม.ต้น (ม.1-3) / ม.ปลาย (ม.4-6) ได้ในแต่ละทุน
-- 30 ต.ค. 2569
--
-- แนวคิด: amount_per_grant = จำนวนเงินกลาง (ใช้ทุกระดับ) คงเดิม ทุนเดิมไม่ต้องแก้อะไร
--   amount_lower / amount_upper = ถ้ากรอก จะใช้แทนจำนวนเงินกลางของระดับนั้น, ว่าง = ใช้จำนวนเงินกลาง
-- v_scholarship_awards.amount_per_grant ตอนนี้ = "จำนวนเงินที่นักเรียนคนนั้นได้จริงตามระดับชั้น"
--   (ชื่อคอลัมน์คงเดิม หน้าสรุปประจำปีจึงได้ยอดถูกต้องโดยไม่ต้องแก้)

alter table public.scholarships
  add column if not exists amount_lower numeric check (amount_lower is null or amount_lower >= 0),
  add column if not exists amount_upper numeric check (amount_upper is null or amount_upper >= 0);

comment on column public.scholarships.amount_lower is 'จำนวนเงินต่อทุนสำหรับ ม.ต้น (ม.1-3) — ว่าง = ใช้ amount_per_grant';
comment on column public.scholarships.amount_upper is 'จำนวนเงินต่อทุนสำหรับ ม.ปลาย (ม.4-6) — ว่าง = ใช้ amount_per_grant';

-- จำนวนเงินที่ได้จริงตามชั้น (class_level เช่น "ม.6" หรือ class_room เช่น "ม.6/1")
create or replace function public.scholarship_amount_for(
  p_general numeric, p_lower numeric, p_upper numeric, p_class text)
returns numeric
language sql
immutable
set search_path = public
as $$
  select case split_part(coalesce(p_class, ''), '/', 1)
           when 'ม.1' then coalesce(p_lower, p_general)
           when 'ม.2' then coalesce(p_lower, p_general)
           when 'ม.3' then coalesce(p_lower, p_general)
           when 'ม.4' then coalesce(p_upper, p_general)
           when 'ม.5' then coalesce(p_upper, p_general)
           when 'ม.6' then coalesce(p_upper, p_general)
           else p_general
         end
$$;


-- view: ยอดต่อคนตามระดับชั้น (คงชื่อคอลัมน์/ลำดับ/ชนิดเดิมทั้งหมด) — ยังเป็น security_invoker
create or replace view public.v_scholarship_awards with (security_invoker = true) as
 SELECT a.id AS application_id,
    s.id AS scholarship_id,
    s.academic_year,
    s.name AS scholarship_name,
    s.provider,
    public.scholarship_amount_for(s.amount_per_grant, s.amount_lower, s.amount_upper, p.class_room) AS amount_per_grant,
    p.id AS profile_id,
    p.display_name,
    p.student_id,
    p.class_room,
    split_part(p.class_room, '/'::text, 1) AS class_level,
    t.total_score,
    a.updated_at AS awarded_at
   FROM (((applications a
     JOIN scholarships s ON ((s.id = a.scholarship_id)))
     JOIN profiles p ON ((p.id = a.profile_id)))
     LEFT JOIN application_totals t ON ((t.application_id = a.id)))
  WHERE (a.status = 'approved'::application_status);

revoke all on public.v_scholarship_awards from anon, authenticated;

create or replace function public.scholarship_save(
  p_id uuid, p_fields jsonb, p_criteria jsonb default null)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_old public.scholarships%rowtype;
  v_id uuid := p_id;
  v_name text; v_year text; v_quota int; v_amount numeric; v_lo numeric; v_up numeric;
  v_provider text; v_desc text; v_closes timestamptz;
  v_new_status public.scholarship_status;
  v_apps int; v_approved int;
  v_keys text[];
  v_changed boolean := false;
  v_sum numeric; v_cnt int;
  v_recomputed int := 0;
begin
  if not public.is_scholarship_officer() then
    raise exception 'เฉพาะผู้ดูแลระบบและครูแนะแนวเท่านั้นที่จัดการทุนได้';
  end if;
  p_fields := coalesce(p_fields, '{}'::jsonb);

  -- ===== สร้างใหม่: ใส่แถวฉบับร่างก่อน แล้วไหลต่อเข้าเส้นทางแก้ไขเดียวกัน =====
  if v_id is null then
    v_name := nullif(btrim(p_fields->>'name'), '');
    v_year := nullif(btrim(p_fields->>'academic_year'), '');
    if v_name is null then raise exception 'กรุณากรอกชื่อทุน'; end if;
    if v_year is null or v_year !~ '^[0-9]{4}$' then
      raise exception 'ปีการศึกษาต้องเป็นตัวเลข 4 หลัก เช่น 2569';
    end if;
    if coalesce((p_fields->>'quota')::int, 1) < 1 then
      raise exception 'จำนวนทุนต้องไม่น้อยกว่า 1';
    end if;
    if exists (select 1 from public.scholarships s
                where lower(btrim(s.name)) = lower(v_name) and s.academic_year = v_year) then
      raise exception 'มีทุนชื่อ "%" ปีการศึกษา % อยู่แล้ว กรุณาเปลี่ยนชื่อหรือปีการศึกษา', v_name, v_year;
    end if;
    insert into public.scholarships (name, quota, academic_year, status, created_by)
    values (v_name, coalesce((p_fields->>'quota')::int, 1), v_year, 'draft', auth.uid())
    returning id into v_id;
  end if;

  select * into v_old from public.scholarships where id = v_id for update;
  if not found then raise exception 'ไม่พบทุนนี้ (อาจถูกลบไปแล้ว)'; end if;

  select count(*), count(*) filter (where a.status = 'approved')
    into v_apps, v_approved
    from public.applications a where a.scholarship_id = v_id;

  -- ===== ข้อมูลทั่วไปของทุน =====
  v_name := case when p_fields ? 'name' then nullif(btrim(p_fields->>'name'), '') else v_old.name end;
  if v_name is null then raise exception 'กรุณากรอกชื่อทุน'; end if;

  v_year := case when p_fields ? 'academic_year' then nullif(btrim(p_fields->>'academic_year'), '') else v_old.academic_year end;
  if v_year is null or v_year !~ '^[0-9]{4}$' then
    raise exception 'ปีการศึกษาต้องเป็นตัวเลข 4 หลัก เช่น 2569';
  end if;

  v_quota := case when p_fields ? 'quota' then (p_fields->>'quota')::int else v_old.quota end;
  if v_quota is null or v_quota < 1 then raise exception 'จำนวนทุนต้องไม่น้อยกว่า 1'; end if;
  -- ตรวจเฉพาะตอน "ลด" จำนวนทุน (ทุนเดิมที่ข้อมูลเก่าเกินโควตาอยู่แล้ว ยังบันทึกเรื่องอื่นได้)
  if v_quota < v_old.quota and v_quota < v_approved then
    raise exception 'ลดจำนวนทุนเหลือ % ไม่ได้ เพราะมีผู้ได้รับทุนแล้ว % คน', v_quota, v_approved;
  end if;

  v_amount := case when p_fields ? 'amount_per_grant' then (p_fields->>'amount_per_grant')::numeric else v_old.amount_per_grant end;
  if v_amount is not null and v_amount < 0 then raise exception 'จำนวนเงินต่อทุนต้องไม่ติดลบ'; end if;

  -- จำนวนเงินแยกระดับ: ว่าง = ใช้จำนวนเงินกลาง (amount_per_grant)
  v_lo := case when p_fields ? 'amount_lower' then (p_fields->>'amount_lower')::numeric else v_old.amount_lower end;
  v_up := case when p_fields ? 'amount_upper' then (p_fields->>'amount_upper')::numeric else v_old.amount_upper end;
  if (v_lo is not null and v_lo < 0) or (v_up is not null and v_up < 0) then
    raise exception 'จำนวนเงินต้องไม่ติดลบ';
  end if;

  v_provider := case when p_fields ? 'provider' then nullif(btrim(p_fields->>'provider'), '') else v_old.provider end;
  v_desc     := case when p_fields ? 'description' then nullif(btrim(p_fields->>'description'), '') else v_old.description end;
  v_closes   := case when p_fields ? 'closes_at' then (p_fields->>'closes_at')::timestamptz else v_old.closes_at end;

  if (v_name is distinct from v_old.name or v_year is distinct from v_old.academic_year)
     and exists (select 1 from public.scholarships s
                  where s.id <> v_id and lower(btrim(s.name)) = lower(v_name) and s.academic_year = v_year) then
    raise exception 'มีทุนชื่อ "%" ปีการศึกษา % อยู่แล้ว กรุณาเปลี่ยนชื่อหรือปีการศึกษา', v_name, v_year;
  end if;

  update public.scholarships
     set name = v_name, provider = v_provider, description = v_desc,
         academic_year = v_year, amount_per_grant = v_amount,
         amount_lower = v_lo, amount_upper = v_up,
         quota = v_quota, closes_at = v_closes
   where id = v_id;

  -- ===== เกณฑ์ (แก้ทีละแถว ไม่ลบทิ้งแล้วสร้างใหม่) =====
  if p_criteria is not null then
    if jsonb_typeof(p_criteria) <> 'array' then raise exception 'รูปแบบเกณฑ์ไม่ถูกต้อง'; end if;

    if exists (select 1 from jsonb_array_elements(p_criteria) e
                where nullif(btrim(e->>'criterion_key'), '') is null
                   or nullif(btrim(e->>'label'), '') is null
                   or (e->>'weight') is null
                   or (e->>'weight')::numeric < 0 or (e->>'weight')::numeric > 1
                   or jsonb_typeof(e->'scoring_rules') is distinct from 'array') then
      raise exception 'ข้อมูลเกณฑ์ไม่ครบ (ต้องมีชื่อ น้ำหนัก 0–100%% และช่วงคะแนน)';
    end if;

    v_keys := array(select e->>'criterion_key' from jsonb_array_elements(p_criteria) e);
    if cardinality(v_keys) <> (select count(distinct k) from unnest(v_keys) k) then
      raise exception 'มีเกณฑ์ชนิดเดียวกันซ้ำกัน กรุณาเลือกให้ไม่ซ้ำ';
    end if;

    -- มีการเปลี่ยนแปลงจริงไหม (บันทึกซ้ำโดยไม่แก้เกณฑ์ ต้องไม่ไปแตะคะแนนเลย)
    select exists (
             select 1 from jsonb_array_elements(p_criteria) e
               left join public.scholarship_criteria c
                 on c.id = (e->>'id')::uuid and c.scholarship_id = v_id
              where c.id is null
                 or c.criterion_key    is distinct from e->>'criterion_key'
                 or c.label            is distinct from e->>'label'
                 or c.weight           is distinct from (e->>'weight')::numeric
                 or c.scoring_rules    is distinct from e->'scoring_rules'
                 or c.higher_is_better is distinct from coalesce((e->>'higher_is_better')::boolean, true)
                 or c.display_order    is distinct from coalesce((e->>'display_order')::int, 0))
        or exists (
             select 1 from public.scholarship_criteria c
              where c.scholarship_id = v_id
                and not exists (select 1 from jsonb_array_elements(p_criteria) e
                                 where (e->>'id')::uuid = c.id))
      into v_changed;

    if v_changed then
      if v_old.status in ('screening', 'announced', 'closed') then
        raise exception 'ทุนนี้อยู่ในขั้น "%" แล้ว แก้เกณฑ์ไม่ได้ — ถ้าต้องการเกณฑ์ใหม่ ให้ใช้ปุ่ม "เปิดรับสมัครรอบใหม่"',
          case v_old.status when 'screening' then 'กำลังคัดกรอง' when 'announced' then 'ประกาศผลแล้ว' else 'ปิดแล้ว' end;
      end if;
      if v_approved > 0 then
        raise exception 'มีผู้ได้รับทุนแล้ว % คน แก้เกณฑ์ไม่ได้ เพราะจะกระทบคะแนนที่ตัดสินไปแล้ว — ถ้าต้องการเกณฑ์ใหม่ ให้ใช้ปุ่ม "เปิดรับสมัครรอบใหม่"', v_approved;
      end if;

      -- 1) ลบเฉพาะเกณฑ์ที่ครูเอาออกจริง
      delete from public.scholarship_criteria c
       where c.scholarship_id = v_id
         and not exists (select 1 from jsonb_array_elements(p_criteria) e where (e->>'id')::uuid = c.id);

      -- 2) พักชื่อรหัสเกณฑ์ที่กำลังเปลี่ยน กันชนกันตอนสลับ (unique: ทุน+รหัสเกณฑ์)
      update public.scholarship_criteria c
         set criterion_key = 'tmp_' || c.id::text
        from jsonb_array_elements(p_criteria) e
       where c.id = (e->>'id')::uuid and c.scholarship_id = v_id
         and c.criterion_key is distinct from e->>'criterion_key';

      -- 3) แก้เกณฑ์เดิมในแถวเดิม (id เดิม -> คะแนนที่มีอยู่ยังผูกกับเกณฑ์นั้น)
      update public.scholarship_criteria c
         set criterion_key    = e->>'criterion_key',
             label            = e->>'label',
             weight           = (e->>'weight')::numeric,
             scoring_rules    = e->'scoring_rules',
             higher_is_better = coalesce((e->>'higher_is_better')::boolean, true),
             display_order    = coalesce((e->>'display_order')::int, 0)
        from jsonb_array_elements(p_criteria) e
       where c.id = (e->>'id')::uuid and c.scholarship_id = v_id;

      -- 4) เพิ่มเกณฑ์ใหม่
      insert into public.scholarship_criteria
        (scholarship_id, criterion_key, label, weight, scoring_rules, higher_is_better, display_order)
      select v_id, e->>'criterion_key', e->>'label', (e->>'weight')::numeric, e->'scoring_rules',
             coalesce((e->>'higher_is_better')::boolean, true), coalesce((e->>'display_order')::int, 0)
        from jsonb_array_elements(p_criteria) e
       where nullif(e->>'id', '') is null;
    end if;
  end if;

  -- ===== สถานะ =====
  v_new_status := case when p_fields ? 'status' then (p_fields->>'status')::public.scholarship_status else v_old.status end;

  if v_new_status = 'draft' and v_apps > 0 then
    raise exception 'ทุนที่มีใบสมัครแล้ว (% ใบ) ย้อนกลับเป็นฉบับร่างไม่ได้ เพราะนักเรียนจะมองไม่เห็นทุนและผลคัดเลือก', v_apps;
  end if;

  if v_new_status = 'open' and (v_old.status <> 'open' or v_changed) then
    select count(*), coalesce(sum(weight), 0) into v_cnt, v_sum
      from public.scholarship_criteria where scholarship_id = v_id;
    if v_cnt = 0 then raise exception 'ต้องมีเกณฑ์อย่างน้อย 1 ข้อก่อนเปิดรับสมัคร'; end if;
    if abs(v_sum - 1) > 0.0001 then
      raise exception 'น้ำหนักรวมของเกณฑ์ต้องเป็น 100%% ก่อนเปิดรับสมัคร (ตอนนี้ %)', round(v_sum * 100, 2)::text || '%';
    end if;
  end if;
  if v_new_status = 'open' and v_old.status <> 'open' and v_closes is not null and v_closes < now() then
    raise exception 'วันปิดรับสมัครเป็นวันที่ผ่านไปแล้ว กรุณาตั้งวันปิดรับสมัครใหม่ก่อนเปิดรับสมัคร';
  end if;

  if v_new_status is distinct from v_old.status then
    update public.scholarships set status = v_new_status where id = v_id;
  end if;

  -- เกณฑ์เปลี่ยน + มีใบสมัครที่ยังไม่ตัดสิน -> คำนวณคะแนนใหม่ให้ตรงกับเกณฑ์ปัจจุบัน
  -- (ฟังก์ชันคำนวณข้ามผู้ได้รับทุนแล้ว และไม่แตะคะแนนที่ครูปรับเอง)
  if v_changed then
    select count(*) into v_recomputed from public.applications a
     where a.scholarship_id = v_id and a.status not in ('withdrawn', 'approved');
    if v_recomputed > 0 then perform public.compute_scholarship_scores(v_id); end if;
  end if;

  return jsonb_build_object('id', v_id, 'criteria_changed', v_changed, 'recomputed', v_recomputed);
end $$;


create or replace function public.scholarship_new_round(
  p_source uuid, p_name text, p_academic_year text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  s public.scholarships%rowtype;
  v_name text; v_year text; v_new uuid;
begin
  if not public.is_scholarship_officer() then
    raise exception 'เฉพาะผู้ดูแลระบบและครูแนะแนวเท่านั้นที่เปิดรอบใหม่ได้';
  end if;
  select * into s from public.scholarships where id = p_source;
  if not found then raise exception 'ไม่พบทุนต้นแบบ'; end if;

  v_name := coalesce(nullif(btrim(p_name), ''), s.name);
  v_year := coalesce(nullif(btrim(p_academic_year), ''), s.academic_year);
  if v_year !~ '^[0-9]{4}$' then raise exception 'ปีการศึกษาต้องเป็นตัวเลข 4 หลัก เช่น 2569'; end if;

  if exists (select 1 from public.scholarships x
              where lower(btrim(x.name)) = lower(v_name) and x.academic_year = v_year) then
    raise exception 'มีทุนชื่อ "%" ปีการศึกษา % อยู่แล้ว — ถ้าเปิดซ้ำในปีเดียวกัน ให้เติมต่อท้ายชื่อ เช่น "(รอบ 2)" หรือเปลี่ยนปีการศึกษา', v_name, v_year;
  end if;

  insert into public.scholarships
    (name, provider, description, amount_per_grant, amount_lower, amount_upper, quota, academic_year,
     opens_at, closes_at, status, eligibility_rules, created_by)
  values
    (v_name, s.provider, s.description, s.amount_per_grant, s.amount_lower, s.amount_upper, s.quota, v_year,
     null, null, 'draft', s.eligibility_rules, auth.uid())
  returning id into v_new;

  insert into public.scholarship_criteria
    (scholarship_id, criterion_key, label, weight, scoring_rules, higher_is_better, display_order)
  select v_new, criterion_key, label, weight, scoring_rules, higher_is_better, display_order
    from public.scholarship_criteria where scholarship_id = p_source;

  insert into public.scholarship_audit_log
    (table_name, record_id, action, field_name, old_value, new_value, reason, actor_id)
  values ('scholarships', v_new, 'insert', 'new_round', p_source::text, v_new::text,
          format('เปิดรอบใหม่ คัดลอกจากทุน "%s" (ปีการศึกษา %s)', s.name, s.academic_year), auth.uid());

  return v_new;
end $$;


create or replace function public.log_scholarship_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.eligibility_rules is distinct from old.eligibility_rules then
    insert into scholarship_audit_log (table_name, record_id, action, field_name, old_value, new_value, reason)
    values ('scholarships', new.id, 'update', 'eligibility_rules',
            old.eligibility_rules::text, new.eligibility_rules::text, 'แก้คุณสมบัติบังคับ');
  end if;
  if new.status is distinct from old.status then
    insert into scholarship_audit_log (table_name, record_id, action, field_name, old_value, new_value, reason)
    values ('scholarships', new.id, 'update', 'status',
            old.status::text, new.status::text, 'เปลี่ยนสถานะทุน');
  end if;
  if new.quota is distinct from old.quota then
    insert into scholarship_audit_log (table_name, record_id, action, field_name, old_value, new_value, reason)
    values ('scholarships', new.id, 'update', 'quota', old.quota::text, new.quota::text, 'แก้จำนวนทุน');
  end if;
  if new.name is distinct from old.name then
    insert into scholarship_audit_log (table_name, record_id, action, field_name, old_value, new_value, reason)
    values ('scholarships', new.id, 'update', 'name', old.name, new.name, 'แก้ชื่อทุน');
  end if;
  if new.amount_per_grant is distinct from old.amount_per_grant then
    insert into scholarship_audit_log (table_name, record_id, action, field_name, old_value, new_value, reason)
    values ('scholarships', new.id, 'update', 'amount_per_grant',
            old.amount_per_grant::text, new.amount_per_grant::text, 'แก้จำนวนเงินต่อทุน');
  end if;
  if new.amount_lower is distinct from old.amount_lower then
    insert into scholarship_audit_log (table_name, record_id, action, field_name, old_value, new_value, reason)
    values ('scholarships', new.id, 'update', 'amount_lower',
            old.amount_lower::text, new.amount_lower::text, 'แก้จำนวนเงิน ม.ต้น');
  end if;
  if new.amount_upper is distinct from old.amount_upper then
    insert into scholarship_audit_log (table_name, record_id, action, field_name, old_value, new_value, reason)
    values ('scholarships', new.id, 'update', 'amount_upper',
            old.amount_upper::text, new.amount_upper::text, 'แก้จำนวนเงิน ม.ปลาย');
  end if;
  if new.closes_at is distinct from old.closes_at then
    insert into scholarship_audit_log (table_name, record_id, action, field_name, old_value, new_value, reason)
    values ('scholarships', new.id, 'update', 'closes_at',
            old.closes_at::text, new.closes_at::text, 'แก้วันปิดรับสมัคร');
  end if;
  if new.academic_year is distinct from old.academic_year then
    insert into scholarship_audit_log (table_name, record_id, action, field_name, old_value, new_value, reason)
    values ('scholarships', new.id, 'update', 'academic_year',
            old.academic_year, new.academic_year, 'แก้ปีการศึกษา');
  end if;
  return new;
end $$;

-- สิทธิ์ (create or replace ไม่เปลี่ยนสิทธิ์เดิม แต่ย้ำไว้ให้ชัด)
revoke all on function public.scholarship_new_round(uuid,text,text) from public, anon;
grant execute on function public.scholarship_new_round(uuid,text,text) to authenticated;
revoke all on function public.scholarship_save(uuid,jsonb,jsonb) from public, anon;
grant execute on function public.scholarship_save(uuid,jsonb,jsonb) to authenticated;
revoke all on function public.log_scholarship_change() from public, anon, authenticated;
revoke all on function public.scholarship_amount_for(numeric,numeric,numeric,text) from public, anon;
