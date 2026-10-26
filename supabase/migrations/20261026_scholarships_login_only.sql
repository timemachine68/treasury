-- รายชื่อทุนและเกณฑ์ทุน: เห็นเฉพาะผู้ที่เข้าสู่ระบบ (เดิมคนนอกที่มี key หน้าเว็บอ่านได้)
-- 26 ต.ค. 2569 — ทุกหน้าที่อ่านตารางนี้ (scholarship-apply/results/admin, index, home) อ่านหลังเข้าสู่ระบบอยู่แล้ว

drop policy if exists "sch_public_read" on public.scholarships;
create policy "sch_public_read" on public.scholarships
  for select to authenticated
  using (status = any (array['open'::scholarship_status, 'announced'::scholarship_status]));

drop policy if exists "crit_public_read" on public.scholarship_criteria;
create policy "crit_public_read" on public.scholarship_criteria
  for select to authenticated
  using (exists (select 1 from public.scholarships s
                 where s.id = scholarship_criteria.scholarship_id
                   and s.status = any (array['open'::scholarship_status, 'announced'::scholarship_status])));

revoke all on public.scholarships from anon;
revoke all on public.scholarship_criteria from anon;
