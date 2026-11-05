--[[
	offline/tu_dong.lua — tự đăng nhập và tự vào máy chủ, để chạy harness
	(trace Frida trong trận) mà không phải bấm màn hình.

	Vì sao cần: AVD ARM này chậm tới mức mỗi phép `screencap`/`dumpsys` đều
	có giá, còn `system_server` thì đã hai lần bị watchdog giết giữa lượt.
	Càng ít thao tác trên UI càng đỡ vỡ.

	Hai bước, đúng như người chơi bấm:

	  1. màn Đăng Nhập  -> điền tên/mật khẩu rồi gọi chính handler của nút
	                       (`CUILogin:onTouchEnd_OnLogin`, CUILogin2.lua:1984)
	                       -> G_Login:Login -> lớp offline trả OnServerLogin
	  2. màn chọn máy chủ -> `CUILogin:loginGame` (CUILogin2.lua:1885)
	                       -> ClientEnterGame -> lớp offline trả OnServerEnterGame

	Dừng ở màn chính; phần vào ải để người/script khác quyết định.

	Tắt: đặt biến môi trường Lua `OfflineTuDong.TAT = true` trước khi nạp,
	hoặc xoá `require("offline.tu_dong")` ở `offline/init.lua`.
]]

require("offline.log")

OfflineTuDong = OfflineTuDong or {}

OfflineTuDong.TAT = false
OfflineTuDong.BUOC = 0        -- 0 chờ đăng nhập · 1 chờ danh sách máy chủ · 2 xong
OfflineTuDong.DEM = 0
OfflineTuDong.TEN = "offline"
OfflineTuDong.MAT_KHAU = "123456"

local function hien(node)
	if node == nil then return false end
	local ok, v = pcall(function () return node:isVisible() end)
	return ok and v or false
end

local function goi(ten, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		OfflineLog:err("tu_dong " .. ten .. ": " .. tostring(err))
	end
	return ok
end

--[[ CHẾ ĐỘ NGƯỜI CHƠI (4/11): tệp `nguoi_choi.flag` cạnh file lưu.

	Cờ này chỉ tắt HAI việc can thiệp vào hướng dẫn tân thủ:
	  · gọi `FinishGudie()` (đóng kịch bản) — bản test cần để không kẹt;
	  · tự bấm "Đi tiếp" trong khung thoại.

	Lý do: người chơi thật PHẢI tự đi qua hướng dẫn. ĐO 4/11: mỗi nhịp `tu_dong`
	gọi `FinishGudie` khi `tListener` khác "GuideShowDialog" (vd `BattleSelectLevel`)
	⇒ kịch bản bị cắt ngay khi vừa hiện, bong bóng thoại hiện lại liên tục.

	VẪN GIỮ: tự đăng nhập / bấm vào game, đóng popup thưởng, đóng panel "Nhận cánh"
	(những thứ ấy không có lối thoát hoặc chặn màn — bỏ đi là kẹt thật).
	`mo_game.cmd` tạo cờ này trước khi spawn và xoá sau khi driver thoát. ]]
function OfflineTuDong:laNguoiChoi()
	if self._nguoiChoi ~= nil then return self._nguoiChoi end
	local v = false
	pcall(function ()
		local p = tostring(OfflineStore:path() or ""):gsub("[^/]*$", "")
		local f = io.open(p .. "nguoi_choi.flag", "r")
		if f then f:close(); v = true end
	end)
	self._nguoiChoi = v
	if v then
		OfflineLog:info("tu_dong: CHE DO NGUOI CHOI — khong dong huong dan, khong tu bam thoai")
	end
	return v
end

function OfflineTuDong:tick()
	if self.TAT then return end
	self.DEM = self.DEM + 1

	--[[ ĐÃ VÀO CẢNH MAIN ⇒ chặng đăng nhập xong, KHÔNG gọi `loginGame` nữa.

		ĐO 2/11 22:51: cửa sổ "Vào game" bị huỷ khi cảnh Main thay thế
		(`lLoginEnterGameUI = nil`), nhưng tu_dong vẫn ở BUOC 0; hết 5 nhịp chờ
		nó gọi `loginGame` -> `callGameRPC` -> `g_buyLoadingDialog:Show()`
		(CUILogin2.lua:3387) rồi NỔ ở `closeEnterGameUI` (:3397, index nil)
		⇒ LỚP ĐANG TẢI KẸT VĨNH VIỄN, Main nuốt mọi cú bấm (`CUIManager:131`).
		Chỉ cần thấy cảnh Main là đủ để đóng chặng đăng nhập. ]]
	local canh = nil
	pcall(function () canh = g_CSceneManager:GetCurrentSceneName() end)
	if canh == "Main" and self.BUOC ~= 2 then
		self.BUOC = 2
		OfflineLog:info("tu_dong: da o canh Main — bo qua buoc dang nhap")
	end

	--[[ Tự đóng LỚP THƯỞNG (CUIRewardLayer).

		Kịch bản hướng dẫn chờ sự kiện `Reward_Hide` SAU khi phát thưởng
		(`CGuideScheme.lua:4358-4364`); sự kiện ấy chỉ được phát trong
		`CUIRewardLayer:onClose()` (`CUIRewardLayer.lua:191`). Trên LDPlayer,
		popup "Nhận Thưởng" hiện ra rồi **nuốt mọi cú bấm** — không đóng được
		⇒ guide kẹt vĩnh viễn, mỗi lần đăng nhập lại kẹt lại.

		Chế độ offline không cần người bấm: gọi đúng đường của nút đóng
		(`onTouchEnd_OnClose`) — nhịp 1 chạy hết hoạt ảnh (`_forceShowAll`),
		nhịp 2 đóng thật. ]]
	if G_CUIRewardLayer ~= nil and G_CUIRewardLayer.bVisible == true then
		self.DEM_THUONG = (self.DEM_THUONG or 0) + 1
		if self.DEM_THUONG >= 2 then
			self.DEM_THUONG = 0
			local ok, err = pcall(function ()
				G_CUIRewardLayer:onTouchEnd_OnClose(nil, true)
			end)
			if not ok then
				OfflineLog:warn("tu_dong: dong lop thuong loi: " .. tostring(err))
				pcall(function () G_CUIRewardLayer:onClose() end)
			end
		end
	else
		self.DEM_THUONG = 0
	end

	-- Popup "Quà Login …" cũng phủ tối và nuốt cú bấm — tự đóng để không kẹt.
	if g_CUILoginReward ~= nil and g_CUILoginReward.bVisible == true then
		self.DEM_LOGIN = (self.DEM_LOGIN or 0) + 1
		if self.DEM_LOGIN >= 3 then
			self.DEM_LOGIN = 0
			pcall(function () g_CUILoginReward:onClose() end)
			OfflineLog:info("tu_dong: da dong popup Qua Login")
		end
	else
		self.DEM_LOGIN = 0
	end

	--[[ PANEL "NHẬN CÁNH" KHÔNG CÓ NÚT ĐÓNG — van an toàn.

		ĐO 26/10 và đo lại 28/10 00:46: mở từ thanh trên ("Nhận"/T.Trang) thì panel
		`g_CUIWingGet` phủ màn và **không có đường thoát**: BACK (`keyevent 4`) và
		bấm ra ngoài đều không ăn, phải khởi động lại game. Nó được mở bằng
		`g_CUISubDialog:Show(g_CUIWingGet.UIName, …)` (`CUIMainTopTool.lua:1213`),
		nên đóng bằng đúng `g_CUISubDialog:Close()` — lối `CUILoginReward` và
		`CGuideScheme` vẫn dùng.

		Chỉ đóng khi đã hiện **30 nhịp** (30 s): đủ để người chơi đọc/claim nếu đủ
		điều kiện (Lv10 + đăng nhập ngày 2), mà không kẹt vĩnh viễn. ]]
	if g_CUIWingGet ~= nil and g_CUISubDialog ~= nil
			and g_CUIWingGet.IsUIShow ~= nil then
		local bHien = false
		pcall(function () bHien = g_CUIWingGet:IsUIShow() == true end)
		if bHien then
			self.DEM_CANH = (self.DEM_CANH or 0) + 1
			if self.DEM_CANH >= 30 then
				self.DEM_CANH = 0
				local ok, err = pcall(function () g_CUISubDialog:Close() end)
				OfflineLog:info("tu_dong: dong panel Nhan canh sau 30s -> "
					.. tostring(ok) .. (ok and "" or (" (" .. tostring(err) .. ")")))
			end
		else
			self.DEM_CANH = 0
		end
	end

	--[[ TẮT HƯỚNG DẪN TÂN THỦ (chế độ offline).

		Đo trên máy 27/10: kịch bản hướng dẫn **không lưu tiến trình**, nên cứ tới
		cảnh Main là nó chạy lại và gọi `ClientReachAchieve(1012)` / `(1009)`
		**liên tục ~0,5 s một lần** (log dày đặc), mỗi vòng lại phát thưởng ⇒
		popup "Nhận Thưởng" hiện lại và khoá màn hình.

		Bản gốc có sẵn hàm kết thúc hướng dẫn — `CGuideScheme_FinishGudie`
		(CGuideScheme.lua:4384-4390) gọi đúng `g_CGuideLogical:FinishGudie()`.

		GỌI LẶP, không một lần: đo lại 27/10 20:5x, sau khi mở khoá một binh
		chủng (bước `ClientUnlockArmy` của chính kịch bản) và quay về Main,
		"Offline: Mậu đi giải khóa Binh Chủng mới nào!" hiện LẠI, kèm lớp chặn
		vô hình nuốt mọi cú bấm trên bản đồ chương. Kịch bản không lưu tiến
		trình nên mỗi lần vào cảnh Main nó khởi động lại từ đầu; đóng một lần
		không đủ.

		ĐO LẠI 28/10 00:20: ngoài bước THOẠI, kịch bản còn những bước chờ SỰ KIỆN
		GIAO DIỆN (`tListener = "OnShowUI"`). Ở các bước đó nó đặt
		`SetSceneCanTouch(false)` — nuốt mọi cú bấm — và `tListener` chỉ về nil khi
		`FinishGudie` chạy; chu kỳ 10 nhịp để lại **tới 10 giây** màn hình chết,
		đủ làm hỏng mọi script bấm theo nhịp ngắn.

		Nay: thấy `tListener` khác nil và KHÔNG phải bước thoại thì đóng NGAY nhịp
		đó (bước thoại để watchdog dưới tự bấm qua, giữ được mạch kịch bản); ngoài
		ra vẫn quét mỗi 10 nhịp cho chắc. `FinishGudie` đặt
		`currCorountine/tListener = nil`, ẩn lớp và `SetSceneCanTouch(true)`. ]]
	if not self:laNguoiChoi()
			and Offline ~= nil and (Offline.LAN_VAO_GAME or 0) > 0
			and g_CGuideLogical ~= nil and g_CGuideLogical.FinishGudie ~= nil then
		self.DEM_VAO = (self.DEM_VAO or 0) + 1
		local cho = g_CGuideLogical.tListener
		local dongNgay = cho ~= nil and cho ~= "GuideShowDialog"
		if dongNgay or self.DEM_VAO >= 10 then
			self.DEM_VAO = 0
			local ok, err = pcall(function () g_CGuideLogical:FinishGudie() end)
			if not ok then
				OfflineLog:warn("tu_dong: dong huong dan loi: " .. tostring(err))
			elseif self.DA_TAT_GUIDE ~= true or dongNgay then
				self.DA_TAT_GUIDE = true
				OfflineLog:info(string.format(
					"tu_dong: dong huong dan (dang cho %s)", tostring(cho)))
			end
		end
	end

	--[[ TỰ BẤM "ĐI TIẾP" CHO KHUNG THOẠI HƯỚNG DẪN.

		Đo 27/10 21:0x: `FinishGudie()` trả true nhưng khung thoại
		"Offline: Mậu đi giải khóa Binh Chủng mới nào!" VẪN hiện lại mỗi lần
		vào cảnh Main, và nó phủ một lớp nuốt mọi cú bấm (bấm node bản đồ
		chương không ăn). Đó KHÔNG phải `g_DramaSystem` (thoại cốt truyện) mà
		là hộp thoại của chính hướng dẫn: `CGuideLogical:ShowDialog`
		(`CGuideLogical.lua:140`) vẽ vào node `clUIMainGuide`, tag 1 (trái) /
		tag 2 (phải).

		Đường người chơi bấm chính là `CGuideLogical:onTouchEnd_onGuideGoNext`
		(:559): ẩn node, gọi callback rồi `continueGuide("GuideShowDialog")`
		để kịch bản chạy câu kế. Gọi đúng hàm ấy — KHÔNG tự ẩn node, vì kịch
		bản sẽ đứng ở `coroutine.yield()` mãi. `obj` phải khác nil
		(`KDebug.ArgsIsNil(obj, …)` chặn ngay đầu hàm) nên truyền
		`clUIMainGuide`. Chỉ gọi khi thật có khung thoại đang hiện, để không
		giẫm lên bước chỉ-tay (tag 3) hay lúc không có hướng dẫn. ]]
	--[[ Ghi lại KHOÁ hướng dẫn đang chờ mỗi khi nó ĐỔI. Đây là bản đồ các bước
		của kịch bản tân thủ trong lượt chơi thật (khoá chính là tên nút/biến mà
		`CGuideScheme` yield) — dùng để biết bước kế tiếp là gì mà điều khiển,
		không phải đoán toạ độ. Chỉ ghi khi đổi, nên nhật ký không phình. ]]
	if g_CGuideLogical ~= nil then
		local khoa = tostring(g_CGuideLogical.tListener)
		if khoa ~= self.TLISTENER then
			self.TLISTENER = khoa
			OfflineLog:info("tu_dong: huong dan cho khoa = " .. khoa)
		end
	end

	if not self:laNguoiChoi()
			and Offline ~= nil and (Offline.LAN_VAO_GAME or 0) > 0
			and clUIMainGuide ~= nil and g_CGuideLogical ~= nil
			and g_CGuideLogical.onTouchEnd_onGuideGoNext ~= nil then
		--[[ Cổng đúng: `tListener` là KHOÁ mà coroutine hướng dẫn đang chờ
			(`coroutine.yield("GuideShowDialog")` — CGuideScheme.lua:77, :84, …),
			và `continueGuide` (:823-860) CHỈ resume khi khoá trùng. Nhờ vậy gọi
			hàm này khi hướng dẫn đang chờ việc khác là vô hại.

			ĐỪNG dò bằng `clUIMainGuide:isVisible()`: đo 27/10 21:27, `clUIMainGuide`
			là userdata KHÔNG có `isVisible` (nổ "attempt to call method 'isVisible'
			(a nil value)") — bản dò cũ vì thế không bao giờ chạy. ]]
		if g_CGuideLogical.tListener == "GuideShowDialog" then
			local ok, err = pcall(function ()
				g_CGuideLogical:onTouchEnd_onGuideGoNext(clUIMainGuide, true)
			end)
			if ok then
				self.DEM_THOAI = (self.DEM_THOAI or 0) + 1
				if self.DEM_THOAI <= 20 or self.DEM_THOAI % 20 == 0 then
					OfflineLog:info("tu_dong: tu bam qua thoai huong dan (lan "
						.. self.DEM_THOAI .. ")")
				end
			else
				OfflineLog:warn("tu_dong: bam qua thoai loi: " .. tostring(err))
			end
		end
	end



	-- Bước 1: màn đăng nhập của client đã hiện chưa
	if self.BUOC == 0 then
		-- Đường LDPlayer: hook Kull SDK đã đăng nhập sẵn nên màn "Vào game"
		-- hiện ra mà KHÔNG qua màn điền tài khoản — bấm thẳng.
		if hien(lLoginEnterGameUI) then
			self.BUOC = 2
			OfflineLog:info("tu_dong: thay man 'Vao game' (SDK da dang nhap), goi loginGame")
			goi("loginGame", function () g_CUILogin:loginGame() end)
			return
		end
		-- Dự phòng khi không dò được cửa sổ: LoginLogicUid có nghĩa là server
		-- (lớp offline) đã nhận đăng nhập; chờ vài nhịp cho UI dựng xong rồi vào.
		local uid = g_CUILogin and g_CUILogin.LoginLogicUid
		if uid ~= nil then
			if self.UID_TICK == nil then
				self.UID_TICK = self.DEM
				OfflineLog:info("tu_dong: da dang nhap (uid=" .. tostring(uid) .. "), cho UI")
			elseif self.DEM >= self.UID_TICK + 5 and lLoginEnterGameUI ~= nil then
				-- CHỈ gọi khi cửa sổ còn thật: `loginGame` -> `callGameRPC` index
				-- `lLoginEnterGameUI` trong `closeEnterGameUI`, nil là nổ SAU KHI
				-- đã Show lớp đang tải (xem đầu tick).
				self.BUOC = 2
				OfflineLog:info("tu_dong: goi loginGame (du phong, khong thay cua so)")
				goi("loginGame", function () g_CUILogin:loginGame() end)
			end
			return
		end
		if g_CUILogin == nil or ebUserLoginName == nil or ebUserLoginPassword == nil then
			return
		end
		--[[ CHẾ ĐỘ TÀI KHOẢN: KHÔNG tự điền / tự đăng nhập hộ.

			Từ 2/11 màn đăng nhập là form GMAIL + MẬT KHẨU của người chơi
			(`offline/tai_khoan.lua`). Tự điền "offline"/"123456" ở đây là
			đăng nhập sai tài khoản rồi kẹt. Chỉ bỏ qua bước ĐIỀN; phía trên,
			nhánh chờ `LoginLogicUid` (sau khi người chơi đăng nhập xong) vẫn
			chạy để tự bấm vào game. ]]
		if OfflineTaiKhoan ~= nil and OfflineTaiKhoan.BAT then
			return
		end
		if not hien(lLoginInputUI) then
			return
		end
		self.BUOC = 1
		OfflineLog:info("tu_dong: thay man dang nhap, dien tai khoan")
		goi("dien ten", function () ebUserLoginName:setText(self.TEN) end)
		goi("dien mat khau", function () ebUserLoginPassword:setText(self.MAT_KHAU) end)
		goi("bam dang nhap", function ()
			local ok = g_CUILogin:onTouchEnd_OnLogin(nil, true)
			OfflineLog:info("tu_dong: onTouchEnd_OnLogin -> " .. tostring(ok))
		end)
		return
	end

	-- Bước 2: danh sách máy chủ (lLoginEnterGameUI) đã hiện thì vào game
	if self.BUOC == 1 then
		if not hien(lLoginEnterGameUI) then
			return
		end
		self.BUOC = 2
		OfflineLog:info("tu_dong: thay man chon may chu, goi loginGame")
		goi("loginGame", function () g_CUILogin:loginGame() end)
		return
	end
end

function OfflineTuDong:batDau()
	if self.TAT then
		OfflineLog:info("tu_dong: TAT, khong tu dang nhap")
		return
	end
	if S_CCSchedule == nil then
		OfflineLog:err("tu_dong: khong thay S_CCSchedule — khong tu dang nhap duoc")
		return
	end
	local ok, err = pcall(function () S_CCSchedule:schedule(self, "tick", 1) end)
	if ok then
		OfflineLog:info("tu_dong: da hen gio tu dang nhap (1 s)")
	else
		OfflineLog:err("tu_dong: hen gio loi: " .. tostring(err))
	end
end

return OfflineTuDong
