# -*- coding: utf-8 -*-
"""Bang tra `event:/...` -> file .ogg da tach tu bank.

    python event_ref.py                 # quet lai roi ghi JSON
    python event_ref.py --json          # chi in thong ke

Nguon : brave-cross/work/vn/apk/assets/banks/{sound_config,hit_config}.xml
        brave-cross/work/vn/apk/assets/banks/*.bank (qua bank.py)
        bravecross-game/sc/**/*.lua
        brave-cross/work/vn/apk/lib/armeabi-v7a/libgame.so
Dich  : bravecross-game/data_ref/event_ref.json

LUAT GIAI, do chu khong doan.

Ban dau tuong bank = doan thu 2 cua duong dan (`event:/Character/Archer/...`
-> `Archer.bank`). Do ra: 314/375 dung, va 61 ca sai — trong do
`event:/Character/Spearmen/Act_Spearman_Wake_Cast` (bank that ten `Spearman`,
so it) va `event:/Event/Event_C1M3_EarthBoom` (bank that ten `EventC1M3`).
Vay duong dan chi la GOI Y.

Luat dung la: **bank duoc xac dinh bang TEN SUBSOUND**, khong phai bang duong
dan. Do tren 413 event (hop cua ba nguon):

    * 384 event khop DUNG MOT bank theo ten subsound (chuan hoa duoi so).
    *   2 event khop nhieu bank — duong dan goi y duoc dung de chon:
        `event:/Character/ZhangJiao/Act_ZhangJiao_Wake_Cast` co o ca
        `ZhangJiao.bank` lan `ZhangJiaoEvil.bank` -> lay `ZhangJiao` theo doan
        duong dan; `event:/Impact/Impact_Catapult_Light` co o `BaiHuZi`,
        `Catapult`, `Impact_Catapult` -> lay `Impact_Catapult` vi ten bank do
        la tien to dai nhat cua doan duong dan.
    *  27 event con lai: ten event la TIEN TO cua ten subsound, thieu duoi
      `_Cast` (`Act_CaoZhi_XuanZhuanKan` -> `Act_CaoZhi_XuanZhuanKan_Cast03`).

Chuan hoa: bo MOI cum `[so _ khoang trang]` o CUOI, vi ban goc dat duoi khong
thong nhat — `_01`, `01`, ca `_ 02` (`Impact_Catapult_Light_ 02`).

KHONG giai duoc thi ghi vao `khong_giai_duoc` kem ly do, KHONG bia. Hai nhom
that (so do tren 448 chuoi, xem BANK.md chu dung chep tay): 15 chuoi ma bank
co that nhung khong co subsound ten ay (`Player03` 6, `LuXun` 3, roi `BGM`,
`BaiHuZi`, `Catapult`, `FaZheng`, `ZhangJiaoEvil`, `ZhangLiaoExclus`, `UI`),
va 5 chuoi khong bank nao co. Bon bank RONG 1 byte
(`Vo_ZhiTianXinChang_Usual/Wake`, `Vo_ZhuGeLiang_Wake/Usual`) la mat du lieu o
tang BANK chu khong phai o tang bang tra, nen chung khong nam trong 21 chuoi
nay: chung chi toi duoc bang ten client ghep luc chay.

Chon bien the: mot ten co the co nhieu ban (`_01`, `_02`, `_03`). Ban goc de
FMOD quyet dinh (event nhieu sound thi FMOD chon theo luat cua no) — KHONG
khoi phuc duoc, nen JSON tra ve CA DANH SACH va ben goi tu chon. Cho nao chi
co mot ban thi danh sach dai 1.
"""
import argparse
import glob
import io
import json
import os
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import bank  # noqa: E402
import cay  # noqa: E402

# Ba bang nay NAM SAN trong APK dang XML tran (khong ma hoa) — doc thang, khong
# chep lai mot ban.
BANK_XML = pathlib.Path(cay.BANKS)
DICH = pathlib.Path(cay.dich('event_ref.json'))
SC_LUA = HERE.parent.parent / 'bravecross-game' / 'sc'
LIBGAME = pathlib.Path(cay.SO)

EVENT = re.compile(r'event:/[^"<\'\s\\\x00]{1,80}')
DUOI = re.compile(r'[\d_\s]+$')
MAU = '%'  # `event:/Vo-Usual/Vo_%s_Usual` — client tu dien ten vao


def chuan(t):
    """Bo duoi so/duoi trang o CUOI. Xem docstring: ban goc dat duoi lech."""
    return DUOI.sub('', t)


def _sub_of():
    """{ten bank: [ten subsound]} — chi bank doc duoc, va chi bank co subsound."""
    ra = {}
    for p in bank.duong_bank():
        try:
            r = bank.mo_bank(p)
        except Exception:
            continue
        if r and r['subs']:
            ra[os.path.basename(p)[:-5]] = [s['ten'] for s in r['subs']]
    return ra


def _su_kien():
    """Moi chuoi `event:/...` trong ba nguon. Tra (set, {nguon: so luong})."""
    ra = set()
    dem = {}
    for ten in ('sound_config.xml', 'hit_config.xml'):
        p = BANK_XML / ten
        if p.is_file():
            s = set(EVENT.findall(io.open(p, encoding='latin-1').read()))
            dem[ten] = len(s)
            ra |= s
    if SC_LUA.is_dir():
        s = set()
        for p in glob.glob(str(SC_LUA / '**' / '*.lua'), recursive=True):
            s |= set(EVENT.findall(io.open(p, encoding='latin-1').read()))
        dem['sc/'] = len(s)
        ra |= s
    if LIBGAME.is_file():
        # Trong .so chi co 5 mau, hai mau chua `%s`/`%02d` nen khong tra duoc.
        s = set(EVENT.findall(io.open(LIBGAME, encoding='latin-1').read()))
        dem['libgame.so'] = len(s)
        ra |= s
    return ra, dem


def _goi_y(ev, co, tien_to=True):
    """Chon trong `co` mot bank theo duong dan cua event.

    Hai muc, theo thu tu: doan duong dan BANG ten bank, roi doan duong dan la
    TIEN TO cua ten bank (`event:/Impact/Impact_Catapult_Light` -> doan
    `Impact` -> bank `Impact_Catapult`). Chi xet trong `co`, khong xet moi
    bank, nen khong the keo mot bank khong lien quan vao.

    `tien_to=False` de TAT muc thu hai. Muc thu hai chon bank dai nhat khop
    tien to, ma khi chinh event KHONG giai duoc thi no chon rat tuy tien: do
    duoc `event:/Impact/Impact_Archery_Flesh_Heavy` bi no gan cho
    `Impact_Electricity` (doan `Impact` khop tien to ca ba bank
    `Impact_Archery` / `Impact_Electricity` / `Impact_Hit`, lay ten dai nhat) —
    roi bao "bank Impact_Electricity khong co subsound ten nay", trong khi ten
    that su khong nam o bank nao. Nen T3 chi duoc dung muc thu nhat: doan
    duong dan BANG ten bank moi la bang chung, con tien to thi khong.
    """
    for x in ev.split('/')[1:-1]:
        if x in co:
            return x
    if not tien_to:
        return None
    ung = []
    for x in ev.split('/')[1:-1]:
        ung += [b for b in co if b.startswith(x)]
    return max(ung, key=len) if ung else None


def giai(ev, sub_of, banks):
    """Tra (bank, [ten subsound], kieu) hoac (None, [], ly do)."""
    cuoi = ev.split('/')[-1]
    c = chuan(cuoi)
    # T1: khop dung ten subsound. Dem theo BANK, khong theo ten.
    co = [b for b, ts in sub_of.items() if any(chuan(t) == c for t in ts)]
    if len(co) > 1:
        # Nhieu bank: duong dan goi y phan xu.
        b = _goi_y(ev, co)
        if b is None:
            return None, [], 'khop %d bank, duong dan khong goi y duoc: %s' % (len(co), co)
        co = [b]
    if co:
        b = co[0]
        return b, [t for t in sub_of[b] if chuan(t) == c], 'chinh-xac'
    # T2: ten event la tien to cua ten subsound (thieu duoi `_Cast`).
    co = [b for b, ts in sub_of.items() if any(t.startswith(cuoi) for t in ts)]
    if len(co) > 1:
        b = _goi_y(ev, co)
        if b is not None:
            co = [b]
            return b, [t for t in sub_of[b] if t.startswith(cuoi)], 'tien-to+goi-y'
        return None, [], 'tien-to khop %d bank: %s' % (len(co), co)
    if co:
        b = co[0]
        return b, [t for t in sub_of[b] if t.startswith(cuoi)], 'tien-to'
    # T3: khong co. Neu doan duong dan la mot bank co that thi noi ro bank do
    # khong chua am thanh nay — nguon goi y KHAC voi "khong co bank nao".
    # Chi muc BANG ten bank (xem `_goi_y`), khong dung tien to: o day khong con
    # ten subsound nao de doi chieu, nen tien to chi la suy dien.
    b = _goi_y(ev, banks, tien_to=False)
    if b is not None:
        return None, [], 'bank %s khong co subsound ten nay' % b
    return None, [], 'khong bank nao co subsound ten nay'


def _file(bank_ten, sub_ten):
    # Dung CHUNG mot dinh nghia voi bank.py, neu khong hai ben lech nhau.
    return bank.ten_file(bank_ten, sub_ten)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--json', action='store_true', help='chi in, khong ghi file')
    a = ap.parse_args()

    sub_of = _sub_of()
    banks = set(sub_of)
    su_kien, dem = _su_kien()
    ra = {}
    khong = {}
    mau = {}
    kieu_dem = {}
    for ev in sorted(su_kien):
        if MAU in ev:
            # `event:/Vo-Usual/Vo_%s_Usual`, `event:/Vo-Guide/Vo_Guide%02d`:
            # client tu dien ten vao luc chay, o day khong tra duoc. Ghi rieng
            # de ben goi biet ma tra tiep bang chinh luat ten o tren.
            mau[ev] = 'client tu dien ten vao luc chay, tra bang luat ten'
            continue
        b, ts, kieu = giai(ev, sub_of, banks)
        if b is None:
            khong[ev] = kieu
            continue
        kieu_dem[kieu] = kieu_dem.get(kieu, 0) + 1
        ra[ev] = dict(bank=b, kieu=kieu,
                      file=[_file(b, t) for t in sorted(ts)])
    tk = dict(so_bank=len(sub_of),
              so_subsound=sum(len(v) for v in sub_of.values()),
              so_event=len(su_kien), so_giai_duoc=len(ra), so_mau=len(mau),
              so_khong_giai_duoc=len(khong), theo_kieu=kieu_dem,
              nguon=dem)
    for k, v in sorted(kieu_dem.items()):
        print('  %-16s %d' % (k, v))
    print('%d/%d event giai duoc (%d mau client tu dien), %d bank, %d subsound'
          % (len(ra), len(su_kien), len(mau), tk['so_bank'], tk['so_subsound']))
    if mau:
        for ev in sorted(mau):
            print('  mau: %s' % ev)
    if khong:
        nhom = {}
        for ev, ly in khong.items():
            nhom.setdefault(ly.split(':')[0], []).append(ev)
        print('khong giai duoc %d, theo ly do:' % len(khong))
        for ly in sorted(nhom):
            print('  %-52s %d' % (ly, len(nhom[ly])))
            for ev in nhom[ly][:6]:
                print('       %s' % ev)
    if a.json:
        return 0
    DICH.parent.mkdir(parents=True, exist_ok=True)
    io.open(DICH, 'w', encoding='utf-8', newline='\n').write(json.dumps(
        dict(event_ref=ra, mau=mau, khong_giai_duoc=khong, thong_ke=tk),
        ensure_ascii=False, indent=1, sort_keys=True))
    print('-> %s' % os.path.relpath(DICH, HERE))
    return 0


if __name__ == '__main__':
    sys.exit(main())
