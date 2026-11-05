--[[
	offline/handlers/ten_ngau_nhien.lua — SINH TÊN NHÂN VẬT NGẪU NHIÊN.

	Khoá `G_GameWorld|ClientGetRandomName(bGender)` (`ClientGameWorld.lua`,
	`ClientGameWorld:GetRandomName(b)`), nút "Đổi tên khác" ở màn đăng ký/tạo nhân vật
	(`CUILogin`). Trước lượt này KHÔNG có handler ⇒ bấm là KHÔNG có gì xảy ra.

	LUẬT LÀ MÃ GỐC CÒN SỐNG: `CharacterNameLogic:GetName(bGender)`
	(`share/share_CharacterNameLogic.lua:25-59`, thực thể `G_CharacterNameLogic`, `:238`) —
	họ + tên, dùng bảng tên theo giới (`true` = nam, `false` = nữ) lấy từ cấu hình THẬT
	`LocalCharacterNameConfig` (`GetNameConfig`, `:95`).

	Trả lời: client KHÔNG có hàm nhận cho lệnh này — `CUILogin:OnGetRandomName(szName)`
	(`CUILogin2.lua:2355`) đăng ký thẳng SỰ KIỆN `OnGetRandomName` (`:124`). Nên handler phát
	đúng sự kiện ấy với CHUỖI tên. Hàm gửi cũng KHÔNG bật lớp tải ⇒ không có gì để tắt.

	Không tự bịa tên khi cấu hình vắng: `GetName` hỏng thì chỉ ghi log, KHÔNG phát sự kiện —
	thà không đổi tên còn hơn đẩy xuống một cái tên do ta tự chế.
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflineTenNgauNhien = OfflineTenNgauNhien or {}

local R = OfflineRouter
local TEN_FILE = "ten ngau nhien"

R:on("G_GameWorld.ClientGetRandomName", function (ctx, bGender)
	if type(_G.G_CharacterNameLogic) ~= "table" then
		OfflineLog:warn(TEN_FILE .. ": thieu G_CharacterNameLogic — khong sinh ten")
		return
	end

	-- `bGender`: true = nam, false = nữ (đúng như `GetName` mong đợi).
	local gioiTinh = (bGender == true)

	local ok, bRet, szTen = pcall(function ()
		return G_CharacterNameLogic:GetName(gioiTinh)
	end)
	if not ok or bRet ~= true or type(szTen) ~= "string" or szTen == "" then
		OfflineLog:warn(TEN_FILE .. ": GetName khong sinh duoc ten")
		return
	end

	OfflineLog:info(string.format("%s: sinh ten '%s' (%s)", TEN_FILE, szTen,
		gioiTinh and "nam" or "nu"))

	-- Sự kiện mà `CUILogin:OnGetRandomName(szName)` đăng ký nghe.
	pcall(function ()
		G_EventManager:PostLogicEvent(szTen, EventManagerLogicEvent.OnGetRandomName)
	end)
end)

OfflineLog:info("ten ngau nhien: da noi 1 khoa (ClientGetRandomName)")

return true
