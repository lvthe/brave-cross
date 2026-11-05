-- _thu_epic.lua — bộ thử cho `offline/handlers/epic.lua` (5 khoá chiến dịch anh hùng).
-- Chạy: `python _thu_nha_cua.py _thu_epic.lua`.
--
-- Đo: chọn phe/độ khó theo lịch mở thật, đặt lại ngày, kết thúc trận với CHỮ KÝ THẬT
-- bốn tham số (bComplete đứng đầu), quét danh vọng MỘT LẦN mỗi tầng, và shop EpicCoin.
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

ErrorCode = { Shop = { NotEnoughCurrency = 1901 } }
CUINotificationEvent = { OnServerRequestError = 'OnServerRequestError' }

--=========================================================== TRẠNG THÁI GIẢ
EPIC = {}
OPEN = { [1] = true, [2] = false, [3] = false, [4] = false }
PRIZE = 0
THONG_BAO = {}
RSP = {}
EVENT = {}
-- 180 dòng cấu hình: chỉ cần vài dòng để đo; ChapterID = "<camp>_<diff>_<level>".
CFG_BY_ID = {}
CFG_V2 = {}
for camp = 1, 4 do
    for diff = 1, 3 do
        CFG_V2[camp] = CFG_V2[camp] or {}
        CFG_V2[camp][diff] = {}
        for level = 1, 9 do
            local id = string.format('%d_%d_%d', camp, diff, level)
            local row = {
                ChapterID = id, HeroFactions = camp, Difficulty = diff, LevelID = level,
                PrizeID = 286 + level, HeroFactionsPrestigeReward = 6,
            }
            CFG_BY_ID[id] = row
            CFG_V2[camp][diff][level] = row
        end
    end
end
GOODS = { ['1'] = { PrizeID = 220001, cost = 15000 }, ['2'] = { PrizeID = 220002, cost = 100 } }

G_DataManager = {
    GetUserDataWithName = function (self, ten) return 0, EPIC end,
    SetUserDataWithName = function (self, ten, t) EPIC = t; return true end,
}
G_ConfigManager = {
    IsEpicOpen = function (self, camp) return OPEN[tonumber(camp)] end,
    GetEpicChapterConfig = function (self, id) return CFG_BY_ID[tostring(id)] end,
    GetEpicChapterConfigV2 = function (self, camp, diff, level)
        local a = CFG_V2[tonumber(camp)]
        return a and a[tonumber(diff)] and a[tonumber(diff)][tonumber(level)] or nil
    end,
    -- Ngưỡng danh vọng luỹ kế: cấp 1 = 10, cấp 2 = 25, … cấp n = 10 + 15(n-1).
    GetHeroFactionsPrestigeLevel = function (self, exp)
        local cap = 0
        for n = 1, 200 do
            if (10 + 15 * (n - 1)) > (tonumber(exp) or 0) then return n - 1 end
            cap = n
        end
        return cap
    end,
    GetCommonConfigWithName = function (self, ten)
        if ten == 'GameEpicChapterGoodsConfig' then return GOODS end
        return nil
    end,
}
G_PrizeLogic = {
    GetPrizeWithID = function (self, id)
        return true, { PrizeContent = { { PrizeResType = 2, PropID = 1, PrizeResCount = 1 } } }
    end,
}
G_ChapterLogic = { SetDataWithPrizeList = function (self, ds, n, from) PRIZE = PRIZE + 1; return true end }
G_EventManager = { PostLogicEvent = function (self, d, ten) EVENT[#EVENT + 1] = ten end }
g_CUINotificationCenter = {
    PostNotification = function (self, ev, ma) THONG_BAO[#THONG_BAO + 1] = ma end,
}
g_CUIGameRPCManager = {}
function g_CUIGameRPCManager:OnReciveResponse(...)
    RSP[#RSP + 1] = { n = select('#', ...), ... }
end

dofile([[__SC__/offline/handlers/epic.lua]])
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
    for _, v in ipairs(c.calls) do
        if v.obj ~= 'g_CUIGameRPCManager' then return v, c end
    end
    return c.calls[#c.calls], c
end

--=========================================================== 1. ĐĂNG KÝ
io.write('\n-- 1. dang ky 5 khoa\n')
local KHOA = {
    'ClientSetTodayChapterDifficult', 'ClientEpicResetDaily', 'ClientEpicChapterCompeleteFight',
    'ClientSweepEpicChapter', 'ClientBuyEpicGoods',
}
local thieu = {}
for _, k in ipairs(KHOA) do
    if not R:has('G_EpicChapterLogic.' .. k) then thieu[#thieu + 1] = k end
end
check(#thieu == 0, 'dang ky DU 5 khoa', table.concat(thieu, ', '))

--=========================================================== 2. CHỌN PHE / ĐỘ KHÓ
io.write('\n-- 2. chon phe / do kho\n')
local x = goi('G_EpicChapterLogic.ClientSetTodayChapterDifficult', 2, 1)
check(x and x.obj == 'g_EpicChapterLogic' and x.f == 'OnClientSetTodayChapterDifficult'
    and x.args[1] == 1, 'phe dong hom nay -> ma 1')

x = goi('G_EpicChapterLogic.ClientSetTodayChapterDifficult', 1, 9)
check(x and x.args[1] == 1, 'do kho 9 > 1 -> ma 1')

x = goi('G_EpicChapterLogic.ClientSetTodayChapterDifficult', 1, 1)
check(x and x.args[1] == 0, 'phe 1 mo, do kho 1 -> ma 0')
check(EPIC.TodayChapterInfo.FightFaction == 1 and EPIC.TodayChapterInfo.Diffculty == 1,
    'luu TodayChapterInfo')
check(EPIC.PassedChapterInfo['1'].Difficulty == 1, 'do kho mo san = 1')

--=========================================================== 3. KẾT THÚC TRẬN
io.write('\n-- 3. ket thuc tran (bComplete dung DAU)\n')
PRIZE = 0
x = goi('G_EpicChapterLogic.ClientEpicChapterCompeleteFight', true, '1_1_3', { 25 }, nil)
check(x and x.f == 'OnEpicChapterCompeleteFight' and x.args[1].IsWin == true
    and x.args[1].PrizeID == 289, 'thang: IsWin + PrizeID 289 (286+3)')
check(PRIZE == 1, 'da phat thuong ai')
check(EPIC.TodayMaxPassedLevel == 3, 'ghi TodayMaxPassedLevel = 3', EPIC.TodayMaxPassedLevel)
check(EPIC.Prestige['1'].Exp == 6, 'cong 6 danh vong', EPIC.Prestige['1'].Exp)

x = goi('G_EpicChapterLogic.ClientEpicChapterCompeleteFight', false, '1_1_4', { 25 }, nil)
check(x and x.args[1].IsWin == false and x.args[1].PrizeID == 0, 'thua: IsWin=false, PrizeID=0')
check(EPIC.TodayMaxPassedLevel == 3, 'thua: KHONG tang tien do')

-- Qua màn 9 ⇒ mở độ khó kế.
goi('G_EpicChapterLogic.ClientEpicChapterCompeleteFight', true, '1_1_9', { 25 }, nil)
check(EPIC.PassedChapterInfo['1'].Difficulty == 2, 'qua man 9 -> mo do kho 2',
    EPIC.PassedChapterInfo['1'].Difficulty)

--=========================================================== 4. QUÉT
io.write('\n-- 4. quet danh vong (mot lan moi tang)\n')
EPIC.TodayMaxPassedLevel = 3
EPIC.SweptMaxLevel = 0
EPIC.Prestige['1'] = { Level = 0, Exp = 0 }
x = goi('G_EpicChapterLogic.ClientSweepEpicChapter', 1, 1)
local soTang = 0
for _ in pairs(x.args[1]) do soTang = soTang + 1 end
check(soTang == 3 and x.args[1][1] == 6 and x.args[1][3] == 6, 'quet 3 tang, moi tang 6')
check(EPIC.Prestige['1'].Exp == 18, 'cong 18 danh vong', EPIC.Prestige['1'].Exp)
check(EPIC.SweptMaxLevel == 3, 'ghi moc da quet 3')

x = goi('G_EpicChapterLogic.ClientSweepEpicChapter', 1, 1)
local lai = 0
for _ in pairs(x.args[1]) do lai = lai + 1 end
check(lai == 0 and EPIC.Prestige['1'].Exp == 18, 'quet lan 2 -> rong, khong cong lai')

--=========================================================== 5. SHOP
io.write('\n-- 5. shop EpicCoin\n')
EPIC.EpicCoin = 20000
PRIZE = 0
local nR = #RSP
x = goi('G_EpicChapterLogic.ClientBuyEpicGoods', 1)
check(EPIC.EpicCoin == 5000 and PRIZE == 1, 'mua mon 1 (-15000, con 5000)')
check(#RSP > nR and RSP[#RSP][3] == 0, 'don lop tai voi ma 0')

EPIC.EpicCoin = 50
PRIZE = 0
nR = #RSP
goi('G_EpicChapterLogic.ClientBuyEpicGoods', 1)
check(#RSP > nR and RSP[#RSP][3] == 1901, 'thieu EpicCoin -> 1901')
check(EPIC.EpicCoin == 50 and PRIZE == 0, 'thieu tien: KHONG tru, KHONG phat')

--=========================================================== 6. ĐẶT LẠI NGÀY
io.write('\n-- 6. dat lai ngay\n')
x = goi('G_EpicChapterLogic.ClientEpicResetDaily')
check(x and x.f == 'OnEpicResetDaily' and x.n == 0, 'dat lai -> OnEpicResetDaily()')
check(EPIC.TodayMaxPassedLevel == 0 and EPIC.SweptMaxLevel == 0, 'xoa tien do + moc quet')

io.write('\nKET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
