-- _thu_chat.lua — bộ thử cho `handlers/chat.lua` + lệnh `nap` qua chat.
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

cjson = { decode = function (s) return {} end }
local BASE = { Diamond = 0, Gold = 0, FirstRechargeTime = 0 }
G_DataManager = { userData = {} }
G_UserLogic = {}
function G_UserLogic:GetBaseInfo() return true, BASE end
function G_UserLogic:AddDiamond(n) BASE.Diamond = BASE.Diamond + n; return true end
function G_UserLogic:AddGold(n) BASE.Gold = BASE.Gold + n; return true end
function G_UserLogic:GetClientCommonData() return true, nil end
function G_UserLogic:SetClientCommonData() return true end
RechargeLogic = {}
ClientRechargeLogic = {}
G_RechargeLogic = setmetatable({}, { __index = ClientRechargeLogic })
G_RechargeLogic[RechargeLogic] = RechargeLogic

dofile([[__SC__/offline/handlers/chat.lua]])
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
local msg = function (s) return { Type = 1, Content = s, ChannelId = 1, Param = "{}" } end

check(R:has('ClientNotifyMessage'), 'dang ky ClientNotifyMessage')

-- 1. lenh nap qua chat
local c1 = ctxGia()
R.handlers['ClientNotifyMessage'](c1, msg('nap 100'))
local k1 = c1.calls[1]
check(k1.args[1] == 'G_ChattingLogic' and k1.args[2] == 'OnNotifyMessage'
      and k1.args[3] == 0 and BASE.Diamond == 100,
      'chat "nap 100": +100 kim cuong, callback OnNotifyMessage(0, 0)', BASE.Diamond)
check(G_DataManager.userData.GameNewHandPrivilege
      and G_DataManager.userData.GameNewHandPrivilege.TotalRechargeMoneyIn24 == 100,
      'va cap nhat tong tan thu = 100')

-- 2. lenh co kim cuong rieng + tien to '/'
local c2 = ctxGia()
R.handlers['ClientNotifyMessage'](c2, msg('/nap 50 200'))
check(BASE.Diamond == 300, '"/nap 50 200": +200 kim cuong', BASE.Diamond)

-- 3. chat thuong: khong doi gi, van tra thanh cong
local truoc = BASE.Diamond
local c3 = ctxGia()
R.handlers['ClientNotifyMessage'](c3, msg('xin chao moi nguoi'))
check(BASE.Diamond == truoc and c3.calls[1].args[3] == 0, 'chat thuong: khong doi du lieu')

-- 4. lenh sai cu phap -> chat thuong
local c4 = ctxGia()
R.handlers['ClientNotifyMessage'](c4, msg('nap abc'))
check(c4.calls[1].args[3] == 0 and BASE.Diamond == truoc, '"nap abc" khong phai lenh')

-- 5. tham so hong -> ma 1
local c5 = ctxGia()
R.handlers['ClientNotifyMessage'](c5, 'khong phai bang')
check(c5.calls[1].args[3] == 1, 'tham so khong phai bang -> ma 1')

-- 6. kenh chat
check(R:has('ClientEnterChatGame') and R:has('ClientEnterChannel')
      and R:has('ClientExitChannel') and R:has('ClientGetFriendChatRecord')
      and R:has('ClientReadFriendMessage'), 'dang ky du 5 lenh kenh chat')
local cc = ctxGia()
R.handlers['ClientEnterChannel'](cc, 0, 1)
local kc = cc.calls[1]
check(kc.args[1] == 0 and kc.args[2] == 1 and type(kc.args[3]) == 'table' and type(kc.args[4]) == 'table',
      'EnterChannel: (0, channelId, {}, {})', kc.args[2])
local ce = ctxGia()
R.handlers['ClientEnterChatGame'](ce)
check(ce.calls[1].args[1] == 0, 'EnterChatGame(0)')
local cx = ctxGia()
R.handlers['ClientExitChannel'](cx, 1)
check(cx.calls[1].args[1] == 0, 'ExitChannel(0)')

io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
