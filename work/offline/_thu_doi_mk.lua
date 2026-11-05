-- _thu_doi_mk.lua — bộ thử cho ĐỔI MẬT KHẨU:
--   (C) `OfflineTaiKhoan:bamMD5` + `doiMatKhau` (POST /api/password);
--   (D) lệnh chat `doimk <cu> <moi>` trong `handlers/chat.lua`.
package.path = [[__SC__/?.lua;__SC__/?/init.lua;]] .. package.path

local function ghi(m) io.write('[log] ' .. tostring(m) .. '\n') end
package.preload['offline.log'] = function ()
    local L = { info = ghi, warn = ghi, err = ghi }; OfflineLog = L; return L
end
local S = { TABLES = {}, data = {} }
function S:path() return 'gia/offline_save_1014.json' end
function S:save() return true end
function S:syncFromClient() end
package.preload['offline.store'] = function () OfflineStore = S; return S end
package.preload['offline.router'] = function ()
    local R = { handlers = {} }
    function R:on(k, f) self.handlers[k] = f end
    function R:has(k) return self.handlers[k] ~= nil end
    function R:getFor(obj, f) return self.handlers[f] end
    OfflineRouter = R; return R
end

-- `cjson` gia: `encode` tra NGUYEN bang (de doc truong), `decode` tra bang tra loi.
cjson = {
    encode = function (t) return t end,
    decode = function (s) return { ok = true, uid = 1014, code = 0, error = 'ok' } end,
}
G_DataManager = { userData = {} }
G_UserLogic = {}
local BASE = { Diamond = 0, Gold = 0 }
function G_UserLogic:GetBaseInfo() return true, BASE end
function G_UserLogic:AddDiamond(n) BASE.Diamond = BASE.Diamond + n; return true end
function G_UserLogic:AddGold(n) BASE.Gold = BASE.Gold + n; return true end
function G_UserLogic:GetClientCommonData() return true, nil end
function G_UserLogic:SetClientCommonData() return true end
RechargeLogic = {}
ClientRechargeLogic = {}
G_RechargeLogic = setmetatable({}, { __index = ClientRechargeLogic })
G_RechargeLogic[RechargeLogic] = RechargeLogic

-- HTTP gia: ghi lai url + body roi TRA LOI NGAY (hoac de bai kiem tu tra loi).
local HTTP = { ds = {}, traLoiNgay = true }
sngHttpRequestWithString = function (url, body)
    HTTP.ds[#HTTP.ds + 1] = { url = url, body = body }
    if HTTP.traLoiNgay then
        OfflineTaiKhoan:__onHttpSuc(url, '{"ok":true,"uid":1014,"code":0}')
    end
end

-- Hẹn giờ gia (batDau của tai_khoan gọi schedule).
S_CCSchedule = { schedule = function () end, scheduleOnce = function () end }

local dat, hong = 0, 0
local function check(ok, ten, ct)
    if ok then dat = dat + 1; io.write('  OK   ' .. ten .. '\n')
    else hong = hong + 1; io.write('  HONG ' .. ten .. (ct ~= nil and (' -> ' .. tostring(ct)) or '') .. '\n') end
end

--------------------------------------------------------------------------- (C)
-- MD5 giong HINH DANG cua `g_CCMath:MD5`: tra 32 hex, KHONG dung `self`.
local function md5Gia(s)
    local t = tostring(s)
    return (t .. string.rep('0', 32)):sub(1, 32)
end
g_CCMath = { MD5 = function (self, s) return md5Gia(s) end }

dofile([[__SC__/offline/tai_khoan.lua]])
local T = OfflineTaiKhoan

check(type(T.doiMatKhau) == 'function' and type(T.bamMD5) == 'function',
      'C0 nap duoc doiMatKhau + bamMD5')

-- C1. Bam MD5: dung 32 ky tu, dung tham so; thieu g_CCMath -> nil + ly do.
local h1, ly1 = T:bamMD5('abc')
check(h1 == md5Gia('abc') and #h1 == 32, 'C1 bamMD5("abc")', tostring(h1))
local cuCC = g_CCMath
g_CCMath = nil
local h2, ly2 = T:bamMD5('abc')
g_CCMath = cuCC
check(h2 == nil and type(ly2) == 'string' and ly2:find('g_CCMath') ~= nil,
      'C1 thieu g_CCMath -> nil + ly do', tostring(ly2))

-- C1b. `g_CCMath` KHONG phai BANG (tren may that no la USERDATA cua lop native:
-- `engine.lua:162` `CCMath:new()`). Ban dau kiem `type(m)=='table'` nen LUON tu choi.
-- Gia lap bang mot THREAD co metatable `__index` — kieu khac bang, van index duoc.
local mt = { __index = { MD5 = function (self, s) return md5Gia(s) end } }
local khac = coroutine.create(function () end)
debug.setmetatable(khac, mt)
g_CCMath = khac
local h3, ly3 = T:bamMD5('abc')
g_CCMath = cuCC
check(h3 == md5Gia('abc'),
      'C1b g_CCMath KHONG phai bang (thread/userdata) van bam duoc', tostring(h3) .. '/' .. tostring(ly3))

-- C2. Chua dang nhap: KHONG goi HTTP, tra loi tai cho ma 3001.
T.email = nil
HTTP.ds = {}
local daTra = nil
local ok2 = T:doiMatKhau('a', 'b', function (ok, res) daTra = { ok = ok, code = res and res.code } end)
check(ok2 == false and daTra ~= nil and daTra.ok == false and daTra.code == 3001,
      'C2 chua dang nhap -> false + ma 3001', daTra and daTra.code)
check(#HTTP.ds == 0, 'C2 va KHONG goi mang', #HTTP.ds)

-- C3. Binh thuong: POST /api/password, dung ba truong, callback ok.
T.email = 'a@b.c'
HTTP.ds = {}
local daTra3 = nil
T:doiMatKhau(md5Gia('cu'), md5Gia('moi'), function (ok, res) daTra3 = { ok = ok, res = res } end)
local g = HTTP.ds[1]
check(g ~= nil and g.url:find('/api/password', 1, true) ~= nil,
      'C3 goi /api/password', g and g.url)
check(g ~= nil and type(g.body) == 'table'
      and g.body.email == 'a@b.c'
      and g.body.old_password == md5Gia('cu')
      and g.body.new_password == md5Gia('moi'),
      'C3 body co email + old_password + new_password')
check(daTra3 ~= nil and daTra3.ok == true, 'C3 callback ok=true')

--------------------------------------------------------------------------- (D)
dofile([[__SC__/offline/handlers/chat.lua]])
local R = require('offline.router')

local function ctxGia()
    local c = { calls = {} }
    function c:call(obj, f, ...)
        self.calls[#self.calls + 1] = { obj = obj, f = f, args = { ... } }
    end
    return c
end
local function msg(s) return { Type = 1, Content = s, ChannelId = 1, Param = '{}' } end

check(R:has('ClientNotifyMessage'), 'D0 dang ky ClientNotifyMessage')

-- D1. `doimk <cu> <moi>`: bam CA HAI va gui dung cap.
T.email = 'a@b.c'
HTTP.ds = {}
local c1 = ctxGia()
R.handlers['ClientNotifyMessage'](c1, msg('doimk cu moi'))
check(#HTTP.ds == 1 and HTTP.ds[1].url:find('/api/password', 1, true) ~= nil,
      'D1 gui dung mot lan /api/password', #HTTP.ds)
check(#HTTP.ds == 1 and HTTP.ds[1].body.old_password == md5Gia('cu')
      and HTTP.ds[1].body.new_password == md5Gia('moi'),
      'D1 bam CA HAI mat khau (khong gui tho)',
      #HTTP.ds == 1 and tostring(HTTP.ds[1].body.new_password))
check(#c1.calls == 1 and c1.calls[1].args[1] == 'G_ChattingLogic' and c1.calls[1].args[3] == 0,
      'D1 van tra OnNotifyMessage(0, 0)')

-- D2. Chua dang nhap: khong gui, van tra loi.
T.email = nil
HTTP.ds = {}
local c2 = ctxGia()
R.handlers['ClientNotifyMessage'](c2, msg('/DOIMK a b'))
check(#HTTP.ds == 0 and #c2.calls == 1 and c2.calls[1].args[3] == 0,
      'D2 chua dang nhap -> khong gui, van tra loi')

-- D3. Sai so mau / tu khoa khac: KHONG phai lenh, khong gui.
T.email = 'a@b.c'
local dsKhong = { 'doimk', 'doimk a', 'doimk a b c', 'doimk a b ', 'doimatkhau', 'abcd a b' }
for i = 1, #dsKhong do
    HTTP.ds = {}
    local c = ctxGia()
    R.handlers['ClientNotifyMessage'](c, msg(dsKhong[i]))
    -- 'doimk a b ' co khoang trang cuoi -> pattern %s*$ van nhan: do la lenh DUNG.
    local laLenh = (dsKhong[i] == 'doimk a b ')
    check((#HTTP.ds == (laLenh and 1 or 0)) and #c.calls == 1 and c.calls[1].args[3] == 0,
          'D3 "' .. dsKhong[i] .. '" -> ' .. (laLenh and 'LA lenh' or 'KHONG phai lenh'), #HTTP.ds)
end

-- D4. Khong co g_CCMath: KHONG gui mat khau tho, van tra loi.
g_CCMath = nil
HTTP.ds = {}
local c4 = ctxGia()
R.handlers['ClientNotifyMessage'](c4, msg('doimk a b'))
g_CCMath = { MD5 = function (self, s) return md5Gia(s) end }
check(#HTTP.ds == 0 and #c4.calls == 1 and c4.calls[1].args[3] == 0,
      'D4 bam hong -> KHONG gui, van tra loi', #HTTP.ds)

-- D5. Cac lenh cu khong bi anh huong.
HTTP.ds = {}
local c5 = ctxGia()
R.handlers['ClientNotifyMessage'](c5, msg('nap 100'))
check(BASE.Diamond == 100 and #HTTP.ds == 0, 'D5 lenh "nap 100" van chay', BASE.Diamond)

io.write(string.format('KET QUA: dat %d, hong %d\n', dat, hong))
os.exit(hong == 0 and 0 or 1)
