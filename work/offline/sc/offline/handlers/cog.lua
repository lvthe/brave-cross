--[[
	offline/handlers/cog.lua — CÔNG THÀNH XUYÊN MÁY CHỦ (攻城战 / COG).

	MÔ HÌNH: "MỘT MÙA CHƯA MỞ". COG là hoạt động theo MÙA do máy chủ vận hành
	(đăng ký → vòng loại → hành quân → công thành → phát thưởng) và cần NHIỀU bang
	hội trên nhiều máy chủ. Bản offline chỉ có một người chơi ⇒ không có mùa nào để
	chạy. Đây KHÔNG phải "nuốt lặng": client có trạng thái THẬT cho việc này —
	`COGDef.STEP_NONE = 0` ("未开放" = chưa mở), và `CUICOGEntry:OnGetBriefInfo`
	có HẲN một nhánh cho `CLIENT_STEP_NONE` (hi chữ xám "chưa mở").

	VÌ SAO LỆNH ĐỌC TRẢ MÃ 0 (khác `handlers/cong_thanh.lua` trả mã lỗi):
	`CUICOG:onShow` gọi `CallGetCOGInfo` NGAY khi mở panel; trả lỗi thì bảng COG
	chỉ bật một toast rồi đứng ở khung trống. Trả ĐÚNG dữ liệu của mùa chưa mở thì:
	  · bảng mở được, dòng trạng thái hiện "chưa mở";
	  · bản đồ vẽ **28 thành** từ cấu hình THẬT `KDBGameGuildAttackCityConfig`
	    (client tự dựng danh sách trong `COGDataManager:OnGetCOGInfo`), mỗi thành
	    KHÔNG có bang chủ (`CityList` rỗng = không ai giữ thành);
	  · `GetCityInfo` trả một thành vô chủ — `Defend = 0`, không đơn xin gia nhập.
	Đó là mô tả ĐÚNG của trạng thái này, không phải dữ liệu bịa.

	CÁC LỆNH THAO TÁC trả MÃ GỐC trong `ErrorCode.COGCode` (`share/error.lua:663`):
	  NotSignUpState 4501 · NoDismissTeamId 4506 · NoDispatchTime 4507 ·
	  NoTeamDeployTime 4512 · NoGuild 4513 · RemainingCompleteTimesNotEnough 4518 ·
	  MissionStateIsNotCompleted 4521 · NoCityPlayback 4522 · NoPlayerPlayback 4523 ·
	  ConfigError 4524. Mỗi khoá chọn mã theo ĐÚNG lý do nó bị chặn (xem từng hàm).

	⚠ BẪY LỚN NHẤT — OBJ GỬI KHÁC OBJ NHẬN:
	client GỬI `"G_COGProtocol"` nhưng KHÔNG có biến toàn cục tên ấy. Thực thể là
	**`g_COGProtocol`** (chữ thường, `COGProtocol.lua:14`). `CallLocal` tra
	`_G[objName]` (`system/rpc.lua:91`) ⇒ phản hồi PHẢI gửi qua `g_COGProtocol`;
	gửi nhầm "G_COGProtocol" thì không hàm nào chạy, không lỗi nào, và lớp tải quay
	mãi. Cùng lẽ: **`G_COGCityDefendMission` KHÔNG có thực thể nào** ở client — sáu
	lệnh thành trì gửi bằng obj ấy nhưng hàm nhận nằm trên `g_COGProtocol`.
	(Cùng họ với Tinh Hồn: gửi `G_StarSoulProtocol`, nhận `g_StarSoulProtocol`.)

	SHOP ĐIỂM COG: `ClientBuyGoods(nIndex)` dùng bảng THẬT `GameCOGGoodsConfig`
	(7 dòng `{PrizeID, Cost}`) và điểm THẬT `GameUserBaseInfo.COGScore`
	(`COGDataManager:GetCOGScore/AddCOGScore`). Offline không có trận COG ⇒ điểm
	thường là 0 ⇒ mọi lượt mua bị từ chối bằng `ErrorCode.RedPack.ScoreLimit 5651`
	("商店兑换积分不足"). Lệnh GM `cog <n>` (`nap_gia_lap.lua`) cộng điểm để thử.

	KHÔNG LÀM (đo được, không bịa): `ClientGetPlayerBattleReport` gọi
	`g_COGDataManager:OnGetPlayerBattleReport` — hàm ấy **KHÔNG TỒN TẠI** trong
	client (grep 0 định nghĩa; chỉ có lời gọi ở `COGProtocol.lua:212`) ⇒ trả lỗi
	4523 là đường duy nhất không làm nổ client.
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflineCOG = OfflineCOG or {}

local R = OfflineRouter
local TEN_FILE = "cog"
local KHOA_TIN_NHAN = "OfflineCOGGuildMsg"

------------------------------------------------------------------- tiện ích

--[[ Mã gốc đọc LÚC CHẠY (bộ thử PC nạp lớp offline khi `ErrorCode` chưa có —
	đọc ở phạm vi tệp sẽ làm đỏ CẢ bộ thử, bẫy đã vấp 1/11). ]]
local function ma(ten, macDinh)
	local ok, v = pcall(function ()
		local E = _G.ErrorCode
		return E and E.COGCode and E.COGCode[ten]
	end)
	return (ok and tonumber(v)) or macDinh
end

-- "商店兑换积分不足" nằm trong nhóm `ErrorCode.RedPack` (không phải COGCode).
local function maDiem()
	local ok, v = pcall(function ()
		return _G.ErrorCode and ErrorCode.RedPack and ErrorCode.RedPack.ScoreLimit
	end)
	return (ok and tonumber(v)) or 5651
end

--[[ Gọi hàm nhận của client. obj là `g_COGProtocol` (chữ thường) — xem đầu tệp.
	Giữ NGUYÊN số tham số kể cả nil ở giữa/cuối (`select("#", ...)`). ]]
local function goi(ctx, hamNhan, ...)
	local a = { n = select("#", ...), ... }
	local ok, e = pcall(function ()
		return ctx:call("g_COGProtocol", hamNhan, unpack(a, 1, a.n))
	end)
	if not ok then
		OfflineLog:err(string.format("%s: khong goi duoc g_COGProtocol.%s -> %s",
			TEN_FILE, tostring(hamNhan), tostring(e)))
	end
end

--[[ Người chơi có bang hội không. COG là bang-hội-đấu-bang-hội nên mọi thao tác
	đều cần bang; `CheckIsHasJoinGuild` trả `(bResult, bHasJoin)` — CỜ NẰM Ở GIÁ
	TRỊ THỨ HAI (đọc giá trị đầu là nhận `true` của "gọi được", luôn đúng). ]]
local function coBang()
	local ok, r, b = pcall(function () return G_GuildLogic:CheckIsHasJoinGuild() end)
	if ok then
		local v = b
		if type(v) ~= "boolean" then v = r end
		if type(v) == "boolean" then return v end
	end
	return false
end

-- Mã chặn chung của một thao tác: chưa có bang thì 4513, có bang thì mã riêng.
local function maThaoTac(ten, macDinh)
	if not coBang() then return ma("NoGuild", 4513) end
	return ma(ten, macDinh)
end

local function docTinNhan()
	local ok, v = pcall(function ()
		local _, x = G_UserLogic:GetClientCommonData(KHOA_TIN_NHAN)
		return x
	end)
	if ok and type(v) == "string" then return v end
	return ""
end

local function ghiTinNhan(s)
	local ok, bRet = pcall(function ()
		return G_UserLogic:SetClientCommonData(KHOA_TIN_NHAN, s)
	end)
	if not ok or bRet ~= true then
		OfflineLog:err(TEN_FILE .. ": khong ghi duoc loi nhan bang hoi")
	end
end

local function dongBo()
	pcall(function () OfflineStore:syncFromClient() end)
end

local function lyDo(ten, maLoi, chiTiet)
	OfflineLog:info(string.format("%s: %s -> ma %d (%s)",
		TEN_FILE, ten, maLoi, chiTiet or "mua COG chua mo"))
end

------------------------------------------------------------------- LỆNH ĐỌC

--[[ `CUICOGEntry` hỏi 60 giây một lần khi về Main. Step = 0 ⇒ nhánh "chưa mở".
	`OnGetBriefInfo(nErrCode, tData)` — client đọc `Step / StepFinishTime /
	IsApplied / AttackCityID / OccupyCityID` (`CUICOGEntry.lua:146-170`). ]]
R:on("G_COGProtocol.ClientGetBriefInfo", function (ctx)
	local d = {
		Step = 0, StepStartTime = 0, StepFinishTime = 0,
		IsApplied = false, AttackCityID = 0, OccupyCityID = 0,
	}
	OfflineLog:info(TEN_FILE .. ": brief -> mua CHUA MO (Step=0)")
	goi(ctx, "OnGetBriefInfo", 0, d)
end)

--[[ `CUICOG:onShow` gọi lệnh này NGAY khi mở bảng. `OnGetCOGInfo(nErrCode, tData)`
	dựng danh sách thành TỪ CẤU HÌNH (`COGDataManager.lua:669-763`) rồi so với
	`tData.CityList` để gán chủ — bảng rỗng = 28 thành vô chủ. `DfendTask` viết
	đúng lỗi chính tả của client (`COGDataManager.lua:696`). ]]
R:on("G_COGProtocol.ClientGetCOGInfo", function (ctx)
	local d = {
		Step = 0, StepStartTime = 0, StepFinishTime = 0,
		OccupyCityID = 0, AppliedCityID = 0, AttackCityID = 0,
		GuildMsg = docTinNhan(),
		AttackTarget = 0, OccupyTarget = 0,
		DfendTask = {}, BattleReport = {}, CityList = {},
	}
	OfflineLog:info(TEN_FILE .. ": info -> mua CHUA MO, 28 thanh tu cau hinh (khong chu)")
	goi(ctx, "OnGetCOGInfo", 0, d)
end)

--[[ Một thành VÔ CHỦ. `OnGetCityInfo` tra thành trong `tCityList` (do lệnh
	GetCOGInfo ở trên dựng) rồi đọc các trường dưới. Các trường `ApplyList` /
	`Last2Guild` để RỖNG — không có bang nào xin đánh, đúng thực tế. ]]
R:on("G_COGProtocol.ClientGetCityInfo", function (ctx, nCityId)
	local d = {
		CityID = tonumber(nCityId) or 0,
		GuildID = 0, GuildName = "", PictureId = "",
		Defend = 0, ApplyList = {}, Last2Guild = {}, AttackGuild = 0,
	}
	OfflineLog:info(string.format("%s: thanh %s -> vo chu (Defend=0)", TEN_FILE,
		tostring(nCityId)))
	goi(ctx, "OnGetCityInfo", 0, d)
end)

--[[ Đội của MÌNH: mùa chưa mở ⇒ chưa lập đội nào; trả danh sách RỖNG đúng hình
	(`OnGetMyTeamList` lặp bằng `ipairs`). `CallGetMyTeamList` không truyền đối số
	dù chỗ gọi ở `CUICOGCityInfo.lua:61` truyền `CityID` — hàm gửi bỏ qua. ]]
R:on("G_COGProtocol.ClientGetMyTeamList", function (ctx)
	OfflineLog:info(TEN_FILE .. ": doi cua minh -> 0 doi")
	goi(ctx, "OnGetMyTeamList", 0, {})
end)

-- Đội của bang KHÁC: offline chỉ có MỘT thành viên (chính mình) ⇒ danh sách rỗng.
R:on("G_COGProtocol.ClientGetGuildTeamProfile", function (ctx)
	goi(ctx, "OnGetGuildTeamProfile", 0, {})
end)

R:on("G_COGProtocol.ClientGetGuildTeamList", function (ctx)
	goi(ctx, "OnGetGuildTeamList", 0, {})
end)

-- Chiến báo bang hội: chưa đánh trận nào ⇒ bảng rỗng (UI tự chịu được bảng rỗng).
R:on("G_COGProtocol.ClientGetGuildBattleReport", function (ctx)
	goi(ctx, "OnGetGuildBattleReport", 0, {})
end)

-- Chiến báo một thành: `CUICOGBrGuild:HandleData` tự vá `tMapData or {}`.
R:on("G_COGProtocol.ClientGetCityReport", function (ctx, nCityId)
	OfflineLog:info(string.format("%s: chien bao thanh %s -> 0 tran", TEN_FILE,
		tostring(nCityId)))
	goi(ctx, "OnGetCityReport", 0, {})
end)

--[[ Ba lệnh PHÁT LẠI — trả LỖI, không trả bảng rỗng:
	· GetPlayerBattleReport: hàm nhận gọi `g_COGDataManager:OnGetPlayerBattleReport`
	  — KHÔNG tồn tại ⇒ mã 0 sẽ nổ ngay trong callback.
	· GetCityPlayback: hàm nhận đòi 5 bảng con KHÁC RỖNG (`ProcessNotTable` từng
	  cái) ⇒ bảng rỗng cũng chỉ thoát im lặng.
	Mã 4522/4523 là mã GỐC "không tìm thấy bản ghi hình". ]]
R:on("G_COGProtocol.ClientGetPlayerBattleReport", function (ctx)
	local m = ma("NoPlayerPlayback", 4523)
	lyDo("ClientGetPlayerBattleReport", m, "khong co tran nao")
	goi(ctx, "OnGetPlayerBattleReport", m, {})
end)

R:on("G_COGProtocol.ClientGetCityPlayback", function (ctx, nCityId, bBattle)
	local m = ma("NoCityPlayback", 4522)
	lyDo("ClientGetCityPlayback", m, "khong co ban ghi hinh")
	goi(ctx, "OnGetCityPlayback", m, {}, bBattle)
end)

R:on("G_COGProtocol.ClientGetPlayerPlayback", function (ctx)
	local m = ma("NoPlayerPlayback", 4523)
	lyDo("ClientGetPlayerPlayback", m, "khong co ban ghi hinh")
	goi(ctx, "OnGetPlayerPlayback", m, {})
end)

------------------------------------------------------------------- THAO TÁC

--[[ `ClientSignUp(nCityId)`: đăng ký (hoặc 0 = huỷ) thành. Mùa chưa mở ⇒
	`NotSignUpState 4501` "当前不在报名阶段" — đúng mã GỐC cho tình huống này. ]]
R:on("G_COGProtocol.ClientSignUp", function (ctx, nCityId)
	local m = maThaoTac("NotSignUpState", 4501)
	lyDo("ClientSignUp", m, "khong phai pha dang ky")
	goi(ctx, "OnSignUp", m, tonumber(nCityId) or 0)
end)

--[[ `ClientSetTargetCity(nCityId, bIsAttack)`: chọn thành công/giữ. Chỉ có nghĩa
	trong pha đăng ký/vòng loại ⇒ cùng mã 4501 (không có cửa sổ thời gian). ]]
R:on("G_COGProtocol.ClientSetTargetCity", function (ctx, nCityId, bIsAttack)
	local m = maThaoTac("NotSignUpState", 4501)
	lyDo("ClientSetTargetCity", m, "khong co cua so chon thanh")
	goi(ctx, "OnSetTargetCity", m, tonumber(nCityId) or 0)
end)

--[[ `ClientSetGuildMsg(strMsg)`: KHÔNG phụ thuộc mùa ⇒ làm THẬT. Lời nhắn được
	lưu vào client common data (đi vào file lưu) và trả lại trong GetCOGInfo.
	`OnSetGuildMsg(nErrCode)` chỉ nhận mã lỗi. ]]
R:on("G_COGProtocol.ClientSetGuildMsg", function (ctx, strMsg)
	local s = tostring(strMsg or "")
	ghiTinNhan(s)
	dongBo()
	OfflineLog:info(string.format("%s: luu loi nhan bang hoi (%d ky tu)", TEN_FILE, #s))
	goi(ctx, "OnSetGuildMsg", 0)
end)

--[[ ĐỘI CÔNG THÀNH: chưa tới pha lập đội ⇒ 4512 "当前时间不能配置队伍". ]]
R:on("G_COGProtocol.ClientAddTeam", function (ctx, tTeamList)
	local m = maThaoTac("NoTeamDeployTime", 4512)
	lyDo("ClientAddTeam", m, "khong phai pha lap doi")
	goi(ctx, "OnAddTeam", m)
end)

R:on("G_COGProtocol.ClientUpdateTeam", function (ctx, nTeamId, tTeamList)
	local m = maThaoTac("NoTeamDeployTime", 4512)
	lyDo("ClientUpdateTeam", m, "khong phai pha lap doi")
	goi(ctx, "OnUpdateTeam", m)
end)

--[[ Giải tán đội: mùa chưa mở ⇒ KHÔNG có đội nào ⇒ 4506 "解散的队伍不存在". ]]
R:on("G_COGProtocol.ClientRemoveTeam", function (ctx, nTeamId)
	local m = maThaoTac("NoDismissTeamId", 4506)
	lyDo("ClientRemoveTeam", m, "khong co doi nao")
	goi(ctx, "OnRemoveTeam", m, tonumber(nTeamId) or 0)
end)

-- Điều đội đi đánh/giữ: ngoài pha hành quân ⇒ 4507 "当前不是派遣队伍的时间".
R:on("G_COGProtocol.ClientDispatchTeam", function (ctx, tMapDispatch)
	local m = maThaoTac("NoDispatchTime", 4507)
	lyDo("ClientDispatchTeam", m, "khong phai pha hanh quan")
	goi(ctx, "OnDispatchTeam", m, {})
end)

------------------------------------------------------------------- SHOP ĐIỂM

--[[ Tra hàng của shop: `GameCOGGoodsConfig` là bảng CON của `KDBGameCommonConfig`
	(7 dòng thật `{PrizeID, Cost}`), đọc qua `GetCommonConfigWithName`. ]]
local function cauHinhShop()
	local ok, cfg = pcall(function ()
		return G_ConfigManager:GetCommonConfigWithName("GameCOGGoodsConfig")
	end)
	if ok and type(cfg) == "table" then return cfg end
	return nil
end

-- Điểm COG hiện có: `COGDataManager:GetCOGScore()` trả `(bResult, nScore)`.
local function diemCOG()
	local ok, r, n = pcall(function () return G_COGDataManager:GetCOGScore() end)
	if ok then
		if type(r) == "boolean" then return r, tonumber(n) or 0 end
		return true, tonumber(r) or 0
	end
	return false, 0
end

--[[ Trả kết quả shop. `ClientBuyGoods` KHÔNG có hàm nhận trên `g_COGProtocol`
	(`COGProtocol.lua:386-389` chỉ gửi) ⇒ phải tự tắt lớp tải qua
	`g_CUIGameRPCManager:OnReciveResponse`; khi thành công còn phát
	`COG.OnBuyCOGGoods` để bảng điểm + danh sách hàng vẽ lại
	(`CUICOGUIPanel.lua:36`, `CUICOGShop.lua:39`). ]]
local function traShop(ctx, maLoi)
	local ds = {}
	if (maLoi or 0) == 0 then
		pcall(function ()
			ds[1] = {
				EventType = EventManagerType.Logic,
				EventName = EventManagerLogicEvent.COG.OnBuyCOGGoods,
				LogicData = nil,
			}
		end)
	end
	local ok, e = pcall(function ()
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", maLoi or 0, ds)
	end)
	if not ok then
		OfflineLog:err(TEN_FILE .. ": khong tat duoc lop tai khi mua -> " .. tostring(e))
	end
end

--[[ `ClientBuyGoods(nIndex)` — nIndex là chỉ số 1..7 trong bảng cấu hình
	(chính chỉ số UI dùng làm tag hàng). Trừ điểm TRƯỚC, phát thưởng SAU; phát
	hỏng thì HOÀN điểm (nguyên tử), không để mất điểm mà không có hàng. ]]
R:on("G_COGProtocol.ClientBuyGoods", function (ctx, nIndex)
	local i = tonumber(nIndex)
	local cfg = cauHinhShop()
	local dong = (cfg and i and cfg[i]) or nil
	if type(dong) ~= "table" then
		lyDo("ClientBuyGoods", ma("ConfigError", 4524),
			"chi so " .. tostring(nIndex) .. " khong co trong GameCOGGoodsConfig")
		return traShop(ctx, ma("ConfigError", 4524))
	end
	if not coBang() then
		local m = ma("NoGuild", 4513)
		lyDo("ClientBuyGoods", m, "chua co bang hoi")
		return traShop(ctx, m)
	end

	local gia = tonumber(dong.Cost) or 0
	local okDiem, diem = diemCOG()
	if not okDiem then
		local m = ma("ConfigError", 4524)
		lyDo("ClientBuyGoods", m, "khong doc duoc diem COG")
		return traShop(ctx, m)
	end
	if diem < gia then
		local m = maDiem()
		lyDo("ClientBuyGoods", m, string.format("diem %d < gia %d", diem, gia))
		return traShop(ctx, m)
	end

	local okTru = pcall(function () return G_COGDataManager:AddCOGScore(-gia) end)
	if not okTru then
		local m = ma("ConfigError", 4524)
		lyDo("ClientBuyGoods", m, "khong tru duoc diem")
		return traShop(ctx, m)
	end

	-- ⚠ `GetPrizeWithID` trả `(bResult, prize)` ⇒ `pcall` cho RA BA giá trị:
	-- (okCall, bResult, prize). Đọc hai giá trị là nhận BOOLEAN làm prize —
	-- bẫy cùng họ `GetItemCount` trả `(ok, n)` (README 1/11).
	local okCall, bLay, prize = pcall(function ()
		return G_PrizeLogic:GetPrizeWithID(dong.PrizeID)
	end)
	local okPhat, daPhat = false, false
	if okCall and bLay ~= false and type(prize) == "table" then
		okPhat, daPhat = pcall(function ()
			return G_ChapterLogic:SetDataWithPrizeData(prize, 1, "COGShop")
		end)
	end
	if not okPhat or daPhat ~= true then
		if not okPhat then
			OfflineLog:err(TEN_FILE .. ": SetDataWithPrizeData loi -> " .. tostring(daPhat))
		end
		pcall(function () G_COGDataManager:AddCOGScore(gia) end)   -- hoàn điểm
		local m = ma("ConfigError", 4524)
		lyDo("ClientBuyGoods", m, "khong phat duoc qua (da hoan diem)")
		return traShop(ctx, m)
	end

	dongBo()
	OfflineLog:info(string.format("%s: mua hang %d (PrizeID %s) — -%d diem, con %d",
		TEN_FILE, i, tostring(dong.PrizeID), gia, diem - gia))
	traShop(ctx, 0)
end)

------------------------------------------------------------------- THÀNH TRÌ
--[[ Sáu lệnh này client GỬI với obj `G_COGCityDefendMission` (KHÔNG có thực thể
	nào ở client) nhưng NHẬN trên `g_COGProtocol` — `ctx:call` ở trên đã gửi đúng
	obj. Hình tham số của hàm nhận:
	  · OnGetCityDefendMission(...)  — chấp nhận (mã, dữ liệu) hoặc (dữ liệu)
	  · OnManualRefreshMission(tData) — MỘT tham số, KHÔNG có mã lỗi
	  · OnGetPrize(tData)             — MỘT tham số, KHÔNG có mã lỗi
	  · OnGetDailyOccupyPrize()       — KHÔNG tham số, luôn chạy nhánh thành công
	  · OnRepairCity / OnAttackCity   — chấp nhận (mã, dữ liệu)
	Vì hai hàm giữa không có kênh báo lỗi, chúng trả dữ liệu RỖNG (không phát gì).

	CHƯA CÓ NHIỆM VỤ THÀNH: GetCityDefendMission trả `{}` ⇒ `SetDefendTask` đặt
	TaskID=0, LastCount=0 (không có nhiệm vụ). Sửa/phá thành cần số lượt nhiệm vụ
	còn lại > 0 ⇒ 4518 "剩余完成次数不足" (đúng mã gốc). Nhận thưởng nhiệm vụ khi
	không có nhiệm vụ ⇒ gọi OnGetPrize({}) — không có gì để phát. ]]
R:on("G_COGCityDefendMission.ClientGetCityDefendMission", function (ctx)
	OfflineLog:info(TEN_FILE .. ": nhiem vu thanh -> khong co (mua chua mo)")
	goi(ctx, "OnGetCityDefendMission", 0, {})
end)

R:on("G_COGCityDefendMission.ClientManualRefreshMission", function (ctx)
	-- Không có nhiệm vụ để làm mới, và KHÔNG trừ kim cương (không có gì để mua).
	OfflineLog:info(TEN_FILE .. ": lam moi nhiem vu thanh -> khong co nhiem vu")
	goi(ctx, "OnManualRefreshMission", {})
end)

R:on("G_COGCityDefendMission.ClientGetPrize", function (ctx, nTaskId)
	OfflineLog:info(string.format("%s: nhan thuong nhiem vu %s -> khong co nhiem vu",
		TEN_FILE, tostring(nTaskId)))
	goi(ctx, "OnGetPrize", {})
end)

R:on("G_COGCityDefendMission.ClientRepairCity", function (ctx, nCityId)
	local m = maThaoTac("RemainingCompleteTimesNotEnough", 4518)
	lyDo("ClientRepairCity", m, "con 0 luot nhiem vu thanh")
	goi(ctx, "OnRepairCity", m, {})
end)

R:on("G_COGCityDefendMission.ClientAttackCity", function (ctx, nCityId)
	local m = maThaoTac("RemainingCompleteTimesNotEnough", 4518)
	lyDo("ClientAttackCity", m, "con 0 luot nhiem vu thanh")
	goi(ctx, "OnAttackCity", m, {})
end)

--[[ Thưởng chiếm thành hằng ngày: mùa chưa mở ⇒ không chiếm thành nào
	(`OccupyCityID = 0`) ⇒ không có thưởng. Hàm nhận không có tham số lỗi nên
	chỉ ghi log; `COGDataManager:OnGetDailyOccupyPrize` với thành 0 là no-op. ]]
R:on("G_COGCityDefendMission.ClientGetDailyOccupyPrize", function (ctx)
	OfflineLog:info(TEN_FILE .. ": thuong chiem thanh -> khong co thanh nao")
	goi(ctx, "OnGetDailyOccupyPrize")
end)

OfflineLog:info("cog: da noi 25 khoa (mua CHUA MO + shop diem that)")

return true
