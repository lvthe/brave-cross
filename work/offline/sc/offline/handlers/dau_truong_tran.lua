--[[
	offline/handlers/dau_truong_tran.lua — TRẬN ĐẤU TRƯỜNG (offline, đánh robot).

	`handlers/dau_truong.lua` từ 28/10 trả **2306** cho toàn bộ nhóm trận, lý do ghi
	ở đầu tệp ấy: "cần `FightData` đầy đủ; cấu hình chỉ có MỘT robot mẫu, không có
	tên/hạng/lực chiến". Lượt này ĐO LẠI và làm được, vì hai điều trước đây bị bỏ qua:

	  1. `GameArenaRobotConfig` **CÓ** `FightData` thật: `Data` (chỉ số tướng) +
	     `Groups` (đội hình). Thiếu duy nhất `BaseInfo` — mà danh sách đối thủ
	     (`dau_truong.lua:71`) ĐÃ tự dựng `BaseInfo` cho robot từ trước.
	  2. Chín khoá của `Data` **HỎNG DẤU CÁCH** (lỗi của bản dịch ngược, không phải
	     của cấu hình): `"CriticalStr ike"`, `"Min Ap"`, `"MaxA p"`, `"D p"`,
	     `"P iercingAp"`, `"DamageAdd ition"`, `"RecoveryB lood"`, `"Resurrect ionTime"`,
	     `" MaxAttackDistance"`. Đổi về tên đúng là việc CỦA TA, ghi rõ ở `TEN_SAI`.

	BA LỆNH (đều objName `G_ArenaLogic`, module ARENA_SERVER):
	  · `ArenaFightRanking(argData)` — client gửi `{Uid, HeroList, Ranking}`
	    (`CUIBattleDeploy.lua:3433-3439`); trả `{FightData=<địch>, FightHeroList=<TA>,
	    BattleRandom}` (`CUIBattleDeploy:OnArenaFightLocalArmy` `:3487`).
	    `FightHeroList` là danh sách TƯỚNG CỦA MÌNH (`GetArmyDatatWithUserData`), KHÔNG
	    phải của địch — đọc nhầm là trận của mình thành robot.
	  · `CompeleteArenaFight(resultData)` — client gửi `{bResult, Replay}` sau trận
	    (`CUIGame.lua:245`, `FBArena.lua:304`). Cộng danh vọng **theo
	    `GameArenaConfig.WinHonour/LoseHonour`**, thắng thì hạng −1 (sàn 1) — cùng luật
	    đã dùng ở server riêng (Mốc 51). Trả `{bResult, Ranking, UserHonnor}`.
	  · `GetUserArenaFightRecord()` — trả danh sách chiến báo đã lưu trong
	    `GameUserArenaRank.FightRecords`.

	[GHIM] Trận THẬT do client chạy (bản đựng lại này client-authoritative); máy chủ
	offline chỉ cấp `FightData` và kết toán theo `bResult` client báo — đúng khuôn
	`FBArena.lua:304`. `BattleRandom` là số ngẫu nhiên của TA (máy chủ gốc sinh nó).
]]

require("offline.log")
require("offline.store")
require("offline.router")

local R = OfflineRouter

-- Chín khoá HỎNG DẤU CÁCH của `KDBGameArenaRobotConfig.FightData.Data` (bản dịch
-- ngược cắt sai chỗ). Tên đích lấy từ đúng những khoá CÙNG NGHĨA đã đúng trong bản ghi.
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
		local kMoi = doiTen and TEN_SAI[k] or nil
		out[kMoi or k] = chepSau(x, doiTen)
	end
	return out
end

local function cfg(ten)
	local ok, v = pcall(function () return G_ConfigManager:GetCommonConfigWithName(ten) end)
	if ok and type(v) == "table" then return v end
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

local function baseInfo()
	local ok, r, b = pcall(function () return G_UserLogic:GetBaseInfo() end)
	if ok then
		if type(b) == "table" then return b end
		if type(r) == "table" then return r end
	end
	return nil
end

--[[ Dựng `FightData` của ROBOT từ cấu hình. `BaseInfo` là ĐẶT (cấu hình không có):
	tên "Robot <uid>", giới tính nam, cấp/lực chiến mượn của người chơi để màn bố trí
	không hiện 0 và không sắp xếp vô lý — cùng quyết định đã có ở `dau_truong.lua:71`. ]]
local function dungFightDataRobot(base)
	local robots = cfg("GameArenaRobotConfig")
	if type(robots) ~= "table" then return nil end
	local r = nil
	for _, x in pairs(robots) do
		if type(x) == "table" then r = x; break end
	end
	if r == nil or type(r.FightData) ~= "table" then return nil end

	local fd = chepSau(r.FightData, true)
	-- Khoá "Groups " (có dấu cách cuối) là lỗi cùng họ; chuẩn hoá.
	if fd["Groups "] ~= nil and fd.Groups == nil then
		fd.Groups = fd["Groups "]
		fd["Groups "] = nil
	end
	fd.Data = fd.Data or {}
	fd.Groups = fd.Groups or {}
	fd.GameUserFormation = fd.GameUserFormation or {}
	fd.BaseInfo = {
		CharacterName = "Robot " .. tostring(r.Uid or ""),
		Gender = true,
		Level = tonumber(base and base.Level) or 1,
		HeroID = tonumber(base and base.HeroID) or 25,
		UserArenaFightCapacity = tonumber(base and base.UserArenaFightCapacity) or 0,
		Portrait = "",
		IconName = "ui_player000M.png",
	}
	return fd, tonumber(r.Uid) or 0
end

R:on("G_ArenaLogic.ArenaFightRanking", function (ctx, argData)
	local base = baseInfo()
	local fd, uidRobot = dungFightDataRobot(base)
	if fd == nil then
		OfflineLog:err("dau truong tran: KHONG dung duoc FightData robot")
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", 2306, {})
		return
	end
	local heroList = (type(argData) == "table" and type(argData.HeroList) == "table")
		and argData.HeroList or {}
	local goi = {
		FightData = fd,
		FightHeroList = heroList,          -- TƯỚNG CỦA MÌNH (xem đầu tệp)
		BattleRandom = math.random(1, 99999),
	}
	OfflineLog:info(string.format("dau truong tran: vao tran voi robot %s, %d tuong cua minh",
		tostring(uidRobot), #heroList))
	ctx:call("G_ArenaLogic", "OnArenaFightRanking", goi)
end)

R:on("G_ArenaLogic.CompeleteArenaFight", function (ctx, resultData)
	local thang = type(resultData) == "table" and resultData.bResult == true
	local c = cfg("GameArenaConfig") or {}
	local honourThem = tonumber(thang and c.WinHonour or c.LoseHonour) or 0

	local u = arena()
	local hangCu = tonumber(u and u.Ranking) or 1000
	pcall(function () G_ArenaDataManager:AddUserArenaHonnor(honourThem, "ArenaFight") end)
	local hangMoi = hangCu
	if thang then
		hangMoi = math.max(1, hangCu - 1)
		pcall(function () G_ArenaDataManager:SetArenaRanking(hangMoi) end)
	end

	-- Chiến báo (giữ 20 dòng mới nhất, mới nhất đứng đầu) — cùng hình dạng UI đọc.
	local honour = honourThem
	pcall(function ()
		local _, hon = G_ArenaDataManager:GetUserArenaHonnor()
		if hon ~= nil then honour = tonumber(hon) or honour end
	end)
	pcall(function ()
		local uu = arena()
		if type(uu) == "table" then
			uu.FightRecords = uu.FightRecords or {}
			table.insert(uu.FightRecords, 1, {
				IsTarget = true, Result = thang,
				TargetName = "Robot", TargetLevel = 1,
				TargetFightingCapacity = 0, TargetPortrait = "", TargetGender = true,
			})
			while #uu.FightRecords > 20 do table.remove(uu.FightRecords) end
			G_ArenaDataManager:SetUserArena(uu)
		end
	end)
	pcall(function () OfflineStore:syncFromClient() end)

	OfflineLog:info(string.format("dau truong tran: %s — hang %s -> %s, danh vong %+d",
		thang and "THANG" or "THUA", tostring(hangCu), tostring(hangMoi), honourThem))
	ctx:call("G_ArenaLogic", "OnCompeleteArenaFight", {
		bResult = thang, Ranking = hangMoi, UserHonnor = honour,
	})
end)

R:on("G_ArenaLogic.GetUserArenaFightRecord", function (ctx)
	local u = arena()
	local ds = (type(u) == "table" and type(u.FightRecords) == "table") and u.FightRecords or {}
	ctx:call("G_ArenaLogic", "OnGetUserArenaFightRecord", ds)
end)

OfflineLog:info("dau truong tran: da noi 3 khoa (ArenaFightRanking / CompeleteArenaFight / GetUserArenaFightRecord)")

return true
