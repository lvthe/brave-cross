# Ghi chú phiên trace — 26/10/2026 (dừng để làm tiếp)

Mục tiêu phiên: chạy **trace trên máy ảo ARM** để đo **chỗ đứng + đường đi** của bản
gốc (bản dựng đang cãi nhau với người dùng ở hai điểm: đội hình "dồn cục" và "chạy quá
xa").

Nối tiếp `GHI-CHU-TRACE-2026-10-23.md` (đã phá cổng SDK, chưa có số đo).

---

## 1. ĐÃ XONG trong phiên (phần chắc chắn, có cổng)

Code bản dựng (không liên quan máy ảo) — chi tiết ở `bravecross-ax/CLAUDE.md`,
GHI CHÚ 25/10 *"TƯỚNG: TRƯỚC/GIỮA/SAU … VÀ TẦM BẮN BỊ NUỐT KHI PORT"*:

1. **Tướng CÓ trước/giữa/sau** = `PlacementType` (1/2/3 = bốn tab "Tất Cả · Trước ·
   Giữa · Sau" của màn bố trí gốc). **KHÔNG** phải `Location`/`AttackLocation` (cả
   92/92 tướng để **0**). Thứ tự đứng trên sân vẫn là `<sPriority>` của `hero_config`.
2. **16 trường tướng bị bộ sinh cũ nuốt** (`MaxAttackDistance`, `NpcSize`,
   `PlacementType`…) — nay bù bằng `build/_sinh_hero_bo_sung.py` (71/71 tướng,
   1.136 trường).
3. **Tách hai loại tầm**: `u.reach` = cổng ra đòn (`nMaxAttackDistance`), `u.dung` =
   chỗ dừng (`ptConfrontDistance` / công thức `vfunc_192` + `fRemoteCoverRatio`).
4. Lỗi chủ công (`Player000M03W` không có mục `move_ref`) bị xếp lớp cận chiến — đã sửa.

**Số đo sau khi sửa** (ải `L_N_01_01`, 5 tướng, `kiem/_do_di_chuyen.lua`):
hàng rộng nhất **440 px** mọi khung; cặp đồng đội khít nhất **33,5 px** lúc t=3,20 là
**hai tướng cận chiến** (LiuBei 1064 · ZhaoYun 1031, cách địch 72/106 px); cự ly ăn đòn
**trung vị 149,8 px · p75 746** (trước khi sửa: 81,5 / 87,8). Cổng trận **12/12 XANH**,
Lua **213/213**.

---

## 2. CÔNG CỤ TRACE (mới, dùng được ngay)

| tệp | việc |
|---|---|
| `frida/trace_vitri.js` | hook 4 hàm, **đã kiểm từng địa chỉ là ĐẦU HÀM Thumb** trên `libgame.so` thật (`sodis.py`): `0x386efc` · `0x38711c` · `0x38729c` (ba hàm **dàn X**, đọc vector đơn vị `+0x20c`/`+0x1bc`/`+0x200` → `x/y/priority(+0x1f0)/tầm(+0x6d0)/AttackLocation(+0x3b8)`) và `0x413a98` (`vfunc_185`, mỗi nhịp dời: `sprite = +0x17c`, `mục tiêu = +0x1c0`) |
| `frida/phan_tich_vitri.py` | đọc `trace_danh.out.jsonl` → bảng dàn trận, quãng đi, độ dồn, phân bố `dist` |
| `_trace_vitri.ps1` | driver: chờ boot → chờ PM → cài APK/OBB nếu thiếu → push `frida-server` nếu thiếu → `deploy.py --push` → frida → `am start` → hook SDK → hook vị trí → chờ 300 s → dump |
| `_vong_trace.ps1` | 3 lần boot THƯỜNG (mỗi lần ~12 phút) |
| `_vong_trace_wipe.ps1` | boot `-wipe-data` rồi gọi driver (đường đang dùng) |

Chạy ngày mai:

```powershell
cd D:\PROJECT\ProjectOut\game\brave-cross\work\offline
powershell -ExecutionPolicy Bypass -File _vong_trace_wipe.ps1
# xong thì đọc:
python -I frida\phan_tich_vitri.py
```

---

## 3. TÌNH TRẠNG MÁY ẢO (số đo trong phiên)

| phép | kết quả |
|---|---|
| boot **thường** (`-gpu host -no-snapshot`) | **0/5 lần** qua (logcat dừng ở `MDnsSdListener`; `sys.boot_completed` rỗng) |
| boot **`-wipe-data`** | **QUA** (lần 1 ~580 s, lần 2 ~270 s) |
| tuổi thọ sau boot | **~5–9 phút** rồi `system_server` chết (`futex_wait`, PM mất; `service list` vẫn 101) |
| `stop` / `start` (adb **root**) để dựng lại framework | **không cứu** |
| `adb push` OBB 208 MB | **34 s** (5,8 MB/s) — **không cần PM** |
| `adb install` APK 43 MB | **chưa xong** — treo ở bước này lúc dừng phiên (00:10:09) |

Trạng thái lúc dừng: driver `_trace_vitri.ps1` đang đứng ở dòng
`== CHUA CAI - cai APK ==` (đã push xong APK, đang chờ PMS cài). PM còn sống lúc
00:08:23 (`pm path android` trả `package:…framework-res.apk`).

**Nếu mai mở máy mà tiến trình còn đó**: xem `_trace_vitri.txt`; nếu quá 10 phút vẫn
đứng ở dòng ấy thì PM đã chết giữa lúc cài → kill qemu, chạy lại
`_vong_trace_wipe.ps1`.

---

## 4. BẪY MỚI (đã trả giá trong phiên)

1. **`.ps1` CHỈ ĐƯỢC ASCII.** PowerShell 5.1 đọc tệp `.ps1` **không BOM** theo bảng mã
   ANSI ⇒ một dấu `—` trong chuỗi làm vỡ dấu nháy và cả script **không parse**
   (`Unexpected token`). Viết xong phải kiểm:
   `[System.Management.Automation.Language.Parser]::ParseFile($p,[ref]$null,[ref]$e)`.
2. **Đừng sinh `.ps1`/`.cmd` bằng heredoc Python** — tầng escape ăn mất `\` (`\a` thành
   byte **0x07 BEL**, `\c` mất luôn dấu), đường dẫn thành `$offpk-vn\…`. Dùng khung
   `Write` hoặc sửa bằng `bytes([92])`.
3. **`chay_trace.py` chỉ bắt `send()`** — `console.log` của script Frida **không** về
   driver; mọi thông báo phải đi qua `send({ten:'log', m:…})`.
4. **Driver cũ đòi thấy *tên gói* mới thoát vòng chờ PM** ⇒ sau `-wipe-data` (chưa cài)
   nó quay vô ích **13 phút** và bỏ lỡ cửa sổ sống. Nay: thấy `pm path android` trả
   `package:` là thoát vòng.
5. **Git Bash + `adb push`**: `MSYS_NO_PATHCONV=1`, không thì `/sdcard/...` thành
   `C:/Program Files/Git/sdcard/...`.
6. `tail -f` mặc định in **10 dòng cuối** ⇒ đồng hồ theo dõi bắn lại dòng cũ; dùng
   `tail -n0 -f`.

---

## 5. VIỆC TIẾP THEO (thứ tự)

1. **Lấy được một trận thật**: chạy `_vong_trace_wipe.ps1`; đích là thấy
   `pid=` → `[trace] da gan dan20c/dan1bc/dan200/di` → `trace: N dong`.
   * Nếu `dan*` **không** bắn: ba hàm dàn chạy TRƯỚC khi hook gắn → hook sớm hơn
     (attach ngay sau `am start`, hoặc dùng `--spawn`).
   * Nếu `di` **không** bắn: mover của tướng không gọi `0x413a98` → thử hook
     `CDFSpriteMoveTroop::vfunc_185` (`0x413ad4`) và `MoveHeroRemote` của nó.
2. **Đọc số** bằng `phan_tich_vitri.py`, rồi trả lời ba câu:
   * thứ tự + bước X lúc dàn trận có đúng `slot = BASE − priority`, `fArmySpace = 1,1`
     ô (110 px) như sim không?
   * hàng có giãn ra khi đánh không (sim: **không quá 440 px**)?
   * "chạy quá xa": đồng đội có bám nhau không, và đơn vị có vượt tuyến không?
   (Config **không** có luật ghì lại: `fFightMoveDistance` chỉ dùng ở **1** khối
   `move_GuYong_Weapon` trên toàn bộ VN.)
3. Nếu máy ảo vẫn không qua nổi bước cài → **kết luận**: trace runtime bị chặn trên
   máy này; cần **máy Android thật có root** hoặc ảnh x86 + libhoudini (việc mới, không
   phải sửa nhanh). Ghi rõ trong tài liệu, đừng thử lại vô hạn.

---

## 6. ĐƯỜNG LDPlayer (đã chọn 26/10) — và vì sao nó chưa lên

Máy có **LDPlayer 9.5.31** (`C:\LDPlayer\LDPlayer9`, instance `LDPlayer` index 0, có
`ldconsole.exe modify --root 1`). Đây là đường tốt hơn AVD ARM: x86_64 + **dịch ARM**
(chạy được APK chỉ có `armeabi-v7a`) + **root sẵn**.

**KẾT LUẬN CŨ Ở ĐÂY SAI — ĐÍNH CHÍNH 26/10 20:10 (đo lại bằng tay, Hyper-V VẪN ĐANG BẬT):**

> ~~VM không khởi động được vì Hyper-V chặn ⇒ phải `bcdedit /set hypervisorlaunchtype off`.~~
> **Không cần tắt Hyper-V, không cần reboot.** VM **chạy được**.

| đo (26/10 20:10) | kết quả |
|---|---|
| tiến trình | `Ld9BoxHeadless` + `Ld9BoxSVC` — **không tên "VirtualBox"**, đó là lý do dò không thấy |
| thời gian boot | **~20 s** tới khi `adb devices` có `emulator-5554` |
| cổng | `0.0.0.0:5555` (sau khi bật ADB, xem dưới) |
| `adb root` → `id` | `uid=0(root)`, `getenforce` = `Permissive` |
| `abilist` | `x86_64,x86,arm64-v8a,armeabi-v7a,armeabi` + `/system/lib/libhoudini.so` |
| VBox.log | `HM: HMR3Init: Attempting fall back to NEM: VT-x is not available` → **lui về NEM/WHPX vẫn chạy** (chậm hơn VT-x thật) |
| GPU | `fastpipe: load host success … libOpenglRender2.dll` ⇒ GPU host |
| cấu hình | 6 CPU · 6144 MB · 1920×1080 @280 dpi · Android 9 (SDK 28) |

**Nguyên nhân THẬT của "không có cổng adb":** khoá `"basicSettings.adbDebug"` **vắng mặt**
trong `C:\LDPlayer\LDPlayer9\vms\config\leidian0.config` (⇒ 0 = tắt). Cách chữa:

```powershell
& 'C:\LDPlayer\LDPlayer9\ldconsole.exe' quit --index 0      # PHẢI tắt máy trước, không thì bị ghi đè
# sửa leidian0.config: thêm  "basicSettings.adbDebug": 1,
& 'C:\LDPlayer\LDPlayer9\ldconsole.exe' launch --index 0
& 'C:\LDPlayer\LDPlayer9\adb.exe' devices                     # → emulator-5554  device
```

Đã sao lưu: `vms\config\leidian0.config.bak_truoc_bat_adb`.

**KHÔNG cần reboot.** Trình tự đúng, chạy được (đo 26/10 20:00–22:35):

```powershell
$adb='C:\LDPlayer\LDPlayer9\adb.exe'
& 'C:\LDPlayer\LDPlayer9\ldconsole.exe' launch --index 0
# (nếu chưa cài) adb install -r -g apk-vn\com.cmn.buatanew.apk
#                 adb push main.81485...obb /sdcard/Android/obb/com.cmn.buatanew/
python -I deploy.py --push --sng        # ĐẨY VÀO /storage/emulated/0/assets/sc
python -I frida\chay_trace.py --spawn --tep be_sdk_spawn_bundle.js --giay 1800
```

---

## 7. KẾT QUẢ ĐO ĐƯỢC TRÊN LDPLAYER (26/10, 20:00–22:35)

### 7.1 Lớp offline đã CHẠY — và hai lỗi thật đã chữa

| việc | kết quả |
|---|---|
| cài APK + OBB | `install` 3 s · push OBB 208 MB **5,4 s** (36,6 MB/s) |
| chỗ nạp được lớp offline | **`/storage/emulated/0/assets/sc`** — hook `fopen` cho thấy `package.path` = `/storage/emulated/0/assets/sc/?.lua` → `/data/user/0/<pkg>/files/download/sc/?.lua` → `/data/user/0/<pkg>/files/assets/sc/?.lua` |
| bản nào nạp được | **`deploy/sng`**; bản `plain` bị bỏ qua |
| đăng nhập | hook `be_sdk_spawn_bundle.js` gọi `Userxsdk.login` → `onLoginSuccessCallback(0, …)` là xong, panel Kull không hiện |

Hai lỗi **trong lớp offline**, tìm bằng `offline.log` (không phải lỗi máy ảo):

1. **Phản hồi đăng nhập thiếu `serverlist`** ⇒ `onLoginLogic` đưa `nil` vào
   `showEnterGameUI` → `getLastServer(nil)` → `GetAuditServerList(nil)` →
   `bad argument #1 to 'ipairs'`. Đã thêm `serverlist` + `lastlist`
   (`handlers/login.lua`).
2. **`RecomendList` phải RỖNG.** Mỗi mục trong đó còn bị đọc như **hồ sơ nhân
   vật** (`CUILoginServerList.lua:849-944` → `CUITravern:GetHeroExPercentage`),
   thiếu `Level`/`Ex` là `KDebug: Arg must be number!`. Máy chủ thật cũng chỉ
   đưa vào đây máy chủ mà tài khoản **đã có nhân vật**.

Thêm `handlers/he_thong.lua` (bạn bè, APR đóng, bảng xếp hạng rỗng, hộp thư
rỗng) + nuốt lặng `ClientSetGuideStepComplete` / `ClientSetSchemeComplete` /
`ClientSetSchemeBegin` / `ClientEnterChannel` /
`ClientGetUserNewHandPrivilegeInfo` (đều "bắn rồi quên", xem
`ClientUserLogic.lua:131-145`, `ClientGameWorld.lua:78`).
⇒ `offline.log` **0 dòng THIEU**; `run_tests.py` **147 đạt / 0 hỏng**.

### 7.2 Chơi trọn một ải

Ải 1 chương 1 (Hoàng-Dư Đằng) → đánh thắng → **Tăng LV Chủ Công (Lv1→Lv2)** →
màn **Thắng** (+6 EXP, x200 vàng, rơi 2 món x2) → **Bạn được 1 tướng** (Lăng
Thống ★) → về cảnh Main, ải đã qua. Tự động hoá: `tu_dong.lua` tự đăng nhập
(thêm nhánh cho đường SDK-hook), `vao_tran.lua` tự vào trận khi tới cảnh Main.

⚠ **`vao_tran` đường `g_CUIGame:Test()` làm SẬP libhoudini** (SIGSEGV, fault
0x14, `#00 pc …/libhoudini.so` trên GLThread) — không phải do Frida (đã thử
không gắn hook vẫn sập). Đã đặt `OfflineVaoTran.TAT = true`; vào trận bằng UI
thật thì ổn định.

### 7.3 ĐIỂM CHẶN: Frida KHÔNG hook được code ARM trên LDPlayer

```
0c2e4000-0cb4c000 r--p … /lib/arm/libgame.so     ← chỉ r--, KHÔNG có r-xp
```

libgame.so được nạp **chỉ-đọc** và code thật chạy bằng **JIT của libhoudini**.
`Process.findModuleByName('libgame.so')` trả `null`; `Interceptor.attach` vào
`base+0x386efc…` chạy được nhưng **không bắn dòng nào**, vì byte bị vá không
phải byte được thi hành. ⇒ Muốn có số đo native phải chạy **ARM thật**
(AVD arm 30.2.2 hoặc máy Android thật có root).

Hệ quả: LDPlayer giờ là môi trường **chơi/kiểm tra lớp offline** rất tốt
(boot 20 s, `adb install` 3 s, push 36 MB/s), nhưng **không dùng để trace**.

---

## 8. HOÀN THIỆN LỚP OFFLINE — đã bù gì, còn chặn ở đâu (27/10 rạng sáng)

### 8.1 Bảng phủ RPC (công cụ mới)

```
python -I _phu_rpc.py          # tổng / đã có / thiếu, kèm file:line của chỗ client gọi
python -I _phu_rpc.py --thieu  # chỉ danh sách thiếu
python -I _phu_nhom.py         # nhóm theo module, đánh dấu [che do phu]
```

Đo được: client gọi **510 hàm server**; lớp offline phủ **43**. Phần lớn số thiếu
thuộc chế độ phụ (đấu trường, quân đoàn, COG, giải đấu, APR…) — **không** cần cho
một lượt chơi đơn.

### 8.2 Đã bù trong đợt này

| việc | tệp |
|---|---|
| `serverlist` + `RecomendList` rỗng (2 lỗi vỡ luồng đăng nhập) | `handlers/login.lua` |
| bạn bè / APR đóng / BXH rỗng / hộp thư rỗng | `handlers/he_thong.lua` |
| nuốt lặng 7 lệnh "bắn rồi quên" (guide step, scheme, enter channel, new-hand) | `handlers/login.lua` |
| **trạng thái thành tựu tự chữa** (State Done → Doing trước khi xét) | `handlers/achieve.lua` |
| **nhiệm vụ hướng dẫn đóng thẳng sang Cleared** (bản gốc bỏ qua bước thưởng khi Cleared) | `handlers/achieve.lua` |
| **rèn trang bị** — gọi lớp cha `EquipmentLogic:SynthesisEquipment` rồi phát đúng sự kiện UI | `handlers/trang_bi.lua` |
| `deploy.py` thêm `/storage/emulated/0/assets` làm ứng viên đầu | `deploy.py` |

`run_tests.py`: **147 đạt / 0 hỏng**.

### 8.3 ĐÃ CHỮA — popup "Nhận Thưởng" khoá tương tác

Truy ra: popup là **`CUIRewardLayer`**; `CGuideScheme_showAwardAchieve`
(`CGuideScheme.lua:4358-4364`) gọi `CallAwardAchieve` rồi `coroutine.yield("Reward_Hide")`,
và `Reward_Hide` **chỉ** được phát trong `CUIRewardLayer:onClose()`
(`CUIRewardLayer.lua:191`). Trên LDPlayer popup hiện ra nhưng không đóng được ⇒ guide
kẹt vĩnh viễn, mỗi lần đăng nhập kẹt lại.

Cách chữa (`sc/offline/tu_dong.lua`): watchdog trong tick — thấy `g_CUIRewardLayer.bVisible`
thì gọi đúng đường của nút đóng (`onTouchEnd_OnClose(nil, true)`): nhịp 1 cho chạy hết
hoạt ảnh (`_forceShowAll`), nhịp 2 đóng thật → `Reward_Hide` được phát, guide chạy tiếp.

**Đã kiểm**: có lần popup tự đóng và guide đi tiếp (tới bước "đi đập tan Hoàng Cân Tặc").
Nhưng **không phải lần nào cũng vậy**: ở lượt khác popup vẫn hiện mà watchdog **không ghi
tên lớp nào** ⇒ cửa sổ đó **không phải** `G_CUIRewardLayer` (biến toàn cục viết HOA, không
phải `g_CUIRewardLayer` — đã sửa) cũng không phải `g_CUIQuestRewardGet`.

Việc còn lại: **xác định đúng lớp** của popup "Nhận Thưởng · Nhập để tắt". Cách nhanh:
hook `g_CUIMultiLayerDialog` (mọi cửa sổ nhiều lớp đăng ký qua nó) hoặc duyệt
`g_CUIMultiLayerDialog.tUIs` trong một tick rồi ghi tên những cái đang `bVisible`.
Đã có sẵn chỗ chèn: khối watchdog trong `tu_dong.lua` (mỗi 3 nhịp ghi log tên lớp đã đóng).

### 8.4 Rèn trang bị — đã chạy thật

`handlers/trang_bi.lua` gọi lớp cha `EquipmentLogic:SynthesisEquipment` (đúng đường bản
gốc để lại trong `ClientEquipmentLogic.lua:240-284`) rồi phát
`EventManagerLogicEvent.OnSynthesisEquipment`. Đo trên máy: bấm Rèn → log
`ren xong: tuong 2, o 2 -> cap 1`, vàng 50200→50190, ô rèn chuyển sang bậc kế
("Đồng Giáp IV" → "Thiết Giáp IV"). **Đã xác nhận chạy đúng.**

### 8.5 GỐC RỄ ĐÃ TÌM RA VÀ ĐÃ CHỮA: `LastEnterGameTime` chưa bao giờ được đặt

Vết gọi (in bằng `debug.traceback` trong handler):

```
ClientGameWorld:EnterGame            (ClientGameWorld.lua:262)
ClientGameWorld:CheckIsOverDay       (ClientGameWorld.lua:350)
CUIMain event → ...                  (CUIMain.lua:776, :317)
```

`CheckIsOverDay` gọi `getIsDailyFirstEnterGame(nLastEnterGameTime, nEnterGameTime, …)`
(`share_gameWorld.lua:17-25`), hàm gốc coi là **lần đầu trong ngày** khi
`nEnterGameTime - nLastEnterGameTime > 86400`. Lớp offline **chưa bao giờ đặt**
`LastEnterGameTime` (nằm trong `tUserGlobalData`) ⇒ lần nào cũng "ngày mới" ⇒ client
gọi lại `EnterGame()` **liên tục** (đo được 46+ lần/giây), kéo theo kịch bản hướng dẫn
chạy lại và phát thưởng lặp ⇒ popup "Nhận Thưởng" hiện lại mãi.

**Sửa** (`handlers/login.lua`, nhánh `ClientEnterGame`): ghi mốc trước khi trả dữ liệu —
```lua
tGlobal.LastEnterGameTime = os.time()
tGlobal.ContinuesEnterGameCount = 1
```

**Kết quả đo sau khi sửa**: `vao game lan` = **1** (trước 46+/giây),
`ClientReachAchieve` = **2** (trước hàng chục), màn hình chính sạch (không popup,
không bàn tay hướng dẫn), `run_tests.py` **147/0**.

### 8.6 Hướng dẫn tân thủ đã tắt được

`tu_dong` gọi `g_CGuideLogical:FinishGudie()` sau 5 nhịp kể từ `Offline.LAN_VAO_GAME`;
log xác nhận `tu_dong: tat huong dan tan thu -> true`. Guide không còn chạy lại.

### 8.7 Tour UI đã chạy lại — và bù được 2 RPC mới

Panel **T.Trang / Nhận cánh** mở sạch, `offline.log` **0 dòng THIEU**. Hai RPC đã bù
trong `handlers/he_thong.lua`:

| RPC | đường làm |
|---|---|
| `ClientRefreshLeftWingCount` | `ClothingLogic:GetChargeWingLeftCount()` (mặc định 999) rồi phát sự kiện chuỗi `"OnRefreshLeftWingCount"` mà `CUIWingGet` đăng ký |
| `ClientGetClothingPrizeCount(strIndex)` | gọi lớp cha `ClothingLogic:refreshGetClothingPrizeCount(0, strIndex)` → trả `OnServerGetClothingPrizeCount(nLeft, strIndex)` |

Đo trên máy: `refresh canh: con 999` · `trang phuc 1: con 999 luot`.
`ClientSetClientCommonData` (client tự lưu dữ liệu chung lên "máy chủ") đã cho vào
danh sách nuốt lặng — dữ liệu ấy client đã có và dựng lại mỗi phiên.

Cột icon mép trái (Hộp Thư / H.Động / Nạp / D.Danh) **vẫn không ăn** với toạ độ ước
lượng — cần đo lại; top bar (T.Trang / Nhận / 7 ngày / Tần Thú) và menu phải thì ăn.

Các panel đã mở được bằng top bar, đều **0 dòng THIEU**:

| panel | toạ độ | ghi chú |
|---|---|---|
| Nhận cánh (T.Trang) | (1030,150) | 2 RPC ở bảng trên; **modal, không thấy nút đóng** — BACK và bấm ra ngoài đều không thoát, phải khởi động lại |
| Quà Login Tuần (7 ngày) | (860,150) | hiện Ngày 1–4 "Chưa đến" |
| Quyền Tân Thủ (Tần Thú) | (690,150) | `G_NewHandPrivilegeLogic` đã nuốt lặng; có nút "Xem" cho mốc nạp |

**Việc tiếp**: (1) tìm đường đóng cho panel modal (Nhận cánh) — thêm watchdog như
`G_CUIRewardLayer` hoặc tìm toạ độ nút X; (2) đo lại toạ độ cột trái; (3) tour tiếp
Nhận / Túi / Mục.

---

## 9. DỪNG PHIÊN 27/10 01:20 — TRẠNG THÁI ĐỂ MAI LÀM TIẾP

### 9.1 Đã bù thêm (đều build + push lên máy)

| RPC / việc | tệp | trạng thái |
|---|---|---|
| `ClientRefreshLeftWingCount` (còn 999) | `handlers/he_thong.lua` | **kiểm trong game**: `refresh canh: con 999` |
| `ClientGetClothingPrizeCount` | `handlers/he_thong.lua` | **kiểm**: `trang phuc 1: con 999 luot` |
| `ClientGetLoginRewardData` + `ClientGetPrize` (popup "Quà login ngày") | `handlers/he_thong.lua` | popup **hết treo**, hiện đủ nội dung; nút "Nhận" chưa ăn với `input tap` |
| watchdog tự đóng `g_CUILoginReward` | `tu_dong.lua` | đã có, chưa bắt được lần nào |
| `ClientSetClientCommonData` | `handlers/login.lua` (nuốt lặng) | xong |
| **`traoRoiDo()`** — trao vật phẩm rơi vào kho | `handlers/chapter.lua` | **CHƯA KIỂM** trong game |

`traoRoiDo` dùng `ItemLogic:AddItem(PropID, PrizeResCount, "roi-do", nil)` cho
`PrizeResType` 2 (Prop) và 8 (Material); các loại khác ghi log `roi do: loai … — chua trao`.
Schema `PrizeData` lấy từ `decompiler/out/vn126/xgg-json/config/share/KDBGameNpcConfig.json`.

### 9.2 Trạng thái máy lúc dừng

`run_tests.py` **147/0** · `vao game lan = 1` · `THIEU = 0` · game ở cảnh Main Lv3,
popup "Quà login ngày" đang mở (bấm `input tap` vào "Nhận" không ăn — thử bằng chuột).

### 9.3 Mở game (thứ tự bắt buộc)

```powershell
& 'C:\LDPlayer\LDPlayer9\ldconsole.exe' launch --index 0
# chờ tới khi: adb devices → emulator-5554  device
& 'C:\LDPlayer\LDPlayer9\adb.exe' -s emulator-5554 root
# adb root GIẾT frida-server → phải bật lại, không thì lỗi "need Gadget"
Start-Process -FilePath 'C:\LDPlayer\LDPlayer9\adb.exe' -ArgumentList '-s','emulator-5554','shell','/data/local/tmp/frida-server'
$off='D:\PROJECT\ProjectOut\game\brave-cross\work\offline'
$env:PYTHONUTF8='1'; python -I "$off\frida\chay_trace.py" --spawn --tep be_sdk_spawn_bundle.js --giay 3600
```

### 9.4 Việc tiếp (theo thứ tự)

1. Kiểm `traoRoiDo` bằng **một trận thật** → mở Túi xem có vật phẩm; nếu có, bù tiếp
   `HeroFragment` (6) và `Resource` (3) theo cùng khung.
2. Đo lại toạ độ: cột icon trái (Hộp Thư/H.Động/Nạp/D.Danh) và nút "Nhận" của popup.
3. Tour tiếp: Hộp Thư → H.Động.
4. (Sau cùng, khi rảnh) trace native: phải có ARM thật — LDPlayer không hook được (mục 7.3).




### 8.8 Trạng thái các phần khác

* `offline.log`: 0 dòng THIEU ở luồng đang chơi (43 handler).
* `run_tests.py`: 147 đạt / 0 hỏng.
* Rèn trang bị: **chạy đúng** (§8.4).






---

## 10. LÀM TIẾP 27/10 (chiều) — bốn việc của §9.4, đo trên LDPlayer

Máy: LDPlayer index 0 chạy sẵn, `adb root` OK, `frida-server` bật lại sau `adb root`,
game mở bằng `python -I frida\chay_trace.py --spawn --tep be_sdk_spawn_bundle.js --giay 20`.

### 10.1 `traoRoiDo` — BỎ, thay bằng đúng luồng gốc (kèm một lỗi thật đã vá)

**Phát hiện**: `traoRoiDo` (viết 27/10 00:01) là **trao lần hai**. Luật gốc
`chapterCompleteSuccess` → `chapterVictoryHandle` (:2811) → `SetDataWithDropList`
(:4028) → `SetDataWithPrizeData` (:4258) **đã trao sẵn** mọi món rơi. Hàm ấy là hàm
**của máy chủ gốc** nằm ngay trong `share/share_ChapterLogic.lua`, client thừa kế
nguyên vẹn (`ClientChapterLogic:SetDataWithPrizeData` chỉ gọi lớp cha,
`user/Logical/ClientChapterLogic.lua:3328`), và phủ sẵn:

| `PrizeResType` | đường trao trong hàm gốc |
|---|---|
| 2 Vật phẩm | `ItemLogic:AddItem` |
| 3 Tài nguyên | `UserLogic:AddGold/AddDiamond/AddConcentrate`, `ArenaLogic`, `CavernDataManager`, `ArmyDataManager` |
| 4 User | `DoPrizeProperty_<tên hàm trong config>` |
| 5 Tướng | `SavePrizeHeroData` → `HeroLogic:AddHero` |
| 6 Mảnh tướng | `HeroLogic:AddHeroFragment` |
| 9 Thời trang · 10 Cánh | nhánh riêng |

**Chỗ duy nhất phải vá**: `SetDataWithDropList` nhận `tReportsData` (chiến báo — phía
máy chủ mới có) và ghi `tReportsData["DropCount_…"]` (:4128) sau MỖI món trao được.
`chapterVictoryHandle` truyền **nil** ⇒ với ải CÓ `DropData` (144/461 ải) phép ghi ấy
ném lỗi **giữa vòng**, các món sau không được trao và `chapterCompleteSuccess` trả
false. Đã bọc: `boc_SetDataWithDropList` trong `handlers/chapter.lua` thay nil bằng
một bảng tạm. Chiến báo thật vẫn do `saveVictoryReport` tự dựng bên trong.

⇒ Mỗi món trao ĐÚNG MỘT lần, qua đúng hàm gốc. `traoRoiDo` đã xoá, thay bằng
`ghiNhatKyRoiDo` (chỉ GHI LOG danh sách rơi để đối chiếu, không trao).

⚠ Bẫy khi viết bản bọc: đừng giữ cờ "đã bọc" trên **class table**. `class()`
(`share/class.lua:56-60`) chỉ đặt `__newindex` cho class table, KHÔNG có `__index`, nên
`ClientChapterLogic.<tên cờ>` **đọc lại luôn ra nil** ⇒ mỗi trận bọc chồng thêm một lớp.
Đã đổi sang biến cục bộ `daBocDrop` trong `handlers/chapter.lua`.

### 10.2 `ClientGetLoginReward` — nút "Nhận" của "Quà login ngày" ĐÃ ĂN

Đo 27/10: bấm `input tap 1190 770` thì RPC **có đi** (`G_AchieveLogic:CallGetLoginReward`
`ClientAchieveLogic.lua:801`) — log ghi `THIEU G_AchieveLogic.ClientGetLoginReward`,
tức nút ăn, chỉ thiếu phía trả. Đã thêm handler (`handlers/he_thong.lua`) gọi chính
`AchieveLogic:GetLoginReward` (`share/AchieveLogic.lua:986`) — hàm này kiểm đã nhận
chưa + cấp ≥ 3, phát thưởng qua `ReceivePrizeWithID(LoginPrizeID = 1010)`, đặt cờ, và
phát `Achieve.OnGetLoginReward` (sự kiện `CUILoginReward:OnGetLoginReward` đang chờ để
đóng popup); rồi trả đường phản hồi chung `CUIRPCManager:OnReciveResponse` để tắt lớp
"đang tải".

**Đo được**: log `ClientGetLoginReward: nhan qua login -> true (ma 0)`; popup đóng;
Ngọc 0→10, và file lưu có `GameUserItem["1"].ItemCount = 10` (Khối Vàng),
`["4"].ItemCount = 20` (EXP Đan), `IsGetLoginReward = true` — **đã ghi vào kho, qua
được lần đăng nhập lại**.

### 10.3 `ClientGetMailList` — Hộp Thư hết quay

Bản cũ trả qua hàm TOÀN CỤC `OnGetMailList` (`CServerResponseLogic.lua:921`, đường
mạng CŨ). `CUIMail` lại nghe **logic event** `"OnServerGetMailList"`
(`CUIMail.lua:161`) do `ClientMailLogic:OnServerGetMailList(nErrCode, tMailList)`
(`ClientMailLogic.lua:138-177`) phát. Đã đổi sang
`ctx:call("G_MailLogic", "OnServerGetMailList", 0, {})`.
**Đo được**: bấm Hộp Thư → panel mở, danh sách rỗng, KHÔNG còn vòng quay.

### 10.4 LỖI GỐC CỦA "vao game lan" LẶP LẠI — ghi nhầm bảng

Sau một trận (27/10 19:57) log phình lên `vao game lan 6285` trong ~30 phút. Nguyên
nhân KHÔNG phải `LastEnterGameTime` không được đặt, mà là **được đặt vào bảng sai**:

* Bản sửa 27/10 00:01 ghi `G_UserDataManager:GetUserGlobalData().LastEnterGameTime`
  — bảng của PHIÊN ĐANG SỐNG.
* `ClientEnterGame` lại trả `tUserData = OfflineStore:all()` — bản **từ file lưu**,
  mốc vẫn là cũ. `OnServerEnterGame` THAY dữ liệu client bằng bảng ấy ⇒ mốc mới bị đè.
* `getIsDailyFirstEnterGame` (`share_gameWorld.lua:17-45`) còn rẽ nhánh theo **NGÀY**
  qua `os.date("*t")` với `DialyRefreshHour = 5`: mốc trong file là 26/10 23:04, hôm
  nay 27/10 20:xx ⇒ `nowDay ~= lastDay and nowHour >= 5` ⇒ "lần đầu trong ngày" ⇒
  `EnterGame()` ⇒ lặp vô hạn. (Lần đo 01:16 không lộ vì mốc còn CÙNG NGÀY.)

**Sửa**: ghi mốc vào chính `tUserData.GameUserGlobalData` trước khi gửi
(`handlers/login.lua`). **Đo lại**: khởi động 20:11 → `vao game lan 1`, 30 s sau vẫn 1.

### 10.5 Hai trận thật + một popup thưởng (đo trong phiên)

| việc | kết quả |
|---|---|
| vào ải (node `Cửa Khăn Vàng (Bàng Thác)` = `L_N_01_03`) | thắng 2 sao, Lv3→**Lv4**, vàng 50390→50590, `ClientChapterCompleteSuccess` không lỗi |
| vào ải `Hoàng-Bộ Quân 1` (`L_N_01_04`) | thắng, vàng +200, popup **"Nhận Thưởng: Binh Hồn x100"** — tức nhánh `PrizeResType 3` (`G_ArmyDataManager`) chạy được |
| rơi đồ `DropList` | **cả hai trận đều `khong roi mon nao`** — KHÔNG phải lỗi: xác suất mỗi món là `DropValue/TotalDropValue` = **12/10000** (`KDBGameNpcConfig`), trừ boss `2015/2016` của `L_N_01_01/02` có **100/100** (thưởng Binh Hồn x6) |

⇒ Muốn kiểm nhánh trao-rơi một cách **chắc chắn** thì phải đánh `L_N_01_01` hoặc
`L_N_01_02` (boss rơi 100%), hoặc càn quét đúng ải đó. `L_N_01_03` có `DropData`
nhưng boss không có bảng rơi nên hai trận vừa rồi chưa chạm nhánh `tReportsData`.

### 10.6 TOẠ ĐỘ ĐO ĐƯỢC (1920×1080, LDPlayer index 0)

| thứ | toạ độ | ghi chú |
|---|---|---|
| nút **Nhận** popup "Quà login ngày" | **(1190, 770)** | bấm ăn |
| bấm để tắt "Nhận Thưởng" | (900, 900) | watchdog cũng tự đóng |
| **H.Động** (cột trái) | **(60, 600)** | mở panel Hoạt Động |
| **Nạp** | (57, 445) | |
| **D.Danh** (cuộn) | (50, 295) | |
| **Hộp Thư** | **(185, 745)** | KHÔNG cùng cột — là hòm thư trên mặt đất |
| chat | (42, 845) | |
| **Tấn Công** (Main) | (1795, 990) | mở bản đồ chương |
| nút **Chiến** (bảng ải) | (1490, 930) → bảng bố trí **Chiến** (1570, 960) | |
| màn trận: **Auto** | (100, 735) | bật tự đánh |
| màn trận: gọi lính | (1400, 800) | |
| bấm qua thoại | (1600, 470) | nhiều thoại liên tiếp |

### 10.7 Trạng thái cuối phiên 27/10

* `run_tests.py`: **147 đạt / 0 hỏng**; `_phu_rpc.py`: **510 hàm client gọi, 46 đã phủ**.
* `offline.log`: **0 dòng THIEU** phát sinh sau khi bù (3 dòng cũ đều trước bản vá).
* `vao game lan = 1` sau khởi động 20:11.

**Việc tiếp**: (1) đánh `L_N_01_01`/`L_N_01_02` (boss rơi 100%) để chạm nhánh
`tReportsData` và xem `roi do: … da trao`; (2) bù `PrizeResType 6` — thử bằng
thưởng thành tựu/nhiệm vụ có mảnh tướng (`KDBGameAchieveConfig`); (3) tour Túi/Mục.

---

## 11. 27/10 (tối) — GỐC RỄ "RƠI ĐỒ MÀ TÚI KHÔNG CÓ" ĐÃ TÌM RA VÀ KIỂM

### 11.1 Lỗi: lớp offline tự lọc sạch mọi món rơi

`CUIGame:OnLevelCompleteCallServer` (`user/Battle/CUIGame.lua:3196-3220`) — đường
ải THƯỜNG — **chỉ gửi `ChapterData`**, KHÔNG có `KillIdList`. Chỉ các ải đặc biệt
mới có (`OnSCSCallServer` :3235, `OnXZWCCallServer`, `OnDKCallServer`,
`OnTGZZCallServer`), và chúng lấy từ `self.ChapterObj:OnKill` — mà `OnKill` chỉ tồn
tại ở `FBHuangJinRuQin/FBSeaBoss/FBShiChangShi/FBTongGuanZhiZhan/FBXueZhanWanCheng/
FBDK`. Ải thường **không ai gom** danh sách giết.

Bản cũ của `handlers/chapter.lua` lấy `{}` khi thiếu ⇒ `filterKillDropList({}, tRoi)`
trả `Drop = {}` ⇒ **mọi món bị lọc sạch**. Đó đúng là triệu chứng "trận thắng có rơi
đồ mà mở Túi không có" (và hai trận `L_N_01_03`/`L_N_01_04` hôm trước đều
`khong roi mon nao` — KHÔNG phải xác suất: **mọi chương đều có ít nhất một NPC rơi
100%**, 164 cặp ải–NPC như vậy ở ải thường).

**Sửa**: chỉ lọc khi `cd.KillIdList` LÀ BẢNG; thiếu thì trao nguyên danh sách đã quay
ở `OfflineDrop_build`, kèm dòng log `client khong gui KillIdList — trao het danh sach roi`.

### 11.2 Kiểm chứng trong game (ải `L_N_01_03`, boss 1001 rơi Binh Hồn x6)

| bước | kết quả |
|---|---|
| trước trận | `GameUserBaseInfo.ArmySoul = 0` (đã tiêu 100 mở Cung Binh ở §11.3) |
| log | `ClientChapterCompleteSuccess L_N_01_03: 1 mon roi — Tai nguyen(id 0 x6)` |
| màn Thắng | hiện **Binh Hồn x6** ở góc trái; lên **Lv5**, mở skill "Thanh Tâm Chú" |
| file lưu | **`GameUserBaseInfo.ArmySoul = 6`** |

⇒ Nhánh `tReportsData` của `SetDataWithDropList` (bọc ở §10.1) + `SetDataWithPrizeData`
nhóm 3 (Tài nguyên → `G_ArmyDataManager:ChangeArmySoul`) chạy đúng và **có ghi vào kho**.

### 11.3 Hướng dẫn tân thủ kẹt ở `ClientUnlockArmy` — đã bù Doanh Trại

Đo: bấm "Mở Khoá" ở Cung Binh ⇒ `THIEU G_ArmyLogic.ClientUnlockArmy args=[3]`,
hướng dẫn đứng im. Đã thêm **`handlers/binh_chung.lua`** phủ 5 lệnh:

| lệnh server | hàm luật gốc | trả cho client |
|---|---|---|
| `ClientUnlockArmy` | `ArmyLogic:UnlockArmy` (:409) | `OnUnlockArmy(nArmyId)` |
| `ClientUpgradeArmy` | `ArmyLogic:UpgradeArmy` (:283) | `OnUpgradeArmy(nArmyId)` |
| `ClientIntoLineup` | `ArmyLogic:IntoLineup` (:585) | `OnIntoLineup{...}` |
| `ClientOutOffLineup` | `ArmyLogic:OutOffLineup` (:707) | `OnOutOffLineup{...}` |
| `ClientSetLastArmyLineup` | (client đã tự gọi trước) | chỉ tắt lớp đang tải |

⚠ Bẫy thứ hai, đo được: mở khoá XONG thì UI nổ
`ArmyLogic.lua:523: attempt to compare nil with number` — dòng dữ liệu binh chủng nạp
từ file lưu **thiếu `ResourceForUpgrade`/`CanBeUnlock`/`BaseInfo`** (những trường do
`updateArmyData` :120-196 sinh). Handler nay gọi lại `updateArmyData` TRƯỚC và SAU khi
mở khoá. Đo lại: Binh Hồn 100 → **0**, panel chuyển sang "Tăng LV" (300), không lỗi.

### 11.4 Ghi chú về hướng dẫn tân thủ / drama

Đo: `g_CGuideLogical:FinishGudie()` trả **true** nhưng đoạn thoại
"Offline: Mậu đi giải khóa Binh Chủng mới nào!" VẪN hiện lại mỗi lần vào cảnh Main —
đó là **lớp thoại cốt truyện** (`plot/drama_*.lua`, người nói là nhân vật người chơi),
KHÔNG phải `CGuideLogical`. Lớp này phủ màn và nuốt cú bấm cho tới khi bấm qua đủ số
câu. `tu_dong` nay gọi `FinishGudie` **lặp mỗi 10 nhịp** (idempotent, để hướng dẫn
không chạy lại), nhưng **không đóng được drama** — việc còn lại là tìm hàm/khoá của
lớp drama (trỏ vào `g_DramaSystem`) để tự bấm qua, hoặc chặn phát drama khi offline.

### 11.5 Toạ độ thêm (1920×1080)

| thứ | toạ độ |
|---|---|
| Doanh Trại (Binh Doanh) trên Main | (780, 570) |
| chọn lính Cung Binh trong dãy | (940, 930) |
| nút **Hình** (xem thông tin lính) | (910, 590) |
| **Mở Khoá** / **Tăng LV** | (505, 960) |
| bấm qua thoại drama | (1600, 620) |
| node boss ải 1-3 trên bản đồ | (370, 520) |

---

## 12. 27/10 (khuya) — TỰ BẤM QUA THOẠI HƯỚNG DẪN + RƯƠNG/QUAY

### 12.1 Khung thoại chặn màn: của HƯỚNG DẪN, và có khoá chờ đúng

Chẩn đoán tại chỗ (đo 21:27, bật tạm `OfflineTuDong.CHAN_DOAN`):

```
clUIMainGuide = userdata
clUIMainGuide:isVisible  -> attempt to call method 'isVisible' (a nil value)   ← KHÔNG có
g_DramaSystem            = userdata; SkipCurrentPlot/EndPlot = function; IsPlaying/GoNext = nil
g_CGuideLogical.currCorountine = thread: 0xd07140e0
```

⇒ Khung thoại "Offline: Mậu đi giải khóa Binh Chủng mới nào!" là hộp thoại của
**hướng dẫn** (`CGuideLogical:ShowDialog`, vẽ vào `clUIMainGuide`), KHÔNG phải
`g_DramaSystem`. Bản dò cũ thất bại vì gọi `isVisible()` trên userdata C++ không có
hàm ấy — pcall nuốt lỗi, nên watchdog **không bao giờ chạy**.

**Cổng đúng**: `g_CGuideLogical.tListener == "GuideShowDialog"` — đó là khoá mà
coroutine hướng dẫn đang chờ (`coroutine.yield("GuideShowDialog")`,
`CGuideScheme.lua:77, :84, …`), và `continueGuide` (:823-860) **chỉ resume khi khoá
trùng**, nên gọi lúc hướng dẫn đang chờ việc khác là vô hại.

**Đường bấm**: `CGuideLogical:onTouchEnd_onGuideGoNext(clUIMainGuide, true)` (:559) —
ẩn node, gọi callback, rồi `continueGuide("GuideShowDialog")`. `obj` phải khác nil
(`KDebug.ArgsIsNil(obj, …)` chặn ngay đầu hàm).

**Đo được**: log `tu_dong: tu bam qua thoai huong dan (lan 1)` ngay nhịp thứ 1 sau
khi cảnh Main dựng, khung thoại biến mất, màn chính sạch (ảnh 21:30).

### 12.2 Rương trên Main = bàn quay (chest shop) — bù 2 RPC

| RPC | trước | nay |
|---|---|---|
| `ClientGetLotteryData` | `THIEU` (21:36) — panel đứng ở vòng quay | trả `OnGetLotteryData(0, {})`; danh sách rỗng hợp lệ (lớp offline không lưu `GameLotteryPlayerRecord`) |
| `ClientGetSoulBoxHeroFragmentList` | thiếu | trả `OnServerGetSoulBoxHeroFragmentList(0, {})` — danh sách rỗng, vì bảng mảnh nào mở được là luật SINH của máy chủ gốc (không ship) |
| `ClientPlaySoulBox` | thiếu | **CHƯA làm** — cùng lý do; sẽ ghi `THIEU` |

**Đo được**: bấm Rương → panel mở, không vòng quay; bấm **"Mua 1 cái" (miễn phí,
còn 5 lần)** → hộp mở, ra **Dá Lam X1**, bấm OK; file lưu có `GameUserItem["14"] = 1`
và `["86"] = 1` (trước 0) ⇒ nhánh quay → `G_LotteryLogic:setDataWithPrizeList` →
`SetDataWithPrizeList` chạy đúng.

### 12.3 Mảnh tướng (PrizeResType 6) — đường trao đã rõ, chưa có dịp chạy

`HeroLogic:AddHero` (`share_HeroLogic.lua:659+`): tướng **đã có** thì rẽ sang
`HeroChangeToFragment` và đặt `tRetData.IsToFragment/FragmentCount` — tức quay TRÙNG
cũng đi đúng `AddHeroFragment`. Còn `PrizeResType 6` trực tiếp thì nằm ở **ải tinh
anh** (`L_H_*`: `MaybeDropEquipListInfo`, `DropData`) — chưa mở ở Lv5.
⇒ Chưa cần bịa đường: khi có ải `L_H_*` hoặc quay trùng tướng, cùng hàm ấy sẽ chạy.

### 12.4 Ghi chú vận hành

`offline.log` **append không cắt**, đã lên **>90.000 dòng** sau các lượt lặp `EnterGame`
của sáng nay. Chưa cắt vì cần đối chiếu lịch sử; nếu thành vấn đề thì thêm xoay vòng
theo dung lượng ở `OfflineLog:open`.

---

## 13. 27/10 (đêm) — ROUTER KHOÁ THEO (obj, func) + TÚI MỞ ĐƯỢC

### 13.1 Lỗi thật: hai hệ dùng CÙNG tên hàm RPC

RPC của bản gốc khoá theo **bộ ba** (module, objName, funcName) —
`CallLocal(szObjName, szFunName, …)` (`system/rpc.lua:83`) — nên **hai hệ khác nhau
được phép trùng tên hàm**. Router của lớp offline lại khoá trơ theo tên hàm ⇒ cái
đăng ký SAU **đè** cái trước và lượt gọi đi nhầm hàm.

Đo được ngay trong nhật ký khởi động: `WARN dang ky de handler: ClientCompeleteFight`
và `… ClientSetLastArmyLineup`. Quét cả cây client: **45 tên hàm** bị dùng bởi nhiều
obj, ví dụ

| tên hàm | các obj |
|---|---|
| `ClientCompeleteFight` | `G_CavernLogic` (:24), `G_EndlessChapterLogic` (:290) — tham số khác hẳn |
| `ClientGetPrize` | `G_LoginRewardLogic`, `G_AdventureLogic`, `G_COGCityDefendMission`, 2 hoạt động |
| `ClientRefresh` | `G_MysteriousStoreLogic`, `G_GodSecret`, `G_GuildStoreLogic` |
| `ClientBuyGoods` | 9 obj (COG, GodSecret, GuildStore, MagicWeapon, Mysterious, ScoreStroe, StateWar, Shop…) |

**Sửa**: `OfflineRouter:getFor(strObj, strFunc)` — thử `"obj.func"` TRƯỚC, rồi mới
rơi về tên trơ; `net.lua:253` dùng hàm này. Handler nào đã đăng ký trơ vẫn chạy như cũ.

Đã đổi ba chỗ đang đụng nhau:

| handler | trước | nay |
|---|---|---|
| cavern | `ClientCompeleteFight` | `G_CavernLogic.ClientCompeleteFight` |
| endless (chưa làm) | `ClientCompeleteFight` (đè cavern!) | `G_EndlessChapterLogic.ClientCompeleteFight` |
| quà login ngày | `ClientGetPrize` | `G_LoginRewardLogic.ClientGetPrize` |
| cửa hàng bí ẩn | `ClientRefresh` | `G_MysteriousStoreLogic.ClientRefresh` |

Kèm: bỏ `ClientSetLastArmyLineup` khỏi `handlers/binh_chung.lua` (đã có ở
`handlers/chapter.lua:285`); `test/run.lua` kiểm handler bằng `getFor`;
`_phu_rpc.py` cắt tiền tố obj khi đối chiếu. **Khởi động lại: 0 cảnh báo trùng.**

### 13.2 TÚI (Backpack) — mở được, dữ liệu khớp

Nút là biến toàn cục `btnBackpackUI`; hàm của nút:
`g_CUIMain:onTouchEnd_onBackpackUI(btnBackpackUI, true)` (`CUIMain.lua:1739`) →
`g_CUINormalDlg:Show(g_CUIBackpack:GetUIName())`. **Đo được**: gọi hàm ấy mở đúng
panel 4 tab, không cần toạ độ.

Nội dung panel khớp file lưu từng món:

| tab | hiện |
|---|---|
| Vật Phẩm | Khối Vàng — SL **10** (`GameUserItem["1"]`) |
| Vật Liệu | Sách Vũ Khí Cấp 1 ×1, Sách Phòng Cấp 1 ×1, Đồng ×2, **Dá Lam ×1**, Tử thiết… |
| Thuốc / Mảnh | (trống ở trạng thái hiện tại) |

⇒ Chuỗi **quay → kho → Túi** khép kín: quay ra Dá Lam, mở Túi thấy Dá Lam.

**Toạ độ nút trên màn hình: CHƯA đo được chắc chắn.** Đo trực tiếp trong game:
`btnBackpackUI` có `getIsVisible() = true`, `getPosition() = (40,40)`,
`getParent():convertToWorldSpace` = **(1296,58 · 917,66)**, `winSize = 1366×768`.
Nhưng world của lớp UI đi qua `UIRootLayer` có biến đổi riêng, nên nhân tỉ lệ
màn hình (1920×1080 ÷ 1366×768) không ra chỗ bấm đúng (thử (1823,435) không ăn).
Muốn có số thì phải log cả chuỗi cha (position + scale từng cấp) — việc nhỏ, chưa làm.

### 13.3 Thêm: log bước hướng dẫn

`tu_dong` ghi `tu_dong: huong dan cho khoa = <khoá>` mỗi khi `tListener` ĐỔI — bản đồ
các bước của kịch bản tân thủ trong lượt thật (khoá là tên nút/biến mà `CGuideScheme`
`coroutine.yield`). Dùng để điều khiển bước kế mà không phải đoán toạ độ.

### 13.4 Trạng thái cuối

`run_tests.py` **147/0** · `_phu_rpc.py` **510 gọi / 52 phủ** · khởi động **0 cảnh báo
trùng** · `THIEU` không phát sinh mới.

---

## 14. 27/10 (đêm muộn) — MẢNH TƯỚNG (PrizeResType 6) ĐÃ KIỂM THẬT

### 14.1 Quay hộp Đồng (miễn phí) → Mảnh Hoa Hùng

Hộp "Đồng" trên Main (Rương): còn **5 lượt miễn phí** (`LotteryFreeCountPerDay = 5`
trong `GameUserGlobalConfig`), giá thường 30.000 vàng (`LotteryCostGold`).
Rút một lượt → hộp mở, hiện **"Mảnh Hoa Hùng X2"** → bấm OK.

**Kiểm trong file lưu** (`offline_save.json`):

```
GameUserHero["47"] = { HeroFragment = 2, IsLock = true }   ← Hoa Hùng (mới, đang gom mảnh)
GameUserHero["25"] = { HeroFragment = 0, IsLock = false }
GameUserHero["2"]  = { HeroFragment = 49, IsLock = false }
```

⇒ `PrizeResType 6` chạy đúng đầu-cuối: `ClientPlayLottery` →
`G_LotteryLogic:setDataWithPrizeList` → `HeroLogic:AddHeroFragment`
(`share_HeroLogic.lua:975`) → `HeroDataManager:AddHeroFragment` ghi `HeroFragment`.
Tướng chưa có thì hàm ấy tự `addHero` (IsLock = true) rồi cộng mảnh — đúng như bản gốc.

**Đủ bộ loại thưởng đã kiểm thật trong game**: 2 Vật phẩm (Khối Vàng/EXP Đan/Dá Lam),
3 Tài nguyên (vàng, Binh Hồn), **6 Mảnh tướng (Hoa Hùng ×2)**, quà login, thưởng ải,
thưởng càn quét-tính-toán (chưa chạy càn quét vì hết lượt).

### 14.2 Toạ độ nút Túi — DỪNG, ghi lại đúng trạng thái

Đã thử ba cách, đều không chốt được con số bấm:

1. `convertToWorldSpace` → (1296,58 · 917,66) với `winSize 1366×768`; nhân tỉ lệ
   màn hình (1920×1080) ra (1823, 435) — **bấm không ăn**.
2. Log cả **chuỗi 9 lớp cha** (position + scale): chuỗi có `pos=(1080.48,386.40)
   scale=0.87`, rồi `pos=(2,560)`, `scale=1.05`… ⇒ phép biến đổi của UI root không
   phải phép nhân tỉ lệ đơn thuần; cần anchorPoint từng lớp mới tích đúng.
3. Log toạ độ ba nút đã biết để suy phép biến đổi affine — **khối chẩn đoán không
   chạy** trên lượt đó (nghi `btnBackpackUI` còn nil lúc chạy, hoặc biến toàn cục khác
   tên), và đã gỡ bỏ để bản cuối sạch.

⇒ Mở Túi **được** (bằng `g_CUIMain:onTouchEnd_onBackpackUI(btnBackpackUI, true)`) và
dữ liệu khớp (§13.2). Toạ độ **bấm tay** để lại cho lượt sau; cách chắc chắn là log
`anchorPoint` + `position` + `scale` của TỪNG lớp cha rồi tích ma trận, hoặc gọi
`btnBackpackUI:getParent():convertToNodeSpace` ngược từ một điểm màn hình đã biết.

### 14.3 Bài học công cụ

Khối chẩn đoán đặt trong `tu_dong` **phải gác cho bộ test PC**: `S_CCDirector` là nil
trong `test/mock.lua`, nên một lần đọc `S_CCDirector:getWinSize()` làm **hỏng 1 test**
(`run_tests.py` ra 146/1 với dòng `LOI: ... attempt to index global 'S_CCDirector'`).
Đã thêm `and S_CCDirector ~= nil` và bọc pcall; sau đó 147/0 trở lại.

### 14.4 Trạng thái cuối phiên

`run_tests.py` **147/0** · `_phu_rpc.py` **510 gọi / 52 phủ** · khởi động **0 cảnh báo
trùng** (hai cảnh báo cuối cùng là 21:53, trước bản vá router 22:20) · bản cuối đã gỡ
hết khối chẩn đoán, `tu_dong` chỉ còn: watchdog thưởng, đóng guide lặp, tự bấm qua
thoại hướng dẫn, log khoá hướng dẫn.

---

## 15. 28/10 (rạng sáng) — DÙNG VẬT PHẨM (nút "Dùng" trong Túi)

### 15.1 Handler mới: `handlers/vat_pham.lua`

```
CUIBackpack "Dùng" -> G_ItemLogic:UseItem(id, count)          (ClientItemLogic.lua:176)
                    -> CallServer("G_ItemLogic","ClientUseItem", id, count)
ta trả             -> G_ItemLogic:OnServerUseItem(id, count, tPrizeList)   (:197)
                      (chính hàm này phát OnReceiveResponse + OnUseItemCallback + OnUseItem)
```

**Luật là của bản gốc**: `ItemLogic:UseItem` (`share/share_ItemLogic.lua:348`) xử lý khai
báo theo `ItemType` (GiftPack/TreasureBox/Portrait) rồi `callUseItem` tra BẢNG HÀM theo
ID: `"useItem_" .. itemID` (:491-527). Bản gốc **ship sẵn** các hàm ấy — `useItem_1`
(vàng theo `Value`), `useItem_3` (kim cương), `useItem_6` (thể lực), `useItem_11/12`,
`useItem_113..116`, `useItem_GiftPack`, `useItem_TreasureBox`, `useItem_Portrait` — nên
lớp offline chỉ GỌI qua lối lớp cha `G_ItemLogic[ItemLogic]`, không chép luật.

### 15.2 Kiểm thật (Khối Vàng id 1 ×3)

Gọi đúng đường người chơi `G_ItemLogic:UseItem(1, 3)` một lần bằng harness tạm:

| | trước | sau |
|---|---|---|
| log | — | `dung vat pham 1 x3 -> true` |
| `GameUserBaseInfo.Gold` | 50.990 | **53.990** (= +3 × `Value` 1000, đúng `useItem_1`) |
| `GameUserItem["1"].ItemCount` | 10 | **7** (ReduceItem của luật gốc) |

### 15.3 Giới hạn — không bịa

* Vật phẩm KHÔNG có `useItem_<ID>` thì luật gốc trả false → handler chỉ tắt lớp đang
  tải, KHÔNG phát `OnUseItem`. Ví dụ **ID 4 (Đại Kinh Nghiệm Đan)** — không có
  `useItem_4` trong bản gốc, nên lớp offline cũng không dùng được nó; muốn tăng cấp
  thì phải đi đường khác của bản gốc.
* `tPrizeList` (GiftPack/TreasureBox) truyền `{}` vì bảng PrizeID của vật phẩm không
  được ship đầy đủ ⇒ hai loại đó bị `useItem_GiftPack` từ chối, đúng tinh thần.

`_phu_rpc.py`: **53 handler phủ**. `run_tests.py` 147/0. Bản cuối đã gỡ harness.

---

## 16. 28/10 — CÀN QUÉT CHẠY THẬT + XOAY VÒNG NHẬT KÝ

### 16.1 "Quét 1" — đường càn quét đã chạy đúng

Trước đây nút Quét luôn xám; nay ải `L_N_01_03` đã **3 sao** nên nút sáng và bấm được
(`CheckCanSweepCount` của client mới cho quét khi ải đã thắng).

| phép | kết quả đo |
|---|---|
| thể lực | 120 → **114** (−`ChapterUserFatigue` = 6, đúng luật `saveChapterBeginStatus`) |
| nhật ký | `ClientChapterSweepOnce: chua mua du luot can quet (co 0, can 1)` — nhánh MUA lượt, đúng: người chơi mới `SweepCount = 0` |
| thưởng | file lưu có **`GameUserItem["10"] = 4`** — đúng `ChapterPrizeData` của ải (`PropID 10 ×4`) do `saveChapterPrizeList(…, bSweepMode = true)` trao |
| chiến báo | `L_N_01_03`: `RatingType = 3`, `PassMissionCount = 3` (tăng qua `saveVictoryReport`) |
| vàng | **KHÔNG đổi** (53.990) — ĐÚNG luật gốc: `chapterSweepHandle` chỉ TÍNH `nResourceCount` rồi trả về cho UI hiển thị (`share_ChapterLogic.lua:2878-2955`), không `AddGold` |

⇒ `ClientChapterSweepOnce` → `mot_lan_quet` → `chapterSweepHandle` → `SetDataWithDropList`
(bọc `tReportsData`) → `saveChapterPrizeList` chạy trọn.

**Quét 10 vẫn xám**: client tự gác bằng `CheckCanSweepCount(key)` (min của
`SweepPerDay − SweepCount` với `PlayPerDay − PassMissionCount`), và ở đây nó trả < 2.
Không phải lỗi lớp offline; muốn chạm nhánh danh-sách thì phải tăng `PassMissionCount`
cho phép (chơi thêm) rồi thử lại.

### 16.2 Xoay vòng `offline.log`

`OfflineLog:open()` mở bằng `"a"` nên file phình vô hạn (đã >91.000 dòng). Nay:
quá **4 MB** thì đổi tên thành `offline.log.1` (xoá bản `.1` cũ trước), mở file mới và
ghi một dòng `da xoay vong nhat ky`.

**Đo được** (khởi động 23:39): `offline.log.1` = 5.092.183 B (giữ nguyên toàn bộ lượt
trước), `offline.log` mới chỉ vài KB, dòng đầu ghi rõ đã xoay.

### 16.3 Trạng thái cuối

`run_tests.py` **147/0** · `_phu_rpc.py` **510 gọi / 53 phủ** (router đăng ký 56 mục vì
có tên kèm obj) · khởi động sạch, không `THIEU` mới.

---

## 17. 28/10 — BÁN + GHÉP VẬT PHẨM, và vì sao "Quét 10" xám

### 17.1 Hai handler mới trong `handlers/vat_pham.lua`

| lệnh | client | luật gốc | trả cho client |
|---|---|---|---|
| `G_ItemLogic.ClientSellItem` | `ClientItemLogic:SellItem` (:125) | `ItemLogic:SellItem` (`share_ItemLogic.lua:291`) — cộng `Price × nCount` rồi `ReduceItem` | `OnServerSellItem(id, count)` (:146) |
| `G_ItemLogic.ClientSynthesisItem` | `ClientItemLogic:UI_SynthesisItem` (:81) | `ItemLogic:SynthesisItem` (:451) — đọc công thức qua `G_EquipmentLogic:GetScrollSynthesisConfig`, kiểm/trừ nguyên liệu, `AddItem` | `OnServerSynthesisItem(id)` (:102) |

**Kiểm thật (bán item 33 ×1, `Price` = 20)**: log `ban vat pham 33 x1 -> true`;
file lưu: `Gold` 53.990 → **54.010**, `GameUserItem["33"]` 1 → **0**.

Ghép: chưa có nguyên liệu/cuộn nên luật gốc từ chối — handler chỉ tắt lớp đang tải,
không báo thành công giả. (Đúng tinh thần: công thức là dữ liệu gốc, không tự tính.)

### 17.2 "Quét 10" xám là LUẬT GỐC, không phải lỗi

`CUIChapterInfo.lua:430-455` gác nút bằng `getSweepState()`, và ngay trên đó bản gốc
ghi chú: **"VIP0时，扫荡十次也为灰"** — ở VIP 0 thì nút quét mười **luôn xám**. Cổng
VIP là `__getVipCanSweep("ChapterSweepUnlockLevel")` với
`VipUnlockConfig.ChapterSweepUnlockLevel = 1`. Người chơi offline là VIP 0 ⇒ Quét 10
không dùng được; đừng "sửa" bằng cách hạ cổng — đó là bịa.

### 17.3 Trạng thái cuối

`run_tests.py` **147/0** · `_phu_rpc.py` **510 gọi / 55 phủ** · nhật ký phiên mới
**0 dòng THIEU** · bản cuối đã gỡ harness.

---

## 18. 28/10 — ĐÓNG CÂU HỎI TOẠ ĐỘ NÚT TÚI + KIỂM TÊN HANDLER + TEST ROUTER

### 18.1 Nút Túi KHÔNG hiện trên cảnh Main — không phải "chưa đo được"

Đối chiếu hai phép đo đã có:

* trong game: `btnBackpackUI` tồn tại và `getIsVisible() = true`; `getPosition() = (40,40)`;
  `getParent():convertToWorldSpace` = (1296,58 · 917,66); `winSize = 1366×768`;
* ảnh chụp cảnh Main: theo phép đổi của UI root (scale dọc 2 theo ghi chú
  `sngXgg` mục 3 — `UIRootLayer` nhân `setScale(1,2)`), world ấy rơi vào khoảng
  **(1823, 435)** trên màn 1920×1080 — **vùng trời trống**, và bấm vào đó không có gì.

⇒ Nút Túi **có tồn tại trong cây UI nhưng không được VẼ ở cảnh Main**. Bản gốc chỉ
hiện nó trong một số bước (kịch bản hướng dẫn `CGuideScheme.lua:1807` làm
`SetHighlight(btnBackpackUI, …)` rồi `coroutine.yield(btnBackpackUI)`). Vì vậy câu
"toạ độ bấm nút Túi" **không có đáp số trên cảnh Main** — không phải lớp offline đo
sai. Muốn mở Túi bằng tay thì phải làm đúng bước hướng dẫn ấy; còn lớp offline mở
được bằng chính hàm của nút (`g_CUIMain:onTouchEnd_onBackpackUI`, §13.2).

**Đừng thử lại lần nữa** trừ khi có ảnh chụp thấy nút.

### 18.2 Công cụ mới: `_phu_rpc.py --la` — bắt handler gõ sai tên

Quét ngược: handler nào đăng ký mà **không khớp bộ ba (obj, func)** nào của client
(cũng không khớp tên trơ) thì in ra. Chạy:

```
python _phu_rpc.py --la
```

Kết quả đầu tiên: 4 tên — và cả 4 đều ĐÚNG, chỉ là Lua không thấy chỗ gửi:

| tên | vì sao không thấy trong Lua |
|---|---|
| `Heartbeat` | client gọi `CallServer(SERVER.X, nil, "Heartbeat")` — obj là **nil**, regex cũ bỏ sót; đã sửa regex nhận `nil` |
| `ClientReportClientInfo`, `ClientStatistics` | **C++ (`libgame`) gửi**, không có trong Lua |
| `ClientStateWarBeginTime` | gọi qua `G_StateWarLogic:ClientStateWarBeginTime()` (khai báo ngoài Lua) |

Đã thêm bảng ngoại lệ kèm lý do; nay `--la` in **"Moi handler deu khop mot lenh client."**

### 18.3 Test router (khoá theo obj) — 5 phép kiểm mới

`test/run.lua` mục 17: đăng ký thử `TEST.TrungTen` + `TrungTen` rồi kiểm

* `getFor("TEST", …)` thấy bản có obj; `getFor("KHAC", …)` rơi về bản trơ;
* `CallServer(5, "TEST", …)` gọi bản **có obj**; `("KHAC", …)` và `("", …)` gọi bản trơ.

`run_tests.py` nay **152 đạt / 0 hỏng** (trước 147).

### 18.4 Trạng thái cuối

`_phu_rpc.py`: **511 hàm client gọi / 56 đã phủ** (regex bắt thêm `Heartbeat` với obj
nil). Nhật ký phiên mới: 0 `THIEU`. Bản dựng trên máy: mới nhất (không đổi lớp offline
trong lượt này — chỉ thêm test và công cụ).

---

## 19. 28/10 — BA HANDLER NỮA + VÁ LỚP CHẶN CỦA HƯỚNG DẪN

### 19.1 `ClientGetLivenessPrize` — nhận thưởng điểm hoạt động

`ClientAchieveLogic:CallGetLivenessPrize` (:808) gửi lệnh rồi phát
`OnWaitingForRequest`; không ai trả thì panel nhiệm vụ ngày đứng. Luật gốc
`AchieveLogic:GetLivenessPrize` (`share/AchieveLogic.lua:616`) kiểm mốc điểm hoạt
động, gọi `G_PrizeLogic:ReceivePrizeWithID(livenessPrize.PrizeID, …)` và tự phát
`Achieve.OnGetLivenessPrize` (UI `CUIDailyTask.lua:346` đang nghe). Handler chỉ gọi
rồi tắt lớp đang tải; chưa đạt mốc thì luật gốc từ chối, log warn.

### 19.2 `ClientSkipAchieve` — bỏ qua nhiệm vụ

Gọi thẳng **hàm client** `ClientAchieveLogic:SkipAchieve` (:745) — nó gọi lớp cha
`AchieveLogic:SkipAchieve` (`:529`) rồi tự đăng ký/huỷ đăng ký nhiệm vụ. Gọi lớp cha
trực tiếp sẽ thiếu phần đăng ký ấy.

### 19.3 `ClientGetPrize` (quà tuần) — trả SAI KIỂU, đã sửa

Hàm nhận là `CUIActivityLoginRewards:OnReceiveCallBack(nRewardCount)` (:147) —
**một con số**; bản cũ trả `{err = 0}` (bảng). Nay trả `0` = "chưa nhận được ngày
nào", đúng sự thật vì lịch 7 ngày là dữ liệu sinh ở máy chủ (`LoginRewardDef` chỉ có
KHOÁ, không có bảng quà).

### 19.4 `ClientPlaySoulBox` — TỪ CHỐI có lý do (2003)

Hộp hồn cần **danh sách mảnh sinh theo tuần** (`WeekHeroIDList`, `Leftime`) — không
có trong bất kỳ bảng cấu hình nào; chỉ có giá (`SoulBoxCost = 250` kim cương). Nay
trả `ErrorCode.CheckSoulBoxNotOpen = 2003` qua đường phản hồi chung: tắt lớp đang
tải, không trừ kim cương, không phát thưởng ma. (`ClientGetSoulBoxHeroFragmentList`
đã trả danh sách rỗng từ §12.)

### 19.5 Vá lớp chặn của hướng dẫn: đóng NGAY khi nó chờ sự kiện giao diện

ĐO 28/10 00:20: ngoài bước thoại, kịch bản còn bước chờ **sự kiện giao diện**
(`tListener = "OnShowUI"`). Ở bước đó nó gọi `SetSceneCanTouch(false)` — **nuốt mọi
cú bấm** — và chỉ nhả khi `FinishGudie` chạy. Chu kỳ cũ 10 nhịp để màn hình chết tới
**10 giây**, đủ phá mọi script bấm theo nhịp ngắn (đo: 3 trận tự động không vào được,
`grep -c ClientChapterCompleteSuccess` = 0).

Nay `tu_dong`: thấy `tListener` khác nil và **khác** `"GuideShowDialog"` thì đóng
ngay nhịp đó; bước thoại vẫn để watchdog tự bấm qua (giữ mạch kịch bản); ngoài ra vẫn
quét mỗi 10 nhịp.

### 19.6 Trạng thái cuối

`run_tests.py` **152/0** · `_phu_rpc.py` **511 gọi / 59 phủ** · `--la`: mọi handler đều
khớp lệnh client. Bản cuối đã gỡ harness; việc chạy trận tự động để lên cấp dời sang
lượt sau (xem §19.5 — lý do trước đó hỏng đã được vá).

---

## 20. 28/10 (khuya) — LÊN Lv6 bằng một trận thật; công thức bấm để tự đánh

### 20.1 Kết quả trận (ải `L_N_01_03`, boss 1001)

| | trước | sau |
|---|---|---|
| `Level` / `Ex` | 5 / — | **6 / 2** (`KDBGameUserConfig` Lv5 `UpgradeEx = 8`, mỗi trận +6) |
| vàng | 54.010 | **54.210** (+`ResourceCount` 200) |
| `ArmySoul` | 6 | **18** (+6 mỗi trận, cộng dồn) |
| `GameUserItem["10"]` | 4 | **5** (rơi thêm 1) |
| log | — | `ClientChapterCompleteSuccess L_N_01_03: 2 mon roi — Vat pham(id 10 x1), Tai nguyen(id 0 x6)` |

Thời gian trận: **70 giây** từ lúc bấm Chiến tới lúc có log hoàn thành (Auto + gọi lính).

### 20.2 Vì sao script 3-trận hỏng, và công thức nào chạy

Ba lần chạy nền đều ra `ClientChapterCompleteSuccess = 0`. Nguyên nhân kép:

1. **Lớp chặn hướng dẫn** ở bước `OnShowUI` — đã vá ở §19.5 (đóng ngay, không đợi 10 nhịp).
2. **Thiếu cú "gọi lính"**: trong trận, bấm Auto là chưa đủ; phải bấm cả vùng
   **"Nhập gọi lính"** (~**1150, 830**) để có quân, không thì trận kéo dài hết giờ.

Công thức chạy được (đo 28/10, 1920×1080):

| bước | toạ độ | chờ |
|---|---|---|
| Tấn Công (Main) | (1795, 990) | 4 s |
| node boss trên bản đồ | (370, 520) | 3 s |
| **Chiến** (bảng ải) | (1490, 930) | 4 s |
| **Chiến** (bảng bố trí) | (1575, 960) | 10–12 s |
| **Auto** | (100, 735) | 2 s |
| lặp: bấm qua thoại + **gọi lính** | (1600, 470) · (1150, 830) | 5 s/lần |
| Tiếp Tục (màn thắng) | (1520, 945) | 6 s |

Muốn tự động nhiều trận thì phải **kiểm trạng thái giữa các bước** (chụp màn hình hoặc
đếm `ClientChapterCompleteSuccess`), đừng bấm mù theo nhịp: node trên bản đồ có lúc
không ăn cú đầu, và màn bố trí cần thời gian dựng.

### 20.3 Cấp 6 mở gì

`VipUnlockConfig`: `MStroe2 = 6` (cửa hàng bí ẩn #2), `ActivityChapterNoCooldownLevel = 6`,
`CaverGetGoldLevel = 7`. Các toà nhà lớn vẫn khoá: Lôi Đài **Lv14**, Chiến Dịch **Lv22**,
Quân Đoàn **Lv25**, Ma Động **Lv34**, Võ Hội **Lv40**, Vân Lai **Lv60** — muốn chạm phải
cày thêm hàng chục trận (Lv6→7 cần 8 EXP, 7→8 cần 9, …).

---

## 21. 28/10 — TOUR NỐT CỘT TRÁI/THANH TRÊN; CÀY CẤP KHÔNG KHẢ THI

### 21.1 Vì sao không cày cấp để mở nội dung

`KDBGameUserConfig` (390 dòng, `UserType = 1`): `UpgradeEx` của Lv6 là **155**, Lv7 183,
Lv8 212 … Lv13 353. Từ Lv6 lên **Lv14** (mốc mở Lôi Đài) cần **2.415 EXP**; mỗi trận
`L_N_01_03` cho `ChapterUserEx = 6` ⇒ **~403 trận**. Đừng lấy cày cấp làm đường mở nội
dung. (Con số *8* thấy trước đó là dòng Lv5 trong danh sách **khác** `UserType` — đọc
nhầm cột.)

### 21.2 Ba lối vào vừa tour — đều đã có đường trả lời

| lối vào | mở ra | đường RPC |
|---|---|---|
| **D.Danh** (cột trái, 50,295) | "Quà Điểm Danh Tháng 10" — lưới quà tháng, dòng "Điểm danh **0** lần" | nút điểm danh gọi `CallAwardAchieve(0)` (`CUISign.lua:540`) → `ClientAwardAchieve` **đã có handler** |
| **7 ngày** (thanh trên) | "Quà Login Tuần" — Ngày 1–4 "Chưa đến" | dựng từ `tActivitieData.RewardCount/LoginCount` + `tActivityConfig` (danh sách PrizeID của HOẠT ĐỘNG); hoạt động offline để trống nên hiện đúng "chưa đến". `ClientGetPrize` nay trả **số 0** (§19.3) |
| **Nhận** (thanh trên, 1045,160) | panel **nhận cánh/trang phục** | log `refresh canh: con 999` — `ClientRefreshLeftWingCount` đã có handler (§8.7) |

Không phát sinh dòng `THIEU` nào trong cả ba lượt.

### 21.3 Trạng thái cuối phiên

`run_tests.py` **152/0** · `_phu_rpc.py` **511 gọi / 59 phủ** · `--la` sạch · game ở cảnh
Main, Lv6, vàng 54.210, Binh Hồn 18.

---

## 22. 28/10 — VÁ BẪY "NHẬN CÁNH" (panel không có đường thoát)

Ghi chú 26/10 (§8.7) đã ghi: panel **Nhận cánh** (`g_CUIWingGet`) mở từ thanh trên là
**modal, không có nút đóng** — BACK và bấm ra ngoài đều không thoát, phải khởi động lại.
Đo lại 28/10 00:46: `keyevent 4` **không** đóng, màn vẫn nguyên panel.

Nó được mở bằng `g_CUISubDialog:Show(g_CUIWingGet.UIName, …)` (`CUIMainTopTool.lua:1213`),
nên đóng bằng đúng `g_CUISubDialog:Close()` — lối `CUILoginReward` (:104) và
`CGuideScheme` (:480, :2230) vẫn dùng.

**Đã thêm van an toàn** vào `tu_dong`: thấy `g_CUIWingGet:IsUIShow() == true` liên tục
**30 nhịp** thì gọi `g_CUISubDialog:Close()` và ghi log. 30 giây đủ để người chơi
đọc/claim nếu đủ điều kiện (Lv10 + đăng nhập ngày 2), mà không kẹt vĩnh viễn.

**Đo được** (00:57): mở panel → 30 s sau log `tu_dong: dong panel Nhan canh sau 30s -> true`,
ảnh chụp trở về cảnh Main bình thường.

`run_tests.py` 152/0; không phát sinh `THIEU`.

---

## 23. 28/10 (tối) — CỬA HÀNG BÍ ẨN + HỘP HỒN: hai mục 1–2 của "Mai làm tiếp" (BAY-UI §6)

**ĐÍNH CHÍNH QUAN TRỌNG.** Hai kết luận cũ — *"luật sinh hàng cửa hàng bí ẩn
chỉ server gốc có"* và *"danh sách mảnh hộp hồn không có trong bất kỳ bảng cấu
hình nào"* — đều SAI. Dữ liệu nằm trong **`KDBGameCommonConfig` dưới dạng bảng
con** (`ConfigName` + `ConfigContent` là chuỗi JSON), KHÔNG phải tệp `KDB*.json`
riêng. Lần quét trước đây lọc theo TÊN TỆP nên không thấy. Ba bảng liên quan:

| bảng con | nội dung |
|---|---|
| `GameMStroeGoodsCrateConfig` | 3 cửa hàng; mỗi cửa là danh sách NHÓM `{Range, GoodsList}` + `IsLevelDepand` (theo `GoodsMap`/`MaxLevel`) + `IsNeedMaterial` |
| `GameSecretShopConfig` | 181 món: `UnitPrice`, `CurrencyType` (1 vàng / 20 kim cương), `PrizeID`, `MinGoodsCount`/`MaxGoodsCount` |
| `GameMaterialIDToMStoreGoodsID` | 54 dòng: vật liệu → mã hàng bán chính vật liệu đó (24 → {1, 101}) |
| `GameSoulBoxConfig` | bể tướng tuần/ngày, trọng số `GetRateMapFirst/Second`, `FirstLotteryCount 3` / `SecondLotteryCount 2`, bảo hiểm `MinTimesGetHero 10` / `MaxTimesGetHero 19`, `RefreshDay 3` |

### 23.1 Cửa hàng bí ẩn — `handlers/mysterious.lua` (viết lại)

* `ClientRefresh`: sinh danh sách cho các cửa ĐÃ MỞ (`VipUnlockConfig.MStroe1..3`
  — LƯU Ý hàm này so **VIP**, không so cấp người chơi: MStroe2 = VIP6, MStroe3 =
  VIP9), gọi `SetMStoreGoodsList` + `SetMStoreRefreshTime`, rồi trả đường chung
  `OnReciveResponse`.
* `ClientRefreshWithDiamond`: giá bằng hàm gốc `GetRefreshDiamond`.
* `ClientBuyGoods`: gọi NGUYÊN `MysteriousStoreLogic:BuyGoods` (kiểm mở khoá,
  `State`, `GetGoodsUnitPrice` + `IsHalfPrice`, trừ vàng/kim, `ReceivePrizeWithID`).
* **ĐẶT** (hàm sinh hàng của server không được ship): mỗi nhóm bốc `Range` món
  KHÔNG LẶP; `IsLevelDepand` lấy `GoodsMap` có `MaxLevel` nhỏ nhất ≥ cấp;
  `IsNeedMaterial` ưu tiên vật liệu ĐANG CÓ trong túi (theo bảng ánh xạ), không
  có thì lấy đều cả bảng. `Count` ngẫu nhiên trong [Min, Max].

**Đo được** (LDPlayer, 1920×1080):

| việc | kết quả |
|---|---|
| sinh hàng | `cua hang bi an 1: sinh 8 mon` (= 2+1+1+1+3, đúng `Range`) |
| mua món 2 (ID 54, mảnh tướng 11 ×3) | vàng **54.210 → 15.210** (−39.000 = 26.000 × 3 × ½), `State` món đó = **1**, `GameUserHero["11"].HeroFragment = 3` |
| mua món trả KIM CƯƠNG khi thiếu | mã **1702** (`ErrorCode.Resource.NoEnoughResource`), không trừ gì |
| nút "bán vài thứ cho tiệm" (hộp thoại của cửa hàng) | xem §23.3 |

⚠ Panel vẫn KHÔNG mở được bằng bấm ở tài khoản thử: `CGameFuncOpeningManager`
gác `CUIMysteryShop` ở **Lv18**. Đồ thử gọi thẳng
`g_CUINormalDlg:Show(g_CUIMysteriousStore:GetUIName())`.

### 23.2 Hộp hồn (魂匣) — `handlers/lottery.lua`

* `ClientGetSoulBoxHeroFragmentList`: trả `{WeekHeroIDList, DayHeroIDList,
  UpdateTime}` lấy từ `GameSoulBoxConfig`; chọn 1 tướng tuần + 3 tướng ngày
  theo MỐC THỜI GIAN (số tuần/số ngày) và giữ 3 ngày (`RefreshDay`) —
  ghi vào `GameUserGlobalData` (`SoulBoxWeek/Day/UpdateTime`).
* `ClientPlaySoulBox`: kiểm mở khoá → đủ kim cương (`SoulBoxCost = **250**`,
  trong `GameUserGlobalConfig`; `GameSoulBoxConfig.CostDiamond = 400` KHÔNG dùng)
  → trừ → quay **3 món bể MỘT + 2 món bể HAI** → phát qua
  `G_ChapterLogic:SetDataWithPrizeList` → trả `{tPrizeList = …}`.
* **Bằng chứng 5 món**: armature `HunXiaAnima` có đúng 5 điểm gắn
  `PlugIn_1..PlugIn_5` (đo bằng `sng_dump.exe arm`), khớp
  `FirstLotteryCount 3 + SecondLotteryCount 2`.
* **ĐẶT**: tướng của món Loại 5 = tướng TUẦN, mảnh (Loại 6) = một trong 3 tướng
  NGÀY; bảo hiểm đếm lượt chưa ra tướng, ngưỡng rút ngẫu nhiên trong
  [MinTimesGetHero, MaxTimesGetHero]; số lượng mỗi món ngẫu nhiên [Count, MaxCount].

**Đo được** (một lượt thật):

```
hop hon: tuan 56 · ngay 4,12,29
hop hon: tru 250 kim cuong: 1260 -> 1010 (ok=true, tra ve=true)
hop hon: 5 mon — loai 2/id 103 x1, loai 2/id 4 x3, loai 5/tuong 56 x1,
                 loai 6/tuong 4 x1, loai 6/tuong 12 x1
```

File lưu: `GameUserItem["103"] = 1`, `["4"] +6`; mảnh tướng 4 = 1, 12 = 1;
popup **"Nhận Thưởng: T.T.Hương ×1"** (tướng tuần 56); `SoulBoxPity = 1`,
`SoulBoxPityTarget = 12`.

**Hộp hồn là SỰ KIỆN, không phải tính năng thường trực.**
`ClientLotteryLogic:CheckSoulBoxIsOpen` (`ClientLotteryLogic.lua:14`) ĐÈ hàm lớp
cha và chỉ hỏi hoạt động `TimeLimitSoulBoxHero`; offline không có lịch vận hành
nên hộp hồn luôn "chưa mở" (mã 2003) dù `VipUnlockConfig.HeroSoulBoxLevel = 0`.
Nay `ClientGetActivityList` trả **một** hoạt động đó, mở thường trực — QUYẾT ĐỊNH
CỦA LỚP OFFLINE (ngày tháng do bản gốc cấp, không bịa). Kết quả: icon **R.Hồn**
hiện trên thanh trên của cảnh Main và panel mở được.

### 23.3 Handler mới: `ClientBatchUseItem` (hộp thoại "bán vài thứ cho tiệm")

Mở Cửa hàng bí ẩn ⇒ hiện `CUIMysteriousStoreQuickSell`; nút OK gọi
`G_ItemLogic:BatchUseItem()` ⇒ `ClientBatchUseItem` (**không tham số**). Trước
bản vá: `THIEU G_ItemLogic.ClientBatchUseItem`, lớp "đang tải" không tắt.

Luật: **dùng** (`UseItem`) từng món trong `UseAllItemConfig` = **[1, 2, 3, 11, 12]**
còn số lượng > 0, rồi gọi `G_ItemLogic:OnServerBatchUseItem()`.
**Đo được**: `dung het vat pham: 1 loai / 7 mon`, vàng **15.210 → 22.210**
(+7.000 = 7 × Value 1000 của Khối Vàng), 7 món biến mất.

### 23.4 Một lỗi đọc giá trị trả về đã vá

`IsEnoughDiamondToMakeLottery(type)` trả **(cờ đủ/không, giá)**. Bản đầu đọc
`local _, b = …` nên `b` là **250** (luôn ≠ true) ⇒ lượt nào cũng báo "không đủ
kim cương" dù có 1.010. Nay đọc giá trị ĐẦU.

### 23.5 Trạng thái cuối phiên

* `run_tests.py` **152/0** · `_phu_rpc.py` **511 gọi / 62 phủ**, `--la` sạch.
* `offline.log`: sau bản vá `ClientBatchUseItem` **0 dòng THIEU** mới.
* **Dữ liệu thử trong file lưu**: đồ thử `thu_hai_muc.lua` đã cấp +250 kim cương
  mỗi lượt đo (4 lượt = +1.000) để quay hộp hồn thật; hiện **1.010 kim cương**,
  vàng 22.210. Đồ thử đã **TẮT** (`OfflineThuHaiMuc.TAT = true`).
* **Còn lại của "Mai làm tiếp"**: mục 3 (Quà Login Tuần) — danh sách PrizeID là
  dữ liệu VẬN HÀNH (activity `LoginReward`), không có trong cấu hình nào; mục 4
  (đường online); mục 5 (cày cấp — không khả thi, §21.1).

---

## 24. 28/10 (khuya) — NÂNG Lv90/VIP15, MỞ KHOÁ MỌI CHỨC NĂNG, KIỂM 21 LỐI VÀO

**Sao lưu trước khi sửa:** `/data/user/0/com.cmn.buatanew/files/offline_save.json.bak_truoc_nang_cap`
+ bản trên PC `work/offline/_save_truoc_nang_cap.json` (49.917 B).

### 24.1 Đặt gì, vì sao đúng mức đó

| trường | giá trị | lý do |
|---|---|---|
| `GameUserBaseInfo.Level` | **90** | mốc cao nhất trong dữ liệu: chương cần **88** (`ChapterOpenNeedCharacterLevel`), chức năng cao nhất **60** (`CUIWorldWar`), bảng giá/hàng theo cấp tới **90** |
| `GameUserBaseInfo.Ex` | 0 | cấp đặt thẳng, không cần EXP |
| `GameUserBaseInfo.VipLevel` | **15** | `VipConfig.VipLevelRechargeList` có 16 mốc ⇒ VIP 0..15; mở `MStroe2/3` (VIP 6/9), `ChapterSweepUnlockLevel`, `FortuneWheelLevel` 9… |
| `RechargeCount` | 800.000 | mốc cuối của `VipLevelRechargeList` (để UI nạp/VIP khớp) |

Cờ mở chức năng KHÔNG suy từ cấp: bản gốc để **client** đặt cờ
`G_UserLogic:SetGameFuncUnLockData(<tên>, true)` (khoá `L_<tên>` trong
`GameUserGlobalData`) khi đạt cấp — bảng cấp ở `CGuideEvent:CheckOpenFunc`
(`CGuideEvent.lua:409`). Offline chép đúng bảng ấy + mọi tên client ĐĂNG KÝ
(`CGameFuncOpeningManager.FuncLockMap`). Kết quả: **27 cờ** (CUIArena 14 ·
CUIMysteryShop 18 · CUIActivityMode 22 · CUIGuildControl 25 · CUIAchieve/CUILeaderboard 28 ·
CUITurnplate 30 · CUIDen 34 · CUIQuest 35 · CUIDestiny 36 · CUISB 37 · HeroFightSoul 38 ·
EquipmentRefine/CUIContest 40 · CUIMainEvilCastle 45 · CUIXingHun 50 · CUIWorldWar 60 …).

Đồ thử: `sc/offline/nang_cap.lua` (một lượt, **đã tắt**).
Kết quả trên cảnh Main: **mọi nhãn "LvX mở" biến mất**, thanh cấp hiện "Max Lv".

### 24.2 Kiểm 21 lối vào — đồ thử `sc/offline/luot_panel.lua`

Mở bằng ĐÚNG hàm nút bấm gọi (`CUIMainBuildingManager:_btnMain*`), 6 nhịp/panel,
đóng bằng `g_CUINormalDlg:Close()` / `g_CUISubDialog:Close()`.

| # | panel | # | panel | # | panel |
|---|---|---|---|---|---|
| 1 | Hộp Thư | 8 | Quân Đoàn | 15 | Ma Thành |
| 2 | BXH | 9 | Võ Hội | 16 | Bản đồ (Tấn Công) |
| 3 | T.Mệnh | 10 | Chợ Đen | 17 | Đấu Trường |
| 4 | Chiến Dịch | 11 | Mỹ Dung Viện | 18 | Thương Nhân |
| 5 | **Shop Thần Bí** | 12 | Nghiên Cứu | 19 | Vân Lai |
| 6 | Ma Động | 13 | Rương (quay) | 20 | **Hộp Hồn** |
| 7 | Lôi Đài | 14 | Binh Doanh | 21 | **Túi** |

**Kết quả: 21/21 mở được, 0 panel ném lỗi.** Ảnh chụp trong lúc chạy:
`_p01.._p21.png`. Shop Thần Bí hiện đủ 8 món + giá + "Sale 50%" + "Đã bán hết"
cho món đã mua + đếm ngược làm mới + nút "Làm Mới".

### 24.3 Năm handler thiếu phát hiện được — và cách trả lời

| RPC | trả lời | ghi chú |
|---|---|---|
| `G_RankLogic.ClientGetLevelRank` | `OnGetLevelRank({}, 0, 0)` | BXH rỗng là hợp lệ (offline không có người chơi khác) |
| `G_GuildLogic.ClientRefreshUserGuild` | `OnRefreshUserGuild()` | không có quân đoàn |
| `G_GuildLogic.ClientGetRandGuildList` | `OnGetRandGuildList(0, {})` | danh sách xin vào quân đoàn rỗng |
| `G_UserLogic.ClientSetGameFuncUnLockData` | **nuốt lặng** | máy chủ gốc chỉ lưu cờ; client đã tự ghi `L_<tên>` trước khi gửi |
| `G_ArenaLogic.GetUserArenal` | **lỗi 2306** (`GetUserArenaDataFaild`) | đấu trường là máy chủ nhiều người chơi — KHÔNG có dữ liệu để dựng, không phát dữ liệu ma |
| `G_PkProtocol.ClientGetData` | **lỗi 6700** (`Pk.PkNotOpen`) | Đấu Trường Anh Hùng cũng vậy; `G_PkProtocol` dựng bằng `bindRpcToEvent` nên `_phu_rpc.py --la` phải thêm ngoại lệ có lý do |

⇒ Ba hệ **Đấu Trường / PK / Quân Đoàn** mở được panel nhưng nội dung rỗng hoặc
báo "chưa mở": đó là dữ liệu nhiều người chơi, không nằm trong cấu hình.

### 24.4 Cổng kiểm

`run_tests.py` **152/0** · `_phu_rpc.py` **511 / 66** · `--la` **sạch** ·
lượt kiểm cuối **0 dòng THIEU** · mọi đồ thử đã **TẮT** (`nang_cap`, `luot_panel`,
`thu_hai_muc`) và bản sạch đã dựng + đẩy.

⚠ File lưu dev giờ là **Lv90 / VIP15** (sửa có chủ ý theo yêu cầu); muốn quay lại
thì chép `offline_save.json.bak_truoc_nang_cap` đè lên.

---

## 25. 28/10 (đêm) — NỐI 19 LỆNH VÀO LUẬT GỐC + hai phát hiện về HỆ THUỐC và lỗi làm treo game

### 25.1 Cách tìm "lệnh thiếu mà luật đã có"

Đối chiếu 445 lệnh còn thiếu (`_phu_rpc.py --thieu`) với các hàm
`function <X>Logic:<Tên>` trong `sc/share/**/*.lua` — **trùng tên sau khi bỏ tiền
tố `Client`** thì chỉ cần GỌI luật, không viết lại. Ra **32** lệnh; đã nối **19**
vào `handlers/tinh_nang.lua`:

| hệ | lệnh |
|---|---|
| Thiên mệnh | `ClientActiveProgress`, `ClientActiveProgressWithCount` |
| Trang bị | `ClientIntensifyEquipment`, `ClientAutoIntensifyEquipment`, `ClientPromoteQualityEquipment`, `ClientRecastEquipment` |
| Tướng | `ClientUpgradeHeroGrowthFactor`, `ClientUpgradeHeroQualityPromotion`, `ClientUseHeroExperiencePill`, `ClientRecruitHero`, `ClientBreakthroughHeroMaxLevel`, `ClientGetTopFightCapacity`, `ClientEquipHreroSkin`, `ClientTakeOffHreroSkin` |
| Đấu trường | `ClientBuyArenaGoods`, `ClientRefreshFightTime` (cả biến thể ARENA_SERVER) |
| Thành tựu | `ClientUpdateFreeStrengthState` |
| Thuốc | 4 lệnh — xem 25.3 (trả lời TỪ CHỐI, không chạy) |

**HAI KIỂU phải phân biệt** (ghi trong đầu tệp `tinh_nang.lua`):
* *Kiểu A* — hàm nhận phía client chỉ vẽ lại ⇒ máy chủ PHẢI chạy luật rồi trả lời.
* *Kiểu B* — hàm nhận TỰ CHẠY luật (`ClientPotionLogic:OnUpgradePotion` gọi
  `self:UpgradePotion`) ⇒ máy chủ chỉ trả OK, gọi thêm là trừ hai lần.

### 25.2 Đo trên trình giả lập (9 mục, `thu_tinh_nang.lua`)

| mục | kết quả |
|---|---|
| Thiên mệnh · Tăng hệ số · Tăng phẩm · Trang bị tăng phẩm · Thành tựu | chạy, không ném lỗi |
| Trang bị cường hoá | luật gốc từ chối mã **1307** (thiếu nguyên liệu) — trả lời đúng |
| Đấu trường mua đồ | từ chối mã **1** (0 danh vọng) — trả lời đúng |
| Tướng đột phá | từ chối mã **1**, nhưng lặp 14 lần/giây ⇒ sự kiện của client tự gọi lại — **cần vá** |
| Tướng tăng hệ số | **`class.lua:65 C stack overflow`** — traceback: `CUIManager:InsertAnimation` → `CUIDialogAnimation:functionPointr`; lỗi nằm ở hệ hoạt ảnh hộp thoại khi KHÔNG có panel tướng mở ⇒ chưa kết luận, phải thử lại từ trong UI tướng |

### 25.3 HỆ THUỐC (丹药) CHẾT TRONG CHÍNH BẢN GỐC

Traceback đầy đủ khi gọi `ClientUpgradePotion`:
`PotionDataManager:updatePotionData` (:762) → `ClientConfigManager:GetConfigWithNameArg`
(:95) → `self.configCacheName.PotionConfig` **nil** → `class.lua:66 'table index is nil'`.

Nguyên nhân: `share/share_configManager.lua` **đã chú thích sẵn** hai dòng
`--PotionConfig` (:129) và `--PotionUnlockConfig` (:146) — client bản này KHÔNG
nạp bảng thuốc (tệp `KDBGamePotionConfig.json` có trong gói nhưng không dùng).
⇒ Bốn lệnh thuốc nay TRẢ LỖI ngay, không gọi hàm nhận (gọi sẽ nổ), log một dòng.
KHÔNG thêm cấu hình thuốc bằng tay — đó là bịa.

### 25.4 Bẫy mới: deploy một tệp Lua SAI CÚ PHÁP làm game TREO Ở SPLASH

Bản `tinh_nang.lua` đầu tiên dùng `...` trong hàm lồng (`pcall(function() ... end)`)
⇒ `offline.init` require lỗi ⇒ cả lớp offline KHÔNG nạp ⇒ game đứng ở màn hình
splash, `offline.log` không có dòng "phien moi" nào, logcat vẫn in
`lua_ProtoRPC::ImportProtoFile` liên tục (dễ tưởng là treo mạng).

**Quy tắc: chạy `python -I run_tests.py` TRƯỚC mỗi lần `build.py`/`deploy.py`.**
Nó `require("offline.init")` nên bắt ngay lỗi cú pháp (152/0).

### 25.5 Trạng thái cuối

`run_tests.py` **152/0** · `_phu_rpc.py` **511 / 88** (trước phiên: 66) ·
`--la` sạch · `offline.log` không có `THIEU` mới cho 19 lệnh này ·
đồ thử `thu_tinh_nang.lua` đã **TẮT**.

**Còn phải làm (theo thứ tự):** vá vòng lặp "đột phá tướng"; thử tăng hệ số từ
trong UI tướng; rồi tới nhóm còn lại của 32 lệnh: `ClientUpgradeBuilding`,
`ClientCompleteBuildingUpgrade`, `ClientAwardDailyTask`, `ClientRecruitHero` (cần
UI), `ClientGetCharacterFreeWing/ChargeWing`, `ClientFreeRoll/VipRoll` (vòng quay
cần luật SINH giải — `GameFortuneWheelConfig` có trọng số nhưng hàm quay chỉ đếm
lượt, phần chọn giải server không được ship).

---

## 26. 28/10 (đêm muộn) — GỐC RỄ "GỌI LẶP 14 LẦN/GIÂY": gọi trúng WRAPPER CLIENT

### 26.1 Bệnh

Sau §25, hai lệnh tướng bị gọi lặp 14 lần/giây. Traceback (bật bằng `xpcall` +
`debug.traceback` trong `offline/net.lua:227`):

```
handler tinh_nang → chay() → luật → ClientHeroLogic.lua:99 → net.lua CallServer → handler → …
```

**Nguyên nhân:** `G_HeroLogic` là thể hiện của `ClientHeroLogic = class(HeroLogic)`,
và lớp client **ĐÈ** đúng những tên ấy bằng hàm GỬI REQUEST:

| tên | bản client |
|---|---|
| `UpgradeHeroGrowthFactor` | `ClientHeroLogic.lua:65-66` |
| `UpgradeHeroQualityPromotion` | `:97-99` |
| `BreakthroughHeroMaxLevel` | `:166-168` |
| `UseHeroExperiencePill`, `RecruitHero`, `GetTopFightCapacity` | cùng kiểu |

Gọi `G_HeroLogic:UpgradeHeroQualityPromotion()` là gọi **bản client** ⇒ nó lại
`CallServer` ⇒ quay lại handler ⇒ đệ quy. Vì thế các lệnh ấy "từ chối mã 1" và lặp.

**Cách chữa (giống `handlers/vat_pham.lua`):** lấy bảng proxy của LỚP CHA mà
`class()` gắn lên mỗi thể hiện — `o[HeroLogic][ten]` — rồi gọi với `self = proxy`
(wrapper tự buộc `self` về thể hiện). Tên lớp cha suy từ tên biến: `G_HeroLogic`
→ `HeroLogic`. Kèm **chốt chống lặp**: quá 6 lần/giây thì không gọi luật nữa và
ghi traceback một lần.

Sau khi sửa: **không còn vòng lặp, không còn `C stack overflow`**; các lệnh trả mã
lỗi thật của luật (1307 = thiếu nguyên liệu; 1 = không đủ điều kiện).

### 26.2 Thêm 4 lệnh (tổng 23 lệnh nối vào luật gốc)

| lệnh | luật | ghi chú |
|---|---|---|
| `ClientUpgradeBuilding` | `BuildingLogic:UpgradeBuilding` | trả **nil, id** khi được; **ErrCode** khi hỏng |
| `ClientCompleteBuildingUpgrade` | `BuildingLogic:CompleteBuildingUpgrade` | như trên |
| `ClientCompleteBuildingUpgradeWithDiomaon` | `...WithDiamond` | tên có lỗi chính tả trong CHÍNH client — giữ nguyên để khớp |
| `ClientAwardDailyTask` | `DailyTaskLogic:AwardDailyTask` | xem 26.3 |

### 26.3 Hai hệ KHÔNG nối được (ghi rõ, không bịa)

* **Nhiệm vụ ngày**: `share/share_dailyTask.lua` có lớp `DailyTaskLogic` nhưng
  **không có thể hiện toàn cục** (`G_DailyTaskLogic` = nil) — client không dùng
  lớp này. Muốn chạy phải tự dựng thể hiện + tự quản trạng thái "đã nhận", tức
  viết lại luật. **Chưa làm.**
* **Thuốc**: chết trong bản gốc (§25.3).

### 26.4 Trạng thái cuối

`run_tests.py` **152/0** · `_phu_rpc.py` **511 / 92** (đầu phiên: 66) · `--la` sạch ·
11 mục đồ thử chạy không lỗi/không lặp · đồ thử **TẮT**, bản sạch đã dựng + đẩy.

**Còn lại của nhóm 32 lệnh:** cánh/trang phục (`GetCharacterFreeWing`,
`GetCharacterChargeWing`), vòng quay (`FreeRoll`/`VipRoll` — luật chỉ đếm lượt,
phần CHỌN GIẢI của server không được ship; cấu hình `GameFortuneWheelConfig` có
trọng số nên có thể dựng như `lottery`), nhóm nhiệm vụ ngày (26.3).

---

## 27. 28/10 (đêm) — CÁNH MIỄN PHÍ (đo được lần ĐẦU chạy TRỌN) + HÀNG MA KHU + một bảng lọt `TABLES`

### 27.1 `ClientGetCharacterFreeWing` — lần đầu chạy TRỌN một luật gốc

`ClothingLogic:GetCharacterFreeWing` (`share/share_ClothingLogic.lua:527`) TỰ phát
`Active.OnGetFreeWing`; panel `CUIWingGet` đăng ký đúng sự kiện ấy
(`CUIWingGet.lua:172`), nên handler chỉ gọi + đồng bộ + tắt lớp tải.

**Đo được:**

```
nhan canh mien phi: da cap
```

File lưu: `GameUserGlobalData.HasGetCharactorFreeWing = true`,
`GameUserHero["25"].WingID = 1 · WingLevel = 1` (cánh miễn phí đã vào nhân vật).
Lượt sau gọi lại ⇒ luật từ chối mã **1** — đúng (đã nhận rồi).

Cùng lượt đo thêm `ClientGetCharacterChargeWing` (điều kiện nạp tiền ⇒ sẽ từ chối
trên tài khoản thử).

### 27.2 Hàng Ma Khu — sinh từ `GameCavernGoodsCreateConfig`

`CavernLogic` chỉ có `BuyCavernGoods` (đọc `userCavern.GoodsList`), không có hàm
sinh; nhưng cấu trúc y hệt cửa hàng bí ẩn: `GameCavernGoodsCreateConfig` = **13
nhóm** `{Range, GoodsList}`, `GameCavernGoodsConfig` = 36 món
`{UnitPrice, CurrencyType 3 = tiền Ma Khu, PrizeID, MinGoodsCount/MaxGoodsCount}`.

Đã thêm vào `handlers/cavern.lua`:
* `ClientRefreshGoodsList` — sinh lại danh sách (miễn phí);
* `ClientRefreshGoodsWithCurrency` — trả tiền theo hàm gốc `GetRefreshCurrency`
  (10/50/100/+50), trừ `CavernCurrency`, tăng `RefreshGoodsCount`.

**Đo:** `Ma Khu: lam moi hang (mien phi) -> 17 mon` (bằng tổng `Range` của 13 nhóm);
file lưu có `GameUserCavern.GoodsList` 17 món `{ID, Count, State}`.

⚠ **Bẫy bảng lọt `TABLES`** (mục 4 của BAY-UI, nay có thêm một ca): lần đầu hàng
sinh ra nhưng file lưu vẫn `"GameUserCavern": null` — vì `OfflineStore.TABLES`
KHÔNG có `GameUserCavern` nên `syncFromClient` bỏ qua. Đã thêm vào `TABLES`
(kèm ghi chú); đồng thời handler chép thẳng `OfflineStore.data.GameUserCavern`
từ `G_CavernDataManager:GetUserCavern()` để không phụ thuộc đường đồng bộ.

### 27.3 Trạng thái cuối

`run_tests.py` **152/0** · `_phu_rpc.py` **511 / 96** (đầu phiên: 66) · `--la` sạch ·
đồ thử **TẮT**, bản sạch đã dựng + đẩy.

**Còn lại:** vòng quay may mắn (`FreeRoll`/`VipRoll` — luật chỉ đếm lượt; DANH SÁCH
bánh xe do server sinh, cấu hình chỉ có trọng số 3 bể và 3 danh sách giải
15/8/5 món; UI `CUIActivityTurnplate` lại gắn với HOẠT ĐỘNG `Turnplate` mà offline
chưa có) · quét nhanh Ma Khu · nhiệm vụ ngày (không có thể hiện `G_DailyTaskLogic`).

---

## 28. 28/10 (khuya) — VÒNG QUAY: SERVER SINH DANH SÁCH 12 Ô TỪ CẤU HÌNH

### 28.1 Ràng buộc đọc từ client

`CUIActivityTurnplate:initItemIcon` (`user/UI/CUIActivityTurnplate.lua:365-368`)
**bỏ qua toàn bộ** nếu `#tWheelList ~= 12` ⇒ bánh phải có ĐÚNG **12 ô**, mỗi ô
`{PrizeID = <mã giải>}` (`:372`), cờ `IsEmpty` tuỳ chọn (`:375`). UI lấy danh sách
từ `userTurnplate.FreeWheelList` / `VipWheelList`.

### 28.2 Luật sinh (SUY, vì server giữ kín)

| bánh | xác suất cấu hình | số ô theo tỉ lệ | đo được |
|---|---|---|---|
| Free | 0,9 : 0,1 : 0 | **11 ô bể 1 + 1 ô bể 2** | `60015 60008 60003 60013 60008 60003 60009 60001 60013 60009 60008 …60018` ✔ đúng 1 ô bể 2 |
| Vip | 0 : 0,6 : 0,4 | **7 ô bể 2 + 5 ô bể 3** | `60022 60016 60019 60017 60023 60018 60020 | 60028 60028 60024 60026 60028` ✔ |

Số ô mỗi bể = `round(xác suất × 12)`, phần dư dồn bể 1; trong bể bốc ĐỀU, CÓ LẶP
(bể chỉ có 15/8/5 mã). Khi quay: chọn BỂ theo đúng xác suất cấu hình rồi chọn đều
một ô thuộc bể ấy ⇒ tỉ lệ trúng khớp cấu hình mà không cần luật nào thêm.

### 28.3 Phần đã có luật gốc (chỉ gọi)

`FortuneWheelLogic:FreeRoll()` (lượt/6 giờ? + đếm), `:VipRoll()` (cổng VIP
`FortuneWheelLevel`, trừ kim cương theo `GetVipRollDiamond`), `SetFreeWheelList`,
`SetVipWheelList`. Phần CHỌN GIẢI là của server ⇒ viết ở `handlers/vong_quay.lua`.

Báo UI: `FortuneWheel.OnRefreshFortuneWheelList` (không có hàm nhận `OnServer…`
nên phát tay), `OnFreeRoll(index)`, `OnVipRoll({Index = …})`.

### 28.4 Đo được

```
vong quay: sinh 2 banh 12/12 o
vong quay FreeWheel: o 6, giai 60003 -> true
vong quay VipWheel: o 1, giai 60022 -> true
```

File lưu: `GameUserFortuneWheel.FreeWheelList` 12 ô, `VipWheelList` 12 ô,
`HasRollFreeWheelCount = 1`, `HasRollVipWheelCount = 1`; kim cương **1010 → 810**
(VipRoll trừ 200). **Phải thêm `GameUserFortuneWheel` vào `OfflineStore.TABLES`**,
nếu không hai danh sách sinh ra sẽ mất sau lần vào game sau (cùng bẫy §27.2).
Vì thế test "đủ 36 bảng" đổi thành **37**.

### 28.5 Trạng thái cuối

`run_tests.py` **152/0** · `_phu_rpc.py` **511 / 99** · `--la` sạch · đồ thử **TẮT**.

**Còn thiếu:** `ClientRunNewServerDailyWheel` / `ClientGetNewServerDailyWheelPrizeList`
(bánh "tân thủ 7 ngày" — `NewServerDailyWheel.PrizeID 91234` +
`DayMaxIndexList [4,4,4,4,6,6,7]`, luật khác hẳn), quét nhanh Ma Khu, nhiệm vụ ngày.

---

## 29. 28/10 (khuya) — BÁNH "TÂN THỦ 7 NGÀY": chỉ thiếu SỐ NGẪU NHIÊN

### 29.1 Luật gốc đã có trọn ba mảnh

| hàm trong `FortuneWheelLogic` | việc |
|---|---|
| `getNewServerDailyWheelPrizeListConfig()` | đọc `GameFortuneWheelConfig.NewServerDailyWheel` (`PrizeID 91234`, `DayMaxIndexList [4,4,4,4,6,6,7]`) + `PrizeContent` của prize 91234 → danh sách giải |
| `getNewServerDailyWheelPrizeList(tRandList)` | XÁO danh sách bằng chính các số ngẫu nhiên máy chủ gửi (Fisher-Yates), nhớ vào `NewServerWheelOutOfOrderPrizeList` |
| `runNewServerDailyWheelWithRand(nRand)` | chọn ô theo `DayMaxIndexList` của ngày hiện tại, đánh dấu ô đã trúng, CẤP THƯỞNG bằng `SetDataWithPrizeList`, tăng `TimesCount`, tự phát `FortuneWheel.NewServerDailyWheelWithRand`; trả `(ok, err, nGetIndex)` |

⇒ Máy chủ chỉ phải sinh `math.random()`; phần còn lại gọi luật.

### 29.2 Đo được

```
vong quay tan thu: danh sach 7 giai
vong quay tan thu: trung o 3
```

File lưu: `NewServerDailyWheelCount = 1` (hôm nay đã quay), `TimesCount = 2` (sang
ngày kế), `NewServerDailyWheelList = [null, null, true]` (ô 3 đã trúng),
`NewServerWheelOutOfOrderPrizeList` 7 phần tử (bản đã xáo, giữ cho cả ngày).

Điều kiện của bản gốc: `checkIsCanRunNewServerDailyWheel` đòi
`G_AchieveLogic:GetSevenDayLeftDay() > 0` **và** `NewServerDailyWheelCount == 0`
(mỗi ngày một lượt). Save thử còn trong 7 ngày tân thủ nên chạy được; quá hạn thì
luật từ chối mã `CanNotRunNewServerDailyWheel` — đúng, không phải lỗi lớp offline.

### 29.3 Trạng thái cuối

`run_tests.py` **152/0** · `_phu_rpc.py` **511 / 101** · `--la` sạch · đồ thử **TẮT**.

**Còn thiếu:** quét nhanh Ma Khu (`ClientCavernSweepAll`/`ClientCavernDirectSweep` —
luật quét của server không ship; chỉ có bảng giá `GameCavernSweepCost`), nhiệm vụ
ngày (`G_DailyTaskLogic` không tồn tại phía client).

---

## 30. 28/10 (khuya) — NHIỆM VỤ NGÀY: nối được phần NHẬN, thiếu phần ĐIỀU KIỆN

### 30.1 Phần nối được

`ClientAwardDailyTask` (gửi từ `CServerRequestLogic.lua:416`, obj **rỗng**) →
`DailyTaskLogic:AwardDailyTask(taskId, equipList)` (`share/share_dailyTask.lua:42`):
đặt `AchieveState.Award` trong `GameUserDailyTask`, đọc `PrizeList` của nhiệm vụ,
phát qua `g_CPrizeLogic`.

Hai điều phải làm thêm (đã làm trong `handlers/achieve.lua`):
* lớp `DailyTaskLogic` **có nhưng client không tạo thể hiện** (`G_DailyTaskLogic`
  = nil — bản gốc chạy nó ở máy chủ) ⇒ tạo `DailyTaskLogic:new()` tại chỗ;
* **cổng trạng thái**: chỉ nhận khi `task.State == AchieveState.Done` (= 2).
  Không có cổng này thì bấm "Nhận" nhiệm vụ nào cũng phát thưởng vô hạn.

**Đo:** `nhiem vu ngay 1: trang thai 1 (can Done = 2)` — tức cổng chạy đúng.

### 30.2 Chỗ KHÔNG dựng lại được (đo, không suy)

* `GameUserDailyTask` trong file lưu là **bảng rỗng** — không ai sinh danh sách
  nhiệm vụ của ngày. `KDBGameDailyTaskConfig.json` chỉ có **8 dòng**
  `{TaskId 1..8, Name ("午餐"…), Award}`: **KHÔNG có điều kiện hoàn thành**.
* Trong `share/share_dailyTask.lua` chỉ có **`checkTask1`** (giờ trong 0..24 ⇒ luôn
  đúng); **không có `checkTask2..8`** — điều kiện của 7 nhiệm vụ còn lại nằm ở
  mã máy chủ, không được ship.
* Lệnh `ClientComplelteDailyTask` (đánh dấu hoàn thành) cũng không có luật tương ứng.

⇒ Muốn "nhiệm vụ ngày chạy" phải BỊA điều kiện, nên dừng ở đây: phần NHẬN đúng
luật + đúng cổng; phần SINH DANH SÁCH và ĐIỀU KIỆN để trống.

### 30.3 Quét nhanh Ma Khu — cũng dừng, vì cùng lý do

`GameCavernSweepCost` chỉ có **giá** (`AllSweep 600`, `DirectSweep` theo tầng);
luật quét của máy chủ không được ship. Đường "tự đánh hộ" (`CavernLogic:
CompeleteFight`) đòi `fightHeroStateMap` + `CheckFight` với trạng thái tướng thật
— dựng khống trạng thái trận là BỊA dữ liệu trận, nên không làm.

### 30.4 Trạng thái cuối phiên

`run_tests.py` **152/0** · `_phu_rpc.py` **511 / 101** · `--la` sạch ·
đồ thử **TẮT**, bản sạch đã dựng + đẩy.

---

## 31. 28/10 (khuya) — NHIỆM VỤ NGÀY (sinh bảng + đặt lại theo ngày) và QUÉT MA KHU

Chủ dự án chốt: **được phép tự đặt chính sách** cho hai chỗ server gốc không ship,
miễn ghi rõ đâu là dữ liệu gốc, đâu là quyết định của lớp offline.

### 31.1 Nhiệm vụ ngày — `handlers/nhiem_vu_ngay.lua` (mới)

* **Sinh danh sách**: đọc 8 dòng `KDBGameDailyTaskConfig` bằng cách dò
  `GetDailyTaskConfigWithId(1..50)` (chỉ có hàm tra TỪNG dòng), tạo thiếu thì thêm
  `{TaskId, AchieveType = TaskId, State = Doing}`.
* **Đặt lại theo ngày**: mốc **5 giờ** (`DialyRefreshHour`); sang ngày mới thì mọi
  nhiệm vụ về `Doing`, ghi `GameUserGlobalData.DailyTaskDay`.
* **Hoàn thành**: `ClientComplelteDailyTask(taskId)` → `Done` (tin client — chế độ
  offline client chính là game thật).
* **Nhận**: `handlers/achieve.lua` — cổng `State == Done`, thưởng lấy từ cấu hình,
  đánh dấu `Cleared`.

**Hai phát hiện khi làm:**

1. `DailyTaskLogic:AwardDailyTask` **lỗi thời** so với gói này — gọi
   `G_DataManager:SetDailyTaskWithId` nhưng hàm thật viết thường
   `setDailyTaskWithId` (`share_CDataManagerPrivate.lua:1006`) ⇒ nil. KHÔNG sửa
   hàm gốc, mà dựng lại ba bước từ dữ liệu.
2. Lúc NẠP cấu hình, khoá `Award` trong JSON được **đổi tên thành `PrizeList`**
   (khoá thật lúc chạy: `TaskId, Name, PrizeList`) — nên hàm gốc đọc
   `taskCondig.PrizeList` là đúng; bản đầu tôi đọc `Award` nên báo thiếu.
3. Danh sách nhiệm vụ nằm ở **`userData.DailyTaskList`** (KHÔNG phải
   `GameUserDailyTask`) — `CDataManager:getDailyTaskList`
   (`share_CDataManagerPrivate.lua:975`). Đã thêm `DailyTaskList` vào
   `OfflineStore.TABLES`; test đếm bảng đổi 37 → **38**.

**Đo:**

```
nhiem vu ngay: 8 nhiem vu (moi/dat lai: 8)
nhiem vu ngay 1: danh dau hoan thanh
nhiem vu ngay 1: da phat 1 mon
```

File lưu: `DailyTaskList` 8 phần tử, task 1 `State = 3` (đã nhận), còn lại `1`;
thể lực **120 → 180** (+60, đúng `AddFatigue` của nhiệm vụ 午餐).

**QUYẾT ĐỊNH CỦA LỚP OFFLINE (không phải dữ liệu gốc):** `AchieveType = TaskId`;
điều kiện hoàn thành do client báo, không tự tính (7/8 nhiệm vụ không có điều kiện
trong bất kỳ tệp nào — §30).

### 31.2 Quét nhanh Ma Khu — `handlers/cavern.lua`

Luật quét của server không ship; đường `CompeleteFight` đòi trạng thái tướng thật
⇒ **chọn cách chủ dự án nêu**: quét phần ĐÃ QUA.

* `ClientCavernDirectSweep` — quét tầng đã qua gần nhất (`CurrentProgress - 1`),
  giá `GameCavernSweepCost.DirectSweep[tầng]`;
* `ClientCavernSweepAll` — quét mọi tầng đã qua (1 … `CurrentProgress-1`), giá
  `AllSweep`;
* thưởng **chỉ vàng**, theo ĐÚNG công thức gốc `GetGoldCountWithPassLevel`
  (130 × cấp tướng/6 × tầng, cộng hệ số VIP) — không phát lại rương tầng;
* trừ **tiền Ma Khu** (ĐẶT: bảng giá không ghi loại tiền).

**Đo:** `Ma Khu quet tat ca: tang 1..4, gia 600, vang +29250`
(tướng Lv90: 130 × 15 × (1+2+3+4) = 19.500, ×1,5 hệ số VIP = 29.250 ✔).

Đồ thử đã đẩy tạm `CurrentProgress = 5` + 1.000 tiền Ma Khu để đo; các lượt sau
chỉ số này nằm trong file lưu dev.

### 31.3 Trạng thái cuối

`run_tests.py` **152/0** · `_phu_rpc.py` **511 / 104** · `--la` sạch ·
đồ thử **TẮT**, bản sạch đã dựng + đẩy.

---

## 32. 28/10 (đêm) — ĐẤU TRƯỜNG: panel SỐNG LẠI (hạng + đối thủ + cửa hàng)

Trước bản này, mở Lôi Đài là báo lỗi **2306** ngay vì không ai trả `GetUserArenal`.
`handlers/dau_truong.lua` (mới) làm phần DỮ LIỆU MÀN HÌNH:

| lệnh | làm gì |
|---|---|
| `GetUserArenal` | trả hạng của mình (`GameUserArenaRank.Ranking`; chưa có ⇒ 1000, ghi rõ là ĐẶT) ⇒ `OnGetUserArenal("1000")` |
| `GetSearchList` | dựng **1 đối thủ** từ `GameArenaRobotConfig` (`Uid 3578`, `FightData.Groups → Soldiers`) — lưu ý khoá thật trong cấu hình là `"Groups "` **có dấu cách cuối** |
| `ClientRefreshUserArenaGoods` | sinh cửa hàng danh vọng từ `GameArenaGoodsCrateConfig` (15 nhóm) + `GameArenaGoodsConfig` (27 món) |
| `ClientAddArenaFightCount` | gọi luật gốc `ArenaLogic:AddFightCount` |

**Đo (ảnh `_arena2.png`):** panel hiện `Hạng 1000`, `XH tốt nhất 1000`, `Hnay còn lượt 5/5`,
đối thủ **`Robot 3578` — Hạng 999**, nút "Chiến". Log:
`dau truong: hang hien tai 1000` · `danh sach dau 1 doi thu`.

**KHÔNG làm trận:** `ArenaFightRanking` phải trả `FightData` đầy đủ (`BaseInfo`,
`Groups[*].Soldiers`) + `FightHeroList` + `BattleRandom` cho màn bố trí
(`CUIBattleDeploy:OnArenaFightLocalArmy`). Cấu hình chỉ có **MỘT** robot mẫu, không
có tên/hạng/lực chiến ⇒ dựng trận là bịa dữ liệu trận. Các nút còn lại
(Chiến · BXH · Quả Lôi · Chiến báo · Đổi quà) được đăng ký trả **mã 2306 ngay**
để tắt lớp "đang tải" thay vì treo màn hình.

**Quyết định của lớp offline (ghi rõ):** hạng mặc định 1000; tên robot
`"Robot <uid>"`; lực chiến robot = lực chiến người chơi (cấu hình không có).

### Trạng thái cuối

`run_tests.py` **152/0** · `_phu_rpc.py` **511 / 107** · `--la` sạch ·
`offline.log` không `THIEU` mới; bản sạch đã dựng + đẩy.
