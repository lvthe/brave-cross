-- _thu_qua_7_ngay.lua — bộ thử cho `offline/handlers/qua_7_ngay.lua`
-- (chạy bằng `python _thu_nha_cua.py _thu_qua_7_ngay.lua`).
--
-- KHÔNG thử ở đây: luật THẬT `SevenDaysGiftLogic:saveSevenDaysGiftWithDay` (bộ thử
-- không có `share/`); bộ này đo ĐƯỜNG DÂY — handler gọi đúng hàm, trả đúng callback
-- và đúng hình tham số, và nhịp `kiem_ngay` gọi đúng `SetDailyLogin`.
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

ErrorCode = {
    UnknowError = 1,
    ArgError = 2,
    SevenDaysGift = { ExceedMaxDay = 3201, NotOpen = 3202, HasGet = 3203 },
}

-- ============================================================ LỚP GỐC GIẢ
local LOGIC = {}
LOGIC.OK = true
LOGIC.ERR = nil
LOGIC.NEM = false          -- true -> nem loi (đo đường pcall)
LOGIC.OK_DAILY = true
LOGIC.LAN = {}

function LOGIC:saveSevenDaysGiftWithDay(nDay)
    self.LAN[#self.LAN + 1] = { ten = 'save', day = nDay }
    if self.NEM then error('no gia lap') end
    return self.OK, self.ERR
end

function LOGIC:SetDailyLogin()
    self.LAN[#self.LAN + 1] = { ten = 'daily' }
    if self.NEM then error('no gia lap') end
    return self.OK_DAILY
end

G_SevenDaysGiftLogic = setmetatable({}, { __index = LOGIC })

dofile([[__SC__/offline/handlers/qua_7_ngay.lua]])
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

local KHOA = 'G_SevenDaysGiftLogic.ClientSevenDaysGift'
local function goi(...)
    local c = ctxGia()
    R.handlers[KHOA](c, ...)
    return c
end

-- ============================================================ 1. ĐĂNG KÝ
check(R:has(KHOA), 'dang ky ' .. KHOA)
check(type(OfflineQua7Ngay) == 'table' and type(OfflineQua7Ngay.kiem_ngay) == 'function',
      'co OfflineQua7Ngay:kiem_ngay')

-- ============================================================ 2. NHẬN OK
LOGIC.OK, LOGIC.ERR, LOGIC.NEM, LOGIC.LAN = true, nil, false, {}
local c2 = goi(3)
check(LOGIC.LAN[1] and LOGIC.LAN[1].ten == 'save' and LOGIC.LAN[1].day == 3,
      'goi DUNG luat goc saveSevenDaysGiftWithDay(3)',
      LOGIC.LAN[1] and (LOGIC.LAN[1].ten .. ':' .. tostring(LOGIC.LAN[1].day)))
check(c2.calls[1] and c2.calls[1].obj == 'G_SevenDaysGiftLogic'
      and c2.calls[1].f == 'OnServerGetSevenDaysGift',
      'tra loi qua OnServerGetSevenDaysGift', c2.calls[1] and c2.calls[1].f)
check(c2.calls[1] and c2.calls[1].args[1] == 3,
      'tra dung nDay = 3 (client kiem ProcessNotNumber)', c2.calls[1] and tostring(c2.calls[1].args[1]))
check(OfflineStore.dongBo ~= nil and OfflineStore.dongBo >= 1, 'co dong bo file luu')

-- ============================================================ 3. LUẬT TỪ CHỐI
LOGIC.OK, LOGIC.ERR, LOGIC.NEM, LOGIC.LAN = false, 3203, false, {}
local c3 = goi(1)
check(c3.calls[1] and type(c3.calls[1].args[1]) == 'table'
      and c3.calls[1].args[1].err == 3203,
      'luat tu choi -> tra BANG co err = ma goc 3203',
      c3.calls[1] and tostring(type(c3.calls[1].args[1]) == 'table' and c3.calls[1].args[1].err or c3.calls[1].args[1]))
check(c3.calls[1] and c3.calls[1].f == 'OnServerGetSevenDaysGift',
      'van goi dung ten ham nhan khi hong', c3.calls[1] and c3.calls[1].f)

-- ============================================================ 4. LUẬT NÉM LỖI
LOGIC.OK, LOGIC.NEM, LOGIC.LAN = true, true, {}
local c4 = goi(2)
check(c4.calls[1] and type(c4.calls[1].args[1]) == 'table' and c4.calls[1].args[1].err == 1,
      'luat nem loi -> pcall bat, tra err = 1',
      c4.calls[1] and tostring(type(c4.calls[1].args[1]) == 'table' and c4.calls[1].args[1].err or c4.calls[1].args[1]))
LOGIC.NEM = false

-- ============================================================ 5. THAM SỐ SAI
LOGIC.OK, LOGIC.ERR, LOGIC.LAN = true, nil, {}
local c5 = goi('khong-phai-so')
check(#LOGIC.LAN == 0, 'tham so sai -> KHONG goi luat goc', #LOGIC.LAN)
check(c5.calls[1] and type(c5.calls[1].args[1]) == 'table' and c5.calls[1].args[1].err == ErrorCode.ArgError,
      'tham so sai -> err = ArgError (2)',
      c5.calls[1] and tostring(type(c5.calls[1].args[1]) == 'table' and c5.calls[1].args[1].err or c5.calls[1].args[1]))

-- ============================================================ 6. KIEM NGAY
LOGIC.OK_DAILY, LOGIC.NEM, LOGIC.LAN = true, false, {}
local ok6 = OfflineQua7Ngay:kiem_ngay()
check(ok6 == true, 'kiem_ngay (mo duoc) -> true', tostring(ok6))
check(LOGIC.LAN[1] and LOGIC.LAN[1].ten == 'daily', 'kiem_ngay goi DUNG SetDailyLogin',
      LOGIC.LAN[1] and LOGIC.LAN[1].ten)

LOGIC.OK_DAILY, LOGIC.LAN = false, {}
local ok7 = OfflineQua7Ngay:kiem_ngay()
check(ok7 == false, 'kiem_ngay (da du 7 ngay) -> false', tostring(ok7))
check(LOGIC.LAN[1] and LOGIC.LAN[1].ten == 'daily', 'kiem_ngay van goi luat goc khi da du ngay')

io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
