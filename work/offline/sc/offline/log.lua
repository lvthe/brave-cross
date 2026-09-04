--[[
	offline/log.lua — ghi nhật ký cho lớp giả lập server.

	Ghi ra cả console (sngUtil_log, thấy được qua logcat) lẫn một file trong thư
	mục ghi được của game. File log là công cụ làm việc chính: mỗi lời gọi API
	chưa hiện thực đều rơi vào đây kèm tham số thật, nên chỉ cần chơi game là
	có ngay danh sách việc phải làm tiếp, đúng thứ tự game cần.
]]

OfflineLog = {}

OfflineLog.FILE = "offline.log"
OfflineLog.__fp = nil
OfflineLog.enabled = true

local function stamp()
	return os.date("%H:%M:%S")
end

function OfflineLog:path()
	-- LGG_GetSetFilePath tro toi thu muc ghi duoc cua game (noi dat set.xgg)
	if LGG_GetSetFilePath then
		return LGG_GetSetFilePath() .. self.FILE
	end
	return self.FILE
end

function OfflineLog:open()
	if self.__fp or not self.enabled then
		return
	end
	local ok, fp = pcall(io.open, self:path(), "a")
	if ok and fp then
		self.__fp = fp
		fp:write(string.format("\n===== phien moi %s =====\n", os.date("%Y-%m-%d %H:%M:%S")))
		fp:flush()
	end
end

function OfflineLog:write(tag, msg)
	if not self.enabled then
		return
	end
	local line = string.format("[%s] %-8s %s", stamp(), tag, msg)
	if sngUtil_log then
		pcall(sngUtil_log, "OFFLINE " .. line)
	end
	self:open()
	if self.__fp then
		pcall(function()
			self.__fp:write(line, "\n")
			self.__fp:flush()
		end)
	end
end

function OfflineLog:info(msg) self:write("info", msg) end
function OfflineLog:warn(msg) self:write("WARN", msg) end
function OfflineLog:err(msg)  self:write("ERROR", msg) end

--[[ Ghi mot loi goi API chua co handler.
	Day la dong quan trong nhat trong ca file log: no cho biet chinh xac
	game dang can gi ma minh chua lam. ]]
function OfflineLog:missing(nModule, strObj, strFunc, tArgs)
	local ok, json = pcall(cjson.encode, tArgs or {})
	self:write("THIEU", string.format("%s.%s  module=%s  args=%s",
		strObj ~= "" and strObj or "(toan cuc)", strFunc, tostring(nModule),
		ok and json or "<khong encode duoc>"))
end

return OfflineLog
