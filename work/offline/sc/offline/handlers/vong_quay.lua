--[[
	offline/handlers/vong_quay.lua — Vòng quay may mắn (转盘): SINH DANH SÁCH 12 Ô
	và QUAY.

	DỮ LIỆU GỐC (`KDBGameCommonConfig` → bảng con `GameFortuneWheelConfig`):

	  FreeWheel.Probability = {1:0.9, 2:0.1, 3:0}     — xác suất 3 BỂ
	  VipWheel.Probability  = {1:0,   2:0.6, 3:0.4}
	  "1"  = 15 mã giải (60001…60015)
	  "2"  = 8  mã (60016…60023)
	  "3"  = 5  mã (60024…60028)

	ĐIỀU BẮT BUỘC TỪ CLIENT: bánh có ĐÚNG **12 ô** — `CUIActivityTurnplate:
	initItemIcon` bỏ qua nếu `#tWheelList ~= 12` (`CUIActivityTurnplate.lua:365-368`),
	mỗi ô là `{PrizeID = <mã giải>}` (đọc ở `:372`), cờ `IsEmpty` tuỳ chọn.
	UI lấy danh sách từ `userTurnplate.FreeWheelList` / `VipWheelList`.

	LUẬT SINH DANH SÁCH KHÔNG ĐƯỢC SHIP (server gốc giữ), nên đây là chỗ SUY, ghi rõ:
	  * mỗi bể chiếm số ô TỈ LỆ với xác suất của nó (làm tròn), phần dư dồn về bể 1:
	    Free 0,9 : 0,1 : 0 ⇒ **11 ô bể 1 + 1 ô bể 2**; Vip 0,6 : 0,4 ⇒ **7 ô bể 2 +
	    5 ô bể 3** (đúng 12);
	  * trong mỗi bể bốc ĐỀU, CÓ LẶP (bể chỉ có 15/8/5 mã nên 12 ô không thể khác);
	  * khi quay: chọn BỂ theo đúng xác suất cấu hình, rồi chọn một ô thuộc bể ấy
	    (đều). Nhờ vậy tỉ lệ trúng khớp cấu hình mà không cần thêm luật nào.

	PHẦN ĐÃ CÓ LUẬT GỐC (chỉ gọi): `FortuneWheelLogic:FreeRoll()` (kiểm lượt + hồi
	chiêu + đếm), `:VipRoll()` (kiểm VIP `FortuneWheelLevel`, trừ kim cương theo
	`GetVipRollDiamond`), `:SetFreeWheelList`, `:SetVipWheelList`.

	Lưu ý: `FreeRoll`/`VipRoll` KHÔNG chọn giải — chúng chỉ lo điều kiện và bộ đếm;
	phần chọn giải là của server ⇒ ở đây.

	Còn thiếu (không bịa): `ClientRunNewServerDailyWheel` và
	`ClientGetNewServerDailyWheelPrizeList` — bánh "tân thủ 7 ngày" dùng
	`NewServerDailyWheel` + `DayMaxIndexList`, khác hẳn bánh này.
]]

require("offline.log")
require("offline.store")
require("offline.router")

local R = OfflineRouter

local SO_O = 12     -- client đòi đúng 12 (`CUIActivityTurnplate.lua:366`)

local function cauHinh()
	local ok, v = pcall(function ()
		return G_ConfigManager:GetCommonConfigWithName("GameFortuneWheelConfig")
	end)
	if ok and type(v) == "table" then
		return v
	end
	return nil
end

local function danhSachBe(cau, be)
	local ds = cau[tostring(be)]
	return (type(ds) == "table") and ds or {}
end

-- Gọi luật gốc qua proxy lớp cha (ClientFortuneWheelLogic = class(FortuneWheelLogic)).
local function chayLuat(ten, ...)
	local o = G_FortuneWheelLogic
	local c = rawget(_G, "FortuneWheelLogic")
	local self = (type(c) == "table" and o[c]) or o
	local fn = self[ten]
	if type(fn) ~= "function" then
		return false, 1
	end
	local args = { n = select("#", ...), ... }
	local ok, bRet, ma = pcall(function ()
		return fn(self, unpack(args, 1, args.n))
	end)
	if not ok then
		OfflineLog:warn(string.format("VongQuay:%s loi: %s", ten, tostring(bRet)))
		return false, 1
	end
	return bRet == true, tonumber(ma)
end

--[[ Sinh 12 ô cho một bánh. Số ô mỗi bể theo tỉ lệ xác suất; phần dư dồn bể 1. ]]
local function sinhBanh(cau, tenBanh)
	local bang = cau[tenBanh]
	local xac = (type(bang) == "table") and bang.Probability or {}
	local soO, tong = {}, 0
	for be = 1, 3 do
		local p = tonumber(xac[tostring(be)]) or tonumber(xac[be]) or 0
		soO[be] = math.floor(p * SO_O + 0.5)
		tong = tong + soO[be]
	end
	soO[1] = soO[1] + (SO_O - tong)

	local banh = {}
	for be = 1, 3 do
		local dsBe = danhSachBe(cau, be)
		local soLan = soO[be] or 0
		if soLan > 0 and #dsBe == 0 then
			-- bể rỗng mà vẫn có xác suất: mượn bể 1
			dsBe = danhSachBe(cau, 1)
		end
		for _ = 1, soLan do
			if #dsBe > 0 then
				local id = dsBe[math.random(#dsBe)]
				banh[#banh + 1] = { PrizeID = tonumber(id) }
			end
		end
	end

	-- Bù cho đủ 12 nếu có bể thiếu dữ liệu.
	while #banh < SO_O do
		local dsBe = danhSachBe(cau, 1)
		if #dsBe == 0 then break end
		banh[#banh + 1] = { PrizeID = tonumber(dsBe[math.random(#dsBe)]) }
	end
	return banh
end

local function beCuaGiai(cau, prizeID)
	for be = 1, 3 do
		for _, id in ipairs(danhSachBe(cau, be)) do
			if tonumber(id) == tonumber(prizeID) then
				return be
			end
		end
	end
	return nil
end

-- Chọn bể theo xác suất cấu hình, rồi một ô thuộc bể ấy.
local function chonO(cau, tenBanh, banh)
	local bang = cau[tenBanh]
	local xac = (type(bang) == "table") and bang.Probability or {}
	local tong = 0
	for be = 1, 3 do
		tong = tong + (tonumber(xac[tostring(be)]) or tonumber(xac[be]) or 0)
	end

	local be = nil
	if tong > 0 then
		local r = math.random() * tong
		for k = 1, 3 do
			r = r - (tonumber(xac[tostring(k)]) or tonumber(xac[k]) or 0)
			if r <= 0 then be = k; break end
		end
	end

	local ung = {}
	for i, o in ipairs(banh) do
		if be == nil or beCuaGiai(cau, o.PrizeID) == be then
			ung[#ung + 1] = i
		end
	end
	if #ung == 0 then
		return math.random(#banh)
	end
	return ung[math.random(#ung)]
end

local function layBanh()
	local ok, u = pcall(function ()
		local _, t = G_FortuneWheelLogic:GetUserFortuneWheel()
		return t
	end)
	if ok then return u end
	return nil
end

local function phatThuong(prizeID)
	if prizeID == nil then return false end
	local ok, bRet = pcall(function ()
		return G_PrizeLogic:ReceivePrizeWithID(prizeID, nil, "FortuneWheel")
	end)
	return ok and bRet ~= false
end

----------------------------------------------------------------- làm mới bánh

--[[ Server sinh lại danh sách rồi báo client. UI đăng ký đúng sự kiện
	`FortuneWheel.OnRefreshFortuneWheelList` (`CUIActivityTurnplate.lua:57`); chuỗi
	này KHÔNG có hàm nhận dạng `OnServer...` nên phải phát tay. ]]
R:on("G_FortuneWheelLogic.ClientRefreshFortuneWheelList", function(ctx)
	local cau = cauHinh()
	local nErr = 0
	if cau == nil then
		nErr = 1
	else
		local banhThuong = sinhBanh(cau, "FreeWheel")
		local banhVip = sinhBanh(cau, "VipWheel")
		pcall(function () G_FortuneWheelLogic:SetFreeWheelList(banhThuong) end)
		pcall(function () G_FortuneWheelLogic:SetVipWheelList(banhVip) end)
		pcall(function () OfflineStore:syncFromClient() end)
		OfflineLog:info(string.format("vong quay: sinh 2 banh %d/%d o",
			#banhThuong, #banhVip))
		pcall(function ()
			G_EventManager:PostLogicEvent(nil,
				EventManagerLogicEvent.FortuneWheel.OnRefreshFortuneWheelList)
		end)
	end
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", nErr, {})
end)

--------------------------------------------------------------------- quay

local function quay(ctx, bVip)
	local cau = cauHinh()
	if cau == nil then
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", 1, {})
		return
	end

	local u = layBanh()
	local tenBanh = bVip and "VipWheel" or "FreeWheel"
	local banh = u and (bVip and u.VipWheelList or u.FreeWheelList)

	-- 1) luật gốc: kiểm lượt / VIP / trừ kim cương / đếm
	local bOk, maLoi = chayLuat(bVip and "VipRoll" or "FreeRoll")
	if not bOk then
		OfflineLog:info(string.format("vong quay %s: luat goc tu choi, ma %s",
			tenBanh, tostring(maLoi)))
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", maLoi or 1, {})
		return
	end

	-- 2) bánh rỗng (chưa làm mới lần nào) ⇒ sinh tại chỗ
	if type(banh) ~= "table" or #banh ~= SO_O then
		banh = sinhBanh(cau, tenBanh)
		pcall(function ()
			if bVip then
				G_FortuneWheelLogic:SetVipWheelList(banh)
			else
				G_FortuneWheelLogic:SetFreeWheelList(banh)
			end
		end)
	end

	-- 3) chọn ô + phát thưởng
	local idx = chonO(cau, tenBanh, banh)
	local prizeID = banh[idx] and tonumber(banh[idx].PrizeID)
	local daPhat = phatThuong(prizeID)

	pcall(function () OfflineStore:syncFromClient() end)
	OfflineLog:info(string.format("vong quay %s: o %d, giai %s -> %s",
		tenBanh, idx, tostring(prizeID), tostring(daPhat)))

	-- 4) báo UI (đúng dạng nó chờ)
	pcall(function ()
		if bVip then
			G_EventManager:PostLogicEvent({ Index = idx },
				EventManagerLogicEvent.FortuneWheel.OnVipRoll)
		else
			G_EventManager:PostLogicEvent(idx,
				EventManagerLogicEvent.FortuneWheel.OnFreeRoll)
		end
	end)
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", 0, {})
end

R:on("G_FortuneWheelLogic.ClientFreeRoll", function(ctx) quay(ctx, false) end)
R:on("G_FortuneWheelLogic.ClientVipRoll", function(ctx) quay(ctx, true) end)

------------------------------------------------ BÁNH "TÂN THỦ 7 NGÀY" (新手转盘)

--[[ Hai lệnh này LUẬT GỐC ĐÃ CÓ SẴN trong `FortuneWheelLogic` — chỉ thiếu phía
	máy chủ sinh SỐ NGẪU NHIÊN:

	  * `getNewServerDailyWheelPrizeListConfig()` → `(ok, NewServerDailyWheel,
	    PrizeList)`: `PrizeID 91234` trong `GameFortuneWheelConfig`, giải nằm ở
	    `PrizeContent` của prize ấy.
	  * `getNewServerDailyWheelPrizeList(tRandList)` — xáo danh sách giải bằng
	    chính các số ngẫu nhiên máy chủ gửi (Fisher-Yates), trả bản ĐÃ XÁO.
	  * `runNewServerDailyWheelWithRand(nRand)` — chọn ô theo `DayMaxIndexList`
	    `[4,4,4,4,6,6,7]` của ngày hiện tại, đánh dấu ô đã trúng, CẤP THƯỞNG bằng
	    `SetDataWithPrizeList`, tăng `TimesCount`, rồi TỰ phát
	    `FortuneWheel.NewServerDailyWheelWithRand`; trả `(ok, err, nGetIndex)`.

	⇒ Ở đây chỉ sinh `math.random()` rồi gọi luật.

	⚠ Điều kiện của bản gốc: `checkIsCanRunNewServerDailyWheel` đòi
	`G_AchieveLogic:GetSevenDayLeftDay() > 0` và `NewServerDailyWheelCount == 0`
	(mỗi ngày một lượt) — tức bánh này CHỈ sống trong 7 ngày tân thủ. Save thử
	sau ngày thứ 7 sẽ bị từ chối mã `CanNotRunNewServerDailyWheel`: đúng luật. ]]

local function chayLuatTho(ten, ...)
	local o = G_FortuneWheelLogic
	local c = rawget(_G, "FortuneWheelLogic")
	local self = (type(c) == "table" and o[c]) or o
	local fn = self[ten]
	if type(fn) ~= "function" then
		return false, "khong co luat " .. ten
	end
	local args = { n = select("#", ...), ... }
	local ok, r1, r2, r3 = xpcall(function ()
		return fn(self, unpack(args, 1, args.n))
	end, function (e)
		return tostring(e) .. (debug and debug.traceback and ("\n" .. tostring(debug.traceback())) or "")
	end)
	return ok, r1, r2, r3
end

R:on("G_FortuneWheelLogic.ClientGetNewServerDailyWheelPrizeList", function(ctx)
	local okCfg, _, _, prizeList = chayLuatTho("getNewServerDailyWheelPrizeListConfig")
	local tRand = {}
	if okCfg and type(prizeList) == "table" and #prizeList > 0 then
		for i = 1, #prizeList do
			tRand[i] = math.random()
		end
	else
		OfflineLog:warn("vong quay tan thu: khong doc duoc danh sach giai (prize 91234)")
	end

	local ok, _, _, daXao = chayLuatTho("getNewServerDailyWheelPrizeList", tRand)
	if not ok then
		OfflineLog:warn("vong quay tan thu: luat xao danh sach loi: " .. tostring(daXao))
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", 1, {})
		return
	end

	OfflineLog:info(string.format("vong quay tan thu: danh sach %d giai",
		type(daXao) == "table" and #daXao or -1))
	pcall(function () OfflineStore:syncFromClient() end)
	ctx:call("G_FortuneWheelLogic", "OnServerGetNewServerDailyWheelPrizeList",
		{ tRandList = tRand, tOutOfOrderPrizeList = daXao or {} })
end)

R:on("G_FortuneWheelLogic.ClientRunNewServerDailyWheel", function(ctx)
	local nRand = math.random()
	local ok, bRet, ma, nGetIndex = chayLuatTho("runNewServerDailyWheelWithRand", nRand)
	if ok and bRet == true then
		pcall(function () OfflineStore:syncFromClient() end)
		OfflineLog:info(string.format("vong quay tan thu: trung o %s", tostring(nGetIndex)))
		ctx:call("G_FortuneWheelLogic", "OnServerRunNewServerDailyWheel",
			{ nRand = nRand, nGetIndex = nGetIndex })
	else
		OfflineLog:info(string.format(
			"vong quay tan thu: luat goc tu choi (ngoai 7 ngay tan thu / da quay hom nay), ma %s",
			tostring(ma)))
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", tonumber(ma) or 1, {})
	end
end)

return true
