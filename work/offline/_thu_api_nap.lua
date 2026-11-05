-- _thu_api_nap.lua — bộ thử cho ba nhóm "dịch vụ ngoài" của lớp offline:
--   handlers/ma_doi.lua · handlers/binh_luan.lua · nap_api.lua
-- (chạy bằng `python _thu_nha_cua.py _thu_api_nap.lua`, hoặc cả cổng `_chay_het.py`).
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

EventManagerLogicEvent = { OnReceiveResponse = 'OnReceiveResponse' }

-- ── thế giới giả ────────────────────────────────────────────────────────────
local KC, VATPHAM, EVENTS, TIPS
local function datLai()
    KC, VATPHAM, EVENTS, TIPS = 0, nil, {}, {}
end
datLai()

G_UserLogic = {}
function G_UserLogic:AddDiamond(n, lyDo)
    KC = KC + n
    return true
end
function G_UserLogic:GetBaseInfo() return true, { CharacterName = 'ThuNghiem' } end

G_ChapterLogic = {}
function G_ChapterLogic:SetDataWithPrizeList(ds, n, tu)
    VATPHAM = { ds = ds, n = n, tu = tu }
    return true
end

G_EventManager = {}
function G_EventManager:PostLogicEvent(tData, ten)
    EVENTS[#EVENTS + 1] = { data = tData, name = ten }
end

OfflineNap = {}
function OfflineNap:cong(tien, kc)
    self.daCong = { tien = tien, kc = kc }
    return true
end

g_CUIToolTips = {}
function g_CUIToolTips:AddTipsWithString(s) TIPS[#TIPS + 1] = s; return true end

sngHttpRequestWithString = function () end     -- có đường HTTP

-- Đối tượng tài khoản giả: mỗi lượt `goi` lấy MỘT phản hồi đã xếp hàng.
local TK = { uid = 1044, ds = {}, calls = {} }
function TK:goi(duong, body, cb)
    self.calls[#self.calls + 1] = { duong = duong, body = body }
    local p = table.remove(self.ds, 1)
    if p == nil then return end
    cb(p[1], p[2])
end
OfflineTaiKhoan = TK

dofile([[__SC__/offline/handlers/ma_doi.lua]])
dofile([[__SC__/offline/handlers/binh_luan.lua]])
dofile([[__SC__/offline/nap_api.lua]])
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
local function maCuoi(ctx)
    local x = ctx.calls[#ctx.calls]
    return x and tonumber(x.err)
end
local function suKien(ten)
    for i = #EVENTS, 1, -1 do
        if EVENTS[i].name == ten then return EVENTS[i].data end
    end
    return nil
end

local fMaDoi = R.handlers['G_RedeemCodeLogic.ClientUseRedeemCode']
local fBinhLuan = R.handlers['G_GameCommentLogic.ClientCommentGame']

io.write('\n=== dang ky khoa ===\n')
check(fMaDoi ~= nil, 'co handler ClientUseRedeemCode')
check(fBinhLuan ~= nil, 'co handler ClientCommentGame')

------------------------------------------------------------------ MÃ ĐỔI
io.write('\n=== ma doi thuong ===\n')
datLai(); TK.uid = 1044; TK.calls = {}
TK.ds = { { true, { ok = true, diamonds = 500, items = { { PrizeResType = 2, PropID = 4, PrizeResCount = 3 } } } } }
local c = ctxGia(); fMaDoi(c, 'ABC123')
local sk = suKien('OnServerUseRedeemCode')
check(KC == 500, 'cong 500 kim cuong', KC)
check(VATPHAM ~= nil and #VATPHAM.ds == 1 and VATPHAM.ds[1].PropID == 4,
    'phat danh sach vat pham qua SetDataWithPrizeList')
check(sk ~= nil and sk.nServerErrCode == 0, 'bao UI ma 0', sk and sk.nServerErrCode)
check(maCuoi(c) == 0, 'dong lop tai (OnReciveResponse 0)', maCuoi(c))
check(TK.calls[1] ~= nil and TK.calls[1].duong == '/api/redeem'
    and TK.calls[1].body.code == 'ABC123' and TK.calls[1].body.uid == 1044,
    'goi dung /api/redeem voi uid + ma')

datLai(); TK.ds = { { false, { ok = false, code = 2406 } } }
c = ctxGia(); fMaDoi(c, 'ABC123')
sk = suKien('OnServerUseRedeemCode')
check(KC == 0 and VATPHAM == nil, 'ma da dung: KHONG cong gi')
check(sk ~= nil and sk.nServerErrCode == 2406, 'chuyen ma 2406 cho UI', sk and sk.nServerErrCode)

datLai(); local httpCu = sngHttpRequestWithString; sngHttpRequestWithString = nil
c = ctxGia(); fMaDoi(c, 'ABC123')
sk = suKien('OnServerUseRedeemCode')
check(sk ~= nil and sk.nServerErrCode == 2405, 'khong co HTTP -> 2405 (trung thuc)',
    sk and sk.nServerErrCode)
sngHttpRequestWithString = httpCu

datLai(); TK.uid = nil
c = ctxGia(); fMaDoi(c, 'ABC123')
sk = suKien('OnServerUseRedeemCode')
check(sk ~= nil and sk.nServerErrCode == 2403, 'chua dang nhap -> 2403', sk and sk.nServerErrCode)
TK.uid = 1044

------------------------------------------------------------------ BÌNH LUẬN
io.write('\n=== binh luan ===\n')
datLai(); TK.calls = {}
TK.ds = { { true, { ok = true, id = 77 } } }
c = ctxGia(); fBinhLuan(c)
check(TK.calls[1] ~= nil and TK.calls[1].duong == '/api/comment'
    and TK.calls[1].body.name == 'ThuNghiem' and TK.calls[1].body.uid == 1044,
    'goi /api/comment voi ten nhan vat')
check(maCuoi(c) == 0, 'dong lop tai ma 0', maCuoi(c))

datLai()
sngHttpRequestWithString = nil
c = ctxGia(); fBinhLuan(c)
check(maCuoi(c) == 0 and #TK.calls == 1,
    'khong co server: van dong lop tai, khong gui', #TK.calls)
sngHttpRequestWithString = httpCu

-------------------------------------------------------------------- NẠP
io.write('\n=== nap tu API ===\n')
datLai(); TK.calls = {}
TK.ds = { { true, { ok = true, kc = 300, count = 2 } } }
OfflineNapApi.daHoi = false
OfflineNapApi:kiem()
check(OfflineNap.daCong ~= nil and OfflineNap.daCong.kc == 300 and OfflineNap.daCong.tien == 300,
    'cong 300 KC qua OfflineNap:cong', OfflineNap.daCong and OfflineNap.daCong.kc)
check(TK.calls[1] ~= nil and TK.calls[1].duong == '/api/recharge/claim',
    'goi /api/recharge/claim')
check(#TIPS == 1, 'hien toast bao nap', #TIPS)

local soLan = #TK.calls
OfflineNapApi:kiem()
check(#TK.calls == soLan, 'chi hoi MOT lan moi phien', #TK.calls - soLan)

datLai()
OfflineNap.daCong = nil
OfflineNapApi.daHoi = false
TK.ds = { { true, { ok = true, kc = 0, count = 0 } } }
OfflineNapApi:kiem()
check(OfflineNap.daCong == nil, 'khong co lenh nap: khong cong gi')
check(#TIPS == 0, 'khong co lenh nap: khong toast')

-- lớp chắn không đè lên hai handler mới
dofile([[__SC__/offline/handlers/chua_ho_tro.lua]])
local R2 = require('offline.router')
check(R2.handlers['G_RedeemCodeLogic.ClientUseRedeemCode'] == fMaDoi,
    'lop chan KHONG de len handler ma doi')
check(R2.handlers['G_GameCommentLogic.ClientCommentGame'] == fBinhLuan,
    'lop chan KHONG de len handler binh luan')

io.write(string.format('\nKET QUA: dat %d, hong %d\n', dat, hong))
os.exit(hong == 0 and 0 or 1)
