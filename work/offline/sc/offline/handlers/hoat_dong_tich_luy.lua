--[[
	offline/handlers/hoat_dong_tich_luy.lua — HOẠT ĐỘNG TÍCH LUỸ (4 khoá, 2 hoạt động).

	  · `G_ActivityCumulativeRecharge|ClientGetUserState` → `OnGetCumulativeRechargeData(nạp, state)`
	  · `G_ActivityCumulativeRecharge|ClientGetPrize(nIndex)`
	  · `G_ActivityCumulativeConsume|ClientGetUserState`  → `OnGetCumulativeConsumeData(tiêu, state)`
	  · `G_ActivityCumulativeConsume|ClientGetPrize(nIndex)`

	HÌNH DỮ LIỆU đọc từ chính UI (không đoán):
	  · `CUIActivityAccumRecharge:updateItemData` đọc cấu hình là **MẢNG** mỗi bậc
	    `{Recharge, PrizeList}`; `CUIActivityAccumConsume` là `{Consume, PrizeList}`.
	  · `state` là BẢN ĐỒ `[tostring(index)] = true/1` (chú thích của chính bản gốc:
	    `CUIActivityAccumRecharge.lua` "dữ liệu máy chủ gửi chỉ có [true/1/nil]").
	  · Callback `OnGetCumulativeRechargeData(nUserRechargeCount, userState)` và
	    `OnGetCumulativeConsumeData(nUserConsumeCount, userState)` — hai hàm PHƯƠNG THỨC
	    trên thực thể `G_ActivityCumulativeRecharge` / `G_ActivityCumulativeConsume`.

	BA NGUỒN SỐ — hai nguồn THẬT, một nguồn của lớp offline:
	  · **Nạp** = `G_RechargeLogic:GetUserRechargeCount()` — THẬT; `OfflineNap:cong`
	    (30/10) là đường làm nó tăng.
	  · **Tiêu** = bộ đếm `OfflineTichLuy` cắm vào `G_UserLogic:CostGold`/`CostDiamond`
	    (`[MOI-1]`), vì cây KHÔNG có hàm `GetUserConsumeCount` nào (grep 0). Cùng cách
	    bọc mà `OfflineThongKe` đã dùng cho `AddFatigueValue` — chỉ đếm khi luật gốc
	    trả `true` (trừ thành công).
	  · **Cấu hình bậc** vẫn do `offline/hoat_dong.lua` cấp; hiện hai hoạt động này ĐÓNG
	    (`OfflineHoatDong.DONG`) vì dữ liệu ship không có bậc thưởng. Handler ở đây
	    CHẠY ĐƯỢC ngay khi chủ dự án điền `OfflineHoatDong.MO_THEM` — đó là lý do tệp
	    này tồn tại.

	Mã lỗi — nhóm `ErrorCode.Activity`: **4001** ActivityNotOpen (không có cấu hình) ·
	**4007** HasGetActivityPrize · **4008** NoEnoughRechargeCount · **4009**
	NoEnoughConsumeCount. `[MOI-2]` ánh xạ "bậc không tồn tại" về 4001.
]]

require("offline.log")
require("offline.store")
require("offline.router")
require("offline.hoat_dong")

OfflineTichLuy = OfflineTichLuy or {}

local R = OfflineRouter
local TEN_FILE = "hoat dong tich luy"

local MA = {
	ARG = 2,
	NOT_OPEN = 4001,
	HAS_GET = 4007,
	NO_RECHARGE = 4008,
	NO_CONSUME = 4009,
	UNKNOWN = 1,
}

--[[ [MOI-1] Hai khoá trạng thái của lớp offline (bản gốc giữ ở máy chủ, không ship:
	`ClientActivityCumulativeRecharge.UserState` chỉ là bộ nhớ client). ]]
local KHOA_TIEU = "CumulativeConsumeValue"        -- tổng đã tiêu
local KHOA_STATE_Nap = "CumulativeRechargeState"  -- bản đồ bậc đã lĩnh (nạp)
local KHOA_STATE_Tieu = "CumulativeConsumeState"  -- bản đồ bậc đã lĩnh (tiêu)

local function dongBo()
	pcall(function () OfflineStore:syncFromClient() end)
end

local function docCong(khoa, macDinh)
	local v = nil
	pcall(function ()
		local _, x = G_UserDataManager:GetUserGlobalData(khoa)
		v = x
	end)
	if v == nil then return macDinh end
	return v
end

local function ghiCong(khoa, giaTri)
	pcall(function () G_UserDataManager:SetUserGlobalData(khoa, giaTri) end)
end

------------------------------------------------------------------- BỘ ĐẾM TIÊU
--[[ Bọc `CostGold`/`CostDiamond`. Chỉ đếm khi hàm gốc trả `true` (đã trừ thật).
	Bọc lớp là cách `OfflineThongKe:dam_bao()` đã dùng cho `AddFatigueValue`. ]]
OfflineTichLuy.ham_goi_vang = nil
OfflineTichLuy.ham_goi_kc = nil

function OfflineTichLuy:congTieu(n)
	if type(n) ~= "number" or n <= 0 then return end
	local cu = tonumber(docCong(KHOA_TIEU, 0)) or 0
	ghiCong(KHOA_TIEU, cu + n)
end

function OfflineTichLuy:dam_bao()
	--[[ Chịu được cả lời gọi bằng DẤU CHẤM (`OfflineTichLuy.dam_bao()`, self = nil).

		ĐO ĐƯỢC 31/10: `init.lua` từng gọi bằng dấu chấm ⇒ `self` nil ⇒ dòng dưới
		ném "attempt to index local 'self' (a nil value)" NGAY trong `require`, cả
		lớp offline không nạp được và **GAME THOÁT** (`onSystemExit`) — triệu chứng
		trên máy chỉ là màn splash đứng im, y như bị panel SDK chặn. Bộ thử tĩnh
		không bắt được vì nó gọi bằng dấu hai chấm; `run_tests.py` cũng không vì
		mock ở đó không có `G_UserLogic`. ]]
	local this = self or OfflineTichLuy
	if type(_G.G_UserLogic) ~= "table" then return false end

	-- Vàng
	if type(G_UserLogic.CostGold) == "function"
		and (this.ham_goi_vang == nil or G_UserLogic.CostGold ~= this.ham_goi_vang) then
		local goc = G_UserLogic.CostGold
		this.ham_goi_vang = function (self_, nCount, ...)
			local a, b = goc(self_, nCount, ...)
			if a == true then OfflineTichLuy:congTieu(tonumber(nCount)) end
			return a, b
		end
		G_UserLogic.CostGold = this.ham_goi_vang
	end

	-- Kim cương
	if type(G_UserLogic.CostDiamond) == "function"
		and (this.ham_goi_kc == nil or G_UserLogic.CostDiamond ~= this.ham_goi_kc) then
		local goc = G_UserLogic.CostDiamond
		this.ham_goi_kc = function (self_, nCount, ...)
			local a, b = goc(self_, nCount, ...)
			if a == true then OfflineTichLuy:congTieu(tonumber(nCount)) end
			return a, b
		end
		G_UserLogic.CostDiamond = this.ham_goi_kc
	end

	return this.ham_goi_vang ~= nil and this.ham_goi_kc ~= nil
end

--------------------------------------------------------------- tiện ích chung
local function loi(ctx, ma, viSao)
	OfflineLog:info(string.format("%s: tu choi, ma %d (%s)",
		TEN_FILE, tonumber(ma) or 1, tostring(viSao)))
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", tonumber(ma) or 1, {})
end

--[[ Cấu hình bậc của hoạt động — lấy từ `G_ActivityLogic` (đã nhận qua
	`ClientGetActivityList`), không có thì lấy từ lịch của lớp offline. ]]
local function cauHinhBac(strType)
	local cfg = nil
	pcall(function () cfg = G_ActivityLogic:GetActivityConfigWithType(strType) end)
	if type(cfg) == "table" and #cfg > 0 then return cfg end
	return nil
end

local function moKhong(strType)
	local mo = false
	pcall(function () mo = G_ActivityLogic:CheckActivityIsOpenWithType(strType) == true end)
	return mo
end

------------------------------------------------------------------- NẠP
R:on("G_ActivityCumulativeRecharge.ClientGetUserState", function (ctx)
	local cfg = cauHinhBac("CumulativeRecharge")
	if cfg == nil or not moKhong("CumulativeRecharge") then
		return loi(ctx, MA.NOT_OPEN, "Recharge.GetUserState(chua mo)")
	end
	local state = docCong(KHOA_STATE_Nap, {})
	if type(state) ~= "table" then state = {} end

	local n = 0
	pcall(function ()
		local _, c = G_RechargeLogic:GetUserRechargeCount()
		n = tonumber(c) or 0
	end)
	OfflineLog:info(string.format("%s: nap = %s, da linh %d bac", TEN_FILE, tostring(n),
		(function () local k = 0; for _ in pairs(state) do k = k + 1 end; return k end)()))
	ctx:call("G_ActivityCumulativeRecharge", "OnGetCumulativeRechargeData", n, state)
end)

R:on("G_ActivityCumulativeRecharge.ClientGetPrize", function (ctx, nIndex)
	local idx = tonumber(nIndex)
	if idx == nil then return loi(ctx, MA.ARG, "Recharge.GetPrize(tham so)") end

	local cfg = cauHinhBac("CumulativeRecharge")
	if cfg == nil or not moKhong("CumulativeRecharge") then
		return loi(ctx, MA.NOT_OPEN, "Recharge.GetPrize(chua mo)")
	end
	local bac = cfg[idx]
	if type(bac) ~= "table" or type(bac.PrizeList) ~= "table" then
		return loi(ctx, MA.NOT_OPEN, "Recharge.GetPrize(bac " .. idx .. ")")
	end

	local state = docCong(KHOA_STATE_Nap, {})
	if type(state) ~= "table" then state = {} end
	if state[tostring(idx)] then
		return loi(ctx, MA.HAS_GET, "Recharge.GetPrize(da linh bac " .. idx .. ")")
	end

	local n = 0
	pcall(function ()
		local _, c = G_RechargeLogic:GetUserRechargeCount()
		n = tonumber(c) or 0
	end)
	if n < (tonumber(bac.Recharge) or 0) then
		return loi(ctx, MA.NO_RECHARGE, string.format("Recharge.GetPrize(nap %s < %s)",
			tostring(n), tostring(bac.Recharge)))
	end

	local okPhat, daPhat = pcall(function ()
		return G_ChapterLogic:SetDataWithPrizeList(bac.PrizeList, nil, "CumulativeRecharge")
	end)
	if not okPhat or daPhat ~= true then
		return loi(ctx, MA.UNKNOWN, "Recharge.GetPrize(SetDataWithPrizeList)")
	end

	state[tostring(idx)] = true
	ghiCong(KHOA_STATE_Nap, state)
	dongBo()
	OfflineLog:info(string.format("%s: da linh bac nap %d", TEN_FILE, idx))
	pcall(function ()
		G_EventManager:PostLogicEvent(idx, EventManagerLogicEvent.Active.OnGetCumulativeRechargePrize)
	end)
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", 0, {})
end)

------------------------------------------------------------------- TIÊU
R:on("G_ActivityCumulativeConsume.ClientGetUserState", function (ctx)
	local cfg = cauHinhBac("CumulativeConsume")
	if cfg == nil or not moKhong("CumulativeConsume") then
		return loi(ctx, MA.NOT_OPEN, "Consume.GetUserState(chua mo)")
	end
	local state = docCong(KHOA_STATE_Tieu, {})
	if type(state) ~= "table" then state = {} end
	local n = tonumber(docCong(KHOA_TIEU, 0)) or 0
	OfflineLog:info(string.format("%s: tieu = %s", TEN_FILE, tostring(n)))
	ctx:call("G_ActivityCumulativeConsume", "OnGetCumulativeConsumeData", n, state)
end)

R:on("G_ActivityCumulativeConsume.ClientGetPrize", function (ctx, nIndex)
	local idx = tonumber(nIndex)
	if idx == nil then return loi(ctx, MA.ARG, "Consume.GetPrize(tham so)") end

	local cfg = cauHinhBac("CumulativeConsume")
	if cfg == nil or not moKhong("CumulativeConsume") then
		return loi(ctx, MA.NOT_OPEN, "Consume.GetPrize(chua mo)")
	end
	local bac = cfg[idx]
	if type(bac) ~= "table" or type(bac.PrizeList) ~= "table" then
		return loi(ctx, MA.NOT_OPEN, "Consume.GetPrize(bac " .. idx .. ")")
	end

	local state = docCong(KHOA_STATE_Tieu, {})
	if type(state) ~= "table" then state = {} end
	if state[tostring(idx)] then
		return loi(ctx, MA.HAS_GET, "Consume.GetPrize(da linh bac " .. idx .. ")")
	end

	local n = tonumber(docCong(KHOA_TIEU, 0)) or 0
	if n < (tonumber(bac.Consume) or 0) then
		return loi(ctx, MA.NO_CONSUME, string.format("Consume.GetPrize(tieu %s < %s)",
			tostring(n), tostring(bac.Consume)))
	end

	local okPhat, daPhat = pcall(function ()
		return G_ChapterLogic:SetDataWithPrizeList(bac.PrizeList, nil, "CumulativeConsume")
	end)
	if not okPhat or daPhat ~= true then
		return loi(ctx, MA.UNKNOWN, "Consume.GetPrize(SetDataWithPrizeList)")
	end

	state[tostring(idx)] = true
	ghiCong(KHOA_STATE_Tieu, state)
	dongBo()
	OfflineLog:info(string.format("%s: da linh bac tieu %d", TEN_FILE, idx))
	pcall(function ()
		G_EventManager:PostLogicEvent(idx, EventManagerLogicEvent.Active.OnGetCumulativeConsumePrize)
	end)
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", 0, {})
end)

OfflineLog:info("hoat dong tich luy: da noi 4 khoa (nap/tiêu x GetUserState/GetPrize)")

return true
