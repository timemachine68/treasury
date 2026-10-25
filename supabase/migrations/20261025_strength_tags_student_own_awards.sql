-- นักเรียนบันทึกเกียรติบัตร/รางวัลของตัวเองได้ (เฉพาะ type='award' ของตัวเอง)
-- ลบได้เฉพาะที่ตัวเองบันทึก (policy ลบเดิมครอบคลุมแล้ว: tagged_by = auth.uid())
create policy "student add own awards" on public.strength_tags
  for insert to authenticated
  with check (
    get_my_role() = 'student'
    and student_id = auth.uid()
    and tagged_by = auth.uid()
    and type = 'award'
    and note is not null
    and length(note) between 1 and 600
  );

create or replace function public.strength_tags_limit_student_awards()
returns trigger language plpgsql security invoker set search_path = public as $$
begin
  if new.tagged_by = new.student_id and new.type = 'award' then
    if (select count(*) from public.strength_tags where student_id = new.student_id and tagged_by = new.student_id and type = 'award') >= 50 then
      raise exception 'บันทึกรางวัลของตัวเองได้ไม่เกิน 50 รายการ';
    end if;
  end if;
  return new;
end $$;

drop trigger if exists strength_tags_limit_student_awards on public.strength_tags;
create trigger strength_tags_limit_student_awards before insert on public.strength_tags
  for each row execute function public.strength_tags_limit_student_awards();
