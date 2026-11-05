-- _thu_vo_hon.lua — bộ thử cho `offline/handlers/vo_hon.lua`
-- (chạy bằng `python _thu_nha_cua.py _thu_vo_hon.lua`).
--
-- Đo: tỉ lệ (SuccessRate + (bội-1)×10, chặn 100), giá (vàng KHÔNG nhân, vật liệu NHÂN),
-- hoàn vàng khi trừ vật liệu hỏng, và ba mã kết quả 1/2/3 mà client đọc.
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

CUINotificationEvent = { OnServerRequestError = 'OnServerRequestError' }

ErrorCode = {
    OK = 0,
    UnknowError = 1,
    ArgError = 2,
    Common = { NotEnoughGold = 500 },
    Item = { NotEnoughItem = 1201, ReduceItemError = 1202 },
    Hero = {
        NotFindHero = 1301,
        UpHeroFightSoulLevelLimit = 1325,
        GetFightSoulConfigFail = 1326,
    },
}

-- ============================================================ GIẢ LẬP (toàn cục)
CFG = {
    [1] = { CostGold = 5000, SuccessRate = 100, NeedLevel = 0,
            MaterialList = { { MaterialID = 103, Count = 1 } } },
    [2] = { CostGold = 6000, SuccessRate = 60, NeedLevel = 10,
            MaterialList = { { MaterialID = 103, Count = 2 } } },
    [3] = { CostGold = 0, SuccessRate = 0, NeedLevel = 0 },   -- dòng "hết cấp"
}
G_ConfigManager = {}
function G_ConfigManager:GetHeroSoulConfig() return CFG end

HERO = { UserHeroID = 25, FightSoulLevel = 0, HeroLevel = 50 }
G_HeroLogic = {}
G_HeroLogic.KHONG_CO = false
function G_HeroLogic:GetHeroWithID(id)
    if self.KHONG_CO then return false end
    return true, HERO
end
function G_HeroLogic:GetUpgradeSoulCost(base, boi) return base * (boi or 1) end

VANG = 100000
G_UserLogic = {}
function G_UserLogic:GetGold() return true, VANG end
function G_UserLogic:CostGold(n, from)
    if VANG < n then return false end
    VANG = VANG - n
    return true
end
function G_UserLogic:AddGold(n, from) VANG = VANG + n; return true end

KHO = { [103] = 100 }
G_ItemLogic = {}
function G_ItemLogic:GetItemCount(id) return true, (KHO[id] or 0) end

G_ItemDataManager = {}
G_ItemDataManager.HONG = false
function G_ItemDataManager:ReduceItem(id, n, from)
    if self.HONG then return false end
    if (KHO[id] or 0) < n then return false end
    KHO[id] = KHO[id] - n
    return true
end

THONG_BAO = {}
g_CUINotificationCenter = {}
function g_CUINotificationCenter:PostNotification(ev, ma) THONG_BAO[#THONG_BAO + 1] = ma end

dofile([[__SC__/offline/handlers/vo_hon.lua]])
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
local function datLai()
    HERO.FightSoulLevel, HERO.HeroLevel = 0, 50
    VANG, KHO[103] = 100000, 100
    G_HeroLogic.KHONG_CO = false
    G_ItemDataManager.HONG = false
    THONG_BAO = {}
    OfflineStore.dongBo = 0
end
local function ketQua(c)
    local x = c.calls[#c.calls]
    return x and x.args[1], x
end

-- math.random điều khiển được: trả đúng số đầu tiên trong danh sách.
local RAND_GOC = math.random
local QUE_RAND = {}
local function datRand(...) QUE_RAND = { ... } end
math.random = function ()
    local v = QUE_RAND[1]
    if v ~= nil then table.remove(QUE_RAND, 1); return v end
    return 1
end

local KHOA = 'G_HeroLogic.ClientUpHeroFightSoul'
local function goi(...) R.handlers[KHOA](ctxGia(), ...) end

-- ============================================================ 1. ĐĂNG KÝ
check(R:has(KHOA), 'dang ky ' .. KHOA)
check(type(OfflineVoHon) == 'table', 'co bang OfflineVoHon')

-- ============================================================ 2. CẤP 1: 100% -> CHẮC THẮNG
datLai()
datRand(100)
local c2 = ctxGia()
R.handlers[KHOA](c2, 25, 1)
local kq2, x2 = ketQua(c2)
check(kq2 == 1, 'ti le 100% -> ket qua 1 (thanh cong)', kq2)
check(HERO.FightSoulLevel == 1, 'cap vo hon 0 -> 1', HERO.FightSoulLevel)
check(VANG == 95000, 'tru DUNG 5000 vang (CostGold KHONG nhan boi)', VANG)
check(KHO[103] == 99, 'tru DUNG 1 vat lieu', KHO[103])
check(x2 and x2.f == 'OnUpHeroFightSoul', 'goi dung ham nhan', x2 and x2.f)
check(OfflineStore.dongBo >= 1, 'co dong bo file luu')

-- ============================================================ 3. CẤP 2 (60%): ROLL TRƯỢT
datLai()
HERO.FightSoulLevel = 1
datRand(100)          -- > 60
goi(25, 1)
check(HERO.FightSoulLevel == 1, 'truot -> cap KHONG doi', HERO.FightSoulLevel)
check(VANG == 94000 and KHO[103] == 98, 'truot VAN tru tien (luot danh co gia)', VANG .. '/' .. KHO[103])

datLai()
HERO.FightSoulLevel = 1
datRand(60)           -- <= 60
goi(25, 1)
check(HERO.FightSoulLevel == 2, 'ti le 60%, roll 60 -> thanh cong', HERO.FightSoulLevel)

-- ============================================================ 4. BỘI NÂNG TỈ LỆ VÀ GIÁ VẬT LIỆU
datLai()
HERO.FightSoulLevel = 1
datRand(65)           -- 60 + (2-1)*10 = 70 -> 65 <= 70 => thanh cong
goi(25, 2)
check(HERO.FightSoulLevel == 2, 'boi 2 -> ti le 70%, roll 65 thanh cong', HERO.FightSoulLevel)
check(KHO[103] == 96, 'vat lieu NHAN boi: 2 x 2 = 4', KHO[103])
check(VANG == 94000, 'vang VAN khong nhan boi', VANG)

-- ============================================================ 5. HẾT CẤP
datLai()
HERO.FightSoulLevel = 2
local c5 = ctxGia()
R.handlers[KHOA](c5, 25, 1)
local kq5 = ketQua(c5)
check(kq5 == 3, 'het cap -> ket qua 3 (khong doi)', kq5)
check(THONG_BAO[1] == ErrorCode.Hero.UpHeroFightSoulLevelLimit, 'het cap -> ma 1325', THONG_BAO[1])

-- ============================================================ 6. CẤP TƯỚNG CHƯA ĐỦ
datLai()
HERO.FightSoulLevel = 1     -- cap ke (2) doi hero Lv10
HERO.HeroLevel = 5
local c6 = ctxGia()
R.handlers[KHOA](c6, 25, 1)     -- cấp 1 -> 2 cần hero Lv10
local kq6 = ketQua(c6)
check(kq6 == 3 and THONG_BAO[1] == ErrorCode.Hero.UpHeroFightSoulLevelLimit,
      'cap tuong < NeedLevel -> 3 + 1325', tostring(kq6) .. '/' .. tostring(THONG_BAO[1]))
check(VANG == 100000, 'bi chan -> khong tru vang')

-- ============================================================ 7. THIẾU VÀNG / THIẾU VẬT LIỆU
datLai()
VANG = 1000
goi(25, 1)
check(THONG_BAO[1] == ErrorCode.Common.NotEnoughGold, 'thieu vang -> ma 500', THONG_BAO[1])
check(KHO[103] == 100, 'thieu vang -> khong tru vat lieu')

datLai()
KHO[103] = 0
goi(25, 1)
check(THONG_BAO[1] == ErrorCode.Item.NotEnoughItem, 'thieu vat lieu -> ma 1201', THONG_BAO[1])
check(VANG == 100000, 'thieu vat lieu -> khong tru vang (kiem het truoc)')

-- ============================================================ 8. TRỪ VẬT LIỆU HỎNG -> HOÀN VÀNG
datLai()
G_ItemDataManager.HONG = true
goi(25, 1)
G_ItemDataManager.HONG = false
check(VANG == 100000, 'tru vat lieu hong -> HOAN lai vang', VANG)
check(THONG_BAO[1] == ErrorCode.Item.ReduceItemError, 'tru vat lieu hong -> ma 1202', THONG_BAO[1])

-- ============================================================ 9. KHÔNG CÓ TƯỚNG
datLai()
G_HeroLogic.KHONG_CO = true
goi(25, 1)
G_HeroLogic.KHONG_CO = false
check(THONG_BAO[1] == ErrorCode.Hero.NotFindHero, 'khong co tuong -> ma 1301', THONG_BAO[1])

-- ============================================================ 10. MaterialListPlus THEO TƯỚNG
datLai()
CFG[1].MaterialListPlus = { ['25'] = { { MaterialID = 103, Count = 3 } } }
datRand(100)
goi(25, 1)
CFG[1].MaterialListPlus = nil
check(KHO[103] == 97, 'MaterialListPlus[25] duoc uu tien (3 vat lieu)', KHO[103])

-- ============================================================ 11. MaterialList DẠNG CHUỖI JSON
-- May Lua tran KHONG co cjson; cam mot ban gia toi thieu de do DUNG duong giai ma.
cjson = { decode = function (sz)
    if sz == '[{"MaterialID":103,"Count":2}]' then
        return { { MaterialID = 103, Count = 2 } }
    end
    return {}
end }
datLai()
local giu = CFG[1].MaterialList
CFG[1].MaterialList = '[{"MaterialID":103,"Count":2}]'
datRand(100)
goi(25, 1)
CFG[1].MaterialList = giu
check(KHO[103] == 98, 'MaterialList dang CHUOI JSON van doc duoc (2 vat lieu)', KHO[103])

math.random = RAND_GOC
cjson = nil
io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
