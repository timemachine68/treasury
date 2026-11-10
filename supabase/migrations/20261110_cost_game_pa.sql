-- เกมใกล้บ้าน vs ไกลบ้าน: เพิ่มแบบวัดก่อน-หลัง (ใช้เป็นหลักฐานผลงาน PA)
-- เก็บเฉพาะรหัสนักเรียนในระบบ ไม่เก็บชื่อในตารางนี้ ค่าก่อนเรียนเก็บครั้งแรกครั้งเดียว ค่าหลังเรียนเก็บของรอบแรกที่เล่นจบ
alter table public.cost_game_plays
  add column if not exists goal text check (goal in ('know_cost','compare','talk_parents','choose')),
  add column if not exists pre_score smallint check (pre_score between 0 and 5),
  add column if not exists post_score smallint check (post_score between 0 and 5),
  add column if not exists self_cost_pre smallint check (self_cost_pre between 1 and 4),
  add column if not exists self_talk_pre smallint check (self_talk_pre between 1 and 4),
  add column if not exists self_cost_post smallint check (self_cost_post between 1 and 4),
  add column if not exists self_talk_post smallint check (self_talk_post between 1 and 4),
  add column if not exists goal_met text check (goal_met in ('yes','some','no'));

drop function if exists public.cost_game_start(text,text);
create or replace function public.cost_game_start(p_guess text, p_year text default '2569', p_pre jsonb default null)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare v_uid uuid := auth.uid(); v_room text; r public.cost_game_plays;
  v_goal text; v_sc int; v_c int; v_t int;
begin
  if v_uid is null then raise exception 'ต้องเข้าสู่ระบบก่อน'; end if;
  if public.get_my_role() is distinct from 'student' then raise exception 'หน้านี้สำหรับนักเรียน'; end if;
  if p_guess not in ('private','public','same') then raise exception 'คำตอบไม่ถูกต้อง'; end if;
  if p_year !~ '^25[0-9]{2}$' then raise exception 'ปีการศึกษาไม่ถูกต้อง'; end if;
  v_room := public.get_my_room();
  if coalesce(trim(v_room),'') = '' then raise exception 'บัญชีนี้ยังไม่มีห้องเรียนในระบบ แจ้งครูก่อนนะ'; end if;
  if p_pre is not null and jsonb_typeof(p_pre) = 'object' then
    v_goal := nullif(p_pre->>'goal','');
    if v_goal is not null and v_goal not in ('know_cost','compare','talk_parents','choose') then raise exception 'เป้าหมายไม่ถูกต้อง'; end if;
    v_sc := nullif(p_pre->>'score','')::int; v_c := nullif(p_pre->>'self_cost','')::int; v_t := nullif(p_pre->>'self_talk','')::int;
    if v_sc not between 0 and 5 or v_c not between 1 and 4 or v_t not between 1 and 4 then raise exception 'คะแนนไม่ถูกต้อง'; end if;
  end if;
  insert into public.cost_game_plays (student_id, academic_year, class_room, pre_guess, goal, pre_score, self_cost_pre, self_talk_pre)
  values (v_uid, p_year, v_room, p_guess, v_goal, v_sc, v_c, v_t)
  on conflict (student_id, academic_year) do update set
    goal = coalesce(public.cost_game_plays.goal, excluded.goal),
    pre_score = coalesce(public.cost_game_plays.pre_score, excluded.pre_score),
    self_cost_pre = coalesce(public.cost_game_plays.self_cost_pre, excluded.self_cost_pre),
    self_talk_pre = coalesce(public.cost_game_plays.self_talk_pre, excluded.self_talk_pre);
  select * into r from public.cost_game_plays where student_id = v_uid and academic_year = p_year;
  return jsonb_build_object('pre_guess', r.pre_guess, 'play_count', r.play_count, 'finished_at', r.finished_at,
    'goal', r.goal, 'pre_score', r.pre_score, 'self_cost_pre', r.self_cost_pre, 'self_talk_pre', r.self_talk_pre);
end $$;

create or replace function public.cost_game_finish(p jsonb, p_year text default '2569')
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare v_uid uuid := auth.uid(); v_ev text[]; n int;
  v_ps int := nullif(p->>'post_score','')::int; v_c int := nullif(p->>'self_cost_post','')::int;
  v_t int := nullif(p->>'self_talk_post','')::int; v_gm text := nullif(p->>'goal_met','');
begin
  if v_uid is null then raise exception 'ต้องเข้าสู่ระบบก่อน'; end if;
  if public.get_my_role() is distinct from 'student' then raise exception 'หน้านี้สำหรับนักเรียน'; end if;
  if jsonb_typeof(p) is distinct from 'object' then raise exception 'ข้อมูลไม่ครบ'; end if;
  if v_ps not between 0 and 5 or v_c not between 1 and 4 or v_t not between 1 and 4 then raise exception 'คะแนนไม่ถูกต้อง'; end if;
  if v_gm is not null and v_gm not in ('yes','some','no') then raise exception 'คำตอบไม่ถูกต้อง'; end if;
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
    post_score = coalesce(post_score, v_ps), self_cost_post = coalesce(self_cost_post, v_c),
    self_talk_post = coalesce(self_talk_post, v_t), goal_met = coalesce(goal_met, v_gm),
    play_count = play_count + 1, finished_at = now(), updated_at = now(),
    class_room = coalesce(nullif(trim(public.get_my_room()),''), class_room)
  where student_id = v_uid and academic_year = p_year;
  get diagnostics n = row_count;
  if n = 0 then raise exception 'ยังไม่ได้โหวตก่อนเล่น เริ่มเกมใหม่อีกครั้งนะ'; end if;
  return jsonb_build_object('ok', true);
end $$;

-- สรุปรายห้อง: เพิ่มค่าเฉลี่ยก่อน-หลัง (นับเฉพาะคนที่มีทั้งคู่)
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
        round(avg(total_private - total_public) filter (where finished_at is not null))::int avg_diff,
        count(*) filter (where pre_score is not null and post_score is not null)::int paired,
        round((avg(pre_score) filter (where pre_score is not null and post_score is not null))::numeric,2) avg_pre,
        round((avg(post_score) filter (where pre_score is not null and post_score is not null))::numeric,2) avg_post,
        count(*) filter (where pre_score is not null and post_score is not null and post_score > pre_score)::int improved,
        count(*) filter (where pre_score is not null and post_score is not null and post_score = pre_score)::int same_score,
        count(*) filter (where pre_score is not null and post_score is not null and post_score < pre_score)::int dropped,
        round((avg(self_cost_pre) filter (where self_cost_post is not null and self_cost_pre is not null))::numeric,2) avg_cost_pre,
        round((avg(self_cost_post) filter (where self_cost_post is not null and self_cost_pre is not null))::numeric,2) avg_cost_post,
        round((avg(self_talk_pre) filter (where self_talk_post is not null and self_talk_pre is not null))::numeric,2) avg_talk_pre,
        round((avg(self_talk_post) filter (where self_talk_post is not null and self_talk_pre is not null))::numeric,2) avg_talk_post,
        count(*) filter (where goal_met='yes')::int goal_yes,
        count(*) filter (where goal_met='some')::int goal_some,
        count(*) filter (where goal_met='no')::int goal_no
      from public.cost_game_plays where academic_year = p_year group by class_room
    )
    select jsonb_agg(jsonb_build_object('room', r.room, 'students', r.students) || coalesce(to_jsonb(a) - 'room', '{}'::jsonb)
             order by nullif(regexp_replace(r.room,'\D','','g'),'')::bigint nulls last, r.room)
    from rooms r left join agg a on a.room = r.room), '[]'::jsonb);
end $$;

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
      'post_choice', g.post_choice, 'talk_home', g.talk_home, 'top_reason', g.top_reason,
      'goal', g.goal, 'pre_score', g.pre_score, 'post_score', g.post_score,
      'self_cost_pre', g.self_cost_pre, 'self_cost_post', g.self_cost_post,
      'self_talk_pre', g.self_talk_pre, 'self_talk_post', g.self_talk_post, 'goal_met', g.goal_met)
      order by pr.student_id nulls last, pr.display_name)
    from public.profiles pr
    left join public.cost_game_plays g on g.student_id = pr.id and g.academic_year = p_year
    where pr.role = 'student' and (pr.class_room = p_room or g.class_room = p_room)), '[]'::jsonb);
end $$;

revoke all on function public.cost_game_start(text,text,jsonb), public.cost_game_finish(jsonb,text),
  public.cost_game_summary(text), public.cost_game_room(text,text) from public, anon;
grant execute on function public.cost_game_start(text,text,jsonb), public.cost_game_finish(jsonb,text),
  public.cost_game_summary(text), public.cost_game_room(text,text) to authenticated;
