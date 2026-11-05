-- _thu_trang_bi.lua — bộ thử cho `offline/handlers/trang_bi_cuong_hoa.lua`
-- (chạy bằng `python _thu_nha_cua.py _thu_trang_bi.lua`).
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

-- Thế giới giả: MỘT ô đồ cấp cường hoá 0, giá mỗi cấp 100 vàng.
local O = { HeroID = 1, EquipPartID = 1, EquipLevel = 1, IntensifyLevel = 0,
            ResourceForIntensify = 100, MaxIntensifyLevel = 99 }
local vang = 1000
local TRAN = 3                 -- trần giả của luật: cấp 3 trở lên từ chối

EquipmentLogic = {}
function EquipmentLogic:IntensifyEquipment(h, p)
    if O.IntensifyLevel >= TRAN then return false, 1102 end
    if vang < O.ResourceForIntensify then return false, 1103 end
    vang = vang - O.ResourceForIntensify
    return true, 0
end
function EquipmentLogic:GetEquipment() return true, O end
function EquipmentLogic:updateEquipData(e)
    e.ResourceForIntensify = 100 * ((tonumber(e.IntensifyLevel) or 0) + 1)
    return true
end
ClientEquipmentLogic = {}
G_EquipmentLogic = setmetatable({}, { __index = EquipmentLogic })
G_EquipmentLogic[EquipmentLogic] = EquipmentLogic

G_EquipmentDataManager = {}
function G_EquipmentDataManager:SetEquipIntensifyLevel(h, p, lv)
    O.IntensifyLevel = lv
    return true
end

dofile([[__SC__/offline/handlers/trang_bi_cuong_hoa.lua]])
local R = require('offline.router')

local dat, hong = 0, 0
local function check(ok, ten, ct)
    if ok then dat = dat + 1; io.write('  OK   ' .. ten .. '\n')
    else hong = hong + 1; io.write('  HONG ' .. ten .. (ct ~= nil and (' -> ' .. tostring(ct)) or '') .. '\n') end
end
local function ctxGia()
    local c = { calls = {} }
    function c:call(obj, f, a, b, err_, ev, ...)
        self.calls[#self.calls + 1] = { obj = obj, f = f, a = a, b = b, err = err_,
                                        n = select('#', ...), args = { ... } }
    end
    return c
end

check(R:has('G_EquipmentLogic.ClientIntensifyEquipment'), 'dang ky ClientIntensifyEquipment')
check(R:has('G_EquipmentLogic.ClientAutoIntensifyEquipment'), 'dang ky ClientAutoIntensifyEquipment')

-- 1. cuong hoa mot cap
local c1 = ctxGia()
R.handlers['G_EquipmentLogic.ClientIntensifyEquipment'](c1, 1, 1)
local k1 = c1.calls[1]
check(k1 and k1.b == 'OnServerIntensifyEquipment' and k1.args[3] == 1 and O.IntensifyLevel == 1,
      'cuong hoa: cap 0 -> 1, callback (h,p,1)', k1 and tostring(O.IntensifyLevel))
check(vang == 900, 'tru dung 100 vang (luat goc lo)', vang)

-- 2. cuong hoa tiep den tran
local c2 = ctxGia()
R.handlers['G_EquipmentLogic.ClientIntensifyEquipment'](c2, 1, 1)
check(c2.calls[1] and c2.calls[1].args[3] == 2 and O.IntensifyLevel == 2, 'cap 1 -> 2', O.IntensifyLevel)

-- 3. tu dong: tu cap 2, tran 8, vang du -> +6 cap
TRAN = 8
vang = 100000          -- du cho 6 cap (300+400+500+600+700+800)
local c3 = ctxGia()
R.handlers['G_EquipmentLogic.ClientAutoIntensifyEquipment'](c3, 1, 1)
local k3 = c3.calls[1]
check(k3 and k3.b == 'OnServerAutoIntensifyEquipment' and k3.args[3] == 6 and O.IntensifyLevel == 8,
      'tu dong: +6 cap (2 -> 8), callback (h,p,soCap,conLai)', k3 and k3.args[3])

-- 4. het vang o cap dau: THANH CONG voi 0 cap (kieu Moc 54)
O.IntensifyLevel = 0
vang = 0
local c4 = ctxGia()
R.handlers['G_EquipmentLogic.ClientAutoIntensifyEquipment'](c4, 1, 1)
local k4 = c4.calls[1]
check(k4 and k4.b == 'OnServerAutoIntensifyEquipment' and k4.args[3] == 0,
      'tu dong het vang: thanh cong 0 cap', k4 and k4.args[3])

-- 5. tham so sai
local c5 = ctxGia()
R.handlers['G_EquipmentLogic.ClientIntensifyEquipment'](c5, nil, 1)
check(c5.calls[1] and c5.calls[1].err == 2 and c5.calls[1].a == '', 'tham so sai -> ma 2')

-- 6. luat goc tu choi (tran) -> ma cua luat
O.IntensifyLevel = 8
local c6 = ctxGia()
R.handlers['G_EquipmentLogic.ClientIntensifyEquipment'](c6, 1, 1)
check(c6.calls[1] and c6.calls[1].err == 1102, 'cham tran -> ma 1102 cua luat goc', c6.calls[1] and c6.calls[1].err)

check(OfflineStore.dongBo and OfflineStore.dongBo > 0, 'co goi syncFromClient')
io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
