// be_sdk6.js — bản bẻ cổng Kull SDK, nhúng frida-java-bridge 6.3.9.
//
// Vì sao phải hạ bridge xuống 6.x: bản 7.x ném
//   "Unable to find fields in java/lang/Thread"
// khi dò ART của Android 6 (API 23, qemu armv7); 6.x còn đường dò cũ nên chạy.
//
// Biên dịch:  cd frida/js && npx frida-compile be_sdk6.js -o ../be_sdk_bundle6.js

const Java = require('frida-java-bridge');

const TEN = '[be_sdk]';

Java.perform(function () {
  // 1) đóng panel SDK đang phủ lên activity Cocos
  var n = 0;
  try {
    Java.choose('com.kull.sdk.p003ui.activities.KullSDKActivity', {
      onMatch: function (inst) {
        n++;
        try { inst.finish(); } catch (e) { console.log(TEN + ' finish loi: ' + e); }
      },
      onComplete: function () { console.log(TEN + ' da finish ' + n + ' activity SDK'); }
    });
  } catch (e) {
    console.log(TEN + ' khong thay KullSDKActivity: ' + e);
  }

  // 2) giả đáp án đăng nhập, bắn về phía engine
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
