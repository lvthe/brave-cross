-- _thu_trang_bi_pham.lua — bộ thử cho `offline/handlers/trang_bi_pham.lua`
-- (chạy bằng `python _thu_nha_cua.py _thu_trang_bi_pham.lua`).
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

local O = {
    HeroID = 1, EquipPartID = 1, EquipmentType = 1, Quality = 2, EquipLevel = 3,
    AppendPropertyRandomRangeMin = 0.8, AppendPropertyRandomRangeMax = 1.3,
    AppendProperty = {
        { PropertyType = 1, BaseValue = 1.0, Value = 0 },
        { PropertyType = 16, BaseValue = 0.9, Value = 0 },
    },
}
local vang = 50000

EquipmentLogic = {}
function EquipmentLogic:PromoteQualityEquipment()
    if O.Quality >= 5 then return false, 1105 end
    O.Quality = O.Quality + 1
    return true, 0
end
function EquipmentLogic:RecastEquipment(h, p, rt)
    if rt == 20 then return false, 2 end       -- giả: kim cương bị từ chối
    if vang < 10000 then return false, 1103 end
    vang = vang - 10000
    return true, 0
end
function EquipmentLogic:GetEquipment() return true, O end
function EquipmentLogic:getAppendPropertyValue(base, pt, q, lvl)
    if base == nil or pt == nil or q == nil or lvl == nil then return false, nil end
    return true, 2 * (base * q - 0.3) * 5     -- coef 2, hệ số cấp 100/20 = 5
end
function EquipmentLogic:updateAppendProperty(e)
    for _, ap in ipairs(e.AppendProperty) do
        local ok, _, v = true, nil, nil
        local b, vv = self:getAppendPropertyValue(ap.BaseValue, ap.PropertyType, e.Quality, e.EquipLevel, e.EquipmentType)
        ap.Value = vv
    end
    return true
end
function EquipmentLogic:updateEquipData() return true end
ClientEquipmentLogic = {}
G_EquipmentLogic = setmetatable({}, { __index = EquipmentLogic })
G_EquipmentLogic[EquipmentLogic] = EquipmentLogic

dofile([[__SC__/offline/handlers/trang_bi_pham.lua]])
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

check(R:has('G_EquipmentLogic.ClientPromoteQualityEquipment'), 'dang ky Promote')
check(R:has('G_EquipmentLogic.ClientRecastEquipment'), 'dang ky Recast')

-- 1. nâng phẩm: 2 -> 3, Value tính lại theo Quality MỚI
local c1 = ctxGia()
R.handlers['G_EquipmentLogic.ClientPromoteQualityEquipment'](c1, 1, 1)
local k1 = c1.calls[1]
check(k1 and k1.b == 'OnServerPromoteQualityEquipment' and #k1.args == 3 and type(k1.args[3]) == 'table',
      'nang pham: callback (h,p,danh sach)', k1 and k1.b)
check(O.Quality == 3, 'pham 2 -> 3', O.Quality)
check(math.abs(O.AppendProperty[1].Value - (2 * (1.0 * 3 - 0.3) * 5)) < 1e-9,
      'Value tinh lai theo Quality MOI, GIU BaseValue=1.0', O.AppendProperty[1].Value)
check(O.AppendProperty[1].BaseValue == 1.0, 'BaseValue KHONG doi khi nang pham', O.AppendProperty[1].BaseValue)

-- 2. nâng phẩm tới trần -> mã của luật gốc
O.Quality = 5
local c2 = ctxGia()
R.handlers['G_EquipmentLogic.ClientPromoteQualityEquipment'](c2, 1, 1)
check(c2.calls[1] and c2.calls[1].err == 1105 and c2.calls[1].a == '',
      'cham tran pham -> 1105, khong callback', c2.calls[1] and c2.calls[1].err)

-- 3. tẩy luyện: BaseValue bốc lại 0.8..1.3, Value tính lại
local c3 = ctxGia()
R.handlers['G_EquipmentLogic.ClientRecastEquipment'](c3, 1, 1, 1)
local k3 = c3.calls[1]
check(k3 and k3.b == 'OnServerRecastEquipment' and #k3.args == 4 and k3.args[3] == 1,
      'tay luyen: callback (h,p,resourceType,danh sach)', k3 and k3.b)
local bv = O.AppendProperty[1].BaseValue
check(bv >= 0.8 and bv <= 1.3, 'BaseValue trong 0,8..1,3', bv)
check(math.abs(O.AppendProperty[1].Value - (2 * (bv * O.Quality - 0.3) * 5)) < 1e-9,
      'Value = coef*(Base*Quality-0,3)*(he so cap/20)', O.AppendProperty[1].Value)
check(vang == 40000, 'tru 10000 vang (luat goc)', vang)

-- 4. bốc lại THẬT: 5 lượt phải ra nhiều hơn một giá trị
local thay = {}
for _ = 1, 5 do
    local c = ctxGia()
    R.handlers['G_EquipmentLogic.ClientRecastEquipment'](c, 1, 1, 1)
    thay[tostring(O.AppendProperty[1].BaseValue)] = true
end
local soKhac = 0
for _ in pairs(thay) do soKhac = soKhac + 1 end
check(soKhac >= 2, '5 luot tay luyen ra >= 2 gia tri BaseValue khac nhau', soKhac)

-- 5. luật gốc từ chối (kim cương) -> mã 2
local c5 = ctxGia()
R.handlers['G_EquipmentLogic.ClientRecastEquipment'](c5, 1, 1, 20)
check(c5.calls[1] and c5.calls[1].err == 2, 'luat goc tu choi -> ma 2', c5.calls[1] and c5.calls[1].err)

-- 6. hết vàng
vang = 0
local c6 = ctxGia()
R.handlers['G_EquipmentLogic.ClientRecastEquipment'](c6, 1, 1, 1)
check(c6.calls[1] and c6.calls[1].err == 1103, 'het vang -> 1103', c6.calls[1] and c6.calls[1].err)

-- 7. tham số sai
local c7 = ctxGia()
R.handlers['G_EquipmentLogic.ClientRecastEquipment'](c7, 1, nil, 1)
check(c7.calls[1] and c7.calls[1].err == 2, 'tham so sai -> 2', c7.calls[1] and c7.calls[1].err)

check(OfflineStore.dongBo and OfflineStore.dongBo > 0, 'co goi syncFromClient')
io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
