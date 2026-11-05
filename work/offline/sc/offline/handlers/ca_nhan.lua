--[[
	offline/handlers/ca_nhan.lua — ĐỔI TÊN + ĐỔI ẢNH ĐẠI DIỆN (offline).

	Ba lệnh `G_UserLogic` client gửi (`ClientUserLogic.lua:153/185/213`) — trước lượt
	này KHÔNG có handler ⇒ bấm "Đổi" là lớp tải quay mãi.

	  · `ClientIsUniqueNickName(strNickName)` → `OnIsUniqueNickName(bUnique)`
	    (`ClientUserLogic.lua:148-170`) — màn đổi tên hỏi TRƯỚC, chỉ khi `true` mới
	    gửi lệnh đổi thật.
	  · `ClientChangeNickName(strNickName)` → `OnChangeNickName()` (KHÔNG đối số).
	  · `ClientChangePortrait(strPortrait)` → `OnChangePortrait()` (KHÔNG đối số).

	Ghi dữ liệu bằng API THẬT của client: `G_UserLogicDataManager:SetValue("CharacterName"
	| "Portrait", giá trị)` (`share_UserLogicDataManager.lua:511`) — hàm này tự cập
	nhật `GameUserBaseInfo` và phát Data event cho UI.

	[MOI] Ba quyết định của lớp offline (máy chủ gốc đã chết, không đối chiếu được):
	  1. **Tên luôn "duy nhất"** — offline một người chơi không có bảng tên toàn server;
	     trả `true` là sự thật chứ không phải bỏ kiểm.
	  2. **Cổng dài tên**: 1..20 ký tự (ô nhập của client tự chặn độ dài; server gốc có
	     cổng riêng mà mã không còn). Rỗng / quá dài ⇒ mã **1** để đóng lớp tải.
	  3. **Ảnh đại diện**: nhận mọi chuỗi khác rỗng; danh sách ảnh client đưa ra đã được
	     chính client lọc theo ảnh sở hữu (`CUIUserInfoPortrait`), nên kiểm lại là thừa.
]]

require("offline.log")
require("offline.store")
require("offline.router")

local R = OfflineRouter
local TEN_DAI_TOI_DA = 20

local function dat(truong, giaTri)
	local ok = pcall(function ()
		G_UserLogicDataManager:SetValue(truong, giaTri)
	end)
	return ok
end

local function dongBo()
	pcall(function () OfflineStore:syncFromClient() end)
end

local function loi(ctx, ma, ten)
	OfflineLog:info(string.format("ca nhan %s: tu choi, ma %d", tostring(ten), tonumber(ma) or 1))
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", tonumber(ma) or 1, {})
end

R:on("G_UserLogic.ClientIsUniqueNickName", function (ctx, strNickName)
	if type(strNickName) ~= "string" or strNickName == "" then
		return loi(ctx, 1, "IsUniqueNickName(type)")
	end
	-- [MOI-1] Offline một người chơi: không có bảng tên toàn server ⇒ luôn duy nhất.
	ctx:call("G_UserLogic", "OnIsUniqueNickName", true)
end)

R:on("G_UserLogic.ClientChangeNickName", function (ctx, strNickName)
	if type(strNickName) ~= "string" or strNickName == ""
		or #strNickName > TEN_DAI_TOI_DA then
		return loi(ctx, 1, "ChangeNickName(cong ten)")
	end
	if not dat("CharacterName", strNickName) then
		return loi(ctx, 1, "ChangeNickName(SetValue)")
	end
	dongBo()
	OfflineLog:info("ca nhan: doi ten -> " .. strNickName)
	ctx:call("G_UserLogic", "OnChangeNickName")
end)

R:on("G_UserLogic.ClientChangePortrait", function (ctx, strPortrait)
	if type(strPortrait) ~= "string" or strPortrait == "" then
		return loi(ctx, 1, "ChangePortrait(type)")
	end
	if not dat("Portrait", strPortrait) then
		return loi(ctx, 1, "ChangePortrait(SetValue)")
	end
	dongBo()
	OfflineLog:info("ca nhan: doi anh dai dien -> " .. strPortrait)
	ctx:call("G_UserLogic", "OnChangePortrait")
end)

OfflineLog:info("ca nhan: da noi 3 khoa (IsUniqueNickName / ChangeNickName / ChangePortrait)")

return true
