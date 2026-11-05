-- _thu_nha_cua.lua — bộ thử cho `offline/nha_cua.lua`, chạy trong máy Lua trần
-- (xem `_thu_nha_cua.py`). `__SC__` được bộ chạy thay bằng đường dẫn cây sc.
package.path = [[__SC__/?.lua;__SC__/?/init.lua;]] .. package.path

local function ghi(m) io.write('[log] ' .. tostring(m) .. '\n') end
package.preload['offline.log'] = function ()
    local L = { info = ghi, warn = ghi, err = ghi }
    OfflineLog = L
    return L
end
package.preload['offline.store'] = function ()
    local S = { TABLES = {}, data = {}, dirty = false }
    OfflineStore = S
    return S
end
package.preload['offline.router'] = function ()
    local R = { handlers = {} }
    function R:on(k, f) self.handlers[k] = f end
    function R:has(k) return self.handlers[k] ~= nil end
    OfflineRouter = R
    return R
end

local CFG = {
    ['4'] = {
        ['1'] = { ResourceForUpgrade = 5000, ResourceType = 1, TimeForUpgrade = 0,
                  MaxLevel = 10, ExWhenComplete = 0, TownHassLevel = 1 },
        ['2'] = { ResourceForUpgrade = 10000, ResourceType = 1, TimeForUpgrade = 0,
                  MaxLevel = 10, ExWhenComplete = 3, TownHassLevel = 1 },
        ['3'] = { ResourceForUpgrade = 20000, ResourceType = 1, TimeForUpgrade = 0,
                  MaxLevel = 10, ExWhenComplete = 0, TownHassLevel = 1 },
    },
    ['5'] = {
        ['1'] = { ResourceForUpgrade = 5000, ResourceType = 1, TimeForUpgrade = 0,
                  MaxLevel = 10, ExWhenComplete = 3, TownHassLevel = 1 },
    },
}
G_ConfigManager = { BuildingConfig = CFG }
CDataManager = {}
G_DataManager = setmetatable({ userData = {} }, { __index = CDataManager })
local base = { Gold = 100000, Diamond = 1000, Ex = 0 }
G_UserLogic = {}
function G_UserLogic:GetBaseInfo() return true, base end
function G_UserLogic:CostGold(n) base.Gold = base.Gold - n; return true end
function G_UserLogic:CostDiamond(n) base.Diamond = base.Diamond - n; return true end
function G_UserLogic:AddUserEx(n) base.Ex = (base.Ex or 0) + n; return true end
G_EventManager = { PostDataEvent = function () end }
EventManagerTableName = { GameUserBuilding = "GameUserBuilding" }
BuildingLogic = {}
function BuildingLogic:new() return setmetatable({}, { __index = BuildingLogic }) end

local NC = dofile([[__SC__/offline/nha_cua.lua]])

local dat, hong = 0, 0
local function check(ok, ten, ct)
    if ok then dat = dat + 1; io.write('  OK   ' .. ten .. '\n')
    else
        hong = hong + 1
        io.write('  HONG ' .. ten .. (ct ~= nil and (' -> ' .. tostring(ct)) or '') .. '\n')
    end
end

check(NC:cai() == true, 'cai() tra true')
check(rawget(_G, 'g_BuildingLogic') ~= nil, 'co g_BuildingLogic')
local t = G_DataManager.userData.GameUserBuilding
check(type(t) == 'table' and type(t['4']) == 'table' and t['4'].BuildingLevel == 1,
      'bang GameUserBuilding duoc dung cap 1', t and t['4'] and t['4'].BuildingLevel)
check(type(CDataManager.GetBuilding) == 'function', 'CDataManager.GetBuilding da co')
check(G_DataManager:GetBuilding(4) ~= nil
      and G_DataManager:GetBuilding(4).BaseInfo.BuildingLevel == 1,
      'GetBuilding(4) tra BaseInfo.BuildingLevel')
check(G_DataManager:GetBuilding(99) == nil, 'GetBuilding id la -> nil')

local r1, r2 = g_BuildingLogic:UpgradeBuilding(4)
check(r1 == nil and tonumber(r2) == 4, 'Upgrade(4): thanh cong tra nil, id',
      tostring(r1) .. ',' .. tostring(r2))
check(base.Gold == 95000, 'tru dung 5000 vang', base.Gold)
check(t['4'].IsUpgrading == true, 'dat co IsUpgrading')
check(g_BuildingLogic:UpgradeBuilding(4) == 6000, 'dang nang -> 6000')
check(g_BuildingLogic:CompleteBuildingUpgrade(5) == 6000, 'chua nang -> 6000')

local c1, c2 = g_BuildingLogic:CompleteBuildingUpgrade(4)
check(c1 == nil and type(c2) == 'table' and c2.BuildingLevel == 2,
      'Complete(4): len cap 2 tra nil, data',
      tostring(c1) .. ',' .. tostring(c2 and c2.BuildingLevel))
check(t['4'].BuildingLevel == 2 and t['4'].IsUpgrading == false,
      'ban ghi: cap 2, het IsUpgrading')
check(g_BuildingLogic:CompleteBuildingUpgrade(4) == 6000, 'Complete lan hai -> 6000')

g_BuildingLogic:UpgradeBuilding(4)
local truoc = base.Diamond
g_BuildingLogic:CompleteBuildingUpgradeWithDiamond(4)
check(t['4'].BuildingLevel == 3, 'CompleteWithDiomaon len cap 3', t['4'].BuildingLevel)
check(base.Diamond == truoc, 'TimeForUpgrade = 0 -> gia kim cuong 0', base.Diamond)

local ex0 = base.Ex
g_BuildingLogic:UpgradeBuilding(5)
g_BuildingLogic:CompleteBuildingUpgrade(5)
check(base.Ex == ex0 + 3, 'cong EXP = ExWhenComplete cua cap CU', base.Ex)

g_BuildingLogic:UpgradeBuilding(5)
local h1 = g_BuildingLogic:CancelBuildingUpgrade(5)
check(h1 == nil and t['5'].IsUpgrading == false and t['5'].UpgradeLeftTime == 0,
      'Cancel xoa dong ho, KHONG hoan vang', tostring(h1))

local R = require('offline.router')
local function ctxGia()
    local c = { calls = {} }
    function c:reply(tData, strFunc, strObj)
        self.calls[#self.calls + 1] = { t = tData, f = strFunc, o = strObj }
    end
    return c
end
check(R:has('ClientCancelBuildingUpgrade'), 'router co ClientCancelBuildingUpgrade')

-- Complete qua RPC: callback toan cuc phai nhan {err, data={BuildingID, BuildingLevel}}
g_BuildingLogic:UpgradeBuilding(4)
local cx1 = ctxGia()
R.handlers['ClientCompleteBuildingUpgrade'](cx1, 4)
local k1 = cx1.calls[1]
check(k1 ~= nil and k1.f == 'OnCompleteBuildingUpgrade' and k1.o == ''
      and k1.t.err == 0 and type(k1.t.data) == 'table' and k1.t.data.BuildingLevel ~= nil,
      'RPC Complete tra {err=0, data} cho ham TOAN CUC', k1 and k1.f)

-- Huy qua RPC
g_BuildingLogic:UpgradeBuilding(5)
local cx2 = ctxGia()
R.handlers['ClientCancelBuildingUpgrade'](cx2, 5)
local k2 = cx2.calls[1]
check(k2 ~= nil and k2.f == 'OnCancelBuildingUpgrade' and k2.t.err == 0 and k2.t.data == 5,
      'RPC huy tra {err=0, data=id}', k2 and k2.t.err)

-- Upgrade im lang: KHONG goi reply
local cx3 = ctxGia()
g_BuildingLogic:UpgradeBuilding(4)
R.handlers['ClientUpgradeBuilding'](cx3, 4)
check(#cx3.calls == 0, 'RPC Upgrade KHONG tra loi (cb="")', #cx3.calls)

check(g_BuildingLogic:UpgradeBuilding(99) == 6000, 'id la -> 6000')
base.Gold = 0
g_BuildingLogic:UpgradeBuilding(5)
check(g_BuildingLogic:UpgradeBuilding(5) == 6000, 'het vang -> 6000')

io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
