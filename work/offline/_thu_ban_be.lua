-- _thu_ban_be.lua — bộ thử cho `offline/handlers/ban_be.lua`
-- (chạy bằng `python _thu_nha_cua.py _thu_ban_be.lua`).
--
-- Đo hai điều: lệnh ĐỌC trả DANH SÁCH RỖNG đúng hình (không nil, không bảng lạ), và lệnh
-- THAO TÁC trả MÃ LỖI GỐC của họ bạn bè — không giả vờ thành công.
package.path = [[__SC__/?.lua;__SC__/?/init.lua;]] .. package.path

local function ghi(m) io.write('[log] ' .. tostring(m) .. '\n') end
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

ErrorCode = { UnknowError = 1, ArgError = 2,
    Friend = { NoApply = 3804, NotFriend = 3805, NoGift = 3807 } }

dofile([[__SC__/offline/handlers/ban_be.lua]])
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
    R.handlers[khoa](c, ...)
    return c, c.calls[#c.calls]
end

-- ============================================================ 1. ĐĂNG KÝ (14 khoá)
local DS = {
    'ClientGetUserRelations', 'ClientGetUserFriends', 'ClientGetRecommendedFriend',
    'ClientSearchUserWithName', 'ClientGetUserDetailByUid', 'ClientApplyForFriend',
    'ClientAcceptApply', 'ClientRefuseAllApply', 'ClientRemoveFriend', 'ClientSendGift',
    'ClientReceiveGift', 'ClientSendGiftAll', 'ClientReceiveGiftAll', 'ClientFightFriend',
}
for _, k in ipairs(DS) do
    check(R:has('G_FriendLogic.' .. k), 'dang ky ' .. k)
end

-- ============================================================ 2. ĐỌC -> RỖNG, ĐÚNG HÌNH
local _, x = goi('G_FriendLogic.ClientGetUserRelations')
check(x and x.f == 'OnGetUserRelations' and x.args[1] == 0
      and type(x.args[2]) == 'table' and next(x.args[2]) == nil,
      'GetUserRelations -> (0, BANG RONG)', x and (tostring(x.args[1]) .. '/' .. type(x.args[2])))

local _, x2 = goi('G_FriendLogic.ClientGetUserFriends')
check(x2 and x2.args[1] == 0 and type(x2.args[2]) == 'table' and next(x2.args[2]) == nil,
      'GetUserFriends -> (0, BANG RONG)')

local _, x3 = goi('G_FriendLogic.ClientGetRecommendedFriend')
check(x3 and x3.args[1] == 0 and type(x3.args[2]) == 'table' and next(x3.args[2]) == nil,
      'GetRecommendedFriend -> (0, BANG RONG)')

local _, x4 = goi('G_FriendLogic.ClientSearchUserWithName', 'abc')
check(x4 and x4.args[1] == 0 and type(x4.args[2]) == 'table' and next(x4.args[2]) == nil,
      'SearchUserWithName -> (0, BANG RONG) = khong tim thay')

-- ============================================================ 3. THAO TÁC -> MÃ GỐC
local _, y1 = goi('G_FriendLogic.ClientApplyForFriend', 123)
check(y1 and y1.args[1] == ErrorCode.Friend.NotFriend, 'ApplyForFriend -> 3805 (khong co ai)',
      y1 and y1.args[1])
local _, y2 = goi('G_FriendLogic.ClientAcceptApply', 123)
check(y2 and y2.args[1] == ErrorCode.Friend.NoApply and y2.args[2] == 123,
      'AcceptApply -> 3804 + tra lai uid', y2 and y2.args[1])
local _, y3 = goi('G_FriendLogic.ClientRefuseAllApply')
check(y3 and y3.args[1] == ErrorCode.Friend.NoApply, 'RefuseAllApply -> 3804', y3 and y3.args[1])
local _, y4 = goi('G_FriendLogic.ClientRemoveFriend', 123)
check(y4 and y4.args[1] == ErrorCode.Friend.NotFriend and y4.args[3] == 123,
      'RemoveFriend -> 3805 + (giam qua=false, uid)', y4 and y4.args[1])
local _, y5 = goi('G_FriendLogic.ClientSendGift', 123)
check(y5 and y5.args[1] == ErrorCode.Friend.NotFriend, 'SendGift -> 3805', y5 and y5.args[1])
local _, y6 = goi('G_FriendLogic.ClientReceiveGift', 123)
check(y6 and y6.args[1] == ErrorCode.Friend.NoGift, 'ReceiveGift -> 3807 (khong co qua)',
      y6 and y6.args[1])
local _, y7 = goi('G_FriendLogic.ClientSendGiftAll')
check(y7 and y7.args[1] == ErrorCode.Friend.NoGift, 'SendGiftAll -> 3807', y7 and y7.args[1])
local _, y8 = goi('G_FriendLogic.ClientReceiveGiftAll')
check(y8 and y8.args[1] == ErrorCode.Friend.NoGift, 'ReceiveGiftAll -> 3807', y8 and y8.args[1])
local _, y9 = goi('G_FriendLogic.ClientGetUserDetailByUid', 123)
check(y9 and y9.args[1] == ErrorCode.Friend.NotFriend, 'GetUserDetailByUid -> 3805', y9 and y9.args[1])
local _, y10 = goi('G_FriendLogic.ClientFightFriend', 123, {})
check(y10 and y10.args[1] == ErrorCode.Friend.NotFriend and y10.n == 3,
      'FightFriend -> 3805 + DU 3 tham so (err, data, heroList)', y10 and y10.n)

io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
