--[[
	offline/thu_tai_khoan.lua — TỰ KIỂM LUỒNG TÀI KHOẢN trong game.

	VÌ SAO CÓ: bấm phím trên LDPlayer để đăng ký làm `system_server` chết
	(đo 2/11 22:43: gõ vào EditBox bằng IME → watchdog giết system_server,
	SurfaceFlinger treo). Tệp này gọi THẲNG handler với `ctx` giả — đúng cách
	`thu_nhom_moi.lua` làm — nên kiểm được CẢ CHUỖI mà không cần bàn phím:

	    ClientRegister -> HTTP /api/register -> OnClientRegister (err 0)
	    ClientLogin    -> HTTP /api/login    -> OnServerLogin     (err 0, uid)
	    ClientEnterGame                     -> 1001 NeedCreateCharacter
	    ClientCreateCharacter               -> OnCreateCharacter (0)
	    ClientEnterGame                     -> err 0 + dữ liệu thật

	BẬT: tạo `taikhoan_test.flag` cạnh file lưu. Chạy MỘT lần rồi tự xoá cờ.
	Đây là đồ thử; tài khoản nó tạo nằm lại trong Postgres (tên `tk_test_*`).
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflineThuTaiKhoan = OfflineThuTaiKhoan or {}

local T = OfflineThuTaiKhoan

T.TEP_CO = "taikhoan_test.flag"
T.DA_CHAY = false
T.BUOC = 0
T.DEM = 0
T.CALLS = {}
T.MOC = 0
T.EMAIL = nil
T.PASS = nil
T.UID = nil
T.DAT = 0
T.HONG = 0

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

local function goi(obj, f, ...)
	local fn = OfflineRouter:getFor(obj, f)
	if fn == nil then
		return nil, "CHUA DANG KY " .. tostring(obj) .. "." .. tostring(f)
	end
	local ctx = T.CTX
	T.MOC = #ctx.calls
	local ok, err = pcall(fn, ctx, ...)
	if not ok then return nil, "NEM LOI: " .. tostring(err) end
	return true
end

-- Lượt trả lời MỚI NHẤT cho (obj, f), chỉ tính từ mốc của bước hiện tại.
function T:tim(obj, f)
	local ds = self.CTX.calls
	for i = self.MOC + 1, #ds do
		local x = ds[i]
		if x.obj == obj and x.f == f then return x end
	end
	return nil
end

local function check(ok, ten, ct)
	if ok then
		T.DAT = T.DAT + 1
		OfflineLog:info("THU TAI KHOAN: OK   " .. ten)
	else
		T.HONG = T.HONG + 1
		OfflineLog:warn("THU TAI KHOAN: HONG " .. ten
			.. (ct ~= nil and (" -> " .. tostring(ct)) or ""))
	end
end

function T:ketLuan(ok, ct)
	if self.DA_CHAY and self.XONG then return end
	self.XONG = true
	check(ok, "ca chuoi", ct)
	OfflineLog:info(string.format("THU TAI KHOAN: KET QUA dat %d, hong %d",
		self.DAT, self.HONG))
	xoaTepCo()
end

function T:batDau()
	self.CTX = { calls = {} }
	function self.CTX:call(obj, f, ...)
		self.calls[#self.calls + 1] = {
			obj = obj, f = f, args = { ... }, n = select("#", ...),
		}
	end

	local ok, md5 = pcall(function () return g_CCMath:MD5("123456") end)
	if not ok or type(md5) ~= "string" then
		return self:ketLuan(false, "khong bam duoc MD5: " .. tostring(md5))
	end
	self.PASS = md5
	self.EMAIL = string.format("tk_test_%d@example.com", os.time())
	OfflineLog:info("THU TAI KHOAN: bat dau voi " .. self.EMAIL)

	self.BUOC = 1
	self.MOC = 0
	local ok2, err = goi("G_Login", "ClientRegister", self.EMAIL, self.PASS, 12, "did-test")
	if not ok2 then
		return self:ketLuan(false, err)
	end
end

function T:buoc()
	if self.BUOC == 1 then
		-- Hàm nhận đăng ký nằm trên g_CUILogin (UI), không phải G_Login.
		local r = self:tim("g_CUILogin", "OnClientRegister")
		if r == nil then return end
		local d = r.args[1]
		check(type(d) == "table" and d.err == 0, "dang ky -> err 0", d and d.err)
		if not (type(d) == "table" and d.err == 0) then
			return self:ketLuan(false, "dang ky that bai")
		end
		self.BUOC = 2
		self.MOC = #self.CTX.calls
		goi("G_Login", "ClientLogin", self.EMAIL, self.PASS, 12)

	elseif self.BUOC == 2 then
		local r = self:tim("G_Login", "OnServerLogin")
		if r == nil then return end
		local d = r.args[1]
		check(type(d) == "table" and d.err == 0, "dang nhap -> err 0", d and d.err)
		if not (type(d) == "table" and d.err == 0) then
			return self:ketLuan(false, "dang nhap that bai")
		end
		self.UID = tonumber(d.uid)
		check(type(self.UID) == "number" and self.UID > 0,
			"uid tu Postgres", d.uid)
		self.BUOC = 3
		self.MOC = #self.CTX.calls
		goi("G_GameWorld", "ClientEnterGame")

	elseif self.BUOC == 3 then
		local r = self:tim("G_GameWorld", "OnServerEnterGame")
		if r == nil then return end
		check(r.args[1] == 1001, "chua co nhan vat -> 1001", r.args[1])
		if r.args[1] ~= 1001 then
			return self:ketLuan(false, "khong ra 1001")
		end
		self.BUOC = 4
		self.MOC = #self.CTX.calls
		goi("G_UserLogic", "ClientCreateCharacter", "TestTK", true, 1, "did-test")

	elseif self.BUOC == 4 then
		local r = self:tim("G_UserLogic", "OnCreateCharacter")
		if r == nil then return end
		check(r.args[1] == 0, "tao nhan vat -> 0", r.args[1])
		if r.args[1] ~= 0 then
			return self:ketLuan(false, "tao nhan vat that bai")
		end
		self.BUOC = 5
		self.MOC = #self.CTX.calls
		goi("G_GameWorld", "ClientEnterGame")

	elseif self.BUOC == 5 then
		local r = self:tim("G_GameWorld", "OnServerEnterGame")
		if r == nil then return end
		local ok = r.args[1] == 0 and type(r.args[2]) == "table"
			and type(r.args[2].GameUserBaseInfo) == "table"
		check(ok, "vao game lan 2 -> err 0 + du lieu", r.args[1])
		if not ok then
			return self:ketLuan(false, "vao game lan 2 that bai")
		end
		local bi = r.args[2].GameUserBaseInfo
		check(bi.CharacterName == "TestTK", "ten nhan vat", bi.CharacterName)
		check(tonumber(bi.Uid) == self.UID, "Uid trong du lieu = uid Postgres", bi.Uid)
		return self:ketLuan(true)
	end
end

function T:tick()
	if self.XONG then return end
	if not self.DA_CHAY then
		if not coTepCo() then return end
		-- Chờ vài nhịp cho engine/HTTP manager dựng xong (offline.init chạy rất sớm).
		self.DEM = (self.DEM or 0) + 1
		if self.DEM < 5 then return end
		self.DA_CHAY = true
		self:batDau()
		return
	end
	self.DEM = self.DEM + 1
	if self.DEM > 120 then
		return self:ketLuan(false, "het gio (120 s)")
	end
	pcall(function () self:buoc() end, function (e)
		OfflineLog:err("THU TAI KHOAN: loi buoc: " .. tostring(e))
	end)
end

function T:batDauHenGio()
	if S_CCSchedule == nil then return end
	pcall(function () S_CCSchedule:schedule(self, "tick", 1) end)
end

OfflineThuTaiKhoan:batDauHenGio()

return OfflineThuTaiKhoan
