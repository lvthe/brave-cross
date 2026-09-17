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
  2. CHO ENGINE DUNG hai hang so do: `0x35f43e` (vn) — lop `CDFTMXTiledMap`,
     vtable `0x00895ac8`, RTTI `0x00895de8`:

         0x35f446  bl 0x38c7f0              ; singleton cau hinh
         0x35f44c  vldr s16,[r0,#0x14]      ; fLaneWidth  (+0x18 la fLaneOffset)
         0x35f456  ldr.w r3,[r3,#0x270]     ; slot ao +0x270
         0x35f45c  vldr s15,[r0,#4]         ; CO O, tinh bang px
         0x35f460  vmul.f32 s15,s16,s15
         0x35f464  vstr s15,[r4,#0x264]     ; be ngang lan, PX

     Slot `+0x270` la `0x35e73a` (vn) = `return this + 0x180`, tuc cap `(rong,
     cao)` cua O. Ba bang chung doc lap noi cap ay la CO O TINH BANG PX:
       * `0x35f068` (vn) viet cung `100*(4-idx)` — 100 px moi o;
       * `InWhichCell` `0x35ec4c` (vn) chan diem theo `v270()[0] * v268()[0]` va
         `v270()[+4] * v268()[+4]` — tuc "co o x so o", roi chia lay chi so o;
       * `map/map_1.tmx` (file TMX duy nhat cua game) khai
         `tilewidth="100" tileheight="100"`, o dat `CDFMapGround 100x100`.
  3. CONG THUC XEP LAN, tu `0x35f0a4` (vn): `y = y0 + (Location-1) * be_ngang_px
     + lech_px`. `Location` doc tu ban ghi sprite (1..3, 0 = khong co lan rieng)
     va bi lam roi bang XOR 4 byte tai `unit+0x484`; ket qua ghi vao `+0x264`
     (be ngang) va `+0x268` (lech) cua chinh doi tuong do.

     => lan 1 lech 10 px, lan 2 lech 50 px, lan 3 lech 90 px so voi y0.

  4. `fArmySpace` (1.1 o = 110 px) la KHOANG CACH GIUA HAI QUAN CUNG MOT TOAN:
     cau hinh ghi chu `<!-- 军队长度间距 -->` ("do dai & khoang cach cua quan")
     tren bo ba `fArmyLength` / `fArmySpace` / `fArmySpaceInArena`. Do duoc them
     mot bang chung nua: engine co HAI ham doc, khac nhau dung o cho lay o cach:
     `0x38193c` (vn) lay `+0x70` (fArmyLength) va `+0x74` (fArmySpace), con
     `0x388240` (vn) lay `+0x70` va `+0x78` (fArmySpaceInArena) — tuc ban dau la
     san thuong, ban sau la dau truong (竞技场), dung nhu ten.
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

HAI BAN `.so` — MOI DIA CHI PHAI NOI RO NO THUOC BAN NAO
--------------------------------------------------------
Trong `work/` co HAI ban `libgame.so` KHAC NHAU ve bo cuc ma:

    apk/lib/armeabi-v7a/libgame.so    10.231.498 byte, 2017-10-25
    vn/apk/lib/armeabi-v7a/libgame.so 10.213.832 byte, 2017-12-28

Khong co doan byte nao giong nhau giua hai ban (do), nen dia chi KHONG dung
chung duoc: cung mot chuoi `DispatchButtonDisable` nam o `0x7c57f8` (apk) va
`0x7c1bb6` (vn). **Ban `vn` moi la ban tham chieu cua ban dung** — `sc/` va
`data_ref` cua game lay tu `work/vn/decrypted/assets`. Vi vay moi dia chi duoi
day ghi ro `vn` hay `apk`, va da do lai TUNG cai tren dung ban ay. Cac dia chi
cu ghi trong tai lieu (ROADMAP, CLAUDE.md) deu DUNG vi chung o KHONG GIAN VN;
mot luot "sua lai" truoc day (2026-09-17) doc nham ban apk roi tuong chung sai
— bai hoc: truoc khi bac bo mot dia chi, phai biet no thuoc ban nao.
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
                'engine nhan voi co o tinh bang px (0x35f43e, ban vn). Sinh bang: '
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
            'ban_so': 'moi dia chi duoi day la cua BAN VN (work/vn/apk/...), ban '
                      'tham chieu cua ban dung; ban apk lech hoan toan (xem dau file)',
            'hang_so_lan': '0x35f43e (vn): vldr s16,[r0,#0x14] (fLaneWidth) roi nhan '
                           'voi slot ao +0x270 (0x35e73a = this+0x180, cap co o)',
            'hang_so_lan2': '0x35f43e (vn): vldr s16,[r0,#0x18] (fLaneOffset), cung '
                            'duong, ghi vao +0x268',
            'xep_lan': '0x35f0a4 (vn): y = y0 + (Location-1)*[+0x264] + [+0x268]',
            'co_o_px': '0x35f068 (vn) viet cung 100*(4-idx); 0x35ec4c chan diem theo '
                       'v270()[i]*v268()[i]; map_1.tmx khai 100x100',
            'o_cach_quan': '0x38193c (vn) lay fArmySpace (+0x74), 0x388240 (vn) lay '
                           'fArmySpaceInArena (+0x78) — hai ham doc, hai loai san',
            'so_lan': 'Location cua bang binh chung: %s' % loc['nguon'],
            # Them 2026-09-17. Ba su that doc ra tu .so, dung de chot cho DAT
            # toan linh dua ra (xem `chua_do_duoc` ngay duoi).
            'do_dai_toan_px': '0x382670 (vn): fArmySpace * fArmyLength * co o px '
                              '(1.1 * 4 * 100 = 440 px). Hai he so lay qua hai ham '
                              'doc cau hinh 0x38193c (+0x70 = fArmyLength) va ban '
                              'anh em 0x388240, roi nhan voi cap co o px '
                              '(this+0x180)',
            'lech_nua_toan_px': '0x41b538 (vn): X -= fArmyLength * 0.5 * co o px '
                                '= 200 px (vsub.f32 tai 0x41b58c). Dau THAT do '
                                '0x414912 quyet dinh: no lat bit dau khi co o '
                                '`[obj+0x308]` khac 1, nen cung ham ay chay ra '
                                'cong hoac tru. Day la vi du thu HAI cua loi '
                                '"hang so tinh bang O nhan co o px"',
            'dispatch_khong_tinh_toa_do': '0x45eef0 (vn) -> 0x45eda4 (than dispatch()) '
                                          'chi goi 0x466220: danh dau quan (+0x5a4 '
                                          '= 0x44) roi noi vao danh sach cua san '
                                          '(+0x39c). Khong mot phep tinh toa do '
                                          'nao — nen cho dung cua quan dua ra la '
                                          'cho dung cua TOAN (SUY RA, xem duoi)',
            # Them 2026-09-17 (luot sau): HAI CO nut bam cua lop drama. Truoc day
            # hai lenh `SeDispatchButtonDisable` / `SetWakeButtonDisable` bi coi la
            # "lenh trang thai vo nghia, chi ghi nhat ky" — SAI: chung ghi co that.
            'co_nut_binh_chung': '0x468b54 (vn) = SeDispatchButtonDisable, 0x468b78 '
                                 '(vn) = SetWakeButtonDisable (ban apk: 0x46af20 / '
                                 '0x46af44): `r0 = lua_toboolean(arg); eor r0,r0,#1; '
                                 'strb.w r0,[drama+0x390]` (binh chung) va `+0x391` '
                                 '(thuc tinh) tai 0x468b6a / 0x468b8e — tuc hai byte '
                                 'ay la co BAN (1 = bam duoc) va gia tri truyen vao '
                                 'bi DAO truoc khi ghi',
            'doc_co_nut': '0x45d554 (vn) doc lai +0x390, 0x462308 (vn) doc +0x391; '
                          'ca hai tra 0 tru khi `[drama+0x37c] == 1` (ban +0x390 con '
                          'tra 0 khi `[drama+0x3fd]` khac 0). Ban apk: 0x45f8b4 / '
                          '0x4646d4. Ban goc GAC o C++ — `CUIGame:TouchArrmy` '
                          '(sc/user/Battle/CUIGame.lua:4055) goi thang dispatch(), '
                          'Lua khong he hoi co',
            'chuoi_json_khong_xref_duoc': 'PosX (0x7bc0b7) / PosY / Soldiers / '
                                          'NpcID / AppearTime nam trong .rodata '
                                          '(ban apk; ban vn lech), nhung KHONG mot '
                                          'word 4 byte nao trong ca file tro vao '
                                          '0x7bc000-0x7bd000 — nen duong engine -> '
                                          'parse JSON khong truy duoc bang tinh '
                                          'toan tinh',
        },
        'chua_do_duoc': {
            # Sua 2026-09-17 (luot sau): truoc day cho nay ghi "DA CHOT" va ban
            # dung da doi `dua_linh` sang dung moc cua toan. Doi xong thi
            # `do_chien_dich --kichban` TUT tu 9 dat / 0 hong xuong 6 dat / 3 hong,
            # nen da BO, va ghi lai dung trang thai that.
            #
            # Sua 2026-09-18 (luot sau nua): LY DO cua lan BO do hoa ra la mot loi
            # THAT cua ban dung, va loi do DA VA — xem muc (2) duoi day. Nen viec
            # "dat ngay moc" nay da duoc DO LAI cung ngay: xem muc (3).
            'cho_dat_toan_linh': 'MOC CUA TOAN thi la so DO: Sprite.Troop.PosX '
                                 '(CUIGame:FitBattleArmyPos dat 3.83 / 7.1 / 7 o; '
                                 'FightLogic:GetSelfFightDataBody mac dinh 7; do '
                                 'trong tran that L_N_01_01 bang `do_chien_dich '
                                 '--kiem`: 7 o = 700 px). Nhung CHO DAT toan linh '
                                 'DUA RA thi van la ĐẶT: ban dung dat o o 0 (mep '
                                 'trai san). DA THU dat ngay moc (2026-09-17) va '
                                 'PHAI BO — `--kichban` tut 9/0 xuong 6/3. LY DO '
                                 'THAT cua cu tut do (do tiep 2026-09-18): luc ay '
                                 '`dung_tran` goi `T.hen:stop()`, ma chinh `hen:buoc` '
                                 'moi la cho BUOC KICH BAN (`kb:buoc`) — nen tran '
                                 'xong la kich ban dung han (do: nhat ky kich ban '
                                 'ket o `ChangeFight LvBuEvil Fight`, thieu '
                                 '`MoveThenDo` / `SetArmyWaiting`). Do la loi cua '
                                 'ban dung, va DA VA. (3) DA DO LAI cung ngay, sau '
                                 'khi va: dat ngay moc ra 11 dat / 0 hong — Y HET '
                                 'luot dat o o 0, cung nhat ky kich ban, cung 1379 '
                                 'khung; khac biet DUY NHAT: tran xong som hon theo '
                                 'GIO TRAN ("song 0 giay 18" so voi "giay 57"). VI '
                                 'VAY ket qua "dat ngay moc lam tut kich ban" la he '
                                 'qua cua hai loi da va, khong phai cua cho dat — '
                                 'va vi bo do KHONG phan biet duoc hai cho dat, ban '
                                 'dung GIU NGUYEN o o 0 (doi la doi hanh vi ma khong '
                                 'co bang chung nao doi theo). GIA THIET CU ("may do '
                                 'bam nut '
                                 'ke ca trong cua so CO NUT bi cam") DA BI BAC BO '
                                 'bang phep do: kich_ban.lua nay giu co that cua '
                                 'SeDispatchButtonDisable (+0x390, xem `do_duoc`) va '
                                 'san_tran.lua DEM so lan bam trong luc bi cam — do '
                                 'duoc 0 lan (lenh cam nam GAN CUOI kich ban, sau '
                                 'khi quan da ra het). CON LAI: (a) do tren ban goc '
                                 '(duong may ao da DO va CHET: co bDirectBattle cua '
                                 'CUIGame:Test() toi "TRAN|chen duoc, bDirectBattle '
                                 '= true" roi SIGSEGV trong RepaleceScene — '
                                 'work/emu_dom.py, work/emu_tran.py), hoac (b) cho '
                                 'may do TUAN THEO co ay. Kem: nguoi dau tien dung '
                                 'ngay moc hay lech nua toan (X -= fArmyLength * 0.5 '
                                 '* co o = 200 px o 0x41b538 vn, xem `do_duoc`), va '
                                 'nhip cach giua cac TOAN dua ra (ban dung lay '
                                 'fArmySpace = 110 px).',
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
