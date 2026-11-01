-- วิทยาเขต: มหาวิทยาลัยที่มีหลายวิทยาเขตให้นักเรียนระบุ + เพิ่มวิทยาลัยพยาบาลบรมราชชนนี

-- 1) รายการวิทยาเขตของแต่ละมหาวิทยาลัย (ว่าง = ไม่ต้องระบุ)
alter table public.iv_universities add column if not exists campuses text[] not null default '{}';

update public.iv_universities u set campuses = v.c from (values
  ('มหาวิทยาลัยเกษตรศาสตร์',                   array['บางเขน','กำแพงแสน','ศรีราชา','เฉลิมพระเกียรติ จังหวัดสกลนคร']),
  ('มหาวิทยาลัยมหิดล',                         array['ศาลายา','พญาไท','บางกอกน้อย','กาญจนบุรี','นครสวรรค์','อำนาจเจริญ']),
  ('มหาวิทยาลัยบูรพา',                         array['บางแสน','จันทบุรี','สระแก้ว']),
  ('มหาวิทยาลัยธรรมศาสตร์',                    array['ท่าพระจันทร์','รังสิต','ลำปาง','พัทยา']),
  ('มหาวิทยาลัยศรีนครินทรวิโรฒ',               array['ประสานมิตร','องครักษ์']),
  ('มหาวิทยาลัยศิลปากร',                       array['วังท่าพระ','พระราชวังสนามจันทร์','เพชรบุรี','ศาลายา']),
  ('มหาวิทยาลัยสงขลานครินทร์',                 array['หาดใหญ่','ปัตตานี','ภูเก็ต','สุราษฎร์ธานี','ตรัง']),
  ('มหาวิทยาลัยขอนแก่น',                       array['ขอนแก่น','หนองคาย']),
  ('มหาวิทยาลัยทักษิณ',                        array['สงขลา','พัทลุง']),
  ('มหาวิทยาลัยแม่โจ้',                        array['เชียงใหม่','แพร่ เฉลิมพระเกียรติ','ชุมพร']),
  ('มหาวิทยาลัยราชภัฏสวนสุนันทา',              array['ศูนย์ดุสิต','นครปฐม','สมุทรสาคร','อู่ทอง','ลำปาง']),
  ('มหาวิทยาลัยเทคโนโลยีพระจอมเกล้าธนบุรี',    array['บางมด','บางขุนเทียน','ราชบุรี']),
  ('มหาวิทยาลัยเทคโนโลยีพระจอมเกล้าพระนครเหนือ', array['กรุงเทพ','ปราจีนบุรี','ระยอง']),
  ('สถาบันเทคโนโลยีพระจอมเกล้าเจ้าคุณทหารลาดกระบัง', array['ลาดกระบัง','ชุมพร']),
  ('มหาวิทยาลัยศรีปทุม',                       array['บางเขน','ชลบุรี','ขอนแก่น']),
  ('มหาวิทยาลัยกรุงเทพ',                       array['รังสิต','กล้วยน้ำไท']),
  ('มหาวิทยาลัยอัสสัมชัญ',                     array['หัวหมาก','บางนา']),
  ('มหาวิทยาลัยรามคำแหง',                      array['หัวหมาก','บางนา']),
  ('มหาวิทยาลัยเทคโนโลยีราชมงคลสุวรรณภูมิ',    array['นนทบุรี','สุพรรณบุรี','พระนครศรีอยุธยา']),
  ('มหาวิทยาลัยเทคโนโลยีราชมงคลตะวันออก',      array['อุเทนถวาย','วังตะไคร้','บางพระ','จันทบุรี'])
) as v(n, c) where u.name = v.n;

-- 2) วิทยาลัยพยาบาลบรมราชชนนี (แยกจากสถาบันพระบรมราชชนก) — วิทยาเขต = จังหวัดที่ตั้งวิทยาลัย
update public.iv_universities
   set aliases = array_remove(aliases, 'วิทยาลัยพยาบาลบรมราชชนนี')
 where name = 'สถาบันพระบรมราชชนก';

insert into public.iv_universities (name, short_name, aliases, sort_order, is_active, campuses)
select 'วิทยาลัยพยาบาลบรมราชชนนี', 'วพบ.', array['พยาบาลบรมราชชนนี','บรมราชชนนี','วพบ','พยาบาลสาธารณสุข'], 56, true,
  array['กรุงเทพมหานคร','ขอนแก่น','จักรีรัช ราชบุรี','ชลบุรี','เชียงราย','เชียงใหม่','ตรัง','นครนายก','นครราชสีมา','นครศรีธรรมราช','นครสวรรค์ (สวรรค์ประชารักษ์)','นนทบุรี','พะเยา','พิษณุโลก (พุทธชินราช)','แพร่','ยะลา','ลำปาง (นครลำปาง)','สงขลา','สระบุรี','สุพรรณบุรี','สุรินทร์','อุดรธานี','อุตรดิตถ์','อุบลราชธานี']
where not exists (select 1 from public.iv_universities where lower(name) = lower('วิทยาลัยพยาบาลบรมราชชนนี'));

-- 3) เก็บวิทยาเขตที่นักเรียนเลือกในแต่ละที่ที่ติด
alter table public.survey_admissions
  add column if not exists campus text check (campus is null or char_length(campus) <= 80);

drop index if exists public.survey_admissions_no_dup;
create unique index survey_admissions_no_dup on public.survey_admissions
  (response_id, kind, public.norm_th(institution), coalesce(public.norm_th(campus), ''),
   coalesce(public.norm_th(faculty), ''), coalesce(public.norm_th(major), ''));

grant select (campus) on public.survey_admissions to authenticated;
grant insert (campus) on public.survey_admissions to authenticated;
grant update (campus) on public.survey_admissions to authenticated;

-- 4) ตรวจวิทยาเขตในฟังก์ชันตรวจข้อมูล (ต้องระบุเมื่อเพิ่ม/เปลี่ยนมหาวิทยาลัยหรือวิทยาเขต; แถวเก่าที่ไม่ได้แก้ยังกด "เลือกเรียน" ได้)
do $$
declare d text;
begin
  select pg_get_functiondef('public.survey_admissions_guard()'::regprocedure) into d;
  if d not like '%v_campuses%' then
    d := replace(d, 'declare v_grade text; v_owner uuid; v_uname text; v_n int;',
                    'declare v_grade text; v_owner uuid; v_uname text; v_n int; v_campuses text[];');
    d := replace(d, E'  if tg_op = ''INSERT'' then\n    select count(*) into v_n',
$p$  new.campus := nullif(btrim(regexp_replace(coalesce(new.campus,''), '\s+', ' ', 'g')), '');
  v_campuses := '{}';
  if new.kind = 'university' and new.university_id is not null then
    select campuses into v_campuses from public.iv_universities where id = new.university_id;
  end if;
  if coalesce(array_length(v_campuses, 1), 0) = 0 then
    new.campus := null;
  elsif new.campus is null and (tg_op = 'INSERT' or new.institution is distinct from old.institution
        or new.university_id is distinct from old.university_id or new.campus is distinct from old.campus) then
    raise exception 'กรุณาระบุวิทยาเขต';
  end if;

  if tg_op = 'INSERT' then
    select count(*) into v_n$p$);
    execute d;
  end if;
end $$;

-- 5) การ์ด: เปลี่ยนวิทยาเขตของที่ที่เลือก = ต้องให้ครูตรวจใหม่
do $$
declare d text;
begin
  select pg_get_functiondef('public.survey_responses_zz_admission_card()'::regprocedure) into d;
  if d not like '%a.campus%' then
    d := replace(d, 'public.survey_card_key(new.institution, new.program, new.photo_path)',
                    'public.survey_card_key(new.institution, concat_ws(''|'', new.program, a.campus), new.photo_path)');
    execute d;
  end if;
end $$;
