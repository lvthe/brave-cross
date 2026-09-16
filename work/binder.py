"""Doc bang bind Lua trong libgame.so: lop -> bang phuong thuc.

    python binder.py --bang              # 132 lop, so ban ghi, co setGray/setOrange
    python binder.py --xam               # chi ket luan ve setGray / setOrange
    python binder.py --lop CCProgressTimer
    python binder.py --slot 0x290        # slot vtable -> ten, va lop nao lo ra
    python binder.py --settype           # sau ten cua setType + hang so chung minh

VI SAO
------
Engine nay lo ra cho Lua theo TUNG LOP: moi lop co mot bang ten phuong thuc, va
chuoi `lItemBackground:setGray(true)` chi chay duoc neu lop C++ cua node do co
ban ghi `setGray`. Nen cau hoi "ban goc co to xam duoc loai node nay khong" la
cau hoi doc bang, khong phai cau hoi suy luan — ma truoc day ta chi suy ra tu
viec cac dong ay bi comment san. Cong cu nay da can it nhat ba lan: `SetCameraScale`
(.data 0x939704 -> 0x467fb4), CCProgressTimer, va setGray/setOrange.

DINH DANG (do bang cach doi chieu noi dung, khong phai doc tai lieu)
--------------------------------------------------------------------
* Ten 132 lop: 132 con tro chuoi lien nhau o `.rodata` 0x92a5ec.
* Bang phuong thuc: 132 con tro lien nhau o `.data` 0x92a814, cung thu tu lop.
* Moi bang la mot day ban ghi **12 byte** `{con_tro_ten, A, B}`:
    B == 0  ->  A la DIA CHI MA (ham C, bit 0 = 1 nghia la Thumb)
    B == 1  ->  A la SO HIEU SLOT trong giao dien node dung chung
  Slot da doi chieu cheo voi ghi chu trong CLAUDE.md (`setPosition` o slot
  `+0x74` cua `cocos2d::sngCCNodeFixInfo`) — khop.
* **Moi bang ket thuc bang mot ban ghi 12 byte toan so 0.** Day la moc chan that:
  **131/132** bang ket thuc dung o moc chan (do bang chinh cong cu nay), khong
  bang nao bi cat vi ten khong doc duoc. Moc chan nay cung la thu pha vo gia
  thuyet "cac bang nam lien nhau, lop sau bat dau ngay sau lop truoc": trong 131
  khe giua cac dia chi bat dau da sap xep, **ba khe khong chia het cho 12**
  (0x934a24->0x934ad0 = 172 byte; 0x9363e4->0x939f7c = 15.256;
  0x93ae1c->0x9596b4 = 125.080). Doc theo moc chan cho so KHAC HAN doc theo khe:
  lop `Label` ra **99** ban ghi chu khong phai 119 — tuc loi doc theo khe da chay
  tran qua 20 ban ghi sang bang lop ke tiep. Vi vay moi so dem o day deu lay theo
  moc chan.
* Mot so lop dang ky TRUNG ten (vd `release` xuat hien 159 luot tren 132 lop;
  `CCLabelBMFont` lap ca bo giao dien node). Day la dang ky hai lan that, khong
  phai doc tran: phan lap lai chinh API cua chinh lop do, khong he co ten la.
* Kiem chung noi dung (dung hai lop doc lap nhau): lop 0 `SimpleAudioEngine` ra
  `end/setResource/preloadBackgroundMusic/playBackgroundMusic/stopBackgroundMusic/
  pauseBackgroundMusic`; lop 8 `CCLabelTTF` ra `setString/getString/initWithString/
  getFontSize/setHorizontalAlignment`; lop 20 `CCProgressTimer` ra
  `getPercentage/setPercentage/initWithFile/setType`.
* Mot ngoai le da gap: lop 113 `CCSpriteFrame` co con tro bang tro toi 0x9596b4,
  cho do khong doc ra ten nao. Ghi lai la biet, khong sua.

KET QUA DA DO (dung lam suy luon cho phan khac)
----------------------------------------------
* `setGray` co tren **dung 5 lop**: CCSprite, CCScale9Sprite, CCButton, Label,
  CCProgressTimer. **`CCLabelTTF` KHONG co** — nen o ban goc goi `setGray` len mot
  nhan CCLabelTTF la loi Lua that, va do la ly do CO HOC khien cac dong ay bi
  comment san trong ma goc.
  Nhung `setGray` KHONG phai mot ham duy nhat: CCSprite va CCButton dung CHUNG mot
  dia chi ma (0x49d70d), CCScale9Sprite rieng (0x2d2839), `Label` rieng (0x2cb1c9),
  CCProgressTimer thi qua slot +0x290. Bon duong, khong phai mot.
* `setOrange` co tren **dung 1 lop**: CCProgressTimer — khop dung 6 cho goi trong
  ma goc, ca 6 deu la progress timer.
* `CCLayerColorRoundRect` khong co `setGray` lan `setOrange`.
* Co **hai** lop progress timer, khong phai mot: `setPercentage`/`getPercentage`/
  `setType` co trong dung 2 bang — `CCProgressTimer` (20) va `CCProgressWithClock`
  (125), ca hai 71 ban ghi va **dung chung** dia chi ma (getPercentage 0x2bccb5,
  setPercentage 0x2bd095, setType 0x2bd439). Lop 125 them `setClock` (0x2bd98b) /
  `stopClock` (0x2bda11); con `setGray` +0x290 va `setOrange` +0x298 thi **chi**
  lop 20 co.

setType (do o `--settype`)
--------------------------
Chuoi `setType` nhan **chuoi**, khong nhan so enum. Sau ten, doc ra tu o hang so
PC-tuong-doi trong chinh than ham: `ccw`, `cw`, `lr`, `rl`, `bt`, `tb`.
`ccw`/`cw` khong dat hinh dang gi, chi goi 0x4c9030 voi 1/0 (doc ra nho thanh
ghi: nhanh `ccw` nhay thang toi lenh `bl`, BO QUA lenh `mov r1, r5`, nen r1 van
la 1). Bon ten con lai truyen 0 roi dat hai method nhan cap float o vtable
`+0x280` va `+0x288`. Hai slot do **khong co ban ghi bind nao** -> khong lo ra
cho Lua, nen TEN cua chung khong doc duoc; con so thi do duoc.

Chay `python binder.py --settype` de in lai ca phep do.
"""
import argparse
import collections
import struct
import sys

import capstone

from xref import load

PATH = 'vn/apk/lib/armeabi-v7a/libgame.so'
BASE_TEN = 0x92a5ec            # .rodata: 132 con tro ten lop
BASE_BANG = 0x92a814           # .data:   132 con tro bang phuong thuc
SETTYPE_THUNK = 0x2bd438       # thunk bind cua setType (goi than that 0x2bd2d8)
SETTYPE_THAN = 0x2bd2d8        # than that: chuoi so sanh -> dat hinh dang
# Bon nhan dat hinh dang: (ten, dia chi lenh blx goi vtable, cap +0x280, cap +0x288)
# Doc tu ban dich; ghi dia chi lenh de con doi chieu lai duoc.
HINH_DANG = [
    ('lr', 0x2bd336, (0.0, 0.0), (1.0, 0.0)),
    ('rl', 0x2bd374, (1.0, 0.0), (1.0, 0.0)),
    ('bt', 0x2bd3b0, (0.0, 0.0), (0.0, 1.0)),
    ('tb', 0x2bd404, (0.0, 1.0), (0.0, 1.0)),
]


class Soi:
    def __init__(self, path=PATH):
        self.elf, self.secs = load(path)
        self.rod = None
        for n, a, d in self.secs:
            if n == '.rodata':
                self.rod = (a, d)
        self.ten = [self.chuoi(self.word(BASE_TEN + 4 * i)) for i in range(132)]

    def _o(self, addr):
        for n, a, d in self.secs:
            if a <= addr < a + len(d):
                return d, a, n
        return None, None, None

    def word(self, addr):
        d, a, _ = self._o(addr)
        return struct.unpack_from('<I', d, addr - a)[0] if d else None

    def chuoi(self, v):
        """Con tro -> chuoi ascii ngan, hoac None neu khong phai con tro chuoi."""
        if not v or not self.rod:
            return None
        a, d = self.rod
        if not (a <= v < a + len(d)):
            return None
        raw = d[v - a:v - a + 64].split(b'\x00')[0]
        try:
            t = raw.decode('ascii')
        except UnicodeDecodeError:
            return None
        return t if t and all(32 <= ord(c) < 127 for c in t) else None

    def bang(self, i):
        """Bang phuong thuc cua lop i, dung lai o ban ghi 12 byte toan so 0."""
        a = self.word(BASE_BANG + 4 * i)
        ra = []
        while True:
            if self.word(a) == 0 and self.word(a + 4) == 0 and self.word(a + 8) == 0:
                break
            ten = self.chuoi(self.word(a))
            if ten is None:
                break
            ra.append((a, ten, self.word(a + 4), self.word(a + 8)))
            a += 12
            if len(ra) > 400:
                break
        return ra

    def tat_ca(self):
        return {self.ten[i]: self.bang(i) for i in range(132)}

    def theo_slot(self):
        ra = collections.defaultdict(list)
        for i in range(132):
            for _, ten, A, B in self.bang(i):
                if B == 1:
                    ra[A].append((self.ten[i], ten))
        return ra


def _so(ten):
    """Tham so --lop: so thu tu hoac ten lop."""
    return int(ten, 0) if ten.lower().startswith('0x') or ten.isdigit() else ten


def lam_bang(s):
    print('%-4s %-24s %8s  %s' % ('so', 'lop', 'ban ghi', 'setGray/setOrange'))
    gray, orange = [], []
    tong = 0
    for i in range(132):
        b = s.bang(i)
        ten = [t for _, t, _, _ in b]
        co = []
        if 'setGray' in ten:
            co.append('setGray')
            gray.append(s.ten[i])
        if 'setOrange' in ten:
            co.append('setOrange')
            orange.append(s.ten[i])
        tong += len(b)
        print('%-4d %-24s %8d  %s' % (i, s.ten[i], len(b), ', '.join(co)))
    print()
    print('tong: 132 lop, %d ban ghi' % tong)
    print('setGray   (%d lop): %s' % (len(gray), ', '.join(gray)))
    print('setOrange (%d lop): %s' % (len(orange), ', '.join(orange)))


def lam_xam(s):
    gray, orange = [], []
    for i in range(132):
        ten = [t for _, t, _, _ in s.bang(i)]
        if 'setGray' in ten:
            gray.append(s.ten[i])
        if 'setOrange' in ten:
            orange.append(s.ten[i])
    print('setGray   co tren %d lop: %s' % (len(gray), ', '.join(gray)))
    print('setOrange co tren %d lop: %s' % (len(orange), ', '.join(orange)))
    print()
    print('CCLabelTTF           co setGray: %s' % ('CCLabelTTF' in gray))
    print('CCLayerColorRoundRect co setGray: %s' % ('CCLayerColorRoundRect' in gray))


def lam_lop(s, doi):
    i = doi if isinstance(doi, int) else (s.ten.index(doi) if doi in s.ten else None)
    if i is None:
        print('khong co lop %r' % doi)
        return 1
    b = s.bang(i)
    print('lop %d %s: %d ban ghi, bang o .data 0x%06x' % (
        i, s.ten[i], len(b), s.word(BASE_BANG + 4 * i)))
    for a, ten, A, B in b:
        if B == 0:
            print('  0x%06x  %-42s MA  0x%08x%s' % (a, ten, A, ' (Thumb)' if A & 1 else ''))
        else:
            print('  0x%06x  %-42s SLOT +0x%03x' % (a, ten, A))


def lam_slot(s, slot):
    v = s.theo_slot().get(slot)
    if not v:
        print('+0x%03x: khong ban ghi bind nao (khong lo ra cho Lua)' % slot)
        return 0
    ten = sorted(set(t for _, t in v))
    lop = sorted(set(l for l, _ in v))
    print('+0x%03x: %d ban ghi, ten %s' % (slot, len(v), ten))
    print('        lop: %s' % ', '.join(lop))


def lam_settype(s):
    """In lai phep do: sau chuoi cua setType, doc tu o hang so PC-tuong-doi."""
    d, a, ten_sec = s._o(SETTYPE_THAN)
    md = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
    lenh = list(md.disasm(d[SETTYPE_THAN - a:SETTYPE_THAN - a + 0x120], SETTYPE_THAN))
    print('%-6s %-9s %-11s %s' % ('ldr', 'o hang so', 'gia tri', 'chuoi'))
    for i, l in enumerate(lenh[:-1]):
        if l.mnemonic != 'ldr' or not l.op_str.startswith('r1, [pc,'):
            continue
        # `add r1, pc` KHONG nam ngay sau `ldr`: giua chung co mot lenh `mov r0, r6`
        # (doi so thu nhat ra truoc). Phai do tim toi ba lenh, khong duoc doi ke tiep.
        sau = None
        for k in (1, 2, 3):
            if i + k < len(lenh) and lenh[i + k].mnemonic == 'add' \
                    and lenh[i + k].op_str.endswith(', pc'):
                sau = lenh[i + k]
                break
        if sau is None:
            continue
        imm = int(l.op_str.split('#')[-1].rstrip(']'), 0)
        o = ((l.address + 4) & ~3) + imm
        w = s.word(o)
        for pc in (sau.address + 4, sau.address + 8):
            t = (w + pc) & 0xffffffff
            if s.chuoi(t):
                print('0x%04x 0x%06x  0x%08x %r' % (l.address, o, w, s.chuoi(t)))
                break
    print()
    print('bon nhan dat hinh dang (dia chi lenh blx goi vtable, doc tu ban dich):')
    for ten, blx, c280, c288 in HINH_DANG:
        print('  %-4s blx 0x%06x   vtable+0x280 <- %-12s vtable+0x288 <- %s' % (
            ten, blx, str(c280), str(c288)))
    print('  ccw/cw: khong dat cap float nao, chi goi 0x4c9030 voi 1/0')
    print()
    print('hai slot +0x280 va +0x288:')
    lam_slot(s, 0x280)
    lam_slot(s, 0x288)


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--bang', action='store_true')
    ap.add_argument('--xam', action='store_true')
    ap.add_argument('--lop', metavar='TEN|SO')
    ap.add_argument('--slot', metavar='0xNNN')
    ap.add_argument('--settype', action='store_true')
    a = ap.parse_args()
    s = Soi()
    if a.bang:
        lam_bang(s)
    if a.xam:
        lam_xam(s)
    if a.lop:
        return lam_lop(s, _so(a.lop))
    if a.slot:
        return lam_slot(s, int(a.slot, 0))
    if a.settype:
        lam_settype(s)
    if not any((a.bang, a.xam, a.lop, a.slot, a.settype)):
        ap.print_help()
    return 0


if __name__ == '__main__':
    sys.exit(main())
