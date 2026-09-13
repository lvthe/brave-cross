--[[
	offline/handlers/lottery.lua — chiêu mộ (扭蛋/gacha): rút tướng bằng vàng/kim cương.

	Bản gốc: client gọi CallServer("G_LotteryLogic", "ClientPlayLottery",
	nLotteryType, bTest) (ClientLotteryLogic.lua:41); server rút rồi trả
	OnServerLotteryFinish(nLotteryMode, tResult, bTest, tHeroData)
	(ClientLotteryLogic.lua:50). Luật RÚT nằm ở server (KHÔNG có trong sc/share),
	nên phải DỰNG LẠI phần chọn — nhưng dùng đúng dữ liệu gốc:

	  * GetLotteryConfig(<tên bể>): các NHÓM, mỗi nhóm có LotteryValue (trọng số
	    nhóm) + LotteryDataList (các mục, mỗi mục có LotteryValue = trọng số mục).
	    Rút = chọn NHÓM theo trọng số, rồi chọn MỤC theo trọng số. (Đo: bể "Gold"
	    có 1 nhóm 27 mục; mỗi mục LotteryResType=5, UserProperty=Random,
	    PrizeProperty là nhóm tướng.)
	  * PHÁT thưởng dùng LẠI lối gốc: G_LotteryLogic:setDataWithPrizeList ->
	    G_ChapterLogic:SetDataWithPrizeList (chính lối phần thưởng ải dùng), tự
	    giải UserProperty=Random + PrizeProperty để cấp tướng NGẪU NHIÊN.

	ĐẶT: cách chọn theo trọng số (nhóm/mục theo LotteryValue) là SUY từ tên
	trường, chưa đối chiếu luật server byte-exact. Số đòn Min/Max, chi phí, tên
	bể ("Gold"/"Diamond") lấy từ cấu hình gốc.
]]

require("offline.log")
require("offline.store")
require("offline.router")

local R = OfflineRouter

-- nLotteryType -> { tên bể, số lần rút, loại tiền, chi phí }. Chi phí lấy từ
-- cấu hình gốc (LotteryCostGold...).
local function thongTin(nType)
	local L = LOTTERY_TYPE
	local function gia(fn)
		local ok, v = G_LotteryLogic[fn](G_LotteryLogic)
		return ok and tonumber(v) or 0
	end
	if nType == L.FREE_ONCE then
		return { ten = "Gold", lan = 1, tien = nil, gia = 0 }
	elseif nType == L.GOLD_ONCE then
		return { ten = "Gold", lan = 1, tien = "gold", gia = gia("GetLotteryCostGold") }
	elseif nType == L.GOLD_TENTIMES then
		return { ten = "Gold", lan = 10, tien = "gold", gia = gia("GetLotteryCostGoldTen") }
	elseif nType == L.DIAMOND_ONCE then
		return { ten = "Diamond", lan = 1, tien = "diamond", gia = gia("GetLotteryCostOne") }
	elseif nType == L.DIAMOND_TENTIMES then
		return { ten = "Diamond", lan = 10, tien = "diamond", gia = gia("GetLotteryCostTen") }
	end
	return nil
end

-- Chọn một phần tử theo trọng số LotteryValue.
local function chonTheoTrong(ds)
	if type(ds) ~= "table" or ds[1] == nil then
		return nil
	end
	local tong = 0
	for _, e in ipairs(ds) do
		tong = tong + (tonumber(e.LotteryValue) or 0)
	end
	if tong <= 0 then
		return ds[math.random(#ds)]
	end
	local r = math.random() * tong
	for _, e in ipairs(ds) do
		r = r - (tonumber(e.LotteryValue) or 0)
		if r <= 0 then
			return e
		end
	end
	return ds[#ds]
end

-- Rút MỘT lần từ bể `ten` -> một mục "lottery result" (đúng trường mà
-- changeLotteryDataToPrizeData đọc).
local function rutMot(ten)
	local cfg = G_ConfigManager:GetLotteryConfig(ten)
	if type(cfg) ~= "table" or cfg[1] == nil then
		return nil
	end
	local nhom = chonTheoTrong(cfg) or cfg[1]
	local muc = chonTheoTrong(nhom.LotteryDataList)
	if muc == nil then
		return nil
	end
	local minC = tonumber(muc.MinLotteryResCount) or 1
	local maxC = tonumber(muc.MaxLotteryResCount) or minC
	local cnt = minC
	if maxC > minC then
		cnt = math.random(minC, maxC)
	end
	-- GIẢI "Random": bể tướng ghi UserProperty="Random" + PrizeProperty là một
	-- CHUỖI danh sách id, ví dụ "[1,2,17,47,38,60]". Server chọn MỘT id rồi mới
	-- cấp; nhánh cấp tướng của client (share_ChapterLogic:4351) THOÁT ngay nếu
	-- còn "Random" và đòi PrizeProperty là SỐ. Nên phải chọn ở đây: tách chuỗi,
	-- rút một id, bỏ cờ Random.
	-- ĐẶT: chọn ĐỀU trong bể (luật cân của server chưa đối chiếu được).
	local prop = muc.PrizeProperty
	local userProp = muc.UserProperty
	if userProp == "Random" and type(prop) == "string" then
		local ids = {}
		for s in tostring(prop):gmatch("(%-?%d+)") do
			ids[#ids + 1] = tonumber(s)
		end
		if ids[1] ~= nil then
			prop = ids[math.random(#ids)]
			userProp = nil
		end
	end
	return {
		LotteryResType = muc.LotteryResType,
		ResCount = cnt,
		QualityType = muc.QualityType,
		CurrencyType = muc.CurrencyType,
		UserProperty = userProp,
		PrizeProperty = prop,
		PropID = muc.PropID,
		EquipmentType = muc.EquipmentType,
	}
end

R:on("ClientPlayLottery", function(ctx, nLotteryType, bTest)
	local tt = thongTin(nLotteryType)
	if tt == nil then
		OfflineLog:err("ClientPlayLottery: loai la " .. tostring(nLotteryType))
		return
	end

	-- Trừ tiền (trừ khi thử). Bản gốc trừ ở server; ta trừ tại chỗ bằng luật gốc.
	if not bTest and tt.gia > 0 then
		if tt.tien == "gold" then
			G_UserLogic:CostGold(tt.gia, "lottery")
		elseif tt.tien == "diamond" then
			G_UserLogic:CostDiamond(tt.gia, "lottery")
		end
	end

	-- Rút `lan` mục theo trọng số cấu hình.
	local ketQua = {}
	for _ = 1, tt.lan do
		local m = rutMot(tt.ten)
		if m ~= nil then
			ketQua[#ketQua + 1] = m
		end
	end

	-- Phát thưởng bằng LỐI GỐC (giải Random + cấp tướng), trừ khi thử.
	local tData = nil
	if not bTest then
		local ok, _, td = G_LotteryLogic:setDataWithPrizeList(ketQua, "lottery")
		if ok then
			tData = td
		end
		OfflineStore:syncFromClient()
	else
		local _, td = G_LotteryLogic:changeLotteryDataToPrizeData(ketQua)
		tData = td
	end

	-- Trả đúng hàm client nhận: OnServerLotteryFinish(nLotteryMode, tResult,
	-- bTest, tHeroData). tHeroData để rỗng: UI đọc tData là chính; chưa gặp chỗ
	-- cần tHeroData qua đường thật.
	ctx:call("G_LotteryLogic", "OnServerLotteryFinish",
		nLotteryType, tData or ketQua, bTest and true or false, {})
end)

return true
