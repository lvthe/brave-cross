--[[
	offline/handlers/toan_cuc_con.lua — NĂM KHOÁ TOÀN CỤC CÒN SỐNG.

	`_phan_loai_toancuc.py` (bỏ chú thích đúng cấp) chia 38 khoá objName RỖNG thành
	**6 SỐNG · 25 CHẾT · 7 TRONG CHÚ THÍCH**. Ba khoá "sống" còn lại
	(`ClientChapterHJRQComplete`, `ClientChapterSCSComplete`, `ClientGetChapterDropData`)
	đã có handler theo obj ở `handlers/ai_dac_biet.lua` — lời gọi obj RỖNG của chúng
	nằm trong đường mạng CŨ `CServerRequestLogic` (0 chỗ gọi).

	Năm khoá dưới đây là những lời gọi THẬT còn lại:

	  `ClientGetSpeechContent(nSpeechId)` — `ClientChattingLogic.lua:118`.
	     Không có bảng nội dung thoại nào trong cấu hình ship ⇒ trả mã GỐC
	     `ErrorCode.Chat.SpeechNotExists = 3902` qua `G_ChattingLogic:OnGetSpeechContent`.
	  `ClientCheckNewEquipment(nEquipId)` — `CUIEquipmentList.lua:164`; KHÔNG có hàm
	     nhận nào (server chỉ đánh dấu "đã xem") và client không chờ ⇒ nuốt lặng,
	     ghi log `info`.
	  `ClientSetArenaHero(heroIdList)` — `ClientArenalLogic.lua:146` (obj `G_ArenaLogic`)
	     ĐỒNG THỜI bản obj RỖNG trong `CServerRequestLogic` (chết). Lưu danh sách vào
	     client common data `OfflineArenaHero` [MOI] rồi gọi hàm nhận THẬT
	     `OnSetArenaHero(heroIdList)`; hàm ấy KHÔNG dừng lớp tải ⇒ phải dọn tay.
	  `ClientBindingAccount(...)` — `ClientLogin.lua:45` (obj `G_Login`). Offline KHÔNG
	     có hệ tài khoản (SDK đã chết, đăng nhập do hook Frida giả) và trong Lua
	     KHÔNG có hàm nhận nào ⇒ nuốt lặng có ghi lý do.
	  `ClientReturnHome()` — `CUIChapterList.lua:894` (obj RỖNG). Đường cũ đáp bằng
	     hàm toàn cục `OnReturnHome(tData)` (`CServerResponseLogic.lua:179-196`);
	     ta trả `{err=0, data={}}` để màn chọn ải đóng và về Main như hàm ấy làm.

	KHÔNG làm 25 khoá CHẾT: hàm bao quanh không ai gọi (toàn bộ nhánh
	`CServerRequestLogic` của đường mạng cũ) — đăng ký chỉ tổ che mất lỗi thật.
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflineToanCucCon = OfflineToanCucCon or {}

local R = OfflineRouter
local TEN_FILE = "toan cuc (con song)"
local KHOA_ARENA = "OfflineArenaHero"

local function goi(ctx, strObj, hamNhan, ...)
	local a = { n = select("#", ...), ... }
	local ok, e = pcall(function ()
		return ctx:call(strObj, hamNhan, unpack(a, 1, a.n))
	end)
	if not ok then
		OfflineLog:err(string.format("%s: khong goi duoc %s.%s -> %s", TEN_FILE,
			tostring(strObj), tostring(hamNhan), tostring(e)))
	end
end

local function donLop(ctx)
	pcall(function ()
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", 0, {})
	end)
end

local function ma(ten, macDinh)
	local ok, v = pcall(function ()
		local E = _G.ErrorCode
		return E and E.Chat and E.Chat[ten]
	end)
	return (ok and tonumber(v)) or macDinh
end

------------------------------------------------------------------- 1. NỘI DUNG THOẠI
--[[ Không có bảng nội dung thoại trong cấu hình ship; trả ĐÚNG mã "không có" của
	bản gốc. `OnGetSpeechContent(errCode, Speech)` tự ghi lỗi rồi phát sự kiện. ]]
R:on("ClientGetSpeechContent", function (ctx, nSpeechId)
	local m = ma("SpeechNotExists", 3902)
	OfflineLog:info(string.format("%s: thoai %s -> ma %d (khong co du lieu thoai)",
		TEN_FILE, tostring(nSpeechId), m))
	goi(ctx, "G_ChattingLogic", "OnGetSpeechContent", m, nil)
end)

------------------------------------------------------------------- 2. ĐÁNH DẤU ĐÃ XEM TRANG BỊ
--[[ Client KHÔNG chờ phản hồi và KHÔNG có hàm nhận (chỉ server đánh dấu "đã xem").
	Nuốt lặng — nhưng vẫn phải có handler để `THIEU` không kêu mỗi lần bấm. ]]
R:on("ClientCheckNewEquipment", function (ctx, nEquipId)
	OfflineLog:info(string.format("%s: da xem trang bi %s (khong co phan hoi)",
		TEN_FILE, tostring(nEquipId)))
end)

------------------------------------------------------------------- 3. ĐỘI HÌNH ĐẤU TRƯỜNG
R:on("G_ArenaLogic.ClientSetArenaHero", function (ctx, heroIdList)
	local ds = {}
	if type(heroIdList) == "table" then
		for _, id in ipairs(heroIdList) do
			local n = tonumber(id)
			if n ~= nil then ds[#ds + 1] = n end
		end
	end
	pcall(function ()
		local bRet = G_UserLogic:SetClientCommonData(KHOA_ARENA, ds)
		if bRet ~= true then
			OfflineLog:warn(TEN_FILE .. ": khong luu duoc doi hinh dau truong")
		end
	end)
	pcall(function () OfflineStore:syncFromClient() end)
	OfflineLog:info(string.format("%s: doi hinh dau truong -> %d tuong", TEN_FILE, #ds))
	goi(ctx, "G_ArenaLogic", "OnSetArenaHero", ds)
	donLop(ctx)
end)

-- Bản obj RỖNG của đường mạng CŨ (`CServerRequestLogic:399`) — cùng một việc.
R:on("ClientSetArenaHero", function (ctx, heroIdList)
	local h = R:getFor("G_ArenaLogic", "ClientSetArenaHero")
	if h ~= nil then return h(ctx, heroIdList) end
end)

------------------------------------------------------------------- 4. LIÊN KẾT TÀI KHOẢN
--[[ Offline KHÔNG có hệ tài khoản và Lua KHÔNG có hàm nhận ⇒ nuốt lặng, ghi lý do
	một dòng để không ai tưởng đã liên kết thành công. ]]
local function khongLienKet(ctx)
	OfflineLog:info(TEN_FILE .. ": ClientBindingAccount — offline khong co he tai khoan,"
		.. " bo qua (khong bao thanh cong)")
end

R:on("G_Login.ClientBindingAccount", khongLienKet)
R:on("ClientBindingAccount", khongLienKet)

------------------------------------------------------------------- 5. VỀ NHÀ
--[[ Đường cũ đáp bằng hàm TOÀN CỤC `OnReturnHome(tData)` — nó `ResetChannelData`
	rồi `RepaleceScene("Main")`. Truyền `{err=0, data={}}`. ]]
R:on("ClientReturnHome", function (ctx)
	OfflineLog:info(TEN_FILE .. ": ve nha tu man chon ai")
	goi(ctx, "", "OnReturnHome", { err = 0, data = {} })
end)

OfflineLog:info("toan cuc (con song): da noi 5 khoa (thoai/trang bi/doi hinh dau truong/lien ket/ve nha)")

return true
