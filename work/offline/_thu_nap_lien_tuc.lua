-- _thu_nap_lien_tuc.lua — bộ thử cho `offline/handlers/nap_lien_tuc.lua`
-- (chạy bằng `python _thu_nha_cua.py _thu_nap_lien_tuc.lua`).
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

ActivityType = { ContinuousRecharge = 'ContinuousRecharge' }
G_DataManager = { userData = {} }

local CFG = {
    ContinuousList = { { RechargeCount = 100, PrizeList = { { PrizeResType = 2, PropID = 1, PrizeResCount = 5 } } } },
    ContinuousPrize = { ContinuousDayCount = 1, PrizeList = { { PrizeResType = 20, PrizeResCount = 1 } } },
}
G_ActivityLogic = {}
function G_ActivityLogic:GetActivityConfigWithType() return CFG end

-- Luật gốc (vị từ) — bản giả đúng ngữ nghĩa của `share/Activities/ContinuousRechargeLogic.lua`.
ContinuousRechargeLogic = {}
function ContinuousRechargeLogic:IsCanGetPrizeWithDay(s, c, i)
    if s.RechargeDayList[i] == nil then return false end
    if type(c.ContinuousList) ~= 'table' then return false end
    if s.RechargeDayList[i] < c.ContinuousList[i].RechargeCount then return false end
    return true
end
function ContinuousRechargeLogic:IsCanGetContinuousPrize(s, c)
    if s.HasGetContinuousPrize then return false end
    if type(c.ContinuousPrize.ContinuousDayCount) ~= 'number' then return false end
    if #s.RechargeDayList < c.ContinuousPrize.ContinuousDayCount then return false end
    for i, rc in ipairs(c.ContinuousList) do
        if s.RechargeDayList[i] and s.RechargeDayList[i] < rc.RechargeCount then return false end
    end
    return true
end
ClientActivityContinuousRecharge = {}
G_ActivityContinuousRecharge = setmetatable({}, { __index = ClientActivityContinuousRecharge })
G_ActivityContinuousRecharge[ContinuousRechargeLogic] = ContinuousRechargeLogic

local daPhat = {}
G_ChapterLogic = {}
function G_ChapterLogic:SetDataWithPrizeList(list) daPhat[#daPhat + 1] = list; return true, nil, 0 end
local daSuKien = {}
G_EventManager = {}
function G_EventManager:PostLogicEvent(d, ten) daSuKien[#daSuKien + 1] = ten end

dofile([[__SC__/offline/handlers/nap_lien_tuc.lua]])
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

for _, k in ipairs({ 'ClientGetUserState', 'ClientGetDayPrize', 'ClientGetContinuousPrize' }) do
    check(R:has('G_ActivityContinuousRecharge.' .. k), 'dang ky ' .. k)
end

-- 1. GetUserState: dung hinh dang, danh sach rong
local c1 = ctxGia()
R.handlers['G_ActivityContinuousRecharge.ClientGetUserState'](c1)
local s = c1.calls[1].args[1]
check(c1.calls[1].f == 'OnGetUserState' and type(s) == 'table'
      and type(s.RechargeList) == 'table' and s.HasGetContinuousPrize == false,
      'GetUserState: hinh dang ContinuousRechargeData', s and type(s.RechargeList))

-- 2. du dieu kien ngay 1 -> phat thuong + luu trang thai + su kien UI
s.RechargeDayList = { 150 }
local c2 = ctxGia()
R.handlers['G_ActivityContinuousRecharge.ClientGetDayPrize'](c2, 1)
check(#daPhat == 1 and s.PrizeStates['1'] == 1, 'ngay 1: phat thuong + PrizeStates=1',
      { #daPhat, s.PrizeStates['1'] })
check(daSuKien[#daSuKien] == 'OnGeContinuousRechargetDayPrize',
      'phat HO su kien UI OnGeContinuousRechargetDayPrize (client bo trong)', daSuKien[#daSuKien])

-- 3. nhan lan hai -> 1
local c3 = ctxGia()
R.handlers['G_ActivityContinuousRecharge.ClientGetDayPrize'](c3, 1)
check(c3.calls[1].args[3] == 1, 'nhan lan hai -> 1', c3.calls[1].args[3])

-- 4. thieu dieu kien -> 1
s.RechargeDayList = { 10 }
local c4 = ctxGia()
R.handlers['G_ActivityContinuousRecharge.ClientGetDayPrize'](c4, 1)
check(c4.calls[1].args[3] == 1, 'chua du RechargeCount -> 1', c4.calls[1].args[3])

-- 5. thuong lien tuc
s.RechargeDayList = { 150 }
local c5 = ctxGia()
R.handlers['G_ActivityContinuousRecharge.ClientGetContinuousPrize'](c5)
check(s.HasGetContinuousPrize == true and daSuKien[#daSuKien] == 'OnGetContinuousRechargePrize',
      'thuong lien tuc: dat co + su kien UI', s.HasGetContinuousPrize)
local c6 = ctxGia()
R.handlers['G_ActivityContinuousRecharge.ClientGetContinuousPrize'](c6)
check(c6.calls[1].args[3] == 1, 'nhan lien tuc lan hai -> 1', c6.calls[1].args[3])

-- 6. cau hinh VANG -> 4001
G_ActivityLogic.GetActivityConfigWithType = function () return nil end
local c7 = ctxGia()
R.handlers['G_ActivityContinuousRecharge.ClientGetDayPrize'](c7, 1)
check(c7.calls[1].args[3] == 4001, 'khong co cau hinh hoat dong -> 4001', c7.calls[1].args[3])

check(OfflineStore.dongBo and OfflineStore.dongBo > 0, 'co goi syncFromClient')
io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
