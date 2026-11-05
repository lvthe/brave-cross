# Ghi chú phiên runtime-trace — 23/10/2026 (dừng lúc 05:04, làm tiếp hôm sau)

Mục tiêu phiên: chạy `frida/trace_danh.js` trong **một trận thật** trên emulator ARM
để đo khoảng cách/hit-box lúc engine gốc quyết định đánh (bốn hàm `vfunc_211`,
`FUN_00425336`, `FUN_00424930`, `CDFDamage_Compute`).

**Kết quả: CHƯA có số đo.** Đã phá được cổng chặn lớn nhất (đăng nhập SDK), còn lại
là độ ổn định của máy ảo.

---

## 1. Cổng chặn thật: panel "Đăng Nhập" là của KULL SDK, không phải của game

Screenshot màn chặn có `Ver_2.0.3` (không phải `Ver. 1.26.5` của game) và nút
`Chơi nhanh` / `Login With Facebook`. Đó là `com.kull.sdk.ui.activities.KullSDKActivity`
phủ lên activity Cocos `org.kingsoft.com.R1_OLChina`.

Chuỗi thật (đọc từ `decompiler/out/VN/jadx`):

```
libgame.so --JNI--> Userxsdk.login()                     (org/cocos2dx/plugin/Userxsdk.java:29)
   -> SDKHandler.loginVI()                               (org/kingsoft/com/SDKHandler.java:87)
      -> AppSDK.login()                                  (mở KullSDKActivity — panel hiện ra)
         ... người chơi bấm Đăng nhập/Chơi nhanh
         -> HTTP tới https://apisdk.kul.vn/              (ConnectionStrings, strings.xml API_URL)
            => CHẾT. JSONRequest.makeHttpRequest ném NullPointerException, panel treo.
   Trên thành công thật:
      AppSDK.callBackLogin.callBackFinishWithResult(result)
      -> SDKHandler$1$1.setMyTaskComplete: đọc result.getString("e") và ("r")
         -> Userxsdk.onLoginSuccessCallback(retCode, rJson)
            -> m_session = base64(json); UserWrapper.onActionResult(..., 0, session)
            -> Lua: G_Login:SdkLogin / ChannelLogin  ->  LỚP OFFLINE CHẶN Ở ĐÂY
```

⇒ **Chỉ cần giả `onLoginSuccessCallback(0, {...})`** là mọi thứ sau đó do lớp offline lo.
Đã kiểm: log native `sngDebugThread onActionResult threadID = ...` xuất hiện.

> ⚠ Tên lớp trong jadx có tiền tố `pNNN` cho gói obfuscate: `p003ui`, `p002bl`.
> Tên THẬT trong APK là `com.kull.sdk.ui.activities.KullSDKActivity` (xem `dumpsys`).

---

## 2. Frida 17 KHÔNG còn bridge Java — cách đã dựng

`typeof Java === 'undefined'` trong script. Frida 17 đã tách `frida-java-bridge` khỏi
agent. Cách chạy được (đã kiểm trên Android 6 / armv7):

1. `frida/js/` có `package.json` + `node_modules` (**frida-java-bridge 6.3.9**,
   frida-compile 19.1.0).
   * v7.x ném `Unable to find fields in java/lang/Thread` trên ART của API 23 ⇒ **phải 6.x**.
   * Bridge 6.x gọi `Module.getExportByName` — **Frida 17 đã bỏ API này** ⇒ phải shim
     sang `Module.findGlobalExportByName` (xem đầu mọi tệp `*.js` trong `frida/js/`).
2. Biên dịch:
   ```
   cd brave-cross/work/offline/frida/js
   npx frida-compile be_sdk_spawn.js -o ../be_sdk_spawn_bundle.js
   ```
3. Chạy: `chay_trace.py --pid <pid> --tep <bundle.js> --giay <giây>`.

**Các script đã có** (`frida/js/` nguồn → `frida/*_bundle.js` đã biên dịch):

| tệp | việc |
|---|---|
| `be_sdk_spawn.js` | **dùng tệp này**: hook `Userxsdk.login` + `AppSDK.login` ⇒ panel SDK KHÔNG BAO GIỜ mở |
| `be_sdk_nhe.js` | gọi thẳng `onLoginSuccessCallback` một lần (khi panel đã hiện) |
| `be_sdk6_shim.js` | bản đầy đủ (thêm `Java.choose` đóng activity — **NẶNG, đừng dùng**, đã làm ANR) |
| `dong_sdk.js` / `dong_sdk2.js` | thử đóng panel: qua `mActivities` (bridge 6 không lộ trường `activity`) và móc `onResume` (không bắn lại) ⇒ **cả hai BẾ TẮC** |
| `_thu_api.js`, `_do_hoat_dong.js` | công cụ chẩn đoán |

**Bài học**: `Java.choose` (quét heap) trên máy ảo này quá nặng ⇒ chỉ hook/call tĩnh.
Cách đúng là **gắn hook TRƯỚC** khi game gọi login (spawn hoặc attach sớm), không phải
đóng panel sau khi nó đã hiện.

---

## 3. Tự đăng nhập trong Lua — `offline/tu_dong.lua` (MỚI)

`deploy/plain/sc/offline/tu_dong.lua`, được `require` ở cuối `offline/init.lua`.
Hẹn giờ 1 s/lượt, hai bước đúng như người chơi bấm:

1. thấy `lLoginInputUI` hiện ⇒ điền `ebUserLoginName`/`ebUserLoginPassword` rồi gọi
   `g_CUILogin:onTouchEnd_OnLogin(nil, true)` (`CUILogin2.lua:1984`);
2. thấy `lLoginEnterGameUI` hiện ⇒ gọi `g_CUILogin:loginGame()` (`CUILogin2.lua:1885`).

Dừng ở màn chính. Tắt bằng `OfflineTuDong.TAT = true` hoặc bỏ dòng `require` trong init.lua.
**CHƯA chạy trọn một lượt** — cần kiểm lại log `offline.log` có dòng `tu_dong: ...`.

### 3.1 `offline/vao_tran.lua` (MỚI, 24/10) — tự vào trận

Nối tiếp `tu_dong`: khi đã vào **cảnh Main**, chờ `CHO_SCENE` giây rồi gọi **đường
thử có sẵn trong mã gốc** (không tự dựng lại logic trận):

* `g_CUIGame:Test()` — `sc/user/Battle/CUIGame.lua:157`: tự đặt `tArmys[1..10]` rồi
  `RepaleceScene("Battle", nil, {ChapterType=1, ChapterScenes=10, MainChapter=0,
  SubChapter=6, ChapterGameTime=10000, ChapterKey="L_N_01_01"}, nil, {})`.
  **Khép kín, không cần dữ liệu máy chủ** ⇒ mặc định dùng đường này.
* `QuickArena()` — `sc/game_arena.lua:124`: đường đấu trường, cần `g_CArena` + đội
  hình người chơi. Tệp ấy **tự gọi `QuickArena()` ngay khi nạp** và không ai
  `require` nó ⇒ trong module mình **chép lại thân hàm**, đừng nạp tệp thử ấy.

Bật/tắt: `OfflineVaoTran.TAT = true`; chọn đường: `OfflineVaoTran.LOAI = "test"|"arena"`.
Log: `vao_tran: da goi test -> true` trong `offline.log`. **CHƯA chạy thử** (máy ảo
24/10 chưa boot xong) — chỗ cần kiểm đầu tiên sau khi trace chạy được.

---

## 4. Máy ảo: chẩn đoán treo (đây là chỗ tốn thời gian nhất)

Triệu chứng: `system_server` đứng, `pm`/`am` báo "Could not access the Package Manager",
adb shell treo. Logcat có `Watchdog: *** GOODBYE!`.

Lấy stack: `adb shell kill -3 <pid system_server>` rồi kéo `/data/anr/traces.txt`
(**phải `MSYS_NO_PATHCONV=1`**, không thì Git Bash đổi `/data/...` thành `C:/Program...`).

Chuỗi khoá đọc được:

```
"android.display" (tid 16) Native
  Surface::disconnect -> libgui -> Binder waitForResponse  (chờ SurfaceFlinger MÃI MÃI)
"Binder_E" (tid 66) holds AMS lock, waits WMS HashMap held by tid 16
"main" (tid 1) waits AMS lock held by tid 66
```

⇒ **SurfaceFlinger của `-gpu swiftshader_indirect` chết** ⇒ WindowManagerService treo
⇒ cả framework đông cứng. Không phải lỗi của game/frida.

**Đã thử**:

| GPU | kết quả |
|---|---|
| `swiftshader_indirect` | chạy được nhưng chết theo chu kỳ (đúng chuỗi trên) |
| `angle_indirect` | không khởi động (lỗi driver GPU) |
| `guest` | treo boot (không có `sys.boot_completed`) |
| **`host`** | **boot 85 s, cài APK `Success`, ổn định hơn hẳn** — dùng cái này |

Lệnh boot đã dùng được:
```
emulator -avd buata -no-window -no-boot-anim -gpu host -no-snapshot
```

**Treo còn lại (chưa giải)**: đôi lúc boot dừng ở chỗ dịch vụ mạng — logcat dừng ngay sau
`MDnsSdListener starting to monitor`, `system_server` nằm `futex_wait`, kèm
`Netd: Unable to create netlink socket: Protocol not supported` /
`cannot find interface dummy0` / `iptables … nat: Table does not exist`.
Boot lại thì có lượt qua. Tỉ lệ qua ~50%.

### 4.1 Chẩn đoán 24/10 — BỐN LƯỢT HỎNG LIÊN TIẾP KHÔNG PHẢI NETD MÀ LÀ KHOÁ SNAPSHOT

Sáng 24/10 boot 4 lần liền, lần nào `sys.boot_completed` cũng rỗng quá 4 phút. Log
emulator nói thẳng lý do **khác** hẳn netd:

```
emulator: ERROR: A snapshot operation for 'buata' is pending and timeout has expired. Exiting...
```

Tức là `emulator` **tự thoát** ngay từ đầu vì còn **khoá snapshot cũ** — di chứng của
việc các lượt trước bị `Stop-Process -Force` (kể cả `emu kill`) trong lúc nó đang ghi
snapshot. Trong khi đó logcat in ra toàn dòng `Netd/iptables` — **đúng nhưng vô can**:
đó chỉ là mấy giây đầu của một tiến trình đã chết, không phải chỗ treo.

**Khoá thật nằm trong `~/.android/avd/buata.avd/`:** `hardware-qemu.ini.lock/`,
`multiinstance.lock`, `snapshot.lock.lock/`, `snapshots/default_boot`, `read-snapshot.txt`.
Phiên bản chạy nền tên tiến trình là **`qemu-system-armel-headless`** (KHÔNG phải
`qemu-system-armv7`) — lọc sai tên thì `Stop-Process` không giết gì mà vẫn tưởng đã giết.

**Đã chữa (24/10):**
1. `Stop-Process` đúng tên `qemu-system-armel-headless`, rồi xoá 3 thư mục `.lock` +
   `snapshots/default_boot` + `read-snapshot.txt`.
2. `config.ini`: `fastboot.forceFastBoot=no`, `firstboot.saveToLocalSnapshot=no`,
   `firstboot.bootFromLocalSnapshot=no`, `firstboot.bootFromDownloadableSnapshot=no`
   (sao lưu `config.ini.bak-snap`).
3. Boot lại bằng `-no-snapshot`: **hết lỗi snapshot**, lần này tiến trình sống và đi
   tiếp qua Netd (logcat sang `ip6tables -X st_penalty_*`, tức đã qua chỗ từng treo).
   Cold boot không snapshot chậm hơn hẳn 85 s — phải chờ tính bằng **phút**.

> **Bài học:** `emu kill` và `Stop-Process` đều có thể để lại khoá snapshot; sau mỗi
> lần giết cứng PHẢI dọn `*.lock` trước khi boot lại, và đừng tin logcat khi log
> emulator đã ghi `ERROR`.

**TÊN TIẾN TRÌNH QEMU ĐỔI THEO CHẾ ĐỘ — lọc sai thì `Stop-Process` không giết gì:**

| chế độ | tên tiến trình |
|---|---|
| `-no-window` | **`qemu-system-armel-headless`** |
| có cửa sổ | **`qemu-system-armel`** |

Sáng 24/10 tôi chỉ lọc `qemu-system-armv7` (sai hoàn toàn) rồi chỉ lọc `-headless`
(sót bản có cửa sổ) ⇒ có lúc "không thấy tiến trình nào" mà qemu vẫn sống, và boot
lại bị từ chối bằng `ERROR: Running multiple emulators with the same AVD`.
Kiểm bằng `Get-Process | ? { $_.Name -match 'qemu|emulator' }`.

**Cửa sổ đồ hoạ không dùng được trên phiên này:** emulator có cửa sổ ghi
`UpdateLayeredWindowIndirect failed … (A device attached to the system is not functioning.)`
nhưng qemu vẫn boot bình thường (chỉ không vẽ được cửa sổ). Đừng lấy lỗi Qt đó làm
dấu hiệu "emulator chết".

Việc khác đã làm: `hw.ramSize` trong `~/.android/avd/buata.avd/config.ini` đã trả về
**1024** (bản sao lưu `config.ini.bak-ram`); `-no-audio` không cải thiện.
Riot **Vanguard (`vgk`) đang chạy** lúc đầu phiên — đã `sc stop vgk` (giờ STOPPED),
không thấy khác biệt rõ.

---

### 4.2 KẾT LUẬN 24/10 — EMULATOR 30.2.2 TREO `system_server`, VÀ KHÔNG CÓ BẢN MỚI ĐỂ NÂNG

Thử liên tiếp trong ngày: `-cores 4/2/1` · `-gpu host`/`swiftshader_indirect` · `-memory 1024/2048`
· `-no-audio` · có/không `frida-server` · có/không `-wipe-data` · `-prop ro.hw_timeout_multiplier=10`
(**prop không ăn**: `getprop` vẫn trả 1). Boot **thành công** vài lần (`sys.boot_completed=1`),
nhưng sau đó `system_server` **luôn** rơi vào `futex_wait` rồi init khởi động lại nó, hoặc cả nhân
treo: qemu ăn **10,3 s CPU mỗi 10 s** trong khi `/proc/uptime` của guest **đứng yên** (lost ticks).
Chuỗi log hay dừng ở `SystemServiceManager: Starting …DisplayManagerService` (nghi
`android.display` chờ SurfaceFlinger — đúng chuỗi ANR đã ghi ở mục 4).

**Bản mới không cứu được:** SDK đã có sẵn `android-sdk/emulator-37/` (37.1.11), nhưng:
```
FATAL | CPU Architecture 'arm' is not supported by the QEMU2 emulator
```
⇒ Emulator mới **bỏ ARM 32-bit**; game gốc chỉ có `armeabi-v7a` ⇒ **30.2.2 là bản duy nhất**.
Không có "nâng cấp" nào cho AVD này. Muốn trace runtime thì cần **máy Android thật** (root) hoặc
một ảnh Android x86 + ARM translation (libhoudini) — cả hai đều là việc mới, không phải sửa nhanh.

**Vì thế 24/10 chuyển sang đường TĨNH:** xem `HIT-BOX-TU-CONFIG.md` — thời điểm đánh và hộp
đòn đánh **là dữ liệu trong `map/*_config.xml`**, đã trích bằng `work/fight_ref.py` (392 module).

## 5. Việc cần kiểm TRƯỚC khi làm tiếp (máy ảo có thể đã mất cài đặt)

```bash
adb -s emulator-5554 shell "pm list packages | grep cmn"        # APK còn không
adb -s emulator-5554 shell "ls -l /sdcard/Android/obb/com.cmn.buatanew/"   # OBB 208 MB
adb -s emulator-5554 shell "ls /sdcard/Android/data/com.cmn.buatanew/files/sc/offline/"
```
Thiếu thì: `adb install -r -g apk-vn/com.cmn.buatanew.apk` · `adb push` OBB ·
`python -I deploy.py --push`.

frida-server: đẩy `/data/local/tmp/frida-server` rồi chạy **trong một adb shell giữ mở**
(`adb shell /data/local/tmp/frida-server` chạy nền) — `setsid … &` KHÔNG giữ được nó sống.

---

## 6. Trình tự đề nghị cho lượt sau (một lần mở game duy nhất)

1. Boot `-gpu host`; chờ `sys.boot_completed=1` **và** `pm list packages` trả lời.
2. `adb shell am start -n com.cmn.buatanew/org.kingsoft.com.R1_OLChina`
3. Ngay sau đó (trong ~10 s): `python -I chay_trace.py --pid <pid> --tep be_sdk_spawn_bundle.js --giay 3600`
   → phải thấy `[be_sdk] da gan hook spawn`.
4. Chờ `[be_sdk] Userxsdk.login -> gia lap dang nhap thanh cong`, rồi chờ `tu_dong`
   tự đăng nhập (log `offline.log`).
5. Gắn trace: `python -I chay_trace.py --pid <pid> --tep trace_danh.js --giay 3600`
   → phải thấy `[trace] da gan hook tai 0x…`. (Gắn **trước** khi vào trận.)
6. Vào ải bằng chạm UI (màn chính → chiến dịch → ải) **hoặc** chép `QuickArena()` của
   `sc/game_arena.lua:124` vào một mô-đun offline (chưa thử; `StartBattle` với
   `ChapterType=9999`, `ChapterKey="L_XSGK"`).
7. Đọc `frida/trace_danh.out.jsonl` — mỗi dòng có `dx/dy/dist`, `dist_arg`, `ket_qua`.

**Kỷ luật để máy khỏi chết**: không `am force-stop` / không đổi activity liên tục,
không `dumpsys`, hạn chế `screencap`; mọi lệnh adb bọc `timeout` và `Start-Job`.
