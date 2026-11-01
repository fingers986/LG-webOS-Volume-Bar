#!/bin/sh
# The service's watchdog, started by 10-cleanyourtv-home (one per boot, also while LG's Home is selected). Every 10 seconds it asks the
# service; when it does not answer:
#   - if the service is not running at all (it exited, for example on a Node 8 libuv assertion, issue 65) it starts it again, notes that
#     in the boot log and adds the service log of the run that ended to cleanyourtv-helper.crash.log (the last 400 lines are kept, so a
#     service that crashes again at once does not wipe the first cause; Share log includes it). This happens as long as CleanYourTV is
#     installed, also while LG's Home is back after a fallback, so the launcher, the Input key and the manager keep their service. Not
#     while bootstrap.sh runs: a setup or an update starts and stops the service itself. A service that stops again at once is started
#     less often (after 10, 20, ... up to 120 seconds), so a service that cannot start does not use the TV all night.
#   - while our launcher is Home and the service stays unreachable for about a minute, LG's Home comes back until the next reboot
#     (undo-home.sh temp), as before.
# The whole script is one block that ends in exit: the shell has read all of it before it runs, so an update that copies a new
# watchdog.sh over this file does not confuse the copy that is running (bootstrap.sh stops it, and the boot script starts the new one).
# The paths can be pointed elsewhere for the tests (tools/test/scripts.test.js); on the TV none of these variables is set.
{
  export PATH=/usr/bin:/usr/sbin:/bin:/sbin:$PATH
  L=${CYTV_DIR:-/media/developer/cleanyourtv}
  LOG=${CYTV_BOOT_LOG:-/tmp/cleanyourtv-boot.log}
  SLOG=${CYTV_SERVICE_LOG:-/tmp/cleanyourtv-helper.log}
  CRASH=${SLOG%.log}.crash.log
  URL=${CYTV_SERVICE_URL:-http://127.0.0.1:8765/api/foreground}
  EVERY=${CYTV_WATCH_SECS:-10}
  H=/usr/palm/applications/com.webos.app.home
  STANDIN=/tmp/cleanyourtv-home-standin
  up() { cut -d' ' -f1 /proc/uptime 2>/dev/null; }
  replaced() { grep -q " $H " /proc/mounts || { [ -f $STANDIN ] && grep -q " $(cat $STANDIN) " /proc/mounts; }; }
  # the log of the run that ended goes to the crash log, which keeps its last 400 lines
  keep_log() {
    [ -s "$SLOG" ] || return 0
    { echo "=== the service log of a run that ended (uptime $(up)) ==="; tail -n 200 "$SLOG"; } >>"$CRASH" 2>/dev/null
    n=$(wc -l <"$CRASH" 2>/dev/null)
    if [ "${n:-0}" -gt 400 ]; then tail -n 400 "$CRASH" >"$CRASH.tmp" && mv "$CRASH.tmp" "$CRASH"; fi
  }

  bad=0       # checks in a row without an answer (the fallback to LG's Home counts them)
  fallback=0  # 1 once LG's Home has been brought back by this watchdog
  fails=0     # starts in a row that did not bring the service back
  hold=0      # checks to wait before the next start
  while [ -f "$L/helper.js" ]; do
    sleep "$EVERY"
    if curl -s -m 3 -o /dev/null "$URL"; then
      bad=0
      fails=0
      hold=0
      continue
    fi
    if ! pgrep -f "$L/helper.js" >/dev/null && ! pgrep -f "^[a-z/]*sh [^ ]*[b]ootstrap.sh" >/dev/null; then
      if [ $hold -gt 0 ]; then
        hold=$((hold - 1))
      else
        fails=$((fails + 1))
        hold=$((fails - 1))
        [ $hold -gt 11 ] && hold=11
        echo "$(up) watchdog: the service had stopped; starting it again (start $fails in a row)" >>"$LOG"
        keep_log
        (cd / && nohup node "$L/helper.js" >"$SLOG" 2>&1 </dev/null &)
      fi
    fi
    if [ $fallback = 0 ] && replaced; then
      bad=$((bad + 1))
      if [ $bad -ge 6 ]; then
        echo "$(up) watchdog: the service did not answer for a minute; LG's Home until the next reboot" >>"$LOG"
        sh "$L/undo-home.sh" temp
        fallback=1
      fi
    fi
  done
  exit 0
}
