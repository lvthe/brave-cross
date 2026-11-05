--[[
	offline/handlers/nap_lien_tuc.lua — NẠP LIÊN TỤC (连续充值, ActivityType 32).

	Ba lệnh `G_ActivityContinuousRecharge` (`ClientActivityContinuousRecharge.lua:18/31/39`),
	trước lượt này KHÔNG có handler nào:

	  · `ClientGetUserState()`            → `OnGetUserState(tUserState)`
	  · `ClientGetDayPrize(nIndex)`       → KHÔNG có callback (client bỏ trống)
	  · `ClientGetContinuousPrize()`      → KHÔNG có callback (client bỏ trống)

	LUẬT GỐC: `share/Activities/ContinuousRechargeLogic.lua` — chỉ có VỊ TỪ, không có
	hàm phát thưởng:
	  · `IsCanGetContinuousPrize(tUserState,tActivityConfig)` — chưa nhận + đủ số NGÀY
	    (`ContinuousDayCount`) + mọi ngày trong `ContinuousList` đủ `RechargeCount`;
	  · `IsCanGetPrizeWithDay(tUserState,tActivityConfig,nIndex)` — ngày ấy đủ `RechargeCount`.
	Hình dạng dữ liệu lấy từ khối chú thích CÙNG tệp (`ContinuousRechargeData`):
	`RechargeList{Count,Time}` · `RechargeDayList` (tổng mỗi ngày) · `PrizeStates[index]`
	(1 = người chơi đã nhận, 2 = gửi qua thư) · `HasGetContinuousPrize`.

	ĐỌC THẲNG RA BA ĐIỀU về trạng thái offline trên máy này (đừng "phát hiện" lại):
	  1. **`RechargeList` RỖNG** — lớp offline KHÔNG có đường nạp tiền (nhóm
	     `G_RechargeLogic` 17 khoá đều "chết SDK" từ trước), nên ngày nào cũng 0 ⇒
	     hai lệnh nhận thưởng LUÔN bị từ chối. Đây là sự thật của dữ liệu, không phải
	     lỗi handler.
	  2. **Cấu hình hoạt động có thể VẮNG**: `G_ActivityLogic:GetActivityConfigWithType`
	     đọc `tOtherData.Activity` của gói đăng nhập; lớp offline không dựng nhánh ấy
	     ⇒ thường `nil`. Khi vắng thì từ chối bằng **4001** (`ActivityNotOpen`), không
	     bịa điều kiện.
	  3. **Callback client KHÔNG phát sự kiện UI** — hai dòng `PostLogicEvent`
	     (`OnGeContinuousRechargetDayPrize` / `OnGetContinuousRechargePrize`) đã BỊ
	     CHÚ THÍCH trong `ClientActivityContinuousRecharge.lua:34/43`, trong khi UI
	     `CUIActivityDailyRecharge.lua:63-70` VẪN đăng ký nghe hai tên ấy. Vì vậy
	     handler phát HỘ hai sự kiện đó sau khi phát thưởng — [MOI], ghi rõ để lượt
	     sau không tưởng client tự lo.

	LƯU TRẠNG THÁI: bảng MỚI `GameUserContinuousRecharge` (thêm vào
	`OfflineStore.TABLES`), dựng lượt đầu bằng hình dạng của khối chú thích trên.
	Mã lỗi: **4001** chưa mở · **1** chưa đủ điều kiện (bản gốc KHÔNG có mã riêng cho
	hoạt động này — `error.lua` không nhắc tên nó).
]]

require("offline.log")
require("offline.store")
require("offline.router")

local R = OfflineRouter
local BANG = "GameUserContinuousRecharge"

local function userData()
	local d = G_DataManager and G_DataManager.userData
	return (type(d) == "table") and d or nil
end

local function trangThai()
	local d = userData()
	if d == nil then return nil end
	local t = d[BANG]
	if type(t) ~= "table" then
		t = {
			RechargeList = {}, RechargeDayList = {}, PrizeStates = {},
			HasGetContinuousPrize = false,
		}
		d[BANG] = t
	end
	return t
end

local function cauHinh()
	local ok, c = pcall(function ()
		return G_ActivityLogic:GetActivityConfigWithType(ActivityType.ContinuousRecharge)
	end)
	if ok and type(c) == "table" then return c end
	return nil
end

local function dongBo()
	pcall(function () OfflineStore:syncFromClient() end)
end

local function hong(ctx, ma)
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", tonumber(ma) or 1, {})
end

local function phatSuKien(ten, duLieu)
	pcall(function () G_EventManager:PostLogicEvent(duLieu, ten) end)
end

-- Vị từ của luật gốc, gọi qua PROXY LỚP CHA (`G_ActivityContinuousRecharge` là thể
-- hiện `ClientActivityContinuousRecharge = class(ContinuousRechargeLogic)`).
local function viTu(ten, ...)
	local o = _G.G_ActivityContinuousRecharge
	if type(o) ~= "table" then return false end
	local lp = rawget(_G, "ContinuousRechargeLogic")
	local self = (type(lp) == "table" and o[lp]) or o
	local fn = self and self[ten]
	if type(fn) ~= "function" then return false end
	local args = { n = select("#", ...), ... }
	local ok, kq = pcall(function () return fn(self, unpack(args, 1, args.n)) end)
	return ok and kq == true
end

R:on("G_ActivityContinuousRecharge.ClientGetUserState", function (ctx)
	local s = trangThai()
	if s == nil then return hong(ctx, 509) end
	dongBo()
	ctx:call("G_ActivityContinuousRecharge", "OnGetUserState", s)
end)

R:on("G_ActivityContinuousRecharge.ClientGetDayPrize", function (ctx, nIndex)
	local s = trangThai()
	if s == nil then return hong(ctx, 509) end
	local c = cauHinh()
	if c == nil then return hong(ctx, 4001) end
	local i = tonumber(nIndex)
	if i == nil or i ~= math.floor(i) or i < 1 then return hong(ctx, 1) end
	s.PrizeStates = s.PrizeStates or {}
	if s.PrizeStates[tostring(i)] ~= nil then return hong(ctx, 1) end
	if not viTu("IsCanGetPrizeWithDay", s, c, i) then return hong(ctx, 1) end

	local muc = c.ContinuousList and c.ContinuousList[i]
	if type(muc) ~= "table" or type(muc.PrizeList) ~= "table" then return hong(ctx, 1) end
	local okP = pcall(function ()
		G_ChapterLogic:SetDataWithPrizeList(muc.PrizeList, nil, "ContinuousRecharge")
	end)
	if not okP then return hong(ctx, 1) end

	s.PrizeStates[tostring(i)] = 1          -- 1 = UserGet (ctor của luật gốc)
	dongBo()
	OfflineLog:info("nap lien tuc: da nhan thuong ngay " .. tostring(i))
	phatSuKien("OnGeContinuousRechargetDayPrize", i)
end)

R:on("G_ActivityContinuousRecharge.ClientGetContinuousPrize", function (ctx)
	local s = trangThai()
	if s == nil then return hong(ctx, 509) end
	local c = cauHinh()
	if c == nil then return hong(ctx, 4001) end
	if not viTu("IsCanGetContinuousPrize", s, c) then return hong(ctx, 1) end

	local prize = c.ContinuousPrize and c.ContinuousPrize.PrizeList
	if type(prize) ~= "table" then return hong(ctx, 1) end
	local okP = pcall(function ()
		G_ChapterLogic:SetDataWithPrizeList(prize, nil, "ContinuousRecharge")
	end)
	if not okP then return hong(ctx, 1) end

	s.HasGetContinuousPrize = true
	dongBo()
	OfflineLog:info("nap lien tuc: da nhan thuong lien tuc")
	phatSuKien("OnGetContinuousRechargePrize", nil)
end)

OfflineLog:info("nap lien tuc: da noi 3 khoa (GetUserState / GetDayPrize / GetContinuousPrize)")

return true
