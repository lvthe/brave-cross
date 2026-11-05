-- _thu_ca_nhan.lua — bộ thử cho `offline/handlers/ca_nhan.lua`
-- (chạy bằng `python _thu_nha_cua.py _thu_ca_nhan.lua`).
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

local BASE = { CharacterName = 'Cu', Portrait = 'p_cu' }
G_UserLogicDataManager = {}
function G_UserLogicDataManager:SetValue(f, v)
    BASE[f] = v
    return true
end

dofile([[__SC__/offline/handlers/ca_nhan.lua]])
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

check(R:has('G_UserLogic.ClientIsUniqueNickName'), 'dang ky IsUniqueNickName')
check(R:has('G_UserLogic.ClientChangeNickName'), 'dang ky ChangeNickName')
check(R:has('G_UserLogic.ClientChangePortrait'), 'dang ky ChangePortrait')

-- 1. ten luon "duy nhat"
local c1 = ctxGia()
R.handlers['G_UserLogic.ClientIsUniqueNickName'](c1, 'TenMoi')
check(c1.calls[1].f == 'OnIsUniqueNickName' and c1.calls[1].args[1] == true,
      'IsUniqueNickName tra true (offline)', c1.calls[1].args[1])

-- 2. doi ten
local c2 = ctxGia()
R.handlers['G_UserLogic.ClientChangeNickName'](c2, 'TenMoi')
check(BASE.CharacterName == 'TenMoi' and c2.calls[1].f == 'OnChangeNickName'
      and c2.calls[1].n == nil, 'doi ten: ghi CharacterName + callback KHONG doi so',
      BASE.CharacterName .. '/' .. c2.calls[1].f)

-- 3. ten rong / qua dai -> ma 1
local c3 = ctxGia()
R.handlers['G_UserLogic.ClientChangeNickName'](c3, '')
check(c3.calls[1].args[3] == 1 and BASE.CharacterName == 'TenMoi', 'ten rong -> ma 1, khong doi', c3.calls[1].args[3])
local c4 = ctxGia()
R.handlers['G_UserLogic.ClientChangeNickName'](c4, string.rep('x', 21))
check(c4.calls[1].args[3] == 1, 'ten 21 ky tu -> ma 1', c4.calls[1].args[3])

-- 4. doi anh dai dien
local c5 = ctxGia()
R.handlers['G_UserLogic.ClientChangePortrait'](c5, 'p_moi')
check(BASE.Portrait == 'p_moi' and c5.calls[1].f == 'OnChangePortrait', 'doi anh: ghi Portrait + callback',
      BASE.Portrait)
local c6 = ctxGia()
R.handlers['G_UserLogic.ClientChangePortrait'](c6, 5)
check(c6.calls[1].args[3] == 1 and BASE.Portrait == 'p_moi', 'anh khong phai chuoi -> ma 1', c6.calls[1].args[3])

check(OfflineStore.dongBo and OfflineStore.dongBo > 0, 'co goi syncFromClient')
io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
