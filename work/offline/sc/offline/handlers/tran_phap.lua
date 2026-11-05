--[[
	offline/handlers/tran_phap.lua — TRẬN PHÁP / 阵法 (ba khoá của `G_FormationLogic`).

	  · `ClientUpgrade(strName)`                 → `OnUpgrade(strName)`
	  · `ClientActiveRareFormation(strName)`     → `OnActiveRareFormation(strName)`
	  · `ClientSelectAdvancedFormation(strName)` → `OnSelectAdvancedFormation(strName)`

	ĐÂY LÀ TÁI DỰNG, KHÔNG PHẢI CHÉP: `share/FormationLogic.lua` (525 dòng) chỉ có
	hàm ĐỌC/KIỂM (`IsOpen` :25 · `GetUserFormationData` :313 · `GetLevel` :367 ·
	`IsActived` :334 · `GetFormationMaxLevel` :168 · `GetFormationConfig` :138 ·
	`GetFormationUpgradeCostWithName` :264 · `CheckCost` :424 ·
	`GetRareFormationActiveConfig` :303). BA hàm đột biến thì KHÔNG có ở đâu trong
	cây ⇒ phần ghép ba hàm ấy lại là của lớp offline, khai [GHIM] ở dưới.

	Ba khoá CÙNG luật với `bravecross-server/src/handlers/tran_phap.ts` (Mốc 46) —
	đổi máy chủ thì đổi cách gọi, không đổi luật.

	[GHIM-1] THỨ TỰ CỔNG — suy từ chính các helper + bảng mã lỗi `ErrorCode.Formation`
	         (`error.lua:764`): 5101 NoThisFormation · 5102 NoOpen · 5104 IsMaxLevel
	         · 5105 WrongType · 5106 HasActived. Bản gốc không còn để đối chiếu.
	[GHIM-2] TĂNG CẤP ghi `Level`/`SeniorLevel` và GIỮ `IsActived` — suy từ cấu trúc
	         `GetLevel` (đọc đúng hai trường ấy) và từ `GetFormationUpgradeCostWithName`
	         (nLevel ≥ nMaxLevel ⇒ cấp kế là SeniorLevel+1, ngược lại Level+1).
	[GHIM-3] CÁCH TRỪ: `G_ItemDataManager:ReduceItem` + `G_UserLogic:CostDiamond/
	         CostGold`, cùng đường `trang_bi_cuong_hoa.lua` / `mua_luot_ai.lua` dùng.
	[GHIM-4] `SelectAdvancedFormation` chỉ kiểm Type == Advanced + IsOpen — không rõ
	         bản gốc có đòi "đã sở hữu cấp > 0" hay không.

	`gui` của cả ba là `strName` (client `OnUpgrade/OnActiveRareFormation/
	OnSelectAdvancedFormation` nhận đúng một chuỗi rồi tự phát sự kiện UI); trạng thái
	đi bằng dữ liệu — hàm gọi `syncFromClient()` sau khi ghi.
]]

require("offline.log")
require("offline.store")
require("offline.router")

local R = OfflineRouter

local MA = {
	ARG          = 2,     -- ErrorCode.System.ParamError
	NO_FORMATION = 5101,  -- ErrorCode.Formation.NoThisFormation
	NO_OPEN      = 5102,  -- ErrorCode.Formation.NoOpen
	MAX_LEVEL    = 5104,  -- ErrorCode.Formation.IsMaxLevel
	WRONG_TYPE   = 5105,  -- ErrorCode.Formation.WrongType
	HAS_ACTIVED  = 5106,  -- ErrorCode.Formation.HasActived
	NO_ITEM      = 1201,  -- ErrorCode.Item.NotEnoughItem
	NO_RESOURCE  = 1702,  -- ErrorCode.Resource.NoEnoughResource
	NO_CONFIG    = 510,   -- ErrorCode.Common.GetConfigFaild
}

local TEN_FILE = "tran phap"

local function loi(ctx, ma, viSao)
	OfflineLog:info(string.format("%s: tu choi, ma %d (%s)",
		TEN_FILE, tonumber(ma) or 1, tostring(viSao)))
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", tonumber(ma) or 1, {})
end

--[[ Gọi một hàm của LỚP CHA trên thực thể `G_FormationLogic`.

	VÌ SAO QUA PROXY: `G_FormationLogic = ClientFormationLogic:new()` — ba hàm
	`Client*` chỉ là lời gửi request; các helper (`IsOpen`, `CheckCost`…) chỉ nằm
	ở lớp cha `FormationLogic`. Proxy `o[FormationLogic]` là lối đã dùng ở
	`handlers/the_luc.lua` / `handlers/mua_luot_ai.lua`. ]]
local function goiCha(ten, ...)
	local o = _G.G_FormationLogic
	local c = _G.FormationLogic
	if type(o) ~= "table" or type(c) ~= "table" then
		return nil
	end
	local self = o[c] or o
	local fn = self[ten]
	if type(fn) ~= "function" then
		return nil
	end
	local args = { n = select("#", ...), ... }
	local ok, a1, a2, a3 = xpcall(function ()
		return fn(self, unpack(args, 1, args.n))
	end, function (e)
		return tostring(e) .. (debug and debug.traceback and ("\n" .. tostring(debug.traceback())) or "")
	end)
	if not ok then
		OfflineLog:err(TEN_FILE .. ": " .. ten .. " nem loi: " .. tostring(a1))
		return nil
	end
	return a1, a2, a3
end

local function dongBo()
	pcall(function () OfflineStore:syncFromClient() end)
end

------------------------------------------------------------------ trừ tài nguyên
--[[ [GHIM-3] Trừ đúng bảng `cost` mà `GetFormationUpgradeCostWithName` /
	`GetRareFormationActiveConfig` trả về: `ItemList[{ItemID, Count}]`, `CostDiamond`,
	`CostGold`. Không tự tính giá — giá là của cấu hình.

	Trả `true` nếu trừ xong; `false, mã` nếu một bước hỏng (đã trừ một phần — khai rõ:
	bản gốc cũng trừ tuần tự, không có giao dịch). ]]
local function truCost(cost, nhan)
	if type(cost) ~= "table" then return false, MA.NO_CONFIG end
	for _, it in ipairs(cost.ItemList or {}) do
		local n = tonumber(it.Count) or 0
		if n > 0 then
			local ok, r = pcall(function ()
				return G_ItemDataManager:ReduceItem(it.ItemID, n, nhan)
			end)
			if not ok or r ~= true then return false, MA.NO_ITEM end
		end
	end
	if (tonumber(cost.CostDiamond) or 0) > 0 then
		local ok, r = pcall(function ()
			return G_UserLogic:CostDiamond(cost.CostDiamond, nhan)
		end)
		if not ok or r ~= true then return false, MA.NO_RESOURCE end
	end
	if (tonumber(cost.CostGold) or 0) > 0 then
		local ok, r = pcall(function ()
			return G_UserLogic:CostGold(cost.CostGold, nhan)
		end)
		if not ok or r ~= true then return false, MA.NO_RESOURCE end
	end
	return true
end

------------------------------------------------------------------ nâng cấp
--[[ Cổng [GHIM-1]: tồn tại config → đã mở → có cấp kế (nếu không = IsMaxLevel) →
	đủ tài nguyên → trừ → +1 cấp ([GHIM-2]) → lưu → trả `OnUpgrade(strName)`. ]]
R:on("G_FormationLogic.ClientUpgrade", function (ctx, strName)
	if type(strName) ~= "string" or strName == "" then
		return loi(ctx, MA.ARG, "Upgrade(strName)")
	end

	local cfg = goiCha("GetFormationConfig", strName)
	if type(cfg) ~= "table" then
		return loi(ctx, MA.NO_FORMATION, "Upgrade(config " .. strName .. ")")
	end
	if goiCha("IsOpen", cfg.Type) ~= true then
		return loi(ctx, MA.NO_OPEN, "Upgrade(IsOpen " .. tostring(cfg.Type) .. ")")
	end

	local _, uf = goiCha("GetUserFormationData")
	if type(uf) ~= "table" then
		return loi(ctx, MA.NO_FORMATION, "Upgrade(user data)")
	end
	uf.Formations = uf.Formations or {}

	local _, nLevel, nSenior = goiCha("GetLevel", strName, uf)
	nLevel = tonumber(nLevel) or 0
	nSenior = tonumber(nSenior) or -1

	local cost = goiCha("GetFormationUpgradeCostWithName", strName, nLevel, nSenior)
	if type(cost) ~= "table" then
		return loi(ctx, MA.MAX_LEVEL, "Upgrade(het cap)")
	end

	local okCost, maCost = goiCha("CheckCost", cost)
	if okCost ~= true then
		return loi(ctx, tonumber(maCost) or MA.NO_CONFIG, "Upgrade(CheckCost)")
	end

	local okTru, maTru = truCost(cost, "FormationUpgrade")
	if not okTru then
		return loi(ctx, maTru, "Upgrade(tru tai nguyen)")
	end

	-- [GHIM-2] Cấp kế: hết Level thì lên SeniorLevel; giữ nguyên `IsActived`.
	local nMaxLevel = tonumber((goiCha("GetFormationMaxLevel", strName))) or 0
	local cu = uf.Formations[strName]
	local moi = type(cu) == "table" and cu or {}
	if nLevel >= nMaxLevel then
		moi.Level = nLevel
		moi.SeniorLevel = nSenior + 1
	else
		moi.Level = nLevel + 1
		moi.SeniorLevel = nSenior
	end
	uf.Formations[strName] = moi

	dongBo()
	OfflineLog:info(string.format("%s: nang %s -> Level=%d Senior=%d",
		TEN_FILE, strName, moi.Level, moi.SeniorLevel))
	ctx:call("G_FormationLogic", "OnUpgrade", strName)
end)

------------------------------------------------------------------ kích hoạt Rare
R:on("G_FormationLogic.ClientActiveRareFormation", function (ctx, strName)
	if type(strName) ~= "string" or strName == "" then
		return loi(ctx, MA.ARG, "ActiveRare(strName)")
	end

	local cfg = goiCha("GetFormationConfig", strName)
	if type(cfg) ~= "table" then
		return loi(ctx, MA.NO_FORMATION, "ActiveRare(config " .. strName .. ")")
	end
	if cfg.Type ~= "Rare" then
		return loi(ctx, MA.WRONG_TYPE, "ActiveRare(Type " .. tostring(cfg.Type) .. ")")
	end

	local _, uf = goiCha("GetUserFormationData")
	if type(uf) ~= "table" then
		return loi(ctx, MA.NO_FORMATION, "ActiveRare(user data)")
	end
	uf.Formations = uf.Formations or {}

	local st = uf.Formations[strName]
	if type(st) == "table" and st.IsActived == true then
		return loi(ctx, MA.HAS_ACTIVED, "ActiveRare(da kich hoat)")
	end

	if goiCha("IsOpen", "Rare") ~= true then
		return loi(ctx, MA.NO_OPEN, "ActiveRare(IsOpen Rare)")
	end

	local active = goiCha("GetRareFormationActiveConfig", strName)
	if type(active) ~= "table" then
		return loi(ctx, MA.NO_FORMATION, "ActiveRare(cost cau hinh)")
	end

	local okCost, maCost = goiCha("CheckCost", active)
	if okCost ~= true then
		return loi(ctx, tonumber(maCost) or MA.NO_CONFIG, "ActiveRare(CheckCost)")
	end

	local okTru, maTru = truCost(active, "FormationActiveRare")
	if not okTru then
		return loi(ctx, maTru, "ActiveRare(tru tai nguyen)")
	end

	local moi = type(st) == "table" and st or {}
	moi.IsActived = true
	uf.Formations[strName] = moi

	dongBo()
	OfflineLog:info(TEN_FILE .. ": kich hoat tran phap hiem " .. strName)
	ctx:call("G_FormationLogic", "OnActiveRareFormation", strName)
end)

------------------------------------------------------------------ chọn Advanced
R:on("G_FormationLogic.ClientSelectAdvancedFormation", function (ctx, strName)
	if type(strName) ~= "string" or strName == "" then
		return loi(ctx, MA.ARG, "SelectAdvanced(strName)")
	end

	local cfg = goiCha("GetFormationConfig", strName)
	if type(cfg) ~= "table" then
		return loi(ctx, MA.NO_FORMATION, "SelectAdvanced(config " .. strName .. ")")
	end
	-- [GHIM-4] Chỉ nhận Type == Advanced (Senior là BIẾN THỂ của Advanced, không
	-- phải lựa chọn riêng trong UI `CUIZF`).
	if cfg.Type ~= "Advanced" then
		return loi(ctx, MA.WRONG_TYPE, "SelectAdvanced(Type " .. tostring(cfg.Type) .. ")")
	end
	if goiCha("IsOpen", "Advanced") ~= true then
		return loi(ctx, MA.NO_OPEN, "SelectAdvanced(IsOpen Advanced)")
	end

	local _, uf = goiCha("GetUserFormationData")
	if type(uf) ~= "table" then
		return loi(ctx, MA.NO_FORMATION, "SelectAdvanced(user data)")
	end
	uf.CurrentAdvancedFormation = strName

	dongBo()
	OfflineLog:info(TEN_FILE .. ": chon tran phap tien giai " .. strName)
	ctx:call("G_FormationLogic", "OnSelectAdvancedFormation", strName)
end)

OfflineLog:info("tran phap: da noi 3 khoa (Upgrade / ActiveRareFormation / SelectAdvancedFormation)")

return true
