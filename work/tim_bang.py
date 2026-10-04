# -*- coding: utf-8 -*-
"""Do lai bang bind Lua (BASE_TEN / BASE_BANG) tren MOT ban libgame.so bat ky.

    BC_TREE=cn131 python tim_bang.py
    BC_TREE=cn131 python tim_bang.py --so <duong dan .so>
    BC_TREE=vn    python tim_bang.py --doi-chieu     # kiem cong cu tren ban da biet

VI SAO CAN
----------
`binder.py` mang hai dia chi CUNG: `BASE_TEN = 0x92a5ec` va `BASE_BANG =
0x92a814`. Do la toa do doc ra tu `libgame.so` BAN VN 10.213.832 byte. Ban 1.31
(`com.wh.dachui`) co file .so 11.306.184 byte — khong co doan byte nao dung
chung, nen hai dia chi ay VO NGHIA voi no.

`cay.kiem_so()` da chan truong hop chay nham (binder.py goi no), nen loi khong
di qua im lang. Nhung chan thi khong lam duoc gi ca — van phai do lai. Cong cu
nay lam viec do, va lam bang CUNG PHUONG PHAP da dung cho ban VN, khong phai
bang cach doan.

HAI KIEU BO TRI, KHONG PHAI MOT
--------------------------------
Do ra ngay 2026-09-19 khi chay ban 1.31: **hai ban khong dat mang lop giong
nhau.** Cong cu nay phai biet ca hai, neu khong thi no bao "khong tim duoc" tren
mot ban hoan toan binh thuong — dung cai da xay ra.

  `hai-mang` (VN 1.26) — HAI mang roi nhau, moi mang buoc 4:

      BASE_TEN  0x92a5ec   .got  132 con tro chuoi, lien nhau
      BASE_BANG 0x92a814   .got  132 con tro bang, lien nhau, cung thu tu

  `cap-lien` (CN 1.31) — TUNG CAP (ten, bang) NAM LIEN NHAU, buoc 8:

      BASE_TEN  0xaa8584   .got  [ten0][bang0][ten1][bang1]...

      Va giua vai cap co o GOT KHAC xen vao (do duoc 2 o sau CCEditBox, 1 o
      sau CCWheelDisk, 4 o o cuoi) — nen KHONG duoc doc bang `base + 8*i`, phai
      DI TUAN TU: o nao doc ra ten lop thi do la mot lop, bang cua no la o NGAY
      SAU. Cach doc theo chi so da sai mot lan: no bo sot `CCControlSlider` va
      `CCParticleSystemQuad` (hai ten roi vao o le vi bi day lech).

      Ban 1.31 co **129 lop**, khong phai 132: bo `CCScale9Sprite`, `CCSprite`,
      `ProtocolAnalytics`. Do bang cach doi chieu DAY ten chu khong theo chi so
      (xem duoi).

DO BANG NEO, KHONG BANG DOAN
----------------------------
Khong quet mo: doi chieu voi BON lop da biet truoc tu ban VN. Neo la TEN lop va
TEN PHUONG THUC, **khong phai chi so trong mang** — chi so da doi giua hai ban
(CCProgressWithClock: VN 125, 1.31 123), nen neo theo chi so se tu choi chinh
ban dung.

    SimpleAudioEngine      playBackgroundMusic / stopBackgroundMusic / setResource
    CCLabelTTF             initWithString / setString / getString
    CCProgressTimer        getPercentage / setPercentage / setType
    CCProgressWithClock    setClock / stopClock

Voi kieu `cap-lien` con phai khop DAY TEN theo thu tu (day 1.31 phai la day con
cua day VN — dung thu tu, chi thieu vai ten), chu khong chi bon o roi rac.

CHUNG MINH DA LAM CHO 1.31 (`cap-lien`, BASE_TEN = 0xaa8584)
------------------------------------------------------------
  1. DUY NHAT: quet ca file 11.306.184 byte, moi section, tim moi cho co >= 4
     ten lop VN lien tiep ma cac O cach deu. Chi dung MOT cho: 0xaa8584, buoc 8.
     (Ba neo doc lap — bat dau tu lop 0, 1, 2 — deu quy ve cung dia chi ay.)
  2. THU TU: day ten doc ra dai 129, va no nam TRONG day 132 ten cua VN theo
     dung thu tu; thieu dung ba ten ghi tren.
  3. BANG: 129 bang, 3312 ban ghi, KHONG hai lop nao dung chung mot bang, 128/129
     ket thuc dung o moc chan 12 byte 0. Bang rong dung MOT cai: `CCSpriteFrame`
     — tai hien y het diem la da ghi cho ban VN (o do la lop 113).

`SETTYPE_THUNK` / `SETTYPE_THAN` thi KHONG phai do rieng: chung doc ra TU bang
vua tim duoc — ban ghi `setType` cua lop 20 cho A = dia chi thunk (bit 0 = 1
nghia la Thumb), roi doc lenh `bl` cua thunk ay ra than ham. Nho vay hai hang so
nay luon khop voi bang, khong the lech.
"""
import argparse
import bisect
import os
import struct
import sys

import capstone

from xref import load

import cay

#: Neo de nhan mang ten lop — neo theo TEN, khong theo chi so (chi so doi giua
#: hai ban: `CCProgressWithClock` la 125 o VN, 123 o 1.31). Bon ten nay dung
#: theo thu tu trong mang o CA HAI ban (da do).
NEO_LOP = ('SimpleAudioEngine', 'CCDirector', 'CCLayer', 'CCLayerColorRoundRim')

#: Phuong thuc dac trung cua tung lop — neo de nhan BANG phuong thuc. Cung lay
#: tu ban VN. Moi bo phai co du, va phai la bo cua DUNG lop do.
NEO_BANG = {
    'SimpleAudioEngine': ('playBackgroundMusic', 'stopBackgroundMusic', 'setResource'),
    'CCLabelTTF': ('initWithString', 'setString', 'getString'),
    'CCProgressTimer': ('getPercentage', 'setPercentage', 'setType'),
    'CCProgressWithClock': ('setClock', 'stopClock'),
}

#: So lop cua mang bind ban VN (do bang moc chan: 131/132 bang).
SO_LOP = 132

#: Kieu bo tri mang lop. Xem docstring.
HAI_MANG = 'hai-mang'      # VN: hai mang roi, buoc 4
CAP_LIEN = 'cap-lien'      # CN 1.31: tung cap (ten, bang) lien nhau, buoc 8


class So:
    """Doc .so: dia chi -> du lieu, va con tro -> chuoi."""

    def __init__(self, path):
        self.path = path
        self.elf, self.secs = load(path)
        self.rod = None
        self.dat = None
        for n, a, d in self.secs:
            if n == '.rodata':
                self.rod = (a, d)
            elif n == '.data':
                self.dat = (a, d)
        # Bang tra cuu dia chi -> section. `_o` duoc goi hang trieu luot (moi o
        # 4 byte cua moi section de tim bang), nen duyet tuan tu danh sach
        # section moi luot la khong chay noi.
        self._muc = sorted(((a, d, n) for n, a, d in self.secs if len(d)))
        self._dau = [m[0] for m in self._muc]

    def _o(self, addr):
        i = bisect.bisect_right(self._dau, addr) - 1
        if i >= 0:
            a, d, n = self._muc[i]
            if addr < a + len(d):
                return d, a, n
        return None, None, None

    def word(self, addr):
        d, a, _ = self._o(addr)
        return struct.unpack_from('<I', d, addr - a)[0] if d else None

    def chuoi_tai(self, v, dai=64):
        """Con tro -> chuoi ascii ngan, hoac None neu khong phai con tro chuoi."""
        if not v or not self.rod:
            return None
        a, d = self.rod
        if not (a <= v < a + len(d)):
            return None
        raw = d[v - a:v - a + dai].split(b'\x00')[0]
        if not raw:
            return None
        try:
            t = raw.decode('ascii')
        except UnicodeDecodeError:
            return None
        return t if all(32 <= ord(c) < 127 for c in t) else None

    def la_dinh_danh(self, v):
        """Con tro -> mot TEN dinh danh C++ (chu, so, _, :, ~). Dung de loai
        nhieu: mot ban ghi bang ma o dau khong phai ten ham thi khong phai ban
        ghi that."""
        t = self.chuoi_tai(v)
        if not t or len(t) > 60:
            return None
        return t if all(c.isalnum() or c in '_~:' for c in t) else None

    def tim_chuoi(self, ten):
        """Moi dia chi trong .rodata mo dau bang chuoi `ten` + NUL.

        Co the ra nhieu cho (chuoi trung), nen tra ve danh sach.
        """
        if not self.rod:
            return []
        a, d = self.rod
        need = ten.encode('ascii') + b'\x00'
        out, i = [], d.find(need)
        while i != -1:
            out.append(a + i)
            i = d.find(need, i + 1)
        return out

    def mang_con_tro(self, sec, dia_chi):
        return struct.unpack_from('<I', sec[1], dia_chi - sec[0])[0]


class MangLop:
    """Mang lop da doc ra. `dia_chi_bang` luon la danh sach, khong tinh theo chi so.

    Ly do khong tinh: o kieu `cap-lien` (1.31) giua cac cap co o GOT khac xen
    vao, nen `base_bang + buoc*i` la mot cong thuc SAI — no bo sot ten nao roi
    vao o le. Do la loi da mac mot lan (2026-09-19).
    """

    def __init__(self, kieu, ten, dia_chi_bang, base_ten, base_bang=None):
        self.kieu = kieu
        self.ten = ten
        self.dia_chi_bang = dia_chi_bang or []
        self.base_ten = base_ten
        self.base_bang = base_bang
        self.so_lop = len(ten)

    def bang(self, i):
        return self.dia_chi_bang[i]

    def chi_so(self, ten):
        return self.ten.index(ten) if ten in self.ten else None


def _doc_cap_lien(s, base, toi_da=400):
    """Kieu CN 1.31: DI TUAN TU, cap (ten, bang) nam lien nhau, buoc 8.

    O nao doc ra ten lop (dinh danh C++) thi do la mot lop, va bang cua no la o
    NGAY SAU. O khac xen vao thi bo qua — khong duoc coi `base + 8*i` la lop thu
    i, vi lam vay se bo sot dung nhung ten bi day sang o le.
    """
    ten, dc = [], []
    for i in range(toi_da):
        t = s.la_dinh_danh(s.word(base + 4 * i))
        if t:
            ten.append(t)
            dc.append(s.word(base + 4 * (i + 1)))
    return ten, dc


def _doc_hai_mang(s, base):
    """Kieu VN 1.26: 132 con tro ten lop lien nhau, buoc 4."""
    return [s.la_dinh_danh(s.word(base + 4 * i)) for i in range(SO_LOP)], None


#: Chi so bon neo tren ban VN — chi dung cho kieu `hai-mang`. Ban khac co the
#: da chen/bot lop nen so chi so doi; neo theo chi so chi de nhan dien ban VN.
CHI_SO_VN = {0: 'SimpleAudioEngine', 8: 'CCLabelTTF',
             20: 'CCProgressTimer', 125: 'CCProgressWithClock'}


def _khop_day(s, ten, dc, neo=NEO_LOP):
    """Kieu `cap-lien`: day ten mo dau dung bon neo VA o sau la BANG that.

    Phan "bang that" la bat buoc, khong phai cho chac. Tren ban VN, mang ten la
    mot day ten LIEN NHAU buoc 4 — nen doc no bang kieu `cap-lien` cung ra dung
    bon neo lam bon ten dau, va `dc[i]` chi la CON TRO TOI TEN KE TIEP. Thieu
    phep kiem nay thi ban VN bi nhan nham, va cong cu tu choi chay vi "nhieu hon
    mot cho".
    """
    if len(ten) < 100 or tuple(ten[:len(neo)]) != neo:
        return False
    for ten_neo in neo:
        if ten_neo not in ten:
            return False
        i = ten.index(ten_neo)
        bang = {t for _, t, _, _ in _bang_tu(s, dc[i])}
        # Phan BAT BUOC: o sau ten phai la mot BANG that. Tren ban VN, doc mang
        # ten (buoc 4) bang kieu cap-lien thi `dc[i]` chi la con tro toi TEN KE
        # TIEP — `_bang_tu` doc chuoi ten ay ra 12-byte mot va tra ve rong. Neu
        # chi doi neo phuong thuc thi ban VN lot qua o lop dau roi nhan nham.
        if not bang:
            return False
        # Phan THEM: lop nao co neo phuong thuc thi doi cho dung. Bon lop neo
        # khong lop nao co du (NEO_LOP gom CCDirector/CCLayer... khong nam
        # trong NEO_BANG), nen phai hoi bang `.get` chu khong tra thang — tra
        # thang thi KeyError nem ra ngay lop neo thu hai.
        can = NEO_BANG.get(ten_neo)
        if can and not all(c in bang for c in can):
            return False
    return True


def _khop_chi_so(ten):
    """Kieu VN: bon neo nam o DUNG chi so da biet, va ca 132 o deu la ten."""
    if len(ten) != SO_LOP or any(t is None for t in ten):
        return False
    return all(ten[i] == t for i, t in CHI_SO_VN.items())


def tim_mang_lop(s):
    """[(MangLop)] — moi cach bo tri tim duoc tren file .so nay.

    Cach lam: lay dia chi chuoi cua lop 0 (`SimpleAudioEngine`), roi tim MOI o 4
    byte (trong BAT KY section nao) tro toi dia chi ay — do la ung vien cho o 0
    cua mang. Voi tung ung vien, thu CA HAI kieu bo tri.

    Quet MOI section chu khong chi `.rodata`: tren ban VN, `binder.py` ghi hai
    mang nay thuoc `.rodata` va `.data`, nhung doc bang section that thi CA HAI
    nam trong `.got` (0x92a07c-0x92c000; ban 1.31: 0xaa7f14-0xaae000). Chung la
    o GOT duoc dien bang relocation luc nap (`R_ARM_RELATIVE`), nen trong file
    chung da giu san dia chi dung — do la ly do `binder.py` doc thang ra ten
    duoc. Ghi lai: chu thich trong `binder.py` ve section la SAI, con dia chi
    thi dung.
    """
    ra = []
    for goc in s.tim_chuoi(NEO_LOP[0]):
        need = struct.pack('<I', goc)
        for _n, a_sec, d_sec in s.secs:
            off = d_sec.find(need)
            while off != -1:
                if off % 4 == 0:
                    base = a_sec + off
                    ten, dc = _doc_cap_lien(s, base)
                    if _khop_day(s, ten, dc):
                        ra.append(MangLop(CAP_LIEN, ten, dc, base))
                    ten, _ = _doc_hai_mang(s, base)
                    if _khop_chi_so(ten):
                        ra.append(MangLop(HAI_MANG, ten, None, base))
                off = d_sec.find(need, off + 1)
    # Mot mang co the bi thay hai lan (hai section chong dia chi) — bo trung.
    return list({(m.kieu, m.base_ten): m for m in ra}.values())


def _bang_tu(s, a):
    """Doc mot bang tu dia chi `a`, dung o ban ghi 12 byte toan so 0.

    Dung lai o moc chan chu KHONG dung theo khe giua cac bang — xem docstring
    `binder.py`: doc theo khe da chay tran 20 ban ghi sang bang ke tiep.
    """
    ra = []
    while True:
        if s.word(a) == 0 and s.word(a + 4) == 0 and s.word(a + 8) == 0:
            break
        ten = s.la_dinh_danh(s.word(a))
        if ten is None:
            break
        ra.append((a, ten, s.word(a + 4), s.word(a + 8)))
        a += 12
        if len(ra) > 400:
            break
    return ra


#: Section co the chua bang phuong thuc. Do tren ban VN: bang cua lop 0 / 8 / 20
#: / 125 lan luot o 0x935c04 / 0x92f090 / 0x93236c / 0x931f64 — CA BON deu thuoc
#: `.data`. Bang phuong thuc la DU LIEU nen khong bao gio nam trong `.text`
#: (5,5 MB, va quet no lam cong cu chay khong noi: 1,4 trieu luot goi `word()`
#: cho mot lan chay, da bi bat dung nhu vay 2026-09-19).
SEC_BANG = ('.data', '.data.rel.ro', '.data.rel.ro.local')


def _cac_bang(s):
    """{(dia chi bat dau): [ban ghi]} cho moi bang trong cac section du lieu.

    Nhan bang tai CHO BAT DAU that: o `a` tro toi mot ten ham, va o `a-12`
    KHONG tro toi ten ham nao (tuc `a` khong phai giua mot bang).
    """
    ra = {}
    for n, a_sec, d_sec in s.secs:
        if n not in SEC_BANG:
            continue
        for off in range(0, len(d_sec) - 12, 4):
            a = a_sec + off
            if s.la_dinh_danh(s.word(a)) is None:
                continue
            if off >= 12 and s.la_dinh_danh(s.word(a - 12)) is not None:
                continue                  # giua mot bang, khong phai dau bang
            b = _bang_tu(s, a)
            if b:
                ra[a] = b
    return ra


def _mang_khop(s, dia_chi_bang):
    """Moi dia chi mang 132 con tro ma cac o neo tro dung vao bang da chon.

    GIAO TAP, khong quet tung o. Voi neo (lop, dia chi bang): moi cho trong file
    dang giu 4 byte bang `dia chi bang` la mot ung vien cho o `lop`; suy nguoc ra
    dia chi mang = cho_do - 4*lop. Giao cac tap ay lai.

    Quet tung o 4 byte (cach lam dau tien) chay qua ca `.text` 5,5 MB cho MOI to
    hop neo — do la 1,4 trieu luot goi `word()` moi to hop, khong chay noi.
    """
    ung = None
    for lop, a_bang in sorted(dia_chi_bang.items()):
        need = struct.pack('<I', a_bang)
        o = set()
        for _n, a_sec, d_sec in s.secs:
            i = d_sec.find(need)
            while i != -1:
                if i % 4 == 0:
                    o.add(a_sec + i - 4 * lop)
                i = d_sec.find(need, i + 1)
        ung = o if ung is None else (ung & o)
        if not ung:
            return []
    return sorted(ung) if ung else []


def kiem_neo_bang(s, mang, cac_bang):
    """Doi chieu bon neo PHUONG THUC voi mang da doc ra. [(lop, thieu)] — rong la dat.

    Day moi la phep kiem that su cho kieu `cap-lien`: khong dung chi so, ma hoi
    thang "lop ten X co bang chua cac phuong thuc Y khong". Neu cach ghep cap
    sai thi bang cua lop se la bang cua lop khac, va phep kiem nay bat duoc.
    """
    loi = []
    for ten_neo, can in sorted(NEO_BANG.items()):
        i = mang.chi_so(ten_neo)
        if i is None:
            loi.append((ten_neo, ['khong co lop nay trong mang']))
            continue
        b = cac_bang.get(mang.bang(i))
        if b is None:
            b = _bang_tu(s, mang.bang(i))
        co = {t for _, t, _, _ in b}
        thieu = [c for c in can if c not in co]
        if thieu:
            loi.append((ten_neo, thieu))
    return loi


def tim_bang_bang(s, cac_bang, neo):
    """(danh sach dia chi mang, {lop: dia chi bang}) — tim theo TO HOP neo.

    Chi dung cho kieu `hai-mang` (VN): o do `base_bang` la mot dia chi RIENG,
    phai tim. Kieu `cap-lien` khong can ham nay — dia chi bang da co san trong
    tung cap doc ra.

    Khong doi moi lop neo chi ra DUNG MOT bang: neo la tap ten phuong thuc, ma
    nhieu lop khac han cung co cung tap ay. Do duoc tren ban VN: `initWithString`
    + `setString` + `getString` khop **5** bang (CCLabelTTF, CCLabelBMFont,
    CCLabelAtlas, Label...), nen doi "moi neo mot ung vien" la tu choi chinh
    ban dung (da bi bat dung nhu vay, 2026-09-19).

    Thay vao do: thu MOI to hop (moi lop neo chon mot ung vien), roi voi moi to
    hop tim mang 132 con tro khop. Mang nao ra DUY NHAT tren moi to hop thi nhan
    — mot mang 132 con tro ma o 0 / 20 / 125 roi dung vao ba bang rieng biet thi
    khong the khop do ngau nhien.
    """
    ung = {}
    # Tu dien neo RONG thi `_tich([])` tra ve dung MOT to hop rong, roi
    # `_mang_khop` voi 0 neo tra ve [] — ham chay tron ven va bao "khong tim
    # duoc mang", khong he noi vi sao. Do la mot loi THAT (2026-09-19): ben goi
    # tra nguoc chieu (`CHI_SO_VN[ten]` thay vi `CHI_SO_VN.items()`) nen tu dien
    # thanh rong, va phep kiem hoi quy VN bao "KHONG TIM DUOC mang bang" trong
    # khi loi nam o cho ghep neo. Chan ngay tai day.
    if not neo:
        print('  !! tu dien neo RONG — khong co gi de doi chieu, dung lai.')
        return [], None
    for lop, can in neo.items():
        ung[lop] = [a for a, b in cac_bang.items()
                    if all(c in {t for _, t, _, _ in b} for c in can)]
        if not ung[lop]:
            print('  !! lop %d (%s): khong bang nao co du cac ten nay'
                  % (lop, '/'.join(can)))
            return [], None

    ra = {}
    for to_hop in _tich(sorted(ung.items())):
        dia_chi_bang = dict(to_hop)
        for base in _mang_khop(s, dia_chi_bang):
            ra.setdefault(base, dia_chi_bang)
    return sorted(ra), (ra[sorted(ra)[0]] if ra else None)


def _tich(ds):
    """Tich Descartes: [danh sach ung vien cua tung lop] -> [to hop].

    Vao:  [(0, [a0, a1]), (20, [b0]), ...]
    Ra :  [((0, a0), (20, b0)), ((0, a1), (20, b0))]
    """
    ra = [()]
    for lop, ung_vien in ds:
        ra = [t + ((lop, x),) for t in ra for x in ung_vien]
    return ra


def tim_settype(s, cac_bang, a_bang):
    """(thunk, than) cua ham setType, doc TU bang cua lop CCProgressTimer.

    Ban ghi cho `setType` co dang {con_tro_ten, A, 0} voi A la dia chi ma. Bit 0
    cua A = 1 nghia la Thumb (dia chi le), nen than thunk la A & ~1. Doc lenh
    `bl` trong thunk ra than ham that.

    Doi chieu lai: `getPercentage` / `setPercentage` phai co mat trong CUNG bang
    nay — neu khong thi `a_bang` khong phai bang cua CCProgressTimer.
    """
    if not a_bang:
        return None, None, None
    b = cac_bang.get(a_bang) or _bang_tu(s, a_bang)
    for cho, ten, A, B in b:
        if ten != 'setType':
            continue
        if B != 0:
            return None, None, 'setType khong phai ham C (A=%d, B=%d)' % (A, B)
        thunk = A & ~1
        than = _duoi_bl(s, thunk)
        return thunk, than, None
    return None, None, 'khong thay ban ghi setType trong bang lop 20'


def _duoi_bl(s, thunk, so_lenh=16):
    """Dia chi THAN ham ma `thunk` goi toi: lenh `bl` CUOI truoc lenh tra ve.

    Khong phai `bl` dau tien — va day la cho tung doan sai. Do tren ban VN, thunk
    `setType` @0x2bd438 co HAI lenh `bl`:

        0x2bd438  push  {r4, lr}
        0x2bd43a  movs  r2, #0
        0x2bd43c  mov   r4, r0
        0x2bd43e  mov   r0, r1
        0x2bd440  movs  r1, #1
        0x2bd442  bl    #0x23c19c     <- chuyen tham so Lua ra chuoi
        0x2bd446  mov   r1, r0
        0x2bd448  mov   r0, r4
        0x2bd44a  bl    #0x2bd2d8     <- THAN that (0x2bd2d8 la hang so trong binder.py)
        0x2bd44e  movs  r0, #0
        0x2bd450  pop   {r4, pc}

    0x23c19c khong phai than ham: no goi 0x23bd34 roi kiem tag kieu
    (`and r3,#0xf; cmp r3,#4`) — dung khuon `luaL_checkstring`. Lay `bl` dau tien
    ra 0x23c19c, lech voi hang so dang dung trong `binder.py`.

    Nen: di het thunk, gom MOI dich `bl`, dung lai o lenh tra ve (`pop` co `pc`,
    hoac `bx lr`), roi tra ve dich CUOI CUNG.
    """
    d, a, _ = s._o(thunk)
    if d is None:
        return None
    md = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
    md.detail = True
    cuoi = None
    for ins in md.disasm(d[thunk - a:thunk - a + 64], thunk):
        if _ket_thuc(ins):
            break
        if ins.mnemonic in ('bl', 'b', 'b.w'):
            for op in ins.operands:
                if op.type == capstone.arm.ARM_OP_IMM:
                    cuoi = op.imm
            if ins.mnemonic in ('b', 'b.w'):
                break            # nhay thang: dich chinh la than ham (tail call)
        so_lenh -= 1
        if so_lenh <= 0:
            break
    return cuoi


def _ket_thuc(ins):
    """Lenh nay ket thuc thunk (tra ve) hay khong: pop co pc, hoac bx lr."""
    if ins.mnemonic == 'pop':
        return 'pc' in ins.op_str
    if ins.mnemonic == 'bx':
        return ins.op_str.strip() == 'lr'
    if ins.mnemonic in ('b', 'b.w'):
        return False             # nhay thang xuong than ham, khong phai tra ve
    return False


def kiem_bang(s, mang, cac_bang):
    """Doc lai toan bo bang cua mang va doi chieu.

    Tra ve (so_bang, so_ban_ghi, loi, dung_chung) — `dung_chung` la {dia chi
    bang: [ten lop]} cho bang bi NHIEU lop tro cung. Do la phep kiem quan trong
    cho kieu `cap-lien`: hai lop khac nhau ma tro cung mot bang thi gan nhu chac
    la ghep cap sai (da do: 1.31 khong co cho nao dung chung).
    """
    so_bang = so_ban_ghi = 0
    loi, dung_chung = [], {}
    for i, ten in enumerate(mang.ten):
        a = mang.bang(i)
        if not a:
            loi.append('lop %d (%s): o mang = 0' % (i, ten))
            continue
        dung_chung.setdefault(a, []).append(ten)
        b = cac_bang.get(a) or _bang_tu(s, a)
        if not b:
            loi.append('lop %d (%s): bang rong @0x%06x' % (i, ten, a))
            continue
        so_bang += 1
        so_ban_ghi += len(b)
    return so_bang, so_ban_ghi, loi, {k: v for k, v in dung_chung.items() if len(v) > 1}


def mang_vn():
    """Mang lop cua BAN VN, doc thang tu cay `vn/` — de doi chieu, khong phai
    de dung. Tra ve None neu khong thay cay VN.

    PHAI noi ro `ban='vn'`: `binder.Soi` mac dinh lay hang so theo BAN DANG CHAY
    (`cay.TEN`), nen dung no tren file `.so` cua VN trong khi dang chay cn131 la
    doc file VN bang hang so 1.31 — ra mot day ten vo nghia, va phep doi chieu
    bao "sai" mot cach am tham (da bi bat dung nhu vay 2026-09-19: 129 ten 1.31
    bi coi la KHONG nam trong day VN, con "VN thua" ra 0 ten — vo ly).
    """
    duong = os.path.join(cay.goc_cua('vn'), 'apk', 'lib', 'armeabi-v7a',
                         'libgame.so')
    if not os.path.exists(duong):
        return None
    import binder
    return binder.Soi(duong, ban='vn')


def doi_chieu_vn(s, mang):
    """Day ten cua ban nay so voi ban VN: co phai DAY CON THEO DUNG THU TU khong.

    Day la phep kiem doc lap cho kieu `cap-lien`: ghep cap sai thi thu tu se loan
    ngay (do da thay khi doc theo chi so — `CCControlSlider` tut xuong o le).
    Tra ve (so_thieu, danh sach_thieu, dat).
    """
    bs = mang_vn()
    if bs is None:
        return None, [], False
    a = [t for t in bs.ten if t]
    i = j = 0
    thieu = []
    while i < len(a) and j < mang.so_lop:
        if a[i] == mang.ten[j]:
            i += 1
            j += 1
        else:
            thieu.append(a[i])
            i += 1
    thieu += a[i:]
    return len(thieu), thieu, (j == mang.so_lop)


def in_hang_so(s, mang, thunk, than):
    print()
    print('  # --- dan vao binder.py (ban %s) ---' % cay.TEN)
    print('  KIEU = %r' % mang.kieu)
    print('  BASE_TEN = 0x%x' % mang.base_ten)
    if mang.kieu == HAI_MANG:
        print('  BASE_BANG = 0x%x' % mang.base_bang)
    else:
        print('  # KHONG co BASE_BANG: tung cap (ten, bang) nam lien nhau. Dia chi')
        print('  # bang di kem tung lop — doc bang `tim_bang.doc_cap_lien()`,')
        print('  # KHONG tinh `base + buoc*i` (co o GOT khac xen vao).')
    if thunk:
        print('  SETTYPE_THUNK = 0x%x' % thunk)
        print('  SETTYPE_THAN = 0x%x' % than)
    print()
    print('  # so lop: %d   lop 0: %s' % (mang.so_lop, mang.ten[0]))
    print('  # so .so: %d byte' % os.path.getsize(s.path))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--so', help='mac dinh: cay.SO cua ban dang chon (BC_TREE)')
    ap.add_argument('--doi-chieu', action='store_true',
                    help='doi chieu voi hai hang so dang co trong binder.py')
    ap.add_argument('--json', help='ghi ket qua ra JSON')
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

    path = a.so or cay.SO
    print('ban %s  %s' % (cay.TEN, path))
    s = So(path)
    print('  .rodata %s  .data %s' % (
        ('0x%06x-%06x' % (s.rod[0], s.rod[0] + len(s.rod[1]) - 1)) if s.rod
        else '(khong co)',
        ('0x%06x-%06x' % (s.dat[0], s.dat[0] + len(s.dat[1]) - 1)) if s.dat
        else '(khong co)'))

    ung_vien = tim_mang_lop(s)
    print()
    print('mang lop tim duoc: %d cho' % len(ung_vien))
    for m in ung_vien:
        print('  kieu %-9s base 0x%06x  %d lop' % (m.kieu, m.base_ten, m.so_lop))
    if not ung_vien:
        print('  KHONG TIM DUOC — dung lai, khong doan.')
        return 1
    if len(ung_vien) > 1:
        print('  dung lai: chua phan biet duoc, khong nhan bua.')
        return 1
    mang = ung_vien[0]
    base_ten = mang.base_ten
    ten_lop = mang.ten
    doc_duoc = sum(1 for t in ten_lop if t)
    print('  KIEU BO TRI: %s' % mang.kieu)
    print('  BASE_TEN = 0x%x' % base_ten)
    print('  ten doc duoc: %d/%d' % (doc_duoc, mang.so_lop))
    for ten_neo in NEO_LOP:
        print('     neo %-22s chi so %s' % (
            ten_neo, mang.chi_so(ten_neo)))

    cac_bang = {}
    if mang.kieu == HAI_MANG:
        cac_bang = _cac_bang(s)
        print()
        print('bang trong .data: %d bang nhan duoc' % len(cac_bang))
        neo_chi_so = {i: NEO_BANG[t] for i, t in CHI_SO_VN.items()}
        mang_bang, dia_chi_bang = tim_bang_bang(s, cac_bang, neo_chi_so)
        if not mang_bang:
            print('  KHONG TIM DUOC mang bang — dung lai.')
            return 1
        if len(mang_bang) > 1:
            print('  nhieu hon mot cho: %s' % ' '.join(hex(m) for m in mang_bang))
            return 1
        mang.base_bang = mang_bang[0]
        mang.dia_chi_bang = [s.word(mang_bang[0] + 4 * i)
                             for i in range(mang.so_lop)]
        print('  BASE_BANG = 0x%x' % mang.base_bang)
        for lop in sorted(dia_chi_bang):
            print('     lop %-4d bang @0x%06x  %d ban ghi'
                  % (lop, dia_chi_bang[lop], len(cac_bang[dia_chi_bang[lop]])))
    else:
        print()
        print('dia chi bang di kem tung cap — khong co BASE_BANG.')

    # Neo PHUONG THUC: hoi thang tung lop ten X co bang chua phuong thuc Y khong.
    # Day moi la phep kiem bat duoc ghep cap sai, va no khong dung chi so.
    loi_neo = kiem_neo_bang(s, mang, cac_bang)
    print()
    print('neo phuong thuc: %s' % ('KHOP CA BON' if not loi_neo else 'LECH'))
    for ten_neo, thieu in loi_neo:
        print('  !! %-22s thieu %s' % (ten_neo, thieu))

    so_bang, so_ban_ghi, loi, dung_chung = kiem_bang(s, mang, cac_bang)
    print()
    print('doc lai: %d/%d lop, %d ban ghi' % (so_bang, mang.so_lop, so_ban_ghi))
    for l in loi[:10]:
        print('  !! %s' % l)
    print('  bang bi nhieu lop dung chung: %s'
          % ({hex(k): v for k, v in dung_chung.items()} or 'khong co'))

    # Moc chan 12 byte 0 la thu CHOT DO DAI bang (xem binder.py: doc theo khe da
    # chay tran 20 ban ghi sang bang ke tiep). Nhung khong phai bang nao cung co
    # moc — lop 113 `CCSpriteFrame` la mot ngoai le da ghi san. Nen vong lap PHAI
    # co gioi han: ban dau khong co, va mot bang thieu moc lam `word()` tra None
    # — `None == 0` la False — nen vong lap chay mai khong dung. Do la thu lam
    # cong cu treo, khong phai cham.
    moc_chan = 0
    thieu_moc = []
    for i, t in enumerate(ten_lop):
        a_b = mang.bang(i)
        j, n = a_b, 0
        while n < 400:
            if s.word(j) == 0 and s.word(j + 4) == 0 and s.word(j + 8) == 0:
                break
            if s.la_dinh_danh(s.word(j)) is None:
                break
            j += 12
            n += 1
        if s.word(j) == 0 and s.word(j + 4) == 0 and s.word(j + 8) == 0:
            moc_chan += 1
        else:
            thieu_moc.append((i, t, a_b, n))
    print('  bang ket thuc dung o moc chan 12 byte 0: %d/%d'
          % (moc_chan, mang.so_lop))
    for i, t, a_b, n in thieu_moc[:6]:
        print('     !! lop %d (%s) @0x%06x: dung sau %d ban ghi, KHONG phai moc chan'
              % (i, t, a_b, n))

    chi_so_st = mang.chi_so('CCProgressTimer')
    thunk, than, loi_st = tim_settype(
        s, cac_bang, mang.bang(chi_so_st) if chi_so_st is not None else None)
    print()
    if loi_st:
        print('setType: %s' % loi_st)
    else:
        print('setType: thunk 0x%x -> than 0x%x' % (thunk, than))

    if a.doi_chieu:
        import binder
        hang = binder.SO_BAN.get(cay.TEN)
        if hang:
            # Doi chieu voi HANG SO DANG DUNG trong binder.py (khong phai voi mot
            # bo so chep tay o day): neu `tim_bang` do dung thi moi gia tri no
            # vua do phai trung cai ma `binder.py` dang dung de doc bang.
            print()
            print('doi chieu voi binder.py (ban %s):' % cay.TEN)
            for nhan, dang, do in (('BASE_TEN', hang['base_ten'], base_ten),
                                   ('BASE_BANG', hang['base_bang'], mang.base_bang),
                                   ('SETTYPE_THUNK', hang['settype_thunk'], thunk),
                                   ('SETTYPE_THAN', hang['settype_than'], than),
                                   ('SO_LOP', hang['so_lop'], mang.so_lop)):
                if dang is None and do is None:
                    print('  %-13s khong co (dung kieu %s)' % (nhan, mang.kieu))
                    continue
                # SO_LOP la SO DEM, khong phai dia chi — in hex thi 129 ra 0x81,
                # doc khong ra "129 lop" nua.
                soi = '%d' if nhan.startswith('SO_') else '0x%x'
                print('  %-13s dang co %-10s do duoc %-10s %s'
                      % (nhan, soi % dang, soi % do,
                         'KHOP' if dang == do else 'LECH'))
            # Doi chieu TOAN BO noi dung bang, khong chi may dia chi: neu
            # `tim_bang` doc dung cho thi toan bo bang phai ra y het `binder.py`
            # doc khi dung hang so cua no. Day moi la phep kiem that su manh —
            # may dia chi khop van co the la may dia chi khop nham.
            bs = binder.Soi()
            giong = khac = 0
            vi_du = []
            for i in range(mang.so_lop):
                t_a = sorted(t for _, t, _, _ in _bang_tu(s, mang.bang(i)))
                t_b = sorted(t for _, t, _, _ in bs.bang(i))
                if t_a == t_b:
                    giong += 1
                else:
                    khac += 1
                    if len(vi_du) < 5:
                        vi_du.append((i, ten_lop[i], len(t_a), len(t_b),
                                      sorted(set(t_a) ^ set(t_b))[:6]))
            print('  noi dung %d bang: %d giong, %d khac'
                  % (mang.so_lop, giong, khac))
            for i, t, na, nb, lech in vi_du:
                print('     lop %-4d %-22s %d vs %d ban ghi, lech %s'
                      % (i, t, na, nb, lech))
        else:
            print()
            print('khong co hang so nao trong binder.py cho ban %r de doi chieu.'
                  % cay.TEN)
        # Phep doi chieu THU HAI, doc lap voi hang so: so DAY TEN LOP voi ban VN.
        # Khong thay cho phep kia — no bat lop ghep cap sai (bang cua lop nay
        # gan cho lop khac), thu ma mot phep doi chieu hang so khong bat duoc vi
        # ca hai deu dung cung mot cach doc sai.
        if cay.TEN != 'vn':
            n_thieu, thieu, dat = doi_chieu_vn(s, mang)
            print()
            if n_thieu is None:
                print('doi chieu: khong thay cay vn/ de so.')
            else:
                print('doi chieu voi ban VN (thu tu ten lop):')
                print('  day %d ten cua ban nay nam trong day VN theo dung thu tu: %s'
                      % (mang.so_lop, dat))
                print('  VN thua %d ten (ban nay bo): %s'
                      % (n_thieu, ', '.join(thieu) or 'khong'))

    in_hang_so(s, mang, thunk, than)

    if a.json:
        import json
        json.dump({'ban': cay.TEN, 'so': path,
                   'kieu': mang.kieu,
                   'BASE_TEN': base_ten, 'BASE_BANG': mang.base_bang,
                   'SETTYPE_THUNK': thunk, 'SETTYPE_THAN': than,
                   'so_lop': mang.so_lop, 'ten_doc_duoc': doc_duoc,
                   'so_bang_doc_lai': so_bang, 'so_ban_ghi': so_ban_ghi,
                   'moc_chan': moc_chan, 'dung_chung': len(dung_chung),
                   'ten_lop': ten_lop,
                   'dia_chi_bang': mang.dia_chi_bang},
                  open(a.json, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
        print('\nda ghi %s' % a.json)
    return 0


if __name__ == '__main__':
    sys.exit(main())
