# -*- coding: utf-8 -*-
"""Be hang so SAN TRAN ra JSON cho Godot dung: khoi <stage>/<army>/<camera> cua
`map/global_config.xml`, cong co o cua `map/map_1.tmx`.

    python tran_ref.py --out <thu_muc_data_ref>

VI SAO
------
Man tran cua ta dang chep tay may hang so nay (`LAN_CACH = 40`, `LAN_LECH = 10`,
`ARMY_SPACE = 1.1`, nam hang so camera...) va ghi chu chung la "suy tu chinh file
do". Do la cho ĐẶT: chua doc duoc cho engine dung chung. Nay doc duoc, va bang
nay giu ca duong doc lan con so:

  1. DON VI la O (格) — khong phai suy luan nua: chinh file cau hinh ghi chu
     ngay tren cap hang so do:

         <!-- 道宽 格 -->          <- "be ngang duong (lan), tinh bang O"
         <fLaneWidth>0.4</fLaneWidth>
         <fLaneOffset>0.1</fLaneOffset>

     Cong cu nay boc luon chu thich ay ra truong `chung` de bang giu bang chung.
  2. CHO ENGINE DUNG hai hang so do: `0x35f43e` (lop `CDFTMXTiledMap`, vtable
     `0x00895ac8`, RTTI `0x00895de8`):

         0x35f446  bl 0x38c7f0              ; singleton cau hinh
         0x35f44c  vldr s16,[r0,#0x14]      ; fLaneWidth  (+0x18 la fLaneOffset)
         0x35f456  ldr.w r3,[r3,#0x270]     ; slot ao +0x270
         0x35f45c  vldr s15,[r0,#4]         ; CO O, tinh bang px
         0x35f460  vmul.f32 s15,s16,s15
         0x35f464  vstr s15,[r4,#0x264]     ; be ngang lan, PX

     Slot `+0x270` la `0x35e73a` = `return this + 0x180`, tuc cap `(rong, cao)`
     cua O. Ba bang chung doc lap noi cap ay la CO O TINH BANG PX:
       * `0x35f068` viet cung `100*(4-idx)` — 100 px moi o;
       * `InWhichCell` `0x35ec4c` chan diem theo `v270()[0] * v268()[0]` va
         `v270()[+4] * v268()[+4]` — tuc "co o x so o", roi chia lay chi so o;
       * `map/map_1.tmx` (file TMX duy nhat cua game) khai
         `tilewidth="100" tileheight="100"`, o dat `CDFMapGround 100x100`.
  3. CONG THUC XEP LAN, tu `0x35f0a4`: `y = y0 + (Location-1) * be_ngang_px +
     lech_px`. `Location` doc tu ban ghi sprite (1..3, 0 = khong co lan rieng) va
     bi lam roi bang XOR 4 byte tai `unit+0x484`; ket qua ghi vao `+0x264` (be
     ngang) va `+0x268` (lech) cua chinh doi tuong do.

     => lan 1 lech 10 px, lan 2 lech 50 px, lan 3 lech 90 px so voi y0.

  4. `fArmySpace` (1.1 o = 110 px) la KHOANG CACH GIUA HAI QUAN CUNG MOT TOAN:
     cau hinh ghi chu `<!-- 军队长度间距 -->` ("do dai & khoang cach cua quan")
     tren bo ba `fArmyLength` / `fArmySpace` / `fArmySpaceInArena`. Do duoc them
     mot bang chung nua: engine co HAI ham doc, khac nhau dung o cho lay o cach:
     `0x38193c` lay `+0x70` (fArmyLength) va `+0x74` (fArmySpace), con `0x388240`
     lay `+0x70` va `+0x78` (fArmySpaceInArena) — tuc ban dau la san thuong, ban
     sau la dau truong (竞技场), dung nhu ten.
  5. SO LAN la so DO, khong phai chon: `Location` cua tung binh chung nam trong
     `config/share/KDBGameArmyConfig.xgg` (91 muc: 48 muc lan 1, 23 muc lan 2,
     19 muc lan 3, 1 muc 0 = tuong nguoi choi). Cong cu dem luon ra day, nen
     `LAN_SO = 3` cua man tran khong con la con so ta tu nghi ra.

Cai gi KHONG doc duoc tu .so, ghi lai cho khoi tuong da do:
  * CHO DAT TOAN LINH dau tien khi nguoi choi bam nut 放兵 — client chi goi
    `CUIGame:TouchArrmy` -> `self.tArmyIcons[id]:dispatch()`, ma `dispatch` va
    `setDispatchID` KHONG file Lua nao dinh nghia (do bang grep ca cay `sc/`),
    tuc no nam trong lop C++ cua engine, va che do thu cua chinh engine thi
    TU SINH du lieu quan (`g_BattleField:setSendTroops("", self.test)` voi
    `self.test = true`, `CUIGame.lua:877-881`). Nen vi tri ay khong suy ra duoc
    tu file .so.
  * Chu thich cua `CUIGame:Test()` (che do thu cua engine) dat `bDirectBattle` —
    co the dung no de DO tren may ao; xem ROADMAP muc "Cho dung quan".
"""
import argparse
import io
import json
import os
import re
import sys
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_MAP = os.path.join(HERE, 'vn', 'decrypted', 'assets', 'map')
DEFAULT_CFG = os.path.join(HERE, 'vn', 'decrypted', 'assets', 'config')

## Bang binh chung cua ban goc — nguon cua `Location` (so lan).
BANG_LINH = os.path.join('share', 'KDBGameArmyConfig.xgg')

## Ba khoi cua global_config.xml ma man tran dung.
KHOI = ('stage', 'army', 'camera')

## So do (2026-09-18) — de mot lan lech du lieu khong di qua im lang.
SO_O = 100


def _doc(path):
    with open(path, 'rb') as fp:
        return fp.read().decode('utf-8', 'replace')


def _in(s):
    """In ra stdout dang BYTE UTF-8: console Windows (cp1252) khong in duoc chu
    Trung cua chu thich goc, ma chu thich ay la bang chung don vi."""
    sys.stdout.buffer.write((s + '\n').encode('utf-8'))
    sys.stdout.buffer.flush()


def _so(s):
    """Chuoi trong XML -> int/float/list. Giu nguyen chuoi neu khong phai so."""
    s = s.strip()
    m = re.fullmatch(r'\{([^}]*)\}', s)
    if m:
        return [_so(x) for x in m.group(1).split(',')]
    try:
        return int(s)
    except ValueError:
        pass
    try:
        return float(s)
    except ValueError:
        return s


def _khoi(s, ten):
    """Cac truong LA (khong co con) cua mot khoi <ten>."""
    m = re.search(r'<%s>(.*?)</%s>' % (ten, ten), s, re.S)
    if not m:
        raise SystemExit('khong thay khoi <%s> trong global_config.xml' % ten)
    e = ET.fromstring('<x>%s</x>' % m.group(1))
    out = {}
    for c in e:
        if len(c) == 0 and (c.text or '').strip():
            out[c.tag] = _so(c.text)
    return out


def _chu_thich(s, tag):
    """Chu thich XML ngay TRUOC <tag> — bang chung don vi cua ban goc."""
    i = s.find('<%s>' % tag)
    if i < 0:
        return ''
    j = s.rfind('<!--', 0, i)
    if j < 0:
        return ''
    k = s.find('-->', j)
    if k < 0 or k > i:
        return ''
    return s[j + 4:k].strip()


def _tmx(path):
    s = _doc(path)
    m = re.search(r'<map\b[^>]*>', s)
    if not m:
        raise SystemExit('khong doc duoc <map> cua %s' % path)
    a = dict(re.findall(r'(\w+)="([^"]*)"', m.group(0)))
    dat = re.search(r'<object\b[^>]*name="CDFMapGround"[^>]*>', s)
    return {
        'rong_px': int(a['tilewidth']), 'cao_px': int(a['tileheight']),
        'so_o_rong': int(a['width']), 'so_o_cao': int(a['height']),
        'dat': dict(re.findall(r'(\w+)="([^"]*)"', dat.group(0))) if dat else {},
    }


def _location(path):
    """Dem `Location` cua bang binh chung: {gia tri: so muc} + so muc.

    Day la cho tra loi "co MAY lan" bang du lieu chu khong bang suy luan: ban ghi
    sprite nao mang `Location` n thi vao lan ay (0 = khong co lan rieng).
    """
    with io.open(path, encoding='utf-8') as f:
        d = json.load(f)
    dem = {}
    for x in d:
        k = int(x.get('Location', 0))
        dem[k] = dem.get(k, 0) + 1
    return {'muc': len(d), 'dem': dem,
            'lan_so': max(dem) if dem else 0,
            'nguon': 'config/' + BANG_LINH}


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--map', default=DEFAULT_MAP, help='mac dinh: %(default)s')
    ap.add_argument('--config', default=DEFAULT_CFG, help='mac dinh: %(default)s')
    ap.add_argument('--out', default=os.path.join(
        HERE, '..', '..', 'bravecross-game', 'data_ref'))
    a = ap.parse_args()
    cfg = os.path.join(a.map, 'global_config.xml')
    tmx = os.path.join(a.map, 'map_1.tmx')
    for p in (cfg, tmx, os.path.join(a.config, BANG_LINH)):
        if not os.path.exists(p):
            raise SystemExit('khong thay ' + p)
    s = _doc(cfg)
    o = _tmx(tmx)
    loc = _location(os.path.join(a.config, BANG_LINH))

    khoi = {t: _khoi(s, t) for t in KHOI}
    rong_o = float(khoi['stage']['fLaneWidth'])
    lech_o = float(khoi['stage']['fLaneOffset'])
    rong_px = round(rong_o * o['rong_px'], 2)
    lech_px = round(lech_o * o['cao_px'], 2)

    b = {
        'note': 'hang so san tran cua ban goc: khoi <stage>/<army>/<camera> cua '
                'map/global_config.xml + co o cua map/map_1.tmx. Don vi cua '
                'fLaneWidth/fLaneOffset la O (格) — chinh file do ghi chu, va '
                'engine nhan voi co o tinh bang px (0x35f43e). Sinh bang: '
                'python tran_ref.py (brave-cross/work).',
        'o_px': o['rong_px'],
        'co_o': o,
        'lan': {
            'rong_o': rong_o, 'rong_px': rong_px,
            'lech_o': lech_o, 'lech_px': lech_px,
            'lan_so': loc['lan_so'],
            'location_dem': loc['dem'],
            'location_nguon': '%s (%d muc)' % (loc['nguon'], loc['muc']),
            'chung': {'fLaneWidth': _chu_thich(s, 'fLaneWidth'),
                      'fLaneOffset': _chu_thich(s, 'fLaneOffset')},
            'cong_thuc': 'y = y0 + (Location-1) * rong_px + lech_px',
            'lech_px_theo_lan': [round(lech_px + (n - 1) * rong_px, 2)
                                 for n in range(1, loc['lan_so'] + 1)],
        },
        'stage': khoi['stage'],
        'army': khoi['army'],
        'camera': khoi['camera'],
        'do_duoc': {
            'hang_so_lan': '0x35f43e: vldr s16,[r0,#0x14] (fLaneWidth) roi nhan '
                           'voi slot ao +0x270 (0x35e73a = this+0x180, cap co o)',
            'hang_so_lan2': '0x35f43e: vldr s16,[r0,#0x18] (fLaneOffset), cung '
                            'duong, ghi vao +0x268',
            'xep_lan': '0x35f0a4: y = y0 + (Location-1)*[+0x264] + [+0x268]',
            'co_o_px': '0x35f068 viet cung 100*(4-idx); 0x35ec4c chan diem theo '
                       'v270()[i]*v268()[i]; map_1.tmx khai 100x100',
            'o_cach_quan': '0x38193c lay fArmySpace (+0x74), 0x388240 lay '
                           'fArmySpaceInArena (+0x78) — hai ham doc, hai loai san',
            'so_lan': 'Location cua bang binh chung: %s' % loc['nguon'],
            # Them 2026-09-17. Ba su that doc ra tu .so, dung de chot cho DAT
            # toan linh dua ra (xem `chua_do_duoc` ngay duoi).
            'do_dai_toan_px': '0x382670: fArmySpace * fArmyLength * co o px '
                              '(1.1 * 4 * 100 = 440 px) — lay qua slot ao +0x3ac '
                              '(0x38193c) roi slot +0x270 (0x35e73a = this+0x180, '
                              'cap co o px). Vi du thu BA cua loi "hang so tinh '
                              'bang O nhan co o px" (sau 0x35f43e va 0x41b538)',
            'dispatch_khong_tinh_toa_do': '0x45eef0 -> 0x45eda4 (than dispatch()) '
                                          'chi goi 0x466220: danh dau quan (+0x5a4 '
                                          '= 0x44) roi noi vao danh sach cua san '
                                          '(+0x39c). Khong mot phep tinh toa do '
                                          'nao — nen cho dung cua quan dua ra la '
                                          'cho dung cua TOAN',
            'chuoi_json_khong_xref_duoc': 'PosX (0x7bc0b7) / PosY / Soldiers / '
                                          'NpcID / AppearTime nam trong .rodata, '
                                          'nhung KHONG mot word 4 byte nao trong '
                                          'ca file tro vao 0x7bc000-0x7bd000 — '
                                          'nen duong engine -> parse JSON khong '
                                          'truy duoc bang tinh toan tinh',
        },
        'chua_do_duoc': {
            # Chot 2026-09-17: KHONG con la "chua do duoc" theo nghia bo ngo.
            # Cho dung = `Sprite.Troop.PosX` (do trong tran that: 7 o = 700 px,
            # ai L_N_01_01). Duong may ao da DO va chet — xem ghi chu.
            'cho_dat_toan_linh': 'Nay da co so: moc cua TOAN = Sprite.Troop.PosX '
                                 '(CUIGame:FitBattleArmyPos dat 3.83 / 7.1 / 7 o; '
                                 'FightLogic:GetSelfFightDataBody mac dinh 7). '
                                 'dispatch() cua C++ khong tinh toa do nen quan '
                                 'dua ra dung moc cua toan. CON LAI (chua ro): '
                                 'nguoi dau tien dung ngay moc hay lech nua toan '
                                 '(engine co X -= fArmyLength * 0.5 * co o = 200 px '
                                 'o 0x41b538), va nhip cach giua cac TOAN dua ra '
                                 '(ta dung fArmySpace). DUONG MAY AO: da do, CHEt — '
                                 'co bDirectBattle cua CUIGame:Test() chay toi '
                                 '"TRAN|chen duoc, bDirectBattle = true" roi '
                                 'SIGSEGV trong RepaleceScene (work/emu_dom.py, '
                                 'work/emu_tran.py).',
        },
    }

    if o['rong_px'] != SO_O or o['cao_px'] != SO_O:
        print('CANH BAO: co o khong phai %d px ma la %dx%d'
              % (SO_O, o['rong_px'], o['cao_px']))

    os.makedirs(a.out, exist_ok=True)
    dich = os.path.join(a.out, 'tran_ref.json')
    with io.open(dich, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(b, f, ensure_ascii=False, indent=1, sort_keys=True)

    _in('co o: %dx%d px (%dx%d o) — %s' % (
        o['rong_px'], o['cao_px'], o['so_o_rong'], o['so_o_cao'], tmx))
    print('lan: rong %s o = %s px, lech %s o = %s px' % (
        rong_o, rong_px, lech_o, lech_px))
    print('     lech theo lan 1..%d: %s px' % (loc['lan_so'], b['lan']['lech_px_theo_lan']))
    _in('so lan: %d — Location dem duoc %s (%d muc cua %s)' % (
        loc['lan_so'], loc['dem'], loc['muc'], loc['nguon']))
    _in('     chu thich cua ban goc: %s' % (
        ' | '.join('%s=%s' % (k, v) for k, v in b['lan']['chung'].items())))
    print('quan cung toan: fArmyLength %s, fArmySpace %s o = %s px, '
          'fArmySpaceInArena %s' % (
              khoi['army']['fArmyLength'], khoi['army']['fArmySpace'],
              round(float(khoi['army']['fArmySpace']) * o['rong_px'], 2),
              khoi['army']['fArmySpaceInArena']))
    print('da ghi', dich)
    return 0


if __name__ == '__main__':
    sys.exit(main())
