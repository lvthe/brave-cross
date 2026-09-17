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



-- === CHEN DE DO: xuong cua armature (emu_xuong.py sinh ra) ===
do
	local function goi(ten, f)
		print("XUONG|goi|" .. ten)
		local ok, a, b = pcall(f)
		print("XUONG|xong|" .. ten .. "|" .. tostring(ok) .. "|"
			.. tostring(a) .. "," .. tostring(b))
		return a, b
	end

	local function hinh(ten)
		local ok, a = pcall(getSpriteFromSpriteCatch, ten)
		print("XUONG|tao|" .. ten .. "|" .. tostring(ok) .. "|" .. tostring(a))
		if ok then return a end
		return nil
	end

	-- Bon so cho MOT xuong: pos/rect voi tham so 2 la chinh armature, roi pos/rect
	-- bo trong tham so 2. In ten xuong o CA HAI dau de doc ra ngay dong nao ung
	-- voi xuong nao.
	local function do_xuong(tien, n, xuong)
		if n == nil then return end
		goi(tien .. "|pos-self|" .. xuong,
			function() return n:_lua_getBonePosInNode(xuong, n) end)
		goi(tien .. "|pos-nil|" .. xuong,
			function() return n:_lua_getBonePosInNode(xuong) end)
		goi(tien .. "|rect-self|" .. xuong,
			function() return n:_lua_getBoneRectInNode(xuong, n) end)
		goi(tien .. "|rect-nil|" .. xuong,
			function() return n:_lua_getBoneRectInNode(xuong) end)
	end

	print("XUONG|bat-dau")
	print("XUONG|co-ham|" .. tostring(type(getSpriteFromSpriteCatch)))
	pcall(function() loadLevelFile("conf/UI_Main_960_640.xgg") end)

	-- (A) Tung rig: moc `_lua_CollisionSize` truoc, roi bon xuong.
	for _, t in ipairs({"ZhangLiangBao", "ElephantSoldier", "Hoplite",
			"BaiHuZi", "YuJin", "Gashapon"}) do
		local n = hinh(t)
		if n ~= nil then
			goi("A|" .. t .. "|ten", function() return n:_Lua_getArmatureName() end)
			goi("A|" .. t .. "|coll", function() return n:_lua_CollisionSize() end)
			goi("A|" .. t .. "|cs", function() return n:getContentSize() end)
			goi("A|" .. t .. "|pos", function() return n:getPosition() end)
			do_xuong("A|" .. t, n, "Collision")
			do_xuong("A|" .. t, n, "Collision_1")
			do_xuong("A|" .. t, n, "Head")
			do_xuong("A|" .. t, n, "KhongCoXuongNay")
		end
	end

	-- (B) Ca "armature khong co xuong Collision" — DaQuZhanShi.
	local d = hinh("DaQuZhanShi")
	if d ~= nil then
		goi("B|DaQuZhanShi|coll", function() return d:_lua_CollisionSize() end)
		do_xuong("B|DaQuZhanShi", d, "Collision")
		do_xuong("B|DaQuZhanShi", d, "Head")
	end

	-- (D) BA RIG MA HAI NGUON KHUNG KHONG THONG NHAT. Xuong `Collision` cua mot
	-- rig mang anh `_res-44`; khung cua anh ay doc duoc o HAI cho:
	--   * ban ghi sprite trong .xml  (bang ChamRef dang dung)
	--   * `sourceSize` cua ban ghi plist (13 float thu 12,13 — o +0x34/+0x38)
	-- Voi 256 anh `_res-44` thi hai nguon BANG NHAU o 253 muc, lech o DUNG BA:
	--   BatFlight 2x2 | DragonFlight 2x2 | LvBuZhanShi 1x1   (.xml)
	--   BatFlight 1x1 | DragonFlight 1x1 | LvBuZhanShi 0x0   (plist sourceSize)
	-- Kep theo `sx` (co 50-160) thi hai gia tri cach nhau mot khoang thay duoc,
	-- nen `_lua_CollisionSize` cua ba rig nay noi thang ra nguon nao dung.
	-- (Va ca ba rig nay CHUA he duoc do lan nao.)
	-- `LvBuZhanShi_A2` va `LvBuZhanShi_Weapon1` la hai bien the CUNG dung anh ay:
	-- bang cu (theo .xml) ghi 1x1 nen co mat trong bang; theo `sourceSize` thi
	-- anh ay 0x0 nen hop bang khong. Hai dong duoi day noi thang ra so nao.
	for _, t in ipairs({"BatFlight", "DragonFlight", "LvBuZhanShi",
			"LvBuZhanShi_A2", "LvBuZhanShi_Weapon1"}) do
		local n3 = hinh(t)
		if n3 ~= nil then
			goi("D|" .. t .. "|coll", function() return n3:_lua_CollisionSize() end)
			do_xuong("D|" .. t, n3, "Collision")
			do_xuong("D|" .. t, n3, "Head")
		end
	end

	-- (C) PHEP DOI KHONG GIAN. Tham so 2 la mot node KHAC voi chinh armature. Da do
	-- duoc: hai vi tri khac nhau cua node dich cho ra hai ket qua KHAC nhau, va
	-- hieu hai ket qua DUNG bang hieu hai vi tri nhan -0,980393 — tuc phep doi CO
	-- that, va co mot he so ti le 1,02 o dau do. Ba phep do con lai o day:
	--   * node dich o goc toa do (0,0)  -> biet so hang tu do (neo).
	--   * doi node dich di hai lan khac nhau -> chot lai he so.
	--   * `_lua_getBoneRectInNode` co doi theo khong (bon so do truoc deu y nguyen).
	--
	-- CACH DO TI LE — DA THU VA DA BO: `getScale` lan `setScale` tren sprite lay
	-- tu `getSpriteFromSpriteCatch` deu GIET CA TIEN TRINH, va pcall KHONG do duoc
	-- loi native (do hai luot: dong cuoi truoc khi tat la `C|scale-n2`, roi
	-- `C|dat-n4-scale2`). Nen ti le khong doc duoc bang hai ham ay; muc (F) di
	-- duong khac — tim mot node KHONG phai armature de lam node dich.
	local n2 = hinh("ZhangLiangBao")
	local n3 = hinh("Hoplite")
	if n2 ~= nil and n3 ~= nil then
		goi("C|pos-self", function() return n2:_lua_getBonePosInNode("Collision", n2) end)
		goi("C|rect-self", function() return n2:_lua_getBoneRectInNode("Collision", n2) end)
		goi("C|vi-tri-n3-goc", function() return n3:getPosition() end)
		goi("C|pos-n3-goc", function() return n2:_lua_getBonePosInNode("Collision", n3) end)
		goi("C|rect-n3-goc", function() return n2:_lua_getBoneRectInNode("Collision", n3) end)
		goi("C|dat-n3-a", function() n3:setPosition(100, 50) return n3:getPosition() end)
		goi("C|pos-n3-a", function() return n2:_lua_getBonePosInNode("Collision", n3) end)
		goi("C|rect-n3-a", function() return n2:_lua_getBoneRectInNode("Collision", n3) end)
		goi("C|dat-n3-b", function() n3:setPosition(-40, 7) return n3:getPosition() end)
		goi("C|pos-n3-b", function() return n2:_lua_getBonePosInNode("Collision", n3) end)
	end

	-- (F) CO NODE NAO KHONG PHAI ARMATURE LAM NODE DICH DUOC KHONG? Cau hoi con
	-- lai cua muc C: he so 0,980393 thuoc node NGUON hay node DICH. Muon tach
	-- phai co mot node dich TI LE 1 — ma armature thi khong doc/doi duoc ti le
	-- (`getScale` lan `setScale` deu giet tien trinh). Vay truoc het xem trong
	-- `_G` co san node nao khong: bon man goc lay dich tu bien TOAN CUC
	-- (`cnHeroInfoUIAnimPos`, `CUIHeroInfoFightSoulUI.lua:3075`), va class node
	-- thuong thi co the tu tao. Muc nay chi DOC, khong goi native nao.
	local ten = {}
	for k, v in pairs(_G) do
		if type(k) == 'string' and (k:sub(1, 2) == 'cn' or k:find('Main') ~= nil) then
			ten[#ten + 1] = k .. '=' .. tostring(v)
		end
	end
	print("XUONG|F|toan-cuc|" .. table.concat(ten, ' ; '))
	print("XUONG|F|CCNode|" .. tostring(rawget(_G, 'CCNode')))
	print("XUONG|F|CCSprite|" .. tostring(rawget(_G, 'CCSprite')))
	print("XUONG|F|cnHeroInfoUIAnimPos|" .. tostring(rawget(_G, 'cnHeroInfoUIAnimPos')))

	-- (G) NODE DICH TI LE 1. Muc (F) cho thay bo cuc Main co san node COCOS
	-- THUONG (`spMainUITheme_halloween_4` la CCSprite, `btnMainContest` la nut,
	-- `g_MainUIScrollLayer` la CCScrollLayer) — khac han armature, va day moi la
	-- loai node ma bon man goc truyen vao tham so 2 (`cnHeroInfoUIAnimPos`).
	--
	-- KHONG doc duoc ti le: `getScale` GIET CA TIEN TRINH o CA class Cocos thuong
	-- chu khong rieng armature (do duoc: dong cuoi truoc khi tat la `G|scale`,
	-- goi tren mot CCSprite). `setScale` cung vay. Nhung khong can doc: do DICH
	-- CHO hai lan, hieu hai ket qua chia cho hieu hai vi tri ra ngay 1/ti_le cua
	-- node dich. Voi node dich la armature thi so do ra 1/1,02; con day thi:
	--   hieu = -(140, 43)        -> node dich ti le 1, va he so 1,02 thuoc NGUON
	--   hieu = -(137,26, 42,16)  -> ti le 1,02 thuoc chinh node DICH (armature)
	local nguon = hinh("ZhangLiangBao")
	local dich = rawget(_G, 'spMainUITheme_halloween_4')
	if nguon ~= nil and dich ~= nil then
		goi("G|vi-tri", function() return dich:getPosition() end)
		goi("G|pos-goc", function() return nguon:_lua_getBonePosInNode("Collision", dich) end)
		goi("G|rect-goc", function() return nguon:_lua_getBoneRectInNode("Collision", dich) end)
		goi("G|dat-a", function() dich:setPosition(100, 50) return dich:getPosition() end)
		goi("G|pos-a", function() return nguon:_lua_getBonePosInNode("Collision", dich) end)
		goi("G|rect-a", function() return nguon:_lua_getBoneRectInNode("Collision", dich) end)
		goi("G|dat-b", function() dich:setPosition(-40, 7) return dich:getPosition() end)
		goi("G|pos-b", function() return nguon:_lua_getBonePosInNode("Collision", dich) end)
	end

	print("XUONG|het")
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
