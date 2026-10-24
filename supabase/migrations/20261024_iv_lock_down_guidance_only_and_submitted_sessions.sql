-- ระบบซ้อมสัมภาษณ์: จำกัดสิทธิ์ครูให้เฉพาะครูแนะแนว + ล็อกเซ็ตที่ส่งครูแล้ว
-- (ใช้กับฐานข้อมูลจริงแล้วเมื่อ 24 ต.ค. 2569)

-- 1) ผู้มีสิทธิ์ดูแลระบบซ้อมสัมภาษณ์ = admin หรือครูแนะแนว
create or replace function public.iv_is_staff()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles p
    where p.id = auth.uid() and (p.role = 'admin' or (p.role = 'teacher' and coalesce(p.is_guidance,false))));
$$;
revoke execute on function public.iv_is_staff() from public, anon;
grant execute on function public.iv_is_staff() to authenticated;

-- 2) iv_sessions
drop policy if exists "own or staff read iv_sessions" on public.iv_sessions;
drop policy if exists "owner or staff update iv_sessions" on public.iv_sessions;
drop policy if exists "student insert own iv_sessions" on public.iv_sessions;
create policy "own or staff read iv_sessions" on public.iv_sessions for select to authenticated
  using (student_id = auth.uid() or iv_is_staff());
create policy "student insert own draft iv_sessions" on public.iv_sessions for insert to authenticated
  with check (student_id = auth.uid() and status = 'draft'
              and reviewer_id is null and reviewed_at is null and teacher_comment is null);
create policy "student update own draft iv_sessions" on public.iv_sessions for update to authenticated
  using (student_id = auth.uid() and status = 'draft')
  with check (student_id = auth.uid() and status in ('draft','submitted'));
create policy "staff update iv_sessions" on public.iv_sessions for update to authenticated
  using (iv_is_staff()) with check (iv_is_staff());

-- กันการแก้ช่องของครู/เปลี่ยนเจ้าของ แม้ policy จะผ่าน
create or replace function public.iv_sessions_guard()
returns trigger language plpgsql set search_path = public as $$
begin
  if auth.uid() is null then return new; end if;  -- งานหลังบ้าน (SQL editor/service)
  if new.student_id is distinct from old.student_id then
    raise exception 'ไม่สามารถเปลี่ยนเจ้าของเซ็ตซ้อมได้';
  end if;
  if not iv_is_staff() then
    if new.reviewer_id is distinct from old.reviewer_id
       or new.reviewed_at is distinct from old.reviewed_at
       or new.teacher_comment is distinct from old.teacher_comment
       or new.status = 'reviewed' then
      raise exception 'เฉพาะครูแนะแนวเท่านั้นที่บันทึกผลตรวจได้';
    end if;
  end if;
  return new;
end $$;
drop trigger if exists iv_sessions_guard on public.iv_sessions;
create trigger iv_sessions_guard before update on public.iv_sessions
  for each row execute function public.iv_sessions_guard();

-- 3) iv_answers: เจ้าของแก้ได้เฉพาะตอนยังเป็นฉบับซ้อม
drop policy if exists "own or staff read iv_answers" on public.iv_answers;
drop policy if exists "owner write iv_answers" on public.iv_answers;
create policy "own or staff read iv_answers" on public.iv_answers for select to authenticated
  using (exists (select 1 from iv_sessions s where s.id = iv_answers.session_id
                 and (s.student_id = auth.uid() or iv_is_staff())));
create policy "owner write draft iv_answers" on public.iv_answers for all to authenticated
  using (exists (select 1 from iv_sessions s where s.id = iv_answers.session_id
                 and s.student_id = auth.uid() and s.status = 'draft'))
  with check (exists (select 1 from iv_sessions s where s.id = iv_answers.session_id
                 and s.student_id = auth.uid() and s.status = 'draft'));

-- 4) iv_scores
drop policy if exists "own or staff read iv_scores" on public.iv_scores;
drop policy if exists "self score own session" on public.iv_scores;
drop policy if exists "teacher score any session" on public.iv_scores;
create policy "own or staff read iv_scores" on public.iv_scores for select to authenticated
  using (exists (select 1 from iv_sessions s where s.id = iv_scores.session_id
                 and (s.student_id = auth.uid() or iv_is_staff())));
create policy "self score own draft session" on public.iv_scores for all to authenticated
  using (scorer_role = 'self' and scorer_id = auth.uid()
         and exists (select 1 from iv_sessions s where s.id = iv_scores.session_id
                     and s.student_id = auth.uid() and s.status = 'draft'))
  with check (scorer_role = 'self' and scorer_id = auth.uid()
         and exists (select 1 from iv_sessions s where s.id = iv_scores.session_id
                     and s.student_id = auth.uid() and s.status = 'draft'));
create policy "staff teacher score" on public.iv_scores for all to authenticated
  using (scorer_role = 'teacher' and iv_is_staff()
         and (scorer_id = auth.uid() or get_my_role() = 'admin'))
  with check (scorer_role = 'teacher' and scorer_id = auth.uid() and iv_is_staff());

-- 5) คลังคำถาม / หมวด / checklist: ครูแนะแนวจัดการ
drop policy if exists "staff write iv_categories" on public.iv_categories;
create policy "staff write iv_categories" on public.iv_categories for all to authenticated
  using (iv_is_staff()) with check (iv_is_staff());
drop policy if exists "staff write iv_questions" on public.iv_questions;
create policy "staff write iv_questions" on public.iv_questions for all to authenticated
  using (iv_is_staff()) with check (iv_is_staff());
drop policy if exists "staff write iv_checklist_items" on public.iv_checklist_items;
create policy "staff write iv_checklist_items" on public.iv_checklist_items for all to authenticated
  using (iv_is_staff()) with check (iv_is_staff());
drop policy if exists "own or staff read iv_checklist_done" on public.iv_checklist_done;
create policy "own or staff read iv_checklist_done" on public.iv_checklist_done for select to authenticated
  using (student_id = auth.uid() or iv_is_staff());

-- 6) ไฟล์เสียง: ฟังได้เฉพาะเจ้าของและครูแนะแนว
drop policy if exists "iv rec read own or staff" on storage.objects;
create policy "iv rec read own or staff" on storage.objects for select to authenticated
  using (bucket_id = 'iv-recordings'
         and ((storage.foldername(name))[1] = auth.uid()::text or public.iv_is_staff()));
