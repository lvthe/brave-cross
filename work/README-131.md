# Bản CN 1.31 `com.wh.dachui` — dịch ngược

Tài liệu này ghi lại bản **thứ ba** của game "Búa Tạ", mới hơn hai bản đã có trong
`README.md`. Mọi con số ở đây đều **đo được**, không suy đoán; chỗ nào chưa chắc
đều ghi rõ là chưa chắc.

## Ba bản

| | CN 1.25 | VN 1.26 | **CN 1.31** |
|---|---|---|---|
| Package | `com.xh.dachui.xsj` | `com.cmn.buatanew` | **`com.wh.dachui`** |
| Version | 1.25.78923 | 1.26.81485 | **1.31.20089** |
| Cây làm việc | `work/` | `work/vn/` | **`bravecross-source/cn131/`** |
| File gốc | 83 MB | — | **`base.apk` 254 MB** |
| `libgame.so` | 10231498 B | 10213832 B | **11306184 B** |
| Lua | 952 | 973 | **1081** |
| Layout cây | kiểu CN | có `obb/` + `decrypted/apk_assets/` | **kiểu CN** (không `obb/`) |
| Ngôn ngữ | Trung | Việt | **Trung** |

Chọn bản bằng biến môi trường `BC_TREE` (xem `cay.py`); mặc định `vn` nên mọi
script giữ nguyên hành vi cũ.

    BC_TREE=cn131 python bank.py --json

## Kết luận trước tiên: định dạng nhị phân KHÔNG đổi

Đây là bản mới hơn của cùng dòng game, không phải game khác. Sáu phép `--scan`
chạy trên cây 1.31 đều **0 lỗi**:

| Phép kiểm | 1.31 | VN 1.26 |
|---|---|---|
| `sng_encrypt.py --selftest` (đối tượng là cây GỐC còn mã hoá) | **1081 file, trùng từng byte, 0 sai** | 973 |
| `xgg.py --scan` | **304 file, 0 lỗi** | 290 |
| `sngxml.py --scan` | **990 file** (537 plist + 453 xml), 0 lỗi, 79336 chuỗi | 919 |
| `anim.py --scan` | **453 xml, 0 lỗi** — 8979 động tác / 142161 xương / **700127 keyframe** | 418 / 641538 |
| `sprites.py --scan` | **434 atlas / 14229 khung, 0 lỗi** | 397 / 12998 |
| `dexinfo.py` | **4095 class / 30477 method, 0 method bị rút thân** | 9021 class |
| `export.py --list` | 20 atlas thiếu texture (không nhân vật nào) | 21 |

⇒ Chạy lại đường ống đã có là đủ; không phải phá định dạng mới. Toàn bộ công việc
là **dò lại địa chỉ** trong `.so` và **tách dữ liệu theo bản** cho khỏi trộn.

Con số **20 atlas thiếu texture** ở dòng cuối nghe như mất mát, nhưng **không
phải** — khung của chúng nằm rời trong `sngSplitData/`. Xem
[mục dưới](#sngsplitdata--khung-rời-của-những-atlas-thiếu-texture).

(chữ "không nhân vật nào" của `export.py` nghĩa là **không nhân vật chơi được**;
trong 20 cái đó vẫn có `ZhaoYunWake`, `LuXunAwakenMulti`, `PlayerMulti` — hiệu ứng
thức tỉnh và nhiều người chơi. Không phải atlas rác.)

## Đã làm ra

| Sản phẩm | Số lượng | Chỗ ghi |
|---|---|---|
| Đặc tả server — 4 file `SERVER_API.md`, `server_api.json`, `rpc-reference.html`, `page_data.json` | **638 API / 735 chỗ gọi** (VN 584) | `bravecross-source/server-spec-131/` |
| `export.py --all` | **16072 file / 469 MB** | `bravecross-source/assets_ref-cn131` |
| `uiart.py` | **7688 PNG** (7689 xuất, 1 hỏng) | `bravecross-source/ui_ref-cn131` |
| `layout.py` | **303** | `bravecross-source/layout_ref-cn131` |
| `scenes.py` | **25** | `bravecross-source/scenes_ref-cn131` |
| Bảng số liệu | **116** | `bravecross-source/data_ref-cn131` |
| Âm thanh | **1650 .ogg** (VN 1500) | `bravecross-source/assets_ref-cn131\audio` |

`uiart.py` hỏng đúng **1** ảnh: `sngDefaultTexture_release aaa.png`, mở đầu bằng
`43 43 5A 21` = `"CCZ!"` — một gói Cocos nén, **không phải ảnh**. Đếm vào chỉ mục
thì Godot sẽ nạp một file rác.

### Âm thanh

`bank.py --json` trên `libfmod.so` 1.31:

| | 1.31 | VN 1.26 |
|---|---|---|
| Kho đọc được | **364 / 367** | 354 / 361 |
| Subsound | **1647** | 1498 |

Ba kho hỏng: `MasterBank`, `MasterBank.strings`, `XiaoQiaoExclus` — **không phải
FSB5**, đúng như bản VN. `bank.py` tự kiểm bằng bộ đọc chứ không ghi byte thô, nên
sai offset thì nó **báo lỗi chứ không im lặng xuất rác**.

Đo thêm một chỗ **khác** bản VN: VN hỏng **7** kho, 1.31 chỉ hỏng **3** — bốn kho
`Vo_ZhiTianXinChang_Usual`, `Vo_ZhiTianXinChang_Wake`, `Vo_ZhuGeLiang_Usual`,
`Vo_ZhuGeLiang_Wake` đọc được ở 1.31 mà không đọc được ở VN. Cả hai bản đều thoát
mã **1** khi có kho hỏng, nên thấy lệnh "đỏ" là **đúng như thiết kế**, không phải
lỗi đường ống — con số cần đọc vẫn in ra ngay trên đó.

## `sngSplitData/` — khung rời của những atlas thiếu texture

`export.py --list` báo **20 atlas** có `.xml` + `.plist` mà texture không được
đóng gói. Đo lại thì chúng **không mất**: khung của chúng nằm rời trong
`decrypted/assets/sngSplitData/`, mỗi khung một file `.pkm` (3429 mục, trong đó
**3401** là `.pkm`; cùng 3429 mục ở `apk/assets/` nhưng **còn mã hoá** — đọc nhầm
cây là ra `41 cf d5 db`, không phải `PKM 10`).
Tên mảnh trùng khít tên khung, kể cả tiền tố atlas: `ZhaoYunWake_res-#zi1.png`
trong plist ↔ `ZhaoYunWake_res-#zi1.pkm` trong `sngSplitData/`.

| Đo trên cả 20 atlas | |
|---|---|
| Khung **không** mang hậu tố ngôn ngữ | **352 / 352 có mảnh** — giống hệt ở **cả hai** bản |
| Kích thước mảnh khớp `sourceSize` trong plist | **352 / 352, 0 lệch** |
| Khung mang hậu tố `_vi` / `_en` / `_kr` / `_zh_Hant` / … | **0 / 274 có mảnh** ở 1.31 — nhưng VN là **61 / 274**, xem [mục dưới](#khung-không-hậu-tố-là-tranh-chữ-tiếng-trung) |

Hai nhóm tách dứt khoát, **không có trường hợp lửng**. 274 khung thiếu đều là
**bản chữ** của chính những khung kia — `ZhaoYunWake_res-#zi1` ↔ `…-#zi1_vi`,
`…-#qiekai1_kr`, v.v. Riêng dòng `0/274`: đó là **của bản 1.31**, không phải hằng
số của game — bản VN ra `61/274`. Và nhóm "không hậu tố" **cũng là chữ Trung**,
không phải hình vẽ trung tính.

Phải so với `sourceSize`, **không** phải `sizeWH`. Hai trường đó khác nhau ở khung
có cắt: `sizeWH` là hình chữ nhật **đã cắt** nằm trong atlas, `sourceSize` là
kích thước sprite **gốc**. Mảnh `.pkm` là cả sprite gốc, nên đem so với `sizeWH`
thì ra "**106/352 lệch**" — con số vô nghĩa, tưởng mảnh sai trong khi mảnh đúng.

Plists còn giữ đủ `atlasXY`, `sizeWH`, `offsetXY`, `rotated`, nên dựng lại atlas
PNG là việc cơ học; hoặc dùng thẳng từng mảnh, đúng cách `uiart.py` đang làm.
`uiart.py` đọc `sngSplitData/` theo **tên khung** và coi mỗi mảnh là một ảnh độc
lập — đường đó dành cho ảnh UI, không phải đường dựng lại atlas.

### Khung "không hậu tố" là tranh chữ tiếng Trung

Giải mã thẳng khung ra PNG rồi mở xem, không suy đoán từ tên:

| Khung | Có ở | Nội dung |
|---|---|---|
| `ZhaoYunWake_res-#zi1` | **cả hai bản** | `七進七出` — **chữ Trung** |
| `ZhaoYunWake_res-#zi1_vi` | chỉ VN | `Tiến Xuất` — chữ Việt |
| `ZhaoYunWake_res-#qiekai1` | **cả hai bản** | `捨生` — chữ Trung |
| `ZhaoYunWake_res-#qiekai1_vi` | chỉ VN | `Tiến Vệ` — chữ Việt |

Khung không hậu tố **không phải** hình vẽ trung tính — nó **là tranh chữ tiếng
Trung**. Bản Việt giữ nguyên tranh đó rồi **phủ** khung `_vi` lên trên. Thế nên
`0/274` của 1.31 khớp hoàn toàn: bản Trung không cần bản phủ, vì khung gốc đã đúng
chữ của nó.

**Hệ quả: không thể dịch bằng cách tráo file.** Chữ **nằm trong ảnh**, nên đổi
ngôn ngữ là phải **vẽ lại ảnh**. Port 1.31 mà muốn tiếng Việt thì từng khung chữ
phải vẽ tay — không có file cấu hình nào thay được.

#### Mỗi bản đóng gói đúng MỘT thứ tiếng — đo mảnh, đừng đo plist

Mỗi thứ tiếng có **atlas riêng**: `Background_<tiếng>_B` và `Font_<tiếng>_T`.
Plist thì **bản nào cũng mang đủ 8 thứ tiếng** (VN 1649 khung, 1.31 1660) — đếm
plist ra hai số gần bằng nhau và **vô nghĩa**, vì plist chỉ là định nghĩa khung.
Texture mới là chỗ nói thật:

| Atlas chữ | VN 1.26 | CN 1.31 |
|---|---|---|
| `Background_vi_B` | **79 / 79** | **0 / 88** |
| `Font_vi_T` | **121 / 121** | 0 / 121 |
| `Background_zh_Hans_B` | 0 / 91 | **91 / 91** |
| `Font_zh_Hans_T` | 0 / 128 | **128 / 128** |
| `Background_de_B` `Background_en_B` `Background_kr_B` `Background_th_B` | 0 | 0 |
| `Font_de_T` `Font_en_T` `Font_kr_T` `Font_th_T` `Font_zh_Hant_T` | 0 | 0 |
| `Background_jp_B` `Font_jp_T` `Background_zh_Hant_B` | **1** khung | **1** khung |

Mỗi bản mang đúng thứ tiếng của mình; **9 atlas tiếng kia trắng ở cả hai bản**.
Ba atlas cuối chỉ có **đúng 1 khung** — khung giữ chỗ — ở cả hai
(`Background_zh_Hant_B` là `1/43`). Nhóm trắng đúng là phần **tải về lúc chạy** —
mà máy chủ thì vắng mặt, nên phần đó **không lấy lại được**. Khớp với kết luận về
máy chủ ở [mục "Đã làm ra"](#đã-làm-ra).

(`Background_vi_B` ghi `0/88` chứ không phải `0/79`: plist hai bản đếm khung khác
nhau — 88 so với 79, `Font_th_T` 123 so với 121. Nên **đừng** lấy số khung của bản
này áp cho bản kia.)

#### Bản Việt vẫn còn chữ Trung

Đo 66 khung chữ (tên mang `#`) không hậu tố trên cây VN: **63 có bản `_vi`, 3
khung không**. Giải mã cả ba — đúng là chữ Trung, không phải hình:

| Khung | Nội dung |
|---|---|
| `XSJieSuoJianZhu_res-#SB` | `神兵解锁` |
| `XSJieSuoJianZhu_res-#XH` | `星魂解锁` |
| `XSJieSuoJianZhu_res-#YLS` | `云来石解锁` |

Ba chỗ này **bản Việt hiện chữ Trung** — tức bản Việt dịch **thiếu**, không phải
dịch hết. (Phạm vi: 66 khung là theo cách đếm tên có `#`; khung chữ không mang `#`
thì phép đếm này không thấy, nên **3** là **cận dưới**, không phải tổng.)

### Nền cảnh cũng vậy — 11/16 atlas đủ 100%

Tài liệu này từng ghi *"`Scene_*.plist` có trong assets nhưng texture của chúng
không có — atlas đó tải về lúc chạy"*, rồi kết luận *"phần nền ghép từ 45 mảnh thì
dựng lại không được"*. Nửa đầu **đúng** (quét cả APK lẫn OBB: không có file nào
tên `Scene_*.png`/`.pkm`); **kết luận sai**. Đo 16 file
`decrypted/assets/img_all/Scene_*.plist`, khớp mảnh theo **cả tên lẫn kích thước
`sourceSize`**:

| Scene | Khung | Khớp cả tên lẫn cỡ |
|---|---|---|
| Arena | 23 | 23 |
| Battlefield | 30 | 30 |
| Beach | 2 | 2 |
| Cavern | 47 | 47 |
| Cemetery | 42 | 42 |
| ChangBanPo | 26 | 26 |
| Desert | 53 | 53 |
| Forest | 27 | 27 |
| **Main** | 56 | **56** |
| Main3_BuildingIcon | 15 | 15 |
| Snow | 28 | 28 |
| Plain | 45 | 25 |
| Main3 | 29 | 2 |
| Main2_BuildingIcon | 19 | 2 |
| **Valley** | 38 | **0** |
| **Main2** | 26 | **0** |

**378/506 khung, 11/16 atlas đủ 100%** — kể cả nền **thành chính** `Scene_Main`
(56/56), cái mà tài liệu cũ tưởng mất sạch. Năm atlas còn lại hụt một phần hoặc
toàn bộ: `Plain` 25/45, `Main3` 2/29, `Main2_BuildingIcon` 2/19, `Valley` và
`Main2` trắng. Texture atlas của chúng **không có** ở cả APK lẫn OBB; còn *vì sao*
thì chưa dò ra — **không** suy ra được từ `UI_Download_File.xgg` (xem ngay dưới).

**Ba cách đếm, ba con số — ghi lại vì tôi đã sập cả hai lần đầu:**

| Cách đếm | Ra | Sai ở đâu |
|---|---|---|
| Tập tên dựng từ `os.listdir()` | 415/506, `Scene_Main` **0/56** | `sngSplitData/` có **28 thư mục con** (`ArmSkills`, `Hero_Head`, `background`, …); `os.listdir` không đệ quy nên khung nằm trong thư mục con bị coi là mất |
| `os.path.exists(<khung>.pkm)` | 471/506 | **Trùng tên giữa các bộ**. `moku.png` của `Scene_Main2_BuildingIcon` khớp một `moku.pkm` chẳng liên quan; nhiều mảnh cùng tên nhưng là **bản hạ nửa cỡ** (`valley_00-01` plist `512x143` ↔ mảnh `256x72`) |
| **Khớp tên VÀ `sourceSize`** | **378/506** | — |

Hai lần đầu đều cho ra kết luận ngược hẳn ("nền thành chính mất sạch") mà không có
gì báo lỗi. Chỉ cách thứ ba mới phân biệt được mảnh thật với mảnh trùng tên.

**Kiểm chéo:** chạy đúng phép đo thứ ba trên cây **VN 1.26** (`BC_TREE=vn`,
`sngSplitData/` 3282 mục) ra **đúng 378/506 và đúng từng dòng** của bảng trên. Hai
bản khác nhau về `libgame.so`, về số Lua, về kho âm thanh, mà phần khung rời thì
trùng khít.

(`UI_Download_File.xgg` trong `conf/` **không** phải danh sách tài nguyên tải về:
nó là bố cục của **màn tải** — 9 khoá, `atlas` 16 mục là atlas của chính màn đó
(`Background_vi_B`, `Blood_Icon`, `Button_2`, `Download_UI`, …), `nodes` 19 nút.
Đừng dùng nó để suy ra cái gì tải về.)

## Dữ liệu 1.31 để NGOÀI repo game

Đây là một lỗi đã xảy ra thật (2026-09-19), không phải chuyện phòng xa:
`data_ref-cn131/` và `layout_ref-cn131/` sinh thẳng vào `bravecross-game/`, mà
`.gitignore` của repo che `data_ref/` và `layout_ref/` nhưng **không che tên nào
thêm hậu tố `-<bản>`**. Hai thư mục hiện ra trong `git status` dạng `??` — chỉ một
lệnh `git add -A` là 32 MB dữ liệu có bản quyền vào thẳng lịch sử repo.

Cách chữa đã chọn: dữ liệu bản khác ra **thư mục ngoài repo**, và **không sửa
`.gitignore`** — sửa ignore mỗi lần thêm bản là cách chữa phải nhớ, và sẽ quên.
`cay._goc_dich()` lo việc này.

**Dọn lần cuối (2026-09-19):** gom hết vào một kho duy nhất,
`C:\Project\game\bravecross-source\`. Trước đó năm thư mục `*-cn131` (942 MB) nằm
ngay cạnh hai repo, còn `work/cn131/` nằm trong cây `brave-cross`.

| Trong `bravecross-source\` | Lấy từ | Dung lượng | File |
|---|---|---|---|
| `cn131/` | `brave-cross/work/cn131/` | **1136,6 MB** | **21.950** |
| `assets_ref-cn131/` | `C:\Project\game\` | 430,5 MB | 16.072 |
| `ui_ref-cn131/` | `C:\Project\game\` | 415,3 MB | 7.688 |
| `layout_ref-cn131/` | `C:\Project\game\` | 22,4 MB | 303 |
| `scenes_ref-cn131/` | `C:\Project\game\` | 8,1 MB | 25 |
| `data_ref-cn131/` | `C:\Project\game\` | 8,0 MB | 117 |
| `server-spec-131/` | `brave-cross/work/` | 1,2 MB | 4 |
| `_artefact/` | `brave-cross/work/` | 1,0 MB | 13 |
| `_pycache/` | `brave-cross/work/__pycache__/` | 0,9 MB | 47 |

**Sửa một con số tài liệu cũ ghi sai:** câu "853 MB, 10666 file" là kích thước của
**riêng `cn131/decrypted/`**, không phải cả cây. Đo cả cây: `apk/` 283,2 MB /
11.283 file **+** `decrypted/` 853,4 MB / 10.666 file = **1136,6 MB / 21.950
file**. Con số **1081 file Lua** cũng là của **một** cây — cả gói có **2162**, vì
Lua tồn tại hai bản: bản còn mã hoá trong `apk/assets/sc` và bản đã giải mã trong
`decrypted/assets/sc`.

**Việc dọn này chữa luôn một cái bẫy thật:** `work/cn131/` nằm trong repo
`brave-cross` mà `.gitignore` **không** che — `git status` liệt nó ở dạng `??`,
nên chỉ một lệnh `git add -A` là 1,1 GB nội dung game có bản quyền vào thẳng lịch
sử. Dời ra ngoài rồi thì không còn gì phải che.

`cay.py` là chỗ duy nhất biết đường: `KHO`, `NGAN` và `goc_cua()` trỏ sang
`bravecross-source/`, nên mọi công cụ đi theo mà không phải sửa chỗ nào khác.
Tài liệu này ghi `bravecross-source/...`; muốn biết đường dẫn tuyệt đối thì chạy
`BC_TREE=cn131 python cay.py`.

## libgame.so 1.31 — những chỗ lệch so với VN

### Bảng lớp Lua: hai kiểu bố trí mảng

Đây là phát hiện quan trọng nhất, và nó đã lật một kết luận cũ ghi sai.

| | VN 1.26 | CN 1.31 |
|---|---|---|
| Kiểu | **`hai-mang`** | **`cap-lien`** |
| Mảng tên | `BASE_TEN = 0x92a5ec`, stride 4 | `BASE_TEN = 0xaa8584`, stride **8** (cặp `(tên, bảng)` nằm liền nhau) |
| Mảng bảng | `BASE_BANG = 0x92a814`, stride 4 | — (không có mảng riêng) |
| Số lớp | 132 | **129** |
| Số bản ghi phương thức | 3523 | **3312** |
| Bảng dùng chung | 1 (`CCSpriteFrame`) | 0 |
| Kết thúc bằng sentinel 12 byte 0 | 131/132 | 128/129 |

Hệ quả: trên 1.31 **`base + 8*i` là SAI** — vài ô GOT không liên quan xen vào giữa,
nên phải **đi tuần tự**, chứ không được tính địa chỉ theo chỉ số. Đó là lý do
`binder.py` phải có hai nhánh đọc.

Ngoài ra `CCSpriteFrame` (lớp duy nhất không có sentinel) đổi chỉ số: VN 113
@0x9596b4 → 1.31 **111 @0xade77c**.

**129 tên của 1.31 là dãy con ĐÚNG THỨ TỰ của 132 tên VN**, thiếu đúng ba lớp:
`CCScale9Sprite`, `CCSprite`, `ProtocolAnalytics`. Đây là phép kiểm chéo độc lập
giữa hai bản — nếu bảng đọc sai thì dãy con không thể đúng thứ tự.

### `setType` — sáu chuỗi hình dạng nằm THẲNG trong `.text`

Cùng một cơ chế, hai cách dựng địa chỉ chuỗi:

| | VN | 1.31 |
|---|---|---|
| Hàm `setType` | `0x2bd438` → thân `0x2bd2d8` | **`0x44312a` → `0x4433a4`** |
| Chuỗi `ccw`/`cw`/`lr`/`rl`/`bt`/`tb` | trong `.rodata`, dựng bằng `ldr r1,[pc,#imm]` + `add r1, pc` | **nằm thẳng trong `.text` tại `0x4434ec..0x443500`**, dựng bằng `adr r1, #imm` |
| Quay 1.0 | `0x4c9030` | **`0x49e474`** |

Sáu chuỗi trong `.text` 1.31 đã đọc từng byte:
`63 63 77 00 63 77 00 00 6c 72 00 00 72 6c 00 00 62 74 00 00 74 62 00 00`.

Cặp số thực **giống hệt VN**; thứ tự so sánh `ccw→cw→lr→rl→bt→tb`. Bốn `blx` ghi
vtable `+0x280` là `lr 0x443454`, `rl 0x443474`, `bt 0x44349e`, `tb 0x44341e`;
`+0x288` dùng **một chỗ dùng chung** `0x4434b8` cho cả bốn — y như VN
(`0x2bd406`), vì `r1`/`r2` được đặt trước khi nhảy tới đó nên từng hình dạng vẫn
khác nhau.

**Sửa một lỗi tài liệu cũ của bản VN**: bảng `HINH_DANG` cũ ghi `tb` = `0x2bd404`
(chính là chỗ dùng chung `+0x288`) trong khi `lr`/`rl`/`bt` ghi chỗ `+0x280`. Chỗ
`+0x280` thật của `tb` là **`0x2bd3ee`**. Từ nay mỗi hình dạng ghi cả hai chỗ.

### `setGray`

VN 5 lớp (có `CCSprite`); 1.31 còn **3**: `Label`, `CCProgressTimer`, `CCButton`
— đúng bằng 5 trừ 2 lớp đã bị bỏ. `Label` có **99 bản ghi ở cả hai bản**.

### Bảng shader

| | VN | 1.31 |
|---|---|---|
| Bảng nguồn | `.data 0x93caec`, 28 nguồn | **`.data 0xabe1d0`, 30 mục** |
| Hàm dựng chương trình | `0x4d8e1c` — `cmp r2,#0x11; bhi.w; tbh` | **`0x4b3c18`** — `cmp r2,#0x11; it hi; pophi; tbb` |
| Vòng đăng ký 18 shader | — | **`0x4b3e64`**, 18 khối stride `0x18` |
| 18 tên | `0x7a9515..0x7cdeb3` (`.rodata`) | **`0x9406f4..0x942429`** |
| Thứ tự chỉ số | chưa dò ra bảng chỉ số | **0..17, đo được** |

Chỉ số 1.31 KHÔNG theo thứ tự địa chỉ: `ShaderPositionTextureColor` ở chỉ số **9**
(địa chỉ `0x9406f4`, thấp hơn hẳn các tên khác), còn `_Orange`/`_Gray`/`_Glow` ở
0, 1, 2. `shaders.py --ten` in ra đủ bảng.

**Hai cái bẫy đã sập, ghi lại để không sập lại:**

1. Địa chỉ đầu bảng `0xabe1d0` **không hề xuất hiện trong file** (quét cả file: **0
   lần**). Từ đó suýt kết luận "bảng không được tham chiếu tới". Sai: các ô GOT giữ
   **`&bảng[i]`** (`0xaa8a74 = 0xabe1e0`, `0xaa8a88 = 0xabe21c`, … — đều là
   `0xabe1d0 + 4k`), nên chỉ địa chỉ *phần tử* xuất hiện, không phải địa chỉ *đầu
   bảng*.
2. Quy ước PC trong hàm dựng rất dễ lấy nhầm: `ldr rN,[pc,#imm]` lấy ô pool tại
   `(địa chỉ + 4) & ~3`, nhưng **`add rN, pc` dùng `PC = địa chỉ + 4` KHÔNG làm
   tròn xuống**. Lấy nhầm (làm tròn cả hai) thì đúng **một trong mỗi cặp** ô GOT
   lệch 2 byte, và đọc ra một giá trị **trông như hợp lệ nhưng là nguồn SAI** — ví
   dụ `0x942a2e` thay vì `0x942b20`, cả hai đều là địa chỉ shader có thật. Đo bằng
   phép đếm: quy ước đúng cho **51/51** ô GOT thẳng hàng 4 byte, hai quy ước kia chỉ
   **27/51** và **26/51**.

Kết quả dò: **17/18 nhánh ra đủ cặp (đỉnh, mảnh)**; phân đỉnh/mảnh theo **nội
dung** (`gl_Position` = đỉnh, `gl_FragColor` = mảnh) nên không phụ thuộc mô hình mô
phỏng. Nguồn **đỉnh dùng chung theo họ** (`0x943147` cho họ `PositionTextureColor`,
`0x94487b` cho họ `Label`), nguồn **mảnh riêng từng lớp** — đúng khuôn VN. Kiểm
chéo: chỉ số đọc được từ ô GOT khớp với giá trị giải ra (`cs 15` → mục `[3]` →
`0xabe1d0+12 = 0xabe1dc` → `0x942870`), sáu phép kiểm đều khớp.

**Chỉ số 9 (`ShaderPositionTextureColor`) không giải tĩnh được** — nhánh của nó
gọi `bl 0x4d5410` rồi `cmp r0, #2`, tức **rẽ theo thiết bị lúc chạy**, không theo
bảng. Ghi là chưa giải được, không đoán.

### Cấu trúc `.so` (để so)

| | VN | 1.31 |
|---|---|---|
| `.text` | `0x203088`, 5595976 B | `0x1fa000`, 6565788 B |
| `.rodata` | `0x7a2410` | `0x9338f0` |
| `.got` | `0x92a07c`, 8068 B | `0xaa7f14`, 24812 B |
| `.data` | `0x92c000` | `0xaae000` |

### Sửa một lỗi tài liệu cũ: hai mảng lớp nằm ở `.got`, không phải `.rodata`/`.data`

`binder.py` có đoạn docstring nói mảng tên và mảng bảng nằm ở `.rodata`/`.data`.
**Sai.** Cả hai đều ở **`.got`** (VN `0x92a07c..0x92c000`, 1.31
`0xaa7f14..0xaae000`), và được `R_ARM_RELATIVE` điền lúc nạp — nên nội dung trong
file **đã** chứa địa chỉ đúng, đọc thẳng ra là được.

## Đã đổi trong `work/`

| File | Đổi gì |
|---|---|
| `cay.py` | **mới** — một chỗ duy nhất biết đang chạy bản nào; `dich()`, `dich_anh()`, `cache()` tự thêm hậu tố bản |
| `binder.py` | đọc được cả hai kiểu bố trí mảng; hằng số theo bản trong `SO_BAN` (`--bang` in bảng lớp) |
| `bank.py` | `SETUP_OFF` theo bản; `_quet_setup()` tự dò và **tự kiểm**, sai thì báo lỗi chứ không xuất rác |
| `shaders.py` | hằng số theo bản (`BAN`); 1.31 có cả bảng nguồn, chỉ số, và cặp (đỉnh, mảnh) |
| `tim_bang.py` | tự dò lại hằng số của `binder.py` từ bất kỳ `.so` nào — **hai bộ đọc độc lập cùng ra một kết quả mới là bằng chứng** |

### `kiem_so()` và `kiem_so_ban()` — cố ý là hai hàm

`kiem_so()` đòi file phải **đúng là bản VN** (`SO_DA_DO`). Dùng cho script còn
mang địa chỉ VN cứng (`move_vt.py`, `picmap.py`).

`kiem_so_ban()` đòi file phải **đúng là bản mà bảng hằng số sắp dùng được đo ra**
(`CO_SO`). Dùng cho `binder.py`, `shaders.py`.

Không gộp làm một, và **không nới `kiem_so()`**: nới ra thì `shaders.py`/`move_vt.py`
sẽ chạy địa chỉ VN trên file 1.31 — đúng lớp lỗi "sai âm thầm" mà cả repo này đang
tránh. Bản chưa đo hằng số (cn125) bị **từ chối thẳng**, không đoán một con số.

### `giu_cho()` — mốc `.ban` phải soi từ thư mục đích ĐI LÊN

Lỗi đã xảy ra thật: `hat_mu` chưa có nên `hat_mu/.ban` không tồn tại; phép kiểm cũ
thấy "không mốc" rồi kết luận "chỗ này vô chủ" — trong khi mốc của thư mục **CHA**
ghi rõ `cn131`. Kết quả: 34 file của bản VN ghi thẳng vào giữa cây của bản 1.31.
Cùng lớp lỗi với `layout.py`: không có gì báo, chỉ có dữ liệu hai bản trộn vào nhau.

## Những gì KHÔNG dịch được, và vì sao

| Thứ | Lý do |
|---|---|
| Nhánh shader chỉ số 9 của 1.31 | Rẽ theo thiết bị lúc chạy (`bl 0x4d5410; cmp r0,#2`), không theo bảng |
| `shaderghep.py`, `move_vt.py` cho 1.31 | Chưa dò `GOC_GOT`/`DANG_KY`/`CTOR` cho 1.31. `move_vt.py` còn đọc `_vts.json` là **dữ liệu dán tay của VN** (34 vtable / 17 lớp, RTTI `0x8de29c`) — dùng cho bản khác là sai hết |
| `text_table.py` cho 1.31 | Bản 1.31 là bản **Trung**: có `conf/text_zh_hans.json` (1.1 MB) và `text_zh_hans2.0.json` (1.0 MB), **không có `text_vi`** |
| Nền cảnh — **5 / 16** atlas hụt khung | `Valley` 0/38, `Main2` 0/26, `Main3` 2/29, `Main2_BuildingIcon` 2/19, `Plain` 25/45. Texture không có ở APK lẫn OBB. **Không phải cả họ `Scene_*`**: 11/16 atlas đủ 100%, kể cả `Scene_Main` (56/56) — tổng **378/506**. Xem [mục `sngSplitData/`](#sngsplitdata--khung-rời-của-những-atlas-thiếu-texture) |
| `emu_*` (11 file) | Cứng vào `com.cmn.buatanew.apk` và đường dẫn máy ảo. **Ngoài phạm vi** — chỉ cần nếu muốn chạy 1.31 trên máy ảo, mà việc đó nặng và không cần cho một bản dịch ngược tĩnh |

## Cách chạy lại

    cd work
    BC_TREE=cn131 python cay.py                 # kiểm cây có đủ không
    BC_TREE=cn131 python binder.py --bang       # bảng lớp theo hằng số của bản này
    BC_TREE=cn131 python tim_bang.py --doi-chieu  # dò LẠI + đối chiếu hai bản
    BC_TREE=cn131 python shaders.py --ten       # 18 shader: tên, chỉ số, nguồn
    BC_TREE=cn131 python bank.py --json         # kho âm thanh + subsound (thoát mã 1: 3 kho hỏng, xem trên)
    BC_TREE=cn131 python split_kiem.py --img    # khung rời: 4653/6111, Scene_Main 56/56
    BC_TREE=cn131 python split_kiem.py --doi-chieu vn   # đối chiếu hai bản

`split_kiem.py --doi-chieu vn` **thoát mã 1**, và đó là **đúng**: nó báo
**60/453 atlas LỆCH**. Hai bản khác nhau thật — phần ngôn ngữ (`ZhaoYunWake`
`10/22` ở 1.31 ↔ `13/22` ở VN) và 1.31 có thêm atlas nhân vật mới
(`ZhaoYunGod`, `ZhaoYunIkkitousen`, `ZhangChunHua`, `UIXianLian`, … chỉ có ở 1.31).
Đừng đọc mã thoát 1 ở đây là đường ống hỏng — phải đọc dòng nó in ra.

Mỗi bước có phép kiểm riêng. Chỗ nào không thoả **cả ba** lối chứng minh độc lập
thì ghi là **chưa chắc**, không ghi là đã xong.
