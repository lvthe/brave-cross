# Lớp offline — chạy "Búa Tạ" không cần server

Game đã đóng cửa, không còn server để đối chiếu. Lớp này thay server bằng một
bộ giả lập **viết bằng Lua chạy ngay trong client**, dùng lại chính luật chơi
mà client đã mang sẵn.

Nền: **bản VN 1.26.81485** (`com.cmn.buatanew`).

## Vì sao chặn được sạch

Toàn bộ giao thức đi qua đúng hai hàm Lua **toàn cục** (`sc/system/rpc.lua`):

```lua
CallServer(nModule, strObjName, strFunction, ...)   -- client -> server   (dòng 155)
CallLocal(strObjName, strFunction, szJsonArgs)      -- server -> client   (dòng 79)
```

Lua tra cứu biến toàn cục lúc gọi, nên ghi đè `CallServer` bắt được **cả** các
lời gọi do `CUIAssist.bindRpcToEvent` sinh ra lúc chạy. Tầng protobuf và socket
trong `libgame.so` không bao giờ được chạm tới — không cần vá `.so`, không cần
vá dex.

Thứ hai, client đã mang sẵn tầng dữ liệu của server. `sc/share/` là mã dùng
chung hai phía; bằng chứng nằm ở `sc/share/share_CDataManager.lua:207`:

```lua
function CDataManager:initUserDataFromDB(strModuleName)
	return 0, nil          -- bản server nạp từ database ở đây
end
```

Hàm chạm database bị rút ruột, còn lại nguyên tầng đọc/ghi (`ModifyUserData`,
`WriteToTable`, `ChangeUserData`). `offline/store.lua` chính là cái database đó.

## Kiến trúc

```
sc/offline/
  init.lua            điểm vào; bịt initUserDataFromDB, cài hook
  net.lua             chặn CallServer + StartRPC, hàng đợi phản hồi bất đồng bộ
  router.lua          sổ đăng ký: tên hàm server -> handler cục bộ
  store.lua           33 bảng GameUser*, lưu ra JSON
  bootstrap.lua       dựng người chơi mới
  log.lua             nhật ký, trong đó có danh sách API còn thiếu
  handlers/login.lua  chuỗi đăng nhập -> bắt tay -> vào game
  handlers/chapter.lua chiến dịch: bắt đầu ải, thắng, thua — gọi luật server
                      có sẵn trong sc/share/share_ChapterLogic.lua
  handlers/achieve.lua thành tựu: đạt / nhận thưởng — gọi luật gốc
                      sc/share/AchieveLogic.lua (hướng dẫn tân thủ chờ nó)
  handlers/statewar.lua Quốc chiến: chỉ câu hỏi giờ mở lúc vào Main; trả
                      "chưa có lịch" để lớp "đang tải" của client tắt
  handlers/mysterious.lua Cửa hàng bí ẩn: ClientRefresh theo mốc giờ; trả qua
                      đường chung OnReciveResponse, KHÔNG sinh hàng (luật đó
                      chỉ server gốc có)
test/
  mock.lua            giả lập môi trường game để test trên PC
  run.lua             bộ test chuỗi vào game
```

**Phản hồi bắt buộc bất đồng bộ.** Server thật không trả lời trong lòng lời gọi;
trả đồng bộ sẽ tái nhập logic client giữa chừng và phá vỡ giả định của nó. Nên
`net.lua` xếp hàng phản hồi và đẩy ra ở khung hình sau qua `S_CCSchedule`.

**Không phải handler nào cũng dùng bao bì `{err=, data=}`.** Ví dụ
`OnServerEnterGame` nhận 5 tham số vị trí (`ClientGameWorld.lua:37`). `ctx:reply`
dùng cho loại bao bì, `ctx:call` cho loại tham số vị trí.

**`ctx:reply` tự dò tên handler lúc chạy.** Nó dựng danh sách ứng viên đúng thứ
tự `build_spec.candidates()` thử (bỏ tiền tố `Client`/`Req`/`Request`, thêm `On`)
rồi chọn tên nào thực sự phân giải ra một hàm theo đúng luật của `CallLocal`.
Quy tắc chuỗi đơn thuần sai 25/415 trường hợp — `ClientCatchFishReq` phải về
`OnCatchFish` chứ không phải `OnCatchFishReq` — và cách dò này còn bắt được cả
handler do `bindRpcToEvent` sinh lúc chạy. Không tên nào phân giải được thì nó
ghi `WARN` chứ không im lặng để client treo.

**Tham số `nil` được giữ chỗ bằng `cjson.null`.** `ctx:call(obj, fn, 1, nil, 3)`
gửi đủ ba tham số; bên client tham số giữa về thành `cjson.null` — đúng thứ
server thật cũng buộc phải gửi, vì transport là JSON và JSON không có "vắng mặt"
ở giữa mảng.

## Trạng thái

> **Cập nhật 28/10/2026** — số dưới đây đo lại trên bản mới nhất
> (`python _phu_rpc.py`, `python run_tests.py`). Xem mục *Cập nhật 28/10* ở cuối
> tệp để biết đã chơi thử tới đâu.

| | |
|---|---:|
| Handler đã hiện thực | **59** / 511 hàm server client có gọi |
| API nuốt lặng lẽ (nhịp tim, thống kê) | 4 |
| Test đạt — lớp offline | **152 / 152** |
| Test đạt — `deploy.py` | 28 / 28 |

Đã chạy được: đăng nhập → danh sách máy chủ → bắt tay → giờ server →
`ClientEnterGame` → `G_DataManager:Init` với đủ 33 bảng → danh sách hoạt động
→ `RepaleceScene("Main")`, lưu và nạp lại tiến trình. Trong Godot
(`bravecross-game/tools/vao_main.gd`) cả chuỗi này chạy bằng mã gốc tới cảnh
chính.

Tên bảng lấy từ `EventManagerTableName` (`sc/share/EventManager.lua:1086`), tên
trường lấy từ chỗ client đọc. **Giá trị** khởi tạo lấy từ **chính bảng cấu hình
của bản gốc**: `KDBGameCommonConfig` có mục `<bảng>Reset` cho 10/33 bảng, và mã
server dùng chung nạp người chơi đúng kiểu đó (`LotteryLogic:Reset`). Bản trước
tự đặt kim cương 5.000 và thống soái 10 — bản gốc ghi 0 và 6. Chỉ còn `ĐẶT` những
gì server cấp cho từng tài khoản (Uid, tên, phiên); 23 bảng không có mục Reset
thì để rỗng.

Tên trường phải khớp chỗ client ĐỌC — đã sửa ba chỗ đoán sai: tên nhân vật là
`CharacterName` (không phải `UserName`), phản hồi đăng nhập là `uid` / `session`
viết thường, danh sách máy chủ là `RecomendList`.

## Chạy test

```bash
pip install lupa
python run_tests.py            # lớp offline — 33 check, cần lupa
python test/test_deploy.py     # deploy.py  — 28 check, không cần gì thêm
```

`test_deploy.py` thay hàm `adb()` bằng một máy giả (dict đường dẫn → bytes) nên
chạy được khi không có thiết bị nào cắm vào. Nó khoá ba lời hứa của `--flags`:
không đụng vào file không phải XML thuần, không báo "đã thêm" khi phép chèn
không ăn, và không đẩy gì lên máy khi không sửa được gì. `--flags` là lệnh duy
nhất ghi đè một file của game trên máy thật, nên đây là chỗ đáng có test nhất.

## Đóng gói và tha lên máy

```bash
python build.py
```

Sinh hai bản trong `deploy/`: `plain/` (nguyên văn) và `sng/` (đã mã hoá đúng
định dạng `sngFile` của game — bộ mã hoá đã kiểm chứng round-trip trùng từng
byte trên cả 973 file Lua gốc).

Điểm chèn là `sc/user/require.lua`, thêm đúng một dòng `require("offline.init")`
ở cuối. Không phải đóng gói lại APK: `package.path` của game ưu tiên external
storage rồi download path **trước** assets (`sc/game.lua:60`) — đây vốn là cơ
chế cập nhật nóng của chính game.

### Cài adb (một lần)

```bash
winget install --id Google.PlatformTools --exact
```

Tải từ `dl.google.com`, winget tự kiểm hash. Sau khi cài phải **mở lại
terminal** thì PATH mới có `adb` — nhưng `deploy.py` cũng tự dò các vị trí cài
thường gặp nên chạy được ngay cả trong cửa sổ cũ.

### Đẩy lên máy

Dùng `deploy.py` thay vì `adb push` tay — nó tự dò thư mục nào ghi được rồi
đẩy vào tất cả, nên không phải đoán:

```bash
python deploy.py --status    # máy, ABI, quyền, thư mục ứng viên
python deploy.py --push      # đẩy (thêm --sng nếu bản plain không ăn)
python deploy.py --flags     # bật DebugTestMode / CloseGuide trong set.xgg
python deploy.py --log -f    # theo dõi offline.log
```

Ứng viên thư mục ghi đè, đọc từ `Cocos2dxHelper.init` trong dex bản VN:

| nguồn | đường dẫn |
|---|---|
| `getExternalFilesDir()` | `/sdcard/Android/data/com.cmn.buatanew/files` |
| `getExternalStorageState()` | `/sdcard` (app targetSdk 23 nên vẫn ghi được) |
| `getFilesDir()` | `/data/data/com.cmn.buatanew/files` — cần root |

**Đo lại 26/10/2026 (hook `fopen` trên LDPlayer):** `package.path` thật của bản
này là `/storage/emulated/0/assets/sc/?.lua`, rồi
`/data/user/0/com.cmn.buatanew/files/download/sc/?.lua`, rồi
`/data/user/0/com.cmn.buatanew/files/assets/sc/?.lua`. Tức nhánh "external" là
**`/storage/emulated/0/assets`**, không phải thư mục `Android/data/<pkg>/files`
— đẩy vào đó thì lớp offline mới được nạp. Bản **`sng`** là bản chạy được
(bản `plain` đã thử và bị bỏ qua).

Bật công tắc gỡ lỗi có sẵn, trong `set.xgg` ở thư mục ghi được của game:

```xml
<DebugTestMode>true</DebugTestMode>
<CloseGuide>true</CloseGuide>
```

## Cách làm tiếp

`offline.log` là danh sách việc, và nó tự sinh theo đúng thứ tự game cần. Mỗi
lần client gọi một API chưa có handler, dòng này xuất hiện:

```
[14:22:07] THIEU    G_ActivityStock.ClientBuyStock  module=5  args=["S001",10,99]
```

Hai loại dòng `WARN` cũng thuộc danh sách việc: *"khong tim thay handler nao"*
(tên client chờ không khớp ứng viên nào — phải truyền tên tay cho `ctx:reply`)
và *"client khong co ham nay"* (đã trả về một tên không tồn tại).

Cứ chơi, đọc log, viết handler cho cái xuất hiện, lặp lại. Tra chữ ký và hình
dạng phản hồi ở `../server-spec-vn/rpc-reference.html`; hình dạng payload chính
xác thì đọc thẳng hàm `On*` tương ứng trong mã client — mã nguồn client có đủ.

## Chạy game để thử: dùng emulator ARM, không cần điện thoại

Game chỉ có `armeabi-v7a` — **32-bit**. Điện thoại đời mới không chạy được, và
đây không phải chuyện cấu hình: chip từ Snapdragon 8 Elite trở đi bỏ hẳn
32-bit ở mức phần cứng, máy không có cả `/system/bin/linker`. Đã đo trên
Galaxy Z Fold7: `ro.product.cpu.abilist` chỉ có `arm64-v8a`, `abilist32` rỗng.

Giả lập kiểu LDPlayer/Nox thì cần VT-x, mà VT-x lại bị Windows chiếm khi VBS
bật — phải tắt tính năng bảo mật mới dùng được.

Đường sạch nhất: **emulator của Android SDK chạy ảnh hệ thống ARM**. Nó *giả
lập* CPU ARM qua QEMU chứ không *dịch*, nên không cần VT-x và chạy được ngay
khi VBS đang bật.

Ba chỗ vướng, ghi lại để khỏi mò lại:

* **Emulator 37.x đã bỏ ARM 32-bit** (`CPU Architecture 'arm' is not supported
  by the QEMU2 emulator`). Phải dùng bản cũ — `30.2.2` vẫn tải được ở
  `dl.google.com/android/repository/emulator-windows-6885378.zip` dù không
  còn được liệt kê trong repo XML.
* **Chỉ ảnh API 23 trở lên mới có `kernel-ranchu`.** Ảnh API 19/22 chỉ có
  `kernel-qemu` của engine cổ điển, mà engine đó đã bị gỡ. Nên API 23 là bản
  nhẹ nhất còn dùng được, dù Android 6 khá nặng cho CPU giả lập.
* **`sdkmanager` trong cmdline-tools mới đã khai tử**, không cài được các gói
  cũ. Phải lấy `cmdline-tools` bản 12 trở về trước. Thiếu
  `platforms/android-23` thì emulator báo `Broken AVD system path`.

```bash
emulator -avd <ten> -no-snapshot -no-boot-anim -gpu swiftshader_indirect
```

`-gpu off` làm game chết ở `GLThread` (`No configs match configSpec`), còn
`-gpu guest` làm `surfaceflinger` chết. Chỉ `swiftshader_indirect` dựng được
EGL.

### Quyền lưu trữ trên Android 6 — phải cấp tay

Game khai `targetSdkVersion 23`, đúng ngưỡng Android bắt đầu áp quyền lúc
chạy, và nó không có code xin quyền kiểu mới. Hệ thống từ chối thẳng:

```
Not granting permission android.permission.READ_EXTERNAL_STORAGE to package com.cmn.buatanew
```

Không có quyền đó thì game **không đọc nổi file OBB** — toàn bộ tài nguyên.
Nó vẫn khởi động, vẫn nạp `libgame.so`, vẫn dựng EGL, rồi chết vì không có dữ
liệu. Cấp trước khi mở game:

```bash
adb shell pm grant com.cmn.buatanew android.permission.READ_EXTERNAL_STORAGE
adb shell pm grant com.cmn.buatanew android.permission.WRITE_EXTERNAL_STORAGE
```

## Đã kiểm chứng được gì trên emulator

**Kull SDK KHÔNG chặn.** Đây là rủi ro lớn nhất của cả lớp offline, và nó đã
bị loại. Log cho thấy game vào thẳng activity, nạp hết thư viện native rồi
khởi động Cocos2d-x, không có cổng đăng nhập nào cản:

```
Start proc com.cmn.buatanew/org.kingsoft.com.R1_OLChina
sngDownload: loadlib by name Crasheye / fmod / fmodstudio / Bugly
sngDownload: loadlib by name game          <- libgame.so nạp được
Cocos2dxActivity: model=sdk_phone_armv7, isEmulator=true
OpenGLRenderer: Initialized EGL, version 1.4
Displayed com.cmn.buatanew/org.kingsoft.com.R1_OLChina: +39s948ms
```

Không có `FATAL EXCEPTION` nào của chính `com.cmn.buatanew`.

## Vẫn chưa kiểm chứng

1. **Đường ghi đè.** Chưa biết `libgame.so` hỏi JNI thư mục nào.
   `deploy.py --push` đẩy vào tất cả ứng viên nên không phải rào cản, chỉ là
   chưa xác nhận cái nào ăn.
2. **File nguyên văn hay đã mã hoá.** Bộ nạp nhiều khả năng kiểm magic
   `sngFile` ở cuối để quyết định có giải mã không, nhưng đây là suy đoán từ
   định dạng. Thử `plain/` trước, không được thì `sng/`.
3. **Game có chơi được không.** Mới chứng minh nó *khởi động* được. Emulator
   ARM chậm tới mức mỗi thao tác mất hàng chục giây, nên chưa ai thấy nó vẽ ra
   màn hình đầu tiên.

---

## Cập nhật 28/10/2026 — chơi thử thật trên LDPlayer

Toàn bộ mục *"Vẫn chưa kiểm chứng"* phía trên **đã trả lời**: đường ghi đè là
`/storage/emulated/0/assets/sc`, bản nạp được là **`sng`**, và game **chơi được trọn
vẹn** trên LDPlayer 9 (boot ~20 s, cài 3 s). Nhật ký chi tiết: `GHI-CHU-TRACE-2026-10-26.md`
từ §10 trở đi. Tóm tắt:

**Đã kiểm trong game (có số đo)**

| việc | bằng chứng |
|---|---|
| Đăng nhập, vào Main, không vòng lặp | `vao game lan 1` |
| Quà login ngày — nút "Nhận" | Ngọc 0→10; `GameUserItem["1"]=10`, `["4"]=20` |
| Hộp thư | panel mở, hết quay vô tận |
| H.Động, Hộp Thư, Rương, Doanh Trại | mở được; toạ độ ở §10.6 |
| Quay hộp (miễn phí) | Dá Lam ×1, **Mảnh Hoa Hùng ×2** (`GameUserHero["47"].HeroFragment=2`) |
| Bán vật phẩm | vàng +20, `ItemCount` 1→0 |
| Dùng vật phẩm | Khối Vàng ×3 → vàng **+3000**, 10→7 |
| Vào trận + thắng | `L_N_01_03` 3 sao, Lv3→5, thưởng rơi Binh Hồn ×6 (`ArmySoul=6`) |
| Càn quét 1 lần | thể lực −6, `GameUserItem["10"]=4` |
| Túi | 4 tab, số liệu khớp file lưu |

**Còn mở (không phải lỗi, đã ghi lý do)**

1. **Trace native** — LDPlayer dịch ARM bằng libhoudini nên `libgame.so` chỉ map
   `r--p`; Frida không vá được byte thi hành ⇒ muốn trace phải có **ARM thật**.
2. ~~**Cửa hàng bí ẩn**~~ — **ĐÃ LÀM 28/10** (§23.1): sinh hàng + mua chạy trên bảng
   cấu hình gốc `GameMStroeGoodsCrateConfig` / `GameSecretShopConfig`
   (`KDBGameCommonConfig`). Đo: 8 món, mua −39.000 vàng, món `State = 1`.
   Panel khoá **Lv18** trên tài khoản thử nên mở bằng hàm.
3. ~~**Hộp hồn (魂匣)**~~ — **ĐÃ LÀM 28/10** (§23.2): `GameSoulBoxConfig` đủ dữ liệu;
   1 lượt = 3 món bể MỘT + 2 món bể HAI (khớp 5 plug `HunXiaAnima`), giá 250 kim cương,
   bảo hiểm 10–19 lượt. Hộp hồn là SỰ KIỆN `TimeLimitSoulBoxHero` ⇒ offline bật thường trực.
4. **Quét 10** — bản gốc khoá ở VIP 0 (`CUIChapterInfo.lua:430-455`).
5. **Nút Túi** — có trong cây UI nhưng **không được vẽ** ở cảnh Main (chỉ hiện trong
   bước hướng dẫn); mở bằng hàm `g_CUIMain:onTouchEnd_onBackpackUI`.

**Bảng tra bẫy UI** → [`BAY-UI.md`](BAY-UI.md): 12 bẫy của client gốc (popup thưởng,
thoại hướng dẫn, bước chặn `OnShowUI`, Hộp Thư quay, panel Nhận cánh không có nút đóng,
nút Túi vô hình, Quét 10 ở VIP 0…), mỗi cái ghi lớp/hàm sinh ra, cách chữa và trạng
thái; cộng 6 bẫy không-phải-UI (vòng lặp vào game, trùng tên RPC, `tReportsData` nil…)
và quy trình 5 bước khi gặp màn hình nuốt cú bấm.

**Công cụ mới trong thư mục này**

| tệp | việc |
|---|---|
| `_phu_rpc.py` | đối chiếu handler với lệnh client gọi; `--thieu`, `--la` (bắt tên gõ sai) |
| `_phu_nhom.py` | nhóm các lệnh còn thiếu theo hệ |
| `frida/chay_trace.py` | gắn script Frida (spawn/attach) — dùng cho SDK hook, không trace được ARM trên LDPlayer |
| `deploy.py --push --sng` | dựng + đẩy lớp offline lên 5 thư mục ứng viên |
| `_chup_ld.ps1` | chụp cửa sổ LDPlayer |
| `sc/offline/thu_hai_muc.lua` | ĐỒ THỬ: mở panel Cửa hàng bí ẩn + Hộp hồn rồi gọi đúng RPC (hai lối vào bị khoá theo cấp/tài khoản) |
| `sc/offline/nang_cap.lua` | ĐỒ THỬ: đặt Lv90 / VIP15 + đặt 27 cờ mở chức năng theo bảng cấp của `CGuideEvent` (§24.1) |
| `sc/offline/luot_panel.lua` | ĐỒ THỬ: mở lần lượt 21 lối vào ở cảnh Main, log cái nào mở/lỗi (§24.2) |
| `sc/offline/thu_tinh_nang.lua` | ĐỒ THỬ: gọi 9 lệnh vừa nối vào luật gốc (thiên mệnh/trang bị/tướng/đấu trường/thuốc) (§25.2) |

## Cập nhật 30/10/2026 — NHÀ CỬA (建筑) chạy trên LDPlayer

Ba khoá xây dựng **đã đăng ký từ 28/10** (`handlers/tinh_nang.lua:369-383`) nhưng
chưa bao giờ chạy: chúng gọi `chayTho("G_BuildingLogic", …)` mà **`g_BuildingLogic`
chưa từng được tạo** (dòng tạo ở `sc/share/share_building.lua:10` BỊ CHÚ THÍCH), và
`G_DataManager:GetBuilding` **không có định nghĩa** ở đâu ⇒ mọi lượt nâng nhà trả
mã 1; màn Binh Doanh còn nil-index ở `CUIBarracks.lua:611/623/722/804`.

**Thêm mới: `sc/offline/nha_cua.lua`** (nạp từ `offline/init.lua`, cài trong
`Offline:start()`), làm bốn việc:

1. **Dựng lại `G_ConfigManager.BuildingConfig`** — bản gốc chết ở BA chỗ (tên bảng
   `share_configManager.lua:51`, tên cache `:125`, hàm cập nhật `:211` đều bị chú
   thích) nên `GetBuildingConfigWithLevel` luôn trả nil. Module đọc thẳng tệp qua
   `ClientConfigManager:GetConfigTableWithName("KDBGameBuildingConfig")` rồi xếp
   `[id][cấp] + MaxLevel` đúng như `updateBuildingConfig` (:1047-1083).
2. **Bảng mới `GameUserBuilding`** (thêm vào `OfflineStore.TABLES`), bản ghi
   `{BuildingID, BuildingLevel, UpgradeBeginTime, UpgradeLeftTime, IsUpgrading}`,
   dựng cấp 1 cho mọi nhà CÓ trong cấu hình (**id 4..12** — ba nhà gốc 1/2/3 không
   có dòng nào trong `KDBGameBuildingConfig`, không bịa).
3. **`CDataManager:GetBuilding`** (phương thức bản gốc thiếu) trả bản ghi kèm
   `BaseInfo` dựng từ cấu hình cấp hiện tại.
4. **Cài lại bốn hàm trên `BuildingLogic`** — `UpgradeBuilding` ·
   `CompleteBuildingUpgrade` · `CompleteBuildingUpgradeWithDiamond` ·
   `CancelBuildingUpgrade` — vì thân gốc gọi `GetResource` (chỉ có `getResource`
   chữ thường) và `AddUserEx` theo đường máy chủ nên gọi vào là chết tiếp.
   Giữ BA con số bám được vào bản gốc: giá = `ResourceForUpgrade` của cấp hiện tại;
   EXP = `ExWhenComplete` của cấp CŨ, cộng TRƯỚC khi +1 cấp (`:126-130`); giá kim
   cương = `ceil((giây/60/5)^1.1)` (`:209-212`). Phần **[MOI]** (quyết định của lớp
   offline, ghi rõ trong đầu tệp): "đang nâng" là cờ `IsUpgrading` (TimeForUpgrade
   = 0 ở CẢ 126 dòng cấu hình), mức khởi tạo cấp 1, hỏng ⇒ 6000
   `ILLEGAL_COMMMAND`.

**Hai lỗi bắt được trong lúc làm** (đã sửa, ghim trong bộ thử):

* `pcall(function() return G_UserLogic:GetBaseInfo() end)` chỉ bắt giá trị ĐẦU —
  mà hàm ấy trả `(bResult, baseInfo)` ⇒ biến nhận là `true`, mọi lượt nâng nhà ra
  6000 dù đủ vàng. Nay nhận cả hai và lấy cái nào là BẢNG.
* Bốn đường RPC nay do module tự đăng ký (ghi đè handler cũ): bản cũ trả
  `ctx:call(…, "", "", mã, {})` **không có `gui`**, nên callback toàn cục
  `OnCompleteBuildingUpgrade(tData)` nhận `tData = nil` rồi nổ ở `tData.err`;
  còn `ClientCancelBuildingUpgrade` **chưa từng được đăng ký**. Nay Complete/Cancel
  trả `{err, data}` đúng `api.lua:64-65`; hai khoá `cb=''` giữ im lặng.

**Đo được**

| phép đo | kết quả |
|---|---|
| Boot trên LDPlayer (logcat) | `nha cua: da cai (cau hinh=true, g_BuildingLogic=true)`; `126 handler` (thêm 1: huỷ nâng) |
| Bộ thử logic `_thu_nha_cua.py` (chạy CHÍNH tệp trên máy bằng lua51.dll, API client giả) | **24/24 DAT**: nâng trừ đúng vàng · đang nâng → 6000 · hoàn thành +1 cấp + EXP cấp cũ · đổi kim cương · huỷ không hoàn vàng · RPC trả `{err,data}` |

**Chưa thử trong game**: bấm nút nâng nhà thật (thuộc lượt chơi của chủ dự án —
mở Binh Doanh/main, chọn nhà, nâng). Mọi con số kinh tế là của cấu hình gốc; luật
"đang nâng" và mức khởi tạo là của lớp offline, đã khai.

### Cùng lượt: MUA LƯỢT ĐÁNH LẠI ẢI

`G_ChapterLogic.ClientBuyChapterBattleResetCount(strChapterKey)` — lệnh của HAI nút
trong popup chi tiết ải (`CUIChapterInfo.lua:2253`, `:2399`). Trước đó nó rơi vào
nhóm "chưa có handler", nên bấm nút là treo lớp tải.

Luật **là mã gốc còn sống**, không viết lại: `ChapterLogic:costDiamondToResetBattleCount`
(`share_ChapterLogic.lua:1106-1175`) — giá theo bảng `ResetBossChapterCountList`
(theo `BattleResetCount + 1`, quá cuối bảng lấy mục cuối), trần `GetMaxBattleCount()`
qua `GetVipConfig`, trừ kim cương, `BattleResetCount + 1`, `PassMissionCount = 0`,
lưu báo cáo. Thân gốc **không trả mã lỗi**, nên handler trả **1** khi hỏng và KHAI RÕ
đó là chỗ port thêm mã. Thành công trả lời ĐÚNG callback phương thức
`G_ChapterLogic.OnServerBuyChapterBattleResetCount(key)` (UI gọi `refreshUI()`).

Đo: `python _thu_nha_cua.py _thu_mua_luot.lua` → **6/6 DAT** (proxy lớp cha, phong bì
trả lời, ba nhánh lỗi: luật trả false · luật NÉM lỗi · key rỗng). Trên LDPlayer:
`127 handler` (thêm một) sau khi push + khởi động lại.

⚠ **Bộ thử dùng chung khung**: `python _thu_nha_cua.py [tệp.lua]` — mặc định là
`_thu_nha_cua.lua` (NHÀ CỬA), truyền `_thu_mua_luot.lua` cho bộ thử này.

### Cùng lượt: NHẬN THƯỞNG THƯ (4 lệnh)

`ClientSaveMailPrizeWithMailID` · `ClientSaveMailPrizeWithMailIdList` · `ClientSaveAllMailPrize` ·
`ClientSetMailReadWithMailID` (tệp mới `handlers/hop_thu.lua`). Trước đó cả bốn **không có
handler** ⇒ bấm "nhận" trong Hộp Thư là lớp tải quay mãi.

Luật là **mã gốc còn sống**: `MailLogic:saveMailPrizeAndStatus` (`:645`, nhận thưởng qua
`G_ChapterLogic:SetDataWithPrizeList`), `saveMailPrizeList` (`:739`, trả danh sách **thật sự
vừa nhận**), `setMailReadWithMailID` (`:589`). Gọi qua proxy lớp cha, như `tinh_nang.lua`.

Hai chỗ dễ sai, đã ghim: `OnServerSaveAllMailPrize` đọc **đối số vị trí 1** là mã lỗi (không
phải `{err,data}`); và `goi()` của handler trả `(ok, <giá trị 1 của hàm gốc>, ...)` — nên
`getMailWithId` phải đọc **ba** giá trị (`ok, bResult, mail`) — bộ thử bắt được đúng lỗi này
ở lượt đầu.

Đo: `python _thu_nha_cua.py _thu_hop_thu.lua` → **11/11 DAT** (nhận một · nhận lại → 2103 của
luật gốc · nhận loạt trả đúng danh sách · nhận tất cả mã 0 · đã đọc · id lạ). Trên LDPlayer:
**131 handler** (thêm bốn) sau push + khởi động lại.

### Cùng lượt: CƯỜNG HOÁ TRANG BỊ (sửa hai handler đã có)

⚠ **`_phu_rpc.py --thieu` BÁO SAI hai khoá này**: `handlers/tinh_nang.lua:138/148` đã đăng ký
`ClientIntensifyEquipment` / `ClientAutoIntensifyEquipment` từ 28/10 — nhưng chúng gọi luật gốc
rồi **không cộng cấp** (thân `IntensifyEquipment` chỉ TRỪ VÀNG), và trả callback thiếu tham số.
Hậu quả: bấm cường hoá **mất vàng mà trang bị không lên cấp**.

Tệp mới `handlers/trang_bi_cuong_hoa.lua`, nạp **SAU** `tinh_nang` (đăng ký đè — log có cảnh báo
"dang ky de handler", đúng như thiết kế). Ba bước cộng cấp chép từ bản client ĐÃ CHÚ THÍCH
(`ClientEquipmentLogic.lua:330-386`): `SetEquipIntensifyLevel(cấp+1)` → `updateEquipData(equipment)`
(đặt lại giá cấp kế, `:1273`) → callback.
Trả lời đủ tham số: `OnServerIntensifyEquipment(h, p, cấpMới)` ·
`OnServerAutoIntensifyEquipment(h, p, sốCấpĐãCộng, giáCấpKế)`.

**Tự động** là TÁI DỰNG `[GHIM]`: `share` chỉ KIỂM rồi trả true, vòng cộng cấp nằm trong máy chủ
đã chết → lặp gọi đúng luật gốc từng cấp tới khi nó từ chối (hết vàng / chạm trần / hết
`HeroLevel`), chốt an toàn 200 vòng; hết vàng ở cấp đầu ⇒ **thành công 0 cấp** (đúng Mốc 54).

Đo: `python _thu_nha_cua.py _thu_trang_bi.lua` → **10/10 DAT** (cộng cấp · trừ đúng vàng ·
tự động +6 cấp · hết vàng 0 cấp · tham số sai mã 2 · chạm trần mã 1102 của luật gốc).
LDPlayer: boot log `trang bi cuong hoa: da dang ky lai 2 khoa`, vẫn **131 handler** (ghi đè,
không thêm khoá mới).

### Cùng lượt: NÂNG PHẨM + TẨY LUYỆN trang bị (sửa hai handler đã có)

`handlers/trang_bi_pham.lua` ghi đè `ClientPromoteQualityEquipment` / `ClientRecastEquipment`
của `tinh_nang.lua:158/168` — hai handler cũ chỉ gọi luật gốc, mà luật gốc **bỏ sót phần cuối**
giống `IntensifyEquipment`:

- `PromoteQualityEquipment` (`share_EquipmentLogic.lua:792-877`) đổi `Quality + 1` nhưng **không
  tính lại thuộc tính phụ** → nay gọi `updateAppendProperty` (`share_EquipmentPropertyLogic.lua:562`):
  GIỮ `BaseValue`, tính lại `Value` = coef·(Base·Quality−0,3)·(hệ số cấp/20) — đúng công thức
  `getAppendPropertyValue` (`:465-502`); kèm `updateEquipData` (giá/trần cường hoá theo phẩm mới).
- `RecastEquipment` (`:650-780`) **chỉ trả nguyên liệu** (đá tẩy luyện 97 hoặc vàng/kim cương) —
  nay bốc lại `BaseValue` trong **0,8…1,3** (`AppendPropertyRandomRange`, `:16-17`) rồi tính lại
  `Value`. **[GHIM]** thứ tự `math.random` là của ta (máy chủ gốc không còn đối chiếu).
- Callback trả đủ: `OnServerPromoteQualityEquipment(h,p,danhSách)` · `OnServerRecastEquipment(h,p,resourceType,danhSách)`.

Đo: `python _thu_nha_cua.py _thu_trang_bi_pham.lua` → **16/16 DAT** (nâng phẩm đổi Value theo
Quality mới mà GIỮ BaseValue · chạm trần 1105 · tẩy luyện BaseValue 0,8..1,3 + Value đúng công
thức + trừ 10000 vàng · 5 lượt ra ≥2 giá trị khác nhau · luật gốc từ chối mã 2 · hết vàng 1103 ·
tham số sai 2). LDPlayer boot: `trang bi pham: da dang ky lai 2 khoa`, vẫn **131 handler**.

### Cùng lượt: TRẬN ĐẤU TRƯỜNG (đánh robot) — hết 2306

`handlers/dau_truong.lua` từ 28/10 trả **2306** cho cả nhóm trận, lý do: "cần `FightData`
đầy đủ". Đo lại thì **cấu hình CÓ `FightData`** (`Data` + `Groups`), chỉ thiếu `BaseInfo`
— mà danh sách đối thủ đã tự dựng `BaseInfo` từ trước. Tệp mới `handlers/dau_truong_tran.lua`
nạp **sau** `dau_truong` (ghi đè ba khoá đang trả 2306):

| lệnh | trả lời |
|---|---|
| `ArenaFightRanking({Uid,HeroList,Ranking})` | `{FightData=<robot>, FightHeroList=<TƯỚNG CỦA MÌNH>, BattleRandom}` |
| `CompeleteArenaFight({bResult,Replay})` | `{bResult, Ranking, UserHonnor}` (+ ghi `FightRecords`, giữ 20 dòng) |
| `GetUserArenaFightRecord()` | danh sách chiến báo |

Hai chỗ **phải biết**:
- **Chín khoá `Data` HỎNG DẤU CÁCH** do bản dịch ngược (`"CriticalStr ike"`, `"Min Ap"`,
  `"MaxA p"`, `"D p"`, `"P iercingAp"`, `"DamageAdd ition"`, `"RecoveryB lood"`,
  `"Resurrect ionTime"`, `" MaxAttackDistance"`) — đổi về tên đúng trong `TEN_SAI`
  (bảng ghi rõ từng cặp). Khoá `"Groups "` có dấu cách cuối cũng chuẩn hoá.
- `FightHeroList` là **tướng CỦA MÌNH** (`CUIBattleDeploy:OnArenaFightLocalArmy:3517`
  đưa nó vào `GetArmyDatatWithUserData`), không phải của địch.

Kết toán theo `GameArenaConfig` thật: thắng +`WinHonour` (20), thua +`LoseHonour` (10);
thắng thì hạng −1 (sàn 1). `BaseInfo` robot là **ĐẶT** (tên `Robot <uid>`, cấp/lực chiến
mượn của người chơi) — cấu hình không có, cùng quyết định đã ghi ở `dau_truong.lua:71`.

Đo: `python _thu_nha_cua.py _thu_dau_truong_tran.lua` → **14/14 DAT** (FightData + BaseInfo ·
chín khoá đổi tên · `Groups ` chuẩn hoá · FightHeroList của mình · thắng +20/hạng 999 ·
thua +10/giữ hạng · chiến báo mới nhất đầu · thiếu cấu hình → 2306). LDPlayer boot:
`dau truong tran: da noi 3 khoa`, vẫn **131 handler** (ghi đè).

⚠ **Chưa đánh trận THẬT trong game** (việc của chủ dự án): vào Lôi Đài → chọn đối thủ →
bố trí → Chiến. Nếu trận nổ, nghi `Data` robot thiếu trường mà engine đọc — log sẽ ở
`lualog/1_log.txt` và `offline.txt` trên máy.

### Cùng lượt: BXH ĐẤU TRƯỜNG + dữ liệu đấu trường

`handlers/dau_truong_bxh.lua` (nạp sau `dau_truong`): `GetWorldArenalRanking(min,max)` ·
`GetArenaRankWithYesterday()` · `ClientGetUserArenaData()`. Offline MỘT người chơi nên bảng
**chỉ có chính mình** — sự thật, không phải lỗi; trang 2 trở đi rỗng.

- `GetWorldArenalRanking`: callback nhận **MỘT MẢNG**, mỗi mục `{RankID, Uid, BaseInfo{…},
  HeroList}` — `HeroList` là **5 tướng mạnh nhất theo cấp** từ `G_HeroLogic:GetHeroMap(true)`
  (hoà cấp thì `UserHeroID` lớn trước, thứ tự tất định), **chỉ bản ghi thật**.
- `GetArenaRankWithYesterday`: `tRankList` là **BẢN ĐỒ khoá uid CHUỖI** + `Rank` (cùng hình
  dạng server riêng Mốc 57); `nYesterdayRank = nSelfRank` (offline không lưu hôm qua).
- `ClientGetUserArenaData`: callback **TOÀN CỤC** `OnGetUserArenaData({err=0,data})`
  (`obj=""`), `data` là bảng `GameUserArenaRank` đang sống.

Đo: `python _thu_nha_cua.py _thu_dau_truong_bxh.lua` → **10/10 DAT** (trang đầu 1 dòng đúng
RankID/Uid · BaseInfo thật · HeroList 5 tướng mạnh nhất bỏ tướng cấp 5 · trang 2 rỗng ·
bản đồ uid chuỗi + Rank · hôm qua = hôm nay · callback toàn cục).
LDPlayer boot: `dau truong bxh: da noi 3 khoa` → **132 handler** (thêm `ClientGetUserArenaData`).

### Cùng lượt: CHI TIẾT ĐỘI HÌNH ĐỐI THỦ

`handlers/dau_truong_chi_tiet.lua` (nạp sau `dau_truong`): `ClientGetArenaDetailByUid(Uid,nRobotId)` ·
`ClientGetUserArenaFightData(uid)` — hai khoá cuối của nhóm trận còn trả 2306.

- `ClientGetArenaDetailByUid` → callback phương thức `OnGetArenaDetailByUid({Uid, ArenaRank,
  UserFightCapacity, ArenaHeroMap})`. Người đọc: `CUILeaderboard:GetArenaDetailCallBack` (cần
  `ArenaHeroMap` + `UserFightCapacity`) và `CUIFriend2Info` (cần thêm `ArenaRank`).
  `ArenaHeroMap = { [UserHeroID] = bản ghi }`, dựng từ `GameArenaRobotConfig.FightData.Data`
  với **cùng bảng đổi 9 khoá hỏng dấu cách** (chép từ `dau_truong_tran.lua` — hai bản phải giống
  nhau). Ba trường UI vẽ cần mà `Data` không có (`UserHeroID`, `HeroLevel`, `HeroQuality`) là **ĐẶT**.
- `ClientGetUserArenaFightData` → callback **toàn cục** `OnGetUserArenaFightData({err=0,data})`.
  ĐO: **không UI nào nghe** `CUINotificationEvent.OnGetUserArenaFightData` ⇒ trả đúng hợp đồng,
  không dựng thêm màn (đã khai).

Đo: `python _thu_nha_cua.py _thu_dau_truong_chi_tiet.lua` → **10/10 DAT**. LDPlayer boot:
`dau truong chi tiet: da noi 2 khoa` → **132 handler** (ghi đè, không thêm khoá).

### Cùng lượt: ĐỔI TÊN + ĐỔI ẢNH ĐẠI DIỆN

`handlers/ca_nhan.lua`: `ClientIsUniqueNickName` · `ClientChangeNickName` · `ClientChangePortrait`
— cả ba trước đây **không có handler** (bấm "Đổi" là lớp tải quay mãi).

Ghi dữ liệu bằng API THẬT của client: `G_UserLogicDataManager:SetValue("CharacterName"|"Portrait", …)`
(`share_UserLogicDataManager.lua:511`) — tự cập nhật `GameUserBaseInfo` + phát Data event.

**[MOI]** ba quyết định (máy chủ gốc đã chết): tên **luôn "duy nhất"** (offline một người chơi, không có
bảng tên toàn server); cổng dài tên **1..20** ký tự; ảnh đại diện nhận mọi chuỗi khác rỗng (client đã
lọc theo ảnh sở hữu). Callback `OnChangeNickName()`/`OnChangePortrait()` **không có đối số**.

Đo: `python _thu_nha_cua.py _thu_ca_nhan.lua` → **10/10 DAT** (tên luôn duy nhất · đổi tên ghi đúng ·
tên rỗng/21 ký tự → 1 · đổi ảnh · ảnh không phải chuỗi → 1). LDPlayer boot: `ca nhan: da noi 3 khoa`
→ **135 handler** (thêm ba).

### Cùng lượt: MUA THỂ LỰC BẰNG KIM CƯƠNG

`handlers/the_luc.lua` → `ClientBuyFatigue` (trước đây không có handler: bấm là không phản hồi).
Luật là **mã gốc còn sống** `UserLogic:buyFatigue` (`share/UserLogic.lua:2895-3013`): đọc
`GameBuyFatigueConfig` (`MaxBuy` + `CostList[{CostDiamond, GetFatigue}]` theo **`CurIndex + 1`**),
trần theo VIP `GetVipConfig("BuyFatigueCountList")`, `CostDiamond` → `AddFatigueValue` → lưu
`BuyFatigueData` → phát `User.OnBuyFatigue`. Mã lỗi của luật: **1808** thiếu cấu hình · **1809**
chạm trần · **1702** thiếu kim cương · **1810/1812** lỗi cộng/lưu.
⚠ Tên hàm là **`buyFatigue`** (b thường — khác chín hàm `Buy*` còn lại), gọi qua proxy lớp cha.
Callback `OnServerBuyFatigue()` **không đối số**.

Đo: `python _thu_nha_cua.py _thu_the_luc.lua` → **5/5 DAT** (thành công · chạm trần 1809 ·
luật ném lỗi → 1, không sập). LDPlayer boot: `the luc: da noi 1 khoa` → **136 handler**.

### Cùng lượt: THẦN BÍ / CỬA HÀNG THẦN BÍ (`G_GodSecret`, 6 khoá)

`handlers/than_bi.lua`: `ClientRefresh` · `ClientFreeRefresh` · `ClientExchange` · `ClientGetGlobleScore` ·
`ClientGetRanking` · `ClientGetGloblePrize`. Trước lượt này **không khoá nào có handler**.

Nguồn luật: bản port máy chủ giả `bc/may_chu/handler/than_bi.lua` (KHÔNG có trên máy — `bc/` là cây
bản Axmol) ⇒ luật được **chép** sang, chỉ đổi tầng lưu (`the_gioi.*` → `G_DataManager`). Hằng số
nguyên văn: `RefreshCost 500` · `RefreshAddScore 100` · `RefreshExchangeCD 300` · `ExchangeListLenth 3`.
`ExchangeList` và `GloblePrizeList[*].PrizeList` **RỖNG** (dữ liệu game chưa có ở cấu hình client) ⇒
làm mới với nguồn rỗng **không chạm** `ExchangeStateList`; mốc 200 điểm tồn tại nhưng chưa cấu hình vật
⇒ nhận thưởng trả **509**.

Mã lỗi: 509 thiếu bảng · 4001 chưa mở · 504 thiếu kim cương · **4020** còn CD miễn phí · 4021 bàn rỗng ·
5301 ô đã đổi · 4 tham số hỏng · 1201 thiếu vật · 4022 đã nhận · 4023 thiếu điểm.

Hai chỗ offline phải khác (đã khai): `GetGlobleScore` trả **điểm của chính mình** (`Score`, không phải
`CumulativeScore`), `GetRanking` trả danh sách **rỗng** — một người chơi.
Khoá thứ bảy `ClientBuyGoods` để nguyên: `share/` không có thân hàm mua cho `G_GodSecret` (đã khai từ Mốc 33).

Đo: `python _thu_nha_cua.py _thu_than_bi.lua` → **22/22 DAT** (mới 6 khoá · Refresh miễn phí khi hết CD,
trừ 500 khi còn CD · FreeRefresh 4020 · bàn rỗng 4021 · đổi trừ/cộng đúng vật · đổi lại 5301 · thiếu vật
1201 · điểm = của mình · BXH rỗng · mốc 4023/509). LDPlayer boot: `than bi: da noi 6 khoa` → **142 handler**.

### 30/10 — THỬ CHẠY HARNESS TRONG GAME: KHÔNG TỚI ĐƯỢC (panel Kull SDK)

Định kiểm chứng đầu-cuối các handler mới bằng `thu_tinh_nang.lua` (`TAT = false`). **Không chạy được**
vì game dừng ở **panel đăng nhập Kull SDK** (SDK chết, đã biết từ 23/10); `tu_dong` báo
`huong dan cho khoa = nil` rồi chờ. Ảnh chụp màn hình xác nhận: panel "Đăng Nhập / Đăng ký / Chơi nhanh".
Bấm "Chơi nhanh" bằng `adb input tap` không ăn (panel của SDK, không phải của game).

⇒ Muốn chạy harness phải đi đúng đường cũ: `_boot_va_chay.ps1` + hook SDK (`frida/be_sdk_spawn`) hoặc
màn login của lớp offline — việc này vẫn thuộc chủ dự án.

**Đã trả máy về trạng thái sạch:** bản lưu sao lưu trước khi thử (`/sdcard/offline_save_backup.json`,
**55.604 B**) đã chép ngược vào `/data/user/0/com.cmn.buatanew/files/offline_save.json`; harness đặt lại
`TAT = true` và push; boot lại: **142 handler, `nha cua: da cai (cau hinh=true, g_BuildingLogic=true)`**.

### Cùng lượt: NẠP LIÊN TỤC (`G_ActivityContinuousRecharge`, 3 khoá)

`handlers/nap_lien_tuc.lua`: `ClientGetUserState` · `ClientGetDayPrize` · `ClientGetContinuousPrize`.

Luật gốc `share/Activities/ContinuousRechargeLogic.lua` **chỉ có vị từ**
(`IsCanGetPrizeWithDay` · `IsCanGetContinuousPrize`); hình dạng dữ liệu lấy từ khối chú thích
`ContinuousRechargeData` (`RechargeList{Count,Time}` · `RechargeDayList` · `PrizeStates` ·
`HasGetContinuousPrize`). Trạng thái lưu ở bảng MỚI `GameUserContinuousRecharge`.

**Ba sự thật của offline, đã khai:**
1. **`RechargeList` rỗng** — lớp offline không có đường nạp tiền (nhóm `G_RechargeLogic` chết SDK) ⇒
   ngày nào cũng 0 ⇒ hai lệnh nhận thưởng luôn bị từ chối (mã **1**). Đó là dữ liệu, không phải lỗi.
2. **Cấu hình hoạt động thường VẮNG** (`GetActivityConfigWithType` đọc `tOtherData.Activity` mà lớp
   offline không dựng) ⇒ từ chối bằng **4001** `ActivityNotOpen`, không bịa điều kiện.
3. **Callback client KHÔNG phát sự kiện UI** — hai dòng `PostLogicEvent` đã bị CHÚ THÍCH
   (`ClientActivityContinuousRecharge.lua:34/43`) trong khi UI vẫn nghe hai tên ấy ⇒ handler **phát hộ**
   `OnGeContinuousRechargetDayPrize` / `OnGetContinuousRechargePrize` ([MOI]).

Đo: `python _thu_nha_cua.py _thu_nap_lien_tuc.lua` → **12/12 DAT**. LDPlayer boot: `nap lien tuc: da noi 3 khoa`
→ **145 handler**.

### Cùng lượt: QUÀ TÂN THỦ (`G_NewHandPrivilegeLogic`, 3 khoá)

`handlers/tan_thu.lua`: `ClientGetUserNewHandPrivilegeInfo` (callback phương thức trên `g_CUINewHandPrivilege`,
`dd_p={}`) · `ClientSendReward` (`OnSendReward`) · `ClientSendRewardV2` (`cb=''` — im lặng nhưng vẫn mang Data).

Dữ liệu `GameNewHandPrivilege = {TotalRechargeMoneyIn24, LastRewardTime, RewardTimes}`; client tự tính `CurLevel`
và `RewardTimesMax` từ `KDBGameNewHandPrivilegeConfig` (`updateGameNewHandPrivilegeConfig :3826`). Luật: **4301**
chưa có đặc quyền · **4302** hết lượt · **4303** đã nhận hôm nay; phát `PrizeId` của NGÀY KẾ TIẾP qua
`G_ChapterLogic:SetDataWithPrizeList`. **[MOI]** không cổng theo `RemainSecond` (client `canGetPrize` cũng không;
24 giờ chỉ để hiện icon).

Offline **không có đường nạp tiền** ⇒ `TotalRechargeMoneyIn24 = 0` ⇒ mọi lượt nhận trả **4301** — dữ liệu, không phải
lỗi handler; bộ thử gieo số để chạy nhánh thành công.

Đo: `python _thu_nha_cua.py _thu_tan_thu.lua` → **13/13 DAT**. LDPlayer boot: `tan thu: da noi 3 khoa` → **148 handler**.

### BẪY MỚI — ĐỊNH DANH CÓ DẤU LÀM CHẾT CẢ LỚP OFFLINE

Một tham số viết `tongNạp` trong `handlers/tan_thu.lua` làm LuaJIT trên máy báo
`')' expected near char(225)`; **cả lớp offline không nạp**, triệu chứng duy nhất trên logcat là tiến trình
thoát (`onSystemExit`) — trông y như "game tự đóng". Công cụ mới **`_kiem_cu_phap.py`** kiểm CÚ PHÁP mọi tệp
Lua của lớp offline bằng chính `lua51.dll` (không cần game): **31 tệp, 0 lỗi** sau khi sửa. **Chạy nó TRƯỚC
mỗi lần `deploy.py --push`.**

### Cùng lượt: MUA LƯỢT QUÉT (`ClientBuyChapterSweepCount`)

Thêm vào `handlers/mua_luot_ai.lua`. Lệnh `ClientChapterLogic.lua:395`, callback PHƯƠNG THỨC
`OnServerBuyChapterSweepCount(n)`.

**Không gọi `changeDiamondToSweepCount`** dù nó còn sống: hàm ấy tiêu kim cương rồi gọi
**`ReduceSweepCount`** — tức **TRỪ** số lượt vừa mua (chỗ đảo nghĩa đã đo ở `handlers/chapter.lua:443-458`).
Thay bằng đúng NGHĨA TÊN + đúng GIÁ của nó: **1 kim cương/lượt** (`:1211`), cộng lượt bằng
`SetSweepCount(hiện có + n)`; thiếu kim cương → **1702**, tham số hỏng → **4**. `[GHIM]` chiều cộng là của ta.

Đo: `python _thu_nha_cua.py _thu_mua_luot.lua` → **10/10** (thêm 4 phép: mua 5 → +5 lượt, −5 kim cương,
callback `(n)` · thiếu kim cương 1702 · tham số 0 → 4). LDPlayer: **149 handler**.

> **BẪY ĐÃ VẤP (2 lần trong lượt này):** (a) chèn mã **SAU** `return true` ⇒ không bao giờ chạy mà
> không lỗi cú pháp; (b) bộ thử dùng SAI tên trường của `ctx` giả — mỗi bộ thử có khuôn riêng
> (`args`/`x`/`a`) nên phải đọc lại đầu tệp trước khi thêm phép kiểm. Cả hai lộ ra bằng phép chạy,
> không bằng đọc mã.

### Cùng lượt: DÙNG NHIỀU VẬT PHẨM MỘT LƯỢT (`ClientBatchUseItemWithItemList`)

Thêm vào `handlers/vat_pham.lua`. Nút "Dùng" của Túi gửi lệnh này khi **số dùng vượt số trong một ngăn**
(`CUIBackpack.lua:718-723` + `checkUseItemDataList:1029`) — danh sách do CHÍNH CLIENT chia sẵn, mỗi mục
`{ItemID, UserCount}`. Callback PHƯƠNG THỨC `OnBatchUseItemWithItemList(tRetData)`; UI đọc
`tUseData.ItemID` và — với hộp quà — `tUseData.RetData` (danh sách thưởng).

`share/` **KHÔNG có hàm batch** (ĐO: `BatchUseItemWithItemList` 0 thân trên cả cây) ⇒ dùng lại ĐÚNG
`ItemLogic:UseItem` từng mục (cùng đường `ClientUseItem` đã chạy); `RetData` chính là bảng thưởng mà
`UseItem` đổ vào tham số thứ ba.
**[MOI]** một mục hỏng KHÔNG làm hỏng cả lượt: bỏ mục hỏng + ghi log, trả danh sách các mục đã dùng;
KHÔNG mục nào dùng được ⇒ mã **1**; danh sách rỗng ⇒ **4**.

Đo: `python _thu_nha_cua.py _thu_dung_loat.lua` → **7/7 DAT**. LDPlayer: **150 handler**.

**Các khoá `G_ItemLogic` còn lại — ĐO ÂM (đừng thử lại):** `BatchUseItem` đã có sẵn trong `vat_pham.lua`
(`OnServerBatchUseItem`); `BuyItem` · `BuyItemBatch` · `RefineItem` · `SellRedundantExclusiveItem` **0 thân
trong `share/`** (quét 973 tệp cho từng tên) ⇒ kết toán máy chủ không có ở cây chỉ-đọc, viết ra là bịa.

### Cổng của lớp offline: `_chay_het.py`

    python _chay_het.py        # -> TONG: 14 tep · dat 174 · hong 0 · do 0

Chạy **mọi** bộ thử `_thu_*.lua` (mỗi bộ một tệp, chạy qua `_thu_nha_cua.py` bằng chính `lua51.dll` —
không cần game, không cần máy), cộng số và in bộ nào đỏ; mã thoát 0/1. Cùng vai với `npm run test:do_phu`
bên server. **Chạy cùng `_kiem_cu_phap.py` trước mỗi lần `deploy.py --push`.**

### 30/10 — BỀ MẶT PORT ĐÃ CẠN (đo, đừng thử lại)

Quét `share/` cho từng khoá còn thiếu của ba nhóm đang mở:
`G_EquipmentLogic` độc quyền (`ForgingExclusiveEquip` · `PurifyExclusiveEquip` · `CancelExclusiveEquip` ·
`GetExclusiveEquipInfo`) và `G_HeroLogic` cánh/kỹ năng (`UpgradeWing` · `IntensifyWing` · `AutoIntensifyWing` ·
`ShowWing` · `GetHeroExclusiveSkin` · `SetExclusiveSkinState` · `ConvertUniversalFragment` · `UpHeroFightSoul`)
— **12/12 khoá 0 thân** trên 973 tệp. Cùng kết luận với `G_ItemLogic` (4 khoá) và `G_GodSecret|ClientBuyGoods`.
Nghĩa là **không còn khoá nào port được bằng thân hàm gốc**; bước tiếp phải là VIẾT MỚI (chủ dự án quyết)
hoặc chạy thử trong game.

### 30/10 — NẠP TIỀN GIẢ LẬP (`offline/nap_gia_lap.lua`): mở đường cho ba hệ đang chết

**Vì sao cần:** trên Android KHÔNG có lệnh mua nào sống trong Lua — `ClientDealPayment` bị **CHÚ THÍCH** ở cả
hai chỗ gọi (`GooglePayManager.lua:273`, `CUIRechargeStore.lua:2437`), AiBei chỉ chạy kênh iOS
(`ABPay:isABChannel`). ⇒ Nạp liên tục + Quà tân thủ luôn từ chối, mua thể lực/kim cương thiếu tiền.

**`OfflineNap:cong(soTien, soKimCuong)`** cập nhật ĐÚNG các trường mà hệ khác đọc (không bịa hệ mới):
| trường | hệ đọc |
|---|---|
| `GameUserBaseInfo.Diamond` (`AddDiamond`) · `FirstRechargeTime` | cửa hàng nạp, UI首充 |
| `GameUserGlobalData.C_RechargeData.FirstRechargeStatus = 1` | `RechargeLogic:CheckHasFirstRecharge` |
| `GameUserContinuousRecharge.RechargeList += {Count,Time}` + **tính lại** `RechargeDayList` | `ContinuousRechargeLogic` |
| `GameNewHandPrivilege.TotalRechargeMoneyIn24 += soTien` | `CUINewHandPrivilegeCommon` |

**Đường kích hoạt — `ClientGMCommond`** (objName rỗng, cb `OnGMCommond` trên `G_GameWorld`, `api.lua:60`):
`{"addgold", n}` · `{"adddiamond", n}` · `{"recharge", tien [, kimcuong]}`. Lệnh khác → mã 1 + log.
**`ClientGetFirstRechargePrize`** cũng nối: thân `RechargeLogic:getFirstRechargePrize` CÓ THẬT trong `share/`
⇒ sau khi nạp giả lập, quà首充 nhận được thật (trả lời `G_RechargeLogic.OnServerGetFirstRechargePrize` — chính
hàm phát sự kiện `OnServerGetFirstRechargePrize` mà `CUIFirstPayGift.lua:67` nghe; còn dòng `api.lua:444` khai
hình dạng KHÁC — ghi lại vì hai nguồn lệch nhau).

**[MOI]** (1) 1 đơn vị "tiền" = 1 `Count` của bảng liên tục + 1 `TotalRechargeMoneyIn24` (cùng thang 100/198 của
cấu hình hai hệ); (2) kim cương mặc định = số tiền — `GameRechargeConfig` chỉ có `FirstRechargePrize`, **không có
danh mục sản phẩm**; (3) không cộng VIP exp.

Đo: `python _thu_nha_cua.py _thu_nap_gia_lap.lua` → **16/16 DAT**. LDPlayer: **152 handler**, log
`nap gia lap: da noi ClientGMCommond … + ClientGetFirstRechargePrize`. Cổng: `_chay_het.py` **15 tệp · 190 phép ·
0 đỏ**; `_kiem_cu_phap.py` **45 tệp · 0 lỗi**.

### Cùng lượt: LỆNH NẠP QUA KHUNG CHAT (không cần GM console)

`handlers/chat.lua` nối `ClientNotifyMessage` (module **CHAT_FRIEND**, objName rỗng, `api.lua:207`) — trước đây
KHÔNG có handler nên gửi chat rơi vào nhánh "sinh" và không phản hồi. Offline một người chơi không có ai để phát
sóng, handler trả `OnNotifyMessage(0, 0)` (client yêu cầu `SpeechId` là SỐ).

**Gõ vào ô chat thế giới:**
```
nap 100          -> giả lập nạp 100 (kim cương = 100)
/nap 50 200      -> giả lập nạp 50, cộng 200 kim cương
```
Xử lý bởi `OfflineNap:cong` (xem mục nạp giả lập ở trên); KHÔNG phát sóng, nhưng client đã tự đưa câu vừa gõ vào
khung chat của mình (`CUIChatting.lua:1020-1036`) nên người chơi thấy nó. Câu thường / lệnh sai cú pháp → chat
thường, không đổi dữ liệu. `[GHIM]` định dạng lệnh là của ta.

Đo: `python _thu_nha_cua.py _thu_chat.lua` → **7/7 DAT**. LDPlayer: **153 handler**, log
`chat: da noi ClientNotifyMessage`. Cổng: `_chay_het.py` **16 tệp · 197 phép · 0 đỏ**; `_kiem_cu_phap.py` 46 tệp 0 lỗi.

### Cùng lượt: KÊNH CHAT (4+1 lệnh) — để khung chat mở được mà gõ `nap`

`handlers/chat.lua` thêm `ClientEnterChatGame` · `ClientEnterChannel` · `ClientExitChannel` ·
`ClientGetFriendChatRecord` · `ClientReadFriendMessage` (im lặng). Trước đó **không lệnh nào có handler** ⇒ mở khung
chat là `CallEnterChannel` rơi vào nhánh "sinh" (trả danh sách rỗng, KHÔNG gọi callback) ⇒ kênh không có lịch sử.

Hình dạng trả lời đo từ `ClientChattingLogic.lua:21-64`: `OnEnterChannel(errCode, nChannelId, tMsgData, tListFriendInfo)`
— kênh **4** (Person) đòi `tListFriendInfo` là BẢNG, kênh khác đòi `tMsgData` là BẢNG ⇒ trả `(0, cid, {}, {})`.
Lịch sử RỖNG là sự thật của offline một người chơi.

Đo: `python _thu_nha_cua.py _thu_chat.lua` → **11/11 DAT**. LDPlayer: **158 handler**. Cổng `_chay_het.py`:
**16 tệp · 201 phép · 0 đỏ**.

---

## 31/10/2026 — BA NHÓM MỚI (trận pháp · thẻ tháng · thời trang) + HAI LỖI CÔNG CỤ

### Cây nguồn `sc/offline/` đã lệch `deploy/plain/sc/offline/` — ĐÃ ĐỒNG BỘ

`build.py` dựng `deploy/plain/` bằng `shutil.rmtree(deploy/plain/sc/offline)` rồi chép từ
**`sc/offline/`**. Nhưng từ 28/10 mọi tệp mới chỉ được viết thẳng vào **`deploy/plain/`** ⇒
`sc/offline/` tụt lại **16 tệp** và **3 tệp khác nội dung**. Nghĩa là **chạy `build.py` một lần
là xoá sạch công của ba ngày** (nhà cửa · nạp giả lập · chat · đấu trường · mọi `handlers/` mới).

Đo: `diff -rq sc/offline deploy/plain/sc/offline` → **0 tệp chỉ-có-ở-nguồn** (deploy là SUPERSET
⇒ chép một chiều là an toàn). Nay `sc/offline` = `deploy/plain/sc/offline` (**49 tệp**, diff rỗng).
`_phu_rpc.py` đọc `sc/offline/` nên trước lượt này nó báo **107 handler** trong khi máy chạy
**158**; nay báo **150** (chênh là các khoá `R:ignore` và khoá trùng tên — xem mục dưới).

**LÝ DO `build.py` TỪNG CHẾT GIỮA CHỪNG — ĐO ĐƯỢC, KHÔNG PHẢI ĐOÁN.** `shutil.rmtree` ném
`PermissionError: WinError 5` ở **`rmdir`**, SAU khi đã xoá sạch tệp ⇒ cây thành **RỖNG nhưng còn
sống**, trông y như "đã xoá xong". Nguyên nhân: thư mục `handlers` mang thuộc tính **`R`
(read-only)** — `cmd attrib` in ra `R` — và Windows **không xoá được thư mục read-only** dù rỗng.
Nay `build.py` có `xoa_cay()`: gỡ cờ read-only từng mục (`onexc`/`onerror`) rồi thử lại; đã đo
`python build.py` chạy TRỌN → **49 tệp + 1 require.lua**, `diff -rq` rỗng, và `attrib` sau build
**không còn `R`**. Cũng đã gỡ `R` khỏi cả `sc/offline/`.

### HAI LỖI CÔNG CỤ ĐO ĐƯỢC, ĐÃ VÁ

1. **`_phu_nhom.py` so SAI ĐỐI TƯỢNG** — nó so tên hàm client (`"ClientUpgrade"`) với **khoá
   đăng ký NGUYÊN VĂN** (`"G_FormationLogic.ClientUpgrade"`), nên **mọi** handler đăng ký bằng
   khoá có tiền tố obj đều bị báo THIẾU. Đây đúng họ bẫy *"hỏi sai đối tượng"*. Đo sau khi vá:
   `G_ArenaLogic` 24 → **12** · `G_HeroLogic` 20 → **12** · `G_COGProtocol` 19 → **18**;
   ba nhóm của lượt này BIẾN MẤT khỏi danh sách thiếu. Vá bằng `da_tran = {ten.split('.')[-1] ...}`
   — cùng phép `_phu_rpc.py` đã làm ở `main()`.
2. **`sc/offline` lệch `deploy/`** (mục trên) làm mọi con số "THIẾU" của các lượt trước **phóng đại**.

### TRẬN PHÁP — `handlers/tran_phap.lua` (3 khoá `G_FormationLogic`)

`ClientUpgrade(strName)` · `ClientActiveRareFormation(strName)` · `ClientSelectAdvancedFormation(strName)`.

**ĐÂY LÀ TÁI DỰNG**: `share/FormationLogic.lua` (525 dòng) chỉ có helper ĐỌC/KIỂM (`IsOpen` :25 ·
`GetUserFormationData` :313 · `GetLevel` :367 · `GetFormationMaxLevel` :168 ·
`GetFormationUpgradeCostWithName` :264 · `CheckCost` :424 · `GetRareFormationActiveConfig` :303);
**không có** hàm đột biến nào. Ba hàm handler GHÉP các helper ấy lại, y bản
`bravecross-server/src/handlers/tran_phap.ts` (Mốc 46) — đổi máy chủ thì đổi cách gọi, KHÔNG đổi luật.

* Trừ tài nguyên bằng đúng API gốc: `G_ItemDataManager:ReduceItem` · `G_UserLogic:CostDiamond/CostGold`.
* Giá là của cấu hình (`GetFormationUpgradeCostWithName` / `RareFormationActiveConfig`), KHÔNG tự tính.
* Tăng cấp: hết `Level` thì lên `SeniorLevel`; giữ `IsActived`.
* Mã lỗi: 2 · 5101 · 5102 · 5104 · 5105 · 5106 · 1201 · 1702 · 510.
* Đo: `python _thu_nha_cua.py _thu_tran_phap.lua` → **24/24 DAT**.

### THẺ THÁNG — `handlers/the_thang.lua` (1 khoá `G_MonthlyCardLogic`)

`ClientGetReward(sCardType)` → gọi **luật gốc** `MonthlyCardLogic:GetReward`
(`share/Activities/MonthlyCardLogic.lua:157-240`) qua proxy lớp cha. Luật ấy tự kiểm "còn ngày thẻ"
(`MonthlyCardLeftCount<loại>`) · "chưa nhận hôm nay" (`IsGetMonthlyCardReward<loại>`) · chọn
`VipReward` khi VIP ≥ 6 rồi phát · giảm 1 ngày · phát `Active.OnGetMonthlyCardReward` (chính sự kiện
`CUIMonthCard` đăng ký nghe). Handler chỉ cần tắt lớp "đang tải" bằng `OnReciveResponse("","",0,{})`.

**KÍCH HOẠT THẺ KHÔNG CÓ KHOÁ CLIENT** — bản gốc kích hoạt từ sự kiện `Active.OnGetMonthlyCard` của
hệ NẠP TIỀN, mà Android không có lệnh mua sống. Nay lệnh GM **`thethang [Normal|ShuGuo]`**
(`offline/nap_gia_lap.lua`) gọi thẳng `MonthlyCardLogic:GetMonthlyCard` — luật GỐC (+30 ngày, phát
`FirstReward`). `[MOI]` chỉ ĐƯỜNG KÍCH HOẠT là của lớp offline.

Đo: `python _thu_nha_cua.py _thu_the_thang.lua` → **12/12 DAT**.

### THỜI TRANG — `handlers/thoi_trang.lua` (3 khoá `G_ClothingLogic`)

| khoá | luật |
|---|---|
| `ClientComposeClothing(heroId, clothId)` | **ghép mới**: cấu hình `GameClothingComposeConfig` (3 dòng Coat005/006/007, `{ItemId, Count=10, PrizeData}`) → khớp `PrizeData.UserProperty.HeroID` → đủ nguyên liệu → `ReduceItem` → `ChapterLogic:SetDataWithPrizeData` (nhánh `PrizeResType.Clothing` → `HeroLogic:AddHeroSkin`, `share_ChapterLogic.lua:4399`) |
| `ClientGetClothingPrize(strIndex)` | **luật GỐC** `ClothingLogic:getClothingPrize` (`share_ClothingLogic.lua:163`): cửa sổ hoạt động theo `FirstEnterGameTime` + `GetClothingRechargeCount` (`G_RechargeLogic:GetUserRechargeCount`) ⇒ **`OfflineNap:cong` là đường thoả điều kiện "đã nạp"** |
| `ClientSetClothingPrizeUseStatus(strIndex)` | **luật GỐC** `ClothingLogic:setClothingPrizeUseStatus` (`:362`), trạng thái ở client common data `ClothingData` |

Mã lỗi nhóm `Clothing`: **3301** CanNotGetClothingPrize · **3302** GetConfigFaild ·
**3305** NotEnoughItemForCompose · **3306** ClothingNotMatchHero. `[GHIM-1]` thứ tự cổng của
`ClientComposeClothing` — bản gốc không có hàm để đối chiếu.

Đo: `python _thu_nha_cua.py _thu_thoi_trang.lua` → **17/17 DAT**.

### LUYỆN HERO — `handlers/luyen_hero.lua` (3 khoá `G_HeroPracticeLogic`)

`ClientPracticeHero(nHeroID, strAreaID)` · `ClientGetPracticePrize(strArenaID)` · `ClientGetPracticeInfo()`.

`share/HeroPracticeLogic.lua` (427 dòng) chỉ có helper ĐỌC/KIỂM (`GetUserHeroPracticeData` :72 ·
`IsCanPracticeHero` :161 · `getGoldReward` :378 · `getHeroExpReward` :386) — **không** hàm đột biến.
TÁI DỰNG, cùng luật `bravecross-server/src/handlers/luyen_hero.ts` (Mốc 47).

* Cổng dùng ĐÚNG `IsCanPracticeHero` (cấu hình → VIP/cấp → khoá tướng 1307 → đã luyện 4205 →
  trần `MaxPracticeCountMap[vip]` 4207) — không chép lại luật.
* Callback `ClientPracticeHero` là `Statistics:OnPracticeHero` (**không** phải
  `G_HeroPracticeLogic` — lớp ấy `:new()` = 0).
* Lĩnh thưởng: ô có tướng + `now − BeginTime ≥ 7200`; phát vàng `getGoldReward(level, ô)` và
  Exp tướng `ceil(level × 0,18)` qua `G_HeroDataManager:SetHeroEx` (API thật, có Data event);
  phát xong XOÁ ô.
* **[GHIM-A] KHÔNG quay `ExtraPrize`** — cấu hình có `{MinChance, HourChance, MaxCount}` nhưng
  luật quay nằm trong máy chủ đã chết.
* **[GHIM-C] `ClientGetPracticeInfo` trả BẢNG RỖNG** — hình thật đòi `tData[tostring(index)]` là
  danh sách thưởng có trường **`PracticeMaxCount`**, mà trường ấy xuất hiện **0 lần** trong cấu
  hình (chỉ có ở `CUIQuest.lua:450/474/872/891`) ⇒ do máy chủ sinh. Trả rỗng để tắt lớp "đang
  tải" thay vì BỊA hình.

Đo: `python _thu_nha_cua.py _thu_luyen_hero.lua` → **16/16 DAT**.

### Cổng của lượt này

```
python _kiem_cu_phap.py              -> kiem 50 tep, loi 0
python _chay_het.py                  -> TONG: 20 tep · dat 270 · hong 0 · do 0   (trước: 16 · 201)
python _phu_rpc.py                   -> da co handler: 153 / 511   (trước: 107 — đo trên cây nguồn CŨ)
```

**NHÓM CÒN THIẾU LỚN NHẤT sau lượt này** (`_phu_nhom.py`, số ĐÃ ĐÚNG sau khi vá):
`(toàn cục)` 56 · `G_GuildLogic` 30 · `G_RankLogic` 19 · `G_TournamentLogic` 18 · `G_FriendLogic` 18 ·
`G_GuildChapterLogic` 18 · `G_GuildWarLogic` 18 · `G_COGProtocol` 18 · `G_ChapterLogic` 17 ·
`G_WCSProtocol` 17 · `G_RechargeLogic` 16.

> **CẢNH BÁO VẬN HÀNH (giữ nguyên từ 30/10):** sau khi sửa `sc/offline/`, muốn đẩy lên máy phải
> chạy **`python build.py`** trước `deploy.py --push` — nếu không, `deploy/plain/` vẫn là bản cũ.
> Từ 31/10 hai cây ĐÃ KHỚP nên `build.py` an toàn; **đừng viết thẳng vào `deploy/` nữa**.

---

## 31/10 (tiếp) — LỊCH HOẠT ĐỘNG VIẾT MỚI + QUỸ CẤP / QUỸ THỜI GIAN

### `offline/hoat_dong.lua` — lịch hoạt động (VIẾT MỚI, không phải port)

Bản gốc nhận lịch từ máy chủ vận hành: `ClientGetActivityList` trả **hai bảng**
`(tActivityStateList, tActivityConfigMap)` (`ClientActivitiesLogic.lua:96-110`), và **mọi** màn hoạt động đọc
chúng qua `GetActivityWithType(type) → (state, config)`; thiếu một trong hai thì hàm trả `nil` ⇒ **tab không bao
giờ hiện**. Trước lượt này lớp offline chỉ phục vụ đúng một hoạt động (`TimeLimitSoulBoxHero`, bật thường trực
từ 28/10) — nay cả lịch nằm ở **một tệp**, và `handlers/login.lua` chỉ còn một lời gọi.

| mở | thưởng | ghi chú |
|---|---|---|
| `LevelFund` (Quỹ cấp) | **THẬT** — `ActivityLevelFundConfig` 12 bậc Level 25..80, PrizeID 109101..109112 | giá mua `[MOI-1]` = 500 kim cương · VIP 0 · cấp 1 |
| `TimeFund` (Quỹ thời gian) | **THẬT** — `ActivityTimeFundConfig` 2 ngày, PrizeID 10001 | giá mua `[MOI-2]` = 300 kim cương |
| `TimeLimitSoulBoxHero` | — | giữ nguyên hành vi 30/10 (bật thường trực) |

**NĂM HOẠT ĐỘNG ĐÓNG — CÓ LÝ DO ĐO ĐƯỢC, ghi trong `OfflineHoatDong.DONG`:**

| hoạt động | vì sao không mở |
|---|---|
| `CumulativeRecharge` · `CumulativeConsume` · `SingleRecharge` | UI đọc `tConf` như **MẢNG `{Recharge, PrizeList}`** (`CUIActivityAccumRecharge:updateItemData`), mà **không có bảng cấu hình nào** như thế trong dữ liệu ship (quét 100 tệp `xgg-json/config/share` + mọi `ConfigName` của `KDBGameCommonConfig`) |
| `LevelCapacityTarget` | `LevelCapacityLogic` chỉ có `getLeftTime`; thưởng do máy chủ phát lúc hết hoạt động |
| `RechargeSign` | cần `RECHARGESIGN_OPENMONTH` + `SignDetail/HeroSprite` **theo tháng** do máy chủ phát; **0** dữ liệu tháng |

**`OfflineHoatDong.MO_THEM`** là chỗ chủ dự án mở thêm **khi có số liệu vận hành** — điền `{keoDai, uuTien, cauHinh}`
là tab hiện ra, KHÔNG phải sửa mã. Để rỗng = trạng thái đúng hiện nay.

### `handlers/quy_hoat_dong.lua` — ba khoá `G_ActivityFund`

`ClientBuyActivityFund` · `ClientGetLevelFundPrize` · `ClientGetTimeFundPrize`.

* **Luật có thật, dùng nguyên:** `ActivityFund:IsCanBuyFund(type, tConfig)` (`FundLogic.lua:78-148`) kiểm
  VIP → kim cương → cấp → đã mua, trả mã `ErrorCode.Activity.Fund` (**4010** thiếu kim cương · **4011** thiếu
  cấp · **4012** đã mua). Trạng thái đọc bằng `IsBuyFund`/`GetPrizeCount`/`GetIsGetTimeFundToday`, ghi bằng
  `G_UserDataManager:SetUserGlobalData` với khoá do chính `getBuyFundKey`/`getFundCountKey` sinh.
* **[MOI-3] Bậc được lĩnh = `GetPrizeCount + 1`** — ĐỌC ĐƯỢC từ chính UI: ô chỉ bấm được khi
  `index == hasGetCount + 1` (`CUIActivityFund.lua:604`) và chỉ hiện "CanGet" khi `userLevel >= config.Level`
  (`:455`). Không phải ta tự nghĩ.
* **[MOI-4]** Quỹ thời gian: mỗi ngày một bậc, hết bảng thì thôi. Khoá này **không có UI nào gọi** trên cây
  (`grep TimeFund` chỉ ra đúng hàm `CallGetTimeFundPrize`) nên rủi ro thấp.
* Mã riêng của lớp offline: **4002** `Activity.ConfigError` (thiếu cấu hình/hết bậc) · **4007**
  `HasGetActivityPrize` (hôm nay đã lĩnh).
* Callback đi bằng **SỰ KIỆN** `Active.OnBuyActivityFund` mà `CUIActivityFund:52` đăng ký nghe — KHÔNG gọi
  thẳng `g_CUIActivityFund` (panel chưa mở thì đối tượng chưa có layer).

### Cổng sau lượt này

```
python _kiem_cu_phap.py   -> kiem 52 tep, loi 0
python _chay_het.py       -> TONG: 22 tep · dat 317 · hong 0 · do 0
python _phu_rpc.py        -> da co handler: 156 / 511
python build.py           -> 52 tep + require.lua, diff voi cay nguon RONG
```

Bộ thử mới: `_thu_hoat_dong.lua` **27/27** · `_thu_quy_hoat_dong.lua` **20/20**.

### `handlers/hoat_dong_tich_luy.lua` — TÍCH LUỸ NẠP / TÍCH LUỸ TIÊU (4 khoá)

`G_ActivityCumulativeRecharge|ClientGetUserState` · `ClientGetPrize` · `G_ActivityCumulativeConsume|ClientGetUserState`
· `ClientGetPrize`.

Hình dữ liệu **đọc từ chính UI**: cấu hình là **MẢNG** bậc — `{Recharge, PrizeList}` cho tích luỹ nạp
(`CUIActivityAccumRecharge:updateItemData`) và `{Consume, PrizeList}` cho tích luỹ tiêu
(`CUIActivityAccumConsume:updateItemData`); `state` là bản đồ `[tostring(index)] = true/1` (chú thích của chính
bản gốc: máy chủ chỉ gửi `[true/1/nil]`). Callback là **phương thức** `OnGetCumulativeRechargeData(nạp, state)` /
`OnGetCumulativeConsumeData(tiêu, state)`.

**Nguồn số:**
* **Nạp** = `G_RechargeLogic:GetUserRechargeCount()` — THẬT; `OfflineNap:cong` (`nap <tiền>` / chat `nap 100`) là
  đường làm nó tăng.
* **Tiêu** = bộ đếm mới `OfflineTichLuy` cắm vào `G_UserLogic:CostGold`/`CostDiamond` (`[MOI-1]`) — vì cây
  **không có** hàm `GetUserConsumeCount` nào (grep = 0). Bọc lớp theo đúng cách `OfflineThongKe` đã bọc
  `AddFatigueValue`; **chỉ đếm khi hàm gốc trả `true`** (trừ thành công). `init.lua` gọi `dam_bao()` trong
  `Offline:start()` và ghi log nếu bọc hỏng.
* **Bậc thưởng** vẫn do `offline/hoat_dong.lua` cấp — hai hoạt động này hiện **ĐÓNG** (`DONG`), handler CHẠY
  ĐƯỢC ngay khi chủ dự án điền `OfflineHoatDong.MO_THEM`.

Mã lỗi nhóm `ErrorCode.Activity`: **4001** (chưa mở / bậc không tồn tại — `[MOI-2]`) · **4007** đã lĩnh ·
**4008** thiếu lượng nạp · **4009** thiếu lượng tiêu.

Đo: `python _thu_nha_cua.py _thu_hoat_dong_tich_luy.lua` → **26/26 DAT**.

### Cổng sau lượt này

```
python _kiem_cu_phap.py   -> kiem 53 tep, loi 0
python _chay_het.py       -> TONG: 23 tep · dat 343 · hong 0 · do 0
python _phu_rpc.py        -> 156 handler / 511   (4 khoá mới KHÔNG làm số này tăng:
                             ClientGetUserState/ClientGetPrize đã được phủ bởi module khác)
python build.py           -> 53 tep + require.lua, diff voi cay nguon RONG
```

> **Còn lại của họ hoạt động, KHAI RÕ LÀ CHƯA LÀM ĐƯỢC:** `ClientGetSingleRechargePrize` (cần DANH MỤC SẢN PHẨM
> nạp — `GameRechargeConfig` chỉ có `FirstRechargePrize`) · `ClientGetLevelCapacityPrize` (luật thưởng cuối kỳ
> nằm trong máy chủ đã chết) · `ClientGetRechargeSignMonthConfig`/`ClientRechargeSignReward` (cần dữ liệu THÁNG
> `SignDetail`/`HeroSprite` + biến `RECHARGESIGN_OPENMONTH`; biến ấy `nil` ⇒ `IsOpenLuxurySign()` trả false nên
> client **không bao giờ gọi** hai khoá này).

---

## 31/10 (tiếp 3) — BỘ THỬ PC `run_tests.py` ĐÃ ĐỎ TỪ 30/10, NAY XANH LẠI

`run_tests.py` (lupa + `test/mock.lua` + `test/run.lua`) chạy **cả chuỗi vào game** của lớp offline trên
PC — mạnh hơn các bộ `_thu_*.lua` (chúng chạy từng tệp với API giả). Lượt này chạy nó lần đầu sau 28/10 và
**nó ĐỎ đúng một phép**: `nTables == 38` trong khi khoi userData có **39** bảng.

* Nguyên nhân: `offline/nha_cua.lua:330-334` (30/10) **TỰ thêm `GameUserBuilding`** vào `OfflineStore.TABLES`
  lúc nạp. Phép kiểm ấy là phép DUY NHẤT bắt được việc đó — và nó chỉ chạy trên `sc/offline`, mà cây ấy đã
  **tụt lại** từ 28/10 (xem mục trên) ⇒ suốt 30–31/10 bộ thử đo một cây CŨ và vẫn XANH.
* Đã sửa kỳ vọng **38 → 39** kèm dấu vết, và thêm **mục 18** — phép kiểm **KHOÁ ĐĂNG KÝ** cho 20 cặp
  `(objName, funcName)` của các nhóm 30–31/10 qua `OfflineRouter:getFor` (đúng hàm dispatch dùng). Sai tiền tố
  obj là handler **không bao giờ chạy mà không có lỗi nào** — bộ thử tĩnh không bắt được kiểu hỏng ấy.

```
python run_tests.py  ->  dat 157, hong 0   (truoc luot nay: 151 / 1, tren cay cu 147 / 0)
```

**BỘ CỔNG ĐẦY ĐỦ (chạy cả bốn trước mỗi lần `deploy.py --push`):**

```
python _kiem_cu_phap.py   # cu phap, 53 tep
python _chay_het.py       # 23 bo thu tinh, 343 phep
python run_tests.py       # chuoi vao game tren PC, 157 phep
python build.py           # dung deploy/plain + deploy/sng
```

---

## 31/10 (tiếp 4) — NGHIỆM THU THẬT TRONG GAME: LỚP OFFLINE TỪNG **LÀM GAME THOÁT**

### Lỗi chặn đường — đã tìm ra và vá

Chạy trên LDPlayer, logcat in:

```
load lua file failed : [.../offline/handlers/hoat_dong_tich_luy.lua]:95:
                       attempt to index local 'self' (a nil value)
onSystemExit
```

`init.lua` gọi `OfflineTichLuy.dam_bao()` bằng **DẤU CHẤM** ⇒ `self = nil` ⇒ ném ngay trong `require`
⇒ **cả lớp offline không nạp, game THOÁT**. Triệu chứng trên màn hình **chỉ là splash đứng im**, y hệt
"bị panel SDK chặn" — nên suốt 30/10 chẩn đoán sai chỗ.

Vá hai lớp: gọi bằng dấu hai chấm, VÀ `dam_bao()` tự chịu được lời gọi bằng dấu chấm
(`local this = self or OfflineTichLuy`). Thêm phép thử gọi bằng dấu chấm vào `_thu_hoat_dong_tich_luy.lua`
— bộ thử tĩnh cũ gọi bằng dấu hai chấm nên **không bao giờ bắt được** kiểu lỗi này.

### Đường chạy THẬT (đã chạy trọn, không phải suy đoán)

```
"C:/LDPlayer/LDPlayer9/adb.exe" root                       # uid=0
adb shell "nohup /data/local/tmp/frida-server >/dev/null 2>&1 &"
python build.py && PATH="/c/LDPlayer/LDPlayer9:$PATH" python deploy.py --push
adb shell am force-stop com.cmn.buatanew
python -u frida/chay_trace.py --spawn --tep be_sdk_spawn_bundle.js --giay 60
```

`be_sdk_spawn_bundle.js` thay `Userxsdk.login` ⇒ **panel Kull SDK không hiện**, game vào thẳng Main.
Lớp offline in `san sang — 175 handler`.

### KẾT QUẢ ĐO ĐƯỢC (ảnh + file lưu, không phải "có vẻ chạy")

| bước | bằng chứng |
|---|---|
| Tab **Quỹ Đầu Tư** hiện | giá `500` ngọc, `VIP0 trở lên`, 12 bậc Lv25→Lv80 khớp `ActivityLevelFundConfig` |
| Bấm **Mua Ngay** với 110 ngọc | client tự chặn (`IsCanBuyFund`), KHÔNG gửi request — đúng |
| Sửa file lưu lên 5000 ngọc, mua lại | log `quy hoat dong: da mua LevelFund (gia 500 kim cuong)`; **Diamond 5000 → 4500** |
| Lĩnh bậc 1 (Lv25, X588) | log `da linh bac 1 cua Quy cap (PrizeID 109101)`; popup "Nhận Thưởng: Ngọc X588 · Đá Lam X1 · Bạch kim X1"; **Diamond 4500 → 5088**; `ActivityFoudGetCount_LevelFund: 1` |

**Một chỗ còn xấu (mỹ quan, không phải lỗi):** bong bóng thoại hiện *"Quá Lv99999 ko thể mua!"* vì UI đọc
`tState.LargestUserLevel or 99999` mà lịch của ta không đặt trường ấy. Muốn đổi thì thêm
`LargestUserLevel = <số>` vào trạng thái trong `offline/hoat_dong.lua`.

---

## 31/10 (tiếp 5) — TỰ KIỂM TRONG GAME: HAI LỖI THẬT NỮA

Bấm UI để nghiệm thu từng panel là đường rất đắt trên máy này (panel **Ma Động / Lôi Đài / Chiêm Tinh nuốt
cả BACK lẫn nút mũi tên**), nên đã làm **harness tự kiểm chạy trong game**: `offline/thu_nhom_moi.lua` gọi
THẲNG handler qua `OfflineRouter:getFor(obj, func)` với `ctx` giả, sau khi đã vào cảnh Main. **Bật/tắt
không cần build lại** — chỉ chạy khi có tệp cờ:

```
adb shell touch /data/user/0/com.cmn.buatanew/files/selftest.flag    # bật
adb shell rm    /data/user/0/com.cmn.buatanew/files/selftest.flag    # tắt
```

### LỖI 1 — gọi helper trên LỚP thay vì THỰC THỂ

`handlers/luyen_hero.lua` gọi `HeroPracticeLogic:IsCanPracticeHero(...)` trên **LỚP**. `class()` giữ phương
thức trong một **`vtbl` ẩn** (`share/class.lua`), nên `HeroPracticeLogic.IsCanPracticeHero` là **nil** ⇒ mọi
lời gọi trả `nil` ⇒ handler trả mã **1** vô nghĩa. Đo trong game: *"gán tướng vào ô: ma=1"* trong khi
`GetPracticeInfo` (không cần helper) vẫn chạy đúng — chính cặp lệch ấy chỉ ra chỗ hỏng.
Vá: gọi qua **thực thể** `G_ClientQuestLogic` + proxy lớp cha (`o[HeroPracticeLogic]`), đúng lối các handler
khác dùng. Bộ thử `_thu_luyen_hero.lua` được dựng lại **đúng hình dạng thật** (lớp KHÔNG lộ phương thức) nên
nếu ai gọi trên lớp lần nữa là ĐỎ ngay.

### LỖI 2 — quên bảng trong `OfflineStore.TABLES`

Handler luyện hero chạy đúng (callback `Statistics.OnPracticeHero`) nhưng file lưu **không có khoá
`GameUserHeroPractice`** ⇒ `PracticeStates` mất sau mỗi lần vào game. Đúng họ bẫy của `GameUserCavern`
(28/10) và `GameUserFortuneWheel`. Vá: thêm vào `TABLES` (`store.lua`); bảng **không** thuộc `TU_DUNG` vì
client tự dựng `PracticeStates = {}` khi thiếu. Phép đếm bảng trong `test/run.lua` **39 → 40** — nó bắt
đúng thay đổi này ngay lượt chạy sau.

### KẾT QUẢ TỰ KIỂM TRONG GAME (log thật, sau khi vá)

| nhóm | kết quả | nghĩa |
|---|---|---|
| trận pháp nâng cấp | `ma=1201` | handler chạy, cổng `Item.NotEnoughItem` đúng (thiếu nguyên liệu) |
| thời trang ghép Coat005 | `ma=3305` | cổng `NotEnoughItemForCompose` đúng (thiếu 15×10) |
| luyện hero gán ô 1 | `ma=0` → `Statistics.OnPracticeHero` | **chạy đúng** sau khi vá lỗi 1 |
| luyện hero GetPracticeInfo | `ma=0` → `G_ClientQuestLogic.ClientGetPracticeInfo` | đúng (bảng rỗng là `[GHIM-C]`) |
| thẻ tháng khi chưa có thẻ | `ma=1` | từ chối đúng |
| kích hoạt thẻ (luật gốc) | `true`, rồi `ClientGetReward` → `ma=0` (lần đầu trong ngày) | **chạy đúng** |
| tích luỹ nạp / tiêu (đang đóng) | `ma=4001` | đúng thiết kế |
| quỹ cấp đã lĩnh hết bậc | `ma=4002` | đúng thiết kế |

File lưu sau lượt chạy: `GameUserHeroPractice.PracticeStates["1"] = {HeroID=25, BeginTime=…}` ⇒ **đã lưu được**.

> **Lưu ý khi dùng harness:** nó KHÔNG idempotent — mỗi lượt lại kích hoạt thẻ tháng (+30 ngày), nên
> `MonthlyCardLeftCountNormal` đã lên **59**. Chỉ bật trên bản lưu thử.

---

## 31/10 (tiếp 6) — TINH HỒN + MỘT LỖI CỦA CHÍNH CLIENT

### `handlers/tinh_hon.lua` — 13 khoá `G_StarSoulProtocol`

Bắt được TRONG GAME: mở panel Chiêm Tinh thì log ghi `THIEU G_StarSoulProtocol.ClientGetReq`; không có
phản hồi nên `_isServerInited` mãi `false` và panel mở **nửa vời**.

* Tên callback **sinh lúc chạy**: `XingHunData.lua:159` gọi
  `CUIAssist.bindRpcToEvent(..., "Client%sReq", "Client%sRsp")` ⇒ phản hồi là `Client<X>Rsp`, một
  PHƯƠNG THỨC trên thực thể `g_StarSoulProtocol`, nhận đúng MỘT tham số. Tên này **không tồn tại dưới
  dạng hằng số** ở đâu trong `api.lua`/spec ⇒ mọi phép quét chuỗi đều mù.
* **`ClientGetReq`** trả **dữ liệu THẬT** (`StarSoulDataManager:GetUserStarSoulData`).
* **12 khoá thao tác** → **5400 `StarSoul.Closed`**: phần luật (triệu hoán/khảm/tháo/gộp/mua ô/bán)
  KHÔNG có thân hàm trong `share/` — chỉ có helper ĐỌC. Trả 5400 là khai đúng sự thật, cùng quyết định
  với `bravecross-server` (`src/handlers/tinh_hon.ts`, Mốc 4).
* `GameUserStarSoul` thêm vào **`TU_DUNG`**: `GetUserStarSoulData` chỉ tự lành khi bảng là **nil**
  (`share_StarSoulDataManager.lua:76-95`), không lành với `{}` — mà `initUserDataFromDB` trả `{}` cho
  bảng không thuộc `TU_DUNG`. Phép đếm bảng trong `run_tests.py` **40 → 39** (bảng vắng mặt lúc khởi động).

**Đo trong game sau khi vá:** `tinh hon: ClientGetReq -> tra du lieu (pack=0 mon)`; tab **Khảm Tinh**
hiện đủ 5 ô hồn (Lv50…Lv80); bấm đổi tab → `ClientSortPackReq -> 5400` và toast **"Hệ thống chưa mở"**.

### Lỗi của CHÍNH CLIENT — `CUINewHandPrivilege`

Log lúc vào Main: `CUINewHandPrivilege.lua:127: attempt to index global 'sngLNewHandPrivilege' (a nil value)`
⇒ lỗi ấy **cắt ngang `OnReciveResponse`**, các mục sự kiện phía sau trong CÙNG gói không chạy.

Nguyên nhân: `__initGetHud` (`:369-374`) kiểm `sngLNewHandPrivilege ~= nil` cho **dòng đầu**, rồi **dòng
ngay sau** vẫn gọi `self:__getRootNode()` — hàm ấy đọc thẳng `sngLNewHandPrivilege:getChildByStringTag`.
Vá ở lớp offline: bọc `__getRootNode` của thực thể để **trả `nil` khi node vắng** — chính `__initGetHud`
đã có `if pRootNode == nil then break end` ngay dưới, tức đây là hành vi nó MUỐN có.
Kiểm: log sau khi vá **0** dòng `sngLNewHandPrivilege`.

---

## 31/10 (tiếp 7) — TINH HỒN: NĂM KHOÁ THAO TÁC LÀM THẬT

Trước đó cả 13 khoá trả `5400 Closed`. Nay **5 khoá TẤT ĐỊNH** làm thật, 7 khoá còn lại vẫn trả 5400
nhưng **mỗi khoá một lý do riêng** (`CHUA_LAM` trong `handlers/tinh_hon.lua`).

| khoá | luật |
|---|---|
| `ClientSortPackReq` | chất lượng GIẢM DẦN → cấp → exp → `star_soul_id` (thứ tự tất định) |
| `ClientSellReq(i, id)` | xoá món, cộng `StarSoulStaticConf[id].price` vàng; `price = 0` → từ chối, KHÔNG xoá |
| `ClientBatchSellReq` | bán mọi món `price > 0`, giữ món `price = 0`; cộng tổng giá |
| `ClientMountReq(t)` | `pack[pack_idx]` → `career[career_id][cell_id]`; ô đang có món thì **món cũ về kho** |
| `ClientDemountReq(t)` | `career[career_id][cell_id]` → kho |

Dữ liệu là CHÍNH bảng `GameUserStarSoul` trong `G_DataManager`, sửa tại chỗ rồi `syncFromClient()`.

7 khoá CHƯA LÀM, lý do từng khoá: `Divine`/`BatchDivine` (`ClientDivineReq()` **không đối số** ⇒ không biết
loại chiêm bốc trong 5 loại giá 15000…145000) · `ConjureZiwen` (không đối số, không có công thức) ·
`BuyPack` (không có bảng giá mua ô) · `UpgradeInCell`/`UpgradeInPack`/`BatchUpgrade` (không có luật gộp cấp,
`ClientBatchUpgradeReq()` cũng không đối số nên máy chủ phải tự chọn cặp gộp).

### BẪY ĐO ĐƯỢC: `star_soul_id` phải là **CHUỖI**

Config manager đánh lại khoá `StarSoulStaticConf` theo **`star_soul_str_id`** (`updateStarSoulStaticConf`,
`share_configManager.lua:4066+`), mà `XingHunData:getXingHunTypeConfig(typeId)` tra `cfg[typeId]`.
Để `star_soul_id` là SỐ thì `cfg[1001]` là `nil` ⇒ `getXingHunArrInBagInOrder` `break` ⇒ **danh sách túi
RỖNG HOÀN TOÀN** dù `Túi: 3/100` vẫn đúng. Đổi sang chuỗi là 3 món hiện ra (Thất Sát Lv1 · Tham Lv5 · Bá Qua Lv1).

**Đo trong game:** `ClientGetReq -> tra du lieu (pack=3 mon)` · chuyển tab Khảm hồn → `sap kho 3 mon` · danh
sách túi hiện đủ 3 món.

### 31/10 (tiếp 8) — CHIÊM BỐC ĐƠN: KHOA THỨ 6 CỦA TINH HỒN

`ClientDivineReq()` **không đối số**, nhưng KHÔNG cần: loại chiêm bốc là `cur_divide` trong bảng người chơi
(`InitData = 1`; `AddToBagByDivine` tăng rồi quay vòng 1..5).

* **Giá** = `StarSoulDivineConf[cur_divide].price` **VÀNG** — UI đọc đúng trường ấy rồi `BuyWithGold`
  (`CUIZhanXing.lua:114-116`).
* **Chất lượng** = dùng ĐÚNG hình config manager dựng sẵn: `DS[divine_id].no_use_diamond =
  {max_chance, chances = {{quality,max_chance},…}}` (`updateStarSoulDivineChanceConf` :4196-4248) — `max_chance`
  đã LUỸ KẾ, chỉ cần bốc đều trong `[1,max_chance]`. Nhánh `use_diamond` (divine 4/5) là `[GHIM]` chưa làm.
* **Cất + tăng `cur_divide`** = `StarSoulDataManager:AddToBagByDivine(strId, quality, true)` — hàm GỐC.
* Trả `ClientDivineRsp({ <hồn> })` — **MẢNG**, vì `setZhanXingResult` lấy `data[1]`.

**BẪY ĐO ĐƯỢC:** ba bảng cấu hình của hệ này KHÔNG phải mảng — `StarSoulStaticConf` đánh lại theo
`star_soul_str_id` (chuỗi), `StarSoulDivineChanceConf` đánh lại thành **bản đồ lồng** `[divine_id][quality]`.
`ipairs` trên chúng trả RỖNG ⇒ handler báo nhầm "thiếu bảng tỉ lệ". Đã thêm bộ đi `quet()` chịu cả hai hình.

**ĐO TRONG GAME:** `chiem boc loai 1 (-15000 vang) -> hon 1034 (chat luong 1)`; vàng 168460 → **153460**; file lưu
`cur_divide: 2`, túi **4 món** (món mới `1034`, `quality = 1`).

### 31/10 (tiếp 9) — GỘP CẤP TINH HỒN (khoá 7 và 8)

`ClientUpgradeInPackReq(pack_idx, xhData, arr)` và `ClientUpgradeInCellReq(career_id, cell_id, xhData, arr)`.

Luật gộp **nằm trong client**, không phải máy chủ chết — ghép đúng hai hàm của nó:
`XingHunData:getXingHunLevelExpAbsolute` (`:522-546`, quy một món về TỔNG exp tuyệt đối) và
`getXingHunLevelAndExpRelative` (`:549-570`, chia ngược ra cấp/exp). **DANH SÁCH MÓN TIÊU do chính client chọn**
và gửi kèm `arr` (`CUIXingHunDetail.lua:396-427`) ⇒ máy chủ chỉ ÁP, không tự chọn.

Chi tiết dễ sai: xoá món tiêu phải đi **TỪ CHỈ SỐ LỚN XUỐNG**, nếu không chỉ số trôi và xoá nhầm món.

Đo: `_thu_tinh_hon.lua` **38/38** · cổng `_chay_het.py` **383 phép · 0 đỏ**.

## 31/10 (tiếp 10) — `CON-LAI.md`: bản kiểm kê khoá còn thiếu (sinh tự động)

`python -I _con_lai.py` sinh `CON-LAI.md` từ chính cây client chỉ-đọc, cộng bảng `PHAN_LOAI` (kết luận ĐÃ ĐO
của các lượt trước). Số chốt lượt này: **511 tên hàm client gọi · 156 có handler · 355 còn thiếu**
(381 nếu đếm theo cặp module+tên).

Phân loại: **nhiều người 143** · **0 thân hàm 62** · **dữ liệu toàn server 19** · **SDK chết 16** ·
**thiếu luật 17** · **chưa phân loại 132** (trong đó `(toàn cục)` **56** — bạn bè, hướng dẫn, mail biến thể,
lệnh dev, đăng ký/đăng nhập SDK).

> Vì sao không "làm hết cho xong": mỗi khoá trong nhóm chưa phân loại cần đọc đúng chỗ gọi + trạng thái client
> của riêng nó; gộp chúng thành một lượt là đoán. `CON-LAI.md` để lượt sau chọn theo NHÓM LÝ DO thay vì dò lại.

### 31/10 (tiếp 11) — NHÓM `objName` RỖNG: 7 khoá "bắn rồi quên"

`handlers/toan_cuc.lua` khai `R:ignore` cho 7 khoá — **không bịa luật nào**, mỗi khoá ghi rõ vì sao nuốt được:

| khoá | vì sao nuốt được |
|---|---|
| `ClientBeginGuide` / `ClientCompeleGuide` | `CServerRequestLogic.lua:369-375` chỉ `CallServer`, **không** bắn `OnWaitingForRequest`; lớp offline đã tắt hướng dẫn |
| `ClientSystemLog` | `system/rpc.lua:238` — dòng **đã chú thích**, không ai gửi |
| `ClientGetMissionData` | `CUIChapterList.lua:955` — dòng **đã chú thích** |
| `ClientTestAddMail` / `ClientTestFullLevelResouces` / `ClientTestFullWorker` | lệnh thử của bản dev, không có nút trên bản phát hành |

Bẫy nhỏ đã vấp: bộ quét `_phu_rpc.dang_ky()` chỉ nhận dạng `R:ignore(...)`, tôi viết `OfflineRouter:ignore(...)`
nên 7 khoá ấy **không được đếm**. Đổi sang `R:ignore` là số nhảy: **156 → 163 tên có handler, 355 → 348 còn thiếu**.

**Còn 12 khoá của nhóm này chưa làm** (bạn bè ×6, potion ×6, ải ×2, đăng ký/đăng nhập ×4, quy đổi kim cương→vàng,
điểm danh, nhận quà, ghép/đổi trang bị…) — mỗi khoá phải đọc hình phản hồi riêng.

### 31/10 (tiếp 12) — QUY ĐỔI KIM CƯƠNG → VÀNG (`ClientReduceDiamondToGold`)

Luật **có sẵn trong `share/`**: `CDataManager:reduceDiamondToGold` (`share_CDataManagerPrivate.lua:710-724`):
`NeedDiamond = ceil(nGoldNum^0,89 / 100)`, và điều kiện là **`getDiamond() > NeedDiamond` (NGẶT)** — bằng đúng
vẫn từ chối. Handler CHỈ tính rồi trả `{err=0, data={NeedDiamond, NeedGold}}`; **chính client** áp thay đổi
(`OnReduceDiamondToGold` tự `ReduceDiamond` + `AddResource(Gold)`) ⇒ trừ thêm ở máy chủ là **trừ ĐÔI**.
Mã lỗi: 4 tham số hỏng · 1702 thiếu kim cương. Đo: `_thu_toan_cuc.lua` **8/8**.

**Còn 11 khoá nhóm này**: bạn bè ×6, potion ×6 (hệ CHẾT trong bản gốc), `ClientSignIn` (`AwardSignIn` không có
trong `share/`), `ClientStartLottery`, ghép/bán trang bị, đăng ký/đăng nhập (SDK).

### 31/10 (tiếp 13) — SÁU KHOÁ THUỐC: HỆ CHẾT, nuốt lặng (13 khoá nuốt lặng tổng cộng)

`ClientBuildPotion` · `ClientCancelBuildPotion` · `ClientCompleteBuildPotion` ·
`ClientCompleteBuildPotionWithDiomaon` · `ClientCancelUpgradePotion` · `ClientCompleteUpgradePotionWithDiomaon`.

Đo: **bốn** chỗ gọi (`CServerRequestLogic.lua:84/89/95/101`) nằm TRONG `--`; **bốn** hàm nhận cũng bị chú thích
(`CServerResponseLogic.lua:522+`); **hai** lệnh còn sống (`:112`, `:124`) chỉ `CallServer`, KHÔNG bắn
`OnWaitingForRequest` ⇒ không chờ phản hồi. Cộng: `PotionConfig` bị chú thích trong `ConfigTableName` ⇒ gọi
luật là nổ `class.lua:66`. Vậy nuốt lặng là ĐÚNG, không phải bỏ sót.

> **BẪY (đã vấp 2 lần):** bộ quét `_phu_rpc.dang_ky()` cắt khối `R:ignore(...)` tại **dấu `)` ĐẦU TIÊN**, nên
> chú thích có ngoặc đơn nằm TRONG danh sách làm 6 khoá không được đếm (số đứng im 164/347). Đưa chú thích ra
> NGOÀI `R:ignore(` là số nhảy: **170 handler / 341 còn thiếu**.

---

## 📌 GHI CHÚ NGÀY MAI (viết cuối 31/10)

**Cổng phải xanh trước khi push** (chạy cả bốn):
```
python _kiem_cu_phap.py   -> 56 tep, loi 0
python _chay_het.py       -> 25 tep · 391 phep · 0 do
python run_tests.py       -> dat 159, hong 0
python -I _con_lai.py     -> CON-LAI.md: 170 handler / 341 con thieu
python build.py && PATH="/c/LDPlayer/LDPlayer9:$PATH" python deploy.py --push
```

**Đã xong trong ngày 31/10:** trận pháp · thẻ tháng · thời trang · luyện hero · lịch hoạt động (Quỹ cấp/Quỹ thời gian) ·
tích luỹ nạp/tiêu · **tinh hồn 8/13** (đọc, sắp kho, bán một, bán hết, khảm, tháo, **chiêm bốc**, **gộp cấp**) ·
13 khoá toàn cục nuốt lặng · đổi kim cương→vàng.

**Năm lỗi thật đã vá — đừng tái phạm:** `self` nil làm **game thoát** (chỉ thấy splash đứng) · gọi helper trên LỚP
thay vì THỰC THỂ · thiếu bảng trong `TABLES` · `sc/offline` lệch `deploy/` · `__getRootNode` của
`CUINewHandPrivilege` nổ khi node chưa dựng.

**Bốn bẫy công cụ:** `_phu_nhom.py` từng so khoá nguyên văn · `_phu_rpc` chỉ nhận `R:ignore(` và **cắt tại dấu `)`
đầu tiên** (chú thích có ngoặc đơn phải đặt NGOÀI) · `build.py` chết vì thư mục cờ `R` (đã có `xoa_cay()`) ·
`_con_lai.py` đọc `sc/offline` nên **phải đồng bộ cây trước khi sinh số**.

**Năm bẫy dữ liệu:** `star_soul_id` phải là CHUỖI · config manager đánh lại khoá (bản đồ lồng / khoá chuỗi, `ipairs`
trả rỗng) · `GameUserStarSoul` phải ở `TU_DUNG` · client tự áp kết quả ở vài lệnh (máy chủ trừ thêm = trừ ĐÔI) ·
`IsUpgrading` là CỜ, đừng suy từ `UpgradeLeftTime = 0`.

**Việc kế:** (a) **bạn bè ×6** — phải VIẾT MỚI · (b) `ClientSignIn` / `ClientStartLottery` / ghép-bán trang bị ·
(c) 5 khoá tinh hồn còn lại · (d) bấm tay nghiệm thu gộp cấp + bán/khảm (tap không chọn được món) ·
(e) về `bravecross-server`.

---

## 1/11 — PHÂN LOẠI 42 KHOÁ "TOÀN CỤC" + HAI HỆ MỚI (QUÀ 7 NGÀY · ĐIỂM KIM THỦ)

### 1. Công cụ mới: `_phan_loai_toancuc.py`

Trước đây 42 khoá `objName` RỖNG còn thiếu chỉ được đếm, không biết khoá nào **còn sống**.
Tệp này phân loại bằng chứng cứ, không bằng cảm giác:

1. **Bỏ chú thích Lua TRƯỚC khi quét** — bản gốc chôn cả tệp trong `--[=====[ … ]=====]`
   (`user/UI/CUIFriend.lua` mở bằng khối 4 dấu `=` và đóng ở cuối tệp) và nhiều hàm trong
   `--[[ … end--]]` (`CServerRequestLogic.lua:181-198` là `Decompose/Sell/ForgeEquipment`).
   Bộ bỏ chú thích phải đọc ĐÚNG CẤP `--[=*[` … `]=*]`, không chỉ `--[[ ]]`.
2. Lui về hàm bao quanh `CallServer(...)` rồi đếm lời gọi **theo ĐÚNG lớp/thực thể**
   (`G_ChapterLogic = ClientChapterLogic:new()` → tập tên gọi hợp lệ), trừ dòng định nghĩa.
   Đếm trần `:TenHam(` cho ra dương tính giả nặng: `ClientAwardAhieve` "sống" chỉ vì
   `ClientAchieveLogic:AwardAchieve` trùng tên.
3. Callback do ENGINE gọi theo tên (`onTouchBegin_*`, `onTouchEnd_*` … đăng ký bằng
   `setEnableLuaTouch`) không có ai grep thấy — phải tính là SỐNG.

**KẾT QUẢ (42 khoá): 12 SỐNG · 23 CHẾT (hàm bao quanh 0 người gọi) · 7 NẰM TRONG CHÚ THÍCH.**
25/42 khoá trước đây bị coi là "còn thiếu" thực ra **không tồn tại đường gọi** — nuốt lặng là
ĐÚNG. Đáng chú ý: `CUIFriend.lua` **bị chú thích toàn bộ** ⇒ cả nhóm bạn bè (`ClientGetUserRelation`,
`ClientSearchUserWithUserName`, `Agree/Refuse/RemoveFriendApply`, `ClientRemoveFriendRelation`)
là mã CHẾT, không phải "phải viết mới" như ghi chú 31/10 vẫn nói.

### 2. `handlers/qua_7_ngay.lua` — QUÀ ĐĂNG NHẬP 7 NGÀY

Khoá `G_SevenDaysGiftLogic|ClientSevenDaysGift(nDay)`, nút "Nhận" của `CUISevenDaysGift`
(mở từ `CUIMainTopTool:onTouchEnd_btnSevenDaysGiftUI`). Luật là **mã gốc còn sống**
`SevenDaysGiftLogic:saveSevenDaysGiftWithDay` — tự chặn quá ngày / chưa mở / đã nhận, đọc
`GameSevenDaysGiftConfig.DayList[nDay].PrizeList` (7 ngày × 3 món, cấu hình THẬT) và phát qua
`G_ChapterLogic:SetDataWithPrizeList`. Mã lỗi trả NGUYÊN: 3201 quá ngày · 3202 chưa mở · 3203 đã nhận.

### 3. `handlers/kim_thu.lua` — ĐIỂM KIM THỦ (đổi kim cương lấy vàng)

Khoá `G_MidasTouchLogic|ClientRunMidasTouchWithCount(nCount)`. Luật gốc
`MidasTouchLogic:runMidasTouchWithCount(nCount, tRandomList)`: trần theo VIP
(`VipConfig.MidasTouchCountList`, VIP0 = **10/ngày**), giá từng lượt theo
`GameMidasTouchConfig.CostList` (140 bậc: 5→20→30→40 kim cương), **hệ số** rút từ `TimesMap`
(`{50:1, 35:2, 10:3, 5:10}` → ngẫu nhiên máy chủ sinh, luật rút). Máy chủ CHỈ sinh
`math.random()` — đúng khuôn của vòng quay / bánh tân thủ. UI **không** tự cộng vàng
(grep `AddGold` trong `CUIMidasTouch.lua` = 0) nên không có trừ/cộng ĐÔI. Trả đủ NĂM trường
`nCount/tRandomList/tDiamondCostList/tGoldGetList/tTimesList` (UI đọc cả năm).

### 4. `offline/qua_ngay.lua` — NHỊP "VIỆC MÁY CHỦ LÀM MỖI NGÀY"

`MidasTouchLogic:ResetDaily` và `SevenDaysGiftLogic:SetDailyLogin` **0 chỗ gọi** trong cả cây
client (grep). Không gọi thay thì quà 7 ngày đứng ở ngày 1 vĩnh viễn và lượt kim thủ cộng dồn
chạm trần một lần là khoá. Tệp này nối vào sự kiện `OnEnterGame` (KHÔNG gọi trong
`Offline:start()` — lúc ấy `OfflineBootstrap:ensure()` chưa chạy, dữ liệu người chơi chưa có;
cùng lý do với `offline/luc_chien.lua`), khoá ngày theo mốc **5 giờ** (`DialyRefreshHour`),
ghi `C_OfflineQuaNgayDay`. Mỗi hệ bọc `pcall` riêng; khoá ngày chỉ ghi SAU khi cả hai đã có
cơ hội chạy. **[MOI]**: nhịp là quyết định của lớp offline, luật + giá vẫn là dữ liệu gốc.

### 5. ĐO TRONG GAME (LDPlayer, 1/11 13:58–13:59)

```
qua 7 ngay: ngay moi — da mo them mot ngay qua
kim thu: ngay moi — da dat lai luot diem kim thu
qua ngay: sang ngay moi (khoa cu nil -> 20261101), da chay: OfflineQua7Ngay, OfflineKimThu
qua 7 ngay: da nhan qua ngay 1
THU qua 7 ngay (ngay 1): ma=0, tra loi=G_SevenDaysGiftLogic.OnServerGetSevenDaysGift
kim thu: 1 luot — tru kim cuong 5, vang +4000 (he so 2)
THU kim thu (1 luot): ma=0, tra loi=G_MidasTouchLogic.OnServerRunMidasTouchWithCount
```

File lưu sau khi chạy: `C_SevenDaysGiftData = {GetStatusMap: {"1": 2}, DayCount: 1}` ·
`C_MidasTouchData = {CurIndex: 1}` · `C_OfflineQuaNgayDay = 20261101` · kim cương **−5** ·
vàng **+4000** (đúng `CostList[1]=5`, `TimesMap` 35% → ×2). Bản lưu trên máy **đã trả lại
nguyên trạng** (57.097 B) và tệp cờ `selftest.flag` đã xoá.

### 6. Cổng cuối lượt

`_kiem_cu_phap.py` **59 tệp · 0 lỗi** · `_chay_het.py` **28 tệp · 447 phép · 0 đỏ**
(31/10: 25 · 391) · `run_tests.py` **162 · 0** (31/10: 159) · `_con_lai.py` **172 handler /
339 còn thiếu** (31/10: 170/341). Bộ thử mới `_thu_qua_7_ngay.lua` **15/15** ·
`_thu_kim_thu.lua` **20/20** · `_thu_qua_ngay.lua` **21/21**. `test/run.lua` mục 18 thêm
2 cặp khoá + 3 phép kiểm móc ngày.

### 7. Việc kế

(a) **`_phan_loai_toancuc.py` cho 143 khoá "nhiều người"** — nhiều khả năng cùng cảnh
"tệp bị chú thích toàn bộ" như `CUIFriend.lua`; đáng quét TRƯỚC khi viết mới bất cứ nhóm nào.
(b) 12 khoá toàn cục CÒN SỐNG chưa làm: `ClientCheckNewEquipment`, `ClientGetChapterDropData`,
`ClientReturnHome`, `ClientGetSpeechContent`, `ClientSetArenaHero`, `ClientChapterHJRQComplete`,
`ClientChapterSCSComplete`, `ClientApplyForFriend`, `ClientBindingAccount`, `ClientCompleteUpgradePotion`,
`ClientAwardAhieve` (chết thật — trùng tên), `ClientStartLottery` (chết thật — client dùng
`ClientPlayLottery` rồi).
(c) 5 khoá tinh hồn còn lại · (d) về `bravecross-server`.

---

## 1/11 (tiếp) — VÁ BẪY BỘ QUÉT, PHÂN LOẠI 143 KHOÁ "NHIỀU NGƯỜI", THÊM MỤC TIÊU ẢI

### 1. VÁ `_phu_rpc.py`: khối `R:ignore(` cắt sai ở dấu `)` ĐẦU TIÊN

Bẫy đã ghi 2 lần (README 31/10) nhưng **vẫn còn trong mã**: `re.findall(r'R:ignore\s*\((.*?)\)')`
cắt tại dấu `)` đầu tiên, mà bản gốc viết chú thích có ngoặc đơn NGAY TRONG danh sách:

```lua
R:ignore(
    "ClientGetUserNewHandPrivilegeInfo",
    -- Client tự lưu (ClothingData, SevenDaysGiftData…) lên máy chủ;
    "ClientSetClientCommonData",
    -- … (`G_UserLogic:SetCommonData` đã ghi tại máy rồi)
    "ClientSetGameFuncUnLockData"
)
```

⇒ hai khoá CUỐI bị báo THIẾU OAN dù đã nuốt lặng từ 27/10. Nay `_khoi_ngoac()` đọc khối
theo **đúng cấp ngoặc**, bỏ qua chuỗi `"…"` và chú thích `-- …` / `--[=*[ … ]=*]`; thêm
`_cac_chuoi()` để không nhặt chuỗi nằm trong chú thích (`"client common data"` trước đây
bị đếm thành một khoá handler). Số: **172 → 174 handler**, thiếu theo tên **339 → 337** (bộ trước đó báo thiếu oan 2 khoá).

⚠ Cùng lượt phát hiện `brave-cross/work/` có **HAI bản giải mã**: `vn/decrypted/assets`
(973 tệp, đầy đủ — `cay.ASSETS` mà `_phu_rpc` quét) và `decrypted/assets` (952 tệp, bản
cũ). `_phan_loai_toancuc.py` trước đó quét bản THIẾU ⇒ báo "hàm không ai gọi" oan cho
những chỗ gọi nằm trong 21 tệp thiếu. Nay lấy đường dẫn từ `cay.ASSETS/sc`.

### 2. `_phan_loai_toancuc.py` mở rộng: `--nhom <module…>` / `--tat-ca`

Phân loại mọi khoá còn thiếu theo **bằng chứng**: SỐNG (có đường gọi thật) · CHẾT (hàm
bao quanh 0 người gọi) · NẰM TRONG CHÚ THÍCH · KHÔNG-CÓ-LỆNH-GỌI. Kết quả toàn bộ 363 khoá:
**279 SỐNG · 83 CHẾT/CHÚ THÍCH/KHÔNG-GỌI**.

**KẾT LUẬN ĐO ĐƯỢC — giả thuyết "nhóm nhiều người cũng là tệp bị chú thích toàn bộ" là SAI:**
131 khoá của 10 module nhiều người (bang hội, bạn bè, công thành, COG, đấu trường điểm…)
có **122 SỐNG**. Chúng là hệ nhiều người chơi THẬT, không phải mã chết ⇒ muốn làm phải
viết mô hình nhiều người, không phải "nuốt lặng". Chỉ 9 khoá chết/trong chú thích.

`_tim_port_duoc.py` (mới) dò khoá còn thiếu mà `share/` còn nguyên thân hàm (bỏ `Client`,
so không phân biệt hoa/thường): **6 ứng viên**. Đáng làm nhất là
`G_ChapterLogic.ClientGetChapterTargetReward` (ở dưới). Các ứng viên còn lại đã đo là
không đi được: `ClientCancelUpgradeArmy`/`ClientSetMailReadWithMailId` (hàm bao quanh 0
người gọi), `ClientGetPassMissionCountList` (client tự tính tại chỗ, RPC không ai gọi),
`ClientBuyTimeHero` (hoạt động đã hết hạn: `FirstEnterGameTime + 259200`).

### 3. `handlers/muc_tieu_ai.lua` — MỤC TIÊU ẢI (rương ở màn chọn ải)

Khoá `G_ChapterLogic|ClientGetChapterTargetReward({nMainChapter, nChapterDifficulty, nStage})`,
bấm từ `CUISelectLevel:onTouchEnd_OnGetChapterTargetReward2`. Luật là **mã gốc còn sống**
`ChapterLogic:getChapterTargetReward` + cấu hình THẬT `GameChapterConfig.TargetReward`
(7 chương × 3 mốc, PrizeID 101011…/102011…; đã tra 4 mã trong `KDBGamePrizeConfig` — CÓ ĐỦ).
Trả `OnServerGetChapterTargetReward({nPrizeID})` — client đòi `nPrizeID` là SỐ rồi đặt
`RetData` cho UI.

⚠ **[MOI] một chỗ chặn thay luật gốc:** luật gốc phát thưởng **TRƯỚC** rồi mới kiểm
"đã lĩnh" (`:3960-3979`) ⇒ một yêu cầu lặp cho mốc đã lĩnh là **phát thưởng LẦN HAI** rồi
mới trả 1431. UI gốc chỉ gửi khi trạng thái = 1 nên bình thường không chạm, nhưng máy chủ
giả không có ai gác hộ. Handler đọc trạng thái TRƯỚC: bằng 2 ⇒ trả 1431 luôn, không gọi luật.

### 4. ĐO TRONG GAME (LDPlayer 14:12 và 14:15, hai lượt)

```
THU muc tieu ai: trang thai chuong 1 thuong = 12=0,3=1,9=0
muc tieu ai: da linh chuong 1 / do kho 1 / moc 3, giai 101011
THU muc tieu ai (chuong 1, moc 3): tra loi=G_ChapterLogic.OnServerGetChapterTargetReward
-- lượt 2 (đã lĩnh rồi):
THU muc tieu ai: trang thai chuong 1 thuong = 12=0,3=2,9=0
muc tieu ai: chuong 1 / do kho 1 / moc 3 DA LINH -> 1431
```

File lưu: `C_TargetRewardData.NormalGetTargetRewardStatusMap["1"]["3"] = 2`; **ArmySoul
18 → 68 = +50**, đúng PrizeID 101011 (`PrizeResType 3, CurrencyType 4 = ArmySoul, 50`).
Kim cương 24436 → 24781 = **−5 (kim thủ) + 50 (quà ngày 1) + 300 (thẻ tháng)** — khớp từng
khoản. Bản lưu trên máy **đã trả nguyên trạng** (57.097 B); `selftest.flag` đã xoá.

### 5. Cổng cuối lượt

`_kiem_cu_phap.py` **60 tệp · 0 lỗi** · `_chay_het.py` **29 tệp · 463 phép · 0 đỏ** ·
`run_tests.py` **162 · 0** · `_con_lai.py` **175 handler / 336 còn thiếu theo tên**
(362 theo cặp module+tên). Bộ thử mới `_thu_muc_tieu_ai.lua` **16/16**.

### 6. Việc kế

(a) **Nhóm nhiều người (122 khoá SỐNG)** — phải VIẾT MỚI mô hình (bang hội/bạn bè/công
thành). Đây là khối lớn nhất còn lại và là quyết định của chủ dự án, không phải việc port.
(b) 16 khoá `G_ChapterLogic` còn SỐNG: các chế độ ải đặc biệt (SCS/HJRQ/TGZZ/DJSJF/XZWC/
PetBoss/ReviveInBattle) — cần đọc từng luật, có thể có phần port được.
(c) `G_HeroLogic` 10 · `G_ItemLogic` 4 · `G_EquipmentLogic` 3 — đã đo "0 thân trong share".
(d) 5 khoá tinh hồn còn lại · (e) về `bravecross-server`.

---

## 1/11 (tiếp 2) — BXH CHUNG: 4 TAB + HAI BẪY ĐỒ THỬ ĐÃ TRẢ GIÁ

### 1. `handlers/bang_xep_hang.lua` — 4 khoá `G_RankLogic`

`ClientGet5HeroPowerRank` · `ClientGetPveNormalRank` · `ClientGetPveEliteRank` ·
`ClientGetPveStarRank` (`ClientLeaderboard.lua:279/508/561/614`, thực thể `G_RankLogic`).
Trước lượt này mở tab là màn hình quay.

Bảng xếp hạng là **trạng thái máy chủ**, `share/` không có luật để port. Offline một người
⇒ bảng có **đúng một dòng của mình, hạng 1** — cùng quyết định với BXH đấu trường
(`dau_truong_bxh.lua`). Dòng ấy dựng bằng chính `G_RankLogic:GetUserHotData()`
(tên/cấp/vàng/giới tính/kim cương/chiến lực 5 tướng) — không bịa trường nào.

Ba tham số **VỊ TRÍ** `(tRankList, nSelfRank, nYesterdayRank)`, KHÔNG bọc `{err, data}` —
cả bốn hàm client đều nhận đúng ba tham số và kiểm từng cái.

### 2. ĐO TRONG GAME — và hai bẫy đã trả giá

**Bẫy A — mở panel bằng SAI dialog manager.** `g_CUISubDialog:Show(...)` không dựng các
layer ⇒ `refreshUI` thoát ở dòng kiểm userdata ĐẦU TIÊN (im lặng, không lỗi). Đường đúng là
`g_CUINormalDlg:Show(g_CUILeaderboard:GetUIName())` — y hệt
`CUIMainBuildingManager:_btnMainLeaderboard` (`:809-811`).

**Bẫy B — gọi `refreshUI` NGAY trong khung mở panel.** Các listener của UI chỉ đăng ký
trong `onVisible()`, mà `onVisible` chạy SAU khi dialog dựng xong. Đo được:
`POST OnServerGet5HeroPowerRank, so dang ky = 0` ⇒ phản hồi bắn vào khoảng không,
`t5HeroRankData` rỗng. Chờ 1 khung (scheduleOnce 1 s) rồi mới đổi tab: **`so dang ky = 1`**.

**Bẫy C — bọc hàm của UI để đo thì KHÔNG ăn.** `G_EventManager:Reg` giữ tham chiếu hàm
CŨ lúc `onVisible`; thay `g_CUILeaderboard.OnServerGet5HeroPowerRank` sau đó không bao giờ
được gọi. Phải bọc **phía logic** (`G_RankLogic.OnGet5HeroPowerRank`) — `CallLocal` tra
cứu tên LÚC GỌI.

**Bẫy D — trả bảng RỖNG thì dòng hiện "hạng 1" mà TRỐNG TÊN.** UI tự vá bằng
`self:getHotdata()`, nhưng hàm ấy đọc bảng `Hotdata` do MÁY CHỦ gửi — offline không ai
sinh. Đo: `dong 1: nil/hang 1`. Sau khi trả kèm dòng dựng bằng `GetUserHotData()`:
**`dong 1: Offline/hang 1`**, và ảnh chụp panel hiện `90 Offline` · `Top 5 tướng: 7884` ·
danh hiệu *Thiên Chùy Cực Hãn*.

### 3. Cổng

`_kiem_cu_phap.py` **61 tệp · 0 lỗi** · `_chay_het.py` **30 tệp · 485 phép · 0 đỏ** ·
`run_tests.py` **162 · 0** · `_con_lai.py` **179 handler / 332 còn thiếu theo tên**
(358 theo cặp). Bộ thử mới `_thu_bang_xep_hang.lua` **22/22**. Cây `sc/offline` =
`deploy/plain/sc/offline`; bản lưu trên máy **trả nguyên trạng** (57.097 B), cờ tự kiểm đã xoá.

### 4. Việc kế

(a) **122 khoá nhiều người** — khối lớn nhất, phải VIẾT MỚI mô hình (quyết định của chủ dự án).
(b) 16 khoá `G_ChapterLogic` còn SỐNG: chế độ ải đặc biệt (SCS/HJRQ/TGZZ/DJSJF/XZWC/PetBoss/
ReviveInBattle) — mỗi khoá một luật, có `GetTGZZChapterPrize`/`GetDKChapterPrize` trong
`share/` là **hàm tính thưởng THẬT** nên có thể port được phần kết toán.
(c) `G_RankLogic` còn 14 khoá "điểm tự thân" (HJRQ/SYZLB/SCSZL/DJSJF/XZWC/TGZZ/DK) — chỉ
đọc điểm của mình, phụ thuộc (b) vì điểm ấy do chế độ đặc biệt sinh ra.
(d) 5 khoá tinh hồn còn lại · (e) về `bravecross-server`.

---

## 1/11 (tiếp 3) — MUA VẬT PHẨM Ở CỬA HÀNG + BA CHỖ MÃ GỐC BỊ TẮT

### 1. `handlers/mua_vat_pham.lua` — hai khoá `G_ItemLogic`

`ClientBuyItem(nItemID, nCount, nResourceType)` và `ClientBuyItemBatch(buyList)`
(`ClientItemLogic.lua:296/325`). Bên gọi: `CUIBuyDialogEx` (hộp thoại "mua N cái" dùng
chung cho mọi cửa hàng) và `CUIWingLackMaterial` (mua nguyên liệu cánh còn thiếu).

Luật là **mã gốc** `ShopLogic:BuyGoods(nGoodsId, nCount)` (`share/ShopLogic.lua:26-96`):
kiểm tiền (1901), hạn mức ngày (1902), trừ tiền, cấp hàng, ghi lượt mua. Bảng giá là
**dữ liệu thật** `KDBGameGoodsConfig` — **65 dòng**, mỗi dòng `ItemId / CurrencyType /
Price / GoodsCount / MaxBuyCountPerDay / GoodsId`.

Đổi `(ItemId, CurrencyType) → GoodsId` bằng chính hàm mà UI dùng để IN RA giá
(`G_ConfigManager:GetGoodsConfigWithType`) ⇒ số tiền trừ ĐÚNG BẰNG số UI hiện.

### 2. BA CHỖ MÃ GỐC BỊ TẮT — mỗi chỗ một lỗi riêng, đều ĐO ĐƯỢC trong game

| Chỗ | Triệu chứng đo được | Cách vá |
|---|---|---|
| `require("share.ShopLogic")` **bị chú thích** (`share_gameLogic_require.lua:67`) | `ClientShopLogic = class(ShopLogic)` lúc ấy `ShopLogic` = nil ⇒ `G_ShopLogic` KHÔNG thừa kế ⇒ `attempt to call method 'BuyGoods' (a nil value)` | `require` thẳng tệp ấy rồi tự tạo thực thể `ShopLogic:new()` (không gọi trên LỚP — bẫy vtbl ẩn) |
| `ConfigManager:GetGoodsConfigWithId` **bị chú thích** (`share_configManager.lua:2235-2238`) nhưng `BuyGoods` gọi ở dòng 49 | `attempt to call method 'GetGoodsConfigWithId' (a nil value)` | Dựng lại bằng cách ĐÁNH LẠI KHOÁ từ `GetGoodsConfig()` — đo: **65 dòng giá** |
| `ClientItemLogic` KHÔNG có hàm nhận phản hồi cho `ClientBuyItem` (khối mô tả `:307-315` bị chú thích; `Item.OnBuyItem` không có chỗ phát) | lớp tải bật mà không ai tắt | Handler tự phát đúng hai sự kiện khối chú thích mô tả: `OnReceiveResponse` + `Item.OnBuyItem{ItemID, BuyCount, ResourceType}` |

### 3. ĐO TRONG GAME

```
mua vat pham: da dung lai GetGoodsConfigWithId (65 dong gia)
mua vat pham: da mua 6 x1
THU mua vat pham (6 x1, kim cuong): ok=true, kim cuong 25368 -> 25318 (tru 50)
```

File lưu: **vật phẩm 6: 0 → 2** (+1 mua, +1 quà ngày 1 — quà 7 ngày cũng cho PropID 6),
`GameUserGoods = {"12": {"GoodsId": 12, "BuyCount": 1}}` (bộ đếm hạn mức ngày). Bản lưu
trên máy **trả nguyên trạng** (57.097 B), cờ tự kiểm đã xoá.

### 4. Cổng

`_kiem_cu_phap.py` **62 tệp · 0 lỗi** · `_chay_het.py` **31 tệp · 509 phép · 0 đỏ** ·
`run_tests.py` **162 · 0** · `_con_lai.py` **181 handler / 330 còn thiếu theo tên**
(356 theo cặp). Bộ thử mới `_thu_mua_vat_pham.lua` **24/24**.

### 5. Việc kế

(a) `ClientRefineItem` / `ClientSellRedundantExclusiveItem` / `ClientRefineEquip` /
`ClientForgingExclusiveEquip` / `ClientPurifyExclusiveEquip` — cùng họ trang bị, đã đo
"0 thân hàm trong share" (cần VIẾT MỚI từ cấu hình `EquipRefineConfig`).
(b) 7 khoá `G_EndlessChapterLogic` (vô tận ải) — có `handlers/endless.lua` từ trước.
(c) 3 khoá `G_EpicChapterLogic` · (d) 122 khoá nhiều người · (e) về `bravecross-server`.

---

## 1/11 (tiếp 4) — TINH LUYỆN TRANG BỊ

### `handlers/tinh_luyen_trang_bi.lua` — `ClientRefineEquip`

Nút "Tinh luyện" của `CUIEquipment_Refine`; trước lượt này bấm là lớp tải quay mãi.

Máy chủ KHÔNG ship thân hàm, nhưng luật suy ra **chắc chắn** từ ba nguồn ĐỘC LẬP:

1. **Mã lỗi đã khai sẵn** (`share/error.lua:82-83`): `NotEnoughConcentrate = 1109`,
   `MaxRefineLevelCantRefine = 1110` — đúng hai cửa của một lệnh tinh luyện, cạnh
   `NotEquipmentExist = 1106`. Không mã nào được khai cho việc khác.
2. **Cấu hình thật** `EquipRefineConfig`: `[EquipPartID][cấp] = {NeedConcentrate, AddPrecent}`
   (5 mốc mỗi bộ phận: 30/40 → 60/80 → …).
3. **UI đọc đúng mốc ấy**: `CUIEquipment_Refine.lua:373` lấy
   `config[tEquip.EquipPartID][tEquip.RefineLevel + 1]` để hiện giá + `%` của CẤP KẾ; công
   thức thuộc tính (`share_EquipmentPropertyLogic.lua:147-160`) đã cộng `AddPrecent%`
   theo `RefineLevel` ⇒ chỉ cần TĂNG CẤP là thuộc tính tự đúng.

Luật: cấp kế → 1110 nếu cao nhất → trừ `NeedConcentrate` bằng `G_UserLogic:CostConcentrate`
(hàm gốc, tự chặn âm) → 1109 nếu thiếu → `SetEquipRefineLevel(cấp+1)` → `updateEquipData`
→ trả `OnRefineEquip()` (hàm nhận KHÔNG đối số). Ghi cấp hỏng thì **hoàn lại** tinh hoa.

### Đo trong game

```
tinh luyen trang bi: hero 2 / o 2 len cap 1 (tru 30 tinh hoa, +5%)
THU tinh luyen (hero 2 / o 2): ok=true, cap 0 -> 1, tinh hoa 2000 -> 1970
```

Bản lưu trên máy **trả nguyên trạng** (57.097 B), cờ tự kiểm đã xoá.

### Cổng

`_kiem_cu_phap.py` **63 tệp · 0 lỗi** · `_chay_het.py` **32 tệp · 527 phép · 0 đỏ** ·
`run_tests.py` **162 · 0** · `_con_lai.py` **182 handler**. Bộ thử mới `_thu_tinh_luyen.lua`
**18/18**.

### Bẫy của bộ thử (ghi để không lặp)
Hai lần liên tiếp: `local G_X = {}` trong tệp thử KHÔNG nhìn thấy được từ handler (handler
chạy ở **chunk khác**, `dofile` nạp tệp riêng) — mọi bảng giả mà handler đọc qua TÊN TOÀN
CỤC phải khai **không `local`**. Triệu chứng: mọi lượt rơi vào nhánh "không tìm thấy".

---

## 1/11 (tiếp 5) — LUYỆN VẬT PHẨM RA TINH HOA

### `handlers/luyen_vat_pham.lua` — `ClientRefineItem`

Panel `CUIRefineItem` mở được từ **Túi** và từ màn tinh luyện trang bị; trước lượt này bấm
"Luyện" là lớp tải quay mãi.

Luật suy từ ba nguồn độc lập: danh sách client gửi (`{ItemId, Count}`, chỉ vật liệu),
tỉ lệ là trường **`Concentrate` của `KDBGameItemConfig`** — chính UI cộng dồn
`Concentrate × số lượng` để hiện "sẽ được N tinh hoa" (`CUIRefineItem.lua:877`), và bộ mã
lỗi đã khai `NotEnoughItem 1201` / `ReduceItemError 1202` / `GetItemConfigFail 1203`.

Xử lý **nguyên tử**: kiểm hết → mới trừ; trừ hỏng giữa chừng thì **hoàn lại** các món đã trừ
và không cộng tinh hoa.

### Ba lỗi bắt được trong một lượt

| Lỗi | Triệu chứng | Sửa |
|---|---|---|
| `ItemLogic:GetItemCount` trả **`(bResult, nCount)`**, đọc thẳng nhận BOOLEAN | `vat pham 88 can 1, co 0` dù món có trong túi ⇒ luôn báo thiếu | đọc qua `local _, n = …` |
| Đồ thử quét `GameUserItem` gặp dòng **"ma"** (`ItemCount > 0` nhưng `IsExist = false`) | chọn nhầm món không tồn tại | lọc thêm `IsExist == true` |
| Túi sạch ⇒ không có vật liệu để đo | — | đồ thử CẤP 3 vật liệu id 88 (`Concentrate = 8`) rồi mới đo |

### Đo trong game

```
THU luyen vat pham: tui sach — da cap 3 vat lieu 88 de do
luyen vat pham: 1 mon -> +8 tinh hoa
THU luyen vat pham (id 88, 1 cai, Concentrate=8): ok=true, so luong 5 -> 4, tinh hoa 5790 -> 5798
```

Bản lưu trên máy **trả nguyên trạng** (57.097 B), cờ tự kiểm đã xoá.

### Cổng

`_kiem_cu_phap.py` **64 tệp · 0 lỗi** · `_chay_het.py` **33 tệp · 546 phép · 0 đỏ** ·
`run_tests.py` **162 · 0** · `_con_lai.py` **183 handler / 328 còn thiếu theo tên**.
Bộ thử mới `_thu_luyen_vat_pham.lua` **19/19**.

---

## 1/11 (tiếp 6) — CÁNH ĐANG HIỂN THỊ

### `handlers/canh_hien_thi.lua` — `ClientShowWing` / `ClientShowMagicWing`

Màn `CUIWingShow` (`:377`); trước lượt này bấm chọn cánh là lớp tải quay mãi.

Đây KHÔNG phải luật chơi — chỉ đổi một **cờ hiển thị** trên bản ghi tướng, bằng hai hàm ghi
đã có sẵn `HeroDataManager:SetHeroShowWingLevel` / `SetHeroShowMagicWingID`. Bộ vẽ đọc đúng
trường ấy (`share/HeroSkinLogic.lua:439`: `ShowWingLevel or WingLevel or 0`). Cổng kiểm suy
từ dữ liệu: cấp cánh phải ≤ `tướng.WingLevel`; cánh ảo phải nằm trong `tướng.MagicWingList`.

### Hai lỗi bắt được

| Lỗi | Triệu chứng | Sửa |
|---|---|---|
| `tonumber(v) == id or tonumber(v.MagicWingID) == id` khi `v` là SỐ | `attempt to index local 'v' (a number value)` — vế phải vẫn được tính | tách nhánh theo `type(v)` |
| Hàm ghi gốc **chỉ `PostDataEvent`**, KHÔNG gán vào bản ghi — bên ghi là máy chủ | `SetHeroShowWingLevel` chạy OK mà `ShowWingLevel` **0 → 0** | gán thẳng hai trường ĐÚNG như payload của chính hàm ấy (`ShowWingLevel`, `ShowMagicWingID`) rồi mới gọi hàm gốc để phát event |

### Đo trong game

```
canh hien thi: tuong 25 hien canh cap 1
THU canh hien thi (tuong 25): ok=true, ShowWingLevel 0 -> 1
```

File lưu: `GameUserHero["25"] = {ShowWingLevel = 1, ShowMagicWingID = 0}`. Bản lưu trên máy
**trả nguyên trạng** (57.097 B), cờ tự kiểm đã xoá.

### Cổng

`_kiem_cu_phap.py` **65 tệp · 0 lỗi** · `_chay_het.py` **34 tệp · 567 phép · 0 đỏ** ·
`run_tests.py` **162 · 0** · `_con_lai.py` **185 handler / 326 còn thiếu theo tên**.
Bộ thử mới `_thu_canh_hien_thi.lua` **22/22**.

---

## 1/11 (tiếp 7) — THIÊN MỆNH CỦA TƯỚNG (Sky Fate)

### `handlers/thien_menh.lua` — 2 khoá `G_HeroLogic`

`ClientUpdateHeroSkyFate(nHeroID, strSkyFateType)` và `ClientResetHeroSkyFate(nHeroID)`
(tab Thiên Mệnh trong màn tướng). **Cả hai đã có hàm nhận trong client**
(`OnUpdateHeroSkyFate(nErrCode)` / `OnResetHeroSkyFate(nErrCode)`) nên chỉ việc gọi đúng tên.

Dữ liệu là cấu hình THẬT + bản ghi THẬT:

| Thứ | Nguồn |
|---|---|
| Cấp hiện tại | `tướng.SkyFate[strLoại]` |
| Cấu hình | `KDBGameHeroSkyFateConfig` — **360 dòng**, 4 loại (`qinglong`/`baihu`/`xuanwu`/`zhuque`) × 8 cấp |
| Giá cấp kế | `nextCfg.CostFragmentPlus[tostring(heroID)]` nếu có, không thì `CostFragment` (đúng hàm `getSkyFateCostFragment` của UI) |
| Tiền | **mảnh của chính tướng ấy** (`HeroFragment`), không phải tài nguyên chung |
| Đặt lại | `SkyFateResetPrice[1]` = **888 kim cương** |

Mã lỗi khai sẵn cho đúng hệ này (`error.lua:132-137`): `HeroFragmentNotEnough = 1332`,
`FateConditionLimit = 1333`. Không có mã "đã cấp tối đa" ⇒ dùng `LimitGrowth = 1316`, ghi log
(client bỏ qua `nErrCode` nên số này chỉ vào nhật ký).

Đặt lại **xoá hết cấp nhưng KHÔNG hoàn mảnh** — không có dữ liệu nào nói có hoàn, nên không
tự thêm việc có lợi cho người chơi.

### Đo trong game

```
thien menh: tuong 12 — 'qinglong' len cap 1 (tru 3 manh)
THU thien menh (tuong 12, qinglong): ok=true, cap 0 -> 1, manh 52 -> 49
```

Bản lưu trên máy **trả nguyên trạng** (57.097 B), cờ tự kiểm đã xoá.

### Cổng

`_kiem_cu_phap.py` **66 tệp · 0 lỗi** · `_chay_het.py` **35 tệp · 590 phép · 0 đỏ** ·
`run_tests.py` **162 · 0** · `_con_lai.py` **187 handler / 324 còn thiếu theo tên**.
Bộ thử mới `_thu_thien_menh.lua` **22/22**.

---

## 1/11 (tiếp 8) — MẢNH VẠN NĂNG

### `handlers/manh_van_nang.lua` — `ClientConvertUniversalFragment`

Đổi mảnh vạn năng (vật phẩm **20**, `G_HeroLogic.UniversalFragmentID`) ra mảnh của một tướng;
gọi từ `CDigUseUniversalFragment` (`CUIUniversalFragment.lua:328`), mở từ **Túi**.

- `nCount` = số mảnh vạn năng **tiêu** (UI lấy trần = số đang có, `:140`); nhận đúng `nCount`
  mảnh tướng (1:1). Khẳng định chéo: khối mô tả phản hồi (`ClientHeroLogic.lua:1105-1114`)
  trả `{HeroID, Count}` và `CUIBackpack.lua:656-676` hiện thưởng `Count` mảnh tướng.
- `GameUniversalFragmentConfig` **không phải hệ số** — nó là **danh sách trắng** 90 tướng đổi
  được (chỗ dùng duy nhất trong client là phép kiểm "có mặt", `CUISubDialog.lua:1608-1618`).
- Trừ mảnh vạn năng TRƯỚC; cộng mảnh tướng hỏng thì **hoàn lại**.

### Ba lỗi/bẫy bắt được

| Vấn đề | Triệu chứng đo được | Cách xử lý |
|---|---|---|
| Khoá bảng cấu hình có thể là **SỐ** thay vì chuỗi | `cfg["25"] == nil` dù tướng 25 có trong bảng | thử cả `cfg[tostring(id)]` và `cfg[id]` |
| `GetCommonConfigWithName("GameUniversalFragmentConfig")` trả **nil** ở bản client này (dù `EquipRefineConfig`/`VipConfig` vẫn đọc được) | đồ thử không chọn được tướng nào | handler **bỏ bước gác** khi thiếu bảng (UI chọn tướng đã tự gác), ghi warn một dòng |
| Client KHÔNG có hàm nhận cho lệnh này (khối mô tả bị chú thích) | lớp tải không ai tắt | handler phát `OnReceiveResponse` trên đúng khoá hàm gửi đã bật (**`"ClientIntensifyWing"`** — hàm gửi dùng sai khoá) rồi phát `Hero.OnConvertUniversalFragment` |

### Đo trong game

```
manh van nang: 5 manh van nang -> 5 manh tuong 4
THU manh van nang (tuong 4): ok=true, van nang 5 -> 0, manh tuong 48 -> 53
```

Bản lưu trên máy **trả nguyên trạng** (57.097 B), cờ tự kiểm đã xoá.

### Cổng

`_kiem_cu_phap.py` **67 tệp · 0 lỗi** · `_chay_het.py` **36 tệp · 610 phép · 0 đỏ** ·
`run_tests.py` **162 · 0** · `_con_lai.py` **188 handler / 323 còn thiếu theo tên**.
Bộ thử mới `_thu_manh_van_nang.lua` **20/20**.

---

## 1/11 (tiếp 9) — TRANG PHỤC ĐỘC QUYỀN (bật/tắt hiển thị)

### `handlers/canh_hien_thi.lua` — thêm khoá thứ 3

`ClientSetExclusiveSkinState(nHeroID, isCancel)` (`CUIHeroInfoExclusiveUI.lua:211-224`);
`isCancel = true` = **huỷ** hiển thị.

Hàm ghi đã có sẵn và **tự gán trường** rồi mới phát event:
`HeroDataManager:SetIsCancelExclusive` (`share_HeroDataManager.lua:1071-1088`, dòng 1082 đặt
`tHeroData.IsCancelExclusive`). Bộ vẽ đọc đúng trường ấy (`HeroSkinLogic.lua:378`,
`share_HeroLogic.lua:2611`).

⚠ Client **CÓ** hàm nhận `OnSetExclusiveSkinState` nhưng nó **KHÔNG tắt lớp tải** — hàm gửi
đã bật `OnWaitingForRequest` trên khoá `"ClientSetExclusiveSkinState"` mà không ai tắt. Nên
handler tự phát `OnReceiveResponse` trên đúng khoá ấy rồi mới gọi hàm nhận.

### Đo trong game

```
canh hien thi: tuong 12 HUY hien trang phuc doc quyen
THU trang phuc doc quyen (tuong 12): ok=true, IsCancelExclusive nil -> true
```

Bản lưu trên máy **trả nguyên trạng** (57.097 B), cờ tự kiểm đã xoá.

### Cổng

`_kiem_cu_phap.py` **67 tệp · 0 lỗi** · `_chay_het.py` **36 tệp · 617 phép · 0 đỏ** ·
`run_tests.py` **162 · 0** · `_con_lai.py` **189 handler / 322 còn thiếu theo tên**.
Bộ thử `_thu_canh_hien_thi.lua` nay **29/29**.

### Đã ĐO là CHƯA NÊN làm (đừng thử lại mò)

- `ClientUpgradeWing`: cấu hình `UpgradeWingConfig` chỉ có `StoneCost/MaxBlessing/CostDiamond`,
  còn UI đọc `GoldCost` (không tồn tại) ⇒ màn hình đang hiện 0 vàng; kèm hệ **phúc khí ngẫu
  nhiên** (`EffectivePercent`, `MaxBlessing`) mà nửa máy chủ không ship.
- `ClientUpHeroFightSoul`: luật rõ (`KDBGameFightSoulConfig` 115 dòng: `CostGold`,
  `SuccessRate/FailRate`, `MaterialList`/`MaterialListPlus`, `NeedLevel`), nhưng hệ số
  `GetUpgradeMultiple()` nhân cả **giá lẫn tỉ lệ** qua `GetUpgradeSoulCost` ⇒ phải đọc thêm
  cách UI tính tỉ lệ trước khi viết; làm ẩu là ra sai giá.

---

## 1/11 (tiếp 10) — NÂNG VÕ HỒN (武魂)

### `handlers/vo_hon.lua` — `ClientUpHeroFightSoul(nHeroID, nMultiple)`

Nút nâng trong `CUIHeroInfoFightSoulUI:doUpgrade`; trước lượt này bấm là lớp tải quay mãi.

Luật + số **đều đọc được**, không phải đoán:

| Thành phần | Nguồn |
|---|---|
| Cấu hình | `KDBGameFightSoulConfig` — 115 dòng: `CostGold`, `SuccessRate`, `NeedLevel`, `MaterialList`, `MaterialListPlus`, `FightProperty` |
| Hết cấp | dòng có `CostGold == 0` — chính UI dùng phép thử ấy (`:1373`) |
| Vật liệu | `MaterialListPlus[tostring(heroID)]` nếu có, không thì `MaterialList` — đúng hàm `getHeroSoulMaterialList` của UI |
| Số vật liệu | `G_HeroLogic:GetUpgradeSoulCost(base, nMultiple)` (hàm GỐC: VIP ≥ 8 giảm 25%, rồi nhân bội). **VÀNG KHÔNG nhân bội** |
| Tỉ lệ thành công | UI hiện `20 + 10×Lv` với `Lv_basic = SuccessRate/10 − 2` ⇒ mốc cơ bản = `SuccessRate`, mỗi bội +10% ⇒ **`SuccessRate + (nMultiple−1)×10`, chặn 100** |

Xử lý: kiểm hết (vàng + vật liệu + cấp tướng) → trừ vàng → trừ vật liệu (hỏng thì **hoàn vàng**)
→ roll → tăng cấp nếu thắng.

Trả lời `OnUpHeroFightSoul(nResult)` — tham số là **SỐ**: **1 thắng · 2 thua · 3 không đổi**
(`CUIHeroInfoFightSoulUI:OnCallBack` chọn hoạt ảnh theo đúng ba số này).

### Ba lỗi bắt được

| Lỗi | Triệu chứng | Sửa |
|---|---|---|
| `pcall(cjson.decode, v)` ném **TRƯỚC** khi vào pcall khi `cjson` là nil | `attempt to index global 'cjson'` — chết cả handler | kiểm `type(_G.cjson)` rồi `pcall(function() return cjson.decode(v) end)` |
| Bộ thử thiếu `CUINotificationEvent` | mọi mã lỗi "biến mất" (pcall nuốt), chỉ thấy ctx đúng | khai biến giả trong bộ thử |
| Test tự cho rằng `FightSoulLevel` đã là 1 | kiểm oan nhánh `NeedLevel` | đặt cấp đúng trong bộ thử |

### Đo trong game

```
vo hon: tuong 56 cap 0 -> 1 (tile 100%, boi 1, tru 5000 vang + 1 vat lieu 103)
THU vo hon (tuong 56): ok=true, ket qua=1, cap 0 -> 1
```

Bản lưu trên máy **trả nguyên trạng** (57.097 B), cờ tự kiểm đã xoá.

### Cổng

`_kiem_cu_phap.py` **68 tệp · 0 lỗi** · `_chay_het.py` **37 tệp · 644 phép · 0 đỏ** ·
`run_tests.py` **162 · 0** · `_con_lai.py` **190 handler / 321 còn thiếu theo tên**.
Bộ thử mới `_thu_vo_hon.lua` **27/27**.

---

## 1/11 (tiếp 11) — PHỤ ĐỀ THEO ẢI (弹幕)

### `handlers/phu_de.lua` — 2 khoá `G_SubtitleLogic`

`ClientSetUserCopySubtitle(copyKey, subtitle, time, color)` và `ClientGetCopySubtitle(copyKey)`
(`ClientSubtitleLogic.lua:14/20`), gọi từ `CUISubtitleInputDialog` khi người chơi gửi một dòng
phụ đề trong ải.

- **Gửi**: client KHÔNG chờ phản hồi (không bật `OnWaitingForRequest`) — nó đã tự hiện dòng của
  mình qua `Subtitle.OnSendSubtitle`. Nên handler chỉ LƯU.
- **Đọc**: `OnGetGetCopySubtitle(nErrCode, copyKey, mySubtitles, friendSubtitles, RandomSubtitles)`
  — **năm tham số VỊ TRÍ**. Mỗi dòng là bảng `{Subtitle, Time, Color}`; chính hàm ấy đặt
  `isMySelf`, sắp theo `Time`, rồi tự chèn phụ đề cấu hình ải + toàn cục. Offline một người ⇒
  hai danh sách bạn bè/ngẫu nhiên để **rỗng**.
- **Lưu ở đâu**: `G_UserLogic:Get/SetClientCommonData("OfflineCopySubtitles")` (vào file lưu).
- **[MOI]** mỗi ải giữ tối đa **100 dòng**, quá thì bỏ dòng CŨ NHẤT — chặn file lưu phình vô hạn;
  con số là quyết định của lớp offline.

### Đo trong game

```
phu de: ai 'L_N_01_03' nhan 1 dong (tong 1)
phu de: ai 'L_N_01_03' tra 1 dong cua minh
THU phu de: gui=true doc=true, OnGetGetCopySubtitle, so dong cua minh = 1
```

Bản lưu trên máy **trả nguyên trạng** (57.097 B), cờ tự kiểm đã xoá.

### Cổng

`_kiem_cu_phap.py` **69 tệp · 0 lỗi** · `_chay_het.py` **38 tệp · 661 phép · 0 đỏ** ·
`run_tests.py` **162 · 0** · `_con_lai.py` **192 handler / 319 còn thiếu theo tên**.
Bộ thử mới `_thu_phu_de.lua` **17/17**.

---

## 1/11 (tiếp 12) — TÊN NHÂN VẬT NGẪU NHIÊN

### `handlers/ten_ngau_nhien.lua` — `ClientGetRandomName(bGender)`

Nút "Đổi tên khác" ở màn tạo nhân vật; trước lượt này bấm **không có gì xảy ra**.

Luật là **mã gốc còn sống**: `CharacterNameLogic:GetName(bGender)` (`true` = nam,
`false` = nữ) — họ + tên, dùng bảng tên trong cấu hình THẬT `LocalCharacterNameConfig`.

Trả lời: client **không có hàm nhận**; `CUILogin:OnGetRandomName(szName)` đăng ký thẳng sự
kiện `OnGetRandomName` ⇒ handler phát đúng sự kiện ấy với CHUỖI tên (hàm gửi không bật lớp
tải nên không có gì để tắt). Bộ sinh hỏng thì **chỉ ghi log, không phát** — thà không đổi tên
còn hơn đẩy xuống một cái tên ta tự chế.

### Đo trong game

```
ten ngau nhien: sinh ten 'ĐoanMộcDiệpNhiên' (nam)
ten ngau nhien: sinh ten 'NạpLanVũToàn' (nu)
THU ten ngau nhien: nam='ĐoanMộcDiệpNhiên', nu='NạpLanVũToàn'
```

Bản lưu trên máy **trả nguyên trạng** (57.097 B), cờ tự kiểm đã xoá.

### Đã ĐO là CHƯA làm được (đừng thử lại mò)

`G_MagicWeaponTreasureBox` (2 khoá mở hộp thần binh): `MagicWeaponCommonConfig` trong bản này
**chỉ có `unlockLevel` + `maxStarLevel`** — KHÔNG có `TreasureList` / `ConsistentTreasure` /
`StoreGoodsConfig` mà `share/MagicWeaponTreasureBox.lua` đọc ⇒ không có bể thưởng để rút.

### Cổng

`_kiem_cu_phap.py` **70 tệp · 0 lỗi** · `_chay_het.py` **39 tệp · 671 phép · 0 đỏ** ·
`run_tests.py` **162 · 0** · `_con_lai.py` **193 handler / 318 còn thiếu theo tên**.
Bộ thử mới `_thu_ten_ngau_nhien.lua` **10/10**.

---

## 1/11 (tiếp 13) — MÔ HÌNH NHIỀU NGƯỜI TỐI THIỂU: BANG HỘI (9 khoá)

**Chủ dự án chọn hướng "mô hình nhiều người tối thiểu".** Khối lớn nhất còn lại là 122 khoá
nhiều người; lượt này mở màn bằng **bang hội** (nhóm đông nhất: 30 khoá).

### `handlers/bang_hoi.lua` — 8 khoá + `bang_xep_hang.lua` thêm 1

MÔ HÌNH [MOI]: người chơi **tự lập một bang**, là **bang chủ và thành viên DUY NHẤT**. Đây là
quyết định sản phẩm, không phải dữ liệu gốc.

| Khoá | Hình phản hồi |
|---|---|
| `ClientCreateGuild(pictrueId, name, notice)` | `OnCreateGuild(tData)` |
| `ClientGetGuildInfo(pageNo, pageSize, guildId)` | `OnGetGuildInfo(err, tGuildInfo)`; chưa có bang ⇒ **3501 `GuildNotExist`** (mã gốc) |
| `ClientModifyNotice(guildId, notice, wx, qq)` | `OnModifyNotice(err)` + gọi `OnGuildNoticeInfoChange` cho UI |
| `ClientGetGuildLogList(guildId)` | `OnGetGuildLogList(err, {})` — RỖNG, không nil |
| `ClientGetGuildApplyList(guildId)` | `OnGetGuildApplyList(err, {})` — RỖNG |
| `ClientExitGuild(guildId)` / `ClientCancelGuild(guildId)` | `OnExitGuild()` / `OnCancelGuild(err)` |
| `ClientDonateGuild(guildId, type, amount)` | **từ chối có lý do** — không có bảng quy đổi, không đoán giá |
| `ClientGetGuildRank(guildId)` | `OnGetGuildRank(ds, 1, 1)` — một dòng là bang của mình |

Hình `tGuildInfo` lấy từ chỗ UI đọc: `Name`, `GuildId`, `StrNotice`, `PictrueId`, `memberList`,
`HeadUid`, `Manager`. Dòng thành viên: `Uid/Nick/Level/VipLevel/FightPower/LastLoginTime/
Gender/Portrait`. Cờ "đang ở trong bang" ghi vào **`GameUserGuildData.GuildId`** — chỗ duy nhất
`ClientGuildLogic:GetGuildData()`/`CheckIsCanJoinGuild` đọc.

### Bắt được TRONG GAME bằng cách bấm tay

Bấm tab **"Quân Đoàn"** của `CUILeaderboard` ⇒ log ghi
**`THIEU G_RankLogic.ClientGetGuildRank`** và màn hình quay mãi. Đây là kiểu hỏng bộ thử KHÔNG
thấy (harness dùng ctx giả). Nay trả `{ một dòng bang của mình }`, hạng 1.

### Đo trong game (hai lượt)

```
bang hoi: lap bang 'Bang Thu Offline' (id 541864), bang chu uid 100001
THU bang hoi: tao=true doc=true, ten='Bang Thu Offline', thanh vien=1, ma=0
bang hoi: da o trong mot bang — tu choi lap them      <- bang GIU qua lan dang nhap
bang xep hang: BXH quan doan — bang 'Bang Thu Offline', hang 1
THU BXH quan doan: ok=true, 1 dong, ten='Bang Thu Offline', hang=1
```

Bản lưu trên máy **trả nguyên trạng** (57.097 B), cờ tự kiểm đã xoá.

### Cổng

`_kiem_cu_phap.py` **71 tệp · 0 lỗi** · `_chay_het.py` **40 tệp · 703 phép · 0 đỏ** ·
`run_tests.py` **162 · 0** (bộ PC từng ĐỎ 1 phép khi đổi mã "chưa có bang" — đã sửa về đúng
3501) · `_con_lai.py` **201 handler / 310 còn thiếu theo tên** (336 theo cặp). Bộ thử mới `_thu_bang_hoi.lua`
**32/32**.

### Còn lại của nhóm nhiều người (đã khai, CHƯA làm)

Xin vào bang khác · duyệt/đá thành viên · phân quyền & đổi chức · đóng thuế công nghệ · xúc
xắc · điều tướng · công thành · COG · bạn bè thật. Mỗi nhóm cần một quyết định mô hình riêng;
`CON-LAI.md` đã ghi kèm lý do từng khoá.

---

## 1/11 (tiếp 14) — BẠN BÈ (mô hình "không có ai"), 14 khoá

### `handlers/ban_be.lua`

`G_FriendLogic` — 14 khoá mà màn **`CUIFriend2`** gọi (`:106` gọi `GetUserRelations()` ngay khi
mở). Trước lượt này KHÔNG có handler ⇒ mở panel Bạn Bè là lớp tải quay mãi.

MÔ HÌNH [MOI]: máy chủ giả chỉ có MỘT người chơi.

| Nhóm | Hành vi |
|---|---|
| ĐỌC (`GetUserRelations` · `GetUserFriends` · `GetRecommendedFriend` · `SearchUserWithName`) | trả **bảng RỖNG đúng hình** — `CUIFriend2:GetUserRelationsCallBack` đọc `tData[tostring(RelationState.X)]`, thiếu khoá thì nó tự coi là `{}` |
| THAO TÁC (`ApplyForFriend` · `AcceptApply` · `RefuseAllApply` · `RemoveFriend` · `SendGift` · `ReceiveGift` · `SendGiftAll` · `ReceiveGiftAll` · `GetUserDetailByUid` · `FightFriend`) | trả **mã lỗi GỐC** `ErrorCode.Friend.*`: `NoApply 3804` · `NotFriend 3805` · `NoGift 3807` |

KHÔNG giả vờ thành công: nói "đã tặng quà/kết bạn" khi không có ai là nói dối người chơi.

### Đo trong game (đường THẬT)

```
ban be: da noi 14 khoa (doc rong + thao tac tu choi trung thuc)
THU ban be (duong that): tFriends = table, 0 nhom quan he
```

Harness gọi `G_FriendLogic:GetUserRelations()` (chính hàm `CUIFriend2:onShow` dùng) rồi kiểm
`tFriends` sau một nhịp — **đúng đường thật**, không phải ctx giả.

Bản lưu trên máy **trả nguyên trạng** (57.097 B), cờ tự kiểm đã xoá.

### Cổng

`_kiem_cu_phap.py` **72 tệp · 0 lỗi** · `_chay_het.py` **41 tệp · 731 phép · 0 đỏ** ·
`run_tests.py` **162 · 0**. Bộ thử mới `_thu_ban_be.lua` **28/28**.

---

## 1/11 (tiếp 15) — CÔNG THÀNH (mô hình "chưa mở"), 15 khoá

### `handlers/cong_thanh.lua`

15 khoá `G_GuildWarLogic` mà màn Công Thành gọi. Trước lượt này mở màn là lớp tải quay mãi.

**"Chưa mở" là câu trả lời ĐÚNG**: công thành là **hai bang đánh nhau**; máy chủ giả chỉ có một
người trong một bang ⇒ không có trận. Mã lỗi GỐC cho đúng tình huống này đã có sẵn:
**`GuildWarNoFightData = 3538`** ("không đủ bang hội để mở hoạt động") — không bịa trận giả.

Hình gọi đặc biệt: MỌI hàm nhận của họ này có chữ ký **`(eventList, nErrCode, …)`** — tham số
ĐẦU phải là một BẢNG (client kiểm `ProcessNotTable(eventList)` rồi thoát). Mỗi hàm một đuôi
tham số riêng, có hàm cần `nil` ở CUỐI ⇒ bảng `DS` ghi rõ **số đuôi** và gọi
`unpack(goi, 1, 2 + nDuoi)` để giữ nil.

### Ba lỗi/bẫy

| Vấn đề | Triệu chứng | Sửa |
|---|---|---|
| `ErrorCode.GuildWar…` không tồn tại (mã nằm trong `ErrorCode.Guild`) | index nil | đọc qua `(x or {})` |
| Đọc `ErrorCode` ở PHẠM VI TỆP | **đỏ cả bộ thử PC**: `attempt to index global 'ErrorCode'` (mock nạp lớp offline khi `ErrorCode` chưa có) | đọc trong hàm `ma()` lúc chạy |
| Đuôi tham số có `nil` ở cuối | `unpack` dừng sớm ⇒ thiếu tham số | ghi số đuôi TƯỜNG MINH, `unpack(goi, 1, 2+n)` |

### Đo trong game (đường THẬT)

```
cong thanh: QueryScore -> ma 3538 (chi mot bang, khong co tran)
cong thanh: CheckCanChangeTeam -> ma 3538
THU cong thanh (duong that): QueryScore=true, CheckCanChangeTeam=true
```

Gọi qua `G_GuildWarLogic:CallQueryScore()`/`CallCheckCanChangeTeam()` — đúng đường
`CallServer → router → ctx:call → hàng đợi → CallLocal`, nên kiểm được cả tầng mạng.

Bản lưu trên máy **trả nguyên trạng** (57.097 B), cờ tự kiểm đã xoá.

### Cổng

`_kiem_cu_phap.py` **73 tệp · 0 lỗi** · `_chay_het.py` **42 tệp · 806 phép · 0 đỏ** ·
`run_tests.py` **162 · 0** · `_con_lai.py` **229 handler / 282 thiếu theo tên**.
Bộ thử mới `_thu_cong_thanh.lua` **75/75**.

⚠ **BẪY CÔNG CỤ:** đăng ký bằng `R:on("G_GuildWarLogic." .. khoa, …)` (ghép chuỗi lúc nạp)
thì `_phu_rpc.dang_ky()` **KHÔNG thấy** khoá nào (nó chỉ đọc chuỗi HẰNG ngay sau `R:on(`) ⇒
CON-LAI đếm thiếu 15 khoá. Nay sinh 15 dòng đăng ký chuỗi hằng qua helper `noi()`.

---

# 📌 GHI CHÚ NGÀY MAI (viết cuối 1/11)

## Số chốt — chạy lại được (bốn cổng)

```
python _kiem_cu_phap.py   -> 73 tep, loi 0
python _chay_het.py       -> 42 tep · 806 phep · 0 do
python run_tests.py       -> dat 162, hong 0
python -I _con_lai.py     -> 229 handler / 282 con thieu (theo ten) · 306 (theo cap)
python build.py && PATH="/c/LDPlayer/LDPlayer9:$PATH" python deploy.py --push
```

**Đầu ngày 1/11: 170 handler / 341 thiếu. Cuối ngày: 229 / 282 — +59 handler.**

## Đã làm trong ngày (15 lượt)

| Lượt | Nội dung |
|---|---|
| 1 | Phân loại 42 khoá toàn cục ⇒ **10 SỐNG / 25 CHẾT / 7 trong chú thích** (`_phan_loai_toancuc.py`) |
| 2 | Vá 2 lỗi công cụ (`R:ignore(` cắt sai; quét bản giải mã thiếu 21 tệp) + phân loại toàn bộ 363 khoá |
| 3 | Quà 7 ngày · Điểm kim thủ · nhịp "việc mỗi ngày" (`qua_ngay.lua`, [MOI]) |
| 4 | Mục tiêu ải (rương màn chọn ải, gác phát thưởng hai lần) |
| 5 | Mua vật phẩm (vá 3 chỗ mã gốc bị chú thích) |
| 6 | Tinh luyện trang bị |
| 7 | Luyện vật phẩm ra tinh hoa |
| 8 | Cánh hiển thị + trang phục độc quyền |
| 9 | BXH chung 4 tab (5 tướng + 3 bảng PvE) |
| 10 | Thiên mệnh tướng |
| 11 | Mảnh vạn năng · Tên ngẫu nhiên |
| 12–15 | **Mô hình nhiều người tối thiểu**: bang hội (9) · bạn bè (14) · công thành (15) |

## Máy đang ở đâu

- LDPlayer bật, `adb root` + `frida-server` chạy; game **đã tắt**.
- Bản lưu **trả nguyên trạng 57.097 B**; cờ `selftest.flag` **đã xoá**.
- Harness `thu_nhom_moi.lua` có **28 mục** (tiêu tài nguyên thật — nhớ sao lưu + phục hồi):
  `adb shell "su -c 'cp .../offline_save.json /sdcard/save_truoc_<viec>.json'"` trước,
  phục hồi sau.

## Việc kế — theo thứ tự đề nghị

1. **COG (`G_COGProtocol`, 18 khoá)** — cùng họ công thành, dùng lại khuôn "chưa mở"
   (`handlers/cong_thanh.lua`): nhanh, rủi ro thấp, có mã gốc sẵn.
2. **Quản lý thành viên bang hội** (duyệt/đá/phân quyền/đổi chức + thuế công nghệ + xúc xắc
   + điều tướng) — cần chốt mô hình (một người thì "duyệt đơn" luôn rỗng, nhưng thuế công nghệ
   và xúc xắc CÓ THỂ làm thật từ `GuildImpeachConfig`/`DiceGameConfig`).
3. **Kênh bang hội (`G_GuildChapterLogic`, 18)** · **đấu trường điểm (12)**.
4. Quay lại **chế độ ải đặc biệt** (30 khoá `G_ChapterLogic` + `G_RankLogic` điểm tự thân) —
   có `GetTGZZChapterPrize`/`GetDKChapterPrize` thật, nhưng **chưa mở trong bản lưu** nên khó
   nghiệm thu.
5. Về **`bravecross-server`** (Mốc 61 xong; 226 tay · 285 sinh · 36).

## Bẫy mới của ngày (đầy đủ ở mục 1/11 trong `trace-runtime-avd`)

- **Công cụ:** `R:on("G_X." .. ten, …)` ghép chuỗi ⇒ `_phu_rpc` KHÔNG đếm; đọc `ErrorCode`
  ở **phạm vi tệp** ⇒ đỏ cả bộ thử PC; `pcall(cjson.decode, v)` ném **trước** pcall khi
  `cjson` nil.
- **Bộ thử:** `local G_X = {}` không thấy được từ handler (khác chunk); thiếu
  `CUINotificationEvent` thì mọi mã lỗi bị pcall nuốt.
- **Dữ liệu:** `ItemLogic:GetItemCount` trả `(ok, n)`; khoá cấu hình có thể là **SỐ**;
  hàm ghi gốc có khi **chỉ `PostDataEvent`, không gán** (phải tự gán `ShowWingLevel`);
  có bảng cấu hình **vắng hẳn** (`GameUniversalFragmentConfig`, `MagicWeaponCommonConfig`).

# 📌 2/11 — COG (CÔNG THÀNH XUYÊN MÁY CHỦ): 25 KHOÁ + MỘT BẪY LỚN VỀ OBJ NHẬN

## Số chốt (chạy lại được)

```
python _kiem_cu_phap.py   -> 74 tep, loi 0
python _chay_het.py       -> 43 tep · 881 phep · 0 do
python run_tests.py       -> dat 162, hong 0
python -I _con_lai.py     -> 252 handler / 259 con thieu (theo ten) · 281 (theo cap)
python build.py && deploy.py --push  (cay sc/offline = deploy/plain/sc/offline, diff RONG)
```

Đầu ngày 229 handler / 282 thiếu ⇒ cuối lượt 252 / 259 (+23 theo tên; +25 khoá RPC).

## MÔ HÌNH: "MỘT MÙA CHƯA MỞ" (khác `cong_thanh` trả mã lỗi cho MỌI khoá)

COG là hoạt động theo MÙA, cần nhiều bang hội trên nhiều máy chủ. Offline một người
⇒ không có mùa nào. Client CÓ trạng thái thật cho việc này: `COGDef.STEP_NONE = 0`
("未开放") và `CUICOGEntry:OnGetBriefInfo` có hẳn nhánh hi chữ xám "chưa mở". Vì vậy:

| nhóm | hành vi |
|---|---|
| 3 lệnh ĐỌC (`GetBriefInfo`, `GetCOGInfo`, `GetCityInfo`) | **mã 0 + dữ liệu thật của mùa chưa mở**: `Step = 0`, `CityList = {}` ⇒ client tự dựng **28 thành** từ `KDBGameGuildAttackCityConfig`, tất cả VÔ CHỦ |
| đội / chiến báo / bản ghi hình | trả RỖNG (`GetMyTeamList`, `GetGuildTeamList`, `GetGuildTeamProfile`, `GetGuildBattleReport`, `GetCityReport`) hoặc mã gốc 4522/4523 (ba lệnh PHÁT LẠI) |
| thao tác | mã gốc `ErrorCode.COGCode`: 4501 đăng ký/chọn thành · 4506 giải tán đội · 4507 điều đội · 4512 lập/sửa đội · 4513 chưa có bang · 4518 sửa/phá thành (0 lượt) |
| `SetGuildMsg` | **làm thật**: lưu client common data `OfflineCOGGuildMsg`, trả lại trong `GetCOGInfo` |
| `ClientBuyGoods` | **làm thật**: bảng `GameCOGGoodsConfig` (7 dòng `{PrizeID, Cost}`) + điểm `GameUserBaseInfo.COGScore`; thiếu điểm ⇒ `ErrorCode.RedPack.ScoreLimit 5651`; phát thưởng hỏng ⇒ HOÀN điểm |

Ba lệnh thành trì (`RepairCity`/`AttackCity`) trả 4518 vì `remainingCompleteTimes = 0`.
`GetCityDefendMission` trả `{}` (không có nhiệm vụ); `ManualRefreshMission`/`GetPrize`
nhận **MỘT tham số dữ liệu** (không có kênh mã lỗi); `GetDailyOccupyPrize` nhận **0 tham số**.

## ⚠ BẪY LỚN NHẤT: OBJ GỬI KHÁC OBJ NHẬN

* Client GỬI `"G_COGProtocol"` nhưng biến toàn cục là **`g_COGProtocol`** (chữ thường,
  `COGProtocol.lua:14`). `CallLocal` tra `_G[objName]` (`system/rpc.lua:91`) ⇒ mọi phản hồi
  PHẢI đi qua `g_COGProtocol`; gửi nhầm là không ai chạy, **không lỗi nào**, lớp tải quay mãi.
  (Cùng họ Tinh Hồn: gửi `G_StarSoulProtocol`, nhận `g_StarSoulProtocol`.)
* **`G_COGCityDefendMission` KHÔNG có thực thể nào** ở client — 6 lệnh thành trì gửi bằng
  obj ấy nhưng hàm nhận nằm trên `g_COGProtocol`.

## BẪY DỮ LIỆU MỚI

* `G_PrizeLogic:GetPrizeWithID` trả `(bResult, prize)` ⇒ `pcall` cho **BA** giá trị
  `(ok, bResult, prize)`. Đọc hai giá trị là nhận **BOOLEAN** làm prize ⇒ mua hàng luôn
  "phát thưởng hỏng". Cùng họ `GetItemCount` trả `(ok, n)`.
* `CheckIsHasJoinGuild` trả `(bResult, bHasJoin)` — **cờ nằm ở giá trị THỨ HAI**; đọc giá
  trị đầu là nhận `true` của "gọi được" ⇒ luôn tưởng có bang.
* `g_COGDataManager:OnGetPlayerBattleReport` **KHÔNG TỒN TẠI** (chỉ có lời gọi ở
  `COGProtocol.lua:212`) ⇒ `ClientGetPlayerBattleReport` phải trả LỖI 4523, trả mã 0 là nổ.

## ĐO TRONG GAME (đường THẬT, harness `thu_nhom_moi.lua` mục 29)

`THU cog (duong that): goi info=true brief=true thanh=true; Step=0, so thanh=28, GuildID thanh 1=0`
— log `san sang — 273 handler`. Bản lưu **trả nguyên trạng 57.097 B**, cờ `selftest.flag` đã xoá.

## ĐÃ ĐO LÀ CHƯA LÀM

Giao diện COG mở được nhưng **chưa bấm tay** (việc chủ dự án): vào Bang Hội → nút Công Thành.
Shop COG muốn thử mua thì cộng điểm bằng GM `cog <n>` (mới thêm ở `nap_gia_lap.lua`).

## Việc kế

1. **Quản lý thành viên bang hội** (duyệt/đá/phân quyền/thuế công nghệ/xúc xắc/điều tướng).
2. **Kênh bang hội** (`G_GuildChapterLogic`, 18) · **đấu trường điểm** (12).
3. Chế độ ải đặc biệt (30 khoá `G_ChapterLogic`).
4. Về `bravecross-server`.

# 📌 2/11 (tiếp) — BANG HỘI NÂNG CAO: 23 KHOÁ (thuế công nghệ · xúc xắc · điều tướng)

## Số chốt

```
python _kiem_cu_phap.py   -> 75 tep, loi 0
python _chay_het.py       -> 44 tep · 943 phep · 0 do
python run_tests.py       -> dat 162, hong 0
python -I _con_lai.py     -> 274 handler / 237 con thieu (theo ten) · 259 (theo cap)
python build.py && deploy.py --push (cay sc/offline = deploy/plain/sc/offline, diff RONG)
```

Đầu lượt: 252/259/281 ⇒ cuối lượt **274/237/259** (+22 theo tên, +23 khoá RPC).
Tệp mới: `handlers/bang_hoi_nang_cao.lua` (nạp SAU `bang_hoi`), bộ thử
`_thu_bang_hoi_nang_cao.lua` **62/62**.

## 23 khoá — chia ba nhóm

| nhóm | khoá | hành vi |
|---|---|---|
| **Quản lý thành viên** (6) | AcceptApply · RejectApply · SetHead · SetManager · CancelManager · KickGuild | một người ⇒ mã gốc **3523** (đơn không tồn tại) / **3507** (không có quyền hoặc không có thành viên ấy). `SetHead` với chính bang chủ trả **0** (idempotent) |
| **Thiết lập / khác** (4) | ModifyGuildSetting · IsHaveGuildRedPoint · UploadWeChatGroup · ImpeachHeadman | 3 khoá **THẬT** (ghi `Type/PictrueId/AcceptLevel`; chấm đỏ = còn lượt xúc xắc; lưu link WeChat). Luận tội ⇒ **3555** `GuildHeadManIsAlive` |
| **Tìm / vào bang** (4) | SearchGuild · JoinGuild · ApplyGuild · CancelApply | `SearchGuild` trả CHÍNH bang của mình (hoặc 3501); join/apply ⇒ **3502** nếu đã ở bang, **3501** nếu chưa có bang nào khác; huỷ đơn = no-op đúng nghĩa |
| **Thuế công nghệ** (1) | DonateGuildTechnology | **THẬT** — xem dưới |
| **Xúc xắc "我要神将"** (3) | GetDiceGameData · PlayDiceGame · GetDiceGameReward | **THẬT** — xem dưới |
| **Điều tướng** (5) | DispatchHero · QuerySelfDispatchList · GetDispatchHeroList · PickGuildHero · EmployDispatchHero | 4 khoá **THẬT** (lưu/lấy/thu hồi); thuê tướng người khác ⇒ **3514** |

`ClientGetRandGuildList` **không đăng ký lại** — đã có từ 28/10 trong `handlers/he_thong.lua:194`
(cùng câu trả lời: mã 0 + danh sách rỗng). Đăng ký hai chỗ chỉ sinh cảnh báo
`dang ky de handler`; đã thấy đúng cảnh báo ấy trong logcat lượt đầu.

## Ba phần THẬT — nguồn số

**Thuế công nghệ.** `KDBGameTchecknologyDonateConfig` (5 bậc): 15.000 **vàng** +20,
hoặc 50/100/250/800 **kim cương** +50/120/200/800, chặn VIP 0/0/3/6/8. Cộng
`TechnologyCount` vào BA chỗ: exp tuyến công nghệ (`GameGuildTechnology[ten].Exp`),
đóng góp cá nhân (`GameUserGuildData.GuildContribution`), tài nguyên bang
(`GameUserGuildData.Resouce`) — đúng hai tài nguyên trong `PrizeID 11..15`.
[GHIM] lên cấp "trừ dần" theo `Exp` của cấp kế (Lv1 200, Lv2 400…) vì đó là cách duy
nhất làm thanh kinh nghiệm UI không vượt 100% (`CUIGuildScienceDlg.lua:250-255`).
Thiếu tiền ⇒ **500/504**; thiếu VIP ⇒ **3401**; max cấp/chỉ số sai ⇒ **2**.

**Xúc xắc.** `DiceGameConfig` (THẬT): `PlayTimes = 5`, `StartPlan` 3 kế hoạch chọn theo
`Rate`, `GodTimesData` = số mặt 6 của TỪNG lượt; `PrizeData` = cặp (số mặt 6 → PrizeID);
`GameUserLottery` là bảng UI ĐỌC (`CUIShakeDice.lua:728-745`). [MOI] `DiceGameDay` +
`DiceGamePlan` — máy chủ gốc đặt lại mỗi ngày (mốc 5 giờ); thiếu thì lượt cộng dồn vĩnh viễn.
Config này KHÔNG có `FreeChangeTimes`/`PayChangeTimes` ⇒ UI ẩn nút "改投"; offline cũng không
làm. Kỷ lục theo quy ước CỦA CLIENT: `nCount × 10^nMaxNum` (100 = một lần 2 mặt 6).

**Điều tướng.** `GameUserGuildData.MapDispatchHero` — ĐÚNG bảng client đọc
(`ClientGuildDispatchLogic.lua:309-340`). Tối đa 3 tướng; không điều chủ công (3534);
không trùng (3513); thu hồi phải giữ ≥ 30 phút (3517). [GHIM] thu nhập theo ĐÚNG công
thức client hiển thị: `15 vàng/phút giữ + HeroPower × 1.5 / 10 × số lần được thuê`.
`ClientExitGuild` (tệp `bang_hoi.lua`) nay chặn khi còn tướng đang điều — **3532**.

## Bốn bẫy mới

1. **NHIỀU HÀM NHẬN KHÔNG CÓ THAM SỐ MÃ LỖI** (`OnPlayDiceGame(tData)`,
   `OnGetDiceGameReward(tData)`, `ClientJoinGuild()`, `OnApplyGuild()`,
   `OnPickGuildHero(tData)`, `OnExitGuild()`, `OnImpeachHeadman(tData)`). Báo lỗi bằng
   `g_CUIGameRPCManager:OnReciveResponse("", "", mã, {})` — đúng đường
   `CUIRPCManager.lua:166` (dừng lớp tải + toast).
2. **`pcall` BA giá trị**: `GetUserGuildTechnology`, `GetHeroWithID`, `GetPrizeWithID`
   đều trả `(bResult, đối tượng)` ⇒ `pcall` cho `(ok, bResult, obj)`. Đọc hai giá trị là
   nhận BOOLEAN (bẫy họ `GetItemCount`).
3. **`[[` NẰM TRONG `--[[ ]]`**: chú thích ghi mảng `[[0,120011],[1,120012]]` làm Lua 5.1
   báo `nesting of [[...]] is deprecated` ⇒ **không nạp được handler**. ⚠ **`_kiem_cu_phap.py`
   KHÔNG bắt được** (lua51.dll là LuaJIT, chấp nhận cú pháp ấy) trong khi **`run_tests.py`
   (lupa Lua 5.1) bắt được**. Vì vậy phải chạy CẢ HAI cổng — đây là lần đầu hai bộ kiểm
   cú pháp lệch nhau.
4. **Đăng ký trùng**: `ClientGetRandGuildList` đã có trong `he_thong.lua`; logcat báo
   `dang ky de handler`. Kiểm logcat dòng này sau mỗi lượt thêm handler.

## ĐO TRONG GAME (18:27, harness `thu_nhom_moi.lua` mục 30)

```
san sang — 296 handler
bang hoi (nang cao): da noi 23 khoa
bang hoi (nang cao): dong gop cong nghe '1' bac 1 (vang 15000) -> +20 exp, cap 0, exp 20
bang hoi (nang cao): xuc xac sang ngay moi (khoa 20261102)
bang hoi (nang cao): xuc xac luot 1/5 — 1 mat 6
bang hoi (nang cao): dieu tuong 4 sang bang (luc chien 2295)
THU bang hoi nang cao: thue=true (vang 152460 -> 137460, exp=20), xuc xac=true (6 mat), dieu tuong=true (hero 4, 1 muc)
```

Bản lưu **trả nguyên trạng 57.097 B**, cờ `selftest.flag` đã xoá, game đã tắt.
**CHƯA BẤM TAY** các panel (Học viện bang hội / Xúc xắc / Điều tướng) — việc chủ dự án.

## Việc kế

1. **Kênh bang hội** (`G_GuildChapterLogic`, 18) · **đấu trường điểm** (12).
2. Chế độ ải đặc biệt (30 khoá `G_ChapterLogic`).
3. Bấm tay nghiệm thu các panel vừa nối.
4. Về `bravecross-server`.

# 📌 2/11 (tiếp 2) — PHÓ BẢN BANG HỘI: 18 KHOÁ (`G_GuildChapterLogic`)

## Số chốt

```
python _kiem_cu_phap.py   -> 76 tep, loi 0
python _chay_het.py       -> 45 tep · 998 phep · 0 do
python run_tests.py       -> dat 162, hong 0
python -I _con_lai.py     -> 292 handler / 219 con thieu (theo ten) · 241 (theo cap)
python build.py && deploy.py --push (cay sc/offline = deploy/plain/sc/offline, diff RONG)
```

Đầu lượt 274/237/259 ⇒ cuối lượt **292/219/241** (+18). Trong game **314 handler**.

## Vì sao làm được THẬT

Phó bản bang hội tưởng là hệ nhiều người, nhưng dữ liệu trận do **chính client** sinh
(`CUIGame:OnGuildCopyCallServer` gửi `ChapterData.TotalHart`), nên bang một người vẫn
chơi trọn vòng: mở → chuẩn bị → vào trận → kết thúc → nhận thưởng. Dữ liệu gốc dùng:

| chỗ | nguồn THẬT |
|---|---|
| 4 phó bản | `KDBGameChapterConfig`, `ChapterType = 9993` (`L_G_01_01`…`L_G_04_01`) |
| giá mở/đặt lại | `GuildLogic:OpenGuildChapterResourceWithConfig` (2500/3500/4000, giảm theo công nghệ) |
| máu boss | `ChapterLogic:CalcGuildChapterBossHp` — đo trong game: **35.638.309 HP** |
| hạn mỗi phó bản | `GuildChapterExternTimeOut` 3/5/7 ngày; `PlayPerDay = 3` |
| đặt lại | `SharedGuildChapterLogic`: **3 lần/tuần**, chu kỳ 7 ngày từ 2017-03-06 05:00 |
| thưởng sát thương/hạng | `GuildInjureConfig.InjureReward` / `InjureRankReward` |
| bể rơi chung | `GuildChapterCommonDropData` → `KDBGameNpcConfig.DropData` |

[GHIM] ba chỗ máy chủ gốc đã chết, không có nguồn thứ hai: (1) thưởng sát thương +
hạng phát MỘT LẦN khi qua phó bản (cờ `Settled`); (2) bể rơi = roll từng dòng
`DropData` theo `DropValue / TotalDropValue`; (3) `SysDispatchLeftTime` = thời gian
còn lại tới hạn phó bản.

## Mã lỗi gốc dùng trong tệp

3541 không đủ quyền · 3542 chưa qua ải thường · 3543 thiếu tài nguyên bang · 3544 chưa
mở · 3545 đã khoá/đã qua · 3546 hết lượt đánh · 3548 đã xin rồi · 3549 không đủ số
lượng để chia · 3551 sai lúc · 3552 đang có người đánh · 3561 quá 3 lần đặt lại/tuần.

## Bốn bẫy mới

1. **`OnChapterRequestDetailed` có BỐN tham số**: `(eventList, nErrCode, danhSách, thờiGianCònLại)`
   — danh sách đứng RIÊNG, không bọc `{MemberList=…}`; truyền thiếu thì client
   `table.sort(nil)` và nổ.
2. **`OnGuildChapterFightBegin` mất khối phát sự kiện**: client chú thích
   `PostLogicEvent(tData, Guild.Copy.OnGuildChapterFightBegin)`
   (`ClientGuildChapterLogic.lua:178-182`) ⇒ handler phải TỰ phát thì màn xếp đội mới
   vào được trận.
3. **Ba giá trị `pcall`** lại vấp: `CheckChapterIsPass` trả `(bResult, bPass)`,
   `GetPrizeWithID` trả `(bResult, prize)`.
4. **Cấu hình là CHUỖI JSON**: `GuildInjureConfig`, `GuildChapterCommonDropData`, cả
   `NpcConfig.DropData` đều là chuỗi — phải `cjson.decode` có gác `_G.cjson`.
   Kèm: `ClientGetGuildInfo` phải trả thêm `Resouce` / `ChapterDispatchTimes` (client
   đọc ở `tGuildInfo`, nguồn thật là `GameUserGuildData`) — đã thêm vào `bang_hoi.lua`.

## ĐO TRONG GAME (18:38, harness mục 31)

```
san sang — 314 handler
pho ban bang: mo 'L_G_01_01' (gia 2500, boss 35638309 HP)
pho ban bang: chuan bi danh 'L_G_01_01'
pho ban bang: vao tran 'L_G_01_01' (boss con 35638309 HP)
pho ban bang: 'L_G_01_01' QUA — da chot thuong (sat thuong 35638309)
pho ban bang: 'L_G_01_01' ket thuc — sat thuong 35638309, boss con 0 (DA QUA)
THU pho ban bang: mo=true chuanbi=true vaotran=true ketthuc=true danhsach=true (1 mo)
                  — boss 35638309 -> 0, daQua=true, 6 mon trong be rơi
```

Ải mở của `L_G_01_01` đòi đã qua `L_N_03_20` (bản lưu thử chưa qua) nên harness TẠM vá
`CheckChapterIsPass`, trả lại ngay sau lượt. Bản lưu **57.097 B trả nguyên trạng**, cờ
đã xoá, game tắt. **CHƯA BẤM TAY** panel Phó bản bang — việc chủ dự án.

## Việc kế

1. **Đấu trường điểm** (`G_ScoreCompetitivePlayProtocol`, 12).
2. Chế độ ải đặc biệt (30 khoá `G_ChapterLogic`).
3. Bấm tay nghiệm thu Phó bản bang (mở khóa bằng cách qua `L_N_03_20`).
4. Về `bravecross-server`.

# 📌 2/11 (tiếp 3) — ĐẤU TRƯỜNG ĐIỂM (APR): 13 KHOÁ, 1000 ROBOT THẬT

## Số chốt

```
python _kiem_cu_phap.py   -> 77 tep, loi 0
python _chay_het.py       -> 46 tep · 1036 phep · 0 do
python run_tests.py       -> dat 162, hong 0
python -I _con_lai.py     -> 304 handler / 207 con thieu (theo ten) · 229 (theo cap)
python build.py && deploy.py --push (cay sc/offline = deploy/plain/sc/offline, diff RONG)
```

Đầu lượt 292/219/241 ⇒ cuối lượt **304/207/229** (+12). Trong game **327 handler**.

## Mở được nhờ ROBOT CÓ THẬT

Máy chủ gốc sinh **1000 robot** từ cấu hình, và LUẬT SINH ROBOT còn nguyên trong
`share/ScoreCompetitivePlay/share_ScoreCompetitivePlayLogic.lua` (`GetRobotInfo`,
`Score2Rank`, `NumId2StrId`, `GenDefence`, …). Bộ thử `_thu_apr.lua` **nạp chính tệp
share ấy** rồi gọi nguyên hàm — không chép luật.

| dữ liệu | nguồn THẬT |
|---|---|
| 1000 đối thủ | `KDBScoreCompetitiveRobot` + `KDBScoreCompetitiveRobotConf` |
| mùa | `KDBScoreCompetitiveRuleConf`: ngày 1 05:00 → ngày 25 22:00, `StartScore 1000` |
| BXH / thăng bậc | `KDBScoreCompetitiveRankConf` 19 bậc (`MinScore`, `rank_reward`, `recover_diamond`…) |
| đội phòng thủ | tướng THẬT của người chơi, lực chiến qua `GetHeroAllFightCapacityWithHero` |
| thưởng thăng bậc | `SetDataWithPrizeData({PrizeContent = cfg.rank_reward})` |

## ⚠ HAI CHỖ PHẢI VÁ MỚI DÙNG ĐƯỢC MÃ GỐC

1. **Cấu hình robot KHÔNG được đăng ký trong client**: `G_ConfigManager:GetScoreCompetitiveRobot`
   và cache `ScoreCompetitiveRobotConf` chỉ có ở máy chủ ⇒ `GetRobotInfo` sẽ nổ.
   Handler tự đăng ký bằng `GetConfigTableWithName("KDBScoreCompetitiveRobot")` — hàm này
   đọc THẲNG `config/share/<tên>.xgg`, không cần đăng ký trước. ĐO trong game:
   `da dang ky cau hinh robot (1000 robot, RobotConf=true)`.
2. **`APRData` đọc bảng `GameScoreCompetitivePlay`** (`score`, `max_score`, `challenge`,
   `defence`, `rank_reward`, `season_id`…). Đây là bảng MÁY CHỦ ghi; offline tự duy trì,
   kèm reset theo mùa và 6 đối thủ gần lực chiến nhất.

## ⚠ BỐN KHOÁ TRẬN: KHÔNG LÀM ĐƯỢC, TRẢ 5500

`BeginFight` / `EndFight` / `RevengeBegin` / `RevengeEnd` cần máy chủ **mô phỏng 3 trận**
rồi gửi `WinIndex`/`Rand`/`Result` cho client phát lại. Bản client **không có bộ mô phỏng**
(grep `share/` 0 hàm), nên không thể sinh kết quả trận mà không BỊA. Bốn khoá trả mã gốc
**5500 `ScoreCompetitive.Closed`** qua hàm nhận (nó có nhánh `ProcessNotTable` ⇒ dừng lớp
tải, KHÔNG vào trận) + toast lý do.

## Bẫy mới

* Obj GỬI `G_ScoreCompetitivePlayProtocol` nhưng obj NHẬN là **`g_APRProtocol`** (chữ thường).
* `Khoá Rsp` của APR **không có tham số mã lỗi** ⇒ báo lỗi bằng
  `g_CUIGameRPCManager:OnReciveResponse("", "", mã, {})`.
* `share` dùng `string.split` (hàm tiện ích của client) — bộ thử phải tự định nghĩa.
* [MOI] phục hồi điểm: config không ghi giới hạn ⇒ chặn **một lần/ngày**, nếu không là
  mua điểm vô hạn.

## ĐO TRONG GAME (19:03, harness mục 32)

```
san sang — 327 handler
dau truong diem: da dang ky cau hinh robot (1000 robot, RobotConf=true)
dau truong diem: trang thai mo -> 3 (cap=true tuong=true)
dau truong diem: mo bang — hang 1001, diem 1000, 6 doi thu, 20 dong BXH
dau truong diem: xem doi thu '408_0' -> true
dau truong diem: luu doi phong thu — 3 doi
THU dau truong diem: state=3, 6 doi thu, hang=1001, 20 dong BXH,
                     xem doi thu: 3 doi phong thu, tran=5500
```

Bản lưu **57.097 B trả nguyên trạng**, cờ đã xoá, game tắt. **CHƯA BẤM TAY** panel
(Đấu trường điểm nằm trong màn Chiến Tranh Thế Giới); trận đánh vẫn chưa chạy được.

## Việc kế

1. Chế độ ải đặc biệt (30 khoá `G_ChapterLogic`).
2. Bấm tay nghiệm thu các panel đã nối (COG, bang hội, phó bản, APR).
3. Về `bravecross-server`.

# 📌 2/11 (tiếp 4) — BXH CHẾ ĐỘ ẢI ĐẶC BIỆT: 14 KHOÁ `G_RankLogic`

## Số chốt

```
python _kiem_cu_phap.py   -> 78 tep, loi 0
python _chay_het.py       -> 47 tep · 1073 phep · 0 do
python run_tests.py       -> dat 162, hong 0
python -I _con_lai.py     -> 318 handler / 193 con thieu (theo ten) · 215 (theo cap)
python build.py && deploy.py --push (cay sc/offline = deploy/plain/sc/offline, diff RONG)
```

Đầu lượt 304/207/229 ⇒ cuối lượt **318/193/215** (+14). Trong game **341 handler**.
Tệp mới `handlers/bang_xep_hang_che_do.lua`, bộ thử `_thu_bxh_che_do.lua` **37/37**.

## 14 khoá — hai nhóm

| nhóm | khoá | hình phản hồi |
|---|---|---|
| ĐIỂM CỦA MÌNH (5) | SelfHJRQ / SYZLB / SCSZL / DJSJF / XZWC | 1 số; **HJRQ là HAI số** `(costTime, wave)` |
| BẢNG XẾP HẠNG (9) | Hjrq / SYZLB / SCSZL / DJSJF / XZWC / TGZZ / DK / ArenaDefendPower / GuildWarScore | bản đồ khoá `uid_server`; **HJRQ giữ `chapterKey` ở tham số 2**; hai khoá cuối có **BA tham số** (bảng, hạng mình, hạng hôm qua) |

Mô hình offline một người ⇒ **một dòng của mình, hạng 1** (cùng quyết định với BXH
chung 1/11 và BXH đấu trường 30/10). Dòng dựng bằng `G_RankLogic:GetUserHotData()`
(tên/cấp/gender/lực chiến) + `Portrait` từ hồ sơ.

Điểm lấy từ THỐNG KÊ THẬT của client (`GetStatisticsCommonData`):
`MaxHJRQBatchCount` · `TGZZChapterLevel` / `TGZZChapterBestDamage` /
`TGZZChapterBestCostTime` · `DKChapterLevel` / `DKChapterBestDamage` /
`DKChapterBestCostTime`. Các chế độ CHƯA có thống kê trong client (SCS `killCount`,
SYZLB/XZWC `costTime`, DJSJF `damage`) trả **0** — trung thực, không bịa.

## Bẫy mới

* `GetUserDataWithName` trả `(mã, bảng)` — nếu KHÔNG bọc pcall mà viết
  `local ok, ma, t = …` thì lệch hết một giá trị (bộ thử bắt được: `Score` luôn 0).
* `#bảng` = 0 với bảng khoá CHUỖI — đếm dòng phải dùng `pairs`, không dùng `#`.
* Mỗi khoá một hình: HJRQ hai số; HJRQ-rank có `chapterKey` ở tham số 2; hai khoá
  "BXH khác" có ba tham số và UI kiểm `ProcessNotNumber` cả hai số.

## ĐO TRONG GAME (19:13, harness mục 33)

```
san sang — 341 handler
BXH che do: da noi 14 khoa (7 che do ai + phong thu dau truong + ho phu)
THU BXH che do: 6/6 khoa dung hinh
```

Bản lưu **57.097 B trả nguyên trạng**, cờ đã xoá, game tắt. **CHƯA BẤM TAY** các tab
BXH (nằm trong màn chế độ ải / BXH chung).

## CÒN LẠI CỦA NHÓM "ẢI ĐẶC BIỆT" — 16 khoá `G_ChapterLogic`

Chưa làm: 6 `…Complete` (HJRQ/SCS/TGZZ/DK/XZWC/DJSJF) · 6 `…Sweep` (+SYZLB) ·
`ClientGetChapterDropData` · `ClientGetSCSChapterNPCData` · `ClientGetDKChapterFaction` ·
`ClientReviveInBattle` · `ClientUserOverHJRQ`. Các chế độ này **chưa mở trong bản lưu**
nên nghiệm thu sẽ phải vá điều kiện như phó bản bang (mục 31).

## Việc kế

1. 16 khoá `G_ChapterLogic` còn lại của chế độ ải đặc biệt.
2. Bấm tay nghiệm thu COG / bang hội / phó bản / APR / BXH chế độ.
3. Về `bravecross-server`.

# 📌 2/11 (tiếp 5) — CHẾ ĐỘ ẢI ĐẶC BIỆT: 16 KHOÁ `G_ChapterLogic`

## Số chốt

```
python _kiem_cu_phap.py   -> 79 tep, loi 0
python _chay_het.py       -> 48 tep · 1101 phep · 0 do
python run_tests.py       -> dat 162, hong 0
python -I _con_lai.py     -> 334 handler / 177 con thieu (theo ten) · 196 (theo cap)
python build.py && deploy.py --push (cay sc/offline = deploy/plain/sc/offline, diff RONG)
```

Đầu lượt 318/193/215 ⇒ cuối lượt **334/177/196** (+16). Trong game **357 handler**.
Tệp mới `handlers/ai_dac_biet.lua`, bộ thử `_thu_ai_dac_biet.lua` **28/28**.

## Làm được nhờ LUẬT MÁY CHỦ GỐC còn trong `share/`

| việc | hàm GỐC dùng nguyên |
|---|---|
| 7 khoá KẾT THÚC | `ChapterLogic:activityChapterComplete(key, dropList, killIdList, damage)` — lọc rơi theo quái giết, nhân rơi, `getOtherPrize` (Định Quân Sơn: vàng theo sát thương; Thập Thường Thị: vật phẩm theo số giết), `chapterVictoryHandle` lưu báo cáo |
| 4 khoá CÀN QUÉT | `ChapterLogic:chapterSweepHandle(cfg, ex, dropList, rating, sweep, from)` |
| thưởng TGZZ/DK | `GetTGZZChapterPrize` / `GetDKChapterPrize` (cấp mùa × % sát thương) |
| hồi sinh | `GetChapterReviveCost(n) = 50 × (n+1)` kim cương |
| sóng HJRQ | đúng luật `share/Statistics.lua:294-339` (`MaxHJRQBatchCount`) |

Rơi dùng CHÍNH bộ sinh của lớp offline (`OfflineDrop_build`) — cùng xác suất ải thường.

## [GHIM] — chỗ luật không ship, chọn trung thực

1. Sweep TGZZ/DK tính thưởng với `DamagePercent = 1`; **phải đã qua ải** mới quét — mã gốc **1435 `NotCrossCantSweep`**.
2. Sweep HJRQ/SYZLB/XZWC gọi `chapterSweepHandle` với rơi sinh lại + sao đã lưu; cùng cổng 1435.
3. `ClientGetSCSChapterNPCData` trả `NpcList = {}` — bảng NPC theo TỪNG CẤP không có trong cấu hình ship; hình rỗng là hình client chịu được.
4. Phe ĐK: offline không có luân phiên ⇒ trả phe **mặc định 1** (đúng giá trị client tự dùng, `CUIDKData.lua:31-34`).
5. PetBoss/DK: client KHÔNG gửi khoá ải ở một số lời gọi ⇒ lấy ải duy nhất của loại đó.

## Bốn bẫy

1. **`ClientChapterDKComplete` GỬI MỘT tham số** (không có chapterKey) — khoá phải lấy trong `ChapterData.ChapterKey`, thiếu thì chọn ải duy nhất của loại 14.
2. Hàm nhận của SCS/HJRQ/DJSJF/XZWC/PetBoss/TGZZ **không có mã lỗi** ⇒ báo lỗi bằng `g_CUIGameRPCManager:OnReciveResponse("", "", mã, {})`.
3. `GetTGZZChapterLevel`/`GetDKChapterLevel` trả **BA** giá trị `(bResult, cấp, cấpTốiĐa)`.
4. `GetStatisticsCommonData` / `GetDiamond` trả **HAI** giá trị — harness đọc ba nên in `nil`; đã sửa cách đọc trong harness.

## ĐO TRONG GAME (19:25, harness mục 34)

```
san sang — 357 handler
ai dac biet: da noi 16 khoa (7 ket thuc, 4 can quet, 5 tien ich)
xem truoc roi 'FB_E_HJRQ' -> 0 mon
HJRQ vuot 5 song (ky luc cu 0)
tu choi -> ma 1435 (chua qua ai FB_E_HJRQ)
hoi sinh lan 1 (-50 kim cuong)
THU ai dac biet: roi=0 mon, phe=1/number, song=5, can quet=1435, hoi sinh=24731 -> 24681
```

Bản lưu **57.097 B trả nguyên trạng**, cờ đã xoá, game tắt. **CHƯA vào trận** các chế độ
này (bản lưu không mở chúng) — đường kết thúc/càn quét mới đo qua bộ thử tĩnh.

## Việc kế

1. Nhóm `G_EndlessChapterLogic` (8) · `G_EpicChapterLogic` (5) · các `G_Activity*`.
2. Bấm tay nghiệm thu các nhóm đã nối.
3. Về `bravecross-server`.

# 📌 2/11 (tiếp 6) — ẢI VÔ TẬN: 9 KHOÁ `G_EndlessChapterLogic`

## Số chốt

```
python _kiem_cu_phap.py   -> 80 tep, loi 0
python _chay_het.py       -> 49 tep · 1139 phep · 0 do
python run_tests.py       -> dat 162, hong 0
python -I _con_lai.py     -> 342 handler / 169 con thieu (theo ten) · 188 (theo cap)
python build.py && deploy.py --push (cay sc/offline = deploy/plain/sc/offline, diff RONG)
```

Đầu lượt 334/177/196 ⇒ cuối lượt **342/169/188** (+8 theo tên; +9 khoá RPC). Trong game
**357 handler**. Tệp mới `handlers/vong_vo_tan.lua`, bộ thử `_thu_vong_vo_tan.lua` **38/38**.

## Thay `chua_lam` cũ bằng luật THẬT

`handlers/endless.lua` (28/10) đăng ký 9 khoá này bằng `chua_lam(...)` — chỉ dọn lớp tải
và ghi “nửa máy chủ không ship”. Lượt này gỡ 9 dòng ấy và dựng lại bằng **hằng số + hàm
ĐỌC có thật** của `share/EndlessChapterLogic.lua`:

| khoá | luật dùng |
|---|---|
| `ClientFight` | `IsCanFight` (2 lượt miễn phí + tối đa 7); tăng `ChallengesCount`; trả `OnFight(heroList, inspire, employ)` |
| `ClientCompeleteFight` | `IsCompeleteData(tData, PassCondition, PassConditionArgs)`; thưởng = `GameEndlessChapterConfig[tầng].PrizeID` (107001…, 250 tầng); sự kiện `IsWin` + `PrizeID` |
| `ClientGotoNextProsees` | chỉ khi đã thắng: tầng+1, đặt lại lượt/chúc phúc; phát `OnGotoNextProsess` |
| `ClientInspire` | `InspireCost` (2000 vàng / 50 kim cương), `InspireEffect` 20/20, tối đa 3 |
| `ClientResetEndlessChapter` | về tầng 1, **1 lần/ngày** (`MaxResetCount`), `BestProsees` giữ nguyên |
| `ClientBuyChallengesCount` | 50 kim cương/lượt, tối đa 5 lượt trả tiền |
| `ClientSwap` / `ClientStopSwap` | 60 giây/tầng (`SwapCostTime`); mỗi tầng quét được trao `PrizeID` của tầng |
| `ClientSwapImmediately` | 2 kim cương/tầng còn lại (`SwapCostDiamondPerFloor`); quét xong nhảy tới `Best+1` |

## Bẫy mới

* `OnFight` có **BA** tham số `(heroIdList, nInspireCount, tEmployHero)`; `OnStopSwap` nhận
  **MẢNG các `PrizeContent`**.
* `ClientGotoNextProsees` là ngoại lệ của bản gốc (khối phát `OnWaitingForRequest` bị chú
  thích) — nhưng bộ thử PC VẪN đòi **đúng MỘT** `OnReciveResponse`; mọi nhánh (kể cả
  “chưa thắng” và “không đọc được dữ liệu”) phải dọn lớp tải, nếu không bộ PC đỏ 2 phép.
* `GetPrizeWithID` trả `(bResult, prize)` ⇒ `pcall` **BA** giá trị (bẫy quen).

## ĐO TRONG GAME (19:37, harness mục 35)

```
san sang — 357 handler
vong vo tan: da noi 9 khoa (vao tran/ket thuc/sang tang/chuc phuc/dat lai/mua luot/quet)
vong vo tan: vao tran tang 1 — luot 1/7
vong vo tan: qua tang 1 (thuong 107001)
vong vo tan: sang tang 2
vong vo tan: bat dau quet tu tang 2 (toi 4)
vong vo tan: dung quet — 2 tang, 2 mon thuong
vong vo tan: dat lai ve tang 1 (Best giu nguyen 4)
THU ai vo tan: vao=true(1 tuong) ketthuc=true sangtang=true(2) quet=true/true (2 tang, 4 mon) datlai=true
```

(dòng cuối: 2 = số món thưởng quét, 4 = tầng hiện tại sau khi quét.) Bản lưu
**57.097 B trả nguyên trạng**, cờ đã xoá, game tắt. **CHƯA bấm tay** vào trận thật của
ải vô tận.

## Việc kế

1. **`G_EpicChapterLogic` (5 khoá)** — Epic 4 phe × độ khó; chưa có share logic.
2. Bấm tay nghiệm thu các nhóm đã nối.
3. Về `bravecross-server`.

# 📌 2/11 (tiếp 7) — CHIẾN DỊCH ANH HÙNG: 5 KHOÁ `G_EpicChapterLogic`

## Số chốt

```
python _kiem_cu_phap.py   -> 81 tep, loi 0
python _chay_het.py       -> 50 tep · 1162 phep · 0 do
python run_tests.py       -> dat 162, hong 0
python -I _con_lai.py     -> 347 handler / 164 con thieu (theo ten) · 183 (theo cap)
python build.py && deploy.py --push (cay sc/offline = deploy/plain/sc/offline, diff RONG)
```

Đầu lượt 342/169/188 ⇒ cuối lượt **347/164/183** (+5). Trong game **362 handler**.
Tệp mới `handlers/epic.lua`, bộ thử `_thu_epic.lua` **23/23**.

## Luật dùng (không có tệp share cho Epic, nhưng đủ mã ĐỌC)

| khoá | luật / dữ liệu |
|---|---|
| `ClientSetTodayChapterDifficult` | `EpicOpenTimeConfig` + `ConfigManager:IsEpicOpen(camp, ngày)`; độ khó ≤ `PassedChapterInfo[camp].Difficulty` |
| `ClientEpicResetDaily` | xoá `TodayChapterInfo` / `TodayMaxPassedLevel` / mốc quét |
| `ClientEpicChapterCompeleteFight` | thưởng `PrizeID` của ải + `HeroFactionsPrestigeReward`; cấp danh vọng bằng hàm GỐC `GetHeroFactionsPrestigeLevel`; qua màn 9 mở độ khó kế |
| `ClientSweepEpicChapter` | quét các tầng ĐÃ QUA HÔM NAY, mỗi tầng MỘT LẦN (mốc `SweptMaxLevel` [MOI]) |
| `ClientBuyEpicGoods` | `GameEpicChapterGoodsConfig[key] = {PrizeID, cost}`; tiền **EpicCoin**; thiếu ⇒ **1901** |

## ⚠ BẪY LỚN — CHỮ KÝ THẬT KHÁC KHAI BÁO

`CallCompeleteFight` khai `(strChapterID, tHeroIdList, tEmployHero)` nhưng
`FBEpic:OnEnd(bComplete)` (`user/FB/FBEpic.lua:60-70`) gọi
`CallCompeleteFight(bComplete, ChapterID, HeroIdList, EmployHero)` — **BỐN** giá trị,
`bComplete` đứng ĐẦU. Đọc theo chữ ký khai báo là mất kết quả trận. Handler nhận
`(bComplete, chapterID, heroList, employHero)`.

## [GHIM] ba chỗ luật máy chủ chết

1. `PassedChapterInfo[camp].Difficulty` khởi tạo **1**; qua màn 9 của độ khó hiện tại
   thì mở độ khó kế (+1).
2. Quét chỉ quét tầng đã qua hôm nay và chỉ MỘT lần/tầng (`SweptMaxLevel`) — chống
   phát danh vọng lặp.
3. Danh vọng cộng dồn tuyệt đối; cấp suy bằng hàm GỐC, không tự đặt ngưỡng.

## ĐO TRONG GAME (19:49, harness mục 36)

```
san sang — 362 handler
epic: da noi 5 khoa (chon phe/do kho, dat lai ngay, ket thuc tran, quet, shop)
epic: chon phe 1, do kho 1
epic: danh vong phe 1 +6 -> Exp 6, cap 1
epic: thang 'SSZY_10' (phe 1, do kho 1, tang 1)
epic: danh vong phe 1 +6 -> Exp 12, cap 2
epic: quet phe 1 do kho 1 — 1 tang, +6 danh vong
epic: mua mon 1 (-15000 EpicCoin, con 5000)
THU epic: phe=1, chon=0, thang=true (tang 1, danh vong 6), quet=1 tang, coin=5000, datlai=OnEpicResetDaily
```

Bản lưu **57.097 B trả nguyên trạng**, cờ đã xoá, game tắt. **CHƯA bấm tay** vào trận Epic.

## Việc kế

1. Nhóm toàn cục còn lại (38 khoá) — dùng `_phan_loai_toancuc.py` phân loại trước.
2. Các `G_Activity*` (mỗi nhóm 1–4 khoá) — phần lớn là dữ liệu vận hành.
3. Bấm tay nghiệm thu toàn bộ; về `bravecross-server`.

# 📌 2/11 (tiếp 8) — NĂM KHOÁ TOÀN CỤC CÒN SỐNG

## Số chốt

```
python _kiem_cu_phap.py   -> 82 tep, loi 0
python _chay_het.py       -> 51 tep · 1173 phep · 0 do
python run_tests.py       -> dat 162, hong 0
python -I _con_lai.py     -> 352 handler / 159 con thieu (theo ten) · 176 (theo cap)
python build.py && deploy.py --push (cay sc/offline = deploy/plain/sc/offline, diff RONG)
```

Đầu lượt 347/164/183 ⇒ cuối lượt **352/159/176** (+5). Trong game **369 handler**.
Tệp mới `handlers/toan_cuc_con.lua`, bộ thử `_thu_toan_cuc_con.lua` **11/11**.

## Phân loại lại 38 khoá objName RỖNG

`_phan_loai_toancuc.py`: **6 SỐNG · 25 CHẾT · 7 TRONG CHÚ THÍCH**. Ba khoá "sống" còn lại
(`ClientChapterHJRQComplete` · `ClientChapterSCSComplete` · `ClientGetChapterDropData`) đã
có handler theo obj ở `ai_dac_biet.lua`; lời gọi obj RỖNG của chúng nằm trong đường mạng
CŨ `CServerRequestLogic` (**0 chỗ gọi**). Năm khoá dưới là lời gọi THẬT còn lại:

| khoá | hành vi |
|---|---|
| `ClientGetSpeechContent` | không có bảng nội dung thoại trong cấu hình ship ⇒ trả **3902 SpeechNotExists** qua `G_ChattingLogic:OnGetSpeechContent(err, nil)` |
| `ClientCheckNewEquipment` | client KHÔNG chờ, KHÔNG có hàm nhận ⇒ nuốt lặng có log (chỉ server đánh dấu "đã xem") |
| `ClientSetArenaHero` | **THẬT**: lưu danh sách vào common data `OfflineArenaHero` [MOI] rồi gọi `G_ArenaLogic:OnSetArenaHero(list)` + dọn lớp tải; đăng ký cả bản `G_ArenaLogic.` và bản obj RỖNG |
| `ClientBindingAccount` | offline KHÔNG có hệ tài khoản (SDK chết), Lua KHÔNG có hàm nhận ⇒ nuốt lặng có ghi lý do, KHÔNG báo thành công |
| `ClientReturnHome` | trả hàm TOÀN CỤC `OnReturnHome({err=0, data={}})` — đường cũ tự `ResetChannelData` + `RepaleceScene("Main")` |

## Bẫy

* `OnSetArenaHero` **không** dọn lớp tải (chỉ phát sự kiện) ⇒ handler phải
  `g_CUIGameRPCManager:OnReciveResponse` tay.
* `ClientSetArenaHero` có HAI chỗ gọi: `G_ArenaLogic` (sống) và obj RỖNG trong
  `CServerRequestLogic` (chết) — đăng ký cả hai, bản RỖNG gọi lại chính handler kia.
* `ClientBindingAccount` không có hàm nhận nào trong Lua — đừng bịa "liên kết thành công".

## ĐO TRONG GAME (19:57, harness mục 37)

```
san sang — 369 handler
toan cuc (con song): da noi 5 khoa (thoai/trang bi/doi hinh dau truong/lien ket/ve nha)
toan cuc (con song): thoai 1 -> ma 3902 (khong co du lieu thoai)
toan cuc (con song): da xem trang bi 1 (khong co phan hoi)
toan cuc (con song): doi hinh dau truong -> 1 tuong
toan cuc (con song): ClientBindingAccount — offline khong co he tai khoan, bo qua
toan cuc (con song): ve nha tu man chon ai
THU toan cuc con song: thoai=3902, trangbi=true, doihinh=1, lienket=true, venha=true/OnReturnHome
```

Bản lưu **57.097 B trả nguyên trạng**, cờ đã xoá, game tắt.

## Việc kế

1. Các `G_Activity*` (mỗi nhóm 1–4 khoá) — phần lớn là dữ liệu vận hành.
2. `G_TournamentLogic` / `G_WCSProtocol` (0 thân hàm trong 973 tệp).
3. Bấm tay nghiệm thu toàn bộ; về `bravecross-server`.

# 📌 2/11 (tiếp 9) — LỚP CHẮN CUỐI: **0 KHOÁ SỐNG CÒN THIẾU**

## Số chốt

```
python _kiem_cu_phap.py   -> 83 tep, loi 0
python _chay_het.py       -> 52 tep · 1185 phep · 0 do
python run_tests.py       -> dat 162, hong 0
python -I _con_lai.py     -> 440 handler / 71 con thieu (theo ten) · 73 (theo cap)
python -I _phan_loai_toancuc.py --tat-ca -> TONG SO KHOA CON SONG: 0 / 73
python build.py && deploy.py --push (cay sc/offline = deploy/plain/sc/offline, diff RONG)
```

Đầu lượt 352/159/176 ⇒ cuối lượt **440/71/73**. Trong game **466 handler**.
Tệp mới `handlers/chua_ho_tro.lua` (100 khoá), bộ thử `_thu_chua_ho_tro.lua` **12/12**.

## Đã làm: lớp chắn cho 100 khoá SỐNG còn lại (34 module)

Mỗi khoá đăng ký bằng CHUỖI HẰNG, handler:
1. ghi log một dòng nói RÕ vì sao nhóm chưa làm;
2. gọi `g_CUIGameRPCManager:OnReciveResponse("", "", mã, {})` — dừng lớp tải + toast;
3. KHÔNG gọi hàm nhận nào khác, KHÔNG trả dữ liệu bịa.

Mã GỐC theo nhóm: `ActivityNotOpen 4001` (mọi `G_Activity*`, `G_ServerActivityFightCap`,
`G_Anniversary`, `G_FreeStrengthLogic`) · `TournamentCode.Closed 4401` ·
`WCSCode.Closed 5201` · `MagicWeapon.SystemIsClosed 5002` ·
`Arenal.GetUserArenaDataFaild 2306` · còn lại **1**. Hai khoá mã **0** (nuốt lặng, hệ đã
chết/không có hàm nhận): `G_Login.ClientBindingChannelAccount`,
`G_PotionLogic.ClientCompleteUpgradePotion`.

## Vì sao 73 khoá còn lại KHÔNG đăng ký

`_phan_loai_toancuc.py` (bỏ chú thích đúng cấp, đếm theo lớp/thực thể, tính callback
engine) xác nhận **0 SỐNG / 73**: 25 khoá toàn cục có hàm bao quanh không ai gọi (toàn
bộ nhánh `CServerRequestLogic` cũ), 7 khoá nằm trong chú thích, phần còn lại là
SDK thanh toán đã chết (10), 0 thân hàm (4: wings ×2, tournament ×1, WCS ×1), và các
khoá chỉ có lời gọi từ chính hàm chết. **Đăng ký chúng sẽ che mất lỗi thật** — đúng
quyết định của các lượt trước.

## Bẫy

* Chuỗi ĐĂNG KÝ phải HẰNG: `R:on("G_X." .. ten, …)` khiến `_phu_rpc` không đếm —
  nên tệp này sinh ra từ danh sách và ghi nguyên văn từng chuỗi.
* `R:ignore` chỉ so TÊN TRẦN ⇒ không dùng cho khoá có obj nếu muốn im lặng có chủ đích;
  lớp chắn dùng `OnReciveResponse` để vẫn dừng lớp tải.

## ĐO TRONG GAME (20:06, harness mục 38)

```
san sang — 466 handler
chua ho tro: da dang ky 100 khoa (lop chan, chua lam that)
G_TournamentLogic.ClientGetContestInfo -> ma 4401
G_WCSProtocol.ClientGetWCSInfo -> ma 5201
G_ActivityRankLogic.ClientGetTop3Payment -> ma 4001
G_MagicWeaponProtocol.ClientStrengthen -> ma 5002
G_CloudShopLogic.ClientChangeCloudShopStatus -> ma 1
THU lop chan cuoi: 5/5 nhom dung ma goc
```

Bản lưu **57.097 B trả nguyên trạng**, cờ đã xoá, game tắt.

## Ý nghĩa của cột mốc này

**Mọi RPC mà client THẬT SỰ gọi đều có câu trả lời** — không còn panel quay mãi, không
còn dòng `THIEU` cho lời gọi sống. 71/73 khoá còn lại là mã chết/SDK chết/0 thân hàm.
Việc còn lại KHÔNG phải "nối thêm handler" mà là **làm thật từng hệ** (tournament
bracket, WCS, guild camp, họ activity, magic weapon …) hoặc **bấm tay nghiệm thu**.

## Việc kế

1. Chọn một hệ trong lớp chắn để **làm thật** (gợi ý: Magic Weapon — có cấu hình;
   hoặc Guild Camp — mô hình bang hội đã có).
2. Bấm tay nghiệm thu 9 nhóm đã nối trong ngày.
3. Về `bravecross-server`.

# 📌 2/11 (tiếp 10) — THẦN BINH: 4 KHOÁ LÀM THẬT (gỡ khỏi lớp chắn)

## Số chốt

```
python _kiem_cu_phap.py   -> 84 tep, loi 0
python _chay_het.py       -> 53 tep · 1203 phep · 0 do
python run_tests.py       -> dat 162, hong 0
python -I _con_lai.py     -> 440 handler / 71 con thieu (theo ten) · 73 (theo cap)
python -I _phan_loai_toancuc.py --tat-ca -> 0 khoa SONG con thieu (73 = chet/SDK/0 than)
python build.py && deploy.py --push (cay sc/offline = deploy/plain/sc/offline, diff RONG)
```

Tệp mới `handlers/than_binh.lua` (4 khoá), bộ thử `_thu_than_binh.lua` **18/18**.
Bốn khoá đã được gỡ khỏi `chua_ho_tro.lua` (còn **96** khoá lớp chắn).

## Luật dùng (đều là mã GỐC)

| khoá | luật |
|---|---|
| `ClientStarUp` | `GetMagicWeaponRefineConfig(hero, part, sao+1)` → `OpenNeedLevel` / `CostGold` / `CostResource` (JSON); trừ vàng + nguyên liệu; `STAR[hero][part].star++` |
| `ClientStarDown` | `star--` (không hoàn nguyên liệu — [GHIM], bản gốc không ship bảng hoàn) |
| `ClientStrengthen` | exp mỗi món = `GameMagicWeaponItemExpConfig[id].Exp`; cộng dồn; cấp = hàm GỐC `G_MagicWeaponLogic:MapExpToLevel`; **trần = min(cấp tướng, breakThroughLevel)**; chặn exp ở `TotalExp(trần)` |
| `ClientBreakThrough` | `GetMagicWeaponStrengthConfigEx(cấp, part).BreakResource[1]` (đã decode ở config manager); trừ món; `breakThroughLevel += 5` |

Mã lỗi GỐC: 5001 DataException · 5003 OverLevelLimit · 5004 ResourceIsNotEnough ·
5005 OverExpLimit. Phản hồi qua **`g_SBProtocol`** (chữ thường).

## Bẫy

* `g_SBProtocol` là thực thể nhận (không phải `G_MagicWeaponProtocol`).
* `CostResource` là **chuỗi JSON**, còn `BreakResource` đã được config manager decode —
  phải nhận cả hai hình.
* Bộ thử: chuỗi cấu hình phải viết theo **cú pháp Lua** (`{ {PropID=…} }`) vì
  lua51.dll không có cjson thật; viết `[…]` (JSON) làm `loadstring` trả nil.

## ĐO TRONG GAME (20:37, harness mục 39)

```
san sang — 466 handler
THU lop chan cuoi: 5/5 nhom dung ma goc
THU than binh: sao=0->0 (ma 5004), cuong hoa=true/86 (exp 25)
```

Lên sao bị từ chối **5004** vì bản lưu KHÔNG có nguyên liệu tinh luyện (PropID 160/161)
— đúng, không phải lỗi. Cường hoá bằng món 86 (+25 exp → cấp 1) chạy THẬT.
Bản lưu **57.097 B trả nguyên trạng**, cờ đã xoá, game tắt.

## Còn lại (không thể "làm thêm handler")

73 khoá còn thiếu đã đo là **0 SỐNG**: 25 toàn cục chỉ gọi từ `CServerRequestLogic` cũ,
7 trong chú thích, 10 SDK thanh toán chết, 4 zero-body, phần còn lại chỉ gọi từ hàm chết.
Các hệ đang ở lớp chắn (tournament, WCS, guild camp, họ activity, arena shop/record,
friend QQ/WX, recharge sign, cloud shop, state war …) **cần dữ liệu vận hành máy chủ
hoặc người chơi khác** — muốn làm thật phải dựng mô hình (như đã làm cho COG/bang hội/
đấu trường điểm), không phải nối thêm handler.

# 📌 2/11 (tiếp 11) — DOANH TRẠI BANG HỘI: 8 KHOÁ (mô hình một người)

## Số chốt

```
python _kiem_cu_phap.py   -> 85 tep, loi 0
python _chay_het.py       -> 54 tep · 1225 phep · 0 do
python run_tests.py       -> dat 162, hong 0
python -I _con_lai.py     -> 440 handler / 71 con thieu (theo ten) · 73 (theo cap)
python -I _phan_loai_toancuc.py --tat-ca -> 0 khoa SONG con thieu
python build.py && deploy.py --push (cay sc/offline = deploy/plain/sc/offline, diff RONG)
```

Tệp mới `handlers/guild_camp.lua` (8 khoá), bộ thử `_thu_guild_camp.lua` **22/22**.
Lớp chắn còn **88** khoá (đã gỡ 4 thần binh + 8 doanh trại). Trong game **466 handler**.

## Mô hình & luật (đọc từ chính `CUIArmyGroupCampsite.lua`)

| khoá | hành vi |
|---|---|
| `ClientEnterGuildCamp` | trả `{[uid]={GameUserBaseInfo, HeroData}}` — MỘT người (chính mình); chưa có bang ⇒ 3501 |
| `ClientLeaveGuildCamp` · `ClientUserMoveTo` · `ClientDoAction` | ECHO lại cho đúng uid (một người; bản gốc phát cho người khác) |
| `ClientGetGuildCampData` | `{CampData={Tree={GrowUpStateCount}}, UserData={UserTreeRewardCount, UserLastWaterTime}}` — đúng hình client đọc |
| `ClientWaterTree` | cửa **9–21**, hồi **120 phút**, tối đa **25 lần**; ngoài cửa ⇒ 3519, đang hồi ⇒ 3533; đủ 25 ⇒ cây chín + `UserTreeRewardCount++` |
| `ClientGetWaterTreeReward` | đánh dấu `ReceivedTreeRewardCount` (client KHÔNG có hàm nhận) |
| `ClientFirewood` | cửa **20–21**, **3 lần/ngày**, hồi **120 giây**; ghi `UserFireWoodCount`/`UserLastFireWoodTime` + phát `PostDataEvent` |

Dữ liệu ở `GameUserGuildData` (đúng chỗ client đọc): `CampTreeGrow` [MOI] ·
`UserLastWaterTime` · `UserTreeRewardCount` · `ReceivedTreeRewardCount` ·
`UserFireWoodCount`/`UserLastFireWoodTime` + `CampFirewoodDay` [MOI] để đặt lại củi mỗi ngày.

## [GHIM] + hai bẫy

1. **`GameGuildCampTreeRewardConfig` là CHUỖI RỖNG** ⇒ KHÔNG có bảng thưởng cây. Cây vẫn
   lớn đủ 25 lần và `UserTreeRewardCount` tăng, nhưng nhận thưởng chỉ ĐÁNH DẤU + log —
   **không bịa** phần thưởng.
2. **Dùng `G_GameWorld:GetServerTime()` cho cửa giờ/hồi**, không phải `os.time()` — UI so
   bằng giờ máy chủ; múi giờ máy guest lệch 1 tiếng (đo: máy 20:48, game 21:48).
3. `ClientFirewood`/`ClientGetWaterTreeReward` không có hàm nhận ⇒ ghi thẳng dữ liệu +
   `PostDataEvent`; đừng gọi hàm nhận không tồn tại.

## ĐO TRONG GAME (20:50, harness mục 40)

```
san sang — 466 handler
THU lop chan cuoi: 5/5 nhom dung ma goc
THU doanh trai: vao=0, cay=0, tuoi=ma 3519, cui=0 (gio server 21:50)
```

Vào doanh trại OK (một người); tưới bị **3519** vì giờ máy chủ 21:50 đã ngoài cửa 9–21 —
ĐÚNG như UI cũng sẽ chặn. Muốn nghiệm thu đường thành công thì đổi giờ máy hoặc chờ cửa.
Bản lưu **57.097 B trả nguyên trạng**, cờ đã xoá, game tắt.

## Còn lại

73 khoá thiếu = **0 SỐNG** (đo bằng `_phan_loai_toancuc`), và các hệ trong lớp chắn còn
lại cần **dữ liệu vận hành máy chủ hoặc người chơi khác**: tournament, WCS, họ activity,
arena shop/record, friend QQ/WX, recharge sign, cloud shop, state war. Muốn làm thật thì
phải dựng mô hình từng hệ (như COG / bang hội / đấu trường điểm / doanh trại).

# 📌 2/11 (tiếp 12) — ĐẤU TRƯỜNG PHẦN CÒN: 4 KHOÁ THẬT

## Số chốt

```
python _kiem_cu_phap.py   -> 86 tep, loi 0
python _chay_het.py       -> 55 tep · 1239 phep · 0 do
python run_tests.py       -> dat 162, hong 0
python -I _con_lai.py     -> 440 handler / 71 con thieu (theo ten) · 73 (theo cap)
python -I _phan_loai_toancuc.py --tat-ca -> 0 khoa SONG con thieu
python build.py && deploy.py --push (cay sc/offline = deploy/plain/sc/offline, diff RONG)
```

Tệp mới `handlers/dau_truong_con.lua` (4 khoá), bộ thử `_thu_dau_truong_con.lua` **14/14**.
Lớp chắn còn **84** khoá. Trong game **466 handler**.

## Bốn khoá

| khoá | luật |
|---|---|
| `ClientRefreshArenaGoodsWithHonor` | **THẬT**: giá GỐC `ArenaLogic:GetRefreshHonour()` (10/50/100/100+(n−2)×50 theo `RefreshGoodsCount`); trừ `ArenaDataManager:AddUserArenaHonnor`; hàng sinh bằng hai bảng `GameArenaGoodsCrateConfig` + `GameArenaGoodsConfig` (cùng bộ sinh 30/10); thiếu ⇒ **2319 NoEnoughHonor** |
| `ClientGetArenaHeroInfo` | **THẬT**: trả đúng hình `{HeroData, EquipsData, GameMagicWeapon, SkillList, BaseInfo}` từ các bảng người chơi; tướng không có ⇒ **2306** |
| `ClientCheckArenaRecord` | nuốt lặng (client không chờ, không hàm nhận) |
| `GetArenaDetailByUid` | TÊN CŨ của `ClientGetArenaDetailByUid` ⇒ chuyển tiếp nguyên tham số sang handler 30/10 |

Kèm: gỡ danh sách `khongCo(...)` cũ trong `dau_truong.lua` (ba khoá này từng trả 2306) để
hết cảnh báo "dang ky de handler".

## Vì sao ActivityRank (4 khoá) KHÔNG làm

`ClientGetPlayerDiamondConsume` / `ClientGetTop3DiamondConsume` / `ClientGetPlayerPayment` /
`ClientGetTop3Payment`:
1. hai hoạt động đứng sau (`CostRanking`, `ChargeRanking`) **ĐÓNG có chủ đích** trong
   `offline/hoat_dong.lua` (dữ liệu vận hành máy chủ không có trong cấu hình ship);
2. **không có hàm nhận nào được ĐĂNG KÝ** — các callback `CUIActivityCost:OnGet*` /
   `CUIActivityRecharge:OnGet*` chỉ là phương thức, không `Reg` vào event nào (grep 0
   dòng Reg) ⇒ phản hồi không có nơi tiêu thụ.
Vì thế giữ mã **4001 ActivityNotOpen** ở lớp chắn là câu trả lời trung thực. Muốn làm thật
phải mở hoạt động (dựng lịch + bảng thưởng) trước.

## ĐO TRONG GAME (20:56, harness mục 41)

```
san sang — 466 handler
dau truong (con): da noi 4 khoa (lam moi bang danh vong/tuong bang hang/xem chien bao/chi tiet doi thu)
dau truong (con): lam moi cua hang -10 danh vong, 16 mon
dau truong (con): thong tin tuong 25 cho hang 1
THU dau truong (con): lam moi=16 mon (danh vong 490), tuong=25
```

Bản lưu **57.097 B trả nguyên trạng**, cờ đã xoá, game tắt.

## Còn lại

73 khoá thiếu = **0 SỐNG**. Các hệ trong lớp chắn (tournament, WCS, họ activity, friend
QQ/WX, recharge sign, cloud shop, state war) cần **dữ liệu vận hành hoặc người chơi khác**
— làm thật nghĩa là dựng mô hình, không phải nối handler.

# 📌 2/11 (tiếp 13) — SỬA LỖI: VÀO MAIN RỒI KẸT "ĐANG TẢI", NUỐT MỌI CÚ BẤM

## Triệu chứng (chủ dự án báo 21:5x)

Vào được Main, thấy lớp **loading** và màn hình **đứng**: bấm nút nào cũng không ăn.
Chụp màn hình thấy cảnh Main vẽ đủ; `screencap` hai lần liên tiếp **giống hệt** (một
phần vì app đã bị đóng, nhưng bấm chat cũng không phản hồi khi app còn sống).

## Truy vết

`offline.log` dừng ở dòng cuối **`tu_dong: goi loginGame (du phong, khong thay cua so)`**
kèm lỗi:

```
CUILogin2.lua:1803: attempt to index global 'lLoginEnterGameUI' (a nil value)
  <- tu_dong.goi("loginGame")
  <- CUILogin:__checkDownloadTips -> __sngLoginGame -> callGameRPC
```

Đọc mã client: `CUILogin:callGameRPC` (`CUILogin2.lua:3387`) **`g_buyLoadingDialog:Show()`
TRƯỚC**, rồi mới gọi `self:closeEnterGameUI()` (:3397) — hàm này index biến toàn cục
`lLoginEnterGameUI`. Khi cảnh Main đã thay cảnh đăng nhập, node ấy bị huỷ ⇒ **nil** ⇒
nổ SAU khi đã bật lớp đang tải. `g_buyLoadingDialog` không bao giờ được `Hide` ⇒
`CUIManager:128` thấy `IsLoading()` ⇒ **chặn toàn bộ touch**, Main đứng im.

## Vì sao `loginGame` được gọi lúc đã ở Main

`offline/tu_dong.lua` (đồ tự đăng nhập) ở `BUOC == 0`: thấy `g_CUILogin.LoginLogicUid`
đã có (SDK đã đăng nhập) nhưng **không thấy cửa sổ "Vào game" hiện** (`hien(...)` sai vì
cửa sổ chưa hiện kịp) ⇒ sau 5 nhịp gọi `loginGame` "dự phòng". Trong lượt hỏng, client đã
**tự vào game xong** (RPC game nối :09, Main :09) trước khi bộ đếm 5 nhịp nổ (:14) ⇒
`loginGame` chạy trên cảnh Main ⇒ Show loading rồi nổ ⇒ kẹt.

Đây là **đua thời gian**, nên có lượt không dính (các lượt :56, :57, :00 không lỗi).

## Sửa (`offline/tu_dong.lua`)

1. **Đầu `tick`**: thấy `g_CSceneManager:GetCurrentSceneName() == "Main"` thì đặt
   `BUOC = 2` — chặng đăng nhập đã xong, không gọi `loginGame` nữa.
2. **Nhánh dự phòng**: chỉ gọi `loginGame` khi `lLoginEnterGameUI ~= nil` — không bao
   giờ gọi `callGameRPC` khi cửa sổ đã bị huỷ.
3. Thêm **`offline/chan_doan.lua`** (bật bằng `chan_doan.flag` cạnh file lưu): ghi
   traceback mỗi lần `LoadingDialog Show/Hide`, mỗi RPC client gửi, và nhịp tim 1 s
   (`loading=true/false`) — để lần sau gặp "đứng mà có loading" là biết ngay ai bật.

## Đo lại sau khi sửa (23:00–23:01)

```
chan doan: LoadingDialog SHOW  <- CUILogin2.callGameRPC (loginGame dự phòng, cửa sổ CÒN)
chan doan: LoadingDialog HIDE  <- ClientGameGateway (vào game xong)
chan doan: nhip loading=false  (mỗi giây, không ngừng)
nhiem vu ngay: 9 nhiem vu (moi/dat lai: 0)
```

Bấm chat mở panel → touch **ăn** trở lại. `_kiem_cu_phap.py`: 87 tệp, lỗi 0.
Bản lưu trước khi sửa: `_save_truoc_sua_2_11.json` (56.757 B).

# 📌 2/11 (tiếp 14) — TÀI KHOẢN GMAIL + MẬT KHẨU (LDPlayer → Postgres)

## Quyết định

Chủ dự án chốt: làm **LDPlayer trước, Axmol sau**; đăng nhập bằng **gmail + mật khẩu**;
đăng ký xong vào **màn tạo nhân vật của game** (không tự đặt tên). Tài khoản **nằm trong
Postgres của `bravecross-server`**, không phải file cục bộ.

## Hai phía

### `bravecross-server` — HTTP API cho client Cocos cũ

Client gốc nói RPC nhị phân, không nói được WebSocket JSON, nhưng nó **có**
`sngHttpRequestWithString` (gọi được từ Lua). Nên `src/index.ts` nay dựng MỘT cổng
`createServer` + gắn `WebSocketServer({server})` lên đó; HTTP nằm ở **`src/http_api.ts`**:

```
POST /api/register  {email, password} -> {ok, uid, username} | {ok:false, code: 1052}
POST /api/login     {email, password} -> {ok, uid, username} | {ok:false, code: 1050/1051}
GET  /api/health
```

- Tài khoản dùng đúng bảng `users` / `worlds` sẵn có (uid thật từ `bigserial`).
- **Mật khẩu client gửi là MD5 hex** (`CUILogin2.lua:onTouchEnd_OnLogin` băm trước), server
  scrypt hoá chuỗi ấy như mọi mật khẩu khác. Axmol sau này muốn dùng chung tài khoản phải
  gửi **MD5 hex**, không phải mật khẩu thô.
- Mã lỗi trả về khớp `ErrorCode.Login` của client (`share/error.lua:48-58`) để hộp thoại
  hiện đúng câu: 1050 sai mật khẩu · 1051 chưa có tài khoản · 1052 email đã đăng ký.

### LDPlayer — form của CHÍNH client

`offline/tai_khoan.lua` (mới):

1. Bọc `CUILogin:startLogin` để đăng nhập đi đường **TÀI KHOẢN** (`bChannel = false`,
   không điền tài khoản đã lưu) thay vì đường SDK đã chết.
2. Mở form có sẵn của game (`CUILogin:onTouchEnd_OnAccountUI`) — ô **Tên user / Mật Khẩu**,
   nút **Login / Đăng Ký** (ảnh `_tk1.png`). Nới `setMaxLength(64)` cho gmail và thay
   `CUIRegisterVerification:CheckUserName` bằng luật email (bản gốc chặn 16 ký tự).
3. `handlers/login.lua`: `ClientRegister` / `ClientLogin` gọi HTTP rồi trả
   `g_CUILogin:OnClientRegister` / `G_Login:OnServerLogin`. Ba khoá SDK
   (`ClientSdkLogin/ChannelLogin/GPlayLogin`) KHÔNG tự đăng nhập nữa — chỉ chuyển sang form.
4. **Kho theo tài khoản**: `OfflineStore:switchTo(uid)` → `offline_save_<uid>.json`.
   Tài khoản mới chưa có file ⇒ `OfflineBootstrap` dựng người chơi mới **KHÔNG có
   CharacterName** ⇒ `ClientEnterGame` trả **1001 NeedCreateCharacter** ⇒ client mở màn
   tạo nhân vật. `ClientCreateCharacter` ghi tên + giới tính, gọi
   `G_UserLogic:OnCreateCharacter(0)` (đúng hàm đẩy sự kiện `CUILogin` đang chờ), rồi
   client tự `EnterGame` lần hai ⇒ vào game.
5. Địa chỉ server đọc `account_server.txt` cạnh file lưu (mặc định
   `http://192.168.1.2:8787` — đo được LDPlayer ping + curl tới địa chỉ này).

## ĐO ĐƯỢC

```
# bộ thử GỌI THẲNG handler (không bàn phím)
THU TAI KHOAN: KET QUA dat 9, hong 0

# bộ thử ĐI ĐƯỜNG GIAO DIỆN (điền ô + bấm nút thật)
THU TK UI: da bam Dang Ky -> da dang nhap uid=1019 -> da bam Tao nhan vat
THU TK UI: da vao game (canh Battle) -> KET QUA dat 1, hong 0

# Postgres
uid 1019 · tk_ui_1793636760@example.com
offline_save_1019.json · CharacterName "UITK" · 8307 B

# server
[http] đăng ký tk_ui_… -> uid=1019 · [http] đăng nhập tk_ui_… -> uid=1019
```

Gates: `_kiem_cu_phap` **90 tệp · 0 lỗi** · `_chay_het` **55 tệp · 1239 phép · 0 đỏ** ·
`run_tests` **162 · 0** · server `tsc --noEmit` sạch · `test:do_phu` **0 phép đỏ**.

## BẪY ĐÃ VẤP (ghi để không vấp lại)

1. **`OnClientRegister` nằm trên `g_CUILogin`, KHÔNG phải `G_Login`** — gửi sai thì
   `net.lua` báo `tra ve G_Login.OnClientRegister nhung client khong co ham nay`, đăng ký
   xong không chạy tiếp. (`OnServerLogin` thì đúng là `G_Login`.)
2. **`CUILogin:startLogin` đặt `bChannel = true`** cho SDK không-LOCAL; chỉ đặt
   `bChannel=false` lúc init là KHÔNG đủ — phải bọc `startLogin` và sửa SAU khi hàm gốc chạy.
3. **Gõ bằng IME làm `system_server` chết** (đo 22:43: load average 18, watchdog giết
   system_server, SurfaceFlinger treo, `screencap` không trả). Đồ thử điền ô bằng
   `setText` + gọi thẳng hàm nút, KHÔNG dùng bàn phím.
4. **Tên nhân vật ≤ 12 ký tự Việt** — tên ngẫu nhiên của game (`VươngĐồngPhủ`) quá dài,
   nút "Vào game" báo "Tên quá dài". Đồ thử dùng `UITK`.
5. **Cảnh lúc vào game là `Battle`** (trận hướng dẫn) trước khi tới `Main` — đừng lấy
   `GetCurrentSceneName()=="Main"` làm dấu "đã vào game"; dùng `Offline.LAN_VAO_GAME`.
6. **Đăng ký xong client tự gọi `G_Login:Login`** với mật khẩu đã MD5; handler `ClientLogin`
   phải nhận cả chuỗi MD5, không băm lại.

## Còn lại (Axmol — lượt sau)

`bravecross-ax/Content/src/bc/man_login.lua` mới có **một ô tên tài khoản**, chưa có mật
khẩu/đăng ký. Lượt Axmol sẽ: thêm ô mật khẩu + nút Đăng ký, gửi **MD5 hex** để dùng chung
tài khoản với LDPlayer, và nối vào `noi_mang.dangNhap` (đã có WebSocket).

# 🌅 BÀN GIAO SANG MAI (viết cuối 2/11, cho lượt kế tiếp)

## Đã xong hôm nay

**TÀI KHOẢN GMAIL + MẬT KHẨU cho LDPlayer — ĐÃ CHẠY ĐẦU-CUỐI.**
Đăng ký trong form của game → tài khoản vào Postgres → đăng nhập → màn tạo nhân vật → vào game.
Chi tiết ở mục **"2/11 (tiếp 14)"** ngay trên; 6 bẫy ở cuối mục ấy.

## Trạng thái máy lúc bàn giao

- Game **đã tắt**; `frida-server` **đang chạy** (pid 3935); **không còn cờ thử** nào.
- **Postgres + server đang chạy**: `bravecross-postgres` healthy, `http://127.0.0.1:8787/api/health`
  trả `{"ok":true}`. Server được bật bằng `npx tsx src/index.ts` trong phiên này —
  **PC/session khởi động lại thì phải bật lại**:
  ```
  cd D:\PROJECT\ProjectOut\game\bravecross-server
  npm run db:up
  npx tsx src/index.ts
  ```
- `account_server.txt` trên máy ảo: `http://192.168.1.2:8787`. **IP PC đổi thì sửa file này.**
- Tài khoản thử đang có trong Postgres (dùng để test nhanh):
  - `test.ldp@example.com` / `password` (uid 1014)
  - `tk_test_*` và `tk_ui_*` / `123456` (uid 1015–1019)
- Save theo tài khoản: `/data/user/0/com.cmn.buatanew/files/offline_save_1015.json` … `_1019.json`.
  Save cũ `offline_save.json` vẫn còn nhưng **không còn được dùng** khi đăng nhập tài khoản.

## Việc kế tiếp, theo thứ tự

1. ~~**AXMOL — form đăng nhập đầy đủ**~~ — **XONG 3/11**, xem mục
   **"3/11 — AXMOL: FORM ĐĂNG NHẬP ĐẦY ĐỦ"** ở cuối tệp này. Form nay có **email +
   mật khẩu + Đăng nhập + Đăng ký**, gửi **MD5 hex** qua WebSocket sẵn có.
2. **Quyết định mô hình dữ liệu giữa hai client** (chưa làm, cần chủ dự án chốt):
   LDPlayer lưu thế giới trong `offline_save_<uid>.json`; Axmol lưu trong Postgres `worlds`.
   Tài khoản dùng chung, nhưng **nhân vật/thế giới hiện KHÔNG dùng chung**. Muốn chung phải
   chọn: (a) LDPlayer đẩy/kéo world qua HTTP, hay (b) chấp nhận hai thế giới riêng.
3. **Tiện ích tài khoản cho LDPlayer** — **ĐĂNG XUẤT / ĐỔI TÀI KHOẢN: XONG 3/11**,
   lệnh chat **`dangxuat`** (hoặc `doitk` / `doitaikhoan`). Xem mục
   **"3/11 (tiếp) — ĐĂNG XUẤT / ĐỔI TÀI KHOẢN"** ở cuối tệp. **Đổi mật khẩu: XONG
   3/11** — lệnh chat `doimk <cũ> <mới>` + `POST /api/password` (mục
   **"3/11 (tiếp 2) — ĐỔI MẬT KHẨU"**; endpoint **chưa gọi thật** vì Docker tắt).
   **Không làm được:** quên mật khẩu (không có đường gửi mail ⇒ **đừng hứa**).
   Gmail hiện chỉ kiểm định dạng, **chưa gửi mail xác thực**.
4. **Dọn tài khoản thử** nếu muốn DB sạch:
   `delete from users where username like 'tk_%' or username = 'test.ldp@example.com';`
   (xoá `users` tự cascade `worlds`; file save trên máy ảo xoá tay nếu cần).

## Cách đo lại (đừng đoán)

```bash
# phía repo offline
python _kiem_cu_phap.py     # 90 tệp
python _chay_het.py         # 55 tệp · 1239 phép
python run_tests.py         # 162

# phía server
npx tsc --noEmit
npm run test:do_phu         # 547 = 226 tay · 285 sinh · 36

# trong game, KHÔNG cần bàn phím:
adb shell touch /data/user/0/com.cmn.buatanew/files/taikhoan_test.flag
#   -> gọi thẳng handler (9 phép)
adb shell touch /data/user/0/com.cmn.buatanew/files/taikhoan_ui_test.flag
#   -> điền ô + bấm nút thật (1 phép; cần server chạy)
```

## Bẫy nhớ đời của lượt này

1. `OnClientRegister` ở **`g_CUILogin`**, không phải `G_Login`.
2. `CUILogin:startLogin` đặt `bChannel=true` — phải bọc và sửa SAU khi hàm gốc chạy.
3. **Gõ bằng IME làm chết `system_server`** — dùng `setText` + gọi thẳng hàm nút.
4. Tên nhân vật **≤ 12 ký tự Việt**.
5. Vào game đi qua cảnh **`Battle`** rồi mới tới `Main` — dùng `Offline.LAN_VAO_GAME`.
6. Đăng ký xong client **tự gọi `G_Login:Login`** với mật khẩu đã MD5 — đừng băm lại.

# 🔑 3/11 — AXMOL: FORM ĐĂNG NHẬP ĐẦY ĐỦ (xong việc chính của lượt)

## Đã làm

**`bravecross-ax/Content/src/bc/man_login.lua`** — viết lại:
- hai ô nhập: **email** (`axui.EditBox` + `setInputMode(EMAILADDR)`) và **mật khẩu**
  (`setInputFlag(PASSWORD)`, hằng số `ax.EDITBOX_INPUT_FLAG_PASSWORD` = 0), tự điền lại
  email lần trước (`bc_taikhoan.txt`; **không** lưu mật khẩu).
- hai nút: **ĐĂNG NHẬP** (vàng) → `noi_mang.dangNhap(email, md5hex)`; **ĐĂNG KÝ** (xanh)
  → `noi_mang.dangKy(email, md5hex)`.
- **băm MD5** bằng `bc/md5.lua` (`bam()`), 32 hex chữ thường — ĐÚNG hợp đồng của client
  gốc (`CUILogin2.lua:onTouchEnd_OnLogin` → `g_CCMath:MD5`) và của lớp offline LDPlayer.
  Băm hỏng thì **KHÔNG gửi** (không bao giờ gửi mật khẩu thô).
- email **hạ chữ thường** + đòi có `@` trước khi gửi (server HTTP hạ chữ thường; làm y
  hệt để `Foo@x.com` và `foo@x.com` là MỘT tài khoản).
- đăng ký xong (**err = 0**) tự gọi `dangNhap` lại với chính cặp vừa tạo.

**`bravecross-ax/Content/src/bc/may_chu/noi_mang.lua`** — thêm đường ĐĂNG KÝ:
- `M.dangKy(tk, mk)` → gói `LOGIN|G_Login|ClientRegister`, `data = {tk, mk, 0, ''}`.
- `M.khiDangKy(fn)` — callback chạy khi server trả `cb = 'OnClientRegister'`.
- `M.dangNhap` và `M.dangKy` dùng CHUNG một hàm `guiTaiKhoan` (cùng `serial`, cùng
  `hangGui`, cùng **chèn ĐẦU** hàng — yêu cầu tài khoản phải là yêu cầu ĐẦU TIÊN của
  phiên để server gán `session.uid` rồi đẩy world của uid ấy).

**Đường đi:** KHÔNG dùng HTTP. Client Axmol đã có transport WebSocket (`BX_SERVER_URL`);
hai endpoint `/api/register|/api/login` chỉ dành cho client Cocos cũ trên LDPlayer.
Server ghi CẢ HAI đường vào cùng bảng `users` (Postgres), mật khẩu là `scrypt(MD5 hex)`
⇒ một tài khoản dùng được ở cả hai client, miễn cả hai đều gửi MD5 hex.

## Cổng đã chạy (3/11)

| lệnh | kết quả |
|---|---|
| `python kiem/_do_neo_noi_mang.py` | **26/26** neo xuất hiện đúng MỘT lần (sửa `noi_mang.lua` mà không phá cổng) |
| `python kiem/doi_chung_noi_mang.py` | **26/26** lỗi gieo làm đỏ ĐÚNG như khai |
| `python kiem/chay_lua.py kiem/thu_noi_mang.lua --truoc kiem/gia` | **26/26 DAT** (giữ nguyên — bộ này KHÔNG có hàm đặt lại) |
| `python kiem/chay_lua.py kiem/thu_dang_ky.lua --truoc kiem/gia` | **6/6 DAT** (tệp MỚI, đường đăng ký + callback) |
| `python build/_kiem_ma_lua.py` | **214/214** tệp dịch được, 0 lỗi |
| MD5 trên LuaJIT của build | **4/4** chuỗi khớp `hashlib` (`dev`, `abc`, `''`, `tk_ui_1@example.com`) |

⚠ **Bẫy của chính bộ test:** định thêm N27/N28 vào `thu_noi_mang.lua` thì bộ gieo lỗi
báo **LỆCH** ở 5 lỗi gieo (N05/N06/N15/N17/N26): bộ ấy **không có hàm đặt lại**, nên một
phép HỎNG CÓ TÍNH để lại trạng thái dùng chung (mốc đã cài, ws đã OPEN, hàng đợi còn phần
tử) và phép thêm ở CUỐI hỏng oan. Đã tách thành `kiem/thu_dang_ky.lua` tự dựng lại toàn bộ
bản giả ⇒ bộ cũ vẫn **26/26**. (Đây đúng luật đã ghi ở đầu `thu_noi_mang.lua`.)

## Chưa làm / bẫy còn lại

1. **`BX_ACCOUNT`/`BX_MATKHAU` ĐÃ đồng bộ** (3/11): đường env cũng băm **MD5** qua
   `bamMatKhau()` trong `noi_mang.lua`, nên tài khoản tạo bằng form đăng nhập được bằng
   `BX_ACCOUNT` và ngược lại. Hai mốc cổng phải đổi theo: NEO **N26** trong
   `kiem/doi_chung_noi_mang.py` và phép N26 trong `kiem/thu_noi_mang.lua` (nay khẳng định
   `data[2] == MD5('dev') = e77989ed…`). Thiếu `bc.md5`/`bit` thì hàm **in cảnh báo** rồi
   gửi nguyên văn — không im lặng.
2. **WS `ClientLogin` auto-provision** (`AUTO_PROVISION=1`): gõ sai email vẫn tạo tài khoản
   rỗng. Muốn "đăng nhập phải có tài khoản" thì đặt `AUTO_PROVISION=0` khi bật server.
3. **Mã lỗi WS là 1001/1002/1003** (nhóm `ErrorCode.GameWorld` của client: "cần tạo nhân
   vật"/"lỗi khởi tạo"/"không lấy được dữ liệu"), KHÔNG phải 1050..1055. Trên cảnh login
   **không có ai nghe** `OnServerRequestError` (grep 0 observer) nên không có toast sai;
   form tự hiện câu lỗi. Đổi mã là việc của server (`login.ts`), có cổng riêng.
4. **Chưa chạy trong game**: form là UI, phải mở Axmol mới thấy. Quy trình:
   server `:8787` chạy → `BX_SERVER_URL=ws://<ip>:8787` → cảnh Login → form hiện sau 1,5 s.
5. **Chưa chốt: world dùng chung hay riêng** giữa LDPlayer (`offline_save_<uid>.json`) và
   Axmol (Postgres `worlds`). Tài khoản dùng chung; NHÂN VẬT/THẾ GIỚI thì chưa.

# 🚪 3/11 (tiếp) — ĐĂNG XUẤT / ĐỔI TÀI KHOẢN (LDPlayer)

## Đã làm

**Lệnh chat mới** — gõ vào ô chat (kênh nào cũng được, lệnh bị chặn TRƯỚC khi phát sóng):

```
dangxuat        (hoặc: doitk / doitaikhoan, có hay không có "/" đầu, không phân biệt hoa/thường)
```

⇒ Lưu kho đang chơi, xoá phiên trong bộ nhớ, rồi về **màn đăng nhập** để đăng nhập
tài khoản khác. `offline_save_<uid>.json` của tài khoản cũ **vẫn còn nguyên**; đăng nhập
lại đúng uid là thấy đúng dữ liệu cũ.

**Tệp sửa:**
- `sc/offline/tai_khoan.lua` — hàm MỚI `OfflineTaiKhoan:dangXuat(cb)`.
- `sc/offline/handlers/chat.lua` — nhận diện lệnh (đặt TRƯỚC nhánh `nap`), trả
  `OnNotifyMessage(0, 0)` như mọi lệnh chat khác.
- `_thu_dang_xuat.lua` — bộ thử MỚI, **28 phép** (16 phép cho `dangXuat`, 12 phép cho
  lệnh chat), chạy trên PC bằng `lua51.dll`.

## Cách làm (và vì sao)

1. `OfflineStore:save()` — **trước mọi thứ**; bỏ bước này là mất tiến trình kể từ nhịp lưu trước.
2. Xoá **PHIÊN** trong bộ nhớ (`uid`, `email`, `pending`, `DA_MO`/`DEM_CHO`) nhưng **KHÔNG**
   xoá `OfflineStore.FILE` — file lưu của uid vẫn nằm trên đĩa.
3. ~~Gọi **hàm của client** `g_CUIUserInfo:Logout("ChangeUser")`~~ — **ĐÍNH CHÍNH 3/11:
   đường này làm app **SIGSEGV ở GLThread** (nạp lại cảnh Login lần hai). Đường CHÍNH nay là
   **`LGG_CloseGame()`**; xem mục "3/11 (tiếp 3) — NGHIỆM THU TRÊN LDPLAYER" ở cuối tệp.
   Nó làm hai việc ta không tự làm được: dọn stack/đăng ký của phiên cũ và
   `G_DataManager:ResetAllModule()`. Đổi cảnh trần mà thiếu bước ấy thì bảng của tài khoản
   CŨ còn nguyên trong `G_DataManager` và **tài khoản sau thấy dữ liệu của tài khoản trước**.
4. **Đường lùi** (khi `Logout` ném hoặc không có `g_CUIUserInfo`): làm đúng bốn bước cốt lõi,
   mỗi bước một `pcall`, ghi rõ bước nào hỏng — phát `Logout.OnClientLogout` →
   `G_GameWorld:ExitGame()` → `g_CSceneManager:RepaleceScene("Login", "ChangeUser")` →
   `G_DataManager:ResetAllModule()`.

**Hoãn 0,3 s** (`S_CCSchedule:scheduleOnce`): lệnh chat chạy **bên trong**
`OnReciveResponse` của gói `ClientNotifyMessage`; đổi cảnh ngay giữa đường phản hồi là tự
cắt chân lớp đang chạy. Không hẹn giờ được (PC test) thì chạy ngay.

## Vì sao KHÔNG đổi cảnh trần ngay từ đầu

`g_CUIUserInfo:Logout` gọi vài thứ SDK (`SDK_Mgr.strChannel_Name`, `WGRefreshWXToken`) mà
máy này **không có SDK sống** ⇒ nó ném **giữa đường**, trước cả dòng đổi cảnh. Đó là lý do
đường lui phải **tự làm lại bốn bước**, chứ không phải "gọi Logout là xong".

## Cổng đã chạy (3/11)

| lệnh | kết quả |
|---|---|
| `python _kiem_cu_phap.py` | **90 tệp · 0 lỗi** |
| `python _chay_het.py` | **56 tệp · 1267 phép · 0 đỏ** (trước lượt: 55 · 1239) |
| `python run_tests.py` | **162 · 0** |
| `python _thu_nha_cua.py _thu_dang_xuat.lua` | **28/28** |

## Cách thử trong game

Mở game → vào Main → gõ `dangxuat` vào ô chat → gửi. Trong `offline.log` phải thấy
`chat: lenh dang xuat -> true hoan` và `dang xuat: g_CUIUserInfo:Logout('ChangeUser') da chay`
(hoặc các dòng `dang xuat (lui): …` nếu máy không có SDK). Khoảng **3 s** sau, form
email + mật khẩu hiện lại, ô email **tự điền** tài khoản vừa dùng (đổi email là xong).

## Chưa làm

- **Đổi mật khẩu** — cần endpoint mới ở server (`POST /api/password`) + băm MD5 hai lần ở
  client; hiện **chưa có**.
- **Quên mật khẩu** — không có đường gửi mail (server không có SMTP) ⇒ **không làm được**,
  đừng hứa. Muốn có thì phải thêm dịch vụ gửi mail, hoặc đổi sang "mã khôi phục" in ra
  lúc đăng ký.

# 🔑 3/11 (tiếp 2) — ĐỔI MẬT KHẨU (biết mật khẩu cũ)

## Đã làm

**Lệnh chat** (chỉ khi đã đăng nhập tài khoản):

```
doimk <mật-khẩu-cũ> <mật-khẩu-mới>        (hoặc doimatkhau, có/không "/")
```

⇒ client băm **MD5** cả hai bằng chính `g_CCMath:MD5` (cùng hàm `CUILogin2` dùng lúc
đăng nhập) rồi `POST /api/password`; server kiểm mật khẩu cũ (scrypt trên chuỗi MD5) và
thay `password_hash`. Kết quả ghi vào `offline.log`:
`chat: doimk -> ok=true code=0 ok` (hoặc `code=1050` sai mật khẩu cũ, `1051` chưa có tài khoản).

**Tệp sửa:**
- `bravecross-server/src/http_api.ts` — endpoint MỚI `POST /api/password`
  (`{email, old_password, new_password}`, cả hai là MD5 hex). Mã lỗi dùng lại nhóm
  `ErrorCode.Login` (1050/1051/1052/1055) + `2` cho tham số sai; thêm luật "mật khẩu mới
  trùng cũ" → `2`. `src/index.ts` in thêm đường dẫn lúc khởi động.
- `sc/offline/tai_khoan.lua` — `T:doiMatKhau(cu, moi, cb)` + `T:bamMD5(s)`
  (băm bằng `g_CCMath:MD5`; **băm hỏng thì KHÔNG gửi**, không bao giờ gửi mật khẩu thô).
- `sc/offline/handlers/chat.lua` — nhận diện lệnh + gọi; chưa đăng nhập / thiếu `g_CCMath`
  đều **không gửi** và vẫn trả `OnNotifyMessage(0,0)`.
- `_thu_doi_mk.lua` — bộ thử MỚI, **21 phép** (8 cho HTTP/`bamMD5`, 13 cho lệnh chat).

## Cổng đã chạy (3/11)

| lệnh | kết quả |
|---|---|
| `python _kiem_cu_phap.py` | **90 tệp · 0 lỗi** |
| `python _chay_het.py` | **57 tệp · 1288 phép · 0 đỏ** |
| `python run_tests.py` | **162 · 0** |
| `npx tsc --noEmit` (server) | **sạch** |
| `npm run test:do_phu` (server) | **0 phép đỏ** (không thêm khoá handler nào) |

## CHƯA ĐO ĐƯỢC (server chưa bật)

Docker daemon đang **tắt** trên máy này, nên Postgres + server `:8787` chưa chạy ⇒ endpoint
mới **chưa được gọi thật lần nào**. Khi bật server, kiểm bằng ba lệnh này (chuỗi mật khẩu
là MD5 hex — băm bằng `printf '%s' 'password' | md5sum`):

```
# 1) đăng ký (nếu chưa có)
curl -s -X POST http://127.0.0.1:8787/api/register \
     -H 'content-type: application/json' \
     -d '{"email":"doi.mk@example.com","password":"5f4dcc3b5aa765d61d8327deb882cf99"}'

# 2) đổi mật khẩu (cũ "password" -> mới "123456")
curl -s -X POST http://127.0.0.1:8787/api/password \
     -H 'content-type: application/json' \
     -d '{"email":"doi.mk@example.com","old_password":"5f4dcc3b5aa765d61d8327deb882cf99","new_password":"e10adc3949ba59abbe56e057f20f883e"}'
#    -> {"ok":true,...}

# 3) mật khẩu cũ phải HỎNG, mật khẩu mới phải ĐƯỢC
curl -s -X POST http://127.0.0.1:8787/api/login -H 'content-type: application/json' \
     -d '{"email":"doi.mk@example.com","password":"5f4dcc3b5aa765d61d8327deb882cf99"}'
#    -> ok:false code:1050
curl -s -X POST http://127.0.0.1:8787/api/login -H 'content-type: application/json' \
     -d '{"email":"doi.mk@example.com","password":"e10adc3949ba59abbe56e057f20f883e"}'
#    -> ok:true
```

## Bẫy đã biết

1. **Mật khẩu HIỆN TRONG KHUNG CHAT** — client tự đưa câu vừa gõ vào khung chat của mình
   (`CUIChatting.lua:1020-1036`) trước khi gọi server. Chat offline **không phát sóng,
   không vào file lưu**, nhưng đây là máy dev LAN: đừng dùng mật khẩu thật.
2. **Không có "quên mật khẩu"**: server không có SMTP, và endpoint đặt lại mật khẩu mà
   không xác minh gì thì ai biết email cũng chiếm được tài khoản. Đừng thêm.
3. **Hai client dùng chung một chuỗi**: nếu đổi bằng LDPlayer (MD5 hex) thì Axmol cũng phải
   gửi MD5 hex — nó đã làm vậy từ lượt trước. Đổi ở đây xong vẫn đăng nhập được ở Axmol.

# 🧪 3/11 (tiếp 3) — NGHIỆM THU TRÊN LDPLAYER: HAI LỖI THẬT ĐÃ VÁ

Máy: LDPlayer chạy, `adb root`, Postgres + server `:8787` bật, lớp offline build + push,
game chạy qua hook SDK (`frida/chay_trace.py --spawn --tep be_sdk_spawn_bundle.js`).

## Đo được (log thật, `offline.log` + `logcat`)

1. **Lớp offline nạp**: `da chan tang mang, 465 handler dang ky` · `san sang — 466 handler`.
2. **Chuỗi tài khoản bằng UI THẬT** (`taikhoan_ui_test.flag`): đăng ký → đăng nhập →
   tạo nhân vật `UITK` → vào game. uid **1041**, **1042** · `THU TK UI: KET QUA dat 1, hong 0`.
3. **`doimk 123456 654321`** (đồ thử MỚI `thu_chat_tk.lua`, cờ `chat_tk_test.flag`):
   `tai khoan: nhan ok=true` → `chat: doimk -> ok=true` → **đăng nhập lại bằng mật khẩu MỚI**
   `ok=true` ⇒ mật khẩu đã đổi THẬT trên Postgres.
4. **`dangxuat`**: xem lỗi 2 bên dưới.

## HAI LỖI THẬT

**Lỗi 1 — `g_CCMath` là USERDATA, không phải bảng.** `T:bamMD5` kiểm
`type(g_CCMath) == "table"` ⇒ **luôn từ chối**, log `chat: doimk khong bam duoc MD5 —
khong thay g_CCMath:MD5`, dù chính client đang dùng `g_CCMath:MD5` lúc đăng nhập (login
chạy được là bằng chứng). `g_CCMath = CCMath:new()` (`engine.lua:162`) trả userdata của
lớp native. Vá: đọc `m.MD5` qua `pcall`, không kiểm kiểu. Bộ thử PC thêm **C1b** (giả lập
bằng một THREAD có metatable `__index` — kiểu khác bảng, vẫn index được).

**Lỗi 2 — `g_CUIUserInfo:Logout("ChangeUser")` làm app SIGSEGV.** ĐO:
`Fatal signal 11 (SIGSEGV), code 1 (SEGV_MAPERR), fault addr 0x1 in tid … (GLThread)`,
`Process com.cmn.buatanew has died`, màn hình về launcher. Đúng họ bẫy **nạp lại bố cục
LẦN HAI**: cảnh Login đã nạp lúc khởi động, `RepaleceScene("Login")` từ trong Main là sập
(khởi động vào Login thì bình thường — đo cùng lượt). Vá: đường chính của `dangXuat` là
**`LGG_CloseGame()`** (đóng app sạch; `CUIOptions`/`CUIDownload` dùng đúng hàm này) —
lần mở sau vào thẳng cảnh Login và form tài khoản hiện ra. Đo lại: `LGG_CloseGame -> true`,
process chết **không có fatal signal**. Bộ thử PC thêm **A5**; bẫy của chính phép thử:
`dangXuat` trả `(true, 'hoan')` NGAY, việc thật chạy trong hàm hẹn giờ ⇒ phải đọc qua
**callback**, không đọc giá trị trả về.

## Cổng lại sau khi vá

`_kiem_cu_phap.py` **91 tệp · 0 lỗi** (thêm `thu_chat_tk.lua`) · `_thu_dang_xuat.lua` **29/29**
· `_thu_doi_mk.lua` **22/22** · `_chay_het.py` **57 tệp · 1290 phép · 0 đỏ** ·
`run_tests.py` **162 · 0**.

## Trạng thái máy lúc bàn giao

Postgres (`bravecross-postgres`) + server `:8787` **đang chạy** (bật bằng `npx tsx src/index.ts`,
tiến trình nền); game **đã đóng** (do `LGG_CloseGame`); không còn cờ thử. Tài khoản thử mới
trong DB: uid **1039–1042** (`tk_ui_1793711*.example.com`, mật khẩu đã đổi thành `654321` ở
1041/1042). Dọn: `delete from users where username like 'tk_ui_1793711%';`

## Khép vòng "đăng xuất → đăng nhập lại tài khoản CŨ" (đo 3/11)

Đồ thử MỚI `offline/thu_dang_nhap_cu.lua`: điền ô bằng `setText` rồi bấm **nút thật**
`g_CUILogin:onTouchEnd_OnLogin` (KHÔNG dùng bàn phím — IME từng giết `system_server`).
Bật bằng **hai tệp cạnh file lưu**: `dangnhap_cu_test.flag` + `dangnhap_cu.txt`
(dòng 1 email, dòng 2 mật khẩu THÔ — client tự băm MD5 như người gõ tay).

**ĐO ĐƯỢC** (tài khoản uid **1043**, mật khẩu đã đổi thành `654321` ở lượt trước):

```
THU DANG NHAP CU: da dien o + bam Dang Nhap
dang nhap tai khoan: tk_ui_1793712644@example.com
tai khoan: kho uid 1043 — da nap file luu          <-- nạp KHO CŨ, không tạo người mới
dang nhap thanh cong: uid=1043
THU DANG NHAP CU: server tra uid=1043 · kho dang dung=1043 · file=offline_save_1043.json
THU DANG NHAP CU: OK — vao game (canh Battle)
```

⇒ Form đăng nhập đi đúng đường tài khoản, server nhận, `OfflineStore` chuyển sang
**đúng** `offline_save_<uid>.json`, và vào game. Ảnh chụp giữa lượt: cảnh cốt truyện
Lôi Thú (đã vào gameplay). Bộ đệm `logcat` hiện tại: **0** dòng `Fatal signal 11`.

⚠ Bẫy của chính lượt đo: `adb push /data/user/...` từ Git Bash bị đổi thành
`C:/Program Files/Git/data/...` ⇒ **`MSYS_NO_PATHCONV=1`**, và đường dẫn NGUỒN phải là
đường Windows (`C:/Users/...`), không phải `/tmp/...`.

# 🧰 3/11 (tiếp 4) — LỖI "CHỌN RƯƠNG XONG ĐỨNG": `ClientPlayLottery(5)` KHÔNG ĐƯỢC TRẢ LỜI

## Triệu chứng (chủ dự án báo)

Xong trận tân thủ → mở **Rương** → bấm **"Miễn phí"** ở rương **Hoàng Kim** → màn hình
**đứng**, bấm gì cũng không ăn.

## Chẩn đoán (`chan_doan.flag` bật — log thật)

```
RPC   > G_LotteryLogic.ClientPlayLottery
ERROR   ClientPlayLottery: loai la 5
WARN    LoadingDialog SHOW        <- và KHÔNG BAO GIỜ HIDE
stack traceback:
    chan_doan.lua:49 in 'Show'
    CUIMain.lua:936 in 'v'            (OnWaitingForRequest)
    CUILottery.lua:2338               (post OnWaitingForRequest trước khi gửi)
nhịp loading=true ... (mãi mãi)
```

Chuỗi nhân quả: `CUILottery:onTouchEnd_OnLotteryDiamondOnce` gửi
`ServerPlayLottery(LOTTERY_TYPE.DIAMOND_FREE)` rồi post `OnWaitingForRequest` ⇒
`CUIMain:OnWaitingForRequest` **Show** lớp tải. Lớp tải chỉ được **Hide** trong
`CUIMain:OnReceiveResponse`, mà hàm ấy chỉ chạy khi có PHẢN HỒI. Handler offline **không
trả lời** ⇒ `CUIManager:131` thấy `IsLoading()` ⇒ **chặn mọi cú bấm**.

## Nguyên nhân

`offline/handlers/lottery.lua::thongTin()` chỉ biết loại **1/2/3/4/6**; `LOTTERY_TYPE`
(`share/Protocol.lua:712-719`) còn **`DIAMOND_FREE = 5`** ("免费钻石一次"). Với 5 nó
`return nil` ⇒ handler `OfflineLog:err(...)` rồi **return luôn** (im lặng).

## Vá (3 chỗ)

1. **Thêm loại 5**: bể `"Diamond"`, **1** lượt, **giá 0** (`share/LotteryLogic.lua:911-912`:
   `nLotteryCostDiamond = 0`).
2. **Đặt hồi chiêu sau lượt miễn phí kim cương**: gọi
   `G_LotteryLogic:ResetFreeDiamondLotteryTime()` (đặt `LastFreeDiamondTime`), đúng hàm gốc
   (`share/LotteryLogic.lua:214-230`). Thiếu nó thì "Miễn phí" sáng mãi.
3. **Không bao giờ bỏ lặng một yêu cầu**: loại LẠ giờ trả
   `OnReciveResponse("", "", 1, {})` — chặn CẢ LỚP lỗi "kẹt lớp tải vì handler không đáp".

## Đồ thử mới (chạy trong game, không cần bàn phím)

`offline/thu_vong_quay.lua` + cờ `vongquay_test.flag` — gọi THẲNG handler:

```
THU VONG QUAY: OK loai 5 -> OnServerLotteryFinish(mode=5, tResult=table, bTest=false)
THU VONG QUAY: LastFreeDiamondTime 0 -> 1793716816
THU VONG QUAY: OK loai 99 -> tra loi ma 1
```

**Bẫy của chính bản vá, do đồ thử bắt:** bản đầu viết `if nLotteryType == L.DIAMOND_FREE`
trong handler, nhưng `L` là **biến cục bộ trong `thongTin`** ⇒
`attempt to index global 'L' (a nil value)` tại `lottery.lua:170`. Sửa thành
`LOTTERY_TYPE.DIAMOND_FREE`.

**Cổng:** `_kiem_cu_phap` **93 tệp · 0 lỗi** · `_chay_het` **57 tệp · 1290 phép · 0 đỏ** ·
`run_tests` **162 · 0**.

# 🌉 3/11 (tiếp 5) — CẦU RPC: LDPlayer DÙNG HANDLER CỦA SERVER (NHÓM `G_LotteryLogic`)

## Đã làm

**Server** — endpoint MỚI `POST /api/rpc` (`src/http_api.ts`):
```
{ uid, moudule, objName, funcName, data, serial, snapshot }  ->  tl { obj, cb, err, suKien, gui, them }
```
Nhận gói, **ghi `snapshot` vào `worlds.data` của uid** (nếu có), gọi `dispatch()` với
`session.uid = uid`, trả nguyên `tl`. Log mỗi lượt: `[rpc] uid=… obj|func -> tay err=…`.

**Client** — tệp MỚI `offline/noi_server.lua`: bọc `OfflineNet.dispatch`; **chỉ** các
`objName` trong `OfflineNoiServer.NHOM` đi qua cầu, còn lại giữ nguyên router offline.
- Mỗi lượt gửi kèm **snapshot 39 bảng** (`OfflineStore.data`) ⇒ handler server tính trên
  ĐÚNG dữ liệu người chơi đang có.
- Phản hồi được đẩy vào hàng đợi của `OfflineNet` dưới dạng
  `g_CUIGameRPCManager:OnReciveResponse(...)` (khung sau mới chạy — đúng luật bất đồng bộ
  của `net.lua`), rồi cầu `syncFromClient()` để ghi vào file lưu.
- Chưa đăng nhập / không có HTTP / lỗi mạng ⇒ **trả lời mã 1**, không bao giờ treo.

**Nhóm đang nối:** `G_LotteryLogic` (4 khoá; server đã port tay ở `vong_quay.ts`, **có**
`DIAMOND_FREE = 5`). Đổi nhóm: sửa `OfflineNoiServer.NHOM`.

## Đo được (đồ thử `offline/thu_cau_rpc.lua`, cờ `cau_rpc_test.flag`)

Gọi qua ĐÚNG đường client `CallServer(...)`:

```
noi_server: gui G_LotteryLogic.ClientGetLotteryData [1]
noi_server: G_LotteryLogic.ClientGetLotteryData -> err=0 cb="OnGetLotteryData"
noi_server: gui G_LotteryLogic.ClientPlayLottery [2]
noi_server: G_LotteryLogic.ClientPlayLottery -> err=2002 cb=""      <- hồi chiêu, ĐÚNG luật server
noi_server: gui G_LotteryLogic.ClientPlayLottery [3]
noi_server: G_LotteryLogic.ClientPlayLottery -> err=0 cb="OnServerLotteryFinish"
dem gui/nhan/hong = 3/3/0
```

Server: `[rpc] uid=1044 G_LotteryLogic|ClientPlayLottery -> tay err=0`.

**Phần thưởng về ĐÚNG file lưu:** `offline_save_1044.json` sau lượt —
`GameUserLottery.FreeCount = 4` (màn hình TRƯỚC lượt ghi "Miễn phí còn 5 lần"),
`LastUpdateTime = 1793718616`, túi 5 món. Tức
**server chạy luật + phát thưởng**, client áp mục Data, cầu ghi lại vào file lưu.

## Bẫy đã vấp

1. **`/api/rpc` trả `tl` KHÔNG có trường `ok`**, mà `OfflineTaiKhoan:goi` coi `ok == true` là
   thành công (`t.ok` của endpoint tài khoản) ⇒ cầu báo "hỏng" dù server đã trả lời. Sửa:
   điều kiện đúng là **`type(tl) == "table" and tl.err ~= nil`**.
2. **Snapshot GHI ĐÈ `worlds.data` của uid** ⇒ trong lúc bật cầu, LDPlayer là **nguồn sự
   thật** cho uid ấy. Đây chính là chỗ "world dùng chung LDPlayer↔Axmol" — hiện
   **chưa chốt** với Axmol; đừng bật cầu và Axmol cùng lúc cho một uid.
3. Cầu chỉ nên route **nhóm đã port tay** ở server; nhóm chưa port sẽ trả "sinh" (rỗng) —
   tệ hơn lớp offline đang có.

## Nối THÊM nhóm `G_FortuneWheelLogic` (vòng quay may mắn) — đo 3/11

`OfflineNoiServer.NHOM` nay có **hai** nhóm: `G_LotteryLogic` + `G_FortuneWheelLogic`.
Đồ thử `cau_rpc_test.flag` gọi qua đúng đường `CallServer`:

```
noi_server: gui G_FortuneWheelLogic.ClientRefreshFortuneWheelList [4]
noi_server: … -> err=0 cb=""
banh sau lam moi = 12 o
noi_server: gui G_FortuneWheelLogic.ClientFreeRoll [5]
noi_server: … -> err=0 cb=""
HasRollFreeWheelCount = 1
dem gui/nhan/hong = 5/5/0
```
Server: `[rpc] uid=1044 G_FortuneWheelLogic|ClientRefreshFortuneWheelList -> tay err=0` ·
`[rpc] … ClientFreeRoll -> tay err=0`.

**File lưu `offline_save_1044.json` sau lượt:** `GameUserFortuneWheel.FreeWheelList` **12 ô**
(ví dụ `[{PrizeID:60009}, …]`), `VipWheelList` **12 ô**, `HasRollFreeWheelCount = 1`,
`LastRollFreeWheelTime = 1793719076` ⇒ bánh do SERVER sinh, lượt quay do SERVER chạy, tất cả
về đúng file lưu cục bộ.

⚠ Nhóm `G_LotteryLogic` của lượt này trả `2002` cho cả hai lượt free — **đúng luật server**
(hồi chiêu/đếm lượt nằm ở server), không phải lỗi cầu.

## Nối theo KHOÁ + ba nhóm nữa — `M.KHOA` (đo 3/11)

`noi_server.lua` nay có **hai** bảng: `M.NHOM` (cả objName, chỉ dùng khi server đã port
**mọi** khoá client gọi) và `M.KHOA` (từng `"objName.funcName"`). Lý do: route cả một obj
mà server chỉ port một phần sẽ đẩy các khoá còn lại vào nhánh "sinh" (rỗng) — **tệ hơn**
lớp offline đang có.

Đang nối:

| kiểu | khoá | server |
|---|---|---|
| `NHOM` | `G_LotteryLogic` | `vong_quay.ts` (4 khoá) |
| `NHOM` | `G_FortuneWheelLogic` | `vong_quay_may_man.ts` (5 khoá) |
| `KHOA` | `G_SevenDaysGiftLogic.ClientSevenDaysGift` | Mốc 43 |
| `KHOA` | `G_MidasTouchLogic.ClientRunMidasTouchWithCount` | Mốc 42 |
| `KHOA` | `G_DestinyLogic.ClientActiveProgress` · `…WithCount` | Mốc 44 |

**ĐO** (đồ thử `cau_rpc_test.flag`, đi qua `CallServer`):

```
noi_server: G_SevenDaysGiftLogic.ClientSevenDaysGift -> err=0 cb="OnServerGetSevenDaysGift"
noi_server: G_MidasTouchLogic.ClientRunMidasTouchWithCount -> err=0 cb="OnServerRunMidasTouchWithCount"
noi_server: G_DestinyLogic.ClientActiveProgress -> err=2901 cb=""      <- thiếu sao, ĐÚNG luật server
```
Server: `[rpc] uid=1044 … -> tay err=0 / err=0 / err=2901`.

**File lưu `offline_save_1044.json` sau lượt:** `C_SevenDaysGiftData = {GetStatusMap:{"1":2},
DayCount:1}` (server đã cấp ngày 1) · `C_MidasTouchData = {CurIndex:1}` · `Gold 52000`,
`Diamond 45` · `DestinyProgress 0` (bị từ chối nên KHÔNG đổi).

## Nối thêm `G_FormationLogic` + `G_HeroPracticeLogic` (đo 3/11)

Cả hai obj client gọi ĐÚNG 3 khoá mà server đã port (Mốc 46/47 — **tái dựng**, có `[GHIM]`),
nên thêm vào `M.NHOM`.

```
noi_server: G_FormationLogic.ClientUpgrade -> err=5102 cb=""                    <- NoOpen: cần Lv42
noi_server: G_FormationLogic.ClientSelectAdvancedFormation -> err=5102 cb=""    <- NoOpen: cần Lv42
noi_server: G_HeroPracticeLogic.ClientPracticeHero -> err=0 cb="OnPracticeHero"
noi_server: G_HeroPracticeLogic.ClientGetPracticePrize -> err=4201 cb=""        <- chưa đủ 2 giờ
noi_server: G_HeroPracticeLogic.ClientGetPracticeInfo -> err=0 cb="ClientGetPracticeInfo"
```
Server: `[rpc] uid=1044 … -> tay err=5102 / 5102 / 0 / 4201 / 0`.

**File lưu `offline_save_1044.json`:** `GameUserHeroPractice.PracticeStates["1"] =
{AreaID:"1", HeroID:25, BeginTime:1793720760}` (server gán tướng vào ô luyện, client lưu lại);
`GameUserFormation` **vẫn `{}`** — đúng, vì cả hai lượt trận pháp bị từ chối 5102 (tài khoản Lv1),
cầu KHÔNG bịa thành công.

**Bảng nối hiện tại** (`M.NHOM` cả obj · `M.KHOA` từng khoá):

| | obj / khoá | server |
|---|---|---|
| NHOM | `G_LotteryLogic` | `vong_quay.ts` |
| NHOM | `G_FortuneWheelLogic` | `vong_quay_may_man.ts` |
| NHOM | `G_FormationLogic` | `tran_phap.ts` |
| NHOM | `G_HeroPracticeLogic` | `luyen_hero.ts` |
| KHOA | `G_SevenDaysGiftLogic.ClientSevenDaysGift` | `qua_7ngay.ts` |
| KHOA | `G_MidasTouchLogic.ClientRunMidasTouchWithCount` | `diem_kim.ts` |
| KHOA | `G_DestinyLogic.ClientActiveProgress` (+`WithCount`) | `thien_menh.ts` |

## Nối thêm 4 nhóm nhỏ (theo KHOÁ) — thẻ tháng · phụ đề · mã đổi quà · trang bị (3/11)

`M.KHOA` thêm: `G_MonthlyCardLogic.ClientGetReward` · `G_SubtitleLogic.ClientSetUserCopySubtitle`
+ `ClientGetCopySubtitle` · `G_RedeemCodeLogic.ClientUseRedeemCode` ·
`G_EquipmentLogic.ClientSynthesisEquipment` + `ClientAutoIntensifyEquipment`.

**ĐO** (`cau_rpc_test.flag`, qua `CallServer`):

```
noi_server: G_MonthlyCardLogic.ClientGetReward -> err=1 cb=""                 <- chưa có thẻ
noi_server: G_SubtitleLogic.ClientSetUserCopySubtitle -> err=0 cb=""
noi_server: G_SubtitleLogic.ClientGetCopySubtitle -> err=0 cb="OnGetCopySubtitle"
noi_server: G_RedeemCodeLogic.ClientUseRedeemCode -> err=2405 cb=""           <- không có kho mã
noi_server: G_EquipmentLogic.ClientSynthesisEquipment -> err=0 cb=""
noi_server: G_EquipmentLogic.ClientAutoIntensifyEquipment -> err=0 cb=""
```
Server: `[rpc] uid=1044 … -> tay err=1 / 0 / 0 / 2405 / 0 / 0`.

**KHE HỞ TÌM RA + ĐÃ VÁ:** `GameUserSubtitle` **không nằm trong `OfflineStore.TABLES`** ⇒ handler
server chạy đúng nhưng `syncFromClient` không chép bảng ấy vào file lưu ⇒ phụ đề đặt qua cầu
**mất sau khi mở lại, im lặng**. Đã thêm vào `TABLES`; đo lại: `offline_save_1044.json` có
`GameUserSubtitle = {"L_N_01_03": {Subtitle:"cau thu tu cau RPC", Time:0, Color:""}}`.
`test/run.lua` cập nhật **39 → 40 bảng** (kèm lý do), `run_tests` về **162 · 0**.

Trang bị: `GameUserEquipment["25"]` có các ô (5, 6…) sau hai lượt ghép/tự cường hoá — bảng
này vốn đã ở `TABLES` nên vào file lưu bình thường.

## Nối thêm `G_AchieveLogic` + `G_MailLogic` + `G_PotionLogic` + `G_CavernLogic` (3/11)

Ba obj đầu server port ĐỦ bộ khoá client gọi ⇒ `M.NHOM`. Hang Động chỉ 5/8+ khoá ⇒ `M.KHOA`.

```
noi_server: G_MailLogic.ClientGetMailList -> err=0 cb="OnServerGetMailList"
noi_server: G_AchieveLogic.ClientReachAchieve -> err=0 cb="OnReachAchieve"   (lượt đầu)
noi_server: G_AchieveLogic.ClientReachAchieve -> err=2203 cb=""              (lượt sau: đã đạt)
noi_server: G_PotionLogic.ClientBuyPotion -> err=0 cb="OnBuyPotion"
noi_server: G_CavernLogic.ClientRevive -> err=1 cb=""                        (không ai chết)
noi_server: G_CavernLogic.ClientResetCavern -> err=0 cb="OnResetCavern"
```

**GIỚI HẠN MỚI TÌM RA (quan trọng):** handler server chạy đúng nhưng phản hồi chỉ áp được lên
những bảng client **ĐÃ CÓ**. `CDataManager:WriteToTable` (`share_CDataManager.lua:391-410`):
bảng vắng mặt + `KeyName ~= "Table_Add"` ⇒ `goto Exit0`, **mục Data bị BỎ, im lặng**. ĐO:
`ClientResetCavern` chạy trên server (`worlds.data` của uid 1044 có
`GameUserCavern {ResetCount:1, ProgressState:0, CurrentProgress:1, …}`) nhưng **file lưu
LDPlayer KHÔNG có bảng ấy** — vì tài khoản mới chưa từng vào Ma Khu nên client chưa tạo
`GameUserCavern`. Vào Ma Khu một lần (lớp offline tự tạo bảng) là các lượt sau áp được.

Cách chữa nếu cần (chưa làm, cần chủ dự án duyệt vì đụng bảng `TU_DUNG`): trong
`noi_server:traLoiVe` tạo `{}` cho bảng vắng mặt trước khi đẩy `OnReciveResponse` — nhưng
`GameUserStarSoul` phải là **NIL** lúc khởi động, nên chỉ được làm theo danh sách trắng.

## Vá giới hạn "bảng vắng mặt" bằng DANH SÁCH TRẮNG (3/11)

`noi_server.lua` thêm `M.TAO_RONG = { GameUserCavern = true }`. Trong `traLoiVe`, trước khi
đẩy `OnReciveResponse`, bảng nào **trong danh sách trắng** mà client CHƯA CÓ thì tạo `{}` —
để `CDataManager:WriteToTable` không bỏ mục Data.

**ĐO:** `noi_server: tao rong bang GameUserCavern` → `offline_save_1044.json` có
`GameUserCavern = {ProgressState:0, CurrentProgress:1, ResetCount:1, TotleResetCount:1, ReviveCount:0, …}`
(khớp `worlds.data` của uid 1044 trên server). Trước khi vá: bảng ấy **không** có trong file lưu.

⚠ Quy tắc khi thêm bảng vào `TAO_RONG`: bảng đó phải **chịu được `{}`** (client tự điền mặc
định). **KHÔNG** thêm `GameUserStarSoul` — nó phải là **NIL** lúc khởi động (`OfflineStore.TU_DUNG`).

## Nối 6 khoá BẢNG XẾP HẠNG (`G_RankLogic`) — 3/11

Client gọi **20** khoá `G_RankLogic`, server port tay **6** ⇒ dùng `M.KHOA`, không dùng `NHOM`:

`ClientGetLevelRank` · `ClientGetArenaDefendPowerRank` · `ClientGet5HeroPowerRank` ·
`ClientGetPveNormalRank` · `ClientGetPveEliteRank` · `ClientGetPveStarRank`.

**ĐO:**
```
noi_server: G_RankLogic.ClientGetLevelRank -> err=0 cb="OnGetLevelRank"
noi_server: G_RankLogic.ClientGet5HeroPowerRank -> err=0 cb="OnGet5HeroPowerRank"
```
`POST /api/rpc … ClientGetLevelRank` trả `gui` là **BẢN ĐỒ khoá uid** (4398 ký tự), có **uid 1044**
của chính LDPlayer — vì cầu đã đẩy thế giới của nó lên `worlds`. Tức LDPlayer **xuất hiện trong
BXH của server** (cùng bảng với tài khoản Axmol).

# 🧰 4/11 — MẤT SERVER VẪN CHƠI ĐƯỢC: hai đường lùi

Từ 2/11 có **hai** đường phụ thuộc server phụ: (1) đăng nhập lấy uid từ Postgres, (2) cầu
RPC `offline/noi_server.lua` cho các nhóm đã port. Server tắt ⇒ người chơi **không vào được
game** và mọi khoá đã nối trả lỗi. Lượt này vá cả hai, và **đo trong game** với server TẮT.

## 1. Cầu RPC rơi về handler offline

`M:gui` khi HTTP hỏng (mã 3001: không gọi được / hết giờ / phản hồi hỏng) **chạy lại
`OfflineNet.dispatch` NGUYÊN BẢN** cho đúng khoá ấy — tức lớp offline trả lời như trước khi
có cầu — thay vì trả `err = 1`. Không có handler offline thì mới trả lỗi.

**ĐO** (server tắt, `dangnhap_cu` + `thu_cau_rpc`):
```
tai khoan: HTTP that bai (-1)
noi_server: G_LotteryLogic.ClientGetLotteryData hong (ok=false) — chay handler OFFLINE
noi_server: G_MailLogic.ClientGetMailList hong (ok=false) — chay handler OFFLINE
```
Tiếp theo là **NGHỈ 30 GIÂY** sau một lần hỏng (`M.NGHI_GIAY`, `M.hongLuc`): `gui` trả `false`
⇒ `dispatch` đi thẳng handler offline, KHÔNG chờ HTTP 2 s mỗi lượt. Lượt gọi đầu tiên sau
khoảng nghỉ mà thành công thì xoá mốc (server đã sống lại).

## 2. Đăng nhập bằng KHO CỤC BỘ khi mất server

`T:dangNhap` bọc callback: lỗi MẠNG + **đúng tài khoản dùng lần cuối trên máy này** + **kho
`offline_save_<uid>.json` có thật** ⇒ vào game bằng kho ấy. `account_last.txt` nay ghi **hai
dòng** (email, uid); tệp cũ một dòng thì đường lùi TỰ TẮT (không đoán uid).

**ĐO** (server tắt, form đăng nhập thật của client):
```
THU DANG NHAP CU: da dien o + bam Dang Nhap
tai khoan: KHONG GOI DUOC SERVER (http) — VAO BANG KHO CUC BO uid=1044; mat khau KHONG duoc kiem, chi dung tren may nay
dang nhap: CHE DO OFFLINE (khong co server) — uid=1044, van mo binh thuong
dang nhap thanh cong: uid=1044
THU DANG NHAP CU: OK    — vao game (canh Main)
```
⚠ Đây là chế độ của MÁY CỤC BỘ, **không kiểm mật khẩu** — server trả lời "sai mật khẩu" /
"chưa có tài khoản" thì KHÔNG có đường lùi. Đăng ký tài khoản MỚI vẫn cần server.

## 3. LỖI THẬT bắt được trong game: `tonumber(x:gsub(...))`

Bản đầu của `uidDaLuu` viết `tonumber(tostring(d2):gsub("%s+", ""))`. `gsub` trả **HAI** giá
trị (chuỗi, số lần thay) ⇒ `tonumber` nhận số lần thay làm **CƠ SỐ**:
```
[string ".../offline/tai_khoan.lua"]:123: bad argument #2 to 'tonumber' (base out of range)
```
Lỗi nổ **BÊN TRONG callback HTTP** nên bị nuốt: `offline.log` **không có một dòng nào** của
đường đăng nhập sau "gui /api/login", form đứng im. Vá bằng **ngoặc kép**
`tonumber((...))`; đã grep cả lớp offline: chỉ có đúng một chỗ.

**ĐO TRỌN 26 BƯỚC** (server TẮT, `thu_cau_rpc` bật cờ `cau_rpc_go`):
```
THU CAU RPC: LastFreeDiamondTime sau = 1793724419 (dem gui/nhan/hong = 5/0/5)
```
27 lượt gọi nhưng chỉ **5** lượt chạm HTTP (mỗi lượt chờ ~2 s rồi rơi về handler offline),
22 lượt còn lại đi THẲNG handler offline nhờ khoảng nghỉ 30 s. **26/26 bước đều có câu trả
lời**, game không treo, `KET THUC` tới đúng hạn.

⚠ **Khác biệt ĐÃ KHAI khi đang trong khoảng nghỉ:** khoá đã nối sẽ do **handler OFFLINE** trả
lời chứ không phải server — vd `G_RedeemCodeLogic.ClientUseRedeemCode` ra **1** (lớp chắn)
thay vì **2405** của server. Cả hai đều là TỪ CHỐI; đừng đọc mã ấy như lỗi của cầu.

## 4. ĐÍNH CHÍNH: GỠ `G_PotionLogic` KHỎI CẦU (4/11)

Mục *"Nối thêm `G_AchieveLogic` + `G_MailLogic` + `G_PotionLogic` + `G_CavernLogic` (3/11)"*
ở trên đã nối **cả obj** `G_PotionLogic`. Nay **gỡ** — đo được nó làm CLIENT nổ:

```
ERROR  loi khi tra g_CUIGameRPCManager.OnReciveResponse:
       [share/class.lua]:66: table index is nil
       ... PotionDataManager.lua:762 updatePotionData <- GetPotionList <- PotionLogic.lua:563 BuyPotion
       <- ClientPotionLogic.lua:346 <- CUIRPCManager.lua:236
```
Server trả `err = 0 cb = "OnBuyPotion"` (port ĐÚNG, `thuoc.ts` Mốc 30) ⇒ client chạy hàm
nhận ⇒ `PotionLogic:BuyPotion` đọc `configCacheName.PotionConfig` — **bị chú thích** trong
`share_configManager.lua:129/146` ⇒ `table index is nil`. Hệ thuốc **chết trong chính bản
client**; lớp offline đã biết và **cố ý trả lỗi thay vì gọi hàm nhận** (`tinh_nang.lua:393-417`).

ĐO: `grep -c 'table index is nil' offline.log` = **4** lượt — 3 lượt 3/11 + 1 lượt 4/11, và
lượt nào có CẦU mới nổ. Sau khi gỡ: `ClientBuyPotion` đi handler offline, **0** lượt nổ.

⇒ LUẬT: một nhóm chỉ nên nối khi **client TIÊU ĐƯỢC phản hồi THÀNH CÔNG**. Nhóm nào mà lớp
offline đang cố ý trả lỗi (vì hàm nhận của client chết) thì nối vào cầu là biến lỗi trung
thực thành crash.

## 5. Nghiệm thu CẢ HAI CHIỀU (4/11)

| | server TẮT | server BẬT |
|---|---|---|
| đăng nhập | `VAO BANG KHO CUC BO uid=1044` → vào Main | `/api/login` → uid 1044 |
| 27 lượt gọi của `thu_cau_rpc` | `dem gui/nhan/hong = 5/0/5` · **26/26 bước có đáp án** | **26/26/0** (26 lượt chạm server, mọi lượt `err` của LUẬT) |
| lỗi client | 0 | **0** (sau khi gỡ `G_PotionLogic`) |

Con số 26 (không phải 27) ở lượt cuối là ĐÚNG: bước `ClientBuyPotion` nay đi handler offline,
không đi cầu. Cùng một bộ thử, cùng một bản build — chỉ khác server bật/tắt.

---

# 📌 BÀN GIAO SANG MAI (viết cuối 4/11)

## Trạng thái máy lúc dừng
- Postgres (`bravecross-postgres`) + server **`:8787` đang chạy** (`npx tsx src/index.ts`, log `/tmp/bc_server3.log`).
- Game **đang mở ở cảnh Main**, uid **1044** “UITK” (Lv1 · vàng 80365 · kim cương 5), hướng dẫn đang trỏ “Tấn Công”.
- `frida-server` chạy; driver `chay_trace.py` **đã thoát** (không còn phiên Frida nào).
- **Không còn cờ thử**; `account_last.txt` = `tk_ui_1793715945@example.com` + `1044`; `account_server.txt` = `http://192.168.1.2:8787`.

## Đã xong 4/11 (chi tiết ở các mục 4/11 phía trên)
1. Cầu RPC **rơi về handler offline** khi HTTP hỏng + **nghỉ 30 s** sau một lần hỏng.
2. **Đăng nhập bằng kho cục bộ** khi mất server (3 điều kiện hẹp, không kiểm mật khẩu).
3. Vá lỗi thật `tonumber(x:gsub())` → `base out of range` (nổ trong callback HTTP, im lặng).
4. **Gỡ `G_PotionLogic` khỏi cầu** (client nổ `class.lua:66 table index is nil`).
5. Cổng: `_kiem_cu_phap` **95 · 0** · `_chay_het` **57 tệp · 1290 phép · 0 đỏ**.
   Nghiệm thu hai chiều cùng build: server TẮT **26/26 bước · 5/0/5** · server BẬT **26/26/0**.

## Việc mai, theo thứ tự
1. **Axmol** — phần đã làm 3/11 (`bc/man_login.lua` email + mật khẩu + Đăng ký, băm **MD5 hex**,
   `bc/may_chu/noi_mang.lua`) **chưa nghiệm thu trong app thật**. Chủ dự án dặn để sau.
   Chạy: `kiem/thu_dang_ky.lua` (6/6) · `kiem/doi_chung_noi_mang.py` (26/26) ·
   `kiem/thu_noi_mang.lua` (28/28) · `kiem/_do_neo_noi_mang.py` (26/26).
2. **Chốt world dùng chung LDPlayer ↔ Axmol — ĐÃ CHỐT + LÀM (4/11 tiếp, xem mục cuối tệp).**
   Luật: **chỉ đẩy snapshot khi bản lưu cục bộ không cũ hơn world trên server**
   (`snapshotVersion`); bị từ chối thì cầu KHÔNG ghi, KHÔNG chạy handler, trả `stale`.
3. **Chế độ offline có nên hiện trong game? — ĐÃ LÀM (4/11 tiếp 2, xem mục cuối tệp).**
   `offline/bao_offline.lua` hiện câu báo qua `g_CUIToolTips:AddTipsWithString` 3 giây
   sau khi vào cảnh Main, chỉ một lần mỗi lượt đăng nhập bằng kho cục bộ.
4. **Dọn tài khoản thử — ĐÃ LÀM (4/11 tiếp 3).** Xoá uid `1015–1019`, `1039–1043` (DB + file
   lưu trên máy). GIỮ `1014` (`test.ldp@example.com`, tài khoản thử chuẩn) và `1044`
   (`tk_ui_1793715945`, tài khoản đang chơi). DB còn: `minh` · `ban` · `dev` · `1014` · `1044`.

## Bẫy mới (đã vấp trong lượt này)
- **`tonumber(x:gsub(...))`**: `gsub` trả **HAI** giá trị ⇒ cơ số sai. Luôn bọc ngoặc kép.
- **Nhiều phiên `chay_trace.py` cùng lúc** làm app **kẹt splash** (không phải lỗi game): phải
  `Stop-Process` hết driver cũ rồi `--spawn` đúng MỘT lần. Kiểm: `ps -A | grep buatanew` chỉ 1 pid.
- **Grep log dễ dính dòng CŨ** của lượt trước (vd `THU CAU RPC: KET THUC`) ⇒ chờ sai. Dùng dấu
  hiệu KHÔNG thể có từ lượt trước: **cờ thử biến mất** (`cau_rpc_test.flag`) hoặc chuỗi mới
  (`CHE DO OFFLINE`).
- **Đừng nối một nhóm vào cầu** nếu client không tiêu được phản hồi THÀNH CÔNG — nối = biến lỗi
  trung thực (lớp offline trả mã) thành **crash** (`G_PotionLogic`).
- Đồng hồ trong `offline.log` **lệch +1 giờ** so với `adb shell date` — đừng lấy mốc log để căn giờ máy.

# 🔗 4/11 (tiếp) — CHỐT WORLD DÙNG CHUNG: CHỈ ĐẨY KHI BẢN CỤC BỘ KHÔNG CŨ HƠN

**Quyết định của chủ dự án:** giữ `snapshot` (LDPlayer vẫn đẩy world lên) nhưng **chỉ đẩy
khi world cục bộ không cũ hơn** world đang có trên server. Trước lượt này mỗi lượt
`/api/rpc` đều GHI ĐÈ `worlds.data`, nên chơi Axmol rồi mở LDPlayer bằng bản lưu cũ là
mất tiến độ mới — im lặng, không mã lỗi.

## Cơ chế (cả hai đầu)

- `worlds.version` (Postgres) tăng mỗi lần có người ghi: Axmol qua WebSocket
  (`savePersisted`), hoặc chính cầu khi nhận snapshot.
- Client (`offline/noi_server.lua`) lưu **phiên bản world mà bản lưu cục bộ dựa trên** ở
  `offline_world_v.txt` cạnh file lưu (hai dòng: uid, version) và gửi kèm
  `snapshotVersion` trong mỗi lượt.
- Server (`src/http_api.ts::snapshotCoTheGhi`): ghi khi `snapshotVersion >= worlds.version`.
  `nil` (client chưa biết — lần đầu sau khi nâng cấp) ⇒ chấp nhận **một lần** rồi trả `v`.
  **Cũ hơn ⇒ TỪ CHỐI:** không ghi, **không chạy handler**, trả `{err:1, stale:true, v}`.
  Không chạy handler vì handler tính trên world của server rồi trả Data áp vào bản lưu
  CŨ của client ⇒ lệch trạng thái, im lặng.
- Phản hồi mang `v` = version **SAU** khi handler chạy (handler có thể tự ghi thêm) —
  client lưu số ấy. **Bị từ chối thì KHÔNG lưu `v`**: lưu là lượt sau tự nhận "đã dựa
  trên world mới" rồi đẩy bản cũ đè lên, phá đúng thứ vừa bảo vệ (test ghim thứ tự này).

## Cổng đã chạy

- `npm run test:cau_rpc` (MỚI) **23/23** — 8 ca hàm quyết định + đối chiếu tệp hai đầu.
- `_thu_noi_server.lua` (MỚI) **18/18** trong `_chay_het.py` — đo phần client bằng
  `lua51.dll`: gửi `snapshotVersion`, lưu `v` khi nhận, **không lưu** khi `stale`,
  rơi về handler offline khi HTTP hỏng, nghỉ 30 s.
- `_kiem_cu_phap.py` **95 tệp · 0 lỗi** · `_chay_het.py` **58 tệp · 1308 phép · 0 đỏ** ·
  `run_tests.py` **162 · 0** · server `tsc --noEmit` sạch · `build.py` rồi
  `diff -rq sc/offline deploy/plain/sc/offline` RỖNG.

## ĐÃ ĐO ĐẦU-CUỐI (4/11, Docker + LDPlayer bật)

- **Server (`/api/rpc` qua `curl`/Python, tài khoản tạm):** lần 1 không `snapshotVersion`
  → nhận, `v=2`; lần 2 `snapshotVersion=2` → nhận, `v=3`; lần 3 `snapshotVersion=1` (< 3)
  → `{err:1, stale:true, v:3}`, `worlds.data`/`version` KHÔNG đổi (psql: `1046|3|CAURPC`).
- **Trong game, cầu RPC:** server BẬT, đồ thử `thu_cau_rpc` **26/26/0** (26 gửi · 26 nhận ·
  0 hỏng) qua 4 nhóm + các khoá đã nối; tệp `offline_world_v.txt` được TẠO và bám đúng
  version server (`1044` · `86` → `120`); log client có `… -> err=… cb="…" v=…`, log server
  `[rpc] … -> tay err=… v=…` khớp từng lượt.
- **Trong game, cổng CŨ:** bump server `120 → 121` bằng một lượt `/api/rpc` gửi lại NGUYÊN
  `worlds.data` (đổi mỗi version); mở lại game ⇒ lượt cầu đầu tiên (`G_MailLogic|ClientGetMailList`)
  bị từ chối — server: `snapshot CU (120 < 121) — KHONG ghi, KHONG chay`; client:
  `noi_server: … — WORLD CUC BO CU HON SERVER (v server = 121)`; sidecar VẪN `120`, server
  VẪN `121` (không lượt ghi nào). Game vẫn ở Main, KHÔNG kẹt lớp tải.
- **Bẫy đồ thử:** `thu_cau_rpc` đòi **CẢ HAI** cờ `cau_rpc_test.flag` **VÀ** `cau_rpc_go.flag`
  (`TEP_CHO`) — chú thích ghi "tuỳ chọn" nhưng mã `if not coTepCho() then return end` là BẮT
  BUỘC; thiếu cờ thứ hai thì đồ thử im lặng (đo: chỉ có `thay tep co cau_rpc_test.flag` rồi
  không chạy). Cờ tạo được trong lúc game ĐANG chạy (nó dò mỗi nhịp).
- **Dọn sau khi đo:** xoá uid tạm `1045/1046`; trả `worlds.version` của 1044 về `120` (bằng
  đúng sidecar) để lượt cầu kế không bị coi là cũ; xoá mọi cờ thử trên máy. Game ở Main,
  không còn hiện tượng kẹt.

## Chưa đo (không còn chặn)

- **Chuyển tiếp:** uid 1044 nay ĐÃ có `offline_world_v.txt` (`1044/120`) ⇒ luật ngặt có
  hiệu lực ngay; nhánh "chưa biết ⇒ nhận một lần" chỉ còn áp cho tài khoản chưa từng qua cầu.
- Chế độ offline HIỂN THỊ dưới dạng toast (`g_CUIToolTips`) — không phải dòng chat; nếu muốn
  lưu lại trong khung chat thì phải viết thêm đường chèn bản ghi chat (chat client không có
  lớp logic để gọi, xem mục 4/11 tiếp 2).

# 📢 4/11 (tiếp 2) — HIỆN "ĐANG CHƠI NGOẠI TUYẾN" TRONG GAME

**Vấn đề:** đường lùi "mất server" cho vào game bằng kho cục bộ mà **không kiểm mật
khẩu**; dấu duy nhất là một dòng trong `offline.log` — người chơi tưởng mình đang
đăng nhập qua mạng.

**Tệp MỚI `offline/bao_offline.lua`** (nạp từ `handlers/login.lua`):
- `OfflineBao:dat(lyDo)` — gọi ở nhánh `res.offline == true` của `ClientLogin`.
- `OfflineBao:xoa()` — gọi khi đăng nhập thành công **qua mạng** (không báo nhầm).
- `OfflineBao:hen()` — gọi ở cuối `ClientEnterGame`: hẹn **3 giây** (cảnh Main dựng
  xong) rồi `g_CUIToolTips:AddTipsWithString(CAU)` — chính API client dùng cho mọi
  thông báo ngắn. Không có `S_CCSchedule` thì hiện ngay; thiếu `g_CUIToolTips` thì
  ghi warn và **không ném** (đường đăng nhập không được chết vì một câu thông báo).
- Câu báo: *"Đang chơi NGOẠI TUYẾN: không kết nối được máy chủ. Mật khẩu không được
  kiểm tra; dữ liệu chỉ lưu trên máy này."*
- **Chỉ một lần** mỗi lượt đăng nhập; không có cờ (`lyDo == nil`) thì `hen()`/`hien()`
  đều trả `false` — vào bằng mạng không báo gì.

**Bẫy đã vấp trong lượt:** bản đầu `hien()` chỉ gác `daBao`, quên gác `lyDo == nil`
⇒ mọi lượt vào game qua mạng đều báo "ngoại tuyến" (bộ thử bắt ngay). Và stub
`OfflineLog` trong bộ thử phải khai `function L:warn(m)` (dấu hai chấm) — khai
`warn = function(m)` thì `self` chiếm đối số, nhật ký ghi `table: 0x…`.

**Cổng:** `_thu_bao_offline.lua` (MỚI) **14/14** · `_chay_het.py` **59 tệp · 1322 phép ·
0 đỏ** · `_kiem_cu_phap.py` **96 tệp · 0 lỗi** · `run_tests.py` **162 · 0** · `build.py`
rồi `diff -rq sc/offline deploy/plain/sc/offline` RỖNG.

**ĐÃ ĐO TRONG GAME (4/11, server TẮT):** đăng nhập bằng `dangnhap_cu_test.flag` (uid 1044)
⇒ `tai khoan: HTTP that bai (-1)` → `dang nhap: CHE DO OFFLINE` → `bao offline: dat co` →
`vao game lan 1` → `bao offline: hen hien sau 3 giay` (20:19:46) → `bao offline: da hien
trong game` (20:19:51). Không có lỗi, game vào Main bình thường; lượt cầu `G_MailLogic`
rơi về handler offline đúng như thiết kế.

# 🧹 4/11 (tiếp 3) — CHỐT BÊN LDPLAYER (Axmol tạm dừng theo yêu cầu chủ dự án)

**Chủ dự án chốt trong lượt:** *"làm trên LDPlayer, ngưng bên Axmol"* — nên **dừng** việc
nghiệm thu form đăng nhập Axmol (app đã mở thử, thấy cửa sổ chạy được, nhưng **KHÔNG đo**
gì thêm; tiến trình đã tắt sạch). Phần Axmol vẫn là việc để sau.

**Đã làm xong bên LDPlayer:**
- **Dọn tài khoản thử:** xoá uid `1015–1019` + `1039–1043` trong Postgres (xoá `worlds`
  theo cascade) và xoá `offline_save_<uid>.json` tương ứng trên máy. GIỮ `1014`
  (`test.ldp@example.com`) và `1044` (đang chơi). DB còn **5** tài khoản:
  `minh` · `ban` · `dev` · `1014` · `1044`.
- **Đồng bộ bản mới nhất:** `diff -rq sc/offline deploy/plain/sc/offline` RỖNG rồi
  `deploy.py --push` (5 chỗ) — máy đang chạy ĐÚNG cây nguồn, gồm cả `bao_offline.lua`
  và luật `snapshotVersion`.
- **Kiểm trạng thái:** game ở cảnh **Main**, uid **1044** "UITK", bấm được; `offline.log`
  **0** dòng lỗi ở phiên cuối; `offline_world_v.txt` = `1044/120` **khớp** `worlds.version`
  = `120` (cùng một nguồn) ⇒ lượt cầu kế tiếp KHÔNG bị coi là cũ.

**Trạng thái máy:** Postgres + server `:8787` đang chạy · LDPlayer + game đang mở ở Main ·
không còn cờ thử · `account_last.txt` = `tk_ui_1793715945@example.com` + `1044`.
**Axmol: đã tắt app**, không còn tiến trình `BraveCross.exe`.

# 🎮 4/11 (tiếp 4) — MỞ GAME MỘT CHẠM + TẠO TÀI KHOẢN (KHÔNG CẦN FACEBOOK)

**Vì sao bấm icon không vào được:** launcher của game là activity riêng
(`org.kingsoft.com.R1_OLChina`), nhưng nó gọi **Kull SDK** → mở `KullSDKActivity` (panel
Facebook). Panel ấy gọi `apisdk.kul.vn` — **server của họ đã chết**; bấm "Chơi nhanh"/
Facebook đều không qua. Đó là lý do mọi lượt test phải spawn qua frida để giả
`Userxsdk.login`. **Đăng ký bằng Facebook là BẤT KHẢ** (không có backend xác thực); tài
khoản của bản dựng nằm trong Postgres của server riêng (email + mật khẩu, MD5 hex).

**`mo_game.cmd`** (MỚI) — nháy đúp:
1. kiểm LDPlayer; 2. kiểm server `:8787` (nếu tắt thì tự mở cửa sổ `npx tsx src/index.ts`);
3. `adb root` + khởi động `frida-server`; 4. dừng game cũ + ghi sẵn `dangnhap_cu.txt` +
   `dangnhap_cu_test.flag` (đồ thử điền form bằng `setText`, KHÔNG dùng IME);
5. spawn game + hook SDK ⇒ vào thẳng **Main**, tự đăng nhập.
Sửa `TAIKHOAN` / `MATKHAU` ở đầu tệp để đổi tài khoản; `BX_GIAY` đổi thời lượng driver
(mặc định 86400 s). **ĐÃ TEST:** `THU DANG NHAP CU: OK — vao game (canh Main)`, uid 1044;
cờ tự xoá sau khi dùng.

**`tao_tai_khoan.cmd <email> <mật khẩu>`** (MỚI, + `tao_tai_khoan.py`) — tạo tài khoản qua
`POST /api/register` với **MD5 hex** (cùng hợp đồng LDPlayer/Axmol). ĐO: tạo
`demo_tk_4_11@example.com` → `{ok:true, uid:1200}` rồi **đã xoá** tài khoản demo. Tài khoản
mới mở game lần đầu sẽ vào **màn tạo nhân vật**.

**ĐẨY DỮ LIỆU LÊN SERVER — đã chạy sẵn:** mỗi lệnh thuộc nhóm nối cầu gửi kèm **toàn bộ
world** (41 bảng) trong `/api/rpc`; server ghi `worlds.data` của uid (luật `snapshotVersion`),
chạy handler rồi trả `suKien`/`gui` để client áp. Bằng chứng lượt test: log client
`noi_server: G_MailLogic.ClientGetMailList -> err=0 cb="OnServerGetMailList" v=121`;
`worlds.version = 121`; sidecar `offline_world_v.txt` = `1044/121` (ba số khớp).

**BẪY ĐÃ VÁ (đo sau khi reboot máy ảo):** bản đầu chờ `frida-server` **2 giây** rồi spawn ⇒
`frida.TransportError: the connection is closed` — game mở ra nhưng **kẹt panel SDK** (hook
chưa gắn), log không có dòng nào mới. Nay script **dò `ps -A | grep -q frida-server` tới 20
giây** rồi mới spawn. ĐO LẠI sau reboot: `[be_sdk] da gan hook spawn` ·
`Userxsdk.login -> gia lap dang nhap thanh cong` · `THU DANG NHAP CU: OK — vao game (canh Main)`
· uid 1044 · sidecar `1044/122`.

# 🎓 4/11 (tiếp 5) — HƯỚNG DẪN TÂN THỦ: TÁCH "CHẾ ĐỘ NGƯỜI CHƠI"

**Hiện tượng chủ dự án báo:** mở game bằng `mo_game.cmd` thì hướng dẫn tân thủ "sao sao" —
bong bóng thoại hiện mà kịch bản không đi tiếp.

**Nguyên nhân ĐO ĐƯỢC:** `offline/tu_dong.lua` (module tự động của bộ test) gọi
`g_CGuideLogical:FinishGudie()` mỗi khi `tListener` khác `"GuideShowDialog"` hoặc 10 nhịp
một lần. Log lượt chơi có **68** dòng `tu_dong: dong huong dan (dang cho BattleSelectLevel)`
⇒ kịch bản bị cắt ngay khi vừa hiện, bong bóng hiện lại liên tục.

**Vá:** thêm `OfflineTuDong:laNguoiChoi()` — đọc tệp **`nguoi_choi.flag`** cạnh file lưu.
Có cờ thì **KHÔNG** gọi `FinishGudie`, **KHÔNG** tự bấm "Đi tiếp"; vẫn giữ tự đăng nhập /
vào game / đóng popup thưởng / đóng panel "Nhận cánh" (những thứ không có lối thoát).
`mo_game.cmd` tạo cờ trước khi spawn và **xoá sau khi driver thoát** (bộ test sau không
bị ảnh hưởng). Đường test cũ (không có cờ) giữ nguyên hành vi.

**ĐO LẠI (4/11):** log `tu_dong: CHE DO NGUOI CHOI — khong dong huong dan, khong tu bam thoai`
· KHÔNG còn dòng `dong huong dan` mới · `huong dan cho khoa = BattleSelectLevel` (đứng chờ
người chơi, đúng thiết kế) · bấm nút **Tấn Công** (1795,990) ⇒ mở màn **"Chương 1 Ngô địch"**
và khoá chuyển **`ChapterInfo`** — tức **chạm KHÔNG bị khoá**, kịch bản đi tiếp bình thường.
Cổng: `_kiem_cu_phap` 96 · 0 · `_chay_het` 59 tệp · 1322 phép · 0 đỏ · `run_tests` 162 · 0.

# 🛠 4/11 (tiếp 6) — PANEL "BỘ THAO" LÀM ĐỨNG GAME: VÒNG LẶP `initUserDataFromDB`

**Triệu chứng:** chơi tới bước hướng dẫn mở panel thương nhân ("Bộ Thao" / `CUITourMerchant`,
chính `CGuideScheme.lua:3149` mở) thì game **đứng**. Log phình **+500 KB/phút**:

```
initUserDataFromDB: GameUserCloudShop   (~50 dòng/giây)
```

**Nguyên nhân ĐO ĐƯỢC (hai lớp, phải sửa CẢ HAI):**
1. Panel gọi `getLeftStandingTime` **mỗi khung hình** → `GetUserDataWithName("GameUserCloudShop")`.
   Bản vá cũ trả `0, {}` rồi để **chỗ gọi** tự gán lại vào `userData`; đường
   `CClientDataManager` đi qua **proxy lớp cha** (`self[CDataManager]`) nên lần sau vẫn thấy
   `nil` ⇒ gọi lại mãi ⇒ ngập log.
2. `ClientTourMerchantLogic.lua:57` **cộng thẳng** `tUserCloudShop.ComeTime`; `{}` ⇒
   *"attempt to perform arithmetic on a nil value"* mỗi khung hình.

**Vá (`offline/init.lua::patchDataManager`):**
- GHI THẲNG khoá vào `mgr.userData` ngay trong hàm vá (không trông vào chỗ gọi);
- `HINH_AN_TOAN = { GameUserCloudShop = { ComeTime = 0 } }` — "chưa có thương nhân đứng",
  đúng nhánh `tUserCloudShop == nil` của chính client (`:54-56`, trả 0); các trường khác
  client đã tự gác nil;
- nhật ký **một dòng/giây/tên**, và nếu lặp ≥ 20 lần/giây thì ghi MỘT `debug.traceback`
  (chẩn đoán cho lượt sau, không phải hành vi).

**ĐO LẠI:** đồ thử MỚI `offline/thu_merchant.lua` (cờ `thu_merchant.flag`) mở đúng đường
`g_CUINormalDlg:Show("CUITourMerchant", nil)`. Kết quả: `THU MERCHANT: mo panel Bo Thao -> true`
· **đúng MỘT** dòng `initUserDataFromDB: GameUserCloudShop` lúc mở · **12 giây sau KHÔNG thêm
dòng nào** · panel "Thương nhân" hiện bình thường (Binh Pháp ×5899) · game bấm được.
Cổng: `_kiem_cu_phap` **97 · 0** · `_chay_het` **59 tệp · 1322 phép · 0 đỏ** · `run_tests` **162 · 0**.

# ✅ 4/11 (tiếp 7) — QUÉT TOÀN BỘ TÍNH NĂNG: 21/21 PANEL + VÁ MA ĐỘNG

**Cách quét:** đồ thử `luot_panel` nay bật bằng CỜ `luot_panel.flag` (không phải sửa mã):
mở lần lượt **21 lối vào** của cảnh Main bằng ĐÚNG hàm nút bấm gọi, mỗi panel 6 nhịp rồi đóng.

**Lượt 1 (trước vá): 20/21.** Panel 06 **Ma Động** ném
`CUICavern.lua:330: attempt to index field 'CurrentDefender' (a nil value)`.
Nguyên nhân: `GameUserCavern` do cầu/server dựng có `ProgressState = 0` (Fight) nên UI đi nhánh
`:325-331` và đọc `CurrentDefender` — trường này **hàm tạo gốc cũng không có**
(`CavernDataManager:CraeteUserCavern`), nó là trạng thái trận do MÁY CHỦ sinh.
**Vá:** bọc `G_CavernDataManager:GetUserCavern` — bảo đảm `CurrentDefender = {}` khi vắng
(UI gặp `[1] = nil` thì `goto Exit0`, panel vẫn vẽ). ⚠ **BẪY `vtbl`:** bọc trên **bảng lớp**
`CavernDataManager` là **trượt im lặng** (lớp giữ phương thức trong `vtbl` ẩn; lớp thật là
`ClientCavernDataManager`) — phải bọc trên **thực thể** `G_CavernDataManager`.

**Lượt 2 (sau vá): 21/21 OK**, log `luot panel: XONG 21/21`, **0 dòng `THIEU`**, **0 lỗi**
ERROR/LOI trong lượt. Hướng dẫn vẫn đi tiếp bình thường (`BattleSelectLevel → ChapterInfo`).

**Tổng kiểm "tất cả tính năng" (4/11):**
| lớp | kết quả |
|---|---|
| Cú pháp Lua | `_kiem_cu_phap` **97 tệp · 0 lỗi** |
| Phép kiểm lớp offline | `_chay_het` **59 tệp · 1322 phép · 0 đỏ** |
| Bộ thử PC | `run_tests` **162 · 0** |
| Độ phủ RPC | `_con_lai` **73 khoá thiếu / 571**; `_phan_loai_toancuc --tat-ca` ⇒ **0 KHOÁ CÒN SỐNG** |
| Server | **47/48 xanh** (`noi_mang` qua driver **17/17**) |
| Trong game | **21/21 panel** · cầu RPC **26/26** · đăng nhập/tạo tài khoản · báo ngoại tuyến · hướng dẫn tân thủ |

**Chưa phủ (khai rõ):** lượt quét chỉ chứng minh panel MỞ được; từng nút BÊN TRONG panel do
bộ thử tĩnh phủ (1322 phép). Đồ thử `thu_nhom_moi` (tự kiểm handler) **không chạy** trên tài
khoản đang chơi vì nó **không idempotent** (kích hoạt thẻ tháng +30 ngày mỗi lượt) — muốn chạy
thì dùng tài khoản thử riêng.

# 📱 4/11 (tiếp 8) — VÁ APK: BẤM ICON LÀ VÀO (KHÔNG CẦN FRIDA)

**Mục tiêu (chủ dự án chốt):** mở game trực tiếp bằng icon trên LDPlayer.

**Vá gì:** `org.cocos2dx.plugin.Userxsdk.login()` — thân cũ gọi `SDKHandler.loginVI()`
(mở `KullSDKActivity`, panel Facebook gọi `apisdk.kul.vn` đã chết). Thay bằng đúng lời gọi
mà frida vẫn làm: dựng `JSONObject` `{UserID:100001, UserName:offline, AccessToken, SessionID}`
rồi `onLoginSuccessCallback(0, json)`.

**Công cụ + cách dựng lại (đã chạy):**
```
_tools/apktool.jar d -f -o apk_giai apk-vn/com.cmn.buatanew.apk
# sửa smali/org/cocos2dx/plugin/Userxsdk.smali  (method login())
_tools/apktool.jar b -o patched_unsigned.apk apk_giai
_tools/uber-apk-signer.jar -a patched_unsigned.apk     # v1+v2+v3, debug key
```
APK ký: `_tools/patched_unsigned-aligned-debugSigned.apk` (43,99 MB).

**CÀI ĐẶT (đã làm, kèm sao lưu):** sao lưu `/data/user/0/com.cmn.buatanew/{files,shared_prefs,
databases}` → `/sdcard/bc_backup_data.tar` (18,1 MB) và OBB → `/sdcard/bc_backup_obb` (199 MB);
`adb uninstall` → `adb install -r` → giải nén tar + `chown 10066` + `restorecon` → chép OBB về.
⚠ **Uid đổi sau cài lại** (10065 → **10066**) — mọi `chown` phải dùng uid MỚI.
⚠ **Quyền bộ nhớ ngoài bị thu hồi khi cài lại** (targetSdk 23): phải
`pm grant … READ/WRITE_EXTERNAL_STORAGE`, nếu không lớp offline (nằm ở
`/storage/emulated/0/assets/sc`) **không nạp**.

**HAI LỖI LUA PHẢI VÁ CÙNG LƯỢT** (nếu không, icon vẫn kẹt “Mất kết nối server”):
1. **`CUILogin:startLogin`**: bản gốc đặt `bChannel=true` rồi
   `RepaleceSceneWithoutLoading("Login")` → `showUI` → `callLoginRPC` (nối
   `vilogin.czgame.net:8530`, chết) **NGAY TRONG HÀM**. Bản bọc cũ đặt `bChannel=false`
   SAU khi hàm trả về ⇒ quá muộn. Nay **KHÔNG gọi bản gốc**: đặt `bChannel=false`, xoá
   session kênh, thay cảnh Login.
2. **Cảnh Login NẠP HAI LẦN** (cùng họ bẫy `nap_lai_dialog.lua`): node của cây PRELOAD
   cũng báo `isVisible()==true` ⇒ mở form một lần rồi tưởng xong là màn tiêu đề đứng
   nguyên. Nay `tick` **thử mỗi giây trong 20 giây**; `moForm` **chỉ điền email khi ô
   đang RỖNG** (không đè chữ người chơi gõ).

**ĐO ĐƯỢC (không frida):** bấm icon → không còn activity `KullSDKActivity`
(`dumpsys activity` chỉ có `R1_OLChina`) → form **“TK đăng nhập”** (email điền sẵn) →
`THU DANG NHAP CU: OK — vao game (canh Main)` (23:48:58), uid 1044, ảnh `_icon9.png`.
**BÀI HỌC CÔNG CỤ:** đừng `cp -r` đè cả cây `files/assets/sc` bằng bản chỉ có lớp offline —
cây gốc 973 tệp nằm ở đó; chỉ **đè thư mục `offline/`**.

# 🔁 4/11 (tiếp 9) — VÒNG LẶP `GameUserCloudShop` TRÊN CẢNH MAIN (VÁ THỨ TỰ TU_DUNG/HINH_AN_TOAN)

**Triệu chứng ĐO được** (log lượt 22:53, uid 1201): `offline.log` ghi
`initUserDataFromDB: GameUserCloudShop` **mỗi giây**, kèm `WARN … LAP >=20 lan/giay` suốt 13 giây;
traceback chỉ đúng chỗ gọi: `CUIMain.lua:741` → `CUIMainBuildingManager:refreshDyncBuilding` →
`ClientTourMerchantLogic:isLeftStandingTime` → `getLeftStandingTime` → `GetUserDataWithName`.
Cả file log có **7.150** dòng `initUserDataFromDB: GameUserCloudShop`.

**Nguyên nhân:** bản vá 4/11 (tiếp 6) thêm `HINH_AN_TOAN.GameUserCloudShop = { ComeTime = 0 }`
để trả hình AN TOÀN, NHƯNG nhánh `TU_DUNG` `return 0, nil` đứng **TRƯỚC** ⇒ `HINH_AN_TOAN`
không bao giờ chạy. Mà `GetUserDataWithName` chỉ cache khi giá trị KHÁC nil
(`share_CDataManager.lua:225`) ⇒ khung hình sau lại thấy nil, lại gọi init — đúng vòng lặp mà
tiếp 6 định chặn. Đồ thử cũ chỉ MỞ PANEL (cảnh Main tạm dừng) nên không thấy.

**Vá:** `init.lua::patchDataManager` — tính `hinh` TRƯỚC; `TU_DUNG` chỉ trả nil khi bảng KHÔNG
có `HINH_AN_TOAN`. Đã kiểm cả **năm** chỗ đọc `GameUserCloudShop`
(`getLeftStandingTime` :50 · `getTourMerchantStatus` :110 · `isGoodsSoldOut` :174 ·
`CUITourMerchant:_initData` :179 · `share/share_CloudShopDataManager.lua`): bảng
`{ ComeTime = 0 }` cho kết quả Y HỆT nhánh nil ("chưa có thương nhân đứng"), và **an toàn hơn**
ở hai chỗ panel đọc thẳng trường (nil sẽ ném). Khác biệt duy nhất: bảng thì CACHE được.

**ĐO LẠI TRONG GAME (cùng build, APK vá, KHÔNG frida):**
- Vào Main bằng tài khoản thử 1044: **đúng 1** dòng `initUserDataFromDB: GameUserCloudShop`
  lúc nạp, rồi **0** dòng trong 40 giây đứng ở Main; **0** `LAP >=20`.
- `luot_panel` (cờ `luot_panel.flag`, tự xoá): **21/21 OK**, gồm **18/21 ThuongNhan**
  (panel Bộ Thao — đúng chỗ dùng `GameUserCloudShop`), **0** `LOI`, **0** `THIEU`.
- File lưu `offline_save_1044.json` có `"GameUserCloudShop":{"ComeTime":0}`.

**Cổng:** `_kiem_cu_phap` **97 · 0** · `_chay_het` **59 tệp · 1322 phép · 0 đỏ** ·
`run_tests` **163 · 0** (đổi 1 kỳ vọng `nil → {ComeTime=0}` + thêm 1 phép: TU_DUNG không có
HINH_AN_TOAN vẫn trả nil) · `build.py` → `diff -rq sc/offline deploy/plain/sc/offline` RỖNG ·
`deploy.py --push` 5 chỗ.

**Việc còn lại của bàn giao 4/11:** chạy `thu_nhom_moi` trên **tài khoản thử riêng**
(không idempotent, +30 ngày thẻ tháng mỗi lượt) — lần này mới chỉ chạy `luot_panel`.

# 🧪 4/11 (tiếp 10) — CHẠY `thu_nhom_moi` TRÊN TÀI KHOẢN THỬ (việc còn treo của lượt 4/11)

Trước đó đồ thử này **chưa từng chạy** vì nó không idempotent (mỗi lượt +30 ngày thẻ
tháng) — nay chạy trên **uid 1044** (`tk_ui_1793715945@example.com`, tài khoản thử chuẩn),
cờ `selftest.flag`, không frida (APK đã vá).

**Kết quả: chạy TRỌN tới `THU ===== het tu kiem =====` trong ~1 giây, 0 lỗi Lua**
(không có `THU: tum lum loi`, không có `THIEU`). Các nhóm mới đều trả đúng hình:
- 31/10: trận pháp **5102** (thiếu nguyên liệu) · thời trang **3305** · luyện hero `0` →
  `Statistics.OnPracticeHero` · thẻ tháng `1 → true → 0` · tích luỹ nạp/tiêu **4001** (đóng) ·
  quỹ cấp **4007** (hết bậc) · quà 7 ngày **3203** (đã nhận hôm nay) · kim thủ 1 lượt
  (KC 5, vàng +6000, hệ số 3) · BXH 5 tướng + 3 bảng PvE `0` · mua vật phẩm −50 KC ·
  tinh luyện +1 cấp · luyện vật phẩm 1→0 (+1 tinh hoa) · thiên mệnh +1 (mảnh 52→49) ·
  mảnh vạn năng 5→0 (mảnh tướng 49→54) · trang phục độc quyền · võ hồn 0→1 · phụ đề 2 dòng ·
  tên ngẫu nhiên có dấu đúng.
- Nhóm nhiều người (mô hình tối thiểu): bang hội tạo/đọc OK (GuildId 877759) · BXH quân đoàn
  1 dòng · công thành `QueryScore/CheckCanChangeTeam` true · bang hội nâng cao (thuê −15000
  vàng, xúc xắc 6 mặt, điều tướng) · phó bản bang trọn 5 bước (boss 35638309→0, 6 món rơi) ·
  đấu trường điểm (state 5, 6 đối thủ, hạng 1001, tranh 5500) · BXH chế độ **6/6 khoá** ·
  ải đặc biệt/ải vô tận/epic/doanh trại đều trả hình.
- Hai mã **không phải lỗi**, log đã giải thích ngay cạnh: `1430` (mục tiêu ải chương 1 mốc 3
  chưa đạt — trạng thái 0) · `5003` (thần binh: tướng cấp 1 < 37).

**Một WARN đúng thiết kế:** `noi_server: G_AchieveLogic.ClientReachAchieve — WORLD CUC BO CU
HON SERVER (v server = 145)` — cổng world dùng chung 4/11 từ chối đẩy snapshot cũ; handler
cũng không chạy. Đây là hành vi ĐÃ CHỐT, không phải lỗi của đồ thử.

**Dọn:** `selftest.flag` + `nguoi_choi.flag` đã xoá; sidecar `1044/145`; game ở cảnh Main
(panel BXH do đồ thử mở — BACK/`input tap` không đóng được, đúng bẫy UI đã ghi, không phải lỗi).

# 🗡️ 4/11 (tiếp 11) — TRANG BỊ ĐỘC QUYỀN: ĐÚC + TINH LUYỆN

Hai lệnh client nằm trong lớp chắn `chua_ho_tro.lua` và **có UI sống** — nay làm thật:

| khoá | UI gọi từ | trước |
|---|---|---|
| `G_EquipmentLogic.ClientForgingExclusiveEquip(heroID, part)` | `CUIEquipment_Refine:onTouchEnd_OnMakeForgeExclusive` (`:1713-1760`) | mã 1 |
| `G_EquipmentLogic.ClientPurifyExclusiveEquip(heroID, part)` | nút tinh luyện khi `EquipRefineType.IsExclusive` (`:607`) | mã 1 |

**Dữ liệu THẬT (ship trong game):** `KDBGameExclusiveEquipConfig.json` 5 bảng con —
`ExclusiveEquipHeroConfig` (22 tướng) · `ExclusiveEquipForgeConfig`
(`[hero][part] = {ItemList, PurifyLevel}`) · `ExclusiveEquipPurifyConfig` (5 phần × 21 cấp)
· `ExclusiveEquipCommonSkillConfig` · `ExclusiveReelSaleConfig`. Đọc bằng đúng hàm config
manager (`GetExclusiveEquipHeroConfig/ForgeConfig/PurifyConfig`).

**Luật** (ba nguồn độc lập, chi tiết ở đầu `handlers/trang_bi_doc_quyen.lua`):
- Đúc: tướng ∈ danh sách (**1330** nếu không) → ô đồ có (**1106**) → chưa độc quyền (**1116**)
  → chất lượng `>= QualityKey.Red+1 = 6` (**1117**) → **tinh luyện THƯỜNG phải đầy** (UI chỉ
  hiện nút đúc ở trạng thái `UpgradeExclusive`, tức `RefineLevel >= 5` — `getEquipState:965`)
  → đủ nguyên liệu (**1201**; trừ nguyên tử, hỏng thì hoàn) → **riêng VŨ KHÍ cần 4 món kia
  đã độc quyền** (**1115**, `GetCanMakeForgeExclusive:1877-1923`) → `SetEquipIsExclusive` →
  `updateEquipData` (thuộc tính đổi sang bảng purify).
- Tinh luyện: phải độc quyền (**1111**) → phần có cấu hình (**1112**) → chưa tối đa (**1113**) →
  đủ tinh hoa (**1109**) → `SetEquipRefineLevel(cấp+1)` + `updateEquipData`.

**HAI BẪY ĐÃ TRÁNH (đo từ chính client, không suy đoán):**
1. **Bảng purify đánh khoá 0-based** (`updateGameExclusiveEquipConfig` gán `[nLevel-1]`), và
   **khoá = `RefineLevel`** — thuộc tính (`share_EquipmentPropertyLogic.lua:147`) và UI
   (`CUIEquipment_Refine.lua:1129`) đều đọc `[RefineLevel]`; **cấp kế = `[RefineLevel+1]`**.
   Toán tử `#` trên bảng 0-based KHÔNG xác định ⇒ cấp tối đa đếm bằng `pairs`.
   Đo: đúc xong giữ `RefineLevel = 5` ⇒ +50% (thường cấp 5 chỉ +25% — đây là phần thưởng độc quyền).
2. **Giá tinh luyện đi qua `HeroLogic:GetUpgradeRefineCost`** — ĐÚNG hàm UI dùng để HIỂN THỊ
   (`:1171`), nên số hiện = số trừ (VIP10 giảm 20%).

**ĐO TRONG GAME (tài khoản thử 1044, APK vá, không frida)** — đồ thử
`offline/thu_doc_quyen.lua`, cờ `thu_doc_quyen.flag`:
- Cấu hình đọc được: **22 tướng · bảng đúc · bảng tinh luyện**.
- Thêm tướng 10, tạo ô bộ phận 2 (chất lượng 6, tinh luyện thường 5), cấp 5+5 nguyên liệu.
- `đúc -> ma=0 · IsExclusive=true` · `đúc lần hai -> ma=1116` ·
  `tinh luyện -> ma=0 · RefineLevel 5→6 · tinh hoa 1961→761 (trừ 1200)`.
- File lưu: `GameUserEquipment["10"]["2"] = {IsExclusive=true, RefineLevel=6, Quality=6}`,
  nguyên liệu 127/89 về 0. **Bản lưu thử giờ có thêm tướng 10 + món độc quyền** (tài khoản thử).

**Cổng:** `_kiem_cu_phap` **99 tệp · 0 lỗi** · `_chay_het` **60 tệp · 1352 phép · 0 đỏ** ·
`run_tests` **163 · 0** · bộ thử mới `_thu_trang_bi_doc_quyen.lua` **30/30** · lớp chắn còn
**82 khoá** (bộ thử lớp chắn đổi kỳ vọng 84 → 82).

# 📋 KIỂM KÊ TÍNH NĂNG CÒN DỞ (sau 4/11 tiếp 11)

Nguồn: `_con_lai.py` (73 khoá THIẾU nhưng **0 SỐNG**), `chua_ho_tro.lua` (82 khoá SỐNG bị chắn),
`_tim_port_duoc.py` (0 ứng viên còn lại), README các mục "chưa làm".

**A. KHÔNG THỂ làm offline thật (cần nhiều người/máy chủ khác/dịch vụ ngoài):**
giải đấu `G_TournamentLogic` (16) · `G_WCSProtocol` (13) · chiến trường trạng thái (2) ·
chợ mây `G_CloudShopLogic` (2) · cửa hàng bang hội (1) · đỏ bao bang (2) · nạp tiền SDK (6) ·
QQ/WeChat (5) · bình luận (1) · mã đổi thưởng (1) · liên kết kênh (1).

**B. Hoạt động do máy chủ VẬN HÀNH — cần viết lịch/dữ liệu [MOI]** (không có trong cấu hình ship):
`ActivityRank` (4) · `Wushuang` (2) · `ActivityShopping` (2) · `ObjExchange` (2) ·
`WealthGod` (2) · `GodHero` (1) · `FreeStrength` (1) · `WeeklyFun` (1) · `TimeHero` (1) ·
`SingleRecharge` (1) · `RechargeSign` (2) · `ActivityFightCap` (1) · `Anniversary` (1) ·
`Adventure` (1) · `ServerTournamentPrize` (1).

**C. 0 thân hàm trong `share/` — phải VIẾT MỚI hoặc cần dữ liệu chưa ship:**
~~nâng cấp/tự động cánh~~ **ĐÃ LÀM 5/11** (chép luật từ bản Axmol — xem mục "4/11 (tiếp 12)") ·
hộp Thần Binh (2 — không có bảng hộp/giá) · bán đồ độc quyền thừa (1 — có
`ExclusiveReelSaleConfig`, nhưng nút gọi chỉ nằm trong panel giải đấu/WCS) · thuốc (1 — hệ
chết trong bản gốc) · kích hoạt skin độc quyền (`ClientGetHeroExclusiveSkin` — nút bị
`do return end` ngay trong client ⇒ mã chết).

**D. Axmol:** phần đăng nhập MD5 hex đã làm 3/11 nhưng **chưa nghiệm thu trong app** (chủ dự án
dặn để sau).

# 🪶 4/11 (tiếp 12) — CÁNH: TIẾN CẤP (chúc phúc) + CƯỜNG HOÁ

Bốn lệnh `CUIWing` có UI sống: `ClientUpgradeWing` · `ClientUpgradeWingWithDiamond` ·
`ClientIntensifyWing` · `ClientAutoIntensifyWing` (`handlers/canh.lua`). Luật **chép nguyên**
khối CÁNH trong `bravecross-ax/Content/src/bc/may_chu/handler/duong_choi.lua:560-1030` —
bản chủ dự án đã chốt 19/10/2026 sau khi đọc tip gốc:

- Đọc chúc phúc ĐANG HIỆN; thanh đầy (`>= MaxBlessing`) ⇒ lượt này **CHẮC CHẮN**.
- Chưa đầy ⇒ `p = EffectivePercent + (1-EffectivePercent) * blessing/MaxBlessing`.
- **THẤT BẠI mới cộng** `ceil(MaxBlessing * EffectivePercent / 2)`; THÀNH CÔNG ⇒ cấp +1, chúc phúc 0.
- Chúc phúc **reset 5:00 mỗi ngày** (khoá riêng `WingBlessingDay` trong `GameUserGlobalData`).
- Nâng bằng kim cương: trả `CostDiamond`, **chắc chắn thành công**.
- Cường hoá: `GameWingIntensifyConfig[cấp+1].StoneCost` đá 101; **trần = CẤP NGƯỜI CHƠI**
  (`CUIWingEnhance:isEnhanceLevelOverUserLevel:1924` + `getCanEnhanceLevelAndWingStoneNum:1952`).

**HAI BẪY ĐÃ VẤP TRONG LƯỢT (cùng họ "hàm trả nhiều giá trị"):**
1. `pcall(function() return GetHeroWithID(id) end)` — `GetHeroWithID` trả `(bResult, hero)`,
   `pcall` gói thêm ⇒ phải nhận **BA** giá trị; nhận hai thì `hero` là boolean ⇒ mọi lượt 1301.
2. `GetUserGlobalData` cũng trả `(bResult, giá trị)` — đọc hai giá trị thì `tonumber(true)=nil`
   ⇒ chúc phúc **reset mỗi lượt** (bộ thử bắt: "cùng ngày 5:00 → 5→2 thay vì 5→7").

**ĐO TRONG GAME (tài khoản thử 1044, cờ `thu_canh.flag`):** cấu hình `UpgradeWingConfig` 13 ·
`HeroWingConfig["1"]` 14 cấp · `GameWingIntensifyConfig` 99 dòng. Thêm cánh 1 cấp 1 cho tướng 25,
cấp 20 đá 102 + 10 đá 101. Kết quả 5 lượt: `that bai (+2) → thanh cong → thanh cong → that bai (+6)
→ that bai (+6)`, đá 102 `20 → 7` (2+2+3+3+3). Cường hoá tự động lên **cấp 1 = trần người chơi**,
lượt hai **1328**; kim cương thiếu **504**. File lưu: `WingLevel=3, WingBlessing=12,
WingIntensifyLevel=1`, đá 101 `10→9`.

**Cổng:** `_kiem_cu_phap` **101 tệp · 0 lỗi** · `_chay_het` **61 tệp · 1381 phép · 0 đỏ** ·
`run_tests` **163 · 0** · bộ thử mới `_thu_canh.lua` **29/29** · lớp chắn còn **80 khoá**.

# 💳 4/11 (tiếp 13) — DỊCH VỤ NGOÀI: MÃ ĐỔI THƯỞNG · BÌNH LUẬN · NHẬN NẠP

Ba khoá trước đây nằm trong lớp chắn (mã 1) nay **làm thật**, dùng API của server riêng (`:8787`):

- `G_RedeemCodeLogic|ClientUseRedeemCode` → `handlers/ma_doi.lua` → `POST /api/redeem`.
  Thành công: cộng KC bằng `G_UserLogic:AddDiamond`, phát vật phẩm bằng
  `G_ChapterLogic:SetDataWithPrizeList(items, 1, "UseRedeemCode")`, báo UI bằng
  `OnServerUseRedeemCode{nServerErrCode, nClientErrCode, RetData}` — đúng hình mà
  `CUIRedeemCode:OnUseRedeemCode` (`:132-190`) đang đọc.
- `G_GameCommentLogic|ClientCommentGame` → `handlers/binh_luan.lua` → `POST /api/comment`
  (client gửi **KHÔNG đối số**, chỉ bật lớp tải).
- `offline/nap_api.lua` → gọi ở cuối `ClientEnterGame` (**một lần/phiên**): `POST /api/recharge/claim`,
  cộng bằng `OfflineNap:cong(kc, kc)` — đi đúng đường GM nạp nên cập nhật luôn nạp-đầu / nạp-liên-tục /
  quà-tân-thủ. `[MOI]` coi 1 KC = 1 đơn vị tiền nạp (API chỉ biết số kim cương).

**Hành vi đã chọn (không bịa):** máy không có HTTP ⇒ mã đổi trả **2405** ("không tồn tại", như bản
gốc không có kho mã), bình luận bỏ qua nhưng **vẫn đóng lớp tải**; chưa đăng nhập ⇒ **2403**
(`GetRedeemCodeFail`). Lớp chắn còn **78 khoá**.

**Đo:** `_kiem_cu_phap` **104 tệp · 0 lỗi** · `_chay_het` **62 tệp · 1403 phép · 0 đỏ** ·
`run_tests` **163 · 0** · bộ thử mới `_thu_api_nap.lua` **22/22** · server `npm run test:nap_api`
**16/16** (cần server + Postgres). Đã `build.py` + `deploy.py --push` 5 chỗ.

**CHƯA CHẠY TRONG GAME** (repo server cấm tự khởi động game). Nghiệm thu tay:
1. `curl -X POST http://127.0.0.1:8787/api/redeem/create -H "content-type: application/json" -d '{"code":"THU500","diamonds":500,"max_uses":3}'`
2. Mở game → Tuỳ chọn → nhập `THU500` → phải cộng 500 KC (và báo lỗi đúng nếu nhập lại).
3. `curl -X POST http://127.0.0.1:8787/api/recharge -H "content-type: application/json" -d '{"uid":<uid>,"diamonds":200}'`
   → thoát/vào lại game → toast "Nạp thành công: +200 kim cương", rồi gọi lại `claim` bằng curl
   phải thấy `kc: 0` (đã nhận).

# 📝 4/11 (tiếp 14) — NHẬT KÝ HÀNH ĐỘNG (nền cho nhóm hoạt động "máy chủ vận hành")

`offline/hanh_dong.lua`: `OfflineHanhDong:ghi(kind, key, value)` gửi `POST /api/event` (server
riêng) — **không bao giờ chặn game**: không có tài khoản / không có `sngHttpRequestWithString`
thì im lặng trả `false`; mỗi `kind` tối đa một lượt mỗi **2 giây**; mọi lỗi HTTP đều bị nuốt.
Đã nối ba chỗ: **vào game** (`login/enter`, cuối `ClientEnterGame`) · **đổi mã thành công**
(`redeem/<mã>`) · **nhận khoản nạp** (`recharge/claim`).

Server dựng kèm động cơ hoạt động: bảng `activities` (lịch `daily` / `weekly` theo thứ /
`range`), `activity_claims` chống nhận hai lần ở khoá chính, `GET /api/activities?uid=` trả
`open` + `day_key` (mốc **5:00**) + `claimed`, `POST /api/activity/claim` trả `{diamonds, items}`
để lớp offline tự áp (như mã đổi). Chi tiết + số đo ở README của `bravecross-server`
(mục "5/11 (tiếp) — ĐỘNG CƠ HOẠT ĐỘNG").

**Đo:** `_kiem_cu_phap` **105 tệp · 0 lỗi** · `_chay_het` **63 tệp · 1413 phép · 0 đỏ** ·
`run_tests` **163 · 0** · bộ thử mới `_thu_hanh_dong.lua` **10/10** · server
`test:hoat_dong_api` **19/19** + `test:nap_api` **16/16** · tsc sạch. Đã `deploy.py --push` 5 chỗ.

**Chưa chạy trong game** (repo server cấm tự bật game). Khi bạn mở game: log `offline.log` có
dòng `hanh dong: da noi nhat ky`; bảng `user_events` sẽ có `login` mỗi lần vào cảnh Main —
kiểm bằng `curl "http://127.0.0.1:8787/api/events?uid=<uid>&limit=5"`.

# 🏆 4/11 (tiếp 15) — SERVER ĐÃ CÓ GIẢI ĐẤU (mục A, phần máy chủ)

Server riêng có **động cơ giải đấu** (mô hình `[MOI]`, `bravecross-server/src/tournament.ts`):
bốn bảng (`tournaments` · `tournament_entries` · `tournament_matches` · `tournament_claims`) +
bảy endpoint (`/api/tournament/create|register|start|tick|claim` và `GET /api/tournament?id=&uid=`,
`GET /api/tournaments`). Sức mạnh xếp hạt giống dùng đúng chuỗi chiến lực 5 tướng đã port; mỗi vòng
chạy sau `round_seconds`; acc không online vẫn được máy chủ **tự đánh** (băm ổn định, 15% lật kèo);
thưởng nhất/nhì/ba nhận một lần (khoá chính CSDL).

**Đo:** `npm run test:tournament_api` **20/20** (3 suất → bracket 4 + 2 vòng, bye, tick 3 trận,
idempotent, 500/250/100 KC, 4007, cascade) · `test:nap_api` 16/16 · `test:hoat_dong_api` 19/19 ·
`tsc` sạch · `test:do_phu` 0 đỏ.

**Chưa nối vào client:** 16 khoá `G_TournamentLogic` (và 13 khoá WCS) vẫn là lớp chắn — màn giải
đấu trong game cần đọc giao thức `CUITournament*` (bracket/quiz/playback) rồi mới trả lời được.
Lớp chắn vẫn **78 khoá**.
