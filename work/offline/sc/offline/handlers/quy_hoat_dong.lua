--[[
	offline/handlers/quy_hoat_dong.lua — QUỸ CẤP / QUỸ THỜI GIAN (`G_ActivityFund`, 3 khoá).

	  · `ClientBuyActivityFund(strFundType)` → mua quỹ
	  · `ClientGetLevelFundPrize()`          → lĩnh bậc Quỹ cấp
	  · `ClientGetTimeFundPrize()`           → lĩnh Quỹ thời gian

	TRẠNG THÁI/CẤU HÌNH ĐẾN TỪ `offline/hoat_dong.lua` (lịch viết mới, 31/10).

	PHẦN LUẬT CÓ THẬT, dùng nguyên văn:
	  · `ActivityFund:IsCanBuyFund(type, tConfig)` (`share/Activities/FundLogic.lua:78-148`)
	    — kiểm VIP → kim cương → cấp → đã mua, trả `(bResult, nErrCode)` với
	    `ErrorCode.Activity.Fund` { 4010 thiếu kim cương · 4011 thiếu cấp · 4012 đã mua }.
	  · `IsBuyFund` / `GetPrizeCount` / `GetIsGetTimeFundToday` — ba hàm đọc trạng thái,
	    khoá do `getBuyFundKey`/`getFundCountKey` sinh (`"HasBuyActivityFoud_<loại>"`,
	    `"ActivityFoudGetCount_<loại>"`); ghi bằng `G_UserDataManager:SetUserGlobalData`.
	  · Thưởng: `ActivityLevelFundConfig` (`{Level, PrizeID}` × 12) và
	    `ActivityTimeFundConfig` (`{Day, PrizeID}` × 2) là CẤU HÌNH THẬT; phát qua
	    `G_PrizeLogic:ReceivePrizeWithID(PrizeID, nil, "ActivityFund")`.

	PHẦN VIẾT MỚI `[MOI]` (máy chủ gốc đã chết, không đối chiếu được):
	  · `[MOI-3]` BẬC ĐƯỢC LĨNH = `GetPrizeCount + 1` — ĐỌC ĐƯỢC từ UI: ô chỉ bấm được
	    khi `index == hasGetCount + 1` (`CUIActivityFund.lua:604`) và chỉ hiện "CanGet"
	    khi `userLevel >= config.Level` (`:455`). Đây là luật của CHÍNH CLIENT, không phải
	    ta tự nghĩ ra.
	  · `[MOI-4]` Quỹ thời gian: mỗi NGÀY một bậc (`IsGetTimeFundToday`), bậc = số đã
	    lĩnh + 1, hết bảng thì từ chối. Không có UI nào gọi khoá này trên cây
	    (`grep TimeFund` chỉ ra đúng hàm CallGetTimeFundPrize) nên ít rủi ro.
	  · Mã lỗi riêng của lớp offline: **4002** `Activity.ConfigError` khi thiếu cấu hình /
	    không có bậc; **4007** `HasGetActivityPrize` khi hôm nay đã lĩnh.
]]

require("offline.log")
require("offline.store")
require("offline.router")
require("offline.hoat_dong")

local R = OfflineRouter
local TEN_FILE = "quy hoat dong"

local MA = {
	ARG       = 2,     -- ErrorCode.System.ParamError
	NOT_OPEN  = 4001,  -- ErrorCode.Activity.ActivityNotOpen
	NO_CONFIG = 4002,  -- ErrorCode.Activity.ConfigError
	HAS_GET   = 4007,  -- ErrorCode.Activity.HasGetActivityPrize
	UNKNOWN   = 1,
}

local function loi(ctx, ma, viSao)
	OfflineLog:info(string.format("%s: tu choi, ma %d (%s)",
		TEN_FILE, tonumber(ma) or 1, tostring(viSao)))
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", tonumber(ma) or 1, {})
end

local function dongBo()
	pcall(function () OfflineStore:syncFromClient() end)
end

--[[ Gọi hàm của LỚP CHA `ActivityFund` trên thực thể `G_ActivityFund`
	(`G_ActivityFund = ClientActivityFund:new()`, `ClientActivitiesLogic.lua:283`). ]]
local function goiCha(ten, ...)
	local o = _G.G_ActivityFund
	local c = _G.ActivityFund
	if type(o) ~= "table" or type(c) ~= "table" then return nil end
	local self = o[c] or o
	local fn = self[ten]
	if type(fn) ~= "function" then return nil end
	local args = { n = select("#", ...), ... }
	local a1, a2 = nil, nil
	local ok = xpcall(function ()
		a1, a2 = fn(self, unpack(args, 1, args.n))
	end, function (e)
		OfflineLog:err(TEN_FILE .. ": " .. ten .. " nem loi: " .. tostring(e))
	end)
	if not ok then return nil end
	return a1, a2
end

local function ghiCong(strKey, giaTri)
	pcall(function () G_UserDataManager:SetUserGlobalData(strKey, giaTri) end)
end

local function docCong(strKey)
	local v = nil
	pcall(function ()
		local _, x = G_UserDataManager:GetUserGlobalData(strKey)
		v = x
	end)
	return v
end

--[[ Cấu hình quỹ: lấy từ `G_ActivityLogic` (đã nhận qua `ClientGetActivityList`);
	không có thì lấy thẳng từ lịch của lớp offline. ]]
local function cauHinhQuy(strType)
	local cfg = nil
	pcall(function () cfg = G_ActivityLogic:GetActivityConfigWithType(strType) end)
	if type(cfg) == "table" then return cfg end
	if OfflineHoatDong then return OfflineHoatDong:cauHinhCua(strType) end
	return nil
end

------------------------------------------------------------------- MUA QUỸ
R:on("G_ActivityFund.ClientBuyActivityFund", function (ctx, strFundType)
	if type(strFundType) ~= "string" or strFundType == "" then
		return loi(ctx, MA.ARG, "BuyActivityFund(tham so)")
	end

	local moKhong = false
	pcall(function ()
		moKhong = G_ActivityLogic:CheckActivityIsOpenWithType(strFundType) == true
	end)
	if not moKhong then
		return loi(ctx, MA.NOT_OPEN, "BuyActivityFund(hoat dong dong)")
	end

	local cfg = cauHinhQuy(strFundType)
	if type(cfg) ~= "table" then
		return loi(ctx, MA.NO_CONFIG, "BuyActivityFund(cau hinh)")
	end

	local okCan, maCan = goiCha("IsCanBuyFund", strFundType, cfg)
	if okCan ~= true then
		return loi(ctx, tonumber(maCan) or MA.UNKNOWN, "BuyActivityFund(IsCanBuyFund)")
	end

	-- Trừ kim cương bằng API gốc; `IsCanBuyFund` đã kiểm đủ tiền.
	local okTru, daTru = pcall(function ()
		return G_UserLogic:CostDiamond(cfg.Diamond, "ActivityFund")
	end)
	if not okTru or daTru ~= true then
		return loi(ctx, 4010, "BuyActivityFund(CostDiamond)")
	end

	local khoa = goiCha("getBuyFundKey", strFundType)
	if type(khoa) ~= "string" then khoa = "HasBuyActivityFoud_" .. strFundType end
	ghiCong(khoa, true)

	dongBo()
	OfflineLog:info(string.format("%s: da mua %s (gia %s kim cuong)",
		TEN_FILE, strFundType, tostring(cfg.Diamond)))

	-- UI nghe SỰ KIỆN `Active.OnBuyActivityFund` (`CUIActivityFund.lua:52`); chỉ phát
	-- sự kiện, KHÔNG gọi thẳng phương thức — panel chưa mở thì đối tượng chưa có layer.
	pcall(function ()
		G_EventManager:PostLogicEvent(strFundType, EventManagerLogicEvent.Active.OnBuyActivityFund)
	end)
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", 0, {})
end)

------------------------------------------------------------------- LĨNH QUỸ CẤP
--[[ `[MOI-3]` Bậc = `GetPrizeCount + 1`; chỉ lĩnh khi ĐÃ MUA quỹ và
	`userLevel >= bậc.Level`. Phát bằng `ReceivePrizeWithID` (PrizeID thật). ]]
R:on("G_ActivityFund.ClientGetLevelFundPrize", function (ctx)
	local okBuy, daMua = goiCha("IsBuyFund", "LevelFund")
	if okBuy ~= true or daMua ~= true then
		return loi(ctx, MA.HAS_GET, "GetLevelFundPrize(chua mua quy)")
	end

	local okDem, nDa = goiCha("GetPrizeCount", "LevelFund")
	if okDem ~= true then
		return loi(ctx, MA.UNKNOWN, "GetLevelFundPrize(GetPrizeCount)")
	end
	nDa = tonumber(nDa) or 0

	local danhSach = nil
	pcall(function () danhSach = G_ConfigManager:GetCommonConfigWithName("ActivityLevelFundConfig") end)
	if type(danhSach) ~= "table" then
		return loi(ctx, MA.NO_CONFIG, "GetLevelFundPrize(ActivityLevelFundConfig)")
	end

	local bac = danhSach[nDa + 1]
	if type(bac) ~= "table" then
		return loi(ctx, MA.NO_CONFIG, "GetLevelFundPrize(het bac)")
	end

	local nLevel = 0
	pcall(function () local _, l = G_UserLogic:GetLevel(); nLevel = tonumber(l) or 0 end)
	if nLevel < (tonumber(bac.Level) or 0) then
		return loi(ctx, 4011, string.format("GetLevelFundPrize(cap %d < %s)",
			nLevel, tostring(bac.Level)))
	end

	local okPhat, daPhat = pcall(function ()
		return G_PrizeLogic:ReceivePrizeWithID(bac.PrizeID, nil, "ActivityFund")
	end)
	if not okPhat or daPhat ~= true then
		return loi(ctx, MA.NO_CONFIG, "GetLevelFundPrize(ReceivePrizeWithID)")
	end

	local khoa = goiCha("getFundCountKey", "LevelFund")
	if type(khoa) ~= "string" then khoa = "ActivityFoudGetCount_LevelFund" end
	ghiCong(khoa, nDa + 1)

	dongBo()
	OfflineLog:info(string.format("%s: da linh bac %d cua Quy cap (PrizeID %s)",
		TEN_FILE, nDa + 1, tostring(bac.PrizeID)))
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", 0, {})
end)

------------------------------------------------------------------- LĨNH QUỸ THỜI GIAN
--[[ `[MOI-4]` Mỗi ngày một bậc; bậc = số đã lĩnh + 1. ]]
R:on("G_ActivityFund.ClientGetTimeFundPrize", function (ctx)
	local okBuy, daMua = goiCha("IsBuyFund", "TimeFund")
	if okBuy ~= true or daMua ~= true then
		return loi(ctx, MA.HAS_GET, "GetTimeFundPrize(chua mua quy)")
	end

	local okHom, homNay = goiCha("GetIsGetTimeFundToday")
	if okHom == true and homNay == true then
		return loi(ctx, MA.HAS_GET, "GetTimeFundPrize(hom nay da linh)")
	end

	local okDem, nDa = goiCha("GetPrizeCount", "TimeFund")
	if okDem ~= true then
		return loi(ctx, MA.UNKNOWN, "GetTimeFundPrize(GetPrizeCount)")
	end
	nDa = tonumber(nDa) or 0

	local danhSach = nil
	pcall(function () danhSach = G_ConfigManager:GetCommonConfigWithName("ActivityTimeFundConfig") end)
	if type(danhSach) ~= "table" then
		return loi(ctx, MA.NO_CONFIG, "GetTimeFundPrize(ActivityTimeFundConfig)")
	end

	local bac = danhSach[nDa + 1]
	if type(bac) ~= "table" then
		return loi(ctx, MA.NO_CONFIG, "GetTimeFundPrize(het bac)")
	end

	local okPhat, daPhat = pcall(function ()
		return G_PrizeLogic:ReceivePrizeWithID(bac.PrizeID, nil, "ActivityFund")
	end)
	if not okPhat or daPhat ~= true then
		return loi(ctx, MA.NO_CONFIG, "GetTimeFundPrize(ReceivePrizeWithID)")
	end

	local khoaDem = goiCha("getFundCountKey", "TimeFund")
	if type(khoaDem) ~= "string" then khoaDem = "ActivityFoudGetCount_TimeFund" end
	ghiCong(khoaDem, nDa + 1)
	ghiCong("IsGetTimeFundToday", true)

	dongBo()
	OfflineLog:info(string.format("%s: da linh bac %d cua Quy thoi gian (PrizeID %s)",
		TEN_FILE, nDa + 1, tostring(bac.PrizeID)))
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", 0, {})
end)

OfflineLog:info("quy hoat dong: da noi 3 khoa (BuyActivityFund / GetLevelFundPrize / GetTimeFundPrize)")

return true
