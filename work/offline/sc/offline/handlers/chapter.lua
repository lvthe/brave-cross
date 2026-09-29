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

--[[ CÀN QUÉT (扫荡) — nút "Quét 1 lần" / "Quét 10 lần" ở màn thông tin ải.

	VÌ SAO NÚT CÓ MÀ KHÔNG CHẠY: hai nút là CON của `s9SweepBoard`
	(`CUIChapterInfo.lua:697`, `:709`), mà `:1678-1681` ẩn CẢ BẢNG cho tới khi
	`tChapterData.BattleStatus == CHAPTER_STATUS.BATTLEVICTORY` — nên phải THẮNG
	ải trước. Đo được (`C:/tmp/th_can_quet4.gd`, ải `L_N_01_01` chưa thắng):
	`btnSweepOne` KHÔNG có mặt trong danh sách ứng viên của cú chạm, và
	`lNormalDlgTouchMask` nhận cú chạm — cổng tiến trình của bản gốc, không phải
	lỗi của bản dựng. Nhưng thắng rồi thì `CallServer` rơi vào khoảng trống
	THẬT: `offline.log` có 20.893 dòng THIEU mà KHÔNG dòng nào mang chữ "Sweep".

	Đường đi, đọc từ chính chỗ gọi:
	  CUIChapterInfo:onTouchEnd_OnSweepOne (:2646) — bốn cổng (thể lực, số lần
	    thách đấu, số lần càn quét, trạng thái sao/VIP) rồi
	    G_ChapterLogic:ChapterSweepOnce(key) -> ClientChapterSweepOnce
	  onTouchEnd_OnSweepTen (:2752) — thêm CheckCanSweepCount, chặn trần 10
	    -> ClientChapterSweepTen -> OnServerChapterSweepTen(LIST)

	LUẬT LÀ CỦA BẢN GỐC:
	  * PHẦN THƯỞNG: `chapterSweepHandle` (share_ChapterLogic.lua:2878) — hàm
	    server CÓ được ship. Nó đi qua CÙNG hai hàm như đường thắng
	    (`SetDataWithDropList` + `saveVictoryReport`), nên số lần thách đấu trong
	    ngày (`PassMissionCount`, :3148-3152) và chiến báo tự khớp.
	  * THỂ LỰC — một lần càn quét = MỘT trận trọn vẹn. Ba chỗ của bản gốc khớp
	    nhau: `saveChapterBeginStatus` trừ `ChapterUserFatigue/6` (:913),
	    `chapterVictoryHandle` trừ `ChapterUserFatigue/6*5` (:2714) — cộng đủ
	    `ChapterUserFatigue` — và chính client ghi giá của càn quét trong chuỗi
	    xác nhận đã bị tắt: `ChapterUserFatigue * 1` cho một lần (:2703) và
	    `ChapterUserFatigue * nMaxSweepCount` cho mười lần (:2839).
	  * SỐ LẦN CÀN QUÉT — có một chỗ KHÔNG khôi phục được, nói thẳng ra:
	    `CheckCanSweepCount` (:1662) = min(`getChapterLeftSweepCount` :1712,
	    `getChapterLeftBattleCount` :1759). Trên `L_N_01_01` đo được
	    `UserGlobalConfig.SweepPerDay = 99999999`, nên vế đầu là 99999999 trừ
	    `SweepCount` — vế SAU mới là trần thật, và nó bị chính
	    `saveVictoryReport` (:3148-3152) tiêu thụ. Trần ấy phải GÁC Ở ĐÂY: client
	    tính `nMaxSweepCount` chỉ để HIỂN THỊ rồi gọi `ChapterSweepTen(key)` trần
	    (:2796-2810), nên nếu lớp này không gác thì không ai gác.
	    `SweepCount` (trong `GameUserGlobalData`) là số lượt MUA BẰNG KIM CƯƠNG,
	    không phải số lượt đã dùng: `changeDiamondToSweepCount` (:1206) tiêu kim
	    cương rồi gọi `ReduceSweepCount`, và chính `um_event.lua:487/512` đặt tên
	    sự kiện ấy là "购买扫荡次数消耗" / "buy_sweep_count". Người chơi mới có
	    `SweepCount = 0`.
	    VÌ THẾ `ReduceSweepCount` (:1320) TỪ CHỐI ngay lượt quét đầu — và không
	    phải lỗi kiểu như tôi tưởng lúc đầu: `:1342` là
	    `ProcessError(nCount >= 0)`, tức `0 - 1 < 0`. Cả nhánh mua cũng không
	    bao giờ chạy: `CUIChapterInfo.lua:1968` chỉ mời mua khi
	    `nLeftSweepCount <= 0`, mà `SweepPerDay = 99999999`.
	    Chỗ này là SUY LUẬN, KHÔNG PHẢI TRÍCH DẪN: bản gốc gọi
	    `ReduceSweepCount` ở đâu thì hàm ấy KHÔNG được ship (grep cả `sc/` chỉ
	    thấy tệp này gọi). Ta vẫn gọi — nó là hàm tiêu thụ DUY NHẤT được ship, và
	    với người chưa mua lượt nào thì từ chối là kết quả đúng — nhưng ghi mức
	    `info` chứ không `warn`, để nhật ký không kêu như lỗi.
	  * SAO: bản gốc chỉ gửi mỗi ChapterKey, nên lấy lại sao ĐÃ LƯU của ải.
	    `saveVictoryReport` chỉ NÂNG sao (:3185 `if nRatingType >
	    tReportsData.RatingType`), nên truyền lại số cũ là phép toán không đổi.
	  * `bSweepMode = true`: `saveChapterPrizeList` (:3642) rẽ theo cờ này để cộng
	    thêm danh sách thưởng RIÊNG của càn quét (扫荡模式奖励) — bỏ cờ là mất nó.

	CÒN THIẾU, không bịa: thời gian hồi (`checkSweepCooldown`/`setSweepCooldown`,
	:1952/:1994) là luật CHỈ SERVER GỐC có và không được ship; client không đọc
	nó trước khi gọi nên ở đây không đặt. ]]

--[[ Sao đã lưu của ải. `GetBattleReportsData` trả HAI giá trị
	`(bResult, tBao)`, mà `local a, b = pcall(f, x)` chỉ hứng được giá trị ĐẦU
	của `f` — nên phải hứng đủ ba chỗ, không thì `tBao` nhận nhầm `bResult`. ]]
local function sao_da_luu(strKey)
	if not (G_ChapterLogic and G_ChapterLogic.GetBattleReportsData) then
		return 0
	end
	local kq, bOk, tBao = pcall(G_ChapterLogic.GetBattleReportsData, G_ChapterLogic, strKey)
	if kq and bOk == true and type(tBao) == "table" then
		return tonumber(tBao.RatingType) or 0
	end
	return 0
end

--[[ Trừ thể lực. Trả false khi không đủ (chính là cổng của bản gốc), và trả
	true khi không có gì để trừ — `ChapterUserFatigue` thiếu thì 0, đúng như
	`saveChapterBeginStatus:913` gác `if nNeedFatigue ~= 0`.

	KHÔNG ghi thống kê ở đây: việc ấy do `offline/thong_ke.lua` làm, bọc thẳng
	`G_UserLogic:AddFatigueValue` — phễu mà CẢ đường trận (`saveChapterBeginStatus`
	:915 và `chapterVictoryHandle` :2717) lẫn đường càn quét đều đi qua. Ghi ở
	đây thì trận đánh thường không được đếm, mà mốc 850 là mốc của cả hai đường. ]]
local function tru_the_luc(nLan, cfg, strNguon)
	local nMot = tonumber(cfg and cfg.ChapterUserFatigue) or 0
	local nTru = -nMot * nLan
	if nTru == 0 or not (G_UserLogic and G_UserLogic.AddFatigueValue) then
		return true
	end
	local ok = G_UserLogic:AddFatigueValue(nTru, strNguon)
	return ok == true
end

--[[ Số lần càn quét được phép trong lượt này: luật gốc, chặn trần 10 như
	`CUIChapterInfo.lua:2793-2795`. `CheckCanSweepCount` cũng trả HAI giá trị. ]]
local function so_lan_duoc_quet(strKey)
	if not (G_ChapterLogic and G_ChapterLogic.CheckCanSweepCount) then
		return 0
	end
	local bOk, nMax = G_ChapterLogic:CheckCanSweepCount(strKey)
	if bOk ~= true then
		return 0
	end
	nMax = tonumber(nMax) or 0
	if nMax > 10 then
		nMax = 10
	end
	if nMax < 0 then
		nMax = 0
	end
	return nMax
end

--[[ Trừ số lượt càn quét ĐÃ MUA (xem khối "SỐ LẦN CÀN QUÉT" ở đầu tệp).

	PHẢI HỎI SỐ DƯ TRƯỚC, không được gọi thẳng: `ReduceSweepCount` từ chối ở
	`:1342` khi `SweepCount` là 0, mà `ProcessError` của chính bản gốc IN RA một
	vết lỗi kèm ngăn xếp mỗi lần nó trả false — đo được, mỗi lượt quét đầu tiên
	của người chơi mới đổ một `ProcessError!` vào bảng điều khiển. Hỏi trước thì
	không có vết giả nào, mà ai đã mua lượt vẫn bị trừ đúng. ]]
local function tru_luot_quet(nLan, strNguon)
	if not (G_ChapterLogic and G_ChapterLogic.ReduceSweepCount
		and G_ChapterDataManager and G_ChapterDataManager.GetSweepCount) then
		return
	end
	local bOk, nCo = G_ChapterDataManager:GetSweepCount()
	if bOk ~= true or type(nCo) ~= "number" or nCo < nLan then
		OfflineLog:info(strNguon .. string.format(
			": chua mua du luot can quet (co %s, can %d) — khong co gi de tru",
			tostring(nCo), nLan))
		return
	end
	local ok = G_ChapterLogic:ReduceSweepCount(nLan)
	if ok ~= true then
		OfflineLog:warn(strNguon .. ": ReduceSweepCount tu choi du so du du "
			.. tostring(nCo))
	end
end

--[[ Một lần càn quét: quay rơi đồ MỚI (không có trận nào để nhặt — đúng việc
	`OfflineDrop_build` làm cho `ClientChapterBegin`) rồi để luật gốc ghi vào
	kho. Trả bảng phản hồi, hoặc nil kèm mã lỗi khi luật gốc từ chối. ]]
local function mot_lan_quet(strKey, cfg, nSao)
	local tRoi = OfflineDrop_build(strKey)
	local ok, nErr, tDrop = G_ChapterLogic:chapterSweepHandle(
		cfg, cfg.ChapterUserEx or 0, tRoi, nSao, true, "ClientChapterSweepOnce")
	if not ok then
		return nil, nErr
	end
	return { ChapterKey = strKey, DropList = (type(tDrop) == "table" and tDrop) or tRoi }
end

--[[ Từ chối thì trả ĐÚNG HÌNH mà client ĐỌC ĐƯỢC, nhưng rỗng: nó đòi
	`tRetData.ChapterKey` là CHUỖI và `tRetData.DropList` là BẢNG
	(ClientChapterLogic.lua:509-518), thiếu một trong hai là `ProcessNotString`
	/ `ProcessNotTable` BẮN LỖI ra nhật ký — đo được với phản hồi `{ErrorCode=1}`
	(§E của C:/tmp/th_can_quet5.gd: `Arg must be string!`). Thà một lượt quét
	RỖNG (không ghi gì vào kho, xem dòng dưới) còn hơn một dòng lỗi do lớp của
	mình sinh ra. `tostring` vì ChapterKey có thể là nil khi client gửi bậy. ]]
local function tra_rong(strKey)
	return { ChapterKey = tostring(strKey), DropList = danhSachRoiRong() }
end

R:on("ClientChapterSweepOnce", function(ctx, strChapterKey)
	gan_ham_chi_server()
	local cfg = cau_hinh(strChapterKey)
	if cfg == nil then
		OfflineLog:err("ClientChapterSweepOnce: khong co cau hinh ai "
			.. tostring(strChapterKey))
		ctx:call("G_ChapterLogic", "OnServerChapterSweepOnce", tra_rong(strChapterKey))
		return
	end

	-- Hai cổng của bản gốc, theo `onTouchEnd_OnSweepOne`: `checkFatigueAndTips(1)`
	-- (:2675) rồi `checkBattleCount` (:2684), và `getChapterLeftBattleCount`
	-- (:1803) TỪ CHỐI khi `PlayPerDay - PassMissionCount` ÂM. Thiếu cổng lượt thì
	-- quét một lần vượt được trần thách đấu trong ngày.
	--
	-- HAI CỔNG BỊ ĐẢO so với bản gốc, và đảo là cố ý: bản gốc chỉ HỎI thể lực ở
	-- cổng đầu rồi để phía server TRỪ (`saveChapterBeginStatus:913`), tức phép
	-- trừ nằm SAU mọi cổng của client. `tru_the_luc` ở đây trừ thật, nên đặt nó
	-- đúng vị trí của bản gốc thì cổng lượt từ chối là mất thể lực mà không có
	-- thưởng — đo được trước khi sửa: `PlayPerDay = 0` làm cả hai lượt quét đều
	-- bị từ chối mà thể lực vẫn rơi 500 -> 494. Đổi lại chỉ khác thứ tự hai dòng
	-- nhật ký khi cả hai cổng cùng thiếu.
	if so_lan_duoc_quet(strChapterKey) < 1 then
		OfflineLog:info("ClientChapterSweepOnce " .. tostring(strChapterKey)
			.. ": het luot thach dau trong ngay — khong quet")
		ctx:call("G_ChapterLogic", "OnServerChapterSweepOnce", tra_rong(strChapterKey))
		return
	end

	if not tru_the_luc(1, cfg, "ClientChapterSweepOnce") then
		OfflineLog:warn("ClientChapterSweepOnce " .. tostring(strChapterKey)
			.. ": khong du the luc — khong quet")
		ctx:call("G_ChapterLogic", "OnServerChapterSweepOnce", tra_rong(strChapterKey))
		return
	end

	local tTra, nErr = mot_lan_quet(strChapterKey, cfg, sao_da_luu(strChapterKey))
	if tTra == nil then
		-- Thể lực đã trừ rồi mà phần thưởng không ghi được: trả lại đúng phần
		-- vừa trừ, để kho không lệch so với luật.
		tru_the_luc(-1, cfg, "ClientChapterSweepOnce-hoan")
		OfflineLog:warn(string.format("ClientChapterSweepOnce %s: luat goc tu choi, ma %s",
			tostring(strChapterKey), tostring(nErr)))
		ctx:call("G_ChapterLogic", "OnServerChapterSweepOnce", tra_rong(strChapterKey))
		return
	end

	tru_luot_quet(1, "ClientChapterSweepOnce")
	OfflineStore:syncFromClient()
	ctx:call("G_ChapterLogic", "OnServerChapterSweepOnce", tTra)
end)

--[[ Càn quét mười lần. Client KHÔNG gửi số lần — nó chỉ gửi ChapterKey, còn
	`CheckCanSweepCount` là hàm của server, nên số lần được tính lại ở đây (bản
	gốc cũng vậy: `onTouchEnd_OnSweepTen` tính `nMaxSweepCount` chỉ để HIỂN THỊ
	và để gác, rồi gọi `ChapterSweepTen(key)` trần).

	Mỗi lần quay rơi đồ RIÊNG, và danh sách trả về là một LIST — chính client đọc
	nó bằng `ipairs` và lấy `v.ChapterKey`/`v.DropList` từng mục
	(ClientChapterLogic.lua:583-586); `#tRetData >= 5` mới kích hoạt chèn danh
	sách bảo hiểm `SweepGuaranteeDropList` (:593-598), nên số mục phải đúng bằng
	số lần quét thật, không được gộp. ]]
R:on("ClientChapterSweepTen", function(ctx, strChapterKey)
	gan_ham_chi_server()
	local cfg = cau_hinh(strChapterKey)
	if cfg == nil then
		OfflineLog:err("ClientChapterSweepTen: khong co cau hinh ai "
			.. tostring(strChapterKey))
		ctx:call("G_ChapterLogic", "OnServerChapterSweepTen", {})
		return
	end

	local nLan = so_lan_duoc_quet(strChapterKey)
	if nLan <= 0 then
		OfflineLog:warn("ClientChapterSweepTen " .. tostring(strChapterKey)
			.. ": khong con luot can quet")
		ctx:call("G_ChapterLogic", "OnServerChapterSweepTen", {})
		return
	end

	if not tru_the_luc(nLan, cfg, "ClientChapterSweepTen") then
		OfflineLog:warn("ClientChapterSweepTen " .. tostring(strChapterKey)
			.. ": khong du the luc cho " .. tostring(nLan) .. " lan")
		ctx:call("G_ChapterLogic", "OnServerChapterSweepTen", {})
		return
	end

	local nSao = sao_da_luu(strChapterKey)
	local ds = {}
	for i = 1, nLan do
		local tTra, nErr = mot_lan_quet(strChapterKey, cfg, nSao)
		if tTra == nil then
			OfflineLog:warn(string.format("ClientChapterSweepTen %s lan %d: luat goc tu choi, ma %s",
				tostring(strChapterKey), i, tostring(nErr)))
			break
		end
		ds[#ds + 1] = tTra
	end

	if #ds == 0 then
		tru_the_luc(-nLan, cfg, "ClientChapterSweepTen-hoan")
		ctx:call("G_ChapterLogic", "OnServerChapterSweepTen", {})
		return
	end
	-- Quét được ít hơn xin thì trả lại phần thể lực của những lần KHÔNG quét,
	-- nếu không kho mất thể lực mà không có phần thưởng nào.
	if #ds < nLan then
		tru_the_luc(-(nLan - #ds), cfg, "ClientChapterSweepTen-hoan")
	end

	tru_luot_quet(#ds, "ClientChapterSweepTen")
	OfflineStore:syncFromClient()
	ctx:call("G_ChapterLogic", "OnServerChapterSweepTen", ds)
end)

return true
