-- ปุ่ม "จัดชื่อคณะ": รวมชื่อคณะที่นักเรียนพิมพ์ต่างกันในมหาวิทยาลัยเดียวกันให้เป็นชื่อเดียว
-- (ครูแนะแนว/ผู้ดูแลเท่านั้น) · การ์ดที่อนุมัติแล้วยังคงเป็นอนุมัติ เพราะเนื้อหาจริงไม่เปลี่ยน
create or replace function public.survey_map_faculty(p_university_id uuid, p_from text[], p_to text)
returns integer language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_to text := nullif(btrim(regexp_replace(coalesce(p_to,''), '\s+', ' ', 'g')), '');
        v_from text[]; v_ids uuid[]; n integer;
begin
  if not public.iv_is_staff() then raise exception 'เฉพาะครูแนะแนวและผู้ดูแลระบบ' using errcode = '42501'; end if;
  if v_to is null or char_length(v_to) > 200 then raise exception 'ชื่อคณะไม่ถูกต้อง'; end if;
  if p_university_id is null or not exists (select 1 from public.iv_universities where id = p_university_id) then raise exception 'ไม่พบมหาวิทยาลัย'; end if;
  select coalesce(array_agg(distinct nullif(btrim(regexp_replace(coalesce(x,''), '\s+', ' ', 'g')), '')), '{}') into v_from from unnest(coalesce(p_from, '{}')) x;
  if coalesce(array_length(v_from, 1), 0) = 0 then return 0; end if;

  -- การ์ดที่อนุมัติแล้วและไม่มีค้างเปลี่ยน จะคงสถานะ
  select coalesce(array_agg(r.id), '{}') into v_ids
    from public.survey_responses r
    join public.survey_admissions a on a.response_id = r.id and a.is_chosen
   where a.university_id = p_university_id and a.kind = 'university'
     and btrim(regexp_replace(coalesce(a.faculty,''), '\s+', ' ', 'g')) = any(v_from)
     and a.faculty is distinct from v_to
     and r.card_status = 'approved' and not r.card_changed;

  update public.survey_admissions a set faculty = v_to
   where a.university_id = p_university_id and a.kind = 'university'
     and btrim(regexp_replace(coalesce(a.faculty,''), '\s+', ' ', 'g')) = any(v_from)
     and a.faculty is distinct from v_to;
  get diagnostics n = row_count;

  if coalesce(array_length(v_ids, 1), 0) > 0 then
    update public.survey_responses s
       set card_status = 'approved', card_changed = false,
           card_snapshot = public.survey_card_key(
             s.institution,
             concat_ws('|', s.program, (select a.campus from public.survey_admissions a where a.response_id = s.id and a.is_chosen limit 1)),
             s.photo_path)
     where s.id = any(v_ids);
  end if;
  return n;
end $$;
revoke execute on function public.survey_map_faculty(uuid, text[], text) from public, anon;
grant execute on function public.survey_map_faculty(uuid, text[], text) to authenticated;
