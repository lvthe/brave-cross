--[[
	offline/handlers/guild_chapter.lua — KÊNH (PHÓ BẢN) BANG HỘI — 军团副本.

	18 khoá `G_GuildChapterLogic` (`ClientGuildChapterLogic`, thực thể CÙNG TÊN
	`G_GuildChapterLogic` — không có bẫy chữ hoa/thường như COG). Trước lượt này
	KHÔNG khoá nào có handler ⇒ mở màn "Quân Đoàn → Phó bản" là lớp tải quay mãi.

	MÔ HÌNH: bang một người vẫn CHƠI ĐƯỢC phó bản (mở → chuẩn bị → đánh → nhận
	thưởng), vì dữ liệu trận do CHÍNH CLIENT sinh ra (`CUIGame:OnGuildCopyCallServer`
	gửi `ChapterData.TotalHart`). Đây là đường THẬT, không phải mô phỏng.

	ĐÂU LÀ DỮ LIỆU GỐC (không bịa):
	  · `KDBGameChapterConfig` 4 dòng `ChapterType = 9993` (`L_G_01_01`…): mở cần
	    `GuildOpenNeedGuildResource` 2500/3500/4000 + đã qua ải thường
	    `GuildOpenNeedPassChapter` (`L_N_03_20`…), `PlayPerDay 3`, thời hạn
	    `GuildChapterExternTimeOut` 3/5/7 ngày, `GuildInjureConfig` (bậc thưởng
	    sát thương + thứ hạng), `GuildChapterCommonDropData` (NpcID rơi chung).
	  · Máu boss = `ChapterLogic:CalcGuildChapterBossHp` (hàm GỐC của client).
	  · Cấu hình tuần = `SharedGuildChapterLogic` (`share_GuildChapterLogic.lua`):
	    `MaxCount = 3` lần đặt lại mỗi tuần, chu kỳ 7 ngày tính từ 2017-03-06 05:00.
	  · Đơn giá mở/đặt lại = `GuildLogic:OpenGuildChapterResourceWithConfig` (hàm
	    GỐC, có giảm giá theo công nghệ `OpenGuildChapter`).

	[GHIM] — chỗ máy chủ gốc đã chết, KHÔNG có nguồn thứ hai:
	1. `GuildInjureConfig.InjureReward/InjureRankReward` phát MỘT LẦN khi qua phó
	   bản (đánh dấu `Settled`), hạng 1 vì chỉ có một người.
	2. Bể rơi chung: mỗi NpcID trong `GuildChapterCommonDropData` ROLL `DropData`
	   theo `DropValue / TotalDropValue` (hai trường có thật của `KDBGameNpcConfig`),
	   chồng vào `Pool[prizeKey]`.
	3. `SysDispatchLeftTime` = thời gian còn lại tới hạn `GuildChapterExternTimeOut`.
	   (Máy chủ gốc có thể tính mốc phân phát khác; UI tự ẩn khi ≤ 0.)

	MÃ LỖI GỐC (`share/error.lua:485-507`): 3541 không đủ quyền · 3542 chưa qua ải
	thường · 3543 thiếu tài nguyên bang · 3544 phó bản chưa mở · 3545 đã bị khoá ·
	3546 hết lượt đánh · 3548 đã xin rồi · 3549 không đủ số lượng để chia ·
	3551 không phải lúc đánh · 3552 đang có người đánh · 3561 quá 3 lần đặt lại.

	⚠ HAI BẪY HÌNH GỌI:
	· Mọi hàm nhận có chữ ký `(eventList, nErrCode, tData)` — tham số ĐẦU là BẢNG.
	  RIÊNG `OnChapterRequestDetailed(eventList, nErrCode, tData, leftDispatchTime)`
	  có BỐN tham số (danh sách thành viên đứng riêng, thời gian còn lại là tham số
	  thứ tư) — truyền thiếu thì client `table.sort(nil)` và nổ.
	· `OnGuildChapterFightBegin` có khối PHÁT SỰ KIỆN BỊ CHÚ THÍCH trong client
	  (`ClientGuildChapterLogic.lua:178-182`) ⇒ handler phải TỰ phát
	  `Guild.Copy.OnGuildChapterFightBegin` thì màn xếp đội mới vào được trận.
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflineGuildChapter = OfflineGuildChapter or {}

local R = OfflineRouter
local TEN_FILE = "pho ban bang"
local KHOA_LUU = "OfflineGuildChapter"
local MOC_NGAY = 5
local GIO_REF = { year = 2017, month = 3, day = 6, hour = 5, min = 0, sec = 0 }
local SO_LAN_DAT_LAI = 3

------------------------------------------------------------------- tiện ích

local function ma(ten, macDinh)
	local ok, v = pcall(function ()
		local E = _G.ErrorCode
		return E and E.Guild and E.Guild[ten]
	end)
	return (ok and tonumber(v)) or macDinh
end

local function goi(ctx, hamNhan, ...)
	local a = { n = select("#", ...), ... }
	local ok, e = pcall(function ()
		return ctx:call("G_GuildChapterLogic", hamNhan, unpack(a, 1, a.n))
	end)
	if not ok then
		OfflineLog:err(string.format("%s: khong goi duoc G_GuildChapterLogic.%s -> %s",
			TEN_FILE, tostring(hamNhan), tostring(e)))
	end
end

-- Trả lỗi: (eventList, nErrCode) — mọi hàm nhận tự dừng lớp tải + hiện toast.
local function loi(ctx, hamNhan, nMa, lyDo)
	OfflineLog:info(string.format("%s: %s -> ma %d (%s)", TEN_FILE, hamNhan, nMa, lyDo or ""))
	goi(ctx, hamNhan, {}, nMa)
end

local function dongBo()
	pcall(function () OfflineStore:syncFromClient() end)
end

local function uid()
	local ok, v = pcall(function () return OfflineBangHoi:uid() end)
	return (ok and tonumber(v)) or 1
end

local function bang()
	local ok, b = pcall(function () return OfflineBangHoi:doc() end)
	return (ok and type(b) == "table") and b or nil
end

local function laQuanLy(b)
	if b == nil then return false end
	local nUid = uid()
	if tonumber(b.HeadUid) == nUid then return true end
	if type(b.Manager) == "string" then
		for v in string.gmatch(b.Manager, "[^|]+") do
			if tonumber(v) == nUid then return true end
		end
	end
	return false
end

local function layBangDuLieu(ten)
	local ok, maLoi, t = pcall(function ()
		return G_DataManager:GetUserDataWithName(ten)
	end)
	if ok and maLoi == 0 and type(t) == "table" then return t end
	return nil
end

local function doc()
	local ok, v = pcall(function ()
		local _, x = G_UserLogic:GetClientCommonData(KHOA_LUU)
		return x
	end)
	if ok and type(v) == "table" then return v end
	return {}
end

local function ghi(t)
	local ok, r = pcall(function ()
		return G_UserLogic:SetClientCommonData(KHOA_LUU, t)
	end)
	if not ok or r ~= true then
		OfflineLog:err(TEN_FILE .. ": khong ghi duoc du lieu pho ban")
	end
end

-- Mốc ngày 5 giờ (cùng `offline/qua_ngay.lua`) — cho lượt đánh mỗi ngày.
local function khoaNgay()
	local now = os.time()
	local t = os.date("*t", now)
	if t.hour < MOC_NGAY then now = now - 86400 end
	local d = os.date("*t", now)
	return d.year * 10000 + d.month * 100 + d.day
end

-- Tuần tính từ 2017-03-06 05:00, 7 ngày — đúng mốc `SharedGuildChapterLogic`.
local function khoaTuan()
	local ref = os.time(GIO_REF)
	local now = os.time()
	return math.floor((now - ref) / (7 * 24 * 3600))
end

local function giaiJSON(v)
	if type(v) == "table" then return v end
	if type(v) ~= "string" or v == "" then return nil end
	if type(_G.cjson) ~= "table" then return nil end
	local ok, t = pcall(function () return cjson.decode(v) end)
	return (ok and type(t) == "table") and t or nil
end

local function cauHinhChapter(chapterKey)
	local ok, cfg = pcall(function ()
		return G_ConfigManager:GetChapterConfig(tostring(chapterKey))
	end)
	if ok and type(cfg) == "table" then return cfg end
	return nil
end

local function phatPrizeID(nPrizeID, lyDo)
	-- ⚠ `GetPrizeWithID` trả `(bResult, prize)` ⇒ `pcall` cho BA giá trị.
	local okLay, bLay, prize = pcall(function ()
		return G_PrizeLogic:GetPrizeWithID(nPrizeID)
	end)
	if not okLay or bLay == false or type(prize) ~= "table" then return false end
	local okPhat, daPhat = pcall(function ()
		return G_ChapterLogic:SetDataWithPrizeData(prize, 1, lyDo or "GuildChapter")
	end)
	return okPhat and daPhat == true
end

-- Tài nguyên bang: nguồn THẬT là `GameUserGuildData.Resouce`; bản trong bảng bang
-- chỉ để màn hình đọc. Sửa CẢ HAI để hai nơi không lệch.
local function truTaiNguyen(nGia)
	local gu = layBangDuLieu("GameUserGuildData")
	if gu == nil or (tonumber(gu.Resouce) or 0) < nGia then return false end
	gu.Resouce = (tonumber(gu.Resouce) or 0) - nGia
	local b = bang()
	if b ~= nil then
		b.Resouce = tonumber(gu.Resouce) or 0
		pcall(function () OfflineBangHoi:ghi(b) end)
	end
	return true
end

local function giaMo(cfg)
	local ok, v = pcall(function ()
		return G_GuildLogic:OpenGuildChapterResourceWithConfig(cfg)
	end)
	if ok and tonumber(v) then return tonumber(v) end
	return tonumber(cfg.GuildOpenNeedGuildResource) or 0
end

local function tongMauBoss(chapterKey)
	local ok, bThay, nHp = pcall(function ()
		return G_ChapterLogic:CalcGuildChapterBossHp(tostring(chapterKey))
	end)
	if ok and bThay ~= false and tonumber(nHp) then return tonumber(nHp) end
	return 1
end

local function thoiHanConLai(e, cfg)
	local now = os.time()
	local han = (tonumber(e.OpenTime) or now) + (tonumber(cfg.GuildChapterExternTimeOut) or 0)
	local con = han - now
	if con < 0 then con = 0 end
	return con
end

local function nguoiChoi()
	local b = {}
	pcall(function ()
		local ok, r, base = pcall(function () return G_UserLogic:GetBaseInfo() end)
		local t = (ok and type(base) == "table") and base or ((ok and type(r) == "table") and r or {})
		b.NickName = t.CharacterName or "Offline"
		b.Level = tonumber(t.Level) or 1
		b.Portrait = t.Portrait
		b.Gender = t.Gender
	end)
	b.Uid = uid()
	b.NickName = b.NickName or "Offline"
	b.Level = b.Level or 1
	return b
end

------------------------------------------------------------------- dữ liệu một phó bản
local function moPhanTu(chapterKey)
	local all = doc()
	local e = all[tostring(chapterKey)]
	if type(e) ~= "table" then
		e = {
			BossHp = 0, BossMax = 0, OpenTime = 0, FightStatus = 0,
			Passed = false, Settled = false,
			Damage = {}, Pool = {}, Requests = {}, Records = {},
			ResetWeek = nil, ResetCount = 0,
			FightDay = nil, FightCount = 0,
		}
		all[tostring(chapterKey)] = e
		return e, all
	end
	if type(e.Damage) ~= "table" then e.Damage = {} end
	if type(e.Pool) ~= "table" then e.Pool = {} end
	if type(e.Requests) ~= "table" then e.Requests = {} end
	if type(e.Records) ~= "table" then e.Records = {} end
	return e, all
end

local function coMo(e)
	return e ~= nil and (tonumber(e.OpenTime) or 0) > 0
end

-- Đếm lượt đánh trong NGÀY; trả số đã đánh hôm nay.
local function luotHomNay(e)
	local key = khoaNgay()
	if tonumber(e.FightDay) ~= key then
		e.FightDay = key
		e.FightCount = 0
	end
	return tonumber(e.FightCount) or 0
end

-- Số lần đặt lại trong TUẦN.
local function luotDatLai(e)
	local key = khoaTuan()
	if tonumber(e.ResetWeek) ~= key then
		e.ResetWeek = key
		e.ResetCount = 0
	end
	return tonumber(e.ResetCount) or 0
end

------------------------------------------------------------------- 1. DANH SÁCH
R:on("G_GuildChapterLogic.ClientQueryGuildChapterListInfo", function (ctx)
	local ds = {}
	local all = doc()
	for key, e in pairs(all) do
		if type(e) == "table" and coMo(e) then
			ds[#ds + 1] = {
				ChapterKey = tostring(key),
				BossHp = tonumber(e.BossHp) or 0,
				OpenTime = tonumber(e.OpenTime) or 0,
				FightStatus = tonumber(e.FightStatus) or 0,
			}
		end
	end
	OfflineLog:info(string.format("%s: danh sach -> %d pho ban dang mo", TEN_FILE, #ds))
	goi(ctx, "OnQueryGuildChapterListInfo", {}, 0, ds)
end)

------------------------------------------------------------------- 2. THÔNG TIN MỘT PHÓ BẢN
R:on("G_GuildChapterLogic.ClientQueryGuildChapterInfo", function (ctx, chapterKey)
	local e = doc()[tostring(chapterKey)]
	local d = { HasRequest = false }
	if type(e) == "table" then
		local req = e.Requests and e.Requests[tostring(uid())]
		d.HasRequest = (type(req) == "string" and req ~= "")
		-- Người đang chuẩn bị/đánh: chỉ có MỘT người chơi, nên là chính mình.
		if (tonumber(e.FightStatus) or 0) > 0 then
			local nguoi = nguoiChoi()
			d.FightInfo = {
				Uid = nguoi.Uid, NickName = nguoi.NickName, Level = nguoi.Level,
				Portrait = nguoi.Portrait, Gender = nguoi.Gender,
				Status = tonumber(e.FightStatus),
			}
		end
	end
	goi(ctx, "OnQueryGuildChapterInfo", {}, 0, d)
end)

------------------------------------------------------------------- 3. MỞ / ĐẶT LẠI
R:on("G_GuildChapterLogic.ClientOpenGuildChapter", function (ctx, chapterKey)
	local b = bang()
	if b == nil then return loi(ctx, "OnOpenGuildChapter", ma("GuildNotExist", 3501), "chua co bang") end
	if not laQuanLy(b) then return loi(ctx, "OnOpenGuildChapter", ma("GuildGuildChapterOperNotMatter", 3541), "khong du quyen") end

	local cfg = cauHinhChapter(chapterKey)
	if cfg == nil then return loi(ctx, "OnOpenGuildChapter", 2, "khong co cau hinh " .. tostring(chapterKey)) end

	local all = doc()
	if type(all[tostring(chapterKey)]) == "table" and coMo(all[tostring(chapterKey)]) then
		return loi(ctx, "OnOpenGuildChapter", ma("GuildChapterLockError", 3545), "da mo roi")
	end

	-- ⚠ BA giá trị: `CheckChapterIsPass` trả `(bResult, bPass)`.
	local okPass, bRetPass, bPass = pcall(function ()
		return G_ChapterLogic:CheckChapterIsPass(tostring(cfg.GuildOpenNeedPassChapter))
	end)
	if not okPass or bRetPass == false or bPass ~= true then
		return loi(ctx, "OnOpenGuildChapter", ma("GuildChapterNotAchieveNormalChp", 3542),
			"chua qua ai " .. tostring(cfg.GuildOpenNeedPassChapter))
	end

	local nGia = giaMo(cfg)
	if not truTaiNguyen(nGia) then
		return loi(ctx, "OnOpenGuildChapter", ma("GuildChapterNotEnoughResource", 3543),
			"thieu tai nguyen bang " .. tostring(nGia))
	end

	local e, all2 = moPhanTu(chapterKey)
	e.BossMax = tongMauBoss(chapterKey)
	e.BossHp = e.BossMax
	e.OpenTime = os.time()
	e.FightStatus = 0
	e.Passed = false
	e.Settled = false
	e.Damage, e.Pool, e.Requests, e.Records = {}, {}, {}, {}
	ghi(all2)
	dongBo()
	OfflineLog:info(string.format("%s: mo '%s' (gia %d, boss %d HP)", TEN_FILE,
		tostring(chapterKey), nGia, e.BossMax))
	goi(ctx, "OnOpenGuildChapter", {}, 0)
end)

R:on("G_GuildChapterLogic.ClientResetGuildChapter", function (ctx, chapterKey)
	local b = bang()
	if b == nil then return loi(ctx, "OnResetGuildChapter", ma("GuildNotExist", 3501), "chua co bang") end
	if not laQuanLy(b) then return loi(ctx, "OnResetGuildChapter", ma("GuildGuildChapterOperNotMatter", 3541), "khong du quyen") end

	local e, all = moPhanTu(chapterKey)
	if not coMo(e) then return loi(ctx, "OnResetGuildChapter", ma("GuildChapterNotOpen", 3544), "chua mo") end
	if (tonumber(e.FightStatus) or 0) ~= 0 then
		return loi(ctx, "OnResetGuildChapter", ma("GuildChapterHasBeenFight", 3552), "dang danh")
	end
	if luotDatLai(e) >= SO_LAN_DAT_LAI then
		return loi(ctx, "OnResetGuildChapter", ma("GuildChapterMaxCount", 3561), "qua 3 lan/tuan")
	end

	local cfg = cauHinhChapter(chapterKey)
	local nGia = cfg and giaMo(cfg) or 0
	if not truTaiNguyen(nGia) then
		return loi(ctx, "OnResetGuildChapter", ma("GuildChapterNotEnoughResource", 3543),
			"thieu tai nguyen bang " .. tostring(nGia))
	end

	e.ResetCount = (tonumber(e.ResetCount) or 0) + 1
	e.BossMax = tongMauBoss(chapterKey)
	e.BossHp = e.BossMax
	e.OpenTime = os.time()
	e.FightStatus = 0
	e.Passed = false
	e.Settled = false
	e.Damage, e.Requests = {}, {}
	ghi(all)
	dongBo()
	OfflineLog:info(string.format("%s: dat lai '%s' (lan %d/tuan, boss %d HP)",
		TEN_FILE, tostring(chapterKey), e.ResetCount, e.BossMax))
	goi(ctx, "OnResetGuildChapter", {}, 0)
end)

------------------------------------------------------------------- 4. CHUẨN BỊ / ĐÁNH
R:on("G_GuildChapterLogic.ClientPrepareGuildChapter", function (ctx, chapterKey)
	local b = bang()
	if b == nil then return loi(ctx, "OnPrepareGuildChapter", ma("GuildNotExist", 3501), "chua co bang") end
	local e, all = moPhanTu(chapterKey)
	if not coMo(e) then return loi(ctx, "OnPrepareGuildChapter", ma("GuildChapterNotOpen", 3544), "chua mo") end
	if e.Passed then return loi(ctx, "OnPrepareGuildChapter", ma("GuildChapterLockError", 3545), "da qua") end
	if (tonumber(e.FightStatus) or 0) ~= 0 then
		return loi(ctx, "OnPrepareGuildChapter", ma("GuildChapterHasBeenFight", 3552), "dang danh")
	end
	e.FightStatus = 1
	ghi(all)
	dongBo()
	OfflineLog:info(TEN_FILE .. ": chuan bi danh '" .. tostring(chapterKey) .. "'")
	goi(ctx, "OnPrepareGuildChapter", {}, 0)
end)

R:on("G_GuildChapterLogic.ClientGiveUpGuildChapterPrepare", function (ctx, chapterKey)
	local e, all = moPhanTu(chapterKey)
	if coMo(e) and (tonumber(e.FightStatus) or 0) == 1 then
		e.FightStatus = 0
		ghi(all)
		dongBo()
	end
	goi(ctx, "OnGiveUpGuildChapterPrepare", {}, 0)
end)

--[[ Vào trận. `reqData = {ChapterKey, HeroList, PotionList}`. Thành công phải
	trả `{BossHp = <máu hiện tại>}` VÀ tự phát sự kiện (client chú thích mất khối
	phát — xem đầu tệp). ]]
R:on("G_GuildChapterLogic.ClientGuildChapterFightBegin", function (ctx, tData)
	local chapterKey = type(tData) == "table" and tostring(tData.ChapterKey or "") or ""
	local e, all = moPhanTu(chapterKey)
	if not coMo(e) then return loi(ctx, "OnGuildChapterFightBegin", ma("GuildChapterNotOpen", 3544), "chua mo") end
	if (tonumber(e.FightStatus) or 0) ~= 1 then
		return loi(ctx, "OnGuildChapterFightBegin", ma("GuildChapterNotFightTime", 3551), "chua chuan bi")
	end
	local cfg = cauHinhChapter(chapterKey)
	local toiDa = cfg and (tonumber(cfg.PlayPerDay) or 3) or 3
	if luotHomNay(e) >= toiDa then
		return loi(ctx, "OnGuildChapterFightBegin", ma("GuildChapterFightTimeLimit", 3546), "het luot hom nay")
	end

	e.FightStatus = 2
	ghi(all)
	dongBo()
	local d = { BossHp = tonumber(e.BossHp) or 0 }
	OfflineLog:info(string.format("%s: vao tran '%s' (boss con %d HP)", TEN_FILE, chapterKey, d.BossHp))
	goi(ctx, "OnGuildChapterFightBegin", {}, 0, d)

	-- Khối phát sự kiện trong client BỊ CHÚ THÍCH ⇒ tự phát để màn xếp đội vào trận.
	pcall(function ()
		G_EventManager:PostLogicEvent(d, EventManagerLogicEvent.Guild.Copy.OnGuildChapterFightBegin)
	end)
end)

--[[ Kết thúc trận: client gửi `{ChapterData = {TotalHart = <sát thương>, …}}`.
	Trừ máu boss, ghi sát thương cá nhân, tăng lượt đánh. Máu về 0 ⇒ qua phó bản
	và chốt thưởng MỘT LẦN (sát thương + hạng 1 + roll bể rơi chung). ]]
local function chotThuong(chapterKey, e, cfg)
	if e.Settled then return end
	e.Settled = true

	local nUid = tostring(uid())
	local satThuong = tonumber(e.Damage[nUid]) or 0

	local injure = giaiJSON(cfg.GuildInjureConfig)
	if injure ~= nil then
		for _, bac in ipairs(injure.InjureReward or {}) do
			local dau = tonumber(bac.InjureBeg) or 0
			local cuoi = tonumber(bac.InjureEnd) or -1
			if satThuong >= dau and (cuoi < 0 or satThuong <= cuoi) then
				phatPrizeID(tonumber(bac.RewardId), "GuildChapterInjure")
				break
			end
		end
		-- Chỉ có MỘT người ⇒ hạng 1. `InjureRankReward` là danh sách các bậc hạng.
		for _, bac in ipairs(injure.InjureRankReward or {}) do
			local dau = tonumber(bac.rankBeg) or 0
			local cuoi = tonumber(bac.rankEnd) or 0
			if 1 >= dau and 1 <= cuoi then
				for _, id in ipairs(bac.rewardList or {}) do
					phatPrizeID(tonumber(id), "GuildChapterRank")
				end
				break
			end
		end
	end

	-- Bể rơi CHUNG: roll từng NpcID mà config chỉ định, theo `DropValue/TotalDropValue`.
	local map = giaiJSON(cfg.GuildChapterCommonDropData)
	if map ~= nil then
		local daRoll = {}
		for _, npcId in pairs(map) do
			local n = tonumber(npcId)
			if n and not daRoll[n] then
				daRoll[n] = true
				local okNpc, npc = pcall(function ()
					return G_ConfigManager:GetNpcConfigWithNpcId(n)
				end)
				if okNpc and type(npc) == "table" then
					local ds = giaiJSON(npc.DropData)
					local tong = tonumber(npc.TotalDropValue) or 100
					if tong <= 0 then tong = 100 end
					for _, drop in ipairs(ds or {}) do
						local pd = type(drop.PrizeData) == "string" and giaiJSON(drop.PrizeData) or drop.PrizeData
						if type(pd) == "table" then
							local p = (tonumber(drop.DropValue) or 0) / tong
							if p > 1 then p = 1 end
							if math.random() <= p then
								local loai = tonumber(pd.PrizeResType) or 0
								local id = 0
								if loai == 2 or loai == 8 then id = tonumber(pd.PropID) or 0
								elseif loai == 3 then id = tonumber(pd.CurrencyType) or 0
								elseif loai == 6 then id = tonumber(pd.PrizeProperty) or 0 end
								local so = tonumber(pd.PrizeResCount) or 0
								if id > 0 and so > 0 then
									local key = loai .. "_" .. id .. "_" .. so
									e.Pool[key] = (tonumber(e.Pool[key]) or 0) + so
								end
							end
						end
					end
				end
			end
		end
	end
	OfflineLog:info(string.format("%s: '%s' QUA — da chot thuong (sat thuong %d)",
		TEN_FILE, tostring(chapterKey), satThuong))
end

R:on("G_GuildChapterLogic.ClientGuildChapterFightComplete", function (ctx, chapterKey, tData)
	local key = tostring(chapterKey or "")
	local e, all = moPhanTu(key)
	if not coMo(e) then return loi(ctx, "OnGuildChapterFightComplete", ma("GuildChapterNotOpen", 3544), "chua mo") end
	if (tonumber(e.FightStatus) or 0) ~= 2 then
		return loi(ctx, "OnGuildChapterFightComplete", ma("GuildChapterNotFightTime", 3551), "khong o trong tran")
	end

	local chapter = (type(tData) == "table" and type(tData.ChapterData) == "table") and tData.ChapterData or {}
	local satThuong = tonumber(chapter.TotalHart) or 0
	if satThuong < 0 then satThuong = 0 end

	local nUid = tostring(uid())
	e.Damage[nUid] = (tonumber(e.Damage[nUid]) or 0) + satThuong
	e.BossHp = (tonumber(e.BossHp) or 0) - satThuong
	if e.BossHp < 0 then e.BossHp = 0 end
	e.FightStatus = 0
	luotHomNay(e)
	e.FightCount = (tonumber(e.FightCount) or 0) + 1

	local cfg = cauHinhChapter(key)
	if e.BossHp <= 0 then
		e.Passed = true
		if cfg ~= nil then chotThuong(key, e, cfg) end
	end
	ghi(all)
	dongBo()

	OfflineLog:info(string.format("%s: '%s' ket thuc — sat thuong %d, boss con %d%s",
		TEN_FILE, key, satThuong, e.BossHp, e.Passed and " (DA QUA)" or ""))
	goi(ctx, "OnGuildChapterFightComplete", {}, 0, {
		ChapterKey = key,
		ChapterData = chapter,
		DropList = {},
	})
end)

------------------------------------------------------------------- 5. THƯỞNG CHUNG
local function RewardInfo(e)
	local d = {}
	for key, so in pairs(e.Pool or {}) do
		local req = 0
		for _, pk in pairs(e.Requests or {}) do
			if pk == key then req = req + 1 end
		end
		d[key] = { GroupCount = tonumber(so) or 0, RequestNum = req }
	end
	return d
end

R:on("G_GuildChapterLogic.ClientGuildChapterRewardInfo", function (ctx)
	local all = doc()
	-- Lấy phó bản đã qua gần nhất (nếu nhiều) — bể rơi là TOÀN BANG nhưng UI
	-- hiện theo từng phó bản; với một người, chọn phó bản mới nhất có bể.
	local chon, cfg = nil, nil
	for key, e in pairs(all) do
		if type(e) == "table" and coMo(e) and next(e.Pool or {}) ~= nil then
			if chon == nil or (tonumber(e.OpenTime) or 0) > (tonumber(chon.OpenTime) or 0) then
				chon, key = e, key
			end
		end
	end
	local con = 0
	if chon ~= nil then
		local c = cauHinhChapter(key)
		if c ~= nil then con = thoiHanConLai(chon, c) end
	end
	local d = { SysDispatchLeftTime = con, RewardInfo = chon and RewardInfo(chon) or {} }
	goi(ctx, "OnGuildChapterRewardInfo", {}, 0, d)
end)

R:on("G_GuildChapterLogic.ClientQueryReqestRewardMember", function (ctx, prizeKey)
	local all = doc()
	local ds = {}
	local pk = tostring(prizeKey or "")
	for _, e in pairs(all) do
		if type(e) == "table" then
			for nUid, key in pairs(e.Requests or {}) do
				if key == pk then
					local nguoi = nguoiChoi()
					ds[#ds + 1] = {
						Uid = tonumber(nUid), NickName = nguoi.NickName, Level = nguoi.Level,
						Portrait = nguoi.Portrait, Gender = nguoi.Gender,
						TotalHart = tonumber(e.Damage[nUid]) or 0,
					}
				end
			end
		end
	end
	goi(ctx, "OnQueryReqestRewardMember", {}, 0, ds)
end)

-- Cấp một `prizeKey` ("loai_id_so") cho người nhận. Trả true nếu phát được.
local function phatTheoKey(prizeKey, nUidNhan, lyDo)
	local a, b, c = tostring(prizeKey or ""):match("^(%d+)_(%d+)_(%d+)$")
	local loai, id, so = tonumber(a), tonumber(b), tonumber(c)
	if loai == nil or id == nil or so == nil then return false end
	local ok, r
	if loai == 2 or loai == 8 then
		ok, r = pcall(function () return G_ItemLogic:AddItem(id, so, lyDo or "GuildChapter") end)
	elseif loai == 6 then
		ok, r = pcall(function () return G_HeroLogic:AddHeroFragment(id, so, lyDo or "GuildChapter") end)
	elseif loai == 3 then
		ok, r = pcall(function () return G_UserLogic:AddResourceWithType(id, so, lyDo or "GuildChapter") end)
	else
		return false
	end
	return ok and r ~= false
end

R:on("G_GuildChapterLogic.ClientDivideReward", function (ctx, prizeKey, receiverUid)
	local b = bang()
	if b == nil then return loi(ctx, "OnDivideReward", ma("GuildNotExist", 3501), "chua co bang") end
	if not laQuanLy(b) then return loi(ctx, "OnDivideReward", ma("GuildGuildChapterOperNotMatter", 3541), "khong du quyen") end

	local pk = tostring(prizeKey or "")
	local nNhan = tonumber(receiverUid) or uid()
	local all = doc()
	local e, keyChon = nil, nil
	for key, x in pairs(all) do
		if type(x) == "table" and (tonumber(x.Pool[pk]) or 0) > 0 then e, keyChon = x, key break end
	end
	if e == nil then
		return loi(ctx, "OnDivideReward", ma("GuildChapterPrizeCountNotEngough", 3549), "be rong")
	end
	if e.Requests[tostring(nNhan)] ~= pk then
		return loi(ctx, "OnDivideReward", ma("GuildChapterPrizeCountNotEngough", 3549), "nguoi nay khong xin mon do")
	end
	if not phatTheoKey(pk, nNhan, "GuildChapterDivide") then
		return loi(ctx, "OnDivideReward", ma("GuildChapterPrizeCountNotEngough", 3549), "khong phat duoc")
	end

	e.Pool[pk] = e.Pool[pk] - 1
	if e.Pool[pk] <= 0 then e.Pool[pk] = nil end
	e.Requests[tostring(nNhan)] = nil
	local nguoi = nguoiChoi()
	e.Records[#e.Records + 1] = {
		PrizeKey = pk,
		DisptcherUid = uid(), DisptcherName = nguoi.NickName,
		ReceiverUid = nNhan, ReceiverName = nguoi.NickName,
		DisptcherTime = os.time(),
	}
	ghi(all)
	dongBo()
	OfflineLog:info(string.format("%s: chia '%s' cho %d", TEN_FILE, pk, nNhan))
	goi(ctx, "OnDivideReward", {}, 0)
end)

R:on("G_GuildChapterLogic.ClientQueryGuildChapterRewardRecord", function (ctx)
	local all = doc()
	local ds = {}
	for _, e in pairs(all) do
		if type(e) == "table" then
			for _, r in ipairs(e.Records or {}) do ds[#ds + 1] = r end
		end
	end
	table.sort(ds, function (a, b) return (tonumber(a.DisptcherTime) or 0) > (tonumber(b.DisptcherTime) or 0) end)
	goi(ctx, "OnQueryGuildChapterRewardRecord", {}, 0, ds)
end)

R:on("G_GuildChapterLogic.ClientQuerySelfRequestPrize", function (ctx)
	local nUid = tostring(uid())
	local all = doc()
	local pk, chon = nil, nil
	for key, e in pairs(all) do
		if type(e) == "table" then
			if type(e.Requests[nUid]) == "string" then pk = e.Requests[nUid]; chon = e end
			if chon == nil and coMo(e) then chon = e end
		end
	end
	local d = {
		RewardInfo = chon and RewardInfo(chon) or {},
		SelfPrizeInfo = { PrizeKey = pk or "", Rank = (pk and 1) or 0 },
	}
	goi(ctx, "OnQuerySelfRequestPrize", {}, 0, d)
end)

-- ⚠ BỐN tham số: danh sách thành viên đứng RIÊNG, thời gian còn lại là tham số 4.
R:on("G_GuildChapterLogic.ClientChapterRequestDetailed", function (ctx, prizeKey)
	local pk = tostring(prizeKey or "")
	local all = doc()
	local ds, con = {}, 0
	for key, e in pairs(all) do
		if type(e) == "table" then
			for nUid, k in pairs(e.Requests or {}) do
				if k == pk then
					local nguoi = nguoiChoi()
					ds[#ds + 1] = {
						Uid = tonumber(nUid), NickName = nguoi.NickName, Level = nguoi.Level,
						Portrait = nguoi.Portrait, Gender = nguoi.Gender,
						TotalHart = tonumber(e.Damage[nUid]) or 0,
					}
				end
			end
			local c = cauHinhChapter(key)
			if c ~= nil then
				local n = thoiHanConLai(e, c)
				if n > con then con = n end
			end
		end
	end
	table.sort(ds, function (a, b) return (a.TotalHart or 0) > (b.TotalHart or 0) end)
	for i, v in ipairs(ds) do v.Rank = i end
	goi(ctx, "OnChapterRequestDetailed", {}, 0, ds, con)
end)

R:on("G_GuildChapterLogic.ClientRequestReward", function (ctx, chapterKey, prizeKey)
	local nUid = tostring(uid())
	local all = doc()
	local pk = tostring(prizeKey or "")
	local e = all[tostring(chapterKey)]
	if type(e) ~= "table" or not coMo(e) then
		return loi(ctx, "OnRequestReward", ma("GuildChapterNotOpen", 3544), "chua mo")
	end
	if type(e.Requests[nUid]) == "string" and e.Requests[nUid] ~= "" then
		return loi(ctx, "OnRequestReward", ma("GuildRecurRequest", 3548), "da xin roi")
	end
	if (tonumber(e.Pool[pk]) or 0) <= 0 then
		return loi(ctx, "OnRequestReward", ma("GuildChapterPrizeCountNotEngough", 3549), "be rong")
	end
	e.Requests[nUid] = pk
	ghi(all)
	dongBo()
	-- Client đọc `GameUserGuildData.GuildChapterReqPrize` để biết "đã xin chưa".
	local gu = layBangDuLieu("GameUserGuildData")
	if gu ~= nil then gu.GuildChapterReqPrize = pk end
	OfflineLog:info(string.format("%s: xin '%s' o '%s'", TEN_FILE, pk, tostring(chapterKey)))
	goi(ctx, "OnRequestReward", {}, 0)
end)

------------------------------------------------------------------- 6. BẢNG SÁT THƯƠNG
local function bangSatThuong(tuToanBo)
	local all = doc()
	local ds = {}
	if tuToanBo then
		-- "Toàn máy chủ" offline = chính bảng của bang (chỉ có một người chơi).
	end
	for key, e in pairs(all) do
		if type(e) == "table" then
			local daCo = false
			for i, v in ipairs(ds) do
				if tonumber(v.Uid) == uid() then daCo = i break end
			end
			local nguoi = nguoiChoi()
			local dong = {
				Uid = nguoi.Uid, NickName = nguoi.NickName, Level = nguoi.Level,
				Portrait = nguoi.Portrait, Gender = nguoi.Gender,
				Injure = tonumber(e.Damage[tostring(uid())]) or 0,
			}
			if daCo then
				if dong.Injure > (ds[daCo].Injure or 0) then ds[daCo] = dong end
			else
				ds[#ds + 1] = dong
			end
		end
	end
	table.sort(ds, function (a, b) return (a.Injure or 0) > (b.Injure or 0) end)
	for i, v in ipairs(ds) do v.Rank = i end
	return ds
end

R:on("G_GuildChapterLogic.ClientQueryGuildChapterInjuryRank", function (ctx, chapterKey)
	local e = doc()[tostring(chapterKey)]
	local ds = {}
	if type(e) == "table" then
		local nguoi = nguoiChoi()
		ds[1] = {
			Rank = 1, Uid = nguoi.Uid, NickName = nguoi.NickName, Level = nguoi.Level,
			Portrait = nguoi.Portrait, Gender = nguoi.Gender,
			Injure = tonumber(e.Damage[tostring(uid())]) or 0,
		}
	end
	goi(ctx, "OnQueryGuildChapterInjuryRank", {}, 0, ds)
end)

R:on("G_GuildChapterLogic.ClientQueryGuildChapterServerInjuryRank", function (ctx, chapterKey)
	goi(ctx, "OnQueryGuildChapterServerInjuryRank", {}, 0, bangSatThuong(true))
end)

-- [[ `ClientChapterGetCommonDropData`: lời gọi trong client BỊ CHÚ THÍCH
--    (`ClientGuildChapterLogic.lua:403`) — đăng ký để nếu bản khác gọi thì không
--    treo lớp tải; trả bảng rỗng (bể rơi nằm ở `GuildChapterRewardInfo`). ]]
R:on("G_GuildChapterLogic.ClientChapterGetCommonDropData", function (ctx, chapterKey, process)
	goi(ctx, "OnChapterGetCommonDropData", {}, 0, {})
end)

OfflineLog:info("pho ban bang: da noi 18 khoa (mo/chuan bi/danh/thuong chung/bang sat thuong)")

return true
