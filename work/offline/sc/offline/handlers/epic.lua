--[[
	offline/handlers/epic.lua — CHIẾN DỊCH ANH HÙNG (史诗战役 / Epic), 5 KHOÁ.

	Năm khoá `G_EpicChapterLogic`: `ClientSetTodayChapterDifficult` · `ClientEpicResetDaily` ·
	`ClientEpicChapterCompeleteFight` · `ClientSweepEpicChapter` · `ClientBuyEpicGoods`.

	⚠ KHÔNG có tệp share cho Epic (grep `share/` 0 `EpicBattleLogic`), nhưng DỮ LIỆU và
	LUẬT ĐỌC thì đủ và đều là mã GỐC:
	  · bảng người chơi `GameUserEpicChapter`: `Prestige[camp]={Level,Exp}`,
	    `TodayChapterInfo={FightFaction,Diffculty}`, `TodayMaxPassedLevel`,
	    `PassedChapterInfo[camp].Difficulty`, `EpicCoin` — hình dạng đọc từ
	    `CUIEpicData.lua:227-260` + `getDifficultMax` (:416) + `getUsrUpgradeData` (:171).
	  · lịch mở phe `EpicOpenTimeConfig` + `G_ConfigManager:IsEpicOpen(camp, ngày)`.
	  · cấu hình ải `GetEpicChapterConfigV2(camp, diff, level)` và
	    `GetEpicChapterConfig(chapterID)` (180 dòng: `HeroFactions`, `Difficulty`,
	    `LevelID`, `PrizeID`, `HeroFactionsPrestigeReward`).
	  · cấp danh vọng = `G_ConfigManager:GetHeroFactionsPrestigeLevel(exp)` (hàm GỐC).
	  · shop `GameEpicChapterGoodsConfig[key] = {PrizeID, cost}` — tiền là **EpicCoin**.

	⚠ BẪY LỚN — CHỮ KÝ THẬT KHÁC KHAI BÁO: `ClientEpicBattleLogic:CallCompeleteFight`
	khai `(strChapterID, tHeroIdList, tEmployHero)` nhưng `FBEpic:OnEnd(bComplete)`
	(`user/FB/FBEpic.lua:60-70`) gọi `CallCompeleteFight(bComplete, ChapterID,
	HeroIdList, EmployHero)` — **BỐN** giá trị, `bComplete` đứng ĐẦU. Handler nhận
	`(bComplete, chapterID, heroList, employHero)`; đọc theo chữ ký khai báo là
	MẤT kết quả trận.

	[GHIM] — ba chỗ luật máy chủ chết, ghi rõ:
	1. `PassedChapterInfo[camp].Difficulty` khởi tạo **1** (độ khó mở sẵn); qua màn 9
	   của độ khó hiện tại thì mở độ khó kế (+1).
	2. Quét chỉ quét những tầng ĐÃ QUA HÔM NAY (`TodayMaxPassedLevel`), và chỉ quét
	   MỘT LẦN mỗi tầng — mốc `SweptMaxLevel` [MOI] để không phát danh vọng hai lần.
	3. Danh vọng cộng dồn TUYỆT ĐỐI (`Exp`), cấp suy bằng hàm GỐC
	   `GetHeroFactionsPrestigeLevel` (không tự đặt ngưỡng).
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflineEpic = OfflineEpic or {}

local R = OfflineRouter
local TEN_FILE = "epic"
local KHOA_BANG = "GameUserEpicChapter"
local SO_PHE = 4

------------------------------------------------------------------- tiện ích

local function goi(ctx, hamNhan, ...)
	local a = { n = select("#", ...), ... }
	local ok, e = pcall(function ()
		return ctx:call("g_EpicChapterLogic", hamNhan, unpack(a, 1, a.n))
	end)
	if not ok then
		OfflineLog:err(string.format("%s: khong goi duoc g_EpicChapterLogic.%s -> %s",
			TEN_FILE, tostring(hamNhan), tostring(e)))
	end
end

local function donLop(ctx, nMa)
	pcall(function ()
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", nMa or 0, {})
	end)
end

local function thongBao(nMa)
	if nMa == nil or nMa == 0 then return end
	pcall(function ()
		g_CUINotificationCenter:PostNotification(
			CUINotificationEvent.OnServerRequestError, nMa)
	end)
end

local function dongBo()
	pcall(function () OfflineStore:syncFromClient() end)
end

local function ma(ten, macDinh)
	local ok, v = pcall(function ()
		local E = _G.ErrorCode
		return E and E.Shop and E.Shop[ten]
	end)
	return (ok and tonumber(v)) or macDinh
end

------------------------------------------------------------------- dữ liệu
local function duLieu()
	local ok, maLoi, d = pcall(function ()
		return G_DataManager:GetUserDataWithName(KHOA_BANG)
	end)
	if not ok or maLoi ~= 0 then return nil end
	if type(d) ~= "table" then
		d = {}
		pcall(function () G_DataManager:SetUserDataWithName(KHOA_BANG, d) end)
	end

	-- Hình dạng: `CUIEpicData:getGameUserEpicChapter` (:227-260).
	if type(d.Prestige) ~= "table" then d.Prestige = {} end
	for camp = 1, SO_PHE do
		local k = tostring(camp)
		if type(d.Prestige[k]) ~= "table" then
			d.Prestige[k] = { Level = 0, Exp = 0 }
		end
		if tonumber(d.Prestige[k].Level) == nil then d.Prestige[k].Level = 0 end
		if tonumber(d.Prestige[k].Exp) == nil then d.Prestige[k].Exp = 0 end
	end
	if type(d.TodayChapterInfo) ~= "table" then d.TodayChapterInfo = {} end
	if tonumber(d.TodayMaxPassedLevel) == nil then d.TodayMaxPassedLevel = 0 end
	if type(d.PassedChapterInfo) ~= "table" then d.PassedChapterInfo = {} end
	for camp = 1, SO_PHE do
		local k = tostring(camp)
		if type(d.PassedChapterInfo[k]) ~= "table" then
			d.PassedChapterInfo[k] = { Difficulty = 1 }
		end
		local diff = tonumber(d.PassedChapterInfo[k].Difficulty) or 0
		if diff < 1 then d.PassedChapterInfo[k].Difficulty = 1 end
	end
	if tonumber(d.EpicCoin) == nil then d.EpicCoin = 0 end
	if tonumber(d.SweptMaxLevel) == nil then d.SweptMaxLevel = 0 end
	return d
end

local function luu(d)
	dongBo()
end

local function cfgChapter(chapterID)
	local ok, cfg = pcall(function ()
		return G_ConfigManager:GetEpicChapterConfig(tostring(chapterID))
	end)
	if ok and type(cfg) == "table" then return cfg end
	return nil
end

local function cfgV2(camp, diff, level)
	local ok, cfg = pcall(function ()
		return G_ConfigManager:GetEpicChapterConfigV2(camp, diff, level)
	end)
	if ok and type(cfg) == "table" then return cfg end
	return nil
end

local function moHomNay(camp)
	local ok, v = pcall(function () return G_ConfigManager:IsEpicOpen(camp) end)
	return ok and v == true
end

-- Danh vọng: cộng dồn tuyệt đối; cấp lấy bằng hàm GỐC của config manager.
local function congDanhVong(d, camp, them)
	if them == nil or them <= 0 then return end
	local k = tostring(camp)
	local p = d.Prestige[k]
	p.Exp = (tonumber(p.Exp) or 0) + them
	local cap = nil
	pcall(function () cap = G_ConfigManager:GetHeroFactionsPrestigeLevel(p.Exp) end)
	if tonumber(cap) and tonumber(cap) >= 0 then p.Level = tonumber(cap) end
	OfflineLog:info(string.format("%s: danh vong phe %d +%d -> Exp %d, cap %d", TEN_FILE,
		camp, them, p.Exp, p.Level))
end

local function phatPrizeID(nPrizeID, from)
	if not tonumber(nPrizeID) or nPrizeID <= 0 then return false end
	-- `GetPrizeWithID` trả `(bResult, prize)` ⇒ pcall BA giá trị.
	local ok, b, prize = pcall(function ()
		return G_PrizeLogic:GetPrizeWithID(nPrizeID)
	end)
	if not ok or b == false or type(prize) ~= "table" or type(prize.PrizeContent) ~= "table" then
		return false
	end
	local okP, r = pcall(function ()
		return G_ChapterLogic:SetDataWithPrizeList(prize.PrizeContent, 1, from or "Epic")
	end)
	return okP and r ~= false
end

------------------------------------------------------------------- 1. CHỌN PHE / ĐỘ KHÓ
R:on("G_EpicChapterLogic.ClientSetTodayChapterDifficult", function (ctx, nFaction, nDifficult)
	local d = duLieu()
	if d == nil then return goi(ctx, "OnClientSetTodayChapterDifficult", 1) end
	local camp = tonumber(nFaction) or 0
	local diff = tonumber(nDifficult) or 0

	if camp < 1 or camp > SO_PHE then
		return goi(ctx, "OnClientSetTodayChapterDifficult", 1)
	end
	if not moHomNay(camp) then
		OfflineLog:info(TEN_FILE .. ": phe " .. tostring(camp) .. " khong mo hom nay")
		return goi(ctx, "OnClientSetTodayChapterDifficult", 1)
	end
	local toiDa = tonumber(d.PassedChapterInfo[tostring(camp)].Difficulty) or 1
	if diff < 1 or diff > toiDa then
		OfflineLog:info(string.format("%s: do kho %d ngoai khoang 1..%d", TEN_FILE, diff, toiDa))
		return goi(ctx, "OnClientSetTodayChapterDifficult", 1)
	end

	d.TodayChapterInfo = { FightFaction = camp, Diffculty = diff }
	d.TodayMaxPassedLevel = 0
	d.SweptMaxLevel = 0
	d.LastRefreshTime = os.time()
	luu(d)
	OfflineLog:info(string.format("%s: chon phe %d, do kho %d", TEN_FILE, camp, diff))
	goi(ctx, "OnClientSetTodayChapterDifficult", 0)
end)

------------------------------------------------------------------- 2. ĐẶT LẠI NGÀY
R:on("G_EpicChapterLogic.ClientEpicResetDaily", function (ctx)
	local d = duLieu()
	if d == nil then return goi(ctx, "OnEpicResetDaily") end
	d.TodayChapterInfo = {}
	d.TodayMaxPassedLevel = 0
	d.SweptMaxLevel = 0
	d.LastRefreshTime = os.time()
	luu(d)
	OfflineLog:info(TEN_FILE .. ": dat lai ngay (chua chon phe)")
	goi(ctx, "OnEpicResetDaily")
end)

------------------------------------------------------------------- 3. KẾT THÚC TRẬN
R:on("G_EpicChapterLogic.ClientEpicChapterCompeleteFight", function (ctx, bComplete, strChapterID,
	tHeroIdList, tEmployHero)
	local d = duLieu()
	local chapterID = tostring(strChapterID or "")
	local cfg = cfgChapter(chapterID)
	local isWin = (bComplete == true)

	if d ~= nil and cfg ~= nil and isWin then
		local camp = tonumber(cfg.HeroFactions) or 0
		local level = tonumber(cfg.LevelID) or 0
		local diff = tonumber(cfg.Difficulty) or 0
		phatPrizeID(tonumber(cfg.PrizeID), "EpicChapter")
		congDanhVong(d, camp, tonumber(cfg.HeroFactionsPrestigeReward) or 0)
		-- Ghi tiến độ HÔM NAY khi đúng phe/độ khó đã chọn.
		local today = d.TodayChapterInfo or {}
		if tonumber(today.FightFaction) == camp and tonumber(today.Diffculty) == diff then
			if level > (tonumber(d.TodayMaxPassedLevel) or 0) then
				d.TodayMaxPassedLevel = level
			end
		end
		-- Qua màn 9 ⇒ mở độ khó kế (tối đa bằng số độ khó của cấu hình).
		if level >= 9 and camp > 0 then
			local k = tostring(camp)
			if diff >= (tonumber(d.PassedChapterInfo[k].Difficulty) or 1) then
				d.PassedChapterInfo[k].Difficulty = diff + 1
			end
		end
		luu(d)
		OfflineLog:info(string.format("%s: thang '%s' (phe %d, do kho %d, tang %d)",
			TEN_FILE, chapterID, camp, diff, level))
	elseif d ~= nil then
		luu(d)
		OfflineLog:info(string.format("%s: '%s' %s", TEN_FILE, chapterID,
			isWin and "khong co cau hinh" or "thua"))
	end

	-- Hàm nhận nhận MỘT bảng; thiếu thì client tự dùng {IsWin=false, PrizeID=0}.
	goi(ctx, "OnEpicChapterCompeleteFight", {
		IsWin = isWin and cfg ~= nil,
		PrizeID = (isWin and cfg ~= nil) and tonumber(cfg.PrizeID) or 0,
	})
	donLop(ctx)
end)

------------------------------------------------------------------- 4. QUÉT
R:on("G_EpicChapterLogic.ClientSweepEpicChapter", function (ctx, dwCampType, dwDifficultID)
	local d = duLieu()
	local camp = tonumber(dwCampType) or 0
	local diff = tonumber(dwDifficultID) or 0
	local ds = {}

	if d ~= nil and camp >= 1 and camp <= SO_PHE then
		local toiDa = tonumber(d.TodayMaxPassedLevel) or 0
		local tu = (tonumber(d.SweptMaxLevel) or 0) + 1
		local tong = 0
		for level = tu, toiDa do
			local cfg = cfgV2(camp, diff, level)
			if cfg ~= nil then
				local thuong = tonumber(cfg.HeroFactionsPrestigeReward) or 0
				if thuong > 0 then
					ds[level] = thuong
					tong = tong + thuong
				end
			end
		end
		congDanhVong(d, camp, tong)
		if toiDa > (tonumber(d.SweptMaxLevel) or 0) then d.SweptMaxLevel = toiDa end
		luu(d)
		OfflineLog:info(string.format("%s: quet phe %d do kho %d — %d tang, +%d danh vong",
			TEN_FILE, camp, diff, toiDa - tu + 1, tong))
	else
		OfflineLog:info(TEN_FILE .. ": quet khong hop le (phe " .. tostring(camp) .. ")")
	end

	goi(ctx, "OnSweepEpicChapter", ds)
	donLop(ctx)
end)

------------------------------------------------------------------- 5. SHOP EPIC
--[[ `GameEpicChapterGoodsConfig[key] = {PrizeID, cost}`; tiền là `EpicCoin`
	(`CUIExchangeShop.lua:35`). Không có hàm nhận riêng cho mua ⇒ dừng lớp tải bằng
	`OnReciveResponse` (khoá "ClientBuyGoods") + phát sự kiện `OnBuyGoodsRsp`. ]]
R:on("G_EpicChapterLogic.ClientBuyEpicGoods", function (ctx, nItemKey)
	local d = duLieu()
	if d == nil then return donLop(ctx, 1) end
	local cfgBang = nil
	pcall(function ()
		cfgBang = G_ConfigManager:GetCommonConfigWithName("GameEpicChapterGoodsConfig")
	end)
	local muc = type(cfgBang) == "table" and cfgBang[tostring(tonumber(nItemKey) or 0)] or nil
	if type(muc) ~= "table" then
		OfflineLog:warn(TEN_FILE .. ": khong co mon shop " .. tostring(nItemKey))
		return donLop(ctx, ma("NotEnoughCurrency", 1901))
	end

	local gia = tonumber(muc.cost) or 0
	if (tonumber(d.EpicCoin) or 0) < gia then
		OfflineLog:info(string.format("%s: thieu EpicCoin (%s < %d)", TEN_FILE,
			tostring(d.EpicCoin), gia))
		return donLop(ctx, ma("NotEnoughCurrency", 1901))
	end
	if not phatPrizeID(tonumber(muc.PrizeID), "EpicShop") then
		OfflineLog:warn(TEN_FILE .. ": khong phat duoc PrizeID " .. tostring(muc.PrizeID))
		return donLop(ctx, 1)
	end
	d.EpicCoin = (tonumber(d.EpicCoin) or 0) - gia
	luu(d)
	OfflineLog:info(string.format("%s: mua mon %s (-%d EpicCoin, con %d)", TEN_FILE,
		tostring(nItemKey), gia, d.EpicCoin))
	donLop(ctx)
	pcall(function ()
		G_EventManager:PostLogicEvent(nil, "OnBuyGoodsRsp")
	end)
end)

OfflineLog:info("epic: da noi 5 khoa (chon phe/do kho, dat lai ngay, ket thuc tran, quet, shop)")

return true
