-- บัญชีกองกลางงานแนะแนว (ledger_*) — สำเนา migration ที่ใช้จริง 25 ต.ค. 2569
-- (ledger_01 + ledger_02_fix_fiscal_year_search_path + ledger_03_entries_update_own_only)
-- เห็นและบันทึกได้เฉพาะ admin + ครูแนะแนว (iv_is_staff()) / ไม่มี policy ลบ ให้ยกเลิกรายการแทน

create or replace function public.ledger_fiscal_year(d date)
returns integer language sql immutable
as $$
  select extract(year from d)::int + 543 + case when extract(month from d) >= 10 then 1 else 0 end;
$$;
alter function public.ledger_fiscal_year(date) set search_path = '';

create table public.ledger_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 1 and 60),
  kind text not null check (kind in ('in','out')),
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz,
  updated_by uuid references public.profiles(id) on delete set null,
  unique (kind, name)
);

create table public.ledger_entries (
  id uuid primary key default gen_random_uuid(),
  entry_date date not null check (entry_date >= date '2020-01-01'),
  kind text not null check (kind in ('in','out')),
  amount numeric(12,2) not null check (amount > 0),
  category_id uuid not null references public.ledger_categories(id) on delete restrict,
  description text not null check (char_length(btrim(description)) between 1 and 200),
  note text check (note is null or char_length(note) <= 500),
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_by uuid references public.profiles(id) on delete set null,
  updated_at timestamptz,
  voided_at timestamptz,
  voided_by uuid references public.profiles(id) on delete set null,
  void_reason text check (void_reason is null or char_length(btrim(void_reason)) between 1 and 200),
  check ((voided_at is null and void_reason is null) or (voided_at is not null and void_reason is not null))
);
create index ledger_entries_date_idx on public.ledger_entries (entry_date);
create index ledger_entries_category_idx on public.ledger_entries (category_id);

create table public.ledger_settings (
  fiscal_year integer primary key check (fiscal_year between 2560 and 2700),
  opening_balance numeric(12,2) not null default 0 check (opening_balance >= 0),
  updated_at timestamptz,
  updated_by uuid references public.profiles(id) on delete set null
);

create or replace function public.ledger_touch()
returns trigger language plpgsql set search_path = public as $$
begin
  new.updated_at := now();
  new.updated_by := auth.uid();
  return new;
end $$;

create trigger ledger_settings_touch before insert or update on public.ledger_settings
  for each row execute function public.ledger_touch();

create or replace function public.ledger_categories_guard()
returns trigger language plpgsql set search_path = public as $$
begin
  if tg_op = 'UPDATE' then
    if new.kind is distinct from old.kind
       and exists (select 1 from public.ledger_entries e where e.category_id = old.id) then
      raise exception 'หมวดนี้มีรายการแล้ว เปลี่ยนประเภท รับ/จ่าย ไม่ได้ ให้ปิดใช้หมวดนี้แล้วสร้างหมวดใหม่';
    end if;
    new.updated_at := now();
    new.updated_by := auth.uid();
  end if;
  new.name := btrim(new.name);
  return new;
end $$;

create trigger ledger_categories_guard_trg before insert or update on public.ledger_categories
  for each row execute function public.ledger_categories_guard();

create or replace function public.ledger_entries_guard()
returns trigger language plpgsql set search_path = public as $$
declare
  v_kind text;
  v_active boolean;
begin
  if tg_op = 'INSERT' then
    new.created_by := auth.uid();
    new.created_at := now();
    new.updated_by := null;
    new.updated_at := null;
    new.voided_at := null;
    new.voided_by := null;
    new.void_reason := null;
    new.description := btrim(new.description);
  else
    if old.voided_at is not null then
      raise exception 'รายการนี้ยกเลิกแล้ว แก้ไขไม่ได้';
    end if;
    new.created_by := old.created_by;
    new.created_at := old.created_at;
    new.description := btrim(new.description);
    if new.void_reason is not null then
      if (new.entry_date, new.kind, new.amount, new.category_id, new.description, new.note)
         is distinct from (old.entry_date, old.kind, old.amount, old.category_id, old.description, old.note) then
        raise exception 'ตอนยกเลิกรายการ แก้ข้อมูลช่องอื่นพร้อมกันไม่ได้';
      end if;
      new.voided_at := now();
      new.voided_by := auth.uid();
      new.updated_by := old.updated_by;
      new.updated_at := old.updated_at;
      return new;
    end if;
    new.voided_at := null;
    new.voided_by := null;
    new.void_reason := null;
    new.updated_by := auth.uid();
    new.updated_at := now();
  end if;

  select c.kind, c.is_active into v_kind, v_active
    from public.ledger_categories c where c.id = new.category_id;
  if v_kind is null or v_kind <> new.kind then
    raise exception 'หมวดหมู่ไม่ตรงกับประเภทรายการ (รับ/จ่าย)';
  end if;
  if (tg_op = 'INSERT' or new.category_id is distinct from old.category_id) and not v_active then
    raise exception 'หมวดหมู่นี้ปิดใช้งานแล้ว เลือกหมวดอื่น';
  end if;
  if (tg_op = 'INSERT' or new.entry_date is distinct from old.entry_date)
     and new.entry_date > (now() at time zone 'Asia/Bangkok')::date then
    raise exception 'วันที่ต้องไม่เกินวันนี้';
  end if;
  return new;
end $$;

create trigger ledger_entries_guard_trg before insert or update on public.ledger_entries
  for each row execute function public.ledger_entries_guard();

alter table public.ledger_categories enable row level security;
alter table public.ledger_entries enable row level security;
alter table public.ledger_settings enable row level security;

create policy ledger_categories_select on public.ledger_categories for select to authenticated using (public.iv_is_staff());
create policy ledger_categories_insert on public.ledger_categories for insert to authenticated with check (public.iv_is_staff());
create policy ledger_categories_update on public.ledger_categories for update to authenticated using (public.iv_is_staff()) with check (public.iv_is_staff());

create policy ledger_entries_select on public.ledger_entries for select to authenticated using (public.iv_is_staff());
create policy ledger_entries_insert on public.ledger_entries for insert to authenticated with check (public.iv_is_staff());
-- แก้/ยกเลิกได้เฉพาะผู้บันทึกเอง (admin ทำได้ทุกรายการ) — ledger_03_entries_update_own_only
create policy ledger_entries_update on public.ledger_entries for update to authenticated
  using (public.iv_is_staff() and (created_by = auth.uid() or public.get_my_role() = 'admin'))
  with check (public.iv_is_staff() and (created_by = auth.uid() or public.get_my_role() = 'admin'));

create policy ledger_settings_select on public.ledger_settings for select to authenticated using (public.iv_is_staff());
create policy ledger_settings_insert on public.ledger_settings for insert to authenticated with check (public.iv_is_staff());
create policy ledger_settings_update on public.ledger_settings for update to authenticated using (public.iv_is_staff()) with check (public.iv_is_staff());

revoke all on public.ledger_categories, public.ledger_entries, public.ledger_settings from public, anon;
revoke delete, truncate on public.ledger_categories, public.ledger_entries, public.ledger_settings from authenticated;
grant select, insert, update on public.ledger_categories, public.ledger_entries, public.ledger_settings to authenticated;

create view public.ledger_monthly_summary with (security_invoker = true) as
select public.ledger_fiscal_year(e.entry_date) as fiscal_year,
       date_trunc('month', e.entry_date)::date as month_start,
       e.kind,
       sum(e.amount) as total,
       count(*)::int as entry_count
from public.ledger_entries e
where e.voided_at is null
group by 1, 2, 3;

create view public.ledger_category_summary with (security_invoker = true) as
select public.ledger_fiscal_year(e.entry_date) as fiscal_year,
       e.kind,
       c.id as category_id,
       c.name as category_name,
       sum(e.amount) as total,
       count(*)::int as entry_count
from public.ledger_entries e
join public.ledger_categories c on c.id = e.category_id
where e.voided_at is null
group by 1, 2, 3, 4;

revoke all on public.ledger_monthly_summary, public.ledger_category_summary from public, anon;
grant select on public.ledger_monthly_summary, public.ledger_category_summary to authenticated;

create or replace function public.ledger_year_summary(p_year integer)
returns table (
  fiscal_year integer, opening_balance numeric, opening_source text,
  total_in numeric, total_out numeric, in_count integer, out_count integer, balance numeric
)
language plpgsql stable set search_path = public as $$
declare
  v_base integer;
  y integer;
  v_open numeric;
  v_src text;
  v_prev_close numeric := null;
  v_in numeric;
  v_out numeric;
  v_ic integer;
  v_oc integer;
  v_set numeric;
begin
  if not public.iv_is_staff() then
    raise exception 'ไม่มีสิทธิ์ดูบัญชีกองกลาง' using errcode = '42501';
  end if;
  if p_year is null or p_year < 2560 or p_year > 2700 then
    raise exception 'ปีงบประมาณไม่ถูกต้อง';
  end if;
  select min(t.fy) into v_base from (
    select s.fiscal_year as fy from public.ledger_settings s
    union all
    select public.ledger_fiscal_year(min(e.entry_date)) from public.ledger_entries e where e.voided_at is null
  ) t;
  if v_base is null or v_base > p_year then v_base := p_year; end if;
  y := v_base;
  loop
    select s.opening_balance into v_set from public.ledger_settings s where s.fiscal_year = y;
    if found then
      v_open := v_set; v_src := 'manual';
    elsif v_prev_close is not null then
      v_open := v_prev_close; v_src := 'carried';
    else
      v_open := 0; v_src := 'none';
    end if;
    select coalesce(sum(e.amount) filter (where e.kind = 'in'), 0),
           coalesce(sum(e.amount) filter (where e.kind = 'out'), 0),
           (count(*) filter (where e.kind = 'in'))::int,
           (count(*) filter (where e.kind = 'out'))::int
      into v_in, v_out, v_ic, v_oc
      from public.ledger_entries e
     where e.voided_at is null
       and e.entry_date >= make_date(y - 544, 10, 1)
       and e.entry_date <  make_date(y - 543, 10, 1);
    v_prev_close := v_open + v_in - v_out;
    exit when y >= p_year;
    y := y + 1;
  end loop;
  return query select p_year, v_open, v_src, v_in, v_out, v_ic, v_oc, v_prev_close;
end $$;

revoke all on function public.ledger_year_summary(integer) from public, anon;
grant execute on function public.ledger_year_summary(integer) to authenticated;

insert into public.ledger_categories (name, kind, sort_order) values
  ('เงินสนับสนุนจากโรงเรียน', 'in', 1),
  ('เงินบริจาค', 'in', 2),
  ('อื่นๆ', 'in', 99),
  ('ค่าวัสดุอุปกรณ์', 'out', 1),
  ('อาหารและเครื่องดื่ม', 'out', 2),
  ('ค่าเดินทาง', 'out', 3),
  ('เอกสารและถ่ายเอกสาร', 'out', 4),
  ('อื่นๆ', 'out', 99);

-- การ์ดเมนู "ระบบของเรา" + เพิ่ม id การ์ดใน menu_permissions.appsOnly ของครูแนะแนวทุกคน
-- (ทำผ่าน execute_sql แล้ว ไม่ต้องรันซ้ำ: external_systems id = a98b67f2-7e00-4cf2-99a7-e84721ccd5aa)
