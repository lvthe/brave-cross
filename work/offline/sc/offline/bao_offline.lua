--[[
	offline/bao_offline.lua — BÁO "ĐANG CHƠI NGOẠI TUYẾN" CHO NGƯỜI CHƠI THẤY (4/11).

	VÌ SAO: đường lùi "mất server" (`OfflineTaiKhoan:dangNhap` → `uidDuPhong`) cho vào
	game bằng KHO CỤC BỘ mà **KHÔNG kiểm mật khẩu**. Trước lượt này dấu duy nhất là
	một dòng trong `offline.log` — người chơi không thấy, dễ tưởng mình đã đăng nhập
	qua mạng và dữ liệu được lưu trên máy chủ.

	ĐƯỜNG HIỂN THỊ: `g_CUIToolTips:AddTipsWithString` — chính API client dùng cho mọi
	thông báo ngắn (`CGuideScheme.lua:4458`, `ClientPaymentLogic.lua:148`, …). KHÔNG
	dùng `print`/notification riêng: `g_CUIToolTips` đã có sẵn hộp thoại và hàng đợi.

	THỜI ĐIỂM: hẹn 3 giây sau `ClientEnterGame` — lúc ấy cảnh Main đã dựng xong (đường
	đăng nhập đi qua cảnh `Battle` rồi mới `Main`, xem memory 2/11). Không có
	`S_CCSchedule` (bộ thử PC) thì hiện ngay.

	CHỈ MỘT LẦN mỗi lượt đăng nhập: `dat()` đặt lại cờ, `hien()` chỉ bắn một lần.
	Đăng nhập lại thành công qua MẠNG thì `xoa()` — không để cờ cũ báo nhầm.
]]

require("offline.log")

OfflineBao = OfflineBao or {}

local M = OfflineBao

M.BAT = true

--- Giây chờ trước khi hiện (cảnh Main dựng xong).
M.CHO_GIAY = 3

--- Câu hiện cho người chơi. Ngắn, nói ĐÚNG ba điều: ngoại tuyến · không kiểm mật
--- khẩu · dữ liệu chỉ ở máy này. Không dọa "mất dữ liệu" (dữ liệu KHÔNG mất).
M.CAU = "Đang chơi NGOẠI TUYẾN: không kết nối được máy chủ. "
	.. "Mật khẩu không được kiểm tra; dữ liệu chỉ lưu trên máy này."

M.daHen = false
M.daBao = false
M.lyDo = nil

--- Gọi khi đăng nhập bằng kho cục bộ (đường lùi "mất server").
function M:dat(lyDo)
	self.daHen = false
	self.daBao = false
	self.lyDo = tostring(lyDo or "dang nhap bang kho cuc bo")
	OfflineLog:info("bao offline: dat co — " .. self.lyDo)
	return true
end

--- Gọi khi đăng nhập thành công qua MẠNG: xoá cờ, không báo nhầm lượt sau.
function M:xoa()
	self.daHen = false
	self.daBao = false
	self.lyDo = nil
	return true
end

--- Hiện ngay (cũng là hàm được hẹn giờ gọi). Trả `true` nếu ĐÃ bắn được câu báo.
function M:hien()
	if not self.BAT or self.lyDo == nil or self.daBao then return false end
	local tips = rawget(_G, "g_CUIToolTips")
	local okGet, fn = pcall(function () return tips and tips.AddTipsWithString end)
	if not okGet or type(fn) ~= "function" then
		-- Không có API hiển thị (bộ thử PC / UI chưa nạp) ⇒ KHÔNG ném: đường đăng nhập
		-- không được chết vì một câu thông báo.
		OfflineLog:warn("bao offline: khong thay g_CUIToolTips:AddTipsWithString")
		return false
	end
	self.daBao = true
	local ok, err = pcall(fn, tips, self.CAU)
	if not ok then
		self.daBao = false
		OfflineLog:warn("bao offline: hien hong — " .. tostring(err))
		return false
	end
	OfflineLog:info("bao offline: da hien trong game")
	return true
end

--- Hẹn hiện sau `CHO_GIAY`; không có bộ hẹn giờ thì hiện ngay. Gọi nhiều lần vô hại.
function M:hen()
	-- KHÔNG có cờ (`lyDo == nil`) ⇒ lượt này vào bằng MẠNG, không báo gì.
	if not self.BAT or self.lyDo == nil or self.daHen or self.daBao then return false end
	self.daHen = true
	local sch = rawget(_G, "S_CCSchedule")
	if sch ~= nil and type(sch.scheduleOnce) == "function" then
		local ok = pcall(function () sch:scheduleOnce(self, "hien", self.CHO_GIAY) end)
		if ok then
			OfflineLog:info(string.format("bao offline: hen hien sau %.0f giay", self.CHO_GIAY))
			return true
		end
	end
	return self:hien()
end

return OfflineBao
