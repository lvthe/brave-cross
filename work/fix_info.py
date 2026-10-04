"""Luật `sngFixInfoReflash` của bản gốc — đọc bản ghi .xgg và KIỂM LẠI phép đo.

    python fix_info.py --dem              kê toàn bộ .xgg trong conf/
    python fix_info.py --kiem             đọc lại _pt/*.log, dựng lại từng mẫu
    python fix_info.py --in <file> <tên>  in bản ghi của một node

VÌ SAO CÓ FILE NÀY. `emu_pt.py` là chương trình ĐO: nó chạy bản gốc trong máy
giả lập rồi in ra vị trí thật. File này là chương trình KIỂM: nó không chạy gì
cả, chỉ đọc lại log thô mà `emu_pt.py` đã ghi (`_pt/*.log`) cộng với chính file
`.xgg`, rồi tự tính ra con số đáng lẽ phải thấy. Hai chương trình khác nhau,
hai đường tính khác nhau — nếu cùng ra một số thì phép đo mới đáng tin.

Đó là lý do `emu_pt.py` phải ghi log ra đĩa: một phép đo chỉ đọc được một lần
trong terminal thì không ai kiểm lại được.

Chạy được gì khi không có máy ảo:
    --dem            đếm cả kho .xgg (không cần log)
    --in <f> <tên>   in bản ghi của một node (không cần log)
    --khoi           đối chiếu cột `fix` mà xgg.py/layout.py ghi ra với đọc thô
                     (không cần log); cả kho 33.472 node, khớp 28.568, lệch 0
    --kiem           cần `_pt/*.log` — sinh bằng `python emu_pt.py --cong`,
                     `--o54`, `--kieu0`, `--kieu23` (đều cần máy ảo đang chạy).
                     `_pt/` là thư mục nháp, không nằm trong git.

BẢN GHI NODE. Mỗi node là một bản ghi dài 216..352 byte; phần đầu cố định:

    +0x38  int32  kieu Y            \
    +0x3C  int32  kieu X            /  THỨ TỰ NÀY NGƯỢC VỚI TÊN GỌI
    +0x40  int32  o40   cột neo trái   (kieu X 1)
    +0x44  int32  o44   cột neo phải  (kieu X 3)
    +0x48  int32  o48   cột neo trên  (kieu Y 1)
    +0x4C  int32  o4C   cột neo dưới (kieu Y 3)
    +0x50  int32  o50   cột lệch giữa (kieu X 2)
    +0x54  int32  o54   cột lệch giữa (kieu Y 2)
    +0x7C  float  x, y              toạ độ trong trình sửa
    +0x84  float  scaleX, scaleY
    +0x90  float  anchorX, anchorY
    +0x98  float  w, h

CẨN THẬN Ở +0x38/+0x3C: `struct.unpack_from('<8i', data, a + 0x38)` trả phần tử
ĐẦU TIÊN là kiểu Y, không phải kiểu X. Đã một lần đọc nhầm và làm đảo trục
trong bảng kê toàn bộ — số liệu cũ (2.622 và 2.302) là số ĐẢO, không dùng lại.

LUẬT. Gọi P = contentSize của CHA, (w,h) = contentSize của node, (sx,sy) =
scale, ax = anchorX·w, ay = anchorY·h (nhân với w,h CHƯA nhân scale — xem dưới),
ws = w·sx, hs = h·sy:

    kiểu X 0  -> để nguyên trục X
    kiểu X 1  -> x = o40 + ax·sx
    kiểu X 2  -> x = (P.w − ws)/2 + ax·sx + o50
    kiểu X 3  -> x = P.w − (ws − ax·sx) − o44
    kiểu Y 0  -> để nguyên trục Y
    kiểu Y 1  -> y = P.h − (hs − ay·sy) − o48
    kiểu Y 2  -> y = (P.h − hs)/2 + ay·sy + o54
    kiểu Y 3  -> y = o4C + ay·sy

Đọc theo "hộp đã co giãn": hộp rộng ws, cao hs; neo nằm trong hộp ở ax·sx kể từ
mép trái và ay·sy kể từ mép DƯỚI (Cocos gốc dưới–trái, y hướng lên). Bốn kiểu là
bốn cách ghim hộp đó:

    kiểu 1: ghim mép trái vào o40        (X) / ghim mép TRÊN vào P.h − o48 (Y)
    kiểu 2: ghim tâm vào P.w/2 + o50     (X) / ghim tâm vào P.h/2 + o54    (Y)
    kiểu 3: ghim mép phải vào P.w − o44  (X) / ghim mép DƯỚI vào o4C      (Y)

Sáu điều đã ĐO được, không suy từ mã:
  * Không có cổng kích hoạt nào. Cha cao thêm 90 thì con cũng nhích đúng 90.
  * Kiểu 0 là "để yên trục đó", không phải "đặt lại về số trong bản ghi".
  * Kiểu 1 và kiểu 3 dùng hộp ĐÃ co giãn; **kiểu 2 dùng hộp CHƯA co giãn**.
    Đây là chỗ dễ đọc sai nhất — xem `cong_thuc` để biết hai mẫu chốt nó.
  * `o50` và `o54` là phép CỘNG có dấu (đo được cả hai dấu).
  * `o44` ghim mép phải, `o4C` ghim mép dưới (đo được ở ba mức khác nhau).
  * Hàm đệ quy xuống con cháu, mỗi cấp dùng contentSize của cha nó.

CHỖ CÒN CHƯA ĐO ĐƯỢC. Số hạng neo của kiểu 2 được chốt bằng ĐÚNG MỘT mẫu
(g_UpgradeQualityActionMaterialItem, neo 0,5, scale 0,8). Cả kho chỉ có **một**
node nữa phân biệt được "neo nhân scale" với "neo không nhân scale" ở kiểu 2 —
`UI_ArmyGroup_War_960_640.xgg` node 390x31 neo (1 ; 0,5) scale (0 ; 1) — và node
đó **không có tên**, cha cũng không có tên, nên không đặt lại bên cha bằng Lua
được. Node đó lại có scaleX = 0 nên bề rộng co giãn bằng 0. Ghi ra đây thay vì
đoán: nếu sau này có màn mới dùng kiểu 2 với neo khác 0 và 0,5 thì phải đo lại.

Số x,y lưu trong bản ghi là số của TRÌNH SỬA, không phải kết quả công thức —
lúc chạy, công thức được tính lại theo contentSize thật của cha. Đó là lý do
chỉ ~47% bản ghi khớp với công thức nếu đem cha của bản ghi ra tính.
"""

import os
import struct
import sys

# Ten lop node trong .xgg co chu Trung (NODE_TYPES cua xgg.py), ma console
# Windows mac dinh la cp1252 — khong sua thi `--in` chet ngay dong dau.
for _d in (sys.stdout, sys.stderr):
    try:
        _d.reconfigure(encoding='utf-8', errors='replace')
    except (AttributeError, OSError):
        pass

import cay
import xgg

CONF = os.path.join(cay.ASSETS, 'conf')
PT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '_pt')

# Tên cột, đúng thứ tự của tuple mà `fix_of` trả về: (mx, my, o40, ...).
#
# Cho nay tung ghi ('my', 'mx', ...) — sai, va sai LANG LE: `fix_of` da doi hai
# phan tu dau ve dung thu tu (mx, my) roi, nen dat ten cot sai lan nua thi
# `f['mx']` doc ra kieu Y. Triệu chứng: bảng kê in ra k=(1,0) cho
# btnEquipForgeUINavigation2 trong khi phep do `--kieu0` cho thay truc X cua no
# dung yen (kieu X = 0). Mot phep kiem đọc sai tên cột thì tệ hơn không có.
COT = ('mx', 'my', 'o40', 'o44', 'o48', 'o4C', 'o50', 'o54')


def fix_of(x, i):
    """Tám số của node thứ `i`, trả về dict theo tên cột.

    Đảo hai phần tử đầu vì lý do ghi ở đầu file.
    """
    a = x.offsets['G'] + x.node_offsets()[i]
    t = struct.unpack_from('<8i', x.data, a + 0x38)
    return dict(zip(COT, (t[1], t[0]) + t[2:]))


def hinh_dang(x, i):
    """Hình dạng của node: w, h, anchor, scale — lấy từ `nodes()`, không chép tay."""
    n = x.nodes()[i]
    return n['w'], n['h'], n['anchorX'], n['anchorY'], n['scaleX'], n['scaleY']


def cong_thuc(f, pw, ph, w, h, ax, ay, sx, sy):
    """Vị trí mà bản gốc sẽ đặt node vào. None nghĩa là trục đó để yên.

    `ax`, `ay` là anchor ĐÃ nhân w,h.

    KIỂU 2 KHÁC KIỂU 1 VÀ 3 Ở CHỖ CO GIÃN — đo được, không suy:
      * kiểu 1 và kiểu 3 dùng hộp ĐÃ co giãn (ws = w·sx, hs = h·sy) và anchor
        cũng đã co giãn (ax·sx, ay·sy):
            btnEquipForgeUINavigation1 (k=(1,1), scale 0,8, 79x79, o40=25,
            o48=15, cha 700x800) đo được (56,6 ; 753,4).
            x = 25 + 39,5·0,8 = 56,6  (chưa co giãn thì ra 64,5)
            y = 800 − (63,2 − 31,6) − 15 = 753,4  (chưa co giãn thì ra 745,5)
            btnHeroEquipUIToRight (k=(3,2), scale x = −1, o44=28, 56x83, cha
            rộng 880) đo được x = 880 ; chưa co giãn thì ra 824.
      * kiểu 2 dùng hộp CHƯA co giãn, và số hạng neo cũng chưa co giãn:
            lCUICOGMap (k=(2,2), neo (0,0), scale 0,8, 2850x2235, cha lCOGUI)
            đo được (−945, −797,5) khi cha 960x640 và (−875, −737,5) khi cha
            1100x760. Chưa co giãn: (960−2850)/2 = −945 và (1100−2850)/2 = −875
            đúng; đã co giãn: (1100−2280)/2 = −590, sai 285 điểm.
            g_UpgradeQualityActionMaterialItem (k=(2,0), neo (0,5;0,5), scale
            0,8, 79x79, cha rộng 500) đo được x = 250. Chưa co giãn:
            (500−79)/2 + 39,5 = 250 đúng; đã co giãn: (500−63,2)/2 + 31,6 =
            242,1, sai 7,9 điểm.
    """
    ws, hs = w * sx, h * sy
    axs, ays = ax * sx, ay * sy
    X = {0: None, 1: f['o40'] + axs,
         2: (pw - w) * 0.5 + ax + f['o50'],
         3: pw - (ws - axs) - f['o44']}[f['mx']]
    Y = {0: None, 1: ph - (hs - ays) - f['o48'],
         2: (ph - h) * 0.5 + ay + f['o54'],
         3: f['o4C'] + ays}[f['my']]
    return X, Y


# Nạp file và tra node theo tên ------------------------------------------------

_cache = {}


def nap(ten_file):
    if ten_file not in _cache:
        _cache[ten_file] = xgg.load(os.path.join(CONF, ten_file))
    return _cache[ten_file]


def tra(ten_file):
    """{tên node: chỉ số} cho một file. Node không tên thì bỏ qua."""
    x = nap(ten_file)
    if '_tra' not in x.__dict__:
        d = {}
        for i, n in enumerate(x.nodes()):
            t = n.get('name')
            if t and t not in d:
                d[t] = i
        x.__dict__['_tra'] = d
    return x.__dict__['_tra']


def cha_cua(x):
    """{id(node): node cha} — cây dựng từ +0xB4/+0xB8 của chính file."""
    d = {}
    for r in x.tree():
        hang = [r]
        d[id(r)] = None
        while hang:
            nd = hang.pop()
            for c in nd.get('children', []):
                d[id(c)] = nd
                hang.append(c)
    return d


# Đọc log thô ------------------------------------------------------------------

def doc_fi(ten_log, the_loai):
    """Các dòng `FI|<thể loại>|...` của một log, tách thành danh sách trường."""
    d = os.path.join(PT, ten_log)
    if not os.path.exists(d):
        print('  thieu log %s — chay `python emu_pt.py --%s` truoc'
              % (ten_log, the_loai))
        return []
    ra = []
    with open(d, encoding='utf-8') as fh:
        for l in fh:
            l = l.strip()
            if l.startswith('FI|' + the_loai + '|'):
                ra.append(l.split('|')[2:])
    return ra


def so_nguyen(v):
    try:
        return int(v)
    except ValueError:
        return None


def so_thuc(v):
    try:
        return float(v)
    except ValueError:
        return None


# Kiểm: cột neo và cổng kích hoạt ----------------------------------------------

# Mẫu của `--cong`, đúng bảng `muc` trong `emu_pt.py`. Bảng này chép tay là
# ĐÚNG Ý ĐỒ: nó là dữ liệu vào của phép kiểm, không phải thứ được kiểm.
MUC_CONG = [
    ('UI_Equipment_960_640.xgg', 'lEquipmentForgeUI', 410, 640,
     ('btnEquipForgeUINavigation2', 'btnEquipForgeUINavigation3')),
    ('UI_Equipment_960_640.xgg', 'lEquipUpgradeQualityCompoundUI', 410, 640,
     ('btnEquipUpgradeQualityCompoundNavigation2',
      'btnEquipUpgradeQualityCompoundNavigation3')),
    ('UI_Equipment_960_640.xgg', 'lEquipUpgradeQualityMainUI', 410, 640,
     ('g_UpgradeQualityActionBeginLayer',)),
    ('UI_Equipment_960_640.xgg', 'nodeEquipmentUI_CritIntensifyLevel', 40, 80,
     ('nodeEquipmentUI_CritIntensifyLevel_1',)),
    ('UI_Hero_960_640.xgg', 'spDlgUpgradeHeroStarSkill', 764, 250,
     ('spDlgUpgradeHeroStarInfoUpIcon5',)),
]


def kiem_cong():
    """Dựng lại năm mẫu của `--cong` từ log + .xgg.

    Ba câu hỏi, mỗi câu một phép đối chiếu số:
      1. Công thức có ra đúng vị trí đo được ở CẢ HAI bên cha không (kể cả
         trước khi đổi bên, nên nó kiểm luôn cả cột neo)?
      2. Không có cổng: con nhích đúng bằng hiệu bên cha.
      3. Trục kiểu 0 có đứng yên không (kiểm ở `--kieu0`, ở đây chỉ suy ra
         từ chỗ công thức trả None mà vị trí đo được vẫn khớp).
    """
    print('=== cong: cong thuc doc lap voi so do duoc ===')
    dong = doc_fi('cong.log', 'cong')
    if not dong:
        return 0, 0
    du = {}
    for p in dong:
        k = so_nguyen(p[0])
        nhan, ten = p[1], p[2]
        so = [so_thuc(v) for v in p[3:]]
        du[(k, nhan, ten)] = so

    ok = hong = 0
    for k, (ten_file, cha, pw_sau, ph_sau, con) in enumerate(MUC_CONG, 1):
        x = nap(ten_file)
        tra_ten = tra(ten_file)
        if cha not in tra_ten:
            print('  muc %d: khong thay cha %s trong %s' % (k, cha, ten_file))
            hong += 1
            continue
        # Bên cha TRƯỚC khi đổi lấy từ log, không lấy từ bảng trên: bảng chỉ
        # ghi bên SAU. Nhờ vậy phép kiểm không tự cho mình đáp số.
        truoc = du.get((k, 'truoc', cha))
        sau = du.get((k, 'sau', cha))
        if not truoc or not sau:
            print('  muc %d: thieu dong cha' % k)
            hong += 1
            continue
        pw_t, ph_t = truoc
        pw_s, ph_s = sau
        n_khop = n_tong = 0
        for t in con:
            if t not in tra_ten:
                print('  muc %d: khong thay %s' % (k, t))
                hong += 1
                continue
            i = tra_ten[t]
            f = fix_of(x, i)
            w, h, ax, ay, sx, sy = hinh_dang(x, i)
            for nhan, (pw, ph) in (('truoc', (pw_t, ph_t)),
                                   ('sau', (pw_s, ph_s))):
                do = du.get((k, nhan, t))
                if not do or len(do) < 4:
                    print('  muc %d %s %s: thieu so do' % (k, nhan, t))
                    hong += 1
                    continue
                mx_do, my_do = do[0], do[1]
                X, Y = cong_thuc(f, pw, ph, w, h, ax * w, ay * h, sx, sy)
                for truc, gia_tri, do_duoc in (('x', X, mx_do), ('y', Y, my_do)):
                    n_tong += 1
                    if gia_tri is None:
                        # Trục để yên: công thức không nói gì. Chỗ này KHÔNG
                        # kiểm được gì, và nói rõ ra thay vì tính là đạt.
                        print('  muc %d %-4s %-38s truc %s kieu 0 — cong thuc'
                              ' khong noi gi' % (k, nhan, t, truc))
                        continue
                    if abs(gia_tri - do_duoc) < 0.01:
                        n_khop += 1
                        ok += 1
                    else:
                        hong += 1
                        print('  muc %d %-4s %-38s truc %s: cong thuc %.3f,'
                              ' do duoc %.3f' % (k, nhan, t, truc, gia_tri,
                                                 do_duoc))
            # Không cổng: chênh lệch phải đúng bằng hiệu bên cha.
            dt = du.get((k, 'truoc', t))
            ds = du.get((k, 'sau', t))
            if dt and ds and len(dt) >= 4 and len(ds) >= 4:
                n_tong += 1
                dx, dy = ds[0] - dt[0], ds[1] - dt[1]
                # kieu Y 1 ghim mep tren -> doi dung bang hieu cao; kieu Y 2
                # ghim tam -> doi dung NUA hieu cao.
                mong_dy = {0: 0.0, 1: ph_s - ph_t, 2: (ph_s - ph_t) * 0.5,
                           3: 0.0}[f['my']]
                mong_dx = {0: 0.0, 1: 0.0, 2: (pw_s - pw_t) * 0.5,
                           3: 0.0}[f['mx']]
                if abs(dx - mong_dx) < 0.01 and abs(dy - mong_dy) < 0.01:
                    n_khop += 1
                    ok += 1
                else:
                    hong += 1
                    print('  muc %d %-38s nhich (%.3f, %.3f), phai la'
                          ' (%.3f, %.3f)' % (k, t, dx, dy, mong_dx, mong_dy))
        print('  muc %d: %s %dx%d -> %dx%d, %d/%d truc khop'
              % (k, cha, pw_t, ph_t, pw_s, ph_s, n_khop, n_tong))
    return ok, hong


# Kiểm: dấu của cột +0x54 ------------------------------------------------------

def kiem_o54():
    """Dựng lại bảng `--o54`: lớp gốc của file, cha bị đổi bên.

    Chỉ lớp GỐC mới kiểm được ở đây: node trong `_pt/o54.log` là lớp gốc của
    chính file nó thuộc về, nên hiệu so với tâm chính là `o50`/`o54`.
    """
    print()
    print('=== o54: dau cua cot lech giua ===')
    dong = doc_fi('o54.log', 'o54')
    if not dong:
        return 0, 0
    # Lần đầu log ra là lúc chưa đổi bên, đã có sẵn bên thật của cảnh; ba lần
    # sau là sau khi `sc:setContentSize` + reflash.
    # (nhan, ten, file, ten lop)
    mau = [('hero-at-960x640', 'lHeroInfoUI', 'UI_Hero_960_640.xgg'),
           ('hero-at-960x800', 'lHeroInfoUI', 'UI_Hero_960_640.xgg'),
           ('hero-at-1137.8x768', 'lHeroInfoUI', 'UI_Hero_960_640.xgg'),
           ('starsoul', 'lStarSoulMain', 'UI_StarSoul_960_640.xgg'),
           ('qq-at-960x640', 'lQQCoinsGift', 'UI_QQCoinsGift_960_640.xgg'),
           ('qq-at-960x800', 'lQQCoinsGift', 'UI_QQCoinsGift_960_640.xgg')]
    du = {}
    for p in dong:
        if len(p) < 8:
            continue
        du[p[0]] = p
    ok = hong = 0
    for nhan, ten, ten_file in mau:
        p = du.get(nhan)
        if p is None:
            print('  thieu mau %s' % nhan)
            hong += 1
            continue
        x, y = so_thuc(p[2]), so_thuc(p[3])
        w, h = so_thuc(p[4]), so_thuc(p[5])
        sw, sh = so_thuc(p[6]), so_thuc(p[7])
        if None in (x, y, w, h, sw, sh):
            print('  mau %s: thieu so' % nhan)
            hong += 1
            continue
        i = tra(ten_file).get(ten)
        if i is None:
            print('  khong thay %s trong %s' % (ten, ten_file))
            hong += 1
            continue
        xx = nap(ten_file)
        f = fix_of(xx, i)
        w2, h2, ax, ay, sx, sy = hinh_dang(xx, i)
        X, Y = cong_thuc(f, sw, sh, w2, h2, ax * w2, ay * h2, sx, sy)
        for truc, gia_tri, do_duoc in (('x', X, x), ('y', Y, y)):
            if gia_tri is None:
                print('  %-18s truc %s kieu 0' % (nhan, truc))
                continue
            if abs(gia_tri - do_duoc) < 0.01:
                ok += 1
            else:
                hong += 1
                print('  %-18s truc %s: cong thuc %.3f, do duoc %.3f'
                      % (nhan, truc, gia_tri, do_duoc))
        # Hiệu so với tâm chính là cột lệch giữa — đây là chỗ đọc ra DẤU.
        if f['my'] == 2:
            thua = y - (sh - h2) * 0.5 - ay * h2 * sy
            if abs(thua - f['o54']) < 0.01:
                ok += 1
            else:
                hong += 1
                print('  %-18s y-thua %.3f, o54 = %d' % (nhan, thua, f['o54']))
            print('  %-18s node %gx%g giua %.1f, do duoc %.1f, y-thua %+g'
                  ' | o50=%d o54=%d' % (nhan, w2, h2, (sh - h2) * 0.5, y,
                                        thua, f['o50'], f['o54']))
    return ok, hong


# Kiểm: kiểu 0 để yên, và đệ quy ------------------------------------------------

def kiem_kieu0():
    """Dựng lại `--kieu0`: đẩy node tới (−777,−888) rồi reflash cha.

    Ba mẫu, ba câu hỏi khác nhau:
      * btnEquipForgeUINavigation1 kiểu (1,1), scale 0,8 — kiểm kích thước ĐÃ
        co giãn trong công thức (không co giãn thì x ra 64,6 thay vì 56,6).
      * btnEquipForgeUINavigation2/3 kiểu X 0 — kiểm trục X ĐỂ YÊN (giữ −777),
        trong khi trục Y được đặt lại.
      * g_EquipForgeUIEffectSmaillIconBg là CHÁU — kiểm đệ quy: chỉ reflash
        lEquipmentForgeUI mà nó vẫn về đúng chỗ theo cha của nó (79x79).
    """
    print()
    print('=== kieu 0: de yen, va de quy xuong chau ===')
    dong = doc_fi('kieu0.log', 'k0')
    if not dong:
        return 0, 0
    du = {}
    for p in dong:
        if len(p) < 2:
            continue
        du[(p[0], p[1])] = p[2:]
    ten_file = 'UI_Equipment_960_640.xgg'
    x = nap(ten_file)
    tra_ten = tra(ten_file)
    f_cha = du.get(('sau', 'lEquipmentForgeUI'))
    if not f_cha:
        print('  thieu dong cha sau')
        return 0, 0
    pw, ph = so_thuc(f_cha[0]), so_thuc(f_cha[1])
    ok = hong = 0

    # Cha riêng của g_EquipForgeUIEffectSmaillIconBg: 79x79, không đổi trong
    # phép đo này — đó chính là điều làm phép kiểm đệ quy có nghĩa.
    cha_ten = 'nodeEquipmentUI_EffectSmaillIconBg'
    i_chau = tra_ten.get('g_EquipForgeUIEffectSmaillIconBg')
    if i_chau is None:
        print('  khong thay chau')
        return ok, hong
    i_cha_chau = tra_ten.get(cha_ten)
    if i_cha_chau is None:
        # Không có tên thì tìm theo cây: cha của cháu.
        cha = cha_cua(x).get(id(x.nodes()[i_chau]))
        i_cha_chau = x.nodes().index(cha) if cha is not None else None
    if i_cha_chau is None:
        print('  khong thay cha cua chau')
        return ok, hong
    wc, hc, _, _, _, _ = hinh_dang(x, i_cha_chau)
    print('  cha cua chau: %s %gx%g' % (cha_ten, wc, hc))

    for t in ('btnEquipForgeUINavigation1', 'btnEquipForgeUINavigation2',
              'btnEquipForgeUINavigation3',
              'g_EquipForgeUIEffectSmaillIconBg'):
        i = tra_ten.get(t)
        if i is None:
            print('  khong thay %s' % t)
            hong += 1
            continue
        do = du.get(('sau', t))
        day = du.get(('day', t))
        if not do or not day:
            print('  thieu so cho %s' % t)
            hong += 1
            continue
        f = fix_of(x, i)
        w, h, ax, ay, sx, sy = hinh_dang(x, i)
        if t == 'g_EquipForgeUIEffectSmaillIconBg':
            X, Y = cong_thuc(f, wc, hc, w, h, ax * w, ay * h, sx, sy)
        else:
            X, Y = cong_thuc(f, pw, ph, w, h, ax * w, ay * h, sx, sy)
        dxx, dyy = so_thuc(do[0]), so_thuc(do[1])
        for truc, gia_tri, do_duoc, da_day in (('x', X, dxx, so_thuc(day[0])),
                                               ('y', Y, dyy, so_thuc(day[1]))):
            if gia_tri is None:
                # Trục kiểu 0: phải GIỮ NGUYÊN số đã đẩy vào (−777 / −888).
                if abs(do_duoc - da_day) < 0.001:
                    ok += 1
                else:
                    hong += 1
                    print('  %-36s truc %s kieu 0 ma doi tu %g sang %g'
                          % (t, truc, da_day, do_duoc))
            elif abs(gia_tri - do_duoc) < 0.01:
                ok += 1
            else:
                hong += 1
                print('  %-36s truc %s: cong thuc %.3f, do duoc %.3f'
                      % (t, truc, gia_tri, do_duoc))
        i0 = '' if X is not None else ' (X kieu 0)'
        i1 = '' if Y is not None else ' (Y kieu 0)'
        print('  %-36s kieu=(%d,%d) scale=(%g,%g) -> %s%s / %s%s'
              % (t, f['mx'], f['my'], sx, sy,
                 ('%.1f' % dxx) if X is None else ('%.1f' % X), i0,
                 ('%.1f' % dyy) if Y is None else ('%.1f' % Y), i1))
    return ok, hong


# Kiểm: kiểu 2, kiểu 3, và ba cột đích còn lại -------------------------------

# Mẫu của `--kieu23`, đúng bảng `muc` trong `emu_pt.py`. Bên của cha lấy TỪ LOG,
# không lấy từ đây — bảng này chỉ nói node nào thuộc file nào.
MUC_K23 = [
    ('1', 'UI_Equipment_960_640.xgg', 'lEquipmentUI',
     ('btnHeroEquipUIToRight',)),
    ('2', 'UI_Equipment_960_640.xgg', 'lEquipUpgradeQualityMainUI',
     ('g_UpgradeQualityActionMaterialItem', 'g_UpgradeQualityActionBeginLayer')),
    ('3', 'UI_Equipment_960_640.xgg', 'g_UpgradeQualityActionBeginLayer',
     ('g_UpgradeQualityActionItemIcon',)),
    ('4', 'UI_AccountLogin_960_640.xgg', 'lNormalLoginUI', ('snsQuickEnter',)),
    ('5', 'UI_AccountLogin_960_640.xgg', 'g_LoginUIScene',
     ('btnLoginOpenProtocol', 'ttfLoginUISceneVer')),
    ('6', 'UI_AccountLogin_960_640.xgg', 'lLoginServerListUI',
     ('g_ServerNodesLayer',)),
    ('7', 'UI_Hero_960_640.xgg', 'lHeroInfoUILeft', ('lHeroInfoUIDetails',)),
    ('8', 'UI_COG_960_640.xgg', 'lCOGUI', ('lCUICOGMap',)),
]


def kiem_kieu23():
    """Dựng lại tám mẫu của `--kieu23`: kiểu 2, kiểu 3, và ba cột đích còn lại.

    Mẫu số 8 và số 2 là hai chỗ ĐÁNG GIÁ NHẤT: chúng phân biệt "hộp đã co giãn"
    với "hộp chưa co giãn" ở kiểu 2, và đó là chỗ mà hai chương trình (đo và
    kiểm) từng bất đồng. Nên in ra CẢ HAI cách đọc, kèm số điểm lệch — nếu chỉ
    in cách đọc đúng thì không ai thấy được phép kiểm này có sức mạnh gì.
    """
    print()
    print('=== kieu 2, kieu 3, cot dich o44/o4C/o50 ===')
    dong = doc_fi('kieu23.log', 'k23')
    if not dong:
        return 0, 0
    du = {}
    for p in dong:
        # p = (muc, nhan, ten, ...) — dòng cha chỉ có 5 trường (kèm bề rộng và
        # bề cao), dòng con có 7 (thêm x, y). Lọc theo >= 6 thì mất hết dòng cha
        # và cả tám mục đều báo "thiếu dòng cha" — đã bị đúng như vậy.
        if len(p) >= 5:
            du[(p[0], p[1], p[2])] = [so_thuc(v) for v in p[3:]]
    ok = hong = 0
    for k, ten_file, cha, con in MUC_K23:
        t = nap(ten_file)
        tra_ten = tra(ten_file)
        pt, ps = du.get((k, 'truoc', cha)), du.get((k, 'sau', cha))
        if not pt or not ps:
            print('  muc %s: thieu dong cha' % k)
            hong += 1
            continue
        print('  muc %s: %s %gx%g -> %gx%g' % (k, cha, pt[0], pt[1],
                                              ps[0], ps[1]))
        for ten in con:
            i = tra_ten.get(ten)
            if i is None:
                print('    khong thay %s trong %s' % (ten, ten_file))
                hong += 1
                continue
            f = fix_of(t, i)
            w, h, ax, ay, sx, sy = hinh_dang(t, i)
            for nhan, (pw, ph) in (('truoc', (pt[0], pt[1])),
                                   ('sau', (ps[0], ps[1]))):
                do = du.get((k, nhan, ten))
                if not do or len(do) < 2:
                    print('    muc %s %s %s: thieu so do' % (k, nhan, ten))
                    hong += 1
                    continue
                X, Y = cong_thuc(f, pw, ph, w, h, ax * w, ay * h, sx, sy)
                for truc, gia_tri, do_duoc in (('x', X, do[0]), ('y', Y, do[1])):
                    if gia_tri is None:
                        # Trục kiểu 0: công thức không nói gì, nhưng BẢN GHI thì
                        # nói — số trong trình sửa phải được giữ nguyên (đo
                        # được ở `--kieu0`). Ở đây chỉ bỏ qua và nói rõ.
                        continue
                    if abs(gia_tri - do_duoc) < 0.01:
                        ok += 1
                    else:
                        hong += 1
                        print('    muc %s %-6s %-34s truc %s: cong thuc %.3f,'
                              ' do duoc %.3f' % (k, nhan, ten, truc, gia_tri,
                                                 do_duoc))
            # Cách đọc "hộp ĐÃ co giãn ở kiểu 2" mà mẫu 8 và mẫu 2 phủ định.
            if f['mx'] == 2 or f['my'] == 2:
                g = dict(f)
                X2, Y2 = cong_thuc_scaled(g, pt[0], pt[1], w, h, ax * w, ay * h,
                                          sx, sy)
                X3, Y3 = cong_thuc_scaled(g, ps[0], ps[1], w, h, ax * w, ay * h,
                                          sx, sy)
                print('    %-34s k=(%d,%d) scale=(%g,%g) neo=(%g,%g)  '
                      'do duoc (%.1f, %.1f) / (%.1f, %.1f) | neu kieu 2 CO'
                      ' gian thi (%.1f, %.1f) / (%.1f, %.1f)'
                      % (ten, f['mx'], f['my'], sx, sy, ax, ay,
                         du[(k, 'truoc', ten)][0], du[(k, 'truoc', ten)][1],
                         du[(k, 'sau', ten)][0], du[(k, 'sau', ten)][1],
                         X2 if X2 is not None else -1, Y2 if Y2 is not None else -1,
                         X3 if X3 is not None else -1, Y3 if Y3 is not None else -1))
    return ok, hong


def cong_thuc_scaled(f, pw, ph, w, h, ax, ay, sx, sy):
    """Bản "kiểu 2 cũng co giãn" — chỉ dùng để ĐỐI CHỨNG, không phải luật.

    Giữ lại có chủ ý: đây là cách đọc sai đã từng nằm trong `emu_pt.py`, và
    `--kiem` in nó ra cạnh số đo để thấy nó sai bao nhiêu điểm. Không có nó thì
    lần sau lại có người "sửa" kiểu 2 về dạng co giãn cho đối xứng.
    """
    ws, hs = w * sx, h * sy
    axs, ays = ax * sx, ay * sy
    X = {0: None, 1: f['o40'] + axs,
         2: (pw - ws) * 0.5 + axs + f['o50'],
         3: pw - (ws - axs) - f['o44']}[f['mx']]
    Y = {0: None, 1: ph - (hs - ays) - f['o48'],
         2: (ph - hs) * 0.5 + ays + f['o54'],
         3: f['o4C'] + ays}[f['my']]
    return X, Y


# Kê toàn bộ -------------------------------------------------------------------

def lech():
    """Kể tên những node mà CÔNG THỨC đặt khác số đã lưu trong bản ghi.

    Đây là phép đo cho câu hỏi "reflash đổi cái gì". Bản ghi `.xgg` giữ x,y của
    người thiết kế, còn lúc chạy bản gốc gọi `sngFixInfoReflash` và ĐẶT LẠI theo
    công thức — nên chỗ nào hai bên lệch nhau thì đó đúng là những node bản gốc
    dịch khỏi vị trí trong file. Chạy ở CỠ THIẾT KẾ của cha (960x640 như trong
    .xgg), tức đúng cỡ mà bản port dùng khi cửa sổ engine đúng tỉ lệ 1,5.

    Sai số cho phép 0,01 điểm: các số trong bản ghi là số nguyên / nửa điểm, nên
    một nửa điểm là lệch thật chứ không phải làm tròn.

    `--lech <ten file>` để soi một màn, `--lech` trọn bộ để đếm.
    """
    import glob
    ten = sys.argv[2] if len(sys.argv) > 2 else None
    if ten:
        ds = [os.path.join(CONF, ten if ten.endswith('.xgg') else ten + '.xgg')]
        if not os.path.exists(ds[0]):
            raise SystemExit('khong thay %s' % ds[0])
    else:
        ds = sorted(glob.glob(os.path.join(CONF, '*.xgg')))
    print()
    print('=== node ma cong thuc dat khac so da luu (co thiet ke cua cha) ===')
    truc = 0
    nhom = {}
    for p in ds:
        try:
            x = xgg.load(p)
            nds = x.nodes()
        except xgg.XggError:
            continue
        d = cha_cua(x)
        for i, nd in enumerate(nds):
            f = fix_of(x, i)
            if not (f['mx'] or f['my']):
                # Cả hai kiểu 0: không trục nào được đặt lại.
                continue
            cha = d.get(id(nd))
            if cha is None:
                continue
            pw, ph = cha['w'], cha['h']
            w, h, axr, ayr, sx, sy = hinh_dang(x, i)
            X, Y = cong_thuc(f, pw, ph, w, h, axr * w, ayr * h, sx, sy)
            for nhan, tinh, luu in (('x', X, nd['x']), ('y', Y, nd['y'])):
                if tinh is None or abs(tinh - luu) <= 0.01:
                    continue
                truc += 1
                nhom['%s k=(%d,%d)' % (nhan, f['mx'], f['my'])] = \
                    nhom.get('%s k=(%d,%d)' % (nhan, f['mx'], f['my']), 0) + 1
                if ten:
                    print('  %-34s %-26s %s: luu %-9g cong thuc %-9g lech %g'
                          % (os.path.basename(p), nd.get('name') or '(khong ten)',
                             nhan, luu, tinh, tinh - luu))
    print('  %d truc lech' % truc)
    for k in sorted(nhom, key=lambda s: -nhom[s]):
        print('    %-16s %d' % (k, nhom[k]))
    return 0


def dem():
    """Bảng kê toàn bộ .xgg trong conf/.

    THỨ TỰ CỘT ĐÃ ĐÚNG (mx, my). Hai con số 2.622 và 2.302 ghi ở các lượt trước
    bị dán nhãn ngược vì đọc nhầm `<8i` từ +0x38: 2.622 là "kiểu X = 0, kiểu Y
    khác 0" (đúng như số ở dưới), còn 2.302 thì không phải kết quả của phép đếm
    nào ở đây cả — không dùng lại. Bảng (mx, my) ở dưới là số duy nhất đáng
    trích dẫn, và tổng các ô của nó khớp đúng số node.
    """
    import glob
    from collections import Counter
    tong = 0
    co_kieu = 0
    chi_y = 0       # mx == 0, my != 0
    chi_x = 0       # my == 0, mx != 0
    ca_hai_0 = 0
    o54_khac_0 = 0
    o54_goc_file = 0
    # Node phân biệt được "số hạng neo của kiểu 2 có nhân scale không": phải có
    # kiểu 2 trên một trục, neo KHÁC 0 và 0,5 (vì neo 0,5 thì (P−w)/2 + ax =
    # P/2 với mọi cách đọc), và scale khác 1. Đếm ở đây để con số "chưa đo được"
    # trong đầu file có chỗ dựa, không phải một câu nói suông.
    kieu2_neo_do = 0
    kieu2_neo_do_co_ten = 0
    bang = Counter()
    gia_tri_o54 = Counter()
    so_file = 0
    for d in sorted(glob.glob(os.path.join(CONF, '*.xgg'))):
        try:
            x = xgg.load(d)
            nds = x.nodes()
            G = x.offsets['G']
            offs = x.node_offsets()
        except Exception:
            continue
        so_file += 1
        # Node gốc của file = không node nào nhận nó làm con.
        #
        # PHẢI gọi `tree()` trước: `nodes()` KHÔNG gắn `children` — cây chỉ được
        # dựng khi gọi `tree()`. Thiếu dòng này thì `co_cha` rỗng và mọi node
        # đều ra "là lớp gốc của file" (đã bị đúng như vậy: 129/129).
        x.tree()
        co_cha = set()
        for nd in nds:
            for c in nd.get('children', []):
                co_cha.add(id(c))
        for i in range(len(nds)):
            t = struct.unpack_from('<8i', x.data, G + offs[i] + 0x38)
            mx, my = t[1], t[0]
            o50, o54 = t[6], t[7]
            tong += 1
            bang[(mx, my)] += 1
            if mx != 0 or my != 0:
                co_kieu += 1
            if mx == 0 and my == 0:
                ca_hai_0 += 1
            elif mx == 0:
                chi_y += 1
            elif my == 0:
                chi_x += 1
            if o54 != 0:
                o54_khac_0 += 1
                gia_tri_o54[o54] += 1
                if id(nds[i]) not in co_cha:
                    o54_goc_file += 1
            ax, ay = struct.unpack_from('<2f', x.data, G + offs[i] + 0x90)
            sx, sy = struct.unpack_from('<2f', x.data, G + offs[i] + 0x84)
            if ((mx == 2 and abs(ax) > 0.01 and abs(ax - 0.5) > 0.01
                 and sx != 1.0)
                    or (my == 2 and abs(ay) > 0.01 and abs(ay - 0.5) > 0.01
                        and sy != 1.0)):
                kieu2_neo_do += 1
                if nds[i].get('name'):
                    kieu2_neo_do_co_ten += 1
    print('=== bang ke toan bo .xgg trong conf/ ===')
    print('  so file doc duoc            : %d' % so_file)
    print('  so node                     : %d' % tong)
    print('  co it nhat mot kieu khac 0  : %d (%.1f%%)'
          % (co_kieu, 100.0 * co_kieu / tong if tong else 0))
    print('  ca hai kieu deu 0           : %d' % ca_hai_0)
    print('  chi Y  (mx=0, my!=0)        : %d' % chi_y)
    print('  chi X  (my=0, mx!=0)        : %d' % chi_x)
    print('  o54 khac 0                  : %d, trong do %d la lop goc cua file'
          % (o54_khac_0, o54_goc_file))
    print('  cac gia tri o54 khac 0      : %s'
          % ', '.join('%+d x%d' % (k, v) for k, v in
                      sorted(gia_tri_o54.items(), key=lambda p: -p[1])))
    print('  kieu 2 ma phan biet duoc so hang neo co nhan scale khong'
          ' (neo khac 0 va 0,5, scale khac 1): %d, trong do CO TEN: %d'
          % (kieu2_neo_do, kieu2_neo_do_co_ten))
    print()
    print('  bang (mx, my) — doc theo dong mx, cot my:')
    mys = sorted({k[1] for k in bang})
    print('        ' + ''.join('%8d' % m for m in mys) + '%10s' % 'tong')
    for mx in sorted({k[0] for k in bang}):
        hang = [bang[(mx, my)] for my in mys]
        print('  mx=%d ' % mx + ''.join('%8d' % v for v in hang)
              + '%10d' % sum(hang))


def in_node(ten_file, ten):
    x = nap(ten_file)
    i = tra(ten_file).get(ten)
    if i is None:
        print('khong thay node %s trong %s' % (ten, ten_file))
        return 1
    f = fix_of(x, i)
    n = x.nodes()[i]
    w, h = n['w'], n['h']
    print('%s / %s  lop %s  kieu %s' % (ten_file, ten, n['cls'],
                                        n['typeName']))
    print('  kieu X = %d, kieu Y = %d' % (f['mx'], f['my']))
    print('  cot: o40=%d o44=%d o48=%d o4C=%d o50=%d o54=%d'
          % (f['o40'], f['o44'], f['o48'], f['o4C'], f['o50'], f['o54']))
    print('  hinh: %gx%g anchor (%g,%g) scale (%g,%g)'
          % (w, h, n['anchorX'], n['anchorY'], n['scaleX'], n['scaleY']))
    print('  ban ghi trong trinh sua: (%g, %g)' % (n['x'], n['y']))
    cha = cha_cua(x).get(id(n))
    if cha is not None:
        print('  cha: %s %gx%g' % (cha.get('name'), cha['w'], cha['h']))
    return 0


def kiem_khoi():
    """Cột `fix` mà `xgg.py` ghi ra có đúng bằng đọc thô không.

    `xgg.py` đọc khối ở `+0x38` khi dựng `nodes()`, `layout.py` chuyển tiếp nó
    sang JSON cho Godot. Đó là hai đường MỚI, nên phải có một đường cũ để đối
    chiếu — chính `struct.unpack_from` của file này. Một lần lệch ở đây thì mọi
    node của mọi màn đều đặt sai chỗ khi lớp đổi cỡ, mà lại im lặng.

    Ngoài số khớp, phép đếm còn cho hai con số dùng để giải thích vì sao cột
    này chỉ có 85,3% node: 5.832 node có cả hai kiểu bằng 0, trong đó 928 node
    vẫn mang o khác 0 — khối không rỗng nhưng cũng không ai dùng.
    """
    print()
    print('=== cot fix cua xgg.py (duong xuat) doi chieu voi doc tho ===')
    ok = hong = 0
    tong = co = co_kieu = o_khi_kieu_0 = khong_khoi = 0
    for p in sorted(xgg.find_files(CONF)):
        try:
            x = xgg.load(p)
            G, offs = x.offsets['G'], x.node_offsets()
            nds = x.nodes()
        except xgg.XggError as e:
            print('  bo qua %s: %s' % (os.path.basename(p), e))
            continue
        for i, nd in enumerate(nds):
            tong += 1
            raw = list(struct.unpack_from('<8i', x.data, G + offs[i] + 0x38))
            co_xgg = nd.get('fix')
            if raw[0] or raw[1]:
                co_kieu += 1
            elif any(raw):
                o_khi_kieu_0 += 1
            if any(raw):
                co += 1
                if co_xgg == raw:
                    ok += 1
                else:
                    hong += 1
                    if hong <= 3:
                        print('  LECH %s %s: %s vs %s'
                              % (os.path.basename(p), nd.get('name'), co_xgg, raw))
            elif co_xgg is not None:
                khong_khoi += 1
                hong += 1
                if hong <= 3:
                    print('  THUA cot fix o %s %s (ca tam so deu 0)'
                          % (os.path.basename(p), nd.get('name')))
            else:
                khong_khoi += 1
    print('  %d node: %d node co khoi khac rong (%d co kieu khac 0, %d ca hai'
          ' kieu 0), %d node ca tam so 0 va khong ghi ra, khop %d, lech %d'
          % (tong, co, co_kieu, o_khi_kieu_0, khong_khoi, ok, hong))
    return ok, hong


def main():
    a = sys.argv[1:]
    if not a or a[0] == '--kiem':
        ok = hong = 0
        for f in (kiem_cong, kiem_o54, kiem_kieu0, kiem_kieu23):
            o, h = f()
            ok, hong = ok + o, hong + h
        print()
        print('khop %d, lech %d' % (ok, hong))
        return 1 if hong else 0
    if a[0] == '--khoi':
        ok, hong = kiem_khoi()
        return 1 if hong else 0
    if a[0] == '--lech':
        return lech()
    if a[0] == '--dem':
        dem()
        return 0
    if a[0] == '--in' and len(a) >= 3:
        return in_node(a[1], a[2])
    print(__doc__)
    return 2


if __name__ == '__main__':
    sys.exit(main())
