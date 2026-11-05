-- _thu_hanh_dong.lua — bộ thử cho `offline/hanh_dong.lua` (nhật ký hành động).
package.path = [[__SC__/?.lua;__SC__/?/init.lua;]] .. package.path

local function ghi(m) io.write('[log] ' .. tostring(m) .. '\n') end
package.preload['offline.log'] = function ()
    local L = { info = ghi, warn = ghi, err = ghi }; OfflineLog = L; return L
end

sngHttpRequestWithString = function () end

local TK = { uid = 1044, calls = {} }
function TK:goi(duong, body, cb)
    self.calls[#self.calls + 1] = { duong = duong, body = body }
    if cb ~= nil then cb(true, { ok = true }) end
end
OfflineTaiKhoan = TK

local HD = dofile([[__SC__/offline/hanh_dong.lua]])

local dat, hong = 0, 0
local function check(ok, ten, ct)
    if ok then dat = dat + 1; io.write('  OK   ' .. ten .. '\n')
    else hong = hong + 1; io.write('  HONG ' .. ten .. (ct ~= nil and (' -> ' .. tostring(ct)) or '') .. '\n') end
end

io.write('\n=== hanh dong ===\n')

TK.uid = nil
check(HD:ghi('login', 'enter', {}) == false and #TK.calls == 0,
    'chua dang nhap -> khong gui')
TK.uid = 1044

local httpCu = sngHttpRequestWithString
sngHttpRequestWithString = nil
check(HD:ghi('login', 'enter', {}) == false and #TK.calls == 0,
    'khong co HTTP -> khong gui')
sngHttpRequestWithString = httpCu

HD:datLai()
check(HD:ghi('login', 'enter', { lan = 1 }) == true, 'gui duoc su kien login')
local c = TK.calls[#TK.calls]
check(c ~= nil and c.duong == '/api/event'
    and c.body.kind == 'login' and c.body.key == 'enter'
    and c.body.uid == 1044 and type(c.body.value) == 'table',
    'dung duong + du lieu', c and (c.duong .. ' ' .. tostring(c.body and c.body.kind)))

local soCu = #TK.calls
check(HD:ghi('login', 'enter', {}) == false and #TK.calls == soCu,
    'cung kind trong 2 giay -> chan spam, khong gui')

check(HD:ghi('redeem', 'ABC', { diamonds = 10 }) == true and #TK.calls == soCu + 1,
    'kind khac -> gui duoc ngay')

HD:datLai()
check(HD:ghi('recharge', 'claim', 'khong-phai-bang') == true, 'value khong phai bang van gui')
c = TK.calls[#TK.calls]
check(type(c.body.value) == 'table', 'value duoc thay bang {}')

HD:datLai()
check(HD:ghi('', 'x', {}) == false, 'kind rong -> khong gui')
check(HD:ghi(nil, nil, nil) == false, 'kind nil -> khong gui')

io.write(string.format('\nKET QUA: dat %d, hong %d\n', dat, hong))
os.exit(hong == 0 and 0 or 1)
