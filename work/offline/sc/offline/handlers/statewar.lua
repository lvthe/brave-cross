--[[
	offline/handlers/statewar.lua — Quốc chiến (国战): chỉ phần Main hỏi lúc vào.

	Tại sao cần: CUIMain:onEnter (CUIMain.lua:533) gọi
	G_StateWarLogic:GetStateWarTimeInfo -> ClientStateWarBeginTime. Hàm gửi do
	CUIAssist.bindRpcToEvent sinh ra (CUIAssist.lua:350) và nó PHÁT
	OnWaitingForRequest -> CUIMain:OnWaitingForRequest bật lớp "đang tải"
	(g_buyLoadingDialog). Lớp đó chỉ tắt khi hàm nhận On<tên> phát
	OnReceiveResponse (:369). Không ai trả thì lớp "đang tải" nằm đè cả cảnh
	Main và nuốt mọi cú bấm — đo bằng tools/bam_that.gd bên bravecross-game
	(vết gọi: CUIAssist.lua:356 < StateWarLogic.lua:27 < CUIMain.lua:533).

	Trả gì: hàm nhận chuyển nguyên tham số sang StateWarLogic:
	OnGetStateWarTimeInfo(tData) (StateWarLogic.lua:30), hàm này đòi tData[1] là
	số, tData[2] là chuỗi, và CHỈ ghi giờ Quốc chiến khi tData[1] > 0. Offline
	không có máy chủ nên không có Quốc chiến: trả (0, "") — không đặt giờ nào.
	Nghĩa "tData[1] > 0 = đang có lịch" là SUY từ chính chỗ dùng đó; giờ thật
	của server gốc thì không có dữ liệu, không bịa.
]]

require("offline.log")
require("offline.router")

local R = OfflineRouter

R:on("ClientStateWarBeginTime", function(ctx)
	ctx:call("G_StateWarLogic", "OnStateWarBeginTime", 0, "")
end)

return true
