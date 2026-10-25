-- คืน policy ทุกตัวในสคีมา public กลับเป็นค่าก่อนรัน 20261025_rls_initplan_wrap_policies.sql
-- (อ่านจากตาราง public.policy_backup_20261025) รันได้ครั้งเดียวใน transaction เดียว
do $rb$
declare r record; stmt text;
begin
  for r in select * from public.policy_backup_20261025 order by tablename, policyname loop
    stmt := format('alter policy %I on public.%I', r.policyname, r.tablename);
    if r.qual is not null then stmt := stmt || ' using (' || r.qual || ')'; end if;
    if r.with_check is not null then stmt := stmt || ' with check (' || r.with_check || ')'; end if;
    execute stmt;
  end loop;
end $rb$;
