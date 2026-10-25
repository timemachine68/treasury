alter table public.work_permit_requests
  add column if not exists contact_phone text,
  add column if not exists contact_email text;

-- คำขอเก่าไม่มีข้อมูลนี้ จึงให้เป็นค่าว่างได้ (ฟอร์มใหม่บังคับกรอก)
alter table public.work_permit_requests
  add constraint work_permit_contact_phone_fmt check (contact_phone is null or contact_phone ~ '^0[0-9]{8,9}$'),
  add constraint work_permit_contact_email_fmt check (contact_email is null or (length(contact_email) <= 254 and contact_email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'));
