--[[
	offline/handlers/canh.lua — CÁNH: TIẾN CẤP (进阶) + CƯỜNG HOÁ (强化).

	Bốn lệnh client của `CUIWing` (`user/UI/CUIWing.lua`), trước lượt này hai khoá nằm
	trong lớp chắn `chua_ho_tro.lua` (mã 1), hai khoá còn lại rơi vào nhóm "thiếu":

	  · `G_HeroLogic.ClientUpgradeWing(heroID)`          — nút "tiến cấp" (`:329`)
	  · `G_HeroLogic.ClientUpgradeWingWithDiamond(heroID)` — nút tiến cấp bằng kim cương (`:789`)
	  · `G_HeroLogic.ClientIntensifyWing(heroID)`        — cường hoá một cấp (`ClientHeroLogic:1037`)
	  · `G_HeroLogic.ClientAutoIntensifyWing(heroID)`    — cường hoá tự động (`CUIWing:696`)

	LUẬT — CHÉP NGUYÊN từ bản đã có trong `bravecross-ax/Content/src/bc/may_chu/handler/
	duong_choi.lua` (khối "CÁNH" `:560-1030`), nơi chủ dự án đã chốt 19/10/2026 sau khi
	đọc tip gốc và cân nhắc hai thứ tự:

	  (1) Đọc chúc phúc ĐANG HIỆN; thanh đầy (`>= MaxBlessing`) ⇒ lượt này CHẮC CHẮN.
	  (2) Chưa đầy ⇒ `p = EffectivePercent + (1-EffectivePercent) * blessing/MaxBlessing`
	      — đúng con số người chơi thấy trên thanh.
	  (3) THẤT BẠI mới cộng chúc phúc; cộng `ceil(MaxBlessing * EffectivePercent / 2)`
	      (`[GHIM]` — config không nói, UI chỉ nói "đầy thì tiến được").
	      THÀNH CÔNG ⇒ cấp + 1, chúc phúc về 0.
	  * Chúc phúc reset lúc **5:00 mỗi ngày** (khoá riêng của máy chủ trong
	    `GameUserGlobalData` — `WingBlessingDay`).
	  * Nâng bằng KIM CƯƠNG: trả `CostDiamond`, **CHẮC CHẮN thành công**.
	  * Trần cấp = số cấp của `HeroWingConfig["1"]` (14).

	CƯỜNG HOÁ: `GameWingIntensifyConfig[cấp+1].StoneCost` đá 101; **trần = CẤP NGƯỜI CHƠI**
	(`G_UserLogic:GetLevel()` — đúng `CUIWingEnhance:isEnhanceLevelOverUserLevel` `:1924-1946`
	và `getCanEnhanceLevelAndWingStoneNum` `:1952-2016`), thêm trần số dòng cấu hình.
	`Auto` = lặp tới khi hết đá hoặc chạm trần; trả `OnIntensifyWing` MỘT lần với cấp cuối.

	MÃ LỖI (đúng nhóm đã khai trong `share/error.lua`): 4 tham số · 6 thiếu cấu hình ·
	1301 không thấy tướng · 1327 chưa có cánh · 1329 hết cấp · 1328 không cường hoá được
	(chạm trần) · 1201 thiếu đá · 1202 trừ đá lỗi · `Common.NotEnoughDiamond = 504`.

	PHẢN HỒI: đóng lớp tải bằng `OnReciveResponse("", "", mã, {})`; UI nghe hai logic
	event `OnUpgradeWing` / `OnIntensifyWing` (đăng ký ở `CUIWing.lua:67-68`).
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflineCanh = OfflineCanh or {}

local R = OfflineRouter
local TEN_FILE = "canh"

local ID_DA_TIEN_CAP = 102
local ID_DA_CUONG_HOA = 101

local function dongBo()
	pcall(function () OfflineStore:syncFromClient() end)
end

local function cfg(ten)
	local ok, v = pcall(function ()
		return G_ConfigManager:GetCommonConfigWithName(ten)
	end)
	if ok and type(v) == "table" then return v end
	return nil
end

local function cauHinhCanh()
	local heroWing = cfg("HeroWingConfig")
	local upgrade = cfg("UpgradeWingConfig")
	local intensify = cfg("GameWingIntensifyConfig")
	if heroWing == nil or upgrade == nil or intensify == nil then return nil end
	local dsCap = heroWing["1"] or heroWing[1]
	if type(dsCap) ~= "table" or #dsCap <= 0 then return nil end
	local nCuongHoa = 0
	for k in pairs(intensify) do
		local n = tonumber(k)
		if n ~= nil and n > nCuongHoa then nCuongHoa = n end
	end
	return {
		upgrade = upgrade,
		intensify = intensify,
		capToiDa = #dsCap,
		capCuongHoa = nCuongHoa,
	}
end

local function layHero(nHeroID)
	-- BẪY: `GetHeroWithID` trả `(bResult, tHero)`; `pcall` gói thêm một giá trị ⇒
	-- phải nhận BA (đây đúng họ bẫy `GetItemCount`/`GetDiamond` đã ghi trong dự án).
	local ok, bRet, tHero = pcall(function () return G_HeroLogic:GetHeroWithID(nHeroID) end)
	if ok and bRet == true and type(tHero) == "table" then return tHero end
	return nil
end

local function demTui(nId)
	local ok, _, n = pcall(function () return G_ItemLogic:GetItemCount(nId) end)
	if ok then return tonumber(n) or 0 end
	return 0
end

local function truTui(nId, nSo, strLyDo)
	local ok, b = pcall(function ()
		return G_ItemDataManager:ReduceItem(nId, nSo, strLyDo)
	end)
	return ok and b == true
end

local function layKimCuong()
	local ok, _, n = pcall(function () return G_UserLogic:GetDiamond() end)
	if ok then return tonumber(n) or 0 end
	return 0
end

local function layCapNguoiChoi()
	local ok, _, n = pcall(function () return G_UserLogic:GetLevel() end)
	if ok then return tonumber(n) or 1 end
	return 1
end

local function traLoi(ctx, nMa)
	pcall(function ()
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", nMa or 0, {})
	end)
end

--[[ Chỉ số ngày của đồng hồ 5:00 — giống hệt bản Axmol (`ngay05`). ]]
local function ngay05(nNow)
	return math.floor((nNow - 5 * 3600) / 86400)
end

--[[ Reset chúc phúc khi sang ngày mới (5:00). Ghi khoá RIÊNG của máy chủ vào
	`GameUserGlobalData`; client không cần biết. ]]
local function resetChucPhuc(hero)
	local homNay = ngay05(os.time())
	-- BẪY: `GetUserGlobalData` trả `(bResult, giá trị)`; `pcall` gói thêm ⇒ BA giá trị.
	local _, _, daLuu = pcall(function () return G_UserDataManager:GetUserGlobalData("WingBlessingDay") end)
	if tonumber(daLuu) == homNay then return false end
	pcall(function () G_UserDataManager:SetUserGlobalData("WingBlessingDay", homNay) end)
	local nBlessing = tonumber(hero.WingBlessing) or 0
	if nBlessing > 0 then
		pcall(function () G_HeroDataManager:SetHeroUpgradeWingBlessing(hero, 0) end)
		return true
	end
	return false
end

-------------------------------------------------------------------------- TIẾN CẤP

local function tienCap(ctx, nHeroID, bKimCuong)
	local nHero = tonumber(nHeroID)
	if nHero == nil then return traLoi(ctx, ErrorCode.ArgError) end
	local c = cauHinhCanh()
	if c == nil then return traLoi(ctx, ErrorCode.Common.GetConfigFaild) end

	local hero = layHero(nHero)
	if hero == nil then return traLoi(ctx, ErrorCode.Hero.NotFindHero) end

	local nWingID = tonumber(hero.WingID) or 0
	if nWingID == 0 then return traLoi(ctx, ErrorCode.Hero.NoWing) end

	local nCap = tonumber(hero.WingLevel) or 0
	if nCap >= c.capToiDa then return traLoi(ctx, ErrorCode.Hero.NoSoMuchLevelWing) end
	local muc = c.upgrade[nCap]
	if type(muc) ~= "table" then return traLoi(ctx, ErrorCode.Hero.NoSoMuchLevelWing) end

	resetChucPhuc(hero)
	local nBlessing = tonumber(hero.WingBlessing) or 0
	local tDuLieu

	if bKimCuong then
		-- Một nút: trả `CostDiamond`, CHẮC CHẮN thành công.
		local nCan = tonumber(muc.CostDiamond) or 0
		if layKimCuong() < nCan then return traLoi(ctx, ErrorCode.Common.NotEnoughDiamond) end
		local okTru, bTru = pcall(function ()
			return G_UserLogic:CostDiamond(nCan, "ClientUpgradeWingWithDiamond")
		end)
		if not okTru or bTru ~= true then return traLoi(ctx, ErrorCode.Common.NotEnoughDiamond) end
		pcall(function () G_HeroDataManager:SetHeroWingLevel(hero, nCap + 1) end)
		if nBlessing > 0 then
			pcall(function () G_HeroDataManager:SetHeroUpgradeWingBlessing(hero, 0) end)
		end
		tDuLieu = {
			HeroID = nHero, WingID = nWingID, WingLevel = nCap + 1,
			IsSuccess = true, AddBlessing = 0,
		}
	else
		local nCanDa = tonumber(muc.StoneCost) or 0
		if demTui(ID_DA_TIEN_CAP) < nCanDa then return traLoi(ctx, ErrorCode.Item.NotEnoughItem) end
		if not truTui(ID_DA_TIEN_CAP, nCanDa, "ClientUpgradeWing") then
			return traLoi(ctx, ErrorCode.Item.ReduceItemError)
		end

		local nMax = tonumber(muc.MaxBlessing) or 1
		local nTiLe = tonumber(muc.EffectivePercent) or 0
		local nCong = math.max(1, math.ceil(nMax * nTiLe / 2))

		local bThanhCong
		if nBlessing >= nMax then
			bThanhCong = true                      -- đầy thanh ⇒ CHẮC CHẮN
		else
			local p = nTiLe + (1 - nTiLe) * (nBlessing / nMax)
			bThanhCong = math.random() < p
		end

		if bThanhCong then
			pcall(function () G_HeroDataManager:SetHeroWingLevel(hero, nCap + 1) end)
			if nBlessing > 0 then
				pcall(function () G_HeroDataManager:SetHeroUpgradeWingBlessing(hero, 0) end)
			end
			tDuLieu = {
				HeroID = nHero, WingID = nWingID, WingLevel = nCap + 1,
				IsSuccess = true, AddBlessing = 0,
			}
		else
			local nMoi = nBlessing + nCong
			if nMoi > nMax then nMoi = nMax end
			pcall(function () G_HeroDataManager:SetHeroUpgradeWingBlessing(hero, nMoi) end)
			tDuLieu = {
				HeroID = nHero, WingID = nWingID, WingLevel = nCap,
				IsSuccess = false, AddBlessing = nMoi - nBlessing,
			}
		end
	end

	dongBo()
	OfflineLog:info(string.format("%s: tuong %d tien cap %d -> %d (%s, chuc phuc %s)",
		TEN_FILE, nHero, nCap, tonumber(hero.WingLevel) or 0,
		bKimCuong and "kim cuong" or (tDuLieu.IsSuccess and "thanh cong" or "that bai"),
		tostring(hero.WingBlessing)))
	traLoi(ctx, 0)
	pcall(function () G_EventManager:PostLogicEvent(tDuLieu, "OnUpgradeWing") end)
end

R:on("G_HeroLogic.ClientUpgradeWing", function (ctx, nHeroID)
	tienCap(ctx, nHeroID, false)
end)

R:on("G_HeroLogic.ClientUpgradeWingWithDiamond", function (ctx, nHeroID)
	tienCap(ctx, nHeroID, true)
end)

------------------------------------------------------------------ CƯỜNG HOÁ

local function cuongHoa(ctx, nHeroID, bTuDong)
	local nHero = tonumber(nHeroID)
	if nHero == nil then return traLoi(ctx, ErrorCode.ArgError) end
	local c = cauHinhCanh()
	if c == nil then return traLoi(ctx, ErrorCode.Common.GetConfigFaild) end

	local hero = layHero(nHero)
	if hero == nil then return traLoi(ctx, ErrorCode.Hero.NotFindHero) end
	local nWingID = tonumber(hero.WingID) or 0
	if nWingID == 0 then return traLoi(ctx, ErrorCode.Hero.NoWing) end

	local nTran = layCapNguoiChoi()
	local nCap = tonumber(hero.WingIntensifyLevel) or 0
	local nCoDa = demTui(ID_DA_CUONG_HOA)
	local nDaDung, nSoCap = 0, 0

	repeat
		if nCap >= nTran then break end
		if nCap >= c.capCuongHoa then break end
		local muc = c.intensify[tostring(nCap + 1)] or c.intensify[nCap + 1]
		if type(muc) ~= "table" then break end
		local nCan = tonumber(muc.StoneCost) or 0
		if nCoDa - nDaDung < nCan then break end
		nDaDung = nDaDung + nCan
		nCap = nCap + 1
		nSoCap = nSoCap + 1
		if not bTuDong then break end
	until false

	if nSoCap <= 0 then
		if nCap >= nTran or nCap >= c.capCuongHoa then
			return traLoi(ctx, ErrorCode.Hero.NoCountIntensifyWing)
		end
		return traLoi(ctx, ErrorCode.Item.NotEnoughItem)
	end

	if not truTui(ID_DA_CUONG_HOA, nDaDung, bTuDong and "ClientAutoIntensifyWing" or "ClientIntensifyWing") then
		return traLoi(ctx, ErrorCode.Item.ReduceItemError)
	end
	pcall(function () G_HeroDataManager:SetHeroWingIntensifyLevel(hero, nCap) end)
	dongBo()

	OfflineLog:info(string.format("%s: tuong %d cuong hoa -> cap %d (+%d cap, tru %d da)",
		TEN_FILE, nHero, nCap, nSoCap, nDaDung))
	traLoi(ctx, 0)
	pcall(function ()
		G_EventManager:PostLogicEvent(
			{ HeroID = nHero, WingID = nWingID, IntensifyLevel = nCap },
			"OnIntensifyWing")
	end)
end

R:on("G_HeroLogic.ClientIntensifyWing", function (ctx, nHeroID)
	cuongHoa(ctx, nHeroID, false)
end)

R:on("G_HeroLogic.ClientAutoIntensifyWing", function (ctx, nHeroID)
	cuongHoa(ctx, nHeroID, true)
end)

OfflineLog:info("canh: da noi 4 khoa (tien cap / kim cuong / cuong hoa / tu dong)")
