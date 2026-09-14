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
	  * Kiểm gian lận: xem dưới.
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
--[[ DANH SÁCH RƠI ĐỒ.

	Luật SINH nằm ở server gốc và không được ship — nhưng SỐ thì có đủ trong
	cấu hình của chính bản gốc, nên dựng lại được:

	  * `KDBGameNpcConfig[NpcID].DropData` — chuỗi JSON, mỗi mục là
	    `{DropWay, DropValue, ModeOfDistribution, PrizeData{...}, ...}`.
	  * `KDBGameNpcConfig[NpcID].TotalDropValue` — mẫu số: 100 hoặc 10000.
	  * `KDBGameChapterConfig[key].ChapterInfo` — `{Groups:[{PosX, PosY,
	    AppearTime, Soldiers:[{NpcID, Level, Num}]}]}`.

	Hình dạng phải trả về, chép từ chú thích đầu `user/Battle/CUIGameFinish.lua`
	và từ chỗ đọc thật (`CUIGameFinish.lua:1885`):

	    { DropConfig = { ["D1"] = { PrizeData = {...} }, ... },
	      Drop       = { ["1-2-1"] = { "D1", "D3" }, ... } }

	Mã đơn vị `"<nhóm>-<lính>-<bản sao>"` do SÂN TRẬN đặt (bản gốc: engine
	C++); client chỉ gom rồi gửi lại, nên chỉ cần hai đầu khớp nhau — xem
	`battle/tran_goc.gd`. Bằng chứng cho dạng mã: chú thích của bản gốc cho ví
	dụ "1-1-1", "1-1-2", "1-1-3", "1-2-1" (ba bản sao rồi sang lính kế tiếp), và
	`ChapterInfo` của ải 1 có đúng một nhóm `Num = 3` ở chỗ đó.

	ĐẶT — cách quay, vì luật server không có:
	  mỗi mục quay RIÊNG, trúng với xác suất `DropValue / TotalDropValue`.
	  Căn cứ: 167/331 NPC có tổng `DropValue` VƯỢT `TotalDropValue`, nên không
	  thể là một lần quay chọn một món; và `TotalDropValue` chỉ nhận 100 hoặc
	  10000, đúng dạng mẫu số phần trăm / phần vạn.
	  `DropWay` và `ModeOfDistribution` trong toàn bộ 2.387 mục đều bằng 1, nên
	  ở đây không rẽ nhánh theo chúng — có dữ liệu khác thì phải xem lại.

	Quân `Num = 0` không ra trận (`tran_goc.gd:doc_quan`) nên không có mã. ]]
--[[ Vài trường cấu hình là chuỗi JSON trong file, nhưng tầng cấu hình của bản
	gốc đã giải sẵn một số trong đó thành bảng (`ChapterInfo` là một —
	`updateChapterConfig` làm việc đó, giống `updateAchieveConfig` giải `Award`).
	Nhận cả hai dạng thay vì đoán dạng nào. ]]
local function chuoiJson(s)
	if type(s) == "table" then
		return s
	end
	if type(s) ~= "string" or s == "" or s == "[]" then
		return nil
	end
	local ok, t = pcall(function() return cjson.decode(s) end)
	if ok and type(t) == "table" then
		return t
	end
	return nil
end

local function npcConfig(nNpcID)
	if G_ConfigManager == nil then
		return nil
	end
	-- Dùng đúng hàm tra cứu của bản gốc (share_configManager.lua:2390).
	local ok, t = pcall(function()
		return G_ConfigManager:GetNpcConfigWithNpcId(tostring(nNpcID))
	end)
	if ok and type(t) == "table" then
		return t
	end
	return nil
end

function OfflineDrop_build(strChapterKey)
	local tDropConfig, tDrop, nKey = {}, {}, 0
	local cfg = nil
	if G_ConfigManager ~= nil then
		local ok, t = pcall(function()
			return G_ConfigManager:GetChapterConfig(strChapterKey)
		end)
		cfg = ok and t or nil
	end
	local info = cfg and chuoiJson(cfg.ChapterInfo)
	if info == nil or type(info.Groups) ~= "table" then
		OfflineLog:warn("khong doc duoc ChapterInfo cua " .. tostring(strChapterKey)
			.. " — danh sach roi do de rong")
		return { DropConfig = tDropConfig, Drop = tDrop }
	end

	for iNhom, g in ipairs(info.Groups) do
		if type(g) == "table" and type(g.Soldiers) == "table" then
			for iLinh, s in ipairs(g.Soldiers) do
				local nNum = tonumber(s.Num) or 0
				local npc = nNum > 0 and npcConfig(s.NpcID) or nil
				local ds = npc and chuoiJson(npc.DropData) or nil
				local nMau = tonumber(npc and npc.TotalDropValue) or 0
				for k = 1, nNum do
					local ma = iNhom .. "-" .. iLinh .. "-" .. k
					local tKeys = {}
					if ds ~= nil and nMau > 0 then
						for _, muc in ipairs(ds) do
							local nGiaTri = tonumber(muc.DropValue) or 0
							if nGiaTri > 0 and math.random() * nMau < nGiaTri then
								nKey = nKey + 1
								local khoa = "D" .. nKey
								tDropConfig[khoa] = { PrizeData = muc.PrizeData }
								tKeys[#tKeys + 1] = khoa
							end
						end
					end
					tDrop[ma] = tKeys
				end
			end
		end
	end
	return { DropConfig = tDropConfig, Drop = tDrop }
end


--[[ Danh sách rơi của ván ĐANG chơi. Phải nhớ lại giữa hai lần gọi: quay ở
	`ClientChapterBegin`, dùng lại ở `ClientChapterCompleteSuccess`. Quay lại
	lần hai thì phần thưởng nhận được sẽ khác cái người chơi vừa nhặt trên sân. ]]
local tRoiDangChoi = nil

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
	tRoiDangChoi = OfflineDrop_build(strKey)
	ctx:call("G_ChapterLogic", "OnServerChapterBegin", {
		ChapterKey = strKey,
		DropData = { DropList = tRoiDangChoi, ChapterEx = cfg.ChapterUserEx or 0 },
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

	-- Lọc danh sách rơi theo những con ĐÃ GIẾT, bằng chính hàm luật của bản
	-- gốc (ChapterLogic:filterKillDropList). Client gom KillIdList từ
	-- `OnKillEnemy` mà sân trận gọi (lua/san_tran.lua).
	local tRoi = tRoiDangChoi or danhSachRoiRong()
	local tGiet = type(cd.KillIdList) == "table" and cd.KillIdList or {}
	local okLoc, tRoiGiet = G_ChapterLogic:filterKillDropList(tGiet, tRoi)
	if okLoc and type(tRoiGiet) == "table" then
		tRoi = tRoiGiet
	else
		OfflineLog:warn("filterKillDropList tu choi — gui danh sach roi rong")
		tRoi = danhSachRoiRong()
	end

	local ok, nErr, nResourceCount = G_ChapterLogic:chapterCompleteSuccess(
		strKey, tRoi, nRating, cfg.ChapterUserEx or 0)
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
		DropList = tRoi,
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
