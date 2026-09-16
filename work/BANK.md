# Âm thanh của bản gốc: bóc từ `.bank`

Bản gốc không có một file âm thanh thường nào (quét `ogg/mp3/wav/m4a/aac/caf/
flac/mid/xm/it/mod` trên cả cây dự án: **0 hit**). Toàn bộ tiếng nằm trong
**361 file `.bank`** ở `work/vn/apk/assets/banks/`, và chúng là **FMOD Studio
bank**, không phải FSB trần.

Công cụ: `work/bank.py` (bóc), `work/event_ref.py` (bảng tra `event:/` → file),
`work/vorbis_probe.py` (quét khoối setup trong một file nhị phân).
Bảng tra chạy cùng: `data_ref/event_ref.json`, và kèm thư mục âm thanh là
`bank_ref.json` (kiểm kê do chính `bank.py` ghi).

## Kết quả đo được

```
python bank.py --all --out ../../bravecross-game/assets_ref/audio
→ 354/361 bank đọc được, 1498 subsound, 56 subsound phải đổi số kênh
```

Bảy bank không đọc được, và cả bảy đều đúng là không có gì để đọc:

| bank | vì sao |
|---|---|
| `MasterBank`, `MasterBank.strings`, `XiaoQiaoExclus` | `RIFF` chỉ có `FMT ` + `LIST` (`PROJ`), **không có chunk `SND `** — bank metadata, không có mẫu |
| `Vo_ZhiTianXinChang_Usual`, `Vo_ZhiTianXinChang_Wake`, `Vo_ZhuGeLiang_Usual`, `Vo_ZhuGeLiang_Wake` | file **1 byte**, chứa đúng ký tự `0` — bản gốc ship file rỗng |

Bốn file 1 byte đó là **dữ liệu mất, không khôi phục được**: client có đường
gọi tới chúng nếu `heroSprite` mang tên tương ứng (`CUIWing.lua:1474-1475` ghép
`banks/Vo_%s_Usual.bank` và `event:/Vo-Usual/Vo_%s_Usual`), nhưng âm thanh
không được đóng gói. Ghi ra đây, không bịa.

## Ba tầng định dạng (đo, không suy)

**1. Vỏ chứa.** `RIFF` + `FEV `, đi từng chunk từ offset 12. Chunk `SND ` nằm
cuối và `SND+8+size == len(file)` ở mọi bank. Blob FSB5 nằm trong ruột `SND `,
nhưng **trước nó là một đoạn đệm 0 dài thay đổi** — đo được: 0, 2, 4, 6, 8,
10, 12, 16, 20, 22, 24, 28, 30 byte. Nên phải **quét tìm chuỗi `FSB5`** (rồi
kiểm `version == 1`), không được ấn cứng kích thước header.

**2. FSB5.** Header `0x3c` byte (bản 1): `0x00` magic, `0x04` version, `0x08`
số subsound, `0x0c` cỡ khối mẫu, `0x10` cỡ bảng tên, `0x14` cỡ khối dữ liệu,
`0x18` codec (mọi bank ở đây là `0xF` = Vorbis FMOD), `0x20` cờ. Mỗi mẫu một
`sample_mode` u64 LE:

* bit 63..34 — số mẫu
* bit 33..8 — `((m >> 7) & 0x07FFFFFF) << 5` = offset trong khối dữ liệu
* bit 7..6 — kênh, theo **cấu hình loa** của FMOD: `0→1, 1→2, 2→6, 3→8`
* bit 5..1 — chỉ số tần số trong
  `[4000, 8000, 11000, 11025, 16000, 22050, 24000, 32000, 44100, 48000, 96000]`
* bit 0 — còn khối phụ

Khối phụ là chuỗi u32: `type = (x >> 25) & 0x7F`, `size = (x >> 1) & 0xFFFFFF`,
`continue = x & 1`. Type `0x0B` = "Vorbis setup ID and seek table", payload là
`setup_id` u32 rồi `table_size` u32.

**Bảng tên không phải các chuỗi nối nhau**: nó là `nsub` u32 **offset**, rồi
các chuỗi nằm **đúng tại offset đó**. Đọc bằng `split('\x00')` là sai — lần
đầu làm thế và sinh ra tên rác kiểu `Archer__\x18`.

**3. Khối setup không nằm trong bank.** Muốn giải mã Vorbis thì cần gói type
`0x05` (codebook), mà FSB5 chỉ tham chiếu nó bằng `setup_id`. Nhưng chính
`libfmod.so` của game mang nguyên văn **32 khối `\x05vorbis`** — chúng là khối
setup chuẩn. Ba id mà bank dùng:

| `setup_id` | offset trong `libfmod.so` | dài |
|---|---|---|
| `0xc55efa16` | 1018984 | 3547 (`0x0ddb`) |
| `0x38aa59ce` | 1035416 | 3832 (`0x0ef8`) |
| `0x84d3ac87` | 1039812 | 3189 (`0x0c75`) |

Ba độ dài này đã **đối chiếu độc lập** với chỉ mục `vcb_list` của vgmstream
(`vcb.h`, 161 blob): khớp tuyệt đối cả ba. Bản của `libfmod.so` và bản của
vgmstream lệch nhau 2 byte ở hai khối (`84d3ac87` tại byte 3117–3144,
`38aa59ce` tại 3750–3781 — bốn trường 4 bit đổi giá trị 12 → 15); **hai bản
đọc được như nhau**, và ta chọn bản của chính game.

Cỡ khối do vgmstream cố định cho mọi setup của FSB5: `exp(2048)` và `exp(256)`
— đó là lý do **một khối setup dùng chung được cho cả 1 kênh lẫn 6 kênh**.

## Cái bẫy lớn nhất: trường `channels` của FSB5

**`channels` là cấu hình loa của FMOD, KHÔNG phải số kênh của dòng Vorbis.**

Đo bằng chính trình giải mã của Godot (libvorbis), trên 18 file ghép từ 6
subsound, mỗi subsound ghép ở ba cách khai 1 / 2 / 6 kênh:

* khối `84d3ac87` (Archer, UI) nạp được ở **cả ba** cách khai, và
  `get_length()` ra **đúng** `số_mẫu / rate` ở cả ba (1,702 s / 0,249 s /
  0,662 s) — khối này không phụ thuộc số kênh.
* khối `38aa59ce` (BGM) **chỉ** nạp được khi khai **2** kênh (42,667 s và
  43,102 s, đúng bằng `số_mẫu / rate`). Khai 1 hoặc 6 đều
  `Error parsing header packet 2: -133` = `OV_EBADHEADER`.

Và số byte trên mẫu của hai bản cùng bài cho thấy trường đó không phải số kênh:
`BGM_Battle_Normal` (FSB5 ghi **1**) 628.305 byte / 2.048.000 mẫu, so với
`BGM_Battle_Normal02` (FSB5 ghi **6**) 601.874 byte / 2.068.897 mẫu — khai 2
kênh cho cả hai thì ra 0,153 và 0,145 byte/mẫu, gần như bằng nhau. Nếu "6" là
6 kênh thật thì bản đó phải nặng gấp ba.

Nên `chon_kenh()` ưu tiên số kênh FSB5 ghi, nhưng nếu khối setup không đọc
được ở số đó thì **tìm số kênh khác làm bộ đọc chạy hết đúng độ dài đã ghi**.
`56/1498` subsound phải đổi — đó là **đúng số liệu của bản gốc**, không phải
sửa cho vừa, và mỗi dòng như vậy được đánh dấu `lech_kenh` trong
`bank_ref.json`.

## Ghép lại thành `.ogg`

Ogg: trang = `OggS` + version 0 + `header_type` + granule 8 byte LE + serial +
số thứ tự + CRC + số đoạn lacing + bảng lacing (255 byte mỗi đoạn, đoạn cuối
< 255) + payload. CRC là **CRC-32 không phản xạ, đa thức `0x04C11DB7`, init 0,
xorout 0** — khác zlib.

* Trang 0: header nhận dạng (`\x01vorbis`, số kênh, tần số, 3 bitrate, byte cỡ
  khối `0xB8`, framing 1), `header_type = 2`.
* Trang 1: header chú thích (`\x03vorbis`, vendor, 0 bình luận) **+ gói setup
  nguyên văn**, `header_type = 0`.
* Từ trang 2: các gói âm thanh. Mỗi gói trong bank là `[u16 LE dài][thân]`;
  `0` và `0xFFFF` là kết thúc / phần đệm cuối.

Byte `0xB8` không phải chọn bừa: nó là `exp(256) | (exp(2048) << 4)`, **trùng
byte với thứ vgmstream ghi** (`build_header_identification`). Granule cộng dồn
theo `samples += (trước + sau) / 4` (vgmstream `vorbis_custom_decoder.c:311`),
và granule trang cuối đặt bằng **số mẫu FSB5 báo**, để bộ giải mã cắt đúng
phần đệm cuối.

Cả 1498 gói đều là gói âm thanh — bit 0 của byte đầu bằng 0 ở **cả 1498**, tức
không có gói header nào được lưu chung trong luồng.

Kiểm chứng cuối: `tools/verify_am.gd` bên repo game nạp từng file bằng
`AudioStreamOggVorbis` và đòi `get_length()` bằng `số_mẫu / rate`.

## `event:/...` → file nào

`bank_config.xml`, `sound_config.xml`, `hit_config.xml` **nằm sẵn trong APK
dạng XML trần** (không mã hóa) ở `assets/banks/`. Cộng thêm chuỗi `event:/`
trong `sc/` của client và 5 mẫu trong `libgame.so`, tổng cộng **448** chuỗi.

Không có chuỗi `event:/` nào nằm trong chính các bank, và `MasterBank.strings`
không chứa đường dẫn dạng văn bản — nên bảng tra phải **suy ra**, và luật suy
ra được đo chứ không đoán:

> Bank được xác định bằng **tên subsound**, không phải bằng đường dẫn.

Đo: `event:/Character/Archer/...` → `Archer.bank` đúng, nhưng cách suy "đoạn
thứ 2 của đường dẫn là tên bank" chỉ đúng **314/375** — sai ở
`event:/Character/Spearmen/Act_Spearman_Wake_Cast` (bank thật tên `Spearman`,
số ít) và `event:/Event/Event_C1M3_EarthBoom` (bank thật tên `EventC1M3`).
Vậy đường dẫn chỉ là **gợi ý**.

Kết quả trên 448 chuỗi: **423 giải được** (413 khớp đúng tên, 10 khớp tiền tố),
**4 là mẫu** để client tự điền tên lúc chạy (`event:/Vo-Wake/Vo_%s_Wake`),
**21 không giải được** và đều được ghi kèm lý do. Hai nhóm thật, đọc ra từ
chính `khong_giai_duoc` của JSON (đừng chép tay lại danh sách này — nó đổi mỗi
lần đo):

* **15 chuỗi: bank có thật, nhưng bank đó không có subsound tên ấy** —
  `Player03` 6 (`Act_Player03_QiangYin_Cast`, `_RouHua_Cast/Imp`,
  `_Wake_Cast/Imp/Pre`), `LuXun` 3 (`_Fight_Cast`, `_Fight2_Cast`, `_Wake_Cast`),
  rồi mỗi bank một cái: `BGM` (`BGM_NewYear`), `BaiHuZi`, `Catapult`, `FaZheng`,
  `ZhangJiaoEvil`, `ZhangLiaoExclus`, `UI` (`UI_TianMIng`).
* **5 chuỗi: không bank nào có subsound tên ấy** —
  `Act_SpearmenN_Wake_Cast`, `Impact_Archery_Flesh_Heavy`,
  `Impact_Archery_Flesh_Light`, `Vo_ZhuGeLiangYoung_Reward`,
  `Vo_ZhaoYun_Event`.

Với nhóm sau thì **đoạn đường dẫn KHÔNG phải bằng chứng**: `event_ref.py` từng
gán hai tiếng `Impact_Archery_Flesh_*` cho `Impact_Electricity` chỉ vì đoạn
`Impact` khớp tiền tố ba bank và nó dài nhất, rồi báo "bank
`Impact_Electricity` không có subsound tên này" — sai, tên đó không nằm ở bank
nào. Nên nhánh dự phòng đó (`_goi_y`) nay chỉ còn xét đoạn đường dẫn **bằng**
tên bank.

**Bốn bank 1 byte ở bảng trên KHÔNG nằm trong 21 chuỗi đó** — chúng là mất dữ
liệu ở tầng bank, không phải ở tầng bảng tra. Chúng chỉ tới được bằng tên do
client ghép lúc chạy: `CUIWing.lua:1474` nạp `banks/Vo_%s_Usual.bank` theo
`heroSprite` rồi `:1475` xin `event:/Vo-Usual/Vo_%s_Usual`. Tên đó **không có
chuỗi ký tự nào trong 973 file Lua** (đo: quét cả `sc/`), nên phép quét chuỗi
không thấy; muốn biết bản gốc có tướng nào tên `ZhuGeLiang` hay
`ZhiTianXinChang` thì phải tra bảng tướng, và ở đây **không khẳng định** là có.

Đuôi tên trong bank **không thống nhất**: `_01`, `01`, và cả `_ 02`
(`Impact_Catapult_Light_ 02`). Nên phép so phải bỏ mọi cụm `[số _ khoảng trắng]`
ở cuối. Một tên có thể có nhiều bản (`_01`, `_02`, `_03`) — bản gốc để FMOD
chọn, **không khôi phục được**, nên `event_ref.json` trả về **cả danh sách** và
bên gọi tự chọn.

Bảy tiếng mà chính `sc/user/Logical/SoundManager.lua` dùng (`SoundDefine`) đều
có trong `UI.bank` — nên đường bấm nút của client không thiếu tiếng nào.
