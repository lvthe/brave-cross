--[[
	offline/tai_khoan.lua — ĐĂNG NHẬP / ĐĂNG KÝ TÀI KHOẢN (GMAIL + MẬT KHẨU).

	TÀI KHOẢN NẰM Ở POSTGRES CỦA `bravecross-server`, không phải file cục bộ.
	Client Cocos cũ nói RPC nhị phân, không nói được WebSocket JSON, nhưng nó
	CÓ `sngHttpRequestWithString` — nên lớp offline chặn `ClientRegister` /
	`ClientLogin` rồi gọi hai endpoint HTTP của server:

	    POST /api/register  { email, password } -> { ok, uid, username }
	    POST /api/login     { email, password } -> { ok, uid, username }

	MẬT KHẨU: client gốc băm MD5 TRƯỚC khi gửi (`CUILogin2.lua:onTouchEnd_OnLogin`
	gọi `g_CCMath:MD5`). Server scrypt hoá chuỗi MD5 ấy — nghĩa là hai client
	(LDPlayer và Axmol sau này) muốn dùng chung tài khoản phải gửi **MD5 hex**.

	ĐỊA CHỈ SERVER: đọc `account_server.txt` cạnh file lưu (một dòng URL, vd
	`http://192.168.1.2:8787`). Không có file thì dùng mặc định dưới đây —
	đo được 2/11: LDPlayer ping và curl tới `192.168.1.2:8787` OK.
]]

require("offline.log")
require("offline.store")

OfflineTaiKhoan = OfflineTaiKhoan or {}

local T = OfflineTaiKhoan

T.BAT = true
T.SERVER_MAC_DINH = "http://192.168.1.2:8787"
T.uid = nil
T.email = nil
T.pending = {}
T.dem = 0
T.DA_MO = false
T.DEM_CHO = 0
T.TIMEOUT = 20
T.LOI_MANG = 3001          -- ErrorCode_3001 = mất kết nối (client có câu dịch)

--[[ CHƠI TIẾP ĐƯỢC KHI MẤT SERVER (thêm 4/11).

	VẤN ĐỀ: từ 2/11 tài khoản nằm ở Postgres, nên **không có server là không đăng
	nhập được** — dù kho chơi (`offline_save_<uid>.json`) vẫn nằm trên máy. Người
	chơi mất luôn đường vào game vì một dịch vụ phụ.

	LUẬT (hẹp, cố ý):
	  · CHỈ khi lỗi là LỖI MẠNG (mã 3001: không gọi được / hết giờ / phản hồi hỏng).
	    Server trả lời "sai mật khẩu"/"chưa có tài khoản" thì KHÔNG có đường lùi.
	  · CHỈ cho ĐÚNG tài khoản đã dùng lần cuối trên MÁY NÀY (`account_last.txt`) và
	    CHỈ khi kho của uid ấy CÓ THẬT trên đĩa.
	  · **KHÔNG kiểm mật khẩu** (không có gì để kiểm) ⇒ đây là chế độ của MÁY CỤC BỘ,
	    KHÔNG phải "tài khoản hoạt động khi offline". Nhật ký ghi WARN rõ ràng.
	  · uid/tài khoản vẫn là của Postgres — server sống lại thì đăng nhập lại bình
	    thường, cùng uid ấy (nên kho không bị lạc).
	Tắt bằng `OfflineTaiKhoan.CHO_PHEP_OFFLINE = false`. ]]
T.CHO_PHEP_OFFLINE = true

------------------------------------------------------------ đường dẫn / địa chỉ

local function thuMuc()
	local p = OfflineStore:path()
	return (p:gsub("[^/]*$", ""))
end

function T:duongCauHinh()
	return thuMuc() .. "account_server.txt"
end

function T:duongEmail()
	return thuMuc() .. "account_last.txt"
end

function T:base()
	if self._base then return self._base end
	local s = nil
	local ok, fp = pcall(io.open, self:duongCauHinh(), "r")
	if ok and fp then
		s = fp:read("*l")
		fp:close()
	end
	s = tostring(s or ""):gsub("%s+", "")
	if s == "" then s = T.SERVER_MAC_DINH end
	self._base = s:gsub("/+$", "")
	OfflineLog:info("tai khoan: server = " .. self._base)
	return self._base
end

function T:emailDaLuu()
	local ok, fp = pcall(io.open, self:duongEmail(), "r")
	if ok and fp then
		local s = fp:read("*l")
		fp:close()
		return tostring(s or ""):gsub("%s+", "")
	end
	return ""
end

function T:luuEmail(email, uid)
	local ok, fp = pcall(io.open, self:duongEmail(), "w")
	if ok and fp then
		fp:write(tostring(email or ""))
		-- Dòng 2 = uid (thêm 4/11): để chế độ "mất server" biết kho cục bộ nào là
		-- của tài khoản ấy. Tệp cũ chỉ có một dòng ⇒ `uidDaLuu` trả nil, chế độ ấy
		-- tự tắt cho tới lượt đăng nhập thành công kế tiếp (không đoán uid).
		if uid ~= nil then
			fp:write("\n", tostring(uid))
		end
		fp:write("\n")
		fp:close()
	end
end

--- uid của tài khoản dùng lần cuối trên máy này (`nil` nếu tệp cũ chỉ có email).
function T:uidDaLuu()
	local ok, fp = pcall(io.open, self:duongEmail(), "r")
	if not ok or not fp then return nil end
	fp:read("*l")                       -- dòng 1 = email
	local d2 = fp:read("*l")
	fp:close()
	-- NGOẶC KÉP là BẮT BUỘC: `gsub` trả HAI giá trị (chuỗi, số lần thay) — thiếu
	-- ngoặc thì `tonumber` nhận số lần thay làm CƠ SỐ, nổ "base out of range"
	-- (đo trong game 4/11: lỗi ấy nằm TRONG callback HTTP nên lớp "đang tải" kẹt,
	-- không một dòng nhật ký nào của đường đăng nhập).
	local n = tonumber((tostring(d2 or ""):gsub("%s+", "")))
	if n == nil or n <= 0 then return nil end
	return n
end

--- Kho `offline_save_<uid>.json` có thật và có nội dung không (không tạo mới).
local function coKhoCua(uid)
	local p = tostring(OfflineStore:path() or ""):gsub("[^/]*$", "")
	local ok, fp = pcall(io.open, string.format("%soffline_save_%d.json", p, uid), "r")
	if not ok or fp == nil then return false end
	local n = fp:seek("end") or 0
	fp:close()
	return n > 2
end

--- Xét đường lùi "mất server" — xem khối `T.CHO_PHEP_OFFLINE` ở đầu tệp.
--- Trả `uid` khi ĐƯỢC phép vào bằng kho cục bộ, `nil` khi không.
function T:uidDuPhong(email, res)
	if self.CHO_PHEP_OFFLINE == false then return nil end
	if type(res) ~= "table" or tonumber(res.code) ~= T.LOI_MANG then return nil end
	local em = tostring(email or ""):lower()
	if em == "" then return nil end
	if em ~= tostring(self:emailDaLuu()):lower() then return nil end
	local uid = self:uidDaLuu()
	if uid == nil or not coKhoCua(uid) then return nil end
	return uid
end

--------------------------------------------------------------- HTTP (client gốc)

--[[ Một lượt gọi HTTP. `rid` nằm trên URL để phân biệt các lượt cùng đường —
	engine chỉ trả lại (url, content) chứ không có mã yêu cầu. ]]
function T:goi(duong, body, cb)
	self.dem = self.dem + 1
	local rid = tostring(self.dem)
	local url = self:base() .. duong .. "?rid=" .. rid
	self.pending[rid] = { cb = cb, t = os.time(), url = url }

	if type(sngHttpRequestWithString) ~= "function" then
		self.pending[rid] = nil
		OfflineLog:err("tai khoan: KHONG co sngHttpRequestWithString")
		return cb(false, { code = T.LOI_MANG, error = "no_http" })
	end

	local ok, err = pcall(function ()
		sngHttpRequestWithString(url, cjson.encode(body), 1,
			"OfflineTaiKhoan", "__onHttpSuc",
			"OfflineTaiKhoan", "__onHttpFail", 0)
	end)
	if not ok then
		self.pending[rid] = nil
		OfflineLog:err("tai khoan: goi HTTP loi: " .. tostring(err))
		return cb(false, { code = T.LOI_MANG, error = "http" })
	end
	OfflineLog:info("tai khoan: gui " .. duong)
end

local function layRid(url)
	return tostring(url or ""):match("[?&]rid=([%w_]+)")
end

function OfflineTaiKhoan:__onHttpSuc(url, content)
	local rid = layRid(url)
	local p = rid and self.pending[rid]
	if p == nil then return end
	self.pending[rid] = nil

	local ok, t = pcall(cjson.decode, tostring(content or ""))
	if not ok or type(t) ~= "table" then
		OfflineLog:err("tai khoan: phan hoi khong phai JSON: " .. tostring(content))
		return p.cb(false, { code = T.LOI_MANG, error = "bad_json" })
	end
	OfflineLog:info("tai khoan: nhan ok=" .. tostring(t.ok)
		.. " code=" .. tostring(t.code) .. " " .. tostring(t.error))
	p.cb(t.ok == true, t)
end

function OfflineTaiKhoan:__onHttpFail(url, errCode)
	local rid = layRid(url)
	local p = rid and self.pending[rid]
	if p == nil then return end
	self.pending[rid] = nil
	OfflineLog:warn("tai khoan: HTTP that bai (" .. tostring(errCode) .. ")")
	p.cb(false, { code = T.LOI_MANG, error = "http" })
end

-- Hẹn giờ: engine không báo gì nếu mạng chết ⇒ tự cắt sau T.TIMEOUT giây.
function T:kiemTimeout()
	local now = os.time()
	for rid, p in pairs(self.pending) do
		if now - p.t > T.TIMEOUT then
			self.pending[rid] = nil
			OfflineLog:warn("tai khoan: het gio cho " .. tostring(rid))
			pcall(p.cb, false, { code = T.LOI_MANG, error = "timeout" })
		end
	end
end

function T:dangKy(email, password, cb)
	return self:goi("/api/register", { email = email, password = password }, cb)
end

function T:dangNhap(email, password, cb)
	return self:goi("/api/login", { email = email, password = password }, function (ok, res)
		if ok then return cb(true, res) end
		-- MẤT SERVER + ĐÚNG tài khoản dùng lần cuối trên máy + CÓ kho cục bộ ⇒ vào
		-- bằng kho ấy. Ba điều kiện đều hẹp; xem khối `T.CHO_PHEP_OFFLINE` đầu tệp.
		local uid = self:uidDuPhong(email, res)
		if uid ~= nil then
			OfflineLog:warn(string.format(
				"tai khoan: KHONG GOI DUOC SERVER (%s) — VAO BANG KHO CUC BO uid=%s; "
				.. "mat khau KHONG duoc kiem, chi dung tren may nay",
				tostring(res and res.error), tostring(uid)))
			return cb(true, { ok = true, uid = uid, username = email, offline = true })
		end
		cb(false, res)
	end)
end

--[[ ĐỔI MẬT KHẨU (`POST /api/password`, thêm 3/11).

	Server đòi ĐÚNG mật khẩu cũ; cả hai chuỗi đều là **MD5 hex** do client băm
	(`T:bamMD5`). Không có "quên mật khẩu": server không có SMTP, và một endpoint
	đặt lại mật khẩu mà không xác minh gì thì ai biết email cũng chiếm được tài khoản.

	`cb(ok, res)` — `res.code` theo nhóm `ErrorCode.Login` (1050 sai mật khẩu cũ,
	1051 chưa có tài khoản, 1052/2/1055 của đường HTTP). ]]
function T:doiMatKhau(matKhauCu, matKhauMoi, cb)
	local email = tostring(self.email or "")
	if email == "" then
		-- Chưa đăng nhập thì KHÔNG gọi mạng: trả lỗi tại chỗ, đúng mã "mất kết nối"
		-- mà client có câu dịch, thay vì để form báo "email không hợp lệ".
		if cb ~= nil then pcall(cb, false, { code = T.LOI_MANG, error = "no_account" }) end
		return false
	end
	return self:goi("/api/password", {
		email        = email,
		old_password = tostring(matKhauCu or ""),
		new_password = tostring(matKhauMoi or ""),
	}, cb)
end

--- Băm MD5 bằng CHÍNH `g_CCMath:MD5` của client — cùng hàm `CUILogin2.lua` dùng
--- lúc đăng nhập, nên chuỗi gửi đi khớp tuyệt đối với mật khẩu đã đăng ký.
--- Tra `(hex)` hoặc `(nil, lý do)`; KHÔNG bao giờ gửi mật khẩu thô khi băm hỏng.
function T:bamMD5(s)
	local m = rawget(_G, "g_CCMath")
	if m == nil then
		return nil, "khong thay g_CCMath"
	end
	-- KHÔNG đòi `type(m) == "table"`: `g_CCMath = CCMath:new()` (`engine.lua:162`) là
	-- **USERDATA** của lớp native, không phải bảng Lua. ĐO 3/11: bản đầu kiểm
	-- `type(m) == "table"` nên LUÔN từ chối, dù chính client đang dùng `g_CCMath:MD5`
	-- lúc đăng nhập (login chạy được chứng minh hàm ấy có). Đọc `m.MD5` qua pcall để
	-- chịu được cả hai hình.
	local okF, fn = pcall(function () return m.MD5 end)
	if not okF or type(fn) ~= "function" then
		return nil, "g_CCMath khong co MD5 (" .. tostring(okF and type(fn) or fn) .. ")"
	end
	local ok, h = pcall(fn, m, tostring(s))
	if not ok or type(h) ~= "string" or #h ~= 32 then
		return nil, "bam MD5 hong: " .. tostring(h)
	end
	return h
end

----------------------------------------------------------- giao diện đăng nhập

--[[ Mở form tài khoản CỦA CHÍNH CLIENT (ô tên + mật khẩu + nút Đăng nhập/Đăng ký).
	Không dựng UI mới: `CUILogin:onTouchEnd_OnAccountUI` là đường người chơi bấm
	trong bản gốc (`CUILogin2.lua:1944`) — nó chỉ bật/tắt các node có sẵn. ]]
function T:moForm()
	if self.DA_MO then return true end
	local ok, err = pcall(function ()
		if g_buyLoadingDialog then g_buyLoadingDialog:Hide() end

		local login = g_CUILogin
		if login == nil then error("chua co g_CUILogin") end
		login.bChannel = false       -- đi đường TÀI KHOẢN, không phải SDK
		login.bAutoLogin = false

		-- Ô nhập email dài hơn 16 (gmail thường 20-30 ký tự).
		pcall(function () ebUserLoginName:setMaxLength(64) end)
		pcall(function () ebRegisterUserName:setMaxLength(64) end)

		-- CHỈ điền khi ô ĐANG RỖNG: hàm này được gọi LẶP (cảnh Login nạp hai
		-- lần — xem `tick`), điền đè sẽ xoá chữ người chơi đang gõ.
		local email = self:emailDaLuu()
		if email ~= "" then
			local cur = nil
			pcall(function () cur = ebUserLoginName:getText() end)
			if cur == nil or cur == "" then
				pcall(function () ebUserLoginName:setText(email) end)
			end
		end

		login:onTouchEnd_OnAccountUI(nil, true)
	end)
	if not ok then
		OfflineLog:warn("tai khoan: chua mo duoc form: " .. tostring(err))
	end
	return ok
end

-- Gọi từ đồ thử/lúc cần mở lại form (đóng rồi mở lại).
function T:moLaiForm()
	self.DA_MO = false
	self.DEM_CHO = 0
	return self:moForm()
end

--[[ ĐĂNG XUẤT / ĐỔI TÀI KHOẢN — về màn đăng nhập, giữ nguyên file lưu của uid cũ.

	Ba việc, theo thứ tự:
	  1. LƯU kho của phiên đang chơi (`OfflineStore:save()`) — bỏ bước này là mất
	     tiến trình kể từ nhịp lưu trước.
	  2. Xoá PHIÊN trong bộ nhớ (`uid`/`email`/`pending`/cờ form) nhưng **KHÔNG**
	     xoá `OfflineStore.FILE` — `offline_save_<uid>.json` vẫn nằm trên đĩa, lần
	     sau đăng nhập lại đúng uid là `switchTo` nạp lại nguyên vẹn.
	  3. Gọi **hàm của client** `g_CUIUserInfo:Logout("ChangeUser")`
	     (`CUIUserInfo.lua:248`): dọn stack RPC, phát `Logout.OnClientLogout`, đổi
	     cảnh `Login`, rồi `G_DataManager:ResetAllModule()`. Không tự đổi cảnh trần:
	     thiếu `ResetAllModule` thì bảng của tài khoản CŨ còn nguyên trong
	     `G_DataManager` và tài khoản sau sẽ thấy dữ liệu của tài khoản trước.

	Hoãn MỘT nhịp (`S_CCSchedule:scheduleOnce`, 0,3 s): lệnh chat chạy BÊN TRONG
	`OnReciveResponse` của gói `ClientNotifyMessage`; đổi cảnh ngay giữa đường
	phản hồi là tự cắt chân lớp đang chạy.

	`Logout` gọi vài thứ của SDK (`SDK_Mgr`, `WGRefreshWXToken`) — máy này không có
	SDK sống, nên nó NÉM ở giữa đường. Khi ấy ta chạy **đường lùi** làm đúng bốn
	bước cốt lõi, mỗi bước một `pcall` và ghi rõ bước nào hỏng.

	Trả `(true, 'hoan' | 'ngay')` — luôn `true`: lệnh đã được NHẬN, kết quả hiện
	trong `offline.log` (không có UI để báo ngược lại cho người chơi).
]]
function T:dangXuat(cb)
	local uidCu = self.uid
	local okLuu, errLuu = pcall(function () OfflineStore:save() end)
	if not okLuu then
		OfflineLog:warn("dang xuat: luu kho hong — " .. tostring(errLuu))
	end

	-- Xoá PHIÊN, không xoá file lưu của uid.
	self.uid = nil
	self.email = nil
	self.DA_MO = false
	self.DEM_CHO = 0
	self.pending = {}

	--[[ Việc thật. Tách ra hàm riêng để hoãn được, và để đường lùi dùng chung. ]]
	local function chay()
		-- ĐƯỜNG CHÍNH (3/11): ĐÓNG APP, KHÔNG đổi cảnh.
		--
		-- ĐO ĐƯỢC TRONG GAME: `g_CUIUserInfo:Logout("ChangeUser")` chạy xong thì app
		-- **SIGSEGV ở GLThread** — `logcat`: `Fatal signal 11 (SIGSEGV), code 1
		-- (SEGV_MAPERR), fault addr 0x1 in tid ... (GLThread)`, `Process ... has died`.
		-- Đúng họ bẫy "nạp lại bố cục LẦN HAI": cảnh Login đã nạp lúc khởi động, nạp
		-- lại từ trong Main là sập. (Khởi động vào Login thì bình thường — đo 3/11.)
		-- Nên đường thoát là ĐÓNG APP: lần mở sau vào thẳng cảnh Login, form tài khoản
		-- hiện ra — đúng điều người chơi cần khi đổi tài khoản.
		local close = rawget(_G, "LGG_CloseGame")
		if type(close) == "function" then
			local okc, ec = pcall(close)
			OfflineLog:info("dang xuat: LGG_CloseGame -> " .. tostring(okc)
				.. (okc and "" or (" — " .. tostring(ec))))
			if okc then
				if cb ~= nil then pcall(cb, true, "close") end
				return
			end
		end

		local ui = rawget(_G, "g_CUIUserInfo")
		if type(ui) == "table" and type(ui.Logout) == "function" then
			local ok, e = pcall(ui.Logout, ui, "ChangeUser")
			if ok then
				OfflineLog:info("dang xuat: g_CUIUserInfo:Logout('ChangeUser') da chay")
				if cb ~= nil then pcall(cb, true, "logout") end
				return
			end
			OfflineLog:warn("dang xuat: Logout nem — " .. tostring(e) .. " — chay duong lui")
		else
			OfflineLog:warn("dang xuat: khong thay g_CUIUserInfo.Logout — chay duong lui")
		end

		-- ĐƯỜNG LÙI: đúng bốn bước cốt lõi của `CUIUserInfo:Logout`, mỗi bước pcall.
		local buoc = {
			{ "phat Logout.OnClientLogout", function ()
				G_EventManager:PostLogicEvent(nil, EventManagerLogicEvent.Logout.OnClientLogout)
			end },
			{ "G_GameWorld:ExitGame", function () G_GameWorld:ExitGame() end },
			{ "doi canh Login", function () g_CSceneManager:RepaleceScene("Login", "ChangeUser") end },
			{ "G_DataManager:ResetAllModule", function () G_DataManager:ResetAllModule() end },
		}
		for i = 1, #buoc do
			local okb, eb = pcall(buoc[i][2])
			OfflineLog:info("dang xuat (lui): " .. buoc[i][1] .. " -> " .. tostring(okb)
				.. (okb and "" or (" — " .. tostring(eb))))
		end
		if cb ~= nil then pcall(cb, true, "lui") end
	end

	if S_CCSchedule ~= nil and type(S_CCSchedule.scheduleOnce) == "function" then
		local hen = { chay = chay }
		local okh, eh = pcall(function () S_CCSchedule:scheduleOnce(hen, "chay", 0.3) end)
		if okh then
			OfflineLog:info(string.format("dang xuat: hoan 0,3 s (uid cu %s)", tostring(uidCu)))
			return true, "hoan"
		end
		OfflineLog:warn("dang xuat: khong hen duoc — chay ngay (" .. tostring(eh) .. ")")
	end
	chay()
	return true, "ngay"
end

--[[ Bọc `CUILogin:startLogin` để đăng nhập đi đường TÀI KHOẢN.

	Bản gốc: SDK báo thành công -> `sngOnSDKLoginCallBack` -> `startLogin()` ->
	với SDK không phải LOCAL thì đặt `bChannel = true` rồi vào `showUI`, và
	`showUI` gọi `callLoginRPC` -> `ClientSdkLogin`. Ta cần `bChannel = false`
	và KHÔNG tự điền tài khoản đã lưu, để người chơi gõ gmail/mật khẩu. ]]
function T:noiVaoLogin()
	local login = rawget(_G, "g_CUILogin")
	if type(login) ~= "table" then
		OfflineLog:err("tai khoan: khong thay g_CUILogin de noi")
		return false
	end
	if login.__offline_tai_khoan then return true end

	local goc = login.startLogin
	if type(goc) == "function" then
		login.startLogin = function (self2, ...)
			--[[ 4/11 — KHÔNG gọi bản gốc nữa.

			Bản gốc (`CUILogin2.lua:329`) ở nhánh KHÔNG-phải-LOCAL đặt
			`self.bChannel = true` rồi `g_CSceneManager:RepaleceSceneWithoutLoading("Login")`
			→ cảnh mới gọi `showUI` → `callLoginRPC` **NGAY TRONG HÀM** (đo trong
			logcat: `startLogin 1/3` và `showUI bChannel = true` cùng một mili-giây).
			Bản bọc cũ đặt `bChannel = false` SAU khi hàm trả về ⇒ quá muộn: game đã
			nối `vilogin.czgame.net:8530` (chết) ⇒ popup "Mất kết nối server".
			Đây là lý do bấm icon (không frida) bị chặn, trong khi đường frida cũ
			tình cờ lọt vì callback đến lúc cảnh login đã dựng xong.

			Nay đi thẳng nhánh TÀI KHOẢN: bChannel = false, xoá session kênh, thay
			cảnh Login (KHÔNG gọi callLoginRPC). Form do `T:hen mo form` mở sau 1 s. ]]
			self2.bChannel = false
			self2.szSessionID = ""
			self2.szChannelID = ""
			self2.szUserName, self2.szPassword = "", ""
			pcall(function () self2:setLoginInfo("", "") end)
			pcall(function () g_Reconnect:setChannel(false) end)
			local ok, e = pcall(function ()
				g_CSceneManager:RepaleceSceneWithoutLoading("Login")
			end)
			if not ok then
				OfflineLog:err("tai khoan: thay canh Login loi: " .. tostring(e))
			end
		end
	end
	login.__offline_tai_khoan = true
	return true
end

--[[ Cho phép GMAIL ở ô đăng ký của client.

	`CUIRegisterVerification:CheckUserName` (`user/UI/CUILogin.lua:38`) chặn
	tên > 16 ký tự và chỉ cho `[%a%d_@.]` — gmail dài và có `-`/`+` sẽ trượt.
	Ta thay bằng luật email, vẫn giữ nguyên câu lỗi của bản gốc. ]]
function T:noiVaoKiemTen()
	local cv = rawget(_G, "g_CUIRegisterVerification")
	if type(cv) ~= "table" or cv.__offline_tai_khoan then return false end

	cv.CheckUserName = function (self2, ten)
		if ten == nil or ten == "" then
			return false, GetStringWithKey("Register_NameNil")
		end
		if string.len(ten) > 64 then
			return false, GetStringWithKey("Register_NameToLong")
		end
		if string.find(ten, "[^%w_@%.%-%+]") then
			return false, GetStringWithKey("Register_NameIsError")
		end
		-- Tài khoản nay là GMAIL: thiếu `@` thì báo ngay tại ô nhập, đừng để
		-- server trả mã 2 (câu "tham số sai" khó hiểu).
		if string.find(ten, "@", 1, true) == nil then
			return false, GetStringWithKey("Register_NameIsError")
		end
		return true, ""
	end
	cv.__offline_tai_khoan = true
	return true
end

--------------------------------------------------------------- nhịp / khởi động

function T:tick()
	self:kiemTimeout()

	if self.DA_MO then return end
	local canh = nil
	pcall(function () canh = g_CSceneManager:GetCurrentSceneName() end)
	if canh ~= "Login" then return end
	if rawget(_G, "lLoginInputAccountUI") == nil then return end
	if type(g_CUILogin) ~= "table" then return end

	self.DEM_CHO = self.DEM_CHO + 1
	-- Chờ 2 nhịp cho cảnh dựng xong, rồi THỬ MỖI NHỊP trong 20 giây. Vì sao không
	-- dừng ngay khi "thấy hiện": cảnh Login NẠP HAI LẦN — node của cây PRELOAD cũng
	-- báo `isVisible()` là true, nên dừng sớm là dừng trước khi cây ĐANG HIỆN nạp
	-- xong ⇒ màn tiêu đề đứng nguyên (đo 4/11). Gọi lặp 20 s là vô hại: `moForm`
	-- chỉ điền email khi ô RỖNG.
	if self.DEM_CHO < 2 then return end
	if self.DEM_CHO > 20 then
		if not self.DA_MO then
			self.DA_MO = true
			OfflineLog:info("tai khoan: da mo form dang nhap/dang ky")
		end
		return
	end
	self:moForm()
end

function T:batDau()
	if not self.BAT then
		OfflineLog:info("tai khoan: TAT")
		return
	end
	--[[ Máy THẬT có `sngHttpRequestWithString` (hàm C của engine). Bộ thử trên
		PC (lupa) không có ⇒ TẮT chế độ tài khoản để `ClientLogin` rơi về đường
		offline cũ (uid 100001). Đây là cổng MÔI TRƯỜNG, không phải cổng tính
		năng: thiếu hàm ấy thì mọi lượt đăng nhập sẽ báo 3001 vô nghĩa. ]]
	if type(rawget(_G, "sngHttpRequestWithString")) ~= "function" then
		self.BAT = false
		OfflineLog:warn("tai khoan: khong co sngHttpRequestWithString — TAT")
		return
	end
	self:noiVaoLogin()
	self:noiVaoKiemTen()

	if S_CCSchedule ~= nil then
		pcall(function () S_CCSchedule:schedule(self, "tick", 1) end)
		OfflineLog:info("tai khoan: da hen gio mo form (1 s)")
	else
		OfflineLog:err("tai khoan: khong thay S_CCSchedule")
	end
end

OfflineTaiKhoan:batDau()

return OfflineTaiKhoan
