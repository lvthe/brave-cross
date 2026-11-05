--[[
	offline/handlers/login.lua — chuỗi vào game: đăng nhập -> bắt tay -> nạp dữ liệu.

	Đây là đường tối thiểu để game chạy tới màn hình chính. Trình tự thật, đọc
	ngược từ mã client:

	  1. client gọi StartRPC
	         -> offline/net.lua bắn OnConnected(rpc, true)
	  2. CUIGameRPCManager:OnConnected  (sc/user/Logical/CUIGameRPCManager.lua:10)
	         -> G_GameGateway:Handshake(key, channel)
	         -> CallServer(GAME_GATEWAY, "", "Handshake", ...)
	  3. ta trả G_GameGateway:OnServerConnected()
	         -> phát sự kiện GameGateway.OnServerConnected
	  4. client gọi G_GameWorld:EnterGame()
	         -> CallServer(GAME_LOGIC, "G_GameWorld", "ClientEnterGame")
	  5. ta trả G_GameWorld:OnServerEnterGame(errCode, tGameUserData, sngData,
	                                         tOtherData, tServerConfig)
	         -> ClientGameWorld:initData -> G_DataManager:Init(tGameUserData)

	Lưu ý về hình dạng phản hồi: KHÔNG phải handler nào cũng dùng bao bì
	{err=, data=}. OnServerEnterGame nhận 5 tham số vị trí
	(sc/user/Logical/ClientGameWorld.lua:37), nên ở đây dùng ctx:call chứ không
	dùng ctx:reply.
]]

require("offline.log")
require("offline.store")
require("offline.router")
require("offline.bootstrap")
require("offline.bao_offline")

local R = OfflineRouter

--------------------------------------------------------------------- đăng nhập

--[[ Máy chủ duy nhất — dùng chung cho cả phản hồi đăng nhập lẫn danh sách
	đề xuất. Địa chỉ là giả: StartRPC đã bị chặn nên không ai quay số.

	`state = 1` là SERVER_STATE.IDLE "流畅" (user_global.lua:25);
	`packageServerList` / `setSelectServer` chỉ đọc id, ip, name, state. ]]
local SERVER = {
	id = 1,
	ip = "127.0.0.1:1",
	name = "Offline",
	state = 1,
	IsRecommend = 1,
}

--[[ Phản hồi đăng nhập.
	ClientLogin:OnServerLogin(tData) chỉ đọc tData.fun rồi phát sự kiện cùng
	tên (sc/user/Logical/ClientLogin.lua:14), nên tData phải mang đúng tên sự
	kiện trong EventManagerLogicEvent.Login. ]]
--
-- Tên trường lấy từ chỗ client ĐỌC: tData.uid và tData.session viết thường
-- (CUILogin2.lua:3208 và :3211, CUIGameRPCManager.lua:255 và :259). uid thành
-- LoginLogicUid, rồi __sngLoginGame đưa nó vào SetRPCUid — là số mà
-- g_CUIGameRPCManager:GetUid() trả về, và CUIMain.lua:1336 in ra. Bản trước
-- gửi Uid / UserName / SessionId viết hoa, tên KHÔNG chỗ nào đọc.
--
-- `serverlist` BẮT BUỘC: onLoginLogic đưa thẳng nó vào
-- showEnterGameUI(tData.lastlist, tData.serverlist) (CUILogin2.lua:3237-3239);
-- không có thì self.tServerList vẫn nil, getLastServer(nil) ->
-- GetAuditServerList(nil) -> "bad argument #1 to 'ipairs'".
-- `lastlist` là máy chủ nhớ lần trước; để trống cũng được (showEnterGameUI
-- tự lấy phần tử cuối), nhưng gửi luôn cho khỏi phải đoán.
local function loginOK(ctx, strEvent, uid)
	ctx:call("G_Login", "OnServerLogin", {
		err = 0,
		fun = strEvent,
		uid = uid or OfflineBootstrap.UID,
		session = "offline-session",
		serverlist = { SERVER },
		lastlist = SERVER,
	})
end

--[[ 2/11 — TÀI KHOẢN GMAIL + MẬT KHẨU, lưu ở Postgres của bravecross-server.
	Ba khoá SDK KHÔNG còn tự đăng nhập: chuyển sang form tài khoản
	(`offline/tai_khoan.lua`). Máy chủ thật (SDK Kull) đã chết, nên đường SDK
	không còn nghĩa lý; tài khoản là thứ người chơi tự tạo. ]]
local function sdkSangTaiKhoan(ctx)
	OfflineLog:info("dang nhap SDK -> chuyen sang form tai khoan (gmail)")
	if OfflineTaiKhoan ~= nil then
		OfflineTaiKhoan.DA_MO = false
		OfflineTaiKhoan.DEM_CHO = 0
	end
end

R:on("ClientSdkLogin", sdkSangTaiKhoan)
R:on("ClientChannelLogin", sdkSangTaiKhoan)
R:on("ClientGPlayLogin", sdkSangTaiKhoan)

local function maLoi(res)
	return tonumber(res and res.code) or 3001   -- 3001 = mất kết nối
end

------------------------------------------------------------------- ĐĂNG KÝ
R:on("ClientRegister", function(ctx, szUserName, szPassword)
	local email = tostring(szUserName or ""):lower()
	local pass = tostring(szPassword or "")
	if OfflineTaiKhoan == nil or not OfflineTaiKhoan.BAT then
		-- Chế độ cũ / máy không có HTTP (bộ thử PC): giữ đường đăng nhập offline.
		return loginOK(ctx, "OnClientRegister", OfflineBootstrap.UID)
	end
	OfflineLog:info("dang ky tai khoan: " .. email)
	OfflineTaiKhoan:dangKy(email, pass, function (ok, res)
		if ok then
			OfflineTaiKhoan.uid = tonumber(res.uid)
			OfflineTaiKhoan.email = email
			OfflineTaiKhoan:luuEmail(email, res.uid)
			OfflineLog:info("dang ky thanh cong: uid=" .. tostring(res.uid))
			-- Hàm nhận `OnClientRegister` nằm trên **g_CUILogin** (UI), KHÔNG
			-- phải G_Login: `CUILogin:OnClientRegister(tData)` (CUILogin2.lua:3023).
			-- Gửi vào G_Login thì net.lua báo "client khong co ham nay" (đo 2/11).
			ctx:call("g_CUILogin", "OnClientRegister", {
				err = 0, UserName = email, IsNewAccount = true, userRegisterType = 12,
			})
		else
			OfflineLog:warn(string.format("dang ky that bai: %s (ma %s)",
				tostring(res.error), tostring(res.code)))
			ctx:call("g_CUILogin", "OnClientRegister", {
				err = maLoi(res), UserName = email, IsNewAccount = false, userRegisterType = 12,
			})
		end
	end)
end)

------------------------------------------------------------------- ĐĂNG NHẬP
R:on("ClientLogin", function(ctx, szUserName, szPassword)
	local email = tostring(szUserName or ""):lower()
	local pass = tostring(szPassword or "")
	if OfflineTaiKhoan == nil or not OfflineTaiKhoan.BAT then
		return loginOK(ctx, "OnClientLogin", OfflineBootstrap.UID)
	end
	OfflineLog:info("dang nhap tai khoan: " .. email)
	OfflineTaiKhoan:dangNhap(email, pass, function (ok, res)
		if ok then
			local uid = tonumber(res.uid)
			OfflineTaiKhoan.uid = uid
			OfflineTaiKhoan.email = email
			OfflineTaiKhoan:luuEmail(email, uid)
			-- `res.offline` = đường lùi "mất server" của `OfflineTaiKhoan:dangNhap`
			-- (không kiểm mật khẩu, chỉ kho cục bộ của đúng tài khoản này).
			if res.offline == true then
				OfflineLog:warn("dang nhap: CHE DO OFFLINE (khong co server) — uid="
					.. tostring(uid) .. ", van mo binh thuong")
				-- 4/11 (tiếp): người chơi PHẢI thấy — trước đây chỉ có trong log.
				if OfflineBao ~= nil then
					OfflineBao:dat("khong goi duoc server")
				end
			elseif OfflineBao ~= nil then
				OfflineBao:xoa()      -- vào bằng mạng ⇒ không báo nhầm
			end
			OfflineBootstrap.UID = uid or OfflineBootstrap.UID
			-- Nhân vật do NGƯỜI CHƠI tạo ở màn tạo nhân vật của client.
			OfflineBootstrap.NAME = nil
			OfflineStore:switchTo(uid)
			OfflineLog:info("dang nhap thanh cong: uid=" .. tostring(uid))
			loginOK(ctx, "OnClientLogin", uid)
		else
			OfflineLog:warn(string.format("dang nhap that bai: %s (ma %s)",
				tostring(res.error), tostring(res.code)))
			ctx:call("G_Login", "OnServerLogin", {
				err = maLoi(res), fun = "OnClientLogin",
			})
		end
	end)
end)

R:onAll({

	--[[ Danh sách máy chủ đề xuất — tấm thẻ "máy chủ + nhân vật lần trước".

		RỖNG là ĐÚNG: máy chủ thật chỉ đưa vào đây những máy chủ mà tài khoản ĐÃ
		có nhân vật. Tài khoản offline mới toanh thì không có cái nào.

		Đừng nhét SERVER vào: mỗi mục còn bị đọc như một hồ sơ nhân vật —
		CharacterName, Portrait, Gender, VipLevel, Level, Ex
		(CUILoginServerList.lua:849-944 → CUITavern:GetHeroExPercentage), thiếu
		Level/Ex là `KDebug: Arg must be number!` và vỡ cả luồng đăng nhập.

		'serverlist' giữ lại vì mã test của chính bản gốc đọc nó
		(test/TestLogin.lua). ]]
	ClientGetRecomendServers = function(ctx)
		ctx:call("G_Login", "OnServerLogin", {
			err = 0,
			fun = "OnClientGetRecomendServers",
			RecomendList = {},
			serverlist = { SERVER },
		})
	end,
})

----------------------------------------------------------------- bắt tay cổng

R:on("Handshake", function(ctx)
	OfflineLog:info("bat tay — bo qua kiem tra phien ban va khoa")
	ctx:call("G_GameGateway", "OnServerConnected")
end)

--------------------------------------------------------------------- vào game

--[[ Dữ liệu ngoài userData mà OnServerEnterGame nhận.

	tOtherData đi qua ClientGameWorld:DealOtherData: nó chỉ đọc .ConfigMap và
	.Activity, và đều kiểm tra nil trước, nên bảng rỗng là hợp lệ.
	tServerConfig chỉ được đọc lại qua GetServerConfig -> CUIAssist.getValue,
	vốn chịu được nil. ]]
local function otherData()
	return {}
end

local function serverConfig()
	return {
		ServerId = 1,
		ServerName = "Offline",
		OpenTime = os.time() - 86400,   -- ĐẶT: coi như máy chủ mở từ hôm qua
	}
end

--[[ Giờ server. ClientGameWorld:EnterGame gọi cái này TRƯỚC ClientEnterGame
	(ClientGameWorld.lua:259); không có thì GetServerTime() lấy mốc 0.

	Chỉ gửi giờ, KHÔNG gửi múi giờ: client chỉ dùng iTimeZone qua
	os.dateSetServerTimeZone — phần mở rộng của engine gốc (ClientGameWorld
	.lua:223) — và không có chỗ nào khác ghi múi giờ của server VN, nên không
	có con số nào để gửi mà không bịa. ]]
R:on("ClientUpdateServerTimeEx", function(ctx)
	ctx:call("G_GameWorld", "OnUpdateServerTimeEx", os.time())
end)

R:on("ClientEnterGame", function(ctx)
	--[[ 2/11: vào game theo TÀI KHOẢN vừa đăng nhập. `switchTo` nạp kho riêng
		của uid (file `offline_save_<uid>.json`); tài khoản mới thì chưa có file
		và `ensure()` dựng người chơi mới. ]]
	if OfflineTaiKhoan ~= nil and OfflineTaiKhoan.uid ~= nil then
		OfflineBootstrap.UID = tonumber(OfflineTaiKhoan.uid) or OfflineBootstrap.UID
		OfflineBootstrap.NAME = nil
		OfflineStore:switchTo(OfflineTaiKhoan.uid)
	end
	local bNew = OfflineBootstrap:ensure()

	--[[ CHƯA CÓ NHÂN VẬT ⇒ 1001 `NeedCreateCharacter`.

		Client `CUILogin:OnServerEnterGame(errCode)` (`CUILogin2.lua:3542`) thấy
		1001 thì mở màn tạo nhân vật. Tạo xong nó gọi `G_GameWorld:EnterGame()`
		lại; lúc ấy `CharacterName` đã có nên đi đường bình thường. ]]
	local tenNhanVat = OfflineStore:get("GameUserBaseInfo", "CharacterName")
	if type(tenNhanVat) ~= "string" or tenNhanVat == "" then
		OfflineLog:info("vao game: chua co nhan vat -> 1001 (mo man tao nhan vat)")
		-- Dấu cho đồ thử biết màn tạo nhân vật vừa được mở.
		Offline = Offline or {}
		Offline.CAN_TAO_NHAN_VAT = true
		ctx:call("G_GameWorld", "OnServerEnterGame", 1001)
		return
	end
	Offline = Offline or {}
	Offline.CAN_TAO_NHAN_VAT = false

	local tUserData = OfflineStore:all()

	--[[ Chốt mốc "lần vào game trước".

		`ClientGameWorld:CheckIsOverDay` (ClientGameWorld.lua:328-354) gọi
		`getIsDailyFirstEnterGame(nLastEnterGameTime, nEnterGameTime, …)`; hàm
		gốc coi là **lần đầu trong ngày** khi
		`nEnterGameTime - nLastEnterGameTime > 86400` (share_gameWorld.lua:21).
		Không đặt `LastEnterGameTime` thì lần nào cũng "ngày mới" ⇒ nó gọi lại
		`EnterGame()` ⇒ `ClientEnterGame` lặp **hàng chục lần mỗi giây**, kéo theo
		kịch bản hướng dẫn chạy lại và phát thưởng liên tục (đo 27/10 00:01 —
		vết gọi: CUIMain event → CheckIsOverDay → EnterGame).

		Nay ghi mốc ngay trước khi trả dữ liệu, đúng như máy chủ thật vẫn làm.

		PHẢI GHI VÀO `tUserData` — bảng SẮP GỬI cho client — chứ không phải
		vào `G_UserDataManager:GetUserGlobalData()` (bảng của phiên ĐANG sống).
		`OnServerEnterGame` THAY dữ liệu client bằng `tUserData` lấy từ file
		lưu; ghi vào bảng kia thì mốc ấy bị đè lại bởi mốc cũ trong file, và
		càng để lâu càng chắc chắn lỗi: `getIsDailyFirstEnterGame` còn rẽ nhánh
		theo NGÀY qua `os.date("*t")` với `DialyRefreshHour = 5`
		(share_gameWorld.lua:29-37) — sang ngày mới là "lần đầu trong ngày"
		⇒ lặp lại vô hạn. ĐO 27/10 20:07: `vao game lan 6285` trong ~30 phút,
		vì mốc trong file vẫn là 26/10 23:04. ]]
	local tGlobal = type(tUserData.GameUserGlobalData) == "table"
		and tUserData.GameUserGlobalData or nil
	if tGlobal == nil then
		tGlobal = {}
		tUserData.GameUserGlobalData = tGlobal
	end
	tGlobal.LastEnterGameTime = os.time()
	tGlobal.ContinuesEnterGameCount = 1

	OfflineLog:info(string.format("vao game (%s), %d bang du lieu",
		bNew and "nguoi choi moi" or "nap tu file luu", OfflineStore:count()))

	-- errCode, tGameUserData, sngData, tOtherData, tServerConfig
	--
	-- Lực chiến KHÔNG điền ở đây. Máy chủ thật tính sẵn số ấy rồi mới gửi khối
	-- dữ liệu xuống (share_HeroLogic.lua:113), nên lớp này phải làm thay — nhưng
	-- phải làm SAU khi khối dữ liệu vào tới client, mà `ctx:call` chỉ ĐẨY vào
	-- hàng đợi rồi khung hình sau mới chạy (net.lua:116 -> :235). Đo được:
	-- đặt ở đây thì `offline.log` ghi `luc chien: dien 0/0 tuong` và nhãn `Lực`
	-- vẫn ra 0. Việc điền nối vào sự kiện `OnEnterGame` — xem
	-- `OfflineLucChien:noi_su_kien` (offline/luc_chien.lua).
	ctx:call("G_GameWorld", "OnServerEnterGame",
		0, tUserData, {}, otherData(), serverConfig())

	-- Dấu cho harness: đã vào game (tu_dong dùng để tắt hướng dẫn tân thủ).
	Offline = Offline or {}
	Offline.LAN_VAO_GAME = (Offline.LAN_VAO_GAME or 0) + 1
	OfflineLog:info("vao game lan " .. tostring(Offline.LAN_VAO_GAME))

	-- 4/11 (tiếp): đường lùi "mất server" đã `dat()` cờ ở `ClientLogin`; hẹn hiện câu
	-- báo SAU khi cảnh Main dựng xong. Không có cờ thì `hen()` trả false, vô hại.
	if OfflineBao ~= nil then OfflineBao:hen() end
end)

--[[ TẠO NHÂN VẬT (`ClientUserLogic:CreateCharacter`).

	Bản gốc trả callback `OnCreateCharacter` là hàm TOÀN CỤC
	(`CServerResponseLogic.lua:5`) — hàm ấy chỉ đẩy một notification, KHÔNG có
	người nghe (grep 0 lượt Reg). Nhưng client CÓ `G_UserLogic:OnCreateCharacter`
	(`ClientUserLogic.lua:28`) — đúng hàm đẩy sự kiện Logic mà
	`CUILogin:OnCreateCharacter` (`CUILogin2.lua:2842`) đang chờ để gọi
	`G_GameWorld:EnterGame()`. Nên gọi thẳng hàm ấy với mã 0 (số, không phải
	bảng: nó đưa thẳng vào `PostLogicEvent`). ]]
R:on("ClientCreateCharacter", function(ctx, szName, bGender)
	if type(szName) == "string" and szName ~= "" then
		-- Client đọc tên ở CharacterName (UserLogicDataManager.lua:209).
		OfflineStore:set("GameUserBaseInfo", "CharacterName", szName)
		OfflineStore:set("GameUserBaseInfo", "Gender", bGender == true)
		OfflineStore:save()
		OfflineLog:info("tao nhan vat: " .. szName
			.. " (gioi tinh " .. (bGender == true and "nam" or "nu") .. ")")
	end
	ctx:call("G_UserLogic", "OnCreateCharacter", 0)
end)

--[[ Danh sách hoạt động — bước cuối của chuỗi vào game.

	CUILogin:sngEnterGame -> G_ActivityLogic:CallGetActivityList -> đây. Hàm
	client nhận nó đặt dữ liệu rồi gọi g_CSceneManager:RepaleceScene("Main")
	(ClientActivitiesLogic.lua:99-104): đây là cửa vào cảnh chính.

	Không có server thì không có lịch hoạt động: bảng cấu hình để RỖNG. Phải
	chỉ tên hàm tay — client viết sai chính tả 'OnGetAcvitityList', nên
	cách dò tên của ctx:reply không ra.

	MỘT NGOẠI LỆ — `TimeLimitSoulBoxHero` (魂匣) bật THƯỜNG TRỰC (28/10).
	Lý do: `ClientLotteryLogic:CheckSoulBoxIsOpen` (`ClientLotteryLogic.lua:14`)
	ĐÈ hàm lớp cha và chỉ hỏi HOẠT ĐỘNG có đang mở không; offline không có
	lịch vận hành nên hộp hồn vĩnh viễn "chưa mở" dù `VipUnlockConfig.HeroSoulBoxLevel
	= 0` (luôn đạt). Đây là QUYẾT ĐỊNH CỦA LỚP OFFLINE (bật sự kiện quanh năm),
	KHÔNG phải dữ liệu gốc: trường ngày bắt đầu/kết thúc do bản gốc cấp.
	Nội dung hộp (bể tướng, trọng số) vẫn lấy từ `GameSoulBoxConfig`.

	31/10: LỊCH CHUYỂN VỀ `offline/hoat_dong.lua` — một nguồn duy nhất cho trạng
	thái + cấu hình hoạt động (nay mở thêm Quỹ cấp / Quỹ thời gian). Ở đây chỉ còn
	một lời gọi; xem đầu tệp ấy để biết chỗ nào là dữ liệu THẬT và chỗ nào là [MOI]. ]]
R:on("ClientGetActivityList", function(ctx)
	if type(OfflineHoatDong) ~= "table" then
		-- Không có module lịch thì vẫn phải trả lời, nếu không cảnh Main không dựng.
		OfflineLog:err("hoat dong: thieu OfflineHoatDong — tra danh sach RONG")
		ctx:call("G_ActivityLogic", "OnGetAcvitityList", {}, {})
		return
	end
	local trangThai, cauHinh = OfflineHoatDong:layDanhSach()
	OfflineLog:info(string.format("hoat dong: tra %d hoat dong",
		(function ()
			local n = 0
			for _ in pairs(trangThai) do n = n + 1 end
			return n
		end)()))
	ctx:call("G_ActivityLogic", "OnGetAcvitityList", trangThai, cauHinh)
end)

---------------------------------------------------------------- nuốt lặng lẽ

--[[ Không có phản hồi và không chạm trạng thái chơi: nhịp tim, thống kê,
	báo cáo. Liệt kê ra đây để chúng không làm nhiễu offline.log.

	Ba cái cuối là "bắn rồi quên" của ClientUserLogic (chỉ CallServer, không
	PostLogicEvent OnWaitingForRequest — ClientUserLogic.lua:131-145), nên
	nuốt lặng là đúng, không phải bỏ sót. ]]
R:ignore(
	"Heartbeat",
	"TickFromClient",
	"ClientReportClientInfo",
	"ClientStatistics",
	"ClientSetGuideStepComplete",
	"ClientSetSchemeComplete",
	"ClientSetSchemeBegin",
	"ClientEnterChannel",
	"ClientGetUserFriends",
	-- ClientGameWorld.lua:78 gửi lúc vào game, KHÔNG có hàm Lua nào nhận phản
	-- hồi (chỉ có CUIPerks/CUINewHandPrivilege đăng ký sự kiện riêng) ⇒ bắn
	-- rồi quên.
	"ClientGetUserNewHandPrivilegeInfo",
	-- Client tự lưu "client common data" (ClothingData, SevenDaysGiftData…) lên
	-- máy chủ; dữ liệu đã có ngay trong client và được dựng lại mỗi phiên, nên
	-- trong chế độ offline không cần phản hồi.
	"ClientSetClientCommonData",
	-- Máy chủ gốc chỉ LƯU cờ mở chức năng (`G_UserLogic:SetCommonData` đã ghi
	-- tại máy rồi mới gửi — khoá `L_<tên>` trong GameUserGlobalData), nên không
	-- có phản hồi nào để trả. Phát hiện 28/10 khi đồ thử nâng cấp đặt cờ.
	"ClientSetGameFuncUnLockData"
)
return true
