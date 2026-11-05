-- _thu_manh_van_nang.lua — bộ thử cho `offline/handlers/manh_van_nang.lua`
-- (chạy bằng `python _thu_nha_cua.py _thu_manh_van_nang.lua`).
--
-- Đo: danh sách trắng, trừ mảnh vạn năng ĐÚNG số, cộng mảnh tướng, HOÀN khi cộng hỏng,
-- và hai sự kiện client chờ (client KHÔNG có hàm nhận cho lệnh này).
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
    Hero = {
        NotFindHero = 1301,
        GetGrowthConfigFail = 1305,
        NotFindHeroConfig = 1308,
        SetHeroFragmentFail = 1309,
    },
}
EventManagerLogicEvent = {
    OnReceiveResponse = 'OnReceiveResponse',
    Hero = { OnConvertUniversalFragment = 'OnConvertUniversalFragment' },
}
CUINotificationEvent = { OnServerRequestError = 'OnServerRequestError' }

-- ============================================================ GIẢ LẬP (toàn cục)
BANG_TRANG = { ['25'] = 1, ['47'] = 1 }     -- tướng đổi được
G_ConfigManager = {}
function G_ConfigManager:GetCommonConfigWithName(ten)
    if ten == 'GameUniversalFragmentConfig' then return BANG_TRANG end
    return nil
end

HERO = { UserHeroID = 25, HeroFragment = 0 }
G_HeroLogic = {}
G_HeroLogic.UniversalFragmentID = 20
G_HeroLogic.KHONG_CO, G_HeroLogic.HONG_CONG = nil, false
function G_HeroLogic:GetHeroWithID(id)
    if self.KHONG_CO then return false end
    return true, HERO
end
function G_HeroLogic:AddHeroFragment(id, n, from)
    if self.HONG_CONG then return false, ErrorCode.Hero.SetHeroFragmentFail end
    HERO.HeroFragment = (HERO.HeroFragment or 0) + n
    return true
end

KHO = { [20] = 10 }
G_ItemLogic = {}
function G_ItemLogic:GetItemCount(id) return true, (KHO[id] or 0) end
function G_ItemLogic:AddItem(id, n, from) KHO[id] = (KHO[id] or 0) + n; return true end

G_ItemDataManager = {}
function G_ItemDataManager:ReduceItem(id, n, from)
    if (KHO[id] or 0) < n then return false end
    KHO[id] = KHO[id] - n
    return true
end

EVENT = {}
G_EventManager = {}
function G_EventManager:PostLogicEvent(data, ev) EVENT[#EVENT + 1] = { data = data, ev = ev } end
THONG_BAO = {}
g_CUINotificationCenter = {}
function g_CUINotificationCenter:PostNotification(ev, ma) THONG_BAO[#THONG_BAO + 1] = ma end

dofile([[__SC__/offline/handlers/manh_van_nang.lua]])
local R = require('offline.router')

local dat, hong = 0, 0
local function check(ok, ten, ct)
    if ok then dat = dat + 1; io.write('  OK   ' .. ten .. '\n')
    else hong = hong + 1; io.write('  HONG ' .. ten .. (ct ~= nil and (' -> ' .. tostring(ct)) or '') .. '\n') end
end
local function ctxGia() local c = {}; function c:call(...) end; return c end
local function datLai()
    KHO[20] = 10
    HERO.HeroFragment = 0
    G_HeroLogic.KHONG_CO, G_HeroLogic.HONG_CONG = nil, false
    EVENT, THONG_BAO = {}, {}
    OfflineStore.dongBo = 0
end
local function coEvent(ten)
    for _, x in ipairs(EVENT) do if x.ev == ten then return x end end
    return nil
end
local function coLopTai(ten)
    for _, x in ipairs(EVENT) do
        if x.ev == 'OnReceiveResponse' and x.data == ten then return x end
    end
    return nil
end

local KHOA = 'G_HeroLogic.ClientConvertUniversalFragment'
local function goi(...) R.handlers[KHOA](ctxGia(), ...) end

-- ============================================================ 1. ĐĂNG KÝ
check(R:has(KHOA), 'dang ky ' .. KHOA)
check(type(OfflineManhVanNang) == 'table', 'co bang OfflineManhVanNang')

-- ============================================================ 2. ĐỔI OK
datLai()
goi(25, 3)
check(KHO[20] == 7, 'tru DUNG 3 manh van nang (10 -> 7)', KHO[20])
check(HERO.HeroFragment == 3, 'cong 3 manh tuong', HERO.HeroFragment)
local ev2 = coEvent('OnConvertUniversalFragment')
check(ev2 and type(ev2.data) == 'table' and ev2.data.HeroID == 25 and ev2.data.Count == 3,
      'phat su kien {HeroID=25, Count=3}',
      ev2 and (tostring(ev2.data.HeroID) .. '/' .. tostring(ev2.data.Count)))
check(coLopTai('ClientIntensifyWing') ~= nil,
      'tat dung lop tai ma ham gui da bat ("ClientIntensifyWing")')
check(OfflineStore.dongBo >= 1, 'co dong bo file luu')
check(#THONG_BAO == 0, 'thanh cong -> khong toast loi')

-- ============================================================ 3. TƯỚNG KHÔNG TRONG DANH SÁCH TRẮNG
datLai()
BANG_TRANG['25'] = nil
goi(25, 1)
BANG_TRANG['25'] = 1
check(KHO[20] == 10 and HERO.HeroFragment == 0, 'ngoai danh sach trang -> khong tru/cong')
check(THONG_BAO[1] == ErrorCode.Hero.NotFindHeroConfig, 'ngoai danh sach trang -> ma 1308',
      THONG_BAO[1])
check(coEvent('OnConvertUniversalFragment') == nil, 'that bai -> khong phat su kien thuong')

-- ============================================================ 4. THIẾU MẢNH VẠN NĂNG
datLai()
KHO[20] = 2
goi(25, 5)
check(KHO[20] == 2 and HERO.HeroFragment == 0, 'thieu -> khong tru/cong')
check(THONG_BAO[1] == ErrorCode.Item.NotEnoughItem, 'thieu van nang -> ma 1201', THONG_BAO[1])

-- ============================================================ 5. KHÔNG CÓ TƯỚNG
datLai()
G_HeroLogic.KHONG_CO = true
goi(25, 1)
G_HeroLogic.KHONG_CO = nil
check(THONG_BAO[1] == ErrorCode.Hero.NotFindHero, 'khong co tuong -> ma 1301', THONG_BAO[1])

-- ============================================================ 6. CỘNG MẢNH HỎNG -> HOÀN
datLai()
G_HeroLogic.HONG_CONG = true
goi(25, 4)
G_HeroLogic.HONG_CONG = false
check(KHO[20] == 10, 'cong manh tuong hong -> HOAN lai 4 manh van nang', KHO[20])
check(THONG_BAO[1] == ErrorCode.Hero.SetHeroFragmentFail, 'cong hong -> ma 1309', THONG_BAO[1])
check(coEvent('OnConvertUniversalFragment') == nil, 'cong hong -> khong phat su kien thuong')

-- ============================================================ 6b. KHOÁ CẤU HÌNH LÀ SỐ
datLai()
BANG_TRANG = { [25] = 1 }      -- khoá SỐ, không phải chuỗi
goi(25, 2)
BANG_TRANG = { ['25'] = 1, ['47'] = 1 }
check(KHO[20] == 8 and HERO.HeroFragment == 2,
      'cau hinh khoa SO van nhan (khong tu choi oan)', KHO[20] .. '/' .. HERO.HeroFragment)

-- ============================================================ 6c. THIẾU CẤU HÌNH -> ĐI TIẾP
datLai()
BANG_TRANG = nil          -- GetCommonConfigWithName tra nil
goi(25, 2)
BANG_TRANG = { ['25'] = 1, ['47'] = 1 }
check(KHO[20] == 8 and HERO.HeroFragment == 2,
      'thieu cau hinh -> KHONG chan nguoi choi (UI da tu gac)', KHO[20] .. '/' .. HERO.HeroFragment)

-- ============================================================ 7. THAM SỐ SAI
datLai()
goi(25, 0)
check(THONG_BAO[1] == ErrorCode.ArgError and KHO[20] == 10, 'nCount 0 -> ma 2, khong tru')

io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
