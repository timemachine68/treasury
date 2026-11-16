"""สร้างแม่แบบเอกสาร Open House จากไฟล์ Word ต้นฉบับของโรงเรียน แล้วฝังลง open-house-docs.js

ทำตามสกิล thai-docx: ใช้ python-docx, แทรก Zero-Width Space (U+200B) ระหว่างคำไทยด้วย pythainlp,
จัดย่อหน้าชิดซ้าย (ไม่ใช้ both / thaiDistribute) — ย่อหน้ากึ่งกลาง (หัวเรื่อง/ช่องลงชื่อ) คงไว้

วิธีใช้ (ต้องมี: pip install python-docx pythainlp):
    python3 tools/open-house-template/make_template.py <ต้นฉบับ.docx> <แม่แบบ.docx> [open-house-docs.js]

- ต้นฉบับ = ไฟล์ "บันทึกข้อความ + รายชื่อ + หนังสือขออนุญาตผู้ปกครอง" ของโรงเรียน (ครูส่งมา 16 พ.ย. 2569)
  อย่าเก็บต้นฉบับใน repo เพราะมีชื่อนักเรียนจริงในหน้ารายชื่อ — สคริปต์นี้ตัดออกให้แล้ว
- คงรูปแบบเดิม (ตราครุฑ ฟอนต์ ระยะขอบ) แทนเฉพาะข้อความที่ต้องเปลี่ยนด้วย {{KEY}}
- อ้างย่อหน้าตามลำดับ: บันทึก p0-28, หัวรายชื่อ p34, แถวแม่แบบ p35, หนังสือผู้ปกครอง p68-96
  ถ้าโรงเรียนเปลี่ยนแบบฟอร์ม ลำดับย่อหน้าจะเปลี่ยน -> สคริปต์จะหยุดที่ assert ให้แก้เลขย่อหน้าก่อน
- หนังสือขออนุญาตผู้ปกครอง = 1 หน้า ไม่ระบุชื่อนักเรียน (เว้นจุดไว้ให้กรอกเอง) ใส่เฉพาะรายละเอียดกิจกรรม ใช้เลขไทยทั้งฉบับ
- ใส่ path ของ open-house-docs.js เป็นอาร์กิวเมนต์ที่ 3 เพื่อแทนค่า TPL_B64 ให้อัตโนมัติ
"""
import sys, zipfile, copy, re, io
from lxml import etree
from docx import Document
from pythainlp import word_tokenize

SRC, OUT = sys.argv[1], sys.argv[2]
W = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
def q(t): return '{%s}%s' % (W, t)

doc = Document(SRC)
root = doc.element
body = root.find(q('body'))
kids = list(body)
paras = [k for k in kids if k.tag == q('p')]
sect = kids[-1]; assert sect.tag == q('sectPr')
assert len(paras) == 97, len(paras)

def text(p): return ''.join(t.text or '' for t in p.iter(q('t')))

def replace_span(p, old, new):
    """แทนข้อความ old ด้วย new ภายในย่อหน้า โดยคง rPr ของ run แรกที่ข้อความเริ่ม"""
    ts = list(p.iter(q('t')))
    s = ''.join(t.text or '' for t in ts)
    i = s.find(old)
    assert i >= 0, (old, s)
    assert s.find(old, i + 1) < 0, ('ซ้ำ', old)
    j = i + len(old); pos = 0; first = True
    for t in ts:
        a, b = pos, pos + len(t.text or ''); pos = b
        if b <= i or a >= j: continue
        txt = t.text or ''
        keep_l = txt[:max(0, i - a)]; keep_r = txt[max(0, j - a):] if j < b else ''
        if first:
            t.text = keep_l + new + keep_r; first = False
        else:
            t.text = keep_r
        t.set('{http://www.w3.org/XML/1998/namespace}space', 'preserve')

def collapse(p, new):
    """ทั้งย่อหน้าเหลือ run เดียว (ใช้ rPr ของ run แรกที่มีข้อความ) — ใช้กับย่อหน้าที่ทุก run รูปแบบเดียวกัน"""
    runs = [r for r in p.findall(q('r'))]
    tr = [r for r in runs if r.find(q('t')) is not None]
    rpr = tr[0].find(q('rPr'))
    for r in runs: p.remove(r)
    r = etree.SubElement(p, q('r'))
    if rpr is not None: r.append(copy.deepcopy(rpr))
    t = etree.SubElement(r, q('t')); t.text = new
    t.set('{http://www.w3.org/XML/1998/namespace}space', 'preserve')

def ppr(p):
    x = p.find(q('pPr'))
    if x is None: x = etree.Element(q('pPr')); p.insert(0, x)
    return x

def insert_ppr_child(p, el, after=('pStyle', 'keepNext', 'keepLines')):
    x = ppr(p); idx = 0
    for k, c in enumerate(list(x)):
        if etree.QName(c).localname in after: idx = k + 1
    x.insert(idx, el)

def set_jc(p, val):
    x = ppr(p); jc = x.find(q('jc'))
    if jc is None:
        jc = etree.Element(q('jc'))
        # jc ต้องอยู่ก่อน rPr / sectPr / pPrChange
        rp = x.find(q('rPr')); (rp.addprevious(jc) if rp is not None else x.append(jc))
    jc.set(q('val'), val)

P = paras
# ---------- บันทึกข้อความ ----------
replace_span(P[6], '5 พฤศจิกายน 2569', '{{DATE}}')
collapse(P[13], '         ด้วย{{UNI}} ได้จัดกิจกรรม Open House ในวัน{{DAYDATE}} ระหว่างเวลา {{TIME}} ณ {{PLACE}} ในการนี้จึงขออนุญาตนำนักเรียนเข้าร่วมกิจกรรมดังกล่าว โดยมีรายชื่อนักเรียนตามเอกสารแนบ')
replace_span(P[14], '...............................................', '{{TEACHERS}}')
replace_span(P[14], 'ตำแหน่ง ครูแนะแนว', 'ตำแหน่ง {{POSITION}}')
# ข้อ 2 เดิมแยก 2 บรรทัด (กด Enter กลางประโยค) -> รวมเป็นย่อหน้าเดียว ชิดซ้ายขวาแบบปกติ
collapse(P[16], '2. ขออนุเคราะห์เวลาเรียนให้กับนักเรียนในวัน{{DAYDATE}} ระหว่างเวลา {{TIME}}')
set_jc(P[16], 'both')
replace_span(P[23], '..............................................', '{{SIGNER}}')
replace_span(P[27], 'นางหทัยทิพย์  รอดดี', '{{HEAD}}')
# หน้ารายชื่อ: ขึ้นหน้าใหม่จริง (แทนบรรทัดว่างที่ดันไว้) + แก้หัวเรื่องจาก "การแข่งขัน" (ค้างจากฟอร์มอื่น)
collapse(P[34], 'รายชื่อนักเรียนที่เข้าร่วมกิจกรรม Open House {{UNI}}')
insert_ppr_child(P[34], etree.Element(q('pageBreakBefore')))
# แถวแม่แบบ: ชื่อ <แท็บ 1 ครั้ง ไปจุดคงที่> ชั้น
row = P[35]
rr = [r for r in row.findall(q('r')) if r.find(q('t')) is not None]
rpr = rr[0].find(q('rPr'))
for r in row.findall(q('r')): row.remove(r)
def add_run(p, content):
    r = etree.SubElement(p, q('r'))
    if rpr is not None: r.append(copy.deepcopy(rpr))
    if content == '\t': etree.SubElement(r, q('tab'))
    else:
        t = etree.SubElement(r, q('t')); t.text = content
        t.set('{http://www.w3.org/XML/1998/namespace}space', 'preserve')
add_run(row, '{{S_NAME}}'); add_run(row, '\t'); add_run(row, '{{S_CLASS}}')
x = ppr(row)
old_tabs = x.find(q('tabs'))
if old_tabs is not None: x.remove(old_tabs)
tabs = etree.Element(q('tabs')); tab = etree.SubElement(tabs, q('tab'))
tab.set(q('val'), 'left'); tab.set(q('pos'), '5670')          # ~10 ซม. จากขอบซ้าย
# tabs อยู่หลัง numPr/pBdr/shd และก่อน spacing/ind/jc
order = ['pStyle','keepNext','keepLines','pageBreakBefore','framePr','widowControl','numPr','suppressLineNumbers','pBdr','shd']
insert_ppr_child(row, tabs, after=order)
set_jc(row, 'left')   # แถวรายชื่อไม่ต้องกระจายเต็มบรรทัด
# ช่องเลขลำดับเดิมกว้าง 360 (พอแค่เลขหลักเดียว) -> 600 ให้พอเลข 2-3 หลัก, เลขยังเริ่มที่ 720 เท่าเดิม
ind = etree.Element(q('ind')); ind.set(q('left'), '1320'); ind.set(q('hanging'), '600')
insert_ppr_child(row, ind, after=order + ['tabs','suppressAutoHyphens','kinsoku','wordWrap','overflowPunct','topLinePunct','autoSpaceDE','autoSpaceDN','bidi','adjustRightInd','snapToGrid','spacing'])

# ---------- หนังสือขออนุญาตผู้ปกครอง ----------
replace_span(P[69], '149', '{{PNO}}')
# บรรทัด "ที่ ศธ ... [แท็บหลายครั้ง] โรงเรียนพูลเจริญวิทยาคม": เดิมกดแท็บ 6 ครั้งดันชื่อโรงเรียน
# พอเป็นเลขไทย (กว้างกว่า) ชื่อโรงเรียนเลยขอบแล้วขึ้นบรรทัดใหม่ -> ใช้แท็บเดียวไปจุดแท็บคงที่ 6480
# (= 4.5 นิ้วจากขอบซ้าย ตำแหน่งเดิมของชื่อโรงเรียนในต้นฉบับ) ไม่ขึ้นกับความกว้างของตัวเลข
for r in P[69].findall(q('r')):
    for tb in r.findall(q('tab')): r.remove(tb)
    for t in r.findall(q('t')):
        if not (t.text or '').strip(): t.text = ''
school = [t for t in P[69].iter(q('t')) if 'โรงเรียนพูลเจริญวิทยาคม' in (t.text or '')]
assert len(school) == 1
school[0].text = school[0].text.lstrip()
school[0].addprevious(etree.Element(q('tab')))
tabs69 = etree.Element(q('tabs')); tb = etree.SubElement(tabs69, q('tab'))
tb.set(q('val'), 'left'); tb.set(q('pos'), '6480')
insert_ppr_child(P[69], tabs69, after=['pStyle','keepNext','keepLines','pageBreakBefore','framePr','widowControl','numPr','suppressLineNumbers','pBdr','shd'])
collapse(P[72], '{{DATE}}')
replace_span(P[74], 'มหาวิทยาลัยธุรกิจบัณฑิตย์', '{{UNI}}')
# P[76] "เรียน ผู้ปกครองของ......" คงจุดไว้ให้กรอกเอง (หนังสือฉบับเดียวใช้ถ่ายสำเนาแจก)
collapse(P[78], '         ด้วย{{UNI}} ได้จัดกิจกรรม Open House ในวัน{{DAYDATE}} ระหว่างเวลา {{TIME}} ณ {{PLACE}}')
replace_span(P[80], '......................................................', ' {{TEACHERS}}')
replace_span(P[80], 'ครูแนะแนว', '{{POSITION}}')
replace_span(P[85], 'นางสุภาพร  รัตน์น้อย', '{{DIRECTOR}}')
# P[91] แบบตอบรับ: ชื่อผู้ปกครอง/นักเรียน/ชั้น คงจุดไว้ให้กรอกเอง
replace_span(P[91], 'มหาวิทยาลัยธุรกิจบัณฑิตย์', '{{UNI}}')
# หนังสือผู้ปกครองต้องจบใน 1 หน้า (ขอบล่างแคบมาก) เผื่อที่ให้ชื่อครูผู้ดูแลหลายคน:
# - บรรทัดว่างก่อนเบอร์โทร และก่อน "ลงชื่อ" ในแบบตอบรับ -> ครึ่งความสูง (แบบเดียวกับบรรทัดว่างหลัง "เรื่อง"/"เรียน" ในฟอร์มเดิม)
def half_blank(p):
    assert text(p) == '', text(p)
    rp = ppr(p).find(q('rPr'))
    if rp is None: rp = etree.SubElement(ppr(p), q('rPr'))
    for tag in ('sz', 'szCs'):
        e = rp.find(q(tag))
        if e is None: e = etree.SubElement(rp, q(tag))
        e.set(q('val'), '16')
half_blank(P[87]); half_blank(P[93])
# - เส้นประตัดแบบตอบรับยาวเกินบรรทัดเล็กน้อยจนขึ้นบรรทัดใหม่ -> ตัดให้สั้นลง
dots = text(P[89]); assert set(dots) <= set('….'), dots
replace_span(P[89], dots, '…' * 54)

# ---------- ประกอบ body ใหม่: บันทึก(0-28) + หัวรายชื่อ(34) + แถว(35) + [SPLIT] + ผู้ปกครอง(68-96) + sectPr ----------
keep = P[0:17] + P[18:29] + [P[34], P[35]]   # ตัด P[17] (เวลาบรรทัดแยกของข้อ 2) เพราะรวมเข้า P[16] แล้ว
split = etree.Element(q('p')); r = etree.SubElement(split, q('r')); t = etree.SubElement(r, q('t')); t.text = '{{SPLIT}}'
parent = P[68:97]
for k in list(body): body.remove(k)
for k in keep: body.append(k)
body.append(split)
for k in parent: body.append(k)
body.append(sect)

# ---------- กฎสกิล thai-docx ----------
ZWS = '\u200b'
THAI = re.compile(r'([\u0E00-\u0E7F]+)')
def insert_zwsp(text):
    """แทรก ZWS ระหว่างคำไทย (pythainlp newmm) อังกฤษ/ตัวเลข/{{KEY}} ไม่แตะ — เหมือน scripts/thai_docx.py ของสกิล"""
    return ''.join(ZWS.join(word_tokenize(part, engine='newmm')) if THAI.fullmatch(part) else part
                   for part in THAI.split(text))
n_left = n_zw = 0
for p in body.iter(q('p')):
    x = p.find(q('pPr'))
    jc = x.find(q('jc')) if x is not None else None
    if jc is not None and jc.get(q('val')) in ('both', 'thaiDistribute', 'distribute', 'lowKashida', 'mediumKashida', 'highKashida'):
        jc.set(q('val'), 'left'); n_left += 1
for t in body.iter(q('t')):
    if t.text and THAI.search(t.text):
        new = insert_zwsp(t.text.replace(ZWS, ''))
        if new != t.text: t.text = new; n_zw += 1
print('ชิดซ้าย %d ย่อหน้า · แทรกตัวคั่นคำ %d ช่วงข้อความ' % (n_left, n_zw))

# ---------- หนังสือผู้ปกครอง: ตัวเลขไทย (ครูกำหนด 16 พ.ย. 2569) ----------
# ทำหลังแทรกตัวคั่นคำ: ตอนแทรกยังเป็นเลขอารบิก pythainlp จึงไม่แทรกตัวคั่นกลางเลขที่หนังสือ/เบอร์โทร
TH_DIGITS = str.maketrans('0123456789', '๐๑๒๓๔๕๖๗๘๙')
n_th = 0
for p in P[68:97]:
    for t in p.iter(q('t')):
        if t.text and re.search(r'[0-9]', t.text):
            t.text = t.text.translate(TH_DIGITS); n_th += 1
print('หนังสือผู้ปกครอง: เปลี่ยนเป็นเลขไทย %d ช่วงข้อความ' % n_th)

# ---------- บันทึกด้วย python-docx + ล้างชื่อผู้สร้างไฟล์ ----------
doc.core_properties.author = 'แนะให้แนว'
doc.core_properties.last_modified_by = 'แนะให้แนว'
buf = io.BytesIO(); doc.save(buf)
zin = zipfile.ZipFile(io.BytesIO(buf.getvalue()))
zout = zipfile.ZipFile(OUT, 'w', zipfile.ZIP_DEFLATED)
for it in zin.infolist():
    data = zin.read(it.filename)
    if it.filename == 'docProps/app.xml':
        data = re.sub(r'(<Company>)[^<]*(</Company>)', r'\1\2', data.decode('utf-8')).encode('utf-8')
    zout.writestr(it, data)
zout.close()

s = zipfile.ZipFile(OUT).read('word/document.xml').decode('utf-8')
keys = sorted(set(re.findall(r'\{\{(\w+)\}\}', s)))
print('placeholders:', keys)
assert '<w:p><w:r><w:t>{{SPLIT}}</w:t></w:r></w:p>' in s, 'ไม่พบตัวแบ่งส่วน {{SPLIT}}'
assert 'STUDENT' not in keys, 'หนังสือผู้ปกครองต้องไม่มีชื่อนักเรียน'

if len(sys.argv) > 3:
    import base64, textwrap
    js_path = sys.argv[3]
    js = open(js_path, encoding='utf-8').read()
    b = base64.b64encode(open(OUT, 'rb').read()).decode()
    new = '  const TPL_B64 =\n' + '\n'.join('    "%s"+' % l for l in textwrap.wrap(b, 100)) + '\n    "";\n'
    js2, n = re.subn(r'  const TPL_B64 =\n(?:    "[^"]*"\+\n)+    "";\n', lambda m: new, js, count=1)
    assert n == 1, 'ไม่พบ TPL_B64 ใน ' + js_path
    open(js_path, 'w', encoding='utf-8').write(js2)
    print('ฝังแม่แบบลง', js_path, 'แล้ว (%d KB)' % (len(b) // 1024))
