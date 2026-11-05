--[[
	offline/handlers/dau_truong_bxh.lua — BẢNG XẾP HẠNG + DỮ LIỆU ĐẤU TRƯỜNG (offline).

	Ba lệnh `G_ArenaLogic` mà `handlers/dau_truong.lua` còn trả 2306 (từ 28/10):

	  · `GetWorldArenalRanking(min, max)` — bảng xếp hạng đấu trường
	    (`CUIArenalLeaderboard.lua:59`). Callback NHẬN MỘT MẢNG:
	    `OnGetWorldArenalRanking(rankingList)`; mỗi mục cần
	    `RankID`, `Uid`, `BaseInfo.{CharacterName,Portrait,Gender,Level,UserFightCapacity,HeroID}`,
	    `HeroList` (danh sách bản ghi tướng — `CUIArenaMain:SortHeroList` đọc
	    `UserHeroID`/`HeroLevel`) — đọc ở `CUIArenalLeaderboard:RefleshItem`.
	  · `GetArenaRankWithYesterday()` — tab đấu trường của BXH chung
	    (`CUILeaderboard.lua:96`); callback `(tRankList, nSelfRank, nYesterdayRank)`
	    với `tRankList` là BẢN ĐỒ khoá theo uid CHUỖI (cùng hình dạng đã dùng ở
	    server riêng, Mốc 57).
	  · `ClientGetUserArenaData()` — dữ liệu đấu trường của mình; callback TOÀN CỤC
	    `OnGetUserArenaData(tData)` đọc `tData.data` rồi `G_DataManager:SetUserArenaData`.

	OFFLINE MỘT NGƯỜI: bảng chỉ có CHÍNH MÌNH — đó là sự thật, không phải lỗi. Nói rõ
	để lượt sau không tưởng thiếu dữ liệu. `HeroList` lấy **5 tướng mạnh nhất theo cấp**
	từ bản ghi thật (`GetHeroMap(true)` — chỉ tướng không khoá), không bịa chỉ số.
]]

require("offline.log")
require("offline.store")
require("offline.router")

local R = OfflineRouter
local SO_TUONG = 5

local function arena()
	local ok, u = pcall(function ()
		local _, x = G_ArenaDataManager:GetUserArena()
		return x
	end)
	if ok then return u end
	return nil
end

local function baseInfo()
	local ok, r, b = pcall(function () return G_UserLogic:GetBaseInfo() end)
	if ok then
		if type(b) == "table" then return b end
		if type(r) == "table" then return r end
	end
	return nil
end

local function uid()
	local b = baseInfo()
	if b and tonumber(b.Uid) and tonumber(b.Uid) > 0 then return tonumber(b.Uid) end
	local ok, u = pcall(function () return OfflineStore:uid() end)
	return (ok and tonumber(u)) or 1
end

local function hang()
	local u = arena()
	local r = tonumber(u and u.Ranking)
	if r == nil or r <= 0 then r = 1000 end     -- cùng mốc ĐẶT của `dau_truong.lua`
	return r
end

--[[ Năm tướng mạnh nhất theo CẤP (hoà thì UserHeroID lớn trước — thứ tự tất định). ]]
local function topTuong()
	local ok, bRet, map = pcall(function () return G_HeroLogic:GetHeroMap(true) end)
	local ds = {}
	if ok and type(map) == "table" then
		for _, h in pairs(map) do
			if type(h) == "table" then ds[#ds + 1] = h end
		end
	end
	table.sort(ds, function (a, b)
		local la, lb = tonumber(a.HeroLevel) or 0, tonumber(b.HeroLevel) or 0
		if la ~= lb then return la > lb end
		return (tonumber(a.UserHeroID) or 0) > (tonumber(b.UserHeroID) or 0)
	end)
	local ra = {}
	for i = 1, math.min(SO_TUONG, #ds) do ra[i] = ds[i] end
	return ra
end

-- Một dòng của bảng: hồ sơ + hạng + tướng.
local function dongCuaMinh()
	local b = baseInfo() or {}
	return {
		RankID = hang(),
		Uid = uid(),
		BaseInfo = {
			CharacterName = b.CharacterName,
			Portrait = b.Portrait,
			Gender = b.Gender,
			Level = b.Level,
			HeroID = b.HeroID,
			UserFightCapacity = tonumber(b.UserFightCapacity) or 0,
		},
		HeroList = topTuong(),
	}
end

R:on("G_ArenaLogic.GetWorldArenalRanking", function (ctx, nMin, nMax)
	local min = tonumber(nMin) or 1
	local max = tonumber(nMax) or 20
	local ds = {}
	-- Chỉ có MỘT người chơi: dòng duy nhất nằm ở khoảng 1..max của trang đầu.
	if min <= 1 and max >= 1 then ds[1] = dongCuaMinh() end
	OfflineLog:info(string.format("dau truong bxh: tra %d dong (khoang %s..%s)", #ds, tostring(min), tostring(max)))
	ctx:call("G_ArenaLogic", "OnGetWorldArenalRanking", ds)
end)

R:on("G_ArenaLogic.GetArenaRankWithYesterday", function (ctx)
	local b = baseInfo() or {}
	local h = hang()
	local banDo = {}
	banDo[tostring(uid())] = {
		CharacterName = b.CharacterName, Portrait = b.Portrait, Gender = b.Gender,
		Level = b.Level, HeroID = b.HeroID,
		UserArenaFightCapacity = tonumber(b.UserArenaFightCapacity) or 0,
		Rank = h,
	}
	-- `nYesterdayRank` = hạng hôm nay: offline KHÔNG lưu hạng hôm qua (đã khai).
	ctx:call("G_ArenaLogic", "OnGetArenaRankWithYesterday", banDo, h, h)
end)

R:on("G_ArenaLogic.ClientGetUserArenaData", function (ctx)
	local u = arena() or {}
	ctx:call("", "OnGetUserArenaData", { err = 0, data = u })
end)

OfflineLog:info("dau truong bxh: da noi 3 khoa (GetWorldArenalRanking / GetArenaRankWithYesterday / ClientGetUserArenaData)")

return true
