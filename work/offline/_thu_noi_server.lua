-- _thu_noi_server.lua — bộ thử cho LUẬT "CHỈ ĐẨY KHI WORLD CỤC BỘ MỚI HƠN" (4/11).
--   Chạy qua `_chay_het.py` (lua51.dll). Không cần Postgres, không cần máy ảo.
--
-- Đo phần CLIENT của cầu RPC: gửi `snapshotVersion`, lưu `v` khi được nhận, KHÔNG
-- lưu `v` khi server từ chối (`tl.stale = true`), và vẫn rơi về handler offline khi
-- server không trả lời. Mọi thông điệp ASCII (bẫy cp1252 của bộ thử).
package.path = [[__SC__/?.lua;__SC__/?/init.lua;]] .. package.path

local function ghi(m) io.write('[log] ' .. tostring(m) .. '\n') end
package.preload['offline.log'] = function ()
    local L = { info = ghi, warn = ghi, err = ghi }; OfflineLog = L; return L
end

-- Dùng thẳng thư mục TEMP (đã tồn tại) — không phải tạo thư mục con.
local TMP = tostring(os.getenv('TEMP') or os.getenv('TMP') or '/tmp'):gsub('\\', '/')
local KHOA = TMP .. '/offline_world_v.txt'

package.preload['offline.store'] = function ()
    local S = { TABLES = {}, data = { GameUserBaseInfo = { Level = 3 } }, dongBo = 0 }
    function S:path() return TMP .. '/offline_save_42.json' end
    function S:syncFromClient() self.dongBo = self.dongBo + 1 end
    OfflineStore = S; return S
end

package.preload['offline.router'] = function ()
    local R = { handlers = {} }
    function R:getFor(o, f) return self.handlers[tostring(o) .. '.' .. tostring(f)] end
    function R:on(k, f) self.handlers[k] = f end
    OfflineRouter = R; return R
end

package.preload['offline.tai_khoan'] = function ()
    local T = { uid = 42 }
    function T:goi(duong, body, cb)
        self.lan = { duong = duong, body = body, cb = cb }
    end
    OfflineTaiKhoan = T; return T
end

-- `offline/net.lua` giả: hàng đợi + dispatch gốc.
local DISPATCH_GOC = 0
OfflineNet = {
    queue = {},
    dispatch = function (self2, nModule, strObj, strFunc, ...)
        DISPATCH_GOC = DISPATCH_GOC + 1
    end,
}
sngHttpRequestWithString = function () end

dofile([[__SC__/offline/noi_server.lua]])
local M = OfflineNoiServer

local dat, hong = 0, 0
local function check(ok, ten, ct)
    if ok then dat = dat + 1; io.write('  OK   ' .. ten .. '\n')
    else hong = hong + 1; io.write('  HONG ' .. ten .. (ct ~= nil and (' -> ' .. tostring(ct)) or '') .. '\n') end
end

-- Dọn tệp phiên bản của lượt chạy trước.
os.remove(KHOA)

-- 1. Chưa biết phiên bản
check(M:docPhienBan(42) == nil, 'chua co tep -> docPhienBan = nil')

-- 2. Ghi rồi đọc lại; uid khác thì KHÔNG dùng bản của uid này
M:luuPhienBan(42, 7)
check(M:docPhienBan(42) == 7, 'luu 7 -> doc lai dung 7')
check(M:docPhienBan(43) == nil, 'uid khac -> nil (khong lay nham phien ban)')

-- 3. Lượt gửi mang snapshotVersion hiện có
M:gui(5, 'G_LotteryLogic', 'ClientGetLotteryData', { n = 0 })
local lan = OfflineTaiKhoan.lan
check(lan ~= nil and lan.duong == '/api/rpc', 'gui -> POST /api/rpc')
check(type(lan) == 'table' and lan.body and lan.body.snapshotVersion == 7,
      'body.snapshotVersion = 7 (phien ban dang giu)',
      lan and lan.body and lan.body.snapshotVersion)
check(lan and lan.body and lan.body.uid == 42 and type(lan.body.snapshot) == 'table',
      'body co uid + snapshot')
check(#OfflineNet.queue == 0, 'chua tra loi thi chua day gi vao hang doi')

-- 4. Server NHẬN (err=0, v=9) -> lưu 9, đẩy OnReciveResponse
lan.cb(true, { err = 0, obj = '', cb = 'OnGetLotteryData', suKien = {}, gui = 0, v = 9 })
check(M:docPhienBan(42) == 9, 'nhan v=9 -> luu 9')
local q = OfflineNet.queue[#OfflineNet.queue]
check(q ~= nil and q.func == 'OnReciveResponse', 'day OnReciveResponse vao hang doi')
check(M.demNhan == 1 and M.hongLuc == nil, 'demNhan=1, khong co moc hong')

-- 5. Lượt sau gửi đúng 9
M:gui(5, 'G_LotteryLogic', 'ClientGetLotteryData', { n = 0 })
check(OfflineTaiKhoan.lan.body.snapshotVersion == 9, 'luot sau gui snapshotVersion = 9')

-- 6. Server TỪ CHỐI (stale) -> KHÔNG lưu v (lưu là tự phá cổng ở lượt sau)
local truoc = M:docPhienBan(42)
OfflineTaiKhoan.lan.cb(true, { err = 1, obj = '', cb = '', suKien = {}, gui = { err = 1 },
                                stale = true, v = 12 })
check(M:docPhienBan(42) == truoc,
      'stale=true -> KHONG luu v=12 (giu ' .. tostring(truoc) .. ')', M:docPhienBan(42))
local q2 = OfflineNet.queue[#OfflineNet.queue]
check(q2 ~= nil and q2.args[3] == 1, 'stale -> client nhan err=1 (dung lop dang tai)')

-- 7. Server KHÔNG TRẢ LỜI -> rơi về handler offline nếu có
local soLanCu = DISPATCH_GOC
OfflineRouter.handlers['G_LotteryLogic.ClientGetLotteryData'] = function () end
M:gui(5, 'G_LotteryLogic', 'ClientGetLotteryData', { n = 0 })
OfflineTaiKhoan.lan.cb(false, { code = 3001 })
check(DISPATCH_GOC == soLanCu + 1, 'hong HTTP -> goi lai dispatch offline')
check(M.demHong == 1 and M.hongLuc ~= nil, 'ghi moc hong de nghi 30 s')
check(M:gui(5, 'G_LotteryLogic', 'ClientGetLotteryData', { n = 0 }) == false,
      'trong 30 s: khong goi server, di thang offline')

-- 8. Handler offline KHÔNG có -> trả err=1 (không bỏ trống, không treo lớp tải)
M.hongLuc = nil
local soLanCu2 = DISPATCH_GOC
M:gui(5, 'G_KhongCo', 'ClientKhongCo', { n = 0 })
OfflineTaiKhoan.lan.cb(false, { code = 3001 })
local q3 = OfflineNet.queue[#OfflineNet.queue]
check(DISPATCH_GOC == soLanCu2, 'khong co handler offline -> KHONG goi dispatch')
check(q3 ~= nil and q3.args[3] == 1, 'khong co handler offline -> err=1, khong bo trong')

os.remove(KHOA)
io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
if hong > 0 then os.exit(1) end
