#!/bin/sh
# Refresh only TV services affected when registering the volume overlay with SAM; keep LG Home as-is.
export PATH=/usr/bin:/usr/sbin:/bin:/sbin:$PATH
L=/media/developer/cleanyourtv
sdk=$(luna-send -n 1 -w 5000 -f luna://com.webos.service.tv.systemproperty/getSystemInfo '{"keys":["sdkVersion"]}' </dev/null 2>/dev/null | sed -n 's/.*"sdkVersion": *"\([^"]*\)".*/\1/p')
list=$(node "$L/tvprofile.js" get afterSam --sdk "$sdk" --home 'com.webos.app.home web' 2>/dev/null)
for svc in $list; do
  systemctl is-active "$svc" >/dev/null 2>&1 && systemctl restart "$svc" >/dev/null 2>&1
 done
