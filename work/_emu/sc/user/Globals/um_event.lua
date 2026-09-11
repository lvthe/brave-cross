--[[
	Date:		2014-06-24
	Company: 	Kingsoft
	Author: 	zhouzhifeng
	Purpose: 	友盟事件
--]]

require("user.Globals.xg_analytics")

UMEventConfig = {}
UMEventConfig.HeroName = {
	HeroID_1 = "少女孙尚香",
	HeroID_2 = "凌统",
	HeroID_3 = "徐庶",
	HeroID_4 = "庞德",
	HeroID_5 = "曹植",
	HeroID_6 = "黄月英",
	HeroID_7 = "陆逊",
	HeroID_8 = "马岱",
	HeroID_9 = "于禁",
	HeroID_10 = "姜维",
	HeroID_11 = "小乔",
	HeroID_12 = "孙策",
	HeroID_13 = "赵云",
	HeroID_14 = "刘备",
	HeroID_15 = "关羽",
	HeroID_16 = "张飞",
	HeroID_17 = "公孙瓒",
	HeroID_18 = "破军",
	HeroID_19 = "周瑜",
	HeroID_20 = "张角",
	HeroID_21 = "魔化张角",
	HeroID_22 = "觉醒少女孙尚香",
	HeroID_23 = "吕布",
	HeroID_24 = "蔡文姬",
	HeroID_25 = "主角",
	HeroID_26 = "马云禄",
	HeroID_27 = "太史慈",
	HeroID_28 = "孙鲁班",
	HeroID_29 = "徐晃",
	HeroID_30 = "周仓",
	HeroID_31 = "顾雍",
	HeroID_32 = "关平",
	HeroID_33 = "刘表",
	HeroID_34 = "马良",
	HeroID_35 = "曹操",
	HeroID_36 = "辛宪英",
	HeroID_37 = "法正",
	HeroID_38 = "潘凤",
	HeroID_39 = "马谡",
	HeroID_40 = "鲁肃",
	HeroID_41 = "曹彰",
	HeroID_42 = "颜良文丑",
	HeroID_43 = "袁绍",
	HeroID_44 = "袁术",
	HeroID_45 = "孙坚",
	HeroID_46 = "貂蝉",
	HeroID_47 = "华雄",
	HeroID_48 = "董卓",
	HeroID_49 = "贾诩",
	HeroID_50 = "周泰",
	HeroID_51 = "郭嘉",
	HeroID_52 = "诸葛亮",
	HeroID_53 = "夏侯渊",
	HeroID_54 = "马超",
	HeroID_55 = "魏延",
	HeroID_56 = "孙尚香",
	HeroID_57 = "大乔",
	HeroID_58 = "甘宁",
	HeroID_59 = "甄宓",
	HeroID_60 = "步练师",
	HeroID_61 = "祝融",
	HeroID_62 = "庞统",
	HeroID_63 = "司马懿",
	HeroID_64 = "许褚",
	HeroID_65 = "庞德",
	HeroID_66 = "张辽",
	HeroID_67 = "张纮",
	HeroID_68 = "张昭",
	HeroID_69 = "黄忠",
	HeroID_70 = "乐进",
	HeroID_71 = "夏侯惇",
	HeroID_72 = "荀彧",
	HeroID_73 = "曹丕",
	HeroID_74 = "魔化董卓",
	HeroID_75 = "少年诸葛亮",
	HeroID_76 = "典韦",
	HeroID_77 = "邓艾",
	--...
	-- 新增英雄需手动添加
}

UMEventConfig.GetHeroName = function (nID)
	local szName = string.format("HeroID_%d", nID)
	szName = UMEventConfig.HeroName[szName] or szName
	return szName
end
	
	
UMEventConfig.ArmyName = {
	ArmyID_1 = "刀盾兵",
	ArmyID_2 = "长矛兵",
	ArmyID_3 = "弓箭兵",
	ArmyID_4 = "骑兵",
	ArmyID_5 = "魔法兵",
	ArmyID_6 = "重甲兵",
	ArmyID_7 = "舞姬",
	ArmyID_8 = "南蛮象兵",
	ArmyID_9 = "铁炮兵",
	ArmyID_10 = "投石车",
	ArmyID_11 = "盾师",	
}

UMEventConfig.GetArmyName = function (nID)
	local szName = "ArmyID_"..nID
	szName = UMEventConfig.ArmyName[szName] or szName
	return szName
end	



UMEvent = {}
UMEvent.m_bOpen 		= true;		--暂时关闭了
UMEvent.m_bFirstStart 	= true; 	--是否第一次启动
UMEvent.tUMQQType = {
	Guest = 0,
	QQ = 1,
	WX = 2
}


--[[
	@brief	友盟初始化
	@param
	@return
--]]
function UMEvent:Init()
	
	ZQEvent:Init()
	
	self:SetIsOpen(true);	--设置启动
	self:RegInit();			--注册事件
	
	--检查是否第一次启动	
	if g_SetGame ~= nil then
		local bUMFirstStart = g_SetGame:GetString("umFirstStartFlg");
		if bUMFirstStart ~= nil and bUMFirstStart == "false" then
			self.m_bFirstStart = false;
		end
	end
			
	--统计启动
	self:StartGame();
end


--[[
	@brief	是否为首次启动
	@param
	@return
--]]
function UMEvent:GetIsFirstStart()
	return self.m_bFirstStart;
end


function UMEvent:SetIsFirstStart()
	g_SetGame:SetString("umFirstStartFlg", "false")
	self.m_bFirstStart = false
end

--[[
	@brief	获取事件名
	@param
	@return
--]]
function UMEvent:GetEventName(strEventName)
	if self:GetIsFirstStart() == true then
		return strEventName.."_first";
	end						
	return strEventName;
end


--[[
	@brief	设置是否开始友盟统计
--]]
function UMEvent:SetIsOpen(bOpen)
	self.m_bOpen = bOpen;
end

--[[
	@brief	获取当前是否开始了友盟统计
--]]
function UMEvent:GetIsOpen()
	return self.m_bOpen;
end	

--新手引导
UMEvent.m_dwGuidIndex = -1;
function UMEvent:FuncSetGuideIndex(dwNewIndex)
	
	if KDebug.ProcessIsNil(dwNewIndex) then
		return 
		--goto Exit0
	end
	
	if self.m_dwGuidIndex ~= dwNewIndex and self.m_dwGuidIndex ~= -1 then
		--结束		
		local strLevel = "guide"..self.m_dwGuidIndex;
		
		if self:GetIsOpen() then
			ProtocolAnalytics_shared():finishLevel(strLevel);
		end
		
		ZQEvent:RoleTask(strLevel, "新手引导" .. self.m_dwGuidIndex, "complete")
		
	end		

	--重新开始下一个
	local strLevel = "guide"..dwNewIndex;
	
	if self:GetIsOpen() then
		ProtocolAnalytics_shared():startLevel(strLevel)	
	end
	
	ZQEvent:RoleTask(strLevel, "新手引导" .. dwNewIndex, "accept")

	XGAnalytics:logEvent(XGAnalytics.EVENT_ID.NOVICESTORY + self.m_dwGuidIndex, "noviceStory_"..tostring(self.m_dwGuidIndex))

	self.m_dwGuidIndex = dwNewIndex;
	
end


-- 登录事件
function UMEvent:Login(nMode)
	
	if not self:GetIsOpen() then
		return;
	end
		
	-- 用户模式登录
	if nMode == USER_GLOBAL.LOGINMODE.ACCOUNT then	
		ProtocolAnalytics_shared():logEvent("umUserLogin", 
			--{umUserLogin="accountLogin"}
			{umUserLogin="账号登录"}
			);
	elseif nMode == USER_GLOBAL.LOGINMODE.QUICK then
	-- 游客模式登录	
		ProtocolAnalytics_shared():logEvent("umUserLogin", 
			--{umUserLogin="quickLogin"}
			{umUserLogin="游客登录"}
			);
	else
	-- 有问题的登录
		KDebug.ProcessError(false)
	end		
	
end

-- 绑定事件
function UMEvent:BindAccount()
	
	ZQEvent:RoleAct("BindAccount", "绑定账号", "End")
	
	if not self:GetIsOpen() then
		return;
	end
	
	-- 绑定用户
	ProtocolAnalytics_shared():logEvent("umBindAccount")	
end

--进入关卡
function UMEvent:StartLevel(strChapterID)
	
	ZQEvent:RoleStage(strChapterID, strChapterID, "begin")
	
	if not self:GetIsOpen() then
		return;
	end
	
	ProtocolAnalytics_shared():startLevel(strChapterID);
end

--关卡胜利
function UMEvent:FinishLevel(strChapterID)
	
	ZQEvent:RoleStage(strChapterID, strChapterID, "End")
	
	if not self:GetIsOpen() then
		return;
	end
	
	ProtocolAnalytics_shared():finishLevel(strChapterID);	
end

--关卡失败
function UMEvent:FailLevel(strChapterID)
	
	ZQEvent:RoleStage(strChapterID, strChapterID, "Fail")
	
	if not self:GetIsOpen() then
		return;
	end
	
	ProtocolAnalytics_shared():failLevel(strChapterID);	
end	

function UMEvent:RegInit()

	if not self:GetIsOpen() then
		return;
	end
	
	--监听ui显示
	G_EventManager:Reg(
		self, 
		self.funcUiShow, 
		EventManagerType.UI, 
		EventManagerUIEvent.OnDialogShow);
	--监听ui关闭
	G_EventManager:Reg(
		self, 
		self.funcUiHide, 
		EventManagerType.UI, 
		EventManagerUIEvent.OnDialogHide);		
	--英雄解锁
	G_EventManager:Reg(
		self, 	
		self.funcHeroUnLock, 
		EventManagerType.Data,  
		EventManagerTableName.GameUserHero, 
		"IsLock");
	--英雄出战
	G_EventManager:Reg(
		self, 	
		self.funcHeroFight, 
		EventManagerType.Data,  
		EventManagerTableName.GameUserHero,
		"IsFighting");
	--英雄提品
	G_EventManager:Reg(
		self, 	
		self.funcHeroQuality, 
		EventManagerType.Data,  
		EventManagerTableName.GameUserHero,
		"HeroQuality");
	--英雄升星
	G_EventManager:Reg(
		self, 	
		self.funcHeroGrowthFactor, 
		EventManagerType.Data,  
		EventManagerTableName.GameUserHero,
		"HeroGrowthFactor");
	--士兵升级
	G_EventManager:Reg(
		self, 	
		self.funcArmyLevelUp, 
		EventManagerType.Data,  
		EventManagerTableName.GameUserArmyType,
		"ArmyLevel");
	--兵营升级
	G_EventManager:Reg(
		self, 	
		self.funcBarracksLevelUp, 		
		EventManagerType.Data,  
		EventManagerTableName.GameUserBaseInfo,
		"BarracksLevel");
	--药水升级
	G_EventManager:Reg(
		self, 	
		self.funcPotionLevel, 		
		EventManagerType.Data,  
		EventManagerTableName.GameUserPotion,
		"PotionLevel");	
	--翰岭院等级
	G_EventManager:Reg(
		self, 	
		self.funcPotionResearchLevel, 		
		EventManagerType.Data,  
		EventManagerTableName.GameUserBaseInfo,
		"ResearchLevel");	
	--药水解锁
	G_EventManager:Reg(
		self, 	
		self.funcPotionUnLock, 		
		EventManagerType.Data,  
		EventManagerTableName.GameUserPotion,
		"IsLock");	
	--制作药水
	G_EventManager:Reg(
		self, 	
		self.funcPotionCount, 		
		EventManagerType.Data,  
		EventManagerTableName.GameUserPotion,
		"PotionCount");	
	--装备等级
	G_EventManager:Reg(
		self, 	
		self.funcEquipLevel, 		
		EventManagerType.Data,  
		EventManagerTableName.GameUserEquipment,
		"EquipLevel");	
	--强化等级
	G_EventManager:Reg(
		self, 	
		self.funcIntensifyLevel, 		
		EventManagerType.Data,  
		EventManagerTableName.GameUserEquipment, 
		"IntensifyLevel");		
	--提品
	G_EventManager:Reg(
		self, 		
		self.funcQuality, 		
		EventManagerType.Data,  
		EventManagerTableName.GameUserEquipment,
		"Quality");
		
	--金币消耗
	G_EventManager:Reg(
		self, 		
		self.funcCostGold, 		
		EventManagerType.Logic,  		
		EventManagerLogicEvent.OnCostGold);		
	--钻石消耗		
	G_EventManager:Reg(
		self, 		
		self.funcCostDiamond, 		
		EventManagerType.Logic,  		
		EventManagerLogicEvent.OnCostDiamond);		
				
	--英雄升级
	G_EventManager:Reg(
		self, 
		self.funcHeroLevelUp,
		EventManagerType.Data,
		"GameUserBaseInfo",
		"Level"	);			
		
end

--[[以下为内部函数，用户不需要调用--]]

function UMEvent:funcHeroLevelUp(tHeroData)
		
	--sngUtil_log("UMEvent:funcHeroLevelUp"..tHeroData.Level);
	--if tHeroData.UserHeroID == 25 then 
		ProtocolAnalytics_shared():logEvent("umHeroLevelUp", {curLevel=tHeroData.Level});		
	--end

	if tHeroData.Level == 5 then 
		ADJEvent:logLevel5()
	elseif tHeroData.Level == 10 then 
		ADJEvent:logLevel10()
	end

	if SDK_Mgr.nUserType == UserType.Xgsdk then
		ProtocolUser_shared():levelup({
			accountID=USER_GLOBAL.COMMON_INFO.ACCOUNT_ID,
			roleID=USER_GLOBAL.COMMON_INFO.ROLE_ID,
			roleName=USER_GLOBAL.COMMON_INFO.ROLE_NAME,
			roleLevel=tHeroData.Level,
			serverID=USER_GLOBAL.COMMON_INFO.SERVER_ID,
			--serverID="1",
			serverName=USER_GLOBAL.COMMON_INFO.SERVER_NAME,
			other=""}
		)
	end

	ZQEvent:RoleAct("UserLevelUp", "主角等级到达" ..tHeroData.Level .. "级" , "UserLevelUp")
	
end


UMEvent.tBuyGoodsText = {
	[EventManagerLogicEvent.Arenal.OnRefreshFightTime] = "刷新竞技场挑战时间消耗",
	[EventManagerLogicEvent.Arenal.OnAddArenaFightCount] = "增加竞技场挑战次数消耗",
	[EventManagerLogicEvent.Cavern.OnCavernRevive] = "魔窟复活主角消耗",
	[EventManagerLogicEvent.FortuneWheel.OnVipRoll] = "高级转盘消耗",
	[EventManagerLogicEvent.MStore.OnBuyGoods] = "神秘商店消耗",
	[EventManagerLogicEvent.Potion.OnCompletePotionUpgradeWithDiamond] = "秒升药水消耗",
	["buyTimeHero"] = "限时神将消耗",
	["buyFatigue"] = "购买体力消耗",
	["ResetBattleCount"] = "重置关卡进入次数消耗",
	["changeDiamondToSweepCount"] = "购买扫荡次数消耗",
	[EventManagerLogicEvent.Equipment.OnRecastEquipment] = "洗练装备消耗",
	["runMidasTouchWithCount"] = "点金手消耗",
	[EventManagerLogicEvent.Lottery.OnDiamondLottery] = "扭蛋消耗",
	[EventManagerLogicEvent.MStore.OnRefreshWithDiamond] = "刷新神秘商店商品消耗",
	
	[EventManagerLogicEvent.Potion.OnUpgradeResearch] = "升级研究所消耗",
	[EventManagerLogicEvent.Potion.OnUpgradePotion] = "升级药水消耗",
	[EventManagerLogicEvent.Potion.OnBuyPotion] = "购买药水消耗",
	[EventManagerLogicEvent.OnIntensifyEquipment] = "强化装备消耗",
	[EventManagerLogicEvent.Lottery.OnGoldLottery] = "扭蛋消耗",
}

-- new 	 CostDiamond
UMEvent.tCostDiamondName = {

	[EventManagerLogicEvent.Arenal.OnRefreshFightTime] = "refresh_arena_CD",
	[EventManagerLogicEvent.Arenal.OnAddArenaFightCount] = "add_arena_count",
	[EventManagerLogicEvent.Cavern.OnCavernRevive] = "cavern_revive",
	[EventManagerLogicEvent.FortuneWheel.OnVipRoll] = "vip_roll",
	[EventManagerLogicEvent.MStore.OnBuyGoods] = "buy_goods",
	[EventManagerLogicEvent.Potion.OnCompletePotionUpgradeWithDiamond] = "complete_potion_upgrade",
	["buyTimeHero"] = "buy_time_limit_hero",
	["buyFatigue"] = "buy_fatigue", 
	["ResetBattleCount"] = "reset_battle_count",
	["changeDiamondToSweepCount"] = "buy_sweep_count",
	[EventManagerLogicEvent.Equipment.OnRecastEquipment] = "recast_equipment",
	["runMidasTouchWithCount"] = "hand_of_midas", 
	[EventManagerLogicEvent.MStore.OnRefreshWithDiamond] = "refresh_mysterious_store",
	
}	
	
-- CostGold	
UMEvent.tCostGoldName = {
	[EventManagerLogicEvent.MStore.OnBuyGoods] = "buy_goods",
	[EventManagerLogicEvent.Potion.OnUpgradeResearch] = "upgrade_research", -- 升级研究所
	[EventManagerLogicEvent.Potion.OnUpgradePotion] = "upgrade_potion", -- 升级药水
	[EventManagerLogicEvent.Potion.OnBuyPotion] = "buy_potion", -- 
	[EventManagerLogicEvent.OnIntensifyEquipment] = "intensify_equipment",
	[EventManagerLogicEvent.Equipment.OnRecastEquipment] = "recast_equipment",
	[EventManagerLogicEvent.Lottery.OnGoldLottery] = "gold_lottery", -- 金币扭蛋
	
}


function UMEvent:funcCostGold(tCostData)
	if tCostData == nil then
		return;
	end
	
	if tCostData.LogicType == nil then
		tCostData.LogicType = "Unknow" 
	end
	
	if KDebug.ArgIsString(self.tCostGoldName[tCostData.LogicType]) then
		UMEvent:Use(self.tCostGoldName[tCostData.LogicType], 1, tCostData.Cost)
	end
	
	if self.tBuyGoodsText[tCostData.LogicType] == nil then
		KDebug.PrintDebug("[call UMEvent func] funcCostGold id:" .. tCostData.LogicType .. "is not UMEvent key!")
		return 
	end
	
	local szCustom = self.tBuyGoodsText[tCostData.LogicType] .. tCostData.Cost .. "金币" 
	
	ProtocolAnalytics_shared():logEvent("umGoldCost1",
		--{costType=tCostData.LogicType}, tCostData.Cost
		{costType =	szCustom}
		);
	
	-- 金币消耗统计
	ZQEvent:RoleItemUpdate("0", tCostData.PrizeId, "金币", tCostData.Cost, szCustom)
	
end
--[[
	tCostData = {
		LogicType,
		Cost,
		PrizeId,
	}
--]]
function UMEvent:funcCostDiamond(tCostData)
	if tCostData == nil then
		return;
	end
	
	if tCostData.LogicType == nil then
		tCostData.LogicType = "Unknow" 
	end
	
	if KDebug.ArgIsString(self.tCostDiamondName[tCostData.LogicType]) then
		UMEvent:Buy(self.tCostDiamondName[tCostData.LogicType], 1, tCostData.Cost)
	end
	
	if self.tBuyGoodsText[tCostData.LogicType] == nil then
		KDebug.PrintDebug("[call UMEvent func] funcCostDiamond id:" .. tCostData.LogicType .. "is not UMEvent key!")
		return 
	end
	--[[
	if tCostData.PrizeId then
		local prizeConfig =  G_ConfigManager:GetPrizeConfigWithID(self.PrizeId)
	end
	--]]
	local szCustom = self.tBuyGoodsText[tCostData.LogicType] .. tCostData.Cost .. "钻石"
	
	ProtocolAnalytics_shared():logEvent("umCostDiamond", 
		--{costType=tCostData.LogicType}, tCostData.Cost
		{costType =	szCustom }
		);
		
	-- 砖石消耗统计
	ZQEvent:RoleItemUpdate("0", tCostData.PrizeId, "钻石", tCostData.Cost, szCustom)
	
end




UMEvent.tEquipPartText = {
	"武器",
	"衣服",
	"鞋子",
	"项链",
	"戒指",
	"坐骑/翅膀"
}
--装备等级
function UMEvent:funcEquipLevel(tHeroData) 		
	if tHeroData == nil then
		return;
	end
	
	if self.tEquipPartText[tHeroData.EquipPartID] == nil then
		KDebug.PrintDebug("[call UMEvent func] EquipPart id:" .. tHeroData.EquipPartID .. "is not UMEvent key!")
		return
	end
	
	local szText = self.tEquipPartText[tHeroData.EquipPartID] .."提升到".. tHeroData.EquipLevel .. "级"
	
	ProtocolAnalytics_shared():logEvent(
		"umEquipHero"..tHeroData.HeroID, 
		--{equipLevel="part"..tHeroData.EquipPartID.."_level"..tHeroData.EquipLevel}
		{equipLevel= szText}
		);
	
	ZQEvent:RoleAct("EquipLevel", szText, "equipLevel")
	
end
--强化等级
function UMEvent:funcIntensifyLevel(tHeroData)
	if tHeroData == nil then
		return;
	end
	
	if self.tEquipPartText[tHeroData.EquipPartID] == nil then
		KDebug.PrintDebug("[call UMEvent func] EquipPart id:" .. tHeroData.EquipPartID .. "is not UMEvent key!")
		return
	end
	
	local szText = self.tEquipPartText[tHeroData.EquipPartID] .. "强化到" .. tHeroData.IntensifyLevel .. "级"
	
	ProtocolAnalytics_shared():logEvent(
		"umEquipHero"..tHeroData.HeroID, 
		--{intensifyLevel="part"..tHeroData.EquipPartID.."_intensifyLevel"..tHeroData.IntensifyLevel}
		{intensifyLevel= szText}
		);		
	
	ZQEvent:RoleAct("EquipIntensifyLevel", szText, "intensifyLevel")
	
end

UMEvent.tEquipQualityText = {
	"白色",
	"绿色",
	"蓝色",
	"紫色",
	"橙色",
	"红色",
}
--提品
function UMEvent:funcQuality(tHeroData) 		
	if tHeroData == nil then
		return;
	end
	
	if self.tEquipPartText[tHeroData.EquipPartID] == nil then
		KDebug.PrintDebug("[call UMEvent func] EquipPart id:" .. tHeroData.EquipPartID .. "is not UMEvent key!")
		return
	end
	if self.tEquipQualityText[tHeroData.Quality] == nil then
		KDebug.PrintDebug("[call UMEvent func] EquipQuality id:" .. tHeroData.Quality .. "is not UMEvent key!")
		return
	end
	
	local szText = self.tEquipPartText[tHeroData.EquipPartID] .."品质提升到".. self.tEquipQualityText[tHeroData.Quality]
	
	ProtocolAnalytics_shared():logEvent(
		"umEquipHero"..tHeroData.HeroID, 
		--{quality="part"..tHeroData.EquipPartID.."_quality"..tHeroData.Quality}
		{quality=szText}
		);				
		
	ZQEvent:RoleAct("EquipQuality", szText, "quality")
	
end


--ui事件
function UMEvent:funcUiShow(cUiName)
	ZQEvent:RoleStage("UI"..cUiName, "UI"..cUiName, "Show")
	ProtocolAnalytics_shared():startLevel("UI"..cUiName);			
end
function UMEvent:funcUiHide(cUiName)
	ZQEvent:RoleStage("UI"..cUiName, "UI"..cUiName, "Hide")
	ProtocolAnalytics_shared():finishLevel("UI"..cUiName);
end


--英雄事件
function UMEvent:funcHeroUnLock(tHeroData)
	
	if tHeroData == nil or tHeroData.IsLock then
		return;
	end
	
	-- 打包时并不是全版本都打入中文(暂时使用不了)
	--local szName = GetCNStringWithKey(string.format("HeroID_%d", tHeroData.UserHeroID))
	local szName = UMEventConfig.GetHeroName(tHeroData.UserHeroID)
	
	ProtocolAnalytics_shared():logEvent("umHeroUp", 
		{ unLock = "解锁" .. szName }
	);
	
	ZQEvent:RoleAct("HeroUnLock", "解锁" .. szName, "unLock")
	
end

function UMEvent:funcHeroFight(tHeroData)
	if tHeroData == nil or (tHeroData ~= nil and not tHeroData.IsFighting) then
		return;
	end
		
	--local szName = GetCNStringWithKey(string.format("HeroID_%d", tHeroData.UserHeroID))
	local szName = UMEventConfig.GetHeroName(tHeroData.UserHeroID)
	
	ProtocolAnalytics_shared():logEvent("umHeroUp", 
			--{fight="hero"..tHeroData.UserHeroID}
			{fight = szName .. "战斗力提升" }
		);	
		
	ZQEvent:RoleAct("HeroFight", szName .. "战斗力提升", "fight")
		
end

UMEvent.tHeroQualityText = {
	["1_0"] = "绿色",
	["1_1"] = "绿色+1",
	["2_0"] = "蓝色",
	["2_1"] = "蓝色+1",
	["2_2"] = "蓝色+2",
	["2_3"] = "蓝色+3",
	["3_0"] = "紫色",
	["3_1"] = "紫色+1",
	["3_2"] = "紫色+2",
	["3_3"] = "紫色+3",
	["4_0"] = "橙色",
	["4_1"] = "橙色+1",
	["4_2"] = "橙色+2",
	["4_3"] = "橙色+3",
	["5_0"] = "红色"
}

function UMEvent:funcHeroQuality(tHeroData)
	
	local bRetCode, nSecondQuality = false,0
	
	if tHeroData == nil then
		return;
	end
	
	-- 第二品质
	bRetCode, nSecondQuality = G_HeroLogic:GetHeroQualityIndex(tHeroData)
	if not bRetCode then
		nSecondQuality = 0
	end
	
	--local szName = GetCNStringWithKey(string.format("HeroID_%d", tHeroData.UserHeroID))
	local szName = UMEventConfig.GetHeroName(tHeroData.UserHeroID)
	
	local szQuality = self.tHeroQualityText[tHeroData.HeroQuality.."_"..nSecondQuality] or tHeroData.HeroQuality.."_"..nSecondQuality
	
	ProtocolAnalytics_shared():logEvent("umHeroUp", 
		--{quality="hero"..tHeroData.UserHeroID.."_quality"..tHeroData.HeroQuality}
		{quality = szName .."到达".. szQuality}
		);	
		
	ZQEvent:RoleAct("HeroQuality", szName .."到达".. szQuality, "quality")
	
end

function UMEvent:funcHeroGrowthFactor(tHeroData)
	
	if tHeroData == nil then
		return;
	end
	
	--local szName = GetCNStringWithKey(string.format("HeroID_%d", tHeroData.UserHeroID))
	local szName = UMEventConfig.GetHeroName(tHeroData.UserHeroID)
	
	ProtocolAnalytics_shared():logEvent("umHeroUp", 
		{ growthFactor = szName .. "提升到".. tHeroData.HeroGrowthFactor  .. "星" }
		);	
		
	ZQEvent:RoleAct("HeroGrowthFactor", szName .. "提升到".. tHeroData.HeroGrowthFactor  .. "星", "growthFactor")
	
end

--士兵升级
function UMEvent:funcArmyLevelUp(tArmyData)
	if tArmyData == nil then
		return;
	end
	
	--local szName = GetCNStringWithKey("ArmyID_"..tArmyData.ArmyTypeID)
	local szName = UMEventConfig.GetArmyName(tArmyData.ArmyTypeID)
	
	local szText = szName .. "提升到" .. tArmyData.ArmyLevel .. "级"
	
	ProtocolAnalytics_shared():logEvent("umArmyLevelUp", 
		--{armyLevelUp="armyType" .. tArmyData.ArmyTypeID .. "_level"..tArmyData.ArmyLevel}
		{armyLevelUp= szText}
		);	
	
	ZQEvent:RoleAct("ArmyLevelUp", szText, "armyLevelUp")
	
end

function UMEvent:funcBarracksLevelUp(tUserInfo)

	if tUserInfo == nil then
		return;
	end
	
	local szText = "兵营提升到" ..tUserInfo.BarracksLevel .. "级"
	
	ProtocolAnalytics_shared():logEvent("umArmyLevelUp", 
		--{barracksLevelUp="level"..tUserInfo.BarracksLevel}
		{barracksLevelUp= szText}
		);	
		
	ZQEvent:RoleAct("BarracksLevelUp", szText, "barracksLevelUp")
	
end

UMEvent.tPotionNameText = {
	"闪电药水",
	"防御药水",
	"灵魂药水",
	"医疗药水",
	"腐蚀药水",
	"觉醒之秘药"
}

--药水
function UMEvent:funcPotionLevel(tUserInfo)	
	if tUserInfo == nil then
		return;
	end
	
	if self.tPotionNameText[tUserInfo.PotionId] == nil then
		KDebug.PrintDebug("[call UMEvent func] Potion id:" .. tUserInfo.PotionId .. "is not UMEvent key!")
		return
	end
	
	ProtocolAnalytics_shared():logEvent("umPotion", 
		--{potionLevel="potion"..tUserInfo.PotionId.."_level"..tUserInfo.PotionLevel}
		{potionLevel= self.tPotionNameText[tUserInfo.PotionId] .. "提升到"..tUserInfo.PotionLevel.. "级"}
		);	
end

function UMEvent:funcPotionResearchLevel(tUserInfo)
	if tUserInfo == nil then
		return;
	end
		
	ProtocolAnalytics_shared():logEvent("umPotion", 
		--{researchLevel="researchLevel"..tUserInfo.ResearchLevel}
		{researchLevel = "药水研究所提升到" ..tUserInfo.ResearchLevel.."级"}
		);	
end

function UMEvent:funcPotionUnLock(tUserInfo)
	if tUserInfo == nil or tUserInfo.IsLock then
		return;
	end
	
	if self.tPotionNameText[tUserInfo.PotionId] == nil then
		KDebug.PrintDebug("[call UMEvent func] Potion id:" .. tUserInfo.PotionId .. "is not UMEvent key!")
		return
	end
	
	ProtocolAnalytics_shared():logEvent("umPotion", 
		--{unLock="unLockPotion"..tUserInfo.PotionId}
		{unLock= "解锁了" .. self.tPotionNameText[tUserInfo.PotionId]}
		);	
end

function UMEvent:funcPotionCount(tUserInfo)
	if tUserInfo == nil then
		return;
	end		
	
	if self.tPotionNameText[tUserInfo.PotionId] == nil then
		KDebug.PrintDebug("[call UMEvent func] Potion id:" .. tUserInfo.PotionId .. "is not UMEvent key!")
		return
	end
	
	ProtocolAnalytics_shared():logEvent("umPotion", 
	--{potionCount="potion"..tUserInfo.PotionId}
		{potionCount= self.tPotionNameText[tUserInfo.PotionId]}
	);		
end

-- 登录
--[[
    @param accountId: 账号ID
	@param roleId: 角色ID
	@param serverId: 服务器ID （必须）
	@param userName: 用户名
	@param ingot: 剩余元宝数量	（可选）
	@param userLevel 用户等级
	@param serverName 服务器名称
--]]
function UMEvent:LoginInfo(accountId, roleId, serverId, userName, ingot, userLevel, serverName)
	
	if ingot == nil then
		ingot = ""
	end
	
	XGAnalytics:setUserInfo(tostring(serverId), tostring(USER_GLOBAL.COMMON_INFO.CHANNEL_ID), tostring(accountId), tostring(roleId), tostring(userName))
	XGAnalytics:logEventLogin()

	--jsonExData.put("roleId", "R0010");// 当前登录的玩家角色ID
	--jsonExData.put("roleName", "令狐一冲");// 当前登录的玩家角色名
	--jsonExData.put("roleLevel", "99");// 当前登录的玩家角色等级
	--jsonExData.put("zoneId", 192825);// 当前登录的游戏区服ID
	--jsonExData.put("zoneName", "游戏一区-逍遥谷");// 当前登录的游戏区服名称
	
	ProtocolUser_shared():submitExtendData("submitExtendData", {roleId=roleId, roleName=userName, roleLevel=userLevel, zoneId=serverId, zoneName=serverName});	
	
	--[[
	std::string user_roleid; // 角色ID
	std::string user_rolename ; // 角色名称
	std::string server_id; // 角色所在服务器ID
	std::string server_name; // 角色所在服务器名称
	std::string user_lv; // 角色等级
	std::string user_race; // 角色种族
	std::string user_party; // 角色帮派工会
	std::string user_vip; // vip等级
	std::string user_blance; // 账户余额
	]]
	sngUtil_log("zzf test: ProtocolUser_shared().setRoleInfo  1")
	if ProtocolUser_shared().setRoleInfo then
		sngUtil_log("zzf test: ProtocolUser_shared().setRoleInfo  2")
		local tRoleInfo = 
		{
			user_roleid = roleId,
			user_rolename = userName,
			server_id = serverId,
			server_name = serverName,
			user_lv = userLevel,
			user_race = 0,
			user_party = 0,
			user_vip = 0,
			user_blance = ingot
		}	
		
		ProtocolUser_shared():setRoleInfo( tRoleInfo )
	end
end

-- 打开游戏
function UMEvent:StartGame()
	ProtocolAnalytics_shared():logEvent(self:GetEventName("umStartGame"))
end

-- 内更新开始
function UMEvent:UpdateInnerStart()
	ProtocolAnalytics_shared():logEvent(self:GetEventName("umUpdateInStart"));
end

-- 内更新结束
function UMEvent:UpdateInnerEnd()
	ProtocolAnalytics_shared():logEvent(self:GetEventName("umUpdateInEnd"));
end



-- 进入登录界面
function UMEvent:EnterLoginUI()
	ProtocolAnalytics_shared():logEvent("umEnterLoginUI")
end

-- 开始登陆SDK账号
function UMEvent:LoginSDK()
	ProtocolAnalytics_shared():logEvent(self:GetEventName("umLoginSDK"))
end

-- 登陆SDK成功
function UMEvent:LoginSDKSuccessfully()
	ProtocolAnalytics_shared():logEvent(self:GetEventName("umLoginSDKSuccessfully"))
end


-- 登陆SDK返回
function UMEvent:LoginSDKCallBack(strCode)
	ProtocolAnalytics_shared():logEvent(self:GetEventName("umLoginSDKCallBack"), {ErrCode = strCode});
end


-- 开始登陆账号
function UMEvent:LoginAccount()
	ProtocolAnalytics_shared():logEvent(self:GetEventName("umLoginAccount"))
	XGAnalytics:logEventByID(XGAnalytics.EVENT_ID.LOGINUSER)
end

-- 登陆成功
function UMEvent:LoginSuccessfully()
	ProtocolAnalytics_shared():logEvent(self:GetEventName("umLoginSuccessfully"))
end

-- 进入游戏
function UMEvent:EnterGame()
	ProtocolAnalytics_shared():logEvent(self:GetEventName("umEnterGame"))
	if UMEvent:GetIsFirstStart() == true then
		UMEvent:SetIsFirstStart()
	end
end

-- 创建角色（起名）
function UMEvent:CreateRole()
	ProtocolAnalytics_shared():logEvent(self:GetEventName("umCreateRole"))
end

-- 检查版本
function UMEvent:CheckVersion()
	ProtocolAnalytics_shared():logEvent("umCheckVersion")
end

-- 加载资源
function UMEvent:LoadResources()
	ProtocolAnalytics_shared():logEvent("umLoadResources")
end

-- 加载完成
function UMEvent:Loaded()
	ProtocolAnalytics_shared():logEvent("umLoaded")
end


-- 登录开始
function UMEvent:LoginBegin()
	KDebug.PrintDebug("登录开始 umLoginBegin")
	ProtocolAnalytics_shared():logEvent("umLoginBegin")
end

-- 登录结束
function UMEvent:LoginEnd()
	KDebug.PrintDebug("登录结束 umLoginEnd")
	ProtocolAnalytics_shared():logEvent("umLoginEnd")
end

-- 进入游戏服务器开始
function UMEvent:EnterGameServerBegin()
	KDebug.PrintDebug("进入游戏服务器开始 umEnterGameServerBegin")
	ProtocolAnalytics_shared():logEvent(self:GetEventName("umEnterGameServerBegin"));
end


-- 点击游戏按钮
-- state 1  点击进入游戏按钮  0 成功返回
function UMEvent:OnEnterGameServer(nState)
	ProtocolAnalytics_shared():logEvent("umOnEnterGameServer", {Action= nState});		    
    if nState == 2 or nState == 3 then
	    XGAnalytics:logEventByID(XGAnalytics.EVENT_ID.LOGINGAME)
    end
end

-- 进入游戏服务器结束
function UMEvent:EnterGameServerEnd()
	KDebug.PrintDebug("进入游戏服务器结束 umEnterGameServerEnd")
	ProtocolAnalytics_shared():logEvent(self:GetEventName("umEnterGameServerEnd"));
end

-- 显示创建角色界面
function UMEvent:ShowUICreateRole()
	ProtocolAnalytics_shared():logEvent(self:GetEventName("umShowUICreateRole"));	
end


-- 开始新手动画（东汉末年）
function UMEvent:BeginNoviceAnimation()
	KDebug.PrintDebug("开始新手动画（东汉末年） umBeginNoviceAnimation")
	ProtocolAnalytics_shared():logEvent(self:GetEventName("umBeginNoviceAnimation"))
	XGAnalytics:logEventByID(XGAnalytics.EVENT_ID.NOVICESTORY)
end

-- 开启新手战役（周仓说话）
function UMEvent:OpenNoviceBattleCampaign()
	KDebug.PrintDebug("开启新手战役（周仓说话） umOpenNoviceBattleCampaign")
	ProtocolAnalytics_shared():logEvent("umOpenNoviceBattleCampaign")
end

-- 点击赵云释放技能
function UMEvent:ClickZhaoYunReleaseSkill()
	ProtocolAnalytics_shared():logEvent(self:GetEventName("umClickZhaoYunReleaseSkill"))
end

-- 点击小乔释放技能
function UMEvent:ClickXiaoQiaoReleaseSkill()
	KDebug.PrintDebug("点击小乔释放技能 umClickXiaoQiaoReleaseSkill")
	ProtocolAnalytics_shared():logEvent(self:GetEventName("umClickXiaoQiaoReleaseSkill"))
end

-- 点击张飞释放技能
function UMEvent:ClickZhangFeiReleaseSkill()
	KDebug.PrintDebug("点击张飞释放技能 umClickZhangFeiReleaseSkill")
	ProtocolAnalytics_shared():logEvent(self:GetEventName("umClickZhangFeiReleaseSkill"))
end

-- 出现结算界面
function UMEvent:ShowUIBattleResult()
	KDebug.PrintDebug("显示结算界面 umShowUIBattleResult")
	ProtocolAnalytics_shared():logEvent(self:GetEventName("umShowUIBattleResult"))
end

-- 显示主城界面
function UMEvent:ShowUIMain()
	KDebug.PrintDebug("显示主城界面 umShowUIMain");
	ProtocolAnalytics_shared():logEvent(self:GetEventName("umShowUIMain"));
end

-- 新手获得左慈
function UMEvent:NoviceGetHeroZuoCi()
	KDebug.PrintDebug("新手获得左慈 umGetHero1")
	ProtocolAnalytics_shared():logEvent("umGetHero1")
end

-- 新手获得凌统
function UMEvent:NoviceGetHeroLingTong()
	KDebug.PrintDebug("新手获得凌统 umGetHero2")
	ProtocolAnalytics_shared():logEvent("umGetHero2")
end

--[[
充值
参数:
	nCash 真实币数量：>=1的整数,最多只保存小数点后2位
	nSource 支付渠道：1 ~ 100的整数, 其中1..20 是预定义含义,其余21-100需要在网站设置。
	nCoin 虚拟币数量：大于0的整数, 最多只保存小数点后2位,一般情况下coin = amount * price
返回值：

--]]
function UMEvent:Pay(nCash, nSource, nCoin)
	ProtocolAnalytics_shared():pay(nCash, 1, nCoin)
	XGAnalytics:logEventPayFor(nCash, nCoin)
end

--[[
充值
参数:
	nCash 真实币数量：>=1的整数,最多只保存小数点后2位
	nSource 支付渠道：1 ~ 100的整数, 其中1..20 是预定义含义,其余21-100需要在网站设置。
	strItemName 道具名称：非空字符串
	nAmount 道具数量：大于0的整数
	nPrice 道具单价：>=0
返回值：

--]]
function UMEvent:PayAndBuyItem(nCash, nSource, strItemName, nAmount, nPrice)
	ProtocolAnalytics_shared():pay(nCash, 1, strItemName, nAmount, nPrice)
	XGAnalytics:logEventPayFor(nCash, nPrice)
end

--[[
购买
参数:
	strItemName 名称
	nAmount 数量
	nPrice 单价
返回值：

--]]
function UMEvent:Buy(strItemName, nAmount, nPrice)
	ProtocolAnalytics_shared():buy(strItemName, nAmount, nPrice)
end

--[[
消耗
参数:
	strItemName 名称
	nAmount 数量
	nPrice 单价
返回值：

--]]
function UMEvent:Use(strItemName, nAmount, nPrice)
	ProtocolAnalytics_shared():use(strItemName, nAmount, nPrice)
end

--[[
额外奖励-赠送金币
参数:
	nCoin 金币数
	nSource 奖励渠道
返回值：

--]]
function UMEvent:Bonus(nCoin, nSource)
	ProtocolAnalytics_shared():bonus(nCoin, 1)
end
--[[
额外奖励-赠送道具
参数:
	strItemName 道具名
	nAmount 数量
	nPrice 单价
	nSource 渠道
返回值：

--]]
function UMEvent:Bonus_Item(strItemName, nAmount, nPrice, nSource)
	ProtocolAnalytics_shared():bonus(strItemName, nAmount, nPrice, 1)
end


-- 腾讯点击事件
--[[
txClickCreateRole
腾讯点击创角色
txClickEnterGame
腾讯点击进入游戏
txClickRandomName
腾讯点击随机名字
txLoginGuest
腾讯点击游客登陆按钮
txLoginQQ
腾讯点击QQ登陆按钮
txLoginWX
腾讯点击微信登陆按钮
txSelectSvrList
腾讯选择区服
--]]

-- 腾讯点击创角色
function UMEvent:txClickCreateRole()
	
	if self.UMQQType == self.tUMQQType.QQ then
		ProtocolAnalytics_shared():logEvent(self:GetEventName("tx_qq_ClickCreateRole"))
	elseif self.UMQQType == self.tUMQQType.WX then
		ProtocolAnalytics_shared():logEvent(self:GetEventName("tx_wx_ClickCreateRole"))
	elseif self.UMQQType == self.tUMQQType.Guest then
		ProtocolAnalytics_shared():logEvent(self:GetEventName("txClickCreateRole"))
	end
end

-- 腾讯点击进入游戏
function UMEvent:txClickEnterGame()
	
	if self.UMQQType == self.tUMQQType.QQ then
		ProtocolAnalytics_shared():logEvent(self:GetEventName("tx_qq_ClickEnterGame"))
	elseif self.UMQQType == self.tUMQQType.WX then
		ProtocolAnalytics_shared():logEvent(self:GetEventName("tx_wx_ClickEnterGame"))
	elseif self.UMQQType == self.tUMQQType.Guest then
		ProtocolAnalytics_shared():logEvent(self:GetEventName("txClickEnterGame"))
	end	
end

-- 腾讯点击随机名字
function UMEvent:txClickRandomName(szType)
	
	if self.UMQQType == self.tUMQQType.QQ then
		ProtocolAnalytics_shared():logEvent(self:GetEventName("tx_qq_ClickRandomName"))
	elseif self.UMQQType == self.tUMQQType.WX then
		ProtocolAnalytics_shared():logEvent(self:GetEventName("tx_wx_ClickRandomName"))
	elseif self.UMQQType == self.tUMQQType.Guest then
		ProtocolAnalytics_shared():logEvent(self:GetEventName("txClickRandomName"))
	end
end

-- 腾讯点击游客登陆按钮
function UMEvent:txLoginGuest()
	self.UMQQType = self.tUMQQType.Guest
	ProtocolAnalytics_shared():logEvent(self:GetEventName("txLoginGuest"))
end

-- 腾讯点击QQ登陆按钮
function UMEvent:txLoginQQ()
	self.UMQQType = self.tUMQQType.QQ
	ProtocolAnalytics_shared():logEvent(self:GetEventName("txLoginQQ"))
end

-- 腾讯点击微信登陆按钮
function UMEvent:txLoginWX()
	self.UMQQType = self.tUMQQType.WX
	ProtocolAnalytics_shared():logEvent(self:GetEventName("txLoginWX"))
end

-- 腾讯选择区服
function UMEvent:txSelectSvrList()
	
	if self.UMQQType == self.tUMQQType.QQ then
		ProtocolAnalytics_shared():logEvent(self:GetEventName("tx_qq_SelectSvrList"))
	elseif self.UMQQType == self.tUMQQType.WX then
		ProtocolAnalytics_shared():logEvent(self:GetEventName("tx_wx_SelectSvrList"))
	elseif self.UMQQType == self.tUMQQType.Guest then
		ProtocolAnalytics_shared():logEvent(self:GetEventName("txSelectSvrList"))
	end
end

function UMEvent:SetQQType(nType)
	self.UMQQType = nType
end	

-- 埋点
function UMEvent:UserLogicUIClick(MainUiId, SubId, info)
	--G_UserLogic:ClientSetUIClick(MainUiId, SubId, info)
end



-- 掌趣统计处理, TODO: 测试
function UMEvent:LogZQEvent(strEventId, strEventName, tData)
	
	 if SDK_Mgr.nUserType ~= UserType.ZQAndroid 
	 	and SDK_Mgr.nUserType ~= UserType.ZQIos
  		and SDK_Mgr.nUserType ~= UserType.ZQGPlay 
  	then
  		return
  	end

 	if strEventId == nil or strEventName == nil then
 		return
 	end

 	if tData == nil then
        tData = {}
 	end

	tData.logKey = strEventName
 	local strEventData = cjson.encode(tData)

 	sngUtil_log("LogZQEvent: strEventId=".. tostring(strEventId) .. " strEventName=" .. tostring(strEventName) .. " strEventData=" .. tostring(strEventData))

	ProtocolUser_shared():submitExtendData(strEventId, strEventData)
end


--下载开始
function UMEvent:downloadBegin()
	ProtocolAnalytics_shared():logEvent("umInnerUpdateDownloadBegin")
end

--下载结束
function UMEvent:downloadEnd()
	ProtocolAnalytics_shared():logEvent("umInnerUpdateDownloadEnd")
end

--统计下载错误
function UMEvent:downloadError(dwErrorCode)
	ProtocolAnalytics_shared():logEvent("umDownloadError", {ErrCode = tostring(strCode)});
end

-- CHEN: thong ke Umeng lam ban dich ARM cua may ao chet.
function UMEvent:Init() end
function UMEvent:StartGame() end
