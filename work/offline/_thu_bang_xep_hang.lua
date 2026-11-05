-- _thu_bang_xep_hang.lua — bộ thử cho `offline/handlers/bang_xep_hang.lua`
-- (chạy bằng `python _thu_nha_cua.py _thu_bang_xep_hang.lua`).
--
-- Bốn khoá này KHÔNG gọi luật gốc nào (bảng xếp hạng là trạng thái máy chủ). Nên bộ thử
-- đo ĐÚNG ba thứ dễ hỏng:
--   1. KHOÁ đăng ký khớp cặp (obj, func) client thật gửi.
--   2. TÊN HÀM NHẬN đúng của từng tab — gọi nhầm tab thì bảng im lặng.
--   3. HÌNH THAM SỐ: đúng BA tham số VỊ TRÍ (bảng, số, số), không bọc `{err, data}` —
--      hàm client nhận `(tRankList, nSelfRank, nYesterdayRank)` và kiểm từng cái.
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

-- Giả lập: uid mà UI đối chiếu, và hàm dựng dòng của client.
g_CUIGameRPCManager = {}
function g_CUIGameRPCManager:GetChinaMixUid() return 100001 end

local HOT = { CharacterName = 'Offline', Level = 90, Gold = 1000 }
G_RankLogic = {}
G_RankLogic.HONG = false
function G_RankLogic:GetUserHotData()
    if self.HONG then error('no gia lap') end
    local t = {}
    for k, v in pairs(HOT) do t[k] = v end
    return true, t
end

-- Bốn tab: khoá gửi lên -> tên hàm client phải nhận.
local BANG = {
    { khoa = 'G_RankLogic.ClientGet5HeroPowerRank', nhan = 'OnGet5HeroPowerRank', ten = '5 tuong' },
    { khoa = 'G_RankLogic.ClientGetPveNormalRank',  nhan = 'OnGetPveNormalRank',  ten = 'PvE thuong' },
    { khoa = 'G_RankLogic.ClientGetPveEliteRank',   nhan = 'OnGetPveEliteRank',   ten = 'PvE tinh anh' },
    { khoa = 'G_RankLogic.ClientGetPveStarRank',    nhan = 'OnGetPveStarRank',    ten = 'PvE sao' },
}

dofile([[__SC__/offline/handlers/bang_xep_hang.lua]])
local R = require('offline.router')

local dat, hong = 0, 0
local function check(ok, ten, ct)
    if ok then dat = dat + 1; io.write('  OK   ' .. ten .. '\n')
    else hong = hong + 1; io.write('  HONG ' .. ten .. (ct ~= nil and (' -> ' .. tostring(ct)) or '') .. '\n') end
end

check(type(OfflineBangXepHang) == 'table', 'co bang OfflineBangXepHang')

for _, t in ipairs(BANG) do
    check(R:has(t.khoa), 'dang ky ' .. t.khoa)

    local c = { calls = {} }
    function c:call(obj, f, ...)
        self.calls[#self.calls + 1] = { obj = obj, f = f, args = { ... }, n = select('#', ...) }
    end
    R.handlers[t.khoa](c)

    local x = c.calls[1]
    check(x ~= nil and x.obj == 'G_RankLogic' and x.f == t.nhan,
          t.ten .. ': goi DUNG ' .. t.nhan, x and (tostring(x.obj) .. '.' .. tostring(x.f)))
    check(x ~= nil and x.n == 3, t.ten .. ': tra DUNG 3 tham so vi tri', x and x.n)
    check(x ~= nil and type(x.args[1]) == 'table' and x.args[2] == 1 and x.args[3] == 1,
          t.ten .. ': (bang, hang 1, hang hom qua 1)',
          x and string.format('%s/%s/%s', type(x.args[1]), tostring(x.args[2]), tostring(x.args[3])))

    -- Dòng của MÌNH phải nằm dưới ĐÚNG khoá uid mà UI dùng, và có TÊN — trả bảng rỗng
    -- thì UI hiện "hạng 1" mà trống tên (đo 1/11).
    local dong = x and type(x.args[1]) == 'table' and x.args[1]['100001']
    check(type(dong) == 'table' and dong.CharacterName == 'Offline' and dong.Rank == 1,
          t.ten .. ': dong cua minh dung uid + co ten + hang 1',
          type(dong) == 'table' and tostring(dong.CharacterName) .. '/' .. tostring(dong.Rank) or 'khong co dong')
end

-- Dựng dòng lỗi -> vẫn phải trả một dòng tối thiểu, không làm hỏng cả bảng.
G_RankLogic.HONG = true
local c9 = { calls = {} }
function c9:call(obj, f, ...) self.calls[#self.calls + 1] = { obj = obj, f = f, args = { ... } } end
R.handlers['G_RankLogic.ClientGet5HeroPowerRank'](c9)
G_RankLogic.HONG = false
local x9 = c9.calls[1]
local d9 = x9 and type(x9.args[1]) == 'table' and x9.args[1]['100001']
check(type(d9) == 'table' and d9.Rank == 1, 'GetUserHotData nem loi -> van co dong toi thieu {Rank=1}',
      type(d9) == 'table' and tostring(d9.Rank) or 'khong co dong')

io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
