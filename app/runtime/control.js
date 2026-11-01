'use strict';
// Sets the CleanYourTV-compatible volume OSD preference and starts/stops this app's audio service.
var cp = require('child_process');
var fs = require('fs');
var DATA = '/media/developer/volume-bar-theme';
var HOOK = '/var/lib/webosbrew/init.d/91-volume-bar-theme';
var PID = '/tmp/volume-bar-theme.pid';
var APP = '/media/developer/apps/usr/palm/applications/com.fingers986.volumebartheme';
var OSD = 'com.webos.surfacemanager.volumeOSD';
function luna(uri, payload, callback) {
  var command = 'luna-send -n 1 -w 5000 -f "$1" "$2" </dev/null';
  cp.execFile('/bin/sh', ['-c', command, 'sh', uri, JSON.stringify(payload || {})], function (error, output) {
    if (error) return callback(error);
    try { callback(null, JSON.parse(output)); } catch (e) { callback(e); }
  });
}
function finish(error) { if (error) { console.error(error.message); process.exit(1); } process.exit(0); }
if (process.argv[2] === 'enable') {
  var theme = process.argv[3] === 'capsule' || process.argv[3] === 'dial' ? process.argv[3] : 'pill';
  try {
    if (!fs.existsSync(DATA)) fs.mkdirSync(DATA);
    fs.writeFileSync(DATA + '/settings.json', JSON.stringify({ theme: theme }));
    if (!fs.existsSync('/var/lib/webosbrew/init.d')) fs.mkdirSync('/var/lib/webosbrew/init.d');
  } catch (e) { return finish(e); }
  luna('luna://com.webos.service.config/getConfigs', { configNames: [OSD] }, function (error, result) {
    if (error || !result || !result.returnValue) return finish(error || new Error('Cannot read LG volume OSD setting'));
    var original = result.configs && result.configs[OSD];
    if (typeof original !== 'boolean') return finish(new Error('This TV does not expose the LG volume OSD setting'));
    try { if (!fs.existsSync(DATA + '/volume-osd.orig')) fs.writeFileSync(DATA + '/volume-osd.orig', String(original)); } catch (e) { return finish(e); }
    luna('luna://com.webos.service.config/setConfigs', { configs: (function () { var x = {}; x[OSD] = false; return x; }()) }, function (e, response) {
      if (e || !response || !response.returnValue) return finish(e || new Error('Cannot hide LG volume bar'));
      try { if (!fs.existsSync(HOOK)) fs.symlinkSync(APP + '/runtime/91-volume-bar-theme', HOOK); } catch (x) { if (x.code !== 'EEXIST') return finish(x); }
      cp.execFile('/bin/sh', [HOOK], finish);
    });
  });
} else {
  try { fs.unlinkSync(HOOK); } catch (e) {}
  try { var pid = Number(fs.readFileSync(PID, 'utf8')); if (pid > 1) process.kill(pid, 'SIGTERM'); } catch (e) {}
  var saved = '';
  try { saved = fs.readFileSync(DATA + '/volume-osd.orig', 'utf8').trim(); } catch (e) {}
  if (saved !== 'true' && saved !== 'false') return finish();
  var restored = {}; restored[OSD] = saved === 'true';
  luna('luna://com.webos.service.config/setConfigs', { configs: restored }, function (error, response) {
    if (error || !response || !response.returnValue) return finish(error || new Error('Cannot restore LG volume bar'));
    try { fs.unlinkSync(DATA + '/volume-osd.orig'); fs.unlinkSync(PID); } catch (e) {}
    finish();
  });
}
