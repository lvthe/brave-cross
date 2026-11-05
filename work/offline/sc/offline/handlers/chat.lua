--[[
	offline/handlers/chat.lua — GỬI CHAT + LỆNH NẠP GIẢ LẬP QUA CHAT.

	Lệnh `ClientNotifyMessage` (module **CHAT_FRIEND**, objName RỖNG — `api.lua:207`),
	`tMessage = {Type, Content, ChannelId, Param}` (`CUIChatting.lua:1040-1047`).
	Callback PHƯƠNG THỨC `G_ChattingLogic.OnNotifyMessage(errCode, SpeechId)`;
	`SpeechId` phải là SỐ (`ClientChattingLogic.lua:105-111` bỏ nếu không phải số).

	Trước lượt này lệnh ấy KHÔNG có handler ⇒ gửi chat rơi vào nhánh "sinh" (danh sách
	rỗng) và không phản hồi. Offline MỘT người chơi không có ai để phát sóng, nên
	handler chỉ trả lời thành công (`errCode = 0`, `SpeechId = 0`).

	ĐƯỜNG KÍCH HOẠT DỄ HƠN GM CONSOLE — gõ vào ô chat thế giới:
	    nap 100            giả lập nạp 100 (kim cương = 100)
	    nap 100 500        giả lập nạp 100, cộng 500 kim cương
	    dangxuat           (hoặc doitk) lưu kho rồi về màn đăng nhập để ĐỔI TÀI KHOẢN
	    doimk <cũ> <mới>   đổi mật khẩu tài khoản đang đăng nhập (server phải chạy)

	⚠ Lệnh `doimk` có mật khẩu nằm trong câu chat, mà client TỰ đưa câu vừa gõ vào
	khung chat của mình (`CUIChatting.lua:1020-1036`) — mật khẩu hiện trên màn. Đây là
	máy dev LAN (chat không phát sóng, không lưu vào file lưu), nhưng đừng dùng mật
	khẩu thật ở đây.
	Câu lệnh được xử lý bởi `OfflineNap:cong` (`offline/nap_gia_lap.lua` — đã khai
	[MOI] ở đó), và KHÔNG phát sóng; client vẫn tự đưa câu vừa gõ vào khung chat của
	mình (`CUIChatting.lua:1020-1036`, trước khi gọi server), nên người chơi thấy nó.

	[GHIM] Định dạng lệnh là của ta; bản gốc không có lệnh chat kiểu này.
]]

require("offline.log")
require("offline.store")
require("offline.router")
require("offline.nap_gia_lap")

local R = OfflineRouter

local function traLoi(ctx, ma, speechId)
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse",
		"G_ChattingLogic", "OnNotifyMessage", ma or 0, {}, ma or 0, speechId or 0)
end

-- `nap <tien> [<kimcuong>]` — chấp nhận cả tiền tố "/".
local function docLenhNap(str)
	local s = tostring(str):lower():gsub("^%s+", "")
	s = s:gsub("^/", "")
	local a, b = s:match("^nap%s+(%d+)%s*(%d*)")
	if a == nil then return nil end
	a = tonumber(a)
	b = (b ~= "" and tonumber(b)) or nil
	if a == nil or a <= 0 then return nil end
	return a, b
end

-- `dangxuat` / `doitk` / `doitaikhoan` — về màn đăng nhập (đổi tài khoản).
-- Chấp nhận tiền tố "/", khoảng trắng hai đầu, và KHÔNG phân biệt hoa/thường.
local function laLenhDangXuat(str)
	local s = tostring(str):lower():gsub("^%s+", ""):gsub("^/", ""):gsub("%s+$", "")
	return s == "dangxuat" or s == "doitk" or s == "doitaikhoan"
end

-- `doimk <matkhaucu> <matkhaumoi>` / `doimatkhau ...` — đổi mật khẩu tài khoản đang
-- đăng nhập. Đúng BA mẩu cách nhau khoảng trắng (mật khẩu không chứa khoảng trắng).
-- Trả `(cu, moi)` hoặc `nil`.
local function docLenhDoiMatKhau(str)
	local s = tostring(str):gsub("^%s+", ""):gsub("^/", "")
	local dau, cu, moi = s:match("^(%S+)%s+(%S+)%s+(%S+)%s*$")
	if dau == nil then return nil end
	dau = dau:lower()
	if dau ~= "doimk" and dau ~= "doimatkhau" then return nil end
	return cu, moi
end

R:on("ClientNotifyMessage", function (ctx, tMessage)
	if type(tMessage) ~= "table" then return traLoi(ctx, 1) end
	local noiDung = tMessage.Content
	if type(noiDung) == "string" then
		if laLenhDangXuat(noiDung) then
			-- Dùng `rawget` chứ không `require`: lớp `tai_khoan` đã do `init.lua`
			-- nạp, và bộ thử PC cố ý KHÔNG nạp nó (thiếu `sngHttpRequestWithString`).
			local tk = rawget(_G, "OfflineTaiKhoan")
			if tk ~= nil and type(tk.dangXuat) == "function" then
				local ok, ly = tk:dangXuat()
				OfflineLog:info("chat: lenh dang xuat -> " .. tostring(ok) .. " " .. tostring(ly))
			else
				OfflineLog:warn("chat: lenh dang xuat nhung khong co OfflineTaiKhoan")
			end
			return traLoi(ctx, 0)
		end
		local cuMk, moiMk = docLenhDoiMatKhau(noiDung)
		if cuMk ~= nil then
			local tk = rawget(_G, "OfflineTaiKhoan")
			if tk == nil or type(tk.doiMatKhau) ~= "function" or type(tk.bamMD5) ~= "function" then
				OfflineLog:warn("chat: doimk nhung ban nay khong co OfflineTaiKhoan.doiMatKhau")
			elseif tk.email == nil then
				OfflineLog:warn("chat: doimk nhung chua dang nhap tai khoan nao")
			else
				local hCu, lyCu = tk:bamMD5(cuMk)
				local hMoi, lyMoi = tk:bamMD5(moiMk)
				if hCu == nil or hMoi == nil then
					-- Băm hỏng thì KHÔNG gửi: gửi mật khẩu thô sẽ thành "sai mật khẩu".
					OfflineLog:warn("chat: doimk khong bam duoc MD5 — " .. tostring(lyCu or lyMoi))
				else
					OfflineLog:info("chat: doimk — gui /api/password cho " .. tostring(tk.email))
					tk:doiMatKhau(hCu, hMoi, function (ok, res)
						OfflineLog:info(string.format("chat: doimk -> ok=%s code=%s %s",
							tostring(ok), tostring(res and res.code), tostring(res and res.error)))
					end)
				end
			end
			return traLoi(ctx, 0)
		end
		local tien, kc = docLenhNap(noiDung)
		if tien ~= nil then
			local ok, ly = OfflineNap:cong(tien, kc)
			if ok then
				OfflineLog:info(string.format("chat: lenh nap %s (kc %s) -> da nap gia lap",
					tostring(tien), tostring(kc or tien)))
			else
				OfflineLog:warn("chat: lenh nap hong — " .. tostring(ly))
			end
			return traLoi(ctx, 0)
		end
	end
	-- Chat thường: offline một người, không có ai để phát sóng.
	return traLoi(ctx, 0)
end)

OfflineLog:info("chat: da noi ClientNotifyMessage (lenh 'nap <tien> [<kc>]')")

--[[ KÊNH CHAT — bốn lệnh còn lại của cùng module `CHAT_FRIEND` (`api.lua:204-210`).
	Không lệnh nào có handler trước lượt này ⇒ mở khung chat là `CallEnterChannel`
	rơi vào nhánh "sinh" (trả danh sách RỖNG, KHÔNG gọi callback) ⇒ kênh không có
	lịch sử, và ô nhập có thể chưa sẵn. Offline một người chơi: lịch sử RỖNG là
	SỰ THẬT; ta chỉ trả lời ĐÚNG HÌNH DẠNG để cửa sổ chat mở được.

	Hình dạng đo từ `ClientChattingLogic.lua:21-64`:
	  · `OnEnterChatGame(errCode)`;
	  · `OnEnterChannel(errCode, nChannelId, tMsgData, tListFriendInfo)` — kênh **4**
	    (Person) đòi `tListFriendInfo` là BẢNG, các kênh khác đòi `tMsgData` là BẢNG;
	  · `OnExitChannel(errCode)`;
	  · `OnGetFriendChatRecord(errCode, tListMsgRecord)`;
	  · `ClientReadFriendMessage` có `cb=''` (im lặng — không trả lời). ]]
R:on("ClientEnterChatGame", function (ctx)
	ctx:call("G_ChattingLogic", "OnEnterChatGame", 0)
end)

R:on("ClientEnterChannel", function (ctx, _nGuildId, nChannelId)
	local cid = tonumber(nChannelId) or 1
	ctx:call("G_ChattingLogic", "OnEnterChannel", 0, cid, {}, {})
end)

R:on("ClientExitChannel", function (ctx, _nChannelId)
	ctx:call("G_ChattingLogic", "OnExitChannel", 0)
end)

R:on("ClientGetFriendChatRecord", function (ctx, _nTargetUid)
	ctx:call("G_ChattingLogic", "OnGetFriendChatRecord", 0, {})
end)

-- `cb=''` — im lặng, nhưng vẫn đăng ký để lệnh không rơi vào nhánh "sinh".
R:on("ClientReadFriendMessage", function (_ctx, _nTargetUid)
end)

return true
