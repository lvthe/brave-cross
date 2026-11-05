--[[
	offline/handlers/ban_be.lua — BẠN BÈ (mô hình "không có ai").

	`G_FriendLogic` (`ClientFriendLogic`, thực thể `G_FriendLogic`) — 14 khoá mà màn
	`CUIFriend2` gọi. Trước lượt này KHÔNG có handler nào ⇒ mở panel Bạn Bè là lớp tải quay mãi
	(`CUIFriend2:onShow` gọi `G_FriendLogic:GetUserRelations()`, `:106`).

	MÔ HÌNH [MOI]: máy chủ giả chỉ có MỘT người chơi, nên KHÔNG có ai để kết bạn, không có thư
	mời, không có quà. Mọi lệnh ĐỌC trả **danh sách RỖNG đúng hình**; mọi lệnh THAO TÁC trên
	một người bạn không tồn tại trả **mã lỗi gốc** (`ErrorCode.Friend.*`: `NoApply 3804`,
	`NotFriend 3805`, `NoGift 3807`) — KHÔNG giả vờ thành công, vì giả vờ là nói dối người chơi
	rằng đã tặng quà/kết bạn.

	HÌNH DỮ LIỆU lấy từ chỗ UI đọc:
	  · `OnGetUserRelations(nErrCode, returnData)` → `CUIFriend2:GetUserRelationsCallBack`
	    đọc `returnData[tostring(RelationState.X)]` với X = 1 (Bạn) · 2 (Ta xin) ·
	    3 (Xin ta) · 5 (Xin nhau) ⇒ trả **bảng rỗng** là đủ hình.
	  · `OnGetUserFriends(nErrCode, returnData)` · `OnGetRecommendedFriend(nErrCode, tData)`
	    · `OnSearchUserWithName(nErrCode, returnData)`.

	KHÔNG làm (kênh SDK): `ClientGetQQWXFriendDetail` · `ClientGetQqWxFriendFatigue` ·
	`ClientSendQqWxFriendFatigue` · `ClientBatchSendriendFatigue` ·
	`ClientBatchReceiveFriendFatigue` — chúng cần tài khoản QQ/WeChat, ngoài phạm vi.
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflineBanBe = OfflineBanBe or {}

local R = OfflineRouter
local TEN_FILE = "ban be"

local function traLoi(ctx, ham, ...)
	ctx:call("G_FriendLogic", ham, ...)
end

local function ghiLyDo(ten, nMa)
	OfflineLog:info(string.format("%s: %s -> ma %s (offline khong co ai)", TEN_FILE, ten, tostring(nMa)))
end

------------------------------------------------------------- đọc: danh sách RỖNG
R:on("G_FriendLogic.ClientGetUserRelations", function (ctx)
	-- Bảng rỗng: UI tự coi mọi nhóm quan hệ là {} (`tData[tostring(k)] or {}`).
	traLoi(ctx, "OnGetUserRelations", 0, {})
end)

R:on("G_FriendLogic.ClientGetUserFriends", function (ctx)
	traLoi(ctx, "OnGetUserFriends", 0, {})
end)

R:on("G_FriendLogic.ClientGetRecommendedFriend", function (ctx)
	traLoi(ctx, "OnGetRecommendedFriend", 0, {})
end)

R:on("G_FriendLogic.ClientSearchUserWithName", function (ctx, szTen)
	OfflineLog:info(string.format("%s: tim '%s' -> khong co ai", TEN_FILE, tostring(szTen)))
	traLoi(ctx, "OnSearchUserWithName", 0, {})
end)

R:on("G_FriendLogic.ClientGetUserDetailByUid", function (ctx, nUid)
	local nMa = (ErrorCode.Friend and ErrorCode.Friend.NotFriend) or 3805
	ghiLyDo("ClientGetUserDetailByUid(" .. tostring(nUid) .. ")", nMa)
	traLoi(ctx, "OnGetUserDetailByUid", nMa, {})
end)

------------------------------------------------------------- thao tác: từ chối trung thực
R:on("G_FriendLogic.ClientApplyForFriend", function (ctx, nUid)
	local nMa = (ErrorCode.Friend and ErrorCode.Friend.NotFriend) or 3805
	ghiLyDo("ClientApplyForFriend(" .. tostring(nUid) .. ")", nMa)
	traLoi(ctx, "OnApplyForFriend", nMa)
end)

R:on("G_FriendLogic.ClientAcceptApply", function (ctx, nUid)
	local nMa = (ErrorCode.Friend and ErrorCode.Friend.NoApply) or 3804
	ghiLyDo("ClientAcceptApply(" .. tostring(nUid) .. ")", nMa)
	traLoi(ctx, "OnAcceptApply", nMa, nUid)
end)

R:on("G_FriendLogic.ClientRefuseAllApply", function (ctx)
	local nMa = (ErrorCode.Friend and ErrorCode.Friend.NoApply) or 3804
	ghiLyDo("ClientRefuseAllApply", nMa)
	traLoi(ctx, "OnRefuseAllApply", nMa)
end)

R:on("G_FriendLogic.ClientRemoveFriend", function (ctx, nUid)
	local nMa = (ErrorCode.Friend and ErrorCode.Friend.NotFriend) or 3805
	ghiLyDo("ClientRemoveFriend(" .. tostring(nUid) .. ")", nMa)
	traLoi(ctx, "OnRemoveFriend", nMa, false, nUid)
end)

R:on("G_FriendLogic.ClientSendGift", function (ctx, nUid)
	local nMa = (ErrorCode.Friend and ErrorCode.Friend.NotFriend) or 3805
	ghiLyDo("ClientSendGift(" .. tostring(nUid) .. ")", nMa)
	traLoi(ctx, "OnSendGift", nMa)
end)

R:on("G_FriendLogic.ClientReceiveGift", function (ctx, nUid)
	local nMa = (ErrorCode.Friend and ErrorCode.Friend.NoGift) or 3807
	ghiLyDo("ClientReceiveGift(" .. tostring(nUid) .. ")", nMa)
	traLoi(ctx, "OnReceiveGift", nMa)
end)

R:on("G_FriendLogic.ClientSendGiftAll", function (ctx)
	local nMa = (ErrorCode.Friend and ErrorCode.Friend.NoGift) or 3807
	ghiLyDo("ClientSendGiftAll", nMa)
	traLoi(ctx, "OnSendGiftAll", nMa)
end)

R:on("G_FriendLogic.ClientReceiveGiftAll", function (ctx)
	local nMa = (ErrorCode.Friend and ErrorCode.Friend.NoGift) or 3807
	ghiLyDo("ClientReceiveGiftAll", nMa)
	traLoi(ctx, "OnReceiveGiftAll", nMa)
end)

R:on("G_FriendLogic.ClientFightFriend", function (ctx, nUid, tHero)
	local nMa = (ErrorCode.Friend and ErrorCode.Friend.NotFriend) or 3805
	ghiLyDo("ClientFightFriend(" .. tostring(nUid) .. ")", nMa)
	-- (errCode, returnData, fightHeroList)
	traLoi(ctx, "OnFightFriend", nMa, {}, nil)
end)

OfflineLog:info("ban be: da noi 14 khoa (doc rong + thao tac tu choi trung thuc)")

return true
