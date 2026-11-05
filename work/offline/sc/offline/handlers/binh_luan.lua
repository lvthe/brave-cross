--[[
	offline/handlers/binh_luan.lua — BÌNH LUẬN GAME (nút "bình luận" trong Tuỳ chọn / Đánh giá).

	Khoá `G_GameCommentLogic|ClientCommentGame` trước đây nằm trong lớp chắn: bản gốc
	mở hộp thoại bình luận CỦA CỬA HÀNG (SDK), nay không còn. Client gửi lệnh **KHÔNG
	ĐỐI SỐ** (`ClientAchieveLogic.lua:963-966`), chỉ bật lớp "đang tải" và không có hàm
	nhận ⇒ lớp offline chỉ cần GHI nhận lên server rồi đóng lớp tải.

	Server: `POST /api/comment` (bảng `comments`). Trang xem sau này đọc `GET /api/comments`.
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflineBinhLuan = OfflineBinhLuan or {}

local R = OfflineRouter
local TEN_FILE = "binh luan"

local function dongLopTai(ctx, nMa)
	pcall(function ()
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", nMa or 0, {})
	end)
end

local function tenNhanVat()
	local ten = ""
	pcall(function ()
		local b, info = G_UserLogic:GetBaseInfo()
		if b == true and type(info) == "table" then
			ten = tostring(info.CharacterName or "")
		end
	end)
	return ten
end

R:on("G_GameCommentLogic.ClientCommentGame", function (ctx)
	local tk = rawget(_G, "OfflineTaiKhoan")
	if tk == nil or tk.uid == nil or type(rawget(_G, "sngHttpRequestWithString")) ~= "function" then
		-- Không có server: vẫn đóng lớp tải, KHÔNG để màn hình đứng.
		OfflineLog:info(TEN_FILE .. ": khong co server — bo qua (khong ghi)")
		dongLopTai(ctx, 0)
		return
	end

	local body = { uid = tonumber(tk.uid), name = tenNhanVat(), content = "" }
	tk:goi("/api/comment", body, function (ok, tl)
		OfflineLog:info(TEN_FILE .. ": " .. (ok and "da ghi" or "that bai")
			.. (ok and (" (id " .. tostring(tl and tl.id) .. ")") or ""))
		dongLopTai(ctx, ok and 0 or 1)
	end)
end)

OfflineLog:info("binh luan: da noi 1 khoa (qua /api/comment)")
