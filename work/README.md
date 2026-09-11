# Dịch ngược APK "Búa Tạ"

Hai bản của cùng một game, dịch ngược song song để đối chiếu.

| | bản CN | bản VN |
|---|---|---|
| File gốc | `OAR1_XGSDK_1.25_jinshan_gwbb_sec.apk` (83 MB) | `Búa+Tạ+-+Siêu+Anh+Hùng_1.26.81485_APKPure.xapk` (252 MB) |
| Package | `com.xh.dachui.xsj` — *dachui* = 大锤 = **búa tạ** | `com.cmn.buatanew` |
| Version | 1.25.78923 (build 2017-10-25) | 1.26.81485 |
| SDK | Kingsoft Passport, XGSDK, Umeng, iFlytek, Bugly/TPNS | Kull SDK, Facebook, Google Play, Bugly/TPNS |
| Bảo vệ | **SecNeo** (`libDexHelper.so`) — lớp bọc + native, **không rút lớp nào khỏi dex** | **không có** |
| Lua | 952 file | 973 file |

Chung: Cocos2d-x + Lua 5.2.3, lớp engine riêng tiền tố `sng`, `libgame.so` (ARMv7) + FMOD Studio.

## Kết quả

```
work/
  apk/, vn/apk/, vn/obb/      APK / OBB giải nén nguyên trạng
  decrypted/                  bản CN đã giải mã
    AndroidManifest.xml       đã giải nhị phân → XML đọc được
    assets/                   3984 file (242 MB)
      sc/                     952 file .lua — TOÀN BỘ logic game, mã nguồn gốc
      config/, conf/          bảng số liệu game (JSON / XML / nhị phân)
      map/, img_all/          atlas, plist, dữ liệu màn chơi
      *.pkm                   texture ETC1 (đã về đúng định dạng PKM 10)
  vn/decrypted/               bản VN đã giải mã — 10090 file, 973 .lua

  unpack.py                   giải nén APK/XAPK -> cả cây thư mục làm việc
  sng_decrypt.py              bộ giải mã tài nguyên
  axml.py                     bộ giải mã AndroidManifest nhị phân
  dexinfo.py                  đo mức độ bị đóng gói của classes.dex
  extract_api.py              quét lời gọi RPC trong Lua
  build_spec.py               sinh đặc tả server
  diff_api.py                 so hai đặc tả (API, chữ ký, enum, mã lỗi)
  inventory.py                so kho tài nguyên hai bản
  xgg.py                      đọc định dạng .xgg (sngXgg / xgg5.0)
  sngxml.py                   đọc plist atlas sngXml
  anim.py                     xuất hoạt ảnh xương ra JSON
  sprites.py                  cắt sprite từ atlas ra PNG (giải ETC1)
  export.py                   xuất trọn gói một atlas hoạt ảnh: PNG + JSON

  server-spec/                đặc tả bản CN — 584 API
  server-spec-vn/             đặc tả bản VN — 614 API
    SERVER_API.md             đặc tả đầy đủ
    server_api.json           bản máy đọc được
    rpc-reference.html        bản tra cứu có tìm kiếm
  inventory.json, api_diff.json
```

## Đặc tả server

Dựng tự động từ mã Lua, mọi số liệu đến từ chính mã nguồn, không suy đoán.

| | CN 1.25 | VN 1.26 |
|---|---:|---:|
| Hàm server client gọi tới | **584** | **614** |
|  — khai báo trực tiếp `CallServer("Tên", …)` | 484 | 487 |
|  — sinh lúc chạy qua `bindRpcToEvent` ⟳ | 100 | 127 |
| Dò được handler trả về | 392 | 415 |
| Callback chiều ngược | 388 | 410 |
| Nhóm mã lỗi | 59 | 62 |

Giao thức: envelope protobuf `GameActionData`, payload **JSON thuần**, định tuyến
**theo tên hàm** ở cả hai chiều — client gửi thẳng tên hàm server cần chạy, server
trả kết quả bằng một RPC ngược gọi hàm `On*` của client.

```bash
python build_spec.py                                            # → server-spec/
python build_spec.py --assets vn/decrypted/assets --out server-spec-vn
cd server-spec && python build_page.py && python build_page.py ../server-spec-vn
python diff_api.py server-spec server-spec-vn                   # → api_diff.json
```

### Hai cách mã nguồn phát sinh lời gọi

Quét `CallServer` không đủ. `CUIAssist.bindRpcToEvent` (`sc/user/UI/CUIAssist.lua:335`)
sinh hàm **lúc chạy** từ một bảng sự kiện:

```lua
CUIAssist.bindRpcToEvent(self, "G_ActivityStock", EventManagerLogicEvent.Stock,
                         "Client%s", "OnClient%s")
-- với mỗi khoá k trong bảng:
--   self[reqFmt % k] = function(...) CallServer(GAME_LOGIC, obj, reqFmt % k, ...) end
```

Tên hàm chỉ tồn tại sau khi `string.format` chạy, nên **không xuất hiện dưới dạng
chuỗi ở bất kỳ đâu trong mã nguồn**. 11 module đi hoàn toàn bằng đường này
(StateWar, Pet, XingHun, JFZY, Stock, RedPacket, GuildContest, HeroPK, Tongque,
ShuaShuaLe, SysExchange). `extract_api.resolve_bound()` nở chúng ra từ
`EventManagerLogicEventDef` trong `sc/share/EventManager.lua`; chữ ký tham số
lấy từ nơi gọi thật, mô tả lấy từ comment cuối dòng của chính khoá sự kiện.

Sau bước này **không còn API nào chưa giải được**: 2 mục còn lại trong `dynamic`
(`rpc.lua`, `CUIAssist._addRpcFunc`) đều là tầng vận chuyển, không phải API.

## Khác biệt VN so với CN

`api_diff.json` — **thêm 30 API, bỏ 0**, không API nào đổi chữ ký:

| đối tượng server | số API mới | nội dung |
|---|---:|---|
| `G_JiuFaZhongyuan` | 15 | 九伐中原 — phó bản trận doanh mới |
| `G_ActivityStock` | 8 | chơi cổ phiếu |
| `G_ServerStateWarProtocol` | 5 | quốc chiến: đường di chuyển, công cáo |
| `G_RechargeLogic` | 2 | cổng thanh toán AiBei |

Thêm 3 nhóm mã lỗi (`JFZY`, `Stock`, `ChargeSign`), 22 callback mới.
Kho tài nguyên: chỉ CN 125 file, chỉ VN 6231, chung 3859 (giống hệt 3506, khác 353).
Chênh lệch gần như toàn bộ nằm ở `.pkm` (chỉ VN có 5837 file) và `.bank` âm thanh (299).

## Cơ chế mã hoá tài nguyên (đã phá)

Mọi file tài nguyên kết thúc bằng magic ASCII `sngFile` (7 byte):

```
file    = payload || b"sngFile"
payload[0:256] = plaintext XOR KEY32          (khoá 32 byte lặp lại)
payload[256:]  = plaintext XOR 0xFF
```

`KEY32 = 5e44dddb bfa6b416 84c7cb83 47a3ec3d 5fcecb86 07ad0d2e 12379d79 ed0fb468`

Sau khi giải mã, các file `.pkm/.plist/.xgg/.xml/.json` còn được nén **gzip** thêm một lớp.

Khoá được khôi phục bằng tấn công *many-time pad*: 952 file `.lua` dùng chung một
keystream, chấm điểm từng vị trí theo tiêu chí "byte giải ra phải là text hợp lệ"
cho ra khoá duy nhất, và lộ ra chu kỳ lặp 32 byte. Bản VN dùng **cùng khoá**.

## Định dạng nhị phân riêng

| Magic | Số file (CN/VN) | Trạng thái |
|---|---|---|
| `xgg5.0` | 278 / 290 | **đã giải**, xem `xgg.py` |
| `sngXgg` | 6 / 6 | **cùng một định dạng với `xgg5.0`** — chung bộ đọc |
| `sngXml` — `.plist` | 493 / 501 | **đã giải**, xem `sngxml.py` |
| `sngXml` — `.xml` | 411 / 418 | **đã giải**, xem `sngxml.py` |

`xgg5.0` và `sngXgg` hoá ra **không phải hai định dạng**: cùng một hàm trong
`libgame.so` nhận cả hai magic, và cả 580 file của hai bản đọc được bằng chung
một bộ giải.

### Bố cục `.xgg` (`work/xgg.py`)

Đây là file **bố cục cảnh/màn chơi**: danh sách atlas, sprite và ảnh rời kèm
toạ độ đặt. Mọi trường đều đọc được, không còn phần nào phải đoán.

Ba hàm trong `libgame.so` (bản CN), tìm qua xref tới chuỗi `sngXgg` ở
`0x007d2c0c`:

| hàm | vai trò |
|---|---|
| `FUN_0048f0f0` | đọc header, cất các con trỏ vào đối tượng 64 byte |
| `FUN_002e7948` | người gọi — `operator_new(0x40)` rồi dùng kết quả |
| `FUN_0048f1b8` | **giải chuỗi** — mấu chốt |

`FUN_0048f1b8` là chỗ mở ra tất cả:

```c
if (rec[1] == 0 || rec[0] < 0)   ->  chuỗi rỗng
else  ->  chuỗi tại  base + rec[0] + *(int*)(base + 0x24),  dài rec[1]
```

mà `*(int*)(base + 0x24)` chính là **`off_H`**. Tức mỗi bản ghi mở đầu bằng
`(offset tính từ off_H, độ dài)`, và `off_H` là gốc kho chuỗi. Thống kê thuần
không ra được điều này — trước đó đã thử gốc là đầu file và `off_E`, đều sai.

```
0x00  char[7]  magic     "sngXgg\0" hoặc "xgg5.0\0"   (memcmp 7 byte)
0x07  byte     0x00
0x08  uint32   off_A     luôn 0x28              580/580 file
0x0C  uint32   off_B     luôn 0x90              580/580 file
0x10  uint32   off_C
0x14  uint32   off_D
0x18  uint32   off_E
0x1C  uint32   off_F
0x20  uint32   off_G     luôn = off_E + 8       580/580 file
0x24  uint32   off_H
                                   7 + 1 + 8*4 = 40 = 0x28, kín hết header
```

Ba section giữa dùng khuôn `[uint32 count][count × bản ghi]`, bản ghi **8 / 16 /
16 byte** — suy từ khoảng cách `(off_kế_tiếp − off − 4) / count`, không một file
nào chia không hết. Thứ tự giá trị `E ≤ G ≤ F ≤ H ≤ kích thước`, đúng 580/580.

```
0x28   section A   104 byte float thông số cảnh
0x90   section B   [count][count × 8]    atlas .plist
off_C  section C   [count][count × 16]   sprite + toạ độ
off_D  section D   [count][count × 16]   ảnh rời + toạ độ
off_E  section E   8 byte (vì off_G luôn = off_E + 8)
off_G  section G   nhị phân, chưa giải
off_F  section F   nhị phân, chưa giải
off_H  section H   kho chuỗi, tới cuối file

bản ghi B  (8 byte):  uint32 str_off, uint32 str_len
bản ghi C (16 byte):  uint32 str_off, uint32 str_len, float x, float y
bản ghi D (16 byte):  giống C
```

**Đã kiểm chứng trên toàn bộ 580 file của cả hai bản:** 29017 bản ghi — 28539
giải ra chuỗi ASCII sạch, 478 độ dài 0 (đúng nhánh chuỗi rỗng trong
`FUN_0048f1b8`), **0 hỏng**. Nội dung đúng một kiểu mỗi section: B toàn
`.plist` (16299), C toàn `.png` (10934), D `.png` (1262) + `.jpg` (44).

Ví dụ `BattleField_Arena_960_640.xgg`:

```
section B — atlas:    Scene_Arena.plist
section C — sprite:   Arena_01-01.png              x=346.0   y=96.0
section D — ảnh rời:  ../png/scene/arena/Arena_ground-a.png   x=1025.0  y=686.0
```

**Còn lại:** ý nghĩa từng float trong section A (nhìn ra `1024.0 / 768.0 / 0.8`
— kích thước cảnh và hệ số tỉ lệ), và nội dung nhị phân của section G và F.

```bash
python xgg.py decrypted/assets --scan   # kiểm trên cả cây
python xgg.py <file.xgg>                # đọc header + nội dung
python xgg.py <file.xgg> --json         # xuất JSON
```

### Bố cục `sngXml` bản `.plist` (`work/sngxml.py`)

Một magic nhưng **hai cấu trúc khác hẳn nhau**, chia đúng theo đuôi file: 493
file `.plist` là atlas sprite (đã giải), 411 file `.xml` là thứ khác (chưa
giải). Chuỗi header lộ nguồn gốc:

```
'Background_2.png'
'$TexturePacker:SmartUpdate:8a9ca6937f09f769cb27d53a0e6d5066$'
'Background_2.png'
```

Đây là plist cocos2d do **TexturePacker** sinh, đã biên dịch sang nhị phân —
ba chuỗi đó chính là khối `metadata` của plist gốc.

Bộ nạp `FUN_0050da18` chỉ kiểm magic rồi cất buffer, không phân tích gì. Hàm
giải chuỗi là `FUN_0050daac`, **cùng khuôn với `.xgg`**:

```c
if (rec[1] == 0)  ->  chuỗi rỗng
else  ->  chuỗi tại  base + rec[0] + <gốc kho chuỗi>,  dài rec[1]
```

```
0x00  char[7]  "sngXml\0"
0x10  uint32   count        số khung
0x18  uint32   str_off, str_len   } ba chuỗi header:
0x28  uint32   str_off, str_len   }   tên texture, hash TexturePacker,
0x30  uint32   str_off, str_len   }   tên texture thật
0x38  uint32   off_recs     gốc mảng bản ghi
0x3c  uint32   off_pool     gốc kho chuỗi

bản ghi 60 byte:
  +0x00  uint32  str_off      ) chắc chắn — từ FUN_0050daac
  +0x04  uint32  str_len      )
  +0x08  float x2    vị trí trong atlas       ) kiểu đo được từ 18980 bản
  +0x10  float x2    kích thước khung         ) ghi thật; TÊN là suy diễn
  +0x18  float x2    độ lệch, 85% bằng 0      ) theo khuôn TexturePacker,
  +0x20  uint32      chỉ nhận 0/1 — cờ rotated) chưa đối chiếu từng trường
  +0x24  float x2    82% bằng 0               ) với code
  +0x2c  float x2    kích thước gốc           )
  +0x34  float x2                             )
```

**Đã kiểm chứng:** `(off_pool − off_recs) / count = 60` byte trên 493/493 file,
không ngoại lệ. 20459 chuỗi: 20306 giải được (16 tên tiếng Trung UTF-8), 153 độ
dài 0, **0 hỏng**. Bản VN cũng vậy: 501 file, 0 lỗi.

```bash
python sngxml.py decrypted/assets --scan
python sngxml.py <file.plist>            # đọc
python sngxml.py <file.plist> --json     # xuất JSON
```

### Bố cục `sngXml` bản `.xml` — dữ liệu hoạt ảnh

411 file (`map/Archer.xml`, `ADou01.xml`… cỡ 160 KB–1,1 MB). Loại này khớp
**chính xác** với nhánh code đi qua `FUN_0026f704`: ba mảng, hai trong số đó
có mảng con. Header giữ một bảng mục lục 9 offset ở `0x44`–`0x64`, tăng dần.

```
0x20  count mảng 1      0x44  gốc mảng 1   (bước 0x10)
0x28  count mảng 2      0x48  gốc con 1    (bước 0x10)
0x40  count mảng 3      0x50  gốc mảng 2   (bước 0x10)
                        0x54  gốc con 2    (bước 0x28)
                        0x60  gốc mảng 3   (bước 0x28)
                        0x64  gốc kho chuỗi   ← đúng `+ 100` trong FUN_0050daac

bản ghi mảng 1 và 2 (0x10):  str_off, str_len, sub_off, sub_count
bản ghi con và mảng 3     :  str_off, str_len, rồi các trường CHƯA RÕ
```

`map/Archer.xml` đọc ra:

```
mảng1  Archer_WeaponNormal  -> Arrow, Fire, PlugIn_60, PlugIn_3 ...
mảng2  Archer_WeaponNormal  -> Walk
mảng3  Archer_res-Head4, Archer_Dong_res-Phantasm ...
```

Tức là bộ phận, hoạt ảnh và sprite của một nhân vật — định dạng hoạt ảnh
xương. Tên hay gặp trong 411 file: `Play` (1929), `LayerName000` (862),
`Layer000` (631), `Collision` (582), `PlugIn_1` (544), `Walk` (406).

**Đã kiểm chứng:** 50042 chuỗi, giải được **100.00%**, 0 rỗng, **0 hỏng**.

### Keyframe — hoạt ảnh xương (`work/anim.py`)

Lớp cuối của định dạng. `sngxml.py` đọc bộ xương, tên động tác và tên sprite;
`anim.py` đọc thêm **dữ liệu biến đổi từng khung**.

```
bản ghi động tác (0x28), ở mảng con của mảng 2:
  +0x00  str_off, str_len    "Walk", "Fight", "Death"...
  +0x08  uint32              số keyframe
  +0x10  uint32              độ dài động tác, tính bằng khung
  +0x14  uint32              cờ lặp: 1 = lặp vô hạn, 0 = chạy một lần
  +0x20  uint32  bone_off    offset vào mảng ở header 0x58
  +0x24  uint32  bone_count  số xương tham gia

bản ghi xương (24 byte), gốc header[0x58]:
  +0x00  str_off, str_len    "HandLeft", "ThighLeft"...
  +0x08  float 1.0
  +0x10  uint32  key_off     offset vào mảng ở header 0x5c
  +0x14  uint32  key_count

khung (80 byte), gốc header[0x5c]:
  +0x00  float x, y          vị trí
  +0x08  float x, y          cùng vị trí, đã làm tròn
  +0x10  float rot, rot      góc xoay (độ), lặp lại
  +0x18  float sx, sy        tỉ lệ
  +0x20..+0x50               0 trên toàn bộ mẫu đã xem
```

`Cavalry.xml`, động tác `Walk` — nhìn là thấy chu kỳ đi thật:

```
ArmLeft   góc:  0.00° →  8.48° → -10.20° →  -2.51°   (tay vung)
LegLeft   góc: 27.00° → 35.47° →  16.80° →  24.33°   (chân bước)
```

`ZhangLiaoGod`, động tác `Fight`, xương `Weapon`:
`-122.7° → 69.9° → 39.4° → -102.0° → 69.9°` — nhịp chém.

**Đã kiểm chứng trên 418/418 file bản VN, 0 lỗi:** 8207 động tác, 131029
xương, **641538 keyframe**.

#### Hai trường giải thêm ở bản ghi động tác

Quét 7995 bản ghi của 411 file:

* `+0x10` **bằng** số keyframe ở 7715 bản ghi, **lớn hơn** ở 136. Ví dụ
  `Archer/Hang` có 2 keyframe nhưng dài 10 khung — giữ tư thế 5 khung mỗi
  keyframe. Đây là *độ dài*, không phải số khoá.
* `+0x14` chỉ nhận 0 hoặc 1, và chia đúng theo nghĩa động tác:

  | cờ | các động tác |
  |---|---|
  | 1 (lặp) | Walk, Standby, Run, WalkBack, Walk2, Defend, DefendBack, Hang, Fire |
  | 0 (một lần) | Fight, Death, Hit, Wake, Fight2, Jump, Down, Fight3 |

  Không có động tác một-lần nào bị đánh dấu lặp và ngược lại.

#### Liên kết xương → ảnh (mảng ở header `0x4c`)

Bản ghi bộ phận dài 16 byte, trước chỉ đọc 8 byte đầu (tên). 8 byte sau là
`(ref_off, ref_count)` trỏ vào một mảng bản ghi 20 byte ở header `0x4c`, và
8 byte đầu của mỗi bản ghi đó là **tên ảnh** mà bộ phận dùng:

```
Archer/Head    -> Head1, Head3, Head2, Head4, Head5   (5 nét mặt)
CaoCao/LeftArm -> CaoCao_res-RightArm                 (dùng lại ảnh tay phải)
CaoCao/Head    -> CaoCao_mc_Head                      (một rig lồng nhau)
```

Đây là chỗ **bắt buộc** phải đọc, không suy ra từ tên được: `CaoCao` đặt tên
ảnh là `face1`, `touguan`, `toufa0013_instant`. **Đã kiểm chứng: 829 file,
65989 tham chiếu, 0 lỗi, 0 tham chiếu rỗng** — 64004 trỏ tới ảnh trong atlas,
1985 trỏ tới rig lồng nhau (`<Tên>_mc_...`, là một biến thể khác trong chính
file đó).

**Chưa rõ:** 12 byte cuối của bản ghi 20 byte này.

```bash
python anim.py <file.xml>                # tóm tắt
python anim.py <file.xml> --anim Fight   # đổ chi tiết một động tác
python anim.py <file.xml> --json         # xuất JSON đầy đủ
python anim.py vn/decrypted/assets --scan
```

**Chưa rõ:** 48 byte cuối mỗi khung (luôn 0 trên mẫu đã xem), và vì sao vị trí
cùng góc xoay đều được lưu hai lần. Đã **thử và loại** giả thuyết bản ghi con
chứa thêm mô tả chuỗi thứ hai/thứ ba — đọc như vậy cho ra rác (`'D'`, `'n'`,
`'De'`) và 332 trường hợp hỏng.

### Nền cảnh (`work/scenes.py`)

Nền sân **không** nằm trong atlas như nhân vật, mà là từng file `.pkm` rời
trong `assets/png/scene/<cảnh>/`.

`BattleField_<cảnh>_960_640.xgg` mô tả sân ghép từ ~45 mảnh nhỏ cộng một atlas
`Scene_<cảnh>.plist`. **Texture của atlas đó không có** — không trong APK,
không trong OBB. Đã kiểm: OBB có 9874 mục, 16 file `Scene_*` đều chỉ là
`.plist`, và không có file nào tên `Scene_*.png`/`.pkm`. Chúng được tải về lúc
chạy từ máy chủ vá. Nên phần nền ghép từ 45 mảnh thì **dựng lại không được**.

Bù lại, các lớp **nền đầy màn** thì còn đủ và dùng được ngay: 24 ảnh trên 9
cảnh, 1024×768 đến 1665×768, vẽ tay.

```bash
python scenes.py --list
python scenes.py --all --out <thư mục>
```

| cảnh | ảnh |
|---|---|
| plain | 4 (1024×768) |
| lava | 5 |
| siege | 3 |
| zizhulin | 3 |
| CBZZ, devil, arena, main3 | 2 mỗi cảnh |
| tongtianta | 1 (1665×768) |

Cùng mẹo alpha như atlas nhân vật: ETC1 không có kênh trong suốt nên game xếp
đôi chiều cao, nửa trên là màu, nửa dưới là độ trong.

### Art giao diện

Cùng `scenes.py`, thêm `--raw` để xuất trọn một thư mục `.pkm`:

```bash
python scenes.py --raw vn/decrypted/assets/png/background --out <thư mục>
```

86 ảnh: khung gỗ, cuộn giấy, bản đồ thế giới, và **16 bản đồ chương**
(`ui_background_chapter_*`).

Cũng như nền cảnh, các atlas `Background_*.plist` mà file bố cục UI tham chiếu
thì **không có texture** — chỉ có `.plist`. Phần dùng được là các ảnh rời này.

### Xem nhanh cả một thư mục ảnh (`work/contact.py`)

Thư mục art của bản gốc có hàng trăm file tên kiểu `ui_background135.pkm`; mở
từng cái để tìm một cái khung thì mất cả buổi.

```bash
python contact.py <thư mục> --out tấm.png --cell 130 --cols 9
```

Dán tất cả thành một tấm lưới, nền ô cờ xám để phân biệt vùng trong suốt.

### Cắt sprite ra PNG (`work/sprites.py`)

Mảnh cuối: pixel. Texture là `.pkm` — **ETC1**, định dạng nén của GPU di động,
7260 file bản VN.

ETC1 **không có kênh alpha**, nên game dùng thủ thuật kinh điển: ảnh cao gấp
đôi vùng sprite, **nửa trên là màu RGB, nửa dưới là alpha dạng xám**. Đo trên
397 cặp plist+texture: tỉ lệ chiều cao / vùng sprite = **2.00 đúng 397/397
file**, không một ngoại lệ.

Kiểm chứng luôn cả bộ giải ETC1 bằng cách đó: nửa dưới giải ra **100% xám,
lệch lớn nhất bằng 0** trên 20.400 điểm mẫu — bộ giải sai thì nửa dưới phải ra
nhiễu màu.

Toạ độ sprite xác định bằng cách lấy kích thước texture làm chuẩn, thử từng
cặp trường xem cặp nào cho sprite nằm gọn trong ảnh:

```
+0x08, +0x0c   vị trí trong atlas (x, y)
+0x10, +0x14   kích thước (w, h)
+0x20          cờ xoay — TexturePacker xoay 90° để xếp chặt, khi đó
               chiều rộng và cao bị hoán đổi trong atlas

không xét xoay : 12613/12998 khung nằm gọn  (97.04%)
có xét xoay    : 12996/12998 khung nằm gọn  (99.98%)
```

Không dùng thư viện ngoài — bộ giải ETC1 và bộ ghi PNG viết thẳng trong file,
giữ đúng kiểu của repo.

```bash
python sprites.py <file.plist>                  # xem thông tin atlas
python sprites.py <file.plist> --out <thư_mục>  # cắt ra PNG RGBA
python sprites.py vn/decrypted/assets --scan
```

Quét toàn bộ, **0 lỗi**: bản VN 397 atlas / 12998 khung, bản CN 88 atlas /
2816 khung. 33 file `.plist` là XML thuần chưa biên dịch (đọc bằng parser XML
bất kỳ), 104 file không có `.pkm` đi kèm.

### Xuất trọn gói một atlas hoạt ảnh (`work/export.py`)

Gộp ba mảnh trên. Một atlas hoạt ảnh gồm ba file cùng tên trong assets:

```
Cavalry.xml     bộ xương + hoạt ảnh
Cavalry.plist   toạ độ sprite trong atlas
Cavalry.pkm     texture ETC1
```

Bản VN có **397 atlas đủ cả ba file**. Đây **không phải 397 "nhân vật"** —
trong đó có 97 atlas `UI*`, 8 `XS*` (hiệu ứng) và 3 `AttackButton`/`StartCartoon`;
còn lại ~289 mới là nhân vật / quân chủng / trang phục.

```
<out>/<Tên>/
    sprites/*.png      từng sprite một file, nền trong suốt
    <Tên>.json         bộ xương, động tác, keyframe, danh sách sprite
```

JSON có trường `spriteFiles` nối **tên sprite trong hoạt ảnh** với **tên file
PNG thật**, nên đọc JSON ra là nạp ảnh được ngay, không phải đoán tên. Trên
`Cavalry` khớp 132/132.

Chạy toàn bộ: **397/397 atlas, 0 lỗi** — 12820 PNG, 7999 động tác,
636388 keyframe, 314 MB.

#### 21 atlas không xuất được — đã truy đến gốc

Đọc tên texture từ header của plist (chứ không đoán theo tên atlas): cả 21 đều
trỏ tới `<tên>.png`, và file đó **không tồn tại ở cả bản CN lẫn bản VN**. Tức
texture không được đóng gói trong build — không phải lỗi tìm đường dẫn của
`export.py`.

**Không có nhân vật nào trong số 21 này**: 16 mục là `UI*`/`XS*` (hiệu ứng giao
diện — `UIJieSuan` 结算, `UIChengHao` 称号, `UIJunTuanTaoFa` 军团讨伐…), 3 mục
`*Multi` là atlas gộp, còn `ZhaoYunWake` / `ZhaoYunExclusWake` là **lớp chữ phụ
đề cảnh thức tỉnh** — các khung trong đó tên `_vi` / `_en` / `_kr` / `_zh_Hant`,
không phải sprite nhân vật.

Kiểm lại bằng:

```bash
python export.py --list        # in cả 21 tên kèm lý do
```

Kết luận: **mọi nhân vật chơi được đều xuất được, không thiếu nhân vật nào.**

178 khung bị bỏ đều là mục kích thước 0×0 tên theo mẫu `X_res-44.png`, mỗi
nhân vật đúng một cái — mục đánh dấu chứ không phải sprite. Công cụ phân biệt
rõ hai loại: mục đánh dấu (bình thường) và khung vượt biên atlas (bất thường,
đáng nghi đọc sai bố cục).

```bash
python export.py --list                       # 397 atlas xuất được + 21 mục thiếu texture
python export.py Cavalry --out <thư_mục>
python export.py --all --out <thư_mục>
```

Kết quả là **nội dung dẫn xuất từ APK có bản quyền** — để ngoài repo, giống
mọi thứ khác trong `.gitignore`.

Phần lớn dữ liệu quan trọng đã có sẵn ở dạng JSON/XML nên không chặn việc đọc
hiểu game.

## Phần Java (classes.dex)

Đo bằng `python dexinfo.py apk/classes.dex vn/apk/classes.dex`:

| | CN | VN |
|---|---:|---:|
| class | 3353 | 9021 |
| method | 22746 | 55929 |
| — có bytecode | 20832 | 50533 |
| — bị xoá thân | **0** | **0** |

**Cả hai dex đều hợp lệ và decompile được bình thường** bằng jadx/dex2jar —
header không hỏng, `file_size` khớp đúng kích thước file, không method nào bị
rút ruột. Toàn bộ lớp SDK đọc được: `kingsoft_pass` 254 class, `xgsdk` 195,
`iflytek` 159, `zxing` 223, `fastjson` 183.

SecNeo ở bản CN **không lấy lớp nào ra khỏi dex**. Đối chiếu từng class khai báo
trong manifest với class có thật trong dex — **thiếu 0 / 26 ở bản CN, 0 / 23 ở bản
VN**:

```bash
python dexinfo.py apk/classes.dex --manifest decrypted/AndroidManifest.xml \
                  --package com.xh.dachui.xsj
python dexinfo.py vn/apk/classes.dex --manifest vn/AndroidManifest.xml \
                  --package com.cmn.buatanew
```

Không có "MainActivity bị mất" — gói `com.xh.dachui.xsj` vốn chỉ có `R*` và
`CallbackActivity`, vì điểm vào Java của game nằm ở gói khác: `org.kingsoft.com.*`
(30 class — `R1_OLChina`, `sngGameEngine`, `SDKHandler`, `TargetActivity`,
`AsrManager`…), **có đủ ở CẢ HAI bản**. Activity `MAIN/LAUNCHER` của bản CN là
`com.xgsdk.client.api.splash.XGSplashActivity`; `R1_OLChina` được khai báo với
action `xg.game.MAIN` + category `DEFAULT` — `xg.game.MAIN` là **tên action**,
không phải tên class.

Vậy SecNeo ở đây là lớp bọc `<application>` (`com.secneo.apkwrapper.ApplicationWrapper`)
cộng thư viện native (`libDexHelper.so`, `libDexHelper-x86.so`) — chống gỡ lỗi và
chống can thiệp lúc chạy, chứ không rút ruột dex.

Thứ thật sự bị mã hoá ở bản CN là hai blob trong assets:
`xgsdk-data-2.0.apk` (35 KB) và `xgsdk-channel-20170726171953.apk` (21 KB) —
**không phải zip, cũng không dùng lớp `sngFile`**, nên `sng_decrypt.py` chỉ chép
nguyên. Đây là gói riêng của XGSDK; nội dung bên trong **chưa kiểm chứng**.

Bản VN **không đóng gói gì cả**: không có `com/secneo`, `com.cmn.buatanew` (23 class)
+ `com.kull.sdk` (299 class) + Facebook SDK đọc được hết, và cũng không có hai blob
XGSDK nói trên. Cần đọc lớp SDK phát hành thì lấy từ bản VN.

Dù sao **logic game không nằm ở Java**. Java chỉ là launcher + SDK (đăng nhập,
thanh toán, thống kê, push). Toàn bộ gameplay nằm ở Lua (đã có đủ) và C++ trong
`libgame.so`.

## Lớp offline

`offline/` — bộ giả lập server chạy ngay trong client, để chơi được khi game đã
đóng cửa. Chặn ở `CallServer`/`CallLocal` (hai hàm Lua toàn cục), dùng lại
`sc/share/` làm luật chơi, thay `CDataManager:initUserDataFromDB` bằng một kho
JSON cục bộ. Hiện chạy được chuỗi đăng nhập → bắt tay → vào game với đủ 33 bảng
dữ liệu; 9/614 handler. Xem `offline/README.md`.

`sng_encrypt.py` — mã hoá ngược về định dạng `sngFile`, để nhét file đã sửa trở
lại game. Round-trip trùng từng byte trên cả 973 file Lua gốc:

```bash
python sng_encrypt.py --selftest vn/obb/assets/sc
cd offline && python run_tests.py && python build.py
```

## Ghi chú

* Comment trong `.lua` trộn cả UTF-8 lẫn GBK (tiếng Trung) tuỳ file.
* Điểm vào: `sc/game.lua`; bảng số liệu: `config/share/KDBGame*.xgg` (JSON).
* Định nghĩa protocol mạng: `conf/*.proto` (protobuf, đã ở dạng text).

## Cách chạy lại từ đầu

Chỉ cần hai file gốc, đặt ở thư mục cha của `work/`. `unpack.py` lo hết phần
giải nén APK/XAPK, giải nhị phân manifest và giải mã tài nguyên:

```bash
python unpack.py ../OAR1_XGSDK_1.25_jinshan_gwbb_sec.apk
python unpack.py "../Búa+Tạ+-+Siêu+Anh+Hùng_1.26.81485_APKPure.xapk" --out vn

python inventory.py                                             # → inventory.json
python build_spec.py
python build_spec.py --assets vn/decrypted/assets --out server-spec-vn
cd server-spec && python build_page.py && python build_page.py ../server-spec-vn
cd .. && python diff_api.py server-spec server-spec-vn
```

## Dịch ngược libgame.so — tìm cái tag

Công cụ: `armdis.py` (dịch Thumb-2 bền, gặp dữ liệu thì nhảy qua),
`xref.py` (tìm chuỗi và từ 4 byte), `findstr.py` (giải tham chiếu chuỗi kiểu
PIC), `picmap.py` (bảng tham chiếu chéo toàn bộ `.text`, nhớ vào `picmap.pkl`).

### Đã xác định được

| Thứ | Địa chỉ / giá trị |
|---|---|
| `CCNode::getChildByTag` | `0x4adaa8` — duyệt mảng con ở `[this+0xB8]`, so `[con+0xC0]` |
| Trường tag trong `CCNode` | `+0xC0` |
| `CCNode::setTag` | `0x4acffa` (`str r1,[r0,#0xc0]; bx lr`) |
| `CCNode::addChild(con,z,tag)` | `0x4ae494`, tag vào qua `r3` |
| Bảng loại node `.xgg` | trong `sngXggParser`, kết thúc ở `0x47f346` |

Bảng phương thức cho Lua nằm trong `.data`, mỗi mục 12 byte
`{tên, giá trị, cờ}`; cờ `1` nghĩa là hàm ảo và giá trị là độ lệch trong
bảng ảo. Các ô đó trỏ tới **lớp bọc Lua**, lớp bọc mới gọi hàm C++ thật:
`getChildByTag` bọc ở `+0x248` → thật ở `+0xfc`; `addChild` bọc ở `+0x224`
→ thật ở `+0xf0`/`+0xf4`/`+0xf8` tuỳ số tham số.

### Kết luận: tag KHÔNG nằm trong .xgg

Ba lối chứng minh độc lập, cùng một kết quả:

1. Quét toàn bộ `.text` tìm lệnh ghi vào `[x+0xC0]`: 133 chỗ, không chỗ nào
   thuộc vùng mã `.xgg`; phần lớn nằm trong openssl/json (trùng offset).
2. Không có lời gọi nào tới `addChild(con, z, tag)` (`+0xf8`) từ vùng `.xgg`
   — bộ nạp chỉ dùng bản 1 và 2 tham số.
3. Bản ghi node = **phần chung 216 byte + phần riêng theo loại** (CCNode 216,
   CCSprite 244, CCScale9Sprite 248, CCButton 260, CCLabelTTF 352). Quét hết
   phần chung, mọi độ rộng: không trường nào chứa đủ bộ tag mà Lua đòi.

Nên `tUIItem` trong `RefleshItem` **không phải** bản sao thuần của node
`.xgg`. Tag phải do thứ dựng ra ô danh sách gán — nghi `G_CTableViewMgr::
CreateTableViewCell`, chưa lần ra.

### Cách duy nhất còn lại để biết chắc

Chạy bản gốc rồi đọc tag thật. Game nạp Lua từ thư mục `sc/` nên chèn được
một đoạn Lua tự viết để duyệt cây và in `node:getTag()`. Đó là sự thật trực
tiếp, không phải suy luận.
