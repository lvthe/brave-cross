--[[
	offline/handlers/luyen_hero.lua — LUYỆN HERO / 训练英雄 (`G_HeroPracticeLogic`, 3 khoá).

	  · `ClientPracticeHero(nHeroID, strAreaID)`  → `Statistics:OnPracticeHero()`
	  · `ClientGetPracticePrize(strArenaID)`      → im lặng (`cb=''`)
	  · `ClientGetPracticeInfo()`                 → `G_ClientQuestLogic:ClientGetPracticeInfo(t)`

	`share/HeroPracticeLogic.lua` (427 dòng) chỉ có helper ĐỌC/KIỂM
	(`GetUserHeroPracticeData` :72 · `IsCanPracticeHero` :161 · `getGoldReward` :378 ·
	`getHeroExpReward` :386); **KHÔNG có** ba hàm đột biến ⇒ đây là TÁI DỰNG, cùng luật
	với `bravecross-server/src/handlers/luyen_hero.ts` (Mốc 47).

	[GHIM-A] **KHÔNG quay `ExtraPrize`** — cấu hình có `{MinChance, HourChance[{Probability,
	         Multi}], DailyMaxCount, MaxCount}` nhưng luật quay nằm trong máy chủ đã chết
	         (`GetPracticePrize` vắng khỏi `share/`). Chỉ phát THƯỞNG GỐC (vàng + Exp tướng).
	[GHIM-B] `ClientGetPracticePrize` (thân gốc vắng): ô phải CÓ tướng và
	         `now - BeginTime >= PracticeTime` (7200 s, `ctor:12`); không đạt ⇒ **4201**
	         `HeroPractice.NoInTime`. Phát xong XOÁ ô (`HeroID = 0`, `BeginTime = 0`).
	[GHIM-C] `ClientGetPracticeInfo`: hình trả lời thật của máy chủ KHÔNG dựng lại được —
	         `CUIQuest.lua:418` đọc `tData[tostring(index)]` như một **DANH SÁCH THƯỞNG**
	         có trường `PracticeMaxCount`, mà `PracticeMaxCount` **0 lần** trong cấu hình
	         (chỉ có ở UI) ⇒ trường ấy do máy chủ sinh. Nay trả **BẢNG RỖNG** + ghi log,
	         để lớp "đang tải" tắt và màn giữ nguyên hiển thị cấu hình như trước.

	Callback `OnPracticeHero` là PHƯƠNG THỨC của **`Statistics`** (`share/Statistics.lua:635`
	— tăng bộ đếm ngày + cộng hoạt động tuần), không phải của `G_HeroPracticeLogic`
	(grep `HeroPracticeLogic:new` = 0).
]]

require("offline.log")
require("offline.store")
require("offline.router")

local R = OfflineRouter
local TEN_FILE = "luyen hero"

local PRACTICE_TIME = 7200          -- ctor `:12` (3600 x 2)
local MA = {
	ARG        = 2,
	NO_IN_TIME = 4201,              -- ErrorCode.HeroPractice.NoInTime
	UNKNOWN    = 1,
}

local function loi(ctx, ma, viSao)
	OfflineLog:info(string.format("%s: tu choi, ma %d (%s)",
		TEN_FILE, tonumber(ma) or 1, tostring(viSao)))
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", tonumber(ma) or 1, {})
end

local function dongBo()
	pcall(function () OfflineStore:syncFromClient() end)
end

--[[ Gọi helper trên THỰC THỂ `G_ClientQuestLogic` (`ClientQuestLogic = class(
	HeroPracticeLogic)`, `G_ClientQuestLogic = ClientQuestLogic:new()` —
	`user/Logical/ClientQuestLogic.lua:3/7`), qua PROXY LỚP CHA.

	⚠ ĐO ĐƯỢC 31/10: gọi thẳng trên LỚP `HeroPracticeLogic` thì **trượt** —
	`class()` giữ phương thức trong một `vtbl` ẨN, `__index` nằm ở metatable của
	`vtbl` chứ không ở lớp (`share/class.lua`), nên `HeroPracticeLogic.IsCan…
	PracticeHero` là `nil` ⇒ mọi lời gọi trả `false, 0` ⇒ handler trả mã **1**
	vô nghĩa. Triệu chứng: bảng kiểm trong game ra `ma=1` cho "gán tướng vào ô"
	trong khi `GetPracticeInfo` (không cần helper) vẫn chạy đúng. ]]
local function goiCha(ten, ...)
	local o = _G.G_ClientQuestLogic
	local c = _G.HeroPracticeLogic
	local self = (type(o) == "table" and type(c) == "table" and o[c]) or o or c
	if type(self) ~= "table" then return nil end
	local fn = self[ten]
	if type(fn) ~= "function" then return nil end
	local args = { n = select("#", ...), ... }
	local a1, a2 = nil, nil
	local ok = xpcall(function ()
		a1, a2 = fn(self, unpack(args, 1, args.n))
	end, function (e)
		OfflineLog:err(TEN_FILE .. ": " .. ten .. " nem loi: " .. tostring(e))
	end)
	if not ok then return nil end
	return a1, a2
end

local function giay()
	local ok, t = pcall(function () return G_GameWorld:GetServerTime() end)
	if ok and tonumber(t) then return tonumber(t) end
	return os.time()
end

------------------------------------------------------------------- GÁN TƯỚNG VÀO Ô
R:on("G_HeroPracticeLogic.ClientPracticeHero", function (ctx, nHeroID, strAreaID)
	local nHero = tonumber(nHeroID)
	if nHero == nil or type(strAreaID) ~= "string" or strAreaID == "" then
		return loi(ctx, MA.ARG, "PracticeHero(tham so)")
	end

	local okCan, maCan = goiCha("IsCanPracticeHero", nHero, strAreaID)
	if okCan ~= true then
		return loi(ctx, tonumber(maCan) or MA.UNKNOWN,
			string.format("PracticeHero(%d, %s)", nHero, strAreaID))
	end

	local _, u = goiCha("GetUserHeroPracticeData")
	if type(u) ~= "table" then return loi(ctx, MA.UNKNOWN, "PracticeHero(user data)") end
	u.PracticeStates = u.PracticeStates or {}
	u.PracticeStates[strAreaID] = {
		AreaID = strAreaID,
		HeroID = nHero,
		BeginTime = giay(),
		RefreshExtraTime = 0,
		RefreshExtraCountDaily = 0,
		RefreshExtraCount = 0,
	}

	dongBo()
	OfflineLog:info(string.format("%s: giao hero %d vao o %s", TEN_FILE, nHero, strAreaID))
	ctx:call("Statistics", "OnPracticeHero")
end)

------------------------------------------------------------------- LĨNH THƯỞNG
R:on("G_HeroPracticeLogic.ClientGetPracticePrize", function (ctx, strArenaID)
	if type(strArenaID) ~= "string" or strArenaID == "" then
		return loi(ctx, MA.ARG, "GetPracticePrize(tham so)")
	end

	local _, u = goiCha("GetUserHeroPracticeData")
	if type(u) ~= "table" then return loi(ctx, MA.UNKNOWN, "GetPracticePrize(user data)") end
	local st = u.PracticeStates and u.PracticeStates[strArenaID]
	if type(st) ~= "table" or (tonumber(st.HeroID) or 0) == 0 then
		return loi(ctx, MA.NO_IN_TIME, "GetPracticePrize(o trong)")
	end

	local nHero = tonumber(st.HeroID)
	if giay() - (tonumber(st.BeginTime) or 0) < PRACTICE_TIME then
		return loi(ctx, MA.NO_IN_TIME, "GetPracticePrize(chua du gio)")
	end

	local nLevel = 1
	pcall(function ()
		local _, l = G_UserLogic:GetLevel()
		nLevel = tonumber(l) or 1
	end)

	local nGold = tonumber(goiCha("getGoldReward", nLevel, strArenaID)) or 0
	local nExp = tonumber(goiCha("getHeroExpReward", nLevel)) or 0

	if nGold > 0 then
		pcall(function () G_UserLogic:AddGold(nGold, "HeroPractice") end)
	end
	if nExp > 0 then
		-- `GetHeroWithID` trả `(mã, tướng)`; nhận BẢNG ở ĐÂU của cặp ấy cũng được
		-- (bản gốc đặt mã lỗi ở vị trí 1, nhưng đây là dữ liệu client nên chấp cả hai).
		local okH, a1, a2 = pcall(function () return G_HeroLogic:GetHeroWithID(nHero) end)
		local tHero = nil
		if okH then
			if type(a1) == "table" then tHero = a1
			elseif type(a2) == "table" then tHero = a2 end
		end
		if tHero ~= nil then
			pcall(function ()
				G_HeroDataManager:SetHeroEx(tHero, (tonumber(tHero.Ex) or 0) + nExp)
			end)
		else
			OfflineLog:warn(string.format("%s: khong thay tuong %d de cong exp", TEN_FILE, nHero))
		end
	end

	-- [GHIM-B] Phát xong thì XOÁ ô (giữ nguyên khoá `AreaID` cho UI đọc).
	st.HeroID = 0
	st.BeginTime = 0

	dongBo()
	OfflineLog:info(string.format("%s: linh thuong o %s — vang %d, exp tuong %d",
		TEN_FILE, strArenaID, nGold, nExp))
	-- `CallGetPracticePrize` bật lớp "đang tải" mà không có callback riêng ⇒ tắt nó.
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", 0, {})
end)

------------------------------------------------------------------- TRUY VẤN TRẠNG THÁI
--[[ [GHIM-C] Hình trả lời thật không dựng lại được ⇒ trả BẢNG RỖNG. Xem đầu tệp. ]]
R:on("G_HeroPracticeLogic.ClientGetPracticeInfo", function (ctx)
	pcall(function () OfflineStore:syncFromClient() end)
	OfflineLog:info(TEN_FILE .. ": GetPracticeInfo -> bang rong (khai [GHIM-C])")
	ctx:call("G_ClientQuestLogic", "ClientGetPracticeInfo", {})
end)

OfflineLog:info("luyen hero: da noi 3 khoa (PracticeHero / GetPracticePrize / GetPracticeInfo)")

return true
