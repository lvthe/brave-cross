-- _thu_giai_dau.lua — bộ thử cho `offline/handlers/giai_dau.lua`.
package.path = [[__SC__/?.lua;__SC__/?/init.lua;]] .. package.path

local function ghi(m) io.write('[log] ' .. tostring(m) .. '\n') end
package.preload['offline.log'] = function ()
    local L = { info = ghi, warn = ghi, err = ghi }; OfflineLog = L; return L
end
package.preload['offline.store'] = function ()
    local S = { TABLES = {}, data = {} }
    function S:syncFromClient() self.dongBo = (self.dongBo or 0) + 1 end
    OfflineStore = S; return S
end
package.preload['offline.router'] = function ()
    local R = { handlers = {} }
    function R:on(k, f) self.handlers[k] = f end
    function R:has(k) return self.handlers[k] ~= nil end
    OfflineRouter = R; return R
end

sngHttpRequestWithString = function () end

local TRA, CALLS = {}, {}
local TK = { uid = 1044 }
function TK:goi(duong, body, cb)
    CALLS[#CALLS + 1] = { duong = duong, body = body }
    local q = TRA[duong]
    local p = q and table.remove(q, 1)
    if p ~= nil then cb(p[1], p[2]) end
end
OfflineTaiKhoan = TK

local KQ = {}
g_ContestLogic = {}
function g_ContestLogic:OnGetContestInfo(ma, data) KQ[#KQ + 1] = { fn = 'OnGetContestInfo', ma = ma, data = data } end
function g_ContestLogic:OnGetOtherInfo(ma, data) KQ[#KQ + 1] = { fn = 'OnGetOtherInfo', ma = ma, data = data } end
function g_ContestLogic:OnSignUp(ma) KQ[#KQ + 1] = { fn = 'OnSignUp', ma = ma } end

OfflineHanhDong = { ghi = function () end }

dofile([[__SC__/offline/handlers/giai_dau.lua]])
local R = require('offline.router')

local dat, hong = 0, 0
local function check(ok, ten, ct)
    if ok then dat = dat + 1; io.write('  OK   ' .. ten .. '\n')
    else hong = hong + 1; io.write('  HONG ' .. ten .. (ct ~= nil and (' -> ' .. tostring(ct)) or '') .. '\n') end
end
local function datLai()
    TRA, CALLS, KQ = {}, {}, {}
end
local function xep(duong, ...)
    TRA[duong] = TRA[duong] or {}
    for _, p in ipairs({ ... }) do table.insert(TRA[duong], p) end
end
local function cuoi(fn)
    for i = #KQ, 1, -1 do if KQ[i].fn == fn then return KQ[i] end end
    return nil
end
local function ctxGia()
    local c = { calls = {} }
    function c:call() return true end
    return c
end

local fInfo = R.handlers['G_TournamentLogic.ClientGetContestInfo']
local fKhac = R.handlers['G_TournamentLogic.ClientGetOtherInfo']
local fDangKy = R.handlers['G_TournamentLogic.ClientSignUp']

io.write('\n=== dang ky khoa ===\n')
check(fInfo ~= nil and fKhac ~= nil and fDangKy ~= nil, 'co 3 handler (contest info / other info / signup)')

local GIAI = {
    ok = true,
    tournament = { id = 7, status = 'dang_ky', created_ts = 1000, now_ts = 1200,
                   round_seconds = 60, prizes = { 0, 0, 0 } },
    entries = {},
    rounds = {},
}
local function xepDoc(giai, dsGiai)
    xep('/api/tournament/tick', { true, { ok = true } })
    xep('/api/tournaments', { true, { ok = true, tournaments = dsGiai or { { id = 7, status = 'dang_ky' } } } })
    xep('/api/tournament', { true, giai or GIAI })
end

io.write('\n=== thong tin giai ===\n')
datLai(); xepDoc()
fInfo(ctxGia())
local k = cuoi('OnGetContestInfo')
check(k ~= nil and k.ma == 0, 'tra ve ma 0', k and k.ma)
check(k ~= nil and k.data.CurrentStep == 1, 'dang_ky -> buoc 1 (dang ky)', k and k.data.CurrentStep)
check(k ~= nil and k.data.IsApplied == false, 'chua dang ky')
check(k ~= nil and k.data.StepStartTime == 1000 and k.data.StepFinishTime == 4600,
    'cua so dang ky: 1000 .. 4600', k and (tostring(k.data.StepStartTime) .. '..' .. tostring(k.data.StepFinishTime)))
check(CALLS[1] ~= nil and CALLS[1].duong == '/api/tournament/tick',
    'goi tick TRUOC khi doc (vong tu chay)')

datLai(); xepDoc({ ok = true, tournament = GIAI.tournament, entries = { { uid = 1044 } }, rounds = {} })
fInfo(ctxGia())
k = cuoi('OnGetContestInfo')
check(k ~= nil and k.data.IsApplied == true, 'da dang ky -> IsApplied true', k and k.data.IsApplied)

datLai(); xepDoc({ ok = true, tournament = { id = 7, status = 'dang_dien_ra', start_ts = 1000,
    now_ts = 2000, round_seconds = 300, prizes = { 0, 0, 0 } }, entries = {}, rounds = {} })
fInfo(ctxGia())
k = cuoi('OnGetContestInfo')
check(k ~= nil and k.data.CurrentStep == 3, 'dang dien ra -> buoc 3', k and k.data.CurrentStep)
check(k ~= nil and k.data.StepFinishTime == 2300, 'ket thuc buoc = now + round_seconds', k and k.data.StepFinishTime)

datLai(); xepDoc({ ok = true, tournament = { id = 7, status = 'xong', finish_ts = 5000,
    now_ts = 6000, prizes = { 0, 0, 0 } }, entries = {},
    rounds = { { round = 1, matches = { { winner_uid = 5 } } }, { round = 2, matches = { { winner_uid = 9 } } } } })
fInfo(ctxGia())
k = cuoi('OnGetContestInfo')
check(k ~= nil and k.data.CurrentStep == 14, 'xong -> buoc 14', k and k.data.CurrentStep)
check(k ~= nil and k.data.ChampionId == 9, 'nha vo dich lay tu tran cuoi', k and k.data.ChampionId)

datLai(); xep('/api/tournament/tick', { true, { ok = true } })
xep('/api/tournaments', { true, { ok = true, tournaments = {} } })
fInfo(ctxGia())
k = cuoi('OnGetContestInfo')
check(k ~= nil and k.ma == 4401, 'khong co giai -> 4401', k and k.ma)

io.write('\n=== thong tin ngan ===\n')
datLai(); xepDoc()
fKhac(ctxGia())
k = cuoi('OnGetOtherInfo')
check(k ~= nil and k.ma == 0 and k.data.CurrentStep == 1, 'OnGetOtherInfo tra du lieu', k and k.ma)

io.write('\n=== dang ky ===\n')
datLai()
xep('/api/tournaments', { true, { ok = true, tournaments = { { id = 7, status = 'dang_ky' } } },
                          true, { ok = true, tournaments = { { id = 7, status = 'dang_ky' } } } })
xep('/api/tournament/register', { true, { ok = true } })
xepDoc({ ok = true, tournament = GIAI.tournament, entries = { { uid = 1044 } }, rounds = {} })
fDangKy(ctxGia())
k = cuoi('OnSignUp')
check(k ~= nil and k.ma == 0, 'dang ky thanh cong -> ma 0', k and k.ma)
local dk = CALLS[1]
check(dk ~= nil and dk.duong == '/api/tournaments', 'hoi danh sach giai truoc', dk and dk.duong)
local reg = nil
for _, c in ipairs(CALLS) do if c.duong == '/api/tournament/register' then reg = c end end
check(reg ~= nil and reg.body.id == 7 and reg.body.uid == 1044, 'goi register dung id + uid',
    reg and (tostring(reg.body and reg.body.id) .. '/' .. tostring(reg.body and reg.body.uid)))
local sau = cuoi('OnGetContestInfo')
check(sau ~= nil and sau.data.IsApplied == true, 'sau dang ky day lai trang thai (IsApplied)',
    sau and sau.data and sau.data.IsApplied)

datLai()
xep('/api/tournaments', { true, { ok = true, tournaments = { { id = 8, status = 'dang_dien_ra' } } } })
fDangKy(ctxGia())
k = cuoi('OnSignUp')
check(k ~= nil and k.ma == 4401, 'chi co giai dang dien ra -> 4401', k and k.ma)

datLai()
local httpCu = sngHttpRequestWithString
sngHttpRequestWithString = nil
fInfo(ctxGia())
k = cuoi('OnGetContestInfo')
check(k ~= nil and k.ma == 4401, 'khong co HTTP -> 4401', k and k.ma)
sngHttpRequestWithString = httpCu

-- lop chan khong de len 3 handler
dofile([[__SC__/offline/handlers/chua_ho_tro.lua]])
local R2 = require('offline.router')
check(R2.handlers['G_TournamentLogic.ClientGetContestInfo'] == fInfo,
    'lop chan KHONG de len handler thong tin giai')
check(R2.handlers['G_TournamentLogic.ClientGetOtherInfo'] == fKhac,
    'lop chan KHONG de len handler thong tin ngan')
check(R2.handlers['G_TournamentLogic.ClientSignUp'] == fDangKy,
    'lop chan KHONG de len handler dang ky')

io.write(string.format('\nKET QUA: dat %d, hong %d\n', dat, hong))
os.exit(hong == 0 and 0 or 1)
