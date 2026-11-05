--[[
	offline/handlers/hop_thu.lua — NHẬN THƯỞNG THƯ (领取附件 / 标记已读).

	Bốn lệnh client gửi (`ClientMailLogic.lua:196/253/284/342`), trước lượt này
	KHÔNG có handler nào ⇒ bấm "nhận" trong Hộp Thư là lớp tải quay mãi.

	   lệnh client                              | luật GỐC (share/MailLogic.lua) | callback trả lời
	   -----------------------------------------|-------------------------------|------------------------------------
	   ClientSaveMailPrizeWithMailID(id)        | saveMailPrizeAndStatus(:645)  | OnServerSaveMailPrizeWithMailID(id, mail)
	   ClientSaveMailPrizeWithMailIdList(list)  | saveMailPrizeList(:739)       | OnServerSaveMailPrizeWithMailIdList(dsĐãLưu)
	   ClientSaveAllMailPrize()                 | saveMailPrizeList(cả bảng)     | OnServerSaveAllMailPrize(mãLỗi)
	   ClientSetMailReadWithMailID(id)          | setMailReadWithMailID(:589)   | OnServerSetMailReadWithMailID(id, mail)

	TẤT CẢ là MÃ GỐC còn sống trong `share/` — handler KHÔNG viết lại luật: nhận
	thưởng đi qua `G_ChapterLogic:SetDataWithPrizeList` (`saveMailPrizeAndStatus`
	`:695`), đánh dấu trạng thái qua `setMailHasRead`/`setMailHasGetPrize`.

	HAI CHỖ PHẢI BIẾT:
	  · `OnServerSaveAllMailPrize(nErrCode)` của client đọc **đối số vị trí 1** là
	    mã lỗi (`ClientMailLogic.lua:300`), KHÔNG phải bảng `{err, data}`.
	  · `saveMailPrizeList` trả `(bResult, tSaveList, nErrCode)` — danh sách THẬT
	    SỰ vừa nhận (chỉ thư CHƯA nhận), và callback List của client nhận đúng
	    danh sách ấy để vẽ lại.

	Gọi qua PROXY LỚP CHA (`o[MailLogic]`) — cùng lối `handlers/tinh_nang.lua`:
	`G_MailLogic` là thể hiện của `ClientMailLogic = class(MailLogic)`.
]]

require("offline.log")
require("offline.store")
require("offline.router")

local R = OfflineRouter

local function lopCha(obj)
	local ten = obj:match("^G_(.+)$")
	if not ten then return nil end
	local c = _G[ten]
	return (type(c) == "table") and c or nil
end

--[[ Gọi hàm LỚP CHA trên `G_MailLogic`; trả NGUYÊN bộ giá trị của bản gốc. ]]
local function goi(ten, ...)
	local o = _G.G_MailLogic
	if type(o) ~= "table" then return false end
	local c = lopCha("G_MailLogic")
	local self = (c and o[c]) or o
	local fn = self and self[ten]
	if type(fn) ~= "function" then return false end
	local args = { n = select("#", ...), ... }
	local ok, a, b, d = xpcall(function ()
		return fn(self, unpack(args, 1, args.n))
	end, function (e)
		return tostring(e) .. (debug and debug.traceback and ("\n" .. tostring(debug.traceback())) or "")
	end)
	if not ok then
		OfflineLog:err("hop thu: " .. ten .. " nem loi: " .. tostring(a))
		return false
	end
	return true, a, b, d
end

local function dongBo()
	pcall(function () OfflineStore:syncFromClient() end)
end

local function loi(ctx, ma, ten)
	ma = tonumber(ma) or 1
	OfflineLog:info(string.format("hop thu %s: luat goc tu choi, ma %d", tostring(ten), ma))
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", ma, {})
end

-- Nhận MỘT thư.
R:on("G_MailLogic.ClientSaveMailPrizeWithMailID", function (ctx, strMailID)
	if type(strMailID) ~= "string" then return loi(ctx, 1, "SaveMailPrizeWithMailID(type)") end
	-- `goi` trả (ok, <giá trị 1 của hàm gốc>, ...) — getMailWithId trả (bResult, mail).
	local ok, bTim, mail = goi("getMailWithId", strMailID)
	if not ok or bTim ~= true or type(mail) ~= "table" then
		return loi(ctx, ErrorCode.Mail.NoMail or 2102, strMailID)
	end
	local ok2, bRet, ma = goi("saveMailPrizeAndStatus", mail)
	dongBo()
	if not ok2 or bRet ~= true then return loi(ctx, ma, strMailID) end
	OfflineLog:info("hop thu: da nhan thu " .. tostring(strMailID))
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse",
		"G_MailLogic", "OnServerSaveMailPrizeWithMailID", 0, {}, strMailID, mail)
end)

-- Nhận MỘT LOẠT thư.
R:on("G_MailLogic.ClientSaveMailPrizeWithMailIdList", function (ctx, tMailIdList)
	if type(tMailIdList) ~= "table" then return loi(ctx, 1, "SaveMailPrizeWithMailIdList(type)") end
	local ds = {}
	for _, id in ipairs(tMailIdList) do
		local ok, bTim, mail = goi("getMailWithId", id)
		if ok and bTim == true and type(mail) == "table" then ds[#ds + 1] = mail end
	end
	local ok, bRet, daLuu, ma = goi("saveMailPrizeList", ds)
	dongBo()
	if not ok or bRet ~= true then return loi(ctx, ma, "SaveMailPrizeWithMailIdList") end
	OfflineLog:info(string.format("hop thu: nhan loat %d thu", #(daLuu or {})))
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse",
		"G_MailLogic", "OnServerSaveMailPrizeWithMailIdList", 0, {}, daLuu or {})
end)

-- Nhận TẤT CẢ (nút "nhận hết").
R:on("G_MailLogic.ClientSaveAllMailPrize", function (ctx)
	local ok, bDS, dsMail = goi("GetMailList")
	if not ok or bDS ~= true or type(dsMail) ~= "table" then
		return loi(ctx, 1, "SaveAllMailPrize(GetMailList)")
	end
	local ok2, bRet, daLuu, ma = goi("saveMailPrizeList", dsMail)
	dongBo()
	if not ok2 or bRet ~= true then return loi(ctx, ma, "SaveAllMailPrize") end
	local n = 0
	if type(daLuu) == "table" then for _ in pairs(daLuu) do n = n + 1 end end
	OfflineLog:info("hop thu: nhan tat ca, " .. n .. " thu moi co thuong")
	-- Callback đọc ĐỐI SỐ VỊ TRÍ 1 là mã lỗi (KHÔNG phải {err,data}).
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse",
		"G_MailLogic", "OnServerSaveAllMailPrize", 0, {}, 0)
end)

-- Đánh dấu ĐÃ ĐỌC.
R:on("G_MailLogic.ClientSetMailReadWithMailID", function (ctx, strMailID)
	if type(strMailID) ~= "string" then return loi(ctx, 1, "SetMailReadWithMailID(type)") end
	local ok, bRet = goi("setMailReadWithMailID", strMailID)
	dongBo()
	if not ok or bRet ~= true then return loi(ctx, 1, strMailID) end
	local _ok, _b, mail = goi("getMailWithId", strMailID)
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse",
		"G_MailLogic", "OnServerSetMailReadWithMailID", 0, {}, strMailID, mail)
end)

return true
