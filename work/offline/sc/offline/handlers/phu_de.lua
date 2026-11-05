--[[
	offline/handlers/phu_de.lua — PHỤ ĐỀ (弹幕) THEO TỪNG ẢI.

	Hai khoá `G_SubtitleLogic` (`ClientSubtitleLogic`, thực thể `G_SubtitleLogic`):

	  · `ClientSetUserCopySubtitle(copyKey, subtitle, time, color)` (`ClientSubtitleLogic.lua:14-17`)
	  · `ClientGetCopySubtitle(copyKey)`                            (`:20-25`)

	Bên gọi: `CUISubtitleInputDialog:onTouchEnd_onClickOk` (`:106-120`) khi người chơi gửi một
	dòng phụ đề trong ải. Trước lượt này KHÔNG có handler ⇒ mở khung phụ đề là lớp tải quay mãi.

	GỬI thì client KHÔNG chờ phản hồi (không bật `OnWaitingForRequest`) — nó đã tự hiện dòng
	của mình qua `Subtitle.OnSendSubtitle` (`:112-113`). Nên handler chỉ VIỆC LƯU.

	ĐỌC: `OnGetGetCopySubtitle(nErrCode, copyKey, mySubtitles, friendSubtitles, RandomSubtitles)`
	(`:28-108`) — **năm tham số VỊ TRÍ**. Mỗi dòng là bảng (hoặc chuỗi JSON) có
	`Subtitle / Time / Color`; chính hàm ấy đặt `isMySelf = true`, sắp xếp theo `Time`, rồi tự
	chèn thêm phụ đề cấu hình ải + toàn cục. Offline một người ⇒ hai danh sách bạn bè và ngẫu
	nhiên để RỖNG (không có ai để có), còn dòng của mình trả nguyên.

	GHI Ở ĐÂU: `G_UserLogic:Get/SetClientCommonData("OfflineCopySubtitles")` — cùng chỗ với
	dữ liệu client khác (đi vào file lưu). [MOI] một chỗ: mỗi ải giữ tối đa `SO_TOI_DA = 100`
	dòng, cũ quá thì bỏ dòng CŨ NHẤT — chặn file lưu phình vô hạn; con số này là quyết định của
	lớp offline, không phải dữ liệu gốc.
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflinePhuDe = OfflinePhuDe or {}

local R = OfflineRouter
local TEN_FILE = "phu de"
local KHOA = "OfflineCopySubtitles"
local SO_TOI_DA = 100

local function doc()
	local ok, v = pcall(function ()
		local _, x = G_UserLogic:GetClientCommonData(KHOA)
		return x
	end)
	if ok and type(v) == "table" then
		return v
	end
	return {}
end

local function ghi(t)
	local ok, bRet = pcall(function ()
		return G_UserLogic:SetClientCommonData(KHOA, t)
	end)
	if not ok or bRet ~= true then
		OfflineLog:err(TEN_FILE .. ": khong ghi duoc du lieu phu de")
	end
end

R:on("G_SubtitleLogic.ClientSetUserCopySubtitle", function (ctx, copyKey, subtitle, time, color)
	if copyKey == nil or type(subtitle) ~= "string" or subtitle == "" then
		OfflineLog:warn(TEN_FILE .. ": tham so sai khi gui")
		return                      -- hàm gửi KHÔNG chờ phản hồi; nuốt lặng là đủ
	end

	local k = tostring(copyKey)
	local all = doc()
	local ds = all[k]
	if type(ds) ~= "table" then
		ds = {}
		all[k] = ds
	end
	ds[#ds + 1] = {
		Subtitle = subtitle,
		Time = tonumber(time) or 0,
		Color = color,
	}
	while #ds > SO_TOI_DA do
		table.remove(ds, 1)
	end
	ghi(all)
	pcall(function () OfflineStore:syncFromClient() end)

	OfflineLog:info(string.format("%s: ai '%s' nhan 1 dong (tong %d)", TEN_FILE, k, #ds))
end)

R:on("G_SubtitleLogic.ClientGetCopySubtitle", function (ctx, copyKey)
	local k = tostring(copyKey or "")
	local all = doc()
	local ds = all[k]
	if type(ds) ~= "table" then
		ds = {}
	end
	OfflineLog:info(string.format("%s: ai '%s' tra %d dong cua minh", TEN_FILE, k, #ds))

	-- Năm tham số VỊ TRÍ: err, copyKey, của mình, bạn bè (rỗng), ngẫu nhiên (rỗng).
	ctx:call("G_SubtitleLogic", "OnGetGetCopySubtitle", 0, copyKey, ds, {}, {})
end)

OfflineLog:info("phu de: da noi 2 khoa (ClientSetUserCopySubtitle / ClientGetCopySubtitle)")

return true
