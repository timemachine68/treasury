/* การ์ดแสดงความยินดี 2 แบบ: "บัตรขึ้นเครื่อง" (ค่าเริ่มต้น) และ "ไฟนีออน" · สีตามมหาวิทยาลัยจริง — ใช้ร่วมกันระหว่าง survey.html (นักเรียน) และ congrats-cards.html (ครู)
   วาดลง <canvas> ในเครื่องผู้ใช้ ไม่เก็บไฟล์การ์ดไว้ที่ไหน · ตราประทับเขียนแค่ "ผ่านแล้ว" (ครูสั่ง 31 ต.ค. 2569) */
(function(){
'use strict';
var __UNI=[
 ['พระจอมเกล้าธนบุรี','#FA4616','KMUTT'],['พระจอมเกล้าเจ้าคุณทหารลาดกระบัง','#E35205','KMITL'],['พระจอมเกล้าพระนครเหนือ','#AC3520','KMUTNB'],
 ['จุฬาลงกรณ์','#DE5C8E','CU'],['เกษตรศาสตร์','#006664','KU'],['มหิดล','#0035AD','MU'],
 ['ธรรมศาสตร์','#C3002F','TU'],['ศิลปากร','#007A6D','SU'],['เชียงใหม่','#9E76B4','CMU'],
 ['ขอนแก่น','#A73B24','KKU'],['สงขลานครินทร์','#003C71','PSU'],['บูรพา','#FFCE00','BUU'],
 ['รามคำแหง','#1E3F8A','RU'],['ศรีนครินทรวิโรฒ','#DA2128','SWU'],['นเรศวร','#E0582A','NU'],
 ['มหาสารคาม','#E6A100','MSU'],['ทักษิณ','#358CCB','TSU'],['สุรนารี','#E4572E','SUT'],
 ['แม่ฟ้าหลวง','#A6192E','MFU'],['พะเยา','#6A3A95','UP'],['วลัยลักษณ์','#F37321','WU'],
 ['แม่โจ้','#00843D','MJU'],['อุบลราชธานี','#1B3F8B','UBU'],['นครพนม','#D4A017','NPU'],
 ['ราชมงคลธัญบุรี','#0B3B8C','RMUTT'],['ราชมงคลกรุงเทพ','','RMUTK'],['ราชมงคลพระนคร','','RMUTP'],
 ['ราชมงคลตะวันออก','','RMUTTO'],['ราชมงคลสุวรรณภูมิ','','RMUTSB'],['ราชมงคลรัตนโกสินทร์','','RMUTR'],
 ['สวนสุนันทา','#1E3A8A','SSRU'],['ราชภัฏธนบุรี','','DRU'],['ราชภัฏพระนคร','','PNRU'],
 ['จันทรเกษม','','CRU'],['บ้านสมเด็จเจ้าพระยา','','BSRU'],['ราชนครินทร์','','RNRU'],
 ['สุโขทัยธรรมาธิราช','','STOU'],['หัวเฉียว','#C79A2E','HCU'],['รังสิต','','RSU'],
 ['มหาวิทยาลัยกรุงเทพ','','BU'],['หอการค้า','','UTCC'],['ศรีปทุม','','SPU'],
 ['เกริก','','KRU'],['ธุรกิจบัณฑิตย์','#5B2C83','DPU'],['เอเชียอาคเนย์','','SAU'],
 ['มหาวิทยาลัยสยาม','','SIAM'],['อัสสัมชัญ','','ABAC'],['เทคโนโลยีมหานคร','','MUT'],
 ['เนชั่น','','NTU'],['ปทุมวัน','','PIT'],['การบินพลเรือน','','CATC'],
 ['บัณฑิตพัฒนศิลป์','','BPI'],['นวมินทราธิราช','#0B5D1E','NMU'],['การกีฬาแห่งชาติ','','TNSU'],
 ['พระบรมราชชนก','','PI'],['บรมราชชนนี','','BCN'],['ไทย-ญี่ปุ่น','#1F4E9C','TNI']
];
  var F_H = "'Chonburi', serif", F_B = "'Sarabun', sans-serif";
  var GOLD = '#e9c46a', PAPER = '#fbf6e9', DEFAULT_U = '#27478a';

  // สีตัวอย่างของมหาวิทยาลัย (ครูปรับเองได้ในฟอร์ม) — ตอนใช้จริงเก็บไว้ในตารางข้อมูล
  var UNI_COLORS = __UNI;

  // arch = ซุ้มประตู, full = ภาพเต็มใบ
  var ARCH = {
    '4:5':  { H: 1350, aw: 700, ah: 700, at: 100, head: 150, nameS: 62, nameY: 938, clsY: 984, rbY: 1026, sc: 1 },
    '1:1':  { H: 1080, aw: 500, ah: 500, at: 80,  head: 104, nameS: 50, nameY: 716, clsY: 756, rbY: 790,  sc: 0.78 },
    '9:16': { H: 1920, aw: 780, ah: 880, at: 150, head: 168, nameS: 70, nameY: 1176, clsY: 1226, rbY: 1272, sc: 1.12 }
  };
  var FULL = { '4:5': { H: 1350, sc: 1 }, '1:1': { H: 1080, sc: 0.78 }, '9:16': { H: 1920, sc: 1.18 } };


  function copy(o) { var r = {}, k; for (k in o) { r[k] = o[k]; } return r; }

  // ---------- สี ----------
  function rgb(h) { h = h.replace('#', ''); return [parseInt(h.substr(0, 2), 16), parseInt(h.substr(2, 2), 16), parseInt(h.substr(4, 2), 16)]; }
  function shade(h, t, to, al) {
    var a = rgb(h), b = (to === 'w') ? [255, 255, 255] : [0, 0, 0];
    return 'rgba(' + a.map(function (v, i) { return Math.round(v + (b[i] - v) * t); }).join(',') + ',' + (al === undefined ? 1 : al) + ')';
  }
  function uniColor(inst) {
    var i; for (i = 0; i < UNI_COLORS.length; i++) { if (inst && inst.indexOf(UNI_COLORS[i][0]) > -1 && UNI_COLORS[i][1]) { return UNI_COLORS[i][1]; } }
    return null;
  }
  // ชื่อบนการ์ด: ใส่วิทยาเขตต่อท้ายถ้ามี (วิทยาลัยพยาบาลบรมราชชนนีใช้ชื่อจังหวัดต่อท้ายเลย)
  function uniText(d) {
    var cp = d.campus ? String(d.campus).trim() : '';
    if (!cp) { return d.inst; }
    return d.inst + (String(d.inst).indexOf('บรมราชชนนี') > -1 ? ' ' : ' วิทยาเขต') + cp;
  }
  function effColor(d) { return d.color || uniColor(d.inst) || DEFAULT_U; }
  function theme(d) {
    var u = effColor(d);
    return {
      u: u,
      deep: shade(u, 0.66, 'k'), mid: shade(u, 0.46, 'k'), glow: shade(u, 0.1, 'w'),
      ink: shade(u, 0.84, 'k'), tint: shade(u, 0.78, 'w'), tint2: shade(u, 0.55, 'w'),
      deepA: function (al) { return shade(u, 0.66, 'k', al); }
    };
  }

  // ---------- ตัวช่วย ----------
  function seedOf(s) { var h = 2166136261, i; s = String(s); for (i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); } return h >>> 0; }
  function rng(seed) { var a = seed >>> 0; return function () { a = (a + 0x6D2B79F5) | 0; var t = Math.imul(a ^ (a >>> 15), 1 | a); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }
  function wrapLines(c, text, maxW) {
    var parts;
    if (typeof Intl !== 'undefined' && Intl.Segmenter) {
      parts = Array.from(new Intl.Segmenter('th', { granularity: 'word' }).segment(text), function (s) { return s.segment; });
    } else { parts = Array.from(text); }
    var lines = [], line = '', i, t;
    for (i = 0; i < parts.length; i++) {
      t = line + parts[i];
      if (c.measureText(t).width > maxW && line) { lines.push(line.trim()); line = parts[i].replace(/^\s+/, ''); } else { line = t; }
    }
    if (line.trim()) { lines.push(line.trim()); }
    return lines;
  }
  function fitOne(c, text, maxW, size, minSize, weight) {
    for (var s = Math.round(size); s >= minSize; s -= 2) {
      c.font = weight + ' ' + s + 'px ' + F_B;
      if (c.measureText(text).width <= maxW) { return { lines: [text], size: s }; }
    }
    return null;
  }
  function fitWrap(c, text, maxW, size, minSize, weight, maxLines) {
    var s, L;
    for (s = Math.round(size); s >= minSize; s -= 2) {
      c.font = weight + ' ' + s + 'px ' + F_B;
      L = wrapLines(c, text, maxW);
      if (L.length <= maxLines) { return { lines: L, size: s }; }
    }
    c.font = weight + ' ' + minSize + 'px ' + F_B;
    L = wrapLines(c, text, maxW).slice(0, maxLines);
    L[L.length - 1] = L[L.length - 1].replace(/.$/, '…');
    return { lines: L, size: minSize };
  }
  function firstLetter(name) { var m = String(name || '').match(/[ก-ฮA-Za-z]/); return m ? m[0] : '★'; }

  var grainTile = null;
  function grain(c, W, H) {
    if (!grainTile) {
      var t = document.createElement('canvas'); t.width = t.height = 180;
      var tc = t.getContext('2d'), im = tc.createImageData(180, 180), i, v;
      for (i = 0; i < im.data.length; i += 4) { v = Math.random() * 255; im.data[i] = im.data[i + 1] = im.data[i + 2] = v; im.data[i + 3] = 255; }
      tc.putImageData(im, 0, 0); grainTile = t;
    }
    c.save(); c.globalAlpha = 0.11; c.globalCompositeOperation = 'overlay';
    c.fillStyle = c.createPattern(grainTile, 'repeat'); c.fillRect(0, 0, W, H); c.restore();
  }
  function lattice(c, W, H, col, step) {
    c.strokeStyle = col; c.lineWidth = 1.5; c.beginPath();
    for (var k = -H; k < W + H; k += step) { c.moveTo(k, 0); c.lineTo(k + H, H); c.moveTo(k, H); c.lineTo(k + H, 0); }
    c.stroke();
  }
  function sparkle(c, x, y, r, col) {
    c.fillStyle = col; c.beginPath(); c.moveTo(x, y - r);
    c.quadraticCurveTo(x, y, x + r, y); c.quadraticCurveTo(x, y, x, y + r);
    c.quadraticCurveTo(x, y, x - r, y); c.quadraticCurveTo(x, y, x, y - r); c.fill();
  }
  function goldGrad(c, y0, y1) {
    var g = c.createLinearGradient(0, y0, 0, y1); g.addColorStop(0, '#f8e7ad'); g.addColorStop(0.55, '#e9c46a'); g.addColorStop(1, '#c99a38'); return g;
  }

  // ซุ้มโค้งทรงไทย (ยอดแหลม ไหล่โค้งนูน)
  function archPath(c, cx, top, w, h, grow, open) {
    var hw = w / 2 + grow, t = top - grow * 1.1, bot = top + h, H2 = bot - t;
    function X(u) { return cx + u * hw; }
    function Y(v) { return t + v * H2; }
    c.beginPath();
    c.moveTo(X(-1), bot); c.lineTo(X(-1), Y(0.36));
    c.bezierCurveTo(X(-1), Y(0.24), X(-0.70), Y(0.21), X(-0.52), Y(0.15));
    c.bezierCurveTo(X(-0.34), Y(0.09), X(-0.07), Y(0.07), X(0), Y(0));
    c.bezierCurveTo(X(0.07), Y(0.07), X(0.34), Y(0.09), X(0.52), Y(0.15));
    c.bezierCurveTo(X(0.70), Y(0.21), X(1), Y(0.24), X(1), Y(0.36));
    c.lineTo(X(1), bot);
    if (!open) { c.closePath(); }
  }
  function ribbon(c, cx, y, w, h, notch) {
    var x = cx - w / 2;
    c.beginPath(); c.moveTo(x, y); c.lineTo(x + w, y); c.lineTo(x + w - notch, y + h / 2); c.lineTo(x + w, y + h);
    c.lineTo(x, y + h); c.lineTo(x + notch, y + h / 2); c.closePath();
  }
  function pillPath(c, x, y, w, h) {
    var r = h / 2; c.beginPath(); c.moveTo(x + r, y); c.lineTo(x + w - r, y); c.arc(x + w - r, y + r, r, -Math.PI / 2, Math.PI / 2);
    c.lineTo(x + r, y + h); c.arc(x + r, y + r, r, Math.PI / 2, -Math.PI / 2); c.closePath();
  }

  // รูปตัวอย่าง: นักเรียนชุดนักเรียน (ภาพวาดไม่มีหน้า)
  function drawStudent(c, x, y, w, h, T) {
    var cx = x + w / 2, hr = Math.min(w, h * 0.9) * 0.2, hy = y + h * 0.44, ys = hy + hr * 1.55, sw = Math.min(w * 0.46, hr * 3.1), ry = hr * 0.95;
    var bg = c.createLinearGradient(0, y, 0, y + h); bg.addColorStop(0, T.tint); bg.addColorStop(1, T.tint2);
    c.fillStyle = bg; c.fillRect(x, y, w, h);
    c.fillStyle = 'rgba(255,255,255,0.28)';
    [[0.2, 0.25, 0.14], [0.82, 0.18, 0.1], [0.74, 0.55, 0.16], [0.14, 0.62, 0.1]].forEach(function (b) { c.beginPath(); c.arc(x + w * b[0], y + h * b[1], Math.min(w, h) * b[2], 0, 6.2832); c.fill(); });
    c.fillStyle = '#f6f5f1'; c.beginPath(); c.ellipse(cx, ys + ry, sw, ry, 0, Math.PI, 2 * Math.PI); c.fill();
    c.fillRect(cx - sw, ys + ry, 2 * sw, y + h - (ys + ry));
    c.fillStyle = '#d9a384'; c.fillRect(cx - hr * 0.34, hy + hr * 0.7, hr * 0.68, ys - (hy + hr * 0.7) + hr * 0.3);
    c.fillStyle = '#e9bd9e'; c.beginPath(); c.moveTo(cx - hr * 0.62, ys); c.lineTo(cx + hr * 0.62, ys); c.lineTo(cx, ys + ry * 0.95); c.closePath(); c.fill();
    c.fillStyle = '#dcdcd6';
    c.beginPath(); c.moveTo(cx - hr * 0.7, ys - 4); c.lineTo(cx - 2, ys + ry * 1.0); c.lineTo(cx - hr * 1.1, ys + ry * 0.7); c.closePath(); c.fill();
    c.beginPath(); c.moveTo(cx + hr * 0.7, ys - 4); c.lineTo(cx + 2, ys + ry * 1.0); c.lineTo(cx + hr * 1.1, ys + ry * 0.7); c.closePath(); c.fill();
    c.fillStyle = '#2b211e'; c.beginPath(); c.ellipse(cx, hy - hr * 0.08, hr * 1.12, hr * 1.2, 0, 0, 6.2832); c.fill();
    c.fillStyle = '#e0ae8d'; c.beginPath(); c.ellipse(cx - hr * 0.92, hy + hr * 0.08, hr * 0.14, hr * 0.22, 0, 0, 6.2832); c.fill();
    c.beginPath(); c.ellipse(cx + hr * 0.92, hy + hr * 0.08, hr * 0.14, hr * 0.22, 0, 0, 6.2832); c.fill();
    c.fillStyle = '#ebc1a2'; c.beginPath(); c.ellipse(cx, hy + hr * 0.1, hr * 0.88, hr * 1.02, 0, 0, 6.2832); c.fill();
    c.fillStyle = '#2b211e'; c.beginPath(); c.ellipse(cx, hy - hr * 0.1, hr * 1.1, hr * 1.1, 0, Math.PI, 2 * Math.PI);
    c.quadraticCurveTo(cx + hr * 0.7, hy - hr * 0.5, cx + hr * 0.1, hy - hr * 0.42);
    c.quadraticCurveTo(cx - hr * 0.5, hy - hr * 0.3, cx - hr * 1.1, hy - hr * 0.1); c.closePath(); c.fill();
  }
  function drawCover(c, img, x, y, w, h, fy) {
    var sc = Math.max(w / img.width, h / img.height), iw = img.width * sc, ih = img.height * sc;
    c.drawImage(img, x + (w - iw) / 2, y - (ih - h) * fy, iw, ih);
  }
  // จัดกรอบตามใบหน้า (ค่าจาก card-photo-fx.js): หน้าสูง ~30% ของกรอบ อยู่กึ่งกลาง ห่างขอบบน ~36%
  function drawFaceFit(c, d, x, y, w, h) {
    var img = d.photo, f = d.photoFace, z = d.photoZoom || 1, IW = img.width, IH = img.height, bg = d.photoBg;
    var s = (h * 0.30 * z) / Math.max(1, f.h * IH), cover = Math.max(w / IW, h / IH);
    if (!bg && s < cover) { s = cover; }
    var iw = IW * s, ih = IH * s;
    var ix = x + w * (0.5 + (d.photoDx || 0)) - f.cx * iw;
    var iy = y + h * (0.36 + (d.photoDy || 0)) - f.cy * ih;
    if (iw >= w) { ix = Math.min(x, Math.max(x + w - iw, ix)); } else if (!bg) { ix = x + (w - iw) / 2; }
    if (bg) { iy = Math.max(iy, y + h - ih); c.fillStyle = bg; c.fillRect(x, y, w, h); }   // ตัวคนต้องยาวถึงขอบล่าง ไม่ลอย
    else if (ih >= h) { iy = Math.min(y, Math.max(y + h - ih, iy)); } else { iy = y + (h - ih) / 2; }
    c.drawImage(img, ix, iy, iw, ih);
  }
  function drawPhotoBlock(c, d, x, y, w, h, T, fy) {
    if (d.photo && d.photo !== 'sample' && d.photo.width && d.photoFace) { drawFaceFit(c, d, x, y, w, h); }
    else if (d.photo && d.photo !== 'sample' && d.photo.width) {
      if (d.photoBg) { c.fillStyle = d.photoBg; c.fillRect(x, y, w, h); }
      drawCover(c, d.photo, x, y, w, h, fy);
    }
    else if (d.photo === 'sample') { drawStudent(c, x, y, w, h, T); }
    else {
      var g = c.createLinearGradient(0, y, 0, y + h); g.addColorStop(0, T.mid); g.addColorStop(1, T.deep);
      c.fillStyle = g; c.fillRect(x, y, w, h);
      c.fillStyle = goldGrad(c, y, y + h); c.textAlign = 'center';
      c.font = '400 ' + Math.round(Math.min(w, h) * 0.5) + 'px ' + F_H;
      c.fillText(firstLetter(d.name), x + w / 2, y + h * 0.62);
    }
  }
  var NEW_H = { '4:5': 1350, '1:1': 1080, '9:16': 1920 };
  var NEW_SC = { '4:5': 1, '1:1': 0.78, '9:16': 1.14 };
  function setup(canvas, rat) { var W = 1080, H = NEW_H[rat]; canvas.width = W; canvas.height = H; return { c: canvas.getContext('2d'), W: W, H: H, sc: NEW_SC[rat] }; }
  function rr(c, x, y, w, h, r) {
    c.beginPath(); c.moveTo(x + r, y); c.arcTo(x + w, y, x + w, y + h, r); c.arcTo(x + w, y + h, x, y + h, r);
    c.arcTo(x, y + h, x, y, r); c.arcTo(x, y, x + w, y, r); c.closePath();
  }
  function fitBlock(c, text, maxW, size, minSize, weight, maxLines) {
    var one = fitOne(c, text, maxW, size, Math.max(minSize, Math.round(size * 0.74)), weight);
    return one || fitWrap(c, text, maxW, Math.round(size * 0.84), minSize, weight, maxLines);
  }
  function fitHead(c, text, maxW, size, minSize) {
    for (var s = Math.round(size); s >= minSize; s -= 2) { c.font = '400 ' + s + 'px ' + F_H; if (c.measureText(text).width <= maxW) { return { text: text, size: s }; } }
    c.font = '400 ' + minSize + 'px ' + F_H;
    var t = text; while (t.length > 1 && c.measureText(t + '…').width > maxW) { t = t.slice(0, -1); }
    return { text: t + '…', size: minSize };
  }
  function isLight(h) { var a = rgb(h); return (0.299 * a[0] + 0.587 * a[1] + 0.114 * a[2]) / 255 > 0.6; }
  function star(c, x, y, R, r, rot, col) {
    c.save(); c.translate(x, y); c.rotate(rot || 0); c.beginPath();
    for (var i = 0; i < 10; i++) { var rad = (i % 2 ? r : R), a = -Math.PI / 2 + i * Math.PI / 5; c.lineTo(Math.cos(a) * rad, Math.sin(a) * rad); }
    c.closePath(); c.fillStyle = col; c.fill(); c.restore();
  }
  function confetti(c, W, H, seed, cols, n, sc, skip) {
    var rnd = rng(seed), i, px, py, sz, kind;
    for (i = 0; i < n; i++) {
      px = rnd() * W; py = rnd() * H; sz = (8 + rnd() * 14) * sc; kind = rnd();
      if (skip && skip(px, py)) { rnd(); rnd(); continue; }
      c.save(); c.translate(px, py); c.rotate(rnd() * 6.28); c.fillStyle = cols[Math.floor(rnd() * cols.length)]; c.globalAlpha = 0.6 + rnd() * 0.35;
      if (kind < 0.5) { c.fillRect(-sz / 2, -sz / 4, sz, sz / 2); } else if (kind < 0.8) { c.beginPath(); c.arc(0, 0, sz / 3, 0, 6.2832); c.fill(); } else { sparkle(c, 0, 0, sz * 0.9, c.fillStyle); }
      c.restore();
    }
  }
  function dots(c, x0, y0, x1, y1, step, r, col) {
    c.fillStyle = col;
    for (var y = y0; y < y1; y += step) { for (var x = x0; x < x1; x += step) { c.beginPath(); c.arc(x, y, r, 0, 6.2832); c.fill(); } }
  }
  // ---------- ตัวช่วยของแบบใหม่ ----------
  var F_M = "'Mitr', sans-serif", F_S = "'Playfair Display', serif", F_T = "'Pacifico', cursive";
  function mixc(h, to, t) { var a = rgb(h), b = rgb(to); return 'rgb(' + [0, 1, 2].map(function (i) { return Math.round(a[i] + (b[i] - a[i]) * t); }).join(',') + ')'; }
  function rgbaU(h, al) { var a = rgb(h); return 'rgba(' + a[0] + ',' + a[1] + ',' + a[2] + ',' + al + ')'; }
  function lumOf(h) { var a = rgb(h); return (0.299 * a[0] + 0.587 * a[1] + 0.114 * a[2]) / 255; }
  function satOf(h) { var a = rgb(h), mx = Math.max(a[0], a[1], a[2]), mn = Math.min(a[0], a[1], a[2]); return mx ? (mx - mn) / mx : 0; }
  function uniCode(d) {
    if (d.code) { return d.code; }
    var i; for (i = 0; i < UNI_COLORS.length; i++) { if (d.inst && d.inst.indexOf(UNI_COLORS[i][0]) > -1 && UNI_COLORS[i][2]) { return UNI_COLORS[i][2]; } }
    return '';
  }
  // ใส่ข้อความ (ไทย/อังกฤษ) ให้พอดีกรอบด้วยฟอนต์ที่กำหนด
  function fitF(c, text, fam, weight, size, min, maxW, maxLines) {
    var s, L;
    for (s = Math.round(size); s >= min; s -= 2) {
      c.font = weight + ' ' + s + 'px ' + fam; L = wrapLines(c, String(text || ''), maxW);
      if (L.length <= maxLines && L.every(function (l) { return c.measureText(l).width <= maxW; })) { return { lines: L, size: s, font: c.font }; }
    }
    c.font = weight + ' ' + min + 'px ' + fam; L = wrapLines(c, String(text || ''), maxW).slice(0, maxLines);
    if (L.length) { while (L[L.length - 1].length > 1 && c.measureText(L[L.length - 1] + '…').width > maxW) { L[L.length - 1] = L[L.length - 1].slice(0, -1); } }
    return { lines: L, size: min, font: c.font };
  }
  function putLines(c, f, x, y, lh, align) { c.font = f.font; c.textAlign = align || 'left'; f.lines.forEach(function (l, i) { c.fillText(l, x, y + i * f.size * lh); }); return y + f.lines.length * f.size * lh; }
  function spaced(c, text, x, y, sp, align) {
    var ch = Array.from(String(text)), w = -sp; ch.forEach(function (k) { w += c.measureText(k).width + sp; });
    var sx = align === 'center' ? x - w / 2 : align === 'right' ? x - w : x; c.textAlign = 'left';
    ch.forEach(function (k) { c.fillText(k, sx, y); sx += c.measureText(k).width + sp; });
  }
  function foil(c, x0, y0, x1, y1) { var g = c.createLinearGradient(x0, y0, x1, y1); g.addColorStop(0, '#8A6215'); g.addColorStop(0.3, '#E8C25A'); g.addColorStop(0.5, '#FFF0B8'); g.addColorStop(0.7, '#D4A63C'); g.addColorStop(1, '#8A6215'); return g; }
  function plane(c, x, y, s, rot, col) {
    c.save(); c.translate(x, y); c.rotate(rot || 0); c.scale(s, s); c.fillStyle = col;
    c.beginPath(); c.moveTo(26, 0); c.lineTo(-18, -6); c.lineTo(-28, -6); c.lineTo(-22, 0); c.lineTo(-28, 6); c.lineTo(-18, 6); c.closePath(); c.fill();
    c.beginPath(); c.moveTo(6, 0); c.lineTo(-7, -24); c.lineTo(-15, -24); c.lineTo(-7, 0); c.lineTo(-15, 24); c.lineTo(-7, 24); c.closePath(); c.fill();
    c.restore();
  }
  // วางเนื้อการ์ด (ออกแบบที่ 1080×1350) ลงขนาดจริง: 1:1 ย่อลง, 9:16 วางกลางแล้วเติมหัว-ท้าย
  function stage(canvas, rat) {
    var S = setup(canvas, rat), k = S.H < 1350 ? S.H / 1350 : 1, oy = S.H > 1350 ? (S.H - 1350) / 2 : 0;
    return { c: S.c, W: S.W, H: S.H, k: k, oy: oy, enter: function () { S.c.save(); S.c.translate((S.W - S.W * k) / 2, oy); S.c.scale(k, k); }, leave: function () { S.c.restore(); } };
  }

  // ---------- แบบ "บัตรขึ้นเครื่อง" ----------
  function drawBoarding(canvas, d, rat) {
    var P = stage(canvas, rat), c = P.c, W = P.W, H = P.H, T = theme(d), U = T.u;
    var deep = mixc(U, '#000000', lumOf(U) > 0.6 ? 0.66 : 0.5), ink = '#1F2328', mute = '#8A8F98', code = uniCode(d), seed = seedOf(d.name + d.inst);
    var UT = lumOf(U) > 0.6 ? mixc(U, '#000000', 0.38) : U;   // สีอ่อนมาก (เช่น เหลือง) ใช้เฉดเข้มขึ้นกับตัวหนังสือบนพื้นขาว
    // พื้นหลังเต็มภาพ
    var g = c.createLinearGradient(0, 0, W, H); g.addColorStop(0, mixc(U, '#ffffff', 0.35)); g.addColorStop(1, mixc(U, '#000000', 0.15)); c.fillStyle = g; c.fillRect(0, 0, W, H);
    c.fillStyle = 'rgba(255,255,255,0.14)'; for (var yy = 12; yy < H; yy += 22) { for (var xx = (yy % 44 ? 0 : 11); xx < W; xx += 22) { c.beginPath(); c.arc(xx, yy, 2.2, 0, 6.2832); c.fill(); } }
    c.strokeStyle = 'rgba(255,255,255,0.35)'; c.lineWidth = 3; c.setLineDash([4, 14]); c.lineCap = 'round';
    c.beginPath(); c.moveTo(-40, H - 100); c.bezierCurveTo(300, H - 450, 700, H + 150, W + 40, H - 370); c.stroke(); c.setLineDash([]); c.lineCap = 'butt';
    if (P.oy > 0) {   // สตอรี่: หัว-ท้ายเพิ่ม
      plane(c, W / 2, P.oy * 0.42, 1.6, -0.35, 'rgba(255,255,255,0.9)');
      c.fillStyle = '#fff'; c.font = '600 30px ' + F_M; spaced(c, 'CLASS OF 2569', W / 2, P.oy * 0.42 + 80, 8, 'center');
      c.font = '600 24px ' + F_M; c.fillStyle = 'rgba(255,255,255,0.85)'; spaced(c, 'POOLCHAROENWITTAYAKOM SCHOOL', W / 2, H - P.oy * 0.45, 5, 'center');
    }
    P.enter();
    var X = 80, Y = 56, CW = 920, CH = 1238, R = 36, cut = 800, cut2 = 1110;
    function notchPath() {
      c.beginPath(); c.moveTo(X + R, Y); c.lineTo(X + CW - R, Y); c.arcTo(X + CW, Y, X + CW, Y + R, R);
      [cut, cut2].forEach(function (q) { c.lineTo(X + CW, Y + q - 24); c.arc(X + CW, Y + q, 24, -Math.PI / 2, Math.PI / 2, true); });
      c.lineTo(X + CW, Y + CH - R); c.arcTo(X + CW, Y + CH, X + CW - R, Y + CH, R); c.lineTo(X + R, Y + CH); c.arcTo(X, Y + CH, X, Y + CH - R, R);
      [cut2, cut].forEach(function (q) { c.lineTo(X, Y + q + 24); c.arc(X, Y + q, 24, Math.PI / 2, -Math.PI / 2, true); });
      c.lineTo(X, Y + R); c.arcTo(X, Y, X + R, Y, R); c.closePath();
    }
    c.save(); c.shadowColor = 'rgba(0,0,0,0.25)'; c.shadowBlur = 44; c.shadowOffsetY = 18; notchPath(); c.fillStyle = '#FFFFFF'; c.fill(); c.restore();
    c.save(); notchPath(); c.clip();
    // หัวบัตร
    var hg = c.createLinearGradient(X, Y, X + CW, Y + 250); hg.addColorStop(0, deep); hg.addColorStop(1, mixc(U, '#000000', lumOf(U) > 0.6 ? 0.5 : 0.3)); c.fillStyle = hg; c.fillRect(X, Y, CW, 250);
    c.save(); c.globalAlpha = 0.1; c.strokeStyle = '#fff'; c.lineWidth = 2; for (var i = 0; i < 9; i++) { c.beginPath(); c.arc(X + CW - 40, Y + 20, 50 + i * 34, 0, 6.2832); c.stroke(); } c.restore();
    c.fillStyle = '#fff'; c.beginPath(); c.arc(X + 62, Y + 52, 22, 0, 6.2832); c.fill(); plane(c, X + 62, Y + 52, 0.5, -0.5, deep);
    c.fillStyle = '#fff'; c.font = '600 22px ' + F_M; spaced(c, 'PW GUIDANCE AIRLINES', X + 98, Y + 60, 3, 'left');
    c.font = '700 20px ' + F_S; c.fillStyle = 'rgba(255,255,255,0.85)'; spaced(c, 'BOARDING PASS', X + CW - 44, Y + 60, 5, 'right');
    c.fillStyle = 'rgba(255,255,255,0.25)'; c.fillRect(X + 40, Y + 90, CW - 80, 1.5);
    var ts = 96; c.font = '400 ' + ts + 'px ' + F_T; while (c.measureText('Congratulations!').width > CW - 140 && ts > 40) { ts -= 2; c.font = '400 ' + ts + 'px ' + F_T; }
    c.textAlign = 'center'; c.fillStyle = 'rgba(0,0,0,0.28)'; c.fillText('Congratulations!', W / 2 + 4, Y + 198);
    c.fillStyle = foil(c, X + 120, Y + 110, X + CW - 120, Y + 220); c.fillText('Congratulations!', W / 2, Y + 194);
    // เส้นทาง PW → มหาวิทยาลัย
    var ry = Y + 300;
    c.font = '600 18px ' + F_M; c.fillStyle = mute; spaced(c, 'FROM', X + 48, ry, 3, 'left'); spaced(c, 'TO', X + CW - 48, ry, 3, 'right');
    c.font = '600 108px ' + F_M; c.fillStyle = ink; c.textAlign = 'left'; c.fillText('PW', X + 44, ry + 104);
    if (code) { var cf = fitF(c, code, F_M, '600', 108, 50, 330, 1); c.fillStyle = UT; putLines(c, cf, X + CW - 44, ry + 104, 1, 'right'); }
    else { c.fillStyle = UT; c.font = '600 60px ' + F_M; c.textAlign = 'right'; c.fillText('★', X + CW - 60, ry + 96); }
    c.font = '400 20px ' + F_B; c.fillStyle = mute; c.textAlign = 'left'; c.fillText('Poolcharoenwittayakom', X + 48, ry + 138); c.textAlign = 'right'; c.fillText('Your next chapter', X + CW - 48, ry + 138);
    var ax0 = X + 250, ax1 = X + CW - 360, ay = ry + 64;
    c.strokeStyle = '#C9CDD3'; c.lineWidth = 3; c.setLineDash([8, 9]); c.beginPath(); c.moveTo(ax0, ay); c.quadraticCurveTo((ax0 + ax1) / 2, ay - 54, ax1, ay); c.stroke(); c.setLineDash([]);
    c.fillStyle = '#C9CDD3'; c.beginPath(); c.arc(ax0, ay, 6, 0, 6.2832); c.fill(); c.beginPath(); c.arc(ax1, ay, 6, 0, 6.2832); c.fill();
    plane(c, (ax0 + ax1) / 2, ay - 27, 1, 0, UT);
    // ผู้โดยสาร
    var px = X + 48, py = Y + 476, pw = 220, ph = 262;
    c.fillStyle = mixc(U, '#ffffff', 0.85); rr(c, px - 8, py - 8, pw + 16, ph + 16, 22); c.fill();
    c.save(); rr(c, px, py, pw, ph, 16); c.clip(); drawPhotoBlock(c, d, px, py, pw, ph, T, 0.2); c.restore();
    var fx = px + pw + 44, fw = X + CW - 48 - fx;
    function lab(txt, x, y) { c.font = '600 16px ' + F_M; c.fillStyle = mute; spaced(c, txt, x, y, 2.5, 'left'); }
    lab('PASSENGER', fx, py + 14);
    c.fillStyle = ink; putLines(c, fitF(c, d.name, F_M, '600', 42, 24, fw, 1), fx, py + 62, 1.2);
    var colW = fw / 2, gy = py + 118;
    [['FLIGHT', 'PW2569'], ['CLASS', d.cls || '-'], ['BOARDING', d.round || '-'], ['STATUS', 'ADMITTED ✓']].forEach(function (it, q) {
      var cx = fx + (q % 2) * colW, cy = gy + Math.floor(q / 2) * 82;
      lab(it[0], cx, cy); c.fillStyle = it[0] === 'STATUS' ? UT : ink; putLines(c, fitF(c, it[1], F_M, '600', 32, 18, colW - 16, 1), cx, cy + 40, 1.2);
    });
    // รอยปรุ
    c.strokeStyle = '#D5D9DE'; c.lineWidth = 3; c.setLineDash([12, 11]);
    [cut, cut2].forEach(function (q) { c.beginPath(); c.moveTo(X + 40, Y + q); c.lineTo(X + CW - 40, Y + q); c.stroke(); }); c.setLineDash([]);
    // ปลายทาง
    var dy = Y + cut + 54;
    lab('DESTINATION · UNIVERSITY', X + 48, dy);
    c.fillStyle = deep; dy = putLines(c, fitF(c, uniText(d), F_M, '600', 44, 26, CW - 96, 2), X + 48, dy + 52, 1.16) + 8;
    lab('TERMINAL · FACULTY / MAJOR', X + 48, dy);
    c.fillStyle = '#3D434B'; putLines(c, fitF(c, d.prog, F_B, '500', 29, 18, CW - 96, 2), X + 48, dy + 40, 1.28);
    // ต้นขั้ว
    var sy = Y + cut2 + 34, rb = rng(seed), bx = X + 48;
    c.fillStyle = ink; while (bx < X + 470) { var bw = 2 + Math.floor(rb() * 5); c.fillRect(bx, sy - 6, bw, 58); bx += bw + 2 + Math.floor(rb() * 4); }
    c.font = 'italic 400 27px ' + F_S; c.fillStyle = deep; c.textAlign = 'right'; c.fillText('Wishing you joy & success', X + CW - 48, sy + 16); c.fillText('on your new journey.', X + CW - 48, sy + 48);
    c.font = '600 14px ' + F_M; c.fillStyle = mute; spaced(c, 'GUIDANCE OFFICE · POOLCHAROENWITTAYAKOM SCHOOL', X + 48, sy + 86, 2, 'left');
    c.restore();
    // ตราประทับบนมุมรูป
    c.save(); c.translate(px + 44, py + ph - 30); c.rotate(-0.25); c.globalAlpha = 0.9;
    c.fillStyle = 'rgba(255,255,255,0.55)'; c.beginPath(); c.arc(0, 0, 70, 0, 6.2832); c.fill();
    c.strokeStyle = UT; c.fillStyle = UT; c.lineWidth = 5; c.beginPath(); c.arc(0, 0, 70, 0, 6.2832); c.stroke(); c.lineWidth = 2; c.beginPath(); c.arc(0, 0, 58, 0, 6.2832); c.stroke();
    c.font = 'italic 900 22px ' + F_S; c.textAlign = 'center'; c.fillText('ADMITTED', 0, 8);
    c.font = '700 12px ' + F_S; spaced(c, '★ 2569 ★', 0, -24, 2, 'center'); spaced(c, 'PW GUIDANCE', 0, 38, 2, 'center');
    c.restore();
    P.leave();
    return { H: H };
  }

  // ---------- แบบ "ไฟนีออน" (สีตามมหาวิทยาลัย) ----------
  function drawNeon(canvas, d, rat) {
    var P = stage(canvas, rat), c = P.c, W = P.W, H = P.H, T = theme(d), U = T.u, gray = satOf(U) < 0.18;
    var hot = gray ? '#FFD34D' : (lumOf(U) < 0.35 ? mixc(U, '#ffffff', 0.45) : mixc(U, '#ffffff', 0.25));
    var soft = gray ? '#FFF1B8' : mixc(U, '#ffffff', 0.75), line = gray ? '#FFE58A' : mixc(U, '#ffffff', 0.6);
    var g = c.createLinearGradient(0, 0, 0, H); g.addColorStop(0, mixc(U, '#000000', 0.8)); g.addColorStop(1, mixc(U, '#000000', 0.91)); c.fillStyle = g; c.fillRect(0, 0, W, H);
    var rg = c.createRadialGradient(W / 2, H * 0.42, 0, W / 2, H * 0.42, 760); rg.addColorStop(0, rgbaU(U, 0.35)); rg.addColorStop(1, rgbaU(U, 0)); c.fillStyle = rg; c.fillRect(0, 0, W, H);
    var r = rng(seedOf(d.name + 'neon')); for (var i = 0; i < 170; i++) { c.fillStyle = 'rgba(255,255,255,' + (0.15 + r() * 0.55) + ')'; c.beginPath(); c.arc(r() * W, r() * H * 0.72, r() * 1.8, 0, 6.2832); c.fill(); }
    var hz = H - 370; c.strokeStyle = gray ? 'rgba(255,211,77,0.22)' : shade(U, 0.3, 'w', 0.22); c.lineWidth = 1.2;
    for (i = 0; i < 16; i++) { c.beginPath(); c.moveTo(W / 2, hz); c.lineTo(-400 + i * 125, H); c.stroke(); }
    for (i = 0; i < 7; i++) { var yy = hz + 20 + i * i * 12; c.beginPath(); c.moveTo(0, yy); c.lineTo(W, yy); c.stroke(); }
    function glow(col, blur, fn) { c.save(); c.shadowColor = col; c.shadowBlur = blur; fn(); c.restore(); }
    if (P.oy > 0) { c.font = '600 26px ' + F_M; c.fillStyle = soft; glow(hot, 12, function () { spaced(c, 'POOLCHAROENWITTAYAKOM SCHOOL', W / 2, P.oy * 0.55, 6, 'center'); }); }
    P.enter();
    c.font = '150px "Great Vibes", ' + F_T; c.textAlign = 'center';
    glow(hot, 44, function () { c.fillStyle = hot; c.fillText('Congratulations', W / 2, 210); });
    glow(hot, 12, function () { c.fillStyle = soft; c.fillText('Congratulations', W / 2, 210); });
    c.font = '46px Monoton, ' + F_M; glow(hot, 16, function () { c.fillStyle = soft; c.fillText('CLASS OF 2569', W / 2, 296); });
    var px = 300, py = 340, pw = 480, ph = 520;
    glow(hot, 50, function () { c.strokeStyle = line; c.lineWidth = 8; rr(c, px - 14, py - 14, pw + 28, ph + 28, 36); c.stroke(); });
    c.save(); rr(c, px, py, pw, ph, 26); c.clip(); drawPhotoBlock(c, d, px, py, pw, ph, T, 0.2); c.restore();
    c.fillStyle = '#fff'; putLines(c, fitF(c, d.name, F_M, '600', 54, 30, 900, 1), W / 2, 950, 1.2, 'center');
    c.font = '400 28px ' + F_B; c.fillStyle = soft; c.textAlign = 'center'; c.fillText([d.cls, d.round].filter(Boolean).join('  ·  '), W / 2, 996);
    var fi = fitF(c, uniText(d), F_M, '600', 44, 26, 920, 2), yi = 1074;
    glow(hot, 22, function () { c.fillStyle = soft; yi = putLines(c, fi, W / 2, 1074, 1.2, 'center'); });
    c.fillStyle = 'rgba(255,255,255,0.85)'; putLines(c, fitF(c, d.prog, F_B, '400', 27, 18, 900, 2), W / 2, yi + 6, 1.3, 'center');
    c.font = '400 22px ' + F_B; c.fillStyle = 'rgba(255,255,255,0.5)'; c.textAlign = 'center'; c.fillText('Guidance Office · Poolcharoenwittayakom School', W / 2, 1300);
    P.leave();
    return { H: H };
  }

  var DESIGNS = { boarding: drawBoarding, neon: drawNeon };
  function drawCard(canvas, d, rat) { var f = DESIGNS[d.design] || DESIGNS[curDesign()] || drawBoarding; return f(canvas, d, rat || '4:5'); }
  function curDesign() { try { var v = localStorage.getItem('pcwCardDesign'); return DESIGNS[v] ? v : 'boarding'; } catch (e) { return 'boarding'; } }
  function setDesign(v) { try { localStorage.setItem('pcwCardDesign', DESIGNS[v] ? v : 'boarding'); } catch (e) { } }

  // ชื่อรอบแบบสั้นสำหรับช่อง "รอบสมัคร" บนการ์ด
  function roundShort(r) {
    var m = String(r || '').match(/รอบ\s*([1-4])/);
    return m ? 'TCAS ' + m[1] : '';
  }
  function fontsReady() {
    if (!document.fonts || !document.fonts.load) { return Promise.resolve(); }
    return Promise.all(['400 30px Sarabun', '500 30px Sarabun', '600 30px Sarabun', '700 30px Sarabun', '400 30px Mitr', '600 30px Mitr', '400 30px Chonburi', '400 30px Pacifico', '700 30px "Playfair Display"', 'italic 400 30px "Playfair Display"', 'italic 900 30px "Playfair Display"', '400 30px "Great Vibes"', '400 30px Monoton'].map(function (f) { return document.fonts.load(f, 'ยินดีด้วย Congratulations PW 2569'); })).catch(function () {});
  }
  window.PCWCard = { draw: drawCard, roundShort: roundShort, fontsReady: fontsReady, color: effColor, code: uniCode, design: curDesign, setDesign: setDesign, designs: [['boarding', '✈️ บัตรขึ้นเครื่อง'], ['neon', '🌃 ไฟนีออน']] };
})();
