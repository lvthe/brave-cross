--[[
	offline/chan_doan.lua — CHẨN ĐOÁN TẠM (bật/tắt bằng cờ bên dưới).

	Mục đích: tìm ra AI bật lớp "đang tải" (`g_buyLoadingDialog` /
	`CUISystemDlg` UIName "LoadingDialog") mà không tắt, làm Main đứng im
	(`CUIManager:131` chặn mọi cú bấm khi `IsLoading()`).

	Bật khi có `chan_doan.flag` cạnh file lưu. Ghi:
	  · mỗi lần Show/Hide kèm TRACE NGƯỢC (ai gọi);
	  · mỗi RPC client gửi xuống lớp offline (khoá obj.func);
	  · nhịp tim mỗi giây (nếu nhịp ngừng = Lua kẹt vòng lặp).
]]

require("offline.log")
require("offline.store")

OfflineChanDoan = OfflineChanDoan or {}

local D = OfflineChanDoan

D.TEP_CO = "chan_doan.flag"

local function tb()
	return debug and debug.traceback and debug.traceback("", 2) or "?"
end

local function bat()
	local ok, fp = pcall(function ()
		-- Bóc MỌI tên tệp (file lưu có thể là `offline_save_<uid>.json`).
		return io.open(OfflineStore:path():gsub("[^/]*$", "") .. D.TEP_CO, "r")
	end)
	if ok and fp then fp:close(); return true end
	return false
end

function D:batDau()
	if self.DA_BAT then return end
	if not bat() then return end
	self.DA_BAT = true

	-- 1. bọc lớp đang tải
	pcall(function ()
		if type(g_buyLoadingDialog) ~= "table" then
			OfflineLog:warn("chan doan: KHONG thay g_buyLoadingDialog")
			return
		end
		local Show, Hide = g_buyLoadingDialog.Show, g_buyLoadingDialog.Hide
		g_buyLoadingDialog.Show = function (self2, ...)
			OfflineLog:warn("chan doan: LoadingDialog SHOW\n" .. tb())
			return Show(self2, ...)
		end
		g_buyLoadingDialog.Hide = function (self2, ...)
			OfflineLog:info("chan doan: LoadingDialog HIDE\n" .. tb())
			return Hide(self2, ...)
		end
		OfflineLog:info("chan doan: da boc LoadingDialog Show/Hide")
	end)

	-- 2. mọi RPC client gửi xuống
	pcall(function ()
		local goc = OfflineNet.dispatch
		OfflineNet.dispatch = function (self2, nModule, strObj, strFunc, ...)
			OfflineLog:info(string.format("chan doan: RPC > %s.%s",
				tostring(strObj), tostring(strFunc)))
			return goc(self2, nModule, strObj, strFunc, ...)
		end
		OfflineLog:info("chan doan: da boc OfflineNet:dispatch")
	end)

	-- 3. nhịp tim mỗi giây
	pcall(function ()
		S_CCSchedule:schedule(D, "nhip", 1)
	end)
end

function D:nhip()
	local dang = "?"
	pcall(function ()
		dang = tostring(g_buyLoadingDialog ~= nil and g_buyLoadingDialog:IsLoading())
	end)
	OfflineLog:info("chan doan: nhip loading=" .. dang)
end

OfflineChanDoan:batDau()

return OfflineChanDoan
