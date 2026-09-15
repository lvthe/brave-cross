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

	VÌ VẬY FILE NÀY CỐ Ý MỎNG: trả lời các câu hỏi CHỈ-ĐỌC, còn với phần máy
	chủ thì DỌN LỚP "ĐANG TẢI" rồi nói thẳng là chưa làm. Đăng ký chứ không để
	rơi vào `OfflineLog:missing`: handler không trả lời thì client treo ở lớp
	"đang tải" chứ không báo gì (net.lua:252-262).

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
	  ClientGetEndlessChapterFirstPrize
	                           ĐỦ dữ liệu để làm mà chưa làm trong đợt này: xét
	                           `BestProsees >= nIndex` + `FirstPrizeStates`, mã
	                           lỗi `ErrorCode.EndlessChapter` (NotPass=4101,
	                           HasGetFristPrize=4102), thưởng
	                           `EndlessChapterFirstPrizeConfig[tostring(n)]`
	                           (113000+n), phát bằng `SetDataWithPrizeData`. Ghi
	                           lại đây để lần sau khỏi dò.
]]

require("offline.log")
require("offline.router")

local R = OfflineRouter

--[[ Dọn lớp "đang tải".

	Mọi `CallX` của client đều phát `OnWaitingForRequest`, và CUIMain CHỈ hạ lớp
	đó ở `OnReceiveResponse` (CUIMain.lua:470, thân hàm ở :941 — chỉ Hide(), không
	dùng tham số). Nên trả lời bằng một hàm `On...` riêng KHÔNG đủ: lớp "đang
	tải" ở lại và nuốt mọi cú bấm.

	Đường chung của bản gốc là
	CUIRPCManager:OnReciveResponse(callbackObj, callbackFunc, nErrCode, eventList)
	(:166) — phát OnReceiveResponse rồi áp eventList. Ta truyền ("", "", 0, {}):
	không lỗi, không đổi dữ liệu, không gọi callback. Cùng lối
	`mysterious.lua:37` và `statewar.lua:26` đang dùng. ]]
local function don_lop_dang_tai(ctx)
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", 0, {})
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
chua_lam("ClientGetEndlessChapterFirstPrize",
	"DU du lieu de lam ma chua lam dot nay — xem chu thich dau file")

return true
