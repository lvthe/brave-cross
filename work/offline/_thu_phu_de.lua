-- _thu_phu_de.lua — bộ thử cho `offline/handlers/phu_de.lua`
-- (chạy bằng `python _thu_nha_cua.py _thu_phu_de.lua`).
--
-- Đo: lưu đúng trường, tách riêng theo ải, trần 100 dòng (bỏ dòng CŨ NHẤT), và hình phản hồi
-- NĂM tham số vị trí mà `ClientSubtitleLogic:OnGetGetCopySubtitle` đòi.
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

-- ============================================================ GIẢ LẬP (toàn cục)
DU_LIEU = {}
G_UserLogic = {}
function G_UserLogic:GetClientCommonData(k) return true, DU_LIEU[k] end
function G_UserLogic:SetClientCommonData(k, v) DU_LIEU[k] = v; return true end

dofile([[__SC__/offline/handlers/phu_de.lua]])
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
local function datLai() DU_LIEU = {}; OfflineStore.dongBo = 0 end

local KS = 'G_SubtitleLogic.ClientSetUserCopySubtitle'
local KG = 'G_SubtitleLogic.ClientGetCopySubtitle'
local function gui(...) R.handlers[KS](ctxGia(), ...) end
local function lay(...)
    local c = ctxGia()
    R.handlers[KG](c, ...)
    return c
end

-- ============================================================ 1. ĐĂNG KÝ
check(R:has(KS), 'dang ky ' .. KS)
check(R:has(KG), 'dang ky ' .. KG)
check(type(OfflinePhuDe) == 'table', 'co bang OfflinePhuDe')

-- ============================================================ 2. GỬI + ĐỌC
datLai()
gui('L_N_01_03', 'chao tat ca', 1200, 'blue')
local all = DU_LIEU['OfflineCopySubtitles']
local ds = all and all['L_N_01_03']
check(type(ds) == 'table' and #ds == 1, 'luu 1 dong cho ai L_N_01_03', ds and #ds)
check(ds and ds[1].Subtitle == 'chao tat ca' and ds[1].Time == 1200 and ds[1].Color == 'blue',
      'luu dung Subtitle/Time/Color',
      ds and (tostring(ds[1].Subtitle) .. '/' .. tostring(ds[1].Time) .. '/' .. tostring(ds[1].Color)))
check(OfflineStore.dongBo >= 1, 'co dong bo file luu')

local c2 = lay('L_N_01_03')
local x2 = c2.calls[1]
check(x2 ~= nil and x2.obj == 'G_SubtitleLogic' and x2.f == 'OnGetGetCopySubtitle',
      'goi dung ten ham nhan', x2 and (tostring(x2.obj) .. '.' .. tostring(x2.f)))
check(x2 ~= nil and x2.n == 5, 'tra DU 5 tham so vi tri (err, key, cua minh, ban be, ngau nhien)',
      x2 and x2.n)
check(x2 and x2.args[1] == 0 and x2.args[2] == 'L_N_01_03', 'err = 0 va copyKey dung',
      x2 and (tostring(x2.args[1]) .. '/' .. tostring(x2.args[2])))
check(x2 and type(x2.args[3]) == 'table' and #x2.args[3] == 1, 'danh sach cua minh co 1 dong',
      x2 and #x2.args[3])
check(x2 and type(x2.args[4]) == 'table' and type(x2.args[5]) == 'table'
      and next(x2.args[4]) == nil and next(x2.args[5]) == nil,
      'ban be / ngau nhien RONG (offline mot nguoi)')

-- ============================================================ 3. TÁCH RIÊNG THEO ẢI
datLai()
gui('ai_A', 'dong A', 100, 'red')
gui('ai_B', 'dong B', 200, 'green')
gui('ai_A', 'dong A2', 300, 'red')
local c3 = lay('ai_A')
check(c3.calls[1] and #c3.calls[1].args[3] == 2, 'ai A co 2 dong, ai B khong lan sang',
      c3.calls[1] and #c3.calls[1].args[3])
local c3b = lay('ai_B')
check(c3b.calls[1] and #c3b.calls[1].args[3] == 1, 'ai B co 1 dong',
      c3b.calls[1] and #c3b.calls[1].args[3])

-- ============================================================ 4. ẢI CHƯA CÓ -> DANH SÁCH RỖNG
datLai()
local c4 = lay('ai_moi')
check(c4.calls[1] and type(c4.calls[1].args[3]) == 'table' and #c4.calls[1].args[3] == 0,
      'ai chua co dong nao -> tra danh sach RONG (khong phai nil)')

-- ============================================================ 5. TRẦN 100 DÒNG
datLai()
for i = 1, 105 do gui('ai_dai', 'dong ' .. i, i, 'white') end
local ds5 = DU_LIEU['OfflineCopySubtitles'] and DU_LIEU['OfflineCopySubtitles']['ai_dai']
check(ds5 and #ds5 == 100, 'giu toi da 100 dong', ds5 and #ds5)
check(ds5 and ds5[1].Subtitle == 'dong 6', 'bo dong CU NHAT (giu tu dong 6 den 105)',
      ds5 and tostring(ds5[1].Subtitle))

-- ============================================================ 6. THAM SỐ SAI -> KHÔNG LƯU
datLai()
gui('ai_X', '', 10, 'red')
gui(nil, 'abc', 10, 'red')
gui('ai_X', 123, 10, 'red')
local all6 = DU_LIEU['OfflineCopySubtitles']
check(all6 == nil or next(all6) == nil, 'tham so sai -> khong luu gi',
      all6 and tostring(next(all6)))

io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
