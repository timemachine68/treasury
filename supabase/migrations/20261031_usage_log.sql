-- สารสนเทศการใช้งานระบบ: เก็บว่าใครเปิดหน้าไหน วันไหน (1 แถว/คน/หน้า/วัน)
-- ไม่มี policy อ่าน/เขียนตรง — เขียนผ่าน usage_log() อ่านเป็นยอดรวมผ่าน usage_summary() เท่านั้น

create table if not exists public.app_usage_log (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  role        text not null,
  is_guidance boolean not null default false,
  class_level text,
  page        text not null check (page ~ '^[a-z0-9][a-z0-9:_-]{0,59}$'),
  visited_on  date not null default ((now() at time zone 'Asia/Bangkok')::date),
  first_at    timestamptz not null default now(),
  constraint app_usage_log_once_per_day unique (user_id, page, visited_on)
);
create index if not exists app_usage_log_visited_on_idx on public.app_usage_log (visited_on);

alter table public.app_usage_log enable row level security;
revoke all on public.app_usage_log from public, anon, authenticated;

-- บันทึกการเปิดหน้า (เรียกจากหน้าเว็บ) — ไม่ error ใส่ผู้ใช้ ถ้าค่าแปลกก็ข้ามเงียบ ๆ
create or replace function public.usage_log(p_page text)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_today date := (now() at time zone 'Asia/Bangkok')::date;
  v_role text; v_g boolean; v_room text; v_n int;
begin
  if v_uid is null or p_page is null or p_page !~ '^[a-z0-9][a-z0-9:_-]{0,59}$' then
    return;
  end if;
  select role, coalesce(is_guidance, false), class_room into v_role, v_g, v_room
  from public.profiles where id = v_uid;
  if v_role is null then return; end if;
  -- กันการยิงชื่อหน้าแปลก ๆ จำนวนมาก: ไม่เกิน 60 หน้า/คน/วัน
  select count(*) into v_n from public.app_usage_log where user_id = v_uid and visited_on = v_today;
  if v_n >= 60 then return; end if;
  insert into public.app_usage_log (user_id, role, is_guidance, class_level, page, visited_on)
  values (v_uid, v_role, v_g,
          case when v_role = 'student' then nullif(split_part(coalesce(v_room, ''), '/', 1), '') end,
          p_page, v_today)
  on conflict on constraint app_usage_log_once_per_day do nothing;
end;
$$;
revoke all on function public.usage_log(text) from public, anon;
grant execute on function public.usage_log(text) to authenticated;

-- สรุปยอดรวมให้แอดมิน/ครูแนะแนว (ไม่มีรายชื่อ)
create or replace function public.usage_summary(p_months int default 12)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_today date := (now() at time zone 'Asia/Bangkok')::date;
  v_from date;
begin
  if not public.iv_is_staff() then
    raise exception 'ไม่มีสิทธิ์ดูข้อมูลการใช้งาน' using errcode = '42501';
  end if;
  v_from := (date_trunc('month', v_today) - make_interval(months => greatest(least(coalesce(p_months, 12), 36), 1) - 1))::date;

  return jsonb_build_object(
    'today', v_today,
    'first_day', (select min(visited_on) from public.app_usage_log),
    'accounts', (select jsonb_build_object(
        'student', count(*) filter (where role = 'student'),
        'guidance', count(*) filter (where role = 'admin' or (role = 'teacher' and coalesce(is_guidance, false))),
        'teacher', count(*) filter (where role = 'teacher' and not coalesce(is_guidance, false)))
      from public.profiles),
    'monthly', (select coalesce(jsonb_agg(m order by m->>'month'), '[]'::jsonb) from (
        select jsonb_build_object(
          'month', to_char(date_trunc('month', visited_on), 'YYYY-MM'),
          'student', count(distinct user_id) filter (where role = 'student'),
          'guidance', count(distinct user_id) filter (where role = 'admin' or is_guidance),
          'teacher', count(distinct user_id) filter (where role = 'teacher' and not is_guidance),
          'user_days', count(distinct (user_id, visited_on))) m
        from public.app_usage_log where visited_on >= v_from
        group by date_trunc('month', visited_on)) x),
    'last30', (select jsonb_build_object(
        'student', count(distinct user_id) filter (where role = 'student'),
        'guidance', count(distinct user_id) filter (where role = 'admin' or is_guidance),
        'teacher', count(distinct user_id) filter (where role = 'teacher' and not is_guidance),
        'user_days', count(distinct (user_id, visited_on)))
      from public.app_usage_log where visited_on > v_today - 30),
    'levels30', (select coalesce(jsonb_agg(jsonb_build_object('level', lv, 'used', used, 'total', total) order by lv), '[]'::jsonb) from (
        select r.lv, coalesce(u.used, 0) used, r.total from
          (select split_part(class_room, '/', 1) lv, count(*) total from public.profiles
            where role = 'student' and class_room like 'ม.%' group by 1) r
          left join (select class_level lv, count(distinct user_id) used from public.app_usage_log
            where role = 'student' and visited_on > v_today - 30 group by 1) u on u.lv = r.lv) y),
    'pages30', (select coalesce(jsonb_agg(jsonb_build_object('page', page, 'users', users, 'student', st, 'staff', sf, 'days', d) order by users desc, page), '[]'::jsonb) from (
        select page, count(distinct user_id) users,
               count(distinct user_id) filter (where role = 'student') st,
               count(distinct user_id) filter (where role <> 'student') sf,
               count(*) d
        from public.app_usage_log where visited_on > v_today - 30
        group by page order by 2 desc, 1 limit 25) z)
  );
end;
$$;
revoke all on function public.usage_summary(int) from public, anon;
grant execute on function public.usage_summary(int) to authenticated;
