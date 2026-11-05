-- _thu_canh_hien_thi.lua — bộ thử cho `offline/handlers/canh_hien_thi.lua`
-- (chạy bằng `python _thu_nha_cua.py _thu_canh_hien_thi.lua`).
--
-- Đo bốn thứ: cổng kiểm (cấp cánh / cánh ảo phải ĐANG CÓ), ghi đúng hàm gốc, phát đúng
-- hai sự kiện (client KHÔNG có hàm nhận cho hai lệnh này), và KHÔNG đụng dữ liệu khi hỏng.
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
    Hero = { NotFindHero = 1301 },
}
EventManagerLogicEvent = {
    OnReceiveResponse = 'OnReceiveResponse',
    Hero = { OnShowWing = 'OnShowWing' },
}
CUINotificationEvent = { OnServerRequestError = 'OnServerRequestError' }

-- ============================================================ GIẢ LẬP (toàn cục)
HERO = { UserHeroID = 25, WingLevel = 3, MagicWingList = { { MagicWingID = 7 }, 9 } }
-- Giả lập ghi trường: hàm gốc CHỈ post event, bên ghi là máy chủ — handler phải tự gán.
G_HeroLogic = {}
G_HeroLogic.KHONG_CO = false
function G_HeroLogic:GetHeroWithID(id)
    if self.KHONG_CO then return false end
    return true, HERO
end

G_HeroDataManager = {}
G_HeroDataManager.HONG = false
function G_HeroDataManager:SetHeroShowWingLevel(hero, cap)
    if self.HONG then return false end
    self.DA_GOI = { loai = 'wing', cap = cap, hero = hero }
    return true
end
function G_HeroDataManager:SetHeroShowMagicWingID(hero, id)
    if self.HONG then return false end
    self.DA_GOI = { loai = 'magic', id = id, hero = hero }
    return true
end
-- Ham ghi CO SAN va TU GAN truong (share_HeroDataManager.lua:1071-1088)
function G_HeroDataManager:SetIsCancelExclusive(hero, huy)
    self.DA_GOI = { loai = 'excl', huy = huy, hero = hero }
    if self.HONG then return false end
    hero.IsCancelExclusive = huy
    return true
end

G_EventManager = {}
EVENT = {}
function G_EventManager:PostLogicEvent(data, ev) EVENT[#EVENT + 1] = { data = data, ev = ev } end
THONG_BAO = {}
g_CUINotificationCenter = {}
function g_CUINotificationCenter:PostNotification(ev, ma) THONG_BAO[#THONG_BAO + 1] = ma end

dofile([[__SC__/offline/handlers/canh_hien_thi.lua]])
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
    HERO.ShowWingLevel, HERO.ShowMagicWingID = 0, 0
    EVENT, THONG_BAO = {}, {}
    G_HeroLogic.KHONG_CO = false
    G_HeroDataManager.HONG = false
    G_HeroDataManager.DA_GOI = nil
    OfflineStore.dongBo = 0
end
-- Lớp tải được tắt bằng `PostLogicEvent(<khoá>, OnReceiveResponse)` — khoá nằm ở DATA,
-- không phải tên sự kiện (viết sai là kiểm trượt dù handler đúng).
local function coLopTai(ten)
    for _, x in ipairs(EVENT) do
        if x.ev == 'OnReceiveResponse' and x.data == ten then return x end
    end
    return nil
end

local function coEvent(ten)
    for _, x in ipairs(EVENT) do if x.ev == ten then return x end end
    return nil
end

local KW = 'G_HeroLogic.ClientShowWing'
local KM = 'G_HeroLogic.ClientShowMagicWing'

-- ============================================================ 1. ĐĂNG KÝ
check(R:has(KW), 'dang ky ' .. KW)
check(R:has(KM), 'dang ky ' .. KM)
check(type(OfflineCanhHienThi) == 'table', 'co bang OfflineCanhHienThi')

-- ============================================================ 2. HIỆN CÁNH THƯỜNG OK
datLai()
R.handlers[KW](ctxGia(), 25, 3)
local g2 = G_HeroDataManager.DA_GOI
check(g2 and g2.loai == 'wing' and g2.cap == 3 and g2.hero == HERO,
      'goi DUNG SetHeroShowWingLevel(tuong, 3)', g2 and (g2.loai .. '/' .. tostring(g2.cap)))
check(coLopTai('ClientShowWing') ~= nil, 'tat dung lop tai cua ClientShowWing')
check(coEvent('OnShowWing') ~= nil, 'phat Hero.OnShowWing (UI ve lai sprite)')
check(HERO.ShowWingLevel == 3 and HERO.ShowMagicWingID == 0,
      'GHI THANG truong theo payload (ShowWingLevel=3, ShowMagicWingID=0)',
      tostring(HERO.ShowWingLevel) .. '/' .. tostring(HERO.ShowMagicWingID))
check(#THONG_BAO == 0, 'thanh cong -> khong toast loi')
check(OfflineStore.dongBo >= 1, 'co dong bo file luu')

-- ============================================================ 3. CẤP CÁNH VƯỢT SỐ ĐANG CÓ
datLai()
R.handlers[KW](ctxGia(), 25, 9)
check(G_HeroDataManager.DA_GOI == nil, 'cap 9 > dang co 3 -> KHONG ghi')
check(THONG_BAO[1] == ErrorCode.ArgError, 'cap vuot -> ma 2', THONG_BAO[1])
check(coEvent('OnShowWing') == nil, 'that bai -> khong phat OnShowWing')

-- ============================================================ 4. BỎ HIỆN (0) VẪN HỢP LỆ
datLai()
R.handlers[KW](ctxGia(), 25, 0)
check(G_HeroDataManager.DA_GOI and G_HeroDataManager.DA_GOI.cap == 0,
      'cap 0 (bo hien) -> ghi duoc')

-- ============================================================ 5. CÁNH ẢO ĐANG CÓ
datLai()
R.handlers[KM](ctxGia(), 25, 7)
local g5 = G_HeroDataManager.DA_GOI
check(g5 and g5.loai == 'magic' and g5.id == 7, 'canh ao 7 (co trong danh sach) -> ghi')
check(coLopTai('ClientShowMagicWing') ~= nil, 'tat dung lop tai cua ClientShowMagicWing')
datLai()
R.handlers[KM](ctxGia(), 25, 9)    -- 9 là số trần trong danh sách
check(G_HeroDataManager.DA_GOI and G_HeroDataManager.DA_GOI.id == 9,
      'canh ao dang so (9) cung nhan')

-- ============================================================ 6. CÁNH ẢO KHÔNG CÓ
datLai()
R.handlers[KM](ctxGia(), 25, 99)
check(G_HeroDataManager.DA_GOI == nil, 'canh ao 99 khong co -> KHONG ghi')
check(THONG_BAO[1] == ErrorCode.ArgError, 'canh ao la -> ma 2', THONG_BAO[1])

-- ============================================================ 7. KHÔNG CÓ TƯỚNG
datLai()
G_HeroLogic.KHONG_CO = true
R.handlers[KW](ctxGia(), 99, 1)
check(THONG_BAO[1] == ErrorCode.Hero.NotFindHero, 'khong co tuong -> ma 1301', THONG_BAO[1])
G_HeroLogic.KHONG_CO = false

-- ============================================================ 8. GHI HỎNG
datLai()
G_HeroDataManager.HONG = true
R.handlers[KW](ctxGia(), 25, 1)
G_HeroDataManager.HONG = false
check(THONG_BAO[1] == ErrorCode.UnknowError, 'ghi hong -> ma 1', THONG_BAO[1])
check(coEvent('OnShowWing') == nil, 'ghi hong -> khong phat OnShowWing')

-- ============================================================ 8b. TRANG PHỤC ĐỘC QUYỀN
local KE = 'G_HeroLogic.ClientSetExclusiveSkinState'
check(R:has(KE), 'dang ky ' .. KE)
datLai()
HERO.IsCancelExclusive = nil
R.handlers[KE](ctxGia(), 25, true)
check(G_HeroDataManager.DA_GOI and G_HeroDataManager.DA_GOI.loai == 'excl'
      and G_HeroDataManager.DA_GOI.huy == true,
      'goi DUNG SetIsCancelExclusive(tuong, true)', G_HeroDataManager.DA_GOI and tostring(G_HeroDataManager.DA_GOI.huy))
check(HERO.IsCancelExclusive == true, 'ham goc tu gan truong -> IsCancelExclusive = true',
      tostring(HERO.IsCancelExclusive))
check(coLopTai('ClientSetExclusiveSkinState') ~= nil,
      'tu tat lop tai (ham nhan cua client KHONG tu tat)')
check(OfflineStore.dongBo >= 1, 'co dong bo file luu')

datLai()
R.handlers[KE](ctxGia(), 25, false)
check(HERO.IsCancelExclusive == false, 'bat hien lai -> IsCancelExclusive = false')

datLai()
G_HeroLogic.KHONG_CO = true
R.handlers[KE](ctxGia(), 99, true)
G_HeroLogic.KHONG_CO = false
check(THONG_BAO[1] == ErrorCode.Hero.NotFindHero, 'khong co tuong -> 1301', THONG_BAO[1])

-- ============================================================ 9. THAM SỐ SAI
datLai()
R.handlers[KW](ctxGia(), 'x', 1)
check(THONG_BAO[1] == ErrorCode.ArgError and G_HeroDataManager.DA_GOI == nil,
      'tham so sai -> ma 2, khong ghi')

io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
