--[[
	offline/init.lua — điểm vào của lớp giả lập server.

	Được nạp từ cuối sc/user/require.lua (bản đè), tức là sau khi toàn bộ lớp
	client đã định nghĩa xong — cần thế vì ta phải vá vào CUIRPCManager và
	đọc S_CCSchedule.

	Cách nạp: package.path của game ưu tiên external storage rồi download path
	trước assets (sc/game.lua:60), nên chỉ cần đặt file vào đó là đè được, không
	phải đóng gói lại APK.
]]

require("offline.log")
require("offline.store")
require("offline.router")
require("offline.bootstrap")
require("offline.net")

-- các nhóm handler; thêm file mới thì require thêm ở đây
require("offline.handlers.login")

Offline = {}
Offline.VERSION = "0.1"

--[[ Bịt tầng chạm database.

	Bản client để trống hàm này (sc/share/share_CDataManager.lua:207) vì phần
	thân là của server. Trả về bảng rỗng thay vì nil để các đường dẫn gọi
	GetUserDataWithName cho một bảng chưa có không vỡ. ]]
local function patchDataManager()
	if not CDataManager then
		OfflineLog:err("khong tim thay CDataManager — nap sai thu tu?")
		return
	end
	CDataManager.initUserDataFromDB = function(mgr, strModuleName)
		OfflineLog:info("initUserDataFromDB: " .. tostring(strModuleName))
		return 0, {}
	end
end

function Offline:start()
	OfflineLog:info(string.format("khoi dong lop offline v%s", self.VERSION))

	patchDataManager()
	OfflineNet:install()

	OfflineLog:info(string.format(
		"san sang — %d handler, file luu: %s",
		OfflineRouter:count(), OfflineStore:path()))
end

-- Tiện cho việc thử: xoá tiến trình chơi rồi khởi động lại game.
function Offline:wipe()
	OfflineStore:reset()
end

Offline:start()

return Offline
