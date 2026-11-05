-- _thu_tan_thu.lua — bộ thử cho `offline/handlers/tan_thu.lua`
-- (chạy bằng `python _thu_nha_cua.py _thu_tan_thu.lua`).
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

local CFG = { ['1'] = { NeedRechargeCount = 100, PrizeList = {
    ['1'] = { PrizeId = 501, Day = 1 }, ['2'] = { PrizeId = 502, Day = 2 } } } }
G_ConfigManager = { configCacheName = { GameNewHandPrivilegeConfig = 'GameNewHandPrivilegeConfig' } }
function G_ConfigManager:GetConfigWithNameArg() return CFG end
function G_ConfigManager:GetPrizeConfigWithID(id)
    return { PrizeContent = { { PrizeResType = 3, CurrencyType = 20, PrizeResCount = id == 501 and 10 or 20 } } }
end

G_DataManager = { userData = {} }
local daPhat = {}
G_ChapterLogic = {}
function G_ChapterLogic:SetDataWithPrizeList(list) daPhat[#daPhat + 1] = list; return true, nil, 0 end

dofile([[__SC__/offline/handlers/tan_thu.lua]])
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

for _, k in ipairs({ 'ClientGetUserNewHandPrivilegeInfo', 'ClientSendReward', 'ClientSendRewardV2' }) do
    check(R:has('G_NewHandPrivilegeLogic.' .. k), 'dang ky ' .. k)
end

-- 1. GetInfo: callback dung ten + co ban ghi
local c1 = ctxGia()
R.handlers['G_NewHandPrivilegeLogic.ClientGetUserNewHandPrivilegeInfo'](c1)
local k1 = c1.calls[1]
local b = G_DataManager.userData.GameNewHandPrivilege
check(k1.f == 'OnReciveResponse' and k1.args[1] == 'g_CUINewHandPrivilege'
      and k1.args[2] == 'OnGetUserNewHandPrivilegeInfo'
      and type(k1.args[4]) == 'table' and k1.args[4][1].TableName == 'GameNewHandPrivilege',
      'GetInfo: callback + muc Data GameNewHandPrivilege', k1.args[2])
check(b and b.TotalRechargeMoneyIn24 == 0 and b.RewardTimes == 0, 'ban ghi duoc dung day du', b and b.RewardTimes)

-- 2. tong nap 0 -> 4301
local c2 = ctxGia()
R.handlers['G_NewHandPrivilegeLogic.ClientSendReward'](c2)
check(c2.calls[1].args[3] == 4301, 'chua co dac quyen -> 4301', c2.calls[1].args[3])

-- 3. du 100 -> nhan ngay 1
b.TotalRechargeMoneyIn24 = 150
local c3 = ctxGia()
R.handlers['G_NewHandPrivilegeLogic.ClientSendReward'](c3)
local k3 = c3.calls[1]
check(k3.args[2] == 'OnSendReward' and b.RewardTimes == 1 and #daPhat == 1,
      'nhan ngay 1: RewardTimes=1 + phat thuong + callback', b.RewardTimes)
check(daPhat[1][1].PrizeResCount == 10, 'phat DUNG PrizeId cua ngay 1 (501 -> 10)', daPhat[1][1].PrizeResCount)

-- 4. cung ngay -> 4303
local c4 = ctxGia()
R.handlers['G_NewHandPrivilegeLogic.ClientSendReward'](c4)
check(c4.calls[1].args[3] == 4303, 'da nhan trong ngay -> 4303', c4.calls[1].args[3])

-- 5. hom sau -> nhan ngay 2
b.LastRewardTime = os.time() - 2 * 86400
local c5 = ctxGia()
R.handlers['G_NewHandPrivilegeLogic.ClientSendReward'](c5)
check(b.RewardTimes == 2 and daPhat[2][1].PrizeResCount == 20,
      'hom sau: nhan ngay 2 (502 -> 20)', b.RewardTimes)

-- 6. het luot -> 4302
b.LastRewardTime = os.time() - 3 * 86400
local c6 = ctxGia()
R.handlers['G_NewHandPrivilegeLogic.ClientSendReward'](c6)
check(c6.calls[1].args[3] == 4302, 'het luot -> 4302', c6.calls[1].args[3])

-- 7. SendRewardV2: IM LANG (obj/cb rong) nhung co muc Data
b.RewardTimes = 0
b.LastRewardTime = 0
local c7 = ctxGia()
R.handlers['G_NewHandPrivilegeLogic.ClientSendRewardV2'](c7)
local k7 = c7.calls[1]
check(k7.f == 'OnReciveResponse' and k7.args[1] == '' and k7.args[2] == ''
      and type(k7.args[4]) == 'table' and k7.args[4][1].TableName == 'GameNewHandPrivilege',
      'SendRewardV2: im lang nhung VAN mang Data', { k7.args[1], k7.args[2] })

check(OfflineStore.dongBo and OfflineStore.dongBo > 0, 'co goi syncFromClient')
io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
