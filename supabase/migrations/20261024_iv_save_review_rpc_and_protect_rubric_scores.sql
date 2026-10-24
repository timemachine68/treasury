-- ระบบซ้อมสัมภาษณ์: บันทึกผลตรวจครั้งเดียวจบ + กันคะแนนหายเมื่อลบเกณฑ์
-- (ใช้กับฐานข้อมูลจริงแล้วเมื่อ 24 ต.ค. 2569)

-- 1) บันทึกผลตรวจครั้งเดียวจบ (คะแนน + สถานะ + ความเห็น) — ถ้าพังกลางทางจะไม่บันทึกอะไรเลย
--    SECURITY INVOKER: ทุกคำสั่งข้างในยังผ่าน RLS ตามสิทธิ์ของผู้เรียก
create or replace function public.iv_save_review(p_session_id uuid, p_scores jsonb, p_comment text default null)
returns void language plpgsql security invoker set search_path = public as $$
declare
  s record; v_me uuid := auth.uid(); v_need int; v_got int;
begin
  if not iv_is_staff() then
    raise exception 'เฉพาะครูแนะแนวเท่านั้นที่บันทึกผลตรวจได้';
  end if;

  select id, status, reviewer_id into s from iv_sessions where id = p_session_id for update;
  if not found then raise exception 'ไม่พบเซ็ตซ้อมนี้ อาจถูกลบไปแล้ว'; end if;
  if s.status = 'draft' then raise exception 'นักเรียนยังไม่ได้ส่งเซ็ตนี้ให้ครูตรวจ'; end if;
  if s.status = 'reviewed' and s.reviewer_id is not null and s.reviewer_id <> v_me
     and get_my_role() <> 'admin' then
    raise exception 'เซ็ตนี้ครูท่านอื่นตรวจแล้ว แก้ได้เฉพาะครูที่ตรวจหรือผู้ดูแลระบบ';
  end if;

  if p_scores is null or jsonb_typeof(p_scores) <> 'object' then
    raise exception 'ไม่มีคะแนนที่จะบันทึก';
  end if;
  if exists (select 1 from jsonb_each_text(p_scores) e
             where e.value !~ '^[1-4]$'
                or not exists (select 1 from iv_rubric_criteria c where c.id::text = e.key and c.is_active)) then
    raise exception 'คะแนนไม่ถูกต้อง ต้องเป็น 1–4 และตรงกับเกณฑ์ที่ใช้อยู่';
  end if;
  select count(*) into v_need from iv_rubric_criteria where is_active;
  select count(*) into v_got from jsonb_object_keys(p_scores);
  if v_got < v_need then raise exception 'ให้คะแนนให้ครบทุกเกณฑ์ก่อนบันทึก'; end if;

  insert into iv_scores(session_id, criteria_id, scorer_role, scorer_id, score)
  select p_session_id, e.key::uuid, 'teacher', v_me, e.value::int from jsonb_each_text(p_scores) e
  on conflict (session_id, criteria_id, scorer_role)
  do update set score = excluded.score, scorer_id = excluded.scorer_id, created_at = now();

  update iv_sessions
     set status = 'reviewed', reviewed_at = now(), reviewer_id = v_me,
         teacher_comment = nullif(btrim(coalesce(p_comment,'')), '')
   where id = p_session_id;
end $$;
revoke execute on function public.iv_save_review(uuid, jsonb, text) from public, anon;
grant execute on function public.iv_save_review(uuid, jsonb, text) to authenticated;

-- 2) ลบเกณฑ์ rubric แล้วคะแนนเก่าต้องไม่หาย: ห้ามลบเกณฑ์ที่มีคะแนนแล้ว ให้ปิด is_active แทน
alter table public.iv_scores drop constraint iv_scores_criteria_id_fkey;
alter table public.iv_scores add constraint iv_scores_criteria_id_fkey
  foreign key (criteria_id) references public.iv_rubric_criteria(id) on delete restrict;
