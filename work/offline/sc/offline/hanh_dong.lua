--[[
	offline/hanh_dong.lua — NHẬT KÝ HÀNH ĐỘNG (ghi về server, không bao giờ chặn game).

	Chủ dự án chốt hướng cho nhóm hoạt động "do máy chủ vận hành": MỖI LƯỢT DÙNG
	đều ghi log, sau này dựng một trang xem chung với trang nạp tiền. Server:
	bảng `user_events` + `POST /api/event` · `GET /api/events` (xem
	`bravecross-server/src/http_api.ts`).

	RÀNG BUỘC:
	  · KHÔNG có tài khoản / KHÔNG có `sngHttpRequestWithString` ⇒ im lặng trả false.
	  · Chống spam: mỗi `kind` tối đa một lượt mỗi `GIAN_CACH` giây.
	  · Mọi lỗi HTTP đều bị nuốt — ghi log KHÔNG được làm hỏng lượt chơi.
]]

require("offline.log")

OfflineHanhDong = OfflineHanhDong or {}

local M = OfflineHanhDong

M.GIAN_CACH = 2
M.daGui = {}

--[[ Ghi một hành động. `value` phải là bảng (sẽ bị thay bằng {} nếu không phải). ]]
function M:ghi(kind, key, value)
	local k = tostring(kind or "")
	if k == "" then return false end

	local tk = rawget(_G, "OfflineTaiKhoan")
	if tk == nil or tk.uid == nil then return false end
	if type(rawget(_G, "sngHttpRequestWithString")) ~= "function" then return false end

	local now = os.time()
	local lanTruoc = self.daGui[k]
	if lanTruoc ~= nil and (now - lanTruoc) < self.GIAN_CACH then
		return false
	end
	self.daGui[k] = now

	local body = {
		uid = tonumber(tk.uid),
		kind = k,
		key = tostring(key or ""),
		value = (type(value) == "table") and value or {},
	}
	local ok = pcall(function ()
		tk:goi("/api/event", body, function () end)   -- không cần phản hồi
	end)
	return ok
end

--[[ Cho bộ thử / lượt sau đặt lại bộ đếm chống spam. ]]
function M:datLai()
	self.daGui = {}
end

if OfflineLog ~= nil then
	OfflineLog:info("hanh dong: da noi nhat ky (POST /api/event)")
end

return M
