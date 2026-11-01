#!/bin/sh
# Install only the volume bar service. LG Home is never mounted, changed, or restarted by a Home takeover.
export PATH=/usr/bin:/usr/sbin:/bin:/sbin:$PATH
S=$(cd "$(dirname "$0")" && pwd)
D=/media/developer/cleanyourtv
INITD=/var/lib/webosbrew/init.d
FIRST_INSTALL=0
[ -f "$D/helper.js" ] || FIRST_INSTALL=1
say(){ echo "[cleanyourtv-volume] $*"; }
die(){ echo "[cleanyourtv-volume] ERROR: $*" >&2; exit 1; }
[ "$(id -u)" = 0 ] || die 'run as root'
command -v luna-send >/dev/null || die 'webOS luna-send not found'
[ -d "$INITD" ] || die 'Homebrew init.d not found; install Homebrew Channel first'
[ -w /media/developer ] || die '/media/developer is not writable'
command -v node >/dev/null || die 'Node.js not found'
[ -f "$S/helper/helper.js" ] && [ -f "$S/scripts/10-cleanyourtv-service" ] || die 'volume service files missing'
mkdir -p "$D/backup"
cp "$S/helper/"*.js "$D/"
cp "$S/scripts/10-cleanyourtv-service" "$S/scripts/volume-osd-restore.sh" "$S/scripts/after-sam.sh" "$D/"
info=$(luna-send -n 1 -w 5000 -f luna://com.webos.service.tv.systemproperty/getSystemInfo '{"keys":["sdkVersion"]}' </dev/null 2>/dev/null)
sdk=$(echo "$info" | sed -n 's/.*"sdkVersion": *"\([^"]*\)".*/\1/p')
APP="$S/../../applications/com.cleanyourtv.notify/appinfo.json"
REFRESH_SAM=$FIRST_INSTALL
[ -f "$APP" ] || die 'volume notification appinfo is missing'
want=$(node "$S/helper/tvprofile.js" get notifyWindow --sdk "$sdk" 2>/dev/null)
case "$want" in
  topui|overlay)
    before=$(sed -n 's/.*"defaultWindowType":"\([^"]*\)".*/\1/p' "$APP")
    if [ "$before" != "$want" ]; then
      sed -i "s/\"defaultWindowType\":\"[^\"]*\"/\"defaultWindowType\":\"$want\"/" "$APP"
      after=$(sed -n 's/.*"defaultWindowType":"\([^"]*\)".*/\1/p' "$APP")
      [ "$after" = "$want" ] || die "could not set notify window type to $want"
    fi
    ;;
  *) die "could not determine supported notify window type for SDK ${sdk:-unknown}" ;;
esac
[ -f "$D/config.json" ] || cp "$S/config.example.json" "$D/config.json"
chmod 700 "$D"; chmod 600 "$D/config.json"; chmod 700 "$D/10-cleanyourtv-service" "$D/volume-osd-restore.sh" "$D/after-sam.sh"
rm -f "$INITD/10-cleanyourtv-home" "$INITD/15-cleanyourtv-debloat"
ln -sf "$D/10-cleanyourtv-service" "$INITD/10-cleanyourtv-service"
pkill -f '[c]leanyourtv/helper.js' 2>/dev/null || true
nohup node "$D/helper.js" >/tmp/cleanyourtv-helper.log 2>&1 </dev/null &
for n in 1 2 3 4 5 6 7 8 9 10; do
  curl -fsS -m 2 http://127.0.0.1:8765/api/version >/dev/null 2>&1 && break
  sleep 1
done
curl -fsS -m 3 http://127.0.0.1:8765/api/version >/dev/null 2>&1 || die 'service did not start; check /tmp/cleanyourtv-helper.log'
appinfo=$(luna-send -n 1 -w 5000 -f luna://com.webos.applicationManager/getAppInfo '{"id":"com.cleanyourtv.notify"}' </dev/null 2>/dev/null)
case "$appinfo" in *'"returnValue": true'*) ;; *) REFRESH_SAM=1 ;; esac
registered=$(echo "$appinfo" | sed -n 's/.*"defaultWindowType" *: *"\([^"]*\)".*/\1/p')
[ -n "$registered" ] && [ "$registered" != "$want" ] && REFRESH_SAM=1
if [ "$REFRESH_SAM" = 1 ]; then
  say 'refreshing the volume overlay registration with SAM'
  systemctl restart sam || die 'could not restart SAM to register the volume overlay'
  sam_ready=0
  for n in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
    systemctl is-active sam >/dev/null 2>&1 && { sam_ready=1; break; }
    sleep 2
  done
  [ "$sam_ready" = 1 ] || die 'SAM did not become active after refreshing the volume overlay'
  sh "$D/after-sam.sh" </dev/null
  sleep 3
  luna-send -n 1 -w 10000 -f luna://com.webos.applicationManager/launch '{"id":"com.webos.app.home"}' </dev/null >/dev/null 2>&1 || say 'LG Home did not respond to relaunch; it remains the configured Home app'
fi
say 'volume bar service installed; LG Home remains unchanged'
