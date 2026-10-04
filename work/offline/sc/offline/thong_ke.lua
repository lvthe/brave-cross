--[[
	offline/thong_ke.lua — ghi thống kê mà bản gốc ghi ở phía server.

	MỘT KHOÁ, MỘT LUẬT: `ConsumFatigueValue` = "thể lực đã tiêu", mốc của thành
	tựu loại 3000 (`sc/share/AchieveLogic.lua:74` trường
	`ConsumFatigueValueAchive`), thứ mà `CUILevelTarget` (阶段目标) hiện thành
	`costTL` / `needTL` và so với `data.AchieveCondition.ConditionVal`.

	VÌ SAO CẦN TỆP NÀY — ĐO ĐƯỢC, KHÔNG ĐOÁN:
	  * Quét cả `sc/`: 21 chỗ gọi `SetStatisticsCommonData`, KHÔNG chỗ nào dùng
	    chuỗi "ConsumFatigueValue". Nó chỉ được ĐỌC
	    (`AchieveCheckLogic.lua:1104`, `CUILevelTarget.lua:50`) và **0** lần
	    trong `work/offline/`. Nửa ghi của bản gốc nằm phía server, không được
	    ship — cùng kiểu với người gọi `ReduceSweepCount`.
	  * Trước tệp này, đo trên `L_N_01_01` (`C:/tmp/tt_moc.gd`): một lượt quét
	    thật làm thể lực rơi 120 -> 114 mà thống kê vẫn `nil`, tiến độ mốc vẫn
	    0/850, `State` vẫn 1 (Doing). Nên `State` không bao giờ sang `Done`,
	    `G_AchieveLogic:CallAwardAchieve` không bao giờ chạy, và QUÀ CỦA MỐC
	    KHÔNG BAO GIỜ PHÁT.
	  * Bản ghi thành tựu 3000 ở lớp này mang
	    `DataEventList = { "GameUserGlobalData.Sta_ConsumFatigueValue" }` — đo
	    được, và ĐÚNG bằng chuỗi mà `SetCommonData` phát ra
	    (`strSaveKey = "Sta_" .. strKey`, bảng `GameUserGlobalData`). Nên khoá
	    đã đúng sẵn; cả dây chuyền cũng có sẵn: ghi khoá này là client tự gọi
	    `CallReachAchieve`, rồi `offline/handlers/achieve.lua` trả lời và mốc
	    hoàn thành. Lớp này chỉ thiếu NGUỒN GHI.

	GHI Ở ĐÂU — `G_UserLogic:AddFatigueValue`, và đây là chỗ DUY NHẤT phải suy:
	không có mã gốc nào GHI khoá này để mà bắt chước. Nhưng chỗ đặt thì có căn
	cứ, không phải đoán bừa: mọi đường tiêu thể lực của chiến dịch đều đi qua
	đúng hàm ấy — `saveChapterBeginStatus` (`share_ChapterLogic.lua:915`, 1/6)
	và `chapterVictoryHandle` (:2717, 5/6, cộng đủ `ChapterUserFatigue` = 6) —
	tức là chính bản gốc cũng coi nó là phễu. Bọc nó thì mọi nguồn tiêu đều
	được đếm mà không phải đoán từng handler, và handler mới thêm sau này tự
	động được đếm. Cách bọc hàm gốc có sẵn tiền lệ trong lớp này:
	`Offline:start` đã vá `CDataManager.initUserDataFromDB` — cũng là hàm gốc.

	GHI NET, KHÔNG GHI GỘP: `AddFatigueValue` nhận số ÂM khi tiêu và số DƯƠNG
	khi tăng. Số dương có hai loại — hoàn lại (thể lực trả về vì lượt quét
	không ra thưởng) và tăng thật (mua thể lực). Phân biệt bằng `strPrizeFrom`:
	mọi nguồn HOÀN của lớp này mang hậu tố `-hoan` (ba chỗ gọi
	`tru_the_luc(-...)` trong `handlers/chapter.lua`). Nên:
	    âm            -> cộng vào thống kê
	    dương + "-hoan" -> trừ ra
	    dương còn lại  -> không đụng tới
	Ghi gộp thì một người chơi quét mãi một ải luôn thất bại sẽ đẩy được mốc
	mà không mất gì. THÊM CHỖ HOÀN MỚI THÌ PHẢI ĐẶT TÊN CÓ HẬU TỐ `-hoan`.

	KẸP Ở 0: hoàn mà thống kê đang 0 (bản lưu cũ, hoặc vừa được đặt lại) thì
	không để nó thành số âm.
]]

require("offline.log")

OfflineThongKe = {}
OfflineThongKe.KHOA = "ConsumFatigueValue"

--[[ Hậu tố đánh dấu nguồn HOÀN thể lực. Xem đầu tệp: đây là quy ước, không
	phải suy đoán — ba chỗ hoàn của lớp này đã đặt tên như vậy. ]]
OfflineThongKe.HAU_TO_HOAN = "-hoan"

OfflineThongKe.ham_goc = nil   -- hàm gốc, để gọi xuyên qua
OfflineThongKe.ham_goi = nil   -- hàm bọc của ta, để nhận ra "đã gắn rồi"


local function la_nguon_hoan(strPrizeFrom)
	if type(strPrizeFrom) ~= "string" then
		return false
	end
	local strTo = OfflineThongKe.HAU_TO_HOAN
	return strPrizeFrom:sub(-#strTo) == strTo
end


--[[ Cộng (hoặc trừ, khi số âm) vào thống kê. Chịu được cả hai trường hợp
	`GetStatisticsCommonData` trả `nil` (chưa ai ghi bao giờ — đo được: lượt đầu
	tiên luôn là `nil`, không phải 0) và trả về không phải số. ]]
function OfflineThongKe:ghi(nDaTieu)
	if type(nDaTieu) ~= "number" or nDaTieu == 0 then
		return
	end
	if not (G_UserLogic and G_UserLogic.GetStatisticsCommonData
			and G_UserLogic.SetStatisticsCommonData) then
		return
	end
	local bOk, nCu = G_UserLogic:GetStatisticsCommonData(self.KHOA)
	if bOk ~= true or type(nCu) ~= "number" then
		nCu = 0
	end
	local nMoi = nCu + nDaTieu
	if nMoi < 0 then
		nMoi = 0
	end
	G_UserLogic:SetStatisticsCommonData(self.KHOA, nMoi)
end


--[[ Bọc `G_UserLogic.AddFatigueValue`. Idempotent: gọi bao nhiêu lần cũng được,
	chỉ bọc một lần. Trả false khi chưa có `G_UserLogic` (nạp sai thứ tự) — chỗ
	gọi phải NÓI RA, đừng để im.

	Nếu sau này có ai đó bọc đè lên ta, `G_UserLogic.AddFatigueValue` sẽ khác
	`self.ham_goi`, và lần gọi sau sẽ bọc tiếp hàm MỚI ấy — nối tiếp chứ không
	mất. ]]
function OfflineThongKe:dam_bao()
	if not (G_UserLogic and type(G_UserLogic.AddFatigueValue) == "function") then
		return false
	end
	if self.ham_goi ~= nil and G_UserLogic.AddFatigueValue == self.ham_goi then
		return true
	end

	local goc = G_UserLogic.AddFatigueValue
	self.ham_goc = goc

	local function boc(self_, nIncrement, strPrizeFrom)
		local ok, nMoi = goc(self_, nIncrement, strPrizeFrom)
		-- Chỉ đếm khi luật gốc ĐÃ đổi thể lực thật. `AddFatigueValue` trả false
		-- khi `nIncrement + FatigueValue < 0` (không trừ gì) — đo được, nên
		-- không đếm một phép trừ đã bị từ chối.
		if ok == true and type(nIncrement) == "number" and nIncrement ~= 0 then
			if nIncrement < 0 then
				OfflineThongKe:ghi(-nIncrement)
			elseif la_nguon_hoan(strPrizeFrom) then
				OfflineThongKe:ghi(-nIncrement)
			end
		end
		return ok, nMoi
	end

	G_UserLogic.AddFatigueValue = boc
	self.ham_goi = boc
	return true
end


return OfflineThongKe
