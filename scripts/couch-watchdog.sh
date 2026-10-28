#!/bin/sh
# Couch edition: starts the CleanYourTV service again when it has stopped. Node 8 on webOS 5 and 6 can end the service with a libuv
# assertion (uv_close); without the service the launcher has no theme and the manager app offers a new setup. Started at boot from
# /var/lib/webosbrew/init.d/20-couch-watchdog (tools/install-couch.sh links it; "undo" removes it). One copy runs (pid file).
export PATH=/usr/bin:/usr/sbin:/bin:/sbin:$PATH
D=/media/developer/cleanyourtv
PID=/tmp/couch-watchdog.pid
[ -f $PID ] && kill -0 "$(cat $PID)" 2>/dev/null && exit 0
(
  sh -c 'echo $PPID' >$PID
  sleep 90
  while true; do
    if ! pgrep -f "[c]leanyourtv/helper.js" >/dev/null; then
      echo "$(cut -d' ' -f1 /proc/uptime) couch-watchdog: the service had stopped; starting it again" >>/tmp/cleanyourtv-boot.log
      [ -f /tmp/cleanyourtv-helper.log ] && cp /tmp/cleanyourtv-helper.log /tmp/cleanyourtv-helper.crash.log
      (cd / && nohup node $D/helper.js >/tmp/cleanyourtv-helper.log 2>&1 </dev/null &)
    fi
    sleep 20
  done
) </dev/null >/dev/null 2>&1 &
