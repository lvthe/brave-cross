// _do_hoat_dong.js — in hình dạng bản ghi mActivities để biết tên trường.
function exportByName(moduleName, name) {
  const global = Module.findGlobalExportByName;
  if (moduleName === null || moduleName === undefined) return global(name);
  try { const m = Process.getModuleByName(moduleName); const a = m.findExportByName(name); if (a !== null) return a; } catch (e) {}
  return global(name);
}
if (typeof Module.getExportByName !== 'function') Module.getExportByName = exportByName;
if (typeof Module.findExportByName !== 'function') Module.findExportByName = exportByName;

const Java = require('frida-java-bridge');
const TEN = '[do_hd]';

Java.perform(function () {
  const ActivityThread = Java.use('android.app.ActivityThread');
  const at = ActivityThread.currentActivityThread();
  const map = at.mActivities.value;
  console.log(TEN + ' n=' + map.size());
  for (let i = 0; i < map.size(); i++) {
    const rec = map.valueAt(i);
    console.log(TEN + ' rec class = ' + rec.$className);
    const keys = Object.keys(rec).filter(k => !k.startsWith('$'));
    console.log(TEN + ' truong = ' + keys.join(', '));
    for (const k of keys) {
      if (/act|token|paused/i.test(k)) {
        try { console.log(TEN + '   ' + k + ' = ' + rec[k].value); }
        catch (e) { console.log(TEN + '   ' + k + ' -> loi: ' + e); }
      }
    }
  }
});
