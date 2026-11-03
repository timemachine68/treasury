-- เกมห้องหนี (ควิซแบบ ZEP QUIZ ทำเอง) สำหรับคาบแนะแนว
-- นักเรียนล็อกอินบัญชีแนะให้แนว เห็นเฉพาะเกมที่เปิดให้ห้องตัวเอง
-- เฉลยอยู่ในฐานข้อมูลเท่านั้น นักเรียนตอบผ่าน RPC ที่ตรวจคำตอบฝั่งเซิร์ฟเวอร์
-- ครูแนะแนว/แอดมิน (iv_is_staff) สร้างชุดคำถาม เปิดรอบเล่นรายห้อง และดูผลสด

-- ---------- ตรวจรูปแบบประตู ----------
create or replace function public.er_valid_doors(d jsonb)
returns boolean language plpgsql immutable set search_path = public as $$
declare x jsonb; n int;
begin
  if d is null or jsonb_typeof(d) <> 'array' then return false; end if;
  if jsonb_array_length(d) < 1 or jsonb_array_length(d) > 10 then return false; end if;
  for x in select * from jsonb_array_elements(d) loop
    if jsonb_typeof(x) <> 'object' then return false; end if;
    if coalesce(x->>'type','') not in ('mc','reflect') then return false; end if;
    if length(btrim(coalesce(x->>'q',''))) = 0 then return false; end if;
    if jsonb_typeof(x->'choices') <> 'array' then return false; end if;
    n := jsonb_array_length(x->'choices');
    if x->>'type' = 'mc' then
      if n < 2 or n > 4 then return false; end if;
      if jsonb_typeof(x->'answer') <> 'number' then return false; end if;
      if (x->>'answer')::int < 0 or (x->>'answer')::int >= n then return false; end if;
    else
      if n < 2 or n > 12 then return false; end if;
      if jsonb_typeof(x->'max_pick') <> 'number' then return false; end if;
      if (x->>'max_pick')::int < 1 or (x->>'max_pick')::int > n then return false; end if;
    end if;
  end loop;
  return true;
end $$;

-- ---------- ตาราง ----------
create table if not exists public.er_quiz_sets (
  id uuid primary key default gen_random_uuid(),
  title text not null check (length(btrim(title)) between 1 and 120),
  topic text not null default '',
  grade text not null default 'ม.1',
  doors jsonb not null default '[]'::jsonb check (jsonb_typeof(doors) = 'array'),
  created_by uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
comment on table public.er_quiz_sets is 'ชุดคำถามเกมห้องหนี (มีเฉลย) — นักเรียนอ่านตรงไม่ได้ ครูแนะแนวเห็นทุกชุด แก้ได้เฉพาะของตัวเอง';

create table if not exists public.er_sessions (
  id uuid primary key default gen_random_uuid(),
  set_id uuid references public.er_quiz_sets(id) on delete set null,
  title text not null,
  doors jsonb not null check (public.er_valid_doors(doors)),
  class_room text not null,
  status text not null default 'open' check (status in ('open','closed')),
  created_by uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  opened_at timestamptz not null default now(),
  closed_at timestamptz
);
comment on table public.er_sessions is 'รอบเล่นเกมห้องหนีรายห้อง — เก็บสำเนาคำถาม ณ ตอนเปิด แก้ชุดคำถามทีหลังไม่กระทบรอบที่เล่นอยู่';
create unique index if not exists er_sessions_one_open on public.er_sessions (set_id, class_room) where status = 'open';
create index if not exists er_sessions_room_open on public.er_sessions (class_room) where status = 'open';
create index if not exists er_sessions_opened on public.er_sessions (opened_at desc);

create table if not exists public.er_attempts (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.er_sessions(id) on delete cascade,
  student_id uuid not null references public.profiles(id) on delete cascade,
  class_room text not null,
  avatar smallint not null default 0 check (avatar between 0 and 3),
  current_door int not null default 0,
  door_tries jsonb not null default '[]'::jsonb,
  first_try int not null default 0,
  wrong_total int not null default 0,
  reflection jsonb,
  started_at timestamptz not null default now(),
  last_active_at timestamptz not null default now(),
  finished_at timestamptz,
  unique (session_id, student_id)
);
comment on table public.er_attempts is 'ผลเล่นเกมห้องหนีรายคน — นักเรียนเขียนผ่าน er_join/er_answer เท่านั้น';
create index if not exists er_attempts_student on public.er_attempts (student_id);

-- ---------- RLS ----------
alter table public.er_quiz_sets enable row level security;
alter table public.er_sessions enable row level security;
alter table public.er_attempts enable row level security;

drop policy if exists er_sets_staff_read on public.er_quiz_sets;
create policy er_sets_staff_read on public.er_quiz_sets for select to authenticated
  using ((select public.iv_is_staff()));
drop policy if exists er_sets_staff_insert on public.er_quiz_sets;
create policy er_sets_staff_insert on public.er_quiz_sets for insert to authenticated
  with check ((select public.iv_is_staff()) and created_by = (select auth.uid()));
drop policy if exists er_sets_owner_update on public.er_quiz_sets;
create policy er_sets_owner_update on public.er_quiz_sets for update to authenticated
  using ((select public.iv_is_staff()) and (created_by = (select auth.uid()) or (select public.get_my_role()) = 'admin'))
  with check ((select public.iv_is_staff()) and (created_by = (select auth.uid()) or (select public.get_my_role()) = 'admin'));
drop policy if exists er_sets_owner_delete on public.er_quiz_sets;
create policy er_sets_owner_delete on public.er_quiz_sets for delete to authenticated
  using ((select public.iv_is_staff()) and (created_by = (select auth.uid()) or (select public.get_my_role()) = 'admin'));

drop policy if exists er_sessions_staff_read on public.er_sessions;
create policy er_sessions_staff_read on public.er_sessions for select to authenticated
  using ((select public.iv_is_staff()));
drop policy if exists er_sessions_staff_insert on public.er_sessions;
create policy er_sessions_staff_insert on public.er_sessions for insert to authenticated
  with check ((select public.iv_is_staff()) and created_by = (select auth.uid()) and status = 'open');
drop policy if exists er_sessions_staff_update on public.er_sessions;
create policy er_sessions_staff_update on public.er_sessions for update to authenticated
  using ((select public.iv_is_staff()))
  with check ((select public.iv_is_staff()));

drop policy if exists er_attempts_staff_read on public.er_attempts;
create policy er_attempts_staff_read on public.er_attempts for select to authenticated
  using ((select public.iv_is_staff()));
drop policy if exists er_attempts_staff_delete on public.er_attempts;
create policy er_attempts_staff_delete on public.er_attempts for delete to authenticated
  using ((select public.iv_is_staff()));

revoke all on public.er_quiz_sets, public.er_sessions, public.er_attempts from public, anon;
revoke all on public.er_quiz_sets, public.er_sessions, public.er_attempts from authenticated;
grant select, insert, update, delete on public.er_quiz_sets to authenticated;
grant select, insert, update (status, closed_at) on public.er_sessions to authenticated;
grant select, delete on public.er_attempts to authenticated;

-- ห้ามแก้คำถาม/ห้องของรอบที่เปิดไปแล้ว (แก้ได้แค่ปิด-เปิดรอบ) — บังคับด้วย column grant ด้านบน
-- กันเปิดรอบซ้ำ: unique index er_sessions_one_open

-- ---------- ตัวช่วย: ตัดเฉลยออกก่อนส่งให้นักเรียน ----------
create or replace function public.er_public_doors(d jsonb)
returns jsonb language sql immutable set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'type', x->>'type', 'q', x->>'q', 'choices', x->'choices', 'max_pick', x->'max_pick'
  ) order by o), '[]'::jsonb)
  from jsonb_array_elements(d) with ordinality as t(x, o)
$$;

-- ---------- นักเรียน: เกมที่เปิดให้ห้องเรา ----------
create or replace function public.er_my_games()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_room text; v_open jsonb; v_done jsonb;
begin
  if v_uid is null then raise exception 'ต้องเข้าสู่ระบบก่อน'; end if;
  if public.get_my_role() <> 'student' then raise exception 'หน้านี้สำหรับนักเรียน'; end if;
  v_room := public.get_my_room();
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', s.id, 'title', s.title, 'doors', jsonb_array_length(s.doors),
      'opened_at', s.opened_at, 'teacher', p.display_name,
      'current_door', a.current_door, 'finished_at', a.finished_at
    ) order by s.opened_at desc), '[]'::jsonb)
    into v_open
    from public.er_sessions s
    left join public.profiles p on p.id = s.created_by
    left join public.er_attempts a on a.session_id = s.id and a.student_id = v_uid
   where s.status = 'open' and s.class_room = v_room;
  select coalesce(jsonb_agg(x order by (x->>'started_at') desc), '[]'::jsonb) into v_done from (
    select jsonb_build_object('id', s.id, 'title', s.title, 'doors', jsonb_array_length(s.doors),
           'current_door', a.current_door, 'finished_at', a.finished_at, 'started_at', a.started_at) x
      from public.er_attempts a join public.er_sessions s on s.id = a.session_id
     where a.student_id = v_uid and (s.status = 'closed' or s.class_room <> coalesce(v_room, ''))
     order by a.started_at desc limit 10) q;
  return jsonb_build_object('room', v_room, 'open', v_open, 'done', v_done);
end $$;

-- ---------- นักเรียน: เข้าห้อง (สร้างผลเล่นถ้ายังไม่มี) ----------
create or replace function public.er_join(p_session uuid, p_avatar int default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); s public.er_sessions; a public.er_attempts; v_esc int;
begin
  if v_uid is null then raise exception 'ต้องเข้าสู่ระบบก่อน'; end if;
  if public.get_my_role() <> 'student' then raise exception 'หน้านี้สำหรับนักเรียน'; end if;
  select * into s from public.er_sessions where id = p_session;
  if not found then raise exception 'ไม่พบภารกิจนี้'; end if;
  select * into a from public.er_attempts where session_id = p_session and student_id = v_uid;
  if not found then
    if s.status <> 'open' then raise exception 'ครูปิดภารกิจนี้แล้ว'; end if;
    if s.class_room is distinct from public.get_my_room() then raise exception 'ภารกิจนี้ไม่ได้เปิดให้ห้องของเรา'; end if;
    insert into public.er_attempts (session_id, student_id, class_room, avatar)
    values (p_session, v_uid, s.class_room, least(greatest(coalesce(p_avatar, 0), 0), 3))
    on conflict (session_id, student_id) do nothing;
    select * into a from public.er_attempts where session_id = p_session and student_id = v_uid;
  elsif p_avatar is not null and a.finished_at is null and s.status = 'open' then
    update public.er_attempts set avatar = least(greatest(p_avatar, 0), 3), last_active_at = now()
     where id = a.id returning * into a;
  end if;
  select count(*) into v_esc from public.er_attempts where session_id = p_session and finished_at is not null;
  return jsonb_build_object(
    'session', jsonb_build_object('id', s.id, 'title', s.title, 'status', s.status, 'class_room', s.class_room),
    'doors', public.er_public_doors(s.doors),
    'attempt', jsonb_build_object('current_door', a.current_door, 'first_try', a.first_try, 'wrong_total', a.wrong_total,
       'avatar', a.avatar, 'started_at', a.started_at, 'finished_at', a.finished_at, 'reflection', a.reflection),
    'escaped', v_esc);
end $$;

-- ---------- นักเรียน: ตอบประตู (ตรวจคำตอบฝั่งเซิร์ฟเวอร์) ----------
create or replace function public.er_answer(p_session uuid, p_door int, p_choices int[])
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid(); s public.er_sessions; a public.er_attempts; d jsonb;
  n int; nc int; tries jsonb; t int; ok boolean; mx int; cnt int; v_ref jsonb; v_next int; v_esc int;
begin
  if v_uid is null then raise exception 'ต้องเข้าสู่ระบบก่อน'; end if;
  select * into s from public.er_sessions where id = p_session;
  if not found then raise exception 'ไม่พบภารกิจนี้'; end if;
  select * into a from public.er_attempts where session_id = p_session and student_id = v_uid for update;
  if not found then raise exception 'ยังไม่ได้เข้าห้องนี้'; end if;
  if a.finished_at is not null then
    return jsonb_build_object('finished', true, 'current_door', a.current_door);
  end if;
  if s.status <> 'open' then
    return jsonb_build_object('error', 'ครูปิดภารกิจนี้แล้ว', 'current_door', a.current_door);
  end if;
  if p_door is distinct from a.current_door then
    return jsonb_build_object('error', 'stale', 'current_door', a.current_door);
  end if;
  n := jsonb_array_length(s.doors);
  d := s.doors -> p_door;
  nc := jsonb_array_length(d -> 'choices');
  cnt := coalesce(array_length(p_choices, 1), 0);
  if exists (select 1 from unnest(p_choices) x where x is null or x < 0 or x >= nc) then
    return jsonb_build_object('error', 'คำตอบไม่ถูกรูปแบบ');
  end if;
  if d->>'type' = 'reflect' then
    mx := (d->>'max_pick')::int;
    if cnt < 1 or cnt > mx or (select count(distinct x) from unnest(p_choices) x) <> cnt then
      return jsonb_build_object('error', 'เลือกได้ 1 ถึง ' || mx || ' ข้อ');
    end if;
    ok := true;
    select jsonb_agg(d->'choices'->>x order by x) into v_ref from unnest(p_choices) x;
  else
    if cnt <> 1 then return jsonb_build_object('error', 'เลือกคำตอบ 1 ข้อ'); end if;
    ok := p_choices[1] = (d->>'answer')::int;
  end if;

  tries := case when jsonb_typeof(a.door_tries) = 'array' then a.door_tries else '[]'::jsonb end;
  while jsonb_array_length(tries) <= p_door loop tries := tries || '0'::jsonb; end loop;
  t := coalesce((tries->>p_door)::int, 0) + 1;
  tries := jsonb_set(tries, array[p_door::text], to_jsonb(t));

  if ok then
    v_next := a.current_door + 1;
    update public.er_attempts set
      current_door = v_next,
      door_tries = tries,
      first_try = first_try + case when t = 1 and d->>'type' = 'mc' then 1 else 0 end,
      reflection = coalesce(v_ref, reflection),
      finished_at = case when v_next >= n then now() else null end,
      last_active_at = now()
    where id = a.id;
  else
    v_next := a.current_door;
    update public.er_attempts set door_tries = tries, wrong_total = wrong_total + 1, last_active_at = now()
     where id = a.id;
  end if;
  select count(*) into v_esc from public.er_attempts where session_id = p_session and finished_at is not null;
  return jsonb_build_object('correct', ok, 'hint', case when ok then null else d->>'hint' end,
    'current_door', v_next, 'finished', v_next >= n, 'tries', t, 'escaped', v_esc);
end $$;

-- ---------- ครู: รายชื่อห้อง ----------
create or replace function public.er_rooms()
returns table (class_room text, students int)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.iv_is_staff() then raise exception 'เฉพาะครูแนะแนว'; end if;
  return query
    select p.class_room, count(*)::int from public.profiles p
     where p.role = 'student' and coalesce(p.status, 'active') = 'active' and p.class_room is not null
     group by p.class_room;
end $$;

-- ---------- ครู: กระดานผลสด (รายชื่อทั้งห้อง + ผลเล่น) ----------
create or replace function public.er_session_board(p_session uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare s public.er_sessions; v_rows jsonb;
begin
  if not public.iv_is_staff() then raise exception 'เฉพาะครูแนะแนว'; end if;
  select * into s from public.er_sessions where id = p_session;
  if not found then raise exception 'ไม่พบรอบเล่นนี้'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
      'student_id', r.id, 'code', coalesce(r.student_id, r.username), 'name', r.display_name,
      'joined', a.id is not null, 'current_door', a.current_door, 'door_tries', a.door_tries,
      'first_try', a.first_try, 'wrong_total', a.wrong_total, 'reflection', a.reflection,
      'started_at', a.started_at, 'last_active_at', a.last_active_at, 'finished_at', a.finished_at
    ) order by coalesce(r.student_id, r.username)), '[]'::jsonb)
    into v_rows
    from (
      select p.id, p.student_id, p.username, p.display_name from public.profiles p
       where p.role = 'student' and coalesce(p.status, 'active') = 'active' and p.class_room = s.class_room
      union
      select p.id, p.student_id, p.username, p.display_name from public.er_attempts x
        join public.profiles p on p.id = x.student_id where x.session_id = p_session
    ) r
    left join public.er_attempts a on a.session_id = p_session and a.student_id = r.id;
  return jsonb_build_object('session', jsonb_build_object('id', s.id, 'title', s.title, 'class_room', s.class_room,
      'status', s.status, 'opened_at', s.opened_at, 'closed_at', s.closed_at, 'doors', s.doors),
    'rows', v_rows);
end $$;

revoke all on function public.er_valid_doors(jsonb), public.er_public_doors(jsonb), public.er_my_games(),
  public.er_join(uuid, int), public.er_answer(uuid, int, int[]), public.er_rooms(), public.er_session_board(uuid)
  from public, anon;
grant execute on function public.er_valid_doors(jsonb), public.er_public_doors(jsonb), public.er_my_games(),
  public.er_join(uuid, int), public.er_answer(uuid, int, int[]), public.er_rooms(), public.er_session_board(uuid)
  to authenticated;
