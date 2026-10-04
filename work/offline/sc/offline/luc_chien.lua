--[[
	offline/luc_chien.lua — máy chủ giả điền "lực chiến" cho từng tướng.

	HAI trường này là số của MÁY CHỦ, không phải của client. Đo trên bản gốc:

	  * `sc/share/share_HeroLogic.lua:113` có sẵn dòng bị chú thích

	        --self:RefreshHeroFightingCapacity(tHero)--不去刷新战力，由服务端刷新后下发

	    — "không tự tính lại lực chiến, máy chủ tính rồi gửi xuống". Mọi chỗ gọi
	    `RefreshHeroFightingCapacity` còn lại (:807, :1316, :1354, :1549, cộng
	    DestinyLogic :153/:374/:485 và UserLogic :1411/:1510) đều nằm SAU một
	    hành động của người chơi; không chỗ nào chạy lúc vào game.
	  * `RefreshHeroAllFightCapacity` (`sc/share/HeroCapacityLogic.lua:296`) —
	    hàm DUY NHẤT ghi `AllFightCapacity` — không có một chỗ gọi nào trong cả
	    973 tệp. Nên trường ấy cũng chỉ có thể đến từ máy chủ.

	Thiếu cả hai thì KHÔNG có một dòng lỗi nào: bảng `<bảng>Reset` của cấu hình
	ghi sẵn số 0, và `GetHeroAllFightCapacityWithHero` (:63) thấy
	`AllFightCapacity` KHÁC nil nên không lùi về `FightCapacity`. Triệu chứng
	duy nhất là mọi màn hiện "Lực 0" — đo trên màn dàn trận chiến dịch
	(`CUIBattleDeploy`, nhãn `ttfTotalFightCapacity`, CUIBattleDeploy.lua:2592)
	với 3 tướng đã vào đội: nhãn ra `0`.

	SỐ do CHÍNH MÃ GỐC tính, không phải công thức chép lại:

	    FightCapacity    <- G_HeroLogic:CalcHeroFightCapatity(tướng)
	    AllFightCapacity <- G_HeroLogic:CalHeroAllFightCapacityWithHero(tướng)
	                        (= số trên + trang bị + cánh + thần binh + hồn sao)

	Phải điền CẢ HAI — đo lúc chạy trên chính màn ấy: điền `FightCapacity`
	(1369,7) mà để `AllFightCapacity` = 0 thì nhãn VẪN ra `0`; điền cả hai thì
	ra `1369`.

	ĐIỀN LÚC NÀO cũng là chuyện phải ĐO, không phải chuyện suy: xem
	`OfflineLucChien:noi_su_kien` ở cuối tệp — gọi thẳng ngay sau `ctx:call` là
	chạy trước khi khối dữ liệu vào tới client.
]]

require("offline.log")

OfflineLucChien = {}

--[[ Điền lực chiến cho MỌI bản ghi tướng đang có.

	Gọi được nhiều lần: lần thứ hai ra đúng số cũ, nên không cần theo dõi "đã
	điền chưa" — và vì thế cũng không có trạng thái nào để lệch với file lưu.

	Trả về số bản ghi điền được, hoặc nil khi môi trường chưa đủ. Bộ test trên
	PC (`test/mock.lua`) KHÔNG có `G_HeroLogic`: ở đó hàm này phải im lặng thoát
	chứ không được làm đứt chuỗi vào game mà test đang chạy. ]]
function OfflineLucChien:bo_sung()
	if not G_HeroLogic then
		OfflineLog:warn("luc chien: khong co G_HeroLogic — bo qua")
		return nil
	end

	-- GetHeroMap (share_HeroLogic.lua:157) tự gọi fillHeroData cho bản ghi nào
	-- chưa nạp, nên tới đây mọi bản ghi đã có HeroInfo để mà tính.
	local bRetCode, heroMap = G_HeroLogic:GetHeroMap()
	if bRetCode ~= true or type(heroMap) ~= "table" then
		OfflineLog:err("luc chien: GetHeroMap khong tra ve bang")
		return nil
	end

	local nTong = 0
	local nDien = 0
	for _, tHero in pairs(heroMap) do
		nTong = nTong + 1
		-- Tướng không có cấu hình thì fillHeroData đã hỏng và cả hai hàm trả
		-- nil: bỏ qua bản ghi ấy, KHÔNG ghi nil đè lên số đang có.
		local _, nFight = G_HeroLogic:CalcHeroFightCapatity(tHero)
		if nFight ~= nil then
			tHero.FightCapacity = nFight
			local _, nAll = G_HeroLogic:CalHeroAllFightCapacityWithHero(tHero)
			tHero.AllFightCapacity = nAll
			nDien = nDien + 1
		end
	end

	OfflineLog:info(string.format("luc chien: dien %d/%d tuong", nDien, nTong))
	return nDien
end

--[[ Nối vào sự kiện `OnEnterGame` của CHÍNH CLIENT, thay vì gọi thẳng từ
	`offline/handlers/login.lua`.

	VÌ SAO — đo được, không phải đoán. `login.lua` trả khối dữ liệu bằng
	`ctx:call`, mà `ctx:call` chỉ ĐẨY vào hàng đợi:

	    function Ctx:call(strObj, strFunc, ...)
	        OfflineNet:push(strObj, strFunc, packv(...))        -- net.lua:116
	    end

	Hàng đợi ấy chỉ chạy ở `OfflineNet:tick()` (net.lua:235) — tức KHUNG HÌNH
	SAU. Nên gọi `bo_sung()` ngay dòng dưới `ctx:call` là chạy TRƯỚC khi
	`G_DataManager:Init` (`ClientGameWorld.lua:166`) được gọi; lúc ấy bản đồ
	tướng còn rỗng và lượt điền không có gì để điền. Đo trong `offline.log`
	của một lượt vào game sạch:

	    vao game (nguoi choi moi), 36 bang du lieu
	    initUserDataFromDB: GameUserHero          <- GetHeroMap hoi luc userData con rong
	    luc chien: dien 0/0 tuong                 <- dien KHONG duoc gi

	Hệ quả ĐO ĐƯỢC: nhãn `Lực` trên màn dàn trận vẫn ra `0` cho tới khi có một
	đường khác tình cờ gọi lại (đường CHIÊU MỘ — `handlers/lottery.lua` — gọi
	`bo_sung` sau khi dữ liệu đã nạp, nên trước đây chỉ những bản lưu có quay
	tướng mới hiện đúng số).

	`ClientGameWorld:OnServerEnterGame` POST `EventManagerLogicEvent.OnEnterGame`
	ở DÒNG CUỐI (`ClientGameWorld.lua:98`), sau `initData` -> `G_DataManager:Init`
	(:166) — tức sự kiện ấy rơi ĐÚNG lúc khối dữ liệu đã nằm trong tay client.
	Đăng ký theo nó thì không phải sửa `net.lua` và không phải đoán số khung. ]]
function OfflineLucChien:noi_su_kien()
	if not G_EventManager then
		OfflineLog:err("luc chien: khong co G_EventManager — khong noi duoc su kien")
		return false
	end
	G_EventManager:Reg(self, self.OnEnterGame, EventManagerType.Logic,
		EventManagerLogicEvent.OnEnterGame)
	return true
end

--[[ Sự kiện mang mã lỗi của `EnterGame` làm tham số đầu (`EventManagerBase:Post`
	truyền `tData` xuống handler): chỉ điền khi vào game THÀNH CÔNG. ]]
function OfflineLucChien:OnEnterGame(nErrCode)
	if nErrCode ~= 0 then
		OfflineLog:warn("luc chien: EnterGame loi " .. tostring(nErrCode) .. " — bo qua")
		return nil
	end
	return self:bo_sung()
end

return true
