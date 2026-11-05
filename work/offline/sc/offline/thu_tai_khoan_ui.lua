--[[
	offline/thu_tai_khoan_ui.lua — TỰ KIỂM ĐƯỜNG GIAO DIỆN đăng ký / đăng nhập.

	Khác `thu_tai_khoan.lua` (gọi thẳng handler): tệp này đi ĐÚNG đường người
	chơi bấm — điền ô bằng lệnh, rồi gọi chính hàm của nút:

	    onTouchEnd_OnRegisterOK  -> G_Login:Register  -> ClientRegister (HTTP)
	    OnClientRegister (err 0) -> G_Login:Login     -> ClientLogin   (HTTP)
	    OnServerLogin            -> màn "Vào game"    -> tu_dong bấm vào
	    ClientEnterGame          -> 1001              -> màn tạo nhân vật
	    onTouchEnd_OnCreateCharacterOK -> ClientCreateCharacter
	    ClientEnterGame lần 2    -> vào cảnh Main

	BẬT: tạo `taikhoan_ui_test.flag` cạnh file lưu. Tự xoá cờ khi xong.
	KHÔNG dùng bàn phím (IME) — đo 2/11 22:43: gõ bằng IME làm system_server
	chết, SurfaceFlinger treo.
]]

require("offline.log")
require("offline.store")

OfflineThuTaiKhoanUI = OfflineThuTaiKhoanUI or {}

local T = OfflineThuTaiKhoanUI

T.TEP_CO = "taikhoan_ui_test.flag"
T.DA_CHAY = false
T.BUOC = 0
T.DEM = 0
T.EMAIL = nil
T.PASS = "123456"
T.DAT = 0
T.HONG = 0
T.XONG = false

local function thuMuc()
	return (OfflineStore:path():gsub("[^/]*$", ""))
end

local function coTepCo()
	local ok, fp = pcall(io.open, thuMuc() .. T.TEP_CO, "r")
	if ok and fp then fp:close(); return true end
	return false
end

local function check(ok, ten, ct)
	if ok then
		T.DAT = T.DAT + 1
		OfflineLog:info("THU TK UI: OK   " .. ten)
	else
		T.HONG = T.HONG + 1
		OfflineLog:warn("THU TK UI: HONG " .. ten
			.. (ct ~= nil and (" -> " .. tostring(ct)) or ""))
	end
end

function T:ketLuan(ok, ct)
	if self.XONG then return end
	self.XONG = true
	check(ok, "ca chuoi UI", ct)
	OfflineLog:info(string.format("THU TK UI: KET QUA dat %d, hong %d",
		self.DAT, self.HONG))
	pcall(os.remove, thuMuc() .. self.TEP_CO)
end

local function canh()
	local s = nil
	pcall(function () s = g_CSceneManager:GetCurrentSceneName() end)
	return s
end

local function hien(node)
	if node == nil then return false end
	local ok, v = pcall(function () return node:isVisible() end)
	return ok and v or false
end

function T:tick()
	if self.XONG then return end

	if not self.DA_CHAY then
		if not coTepCo() then return end
		self.DEM = (self.DEM or 0) + 1
		if self.DEM < 6 then return end
		if canh() ~= "Login" then return end
		self.EMAIL = string.format("tk_ui_%d@example.com", os.time())
		self.DA_CHAY = true
		self.BUOC = 1
		OfflineLog:info("THU TK UI: bat dau voi " .. self.EMAIL)
	end

	self.DEM = self.DEM + 1
	if self.DEM > 150 then
		return self:ketLuan(false, "het gio (150 s)")
	end

	local ok, err = pcall(function () self:buoc() end)
	if not ok then
		OfflineLog:err("THU TK UI: loi buoc: " .. tostring(err))
	end
end

function T:buoc()
	if self.BUOC == 1 then
		if rawget(_G, "ebRegisterUserName") == nil
				or rawget(_G, "ebRegisterPassword") == nil
				or rawget(_G, "ebRegisterPassword2") == nil then
			return
		end
		local ok, e = pcall(function ()
			g_CUILogin.bChannel = false
			g_CUILogin:onTouchEnd_OnRegisterUI(nil, true)
			ebRegisterUserName:setMaxLength(64)
			ebRegisterUserName:setText(self.EMAIL)
			ebRegisterPassword:setText(self.PASS)
			ebRegisterPassword2:setText(self.PASS)
			g_CUILogin:onTouchEnd_OnRegisterOK(nil, true)
		end)
		if not ok then
			return self:ketLuan(false, "bam dang ky loi: " .. tostring(e))
		end
		OfflineLog:info("THU TK UI: da bam Dang Ky")
		self.BUOC = 2

	elseif self.BUOC == 2 then
		-- Đăng ký xong client tự gọi Login; `LoginLogicUid` chỉ có sau OnServerLogin.
		local uid = g_CUILogin and g_CUILogin.LoginLogicUid
		if uid == nil then return end
		OfflineLog:info("THU TK UI: da dang nhap uid=" .. tostring(uid))
		self.BUOC = 3

	elseif self.BUOC == 3 then
		-- Chờ dấu 1001 do lớp offline đặt (`Offline.CAN_TAO_NHAN_VAT`). KHÔNG dò
		-- `lLoginInputCreateCharacterUI:isVisible()` — đo 2/11: màn đã hiện mà
		-- `isVisible()` trả false, làm đồ thử chờ tới hết giờ.
		if Offline == nil or Offline.CAN_TAO_NHAN_VAT ~= true then return end
		self.DEM_TAO = (self.DEM_TAO or 0) + 1
		if self.DEM_TAO < 2 then return end
		local ok, e = pcall(function ()
			-- Tên NGẮN: màn tạo nhân vật chặn tên quá 12 ký tự Việt
			-- ("Tên quá dài, không thể sử dụng" — đo khi bấm nút thật).
			ebCreateName:setText("UITK")
			g_CUILogin:onTouchEnd_OnCreateCharacterOK(nil, true)
		end)
		if not ok then
			return self:ketLuan(false, "bam tao nhan vat loi: " .. tostring(e))
		end
		OfflineLog:info("THU TK UI: da bam Tao nhan vat")
		self.BUOC = 4

	elseif self.BUOC == 4 then
		-- Dấu "đã vào game" lấy từ CHÍNH lớp offline (`ClientEnterGame` tăng
		-- `Offline.LAN_VAO_GAME` sau khi qua cửa nhân vật), không dò tên cảnh:
		-- đo 2/11 00:20 — game ĐÃ ở Main (nhiệm vụ ngày chạy, hướng dẫn đóng)
		-- mà `GetCurrentSceneName()` trong tick đồ thử không trả "Main".
		if Offline == nil or (Offline.LAN_VAO_GAME or 0) <= 0 then return end
		OfflineLog:info("THU TK UI: da vao game (canh " .. tostring(canh()) .. ")")
		return self:ketLuan(true)
	end
end

function T:batDauHenGio()
	if S_CCSchedule == nil then return end
	pcall(function () S_CCSchedule:schedule(self, "tick", 1) end)
end

OfflineThuTaiKhoanUI:batDauHenGio()

return OfflineThuTaiKhoanUI
