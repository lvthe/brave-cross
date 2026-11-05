--[[
	offline/handlers/dau_truong_chi_tiet.lua — XEM ĐỘI HÌNH ĐỐI THỦ TRƯỚC KHI ĐÁNH.

	Hai lệnh `G_ArenaLogic` còn trả 2306:

	  · `ClientGetArenaDetailByUid(Uid, nRobotId)` (`ClientArenalLogic.lua:799`) —
	    callback PHƯƠNG THỨC `OnGetArenaDetailByUid(retUserArenaData)`; người đọc:
	    `CUILeaderboard:GetArenaDetailCallBack` (`:489-519`) cần
	    **`tArenaDetail.ArenaHeroMap`** (bảng) + **`UserFightCapacity`**, và
	    `CUIFriend2Info:GetArenaDetailCallBack` (`:1774`) đọc thêm **`ArenaRank`**.
	  · `ClientGetUserArenaFightData(uid)` (`CServerRequestLogic.lua:403-405`) —
	    callback TOÀN CỤC `OnGetUserArenaFightData(tData)` đọc `tData.data`
	    (`CServerResponseLogic.lua:1081-1089`). ĐO: **không UI nào nghe**
	    `CUINotificationEvent.OnGetUserArenaFightData` (grep = 0 ngoài định nghĩa) ⇒
	    trả dữ liệu cho đúng hợp đồng, ghi rõ là TRƠ, không bịa thêm màn.

	NGUỒN: `GameArenaRobotConfig[*].FightData.Data` — cùng nguồn và cùng cách đổi
	chín khoá hỏng dấu cách mà `dau_truong_tran.lua` đã dùng (chép bảng `TEN_SAI`,
	KHAI RÕ là chép — hai bản phải giống nhau, đừng sửa lẻ một bên).

	`ArenaHeroMap` dạng `{ [UserHeroID] = bản ghi tướng }` — thêm ba trường bắt buộc
	mà UI vẽ cần (`UserHeroID`, `HeroLevel`, `HeroQuality`) vì `Data` của robot không
	có; đó là ĐẶT, ghi rõ ở đây.
]]

require("offline.log")
require("offline.store")
require("offline.router")

local R = OfflineRouter

-- CHÉP từ `dau_truong_tran.lua` (TEN_SAI) — hai tệp phải cùng một bảng.
local TEN_SAI = {
	["CriticalStr ike"] = "CriticalStrike",
	["Min Ap"] = "MinAp",
	["MaxA p"] = "MaxAp",
	["D p"] = "Dp",
	["P iercingAp"] = "PiercingAp",
	["DamageAdd ition"] = "DamageAddition",
	["RecoveryB lood"] = "RecoveryBlood",
	["Resurrect ionTime"] = "ResurrectionTime",
	[" MaxAttackDistance"] = "MaxAttackDistance",
}

local function chepSau(v, doiTen)
	if type(v) ~= "table" then return v end
	local out = {}
	for k, x in pairs(v) do
		out[(doiTen and TEN_SAI[k]) or k] = chepSau(x, doiTen)
	end
	return out
end

local function cfg(ten)
	local ok, v = pcall(function () return G_ConfigManager:GetCommonConfigWithName(ten) end)
	if ok and type(v) == "table" then return v end
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

local function arena()
	local ok, u = pcall(function ()
		local _, x = G_ArenaDataManager:GetUserArena()
		return x
	end)
	if ok then return u end
	return nil
end

local function hang()
	local u = arena()
	local r = tonumber(u and u.Ranking)
	if r == nil or r <= 0 then r = 1000 end
	return r
end

--[[ Dựng `ArenaHeroMap` từ `Data` của robot + ba trường ĐẶT cho UI vẽ. ]]
local function banDoTuongRobot(base)
	local robots = cfg("GameArenaRobotConfig")
	if type(robots) ~= "table" then return nil end
	local r = nil
	for _, x in pairs(robots) do if type(x) == "table" then r = x; break end end
	if r == nil or type(r.FightData) ~= "table" or type(r.FightData.Data) ~= "table" then
		return nil
	end
	local map = {}
	for k, h in pairs(r.FightData.Data) do
		if type(h) == "table" then
			local o = chepSau(h, true)
			o.UserHeroID = tonumber(o.UserHeroID) or tonumber(k) or 25
			o.HeroLevel = tonumber(o.HeroLevel) or tonumber(base and base.Level) or 1
			o.HeroQuality = tonumber(o.HeroQuality) or 1
			o.IsLock = false
			map[tostring(o.UserHeroID)] = o
		end
	end
	return map
end

R:on("G_ArenaLogic.ClientGetArenaDetailByUid", function (ctx, nUid, _nRobotId)
	local base = baseInfo() or {}
	local map = banDoTuongRobot(base)
	if map == nil then
		OfflineLog:err("dau truong chi tiet: KHONG dung duoc ArenaHeroMap (thieu GameArenaRobotConfig)")
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", 2306, {})
		return
	end
	local goi = {
		Uid = tonumber(nUid) or 0,
		ArenaRank = hang(),                              -- UI hiện hạng đối thủ
		UserFightCapacity = tonumber(base.UserFightCapacity) or 0,
		ArenaHeroMap = map,
	}
	OfflineLog:info(string.format("dau truong chi tiet: uid %s, %d tuong", tostring(nUid), (function ()
		local n = 0; for _ in pairs(map) do n = n + 1 end; return n
	end)()))
	ctx:call("G_ArenaLogic", "OnGetArenaDetailByUid", goi)
end)

R:on("G_ArenaLogic.ClientGetUserArenaFightData", function (ctx, nUid)
	local base = baseInfo() or {}
	local map = banDoTuongRobot(base) or {}
	local fd = {
		BaseInfo = {
			CharacterName = "Robot " .. tostring(nUid or ""),
			Gender = true,
			Level = tonumber(base.Level) or 1,
			HeroID = tonumber(base.HeroID) or 25,
			UserArenaFightCapacity = tonumber(base.UserArenaFightCapacity) or 0,
		},
		Data = map,
		Groups = {},
		GameUserFormation = {},
	}
	-- Callback TOÀN CỤC (`obj=''`), đọc `tData.data`. ĐO: không UI nào nghe notification
	-- này — trả đúng hợp đồng, KHÔNG dựng màn.
	ctx:call("", "OnGetUserArenaFightData", { err = 0, data = { FightData = fd } })
end)

OfflineLog:info("dau truong chi tiet: da noi 2 khoa (ClientGetArenaDetailByUid / ClientGetUserArenaFightData)")

return true
