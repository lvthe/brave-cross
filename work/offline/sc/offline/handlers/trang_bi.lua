--[[
	offline/handlers/trang_bi.lua — trang bị: rèn (chế tạo).

	Vì sao cần: kịch bản hướng dẫn tân thủ bắt buộc phải rèn một món cho Lăng
	Thống (`CGuideScheme.lua:3782` — `coroutine.yield("OnSynthesisEquipmentFinish")`).
	Không trả `ClientSynthesisEquipment` thì nút Rèn quay mãi và màn hình khoá
	tương tác.

	Đường làm ĐÚNG là đường bản gốc đã có sẵn: `ClientEquipmentLogic.lua:240-284`
	giữ nguyên bản gốc dưới dạng chú thích —

	    bResult, nErrCode = self[EquipmentLogic]:SynthesisEquipment(heroID, partID)
	    bResult, tEquipment = self:GetEquipment(heroID, partID)
	    self:updateEquipData(tEquipment)
	    logicData.HeroID / EquipPartID / EquipLevel
	    G_EventManager:PostLogicEvent(logicData, EventManagerLogicEvent.OnSynthesisEquipment)

	tức lớp cha `EquipmentLogic` (share/share_EquipmentLogic.lua:899) tự lo liệu
	liệu có đủ nguyên liệu/vàng không, nâng cấp bậc, cập nhật dữ liệu. Ta chỉ gọi
	nó rồi phát đúng sự kiện mà UI đang chờ (`CUIEquipment.lua:245`).
]]

require("offline.log")
require("offline.store")
require("offline.router")

local R = OfflineRouter

local function lopCha()
	if EquipmentLogic == nil or G_EquipmentLogic == nil then
		return nil
	end
	return G_EquipmentLogic[EquipmentLogic]
end

R:on("ClientSynthesisEquipment", function(ctx, nHeroID, nEquipPartID)
	local goc = lopCha()
	if goc == nil then
		OfflineLog:err("ClientSynthesisEquipment: khong lay duoc lop cha EquipmentLogic")
		return
	end

	local ok, nErr = goc:SynthesisEquipment(nHeroID, nEquipPartID)
	if not ok then
		OfflineLog:warn(string.format(
			"ClientSynthesisEquipment %s/%s: luat goc tu choi, ma %s",
			tostring(nHeroID), tostring(nEquipPartID), tostring(nErr)))
		return
	end

	local _, tEquip = goc:GetEquipment(nHeroID, nEquipPartID)
	local nCap = (tEquip ~= nil) and tEquip.EquipLevel or 0
	OfflineLog:info(string.format("ren xong: tuong %s, o %s -> cap %s",
		tostring(nHeroID), tostring(nEquipPartID), tostring(nCap)))

	OfflineStore:syncFromClient()

	-- Phản hồi cho tầng logic (mở lại khoá gửi, chấm đỏ) ...
	ctx:call("G_EquipmentLogic", "OnServerSynthesisEquipment", nHeroID, nEquipPartID, {})
	-- ... rồi phát đúng sự kiện UI đang chờ để chạy hoạt ảnh rèn.
	if G_EventManager ~= nil and EventManagerLogicEvent ~= nil then
		G_EventManager:PostLogicEvent({
			HeroID = nHeroID,
			EquipPartID = nEquipPartID,
			EquipLevel = nCap,
		}, EventManagerLogicEvent.OnSynthesisEquipment)
	end
end)

return true
