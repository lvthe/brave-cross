// be_sdk.ts — nguồn của bundle bẻ cổng đăng nhập Kull SDK.
//
// Frida 17 đã BỎ bridge Java khỏi agent (typeof Java === 'undefined'), nên
// phải nhúng frida-java-bridge rồi biên dịch:
//
//     cd frida/js && npx frida-compile be_sdk.ts -o ../be_sdk_bundle.js
//
// Đường thật (jadx, out/VN/jadx):
//   KullSDKActivity --HTTP--> apisdk.kul.vn   (chết ⇒ panel đăng nhập treo)
//   AppSDK.callBackLogin.callBackFinishWithResult(result)
//     -> SDKHandler$1$1.setMyTaskComplete  ->  Userxsdk.onLoginSuccessCallback(0, rJson)
//        -> m_strSectionID = base64(json);  UserWrapper.onActionResult(..., 0, session)
//           -> Lua G_Login:SdkLogin / ChannelLogin  ->  lớp offline chặn
//
// Nên chỉ cần gọi thẳng onLoginSuccessCallback là đủ cho phần sau.

import Java from 'frida-java-bridge';

const TEN = '[be_sdk]';

Java.perform(() => {
  // 1) đóng panel SDK đang phủ lên activity Cocos
  let n = 0;
  try {
    Java.choose('com.kull.sdk.p003ui.activities.KullSDKActivity', {
      onMatch(inst: any) {
        n++;
        try {
          inst.finish();
        } catch (e) {
          console.log(`${TEN} finish loi: ${e}`);
        }
      },
      onComplete() {
        console.log(`${TEN} da finish ${n} activity SDK`);
      },
    });
  } catch (e) {
    console.log(`${TEN} khong thay KullSDKActivity: ${e}`);
  }

  // 2) giả đáp án đăng nhập, bắn về phía engine
  try {
    const JSONObject = Java.use('org.json.JSONObject');
    const j = JSONObject.$new(
      JSON.stringify({
        UserID: '100001',
        UserName: 'offline',
        AccessToken: 'offline-token',
        SessionID: 'offline-session',
      }),
    );
    const Userxsdk = Java.use('org.cocos2dx.plugin.Userxsdk');
    Userxsdk.onLoginSuccessCallback(0, j);
    console.log(`${TEN} da goi onLoginSuccessCallback(0, ...)`);
  } catch (e) {
    console.log(`${TEN} loi goi callback: ${e}`);
  }

  // 3) báo trạng thái để biết bridge có sống
  try {
    console.log(`${TEN} Android SDK=${Java.androidVersion}`);
  } catch (e) {
    console.log(`${TEN} khong doc duoc androidVersion: ${e}`);
  }
});
