-- แบบวัดก่อน-หลัง: ครูเปิด/ปิดรอบได้เอง + ล็อกที่ฐานข้อมูล (นักเรียนส่งได้เฉพาะรอบที่เปิด)
create table if not exists public.tarot_prepost_config (
  id smallint primary key default 1 check (id = 1),
  round_label text not null,
  instrument_version text not null default 'v0-draft',
  pre_open boolean not null default false,
  post_open boolean not null default false,
  updated_by uuid references public.profiles(id),
  updated_at timestamptz not null default now()
);
alter table public.tarot_prepost_config enable row level security;
create policy "see prepost config" on public.tarot_prepost_config for select to authenticated using (true);
create policy "staff insert prepost config" on public.tarot_prepost_config for insert to authenticated
  with check (get_my_role() in ('teacher','admin') and updated_by = auth.uid());
create policy "staff update prepost config" on public.tarot_prepost_config for update to authenticated
  using (get_my_role() in ('teacher','admin')) with check (updated_by = auth.uid());

alter table public.tarot_prepost add column if not exists instrument_version text not null default 'v0-draft';
alter table public.tarot_prepost add constraint tarot_prepost_items_array check (jsonb_typeof(items) = 'array');
alter table public.tarot_prepost add constraint tarot_prepost_total_range check (total >= 0);

drop policy if exists "student insert prepost" on public.tarot_prepost;
create policy "student insert prepost" on public.tarot_prepost for insert to authenticated
  with check (student_id = auth.uid()
    and exists (select 1 from public.tarot_consents c where c.student_id = auth.uid() and c.consented)
    and exists (select 1 from public.tarot_prepost_config g
                where g.round_label = tarot_prepost.round_label
                  and g.instrument_version = tarot_prepost.instrument_version
                  and ((tarot_prepost.phase = 'pre' and g.pre_open) or (tarot_prepost.phase = 'post' and g.post_open))));
create policy "staff delete prepost" on public.tarot_prepost for delete to authenticated
  using (get_my_role() in ('teacher','admin'));

revoke all on public.tarot_prepost_config from anon;
