# -*- coding: utf-8 -*-
"""Hộp chạm của armature (`_lua_CollisionSize`) — bảng số sinh từ dữ liệu gốc.

    python cham_ref.py --json ../../bravecross-game/data_ref/cham_ref.json
    python cham_ref.py --do          # các phép đếm thô để đối chiếu
    python cham_ref.py --lech        # các rig mà khoá Collision KHÔNG đồng nhất
    python cham_ref.py --xem Hoplite
    python cham_ref.py --chon 10     # chọn rig đem đi đo trên máy ảo

CÔNG THỨC
---------
    hộp = (w·sx·|cos rot1| + h·sy·|sin rot1| ,
           h·sy·|cos rot2| + w·sx·|sin rot2|)

  * `w, h` là **`sourceSize` của bản ghi `.plist`** — cặp float thứ 12, 13 của
    bản ghi 60 byte (ở `+0x34`), `sngxml.py` đọc ra dưới tên `sourceSize`.
  * `sx, sy, rot1, rot2` là khoá của xương `Collision` (`rot1` ở `+0x10`, `rot2`
    ở `+0x14` của bản ghi khung 80 byte).
  * `rot` tính bằng ĐỘ, và phải lấy **|cos|** chứ không phải `cos`: `CaoCao` /
    `ZhangLiaoDog` / `ShenHaiZhangYu` đặt `rot2 = 180` (một cờ lật), để nguyên
    dấu thì bề cao ra ÂM. Với `rot = 0` công thức rút về `w·sx, h·sy`.
  * Hộp bao của hình chữ nhật quay góc `t` đúng là `W·|cos t| + H·|sin t|` —
    công thức hình học thường, không phải số học đặt riêng cho việc này.

NGUỒN KHUNG ẢNH — chỗ tài liệu này TỪNG SAI, và cách phát hiện
--------------------------------------------------------------
Bản ghi sprite của `.xml` (mảng ở header 0x60, bản ghi 40 byte, `+0x08`) cũng
khai một cặp `(w,h)`, và bản đầu của tài liệu này kết luận "bản gốc đọc theo
`.xml`" — **sai**. Lý do sai: `.plist` có **BA** cặp cỡ chứ không phải một
(`work/khung_nguon.py` in ra ba cặp ấy):

    f2,f3   = khung ĐÃ CẮT trong atlas        (`sizeWH`)
    f9,f10  = LẶP LẠI y hệt `sizeWH`          (đo: 13.634/13.634 khung)
    f11,f12 = `sourceSize`, khung TRƯỚC KHI CẮT

Phép đối chiếu cũ lấy nhầm cặp ĐÃ CẮT (`Hoplite_res-44`: 1×1), thấy nó khác
`.xml` (3×3) mà máy ảo lại trả 3 × 54,52 — nên tưởng là theo `.xml`. Nhưng
`sourceSize` của chính ảnh ấy **cũng là 3×3**: hai nguồn bằng nhau, phép đo ấy
không phân biệt được gì.

Ba phép đo phân biệt được, và đều nói **`sourceSize`**:

    rig               | đo được               | theo sourceSize     | theo .xml
    ------------------|-----------------------|---------------------|----------------
    BatFlight         | 145,00999450684 × 120 | 1 × 145,01 = 145,01 | 2 × 145,01 = 290,02
    DragonFlight      | 175 × 145             | 1 × 175             | 2 × 175 = 350
    DragonFlight Head | 64 × 64               | 64 × 64             | 65 × 64

Hai phép đầu lệch **hẳn một hệ số 2** (`.xml` khai 2×2 cho ảnh `_res-44` còn
`sourceSize` khai 1×1); phép thứ ba lệch đúng 1 điểm ảnh. Cả ba rig ấy **chưa
từng được đo** trước lượt `emu_xuong.py`. Ảnh hưởng trên bảng: đúng **2 trong
224** rig mang tên file có hộp chạm sai ở bảng cũ (`BatFlight`, `DragonFlight`),
222 rig còn lại không đổi một số nào.

CÁCH TÌM RA
-----------
Bảng bind của lớp armature nằm ở `.data` 0x937350 (**95** bản ghi 12 byte, KHÔNG
nằm trong 132 lớp của `binder.py`); bản ghi của `_lua_CollisionSize` trỏ tới
`0x2ab932` (Thumb, bit 0 đã bật), và thân hàm ấy đọc hai float ở `[sp+8]` và
`[sp+0xc]` rồi `lua_pushnumber` hai lần — một CẶP số, không phải một số. Nó gọi
`0x2ab860`, mà `.symtab` gọi đúng tên
`std::map<int, CDFColliderBoneInfo>::operator[]` (`0x2ab7e4` là
`_Rb_tree::_M_insert_unique`) — tức cặp số nằm trong một bản ghi
`CDFColliderBoneInfo` gắn trên chính armature ở `+0x27c`, khoá `0`. Đọc mã chỉ
cho biết đến thế; cặp số NGHĨA LÀ GÌ thì phải đo.

Con số **95** là đếm lại chứ không phải số cũ: bảng kết thúc ở `0x9377c4` (ba
word 0), và ngay trước `0x937350` cũng là ba word 0 (`0x937344`) — nên bảng này
liền một mạch 95 dòng. (Bản ghi "81" trong tài liệu trước đây là do vòng lặp đọc
tự cắt ở `range(81)`, không phải bảng ngắn hơn.) Đuôi bảng đáng chú ý: có
`_ShowShadow` (`0x419f75`), `_Lua_addStarLevelEffect` (`0x41ba6d`), `_lua_setOpacity`,
`_lua_openColorOverlay`, `setIsOpenDetection` — tức bảng bind này phủ cả phần
bóng đổ mà `battle/bong_ref.gd` đang mô phỏng. Có thêm một bảng **gần trùng** ở
`0x937f28` (93 dòng, giống 92 dòng đầu của bảng kia, chỉ khác dòng `setPosition`:
`0x3672c7` so với `0x41ba6d`) — chưa tra ra lớp nào dùng nó, ghi lại để đừng
tưởng là một bảng duy nhất.

BẢY PHÉP ĐO TRÊN MÁY ẢO (`emu_cham.py`, bản gốc chạy trong Android)

    | rig              | w,h | sx, sy         | rot1, rot2   | tính        | đo được         |
    |------------------|-----|----------------|--------------|-------------|-----------------|
    | Hoplite          | 3,3 | 54,52  54,4    | 0      0     | 163,5599976 | 163,55999755859 |
    | ElephantSoldier  | 3,3 | 56,84  39,5    | 0      0     | 170,5200043 | 170,52000427246 |
    | BaiHuZi          | 2,2 | 160    152,5   | 0      0     | 320         | 320             |
    | ZhangLiangBao    | 1,1 | 175    227,5   | 0      0     | 175         | 175             |
    | YuJin            | 1,1 | 139,88 179,84  | -0,04  -0,06 | 140,00552   | 140,00547790527 |
    | MaYuanYi         | 1,1 | 254,39 189,49  | -0,08  -0,03 | 254,65454   | 254,65454101562 |
    | GongSunZan       | 1,1 | 139,89 184,86  |  0,04   0,06 | 140,01898   | 140,01898193359 |

ĐỘ CHÍNH XÁC — nói đúng mức, không nói quá
------------------------------------------
  * **`rot = 0`: khớp từng bit.** Bốn rig `Hoplite`, `ElephantSoldier`,
    `BaiHuZi`, `ZhangLiangBao` lệch **≤ 4e-12** — tức chỉ còn sai số biểu diễn
    float32, không phải sai số công thức.
  * **`rot = 180`: cũng khớp từng bit**, và đây là lý do: `|cos 180°| = 1`,
    `|sin 180°| = 0`, nên công thức THOÁI HOÁ thành phép nhân `h·sy` và `w·sx`
    — không có đường lượng giác nào được dùng. Quét cả 592 biến thể thì **chỉ
    có đúng ba giá trị góc** xuất hiện: `0`, `180`, và ba rig nhỏ dưới đây —
    nên **589/592 biến thể rơi vào hai ca khớp bit**, chỉ **3/592** thật sự đi
    qua `sin`/`cos` ở góc khác 0.
  * **Góc nhỏ khác 0: LỆCH, và chưa giải thích được.** Ba rig `YuJin`,
    `MaYuanYi`, `GongSunZan` (|rot| ≤ 0,08°) lệch tối đa **2,2e-4 điểm ảnh**
    (1,3e-6 tương đối). Đã thử mô hình hoá phần lệch này (coi như sai số của
    chính GÓC: suy ngược góc hiệu dụng từ số đo) và **nó không theo một luật
    nào** — cùng một rig, `rot1` lệch +8,0e-4 tương đối còn `rot2` lệch −1,2e-3;
    hai rig cùng |rot| = 0,04° thì lệch cùng độ lớn nhưng **ngược dấu** trong
    khi `rot1` của chúng cùng dấu. Ghi lại là CHƯA RÕ, không gán cho một nguyên
    nhân nào. Ảnh hưởng trong game: dưới 0,0002 điểm ảnh, không nhìn thấy được.

Hai ca `MaYuanYi` và `GongSunZan` chốt **cặp trục**: đổi vai `rot1`/`rot2` cho ra
254,489 × 189,845 và 140,084 × 184,958 — lệch **0,165 và 0,065 điểm ảnh**, tức
lớn hơn hẳn phần lệch chưa giải thích ở trên (2,2e-4) khoảng **300 lần**, nên
phép thử này phân biệt được thật chứ không phải đang cân nhiễu.

Còn `|cos|` thì **không** dựa vào một phép đo trực tiếp: máy ảo chưa lần nào đo
một rig `rot = 180`. Căn cứ là hình học — hộp bao của một hình chữ nhật không
thể có cạnh ÂM, mà để nguyên dấu thì `CaoCao` ra `100 × −189,99`.

`(0, 0)` khi armature không có xương `Collision`: đo trên `DaQuZhanShi`
(`getContentSize` của nó là 104,78 × 123,24, tức **KHÔNG** phải cùng một đại
lượng — trùng nhau ở mấy rig đầu chỉ là trùng ngẫu nhiên, ghi lại vì đã có lần
kết luận nhầm là bằng nhau).

TÍNH MỘT LẦN hay THEO TỪNG KHUNG — **KHÔNG PHÂN BIỆT ĐƯỢC**, và vì sao
--------------------------------------------------------------------
Quét cả 418 file: khoá 0 của `Collision` **giống nhau ở mọi động tác** trong
**223/224** rig. Rig duy nhất khác là `ZhangLiangBao`, và khác có **0,01 điểm
ảnh** (`Death`/`Hit`/`Wake` = 227,49000549316406; `Fight`/`Fight2`/`Standby`/
`Walk` = 227,5). Đo trên máy ảo: dựng `ZhangLiangBao` rồi `_Lua_playAnimation`
sang `Hit`, `Death`, `Fight2`, `Standby` — **cả bốn lần đều trả 175 × 227,5**.
Nhưng phép ĐỐI CHỨNG đi kèm lại ÂM: `_lua_getBonePosInNode("Collision")` trả y
nguyên `-88, 227` qua cả bốn động tác, tức không chứng minh được `playAnimation`
kịp có tác dụng trong cùng một đoạn Lua — nên "227,5 cả bốn lần" **không** kết
luận được là hộp tính một lần.

Nên bảng dùng luật: **khoá 0 của động tác ĐẦU TIÊN có xương `Collision`** trong
biến thể mang tên file. Luật này tái tạo đúng mọi phép đo hiện có (kể cả
`ZhangLiangBao`: động tác đầu là `Standby`, 227,5), và trong 223 rig còn lại thì
mọi luật khác đều cho cùng số. Giới hạn còn lại đúng 0,01 điểm ảnh trên 1 trong
224 rig.

BA PHÉP ĐẾM ĐỘC LẬP (đối chiếu bảng sinh ra, không cần máy ảo)
---------------------------------------------------------------
  * 418 file `.xml`; 224 có xương `Collision` ở biến thể mang tên file; 592
    biến thể có xương ấy nếu tính cả armature lồng nhau.
  * **0** file có hai bản ghi sprite TRÙNG TÊN mà khác cỡ — nên "tên → (w,h)"
    là ánh xạ hàm, tra được.
  * Cỡ khung của xương `Collision`: 1×1 ở 146 rig, 4×4 ở 32, 3×3 ở 21, 2×2 ở
    19, rồi lẻ tẻ 5×5, 7×7, 8×8, 10×10. (Số `w,h` này là hệ số nhân: `Archer`
    3×3 với `sx = 18` cho hộp 54 × 99.)

HAI CÁI BẪY ĐÃ MẮC
-------------------
  * `Collision` và `Collision_1` là HAI xương khác nhau. `ElephantSoldier`,
    `ADou01`, `ArmorCavalry` có cả hai với cỡ khác hẳn (3 × 56,84/39,5 so với
    3 × 17,6/35,6 ở ElephantSoldier). Gộp cả hai lại thì ra "2 khoá trong một
    động tác khác nhau" — một cái bẫy tự tạo. Bản gốc trả về của `Collision`;
    đo được: ElephantSoldier ra 170,52 × 118,5, tức bộ 56,84/39,5.
  * Một file `.xml` chứa NHIỀU armature. `ZhangLiangBao_ZhangLiang`,
    `CaoCao_WeaponWake`, `DaQiaoReplica`… là những hình tượng RIÊNG, cỡ riêng.
    Đếm gộp cả file thì ra "114 rig có khoá 0 khác nhau" — con số vô nghĩa.
    Tính theo từng biến thể: **1**.
"""
import argparse
import collections
import glob
import io
import json
import math
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import anim                                            # noqa: E402

MAP = os.path.join(HERE, 'vn', 'decrypted', 'assets', 'map')
ANIM_REC = 0x28


def _f32(x):
    """Ép về float32 rồi trả lại double — đúng đường đi của engine."""
    return struct.unpack('<f', struct.pack('<f', x))[0]


def hop(w, h, rot1, rot2, sx, sy):
    """Hộp bao của khung ảnh (w·sx, h·sy) sau khi xoay (rot1, rot2) độ.

    Hộp bao của một hình chữ nhật quay góc `t` là `W·|cos t| + H·|sin t|` —
    công thức hình học thường, và cũng đúng cho góc tù (`|cos|` chứ không phải
    `cos`: `CaoCao` có `rot2 = 180`, để nguyên dấu thì ra bề cao ÂM).
    """
    a1, a2 = math.radians(rot1), math.radians(rot2)
    rong = _f32(_f32(w * sx) * abs(math.cos(a1)) + _f32(h * sy) * abs(math.sin(a1)))
    cao = _f32(_f32(h * sy) * abs(math.cos(a2)) + _f32(w * sx) * abs(math.sin(a2)))
    return rong, cao


def kich_thuoc_nguon(plist_path):
    """tên sprite -> `sourceSize` của bản ghi `.plist` (cặp float thứ 12, 13).

    Đây mới là khung mà engine dùng (xem docstring đầu file). Tên trong `.plist`
    có đuôi `.png`, còn tên trong `.xml` thì không — bỏ đuôi khi trả về.
    """
    d = open(plist_path, 'rb').read()
    if d[:6] != b'sngXml':
        return None
    count = struct.unpack_from('<I', d, 0x10)[0]
    off_recs = struct.unpack_from('<I', d, 0x38)[0]
    off_pool = struct.unpack_from('<I', d, 0x3c)[0]
    if not count or not off_recs:
        return None
    stride = (off_pool - off_recs) // count
    if stride < 60:
        return None
    ra = {}
    for i in range(count):
        b = off_recs + i * stride
        f = struct.unpack_from('<13f', d, b + 8)
        no, nl = struct.unpack_from('<II', d, b)
        nm = d[off_pool + no:off_pool + no + nl].decode('utf-8', 'replace')
        ra[nm[:-4] if nm.endswith('.png') else nm] = (f[11], f[12])
    return ra


class Rig(object):
    """Một file .xml đọc ra đủ thứ cần cho hộp chạm."""

    def __init__(self, path):
        self.duong_dan = path
        self.ten = os.path.basename(path)[:-4]
        self.a = anim.Anim(open(path, 'rb').read(), self.ten)
        self._nguon = False              # chua doc; None = khong co .plist

    def kich_thuoc_nguon_sprite(self):
        """tên sprite -> (w,h) mà ENGINE dùng, đọc từ `.plist` cùng thư mục.

        Không có `.plist` (hoặc tên ảnh vắng trong đó) thì lui về bản ghi
        `.xml` — hai nguồn chỉ lệch ở 4.173/13.601 ảnh, và ở **2/224** rig thì
        lệch ấy đổi hẳn hộp chạm.
        """
        if self._nguon is False:
            pl = os.path.join(os.path.dirname(self.duong_dan), self.ten + '.plist')
            self._nguon = kich_thuoc_nguon(pl) if os.path.isfile(pl) else None
        if self._nguon is None:
            return self.kich_thuoc_sprite()
        ra = dict(self.kich_thuoc_sprite())
        ra.update(self._nguon)
        return ra

    def kich_thuoc_sprite(self):
        """tên sprite -> (w, h) của bản ghi trong .xml (mảng ở header 0x60)."""
        a, ra = self.a, {}
        for i in range(a.u(0x40)):
            q = a.spr_base + i * 0x28
            ra[a._name_at(q)] = struct.unpack_from('<2f', a.d, q + 8)
        return ra

    def anh_cua_xuong(self):
        """tên xương -> danh sách tên ảnh (bản ghi bộ phận cùng tên, header 0x4c)."""
        a, ra = self.a, {}
        for i in range(a.u(0x20)):
            r = a.part_base + i * 0x10
            sub_off, sub_n = a.u(r + 8), a.u(r + 0xc)
            for k in range(sub_n):
                q = a.part_sub + sub_off + k * 0x10
                ra[a._name_at(q)] = a.sprite_refs(a.u(q + 8), a.u(q + 0xc))
        return ra

    def moi_bien_the(self):
        """Tên MỌI biến thể trong file (armature lồng nhau cũng là biến thể)."""
        a = self.a
        return [a._name_at(a.grp_base + gi * 0x10) for gi in range(a.u(0x28))]

    def _bien_the(self, ten):
        a = self.a
        for gi in range(a.u(0x28)):
            r = a.grp_base + gi * 0x10
            if a._name_at(r) == ten:
                return (r, a.u(r + 8), a.u(r + 0xc))
        return None

    def bien_the_chinh(self):
        """Biến thể nhiều động tác nhất — cùng luật `SngRig._richest_variant`."""
        a, best, bestn = self.a, None, -1
        for gi in range(a.u(0x28)):
            r = a.grp_base + gi * 0x10
            n = a.u(r + 0xc)
            if n > bestn:
                bestn, best = n, (r, a.u(r + 8), n)
        return best

    def bien_the_theo_ten(self):
        """Biến thể MANG TÊN FILE — đó là thứ `getSpriteFromSpriteCatch(<tên>)`
        dựng ra. Không có thì lấy biến thể nhiều động tác nhất.

        Phân biệt này quan trọng: một file `.xml` chứa NHIỀU armature (biến thể
        `ZhangLiangBao_ZhangLiang`, `CaoCao_WeaponWake`… là những hình tượng
        riêng, cỡ riêng). Đếm gộp cả file thì ra "114 rig có khoá 0 khác nhau",
        nhưng con số ấy vô nghĩa — khác nhau giữa các BIẾN THỂ là đương nhiên.
        """
        return self._bien_the(self.ten) or self.bien_the_chinh()

    def _xuong_cham(self, ar):
        """Địa chỉ bản ghi xương `Collision` trong một động tác, hoặc -1.

        Ưu tiên ĐÚNG tên `Collision`: `ElephantSoldier` / `ADou01` /
        `ArmorCavalry` có thêm xương `Collision_1` với cỡ khác hẳn, mà bản gốc
        chỉ trả về một cặp — đo được là của `Collision` (ElephantSoldier:
        170,52 × 118,5 = 3 × 56,84/39,5, không phải 3 × 17,6/35,6).
        """
        a, dung, gan = self.a, -1, -1
        for bi in range(a.u(ar + 0x24)):
            bp = a.bone_base + a.u(ar + 0x20) + bi * 24
            bn = a._name_at(bp)
            if bn == 'Collision':
                return bp
            if bn.startswith('Collision') and gan < 0:
                gan = bp
        return gan

    def khoa_cham(self, bien_the=None, dong_tac=None):
        """Khoá của xương `Collision` trong một động tác.

        Trả về dict, hoặc None nếu armature không có xương ấy. `bien_the` là
        TÊN biến thể (bỏ trống = biến thể mang tên file, xem
        `bien_the_theo_ten`), `dong_tac` là tên động tác (bỏ trống = động tác
        đầu tiên có xương).
        """
        a = self.a
        bt = self.bien_the_theo_ten() if bien_the is None else self._bien_the(bien_the)
        if bt is None:
            return None
        r, sub_off, sub_n = bt
        ten_bt = a._name_at(r)
        for k in range(sub_n):
            ar = a.grp_sub + sub_off + k * ANIM_REC
            nm = a._name_at(ar)
            if dong_tac is not None and nm != dong_tac:
                continue
            bp = self._xuong_cham(ar)
            if bp < 0:
                continue
            ra = []
            for j in range(a.u(bp + 0x14)):
                q = a.key_base + a.u(bp + 0x10) + j * 80
                v = struct.unpack_from('<8f', a.d, q)
                ra.append(dict(x=v[0], y=v[1], rot=v[4], rot2=v[5],
                               sx=v[6], sy=v[7],
                               d=struct.unpack_from('<i', a.d, q + 0x2C)[0],
                               dur=struct.unpack_from('<i', a.d, q + 0x40)[0]))
            return dict(bien_the=ten_bt, dong_tac=nm, xuong=a._name_at(bp), keys=ra)
        return None

    def moi_khoa_cham(self, bien_the=None):
        """MỌI khoá `Collision` của MỌI động tác trong MỘT biến thể — để xem
        khoá có đổi theo động tác không (câu hỏi 'hộp tính lúc nạp hay theo
        từng khung')."""
        a = self.a
        bt = self.bien_the_theo_ten() if bien_the is None else self._bien_the(bien_the)
        if bt is None:
            return []
        r, sub_off, sub_n = bt
        ra = []
        for k in range(sub_n):
            ar = a.grp_sub + sub_off + k * ANIM_REC
            bp = self._xuong_cham(ar)
            if bp < 0:
                continue
            for j in range(a.u(bp + 0x14)):
                q = a.key_base + a.u(bp + 0x10) + j * 80
                v = struct.unpack_from('<8f', a.d, q)
                ra.append((a._name_at(bp), a._name_at(ar), j, v[4], v[5], v[6], v[7]))
        return ra

    def ho_cham(self, **kw):
        """Hộp chạm của động tác đầu tiên có xương `Collision`, hoặc None."""
        k = self.khoa_cham(**kw)
        if k is None:
            return None
        anh = self.anh_cua_xuong().get(k['xuong'], [])
        sz = self.kich_thuoc_nguon_sprite()
        keys = k['keys']
        # Khung ảnh của xương: chỉ số `d` của khoá trỏ vào danh sách ảnh của
        # xương, chứ không phải vào mảng sprite toàn cục.
        d = keys[0]['d']
        ten_anh = anh[d] if 0 <= d < len(anh) else ''
        w, h = sz.get(ten_anh, (0.0, 0.0))
        rong, cao = hop(w, h, keys[0]['rot'], keys[0]['rot2'],
                        keys[0]['sx'], keys[0]['sy'])
        ra = dict((kk, vv) for kk, vv in k.items() if kk != 'keys')
        ra.update(ten_anh=ten_anh, w=w, h=h,
                  rot=keys[0]['rot'], rot2=keys[0]['rot2'],
                  sx=keys[0]['sx'], sy=keys[0]['sy'], rong=rong, cao=cao)
        return ra


def tat_ca():
    for p in sorted(glob.glob(os.path.join(MAP, '*.xml'))):
        try:
            yield Rig(p)
        except Exception:
            continue                       # *_config.xml khong phai file rig


def lenh_do():
    """Vài phép đếm thô để đối chiếu bảng sinh ra, không cần máy ảo."""
    n_file = n_cham = n_rot = n_w1 = 0
    wh = collections.Counter()
    trung = 0
    nhieu_khoa = 0        # rig co dong tac mang >1 khoa Collision
    lech_trong_rig = 0    # rig ma cac khoa Collision KHONG giong nhau
    lech_khoa_0 = 0       # rig ma khoa 0 cua cac dong tac KHONG giong nhau
    khac_bien_the = 0     # rig ma "bien the nhieu dong tac nhat" KHAC ten file
    for r in tat_ca():
        n_file += 1
        # Ten sprite trung nhau trong CUNG mot file: chi nguy hiem khi kich thuoc
        # khac nhau, vi luc do "ten -> (w,h)" khong con la anh xa ham.
        if len(r.kich_thuoc_sprite()) != r.a.u(0x40):
            trung += 1
        if r.bien_the_chinh()[0] != r.bien_the_theo_ten()[0]:
            khac_bien_the += 1
        h = r.ho_cham()
        if h is None:
            continue
        n_cham += 1
        wh[(h['w'], h['h'])] += 1
        if h['rot'] or h['rot2']:
            n_rot += 1
        if (h['w'], h['h']) == (1.0, 1.0):
            n_w1 += 1
        mk = r.moi_khoa_cham()
        # Trong MOT bien the: gop theo (XUONG, dong tac) chu KHONG phai chi theo
        # dong tac. `ElephantSoldier` co hai xuong `Collision` va `Collision_1`
        # voi hai co khac han — gop lai thi tuong nham la "khoa doi theo khung".
        if any(y[2] > 0 for y in mk):
            nhieu_khoa += 1
        theo_dt = {}
        for ten_xuong, ten_dt, j, r1, r2, sx, sy in mk:
            theo_dt.setdefault((ten_xuong, ten_dt), []).append((r1, r2, sx, sy))
        if any(len(set(v)) > 1 for v in theo_dt.values()):
            lech_trong_rig += 1
        if len(set(v[0] for v in theo_dt.values())) > 1:
            lech_khoa_0 += 1
    print('file .xml doc duoc            : %d' % n_file)
    print('  bien the mang ten file co xuong Collision: %d' % n_cham)
    print('  khung anh 1x1               : %d' % n_w1)
    print('  co rot khac 0               : %d' % n_rot)
    print('  ten sprite trung khac co    : %d' % trung)
    print('  dong tac mang >1 khoa       : %d' % nhieu_khoa)
    print('  khoa TRONG mot dong tac khac nhau: %d' % lech_trong_rig)
    print('  khoa 0 KHAC nhau giua cac dong tac: %d' % lech_khoa_0)
    # Con so nay KHAC han con so cua `--bien-the`, dung de lan: no dem ca nhung
    # file ma ten thu muc KHONG phai mot bien the (`Player000.xml` chi co cac
    # nhom `Player000W03W`...), tuc la `bien_the_theo_ten()` phai lui ve nhom
    # nhieu dong tac nhat — truong hop ay KHONG phai chon sai. Con so noi len
    # viec chon sai la cua `--bien-the` (45, trong do 12 doi hop cham).
    print('  nhom nhieu dong tac nhat khac bien the THEO TEN (ke ca ten file '
          'khong phai bien the): %d' % khac_bien_the)
    print('kich thuoc khung anh cua xuong Collision:')
    for (w, h), n in sorted(wh.items(), key=lambda x: -x[1]):
        print('   %5g x %-5g  %d' % (w, h, n))


def lenh_lech():
    """Liệt kê đúng những rig mà khoá `Collision` KHÔNG giống nhau — đây là
    nhóm quyết định câu hỏi 'hộp tính lúc nạp hay theo từng khung'."""
    for r in tat_ca():
        mk = r.moi_khoa_cham()
        if not mk:
            continue
        theo_dt = {}
        for ten_xuong, ten_dt, j, r1, r2, sx, sy in mk:
            theo_dt.setdefault((ten_xuong, ten_dt), []).append((r1, r2, sx, sy))
        trong = sorted(k for k, v in theo_dt.items() if len(set(v)) > 1)
        giua = sorted(set(v[0] for v in theo_dt.values()))
        if not trong and len(giua) <= 1:
            continue
        print('=== %s' % r.ten)
        if len(giua) > 1:
            print('   khoa 0 khac nhau giua cac (xuong, dong tac): %d gia tri' % len(giua))
            for g in giua:
                co = sorted(k for k, v in theo_dt.items() if v[0] == g)
                print('      %-40s %s' % (g, ', '.join('%s/%s' % c for c in co[:6])))
        for k in trong:
            print('   khoa TRONG %s/%s khac nhau: %s' % (k[0], k[1], theo_dt[k]))


def lenh_bien_the():
    """Đếm xem việc CHỌN BIẾN THỂ có làm đổi kết quả không.

    Bản dựng chọn nhóm nhiều động tác nhất, khi bằng nhau thì lấy nhóm ĐẦU TIÊN.
    Lệnh này in ra ba con số dùng để biện luận cho `--bien-the` của bản dựng
    (`SngRig._bien_the_cho`, đo trên máy ảo ở `emu_cham.py` mục F):

      * biến thể mang tên file nằm ở đâu trong danh sách nhóm;
      * bao nhiêu rig có biến thể mang tên file VÀ nó khác nhóm nhiều động tác
        nhất — tức cách chọn cũ chọn sai;
      * trong đó bao nhiêu rig mà hộp chạm KHÁC HẲN nhau giữa hai biến thể, tức
        cách chọn cũ cho ra số sai (hoặc (0, 0)).
    """
    n_file = n_trung_ten = n_cuoi = n_lech = 0
    doi = []
    for r in tat_ca():
        gs = r.a.groups()
        if not gs:
            continue
        n_file += 1
        names = [g['variant'] for g in gs]
        if r.ten not in names:
            continue                       # ten thu muc khong phai mot bien the
        n_trung_ten += 1
        if names[-1] == r.ten:
            n_cuoi += 1
        best = max(gs, key=lambda g: len(g['animations']))['variant']
        if best == r.ten:
            continue
        n_lech += 1
        a, b = r.ho_cham(bien_the=r.ten), r.ho_cham(bien_the=best)
        cap = ((a['rong'], a['cao']) if a else None,
               (b['rong'], b['cao']) if b else None)
        if cap[0] != cap[1]:
            doi.append((r.ten, names.index(r.ten), len(names), best, cap))
    print('file .xml co nhom dong tac      : %d' % n_file)
    print('  ten file LA mot bien the      : %d' % n_trung_ten)
    print('  trong do bien the ay nam CUOI : %d' % n_cuoi)
    print('  nhung no KHAC nhom nhieu dong tac nhat: %d' % n_lech)
    print('  trong do hop cham DOI HAN: %d' % len(doi))
    for ten, i, n, best, (a, b) in doi:
        print('   %-22s nhom %d/%d -> %-26s ten file %-24s richest %s'
              % (ten, i + 1, n, best, a, b))


def lenh_xem(ten):
    r = Rig(os.path.join(MAP, ten + '.xml'))
    print('=== %s' % ten)
    k = r.khoa_cham()
    if k is None:
        print('   khong co xuong Collision o bien the mang ten file')
    else:
        print('   bien the %s | dong tac %s | xuong %s | %d khoa'
              % (k['bien_the'], k['dong_tac'], k['xuong'], len(k['keys'])))
        for kk in k['keys']:
            print('      x %g y %g rot %g rot2 %g sx %g sy %g d %d dur %d'
                  % (kk['x'], kk['y'], kk['rot'], kk['rot2'],
                     kk['sx'], kk['sy'], kk['d'], kk['dur']))
    h = r.ho_cham()
    if h is not None:
        print('   anh %s (w,h = %g,%g) -> hop %g x %g'
              % (h['ten_anh'], h['w'], h['h'], h['rong'], h['cao']))
    # Moi dong tac co xuong Collision, de xem khoa co doi theo dong tac khong.
    for ten_xuong, ten_dt, j, r1, r2, sx, sy in r.moi_khoa_cham():
        print('   %-22s %-14s khoa %d: sx %g sy %g rot %g rot2 %g'
              % (ten_dt, ten_xuong, j, sx, sy, r1, r2))


def lenh_chon(n=6):
    """Chọn rig đem đi đo trên máy ảo: ưu tiên rot khác 0 và w,h khác 1."""
    ung = []
    for r in tat_ca():
        h = r.ho_cham()
        if h is None or not h['ten_anh']:
            continue
        la = abs(h['rot']) + abs(h['rot2'])
        ung.append((la, (h['w'], h['h']) != (1.0, 1.0), r.ten, h))
    ung.sort(key=lambda x: (-x[0], not x[1], x[2]))
    print('%-18s %-16s %-14s %-24s %s' % ('ten', 'bien the', 'dong tac',
                                         'anh (w,h)', 'hop du doan'))
    for la, kw, ten, h in ung[:n]:
        print('%-18s %-16s %-14s %-24s %g x %g'
              % (ten, h['bien_the'], h['dong_tac'],
                 '%s (%g,%g)' % (h['ten_anh'], h['w'], h['h']), h['rong'], h['cao']))
    print()
    print('co rot khac 0: %d | khung anh khac 1: %d | tong: %d'
          % (sum(1 for u in ung if u[0] > 0),
             sum(1 for u in ung if u[1]), len(ung)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--json', metavar='DUONG_DAN')
    ap.add_argument('--do', action='store_true')
    ap.add_argument('--lech', action='store_true')
    ap.add_argument('--bien-the', action='store_true')
    ap.add_argument('--xem', metavar='TEN')
    ap.add_argument('--chon', type=int, nargs='?', const=6)
    a = ap.parse_args()
    # Phai doi stdout sang utf-8: khong co dong nay thi `print(__doc__)` chet
    # tren Windows (cp1252) ngay tai chu co dau dau tien — ma chet o DUONG HUONG
    # DAN, tuc la go sai mot tham so thi khong doc duoc cach dung.
    sys.stdout.reconfigure(encoding='utf-8')
    if a.do:
        lenh_do()
    if a.lech:
        lenh_lech()
    if a.bien_the:
        lenh_bien_the()
    if a.xem:
        lenh_xem(a.xem)
    if a.chon is not None:
        lenh_chon(a.chon if a.chon else 6)
    if a.json:
        # Khoá theo TÊN BIẾN THỂ, vì biến thể mới là thứ `SngRig` dựng ra và
        # cũng là thứ `getSpriteFromSpriteCatch(<tên>)` hỏi tới. Tên biến thể
        # hoặc trùng tên file (`Archer`) hoặc là `<File>_<Hậu tố>`
        # (`CaoCao_WeaponWake`), nên một khoá là đủ cho cả hai đường tra.
        ra, n_bt = {}, 0
        for r in tat_ca():
            for bt in r.moi_bien_the():
                h = r.ho_cham(bien_the=bt)
                if h is None or not h['ten_anh'] or (h['w'], h['h']) == (0.0, 0.0):
                    continue
                n_bt += 1
                ra[bt] = dict(
                    file=r.ten, dong_tac=h['dong_tac'], xuong=h['xuong'],
                    anh=h['ten_anh'], w=h['w'], h=h['h'],
                    rot=h['rot'], rot2=h['rot2'], sx=h['sx'], sy=h['sy'],
                    rong=h['rong'], cao=h['cao'])
        with io.open(a.json, 'w', encoding='utf-8', newline='\n') as fp:
            json.dump(dict(so_bien_the=len(ra), cham=ra), fp,
                      ensure_ascii=False, indent=1, sort_keys=True)
        print('ghi %s: %d bien the co xuong Collision' % (a.json, n_bt))
    if not any([a.do, a.lech, a.bien_the, a.xem, a.chon is not None, a.json]):
        print(__doc__)
    return 0


if __name__ == '__main__':
    sys.exit(main())
