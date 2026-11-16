-- คลังมหาวิทยาลัย (uni-library.html) — 16 พ.ย. 2569
-- 1) เพิ่ม PIM เข้ารายชื่อกลาง iv_universities
-- 2) ตาราง uni_profiles: ข้อมูลรายแห่งที่ครูแนะแนวแก้ได้ (ค่าเทอม/หอ อ่านจาก cost-game-data.js ผ่าน game_key)
-- 3) RPC uni_library_extras(): สรุปตัวเลขรุ่นพี่/โควตา/MOU/คำถามสัมภาษณ์/Open House
--    คืนเฉพาะจำนวนรวม จำนวน 1–2 คนคืนเป็น null (หน้าเว็บแสดง "น้อยกว่า 3 คน") ไม่คืนชื่อนักเรียน
-- 4) การ์ดเมนู "คลังมหาวิทยาลัย"

-- ---------- 1) PIM ----------
insert into public.iv_universities (name, short_name, aliases, sort_order, is_active, campuses)
select 'สถาบันการจัดการปัญญาภิวัฒน์', 'PIM',
       array['ปัญญาภิวัฒน์','สถาบันปัญญาภิวัฒน์','พีไอเอ็ม','PIM','Panyapiwat'], 58, true, array[]::text[]
where not exists (select 1 from public.iv_universities where name = 'สถาบันการจัดการปัญญาภิวัฒน์');

-- ---------- 2) uni_profiles ----------
create table if not exists public.uni_profiles (
  id             uuid primary key default gen_random_uuid(),
  university_id  uuid not null unique references public.iv_universities(id) on delete cascade,
  game_key       text unique check (game_key ~ '^[a-z]{2,12}$'),
  uni_type       text not null check (uni_type in ('public','rajabhat','rajamangala','private','special')),
  province       text check (char_length(province) <= 80),
  campus_label   text check (char_length(campus_label) <= 120),
  zone           text check (zone in ('near','mid','far')),
  highlights     text check (char_length(highlights) <= 400),
  website_url    text check (website_url ~* '^https?://' and char_length(website_url) <= 300),
  admission_url  text check (admission_url ~* '^https?://' and char_length(admission_url) <= 300),
  has_dorm       boolean,
  source_note    text check (char_length(source_note) <= 300),
  is_published   boolean not null default true,
  updated_by     uuid default auth.uid(),
  updated_at     timestamptz not null default now(),
  created_at     timestamptz not null default now()
);

alter table public.uni_profiles enable row level security;

drop policy if exists "uni_profiles read" on public.uni_profiles;
create policy "uni_profiles read" on public.uni_profiles for select to authenticated
  using (is_published or (select public.iv_is_staff()));
drop policy if exists "uni_profiles staff insert" on public.uni_profiles;
create policy "uni_profiles staff insert" on public.uni_profiles for insert to authenticated
  with check ((select public.iv_is_staff()));
drop policy if exists "uni_profiles staff update" on public.uni_profiles;
create policy "uni_profiles staff update" on public.uni_profiles for update to authenticated
  using ((select public.iv_is_staff())) with check ((select public.iv_is_staff()));
drop policy if exists "uni_profiles staff delete" on public.uni_profiles;
create policy "uni_profiles staff delete" on public.uni_profiles for delete to authenticated
  using ((select public.iv_is_staff()));

revoke all on public.uni_profiles from anon;
revoke truncate, references, trigger on public.uni_profiles from authenticated;

create or replace function public.uni_profiles_touch()
returns trigger language plpgsql set search_path = public as $$
begin
  new.updated_at := now();
  new.updated_by := auth.uid();
  if tg_op = 'UPDATE' then new.created_at := old.created_at; end if;
  return new;
end $$;
revoke all on function public.uni_profiles_touch() from public, anon;

drop trigger if exists uni_profiles_touch on public.uni_profiles;
create trigger uni_profiles_touch before insert or update on public.uni_profiles
  for each row execute function public.uni_profiles_touch();

-- ข้อมูลเริ่มต้น 15 แห่งที่มีค่าเทอมในเกม (ประเภท/ระยะ/จังหวัด ตาม cost-game-data.js)
insert into public.uni_profiles (university_id, game_key, uni_type, province, campus_label, zone, website_url, admission_url, has_dorm)
select u.id, s.k, s.t, s.prov, s.campus, s.z, s.web, s.adm, s.dorm
from (values
  ('ม.หัวเฉียว',   'hcu',   'private',     'สมุทรปราการ', 'บางพลี',             'near', 'https://www.hcu.ac.th',  'https://admission.hcu.ac.th', null::boolean),
  ('มทร.กรุงเทพ',  'rmutk', 'rajamangala', 'กรุงเทพฯ',    'สาทร',               'near', 'https://www.rmutk.ac.th','https://admission.rmutk.ac.th', null),
  ('สจล.',         'kmitl', 'public',      'กรุงเทพฯ',    'ลาดกระบัง',          'near', 'https://www.kmitl.ac.th', null, null),
  ('มก.',          'ku',    'public',      'ชลบุรี',       'วิทยาเขตศรีราชา',     'mid',  'https://www.src.ku.ac.th','https://admissions.src.ku.ac.th', null),
  ('ม.บูรพา',      'buu',   'public',      'ชลบุรี',       'บางแสน',             'mid',  'https://www.buu.ac.th',  null, true),
  ('ม.พะเยา',      'up',    'public',      'พะเยา',        null,                 'far',  'https://www.up.ac.th',   'https://admission.up.ac.th', true),
  ('มฟล.',         'mfu',   'public',      'เชียงราย',     null,                 'far',  'https://www.mfu.ac.th',  null, true),
  ('ม.เชียงใหม่',  'cmu',   'public',      'เชียงใหม่',    null,                 'far',  'https://www.cmu.ac.th',  'https://admission.reg.cmu.ac.th', null),
  ('ม.นเรศวร',     'nu',    'public',      'พิษณุโลก',     null,                 'far',  'https://www.nu.ac.th',   'https://www.admission.nu.ac.th', null),
  ('ม.อ.',         'psuh',  'public',      'สงขลา',        'วิทยาเขตหาดใหญ่',     'far',  'https://www.psu.ac.th',  null, true),
  ('ม.ขอนแก่น',    'kku',   'public',      'ขอนแก่น',      null,                 'far',  'https://www.kku.ac.th',  'https://apps.admissions.kku.ac.th', null),
  ('ม.มหาสารคาม',  'msu',   'public',      'มหาสารคาม',    null,                 'far',  'https://www.msu.ac.th',  'https://admission.msu.ac.th', null),
  ('มรภ.ธนบุรี',   'dru',   'rajabhat',    'สมุทรปราการ', 'ศูนย์สมุทรปราการ',     'near', 'https://sp.dru.ac.th',   null, null),
  ('ม.ศิลปากร',    'su',    'public',      'นครปฐม / กรุงเทพฯ', null,             'mid',  'https://www.su.ac.th',   'https://admission.su.ac.th', true),
  ('PIM',          'pim',   'private',     null,           null,                 'near', 'https://www.pim.ac.th',  null, null)
) as s(short, k, t, prov, campus, z, web, adm, dorm)
join public.iv_universities u on u.short_name = s.short
on conflict (university_id) do nothing;

-- ---------- 3) RPC สรุปตัวเลข ----------
create or replace function public.uni_lib_match(p_name text, p_short text, p_aliases text[], p_txt text)
returns boolean language sql immutable set search_path = public as $$
  select p_txt is not null and (
       norm_th(p_txt) in (norm_th(p_name), norm_th(p_short))
    or position(norm_th(p_name) in norm_th(p_txt)) > 0
    or exists (select 1 from unnest(coalesce(p_aliases, '{}')) a
               where norm_th(a) = norm_th(p_txt)
                  or (char_length(norm_th(a)) >= 12 and position(norm_th(a) in norm_th(p_txt)) > 0)))
$$;

create or replace function public.uni_library_extras()
returns table (
  university_id   uuid,
  admitted        int,      -- คนที่ติด (นับคน) — null = 1–2 คน
  chosen          int,      -- คนที่เลือกเรียนที่นี่ — null = 1–2 คน
  faculties       jsonb,    -- [{faculty, n}] ของคนที่เลือกเรียน (มีเฉพาะเมื่อ chosen >= 3, n null = 1–2 คน)
  quotas          jsonb,    -- โควตาโรงเรียน (ไม่รวม draft)
  has_mou         boolean,
  iv_questions    int,
  chang_phueak    text,     -- 'open' | 'closed' | null
  open_house      jsonb     -- งาน Open House ที่ยังไม่ถึงวัน
)
language sql stable security definer set search_path = public as $$
  with u as (
    select v.* from iv_universities v
    join uni_profiles p on p.university_id = v.id
    where auth.uid() is not null and (p.is_published or iv_is_staff())
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

-- ---------- 4) การ์ดเมนู ----------
insert into public.external_systems (id, title, icon, url, visible_to, category, sort_order)
values ('5a7e0c11-9a2b-4c3d-8e4f-2026111600b1', 'คลังมหาวิทยาลัย', '🏛', 'https://timemachine68.github.io/treasury/uni-library.html',
        array['student','teacher'], 'TCAS', 1)
on conflict (id) do nothing;
update public.profiles
   set menu_permissions = jsonb_set(menu_permissions, '{appsOnly}', (menu_permissions->'appsOnly') || '"5a7e0c11-9a2b-4c3d-8e4f-2026111600b1"'::jsonb)
 where is_guidance and jsonb_typeof(menu_permissions->'appsOnly') = 'array'
   and not (menu_permissions->'appsOnly') ? '5a7e0c11-9a2b-4c3d-8e4f-2026111600b1';
