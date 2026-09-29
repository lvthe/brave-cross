"""Soi bang shader trong libgame.so: ten, bang nguon, va cho NOI hai bang do.

    python shaders.py --ten        # dia chi cac chuoi ten shader
    python shaders.py --nguon      # bang nguon + doan dau moi nguon
    python shaders.py --noi        # quet TOAN FILE tim con tro toi ten/nguon
    python shaders.py --so         # chi in ket luan dang so
    BC_TREE=cn131 python shaders.py --ten

VI SAO
------
`setGray` (VN, 5 ban sao: 0x24efaa, 0x2bd236, 0x2cfa36, 0x2d280e, 0x49d6ea)
khong he nhac tới nguon shader — no chi dung chuoi ten roi goi
`vfunc_0x158(ten)`. Muon biet chuoi `ShaderPositionTextureColor_Gray` ung voi
nguon nao trong bang nguon thi phai tim cho lien ket hai thu do.

**Da xong — bang day du nam o `shaderghep.py --bang`** (chi so -> ten -> nguon
dinh -> nguon manh), va GRAY la **chi so 1**, nguon manh `N[18] = 0x7ccf00`.

Phep quet trong file nay cho ket qua AM, va ly do da ro (do bang `--quanh`):
dia chi chuoi ten duoc dung bang **PC-TUONG-DOI** — `ldr r1, [pc, #imm]` roi
`add r1, pc`, voi o hang so trong literal pool chua `dich - pc`. Nen trong file
KHONG he co 4 byte nao bang dia chi chuoi, va moi phep quet con tro tuyet doi
(ke ca quet toan file o day) khong the tim ra. Ket luan cu ghi o cho khac rang
"dia chi duoc dung bang movw/movt" la mot SUY DOAN, khong phai do.

Con duong dung la doc MA: `shaderghep.py` dich nguoc `.text`, ghep lai tung cap
`ldr`/`add` thanh hang so 32 bit, roi lan theo GOT toi bang nguon. Ba tang:
`[r5+off]` (o GOT) -> mot phan tu cua bang nguon -> `ldr` lan nua moi ra chuoi
nguon. Vi vay quet con tro khong bao gio thay nguon: dia chi nguon khong xuat
hien trong ma.

HAI BAN, HAI BO HANG SO
-----------------------
Moi dia chi trong file nay do ra tu MOT file `.so` cu the, nen phai tach han
theo ban (xem `BAN`). Ban dang chay la `cay.TEN`; `--doi-chieu` khong co o day
vi `binder.py` moi la noi doi chieu — o day chi co hang so do bang tay, moi con
so ghi kem cho da do.

1.31 khac VN o bon cho, va ca bon deu da do chu khong suy doan:

  * **Bang nguon o `.data` 0xabe1d0, 30 muc** (VN: 0x93caec, 28 muc). Do bang
    cach quet moi doan `.rodata`/`.data`/`.got` tim day word lien tiep tro vao
    vung chuoi GLSL: ra sau day, hai day GLSL la chinh (0xabe1d0 30 word va
    0xabe958 22 word — day sau la bang KHAC, xem duoi).
  * **GOT giu `&bang[i]`, khong giu dia chi dau bang.** Day la cho khac VN va
    cung la cho lam phep quet "0xabe1d0 xuat hien may lan" tra ve **0** — trong
    khi bang ro rang duoc dung. Cac o GOT do ra: 0xaa8a74 = 0xabe1e0,
    0xaa8a88 = 0xabe21c, 0xaa8a6c = 0xabe1e8, 0xaa8a54 = 0xabe1d8,
    0xaa8a4c = 0xabe238 — tat ca deu = 0xabe1d0 + 4k. Nen dia chi dau bang khong
    he xuat hien, va ket luan cu "bang 0xabe1d0 khong cho nao tham chieu toi"
    (ghi trong ban thao truoc) la SAI: no bi tham chieu qua tung phan tu.
  * **Ham dung chuong trinh o 0x4b3c18**, mo dau `cmp r2,#0x11; it hi; pophi;
    tbb [pc,r2]` — 18 nhanh, bang nhay 18 byte tai 0x4b3c28. VN: 0x4d8e1c voi
    `cmp r2,#0x11; bhi.w; tbh`. Vai nhanh doc nguon qua **hai tang GOT**
    (`ldr r0,[r0]; ldr r2,[r0]`), vai nhanh khac chi `ldr`+`add pc` roi tra ve
    o GOT; ca hai cuoi cung deu ve cung bang 0xabe1d0.
  * **Thu tu chi so khac VN.** Chi so KHONG theo thu tu dia chi chuoi: 1.31 co
    `ShaderPositionTextureColor` o chi so **9** (dia chi 0x9406f4, thap hon han
    cac ten khac) con `_Orange/_Gray/_Glow` o 0,1,2. VN khong co bang chi so do
    ra, nen o day VN de `chi_so = None` chu khong dien mot con so doan.

Con `0xabe958` (22 muc) KHONG phai bang nguon shader: 19 muc dau la ten file PNG
(`AttackButton.png`, `UIJunTuanYingDi.png`...), chi ba muc cuoi [19..21]
(0x94b392, 0x94b537, 0x94b6c6) moi la GLSL — do la bo nguon BIEN THE ma
`_Orange`/`_Gray`/`_Glow` dung thay cho nguon goc, tuong ung `N[18] = 0x7ccf00`
cua VN.
"""
import argparse
import struct
import sys

from xref import load

import cay

PATH = cay.SO


#: Hang so theo TUNG ban. Xem docstring: bon khac biet da do giua VN va 1.31.
BAN = {
    'vn': dict(
        # .data: 28 con tro nguon, ket thuc 0xffffffff
        bang_nguon=0x93caec,
        so_muc=30,
        # Vung nguon shader. Do duoc 0x7c6f51..0x7cdab4; o day noi rong ra mot
        # khuc cho de nhan ra, dung y nhu ban cu.
        vung_nguon=(0x7c0000, 0x7dffff),
        ham_dung=None,
        # (ten, dia chi chuoi, chi so) — chi so None vi VN chua do ra bang do.
        ten=[
            ('ShaderPositionTextureColor_Gray', 0x7a9515, None),
            ('ShaderPositionTextureColor', 0x7a9608, None),
            ('ShaderPosition_uColor', 0x7a96b1, None),
            ('ShaderPositionTextureColor_Whitened', 0x7acaaa, None),
            ('ShaderPositionColor', 0x7acba6, None),
            ('ShaderPositionTextureColor_Orange', 0x7acea8, None),
            ('ShaderPositionTexture', 0x7ad242, None),
            ('ShaderPositionTextureColor_Glow', 0x7adca5, None),
            ('ShaderPositionTexture_uColor', 0x7c491a, None),
            ('ShaderPositionLengthTextureColor', 0x7c4ec6, None),
            ('ShaderPositionTextureColorAlphaTest', 0x7c5420, None),
            ('ShaderLabel_DistanceField_Normal', 0x7cde1b, None),
            ('ShaderLabel_DistanceField_Glow', 0x7cde3c, None),
            ('ShaderLabel_Normal', 0x7cde5b, None),
            ('ShaderLabel_Gradual', 0x7cde6e, None),
            ('ShaderLabel_Outline', 0x7cde82, None),
            ('ShaderPositionTextureA8Color', 0x7cde96, None),
            ('KCCShader_PositionTextureColor_HSL', 0x7cdeb3, None),
        ],
    ),
    'cn131': dict(
        # .data: 30 con tro nguon. KHONG ket thuc bang 0xffffffff — muc [21] va
        # [28] dung lai nguon cua [9], nen cho ket thuc phai theo so muc.
        bang_nguon=0xabe1d0,
        so_muc=30,
        # Do duoc 0x94244c..0x94b6c6 (ke ca bo bien the 0x94b392..0x94b6c6).
        vung_nguon=(0x942000, 0x94c000),
        ham_dung=0x4b3c18,
        # Do bang cach dien giai chinh ham dung: di theo `tbb [pc,r2]` (18 nhanh
        # tai 0x4b3c28), mo phong luong thanh ghi, dung o `bl 0x4b1f58`. Ket qua
        # la 17/18 nhanh ra DUNG HAI nguon; chi so 9 khong ra vi no re theo thiet
        # bi luc chay (`bl 0x4d5410; cmp r0,#2`) chu khong theo bang.
        #
        # Phan dinh/manh do bang NOI DUNG (`gl_Position` = dinh, `gl_FragColor` =
        # manh), khong theo thu tu thanh ghi — nho vay khong phu thuoc mo hinh
        # mo phong. Nguon dinh dung chung theo ho (0x943147 cho ho
        # PositionTextureColor, 0x94487b cho ho Label); nguon manh RIENG tung
        # lop — dung khuon VN.
        #
        # Sau phep kiem cheo: chi so doc duoc tu o GOT (vi du cs 15 -> muc [3])
        # dung bang voi gia tri giai ra (0xabe1d0 + 4*3 = 0xabe1dc -> 0x942870).
        # Sau lan luot deu khop, ke ca bon cho da giai tay truoc do.
        #
        # CANH BAO ve quy uoc PC: `ldr rN,[pc,#imm]` lay o pool tai
        # `(dia chi + 4) & ~3`, nhung `add rN, pc` dung **PC = dia chi + 4 KHONG
        # lam tron xuong**. Lay nham quy uoc (lam tron ca hai) thi dung MOT trong
        # moi cap o GOT lech 2 byte, va doc ra mot gia tri TRONG NHU HOP LE nhung
        # la nguon SAI — do la lop loi im lang. Do bang phep dem: quy uoc dung cho
        # 51/51 o GOT thang 4, hai quy uoc kia chi 27/51 va 26/51.
        nguon_lop={
            0: (0x943147, 0x94334a),   1: (0x943147, 0x943466),
            2: (0x943147, 0x943627),   3: (0x943147, 0x943853),
            4: (0x94487b, 0x943a4f),   5: (0x94487b, 0x943d55),
            6: (0x94487b, 0x944028),   7: (0x94487b, 0x944218),
            8: (0x94487b, 0x9444ed),
            9: None,                   # re theo thiet bi luc chay, khong giai tinh
            10: (0x943147, 0x944bbe), 11: (0x942b20, 0x942a2e),
            12: (0x942df9, 0x942c9b), 13: (0x944fa9, 0x944e6c),
            14: (0x943147, 0x942f7d), 15: (0x942870, 0x94279f),
            16: (0x9458ae, 0x945514), 17: (0x943147, 0x945bbb),
        },
        # Vong dang ky 18 shader o 0x4b3e64..0x4b3ffc, moi khoi 0x18 byte:
        #   ldr r1,[pc,#imm]; mov r0,r4; add r1,pc; bl 0x4b4068(ten)
        #   mov r5,r0; bl 0x4b31e4
        #   mov r1,r5; movs r2,#<chi so>; bl 0x4b3c18(handle, chi so)
        # 18 chi so ra dung 0..17, moi ten mot lan.
        ten=[
            ('ShaderPositionTextureColor_Orange', 0x94228d, 0),
            ('ShaderPositionTextureColor_Gray', 0x9422af, 1),
            ('ShaderPositionTextureColor_Glow', 0x9422cf, 2),
            ('ShaderPositionTextureColor_Whitened', 0x9422ef, 3),
            ('ShaderLabel_DistanceField_Normal', 0x942313, 4),
            ('ShaderLabel_DistanceField_Glow', 0x942334, 5),
            ('ShaderLabel_Normal', 0x942353, 6),
            ('ShaderLabel_Outline', 0x94237a, 7),
            ('ShaderLabel_Gradual', 0x942366, 8),
            ('ShaderPositionTextureColor', 0x9406f4, 9),
            ('ShaderPositionTextureColorAlphaTest', 0x9413a1, 10),
            ('ShaderPositionColor', 0x94238e, 11),
            ('ShaderPositionTexture', 0x9423a2, 12),
            ('ShaderPositionTexture_uColor', 0x9423b8, 13),
            ('ShaderPositionTextureA8Color', 0x9423d5, 14),
            ('ShaderPosition_uColor', 0x9423f2, 15),
            ('ShaderPositionLengthTextureColor', 0x942408, 16),
            ('KCCShader_PositionTextureColor_HSL', 0x942429, 17),
        ],
    ),
}


def _h():
    """Khoi hang so cua ban dang chay, kem loi ro rang neu ban chua do."""
    if cay.TEN not in BAN:
        raise SystemExit(
            'chua do hang so shader cho ban %r.\n'
            '  Bang nguon / chuoi ten cua ban khac nam o dia chi khac han;\n'
            '  dung dia chi cua ban da do se ra ket qua sai am tham.\n'
            '  Cac ban da do: %s' % (cay.TEN, ', '.join(sorted(BAN))))
    return BAN[cay.TEN]


def _sec(secs, addr):
    for n, a, d in secs:
        if a <= addr < a + len(d):
            return n
    return '?'


def quet(secs, value):
    """Moi do lech (khong can thang 4) chua 4 byte == value, kem ten doan."""
    need = struct.pack('<I', value)
    ra = []
    for n, a, d in secs:
        i = d.find(need)
        while i != -1:
            ra.append((n, a + i))
            i = d.find(need, i + 1)
    return ra


def word(secs, addr):
    for n, a, d in secs:
        if a <= addr < a + len(d) - 4:
            return struct.unpack_from('<I', d, addr - a)[0]
    return None


def la_nguon(secs_or_v, v=None):
    """Dia chi nam trong vung nguon shader cua BAN dang chay?

    Nhan mot tham so (dia chi) hoac hai (secs, dia chi) — ban cu goi mot tham
    so, giu nguyen de khong pha cho goi cu.
    """
    if v is None:
        v = secs_or_v
    lo, hi = _h()['vung_nguon']
    return v is not None and lo <= v <= hi


def ten(secs):
    h = _h()
    print('  %d ten shader cua ban %r:' % (len(h['ten']), cay.TEN))
    nl = h.get('nguon_lop') or {}
    for t, a, cs in h['ten']:
        nguon = ''
        if cs is not None and cs in nl:
            p = nl[cs]
            nguon = ('  dinh 0x%06x manh 0x%06x' % p) if p else '  (re theo thiet bi)'
        print('  %-38s 0x%06x  %-8s  chi so %-4s%s' % (
            t, a, _sec(secs, a),
            'chua do' if cs is None else cs, nguon))
    if h['ham_dung']:
        print('  ham dung chuong trinh: 0x%06x' % h['ham_dung'])
    return 0


def nguon(secs):
    h = _h()
    print('  bang nguon 0x%06x (%s):' % (h['bang_nguon'],
                                        _sec(secs, h['bang_nguon'])))
    for i in range(h['so_muc']):
        v = word(secs, h['bang_nguon'] + 4 * i)
        if v is None:
            break
        if v == 0xffffffff:
            print('    [%2d] 0xffffffff  <-- ket thuc' % i)
            continue
        s = b''
        for n, a, d in secs:
            if a <= v < a + len(d):
                off = v - a
                s = d[off:off + 40]
                break
        dau = s.split(b'\n')[0][:38].decode('ascii', 'replace')
        print('    [%2d] 0x%06x  %-9s %s' % (i, v, _sec(secs, v), dau))
    return 0


def noi(secs):
    """Cho NOI: moi cho chua con tro toi mot trong cac chuoi ten.

    Neu co bang {ten -> nguon} thi cho chua con tro ten se NAM SAT mot con tro
    nguon. Do la thu can tim.

    Ket qua AM la DUNG cho ca hai ban: dia chi chuoi ten duoc dung bang
    PC-tuong-doi, nen 4 byte dia chi khong he co trong file (xem docstring).
    """
    h = _h()
    print('quet toan file tim con tro toi %d chuoi ten:' % len(h['ten']))
    for t, a, cs in h['ten']:
        hits = quet(secs, a)
        if not hits:
            print('  %-38s khong cho nao' % t)
            continue
        print('  %-38s %d cho:' % (t, len(hits)))
        for sec, at in hits:
            truoc = [word(secs, at - 4 * k) for k in (2, 1)]
            sau = [word(secs, at + 4 * k) for k in (1, 2)]
            print('      %-9s 0x%06x  truoc=%s  sau=%s  %s' % (
                sec, at,
                ' '.join('%08x' % v for v in truoc if v is not None),
                ' '.join('%08x' % v for v in sau if v is not None),
                '<-- SAT NGUON' if any(la_nguon(v) for v in truoc + sau) else ''))
    return 0


def so(secs):
    """In ket luan dang so — de doi chieu giua hai ban bang mat."""
    h = _h()
    print('ban              %s' % cay.TEN)
    print('bang nguon       0x%06x  %s  %d muc' % (
        h['bang_nguon'], _sec(secs, h['bang_nguon']), h['so_muc']))
    print('ham dung         %s' % (
        '0x%06x' % h['ham_dung'] if h['ham_dung'] else 'chua do'))
    print('ten shader       %d' % len(h['ten']))
    co_cs = sum(1 for _, _, cs in h['ten'] if cs is not None)
    print('co chi so        %d' % co_cs)
    lo, hi = h['vung_nguon']
    n_trong = n_ngoai = 0
    for i in range(h['so_muc']):
        v = word(secs, h['bang_nguon'] + 4 * i)
        if v is None or v == 0xffffffff:
            continue
        if lo <= v <= hi:
            n_trong += 1
        else:
            n_ngoai += 1
    print('muc tro vao vung %d / ngoai vung %d' % (n_trong, n_ngoai))
    # Phep kiem khong the doan: moi muc phai tro toi mot cho CO THAT.
    khong_doc = sum(1 for i in range(h['so_muc'])
                    if (word(secs, h['bang_nguon'] + 4 * i) or 0) != 0xffffffff
                    and word(secs, h['bang_nguon'] + 4 * i) is not None
                    and _sec(secs, word(secs, h['bang_nguon'] + 4 * i)) == '?')
    print('muc tro ra ngoai file  %d' % khong_doc)
    return 0


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    # Dia chi trong file nay do ra theo TUNG ban — xem cay.kiem_so_ban(). Dung
    # cay.kiem_so() (cung dia chi VN) thi ban khac bi chan oan, con bo kiem han
    # thi dia chi VN chay tren file 1.31 se ra ket qua sai ma khong bao loi.
    loi = cay.kiem_so_ban()
    if loi:
        sys.exit(loi)
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--ten', action='store_true')
    ap.add_argument('--nguon', action='store_true')
    ap.add_argument('--noi', action='store_true')
    ap.add_argument('--so', action='store_true')
    a = ap.parse_args()
    _, secs = load(PATH)
    print('doan:', ' '.join('%s@0x%x(%d)' % (n, ad, len(d)) for n, ad, d in secs))
    if not any((a.ten, a.nguon, a.noi, a.so)):
        ap.print_help()
        return
    if a.ten:
        ten(secs)
    if a.nguon:
        nguon(secs)
    if a.noi:
        noi(secs)
    if a.so:
        so(secs)


if __name__ == '__main__':
    sys.exit(main())
