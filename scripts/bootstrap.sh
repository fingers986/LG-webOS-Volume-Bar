#!/bin/sh
# Install only the volume bar service. LG Home is never mounted, changed, or restarted by a Home takeover.
export PATH=/usr/bin:/usr/sbin:/bin:/sbin:$PATH
S=$(cd "$(dirname "$0")" && pwd)
D=/media/developer/cleanyourtv
INITD=/var/lib/webosbrew/init.d
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
if [ -f "$APP" ]; then
  want=$(node "$S/helper/tvprofile.js" get notifyWindow --sdk "$sdk" 2>/dev/null)
  case "$want" in topui|overlay) sed -i "s/\"defaultWindowType\":\"[^\"]*\"/\"defaultWindowType\":\"$want\"/" "$APP" ;; esac
fi
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
say 'volume bar service installed; LG Home remains unchanged'
