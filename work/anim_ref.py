# -*- coding: utf-8 -*-
"""Rut bang doi ten SPRITE -> ARMATURE cua ham `toAnimationName` ra JSON.

Vi sao can: `CPublic:toArmatureName` (sc/user/Public/CPublic.lua:2033) goi
`toAnimationName(strName)` cho TUNG tuong, TUNG linh va tung nhom dich de lap
danh sach armature nap truoc cua tran (`CPublic:SetBattleArmatureName`, :1890 —
duoc 15 cho goi tu CUIBattleDeploy/CUIArenaRecord/...). Ten do CO trong
libgame.so, nen lop gia lap khong duoc phep de no thanh BONG: doc ra bong thi
`KDebug.ProcessNotString` o :2041 that bai, ham thoat som va danh sach rong.

HAM C++ CHUA DOC RA DUOC, nhung DA DO DUOC LUAT. `toAnimationName` la mot
binding toan cuc cua engine, dang ky o 0x20c0ba trong libgame.so — ngay giua
`giveBackToSpriteCatch` va `updateSettingFile` trong bang 111 ten (cung loat voi
`createSprite`, `getUIAnimFromSpriteCatch`, `updateArmatureLanguageSuffix`).
Con tro ham nam trong bang nap luc chay, khong co trong file .so, nen khong doc
ra than duoc. Nhung chay duoc no trong may ao thi do duoc luat: xem
`emu_anim.py` — 50 ten do ngay 2026-09-18, va luat ra dung nhu bang tra o day.
Sau file cau hinh sprite cua ban goc la du lieu ma ham do doc:

    map/hero_config.xml      map/player_config.xml   map/boss_config.xml
    map/heroex_config.xml    map/sprite_config.xml   map/evil_config.xml

LUAT (do, khong suy):

  1. Muc co `<sAnimation>` -> tra ve gia tri do. Do duoc **13 muc**, TAT CA
     trong `evil_config.xml`, moi gia tri deu la armature CO THAT trong `map/`:
     `<sName>Archer_VampirE</sName>` + `<sAnimation>Archer</sAnimation>`.
  2. Muc KHONG co `<sAnimation>` -> di theo `<sBaseItem>`: muc ma no tro toi co
     `<sAnimation>` thi tra ve gia tri do. Do duoc **90 muc** nhu vay — dung
     muoi goc linh (Archer, Artillery, Catapult, Cavalry, Defender,
     ElephantSoldier, Hoplite, Priest, Spearmen, Witch) nhan chin bien the
     (`_Dong`, `_DongBoss`, `_Evil`, `_EvilBoss`, `_Shi`, `_ShiBoss`,
     `_Skeleton`, `_SkeletonBoss`, `_VampirEBoss`). Vi du `Archer_Evil ->
     Archer` — chinh no KHONG co `<sAnimation>` rieng.
  3. Khong toi mot `<sAnimation>` nao -> tra NGUYEN TEN. Con **764 muc** co
     `<sBaseItem>` ma chuoi khong toi dau: chung la toc/ao/vu khi
     (`ZhangJiao_Hair` -> `Silk_Short`) va cac chuoi dai 2-3 buoc
     (`ArcherN_Weapon_Normal2` -> `ArcherN_Weapon_Normal` -> `Archer_WeaponNormal`).

Tong: **103 dong doi ten** (13 + 90); 1865 muc con lai tra nguyen ten.

BAY DA MAC, ghi lai:

  * Luat "di theo `<sBaseItem>` den GOC roi lay ten goc" la SAI, va so do bac bo
    no: chuoi thuong ket thuc o ten KHONG phai armature (`Silk`, `weapon_throw`,
    `Player03`, `pause_HeroWake` — 0 trong so chung la thu muc armature). Luat
    dung la "di cho toi mot `<sAnimation>`", khong phai "di cho toi goc". Hai
    luat chi khac nhau o cho nay va luot doc du lieu dau tien tuong cai sau la
    luat cua ham.
  * Tren du lieu nay so buoc `<sBaseItem>` phai di **toi da la 1**, nen "mot
    buoc" va "di toi khi gap" cho ra CUNG mot ham — khong phan biet duoc bang
    du lieu. Doan ma o day di toi khi gap (co chan vong lap), va ghi ro cho
    khong phan biet duoc nay.
  * Du lieu mot minh chi noi "co `<sAnimation>`", khong noi ham co dung no lam
    ten armature. Phai chay ban goc trong may ao moi biet — da chay: 13/13 ten
    goc, 18/18 ten con, va 6 chuoi dai khong toi `<sAnimation>` deu tra nguyen
    ten.

    python anim_ref.py                          # xem thong ke
    python anim_ref.py --json <duong dan>       # ghi JSON
"""
import argparse
import glob
import io
import json
import os
import sys
import xml.etree.ElementTree as ET

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import cay

HERE = os.path.dirname(os.path.abspath(__file__))
MAP = os.path.join(cay.ASSETS, 'map')
HO = ('hero', 'heroex', 'player', 'sprite', 'boss', 'evil')

# So do duoc 2026-09-18, de mot lan lech du lieu khong di qua im lang.
SO_MUC = 1968
SO_TRUC_TIEP = 13
SO_DOI_TEN = 103
CHAN_BUOC = 8


def doc_armature():
    """Ten cac armature CO THAT: ten file .xml trong map/ (bo cac file cau hinh)."""
    canh = set()
    for p in glob.glob(os.path.join(MAP, '*.xml')):
        ten = os.path.splitext(os.path.basename(p))[0]
        if ten not in [h + '_config' for h in HO]:
            canh.add(ten)
    return canh


def doc_muc():
    """Moi muc co <sName> trong sau file cau hinh -> ban ghi cac truong con."""
    muc = {}
    for h in HO:
        p = os.path.join(MAP, h + '_config.xml')
        if not os.path.exists(p):
            raise SystemExit('thieu ' + p)
        goc = ET.parse(p).getroot()

        def di(el):
            for c in el:
                nm = c.find('sName')
                if nm is not None and nm.text:
                    # Chi lay truong la (khong co con) — lsAdapt/... la khung.
                    muc[nm.text] = {g.tag: (g.text or '').strip()
                                    for g in c if len(g) == 0}
                di(c)
        di(goc)
    return muc


def giai(muc, ten):
    """<sAnimation> dau tien gap tren chuoi <sBaseItem>, hoac None.

    Di cho toi khi gap, chu khong phai toi goc — xem dau file. Chan vong lap
    bang tap da thay va bang so buoc, vi du lieu do khong co vong nhung mot lan
    du lieu lech thi vong lap se treo chu khong bao loi.
    """
    thay = set()
    for _ in range(CHAN_BUOC):
        if ten in thay or ten not in muc:
            return None
        thay.add(ten)
        an = muc[ten].get('sAnimation')
        if an:
            return an
        ten = muc[ten].get('sBaseItem')
        if not ten:
            return None
    return None


def rut(muc, arm):
    doi = {}
    for ten in sorted(muc):
        an = giai(muc, ten)
        if not an or an == ten:
            if an == ten:
                raise SystemExit('%s: <sAnimation> bang chinh <sName>, vo nghia' % ten)
            continue
        doi[ten] = an
    # Moi dich phai la armature co that — neu khong thi bang tra nay sai.
    for ten, an in sorted(doi.items()):
        if an not in arm:
            raise SystemExit('%s -> %s: %s khong phai armature trong %s'
                             % (ten, an, an, MAP))
    return doi


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--json', help='ghi bang tra ra file JSON')
    a = ap.parse_args()

    arm = doc_armature()
    muc = doc_muc()
    doi = rut(muc, arm)

    truc = [t for t in muc if muc[t].get('sAnimation')]
    co_goc = [t for t in muc if muc[t].get('sBaseItem')]
    buoc = {}
    for t in doi:
        n, x = 0, t
        while x in muc and not muc[x].get('sAnimation'):
            x = muc[x].get('sBaseItem')
            n += 1
        buoc[n] = buoc.get(n, 0) + 1

    print('armature trong %s: %d' % (MAP, len(arm)))
    print('muc co <sName>: %d%s' % (
        len(muc), '' if len(muc) == SO_MUC else '   <<< LECH, phai la %d' % SO_MUC))
    print('muc co <sAnimation> truc tiep: %d%s' % (
        len(truc), '' if len(truc) == SO_TRUC_TIEP else
        '   <<< LECH, phai la %d' % SO_TRUC_TIEP))
    print('muc co <sBaseItem>: %d' % len(co_goc))
    print('bang doi ten: %d dong%s  (so buoc <sBaseItem> phai di: %s)' % (
        len(doi), '' if len(doi) == SO_DOI_TEN else
        '   <<< LECH, phai la %d' % SO_DOI_TEN,
        ', '.join('%d buoc: %d muc' % (k, v) for k, v in sorted(buoc.items()))))
    for ten in sorted(doi):
        print('  %-28s -> %s' % (ten, doi[ten]))

    if a.json:
        b = {
            'note': 'ten sprite -> ten armature cua ham toAnimationName. Luat DO '
                    'DUOC (work/emu_anim.py, 50 ten chay trong may ao): tra '
                    '<sAnimation> cua muc, neu muc khong co thi tra <sAnimation> '
                    'cua muc ma <sBaseItem> tro toi; khong toi mot <sAnimation> '
                    'nao thi tra nguyen ten.',
            'nguon': {'cau_hinh': 'map/%s_config.xml' % '|'.join(HO),
                      'khoa': 'toAnimationName dang ky o 0x20c0ba trong libgame.so',
                      'do_tren_may_ao': 'work/emu_anim.py (50 ten, 13 truc tiep + '
                                        '18 con + 6 chuoi dai + 13 ten doi chieu)'},
            'doi_ten': doi,
        }
        with io.open(a.json, 'w', encoding='utf-8', newline='\n') as f:
            json.dump(b, f, ensure_ascii=False, indent=1, sort_keys=True)
        print('da ghi', a.json)


if __name__ == '__main__':
    main()
