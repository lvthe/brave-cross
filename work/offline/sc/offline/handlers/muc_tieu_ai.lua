--[[
	offline/handlers/muc_tieu_ai.lua — MỤC TIÊU ẢI / 关卡目标奖励 (rương ở màn chọn ải).

	Khoá `G_ChapterLogic|ClientGetChapterTargetReward({nMainChapter, nChapterDifficulty,
	nStage})` (`ClientChapterLogic.lua:141`), bấm từ `CUISelectLevel`
	(`onTouchEnd_OnGetChapterTargetReward2`, `:921`). Trước lượt này KHÔNG có handler
	nào ⇒ bấm rương là lớp "đang tải" quay mãi (`GetChapterTargetReward` bật
	`OnWaitingForRequest`, `OnServerGetChapterTargetReward` mới tắt).

	LUẬT LÀ MÃ GỐC CÒN SỐNG: `ChapterLogic:getChapterTargetReward(nMainChapter,
	nChapterDifficulty, nStage)` (`share/share_ChapterLogic.lua:3881-4009`), gọi qua
	THỰC THỂ `G_ChapterLogic` (`ClientChapterLogic` chỉ có bản HOA `GetChapterTargetReward`
	là hàm gửi RPC — KHÁC TÊN nên không đệ quy). Luật tự:
	  · dựng bảng trạng thái từ `GetChapterTargetRewardStatusMap` (đọc `GameChapterConfig.
	    TargetReward.NormalChapterPrizeIDMap` / `HardChapterPrizeIDMap` — cấu hình THẬT:
	    7 chương × 3 mốc, PrizeID 101011… / 102011…; đã tra 4 mã trong
	    `KDBGamePrizeConfig` 2341 dòng, CÓ ĐỦ);
	  · phát thưởng bằng `G_PrizeLogic:ReceivePrizeWithID`;
	  · đặt trạng thái 2 (đã lĩnh) rồi lưu vào `C_TargetRewardData`.

	⚠ MỘT CHỖ PHẢI CHẶN THAY LUẬT GỐC ([MOI], có lý do ĐO ĐƯỢC): luật gốc phát thưởng
	TRƯỚC rồi mới kiểm "đã lĩnh" (`:3960-3979`), nên một yêu cầu LẶP cho mốc đã lĩnh
	sẽ **phát thưởng LẦN HAI** rồi mới trả mã 1431. UI gốc chỉ gửi khi trạng thái = 1
	nên bình thường không chạm; nhưng máy chủ giả không có ai gác hộ, và đồ thử của ta
	gọi thẳng handler. Nên ở đây đọc trạng thái TRƯỚC: bằng 2 thì trả 1431 luôn, không
	gọi luật. Đường bình thường (trạng thái 1) đi NGUYÊN luật gốc.

	Trả về: `OnServerGetChapterTargetReward(tData)` — `ClientChapterLogic.lua:155` đòi
	`tData` là BẢNG và `tData.nPrizeID` là SỐ, rồi đặt `RetData = tData` cho UI
	(`CUISelectLevel.lua:995` dùng `tData.RetData`). Tên hàm nhận không suy ra được
	bằng quy tắc chuỗi của `ctx:reply` nên chỉ tay.

	Mã lỗi: 2 sai tham số · 1430 không dựng được trạng thái / mốc chưa mở · 1431 đã lĩnh.
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflineMucTieuAi = OfflineMucTieuAi or {}

local R = OfflineRouter
local TEN_FILE = "muc tieu ai"

local function dongBo()
	pcall(function () OfflineStore:syncFromClient() end)
end

local function traLoi(ctx, tData)
	ctx:call("G_ChapterLogic", "OnServerGetChapterTargetReward", tData)
end

--[[ Trạng thái của đúng mốc `nStage`: 0 chưa mở · 1 lĩnh được · 2 đã lĩnh · nil lạ.
	Trả nil nếu không dựng nổi bảng trạng thái (để luật gốc tự trả mã của nó). ]]
local function trangThaiMoc(nMainChapter, nChapterDifficulty, nStage)
	local ok, bRet, tStatusMap = pcall(function ()
		return G_ChapterLogic:GetChapterTargetRewardStatusMap(nMainChapter, nChapterDifficulty)
	end)
	if not ok or bRet ~= true or type(tStatusMap) ~= "table" then
		return nil
	end
	return tonumber(tStatusMap[tostring(nStage)])
end

R:on("G_ChapterLogic.ClientGetChapterTargetReward", function (ctx, tData)
	if type(tData) ~= "table" then
		OfflineLog:warn(TEN_FILE .. ": tham so khong phai bang (" .. type(tData) .. ")")
		traLoi(ctx, { err = ErrorCode.ArgError })
		return
	end

	local nMainChapter = tonumber(tData.nMainChapter)
	local nDifficulty = tonumber(tData.nChapterDifficulty)
	local nStage = tonumber(tData.nStage)
	if nMainChapter == nil or nDifficulty == nil or nStage == nil then
		OfflineLog:warn(TEN_FILE .. ": thieu truong trong yeu cau")
		traLoi(ctx, { err = ErrorCode.ArgError })
		return
	end

	-- [MOI] Gác phát-thưởng-hai-lần — xem đầu tệp.
	local tt = trangThaiMoc(nMainChapter, nDifficulty, nStage)
	if tt == 2 then
		OfflineLog:info(string.format("%s: chuong %d / do kho %d / moc %d DA LINH -> 1431",
			TEN_FILE, nMainChapter, nDifficulty, nStage))
		traLoi(ctx, { err = ErrorCode.Chapter.ChapterTargetRewardHasGet })
		return
	end

	local ok, bRet, nPrizeID, nErr = pcall(function ()
		return G_ChapterLogic:getChapterTargetReward(nMainChapter, nDifficulty, nStage)
	end)
	if not ok then
		OfflineLog:err(TEN_FILE .. ": luat goc nem loi: " .. tostring(bRet))
		traLoi(ctx, { err = 1 })
		return
	end

	dongBo()

	if bRet ~= true then
		OfflineLog:info(string.format(
			"%s: chuong %d / do kho %d / moc %d bi tu choi, ma %s (trang thai %s)",
			TEN_FILE, nMainChapter, nDifficulty, nStage, tostring(nErr), tostring(tt)))
		traLoi(ctx, { err = tonumber(nErr) or 1 })
		return
	end

	OfflineLog:info(string.format("%s: da linh chuong %d / do kho %d / moc %d, giai %s",
		TEN_FILE, nMainChapter, nDifficulty, nStage, tostring(nPrizeID)))
	traLoi(ctx, { nPrizeID = tonumber(nPrizeID) or 0 })
end)

OfflineLog:info("muc tieu ai: da noi 1 khoa (ClientGetChapterTargetReward)")

return true
