// be_sdk6_shim.js — bẻ cổng Kull SDK, chạy được trên Frida 17.
//
// Hai lý do phải có tệp này thay vì gọi frida-java-bridge trần:
//   1. Frida 17 đã tách bridge khỏi agent (typeof Java === 'undefined')
//      ⇒ phải nhúng bằng frida-compile.
//   2. Frida 17 BỎ `Module.getExportByName` / `Module.findExportByName`
//      ⇒ bridge 6.x ném "TypeError: not a function" ở android.js:1274
//      (getAndroidSystemProperty). Shim dưới đây ánh xạ lại sang API mới.
//
// Biên dịch: cd frida/js && npx frida-compile be_sdk6_shim.js -o ../be_sdk_bundle6.js

function exportByName(moduleName, name) {
  const global = Module.findGlobalExportByName;
  if (moduleName === null || moduleName === undefined) {
    return global(name);
  }
  try {
    const m = Process.getModuleByName(moduleName);
    const a = m.findExportByName(name);
    if (a !== null) return a;
  } catch (e) { /* module chưa nạp */ }
  return global(name);
}

if (typeof Module.getExportByName !== 'function') {
  Module.getExportByName = exportByName;
}
if (typeof Module.findExportByName !== 'function') {
  Module.findExportByName = exportByName;
}

const Java = require('frida-java-bridge');

const TEN = '[be_sdk]';

Java.perform(function () {
  var n = 0;
  try {
    // Tên THẬT trong APK: jadx chèn tiền tố `pNNN` cho gói bị obfuscate
    // (`ui` -> `p003ui`, `bl` -> `p002bl`), nên đừng chép tên từ jadx.
    Java.choose('com.kull.sdk.ui.activities.KullSDKActivity', {
      onMatch: function (inst) {
        n++;
        try { inst.finish(); } catch (e) { console.log(TEN + ' finish loi: ' + e); }
      },
      onComplete: function () { console.log(TEN + ' da finish ' + n + ' activity SDK'); }
    });
  } catch (e) {
    console.log(TEN + ' khong thay KullSDKActivity: ' + e);
  }

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

  try { console.log(TEN + ' Android SDK=' + Java.androidVersion); } catch (e) {}
});
