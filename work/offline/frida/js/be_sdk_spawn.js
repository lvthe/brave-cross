// be_sdk_spawn.js — nạp NGAY LÚC SPAWN: chặn cổng Kull SDK trước khi nó mở.
//
// Các lượt trước gắn script vào tiến trình ĐANG CHẠY nên panel SDK đã hiện ra
// rồi; muốn đóng nó phải quét heap (làm ANR máy ảo) hoặc móc onResume (không
// bắn lại). Spawn + hook `Userxsdk.login` thì panel không bao giờ được mở:
//
//   libgame.so --JNI--> Userxsdk.login()   [bị chặn]
//                        -> Userxsdk.onLoginSuccessCallback(0, fake)
//                        -> UserWrapper.onActionResult(...) -> Lua -> lớp offline
//
// Biên dịch: cd frida/js && npx frida-compile be_sdk_spawn.js -o ../be_sdk_spawn_bundle.js

function exportByName(moduleName, name) {
  const global = Module.findGlobalExportByName;
  if (moduleName === null || moduleName === undefined) return global(name);
  try { const m = Process.getModuleByName(moduleName); const a = m.findExportByName(name); if (a !== null) return a; } catch (e) {}
  return global(name);
}
if (typeof Module.getExportByName !== 'function') Module.getExportByName = exportByName;
if (typeof Module.findExportByName !== 'function') Module.findExportByName = exportByName;

const Java = require('frida-java-bridge');
const TEN = '[be_sdk]';

Java.perform(function () {
  const JSONObject = Java.use('org.json.JSONObject');
  const Userxsdk = Java.use('org.cocos2dx.plugin.Userxsdk');

  Userxsdk.login.implementation = function () {
    console.log(TEN + ' Userxsdk.login -> gia lap dang nhap thanh cong');
    const j = JSONObject.$new(JSON.stringify({
      UserID: '100001',
      UserName: 'offline',
      AccessToken: 'offline-token',
      SessionID: 'offline-session'
    }));
    Userxsdk.onLoginSuccessCallback(0, j);
  };

  // hai cửa sau, phòng khi native gọi thẳng Java mà không qua plugin
  try {
    const AppSDK = Java.use('com.kull.sdk.AppSDK');
    AppSDK.login.implementation = function () {
      console.log(TEN + ' chan AppSDK.login (khong mo panel SDK)');
      const j = JSONObject.$new(JSON.stringify({ UserID: '100001', UserName: 'offline', AccessToken: 'offline-token' }));
      Userxsdk.onLoginSuccessCallback(0, j);
    };
  } catch (e) { console.log(TEN + ' khong hook AppSDK.login: ' + e); }

  console.log(TEN + ' da gan hook spawn, SDK=' + Java.androidVersion);
});
