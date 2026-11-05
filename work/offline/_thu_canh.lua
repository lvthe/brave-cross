-- _thu_canh.lua — bo thu cho `offline/handlers/canh.lua`
-- (chay bang `python _thu_nha_cua.py _thu_canh.lua`, hoac ca cong `python _chay_het.py`).
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
    ArgError = 2,
    Common = { GetConfigFaild = 6, NotEnoughDiamond = 504 },
    Hero = { NotFindHero = 1301, NoWing = 1327, NoCountIntensifyWing = 1328, NoSoMuchLevelWing = 1329 },
    Item = { NotEnoughItem = 1201, ReduceItemError = 1202 },
}

-- cau hinh THAT (rut gon dung hinh dang)
local CAP_TOI_DA = 14
local HERO_WING = { ["1"] = {} }
for i = 1, CAP_TOI_DA do HERO_WING["1"][i] = { FightProperty = {} } end
local UPGRADE = {}
for i = 1, CAP_TOI_DA do
    UPGRADE[i] = { StoneCost = 2, MaxBlessing = 10, EffectivePercent = 0.4, CostDiamond = 450 }
end
local INTENSIFY = { ["1"] = { StoneCost = 1 }, ["2"] = { StoneCost = 2 }, ["3"] = { StoneCost = 3 } }

G_ConfigManager = {}
function G_ConfigManager:GetCommonConfigWithName(ten)
    if ten == "HeroWingConfig" then return HERO_WING end
    if ten == "UpgradeWingConfig" then return UPGRADE end
    if ten == "GameWingIntensifyConfig" then return INTENSIFY end
    return nil
end

-- the gioi gia
local hero, kho, kimCuong, capNguoiChoi, globalData, events
local function datLai()
    hero = { UserHeroID = 25, WingID = 1, WingLevel = 1, WingIntensifyLevel = 0, WingBlessing = 0 }
    kho = { [101] = 20, [102] = 20 }
    kimCuong = 1000
    capNguoiChoi = 3
    globalData = {}
    events = {}
end
datLai()

G_HeroLogic = {}
function G_HeroLogic:GetHeroWithID(id)
    if hero ~= nil and tonumber(id) == hero.UserHeroID then return true, hero end
    return false, nil
end

G_ItemLogic = {}
function G_ItemLogic:GetItemCount(id) return true, kho[id] or 0 end
function G_ItemLogic:AddItem(id, n) kho[id] = (kho[id] or 0) + n; return true end
G_ItemDataManager = {}
function G_ItemDataManager:ReduceItem(id, n)
    if (kho[id] or 0) < n then return false end
    kho[id] = kho[id] - n
    return true
end

G_UserLogic = {}
function G_UserLogic:GetDiamond() return true, kimCuong end
function G_UserLogic:CostDiamond(n)
    if kimCuong < n then return false end
    kimCuong = kimCuong - n
    return true
end
function G_UserLogic:GetLevel() return true, capNguoiChoi end

G_UserDataManager = {}
function G_UserDataManager:GetUserGlobalData(k) return true, globalData[k] end
function G_UserDataManager:SetUserGlobalData(k, v) globalData[k] = v; return true end

G_HeroDataManager = {}
function G_HeroDataManager:SetHeroWingLevel(h, lv) h.WingLevel = lv; return true end
function G_HeroDataManager:SetHeroUpgradeWingBlessing(h, n) h.WingBlessing = n; return true end
function G_HeroDataManager:SetHeroWingIntensifyLevel(h, n) h.WingIntensifyLevel = n; return true end

G_EventManager = {}
function G_EventManager:PostLogicEvent(tData, ten)
    events[#events + 1] = { data = tData, name = ten }
end

dofile([[__SC__/offline/handlers/canh.lua]])
local R = require('offline.router')

local dat, hong = 0, 0
local function check(ok, ten, ct)
    if ok then dat = dat + 1; io.write('  OK   ' .. ten .. '\n')
    else hong = hong + 1; io.write('  HONG ' .. ten .. (ct ~= nil and (' -> ' .. tostring(ct)) or '') .. '\n') end
end
local function ctxGia()
    local c = { calls = {} }
    function c:call(obj, f, a, b, ma, ev)
        self.calls[#self.calls + 1] = { obj = obj, f = f, a = a, b = b, err = ma, ev = ev }
        return true
    end
    return c
end
local function maCua(ctx)
    local x = ctx.calls[#ctx.calls]
    return x and tonumber(x.err)
end

local fTienCap = R.handlers['G_HeroLogic.ClientUpgradeWing']
local fKimCuong = R.handlers['G_HeroLogic.ClientUpgradeWingWithDiamond']
local fCuongHoa = R.handlers['G_HeroLogic.ClientIntensifyWing']
local fTuDong = R.handlers['G_HeroLogic.ClientAutoIntensifyWing']

io.write('\n=== dang ky khoa ===\n')
check(fTienCap ~= nil and fKimCuong ~= nil and fCuongHoa ~= nil and fTuDong ~= nil,
    'co du 4 handler (tien cap / kim cuong / cuong hoa / tu dong)')

----------------------------------------------------------------- TIEN CAP
io.write('\n=== tien cap ===\n')
datLai(); hero = nil
local c = ctxGia(); fTienCap(c, 25)
check(maCua(c) == 1301, 'khong thay tuong -> 1301', maCua(c))

datLai(); hero.WingID = 0
c = ctxGia(); fTienCap(c, 25)
check(maCua(c) == 1327, 'chua co canh -> 1327', maCua(c))

datLai(); hero.WingLevel = CAP_TOI_DA
c = ctxGia(); fTienCap(c, 25)
check(maCua(c) == 1329, 'da cap toi da -> 1329', maCua(c))

datLai(); kho[102] = 1
c = ctxGia(); fTienCap(c, 25)
check(maCua(c) == 1201, 'thieu da tien cap -> 1201', maCua(c))

-- THAT BAI: random 0.99 > p, chuc phuc 0 -> +2 (ceil(10*0.4/2))
datLai(); local rdGoc = math.random
math.random = function () return 0.99 end
c = ctxGia(); fTienCap(c, 25)
math.random = rdGoc
check(maCua(c) == 0, 'that bai van tra 0', maCua(c))
check(hero.WingLevel == 1, 'that bai KHONG len cap', hero.WingLevel)
check(hero.WingBlessing == 2, 'that bai cong chuc phuc +2', hero.WingBlessing)
check(kho[102] == 18, 'that bai van tru 2 da', kho[102])
check(#events == 1 and events[1].name == 'OnUpgradeWing'
    and events[1].data.IsSuccess == false and events[1].data.AddBlessing == 2,
    'event OnUpgradeWing(IsSuccess=false, AddBlessing=2)')

-- THANH CONG: random 0 -> p > 0
datLai(); math.random = function () return 0 end
c = ctxGia(); fTienCap(c, 25)
math.random = rdGoc
check(maCua(c) == 0 and hero.WingLevel == 2, 'roll thap -> thanh cong, cap 1->2', hero.WingLevel)
check(hero.WingBlessing == 0, 'thanh cong reset chuc phuc', hero.WingBlessing)
check(events[1].data.IsSuccess == true and events[1].data.WingLevel == 2,
    'event OnUpgradeWing(IsSuccess=true, WingLevel=2)')

-- DAY THANH => CHAC CHAN (du random cao; dat moc ngay de khong bi reset 5:00)
datLai(); hero.WingBlessing = 10
globalData.WingBlessingDay = math.floor((os.time() - 5 * 3600) / 86400)
math.random = function () return 0.999 end
c = ctxGia(); fTienCap(c, 25)
math.random = rdGoc
check(maCua(c) == 0 and hero.WingLevel == 2 and hero.WingBlessing == 0,
    'day thanh => chac chan thanh cong (du random cao)', hero.WingLevel)

-- RESET 5:00: da luu hom nay => KHONG reset
datLai(); hero.WingBlessing = 5
globalData.WingBlessingDay = math.floor((os.time() - 5 * 3600) / 86400)
math.random = function () return 0.99 end
c = ctxGia(); fTienCap(c, 25)
math.random = rdGoc
check(hero.WingBlessing == 7, 'cung ngay 5:00 => KHONG reset (5 -> 7)', hero.WingBlessing)

-- RESET 5:00: da luu hom qua => reset ve 0 roi moi roll
datLai(); hero.WingBlessing = 5
globalData.WingBlessingDay = math.floor((os.time() - 5 * 3600) / 86400) - 1
math.random = function () return 0.99 end
c = ctxGia(); fTienCap(c, 25)
math.random = rdGoc
check(hero.WingBlessing == 2, 'sang ngay 5:00 => reset roi cong 2', hero.WingBlessing)

-- KIM CUONG: thieu => 504
datLai(); kimCuong = 100
c = ctxGia(); fKimCuong(c, 25)
check(maCua(c) == 504, 'thieu kim cuong -> 504', maCua(c))
check(hero.WingLevel == 1, 'thieu kim cuong KHONG len cap')

-- KIM CUONG: du => chac chan, tru 450
datLai(); hero.WingBlessing = 6
c = ctxGia(); fKimCuong(c, 25)
check(maCua(c) == 0 and hero.WingLevel == 2, 'kim cuong -> chac chan len cap', hero.WingLevel)
check(kimCuong == 550, 'tru dung 450 kim cuong', kimCuong)
check(hero.WingBlessing == 0, 'kim cuong reset chuc phuc', hero.WingBlessing)

------------------------------------------------------------------- CUONG HOA
io.write('\n=== cuong hoa ===\n')
datLai(); kho[101] = 0
c = ctxGia(); fCuongHoa(c, 25)
check(maCua(c) == 1201, 'thieu da cuong hoa -> 1201', maCua(c))

datLai()   -- cap nguoi choi 3, da 20 => mot cap
c = ctxGia(); fCuongHoa(c, 25)
check(maCua(c) == 0 and hero.WingIntensifyLevel == 1, 'cuong hoa mot cap (0->1)', hero.WingIntensifyLevel)
check(kho[101] == 19 and #events == 1 and events[1].name == 'OnIntensifyWing'
    and events[1].data.IntensifyLevel == 1, 'tru 1 da + event OnIntensifyWing')

datLai()   -- tu dong: 1+2+3 = 6 da, cham tran cap nguoi choi 3
c = ctxGia(); fTuDong(c, 25)
check(maCua(c) == 0 and hero.WingIntensifyLevel == 3, 'tu dong len cham tran nguoi choi (3)', hero.WingIntensifyLevel)
check(kho[101] == 14, 'tu dong tru 6 da (20 -> 14)', kho[101])

datLai(); hero.WingIntensifyLevel = 3
c = ctxGia(); fTuDong(c, 25)
check(maCua(c) == 1328, 'da cham tran -> 1328', maCua(c))

-- lop chan khong de len handler
dofile([[__SC__/offline/handlers/chua_ho_tro.lua]])
local R2 = require('offline.router')
check(R2.handlers['G_HeroLogic.ClientUpgradeWing'] == fTienCap,
    'lop chan KHONG de len handler tien cap')
check(R2.handlers['G_HeroLogic.ClientAutoIntensifyWing'] == fTuDong,
    'lop chan KHONG de len handler tu dong')

io.write(string.format('\nKET QUA: dat %d, hong %d\n', dat, hong))
os.exit(hong == 0 and 0 or 1)
