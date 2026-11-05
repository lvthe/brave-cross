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
require("offline.luc_chien")

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
	elseif nType == L.DIAMOND_FREE then
		-- `DIAMOND_FREE = 5` ("免费钻石一次"): bể Diamond, MỘT lượt, GIÁ 0
		-- (`share/LotteryLogic.lua:911-912`: `nLotteryCostDiamond = 0`).
		-- ĐO 3/11: thiếu nhánh này làm nút "Miễn phí" của rương Hoàng Kim gửi
		-- `ClientPlayLottery(5)` -> handler log "loai la 5" rồi IM LẶNG -> lớp
		-- "đang tải" không tắt -> `CUIManager` chặn mọi cú bấm (màn hình đứng).
		return { ten = "Diamond", lan = 1, tien = nil, gia = 0 }
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
		-- KHÔNG bỏ lặng: client đã bật lớp "đang tải" TRƯỚC khi gửi
		-- (`CUILottery.lua:2336-2338` post `OnWaitingForRequest`; `CUIMain.lua:932`
		-- Show). Không trả lời thì lớp ấy không bao giờ tắt và `CUIManager:131`
		-- chặn MỌI cú bấm. Trả lỗi để `OnReceiveResponse` bình thường chạy.
		return ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", 1, {})
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
		-- Riêng lượt MIỄN PHÍ kim cương: đặt mốc để hồi chiêu (`LastFreeDiamondTime`).
		-- Bản gốc gọi `ResetFreeDiamondLotteryTime` (`share/LotteryLogic.lua:214-230`);
		-- thiếu nó thì "Miễn phí" sáng MÃI và `isNeverRunFreeDiamondLottery` sai.
		-- `L` là CỤC BỘ trong `thongTin`, KHÔNG có ở đây (đồ thử bắt: "attempt to
		-- index global 'L'"); dùng tên TOÀN CỤC của `Protocol.lua:717`.
		if nLotteryType == LOTTERY_TYPE.DIAMOND_FREE then
			pcall(function () G_LotteryLogic:ResetFreeDiamondLotteryTime() end)
			OfflineStore:syncFromClient()
		end
	else
		local _, td = G_LotteryLogic:changeLotteryDataToPrizeData(ketQua)
		tData = td
	end

	-- Trả đúng hàm client nhận: OnServerLotteryFinish(nLotteryMode, tResult,
	-- bTest, tHeroData). tHeroData để rỗng: UI đọc tData là chính; chưa gặp chỗ
	-- cần tHeroData qua đường thật.
	--
	-- Tướng VỪA quay ra chưa có lực chiến (máy chủ thật gửi kèm số ấy trong
	-- GameUserHero — xem offline/luc_chien.lua), nên điền ngay tại đây; không
	-- thì nó hiện "Lực 0" cho tới lần vào game sau.
	if not bTest then
		OfflineLucChien:bo_sung()
	end

	ctx:call("G_LotteryLogic", "OnServerLotteryFinish",
		nLotteryType, tData or ketQua, bTest and true or false, {})
end)

--[[ Lịch sử quay của người chơi (`CUILottery:OnGetLotteryData`,
	`CUILottery.lua:21`). ĐO 27/10: bấm Rương trên Main ⇒ panel mở nhưng
	`THIEU G_LotteryLogic.ClientGetLotteryData`, phần "lịch sử/kỷ lục" đứng ở
	vòng quay.

	Người nhận là `ClientLotteryLogic:OnGetLotteryData(nErrCode, tResult)`
	(`ClientLotteryLogic.lua:100-118`): đòi `tResult` là BẢNG và phát event
	`"OnGetLotteryData"` với `{nErrCode, tData}`. Danh sách rỗng là hợp lệ —
	lớp offline không lưu lịch sử quay (bản gốc lưu ở `GameLotteryPlayerRecord`,
	ta chưa ghi vào đó). ]]
R:on("ClientGetLotteryData", function(ctx)
	ctx:call("G_LotteryLogic", "OnGetLotteryData", 0, {})
end)

----------------------------------------------------------- hộp hồn (魂匣)

--[[ ĐÍNH CHÍNH 28/10 — bản trước nói "danh sách mảnh sinh theo tuần KHÔNG có
	trong bất kỳ bảng cấu hình nào". SAI. Nó nằm trong `KDBGameCommonConfig`
	dưới tên bảng con **`GameSoulBoxConfig`** (không phải một tệp KDB*.json
	riêng, nên lần quét theo tên tệp trước đây không thấy):

	  MinTimesGetHero 10 / MaxTimesGetHero 19   — bảo hiểm ra TƯỚNG trong 10..19 lượt
	  RefreshDay 3                              — 3 ngày đổi hộp một lần
	  CostDiamond 400                           — (giá THẬT lúc quay là
	                                              `SoulBoxCost = 250` trong
	                                              GameUserGlobalConfig — hàm
	                                              `LotteryLogic:GetSoulBoxCost`)
	  WeekCount 1 / DayCount 3                  — 1 tướng tuần + 3 tướng ngày
	  FirstLotteryCount 3 / SecondLotteryCount 2 — MỖI lượt ra 3 món bể MỘT +
	                                              2 món bể HAI = 5 món, khớp
	                                              đúng 5 điểm gắn `PlugIn_1..5`
	                                              của armature `HunXiaAnima`
	                                              (đo bằng sng_dump: 5 plug)
	  GetRateMapFirst  — trọng số 38/25/20/10/5/2 cho 5 vật phẩm + 1 TƯỚNG
	  GetRateMapSecond — một mục trọng số 100: MẢNH TƯỚNG
	  WeekHeroIDList 5 / DayHeroIDList 24       — bể tướng để chọn

	ĐẶT (những chỗ hàm sinh của server không được ship nên phải suy):
	  * chọn 1 tướng tuần + 3 tướng ngày theo MỐC THỜI GIAN (số tuần / số ngày)
	    rồi giữ nguyên 3 ngày (`RefreshDay`), thay vì ngẫu nhiên mỗi lần gọi;
	  * món TƯỚNG lấy tướng TUẦN, món MẢNH lấy một trong 3 tướng NGÀY (đều);
	  * bảo hiểm: đếm số lượt chưa ra tướng, ngưỡng rút ngẫu nhiên trong
	    [MinTimesGetHero, MaxTimesGetHero], chạm ngưỡng thì lượt đó thay một
	    món bằng TƯỚNG;
	  * số lượng mỗi món ngẫu nhiên trong [Count, MaxCount] của cấu hình.
]]

local function cfgHopHon()
	local ok, v = pcall(function ()
		return G_ConfigManager:GetCommonConfigWithName("GameSoulBoxConfig")
	end)
	if ok and type(v) == "table" then
		return v
	end
	return nil
end

local function globalData()
	local ok, g = pcall(function ()
		local _, t = G_UserLogic:GetUserGlobalData()
		return t
	end)
	if ok and type(g) == "table" then
		return g
	end
	return nil
end

-- Trạng thái riêng của lớp offline (server gốc giữ ở bảng không được ship):
-- mốc đổi hộp, bể tướng đã chọn, số lượt chưa ra tướng + ngưỡng bảo hiểm.
local KHOA = {
	update = "SoulBoxUpdateTime",
	week = "SoulBoxWeek",
	day = "SoulBoxDay",
	pity = "SoulBoxPity",
	nguong = "SoulBoxPityTarget",
}

local function chonTuongHopHon(cfg, now)
	local weekList = cfg.WeekHeroIDList
	local dayList = cfg.DayHeroIDList
	local soNgay = math.floor(now / 86400)
	local soTuan = math.floor(soNgay / 7)
	local week, day = {}, {}

	if type(weekList) == "table" and #weekList > 0 then
		for i = 0, math.max(1, tonumber(cfg.WeekCount) or 1) - 1 do
			week[#week + 1] = weekList[(soTuan + i) % #weekList + 1]
		end
	end
	if type(dayList) == "table" and #dayList > 0 then
		local canChon = math.max(1, tonumber(cfg.DayCount) or 3)
		for i = 0, canChon - 1 do
			day[#day + 1] = dayList[(soNgay * canChon + i) % #dayList + 1]
		end
	end
	return week, day
end

local function chonTheoBangTrong(bang)
	local tong = 0
	for trong, _ in pairs(bang or {}) do
		tong = tong + (tonumber(trong) or 0)
	end
	if tong <= 0 then
		return nil
	end
	local r = math.random() * tong
	for trong, muc in pairs(bang) do
		r = r - (tonumber(trong) or 0)
		if r <= 0 then
			return muc
		end
	end
	return nil
end

local function soLuongCuaMuc(muc)
	local minC = tonumber(muc.Count) or 1
	local maxC = tonumber(muc.MaxCount) or minC
	if maxC > minC then
		return math.random(minC, maxC)
	end
	return minC
end

-- Một mục cấu hình -> một PrizeData; `tuong` là mã tướng dùng cho Loại 5/6.
local function mucThanhGiaiThuong(muc, tuong)
	local loai = tonumber(muc.PrizeResType)
	local soLuong = soLuongCuaMuc(muc)
	if loai == PrizeResType.Hero then
		return { PrizeResType = PrizeResType.Hero, PrizeProperty = tuong, PrizeResCount = 1 }
	elseif loai == PrizeResType.HeroFragment then
		return { PrizeResType = PrizeResType.HeroFragment, PrizeProperty = tuong, PrizeResCount = soLuong }
	end
	return { PrizeResType = PrizeResType.Prop, PropID = tonumber(muc.Id), PrizeResCount = soLuong }
end

--[[ Danh sách tướng của hộp. Người nhận:
	`ClientLotteryLogic:OnServerGetSoulBoxHeroFragmentList(nErrCode, tData)`
	(`ClientLotteryLogic.lua:216+`) — chính nó phát `OnReceiveResponse` (tắt lớp
	đang tải) rồi phát dữ liệu cho UI; `CUISoulBox` đọc đúng ba khoá dưới đây
	(`WeekHeroIDList`, `DayHeroIDList`, `UpdateTime`). ]]
R:on("ClientGetSoulBoxHeroFragmentList", function(ctx)
	local cfg = cfgHopHon()
	if cfg == nil then
		OfflineLog:warn("GetSoulBoxHeroFragmentList: thieu GameSoulBoxConfig — tra rong")
		ctx:call("G_LotteryLogic", "OnServerGetSoulBoxHeroFragmentList", 0, {})
		return
	end

	local now = tonumber(G_GameWorld:GetServerTime()) or os.time()
	local g = globalData()
	local refreshDay = tonumber(cfg.RefreshDay) or 3
	local tData

	local conHan = g ~= nil and tonumber(g[KHOA.update]) ~= nil
		and now < g[KHOA.update] + refreshDay * 86400
	if conHan and type(g[KHOA.week]) == "table" and type(g[KHOA.day]) == "table" then
		tData = {
			WeekHeroIDList = g[KHOA.week],
			DayHeroIDList = g[KHOA.day],
			UpdateTime = g[KHOA.update],
		}
	else
		local week, day = chonTuongHopHon(cfg, now)
		if g ~= nil then
			g[KHOA.update] = now
			g[KHOA.week] = week
			g[KHOA.day] = day
			OfflineStore:syncFromClient()
		end
		tData = { WeekHeroIDList = week, DayHeroIDList = day, UpdateTime = now }
	end

	OfflineLog:info(string.format("hop hon: tuan %s · ngay %s",
		table.concat(tData.WeekHeroIDList or {}, ","),
		table.concat(tData.DayHeroIDList or {}, ",")))
	ctx:call("G_LotteryLogic", "OnServerGetSoulBoxHeroFragmentList", 0, tData)
end)

--[[ Quay HỘP HỒN (魂匣). `ClientLotteryLogic:PlaySoulBox`
	(`ClientLotteryLogic.lua:137`) gửi `ClientPlaySoulBox` rồi bật lớp "đang
	tải"; người nhận là `ClientLotteryLogic:OnServerPlaySoulBox(tData)`, UI đọc
	`tData.tPrizeList` (`CUISoulBox:enterSoulBoxResultAnimation`).

	Thứ tự kiểm đúng như bản gốc: mở khoá (`CheckSoulBoxIsOpen` — cổng VIP
	`HeroSoulBoxLevel`) -> đủ kim cương (`IsEnoughDiamondToMakeLottery`,
	giá `GetSoulBoxCost`) -> trừ -> quay -> phát thưởng qua
	`G_ChapterLogic:SetDataWithPrizeList` (chính lối cấp phần thưởng của ải, đã
	phủ Loại 2 / 5 / 6). ]]
R:on("G_LotteryLogic.ClientPlaySoulBox", function(ctx, bTest)
	local cfg = cfgHopHon()
	local now = tonumber(G_GameWorld:GetServerTime()) or os.time()

	local function traLoi(nErr)
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", nErr, {})
	end

	if cfg == nil then
		OfflineLog:warn("ClientPlaySoulBox: thieu GameSoulBoxConfig")
		traLoi(ErrorCode.CheckSoulBoxNotOpen)
		return
	end

	local okMo, moRoi = pcall(function ()
		local _, b = G_LotteryLogic:CheckSoulBoxIsOpen()
		return b
	end)
	if not okMo or moRoi ~= true then
		OfflineLog:info("ClientPlaySoulBox: hop hon chua mo khoa -> 2003")
		traLoi(ErrorCode.CheckSoulBoxNotOpen)
		return
	end

	if bTest ~= true then
		-- ⚠ `IsEnoughDiamondToMakeLottery` trả (bResult, nCost) — giá trị ĐẦU
		-- là cờ đủ/không, giá trị HAI là giá. Đọc nhầm thứ tự thì `du` là 250
		-- (số thật, luôn khác true) và lần nào cũng báo thiếu tiền.
		local okDu, du = pcall(function ()
			local b = G_LotteryLogic:IsEnoughDiamondToMakeLottery(LOTTERY_TYPE.SOULBOX_ONCE)
			return b == true
		end)
		if not okDu or du ~= true then
			-- Ghi cả giá lẫn số kim cương thực có: "không đủ" của bản gốc có
			-- hai đường (thiếu tiền thật / không đọc được giá), phải phân biệt.
			local gia, kim = "?", "?"
			pcall(function ()
				local _, c = G_LotteryLogic:GetSoulBoxCost()
				gia = tostring(c)
				local _, n = G_UserLogic:GetDiamond()
				kim = tostring(n)
			end)
			OfflineLog:info(string.format(
				"ClientPlaySoulBox: khong du kim cuong -> 1702 (gia %s, co %s, loi %s)",
				gia, kim, tostring(du)))
			traLoi(ErrorCode.Resource.NoEnoughResource)
			return
		end
	end

	-- Bể tướng của hộp (chọn lại nếu đã quá hạn đổi — giống lần mở panel).
	local g = globalData()
	local refreshDay = tonumber(cfg.RefreshDay) or 3
	local week, day = nil, nil
	if g ~= nil and type(g[KHOA.week]) == "table" and type(g[KHOA.day]) == "table"
		and tonumber(g[KHOA.update]) and now < g[KHOA.update] + refreshDay * 86400 then
		week, day = g[KHOA.week], g[KHOA.day]
	else
		week, day = chonTuongHopHon(cfg, now)
	end
	local tuongTuan = week and week[1]
	local tuongNgay = (day and #day > 0) and day
		or (week and #week > 0 and week or {})
	local function chonTuongNgay()
		if type(tuongNgay) == "table" and #tuongNgay > 0 then
			return tonumber(tuongNgay[math.random(#tuongNgay)])
		end
		return nil
	end

	-- Trừ kim cương (bản gốc trừ ở server; số lấy đúng hàm gốc).
	if bTest ~= true then
		local okGia, gia = pcall(function ()
			local _, c = G_LotteryLogic:GetSoulBoxCost()
			return tonumber(c)
		end)
		if okGia and tonumber(gia) and tonumber(gia) > 0 then
			local truoc, sau = "?", "?"
			pcall(function ()
				local _, n = G_UserLogic:GetDiamond()
				truoc = tostring(n)
			end)
			local okCost, bCost = pcall(function ()
				return G_UserLogic:CostDiamond(tonumber(gia), "soulbox")
			end)
			pcall(function ()
				local _, n = G_UserLogic:GetDiamond()
				sau = tostring(n)
			end)
			OfflineLog:info(string.format(
				"hop hon: tru %s kim cuong: %s -> %s (ok=%s, tra ve=%s)",
				tostring(gia), truoc, sau, tostring(okCost), tostring(bCost)))
		end
	end

	-- Bảo hiểm ra tướng: đếm lượt chưa ra tướng, ngưỡng trong [Min, Max].
	local pity = (g and tonumber(g[KHOA.pity])) or 0
	local nguong = (g and tonumber(g[KHOA.nguong])) or 0
	if nguong <= 0 then
		nguong = math.random(tonumber(cfg.MinTimesGetHero) or 10,
			math.max(tonumber(cfg.MinTimesGetHero) or 10, tonumber(cfg.MaxTimesGetHero) or 19))
	end
	pity = pity + 1
	local batBuocTuong = pity >= nguong
	local daRaTuong = false

	local ds = {}
	local soMot = math.max(1, tonumber(cfg.FirstLotteryCount) or 3)
	local soHai = math.max(0, tonumber(cfg.SecondLotteryCount) or 2)
	local mapMot = cfg.GetRateMapFirst or {}
	local mapHai = cfg.GetRateMapSecond or {}

	for _ = 1, soMot do
		local muc = chonTheoBangTrong(mapMot)
		if muc ~= nil then
			if tonumber(muc.PrizeResType) == PrizeResType.Hero then
				daRaTuong = true
				ds[#ds + 1] = mucThanhGiaiThuong(muc, tonumber(tuongTuan) or chonTuongNgay())
			else
				ds[#ds + 1] = mucThanhGiaiThuong(muc, chonTuongNgay())
			end
		end
	end
	if batBuocTuong and not daRaTuong then
		-- Thay món ĐẦU bằng tướng: hộp luôn đủ số điểm gắn của armature.
		local tuong = tonumber(tuongTuan) or chonTuongNgay()
		if tuong ~= nil then
			ds[1] = { PrizeResType = PrizeResType.Hero, PrizeProperty = tuong, PrizeResCount = 1 }
			daRaTuong = true
		end
	end

	for _ = 1, soHai do
		local muc = chonTheoBangTrong(mapHai)
		if muc ~= nil then
			ds[#ds + 1] = mucThanhGiaiThuong(muc, chonTuongNgay())
		end
	end

	if g ~= nil and bTest ~= true then
		g[KHOA.update] = g[KHOA.update] or now
		g[KHOA.week] = g[KHOA.week] or week
		g[KHOA.day] = g[KHOA.day] or day
		g[KHOA.pity] = daRaTuong and 0 or pity
		g[KHOA.nguong] = daRaTuong and 0 or nguong
	end

	if bTest ~= true and #ds > 0 then
		local okPhat = pcall(function ()
			return G_ChapterLogic:SetDataWithPrizeList(ds, nil, "soulbox")
		end)
		if not okPhat then
			OfflineLog:warn("ClientPlaySoulBox: phat thuong loi")
		end
		OfflineStore:syncFromClient()
		OfflineLucChien:bo_sung()
	end

	local ten = {}
	for _, m in ipairs(ds) do
		ten[#ten + 1] = string.format("loai %s%s x%s", tostring(m.PrizeResType),
			m.PropID and ("/id " .. tostring(m.PropID)) or ("/tuong " .. tostring(m.PrizeProperty)),
			tostring(m.PrizeResCount))
	end
	OfflineLog:info(string.format("hop hon: %d mon — %s", #ds, table.concat(ten, ", ")))

	ctx:call("G_LotteryLogic", "OnServerPlaySoulBox", { tPrizeList = ds })
end)

return true
