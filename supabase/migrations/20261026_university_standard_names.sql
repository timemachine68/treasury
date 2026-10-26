-- ชื่อมหาวิทยาลัยมาตรฐานเดียวกัน: ใช้ตารางกลาง iv_universities
-- 1) เติมรายการ  2) survey_responses.university_id + trigger ทำชื่อให้ตรงรายการ  3) RPC ให้ครูจัดชื่อที่นักเรียนพิมพ์เอง

create unique index if not exists iv_universities_name_uq on public.iv_universities (lower(name));

insert into public.iv_universities (name, short_name, aliases, sort_order, is_active) values
 ('มหาวิทยาลัยเชียงใหม่','ม.เชียงใหม่',array['เชียงใหม่','มช','CMU'],13,true),
 ('มหาวิทยาลัยขอนแก่น','ม.ขอนแก่น',array['ขอนแก่น','มข','KKU'],14,true),
 ('มหาวิทยาลัยสงขลานครินทร์','ม.อ.',array['สงขลานครินทร์','มอ','PSU','หาดใหญ่','ม.สงขลานครินทร์'],15,true),
 ('มหาวิทยาลัยศิลปากร','ม.ศิลปากร',array['ศิลปากร','มศก','SU','วังท่าพระ','สนามจันทร์'],16,true),
 ('มหาวิทยาลัยนเรศวร','ม.นเรศวร',array['นเรศวร','มน','NU'],17,true),
 ('มหาวิทยาลัยทักษิณ','ม.ทักษิณ',array['ทักษิณ','มทษ','TSU'],18,true),
 ('มหาวิทยาลัยอุบลราชธานี','ม.อุบลฯ',array['อุบลราชธานี','อุบล','มอบ','UBU'],19,true),
 ('มหาวิทยาลัยเทคโนโลยีสุรนารี','มทส.',array['สุรนารี','มทส','SUT','เทคโนโลยีสุรนารี'],20,true),
 ('มหาวิทยาลัยแม่ฟ้าหลวง','มฟล.',array['แม่ฟ้าหลวง','มฟล','MFU'],21,true),
 ('มหาวิทยาลัยพะเยา','ม.พะเยา',array['พะเยา','มพ','UP'],22,true),
 ('มหาวิทยาลัยวลัยลักษณ์','ม.วลัยลักษณ์',array['วลัยลักษณ์','มวล','WU'],23,true),
 ('มหาวิทยาลัยแม่โจ้','ม.แม่โจ้',array['แม่โจ้','มจ','MJU'],24,true),
 ('มหาวิทยาลัยนครพนม','ม.นครพนม',array['นครพนม','นพ','NPU'],25,true),
 ('มหาวิทยาลัยรามคำแหง','ม.รามฯ',array['รามคำแหง','ราม','มร','RU'],26,true),
 ('มหาวิทยาลัยสุโขทัยธรรมาธิราช','มสธ.',array['สุโขทัยธรรมาธิราช','มสธ','STOU','สุโขทัย'],27,true),
 ('มหาวิทยาลัยเทคโนโลยีพระจอมเกล้าพระนครเหนือ','มจพ.',array['มจพ','พระจอมเกล้าพระนครเหนือ','พระนครเหนือ','KMUTNB'],28,true),
 ('มหาวิทยาลัยเทคโนโลยีราชมงคลกรุงเทพ','มทร.กรุงเทพ',array['ราชมงคลกรุงเทพ','มทรกรุงเทพ','RMUTK'],29,true),
 ('มหาวิทยาลัยเทคโนโลยีราชมงคลพระนคร','มทร.พระนคร',array['ราชมงคลพระนคร','มทรพระนคร','RMUTP'],30,true),
 ('มหาวิทยาลัยเทคโนโลยีราชมงคลตะวันออก','มทร.ตะวันออก',array['ราชมงคลตะวันออก','มทรตะวันออก','RMUTTO'],31,true),
 ('มหาวิทยาลัยเทคโนโลยีราชมงคลสุวรรณภูมิ','มทร.สุวรรณภูมิ',array['ราชมงคลสุวรรณภูมิ','มทรสุวรรณภูมิ','RMUTSB'],32,true),
 ('มหาวิทยาลัยเทคโนโลยีราชมงคลรัตนโกสินทร์','มทร.รัตนโกสินทร์',array['ราชมงคลรัตนโกสินทร์','มทรรัตนโกสินทร์','RMUTR'],33,true),
 ('มหาวิทยาลัยราชภัฏพระนคร','มรภ.พระนคร',array['ราชภัฏพระนคร','มรภพระนคร','PNRU'],34,true),
 ('มหาวิทยาลัยราชภัฏจันทรเกษม','มรภ.จันทรเกษม',array['ราชภัฏจันทรเกษม','จันทรเกษม','CRU'],35,true),
 ('มหาวิทยาลัยราชภัฏบ้านสมเด็จเจ้าพระยา','มรภ.บ้านสมเด็จ',array['ราชภัฏบ้านสมเด็จ','บ้านสมเด็จ','BSRU'],36,true),
 ('มหาวิทยาลัยราชภัฏราชนครินทร์','มรภ.ราชนครินทร์',array['ราชภัฏราชนครินทร์','ราชนครินทร์','RNRU','ฉะเชิงเทรา'],37,true),
 ('มหาวิทยาลัยหัวเฉียวเฉลิมพระเกียรติ','ม.หัวเฉียว',array['หัวเฉียว','HCU','ม.หัวเฉียวเฉลิมพระเกียรติ'],38,true),
 ('มหาวิทยาลัยรังสิต','ม.รังสิต',array['รังสิต','RSU'],39,true),
 ('มหาวิทยาลัยกรุงเทพ','ม.กรุงเทพ',array['กรุงเทพ','BU'],40,true),
 ('มหาวิทยาลัยหอการค้าไทย','ม.หอการค้า',array['หอการค้า','หอการค้าไทย','UTCC'],41,true),
 ('มหาวิทยาลัยศรีปทุม','ม.ศรีปทุม',array['ศรีปทุม','SPU'],42,true),
 ('มหาวิทยาลัยเกริก','ม.เกริก',array['เกริก','KU เกริก'],43,true),
 ('มหาวิทยาลัยธุรกิจบัณฑิตย์','มธบ.',array['ธุรกิจบัณฑิตย์','มธบ','DPU'],44,true),
 ('มหาวิทยาลัยเอเชียอาคเนย์','ม.เอเชียอาคเนย์',array['เอเชียอาคเนย์','SAU'],45,true),
 ('มหาวิทยาลัยสยาม','ม.สยาม',array['สยาม','SIAM'],46,true),
 ('มหาวิทยาลัยอัสสัมชัญ','ABAC',array['อัสสัมชัญ','เอแบค','ABAC'],47,true),
 ('มหาวิทยาลัยเทคโนโลยีมหานคร','มทม.',array['มหานคร','มทม','MUT'],48,true),
 ('มหาวิทยาลัยเนชั่น','ม.เนชั่น',array['เนชั่น'],49,true),
 ('สถาบันเทคโนโลยีปทุมวัน','สทป.',array['ปทุมวัน','สทป'],50,true),
 ('สถาบันการบินพลเรือน','สบพ.',array['การบินพลเรือน','สบพ','CATC'],51,true),
 ('สถาบันบัณฑิตพัฒนศิลป์','สบศ.',array['พัฒนศิลป์','บัณฑิตพัฒนศิลป์'],52,true),
 ('มหาวิทยาลัยนวมินทราธิราช','ม.นวมินทราธิราช',array['นวมินทราธิราช'],53,true),
 ('มหาวิทยาลัยการกีฬาแห่งชาติ','ม.การกีฬา',array['การกีฬาแห่งชาติ','การกีฬา'],54,true),
 ('สถาบันพระบรมราชชนก','สบช.',array['พระบรมราชชนก','สบช','วิทยาลัยพยาบาลบรมราชชนนี'],55,true)
on conflict ((lower(name))) do nothing;

alter table public.survey_responses
  add column if not exists university_id uuid references public.iv_universities(id) on delete set null;
create index if not exists survey_responses_university_idx on public.survey_responses(university_id);

-- ทำชื่อให้เทียบกันได้: ตัวพิมพ์เล็ก ตัดช่องว่าง จุด ขีด ลูกน้ำ วงเล็บ
create or replace function public.norm_th(p text) returns text
language sql immutable set search_path = public as
$$ select lower(regexp_replace(coalesce(p,''), '[\s\.\-,()]', '', 'g')) $$;

-- หา id มหาวิทยาลัยจากชื่อที่พิมพ์ (ชื่อเต็ม/ชื่อย่อ/ชื่อเรียกอื่น) คืนค่าเมื่อตรงกันเพียงที่เดียวเท่านั้น
create or replace function public.match_university(p text) returns uuid
language sql stable set search_path = public as $$
  with t as (select public.norm_th(p) n),
  hits as (
    select u.id from public.iv_universities u, t
    where t.n <> '' and u.is_active and (
      public.norm_th(u.name) = t.n or public.norm_th(u.short_name) = t.n
      or exists (select 1 from unnest(coalesce(u.aliases,'{}')) a where public.norm_th(a) = t.n))
  )
  select case when (select count(*) from hits) = 1 then (select id from hits) end
$$;

create or replace function public.survey_responses_norm_university() returns trigger
language plpgsql set search_path = public as $$
declare uname text;
begin
  if new.status is distinct from 'มหาวิทยาลัย' then
    new.university_id := null; return new;
  end if;
  -- แก้ข้อความชื่อโดยไม่ได้เปลี่ยน id (เช่น ฟอร์มรุ่นเก่า) ให้จับคู่ใหม่จากข้อความ
  if tg_op = 'UPDATE' and new.institution is distinct from old.institution
     and new.university_id is not distinct from old.university_id then
    new.university_id := null;
  end if;
  if new.university_id is null then
    new.university_id := public.match_university(new.institution);
  end if;
  if new.university_id is not null then
    select name into uname from public.iv_universities where id = new.university_id;
    if uname is null then new.university_id := null; else new.institution := uname; end if;
  end if;
  return new;
end $$;
revoke all on function public.survey_responses_norm_university() from public, anon, authenticated;

drop trigger if exists survey_responses_norm_university on public.survey_responses;
create trigger survey_responses_norm_university before insert or update
  on public.survey_responses for each row execute function public.survey_responses_norm_university();

-- ให้คำตอบเดิมตรงรายการเท่าที่จับคู่ได้
update public.survey_responses set institution = institution where status = 'มหาวิทยาลัย';

-- ครูจัดชื่อที่นักเรียนพิมพ์เอง: ผูกกับมหาวิทยาลัยในรายการ + จำชื่อนั้นเป็นชื่อเรียกอื่น (รอบหน้าตรงเองอัตโนมัติ)
create or replace function public.survey_map_university(p_text text, p_university_id uuid)
returns integer language plpgsql security definer set search_path = public as $$
declare n integer; t text := btrim(coalesce(p_text,''));
begin
  if not public.iv_is_staff() then raise exception 'เฉพาะครูแนะแนวและผู้ดูแลระบบ'; end if;
  if t = '' or not exists (select 1 from public.iv_universities where id = p_university_id) then
    raise exception 'ข้อมูลไม่ครบ';
  end if;
  update public.survey_responses set university_id = p_university_id
   where status = 'มหาวิทยาลัย' and university_id is null and institution = t;
  get diagnostics n = row_count;
  update public.iv_universities
     set aliases = array_append(coalesce(aliases,'{}'), t)
   where id = p_university_id and not (t = any(coalesce(aliases,'{}'))) and public.norm_th(name) <> public.norm_th(t);
  return n;
end $$;
revoke all on function public.survey_map_university(text, uuid) from public, anon;
grant execute on function public.survey_map_university(text, uuid) to authenticated;
