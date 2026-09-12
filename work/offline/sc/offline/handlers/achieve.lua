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

return true
