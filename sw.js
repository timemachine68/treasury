/* Service worker ของ "แนะให้แนว"
 * หลักการ: ข้อมูลนักเรียนอยู่ที่ Supabase (คนละโดเมน) — ไม่แคชเด็ดขาด ปล่อยผ่านทุกคำขอข้ามโดเมน
 * - หน้า HTML: ลองเน็ตก่อนเสมอ (ได้หน้าใหม่ล่าสุดทุกครั้งที่อัปโหลดแทนที่) ถ้าเน็ตหลุดจึงแสดงหน้า "ไม่มีอินเทอร์เน็ต"
 * - ไอคอน/manifest: แคชไว้ใช้ซ้ำ
 * เปลี่ยน VERSION เมื่อแก้ไฟล์นี้หรือเปลี่ยนไอคอน
 */
const VERSION = 'pcw-v1';
const SHELL = ['offline.html', 'icons/icon-192.png', 'icons/icon-512.png', 'icons/apple-touch-icon.png', 'manifest.webmanifest'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(VERSION).then(c => c.addAll(SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys => Promise.all(keys.filter(k => k !== VERSION).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;          // Supabase, ฟอนต์, CDN: ไม่ยุ่ง

  if (req.mode === 'navigate') {                            // หน้าเว็บ: เน็ตก่อน
    e.respondWith(fetch(req).catch(() => caches.match('offline.html')));
    return;
  }
  if (url.pathname.includes('/icons/') || url.pathname.endsWith('manifest.webmanifest')) {
    e.respondWith(caches.match(req).then(hit => hit || fetch(req)));
  }
  // ไฟล์อื่นของเว็บ (js/csv ฯลฯ): ปล่อยให้เบราว์เซอร์จัดการตามปกติ
});
