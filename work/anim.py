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
    +0x08  float   luon 0x3f800000 (= 1.0) tren CA 132.367 ban ghi xuong cua
                    418 file, khong phai "mau da xem"
    +0x0c  uint32  0
    +0x10  uint32  key_off              offset vao mang o header 0x5c
    +0x14  uint32  key_count            so khung cua rieng xuong nay

Khung, 80 byte, o goc header[0x5c]:

    +0x00  float x, y                   vi tri
    +0x08  float x2, y2                 GOC TRAI-TREN cua o anh — xem muc
                                        "hai cap vi tri" ben duoi
    +0x10  float rot1, rot2             HAI goc xoay RIENG (do), khong lap lai
    +0x18  float sx, float sy           ti le
    +0x20  float ax, ay                 DIEM NEO cua anh, tinh bang pixel cua
                                        chinh anh do (khong chuan hoa)
    +0x2C  int32  d    CHI SO ANH dang hien: vi tri trong danh sach sprite cua
                       xuong (header 0x4c); -1 = AN
    +0x38  uint32 str_off, str_len     TEN CACH TRON cua khung nay
    +0x40  uint32 dur  so khung keyframe nay GIU truoc khi sang keyframe sau
    +0x28, +0x30..+0x34, +0x44..+0x4C   chua giai (+0x28 hang so theo xuong;
                       +0x44..+0x4C co ve la bien doi mau)

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

HAI CAP VI TRI (+0x00 va +0x08) va HAI GOC XOAY (+0x10 va +0x14)

Truoc day ghi "+0x08 chi la BAN LAM TRON cua +0x00" va "cong thuc ra hieu ay van
CHUA KHOI PHUC" — ca hai deu SAI. Cong thuc da ra, do tren 418 file / 641.536
keyframe (2 khung NaN bo ra), trong do 617.664 khung HIEN:

    do lech = quay( (sx * ax, sy * ay), rot1 )
    v2 = ceil(x - do lech.x),   v3 = ceil(y - do lech.y)

`ax, ay` la +0x20 / +0x24 — hai truong truoc day ghi "chua giai". Chung la **diem
neo cua anh, tinh bang pixel CUA CHINH ANH do, khong chuan hoa**: xuong `Body`
cua Hoplite co neo (72,15; 75,85) tren anh ~150 px, con `Collision` (anh giu cho
1x1) co neo (0,5; 0,5). Nhan voi (sx, sy), quay theo `rot1`, roi lay vi tri xuong
tru di — ra GOC TRAI-TREN cua o anh. Nghia cua cap (v2, v3) la vay: **goc trai-
tren cua o anh**, lam tron len de ban ve khong bi duong ranh giua hai o.

Them mot luat nua: **khi `rot2 - rot1 = 180 do` (mod 360) thi phan x doi dau** —
dung nhu cocos doi dau `relativeOffset.x` khi lat truc x.

DO BANG HAI DUONG DOC LAP, hai con so khac nhau va khac nhau CO LY DO. Ca hai deu
nam trong `work/hai_cap.py` (so BANG) va `work/hai_cap_do.py` (do NGUOC do lech
that: `v2 = ceil(x - d)` nghia la `d` nam trong nua khoang `[x - v2, x - v2 + 1)`,
nen tu (v2, v3) trong file suy nguoc duoc do lech that roi xem cong thuc nao roi
vao do):

  do NGUOC (do lech roi dung vao o pixel)         607.943 / 617.664 = **98,43%**
  so BANG (doi cong thuc ra so roi so bang)       576.347 / 617.664 = **93,31%**

Lech nhau dung 5,12% va do la cau tra loi: **31.598 khung (5,12%) luu do lech THO,
khong lam tron** — (v2, v3) la so le o nhung khung ay (ZhuGeLiangCircle `Layer000`
x = 0, y = 1564,4, s = 5 -> v3 = 1564,4 chu khong phai 1565). 93,31 + 5,12 =
98,43, khop tung phan. Cong thuc dung o ca hai cho; chi la file khong phai luc nao
cung lam tron. (Ca thay 36.271 khung = 5,87% luu so tho.)

Cac ban khac trong cung phep do NGUOC, de thay cong thuc nay khong phai ban duy
nhat "tam duoc": khong quay 596.685 (96,60%); quay theo `rot2` 605.438 (98,02%);
quay theo (rot1+rot2)/2 605.681 (98,06%); lat VO DIEU KIEN tut xuong 575.423
(93,16%).

LUAT LAT do duoc la dung o phan lon va **SAI o 3.033 keyframe (0,49%)**, sai ca hai
chieu: co khung hieu = 0 ma van phai lat (ArcherN `Defend` / `Neck`), co khung hieu
= 180 ma khong lat (ArcherN `WakeLoop` / `Neck`). Nen thu that su quyet dinh co le
la co lat-theo-bien-the (cocos `isFlipX`) chu khong nam trong ban ghi khung. Ghi
ra, KHONG suy dien them.

CHUA KHOI PHUC: **7.295 khung (1,18%)** khong ban ung vien nao ra, don vao xuong
lop HIEU UNG — `LayerName000` (3.670 khung sai), `LayerName002` 1.626, `deng1`
1.477, `LayerName001` 1.295, `Layer000` 1.244, `Layer002` 969, `deng2` 827… —
nhung xuong co neo RAT LON (|neo| 3169..3550 px, co mot gia tri rac 1,67e24) va co
khung `rot1 != rot2` lech khong phai 180 do. Ban dung doc `+0x08` cho
`_lua_getBonePosInNode` VAN DUNG; cho nay chi anh huong toi xuong hieu ung khong
nhin thay. Ghi ro la chua khoi phuc, khong doan.

NAM keyframe doi chieu doc lap duoc voi may ao (`work/emu_xuong.py`); bon trong nam
co neo khac 0 nen phep kiem nay co suc phan biet that:

    ZhangLiangBao Collision (x,y)=(-0,50; -113,50) (sx,sy)=(175,00; 227,50)
                            neo=(0,5; 0,5) -> ceil(-88,00; -227,25) = (-88, -227)
    Hoplite       Collision (x,y)=(-45,09; -129,61) (sx,sy)=(54,52; 54,40)
                            neo=(0,6; 0,6) -> ceil(-77,802; -162,25) = (-77, -162)
    Gashapon      Collision (x,y)=(-78,85; -72,52) (sx,sy)=(38,00; 44,40)
                            neo=(1,4; 2,8) -> ceil(-132,05; -196,84) = (-132, -196)
    ElephantSoldier Collision (x,y)=(-69,17; -69,85) (sx,sy)=(56,84; 39,50)
                            neo=(0,6; 1,16) -> ceil(-103,27; -115,67) = (-103, -115)
    YuJin         Head      (x,y)=(0,59; -127,67) (sx,sy)=(1; 1)
                            neo=(0; 0) -> (1, -127)

Nam so nay dung bang nam so ma ham `_lua_getBonePosInNode` cua ban goc tra ve.

Anh huong toi ban dung: **khong phai doi gi**. Do lech bang 0 o **553.661 khung
(89,64% so khung hien) vi neo la (0, 0)** — ca xuong than nhan vat nam trong so
do, nen voi chung `v = ceil(x, y)`, hai cap lech nhau duoi 1 px: ve bang `+0x00`
(dung khong gian Cocos, neo (0,5; 0,5) — xem `rig/sng_rig.gd`) van dung, con
`diem_xuong` doc `+0x08` cho lop Lua. Phan lech con lai nam o xuong hieu ung va o
hop cham (khong nhin thay).

  +0x10  la HAI goc RIENG, khong phai mot goc lap lai: **80.620 keyframe
         (12,5%)** co rot1 != rot2. Vd ADou01 `JiWing` 27,87 / 18,07; ADou01
         `图层 2` 180 / 0 — lat MOT truc chu khong lat ca hai.
         Do cung la cap ma `_lua_CollisionSize` dung: `rot1` nhan voi be RONG,
         `rot2` nhan voi be CAO (xem `cham_ref.py`), va `rot2 - rot1` la thu quyet
         dinh luat lat o tren.

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
(luon 0 tren mau da xem).

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

    def _blend_at(self, q):
        """Ten cach tron cua mot khung: cap (str_off, str_len) o +0x38.

        Cong thuc CACH TRON nam trong tung khung, khong phai trong bang sprite
        (cho nay truoc day ghi "chua giai"). Do tren 418 file .xml, tu vung
        dong goi duoc chi co: 'normal' 462.850, rong 159.663, 'screen' 22.083,
        'undefined' 3, 'overlay' 3, 'lighten' 1, cong 21 cho rac (BingYing,
        XSJiYouHeTiJi). 'multiply' KHONG xuat hien lan nao.

        Doi chieu voi ban goc chay trong may ao (work/emu_dom.py) va voi ham
        phan nhanh trong libgame.so (0x25d476..0x25d4ce, xem CLAUDE.md):

            chuoi        +0x78  +0x7c (nguon)  +0x80 (dich)   GL
            rong / la    0      1              0x303          GL_ONE, GL_ONE_MINUS_SRC_ALPHA
            'screen'     1      0x302          1              GL_SRC_ALPHA, GL_ONE   <- CONG
            'multiply'   2      0x306          0x303          GL_DST_COLOR, GL_ONE_MINUS_SRC_ALPHA

        Thieu truong nay thi armature nao co khung 'screen' se duoc ve tron
        THUONG: do duoc o Main — `UITongYong_ItemLight` (32/32 khung 'screen')
        thanh mot dom xanh dac thay vi vet sang.
        """
        off = self.u(q + 0x38)
        ln = self.u(q + 0x3C)
        if ln == 0 or ln > 64:
            return ''
        a = self.pool + off
        if a + ln > self.size:
            return ''
        return self.d[a:a + ln].decode('utf-8', 'replace')

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
                # v2/v3 la cap +0x08 = GOC TRAI-TREN cua o anh (pixel, lam tron
                # len): `ceil((x,y) - quay((sx*ax, sy*ay), rot1))` voi (ax,ay) la
                # neo o +0x20/+0x24 — khop 602.002/641.536 keyframe (93,84%),
                # xem muc "HAI CAP VI TRI" o docstring. Ban goc doc DUNG cap nay:
                # `_lua_getBonePosInNode` tra `(v2, -v3)`, do bang may ao tren
                # nam xuong (`emu_xuong.py`) va doi chieu doc lap duoc tu du lieu
                # (ZhangLiangBao (-88,-227), ElephantSoldier (-103,-115), YuJin
                # Head (1,-127), Gashapon (-132,-196), Hoplite (-77,-162)).
                ('v2', round(v[2], 4)), ('v3', round(v[3], 4)),
                ('rot', round(v[4], 4)),
                # rot2 la goc THU HAI (+0x14). `_lua_getBoneRectInNode` dung no
                # cho be CAO, y nhu `cham_ref.py` (12,5% keyframe co rot != rot2).
                ('rot2', round(v[5], 4)),
                ('sx', round(v[6], 4)), ('sy', round(v[7], 4)),
                ('d', struct.unpack_from('<i', self.d, q + 0x2C)[0]),
                ('dur', struct.unpack_from('<I', self.d, q + 0x40)[0]),
                ('blend', self._blend_at(q)),
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

    def sprite_anchors(self, off, count):
        """Diem neo cua tung anh: cap float (x, y) o +0x08 cua ban ghi tham chieu.

        Neo nam TRONG O ANH CUA CHINH ANH AY (khong phai toa do xuong), va no la
        thuoc tinh cua ANH chu khong cua xuong: do tren 397 file .xml thi
        15.237/15.238 ten anh khai CUNG mot neo o moi rig dung chung — ngoai le
        duy nhat la `ZhaoYun_Eff-Line_instant`, va 12.761/12.957 (98,5%) neo nam
        gon trong o anh cua no.

        Ban goc doc dung cap nay: `rig/sng_rig.gd` truoc day bo qua no va dat
        CANH DAY anh len goc xuong, do ra thi neo cua chinh anh trung goc xuong
        chi 2.977/27.948 cap xuong->anh (10,7%).

        Tra ve dict ten -> [x, y]; ten trung thi giu cai dau tien. Tra ve LIST chu
        khong phai tuple de `export._lam_sach_json` di xuong duoc — no chi de quy
        vao dict/list, nen mot tuple lot luoi se lam `json.dump(allow_nan=False)`
        nem loi thay vi ghi ra file JSON hong.
        """
        out = collections.OrderedDict()
        for j in range(count):
            p = self.ref_base + off + j * REF_REC
            if p + REF_REC > self.size:
                raise AnimError('tham chieu sprite vuot cuoi file')
            ten = self._name_at(p)
            if ten in out:
                continue
            out[ten] = list(struct.unpack_from('<2f', self.d, p + 0x08))
        return out

    def all_anchors(self):
        """Gop `sprite_anchors` cua MOI ban ghi tham chieu trong file.

        Chi `parts()` mang ban ghi tham chieu sprite (`bones()` khong co), va do
        cung dung la duong `sng_rig.gd:_sprite_for()` doc, nen quet het `parts()`
        la phu het duong ve cua ban dung.
        """
        out = collections.OrderedDict()
        for i in range(self.u(0x20)):
            r = self.part_base + i * 0x10
            sub_off, sub_n = self.u(r + 8), self.u(r + 0xc)
            for k in range(sub_n):
                q = self.part_sub + sub_off + k * 0x10
                for ten, neo in self.sprite_anchors(self.u(q + 8),
                                                    self.u(q + 0xc)).items():
                    if ten not in out:
                        out[ten] = neo
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
            # Neo theo TUNG ANH (xem `all_anchors`). `rig/sng_rig.gd` dung no de
            # dat anh sao cho neo nam tren goc xuong — do la luat cua ban goc.
            ('spriteAnchors', self.all_anchors()),
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
