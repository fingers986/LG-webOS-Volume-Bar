#!/bin/sh
# Remove the volume bar service/apps and restore LG's saved volume OSD setting. LG Home is never modified.
export PATH=/usr/bin:/usr/sbin:/bin:/sbin:$PATH
D=/media/developer/cleanyourtv
INITD=/var/lib/webosbrew/init.d
[ "$(id -u)" = 0 ] || { echo 'run as root'; exit 1; }
rm -f "$INITD/10-cleanyourtv-service" "$INITD/10-cleanyourtv-home" "$INITD/15-cleanyourtv-debloat"
[ -f "$D/volume-osd-restore.sh" ] && sh "$D/volume-osd-restore.sh" </dev/null
pkill -f '[c]leanyourtv/helper.js' 2>/dev/null || true
for id in com.cleanyourtv.notify com.cleanyourtv.manager; do
  luna-send -n 1 -w 10000 -f luna://com.webos.applicationManager/closeByAppId "{\"id\":\"$id\"}" </dev/null >/dev/null 2>&1
  luna-send -n 1 -w 20000 -f luna://com.webos.appInstallService/dev/remove "{\"id\":\"$id\",\"subscribe\":false}" </dev/null >/dev/null 2>&1
  rm -rf "/media/developer/apps/usr/palm/packages/$id" "/media/developer/apps/usr/palm/applications/$id"
done
rm -rf /media/developer/apps/usr/palm/services/com.cleanyourtv.manager.service "$D"
echo 'Volume bar removed; LG Home was left unchanged.'
