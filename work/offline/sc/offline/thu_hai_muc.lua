--[[
	offline/thu_hai_muc.lua — ĐỒ THỬ: mở hai panel vừa làm rồi gọi đúng đường
	RPC của chúng, để đo trên máy thật mà không phải bấm màn hình.

	Vì sao cần đồ thử riêng: hai lối vào này bị KHOÁ THEO CẤP/TÀI KHOẢN trên
	tài khoản thử (Lv6, VIP0), nên bấm UI không tới được:
	  * Cửa hàng bí ẩn (`btnMainMysteryShop`) — `CGameFuncOpeningManager` gác
	    `CUIMysteryShop` ở **Lv18** (`CGameFuncOpeningManager.lua:444`), dù
	    `VipUnlockConfig.MStroe1 = 0`.
	  * Hộp hồn (`onTouchEnd_OnOpenSoulBox`, `CUIMainTopTool.lua:1536`) — nút chỉ
	    hiện khi có hoạt động `TimeLimitSoulBoxHero`; offline không có hoạt động.

	Mở panel bằng ĐÚNG hàm client dùng (như cách mở Túi — xem BAY-UI mục 9),
	KHÔNG dò toạ độ. Mọi bước đều ghi `offline.log`.

	Tắt/bật bằng `OfflineThuHaiMuc.TAT` (true = tắt). Đang BẬT để đo lượt
	28/10 — đo xong nhớ trả về `true`.
]]

require("offline.log")
require("offline.store")

OfflineThuHaiMuc = OfflineThuHaiMuc or {}

-- ĐÃ ĐO XONG 28/10 (kết quả: GHI-CHU-TRACE-2026-10-26.md §23) ⇒ TẮT.
OfflineThuHaiMuc.TAT = true
OfflineThuHaiMuc.CHO_SCENE = 10     -- nhịp chờ cảnh Main dựng xong
-- CẤP KIM CƯƠNG để quay hộp hồn thật (giá `SoulBoxCost = 250`). Chỉ là DỮ
-- LIỆU THỬ cho file lưu dev — không phải đường của game. Đặt false để chỉ đo
-- nhánh "không đủ kim cương".
OfflineThuHaiMuc.CAP_KIM_CUONG = true

OfflineThuHaiMuc.DEM = 0
OfflineThuHaiMuc.BUOC = 0

local function tenCanh()
	if g_CSceneManager == nil then return nil end
	local ok, v = pcall(function () return g_CSceneManager:GetCurrentSceneName() end)
	return ok and v or nil
end

local function demHang()
	local ok, u = pcall(function ()
		local _, t = G_MysteriousStoreLogic:GetUserMysteriousStore()
		return t
	end)
	if not ok or type(u) ~= "table" or type(u.MStoreGoodsListMap) ~= "table" then
		return nil
	end
	local ds = u.MStoreGoodsListMap["1"]
	if type(ds) ~= "table" then return 0 end
	return #ds
end

-- Món đầu tiên trả VÀNG và còn đủ tiền (CurrencyType 1 = Gold).
function OfflineThuHaiMuc:chonMonVang()
	local ds, secret = nil, nil
	pcall(function ()
		local _, u = G_MysteriousStoreLogic:GetUserMysteriousStore()
		ds = u and u.MStoreGoodsListMap and u.MStoreGoodsListMap["1"]
		secret = G_ConfigManager:GetCommonConfigWithName("GameSecretShopConfig")
	end)
	if type(ds) ~= "table" or type(secret) ~= "table" then
		return nil
	end
	local vang = 0
	pcall(function ()
		local _, g = G_UserLogic:GetGold()
		vang = tonumber(g) or 0
	end)
	for i, mon in ipairs(ds) do
		local g = secret[tostring(mon.ID)]
		if type(g) == "table" and tonumber(g.CurrencyType) == 1
			and (tonumber(g.UnitPrice) or 0) <= vang then
			return i
		end
	end
	return nil
end

function OfflineThuHaiMuc:tick()
	if self.TAT or self.XONG then return end
	if tenCanh() ~= "Main" then return end

	self.DEM = self.DEM + 1
	if self.DEM < self.CHO_SCENE then return end

	self.BUOC = self.BUOC + 1
	local buoc = self.BUOC

	if buoc == 1 then
		OfflineLog:info(string.format("thu: cua hang bi an co %s mon trong danh sach",
			tostring(demHang())))
		self.monVang = self:chonMonVang()
		OfflineLog:info("thu: chon mon mua = " .. tostring(self.monVang))
		local ok, err = pcall(function ()
			g_CUINormalDlg:Show(g_CUIMysteriousStore:GetUIName())
		end)
		OfflineLog:info("thu: mo panel cua hang bi an -> " .. tostring(ok) .. " " .. tostring(err))
	elseif buoc == 3 then
		-- Hộp thoại "bán vài thứ cho tiệm" của cửa hàng bí ẩn: OK gọi BatchUseItem.
		local truoc = "?"
		pcall(function ()
			local _, g = G_UserLogic:GetGold()
			truoc = tostring(g)
		end)
		local ok, err = pcall(function () G_ItemLogic:BatchUseItem() end)
		OfflineLog:info(string.format("thu: BatchUseItem -> %s %s (vang truoc %s)",
			tostring(ok), tostring(err), truoc))
	elseif buoc == 6 then
		-- Mua món TRẢ VÀNG bằng đúng đường UI dùng (CallBuyGoods) — món trả kim
		-- cương sẽ trả 1702 vì tài khoản thử chỉ có ít kim cương.
		local truoc = nil
		pcall(function ()
			local _, g = G_UserLogic:GetGold()
			truoc = tonumber(g)
		end)
		local ok, err = pcall(function ()
			G_MysteriousStoreLogic:CallBuyGoods("1", self.monVang or 1)
		end)
		OfflineLog:info(string.format("thu: CallBuyGoods(1,%s) -> %s %s (vang truoc %s)",
			tostring(self.monVang), tostring(ok), tostring(err), tostring(truoc)))
	elseif buoc == 12 then
		pcall(function () g_CUINormalDlg:Close() end)
		local ok, err = pcall(function ()
			g_CUINormalDlg:Show(g_CUISoulBox:GetUIName())
		end)
		OfflineLog:info("thu: mo panel hop hon -> " .. tostring(ok) .. " " .. tostring(err))
	elseif buoc == 18 then
		local d = nil
		pcall(function ()
			local c = g_CUISoulBox and g_CUISoulBox.SoulBoxFragmentConfigMap
			if type(c) == "table" then
				d = string.format("tuan=%s ngay=%s", tostring((c.WeekHeroIDList or {})[1]),
					tostring((c.DayHeroIDList or {})[1]))
			end
		end)
		OfflineLog:info("thu: hop hon nhan duoc " .. tostring(d))

		if self.CAP_KIM_CUONG then
			pcall(function () G_UserLogic:AddDiamond(250, "thu-nghiem") end)
		end
		pcall(function () OfflineStore:syncFromClient() end)

		local ok, err = pcall(function ()
			G_LotteryLogic:PlaySoulBox(false)
		end)
		OfflineLog:info("thu: PlaySoulBox -> " .. tostring(ok) .. " " .. tostring(err))
	elseif buoc == 24 then
		local kim = "?"
		pcall(function ()
			local _, n = G_UserLogic:GetDiamond()
			kim = tostring(n)
		end)
		OfflineLog:info("thu: xong — kim cuong con " .. kim)
		pcall(function () g_CUINormalDlg:Close() end)
		self.XONG = true
	end
end

function OfflineThuHaiMuc:batDau()
	if self.TAT then
		return
	end
	if S_CCSchedule == nil then
		OfflineLog:err("thu_hai_muc: khong thay S_CCSchedule")
		return
	end
	local ok, err = pcall(function () S_CCSchedule:schedule(self, "tick", 1) end)
	if ok then
		OfflineLog:info("thu_hai_muc: da hen gio (1 s/nhip)")
	else
		OfflineLog:err("thu_hai_muc: hen gio loi: " .. tostring(err))
	end
end

return OfflineThuHaiMuc
