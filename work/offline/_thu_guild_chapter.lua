-- _thu_guild_chapter.lua — bộ thử cho `offline/handlers/guild_chapter.lua`
-- (18 khoá phó bản bang hội). Chạy: `python _thu_nha_cua.py _thu_guild_chapter.lua`.
--
-- Đo: mã lỗi mở/đặt lại/đánh, máy trạng thái (chưa mở → chuẩn bị → đánh → qua),
-- chốt thưởng MỘT LẦN (sát thương + hạng 1 + bể rơi), xin & chia thưởng, và
-- HÌNH GỌI 4 tham số của `OnChapterRequestDetailed`.
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

-- cjson giả: bộ đọc JSON TỐI THIỂU (đủ cho cấu hình ở đây). Không dùng `return
-- <chuỗi>` vì JSON có `"khoá": giá trị` — dấu hai chấm KHÔNG hợp lệ trong Lua.
local function jsonDecode(s)
    local i = 1
    local function skip() while i <= #s and s:sub(i, i):match('%s') do i = i + 1 end end
    local parse
    local function chuoi()
        i = i + 1
        local out = {}
        while true do
            local c = s:sub(i, i)
            if c == '"' then i = i + 1 break end
            if c == '\\' then
                local n = s:sub(i + 1, i + 1)
                if n == 'n' then out[#out + 1] = '\n'
                elseif n == 't' then out[#out + 1] = '\t'
                else out[#out + 1] = n end
                i = i + 2
            else
                out[#out + 1] = c
                i = i + 1
            end
        end
        return table.concat(out)
    end
    function parse()
        skip()
        local c = s:sub(i, i)
        if c == '{' then
            i = i + 1
            local t = {}
            skip()
            if s:sub(i, i) == '}' then i = i + 1; return t end
            while true do
                skip(); local k = chuoi(); skip(); i = i + 1     -- ':'
                t[k] = parse(); skip()
                local d = s:sub(i, i); i = i + 1
                if d == '}' then break end
            end
            return t
        elseif c == '[' then
            i = i + 1
            local t = {}
            skip()
            if s:sub(i, i) == ']' then i = i + 1; return t end
            while true do
                t[#t + 1] = parse(); skip()
                local d = s:sub(i, i); i = i + 1
                if d == ']' then break end
            end
            return t
        elseif c == '"' then
            return chuoi()
        else
            local j = i
            while j <= #s and not s:sub(j, j):match('[,%]}]') and not s:sub(j, j):match('%s') do j = j + 1 end
            local tok = s:sub(i, j - 1)
            i = j
            if tok == 'true' then return true end
            if tok == 'false' then return false end
            if tok == 'null' then return nil end
            return tonumber(tok)
        end
    end
    return parse()
end
cjson = { decode = function (s) return jsonDecode(tostring(s)) end }

ErrorCode = {
    ArgError = 2,
    Guild = {
        GuildNotExist = 3501,
        GuildGuildChapterOperNotMatter = 3541,
        GuildChapterNotAchieveNormalChp = 3542,
        GuildChapterNotEnoughResource = 3543,
        GuildChapterNotOpen = 3544,
        GuildChapterLockError = 3545,
        GuildChapterFightTimeLimit = 3546,
        GuildRecurRequest = 3548,
        GuildChapterPrizeCountNotEngough = 3549,
        GuildChapterNotFightTime = 3551,
        GuildChapterHasBeenFight = 3552,
        GuildChapterMaxCount = 3561,
    },
}
EventManagerLogicEvent = { Guild = { Copy = { OnGuildChapterFightBegin = 'OnGuildChapterFightBegin' } } }

--=========================================================== TRẠNG THÁI GIẢ
UID = 100001
BANG = { GuildId = 123, Name = 'Bang Thu', HeadUid = UID, Manager = '', PictrueId = '1' }
GUD = { GuildId = 123, Resouce = 50000 }
CD = {}                 -- dữ liệu client common data (OfflineGuildChapter)
PASSED = { L_N_03_20 = true, L_N_06_20 = false, L_N_08_20 = false, L_N_10_20 = false }
DA_PHAT = {}            -- PrizeID đã phát
DA_CONG_ITEM = {}       -- {id, so} đã cộng
EVENT = {}

OfflineBangHoi = {
    doc = function (self) return BANG end,
    ghi = function (self, b) BANG = b; return true end,
    uid = function (self) return UID end,
}

G_UserLogic = {
    GetClientCommonData = function (self, k) return true, CD[k] end,
    SetClientCommonData = function (self, k, v) CD[k] = v; return true end,
    GetBaseInfo = function (self) return true, { CharacterName = 'Offline', Level = 90 } end,
    AddResourceWithType = function (self, loai, so) DA_CONG_ITEM[#DA_CONG_ITEM + 1] = { loai, so }; return true end,
}
G_DataManager = {
    GetUserDataWithName = function (self, ten)
        if ten == 'GameUserGuildData' then return 0, GUD end
        return 0, {}
    end,
}

CFG = {
    L_G_01_01 = {
        ChapterKey = 'L_G_01_01', GuildOpenNeedGuildResource = 2500,
        GuildOpenNeedPassChapter = 'L_N_03_20', GuildChapterExternTimeOut = 259200, PlayPerDay = 3,
        GuildInjureConfig = '{"InjureReward":[{"InjureBeg":0,"InjureEnd":100000,"RewardId":122001}],"InjureRankReward":[{"rankBeg":1,"rankEnd":1,"rewardList":[105001,105002]}]}',
        GuildChapterCommonDropData = '{"95":"4501","50":"4501","0":"4501"}',
    },
    L_G_02_01 = {
        ChapterKey = 'L_G_02_01', GuildOpenNeedGuildResource = 2500,
        GuildOpenNeedPassChapter = 'L_N_03_20', GuildChapterExternTimeOut = 259200, PlayPerDay = 3,
        GuildInjureConfig = '{"InjureReward":[],"InjureRankReward":[]}',
        GuildChapterCommonDropData = '{}',
    },
}
NPC = {
    [4501] = {
        TotalDropValue = 100,
        DropData = '[{"DropValue":100,"PrizeData":{"PrizeResType":2,"PropID":14,"PrizeResCount":5}},{"DropValue":100,"PrizeData":{"PrizeResType":6,"PrizeProperty":25,"PrizeResCount":2}}]',
    },
}

G_ConfigManager = {
    GetChapterConfig = function (self, k) return CFG[tostring(k)] end,
    GetNpcConfigWithNpcId = function (self, id) return NPC[tonumber(id)] end,
}
G_ChapterLogic = {
    CalcGuildChapterBossHp = function (self, k) return true, 10000 end,
    CheckChapterIsPass = function (self, k) return true, PASSED[tostring(k)] == true end,
    SetDataWithPrizeData = function (self, prize, so, lyDo) return true end,
}
G_GuildLogic = {
    OpenGuildChapterResourceWithConfig = function (self, cfg) return tonumber(cfg.GuildOpenNeedGuildResource) or 0 end,
}
G_PrizeLogic = {
    GetPrizeWithID = function (self, id) DA_PHAT[#DA_PHAT + 1] = id; return true, { PrizeContent = {} } end,
}
G_ItemLogic = {
    AddItem = function (self, id, so) DA_CONG_ITEM[#DA_CONG_ITEM + 1] = { id, so }; return true end,
}
G_HeroLogic = {
    AddHeroFragment = function (self, id, so) DA_CONG_ITEM[#DA_CONG_ITEM + 1] = { id, so }; return true end,
}
G_EventManager = { PostLogicEvent = function (self, d, ten) EVENT[#EVENT + 1] = { data = d, name = ten } end }

dofile([[__SC__/offline/handlers/guild_chapter.lua]])
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
local function goi(khoa, ...)
    local c = ctxGia()
    local h = R.handlers[khoa]
    if h == nil then return nil end
    h(c, ...)
    return c.calls[#c.calls]
end
local function maCua(x) return x and x.args[2] end

--=========================================================== 1. ĐĂNG KÝ
io.write('\n-- 1. dang ky 18 khoa\n')
local KHOA = {
    'ClientQueryGuildChapterListInfo', 'ClientQueryGuildChapterInfo', 'ClientOpenGuildChapter',
    'ClientResetGuildChapter', 'ClientPrepareGuildChapter', 'ClientGiveUpGuildChapterPrepare',
    'ClientGuildChapterFightBegin', 'ClientGuildChapterFightComplete', 'ClientGuildChapterRewardInfo',
    'ClientQueryReqestRewardMember', 'ClientDivideReward', 'ClientQueryGuildChapterRewardRecord',
    'ClientQuerySelfRequestPrize', 'ClientChapterRequestDetailed', 'ClientRequestReward',
    'ClientQueryGuildChapterInjuryRank', 'ClientQueryGuildChapterServerInjuryRank',
    'ClientChapterGetCommonDropData',
}
local thieu = {}
for _, k in ipairs(KHOA) do
    if not R:has('G_GuildChapterLogic.' .. k) then thieu[#thieu + 1] = k end
end
check(#thieu == 0, 'dang ky DU 18 khoa', table.concat(thieu, ', '))

--=========================================================== 2. CỔNG MỞ
io.write('\n-- 2. mo pho ban: cac cong chan\n')
local x = goi('G_GuildChapterLogic.ClientQueryGuildChapterListInfo')
check(x and x.f == 'OnQueryGuildChapterListInfo' and x.n == 3 and maCua(x) == 0
    and type(x.args[3]) == 'table', 'danh sach rong -> (eventList, 0, {})')

BANG = nil
x = goi('G_GuildChapterLogic.ClientOpenGuildChapter', 'L_G_01_01')
check(x and x.n == 2 and maCua(x) == 3501, 'chua co bang -> 3501')
BANG = { GuildId = 123, Name = 'Bang Thu', HeadUid = 999, Manager = '' }
x = goi('G_GuildChapterLogic.ClientOpenGuildChapter', 'L_G_01_01')
check(x and maCua(x) == 3541, 'khong phai quan ly -> 3541')
BANG.HeadUid = UID

PASSED.L_N_03_20 = false
x = goi('G_GuildChapterLogic.ClientOpenGuildChapter', 'L_G_01_01')
check(x and maCua(x) == 3542, 'chua qua ai thuong -> 3542')
PASSED.L_N_03_20 = true

GUD.Resouce = 100
x = goi('G_GuildChapterLogic.ClientOpenGuildChapter', 'L_G_01_01')
check(x and maCua(x) == 3543, 'thieu tai nguyen bang -> 3543')
GUD.Resouce = 50000

x = goi('G_GuildChapterLogic.ClientOpenGuildChapter', 'L_G_01_01')
check(x and x.f == 'OnOpenGuildChapter' and x.n == 2 and maCua(x) == 0, 'mo -> OnOpenGuildChapter(eventList, 0)')
check(GUD.Resouce == 47500, 'tru dung 2500 tai nguyen bang', GUD.Resouce)
local e = CD['OfflineGuildChapter'] and CD['OfflineGuildChapter']['L_G_01_01']
check(e and e.BossHp == 10000 and e.BossMax == 10000, 'boss 10000 HP (tu CalcGuildChapterBossHp)')
check(e and type(e.OpenTime) == 'number' and e.OpenTime > 0, 'co OpenTime')

x = goi('G_GuildChapterLogic.ClientOpenGuildChapter', 'L_G_01_01')
check(x and maCua(x) == 3545, 'mo lai pho ban da mo -> 3545')

x = goi('G_GuildChapterLogic.ClientQueryGuildChapterListInfo')
check(x and #x.args[3] == 1 and x.args[3][1].ChapterKey == 'L_G_01_01'
    and x.args[3][1].BossHp == 10000, 'danh sach -> 1 pho ban, dung BossHp')

--=========================================================== 3. CHUẨN BỊ / ĐÁNH
io.write('\n-- 3. chuan bi -> danh -> ket thuc\n')
x = goi('G_GuildChapterLogic.ClientQueryGuildChapterInfo', 'L_G_01_01')
check(x and x.n == 3 and maCua(x) == 0 and x.args[3].HasRequest == false
    and x.args[3].FightInfo == nil, 'info: chua xin thuong, khong co nguoi danh')

x = goi('G_GuildChapterLogic.ClientPrepareGuildChapter', 'L_G_01_01')
check(x and x.f == 'OnPrepareGuildChapter' and maCua(x) == 0, 'chuan bi -> 0')
x = goi('G_GuildChapterLogic.ClientQueryGuildChapterInfo', 'L_G_01_01')
check(x and x.args[3].FightInfo and x.args[3].FightInfo.Status == 1, 'info: FightInfo.Status = 1')

x = goi('G_GuildChapterLogic.ClientPrepareGuildChapter', 'L_G_01_01')
check(x and maCua(x) == 3552, 'chuan bi lan 2 -> 3552')

x = goi('G_GuildChapterLogic.ClientGuildChapterFightBegin', { ChapterKey = 'L_G_01_01' })
check(x and x.f == 'OnGuildChapterFightBegin' and x.n == 3 and x.args[3].BossHp == 10000,
    'vao tran -> (eventList, 0, {BossHp = 10000})')
check(#EVENT > 0 and EVENT[#EVENT].name == 'OnGuildChapterFightBegin'
    and EVENT[#EVENT].data.BossHp == 10000, 'TU PHAT OnGuildChapterFightBegin (client chu thich mat khoi phat)')

x = goi('G_GuildChapterLogic.ClientGuildChapterFightBegin', { ChapterKey = 'L_G_01_01' })
check(x and maCua(x) == 3551, 'vao tran lan 2 khi dang danh -> 3551')

x = goi('G_GuildChapterLogic.ClientGuildChapterFightComplete', 'L_G_01_01',
    { ChapterData = { TotalHart = 4000 } })
check(x and x.f == 'OnGuildChapterFightComplete' and x.n == 3 and x.args[3].ChapterData.TotalHart == 4000,
    'ket thuc -> tra ChapterData (man ket qua doc TotalHart)')
check(e.BossHp == 6000 and e.FightStatus == 0, 'tru 4000 mau boss (10000 -> 6000)')
check(e.Damage[tostring(UID)] == 4000, 'ghi sat thuong ca nhan')
check(e.FightCount == 1, 'tang luot danh hom nay')

--=========================================================== 4. QUA PHÓ BẢN
io.write('\n-- 4. danh ban cuoi -> QUA + chot thuong MOT LAN\n')
goi('G_GuildChapterLogic.ClientPrepareGuildChapter', 'L_G_01_01')
goi('G_GuildChapterLogic.ClientGuildChapterFightBegin', { ChapterKey = 'L_G_01_01' })
x = goi('G_GuildChapterLogic.ClientGuildChapterFightComplete', 'L_G_01_01',
    { ChapterData = { TotalHart = 7000 } })
check(e.BossHp == 0 and e.Passed == true, 'mau ve 0 -> Passed')
check(e.Settled == true, 'da chot thuong')
check(#DA_PHAT == 3, 'phat 3 PrizeID: bac sat thuong 1 + hang 1 (2 mon)', #DA_PHAT)

-- Bể rơi: 2 món của NPC 4501 (Prop 14 x5, manh tuong 25 x2).
check(e.Pool['2_14_5'] == 5 and e.Pool['6_25_2'] == 2,
    'be rơi chung: 2_14_5 = 5, 6_25_2 = 2',
    tostring(e.Pool['2_14_5']) .. '/' .. tostring(e.Pool['6_25_2']))

-- Đánh lại sau khi qua: prepare bị chặn 3545.
x = goi('G_GuildChapterLogic.ClientPrepareGuildChapter', 'L_G_01_01')
check(x and maCua(x) == 3545, 'pho ban da qua -> chuan bi bi chan 3545')

--=========================================================== 5. HẠN LƯỢT ĐÁNH
io.write('\n-- 5. han luot danh trong ngay\n')
PASSED.L_N_03_20 = true
goi('G_GuildChapterLogic.ClientOpenGuildChapter', 'L_G_02_01')
local e2 = CD['OfflineGuildChapter']['L_G_02_01']
local function khoaNgayTest()
    local now = os.time()
    local t = os.date('*t', now)
    if t.hour < 5 then now = now - 86400 end
    local d = os.date('*t', now)
    return d.year * 10000 + d.month * 100 + d.day
end
e2.FightDay = khoaNgayTest()
e2.FightCount = 3
goi('G_GuildChapterLogic.ClientPrepareGuildChapter', 'L_G_02_01')
x = goi('G_GuildChapterLogic.ClientGuildChapterFightBegin', { ChapterKey = 'L_G_02_01' })
check(x and maCua(x) == 3546, 'da du 3 luot -> 3546')
goi('G_GuildChapterLogic.ClientGiveUpGuildChapterPrepare', 'L_G_02_01')

--=========================================================== 6. XIN & CHIA THƯỞNG
io.write('\n-- 6. thuong chung: xin & chia\n')
x = goi('G_GuildChapterLogic.ClientGuildChapterRewardInfo')
check(x and x.f == 'OnGuildChapterRewardInfo' and x.n == 3 and x.args[3].RewardInfo['2_14_5'].GroupCount == 5,
    'reward info -> GroupCount 5')
check(type(x.args[3].SysDispatchLeftTime) == 'number', 'co SysDispatchLeftTime (so)')

x = goi('G_GuildChapterLogic.ClientRequestReward', 'L_G_01_01', '2_14_5')
check(x and x.f == 'OnRequestReward' and maCua(x) == 0, 'xin mon 2_14_5 -> 0')
check(e.Requests[tostring(UID)] == '2_14_5', 'luu don xin cua minh')
check(GUD.GuildChapterReqPrize == '2_14_5', 'ghi GameUserGuildData.GuildChapterReqPrize')

x = goi('G_GuildChapterLogic.ClientRequestReward', 'L_G_01_01', '6_25_2')
check(x and maCua(x) == 3548, 'xin mon thu 2 -> 3548 da xin roi')

x = goi('G_GuildChapterLogic.ClientQuerySelfRequestPrize')
check(x and x.args[3].SelfPrizeInfo.PrizeKey == '2_14_5' and x.args[3].SelfPrizeInfo.Rank == 1,
    'self request -> PrizeKey + hang 1')

x = goi('G_GuildChapterLogic.ClientQueryReqestRewardMember', '2_14_5')
check(x and x.n == 3 and #x.args[3] == 1 and x.args[3][1].Uid == UID, 'danh sach nguoi xin -> 1 nguoi')

x = goi('G_GuildChapterLogic.ClientChapterRequestDetailed', '2_14_5')
check(x and x.n == 4, 'chapter detail -> BON tham so (danh sach + thoi gian)')
check(x and type(x.args[3]) == 'table' and #x.args[3] == 1 and type(x.args[4]) == 'number',
    'detail: MemberList rieng + LeftDispatchTime')

-- Chia khi KHÔNG phải quản lý.
BANG.HeadUid = 999
x = goi('G_GuildChapterLogic.ClientDivideReward', '2_14_5', UID)
check(x and maCua(x) == 3541, 'chia khi khong du quyen -> 3541')
BANG.HeadUid = UID

x = goi('G_GuildChapterLogic.ClientDivideReward', '2_14_5', UID)
check(x and x.f == 'OnDivideReward' and maCua(x) == 0, 'chia -> 0')
local daCong = false
for _, v in ipairs(DA_CONG_ITEM) do
    if v[1] == 14 and v[2] == 5 then daCong = true end
end
check(daCong, 'da cong vat pham 14 x5 cho nguoi nhan')
check(e.Pool['2_14_5'] == 4, 'be giam con 4', e.Pool['2_14_5'])
check(e.Requests[tostring(UID)] == nil, 'xoa don xin sau khi chia')
check(#e.Records == 1, 'ghi 1 dong lich su chia')

x = goi('G_GuildChapterLogic.ClientDivideReward', '2_14_5', UID)
check(x and maCua(x) == 3549, 'chia khi khong con don xin -> 3549')

x = goi('G_GuildChapterLogic.ClientQueryGuildChapterRewardRecord')
check(x and x.n == 3 and #x.args[3] == 1 and x.args[3][1].ReceiverUid == UID, 'lich su chia -> 1 dong')

--=========================================================== 7. BẢNG SÁT THƯƠNG
io.write('\n-- 7. bang sat thuong\n')
x = goi('G_GuildChapterLogic.ClientQueryGuildChapterInjuryRank', 'L_G_01_01')
check(x and x.n == 3 and #x.args[3] == 1 and x.args[3][1].Injure == 11000 and x.args[3][1].Rank == 1,
    'bang bang -> 11000 sat thuong, hang 1')
x = goi('G_GuildChapterLogic.ClientQueryGuildChapterServerInjuryRank', 'L_G_01_01')
check(x and x.n == 3 and #x.args[3] == 1, 'bang toan may chu -> 1 dong (chi minh)')

--=========================================================== 8. ĐẶT LẠI
io.write('\n-- 8. dat lai: 3 lan/tuan\n')
GUD.Resouce = 50000
x = goi('G_GuildChapterLogic.ClientResetGuildChapter', 'L_G_01_01')
check(x and x.f == 'OnResetGuildChapter' and maCua(x) == 0, 'dat lai lan 1 -> 0')
check(e.BossHp == 10000 and e.ResetCount == 1 and e.Damage[tostring(UID)] == nil,
    'dat lai: boss day mau, xoa sat thuong, dem lan 1')
check(GUD.Resouce == 47500, 'dat lai tru 2500 tai nguyen', GUD.Resouce)

e.ResetCount = 3
x = goi('G_GuildChapterLogic.ClientResetGuildChapter', 'L_G_01_01')
check(x and maCua(x) == 3561, 'lan thu 4 trong tuan -> 3561')
e.ResetCount = 1

goi('G_GuildChapterLogic.ClientPrepareGuildChapter', 'L_G_01_01')
x = goi('G_GuildChapterLogic.ClientResetGuildChapter', 'L_G_01_01')
check(x and maCua(x) == 3552, 'dat lai khi dang danh -> 3552')
goi('G_GuildChapterLogic.ClientGiveUpGuildChapterPrepare', 'L_G_01_01')

--=========================================================== 9. RƠI CHUNG
io.write('\n-- 9. lenh phu\n')
x = goi('G_GuildChapterLogic.ClientChapterGetCommonDropData', 'L_G_01_01', 0.5)
check(x and x.f == 'OnChapterGetCommonDropData' and x.n == 3 and maCua(x) == 0,
    'ClientChapterGetCommonDropData -> (eventList, 0, {})')

io.write('\nKET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
