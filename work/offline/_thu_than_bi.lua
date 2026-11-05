-- _thu_than_bi.lua — bộ thử cho `offline/handlers/than_bi.lua`
-- (chạy bằng `python _thu_nha_cua.py _thu_than_bi.lua`).
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

ErrorCode = { Common = { SetDataErr = 509, NotEnoughDiamond = 504 },
              System = { ParamError = 4 }, Item = { NotEnoughItem = 1201 },
              Activity = { ActivityNotOpen = 4001 },
              GodSecret = { HasExchange = 5301 } }

local BASE = { Diamond = 1000, Gold = 5000 }
G_DataManager = { userData = {} }
G_UserLogic = {}
function G_UserLogic:GetBaseInfo() return true, BASE end
function G_UserLogic:CostDiamond(n) BASE.Diamond = BASE.Diamond - n; return true end
function G_UserLogic:AddDiamond(n) BASE.Diamond = BASE.Diamond + n; return true end
function G_UserLogic:CostGold(n) BASE.Gold = BASE.Gold - n; return true end
function G_UserLogic:AddGold(n) BASE.Gold = BASE.Gold + n; return true end

local TUI = { ['1'] = 10, ['4'] = 10 }
G_ItemLogic = {}
function G_ItemLogic:GetItemCount(id) return true, TUI[tostring(id)] or 0 end
G_ItemDataManager = {}
function G_ItemDataManager:AddItem(id, n) TUI[tostring(id)] = (TUI[tostring(id)] or 0) + n; return true end
function G_ItemDataManager:ReduceItem(id, n) TUI[tostring(id)] = (TUI[tostring(id)] or 0) - n; return true end

dofile([[__SC__/offline/handlers/than_bi.lua]])
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

for _, k in ipairs({ 'ClientRefresh', 'ClientFreeRefresh', 'ClientExchange',
                      'ClientGetGlobleScore', 'ClientGetRanking', 'ClientGetGloblePrize' }) do
    check(R:has('G_GodSecret.' .. k), 'dang ky ' .. k)
end

local B = G_DataManager.userData.GameGodSecret or {}
-- 1. Refresh khi KHONG co CD: mien phi (gia 0), +100 diem, dat CD
local c1 = ctxGia()
R.handlers['G_GodSecret.ClientRefresh'](c1)
local k1 = c1.calls[1]
local b1 = G_DataManager.userData.GameGodSecret
check(k1.args[1] == 'G_GodSecret' and k1.args[2] == 'OnRefresh' and k1.args[3] == 0,
      'Refresh: OnReciveResponse(G_GodSecret, OnRefresh, 0, ...)', k1.args[2])
check(b1.Score == 100 and b1.CumulativeScore == 100, 'diem +100 ca hai truong', { b1.Score, b1.CumulativeScore })
check(BASE.Diamond == 1000, 'chua co CD -> KHONG tru kim cuong', BASE.Diamond)
check(b1.NextFreeDrawTime > os.time(), 'dat NextFreeDrawTime')

-- 2. FreeRefresh ngay -> 4020
local c2 = ctxGia()
R.handlers['G_GodSecret.ClientFreeRefresh'](c2)
check(c2.calls[1].args[3] == 4020, 'FreeRefresh con CD -> 4020', c2.calls[1].args[3])

-- 3. Refresh khi CO CD -> tru 500
local c3 = ctxGia()
R.handlers['G_GodSecret.ClientRefresh'](c3)
check(BASE.Diamond == 500, 'co CD -> tru 500 kim cuong', BASE.Diamond)

-- 4. Exchange voi ban RONG -> 4021
local c4 = ctxGia()
R.handlers['G_GodSecret.ClientExchange'](c4, 1)
check(c4.calls[1].args[3] == 4021, 'ban rong -> 4021', c4.calls[1].args[3])

-- 5. Gieo ban: Prop 1 x2 -> Prop 4 x3, diem 0. Doi duoc, tru/cong dung, lan hai 5301
b1.ExchangeStateList = { { From = { PrizeResType = 2, PropID = 1, PrizeResCount = 2 },
                           To = { PrizeResType = 2, PropID = 4, PrizeResCount = 3 },
                           ExchangeScore = 0, ExchangeState = 0 } }
local c5 = ctxGia()
R.handlers['G_GodSecret.ClientExchange'](c5, 1)
check(c5.calls[1].args[2] == 'OnExchange' and c5.calls[1].args[5] == 1,
      'Exchange: OnExchange, gui = chi so o', c5.calls[1].args[5])
check(TUI['1'] == 8 and TUI['4'] == 13, 'tru 2 vat 1, cong 3 vat 4', { TUI['1'], TUI['4'] })
local c6 = ctxGia()
R.handlers['G_GodSecret.ClientExchange'](c6, 1)
check(c6.calls[1].args[3] == 5301, 'doi lan hai -> 5301', c6.calls[1].args[3])

-- 6. thieu vat -> 1201
b1.ExchangeStateList[1].ExchangeState = 0
TUI['1'] = 0
local c7 = ctxGia()
R.handlers['G_GodSecret.ClientExchange'](c7, 1)
check(c7.calls[1].args[3] == 1201, 'thieu vat -> 1201', c7.calls[1].args[3])

-- 7. diem toan server = diem cua minh; BXH rong
local c8 = ctxGia()
R.handlers['G_GodSecret.ClientGetGlobleScore'](c8)
check(c8.calls[1].args[5] == b1.Score, 'GetGlobleScore = Score cua minh', c8.calls[1].args[5])
local c9 = ctxGia()
R.handlers['G_GodSecret.ClientGetRanking'](c9)
check(type(c9.calls[1].args[5]) == 'table' and next(c9.calls[1].args[5]) == nil, 'GetRanking: danh sach rong')

-- 8. moc thuong: thieu diem 4023; du diem nhung PrizeList rong -> 509
b1.Score = 0
local c10 = ctxGia()
R.handlers['G_GodSecret.ClientGetGloblePrize'](c10, 1)
check(c10.calls[1].args[3] == 4023, 'thieu diem -> 4023', c10.calls[1].args[3])
b1.Score = 500
local c11 = ctxGia()
R.handlers['G_GodSecret.ClientGetGloblePrize'](c11, 1)
check(c11.calls[1].args[3] == 509, 'du diem nhung PrizeList rong -> 509', c11.calls[1].args[3])

check(OfflineStore.dongBo and OfflineStore.dongBo > 0, 'co goi syncFromClient')
io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
