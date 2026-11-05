-- _thu_ai_dac_biet.lua — bộ thử cho `offline/handlers/ai_dac_biet.lua`
-- (16 khoá chế độ ải đặc biệt). Chạy: `python _thu_nha_cua.py _thu_ai_dac_biet.lua`.
--
-- Đo: đăng ký 16 khoá, 7 khoá KẾT THÚC đi qua máy结算 GỐC (`activityChapterComplete`)
-- và trả đúng hàm nhận; 4 khoá CÀN QUÉT gác 1435 khi chưa qua ải rồi gọi
-- `chapterSweepHandle`; 5 tiện ích (rơi/NPC/phe/hồi sinh/sóng HJRQ).
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

ErrorCode = {
    Chapter = {
        CanNotFoundConfig = 1404, NotCrossCantSweep = 1435, SavePrizeDataError = 1409,
    },
}
EventManagerLogicEvent = { Chapter = { OnReviveInBattle = 'OnReviveInBattle' } }
CUINotificationEvent = { OnServerRequestError = 'OnServerRequestError' }

--=========================================================== TRẠNG THÁI GIẢ
DA_QUA = { FB_E_HJRQ = true, FB_E_SYZLB = true, FB_E_SCSZL = false, FB_TGZZ = true, FB_DK = true }
STATS = { MaxHJRQBatchCount = 3 }
BASE = { Diamond = 1000 }
REVIVE = 0
EVENT = {}
THONG_BAO = {}
RSP = {}
PRIZE_DA_PHAT = 0

DS_AI = {
    [3] = { { ChapterKey = 'FB_E_HJRQ' } },
    [4] = { { ChapterKey = 'FB_E_SCSZL' } },
    [5] = { { ChapterKey = 'FB_E_SYZLB' } },
    [6] = { { ChapterKey = 'FB_E_DJSJF' } },
    [7] = { { ChapterKey = 'FB_E_XZWC' } },
    [8] = { { ChapterKey = 'FB_E_PETBOSS' } },
    [13] = { { ChapterKey = 'FB_TGZZ' } },
    [14] = { { ChapterKey = 'FB_DK' } },
}
CFG = {}
for _, t in ipairs({ 3, 4, 5, 6, 7, 8, 13, 14 }) do
    local k = DS_AI[t][1].ChapterKey
    CFG[k] = { ChapterKey = k, ChapterType = t, ChapterUserEx = 0, ChapterUserFatigue = 0 }
end

OfflineDrop_build = function (key)
    return { DropConfig = {}, Drop = { { Id = 'x' } } }
end

G_ConfigManager = {
    GetChapterConfig = function (self, k) return CFG[tostring(k)] end,
}
G_UserLogic = {
    GetStatisticsCommonData = function (self, k) return true, STATS[k] end,
    SetStatisticsCommonData = function (self, k, v) STATS[k] = v; return true end,
    CostDiamond = function (self, n)
        if BASE.Diamond < n then return false, BASE.Diamond end
        BASE.Diamond = BASE.Diamond - n
        return true, BASE.Diamond
    end,
}
G_UserLogicDataManager = {
    GetChapterReviveCount = function (self) return true, REVIVE end,
    SetChapterReviveCount = function (self, n) REVIVE = n; return true end,
}
G_EventManager = {
    PostLogicEvent = function (self, d, ten) EVENT[#EVENT + 1] = ten end,
}
g_CUINotificationCenter = {
    PostNotification = function (self, ev, ma) THONG_BAO[#THONG_BAO + 1] = ma end,
}
g_CUIGameRPCManager = {}
function g_CUIGameRPCManager:OnReciveResponse(...)
    RSP[#RSP + 1] = { n = select('#', ...), ... }
end

G_ChapterLogic = {
    activityChapterComplete = function (self, key, drop, kills, dmg)
        if key == 'FB_E_SCSZL' then return false, 1404 end
        return true, 0, { DropConfig = {}, Drop = { { Id = 'k1' } } }, 10, 5, 3,
            { { PrizeResType = 2, PropID = 1, PrizeResCount = 1 } }
    end,
    chapterSweepHandle = function (self, cfg, ex, drop, rating, sweep, from)
        return true, 0, drop, { { PrizeResType = 2, PropID = 2, PrizeResCount = 1 } }, 20, 4
    end,
    CheckChapterIsPass = function (self, key) return true, DA_QUA[tostring(key)] == true end,
    GetChapterListByChapterType = function (self, t) return DS_AI[t] or {} end,
    filterKillDropList = function (self, kills, drop) return true, drop end,
    GetTGZZChapterLevel = function (self) return true, 3, 10 end,
    GetDKChapterLevel = function (self) return true, 2, 10 end,
    GetTGZZChapterPrize = function (self, cap, pct)
        return { { PrizeResType = 2, PropID = 9, PrizeResCount = math.ceil(10 * cap * pct) } }
    end,
    GetDKChapterPrize = function (self, cap, pct)
        return { { PrizeResType = 2, PropID = 8, PrizeResCount = math.ceil(5 * cap * pct) } }
    end,
    SetDataWithPrizeList = function (self, ds, n, from)
        PRIZE_DA_PHAT = PRIZE_DA_PHAT + 1
        return true
    end,
    GetChapterReviveCost = function (self, n) return 50 * (n + 1) end,
}

dofile([[__SC__/offline/handlers/ai_dac_biet.lua]])
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
        if obj == 'g_CUIGameRPCManager' then
            local o = _G[obj]
            if type(o) == 'table' and type(o[f]) == 'function' then o[f](o, ...) end
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
io.write('\n-- 1. dang ky 16 khoa\n')
local KHOA = {
    'ClientChapterHJRQComplete', 'ClientChapterSCSComplete', 'ClientChapterDJSJFComplete',
    'ClientChapterXZWCComplete', 'ClientChapterTGZZComplete', 'ClientChapterPetBossComplete',
    'ClientChapterDKComplete', 'ClientChapterTGZZSweep', 'ClientChapterDKSweep',
    'ClientChapterHJRQSweep', 'ClientChapterSYZLBAndXZWCSweep', 'ClientGetChapterDropData',
    'ClientGetSCSChapterNPCData', 'ClientGetDKChapterFaction', 'ClientReviveInBattle',
    'ClientUserOverHJRQ',
}
local thieu = {}
for _, k in ipairs(KHOA) do
    if not R:has('G_ChapterLogic.' .. k) then thieu[#thieu + 1] = k end
end
check(#thieu == 0, 'dang ky DU 16 khoa', table.concat(thieu, ', '))

--=========================================================== 2. KẾT THÚC
io.write('\n-- 2. 7 khoa ket thuc\n')
local function ketThuc(khoa, key, hamNhan, ...)
    local x = goi(khoa, key, { ChapterData = { KillIdList = { 'a' }, DamageCount = 100,
        BatchCount = 7 }, DamagePercent = 0.5 })
    check(x and x.f == hamNhan, khoa .. ' -> ' .. hamNhan, x and x.f)
    return x
end

local x = ketThuc('G_ChapterLogic.ClientChapterHJRQComplete', 'FB_E_HJRQ', 'OnServerChapterHJRQComplete')
check(x and x.args[1].ChapterKey == 'FB_E_HJRQ' and type(x.args[1].KillDropList) == 'table',
    'HJRQ: tra ChapterKey + KillDropList')
check(STATS.MaxHJRQBatchCount == 7, 'HJRQ: ghi ky luc song 3 -> 7', STATS.MaxHJRQBatchCount)
check(x and x.args[1].AddDropGold == 8, 'HJRQ: AddDropGold = 5 + 3', x and x.args[1].AddDropGold)

ketThuc('G_ChapterLogic.ClientChapterDJSJFComplete', 'FB_E_DJSJF', 'OnServerChapterDJSJFComplete')
ketThuc('G_ChapterLogic.ClientChapterXZWCComplete', 'FB_E_XZWC', 'OnServerChapterXZWCComplete')
ketThuc('G_ChapterLogic.ClientChapterPetBossComplete', 'FB_E_PETBOSS', 'OnChapterPetBossComplete')

x = ketThuc('G_ChapterLogic.ClientChapterTGZZComplete', 'FB_TGZZ', 'OnChapterTGZZComplete')
check(x and type(x.args[1].PrizeList) == 'table' and x.args[1].PrizeList[1].PrizeResCount == 15,
    'TGZZ: thuong rieng 10×3×0.5 = 15')
check(x and x.args[1].DamagePercent == 0.5, 'TGZZ: giu DamagePercent')

-- DK: GỬI MỘT THAM SỐ — khoá ải lấy trong dữ liệu / ải duy nhất.
x = goi('G_ChapterLogic.ClientChapterDKComplete', { ChapterData = { KillIdList = {}, DamagePercent = 1 } })
check(x and x.f == 'OnChapterDKComplete' and x.args[1].ChapterKey == 'FB_DK',
    'DK: mot tham so -> tu tim ai FB_DK', x and x.args[1] and x.args[1].ChapterKey)

-- Thất bại: máy结算 gốc từ chối -> báo lỗi qua OnReciveResponse.
local nR = #RSP
goi('G_ChapterLogic.ClientChapterSCSComplete', 'FB_E_SCSZL', { ChapterData = { KillIdList = {} } })
check(#RSP > nR and RSP[#RSP][3] == 1404, 'SCS that bai -> OnReciveResponse(1404)')

--=========================================================== 3. CÀN QUÉT
io.write('\n-- 3. bon khoa can quet\n')
DA_QUA.FB_E_SCSZL = false
-- Chưa qua ải: HJRQ sweep dùng khoá chưa qua.
DA_QUA.FB_E_HJRQ = false
nR = #RSP
goi('G_ChapterLogic.ClientChapterHJRQSweep', 'FB_E_HJRQ')
check(#RSP > nR and RSP[#RSP][3] == 1435, 'HJRQ chua qua -> 1435 NotCrossCantSweep')
DA_QUA.FB_E_HJRQ = true

x = goi('G_ChapterLogic.ClientChapterHJRQSweep', 'FB_E_HJRQ')
check(x and x.f == 'OnServerChapterHJRQSweep' and x.args[1].ChapterKey == 'FB_E_HJRQ'
    and type(x.args[1].DropList) == 'table', 'HJRQ can quet -> tData.ChapterKey + DropList')

x = goi('G_ChapterLogic.ClientChapterSYZLBAndXZWCSweep', 'FB_E_SYZLB')
check(x and x.f == 'OnChapterSYZLBAndXZWCSweep' and x.args[1].ChapterKey == 'FB_E_SYZLB',
    'SYZLB/XZWC can quet -> tData')

x = goi('G_ChapterLogic.ClientChapterTGZZSweep')
check(x and x.f == 'OnChapterTGZZSweep' and type(x.args[1]) == 'table'
    and x.args[1][1].PrizeResCount == 30, 'TGZZ can quet -> thuong 10×3 = 30', x and x.args[1][1].PrizeResCount)

x = goi('G_ChapterLogic.ClientChapterDKSweep')
check(x and x.f == 'OnChapterDKSweep' and x.args[1][1].PrizeResCount == 10,
    'DK can quet -> thuong 5×2 = 10', x and x.args[1][1].PrizeResCount)

--=========================================================== 4. TIỆN ÍCH
io.write('\n-- 4. nam tien ich\n')
x = goi('G_ChapterLogic.ClientGetChapterDropData', 'FB_E_HJRQ')
check(x and x.f == 'OnServerGetChapterDropData' and x.args[1].ChapterKey == 'FB_E_HJRQ'
    and type(x.args[1].DropList) == 'table', 'xem truoc roi -> DropList')

x = goi('G_ChapterLogic.ClientGetSCSChapterNPCData', { 1, 2 })
check(x and x.f == 'OnServerGetSCSChapterNPCData' and type(x.args[1].NpcList) == 'table',
    'SCS NPC -> NpcList (bang)')

x = goi('G_ChapterLogic.ClientGetDKChapterFaction')
check(x and x.f == 'OnGetDKChapterFaction' and x.n == 3 and x.args[1] == 0 and x.args[2] == 1
    and type(x.args[3]) == 'number', 'phe DK -> (0, phe 1, thoi gian)')

BASE.Diamond = 1000
REVIVE = 0
EVENT = {}
goi('G_ChapterLogic.ClientReviveInBattle')
check(BASE.Diamond == 950, 'hoi sinh lan 1 tru 50 kim cuong', BASE.Diamond)
check(REVIVE == 1, 'tang ChapterReviveCount len 1')
check(#EVENT > 0 and EVENT[#EVENT] == 'OnReviveInBattle', 'phat su kien OnReviveInBattle')

BASE.Diamond = 10
goi('G_ChapterLogic.ClientReviveInBattle')
check(THONG_BAO[#THONG_BAO] == 504, 'thieu kim cuong -> 504')
check(REVIVE == 1, 'thieu kim cuong: KHONG tang bo dem')

STATS.MaxHJRQBatchCount = 3
goi('G_ChapterLogic.ClientUserOverHJRQ', 9, 'FB_E_HJRQ')
check(STATS.MaxHJRQBatchCount == 9, 'HJRQ vuot 9 song -> ghi 9')
goi('G_ChapterLogic.ClientUserOverHJRQ', 5, 'FB_E_HJRQ')
check(STATS.MaxHJRQBatchCount == 9, 'song thap hon -> KHONG lui ky luc')

io.write('\nKET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
