-- ตัวอย่างแนวคำตอบ (ซ้อมสัมภาษณ์) — แยกตาราง ไม่อยู่ใน iv_questions เพื่อไม่ให้นักเรียนอ่านก่อนส่งคำตอบ
create table public.iv_sample_answers (
  question_id uuid primary key references public.iv_questions(id) on delete cascade,
  answer_text text not null check (char_length(answer_text) between 10 and 1500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.iv_sample_answers enable row level security;

create policy "staff all iv_sample_answers" on public.iv_sample_answers
  for all to authenticated
  using ((select iv_is_staff())) with check ((select iv_is_staff()));

revoke all on public.iv_sample_answers from anon, public;

-- นักเรียนดูได้เฉพาะข้อที่ตนส่งคำตอบแล้ว (status submitted/reviewed) ครูแนะแนวดูได้ทุกข้อ
create or replace function public.iv_sample_for_question(p_question_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare v text;
begin
  if auth.uid() is null then
    raise exception 'ต้องเข้าสู่ระบบก่อน';
  end if;
  if not (
    (select iv_is_staff())
    or exists (
      select 1 from iv_answers a join iv_sessions s on s.id = a.session_id
      where a.question_id = p_question_id
        and s.student_id = auth.uid()
        and s.status in ('submitted','reviewed')
    )
  ) then
    raise exception 'ส่งคำตอบข้อนี้ก่อน จึงจะดูตัวอย่างคำตอบได้';
  end if;
  select answer_text into v from iv_sample_answers where question_id = p_question_id;
  return v;
end $$;

revoke all on function public.iv_sample_for_question(uuid) from public, anon;
grant execute on function public.iv_sample_for_question(uuid) to authenticated;
