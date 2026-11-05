--[[
	offline/noi_server.lua — CẦU nối MỘT NHÓM RPC SANG SERVER THẬT (`bravecross-server`).

	VÌ SAO CÓ: client Cocos cũ không nói được WebSocket, nên lớp offline trả lời TẠI CHỖ
	(440/511 tên hàm). Muốn một nhóm dùng handler của SERVER thật thì phải có cầu.

	ĐƯỜNG ĐI:
	    CallServer(...)                  (sc/system/rpc.lua, đã bị OfflineNet chặn)
	      -> OfflineNet:dispatch          (offline/net.lua)
	        -> [tệp này] nếu objName thuộc NHÓM:
	             POST /api/rpc { uid, moudule, objName, funcName, data, serial, snapshot }
	             <- tl { obj, cb, err, suKien, gui, them }
	             -> đẩy `OnReciveResponse(...)` vào hàng đợi của OfflineNet (khung sau mới chạy,
	                đúng luật bất đồng bộ của net.lua)
	        -> không thuộc NHÓM: trả lại router cũ (hành vi KHÔNG đổi).

	SNAPSHOT: mỗi lượt gửi kèm TOÀN BỘ `OfflineStore.data` (39 bảng, đúng hình `worlds.data`)
	để handler server tính trên dữ liệu người chơi ĐANG CÓ. Từ 4/11 server CHỈ GHI ĐÈ khi bản lưu cục bộ **không cũ hơn** world của uid
	(xem khoi PHIEN BAN WORLD ben duoi). Truoc 4/11 moi luot deu GHI DE.
	(dieu nay doi duoc vi Axmol ghi cung bang worlds).
	Phản hồi mang `suKien` Data để client tự áp; sau khi áp xong cầu đồng bộ lại vào file lưu.

	BẬT/TẮT: `M.BAT` trong tệp, hoặc `M.NHOM[<objName>] = false`. Không có server / chưa
	đăng nhập / HTTP hỏng ⇒ **rơi về handler offline** (hoặc trả lỗi), KHÔNG bao giờ treo:
	client đã bật lớp "đang tải" trước khi gửi, nên mọi nhánh đều phải có câu trả lời.
]]

require("offline.log")
require("offline.store")
require("offline.router")
require("offline.tai_khoan")

OfflineNoiServer = OfflineNoiServer or {}

local M = OfflineNoiServer

M.BAT = true

--- Nhóm objName chuyển sang server. `G_LotteryLogic` = 4 khoá, đã port tay ở server
--- (`src/handlers/vong_quay.ts`, Mốc 31; có cả `DIAMOND_FREE = 5`).
-- CẢ objName: dùng khi server đã port TAY **mọi** khoá client gọi của obj ấy.
M.NHOM = {
	G_LotteryLogic = true,
	-- VÒNG QUAY MAY MẮN (Mốc 62, server `vong_quay_may_man.ts`, 5 khoá; đã kiểm bằng
	-- `test:vong_quay_may_man`). Client gọi: `ClientRefreshFortuneWheelList` /
	-- `ClientFreeRoll` / `ClientVipRoll` / hai khoá bánh tân thủ.
	G_FortuneWheelLogic = true,
	-- TRẬN PHÁP (server Mốc 46, `tran_phap.ts`, 3 khoá — TÁI DỰNG `[GHIM]`) và
	-- LUYỆN HERO (Mốc 47, `luyen_hero.ts`, 3 khoá — TÁI DỰNG + ĐO ÂM). Cả hai obj
	-- client gọi ĐÚNG các khoá ấy ⇒ route cả obj được.
	G_FormationLogic = true,
	G_HeroPracticeLogic = true,
	-- THÀNH TỰU (Mốc 35, 6 khoá) · HỘP THƯ (Mốc 32, 5 khoá): client gọi ĐÚNG bộ khoá
	-- server đã port.
	G_AchieveLogic = true,
	G_MailLogic = true,
	--⚠ `G_PotionLogic` ĐÃ GỠ 4/11 — ĐỪNG NỐI LẠI. Hệ thuốc CHẾT TRONG CHÍNH BẢN CLIENT
	-- này (`configCacheName.PotionConfig` bị chú thích trong `share_configManager.lua`
	-- :129/:146), nên hàm nhận `ClientPotionLogic:OnBuyPotion` chạy `PotionLogic:BuyPotion`
	-- → `PotionDataManager:updatePotionData` → `class.lua:66 'table index is nil'`.
	-- ĐO: 4 lượt nổ trong `offline.log` (3 lượt 3/11 + 1 lượt 4/11) — chỉ lượt nào có
	-- CẦU mới nổ, vì lớp offline CỐ Ý trả lỗi thay vì gọi hàm nhận (`tinh_nang.lua:393-417`).
	-- Server port ĐÚNG (`thuoc.ts`), nhưng client không tiêu được phản hồi thành công.
}

-- TỪNG KHOÁ `"<objName>.<funcName>"`: dùng khi server chỉ port MỘT PHẦN obj — route cả
-- obj sẽ đẩy các khoá chưa port sang nhánh "sinh" (rỗng), TỆ HƠN lớp offline.
M.KHOA = {
	-- Quà 7 ngày (server Mốc 43, `qua_7ngay.ts`) — một khoá.
	["G_SevenDaysGiftLogic.ClientSevenDaysGift"] = true,
	-- Điểm thạch thành kim (server Mốc 42, `diem_kim.ts`) — một khoá.
	["G_MidasTouchLogic.ClientRunMidasTouchWithCount"] = true,
	-- Thiên mệnh (server Mốc 44, `thien_menh.ts`) — hai khoá.
	["G_DestinyLogic.ClientActiveProgress"] = true,
	["G_DestinyLogic.ClientActiveProgressWithCount"] = true,
	-- Thẻ tháng (Mốc 45) · Phụ đề phó bản (Mốc 49) · Mã đổi quà (Mốc 50) ·
	-- Ghép + tự cường hoá trang bị (Mốc 54).
	["G_MonthlyCardLogic.ClientGetReward"] = true,
	["G_SubtitleLogic.ClientSetUserCopySubtitle"] = true,
	["G_SubtitleLogic.ClientGetCopySubtitle"] = true,
	["G_RedeemCodeLogic.ClientUseRedeemCode"] = true,
	["G_EquipmentLogic.ClientSynthesisEquipment"] = true,
	["G_EquipmentLogic.ClientAutoIntensifyEquipment"] = true,
	-- HANG ĐỘNG (Mốc 39): server chỉ port 5/8+ khoá client gọi ⇒ KHOA từng khoá.
	["G_CavernLogic.ClientCompeleteFight"] = true,
	["G_CavernLogic.ClientCompeleteProgress"] = true,
	["G_CavernLogic.ClientRevive"] = true,
	["G_CavernLogic.ClientResetCavern"] = true,
	["G_CavernLogic.ClientBuyCavernGoods"] = true,
	-- BẢNG XẾP HẠNG (Mốc 57/58/59): client gọi 20 khoá, server port tay 6 ⇒ KHOA.
	-- Đọc chéo `worlds` của MỌI uid ⇒ LDPlayer xuất hiện trong BXH của server.
	["G_RankLogic.ClientGetLevelRank"] = true,
	["G_RankLogic.ClientGetArenaDefendPowerRank"] = true,
	["G_RankLogic.ClientGet5HeroPowerRank"] = true,
	["G_RankLogic.ClientGetPveNormalRank"] = true,
	["G_RankLogic.ClientGetPveEliteRank"] = true,
	["G_RankLogic.ClientGetPveStarRank"] = true,
}

--[[ Bảng client CHƯA CÓ mà phản hồi server có thể ghi vào ⇒ tạo `{}` TRƯỚC.

	`CDataManager:WriteToTable` (`share_CDataManager.lua:391-410`) BỎ mục Data khi bảng
	vắng mặt và `KeyName ~= "Table_Add"` — im lặng. ĐO 3/11: `ClientResetCavern` chạy trên
	server (`worlds.data` có `GameUserCavern`) mà file lưu LDPlayer KHÔNG có bảng ấy.

	CHỈ những bảng dưới đây, và mỗi bảng phải CHỊU ĐƯỢC `{}` (client tự điền mặc định).
	TUYỆT ĐỐI không thêm `GameUserStarSoul`: nó phải là **NIL** lúc khởi động
	(`OfflineStore.TU_DUNG`), `{}` sẽ làm `GetUserStarSoulData` không tự lành. ]]
M.TAO_RONG = {
	GameUserCavern = true,
}

M.serial = 0
M.demGui, M.demNhan, M.demHong = 0, 0, 0

--[[ NGHỈ SAU KHI HỎNG (4/11). Mỗi lượt gọi server khi mất mạng phải CHỜ HTTP báo
	hỏng (đo được ~2 s) rồi mới rơi về handler offline ⇒ mở panel nào cũng khựng 2 s,
	dù lớp offline trả lời ngay. Sau MỘT lần hỏng, thôi gọi server trong `NGHI_GIAY`
	giây: `gui` trả `false` ⇒ `dispatch` chạy thẳng handler offline, tức thì.
	Lượt ĐẦU sau khoảng nghỉ mà thành công thì xoá mốc (server đã sống lại).
	ĐO: 26 bước `thu_cau_rpc` khi server tắt — trước vá 27 lượt gọi (27×2 s chờ),
	sau vá chỉ 1 lượt gọi hỏng rồi 25 bước còn lại đi thẳng offline. ]]
M.NGHI_GIAY = 30
M.hongLuc = nil

--[[ PHIÊN BẢN WORLD — luật "chỉ đẩy khi world cục bộ MỚI HƠN" (chủ dự án chốt 4/11).

	`worlds.version` của Postgres tăng mỗi lần có người ghi (Axmol qua WebSocket, hoặc
	chính cầu này khi nhận snapshot). Client gửi kèm `snapshotVersion` = phiên bản mà
	BẢN LƯU CỤC BỘ của nó dựa trên; server chỉ ghi đè khi số ấy >= phiên bản server.

	Vì sao cần: trước 4/11 mỗi lượt RPC đều GHI ĐÈ `worlds.data`. Nếu người chơi vừa
	chơi bên Axmol rồi mở LDPlayer với bản lưu cũ, lượt RPC đầu tiên xoá sạch tiến độ
	mới — im lặng, không lỗi.

	Lưu ở `offline_world_v.txt` cạnh file lưu (hai dòng: uid, version). Tệp vắng hoặc
	uid khác ⇒ `nil` (client chưa biết) ⇒ server chấp nhận MỘT lần rồi trả `v` để lưu.
	BỊ TỪ CHỐI (`tl.stale`) thì KHÔNG lưu `v` — lưu là lượt sau tự nhận "đã dựa trên
	world mới" và đẩy bản CŨ đè lên, phá đúng thứ vừa bảo vệ. ]]

local function thuMuc()
	local p = tostring(OfflineStore:path() or "")
	return (p:gsub("[^/]*$", ""))
end

function M:duongPhienBan()
	return thuMuc() .. "offline_world_v.txt"
end

--- Phiên bản world mà bản lưu cục bộ dựa trên; `nil` khi chưa biết / khác tài khoản.
function M:docPhienBan(uid)
	if uid == nil then return nil end
	local ok, fp = pcall(io.open, self:duongPhienBan(), "r")
	if not ok or fp == nil then return nil end
	local d1 = fp:read("*l")
	local d2 = fp:read("*l")
	fp:close()
	-- NGOẶC KÉP bắt buộc: `gsub` trả HAI giá trị (xem bẫy `tonumber` 4/11 ở `tai_khoan.lua`).
	local u = tonumber((tostring(d1 or ""):gsub("%s+", "")))
	local v = tonumber((tostring(d2 or ""):gsub("%s+", "")))
	if v == nil or u ~= tonumber(uid) then return nil end
	return v
end

function M:luuPhienBan(uid, v)
	if uid == nil or type(v) ~= "number" then return end
	local ok, fp = pcall(io.open, self:duongPhienBan(), "w")
	if not ok or fp == nil then
		OfflineLog:warn("noi_server: khong ghi duoc phien ban world")
		return
	end
	fp:write(tostring(uid), "\n", tostring(math.floor(v)), "\n")
	fp:close()
end

local function packv(...)
	local t = { ... }
	t.n = select("#", ...)
	return t
end

--- Đổi gói tham số thành MẢNG ĐẶC (JSON không có "vắng mặt" ở giữa mảng).
local function mang(t)
	local n = (type(t) == "table") and (t.n or #t) or 0
	local out = {}
	for i = 1, n do out[i] = t[i] end
	return out
end

function M:laNhom(strObj, strFunc)
	if type(strObj) ~= "string" then return false end
	if self.NHOM[strObj] == true then return true end
	return self.KHOA[strObj .. "." .. tostring(strFunc)] == true
end

--- Đẩy phản hồi về client qua ĐÚNG hàm nhận của giao thức.
--- `OnReciveResponse(cbObj, cbFunc, nErrCode, eventList, ...gui/them)`.
function M:traLoiVe(tl)
	local args = { n = 5, tl.obj or "", tl.cb or "", tl.err or 0, tl.suKien or {}, tl.gui }
	local them = tl.them
	if type(them) == "table" then
		for i = 1, #them do
			args.n = args.n + 1
			args[args.n] = them[i]
		end
	end
	-- Tạo rỗng (danh sách trắng) để `ChangeUserData` không bỏ mục Data.
	local dm0 = rawget(_G, "G_DataManager")
	local u0 = dm0 and dm0.userData
	if type(u0) == "table" and type(tl.suKien) == "table" then
		for _, ev in ipairs(tl.suKien) do
			if type(ev) == "table" and ev.EventType == 1 and type(ev.TableName) == "string"
					and u0[ev.TableName] == nil and ev.KeyName ~= "Table_Add"
					and self.TAO_RONG[ev.TableName] == true then
				u0[ev.TableName] = {}
				OfflineLog:info("noi_server: tao rong bang " .. ev.TableName)
			end
		end
	end

	local q = OfflineNet and OfflineNet.queue
	if type(q) ~= "table" then
		OfflineLog:err("noi_server: khong thay OfflineNet.queue — khong tra loi duoc")
		return
	end
	q[#q + 1] = { obj = "g_CUIGameRPCManager", func = "OnReciveResponse", args = args }
end

--- Đồng bộ lại thư mục lưu SAU khi `OnReciveResponse` đã áp mục Data (chạy ở nhịp sau).
function M:dongBo()
	pcall(function () OfflineStore:syncFromClient() end)
end

--- Gửi một lệnh sang server. Trả `true` nếu ĐÃ nhận trách nhiệm trả lời.
function M:gui(nModule, strObj, strFunc, tArgs)
	local tk = rawget(_G, "OfflineTaiKhoan")
	if tk == nil or tk.uid == nil then
		return false        -- chưa đăng nhập: để router offline trả lời
	end
	if type(rawget(_G, "sngHttpRequestWithString")) ~= "function" then
		return false        -- bộ thử PC / máy không có HTTP: để offline trả lời
	end
	-- Đang trong khoảng NGHỈ sau một lần hỏng ⇒ đi thẳng handler offline.
	if self.hongLuc ~= nil and (os.time() - self.hongLuc) < self.NGHI_GIAY then
		return false
	end

	OfflineStore:syncFromClient()
	self.serial = self.serial + 1
	local uid = tonumber(tk.uid)
	local body = {
		uid = uid,
		moudule = nModule,
		objName = strObj,
		funcName = strFunc,
		data = mang(tArgs),
		serial = self.serial,
		snapshot = OfflineStore.data,
		-- `nil` (chưa biết) ⇒ cjson BỎ khoá; server coi là "lần đầu", nhận một lượt.
		snapshotVersion = self:docPhienBan(uid),
	}
	self.demGui = self.demGui + 1
	OfflineLog:info(string.format("noi_server: gui %s.%s [%d]", strObj, strFunc, self.serial))

	tk:goi("/api/rpc", body, function (ok, tl)
		-- `ok` của lớp TÀI KHOẢN là `t.ok == true` (endpoint tài khoản có trường `ok`).
		-- `/api/rpc` trả `tl` KHÔNG có `ok` ⇒ `ok=false` ở đây KHÔNG phải lỗi.
		-- Điều kiện đúng: là BẢNG và có `err` (hình `tl`).
		if type(tl) ~= "table" or tl.err == nil then
			self.demHong = self.demHong + 1
			self.hongLuc = os.time()
			-- SERVER KHÔNG TRẢ LỜI ⇒ TRẢ LẠI LỚP OFFLINE (nếu có handler cho khoá ấy).
			-- Không làm thế thì mất server là MẤT LUÔN tính năng (mọi khoá trong NHOM/KHOA
			-- trả mã 1), dù lớp offline vẫn còn handler chạy tốt.
			local coLocal = OfflineRouter:getFor(strObj, strFunc) ~= nil
			OfflineLog:warn(string.format(
				"noi_server: %s.%s hong (ok=%s) — %s", strObj, strFunc, tostring(ok),
				coLocal and "chay handler OFFLINE" or "khong co handler offline, tra ma 1"))
			if coLocal and type(self.goc) == "function" then
				local n = (type(tArgs) == "table" and tArgs.n) or 0
				self.goc(OfflineNet, nModule, strObj, strFunc, unpack(tArgs, 1, n))
				return
			end
			self:traLoiVe({ obj = "", cb = "", err = 1, suKien = {} })
			return
		end
		self.demNhan = self.demNhan + 1
		self.hongLuc = nil
		-- BỊ TỪ CHỐI vì bản lưu cục bộ CŨ HƠN world trên server (thường: vừa chơi Axmol).
		-- KHÔNG lưu `tl.v`: xem chú thích khối PHIÊN BẢN WORLD ở trên.
		if tl.stale == true then
			OfflineLog:warn(string.format(
				"noi_server: %s.%s — WORLD CUC BO CU HON SERVER (v server = %s): "
				.. "khong day snapshot, khong chay handler; mo lai bang client da chay gan nhat",
				strObj, strFunc, tostring(tl.v)))
			self:traLoiVe(tl)          -- err = 1 ⇒ client báo lỗi + dừng lớp "đang tải"
			return
		end
		if type(tl.v) == "number" then
			self:luuPhienBan(uid, tl.v)
		end
		OfflineLog:info(string.format("noi_server: %s.%s -> err=%s cb=\"%s\" v=%s",
			strObj, strFunc, tostring(tl.err), tostring(tl.cb), tostring(tl.v)))
		self:traLoiVe(tl)
		if S_CCSchedule ~= nil and type(S_CCSchedule.scheduleOnce) == "function" then
			pcall(function () S_CCSchedule:scheduleOnce(self, "dongBo", 0.2) end)
		end
	end)
	return true
end

--- Bọc `OfflineNet.dispatch` — CHỈ nhóm trong `M.NHOM` đi qua cầu.
function M:cai()
	if self.DA_CAI then return true, "da cai" end
	if type(OfflineNet) ~= "table" or type(OfflineNet.dispatch) ~= "function" then
		OfflineLog:err("noi_server: khong thay OfflineNet.dispatch (net.lua chua cai?)")
		return false, "khong thay OfflineNet"
	end
	local goc = OfflineNet.dispatch
	self.goc = goc
	OfflineNet.dispatch = function (self2, nModule, strObj, strFunc, ...)
		if M.BAT and M:laNhom(strObj, strFunc) and M:gui(nModule, strObj, strFunc, packv(...)) then
			return
		end
		return goc(self2, nModule, strObj, strFunc, ...)
	end
	self.DA_CAI = true
	local ds = {}
	for k, v in pairs(self.NHOM) do if v then ds[#ds + 1] = k end end
	for k, v in pairs(self.KHOA) do if v then ds[#ds + 1] = k end end
	table.sort(ds)
	OfflineLog:info("noi_server: da noi cau RPC -> server cho: " .. table.concat(ds, ", "))
	return true, "da cai"
end

M:cai()

return OfflineNoiServer
