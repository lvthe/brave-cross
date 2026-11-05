-- _thu_the_luc.lua — bộ thử cho `offline/handlers/the_luc.lua`
-- (chạy bằng `python _thu_nha_cua.py _thu_the_luc.lua`).
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

-- Luật giả: 2 lần mua được, lần 3 chạm trần (1809); có cờ để thử nhánh ném lỗi.
UserLogic = {}
local lanMua = 0
UserLogic.buyFatigue = function ()
    if UserLogic.NEM then error('no bien') end
    if lanMua >= 2 then return false, 1809 end
    lanMua = lanMua + 1
    return true, 0
end
ClientUserLogic = {}
G_UserLogic = setmetatable({}, { __index = UserLogic })
G_UserLogic[UserLogic] = UserLogic

dofile([[__SC__/offline/handlers/the_luc.lua]])
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

check(R:has('G_UserLogic.ClientBuyFatigue'), 'dang ky ClientBuyFatigue')

-- 1. mua thanh cong
local c1 = ctxGia()
R.handlers['G_UserLogic.ClientBuyFatigue'](c1)
check(c1.calls[1].obj == 'G_UserLogic' and c1.calls[1].f == 'OnServerBuyFatigue'
      and #c1.calls[1].args == 0, 'thanh cong: OnServerBuyFatigue KHONG doi so', c1.calls[1].f)
check(OfflineStore.dongBo and OfflineStore.dongBo > 0, 'co goi syncFromClient')

-- 2. cham tran -> ma cua luat goc
local c2 = ctxGia()
R.handlers['G_UserLogic.ClientBuyFatigue'](c2)
R.handlers['G_UserLogic.ClientBuyFatigue'](c2)   -- lan thu ba
check(c2.calls[#c2.calls].args[3] == 1809, 'cham tran -> 1809', c2.calls[#c2.calls].args[3])

-- 3. luat goc NEM loi -> pcall chan, ma 1
UserLogic.NEM = true
local c3 = ctxGia()
R.handlers['G_UserLogic.ClientBuyFatigue'](c3)
check(c3.calls[1].args[3] == 1, 'luat goc nem loi -> ma 1 (khong sap)', c3.calls[1].args[3])

io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
