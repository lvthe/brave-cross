-- _thu_bang_hoi_nang_cao.lua — bộ thử cho `offline/handlers/bang_hoi_nang_cao.lua`
-- (chạy bằng `python _thu_nha_cua.py _thu_bang_hoi_nang_cao.lua`).
--
-- Đo bốn thứ dễ hỏng:
--   1. KHOÁ ĐĂNG KÝ 23 cái (sai tiền tố obj là handler không bao giờ chạy).
--   2. MÃ LỖI GỐC cho nhóm "một người" (3523/3507/3502/3501/3555).
--   3. THUẾ CÔNG NGHỆ: trừ đúng vàng/ngọc, cộng exp + đóng góp + tài nguyên bang,
--      lên cấp theo `Exp` của cấp kế (dư chuyển tiếp).
--   4. XÚC XẮC + ĐIỀU TƯỚNG: trạng thái ghi vào ĐÚNG bảng client đọc
--      (`GameUserLottery`, `GameUserGuildData.MapDispatchHero`), và các cổng chặn.
package.path = [[__SC__/?.lua;__SC__/?/init.lua;]] .. package.path

local function ghi(a, b)
    local m = b
    if type(a) == 'string' then m = a end
    io.write('[log] ' .. tostring(m) .. '\n')
end
package.preload['offline.log'] = function ()
    local L = { info = ghi, warn = ghi, err = ghi }; OfflineLog = L; return L
end
package.preload['offline.store'] = function ()
    local S = { TABLES = {}, data = {}, dirty = false }
    function S:syncFromClient() end
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
    Common = { NotEnoughGold = 500, NotEnoughDiamond = 504 },
    Guild = {
        GuildNotExist = 3501, GuildIsIn = 3502, GuildAuthLess = 3507,
        GuildDisptachFull = 3512, GuildRedisptach = 3513,
        GuildDisptchInfoChange = 3514, GuildNotEnoughTime = 3517,
        GuildNotApply = 3523, GuildExitWithDispatch = 3532,
        GuildCantMainRole = 3534, GuildTargetNotHeadman = 3553,
        GuildHeadManIsAlive = 3555,
    },
    VIP = { NoEnoughVipLevel = 3401 },
    DiceGame = {
        NotEnoughPlayTimes = 4700, PayTimesLimit = 4701,
        NeedPayDiceGame = 4702, NoReward = 4703,
    },
}

EventManagerLogicEvent = { Guild = { OnDonateGuildTechnology = 'DonateGuildTechnology' } }
CUINotificationEvent = { OnServerRequestError = 'OnServerRequestError' }

--=========================================================== TRẠNG THÁI GIẢ
UID = 100001
BANG = {
    GuildId = 123, Name = 'Bang Thu', PictrueId = '1', StrNotice = '',
    StrWeChatGroup = '', HeadUid = UID, Type = 1, AcceptLevel = 1,
    CreateTime = os.time() - 86400 * 3,
    memberList = { { Uid = UID, Nick = 'Offline', Level = 90 } },
}
GUD = { GuildId = 123, GuildContribution = 0, Resouce = 0 }
LOTTERY = {}
BASE = { VipLevel = 0, Gold = 20000, Diamond = 1000 }
TECH = {}     -- GameGuildTechnology: [ten] = {Name, Level, Exp}
LOGIC_EVENTS = {}
THONG_BAO = {}
LOTTERY_RESET = false

OfflineBangHoi = {
    doc = function (self) return BANG end,
    ghi = function (self, b)
        BANG = b
        GUD.GuildId = (b and b.GuildId) or 0
        return true
    end,
    uid = function (self) return UID end,
}

G_DataManager = {
    GetUserDataWithName = function (self, ten)
        if ten == 'GameUserGuildData' then return 0, GUD end
        if ten == 'GameUserLottery' then return 0, LOTTERY end
        if ten == 'GameGuildTechnology' then return 0, TECH end
        return 0, nil
    end,
    SetUserDataWithName = function (self, ten, t)
        if ten == 'GameUserLottery' then LOTTERY = t; LOTTERY_RESET = true end
        return true
    end,
}

-- Cấu hình THẬT rút gọn: 12 tuyến × 15..50 cấp; ở đây đủ để đo luật lên cấp.
TECH_CFG = { ['1'] = {} }
for i = 1, 5 do
    TECH_CFG['1'][tostring(i)] = { Name = 1, Level = i, Exp = 200 * i, Value = 20 * i }
end
DONATE_CFG = {
    ['1'] = { Index = 1, ResourceType = 1, ResourceCount = 15000, TechnologyCount = 20, VipLimite = 0 },
    ['2'] = { Index = 2, ResourceType = 20, ResourceCount = 50, TechnologyCount = 50, VipLimite = 0 },
    ['3'] = { Index = 3, ResourceType = 20, ResourceCount = 100, TechnologyCount = 120, VipLimite = 3 },
    ['5'] = { Index = 5, ResourceType = 20, ResourceCount = 800, TechnologyCount = 800, VipLimite = 8 },
}
DICE_CFG = {
    PlayTimes = 5,
    GodHeroId = 23,
    PrizeData = {
        { 0, 120011 }, { 1, 120012 }, { 2, 120013 }, { 3, 120014 },
        { 4, 120015 }, { 5, 120016 }, { 6, 120017 },
    },
    -- MỘT kế hoạch, Rate 100 ⇒ luôn chọn; mỗi lượt đúng 2 mặt 6 (đo được).
    StartPlan = { { Rate = 100, GodTimesData = { 2, 2, 2, 2, 2 } } },
    ChangePrice = { 10, 10, 20 },
    ChangeRate = {},
}
PRIZE = {}

G_ConfigManager = {
    GetGameTchecknologyDonateConfig = function (self, i) return DONATE_CFG[tostring(i)] end,
    GetGameGuildTchecknologyConfig = function (self, ten, cap)
        return TECH_CFG[tostring(ten)] and TECH_CFG[tostring(ten)][tostring(cap)] or nil
    end,
    GetCommonConfigWithName = function (self, ten)
        if ten == 'DiceGameConfig' then return DICE_CFG end
        return nil
    end,
}

G_UserLogic = {
    GetBaseInfo = function (self) return true, BASE end,
    CostGold = function (self, n)
        if BASE.Gold < n then return false, BASE.Gold end
        BASE.Gold = BASE.Gold - n; return true, BASE.Gold
    end,
    CostDiamond = function (self, n)
        if BASE.Diamond < n then return false, BASE.Diamond end
        BASE.Diamond = BASE.Diamond - n; return true, BASE.Diamond
    end,
    AddGold = function (self, n) BASE.Gold = BASE.Gold + n; return true, BASE.Gold end,
    GetCharacterName = function (self) return true, 'Offline' end,
}

G_GuildLogic = {
    GetUserGuildTechnology = function (self, ten)
        local k = tostring(ten)
        TECH[k] = TECH[k] or { Name = tonumber(k) or k, Level = 0, Exp = 0 }
        return true, TECH[k]
    end,
}

G_RankLogic = { GetUserHotData = function (self) return true, { CharacterName = 'Offline', Level = 90 } end }
G_HeroLogic = {
    GetHeroWithID = function (self, id)
        if tonumber(id) == 25 then return true, { UserHeroID = 25, HeroLevel = 90, IsMain = true } end
        if tonumber(id) and tonumber(id) < 100 then return true, { UserHeroID = tonumber(id), HeroLevel = 80 } end
        return false, nil
    end,
    IsCharacter = function (self, t) return t ~= nil and t.UserHeroID == 25 end,
    GetHeroAllFightCapacityWithHero = function (self, t) return true, 1000 end,
}
G_PrizeLogic = {
    GetPrizeWithID = function (self, id)
        PRIZE[#PRIZE + 1] = id
        return true, { PrizeContent = { { PrizeID = id } } }
    end,
}
G_ChapterLogic = {
    SetDataWithPrizeData = function (self, p, n, r) return true end,
}
G_EventManager = {
    PostLogicEvent = function (self, d, name) LOGIC_EVENTS[#LOGIC_EVENTS + 1] = name end,
}
g_CUINotificationCenter = {
    PostNotification = function (self, ev, ma) THONG_BAO[#THONG_BAO + 1] = ma end,
}

dofile([[__SC__/offline/handlers/bang_hoi_nang_cao.lua]])
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
        local o = _G[obj]
        if type(o) == 'table' and type(o[f]) == 'function' then o[f](o, ...) end
    end
    return c
end
-- Ghi mọi lời gọi OnReciveResponse vào một bảng chung để kiểm mã lỗi.
RSP = {}
g_CUIGameRPCManager = {}
function g_CUIGameRPCManager:OnReciveResponse(...)
    RSP[#RSP + 1] = { n = select('#', ...), ... }
end
local function rspCuoi() return RSP[#RSP] end
local function goi(khoa, ...)
    local c = ctxGia()
    local h = R.handlers[khoa]
    if h == nil then return nil end
    h(c, ...)
    return c.calls[#c.calls], c, #c.calls
end

--=========================================================== 1. ĐĂNG KÝ
io.write('\n-- 1. dang ky 23 khoa\n')
local KHOA = {
    'ClientAcceptApply', 'ClientRejectApply', 'ClientSetHead', 'ClientSetManager',
    'ClientCancelManager', 'ClientKickGuild', 'ClientModifyGuildSetting',
    'ClientIsHaveGuildRedPoint', 'ClientUploadWeChatGroup', 'ClientImpeachHeadman',
    'ClientSearchGuild', 'ClientJoinGuild',
    'ClientApplyGuild', 'ClientCancelApply', 'ClientDonateGuildTechnology',
    'ClientGetDiceGameData', 'ClientPlayDiceGame', 'ClientGetDiceGameReward',
    'ClientDispatchHero', 'ClientQuerySelfDispatchList', 'ClientGetDispatchHeroList',
    'ClientPickGuildHero', 'ClientEmployDispatchHero',
}
local thieu = {}
for _, k in ipairs(KHOA) do
    if not R:has('G_GuildLogic.' .. k) then thieu[#thieu + 1] = k end
end
check(#thieu == 0, 'dang ky DU 23 khoa cua tep nay (ClientGetRandGuildList do he_thong lo)', table.concat(thieu, ', '))

--=========================================================== 2. QUẢN LÝ THÀNH VIÊN
io.write('\n-- 2. quan ly thanh vien: mot nguoi -> ma GOC\n')
local function maCua(x) return x and x.args[1] end

local x = goi('G_GuildLogic.ClientAcceptApply', 5)
check(x and x.f == 'OnAcceptApply' and maCua(x) == 3523, 'duyet don -> OnAcceptApply(3523)')
x = goi('G_GuildLogic.ClientRejectApply', 5)
check(x and x.f == 'OnRejectApply' and maCua(x) == 3523, 'tu choi don -> OnRejectApply(3523)')

x = goi('G_GuildLogic.ClientSetHead', UID)
check(x and x.f == 'OnSetHead' and maCua(x) == 0, 'dat lai chinh minh lam bang chu -> 0 (idempotent)')
x = goi('G_GuildLogic.ClientSetHead', 999)
check(x and maCua(x) == 3507, 'dat nguoi khac lam bang chu -> 3507')

x = goi('G_GuildLogic.ClientSetManager', 999)
check(x and x.f == 'OnSetManager' and maCua(x) == 3507, 'dat pho bang chu -> 3507')
x = goi('G_GuildLogic.ClientCancelManager', 999)
check(x and x.f == 'OnCancelManager' and maCua(x) == 3507, 'bo pho bang chu -> 3507')
x = goi('G_GuildLogic.ClientKickGuild', 999)
check(x and x.f == 'OnKickGuild' and maCua(x) == 3507, 'da thanh vien -> 3507')

--=========================================================== 3. THIẾT LẬP BANG
io.write('\n-- 3. thiet lap bang (that)\n')
x = goi('G_GuildLogic.ClientModifyGuildSetting', 123, 2, '5', 10)
check(x and x.f == 'ClientModifyGuildSetting' and maCua(x) == 0, 'bang chu doi thiet lap -> 0')
check(BANG.Type == 2 and BANG.PictrueId == '5' and BANG.AcceptLevel == 10,
    'thiet lap da ghi Type/PictrueId/AcceptLevel')

local chuCu = BANG.HeadUid
BANG.HeadUid = 999
x = goi('G_GuildLogic.ClientModifyGuildSetting', 123, 1, '1', 1)
check(x and maCua(x) == 3507, 'KHONG phai bang chu -> 3507')
BANG.HeadUid = chuCu

x = goi('G_GuildLogic.ClientUploadWeChatGroup', 123, 'https://qr/x')
check(x and x.f == 'OnUploadWeChatGroup' and maCua(x) == 0 and BANG.WeChatGroup == 'https://qr/x',
    'luu link nhom WeChat (that)')

--=========================================================== 4. TÌM / VÀO BANG
io.write('\n-- 4. tim / vao / xin vao bang\n')
x = goi('G_GuildLogic.ClientSearchGuild', 123)
check(x and x.f == 'OnSearchGuild' and maCua(x) == 0 and x.args[2].GuildId == 123,
    'tim bang cua minh -> tra ve du truong')
check(x and x.args[2].PictrueId == '5' and type(x.args[2].MemberNum) == 'number',
    'du truong danh sach (PictrueId/MemberNum/Type)')
x = goi('G_GuildLogic.ClientSearchGuild', 777)
check(x and maCua(x) == 3501, 'tim bang khong co -> 3501')

local nRsp = #RSP
goi('G_GuildLogic.ClientJoinGuild', 123)
check(rspCuoi() and rspCuoi()[3] == 3502, 'vao bang khi DA o trong bang -> 3502')
goi('G_GuildLogic.ClientApplyGuild', 123)
check(rspCuoi() and rspCuoi()[3] == 3502, 'xin vao bang khi DA o trong bang -> 3502')

BANG = nil
goi('G_GuildLogic.ClientJoinGuild', 123)
check(rspCuoi() and rspCuoi()[3] == 3501, 'vao bang khi CHUA co bang nao -> 3501')
goi('G_GuildLogic.ClientApplyGuild', 123)
check(rspCuoi() and rspCuoi()[3] == 3501, 'xin vao khi chua co bang nao -> 3501')
BANG = { GuildId = 123, Name = 'Bang Thu', PictrueId = '1', HeadUid = UID, Type = 1,
    AcceptLevel = 1, memberList = { { Uid = UID } } }

x = goi('G_GuildLogic.ClientCancelApply', 123)
check(x and x.f == 'OnCancelApply', 'huy don xin -> OnCancelApply()')

x = goi('G_GuildLogic.ClientImpeachHeadman', UID, 123)
check(#THONG_BAO > 0 and THONG_BAO[#THONG_BAO] == 3555, 'luan toi bang chu -> 3555 (khong goi ham nhan)')
check(x == nil, 'luan toi KHONG goi ham nhan (tranh UI bao thanh cong)')

--=========================================================== 5. THUẾ CÔNG NGHỆ
io.write('\n-- 5. thue cong nghe\n')
GUD.GuildContribution = 0
GUD.Resouce = 0
TECH = {}
BASE.Gold = 20000
BASE.Diamond = 1000
BASE.VipLevel = 0

x = goi('G_GuildLogic.ClientDonateGuildTechnology', '1', 3)   -- bậc 3 cần VIP 3
check(x and x.f == 'OnDonateGuildTechnology' and THONG_BAO[#THONG_BAO] == 3401,
    'bac 3 khi VIP 0 -> 3401 NoEnoughVipLevel')
check(BASE.Diamond == 1000, 'VIP khong du: KHONG tru ngoc')

BASE.Gold = 100
x = goi('G_GuildLogic.ClientDonateGuildTechnology', '1', 1)
check(THONG_BAO[#THONG_BAO] == 500 and BASE.Gold == 100, 'thieu vang -> 500, khong tru')
BASE.Gold = 20000

x = goi('G_GuildLogic.ClientDonateGuildTechnology', '1', 1)   -- 15.000 vàng, +20 exp
check(x and x.f == 'OnDonateGuildTechnology', 'dong gop bac 1 -> OnDonateGuildTechnology()')
check(BASE.Gold == 5000, 'tru dung 15.000 vang (20000 -> 5000)', BASE.Gold)
check(TECH['1'] and TECH['1'].Exp == 20 and TECH['1'].Level == 0, 'cong 20 exp, chua len cap')
check(GUD.GuildContribution == 20 and GUD.Resouce == 20, 'cong 20 vao dong gop ca nhan + tai nguyen bang')

-- 9 lượt nữa = 180 exp ⇒ 200 exp ⇒ LÊN CẤP 1 và dư 0 (Exp cấp 1 = 200).
local daLen = false
local capLen, expLen = nil, nil
for i = 1, 9 do
    BASE.Gold = 20000          -- nạp lại để đo luật lên cấp, không đo tiền
    local _, c = goi('G_GuildLogic.ClientDonateGuildTechnology', '1', 1)
    -- Lượt lên cấp gọi HAI hàm nhận: OnGuildTechnologyLevelUp rồi OnDonateGuildTechnology,
    -- nên phải quét CẢ danh sách lời gọi, không đọc lời gọi cuối.
    for _, call in ipairs(c and c.calls or {}) do
        if call.f == 'OnGuildTechnologyLevelUp' then
            daLen = true
            capLen, expLen = call.args[2], call.args[3]
        end
    end
end
check(daLen and capLen == 1 and expLen == 0,
    'len cap 1: OnGuildTechnologyLevelUp(ten, cap 1, exp 0)', tostring(capLen) .. '/' .. tostring(expLen))
check(TECH['1'].Level == 1 and TECH['1'].Exp == 0,
    'sau 200 exp -> cap 1, exp 0 (tru dan theo Exp cua cap ke)')

TECH['1'].Level = 5
TECH['1'].Exp = 0
goi('G_GuildLogic.ClientDonateGuildTechnology', '1', 1)
check(THONG_BAO[#THONG_BAO] == 2, 'da cap cao nhat -> ArgError (2)')
TECH['1'].Level = 1
TECH['1'].Exp = 0

--=========================================================== 6. XÚC XẮC
io.write('\n-- 6. xuc xac (GameUserLottery)\n')
LOTTERY = {}
PRIZE = {}
BASE.Gold = 20000

x = goi('G_GuildLogic.ClientGetDiceGameData')
check(x and x.f == 'OnGetDiceGameData' and type(x.args[1]) == 'table', 'du lieu xuc xac -> OnGetDiceGameData(tData)')
check(x and x.args[1].RewardInfo and x.args[1].RewardInfo.GodHeroId == 23,
    'tra RewardInfo.GodHeroId = 23')
check(x and type(x.args[1].BestPlayer) == 'table', 'tra BestPlayer')
check(LOTTERY.DiceGamePlayTimes == 0, 'ngay moi: 0 luot da dung')

x = goi('G_GuildLogic.ClientPlayDiceGame')
check(x and x.f == 'OnPlayDiceGame' and type(x.args[1]) == 'table', 'do xuc xac -> OnPlayDiceGame')
check(type(LOTTERY.DiceGameData) == 'table' and #LOTTERY.DiceGameData == 6,
    'luu 6 mat vao GameUserLottery.DiceGameData')
local soSau = 0
for _, v in ipairs(LOTTERY.DiceGameData) do if v == 6 then soSau = soSau + 1 end end
check(soSau == 2, 'ke hoach GodTimesData[1] = 2 -> dung 2 mat 6', soSau)
check(LOTTERY.DiceGamePlayTimes == 1, 'da dung 1 luot')

x = goi('G_GuildLogic.ClientGetDiceGameReward')
check(x and x.f == 'OnGetDiceGameReward' and #PRIZE == 1 and PRIZE[1] == 120013,
    'nhan thuong 2 mat 6 -> PrizeID 120013')
check(LOTTERY.DiceGameData == nil, 'nhan xong XOA 6 mat')
check(LOTTERY.DiceGameValue == 100, 'ky luc: 1 lan 2 mat 6 = 100', LOTTERY.DiceGameValue)

goi('G_GuildLogic.ClientPlayDiceGame')
goi('G_GuildLogic.ClientGetDiceGameReward')
check(LOTTERY.DiceGameValue == 200, 'lan thu 2 cung 2 mat 6 -> 200', LOTTERY.DiceGameValue)

-- Lượt còn lại: 2,3,4,5 → 3 lượt nữa là hết 5.
goi('G_GuildLogic.ClientPlayDiceGame')
goi('G_GuildLogic.ClientGetDiceGameReward')
goi('G_GuildLogic.ClientPlayDiceGame')
goi('G_GuildLogic.ClientGetDiceGameReward')
goi('G_GuildLogic.ClientPlayDiceGame')
goi('G_GuildLogic.ClientGetDiceGameReward')
check(LOTTERY.DiceGamePlayTimes == 5, 'da dung du 5 luot')

local nRspTruoc = #RSP
goi('G_GuildLogic.ClientPlayDiceGame')
check(#RSP > nRspTruoc and rspCuoi()[3] == 4700, 'luot thu 6 -> 4700 NotEnoughPlayTimes')

x = goi('G_GuildLogic.ClientIsHaveGuildRedPoint', 123)
check(x and x.f == 'onIsHaveGuildRedPoint' and x.args[1] == false, 'het luot -> cham do = false')

-- Sang ngày mới: đặt khoá ngày CŨ rồi mở lại.
LOTTERY.DiceGameDay = 20000101
x = goi('G_GuildLogic.ClientGetDiceGameData')
check(LOTTERY.DiceGamePlayTimes == 0, 'sang ngay moi: dat lai 0 luot')
x = goi('G_GuildLogic.ClientIsHaveGuildRedPoint', 123)
check(x and x.args[1] == true, 'ngay moi con luot -> cham do = true')

local nRsp2 = #RSP
LOTTERY.DiceGameData = nil
goi('G_GuildLogic.ClientGetDiceGameReward')
check(#RSP > nRsp2 and rspCuoi()[3] == 4703, 'nhan thuong khi chua do -> 4703 NoReward')

--=========================================================== 7. ĐIỀU TƯỚNG
io.write('\n-- 7. dieu tuong (GameUserGuildData.MapDispatchHero)\n')
GUD.MapDispatchHero = nil
BASE.Gold = 20000

x = goi('G_GuildLogic.ClientDispatchHero', 123, 56)
check(x and x.f == 'onQuerySelfDispatchList' and type(x.args[1].RetData) == 'table'
    and #x.args[1].RetData == 1, 'dieu tuong 56 -> tra danh sach cua minh (1 muc)')
check(type(GUD.MapDispatchHero) == 'table' and GUD.MapDispatchHero['56'] ~= nil,
    'luu vao MapDispatchHero (dung bang client doc)')

local nTb = #THONG_BAO
goi('G_GuildLogic.ClientDispatchHero', 123, 56)
check(#THONG_BAO > nTb and THONG_BAO[#THONG_BAO] == 3513, 'dieu lai cung tuong -> 3513')

nTb = #THONG_BAO
goi('G_GuildLogic.ClientDispatchHero', 123, 25)   -- chủ công
check(#THONG_BAO > nTb and THONG_BAO[#THONG_BAO] == 3534, 'dieu CHU CONG -> 3534')

goi('G_GuildLogic.ClientDispatchHero', 123, 57)
goi('G_GuildLogic.ClientDispatchHero', 123, 58)
nTb = #THONG_BAO
goi('G_GuildLogic.ClientDispatchHero', 123, 59)
check(#THONG_BAO > nTb and THONG_BAO[#THONG_BAO] == 3512, 'dieu tuong thu 4 -> 3512')

x = goi('G_GuildLogic.ClientQuerySelfDispatchList', 123)
local dem = 0
for _ in pairs(GUD.MapDispatchHero) do dem = dem + 1 end
check(x and x.f == 'onQuerySelfDispatchList' and #x.args[1].RetData == dem,
    'truy van danh sach -> du ' .. tostring(dem) .. ' muc')

nTb = #THONG_BAO
goi('G_GuildLogic.ClientPickGuildHero', 56)
check(#THONG_BAO > nTb and THONG_BAO[#THONG_BAO] == 3517, 'thu hoi truoc 30 phut -> 3517')

GUD.MapDispatchHero['56'].DispatchTime = os.time() - 3600
BASE.Gold = 20000
x = goi('G_GuildLogic.ClientPickGuildHero', 56)
check(x and x.f == 'OnPickGuildHero' and type(x.args[1].RetData) == 'number',
    'thu hoi sau 1 gio -> OnPickGuildHero({RetData = so vang})')
check(BASE.Gold > 20000, 'cong vang theo cong thuc client', BASE.Gold)
check(GUD.MapDispatchHero['56'] == nil, 'da xoa khoi MapDispatchHero')

nRsp = #RSP
goi('G_GuildLogic.ClientEmployDispatchHero', 56, 999, 123, 1)
check(#RSP > nRsp and rspCuoi()[3] == 3514, 'thue tuong nguoi khac -> 3514')

x = goi('G_GuildLogic.ClientGetDispatchHeroList', 123)
check(x and x.f == 'OnGetDispatchHeroList' and maCua(x) == 0 and #x.args[2] == 0,
    'danh sach tuong cho thue -> rong (chi co tuong cua minh)')

io.write('\nKET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
