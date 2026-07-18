-- ระบบฝึกซ้อมสอบสัมภาษณ์ (เฟส 1): schema + RLS + storage
-- ตารางทั้งหมดใช้ prefix iv_ กันชนกับระบบคลังแนะแนวเดิม
-- หมายเหตุ: migration นี้ถูก apply กับโปรเจกต์ guidance-library แล้วเมื่อ 2026-07-18

create table public.iv_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  emoji text not null default '🎓',
  color text not null default '#0F6B5C',
  sort_order int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.iv_questions (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.iv_categories(id) on delete cascade,
  question_text text not null,
  guide_answer text,
  difficulty text not null default 'medium' check (difficulty in ('easy','medium','hard')),
  suggested_seconds int not null default 120,
  lang text not null default 'th' check (lang in ('th','en')),
  is_active boolean not null default true,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.iv_rubric_criteria (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  title text not null,
  description text,
  sort_order int not null default 0,
  is_active boolean not null default true
);

create table public.iv_sessions (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null default 'solo' check (kind in ('solo','mock')),
  category_id uuid references public.iv_categories(id) on delete set null,
  status text not null default 'draft' check (status in ('draft','submitted','reviewed')),
  submitted_at timestamptz,
  reviewed_at timestamptz,
  reviewer_id uuid references public.profiles(id) on delete set null,
  teacher_comment text,
  created_at timestamptz not null default now()
);
create index iv_sessions_student_idx on public.iv_sessions(student_id, created_at desc);
create index iv_sessions_status_idx on public.iv_sessions(status, submitted_at);

create table public.iv_answers (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.iv_sessions(id) on delete cascade,
  question_id uuid references public.iv_questions(id) on delete set null,
  question_text text not null,          -- snapshot ของคำถาม กันกรณีคำถามถูกแก้/ลบภายหลัง
  guide_answer text,                    -- snapshot แนวทางการตอบ
  answer_text text,
  media_path text,
  media_kind text not null default 'none' check (media_kind in ('none','audio','video')),
  seconds_used int,
  order_no int not null default 1
);
create index iv_answers_session_idx on public.iv_answers(session_id, order_no);

create table public.iv_scores (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.iv_sessions(id) on delete cascade,
  criteria_id uuid not null references public.iv_rubric_criteria(id) on delete cascade,
  scorer_role text not null check (scorer_role in ('self','teacher')),
  scorer_id uuid references public.profiles(id) on delete set null,
  score int not null check (score between 1 and 4),
  note text,
  created_at timestamptz not null default now(),
  unique (session_id, criteria_id, scorer_role)
);

-- ═══ RLS ═══
alter table public.iv_categories enable row level security;
alter table public.iv_questions enable row level security;
alter table public.iv_rubric_criteria enable row level security;
alter table public.iv_sessions enable row level security;
alter table public.iv_answers enable row level security;
alter table public.iv_scores enable row level security;

-- คลังคำถาม/หมวด/rubric: ทุกคนที่ login อ่านได้ ครู+admin แก้ได้
create policy "authenticated read iv_categories" on public.iv_categories
  for select to authenticated using (true);
create policy "staff write iv_categories" on public.iv_categories
  for all to authenticated
  using (get_my_role() in ('teacher','admin'))
  with check (get_my_role() in ('teacher','admin'));

create policy "authenticated read iv_questions" on public.iv_questions
  for select to authenticated using (true);
create policy "staff write iv_questions" on public.iv_questions
  for all to authenticated
  using (get_my_role() in ('teacher','admin'))
  with check (get_my_role() in ('teacher','admin'));

create policy "authenticated read iv_rubric" on public.iv_rubric_criteria
  for select to authenticated using (true);
create policy "admin write iv_rubric" on public.iv_rubric_criteria
  for all to authenticated
  using (get_my_role() = 'admin')
  with check (get_my_role() = 'admin');

-- sessions: นักเรียนจัดการของตัวเอง ครู/admin อ่านทั้งหมด + อัปเดตเพื่อรีวิว
create policy "own or staff read iv_sessions" on public.iv_sessions
  for select to authenticated
  using (student_id = auth.uid() or get_my_role() in ('teacher','admin'));
create policy "student insert own iv_sessions" on public.iv_sessions
  for insert to authenticated
  with check (student_id = auth.uid());
create policy "owner or staff update iv_sessions" on public.iv_sessions
  for update to authenticated
  using (student_id = auth.uid() or get_my_role() in ('teacher','admin'));
create policy "owner or admin delete iv_sessions" on public.iv_sessions
  for delete to authenticated
  using (student_id = auth.uid() or get_my_role() = 'admin');

-- answers: ตาม ownership ของ session
create policy "own or staff read iv_answers" on public.iv_answers
  for select to authenticated
  using (exists (select 1 from public.iv_sessions s where s.id = session_id
         and (s.student_id = auth.uid() or get_my_role() in ('teacher','admin'))));
create policy "owner write iv_answers" on public.iv_answers
  for all to authenticated
  using (exists (select 1 from public.iv_sessions s where s.id = session_id and s.student_id = auth.uid()))
  with check (exists (select 1 from public.iv_sessions s where s.id = session_id and s.student_id = auth.uid()));

-- scores: self = เจ้าของ session, teacher = ครู/admin
create policy "own or staff read iv_scores" on public.iv_scores
  for select to authenticated
  using (exists (select 1 from public.iv_sessions s where s.id = session_id
         and (s.student_id = auth.uid() or get_my_role() in ('teacher','admin'))));
create policy "self score own session" on public.iv_scores
  for all to authenticated
  using (scorer_role = 'self' and scorer_id = auth.uid()
         and exists (select 1 from public.iv_sessions s where s.id = session_id and s.student_id = auth.uid()))
  with check (scorer_role = 'self' and scorer_id = auth.uid()
         and exists (select 1 from public.iv_sessions s where s.id = session_id and s.student_id = auth.uid()));
create policy "teacher score any session" on public.iv_scores
  for all to authenticated
  using (scorer_role = 'teacher' and get_my_role() in ('teacher','admin'))
  with check (scorer_role = 'teacher' and scorer_id = auth.uid() and get_my_role() in ('teacher','admin'));

-- ═══ Storage: bucket เก็บไฟล์อัดเสียง (private) path = {uid}/{session_id}/{ไฟล์} ═══
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('iv-recordings','iv-recordings', false, 26214400, array['audio/webm','audio/mp4','audio/mpeg','audio/ogg','video/webm','video/mp4'])
on conflict (id) do nothing;

create policy "iv rec upload own folder" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'iv-recordings' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "iv rec read own or staff" on storage.objects
  for select to authenticated
  using (bucket_id = 'iv-recordings'
         and ((storage.foldername(name))[1] = auth.uid()::text or get_my_role() in ('teacher','admin')));
create policy "iv rec delete own or admin" on storage.objects
  for delete to authenticated
  using (bucket_id = 'iv-recordings'
         and ((storage.foldername(name))[1] = auth.uid()::text or get_my_role() = 'admin'));
