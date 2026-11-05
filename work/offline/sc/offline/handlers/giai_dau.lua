--[[
	offline/handlers/giai_dau.lua — GIẢI ĐẤU (武道会) nối với động cơ trên server riêng.

	Ba khoá có HÌNH DỮ LIỆU đọc rõ trong client:
	  · `G_TournamentLogic|ClientGetContestInfo` → `g_ContestLogic:OnGetContestInfo(err, tData)`
	    — `ContestDataManager:OnGetContestInfo` (`user/UI/contest/ContestDataManager.lua:635`)
	    đọc `IsApplied · IsAutoAppiled · CurrentStep · StepStartTime · StepFinishTime ·
	    CanDoQuiz · Score`.
	  · `G_TournamentLogic|ClientGetOtherInfo` → `OnGetOtherInfo(err, tData)`
	    — `ContestHelper:OnGetOtherInfo` (`user/UI/contest/ContestHelper.lua:115`) đọc thêm
	    `ChampionId · ChampionAward · CanDoQuiz · DiamondAwardCount · championWelfare · HeroInfo`.
	  · `G_TournamentLogic|ClientSignUp` → `OnSignUp(err)`.

	MƯỜI BA KHOÁ CÒN LẠI GIỮ NGUYÊN trong lớp chắn: battle report / 32强 / finals / quiz /
	playback / shop có hình dữ liệu là cả một hệ (seats, quiz, replay) — trả nửa vời sẽ làm
	UI NÉM LỖI, nên chưa mở. Mở dần từng nhóm khi đọc xong hình của nhóm ấy.

	ÁNH XẠ BƯỚC (client `share/TournamentDef.lua:40-54`):
	  server `dang_ky`      → CLIENT_STEP_SIGNUP (1)
	  server `dang_dien_ra` → CLIENT_STEP_AUDITION (3)
	  server `xong`         → CLIENT_STEP_OVER (14)
	Mỗi lượt đọc đều gọi `/api/tournament/tick` trước (idempotent) để vòng đã tới hạn tự chạy —
	người chơi mở màn hình là bracket tiến, không cần cron.
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflineGiaiDau = OfflineGiaiDau or {}

local R = OfflineRouter
local TEN_FILE = "giai dau"

local STEP_SIGNUP = 1
local STEP_AUDITION = 3
local STEP_OVER = 14
local MA_DONG = 4401      -- `TournamentCode.Closed` của client

local function coHTTP()
	local tk = rawget(_G, "OfflineTaiKhoan")
	if tk == nil or tk.uid == nil then return nil end
	if type(rawget(_G, "sngHttpRequestWithString")) ~= "function" then return nil end
	return tk
end

local function api(duong, body, cb)
	local tk = rawget(_G, "OfflineTaiKhoan")
	if tk == nil then return false end
	return pcall(function () tk:goi(duong, body, cb) end)
end

local function traLoi(fn, ...)
	local args = { n = select("#", ...), ... }
	pcall(function ()
		local f = g_ContestLogic[fn]
		if type(f) ~= "function" then return end
		f(g_ContestLogic, unpack(args, 1, args.n))
	end)
end

--[[ Chọn giải đang mở MỚI NHẤT (dang_ky hoặc dang_dien_ra). ]]
local function chonGiai(ds)
	if type(ds) ~= "table" then return nil end
	local chon = nil
	for _, g in ipairs(ds) do
		local st = g and g.status
		if (st == "dang_ky" or st == "dang_dien_ra")
			and (chon == nil or (tonumber(g.id) or 0) > (tonumber(chon.id) or 0)) then
			chon = g
		end
	end
	return chon
end

local function daDangKy(tl, uid)
	local ds = type(tl) == "table" and tl.entries or nil
	if type(ds) ~= "table" then return false end
	for _, e in ipairs(ds) do
		if tonumber(e.uid) == tonumber(uid) then return true end
	end
	return false
end

local function duLieu(tl, uid)
	local g = type(tl) == "table" and tl.tournament or {}
	local step = STEP_OVER
	if g.status == "dang_ky" then step = STEP_SIGNUP
	elseif g.status == "dang_dien_ra" then step = STEP_AUDITION end

	local now = tonumber(g.now_ts) or os.time()
	local start = tonumber(g.start_ts) or tonumber(g.created_ts) or now
	local finish
	if g.status == "dang_ky" then
		finish = start + 3600                       -- [MOI] cửa sổ đăng ký hiển thị 1 giờ
	elseif g.status == "dang_dien_ra" then
		finish = now + (tonumber(g.round_seconds) or 300)
	else
		finish = tonumber(g.finish_ts) or now
	end

	local champion = 0
	if g.status == "xong" and type(tl.rounds) == "table" and #tl.rounds > 0 then
		local cuoi = tl.rounds[#tl.rounds]
		local tran = cuoi and cuoi.matches and cuoi.matches[1]
		if tran and tran.winner_uid ~= nil then champion = tonumber(tran.winner_uid) or 0 end
	end

	return {
		IsApplied = daDangKy(tl, uid),
		IsAutoAppiled = false,
		CurrentStep = step,
		PlayerStep = 0,
		StepStartTime = start,
		StepFinishTime = finish,
		CanDoQuiz = false,
		Score = 0,
		ChampionId = champion,
		ChampionName = "",
		ChampionAward = false,
		DiamondAwardCount = 0,
		championWelfare = {},
		HeroInfo = {},
	}
end

--[[ Đọc giải: tick (cho vòng tới hạn tự chạy) → danh sách → chi tiết. ]]
local function docGiai(uid, cb)
	api("/api/tournament/tick", {}, function ()
		api("/api/tournaments", {}, function (okDS, ds)
			local g = chonGiai(okDS and ds and ds.tournaments or nil)
			if g == nil then return cb(false, nil) end
			api("/api/tournament", { id = tonumber(g.id), uid = tonumber(uid) }, function (ok, tl)
				cb(ok == true, tl)
			end)
		end)
	end)
end

local function guiThongTin(ctx, fnTraLoi)
	local tk = coHTTP()
	if tk == nil then
		OfflineLog:warn(TEN_FILE .. ": khong co HTTP/tai khoan")
		traLoi(fnTraLoi, MA_DONG, {})
		return
	end
	docGiai(tonumber(tk.uid), function (ok, tl)
		if not ok then
			OfflineLog:info(TEN_FILE .. ": khong co giai dang mo")
			traLoi(fnTraLoi, MA_DONG, {})
			return
		end
		local d = duLieu(tl, tonumber(tk.uid))
		OfflineLog:info(string.format("%s: giai %s · buoc %d · da dang ky=%s",
			TEN_FILE, tostring(tl.tournament and tl.tournament.id),
			tostring(d.CurrentStep), tostring(d.IsApplied)))
		traLoi(fnTraLoi, 0, d)
	end)
end

R:on("G_TournamentLogic.ClientGetContestInfo", function (ctx)
	guiThongTin(ctx, "OnGetContestInfo")
end)

R:on("G_TournamentLogic.ClientGetOtherInfo", function (ctx)
	guiThongTin(ctx, "OnGetOtherInfo")
end)

R:on("G_TournamentLogic.ClientSignUp", function (ctx)
	local tk = coHTTP()
	if tk == nil then
		traLoi("OnSignUp", MA_DONG)
		return
	end
	api("/api/tournaments", {}, function (okDS, ds)
		local g = chonGiai(okDS and ds and ds.tournaments or nil)
		if g == nil or g.status ~= "dang_ky" then
			OfflineLog:info(TEN_FILE .. ": khong co giai trong pha dang ky")
			traLoi("OnSignUp", MA_DONG)
			return
		end
		api("/api/tournament/register",
			{ id = tonumber(g.id), uid = tonumber(tk.uid) },
			function (ok, tl)
				if ok == true then
					OfflineLog:info(string.format("%s: da dang ky giai %d", TEN_FILE, tonumber(g.id)))
					pcall(function ()
						if OfflineHanhDong ~= nil then
							OfflineHanhDong:ghi("tournament", "signup", { id = tonumber(g.id) })
						end
					end)
					traLoi("OnSignUp", 0)
					-- Đẩy lại trạng thái để màn hình đổi sang "đã đăng ký".
					docGiai(tonumber(tk.uid), function (ok2, tl2)
						if ok2 then traLoi("OnGetContestInfo", 0, duLieu(tl2, tonumber(tk.uid))) end
					end)
				else
					local ma = tonumber(tl and tl.code) or MA_DONG
					OfflineLog:info(TEN_FILE .. ": dang ky that bai ma " .. tostring(ma))
					traLoi("OnSignUp", ma)
				end
			end)
	end)
end)

OfflineLog:info("giai dau: da noi 3 khoa (thong tin / thong tin ngan / dang ky)")
