--[[
	offline/handlers/bang_xep_hang_che_do.lua — BẢNG XẾP HẠNG CỦA CÁC CHẾ ĐỘ ẢI ĐẶC BIỆT
	(14 khoá `G_RankLogic`).

	Vì sao có tệp này: mỗi chế độ ải (黄巾入侵 / 十常侍 / 定军山剿匪 / 三英战吕布 /
	血战宛城 / 潼关之战 / 荡寇) có một bảng xếp hạng riêng. Client gọi `G_RankLogic`
	14 lần và trước lượt này KHÔNG khoá nào có handler ⇒ mở tab xếp hạng của chế độ
	là lớp tải quay mãi.

	MÔ HÌNH: offline MỘT người ⇒ mỗi bảng chỉ có MỘT dòng là CHÍNH MÌNH, hạng 1.
	Cùng quyết định đã dùng cho BXH chung (`bang_xep_hang.lua`) và BXH đấu trường
	(`dau_truong_bxh.lua`) — không bịa thêm người chơi.

	DỮ LIỆU THẬT (không bịa):
	  · dòng của mình dựng bằng `G_RankLogic:GetUserHotData()` (tên/cấp/gender/lực
	    chiến) + `GetBaseInfo().Portrait`.
	  · điểm từng chế độ lấy từ THỐNG KÊ có thật của client
	    (`G_UserLogic:GetStatisticsCommonData`):
	      HJRQ  → `MaxHJRQBatchCount` (`share/Statistics.lua:298-339` ghi khi qua ải)
	      TGZZ  → `TGZZChapterLevel` / `TGZZChapterBestDamage` / `TGZZChapterBestCostTime`
	      DK    → `DKChapterLevel` / `DKChapterBestDamage` / `DKChapterBestCostTime`
	    (`share/share_ChapterLogic.lua:5704-5890` đọc đúng ba tên này.)
	  · chế độ CHƯA có thống kê trong client (SCS killCount, SYZLB/XZWC costTime,
	    DJSJF damage) trả **0** — trung thực: offline chưa từng ghi số ấy.

	HÌNH PHẢN HỒI (đọc từ mã client — mỗi khoá một hình, KHÔNG gộp):
	  · "điểm của mình": `OnGetSelf…RankScore(số)` — HJRQ là HAI số (costTime, wave).
	  · "bảng xếp hạng": `OnGet…Rank(tRankList[, chapterKey])` — tRankList là BẢN ĐỒ
	    khoá `uid_server` (UI tự đặt `strUid = k`), mỗi dòng có `Rank`, tên/cấp/ảnh,
	    `power`, và trường riêng của chế độ (`wave`,`costTime`,`killCount`,`damage`,
	    `level`) — danh sách trường đọc từ `CUIActivityModeLeadboard.lua:550-600`.
	  · `ArenaDefendPowerRank` / `GuildWarScoreRank`: BA tham số (bảng, hạng mình,
	    hạng hôm qua) — UI kiểm `ProcessNotNumber` cả hai số.
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflineBXHCheDo = OfflineBXHCheDo or {}

local R = OfflineRouter
local TEN_FILE = "BXH che do"

local function goi(ctx, hamNhan, ...)
	local a = { n = select("#", ...), ... }
	local ok, e = pcall(function ()
		return ctx:call("G_RankLogic", hamNhan, unpack(a, 1, a.n))
	end)
	if not ok then
		OfflineLog:err(string.format("%s: khong goi duoc G_RankLogic.%s -> %s",
			TEN_FILE, tostring(hamNhan), tostring(e)))
	end
end

local function soLieu(strKey)
	local ok, bRet, v = pcall(function ()
		return G_UserLogic:GetStatisticsCommonData(strKey)
	end)
	if ok and bRet ~= false and tonumber(v) then return tonumber(v) end
	return 0
end

local function uidStr()
	local uid = 1
	pcall(function () uid = tonumber(OfflineBangHoi:uid()) or 1 end)
	return tostring(uid) .. "_1"
end

--[[ Một dòng của bảng, dựng bằng CHÍNH hàm client (`GetUserHotData` trả
	`(bResult, tHotData)`) + Portrait từ hồ sơ. `them` là trường riêng chế độ. ]]
local function dongCuaMinh(them)
	local d = {}
	local ok, bRet, tHot = pcall(function () return G_RankLogic:GetUserHotData() end)
	if ok and bRet == true and type(tHot) == "table" then
		for k, v in pairs(tHot) do d[k] = v end
	else
		OfflineLog:warn(TEN_FILE .. ": khong dung duoc GetUserHotData — dung dong toi thieu")
	end
	pcall(function ()
		local ok2, r, base = pcall(function () return G_UserLogic:GetBaseInfo() end)
		local t = (ok2 and type(base) == "table") and base or ((ok2 and type(r) == "table") and r or {})
		d.Portrait = t.Portrait or d.Portrait
		d.CharacterName = d.CharacterName or t.CharacterName or "Offline"
		d.Level = d.Level or tonumber(t.Level) or 1
		if d.Gender == nil then d.Gender = t.Gender end
	end)
	d.Rank = 1
	d.power = tonumber(d.power) or tonumber(d.UserArenaFightCapacity) or 0
	d.UserArenaFightCapacity = tonumber(d.UserArenaFightCapacity) or d.power
	for k, v in pairs(them or {}) do d[k] = v end
	return d
end

-- Bản đồ một dòng (UI tự đặt `strUid = khoá`).
local function bangMot(them)
	return { [uidStr()] = dongCuaMinh(them) }
end

------------------------------------------------------------------- ĐIỂM CỦA MÌNH
--[[ HJRQ: `OnGetSelfHJRQRankScore(nCostTime, nWave)` — HAI số. ]]
R:on("G_RankLogic.ClientGetSelfHJRQRankScore", function (ctx, strChapterKey)
	goi(ctx, "OnGetSelfHJRQRankScore", 0, soLieu("MaxHJRQBatchCount"))
end)

R:on("G_RankLogic.ClientGetSelfSYZLBRankScore", function (ctx, strChapterKey)
	goi(ctx, "OnGetSelfSYZLBRankScore", 0)
end)

R:on("G_RankLogic.ClientGetSelfSCSZLRankScore", function (ctx)
	goi(ctx, "OnGetSelfSCSZLRankScore", 0)
end)

R:on("G_RankLogic.ClientGetSelfDJSJFRankScore", function (ctx)
	goi(ctx, "OnGetSelfDJSJFRankScore", 0)
end)

R:on("G_RankLogic.ClientGetSelfXZWCRankScore", function (ctx, strChapterKey)
	goi(ctx, "OnGetSelfXZWCRankScore", 0)
end)

------------------------------------------------------------------- BẢNG XẾP HẠNG
R:on("G_RankLogic.ClientGetHjrqRank", function (ctx, strChapterKey)
	goi(ctx, "OnGetHjrqRank", bangMot({ wave = soLieu("MaxHJRQBatchCount"), costTime = 0 }),
		tostring(strChapterKey or "FB_E_HJRQ"))
end)

R:on("G_RankLogic.ClientGetSYZLBRank", function (ctx, strChapterKey)
	goi(ctx, "OnGetSYZLBRank", bangMot({ costTime = 0 }))
end)

R:on("G_RankLogic.ClientGetSCSZLRank", function (ctx)
	goi(ctx, "OnGetSCSZLRank", bangMot({ killCount = 0 }))
end)

R:on("G_RankLogic.ClientGetDJSJFRank", function (ctx)
	goi(ctx, "OnGetDJSJFRank", bangMot({ damage = 0 }))
end)

R:on("G_RankLogic.ClientGetXZWCRank", function (ctx, strChapterKey)
	goi(ctx, "OnGetXZWCRank", bangMot({ costTime = 0 }))
end)

--[[ TGZZ / DK: UI đọc `level` và `damage` (`CUIActivityModeLeadboard.lua:560-600`). ]]
R:on("G_RankLogic.ClientGetTGZZRank", function (ctx)
	goi(ctx, "OnGetTGZZRank", bangMot({
		level = soLieu("TGZZChapterLevel"),
		damage = soLieu("TGZZChapterBestDamage"),
		costTime = soLieu("TGZZChapterBestCostTime"),
	}))
end)

R:on("G_RankLogic.ClientGetDKRank", function (ctx)
	goi(ctx, "OnGetDKRank", bangMot({
		level = soLieu("DKChapterLevel"),
		damage = soLieu("DKChapterBestDamage"),
		costTime = soLieu("DKChapterBestCostTime"),
	}))
end)

------------------------------------------------------------------- BXH KHÁC
--[[ BXH lực chiến phòng thủ đấu trường — UI hiện KHÔNG còn gọi (dòng gọi đã bị chú
	thích `CUILeaderboard.lua:1643`), nhưng vẫn trả đúng hình 3 tham số để nếu bản
	khác gọi thì không treo. ]]
R:on("G_RankLogic.ClientGetArenaDefendPowerRank", function (ctx)
	goi(ctx, "OnGetArenaDefendPowerRank", bangMot({}), 1, 1)
end)

--[[ BXH "hổ phù" bang hội (GuildWarCoin). Offline: một bang của mình ⇒ một dòng,
	hạng 1; CHƯA có bang ⇒ bảng rỗng + hạng 0 (UI vẫn qua vì hai số là NUMBER). ]]
R:on("G_RankLogic.ClientGetGuildWarScoreRank", function (ctx, nGuildId)
	local b = nil
	pcall(function () b = OfflineBangHoi:doc() end)
	local gu = nil
	pcall(function ()
		-- `GetUserDataWithName` trả `(bRetCode, bảng)` — KHÔNG bọc pcall thì chỉ hai
		-- giá trị, đọc ba là lệch hết (bẫy quen thuộc của tệp này).
		local maLoi, t = G_DataManager:GetUserDataWithName("GameUserGuildData")
		if maLoi == 0 and type(t) == "table" then gu = t end
	end)
	local ds = {}
	local hang = 0
	if type(b) == "table" and tonumber(b.GuildId) then
		hang = 1
		ds[tostring(b.GuildId)] = {
			Rank = 1,
			GuildId = tonumber(b.GuildId),
			GuildName = b.Name or "Guild",
			GuildData = { Name = b.Name or "Guild" },
			Score = tonumber(gu and gu.GuildWarCoin) or 0,
		}
	end
	local dem = 0
	for _ in pairs(ds) do dem = dem + 1 end
	OfflineLog:info(string.format("%s: BXH ho phu -> %d dong (hang %d)", TEN_FILE, dem, hang))
	goi(ctx, "OnGetGuildWarScoreRank", ds, hang, hang)
end)

OfflineLog:info("BXH che do: da noi 14 khoa (7 che do ai + phong thu dau truong + ho phu)")

return true
