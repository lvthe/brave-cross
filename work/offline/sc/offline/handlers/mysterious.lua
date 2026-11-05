--[[
	offline/handlers/mysterious.lua — Cửa hàng bí ẩn: làm mới theo giờ + mua hàng.

	Tại sao cần: lúc hiện Main, ClientMysteriousStoreLogic:OnMainShowUI
	(ClientMysteriousStoreLogic.lua:15) thấy hàng đã quá mốc làm mới (mốc giờ
	9 / 12 / 18 / 21, MysteriousStoreLogic.RefreshHours) thì gọi CallRefresh:
	CallServer ClientRefresh rồi PHÁT OnWaitingForRequest -> CUIMain bật lớp
	"đang tải". Không ai trả thì lớp đó đè cả Main và nuốt mọi cú bấm.

	ĐÍNH CHÍNH 28/10 — bản trước ghi "luật SINH danh sách hàng chỉ server gốc
	có, không có bảng cấu hình". SAI. Bảng ấy nằm ngay trong
	`KDBGameCommonConfig` (bảng con, KHÔNG phải một tệp KDB*.json riêng — vì
	thế lần quét theo TÊN TỆP trước đây không thấy):

	  * `GameMStroeGoodsCrateConfig` — 3 cửa hàng (1 / 2 / 3), mỗi cửa là danh
	    sách NHÓM; mỗi nhóm `{Range = <bốc bao nhiêu món>, GoodsList = {...}}`.
	    Nhóm đặc biệt: `IsLevelDepand` (chọn theo `GoodsMap` với `MaxLevel`),
	    `IsNeedMaterial` (chọn theo `GameMaterialIDToMStoreGoodsID`).
	  * `GameSecretShopConfig` — 181 món: `UnitPrice`, `CurrencyType`
	    (1 = vàng, 20 = kim cương), `PrizeID`, `MinGoodsCount`/`MaxGoodsCount`.
	  * `GameMaterialIDToMStoreGoodsID` — 54 dòng: mã vật liệu -> các mã hàng
	    bán chính vật liệu đó (vd 24 "1阶武器卷轴" -> {1, 101}: bản trả vàng và
	    bản trả kim cương; cả hai cùng PrizeID 40001 = vật phẩm 24 x5).

	ĐỌC/GHI/MUA dùng NGUYÊN hàm gốc trong `sc/share/MysteriousStoreLogic.lua`
	(GetUserMysteriousStore, SetMStoreGoodsList, SetMStoreRefreshTime,
	SetMStoreRefreshCount, GetRefreshDiamond, BuyGoods) — client thừa kế cả
	khối máy chủ ấy nên không phải chép lại luật giá / trừ tiền / phát hàng.

	ĐẶT (chỗ duy nhất phải suy, vì hàm sinh hàng của server không được ship):
	  * mỗi nhóm bốc `Range` món KHÔNG LẶP từ nguồn của nó, đều (chưa đối
	    chiếu được trọng số nếu server gốc có);
	  * nhóm `IsLevelDepand` lấy `GoodsMap` có `MaxLevel` NHỎ NHẤT mà >= cấp
	    người chơi (danh sách đã xếp tăng dần 20..90);
	  * nhóm `IsNeedMaterial` ưu tiên các vật liệu người chơi ĐANG CÓ trong túi
	    (tra `GameMaterialIDToMStoreGoodsID`); không có món nào thì lấy đều
	    trong toàn bộ bảng ánh xạ. Tên trường là "cần vật liệu" nên đọc là
	    "món mà người chơi có vật liệu liên quan"; CHƯA đối chiếu được.
	  * `Count` của món = ngẫu nhiên trong [MinGoodsCount, MaxGoodsCount]
	    (đo được: 60/181 món có Min = Max = 3, 24 món 20/20, …).
]]

require("offline.log")
require("offline.store")
require("offline.router")

local R = OfflineRouter

--------------------------------------------------------------- đọc cấu hình

local function cauHinh(ten)
	local ok, v = pcall(function ()
		return G_ConfigManager:GetCommonConfigWithName(ten)
	end)
	if ok and type(v) == "table" then
		return v
	end
	return nil
end

-- Cấu hình giải từ JSON nên khoá là CHUỖI ("1"), còn chỗ gọi lại hay dùng số.
local function theoKhoa(t, k)
	if type(t) ~= "table" then
		return nil
	end
	return t[tostring(k)] or t[k]
end

local function capNguoiChoi()
	local ok, cap = pcall(function ()
		local _, n = G_UserLogic:GetLevel()
		return n
	end)
	if ok and tonumber(cap) then
		return tonumber(cap)
	end
	return 1
end

-- Chọn `n` phần tử KHÔNG LẶP (Fisher-Yates trên bản sao).
local function boclua(ds, n)
	local con = {}
	if type(ds) == "table" then
		for i = 1, #ds do
			con[i] = ds[i]
		end
	end
	for i = #con, 2, -1 do
		local j = math.random(i)
		con[i], con[j] = con[j], con[i]
	end
	local ra = {}
	for i = 1, math.min(n or 1, #con) do
		ra[i] = con[i]
	end
	return ra
end

local function nhomTheoCap(goodsMap, cap)
	if type(goodsMap) ~= "table" then
		return nil
	end
	local chon = nil
	for _, m in ipairs(goodsMap) do
		local maxLevel = tonumber(m.MaxLevel)
		if maxLevel and cap <= maxLevel then
			if chon == nil or maxLevel < tonumber(chon.MaxLevel) then
				chon = m
			end
		end
	end
	return chon or goodsMap[#goodsMap]
end

-- Vật liệu người chơi đang có (ItemCount > 0), theo đúng bảng ánh xạ.
local function hangTheoVatTu(anhXa)
	local co = {}
	local okMap, itemMap = pcall(function ()
		local _, m = G_ItemLogic:GetItemMap()
		return m
	end)
	if okMap and type(itemMap) == "table" then
		for strId, item in pairs(itemMap) do
			local n = tonumber(item and item.ItemCount) or 0
			if n > 0 and anhXa[strId] ~= nil then
				co[strId] = true
			end
		end
	end

	local ra = {}
	for strVatTu in pairs(anhXa) do
		if co[strVatTu] then
			for _, id in ipairs(anhXa[strVatTu]) do
				ra[#ra + 1] = id
			end
		end
	end
	if #ra == 0 then
		for _, ds in pairs(anhXa) do
			for _, id in ipairs(ds) do
				ra[#ra + 1] = id
			end
		end
	end
	return ra
end

------------------------------------------------------------------ sinh hàng

local function sinhMotCua(strIndex)
	local crate = theoKhoa(cauHinh("GameMStroeGoodsCrateConfig"), strIndex)
	if type(crate) ~= "table" then
		return nil
	end

	local secret = cauHinh("GameSecretShopConfig")
	local anhXa = cauHinh("GameMaterialIDToMStoreGoodsID") or {}
	local cap = capNguoiChoi()
	local ds, daCo = {}, {}

	for _, nhom in ipairs(crate) do
		local nguon = nil
		if nhom.IsLevelDepand and nhom.GoodsMap then
			local m = nhomTheoCap(nhom.GoodsMap, cap)
			nguon = m and m.GoodsList
		elseif nhom.IsNeedMaterial then
			nguon = hangTheoVatTu(anhXa)
		elseif nhom.GoodsList then
			nguon = nhom.GoodsList
		end

		if type(nguon) == "table" then
			local canBoc = tonumber(nhom.Range) or 1
			-- Bốc dư rồi lọc trùng: hai nhóm khác nhau có thể cùng một mã hàng.
			local daLay = 0
			for _, id in ipairs(boclua(nguon, canBoc * 3)) do
				if daLay >= canBoc then
					break
				end
				if not daCo[id] then
					local g = theoKhoa(secret, id)
					if g ~= nil then
						local minC = tonumber(g.MinGoodsCount) or 1
						local maxC = tonumber(g.MaxGoodsCount) or minC
						ds[#ds + 1] = {
							ID = tonumber(id),
							Count = maxC > minC and math.random(minC, maxC) or minC,
							State = 0,
						}
						daCo[id] = true
						daLay = daLay + 1
					end
				end
			end
		end
	end

	return ds
end

-- Làm mới những cửa đã mở khoá (MStroe1/2/3 qua VipUnlockConfig).
local function lamMoi(chiSoDinh)
	local soCua = 0
	for idx = 1, 3 do
		if chiSoDinh == nil or tostring(idx) == tostring(chiSoDinh) then
			local okMo, moRoi = pcall(function ()
				local _, b = G_UserLogic:CheckIsVipUnlock("MStroe" .. idx)
				return b
			end)
			if okMo and moRoi then
				local ds = sinhMotCua(idx)
				if ds ~= nil and #ds > 0 then
					G_MysteriousStoreLogic:SetMStoreGoodsList(ds, tostring(idx))
					soCua = soCua + 1
					OfflineLog:info(string.format("cua hang bi an %d: sinh %d mon", idx, #ds))
				else
					OfflineLog:warn(string.format("cua hang bi an %d: khong sinh duoc mon nao", idx))
				end
			end
		end
	end
	return soCua
end

-------------------------------------------------------------------- handler

--[[ Làm mới theo mốc giờ (máy chủ gốc sinh danh sách mới rồi đặt mốc).
	Phản hồi đi đường CHUNG của bản gốc (`CUIRPCManager:OnReciveResponse`,
	`CUIRPCManager.lua:166`): phát OnReceiveResponse — tắt lớp "đang tải" — và
	áp eventList rỗng. Client không có hàm On... riêng cho ClientRefresh. ]]
R:on("G_MysteriousStoreLogic.ClientRefresh", function(ctx)
	local soCua = lamMoi(nil)
	pcall(function ()
		G_MysteriousStoreLogic:SetMStoreRefreshTime(G_GameWorld:GetServerTime())
	end)
	OfflineStore:syncFromClient()
	OfflineLog:info(string.format("cua hang bi an: lam moi %d cua", soCua))
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", 0, {})
end)

--[[ Làm mới MỘT cửa bằng kim cương. Giá lấy đúng hàm gốc
	`MysteriousStoreLogic:GetRefreshDiamond` (10 / 50 / 100 / +50 mỗi lần),
	đếm bằng `RefreshMStoreDailyCountList[strIndex]`. ]]
R:on("G_MysteriousStoreLogic.ClientRefreshWithDiamond", function(ctx, strIndex)
	local nErr = 0
	local okGia, gia = pcall(function ()
		local _, c = G_MysteriousStoreLogic:GetRefreshDiamond(strIndex)
		return c
	end)
	gia = okGia and tonumber(gia) or nil

	if gia == nil then
		nErr = ErrorCode.System.GetConfigFaild
	else
		local okDu, du = pcall(function ()
			local _, n = G_UserLogic:GetDiamond()
			return n
		end)
		if not okDu or (tonumber(du) or 0) < gia then
			nErr = ErrorCode.Resource.NoEnoughResource
		else
			pcall(function ()
				G_UserLogic:CostDiamond(gia, "MStroeRefresh", { Index = strIndex })
			end)
			lamMoi(strIndex)
			pcall(function ()
				local _, u = G_MysteriousStoreLogic:GetUserMysteriousStore()
				local dem = (u and u.RefreshMStoreDailyCountList
					and tonumber(u.RefreshMStoreDailyCountList[strIndex])) or 0
				G_MysteriousStoreLogic:SetMStoreRefreshCount(dem + 1, strIndex)
			end)
			OfflineStore:syncFromClient()
		end
	end

	OfflineLog:info(string.format("lam moi cua hang bi an %s bang kim cuong -> ma %d (gia %s)",
		tostring(strIndex), nErr, tostring(gia)))
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", nErr, {})
end)

--[[ Mua hàng: gọi NGUYÊN `MysteriousStoreLogic:BuyGoods` (kiểm mở khoá, kiểm
	còn hàng, kiểm đủ tiền theo `GetGoodsUnitPrice` + `IsHalfPrice`, trừ tiền,
	phát thưởng bằng `ReceivePrizeWithID`, đặt `State = 1`, phát logic event
	`MStore.OnBuyGoods` cho UI vẽ lại). Ta chỉ nhận mã lỗi và tắt lớp tải. ]]
R:on("G_MysteriousStoreLogic.ClientBuyGoods", function(ctx, strIndex, nGoodsIndex)
	local nErr = 0
	local ok, bRet, maLoi = pcall(function ()
		return G_MysteriousStoreLogic:BuyGoods(strIndex, nGoodsIndex)
	end)

	if not ok then
		OfflineLog:warn("ClientBuyGoods loi: " .. tostring(bRet))
		nErr = ErrorCode.MStore.GetUserMStoreFaild
	elseif bRet ~= true then
		nErr = tonumber(maLoi) or ErrorCode.MStore.NoIncludeGoods
	end

	OfflineLog:info(string.format("mua hang bi an cua %s mon %s -> ma %d",
		tostring(strIndex), tostring(nGoodsIndex), nErr))
	if nErr == 0 then
		OfflineStore:syncFromClient()
	end
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", nErr, {})
end)

return true
