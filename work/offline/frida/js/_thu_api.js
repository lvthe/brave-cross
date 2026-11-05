// _thu_api.js — dò vì sao bridge 6.x không thấy API Android.
const android = require('frida-java-bridge/lib/android');

try {
  console.log('[thu] getAndroidVersion = ' + android.getAndroidVersion());
} catch (e) {
  console.log('[thu] getAndroidVersion NEM: ' + e + '\n' + (e.stack || ''));
}

try {
  const api = android.getApi();
  console.log('[thu] getApi = ' + (api === null ? 'null' : JSON.stringify({flavor: api.flavor, module: api.module.name, path: api.module.path})));
} catch (e) {
  console.log('[thu] getApi NEM: ' + e + '\n' + (e.stack || ''));
}

const mods = Process.enumerateModules().filter(m => /^(libart|libdvm)\.so$/.test(m.name));
console.log('[thu] module vm: ' + JSON.stringify(mods.map(m => ({name: m.name, path: m.path, size: m.size}))));
