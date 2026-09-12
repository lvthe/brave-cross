--[[
	offline/handlers/mysterious.lua — Cửa hàng bí ẩn: làm mới theo giờ.

	Tại sao cần: lúc hiện Main, ClientMysteriousStoreLogic:OnMainShowUI
	(ClientMysteriousStoreLogic.lua:15) thấy hàng đã quá mốc làm mới (mốc giờ
	9 / 12 / 18 / 21, MysteriousStoreLogic.RefreshHours) thì gọi CallRefresh:
	CallServer ClientRefresh rồi PHÁT OnWaitingForRequest -> CUIMain bật lớp
	"đang tải". Không ai trả thì lớp đó đè cả Main và nuốt mọi cú bấm. Phụ thuộc
	GIỜ nên lúc được lúc không: tools/bam_that.gd bên bravecross-game qua được
	rồi lại vướng khi đồng hồ vượt một mốc (vết gọi: ClientMysteriousStoreLogic
	.lua:56 < CUIMain.lua:317 postOnMainShowEvent).

	Trả gì: client KHÔNG có hàm On... riêng cho ClientRefresh (đặc tả server
	cũng ghi "—" cho cả họ hàm này). Đường phản hồi chung của bản gốc là
	CUIRPCManager:OnReciveResponse(callbackObj, callbackFunc, nErrCode,
	eventList, ...) (CUIRPCManager.lua:166, "收到服务端回调之后跟新数据并通知相应事件"):
	phát OnReceiveResponse — cái tắt lớp "đang tải" — rồi áp eventList (thay đổi
	dữ liệu người chơi) và gọi callbackObj.callbackFunc nếu có. Ta trả đúng
	đường đó với ("", "", 0, {}): không lỗi, không đổi dữ liệu, không gọi gì.
	Rằng server gốc trả ClientRefresh qua đường chung này là SUY từ việc client
	không có đường nào khác.

	CÒN THIẾU, không bịa: luật SINH danh sách hàng mới chỉ server gốc có —
	sc/share/MysteriousStoreLogic.lua chỉ có đọc / ghi / mua / tính mốc giờ.
	Nên offline không làm mới hàng: cửa hàng giữ nguyên danh sách cũ (người chơi
	mới: rỗng). CallRefresh tự chặn gọi lại trong cùng phiên
	(self.LastRefreshMStoreTime, :47), nên không lặp.
]]

require("offline.log")
require("offline.router")

local R = OfflineRouter

R:on("ClientRefresh", function(ctx)
	OfflineLog:warn("ClientRefresh (cua hang bi an): luat sinh hang chi server goc co — khong lam moi")
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", 0, {})
end)

return true
