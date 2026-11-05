--[[
	offline/handlers/qua_7_ngay.lua — QUÀ ĐĂNG NHẬP 7 NGÀY / 七日登录领奖.

	Khoá `G_SevenDaysGiftLogic|ClientSevenDaysGift(nDay)` (`ClientSevenDaysGiftLogic.lua:32`,
	nút "Nhận" của `CUISevenDaysGift` mở từ `CUIMainTopTool:onTouchEnd_btnSevenDaysGiftUI`).
	Trước lượt này KHÔNG có handler nào ⇒ bấm "Nhận" là lớp "đang tải" quay mãi.

	LUẬT LÀ MÃ GỐC CÒN SỐNG: `SevenDaysGiftLogic:saveSevenDaysGiftWithDay(nDay)`
	(`share/share_SevenDaysGiftLogic.lua:220-320`), gọi qua THỰC THỂ `G_SevenDaysGiftLogic`
	(`ClientSevenDaysGiftLogic` thừa kế nguyên vẹn — nó chỉ ĐÈ `GetSevenDaysGift`, tên khác).
	Luật tự làm hết:

	  · chặn quá ngày cuối (`checkIsMaxDay(nDay - 1)` → `SevenDaysGift.ExceedMaxDay`);
	  · chặn ngày chưa mở / đã nhận (`GetStatusMap[nDay]`, mã `NotOpen` / `HasGet`);
	  · đọc `GameSevenDaysGiftConfig.DayList[nDay].PrizeList` (cấu hình THẬT, 7 ngày × 3 món);
	  · phát thưởng bằng `G_ChapterLogic:SetDataWithPrizeList` (chính lối cấp thưởng của ải,
	    tự đẩy popup "Nhận Thưởng" cho UI);
	  · đặt `GetStatusMap[nDay] = HasGet` rồi lưu.

	VÌ SAO PHẢI CÓ `OfflineQua7Ngay:kiem_ngay()`: bảng trạng thái
	(`GameUserGlobalData.C_SevenDaysGiftData`) do MÁY CHỦ sinh bằng
	`SevenDaysGiftLogic:SetDailyLogin()` (mở thêm một ngày mỗi ngày). Hàm ấy KHÔNG có
	một chỗ gọi nào trong cả cây client (grep 0) — đo được: mọi ngày nằm ở `NotOpen`,
	nút "Nhận" bấm vào chỉ ra mã `NotOpen`. Lớp offline gọi nó MỘT LẦN MỖI NGÀY (mốc
	5 giờ, như `DialyRefreshHour`) — [MOI] đây là QUYẾT ĐỊNH của lớp offline thay cho
	nhịp đăng nhập của máy chủ, KHÔNG phải dữ liệu bịa; toàn bộ luật thưởng vẫn là
	mã gốc + cấu hình gốc.

	Mã lỗi: `saveSevenDaysGiftWithDay` trả `(bResult, nErrCode)` ĐÚNG mã gốc
	(3201 quá ngày / 3202 chưa mở / 3203 đã nhận / …) nên trả thẳng, không quy về 1.
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflineQua7Ngay = OfflineQua7Ngay or {}

local R = OfflineRouter
local TEN_FILE = "qua 7 ngay"

local function dongBo()
	pcall(function () OfflineStore:syncFromClient() end)
end

--[[ Trả lời cho client. Tên hàm nhận KHÔNG suy ra được bằng quy tắc chuỗi
	(`ctx:reply` sẽ dò thành `OnSevenDaysGift`, không tồn tại), nên chỉ tay.
	Tham số ĐẦU là `nDay` khi thành công; khi hỏng truyền một BẢNG — client
	kiểm `ProcessNotNumber` rồi thoát, và nó đã tắt lớp "đang tải" ở dòng đầu
	(`CUISevenDaysGift.lua:178-186`), nên không treo. ]]
local function traLoi(ctx, nDay)
	ctx:call("G_SevenDaysGiftLogic", "OnServerGetSevenDaysGift", nDay)
end

R:on("G_SevenDaysGiftLogic.ClientSevenDaysGift", function (ctx, nDay)
	if type(nDay) ~= "number" then
		OfflineLog:warn(TEN_FILE .. ": nDay khong phai so (" .. tostring(nDay) .. ")")
		traLoi(ctx, { err = ErrorCode.ArgError })
		return
	end

	local ok, bRet, nErr = pcall(function ()
		return G_SevenDaysGiftLogic:saveSevenDaysGiftWithDay(nDay)
	end)
	if not ok then
		OfflineLog:err(TEN_FILE .. ": luat goc nem loi: " .. tostring(bRet))
		traLoi(ctx, { err = 1 })
		return
	end

	dongBo()

	if bRet ~= true then
		OfflineLog:info(string.format("%s: nhan ngay %d bi tu choi, ma %s",
			TEN_FILE, nDay, tostring(nErr)))
		traLoi(ctx, { err = tonumber(nErr) or 1 })
		return
	end

	OfflineLog:info(string.format("%s: da nhan qua ngay %d", TEN_FILE, nDay))
	traLoi(ctx, nDay)
end)

--[[ Một ngày mới: gọi `SetDailyLogin` — luật gốc, tự cộng `DayCount` và mở ngày
	kế tiếp. Trả true nếu vừa mở thêm ngày. ]]
function OfflineQua7Ngay:kiem_ngay()
	if type(_G.G_SevenDaysGiftLogic) ~= "table" then
		OfflineLog:warn(TEN_FILE .. ": thieu G_SevenDaysGiftLogic — khong mo ngay moi")
		return false
	end
	local ok, bRet = pcall(function ()
		return G_SevenDaysGiftLogic:SetDailyLogin()
	end)
	if not ok then
		OfflineLog:err(TEN_FILE .. ": SetDailyLogin nem loi: " .. tostring(bRet))
		return false
	end
	if bRet == true then
		OfflineLog:info(TEN_FILE .. ": ngay moi — da mo them mot ngay qua")
	end
	dongBo()
	return bRet == true
end

OfflineLog:info("qua 7 ngay: da noi 1 khoa (ClientSevenDaysGift) + OfflineQua7Ngay:kiem_ngay")

return true
