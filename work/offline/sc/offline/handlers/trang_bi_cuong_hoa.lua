--[[
	offline/handlers/trang_bi_cuong_hoa.lua — CƯỜNG HOÁ TRANG BỊ (装备强化).

	Hai lệnh client (`ClientEquipmentLogic.lua:143/298`), trước lượt này KHÔNG có
	handler nào ⇒ bấm "cường hoá" / "tự động" trong màn trang bị là lớp tải quay mãi.

	  · `G_EquipmentLogic.ClientIntensifyEquipment(nHeroID, nEquipPartID)`
	  · `G_EquipmentLogic.ClientAutoIntensifyEquipment(nHeroID, nEquipPartID)`

	LUẬT (cổng + trừ vàng) LÀ MÃ GỐC: `EquipmentLogic:IntensifyEquipment`
	(`share_EquipmentLogic.lua:511-585`) — thứ tự cổng: có anh hùng (1301) → không
	khoá (1307) → ô có đồ, `EquipLevel ~= 0` (1106) → `IntensifyLevel < HeroLevel`
	và `< MaxIntensifyLevel` (1102) → đủ vàng (1103, giá `ResourceForIntensify` của
	CẤP KẾ do `updateEquipData` đặt, `:1273`) → `CostGold`.

	PHẦN BẢN GỐC ĐỂ CHO MÁY CHỦ: thân `IntensifyEquipment` CHỈ TRỪ VÀNG, KHÔNG
	cộng cấp. Lượt cộng cấp nằm trong bản client ĐÃ BỊ CHÚ THÍCH
	(`ClientEquipmentLogic.lua:330-386`), và đó là khuôn ta dùng — nguyên văn ba bước:
	  `G_EquipmentDataManager:SetEquipIntensifyLevel(hero, part, cấp + 1)` (`:199`,
	  tự phát Data event `GameUserEquipment.IntensifyLevel`) →
	  `self:updateEquipData(equipment)` (`:1196`, đặt lại giá cấp kế) →
	  `PostLogicEvent(..., OnIntensifyEquipment)`. Ghi nguyên văn để lượt sau không
	  phải "phát hiện lại" là thiếu.

	TỰ ĐỘNG (`AutoIntensifyEquipment`, `:593-640`) trong `share/` **CHỈ KIỂM rồi trả
	true** — vòng cộng cấp nằm trong máy chủ đã chết. Ở đây vòng ấy là TÁI DỰNG
	([GHIM]): lặp gọi đúng luật gốc từng cấp cho tới khi nó từ chối (hết vàng /
	chạm trần / hết `HeroLevel`), đếm số cấp đã cộng — đúng cách phía server đã làm
	ở Mốc 54 (`bravecross-server`, `ClientAutoIntensifyEquipment`).
]]

require("offline.log")
require("offline.store")
require("offline.router")

local R = OfflineRouter
local SO_CAP_TOI_DA = 200       -- chốt an toàn của vòng lặp tái dựng

local function lopCha(obj)
	local ten = obj:match("^G_(.+)$")
	if not ten then return nil end
	local c = _G[ten]
	return (type(c) == "table") and c or nil
end

-- Gọi hàm LỚP CHA trên `G_EquipmentLogic`; trả NGUYÊN bộ giá trị bản gốc.
local function goi(ten, ...)
	local o = _G.G_EquipmentLogic
	if type(o) ~= "table" then return false end
	local c = lopCha("G_EquipmentLogic")
	local self = (c and o[c]) or o
	local fn = self and self[ten]
	if type(fn) ~= "function" then return false end
	local args = { n = select("#", ...), ... }
	local ok, a, b, d = xpcall(function ()
		return fn(self, unpack(args, 1, args.n))
	end, function (e)
		return tostring(e) .. (debug and debug.traceback and ("\n" .. tostring(debug.traceback())) or "")
	end)
	if not ok then
		OfflineLog:err("trang bi: " .. ten .. " nem loi: " .. tostring(a))
		return false
	end
	return true, a, b, d
end

local function dongBo()
	pcall(function () OfflineStore:syncFromClient() end)
end

local function loi(ctx, ma, ten)
	ma = tonumber(ma) or 1
	OfflineLog:info(string.format("trang bi %s: luat goc tu choi, ma %d", tostring(ten), ma))
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", ma, {})
end

--[[ Cộng MỘT cấp sau khi luật gốc đã trừ vàng. Trả cấp MỚI, hoặc nil nếu hỏng
	(không lấy được bản ghi — coi như thất bại để không báo sai cho UI). ]]
local function congMotCap(nHeroID, nPartID)
	local ok, bRet, equip = goi("GetEquipment", nHeroID, nPartID)
	if not ok or bRet ~= true or type(equip) ~= "table" then return nil end
	local capMoi = (tonumber(equip.IntensifyLevel) or 0) + 1
	local okSet = pcall(function ()
		G_EquipmentDataManager:SetEquipIntensifyLevel(nHeroID, nPartID, capMoi)
	end)
	if not okSet then return nil end
	pcall(function () goi("updateEquipData", equip) end)
	return capMoi, equip
end

R:on("G_EquipmentLogic.ClientIntensifyEquipment", function (ctx, nHeroID, nEquipPartID)
	local h, p = tonumber(nHeroID), tonumber(nEquipPartID)
	if h == nil or p == nil then return loi(ctx, 2, "Intensify(type)") end

	local ok, bRet, ma = goi("IntensifyEquipment", h, p)
	if not ok or bRet ~= true then return loi(ctx, ma, "Intensify") end

	local capMoi = congMotCap(h, p)
	dongBo()
	if capMoi == nil then return loi(ctx, 1, "Intensify(cong cap)") end

	OfflineLog:info(string.format("trang bi: cuong hoa hero %s o %s -> cap %s", tostring(h), tostring(p), tostring(capMoi)))
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse",
		"G_EquipmentLogic", "OnServerIntensifyEquipment", 0, {}, h, p, capMoi)
end)

R:on("G_EquipmentLogic.ClientAutoIntensifyEquipment", function (ctx, nHeroID, nEquipPartID)
	local h, p = tonumber(nHeroID), tonumber(nEquipPartID)
	if h == nil or p == nil then return loi(ctx, 2, "AutoIntensify(type)") end

	-- [GHIM] TÁI DỰNG vòng: share chỉ kiểm rồi trả true (xem đầu tệp).
	local soCap = 0
	local cungCuoi = nil
	while soCap < SO_CAP_TOI_DA do
		local ok, bRet = goi("IntensifyEquipment", h, p)
		if not ok or bRet ~= true then break end          -- hết vàng / chạm trần / hết cấp
		local capMoi, equip = congMotCap(h, p)
		if capMoi == nil then break end
		cungCuoi = equip
		soCap = soCap + 1
	end
	dongBo()

	-- Hết vàng ở cấp ĐẦU: bản gốc vẫn trả thành công với 0 cấp (Mốc 54 đã ghim).
	local conLai = (cungCuoi and tonumber(cungCuoi.ResourceForIntensify)) or 0
	OfflineLog:info(string.format("trang bi: tu dong cuong hoa hero %s o %s -> +%d cap", tostring(h), tostring(p), soCap))
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse",
		"G_EquipmentLogic", "OnServerAutoIntensifyEquipment", 0, {}, h, p, soCap, conLai)
end)

OfflineLog:info("trang bi cuong hoa: da dang ky lai 2 khoa (ghi de tinh_nang.lua:138/148)")

return true
