--[[
	offline/handlers/tinh_nang.lua — nối các lệnh CHỈ-THIẾU-PHẢN-HỒI vào LUẬT
	GỐC đã có trong `sc/share/`.

	Cách tìm ra danh sách này (28/10): đối chiếu 445 lệnh còn thiếu với các hàm
	`function <X>Logic:<Tên>` trong `sc/share/**/*.lua` — trùng tên sau khi bỏ
	tiền tố `Client` thì chỉ cần GỌI, không phải viết lại luật (đúng cách
	`handlers/cavern.lua` đang làm). Có **32** lệnh như vậy.

	HAI KIỂU, đừng lẫn:
	  * Kiểu A — hàm nhận phía client chỉ VẼ LẠI: máy chủ phải CHẠY LUẬT rồi mới
	    trả lời (thiết bị, tướng, đấu trường, thành tựu, thiên mệnh).
	  * Kiểu B — hàm nhận phía client TỰ CHẠY LUẬT (`ClientPotionLogic:
	    OnUpgradePotion` gọi `self:UpgradePotion`, `OnBuyPotion` gọi
	    `self:BuyPotion`…): máy chủ chỉ trả OK, KHÔNG gọi luật — gọi cả hai thì
	    thuốc bị trừ hai lần. Bốn lệnh thuốc ở cuối tệp là kiểu B.

	Đo trên trình giả lập mỗi lần thêm: xem GHI-CHU-TRACE-2026-10-26.md §25.
]]

require("offline.log")
require("offline.store")
require("offline.router")

local R = OfflineRouter

local function dongBo()
	pcall(function () OfflineStore:syncFromClient() end)
end

--[[ Trả mã lỗi qua đường chung + GHI LOG. Không ghi thì "luật gốc từ chối vì
	thiếu nguyên liệu" trông y hệt "handler chạy đúng mà không có tác dụng". ]]
local function loi(ctx, ma, ten)
	ma = tonumber(ma) or 1
	OfflineLog:info(string.format("tinh nang %s: luat goc tu choi, ma %d", tostring(ten), ma))
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", ma, {})
end

--[[ Chống gọi lặp: ĐO 28/10 có lệnh bị gọi 14 lần trong MỘT giây (luật gốc từ
	chối ⇒ client phản ứng ⇒ gọi lại). Lần thứ 6 trong 1 giây thì KHÔNG gọi luật
	nữa, ghi một lần kèm traceback để biết ai gọi — tránh vừa spam log vừa đốt
	CPU. `self` ở đây là bảng đếm của tệp này. ]]
local demGoi = {}

local function biLap(khoa)
	local now = os.time()
	local d = demGoi[khoa]
	if d == nil or d.giay ~= now then
		demGoi[khoa] = { giay = now, dem = 1 }
		return false
	end
	d.dem = d.dem + 1
	if d.dem == 6 then
		OfflineLog:warn(string.format("%s bi goi lap 6 lan/giay — chan lai. Ai goi:\n%s",
			khoa, tostring(debug and debug.traceback and debug.traceback("", 2))))
		return true
	end
	return d.dem > 6
end

--[[ Gọi luật GỐC (lớp cha trong `sc/share/`), KHÔNG gọi bản client.

	`G_HeroLogic` là thể hiện của `ClientHeroLogic = class(HeroLogic)`; lớp client
	ĐÈ nhiều tên bằng hàm GỬI REQUEST (`ClientHeroLogic.lua:65` tăng hệ số, `:97`
	tăng phẩm, `:166` đột phá…). Gọi `G_HeroLogic:UpgradeHeroQualityPromotion()`
	thì trúng bản client ⇒ nó lại `CallServer` ⇒ vào lại handler ⇒ đệ quy vô hạn
	(ĐO 28/10: 14 lần/giây, traceback `ClientHeroLogic.lua:99 → net.lua CallServer
	→ handler`).

	Lối đúng là lấy bảng proxy của LỚP CHA mà `class()` gắn lên mỗi thể hiện:
	`o[HeroLogic][ten]` (cùng lối `handlers/vat_pham.lua` dùng cho `ItemLogic`).
	Tên lớp cha suy từ tên biến: `G_HeroLogic` → `HeroLogic`.
]]
local function lopCha(obj)
	local ten = obj:match("^G_(.+)$")
	if not ten then return nil end
	local c = _G[ten]
	return (type(c) == "table") and c or nil
end

local function chay(obj, ten, ...)
	local o = _G[obj]
	if type(o) ~= "table" then
		OfflineLog:err(string.format("%s: khong co doi tuong", tostring(obj)))
		return false, 1
	end

	local c = lopCha(obj)
	local proxy = c and o[c] or nil
	local self = proxy or o
	local fn = self[ten]
	if type(fn) ~= "function" then
		OfflineLog:err(string.format("%s: khong co luat %s", obj, ten))
		return false, 1
	end
	if biLap(obj .. ":" .. ten) then
		return false, 1
	end

	-- Lua 5.1: `...` không dùng được trong hàm lồng, phải đóng gói trước.
	local args = { n = select("#", ...), ... }
	local ok, bRet, ma = xpcall(function ()
		return fn(self, unpack(args, 1, args.n))
	end, function (e)
		return tostring(e) .. (debug and debug.traceback and ("\n" .. tostring(debug.traceback())) or "")
	end)
	if not ok then
		OfflineLog:warn(string.format("%s:%s loi: %s", obj, ten, tostring(bRet)))
		return false, 1
	end
	return bRet == true, ma
end

----------------------------------------------------------- THIÊN MỆNH (天命)

R:on("G_DestinyLogic.ClientActiveProgress", function(ctx)
	local ok, ma = chay("G_DestinyLogic", "ActiveProgress")
	if ok then
		dongBo()
		ctx:call("G_DestinyLogic", "OnActiveProgress")
	else
		loi(ctx, ma, "G_DestinyLogic.ClientActiveProgress")
	end
end)

R:on("G_DestinyLogic.ClientActiveProgressWithCount", function(ctx, nCount)
	local ok, ma = chay("G_DestinyLogic", "ActiveProgressWithCount", nCount)
	if ok then
		dongBo()
		ctx:call("G_DestinyLogic", "OnActiveProgressWithCount", nil)
	else
		loi(ctx, ma, "G_DestinyLogic.ClientActiveProgressWithCount")
	end
end)

------------------------------------------------------------ TRANG BỊ (装备)

R:on("G_EquipmentLogic.ClientIntensifyEquipment", function(ctx, nHeroID, nPartID)
	local ok, ma = chay("G_EquipmentLogic", "IntensifyEquipment", nHeroID, nPartID)
	if ok then
		dongBo()
		ctx:call("G_EquipmentLogic", "OnServerIntensifyEquipment", nHeroID, nPartID)
	else
		loi(ctx, ma, "G_EquipmentLogic.ClientIntensifyEquipment")
	end
end)

R:on("G_EquipmentLogic.ClientAutoIntensifyEquipment", function(ctx, nHeroID, nPartID)
	local ok, ma = chay("G_EquipmentLogic", "AutoIntensifyEquipment", nHeroID, nPartID)
	if ok then
		dongBo()
		ctx:call("G_EquipmentLogic", "OnServerAutoIntensifyEquipment", nHeroID, nPartID)
	else
		loi(ctx, ma, "G_EquipmentLogic.ClientAutoIntensifyEquipment")
	end
end)

R:on("G_EquipmentLogic.ClientPromoteQualityEquipment", function(ctx, nHeroID, nPartID)
	local ok, ma = chay("G_EquipmentLogic", "PromoteQualityEquipment", nHeroID, nPartID)
	if ok then
		dongBo()
		ctx:call("G_EquipmentLogic", "OnServerPromoteQualityEquipment", nHeroID, nPartID)
	else
		loi(ctx, ma, "G_EquipmentLogic.ClientPromoteQualityEquipment")
	end
end)

R:on("G_EquipmentLogic.ClientRecastEquipment", function(ctx, nHeroID, nPartID, nResourceType)
	local ok, ma = chay("G_EquipmentLogic", "RecastEquipment", nHeroID, nPartID, nResourceType)
	if ok then
		dongBo()
		ctx:call("G_EquipmentLogic", "OnServerRecastEquipment", nHeroID, nPartID, nResourceType)
	else
		loi(ctx, ma, "G_EquipmentLogic.ClientRecastEquipment")
	end
end)

---------------------------------------------------------------- TƯỚNG (英雄)

R:on("G_HeroLogic.ClientUpgradeHeroGrowthFactor", function(ctx, nHeroID)
	local ok, ma = chay("G_HeroLogic", "UpgradeHeroGrowthFactor", nHeroID)
	if ok then
		dongBo()
		ctx:call("G_HeroLogic", "OnServerUpgradeHeroGrowthFactor", nHeroID)
	else
		loi(ctx, ma, "G_HeroLogic.ClientUpgradeHeroGrowthFactor")
	end
end)

R:on("G_HeroLogic.ClientUpgradeHeroQualityPromotion", function(ctx, nHeroID)
	local ok, ma = chay("G_HeroLogic", "UpgradeHeroQualityPromotion", nHeroID)
	if ok then
		dongBo()
		ctx:call("G_HeroLogic", "OnServerUpgradeHeroQualityPromotion", nHeroID)
	else
		loi(ctx, ma, "G_HeroLogic.ClientUpgradeHeroQualityPromotion")
	end
end)

R:on("G_HeroLogic.ClientUseHeroExperiencePill", function(ctx, nHeroID, nItemID, nCount)
	local ok, ma = chay("G_HeroLogic", "UseHeroExperiencePill", nHeroID, nItemID, nCount)
	if ok then
		dongBo()
		ctx:call("G_HeroLogic", "OnServerUseHeroExperiencePill", nHeroID, nItemID, nCount)
	else
		loi(ctx, ma, "G_HeroLogic.ClientUseHeroExperiencePill")
	end
end)

R:on("G_HeroLogic.ClientRecruitHero", function(ctx, nHeroID)
	local ok, ma = chay("G_HeroLogic", "RecruitHero", nHeroID)
	if ok then
		dongBo()
		ctx:call("G_HeroLogic", "OnServerRecruitHero", nHeroID)
	else
		loi(ctx, ma, "G_HeroLogic.ClientRecruitHero")
	end
end)

R:on("G_HeroLogic.ClientBreakthroughHeroMaxLevel", function(ctx, nHeroID)
	local ok, ma = chay("G_HeroLogic", "BreakthroughHeroMaxLevel", nHeroID)
	if ok then
		dongBo()
		ctx:call("G_HeroLogic", "OnServerBreakthroughHeroMaxLevel", nHeroID)
	else
		loi(ctx, ma, "G_HeroLogic.ClientBreakthroughHeroMaxLevel")
	end
end)

R:on("G_HeroLogic.ClientGetTopFightCapacity", function(ctx, nCount)
	local ok, giaTri = chay("G_HeroLogic", "GetTopFightCapacity", nCount)
	if ok then
		ctx:call("G_HeroLogic", "OnGetTopFightCapacity", giaTri)
	else
		loi(ctx, giaTri)
	end
end)

-- Trang phục/da của tướng: luật gốc lo việc mặc; client vẽ lại từ dữ liệu.
R:on("G_HeroLogic.ClientEquipHreroSkin", function(ctx, nHeroID, strPart, strSkin)
	local ok, ma = chay("G_HeroLogic", "EquipHreroSkin", nHeroID, strPart, strSkin)
	dongBo()
	if ok then
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", 0, {})
	else
		loi(ctx, ma, "G_HeroLogic.ClientEquipHreroSkin")
	end
end)

R:on("G_HeroLogic.ClientTakeOffHreroSkin", function(ctx, nHeroID, strPart, strSkin)
	local ok, ma = chay("G_HeroLogic", "TakeOffHreroSkin", nHeroID, strPart, strSkin)
	dongBo()
	if ok then
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", 0, {})
	else
		loi(ctx, ma, "G_HeroLogic.ClientTakeOffHreroSkin")
	end
end)

---------------------------------------------------------------- ĐẤU TRƯỜNG

R:on("G_ArenaLogic.ClientBuyArenaGoods", function(ctx, nGoodsIndex)
	local ok, ma = chay("G_ArenaLogic", "BuyArenaGoods", nGoodsIndex)
	if ok then
		dongBo()
		ctx:call("G_ArenaLogic", "OnBuyArenaGoods", nGoodsIndex)
	else
		loi(ctx, ma, "G_ArenaLogic.ClientBuyArenaGoods")
	end
end)

R:on("G_ArenaLogic.ClientRefreshFightTime", function(ctx)
	local ok, ma = chay("G_ArenaLogic", "RefreshFightTime")
	if ok then
		dongBo()
		ctx:call("G_ArenaLogic", "OnRefreshFightTime", 0)
	else
		loi(ctx, ma, "G_ArenaLogic.ClientRefreshFightTime")
	end
end)

R:on("G_ArenaLogic.RefreshFightTime", function(ctx)
	local ok, ma = chay("G_ArenaLogic", "RefreshFightTime")
	if ok then
		dongBo()
		ctx:call("G_ArenaLogic", "OnRefreshFightTime", 0)
	else
		loi(ctx, ma, "G_ArenaLogic.RefreshFightTime")
	end
end)

---------------------------------------------------------------- THÀNH TỰU

R:on("G_AchieveLogic.ClientUpdateFreeStrengthState", function(ctx)
	local ok, ma = chay("G_AchieveLogic", "UpdateFreeStrengthState")
	if ok then
		dongBo()
		ctx:call("G_AchieveLogic", "OnUpdateFreeStrengthState")
	else
		loi(ctx, ma, "G_AchieveLogic.ClientUpdateFreeStrengthState")
	end
end)

------------------------------------------------------------ CÁNH / TRANG PHỤC

--[[ "Nhận cánh" (panel `CUIWingGet`, mở từ thanh trên). Hai luật gốc đã TỰ PHÁT
	sự kiện cho UI (`Active.OnGetFreeWing` / `Active.OnGetChargeWing`,
	`share/share_ClothingLogic.lua:527+`), nên handler chỉ gọi + đồng bộ + tắt lớp
	"đang tải" (`CallGetCharacterFreeWing` đã bật nó,
	`ClientClothingLogic.lua:20`). ]]
R:on("G_ClothingLogic.ClientGetCharacterFreeWing", function(ctx)
	local ok, ma = chay("G_ClothingLogic", "GetCharacterFreeWing")
	if ok then
		dongBo()
		OfflineLog:info("nhan canh mien phi: da cap")
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", 0, {})
	else
		loi(ctx, ma, "G_ClothingLogic.ClientGetCharacterFreeWing")
	end
end)

R:on("G_ClothingLogic.ClientGetCharacterChargeWing", function(ctx)
	local ok, ma = chay("G_ClothingLogic", "GetCharacterChargeWing")
	if ok then
		dongBo()
		OfflineLog:info("nhan canh nap: da cap")
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", 0, {})
	else
		loi(ctx, ma, "G_ClothingLogic.ClientGetCharacterChargeWing")
	end
end)

----------------------------------------------------- XÂY DỰNG (建筑) + NHIỆM VỤ NGÀY

--[[ Hai luật này KHÔNG theo quy ước (bResult, errCode): `BuildingLogic:
	UpgradeBuilding` trả **nil, id** khi được và trả **ErrCode** khi hỏng; còn
	`DailyTaskLogic:AwardDailyTask` KHÔNG trả gì. Vì thế phải đọc riêng, không
	dùng `chay` (hàm ấy đòi `bRet == true`). ]]
local function chayTho(obj, ten, ...)
	local o = _G[obj]
	if type(o) ~= "table" then return false, "khong co doi tuong" end
	local c = lopCha(obj)
	local proxy = c and o[c] or nil
	local self = proxy or o
	local fn = self[ten]
	if type(fn) ~= "function" then return false, "khong co luat " .. ten end
	local args = { n = select("#", ...), ... }
	local ok, r1, r2 = xpcall(function ()
		return fn(self, unpack(args, 1, args.n))
	end, function (e)
		return tostring(e) .. (debug and debug.traceback and ("\n" .. tostring(debug.traceback())) or "")
	end)
	return ok, r1, r2
end

local function xayDung(ctx, ten, nBuildingID)
	local ok, r1 = chayTho("G_BuildingLogic", ten, nBuildingID)
	local maLoi = 0
	if not ok then
		maLoi = 1
	elseif r1 ~= nil then
		maLoi = tonumber(r1) or 1
	end
	dongBo()
	OfflineLog:info(string.format("xay dung %s(%s) -> ma %d", ten, tostring(nBuildingID), maLoi))
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", maLoi, {})
end

R:on("ClientUpgradeBuilding", function(ctx, nBuildingID)
	xayDung(ctx, "UpgradeBuilding", nBuildingID)
end)

R:on("ClientCompleteBuildingUpgrade", function(ctx, nBuildingID)
	xayDung(ctx, "CompleteBuildingUpgrade", nBuildingID)
end)

R:on("ClientCompleteBuildingUpgradeWithDiomaon", function(ctx, nBuildingID)
	-- Tên có lỗi chính tả trong CHÍNH client (Diomaon) — giữ nguyên để khớp.
	local ok, r1 = chayTho("G_BuildingLogic", "CompleteBuildingUpgradeWithDiamond", nBuildingID)
	local maLoi = (not ok) and 1 or (tonumber(r1) or 0)
	dongBo()
	OfflineLog:info(string.format("xay dung hoan tat bang kim cuong(%s) -> ma %d",
		tostring(nBuildingID), maLoi))
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", maLoi, {})
end)

-- `ClientAwardDailyTask` chuyển sang `handlers/achieve.lua` (có cổng trạng thái
-- Done + tự tạo thể hiện `DailyTaskLogic`) — đăng ký hai nơi thì bản nạp sau
-- đè bản nạp trước, dễ mất cổng mà không ai thấy.

------------------------------------------------------- KIỂU B: THUỐC (丹药)

--[[ THUỐC (丹药) — HỆ NÀY CHẾT TRONG CHÍNH BẢN GỐC, không phải thiếu handler.

	ĐO 28/10 (traceback đầy đủ): gọi `ClientUpgradePotion` ⇒ client chạy
	`PotionLogic:UpgradePotion` ⇒ `PotionDataManager:updatePotionData`
	(`share/PotionDataManager.lua:762`) ⇒ `ConfigManager:GetPotionConfigWithLevel`
	⇒ `self.configCacheName.PotionConfig` là **nil** ⇒ nổ
	`class.lua:66 'table index is nil'`.

	Vì sao nil: trong `share/share_configManager.lua` hai dòng đăng ký cache
	**bị chú thích sẵn** — `--PotionConfig` (:129) và `--PotionUnlockConfig`
	(:146) — tức bản client này KHÔNG nạp bảng cấu hình thuốc (bảng
	`KDBGamePotionConfig.json` vẫn có trong gói, nhưng client không dùng).

	⇒ Không thể "chạy đúng luật": chính bản gốc cũng nổ ở đây. Nên lớp offline
	TRẢ LỖI luôn (không gọi hàm nhận, vì hàm nhận sẽ chạy lại luật và nổ), ghi
	log một lần cho rõ. Đừng thêm cấu hình thuốc bằng tay — đó là bịa. ]]
local function thuocChet(ctx, ten)
	OfflineLog:warn(string.format(
		"%s: he thuoc KHONG co cau hinh trong ban nay (configCacheName.PotionConfig bi chu thich)"
		.. " -> tra loi", ten))
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "",
		ErrorCode and ErrorCode.Server and ErrorCode.Server.UnKown or 1, {})
end

R:on("G_PotionLogic.ClientUpgradePotion", function(ctx) thuocChet(ctx, "ClientUpgradePotion") end)
R:on("G_PotionLogic.ClientBuyPotion", function(ctx) thuocChet(ctx, "ClientBuyPotion") end)
R:on("G_PotionLogic.ClientUpgradeResearch", function(ctx) thuocChet(ctx, "ClientUpgradeResearch") end)
R:on("G_PotionLogic.ClientCompletePotionUpgradeWithDiamond", function(ctx)
	thuocChet(ctx, "ClientCompletePotionUpgradeWithDiamond")
end)

return true
