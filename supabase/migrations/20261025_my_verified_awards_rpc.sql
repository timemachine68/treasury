-- นักเรียนดูผลงานของตัวเองที่ยืนยันแล้วใน TCASVerified (เฉพาะแถวของ auth.uid())
create or replace function public.my_verified_awards()
returns table(participant_id uuid, tcas_type text, title text, level text, academic_year smallint, prize_name text, exp_name text, organizer text)
language sql stable security definer set search_path = public as $$
  select p.id, e.tcas_type::text, e.title, e.level::text, e.academic_year, p.prize_name, p.exp_name, e.organizer
  from public.award_participants p
  join public.award_events e on e.id = p.event_id
  where p.profile_id = auth.uid() and e.status = 'verified'
  order by e.academic_year desc, e.created_at desc
$$;
revoke all on function public.my_verified_awards() from public, anon;
grant execute on function public.my_verified_awards() to authenticated;
