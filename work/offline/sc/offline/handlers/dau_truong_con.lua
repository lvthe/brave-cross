--[[
	offline/handlers/dau_truong_con.lua — ĐẤU TRƯỜNG: 4 KHOÁ CÒN LẠI.

	`dau_truong.lua` (30/10) đã làm phần DỮ LIỆU MÀN HÌNH và từng đăng ký bốn khoá này
	bằng `khongCo(...)` (trả 2306). Nay làm thật:

	  · `ClientRefreshArenaGoodsWithHonor` — làm mới CỬA HÀNG bằng DANH VỌNG. Luật GỐC:
	      giá theo `ArenaLogic:GetRefreshHonour()` (10 / 50 / 100 / 100+(n−2)×50 theo
	      `RefreshGoodsCount`), trừ bằng `ArenaDataManager:AddUserArenaHonnor`; hàng sinh
	      bằng chính hai bảng `GameArenaGoodsCrateConfig` + `GameArenaGoodsConfig`
	      (cùng bộ sinh với `ClientRefreshUserArenaGoods`). Thiếu danh vọng ⇒ **2319
	      NoEnoughHonor**.
	  · `ClientGetArenaHeroInfo(ranking, heroId)` — thông tin một tướng trên bảng hạng.
	      Offline chỉ có tướng CỦA MÌNH ⇒ trả đúng hình `{HeroData, EquipsData,
	      GameMagicWeapon, SkillList}` từ các bảng người chơi THẬT; tướng không có ⇒ 2306.
	  · `ClientCheckArenaRecord` — client KHÔNG chờ và KHÔNG có hàm nhận (chỉ server đánh
	      dấu "đã xem") ⇒ nuốt lặng.
	  · `GetArenaDetailByUid(Uid, robotId)` — đây là TÊN CŨ của
	      `ClientGetArenaDetailByUid` (đã làm thật ở `dau_truong_chi_tiet.lua` từ 30/10
	      cho đường ARENA_SERVER) ⇒ chuyển tiếp nguyên tham số.
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflineDauTruongCon = OfflineDauTruongCon or {}

local R = OfflineRouter
local TEN_FILE = "dau truong (con)"

local function cfg(ten)
	local ok, v = pcall(function () return G_ConfigManager:GetCommonConfigWithName(ten) end)
	if ok and type(v) == "table" then return v end
	return nil
end

local function goi(ctx, hamNhan, ...)
	local a = { n = select("#", ...), ... }
	local ok, e = pcall(function ()
		return ctx:call("G_ArenaLogic", hamNhan, unpack(a, 1, a.n))
	end)
	if not ok then
		OfflineLog:err(string.format("%s: khong goi duoc G_ArenaLogic.%s -> %s",
			TEN_FILE, tostring(hamNhan), tostring(e)))
	end
end

local function donLop(ctx, nMa)
	pcall(function ()
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", nMa or 0, {})
	end)
end

local function maArena(ten, macDinh)
	local ok, v = pcall(function ()
		local E = _G.ErrorCode
		return E and E.Arenal and E.Arenal[ten]
	end)
	return (ok and tonumber(v)) or macDinh
end

local function dongBo()
	pcall(function () OfflineStore:syncFromClient() end)
end

local function userArena()
	local ok, b, u = pcall(function () return G_ArenaDataManager:GetUserArena() end)
	if ok and b ~= false and type(u) == "table" then return u end
	return nil
end

-- Cùng bộ sinh với `dau_truong.lua` (30/10): 15 nhóm `{Range, GoodsList}` + 27 món.
local function sinhHang()
	local crate = cfg("GameArenaGoodsCrateConfig")
	local goods = cfg("GameArenaGoodsConfig")
	if type(crate) ~= "table" or type(goods) ~= "table" then return nil end
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

------------------------------------------------------------------- 1. LÀM MỚI BẰNG DANH VỌNG
R:on("G_ArenaLogic.ClientRefreshArenaGoodsWithHonor", function (ctx)
	local u = userArena()
	if u == nil then
		return donLop(ctx, maArena("GetUserArenaDataFaild", 2306))
	end

	local okCost, bCost, cost = pcall(function () return G_ArenaLogic:GetRefreshHonour() end)
	if not okCost or bCost ~= true or tonumber(cost) == nil then
		OfflineLog:warn(TEN_FILE .. ": khong doc duoc gia lam moi")
		return donLop(ctx, maArena("GetRefreshGoodsCostFaild", 2320))
	end
	cost = tonumber(cost)

	local okHonor, bHonor, honor = pcall(function () return G_ArenaDataManager:GetUserArenaHonnor() end)
	if not okHonor or bHonor ~= true or tonumber(honor) == nil then
		OfflineLog:warn(TEN_FILE .. ": khong doc duoc danh vong")
		return donLop(ctx, maArena("GetUserArenaDataFaild", 2306))
	end
	if tonumber(honor) < cost then
		OfflineLog:info(string.format("%s: thieu danh vong (%s < %d)", TEN_FILE,
			tostring(honor), cost))
		return donLop(ctx, maArena("NoEnoughHonor", 2319))
	end

	local ds = sinhHang()
	if ds == nil or #ds == 0 then
		return donLop(ctx, maArena("GetRandomGoodsListFaild", 2311))
	end

	local okTru, daTru = pcall(function ()
		return G_ArenaDataManager:AddUserArenaHonnor(-cost, "RefreshGoodsWithHonor")
	end)
	if not okTru or daTru ~= true then
		return donLop(ctx, maArena("NoEnoughHonor", 2319))
	end

	pcall(function () G_ArenaDataManager:SetUserArenaGoodsList(ds) end)
	pcall(function ()
		G_ArenaDataManager:SetLastRefreshGoodsListTime(G_GameWorld:GetServerTime())
	end)
	pcall(function ()
		local so = tonumber(u.RefreshGoodsCount) or 0
		G_ArenaDataManager:SetRefreshGoodsCount(so + 1)
	end)
	dongBo()
	OfflineLog:info(string.format("%s: lam moi cua hang -%d danh vong, %d mon", TEN_FILE,
		cost, #ds))
	goi(ctx, "OnRefreshArenaGoodsWithHonor", ds)
	donLop(ctx)
end)

------------------------------------------------------------------- 2. TƯỚNG TRÊN BẢNG HẠNG
--[[ Offline chỉ có tướng CỦA MÌNH: trả đúng hình `CUIArenalLeaderboard:OnGetArenaHeroInfo`
	đọc (`HeroData`, `EquipsData`, `GameMagicWeapon`, `SkillList`). ]]
R:on("G_ArenaLogic.ClientGetArenaHeroInfo", function (ctx, ranking, heroId)
	local id = tonumber(heroId)
	local okH, bH, tHero = pcall(function () return G_HeroLogic:GetHeroWithID(id or 0) end)
	if not okH or bH == false or type(tHero) ~= "table" then
		OfflineLog:info(TEN_FILE .. ": khong co tuong " .. tostring(heroId))
		return donLop(ctx, maArena("GetUserArenaDataFaild", 2306))
	end

	local function bang(ten, khoa)
		local ok, maLoi, t = pcall(function () return G_DataManager:GetUserDataWithName(ten) end)
		if not ok or maLoi ~= 0 or type(t) ~= "table" then return {} end
		if khoa == nil then return t end
		return type(t[khoa]) == "table" and t[khoa] or {}
	end

	local magic = nil
	pcall(function ()
		local okM, bM, m = pcall(function () return G_MagicWeaponLogic:GetMagicWeaponData() end)
		if okM and bM ~= false and type(m) == "table" then magic = m end
	end)

	local d = {
		HeroData = tHero,
		EquipsData = bang("GameUserEquipment", tostring(id)),
		GameMagicWeapon = magic or {},
		SkillList = bang("GameUserSkill", tostring(id)),
		BaseInfo = bang("GameUserBaseInfo"),
	}
	OfflineLog:info(string.format("%s: thong tin tuong %s cho hang %s", TEN_FILE,
		tostring(heroId), tostring(ranking)))
	goi(ctx, "OnGetArenaHeroInfo", d)
	donLop(ctx)
end)

------------------------------------------------------------------- 3. ĐÁNH DẤU ĐÃ XEM CHIẾN BÁO
R:on("G_ArenaLogic.ClientCheckArenaRecord", function (ctx)
	OfflineLog:info(TEN_FILE .. ": danh dau da xem chien bao (khong co phan hoi)")
end)

------------------------------------------------------------------- 4. TÊN CŨ CỦA CHI TIẾT ĐỐI THỦ
R:on("G_ArenaLogic.GetArenaDetailByUid", function (ctx, nUid, nRobotId)
	local h = R:getFor("G_ArenaLogic", "ClientGetArenaDetailByUid")
	if h == nil then
		return donLop(ctx, maArena("GetUserArenaDataFaild", 2306))
	end
	return h(ctx, nUid, nRobotId)
end)

OfflineLog:info("dau truong (con): da noi 4 khoa (lam moi bang danh vong/tuong bang hang/xem chien bao/chi tiet doi thu)")

return true
