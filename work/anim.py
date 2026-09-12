# -*- coding: utf-8 -*-
"""Xuat hoat anh xuong tu file .xml cua game ra JSON.

Day la lop cuoi cua dinh dang sngXml ban .xml — phan keyframe. sngxml.py doc
duoc bo xuong, ten dong tac va ten sprite; file nay doc them DU LIEU BIEN DOI
tung khung: vi tri, goc xoay, ti le cua tung xuong.

BO CUC (tiep noi sngxml.py)

Ban ghi dong tac, 0x28 byte, nam o mang con cua mang 2:

    +0x00  uint32  str_off, str_len     ten dong tac: "Walk", "Fight"...
    +0x08  uint32  so keyframe
    +0x10  uint32  do dai dong tac tinh bang khung
    +0x14  uint32  co lap: 1 = lap vo han, 0 = chay mot lan
    +0x20  uint32  bone_off             offset vao mang o header 0x58
    +0x24  uint32  bone_count           so xuong tham gia dong tac nay

Hai truong +0x10 va +0x14 doc duoc bang cach quet 7995 ban ghi cua 411 file:

  +0x10  bang so keyframe o 7715 ban ghi, lon hon o 136. Vd Archer/Hang co 2
         keyframe nhung do dai 10 khung — giu tu the 5 khung moi keyframe.
  +0x14  chi nhan 0 hoac 1, va chia dung theo nghia dong tac:
         lap 1   Walk, Standby, Run, WalkBack, Walk2, Defend, Hang, Fire
         lap 0   Fight, Death, Hit, Wake, Fight2, Jump, Down, Fight3
         Khong co dong tac mot-lan nao bi danh dau lap va nguoc lai.

Ban ghi xuong, 24 byte, o goc header[0x58]:

    +0x00  uint32  str_off, str_len     ten xuong: "HandLeft", "ThighLeft"...
    +0x08  float   he so (luon 1.0 tren mau da xem)
    +0x0c  uint32  0
    +0x10  uint32  key_off              offset vao mang o header 0x5c
    +0x14  uint32  key_count            so khung cua rieng xuong nay

Khung, 80 byte, o goc header[0x5c]:

    +0x00  float x, float y             vi tri
    +0x08  float x, float y             cung vi tri, da lam tron
    +0x10  float rot, float rot         goc xoay (do), lap lai
    +0x18  float sx, float sy           ti le
    +0x2C  int32  d    CHI SO ANH dang hien: vi tri trong danh sach sprite cua
                       xuong (header 0x4c); -1 = AN
    +0x40  uint32 dur  so khung keyframe nay GIU truoc khi sang keyframe sau
    +0x20, +0x24, +0x28, +0x30..+0x3C, +0x44..+0x4C   chua giai (+0x28 hang
                       so theo xuong; +0x44..+0x4C co ve la bien doi mau)

Truoc day ghi "+0x20..+0x50 luon 0 tren mau da xem" — SAI: mau cu toan nhan
vat thuong. Do tren 418 file / 641.538 keyframe cua ca hai ban:

  d    nam trong [-1, so sprite cua xuong - 1] o 641.525 keyframe; so sprite
       lay tu bang RIENG (header 0x4c), khong phai tu khung. -1 gap 23.840 lan.
       13 cho lech deu o BingYing.xml va XSJiYouHeTiJi.xml (gia tri rac: 100,
       so thuc) — hai file do bo cuc khung khac, chua giai.
  dur  tren moi xuong >= 2 keyframe, tong dur = do dai dong tac o 95.416 /
       95.431 xuong; 15 cho lech deu o BingYing.xml.

Nghia doc duoc tren Player000M03W: eff010 cua Fight la (-1,8) (0,3) (0,1)
(-1,2) — an 8 khung, hien anh 0 bon khung, an 2; eff010 cua YinHuo_Standby
chay anh 2 -> 3 -> 4 — hoat hinh doi anh tung khung.

Muc con cua BO PHAN, 16 byte, o goc header[0x48]:

    +0x00  uint32  str_off, str_len     ten xuong
    +0x08  uint32  ref_off              offset vao mang o header 0x4c
    +0x0c  uint32  ref_count            so sprite ma xuong nay ve

Tham chieu SPRITE, 20 byte, o goc header[0x4c]:

    +0x00  uint32  str_off, str_len     ten sprite
    +0x08  float   x, y                 diem neo rieng cua xuong
    +0x10  uint32  0

Day la ANH XA XUONG -> SPRITE, thu quyet dinh moi xuong ve cai gi. Truoc
day header[0x4c] khong ai dung va muc con cua bo phan chi doc moi ten, nen
JSON xuat ra khong he co thong tin nay — bo nap rig ben Godot doi
children = [{name, sprites}] ma chi nhan duoc mot danh sach ten tran.

Doi chieu tren Cavalry, ten xuong trung duoi ten sprite nen khong the nham:

    HandLeft   -> Cavalry_res-HandLeft
    ArmLeft    -> Cavalry_res-ArmLeft
    ThighLeft  -> Cavalry_res-ThighLeft
    ATail      -> CavalryAlpaca_res-ATail

Ban ghi SPRITE, 40 byte, o goc header[0x60] — doc duoc nhung chua dung:

    +0x00  uint32  str_off, str_len     ten sprite
    +0x08  float   w, h                 kich thuoc khung
    +0x10  float   px, py               tam
    +0x18  0, 0
    +0x20  float   atlasX, atlasY       vi tri trong atlas

Vi du Cavalry.xml, dong tac Walk:

    ArmLeft   goc:  0.00 ->  8.48 -> -10.20 ->  -2.51    (tay vung)
    LegLeft   goc: 27.00 -> 35.47 ->  16.80 ->  24.33    (chan buoc)

BAN GHI BO PHAN, 16 byte, o mang con cua mang 1:

    +0x00  uint32  str_off, str_len     ten bo phan: "Head", "ArmLeft"...
    +0x08  uint32  ref_off              offset vao mang o header 0x4c
    +0x0c  uint32  ref_count            so ANH ma bo phan nay dung

Mang o 0x4c, ban ghi 20 byte, tam thoi chi doc 8 byte dau (ten anh). Day la
LIEN KET XUONG -> ANH do chinh file luu, khong phai suy tu ten:

    Archer/Head   -> Head1, Head3, Head2, Head4, Head5   (5 net mat)
    CaoCao/LeftArm-> CaoCao_res-RightArm                 (dung lai anh tay phai)
    CaoCao/Head   -> CaoCao_mc_Head                      (mot rig long nhau)

Quan trong voi nhung nhan vat dat ten anh khong theo bo phan: CaoCao co
"face1", "touguan", "toufa0013_instant" — do ten thi chiu, doc bang o day thi
ra dung.

CHUA RO: 12 byte cuoi cua ban ghi 20 byte nay; 48 byte cuoi cua moi khung
(luon 0 tren mau da xem); va vi sao vi tri cung goc xoay deu duoc luu hai lan.

    python anim.py <file.xml>                # tom tat
    python anim.py <file.xml> --json         # xuat JSON day du
    python anim.py <file.xml> --anim Walk    # do chi tiet mot dong tac
    python anim.py --scan <thu_muc>          # kiem tra tren ca cay
"""
import os, sys, json, glob, struct, argparse, collections

MAGIC = b'sngXml\x00'
ANIM_REC = 0x28
BONE_REC = 24
KEY_REC = 80
REF_REC = 20


class AnimError(Exception):
    pass


class Anim(object):

    def __init__(self, data, name=''):
        self.d, self.name, self.size = data, name, len(data)
        if self.size < 0x70 or data[:7] != MAGIC:
            raise AnimError('khong phai file sngXml')
        u = self.u = lambda o: struct.unpack_from('<I', data, o)[0]
        self.pool = u(0x64)
        self.grp_base, self.grp_sub = u(0x50), u(0x54)   # mang 2 + mang con
        self.bone_base = u(0x58)
        self.key_base = u(0x5c)
        self.part_base, self.part_sub = u(0x44), u(0x48)
        self.ref_base = u(0x4c)
        self.spr_base = u(0x60)
        for o in (0x44, 0x48, 0x4c, 0x50, 0x54, 0x58, 0x5c, 0x60, 0x64):
            if not 0 < u(o) <= self.size:
                raise AnimError('bo cuc khong phai ban .xml (0x%02X ngoai file)' % o)

    def s(self, off, ln):
        if ln == 0:
            return ''
        a = self.pool + off
        if a + ln > self.size:
            raise AnimError('chuoi vuot cuoi file')
        return self.d[a:a + ln].decode('utf-8', 'replace')

    def _name_at(self, p):
        return self.s(self.u(p), self.u(p + 4))

    # ------------------------------------------------------------- doc
    def keys(self, key_off, count):
        """Cac khung cua mot xuong."""
        out = []
        for i in range(count):
            q = self.key_base + key_off + i * KEY_REC
            if q + KEY_REC > self.size:
                raise AnimError('khung vuot cuoi file')
            v = struct.unpack_from('<8f', self.d, q)
            out.append(collections.OrderedDict([
                ('x', round(v[0], 4)), ('y', round(v[1], 4)),
                ('rot', round(v[4], 4)),
                ('sx', round(v[6], 4)), ('sy', round(v[7], 4)),
                ('d', struct.unpack_from('<i', self.d, q + 0x2C)[0]),
                ('dur', struct.unpack_from('<I', self.d, q + 0x40)[0]),
            ]))
        return out

    def bones(self, bone_off, count):
        out = []
        for i in range(count):
            p = self.bone_base + bone_off + i * BONE_REC
            if p + BONE_REC > self.size:
                raise AnimError('ban ghi xuong vuot cuoi file')
            out.append(collections.OrderedDict([
                ('name', self._name_at(p)),
                ('keys', self.keys(self.u(p + 0x10), self.u(p + 0x14))),
            ]))
        return out

    def groups(self):
        """Cac bien the (Cavalry, Cavalry_Dong...) va dong tac cua chung."""
        out = []
        for i in range(self.u(0x28)):
            r = self.grp_base + i * 0x10
            sub_off, sub_n = self.u(r + 8), self.u(r + 0xc)
            anims = []
            for k in range(sub_n):
                a = self.grp_sub + sub_off + k * ANIM_REC
                nm = self._name_at(a)
                if not nm or nm == 'None':
                    continue
                nFrames = self.u(a + 8)
                nDur = self.u(a + 0x10)
                anims.append(collections.OrderedDict([
                    ('name', nm),
                    ('frames', nFrames),
                    ('duration', nDur if nDur >= nFrames else nFrames),
                    ('loop', self.u(a + 0x14) == 1),
                    ('bones', self.bones(self.u(a + 0x20), self.u(a + 0x24))),
                ]))
            if anims:
                out.append(collections.OrderedDict([
                    ('variant', self._name_at(r)), ('animations', anims)]))
        return out

    def sprite_refs(self, off, count):
        """Danh sach ten sprite ma mot xuong ve ra.

        Moi ban ghi 20 byte o goc header[0x4c]:

            +0x00  uint32 str_off, str_len   ten sprite
            +0x08  float  x, y               diem neo cua rieng xuong nay
            +0x10  uint32 0

        Doi chieu tren Cavalry: HandLeft -> Cavalry_res-HandLeft,
        ArmLeft -> Cavalry_res-ArmLeft, ATail -> CavalryAlpaca_res-ATail —
        ten xuong trung duoi ten sprite, nen anh xa nay chac chan dung.
        """
        out = []
        for j in range(count):
            p = self.ref_base + off + j * REF_REC
            if p + REF_REC > self.size:
                raise AnimError('tham chieu sprite vuot cuoi file')
            out.append(self._name_at(p))
        return out

    def parts(self):
        out = []
        for i in range(self.u(0x20)):
            r = self.part_base + i * 0x10
            sub_off, sub_n = self.u(r + 8), self.u(r + 0xc)
            kids = []
            for k in range(sub_n):
                q = self.part_sub + sub_off + k * 0x10
                ref_off, ref_n = self.u(q + 8), self.u(q + 0xc)
                kids.append(collections.OrderedDict([
                    ('name', self._name_at(q)),
                    ('sprites', self.sprite_refs(ref_off, ref_n)),
                ]))
            out.append(collections.OrderedDict([
                ('name', self._name_at(r)), ('children', kids)]))
        return out

    def sprites(self):
        return [self._name_at(self.spr_base + i * 0x28) for i in range(self.u(0x40))]

    def to_dict(self):
        return collections.OrderedDict([
            ('file', self.name), ('size', self.size),
            ('parts', self.parts()),
            ('sprites', self.sprites()),
            ('groups', self.groups()),
        ])


def load(path):
    with open(path, 'rb') as fp:
        return Anim(fp.read(), os.path.basename(path))


def find_files(root):
    out = []
    for p in glob.glob(os.path.join(root, '**', '*'), recursive=True):
        if os.path.isfile(p):
            with open(p, 'rb') as fp:
                if fp.read(7) == MAGIC:
                    out.append(p)
    return sorted(out)


# --------------------------------------------------------------------- lenh
def cmd_show(path, only):
    a = load(path)
    gs = a.groups()
    print('%s  —  %d byte' % (path, a.size))
    print('  bo phan : %d    sprite : %d    bien the co dong tac : %d'
          % (len(a.parts()), len(a.sprites()), len(gs)))
    for g in gs:
        shown = [x for x in g['animations'] if not only or x['name'] == only]
        if not shown:
            continue
        print()
        print('  === %s — %d dong tac ===' % (g['variant'], len(g['animations'])))
        for an in shown:
            nk = sum(len(b['keys']) for b in an['bones'])
            print('    %-18s %2d khung, %2d xuong, %3d keyframe'
                  % (an['name'], an['frames'], len(an['bones']), nk))
            if only:
                for b in an['bones'][:8]:
                    ks = b['keys']
                    print('       %-18s %s' % (b['name'],
                        '  '.join('(%.1f,%.1f)@%.1f' % (k['x'], k['y'], k['rot']) for k in ks[:5])))


def cmd_scan(root):
    files = find_files(root)
    ok = other = 0
    nanim = nbone = nkey = 0
    errs = []
    for p in files:
        try:
            a = load(p)
            for g in a.groups():
                for an in g['animations']:
                    nanim += 1
                    for b in an['bones']:
                        nbone += 1
                        nkey += len(b['keys'])
            ok += 1
        except AnimError as e:
            if 'ban .xml' in str(e):
                other += 1
            else:
                errs.append((p, str(e)))
    print('quet %s' % root)
    print('  file sngXml   : %d' % len(files))
    print('  ban .xml doc  : %d' % ok)
    print('  ban .plist    : %d  (dung sngxml.py)' % other)
    print('  loi           : %d' % len(errs))
    for p, e in errs[:5]:
        print('     %s — %s' % (os.path.basename(p), e))
    print()
    print('  dong tac      : %d' % nanim)
    print('  xuong         : %d' % nbone)
    print('  keyframe      : %d' % nkey)
    return 0 if not errs else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('target')
    ap.add_argument('--json', action='store_true', help='xuat JSON day du')
    ap.add_argument('--anim', metavar='TEN', help='do chi tiet mot dong tac')
    ap.add_argument('--scan', action='store_true', help='kiem tra ca cay')
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')
    if a.scan:
        sys.exit(cmd_scan(a.target))
    try:
        if a.json:
            print(json.dumps(load(a.target).to_dict(), ensure_ascii=False, indent=1))
        else:
            cmd_show(a.target, a.anim)
    except AnimError as e:
        sys.exit('khong doc duoc: %s' % e)


if __name__ == '__main__':
    main()
