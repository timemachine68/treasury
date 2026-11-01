/* การ์ดแสดงความยินดี แบบ 5 "บัตรผ่านเข้า" — ใช้ร่วมกันระหว่าง survey.html (นักเรียน) และ congrats-cards.html (ครู)
   วาดลง <canvas> ในเครื่องผู้ใช้ ไม่เก็บไฟล์การ์ดไว้ที่ไหน · ตราประทับเขียนแค่ "ผ่านแล้ว" (ครูสั่ง 31 ต.ค. 2569) */
(function(){
'use strict';
var __UNI=[
 ['พระจอมเกล้าธนบุรี','#f26a21'],['พระจอมเกล้าเจ้าคุณทหารลาดกระบัง','#e8531f'],['พระจอมเกล้าพระนครเหนือ','#b3202a'],
 ['จุฬาลงกรณ์','#e0066f'],['เกษตรศาสตร์','#0b8a42'],['มหิดล','#1c3f94'],['ธรรมศาสตร์','#b3202a'],
 ['ศิลปากร','#0a7a5a'],['เชียงใหม่','#7b3f98'],['ขอนแก่น','#b8860b'],['สงขลานครินทร์','#1f3c88'],
 ['บูรพา','#e9a400'],['รามคำแหง','#d4570f'],['ศรีนครินทรวิโรฒ','#a0242a'],['นเรศวร','#8a1c1c'],
 ['มหาสารคาม','#e6a100'],['ทักษิณ','#d6246a'],['สุรนารี','#c81f2d'],['แม่ฟ้าหลวง','#c8102e'],['พะเยา','#6a3a95']
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
    var i; for (i = 0; i < UNI_COLORS.length; i++) { if (inst && inst.indexOf(UNI_COLORS[i][0]) > -1) { return UNI_COLORS[i][1]; } }
    return null;
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
  function drawPhotoBlock(c, d, x, y, w, h, T, fy) {
    if (d.photo && d.photo !== 'sample' && d.photo.width) { drawCover(c, d.photo, x, y, w, h, fy); }
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
  // ---------- แบบที่ 5: บัตรผ่านเข้า ----------
  function drawTicket(canvas, d, rat) {
    var s = setup(canvas, rat), c = s.c, W = s.W, H = s.H, T = theme(d), k = ({ '4:5': 1, '1:1': 0.8, '9:16': 1.12 })[rat], ky = (rat === '9:16') ? 1.35 : 1, i;
    var bg = c.createLinearGradient(0, 0, W, H); bg.addColorStop(0, T.tint); bg.addColorStop(1, T.tint2); c.fillStyle = bg; c.fillRect(0, 0, W, H);
    dots(c, 20, 20, W, H, 46, 5, 'rgba(255,255,255,0.4)');
    var m = (rat === '9:16') ? 80 : (rat === '1:1' ? 52 : 64), tx = m, tw = W - 2 * m, ty = m, th = H - 2 * m, rad = 34 * k;
    var headH = 140 * k, upH = 450 * k * ky, footH = 104 * k, py = ty + headH + upH, nr = 26 * k, pad = 48 * k, ink = T.ink;
    function tpath() {
      c.beginPath(); c.moveTo(tx + rad, ty); c.lineTo(tx + tw - rad, ty); c.arcTo(tx + tw, ty, tx + tw, ty + rad, rad);
      c.lineTo(tx + tw, py - nr); c.arc(tx + tw, py, nr, -Math.PI / 2, Math.PI / 2, true);
      c.lineTo(tx + tw, ty + th - rad); c.arcTo(tx + tw, ty + th, tx + tw - rad, ty + th, rad);
      c.lineTo(tx + rad, ty + th); c.arcTo(tx, ty + th, tx, ty + th - rad, rad);
      c.lineTo(tx, py + nr); c.arc(tx, py, nr, Math.PI / 2, -Math.PI / 2, true);
      c.lineTo(tx, ty + rad); c.arcTo(tx, ty, tx + rad, ty, rad); c.closePath();
    }
    c.save(); c.shadowColor = 'rgba(0,0,0,0.3)'; c.shadowBlur = 40; c.shadowOffsetY = 18; tpath(); c.fillStyle = '#fffdf7'; c.fill(); c.restore();

    // หัวบัตร
    c.save(); tpath(); c.clip();
    c.fillStyle = T.deep; c.fillRect(tx, ty, tw, headH);
    c.save(); c.beginPath(); c.rect(tx, ty, tw, headH); c.clip(); lattice(c, W, H, 'rgba(233,196,106,0.09)', 60 * k); c.restore();
    c.fillStyle = goldGrad(c, ty + headH - 8 * k, ty + headH); c.fillRect(tx, ty + headH - 7 * k, tw, 7 * k);
    c.restore();
    c.textAlign = 'left'; c.font = '400 ' + Math.round(76 * k) + 'px ' + F_H; c.fillStyle = goldGrad(c, ty + 30 * k, ty + headH - 30 * k);
    c.fillText('ยินดีด้วย!', tx + pad, ty + headH * 0.66);
    c.textAlign = 'right'; c.fillStyle = '#fbf6e9'; c.font = '700 ' + Math.round(26 * k) + 'px ' + F_B; c.fillText('บัตรผ่านเข้าศึกษาต่อ', tx + tw - pad, ty + headH * 0.44);
    c.fillStyle = 'rgba(251,246,233,0.8)'; c.font = '400 ' + Math.round(24 * k) + 'px ' + F_B; c.fillText('โรงเรียนพูลเจริญวิทยาคม', tx + tw - pad, ty + headH * 0.72);

    // รูป + ข้อมูลนักเรียน
    var px0 = tx + pad, py0 = ty + headH + 30 * k, pw = 322 * k, ph = upH - 60 * k;
    c.save(); c.shadowColor = 'rgba(0,0,0,0.25)'; c.shadowBlur = 16; c.shadowOffsetY = 6; rr(c, px0 - 6 * k, py0 - 6 * k, pw + 12 * k, ph + 12 * k, 20 * k); c.fillStyle = goldGrad(c, py0, py0 + ph); c.fill(); c.restore();
    c.save(); rr(c, px0, py0, pw, ph, 14 * k); c.clip(); drawPhotoBlock(c, d, px0, py0, pw, ph, T, 0.2); c.restore();
    var fx = px0 + pw + 40 * k, fw = tx + tw - pad - fx, fy = py0, lab = Math.round(22 * k), gap = 16 * k;
    var nm = fitBlock(c, d.name, fw, 50 * k, 28, '700', 2);
    function label(t, y) { c.textAlign = 'left'; c.font = '600 ' + lab + 'px ' + F_B; c.fillStyle = '#7b8494'; c.fillText(t, fx, y + lab * 0.9); return y + lab * 1.45; }
    fy = label('ชื่อ-นามสกุล', fy);
    c.fillStyle = ink; c.font = '700 ' + nm.size + 'px ' + F_B; nm.lines.forEach(function (t, q) { c.fillText(t, fx, fy + nm.size * 0.95 + q * nm.size * 1.2); });
    fy += nm.lines.length * nm.size * 1.2 + gap;
    fy = label('ชั้น', fy); c.fillStyle = ink; c.font = '700 ' + Math.round(36 * k) + 'px ' + F_B; c.fillText(d.cls, fx, fy + 30 * k); fy += 44 * k + gap;
    if (d.round) { fy = label('รอบสมัคร', fy); c.fillStyle = ink; c.font = '700 ' + Math.round(36 * k) + 'px ' + F_B; c.fillText(d.round, fx, fy + 30 * k); }

    // รอยปรุ
    c.save(); c.setLineDash([14 * k, 11 * k]); c.lineWidth = 3 * k; c.strokeStyle = '#cfc8b2'; c.beginPath(); c.moveTo(tx + nr + 12 * k, py); c.lineTo(tx + tw - nr - 12 * k, py); c.stroke(); c.restore();

    // ส่วนล่าง
    var lw = tw - 2 * pad, uni = fitBlock(c, d.inst, lw, 68 * k, 32, '700', 2), fac = fitBlock(c, d.prog, lw, 44 * k, 26, '600', 2);
    var lg = 14 * k, contentH = lab * 1.45 + uni.lines.length * uni.size * 1.2 + lg + lab * 1.45 + fac.lines.length * fac.size * 1.3;
    var rTop = py + nr, rBot = ty + th - footH, yy = rTop + Math.max(10 * k, (rBot - rTop - contentH) * 0.34);
    c.textAlign = 'left'; c.font = '600 ' + lab + 'px ' + F_B; c.fillStyle = '#7b8494'; c.fillText('มหาวิทยาลัย', tx + pad, yy + lab * 0.9); yy += lab * 1.45;
    c.fillStyle = ink; c.font = '700 ' + uni.size + 'px ' + F_B; uni.lines.forEach(function (t, q) { c.fillText(t, tx + pad, yy + uni.size * 0.95 + q * uni.size * 1.2); });
    yy += uni.lines.length * uni.size * 1.2 + lg;
    c.font = '600 ' + lab + 'px ' + F_B; c.fillStyle = '#7b8494'; c.fillText('คณะ / สาขา', tx + pad, yy + lab * 0.9); yy += lab * 1.45;
    c.fillStyle = '#2f3b52'; c.font = '600 ' + fac.size + 'px ' + F_B; fac.lines.forEach(function (t, q) { c.fillText(t, tx + pad, yy + fac.size * 0.98 + q * fac.size * 1.3); });

    c.textAlign = 'left'; c.fillStyle = '#9aa3b2'; c.font = '600 ' + Math.round(26 * k) + 'px ' + F_B; c.fillText('ขอให้เรียนสนุกและประสบความสำเร็จ', tx + pad, rBot - 26 * k);

    // ตราประทับ
    var sr = 96 * k, sx = tx + tw - pad - sr - 14 * k, sy = py0 + ph - sr - 6 * k, stc = shade(T.u, 0.3, 'k');
    c.save(); c.translate(sx, sy); c.rotate(-0.24); c.globalCompositeOperation = 'multiply'; c.globalAlpha = 0.92;
    c.strokeStyle = stc; c.lineWidth = 6 * k; c.beginPath(); c.arc(0, 0, sr, 0, 6.2832); c.stroke();
    c.lineWidth = 2.5 * k; c.beginPath(); c.arc(0, 0, sr - 12 * k, 0, 6.2832); c.stroke();
    c.fillStyle = stc; c.textAlign = 'center'; c.font = '400 ' + Math.round(31 * k) + 'px ' + F_H; c.fillText('ผ่านแล้ว', 0, 12 * k);
    c.restore();

    // ท้ายบัตร: บาร์โค้ด
    var ft = ty + th - footH, rnd = rng(seedOf(d.name + d.inst + 'bc')), bxx = tx + pad, bh = 56 * k, byy = ft + (footH - bh) / 2;
    c.fillStyle = '#e5dfcb'; c.fillRect(tx + pad, ft, tw - 2 * pad, 2 * k);
    c.fillStyle = ink; c.globalAlpha = 0.85;
    while (bxx < tx + tw * 0.46) { var bw = (2 + Math.floor(rnd() * 4)) * k; c.fillRect(bxx, byy, bw, bh); bxx += bw + (2 + Math.floor(rnd() * 4)) * k; }
    c.globalAlpha = 1; c.textAlign = 'right'; c.fillStyle = '#7b8494'; c.font = '600 ' + Math.round(24 * k) + 'px ' + F_B; c.fillText('งานแนะแนว  ·  แนะให้แนว', tx + tw - pad, ft + footH / 2 + 8 * k);
    sparkle(c, tx - 4, ty + 10, 26 * k, '#ffffff'); sparkle(c, tx + tw + 6, ty + th - 20, 22 * k, '#ffffff');
    return { H: H };
  }

  // ชื่อรอบแบบสั้นสำหรับช่อง "รอบสมัคร" บนการ์ด
  function roundShort(r) {
    var m = String(r || '').match(/รอบ\s*([1-4])/);
    return m ? 'TCAS ' + m[1] : '';
  }
  function fontsReady() {
    if (!document.fonts || !document.fonts.load) { return Promise.resolve(); }
    return Promise.all(['400 30px Sarabun', '600 30px Sarabun', '700 30px Sarabun', '400 30px Chonburi'].map(function (f) { return document.fonts.load(f, 'ยินดีด้วย'); })).catch(function () {});
  }
  window.PCWCard = { draw: drawTicket, roundShort: roundShort, fontsReady: fontsReady, color: effColor };
})();
