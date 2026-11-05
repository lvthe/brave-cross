-- _thu_quy_hoat_dong.lua — bộ thử cho `offline/handlers/quy_hoat_dong.lua`
-- (chạy bằng `python _thu_nha_cua.py _thu_quy_hoat_dong.lua`).
--
-- Bộ thử nạp LUÔN `offline/hoat_dong.lua` THẬT (qua `require`) để đo cả chỗ nối.
-- KHÔNG thử ở đây: luật gốc `IsCanBuyFund` (máy Lua trần không có `share/`) —
-- bộ này giả lập nó và chỉ đo ĐƯỜNG DÂY + cách ghi trạng thái của handler.
package.path = [[__SC__/?.lua;__SC__/?/init.lua;]] .. package.path

local function ghi(m) io.write('[log] ' .. tostring(m) .. '\n') end
package.preload['offline.log'] = function ()
    local L = { info = ghi, warn = ghi, err = ghi }; OfflineLog = L; return L
end
package.preload['offline.store'] = function ()
    local S = { TABLES = {}, data = {}, dirty = false }
    function S:syncFromClient() self.dongBo = (self.dongBo or 0) + 1 end
    OfflineStore = S; return S
end
package.preload['offline.router'] = function ()
    local R = { handlers = {} }
    function R:on(k, f) self.handlers[k] = f end
    function R:has(k) return self.handlers[k] ~= nil end
    OfflineRouter = R; return R
end

-- ============================================================ LỚP CHA GIẢ
ActivityFund = {}

local TOAN_CUC = {}                 -- GameUserGlobalData giả
local DA_MUA = { LevelFund = false, TimeFund = false }

function ActivityFund:IsCanBuyFund(strFundType, tConfig)
    return self.CAN, self.CAN_MA
end

function ActivityFund:IsBuyFund(strFundType)
    return true, DA_MUA[strFundType] == true
end

function ActivityFund:GetPrizeCount(strFundType)
    return true, TOAN_CUC['ActivityFoudGetCount_' .. strFundType] or 0
end

function ActivityFund:GetIsGetTimeFundToday()
    return true, TOAN_CUC.IsGetTimeFundToday == true
end

function ActivityFund:getBuyFundKey(strFundType)
    return 'HasBuyActivityFoud_' .. strFundType
end

function ActivityFund:getFundCountKey(strFundType)
    return 'ActivityFoudGetCount_' .. strFundType
end

ClientActivityFund = {}
G_ActivityFund = setmetatable({}, { __index = ActivityFund })
G_ActivityFund[ActivityFund] = ActivityFund

-- ---------------------------------------------------------- API giả
local daTru = { diamond = 0 }
G_UserLogic = {}
function G_UserLogic:GetLevel() return true, 30 end
function G_UserLogic:CostDiamond(n) daTru.diamond = daTru.diamond + n; return true end

G_UserDataManager = {}
function G_UserDataManager:GetUserGlobalData(k) return 0, TOAN_CUC[k] end
function G_UserDataManager:SetUserGlobalData(k, v) TOAN_CUC[k] = v; return true end

local DA_PHAT = {}
G_PrizeLogic = {}
function G_PrizeLogic:ReceivePrizeWithID(id)
    DA_PHAT[#DA_PHAT + 1] = id
    return true
end

G_ConfigManager = {}
G_ConfigManager.CAU_HINH = {
    ActivityLevelFundConfig = {
        { Level = 25, PrizeID = 109101 },
        { Level = 30, PrizeID = 109102 },
        { Level = 35, PrizeID = 109103 },
    },
    ActivityTimeFundConfig = {
        { Day = 1, PrizeID = 10001 },
    },
}
function G_ConfigManager:GetCommonConfigWithName(ten)
    return self.CAU_HINH[ten]
end

local SU_KIEN = {}
G_EventManager = {}
function G_EventManager:PostLogicEvent(duLieu, ten)
    SU_KIEN[#SU_KIEN + 1] = { ten = ten, duLieu = duLieu }
end
EventManagerLogicEvent = { Active = { OnBuyActivityFund = 'OnBuyActivityFund' } }

G_ActivityLogic = {}
G_ActivityLogic.MO = true
G_ActivityLogic.CAU_HINH = {
    LevelFund = { Diamond = 500, VipLevel = 0, Level = 1 },
    TimeFund = { Diamond = 300, VipLevel = 0, Level = 1 },
}
function G_ActivityLogic:GetActivityConfigWithType(t) return self.CAU_HINH[t] end
function G_ActivityLogic:CheckActivityIsOpenWithType(t) return self.MO end

G_GameWorld = {}
function G_GameWorld:GetServerTime() return 1700000000 end

dofile([[__SC__/offline/handlers/quy_hoat_dong.lua]])
local R = require('offline.router')

local dat, hong = 0, 0
local function check(ok, ten, ct)
    if ok then dat = dat + 1; io.write('  OK   ' .. ten .. '\n')
    else hong = hong + 1; io.write('  HONG ' .. ten .. (ct ~= nil and (' -> ' .. tostring(ct)) or '') .. '\n') end
end
local function ctxGia()
    local c = { calls = {} }
    function c:call(obj, f, ...)
        self.calls[#self.calls + 1] = { obj = obj, f = f, args = { ... } }
    end
    return c
end
local function demMa(c)
    local x = c.calls[#c.calls]
    return x and x.args[3]
end

local MUA = 'G_ActivityFund.ClientBuyActivityFund'
local CAP = 'G_ActivityFund.ClientGetLevelFundPrize'
local TG  = 'G_ActivityFund.ClientGetTimeFundPrize'

check(R:has(MUA) and R:has(CAP) and R:has(TG), 'dang ky 3 khoa')

-- ============================================================ 1. MUA OK
DA_MUA.LevelFund = false
daTru.diamond = 0
SU_KIEN = {}
ActivityFund.CAN = true
local c1 = ctxGia()
R.handlers[MUA](c1, 'LevelFund')
check(daTru.diamond == 500, 'mua: tru dung 500 kim cuong', daTru.diamond)
check(TOAN_CUC.HasBuyActivityFoud_LevelFund == true, 'mua: dat co da mua')
check(SU_KIEN[1] and SU_KIEN[1].ten == 'OnBuyActivityFund' and SU_KIEN[1].duLieu == 'LevelFund',
      'mua: phat su kien Active.OnBuyActivityFund', SU_KIEN[1] and SU_KIEN[1].ten)
check(c1.calls[1].f == 'OnReciveResponse' and c1.calls[1].args[3] == 0,
      'mua OK: tat lop dang tai', c1.calls[1].f)

-- ============================================================ 2. MUA KHI DONG
G_ActivityLogic.MO = false
local c2 = ctxGia()
R.handlers[MUA](c2, 'LevelFund')
check(demMa(c2) == 4001, 'hoat dong dong -> 4001', demMa(c2))
G_ActivityLogic.MO = true

-- ============================================================ 3. MUA BI TU CHOI
ActivityFund.CAN, ActivityFund.CAN_MA = false, 4012
daTru.diamond = 0
local c3 = ctxGia()
R.handlers[MUA](c3, 'LevelFund')
check(demMa(c3) == 4012, 'IsCanBuyFund tu choi -> ma cua no (4012)', demMa(c3))
check(daTru.diamond == 0, 'bi tu choi -> KHONG tru kim cuong', daTru.diamond)
ActivityFund.CAN = true

-- ============================================================ 4. MUA ARG SAI
local c4 = ctxGia()
R.handlers[MUA](c4, nil)
check(demMa(c4) == 2, 'mua arg nil -> 2', demMa(c4))

-- ============================================================ 5. LINH CAP OK
DA_MUA.LevelFund = true
TOAN_CUC.ActivityFoudGetCount_LevelFund = 0
DA_PHAT = {}
G_UserLogic.GetLevel = function () return true, 30 end
local c5 = ctxGia()
R.handlers[CAP](c5)
check(DA_PHAT[1] == 109101, 'linh cap: bac 1 = PrizeID 109101', DA_PHAT[1])
check(TOAN_CUC.ActivityFoudGetCount_LevelFund == 1, 'linh cap: dem 0 -> 1',
      TOAN_CUC.ActivityFoudGetCount_LevelFund)
check(c5.calls[1].f == 'OnReciveResponse' and c5.calls[1].args[3] == 0,
      'linh cap OK: tat lop dang tai')

-- ============================================================ 6. BAC KE TIEP
TOAN_CUC.ActivityFoudGetCount_LevelFund = 1
DA_PHAT = {}
local c6 = ctxGia()
R.handlers[CAP](c6)
check(DA_PHAT[1] == 109102, 'linh cap: bac 2 = PrizeID 109102', DA_PHAT[1])

-- ============================================================ 7. CHUA MUA
DA_MUA.LevelFund = false
local c7 = ctxGia()
R.handlers[CAP](c7)
check(demMa(c7) == 4007, 'chua mua quy -> 4007', demMa(c7))
DA_MUA.LevelFund = true

-- ============================================================ 8. THIEU CAP
TOAN_CUC.ActivityFoudGetCount_LevelFund = 2      -- bac 3 doi Level 35
G_UserLogic.GetLevel = function () return true, 30 end
local c8 = ctxGia()
R.handlers[CAP](c8)
check(demMa(c8) == 4011, 'cap 30 < 35 -> 4011', demMa(c8))

-- ============================================================ 9. HET BAC
TOAN_CUC.ActivityFoudGetCount_LevelFund = 3
local c9 = ctxGia()
R.handlers[CAP](c9)
check(demMa(c9) == 4002, 'het bac -> 4002', demMa(c9))

-- ============================================================ 10. QUY THOI GIAN OK
DA_MUA.TimeFund = true
TOAN_CUC.ActivityFoudGetCount_TimeFund = 0
TOAN_CUC.IsGetTimeFundToday = false
DA_PHAT = {}
local c10 = ctxGia()
R.handlers[TG](c10)
check(DA_PHAT[1] == 10001, 'quy thoi gian: PrizeID 10001', DA_PHAT[1])
check(TOAN_CUC.IsGetTimeFundToday == true, 'quy thoi gian: dat co hom nay')
check(TOAN_CUC.ActivityFoudGetCount_TimeFund == 1, 'quy thoi gian: dem 0 -> 1')

-- ============================================================ 11. LINH LAN HAI
local c11 = ctxGia()
R.handlers[TG](c11)
check(demMa(c11) == 4007, 'hom nay da linh -> 4007', demMa(c11))

io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
