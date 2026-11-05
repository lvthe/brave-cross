# Hit-box và thời điểm đánh — ĐỌC TĨNH TỪ CONFIG (24/10/2026)

Mục đích: trả lời câu hỏi đang treo của bản dựng (`bravecross-ax`) — *"đòn đánh ăn sát
thương lúc nào và trong hộp nào"* — **không cần trace runtime**, bằng dữ liệu gốc trong
`map/*_config.xml` + đường đọc trong `libgame.so` bản VN 1.26.

Mọi số dưới đây đọc trên `decompiler/out/vn126/` (tài nguyên đã giải mã) và
`decompiler/out/vn126/ghidra-c/` (C từ Ghidra, địa chỉ là **Ghidra**, ELF = −0x10000).

---

## 1. Dữ liệu nằm trong config, không phải mã

Bảy tệp config có khối `<fight>` (đã bỏ khối nằm trong `<!-- -->`):

| tệp | số `<fight>` | có `sClass` | có `fAttackFrameFight` |
|---|---:|---:|---:|
| `hero_config.xml` | 224 | 203 | 110 |
| `heroex_config.xml` | 64 | 37 | 15 |
| `sprite_config.xml` | 57 | 42 | 27 |
| `boss_config.xml` | 17 | 15 | 10 |
| `player_config.xml` | 14 | 5 | 3 |
| `evil_config.xml` | 12 | 6 | 7 |
| `pet_config.xml` | 4 | 3 | 4 |

Chú thích **nguyên văn** trong `sprite_config.xml` (dịch):

| khoá | nghĩa |
|---|---|
| `nAttackType` | 1 近战 = cận chiến · 2 目标区域 = vùng quanh **mục tiêu** · 3 自身区域 = vùng quanh **bản thân** · 4 屏幕区域 = cả màn · 5 远程 = đánh xa · 6 全屏 = toàn màn |
| `fAttackFrameFight` | **"thời điểm đánh thật" — hậu tố là TÊN ĐỘNG TÁC** (Fight, Fight2, Fight3, Wake, Critical, Loop…) |
| `ptAttackExpandUnitLB` / `ptAttackExpandUnitRT` | **hộp bao của đòn đánh vùng**: góc dưới-trái / trên-phải, **đơn vị ô** (1 ô = 100 px) |
| `nAttackTargetLimit` | số mục tiêu tối đa của đòn vùng |
| `nAttackSectionLimit` / `fAttackSectionInterval` / `bAttackSectionReorientation` | đòn **nhiều nhịp** ("mảnh"): số nhịp · khoảng cách giây · có chọn lại mục tiêu mỗi nhịp không |
| `fDamageBonusFight` | hệ số cộng sát thương của động tác |
| `nSortTargets` | 1 = gần→xa · 2 = ngẫu nhiên |

Ví dụ thật:

```xml
<fight>
  <sName>fight_Player03</sName>
  <sClass>CDFSpriteFightPlayer03</sClass>
  <nAttackType>5</nAttackType>
  <fAttackFrameFight>6.0</fAttackFrameFight>
  <fAttackFrameFight2>6.0</fAttackFrameFight2>
  <fAttackFrameFight3>6.0</fAttackFrameFight3>
  <nComboNum>1</nComboNum>
</fight>
```

```xml
<fight>
  <sName>fight_ZhangJiao</sName>
  <sClass>CDFSpriteFightZhangJiao</sClass>
  <fAttackFrameFight>9.2</fAttackFrameFight>
  <fAttackFrameLoopFight>9.2</fAttackFrameLoopFight>
  <nComboNumFight>3</nComboNumFight>
  <fAttackFrameFight2>0</fAttackFrameFight2>
  <ptAttackExpandUnitLB>{-1,-1}</ptAttackExpandUnitLB>
  <nAttackTargetLimit>3</nAttackTargetLimit>
  <sWeaponFight>ZhangJiao_Weapon1</sWeaponFight>
</fight>
```

---

## 2. Đường đọc trong `libgame.so` (VN 1.26)

### 2.1 `fAttackFrame*` → GIÂY

`CDFSpriteFightPlayer03::vfunc_204` (`0x401cf8`, Ghidra) chọn khoá theo thứ tự:

1. đòn chí mạng → `fAttackFrameCritical`
2. `bWakeTimeByAction == 0` → `fAttackFrameWake`
3. còn lại → **`fAttackFrame` + hậu tố tên động tác** (`FUN_0028c874` ghép tên,
   `param_1+0x1cc` là chuỗi động tác)
4. mặc định `0` nếu thiếu khoá

rồi `FUN_002ba4b0(sprite, frame)` = **`frame × 1/fps`**, với
`fps = *(*(sprite+0x188) + 0x5c)` (nhịp khung của armature: 16 / 24 / 12 —
đã đo trước đây trong `sngXml`). Kết quả ghi vào **`+0x1d8`** (giây kể từ lúc bắt đầu
động tác).

⇒ **Thời điểm đánh = `fAttackFrame<tên động tác>` ÷ fps.** Không phải hằng số trong mã.

### 2.2 Hộp đòn đánh vùng

Trong hàm nạp cấu hình chiến đấu (dạng chung, ví dụ
`CDFSpriteFightDefenderNGuard::vfunc_155` @ `0x401e18`, `part_0040.c`):

| khoá | trường trên đối tượng |
|---|---|
| `nAttackType` | `+0x198` |
| `ptAttackExpandUnitLB` | `+0x19c` (Vec2, **ô**) |
| `ptAttackExpandUnitRT` | `+0x1a4` (Vec2, **ô**) |
| `nAttackTargetLimit` | `+0x1ac` |
| `nAttackSectionLimit` | `+0x1b0` (+ bản sao `+0x224`) |
| `bAttackSectionReorientation` | `+0x1c0` |
| `sWeaponFight` | `+0x1c4` |
| `sAttackAction` | `+0x1c8` |

### 2.3 Cổng sát thương vẫn KHÔNG đo khoảng cách

`CDFSpriteFightPlayer03::vfunc_211` (`0x4011f4`) → `FUN_00401090(this, target, param)`
áp `lsPlugins` cho **mục tiêu đã chọn sẵn**. Việc chọn mục tiêu / áp sát nằm ở
lớp di chuyển (`CDFSpriteEye` + `MoveTroop*`, đã port 22/10). Khớp kết luận cũ.

---

## 3. Cái đã trả lời được / cái CHƯA

**Đã trả lời:**

* Thời điểm ăn sát thương là **dữ liệu**, không phải hằng số: `fAttackFrame<Action> ÷ fps`.
* Đòn vùng dùng **hộp chữ nhật theo Ô** (`ptAttackExpandUnitLB/RT`), có giới hạn số
  mục tiêu và có loại đòn nhiều nhịp (`nAttackSection*`).
* `vfunc_211` không kiểm khoảng cách; nó chỉ áp hiệu ứng/sát thương lên mục tiêu đã có.

**ĐÃ TRUY TIẾP (24/10) — HỘP `ptAttackExpandUnit` LÀ DỮ LIỆU CHẾT Ở BẢN VN 1.26:**

* Quét **toàn bộ** 87 tệp C của `vn126/ghidra-c`: `+0x19c` và `+0x1a4` (hai mép hộp trên
  đối tượng module đánh) **chỉ xuất hiện trong chính hàm nạp** `vfunc_155` @ `0x401e18`
  (`FUN_004bf6c6(param_1+0x19c, …)` và phép `−LB` để suy RT). **Không một hàm nào đọc
  lại** — kể cả khi quét rộng sang mọi lớp `CDFSpriteFight*`, `CDFSpriteWeapon*`,
  `CDFPlugin*` (0 kết quả) lẫn quét theo *mọi* biến nền chứ không riêng `param_1`.
* Đòn vùng thật nằm ở **hệ plugin `Elem*`**, không ở hộp của module đánh. Trong
  `plugin_config.xml` **chỉ có đúng 1 plug** khai `ptArea`:
  `CaoCao_EnergySplashDebuff` → `sClass ElemExplodeAttack`, `ptArea {3,4}`,
  `nTargetNum 3`, **`nStatus 26` + `fStatusTime 7`** ⇒ nó gây **TRẠNG THÁI**, không
  gây sát thương. (`ElemGetSpriteInArea` có lớp nhưng **không plug nào dùng**.)
* Hình học vùng (đọc từ `FUN_003db2c0` @ `0x3db2c0`):
  `x1 = cx − area.x·S`, `y1 = cy − area.y·S`, `x2 = cx + area.x·S`, `y2 = cy + area.y·S`
  với `S = *(FUN_0036ea7c()->vtbl[0x270])` = **cỡ ô px (100)**, tức `ptArea` là
  **NỬA CẠNH, đơn vị ô**.
* **Tâm vùng = MỤC TIÊU**, không phải người đánh: `vfunc_198` @ `0x4014b8` dựng struct
  tham số của đòn với `+0x18 = param_2` (**mục tiêu** truyền từ `vfunc_211`) và
  `+0x1c = param_1[0x5f]` (**sprite người đánh**); `ElemExplodeAttack::vfunc_2` @
  `0x380522` lấy `ctx+0x18` làm tâm truy vấn (`FUN_00407074`) và `ctx+0x1c` để lấy
  `GetEyeInfo` lọc phe/lớp.

**Vì sao CHƯA port đòn vùng:** hiệu ứng vùng duy nhất trong bản VN là **một trạng
thái** (nStatus 26 trong 7 s cho ≤3 mục tiêu), và nó gắn qua `ElemExplodeAttack` —
muốn chạy phải có **chuỗi `Elem*`** (CDFPluginMachine + lsElemEnter/lsCondition) mà
sim chưa có. Còn `fThrowDistance` / `ptImpactRTWake` / `po2AttackShakeFight` chưa truy.

**ĐÃ DỰNG NỀN (24/10, trong `bravecross-ax`):** `plug_ref.lua` (843 plug) ·
`trang_thai_ref.lua` (bảng `<debuff>` của `global_config.xml`: `time/slow/harm/dot`) ·
`trang_thai.lua` (khung + hiệu ứng Chậm 9 ×0,5 · Đóng băng 3 +15 % · Trúng độc 7
−5 %/s · Thiêu đốt 2 −1,5 %/s `[GHIM]`) · `san_tran` gắn trạng thái từ `<lsPlugins>`
(cờ `BX_TRAN_TRANG_THAI`). Đo bằng plug thử: **40,36 s → 14,35 s**. Toàn bản VN chỉ có
**một** module *vũ khí* mang plugin trạng thái.

**ĐÃ CÀI CHUỖI `Elem*` (cùng ngày):** `bc/tran/elem.lua` — máy `CDFPluginMachine`
(`lsCondition` → `lsElemEnter`/`lsElemPlugEnter`) · `ElemExecuteOdds` ·
`ElemIsHeroFactions` · `ElemAddStatus` · `ElemExplodeAttack` (hộp `ptArea` × 100 px
quanh MỤC TIÊU, ≤ `nTargetNum`). Cổng `thu_elem` 12/12 dùng plug THẬT của CaoCao và
GuanYu. **Còn thiếu để sống:** tầng **kỹ năng hoặc vũ khí** — không module đánh nào
của đơn vị trỏ tới máy→trạng thái.

⇒ **Runtime trace vẫn có giá trị để chốt 4 điều trên**, nhưng không còn là đường duy
nhất để port thời điểm đánh.

---

## 4. ĐÒN NHIỀU NHỊP — `vfunc_206` @ 0x401b50 (port 24/10)

Ba khoá **đều có hậu tố tên động tác** (config thật: `...Fight` 20 · `...Fight2` 24 ·
`...Wake` 14 · `...Wake2` 1 · `...Super` 1):

| khoá | luật nạp | ô |
|---|---|---|
| `nAttackSectionLimit<ĐộngTác>` | đọc có hậu tố trước, không có đọc khoá trần; mặc định **1** | `+0x1b0` |
| `fAttackSectionInterval<ĐộngTác>` | mặc định **−1 → 0**; **đơn vị KHUNG**, đổi sang giây bằng `FUN_002ba4b0` (÷ fps) | `+0x1b4` |
| `bAttackSectionReorientation` | mặc định **0** | `+0x1c0` |
| `bShareDamageBonus` | mặc định **1** ⇒ `+0x1d0` **chia cho số nhịp** | `+0x1d0` |

Đã port vào `bravecross-ax` (`fight_ref.don()` + `san_tran`), đo bằng
`kiem/thu_nhip_danh.lua`: TẮT = 1 nhịp 100 sát thương ăn ngay; BẬT (YuJin) = 3 nhịp
33,33 cách 0,396 s.

---

## 4. ĐÍNH CHÍNH 25/10 — HỘP `ptAttackExpandUnit` **KHÔNG** PHẢI DỮ LIỆU CHẾT

Đoạn *"ĐÃ TRUY TIẾP (24/10) — HỘP `ptAttackExpandUnit` LÀ DỮ LIỆU CHẾT Ở BẢN VN
1.26"* ở §3 **SAI ở vế "không một hàm nào đọc lại"**. Chỗ đọc nằm ở **CHỖ GỌI**, không
nằm trong hàm nạp:

* `FUN_00411ec0` @ `0x411ec0` (và bản song sinh `FUN_00411f5c` @ `0x411f5c`):
  ```
  pcVar2 = *(code **)(*param_1 + 0x2dc);
  FUN_004bf6b2(auStack_30, param_1 + 0x67);     // = +0x19c = LB
  FUN_004bf6b2(auStack_28, param_1 + 0x69);     // = +0x1a4 = RT
  (*pcVar2)(param_1, auStack_38, auStack_30, auStack_28);
  ```
  slot vtable `0x2dc` = `CDFSpriteFightPlayer03::vfunc_183` @ `0x400c44` — **hộp đòn**.
* `FUN_00400b14` @ `0x400b14` dựng hai góc = `pos + LB/RT × scale(100 px/ô) × hướng`
  (hướng **chỉ nhân trục X**), rồi đổi thành `[x1..x2]×[y1..y2]`.
* `FUN_003db100(map+0x1fc, góc1, góc2, danh_sách, fight)` lấy đơn vị trong hộp;
  `CDFSpriteFightPlotMonitor::vfunc_184` @ `0x401026` áp `nAttackTargetLimit` (`−1` =
  không giới hạn) — xem `CDFSpriteFightTreat::vfunc_184` @ `0x408b44`.

**Đã port:** `bravecross-ax/Content/src/bc/tran/danh_vung.lua` (đòn nhiều đích); cổng
`kiem/thu_danh_vung.lua` **24/24**; chạy thật 25/10 (`bc_tt_tran.txt` có `[TRAN]` +
24 dòng `[DAN]`, 0 lỗi Lua).

**Bài học:** phép quét "trường X được đọc ở đâu" chỉ thấy lời đọc **trực tiếp** trên
`param_1`. Khi trường được truyền qua **con trỏ nền** (`param_1 + 0x67`) vào một hàm
khác, phép quét theo offset **trượt** — cùng họ bẫy 69/73: một câu "không có" sống lâu
hơn phép đo đã sinh ra nó.
