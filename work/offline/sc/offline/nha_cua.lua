--[[
	offline/nha_cua.lua — NHÀ CỬA trên LỚP OFFLINE (bản gốc chạy trên LDPlayer).

	VÌ SAO CẦN (đo 30/10): ba khoá xây dựng ĐÃ được đăng ký ở
	`offline/handlers/tinh_nang.lua:369-383` (`ClientUpgradeBuilding`,
	`ClientCompleteBuildingUpgrade`, `ClientCompleteBuildingUpgradeWithDiomaon`),
	nhưng cả ba gọi `chayTho("G_BuildingLogic", …)` — mà `g_BuildingLogic`
	**chưa từng được tạo** ở đâu (dòng `g_BuildingLogic = BuildingLogic:new()` ở
	`sc/share/share_building.lua:10` BỊ CHÚ THÍCH), và `G_DataManager:GetBuilding`
	**không có định nghĩa**. Hệ quả: mọi lượt nâng nhà trả "khong co doi tuong"
	⇒ mã lỗi 1, màn Binh Doanh còn nil-index ở bốn chỗ (`CUIBarracks.lua:611/623/722/804`).

	VÌ SAO KHÔNG GỌI LUẬT GỐC: `BuildingLogic:UpgradeBuilding` gọi
	`G_DataManager:GetBuilding` (thiếu) rồi `G_DataManager:GetResource`
	(chỉ có `getResource` chữ thường) — gọi vào là chết tiếp. Vì vậy module này
	**CÀI LẠI** bốn hàm trên `BuildingLogic` bằng luật riêng, đọc cùng bảng
	`KDBGameBuildingConfig` thật của game. Luật ở đây là **[MOI]** (quyết định
	của lớp offline, không phải dữ liệu gốc); ba con số BÁM ĐƯỢC vào bản gốc:
	  · giá nâng cấp = `ResourceForUpgrade` của CẤP HIỆN TẠI (share_building.lua:104);
	  · kinh nghiệm hoàn thành = `ExWhenComplete` của cấp CŨ, cộng TRƯỚC khi +1 cấp
	    (`:126-130`);
	  · giá kim cương = `ceil((leftTime/60/5)^1.1)` (`:209-212`).
	[MOI] (không suy được từ bản gốc, vì cả đường dựng đã chết):
	  · "đang nâng" = cờ `IsUpgrading` (TimeForUpgrade = 0 ở CẢ 126 dòng cấu hình);
	  · mức khởi tạo = cấp 1; chỉ id có trong cấu hình (4..12);
	  · hỏng ⇒ `ErrCode.ILLEGAL_COMMMAND` (6000) — mã duy nhất `share_building.lua` dùng.

	Dữ liệu: bảng MỚI `GameUserBuilding` (thêm vào `OfflineStore.TABLES`), bản ghi
	`{BuildingID, BuildingLevel, UpgradeBeginTime, UpgradeLeftTime, IsUpgrading}`.
	`GetBuilding` trả kèm `BaseInfo` DỰNG TỪ CẤU HÌNH, để màn nào đọc
	`building.BaseInfo.BuildingLevel` vẫn thấy số.
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflineNhaCua = OfflineNhaCua or {}

local BANG = "GameUserBuilding"
local TEN_BANG_TRONG_STORE = "GameUserBuilding"
local ERR = 6000                    -- ErrCode.ILLEGAL_COMMMAND

local function cfgTatCa()
	local c = G_ConfigManager and G_ConfigManager.BuildingConfig
	return (type(c) == "table") and c or nil
end

local function cfgCua(id, lv)
	local b = cfgTatCa() and cfgTatCa()[tostring(id)]
	return b and b[tostring(lv)] or nil
end

--[[ Dựng `G_ConfigManager.BuildingConfig` nếu chưa có. Cấu hình này CHẾT trong
	bản gốc ở ba chỗ (bảng tên bị chú thích `share_configManager.lua:51`,
	tên cache `:125`, hàm cập nhật `:211`), nên cache rỗng và
	`GetBuildingConfigWithLevel` luôn trả nil. Ở đây đọc thẳng tệp qua
	`ClientConfigManager:GetConfigTableWithName` (hàm SỐNG, đọc
	`config/share/KDBGameBuildingConfig.xgg`) rồi xếp lại đúng hình dạng
	[id][cấp] + `MaxLevel` như `updateBuildingConfig` (:1047-1083). ]]
local function damBaoCauHinh()
	if cfgTatCa() ~= nil and next(cfgTatCa()) ~= nil then
		return true
	end
	local CM = G_ConfigManager
	if type(CM) ~= "table" or type(CM.GetConfigTableWithName) ~= "function" then
		return false
	end
	local ok, rows = pcall(function ()
		return CM:GetConfigTableWithName("KDBGameBuildingConfig")
	end)
	if not ok or type(rows) ~= "table" then
		OfflineLog:err("nha cua: khong doc duoc KDBGameBuildingConfig")
		return false
	end
	local byId, maxLv = {}, {}
	for _, r in ipairs(rows) do
		local id, lv = tonumber(r.BuildingID), tonumber(r.BuildingLevel)
		if id ~= nil and lv ~= nil then
			byId[tostring(id)] = byId[tostring(id)] or {}
			byId[tostring(id)][tostring(lv)] = r
			if id ~= nil and (maxLv[id] == nil or lv > maxLv[id]) then
				maxLv[id] = lv
			end
		end
	end
	for id, lvs in pairs(byId) do
		local mx = maxLv[tonumber(id)]
		for _, c in pairs(lvs) do
			c.MaxLevel = mx
		end
	end
	CM.BuildingConfig = byId
	return next(byId) ~= nil
end

local function userData()
	local d = G_DataManager and G_DataManager.userData
	return (type(d) == "table") and d or nil
end

--[[ Bảng nhà của người chơi, dựng lượt đầu bằng cấp 1 cho MỌI nhà có cấu hình. ]]
local function bangNha()
	local d = userData()
	if d == nil then return nil end
	local t = d[BANG]
	if type(t) ~= "table" then
		t = {}
		d[BANG] = t
	end
	local cfg = cfgTatCa() or {}
	for k in pairs(cfg) do
		if type(t[k]) ~= "table" then
			t[k] = {
				BuildingID = tonumber(k), BuildingLevel = 1,
				UpgradeBeginTime = 0, UpgradeLeftTime = 0, IsUpgrading = false,
			}
		end
	end
	return t
end

local function danhDauDirty()
	if OfflineStore ~= nil then OfflineStore.dirty = true end
end

local function phatSuKien(rec)
	pcall(function ()
		G_EventManager:PostDataEvent(rec, EventManagerTableName.GameUserBuilding, "Table_Add")
	end)
end

--[[ `GetBuilding` — phương thức BẢN GỐC THIẾU. Trả bản ghi + `BaseInfo` dựng từ
	cấu hình của CẤP HIỆN TẠI (cùng bộ cột `updateCommonBuldingData`,
	`share_CDataManagerUpdateConfig.lua:96-110`). ]]
local function caiGetBuilding()
	if type(CDataManager) ~= "table" then return false end
	if rawget(CDataManager, "GetBuilding") ~= nil then return true end
	CDataManager.GetBuilding = function (self, nBuildingID)
		local id = tonumber(nBuildingID)
		if id == nil then return nil end
		local t = self.userData and self.userData[BANG]
		local rec = type(t) == "table" and t[tostring(id)] or nil
		if type(rec) ~= "table" then return nil end
		local c = cfgCua(id, rec.BuildingLevel) or {}
		return {
			BaseInfo = {
				BuildingID = id,
				BuildingLevel = rec.BuildingLevel,
				ResourceForUpgrade = c.ResourceForUpgrade,
				ResourceType = c.ResourceType,
				TimeForUpgrade = c.TimeForUpgrade,
				TownHassLevel = c.TownHassLevel,
				ExWhenComplete = c.ExWhenComplete,
				MaxLevel = c.MaxLevel,
				UpgradeLeftTime = rec.UpgradeLeftTime,
			},
		}
	end
	return true
end

--[[ `GetBaseInfo()` của bản gốc trả HAI giá trị `(bResult, baseInfo)`; `pcall`
	chỉ bắt giá trị ĐẦU, nên phải nhận cả hai rồi lấy cái nào là BẢNG. Đã vấp một
	lượt: viết `local ok, b = pcall(...)` thì `b` là `true` ⇒ mọi lượt nâng nhà ra
	6000 dù đủ vàng (bộ thử `_thu_nha_cua.py` bắt được). ]]
local function baseInfo()
	local ok, r, b = pcall(function () return G_UserLogic:GetBaseInfo() end)
	if ok then
		if type(b) == "table" then return b end
		if type(r) == "table" then return r end
	end
	return nil
end

local function giaKimCuong(leftTime)
	if type(leftTime) ~= "number" or leftTime <= 0 then return 0 end
	return math.ceil(math.pow(leftTime / 60 / 5, 1.1))
end

--[[ Cài lại bốn hàm trên `BuildingLogic`. Quy ước trả của ba hàm đầu (giữ đúng
	cái `handlers/tinh_nang.lua` đang đọc): THÀNH CÔNG trả `nil, <id|data>`,
	HỎNG trả `<mã lỗi>` (một số, đứng ở vị trí giá trị đầu). ]]
local function caiLuat()
	local BL = rawget(_G, "BuildingLogic")
	if type(BL) ~= "table" then
		return false, "chua nap share_building"
	end

	BL.UpgradeBuilding = function (_self, nBuildingID)
		local id = tonumber(nBuildingID)
		local t = bangNha()
		local rec = t and id and t[tostring(id)]
		if rec == nil then return ERR end
		local c = cfgCua(id, rec.BuildingLevel)
		if c == nil then return ERR end
		if rec.IsUpgrading then return ERR end
		if tonumber(rec.BuildingLevel) >= tonumber(c.MaxLevel or 0) then return ERR end
		if tonumber(c.ResourceType) ~= 1 then return ERR end   -- 126/126 dòng là 1 (Gold)
		local b = baseInfo()
		local gia = tonumber(c.ResourceForUpgrade) or 0
		if b == nil or (tonumber(b.Gold) or 0) < gia then return ERR end
		local ok = pcall(function () G_UserLogic:CostGold(gia, "BuildingUpgrade") end)
		if not ok then return ERR end
		rec.UpgradeBeginTime = os.time()
		rec.UpgradeLeftTime = tonumber(c.TimeForUpgrade) or 0
		rec.IsUpgrading = true
		danhDauDirty()
		phatSuKien(rec)
		return nil, id
	end

	local function hoanThanh(id, rec)
		local c = cfgCua(id, rec.BuildingLevel) or {}
		local ex = tonumber(c.ExWhenComplete) or 0
		local lvMoi = (tonumber(rec.BuildingLevel) or 1) + 1
		-- Thứ tự bản gốc: cộng EXP TRƯỚC khi +1 cấp (share_building.lua:126-130).
		if ex > 0 then
			pcall(function () G_UserLogic:AddUserEx(ex, "BuildingComplete") end)
		end
		rec.BuildingLevel = lvMoi
		rec.UpgradeBeginTime = 0
		rec.UpgradeLeftTime = 0
		rec.IsUpgrading = false
		danhDauDirty()
		phatSuKien(rec)
		return { BuildingID = id, BuildingLevel = lvMoi }
	end

	BL.CompleteBuildingUpgrade = function (_self, nBuildingID)
		local id = tonumber(nBuildingID)
		local t = bangNha()
		local rec = t and id and t[tostring(id)]
		if rec == nil or not rec.IsUpgrading then return ERR end
		local het = (tonumber(rec.UpgradeBeginTime) or 0) + (tonumber(rec.UpgradeLeftTime) or 0)
		if os.time() < het then return ERR end
		return nil, hoanThanh(id, rec)
	end

	BL.CompleteBuildingUpgradeWithDiamond = function (_self, nBuildingID)
		local id = tonumber(nBuildingID)
		local t = bangNha()
		local rec = t and id and t[tostring(id)]
		if rec == nil or not rec.IsUpgrading then return ERR end
		local conLai = math.max(0,
			(tonumber(rec.UpgradeBeginTime) or 0) + (tonumber(rec.UpgradeLeftTime) or 0) - os.time())
		local gia = giaKimCuong(conLai)
		local b = baseInfo()
		if b == nil or (tonumber(b.Diamond) or 0) < gia then return ERR end
		if gia > 0 then
			local ok = pcall(function () G_UserLogic:CostDiamond(gia) end)
			if not ok then return ERR end
		end
		hoanThanh(id, rec)
		return nil
	end

	-- Huỷ: bản gốc chỉ đặt `UpgradeLeftTime = 0`, KHÔNG hoàn vàng (:163-177).
	BL.CancelBuildingUpgrade = function (_self, nBuildingID)
		local id = tonumber(nBuildingID)
		local t = bangNha()
		local rec = t and id and t[tostring(id)]
		if rec == nil then return ERR end
		rec.UpgradeBeginTime = 0
		rec.UpgradeLeftTime = 0
		rec.IsUpgrading = false
		danhDauDirty()
		phatSuKien(rec)
		return nil, id
	end

	return true
end

--[[ Bốn đường RPC. GHI ĐÈ handler của `tinh_nang.lua` (ghi thẳng vào bảng, không
	dùng `R:on` để khỏi in cảnh báo "dang ky de") vì hai lý do ĐO ĐƯỢC:
	  1. Bản cũ trả `ctx:call(..., "", "", mã, {})` — KHÔNG có tham số `gui`, nên
	     callback toàn cục `OnCompleteBuildingUpgrade(tData)` nhận `tData = nil`
	     rồi `tData.err` nổ; còn `api.lua:65` khai hàm ấy nhận `{err, data}`.
	  2. `ClientCancelBuildingUpgrade` (`api.lua:64`, `cb='OnCancelBuildingUpgrade'`)
	     CHƯA TỪNG được đăng ký ở đâu.
	Hai khoá `cb=''` (Upgrade, WithDiomaon) thì KHÔNG trả lời gì — đúng kiểu im
	lặng của chúng ở bản gốc. ]]
local function caiRouter()
	local R = OfflineRouter
	if type(R) ~= "table" then return false end
	local H = R.handlers

	local function goi(ten, ...)
		if rawget(_G, "g_BuildingLogic") == nil then return false, ERR end
		-- Gói tham số TRƯỚC khi vào closure: `...` không dùng được bên trong.
		local args = { n = select("#", ...), ... }
		local ok, r1, r2 = pcall(function ()
			return g_BuildingLogic[ten](g_BuildingLogic, unpack(args, 1, args.n))
		end)
		if not ok then return false, ERR end
		if type(r1) == "number" then return false, r1 end   -- quy ước: số = mã lỗi
		return true, r2
	end

	H["ClientUpgradeBuilding"] = function (_ctx, nBuildingID)
		local _ok = goi("UpgradeBuilding", nBuildingID)         -- im lặng, không trả lời
	end

	H["ClientCompleteBuildingUpgrade"] = function (ctx, nBuildingID)
		local ok, data = goi("CompleteBuildingUpgrade", nBuildingID)
		if ok then
			ctx:reply({ err = 0, data = data }, "OnCompleteBuildingUpgrade", "")
		else
			ctx:reply({ err = data or ERR }, "OnCompleteBuildingUpgrade", "")
		end
	end

	H["ClientCompleteBuildingUpgradeWithDiomaon"] = function (_ctx, nBuildingID)
		goi("CompleteBuildingUpgradeWithDiamond", nBuildingID)  -- im lặng
	end

	H["ClientCancelBuildingUpgrade"] = function (ctx, nBuildingID)
		local ok, data = goi("CancelBuildingUpgrade", nBuildingID)
		ctx:reply({ err = ok and 0 or (data or ERR), data = ok and data or nil },
			"OnCancelBuildingUpgrade", "")
	end

	return true
end

function OfflineNhaCua:cai()
	-- 1. Bảng dữ liệu mới phải nằm trong danh sách lưu, nếu không `save` bỏ rơi nó.
	local daCo = false
	for _, ten in ipairs(OfflineStore.TABLES) do
		if ten == TEN_BANG_TRONG_STORE then daCo = true; break end
	end
	if not daCo then
		OfflineStore.TABLES[#OfflineStore.TABLES + 1] = TEN_BANG_TRONG_STORE
	end
	if type(OfflineStore.data) == "table" and type(OfflineStore.data[BANG]) ~= "table" then
		OfflineStore.data[BANG] = {}
	end

	-- 2. Cấu hình (bản gốc chết ở ba chỗ — xem đầu tệp).
	local coCauHinh = damBaoCauHinh()
	if not coCauHinh then
		OfflineLog:err("nha cua: KHONG dung duoc BuildingConfig — bang se rong")
	end

	-- 3. Dữ liệu + phương thức còn thiếu.
	bangNha()
	caiGetBuilding()

	-- 4. Luật + thực thể + đường huỷ.
	local okLuat, loiLuat = caiLuat()
	if not okLuat then
		OfflineLog:err("nha cua: khong cai duoc luat — " .. tostring(loiLuat))
		return false
	end
	if rawget(_G, "g_BuildingLogic") == nil then
		local BL = rawget(_G, "BuildingLogic")
		local ok, inst = pcall(function () return BL:new() end)
		if ok and inst ~= nil then
			rawset(_G, "g_BuildingLogic", inst)
		end
	end
	caiRouter()

	OfflineLog:info("nha cua: da cai (cau hinh=" .. tostring(coCauHinh)
		.. ", g_BuildingLogic=" .. tostring(rawget(_G, "g_BuildingLogic") ~= nil) .. ")")
	return rawget(_G, "g_BuildingLogic") ~= nil
end

return OfflineNhaCua
