-- คลังมหาวิทยาลัย: ครูกลุ่มสาระ (teacher ที่ไม่ใช่ครูแนะแนว) อ่านไม่ได้ — ครูสั่ง 16 พ.ย. 2569
-- อ่านได้: นักเรียน (เฉพาะแห่งที่แสดงอยู่) + ครูแนะแนว/แอดมิน (iv_is_staff)
drop policy if exists "uni_profiles read" on public.uni_profiles;
create policy "uni_profiles read" on public.uni_profiles for select to authenticated
  using ((select public.iv_is_staff())
         or (is_published and (select public.get_my_role()) = 'student'));

create or replace function public.uni_library_extras()
returns table (
  university_id uuid, admitted int, chosen int, faculties jsonb, quotas jsonb,
  has_mou boolean, iv_questions int, chang_phueak text, open_house jsonb
)
language sql stable security definer set search_path = public as $$
  with me as (
    select iv_is_staff() as staff, (select role from profiles where id = auth.uid()) as role
  ),
  u as (
    select v.* from iv_universities v
    join uni_profiles p on p.university_id = v.id
    cross join me
    where auth.uid() is not null
      and (me.staff or (me.role = 'student' and p.is_published))
  ),
  adm as (
    select a.university_id,
           count(distinct a.student_id) as n,
           count(distinct a.student_id) filter (where a.is_chosen) as c
    from survey_admissions a
    where a.kind = 'university' and a.university_id is not null
    group by 1
  ),
  fac as (
    select x.university_id,
           jsonb_agg(jsonb_build_object('faculty', x.faculty, 'n', case when x.n >= 3 then x.n end)
                     order by x.n desc, x.faculty) as j
    from (select a.university_id, coalesce(nullif(btrim(a.faculty), ''), 'ไม่ระบุคณะ') as faculty,
                 count(distinct a.student_id) as n
          from survey_admissions a
          where a.kind = 'university' and a.is_chosen and a.university_id is not null
          group by 1, 2) x
    group by 1
  )
  select u.id,
         case when coalesce(adm.n, 0) between 1 and 2 then null else coalesce(adm.n, 0)::int end,
         case when coalesce(adm.c, 0) between 1 and 2 then null else coalesce(adm.c, 0)::int end,
         case when coalesce(adm.c, 0) >= 3 then fac.j end,
         (select jsonb_agg(jsonb_build_object('faculty', q.faculty, 'seats', q.seats, 'type', q.quota_type,
                                              'year', q.academic_year, 'status', q.status, 'closes_at', q.closes_at)
                           order by q.academic_year desc, q.faculty)
            from quotas q
           where q.status <> 'draft' and uni_lib_match(u.name, u.short_name, u.aliases, q.university)),
         exists (select 1 from mou_institutions m where uni_lib_match(u.name, u.short_name, u.aliases, m.name)),
         (select count(*)::int from iv_questions iq where iq.university_id = u.id),
         case when u.name = 'มหาวิทยาลัยบูรพา' and exists (select 1 from chang_phueak_programs) then
              case when exists (select 1 from chang_phueak_programs where is_open) then 'open' else 'closed' end end,
         (select jsonb_agg(jsonb_build_object('date', e.event_date, 'code', e.event_code, 'open', e.is_open) order by e.event_date)
            from open_house_events e
           where e.event_date >= current_date and uni_lib_match(u.name, u.short_name, u.aliases, e.university))
  from u
  left join adm on adm.university_id = u.id
  left join fac on fac.university_id = u.id
$$;

revoke all on function public.uni_library_extras() from public, anon;
grant execute on function public.uni_library_extras() to authenticated;
