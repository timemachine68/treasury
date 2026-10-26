-- ยินยอมใช้รูป + จำกัดสิทธิ์อ่านรูปให้ครูแนะแนว/admin
alter table public.survey_responses
  add column if not exists photo_consent boolean not null default false,
  add column if not exists photo_consent_at timestamptz;

create or replace function public.survey_responses_consent_guard()
returns trigger language plpgsql set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    new.photo_consent_at := case when new.photo_consent then now() else null end;
  elsif new.photo_consent is distinct from old.photo_consent then
    new.photo_consent_at := case when new.photo_consent then now() else null end;
  else
    new.photo_consent_at := old.photo_consent_at;
  end if;
  return new;
end $$;
revoke all on function public.survey_responses_consent_guard() from public, anon;

drop trigger if exists survey_responses_consent_guard on public.survey_responses;
create trigger survey_responses_consent_guard before insert or update
  on public.survey_responses for each row
  execute function public.survey_responses_consent_guard();

-- อ่านรูป: เจ้าของโฟลเดอร์ หรือครูแนะแนว/admin เท่านั้น
drop policy if exists "read survey photos" on storage.objects;
create policy "read survey photos" on storage.objects for select to authenticated
  using (bucket_id = 'survey-photos' and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or (select public.iv_is_staff())
  ));

-- ถอนความยินยอม (เจ้าของคำตอบหรือครูแนะแนว/admin) แม้รอบปิดแล้ว
create or replace function public.survey_withdraw_photo_consent(p_response_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.survey_responses
     set photo_consent = false
   where id = p_response_id
     and (student_id = (select auth.uid()) or public.iv_is_staff());
  if not found then raise exception 'ไม่พบคำตอบ หรือไม่มีสิทธิ์'; end if;
end $$;
revoke all on function public.survey_withdraw_photo_consent(uuid) from public, anon;
grant execute on function public.survey_withdraw_photo_consent(uuid) to authenticated;
revoke execute on function public.survey_responses_consent_guard() from authenticated;
