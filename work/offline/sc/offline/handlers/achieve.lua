--[[
	offline/handlers/achieve.lua — thành tựu / nhiệm vụ: đạt và nhận thưởng.

	Tại sao cần — ĐỌC TỪ MÃ, CHƯA QUAN SÁT: kịch bản hướng dẫn tân thủ
	(CGuideScheme_showAwardAchieve, CGuideScheme.lua:4329) làm

	    g_buyLoadingDialog:Show()
	    G_AchieveLogic:CallReachAchieve(nAchieveID, false)
	    coroutine.yield(EventManagerLogicEvent.Achieve.OnReachAchieve)
	    g_buyLoadingDialog:Hide()

	Không ai trả ClientReachAchieve thì sự kiện không bao giờ tới và lớp "đang
	tải" (lCommonLoadingDialog, tên chạm ClickBackground) nằm đè màn, nuốt mọi
	cú bấm. Viết file này lúc đang đoán nó là thủ phạm làm Main kẹt — đoán SAI:
	vết gọi của tools/bam_that.gd (bravecross-game) chỉ ra Quốc chiến
	(handlers/statewar.lua) và Cửa hàng bí ẩn (handlers/mysterious.lua). Đoạn
	hướng dẫn này chưa chạy tới trong lần dò nào, nên hai handler dưới đây CHƯA
	được kiểm bằng đường thật — chỉ đúng hình theo mã client và luật gốc.

	LUẬT LÀ CỦA BẢN GỐC, trong sc/share/AchieveLogic.lua:
	  * ReachAchieve: kiểm lại thành tựu, đặt trạng thái Done, rồi PHÁT sự kiện
	    OnReachAchieve — chính sự kiện kịch bản hướng dẫn chờ. Client không định
	    nghĩa đè hàm này nên gọi thẳng trên G_AchieveLogic.
	  * AwardAchieve: phát thưởng (G_PrizeLogic:ReceivePrizeWithID), sang bậc kế
	    hoặc Cleared. Client ĐÈ hàm này bằng bản không có luật
	    (ClientAchieveLogic.lua:635, dòng gọi luật bị chú thích bỏ), nên gọi bản
	    gốc qua lối lớp cha G_AchieveLogic[AchieveLogic] — đúng lối dòng bị bỏ đó
	    dùng.
	Sau đó trả đúng hàm client nhận: OnReachAchieve(nAchieveType) (mở khoá gửi
	lại, chấm đỏ) và OnAwardAchieve(nAchieveType) (gọi bản client AwardAchieve:
	đăng ký lại bậc mới, chấm đỏ).
]]

require("offline.log")
require("offline.store")
require("offline.router")

local R = OfflineRouter

R:on("ClientReachAchieve", function(ctx, nAchieveType)
	--[[ Nhiệm vụ HƯỚNG DẪN thì đóng thẳng, không thưởng.

		Kịch bản tân thủ gọi reach → award → hiện popup "Nhận Thưởng"; popup ấy
		khoá tương tác và mỗi lần đăng nhập lại chạy lại y hệt (đo 26/10:
		popup đứng im, không RPC nào phát ra). Bản gốc bỏ qua bước thưởng khi
		thấy State == Cleared (CGuideScheme.lua:4334-4337), nên ở chế độ offline
		ta đóng luôn nhiệm vụ hướng dẫn — thưởng của nó (nguyên liệu, mảnh tướng)
		đã rơi sẵn qua ải và hộp thư.

		Nhận biết nhiệm vụ hướng dẫn bằng chính hàm của bản gốc:
		GetGuidTaskWithType tra map riêng (AchieveLogic.lua:798-816). ]]
	local okGuid, tGuid = G_AchieveLogic:GetGuidTaskWithType(nAchieveType)
	if okGuid == true and tGuid ~= nil then
		local okR, nErrR = G_AchieveLogic:ReachAchieve(nAchieveType)
		G_AchieveLogic:setUserAchieveState(tGuid, AchieveState.Cleared)
		OfflineLog:info(string.format("ClientReachAchieve %s (huong dan): reach=%s, -> Cleared",
			tostring(nAchieveType), tostring(okR)))
		OfflineStore:syncFromClient()
		ctx:call("G_AchieveLogic", "OnReachAchieve", nAchieveType)
		return
	end

	--[[ Tự chữa trạng thái trước khi xét.

		Đo trên máy 26/10: kịch bản hướng dẫn gọi CallReachAchieve(1012) rồi
		`g_buyLoadingDialog:Hide()` + yield — nhưng luật gốc từ chối mã **2201**
		(WrongAcheiveState) vì dòng GameUserAchieve của loại đó không ở
		Done/Doing như nó đòi; lớp "đang tải" không được ẩn và màn hình **nuốt
		mọi cú bấm** (popup "Nhận Thưởng" đứng im, không RPC nào phát ra).

		Trong lớp offline, "máy chủ" là ta: dòng thiếu thì tạo (addTask đặt
		State = Doing đúng như bản gốc, AchieveLogic.lua:1220-1224), dòng có mà
		State lạ thì đưa về Doing rồi xét lại — thay vì bỏ cuộc. ]]
	local okMap, map = G_AchieveLogic:getUserAllAchieveMap()
	local row = (okMap == true and map ~= nil) and map[tostring(nAchieveType)] or nil
	if row == nil then
		local okAdd = G_AchieveLogic:addTask(nAchieveType)
		OfflineLog:info(string.format("ClientReachAchieve %s: chua co dong, addTask -> %s",
			tostring(nAchieveType), tostring(okAdd)))
	elseif row.State == AchieveState.Done then
		-- Đã đạt nhưng chưa nhận thưởng: luật gốc đòi Doing mới xét lại.
		OfflineLog:info(string.format("ClientReachAchieve %s: State cu = Done, dua ve Doing",
			tostring(nAchieveType)))
		G_AchieveLogic:setUserAchieveState(row, AchieveState.Doing)
	else
		-- Cleared (đã nhận thưởng) hoặc trạng thái khác: KHÔNG đụng vào.
		-- Đặt lại Doing ở đây làm kịch bản hướng dẫn chạy lại cả chuỗi
		-- reach→award mỗi lần đăng nhập, và lần nào cũng kẹt ở popup thưởng
		-- (đo được 26/10 23:16).
		OfflineLog:info(string.format("ClientReachAchieve %s: State = %s, giu nguyen",
			tostring(nAchieveType), tostring(row.State)))
	end

	local ok, nErr = G_AchieveLogic:ReachAchieve(nAchieveType)
	if not ok then
		-- Client chi goi khi CheckAchievement cua chinh no da dat, nen luat
		-- goc tu choi la chuyen la: ghi lai, van tra de client mo khoa gui lai.
		OfflineLog:warn(string.format("ClientReachAchieve %s: luat goc tu choi, ma %s",
			tostring(nAchieveType), tostring(nErr)))
	end
	OfflineStore:syncFromClient()
	ctx:call("G_AchieveLogic", "OnReachAchieve", nAchieveType)
end)

--[[ Nhận thưởng ĐIỂM HOẠT ĐỘNG (nhiệm vụ ngày — `CUIDailyTask:346` nghe
	`Achieve.OnGetLivenessPrize`).

	Client: `ClientAchieveLogic:CallGetLivenessPrize` (:808) → `ClientGetLivenessPrize`
	rồi phát `OnWaitingForRequest`. Luật gốc `AchieveLogic:GetLivenessPrize`
	(`share/AchieveLogic.lua:616`) kiểm mốc điểm hoạt động, gọi
	`G_PrizeLogic:ReceivePrizeWithID(livenessPrize.PrizeID, …)` và tự phát
	`Achieve.OnGetLivenessPrize` — nên handler chỉ GỌI rồi tắt lớp đang tải.

	Chưa đạt mốc thì luật gốc từ chối (bReCode=false) — ghi warn, vẫn phải tắt
	lớp đang tải, không thì client treo. ]]
R:on("ClientGetLivenessPrize", function(ctx)
	local bOk = false
	local nErr = 0
	if G_AchieveLogic ~= nil and G_AchieveLogic.GetLivenessPrize ~= nil then
		local ok, bRet, nMa = pcall(function ()
			return G_AchieveLogic:GetLivenessPrize()
		end)
		bOk = ok and bRet == true
		if not bOk then
			nErr = ok and tonumber(nMa) or 1
		end
	end
	OfflineLog:info(string.format("nhan thuong hoat dong -> %s (ma %s)",
		tostring(bOk), tostring(nErr)))
	if bOk then
		OfflineStore:syncFromClient()
	end
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "",
		bOk and 0 or nErr, {})
end)

--[[ Bỏ qua một nhiệm vụ (`ClientSkipAchieve`).

	Client đã có hàm xử lý trọn đường: `ClientAchieveLogic:SkipAchieve`
	(:745) gọi lớp cha `AchieveLogic:SkipAchieve` (`share/AchieveLogic.lua:529`)
	rồi tự đăng ký / huỷ đăng ký nhiệm vụ theo trạng thái mới. Nên handler gọi
	chính hàm client ấy (KHÔNG gọi lớp cha trực tiếp, sẽ thiếu phần đăng ký). ]]
R:on("ClientSkipAchieve", function(ctx, nAchieveType)
	local ok, bRet = pcall(function ()
		return G_AchieveLogic:SkipAchieve(nAchieveType)
	end)
	OfflineLog:info(string.format("bo qua nhiem vu %s -> %s",
		tostring(nAchieveType), tostring(ok and bRet)))
	OfflineStore:syncFromClient()
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", 0, {})
end)

R:on("ClientAwardAchieve", function(ctx, nAchieveType)
	local goc = AchieveLogic and G_AchieveLogic[AchieveLogic]
	if goc == nil then
		OfflineLog:err("ClientAwardAchieve: khong lay duoc lop cha AchieveLogic")
		return
	end
	local ok, nErr = goc:AwardAchieve(nAchieveType)
	if not ok then
		OfflineLog:warn(string.format("ClientAwardAchieve %s: luat goc tu choi, ma %s",
			tostring(nAchieveType), tostring(nErr)))
	end
	OfflineStore:syncFromClient()
	ctx:call("G_AchieveLogic", "OnAwardAchieve", nAchieveType)
end)

--[[ NHẬN THƯỞNG NHIỆM VỤ NGÀY (`ClientAwardDailyTask`).

	Người gửi: `CServerRequestLogic:AwardDailyTask(taskId)` (`:416`), obj **rỗng**.

	⚠ KHÔNG dùng được `DailyTaskLogic:AwardDailyTask` như bản gốc — hàm ấy đã LỖI
	THỜI so với dữ liệu trong gói này (ĐO 28/10, hai lỗi độc lập):
	  1. gọi `G_DataManager:SetDailyTaskWithId` — hàm thật viết **thường**
	     `setDailyTaskWithId` (`share/share_CDataManagerPrivate.lua:1006`) ⇒
	     `attempt to call method 'SetDailyTaskWithId' (a nil value)`;
	  2. đọc `taskCondig.PrizeList`, nhưng `KDBGameDailyTaskConfig` chỉ có khoá
	     **`Award`** (chuỗi JSON danh sách PrizeData) ⇒ dù sửa lỗi 1 thì vẫn nil.
	Bản gốc chạy hàm này ở MÁY CHỦ với bảng cấu hình khác, nên đừng "sửa" nó.

	Ở đây dựng lại đúng ba bước từ DỮ LIỆU CÓ SẴN:
	  * cổng: nhiệm vụ phải đang `AchieveState.Done` (2);
	  * thưởng: `cjson.decode(cfg.Award)` → `G_ChapterLogic:SetDataWithPrizeList`
	    (chính lối cấp thưởng dùng khắp nơi);
	  * đánh dấu: `G_DataManager:setDailyTaskWithId(taskId, AchieveState.Cleared)`. ]]
R:on("ClientAwardDailyTask", function(ctx, taskId)
	local nErr = 0
	local task, trangThai = nil, nil
	pcall(function ()
		task = G_DataManager:getDailyTaskWithId(taskId)
		trangThai = task and tonumber(task.State)
	end)

	local cfg = nil
	pcall(function () cfg = G_ConfigManager:GetDailyTaskConfigWithId(taskId) end)

	if trangThai ~= AchieveState.Done then
		nErr = 1
		OfflineLog:info(string.format("nhiem vu ngay %s: trang thai %s (can Done = 2)",
			tostring(taskId), tostring(trangThai)))
	elseif type(cfg) ~= "table" then
		nErr = 1
		OfflineLog:warn("nhiem vu ngay: khong co cau hinh cho task " .. tostring(taskId))
	else
		-- ĐO 28/10: lúc NẠP cấu hình, khoá `Award` trong JSON được đổi tên thành
		-- **`PrizeList`** (khoá thật lúc chạy: TaskId, Name, PrizeList) — nên
		-- `DailyTaskLogic:AwardDailyTask` đọc `taskCondig.PrizeList` là ĐÚNG.
		local ds = cfg.PrizeList or cfg.Award
		if type(ds) == "string" then
			local okJ, v = pcall(cjson.decode, ds)
			ds = okJ and v or nil
		end
		if type(ds) ~= "table" then
			nErr = 1
			local khoa = {}
			pcall(function ()
				for k in pairs(cfg) do khoa[#khoa + 1] = tostring(k) end
			end)
			OfflineLog:warn("nhiem vu ngay: khong doc duoc truong Award (khoa: "
				.. table.concat(khoa, ",") .. "; type Award = " .. type(cfg.Award) .. ")")
		else
			local okP, bP = pcall(function ()
				return G_ChapterLogic:SetDataWithPrizeList(ds, nil, "DailyTask")
			end)
			if not okP or bP ~= true then
				nErr = 1
				OfflineLog:warn("nhiem vu ngay: phat thuong loi: " .. tostring(bP))
			else
				pcall(function ()
					G_DataManager:setDailyTaskWithId(taskId, AchieveState.Cleared)
				end)
				OfflineStore:syncFromClient()
				OfflineLog:info(string.format("nhiem vu ngay %s: da phat %d mon",
					tostring(taskId), #ds))
			end
		end
	end

	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", nErr, {})
end)

return true
