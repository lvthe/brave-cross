--[[
	offline/hoat_dong.lua — LỊCH HOẠT ĐỘNG của lớp offline (VIẾT MỚI).

	VÌ SAO PHẢI CÓ: bản gốc nhận lịch từ máy chủ vận hành —
	`G_ActivityLogic|ClientGetActivityList` trả HAI bảng `(tActivityStateList,
	tActivityConfigMap)` (`ClientActivitiesLogic.lua:96-110`), và mọi màn hoạt động
	đọc chúng qua `GetActivityWithType(type)` → `(state, config)`; thiếu một trong
	hai thì `GetActivityWithType` trả `nil` ⇒ tab hoạt động KHÔNG BAO GIỜ hiện.
	Lớp offline trước 31/10 chỉ phục vụ đúng MỘT hoạt động (`TimeLimitSoulBoxHero`,
	bật thường trực, xem `handlers/login.lua`).

	ĐÂY LÀ DỮ LIỆU BỊA Ở PHẦN NÀO — KHAI RÕ TỪNG CHỖ:
	  · `thoiGian` (bắt đầu/kéo dài), `uuTien`, `ActivityID` — của lớp offline.
	  · `cauHinh` của `LevelFund` (`Diamond`/`VipLevel`/`Level`) — **KHÔNG có trong
	    cấu hình ship** (`KDBGameCommonConfig` chỉ có `ActivityLevelFundConfig` =
	    danh sách `{Level, PrizeID}`). Đây là GIÁ BÁN do lớp offline đặt, `[MOI-1]`;
	    muốn đổi thì sửa ĐÚNG một dòng dưới.
	  · **THƯỞNG THÌ KHÔNG BỊA**: `ActivityLevelFundConfig` (12 bậc Level 25..80,
	    PrizeID 109101..109112) và `ActivityTimeFundConfig` (2 ngày, PrizeID 10001)
	    là cấu hình THẬT, đọc qua `G_ConfigManager`.

	HOẠT ĐỘNG NÀO **KHÔNG** MỞ ĐƯỢC HÔM NAY (đo, đừng thêm vào bảng mà không có dữ liệu):
	  · `CumulativeRecharge` / `CumulativeConsume` / `SingleRecharge` — UI đọc
	    `tConf` như MỘT MẢNG `{Recharge, PrizeList}` (`CUIActivityAccumRecharge.lua`
	    `updateItemData`), mà **không có bảng cấu hình nào** như thế trong dữ liệu ship
	    ⇒ bậc thưởng ở đâu ra là BỊA. Để ĐÓNG.
	  · `LevelCapacityTarget` — `ClientActivityLevelCapacity:Init` chỉ cần
	    `DayLimit`, nhưng thưởng lại do máy chủ phát lúc hết hoạt động
	    (`CallGetLevelCapacityPrize`), luật thưởng không có ở cây ⇒ ĐÓNG.
	  · `RechargeSignLogic` (豪华签到) — cần `RECHARGESIGN_OPENMONTH` + `SignDetail`
	    theo THÁNG (`HeroSprite`, `Sign`, `PrizeList`) do máy chủ phát; **không có
	    dữ liệu tháng nào** trong cây ⇒ ĐÓNG.

	`TimeLimitSoulBoxHero` ĐƯỢC GIỮ y hành vi 30/10 (bật thường trực) — chuyển từ
	`handlers/login.lua` về đây để chỉ còn MỘT nguồn.
]]

require("offline.log")

OfflineHoatDong = OfflineHoatDong or {}

--[[ [MOI-1] Giá mua Quỹ cấp — KHÔNG có trong dữ liệu ship. Muốn đổi: sửa ba số này.
	Diamond = kim cương phải trả; VipLevel / Level = cổng vào. ]]
OfflineHoatDong.QUY_CAP = { Diamond = 500, VipLevel = 0, Level = 1 }

--[[ [MOI-2] Giá mua Quỹ thời gian — cùng lý do. ]]
OfflineHoatDong.QUY_THOI_GIAN = { Diamond = 300, VipLevel = 0, Level = 1 }

--[[ Lịch. Mỗi dòng:
	  type    = giá trị của `ActivityType` (Protocol.lua)
	  keoDai  = số giây hoạt động tính từ lúc vào game (offline: luôn chạy)
	  uuTien  = `Priority`, chỉ để sắp tab
	  cauHinh = bảng cấu hình máy chủ gửi; `nil` = KHÔNG mở (giữ tab ẩn)
	  ghiChu  = dấu vết cho người đọc sau

	`ActivityID` đánh số tăng dần theo thứ tự trong bảng, bắt đầu từ 1; `0` là
	"đóng" theo `CheckActivityIsOpen` (`ClientActivitiesLogic.lua:174`). ]]
OfflineHoatDong.DANH_SACH = {
	{
		type = "LevelFund", keoDai = 3650 * 86400, uuTien = 10,
		cauHinh = function () return OfflineHoatDong.QUY_CAP end,
		ghiChu = "Quỹ cấp: thưởng THẬT từ ActivityLevelFundConfig; giá là [MOI-1]",
	},
	{
		type = "TimeFund", keoDai = 3650 * 86400, uuTien = 11,
		cauHinh = function () return OfflineHoatDong.QUY_THOI_GIAN end,
		ghiChu = "Quỹ thời gian: thưởng THẬT từ ActivityTimeFundConfig; giá là [MOI-2]",
	},
	{
		type = "TimeLimitSoulBoxHero", keoDai = 3650 * 86400, uuTien = 1,
		cauHinh = function () return nil end,
		ghiChu = "Hộp hồn — giữ nguyên quyết định 30/10; cấu hình để nil (client chỉ cần trạng thái)",
	},
}

-- Hoạt động ĐÓNG nhưng vẫn ghi tên ở đây để lượt sau không "phát hiện lại" như thiếu sót.
OfflineHoatDong.DONG = {
	CumulativeRecharge = "khong co bang bac thuong {Recharge, PrizeList} trong du lieu ship",
	CumulativeConsume = "khong co bang bac thuong {Cost, PrizeList} trong du lieu ship",
	SingleRecharge = "khong co bang bac thuong trong du lieu ship",
	LevelCapacityTarget = "luat thuong cuoi hoat dong nam trong may chu da chet",
	RechargeSign = "thieu du lieu THANG (SignDetail/HeroSprite) do may chu phat",
}

--[[ CHỖ MỞ THÊM — dành cho chủ dự án khi CÓ số liệu vận hành.

	`DANH_SACH` ở trên chỉ chứa hoạt động có THƯỞNG THẬT trong dữ liệu ship. Năm
	hoạt động trong `DONG` không mở được vì cần bậc thưởng / dữ liệu tháng do máy
	chủ vận hành phát. Muốn mở: điền vào bảng này, KHÔNG cần sửa mã.

	    OfflineHoatDong.MO_THEM.CumulativeRecharge = {
	        keoDai = 7 * 86400, uuTien = 20,
	        cauHinh = {
	            -- hình dạng do UI đòi (`CUIActivityAccumRecharge:updateItemData`):
	            -- MẢNG các bậc, mỗi bậc { Recharge = <số tiền>, PrizeList = { <PrizeData> } }
	        },
	    }

	Bậc thưởng PHẢI là số liệu thật (từ vận hành / bản ghi cũ). Để RỖNG là trạng
	thái ĐÚNG hiện nay: tab ấy không hiện. ]]
OfflineHoatDong.MO_THEM = {}

local function gio()
	local ok, t = pcall(function () return G_GameWorld:GetServerTime() end)
	if ok and tonumber(t) then return tonumber(t) end
	return os.time()
end

--[[ Dựng hai bảng đúng hình dạng `OnGetAcvitityList(tActivityStateList,
	tActivityConfigMap)` chờ.
	`truoc` (tuỳ chọn) = mốc bắt đầu; mặc định `now - 1 ngày` để tab hiện ngay. ]]
function OfflineHoatDong:layDanhSach(truoc)
	local now = gio()
	local batDau = tonumber(truoc) or (now - 86400)

	local trangThai, cauHinh = {}, {}
	local id = 0

	local function them(strType, keoDai, uuTien, cfg)
		id = id + 1
		trangThai[strType] = {
			ActivityID = id,
			ActivityType = strType,
			IsActivityClose = false,
			BeginTime = batDau,
			EndTime = batDau + (tonumber(keoDai) or 86400),
			LowestUserLevel = 0,
			LowestVipLevel = 0,
			Priority = tonumber(uuTien) or id,
		}
		if type(cfg) == "table" then
			cauHinh[strType] = cfg
		end
	end

	for _, d in ipairs(self.DANH_SACH) do
		local cfg = nil
		if type(d.cauHinh) == "function" then cfg = d.cauHinh() end
		them(d.type, d.keoDai, d.uuTien, cfg)
	end

	-- Mở thêm khi chủ dự án điền `MO_THEM` (xem đầu tệp).
	for strType, d in pairs(self.MO_THEM or {}) do
		if type(d) == "table" and type(d.cauHinh) == "table" then
			them(strType, d.keoDai, d.uuTien, d.cauHinh)
		end
	end

	return trangThai, cauHinh
end

--[[ Cấu hình của MỘT hoạt động, đọc lại từ cùng bảng trên (dùng trong handler). ]]
function OfflineHoatDong:cauHinhCua(strType)
	for _, d in ipairs(self.DANH_SACH) do
		if d.type == strType and type(d.cauHinh) == "function" then
			local cfg = d.cauHinh()
			if type(cfg) == "table" then return cfg end
		end
	end
	return nil
end

function OfflineHoatDong:moKhong(strType)
	return self.DONG[strType] ~= nil
end

OfflineLog:info(string.format(
	"hoat dong: lich moi — %d hoat dong mo, %d dong co ghi ly do",
	#OfflineHoatDong.DANH_SACH, (function ()
		local n = 0
		for _ in pairs(OfflineHoatDong.DONG) do n = n + 1 end
		return n
	end)()))

return OfflineHoatDong
