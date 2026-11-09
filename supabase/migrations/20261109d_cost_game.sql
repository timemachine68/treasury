-- เกม "ใกล้บ้าน vs ไกลบ้าน: 4 ปีจ่ายจริงเท่าไหร่?" (แนะแนว ม.6 หน่วย 2 แผน B)
-- เก็บ: โหวตก่อนเล่น (ทายว่าฝั่งไหนถูกกว่า) + ผลเทียบ 4 ปี + โหวตหลังเล่น  — 1 แถวต่อนักเรียนต่อปีการศึกษา
-- ไม่เก็บรายได้/ฐานะจริงของครอบครัว ตัวเลขทั้งหมดเป็นของ "เส้นทางที่เลือกในเกม"
-- สิทธิ์: นักเรียนอ่านได้เฉพาะแถวตัวเอง เขียนผ่าน RPC เท่านั้น / ครูแนะแนว+แอดมิน (iv_is_staff) อ่านทั้งหมดและลบได้

create table if not exists public.cost_game_plays (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.profiles(id) on delete cascade,
  academic_year text not null default '2569',
  class_room text not null,
  pre_guess text not null check (pre_guess in ('private','public','same')),
  track text check (track ~ '^[a-z0-9_]{1,40}$'),
  private_prog text check (private_prog ~ '^[a-z0-9_]{1,40}$'),
  public_prog text check (public_prog ~ '^[a-z0-9_]{1,40}$'),
  housing text check (housing in ('home','dorm_in','dorm_out')),
  total_private integer check (total_private between 0 and 5000000),
  total_public integer check (total_public between 0 and 5000000),
  events text[] not null default '{}',
  top_reason text check (top_reason ~ '^[a-z_]{1,30}$'),
  post_choice text check (post_choice in ('private','public','unsure')),
  talk_home text check (talk_home in ('yes','maybe','no')),
  play_count integer not null default 0,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  updated_at timestamptz not null default now(),
  unique (student_id, academic_year)
);
comment on table public.cost_game_plays is 'เกมเทียบค่าใช้จ่าย 4 ปี (เอกชนใกล้บ้าน vs รัฐ) — นักเรียนเห็นแถวตัวเอง เขียนผ่าน cost_game_start/cost_game_finish เท่านั้น ครูแนะแนวดูสรุปรายห้อง';
create index if not exists cost_game_plays_room_idx on public.cost_game_plays (academic_year, class_room);

alter table public.cost_game_plays enable row level security;

drop policy if exists cost_game_own_read on public.cost_game_plays;
create policy cost_game_own_read on public.cost_game_plays for select to authenticated
  using (student_id = (select auth.uid()));
drop policy if exists cost_game_staff_read on public.cost_game_plays;
create policy cost_game_staff_read on public.cost_game_plays for select to authenticated
  using ((select public.iv_is_staff()));
drop policy if exists cost_game_staff_delete on public.cost_game_plays;
create policy cost_game_staff_delete on public.cost_game_plays for delete to authenticated
  using ((select public.iv_is_staff()));

revoke all on public.cost_game_plays from public, anon, authenticated;
grant select, delete on public.cost_game_plays to authenticated;

-- โหวตก่อนเล่น: บันทึกครั้งแรกครั้งเดียว (เล่นซ้ำไม่ทับคำทายเดิม เพื่อเทียบก่อน-หลังได้จริง)
create or replace function public.cost_game_start(p_guess text, p_year text default '2569')
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare v_uid uuid := auth.uid(); v_room text; r public.cost_game_plays;
begin
  if v_uid is null then raise exception 'ต้องเข้าสู่ระบบก่อน'; end if;
  if public.get_my_role() is distinct from 'student' then raise exception 'หน้านี้สำหรับนักเรียน'; end if;
  if p_guess not in ('private','public','same') then raise exception 'คำตอบไม่ถูกต้อง'; end if;
  if p_year !~ '^25[0-9]{2}$' then raise exception 'ปีการศึกษาไม่ถูกต้อง'; end if;
  v_room := public.get_my_room();
  if coalesce(trim(v_room),'') = '' then raise exception 'บัญชีนี้ยังไม่มีห้องเรียนในระบบ แจ้งครูก่อนนะ'; end if;
  insert into public.cost_game_plays (student_id, academic_year, class_room, pre_guess)
  values (v_uid, p_year, v_room, p_guess)
  on conflict (student_id, academic_year) do nothing;
  select * into r from public.cost_game_plays where student_id = v_uid and academic_year = p_year;
  return jsonb_build_object('pre_guess', r.pre_guess, 'play_count', r.play_count, 'finished_at', r.finished_at);
end $$;

-- ส่งผลหลังเล่น: เก็บผลล่าสุด นับจำนวนรอบที่เล่น
create or replace function public.cost_game_finish(p jsonb, p_year text default '2569')
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare v_uid uuid := auth.uid(); v_ev text[]; n int;
begin
  if v_uid is null then raise exception 'ต้องเข้าสู่ระบบก่อน'; end if;
  if public.get_my_role() is distinct from 'student' then raise exception 'หน้านี้สำหรับนักเรียน'; end if;
  if jsonb_typeof(p) is distinct from 'object' then raise exception 'ข้อมูลไม่ครบ'; end if;
  select coalesce(array_agg(e), '{}') into v_ev
    from (select jsonb_array_elements_text(coalesce(p->'events','[]'::jsonb)) e limit 6) x
   where e ~ '^[a-z0-9_]{1,30}$';
  update public.cost_game_plays set
    track = p->>'track', private_prog = p->>'private_prog', public_prog = p->>'public_prog',
    housing = p->>'housing',
    total_private = round((p->>'total_private')::numeric)::int,
    total_public  = round((p->>'total_public')::numeric)::int,
    events = v_ev, top_reason = nullif(p->>'top_reason',''),
    post_choice = p->>'post_choice', talk_home = p->>'talk_home',
    play_count = play_count + 1, finished_at = now(), updated_at = now(),
    class_room = coalesce(nullif(trim(public.get_my_room()),''), class_room)
  where student_id = v_uid and academic_year = p_year;
  get diagnostics n = row_count;
  if n = 0 then raise exception 'ยังไม่ได้โหวตก่อนเล่น เริ่มเกมใหม่อีกครั้งนะ'; end if;
  return jsonb_build_object('ok', true);
end $$;

-- สรุปรายห้องสำหรับครู (ห้อง ม.6 ทุกห้องแสดงแม้ยังไม่มีใครเล่น)
create or replace function public.cost_game_summary(p_year text default '2569')
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  if not public.iv_is_staff() then raise exception 'เฉพาะครูแนะแนวและแอดมิน'; end if;
  return coalesce((
    with rooms as (
      select class_room room, count(*)::int students from public.profiles
       where role = 'student' and coalesce(status,'active') = 'active' and class_room like 'ม.6/%'
       group by class_room
      union
      select distinct class_room, 0 from public.cost_game_plays where academic_year = p_year
       and class_room not in (select class_room from public.profiles where role='student' and class_room like 'ม.6/%' and class_room is not null)
    ), agg as (
      select class_room room,
        count(*)::int started,
        count(*) filter (where finished_at is not null)::int finished,
        count(*) filter (where pre_guess='private')::int pre_private,
        count(*) filter (where pre_guess='public')::int pre_public,
        count(*) filter (where pre_guess='same')::int pre_same,
        count(*) filter (where finished_at is not null and total_public < total_private)::int found_public_cheaper,
        count(*) filter (where finished_at is not null and total_public >= total_private)::int found_private_cheaper,
        count(*) filter (where post_choice='private')::int post_private,
        count(*) filter (where post_choice='public')::int post_public,
        count(*) filter (where post_choice='unsure')::int post_unsure,
        count(*) filter (where talk_home='yes')::int talk_yes,
        count(*) filter (where talk_home='maybe')::int talk_maybe,
        count(*) filter (where talk_home='no')::int talk_no,
        count(*) filter (where finished_at is not null and pre_guess='private' and total_public < total_private)::int surprised,
        round(avg(total_private - total_public) filter (where finished_at is not null))::int avg_diff
      from public.cost_game_plays where academic_year = p_year group by class_room
    )
    select jsonb_agg(jsonb_build_object('room', r.room, 'students', r.students) || coalesce(to_jsonb(a) - 'room', '{}'::jsonb)
             order by nullif(regexp_replace(r.room,'\D','','g'),'')::bigint nulls last, r.room)
    from rooms r left join agg a on a.room = r.room), '[]'::jsonb);
end $$;

-- รายชื่อในห้องเดียวสำหรับครู (ใครเล่นแล้ว/ยังไม่เล่น)
create or replace function public.cost_game_room(p_room text, p_year text default '2569')
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  if not public.iv_is_staff() then raise exception 'เฉพาะครูแนะแนวและแอดมิน'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'pid', pr.id, 'student_id', pr.student_id, 'name', pr.display_name,
      'pre_guess', g.pre_guess, 'finished', g.finished_at is not null, 'play_count', coalesce(g.play_count,0),
      'track', g.track, 'private_prog', g.private_prog, 'public_prog', g.public_prog, 'housing', g.housing,
      'total_private', g.total_private, 'total_public', g.total_public,
      'post_choice', g.post_choice, 'talk_home', g.talk_home, 'top_reason', g.top_reason)
      order by pr.student_id nulls last, pr.display_name)
    from public.profiles pr
    left join public.cost_game_plays g on g.student_id = pr.id and g.academic_year = p_year
    where pr.role = 'student' and (pr.class_room = p_room or g.class_room = p_room)), '[]'::jsonb);
end $$;

revoke all on function public.cost_game_start(text,text), public.cost_game_finish(jsonb,text),
  public.cost_game_summary(text), public.cost_game_room(text,text) from public, anon;
grant execute on function public.cost_game_start(text,text), public.cost_game_finish(jsonb,text),
  public.cost_game_summary(text), public.cost_game_room(text,text) to authenticated;

-- การ์ดในเมนูระบบ
insert into public.external_systems (title, description, url, icon, visible_to, sort_order, category, student_grades)
select 'ใกล้บ้าน vs ไกลบ้าน', 'เกมเทียบค่าใช้จ่ายเรียนมหาวิทยาลัย 4 ปี เอกชนใกล้บ้าน กับ รัฐที่ต้องอยู่หอ', 'https://timemachine68.github.io/treasury/cost-game.html', '💰', array['student'], 20, null, array['ม.6']
where not exists (select 1 from public.external_systems where url = 'https://timemachine68.github.io/treasury/cost-game.html');
insert into public.external_systems (title, description, url, icon, visible_to, sort_order, category, student_grades)
select 'ใกล้บ้าน vs ไกลบ้าน (หน้าครู)', 'ดูผลโหวตก่อน-หลังเล่นรายห้อง และเปิดโหมดสาธิตขึ้นจอ', 'https://timemachine68.github.io/treasury/cost-game-teacher.html', '💰', array['teacher'], 21, null, null
where not exists (select 1 from public.external_systems where url = 'https://timemachine68.github.io/treasury/cost-game-teacher.html');
