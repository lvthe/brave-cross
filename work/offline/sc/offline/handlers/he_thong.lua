--[[
	offline/handlers/he_thong.lua — các hệ thống phụ client hỏi ngay khi vào game:
	bạn bè, APR (đấu trường xếp hạng), kênh chat.

	Ba cái đầu đều KHÔNG có dữ liệu trong chế độ offline, nhưng client vẫn chờ
	phản hồi (`OnWaitingForRequest`), nên phải trả lời — và trả lời đúng là
	"chưa có / đang đóng", không bịa dữ liệu.

	`ClientEnterChannel` (kênh chat, gửi sang SERVER.CHAT_FRIEND) vốn không có
	phản hồi — xem danh sách nuốt lặng ở handlers/login.lua.
]]

require("offline.log")
require("offline.store")
require("offline.router")

local R = OfflineRouter

--[[ Bạn bè: chưa có ai.

	KHÔNG trả lời: client không có hàm nhận nào cho lệnh này (ClientFriendLogic
	là class, dòng PostLogicEvent OnWaitingForRequest bị chú thích bỏ —
	ClientFriendLogic.lua:218-242), trả về chỉ sinh cảnh báo "client khong co
	ham nay". Xem danh sách nuốt lặng ở handlers/login.lua. ]]

--[[ Trạng thái APR: ĐÓNG. ClientGetOpenInfoRsp(nState, nServerOpenTime,
	nEndTime) — ba số (APRProtocol.lua:28-35). Không có trận PvP nào trong lớp
	offline nên "đóng" là đúng, không phải thiếu. ]]
R:on("ClientGetOpenInfoReq", function(ctx)
	ctx:call("g_APRProtocol", "ClientGetOpenInfoRsp", 0, 0, 0)
end)

--[[ Bảng xếp hạng APR: rỗng, nhưng ĐÚNG hình dạng APRData:parseServerInfo
	đòi (APRData.lua:643-657): tData.ScoreCompetitive.LastChampion.RankList. ]]
R:on("ClientGetServerInfoReq", function(ctx)
	ctx:call("g_APRProtocol", "ClientGetServerInfoRsp", {
		ScoreCompetitive = { LastChampion = { RankList = {} } },
	})
end)

--[[ Hộp thư: không có thư nào.

	ĐO 27/10: bấm Hộp Thư thì panel mở nhưng quay VÔ TẬN. Bản cũ trả qua hàm
	TOÀN CỤC `OnGetMailList` (CServerResponseLogic.lua:921) — đó là đường MẠNG
	CŨ (notification center), còn `CUIMail` lại nghe **logic event**
	`"OnServerGetMailList"` (`CUIMail.lua:161`) do
	`ClientMailLogic:OnServerGetMailList(nErrCode, tMailList)`
	(`ClientMailLogic.lua:138-177`) phát ra. Trả đúng hàm ấy với danh sách
	rỗng: nó tự phát `OnReceiveResponse` (tắt vòng quay) rồi phát dữ liệu. ]]
R:on("ClientGetMailList", function(ctx)
	ctx:call("G_MailLogic", "OnServerGetMailList", 0, {})
end)

--[[ Số lượt nhận cánh còn lại (panel Nhận cánh — T.Trang).

	Client gửi `ClientRefreshLeftWingCount` rồi chờ sự kiện
	`"OnRefreshLeftWingCount"` (`CUIWingGet.lua:174`, hàm nhận ở `:271`) —
	khoá sự kiện là CHUỖI, và **không có hàm Lua nào nhận phản hồi** (bản gốc
	phát từ phía server/C++). Con số lấy từ
	`G_UserDataManager:GetUserGlobalData("LeftActiveWing")`, mặc định **999**
	(`share_ClothingLogic.lua:805-812`). ]]
R:on("ClientRefreshLeftWingCount", function(ctx)
	local okB, nCon = false, nil
	if G_ClothingLogic ~= nil then
		okB, nCon = pcall(function ()
			local _, n = G_ClothingLogic:GetChargeWingLeftCount()
			return n
		end)
	end
	OfflineLog:info("refresh canh: con " .. tostring(okB and nCon or "?"))
	if G_EventManager ~= nil then
		G_EventManager:PostLogicEvent(nil, "OnRefreshLeftWingCount")
	end
end)

--[[ Số lượt nhận thưởng còn lại của một bộ trang phục (panel Nhận cánh/T.Trang).

	Client nhận bằng `ClientClothingLogic:OnServerGetClothingPrizeCount(nLeft,
	strIndex)` (ClientClothingLogic.lua:134-151) — hai số theo vị trí, rồi phát
	sự kiện "OnServerGetClothingPrizeCount" cho UI.

	Số lấy từ chính logic gốc: `ClothingLogic:refreshGetClothingPrizeCount`
	(share_ClothingLogic.lua:404-518) trả (bResult, nErrCode, nLeftCount). ]]
R:on("ClientGetClothingPrizeCount", function(ctx, strIndex)
	local goc = nil
	if ClothingLogic ~= nil and G_ClothingLogic ~= nil then
		goc = G_ClothingLogic[ClothingLogic]
	end
	local nLeft = 0
	if goc ~= nil then
		local ok, _, _, n = pcall(function ()
			return goc:refreshGetClothingPrizeCount(0, strIndex)
		end)
		if ok and n ~= nil then
			nLeft = n
		else
			OfflineLog:warn("ClientGetClothingPrizeCount: khong lay duoc so luot, dung 0")
		end
	end
	OfflineLog:info(string.format("trang phuc %s: con %s luot", tostring(strIndex), tostring(nLeft)))
	ctx:call("G_ClothingLogic", "OnServerGetClothingPrizeCount", nLeft, strIndex)
end)

--[[ Quà Login Tuần (popup "Quà Login …" mở lúc vào game).

	UI gọi `G_LoginRewardLogic:ClientGetLoginRewardData()` rồi CHỜ sự kiện
	`Active.OnGetLoginRewardData` (`CUIActivityLoginRewards.lua:39-43`); không
	trả lời là cả panel đứng, nuốt mọi cú bấm (đo 27/10). Người nhận là
	`ClientActivityLoginReward:OnGetLoginRewardData(nErrCode, tData)`
	(`ClientActivityLoginRewardLogic.lua:19-33`) — hai tham số theo vị trí.

	Nhận quà cũng vậy: `ClientGetPrize` → `OnGetPrize(tData)` (`:42-53`). ]]
R:on("ClientGetLoginRewardData", function(ctx)
	ctx:call("G_LoginRewardLogic", "OnGetLoginRewardData", 0, {})
end)

--[[ Nhận quà "Quà Login Tuần" (7 ngày).

	ĐO 28/10: hàm nhận là `ClientActivityLoginReward:OnGetPrize(tData)`
	(`ClientActivityLoginRewardLogic.lua:42`) → phát
	`Active.OnReceiveLoginReward` với chính tData; UI đọc nó ở
	`CUIActivityLoginRewards:OnReceiveCallBack(nRewardCount)` (:147) và gán
	`tActivitieData.RewardCount = nRewardCount` ⇒ **phải là SỐ**, không phải bảng
	(bản cũ trả `{err=0}` — sai kiểu).

	Vì sao luôn 0: lịch 7 ngày là dữ liệu SINH Ở MÁY CHỦ (`LoginRewardDef` chỉ
	định nghĩa KHOÁ, không có bảng quà), và hoạt động này không mở trong chế độ
	offline; `CUIActivityLoginRewards:onShow` chỉ gọi `ClientGetLoginRewardData`
	khi `tActivityState` có. Nên 0 = "chưa nhận được ngày nào", đúng sự thật. ]]
R:on("G_LoginRewardLogic.ClientGetPrize", function(ctx)
	ctx:call("G_LoginRewardLogic", "OnGetPrize", 0)
end)

--[[ Nút "Nhận" của popup "Quà login ngày" (CUILoginReward).

	ĐO 27/10: bấm nút thì RPC CÓ đi — `G_AchieveLogic:CallGetLoginReward`
	(ClientAchieveLogic.lua:801) gửi `ClientGetLoginReward`, rồi phát
	`OnWaitingForRequest` (hiện lớp "đang tải"). Lớp offline chưa có handler
	nên log ghi THIEU và nút "không ăn" — thật ra nút ăn, chỉ thiếu phía trả.

	Việc phát thưởng là của CHÍNH luật gốc: `AchieveLogic:GetLoginReward`
	(share/AchieveLogic.lua:986) kiểm "đã nhận chưa" + cấp ≥ 3, gọi
	`G_PrizeLogic:ReceivePrizeWithID(LoginPrizeID = 1010)`, đặt cờ đã nhận, và
	phát `Achieve.OnGetLoginReward` — sự kiện `CUILoginReward:OnGetLoginReward`
	(`CUILoginReward.lua:105`) đang chờ để đóng popup.

	Còn lại chỉ là tắt lớp "đang tải": đường phản hồi chung của bản gốc
	(`CUIRPCManager:OnReciveResponse`, xem handlers/mysterious.lua:15). ]]
R:on("ClientGetLoginReward", function(ctx)
	local bOk, nErr = false, 0
	if G_AchieveLogic ~= nil and G_AchieveLogic.GetLoginReward ~= nil then
		bOk, nErr = G_AchieveLogic:GetLoginReward()
	else
		nErr = 1
	end
	OfflineLog:info(string.format("ClientGetLoginReward: nhan qua login -> %s (ma %s)",
		tostring(bOk), tostring(nErr)))
	if bOk == true and OfflineStore ~= nil then
		OfflineStore:syncFromClient()
	end
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "",
		(bOk == true) and 0 or (tonumber(nErr) or 1), {})
end)

--[[ BẢNG XẾP HẠNG CẤP (`CUIActivityWeeklyLoop` / `CUILeaderboard`).

	ĐO 28/10 (sau khi nâng Lv90 mở BXH): mở BXH ⇒ `THIEU G_RankLogic.ClientGetLevelRank`.
	Người nhận: `ClientLeaderboardLogic:OnGetLevelRank(tRankList, nSelfRank,
	nYesterdayRank)` (`user/Logical/ClientLeaderboard.lua:195`) — nó chỉ đóng gói
	và phát `"OnServerGetLevelRank"`, KHÔNG kiểm nội dung. Bảng rỗng là hợp lệ
	(offline không có người chơi khác; hạng của mình để 0). ]]
R:on("G_RankLogic.ClientGetLevelRank", function(ctx)
	ctx:call("G_RankLogic", "OnGetLevelRank", {}, 0, 0)
end)

--[[ LÀM MỚI QUÂN ĐOÀN (`G_GuildLogic.ClientRefreshUserGuild`).

	`ClientGuildLogic:RefreshUserGuild(GuildId)` (`ClientGuildManageLogic.lua:602`)
	bật lớp tải rồi gửi; người nhận `ClientGuildLogic:OnRefreshUserGuild()`
	(`:610`) phát `Guild.OnRefreshUserGuild` với `{}`. Offline không có quân đoàn
	nên trả đúng "không có gì" — `CUIMain:OnRefreshUserGuildCallBack` đóng danh
	sách quân đoàn. ]]
R:on("G_GuildLogic.ClientRefreshUserGuild", function(ctx)
	ctx:call("G_GuildLogic", "OnRefreshUserGuild")
end)

--[[ DANH SÁCH QUÂN ĐOÀN ĐỂ XIN VÀO (`G_GuildLogic.ClientGetRandGuildList`).

	ĐO 28/10 (lượt kiểm panel lần hai): mở Quân Đoàn ⇒ `THIEU`. Người nhận
	`ClientGuildLogic:OnGetRandGuildList(nErrCode, tData)`
	(`ClientGuildApplyLogic.lua:66`) — nó chỉ đóng gói rồi phát
	`"OnServerGetGuildJoinList"`. Offline KHÔNG có quân đoàn nào ⇒ danh sách
	rỗng là đúng dữ liệu, không phải né. ]]
R:on("G_GuildLogic.ClientGetRandGuildList", function(ctx)
	ctx:call("G_GuildLogic", "OnGetRandGuildList", 0, {})
end)

--[[ ĐẤU TRƯỜNG (`G_ArenaLogic.GetUserArenal`, module ARENA_SERVER) và
	ĐẤU TRƯỜNG ANH HÙNG (`G_PkProtocol.ClientGetData`) — CHƯA CÓ DỮ LIỆU.

	Hai hệ này là máy chủ nhiều người chơi (xếp hạng, danh sách đối thủ, trận
	PK ghi lại); không có dữ liệu nào trong cấu hình để dựng lại. Trả mã lỗi
	ĐÚNG của bản gốc (`ErrorCode.Arenal.GetUserArenaDataFaild = 2306`,
	`ErrorCode.Pk.PkNotOpen = 6700`) qua đường phản hồi chung: tắt lớp "đang
	tải", UI báo lỗi, KHÔNG phát dữ liệu ma. ]]
R:on("G_ArenaLogic.GetUserArenal", function(ctx)
	OfflineLog:warn("dau truong: chua co du lieu xep hang (may chu dau truong) -> 2306")
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "",
		ErrorCode.Arenal.GetUserArenaDataFaild, {})
end)

R:on("G_PkProtocol.ClientGetData", function(ctx, strTag, tFields)
	OfflineLog:warn("dau truong anh hung: chua co may chu PK -> 6700 (the " .. tostring(strTag) .. ")")
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", ErrorCode.Pk.PkNotOpen, {})
end)

return true
