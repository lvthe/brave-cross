-- _thu_luyen_vat_pham.lua — bộ thử cho `offline/handlers/luyen_vat_pham.lua`
-- (chạy bằng `python _thu_nha_cua.py _thu_luyen_vat_pham.lua`).
--
-- Đo bốn thứ dễ hỏng nhất của một lệnh "trừ N món rồi cộng điểm":
--   1. KIỂM HẾT trước khi TRỪ (không trừ dở).
--   2. Tỉ lệ đúng: `Config.Concentrate × Count` — số UI đã hiện cho người chơi.
--   3. Trừ hỏng giữa chừng -> HOÀN LẠI món đã trừ.
--   4. Phát đúng hai sự kiện client chờ (client KHÔNG có hàm nhận cho lệnh này).
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
    Item = { NotEnoughItem = 1201, ReduceItemError = 1202, GetItemConfigFail = 1203 },
}
EventManagerLogicEvent = { OnReceiveResponse = 'OnReceiveResponse' }
CUINotificationEvent = { OnServerRequestError = 'OnServerRequestError' }

-- ============================================================ GIẢ LẬP (toàn cục)
ITEMCFG = {
    [10] = { Concentrate = 3 },
    [11] = { Concentrate = 5 },
    [12] = {},                 -- thiếu Concentrate
}
G_ConfigManager = {}
function G_ConfigManager:GetItemConfigWithId(id) return ITEMCFG[id] end

KHO = { [10] = 10, [11] = 4 }
ITEMLOGIC = { HONG_O = nil }
G_ItemLogic = {}
function G_ItemLogic:GetItemCount(id) return true, (KHO[id] or 0) end   -- (ok, n) nhu ban goc
function G_ItemLogic:AddItem(id, n, from) KHO[id] = (KHO[id] or 0) + n; return true end

G_ItemDataManager = {}
function G_ItemDataManager:ReduceItem(id, n, from)
    if ITEMLOGIC.HONG_O == id then return false end
    if (KHO[id] or 0) < n then return false end
    KHO[id] = KHO[id] - n
    return true
end

TINH_HOA = 0
G_UserLogic = {}
function G_UserLogic:AddConcentrate(n, from) TINH_HOA = TINH_HOA + n; return true end

G_EventManager = {}
EVENT = {}
function G_EventManager:PostLogicEvent(data, ev) EVENT[#EVENT + 1] = { data = data, ev = ev } end

THONG_BAO = {}
g_CUINotificationCenter = {}
function g_CUINotificationCenter:PostNotification(ev, ma) THONG_BAO[#THONG_BAO + 1] = ma end

dofile([[__SC__/offline/handlers/luyen_vat_pham.lua]])
local R = require('offline.router')

local dat, hong = 0, 0
local function check(ok, ten, ct)
    if ok then dat = dat + 1; io.write('  OK   ' .. ten .. '\n')
    else hong = hong + 1; io.write('  HONG ' .. ten .. (ct ~= nil and (' -> ' .. tostring(ct)) or '') .. '\n') end
end
local function ctxGia()
    local c = {}
    function c:call(...) end
    return c
end
local function datLai()
    KHO = { [10] = 10, [11] = 4 }
    TINH_HOA, THONG_BAO, EVENT = 0, {}, {}
    ITEMLOGIC.HONG_O = nil
end
local function coEvent(ten)
    for _, x in ipairs(EVENT) do if x.ev == ten then return x end end
    return nil
end

local KHOA = 'G_ItemLogic.ClientRefineItem'
local function goi(...) R.handlers[KHOA](ctxGia(), ...) end

-- ============================================================ 1. ĐĂNG KÝ
check(R:has(KHOA), 'dang ky ' .. KHOA)
check(type(OfflineLuyenVatPham) == 'table', 'co bang OfflineLuyenVatPham')

-- ============================================================ 2. LUYỆN OK
datLai()
goi({ { ItemId = 10, Count = 2 }, { ItemId = 11, Count = 1 } })
check(KHO[10] == 8 and KHO[11] == 3, 'tru dung so vat pham (10: 10->8, 11: 4->3)',
      (KHO[10] or 0) .. '/' .. (KHO[11] or 0))
check(TINH_HOA == 3 * 2 + 5 * 1, 'cong DUNG Concentrate x Count = 11', TINH_HOA)
check(coEvent('OnReceiveResponse') ~= nil, 'phat OnReceiveResponse (tat lop tai)')
check(coEvent('ClientRefineItem') ~= nil, 'phat su kien ClientRefineItem (UI chay hoat anh)')
check(#THONG_BAO == 0, 'thanh cong -> khong toast loi', #THONG_BAO)

-- ============================================================ 3. THIẾU MÓN -> KHÔNG TRỪ GÌ
datLai()
goi({ { ItemId = 10, Count = 2 }, { ItemId = 11, Count = 99 } })
check(KHO[10] == 10 and KHO[11] == 4, 'kiem HET truoc khi tru: mon 10 VAN CON NGUYEN',
      (KHO[10] or 0) .. '/' .. (KHO[11] or 0))
check(TINH_HOA == 0, 'thieu mon -> khong cong tinh hoa')
check(THONG_BAO[1] == ErrorCode.Item.NotEnoughItem, 'thieu mon -> ma 1201', THONG_BAO[1])
check(coEvent('ClientRefineItem') == nil, 'that bai -> khong phat su kien thanh cong')

-- ============================================================ 4. THIẾU CẤU HÌNH
datLai()
goi({ { ItemId = 12, Count = 1 } })
check(THONG_BAO[1] == ErrorCode.Item.GetItemConfigFail, 'vat pham thieu Concentrate -> ma 1203',
      THONG_BAO[1])
check(KHO[10] == 10, 'khong tru gi')

-- ============================================================ 5. TRỪ HỎNG GIỮA CHỪNG -> HOÀN LẠI
datLai()
ITEMLOGIC.HONG_O = 11
goi({ { ItemId = 10, Count = 2 }, { ItemId = 11, Count = 1 } })
check(THONG_BAO[1] == ErrorCode.Item.ReduceItemError, 'tru hong -> ma 1202', THONG_BAO[1])
check(KHO[10] == 10, 'mon truoc da duoc HOAN LAI (10: 8 -> 10)', KHO[10])
check(TINH_HOA == 0, 'khong cong tinh hoa khi tru hong')
ITEMLOGIC.HONG_O = nil

-- ============================================================ 6. DANH SÁCH RỖNG / SAI
datLai()
goi({})
check(THONG_BAO[1] == ErrorCode.ArgError, 'danh sach rong -> ma 2', THONG_BAO[1])
THONG_BAO = {}
goi('khong-phai-bang')
check(THONG_BAO[1] == ErrorCode.ArgError, 'tham so khong phai bang -> ma 2', THONG_BAO[1])
check(KHO[10] == 10, 'khong tru gi')

io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
