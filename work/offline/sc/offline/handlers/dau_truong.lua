--[[
	offline/handlers/dau_truong.lua — ĐẤU TRƯỜNG (竞技场): phần DỮ LIỆU MÀN HÌNH.

	Trước bản này panel Lôi Đài mở ra là báo lỗi 2306
	(`ErrorHandler.GetUserArenaDataFaild`) vì không ai trả `GetUserArenal`.

	Nay làm được 4 việc, tất cả từ DỮ LIỆU CÓ SẴN:
	  * `GetUserArenal` — hạng của mình (`GameUserArenaRank` đã có sẵn trong file
	    lưu; chưa có thì đặt mặc định 1000, ghi rõ là ĐẶT);
	  * `GetSearchList` — danh sách đối thủ dựng từ **`GameArenaRobotConfig`**
	    (1 robot: `Uid 3578`, `FightData.Data` = chỉ số tướng, `Groups` = đội hình);
	  * `ClientRefreshUserArenaGoods` — sinh cửa hàng danh vọng từ
	    `GameArenaGoodsCrateConfig` (15 nhóm `{Range, GoodsList}`) +
	    `GameArenaGoodsConfig` (27 món `{PrizeID, cost}`);
	  * `ClientAddArenaFightCount` — gọi luật gốc `ArenaLogic:AddFightCount`.

	⚠ KHÔNG làm trận: `ArenaFightRanking` đòi máy chủ trả `FightData` đầy đủ
	(`BaseInfo`, `Groups[*].Soldiers`) + `FightHeroList` + `BattleRandom` cho màn
	bố trí (`CUIBattleDeploy:OnArenaFightLocalArmy`). Cấu hình chỉ có **MỘT** robot
	mẫu, không có tên/hạng/lực chiến; dựng trận từ nó là bịa dữ liệu trận — nên
	giữ nguyên mã 2306 và ghi log. Muốn có trận thì phải có bảng robot đầy đủ.
]]

require("offline.log")
require("offline.store")
require("offline.router")

local R = OfflineRouter

local HANG_MAC_DINH = 1000       -- ĐẶT: chưa có hạng thì lấy mốc này

local function cfg(ten)
	local ok, v = pcall(function () return G_ConfigManager:GetCommonConfigWithName(ten) end)
	if ok and type(v) == "table" then return v end
	return nil
end

local function userArena()
	local ok, u = pcall(function ()
		local _, x = G_ArenaDataManager:GetUserArena()
		return x
	end)
	if ok then return u end
	return nil
end

local function hangCuaMinh()
	local u = userArena()
	local r = u and tonumber(u.Ranking)
	if r == nil or r <= 0 then
		r = HANG_MAC_DINH
		pcall(function () G_ArenaDataManager:SetArenaRanking(r) end)
	end
	return r
end

--------------------------------------------------------------- hạng + đối thủ

R:on("G_ArenaLogic.GetUserArenal", function(ctx)
	local hang = hangCuaMinh()
	OfflineLog:info("dau truong: hang hien tai " .. tostring(hang))
	ctx:call("G_ArenaLogic", "OnGetUserArenal", tostring(hang))
end)

--[[ Danh sách đối thủ = robot trong `GameArenaRobotConfig`. Chỉ có 1 robot mẫu,
	nên danh sách 1 mục. Trường mà UI đọc (`CUIArenaMain:RefleshFightList`,
	`:379-392`): `RankID`, `BaseInfo.CharacterName/UserFightCapacity/Portrait/
	Gender/HeroID`, `HeorList`. Tên và lực chiến robot KHÔNG có trong cấu hình ⇒
	ĐẶT: tên "Robot <uid>", lực chiến = lực chiến của chính người chơi (để sắp
	xếp không vô lý), `HeorList` lấy từ `Groups[*].Soldiers[*].Data`. ]]
R:on("G_ArenaLogic.GetSearchList", function(ctx)
	local robots = cfg("GameArenaRobotConfig")
	local hang = hangCuaMinh()
	local ds = {}

	local lc = 0
	pcall(function ()
		local _, b = G_UserLogic:GetBaseInfo()
		lc = tonumber(b and b.UserFightCapacity) or 0
	end)

	for _, r in pairs(robots or {}) do
		if type(r) == "table" then
			local heroList, heroID = {}, nil
			local fd = r.FightData or {}
			local groups = fd.Groups or fd["Groups "] or {}
			for _, g in ipairs(groups) do
				for _, s in ipairs(g.Soldiers or {}) do
					local id = tonumber(s.Data) or tonumber(s.NpcID)
					if id then
						heroList[#heroList + 1] = id
						heroID = heroID or id
					end
				end
			end
			ds[#ds + 1] = {
				Uid = tonumber(r.Uid) or 0,
				RankID = math.max(1, hang - 1),
				BaseInfo = {
					CharacterName = "Robot " .. tostring(r.Uid),
					UserFightCapacity = lc,
					Portrait = "",
					Gender = true,
					HeroID = heroID or 25,
				},
				HeorList = heroList,
			}
		end
	end

	OfflineLog:info(string.format("dau truong: danh sach dau %d doi thu", #ds))
	ctx:call("G_ArenaLogic", "OnGetSearchList", ds)
end)

----------------------------------------------------------------- cửa hàng

local function sinhHangDanhVong()
	local crate = cfg("GameArenaGoodsCrateConfig")
	local goods = cfg("GameArenaGoodsConfig")
	if type(crate) ~= "table" or type(goods) ~= "table" then
		return nil
	end
	local ds, daCo = {}, {}
	for _, nhom in ipairs(crate) do
		local canBoc = tonumber(nhom.Range) or 1
		local nguon = nhom.GoodsList
		if type(nguon) == "table" then
			local con = {}
			for i = 1, #nguon do con[i] = nguon[i] end
			for i = #con, 2, -1 do
				local j = math.random(i)
				con[i], con[j] = con[j], con[i]
			end
			local daLay = 0
			for _, id in ipairs(con) do
				if daLay >= canBoc then break end
				if not daCo[id] then
					local g = goods[tostring(id)]
					if type(g) == "table" then
						ds[#ds + 1] = { ID = tonumber(id), State = 0, Cost = tonumber(g.cost) }
						daCo[id] = true
						daLay = daLay + 1
					end
				end
			end
		end
	end
	return ds
end

R:on("G_ArenaLogic.ClientRefreshUserArenaGoods", function(ctx)
	local ds = sinhHangDanhVong()
	local nErr = 0
	if ds ~= nil and #ds > 0 then
		pcall(function () G_ArenaDataManager:SetUserArenaGoodsList(ds) end)
		OfflineLog:info(string.format("dau truong: lam moi cua hang %d mon", #ds))
	else
		nErr = 1
	end
	pcall(function () OfflineStore:syncFromClient() end)
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", nErr, {})
end)

--[[ Mua thêm lượt đánh: luật gốc `ArenaLogic:AddFightCount` (trừ kim cương theo
	`GetAddFightCountCost`). Chỉ gọi, không chép luật. ]]
R:on("G_ArenaLogic.ClientAddArenaFightCount", function(ctx)
	local o = G_ArenaLogic
	local c = rawget(_G, "ArenaLogic")
	local self = (type(c) == "table" and o[c]) or o
	local ok, bRet, ma = pcall(function () return self:AddFightCount(self) end)
	if ok and bRet == true then
		pcall(function () OfflineStore:syncFromClient() end)
		-- Người nhận thật: `ClientArenaLogic:OnAddArenaFightCount()` — nó phát
		-- `Arenal.OnAddArenaFightCount` để UI vẽ lại số lượt.
		ctx:call("G_ArenaLogic", "OnAddArenaFightCount")
	else
		OfflineLog:info("dau truong: mua luot bi tu choi, ma " .. tostring(ma))
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", tonumber(ma) or 1, {})
	end
end)

--[[ Các nút KHÁC trong panel (Chiến · BXH · Quả Lôi · Chiến báo · Đổi quà) đều
	gửi lệnh rồi bật lớp "đang tải". Phần dữ liệu của chúng KHÔNG dựng lại được
	(xếp hạng thế giới/chiến báo/replay là của máy chủ nhiều người chơi; trận thì
	cần `FightData` đầy đủ — xem đầu tệp). Nên trả mã lỗi NGAY để tắt lớp tải,
	thay vì để màn hình treo: đó là đường phản hồi chung
	`CUIRPCManager:OnReciveResponse`. ]]
local function khongCo(ctx, ten)
	OfflineLog:warn("dau truong: " .. ten .. " chua co du lieu (may chu nhieu nguoi choi) -> 2306")
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "",
		ErrorCode.Arenal.GetUserArenaDataFaild, {})
end

for _, ten in ipairs({
	"ArenaFightRanking", "ArenaFightTest", "CompeleteArenaFight", "CompeleteArenaFightTest",
	"GetArenaRankWithYesterday", "GetWorldArenalRanking", "GetUserArenaFightRecord",
	"GetUserArenaFightReplay", "GetUserArenaFightReplayNew", "GetArenaRankingWithRange",
}) do
	-- KHÔNG đưa `RefreshFightTime` / `AddArenaFightCount` vào đây: hai lệnh ấy đã
	-- chạy được bằng luật gốc (`handlers/tinh_nang.lua`) — đăng ký đè là mất đường.
	R:on("G_ArenaLogic." .. ten, function(ctx) khongCo(ctx, ten) end)
end

-- Bốn khoá `ClientCheckArenaRecord` / `ClientGetArenaHeroInfo` /
-- `ClientRefreshArenaGoodsWithHonor` / `GetArenaDetailByUid` KHÔNG đăng ký ở đây nữa:
-- ba khoá đầu đã làm THẬT ở `handlers/dau_truong_con.lua` (2/11), hai khoá còn lại
-- (`ClientGetUserArenaFightData`, `ClientGetArenaDetailByUid`) ở
-- `handlers/dau_truong_chi_tiet.lua` từ 30/10. Đăng ký đè ở đây chỉ sinh cảnh báo.

return true
