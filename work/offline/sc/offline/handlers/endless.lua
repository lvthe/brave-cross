--[[
	offline/handlers/endless.lua — ải vô tận (无限关, EndlessChapter).

	VÌ SAO HỌ NÀY CẦN: hai màn của họ này vỡ NGAY LÚC ĐỌC DỮ LIỆU, trước khi
	gọi máy chủ câu nào — chúng không hỏng vì thiếu phản hồi:

	  CUIInfiniteLevelMain.lua:619
	    FreeChallengesCount(2) + PayChallengesCount(nil) - ChallengesCount(nil)
	  CUIInfiniteLevelFirstPassRewards.lua:211
	    self.tEndlessChapterData.BestProsees(nil) >= i

	Cả hai chỉ vì bảng `GameUserEndlessChapter` thiếu, và chỗ gỡ nằm ở tầng DỮ
	LIỆU chứ không ở file này: `OfflineStore.TU_DUNG` (store.lua) để bảng đó
	VẮNG MẶT lúc khởi động, nên `EndlessChapterLogic:GetUserEndlessChapterData`
	(share/EndlessChapterLogic.lua:127) thấy `nil` và tự gọi
	`craeteUserEndlessChapter()`. File này KHÔNG góp phần gỡ hai dòng trên.

	KHÁC `chapter` VÀ `cavern`: TÍNH NĂNG NÀY KHÔNG ĐƯỢC SHIP NỬA MÁY CHỦ.
	`sc/share/EndlessChapterLogic.lua` (557 dòng) chỉ có hàm ĐỌC: hình dạng bảng,
	cổng vào ải (`IsCanFight`), số học quét, và bộ xét điều kiện qua ải. Không
	có hàm nào THAY ĐỔI trạng thái người chơi, và `ServerEndlessChapterLogic`
	không có trong repo. Nên ở đây không thể "gọi luật gốc" như `chapter.lua`
	làm với `share_ChapterLogic.lua`.

	VÌ VẬY FILE NÀY CỐ Ý MỎNG: trả lời các câu hỏi CHỈ-ĐỌC và làm TRỌN đúng MỘT
	việc máy chủ (`ClientGetEndlessChapterFirstPrize` — xem chú thích ở hàm đó),
	còn phần máy chủ thật thì DỌN LỚP "ĐANG TẢI" rồi nói thẳng là chưa làm. Đăng
	ký chứ không để rơi vào `OfflineLog:missing`: handler không trả lời thì client
	treo ở lớp "đang tải" chứ không báo gì (net.lua:252-262).

	CÒN THIẾU, nói rõ vì sao — KHÔNG đoán (mỗi mục là một dòng `chua_lam` dưới):

	  ClientFight              nửa máy chủ không ship: chỗ chuyển trạng thái (khi
	                           nào ChallengesCount tăng, PayChallengesCount bị
	                           tiêu) nằm trong ServerEndlessChapterLogic. Chỉ
	                           biết CỔNG VÀO `IsCanFight` (:211), không biết hệ
	                           quả sau đó.
	  ClientInspire            `InspireProbability = {Gold=50, Diamond=100}`
	                           (ctor :33) có trong mã nhưng KHÔNG chỗ nào đọc:
	                           không biết 50/100 là phần trăm hay ngưỡng, cũng
	                           không biết trừ tài nguyên thế nào.
	  ClientResetEndlessChapter không biết reset cái gì và giá bao nhiêu.
	                           `MaxResetCount = 1` trông như mốc ngày nhưng không
	                           chỗ nào ship ranh giới ngày.
	  ClientCompeleteFight     biết thưởng qua tầng (`PrizeID = 107000+n`) và bộ
	                           xét `IsCompeleteData`, nhưng KHÔNG biết thứ tự
	                           đường thắng cũng như cách dời CurrentProsess /
	                           BestProsees / CurrentState.
	  ClientGotoNextProsees    cùng loại — phần dời trạng thái là của máy chủ.
	  ClientSwap/ClientStopSwap thời gian quét tính được hết (`GetSwapCount`,
	                           `GetSwapProsees`, `GetSweepImmediatelyCost`) nhưng
	                           cách GOM thưởng đã tích thành `tPrizeList` thì
	                           không được ship.
	  ClientSwapImmediately    client KHÔNG có listener nào cho lệnh này (no-op
	                           từ đầu), nên trả lời cho khỏi treo là hết.
	  ClientBuyChallengesCount không biết khi nào trừ tài nguyên và khi nào cộng
	                           `PayChallengesCount`; hằng số giá thì có
	                           (`PayChallengesCost = 50`).
]]

require("offline.log")
require("offline.store")
require("offline.router")

local R = OfflineRouter

--[[ Mã lỗi, lấy từ bản gốc (`sc/share/error.lua:605-610`).

	KHÔNG có số dự phòng, và đây là chỗ dễ sai nhất của hàm này: `ErrorCode` là
	mã GỐC và luôn được nạp — `share/share_public_require.lua:14` require
	`share.error`, mà file đó được kéo vào ở `lua/bootstrap.lua:603`. Thiếu nó
	là lỗi nạp chứ không phải chuyện để ta chọn hộ một con số; bịa số thì
	`CUIMain:OnShowError` tra ra một khoá khác và người chơi đọc một câu khác.

	Đo thêm, để khỏi tưởng hai mã này có sẵn câu chữ: `conf/text_vi.xgg` có 453
	khoá `ErrorCode_*` và **4101/4102 KHÔNG nằm trong đó** (cả nhóm 4xxx chỉ có
	4001, 4003, 4205, 4401…). `CUIMain:OnShowError` (:914) làm
	`GetStringWithKey(string.format("ErrorCode_%d", err))`, mà `_text` thiếu
	khoá thì trả về chính khoá (game/lua_runtime.gd:507) — nên người chơi thấy
	đúng dòng chữ `ErrorCode_4101`. Bản gốc cũng vậy: máy chủ thật gửi mã đó.
	Giữ nguyên, KHÔNG thay bằng câu tự viết. ]]
local function ma_loi(strTen)
	local ec = rawget(_G, "ErrorCode")
	local t = ec and ec.EndlessChapter
	if t == nil or t[strTen] == nil then
		OfflineLog:err("thieu ErrorCode.EndlessChapter." .. strTen
			.. " — tra loi khong co ma loi (0) chu khong bia mot so")
		return nil
	end
	return t[strTen]
end

--[[ Dọn lớp "đang tải".

	Mọi `CallX` của client đều phát `OnWaitingForRequest`, và CUIMain CHỈ hạ lớp
	đó ở `OnReceiveResponse` (CUIMain.lua:470, thân hàm ở :941 — chỉ Hide(), không
	dùng tham số). Nên trả lời bằng một hàm `On...` riêng KHÔNG đủ: lớp "đang
	tải" ở lại và nuốt mọi cú bấm.

	Đường chung của bản gốc là
	CUIRPCManager:OnReciveResponse(callbackObj, callbackFunc, nErrCode, eventList)
	(:166) — phát OnReceiveResponse rồi áp eventList. Ta truyền ("", "", 0, {}):
	không lỗi, không đổi dữ liệu, không gọi callback. Cùng lối
	`mysterious.lua:37` và `statewar.lua:26` đang dùng.

	`nErrCode ~= 0` (:187) thì bản gốc còn bắn
	`CUINotificationEvent.OnServerRequestError` — tức là hiện ĐÚNG câu báo lỗi
	của bản gốc. Nên chỗ nào có mã lỗi thật thì truyền vào, đừng nuốt. ]]
local function don_lop_dang_tai(ctx, nErrCode, tEventList)
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "",
		nErrCode or 0, tEventList or {})
end


--[[ Bảng xếp hạng ải vô tận.

	Cùng loại với `ClientGetGuildInfo` của bang hội: cần NGƯỜI CHƠI KHÁC. Offline
	chỉ có một người, nên câu trả lời trung thực là "chưa có bảng xếp hạng",
	KHÔNG phải dựng vài cái tên giả cho màn hình đỡ trống.

	Chữ ký đọc từ chính client: `OnGetEndlessChapterRank(tRankList, nSelfRank,
	nYesterdayRank)` (ClientEndlessChapterLogic.lua:309). Dùng `ctx:call` vì hàm
	nhận tham số VỊ TRÍ, không theo bao bì {err=, data=}.

	Hình dạng trả về không phải số ta nghĩ ra: bản gốc có sẵn một mẫu y hệt
	trong mã — `CUILeaderboard.lua:1633` giữ nguyên dòng
	`{tRankList={}, nSelfRank=0, nYesterdayRank=0}` (bị chú thích đi, nhưng là
	đúng hình dạng đó). Màn `CUIInfiniteLevelLeaderboard` chỉ đọc `tData.RankList`
	(:130), danh sách rỗng thì nó hiện dòng "chưa có xếp hạng" — đúng thực tế.

	Vẫn phải dọn lớp "đang tải": `CallGetEndlessChapterRank` có phát
	OnWaitingForRequest (:306), mà hàm `On...` riêng không hạ được lớp đó. ]]
R:on("ClientGetEndlessChapterRank", function(ctx)
	OfflineLog:warn("ClientGetEndlessChapterRank: offline chi co mot nguoi choi"
		.. " — tra bang xep hang RONG, khong dung ten gia")
	ctx:call("G_EndlessChapterLogic", "OnGetEndlessChapterRank", {}, 0, 0)
	don_lop_dang_tai(ctx)
end)


--[[ Phần thuộc máy chủ: đăng ký cho khỏi rơi vào "missing", dọn lớp "đang tải",
	rồi ghi nhật ký nói rõ chỗ nào chưa khôi phục được. KHÔNG đổi trạng thái —
	đổi thì phải bịa luật. ]]
local function chua_lam(strTen, strViSao)
	R:on(strTen, function(ctx)
		OfflineLog:warn(strTen .. ": " .. strViSao)
		don_lop_dang_tai(ctx)
	end)
end

chua_lam("ClientFight",
	"nua may chu khong duoc ship — chi biet cong vao IsCanFight, khong biet khi nao"
	.. " ChallengesCount tang / PayChallengesCount bi tieu")
chua_lam("ClientInspire",
	"InspireProbability co trong ma nhung KHONG cho nao doc — khong biet 50/100"
	.. " la phan tram hay nguong")
chua_lam("ClientResetEndlessChapter",
	"khong biet reset cai gi va gia bao nhieu")
chua_lam("ClientCompeleteFight",
	"biet thuong qua tang (107000+n) va bo xet IsCompeleteData, nhung khong biet"
	.. " thu tu duong thang cung cach doi CurrentProsess/BestProsees/CurrentState")
chua_lam("ClientGotoNextProsees",
	"phan doi trang thai la cua may chu")
chua_lam("ClientSwap",
	"tinh duoc thoi gian quet, nhung cach GOM thuong da tich thanh tPrizeList"
	.. " khong duoc ship")
chua_lam("ClientStopSwap",
	"cung ly do ClientSwap: danh sach thuong quet khong duoc ship")
chua_lam("ClientSwapImmediately",
	"client khong co listener nao cho lenh nay — no-op tu dau")
chua_lam("ClientBuyChallengesCount",
	"khong biet khi nao tru tai nguyen / cong PayChallengesCount (gia 50 thi co)")


--[[ Thưởng thông ải LẦN ĐẦU của một tầng (首次通关奖励).

	ĐÂY LÀ MỤC DUY NHẤT của họ này làm được TRỌN, vì cả ba mảnh đều có mã gốc:

	  1. ĐIỀU KIỆN — `BestProsees >= nIndex` và `FirstPrizeStates[tostring(n)]`
	     chưa bật. Hai trường đó là hình dạng CHÍNH CLIENT dựng
	     (`share/EndlessChapterLogic.lua:164-182`).
	  2. MÃ LỖI — `ErrorCode.EndlessChapter` (NotPass 4101, HasGetFristPrize 4102)
	     ở `sc/share/error.lua:605-610`.
	  3. PHÁT THƯỞNG — `G_PrizeLogic:GetPrizeWithID(113000 + n)` rồi
	     `G_ChapterLogic:SetDataWithPrizeList(PrizeContent, 1, ...)`. Đúng cặp hàm
	     mà `share_ChapterLogic.lua:2236-2238` (thưởng chiến dịch) dùng, không
	     phải đường tự chế.

	Số 113000+n KHÔNG phải suy ra: `KDBGameCommonConfig` mục
	`EndlessChapterFirstPrizeConfig` là chuỗi JSON `{"1":113001,...,"250":113250}`.

	CHI TIẾT DỄ SAI — client tự đánh dấu trước, không chờ ta:
	`onTouchEnd_OnGetFristPassReward` (CUIInfiniteLevelFirstPassRewards.lua:335)
	gọi RPC rồi LẬP TỨC bật `FirstPrizeStates[n] = true` và đổi hình sang "đã
	nhận", KHÔNG có hàm `On*` nào để nghe phản hồi (đo: `grep` toàn `sc/` chỉ ra
	một dòng chú thích). Nên việc của ta không phải "báo cho client biết đã nhận"
	mà là (a) phát thật phần thưởng, (b) ĐỒNG BỘ dấu đó xuống kho.

	Vì sao phải đồng bộ tay: lần dựng ĐẦU TIÊN, `GetUserEndlessChapterData` gọi
	`setUserEndlessChapter` -> `PostDataEvent(copyTab(t))`, nên bản trong
	`G_DataManager.userData` là một BẢN SAO còn `self.UserEndlessChapter` giữ bản
	GỐC — màn hình sửa bản gốc, `OfflineStore:syncFromClient` đọc bản sao. Từ lần
	thứ hai trở đi thì hai bên là một (nhánh `UserEndlessChapter ~= nil` trả thẳng
	bản trong DataManager). Ghi qua event `Data` là cách của chính bản gốc
	(`CUIRPCManager:OnReciveResponse:217` -> `G_DataManager:ChangeUserData`), nên
	dùng nó chứ không sửa thẳng `userData`. ]]
R:on("ClientGetEndlessChapterFirstPrize", function(ctx, nIndex)
	local n = tonumber(nIndex)
	if n == nil or n < 1 then
		OfflineLog:warn("ClientGetEndlessChapterFirstPrize: chi so khong hop le "
			.. tostring(nIndex))
		don_lop_dang_tai(ctx)
		return
	end

	if G_EndlessChapterLogic == nil then
		OfflineLog:warn("ClientGetEndlessChapterFirstPrize: chua co "
			.. "G_EndlessChapterLogic")
		don_lop_dang_tai(ctx)
		return
	end

	local _, duLieu = G_EndlessChapterLogic:GetUserEndlessChapterData()
	if type(duLieu) ~= "table" then
		OfflineLog:warn("ClientGetEndlessChapterFirstPrize: khong doc duoc "
			.. "GameUserEndlessChapter")
		don_lop_dang_tai(ctx)
		return
	end

	local nToiNhat = tonumber(duLieu.BestProsees) or 0
	if nToiNhat < n then
		OfflineLog:warn(string.format("ClientGetEndlessChapterFirstPrize tang %d: "
			.. "chua thong (toi nhat %d) — ma %s", n, nToiNhat,
			tostring(ma_loi("NotPass"))))
		don_lop_dang_tai(ctx, ma_loi("NotPass"))
		return
	end

	local tDaNhan = duLieu.FirstPrizeStates
	if type(tDaNhan) ~= "table" then
		tDaNhan = {}
	end
	if tDaNhan[tostring(n)] == true then
		OfflineLog:warn(string.format("ClientGetEndlessChapterFirstPrize tang %d: "
			.. "da nhan roi — ma %s", n, tostring(ma_loi("HasGetFristPrize"))))
		don_lop_dang_tai(ctx, ma_loi("HasGetFristPrize"))
		return
	end

	-- PHÁT THƯỞNG bằng cặp hàm của bản gốc. Không có `G_PrizeLogic` thì thôi,
	-- khong bia so thay.
	local nPrizeID = 113000 + n
	local okLay, bLay, tCauHinh =
		pcall(G_PrizeLogic.GetPrizeWithID, G_PrizeLogic, nPrizeID)
	if not okLay or bLay ~= true or type(tCauHinh) ~= "table"
			or type(tCauHinh.PrizeContent) ~= "table" then
		OfflineLog:warn(string.format("ClientGetEndlessChapterFirstPrize tang %d: "
			.. "khong doc duoc cau hinh thuong %d", n, nPrizeID))
		don_lop_dang_tai(ctx)
		return
	end

	local okPhat, bPhat = pcall(G_ChapterLogic.SetDataWithPrizeList,
		G_ChapterLogic, tCauHinh.PrizeContent, 1, "EndlessChapterFirstPrize")
	if not okPhat or bPhat ~= true then
		OfflineLog:warn(string.format("ClientGetEndlessChapterFirstPrize tang %d: "
			.. "SetDataWithPrizeList tu choi", n))
		don_lop_dang_tai(ctx)
		return
	end

	-- Đánh dấu đã nhận. Ghi vào BẢN CLIENT ĐANG GIỮ (để màn hình đang mở nhất
	-- quán) rồi ghi vào kho bằng ĐÚNG hàm mà đường phản hồi của bản gốc dùng
	-- (`G_DataManager:ChangeUserData`, xem `CUIRPCManager:OnReciveResponse:217`).
	--
	-- Vì sao gọi thẳng chứ không chỉ trả event `Data` cho `OnReciveResponse` áp:
	-- hàng đợi phản hồi chỉ chạy ở tick sau (`OfflineNet:tick`), mà
	-- `OfflineStore:flush` chỉ ghi khi `dirty`, còn `dirty` chỉ bật ở
	-- `syncFromClient`. Gọi thẳng thì `syncFromClient` đọc được NGAY giá trị vừa
	-- ghi; để event tự áp thì lượt ghi đầu tiên bỏ sót dấu này.
	local tMoi = {}
	for k, v in pairs(tDaNhan) do
		tMoi[k] = v
	end
	tMoi[tostring(n)] = true
	duLieu.FirstPrizeStates = tMoi
	local okGhi, bGhi = pcall(G_DataManager.ChangeUserData, G_DataManager,
		"GameUserEndlessChapter", { FirstPrizeStates = tMoi }, "FirstPrizeStates")
	if not okGhi or bGhi ~= true then
		OfflineLog:warn(string.format("ClientGetEndlessChapterFirstPrize tang %d: "
			.. "khong ghi duoc dau da nhan xuong kho — se hoi lai duoc", n))
	end
	OfflineStore:syncFromClient()

	OfflineLog:info(string.format(
		"ClientGetEndlessChapterFirstPrize tang %d: phat thuong %d", n, nPrizeID))
	don_lop_dang_tai(ctx)
end)

return true
