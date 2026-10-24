-- ระบบซ้อมสัมภาษณ์: นักเรียนที่ไปสัมภาษณ์มาแล้วแชร์คำถามเข้าคลัง (ครูแนะแนวตรวจก่อนขึ้นคลัง)
-- (ใช้กับฐานข้อมูลจริงแล้วเมื่อ 24 ต.ค. 2569)

-- 1) ธงบอกว่าคำถามนี้มาจากรุ่นพี่แชร์ (ไม่เก็บชื่อผู้แชร์ในคลัง)
alter table public.iv_questions add column is_student_shared boolean not null default false;

-- 2) กล่องรอตรวจ
create table public.iv_question_submissions (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.profiles(id) on delete cascade,
  university_id uuid references public.iv_universities(id) on delete set null,
  target_university text,
  target_faculty text,
  round_label text check (round_label is null or round_label in ('portfolio','quota','direct','admission','other')),
  question_text text not null check (char_length(btrim(question_text)) between 10 and 300),
  answer_tip text check (answer_tip is null or char_length(answer_tip) <= 500),
  lang text not null default 'th' check (lang in ('th','en')),
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  reviewer_id uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  reject_reason text check (reject_reason is null or char_length(reject_reason) <= 300),
  approved_question_id uuid references public.iv_questions(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint iv_sub_target_len check (char_length(coalesce(target_university,'')) <= 120
                                  and char_length(coalesce(target_faculty,'')) <= 120)
);
create index iv_sub_status_idx on public.iv_question_submissions(status, created_at);
create index iv_sub_student_idx on public.iv_question_submissions(student_id);
-- ห้ามส่งข้อความเดิมซ้ำ (กันกดส่งซ้ำ)
create unique index iv_sub_student_text_uq on public.iv_question_submissions(student_id, md5(lower(btrim(question_text))));

alter table public.iv_question_submissions enable row level security;
create policy "own or staff read iv_sub" on public.iv_question_submissions for select to authenticated
  using (student_id = auth.uid() or iv_is_staff());
create policy "student insert own pending iv_sub" on public.iv_question_submissions for insert to authenticated
  with check (student_id = auth.uid() and get_my_role() = 'student' and status = 'pending'
              and reviewer_id is null and reviewed_at is null and reject_reason is null and approved_question_id is null);
create policy "student delete own pending iv_sub" on public.iv_question_submissions for delete to authenticated
  using (student_id = auth.uid() and status = 'pending');
create policy "staff update iv_sub" on public.iv_question_submissions for update to authenticated
  using (iv_is_staff()) with check (iv_is_staff());
create policy "staff delete iv_sub" on public.iv_question_submissions for delete to authenticated
  using (iv_is_staff());

-- กันส่งรัว: รอตรวจพร้อมกันได้ไม่เกิน 10 ข้อต่อคน
create or replace function public.iv_sub_limit()
returns trigger language plpgsql set search_path = public as $$
begin
  if (select count(*) from iv_question_submissions where student_id = new.student_id and status = 'pending') >= 10 then
    raise exception 'มีคำถามรอครูตรวจครบ 10 ข้อแล้ว รอให้ครูตรวจก่อนแล้วค่อยส่งเพิ่มนะ';
  end if;
  return new;
end $$;
create trigger iv_sub_limit before insert on public.iv_question_submissions
  for each row execute function public.iv_sub_limit();

-- 3) ครูอนุมัติ → ขึ้นคลังทันที (ครั้งเดียวจบ) — ครูแก้ถ้อยคำ/หมวดได้ก่อนขึ้น
create or replace function public.iv_approve_submission(
  p_id uuid, p_category_id uuid, p_university_id uuid, p_is_ai boolean,
  p_question_text text, p_guide_answer text, p_difficulty text, p_seconds int, p_lang text)
returns uuid language plpgsql security invoker set search_path = public as $$
declare s record; v_q uuid; v_text text := btrim(coalesce(p_question_text,''));
begin
  if not iv_is_staff() then raise exception 'เฉพาะครูแนะแนวเท่านั้นที่อนุมัติได้'; end if;
  select * into s from iv_question_submissions where id = p_id for update;
  if not found then raise exception 'ไม่พบคำถามนี้ อาจถูกลบไปแล้ว'; end if;
  if s.status <> 'pending' then raise exception 'คำถามนี้ถูกตรวจไปแล้ว'; end if;
  if char_length(v_text) < 10 then raise exception 'คำถามสั้นเกินไป'; end if;
  if p_university_id is not null and coalesce(p_is_ai,false) then
    raise exception 'เลือกได้แบบเดียว: เฉพาะมหาวิทยาลัย หรือ คำถาม AI';
  end if;
  if p_difficulty not in ('easy','medium','hard') then raise exception 'ระดับความยากไม่ถูกต้อง'; end if;
  if exists (select 1 from iv_questions x where x.category_id = p_category_id
             and x.university_id is not distinct from p_university_id
             and lower(btrim(x.question_text)) = lower(v_text)) then
    raise exception 'มีคำถามนี้ในคลังแล้ว ให้กดไม่รับแทน';
  end if;
  insert into iv_questions(category_id, university_id, question_text, guide_answer, difficulty,
                           suggested_seconds, lang, is_active, is_ai, is_student_shared, created_by)
  values (p_category_id, p_university_id, v_text, nullif(btrim(coalesce(p_guide_answer,'')),''), p_difficulty,
          greatest(30, least(600, coalesce(p_seconds,120))), coalesce(p_lang,'th'), true, coalesce(p_is_ai,false), true, auth.uid())
  returning id into v_q;
  update iv_question_submissions
     set status='approved', reviewer_id=auth.uid(), reviewed_at=now(), approved_question_id=v_q, reject_reason=null
   where id = p_id;
  return v_q;
end $$;

create or replace function public.iv_reject_submission(p_id uuid, p_reason text)
returns void language plpgsql security invoker set search_path = public as $$
declare s record;
begin
  if not iv_is_staff() then raise exception 'เฉพาะครูแนะแนวเท่านั้นที่ตรวจได้'; end if;
  select * into s from iv_question_submissions where id = p_id for update;
  if not found then raise exception 'ไม่พบคำถามนี้ อาจถูกลบไปแล้ว'; end if;
  if s.status <> 'pending' then raise exception 'คำถามนี้ถูกตรวจไปแล้ว'; end if;
  update iv_question_submissions
     set status='rejected', reviewer_id=auth.uid(), reviewed_at=now(),
         reject_reason = nullif(left(btrim(coalesce(p_reason,'')),300),'')
   where id = p_id;
end $$;

revoke execute on function public.iv_approve_submission(uuid,uuid,uuid,boolean,text,text,text,int,text) from public, anon;
revoke execute on function public.iv_reject_submission(uuid,text) from public, anon;
grant execute on function public.iv_approve_submission(uuid,uuid,uuid,boolean,text,text,text,int,text) to authenticated;
grant execute on function public.iv_reject_submission(uuid,text) to authenticated;
