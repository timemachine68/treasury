-- แก้: ครูกดอนุมัติแล้วการ์ดเด้งกลับเป็น "มีการเปลี่ยน"
-- สาเหตุ: trigger เทียบค่าแบบ program|วิทยาเขต แต่ survey_card_review จดค่าเทียบแค่ program
-- (ใช้ได้เฉพาะคนที่มีวิทยาเขต) → ต้องจดแบบเดียวกัน
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
         card_snapshot = public.survey_card_key(
           s.institution,
           concat_ws('|', s.program, (select a.campus from public.survey_admissions a where a.response_id = s.id and a.is_chosen limit 1)),
           s.photo_path),
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

-- ซ่อมแถวที่อนุมัติแล้วเด้งกลับ (เนื้อหาไม่เปลี่ยน)
update public.survey_responses s
   set card_status = 'approved', card_changed = false,
       card_snapshot = public.survey_card_key(s.institution, concat_ws('|', s.program, (select a.campus from public.survey_admissions a where a.response_id = s.id and a.is_chosen limit 1)), s.photo_path)
 where s.card_status = 'pending' and s.card_changed and s.card_reviewed_at is not null
   and s.card_reviewed_at > now() - interval '3 days'
   and s.card_snapshot = public.survey_card_key(s.institution, s.program, s.photo_path);
