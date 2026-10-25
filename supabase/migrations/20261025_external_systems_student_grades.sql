-- จำกัดระดับชั้นที่นักเรียนเห็นการ์ด "ระบบของเรา" (null = ทุกระดับชั้น)
alter table public.external_systems add column if not exists student_grades text[];
alter table public.external_systems drop constraint if exists external_systems_student_grades_check;
alter table public.external_systems add constraint external_systems_student_grades_check
  check (student_grades is null or student_grades <@ array['ม.1','ม.2','ม.3','ม.4','ม.5','ม.6']);

drop policy if exists "see external systems" on public.external_systems;
create policy "see external systems" on public.external_systems for select to authenticated
using (
  get_my_role() = 'admin'
  or (
    get_my_role() = any (visible_to)
    and (
      get_my_role() <> 'student'
      or student_grades is null
      or split_part(get_my_room(), '/', 1) = any (student_grades)
    )
  )
);
