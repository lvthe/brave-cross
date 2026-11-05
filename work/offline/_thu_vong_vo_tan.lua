-- _thu_vong_vo_tan.lua — bộ thử cho `offline/handlers/vong_vo_tan.lua` (9 khoá ải vô tận).
-- Chạy: `python _thu_nha_cua.py _thu_vong_vo_tan.lua`.
--
-- Đo: vào trận (trừ lượt), chúc phúc (giá/trần), kết thúc trận (thưởng + sự kiện),
-- sang tầng, đặt lại (1 lần/ngày), mua lượt, quét theo thời gian và quét ngay.
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

EventManagerLogicEvent = { EndlessChapter = {
    OnSweep = 'OnSweep', OnStopSweep = 'OnStopSweep', OnInspire = 'OnInspire',
    OnCompeleteFight = 'OnCompeleteFight', OnResetEndlessChapter = 'OnReset',
    OnBuyChallengesCount = 'OnBuy', OnSweepImmediately = 'OnSweepNow',
    OnGotoNextProsess = 'OnGotoNext', OnFihgt = 'OnFight',
} }
CUINotificationEvent = { OnServerRequestError = 'OnServerRequestError' }

--=========================================================== TRẠNG THÁI GIẢ
DATA = {
    CurrentProsess = 1, ChallengesCount = 0, PayChallengesCount = 0, ResetCount = 0,
    IsSweeping = false, LastSweepTime = 0, BestProsees = 0, InspireCount = 0,
    SwapBeginTime = 0, FightHeroList = { 25 }, CurrentState = 0, FirstPrizeStates = {},
}
BASE = { Gold = 100000, Diamond = 1000 }
EVENT = {}
THONG_BAO = {}
PRIZE = 0
WIN = true
CO_THE = true

local function levelCfg(cap)
    return { LevelID = cap, PassCondition = 0, PassConditionArgs = 0, PrizeID = 107000 + cap }
end

G_EndlessChapterLogic = {
    MaxChallengesCount = 7, FreeChallengesCount = 2, MaxInspireCount = 3,
    InspireCost = { [1] = 2000, [20] = 50 },
    SwapCostTime = 60, SwapCostDiamondPerFloor = 2, MaxResetCount = 1,
    GetUserEndlessChapterData = function (self) return true, DATA end,
    setUserEndlessChapter = function (self, d) DATA = d; return true end,
    IsCanFight = function (self) return CO_THE, CO_THE and 0 or 1 end,
    IsCompeleteData = function (self, t, n, args) return true, WIN end,
}
G_ConfigManager = { GetEndlessChapterConfig = function (self, cap) return levelCfg(cap) end }
G_PrizeLogic = { GetPrizeWithID = function (self, id)
    return true, { PrizeContent = { { PrizeResType = 2, PropID = 1, PrizeResCount = 10 } } }
end }
G_ChapterLogic = { SetDataWithPrizeList = function (self, ds, n, from) PRIZE = PRIZE + 1; return true end }
G_UserLogic = {
    CostGold = function (self, n)
        if BASE.Gold < n then return false, BASE.Gold end
        BASE.Gold = BASE.Gold - n; return true, BASE.Gold
    end,
    CostDiamond = function (self, n)
        if BASE.Diamond < n then return false, BASE.Diamond end
        BASE.Diamond = BASE.Diamond - n; return true, BASE.Diamond
    end,
}
G_EventManager = { PostLogicEvent = function (self, d, ten) EVENT[#EVENT + 1] = { data = d, name = ten } end }
g_CUINotificationCenter = {
    PostNotification = function (self, ev, ma) THONG_BAO[#THONG_BAO + 1] = ma end,
}
g_CUIGameRPCManager = {}
RSP = {}
function g_CUIGameRPCManager:OnReciveResponse(...)
    RSP[#RSP + 1] = { n = select('#', ...), ... }
end

dofile([[__SC__/offline/handlers/vong_vo_tan.lua]])
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
    -- Ưu tiên lời gọi HÀM NHẬN (không phải OnReciveResponse) — handler thường
    -- gọi hàm nhận rồi mới dọn lớp tải, nên "lời gọi cuối" luôn là dọn lớp.
    for _, v in ipairs(c.calls) do
        if v.obj ~= 'g_CUIGameRPCManager' then return v, c end
    end
    return c.calls[#c.calls], c
end

--=========================================================== 1. ĐĂNG KÝ
io.write('\n-- 1. dang ky 9 khoa\n')
local KHOA = {
    'ClientFight', 'ClientCompeleteFight', 'ClientGotoNextProsees', 'ClientInspire',
    'ClientResetEndlessChapter', 'ClientBuyChallengesCount', 'ClientSwap',
    'ClientStopSwap', 'ClientSwapImmediately',
}
local thieu = {}
for _, k in ipairs(KHOA) do
    if not R:has('G_EndlessChapterLogic.' .. k) then thieu[#thieu + 1] = k end
end
check(#thieu == 0, 'dang ky DU 9 khoa', table.concat(thieu, ', '))

--=========================================================== 2. VÀO TRẬN
io.write('\n-- 2. vao tran\n')
local x = goi('G_EndlessChapterLogic.ClientFight', { 25, 26 }, { Foo = 1 })
check(x and x.f == 'OnFight' and x.n == 3, 'Fight -> OnFight(heroList, inspire, employ) BA tham so')
check(x and x.args[1][1] == 25 and x.args[2] == 0, 'tra danh sach tuong + inspire 0')
check(DATA.ChallengesCount == 1, 'tang ChallengesCount 1')
check(DATA.FightHeroList[2] == 26, 'luu FightHeroList')

CO_THE = false
x = goi('G_EndlessChapterLogic.ClientFight', { 25 })
check(x and x.f == 'OnReciveResponse' and x.args[3] == 1, 'IsCanFight tu choi -> OnReciveResponse(1)')
CO_THE = true

--=========================================================== 3. CHÚC PHÚC
io.write('\n-- 3. chuc phuc\n')
BASE.Gold = 100000
DATA.InspireCount = 0
goi('G_EndlessChapterLogic.ClientInspire', 1)
check(DATA.InspireCount == 1 and BASE.Gold == 98000, 'chuc phuc vang -2000, lan 1')
check(EVENT[#EVENT].name == 'OnInspire' and EVENT[#EVENT].data == true, 'phat OnInspire(true)')

DATA.InspireCount = 3
BASE.Diamond = 1000
goi('G_EndlessChapterLogic.ClientInspire', 20)
check(DATA.InspireCount == 3 and BASE.Diamond == 1000, 'da du 3 lan -> KHONG tru, khong tang')

DATA.InspireCount = 0
BASE.Diamond = 10
goi('G_EndlessChapterLogic.ClientInspire', 20)
check(THONG_BAO[#THONG_BAO] == 504, 'thieu kim cuong -> toast 504')
check(EVENT[#EVENT].data == false, 'phat OnInspire(false)')

--=========================================================== 4. KẾT THÚC TRẬN
io.write('\n-- 4. ket thuc tran\n')
DATA.CurrentProsess = 1
DATA.CurrentState = 0
DATA.BestProsees = 0
WIN = true
PRIZE = 0
EVENT = {}
x = goi('G_EndlessChapterLogic.ClientCompeleteFight', { IsDestroyAllEnemy = true })
check(x and x.f == 'OnReciveResponse', 'ket thuc -> don lop tai')
check(DATA.CurrentState == 1 and DATA.BestProsees == 1, 'thang: CurrentState=1, Best=1')
check(PRIZE == 1, 'da phat thuong tang 1')
check(EVENT[#EVENT].name == 'OnCompeleteFight' and EVENT[#EVENT].data.IsWin == true
    and EVENT[#EVENT].data.PrizeID == 107001, 'su kien IsWin + PrizeID 107001')

WIN = false
DATA.CurrentProsess = 2
x = goi('G_EndlessChapterLogic.ClientCompeleteFight', {})
check(EVENT[#EVENT].data.IsWin == false and EVENT[#EVENT].data.PrizeID == 0,
    'thua: IsWin=false, PrizeID=0')

--=========================================================== 5. SANG TẦNG
io.write('\n-- 5. sang tang\n')
DATA.CurrentProsess = 1
DATA.CurrentState = 0
DATA.ChallengesCount = 5
DATA.InspireCount = 2
EVENT = {}
goi('G_EndlessChapterLogic.ClientGotoNextProsees')
check(DATA.CurrentProsess == 1, 'chua thang -> KHONG sang tang')
check(#EVENT == 0, 'chua thang: khong phat su kien')

DATA.CurrentState = 1
goi('G_EndlessChapterLogic.ClientGotoNextProsees')
check(DATA.CurrentProsess == 2 and DATA.CurrentState == 0, 'thang -> sang tang 2')
check(DATA.ChallengesCount == 0 and DATA.InspireCount == 0, 'sang tang: dat lai luot + chuc phuc')
check(EVENT[#EVENT].name == 'OnGotoNext', 'phat OnGotoNextProsess')

--=========================================================== 6. ĐẶT LẠI
io.write('\n-- 6. dat lai: 1 lan/ngay\n')
DATA.CurrentProsess = 3
DATA.ResetDay = nil
EVENT = {}
goi('G_EndlessChapterLogic.ClientResetEndlessChapter')
check(DATA.CurrentProsess == 1, 'dat lai -> ve tang 1')
check(DATA.ResetDay ~= nil, 'ghi khoa ngay')
check(EVENT[#EVENT].name == 'OnReset', 'phat OnResetEndlessChapter')

local ngayCu = DATA.ResetDay
DATA.CurrentProsess = 4
goi('G_EndlessChapterLogic.ClientResetEndlessChapter')
check(DATA.CurrentProsess == 4, 'cung ngay -> KHONG dat lai lan 2')
DATA.ResetDay = nil

--=========================================================== 7. MUA LƯỢT
io.write('\n-- 7. mua luot danh\n')
DATA.PayChallengesCount = 0
BASE.Diamond = 1000
goi('G_EndlessChapterLogic.ClientBuyChallengesCount')
check(DATA.PayChallengesCount == 1 and BASE.Diamond == 950, 'mua 1 luot -50 kim cuong')
DATA.PayChallengesCount = 5
BASE.Diamond = 1000
goi('G_EndlessChapterLogic.ClientBuyChallengesCount')
check(DATA.PayChallengesCount == 5 and BASE.Diamond == 1000, 'da du 5 luot -> khong tru')

--=========================================================== 8. QUÉT
io.write('\n-- 8. quet theo thoi gian\n')
DATA.CurrentProsess = 2
DATA.BestProsees = 5
DATA.CurrentState = 1
EVENT = {}
PRIZE = 0
x = goi('G_EndlessChapterLogic.ClientSwap')
check(x and x.f == 'OnSwap', 'bat dau quet -> OnSwap')
check((DATA.SwapBeginTime or 0) > 0 and DATA.IsSweeping == true, 'co SwapBeginTime')

DATA.SwapBeginTime = os.time() - 130     -- 2 tầng (60s/tầng)
x = goi('G_EndlessChapterLogic.ClientStopSwap')
check(x and x.f == 'OnStopSwap' and type(x.args[1]) == 'table' and #x.args[1] == 2,
    'dung quet -> 2 tang thuong')
check(DATA.CurrentProsess == 4, 'tang 2 -> 4 (quet 2 tang)', DATA.CurrentProsess)
check(DATA.SwapBeginTime == 0 and DATA.IsSweeping == false, 'tat phien quet')
check(PRIZE == 2, 'phat 2 thuong tang', PRIZE)

--=========================================================== 9. QUÉT NGAY
io.write('\n-- 9. quet ngay\n')
DATA.CurrentProsess = 4
DATA.BestProsees = 6
BASE.Diamond = 1000
PRIZE = 0
local nR = #RSP
x = goi('G_EndlessChapterLogic.ClientSwapImmediately')
check(x and x.f == 'OnStopSwap' and #x.args[1] == 3, 'quet ngay -> 3 tang (4,5,6)')
check(BASE.Diamond == 994, 'gia 3 x 2 = 6 kim cuong', BASE.Diamond)
check(DATA.CurrentProsess == 7, 'xong -> tang 7 (Best + 1)', DATA.CurrentProsess)
check(#RSP > nR, 'co don lop tai')

BASE.Diamond = 1
DATA.CurrentProsess = 7
DATA.BestProsees = 9
nR = #RSP
goi('G_EndlessChapterLogic.ClientSwapImmediately')
check(THONG_BAO[#THONG_BAO] == 504 and DATA.CurrentProsess == 7, 'thieu kim cuong -> khong quet')

io.write('\nKET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
