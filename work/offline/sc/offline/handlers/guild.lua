--[[
	offline/handlers/guild.lua — bang hội (quân đoàn).

	ĐỌC TRƯỚC KHI THÊM: bang hội là tính năng NHIỀU NGƯỜI CHƠI. Offline chỉ có
	một người và không có kho bang hội nào, nên câu trả lời trung thực cho mọi
	câu hỏi "bang này thế nào" là **chưa có bang** — không phải dựng một cái
	bang giả cho màn hình đỡ trống.

	Đường đi, đọc từ mã client:

	  CUIGuildControl:onInit
	    -> G_GuildLogic:GetGuildData()            (bảng GameUserGuildData)
	    -> G_GuildLogic:GetGuildInfo(0, 0, GuildId, true)
	       -> CallServer "ClientGetGuildInfo"(PageNo, PageSize, GuildId)
	  ta trả G_GuildLogic:OnGetGuildInfo(nErrCode, tGuildInfo)
	       (ClientGuildManageLogic.lua:283)

	`GuildId ~= 0` là phép thử "có bang hay không" mà chính client dùng
	(CUIGuildDispatch.lua:109, CUIGuildWar.lua:405), nên người chơi mới có
	GuildId = 0 và ta trả mã GuildNotExist (3501) của chính bản gốc.

	CHƯA LÀM, và nói rõ vì sao: tạo bang, xin vào, quyên góp, chiến bang, phó
	bản bang — tất cả đều cần NGƯỜI CHƠI KHÁC hoặc một kho bang hội dùng chung.
	Dựng chúng offline thì phải bịa ra cả một danh sách bang và thành viên, tức
	bịa số. Nếu sau này có máy chủ thật thì phần đó thuộc về máy chủ.
]]

require("offline.log")
require("offline.router")

local R = OfflineRouter

--[[ Thông tin một bang. Người chơi offline không ở bang nào, và cũng không có
	bang nào khác để tra — trả đúng mã "bang không tồn tại" của bản gốc.

	Client xử mã này bằng cách bắn CUINotificationEvent.OnServerRequestError
	rồi thoát êm (ClientGuildManageLogic.lua:288), không chết. ]]
R:on("ClientGetGuildInfo", function(ctx, nPageNo, nPageSize, nGuildId)
	local nErr = (ErrorCode and ErrorCode.Guild and ErrorCode.Guild.GuildNotExist)
		or 3501
	ctx:call("G_GuildLogic", "OnGetGuildInfo", nErr, {})
end)
