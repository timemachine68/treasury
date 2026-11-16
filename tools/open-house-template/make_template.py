"""สร้างแม่แบบเอกสาร Open House จากไฟล์ Word ต้นฉบับของโรงเรียน แล้วฝังลง open-house-docs.js

วิธีใช้ (ต้องมี python3 + lxml):
    python3 tools/open-house-template/make_template.py <ต้นฉบับ.docx> <แม่แบบ.docx> [open-house-docs.js]

- ต้นฉบับ = ไฟล์ "บันทึกข้อความ + รายชื่อ + หนังสือขออนุญาตผู้ปกครอง" ของโรงเรียน (ครูส่งมา 16 พ.ย. 2569)
  อย่าเก็บต้นฉบับใน repo เพราะมีชื่อนักเรียนจริงในหน้ารายชื่อ — สคริปต์นี้ตัดออกให้แล้ว
- คงรูปแบบเดิม (ตราครุฑ ฟอนต์ ระยะขอบ) แทนเฉพาะข้อความที่ต้องเปลี่ยนด้วย {{KEY}}
- อ้างย่อหน้าตามลำดับ: บันทึก p0-28, หัวรายชื่อ p34, แถวแม่แบบ p35, หนังสือผู้ปกครอง p68-96
  ถ้าโรงเรียนเปลี่ยนแบบฟอร์ม ลำดับย่อหน้าจะเปลี่ยน -> สคริปต์จะหยุดที่ assert ให้แก้เลขย่อหน้าก่อน
- ใส่ path ของ open-house-docs.js เป็นอาร์กิวเมนต์ที่ 3 เพื่อแทนค่า TPL_B64 ให้อัตโนมัติ
"""
import sys, zipfile, copy, re
from lxml import etree

SRC, OUT = sys.argv[1], sys.argv[2]
W = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
def q(t): return '{%s}%s' % (W, t)

zin = zipfile.ZipFile(SRC)
root = etree.fromstring(zin.read('word/document.xml'))
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
collapse(P[72], '{{DATE}}')
replace_span(P[74], 'มหาวิทยาลัยธุรกิจบัณฑิตย์', '{{UNI}}')
replace_span(P[76], 'ของ......................................................', 'ของ {{STUDENT}}')
collapse(P[78], '         ด้วย{{UNI}} ได้จัดกิจกรรม Open House ในวัน{{DAYDATE}} ระหว่างเวลา {{TIME}} ณ {{PLACE}}')
replace_span(P[80], '......................................................', ' {{TEACHERS}}')
replace_span(P[80], 'ครูแนะแนว', '{{POSITION}}')
replace_span(P[85], 'นางสุภาพร  รัตน์น้อย', '{{DIRECTOR}}')
replace_span(P[91], 'ผู้ปกครอง.....................................................นักเรียนชั้น ม........../.......', 'ผู้ปกครอง {{STUDENT}} นักเรียนชั้น ม.{{CLS}}')
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

xml = etree.tostring(root, xml_declaration=True, encoding='UTF-8', standalone=True)
def scrub_props(name, data):
    """ล้างชื่อผู้สร้าง/ผู้แก้ไข/บริษัทในคุณสมบัติไฟล์ (เป็นชื่อบุคคล ไม่ต้องติดไปกับเอกสาร)"""
    t = data.decode('utf-8')
    if name == 'docProps/core.xml':
        t = re.sub(r'(<dc:creator>)[^<]*(</dc:creator>)', r'\1แนะให้แนว\2', t)
        t = re.sub(r'(<cp:lastModifiedBy>)[^<]*(</cp:lastModifiedBy>)', r'\1แนะให้แนว\2', t)
    if name == 'docProps/app.xml':
        t = re.sub(r'(<Company>)[^<]*(</Company>)', r'\1\2', t)
    return t.encode('utf-8')

zout = zipfile.ZipFile(OUT, 'w', zipfile.ZIP_DEFLATED)
for it in zin.infolist():
    if it.filename == 'word/document.xml': data = xml
    elif it.filename in ('docProps/core.xml', 'docProps/app.xml'): data = scrub_props(it.filename, zin.read(it.filename))
    else: data = zin.read(it.filename)
    zout.writestr(it, data)
zout.close()

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

# รายงานผล
s = xml.decode('utf-8')
keys = sorted(set(re.findall(r'\{\{(\w+)\}\}', s)))
print('placeholders:', keys)
print('split marker as <w:p>:', '<w:p><w:r><w:t>{{SPLIT}}</w:t></w:r></w:p>' in s)
