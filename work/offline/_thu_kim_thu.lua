-- _thu_kim_thu.lua — bộ thử cho `offline/handlers/kim_thu.lua`
-- (chạy bằng `python _thu_nha_cua.py _thu_kim_thu.lua`).
--
-- KHÔNG thử ở đây: luật THẬT `MidasTouchLogic:runMidasTouchWithCount` (bộ thử không
-- có `share/`); bộ này đo ĐƯỜNG DÂY — sinh ĐÚNG số ngẫu nhiên, gọi đúng hàm, trả
-- ĐÚNG NĂM trường mà `CUIMidasTouch` đọc, và chặn sớm hai cửa (hết lượt / sai tham số).
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
    local R = { helpers = {}, handlers = {} }
    function R:on(k, f) self.handlers[k] = f end
    function R:has(k) return self.handlers[k] ~= nil end
    OfflineRouter = R; return R
end

ErrorCode = {
    UnknowError = 1,
    ArgError = 2,
    MidasTouch = {
        MidasTouchGetConfigFaild = 2801,
        MidasTouchGetDataFaild = 2802,
        MidasTouchSetDataFaild = 2803,
        MidasTouchRunMax = 2804,
        NotEnoughResource = 2805,
    },
}

-- ============================================================ LỚP GỐC GIẢ
local MIDAS = {}
MIDAS.MAX = 10
MIDAS.OK = true
MIDAS.ERR = nil
MIDAS.NEM = false
MIDAS.LAN = {}

function MIDAS:getMaxTouch()
    return true, self.MAX
end

function MIDAS:runMidasTouchWithCount(nCount, randoms)
    self.LAN[#self.LAN + 1] = { ten = 'run', nCount = nCount, soRandom = #randoms, randoms = randoms }
    if self.NEM then error('no gia lap') end
    if self.OK ~= true then return false, self.ERR end
    return true, 0, { 5, 5 }, { 2000, 2000 }, { 1, 1 }
end

function MIDAS:ResetDaily()
    self.LAN[#self.LAN + 1] = { ten = 'reset' }
    if self.NEM then error('no gia lap') end
    return true
end

G_MidasTouchLogic = setmetatable({}, { __index = MIDAS })

G_MidasDataManager = {}
G_MidasDataManager.CUR = 0
function G_MidasDataManager:GetMidasTouchData()
    return true, { CurIndex = self.CUR }
end

dofile([[__SC__/offline/handlers/kim_thu.lua]])
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
    end
    return c
end

local KHOA = 'G_MidasTouchLogic.ClientRunMidasTouchWithCount'
local function goi(...)
    local c = ctxGia()
    R.handlers[KHOA](c, ...)
    return c
end

-- ============================================================ 1. ĐĂNG KÝ
check(R:has(KHOA), 'dang ky ' .. KHOA)
check(type(OfflineKimThu) == 'table' and type(OfflineKimThu.kiem_ngay) == 'function',
      'co OfflineKimThu:kiem_ngay')

-- ============================================================ 2. CHẠY OK
MIDAS.OK, MIDAS.ERR, MIDAS.NEM, MIDAS.LAN, MIDAS.MAX = true, nil, false, {}, 100
G_MidasDataManager.CUR = 0
local c2 = goi(3)
check(MIDAS.LAN[1] and MIDAS.LAN[1].ten == 'run' and MIDAS.LAN[1].nCount == 3,
      'goi DUNG luat goc runMidasTouchWithCount(3, ...)',
      MIDAS.LAN[1] and (tostring(MIDAS.LAN[1].ten) .. ':' .. tostring(MIDAS.LAN[1].nCount)))
check(MIDAS.LAN[1] and MIDAS.LAN[1].soRandom == 3,
      'sinh DUNG 3 so ngau nhien (luat doi nCount == #tRandomList)', MIDAS.LAN[1] and MIDAS.LAN[1].soRandom)
local okR = true
for i = 1, 3 do
    local r = MIDAS.LAN[1] and MIDAS.LAN[1].randoms[i]
    if type(r) ~= 'number' or r < 0 or r >= 1 then okR = false end
end
check(okR, 'moi so ngau nhien nam trong [0,1) — dai getTimesWithRateList doi')

local t2 = c2.calls[1] and c2.calls[1].args[1]
check(c2.calls[1] and c2.calls[1].obj == 'G_MidasTouchLogic'
      and c2.calls[1].f == 'OnServerRunMidasTouchWithCount',
      'tra loi qua OnServerRunMidasTouchWithCount', c2.calls[1] and c2.calls[1].f)
check(type(t2) == 'table' and t2.nCount == 3 and type(t2.tRandomList) == 'table'
      and type(t2.tDiamondCostList) == 'table' and type(t2.tGoldGetList) == 'table'
      and type(t2.tTimesList) == 'table',
      'tra DU NAM truong UI doc (nCount/tRandomList/tDiamondCostList/tGoldGetList/tTimesList)')
check(t2 and t2.tDiamondCostList[1] == 5 and t2.tGoldGetList[1] == 2000 and t2.tTimesList[1] == 1,
      'bon so cua luat goc duoc chuyen NGUYEN', t2 and tostring(t2.tGoldGetList and t2.tGoldGetList[1]))

-- ============================================================ 3. THAM SỐ SAI
MIDAS.LAN = {}
for _, v in ipairs({ 0, -1, 1.5, 'x' }) do
    local c = goi(v)
    local a = c.calls[1] and c.calls[1].args[1]
    check(type(a) == 'table' and a.err == ErrorCode.ArgError,
          'nCount = ' .. tostring(v) .. ' -> err 2', type(a) == 'table' and a.err or tostring(a))
end
check(#MIDAS.LAN == 0, 'tham so sai -> KHONG goi luat goc', #MIDAS.LAN)

-- ============================================================ 4. HẾT LƯỢT (2804)
MIDAS.MAX, G_MidasDataManager.CUR = 10, 8
MIDAS.LAN = {}
local c4 = goi(3)
local a4 = c4.calls[1] and c4.calls[1].args[1]
check(type(a4) == 'table' and a4.err == ErrorCode.MidasTouch.MidasTouchRunMax,
      'con 2 luot ma xin 3 -> 2804 (MidasTouchRunMax)', type(a4) == 'table' and a4.err or tostring(a4))
check(#MIDAS.LAN == 0, 'het luot -> KHONG goi luat goc', #MIDAS.LAN)

MIDAS.MAX, G_MidasDataManager.CUR = 10, 8
MIDAS.LAN = {}
local c5 = goi(2)
local a5 = c5.calls[1] and c5.calls[1].args[1]
check(type(a5) == 'table' and a5.nCount == 2, 'con dung 2 luot ma xin 2 -> CHAY (bien)',
      type(a5) == 'table' and tostring(a5.err or a5.nCount))

-- ============================================================ 5. LUẬT TỪ CHỐI
MIDAS.MAX, G_MidasDataManager.CUR = 100, 0
MIDAS.OK, MIDAS.ERR, MIDAS.LAN = false, 2805, {}
local c6 = goi(1)
local a6 = c6.calls[1] and c6.calls[1].args[1]
check(type(a6) == 'table' and a6.err == 2805, 'luat tu choi -> tra ma goc 2805',
      type(a6) == 'table' and a6.err or tostring(a6))

-- ============================================================ 6. LUẬT NÉM LỖI
MIDAS.OK, MIDAS.NEM, MIDAS.LAN = true, true, {}
local c7 = goi(1)
local a7 = c7.calls[1] and c7.calls[1].args[1]
check(type(a7) == 'table' and a7.err == 1, 'luat nem loi -> err 1',
      type(a7) == 'table' and a7.err or tostring(a7))
MIDAS.NEM = false

-- ============================================================ 7. KIEM NGAY
MIDAS.NEM, MIDAS.LAN = false, {}
local ok8 = OfflineKimThu:kiem_ngay()
check(ok8 == true, 'kiem_ngay -> true', tostring(ok8))
check(MIDAS.LAN[1] and MIDAS.LAN[1].ten == 'reset', 'kiem_ngay goi DUNG ResetDaily',
      MIDAS.LAN[1] and MIDAS.LAN[1].ten)

io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
