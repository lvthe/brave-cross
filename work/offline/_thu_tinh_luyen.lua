-- _thu_tinh_luyen.lua — bộ thử cho `offline/handlers/tinh_luyen_trang_bi.lua`
-- (chạy bằng `python _thu_nha_cua.py _thu_tinh_luyen.lua`).
--
-- KHÔNG thử ở đây: bàn giao của luật máy chủ (không ship). Bộ này đo ĐÚNG bốn cửa mà
-- mã lỗi gốc 1106/1109/1110 mô tả + hình phản hồi (hàm nhận KHÔNG đối số).
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
    Equipment = {
        NotFindEquipment = 1101,
        SetEquipIntensifyLevel = 1104,
        NotEquipmentExist = 1106,
        NotEnoughConcentrate = 1109,
        MaxRefineLevelCantRefine = 1110,
    },
}
CUINotificationEvent = { OnServerRequestError = 'OnServerRequestError' }

-- ============================================================ GIẢ LẬP
local CFG = {
    [1] = { { NeedConcentrate = 40, AddPrecent = 5 },
            { NeedConcentrate = 80, AddPrecent = 10 } },
}
G_ConfigManager = {}
function G_ConfigManager:GetCommonConfigWithName(ten)
    if ten == 'EquipRefineConfig' then return CFG end
    return nil
end

local EQUIP = { EquipPartID = 1, RefineLevel = 0, EquipLevel = 3 }
G_EquipmentLogic = {}   -- PHAI la bien TOAN CUC: handler chay o chunk khac
function G_EquipmentLogic:GetEquipment(hero, part)
    if self.KHONG_CO then return false end
    return true, EQUIP
end
function G_EquipmentLogic:updateEquipData(e) self.DA_CAP_NHAT = (self.DA_CAP_NHAT or 0) + 1 end

local DM = { HONG = false }
G_EquipmentDataManager = {}   -- toan cuc
function G_EquipmentDataManager:SetEquipRefineLevel(hero, part, cap)
    self.DA_DAT = { hero = hero, part = part, cap = cap }
    if DM.HONG then return false end
    EQUIP.RefineLevel = cap
    return true
end

local USER = { TINH_HOA = 100 }
G_UserLogic = {}   -- toan cuc
function G_UserLogic:CostConcentrate(n, from)
    if USER.TINH_HOA - n < 0 then return false, 'thieu' end
    USER.TINH_HOA = USER.TINH_HOA - n
    return true
end
function G_UserLogic:GetConcentrate() return true, USER.TINH_HOA end
function G_UserLogic:AddConcentrate(n, from) USER.TINH_HOA = USER.TINH_HOA + n; return true end

local THONG_BAO = {}
g_CUINotificationCenter = {}
function g_CUINotificationCenter:PostNotification(ev, ma) THONG_BAO[#THONG_BAO + 1] = ma end

dofile([[__SC__/offline/handlers/tinh_luyen_trang_bi.lua]])
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
local KHOA = 'G_EquipmentLogic.ClientRefineEquip'
local function goi(...)
    local c = ctxGia()
    R.handlers[KHOA](c, ...)
    return c
end
local function datLai()
    EQUIP.RefineLevel, EQUIP.EquipPartID = 0, 1
    USER.TINH_HOA = 100
    THONG_BAO = {}
    G_EquipmentLogic.KHONG_CO = false
    G_EquipmentLogic.DA_CAP_NHAT = 0
    DM.HONG = false
    G_EquipmentDataManager.DA_DAT = nil
    OfflineStore.dongBo = 0
end

-- ============================================================ 1. ĐĂNG KÝ
check(R:has(KHOA), 'dang ky ' .. KHOA)
check(type(OfflineTinhLuyen) == 'table', 'co bang OfflineTinhLuyen')

-- ============================================================ 2. NÂNG CẤP OK
datLai()
local c2 = goi(9, 1)
check(EQUIP.RefineLevel == 1, 'tang cap 0 -> 1', EQUIP.RefineLevel)
check(USER.TINH_HOA == 60, 'tru DUNG 40 tinh hoa (cau hinh cap 1)', USER.TINH_HOA)
check(G_EquipmentDataManager.DA_DAT and G_EquipmentDataManager.DA_DAT.cap == 1,
      'goi SetEquipRefineLevel(cap 1)')
check(G_EquipmentLogic.DA_CAP_NHAT == 1, 'goi updateEquipData de tinh lai thuoc tinh')
check(OfflineStore.dongBo >= 1, 'co dong bo file luu')
local x2 = c2.calls[#c2.calls]
check(x2 and x2.obj == 'G_EquipmentLogic' and x2.f == 'OnRefineEquip' and x2.n == 0,
      'tra loi OnRefineEquip KHONG doi so', x2 and (x2.f .. '/' .. x2.n))
check(#THONG_BAO == 0, 'thanh cong -> khong co toast loi', #THONG_BAO)

-- ============================================================ 3. THIẾU TINH HOA
datLai()
USER.TINH_HOA = 10
local c3 = goi(9, 1)
check(EQUIP.RefineLevel == 0, 'thieu tinh hoa -> cap KHONG doi', EQUIP.RefineLevel)
check(THONG_BAO[1] == ErrorCode.Equipment.NotEnoughConcentrate, 'thieu tinh hoa -> ma 1109',
      THONG_BAO[1])
check(c3.calls[#c3.calls] and c3.calls[#c3.calls].f == 'OnRefineEquip',
      'van tra OnRefineEquip (client tat lop tai)')

-- ============================================================ 4. ĐÃ MAX
datLai()
EQUIP.RefineLevel = 2
local c4 = goi(9, 1)
check(THONG_BAO[1] == ErrorCode.Equipment.MaxRefineLevelCantRefine, 'cap toi da -> ma 1110',
      THONG_BAO[1])
check(USER.TINH_HOA == 100, 'cap toi da -> KHONG tru tinh hoa', USER.TINH_HOA)

-- ============================================================ 5. KHÔNG CÓ TRANG BỊ
datLai()
G_EquipmentLogic.KHONG_CO = true
local c5 = goi(9, 1)
check(THONG_BAO[1] == ErrorCode.Equipment.NotFindEquipment, 'khong co trang bi -> ma 1101',
      THONG_BAO[1])
G_EquipmentLogic.KHONG_CO = false

-- ============================================================ 6. THAM SỐ SAI
datLai()
goi('x', 1)
check(THONG_BAO[1] == ErrorCode.ArgError and USER.TINH_HOA == 100, 'tham so sai -> ma 2, khong tru')

-- ============================================================ 7. GHI CẤP HỎNG -> HOÀN TINH HOA
datLai()
DM.HONG = true
goi(9, 1)
DM.HONG = false
check(USER.TINH_HOA == 100, 'SetEquipRefineLevel hong -> HOAN lai tinh hoa da tru',
      USER.TINH_HOA)
check(THONG_BAO[1] == ErrorCode.Equipment.SetEquipIntensifyLevel, 'ghi cap hong -> ma 1104',
      THONG_BAO[1])

io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
