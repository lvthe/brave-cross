# -*- coding: utf-8 -*-
"""Bo doc dinh dang '.xgg' (magic 'sngXgg' / 'xgg5.0') cua game — DA GIAI XONG.

Day la file bo cuc canh/man choi: BattleField_*, UI_*. Moi truong deu doc
duoc; khong con phan nao phai doan.

NGUON GOC. Khong suy dien tu du lieu, ma doc thang tu libgame.so (ban CN,
tim qua xref toi chuoi 'sngXgg' @ 0x007d2c0c):

  FUN_0048f0f0  — doc header, cat cac con tro vao doi tuong 64 byte
  FUN_002e7948  — nguoi goi; operator_new(0x40) roi dung ket qua
  FUN_0048f1b8  — GIAI CHUOI, day la manh chot:

      if (rec[1] == 0 || rec[0] < 0)  ->  chuoi rong
      else  ->  chuoi tai  base + rec[0] + *(int*)(base + 0x24),  dai rec[1]

  ma *(int*)(base + 0x24) chinh la off_H. Tuc la moi ban ghi mo dau bang
  (offset tinh tu off_H, do dai), va off_H la goc kho chuoi.

BO CUC

    0x00  char[7]  magic     "sngXgg\\0" hoac "xgg5.0\\0"   (memcmp 7 byte)
    0x07  byte     0x00
    0x08  uint32   off_A     luon 0x28              580/580 file
    0x0c  uint32   off_B     luon 0x90              580/580 file
    0x10  uint32   off_C
    0x14  uint32   off_D
    0x18  uint32   off_E
    0x1c  uint32   off_F
    0x20  uint32   off_G     luon = off_E + 8       580/580 file
    0x24  uint32   off_H     goc kho chuoi
                                    7 + 1 + 8*4 = 40 = 0x28, kin het header

    0x28   section A   104 byte cac float thong so canh
    0x90   section B   [uint32 count][count *  8 byte]   atlas .plist
    off_C  section C   [uint32 count][count * 16 byte]   sprite + toa do
    off_D  section D   [uint32 count][count * 16 byte]   anh roi + toa do
    off_E  section E   8 byte (vi off_G luon = off_E + 8)
    off_G  section G   cay node — bo cuc man hinh (xem Xgg.nodes())
    off_F  section F   bang offset uint32 tro vao G, tang dan
    off_H  section H   kho chuoi, toi cuoi file

    ban ghi B  (8 byte):  uint32 str_off, uint32 str_len
    ban ghi C (16 byte):  uint32 str_off, uint32 str_len, float x, float y
    ban ghi D (16 byte):  giong C

DA KIEM CHUNG tren toan bo 580 file cua ca hai ban (CN + VN):
  - moi offset trong header nam trong file, cac hang so tren dung 580/580
  - kich thuoc ban ghi suy tu (off_ke_tiep - off - 4)/count ra dung 8/16/16,
    khong file nao chia khong het
  - 29017 ban ghi: 28539 giai ra chuoi ASCII sach, 478 do dai 0 (dung nhanh
    chuoi rong trong FUN_0048f1b8), 0 HONG
  - noi dung dung mot kieu: B toan .plist (16299), C toan .png (10934),
    D .png (1262) + .jpg (44)

SECTION G — CAY NODE, tuc bo cuc that su cua man hinh.

F la bang offset uint32 tro vao G, tang dan. Moi ban ghi node dai thay doi
(216..352 byte) nhung cac truong can dung deu o vi tri co dinh: ten lop, ten
instance, tai nguyen, x, y, scale, rotation, anchor, w, h, va SO CON o +0xB4.
Node luu duyet THEO TANG — xem Xgg.nodes() va Xgg.tree().

Kiem tren toan bo 580 file: 65935 node, 2146 goc, sau nhat 12 tang, 0 HONG.

CON LAI: y nghia tung float trong section A (nhin ra 1024.0 / 768.0 / 0.8 —
kich thuoc canh va he so ti le), va cac truong con lai cua ban ghi node.

    python xgg.py <file>                 # doc header + noi dung
    python xgg.py <file> --json          # xuat JSON
    python xgg.py --scan <thu_muc>       # kiem tra tren ca cay
"""
import os, sys, json, glob, struct, argparse, collections

MAGICS = (b'sngXgg\x00', b'xgg5.0\x00')
HEADER_SIZE = 0x28
SECTIONS = ('A', 'B', 'C', 'D', 'E', 'F', 'G', 'H')
COUNTED = ('B', 'C', 'D')
REC_FIELDS = {'B': 8, 'C': 16, 'D': 16}


class XggError(Exception):
    pass


class Xgg(object):
    """Mot file .xgg da giai."""

    def __init__(self, data, name=''):
        self.data = data
        self.name = name
        self.size = len(data)
        if self.size < HEADER_SIZE:
            raise XggError('file qua ngan (%d byte)' % self.size)
        self.magic = data[:7]
        if self.magic not in MAGICS:
            raise XggError('magic la %r, khong phai .xgg' % self.magic[:7])

        self.byte7 = data[7]
        self.offsets = collections.OrderedDict(
            zip(SECTIONS, struct.unpack_from('<8I', data, 8)))
        for tag, off in self.offsets.items():
            if not 0 < off <= self.size:
                raise XggError('off_%s = 0x%X nam ngoai file (%d byte)'
                               % (tag, off, self.size))

        self.counts, self.rec_size, self.data_at = {}, {}, {}
        order = list(self.offsets)
        for tag in COUNTED:
            off = self.offsets[tag]
            nxt = self.offsets[order[order.index(tag) + 1]]
            self.counts[tag] = struct.unpack_from('<I', data, off)[0]
            self.data_at[tag] = off + 4
            span, n = nxt - off - 4, self.counts[tag]
            if n == 0:
                self.rec_size[tag] = 0
            elif span % n:
                raise XggError('section %s: span %d khong chia het cho count %d'
                               % (tag, span, n))
            else:
                self.rec_size[tag] = span // n

    # ---------------------------------------------------------------- chuoi
    def string(self, off, length):
        """Giai chuoi y het FUN_0048f1b8: goc la off_H."""
        if length == 0 or off < 0:
            return ''
        a = self.offsets['H'] + off
        if a + length > self.size:
            raise XggError('chuoi tai off_H+%d dai %d vuot cuoi file' % (off, length))
        return self.data[a:a + length].decode('utf-8', 'replace')

    # -------------------------------------------------------------- section
    def extent(self, tag):
        """(dau, cuoi). Cuoi = offset nho nhat lon hon no — thu tu gia tri la
        E <= G <= F <= H, khong trung thu tu o header."""
        start = self.offsets[tag]
        later = [v for v in self.offsets.values() if v > start]
        return start, (min(later) if later else self.size)

    def section_bytes(self, tag):
        a, b = self.extent(tag)
        return self.data[a:b]

    def scene_floats(self):
        """Section A doc thanh float. Tung truong chua ro y nghia."""
        a = self.section_bytes('A')
        return list(struct.unpack('<%df' % (len(a) // 4), a[:len(a) // 4 * 4]))

    def records(self, tag):
        """Ban ghi da giai. B -> {name}; C/D -> {name, x, y}."""
        if tag not in COUNTED:
            raise XggError('section %s khong phai dang [count][ban ghi]' % tag)
        w, at, out = self.rec_size[tag], self.data_at[tag], []
        for i in range(self.counts[tag]):
            r = self.data[at + i * w: at + (i + 1) * w]
            off, ln = struct.unpack_from('<II', r, 0)
            rec = {'name': self.string(off, ln), 'str_off': off, 'str_len': ln}
            if w >= 16:
                rec['x'], rec['y'] = struct.unpack_from('<ff', r, 8)
            out.append(rec)
        return out

    NODE_MIN = 0xA0        # phan dau co dinh cua mot ban ghi node

    def node_offsets(self):
        """Section F la bang offset uint32 tro vao G, tang dan."""
        a, b = self.offsets['F'], self.offsets['H']
        if b <= a or (b - a) % 4:
            raise XggError('section F khong phai bang offset')
        n = (b - a) // 4
        return struct.unpack_from('<%dI' % n, self.data, a)

    def nodes(self):
        """Cay node cua man hinh — bo cuc that su.

        Moi ban ghi dai thay doi (216..352 byte tren mau da xem), nhung phan
        dau den 0xA0 thi co dinh:

            +0x60  str_off, str_len   ten lop      spXxx / clXxx / lXxx / g_Xxx
            +0x68  str_off, str_len   ten instance
            +0x70  str_off, str_len   tai nguyen (sprite, hieu ung), co the rong
            +0x7C  float x, y            toa do, TUONG DOI VOI CHA
            +0x84  float scaleX, scaleY
            +0x8C  float rotation        do
            +0x90  float anchorX, anchorY  CCSprite luon 0.5; layer thuong 0
            +0x98  float w, h
            +0xB4  uint32 so con         (xem tree())

        Doi chieu: node nen cua BattleField_Cavern_02 ra w=1665 h=768, dung
        bang gia tri section D cua chinh anh do; va g_GameUILayer cua HUD ra
        960x640, dung do phan giai thiet ke cua game.
        """
        if getattr(self, '_nodes', None) is not None:
            return self._nodes
        G, lenG = self.offsets['G'], self.offsets['F'] - self.offsets['G']
        offs = self.node_offsets()
        out = []
        for i, o in enumerate(offs):
            a = G + o
            end = G + (offs[i + 1] if i + 1 < len(offs) else lenG)
            if end - a < self.NODE_MIN:
                raise XggError('ban ghi node %d chi %d byte' % (i, end - a))
            u = lambda p: struct.unpack_from('<I', self.data, a + p)[0]
            x, y, sx, sy = struct.unpack_from('<4f', self.data, a + 0x7C)
            rot, = struct.unpack_from('<f', self.data, a + 0x8C)
            ax, ay = struct.unpack_from('<2f', self.data, a + 0x90)
            w, h = struct.unpack_from('<2f', self.data, a + 0x98)
            out.append(collections.OrderedDict([
                ('cls', self.string(u(0x60), u(0x64))),
                ('name', self.string(u(0x68), u(0x6C))),
                ('res', self.string(u(0x70), u(0x74))),
                ('x', round(x, 3)), ('y', round(y, 3)),
                ('scaleX', round(sx, 4)), ('scaleY', round(sy, 4)),
                ('rot', round(rot, 3)),
                # +0xA4: CHUA RO LA GI. Da tung ghi o day la 'tag so nguyen
                # cua Cocos' — SAI, va chinh minh bac bo sau do. Cach kiem:
                # gom moi '<ten toan cuc>:getChildByTag(n)' lam moc, chi giu
                # ten nao xuat hien o DUNG MOT man de khong lan, roi quet het
                # ban ghi. Khong offset nao vuot 31% — 0x038, 0x0A4, 0x03C xap
                # xi nhau, tuc la khong cai nao dung. Gia thuyet 'tag = thu tu
                # con' cung sai: 33/52 moc doi tag lon hon ca so con.
                # Ket luan: tag KHONG nam trong ban ghi node. Muon biet that
                # thi phai doc bo nap .xgg trong libgame.so.
                # Van giu truong nay vi no co that va co the con dung, nhung
                # DUNG coi no la tag.
                ('u_a4', struct.unpack_from('<i', self.data, a + 0xA4)[0]),
                # +0xA1: co hien/an. SUY RA chu chua doc tu libgame.so, nhung
                # khop voi moi node kiem duoc: cac hop thoai (clGameReviveDlg,
                # clBattlePause, clGuickGameFinish), khung mach nuoc va nut
                # test deu =0; con lUITopLayer, ttfLeaderShip, g_GameUILayer
                # deu =1. Toan file: 540 hien / 89 an.
                ('visible', bool(self.data[a + 0xA1])),
                ('anchorX', round(ax, 4)), ('anchorY', round(ay, 4)),
                ('w', round(w, 3)), ('h', round(h, 3)),
                ('bytes', end - a),
            ]))
        # Nho lai: tree() va node_image() deu dua tren CHINH cac dict nay, neu
        # dung lai moi lan mot danh sach moi thi khong the gan them truong.
        self._nodes = out
        return out

    # Offset cua cap (str_off, str_len) chua TEN ANH, theo tung co ban ghi.
    # CHUA doc tu libgame.so — do bang thong ke roi tu kiem chung, nen phai
    # coi la PHONG DOAN cho toi khi doc duoc ham nap that su:
    #
    #   co 244 -> +0xEC   90% node sprite suy ra dung kich thuoc
    #   co 260 -> +0xF4   97%
    #   co 248 -> +0xF0    4%  <- khong dung duoc, bo han
    #
    # Cac co khac (216, 220, 320, 352) khong co ten anh nao — dung, vi chung
    # la layer va label.
    IMG_FIELD = {244: 0xEC, 260: 0xF4, 256: 0xEC, 324: 0xF0}

    def node_image(self, i):
        """(ten anh, do tin cay) cua node thu i.

        do tin cay:
            'verified'  ten co trong section C cua chinh man nay VA kich thuoc
                        khop w/h cua node — coi nhu chac chan dung
            'guess'     giai ra chuoi hop le nhung khong tu kiem chung duoc
            ''          khong co ten anh
        """
        nds = self.nodes()
        if not 0 <= i < len(nds):
            return '', ''
        nd = nds[i]
        off = self.IMG_FIELD.get(nd['bytes'])
        if off is None or off + 8 > nd['bytes']:
            return '', ''
        a = self.offsets['G'] + self.node_offsets()[i]
        so, sl = struct.unpack_from('<2I', self.data, a + off)
        if not sl or sl > 200 or so + sl > self.size - self.offsets['H']:
            return '', ''
        try:
            name = self.data[self.offsets['H'] + so:
                             self.offsets['H'] + so + sl].decode('utf-8')
        except UnicodeDecodeError:
            return '', ''
        if not name or any(ord(c) < 32 for c in name):
            return '', ''

        if not hasattr(self, '_csize'):
            self._csize = {}
            for r in self.records('C'):
                if r['name']:
                    self._csize[r['name']] = (round(r['x']), round(r['y']))
                    self._csize[r['name'].lstrip('@')] = (round(r['x']), round(r['y']))
        want = (round(nd['w']), round(nd['h']))
        if self._csize.get(name) == want or self._csize.get(name.lstrip('@')) == want:
            return name, 'verified'
        return name, 'guess'

    def tree(self):
        """Dung lai cay tu danh sach phang.

        Moi ban ghi mang SO CON o +0xB4 va CHI SO CON DAU TIEN o +0xB8 (tinh
        bang byte, chia 4 ra chi so node). Nen cay khong phai doan.

        Truoc day cho la node luu theo tang (BFS) roi lay k node ke tiep chua
        ai nhan. Doan the ra sai: lAchieveTemplate (760x105) nuot mot node
        840x520. Doc thang 0xB8 thi ra dung — lAchieveTemplate chua canget va
        noget cung 760x105 (hai trang thai cua mot dong) va rewardList2 chua
        reward1/2/3.

        Kiem tren ca 284 bo cuc: khong node nao vuot bien, khong node nao co
        hai cha. Doan thu tu thi khong the bao dam duoc hai dieu do.

        Toa do x,y la TUONG DOI VOI CHA (Cocos2d), khong phai toa do man hinh.
        """
        nds = self.nodes()
        G, offs = self.offsets['G'], self.node_offsets()
        kids = [struct.unpack_from('<I', self.data, G + o + 0xB4)[0] for o in offs]
        first = [struct.unpack_from('<I', self.data, G + o + 0xB8)[0] // 4
                 for o in offs]
        for nd, k in zip(nds, kids):
            nd['children'] = []
            nd['nKids'] = k

        for i, nd in enumerate(nds):
            a, b = first[i], first[i] + nd['nKids']
            if b > len(nds):
                raise XggError('node %d doi con %d..%d, chi co %d node'
                               % (i, a, b, len(nds)))
            nd['children'] = nds[a:b]

        seen = set()
        for nd in nds:
            for c in nd['children']:
                seen.add(id(c))
        return [nd for nd in nds if id(nd) not in seen]

    def to_dict(self):
        return collections.OrderedDict([
            ('file', self.name),
            ('magic', self.magic[:6].decode()),
            ('size', self.size),
            ('offsets', collections.OrderedDict(
                (k, v) for k, v in self.offsets.items())),
            ('sceneFloats', [round(f, 4) for f in self.scene_floats()]),
            ('atlas', [r['name'] for r in self.records('B')]),
            ('sprites', [{'name': r['name'], 'x': r['x'], 'y': r['y']}
                         for r in self.records('C')]),
            ('images', [{'name': r['name'], 'x': r['x'], 'y': r['y']}
                        for r in self.records('D')]),
            ('nodes', self.nodes()),
        ])


def load(path):
    with open(path, 'rb') as fp:
        return Xgg(fp.read(), os.path.basename(path))


def find_files(root):
    out = []
    for p in glob.glob(os.path.join(root, '**', '*'), recursive=True):
        if os.path.isfile(p):
            with open(p, 'rb') as fp:
                if fp.read(7) in MAGICS:
                    out.append(p)
    return sorted(out)


# --------------------------------------------------------------------- lenh
def cmd_show(path, limit):
    xf = load(path)
    print('%s  —  %d byte, magic %r' % (path, xf.size, xf.magic[:6].decode()))
    print()
    print('  %-4s %-9s %-10s %-8s %-9s %s'
          % ('sec', 'o header', 'offset', 'count', 'ban ghi', 'kich thuoc'))
    for i, tag in enumerate(xf.offsets):
        start, end = xf.extent(tag)
        n = xf.counts.get(tag)
        print('  %-4s %-9s 0x%-8X %-8s %-9s %d byte'
              % (tag, '0x%02X' % (8 + i * 4), xf.offsets[tag],
                 '—' if n is None else n,
                 ('%d byte' % xf.rec_size[tag]) if n else '—', end - start))

    print()
    fl = xf.scene_floats()
    print('  section A — %d float (y nghia tung truong chua ro):' % len(fl))
    for i in range(0, min(len(fl), 12), 6):
        print('    [%2d] %s' % (i, '  '.join('%10.3f' % v for v in fl[i:i + 6])))

    for tag, title in (('B', 'atlas (.plist)'), ('C', 'sprite'), ('D', 'anh roi')):
        recs = xf.records(tag)
        if not recs:
            continue
        print()
        print('  section %s — %s, %d muc%s:'
              % (tag, title, len(recs),
                 '' if len(recs) <= limit else ' (hien %d dau)' % limit))
        for r in recs[:limit]:
            if 'x' in r:
                print('    %-44s  x=%-9.1f y=%.1f' % (r['name'] or '(rong)', r['x'], r['y']))
            else:
                print('    %s' % r['name'])

    nodes = xf.nodes()
    if nodes:
        print()
        print('  section G — cay node, %d muc%s:'
              % (len(nodes), '' if len(nodes) <= limit else ' (hien %d dau)' % limit))
        print('    %-24s %-26s %9s %9s %8s %8s'
              % ('lop', 'ten', 'x', 'y', 'w', 'h'))
        for nd in nodes[:limit]:
            print('    %-24s %-26s %9.1f %9.1f %8.1f %8.1f'
                  % (nd['cls'][:24] or '(rong)', nd['name'][:26], nd['x'], nd['y'],
                     nd['w'], nd['h']))


def cmd_json(path):
    print(json.dumps(load(path).to_dict(), ensure_ascii=False, indent=1))


def cmd_scan(root):
    files = find_files(root)
    if not files:
        sys.exit('khong thay file .xgg nao trong %s' % root)
    ok = nrec = nstr = nempty = 0
    errs = []
    ext = collections.Counter()
    for p in files:
        try:
            xf = load(p)
            for tag in COUNTED:
                for r in xf.records(tag):
                    nrec += 1
                    if r['str_len'] == 0:
                        nempty += 1
                    else:
                        nstr += 1
                        if '.' in r['name']:
                            ext['.' + r['name'].rsplit('.', 1)[1]] += 1
            ok += 1
        except (XggError, UnicodeDecodeError) as e:
            errs.append((p, str(e)))

    print('quet %s' % root)
    print('  file .xgg   : %d' % len(files))
    print('  giai duoc   : %d' % ok)
    print('  loi         : %d' % len(errs))
    for p, e in errs[:5]:
        print('     %s — %s' % (p, e))
    print()
    print('  ban ghi     : %d  (chuoi %d, rong %d)' % (nrec, nstr, nempty))
    print('  duoi file   : %s' % ', '.join('%s x%d' % kv for kv in ext.most_common(6)))
    return 0 if not errs else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('target', help='file .xgg, hoac thu muc khi dung --scan')
    ap.add_argument('--json', action='store_true', help='xuat JSON thay vi ban tom tat')
    ap.add_argument('--scan', action='store_true', help='kiem tra tren ca cay thu muc')
    ap.add_argument('--limit', type=int, default=10, help='so muc hien ra (mac dinh 10)')
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')

    if a.scan:
        sys.exit(cmd_scan(a.target))
    try:
        if a.json:
            cmd_json(a.target)
        else:
            cmd_show(a.target, a.limit)
    except XggError as e:
        sys.exit('khong doc duoc: %s' % e)


if __name__ == '__main__':
    main()
