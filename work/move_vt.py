# -*- coding: utf-8 -*-
"""Do lai phep quet da dung cho ket luan "ptRunVector khong co ai doc".

    python move_vt.py                  # quet va in bang
    python move_vt.py --vts            # chi in bang vtable dang dung
    python move_vt.py --json <f>       # ghi so do ra JSON

Cau hoi: trong ho `CDFSpriteMove*` cua libgame.so, truong nao duoc doc — nhat la
`ptRunVector` (toc do CHAY, +0x1B8; `ptVector` la toc do DI, +0x1B0). Ten truong
giai bang TRA CHUOI chu khong suy tu so: literal 0x003a7f1e -> 0x7bdb68 =
'ptVector' (di kem `add.w r6, r4, #0x1b0`), literal 0x003a8da6 -> 0x7bea24 =
'ptRunVector' (di kem `#0x1b8`).

Bon buoc, va ba cho da quet nham (ghi lai de khong mac lai):

  1. `_vts.json`: 34 vtable cua 17 lop (RTTI o 0x8de29c).
  2. Moi vtable -> danh sach O MA tro vao .text. Do dai vtable lay bang dia chi
     vtable KE TIEP: cac vtable nam LIEN NHAU trong .data.rel.ro, nen di cho toi
     khi gap mot word khong tro vao .text thi se an luon vtable sau vao cung mot
     danh sach — lam the lan dau ra 13.259 "o ma", trong khi 34 vtable that chi
     vao khoang 6.400. O thuan ao o GIUA vtable thi `continue` chu khong `break`.
  3. Moi o ma la mot DIEM VAO HAM — phai quet THAN cua ham do (tu diem vao toi
     `pop {..., pc}` / `bx lr` / `b` nhay ra ngoai khoang quet). Quet chinh DIA
     CHI o ma thi ket qua luon la 0: dia chi o ma la mot con tro, khong phai mot
     lenh. Mot ket luan "khong ai doc" do ra thi rong nghia.
  4. `disasm()` cua capstone DUNG o byte khong dich duoc dau tien. Quet thang ca
     .text 5,6 MB chi ra ~60k lenh; phai resync (`p += 2`) moi ra 2.233.285 lenh
     (`findstr.dis_all` da lam viec do).

GIOI HAN, PHAI GHI RO: mot lenh `#0x1b8` tran khong noi len duoc no thuoc doi
tuong nao. Quet thua (an sang ham ben canh) chi THEM ket qua gia chu khong lam
mat ket qua that. Nen so o day nghia la "bao nhieu cho cham `+0x1B0`/`+0x1B8`
trong THAN cac ham ma 34 vtable tro toi", KHONG phai "bao nhieu cho doc
ptRunVector". Muon chac phai phan tich luong du lieu theo thanh ghi — chua lam,
va vi vay ROADMAP khong duoc phep khang dinh "khong ai doc".
"""
import argparse
import bisect
import cay
import json
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from findstr import dis_all, word  # noqa: E402
from xref import load  # noqa: E402

_e, SECS = load()
VTS = pathlib.Path(cay.cache('_vts.json'))
CTOR = 0x415c34
CTOR_VT = 0x8da858
# Hai truong can soi. +0x1B8 = ptRunVector (8 byte: 0x1B8 va 0x1BC la hai float).
SOI = (0x1B0, 0x1B4, 0x1B8, 0x1BC)


def text_range():
    for n, a, d in SECS:
        if n == '.text':
            return a, a + len(d)
    raise SystemExit('khong thay .text')


def trong_text(a, s, e):
    return s <= a < e


def o_ma(vt, s, e, het=None):
    """Cac word cua vtable tro vao .text.

    Het bang `het` (dia chi vtable ke tiep) chu khong phai bang o trong dau tien:
    cac vtable nam lien nhau trong .data.rel.ro, nen di cho toi khi gap word
    khong tro vao .text thi se an luon vtable sau vao cung mot danh sach.
    `continue` chu khong `break` o o thuan ao — vtable co o nhu vay o giua.
    """
    out, i = [], 0
    while True:
        a = vt + i * 4
        if het is not None and a >= het:
            break
        w = word(a)
        if w is None:
            break
        if trong_text(w, s, e):
            out.append(w)
        i += 1
        if i > 400:
            break
    return out


def moc(insns):
    """Bang tra dia chi -> chi so trong `insns` (insns xep theo dia chi tang)."""
    return [i.address for i in insns]


def than(a, insns, dia_chi, toi_da=0x1000):
    """Than cua ham tu diem vao `a`.

    Dung o `pop {..., pc}`, `bx lr`, hoac `b` nhay ra ngoai khoang quet. Qua
    `toi_da` byte cung dung — ham ARM that thuong ngan hon nhieu; tran nay chi de
    mot ham la khong keo ca .text vao.
    """
    ra = []
    for i in insns[bisect.bisect_left(dia_chi, a):]:
        if i.address > a + toi_da:
            break
        ra.append(i)
        m = i.mnemonic.split('.')[0]
        if m == 'bx' and i.op_str == 'lr':
            break
        if m == 'pop' and 'pc' in i.op_str:
            break
        if m == 'b':
            try:
                dich = int(i.op_str.lstrip('#'), 16)
            except ValueError:
                continue
            if dich < a or dich > a + toi_da:
                break
    return ra


def cham(insns):
    """[(dia chi lenh, so truong, kieu)] cho moi lenh dong toi mot trong SOI.

    Hai dang: `[rX, #imm]` la DOC ('doc'), `add*/sub* rX, rY, #imm` la LAY DIA CHI
    ('diachi') — dang thu hai bi bo sot neu chi tim ngoac vuong, ma chinh ham
    dung trao truong di bang dang thu hai.
    """
    ngoac = re.compile(r'\[(\w+), #(0x[0-9a-f]+|\d+)\]')
    ngay = re.compile(r'^(\w+), (\w+), #(0x[0-9a-f]+|\d+)$')
    ra = []
    for i in insns:
        for m in ngoac.finditer(i.op_str):
            # `ldr r1, [pc, #0x1b8]` la nap LITERAL theo PC-relative — so 0x1b8 o
            # do la KHOANG CACH toi literal, khong phai truong nao ca. Bo `pc`
            # (va `sp`) di, khong thi +0x1B0/+0x1B4 ra mot dong "doc" gia.
            if m.group(1) in ('pc', 'sp'):
                continue
            v = int(m.group(2), 0)
            if v in SOI:
                ra.append((i.address, v, 'doc'))
        if i.mnemonic.split('.')[0] in ('add', 'addw', 'sub', 'subw'):
            m = ngay.match(i.op_str)
            if m and m.group(2) != 'sp':
                v = int(m.group(3), 0)
                if v in SOI:
                    ra.append((i.address, v, 'diachi'))
    return ra


def main():
    # Dia chi trong file nay do ra tu ban VN — xem cay.kiem_so().
    loi = cay.kiem_so()
    if loi:
        sys.exit(loi)
    ap = argparse.ArgumentParser()
    ap.add_argument('--json')
    ap.add_argument('--vts', action='store_true', help='chi in bang vtable dang dung')
    a = ap.parse_args()

    vts = json.loads(VTS.read_text('utf-8'))
    print('vtable trong %s: %d' % (VTS.name, len(vts)))
    if a.vts:
        for vt, lop in vts:
            print('  %08x  %s' % (vt, lop))
        return

    s, e = text_range()
    print('.text %08x..%08x' % (s, e))

    # 1+2. o ma cua tung vtable; het o vtable ke tiep
    dai = sorted(vt for vt, _ in vts)
    tong, chi_tiet, diem_vao = 0, {}, set()
    for vt, lop in vts:
        ke = next((x for x in dai if x > vt), None)
        o = o_ma(vt, s, e, het=ke)
        chi_tiet['%08x' % vt] = {'lop': lop, 'so_o': len(o),
                                 'het': ('%08x' % ke) if ke else 'het .text'}
        tong += len(o)
        diem_vao.update(o)
    print('vtable: %d, tong o ma tro vao .text: %d, diem vao ham rieng: %d'
          % (len(vts), tong, len(diem_vao)))

    # 3. quet .text mot lan, roi quet THAN tung diem vao
    insns = dis_all(s, e)
    dia_chi = moc(insns)
    print('so lenh quet duoc: %d' % len(insns))
    theo, so_lenh_than = {}, 0
    for f in sorted(diem_vao):
        body = than(f, insns, dia_chi)
        so_lenh_than += len(body)
        for ad, v, kieu in cham(body):
            theo.setdefault(v, []).append((f, ad, kieu))
    print('than cac diem vao: %d lenh' % so_lenh_than)
    print('cham truong trong than cac ham ma 34 vtable tro toi:')
    for v in sorted(SOI):
        ds = theo.get(v, [])
        ham = {f for f, _ad, _k in ds}
        kieu = {}
        for _f, _ad, k in ds:
            kieu[k] = kieu.get(k, 0) + 1
        print('   +0x%03x  %6d cho, %4d ham  (%s)'
              % (v, len(ds), len(ham),
                 ', '.join('%s %d' % (k, n) for k, n in sorted(kieu.items())) or 'khong'))

    # 4. ham dung cau hinh nam o o ma thu may cua vtable
    o = o_ma(CTOR_VT, s, e, het=next((x for x in dai if x > CTOR_VT), None))
    print('ham dung 0x%08x: %s vtable 0x%08x'
          % (CTOR, ('o ma thu %d' % o.index(CTOR)) if CTOR in o else 'KHONG la o ma cua',
             CTOR_VT))
    print('ham dung/cham quanh no: %s' % ' '.join(
        '+0x%03x@%08x(%s)' % (v, ad, k) for ad, v, k in cham(
            than(CTOR, insns, dia_chi)) or []) or 'khong cham truong nao')

    if a.json:
        pathlib.Path(a.json).write_text(json.dumps(
            {'vtable': chi_tiet, 'tong_o_ma': tong, 'diem_vao': len(diem_vao),
             'so_lenh': len(insns), 'so_lenh_than': so_lenh_than,
             'cham': {('0x%03x' % v): {'cho': len(theo.get(v, [])),
                                       'ham': len({f for f, _a, _k in theo.get(v, [])}),
                                       'kieu': {k: sum(1 for _f, _a, kk in theo.get(v, [])
                                                       if kk == k)
                                                for k in ('doc', 'diachi')}}
                      for v in sorted(SOI)},
             'cho': [[v, '%08x' % f, '%08x' % ad, k] for v in sorted(SOI)
                     for f, ad, k in theo.get(v, [])]},
            ensure_ascii=False, indent=1, sort_keys=True), encoding='utf-8')
        print('da ghi', a.json)


if __name__ == '__main__':
    main()
