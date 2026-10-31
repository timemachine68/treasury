/**
 * รับไฟล์งานนักเรียน (PDF / JPG / PNG) เข้า Google Drive ของโรงเรียน — ระบบ "แนะให้แนว"
 *
 * วิธีทำงาน
 *  1) หน้าเว็บส่ง { action, token (token ล็อกอิน Supabase ของนักเรียน/ครู), ... } มาที่ Web app นี้
 *  2) สคริปต์เอา token ไปเรียกฟังก์ชันในฐานข้อมูล (drive_submit_context / drive_submit_record / drive_view_check)
 *     ฐานข้อมูลเป็นคนตัดสินสิทธิ์ ไม่มี token ที่ถูกต้อง = ทำอะไรไม่ได้เลย
 *  3) ไฟล์เก็บที่ โฟลเดอร์หลัก / ชื่องาน / ห้อง / รหัสนักเรียน  (โฟลเดอร์เป็นส่วนตัว ไม่แชร์ใคร)
 *  4) ครูเปิดไฟล์ผ่านหน้าเว็บ (action: get) ไม่ต้องมีสิทธิ์ใน Drive
 *
 * ติดตั้ง: ดู README.md ในโฟลเดอร์เดียวกัน
 */

var SUPABASE_URL = 'https://ikkhjslmtjwrxzxvtokb.supabase.co';
// anon key เป็นกุญแจสาธารณะที่ออกแบบให้เปิดเผยได้ (ตัวเดียวกับที่อยู่ใน index.html)
var ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlra2hqc2xtdGp3cnh6eHZ0b2tiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM3NDMzNjksImV4cCI6MjA5OTMxOTM2OX0.3OR_9mEv82Ns1LLjx5nnRwJYzrtKFtWCWd1bPuQfNKU';

var ROOT_FOLDER_NAME = 'งานนักเรียน (แนะให้แนว)';
var MAX_BYTES = 10 * 1024 * 1024;           // 10 MB ต่อไฟล์
var ALLOWED = { 'application/pdf': 'pdf', 'image/jpeg': 'jpg', 'image/png': 'png' };
var UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/* ───────── จุดเข้า ───────── */

function doGet() {
  return out_({ ok: true, service: 'drive-submission' });
}

function doPost(e) {
  try {
    var req = JSON.parse((e && e.postData && e.postData.contents) || '{}');
    var token = String(req.token || '');
    if (token.length < 20 || token.length > 4000) return fail_('กรุณาเข้าสู่ระบบใหม่อีกครั้งค่ะ');

    if (req.action === 'submit') return out_(submit_(req, token));
    if (req.action === 'get') return out_(get_(req, token));
    return fail_('คำสั่งไม่ถูกต้องค่ะ');
  } catch (err) {
    var m = String(err && err.message || '');
    if (m.indexOf('Thai:') === 0) return fail_(m.slice(5));   // ข้อความภาษาไทยที่ตั้งใจบอกผู้ใช้ ไม่ต้องบันทึก log
    console.error(err && err.stack || err);
    return fail_('ระบบขัดข้องชั่วคราว ลองส่งใหม่อีกครั้งนะคะ', true);
  }
}

/* ───────── ส่งงาน ───────── */

function submit_(req, token) {
  var assignmentId = String(req.assignmentId || '');
  if (!UUID_RE.test(assignmentId)) throw thai_('ข้อมูลงานไม่ถูกต้อง ลองโหลดหน้าใหม่ค่ะ');

  var mime = String(req.mime || '');
  var ext = ALLOWED[mime];
  if (!ext) throw thai_('ส่งได้เฉพาะไฟล์ PDF, JPG หรือ PNG เท่านั้นค่ะ');

  if (typeof req.data !== 'string' || !req.data) throw thai_('ไม่พบไฟล์ที่ส่งมา ลองเลือกไฟล์ใหม่ค่ะ');
  var bytes = Utilities.base64Decode(req.data);
  if (bytes.length < 1 || bytes.length > MAX_BYTES) throw thai_('ไฟล์ต้องมีขนาดไม่เกิน 10 MB ค่ะ');
  if (!magicOk_(bytes, mime)) throw thai_('ไฟล์ไม่ตรงกับชนิดที่เลือก (ต้องเป็น PDF, JPG หรือ PNG จริง) ค่ะ');

  // 1) ถามฐานข้อมูลก่อนว่าคนนี้ส่งงานนี้ได้ไหม
  var ctx = rpc_('drive_submit_context', { p_assignment_id: assignmentId }, token);

  // 2) หา/สร้างโฟลเดอร์ แล้วเก็บไฟล์
  var folder = studentFolder_(assignmentId, ctx);
  var safeTitle = safe_(ctx.assignment_title).substring(0, 40);
  var fileName = safe_(ctx.student_code) + '_' + safeTitle + '.' + ext;
  var file = folder.createFile(Utilities.newBlob(bytes, mime, fileName));

  // 3) บันทึกลงฐานข้อมูล (ถ้าไม่สำเร็จ ลบไฟล์ที่เพิ่งสร้างทิ้ง กันไฟล์ค้าง)
  var rec;
  try {
    rec = rpc_('drive_submit_record', {
      p_assignment_id: assignmentId,
      p_drive_file_id: file.getId(),
      p_file_name: String(req.fileName || fileName).substring(0, 200),
      p_mime: mime,
      p_size: bytes.length,
      p_note: req.note ? String(req.note).substring(0, 500) : null
    }, token);
  } catch (err) {
    try { file.setTrashed(true); } catch (ignore) {}
    throw err;
  }

  // 4) ส่งใหม่ = ไฟล์เก่าลงถังขยะ (กู้คืนได้ 30 วัน)
  if (rec.old_drive_file_id && rec.old_drive_file_id !== file.getId()) {
    try { DriveApp.getFileById(rec.old_drive_file_id).setTrashed(true); } catch (ignore) {}
  }
  return { ok: true };
}

/* ───────── ครูเปิดดูไฟล์ ───────── */

function get_(req, token) {
  var sid = String(req.submissionId || '');
  if (!UUID_RE.test(sid)) throw thai_('ข้อมูลไม่ถูกต้องค่ะ');
  var info = rpc_('drive_view_check', { p_submission_id: sid }, token);
  var blob;
  try {
    blob = DriveApp.getFileById(info.drive_file_id).getBlob();
  } catch (err) {
    throw thai_('ไม่พบไฟล์ใน Drive (อาจถูกลบไปแล้ว) ค่ะ');
  }
  return {
    ok: true,
    name: info.file_name || 'งานนักเรียน',
    mime: info.mime || blob.getContentType(),
    data: Utilities.base64Encode(blob.getBytes())
  };
}

/* ───────── โฟลเดอร์ ───────── */

function rootFolder_() {
  var props = PropertiesService.getScriptProperties();
  var id = props.getProperty('ROOT_FOLDER_ID');
  if (id) {
    try { return DriveApp.getFolderById(id); } catch (ignore) {}
  }
  var f = DriveApp.createFolder(ROOT_FOLDER_NAME);
  props.setProperty('ROOT_FOLDER_ID', f.getId());
  return f;
}

function childFolder_(parent, name) {
  var it = parent.getFoldersByName(name);
  return it.hasNext() ? it.next() : parent.createFolder(name);
}

// โฟลเดอร์: หลัก / ชื่องาน [รหัสงานสั้น] / ห้อง / รหัสนักเรียน
// ใช้ cache + lock กันโฟลเดอร์ซ้ำตอนนักเรียนทั้งห้องส่งพร้อมกัน
function studentFolder_(assignmentId, ctx) {
  var room = safe_(ctx.class_room).replace(/\//g, '-');
  var code = safe_(ctx.student_code);
  var key = 'f:' + assignmentId + ':' + room + ':' + code;
  var cache = CacheService.getScriptCache();
  var hit = cache.get(key);
  if (hit) {
    try { return DriveApp.getFolderById(hit); } catch (ignore) {}
  }
  var lock = LockService.getScriptLock();
  lock.waitLock(25000);
  try {
    var title = safe_(ctx.assignment_title).substring(0, 60) + ' [' + assignmentId.substring(0, 6) + ']';
    var f = childFolder_(childFolder_(childFolder_(rootFolder_(), title), room), code);
    cache.put(key, f.getId(), 21600);
    return f;
  } finally {
    lock.releaseLock();
  }
}

/* ───────── ตัวช่วย ───────── */

function rpc_(name, args, token) {
  var res = UrlFetchApp.fetch(SUPABASE_URL + '/rest/v1/rpc/' + name, {
    method: 'post',
    contentType: 'application/json',
    headers: { apikey: ANON_KEY, Authorization: 'Bearer ' + token },
    payload: JSON.stringify(args),
    muteHttpExceptions: true
  });
  var code = res.getResponseCode();
  var body = res.getContentText();
  if (code === 200) return JSON.parse(body);
  if (code === 401) throw thai_('เซสชันหมดอายุแล้ว กรุณาโหลดหน้าใหม่แล้วเข้าสู่ระบบอีกครั้งค่ะ');
  var msg = '';
  try { msg = JSON.parse(body).message || ''; } catch (ignore) {}
  // ข้อความภาษาไทยที่ฐานข้อมูลตั้งใจส่งมา (raise exception) แสดงให้ผู้ใช้ได้
  if (code === 400 && /[฀-๿]/.test(msg)) throw thai_(msg);
  throw new Error('rpc ' + name + ' ' + code + ' ' + body.substring(0, 200));
}

function magicOk_(b, mime) {
  function u(i) { return b[i] & 255; }
  if (mime === 'application/pdf') return u(0) === 0x25 && u(1) === 0x50 && u(2) === 0x44 && u(3) === 0x46;
  if (mime === 'image/jpeg') return u(0) === 0xFF && u(1) === 0xD8 && u(2) === 0xFF;
  if (mime === 'image/png') return u(0) === 0x89 && u(1) === 0x50 && u(2) === 0x4E && u(3) === 0x47;
  return false;
}

function safe_(s) {
  var t = String(s == null ? '' : s).replace(/[\\/:*?"<>|\r\n\t]/g, '-').replace(/\s+/g, ' ').trim();
  return t || 'ไม่ระบุ';
}

function thai_(m) { return new Error('Thai:' + m); }

function out_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
}

function fail_(message, busy) {
  return out_({ ok: false, error: message, busy: !!busy });
}

/* ───────── รันครั้งเดียวตอนติดตั้ง ───────── */

// กด Run ที่ฟังก์ชันนี้ 1 ครั้งหลังวางโค้ด เพื่ออนุญาตสิทธิ์ Drive และสร้างโฟลเดอร์หลัก
function setupOnce() {
  var f = rootFolder_();
  Logger.log('โฟลเดอร์หลัก: ' + f.getUrl());
  UrlFetchApp.fetch(SUPABASE_URL + '/rest/v1/', { headers: { apikey: ANON_KEY }, muteHttpExceptions: true });
}
