# -*- coding: utf-8 -*-
"""Bang tra tieng dong theo hoat dong va tieng trung don, doc tu bang cau hinh
cua ban goc.

    python trigger_ref.py            # ghi JSON
    python trigger_ref.py --json     # chi in thong ke

Nguon : brave-cross/work/vn/apk/assets/banks/{sound_config,hit_config,
        bank_config}.xml  (nam TRAN trong APK, khong ma hoa; hit_config la GBK)
Dich  : bravecross-game/data_ref/trigger_ref.json

VI SAO CAN. Ban goc khong phat tieng trong tran bang Lua: do tren 973 file Lua
trong `sc/`, khong file nao doc ba bang nay — chung chi xuat hien o
`sngCrcCache.sc` (bang bam CRC cua tai nguyen) va trong `libgame.so`. Engine C++
tu doc roi tu phat khi armature chay toi khung. Muon giong ban goc thi phai lam
lai dung luat do tu chinh du lieu, khong suy dien.

BA BANG, ba luat khac nhau:

  * `sound_config.xml` — `<armature><action><Sound frame sound loop/>`: armature
    chay dong tac nao thi toi KHUNG thu may thi phat tieng gi. `frame` dem tu 0
    theo chi so khung cua chinh dong tac do.
  * `hit_config.xml` — tieng TRUNG DON, va no ghep tu ba manh:
      - `<armatures>`: ben DANH, theo armature + dong tac, moi cu danh (theo
        `index`) co mot `kitMaterial` (loai vu khi: 1 sac, 2 don, 3 cung/lao,
        4 nhac cu, 5 phep, 6 nang, 7 hoa khi, 8 bang, 9 lua, 10 set);
      - `<armors>`: ben CHIU, theo armature, co `armorMaterial` (1 kim loai,
        2 go, 3 than, 4 da);
      - `<events>`: khoa `"<kit>_<giap>_<do manh>"` (do manh 1 nhe, 2 nang) tra
        ra `event:/Impact/...`.
    17 trong 226 cu danh con co `specifyEvent` / `specifyPlugin`: chi so de
    CHI DINH san, va 17/17 deu la 0 hoac 5 (xem `chi_dinh` duoi day).
  * `bank_config.xml` — armature -> `banks/X.bank`. Ghi vao day chi de DOI
    CHIEU: moi tieng cua mot armature phai nam trong bank cua chinh no. Ban
    goc nap bank theo tung tuong (`loadEffectBank`, xem BANK.md).

KHONG khoi phuc duoc, va khong bia: `specifyEvent` / `specifyPlugin` chi xuat
hien 17 lan va gia tri la 0 hoac 5, khong co bang nao noi "5" la gi (chi so vao
`<events>` theo thu tu? vao `<plugins>`?). Bang `events` duoc tra theo KHOA
chuoi nen khong can chi so do; JSON giu nguyen gia tri goc de ben dung tu quyet
dinh. Cach ghep `<kit>_<giap>_<do manh>` thi doc thang tu khoa cua chinh bang
do; con luc nao la "nhe" / "nang" thi engine quyet dinh, o day khong doan.
"""
import argparse
import collections
import io
import json
import pathlib
import re
import sys
import xml.etree.ElementTree as ET

HERE = pathlib.Path(__file__).resolve().parent
BANKS = HERE / 'vn' / 'apk' / 'assets' / 'banks'
DICH = HERE.parent.parent / 'bravecross-game' / 'data_ref' / 'trigger_ref.json'


def _doc(ten, ma):
    """Doc mot file XML cua APK. `hit_config.xml` la GBK, hai file kia UTF-8."""
    return io.open(BANKS / ten, encoding=ma, errors='replace').read()


def _bo_chu_thich(d):
    """Bo chu thich XML, tra (van ban, so chu thich co `--` ben trong).

    Phai bo bang tay: `hit_config.xml` cua ban goc co chu thich chua `--` o
    giua — dong 363 `<!--董卓魔化--没必要加特效音效了-->` — va XML khong cho
    phep `--` trong chu thich, nen `xml.etree` dung ngay o do
    ("not well-formed (invalid token)"). Day la du lieu goc, khong phai loi
    doc: cat chu thich di la doc duoc het 84 armature.
    """
    n = 0
    for m in re.finditer(r'<!--(.*?)-->', d, re.S):
        if '--' in m.group(1):
            n += 1
    return re.sub(r'<!--.*?-->', '', d, flags=re.S), n


def tieng_hoat_dong():
    """armature -> action -> [{khung, su_kien, lap}]."""
    goc = ET.fromstring(_doc('sound_config.xml', 'utf-8'))
    ra = collections.OrderedDict()
    n_khung_lap = 0
    for arm in goc:
        for act in arm:
            ds = []
            for s in act.findall('Sound'):
                lap = s.get('loop', '0') == '1'
                if lap:
                    n_khung_lap += 1
                ds.append(collections.OrderedDict([
                    ('khung', int(s.get('frame'))),
                    ('su_kien', s.get('sound')),
                    ('lap', lap),
                ]))
            if ds:
                ra.setdefault(arm.tag, collections.OrderedDict())[act.tag] = ds
    return ra, n_khung_lap


def trung_don():
    d, n_thich_la = _bo_chu_thich(_doc('hit_config.xml', 'gbk'))
    goc = ET.fromstring(d)

    danh = collections.OrderedDict()
    n_chi_dinh = 0
    for arm in goc.find('armatures'):
        for act in arm.findall('action'):
            ds = []
            for s in act.findall('strike'):
                cd = int(s.get('specifyEvent', '0'))
                cp = int(s.get('specifyPlugin', '0'))
                if cd or cp:
                    n_chi_dinh += 1
                ds.append(collections.OrderedDict([
                    ('index', int(s.get('index'))),
                    ('kit', int(s.get('kitMaterial'))),
                    ('chi_dinh_su_kien', cd),
                    ('chi_dinh_hieu_ung', cp),
                ]))
            if ds:
                danh.setdefault(arm.get('name'), collections.OrderedDict())[
                    act.get('name')] = ds

    giap = collections.OrderedDict()
    for it in goc.find('armors'):
        giap[it.get('name')] = int(it.get('armorMaterial'))

    dung_lai = collections.OrderedDict()
    for it in goc.find('reuseArmatures'):
        dung_lai[it.get('key')] = it.get('value')

    su_kien = collections.OrderedDict()
    for it in sorted(goc.find('events'), key=lambda x: x.get('key')):
        su_kien[it.get('key')] = it.get('value')

    hieu_ung = collections.OrderedDict()
    for it in goc.find('plugins'):
        hieu_ung[it.get('key')] = it.get('value')

    return collections.OrderedDict([
        ('danh', danh), ('giap', giap), ('dung_lai', dung_lai),
        ('su_kien', su_kien), ('hieu_ung', hieu_ung),
    ]), n_chi_dinh, n_thich_la


def bank_theo_armature():
    """armature -> [duong dan bank]. Chi de doi chieu (xem dau file).

    Dang that cua file: `<animations><Ten><bank>banks/X.bank</bank>...</Ten>`.
    Trong do co hai diem phai giu nguyen chu khong "don dep":
      * mot armature co the liet ke NHIEU bank, va co bank lap LAI (do duoc:
        `LvBu` liet `banks/LvBu.bank` hai lan; `DefenderN` liet `Defender` roi
        `DefenderN`) — nen day la danh sach chu khong phai mot gia tri;
      * `<customBank>` la the rieng, khong phai `<bank>` (do duoc:
        `WitchDoctor` chi co `customBank`, con `Artillery` co ca hai).
        `WitchDoctor_Effect` nam RIENG va tro toi dung bank do.
    """
    goc = ET.fromstring(_doc('bank_config.xml', 'utf-8'))
    ra = collections.OrderedDict()
    for arm in goc:
        ds = [b.text for b in arm if b.tag in ('bank', 'customBank') and b.text]
        if ds:
            ra[arm.tag] = ds
    return ra


def _co_armature():
    """Ten armature ta CO (assets_ref/<Ten>/<Ten>.json)."""
    goc = HERE.parent.parent / 'bravecross-game' / 'assets_ref'
    if not goc.is_dir():
        return None
    return {p.name for p in goc.iterdir() if p.is_dir()}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--json', action='store_true', help='chi in, khong ghi file')
    a = ap.parse_args()

    thd, n_lap = tieng_hoat_dong()
    td, n_chi_dinh, n_thich_la = trung_don()
    bank = bank_theo_armature()

    n_sound = sum(len(v) for act in thd.values() for v in act.values())
    n_arm_sound = len(thd)
    n_danh = sum(len(v) for act in td['danh'].values() for v in act.values())
    co = _co_armature()

    def _thieu(ten_ds):
        if co is None:
            return None
        return sorted(t for t in ten_ds if t not in co)

    thieu_sound = _thieu(thd.keys())
    thieu_giap = _thieu(td['giap'].keys())
    thieu_danh = _thieu(td['danh'].keys())

    ra = collections.OrderedDict([
        ('tieng_hoat_dong', thd),
        ('trung_don', td),
        ('bank_theo_armature', bank),
        ('thong_ke', collections.OrderedDict([
            ('so_armature_sound_config', n_arm_sound),
            ('so_tieng_hoat_dong', n_sound),
            ('so_tieng_lap', n_lap),
            ('so_armature_hit_config', len(td['danh'])),
            ('so_cu_danh', n_danh),
            ('so_co_chi_dinh', n_chi_dinh),
            ('so_chu_thich_chua_hai_gach', n_thich_la),
            ('so_giap', len(td['giap'])),
            ('so_dung_lai', len(td['dung_lai'])),
            ('so_su_kien_trung_don', len(td['su_kien'])),
            ('so_hieu_ung', len(td['hieu_ung'])),
            ('so_bank_config', len(bank)),
        ])),
    ])
    if thieu_sound is not None:
        ra['thong_ke']['armature_sound_config_ta_khong_co'] = thieu_sound
        ra['thong_ke']['armature_hit_config_ta_khong_co'] = thieu_danh
        ra['thong_ke']['armature_giap_ta_khong_co'] = thieu_giap

    print('tieng hoat dong : %d armature, %d tieng, %d tieng lap'
          % (n_arm_sound, n_sound, n_lap))
    print('trung don       : %d armature danh, %d cu danh (%d co chi dinh), '
          '%d giap, %d dung lai, %d su kien, %d hieu ung'
          % (len(td['danh']), n_danh, n_chi_dinh, len(td['giap']),
             len(td['dung_lai']), len(td['su_kien']), len(td['hieu_ung'])))
    print('bank_config     : %d armature, %d duong dan bank (%d armature liet tu 2 bank tro len)'
          % (len(bank), sum(len(v) for v in bank.values()),
             sum(1 for v in bank.values() if len(v) > 1)))
    print('chu thich XML chua `--` (phai bo tay): %d' % n_thich_la)
    if co is not None:
        print('doi chieu voi assets_ref (%d armature): thieu %d / thieu %d / thieu %d'
              % (len(co), len(thieu_sound), len(thieu_danh), len(thieu_giap)))
        if thieu_sound:
            print('  sound_config khong co rig: %s' % ', '.join(thieu_sound[:8]))
        if thieu_danh:
            print('  hit_config/danh khong co rig: %s' % ', '.join(thieu_danh[:8]))
        if thieu_giap:
            print('  hit_config/giap khong co rig: %s' % ', '.join(thieu_giap[:8]))

    if a.json:
        return 0
    DICH.parent.mkdir(parents=True, exist_ok=True)
    with io.open(DICH, 'w', encoding='utf-8') as f:
        json.dump(ra, f, ensure_ascii=False, indent=1)
    print('-> %s' % DICH)
    return 0


if __name__ == '__main__':
    sys.exit(main())
