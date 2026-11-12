/* ข้อมูลเกม "ใกล้บ้าน vs ไกลบ้าน" — ใช้ร่วมกันใน cost-game.html / cost-game-teacher.html / cost-game-cards.html
   ตรวจข้อมูลล่าสุด: 9 พ.ย. 2569  (ปีหน้าแก้แค่ไฟล์นี้ไฟล์เดียว)
   ค่าเทอม = ค่าธรรมเนียมเหมาจ่ายต่อภาคการศึกษา ภาคปกติ นักศึกษาไทย
   รุ่นพี่ = จำนวนนักเรียนพูลเจริญวิทยาคมที่มีชื่อในไฟล์ผลการคัดเลือก TCAS ปี 2569 (นับเฉพาะวิทยาเขตนี้) */
window.CG = (function(){
const CHECKED = "9 พ.ย. 2569";
const YEAR = "2569";

const SRC = {
  custom:{t:"ตัวเลขที่นักเรียนกรอกเอง (ไม่ได้ตรวจกับประกาศของมหาวิทยาลัย)", u:""},
  hcu:  {t:"ตารางค่าธรรมเนียมเหมาจ่าย ป.ตรี ปี 2569 ม.หัวเฉียวเฉลิมพระเกียรติ", u:"https://admission.hcu.ac.th/Files/payment.pdf"},
  kmitl:{t:"สรุปค่าเทอม สจล. 2569 (อ้างประกาศสำนักทะเบียน สจล.)", u:"https://dreamnesthub.com/tuition-fee-kmitl-2569"},
  ku:   {t:"ประกาศรับสมัคร TCAS1 ปี 2569 มก.ศรีราชา (ข้อ 9 ค่าธรรมเนียม)", u:"https://admissions.src.ku.ac.th/pdf/TCAS1_1_69.pdf"},
  buu:  {t:"สรุปค่าเทอม ม.บูรพา 2569 (อ้างระเบียบมหาวิทยาลัย)", u:"https://dreamnesthub.com/tuition-fee-buu-2569"},
  mfu:  {t:"สรุปค่าเทอม ม.แม่ฟ้าหลวง 2569", u:"https://dreamnesthub.com/tuition-fee-mfu-2568"},
  bu:   {t:"สรุปค่าเทอม ม.กรุงเทพ (ค่าเทอมภาคเรียนแรก ปี 2569 ของสาขาที่ใช้เทียบ)", u:"https://dreamnesthub.com/tuition-fee-bu-2569"},
  up:   {t:"สรุปค่าเทอม ม.พะเยา 2569 (ประมาณการรายกลุ่มคณะ ควรตรวจประกาศ REG-UP)", u:"https://dreamnesthub.com/khafee-mahawithayalai-phayao-2568"},
  rmutk:{t:"อัตราการเก็บเงินรับเข้า ป.ตรี สำหรับนักศึกษารับเข้าปี 2570 มทร.กรุงเทพ (ปรับปรุง 4 พ.ย. 2569)", u:"https://admission.rmutk.ac.th/?p=16311"},
  dormUP:{t:"ประกาศอัตราค่าธรรมเนียมหอพัก ม.พะเยา (ใช้ตั้งแต่ปีการศึกษา 2564 ตามเอกสารที่ครูส่งมา)", u:""},
  dormIn:{t:"สำรวจราคาหอในมหาวิทยาลัย ปี 2568 (LINE TODAY)", u:"https://today.line.me/th/v3/article/aGLP5qo"},
  rent: {t:"ราคาหอนอกใกล้มหาวิทยาลัย (ค่ากลางของหน้า 'ราคาถูก' RentHub)", u:"https://www.renthub.in.th/"},
  bus:  {t:"ค่ารถทัวร์ กรุงเทพฯ–เชียงราย เริ่ม 789 บาท (12Go)", u:"https://12go.com/th/bus/bangkok/chiang-rai"},
  cmu:  {t:"ค่าธรรมเนียมการศึกษา ป.ตรี หลักสูตรไทยภาคปกติ ม.เชียงใหม่ (ใช้กับผู้เข้าศึกษาปี 2570 ข้อมูล ณ 6 ต.ค. 2569 · ตัวเลขเป็นภาคแรก)", u:"https://admission.reg.cmu.ac.th/tcas/files_download/%E0%B8%84%E0%B9%88%E0%B8%B2%E0%B8%98%E0%B8%A3%E0%B8%A3%E0%B8%A1%E0%B9%80%E0%B8%99%E0%B8%B5%E0%B8%A2%E0%B8%A1%E0%B8%81%E0%B8%B2%E0%B8%A3%E0%B8%A8%E0%B8%B6%E0%B8%81%E0%B8%A9%E0%B8%B2.pdf"},
  nu:   {t:"ประกาศ ม.นเรศวร อัตราค่าธรรมเนียมการศึกษา ป.ตรี ภาคปกติ ผู้เข้าศึกษาตั้งแต่ปีการศึกษา 2568 เป็นต้นไป (ลงวันที่ 13 พ.ย. 2567 ตัวเลขต่อภาค)", u:"https://www.admission.nu.ac.th/pdf/%E0%B8%9B%E0%B8%A3%E0%B8%B0%E0%B8%81%E0%B8%B2%E0%B8%A8%E0%B8%84%E0%B9%88%E0%B8%B2%E0%B8%98%E0%B8%A3%E0%B8%A3%E0%B8%A1%E0%B9%80%E0%B8%99%E0%B8%B5%E0%B8%A2%E0%B8%A1%20%E0%B8%9B.%E0%B8%95%E0%B8%A3%E0%B8%B5-68.pdf"},
  nuTrip:{t:"ค่ารถทัวร์ กรุงเทพฯ–พิษณุโลก ประมาณ 9.6–12.7 ดอลลาร์สหรัฐ ใช้เวลาราว 6 ชม. (12Go) · ค่ากลับบ้านต่อครั้งในเกมเป็นค่าประมาณของหนู", u:"https://12go.com/th/travel/bangkok/phitsanulok?z=7173817"},
  psuDorm:{t:"หอพักศรีตรัง 1 ม.อ.ตรัง: ห้อง 2 คน 3,800 + น้ำ 200 บาท/ภาค + ประกันทรัพย์สิน 1,000 บาท/ปี (รวมคิด 4,500/ภาค) · ค่าไฟตามจริง ใช้ค่าประมาณ 150/เดือน · เอกสารไม่ระบุปี", u:"https://www.psu.ac.th/trang/wp-content/uploads/%E0%B8%A3%E0%B8%B2%E0%B8%A2%E0%B8%A5%E0%B8%B0%E0%B9%80%E0%B8%AD%E0%B8%B5%E0%B8%A2%E0%B8%94%E0%B8%82%E0%B9%89%E0%B8%AD%E0%B8%A1%E0%B8%B9%E0%B8%A5%E0%B9%81%E0%B8%A5%E0%B8%B0%E0%B8%AA%E0%B8%B4%E0%B9%88%E0%B8%87%E0%B8%AD%E0%B8%B3%E0%B8%99%E0%B8%A7%E0%B8%A2%E0%B8%84%E0%B8%A7%E0%B8%B2%E0%B8%A1%E0%B8%AA%E0%B8%B0%E0%B8%94%E0%B8%A7%E0%B8%81-%E0%B8%AB%E0%B8%AD%E0%B8%9E%E0%B8%B1%E0%B8%81%E0%B8%A8%E0%B8%A3%E0%B8%B5%E0%B8%95%E0%B8%A3%E0%B8%B1%E0%B8%87-1.pdf"},
  psuTrip:{t:"รถไฟชั้น 3 กรุงเทพฯ–ตรัง ประมาณ 7 ดอลลาร์สหรัฐ (~250 บาท) ต่อเที่ยว ราว 14 ชม. (12Go) · ไป-กลับ ~500 บาท", u:"https://12go.asia/en/travel/trang/bangkok?z=14813844"},
  psuh: {t:"ม.อ.หาดใหญ่: ค่าเทอมใช้อัตรากลางของ ม.อ. ปี 2569 ตามกลุ่มคณะ ส่วนค่าหอ (หอศรีตรัง ม.อ.ตรัง) และค่ากลับบ้านใช้เป็นค่าอ้างอิง ตามที่ครูแจ้ง ยังไม่ได้ตรวจราคาหอและเส้นทางของหาดใหญ่", u:"https://regist.trang.psu.ac.th/wp-content/uploads/bachelor_fee_2569.pdf"},
  rentN:{t:"ค่าเช่าหอนอก: ใช้ค่ากลางเดียวกับ ม.พะเยา/แม่ฟ้าหลวง (ค่าประมาณ ยังไม่ได้สำรวจเฉพาะเมืองนี้ และยังไม่ได้ใส่ราคาหอในของมหาวิทยาลัย)", u:""},
  dru:  {t:"ค่าเทอม ม.ราชภัฏธนบุรี ศูนย์สมุทรปราการ ภาคปกติ (เว็บศูนย์สมุทรปราการ เป็นค่าประมาณ ไม่ระบุปี แบ่งชำระ 2 ครั้ง/เทอม)", u:"https://sp.dru.ac.th/new/?page_id=14"}
};

/* zone: near = ไป-กลับจากบ้านได้, mid = ชลบุรี กลับบ้านบ่อยได้, far = ต่างภาค */
const U = {
  hcu:  {name:"ม.หัวเฉียวเฉลิมพระเกียรติ", short:"หัวเฉียวฯ", place:"บางพลี สมุทรปราการ", type:"private", zone:"near", housing:["home"], seniors:2, src:"hcu"},
  bu:   {name:"ม.กรุงเทพ", short:"ม.กรุงเทพ", place:"กล้วยน้ำไท / รังสิต", type:"private", zone:"near", housing:["home"], seniors:0, src:"bu"},
  rmutk:{name:"มทร.กรุงเทพ (ราชมงคลกรุงเทพ)", short:"ราชมงคลกรุงเทพ", place:"สาทร กรุงเทพฯ", type:"public", zone:"near", housing:["home","dorm_out"], rent:3025, seniors:16, src:"rmutk"},
  kmitl:{name:"สจล. พระจอมเกล้าลาดกระบัง", short:"สจล.", place:"ลาดกระบัง กรุงเทพฯ", type:"public", zone:"near", housing:["home","dorm_out"], rent:3025, seniors:35, src:"kmitl"},
  ku:   {name:"ม.เกษตรศาสตร์ ศรีราชา", short:"มก.ศรีราชา", place:"ศรีราชา ชลบุรี", type:"public", zone:"mid", housing:["dorm_out"], rent:3250, seniors:7, src:"ku"},
  buu:  {name:"ม.บูรพา บางแสน", short:"บูรพา", place:"บางแสน ชลบุรี", type:"public", zone:"mid", housing:["dorm_in","dorm_out"], dormIn:{fee:3850, util:100, label:"หอในพัดลม 2–4 คน/ห้อง เริ่ม 3,850 บาท/เทอม"}, rent:3250, seniors:23, src:"buu"},
  up:   {name:"ม.พะเยา", short:"ม.พะเยา", place:"เมือง พะเยา", type:"public", zone:"far", housing:["dorm_in","dorm_out"], rent:2750, dormIn:{fee:10580, util:150, label:"หอในพัดลม 4 คน/ห้อง 21,160 บาท/ปี (หอ มพ. 2 คน/ห้อง ถูกสุด 12,000 · ห้องแอร์ 29,095–31,740 บาท/ปี)"}, dormSrc:"dormUP", seniors:7, src:"up"},
  mfu:  {name:"ม.แม่ฟ้าหลวง", short:"แม่ฟ้าหลวง", place:"เชียงราย", type:"public", zone:"far", housing:["dorm_in","dorm_out"], dormIn:{fee:5000, util:200, label:"หอในพัดลม 4,000–6,000 บาท/เทอม (ใช้ 5,000)"}, rent:2750, firstYearIn:true, seniors:9, src:"mfu"},
  /* seniors:"N" = รอใส่จำนวนรุ่นพี่จริงจากไฟล์ผลคัดเลือก TCAS 2569 (เกมจะแสดง "N คน") */
  cmu:  {name:"ม.เชียงใหม่", short:"มช.", place:"เมือง เชียงใหม่", type:"public", zone:"far", housing:["dorm_out"], rent:2750, rentSrc:"rentN", seniors:"N", src:"cmu"},
  nu:   {name:"ม.นเรศวร", short:"ม.นเรศวร", place:"เมือง พิษณุโลก", type:"public", zone:"far", housing:["dorm_out"], rent:2750, rentSrc:"rentN", trip:{cost:1000, hours:12}, tripSrc:"nuTrip", seniors:"N", src:"nu"},
  psuh: {name:"ม.สงขลานครินทร์ หาดใหญ่", short:"ม.อ.หาดใหญ่", place:"หาดใหญ่ สงขลา", type:"public", zone:"far", housing:["dorm_in"], dormIn:{fee:4500, util:150, label:"ใช้ค่าหอศรีตรังของ ม.อ. เป็นค่าอ้างอิง: ห้อง 2 คน 3,800 + น้ำ 200 + ประกัน 500 บาท/ภาค (ค่าไฟประมาณ 150/เดือน)"}, dormSrc:"psuDorm", trip:{cost:500, hours:28}, tripSrc:"psuTrip", seniors:"0", src:"psuh"},
  dru:  {name:"ม.ราชภัฏธนบุรี ศูนย์สมุทรปราการ", short:"ราชภัฏธนบุรี", place:"ศูนย์สมุทรปราการ", type:"public", zone:"near", housing:["home"], seniors:"N", src:"dru"}
};

/* sem = ค่าเทอมต่อภาค, summer = ค่าภาคฤดูร้อนรวมทั้งหลักสูตร (ถ้ามีบังคับ) */
const P = {
  hcu_biz:   {u:"hcu", name:"บริหารธุรกิจ (บัญชี / โลจิสติกส์ / บริหาร)", sem:37500, field:"biz"},
  hcu_eng:   {u:"hcu", name:"ศิลปศาสตร์ ภาษาอังกฤษ", sem:38000, field:"lang"},
  hcu_cs:    {u:"hcu", name:"วิทยาการคอมพิวเตอร์", sem:47000, field:"sci"},
  hcu_medsci:{u:"hcu", name:"วิทยาศาสตร์การแพทย์", sem:47000, field:"medsci"},
  hcu_mt:    {u:"hcu", name:"เทคนิคการแพทย์", sem:79500, field:"mt"},
  hcu_pt:    {u:"hcu", name:"กายภาพบำบัด", sem:76500, field:"pt"},
  hcu_nur:   {u:"hcu", name:"พยาบาลศาสตร์", sem:90000, summer:132000, note:"รวมภาคฤดูร้อน 3 ครั้ง ครั้งละ 44,000", field:"nur"},
  hcu_oh:    {u:"hcu", name:"อาชีวอนามัยและความปลอดภัย", sem:50000, field:"oh"},

  bu_biz:    {u:"bu", name:"บริหารธุรกิจ (การตลาด)", sem:43180, field:"biz", note:"ใช้ค่าเทอมภาคแรก ปี 69 เป็นค่าเฉลี่ยต่อภาค"},
  bu_eng:    {u:"bu", name:"มนุษยศาสตร์ ภาษาอังกฤษ", sem:44580, field:"lang", note:"ใช้ค่าเทอมภาคแรก ปี 69 เป็นค่าเฉลี่ยต่อภาค"},

  rmutk_biz: {u:"rmutk", name:"บริหารธุรกิจ (การตลาด / การบัญชี / การเงิน)", sem:9500, fixed:5320, field:"biz", note:"ค่าเทอม 9,000 + กิจกรรม 500 · รวมค่าแรกเข้า/ประกันของเสียหาย 5,320 บาทครั้งเดียว"},
  rmutk_cs:  {u:"rmutk", name:"วิทยาการคอมพิวเตอร์", sem:10550, fixed:5320, field:"sci", note:"ค่าเทอม 10,050 + กิจกรรม 500 · รวมค่าแรกเข้า/ประกันของเสียหาย 5,320 บาทครั้งเดียว"},
  rmutk_eng: {u:"rmutk", name:"ศิลปศาสตร์ ภาษาอังกฤษเพื่อการสื่อสารสากล", sem:9550, fixed:5320, field:"lang", note:"ค่าเทอม 9,050 + กิจกรรม 500 · รวมค่าแรกเข้า/ประกันของเสียหาย 5,320 บาทครั้งเดียว"},
  rmutk_health:{u:"rmutk", name:"วิทยาศาสตร์เพื่อสุขภาพและความงาม", sem:10550, fixed:5320, field:"medsci", note:"ค่าเทอม 10,050 + กิจกรรม 500 · รวมค่าแรกเข้า/ประกันของเสียหาย 5,320 บาทครั้งเดียว"},

  kmitl_biz: {u:"kmitl", name:"บริหารธุรกิจ", sem:20000, field:"biz"},
  kmitl_sci: {u:"kmitl", name:"วิทยาศาสตร์ (หลักสูตรภาษาไทย)", sem:19000, field:"sci"},
  kmitl_lang:{u:"kmitl", name:"ศิลปศาสตร์ ภาษาอังกฤษ / ญี่ปุ่น", sem:19000, field:"lang"},
  ku_mgt:    {u:"ku", name:"วิทยาการจัดการ (โลจิสติกส์ / การเงิน / บริหาร)", sem:17200, field:"biz"},
  ku_sci:    {u:"ku", name:"วิทยาศาสตร์ ศรีราชา", sem:22500, field:"sci"},
  buu_log:   {u:"buu", name:"โลจิสติกส์และโซ่อุปทาน", sem:21000, field:"biz"},
  buu_eng:   {u:"buu", name:"ภาษาอังกฤษเพื่อการสื่อสาร", sem:17000, field:"lang"},
  buu_sci:   {u:"buu", name:"วิทยาศาสตร์ (คณิต เคมี ฟิสิกส์ ฯลฯ)", sem:22500, field:"sci"},
  buu_medsci:{u:"buu", name:"วิทยาศาสตร์การแพทย์ (สหเวชศาสตร์)", sem:20800, field:"medsci"},
  buu_mt:    {u:"buu", name:"เทคนิคการแพทย์ (สหเวชศาสตร์)", sem:35000, field:"mt"},
  buu_pt:    {u:"buu", name:"กายภาพบำบัด (สหเวชศาสตร์)", sem:35000, field:"pt"},
  buu_nur:   {u:"buu", name:"พยาบาลศาสตร์", sem:28000, summer:42000, note:"รวมภาคฤดูร้อน 3 ครั้ง ครั้งละ 14,000 (ใช้จำนวนครั้งเท่ากับหัวเฉียวฯ เพื่อเทียบให้ยุติธรรม)", field:"nur"},
  up_mgt:    {u:"up", name:"บริหารธุรกิจ / นิเทศศาสตร์", sem:15000, field:"biz"},
  up_lang:   {u:"up", name:"ศิลปศาสตร์ (ภาษา)", sem:15000, field:"lang"},
  up_sci:    {u:"up", name:"วิทยาศาสตร์ (กลุ่มวิทยาศาสตร์)", sem:18000, field:"sci"},
  up_medsci: {u:"up", name:"วิทยาศาสตร์การแพทย์ / สาธารณสุข (กลุ่มวิทยาศาสตร์)", sem:18000, field:"medsci"},
  up_nur:    {u:"up", name:"พยาบาลศาสตร์", sem:28000, summer:42000, note:"รวมภาคฤดูร้อน 3 ครั้ง ครั้งละ 14,000 (สมมุติเท่า ม.บูรพา เพื่อเทียบให้ยุติธรรม)", field:"nur"},
  mfu_mgt:   {u:"mfu", name:"การจัดการ บริหารธุรกิจ", sem:27500, field:"biz"},
  mfu_oh:    {u:"mfu", name:"วิทยาศาสตร์สุขภาพ อาชีวอนามัยฯ", sem:30000, field:"oh"},

  cmu_biz:   {u:"cmu", name:"บริหารธุรกิจ / บัญชี (หลักสูตรไทย)", sem:18000, field:"biz"},
  cmu_sci:   {u:"cmu", name:"วิทยาศาสตร์ (เคมี ชีววิทยา ฟิสิกส์ คณิต วิทยาการคอมพิวเตอร์ ฯลฯ)", sem:18000, field:"sci"},
  cmu_lang:  {u:"cmu", name:"มนุษยศาสตร์ ภาษาอังกฤษ / ฝรั่งเศส / จิตวิทยา", sem:15000, field:"lang"},
  cmu_nur:   {u:"cmu", name:"พยาบาลศาสตร์", sem:25000, field:"nur", note:"ยังไม่รวมภาคฤดูร้อน (ประกาศของ มช. ไม่ระบุ) ค่าจริงอาจสูงกว่านี้"},
  cmu_mt:    {u:"cmu", name:"เทคนิคการแพทย์ (คณะเทคนิคการแพทย์)", sem:25000, field:"mt"},
  cmu_pt:    {u:"cmu", name:"กายภาพบำบัด (คณะเทคนิคการแพทย์)", sem:25000, field:"pt"},

  nu_biz:    {u:"nu", name:"บริหารธุรกิจ / การเงิน / บัญชี / เศรษฐศาสตร์", sem:15000, field:"biz"},
  nu_sci:    {u:"nu", name:"วิทยาศาสตร์ (เคมี ชีววิทยา ฟิสิกส์ คณิต วิทยาการคอมพิวเตอร์ ฯลฯ)", sem:16000, field:"sci"},
  nu_lang:   {u:"nu", name:"มนุษยศาสตร์ ภาษาอังกฤษ / ภาษาไทย / ภาษาจีน / ภาษาญี่ปุ่น ฯลฯ", sem:15000, field:"lang"},
  nu_nur:    {u:"nu", name:"พยาบาลศาสตร์", sem:20000, field:"nur", note:"ยังไม่รวมภาคฤดูร้อน (ประกาศของ มน. ไม่ระบุ) ค่าจริงอาจสูงกว่านี้"},
  nu_medsci: {u:"nu", name:"วิทยาศาสตร์การแพทย์ (จุลชีววิทยา พยาธิวิทยากายวิภาค ฯลฯ)", sem:20000, field:"medsci"},
  nu_mt:     {u:"nu", name:"เทคนิคการแพทย์ (คณะสหเวชศาสตร์)", sem:28000, field:"mt"},
  nu_pt:     {u:"nu", name:"กายภาพบำบัด (คณะสหเวชศาสตร์)", sem:28000, field:"pt"},

  psuh_biz: {u:"psuh", name:"วิทยาการจัดการ (บัญชี / การจัดการ)", sem:16000, field:"biz", note:"อัตรากลุ่มคณะวิทยาการจัดการ"},
  psuh_sci: {u:"psuh", name:"วิทยาศาสตร์", sem:18000, field:"sci", note:"อัตรากลุ่มคณะวิทยาศาสตร์"},
  psuh_lang:{u:"psuh", name:"ศิลปศาสตร์ (ภาษา)", sem:16000, field:"lang", note:"อัตรากลุ่มคณะศิลปศาสตร์"},
  psuh_nur: {u:"psuh", name:"พยาบาลศาสตร์", sem:22000, field:"nur", note:"ยังไม่รวมภาคฤดูร้อน"},
  psuh_mt:  {u:"psuh", name:"เทคนิคการแพทย์", sem:22000, field:"mt"},
  psuh_pt:  {u:"psuh", name:"กายภาพบำบัด", sem:18000, field:"pt", note:"อัตรากลุ่มแพทยศาสตร์ (สาขาสุขภาพ)"},
  dru_eng:   {u:"dru", name:"ภาษาอังกฤษธุรกิจ (ศศ.บ.)", sem:9000, fixed:1000, field:"lang", note:"เทอมแรก ~10,000 เทอมถัดไป ~9,000 (คิดส่วนต่างเทอมแรก 1,000 ครั้งเดียว) · ค่าประมาณจากเว็บศูนย์"},
  dru_chi:   {u:"dru", name:"ภาษาจีนเพื่อการสื่อสาร (ศศ.บ.)", sem:9000, fixed:1000, field:"lang", note:"เทอมแรก ~10,000 เทอมถัดไป ~9,000 (คิดส่วนต่างเทอมแรก 1,000 ครั้งเดียว) · ค่าประมาณจากเว็บศูนย์"},
  dru_thai:  {u:"dru", name:"ภาษาไทย (ศศ.บ.)", sem:9000, fixed:1000, field:"lang", note:"เทอมแรก ~10,000 เทอมถัดไป ~9,000 (คิดส่วนต่างเทอมแรก 1,000 ครั้งเดียว) · ค่าประมาณจากเว็บศูนย์"},
  dru_nur:   {u:"dru", name:"พยาบาลศาสตร์", sem:70000, fixed:3700, field:"nur", note:"~70,000 ต่อเทอม + ค่าใช้จ่ายเพิ่มเติมเทอมแรก ~3,700 · ยังไม่รวมภาคฤดูร้อน (เว็บไม่ระบุ) · ค่าประมาณจากเว็บศูนย์"}
};

const TRACKS = {
  biz:   {name:"ธุรกิจ บัญชี โลจิสติกส์", icon:"💼", priv:["hcu_biz","bu_biz"], pub:["kmitl_biz","ku_mgt","buu_log","mfu_mgt","up_mgt","rmutk_biz","cmu_biz","nu_biz","psuh_biz"]},
  health:{name:"สุขภาพ พยาบาล เทคนิคการแพทย์", icon:"🩺", priv:["hcu_nur","hcu_mt","hcu_pt","hcu_medsci","hcu_oh","dru_nur"], pub:["buu_nur","buu_mt","buu_pt","buu_medsci","mfu_oh","up_nur","up_medsci","rmutk_health","cmu_nur","cmu_mt","cmu_pt","nu_nur","nu_medsci","nu_mt","nu_pt","dru_nur","psuh_nur","psuh_mt","psuh_pt"]},
  sci:   {name:"วิทยาศาสตร์ คอมพิวเตอร์", icon:"🔬", priv:["hcu_cs"], pub:["kmitl_sci","ku_sci","buu_sci","up_sci","rmutk_cs","cmu_sci","nu_sci","psuh_sci"]},
  lang:  {name:"ภาษา ศิลปศาสตร์", icon:"🌏", priv:["hcu_eng","bu_eng","dru_eng","dru_chi","dru_thai"], pub:["kmitl_lang","buu_eng","up_lang","rmutk_eng","cmu_lang","nu_lang","psuh_lang","dru_eng","dru_chi","dru_thai"]}
};

const HOUSING = {home:"อยู่บ้าน ไป-กลับทุกวัน", dorm_in:"หอใน (หอของมหาวิทยาลัย)", dorm_out:"หอนอก (เช่ารายเดือน)"};

/* ค่าประมาณ — นักเรียนปรับเป็นของบ้านตัวเองได้ในเกม */
const DEFAULTS = {commute:100, hours:2, lunch:80, dormFood:150, homeFood:60};
const COMMUTE_PRESETS = [
  {k:"bus", label:"รถเมล์ / สองแถว", v:60},
  {k:"mix", label:"วินมอไซค์ + รถเมล์", v:100},
  {k:"bike", label:"ขับมอไซค์เอง (ค่าน้ำมัน)", v:50},
  {k:"car", label:"ผู้ปกครองขับรถไปส่ง", v:180},
  {k:"grab", label:"แอปเรียกรถ", v:300}
];
const K = {
  studyDays:160,   // วันเรียน/ปี = 2 เทอม × 16 สัปดาห์ × 5 วัน
  dormMonths:9,    // เดือนที่อยู่หอ/ปี
  dormDays:270,    // วันที่อยู่หอ/ปี
  utilOut:600,     // ค่าน้ำไฟหอนอก/เดือน (ประมาณ)
  tripMid:300,     // กลับบ้านจากชลบุรี ไป-กลับ/ครั้ง (ประมาณ)
  tripMidPerMonth:2,
  tripFar:1800,    // กลับบ้านจากเชียงราย ไป-กลับ/ครั้ง (รถทัวร์ 789+ ต่อเที่ยว + ค่ารถไปขนส่ง)
  tripFarPerYear:3,
  tripHoursMid:4, tripHoursFar:26
};

const REASONS = [
  {k:"safety", t:"ความปลอดภัย"},
  {k:"family", t:"ได้อยู่ใกล้ครอบครัว ช่วยงานบ้านได้"},
  {k:"major", t:"ได้เรียนคณะ/สาขาที่อยากเรียนจริง ๆ"},
  {k:"time", t:"มีเวลาอ่านหนังสือ พักผ่อน ไม่ต้องเดินทางนาน"},
  {k:"self", t:"ได้ฝึกดูแลตัวเอง"},
  {k:"job", t:"ชื่อเสียงมหาวิทยาลัย โอกาสได้งาน"}
];

/* การ์ดเหตุการณ์: side = ฝั่งที่โดน (home = คนไป-กลับ, dorm = คนอยู่หอ, both = เท่ากันทั้งคู่) */
const EVENTS = [
  {k:"fuel", side:"home", icon:"⛽", t:"น้ำมันขึ้นราคา", d:"ค่ารถไป-กลับเพิ่มขึ้น 20%", fx:p=>{p.commute=Math.round(p.commute*1.2)}},
  {k:"traffic", side:"home", icon:"🚦", t:"รถติดหนักหน้าฝน", d:"เวลาเดินทางเพิ่มอีกวันละ 30 นาที", fx:p=>{p.hours+=0.5}},
  {k:"latecls", side:"home", icon:"🌙", t:"เรียนเลิกค่ำ", d:"ต้องซื้อข้าวเย็นที่มหาวิทยาลัยด้วย วันละ +50 บาท", fx:p=>{p.lunch+=50}},
  {k:"contract", side:"dorm", icon:"📄", t:"หอนอกให้ทำสัญญา 12 เดือน", d:"ปิดเทอมก็ต้องจ่ายค่าห้อง (ถ้าอยู่หอใน ไม่โดน)", fx:p=>{p.months=12}},
  {k:"homesick", side:"dorm", icon:"🏠", t:"คิดถึงบ้าน", d:"กลับบ้านบ่อยขึ้นเป็น 2 เท่า", fx:p=>{p.tripMult=2}},
  {k:"cook", side:"dorm", icon:"🍳", t:"ทำกับข้าวกินเองกับเพื่อน", d:"ค่ากินตอนอยู่หอลดลง 20%", fx:p=>{p.dormFood=Math.round(p.dormFood*0.8)}},
  {k:"share", side:"dorm", icon:"👫", t:"หารห้องกับเพื่อน", d:"ค่าเช่าหอนอกลดครึ่งหนึ่ง (หอในหารอยู่แล้ว)", fx:p=>{p.share=true}},
  {k:"dormlotto", side:"dorm", icon:"🎟️", t:"จับฉลากได้หอใน", d:"ถ้าเลือกหอนอกไว้ และมหาวิทยาลัยมีหอใน ได้ย้ายเข้าหอใน", fx:p=>{p.forceIn=true}},
  {k:"laptop", side:"both", icon:"💻", t:"โน้ตบุ๊กพัง", d:"ค่าซ่อม 5,000 บาท ทั้งสองฝั่งเท่ากัน", fx:p=>{p.both+=5000}},
  {k:"intern", side:"both", icon:"🧳", t:"ฝึกงานต่างจังหวัด 2 เดือน", d:"เช่าห้อง+ค่ากิน 15,000 บาท ทั้งสองฝั่งเท่ากัน", fx:p=>{p.both+=15000}},
  {k:"loan", side:"both", icon:"🏦", t:"กู้ กยศ. ค่าเทอมได้", d:"ยอดรวมไม่เปลี่ยน แต่บ้านไม่ต้องจ่ายก้อนใหญ่ทันที (เรียนจบแล้วผ่อนคืน)", fx:p=>{}}
];

/* คิดเงิน 4 ปี ของ 1 ฝั่ง  — คืนรายการแยกหมวด */
function calc(progKey, housing, base){
  const pr = P[progKey], uni = U[pr.u], p = Object.assign({months:K.dormMonths, tripMult:1, share:false, forceIn:false, both:0}, base);
  let tuition = pr.sem*8 + (pr.summer||0) + (pr.fixed||0), stay=0, food=0, travel=0, hours=0;
  for(let y=1;y<=4;y++){
    let h = housing;
    if(h==="dorm_out" && uni.dormIn && (p.forceIn || (uni.firstYearIn && y===1))) h="dorm_in";
    if(h==="home"){
      food += 365*p.homeFood + K.studyDays*p.lunch;
      travel += K.studyDays*p.commute;
      hours += K.studyDays*p.hours;
    }else{
      if(h==="dorm_in"){ stay += uni.dormIn.fee*2 + uni.dormIn.util*K.dormMonths; }
      else { stay += (p.share?uni.rent/2:uni.rent)*p.months + (uni.utilOut!=null?uni.utilOut:K.utilOut)*p.months; }
      food += K.dormDays*p.dormFood + (365-K.dormDays)*p.homeFood;
      if(uni.zone==="far"){ const tc=uni.trip?uni.trip.cost:K.tripFar, th=uni.trip?uni.trip.hours:K.tripHoursFar, py=uni.tripPerYear!=null?uni.tripPerYear:K.tripFarPerYear; travel += tc*py*p.tripMult; hours += th*py*p.tripMult; }
      else { travel += K.tripMid*K.tripMidPerMonth*K.dormMonths*p.tripMult; hours += K.tripHoursMid*K.tripMidPerMonth*K.dormMonths*p.tripMult; }
    }
  }
  const other = p.both;
  const r = {tuition:Math.round(tuition), stay:Math.round(stay), food:Math.round(food), travel:Math.round(travel), other, hours:Math.round(hours)};
  r.total = r.tuition + r.stay + r.food + r.travel + r.other;
  return r;
}
const baht = n => Math.round(n).toLocaleString("th-TH");
return {CHECKED, YEAR, SRC, U, P, TRACKS, HOUSING, DEFAULTS, COMMUTE_PRESETS, K, REASONS, EVENTS, calc, baht};
})();
