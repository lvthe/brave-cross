-- _thu_apr.lua — bộ thử cho `offline/handlers/apr.lua` (đấu trường điểm).
-- Chạy: `python _thu_nha_cua.py _thu_apr.lua`.
--
-- Nạp LUẬT MÁY CHỦ GỐC (`share/ScoreCompetitivePlay/share_ScoreCompetitivePlayLogic.lua`)
-- để đo tích hợp robot thật, không chép lại luật. Đo: trạng thái mở, BeginPlay (danh
-- sách đối thủ + BXH), ViewPlayer, đội phòng thủ, thưởng thăng bậc, phục hồi điểm, và
-- bốn khoá trận TỪ CHỐI bằng 5500.
package.path = [[__SC__/?.lua;__SC__/?/init.lua;]] .. package.path

local function ghi(a, b)
    local m = b
    if type(a) == 'string' then m = a end
    io.write('[log] ' .. tostring(m) .. '\n')
end
package.preload['offline.log'] = function ()
    local L = { info = ghi, warn = ghi, err = ghi }; OfflineLog = L; return L
end
package.preload['offline.store'] = function ()
    local S = { TABLES = {}, data = {}, dirty = false }
    function S:syncFromClient() end
    OfflineStore = S; return S
end
package.preload['offline.router'] = function ()
    local R = { handlers = {} }
    function R:on(k, f) self.handlers[k] = f end
    function R:has(k) return self.handlers[k] ~= nil end
    OfflineRouter = R; return R
end

-- `class` tối thiểu để nạp được tệp share (máy chủ gốc).
function class(base)
    local c = {}
    c.__index = c
    if base then setmetatable(c, { __index = base }) end
    function c:new(...)
        local o = setmetatable({}, c)
        if o.ctor then o:ctor(...) end
        return o
    end
    return c
end

KDebug = {
    ProcessNotTable = function () return false end,
    ProcessNotNumber = function () return false end,
    ProcessNotString = function () return false end,
    ProcessError = function () return false end,
    PrintWarning = function () end,
    PrintError = function () end,
    ProcessNotUserdata = function () return false end,
}
copyTab = function (t) local o = {}; for k, v in pairs(t or {}) do o[k] = v end; return o end
-- `string.split` là hàm tiện ích của client (không có trong Lua trần) — share dùng nó.
function string.split(s, sep)
    local out = {}
    for piece in string.gmatch(tostring(s), '([^' .. tostring(sep) .. ']+)') do out[#out + 1] = piece end
    return out
end
EquipmentType = { Weapon = 1 }
ErrorCode = {
    OK = 0,
    ScoreCompetitive = {
        Closed = 5500, Challenged = 5501, Rewarded = 5502, RewardNotAble = 5503,
        MaxRevenge = 5504, NotMatch = 5505, NotSameMatch = 5507, RankCanNotRevenge = 5508,
    },
}
CUINotificationEvent = { OnServerRequestError = 'OnServerRequestError' }

--=========================================================== TRẠNG THÁI GIẢ
UID = 100001
BANG = { GuildId = 123, HeadUid = UID }
APRDATA = {}
HEROES = { ['56'] = { UserHeroID = 56 }, ['57'] = { UserHeroID = 57 }, ['58'] = { UserHeroID = 58 } }
BASE = { Level = 90, Diamond = 1000 }
THONG_BAO = {}
PRIZE_PHAT = 0

OfflineBangHoi = { uid = function () return UID end }

G_DataManager = {
    GetUserDataWithName = function (self, ten)
        if ten == 'GameScoreCompetitivePlay' then return 0, APRDATA end
        if ten == 'GameUserHero' then return 0, HEROES end
        return 0, {}
    end,
    SetUserDataWithName = function (self, ten, t)
        if ten == 'GameScoreCompetitivePlay' then APRDATA = t end
        return true
    end,
}
G_UserLogic = {
    GetBaseInfo = function (self) return true, BASE end,
    CostDiamond = function (self, n)
        if BASE.Diamond < n then return false, BASE.Diamond end
        BASE.Diamond = BASE.Diamond - n
        return true, BASE.Diamond
    end,
}
G_HeroLogic = {
    GetHeroWithID = function (self, id) return true, HEROES[tostring(id)] end,
    GetHeroAllFightCapacityWithHero = function (self, h) return true, 1000 end,
    FilterHeroJobType = function (self, id, job) return job or 1 end,
}
G_ChapterLogic = {
    SetDataWithPrizeData = function (self, prize, n, lyDo) PRIZE_PHAT = PRIZE_PHAT + 1; return true end,
}
G_RankLogic = { GetSelf5HeroPower = function (self) return true, 5000 end }
g_CUINotificationCenter = {
    PostNotification = function (self, ev, ma) THONG_BAO[#THONG_BAO + 1] = ma end,
}
g_CUIGameRPCManager = {}
RSP = {}
function g_CUIGameRPCManager:OnReciveResponse(...)
    RSP[#RSP + 1] = { n = select('#', ...), ... }
end

--=========================================================== CẤU HÌNH
RULE = {
    Start_mday = 1, Start_hour = 5, Start_min = 0,
    End_mday = 25, End_hour = 22, End_min = 0,
    StartScore = 1000, RobotCount = 20,
}
ROBOT_CONF = {
    HeroInfo = { HeroLevel = 70, HeroQuality = 4, HeroQualityAdd = 4.9, HeroGrowthFactor = 5 },
    EquipInfo = { EquipLevel = 7, IntensifyLevel = 70, Quality = 5 },
}
-- 20 robot, lực chiến tăng dần; `team` đúng hình share logic đọc (cặp heroId, jobType).
ROBOTS = {}
for i = 1, 20 do
    ROBOTS[i] = {
        name = 'Robot' .. i, gender = i % 2, fight_capacity = 1000 * i,
        team = { { 25, 1, 26, 2 }, { 27, 1 }, { 28, 2 } },
    }
end
RANK = {}
for cap = 1, 19 do
    RANK[tostring(cap)] = {
        Id = cap,
        MinScore = 1000 + (19 - cap) * 200,   -- 19:1000, 18:1200 … 1:4600
        win_add_score = 50, lose_dec_score = 10,
        lose_recover_score = (cap == 5) and 25 or 0,
        recover_diamond = (cap == 5) and 120 or 0,
        rank_reward = (cap == 1) and { { PrizeResType = 2, PropID = 89, PrizeResCount = 10 } } or '',
        season_reward = {},
    }
end
RANK_SCORE = {}
for cap = 1, 19 do RANK_SCORE[tostring(cap)] = RANK[tostring(cap)].MinScore end

G_ConfigManager = {
    configCacheName = {
        ScoreCompetitiveRuleConf = 'ScoreCompetitiveRuleConf',
        ScoreCompetitiveRobotConf = 'ScoreCompetitiveRobotConf',
        ScoreCompetitiveRankScore = 'ScoreCompetitiveRankScore',
    },
    ScoreCompetitiveRuleConf = RULE,
    ScoreCompetitiveRobot = ROBOTS,
    ScoreCompetitiveRobotConf = ROBOT_CONF,
    ScoreCompetitiveRankScore = RANK_SCORE,
    GetConfigWithNameArg = function (self, cache)
        return self[cache]
    end,
    GetConfigTableWithName = function (self, ten) return nil end,
    GetScoreCompetitiveRankConf = function (self, cap) return RANK[tostring(cap)] end,
    GetScoreCompetitiveRobot = function (self, id) return ROBOTS[tonumber(id) or 0] end,
}

-- Nạp LUẬT GỐC của máy chủ (share) — dùng chính GetRobotInfo/Score2Rank/NumId2StrId.
-- Cây `deploy/plain/sc` KHÔNG chứa `share/` nên lùi ra assets thật (5 cấp từ sc).
dofile([[__SC__/../../../../vn/decrypted/assets/sc/share/ScoreCompetitivePlay/share_ScoreCompetitivePlayLogic.lua]])
dofile([[__SC__/offline/handlers/apr.lua]])
local R = require('offline.router')

local dat, hong = 0, 0
local function check(ok, ten, ct)
    if ok then dat = dat + 1; io.write('  OK   ' .. ten .. '\n')
    else hong = hong + 1; io.write('  HONG ' .. ten .. (ct ~= nil and (' -> ' .. tostring(ct)) or '') .. '\n') end
end
local function ctxGia()
    local c = { calls = {} }
    function c:call(obj, f, ...)
        self.calls[#self.calls + 1] = { obj = obj, f = f, args = { ... }, n = select('#', ...) }
        -- Chỉ `g_CUIGameRPCManager` có hàm nhận THẬT trong bộ thử (ghi vào RSP).
        local o = _G[obj]
        if obj == 'g_CUIGameRPCManager' and type(o) == 'table' and type(o[f]) == 'function' then
            o[f](o, ...)
        end
    end
    return c
end
local function goi(khoa, ...)
    local c = ctxGia()
    local h = R.handlers[khoa]
    if h == nil then return nil end
    h(c, ...)
    return c.calls[#c.calls], c
end

--=========================================================== 1. ĐĂNG KÝ
io.write('\n-- 1. dang ky 13 khoa + obj nhan g_APRProtocol\n')
local KHOA = {
    'ClientGetOpenInfoReq', 'ClientBeginPlayReq', 'ClientViewPlayerReq', 'ClientBeginFightReq',
    'ClientEndFightReq', 'ClientAdjustDefTeamReq', 'ClientGetRankRewardReq', 'ClientGetReportReq',
    'ClientGetReplayReq', 'ClientGetRankListReq', 'ClientRevengeBeginReq', 'ClientRevengeEndReq',
    'ClientFailRecoverReq',
}
local thieu = {}
for _, k in ipairs(KHOA) do
    if not R:has('G_ScoreCompetitivePlayProtocol.' .. k) then thieu[#thieu + 1] = k end
end
check(#thieu == 0, 'dang ky DU 13 khoa', table.concat(thieu, ', '))

local x = goi('G_ScoreCompetitivePlayProtocol.ClientGetOpenInfoReq')
check(x and x.obj == 'g_APRProtocol' and x.f == 'ClientGetOpenInfoRsp',
    'mo -> ClientGetOpenInfoRsp qua g_APRProtocol (chu thuong)')
check(x and x.n == 3 and x.args[1] == 3, 'du 70 cap + mua dang mo -> state 3 (OPEN)', x and x.args[1])
check(x and type(x.args[2]) == 'number' and x.args[2] > 0, 'co thoi gian con lai')

BASE.Level = 50
x = goi('G_ScoreCompetitivePlayProtocol.ClientGetOpenInfoReq')
check(x and x.args[1] == 5, 'chua du 70 cap -> state 5')
BASE.Level = 90

--=========================================================== 2. BEGIN PLAY
io.write('\n-- 2. BeginPlay: doi thu + BXH tu ROBOT THAT\n')
x = goi('G_ScoreCompetitivePlayProtocol.ClientBeginPlayReq')
check(x and x.f == 'ClientBeginPlayRsp' and x.n == 4, 'BeginPlay -> 4 tham so')
local topN, tAll = x.args[1], x.args[2]
check(type(topN) == 'table' and type(topN.RankList) == 'table' and #topN.RankList > 0,
    'tTopN.RankList co dong')
check(type(topN.SelfRank) == 'number' and topN.SelfRank >= 1, 'co SelfRank')
check(type(tAll) == 'table' and tAll[topN.RankList[1].Id] ~= nil,
    'moi dong BXH deu co trong tAll')
check(type(APRDATA.challenge) == 'table' and #APRDATA.challenge == 6,
    'ghi 6 doi thu vao GameScoreCompetitivePlay.challenge')
check(type(APRDATA.season_id) == 'string' and APRDATA.season_id ~= '',
    'co season_id')
check(APRDATA.score == 1000 and APRDATA.max_score == 1000, 'diem khoi dau 1000')

--=========================================================== 3. XEM ĐỐI THỦ
io.write('\n-- 3. ViewPlayer: dung GetRobotInfo cua share\n')
local sidRobot = APRDATA.challenge[1].Id
x = goi('G_ScoreCompetitivePlayProtocol.ClientViewPlayerReq', sidRobot)
check(x and x.f == 'ClientViewPlayerRsp' and type(x.args[1]) == 'table', 'xem doi thu -> tra bang')
check(x and type(x.args[1].GameUserBaseInfo) == 'table'
    and type(x.args[1].GameScoreCompetitivePlay) == 'table'
    and type(x.args[1].GameScoreCompetitivePlay.defence) == 'table',
    'du 3 khoi: BaseInfo / ScoreCompetitivePlay / defence')
check(x and type(x.args[1].GameUserHero) == 'table'
    and x.args[1].GameUserHero['25'] ~= nil, 'co du lieu tuong robot (25)')

--=========================================================== 4. BỐN KHOÁ TRẬN
io.write('\n-- 4. bon khoa tran: tu choi 5500, KHONG vao tran\n')
x = goi('G_ScoreCompetitivePlayProtocol.ClientBeginFightReq', { { 56 } }, 1, sidRobot)
check(x and x.f == 'ClientBeginFightRsp' and x.args[1] == 5500, 'BeginFight -> Rsp(5500)')
check(THONG_BAO[#THONG_BAO] == 5500, 'co toast 5500')
x = goi('G_ScoreCompetitivePlayProtocol.ClientEndFightReq', 1, {})
check(x and x.f == 'ClientEndFightRsp' and x.args[1] == nil, 'EndFight -> Rsp(nil, nil)')
x = goi('G_ScoreCompetitivePlayProtocol.ClientRevengeBeginReq', { { 56 } }, 'r_1')
check(x and x.f == 'ClientRevengeBeginRsp' and x.args[1] == 5500, 'RevengeBegin -> 5500')
x = goi('G_ScoreCompetitivePlayProtocol.ClientRevengeEndReq', 'r_1', {})
check(x and x.f == 'ClientRevengeEndRsp', 'RevengeEnd -> Rsp')

--=========================================================== 5. ĐỘI PHÒNG THỦ
io.write('\n-- 5. doi phong thu\n')
x = goi('G_ScoreCompetitivePlayProtocol.ClientAdjustDefTeamReq', { { 56 }, { 57 }, { 58 } })
check(x and x.f == 'ClientAdjustDefTeamRsp' and x.n == 0, 'luu doi -> Rsp() khong tham so')
check(type(APRDATA.defence) == 'table' and #APRDATA.defence == 3,
    'GameScoreCompetitivePlay.defence co 3 doi')
check(APRDATA.defence[1].team[1].hero_id == 56 and APRDATA.defence[1].fight_capacity == 1000,
    'doi 1: hero 56, luc chien 1000')

local nR = #RSP
x = goi('G_ScoreCompetitivePlayProtocol.ClientAdjustDefTeamReq', { { 999 } })
check(#RSP > nR and RSP[#RSP][3] == 5500, 'hero khong co -> OnReciveResponse(5500)')

--=========================================================== 6. THƯỞNG THĂNG BẬC
io.write('\n-- 6. thuong thang bac\n')
APRDATA.max_score = 1000
goi('G_ScoreCompetitivePlayProtocol.ClientGetRankRewardReq', 1)
check(#RSP > 0 and RSP[#RSP][3] == 5503, 'chua dat diem -> 5503')

APRDATA.max_score = 5000
APRDATA.rank_reward = { [1] = 0 }
PRIZE_PHAT = 0
x = goi('G_ScoreCompetitivePlayProtocol.ClientGetRankRewardReq', 1)
check(x and x.f == 'ClientGetRankRewardRsp' and type(x.args[1]) == 'table' and #x.args[1] == 1,
    'nhan thuong bac 1 -> Rsp(danh sach mon)')
check(PRIZE_PHAT == 1 and APRDATA.rank_reward[1] == 1, 'da phat thuong + danh dau da nhan')

nR = #RSP
goi('G_ScoreCompetitivePlayProtocol.ClientGetRankRewardReq', 1)
check(#RSP > nR and RSP[#RSP][3] == 5502, 'nhan lai -> 5502 Rewarded')

nR = #RSP
goi('G_ScoreCompetitivePlayProtocol.ClientGetRankRewardReq', 2)
check(#RSP > nR and RSP[#RSP][3] == 5503, 'bac khong co thuong -> 5503')

--=========================================================== 7. PHỤC HỒI ĐIỂM
io.write('\n-- 7. phuc hoi diem (bac 5: 25 diem / 120 kim cuong)\n')
APRDATA.score = 3800          -- đúng mốc bậc 5
APRDATA.max_score = 4000
BASE.Diamond = 1000
APRDATA.last_recover_day = nil
x = goi('G_ScoreCompetitivePlayProtocol.ClientFailRecoverReq')
check(x and x.f == 'ClientFailRecoverRsp' and x.n == 0, 'phuc hoi -> Rsp()')
check(APRDATA.score == 3825, 'cong 25 diem (3800 -> 3825)', APRDATA.score)
check(BASE.Diamond == 880, 'tru 120 kim cuong', BASE.Diamond)

nR = #RSP
goi('G_ScoreCompetitivePlayProtocol.ClientFailRecoverReq')
check(#RSP > nR and RSP[#RSP][3] == 5503, 'phuc hoi lan 2 trong ngay -> 5503')

--=========================================================== 8. BXH / BÁO CÁO
io.write('\n-- 8. BXH / bao cao / replay\n')
x = goi('G_ScoreCompetitivePlayProtocol.ClientGetRankListReq', 1, 10)
check(x and x.f == 'ClientGetRankListRsp' and type(x.args[1]) == 'table', 'BXH -> bang')
local dem = 0
for _, v in pairs(x.args[1]) do
    dem = dem + 1
    if dem == 1 then
        check(type(v.Rank) == 'number' and type(v.CharacterName) == 'string'
            and type(v.ScoreCompetitiveFightCap) == 'number' and type(v.Portrait) == 'string',
            'dong BXH du truong APRData doc')
    end
end
check(dem == 10, 'lay dung 10 dong', dem)

x = goi('G_ScoreCompetitivePlayProtocol.ClientGetReportReq')
check(x and x.f == 'ClientGetReportRsp' and x.n == 2
    and type(x.args[1]) == 'table' and type(x.args[2]) == 'table', 'bao cao -> 2 bang rong')
x = goi('G_ScoreCompetitivePlayProtocol.ClientGetReplayReq', 'x')
check(x and x.f == 'ClientGetReplayRsp' and type(x.args[1]) == 'table', 'replay -> bang rong')

io.write('\nKET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
