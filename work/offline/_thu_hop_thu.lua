-- _thu_hop_thu.lua — bộ thử cho `offline/handlers/hop_thu.lua`
-- (chạy bằng `python _thu_nha_cua.py _thu_hop_thu.lua`).
-- Đo ĐƯỜNG NỐI + phong bì; LUẬT (saveMailPrizeAndStatus...) là mã gốc, không chép lại.
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

ErrorCode = { Mail = { NoMail = 2102 } }

-- Lớp CHA + thể hiện
MailLogic = {}
local KHO = {
    m1 = { MailID = 'm1', MailText = '{"attach":[]}', read = false, got = false },
    m2 = { MailID = 'm2', MailText = '{"attach":[]}', read = false, got = false },
}
function MailLogic:GetMailList() return true, KHO end
function MailLogic:getMailWithId(id) local m = KHO[id]; if m == nil then return false end; return true, m end
function MailLogic:saveMailPrizeAndStatus(mail)
    if mail.got then return false, 2103 end
    mail.got = true; mail.read = true
    return true, 0
end
function MailLogic:saveMailPrizeList(ds)
    local da = {}
    for _, m in pairs(ds) do
        local ok = self:saveMailPrizeAndStatus(m)
        if ok then da[#da + 1] = m end
    end
    return true, da, 0
end
function MailLogic:setMailReadWithMailID(id)
    local ok, m = self:getMailWithId(id)
    if not ok then return false end
    m.read = true
    return true
end
ClientMailLogic = {}
G_MailLogic = setmetatable({}, { __index = MailLogic })
G_MailLogic[MailLogic] = MailLogic

dofile([[__SC__/offline/handlers/hop_thu.lua]])
local R = require('offline.router')

local dat, hong = 0, 0
local function check(ok, ten, ct)
    if ok then dat = dat + 1; io.write('  OK   ' .. ten .. '\n')
    else hong = hong + 1; io.write('  HONG ' .. ten .. (ct ~= nil and (' -> ' .. tostring(ct)) or '') .. '\n') end
end
local function ctxGia()
    local c = { calls = {} }
    function c:call(obj, f, a, b, err_, ev, ...)
        self.calls[#self.calls + 1] = { obj = obj, f = f, a = a, b = b, err = err_, n = select('#', ...), x = ... }
    end
    return c
end

for _, k in ipairs({ 'ClientSaveMailPrizeWithMailID', 'ClientSaveMailPrizeWithMailIdList',
                      'ClientSaveAllMailPrize', 'ClientSetMailReadWithMailID' }) do
    check(R:has('G_MailLogic.' .. k), 'da dang ky G_MailLogic.' .. k)
end

-- 1. nhận MỘT thư
local c1 = ctxGia()
R.handlers['G_MailLogic.ClientSaveMailPrizeWithMailID'](c1, 'm1')
local k1 = c1.calls[1]
check(k1 and k1.b == 'OnServerSaveMailPrizeWithMailID' and k1.x == 'm1' and KHO.m1.got == true,
      'nhan mot thu: callback (id, mail) + da danh dau got', k1 and k1.b)

-- 2. nhận lại -> 2103, không callback
local c2 = ctxGia()
R.handlers['G_MailLogic.ClientSaveMailPrizeWithMailID'](c2, 'm1')
check(c2.calls[1] and c2.calls[1].err == 2103 and c2.calls[1].a == '',
      'nhan lan hai -> ma 2103 (luat goc), khong callback', c2.calls[1] and c2.calls[1].err)

-- 3. danh sách: chỉ m2 chưa nhận -> trả đúng [m2]
local c3 = ctxGia()
R.handlers['G_MailLogic.ClientSaveMailPrizeWithMailIdList'](c3, { 'm1', 'm2' })
local k3 = c3.calls[1]
check(k3 and k3.b == 'OnServerSaveMailPrizeWithMailIdList' and type(k3.x) == 'table'
      and #k3.x == 1 and k3.x[1] == KHO.m2, 'nhan loat: tra danh sach THAT SU vua nhan (1: m2)',
      k3 and k3.x and #k3.x)

-- 4. nhận tất cả: không còn gì -> mã 0, danh sách rỗng
local c4 = ctxGia()
R.handlers['G_MailLogic.ClientSaveAllMailPrize'](c4)
local k4 = c4.calls[1]
check(k4 and k4.b == 'OnServerSaveAllMailPrize' and k4.x == 0,
      'nhan tat ca: callback doc DOI SO VI TRI 1 = ma 0', k4 and k4.x)

-- 5. đánh dấu đã đọc
KHO.m2.read = false
local c5 = ctxGia()
R.handlers['G_MailLogic.ClientSetMailReadWithMailID'](c5, 'm2')
local k5 = c5.calls[1]
check(k5 and k5.b == 'OnServerSetMailReadWithMailID' and k5.x == 'm2' and KHO.m2.read == true,
      'danh dau da doc + callback (id, mail)', k5 and k5.b)

-- 6. id lạ -> mã lỗi, không callback
local c6 = ctxGia()
R.handlers['G_MailLogic.ClientSetMailReadWithMailID'](c6, 'khong_co')
check(c6.calls[1] and c6.calls[1].a == '', 'id la -> nhanh loi, khong callback', c6.calls[1] and c6.calls[1].err)

check(OfflineStore.dongBo and OfflineStore.dongBo > 0, 'co goi syncFromClient')
io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
