-- รูปถ่ายนักเรียนของโรงเรียน (ชื่อไฟล์ = รหัสนักเรียน 5 หลัก) ใช้ในทำเนียบนักเรียน
-- รันแล้วบน Supabase โปรเจกต์ ikkhjslmtjwrxzxvtokb เมื่อ 2026-11-09 (migration: school_photos_for_roster)
alter table public.profiles add column if not exists school_photo_path text;

-- ครูแนะแนว/แอดมิน อัปโหลดเข้าโฟลเดอร์ school/ ได้ (อ่านได้อยู่แล้วตามนโยบาย "avatar read own or staff")
drop policy if exists "school photo staff insert" on storage.objects;
create policy "school photo staff insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'profile-photos' and (storage.foldername(name))[1] = 'school' and (select public.iv_is_staff()));

drop policy if exists "school photo staff update" on storage.objects;
create policy "school photo staff update" on storage.objects for update to authenticated
  using (bucket_id = 'profile-photos' and (storage.foldername(name))[1] = 'school' and (select public.iv_is_staff()))
  with check (bucket_id = 'profile-photos' and (storage.foldername(name))[1] = 'school' and (select public.iv_is_staff()));

-- profiles แก้ได้เฉพาะแอดมิน จึงใช้ฟังก์ชันที่เช็กสิทธิ์เอง
create or replace function public.set_school_photos(p_ids text[])
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare n integer;
begin
  if not public.iv_is_staff() then
    raise exception 'ไม่มีสิทธิ์ (เฉพาะแอดมินหรือครูแนะแนว)';
  end if;
  update public.profiles
     set school_photo_path = 'school/' || student_id || '.jpg'
   where role = 'student'
     and student_id = any(p_ids)
     and student_id ~ '^[0-9]{5}$';
  get diagnostics n = row_count;
  return n;
end;
$$;
revoke all on function public.set_school_photos(text[]) from public, anon;
grant execute on function public.set_school_photos(text[]) to authenticated;
