--[[
	offline/thu_doc_quyen.lua — ĐỒ THỬ trong game cho TRANG BỊ ĐỘC QUYỀN.

	Bật bằng tệp cờ `thu_doc_quyen.flag` cạnh file lưu (tự xoá sau khi chạy). Sau khi
	vào cảnh Main, nó:

	  1. Đo CẤU HÌNH THẬT có đọc được không (`KDBGameExclusiveEquipConfig`):
	     danh sách tướng · bảng đúc · bảng tinh luyện.
	  2. Chuẩn bị trên TÀI KHOẢN THỬ: thêm tướng 10 (có trong danh sách), tạo một ô
	     trang bị bộ phận 2 chất lượng 6 / tinh luyện thường 5, cấp đủ nguyên liệu.
	  3. Gọi THẲNG hai handler qua `OfflineRouter` với `ctx` giả (cùng cách
	     `thu_nhom_moi.lua`), ghi mã lỗi + trạng thái sau mỗi lượt.
	  4. Gọi lại lệnh đúc lần hai để thấy cửa `IsExclusive = 1116`.

	CHỈ dùng trên tài khoản thử: nó THÊM tướng và trang bị vào bản lưu.
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflineThuDocQuyen = OfflineThuDocQuyen or {}

local T = OfflineThuDocQuyen

T.TEP_CO = "thu_doc_quyen.flag"
T.CHO = 8
T.DEM = 0
T.DA_CHAY = false

local N_HERO = 10          -- có trong ExclusiveEquipHeroConfig
local N_PHAN = 2           -- bộ phận 2 (không phải vũ khí — vũ khí đòi 4 món kia)

local function thuMuc() return (OfflineStore:path():gsub("[^/]*$", "")) end
local function coTepCo()
	local ok, fp = pcall(io.open, thuMuc() .. T.TEP_CO, "r")
	if ok and fp then fp:close(); return true end
	return false
end
local function xoaCo() pcall(os.remove, thuMuc() .. T.TEP_CO) end
local function ghi(m) OfflineLog:info("THU DOC QUYEN: " .. tostring(m)) end

local function ctxGia()
	local c = { calls = {} }
	function c:call(obj, f, a, b, ma, ev)
		self.calls[#self.calls + 1] = { obj = obj, f = f, a = a, b = b, err = ma, ev = ev }
		return true
	end
	return c
end

local function goi(obj, func, ...)
	local fn = OfflineRouter:getFor(obj, func)
	if fn == nil then return nil, "CHUA DANG KY" end
	local ctx = ctxGia()
	local ok, err = pcall(fn, ctx, ...)
	if not ok then return nil, tostring(err) end
	return ctx
end

local function maCua(ctx)
	local x = ctx and ctx.calls[#ctx.calls]
	if x == nil then return nil end
	return tonumber(x.err)
end

local function docCauHinh(ten)
	local ok, t = pcall(function ()
		return G_ConfigManager[ten](G_ConfigManager)
	end)
	if ok and type(t) == "table" then return t end
	return nil
end

local function layKhoa(t, k)
	if type(t) ~= "table" then return nil end
	return t[k] or t[tostring(k)]
end

local function layDo(h, p)
	local ok, _, e = pcall(function () return G_EquipmentLogic:GetEquipment(h, p) end)
	if ok and type(e) == "table" then return e end
	return nil
end

function T:chay()
	-- 1. cấu hình
	local dsTuong = docCauHinh("GetExclusiveEquipHeroConfig")
	local cfgDuc   = docCauHinh("GetExclusiveEquipForgeConfig")
	local cfgLuyen = docCauHinh("GetExclusiveEquipPurifyConfig")

	local nTuong, co10 = 0, false
	if dsTuong then
		for _, v in ipairs(dsTuong) do
			nTuong = nTuong + 1
			if tonumber(v) == N_HERO then co10 = true end
		end
	end
	ghi(string.format("cau hinh: tuong=%s (co %d=%s) · duc=%s · luyen=%s",
		tostring(dsTuong ~= nil), nTuong, tostring(co10),
		tostring(cfgDuc ~= nil), tostring(cfgLuyen ~= nil)))
	if dsTuong == nil or cfgDuc == nil or cfgLuyen == nil then
		ghi("THIEU CAU HINH — dung lai (config manager chua nap KDBGameExclusiveEquipConfig)")
		return
	end

	-- 2. chuẩn bị tài khoản thử
	local okHero, bCoHero, hero = pcall(function () return G_HeroLogic:GetHeroWithID(N_HERO) end)
	if not (okHero and bCoHero == true and type(hero) == "table") then
		local themOk, them = pcall(function ()
			return G_HeroLogic:AddHero(N_HERO, 1, "thu_doc_quyen")
		end)
		ghi("them tuong " .. N_HERO .. " -> " .. tostring(themOk) .. "/" .. tostring(them))
	end

	local e = layDo(N_HERO, N_PHAN)
	if e == nil then
		local ok, b = pcall(function ()
			return G_EquipmentDataManager:AddEquip({
				HeroID = N_HERO, EquipPartID = N_PHAN, EquipLevel = 1,
				Quality = 6, RefineLevel = 5, EquipmentType = 24,
				IsExist = true, IsIdentified = false, IsDedicated = false,
				IntensifyLevel = 0, State = 0,
			})
		end)
		e = layDo(N_HERO, N_PHAN)
		ghi("tao o trang bi -> " .. tostring(ok) .. "/" .. tostring(b) .. " (tim lai: "
			.. tostring(e ~= nil) .. ")")
	end
	if e == nil then
		ghi("KHONG tao duoc trang bi — dung lai")
		return
	end
	e.Quality = 6
	e.EquipLevel = 1
	e.RefineLevel = 5
	pcall(function () G_EquipmentLogic:updateEquipData(e, true) end)

	-- nguyên liệu đúc (cấu hình thật)
	local dong = layKhoa(layKhoa(cfgDuc, N_HERO), N_PHAN)
	if type(dong) ~= "table" or type(dong.ItemList) ~= "table" then
		ghi("thieu dong cau hinh duc cho tuong " .. N_HERO .. "/o " .. N_PHAN)
		return
	end
	for _, v in ipairs(dong.ItemList) do
		local _, _, n = pcall(function () return G_ItemLogic:GetItemCount(v.ItemID) end)
		if (tonumber(n) or 0) < v.Count then
			pcall(function () G_ItemLogic:AddItem(v.ItemID, v.Count, "thu_doc_quyen") end)
		end
	end

	local _, tinhHoaTruoc = pcall(function () return G_UserLogic:GetConcentrate() end)
	ghi(string.format("truoc: IsExclusive=%s · RefineLevel=%s · tinh hoa=%s",
		tostring(e.IsExclusive), tostring(e.RefineLevel), tostring(tinhHoaTruoc)))

	-- 3. ĐÚC
	local c1, err1 = goi("G_EquipmentLogic", "ClientForgingExclusiveEquip", N_HERO, N_PHAN)
	ghi(string.format("duc -> ma=%s%s · IsExclusive=%s",
		tostring(maCua(c1)), err1 and (" LOI " .. err1) or "", tostring(e.IsExclusive)))

	-- 4. ĐÚC LẦN HAI (phải bị cửa 1116)
	local c2 = goi("G_EquipmentLogic", "ClientForgingExclusiveEquip", N_HERO, N_PHAN)
	ghi("duc lan hai -> ma=" .. tostring(maCua(c2)))

	-- 5. TINH LUYỆN ĐỘC QUYỀN
	local c3, err3 = goi("G_EquipmentLogic", "ClientPurifyExclusiveEquip", N_HERO, N_PHAN)
	local _, tinhHoaSau = pcall(function () return G_UserLogic:GetConcentrate() end)
	ghi(string.format("tinh luyen -> ma=%s%s · RefineLevel=%s · tinh hoa=%s (tru %s)",
		tostring(maCua(c3)), err3 and (" LOI " .. err3) or "",
		tostring(e.RefineLevel), tostring(tinhHoaSau),
		tostring((tonumber(tinhHoaTruoc) or 0) - (tonumber(tinhHoaSau) or 0))))

	pcall(function () OfflineStore:syncFromClient() end)
	ghi("XONG")
end

function T:tick()
	if self.DA_CHAY then return end
	self.DEM = self.DEM + 1
	if self.DEM < self.CHO then return end
	if not (Offline and Offline.LAN_VAO_GAME and Offline.LAN_VAO_GAME > 0) then
		return
	end
	self.DA_CHAY = true
	local ok, err = pcall(function () self:chay() end)
	if not ok then
		OfflineLog:err("THU DOC QUYEN: loi — " .. tostring(err))
	end
end

function T:batDau()
	if not coTepCo() then return end
	OfflineLog:info("THU DOC QUYEN: thay tep co " .. self.TEP_CO)
	xoaCo()
	if S_CCSchedule == nil then
		OfflineLog:err("THU DOC QUYEN: khong co S_CCSchedule")
		return
	end
	pcall(function () S_CCSchedule:schedule(self, "tick", 1) end)
end

return OfflineThuDocQuyen
