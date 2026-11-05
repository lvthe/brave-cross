--[[
	offline/handlers/the_luc.lua — MUA THỂ LỰC BẰNG KIM CƯƠNG.

	Lệnh `G_UserLogic.ClientBuyFatigue()` (`ClientUserLogic.lua:106`) — trước lượt này
	KHÔNG có handler nào ⇒ bấm "mua thể lực" là không phản hồi.

	LUẬT LÀ MÃ GỐC CÒN SỐNG: `UserLogic:buyFatigue` (`share/UserLogic.lua:2895-3013`),
	đọc thẳng cấu hình `GameBuyFatigueConfig`:
	  · `MaxBuy` + `CostList[{CostDiamond, GetFatigue}]` — chỉ số **`CurIndex + 1`**;
	  · trần theo VIP: `GetMaxFatigueBuyCount()` → `GetVipConfig("BuyFatigueCountList")`;
	  · `CostDiamond` → `AddFatigueValue(GetFatigue)` → lưu `BuyFatigueData` (client
	    common data, cơ chế `C_…` của `SetCommonData`) → phát `User.OnBuyFatigue`.
	Mã lỗi đều của `ErrorCode.UserLogic`/`Resource` (1808 thiếu cấu hình · 1809 chạm
	trần · 1702 không đủ kim cương · 1810 cộng thể lực hỏng · 1812 lưu hỏng).

	Gọi qua PROXY LỚP CHA: `G_UserLogic` là thể hiện `ClientUserLogic = class(UserLogic)`;
	tên hàm là **`buyFatigue`** (b thường — khác 9 hàm `Buy*` còn lại), chép đúng nguyên văn.

	Callback `OnServerBuyFatigue()` KHÔNG đối số (`ClientUserLogic.lua:118-121`).
]]

require("offline.log")
require("offline.store")
require("offline.router")

local R = OfflineRouter

local function lopCha(obj)
	local ten = obj:match("^G_(.+)$")
	if not ten then return nil end
	local c = _G[ten]
	return (type(c) == "table") and c or nil
end

local function goi(ten, ...)
	local o = _G.G_UserLogic
	if type(o) ~= "table" then return false end
	local c = lopCha("G_UserLogic")
	local self = (c and o[c]) or o
	local fn = self and self[ten]
	if type(fn) ~= "function" then return false end
	local args = { n = select("#", ...), ... }
	local ok, a, b = xpcall(function ()
		return fn(self, unpack(args, 1, args.n))
	end, function (e)
		return tostring(e) .. (debug and debug.traceback and ("\n" .. tostring(debug.traceback())) or "")
	end)
	if not ok then
		OfflineLog:err("the luc: " .. ten .. " nem loi: " .. tostring(a))
		return false
	end
	return true, a, b
end

R:on("G_UserLogic.ClientBuyFatigue", function (ctx)
	local ok, bRet, ma = goi("buyFatigue")
	pcall(function () OfflineStore:syncFromClient() end)

	if not ok or bRet ~= true then
		ma = tonumber(ma) or 1
		OfflineLog:info("the luc: luat goc tu choi, ma " .. tostring(ma))
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", ma, {})
		return
	end
	OfflineLog:info("the luc: da mua them the luc")
	ctx:call("G_UserLogic", "OnServerBuyFatigue")
end)

OfflineLog:info("the luc: da noi 1 khoa (ClientBuyFatigue)")

return true
