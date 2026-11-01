/* Restore the user's setup choices when setup is opened again. */
function setupDefaults() {
  rootExec('cat /media/developer/cleanyourtv/config.json 2>/dev/null').then(function (m) {
    var o = null;
    try {
      o = JSON.parse(execOut(m).out).options;
    } catch (x) {}
    if (!o) return;
    if (o.debloat === false) setup.debloat = false;
    if (o.inputKey === false) setup.inputKey = false;
    if (offline) {
      build();
      draw();
    }
  });
}
function execOut(m) {
  var o = {};
  try {
    o = JSON.parse(m);
  } catch (e) {}
  return { out: String(o.stdoutString || '') };
}
