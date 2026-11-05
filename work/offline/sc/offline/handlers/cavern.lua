--[[
	offline/handlers/cavern.lua — Ma Khu (魔窟 / hang): đánh từng tầng, nhận
	thưởng, mua đồ, đặt lại.

	Client gọi CallServer("G_CavernLogic", "ClientX", ...) rồi CHỜ; server chạy
	luật rồi phát sự kiện `EventManagerLogicEvent.Cavern.*` để CUICavern cập
	nhật. Luật NẰM SẴN trong sc/share/CavernLogic.lua (như ChapterLogic), nên
	handler chỉ GỌI luật gốc rồi đồng bộ kho — KHÔNG bịa số.

	Một số luật TỰ PHÁT sự kiện của nó (CompeleteFight:159, GetReward:367,
	Revive:482, BuyCavernGoods:791) — handler chỉ cần gọi + đồng bộ. Hai luật
	KHÔNG tự phát (CompeleteProgress, ResetCavern) thì handler phát hộ đúng sự
	kiện CUICavern đăng ký (CUICavern.lua:145,148). Đối chiếu bằng chính danh
	sách Reg của CUICavern.
]]

require("offline.log")
require("offline.store")
require("offline.router")

local R = OfflineRouter

-- Gọi một luật của G_CavernLogic rồi đồng bộ kho. Trả kết quả luật.
local function chay(ten, ...)
	if G_CavernLogic == nil or type(G_CavernLogic[ten]) ~= "function" then
		OfflineLog:err("Cavern: khong co luat " .. tostring(ten))
		return false
	end
	local ok = G_CavernLogic[ten](G_CavernLogic, ...)
	OfflineStore:syncFromClient()
	return ok
end

-- Đánh xong một tầng: submit kết quả. CompeleteFight TỰ phát OnCompeleteFight.
R:on("G_CavernLogic.ClientCompeleteFight", function(ctx, bFightResult, fightHeroStateMap,
		defenderState, tEmployHero, tEmployHeroState)
	chay("CompeleteFight", bFightResult, fightHeroStateMap, defenderState,
		tEmployHero, tEmployHeroState)
end)

-- Lên tầng kế. Luật KHÔNG tự phát -> phát Cavern.OnCompeleteProgress
-- (CUICavern:148 nghe, hàm không cần dữ liệu).
R:on("ClientCompeleteProgress", function(ctx)
	chay("CompeleteProgress")
	G_EventManager:PostLogicEvent(nil, EventManagerLogicEvent.Cavern.OnCompeleteProgress)
end)

-- Nhận rương thưởng. GetReward TỰ phát OnGetReward + OnReceivePrize.
R:on("ClientCavernGetReward", function(ctx, nIndex)
	chay("GetReward", nIndex)
end)

-- Đặt lại Ma Khu. Luật KHÔNG tự phát -> phát Cavern.ResetCavern (CUICavern:145).
R:on("ClientResetCavern", function(ctx)
	chay("ResetCavern")
	G_EventManager:PostLogicEvent(nil, EventManagerLogicEvent.Cavern.ResetCavern)
end)

-- Hồi sinh. Revive TỰ phát OnCavernRevive.
R:on("ClientRevive", function(ctx)
	chay("Revive")
end)

-- Cửa hàng Ma Khu: mua đồ. BuyCavernGoods TỰ phát OnBuyCavernGoods.
R:on("ClientBuyCavernGoods", function(ctx, goodsIndex)
	chay("BuyCavernGoods", goodsIndex)
end)

--[[ LÀM MỚI HÀNG CỬA HÀNG MA KHU — luật SINH danh sách không nằm trong
	`CavernLogic` (chỉ có `BuyCavernGoods` đọc `userCavern.GoodsList`), nhưng DỮ
	LIỆU thì có: `GameCavernGoodsCreateConfig` = 13 NHÓM `{Range, GoodsList}`
	và `GameCavernGoodsConfig` = 36 món `{UnitPrice, CurrencyType 3 = tiền Ma
	Khu, PrizeID, MinGoodsCount, MaxGoodsCount}`.

	ĐẶT (chưa đối chiếu được luật server): mỗi nhóm bốc `Range` mã KHÔNG LẶP;
	`Count` hiển thị = ngẫu nhiên trong [MinGoodsCount, MaxGoodsCount] — chỗ
	MUA dùng thẳng `MinGoodsCount` của cấu hình (`BuyCavernGoods`: `cost =
	UnitPrice * MinGoodsCount`), nên `Count` chỉ để vẽ.

	Hai đường: MIỄN PHÍ (`ClientRefreshGoodsList`) và TRẢ TIỀN
	(`ClientRefreshGoodsWithCurrency`, giá = `CavernLogic:GetRefreshCurrency`
	10/50/100/+50 — chính hàm gốc). Client không có hàm On... riêng cho hai lệnh
	này ⇒ trả đường phản hồi chung; UI đọc lại dữ liệu đã đổi. ]]
local function sinhHangMaKhu()
	local crate = G_ConfigManager:GetCommonConfigWithName("GameCavernGoodsCreateConfig")
	local hang = G_ConfigManager:GetCommonConfigWithName("GameCavernGoodsConfig")
	if type(crate) ~= "table" or type(hang) ~= "table" then
		return nil
	end
	local ds, daCo = {}, {}
	for _, nhom in ipairs(crate) do
		local canBoc = tonumber(nhom.Range) or 1
		local nguon = nhom.GoodsList
		if type(nguon) == "table" then
			local con = {}
			for i = 1, #nguon do con[i] = nguon[i] end
			for i = #con, 2, -1 do
				local j = math.random(i)
				con[i], con[j] = con[j], con[i]
			end
			local daLay = 0
			for _, id in ipairs(con) do
				if daLay >= canBoc then break end
				if not daCo[id] then
					local g = hang[tostring(id)]
					if type(g) == "table" then
						local minC = tonumber(g.MinGoodsCount) or 1
						local maxC = tonumber(g.MaxGoodsCount) or minC
						ds[#ds + 1] = {
							ID = tonumber(id),
							Count = maxC > minC and math.random(minC, maxC) or minC,
							State = 0,
						}
						daCo[id] = true
						daLay = daLay + 1
					end
				end
			end
		end
	end
	return ds
end

R:on("G_CavernLogic.ClientRefreshGoodsList", function(ctx)
	local ds = sinhHangMaKhu()
	if ds ~= nil and #ds > 0 then
		pcall(function () G_CavernDataManager:SetCavernGoodsList(ds) end)
		--[[ `CavernDataManager` TỰ dựng bảng khi nil và ghi qua
			`G_DataManager:SetUserDataWithName`, nhưng ĐO 28/10 thấy file lưu vẫn
			`GameUserCavern: null` — nên chép thẳng vào kho của lớp offline nữa,
			không phụ thuộc `syncFromClient` có thấy hay không. ]]
		pcall(function ()
			local _, u = G_CavernDataManager:GetUserCavern()
			if type(u) == "table" and OfflineStore.data ~= nil then
				OfflineStore.data.GameUserCavern = u
				OfflineStore.dirty = true
			end
		end)
		OfflineStore:syncFromClient()
		OfflineStore:save()
		OfflineLog:info(string.format("Ma Khu: lam moi hang (mien phi) -> %d mon", #ds))
	else
		OfflineLog:warn("Ma Khu: khong sinh duoc danh sach hang")
	end
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", 0, {})
end)

R:on("G_CavernLogic.ClientRefreshGoodsWithCurrency", function(ctx)
	local nErr = 0
	local okGia, gia = pcall(function ()
		local _, c = G_CavernLogic:GetRefreshCurrency()
		return tonumber(c)
	end)
	local okDu, cur = pcall(function ()
		local _, u = G_CavernDataManager:GetUserCavern()
		return tonumber(u and u.Currency)
	end)

	if not okGia or not tonumber(gia) then
		nErr = 1
	elseif not okDu or (tonumber(cur) or 0) < gia then
		nErr = 1
	else
		local ds = sinhHangMaKhu()
		if ds ~= nil and #ds > 0 then
			pcall(function ()
				G_CavernDataManager:AddCavernCurrency(0 - gia, "RefreshCavernGoods")
				G_CavernDataManager:SetCavernGoodsList(ds)
				local _, u = G_CavernDataManager:GetUserCavern()
				G_CavernDataManager:SetRefreshGoodsCount((tonumber(u.RefreshGoodsCount) or 0) + 1)
			end)
			OfflineStore:syncFromClient()
		else
			nErr = 1
		end
	end

	OfflineLog:info(string.format("Ma Khu: lam moi hang bang tien (gia %s, co %s) -> ma %d",
		tostring(gia), tostring(cur), nErr))
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", nErr, {})
end)

--[[ QUÉT NHANH MA KHU — QUYẾT ĐỊNH CỦA LỚP OFFLINE (chủ dự án yêu cầu).

	Luật quét của máy chủ gốc KHÔNG được ship (chỉ có bảng GIÁ
	`GameCavernSweepCost`: `DirectSweep` theo tầng, `AllSweep = 600`). Đường "đánh
	hộ" (`CavernLogic:CompeleteFight`) đòi trạng thái tướng thật do trận đấu sinh
	ra, nên dựng khống là bịa dữ liệu trận — không làm.

	Nên chọn cách đúng ý chủ dự án: **quét phần ĐÃ QUA** (giống càn quét ải):
	  * `ClientCavernDirectSweep` — quét TẦNG ĐÃ QUA GẦN NHẤT
	    (`CurrentProgress - 1`), giá `DirectSweep[tầng]`;
	  * `ClientCavernSweepAll` — quét TẤT CẢ tầng đã qua (1 … `CurrentProgress-1`),
	    giá `AllSweep`;
	  * thưởng CHỈ VÀNG, theo ĐÚNG công thức gốc
	    `CavernLogic:GetGoldCountWithPassLevel(tầng)` (130 × cấp tướng/6 × tầng,
	    có hệ số VIP `GetVipMultipleGold`) — KHÔNG phát lại rương tầng (rương chỉ
	    một lần mỗi lượt reset);
	  * trừ bằng **tiền Ma Khu** (`CavernCurrency`) — ĐẶT: bảng giá không ghi loại
	    tiền, chọn tiền Ma Khu vì đó là tài nguyên riêng của hệ này.
]]

local function quet(ctx, bTatCa)
	local nErr = 0
	local u = nil
	local okU = pcall(function ()
		local _, x = G_CavernDataManager:GetUserCavern()
		u = x
		return true
	end)

	local tien = okU and tonumber(u and u.CurrentProgress) or nil
	local daQua = (tien and tien > 1) and (tien - 1) or 0

	local cfg = G_ConfigManager:GetCommonConfigWithName("GameCavernSweepCost")
	if type(cfg) ~= "table" then
		OfflineLog:warn("Ma Khu quet: thieu GameCavernSweepCost")
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", 1, {})
		return
	end

	if daQua < 1 then
		OfflineLog:info("Ma Khu quet: chua qua tang nao")
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", 1, {})
		return
	end

	local tu, den, gia = 1, daQua, nil
	if bTatCa then
		gia = tonumber(cfg.AllSweep)
	else
		tu, den = daQua, daQua
		gia = tonumber(cfg.DirectSweep and cfg.DirectSweep[daQua])
	end

	local co = tonumber(u and u.Currency) or 0
	if gia == nil or gia <= 0 then
		nErr = 1
	elseif co < gia then
		nErr = 1
		OfflineLog:info(string.format("Ma Khu quet: thieu tien (co %d, can %d)", co, gia))
	else
		local tongVang = 0
		for tang = tu, den do
			local okV, vang = pcall(function ()
				local _, g = G_CavernLogic:GetGoldCountWithPassLevel(tang)
				return tonumber(g) or 0
			end)
			if okV and vang > 0 then
				tongVang = tongVang + vang
			end
		end

		if tongVang <= 0 then
			nErr = 1
		else
			pcall(function ()
				G_CavernDataManager:AddCavernCurrency(0 - gia, "CavernSweep")
				G_UserLogic:AddGold(tongVang, "CavernSweep")
			end)
			OfflineStore:syncFromClient()
			OfflineLog:info(string.format("Ma Khu quet %s: tang %d..%d, gia %d, vang +%d",
				bTatCa and "tat ca" or "mot tang", tu, den, gia, tongVang))
		end
	end

	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", nErr, {})
end

R:on("G_CavernLogic.ClientCavernDirectSweep", function(ctx) quet(ctx, false) end)
R:on("G_CavernLogic.ClientCavernSweepAll", function(ctx) quet(ctx, true) end)

return true
