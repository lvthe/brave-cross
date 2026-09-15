"""Ghép tag đo được từ máy ảo vào các file bố cục.

    python emu_join.py                      # xem khớp được bao nhiêu
    python emu_join.py --ghi                # ghi trường "tag" vào layout_ref

HAI đường đo, hai cách ghép — chạy nối tiếp, đường sau đè đường trước:

1. `tags_that.json` (đầu dò HỎI TỪNG TAG, `emu_tags.py`) — cây đường dẫn kiểu
   `lAchieveTemplate/4/1`: tên node gốc rồi lần lượt các TAG. Ghép bằng VỊ TRÍ,
   vì đường dẫn không mang chỉ số con nên phải đi tìm node theo toạ độ/kích cỡ.

2. `tags_cay.json` (đầu dò ĐI CẢ CÂY, `emu_tags.py --cay`) — cùng hình dạng
   nhưng mỗi mắt là CHỈ SỐ CON: `lAchieveTemplate/2/1`. Ghép THẲNG theo chỉ số,
   không phải dò gì cả. Đo được chỉ số con của engine trùng khít thứ tự con
   trong file: UI_FriendsChatting 65/65 đường, UI_ArmyGroup_Campsite_ControlPanel
   172/172, không trượt đường nào — nên đây là đường CHÍNH XÁC, còn đường vị trí
   là đường dự phòng cho màn chưa đo được bằng cách đi cây.

Vì sao cần cả hai: đường vị trí trượt ở những lớp phủ màn bị engine nới theo cỡ
cửa sổ rồi ĐẶT GIỮA (`UI_FriendsChatting`: ba con đầu của `聊天隔挡层` file ghi
(0,0) 960x640, engine báo (-234,5,-64) 1429x768) — tỉ lệ cỡ cha cho ra x = 0,
không bao giờ bằng -234,5. Đo được trên chính màn đó: ghép vị trí 57 khớp /
5 trượt, còn đi cây thì đủ 65 node.

Chạy cả hai rồi mới áp `tags_nhan.json` (tag suy từ đối chiếu nhãn).

BÀI HỌC ĐÃ TRẢ GIÁ: đường 2 có dữ liệu trong `tags_cay.json` từ lâu mà **chưa
từng được chạy**. Hệ quả là cả một mớ "màn thiếu tag" được ghi vào ROADMAP —
`CUIFriendsChatting`, `CUIArmyGroupCampsite`, `RedPacketMainDlg` — trong khi tag
của chúng đã nằm sẵn trong file, chỉ thiếu bước áp. Chạy đường 2: node có tag
19.456/33.472 (58,1%) -> 26.315/33.472 (78,6%), `quet_show.gd` 71 màn hỏng -> 67.
Từ nay thêm đường đo mới thì **phải chạy nó rồi mới kết luận là thiếu dữ liệu**.

Có node không bao giờ lấy được tag bằng `getChildByTag`: nó chỉ trả về node ĐẦU
TIÊN mang tag đó, nên anh em trùng tag thì những cái sau bị khuất — đó là giới
hạn của chính engine, và cũng có nghĩa mã gốc không bao giờ với tới chúng.
Đi cả cây thì thấy được cả chúng (bản thân chúng VẪN có tag, chỉ là không ai
hỏi tới bằng tag).
"""

import argparse
import collections
import json
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
LAYOUT = HERE.parent.parent / 'bravecross-game' / 'layout_ref'
DO = HERE / 'tags_that.json'
CAY = HERE / 'tags_cay.json'
GAN = 0.51          # khop khit: sai lech vi tri cho phep (px)
NOI = 24.0          # khop gan dung, khi engine da doi node theo co anh that
HINH = 1.0          # sai lech cho phep khi doi chieu HINH (chi de kiem, khong de ghep)


def ten(n):
    return n.get('name') or n.get('cls') or ''


def moi_ten(node, muon, ra):
    """Mọi node mang tên này — bố cục có thể có nhiều node trùng tên."""
    if ten(node) == muon:
        ra.append(node)
    for c in node.get('children', []):
        moi_ten(c, muon, ra)


def _moi_node(node):
    """Mọi node trong cây, kể cả chính nó."""
    yield node
    for c in node.get('children', []):
        for n in _moi_node(c):
            yield n


def chon_ung_vien(ung_vien, con_engine):
    """Chọn node nào trong số trùng tên, bằng cách so vị trí các con.

    Bố cục có node trùng tên thật — ví dụ `lAchieveTemplateTop` có hai bản,
    một ở gốc và một lồng trong `lAchieveLayer`, với thứ tự con khác hẳn
    nhau. Lấy bừa cái đầu tiên thì tag của bản này bị đổ sang bản kia, và
    trong cùng một node lại có hai con cùng tag — `getChildByTag(7)` trả về
    nil và dòng đầu tiên của danh sách đã hỏng.
    """
    if len(ung_vien) == 1:
        return ung_vien[0]
    tot, diem_tot = None, -1
    for uv in ung_vien:
        vi_tri = {(round(c['x'], 1), round(c['y'], 1))
                  for c in uv.get('children', [])}
        diem = sum(1 for o in con_engine
                   if (round(o['x'], 1), round(o['y'], 1)) in vi_tri)
        if diem > diem_tot:
            tot, diem_tot = uv, diem
    return tot


def diem_cay_con(c, con_engine):
    """Bao nhieu con engine bao khop (vi tri + co) mot con cua node c.

    Dung de phan xu khi nhieu anh em TRUNG KHIT ca vi tri lan co: vi tri
    thoi khong phan biet duoc, cay con thi co. `UI_MessageBox`: nam con cua
    `lSmallBackgroup` cung o (230, 155) 500x330. May ao do tag 1 co 6 con
    (2/3/4/202/1011/1012) — dung bo con cua `lMessageBox` — con tag 4 co 3
    con, la `lThreeButton`. Lay cai dau tien con trong thi `lMessageBox` an
    tag 4, `getChildByTag(1):getChildByTag(2)` ra nil, va MOI hop thoai hoi
    cua game chet o CMessageBox.lua:79.
    """
    diem = 0
    for e in con_engine:
        for k in c.get('children', []):
            if (abs(k['x'] - e['x']) <= NOI and abs(k['y'] - e['y']) <= NOI
                    and abs(k['w'] - e['w']) <= 1.0 and abs(k['h'] - e['h']) <= 1.0):
                diem += 1
                break
    return diem, -abs(len(c.get('children', [])) - len(con_engine))


def chon_con(cha, o, da_dung, ti_le=(1.0, 1.0), con_engine=()):
    """Con nào của `cha` ứng với node engine báo ở vị trí o.

    Khớp trước bằng vị trí đúng khít, không được thì mới nới ra gần đúng.
    Phải có bước nới: với sprite, engine nạp ảnh THẬT rồi dời node theo cỡ
    ảnh mới, nên vị trí lệch vài px so với file — hai icon trạng thái của
    `canget` file ghi @686.5 và @688 mà engine báo @681 và @674. Khít 0,5 px
    thì trượt cả hai, và dòng đầu của danh sách hỏng ngay.

    Bước cuối so theo TỈ LỆ CỠ CHA (ti_le = cỡ engine báo / cỡ trong file).
    Engine nới lớp phủ màn theo tỉ lệ cửa sổ (SetWHScaleToWinSize: 1366 ->
    1429 trên máy ảo) và giữ con ở đúng TỈ LỆ trong cha: `lLoadingDialog` file
    ghi x=683 (giữa 1366), engine báo 714,5 (giữa 1429) — lệch 31,5 px, quá
    ngưỡng nới. Thiếu bước này thì `lCommonLoadingDialog:getChildByTag(4)` ra
    nil và CUIBuyDialog.lua:197/227 chết — chính chỗ cảnh Main chết.
    """
    con = cha.get('children', [])
    if not con:
        return None
    chua = [c for c in con if id(c) not in da_dung]
    sx, sy = ti_le

    def hop(bo, nguong, kx=1.0, ky=1.0):
        gan = [c for c in bo
               if abs(c['x'] * kx - o['x']) <= nguong
               and abs(c['y'] * ky - o['y']) <= nguong]
        if not gan:
            return None
        # Cùng vị trí thì lấy cái khớp cả kích thước.
        khop = [c for c in gan
                if abs(c['w'] - o['w']) <= 1.0 and abs(c['h'] - o['h']) <= 1.0]
        if len(khop) > 1 and con_engine:
            # Trung khit ca vi tri lan co: phan xu bang cay con (diem_cay_con).
            return max(khop, key=lambda c: diem_cay_con(c, con_engine))
        if khop:
            return khop[0]
        # Không thì lấy cái gần nhất.
        return min(gan, key=lambda c: (c['x'] - o['x']) ** 2 + (c['y'] - o['y']) ** 2)

    for nguong in (GAN, NOI):
        for bo in (chua, con):
            r = hop(bo, nguong)
            if r is not None:
                return r
    if abs(sx - 1.0) > 1e-3 or abs(sy - 1.0) > 1e-3:
        for nguong in (GAN, NOI):
            for bo in (chua, con):
                r = hop(bo, nguong, sx, sy)
                if r is not None:
                    return r
    return None


def so_tag(o):
    """Tag engine báo cho một node, dạng số; None nếu không đọc được.

    `getTag()` trả về số, nhưng đi qua log nên nó thành chuỗi. Tag 0 là tag
    THẬT (cocos2d-x 2.x đánh dấu "không có tag" bằng -1, không phải 0): đo được
    3.675 lượt `getChildByTag(0)` trong mã gốc trả về node.
    """
    t = str(o.get('tag', '')).strip()
    if not t:
        return None
    try:
        return int(t)
    except ValueError:
        return None


def theo_chi_so(nut, phan):
    """Đi từ `nut` xuống theo các CHỈ SỐ CON (1-based, như mã gốc duyệt).

    Trả về node của bố cục, hoặc None nếu cây không khớp (chỉ số vượt số con).
    """
    for phan_tu in phan:
        try:
            k = int(phan_tu) - 1
        except ValueError:
            return None
        con = nut.get('children', [])
        if k < 0 or k >= len(con):
            return None
        nut = con[k]
    return nut


def ghep_chi_so(doc, cay_man, tk):
    """Ghép tag theo CHỈ SỐ CON — đường chính xác (xem docstring đầu file).

    Ghi thẳng vào node, và trả về tập id() những node do đường NÀY ghi — để
    bước dọn ở dưới biết chỗ nào là lời của engine, chỗ nào là phỏng đoán cũ.
    """
    # Ten node goc cua file: đường dẫn đi từ một tên LỒNG trong file (đầu dò
    # `--cay` đi từ mọi node có tên, không chỉ node gốc) không dùng được, vì
    # chỉ số của nó tính từ một gốc khác.
    goc = {}
    for r in doc.get('roots', []):
        goc.setdefault(ten(r), []).append(r)
    # ...nhưng "không dùng được" chỉ đúng khi tên ấy mơ hồ. Tên LỒNG mà trong
    # file chỉ có ĐÚNG MỘT node mang nó thì chỉ số con tính từ chính node đó là
    # đường đi thẳng, y như đường từ gốc thật — không phải phỏng đoán gì.
    # Đo trên 146 màn đã đi cây: 12.326 đường bị bỏ ở nhánh cũ, trong đó 11.223
    # đường có tên LỒNG duy nhất (0 đường không tìm thấy tên, 0 đường trùng tên).
    bang_ten = {}
    for r in doc.get('roots', []):
        for n in _moi_node(r):
            t = ten(n)
            if t:
                bang_ten.setdefault(t, []).append(n)
    da_ghi = set()
    for duong in sorted(cay_man, key=lambda d: (d.count('/'), d)):
        phan = duong.split('/')
        neo = goc.get(phan[0])
        neo_ten = False
        if neo is None:
            uv = bang_ten.get(phan[0]) or []
            if len(uv) != 1:
                tk['goc-khac'] += 1
                continue
            neo = uv
            neo_ten = True
            tk['neo-ten'] += 1
        if len(phan) == 1:
            tk['goc'] += 1
            continue
        ung_vien = neo
        if len(ung_vien) == 1:
            nut = ung_vien[0]
        else:
            # Nhiều node gốc trùng tên: phân xu bằng vị trí các con, cùng cách
            # mà đường vị trí đang dùng.
            con_engine = [cay_man[d] for d in cay_man
                          if d.startswith(duong + '/') and d.count('/') == 1]
            nut = chon_ung_vien(ung_vien, con_engine)
        if nut is None:
            tk['lech-cay'] += 1
            continue
        nut = theo_chi_so(nut, phan[1:])
        if nut is None:
            tk['lech-cay'] += 1
            continue
        o = cay_man[duong]
        t = so_tag(o)
        if t is None:
            tk['khong-co-tag'] += 1
            continue
        # Đối chiếu HÌNH — không dùng để ghép, dùng để biết đường chỉ số có
        # đáng tin không. Lệch hình thường là do engine nới lớp phủ theo cửa sổ,
        # đúng những chỗ đường vị trí trượt; vẫn ghi, nhưng đếm riêng.
        if (abs(o.get('x', 0) - nut['x']) <= HINH
                and abs(o.get('y', 0) - nut['y']) <= HINH
                and abs(o.get('w', 0) - nut['w']) <= HINH
                and abs(o.get('h', 0) - nut['h']) <= HINH):
            tk['khop-hinh'] += 1
            if neo_ten:
                tk['neo-khop'] += 1
        else:
            tk['lech-hinh'] += 1
            if neo_ten:
                tk['neo-lech'] += 1
        cu = nut.get('tag')
        if cu is None:
            tk['moi'] += 1
        elif cu == t:
            tk['trung'] += 1
        else:
            tk['doi'] += 1
        nut['tag'] = t
        nut.pop('tagFrom', None)        # tag ĐO được thì không còn là tag SUY
        da_ghi.add(id(nut))
    return da_ghi


def ghep_cay(doc, cay_man, tk):
    """Áp `tags_cay.json` cho một màn; trả về tập id() node đã ghi.

    KHÔNG xoá tag cũ. Đường vị trí có thể đã gán cho node này một tag mà đường
    chỉ số nói khác; ta ghi đè (đường chỉ số là lời của chính engine, đo được
    chỉ số con trùng khít thứ tự file), nhưng không đụng tới node mà đường chỉ
    số không đo được — ở đó tag cũ vẫn là bằng chứng duy nhất ta có. Hệ quả có
    thể có (một node còn tag cũ trùng với tag mới của anh em nó) ĐO ĐƯỢC bằng
    chính đầu dò của bản gốc: xem tools/quet_show.gd, mục "TAG: ... luot
    getChildByTag co ket qua".
    """
    return ghep_chi_so(doc, cay_man, tk)


def ghep_mot_man(doc, cay):
    """Trả về (số khớp, số không khớp). Gắn thẳng 'tag' vào node của doc."""
    goc = {}
    da_dung = set()
    da_giai = set()          # node bo cuc da duoc mot duong engine nhan
    khop = truot = 0
    # Sap theo do sau de cha luon duoc giai truoc con.
    for duong in sorted(cay, key=lambda d: d.count('/')):
        o = cay[duong]
        phan = duong.split('/')
        if len(phan) == 1:                       # node goc, tra theo ten
            ung_vien = []
            for r in doc.get('roots', []):
                moi_ten(r, phan[0], ung_vien)
            if not ung_vien:
                continue
            con_engine = [cay[d] for d in cay
                          if d.startswith(duong + '/')
                          and d.count('/') == 1]
            nut = chon_ung_vien(ung_vien, con_engine)
            # Node nay da duoc mot duong khac nhan roi thi bo — hai duong
            # engine cung tro ve mot node bo cuc se ghi de len nhau va sinh
            # ra tag trung trong cung mot cha.
            if nut is None or id(nut) in da_giai:
                continue
            da_giai.add(id(nut))
            goc[duong] = nut
            continue
        duong_cha = '/'.join(phan[:-1])
        cha = goc.get(duong_cha)
        if cha is None:
            truot += 1
            continue
        # Co cha ma engine bao ve so voi co trong file (xem chon_con).
        o_cha = cay.get(duong_cha) or {}
        ti_le = (o_cha.get('w', 0) / cha['w'] if cha.get('w') else 1.0,
                 o_cha.get('h', 0) / cha['h'] if cha.get('h') else 1.0)
        sau = duong.count('/') + 1
        con_engine = [cay[d] for d in cay
                      if d.startswith(duong + '/') and d.count('/') == sau]
        con = chon_con(cha, o, da_dung, ti_le, con_engine)
        if con is None:
            truot += 1
            continue
        con['tag'] = int(phan[-1])
        da_dung.add(id(con))
        khop += 1
        # Node nay da duoc mot duong khac nhan thi KHONG di tiep xuong con
        # cua no theo duong nay. Cung mot node runtime thuong den qua hai
        # duong — vi du `lAchieveTemplateTop` (theo ten) va `lAchieveLayer/2`
        # (theo tag) — va neu ca hai cung phat tag cho con thi lan sau se
        # vo phai nhung con chua dung, dat nham tag, roi sinh ra hai con
        # cung tag trong mot cha.
        if id(con) in da_giai:
            continue
        da_giai.add(id(con))
        goc[duong] = con
    return khop, truot


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--ghi', action='store_true', help='ghi vao layout_ref')
    ap.add_argument('--do', default=str(DO))
    ap.add_argument('--cay', default=str(CAY),
                    help='du lieu di ca cay (emu_tags.py --cay); khong co thi bo qua')
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')

    p = pathlib.Path(a.do)
    if not p.exists():
        raise SystemExit('chua co %s — chay emu_tags.py truoc' % p)
    duoc = json.loads(p.read_text('utf-8'))
    nodes = duoc.get('nodes', {})
    print('co du lieu do cho %d man' % len(nodes))

    tong_khop = tong_truot = tong_man = 0
    for man, cay in sorted(nodes.items()):
        f = LAYOUT / (man.replace('.xgg', '') + '.json')
        if not f.exists():
            continue
        doc = json.loads(f.read_text('utf-8'))
        khop, truot = ghep_mot_man(doc, cay)
        tong_khop += khop
        tong_truot += truot
        tong_man += 1
        if a.ghi:
            f.write_text(json.dumps(doc, ensure_ascii=False), encoding='utf-8')
    print('%d man: %d node gan duoc tag theo VI TRI, %d khong khop duoc'
          % (tong_man, tong_khop, tong_truot))
    print('(chay lai voi --ghi de ghi vao layout_ref)')

    # --- Đường thứ hai: ghép theo CHỈ SỐ CON (emu_tags.py --cay) ---
    pc = pathlib.Path(a.cay)
    if not pc.exists():
        print('\nchua co %s — chay `emu_tags.py --cay --all` de do them\n'
              '(bo qua duong chi so, chi con tag ghep theo vi tri)' % pc.name)
        return
    cd = json.loads(pc.read_text('utf-8'))
    cay_man = cd.get('cay', {})
    xong = cd.get('xong', {})
    tk = collections.Counter()
    for man, cay in sorted(cay_man.items()):
        f = LAYOUT / (man.replace('.xgg', '') + '.json')
        if not f.exists():
            continue
        doc = json.loads(f.read_text('utf-8'))
        ghep_cay(doc, cay, tk)
        tk['man'] += 1
        if not xong.get(man, False):
            tk['man-thieu'] += 1
        if a.ghi:
            f.write_text(json.dumps(doc, ensure_ascii=False), encoding='utf-8')
    print('\n%d man ghep lai theo CHI SO CON (trong do %d man dau do di KHONG tron):'
          % (tk['man'], tk['man-thieu']))
    for k in ('moi', 'trung', 'doi', 'lech-hinh', 'khop-hinh', 'khong-co-tag',
              'lech-cay', 'goc', 'goc-khac', 'neo-ten', 'neo-khop', 'neo-lech'):
        print('   %-12s %6d' % (k, tk[k]))
    print('   ("moi" = node nay truoc khong co tag; "doi" = tag CU khac tag do lai)')
    if a.ghi:
        print('da ghi vao layout_ref')



NHAN = HERE / 'tags_nhan.json'


def chon_khop(c, e):
    """Node c co khop muc e cua tags_nhan.json khong.

    'con'  : ten node hoac ten lop, dung tuyet doi (doi chieu nhan).
    'loai' : typeName cua node; 'co_con' (tuy chon): no co it nhat mot con
             typeName do (suy cau truc — cho node khong ten, lop chung chung).
    """
    if 'con' in e:
        return e['con'] in (c.get('name'), c.get('cls'))
    if c.get('typeName') != e.get('loai'):
        return False
    if 'co_con' in e:
        return any(k.get('typeName') == e['co_con'] for k in c.get('children', []))
    return True


def ghep_nhan(ghi):
    """Ap tag SUY RA bang doi chieu nhan (tags_nhan.json) — chay SAU tag do.

    Chi gan cho node CHUA co tag, khong de hai con cung tag, va danh dau
    tagFrom = 'nhan' de ai doc bo cuc cung biet tag nao la do, tag nao la suy.
    Muc nao khong chi ra DUNG MOT node thi bao HONG chu khong doan.
    """
    if not NHAN.exists():
        return 0, 0
    bang = json.loads(NHAN.read_text('utf-8'))
    gan = loi = 0
    for man, ds_cha in bang.get('man', {}).items():
        f = LAYOUT / (man.replace('.xgg', '') + '.json')
        if not f.exists():
            print('  (tags_nhan: khong co %s)' % f.name)
            continue
        doc = json.loads(f.read_text('utf-8'))
        for ten_cha, ds in ds_cha.items():
            # Cha la DUONG TAG kieu tags_that.json: 'lMainToolbarRightTop/18'
            # = con mang tag 18 cua node ten lMainToolbarRightTop. Nho vay muc
            # sau tro duoc toi node chi vua co tag o muc truoc.
            phan = ten_cha.split('/')
            cha = []
            for r in doc.get('roots', []):
                moi_ten(r, phan[0], cha)
            for t_ in phan[1:]:
                cha = [c for n_ in cha for c in n_.get('children', [])
                       if str(c.get('tag')) == t_]
            if len(cha) != 1:
                print('  HONG tags_nhan: %s co %d node o %s' % (man, len(cha), ten_cha))
                loi += 1
                continue
            con = cha[0].get('children', [])
            for e in ds:
                khop = [c for c in con if chon_khop(c, e)]
                if len(khop) != 1:
                    print('  HONG tags_nhan: %s/%s: %d con khop %s'
                          % (man, ten_cha, len(khop), e.get('con') or e.get('loai')))
                    loi += 1
                    continue
                c = khop[0]
                if 'tag' in c:
                    if c['tag'] != e['tag']:
                        print('  HONG tags_nhan: %s da co tag DO %s, bang nhan ghi %s'
                              % (e['con'], c['tag'], e['tag']))
                        loi += 1
                    continue
                if any(x.get('tag') == e['tag'] for x in con):
                    print('  HONG tags_nhan: tag %s da co con khac mang' % e['tag'])
                    loi += 1
                    continue
                c['tag'] = e['tag']
                c['tagFrom'] = 'nhan'
                gan += 1
        if ghi:
            f.write_text(json.dumps(doc, ensure_ascii=False), encoding='utf-8')
    return gan, loi


if __name__ == '__main__':
    main()
    g_, l_ = ghep_nhan('--ghi' in sys.argv)
    print('tags_nhan.json: %d node gan them tag suy tu nhan, %d loi' % (g_, l_))
