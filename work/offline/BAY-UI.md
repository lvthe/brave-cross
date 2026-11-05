# Bẫy UI của "Búa Tạ" — bảng tra và cách chữa

Cập nhật **28/10/2026**. Gom toàn bộ bẫy giao diện đã trả giá trong lúc dựng lớp
offline (`GHI-CHU-TRACE-2026-10-26.md` §7–§22), tách rõ **bẫy của client gốc** (vẫn
gặp khi chạy ONLINE, vì client không đổi) và **bẫy của riêng lớp offline**.

> Đọc kèm: §8.3 (popup thưởng), §10 (bản vá đầu), §12 (thoại), §13 (router, Túi),
> §19 (lớp chặn `OnShowUI`), §22 (Nhận cánh).

---

## 1. Bảng tổng hợp

| # | Triệu chứng | Chỗ sinh ra | Cách chữa | Trạng thái |
|---|---|---|---|---|
| 1 | Popup **"Nhận Thưởng"** hiện rồi nuốt mọi cú bấm | `G_CUIRewardLayer`; `CGuideScheme` chờ `Reward_Hide` (`CGuideScheme.lua:4358-4364`), sự kiện ấy CHỈ phát trong `CUIRewardLayer:onClose()` (`CUIRewardLayer.lua:191`) | nhịp 1 `_forceShowAll`, nhịp 2 `onTouchEnd_OnClose(nil, true)` — trong `tu_dong.lua` | **đã vá** |
| 2 | Popup **"Quà login ngày"** phủ tối, bấm "Nhận" không ăn | `g_CUILoginReward`, thiếu handler `ClientGetLoginReward` ⇒ nút CÓ ăn nhưng không ai trả lời | handler gọi `AchieveLogic:GetLoginReward` + `OnReciveResponse`; watchdog đóng popup sau 3 nhịp | **đã vá** (§10.2) |
| 3 | Khung **thoại hướng dẫn** chặn màn | `CGuideLogical:ShowDialog` (`CGuideLogical.lua:140`) vẽ vào `clUIMainGuide`; kịch bản `coroutine.yield("GuideShowDialog")` (`CGuideScheme.lua:77, :84, …`) | tự bấm `onTouchEnd_onGuideGoNext(clUIMainGuide, true)` (`:559`) khi `tListener == "GuideShowDialog"` | **đã vá** (§12.1) |
| 4 | Cả màn **nuốt cú bấm** ở bước hướng dẫn KHÔNG phải thoại | kịch bản chờ sự kiện giao diện (`tListener = "OnShowUI"`) và gọi `SetSceneCanTouch(false)`; chỉ nhả khi `FinishGudie` (`:770`) | `tu_dong`: thấy `tListener` khác nil và khác `"GuideShowDialog"` thì gọi `g_CGuideLogical:FinishGudie()` **ngay nhịp đó** | **đã vá** (§19.5) |
| 5 | Hướng dẫn **chạy lại mỗi lần vào Main** | kịch bản tân thủ không lưu tiến trình | `FinishGudie` lặp (10 nhịp) + bấm qua thoại | **đã vá**, vẫn còn nhiễu |
| 6 | Panel **"Nhận cánh"** (`T.Trang` / `Nhận`) không có đường thoát: BACK và bấm ra ngoài đều không ăn | `g_CUIWingGet` (`CUIWingGet.lua:9`), mở bằng `g_CUISubDialog:Show(...)` (`CUIMainTopTool.lua:1213`) | `g_CUISubDialog:Close()` sau khi hiện 30 nhịp (watchdog `tu_dong`) | **đã vá** (§22) |
| 7 | **Hộp Thư** quay vô tận | bản cũ trả qua hàm TOÀN CỤC `OnGetMailList` (đường mạng CŨ); `CUIMail` nghe logic event `"OnServerGetMailList"` (`CUIMail.lua:161`) | trả qua `G_MailLogic:OnServerGetMailList(0, {})` (`ClientMailLogic.lua:138`) | **đã vá** (§10.3) |
| 8 | Panel mở nhưng **đứng ở vòng quay** (mọi panel có nút gửi server) | `OnWaitingForRequest` hiện `g_buyLoadingDialog`; nó CHỈ tắt khi có `CUINotificationEvent.OnReceiveResponse` (`CUIMain.lua:941-947`) | mọi handler phải trả lời — hoặc `g_CUIGameRPCManager:OnReciveResponse("", "", err, {})` | quy ước chung |
| 9 | **Nút Túi** không thấy trên cảnh Main | `btnBackpackUI` có trong cây UI, `getIsVisible()=true`, nhưng world (1296.58, 917.66) rơi vào **trời trống** khi đổi qua UI root; bản gốc chỉ vẽ nó trong bước hướng dẫn (`CGuideScheme.lua:1807`) | mở bằng hàm của nút: `g_CUIMain:onTouchEnd_onBackpackUI(btnBackpackUI, true)` (`CUIMain.lua:1739`); **đừng tìm toạ độ** | đã hiểu, không vá (§18.1) |
| 10 | **"Quét 10"** xám dù còn lượt | luật gốc: VIP 0 thì quét mười luôn xám (`CUIChapterInfo.lua:430-455`, cổng `__getVipCanSweep("ChapterSweepUnlockLevel") = 1`) | không sửa — hạ cổng là bịa | luật gốc (§17.2) |
| 11 | Quà tuần: bấm nhận xong UI hiện sai | `CUIActivityLoginRewards:OnReceiveCallBack(nRewardCount)` (`:147`) đọc **một con số**; bản cũ trả bảng `{err=0}` | trả số `0` (chưa nhận ngày nào) | **đã vá** (§19.3) |
| 12 | Bấm "Nhận" ở panel ngày mà không có phản hồi | `ClientAchieveLogic:CallAwardAchieve(0)` (`CUISign.lua:540`) — nút điểm danh dùng chung đường thưởng thành tựu | `ClientAwardAchieve` đã có handler | đã phủ |

---

## 2. Bẫy "không phải UI" nhưng cùng kiểu (dễ gặp lại khi làm online)

| # | Chuyện | Gốc rễ | Cách chữa |
|---|---|---|---|
| 13 | **Vòng lặp vào game** (`vao game lan 6285`) | mốc `LastEnterGameTime` ghi vào bảng của PHIÊN ĐANG SỐNG, còn phản hồi gửi bảng lấy TỪ FILE LƯU ⇒ bị đè lại; và `getIsDailyFirstEnterGame` (`share_gameWorld.lua:17-45`) còn rẽ nhánh theo **ngày** (`DialyRefreshHour = 5`) | ghi mốc vào chính `tUserData.GameUserGlobalData` trước khi gửi (`handlers/login.lua`) |
| 14 | Hai hệ dùng **cùng tên hàm RPC**, cái sau đè cái trước | RPC gốc khoá bộ ba `(module, objName, funcName)` (`system/rpc.lua:83`), router cũ khoá trơ tên hàm. 45 tên bị trùng (`ClientCompeleteFight` ở `G_CavernLogic` và `G_EndlessChapterLogic`) | `OfflineRouter:getFor(obj, func)` — thử `"obj.func"` trước, rồi tên trơ (`net.lua:253`) |
| 15 | `SetDataWithDropList` ném lỗi giữa vòng trao thưởng | `chapterVictoryHandle` truyền `tReportsData = nil`, hàm ghi `tReportsData["DropCount_…"]` (`share_ChapterLogic.lua:4128`) với ải có `DropData` (144/461 ải) | bọc `SetDataWithDropList` thay nil bằng `{}` (`handlers/chapter.lua`) |
| 16 | Lưu cờ trên **class table** rồi đọc lại luôn ra nil | `class()` (`share/class.lua:56-60`) chỉ có `__newindex`, KHÔNG có `__index` | giữ cờ trong biến cục bộ của tệp |
| 17 | Client KHÔNG gửi `KillIdList` ở ải thường | `CUIGame:OnLevelCompleteCallServer` (`:3196-3220`) chỉ gửi `ChapterData` | chỉ lọc rơi đồ khi `cd.KillIdList` là bảng; thiếu thì trao nguyên danh sách đã quay |
| 18 | Vật phẩm "Dùng" không có tác dụng (vd ID 4) | bản gốc chỉ ship bảng hàm `useItem_<ID>` cho MỘT SỐ ID (`share_ItemLogic.lua:491-527`) | không bịa; luật gốc từ chối thì trả lỗi |
| 19 | Báo "không đủ kim cương" dù thừa tiền | `IsEnoughDiamondToMakeLottery` trả **(cờ, giá)**; đọc `local _, b` thì `b` là **250** | đọc giá trị ĐẦU (§23.4) |
| 20 | Kết luận "không có bảng cấu hình" | nhiều bảng là **bảng con** của `KDBGameCommonConfig` (`ConfigName`/`ConfigContent`), không có tệp `KDB*.json` riêng | quét theo `ConfigName` bên trong, đừng quét theo tên tệp (§23) |

---

## 3. Khi gặp lại "màn hình nuốt cú bấm" — thứ tự kiểm

1. `offline.log` có dòng **`THIEU`** mới? → thiếu handler, viết handler đó (nhớ tắt lớp
   đang tải bằng `OnReciveResponse`).
2. **`tu_dong: huong dan cho khoa = …`** — khoá là gì?
   * `GuideShowDialog` → để watchdog tự bấm;
   * khác (vd `OnShowUI`) → gọi `FinishGudie` ngay.
3. Panel là `CUIPublic` nào? Thử `X:IsUIShow()`, nếu có thì đóng bằng **đường mở tương
   ứng** (`g_CUISubDialog:Close()`, `onTouchEnd_OnClose`, …), đừng đoán nút X.
4. Vẫn treo → soi `g_buyLoadingDialog:IsLoading()`: nếu còn thì đúng là thiếu
   `OnReceiveResponse` (mục 8).
5. Nút **không ăn** ≠ nút hỏng: log `THIEU` xuất hiện đúng lúc bấm nghĩa là nút ĂN,
   chỉ thiếu phía trả lời (đã hai lần tưởng nhầm: "Nhận" quà login, "Mở Khoá" binh chủng).

---

## 4. Đồ nghề đã có (đừng làm lại)

| việc | lệnh |
|---|---|
| đối chiếu handler ↔ lệnh client | `python -I _phu_rpc.py` · `--thieu` · `--la` (bắt tên gõ sai) |
| chạy bộ test PC | `python -I run_tests.py` (**152/0**) |
| dựng + đẩy lớp offline | `python -I build.py` rồi `python -I deploy.py --push --sng` (đẩy 5 chỗ) |
| log trên máy | `adb shell tail /data/data/com.cmn.buatanew/files/offline.log` (tự xoay vòng 4 MB) |
| chụp màn hình | `adb -s emulator-5554 exec-out screencap -p > x.png` |

---

## 5. Bẫy của RIÊNG môi trường (không liên quan client)

1. **`.ps1` chỉ được ASCII** (PS 5.1 đọc không BOM theo ANSI) — một dấu `—` làm vỡ cả script.
2. **Git Bash + `adb push`**: phải `MSYS_NO_PATHCONV=1`, không thì `/sdcard/...` thành
   `C:/Program Files/Git/sdcard/...`.
3. **`adb root` giết `frida-server`** → phải bật lại, không thì "need Gadget".
4. **`build.py` đôi khi không xoá được `deploy/plain`** (Windows khoá thư mục) → xoá
   bằng PowerShell có vòng thử lại rồi build.
5. **Bấm mù theo nhịp thì hỏng**: node trên bản đồ có lúc không ăn cú đầu, màn bố trí
   cần thời gian dựng; trong trận phải bấm **Auto + "Nhập gọi lính" (~1150,830)**.
   Công thức bấm đầy đủ: §20.2.
6. **Frida không trace được trên LDPlayer**: `libgame.so` chỉ map `r--p`, code ARM chạy
   bằng JIT của libhoudini ⇒ muốn trace native phải có **ARM thật**.

---

## 6. Mai làm tiếp

1. **Cửa hàng bí ẩn** — **ĐÃ LÀM 28/10** (§23.1): dữ liệu sinh hàng nằm trong
   `KDBGameCommonConfig` (bảng con `GameMStroeGoodsCrateConfig`, `GameSecretShopConfig`,
   `GameMaterialIDToMStoreGoodsID`). Đo được: sinh 8 món, mua −39.000 vàng, món chuyển
   `State = 1`, thiếu tiền trả 1702. Panel vẫn khoá Lv18 trên tài khoản thử ⇒ mở bằng hàm.
2. **Hộp hồn (魂匣)** — **ĐÃ LÀM 28/10** (§23.2): `GameSoulBoxConfig` có đủ bể tướng,
   trọng số, 3+2 món/lượt (khớp 5 plug của `HunXiaAnima`), bảo hiểm 10–19 lượt, giá 250.
   Hộp hồn là SỰ KIỆN `TimeLimitSoulBoxHero` ⇒ offline bật thường trực (§23.2).
3. **Quà Login Tuần (7 ngày)** — UI dựng từ `RewardCount`/`LoginCount` + danh sách
   PrizeID của **hoạt động**; muốn chạy được thì phải có hoạt động `LoginReward` với
   danh sách PrizeID (online: server cấp; offline: cần bảng PrizeID đầy đủ).
4. **Đường "online"**: giữ nguyên các kết luận ở mục 1 (bẫy 1–12 đều là hành vi client,
   server thật cũng phải trả lời đúng như §1 cột "cách chữa"), chỉ bỏ phần watchdog
   `tu_dong` và các mẹo mở panel bằng hàm.
5. **Nếu quay lại cày cấp**: Lv6→Lv14 cần 2.415 EXP ≈ **403 trận** (§21.1) — không đáng.
6. **Mở khoá để kiểm panel**: dùng `sc/offline/nang_cap.lua` (Lv90/VIP15 + 27 cờ chức
   năng) rồi `sc/offline/luot_panel.lua` (mở lần lượt 21 lối vào, log mở/lỗi). Cả hai
   **TẮT** mặc định; kết quả lượt 28/10: **21/21 mở được, 0 lỗi** (§24). Ba hệ
   **Đấu Trường / PK / Quân Đoàn** mở panel nhưng rỗng hoặc báo chưa mở — dữ liệu
   nhiều người chơi, không có trong cấu hình.
