-- _thu_nap_gia_lap.lua — bộ thử cho `offline/nap_gia_lap.lua`
-- (chạy bằng `python _thu_nha_cua.py _thu_nap_gia_lap.lua`).
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

cjson = { decode = function (s) return { FirstRechargeStatus = 0 } end }
local BASE = { Diamond = 10, Gold = 0, FirstRechargeTime = 0 }
local CHUNG = {}
G_DataManager = { userData = {} }
G_UserLogic = {}
function G_UserLogic:GetBaseInfo() return true, BASE end
function G_UserLogic:AddDiamond(n) BASE.Diamond = BASE.Diamond + n; return true end
function G_UserLogic:AddGold(n) BASE.Gold = BASE.Gold + n; return true end
function G_UserLogic:GetClientCommonData(k) return true, CHUNG[k] end
function G_UserLogic:SetClientCommonData(k, v) CHUNG[k] = v; return true end

RechargeLogic = {}
function RechargeLogic:getFirstRechargePrize()
    return true, 0, { { PrizeResType = 20, PrizeResCount = 5 } }
end
ClientRechargeLogic = {}
G_RechargeLogic = setmetatable({}, { __index = ClientRechargeLogic })
G_RechargeLogic[RechargeLogic] = RechargeLogic

dofile([[__SC__/offline/nap_gia_lap.lua]])
local R = require('offline.router')

local dat, hong = 0, 0
local function check(ok, ten, ct)
    if ok then dat = dat + 1; io.write('  OK   ' .. ten .. '\n')
    else hong = hong + 1; io.write('  HONG ' .. ten .. (ct ~= nil and (' -> ' .. tostring(ct)) or '') .. '\n') end
end
local function ctxGia()
    local c = { calls = {} }
    function c:call(obj, f, ...)
        self.calls[#self.calls + 1] = { obj = obj, f = f, a = ..., args = { ... } }
    end
    return c
end

check(OfflineNap ~= nil, 'co OfflineNap')
check(R:has('ClientGMCommond'), 'dang ky ClientGMCommond')
check(R:has('G_RechargeLogic.ClientGetFirstRechargePrize'), 'dang ky ClientGetFirstRechargePrize')

-- 1. nạp giả lập cơ bản
local ok1 = OfflineNap:cong(100)
check(ok1 == true and BASE.Diamond == 110, 'cong(100): +100 kim cuong (10 -> 110)', BASE.Diamond)
check(BASE.FirstRechargeTime > 0, 'dat FirstRechargeTime')
check(CHUNG.RechargeData and CHUNG.RechargeData.FirstRechargeStatus == 1,
      'RechargeData.FirstRechargeStatus = 1 (HasFirstRecharge)', CHUNG.RechargeData and CHUNG.RechargeData.FirstRechargeStatus)
local d = G_DataManager.userData
check(d.GameUserContinuousRecharge and #d.GameUserContinuousRecharge.RechargeList == 1
      and d.GameUserContinuousRecharge.RechargeDayList[1] == 100,
      'Nạp liên tục: 1 dòng + DayList {100}', d.GameUserContinuousRecharge and d.GameUserContinuousRecharge.RechargeDayList[1])
check(d.GameNewHandPrivilege.TotalRechargeMoneyIn24 == 100, 'Quà tân thủ: tong 100',
      d.GameNewHandPrivilege.TotalRechargeMoneyIn24)

-- 2. nạp kèm số kim cương khác
OfflineNap:cong(50, 200)
check(BASE.Diamond == 310, 'cong(50,200): +200 kim cuong', BASE.Diamond)
check(#d.GameUserContinuousRecharge.RechargeList == 2
      and d.GameUserContinuousRecharge.RechargeDayList[1] == 150,
      'DayList = {150} (cộng dồn cùng ngày)', d.GameUserContinuousRecharge.RechargeDayList[1])
check(d.GameNewHandPrivilege.TotalRechargeMoneyIn24 == 150, 'tong tan thu 150',
      d.GameNewHandPrivilege.TotalRechargeMoneyIn24)

-- 3. GM recharge
local c3 = ctxGia()
R.handlers['ClientGMCommond'](c3, { 'recharge', 30 })
local k3 = c3.calls[1]
check(k3 and k3.f == 'OnReciveResponse' and k3.args[1] == 'G_GameWorld' and k3.args[3] == 0,
      'GM recharge: OnGMCommond(G_GameWorld, 0)', k3 and k3.args[3])
check(BASE.Diamond == 340 and d.GameNewHandPrivilege.TotalRechargeMoneyIn24 == 180,
      'GM recharge 30: +30 kim cuong, tong 180', BASE.Diamond)

-- 4. GM addgold
local c4 = ctxGia()
R.handlers['ClientGMCommond'](c4, { 'addgold', 500 })
check(BASE.Gold == 500, 'GM addgold 500', BASE.Gold)

-- 5. lệnh lạ -> mã 1
local c5 = ctxGia()
R.handlers['ClientGMCommond'](c5, { 'khongco' })
check(c5.calls[1].args[3] == 1, 'lenh la -> ma 1', c5.calls[1].args[3])

-- 6. qua dau nap
local c6 = ctxGia()
R.handlers["G_RechargeLogic.ClientGetFirstRechargePrize"](c6)
local k6 = c6.calls[1]
check(k6.f == 'OnReciveResponse' and k6.args[1] == 'G_RechargeLogic'
      and k6.args[2] == 'OnServerGetFirstRechargePrize'
      and type(k6.args[5]) == 'table' and k6.args[5][1].PrizeResCount == 5,
      'qua dau nap: callback phuong thuc + danh sach thuong', k6.args[2])

io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
