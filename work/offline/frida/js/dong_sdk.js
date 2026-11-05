// dong_sdk.js — đóng KullSDKActivity mà KHÔNG quét heap.
//
// `Java.choose` quét cả heap để tìm thể hiện ⇒ trên AVD ARM hệ này rất nặng
// (đã một lần làm system_server ANR). Ở đây đi qua bảng hoạt động của
// ActivityThread: `mActivities` là ArrayMap<IBinder, ActivityClientRecord>,
// mỗi bản ghi có trường `activity`.
//
// Biên dịch: cd frida/js && npx frida-compile dong_sdk.js -o ../dong_sdk_bundle.js

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

const TEN = '[dong_sdk]';

Java.perform(function () {
  try {
    const ActivityThread = Java.use('android.app.ActivityThread');
    const at = ActivityThread.currentActivityThread();
    const map = at.mActivities.value;
    const n = map.size();
    console.log(TEN + ' so hoat dong = ' + n);
    for (let i = 0; i < n; i++) {
      const rec = map.valueAt(i);
      let act;
      try { act = rec.activity.value; } catch (e) { console.log(TEN + ' bo qua #' + i + ': ' + e); continue; }
      const ten = act.getClass().getName();
      console.log(TEN + ' #' + i + ' = ' + ten + ' finishing=' + act.isFinishing());
      if (ten === 'com.kull.sdk.ui.activities.KullSDKActivity') {
        try {
          act.finish();
          console.log(TEN + ' da goi finish() cho ' + ten);
        } catch (e) {
          console.log(TEN + ' finish loi: ' + e);
        }
      }
    }
  } catch (e) {
    console.log(TEN + ' loi: ' + e + '\n' + (e.stack || ''));
  }
});
