-- ปรับ RLS policy ให้เรียก auth.uid() และฟังก์ชันตรวจบทบาทแบบไม่รับค่า "ครั้งเดียวต่อคำสั่ง" (ห่อด้วย select)
-- แทนที่จะเรียกซ้ำทุกแถว — ความหมายของสิทธิ์เหมือนเดิมทุกประการ (แทนข้อความล้วน ๆ)
-- ไม่แตะ: awards_my_group_ids() (ใช้กับ = ANY(...) ห่อแล้วกำกวม), award_event_locked_by_batch(id) (ขึ้นกับแถว)
--
-- ตัวตรวจในตัว (ถ้าไม่ผ่านข้อใดข้อหนึ่ง migration ทั้งก้อนถูกยกเลิก ไม่มีอะไรเปลี่ยน):
--   1) policy ทุกตัวหลังแก้ ต้องเหมือนเดิมเมื่อ "ถอดการห่อ" ออก (ทั้งนิพจน์, คำสั่ง, ประเภท permissive, บทบาท)
--   2) จำนวน policy เท่าเดิม
--   3) อ่านทุกตาราง × 5 บทบาท (ไม่ล็อกอิน/นักเรียน/ครู/ครูแนะแนว/แอดมิน) ได้จำนวนแถวเท่าเดิมทุกช่อง
-- ย้อนกลับ: supabase/rollbacks/20261025_rls_initplan_rollback.sql (อ่านจากตารางสำรอง policy_backup_20261025)

create table public.policy_backup_20261025 (
  schemaname text, tablename text, policyname text, permissive text, roles text[],
  cmd text, qual text, with_check text, saved_at timestamptz default now());
alter table public.policy_backup_20261025 enable row level security;      -- ไม่มี policy = API อ่านไม่ได้
revoke all on public.policy_backup_20261025 from anon, authenticated;
insert into public.policy_backup_20261025 (schemaname,tablename,policyname,permissive,roles,cmd,qual,with_check)
  select schemaname,tablename,policyname,permissive,roles::text[],cmd,qual,with_check
  from pg_policies where schemaname = 'public';

create or replace function pg_temp.norm(x text) returns text language sql immutable as $n$
  select regexp_replace(x,
    '\(\s*SELECT\s+((?:auth\.uid|get_my_role|get_my_room|iv_is_staff|is_scholarship_officer|awards_is_officer|can_manage_announcements)\(\))\s+AS\s+\w+\s*\)',
    '\1', 'gi')
$n$;

create or replace function pg_temp.rls_matrix(p_ids jsonb) returns jsonb language plpgsql as $m$
declare t text; per text; uid text; cnt bigint; res jsonb := '{}'::jsonb;
begin
  for t in select distinct tablename from pg_policies where schemaname = 'public' order by 1 loop
    for per, uid in select key, value from jsonb_each_text(p_ids) order by key loop
      begin
        if per = 'anon' then
          perform set_config('request.jwt.claims', '', true);
          set local role anon;
        else
          perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
          set local role authenticated;
        end if;
        execute format('select count(*) from public.%I', t) into cnt;
        reset role;
        res := res || jsonb_build_object(t || '|' || per, cnt);
      exception when others then
        reset role;
        res := res || jsonb_build_object(t || '|' || per, 'ERR ' || sqlstate);
      end;
    end loop;
  end loop;
  perform set_config('request.jwt.claims', '', true);
  return res;
end $m$;

do $mig$
declare
  fns text[] := array['auth.uid','get_my_role','get_my_room','iv_is_staff','is_scholarship_officer','awards_is_officer','can_manage_announcements'];
  f text; fre text; short text; r record;
  nq text; nw text; stmt text; changed int := 0; total_before int; total_after int; bad int;
  adm uuid; gdn uuid; tch uuid; stu uuid; personas jsonb; m_before jsonb; m_after jsonb; diffkeys text;
begin
  select id into adm from public.profiles where role = 'admin' limit 1;
  select id into gdn from public.profiles where role = 'teacher' and coalesce(is_guidance,false) limit 1;
  select id into tch from public.profiles where role = 'teacher' and not coalesce(is_guidance,false) limit 1;
  select id into stu from public.profiles where role = 'student' limit 1;
  personas := jsonb_strip_nulls(jsonb_build_object('anon','','admin',adm,'guidance',gdn,'teacher',tch,'student',stu));

  select count(*) into total_before from pg_policies where schemaname = 'public';
  m_before := pg_temp.rls_matrix(personas);

  for r in select * from pg_policies where schemaname = 'public' order by tablename, policyname loop
    nq := r.qual; nw := r.with_check;
    foreach f in array fns loop
      fre := replace(f, '.', '\.');
      short := split_part(f, '.', array_length(string_to_array(f, '.'), 1));
      if nq is not null then
        nq := regexp_replace(nq, '\(\s*SELECT\s+' || fre || '\(\)\s+AS\s+\w+\s*\)', '@@KEEP_' || short || '@@', 'g');
        nq := regexp_replace(nq, '(?<![A-Za-z0-9_.])' || fre || '\(\)', '(select ' || f || '())', 'g');
        nq := replace(nq, '@@KEEP_' || short || '@@', '( SELECT ' || f || '() AS ' || short || ')');
      end if;
      if nw is not null then
        nw := regexp_replace(nw, '\(\s*SELECT\s+' || fre || '\(\)\s+AS\s+\w+\s*\)', '@@KEEP_' || short || '@@', 'g');
        nw := regexp_replace(nw, '(?<![A-Za-z0-9_.])' || fre || '\(\)', '(select ' || f || '())', 'g');
        nw := replace(nw, '@@KEEP_' || short || '@@', '( SELECT ' || f || '() AS ' || short || ')');
      end if;
    end loop;
    if nq is distinct from r.qual or nw is distinct from r.with_check then
      stmt := format('alter policy %I on public.%I', r.policyname, r.tablename);
      if nq is not null then stmt := stmt || ' using (' || nq || ')'; end if;
      if nw is not null then stmt := stmt || ' with check (' || nw || ')'; end if;
      execute stmt;
      changed := changed + 1;
    end if;
  end loop;

  -- ตรวจ 1+2: โครงสร้างเหมือนเดิมเมื่อถอดการห่อ
  select count(*) into total_after from pg_policies where schemaname = 'public';
  if total_after <> total_before then
    raise exception 'จำนวน policy เปลี่ยน: % -> %', total_before, total_after;
  end if;
  select count(*) into bad
  from public.policy_backup_20261025 b
  left join pg_policies p on p.schemaname = b.schemaname and p.tablename = b.tablename and p.policyname = b.policyname
  where p.policyname is null
     or pg_temp.norm(b.qual) is distinct from pg_temp.norm(p.qual)
     or pg_temp.norm(b.with_check) is distinct from pg_temp.norm(p.with_check)
     or b.cmd <> p.cmd or b.permissive <> p.permissive or b.roles <> p.roles::text[];
  if bad > 0 then raise exception 'policy % ตัวไม่ตรงกับของเดิมหลังถอดการห่อ ยกเลิกทั้งหมด', bad; end if;

  -- ตรวจ 3: ผลอ่านทุกตาราง × บทบาท ต้องเท่าเดิม
  m_after := pg_temp.rls_matrix(personas);
  if m_before <> m_after then
    select string_agg(k, ', ') into diffkeys from (select key k from jsonb_each(m_before) b
      where m_after -> b.key is distinct from b.value limit 10) d;
    raise exception 'ผลอ่านต่างจากเดิม: %', diffkeys;
  end if;

  perform set_config('app.rls_wrap_stats',
    format('changed=%s total=%s matrix_cells=%s personas=%s', changed, total_after, (select count(*) from jsonb_object_keys(m_after)), (select string_agg(key, ',') from jsonb_each(personas))), false);
end $mig$;
