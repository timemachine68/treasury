-- หน้าโปรไฟล์ส่วนตัว: เพิ่มรูปโปรไฟล์ (avatar) ให้ profiles ทุก role (นักเรียน/ครู/admin)
-- ตั้งใจไม่เปิด policy ให้ "update ตาราง profiles ทั้งแถว" กับเจ้าของบัญชีเอง เพราะจะเปิดช่องให้
-- นักเรียนแก้ role/class_room/menu_permissions ของตัวเองได้ด้วย (privilege escalation)
-- จึงใช้ฟังก์ชัน security definer ที่แก้ได้เฉพาะคอลัมน์ avatar_path ของ auth.uid() ตัวเองเท่านั้น

alter table public.profiles add column if not exists avatar_path text;

create or replace function public.update_my_avatar(new_path text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles set avatar_path = new_path where id = auth.uid();
end;
$$;

revoke all on function public.update_my_avatar(text) from public;
grant execute on function public.update_my_avatar(text) to authenticated;

-- ═══ Storage: bucket เก็บรูปโปรไฟล์ (private) path = {uid}/{ไฟล์} ═══
-- limit 2MB เผื่อไว้เยอะกว่าไฟล์จริง (บีบอัดฝั่ง client เหลือ ~15-40KB/รูป) กันกรณี client ไม่ได้บีบอัดมา
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('profile-photos', 'profile-photos', false, 2097152, array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

create policy "avatar upload own folder" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'profile-photos' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "avatar update own folder" on storage.objects
  for update to authenticated
  using (bucket_id = 'profile-photos' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'profile-photos' and (storage.foldername(name))[1] = auth.uid()::text);

-- อ่านได้: เจ้าของรูปเอง หรือครู/admin (ต้องเห็นรูปนักเรียนได้ เช่น หน้ารายชื่อ)
create policy "avatar read own or staff" on storage.objects
  for select to authenticated
  using (bucket_id = 'profile-photos'
         and ((storage.foldername(name))[1] = auth.uid()::text or get_my_role() in ('teacher','admin')));

create policy "avatar delete own or admin" on storage.objects
  for delete to authenticated
  using (bucket_id = 'profile-photos'
         and ((storage.foldername(name))[1] = auth.uid()::text or get_my_role() = 'admin'));
