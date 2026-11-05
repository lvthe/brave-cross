--[[
	offline/thu_dang_nhap_cu.lua — ĐĂNG NHẬP LẠI BẰNG TÀI KHOẢN **CŨ** QUA FORM THẬT.

	VÌ SAO CÓ: `thu_tai_khoan_ui.lua` luôn ĐĂNG KÝ một tài khoản mới. Nhưng câu hỏi
	của lượt "đăng xuất / đổi tài khoản" là: sau khi `dangxuat` đóng app, **mở lại và
	đăng nhập bằng tài khoản vừa dùng** thì có vào đúng kho lưu của nó không. Đồ thử
	này điền ô bằng `setText` rồi bấm nút THẬT (`onTouchEnd_OnLogin`) — KHÔNG dùng bàn
	phím, vì IME từng làm chết `system_server` (đo 2/11).

	BẬT: tạo `dangnhap_cu_test.flag` + tệp `dangnhap_cu.txt` cạnh file lưu:
	    dòng 1 = email, dòng 2 = mật khẩu (THÔ — client tự băm MD5 như người gõ tay)
	Không có tệp tài khoản thì đồ thử TỰ BỎ và ghi lý do (không đoán tài khoản).

	Đo được: form đăng nhập đi đúng đường tài khoản, server nhận, `OfflineStore`
	chuyển sang `offline_save_<uid>.json` của ĐÚNG uid ấy, và vào được game.
]]

require("offline.log")
require("offline.store")
require("offline.router")
require("offline.tai_khoan")

OfflineThuDangNhapCu = OfflineThuDangNhapCu or {}

local T = OfflineThuDangNhapCu

T.TEP_CO = "dangnhap_cu_test.flag"
T.TEP_TK = "dangnhap_cu.txt"
T.DEM = 0
T.DA_CHAY = false
T.XONG = false
T.BUOC = 0

local function thuMuc()
	return (OfflineStore:path():gsub("[^/]*$", ""))
end

local function coTepCo()
	local ok, fp = pcall(io.open, thuMuc() .. T.TEP_CO, "r")
	if ok and fp then fp:close(); return true end
	return false
end

local function xoaCo()
	pcall(os.remove, thuMuc() .. T.TEP_CO)
	pcall(os.remove, thuMuc() .. T.TEP_TK)
end

--- Đọc hai dòng: email, mật khẩu. Trả `(email, mk)` hoặc `(nil, ly do)`.
local function docTaiKhoan()
	local ok, fp = pcall(io.open, thuMuc() .. T.TEP_TK, "r")
	if not ok or not fp then return nil, "khong co " .. T.TEP_TK end
	local email = fp:read("*l")
	local mk = fp:read("*l")
	fp:close()
	email = tostring(email or ""):gsub("^%s+", ""):gsub("%s+$", "")
	mk = tostring(mk or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if email == "" or mk == "" then return nil, "tep tai khoan thieu dong" end
	return email, mk
end

local function canh()
	local s = nil
	pcall(function () s = g_CSceneManager:GetCurrentSceneName() end)
	return s
end

function T:ketLuan(ok, ct)
	self.XONG = true
	OfflineLog:info(string.format("THU DANG NHAP CU: %s%s",
		ok and "OK   " or "HONG ", ct ~= nil and (" — " .. tostring(ct)) or ""))
	xoaCo()
end

function T:tick()
	if self.XONG then return end
	if not coTepCo() then return end

	if not self.DA_CHAY then
		self.DEM = self.DEM + 1
		if self.DEM < 6 then return end
		if canh() ~= "Login" then return end
		local email, mk = docTaiKhoan()
		if email == nil then
			return self:ketLuan(false, mk)
		end
		self.EMAIL, self.MK = email, mk
		self.DA_CHAY = true
		self.BUOC = 1
		OfflineLog:info("THU DANG NHAP CU: bat dau voi " .. email)
	end

	self.DEM = self.DEM + 1
	if self.DEM > 150 then
		return self:ketLuan(false, "het gio (150 s)")
	end
	local ok, err = pcall(function () self:buoc() end)
	if not ok then
		OfflineLog:err("THU DANG NHAP CU: loi buoc: " .. tostring(err))
	end
end

function T:buoc()
	if self.BUOC == 1 then
		if rawget(_G, "ebUserLoginName") == nil
				or rawget(_G, "ebUserLoginPassword") == nil then
			return
		end
		local ok, e = pcall(function ()
			g_CUILogin.bChannel = false
			ebUserLoginName:setMaxLength(64)
			ebUserLoginName:setText(self.EMAIL)
			ebUserLoginPassword:setText(self.MK)
			g_CUILogin:onTouchEnd_OnLogin(nil, true)
		end)
		if not ok then
			return self:ketLuan(false, "bam dang nhap loi: " .. tostring(e))
		end
		OfflineLog:info("THU DANG NHAP CU: da dien o + bam Dang Nhap")
		self.BUOC = 2

	elseif self.BUOC == 2 then
		local uid = g_CUILogin and g_CUILogin.LoginLogicUid
		if uid == nil then return end
		-- Kho phải chuyển sang ĐÚNG uid của tài khoản vừa đăng nhập.
		local kho = OfflineStore.uid_tai_khoan
		OfflineLog:info(string.format(
			"THU DANG NHAP CU: server tra uid=%s · kho dang dung=%s · file=%s",
			tostring(uid), tostring(kho), tostring(OfflineStore.FILE)))
		if tostring(kho) ~= tostring(uid) then
			return self:ketLuan(false, string.format("kho %s KHAC uid %s", tostring(kho), tostring(uid)))
		end
		self.BUOC = 3

	elseif self.BUOC == 3 then
		-- `tu_dong` bấm "Vào game" hộ; dấu vào game lấy từ CHÍNH lớp offline.
		if Offline == nil or (Offline.LAN_VAO_GAME or 0) <= 0 then return end
		return self:ketLuan(true, "vao game (canh " .. tostring(canh()) .. ")")
	end
end

function T:batDau()
	if not coTepCo() then return end
	OfflineLog:info("THU DANG NHAP CU: thay tep co " .. self.TEP_CO
		.. " — se tu dang nhap lai sau khi man Login len")
	if S_CCSchedule == nil then
		OfflineLog:err("THU DANG NHAP CU: khong co S_CCSchedule")
		return
	end
	pcall(function () S_CCSchedule:schedule(self, "tick", 1) end)
end

return OfflineThuDangNhapCu
