--[[
	offline/handlers/trang_bi_pham.lua — NÂNG PHẨM + TẨY LUYỆN trang bị.

	Hai lệnh client (`ClientEquipmentLogic.lua:393/487`). Cả hai ĐÃ có handler trong
	`handlers/tinh_nang.lua:158/168` từ 28/10 nhưng chỉ gọi luật gốc rồi thôi —
	mà luật gốc BỎ SÓT phần cuối, y như `IntensifyEquipment`:

	  · `PromoteQualityEquipment` (`share_EquipmentLogic.lua:792-877`) đổi
	    `Quality + 1` nhưng **KHÔNG tính lại thuộc tính phụ**;
	  · `RecastEquipment` (`:650-780`) **chỉ trả nguyên liệu** (đá tẩy luyện 97 hoặc
	    vàng/kim cương), **KHÔNG bốc lại** `BaseValue`.

	Phần thiếu ấy là của máy chủ đã chết. Ở đây:
	  · Nâng phẩm: `updateAppendProperty(equipment)` (`share_EquipmentPropertyLogic.lua:562`)
	    GIỮ `BaseValue`, tính lại `Value` = coef·(Base·Quality − 0,3)·(hệ số cấp/20)
	    — đúng công thức `getAppendPropertyValue` (`:465-502`).
	  · Tẩy luyện: bốc lại `BaseValue` trong **0,8…1,3** (`AppendPropertyRandomRange`,
	    `share_EquipmentLogic.lua:16-17`) rồi tính lại `Value` bằng CÙNG công thức.
	    **[GHIM]** thứ tự gọi `math.random` là của ta; máy chủ gốc không còn để đối chiếu.

	Nạp SAU `tinh_nang` để ghi đè hai khoá (log có cảnh báo "dang ky de handler").
	Trả lời đủ tham số: `OnServerPromoteQualityEquipment(h, p, danhSách)` ·
	`OnServerRecastEquipment(h, p, resourceType, danhSách)`.
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
		OfflineLog:err("trang bi " .. ten .. " nem loi: " .. tostring(a))
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

local function layDo(h, p)
	local ok, bRet, equip = goi("GetEquipment", h, p)
	if ok and bRet == true and type(equip) == "table" then return equip end
	return nil
end

-- Tính lại `Value` của MỌI thuộc tính phụ từ `BaseValue` hiện có.
local function tinhLaiGiaTri(equip)
	if type(equip.AppendProperty) ~= "table" then return end
	for _, ap in ipairs(equip.AppendProperty) do
		if type(ap) == "table" then
			local ok, bRet, v = goi("getAppendPropertyValue",
				ap.BaseValue, ap.PropertyType, equip.Quality, equip.EquipLevel, equip.EquipmentType)
			if ok and bRet == true and v ~= nil then ap.Value = v end
		end
	end
end

R:on("G_EquipmentLogic.ClientPromoteQualityEquipment", function (ctx, nHeroID, nPartID)
	local h, p = tonumber(nHeroID), tonumber(nPartID)
	if h == nil or p == nil then return loi(ctx, 2, "Promote(type)") end

	local ok, bRet, ma = goi("PromoteQualityEquipment", h, p)
	if not ok or bRet ~= true then return loi(ctx, ma, "Promote") end

	local equip = layDo(h, p)
	if equip == nil then return loi(ctx, 1, "Promote(lay do)") end
	-- GIỮ BaseValue, chỉ tính lại Value theo Quality mới (mã gốc của bước này).
	pcall(function () goi("updateAppendProperty", equip) end)
	-- Bản ghi đổi cả giá cường hoá/trần theo phẩm mới.
	pcall(function () goi("updateEquipData", equip) end)
	dongBo()

	OfflineLog:info(string.format("trang bi: nang pham hero %s o %s -> pham %s",
		tostring(h), tostring(p), tostring(equip.Quality)))
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse",
		"G_EquipmentLogic", "OnServerPromoteQualityEquipment", 0, {}, h, p, equip.AppendProperty or {})
end)

R:on("G_EquipmentLogic.ClientRecastEquipment", function (ctx, nHeroID, nPartID, nResourceType)
	local h, p, rt = tonumber(nHeroID), tonumber(nPartID), tonumber(nResourceType)
	if h == nil or p == nil or rt == nil then return loi(ctx, 2, "Recast(type)") end

	local ok, bRet, ma = goi("RecastEquipment", h, p, rt)
	if not ok or bRet ~= true then return loi(ctx, ma, "Recast") end

	local equip = layDo(h, p)
	if equip == nil then return loi(ctx, 1, "Recast(lay do)") end

	-- [GHIM] BỐC LẠI BaseValue trong 0,8…1,3 (share_EquipmentLogic.lua:16-17).
	local m = tonumber(equip.AppendPropertyRandomRangeMin) or 0.8
	local M = tonumber(equip.AppendPropertyRandomRangeMax) or 1.3
	if type(equip.AppendProperty) == "table" then
		for _, ap in ipairs(equip.AppendProperty) do
			if type(ap) == "table" then
				ap.BaseValue = m + math.random() * (M - m)
			end
		end
	end
	tinhLaiGiaTri(equip)
	dongBo()

	OfflineLog:info(string.format("trang bi: tay luyen hero %s o %s (kieu %s), %d thuoc tinh",
		tostring(h), tostring(p), tostring(rt),
		(type(equip.AppendProperty) == "table") and #equip.AppendProperty or 0))
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse",
		"G_EquipmentLogic", "OnServerRecastEquipment", 0, {}, h, p, rt, equip.AppendProperty or {})
end)

OfflineLog:info("trang bi pham: da dang ky lai 2 khoa (ghi de tinh_nang.lua:158/168)")

return true
