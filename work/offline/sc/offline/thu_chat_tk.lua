--[[
	offline/thu_chat_tk.lua — TỰ KIỂM HAI LỆNH CHAT TÀI KHOẢN, CHẠY TRONG GAME.

	Gõ chat trên máy này phải mở panel + bật bàn phím, mà IME đã một lần làm chết
	`system_server` (đo 2/11). Tệp này gọi THẲNG handler `ClientNotifyMessage` với
	một `ctx` giả — đúng cách `thu_nhom_moi.lua` làm — nên kiểm được CẢ CHUỖI mà
	không cần bàn phím:

	    doimk 123456 654321   -> /api/password -> đổi mật khẩu thật trên Postgres
	    (đăng nhập lại bằng mật khẩu MỚI để chứng minh nó đã đổi)
	    dangxuat              -> kho lưu + về màn đăng nhập

	BẬT: tạo `chat_tk_test.flag` cạnh file lưu; chạy MỘT lần sau khi vào Main.
	Đồ thử này ĐỔI MẬT KHẨU của tài khoản đang đăng nhập — chỉ dùng trên tài khoản
	thử (`tk_ui_*`).
]]

require("offline.log")
require("offline.store")
require("offline.router")
require("offline.tai_khoan")

OfflineThuChatTk = OfflineThuChatTk or {}

local T = OfflineThuChatTk

T.TEP_CO = "chat_tk_test.flag"
T.DEM = 0
T.DA_CHAY = false
T.CHO = 6            -- nhịp chờ vào game trước khi bắt đầu
T.BUOC = 0
T.MK_CU = "123456"
T.MK_MOI = "654321"

local function thuMuc()
	return (OfflineStore:path():gsub("[^/]*$", ""))
end

local function coTepCo()
	local ok, fp = pcall(io.open, thuMuc() .. T.TEP_CO, "r")
	if ok and fp then fp:close(); return true end
	return false
end

local function xoaTepCo()
	pcall(os.remove, thuMuc() .. T.TEP_CO)
end

local function ctxGia()
	local c = { calls = {} }
	function c:call(obj, f, ...)
		self.calls[#self.calls + 1] = { obj = obj, f = f, args = { ... } }
		return true
	end
	return c
end

--- Gọi lệnh chat y hệt lúc người chơi bấm "Gửi".
function T:goiChat(noiDung)
	local fn = OfflineRouter:getFor(nil, "ClientNotifyMessage")
	if fn == nil then
		OfflineLog:err("THU CHAT TK: khong co handler ClientNotifyMessage")
		return false
	end
	local c = ctxGia()
	local ok, err = pcall(fn, c, { Type = 1, Content = noiDung, ChannelId = 1, Param = "{}" })
	if not ok then
		OfflineLog:err("THU CHAT TK: handler nem — " .. tostring(err))
		return false
	end
	OfflineLog:info(string.format("THU CHAT TK: da goi '%s' (tra loi %d muc)", noiDung, #c.calls))
	return true
end

function T:tick()
	if self.DA_CHAY or self.TAT then return end
	if not coTepCo() then return end
	if not (Offline and Offline.LAN_VAO_GAME and Offline.LAN_VAO_GAME > 0) then return end

	self.DEM = self.DEM + 1
	if self.DEM < self.CHO then return end

	local tk = rawget(_G, "OfflineTaiKhoan")
	if tk == nil or tk.email == nil then
		OfflineLog:warn("THU CHAT TK: chua dang nhap tai khoan nao — bo qua")
		self.DA_CHAY = true
		xoaTepCo()
		return
	end
	local email = tk.email

	-- 0 -> gửi `doimk`
	if self.BUOC == 0 then
		self.BUOC = 1
		self.DEM = 0
		OfflineLog:info("THU CHAT TK: tai khoan " .. tostring(email))
		self:goiChat("doimk " .. T.MK_CU .. " " .. T.MK_MOI)
		OfflineLog:info("THU CHAT TK: cho /api/password tra loi...")
		return
	end

	-- 1 -> sau 5 nhịp: đăng nhập lại bằng MẬT KHẨU MỚI (chứng minh đã đổi)
	if self.BUOC == 1 then
		if self.DEM < 5 then return end
		self.BUOC = 2
		self.DEM = 0
		local h, ly = tk:bamMD5(T.MK_MOI)
		if h == nil then
			OfflineLog:err("THU CHAT TK: khong bam duoc MD5 — " .. tostring(ly))
			self.DA_CHAY = true
			xoaTepCo()
			return
		end
		OfflineLog:info("THU CHAT TK: thu dang nhap lai bang mat khau MOI")
		tk:dangNhap(email, h, function (ok, res)
			OfflineLog:info(string.format("THU CHAT TK: dang nhap mat khau moi -> ok=%s code=%s %s",
				tostring(ok), tostring(res and res.code), tostring(res and res.error)))
		end)
		return
	end

	-- 2 -> sau 5 nhịp: gửi `dangxuat` (đổi cảnh ⇒ làm CUỐI)
	if self.BUOC == 2 then
		if self.DEM < 5 then return end
		self.BUOC = 3
		self.DA_CHAY = true
		OfflineLog:info("THU CHAT TK: gui 'dangxuat' — se ve man dang nhap")
		self:goiChat("dangxuat")
		xoaTepCo()
		return
	end
end

function T:batDau()
	if not coTepCo() then return end
	OfflineLog:info("THU CHAT TK: thay tep co " .. self.TEP_CO
		.. " — se tu kiem sau khi vao Main")
	if S_CCSchedule == nil then
		OfflineLog:err("THU CHAT TK: khong co S_CCSchedule")
		return
	end
	pcall(function () S_CCSchedule:schedule(self, "tick", 1) end)
end

return OfflineThuChatTk
