// be_sdk_nhe.js — bản GỌN của be_sdk6_shim.js.
//
// Lượt trước dùng `Java.choose` để đóng KullSDKActivity; trên AVD ARM
// (Android 6, ART cũ) phép quét heap ấy rất nặng: máy đã ANR ngay sau đó
// (system_server SIG 3, activity manager treo). Ở đây chỉ gọi đúng một hàm
// tĩnh, rồi để adb đưa activity Cocos lên trước.
//
// Biên dịch: cd frida/js && npx frida-compile be_sdk_nhe.js -o ../be_sdk_nhe_bundle.js

function exportByName(moduleName, name) {
  const global = Module.findGlobalExportByName;
  if (moduleName === null || moduleName === undefined) return global(name);
  try {
    const m = Process.getModuleByName(moduleName);
    const a = m.findExportByName(name);
    if (a !== null) return a;
  } catch (e) {}
  return global(name);
}
if (typeof Module.getExportByName !== 'function') Module.getExportByName = exportByName;
if (typeof Module.findExportByName !== 'function') Module.findExportByName = exportByName;

const Java = require('frida-java-bridge');

const TEN = '[be_sdk]';

Java.perform(function () {
  try {
    var JSONObject = Java.use('org.json.JSONObject');
    var j = JSONObject.$new(JSON.stringify({
      UserID: '100001',
      UserName: 'offline',
      AccessToken: 'offline-token',
      SessionID: 'offline-session'
    }));
    var Userxsdk = Java.use('org.cocos2dx.plugin.Userxsdk');
    Userxsdk.onLoginSuccessCallback(0, j);
    console.log(TEN + ' da goi onLoginSuccessCallback(0, ...)');
  } catch (e) {
    console.log(TEN + ' loi goi callback: ' + e);
  }

  // cũng chặn luôn lượt gọi sau, phòng khi native hỏi lại
  try {
    var AppSDK = Java.use('com.kull.sdk.AppSDK');
    AppSDK.login.implementation = function () {
      console.log(TEN + ' chan AppSDK.login -> gia lap thanh cong');
      Userxsdk.onLoginSuccessCallback(0, j);
    };
  } catch (e) {
    console.log(TEN + ' khong hook duoc AppSDK.login: ' + e);
  }

  try { console.log(TEN + ' Android SDK=' + Java.androidVersion); } catch (e) {}
});
