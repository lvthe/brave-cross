-- _thu_bang_hoi.lua — bộ thử cho `offline/handlers/bang_hoi.lua`
-- (chạy bằng `python _thu_nha_cua.py _thu_bang_hoi.lua`).
--
-- Đo mô hình TỐI THIỂU: lập bang một người, hình `tGuildInfo` đúng chỗ UI đọc
-- (Name/GuildId/StrNotice/PictrueId/memberList/HeadUid/Manager), cờ `GameUserGuildData.GuildId`,
-- và mọi khoá "không có ai" trả ĐÚNG hình (danh sách rỗng, không phải nil).
package.path = [[__SC__/?.lua;__SC__/?/init.lua;]] .. package.path

local function ghi(m) io.write('[log] ' .. tostring(m) .. '\n') end
package.preload['offline.log'] = function ()
    local L = { info = ghi, warn = ghi, err = ghi }; OfflineLog = L; return L
end
package.preload['offline.store'] = function ()
    local S = { TABLES = {}, data = {}, dirty = false, UID = 100001 }
    function S:syncFromClient() self.dongBo = (self.dongBo or 0) + 1 end
    function S:uid() return self.UID end
    OfflineStore = S; return S
end
package.preload['offline.router'] = function ()
    local R = { handlers = {} }
    function R:on(k, f) self.handlers[k] = f end
    function R:has(k) return self.handlers[k] ~= nil end
    OfflineRouter = R; return R
end

ErrorCode = {
    OK = 0, UnknowError = 1, ArgError = 2,
    Guild = { GuildNotExist = 3501 },
}
CUINotificationEvent = { OnServerRequestError = 'OnServerRequestError' }

-- ============================================================ GIẢ LẬP (toàn cục)
BASE = { Uid = 100001, CharacterName = 'Offline', Level = 90, VipLevel = 15,
         UserFightCapacity = 7884, Gender = true, Portrait = 1 }
G_UserLogic = {}
function G_UserLogic:GetBaseInfo() return true, BASE end
function G_UserLogic:GetClientCommonData(k) return true, DU_LIEU[k] end
function G_UserLogic:SetClientCommonData(k, v) DU_LIEU[k] = v; return true end

DU_LIEU = {}
GUILD_TAB = {}
G_DataManager = {}
function G_DataManager:GetUserDataWithName(n) return 0, GUILD_TAB end
function G_DataManager:ChangeUserData(n, t, k)
    for kk, vv in pairs(t) do GUILD_TAB[kk] = vv end
    self.DA_DOI = (self.DA_DOI or 0) + 1
end

THONG_BAO = {}
g_CUINotificationCenter = {}
function g_CUINotificationCenter:PostNotification(ev, ma) THONG_BAO[#THONG_BAO + 1] = ma end

NOTICE_GOI = {}
G_GuildLogic = {}
function G_GuildLogic:OnGuildNoticeInfoChange(a, b, c) NOTICE_GOI[#NOTICE_GOI + 1] = { a, b, c } end

dofile([[__SC__/offline/handlers/bang_hoi.lua]])
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
local function datLai()
    DU_LIEU, GUILD_TAB, THONG_BAO, NOTICE_GOI = {}, {}, {}, {}
    OfflineStore.dongBo = 0
end
local function goi(khoa, ...)
    local c = ctxGia()
    R.handlers[khoa](c, ...)
    return c, c.calls[#c.calls]
end

-- ============================================================ 1. ĐĂNG KÝ
for _, k in ipairs({
    'G_GuildLogic.ClientCreateGuild', 'G_GuildLogic.ClientGetGuildInfo',
    'G_GuildLogic.ClientModifyNotice', 'G_GuildLogic.ClientGetGuildLogList',
    'G_GuildLogic.ClientGetGuildApplyList', 'G_GuildLogic.ClientExitGuild',
    'G_GuildLogic.ClientCancelGuild', 'G_GuildLogic.ClientDonateGuild',
}) do
    check(R:has(k), 'dang ky ' .. k)
end
check(type(OfflineBangHoi) == 'table', 'co bang OfflineBangHoi')

-- ============================================================ 2. CHƯA CÓ BANG
datLai()
local c2, x2 = goi('G_GuildLogic.ClientGetGuildInfo', 1, 10, 0)
check(x2 and x2.f == 'OnGetGuildInfo' and x2.args[1] == ErrorCode.Guild.GuildNotExist,
      'chua co bang -> MA GOC 3501 (GuildNotExist), khong bia bang',
      x2 and tostring(x2.args[1]))

-- ============================================================ 3. LẬP BANG
datLai()
local _, x3 = goi('G_GuildLogic.ClientCreateGuild', '1', 'Bang Cua Toi', 'Chao mung')
local b = DU_LIEU['OfflineGuild']
check(x3 and x3.f == 'OnCreateGuild', 'tra OnCreateGuild', x3 and x3.f)
check(type(b) == 'table' and b.Name == 'Bang Cua Toi' and b.StrNotice == 'Chao mung'
      and tonumber(b.GuildId) and b.PictrueId == '1',
      'bang co Name/StrNotice/GuildId/PictrueId', type(b))
check(b and tonumber(b.HeadUid) == 100001, 'bang chu = uid nguoi choi', b and tostring(b.HeadUid))
check(b and type(b.memberList) == 'table' and #b.memberList == 1
      and b.memberList[1].Uid == 100001 and b.memberList[1].Nick == 'Offline',
      'memberList co DUNG mot dong cua minh (co Nick)',
      b and b.memberList and tostring(b.memberList[1] and b.memberList[1].Nick))
check(GUILD_TAB.GuildId ~= nil and GUILD_TAB.GuildId > 0,
      'co ghi co GameUserGuildData.GuildId (client biet dang o trong bang)',
      tostring(GUILD_TAB.GuildId))
check(OfflineStore.dongBo >= 1, 'co dong bo file luu')

-- ============================================================ 4. LẬP BANG LẦN HAI
datLai()
goi('G_GuildLogic.ClientCreateGuild', '1', 'Bang A', 'x')
local _, x4 = goi('G_GuildLogic.ClientCreateGuild', '1', 'Bang B', 'y')
check(x4 and type(x4.args[1]) == 'table' and x4.args[1].err ~= nil,
      'dang o trong bang -> tu choi lap them (tra {err})', x4 and type(x4.args[1]))
check(DU_LIEU['OfflineGuild'].Name == 'Bang A', 'bang cu giu nguyen',
      DU_LIEU['OfflineGuild'].Name)

-- ============================================================ 5. THÔNG TIN BANG
datLai()
goi('G_GuildLogic.ClientCreateGuild', '1', 'Bang A', 'x')
local _, x5 = goi('G_GuildLogic.ClientGetGuildInfo', 1, 10, 0)
check(x5 and x5.f == 'OnGetGuildInfo' and x5.args[1] == 0, 'co bang -> err 0',
      x5 and tostring(x5.args[1]))
local info = x5 and x5.args[2]
check(type(info) == 'table' and info.Name == 'Bang A' and type(info.memberList) == 'table',
      'tra tGuildInfo co Name + memberList',
      type(info))
check(info and info.StrNotice ~= nil and info.PictrueId ~= nil and info.HeadUid ~= nil,
      'du truong UI doc: StrNotice/PictrueId/HeadUid')

-- ============================================================ 6. ĐỔI THÔNG BÁO
datLai()
goi('G_GuildLogic.ClientCreateGuild', '1', 'Bang A', 'cu')
local _, x6 = goi('G_GuildLogic.ClientModifyNotice', 1, 'moi', 'wx', 'qq')
local b6 = DU_LIEU['OfflineGuild']
check(b6.StrNotice == 'moi' and b6.StrWeChatGroup == 'wx' and b6.StrQQGroup == 'qq',
      'luu du ba truong thong bao', b6.StrNotice)
check(x6 and x6.f == 'OnModifyNotice' and x6.args[1] == 0, 'tra OnModifyNotice(0)')
check(NOTICE_GOI[1] and NOTICE_GOI[1][1] == 'moi', 'goi OnGuildNoticeInfoChange cho UI')

-- ============================================================ 7. DANH SÁCH RỖNG ĐÚNG HÌNH
datLai()
local _, x7 = goi('G_GuildLogic.ClientGetGuildLogList', 1)
check(x7 and x7.args[2] ~= nil and type(x7.args[2]) == 'table' and next(x7.args[2]) == nil,
      'nhat ky -> danh sach RONG (khong nil)', x7 and type(x7.args[2]))
local _, x8 = goi('G_GuildLogic.ClientGetGuildApplyList', 1)
check(x8 and x8.args[2] ~= nil and type(x8.args[2]) == 'table' and next(x8.args[2]) == nil,
      'don xin -> danh sach RONG (khong nil)', x8 and type(x8.args[2]))

-- ============================================================ 8. RỜI / GIẢI TÁN
datLai()
goi('G_GuildLogic.ClientCreateGuild', '1', 'Bang A', 'x')
local _, x9 = goi('G_GuildLogic.ClientExitGuild', 1)
check(x9 and x9.f == 'OnExitGuild', 'tra OnExitGuild', x9 and x9.f)
check(DU_LIEU['OfflineGuild'] == nil, 'roi bang -> xoa du lieu bang')
check(GUILD_TAB.GuildId == 0, 'co GameUserGuildData.GuildId ve 0', tostring(GUILD_TAB.GuildId))

datLai()
goi('G_GuildLogic.ClientCreateGuild', '1', 'Bang A', 'x')
local _, x10 = goi('G_GuildLogic.ClientCancelGuild', 1)
check(x10 and x10.f == 'OnCancelGuild' and x10.args[1] == 0, 'giai tan -> OnCancelGuild(0)')
check(DU_LIEU['OfflineGuild'] == nil, 'giai tan -> xoa du lieu bang')

-- ============================================================ 9. ĐÓNG GÓP CHƯA LÀM -> BÁO ĐÚNG
datLai()
local _, x11 = goi('G_GuildLogic.ClientDonateGuild', 1, 'gold', 100)
check(x11 and x11.f == 'OnDonateGuild' and x11.args[1] ~= 0,
      'dong gop chua co bang gia -> tra ma loi (khong doan gia)', x11 and tostring(x11.args[1]))

io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
