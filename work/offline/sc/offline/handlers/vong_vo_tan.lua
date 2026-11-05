--[[
	offline/handlers/vong_vo_tan.lua — ẢI VÔ TẬN (无限关 / EndlessChapter), 9 KHOÁ.

	`handlers/endless.lua` (28/10) đã đăng ký 9 khoá này bằng `chua_lam(...)` — chỉ
	dọn lớp "đang tải" và ghi log "nửa máy chủ không ship". Lượt này dựng LẠI bằng
	các hằng số + hàm ĐỌC CÓ THẬT của `share/EndlessChapterLogic.lua`:

	  · bảng trạng thái `GameUserEndlessChapter` và default của nó
	    (`GetUserEndlessChapterData`/`craeteUserEndlessChapter`),
	  · cổng vào `IsCanFight` (2 lượt miễn phí + tối đa 7; `PayChallengesCost = 50`),
	  · giá/ảnh hưởng CHÚC PHÚC (`InspireCost = {Gold=2000, Diamond=50}`,
	    `InspireEffect = {AP=20, HP=20}`, tối đa 3),
	  · bộ xét điều kiện qua ải `IsCompeleteData(tData, PassCondition, PassConditionArgs)`
	    (7 điều kiện, args nằm trong `GameEndlessChapterConfig`),
	  · thưởng mỗi tầng = **`GameEndlessChapterConfig[LevelID].PrizeID`** (107001…, 250 tầng),
	  · quét: `SwapCostTime = 60` giây/tầng, `SwapCostDiamondPerFloor = 2` kim cương,
	    `GetSwapCount`/`GetLeftSwapCount`/`GetSweepImmediatelyCost`.

	[GHIM] — ba chỗ chỉ suy ra từ hằng số/bộ đọc, ghi rõ:
	1. `ClientFight`: tăng `ChallengesCount` 1 mỗi lượt (miễn phí 2 lượt đầu, sau đó
	   dùng `PayChallengesCount` đã mua) — đúng điều kiện `IsCanFight`.
	2. `ClientResetEndlessChapter`: đặt lại về tầng 1, **1 lần/ngày** (`MaxResetCount = 1`),
	   lưu khoá ngày riêng `ResetDay` [MOI]; `BestProsees` GIỮ nguyên.
	3. `ClientSwapImmediately`: giá = số tầng còn lại × 2 kim cương
	   (`GetSweepImmediatelyCost`); quét xong nhảy tới `BestProsees + 1`.

	⚠ HÌNH GỌI: `OnFight(heroIdList, nInspireCount, tEmployHero)` BA tham số;
	`OnStopSwap(tPrizeList)` nhận MẢNG các `PrizeContent`; hai khoá `ClientSwapImmediately`
	và `ClientBuyChallengesCount` KHÔNG có hàm nhận ⇒ dọn lớp tải bằng
	`g_CUIGameRPCManager:OnReciveResponse("", "", 0, {})`.
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflineVongVoTan = OfflineVongVoTan or {}

local R = OfflineRouter
local TEN_FILE = "vong vo tan"
local MOC_NGAY = 5

------------------------------------------------------------------- tiện ích

local function goi(ctx, hamNhan, ...)
	local a = { n = select("#", ...), ... }
	local ok, e = pcall(function ()
		return ctx:call("G_EndlessChapterLogic", hamNhan, unpack(a, 1, a.n))
	end)
	if not ok then
		OfflineLog:err(string.format("%s: khong goi duoc %s -> %s", TEN_FILE,
			tostring(hamNhan), tostring(e)))
	end
end

local function donLop(ctx)
	pcall(function ()
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", 0, {})
	end)
end

local function baoLoi(ctx, nMa, lyDo)
	OfflineLog:info(string.format("%s: tu choi -> ma %d (%s)", TEN_FILE, nMa, lyDo or ""))
	pcall(function ()
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", nMa, {})
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

local function duLieu()
	local ok, b, d = pcall(function ()
		return G_EndlessChapterLogic:GetUserEndlessChapterData()
	end)
	if ok and b ~= false and type(d) == "table" then return d end
	return nil
end

local function luu(d)
	local ok, r = pcall(function ()
		return G_EndlessChapterLogic:setUserEndlessChapter(d)
	end)
	if not ok or r == false then
		OfflineLog:err(TEN_FILE .. ": khong luu duoc GameUserEndlessChapter")
	end
	dongBo()
end

local function cauHinhCap(cap)
	local ok, cfg = pcall(function ()
		return G_ConfigManager:GetEndlessChapterConfig(tonumber(cap) or 0)
	end)
	if ok and type(cfg) == "table" then return cfg end
	return nil
end

local function khoaNgay()
	local now = os.time()
	local t = os.date("*t", now)
	if t.hour < MOC_NGAY then now = now - 86400 end
	local d = os.date("*t", now)
	return d.year * 10000 + d.month * 100 + d.day
end

local function hangSo(ten, macDinh)
	local v = G_EndlessChapterLogic and G_EndlessChapterLogic[ten]
	if tonumber(v) then return tonumber(v) end
	return macDinh
end

-- Nội dung của một PrizeID. `GetPrizeWithID` trả `(bResult, prize)` ⇒ pcall BA giá trị.
local function noiDungPrize(nPrizeID)
	local ok, b, prize = pcall(function ()
		return G_PrizeLogic:GetPrizeWithID(tonumber(nPrizeID) or 0)
	end)
	if ok and b ~= false and type(prize) == "table" and type(prize.PrizeContent) == "table" then
		return prize.PrizeContent
	end
	return nil
end

local function phatPrizeList(ds, from)
	if type(ds) ~= "table" or #ds == 0 then return false end
	local ok, r = pcall(function ()
		return G_ChapterLogic:SetDataWithPrizeList(ds, 1, from or "EndlessChapter")
	end)
	return ok and r ~= false
end

------------------------------------------------------------------- 1. VÀO TRẬN
--[[ `OnFight(heroIdList, nInspireCount, tEmployHero)` — client tự dựng trận từ hai
	tham số đầu. Cổng vào dùng NGUYÊN `IsCanFight` (share trả `(bResult, errCode)`). ]]
R:on("G_EndlessChapterLogic.ClientFight", function (ctx, heroIdList, tEmployHero)
	local d = duLieu()
	if d == nil then return baoLoi(ctx, 1, "khong doc duoc du lieu ai vo tan") end

	local ok, coThe, maLoi = pcall(function ()
		return G_EndlessChapterLogic:IsCanFight()
	end)
	if not ok or coThe ~= true then
		return baoLoi(ctx, tonumber(maLoi) or 1, "IsCanFight tu choi")
	end

	if type(heroIdList) == "table" then d.FightHeroList = heroIdList end
	d.ChallengesCount = (tonumber(d.ChallengesCount) or 0) + 1
	luu(d)
	OfflineLog:info(string.format("%s: vao tran tang %d — luot %s/%s", TEN_FILE,
		tonumber(d.CurrentProsess) or 1, tostring(d.ChallengesCount),
		tostring(hangSo("MaxChallengesCount", 7))))
	goi(ctx, "OnFight", d.FightHeroList or {}, tonumber(d.InspireCount) or 0, tEmployHero)
	donLop(ctx)
end)

------------------------------------------------------------------- 2. KẾT THÚC TRẬN
--[[ Xét điều kiện qua ải bằng `IsCompeleteData` (7 điều kiện có thật); thưởng =
	`GameEndlessChapterConfig[CurrentProsess].PrizeID`. Kết quả gửi qua SỰ KIỆN
	`OnCompeleteFight` — `CUIEndlessFinish` đọc `IsWin` và `PrizeID`. ]]
R:on("G_EndlessChapterLogic.ClientCompeleteFight", function (ctx, tCompeleteData)
	local d = duLieu()
	if d == nil then return baoLoi(ctx, 1, "khong doc duoc du lieu") end
	local cap = tonumber(d.CurrentProsess) or 1
	local cfg = cauHinhCap(cap)
	if cfg == nil then return baoLoi(ctx, 1, "khong co cau hinh tang " .. tostring(cap)) end

	local ok, bOk, thang = pcall(function ()
		return G_EndlessChapterLogic:IsCompeleteData(tCompeleteData or {},
			tonumber(cfg.PassCondition) or 0, cfg.PassConditionArgs)
	end)
	local isWin = ok and bOk ~= false and thang == true

	local nPrizeID = tonumber(cfg.PrizeID) or 0
	if isWin then
		local noiDung = noiDungPrize(nPrizeID)
		if noiDung ~= nil then phatPrizeList(noiDung, "EndlessChapter") end
		d.CurrentState = 1                       -- ProsessState.HasWin
		if cap > (tonumber(d.BestProsees) or 0) then d.BestProsees = cap end
		luu(d)
		OfflineLog:info(string.format("%s: qua tang %d (thuong %d)", TEN_FILE, cap, nPrizeID))
	else
		luu(d)
		OfflineLog:info(string.format("%s: thua tang %d", TEN_FILE, cap))
	end

	pcall(function ()
		G_EventManager:PostLogicEvent({ IsWin = isWin, PrizeID = isWin and nPrizeID or 0 },
			EventManagerLogicEvent.EndlessChapter.OnCompeleteFight)
	end)
	donLop(ctx)
end)

------------------------------------------------------------------- 3. SANG TẦNG KẾ
--[[ `CallGotoNextProsees` KHÔNG phát lớp "đang tải" ⇒ chỉ cần đổi trạng thái và
	phát sự kiện `OnGotoNextProsess` để màn chính vẽ lại. ]]
R:on("G_EndlessChapterLogic.ClientGotoNextProsees", function (ctx)
	local d = duLieu()
	if d == nil then return donLop(ctx) end
	if (tonumber(d.CurrentState) or 0) ~= 1 then
		OfflineLog:warn(TEN_FILE .. ": chua thang tang nay — khong sang tang")
		return donLop(ctx)
	end
	local capCu = tonumber(d.CurrentProsess) or 1
	d.CurrentProsess = capCu + 1
	d.CurrentState = 0
	d.ChallengesCount = 0
	d.InspireCount = 0
	luu(d)
	OfflineLog:info(string.format("%s: sang tang %d", TEN_FILE, d.CurrentProsess))
	pcall(function ()
		G_EventManager:PostLogicEvent(nil, EventManagerLogicEvent.EndlessChapter.OnGotoNextProsess)
	end)
	donLop(ctx)
end)

------------------------------------------------------------------- 4. CHÚC PHÚC (inspire)
R:on("G_EndlessChapterLogic.ClientInspire", function (ctx, nResourceType)
	local d = duLieu()
	if d == nil then return baoLoi(ctx, 1, "khong doc duoc du lieu") end
	local daDung = tonumber(d.InspireCount) or 0
	local toiDa = hangSo("MaxInspireCount", 3)
	local loai = tonumber(nResourceType) or 0
	local gia = nil
	pcall(function ()
		local bang = G_EndlessChapterLogic and G_EndlessChapterLogic.InspireCost
		if type(bang) == "table" then gia = tonumber(bang[loai]) end
	end)

	local thanhCong = false
	if daDung < toiDa and gia ~= nil and gia > 0 then
		local okTru, daTru
		if loai == 1 then               -- ResourceType.Gold
			okTru, daTru = pcall(function () return G_UserLogic:CostGold(gia, "EndlessInspire") end)
		elseif loai == 20 then          -- ResourceType.Diamond
			okTru, daTru = pcall(function () return G_UserLogic:CostDiamond(gia, "EndlessInspire") end)
		end
		thanhCong = okTru == true and daTru == true
		if thanhCong then
			d.InspireCount = daDung + 1
			luu(d)
			OfflineLog:info(string.format("%s: chuc phuc lan %d (-%d loai %d)", TEN_FILE,
				d.InspireCount, gia, loai))
		else
			thongBao(loai == 1 and 500 or 504)
		end
	elseif daDung >= toiDa then
		OfflineLog:info(TEN_FILE .. ": da chuc phuc toi da " .. tostring(toiDa) .. " lan")
	end
	pcall(function ()
		G_EventManager:PostLogicEvent(thanhCong, EventManagerLogicEvent.EndlessChapter.OnInspire)
	end)
	donLop(ctx)
end)

------------------------------------------------------------------- 5. ĐẶT LẠI
R:on("G_EndlessChapterLogic.ClientResetEndlessChapter", function (ctx)
	local d = duLieu()
	if d == nil then return baoLoi(ctx, 1, "khong doc duoc du lieu") end
	local hom = khoaNgay()
	if tonumber(d.ResetDay) == hom then
		OfflineLog:info(TEN_FILE .. ": hom nay da dat lai roi")
		donLop(ctx)
		return
	end
	d.ResetDay = hom
	d.ResetCount = (tonumber(d.ResetCount) or 0) + 1
	d.CurrentProsess = 1
	d.CurrentState = 0
	d.ChallengesCount = 0
	d.InspireCount = 0
	d.IsSweeping = false
	d.SwapBeginTime = 0
	luu(d)
	OfflineLog:info(TEN_FILE .. ": dat lai ve tang 1 (Best giu nguyen "
		.. tostring(d.BestProsees) .. ")")
	pcall(function ()
		G_EventManager:PostLogicEvent(nil, EventManagerLogicEvent.EndlessChapter.OnResetEndlessChapter)
	end)
	donLop(ctx)
end)

------------------------------------------------------------------- 6. MUA LƯỢT ĐÁNH
R:on("G_EndlessChapterLogic.ClientBuyChallengesCount", function (ctx)
	local d = duLieu()
	if d == nil then return baoLoi(ctx, 1, "khong doc duoc du lieu") end
	local toiDaPay = hangSo("MaxChallengesCount", 7) - hangSo("FreeChallengesCount", 2)
	local daMua = tonumber(d.PayChallengesCount) or 0
	if daMua >= toiDaPay then
		OfflineLog:info(TEN_FILE .. ": da mua du " .. tostring(toiDaPay) .. " luot tra tien")
		return donLop(ctx)
	end
	local gia = hangSo("PayChallengesCost", 50)
	local okTru, daTru = pcall(function () return G_UserLogic:CostDiamond(gia, "EndlessBuyChallenges") end)
	if not okTru or daTru ~= true then
		thongBao(504)
		return donLop(ctx)
	end
	d.PayChallengesCount = daMua + 1
	luu(d)
	OfflineLog:info(string.format("%s: mua luot danh %d (-%d kim cuong)", TEN_FILE,
		d.PayChallengesCount, gia))
	pcall(function ()
		G_EventManager:PostLogicEvent(d.PayChallengesCount,
			EventManagerLogicEvent.EndlessChapter.OnBuyChallengesCount)
	end)
	donLop(ctx)
end)

------------------------------------------------------------------- 7. QUÉT
--[[ Quét chạy THEO THỜI GIAN: 60 giây một tầng (`SwapCostTime`). Mỗi tầng đã quét
	được trao `GameEndlessChapterConfig[tầng].PrizeID`. ]]
local function thuHoachQuet(d, nSoTang)
	local ds = {}
	local nReward = 0
	if nSoTang <= 0 then return ds, nReward end
	local bat = tonumber(d.CurrentProsess) or 1
	for i = 0, nSoTang - 1 do
		local cfg = cauHinhCap(bat + i)
		if cfg ~= nil then
			local noiDung = noiDungPrize(cfg.PrizeID)
			if noiDung ~= nil then
				pcall(function () G_ChapterLogic:SetDataWithPrizeList(noiDung, 1, "EndlessSweep") end)
				ds[#ds + 1] = noiDung
				nReward = nReward + 1
			end
		end
	end
	d.CurrentProsess = bat + nSoTang
	d.CurrentState = 0
	d.ChallengesCount = 0
	d.InspireCount = 0
	d.IsSweeping = false
	d.SwapBeginTime = 0
	return ds, nReward
end

R:on("G_EndlessChapterLogic.ClientSwap", function (ctx)
	local d = duLieu()
	if d == nil then return baoLoi(ctx, 1, "khong doc duoc du lieu") end
	local cap = tonumber(d.CurrentProsess) or 1
	local best = tonumber(d.BestProsees) or 0
	if best < cap then
		return baoLoi(ctx, 1, "khong co tang nao de quet")
	end
	d.SwapBeginTime = os.time()
	d.IsSweeping = true
	luu(d)
	OfflineLog:info(string.format("%s: bat dau quet tu tang %d (toi %d)", TEN_FILE, cap, best))
	goi(ctx, "OnSwap")
	donLop(ctx)
end)

local function dungQuet(ctx)
	local d = duLieu()
	if d == nil then return baoLoi(ctx, 1, "khong doc duoc du lieu") end
	if (tonumber(d.SwapBeginTime) or 0) == 0 then
		OfflineLog:info(TEN_FILE .. ": khong co phien quet nao")
		return donLop(ctx)
	end
	local giay = math.max(0, os.time() - (tonumber(d.SwapBeginTime) or 0))
	local soTang = math.floor(giay / hangSo("SwapCostTime", 60))
	local cap = tonumber(d.CurrentProsess) or 1
	local best = tonumber(d.BestProsees) or 0
	local conLai = math.max(0, best - cap + 1)
	if soTang > conLai then soTang = conLai end
	local ds, n = thuHoachQuet(d, soTang)
	luu(d)
	OfflineLog:info(string.format("%s: dung quet — %d tang, %d mon thuong", TEN_FILE, soTang, n))
	goi(ctx, "OnStopSwap", ds)
	donLop(ctx)
end

R:on("G_EndlessChapterLogic.ClientStopSwap", function (ctx)
	dungQuet(ctx)
end)

--[[ Quét NGAY: giá = số tầng còn lại × 2 kim cương (`GetSweepImmediatelyCost`). ]]
R:on("G_EndlessChapterLogic.ClientSwapImmediately", function (ctx)
	local d = duLieu()
	if d == nil then return baoLoi(ctx, 1, "khong doc duoc du lieu") end
	local cap = tonumber(d.CurrentProsess) or 1
	local best = tonumber(d.BestProsees) or 0
	local soTang = math.max(0, best - cap + 1)
	if soTang <= 0 then
		OfflineLog:info(TEN_FILE .. ": khong co tang nao de quet ngay")
		return donLop(ctx)
	end
	local gia = soTang * hangSo("SwapCostDiamondPerFloor", 2)
	local okTru, daTru = pcall(function () return G_UserLogic:CostDiamond(gia, "EndlessSweepNow") end)
	if not okTru or daTru ~= true then
		thongBao(504)
		return donLop(ctx)
	end
	local ds, n = thuHoachQuet(d, soTang)
	luu(d)
	OfflineLog:info(string.format("%s: quet ngay %d tang (-%d kim cuong), %d mon", TEN_FILE,
		soTang, gia, n))
	pcall(function ()
		G_EventManager:PostLogicEvent(ds, EventManagerLogicEvent.EndlessChapter.OnSweepImmediately)
	end)
	goi(ctx, "OnStopSwap", ds)
	donLop(ctx)
end)

OfflineLog:info("vong vo tan: da noi 9 khoa (vao tran/ket thuc/sang tang/chuc phuc/dat lai/mua luot/quet)")

return true
