--[[
	offline/router.lua — sổ đăng ký handler: tên hàm server -> hàm xử lý cục bộ.

	Server gốc định tuyến thuần theo tên hàm (xem sc/system/rpc.lua), không có
	opcode, nên bảng này khớp 1-1 với cột "Hàm server" trong server-spec-vn.

	Một handler nhận (ctx, ...) với ... đúng các tham số client truyền vào
	CallServer, và trả kết quả bằng ctx:reply{...} — hoặc không trả gì nếu API
	đó vốn không có phản hồi.
]]

require("offline.log")

OfflineRouter = {}
OfflineRouter.handlers = {}     -- ["obj.func" hoặc "func"] = function(ctx, ...)
OfflineRouter.silent = {}       -- các API cố tình bỏ qua, không ghi log thiếu

--[[ Đăng ký handler.

	TÊN CÓ THỂ CÓ TIỀN TỐ OBJ: `"G_CavernLogic.ClientCompeleteFight"`.

	Vì sao cần: RPC của bản gốc khoá theo BỘ BA (module, objName, funcName) —
	`CallLocal(szObjName, szFunName, …)` (`system/rpc.lua:83`) — nên HAI hệ
	khác nhau được dùng CÙNG một tên hàm. Đo 27/10: `ClientCompeleteFight` có ở
	CẢ `ClientCavernLogic.lua:24` (obj `G_CavernLogic`) LẪN
	`ClientEndlessChapterLogic.lua:290` (obj `G_EndlessChapterLogic`), tham số
	khác hẳn nhau. Router cũ khoá trơ tên hàm ⇒ cái đăng ký sau ĐÈ cái trước và
	lượt gọi đi nhầm hàm (log `dang ky de handler: ClientCompeleteFight`).

	Vì vậy: đăng ký được cả `"obj.func"`; lúc điều phối, `net.lua` thử
	`obj .. "." .. func` TRƯỚC rồi mới tới tên trơ (giữ nguyên mọi handler cũ). ]]
function OfflineRouter:on(strFunc, fn)
	if self.handlers[strFunc] then
		OfflineLog:warn("dang ky de handler: " .. strFunc)
	end
	self.handlers[strFunc] = fn
end

-- Đăng ký nhiều handler cùng lúc: OfflineRouter:onAll{ TenHam = fn, ... }
function OfflineRouter:onAll(t)
	for k, v in pairs(t) do
		self:on(k, v)
	end
end

--[[ Đánh dấu các API nuốt lặng lẽ: thống kê, tim đập, báo cáo — không có
	phản hồi và không ảnh hưởng gì tới trạng thái chơi. ]]
function OfflineRouter:ignore(...)
	for _, name in ipairs({...}) do
		self.silent[name] = true
	end
end

function OfflineRouter:has(strFunc)
	return self.handlers[strFunc] ~= nil
end

function OfflineRouter:isSilent(strFunc)
	return self.silent[strFunc] == true
end

function OfflineRouter:get(strFunc)
	return self.handlers[strFunc]
end

--[[ Tra handler theo ĐÚNG bộ ba của bản gốc: (objName, funcName).
	Ưu tiên bản ghi CÓ OBJ; không có thì rơi về tên trơ. ]]
function OfflineRouter:getFor(strObj, strFunc)
	if strObj ~= nil and strObj ~= "" then
		local fn = self.handlers[strObj .. "." .. strFunc]
		if fn ~= nil then
			return fn
		end
	end
	return self.handlers[strFunc]
end

function OfflineRouter:count()
	local n = 0
	for _ in pairs(self.handlers) do n = n + 1 end
	return n
end

return OfflineRouter
