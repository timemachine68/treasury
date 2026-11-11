-- รายการงาน Open House (ครูเพิ่มได้เอง) + เลือกได้เฉพาะ ไป / ไม่ไป
create table public.open_house_events (
  event_code text primary key check (char_length(event_code) between 3 and 60),
  university text not null check (char_length(university) between 1 and 200),
  event_date date not null,
  is_open boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.open_house_events enable row level security;

create policy "events_select_authenticated" on public.open_house_events
  for select to authenticated using (true);
create policy "events_staff_write" on public.open_house_events
  for all to authenticated
  using (public.is_guidance_staff()) with check (public.is_guidance_staff());

revoke all on public.open_house_events from anon;
grant select on public.open_house_events to authenticated;
grant insert, update, delete on public.open_house_events to authenticated;

insert into public.open_house_events (event_code, university, event_date) values
  ('sbu-openhouse-2569-11-19', 'มหาวิทยาลัยเซาธ์อีสต์บางกอก', '2026-11-19'),
  ('kasem-bundit-2569-11-20', 'มหาวิทยาลัยเกษมบัณฑิต', '2026-11-20');

alter table public.open_house_registrations
  add constraint open_house_registrations_event_fk
  foreign key (event_code) references public.open_house_events(event_code);
alter table public.open_house_registrations
  drop constraint open_house_registrations_interest_check;
alter table public.open_house_registrations
  add constraint open_house_registrations_interest_check check (interest in ('yes','no'));
alter table public.open_house_registrations alter column event_code drop default;
