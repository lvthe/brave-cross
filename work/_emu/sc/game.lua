print("CHEN|dang dung ban de game.lua")
--[[
local declaredNames = {} 
local mt = {
 __newindex = function(table,name,value)
	
	if name == "lSubDialogMask" then
		local ii = 0;
		ii = 0;
	end
	
	
	
	
	
	 rawset(table,name,value)
 end,
 
 __index = function(_,name)
	
	if name == "lSubDialogMask" then
		local ii = 0;
		ii = 0;
	end
	
	return rawget(_,name)
	
 end
}    
 setmetatable(_G,mt)
]]
TIME_DIF = 0
DEBUG = false
ENABLE_STRING_RECORD = false -- 字符串记录开关(开启后会记录使用到的StringKey到StringRecord.xgg中)
DEBUG_OPEN_LOCAL_SERVER_LIST = true -- 测试打开本地服务器列表

-- 战场出来是否检查内更新控制
CHECK_RESUPDATE_AFTER_BATTLE = false 

--2015/5/18 by rong34 begin 重新指向
if os.dateServer ~= nil then
	os.dateOrg = os.date
	os.date = os.dateServer;
end
--2015/5/18 by rong34 end

--设置包的搜索选项
function sngSetSearchFileSuffix(strSuffixName)

	strSuffixName	= "sc/?"..strSuffixName..";"	--sc/?.lua

	local szExternalStorageDirectory = LGG_GetExternalStorageDirectory()
	szExternalStorageDirectory = szExternalStorageDirectory .. strSuffixName

	local szDownloadPath = LGG_GetDownloadPath()
	szDownloadPath = szDownloadPath .. strSuffixName

	local szAssetsPath = LGG_GetAssetsPath()
	szAssetsPath = szAssetsPath .. strSuffixName

	package.path  =  szExternalStorageDirectory .. szDownloadPath .. szAssetsPath ..package.path;
end

sngSetSearchFileSuffix(".lua");
sngSetSearchFileSuffix(".sc");
print("CHEN|package.path=" .. tostring(package.path))


--2016/12/20 by rong34 begin 由于luaState ret过程中，如果触发printToSystemErrorLog 
--会重新构造ProtocolUser_shared单例，造成ProtocolUser_shared存储的luaState是reset前的，
--登录回调就会crash
if ProtocolUser_shared() and ProtocolUser_shared().purge then
   ProtocolUser_shared():purge()
end	
--2016/12/20 by rong34 end


print("CHEN|truoc sngHttMgr = ")
sngHttMgr = {}
sngHttMgr.m_pRawFunc_sngHttpRequest 			= sngHttpRequest
sngHttMgr.m_pRawFunc_sngHttpRequestWithData		= sngHttpRequestWithData
sngHttMgr.m_pRawFunc_sngHttpRequestByFile		= sngHttpRequestByFile
sngHttMgr.m_pRawFunc_sngHttpRequestWithString	= sngHttpRequestWithString
sngHttMgr.m_tNodeArr = {}
sngHttMgr.m_tNodeArr.tHightProriArr = {}
sngHttMgr.m_tNodeArr.tLowPriorArr 	= {}

sngHttpRequest = function (...)
	sngHttMgr:__push(false, sngHttMgr.m_pRawFunc_sngHttpRequest, ...)
end

sngHttpRequest_prior = function (...)
	sngHttMgr:__push(true, sngHttMgr.m_pRawFunc_sngHttpRequest, ...)
end

sngHttpRequestWithData = function (...)
	sngHttMgr:__push(false, sngHttMgr.m_pRawFunc_sngHttpRequestWithData, ...)
end

sngHttpRequestWithData_prioi = function (...)
	sngHttMgr:__push(true, sngHttMgr.m_pRawFunc_sngHttpRequestWithData, ...)
end

sngHttpRequestWithString = function (...)
	sngHttMgr:__push(false, sngHttMgr.m_pRawFunc_sngHttpRequestWithString, ...)
end

sngHttpRequestWithString_prior = function (...)
	sngHttMgr:__push(true, sngHttMgr.m_pRawFunc_sngHttpRequestWithString, ...)
end

sngHttpRequestByFile = function (...)
	sngHttMgr:__push(false, sngHttMgr.m_pRawFunc_sngHttpRequestByFile, ...)
end

sngHttpRequestByFile_prior = function (...)
	sngHttMgr:__push(true, sngHttMgr.m_pRawFunc_sngHttpRequestByFile, ...)
end

function sngHttMgr:__push(bPrior, pFunc, ...)
	local tNewNode = 
	{
		bPrior	= bPrior,
		pFunc 	= pFunc,
		tParam	= {...}
	}
	
	local tTargeArr = nil
	if bPrior == true then
		tTargeArr = self.m_tNodeArr.tHightProriArr
	else
		tTargeArr = self.m_tNodeArr.tLowPriorArr
	end
	
	if tTargeArr ~= nil then
		table.insert(tTargeArr, tNewNode)
	end
end

function sngHttMgr:__runNodeArr(tNodeArr)
	repeat
		if tNodeArr == nil or #tNodeArr <= 0 then break end
		--
		for i=1, #tNodeArr do
			local tCurNode = tNodeArr[i]
			tCurNode.pFunc(unpack(tCurNode.tParam))
		end
	until true
end

function sngHttMgr:__run()
	repeat
		if #self.m_tNodeArr.tHightProriArr > 0 then
			self:__runNodeArr(self.m_tNodeArr.tHightProriArr)
			self.m_tNodeArr.tHightProriArr = {}
		end
		--
		if ProtocolUser_shared == nil or not ProtocolUser_shared():isLogined() then break end
		--
		if #self.m_tNodeArr.tLowPriorArr > 0 then
			self:__runNodeArr(self.m_tNodeArr.tLowPriorArr)
			self.m_tNodeArr.tLowPriorArr = {}
		end
	until true
end

function sngHttMgr:createInstance()
	g_CTimerManager:AddMission("sngHttMgr", self, "__run")
end

function sngHttMgr:destroyInstance()
	g_CTimerManager:RemoveMission("sngHttMgr")
end



--优先加载Share
require("share.share_public_require")
require("share.share_gameLogic_require")
KDebug.PrintDebug("game.lua 1")

--包含System/s_require.lua文件
require("system.s_require")
KDebug.PrintDebug("game.lua 1.5")

--包含user/require文件
require("user.require")

--设置是否缓存对象
--sngObjCache_setIsCache(false);


if LGG_GetPlatformString() == "ios" then
	-- umeng channel, 在SDK_Setting.lua配置
	ProtocolAnalytics_shared():setChannelId(SDK_Mgr.UMENG_KEY) 
	-- umeng启动
	ProtocolAnalytics_shared():startSession("541ff7eefd98c515a800093e")
end

--测试支付
--require("user.Public.debug_ProtocolIAP")

if DEBUG then

	--测试RPC连接
	g_TestRPC:loadUI()
	do return end	
	--测试结束
end

KDebug.PrintDebug("game.lua 1.8")


do
	require("system.sngRpcAnalytics")
	sngRpcAnalytics:start()
end

G_ConfigManager:Init()

KDebug.PrintDebug("game.lua 2")

--读取数据
initGameConfig()

XGAnalytics:logEventByID(XGAnalytics.EVENT_ID.START)

--友盟统计初始化
UMEvent:Init();

XGEvent:Init();


KDebug.PrintDebug("game.lua 3")

--初始化剧情脚本系统
require("plot.string_gb")
KDebug.PrintDebug("game.lua 3.5")
g_DramaSystem = DFDramaScriptSystem:new()
KDebug.PrintDebug("game.lua 4")
--初始化声音模块
g_SimpleAudioEngine = SimpleAudioEngine:new()
KDebug.PrintDebug("game.lua 5")
--初始化下载模块

if true or SDK_Mgr.bIsUseUpdateV2 then
  require("user.Public.sngDownload_c2l")
  g_DownloadMgr = sngDownload_c2l;
else
  g_DownloadMgr = IsngDownloadMgr:new()
end

--[[
	@brief	补丁
--]]
sngPatch = {}
function sngPatch:__process_HeroIcon3()
	local bNeedRestart = false
	repeat
		local strFlg = g_SetGame:GetString("sngPatchHeroIcon3")
		if strFlg == "true" then break end
		--
		local strPath = sngUtil:getDownloadPath().."img_all/HeroIcon_3.pkm"
		if sngUtil:isFileExist(strPath) == false then break end
		--
		os.remove(strPath)
		g_SetGame:SetString("sngPatchHeroIcon3", "true")
		--
		LGG_RestartGame()
		bNeedRestart = true
	until true
	return bNeedRestart
end

if sngPatch:__process_HeroIcon3() == true then
	return
end

--2017/2/20 by rong34 begin 覆盖安装的时候
do
	local strBundleVersion = g_SetGame:GetString("BundleVersion") 
	local bWriteVersion = false
	local bNeedRestart = false
	if strBundleVersion == nil then
		bWriteVersion = true
	elseif strBundleVersion == "" or  strBundleVersion ~=  LGG_App_BundleVersion() then
		bWriteVersion = true
		bNeedRestart = true
		
		sngUtil:deletePath(sngUtil:getDownloadPath().."sc/")
		sngUtil:deletePath(sngUtil:getDownloadPath().."conf/")
		sngUtil:deletePath(sngUtil:getDownloadPath().."config/")
		sngUtil:deletePath(sngUtil:getDownloadPath().."img_all/")
		sngUtil:deletePath(sngUtil:getDownloadPath().."map/")
		os.remove(sngUtil:getDownloadPath().."sngPngDesData.bin")
		os.remove(sngUtil:getDownloadPath()..sngDownload.DEF_FILENAME_VERSION)
		os.remove(sngUtil:getDownloadPath()..sngDownload.DEF_FILENAME_RESCRITABLE)

	end
	
	if bWriteVersion == true then
		g_SetGame:SetString("BundleVersion", LGG_App_BundleVersion())
		-- hua: 2016-04-12 复制全资源包
		if LGG_needCopyResZip then
			local needCopy = LGG_needCopyResZip()
			-- sngUtil_log("hua test: LGG_needCopyResZip =" .. tostring(needCopy))
			if needCopy and LGG_copyResZip then
				local result = LGG_copyResZip()
				-- sngUtil_log("hua test: LGG_copyResZip =" .. tostring(result))
			end
		end
	end
	
	if bNeedRestart then
		LGG_RestartGame() 
		return
	end
end
--2017/2/20 by rong34 end

--2017/8/26 by rong34 begin
if g_CUIMainTheme and g_CUIMainTheme.__twoYearCheckInit ~= nil then
	g_CUIMainTheme:__twoYearCheckInit()
end
--2017/8/26 by rong34 end


--[[
if IS_OPEN_VOICE then
    setUsualVoiceMute(false)
	setWakeVoiceMute(false)		
else
    setUsualVoiceMute(true)
	setWakeVoiceMute(true)		
end
]]

KDebug.PrintDebug("game.lua 6")
-- CHEN: FMOD la thu vien ARM, goi qua ban dich la SIGSEGV.
local function _bo() end
loadBackgroundBank = _bo
loadEffectBank = _bo
pushBankStack = _bo
print("CHEN|da tat am thanh")


-- 设置随机数种子
math.randomseed(os.time())

--初始游戏声音
loadBackgroundBank("BG", "banks/BGM.bank")
loadBackgroundBank("BG", "banks/BGM_NewYear.bank")
loadBackgroundBank("BG", "banks/BGM_Anniversary.bank")
loadBackgroundBank("BG", "banks/BGM_TwoYear.bank")
loadEffectBank("UI", "banks/UI.bank")
loadEffectBank("UI", "banks/UI_EVENT.bank")

pushBankStack()            --加入一个栈 后面全部走管理

--初始游戏声音 end

-- 配置界面(读取本地配置设置：音乐，音效，版本号)
print("CHEN|truoc g_CUIOptions:InitGameInfo()")
g_CUIOptions:InitGameInfo()

-- 断线重连次数
USER_GLOBAL.RECONNECT_COUNT = 3

----------
-- 测试 --
----------
-- 测试模式
-- 在本地set.xgg中加入<DebugTestMode>true</DebugTestMode>
-- 本地测试的地方使用(本地测试功能)
G_DEBUG_TEST_MODE = g_SetGame:GetString("DebugTestMode") == "true"
if G_DEBUG_TEST_MODE then
	g_CGameFuncOpeningManager.IsTest = true
end

--[[
--UI
Test0000 = class()

function Test0000:ctor()
	
	self.nTouchCount = 0
	
end	

g_Test0000 = Test0000:new()

-- 播放升级的动作
function Test0000:onTouchEnd_OnTestPlayLevelUp(obj, bTouch)
	
	local nAddLevel = test0000_ebLevelUpCount:getText()
	if nAddLevel== nil or nAddLevel == "" then
		nAddLevel = 0
	end
	
	nAddLevel = tonumber(nAddLevel)
	nEndLevel = 0
	nBeginPercent = 0
	nEndPercent = 100
	nIntervalTime = 0.5
	
	--tLevelUpData = {pActionObjParent = test0000_ptLevelUpIconBg, pActionObj = test0000_ptLevelUpIcon, pActionFont = test0000_ptLevelFont, szLevel = 1}
	--tLevelFullData = {pActionObj = test0000_ptLevelFullIcon}
	--tEndData = {}
	
	g_CPublic:RunActionWithAddExp(test0000_ptExpValue, nAddLevel, nEndLevel, nBeginPercent, nEndPercent, nIntervalTime, tLevelUpData, tLevelFullData, tEndData)
	
end		


-- 重新装载 loading ui
function Test0000:onTouchEnd_OnTestReloadUI()
	
	if self.nTouchCount%2 == 0 then
		g_CUILoad:SetFBTips(3)
	end
	
	loadLevelFile("conf/UI_Load_960_640.xgg")
	S_CCDirector:replaceScene(g_LoadScene)
	g_CUILoad:PlayLoading()
	
	self.fTime = 5
	g_CTimerManager:AddMission("Test0000_CallLoadTimer", self, "CallLoadTimer")
	
	self.nTouchCount = self.nTouchCount + 1
	
end	

function Test0000:CallLoadTimer(fTime)
	
	self.fTime = self.fTime - fTime
	if self.fTime <= 0 then
		g_CTimerManager:RemoveMission("Test0000_CallLoadTimer")
		loadLevelFile("conf/TestToDoUI.xgg")
		S_CCDirector:replaceScene(g_TestToDoScene)
	end
end	

-- 播放光芒
function Test0000:onTouchEnd_OnTouchPlayLight(obj)
	
	--self.pLight = getSpriteFromSpriteCatch("ExpEffect_UseBall")
	
	self.pLight = getSpriteFromSpriteCatch("UIYingXiongTiPin_TiPin")
	--self.pLight = getSpriteFromSpriteCatch("ShengXingAnima")
	spTest0000Light:addChild(self.pLight)
	self.pLight:_Lua_playAnimation("Play")
	
end	

loadLevelFile("conf/TestToDoUI.xgg")
S_CCDirector:replaceScene(g_TestToDoScene)

do return end
--]]
-------------
-- 测试 end--
-------------

print("CHEN|truoc g_CUILoad:InitUI()")
g_CUILoad:InitUI()

-- [[
--是否关闭新手引导

if g_SetGame:GetString("CloseGuide") == "true" then
	-- 关闭新手
	g_CUIMain.bIgnoreGuide = true
else
	g_CUIMain.bIgnoreGuide = false
end

-- 打开所有游戏的功能
if g_SetGame:GetString("OpenAllGameFun") == "true" then
	g_CGameFuncOpeningManager.IsTest = true
end

--require("local")

-- 显示被踢的信息
g_bShowServerKickedMsg = false

--rong 2014/11/10
-- 是否异步装载
g_bSngSceneLoadAsync = false;

--战场测试
g_CUIGame.bTestButton = false
--关卡剧情不关闭
g_CUIGame.bRepeatPlot = false

local bDirectBattle = false

print("CHEN|truoc XGAnalytics:logEventByID(XGAnalyti")
XGAnalytics:logEventByID(XGAnalytics.EVENT_ID.LOADCONFIG)



-- === CHEN DE DO: diem gan armature co mang ti le 1,02 khong (emu_plug.py sinh ra) ===
do
	local function goi(ten, f)
		print("PLUG|goi|" .. ten)
		local ok, a, b = pcall(f)
		print("PLUG|xong|" .. ten .. "|" .. tostring(ok) .. "|"
			.. tostring(a) .. "," .. tostring(b))
		return a, b
	end

	local function hinh(ten)
		local ok, a = pcall(getSpriteFromSpriteCatch, ten)
		print("PLUG|tao|" .. ten .. "|" .. tostring(ok) .. "|" .. tostring(a))
		if ok then return a end
		return nil
	end

	print("PLUG|bat-dau")
	pcall(function() loadLevelFile("conf/UI_Main_960_640.xgg") end)

	-- Node cha THUONG: node CO SAN cua bo cuc Main (khong tao moi — create() giet
	-- ca tien trinh tren ban dich ARM). Thu lan luot, in ra node nao dung duoc.
	local ung_vien = {"spMainUITheme_halloween_4", "ndMain", "ndTop", "ndBottom"}
	local cha = nil
	for _, nm in ipairs(ung_vien) do
		local n = rawget(_G, nm)
		print("PLUG|ung-vien|" .. nm .. "|" .. tostring(n))
		if n ~= nil and cha == nil then cha = n end
	end
	print("PLUG|cha|" .. tostring(cha))

	local spA = hinh("Gashapon")
	if spA == nil or cha == nil then
		print("PLUG|het")
		return
	end

	-- Phai nam TRONG CAY thi dong tac moi ap track (xem chu thich cua
	-- tools/verify_plug.gd); khong thi moi xuong o (0, 0) va phep do vo nghia.
	-- KHONG hoi so con: tra khoa do tren userdata lam ban dich ARM chet ngay
	-- (rang buoc ghi o docstring `emu_tags.py`).
	--
	-- LUOT 2: KHONG them vao cay nua. Luot 1 co them (`cha:addChild(spA)`) va do
	-- duoc dong tac KHONG ap: Star1 va Star5 ra y het nhau, trong khi
	-- `PlugIn_4_Hero` phai lech 2,8 theo y. `emu_cham.py` (muc D) do duoc dong tac
	-- CO ap va no khong them vao cay — nen thu bo buoc them.
	if rawget(_G, 'PLUG_TREO') then
		goi("gan-cha", function() cha:addChild(spA) return true end)
		goi("dat-0", function() spA:setPosition(0, 0) return spA:getPosition() end)
	else
		print("PLUG|khong-treo|de nguyen, khong addChild")
	end
	goi("play", function() return spA:_Lua_playAnimation("Star1") end)
	goi("ten-armature", function() return spA:_Lua_getArmatureName() end)

	-- Doi chung cho "dong tac da ap chua": xương Collision phai khac (0,0).
	goi("coll", function() return spA:_lua_CollisionSize() end)
	-- Doi chung 1: TOA DO XUONG Collision doc ra phai TRUNG voi ban dung Godot
	-- (tools/verify_plug.gd do duoc (-132, 196)). Khong trung thi hai ben dang
	-- o HAI TU THE khac nhau va moi so sanh tuyet doi la vo nghia.
	goi("bone-coll", function() return spA:_lua_getBonePosInNode("Collision", spA) end)

	local PLUG = {4, 5, 6, 7}

	local function doc(dich, nhan)
		if dich == nil then
			print("PLUG|BO-QUA|" .. nhan .. "|dich nil")
			return
		end
		local ra = {}
		for _, n in ipairs(PLUG) do
			local x, y = goi("pos|" .. nhan .. "|" .. n, function()
				return spA:_lua_getPlugInPositionInNode(n, dich) end)
			ra[n] = {x, y}
		end
		-- Tuyet doi (phu thuoc goc/vi tri cua cha nen chi de tham khao).
		for _, n in ipairs(PLUG) do
			if ra[n] ~= nil and ra[n][1] ~= nil then
				print("PLUG|ABS|" .. nhan .. "|" .. n .. "|" .. ra[n][1] .. "," .. ra[n][2])
			end
		end
		-- HIEU so voi diem gan 6 — day moi la phep do sach: hieu khong dinh gi
		-- toi goc, diem neo, hay chieu cao cua cha, chi con ti le.
		if ra[6] ~= nil and ra[6][1] ~= nil then
			for _, n in ipairs(PLUG) do
				if n ~= 6 and ra[n] ~= nil and ra[n][1] ~= nil then
					print("PLUG|HIEU|" .. nhan .. "|" .. n .. "|"
						.. (ra[n][1] - ra[6][1]) .. "," .. (ra[n][2] - ra[6][2]))
				end
			end
		else
			print("PLUG|BO-QUA|" .. nhan .. "|khong doc duoc diem gan 6")
		end
	end

	-- HAI phep, chi khac nhau o TINH CHAT cua dich. Ti so giua chung la ti le cua
	-- NGUON — xem chu thich dau file: dich la CHINH NGUON thi he so cua nguon
	-- triet tieu (`inv(nguon) * nguon:to_global(v)`), nen hieu ra dung so NEN;
	-- dich la node THUONG thi hieu ra `so NEN x ti le NGUON`. Ti so = ti le NGUON.
	--
	-- Day moi la phep tra loi cau hoi. Luot truoc lay dich la `Hoplite` (cung la
	-- doi tuong bat duoc, ti le 1,02) nen ti so ra 1,02 chi la ti le cua DICH —
	-- khong noi gi ve nguon. Phai lay dich la CHINH `spA`.
	doc(spA, "self")
	doc(cha, "thuong")

	-- Doi chieu QUYET DINH: chinh bon xuong ay doc qua duong XUONG
	-- (`_lua_getBonePosInNode`), cung dich, cung tu the. Hai duong ra HAI so khac
	-- nhau thi `_lua_getPlugInPositionInNode` KHONG phai la "vi tri cua xuong
	-- PlugIn_n" — va moi so sanh no voi khoa trong file la so sanh sai doi tuong.
	local TEN = {[4] = "PlugIn_4_Hero", [5] = "PlugIn_5_Word",
		[6] = "PlugIn_6_Light", [7] = "PlugIn_7_HeroName"}
	for _, n in ipairs(PLUG) do
		local x, y = goi("bone|" .. n, function()
			return spA:_lua_getBonePosInNode(TEN[n], cha) end)
		if x ~= nil then
			print("PLUG|BONE|" .. n .. "|" .. x .. "," .. y)
		end
	end

	doc(hinh("Hoplite"), "armature")

	-- Doi chung 2 (QUYET DINH): `PlugIn_4_Hero` la xuong DUY NHAT trong Gashapon
	-- doi giua Star1 (y = 115,54) va Star5 (y = 112,74). Doc no sau CA HAI dong
	-- tac: doi thi dong tac CO ap; khong doi thi bon so tuyet doi o tren la TU THE
	-- NGHI chu khong phai cua Star1, va phep do tuyet doi KHONG noi len gi (con
	-- phep ti so thi khong phu thuoc tu the nen van dung).
	goi("play-Star5", function() return spA:_Lua_playAnimation("Star5") end)
	goi("bone-plug4-sau-Star5", function()
		return spA:_lua_getBonePosInNode("PlugIn_4_Hero", cha) end)
	doc(cha, "Star5")

	print("PLUG|het")
end

do return end

sngHttMgr:createInstance()

if bDirectBattle then
	g_CUIGame:Test()
elseif IsAppIndependentMode() then
    -- 单独运行战斗
	g_CUIGame:SetRunInServer(true)
else
	-- 开启游戏
--[[
	g_CSceneManager:RepaleceSceneWithoutLoading("Logo")
	g_CUILoadingGame:SetRunGameDelayTime(1) -- 在logo处停留3秒		
	g_CTimerManager:AddMission("CUILoadingGame_RunGameTimer", g_CUILoadingGame, "RunGameTimer")
	do return end
--]]
	local szPlatform = LGG_GetPlatformString()
	
	--android下 开启dump记录
	if szPlatform == "android" then
		LGG_SetDumpInfo(true)
	end
	
	if szPlatform == "windows" then
		-- 直接运行游戏
		g_CUILoadingGame:RunGame()
	else
		
		g_CSceneManager:RepaleceSceneWithoutLoading("Logo")
		
		g_CUILoadingGame:SetRunGameDelayTime(1) -- 在logo处停留3秒		
		g_CTimerManager:AddMission("CUILoadingGame_RunGameTimer", g_CUILoadingGame, "RunGameTimer")
	end
	
end	


-- 西瓜SDK基础版
local pckName = ProtocolUser_shared():getPackageName()
-- sngUtil_log("hua test: getPackageName pckName=" .. tostring(pckName))
if pckName and (pckName == "com.wh.dachui" or pckName == DEFAULT_XGSDK_PACKAGE_NAME ) then
	-- sngUtil_log("hua test: xgsdk base version, set to local")
	SDK_Mgr.strSDK_Name = USER_GLOBAL.SDK_NAME.LOCAL
	SDK_Mgr.nUserType = nil		
end


-- 广点通处理
if g_GDTManager then
  g_GDTManager:SendHttpUrl()
end

--[[
--debugSngTest
require("user.Public.debug_sngTest")
debugSngTest();
--]]

KDebug.PrintDebug("game.lua 7")

--2017/2/6 by rong34 begin 清除lua stack
do
	if S_CCDirector ~= nil and S_CCDirector.setIsCleanLuaStack ~= nil then
		S_CCDirector:setIsCleanLuaStack(true)
	end
end
--2017/2/6 by rong34 end

--2017/3/16 by rong34 begin	启动垃圾回收
sngAutoGarbage:start()
--2017/3/16 by rong34 end
