-- ระบบซ้อมสัมภาษณ์: เป้าหมายมหาวิทยาลัย/คณะ (ไม่บังคับ) + ชุดคำถามเฉพาะมหาวิทยาลัย + ธงคำถาม AI
-- (ใช้กับฐานข้อมูลจริงแล้วเมื่อ 24 ต.ค. 2569 — ข้อมูลคำถามอยู่ในไฟล์ 20261024_iv_university_and_ai_questions_seed.sql)

-- มหาวิทยาลัยที่มีชุดคำถามเฉพาะ
create table public.iv_universities (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  short_name text,
  aliases text[] not null default '{}',
  sort_order integer not null default 100,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.iv_universities enable row level security;
create policy "authenticated read iv_universities" on public.iv_universities for select to authenticated using (true);
create policy "staff write iv_universities" on public.iv_universities for all to authenticated
  using (iv_is_staff()) with check (iv_is_staff());

-- รายชื่อคณะให้เลือก (ผูกกับหมวดคำถาม เพื่อแนะนำหมวดให้อัตโนมัติ)
create table public.iv_faculty_options (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  category_id uuid references public.iv_categories(id) on delete set null,
  sort_order integer not null default 100,
  is_active boolean not null default true
);
alter table public.iv_faculty_options enable row level security;
create policy "authenticated read iv_faculty_options" on public.iv_faculty_options for select to authenticated using (true);
create policy "staff write iv_faculty_options" on public.iv_faculty_options for all to authenticated
  using (iv_is_staff()) with check (iv_is_staff());

-- คำถาม: ผูกมหาวิทยาลัย (ถ้าเป็นชุดเฉพาะ) + ธงคำถาม AI
alter table public.iv_questions
  add column university_id uuid references public.iv_universities(id) on delete restrict,
  add column is_ai boolean not null default false;
create index iv_questions_university_idx on public.iv_questions(university_id) where university_id is not null;

-- เซ็ตซ้อม: เป้าหมายที่นักเรียนระบุ (ไม่บังคับ)
alter table public.iv_sessions
  add column university_id uuid references public.iv_universities(id) on delete set null,
  add column target_university text,
  add column target_faculty text;
alter table public.iv_sessions
  add constraint iv_sessions_target_len check (char_length(coalesce(target_university,'')) <= 120
                                           and char_length(coalesce(target_faculty,'')) <= 120);

-- ข้อมูลตั้งต้น: มหาวิทยาลัย 12 แห่ง
insert into public.iv_universities(name, short_name, aliases, sort_order) values
 ('มหาวิทยาลัยบูรพา','ม.บูรพา', array['บูรพา','มบ','BUU','บางแสน'], 1),
 ('สถาบันเทคโนโลยีพระจอมเกล้าเจ้าคุณทหารลาดกระบัง','สจล.', array['สจล','ลาดกระบัง','พระจอมเกล้าลาดกระบัง','KMITL'], 2),
 ('มหาวิทยาลัยเทคโนโลยีราชมงคลธัญบุรี','มทร.ธัญบุรี', array['ราชมงคลธัญบุรี','มทรธัญบุรี','ธัญบุรี','RMUTT'], 3),
 ('มหาวิทยาลัยมหาสารคาม','ม.มหาสารคาม', array['มหาสารคาม','มมส','MSU'], 4),
 ('จุฬาลงกรณ์มหาวิทยาลัย','จุฬาฯ', array['จุฬา','จุฬาลงกรณ์','CU','Chula'], 5),
 ('มหาวิทยาลัยมหิดล','ม.มหิดล', array['มหิดล','มม','MU','Mahidol'], 6),
 ('มหาวิทยาลัยธรรมศาสตร์','มธ.', array['ธรรมศาสตร์','มธ','TU'], 7),
 ('มหาวิทยาลัยเกษตรศาสตร์','มก.', array['เกษตรศาสตร์','เกษตร','มก','KU'], 8),
 ('มหาวิทยาลัยศรีนครินทรวิโรฒ','มศว', array['ศรีนครินทรวิโรฒ','มศว','SWU','ประสานมิตร','องครักษ์'], 9),
 ('มหาวิทยาลัยเทคโนโลยีพระจอมเกล้าธนบุรี','มจธ.', array['มจธ','บางมด','พระจอมเกล้าธนบุรี','KMUTT'], 10),
 ('มหาวิทยาลัยราชภัฏธนบุรี','มรภ.ธนบุรี', array['ราชภัฏธนบุรี','มรภธนบุรี','DRU'], 11),
 ('มหาวิทยาลัยราชภัฏสวนสุนันทา','มรภ.สวนสุนันทา', array['สวนสุนันทา','ราชภัฏสวนสุนันทา','SSRU'], 12);

-- ข้อมูลตั้งต้น: คณะ → หมวดคำถาม
insert into public.iv_faculty_options(name, category_id, sort_order)
select f.name, c.id, f.ord from (values
 ('แพทยศาสตร์','แพทย์ · พยาบาล · สาธารณสุข',1),('พยาบาลศาสตร์','แพทย์ · พยาบาล · สาธารณสุข',2),
 ('เภสัชศาสตร์','แพทย์ · พยาบาล · สาธารณสุข',3),('ทันตแพทยศาสตร์','แพทย์ · พยาบาล · สาธารณสุข',4),
 ('สัตวแพทยศาสตร์','แพทย์ · พยาบาล · สาธารณสุข',5),('สหเวชศาสตร์ / เทคนิคการแพทย์','แพทย์ · พยาบาล · สาธารณสุข',6),
 ('สาธารณสุขศาสตร์','แพทย์ · พยาบาล · สาธารณสุข',7),('วิทยาศาสตร์การกีฬา','แพทย์ · พยาบาล · สาธารณสุข',8),
 ('วิศวกรรมศาสตร์','วิศวกรรม · วิทยาศาสตร์ · เทคโนโลยี',10),('วิทยาศาสตร์','วิศวกรรม · วิทยาศาสตร์ · เทคโนโลยี',11),
 ('วิทยาการคอมพิวเตอร์ / เทคโนโลยีสารสนเทศ','วิศวกรรม · วิทยาศาสตร์ · เทคโนโลยี',12),
 ('วิทยาการสารสนเทศ','วิศวกรรม · วิทยาศาสตร์ · เทคโนโลยี',13),
 ('เกษตรศาสตร์ / อุตสาหกรรมเกษตร','วิศวกรรม · วิทยาศาสตร์ · เทคโนโลยี',14),
 ('วิทยาศาสตร์ทางทะเล / ประมง','วิศวกรรม · วิทยาศาสตร์ · เทคโนโลยี',15),
 ('ครุศาสตร์','ครุศาสตร์ · ศึกษาศาสตร์',20),('ศึกษาศาสตร์','ครุศาสตร์ · ศึกษาศาสตร์',21),
 ('ครุศาสตร์อุตสาหกรรมและเทคโนโลยี','ครุศาสตร์ · ศึกษาศาสตร์',22),
 ('บริหารธุรกิจ','บริหาร · บัญชี · เศรษฐศาสตร์',30),('บัญชี','บริหาร · บัญชี · เศรษฐศาสตร์',31),
 ('เศรษฐศาสตร์','บริหาร · บัญชี · เศรษฐศาสตร์',32),('การท่องเที่ยวและการโรงแรม','บริหาร · บัญชี · เศรษฐศาสตร์',33),
 ('โลจิสติกส์','บริหาร · บัญชี · เศรษฐศาสตร์',34),
 ('นิติศาสตร์','มนุษยศาสตร์ · สังคม · นิติ · รัฐศาสตร์',40),('รัฐศาสตร์','มนุษยศาสตร์ · สังคม · นิติ · รัฐศาสตร์',41),
 ('มนุษยศาสตร์ / อักษรศาสตร์ / ศิลปศาสตร์','มนุษยศาสตร์ · สังคม · นิติ · รัฐศาสตร์',42),
 ('สังคมศาสตร์ / สังคมสงเคราะห์','มนุษยศาสตร์ · สังคม · นิติ · รัฐศาสตร์',43),
 ('จิตวิทยา','มนุษยศาสตร์ · สังคม · นิติ · รัฐศาสตร์',44),
 ('สถาปัตยกรรมศาสตร์','ศิลปกรรม · สถาปัตย์ · นิเทศศาสตร์',50),('ศิลปกรรมศาสตร์ / วิจิตรศิลป์','ศิลปกรรม · สถาปัตย์ · นิเทศศาสตร์',51),
 ('นิเทศศาสตร์ / สื่อสารมวลชน','ศิลปกรรม · สถาปัตย์ · นิเทศศาสตร์',52),('ดนตรี','ศิลปกรรม · สถาปัตย์ · นิเทศศาสตร์',53),
 ('หลักสูตรนานาชาติ (สัมภาษณ์ภาษาอังกฤษ)','ภาษาอังกฤษ (English Interview)',60)
) f(name, cat, ord) join public.iv_categories c on c.name = f.cat;
