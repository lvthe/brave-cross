"""Tim cho GHEP ten shader voi nguon shader trong libgame.so.

    python shaderghep.py                 # quet .text, in cac cum dang quan tam
    python shaderghep.py --cum           # chi in cum co CA ten LAN nguon
    python shaderghep.py --quanh 0x49d6d4  # chi tiet quanh mot dia chi
    python shaderghep.py --nguon         # in 28 nguon va dong dau cua moi nguon
    python shaderghep.py --nguon 8       # in TRON nguon N[8] (nguon dinh dung chung)

VI SAO
------
`shaders.py --noi` quet toan file tim CON TRO toi 18 chuoi ten shader: khong
mot cho nao. Nhung doc ky than ham `setGray` (0x49d6d4) thi thay vi sao:

    0x49d6e8  ldr  r1, [pc, #0x18]      ; nap tu hang so trong .text
    0x49d6ea  add  r1, pc               ; r1 = hang so + PC  -> dia chi chuoi

Dia chi duoc dung bang PC-TUONG-DOI, nen trong file KHONG he co 4 byte nao bang
dia chi chuoi — phep quet con tro tuyet doi khong the tim ra, va ket luan cu
"dia chi duoc dung bang movw/movt" la SAI (do la mot suy doan, khong phai do).

Vi vay phep ghep phai lam o phia MA: dich nguoc `.text`, ghep lai tung cap
`ldr [pc,#imm]` + `add rX, pc` thanh hang so 32 bit, roi xem hang so do roi vao
(a) mot trong 18 chuoi ten, (b) mot trong 28 nguon, (c) dia chi bang nguon
`.data 0x93caec`. Cum nao co CA ten LAN nguon chinh la bang ghep dang tim.

Ghi chu ve do tin cay: phep ghep chi nhan cap `ldr`/`add` cach nhau <= 0x10 byte
va cung thanh ghi — dung khuon ma 5 than ham `setGray` dung. Hang so tuyet doi
(kieu `ldr r1,[pc]` roi dung thang) cung duoc ghi lai, de khong bo sot duong
khac. Moi ket qua deu kem `--quanh` de doi chieu bang capstone.
"""
import argparse
import struct
import sys

import capstone

from xref import load

TEN = {
    0x7a9515: 'ShaderPositionTextureColor_Gray',
    0x7a9608: 'ShaderPositionTextureColor',
    0x7a96b1: 'ShaderPosition_uColor',
    0x7acaaa: 'ShaderPositionTextureColor_Whitened',
    0x7acba6: 'ShaderPositionColor',
    0x7acea8: 'ShaderPositionTextureColor_Orange',
    0x7ad242: 'ShaderPositionTexture',
    0x7adca5: 'ShaderPositionTextureColor_Glow',
    0x7c491a: 'ShaderPositionTexture_uColor',
    0x7c4ec6: 'ShaderPositionLengthTextureColor',
    0x7c5420: 'ShaderPositionTextureColorAlphaTest',
    0x7cde1b: 'ShaderLabel_DistanceField_Normal',
    0x7cde3c: 'ShaderLabel_DistanceField_Glow',
    0x7cde5b: 'ShaderLabel_Normal',
    0x7cde6e: 'ShaderLabel_Gradual',
    0x7cde82: 'ShaderLabel_Outline',
    0x7cde96: 'ShaderPositionTextureA8Color',
    0x7cdeb3: 'KCCShader_PositionTextureColor_HSL',
}

NGUON = [
    0x7c6f51, 0x7ca769, 0x7ca96c, 0x7cac79, 0x7cb013, 0x7cb441, 0x7cb57e,
    0x7cb6bb, 0x7ca769, 0x7cb969, 0x7cbaab, 0x7cbcac, 0x7cc03a, 0x7cc30f,
    0x7cc4ff, 0x7cc7d2, 0x7ccad8, 0x7cccd4, 0x7ccf00, 0x7cd0c1, 0x7ca769,
    0x7cd1dd, 0x7cd3a7, 0x7cd52b, 0x7cd689, 0x7cd804, 0x7cd8f6, 0x7cdab4,
]

BANG_NGUON = 0x93caec
TEXT = '.text'

# Ba dia chi cua bo dang ky shader, do bang cach doc ma (xem `--bang`):
#   0x4d97ec  ham dang ky: moi khoi 0x34 byte = mot ten + mot chi so
#   0x4d8e1c  ham dung chuong trinh: `cmp r2,#0x11` roi `tbh` -> 18 khoi case
#   0x92ba60  goc cua bang con tro (tinh tu `ldr r5,[pc,#0x388]` + `add r5,pc`)
DANG_KY = 0x4d97ec
DUNG_CT = 0x4d8e1c
GOC_GOT = 0x92ba60
NGUON_DINH = 8                 # N[8] = 0x7ca769, nguon dinh dung chung nhieu nhat

md = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
# KHONG co dong nay thi `disasm` DUNG NGAY o byte khong dich duoc dau tien:
# do duoc la ca `.text` 5,6 MB chi ra dung 6 lenh. `skipdata` cho capstone phat
# ra `.byte` cho vung du lieu roi dich tiep — du de quet tuyen tinh, va moi cho
# tim duoc deu duoc kiem lai bang `--quanh` truoc khi tin.
md.skipdata = True


def _nhan(gt):
    if gt in TEN:
        return TEN[gt]
    if gt in NGUON:
        return 'N[%d]' % NGUON.index(gt)
    if gt == BANG_NGUON:
        return 'BANG-NGUON'
    return '?0x%x' % gt


def _doc(data, base, addr, n=4):
    off = addr - base
    if off < 0 or off + n > len(data):
        return None
    return data[off:off + n]


def quet_pc(data, base):
    """Moi cho dung dia chi bang PC-tuong-doi (kieu `ldr [pc]` + `add rX,pc`).

    Tra ve (dia chi lenh ldr, gia tri tinh duoc, kieu) voi kieu la 'tuong-doi'
    hay 'tuyet-doi'.
    """
    ra = []
    cho = {}                      # reg -> (dia chi lenh ldr, hang so trong pool)
    for ins in md.disasm(data, base):
        c = ins.op_str
        if ins.mnemonic == 'ldr' and '[pc,' in c:
            try:
                reg = c.split(',')[0].strip()
                imm = int(c.split('#')[1].rstrip(']'), 0)
            except (IndexError, ValueError):
                reg = None
            if reg:
                pc = (ins.address + 4) & ~3
                w = _doc(data, base, pc + imm)
                if w:
                    v = struct.unpack('<I', w)[0]
                    cho[reg] = (ins.address, v)
                    ra.append((ins.address, v, 'tuyet-doi'))
        elif ins.mnemonic == 'add' and c.endswith(', pc'):
            reg = c.split(',')[0].strip()
            t = cho.get(reg)
            if t and ins.address - t[0] <= 0x10:
                del cho[reg]
                pc = (ins.address + 4) & ~3
                ra.append((t[0], (t[1] + pc) & 0xFFFFFFFF, 'tuong-doi'))
        elif ins.mnemonic in ('movw', 'movt'):
            # giu lai de doi chieu: khuon nay KHONG dung cho ten shader, nhung
            # co the dung cho cho khac.
            pass
        # don cho cu
        if len(cho) > 8:
            cho.clear()
    return ra


def cum(cho, khe=0x400):
    ra = []
    for addr, gt, kieu in cho:
        if ra and addr - ra[-1][-1][0] <= khe:
            ra[-1].append((addr, gt, kieu))
        else:
            ra.append([(addr, gt, kieu)])
    return ra


def _W(secs, addr):
    if addr is None:
        return None
    for n, a, d in secs:
        if a <= addr < a + len(d) - 4:
            return struct.unpack_from('<I', d, addr - a)[0]
    return None


def _H(secs, addr):
    if addr is None:
        return None
    for n, a, d in secs:
        if a <= addr < a + len(d) - 2:
            return struct.unpack_from('<H', d, addr - a)[0]
    return None


def _tgt(ins):
    """Dia chi hang so cua `ldr rX, [pc, #imm]`."""
    return ((ins.address + 4) & ~3) + int(ins.op_str.split('#')[1].rstrip(']'), 0)


def _cstr(secs, addr):
    for n, a, d in secs:
        if a <= addr < a + len(d):
            off = addr - a
            return d[off:d.find(b'\0', off)].decode('latin-1')
    return None


def bang(secs):
    """Bang that: chi so -> (ten shader, nguon dinh, nguon manh).

    Hai buoc, moi buoc deu doc tu ma chu khong suy doan:

    1. Ham dang ky `DANG_KY` goi `bl DUNG_CT(ten, chi so)` sau moi khoi 0x34
       byte. Ten lay bang cap `ldr r1,[pc,#imm]` + `add r1, pc` ngay truoc do.
    2. Ham dung chuong trinh `DUNG_CT` la mot `switch` 18 nhanh (`cmp r2,#0x11`
       roi `tbh`). Moi nhanh nap HAI con tro qua bang con tro tai `GOC_GOT`:
       moi o tro toi mot PHAN TU cua bang nguon (.data 0x93caec), roi `ldr`
       lan nua moi ra dia chi chuoi nguon. Do la ly do khong phep quet con tro
       nao tim ra nguon: dia chi nguon chua bao gio xuat hien trong ma.
    """
    base, data = next((ad, d) for n, ad, d in secs if n == TEXT)
    khu = list(md.disasm(data[base - base:], base))     # tam, se thay ben duoi
    del khu
    reg = list(md.disasm(_doc(data, base, DANG_KY, 0x2c0), DANG_KY))
    ten_theo_idx = {}
    for k, i in enumerate(reg):
        if i.mnemonic != 'movs' or not i.op_str.startswith('r2, #'):
            continue
        if not any(g.mnemonic == 'bl' for g in reg[k + 1:k + 5]):
            continue
        try:
            idx = int(i.op_str.split('#')[1], 0)
        except ValueError:
            continue
        # Lui ve cap ldr/add gan nhat. Khoang lui phai du rong: khoi DAU TIEN co
        # `ldr` cach `movs r2` bay lenh (giua chung co ca `push`), cac khoi sau
        # thi cach nam. Thu CA HAI loi tinh PC (cong 4, va can 4) roi chi nhan
        # ket qua bat dau bang 'Shader'/'KCC' — do la mot phep KIEM, khong phai
        # mot phep doan.
        for j in range(k - 1, max(-1, k - 9), -1):
            if reg[j].mnemonic != 'ldr' or '[pc,' not in reg[j].op_str:
                continue
            w = _W(secs, _tgt(reg[j]))
            if w is None:
                break
            truoc = None
            for m in range(j + 1, min(len(reg), j + 4)):
                if reg[m].mnemonic == 'add' and reg[m].op_str.endswith(', pc'):
                    truoc = reg[m]
                    break
            if truoc is None:
                break
            for pc in (truoc.address + 4, (truoc.address + 4) & ~3):
                s = _cstr(secs, (w + pc) & 0xFFFFFFFF)
                if s and (s.startswith('Shader') or s.startswith('KCC')):
                    ten_theo_idx[idx] = s
                    break
            break

    dung = list(md.disasm(_doc(data, base, DUNG_CT, 0x3e0), DUNG_CT))
    tb = DUNG_CT + 0x12                 # bang nhay ngay sau `tbh`
    print('chi so | ten                     | nguon dinh | nguon manh | dia chi')
    for idx in range(18):
        hw = _H(secs, tb + 2 * idx)
        if hw is None:
            continue
        bloc = (tb + 2 * hw) & 0xFFFFFFFF
        cap = []
        for k, i in enumerate(dung):
            if not (bloc <= i.address < bloc + 0x60):
                continue
            if i.mnemonic != 'ldr' or '[pc,' not in i.op_str:
                continue
            r = i.op_str.split(',')[0].strip()
            w = _W(secs, _tgt(i))
            if w is None:
                continue
            if w > 0x80000000:
                w -= 1 << 32
            for j in dung[k + 1:k + 4]:
                if j.mnemonic == 'ldr' and ('[r5, %s]' % r) in j.op_str:
                    pt = _W(secs, (GOC_GOT + w) & 0xFFFFFFFF)
                    if pt and BANG_NGUON <= pt <= BANG_NGUON + 4 * 27:
                        cap.append((pt - BANG_NGUON) // 4)
                    break
        if len(cap) < 2:
            print('%6d | %-23s | (khong giai duoc khoi 0x%06x)' % (idx, '', bloc))
            continue
        iv, im = cap[0], cap[1]
        ad = NGUON[im]
        s = _cstr(secs, ad) or ''
        mau = next((l.strip() for l in s.splitlines() if 'gl_FragColor' in l), '')
        print('%6d | %-23s | N[%2d]      | N[%2d]      | 0x%06x  %s' % (
            idx, ten_theo_idx.get(idx, '?'), iv, im, ad, mau[:44]))
    return 0


def in_nguon(chi_so=None):
    e, secs = load()
    for i, ad in enumerate(NGUON):
        s = b''
        for n, a, d in secs:
            if a <= ad < a + len(d):
                off = ad - a
                s = d[off:d.find(b'\0', off)]
                break
        if chi_so is not None and i != chi_so:
            continue
        if chi_so is not None:
            print('N[%d] 0x%06x  %d byte\n---' % (i, ad, len(s)))
            print(s.decode('latin-1'))
            print('---')
            continue
        dong = [l.strip() for l in s.decode('latin-1').splitlines() if l.strip()]
        dau = dong[1] if len(dong) > 1 else (dong[0] if dong else '')
        print('  N[%2d] 0x%06x %4d byte  %s' % (i, ad, len(s), dau[:70]))
    return 0


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--cum', action='store_true')
    ap.add_argument('--nguon', nargs='?', const=-1, type=int,
                    metavar='I', help='liet ke 28 nguon, hoac in tron nguon N[I]')
    ap.add_argument('--bang', action='store_true',
                    help='bang that: chi so -> ten shader + nguon dinh/manh')
    ap.add_argument('--han', type=int, default=60)
    ap.add_argument('--quanh', default=None)
    a = ap.parse_args()
    if a.nguon is not None:
        return in_nguon(None if a.nguon < 0 else a.nguon)

    e, secs = load()
    if a.bang:
        return bang(secs)
    base, data = next((ad, d) for n, ad, d in secs if n == TEXT)
    if a.quanh:
        addr = int(a.quanh, 0)
        print('=== ban dich capstone quanh 0x%06x ===' % addr)
        for i in md.disasm(_doc(data, base, addr, 0x60), addr):
            print('  0x%06x  %-10s %s' % (i.address, i.mnemonic, i.op_str))
        print('=== gia tri PC-tuong-doi quanh do ===')
        print('   (xem bang cach chay lai khong co --quanh)')
        return 0

    print('dich nguoc .text (%d byte)...' % len(data))
    ch = quet_pc(data, base)
    print('cho dung dia chi: %d (%d tuong doi, %d tuyet doi)' % (
        len(ch),
        sum(1 for x in ch if x[2] == 'tuong-doi'),
        sum(1 for x in ch if x[2] == 'tuyet-doi')))
    for ds, ten_ds in ((TEN, 'ten shader'), ({v: v for v in NGUON}, 'nguon shader'),
                       ({BANG_NGUON: 1}, 'bang nguon')):
        for kieu in ('tuong-doi', 'tuyet-doi'):
            dem = sum(1 for _, gt, k in ch if k == kieu and gt in ds)
            print('  tro toi %-12s kieu %-9s %d' % (ten_ds, kieu, dem))
    quan_tam = set(TEN) | set(NGUON) | {BANG_NGUON}
    cho = [(ad, gt, k) for ad, gt, k in ch if gt in quan_tam]
    cs = cum(cho)
    print('cum (khe 0x400): %d' % len(cs))
    in_ra = 0
    for c in cs:
        co_ten = any(gt in TEN for _, gt, _ in c)
        co_nguon = any(gt in NGUON or gt == BANG_NGUON for _, gt, _ in c)
        if a.cum and not (co_ten and co_nguon):
            continue
        in_ra += 1
        if in_ra > a.han:
            print('  ... con nua')
            break
        print('\n  cum 0x%06x..0x%06x  %d cho  %s' % (
            c[0][0], c[-1][0], len(c),
            'TEN+NGUON' if co_ten and co_nguon else ('TEN' if co_ten else 'NGUON')))
        for ad, gt, k in c:
            print('    0x%06x  %-34s %s' % (ad, _nhan(gt), k))
    return 0


if __name__ == '__main__':
    sys.exit(main())
