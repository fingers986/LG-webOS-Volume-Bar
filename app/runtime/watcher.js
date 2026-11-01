'use strict';
// Audio watcher follows CleanYourTV's helper/audio.js:
// master/getVolume provides mute/output; getArcVolume provides the ARC level.
var cp = require('child_process');
var fs = require('fs');
var APP_ID = 'com.fingers986.volumebartheme';
var SETTINGS = '/media/developer/volume-bar-theme/settings.json';
var master = null;
var arcVolume = null;
var lastShown = null;
var lastLaunchAt = 0;
var activeUntil = 0;
var arcFailed = false;
var polling = false;
var stopping = false;
var audioProcess = null;
var arcTimer = null;
var launchTimer = null;

function log(message) {
  try { fs.appendFileSync('/tmp/volume-bar-theme.log', new Date().toISOString() + ' ' + message + '\n'); } catch (e) {}
}
function selectedTheme() {
  try {
    var value = JSON.parse(fs.readFileSync(SETTINGS, 'utf8')).theme;
    return value === 'capsule' || value === 'dial' ? value : 'pill';
  } catch (e) { return 'pill'; }
}
function showVolume() {
  if (!master || typeof master.volume !== 'number') return;
  var volume = master.soundOutput === 'external_arc' ? arcVolume : master.volume;
  if (volume === null || typeof volume !== 'number') return;
  var key = String(volume) + ':' + !!master.muteStatus + ':' + master.soundOutput;
  if (key === lastShown) return;
  var now = Date.now();
  if (now - lastLaunchAt < 350) {
    if (!launchTimer) launchTimer = setTimeout(function () { launchTimer = null; showVolume(); }, 350 - (now - lastLaunchAt));
    return;
  }
  lastShown = key;
  lastLaunchAt = now;
  var params = { volume: volume, mute: !!master.muteStatus, output: master.soundOutput, theme: selectedTheme() };
  cp.execFile('/usr/bin/luna-send', ['-n', '1', 'luna://com.webos.applicationManager/launch', JSON.stringify({ id: APP_ID, params: params })], function (error) {
    if (error) log('volume overlay launch failed: ' + error.message);
  });
}

// The pty wrapper matches CleanYourTV's helper/audio.js on webOS, where the
// Luna response is emitted through a pseudo-terminal rather than plain stdout.
function pollArc() {
  arcTimer = null;
  if (stopping || polling || !master || master.soundOutput !== 'external_arc') {
    if (!stopping) arcTimer = setTimeout(pollArc, 1000);
    return;
  }
  polling = true;
  var previous = arcVolume;
  var child;
  try {
    child = cp.spawn('script', ['-q', '-c', "luna-send -n 1 'luna://com.webos.service.eim/getArcVolume' '{}'", '/dev/null']);
  } catch (e) {
    polling = false;
    arcTimer = setTimeout(pollArc, 1000);
    return;
  }
  var output = '';
  var done = false;
  var timeout = setTimeout(function () {
    try { child.kill(); } catch (e) {}
    finish(new Error('ARC volume request timed out'));
  }, 1500);
  function finish(error) {
    if (done) return;
    done = true;
    clearTimeout(timeout);
    polling = false;
    if (!stopping && !error) {
      try {
        var match = output.match(/\{[^]*\}/);
        var response = match && JSON.parse(match[0]);
        var value = response && response.Volume;
        if (typeof value !== 'number' || !isFinite(value) || value < 0 || value > 100) throw new Error('invalid ARC volume response');
        arcFailed = false;
        arcVolume = value;
        if (value !== previous) {
          master.volume = value;
          showVolume();
          activeUntil = Date.now() + 2500;
        }
      } catch (e) { error = e; }
    }
    if (error && !arcFailed) log('ARC volume unavailable: ' + error.message);
    arcFailed = !!error;
    if (!stopping) arcTimer = setTimeout(pollArc, Date.now() < activeUntil ? 150 : 1000);
  }
  child.stdout.on('data', function (data) { output += data.toString('utf8'); });
  child.on('error', finish);
  child.on('close', function (code) { finish(code ? new Error('ARC volume request exited ' + code) : null); });
}

function subscribeAudio(delay) {
  if (stopping) return;
  var retryDelay = delay || 3000;
  try { audioProcess = cp.spawn('luna-send', ['-i', 'luna://com.webos.service.audio/master/getVolume', '{"subscribe":true}']); }
  catch (e) {
    setTimeout(function () { subscribeAudio(Math.min(retryDelay * 2, 60000)); }, retryDelay);
    return;
  }
  var buffer = '';
  var retry = false;
  audioProcess.stdout.on('data', function (chunk) {
    buffer += chunk.toString('utf8');
    var lines = buffer.split('\n');
    buffer = lines.pop();
    lines.forEach(function (line) {
      try {
        var response = JSON.parse(line.trim());
        var value = response.volumeStatus || response;
        if (!value || typeof value.muteStatus !== 'boolean' && typeof value.volume !== 'number') return;
        var oldOutput = master && master.soundOutput;
        var nextVolume = typeof value.volume === 'number' ? value.volume : (master ? master.volume : 0);
        var changed = !master || master.muteStatus !== value.muteStatus || master.soundOutput !== value.soundOutput || master.volume !== nextVolume;
        master = {
          muteStatus: typeof value.muteStatus === 'boolean' ? value.muteStatus : !!(master && master.muteStatus),
          soundOutput: value.soundOutput || oldOutput || 'tv_speaker',
          volume: nextVolume
        };
        if (master.soundOutput === 'external_arc') {
          if (arcVolume !== null) master.volume = arcVolume;
          if (changed) {
            activeUntil = Date.now() + 2500;
            if (arcTimer) clearTimeout(arcTimer);
            pollArc();
          }
        }
        if (changed && (master.soundOutput !== 'external_arc' || arcVolume !== null)) showVolume();
      } catch (e) {}
    });
  });
  function restart() {
    if (retry || stopping) return;
    retry = true;
    setTimeout(function () { subscribeAudio(Math.min(retryDelay * 2, 60000)); }, retryDelay);
  }
  audioProcess.on('error', restart);
  audioProcess.on('close', restart);
}
function stop() {
  stopping = true;
  if (arcTimer) clearTimeout(arcTimer);
  if (launchTimer) clearTimeout(launchTimer);
  if (audioProcess) try { audioProcess.kill(); } catch (e) {}
  process.exit(0);
}
process.on('SIGTERM', stop);
process.on('SIGINT', stop);
log('CleanYourTV-based volume theme watcher started');
subscribeAudio(3000);
pollArc();
