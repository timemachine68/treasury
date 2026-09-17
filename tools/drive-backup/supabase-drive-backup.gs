/**
 * สำรองไฟล์จาก Supabase Storage ไป Google Drive — คลังแนะแนว
 *
 * สคริปต์นี้ "คัดลอก" ไฟล์ออกมาเก็บไว้เฉยๆ ไม่ได้แตะระบบอัปโหลดหรือฐานข้อมูลของเว็บเลย
 * ถ้าสคริปต์พังหรือหยุดทำงาน เว็บยังใช้งานได้ปกติทุกอย่าง
 *
 * วิธีติดตั้ง: อ่าน README.md ในโฟลเดอร์เดียวกัน
 */

// ─────────────────────────────────────────────────────────────
// ฟังก์ชันหลัก — ตัวที่ตั้งเวลาให้รันอัตโนมัติทุกคืน
// ─────────────────────────────────────────────────────────────
function backupNow() {
  const cfg = getConfig_();
  const startedAt = Date.now();
  const root = getBackupRoot_(cfg);
  const manifest = readManifest_(root);

  const buckets = listBuckets_(cfg);
  Logger.log('เจอ bucket ทั้งหมด %s อัน: %s', buckets.length, buckets.join(', '));

  let copied = 0, skipped = 0, bytes = 0, ranOutOfTime = false;

  for (const bucket of buckets) {
    if (ranOutOfTime) break;

    const files = listBucketFiles_(cfg, bucket, '', []);
    Logger.log('[%s] มีไฟล์ %s รายการ', bucket, files.length);

    for (const file of files) {
      // กันโดน Apps Script ตัดกลางคัน: พอใกล้หมดเวลาให้หยุดสวยๆ แล้วไปต่อรอบหน้า
      if (Date.now() - startedAt > cfg.budgetMs) {
        ranOutOfTime = true;
        Logger.log('ใกล้หมดเวลาที่กำหนดไว้ หยุดไว้ก่อน เดี๋ยวรอบหน้าทำต่อจากตรงนี้');
        break;
      }

      const key = bucket + '/' + file.path;
      if (manifest[key] === file.updated) { skipped++; continue; }

      try {
        const saved = copyToDrive_(cfg, root, bucket, file);
        manifest[key] = file.updated;
        copied++;
        bytes += saved;
      } catch (err) {
        // Drive เต็มคือเหตุผลเดียวที่ควรหยุดทั้งรอบ — อย่างอื่นข้ามไฟล์นั้นแล้วไปต่อ
        if (isQuotaError_(err)) {
          saveManifest_(root, manifest);
          throw new Error('พื้นที่ Google Drive เต็ม สำรองต่อไม่ได้ค่ะ — ' +
            'กรุณาเคลียร์พื้นที่ใน Drive แล้วสคริปต์จะทำต่อเองรอบถัดไป (' + err.message + ')');
        }
        Logger.log('ข้ามไฟล์ %s เพราะ error: %s', key, err.message);
      }

      // เซฟความคืบหน้าเป็นระยะ เผื่อสคริปต์ถูกตัดกลางคันจะได้ไม่ต้องเริ่มใหม่หมด
      if (copied % 25 === 0) saveManifest_(root, manifest);
    }
  }

  saveManifest_(root, manifest);
  Logger.log('เสร็จรอบนี้: คัดลอกใหม่ %s ไฟล์ (%s MB) · ข้ามเพราะสำรองไว้แล้ว %s ไฟล์%s',
    copied, (bytes / 1048576).toFixed(1), skipped,
    ranOutOfTime ? ' · ยังไม่ครบ เดี๋ยวรอบหน้าทำต่อ' : '');
}

// ─────────────────────────────────────────────────────────────
// ตั้งค่า — เก็บใน Script Properties ไม่ใส่ในโค้ด เพราะ service_role key เป็นกุญแจหลัก
// ─────────────────────────────────────────────────────────────
function getConfig_() {
  const p = PropertiesService.getScriptProperties();
  const url = p.getProperty('SUPABASE_URL');
  const key = p.getProperty('SERVICE_ROLE_KEY');
  if (!url || !key) {
    throw new Error('ยังไม่ได้ตั้งค่า SUPABASE_URL กับ SERVICE_ROLE_KEY ใน Script Properties ค่ะ (ดูวิธีใน README)');
  }
  return {
    url: url.replace(/\/+$/, ''),
    key: key,
    folderId: p.getProperty('DRIVE_FOLDER_ID') || '',
    // Apps Script ตัดการทำงานที่ 6 นาที (บัญชีทั่วไป) หรือ 30 นาที (Workspace)
    // ตั้งงบเวลาไว้ต่ำกว่านั้นเพื่อให้เซฟ manifest ทันก่อนโดนตัด
    budgetMs: Number(p.getProperty('BUDGET_MINUTES') || 4.5) * 60 * 1000,
    skipBuckets: (p.getProperty('SKIP_BUCKETS') || '').split(',').map(s => s.trim()).filter(Boolean)
  };
}

// ─────────────────────────────────────────────────────────────
// คุยกับ Supabase
// ─────────────────────────────────────────────────────────────
function sbRequest_(cfg, path, options) {
  const opt = options || {};
  const res = UrlFetchApp.fetch(cfg.url + path, {
    method: opt.method || 'get',
    contentType: opt.body ? 'application/json' : undefined,
    payload: opt.body ? JSON.stringify(opt.body) : undefined,
    headers: { Authorization: 'Bearer ' + cfg.key, apikey: cfg.key },
    muteHttpExceptions: true
  });
  const code = res.getResponseCode();
  if (code < 200 || code >= 300) {
    throw new Error('Supabase ตอบ ' + code + ' ที่ ' + path + ': ' + res.getContentText().slice(0, 300));
  }
  return res;
}

function listBuckets_(cfg) {
  const all = JSON.parse(sbRequest_(cfg, '/storage/v1/bucket').getContentText());
  return all.map(b => b.name).filter(name => cfg.skipBuckets.indexOf(name) === -1);
}

/**
 * ไล่เก็บรายชื่อไฟล์ทั้ง bucket
 * API ของ Supabase คืนมาทีละชั้นโฟลเดอร์ — รายการที่ id เป็น null คือโฟลเดอร์ ต้องไล่ลงไปข้างในเอง
 */
function listBucketFiles_(cfg, bucket, prefix, out) {
  const LIMIT = 100;
  let offset = 0;

  while (true) {
    const page = JSON.parse(sbRequest_(cfg, '/storage/v1/object/list/' + encodeURIComponent(bucket), {
      method: 'post',
      body: { prefix: prefix, limit: LIMIT, offset: offset, sortBy: { column: 'name', order: 'asc' } }
    }).getContentText());

    if (!page.length) break;

    for (const entry of page) {
      const full = prefix ? prefix + '/' + entry.name : entry.name;
      if (entry.id === null || entry.id === undefined) {
        listBucketFiles_(cfg, bucket, full, out);
      } else if (entry.name !== '.emptyFolderPlaceholder') {
        out.push({
          path: full,
          size: Number((entry.metadata || {}).size || 0),
          // ใช้เทียบว่าไฟล์ถูกแก้ไขหลังสำรองครั้งล่าสุดไหม (เช่น รูปโปรไฟล์ที่อัปทับ)
          updated: entry.updated_at || entry.created_at || ''
        });
      }
    }

    if (page.length < LIMIT) break;
    offset += LIMIT;
  }
  return out;
}

function downloadFile_(cfg, bucket, path) {
  const encoded = path.split('/').map(encodeURIComponent).join('/');
  return sbRequest_(cfg, '/storage/v1/object/authenticated/' + encodeURIComponent(bucket) + '/' + encoded).getBlob();
}

// ─────────────────────────────────────────────────────────────
// ฝั่ง Google Drive
// ─────────────────────────────────────────────────────────────
function getBackupRoot_(cfg) {
  if (cfg.folderId) return DriveApp.getFolderById(cfg.folderId);
  return ensureFolder_(DriveApp.getRootFolder(), 'คลังแนะแนว-สำรองไฟล์');
}

function ensureFolder_(parent, name) {
  const it = parent.getFoldersByName(name);
  return it.hasNext() ? it.next() : parent.createFolder(name);
}

/**
 * คัดลอกไฟล์ลง Drive โดยจำลองโครงสร้างโฟลเดอร์เหมือนใน Supabase (bucket/รหัสผู้ใช้/ชื่อไฟล์)
 * เพื่อให้คนเปิดดูเองแล้วหาเจอ ไม่ใช่กองรวมกันมั่วๆ
 */
function copyToDrive_(cfg, root, bucket, file) {
  const parts = file.path.split('/');
  const fileName = parts.pop();

  let folder = ensureFolder_(root, bucket);
  for (const part of parts) folder = ensureFolder_(folder, part);

  // เช็คซ้ำจากตัวโฟลเดอร์จริงด้วย ไม่ใช่เชื่อ manifest อย่างเดียว —
  // เผื่อรอบก่อนถูกตัดกลางคันจนเซฟ manifest ไม่ทัน จะได้ไม่เกิดไฟล์ซ้ำ
  const existing = folder.getFilesByName(fileName);
  while (existing.hasNext()) existing.next().setTrashed(true);

  const blob = downloadFile_(cfg, bucket, file.path);
  folder.createFile(blob.setName(fileName));
  return file.size;
}

function isQuotaError_(err) {
  const m = (err && err.message ? err.message : '').toLowerCase();
  return m.indexOf('quota') !== -1 || m.indexOf('storage') !== -1 || m.indexOf('space') !== -1;
}

// ─────────────────────────────────────────────────────────────
// manifest = บันทึกว่าสำรองอะไรไปแล้วบ้าง เก็บเป็นไฟล์ใน Drive
// (Script Properties เก็บได้แค่ 9KB ต่อค่า ไม่พอกับไฟล์หลักพัน)
// ─────────────────────────────────────────────────────────────
const MANIFEST_NAME = '_manifest.json';

function readManifest_(root) {
  const it = root.getFilesByName(MANIFEST_NAME);
  if (!it.hasNext()) return {};
  try {
    return JSON.parse(it.next().getBlob().getDataAsString()) || {};
  } catch (err) {
    Logger.log('อ่าน manifest เดิมไม่ได้ (%s) เริ่มนับใหม่ — ไฟล์ที่มีอยู่แล้วใน Drive จะไม่ซ้ำเพราะเช็คจากโฟลเดอร์จริงอีกชั้น', err.message);
    return {};
  }
}

function saveManifest_(root, manifest) {
  const body = JSON.stringify(manifest);
  const it = root.getFilesByName(MANIFEST_NAME);
  if (it.hasNext()) it.next().setContent(body);
  else root.createFile(MANIFEST_NAME, body, MimeType.PLAIN_TEXT);
}

// ─────────────────────────────────────────────────────────────
// ตัวช่วยตอนติดตั้ง — รันมือครั้งเดียว
// ─────────────────────────────────────────────────────────────

/** ตรวจว่าตั้งค่าถูกไหม ต่อ Supabase ติดไหม โดยยังไม่คัดลอกอะไรเลย */
function testConnection() {
  const cfg = getConfig_();
  const buckets = listBuckets_(cfg);
  Logger.log('ต่อ Supabase สำเร็จ ✅ เจอ bucket: %s', buckets.join(', ') || '(ไม่มี)');

  let total = 0;
  for (const b of buckets) {
    const files = listBucketFiles_(cfg, b, '', []);
    const mb = files.reduce((s, f) => s + f.size, 0) / 1048576;
    total += mb;
    Logger.log('  • %s: %s ไฟล์ (%s MB)', b, files.length, mb.toFixed(1));
  }
  Logger.log('รวมทั้งหมด %s MB', total.toFixed(1));
  Logger.log('โฟลเดอร์ปลายทางใน Drive: %s', getBackupRoot_(cfg).getName());
}

/** ตั้งเวลาให้รันอัตโนมัติทุกคืนตี 2 (ลบ trigger เดิมของสคริปต์นี้ก่อน กันซ้อนกัน) */
function installNightlyTrigger() {
  ScriptApp.getProjectTriggers()
    .filter(t => t.getHandlerFunction() === 'backupNow')
    .forEach(t => ScriptApp.deleteTrigger(t));

  ScriptApp.newTrigger('backupNow').timeBased().atHour(2).everyDays(1).create();
  Logger.log('ตั้งเวลาเรียบร้อย จะรันทุกคืนประมาณตี 2 ค่ะ');
}
