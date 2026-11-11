-- เพิ่มสถาบันเทคโนโลยีไทย-ญี่ปุ่น ในรายชื่อมหาวิทยาลัยมาตรฐาน
insert into public.iv_universities (name, short_name, aliases, sort_order, is_active) values
 ('สถาบันเทคโนโลยีไทย-ญี่ปุ่น','TNI',array['ไทย-ญี่ปุ่น','ไทยญี่ปุ่น','เทคโนโลยีไทย-ญี่ปุ่น','TNI','Thai-Nichi','Thai Nichi Institute of Technology','สถาบันไทย-ญี่ปุ่น'],57,true)
on conflict ((lower(name))) do nothing;
