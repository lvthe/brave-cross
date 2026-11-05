--[[
	offline/nap_api.lua — NHẬN KHOẢN NẠP TỪ API (thay SDK thanh toán đã chết).

	VÌ SAO: `ClientDealPayment` bị chú thích ở CẢ HAI chỗ và `apisdk.kul.vn` không còn
	⇒ trong game không có đường mua thật. Nay khoản nạp do một API ngoài tạo
	(`POST /api/recharge` của server riêng), rồi MỖI LẦN VÀO GAME lớp offline "kéo"
	`POST /api/recharge/claim` — server đánh dấu `claimed` trong CÙNG transaction nên
	không cộng hai lần.

	CỘNG KIM CƯƠNG bằng `OfflineNap:cong(kc, kc)`: đi đúng đường của lệnh GM `nap`
	(nạp giả lập) — cập nhật luôn mốc nạp đầu tiên / nạp liên tục / quà tân thủ, để
	các hệ đọc số nạp thấy khoản này. `[MOI]` coi 1 KC = 1 đơn vị tiền nạp; API chỉ
	biết số kim cương, không có số tiền thật.

	Chỉ hỏi MỘT lần mỗi phiên (`daHoi`), và im lặng khi không có server.
]]

require("offline.log")
require("offline.store")

OfflineNapApi = OfflineNapApi or {}

local M = OfflineNapApi

M.daHoi = false

function M:kiem()
	if self.daHoi then return end

	local tk = rawget(_G, "OfflineTaiKhoan")
	if tk == nil or tk.uid == nil then return end
	if type(rawget(_G, "sngHttpRequestWithString")) ~= "function" then return end
	local nap = rawget(_G, "OfflineNap")
	if type(nap) ~= "table" then return end

	self.daHoi = true

	tk:goi("/api/recharge/claim", { uid = tonumber(tk.uid) }, function (ok, tl)
		if not ok then
			OfflineLog:warn("nap api: khong lay duoc lenh nap")
			return
		end
		local nKC = tonumber(tl.kc) or 0
		if nKC <= 0 then return end

		local okCong, err = nap:cong(nKC, nKC)
		if okCong then
			pcall(function () OfflineStore:syncFromClient() end)
			OfflineLog:info(string.format("nap api: +%d KC (%s lenh)", nKC, tostring(tl.count)))
			pcall(function ()
				if OfflineHanhDong ~= nil then
					OfflineHanhDong:ghi("recharge", "claim", { kc = nKC, count = tonumber(tl.count) or 0 })
				end
			end)
			pcall(function ()
				g_CUIToolTips:AddTipsWithString(string.format("Nạp thành công: +%d kim cương", nKC))
			end)
		else
			OfflineLog:warn("nap api: cong that bai — " .. tostring(err))
		end
	end)
end

return M
