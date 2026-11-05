--[[
	offline/handlers/apr.lua — ĐẤU TRƯỜNG ĐIỂM (积分竞技场 / APR).

	12 khoá `G_ScoreCompetitivePlayProtocol` + ghi đè `ClientGetOpenInfoReq` (bản cũ
	trong `handlers/he_thong.lua` trả "ĐÓNG" để panel không mở). Thực thể client là
	**`g_APRProtocol`** (`APRProtocol.lua:13-15`) — GỬI bằng `G_ScoreCompetitivePlayProtocol`
	nhưng NHẬN bằng `g_APRProtocol` (cùng bẫy chữ hoa/thường với COG).

	VÌ SAO MỞ ĐƯỢC MÀ KHÔNG BỊA: máy chủ gốc sinh **1000 ROBOT** từ cấu hình THẬT và
	luật sinh robot còn nguyên trong `share/ScoreCompetitivePlay/share_ScoreCompetitivePlayLogic.lua`
	(`GetRobotInfo`, `Score2Rank`, `GenDefence`, …). Cấu hình:
	  · `KDBScoreCompetitiveRuleConf` — StartScore 1000, mùa ngày 1 05:00 → ngày 25 22:00.
	  · `KDBScoreCompetitiveRankConf` — 19 bậc: `MinScore`, `win_add_score`,
	    `lose_recover_score`, `recover_diamond`, `rank_reward`, `season_reward`.
	  · `KDBScoreCompetitiveRobot` (1000 dòng `{name, gender, fight_capacity, team}`)
	    + `KDBScoreCompetitiveRobotConf` (chỉ số hero/trang bị của robot).
	⇒ Toàn bộ DỮ LIỆU (danh sách đối thủ, xem đối thủ, BXH, thưởng thăng bậc, phục hồi
	điểm, chỉnh đội phòng thủ) là THẬT.

	⚠ HAI CHỖ PHẢI VÁ ĐỂ DÙNG ĐƯỢC MÃ MÁY CHỦ GỐC:
	1. `G_ConfigManager:GetScoreCompetitiveRobot` và cache `ScoreCompetitiveRobotConf`
	   **KHÔNG được đăng ký** trong bản client (chỉ máy chủ có) ⇒ `GetRobotInfo` sẽ nổ.
	   Ta đăng ký tại chỗ bằng `GetConfigTableWithName` (hàm này đọc thẳng tệp `.xgg`
	   theo tên, không cần đăng ký trước) — xem `damBaoCauHinhRobot`.
	2. `APRData` đọc trạng thái trong bảng `GameScoreCompetitivePlay` (`score`,
	   `max_score`, `challenge`, `defence`, `rank_reward`, `season_id`…). Đây là bảng
	   MÁY CHỦ ghi; offline phải tự duy trì.

	⚠ KHÔNG LÀM ĐƯỢC — BỐN KHOÁ TRẬN ĐẤU: `BeginFight`/`EndFight`/`RevengeBegin`/
	`RevengeEnd`. Máy chủ gốc MÔ PHỎNG 3 trận rồi gửi `WinIndex`/`Rand`/`Result` để
	client phát lại; bản client KHÔNG có bộ mô phỏng nào (grep `share/` 0 hàm), nên
	không thể sinh kết quả trận mà không BỊA. Bốn khoá ấy trả mã gốc **5500
	`ScoreCompetitive.Closed`** qua đúng hàm nhận (nó có nhánh `ProcessNotTable` ⇒
	dừng lớp tải, không vào trận), kèm toast để người chơi biết lý do.

	MÃ GỐC KHÁC (`share/error.lua:814`): 5501 đã đánh · 5502 đã nhận thưởng ·
	5503 chưa đủ điều kiện · 5504 hết lượt trả thù · 5505 không đúng mùa.
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflineAPR = OfflineAPR or {}

local R = OfflineRouter
local TEN_FILE = "dau truong diem"
local KHOA_BANG = "GameScoreCompetitivePlay"

------------------------------------------------------------------- tiện ích

local function ma(ten, macDinh)
	local ok, v = pcall(function ()
		local E = _G.ErrorCode
		return E and E.ScoreCompetitive and E.ScoreCompetitive[ten]
	end)
	return (ok and tonumber(v)) or macDinh
end

local function goi(ctx, hamNhan, ...)
	local a = { n = select("#", ...), ... }
	local ok, e = pcall(function ()
		return ctx:call("g_APRProtocol", hamNhan, unpack(a, 1, a.n))
	end)
	if not ok then
		OfflineLog:err(string.format("%s: khong goi duoc g_APRProtocol.%s -> %s",
			TEN_FILE, tostring(hamNhan), tostring(e)))
	end
end

--[[ Khoá KHÔNG có kênh mã lỗi (mọi `Rsp` của APR chỉ nhận dữ liệu): báo lỗi bằng
	đường chung `OnReciveResponse` (dừng lớp tải + toast). ]]
local function baoLoi(ctx, nMa, lyDo)
	OfflineLog:info(string.format("%s: tu choi -> ma %d (%s)", TEN_FILE, nMa, lyDo or ""))
	pcall(function ()
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", nMa, {})
	end)
end

local function thongBao(nMa)
	if nMa == nil or nMa == 0 then return end
	pcall(function ()
		g_CUINotificationCenter:PostNotification(
			CUINotificationEvent.OnServerRequestError, nMa)
	end)
end

local function dongBo()
	pcall(function () OfflineStore:syncFromClient() end)
end

local function uid()
	local ok, v = pcall(function () return OfflineBangHoi:uid() end)
	return (ok and tonumber(v)) or 1
end

local function layBangDuLieu(ten)
	local ok, maLoi, t = pcall(function ()
		return G_DataManager:GetUserDataWithName(ten)
	end)
	if ok and maLoi == 0 and type(t) == "table" then return t end
	return nil
end

local function share()
	return _G.G_ShareScoreCompetitiveLogic
end

local function cauHinhRule()
	local ok, cfg = pcall(function ()
		return G_ConfigManager:GetConfigWithNameArg(G_ConfigManager.configCacheName.ScoreCompetitiveRuleConf)
	end)
	if ok and type(cfg) == "table" then return cfg end
	return nil
end

local function cauHinhRank(cap)
	local ok, cfg = pcall(function ()
		return G_ConfigManager:GetScoreCompetitiveRankConf(tonumber(cap) or 0)
	end)
	if ok and type(cfg) == "table" then return cfg end
	return nil
end

--=============================================================== VÁ CẤU HÌNH ROBOT
--[[ Bản client KHÔNG đăng ký `KDBScoreCompetitiveRobot` / `KDBScoreCompetitiveRobotConf`
	(chỉ máy chủ dùng) — `GetConfigTableWithName` đọc thẳng `config/share/<tên>.xgg`
	nên đăng ký được tại chỗ. Gọi LƯỢT ĐẦU, không gọi lúc nạp tệp (config manager chưa
	chắc đã Init xong). ]]
local DA_VA = false
local function damBaoCauHinhRobot()
	if DA_VA or type(_G.G_ConfigManager) ~= "table" then return end
	DA_VA = true
	local C = G_ConfigManager
	if type(C.GetScoreCompetitiveRobot) ~= "function" then
		local ok, rows = pcall(function () return C:GetConfigTableWithName("KDBScoreCompetitiveRobot") end)
		C.ScoreCompetitiveRobot = (ok and type(rows) == "table") and rows or {}
		C.GetScoreCompetitiveRobot = function (self, nId)
			return self.ScoreCompetitiveRobot[tonumber(nId) or 0]
		end
	end
	if C.ScoreCompetitiveRobotConf == nil then
		local ok, rows = pcall(function () return C:GetConfigTableWithName("KDBScoreCompetitiveRobotConf") end)
		local row = (ok and type(rows) == "table") and rows[1] or nil
		C.ScoreCompetitiveRobotConf = row
		C.configCacheName.ScoreCompetitiveRobotConf = "ScoreCompetitiveRobotConf"
	end
	OfflineLog:info(string.format("%s: da dang ky cau hinh robot (%d robot, RobotConf=%s)",
		TEN_FILE, #(C.ScoreCompetitiveRobot or {}), tostring(C.ScoreCompetitiveRobotConf ~= nil)))
end

------------------------------------------------------------------- dữ liệu mùa
local function startScore()
	local cfg = cauHinhRule()
	return tonumber(cfg and cfg.StartScore) or 1000
end

local function mocMua(ngay, gio, phut)
	local t = os.date("*t")
	return os.time({ year = t.year, month = t.month, day = ngay, hour = gio, min = phut or 0, sec = 0 })
end

local function mocBatDau(cfg)
	return mocMua(tonumber(cfg.Start_mday) or 1, tonumber(cfg.Start_hour) or 5, tonumber(cfg.Start_min) or 0)
end

local function mocKetThuc(cfg)
	return mocMua(tonumber(cfg.End_mday) or 25, tonumber(cfg.End_hour) or 22, tonumber(cfg.End_min) or 0)
end

-- Các bậc có thưởng thăng bậc trong cấu hình (1/4/7/10/13/16/18 …).
local function cacBacCoThuong()
	local ds = {}
	for cap = 1, 19 do
		local cfg = cauHinhRank(cap)
		if cfg ~= nil and type(cfg.rank_reward) == "table" and #cfg.rank_reward > 0 then
			ds[#ds + 1] = cap
		end
	end
	return ds
end

--[[ Trạng thái mùa. Trả (state, giây còn lại, mốc kết thúc) theo `APRData.OPEN_STATE`:
	6 = chờ mở, 3 = đang mở, 4 = đã kết thúc. ]]
local function trangThaiMua()
	local cfg = cauHinhRule()
	if cfg == nil then return 0, 0, 0 end
	local now = os.time()
	local batDau = mocBatDau(cfg)
	local ketThuc = mocKetThuc(cfg)
	if now < batDau then
		return 6, batDau - now, ketThuc
	elseif now <= ketThuc then
		return 3, ketThuc - now, ketThuc
	end
	local t = os.date("*t")
	local thang = t.month + 1
	local nam = t.year
	if thang > 12 then thang, nam = 1, nam + 1 end
	local sau = os.time({ year = nam, month = thang, day = tonumber(cfg.Start_mday) or 1,
		hour = tonumber(cfg.Start_hour) or 5, min = tonumber(cfg.Start_min) or 0, sec = 0 })
	return 4, sau - now, ketThuc
end

local function tongLucChien()
	local ok, bRet, n = pcall(function () return G_RankLogic:GetSelf5HeroPower() end)
	if ok and bRet ~= false and tonumber(n) then return tonumber(n) end
	return 0
end

local function duLieu()
	local t = layBangDuLieu(KHOA_BANG)
	if t == nil then
		t = {}
		pcall(function () G_DataManager:SetUserDataWithName(KHOA_BANG, t) end)
	end

	damBaoCauHinhRobot()

	local sid = ""
	pcall(function () sid = tostring(share():GetCurMatchId()) end)
	if sid ~= "" and tostring(t.season_id) ~= sid then
		t.season_id = sid
		t.score = startScore()
		t.max_score = t.score
		t.challenge = {}
		t.daily_revenge_count = 0
		t.rank_reward = {}
		for _, cap in ipairs(cacBacCoThuong()) do t.rank_reward[cap] = 0 end
	end
	if tonumber(t.score) == nil then t.score = startScore() end
	if tonumber(t.max_score) == nil then t.max_score = t.score end
	if type(t.challenge) ~= "table" then t.challenge = {} end
	if type(t.defence) ~= "table" then t.defence = {} end
	if type(t.rank_reward) ~= "table" then t.rank_reward = {} end
	if tonumber(t.daily_revenge_count) == nil then t.daily_revenge_count = 0 end
	t.total_fight_capacity = tongLucChien()
	return t
end

------------------------------------------------------------------- robot / xếp hạng
local function dongRobot(i)
	local C = G_ConfigManager
	local rows = C and C.ScoreCompetitiveRobot
	local r = type(rows) == "table" and rows[i] or nil
	if type(r) ~= "table" then return nil end
	return r
end

local function soRobot()
	local C = G_ConfigManager
	return type(C and C.ScoreCompetitiveRobot) == "table" and #C.ScoreCompetitiveRobot or 0
end

local function strIdRobot(i)
	return share():NumId2StrId(0, i)
end

local function strIdMinh()
	return share():NumId2StrId(1, uid())
end

local function capCuaMinh()
	local ok, b, cap, myRank = pcall(function ()
		local d = duLieu()
		return true, share():Score2Rank(d.score)
	end)
	if ok and tonumber(cap) then return tonumber(cap) end
	return 19
end

--[[ Dòng công khai của một robot (đủ trường `APRData` đọc để vẽ BXH / danh sách
	đối thủ): CharacterName, Portrait, Level, HeroID, Gender, ScoreCompetitiveFightCap. ]]
local function dongCongKhai(i, r)
	local conf = G_ConfigManager.ScoreCompetitiveRobotConf
	local level = (type(conf) == "table" and type(conf.HeroInfo) == "table" and conf.HeroInfo.HeroLevel) or 70
	local laNam = (tonumber(r.gender) or 0) % 2 == 0
	return {
		CharacterName = r.name,
		Level = level,
		HeroID = 99999,
		Gender = laNam,
		Portrait = laNam and "player000M" or "player000W",
		ScoreCompetitiveFightCap = tonumber(r.fight_capacity) or 0,
		ScoreCompetitiveLastRank = 19,
		LoginChannel = "",
	}
end

--[[ Bảng xếp hạng gộp: robot (theo lực chiến) + mình (theo điểm). Trả danh sách
	{{strId, score, power}, …} đã sắp, và vị trí của mình. ]]
local function bangXepHang()
	local d = duLieu()
	local n = soRobot()
	local ds = {}
	for i = 1, n do
		local r = dongRobot(i)
		if type(r) == "table" then
			ds[#ds + 1] = { id = strIdRobot(i), score = startScore(),
				power = tonumber(r.fight_capacity) or 0, robot = i }
		end
	end
	local sid = strIdMinh()
	ds[#ds + 1] = { id = sid, score = tonumber(d.score) or 0,
		power = tonumber(d.total_fight_capacity) or 0, laMinh = true }
	table.sort(ds, function (a, b)
		if a.score ~= b.score then return a.score > b.score end
		return a.power > b.power
	end)
	local viTri = #ds
	for i, v in ipairs(ds) do
		v.rank = i
		if v.laMinh then viTri = i end
	end
	return ds, viTri
end

local function thongTinCuaMinh()
	local d = duLieu()
	local b = {}
	pcall(function ()
		local ok, r, base = pcall(function () return G_UserLogic:GetBaseInfo() end)
		local t = (ok and type(base) == "table") and base or ((ok and type(r) == "table") and r or {})
		b.CharacterName = t.CharacterName or "Offline"
		b.Level = tonumber(t.Level) or 1
		b.Portrait = t.Portrait or "player000M"
		b.Gender = t.Gender
	end)
	return {
		CharacterName = b.CharacterName or "Offline",
		Level = b.Level or 1,
		HeroID = 99999,
		Gender = b.Gender,
		Portrait = b.Portrait or "player000M",
		ScoreCompetitiveFightCap = tonumber(d.total_fight_capacity) or 0,
		ScoreCompetitiveLastRank = 19,
		LoginChannel = "",
	}
end

------------------------------------------------------------------- 1. TRẠNG THÁI MỞ
--[[ Ghi đè bản "ĐÓNG" cũ trong `he_thong.lua`. Điều kiện = `ShareScoreCompetitiveLogic:IsSysOpen`
	(≥70 cấp, ≥3 tướng — hai hằng số có thật trong mã máy chủ gốc). ]]
R:on("G_ScoreCompetitivePlayProtocol.ClientGetOpenInfoReq", function (ctx)
	damBaoCauHinhRobot()
	local state, con, het = 0, 0, 0

	local duCap, duTuong = false, false
	pcall(function ()
		local ok, r, base = pcall(function () return G_UserLogic:GetBaseInfo() end)
		local t = (ok and type(base) == "table") and base or ((ok and type(r) == "table") and r or {})
		duCap = (tonumber(t.Level) or 0) >= 70
	end)
	pcall(function ()
		local _, ds = G_DataManager:GetUserDataWithName("GameUserHero")
		local dem = 0
		for _ in pairs(ds or {}) do dem = dem + 1 end
		duTuong = dem >= 3
	end)

	if not duCap then
		state = 5     -- NOT_ENOUGH_70_LEVEL
	else
		state, con, het = trangThaiMua()
	end
	OfflineLog:info(string.format("%s: trang thai mo -> %d (cap=%s tuong=%s)", TEN_FILE,
		state, tostring(duCap), tostring(duTuong)))
	goi(ctx, "ClientGetOpenInfoRsp", state, con, het)
end)

------------------------------------------------------------------- 2. THÔNG TIN CHÍNH
R:on("G_ScoreCompetitivePlayProtocol.ClientBeginPlayReq", function (ctx)
	local d = duLieu()
	local cfg = cauHinhRule()
	local ds, viTri = bangXepHang()
	local sid = strIdMinh()

	-- 6 đối thủ gần lực chiến nhất (config RobotCount = 1000; quét tuyến tính).
	local luc = tonumber(d.total_fight_capacity) or 0
	local ung = {}
	for i = 1, soRobot() do
		local r = dongRobot(i)
		if type(r) == "table" then
			ung[#ung + 1] = { i = i, cach = math.abs((tonumber(r.fight_capacity) or 0) - luc) }
		end
	end
	table.sort(ung, function (a, b) return a.cach < b.cach end)
	local challenge = {}
	local tAll = {}
	for k = 1, math.min(6, #ung) do
		local i = ung[k].i
		local r = dongRobot(i)
		local sidR = strIdRobot(i)
		challenge[#challenge + 1] = { Id = sidR, Score = startScore(), state = 0 }
		tAll[sidR] = dongCongKhai(i, r)
	end
	d.challenge = challenge
	tAll[sid] = thongTinCuaMinh()

	-- BXH chính: lấy 20 dòng đầu của bảng gộp (luôn có dòng của mình).
	local rankList = {}
	for k = 1, math.min(20, #ds) do
		local v = ds[k]
		rankList[#rankList + 1] = { Id = v.id, Score = v.score }
		tAll[v.id] = tAll[v.id] or (v.laMinh and thongTinCuaMinh() or dongCongKhai(v.robot, dongRobot(v.robot)))
	end
	if tAll[sid] == nil then
		rankList[#rankList + 1] = { Id = sid, Score = tonumber(d.score) or 0 }
		tAll[sid] = thongTinCuaMinh()
	end

	local batDau, ketThuc = 0, 0
	if cfg ~= nil then
		local t = os.date("*t")
		local thang = t.month + 1
		local nam = t.year
		if thang > 12 then thang, nam = 1, nam + 1 end
		batDau = os.time({ year = nam, month = thang, day = tonumber(cfg.Start_mday) or 1,
			hour = tonumber(cfg.Start_hour) or 5, min = tonumber(cfg.Start_min) or 0, sec = 0 })
		ketThuc = mocKetThuc(cfg)
	end
	local tTopN = { SelfRank = viTri, SelfScore = tonumber(d.score) or 0, RankList = rankList }
	dongBo()
	OfflineLog:info(string.format("%s: mo bang — hang %d, diem %s, %d doi thu, %d dong BXH",
		TEN_FILE, viTri, tostring(d.score), #challenge, #rankList))
	goi(ctx, "ClientBeginPlayRsp", tTopN, tAll, batDau, ketThuc)
end)

------------------------------------------------------------------- 3. XEM ĐỐI THỦ
R:on("G_ScoreCompetitivePlayProtocol.ClientViewPlayerReq", function (ctx, strId)
	local s = tostring(strId or "")
	local uidR, serverId = nil, nil
	pcall(function () uidR, serverId = share():StrId2NumId(s) end)
	local d = nil
	if uidR ~= nil and serverId == 0 and tonumber(uidR) then
		local ok, maLoi, tb = pcall(function ()
			return share():GetRobotInfo(tonumber(uidR))
		end)
		if ok and maLoi == 0 and type(tb) == "table" then d = tb end
	end
	if d == nil and s == strIdMinh() then
		d = { GameUserBaseInfo = thongTinCuaMinh(),
			GameScoreCompetitivePlay = { score = duLieu().score,
				total_fight_capacity = duLieu().total_fight_capacity,
				defence = duLieu().defence },
			GameUserHero = {} }
	end
	OfflineLog:info(string.format("%s: xem doi thu '%s' -> %s", TEN_FILE, s,
		tostring(d ~= nil)))
	goi(ctx, "ClientViewPlayerRsp", d or {})
end)

------------------------------------------------------------------- 4. BỐN KHOÁ TRẬN (KHÔNG mô phỏng được)
local function trungLapTran(ctx, hamNhan, lyDo)
	local nMa = ma("Closed", 5500)
	OfflineLog:info(string.format("%s: %s -> %d (%s)", TEN_FILE, hamNhan, nMa, lyDo))
	-- Truyền SỐ (không phải bảng) ⇒ hàm nhận dừng lớp tải rồi thoát, không vào trận.
	if hamNhan == "ClientEndFightRsp" or hamNhan == "ClientRevengeEndRsp" then
		goi(ctx, hamNhan, nil, nil)
	else
		goi(ctx, hamNhan, nMa)
	end
	thongBao(nMa)
end

R:on("G_ScoreCompetitivePlayProtocol.ClientBeginFightReq", function (ctx, tAttack, nIdx, strId)
	trungLapTran(ctx, "ClientBeginFightRsp", "khong co bo mo phong tran")
end)

R:on("G_ScoreCompetitivePlayProtocol.ClientEndFightReq", function (ctx, nIdx, tData)
	trungLapTran(ctx, "ClientEndFightRsp", "khong co bo mo phong tran")
end)

R:on("G_ScoreCompetitivePlayProtocol.ClientRevengeBeginReq", function (ctx, tAttack, strRecordId)
	trungLapTran(ctx, "ClientRevengeBeginRsp", "khong co ban ghi tran de tra thu")
end)

R:on("G_ScoreCompetitivePlayProtocol.ClientRevengeEndReq", function (ctx, strRecordId, tData)
	trungLapTran(ctx, "ClientRevengeEndRsp", "khong co ban ghi tran de tra thu")
end)

------------------------------------------------------------------- 5. ĐỘI PHÒNG THỦ
--[[ `ClientAdjustDefTeamReq(tData)` — tData là DANH SÁCH các đội, mỗi đội là danh
	sách hero id (`APRTeamData:deployUIToProtocolData`). Lưu thành đúng hình
	`GameScoreCompetitivePlay.defence` mà `parseChallengerInfo` đọc:
	`{ {fight_capacity, team = {{hero_id}, …}}, … }`. ]]
R:on("G_ScoreCompetitivePlayProtocol.ClientAdjustDefTeamReq", function (ctx, tData)
	if type(tData) ~= "table" then
		return baoLoi(ctx, ma("Closed", 5500), "du lieu doi phong thu sai")
	end
	local d = duLieu()
	local defence = {}
	for _, dsHero in ipairs(tData) do
		if type(dsHero) ~= "table" then
			return baoLoi(ctx, ma("Closed", 5500), "doi phong thu sai hinh")
		end
		local team, luc = {}, 0
		for _, id in ipairs(dsHero) do
			local nId = tonumber(id)
			if nId == nil then
				return baoLoi(ctx, ma("Closed", 5500), "hero id khong phai so")
			end
			local ok, b, hero = pcall(function () return G_HeroLogic:GetHeroWithID(nId) end)
			if not ok or b == false or type(hero) ~= "table" then
				return baoLoi(ctx, ma("Closed", 5500), "khong co tuong " .. tostring(nId))
			end
			local okF, bF, nF = pcall(function () return G_HeroLogic:GetHeroAllFightCapacityWithHero(hero) end)
			luc = luc + ((okF and bF ~= false and tonumber(nF)) or 0)
			team[#team + 1] = { hero_id = nId }
		end
		table.insert(defence, { fight_capacity = luc, team = team })
	end
	d.defence = defence
	dongBo()
	OfflineLog:info(string.format("%s: luu doi phong thu — %d doi", TEN_FILE, #defence))
	goi(ctx, "ClientAdjustDefTeamRsp")
end)

------------------------------------------------------------------- 6. THƯỞNG THĂNG BẬC
R:on("G_ScoreCompetitivePlayProtocol.ClientGetRankRewardReq", function (ctx, nCap)
	local cap = tonumber(nCap) or 0
	local d = duLieu()
	local cfg = cauHinhRank(cap)
	if cfg == nil or type(cfg.rank_reward) ~= "table" or #cfg.rank_reward == 0 then
		return baoLoi(ctx, ma("RewardNotAble", 5503), "bac " .. tostring(cap) .. " khong co thuong")
	end
	if (tonumber(d.max_score) or 0) < (tonumber(cfg.MinScore) or 0) then
		return baoLoi(ctx, ma("RewardNotAble", 5503), "chua dat diem bac " .. tostring(cap))
	end
	if tonumber(d.rank_reward[cap]) ~= 0 then
		return baoLoi(ctx, ma("Rewarded", 5502), "da nhan bac " .. tostring(cap))
	end

	-- Đường thưởng GỐC: `SetDataWithPrizeData` nhận `{PrizeContent = danh sách}`.
	local okPhat, daPhat = pcall(function ()
		return G_ChapterLogic:SetDataWithPrizeData({ PrizeContent = cfg.rank_reward }, 1, "APR")
	end)
	if not okPhat or daPhat ~= true then
		return baoLoi(ctx, ma("RewardNotAble", 5503), "khong phat duoc thuong")
	end
	d.rank_reward[cap] = 1
	dongBo()
	OfflineLog:info(string.format("%s: nhan thuong thang bac %d (%d mon)", TEN_FILE, cap, #cfg.rank_reward))
	goi(ctx, "ClientGetRankRewardRsp", cfg.rank_reward)
end)

------------------------------------------------------------------- 7. PHỤC HỒI ĐIỂM
--[[ Mất điểm khi thua; `lose_recover_score` điểm đổi lấy `recover_diamond` kim cương
	(đúng hai trường của bậc hiện tại). [MOI] mỗi ngày MỘT lần — cấu hình không ghi
	giới hạn, nhưng không chặn thì thành mua điểm vô hạn. ]]
R:on("G_ScoreCompetitivePlayProtocol.ClientFailRecoverReq", function (ctx)
	local d = duLieu()
	local cap = nil
	pcall(function () cap = share():Score2Rank(d.score) end)
	local cfg = cauHinhRank(cap)
	local diem = tonumber(cfg and cfg.lose_recover_score) or 0
	local kc = tonumber(cfg and cfg.recover_diamond) or 0
	if diem <= 0 or kc <= 0 then
		return baoLoi(ctx, ma("RewardNotAble", 5503), "bac nay khong ho tro phuc hoi")
	end
	if (tonumber(d.score) or 0) >= (tonumber(d.max_score) or 0) then
		return baoLoi(ctx, ma("RewardNotAble", 5503), "chua mat diem")
	end
	local t = os.date("*t")
	local now = os.time()
	if t.hour < 5 then now = now - 86400 end
	local hom = os.date("*t", now)
	local khoaHom = hom.year * 10000 + hom.month * 100 + hom.day
	if tonumber(d.last_recover_day) == khoaHom then
		return baoLoi(ctx, ma("RewardNotAble", 5503), "hom nay da phuc hoi roi")
	end
	local okTru, daTru = pcall(function () return G_UserLogic:CostDiamond(kc, "APRRecover") end)
	if not okTru or daTru ~= true then
		return baoLoi(ctx, 504, "khong du kim cuong")
	end
	d.score = math.min(tonumber(d.max_score) or 0, (tonumber(d.score) or 0) + diem)
	d.last_recover_day = khoaHom
	dongBo()
	OfflineLog:info(string.format("%s: phuc hoi %d diem (-%d kim cuong) -> %d", TEN_FILE, diem, kc, d.score))
	goi(ctx, "ClientFailRecoverRsp")
end)

------------------------------------------------------------------- 8. BXH / BÁO CÁO / REPLAY
R:on("G_ScoreCompetitivePlayProtocol.ClientGetRankListReq", function (ctx, nStart, nCount)
	local bat = tonumber(nStart) or 1
	local so = tonumber(nCount) or 10
	if bat < 1 then bat = 1 end
	local ds = bangXepHang()
	local ket = {}
	for k = bat, math.min(bat + so - 1, #ds) do
		local v = ds[k]
		local info
		if v.laMinh then
			info = thongTinCuaMinh()
		else
			info = dongCongKhai(v.robot, dongRobot(v.robot))
		end
		ket[v.id] = {
			Rank = k,
			CharacterName = info.CharacterName,
			ScoreCompetitiveFightCap = info.ScoreCompetitiveFightCap,
			Level = info.Level,
			Score = v.score,
			Portrait = info.Portrait,
			Gender = info.Gender,
			HeroID = info.HeroID,
			ScoreCompetitiveLastRank = info.ScoreCompetitiveLastRank,
			LoginChannel = "",
		}
	end
	goi(ctx, "ClientGetRankListRsp", ket)
end)

-- Không có trận nào ⇒ không có báo cáo. Hàm nhận tự hiện tips "không có bản ghi".
R:on("G_ScoreCompetitivePlayProtocol.ClientGetReportReq", function (ctx)
	goi(ctx, "ClientGetReportRsp", {}, {})
end)

R:on("G_ScoreCompetitivePlayProtocol.ClientGetReplayReq", function (ctx, strRecordId)
	goi(ctx, "ClientGetReplayRsp", {})
end)

OfflineLog:info("dau truong diem: da noi 13 khoa (mo/doi thu/BXH/thuong/phuc hoi; 4 khoa tran tu choi 5500)")

return true
