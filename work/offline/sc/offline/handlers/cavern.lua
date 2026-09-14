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
R:on("ClientCompeleteFight", function(ctx, bFightResult, fightHeroStateMap,
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

-- CHƯA LÀM: làm mới hàng cửa hàng (ClientRefreshGoodsList /
-- ClientRefreshGoodsWithCurrency) và quét nhanh (ClientCavernSweepAll /
-- ClientCavernDirectSweep). Luật sinh danh sách hàng không nằm trong
-- CavernLogic (chưa tìm ra chỗ), nên chưa gọi được — để lần sau, không bịa.

return true
