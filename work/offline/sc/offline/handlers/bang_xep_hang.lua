--[[
	offline/handlers/bang_xep_hang.lua — BẢNG XẾP HẠNG chung (tab PvE + chiến lực 5 tướng).

	Bốn khoá `G_RankLogic` (`ClientLeaderboardLogic`, thực thể `G_RankLogic`):

	  · `ClientGet5HeroPowerRank`  → `OnGet5HeroPowerRank(tRankList, nSelfRank, nYesterdayRank)`
	  · `ClientGetPveNormalRank`   → `OnGetPveNormalRank(...)`
	  · `ClientGetPveEliteRank`    → `OnGetPveEliteRank(...)`
	  · `ClientGetPveStarRank`     → `OnGetPveStarRank(...)`

	(`user/Logical/ClientLeaderboard.lua:279/508/561/614`. Tab tương ứng của
	`CUILeaderboard`.) Trước lượt này KHÔNG có handler nào ⇒ mở tab là màn hình quay.

	KHÔNG có luật để port: bảng xếp hạng là **trạng thái máy chủ** (ai đứng thứ mấy),
	không phải hàm. `share/` chỉ có hàm ĐỌC phía client.

	OFFLINE MỘT NGƯỜI ⇒ bảng chỉ có CHÍNH MÌNH, hạng 1. Đó là SỰ THẬT của máy chủ giả này
	chứ không phải số bịa — cùng quyết định đã dùng cho BXH đấu trường
	(`handlers/dau_truong_bxh.lua`). [MOI] nằm ở chỗ "hạng 1": máy chủ thật tính hạng từ
	dữ liệu toàn máy chủ; ở đây chỉ có một người nên hạng 1 là hệ quả, không phải ước lượng.

	QUAN TRỌNG — DÒNG CỦA MÌNH PHẢI CÓ TÊN (đo 1/11): trả bảng RỖNG thì UI tự vá bằng
	`self:getHotdata()` (`CUILeaderboard.lua:563-580`), nhưng hàm ấy đọc bảng `Hotdata`
	do MÁY CHỦ gửi — offline không ai sinh ⇒ bảng hiện "hạng 1" mà **TRỐNG TÊN**. Vì thế
	ở đây dựng dòng bằng chính `G_RankLogic:GetUserHotData()` (xem `dongCuaMinh`).
	UI vẫn tự điền `chapterKey` cho tab PvE, nên không đụng trường ấy.

	Ba trường bắt buộc, thiếu cái nào client cũng bỏ qua cả bảng
	(`ProcessNotNumber(nSelfRank)` → thoát): `tRankList` (bảng), `nSelfRank`, `nYesterdayRank`.
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflineBangXepHang = OfflineBangXepHang or {}

local R = OfflineRouter
local TEN_FILE = "bang xep hang"
local HANG = 1

--[[ Uid mà UI dùng để đối chiếu dòng của mình — `CUILeaderboard` gọi
	`g_CUIGameRPCManager:GetChinaMixUid()` (`:545`); phải trả ĐÚNG số ấy, lệch là UI
	coi dòng của mình là "người khác". Bản dự phòng chỉ dùng khi manager vắng. ]]
local function uidCuaMinh()
	local ok, u = pcall(function () return g_CUIGameRPCManager:GetChinaMixUid() end)
	u = ok and tonumber(u) or nil
	if u == nil then
		ok, u = pcall(function () return OfflineStore:uid() end)
		u = ok and tonumber(u) or nil
	end
	return u or 1
end

--[[ Một dòng của bảng, dựng bằng CHÍNH hàm của client:
	`G_RankLogic:GetUserHotData()` (`ClientLeaderboard.lua:785-825`) trả
	CharacterName/Level/Gold/Gender/Diamond/UserArenaFightCapacity/HeroFight, đọc thẳng
	`GetBaseInfo()` và `GetSelf5HeroPower()`. Không bịa trường nào.

	VÌ SAO PHẢI CÓ DÒNG NÀY: nếu trả bảng RỖNG, UI tự vá bằng `self:getHotdata()` —
	nhưng hàm ấy đọc bảng `Hotdata` do MÁY CHỦ gửi, offline không ai sinh ⇒ dòng hiện
	"hạng 1" mà TRỐNG TÊN (đo được 1/11: `dong 1: nil/hang 1`).

	Hàm ấy có thể ném lỗi khi bảng `Hotdata`/quân đoàn thiếu ⇒ bọc `pcall`, chấp nhận
	dòng tối thiểu `{ Rank = 1 }` chứ không làm hỏng cả bảng. ]]
local function dongCuaMinh()
	local ok, bRet, tHot = pcall(function ()
		return G_RankLogic:GetUserHotData()
	end)
	local dong = {}
	if ok and bRet == true and type(tHot) == "table" then
		for k, v in pairs(tHot) do dong[k] = v end
	else
		OfflineLog:warn(TEN_FILE .. ": khong dung duoc GetUserHotData — dung dong toi thieu")
	end
	dong.Rank = HANG
	return dong
end

--[[ Trả lời một tab. `ctx:call` gọi THẲNG hàm client với BA tham số vị trí — không
	bọc `{err, data}` — vì cả bốn hàm `OnGet*Rank` của client đều nhận đúng ba tham số
	này và kiểm từng cái một. ]]
local function traLoi(ctx, hamNhan)
	local danhSach = {}
	danhSach[tostring(uidCuaMinh())] = dongCuaMinh()
	ctx:call("G_RankLogic", hamNhan, danhSach, HANG, HANG)
end

R:on("G_RankLogic.ClientGet5HeroPowerRank", function (ctx)
	OfflineLog:info(TEN_FILE .. ": chien luc 5 tuong — offline mot nguoi, mot dong + hang 1")
	traLoi(ctx, "OnGet5HeroPowerRank")
end)

R:on("G_RankLogic.ClientGetPveNormalRank", function (ctx)
	OfflineLog:info(TEN_FILE .. ": PvE thuong — offline mot nguoi, mot dong + hang 1")
	traLoi(ctx, "OnGetPveNormalRank")
end)

R:on("G_RankLogic.ClientGetPveEliteRank", function (ctx)
	OfflineLog:info(TEN_FILE .. ": PvE tinh anh — offline mot nguoi, mot dong + hang 1")
	traLoi(ctx, "OnGetPveEliteRank")
end)

--[[ BXH QUÂN ĐOÀN — `ClientGetGuildRank(nGuildId)` (`ClientLeaderboard.lua:668-690`).
	ĐO TRONG GAME 1/11: bấm tab "Quân Đoàn" của `CUILeaderboard` ⇒ `THIEU G_RankLogic.ClientGetGuildRank`
	⇒ màn hình quay mãi. Cùng hình với các tab khác: `(tRankList, nSelfRank, nYesterdayRank)`,
	mỗi dòng là `{ GuildName, GuildData = { Name, PictrueId, … }, Rank }` (`CUILeaderboard.lua:2269-2355`).
	Một bang duy nhất (của mình) ⇒ hạng 1; chưa lập bang ⇒ bảng RỖNG, hạng 0. ]]
R:on("G_RankLogic.ClientGetGuildRank", function (ctx)
	local ds, hang = {}, 0
	local b = nil
	pcall(function ()
		if type(OfflineBangHoi) == "table" and OfflineBangHoi.bang then
			b = OfflineBangHoi:bang()
		end
	end)
	if b ~= nil and tonumber(b.GuildId) then
		hang = 1
		ds[tostring(b.GuildId)] = {
			GuildName = b.Name,
			GuildData = {
				GuildId = b.GuildId,
				Name = b.Name,
				PictrueId = b.PictrueId,
				Level = 1,
				MemberCount = b.MemberCount,
			},
			Rank = 1,
		}
	end
	OfflineLog:info(string.format("%s: BXH quan doan — %s", TEN_FILE,
		b and ("bang '" .. tostring(b.Name) .. "', hang 1") or "chua lap bang, bang rong"))
	ctx:call("G_RankLogic", "OnGetGuildRank", ds, hang, hang)
end)

R:on("G_RankLogic.ClientGetPveStarRank", function (ctx)
	OfflineLog:info(TEN_FILE .. ": PvE sao — offline mot nguoi, mot dong + hang 1")
	traLoi(ctx, "OnGetPveStarRank")
end)

OfflineLog:info("bang xep hang: da noi 4 khoa (5 tuong / PvE thuong / tinh anh / sao)")

return true
