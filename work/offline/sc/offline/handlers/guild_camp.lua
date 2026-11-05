--[[
	offline/handlers/guild_camp.lua — DOANH TRẠI BANG HỘI (军团营地), 8 KHOÁ.

	MÔ HÌNH: offline MỘT người ⇒ doanh trại chỉ có CHÍNH MÌNH (cùng quyết định với
	bang hội tối thiểu 1/11). Vẫn giữ ĐÚNG luật thời gian của bản gốc — đọc từ chính
	`CUIArmyGroupCampsite.lua`:
	  · TƯỚI CÂY (摇钱树): cửa 9:00–21:00 (`IsInWateringTime:2218`), hồi **120 phút**
	    (`nWateringCDTime = 120*60`), **25 lần tưới** thì cây chín (`setTreeStatus`,
	    mốc 1..25, 4 giai đoạn hình).
	  · THÊM CỦI (篝火): cửa **20:00–21:00** (`IsInBonfireTime:2440`), **3 lần/ngày**,
	    hồi **120 giây** (`nFirewoodCDTime`).
	Dữ liệu nằm trong `GameUserGuildData` — đúng chỗ client đọc:
	  `CampTreeGrow` · `UserLastWaterTime` · `UserTreeRewardCount` ·
	  `ReceivedTreeRewardCount` (đã có default trong `GuildLogic:GetGuildData`) ·
	  `UserFireWoodCount` · `UserLastFireWoodTime` (đã có default).

	HÌNH PHẢN HỒI (`ClientGuildCampLogic`):
	  `OnEnterGuildCamp(err, { [uid] = {GameUserBaseInfo, HeroData} })` ·
	  `OnGetGuildCampData(err, {CampData={Tree={GrowUpStateCount}}, UserData={UserTreeRewardCount, UserLastWaterTime}})`
	  · `OnSelfWaterTree(err, {GrowUpStateCount, UserLastWaterTime})` ·
	  `OnUserWaterTree(count)` · `OnUserMoveTo(uid,x,y,dir)` · `OnUserDoAction(uid, ...)`
	  · `OnUserLeaveGuildCamp(uid)`.

	[GHIM] — ba chỗ luật máy chủ chết:
	1. `GameGuildCampTreeRewardConfig` trong `KDBGameCommonConfig` là **CHUỖI RỖNG** ⇒
	   KHÔNG có bảng thưởng cây. Cây vẫn lớn đủ 25 lần và `UserTreeRewardCount` tăng,
	   nhưng `ClientGetWaterTreeReward` chỉ ĐÁNH DẤU đã nhận + ghi log — **không bịa**
	   phần thưởng. (Client không có hàm nhận cho khoá này.)
	2. `ClientFirewood` không có hàm nhận; ghi thẳng vào `GameUserGuildData`.
	3. Mã lỗi: 3501 chưa có bang · 3519 ngoài giờ hoạt động · 3533 đang hồi.
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflineGuildCamp = OfflineGuildCamp or {}

local R = OfflineRouter
local TEN_FILE = "doanh trai bang"
local MOC_NGAY = 5
local GIO_TUOI_TU = 9
local GIO_TUOI_DEN = 21
local GIO_CUI_TU = 20
local GIO_CUI_DEN = 21
local HOI_TUOI = 120 * 60          -- 120 phút
local HOI_CUI = 120                -- 120 giây
local CUI_MOI_NGAY = 3
local TUOI_TOI_DA = 25

------------------------------------------------------------------- tiện ích

local function ma(ten, macDinh)
	local ok, v = pcall(function ()
		local E = _G.ErrorCode
		return E and E.Guild and E.Guild[ten]
	end)
	return (ok and tonumber(v)) or macDinh
end

local function goi(ctx, hamNhan, ...)
	local a = { n = select("#", ...), ... }
	local ok, e = pcall(function ()
		return ctx:call("G_GuildCampLogic", hamNhan, unpack(a, 1, a.n))
	end)
	if not ok then
		OfflineLog:err(string.format("%s: khong goi duoc G_GuildCampLogic.%s -> %s",
			TEN_FILE, tostring(hamNhan), tostring(e)))
	end
end

--[[ Giờ của GAME (máy chủ), không phải giờ máy: UI so cửa giờ và hồi bằng
	`G_GameWorld:GetServerTime()` (`CUIArmyGroupCampsite:IsInWateringTime`), nên lớp
	offline phải dùng CÙNG nguồn, lệch múi giờ máy là lệch cửa. ]]
local function bayGio()
	local ok, t = pcall(function () return G_GameWorld:GetServerTime() end)
	if ok and tonumber(t) and tonumber(t) > 0 then return tonumber(t) end
	return os.time()
end

local function dongBo()
	pcall(function () OfflineStore:syncFromClient() end)
end

local function uid()
	local ok, v = pcall(function () return OfflineBangHoi:uid() end)
	return (ok and tonumber(v)) or 1
end

local function bang()
	local ok, b = pcall(function () return OfflineBangHoi:doc() end)
	return (ok and type(b) == "table") and b or nil
end

-- Bảng GỐC mà client đọc (`ClientGuildCampLogic:GetReceivedTreeRewardCount`,
-- `CUIArmyGroupCampsite:OnGetGuildCampData` đọc `UserLastFireWoodTime/UserFireWoodCount`).
local function duLieu()
	local ok, maLoi, d = pcall(function ()
		return G_DataManager:GetUserDataWithName("GameUserGuildData")
	end)
	if not ok or maLoi ~= 0 or type(d) ~= "table" then return nil end
	if tonumber(d.CampTreeGrow) == nil then d.CampTreeGrow = 0 end
	if tonumber(d.UserLastWaterTime) == nil then d.UserLastWaterTime = 0 end
	if tonumber(d.UserTreeRewardCount) == nil then d.UserTreeRewardCount = 0 end
	if tonumber(d.ReceivedTreeRewardCount) == nil then d.ReceivedTreeRewardCount = 0 end
	if tonumber(d.UserFireWoodCount) == nil then d.UserFireWoodCount = 0 end
	if tonumber(d.UserLastFireWoodTime) == nil then d.UserLastFireWoodTime = 0 end
	return d
end

local function khoaNgay()
	local now = bayGio()
	local t = os.date("*t", now)
	if t.hour < MOC_NGAY then now = now - 86400 end
	local d = os.date("*t", now)
	return d.year * 10000 + d.month * 100 + d.day
end

-- Đặt lại số củi mỗi ngày [MOI] — client chỉ so `UserFireWoodCount < 3`.
local function datLaiCui(d)
	local hom = khoaNgay()
	if tonumber(d.CampFirewoodDay) ~= hom then
		d.CampFirewoodDay = hom
		d.UserFireWoodCount = 0
	end
end

local function trongGio(tu, den)
	local t = os.date("*t", bayGio())
	return t.hour >= tu and t.hour < den
end

local function nguoiChoi()
	local b = {}
	pcall(function ()
		local ok, r, base = pcall(function () return G_UserLogic:GetBaseInfo() end)
		local t = (ok and type(base) == "table") and base or ((ok and type(r) == "table") and r or {})
		for k, v in pairs(t) do b[k] = v end
	end)
	return b
end

local function duLieuHero()
	local heroId = nil
	pcall(function ()
		local ok, b, n = pcall(function () return G_HeroLogic:GetCharacterID() end)
		if ok and b ~= false and tonumber(n) then heroId = tonumber(n) end
	end)
	if heroId == nil then
		pcall(function ()
			local _, hs = G_DataManager:GetUserDataWithName("GameUserHero")
			for k in pairs(hs or {}) do heroId = tonumber(k); break end
		end)
	end
	if heroId == nil then return {} end
	local ok, b, tHero = pcall(function () return G_HeroLogic:GetHeroWithID(heroId) end)
	if ok and b ~= false and type(tHero) == "table" then return tHero end
	return {}
end

------------------------------------------------------------------- 1. VÀO / RỜI
R:on("G_GuildCampLogic.ClientEnterGuildCamp", function (ctx, tClientUserState)
	local b = bang()
	if b == nil then
		goi(ctx, "OnEnterGuildCamp", ma("GuildNotExist", 3501), nil)
		return
	end
	local base = nguoiChoi()
	base.Uid = uid()
	local d = {
		[tostring(uid())] = { GameUserBaseInfo = base, HeroData = duLieuHero() },
	}
	OfflineLog:info(TEN_FILE .. ": vao doanh trai (mot minh)")
	goi(ctx, "OnEnterGuildCamp", 0, d)
end)

R:on("G_GuildCampLogic.ClientLeaveGuildCamp", function (ctx)
	goi(ctx, "OnUserLeaveGuildCamp", uid())
	OfflineLog:info(TEN_FILE .. ": roi doanh trai")
end)

------------------------------------------------------------------- 2. DI CHUYỂN / HÀNH ĐỘNG
--[[ Một người: client đã tự dời nhân vật cục bộ; server chỉ cần ECHO để UI đồng bộ
	(cùng hình với bản gốc phát cho người khác). ]]
R:on("G_GuildCampLogic.ClientUserMoveTo", function (ctx, x, y, direction)
	goi(ctx, "OnUserMoveTo", uid(), tonumber(x) or 0, tonumber(y) or 0, tonumber(direction) or 0)
end)

R:on("G_GuildCampLogic.ClientDoAction", function (ctx, ...)
	local a = { n = select("#", ...), ... }
	local ok, e = pcall(function ()
		ctx:call("G_GuildCampLogic", "OnUserDoAction", uid(), unpack(a, 1, a.n))
	end)
	if not ok then
		OfflineLog:err(TEN_FILE .. ": echo DoAction loi -> " .. tostring(e))
	end
end)

------------------------------------------------------------------- 3. TRẠNG THÁI
R:on("G_GuildCampLogic.ClientGetGuildCampData", function (ctx)
	local b = bang()
	if b == nil then
		goi(ctx, "OnGetGuildCampData", ma("GuildNotExist", 3501), nil)
		return
	end
	local d = duLieu()
	if d == nil then
		goi(ctx, "OnGetGuildCampData", 1, nil)
		return
	end
	datLaiCui(d)
	goi(ctx, "OnGetGuildCampData", 0, {
		CampData = { Tree = { GrowUpStateCount = tonumber(d.CampTreeGrow) or 0 } },
		UserData = {
			UserTreeRewardCount = tonumber(d.UserTreeRewardCount) or 0,
			UserLastWaterTime = tonumber(d.UserLastWaterTime) or 0,
		},
	})
end)

------------------------------------------------------------------- 4. TƯỚI CÂY
R:on("G_GuildCampLogic.ClientWaterTree", function (ctx)
	local b = bang()
	if b == nil then
		goi(ctx, "OnSelfWaterTree", ma("GuildNotExist", 3501), nil)
		return
	end
	if not trongGio(GIO_TUOI_TU, GIO_TUOI_DEN) then
		goi(ctx, "OnSelfWaterTree", ma("GuildNotActivityTime", 3519), nil)
		return
	end
	local d = duLieu()
	if d == nil then
		goi(ctx, "OnSelfWaterTree", 1, nil)
		return
	end
	local grow = tonumber(d.CampTreeGrow) or 0
	if grow >= TUOI_TOI_DA then
		goi(ctx, "OnSelfWaterTree", ma("GuildNotActivityTime", 3519), nil)
		return
	end
	local now = bayGio()
	if now - (tonumber(d.UserLastWaterTime) or 0) < HOI_TUOI then
		goi(ctx, "OnSelfWaterTree", ma("GuildDonateCdTime", 3533), nil)
		return
	end

	grow = grow + 1
	d.CampTreeGrow = grow
	d.UserLastWaterTime = now
	if grow >= TUOI_TOI_DA then
		d.UserTreeRewardCount = (tonumber(d.UserTreeRewardCount) or 0) + 1
		OfflineLog:info(TEN_FILE .. ": cay CHIN sau 25 lan tuoi — cho nhan thuong")
	end
	dongBo()
	OfflineLog:info(string.format("%s: tuoi cay lan %d/25", TEN_FILE, grow))
	goi(ctx, "OnSelfWaterTree", 0, { GrowUpStateCount = grow, UserLastWaterTime = now })
	-- Bản gốc phát cho NGƯỜI KHÁC; offline phát lại để UI tự nhiên.
	goi(ctx, "OnUserWaterTree", grow)
end)

------------------------------------------------------------------- 5. NHẬN THƯỞNG CÂY
--[[ `GameGuildCampTreeRewardConfig` RỖNG ⇒ không có phần thưởng để trao. Chỉ đánh
	dấu đã nhận (để UI thôi gọi lại) + ghi log. Client KHÔNG có hàm nhận cho khoá này. ]]
R:on("G_GuildCampLogic.ClientGetWaterTreeReward", function (ctx)
	local d = duLieu()
	if d == nil then return end
	local co = tonumber(d.UserTreeRewardCount) or 0
	if co <= (tonumber(d.ReceivedTreeRewardCount) or 0) then return end
	d.ReceivedTreeRewardCount = co
	dongBo()
	OfflineLog:warn(string.format("%s: danh dau da nhan %d luot thuong cay —"
		.. " GameGuildCampTreeRewardConfig RONG nen KHONG trao mon nao", TEN_FILE, co))
end)

------------------------------------------------------------------- 6. THÊM CỦI
--[[ Không có hàm nhận: ghi thẳng `UserFireWoodCount` / `UserLastFireWoodTime` vào
	GameUserGuildData — đúng hai trường `CUIArmyGroupCampsite:OnGetGuildCampData` đọc. ]]
R:on("G_GuildCampLogic.ClientFirewood", function (ctx)
	local b = bang()
	if b == nil then return end
	if not trongGio(GIO_CUI_TU, GIO_CUI_DEN) then
		OfflineLog:info(TEN_FILE .. ": them cui ngoai gio 20-21 — bo qua")
		return
	end
	local d = duLieu()
	if d == nil then return end
	datLaiCui(d)
	local so = tonumber(d.UserFireWoodCount) or 0
	if so >= CUI_MOI_NGAY then
		OfflineLog:info(TEN_FILE .. ": da du 3 lan them cui hom nay")
		return
	end
	local now = bayGio()
	if now - (tonumber(d.UserLastFireWoodTime) or 0) < HOI_CUI then
		OfflineLog:info(TEN_FILE .. ": them cui dang hoi 120 giay")
		return
	end
	d.UserFireWoodCount = so + 1
	d.UserLastFireWoodTime = now
	dongBo()
	OfflineLog:info(string.format("%s: them cui lan %d/3", TEN_FILE, d.UserFireWoodCount))
	pcall(function ()
		G_EventManager:PostDataEvent({
			UserFireWoodCount = d.UserFireWoodCount,
			UserLastFireWoodTime = now,
		}, "GameUserGuildData", "UserFireWoodCount")
	end)
end)

OfflineLog:info("doanh trai bang: da noi 8 khoa (vao/roi/di chuyen/hanh dong/trai thai/tuoi cay/nhan thuong/them cui)")

return true
