/* card-photo-fx.js — ปรับรูปนักเรียนสำหรับการ์ดแสดงความยินดี (ทำในเบราว์เซอร์ทั้งหมด รูปไม่ถูกส่งออกนอกระบบ)
 * 1) หาตำแหน่งใบหน้า  → ให้ congrats-card-draw.js จัดกรอบให้หน้าขนาดเท่ากันทุกใบ
 * 2) ปรับแสง/สีอัตโนมัติ (ไม่ใช้โมเดล)
 * 3) แยกคนออกจากพื้นหลัง → เปลี่ยนพื้นเป็นสีมหาวิทยาลัย/สีขาว
 * โมเดล MediaPipe (Apache-2.0) โหลดเฉพาะฝั่งครูตอนต้องใช้ ฝั่งนักเรียนใช้แค่ render() ที่ไม่ต้องโหลดโมเดล
 *
 * fx = { v:1, auto:true, tone:{g:[r,g,b],lo,hi,gamma}, face:{cx,cy,w,h}|null, zoom:1, dx:0, dy:0, bright:0, contrast:0, bg:'keep'|'uni'|'white' }
 *   (ตำแหน่งทั้งหมดเป็นสัดส่วน 0–1 ของรูป ไม่ขึ้นกับขนาดไฟล์)
 */
(function () {
  'use strict';
  var O = window.PCW_FX_ASSETS || {};   // เปลี่ยนที่อยู่ไฟล์ได้ (ใช้ตอนทดสอบ)
  var TV = O.tv || 'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.14';
  var FACE_MODEL = O.face || 'https://storage.googleapis.com/mediapipe-models/face_detector/blaze_face_short_range/float16/1/blaze_face_short_range.tflite';
  var SEG_MODEL = O.seg || 'https://storage.googleapis.com/mediapipe-models/image_segmenter/selfie_segmenter/float16/latest/selfie_segmenter.tflite';
  var MAX_SIDE = 1400;
  var WHITE_BG = '#F3F5F7';

  function clamp(v, a, b) { return v < a ? a : v > b ? b : v; }
  function canvas(w, h) { var c = document.createElement('canvas'); c.width = Math.max(1, Math.round(w)); c.height = Math.max(1, Math.round(h)); return c; }
  function scaled(img, maxSide) {
    var w = img.naturalWidth || img.width, h = img.naturalHeight || img.height, s = Math.min(1, maxSide / Math.max(w, h));
    var c = canvas(w * s, h * s), x = c.getContext('2d');
    x.imageSmoothingQuality = 'high'; x.drawImage(img, 0, 0, c.width, c.height);
    return c;
  }

  /* ---------- โหลดโมเดล (ครั้งเดียว) ---------- */
  var visionP = null, faceP = null, segP = null;
  function vision() {
    if (!visionP) {
      visionP = import(TV + '/vision_bundle.mjs').then(function (m) {
        return m.FilesetResolver.forVisionTasks(TV + '/wasm').then(function (fs) { return { m: m, fs: fs }; });
      });
      visionP.catch(function () { visionP = null; });
    }
    return visionP;
  }
  function faceDetector() {
    if (!faceP) {
      faceP = vision().then(function (v) {
        return v.m.FaceDetector.createFromOptions(v.fs, { baseOptions: { modelAssetPath: FACE_MODEL, delegate: 'CPU' }, runningMode: 'IMAGE', minDetectionConfidence: 0.45 });
      });
      faceP.catch(function () { faceP = null; });
    }
    return faceP;
  }
  function segmenter() {
    if (!segP) {
      segP = vision().then(function (v) {
        return v.m.ImageSegmenter.createFromOptions(v.fs, { baseOptions: { modelAssetPath: SEG_MODEL, delegate: 'CPU' }, runningMode: 'IMAGE', outputCategoryMask: false, outputConfidenceMasks: true });
      });
      segP.catch(function () { segP = null; });
    }
    return segP;
  }

  /* ---------- 1) หาใบหน้า ---------- */
  // โมเดลหาหน้าระยะใกล้ หน้าต้องใหญ่พอในภาพ → ลองทั้งรูปก่อน ถ้าไม่เจอ (ถ่ายเต็มตัว หน้าเล็ก)
  // ค่อย ๆ ซูมส่องส่วนบนของรูปเป็นช่อง ๆ แล้วเลือกผลที่มั่นใจที่สุด
  function windows(W, H) {
    var list = [[0, 0, 1, 1]], sizes = [0.6, 0.4, 0.28], s, step, x, y;
    for (var i = 0; i < sizes.length; i++) {
      s = sizes[i] * Math.min(W, H); step = s / 2;
      for (y = 0; y + s <= H * 0.7 + 1; y += step) for (x = 0; x + s <= W + 1; x += step) list.push([x / W, y / H, s / W, s / H]);
    }
    return list;
  }
  function detectIn(det, src, t) {
    var W = src.width, H = src.height, sx = t[0] * W, sy = t[1] * H, sw = t[2] * W, sh = t[3] * H;
    // ใช้ผืนจัตุรัสเสมอ (ภาพไม่จัตุรัส ตำแหน่งหน้าที่ได้จะเพี้ยน)
    var k = Math.min(4, 512 / Math.max(sw, sh)), side = Math.round(Math.max(sw, sh) * k), c = canvas(side, side), cx = c.getContext('2d');
    var offX = (side - sw * k) / 2;
    cx.fillStyle = '#808080'; cx.fillRect(0, 0, side, side);
    cx.drawImage(src, sx, sy, sw, sh, offX, 0, sw * k, sh * k);
    var r = det.detect(c), out = [];
    (r.detections || []).forEach(function (d) {
      var b = d.boundingBox, score = d.categories && d.categories[0] ? d.categories[0].score : 0;
      if (b.width > side * 0.9 || b.width < side * 0.06) return;    // กรอบใหญ่/เล็กผิดปกติ = หาผิด
      var fw = b.width / k, fh = b.height / k;
      out.push({ score: score, f: { cx: (sx + (b.originX - offX) / k + fw / 2) / W, cy: (sy + b.originY / k + fh / 2) / H, w: fw / W, h: fh / H } });
    });
    return out;
  }
  function findFace(src) {
    return faceDetector().then(function (det) {
      var all = detectIn(det, src, [0, 0, 1, 1]).filter(function (r) { return r.score >= 0.6; });
      if (!all.length) {
        windows(src.width, src.height).slice(1).forEach(function (t) { all = all.concat(detectIn(det, src, t)); });
        all = all.filter(function (r) { return r.score >= 0.7; });
      }
      if (!all.length) return null;
      all.sort(function (a, b) { return b.score - a.score; });
      // ซูมเข้าไปรอบ ๆ หน้าที่เจอแล้วหาซ้ำ เพื่อให้กรอบหน้าแม่นขึ้น (หน้าเล็กในรูปใหญ่ กรอบแรกมักหยาบ)
      var f = all[0].f, W = src.width, H = src.height;
      for (var n = 0; n < 2; n++) {
        var side = Math.min(W, H, Math.max(f.w * W, f.h * H) * 2.6), x0 = clamp(f.cx * W - side / 2, 0, W - side), y0 = clamp(f.cy * H - side / 2, 0, H - side);
        var near = detectIn(det, src, [x0 / W, y0 / H, side / W, side / H]).filter(function (r) { return r.score >= 0.55; });
        if (!near.length) break;
        near.sort(function (a, b) { return (Math.abs(a.f.cx - f.cx) + Math.abs(a.f.cy - f.cy)) - (Math.abs(b.f.cx - f.cx) + Math.abs(b.f.cy - f.cy)); });
        var g = near[0].f, same = Math.abs(g.w - f.w) < f.w * 0.08;
        f = g; if (same) break;
      }
      return f;
    });
  }

  /* ---------- 2) ปรับแสง/สีอัตโนมัติ ---------- */
  function analyzeTone(src, face) {
    var c = scaled(src, 256), x = c.getContext('2d'), W = c.width, H = c.height, d = x.getImageData(0, 0, W, H).data;
    var sr = 0, sg = 0, sb = 0, n = 0, i, l;
    for (i = 0; i < d.length; i += 4) {
      l = (0.299 * d[i] + 0.587 * d[i + 1] + 0.114 * d[i + 2]) / 255;
      if (l > 0.06 && l < 0.94) { sr += d[i]; sg += d[i + 1]; sb += d[i + 2]; n++; }
    }
    var g = [1, 1, 1];
    if (n > 50) {
      var mr = sr / n, mg = sg / n, mb = sb / n, avg = (mr + mg + mb) / 3;
      g = [mr, mg, mb].map(function (m) { var k = clamp(avg / Math.max(1, m), 0.88, 1.15); return 1 + (k - 1) * 0.6; });
    }
    var hist = new Array(256).fill(0), total = 0;
    for (i = 0; i < d.length; i += 4) {
      l = Math.round(clamp(0.299 * d[i] * g[0] + 0.587 * d[i + 1] * g[1] + 0.114 * d[i + 2] * g[2], 0, 255));
      hist[l]++; total++;
    }
    function pct(p) { var acc = 0, t = total * p; for (var v = 0; v < 256; v++) { acc += hist[v]; if (acc >= t) return v; } return 255; }
    var lo = Math.min(pct(0.005) / 255, 0.14), hi = Math.max(pct(0.995) / 255, 0.8);
    if (hi - lo < 0.3) { lo = 0; hi = 1; }
    // ความสว่างของบริเวณหน้า (หรือกลางรูปถ้าไม่เจอหน้า) → gamma ให้หน้าสว่างพอดี
    var fx0 = face ? face.cx - face.w / 2 : 0.3, fy0 = face ? face.cy - face.h / 2 : 0.15, fw = face ? face.w : 0.4, fh = face ? face.h : 0.4;
    var X0 = Math.floor(clamp(fx0, 0, 1) * W), Y0 = Math.floor(clamp(fy0, 0, 1) * H), X1 = Math.ceil(clamp(fx0 + fw, 0, 1) * W), Y1 = Math.ceil(clamp(fy0 + fh, 0, 1) * H);
    var s = 0, m = 0, xx, yy, p;
    for (yy = Y0; yy < Y1; yy++) for (xx = X0; xx < X1; xx++) {
      p = (yy * W + xx) * 4;
      l = (0.299 * d[p] * g[0] + 0.587 * d[p + 1] * g[1] + 0.114 * d[p + 2] * g[2]) / 255;
      s += clamp((l - lo) / (hi - lo), 0.001, 1); m++;
    }
    var mean = m ? s / m : 0.5, gamma = clamp(Math.log(0.56) / Math.log(clamp(mean, 0.05, 0.95)), 0.62, 1.35);
    return { g: g.map(function (v) { return +v.toFixed(3); }), lo: +lo.toFixed(3), hi: +hi.toFixed(3), gamma: +gamma.toFixed(3) };
  }
  function lut(fx) {
    var t = (fx.auto !== false && fx.tone) ? fx.tone : { g: [1, 1, 1], lo: 0, hi: 1, gamma: 1 };
    var b = clamp((fx.bright || 0) / 200, -0.25, 0.25), c = clamp((fx.contrast || 0) / 100, -0.5, 0.5), out = [], ch, v, x;
    for (ch = 0; ch < 3; ch++) {
      var a = new Uint8ClampedArray(256);
      for (v = 0; v < 256; v++) {
        x = v * t.g[ch] / 255;
        x = clamp((x - t.lo) / Math.max(0.05, t.hi - t.lo), 0, 1);
        x = Math.pow(x, t.gamma);
        x = (x - 0.5) * (1 + c) + 0.5 + b;
        a[v] = Math.round(clamp(x, 0, 1) * 255);
      }
      out.push(a);
    }
    return out;
  }

  /* ---------- 3) แยกคนออกจากพื้นหลัง → รูป mask (PNG ขาว+ความโปร่งใส) ---------- */
  function makeMask(src) {
    return segmenter().then(function (seg) {
      var c = scaled(src, 640), res = seg.segment(c), m = res.confidenceMasks && res.confidenceMasks[0];
      if (!m) { if (res.close) res.close(); throw new Error('แยกพื้นหลังไม่สำเร็จ'); }
      var arr = m.getAsFloat32Array(), w = m.width, h = m.height, out = canvas(w, h), ox = out.getContext('2d'), id = ox.createImageData(w, h), i, v;
      var person = 0;
      for (i = 0; i < arr.length; i++) {
        v = clamp((arr[i] - 0.3) / 0.4, 0, 1); v = v * v * (3 - 2 * v);   // ขอบนุ่มแต่คม
        id.data[i * 4] = id.data[i * 4 + 1] = id.data[i * 4 + 2] = 255; id.data[i * 4 + 3] = Math.round(v * 255);
        if (v > 0.5) person++;
      }
      ox.putImageData(id, 0, 0);
      if (res.close) res.close();
      var ratio = person / arr.length;
      if (ratio < 0.03) throw new Error('หาตัวคนในรูปไม่เจอ ใช้พื้นหลังเดิมไปก่อน');
      return out;
    });
  }

  /* ---------- สร้างรูปที่ปรับแล้ว (ไม่ต้องใช้โมเดล) ---------- */
  function bgColor(mode, uniHex) {
    if (mode === 'white') return WHITE_BG;
    if (mode === 'uni') {
      var h = String(uniHex || '#27478a').replace('#', ''), r = parseInt(h.substr(0, 2), 16), g = parseInt(h.substr(2, 2), 16), b = parseInt(h.substr(4, 2), 16);
      var t = 0.78; // อ่อนลงมาก ให้หน้าเด่น
      return 'rgb(' + Math.round(r + (255 - r) * t) + ',' + Math.round(g + (255 - g) * t) + ',' + Math.round(b + (255 - b) * t) + ')';
    }
    return null;
  }
  function render(img, fx, maskImg, uniHex) {
    fx = fx || {};
    var c = scaled(img, MAX_SIDE), x = c.getContext('2d'), W = c.width, H = c.height;
    var L = lut(fx), id = x.getImageData(0, 0, W, H), d = id.data, i;
    for (i = 0; i < d.length; i += 4) { d[i] = L[0][d[i]]; d[i + 1] = L[1][d[i + 1]]; d[i + 2] = L[2][d[i + 2]]; }
    x.putImageData(id, 0, 0);
    var bg = (fx.bg && fx.bg !== 'keep' && maskImg) ? bgColor(fx.bg, uniHex) : null;
    if (bg) {
      var person = canvas(W, H), px = person.getContext('2d');
      px.drawImage(c, 0, 0);
      px.globalCompositeOperation = 'destination-in';
      px.imageSmoothingQuality = 'high';
      px.drawImage(maskImg, 0, 0, W, H);
      x.globalCompositeOperation = 'source-over';
      x.fillStyle = bg; x.fillRect(0, 0, W, H);
      var gl = x.createRadialGradient(W / 2, H * 0.35, 0, W / 2, H * 0.35, Math.max(W, H) * 0.75);
      gl.addColorStop(0, 'rgba(255,255,255,0.35)'); gl.addColorStop(1, 'rgba(255,255,255,0)');
      x.fillStyle = gl; x.fillRect(0, 0, W, H);
      x.drawImage(person, 0, 0);
    }
    return { canvas: c, bg: bg };
  }

  /* ---------- ค่าเริ่มต้นอัตโนมัติ (ฝั่งครู) ---------- */
  function autoFx(img) {
    var src = scaled(img, 1024);
    return findFace(src).catch(function () { return null; }).then(function (face) {
      return { v: 1, auto: true, tone: analyzeTone(src, face), face: face, zoom: 1, dx: 0, dy: 0, bright: 0, contrast: 0, bg: 'keep', noFace: !face };
    });
  }
  function maskFor(img) { return makeMask(scaled(img, 1024)); }
  function preload(withSeg) { faceDetector(); if (withSeg) segmenter(); }

  // ค่าที่ส่งให้ congrats-card-draw.js
  function cardFields(prepared, fx) {
    if (!prepared) return {};
    // ไม่เจอหน้า: สมมติหน้าอยู่กลางค่อนบน เพื่อให้ครูยังซูม/เลื่อนเองได้
    var face = (fx && fx.face) || (fx ? { cx: 0.5, cy: 0.3, w: 0.3, h: 0.3 * prepared.canvas.width / prepared.canvas.height } : null);
    return { photo: prepared.canvas, photoFace: face, photoZoom: (fx && fx.zoom) || 1, photoDx: (fx && fx.dx) || 0, photoDy: (fx && fx.dy) || 0, photoBg: prepared.bg || null };
  }

  window.PCWPhoto = { autoFx: autoFx, maskFor: maskFor, render: render, bgColor: bgColor, cardFields: cardFields, preload: preload };
})();
