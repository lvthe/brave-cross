--[[
	offline/handlers/chapter.lua — chiến dịch: bắt đầu ải, thắng, thua.

	Đường đi, đọc từ mã client và đo bằng tools/do_chien_dich.gd bên
	bravecross-game:

	  nút tấn công ở Main -> chọn ải -> "Đi" -> màn bố trí quân -> tấn công
	    CUIBattleDeploy:SetChapterBegin -> G_ChapterLogic:ChapterBegin
	    -> CallServer ClientChapterBegin({ChapterKey, HeroList, PotionList})
	  ta trả G_ChapterLogic:OnServerChapterBegin(tRet)
	    -> CUIBattleDeploy:OnServerChapterBegin -> RepaleceScene("Battle")
	  hết trận: ChapterGeneral:OnGeneralEnd -> CUIGame:OnLevelCompleteCallServer
	    -> ClientChapterCompleteSuccess / ClientChapterCompleteFaild

	LUẬT LÀ CỦA BẢN GỐC. sc/share/share_ChapterLogic.lua chứa sẵn phần server:
	saveChapterBeginStatus (kiểm cấp, số lần trong ngày, thể lực; trừ 1/6 thể
	lực; lưu đội hình), chapterCompleteSuccess -> chapterVictoryHandle (trừ nốt
	5/6 thể lực, cộng kinh nghiệm người và tướng, vàng ResourceCount, phần
	thưởng ChapterPrizeList, lưu chiến báo) và chapterCompleteFaild. Client có
	sẵn chúng trên G_ChapterLogic (ClientChapterLogic kế thừa ChapterLogic) và
	không viết đè hàm luật nào — ở đây chỉ GỌI, rồi chép kết quả về kho
	(OfflineStore:syncFromClient).

	CÒN THIẾU, không bịa:
	  * Danh sách rơi đồ (DropData.DropList): server gốc sinh ra, luật sinh
	    không có trong sc/share. Gửi bảng rỗng — đánh xong không rơi đồ, còn
	    vàng, kinh nghiệm và phần thưởng cố định vẫn đủ vì chúng lấy từ cấu hình.
	  * Kiểm gian lận (ChapterData.DamageVerify) của server gốc: không có mã,
	    không kiểm.
]]

require("offline.log")
require("offline.store")
require("offline.router")

local R = OfflineRouter

local function ma_ok()
	return (ErrorCode and ErrorCode.OK) or 0
end

-- Danh sach roi do KHONG CO GI, dung hinh {DropConfig, Drop} ma client doi.
local function danhSachRoiRong()
	return { DropConfig = {}, Drop = {} }
end

--[[ Hàm CHỈ SERVER GỐC có. chapterVictoryHandle gọi
	self:CheckActivityIsDoublePrize(ChapterKey) (share_ChapterLogic.lua:2747)
	nhưng không file nào của client định nghĩa nó — phần server của lớp
	ChapterLogic không được ship. Theo chỗ dùng ngay sau đó (:2760-2799), nó hỏi
	HOẠT ĐỘNG "rơi đồ nhân đôi" (ActivityType.ChapterDoubleDrop) có mở không, rồi
	trả (bResult, bDoublePrize, nCountMultiple).

	Hỏi đúng hàm gốc mà chính đoạn đó dùng (G_ActivityLogic:
	CheckActivityIsOpenWithType). Offline không có hoạt động nào (danh sách
	hoạt động rỗng, handlers/login.lua) nên luôn là KHÔNG nhân đôi. Nếu một ngày
	hoạt động đó mở thì hệ số nhân không biết lấy ở đâu — kêu lên, không đoán. ]]
local function gan_ham_chi_server()
	if G_ChapterLogic == nil or G_ChapterLogic.CheckActivityIsDoublePrize ~= nil then
		return
	end
	ClientChapterLogic.CheckActivityIsDoublePrize = function(self, strKey)
		local mo = false
		if G_ActivityLogic and G_ActivityLogic.CheckActivityIsOpenWithType
				and ActivityType and ActivityType.ChapterDoubleDrop then
			local ok, r = pcall(G_ActivityLogic.CheckActivityIsOpenWithType, G_ActivityLogic,
				ActivityType.ChapterDoubleDrop)
			mo = ok and r == true
		end
		if mo then
			OfflineLog:warn("hoat dong roi do nhan doi dang mo nhung khong biet he so — khong nhan")
		end
		return true, false, 1
	end
end

local function cau_hinh(strKey)
	if not (G_ConfigManager and G_ConfigManager.GetChapterConfig) then
		return nil
	end
	local ok, t = pcall(G_ConfigManager.GetChapterConfig, G_ConfigManager, strKey)
	return ok and type(t) == "table" and t or nil
end

--[[ Đội hình cuối — client đã tự áp (ClientArmyLogic.lua:120 gọi
	G_ArmyLogic:SetLastArmyLineup trước khi CallServer), server gốc chạy lại
	cùng luật trên bản của nó. Không có phản hồi: client không có hàm nhận. ]]
R:on("ClientSetLastArmyLineup", function(ctx, nIndex)
	OfflineStore:syncFromClient()
end)

R:on("ClientChapterBegin", function(ctx, tData)
	local strKey = type(tData) == "table" and tData.ChapterKey or nil
	local cfg = cau_hinh(strKey)
	if cfg == nil then
		OfflineLog:err("ClientChapterBegin: khong co cau hinh ai " .. tostring(strKey))
		ctx:call("G_ChapterLogic", "OnServerChapterBegin",
			{ ChapterKey = strKey, ErrorCode = 1 })
		return
	end

	local ok, nErr = G_ChapterLogic:saveChapterBeginStatus(tData)
	if not ok or (nErr ~= nil and nErr ~= ma_ok()) then
		-- Không vào được (thiếu thể lực, hết lượt, chưa đủ cấp...). Client
		-- thấy thiếu DropData thì dừng ở OnServerChapterBegin mà không đổi cảnh.
		OfflineLog:warn(string.format("ClientChapterBegin %s: khong vao duoc, ma %s",
			strKey, tostring(nErr)))
		ctx:call("G_ChapterLogic", "OnServerChapterBegin",
			{ ChapterKey = strKey, ErrorCode = nErr or 1 })
		return
	end
	OfflineStore:syncFromClient()

	-- CUIBattleDeploy:OnServerChapterBegin đòi DropData.DropList (bảng) và
	-- DropData.ChapterEx (số) (CUIBattleDeploy.lua:3191-3204). Không gửi
	-- ChapterInfo thì client tự lấy quân địch từ cấu hình (:3225).
	-- ChapterEx = ChapterUserEx: chính con số chapterCompleteSuccess nhận làm
	-- nChapterUserEx. (L_N_01_01: ChapterUserEx = ChapterFirstEx = 6, nên ải
	-- này không phân biệt được hai trường; chưa gặp ải nào cần.)
	-- DropList rong nhung DUNG HINH: client doi DropList.DropConfig la bang
	-- (ClientEquipmentLogic.lua:670), Drop thi co the thieu (:674). Hinh
	-- {DropConfig, Drop} lay tu chinh mau thu cua ban goc
	-- (share_ChapterLogicTest.lua:58). Gui {} tron thi client dung o
	-- OnServerChapterBegin, khong bao gio doi canh.
	ctx:call("G_ChapterLogic", "OnServerChapterBegin", {
		ChapterKey = strKey,
		DropData = { DropList = danhSachRoiRong(), ChapterEx = cfg.ChapterUserEx or 0 },
	})
end)

--[[ Kiểm chống gian lận lúc vào trận (CUIGame:sendServerCheckData,
	CUIGame.lua:840). Client không chờ: chỉ dừng trận khi server trả Err > 0
	(OnClientCheckServerBack, :798). Offline không có luật kiểm (nằm ở server),
	nên không kiểm và không trả. ]]
R:ignore("ClientCheck")

R:on("ClientChapterCompleteSuccess", function(ctx, strKey, tClientData)
	gan_ham_chi_server()
	local cfg = cau_hinh(strKey) or {}
	local cd = type(tClientData) == "table" and tClientData.ChapterData or {}
	-- Số sao do client tính (CUIGame:getRating theo số tướng còn sống).
	local nRating = tonumber(cd.RatingType) or 1

	local ok, nErr, nResourceCount = G_ChapterLogic:chapterCompleteSuccess(
		strKey, {}, nRating, cfg.ChapterUserEx or 0)
	if not ok then
		OfflineLog:warn(string.format("ClientChapterCompleteSuccess %s: luat goc tu choi, ma %s",
			tostring(strKey), tostring(nErr)))
	end
	OfflineStore:syncFromClient()

	-- Màn kết thúc đọc DropList, ResourceCount, DropExtraGold của phản hồi
	-- (CUIGameFinish.lua:420, :780, :806); ClientChapterLogic đòi ChapterKey.
	-- Man ket thuc doc DropList.Drop / DropList.DropConfig
	-- (CGameFinishAward:getAwardList, CUIGameFinish.lua:1883-1888).
	ctx:call("G_ChapterLogic", "OnServerChapterCompleteSuccess", {
		ChapterKey = strKey,
		DropList = danhSachRoiRong(),
		ResourceCount = nResourceCount or 0,
		ErrorCode = nErr or ma_ok(),
	})
end)

R:on("ClientChapterCompleteFaild", function(ctx, strKey, tClientData)
	local ok, nErr = G_ChapterLogic:chapterCompleteFaild(strKey)
	if not ok then
		OfflineLog:warn(string.format("ClientChapterCompleteFaild %s: ma %s",
			tostring(strKey), tostring(nErr)))
	end
	OfflineStore:syncFromClient()
	ctx:call("G_ChapterLogic", "OnServerChapterCompleteFaild", {
		ChapterKey = strKey,
		ErrorCode = nErr or ma_ok(),
	})
end)

return true
