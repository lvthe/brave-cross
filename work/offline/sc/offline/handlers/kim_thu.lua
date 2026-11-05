--[[
	offline/handlers/kim_thu.lua — ĐIỂM KIM THỦ / 点金手 (đổi kim cương lấy vàng).

	Khoá `G_MidasTouchLogic|ClientRunMidasTouchWithCount(nCount)`
	(`ClientMidasTouchLogic.lua:32`; nút của `CUIMidasTouch`, mở từ `CUIMain.lua:2450`,
	`CUIDailyTask.lua:1196`, `CUIActivitySpecialSale.lua:635`).
	Trước lượt này KHÔNG có handler nào ⇒ bấm là lớp "đang tải" quay mãi.

	LUẬT LÀ MÃ GỐC CÒN SỐNG: `MidasTouchLogic:runMidasTouchWithCount(nCount, tRandomList,
	tArgTimesList)` (`share/share_MidasTouchLogic.lua:63-261`), gọi qua THỰC THỂ
	`G_MidasTouchLogic` (`ClientMidasTouchLogic` thừa kế; nó chỉ thêm `GetDataTouchTimes`,
	không đè hàm này). Luật tự làm hết:

	  · chặn vượt số lượt mỗi ngày: `getMaxTouch()` = `VipConfig.MidasTouchCountList`
	    theo VIP (cấu hình THẬT: VIP0 = **10**, VIP15 = 140) → `MidasTouchRunMax` 2804;
	  · tính giá từng lượt theo `GameMidasTouchConfig.CostList[CurIndex + i]`
	    (cấu hình THẬT, 140 bậc: 5→20→30→40 kim cương, vàng 2000→…);
	  · **RÚT HỆ SỐ** từ `TimesMap` (`{50:1, 35:2, 10:3, 5:10}` — tổng 100) bằng số ngẫu
	    nhiên máy chủ sinh (`getTimesWithRateList`);
	  · trừ `CostDiamond` rồi `AddGold` — HAI lần ghi DUY NHẤT vào túi;
	  · tăng `CurIndex`, lưu `C_MidasTouchData`.

	VÌ SAO CHỈ SINH SỐ NGẪU NHIÊN Ở ĐÂY: đúng như vòng quay (28/10) và bánh tân thủ
	(28/10) — phần "rút" của máy chủ gốc không được ship, nhưng hàm LUẬT có sẵn nhận
	`tRandomList` làm tham số; máy chủ chỉ là bên sinh `math.random()`. Ở đây bảng
	ngẫu nhiên dài ĐÚNG `nCount` (luật đòi `nCount == #tRandomList`, sai là mã 2).

	TRẢ VỀ: `OnServerRunMidasTouchWithCount(tData)` — `ClientMidasTouchLogic.lua:50-89`
	kiểm `tData.nCount`, `tData.tRandomList`, `tData.tTimesList`; `CUIMidasTouch.lua:...`
	đọc thêm `tData.tDiamondCostList` / `tData.tGoldGetList` để chạy hoạt ảnh. Cả NĂM
	trường đều phải có. UI KHÔNG tự cộng vàng (grep `AddGold` trong `CUIMidasTouch.lua`
	= 0) ⇒ máy chủ là bên duy nhất ghi, không có chuyện trừ/cộng ĐÔI.

	VÌ SAO CÓ `OfflineKimThu:kiem_ngay()`: `MidasTouchLogic:ResetDaily()` (đặt
	`CurIndex = 0`) là hàm MÁY CHỦ, không có chỗ gọi nào trong client (grep 0). Không
	gọi thì `CurIndex` cộng dồn mãi qua các ngày, chạm `MaxTouch` một lần là hệ khoá
	vĩnh viễn. Lớp offline gọi nó MỘT LẦN MỖI NGÀY (mốc 5 giờ) — [MOI] nhịp thay cho
	máy chủ, luật và giá vẫn là dữ liệu gốc.

	Mã lỗi: trả ĐÚNG mã gốc (2801 thiếu cấu hình · 2802/2803 lỗi dữ liệu · 2804 hết
	lượt · 2805 thiếu kim cương · 2 sai tham số).
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflineKimThu = OfflineKimThu or {}

local R = OfflineRouter
local TEN_FILE = "kim thu"

local function dongBo()
	pcall(function () OfflineStore:syncFromClient() end)
end

--[[ Trả lời. Tên hàm nhận (`OnServerRunMidasTouchWithCount`) KHÔNG suy ra được bằng
	quy tắc chuỗi của `ctx:reply` (nó dò ra `OnRunMidasTouchWithCount`), nên chỉ tay.
	Khi hỏng truyền bảng `{err=…}` — client thấy `tData.nCount` là nil, thoát, và nó
	đã tắt lớp "đang tải" ở dòng đầu callback UI. ]]
local function traLoi(ctx, tData)
	ctx:call("G_MidasTouchLogic", "OnServerRunMidasTouchWithCount", tData)
end

R:on("G_MidasTouchLogic.ClientRunMidasTouchWithCount", function (ctx, nCount)
	if type(nCount) ~= "number" or nCount < 1 or nCount ~= math.floor(nCount) then
		OfflineLog:warn(TEN_FILE .. ": nCount khong hop le (" .. tostring(nCount) .. ")")
		traLoi(ctx, { err = ErrorCode.ArgError })
		return
	end

	-- Chặn sớm theo ĐÚNG hai cửa của luật gốc, để không phải sinh một bảng ngẫu nhiên
	-- khổng lồ rồi mới bị từ chối ở giữa chừng.
	local soConLai = nil
	pcall(function ()
		local _, max = G_MidasTouchLogic:getMaxTouch()
		local _, d = G_MidasDataManager:GetMidasTouchData()
		local m = tonumber(max)
		if m == nil then
			-- Không đọc được trần: ĐỪNG đoán. Để luật gốc tự trả mã của nó
			-- (2801 thiếu cấu hình) thay vì ta báo oan 2804.
			return
		end
		local idx = tonumber(d and d.CurIndex) or 0
		soConLai = m - idx
	end)
	if soConLai ~= nil and nCount > soConLai then
		OfflineLog:info(string.format("%s: xin %d luot, con %d -> 2804",
			TEN_FILE, nCount, soConLai))
		traLoi(ctx, { err = ErrorCode.MidasTouch.MidasTouchRunMax })
		return
	end

	-- Máy chủ gốc sinh đúng `nCount` số ngẫu nhiên trong [0,1); hệ số do luật gốc rút.
	local randoms = {}
	for i = 1, nCount do
		randoms[i] = math.random()
	end

	local ok, bRet, nErr, costList, goldList, timesList = pcall(function ()
		return G_MidasTouchLogic:runMidasTouchWithCount(nCount, randoms)
	end)
	if not ok then
		OfflineLog:err(TEN_FILE .. ": luat goc nem loi: " .. tostring(bRet))
		traLoi(ctx, { err = 1 })
		return
	end

	dongBo()

	if bRet ~= true then
		OfflineLog:info(string.format("%s: %d luot bi tu choi, ma %s",
			TEN_FILE, nCount, tostring(nErr)))
		traLoi(ctx, { err = tonumber(nErr) or 1 })
		return
	end

	OfflineLog:info(string.format("%s: %d luot — tru kim cuong %s, vang +%s (he so %s)",
		TEN_FILE, nCount,
		table.concat(costList or {}, "+"), table.concat(goldList or {}, "+"),
		table.concat(timesList or {}, ",")))

	traLoi(ctx, {
		nCount = nCount,
		tRandomList = randoms,
		tDiamondCostList = costList or {},
		tGoldGetList = goldList or {},
		tTimesList = timesList or {},
	})
end)

--[[ Một ngày mới: `ResetDaily` đặt `CurIndex = 0`. Trả true nếu luật gốc chạy được. ]]
function OfflineKimThu:kiem_ngay()
	if type(_G.G_MidasTouchLogic) ~= "table" then
		OfflineLog:warn(TEN_FILE .. ": thieu G_MidasTouchLogic — khong dat lai luot ngay")
		return false
	end
	local ok, bRet = pcall(function ()
		return G_MidasTouchLogic:ResetDaily()
	end)
	if not ok then
		OfflineLog:err(TEN_FILE .. ": ResetDaily nem loi: " .. tostring(bRet))
		return false
	end
	if bRet == true then
		OfflineLog:info(TEN_FILE .. ": ngay moi — da dat lai luot diem kim thu")
	end
	dongBo()
	return bRet == true
end

OfflineLog:info("kim thu: da noi 1 khoa (ClientRunMidasTouchWithCount) + OfflineKimThu:kiem_ngay")

return true
