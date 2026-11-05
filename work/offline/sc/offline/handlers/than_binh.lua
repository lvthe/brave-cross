--[[
	offline/handlers/than_binh.lua — THẦN BINH (神兵 / Magic Weapon), 4 KHOÁ THẬT.

	`G_MagicWeaponProtocol`: `ClientStarUp` / `ClientStarDown` / `ClientStrengthen` /
	`ClientBreakThrough`. Phản hồi đi qua **`g_SBProtocol`** (chữ thường —
	`SBProtocol.lua:11`), KHÔNG phải `G_MagicWeaponProtocol`.

	DỮ LIỆU THẬT (đọc từ chính client/share — không có tệp share nào ĐỘT BIẾN, nên
	phần ghi dưới đây dựng lại từ cấu hình + luật ĐỌC):
	  · bảng người chơi `GameMagicWeapon` (đã có trong `OfflineStore.TABLES`):
	        `.STAR[heroId][part].star`
	        `.STRENGTHEN[heroId][part] = {level, exp, breakThroughLevel, needToBreakThrough}`
	    đúng hình `MagicWeaponLogic:GetFieldData` (`share/share_magicWeapon.lua:142`).
	  · LÊN SAO: `ConfigManager:GetMagicWeaponRefineConfig(hero, part, star+1)` (điều
	    phối 3 bảng: `GameMagicWeaponRefineConfig` cho phần 7/8, `NormalEquipRefine`
	    cho 1..5) → `CostResource` (JSON), `CostGold`, `OpenNeedLevel`.
	  · CƯỜNG HOÁ: exp mỗi món = `GameMagicWeaponItemExpConfig[itemID].Exp` (chính
	    `SBDataManager:GetMaterialAddExp` dùng), cộng dồn TUYỆT ĐỐI; cấp suy bằng hàm
	    GỐC `G_MagicWeaponLogic:MapExpToLevel(part, exp)` (`:253`).
	  · TRẦN CƯỜNG HOÁ = `min(cấp tướng, breakThroughLevel)` — đúng
	    `SBDataManager:GetMaxIntensifyLevel` (`:337`).
	  · ĐỘT PHÁ: `GetMagicWeaponStrengthConfigEx(cấp, part).BreakResource` (đã
	    `cjson.decode` trong `updateGameMagicWeaponStrengthConfig:3534`) — tiêu món
	    đầu; `breakThroughLevel += 5` (`MagicWeaponDef.BreakThroughLevel`).

	MÃ GỐC (`share/error.lua:747`): 5001 DataException · 5002 SystemIsClosed ·
	5003 OverLevelLimit · 5004 ResourceIsNotEnough · 5005 OverExpLimit.
	Hàm nhận KHÔNG có tham số mã lỗi ⇒ báo lỗi bằng `OnReciveResponse`.

	[GHIM] — chỗ luật máy chủ chết:
	1. `ClientStarDown` ("giáng sao"): KHÔNG hoàn nguyên liệu (không có bảng hoàn).
	2. Đột phá: mỗi lần +5 cấp trần; cấp/exp giữ nguyên; `needToBreakThrough=false`.
	3. Khi exp vượt trần, CHẶN exp ở `TotalExp(trần)` để thanh kinh nghiệm không tràn.
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflineThanBinh = OfflineThanBinh or {}

local R = OfflineRouter
local TEN_FILE = "than binh"

------------------------------------------------------------------- tiện ích

local function ma(ten, macDinh)
	local ok, v = pcall(function ()
		local E = _G.ErrorCode
		return E and E.MagicWeapon and E.MagicWeapon[ten]
	end)
	return (ok and tonumber(v)) or macDinh
end

local function goi(ctx, hamNhan, ...)
	local a = { n = select("#", ...), ... }
	local ok, e = pcall(function ()
		return ctx:call("g_SBProtocol", hamNhan, unpack(a, 1, a.n))
	end)
	if not ok then
		OfflineLog:err(string.format("%s: khong goi duoc g_SBProtocol.%s -> %s",
			TEN_FILE, tostring(hamNhan), tostring(e)))
	end
end

local function baoLoi(ctx, nMa, lyDo)
	OfflineLog:info(string.format("%s: tu choi -> ma %d (%s)", TEN_FILE, nMa, lyDo or ""))
	pcall(function ()
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", nMa, {})
	end)
end

local function dongBo()
	pcall(function () OfflineStore:syncFromClient() end)
end

local function docJSON(v)
	if type(v) == "table" then return v end
	if type(v) ~= "string" or v == "" then return nil end
	if type(_G.cjson) ~= "table" then return nil end
	local ok, t = pcall(function () return cjson.decode(v) end)
	return (ok and type(t) == "table") and t or nil
end

local function duLieu()
	local ok, maLoi, d = pcall(function ()
		return G_DataManager:GetUserDataWithName("GameMagicWeapon")
	end)
	if not ok or maLoi ~= 0 then return nil end
	if type(d) ~= "table" then
		d = {}
		pcall(function () G_DataManager:SetUserDataWithName("GameMagicWeapon", d) end)
	end
	if type(d.STAR) ~= "table" then d.STAR = {} end
	if type(d.STRENGTHEN) ~= "table" then d.STRENGTHEN = {} end
	return d
end

local function muc(d, khoa, hero, part)
	local k = tostring(hero)
	local p = tostring(part)
	d[khoa][k] = d[khoa][k] or {}
	d[khoa][k][p] = d[khoa][k][p] or {}
	return d[khoa][k][p]
end

local function demMon(id)
	local ok, b, n = pcall(function () return G_ItemLogic:GetItemCount(id) end)
	if ok and b ~= false and tonumber(n) then return tonumber(n) end
	return 0
end

local function truMon(id, so)
	local ok, r = pcall(function ()
		return G_ItemDataManager:ReduceItem(id, so, "MagicWeapon")
	end)
	return ok and r == true
end

-- Kiểm + trừ một danh sách { {PropID, PrizeResCount}, … }. Trả true nếu đủ và đã trừ.
local function tieuDanhSach(ds)
	if type(ds) ~= "table" then return true end
	local can = {}
	for _, mon in ipairs(ds) do
		if type(mon) == "table" then
			local id = tonumber(mon.PropID) or 0
			local so = tonumber(mon.PrizeResCount) or 0
			if id > 0 and so > 0 then
				can[#can + 1] = { id = id, so = so }
				if demMon(id) < so then return false end
			end
		end
	end
	for _, m in ipairs(can) do
		if not truMon(m.id, m.so) then return false end
	end
	return true
end

local function capCuaTuong(hero)
	local ok, b, tHero = pcall(function () return G_HeroLogic:GetHeroWithID(hero) end)
	if ok and b ~= false and type(tHero) == "table" then
		return tonumber(tHero.HeroLevel) or 1
	end
	return 1
end

local function tongExpCuaCap(part, cap)
	local cfg = nil
	pcall(function () cfg = G_ConfigManager:GetStrengthConfig(part) end)
	local dong = type(cfg) == "table" and cfg[tonumber(cap) or 0] or nil
	return tonumber(dong and dong.TotalExp) or 0
end

local function mapCap(part, exp)
	local ok, cap = pcall(function () return G_MagicWeaponLogic:MapExpToLevel(part, exp) end)
	if ok and tonumber(cap) then return tonumber(cap) end
	return 0
end

------------------------------------------------------------------- 1. LÊN SAO
R:on("G_MagicWeaponProtocol.ClientStarUp", function (ctx, tData)
	local d = duLieu()
	if d == nil or type(tData) ~= "table" then
		return baoLoi(ctx, ma("DataException", 5001), "du lieu sai")
	end
	local hero = tonumber(tData.heroId) or 0
	local part = tonumber(tData.equipmentType) or 0
	if hero <= 0 or part <= 0 then
		return baoLoi(ctx, ma("DataException", 5001), "hero/part sai")
	end

	local star = 0
	pcall(function () star = tonumber(G_MagicWeaponLogic:GetEquipmentStarLevel(hero, part)) or 0 end)
	local cfg = nil
	pcall(function () cfg = G_ConfigManager:GetMagicWeaponRefineConfig(hero, part, star + 1) end)
	if type(cfg) ~= "table" then
		return baoLoi(ctx, ma("OverLevelLimit", 5003), "da sao toi da")
	end

	local canCap = tonumber(cfg.OpenNeedLevel) or 1
	local capTuong = capCuaTuong(hero)
	if capTuong < canCap then
		return baoLoi(ctx, ma("OverLevelLimit", 5003), string.format("tuong cap %d < %d", capTuong, canCap))
	end

	local gia = tonumber(cfg.CostGold) or 0
	if gia > 0 then
		local okTru, daTru = pcall(function () return G_UserLogic:CostGold(gia, "SBStarUp") end)
		if not okTru or daTru ~= true then
			return baoLoi(ctx, ma("ResourceIsNotEnough", 5004), "thieu vang")
		end
	end
	if not tieuDanhSach(docJSON(cfg.CostResource)) then
		return baoLoi(ctx, ma("ResourceIsNotEnough", 5004), "thieu nguyen lieu")
	end

	local e = muc(d, "STAR", hero, part)
	e.star = star + 1
	dongBo()
	OfflineLog:info(string.format("%s: tuong %d o %d len sao %d", TEN_FILE, hero, part, e.star))
	goi(ctx, "OnStarUp", {})
end)

------------------------------------------------------------------- 2. GIÁNG SAO
--[[ [GHIM] KHÔNG hoàn nguyên liệu — bản gốc không ship bảng hoàn. ]]
R:on("G_MagicWeaponProtocol.ClientStarDown", function (ctx, tData)
	local d = duLieu()
	if d == nil or type(tData) ~= "table" then
		return baoLoi(ctx, ma("DataException", 5001), "du lieu sai")
	end
	local hero = tonumber(tData.heroId) or 0
	local part = tonumber(tData.equipmentType) or 0
	local e = muc(d, "STAR", hero, part)
	local star = tonumber(e.star) or 0
	if star <= 0 then
		return baoLoi(ctx, ma("DataException", 5001), "dang o sao 0")
	end
	e.star = star - 1
	dongBo()
	OfflineLog:info(string.format("%s: tuong %d o %d giang sao %d -> %d", TEN_FILE,
		hero, part, star, e.star))
	goi(ctx, "OnStarDown", { star = e.star })
end)

------------------------------------------------------------------- 3. CƯỜNG HOÁ
--[[ `costItem` = `{{id, count}, …}` do client chọn; exp = Σ `ItemExpConfig[id].Exp × count`.
	Cấp suy bằng hàm GỐC; trần = min(cấp tướng, breakThroughLevel). ]]
R:on("G_MagicWeaponProtocol.ClientStrengthen", function (ctx, tData)
	local d = duLieu()
	if d == nil or type(tData) ~= "table" then
		return baoLoi(ctx, ma("DataException", 5001), "du lieu sai")
	end
	local hero = tonumber(tData.heroId) or 0
	local part = tonumber(tData.equipmentType) or 0
	if part ~= 7 and part ~= 8 then
		return baoLoi(ctx, ma("DataException", 5001), "chi cuong hoa duoc than binh (o 7/8)")
	end

	local cfgExp = nil
	pcall(function ()
		cfgExp = G_ConfigManager:GetCommonConfigWithName("GameMagicWeaponItemExpConfig")
	end)
	local ds = type(tData.costItem) == "table" and tData.costItem or {}
	local can = {}
	local tongExp = 0
	for _, mon in ipairs(ds) do
		local id = tonumber(type(mon) == "table" and (mon.id or mon.ID) or mon)
		local so = tonumber(type(mon) == "table" and (mon.count or mon.Count) or 1) or 0
		if id == nil or so <= 0 then
			return baoLoi(ctx, ma("DataException", 5001), "mon nguyen lieu sai")
		end
		if demMon(id) < so then
			return baoLoi(ctx, ma("ResourceIsNotEnough", 5004), "thieu mon " .. tostring(id))
		end
		local mot = nil
		if type(cfgExp) == "table" then
			local dong = cfgExp[tostring(id)] or cfgExp[id]
			mot = tonumber(dong and dong.Exp) or 0
		end
		tongExp = tongExp + mot * so
		can[#can + 1] = { id = id, so = so }
	end
	if #can == 0 or tongExp <= 0 then
		return baoLoi(ctx, ma("DataException", 5001), "khong co nguyen lieu hop le")
	end
	for _, m in ipairs(can) do
		if not truMon(m.id, m.so) then
			return baoLoi(ctx, ma("ResourceIsNotEnough", 5004), "tru mon that bai")
		end
	end

	local e = muc(d, "STRENGTHEN", hero, part)
	local expCu = tonumber(e.exp) or 0
	local breakCap = tonumber(e.breakThroughLevel) or 5
	local tran = math.min(capCuaTuong(hero), breakCap)
	local expMoi = expCu + tongExp
	local capMoi = mapCap(part, expMoi)
	if capMoi > tran then capMoi = tran end
	if capMoi >= tran and tran > 0 then
		local tranExp = tongExpCuaCap(part, tran)
		if tranExp > 0 and expMoi > tranExp then expMoi = tranExp end
	end
	e.exp = expMoi
	e.level = capMoi
	e.breakThroughLevel = breakCap
	-- Cần đột phá khi đã chạm trần và trần còn thấp hơn cấp tướng.
	e.needToBreakThrough = (capMoi >= breakCap) and (breakCap < capCuaTuong(hero))
	dongBo()
	OfflineLog:info(string.format("%s: tuong %d o %d +%d exp -> cap %d (tran %d%s)",
		TEN_FILE, hero, part, tongExp, capMoi, tran, e.needToBreakThrough and ", CAN DOT PHA" or ""))
	goi(ctx, "OnStrengthen", {})
end)

------------------------------------------------------------------- 4. ĐỘT PHÁ
R:on("G_MagicWeaponProtocol.ClientBreakThrough", function (ctx, tData)
	local d = duLieu()
	if d == nil or type(tData) ~= "table" then
		return baoLoi(ctx, ma("DataException", 5001), "du lieu sai")
	end
	local hero = tonumber(tData.heroId) or 0
	local part = tonumber(tData.equipmentType) or 0
	local e = muc(d, "STRENGTHEN", hero, part)
	local cap = tonumber(e.level) or mapCap(part, tonumber(e.exp) or 0)
	local breakCap = tonumber(e.breakThroughLevel) or 5
	if cap < breakCap then
		return baoLoi(ctx, ma("OverExpLimit", 5005), "chua cham tran cuong hoa")
	end

	local cfg = nil
	pcall(function () cfg = G_ConfigManager:GetMagicWeaponStrengthConfigEx(cap, part) end)
	local ds = docJSON(cfg and cfg.BreakResource)
	local mon = type(ds) == "table" and (ds[1] or ds) or nil
	if type(mon) ~= "table" or not tieuDanhSach({ mon }) then
		return baoLoi(ctx, ma("ResourceIsNotEnough", 5004), "thieu nguyen lieu dot pha")
	end

	e.breakThroughLevel = breakCap + 5
	e.needToBreakThrough = false
	e.level = cap
	dongBo()
	OfflineLog:info(string.format("%s: tuong %d o %d dot pha tai cap %d -> tran %d",
		TEN_FILE, hero, part, cap, e.breakThroughLevel))
	goi(ctx, "OnBreakThrough", {})
end)

OfflineLog:info("than binh: da noi 4 khoa (len sao/giang sao/cuong hoa/dot pha)")

return true
