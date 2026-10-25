-- อีเมลแจ้งนักเรียนเมื่อครูกด "เอกสารเสร็จแล้ว" (สถานะ ready) — ส่งผ่าน Google Apps Script เดียวกับอีเมลแจ้งครู
alter table public.work_permit_notify_config
  add column if not exists student_mail_secret text not null default gen_random_uuid()::text;

create or replace function public.notify_work_permit_ready()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, net
as $$
declare
  cfg record;
  stu record;
begin
  if coalesce(new.contact_email, '') = '' then
    return new;  -- คำขอเก่าไม่มีอีเมลนักเรียน
  end if;

  select * into cfg from public.work_permit_notify_config where id = 1;
  if cfg is null or not cfg.enabled or coalesce(cfg.webhook_url, '') = '' then
    return new;
  end if;

  select display_name into stu from public.profiles where id = new.student_id;

  begin
    perform net.http_post(
      url := cfg.webhook_url,
      body := jsonb_build_object(
        'action', 'student_ready',
        'secret', cfg.student_mail_secret,
        'to', new.contact_email,
        'student_name', coalesce(stu.display_name, ''),
        'request_type', new.request_type::text,
        'employer_name', new.employer_name
      ),
      headers := '{"Content-Type":"application/json"}'::jsonb,
      timeout_milliseconds := 5000
    );
  exception when others then
    raise warning 'work_permit ready notify failed: %', sqlerrm;
  end;

  return new;
end;
$$;

revoke execute on function public.notify_work_permit_ready() from public, anon, authenticated;

drop trigger if exists work_permit_requests_notify_ready on public.work_permit_requests;
create trigger work_permit_requests_notify_ready
after update of status on public.work_permit_requests
for each row
when (new.status = 'ready' and old.status is distinct from 'ready')
execute function public.notify_work_permit_ready();
