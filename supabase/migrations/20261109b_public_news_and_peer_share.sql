-- ข่าวประชาสัมพันธ์สาธารณะ (news.html) + ลิงก์ลับคลังสื่อสำหรับเพื่อนครู (share.html)
-- หลักการ: ไม่เปิดสิทธิ์ anon ให้ตารางใดเลย คนนอกอ่านได้ผ่านฟังก์ชันที่คืนเฉพาะคอลัมน์ที่ปลอดภัยเท่านั้น
-- ไฟล์แนบ: ออกลิงก์ผ่าน Edge Function `public-file` (ตรวจสิทธิ์ก่อนทุกครั้ง) bucket ยังเป็น private เหมือนเดิม

-- 1) ช่องติ๊ก (ค่าเริ่มต้น = ไม่เผยแพร่ ข้อมูลเดิมทั้งหมดยังเป็นส่วนตัว)
alter table public.announcements add column if not exists is_public boolean not null default false;
alter table public.resources     add column if not exists share_with_peers boolean not null default false;

-- 2) รหัสลิงก์ลับ (มีได้ลิงก์เดียว เปลี่ยนใหม่ = ลิงก์เก่าใช้ไม่ได้ทันที)
create table if not exists public.peer_share_links (
  id          smallint primary key default 1 check (id = 1),
  token       text not null check (char_length(token) >= 40),
  updated_at  timestamptz not null default now(),
  updated_by  uuid references public.profiles(id) on delete set null
);
alter table public.peer_share_links enable row level security;
drop policy if exists "staff read peer link" on public.peer_share_links;
create policy "staff read peer link" on public.peer_share_links
  for select to authenticated using ((select public.iv_is_staff()));
revoke all on public.peer_share_links from anon, authenticated;
grant select on public.peer_share_links to authenticated;

-- ครูแนะแนว/admin สร้างหรือเปลี่ยนลิงก์ใหม่
create or replace function public.peer_share_rotate()
returns text language plpgsql volatile security definer set search_path = public as $$
declare t text := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
begin
  if not public.iv_is_staff() then raise exception 'เฉพาะครูแนะแนวหรือผู้ดูแลระบบ'; end if;
  insert into public.peer_share_links (id, token, updated_at, updated_by)
  values (1, t, now(), auth.uid())
  on conflict (id) do update set token = excluded.token, updated_at = now(), updated_by = auth.uid();
  return t;
end $$;
revoke all on function public.peer_share_rotate() from public, anon;
grant execute on function public.peer_share_rotate() to authenticated;

-- ปิดลิงก์ (ไม่มีลิงก์ไหนใช้ได้จนกว่าจะสร้างใหม่)
create or replace function public.peer_share_disable()
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  if not public.iv_is_staff() then raise exception 'เฉพาะครูแนะแนวหรือผู้ดูแลระบบ'; end if;
  delete from public.peer_share_links where id = 1;
end $$;
revoke all on function public.peer_share_disable() from public, anon;
grant execute on function public.peer_share_disable() to authenticated;

-- 3) ข่าวสาธารณะ: เฉพาะที่ "เผยแพร่ทันที" และ "เผยแพร่สาธารณะ" ทั้งคู่ — ไม่คืนชื่อผู้โพสต์/ที่อยู่ไฟล์
create or replace function public.public_news()
returns table (id uuid, title text, content text, external_url text, file_name text, has_file boolean,
               is_pinned boolean, created_at timestamptz, updated_at timestamptz)
language sql stable security definer set search_path = public as $$
  select a.id, a.title, a.content, a.external_url, a.file_name, a.file_path is not null,
         (a.is_pinned and (a.pinned_until is null or a.pinned_until >= (now() at time zone 'Asia/Bangkok')::date)),
         a.created_at, a.updated_at
  from public.announcements a
  where a.is_active and a.is_public
  order by 7 desc, a.created_at desc
  limit 200
$$;
revoke all on function public.public_news() from public;
grant execute on function public.public_news() to anon, authenticated;

-- ปฏิทิน (ไม่มีข้อมูลนักเรียน) ย้อนหลัง 1 เดือน ถึงล่วงหน้า
create or replace function public.public_calendar()
returns table (id uuid, title text, category text, start_date date, end_date date, link_url text, note text)
language sql stable security definer set search_path = public as $$
  select c.id, c.title, c.category, c.start_date, c.end_date, c.link_url, c.note
  from public.calendar_events c
  where coalesce(c.end_date, c.start_date) >= ((now() at time zone 'Asia/Bangkok')::date - 31)
  order by c.start_date, c.id
  limit 500
$$;
revoke all on function public.public_calendar() from public;
grant execute on function public.public_calendar() to anon, authenticated;

-- 4) สื่อสำหรับเพื่อนครู: ต้องมีรหัสลิงก์ที่ถูกต้องเท่านั้น
create or replace function public.peer_shared_resources(p_token text)
returns table (id uuid, title text, description text, grade_level text, resource_type text,
               external_url text, extra_links jsonb, file_name text, has_file boolean, created_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  if p_token is null or char_length(p_token) < 40
     or not exists (select 1 from public.peer_share_links l where l.id = 1 and l.token = p_token) then
    raise exception 'invalid_link' using errcode = 'P0001';
  end if;
  return query
    select r.id, r.title, r.description, r.grade_level, r.resource_type, r.external_url,
           coalesce(r.extra_links, '[]'::jsonb), r.file_name, r.file_path is not null, r.created_at
    from public.resources r
    where r.share_with_peers
    order by r.created_at desc
    limit 500;
end $$;
revoke all on function public.peer_shared_resources(text) from public;
grant execute on function public.peer_shared_resources(text) to anon, authenticated;

-- ตามมา: ปิดสิทธิ์ anon ที่ค้างอยู่บนตาราง resources (มี RLS กันอยู่แล้ว แต่ปิดซ้ำให้ชัด)
revoke all on public.resources from anon;
