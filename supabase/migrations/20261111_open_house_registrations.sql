-- ลงทะเบียนงาน Open House มหาวิทยาลัยเซาธ์อีสต์บางกอก (19 พ.ย. 2569)
create table public.open_house_registrations (
  id uuid primary key default gen_random_uuid(),
  event_code text not null default 'sbu-openhouse-2569-11-19',
  profile_id uuid not null references public.profiles(id) on delete cascade,
  interest text not null check (interest in ('yes','maybe','no')),
  go_with_school boolean not null default false,
  faculties text[] not null default '{}' check (cardinality(faculties) <= 20),
  note text check (note is null or char_length(note) <= 500),
  student_id_snapshot text,
  name_snapshot text,
  class_snapshot text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (event_code, profile_id)
);

alter table public.open_house_registrations enable row level security;

-- ฟังก์ชันตรวจสิทธิ์ครูแนะแนว/แอดมิน (SECURITY DEFINER จึงปิดสิทธิ์จาก PUBLIC/anon)
create or replace function public.is_guidance_staff()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and (p.is_guidance or p.role = 'admin')
  );
$$;
revoke all on function public.is_guidance_staff() from public, anon;
grant execute on function public.is_guidance_staff() to authenticated;

create policy "student_own_select" on public.open_house_registrations
  for select to authenticated using (profile_id = auth.uid());
create policy "student_own_insert" on public.open_house_registrations
  for insert to authenticated with check (profile_id = auth.uid());
create policy "student_own_update" on public.open_house_registrations
  for update to authenticated using (profile_id = auth.uid()) with check (profile_id = auth.uid());
create policy "staff_select" on public.open_house_registrations
  for select to authenticated using (public.is_guidance_staff());

revoke all on public.open_house_registrations from anon;
grant select, insert, update on public.open_house_registrations to authenticated;
