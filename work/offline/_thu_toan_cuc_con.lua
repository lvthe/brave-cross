-- _thu_toan_cuc_con.lua — bộ thử cho `offline/handlers/toan_cuc_con.lua`
-- (5 khoá toàn cục còn sống). Chạy: `python _thu_nha_cua.py _thu_toan_cuc_con.lua`.
package.path = [[__SC__/?.lua;__SC__/?/init.lua;]] .. package.path

local function ghi(a, b)
    local m = b
    if type(a) == 'string' then m = a end
    io.write('[log] ' .. tostring(m) .. '\n')
end
package.preload['offline.log'] = function ()
    local L = { info = ghi, warn = ghi, err = ghi }; OfflineLog = L; return L
end
package.preload['offline.store'] = function ()
    local S = { TABLES = {}, data = {}, dirty = false }
    function S:syncFromClient() end
    OfflineStore = S; return S
end
package.preload['offline.router'] = function ()
    local R = { handlers = {} }
    function R:on(k, f) self.handlers[k] = f end
    function R:has(k) return self.handlers[k] ~= nil end
    function R:getFor(obj, f)
        if obj ~= nil and obj ~= '' and self.handlers[obj .. '.' .. f] then
            return self.handlers[obj .. '.' .. f]
        end
        return self.handlers[f]
    end
    OfflineRouter = R; return R
end

ErrorCode = { Chat = { SpeechNotExists = 3902 } }
DU_LIEU = {}

G_UserLogic = {
    SetClientCommonData = function (self, k, v) DU_LIEU[k] = v; return true end,
}
RSP = {}
g_CUIGameRPCManager = {}
function g_CUIGameRPCManager:OnReciveResponse(...)
    RSP[#RSP + 1] = { n = select('#', ...), ... }
end

dofile([[__SC__/offline/handlers/toan_cuc_con.lua]])
local R = require('offline.router')

local dat, hong = 0, 0
local function check(ok, ten, ct)
    if ok then dat = dat + 1; io.write('  OK   ' .. ten .. '\n')
    else hong = hong + 1; io.write('  HONG ' .. ten .. (ct ~= nil and (' -> ' .. tostring(ct)) or '') .. '\n') end
end
local function ctxGia()
    local c = { calls = {} }
    function c:call(obj, f, ...)
        self.calls[#self.calls + 1] = { obj = obj, f = f, args = { ... }, n = select('#', ...) }
        if obj == 'g_CUIGameRPCManager' then
            local o = _G[obj]
            if type(o) == 'table' and type(o[f]) == 'function' then o[f](o, ...) end
        end
    end
    return c
end
local local_goi
local function goi(chave, ...)
    local c = ctxGia()
    local h = R.handlers[chave]
    if h == nil then return nil end
    h(c, ...)
    for _, v in ipairs(c.calls) do
        if v.obj ~= 'g_CUIGameRPCManager' then return v, c end
    end
    return c.calls[#c.calls], c
end

--=========================================================== 1. ĐĂNG KÝ
io.write('\n-- 1. dang ky\n')
local KHOA = {
    'ClientGetSpeechContent', 'ClientCheckNewEquipment', 'G_ArenaLogic.ClientSetArenaHero',
    'ClientSetArenaHero', 'G_Login.ClientBindingAccount', 'ClientBindingAccount',
    'ClientReturnHome',
}
local thieu = {}
for _, k in ipairs(KHOA) do
    if not R:has(k) then thieu[#thieu + 1] = k end
end
check(#thieu == 0, 'dang ky DU 7 khoa', table.concat(thieu, ', '))

--=========================================================== 2. NỘI DUNG THOẠI
io.write('\n-- 2. noi dung thoai\n')
local x = goi('ClientGetSpeechContent', 12345)
check(x and x.obj == 'G_ChattingLogic' and x.f == 'OnGetSpeechContent' and x.n == 2,
    'thoai -> OnGetSpeechContent(err, nil) HAI tham so')
check(x and x.args[1] == 3902, 'thoai khong co -> 3902 SpeechNotExists')

--=========================================================== 3. ĐÁNH DẤU TRANG BỊ
io.write('\n-- 3. danh dau trang bi\n')
local c = ctxGia()
R.handlers['ClientCheckNewEquipment'](c, 777)
check(#c.calls == 0, 'danh dau trang bi: KHONG tra loi (client khong cho)')

--=========================================================== 4. ĐỘI HÌNH ĐẤU TRƯỜNG
io.write('\n-- 4. doi hinh dau truong\n')
local nR = #RSP
x = goi('G_ArenaLogic.ClientSetArenaHero', { 25, '26', 27 })
check(x and x.f == 'OnSetArenaHero' and #x.args[1] == 3, 'SetArenaHero -> OnSetArenaHero(3 tuong)')
check(DU_LIEU['OfflineArenaHero'][1] == 25 and DU_LIEU['OfflineArenaHero'][2] == 26,
    'luu danh sach (so hoa)')
check(#RSP > nR, 'co don lop tai')

x = goi('ClientSetArenaHero', { 30 })
check(x and x.f == 'OnSetArenaHero' and x.args[1][1] == 30, 'ban obj RONG cung chay')

--=========================================================== 5. LIÊN KẾT / VỀ NHÀ
io.write('\n-- 5. lien ket tai khoan / ve nha\n')
c = ctxGia()
R.handlers['G_Login.ClientBindingAccount'](c, 'user', 'pass', 'old', 1)
check(#c.calls == 0, 'lien ket tai khoan: nuot lang (khong bao thanh cong)')
c = ctxGia()
R.handlers['ClientBindingAccount'](c, 'u', 'p')
check(#c.calls == 0, 'ban obj RONG: cung nuot lang')

x = goi('ClientReturnHome')
check(x and x.obj == '' and x.f == 'OnReturnHome' and type(x.args[1]) == 'table'
    and x.args[1].err == 0, 've nha -> OnReturnHome({err=0, data={}})')

io.write('\nKET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
