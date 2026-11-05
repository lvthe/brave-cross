// dong_sdk2.js — đóng KullSDKActivity bằng móc vòng đời.
//
// `Java.choose` (quét heap) quá nặng trên AVD ARM này; đọc `mActivities` thì
// bridge 6 không lộ trường `activity`. Cách nhẹ: móc `onResume` — khi activity
// resume lại (bấm HOME rồi mở lại task) thì chính nó gọi finish().
//
// Biên dịch: cd frida/js && npx frida-compile dong_sdk2.js -o ../dong_sdk2_bundle.js

function exportByName(moduleName, name) {
  const global = Module.findGlobalExportByName;
  if (moduleName === null || moduleName === undefined) return global(name);
  try { const m = Process.getModuleByName(moduleName); const a = m.findExportByName(name); if (a !== null) return a; } catch (e) {}
  return global(name);
}
if (typeof Module.getExportByName !== 'function') Module.getExportByName = exportByName;
if (typeof Module.findExportByName !== 'function') Module.findExportByName = exportByName;

const Java = require('frida-java-bridge');
const TEN = '[dong_sdk]';

Java.perform(function () {
  try {
    const K = Java.use('com.kull.sdk.ui.activities.KullSDKActivity');
    K.onResume.implementation = function () {
      console.log(TEN + ' onResume -> finish()');
      this.finish();
    };
    console.log(TEN + ' da moc onResume');
  } catch (e) {
    console.log(TEN + ' moc loi: ' + e);
  }
});
