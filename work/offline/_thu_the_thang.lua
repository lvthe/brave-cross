-- _thu_the_thang.lua — bộ thử cho `offline/handlers/the_thang.lua`
-- (chạy bằng `python _thu_nha_cua.py _thu_the_thang.lua`).
--
-- KHÔNG thử ở đây: luật THẬT của `MonthlyCardLogic:GetReward` (bộ thử KHÔNG có
-- `share/`); bộ này chỉ đo ĐƯỜNG DÂY — handler gọi đúng hàm lớp cha, trả đúng
-- callback, và đường kích hoạt `OfflineTheThang:kichHoat`.
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

-- ============================================================ LỚP CHA GIẢ
MonthlyCardLogic = {}
MonthlyCardLogic.MonthCardCount = 30
MonthlyCardLogic.KQ = false        -- cờ giả: kết quả GetReward
MonthlyCardLogic.KQ_THE = true     -- cờ giả: kết quả GetMonthlyCard
MonthlyCardLogic.LAN = {}          -- nhật ký lượt gọi

function MonthlyCardLogic:GetReward(sCardType)
    self.LAN[#self.LAN + 1] = { ten = 'GetReward', loai = sCardType }
    return self.KQ
end

function MonthlyCardLogic:GetMonthlyCard(sCardType)
    self.LAN[#self.LAN + 1] = { ten = 'GetMonthlyCard', loai = sCardType }
    return self.KQ_THE
end

function MonthlyCardLogic:GetMonthlyCardLeftCount(sCardType)
    return true, 0
end

ClientMonthlyCardLogic = {}
G_MonthlyCardLogic = setmetatable({}, { __index = MonthlyCardLogic })
G_MonthlyCardLogic[MonthlyCardLogic] = MonthlyCardLogic

dofile([[__SC__/offline/handlers/the_thang.lua]])
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

check(R:has('G_MonthlyCardLogic.ClientGetReward'), 'dang ky ClientGetReward')
check(type(OfflineTheThang) == 'table' and type(OfflineTheThang.kichHoat) == 'function',
      'co OfflineTheThang:kichHoat')

-- ============================================================ 1. NHAN OK
MonthlyCardLogic.KQ = true
MonthlyCardLogic.LAN = {}
local c1 = ctxGia()
R.handlers['G_MonthlyCardLogic.ClientGetReward'](c1, 'Normal')
check(MonthlyCardLogic.LAN[1] and MonthlyCardLogic.LAN[1].ten == 'GetReward'
      and MonthlyCardLogic.LAN[1].loai == 'Normal',
      'goi DUNG luat goc GetReward(Normal)', MonthlyCardLogic.LAN[1] and MonthlyCardLogic.LAN[1].ten)
check(c1.calls[1] and c1.calls[1].f == 'OnReciveResponse' and c1.calls[1].args[3] == 0,
      'thanh cong -> OnReciveResponse ma 0', c1.calls[1] and c1.calls[1].args[3])

-- ============================================================ 2. NHAN HONG
MonthlyCardLogic.KQ = false
local c2 = ctxGia()
R.handlers['G_MonthlyCardLogic.ClientGetReward'](c2, 'Normal')
check(c2.calls[1].args[3] == 1, 'that bai -> ma 1', c2.calls[1].args[3])

-- ============================================================ 3. ARG SAI
local c3 = ctxGia()
local truoc3 = #MonthlyCardLogic.LAN
R.handlers['G_MonthlyCardLogic.ClientGetReward'](c3, nil)
check(c3.calls[1].args[3] == 1, 'arg nil -> ma 1', c3.calls[1].args[3])
check(#MonthlyCardLogic.LAN == truoc3, 'arg sai -> KHONG goi luat goc',
      #MonthlyCardLogic.LAN - truoc3)

-- ============================================================ 4. KICH HOAT
MonthlyCardLogic.KQ_THE = true
MonthlyCardLogic.LAN = {}
local ok4, loi4 = OfflineTheThang:kichHoat('ShuGuo')
check(ok4 == true and loi4 == nil, 'kichHoat ShuGuo OK', tostring(loi4))
check(MonthlyCardLogic.LAN[1] and MonthlyCardLogic.LAN[1].ten == 'GetMonthlyCard'
      and MonthlyCardLogic.LAN[1].loai == 'ShuGuo',
      'kichHoat goi GetMonthlyCard(ShuGuo)', MonthlyCardLogic.LAN[1] and MonthlyCardLogic.LAN[1].ten)

-- ============================================================ 5. KICH HOAT LOAI LA
local ok5, loi5 = OfflineTheThang:kichHoat('KhongCo')
check(ok5 == false and type(loi5) == 'string', 'kichHoat loai la -> false + ly do', tostring(loi5))

-- ============================================================ 6. KICH HOAT THAT BAI
MonthlyCardLogic.KQ_THE = false
local ok6, loi6 = OfflineTheThang:kichHoat()
check(ok6 == false, 'kichHoat that bai -> false', tostring(loi6))
MonthlyCardLogic.KQ_THE = true

-- ============================================================ 7. MAC DINH Normal
MonthlyCardLogic.LAN = {}
OfflineTheThang:kichHoat(nil)
check(MonthlyCardLogic.LAN[1] and MonthlyCardLogic.LAN[1].loai == 'Normal',
      'kichHoat() mac dinh Normal', MonthlyCardLogic.LAN[1] and MonthlyCardLogic.LAN[1].loai)

io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
