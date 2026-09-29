"""Doc bang bind Lua trong libgame.so: lop -> bang phuong thuc.

    python binder.py --bang              # 132 lop, so ban ghi, co setGray/setOrange
    python binder.py --xam               # chi ket luan ve setGray / setOrange
    python binder.py --lop CCProgressTimer
    python binder.py --slot 0x290        # slot vtable -> ten, va lop nao lo ra
    python binder.py --settype           # sau ten cua setType + hang so chung minh
    python binder.py --nut               # cac o cua node + pauseActions/resumeActions

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
* Moi bang la mot day ban ghi **12 byte** `{con_tro_ten, A, B}`:
    B == 0  ->  A la DIA CHI MA (ham C, bit 0 = 1 nghia la Thumb)
    B == 1  ->  A la SO HIEU SLOT trong giao dien node dung chung
  Slot da doi chieu cheo voi ghi chu trong CLAUDE.md (`setPosition` o slot
  `+0x74` cua `cocos2d::sngCCNodeFixInfo`) — khop.
* **Moi bang ket thuc bang mot ban ghi 12 byte toan so 0.** Day la moc chan that:
  tren ban VN **131/132** bang ket thuc dung o moc chan (do bang chinh cong cu
  nay), khong bang nao bi cat vi ten khong doc duoc. Moc chan nay cung la thu pha
  vo gia thuyet "cac bang nam lien nhau, lop sau bat dau ngay sau lop truoc":
  trong 131 khe giua cac dia chi bat dau da sap xep, **ba khe khong chia het cho
  12** (0x934a24->0x934ad0 = 172 byte; 0x9363e4->0x939f7c = 15.256;
  0x93ae1c->0x9596b4 = 125.080). Doc theo moc chan cho so KHAC HAN doc theo khe:
  lop `Label` ra **99** ban ghi chu khong phai 119 — tuc loi doc theo khe da chay
  tran qua 20 ban ghi sang bang lop ke tiep. Vi vay moi so dem o day deu lay theo
  moc chan.
* Mot so lop dang ky TRUNG ten (vd `release` xuat hien 159 luot tren 132 lop;
  `CCLabelBMFont` lap ca bo giao dien node). Day la dang ky hai lan that, khong
  phai doc tran: phan lap lai chinh API cua chinh lop do, khong he co ten la.
* Kiem chung noi dung (dung hai lop doc lap nhau), ban VN: lop 0
  `SimpleAudioEngine` ra `end/setResource/preloadBackgroundMusic/
  playBackgroundMusic/stopBackgroundMusic/pauseBackgroundMusic`; lop 8
  `CCLabelTTF` ra `setString/getString/initWithString/getFontSize/
  setHorizontalAlignment`; lop 20 `CCProgressTimer` ra
  `getPercentage/setPercentage/initWithFile/setType`.
* Mot ngoai le da gap o CA HAI ban: lop `CCSpriteFrame` co con tro bang tro toi
  mot cho khong doc ra ten nao (VN 0x9596b4, chi so 113; cn131 0xade77c, chi so
  111). Ghi lai la biet, khong sua.

HAI KIEU BO TRI MANG LOP — VA SECTION KHONG PHAI `.rodata`/`.data`
------------------------------------------------------------------
Ban dau tai lieu nay ghi ten lop o `.rodata` va bang phuong thuc o `.data`. **Sai
ca hai**: doc theo section that thi nam trong `.got` (VN 0x92a07c-0x92c000,
cn131 0xaa7f14-0xaae000). Chung la o GOT duoc dien bang relocation luc nap
(`R_ARM_RELATIVE`), nen trong FILE chung da giu san dia chi dung — do la ly do
doc thang ra ten duoc. Dia chi thi van dung, chi section ghi sai.

Hai ban khong dat mang lop giong nhau (do ra 2026-09-19 khi chay 1.31):

    'hai-mang'  VN 1.26   HAI mang roi nhau, moi mang buoc 4:
        BASE_TEN  0x92a5ec  .got  132 con tro chuoi, lien nhau
        BASE_BANG 0x92a814  .got  132 con tro bang, cung thu tu, lien nhau
    'cap-lien'  CN 1.31   TUNG CAP (ten, bang) NAM LIEN NHAU, buoc 8:
        BASE_TEN  0xaa8584  .got  [ten0][bang0][ten1][bang1]...
        KHONG co BASE_BANG: dia chi bang di kem tung lop, nen
        `BASE_BANG + buoc*i` la VO NGHIA o kieu nay.

Voi kieu `cap-lien`, giua vai cap co o GOT KHAC xen vao (2 o sau CCEditBox, 1 o
sau CCWheelDisk, 4 o o cuoi) — nen phai DI TUAN TU chu khong duoc doc bang
`base + 8*i`. Ban 1.31 co **129 lop**, khong phai 132: bo `CCScale9Sprite`,
`CCSprite`, `ProtocolAnalytics`. Do bang cach doi chieu DAY TEN chu khong theo
chi so.

Hang so cua tung ban nam trong `SO_BAN` duoi day. Cong cu DO ra chung la
`tim_bang.py` (doc lap, khong dung hang so trong file nay — hai duong doc khac
nhau cho cung ket qua la bang chung, xem `tim_bang.py --doi-chieu`).

KET QUA DA DO (dung lam suy luon cho phan khac)
----------------------------------------------
* `setGray` tren ban VN co **dung 5 lop**: CCSprite, CCScale9Sprite, CCButton,
  Label, CCProgressTimer. **`CCLabelTTF` KHONG co** — nen o ban goc goi `setGray`
  len mot nhan CCLabelTTF la loi Lua that, va do la ly do CO HOC khien cac dong
  ay bi comment san trong ma goc.
* **Ban 1.31: `setGray` chi con 3 lop** — Label, CCProgressTimer, CCButton
  (do bang `BC_TREE=cn131 python binder.py --xam`, 2026-09-19). Mat hai lop
  CCSprite va CCScale9Sprite, dung hai lop ma 1.31 bo khoi so dang ky
  (129 = 132 - 3, xem dau file). Hai duong do doc lap — dem lop theo ten, va dem
  `setGray` theo bang — ra cung mot ket qua, nen day khong phai loi doc bang.
  He qua cho ban dung lai: o 1.31, goi `setGray` len mot node kieu CCSprite la
  loi Lua that. `setOrange` van **dung 1 lop** o ca hai ban: CCProgressTimer.
  `Label` o 1.31 ra **99** ban ghi — trung con so cua VN, them mot bang chung
  nua cho quy tac "dem theo moc chan, khong dem theo khe".
* `setGray` KHONG phai mot ham duy nhat (do tren VN): CCSprite va CCButton dung
  CHUNG mot dia chi ma (0x49d70d), CCScale9Sprite rieng (0x2d2839), `Label` rieng
  (0x2cb1c9), CCProgressTimer thi qua slot +0x290. Bon duong, khong phai mot.
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
Chuoi `setType` nhan **chuoi**, khong nhan so enum. Sau ten: `ccw`, `cw`, `lr`,
`rl`, `bt`, `tb` — sau chuoi do so sanh theo DUNG thu tu ay o CA HAI ban (do lai
2026-09-19), nhung CHO CHUA chuoi khac nhau:

    vn     .rodata, nap bang `ldr r1,[pc,#imm]` roi `add r1, pc`
    cn131  NGAY TRONG `.text`, ngay sau than ham, thang `adr r1, #imm`
           (0x4434ec 'ccw', 0x4434f0 'cw', 0x4434f4 'lr', 0x4434f8 'rl',
            0x4434fc 'bt', 0x443500 'tb' — moi chuoi mot o 4 byte)

Do la ly do mot phep tim chuoi quet `.rodata` khong thay gi tren ban 1.31.

`ccw`/`cw` khong dat hinh dang gi, chi goi ham dat huong quay voi 1/0 (vn
0x4c9030, cn131 0x49e474; doc ra nho thanh ghi: nhanh `ccw` nhay thang toi lenh
`bl`, BO QUA lenh `mov r1, r5`, nen r1 van la 1). Bon ten con lai truyen 0 roi
dat hai method nhan cap float o vtable `+0x280` va `+0x288`. Hai slot do **khong
co ban ghi bind nao** -> khong lo ra cho Lua, nen TEN cua chung khong doc duoc;
con so thi do duoc.

**Bon cap so GIONG HET NHAU giua hai ban** — lr (0,0)+(1,0); rl (1,0)+(1,0); bt
(0,0)+(0,1); tb (0,1)+(0,1) — chi dia chi lenh la khac. Do la mot phep kiem doc
lap cho ca hai lan do: hai ban khac han nhau ve bo cuc ma doc ra cung bon cap.

Mot cho de doc nham: o CA HAI ban, lenh `blx` ghi `+0x288` la MOT DIEM CHUNG cho
ca bon hinh dang (vn 0x2bd406, cn131 0x4434b8) — cap so van khac nhau vi r1/r2
duoc dat truoc khi nhay toi do, chu khong phai bon lenh rieng. Tai lieu cu cua
ban VN ghi dia chi cua `tb` la 0x2bd404, tuc diem chung ay, trong khi ba hinh
dang kia ghi diem `+0x280` — nay ghi ro CA HAI diem cho tung hinh dang.

Chay `python binder.py --settype` de in lai ca phep do.

CAC O CUA NODE, va `pauseActions` (do o `--nut`)
------------------------------------------------
Bay ham action cua node bind vao cung mot ho ham trong .text, va moi ham doc
dung mot o co dinh tren doi tuong:

    +0xdc  bo quan ly action  -- runAction 0x4ae7d4, stopAllActions 0x4ae800,
                                 stopActionByTag 0x4ae838, getActionByTag
                                 0x4ae868, numberOfRunningActions 0x4ae890
    +0xd8  bo hen gio         -- KHONG mot ham action nao doc no
    +0xe0  m_bRunning (bool)

`runAction` (0x4ae7e4) va ho ham hen gio (0x4ae89e) deu doc `ldrb r3,[r0,#0xe0]`
roi `eor r3, r3, #1` truoc khi truyen xuong — dung phep PHU DINH do la dau vet
nhan ra `!m_bRunning`, dung chu ky `CCNode::runAction` / `CCNode::schedule` cua
Cocos2d-x. Nen ba o tren la do, khong phai suy tu ten.

`pauseActions` (0x4aeb88) va `resumeActions` (0x4aeacc) moi ham goi **CA HAI**
bo, khong phai chi action:

    0x4aeb8e  ldr.w r0, [r0, #0xd8] ; bl 0x49fcd0     ; hen gio  <- pause
    0x4aeb96  ldr.w r0, [r4, #0xdc] ; b.w 0x4a9920    ; action   <- pause
    0x4aead2  ldr.w r0, [r0, #0xd8] ; bl 0x49fb44     ; hen gio  <- resume
    0x4aeada  ldr.w r0, [r4, #0xdc] ; b.w 0x4a99dc    ; action   <- resume

Tuc `pauseActions` chinh la `pauseSchedulerAndActions` cua Cocos nhu ban goc
dat ten. He qua dung cho ban dung lai: tam dung mot node thi hen gio cua node
do (`S_CCSchedule:scheduleOnce(node, ...)`) **cung dung theo**. Quet ca 132
bang khong thay ham rieng nao de dung bo hen gio (`pause` 2 lop, `resume` 2,
`schedule`/`scheduleOnce`/`scheduleUpdate` chi o lop `CCSchedule`) — nen day la
duong DUY NHAT.
"""
import argparse
import collections
import struct
import sys

import capstone

from xref import load

import cay

PATH = cay.SO

#: Hang so do ra cho TUNG ban. Moi ban mot bo: ba file .so cua ba ban khac han
#: nhau ve bo cuc (khong mot doan byte nao giong nhau), nen dia chi cua ban nay
#: dan sang file cua ban kia la sai het — khong phai lech vai byte.
#:
#:   kieu         'hai-mang' (VN) hay 'cap-lien' (cn131) — xem dau file
#:   base_ten     dia chi mang ten lop trong .got
#:   base_bang    dia chi mang bang phuong thuc — CHI co o kieu 'hai-mang'
#:   so_lop       so lop dang ky (VN 132, cn131 129)
#:   settype_*    thunk bind + than ham setType
#:   hinh_dang    (ten, blx +0x280, blx +0x288, cap +0x280, cap +0x288)
#:   chuoi_shape  cho chua sau chuoi so sanh ('rodata' hay 'text' — xem tai lieu)
#:   quay_1_0     ham dat huong quay ma ccw/cw goi voi 1/0
SO_BAN = {
    'vn': dict(
        kieu='hai-mang',
        base_ten=0x92a5ec, base_bang=0x92a814, so_lop=132,
        settype_thunk=0x2bd438, settype_than=0x2bd2d8,
        chuoi_shape='rodata', quay_1_0=0x4c9030,
        hinh_dang=[
            ('lr', 0x2bd336, 0x2bd406, (0.0, 0.0), (1.0, 0.0)),
            ('rl', 0x2bd374, 0x2bd406, (1.0, 0.0), (1.0, 0.0)),
            ('bt', 0x2bd3b0, 0x2bd406, (0.0, 0.0), (0.0, 1.0)),
            ('tb', 0x2bd3ee, 0x2bd406, (0.0, 1.0), (0.0, 1.0)),
        ],
    ),
    'cn131': dict(
        kieu='cap-lien',
        base_ten=0xaa8584, base_bang=None, so_lop=129,
        settype_thunk=0x44312a, settype_than=0x4433a4,
        chuoi_shape='text', quay_1_0=0x49e474,
        hinh_dang=[
            ('lr', 0x443454, 0x4434b8, (0.0, 0.0), (1.0, 0.0)),
            ('rl', 0x443474, 0x4434b8, (1.0, 0.0), (1.0, 0.0)),
            ('bt', 0x44349e, 0x4434b8, (0.0, 0.0), (0.0, 1.0)),
            ('tb', 0x44341e, 0x4434b8, (0.0, 1.0), (0.0, 1.0)),
        ],
    ),
}

#: Ten lop ma cac dia chi CUNG trong file nay (`--nut`) do ra — ban VN.
#: `--nut` tu choi chay o ban khac thay vi in ra mot bang sai.
BAN_NUT = 'vn'


def _dinh_danh(s, v):
    """Con tro -> mot TEN dinh danh C++ (chu, so, _, :, ~), hoac None.

    Bo loc nay moi la thu phan biet "mot o la TEN LOP" voi "mot o GOT khac xen
    vao" — khong phai viec doc ra duoc chuoi. O GOT tro vao `.data` cung "doc ra
    chuoi" duoc neu gap byte nao tinh co la chu: bo loc di thi phep di tuan tu
    cua kieu `cap-lien` nhat duoc rac (`5)P`) va ca mang lop sai han.
    """
    t = s.chuoi(v)                 # `chuoi` gioi han trong .rodata, xem Soi.chuoi
    if not t or len(t) > 60:
        return None
    return t if all(c.isalnum() or c in '_~:' for c in t) else None


def _chuoi_o(d, a, v):
    """Chuoi ascii ngan tai dia chi `v` trong section (d, a). Khac `Soi.chuoi`:
    doc o BAT KY section nao, khong chi `.rodata` — ban 1.31 dat chuoi hinh dang
    ngay trong `.text` (xem `_chuoi_settype`)."""
    if not v or not (a <= v < a + len(d)):
        return None
    raw = d[v - a:v - a + 64].split(b'\x00')[0]
    try:
        t = raw.decode('ascii')
    except UnicodeDecodeError:
        return None
    return t if t and all(32 <= ord(c) < 127 for c in t) else None


class Soi:
    """Doc bang bind cua ban dang chon (BC_TREE). Xem `SO_BAN`."""

    def __init__(self, path=None, ban=None):
        self.ban = ban or cay.TEN
        if self.ban not in SO_BAN:
            raise SystemExit('chua do hang so bang bind cho ban %r' % self.ban)
        self.h = SO_BAN[self.ban]
        self.elf, self.secs = load(path or PATH)
        self.rod = None
        for n, a, d in self.secs:
            if n == '.rodata':
                self.rod = (a, d)
        n = self.h['so_lop']
        if self.h['kieu'] == 'hai-mang':
            self.ten = [_dinh_danh(self, self.word(self.h['base_ten'] + 4 * i))
                        for i in range(n)]
            self.bang_o = [self.word(self.h['base_bang'] + 4 * i)
                           for i in range(n)]
        else:
            # Kieu cap-lien: phai DI TUAN TU tu base_ten, khong duoc tinh
            # `base + buoc*i` — giua vai cap co o GOT khac xen vao (xem dau file).
            self.ten, self.bang_o = self._doc_cap_lien(self.h['base_ten'])

    def _doc_cap_lien(self, base, toi_da=400):
        """Kieu `cap-lien`: DI TUAN TU, cap (ten, bang) nam lien nhau, buoc 8.

        O nao doc ra TEN LOP thi do la mot lop, va bang cua no la o NGAY SAU; o
        khac xen vao thi BO QUA. Khong duoc coi `base + 8*i` la lop thu i: ban
        1.31 co 2 o GOT xen sau CCEditBox, 1 sau CCWheelDisk, 4 o o cuoi, nen
        dem theo chi so se lech dan va mat lop.
        """
        ten, bang = [], []
        for i in range(toi_da):
            t = _dinh_danh(self, self.word(base + 4 * i))
            if t:
                ten.append(t)
                bang.append(self.word(base + 4 * (i + 1)))
        return ten, bang

    def _o(self, addr):
        for n, a, d in self.secs:
            if a <= addr < a + len(d):
                return d, a, n
        return None, None, None

    def word(self, addr):
        d, a, _ = self._o(addr)
        if d is None or addr + 4 > a + len(d):
            return None
        return struct.unpack_from('<I', d, addr - a)[0]

    def chuoi(self, v):
        """Con tro -> chuoi ascii ngan, hoac None neu khong phai con tro chuoi.

        Giu gioi han trong `.rodata`: day la duong doc TEN LOP, ma ten lop la con
        tro chuoi that; noi long ra se nhan nham du lieu `.text` lam ten.
        """
        if not v or not self.rod:
            return None
        a, d = self.rod
        if not (a <= v < a + len(d)):
            return None
        return _chuoi_o(d, a, v)

    def bang(self, i):
        """Bang phuong thuc cua lop i, dung lai o ban ghi 12 byte toan so 0."""
        if not 0 <= i < len(self.bang_o):
            return []
        a = self.bang_o[i]
        if a is None:
            return []
        ra = []
        while True:
            if self.word(a) == 0 and self.word(a + 4) == 0 and self.word(a + 8) == 0:
                break
            ten = _dinh_danh(self, self.word(a))
            if ten is None:
                break
            ra.append((a, ten, self.word(a + 4), self.word(a + 8)))
            a += 12
            if len(ra) > 400:
                break
        return ra

    def tat_ca(self):
        return {self.ten[i]: self.bang(i) for i in range(len(self.ten))}

    def theo_slot(self):
        ra = collections.defaultdict(list)
        for i in range(len(self.ten)):
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
    for i in range(len(s.ten)):
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
    print('tong: %d lop, %d ban ghi' % (len(s.ten), tong))
    print('setGray   (%d lop): %s' % (len(gray), ', '.join(gray)))
    print('setOrange (%d lop): %s' % (len(orange), ', '.join(orange)))


def lam_xam(s):
    gray, orange = [], []
    for i in range(len(s.ten)):
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
    if s.bang_o[i] is None:
        print('lop %d %s: o bang la 0 — lop nay khong co bang (xem dau file)'
              % (i, s.ten[i]))
        return 1
    _, _, sec = s._o(s.bang_o[i])
    print('lop %d %s: %d ban ghi, bang o %s 0x%06x' % (
        i, s.ten[i], len(b), sec, s.bang_o[i]))
    for a_, ten, A, B in b:
        if B == 0:
            print('  0x%06x  %-42s MA  0x%08x%s' % (a_, ten, A, ' (Thumb)' if A & 1 else ''))
        else:
            print('  0x%06x  %-42s SLOT +0x%03x' % (a_, ten, A))


def lam_slot(s, slot):
    v = s.theo_slot().get(slot)
    if not v:
        print('+0x%03x: khong ban ghi bind nao (khong lo ra cho Lua)' % slot)
        return 0
    ten = sorted(set(t for _, t in v))
    lop = sorted(set(l for l, _ in v))
    print('+0x%03x: %d ban ghi, ten %s' % (slot, len(v), ten))
    print('        lop: %s' % ', '.join(lop))


def _chuoi_settype(s):
    """[(dia chi lenh, dia chi chuoi, chuoi)] — sau chuoi ma setType so sanh.

    Hai kieu ma may, ca hai deu co that (do lai 2026-09-19):

        'ldr' (vn)     `ldr r1,[pc,#imm]` roi `add r1, pc` — o hang so giu CON
                       TRO chuoi, chuoi nam trong `.rodata`
        'adr' (cn131)  `adr r1,#imm` — tro THANG toi chuoi, chuoi nam trong
                       `.text` ngay sau than ham

    Do la ly do mot phep tim chuoi quet `.rodata` khong thay gi tren 1.31.
    """
    than = s.h['settype_than']
    d, a, _ = s._o(than)
    md = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
    lenh = list(md.disasm(d[than - a:than - a + 0x120], than))
    ra = []
    for i, l in enumerate(lenh[:-1]):
        if l.mnemonic == 'adr' and l.op_str.startswith('r1, #'):
            o = ((l.address + 4) & ~3) + int(l.op_str.split('#')[-1], 0)
            t = _chuoi_o(d, a, o)
            if t:
                ra.append((l.address, o, t))
            continue
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
            if s.chuoi(t):            # `chuoi` gioi han trong .rodata: dung cho kieu 'ldr'
                ra.append((l.address, t, s.chuoi(t)))
                break
    return ra


def lam_settype(s):
    """In lai phep do: sau chuoi cua setType, doc tu ma may cua ban dang chon."""
    print('%-8s %-9s %s' % ('lenh', 'chuoi o', 'chuoi'))
    for ad, o, t in _chuoi_settype(s):
        print('0x%06x 0x%06x %r' % (ad, o, t))
    print()
    print('bon nhan dat hinh dang (lenh blx goi vtable, doc tu ban dich):')
    for ten, b280, b288, c280, c288 in s.h['hinh_dang']:
        print('  %-4s blx +0x280 @0x%06x  blx +0x288 @0x%06x   '
              'vtable+0x280 <- %-12s vtable+0x288 <- %s' % (
                  ten, b280, b288, str(c280), str(c288)))
    print('  ccw/cw: khong dat cap float nao, chi goi 0x%06x voi 1/0'
          % s.h['quay_1_0'])
    print('  chuoi so sanh nam trong: %s' % s.h['chuoi_shape'])
    print()
    print('hai slot +0x280 va +0x288:')
    lam_slot(s, 0x280)
    lam_slot(s, 0x288)


def lam_nut(s):
    """In lai phep do cac o cua node: ham action -> o nao tren doi tuong.

    Khong suy tu ten: moi ham bind di thang vao mot ham trong .text, va ham do
    doc dung mot o co dinh. In ra o nao, de con doi chieu lai.

    CHI chay duoc o ban VN: bay dia chi duoi day do ra tu ban VN va CHUA do lai
    cho ban nao khac. Do lai duoc (cung duong: `runAction` doc `+0xe0` roi
    `eor r3,r3,#1`), nhung chua lam — nen tu choi chu khong in mot bang sai.
    """
    if s.ban != BAN_NUT:
        print('--nut moi do cho ban %s; ban dang chon la %s.'
              % (BAN_NUT, s.ban))
        print('Bay dia chi ham action trong ham nay la cua ban %s. Do lai truoc'
              % BAN_NUT)
        print('(tim ham bind cua runAction, roi doc o nao + phep phu dinh '
              '`eor #1`) — xem README muc ban 1.31.')
        return 1
    HO = [
        ('runAction', 0x4ae7d4),
        ('stopAllActions', 0x4ae800),
        ('stopActionByTag', 0x4ae838),
        ('getActionByTag', 0x4ae868),
        ('numberOfRunningActions', 0x4ae890),
        ('hen gio (khong bind)', 0x4ae89a),
        ('resumeActions', 0x4aeacc),
        ('pauseActions', 0x4aeb88),
    ]
    d, a, _ = s._o(0x4ae7d4)
    md = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
    print('%-22s %-8s %-22s %s' % ('ham', 'dia chi', 'o doc tren self', 'ghi chu'))
    for ten, ad in HO:
        # Dung o CUOI HAM, khong dung cua so byte co dinh: cua so 0x20 chay tran
        # qua ham ke tiep (cac ham nay chi 3-8 lenh) va doc nham o cua no — dung
        # loi da mac mot lan voi bang lop (doc theo khe thi tran 20 ban ghi).
        # Moc cuoi: `pop {..., pc}` / `bx lr`, hoac nhanh duoi `b`/`b.w`.
        o, co_phu = [], False
        for l in md.disasm(d[ad - a:ad - a + 0x40], ad):
            if l.address > ad and l.mnemonic in ('push', 'push.w'):
                break                      # mo dau ham ke tiep
            if ']' in l.op_str and l.mnemonic.startswith('ldr'):
                o.append(l.op_str.split('#')[-1].rstrip(']'))
            if l.mnemonic == 'eor' and l.op_str.endswith('#1'):
                co_phu = True
            cuoi = (l.mnemonic in ('b', 'b.w', 'bx')
                    or (l.mnemonic.startswith('pop') and 'pc' in l.op_str))
            if cuoi:
                break
        chinh = sorted({x for x in o if x in ('0xd8', '0xdc', '0xe0')})
        print('%-22s 0x%06x %-22s%s' % (
            ten, ad, ', '.join('+' + x for x in chinh),
            '  eor r3,r3,#1 (= !m_bRunning)' if co_phu else ''))
    print()
    print('ket luan: +0xdc = bo quan ly action (5 ham action doc no)')
    print('          +0xd8 = bo thu hai — chi pause/resume cham toi, khong ham')
    print('                  action nao doc; tan cong hen gio doc no cung phep')
    print('                  phu dinh `!m_bRunning` nhu runAction')
    print('          +0xe0 = m_bRunning (bool)')
    print('          pause/resume goi CA HAI bo -> dung chu ky')
    print('          pauseSchedulerAndActions cua Cocos')
    print('          (TEN cua +0xd8 suy ra tu chu ky do; con so thi do duoc)')
    print()
    print('quet ca 132 bang lop xem co ham dung bo hen gio rieng khong:')
    dem = collections.Counter()
    for i in range(132):
        for _, t, _, _ in s.bang(i):
            if t in ('pause', 'pauseScheduler', 'pauseSchedulerAndActions', 'pauseTarget',
                     'resume', 'resumeScheduler', 'resumeSchedulerAndActions', 'resumeTarget',
                     'schedule', 'scheduleOnce', 'scheduleUpdate'):
                dem[t] += 1
    for t, n in sorted(dem.items()):
        print('  %-28s %d lop' % (t, n))
    print('  -> khong co ham nao rieng cho bo hen gio: pauseActions/resumeActions')
    print('     la duong DUY NHAT, va no dung ca hai bo.')


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    # `kiem_so_ban` chu khong `kiem_so`: file nay da co hang so cho TUNG ban
    # (`SO_BAN`), nen phep kiem dung la ".so nay co dung la ban da do hang so
    # khong", khong phai "co phai ban VN khong" — doi sau se chan dung cai ma
    # file nay lam duoc.
    loi = cay.kiem_so_ban()
    if loi:
        sys.exit(loi)
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--bang', action='store_true')
    ap.add_argument('--xam', action='store_true')
    ap.add_argument('--lop', metavar='TEN|SO')
    ap.add_argument('--slot', metavar='0xNNN')
    ap.add_argument('--settype', action='store_true')
    ap.add_argument('--nut', action='store_true',
                    help='cac o cua node + pauseActions/resumeActions')
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
    if a.nut:
        lam_nut(s)
    if not any((a.bang, a.xam, a.lop, a.slot, a.settype, a.nut)):
        ap.print_help()
    return 0


if __name__ == '__main__':
    sys.exit(main())
