"""Soi bang shader trong libgame.so: 18 ten, 28 nguon, va cho NOI hai bang do.

    python shaders.py --ten        # dia chi 18 chuoi ten shader
    python shaders.py --nguon      # bang nguon (.data 0x93caec) + doan dau moi nguon
    python shaders.py --noi        # quet TOAN FILE tim con tro toi ten/nguon
    python shaders.py --so         # chi in ket luan dang so

VI SAO
------
`setGray` (5 ban sao: 0x24efaa, 0x2bd236, 0x2cfa36, 0x2d280e, 0x49d6ea) khong he
nhac tới nguon shader — no chi dung chuoi ten roi goi `vfunc_0x158(ten)`. Muon
biet chuoi `ShaderPositionTextureColor_Gray` ung voi nguon nao trong 28 nguon
cua bang `0x93caec` thi phai tim cho lien ket hai thu do.

**Da xong — bang day du nam o `shaderghep.py --bang`** (chi so -> ten -> nguon
dinh -> nguon manh), va GRAY la **chi so 1**, nguon manh `N[18] = 0x7ccf00`.

Phep quet trong file nay cho ket qua AM, va ly do da ro (do bang `--quanh`):
dia chi chuoi ten duoc dung bang **PC-TUONG-DOI** — `ldr r1, [pc, #imm]` roi
`add r1, pc`, voi o hang so trong literal pool chua `dich - pc`. Nen trong file
KHONG he co 4 byte nao bang dia chi chuoi, va moi phep quet con tro tuyet doi
(ke ca quet toan file o day) khong the tim ra. Ket luan cu ghi o cho khac rang
"dia chi duoc dung bang movw/movt" la mot SUY DOAN, khong phai do.

Con duong dung la doc MA: `shaderghep.py` dich nguoc `.text`, ghep lai tung cap
`ldr`/`add` thanh hang so 32 bit, roi lan theo GOT (`GOC_GOT = 0x92ba60`) toi
bang nguon. Ba tang: `[r5+off]` (o GOT) -> mot phan tu cua bang nguon
(`0x93caec+4i`) -> `ldr` lan nua moi ra chuoi nguon. Vi vay quet con tro
khong bao gio thay nguon: dia chi nguon khong xuat hien trong ma.
"""
import argparse
import struct
import sys

from xref import load

PATH = 'vn/apk/lib/armeabi-v7a/libgame.so'
BANG_NGUON = 0x93caec          # .data: 28 con tro nguon, ket thuc 0xffffffff
TEN_GRAY = 0x7a9515            # .rodata: "ShaderPositionTextureColor_Gray"
TEN_GOC = 0x7a9608             # .rodata: "ShaderPositionTextureColor"

TEN = [
    ('ShaderPositionTextureColor_Gray', 0x7a9515),
    ('ShaderPositionTextureColor', 0x7a9608),
    ('ShaderPosition_uColor', 0x7a96b1),
    ('ShaderPositionTextureColor_Whitened', 0x7acaaa),
    ('ShaderPositionColor', 0x7acba6),
    ('ShaderPositionTextureColor_Orange', 0x7acea8),
    ('ShaderPositionTexture', 0x7ad242),
    ('ShaderPositionTextureColor_Glow', 0x7adca5),
    ('ShaderPositionTexture_uColor', 0x7c491a),
    ('ShaderPositionLengthTextureColor', 0x7c4ec6),
    ('ShaderPositionTextureColorAlphaTest', 0x7c5420),
    ('ShaderLabel_DistanceField_Normal', 0x7cde1b),
    ('ShaderLabel_DistanceField_Glow', 0x7cde3c),
    ('ShaderLabel_Normal', 0x7cde5b),
    ('ShaderLabel_Gradual', 0x7cde6e),
    ('ShaderLabel_Outline', 0x7cde82),
    ('ShaderPositionTextureA8Color', 0x7cde96),
    ('KCCShader_PositionTextureColor_HSL', 0x7cdeb3),
]


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


def la_nguon(v):
    """Dia chi nam trong vung nguon shader (da do: 0x7c6f51..0x7cdab4)?"""
    return v is not None and 0x7c0000 <= v <= 0x7dffff


def ten(secs):
    for t, a in TEN:
        print('  %-38s 0x%06x  %s' % (t, a, _sec(secs, a)))
    return 0


def nguon(secs):
    print('  bang nguon .data 0x%06x:' % BANG_NGUON)
    for i in range(30):
        v = word(secs, BANG_NGUON + 4 * i)
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
        print('    [%2d] 0x%06x  %s' % (i, v, dau))
    return 0


def noi(secs):
    """Cho NOI: moi cho chua con tro toi mot trong 18 chuoi ten.

    Neu co bang {ten -> nguon} thi cho chua con tro ten se NAM SAT mot con tro
    nguon. Do la thu can tim.
    """
    print('quet toan file tim con tro toi 18 chuoi ten:')
    for t, a in TEN:
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


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--ten', action='store_true')
    ap.add_argument('--nguon', action='store_true')
    ap.add_argument('--noi', action='store_true')
    ap.add_argument('--so', action='store_true')
    a = ap.parse_args()
    _, secs = load(PATH)
    print('doan:', ' '.join('%s@0x%x(%d)' % (n, ad, len(d)) for n, ad, d in secs))
    lam = [a.ten, a.nguon, a.noi, a.so]
    if not any(lam):
        ap.print_help()
        return
    if a.ten:
        ten(secs)
    if a.nguon:
        nguon(secs)
    if a.noi:
        noi(secs)


if __name__ == '__main__':
    sys.exit(main())
