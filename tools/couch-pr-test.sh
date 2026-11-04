#!/bin/sh
# Couch edition only (not for upstream): the checks the reviewer asked for, on a real TV.
# Checks for the pull requests on the TV (run as root): sh prtest.sh <phase>. Results go to /media/developer/cleanyourtv/pr-test/.
export PATH=/usr/bin:/usr/sbin:/bin:/sbin:$PATH
L=/media/developer/cleanyourtv
R=$L/pr-test
mkdir -p $R
up() { cut -d' ' -f1 /proc/uptime; }
api() { curl -s -m 20 "$@"; }
case "$1" in
boot) # after a reboot: the first lines of the boot log, and whether the stand-in was mounted first
  n=${2:-x}
  { echo "== boot $n (uptime $(up))"; head -n 8 /tmp/cleanyourtv-boot.log; echo "home-takeover: $(cat $L/home-takeover 2>/dev/null)";
    grep " /usr/bin/com.webos.app.home " /proc/mounts | cut -d' ' -f1-3; } > $R/boot-$n.txt
  cat $R/boot-$n.txt ;;
home) # the Home key: the app manager launches Home, as the key does; the launcher must be shown and open in webapp-mgr
  luna-send -n 1 -w 8000 -f luna://com.webos.applicationManager/launch '{"id":"com.webos.app.home"}' </dev/null | grep returnValue
  sleep 4
  tail -n 3 /tmp/cleanyourtv-boot.log
  luna-send -n 1 -w 3000 -f luna://com.webos.applicationManager/getForegroundAppInfo '{}' </dev/null | grep appId
  luna-send -n 1 -w 3000 luna://com.palm.webappmanager/listRunningApps '{}' </dev/null | grep -c '"com.webos.app.home"' ;;
mark) # an update of the launcher: one file of the launcher changes (a comment at the end of the page)
  echo "<!-- pr-test launcher update $(date +%s) -->" >> $L/app/index.html
  tail -c 80 $L/app/index.html; echo ;;
marked) # after the reboot: the staged page has the change, and the boot took the slow way
  echo "staged page: $(tail -c 80 $L/home-overlay/index.html | grep -o 'pr-test launcher update [0-9]*')"
  echo "app page:    $(tail -c 80 $L/app/index.html | grep -o 'pr-test launcher update [0-9]*')"
  grep -c "known from an earlier boot" /tmp/cleanyourtv-boot.log | sed 's/^/fast start lines: /' ;;
unmark)
  sed -i '/<!-- pr-test launcher update [0-9]* -->/d' $L/app/index.html; tail -c 40 $L/app/index.html; echo ;;
box) # the black box: lines and their spacing, size, and the reason line of the boot before
  echo "lines: $(grep -c mem= $L/blackbox.log)  bytes: $(wc -c < $L/blackbox.log)"
  grep mem= $L/blackbox.log | cut -d' ' -f1 | awk 'NR>1{printf "%.0f ", $1-p} {p=$1} END{print ""}' | sed 's/^/spacing (s): /'
  tail -n 2 $L/blackbox.log | cut -c1-200
  echo "last boot: $(head -n 1 $L/blackbox.last.log)" ;;
fill) # the 64 KB cap: the box is filled to 70 KB; the next line must bring it back below 64 KB
  i=0; while [ $i -lt 720 ]; do echo "0.00 fill xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"; i=$((i + 1)); done >> $L/blackbox.log
  echo "filled: $(wc -c < $L/blackbox.log)" ;;
cost) # what top costs every 30 seconds: the CPU time of 10 runs (utime + stime of the children, in clock ticks of 1/100 s)
  sh -c 'for i in 1 2 3 4 5 6 7 8 9 10; do top -b -n 1 >/dev/null 2>&1; done; cat /proc/$$/stat' | awk '{t=$16+$17; printf "top -b -n 1: %.3f s CPU per run, %.2f%% of one core at one run per 30 s\n", t/1000, t/1000/30*100}'
  echo "load now: $(cut -d' ' -f1-3 /proc/loadavg)" ;;
disable) touch $L/DISABLE; echo "DISABLE set" ;;
enable) rm -f $L/DISABLE; echo "DISABLE removed" ;;
lg) # LG's Home is on the Home key: no stand-in mount, and Home is LG's own program
  echo "mount over LG's Home: $(grep -c ' /usr/bin/com.webos.app.home ' /proc/mounts)"
  luna-send -n 1 -w 8000 -f luna://com.webos.applicationManager/launch '{"id":"com.webos.app.home"}' </dev/null | grep returnValue
  sleep 4
  echo "LG's Home program running: $(pgrep -f '^/usr/bin/com.webos.app.home' | head -n 1)"
  echo "our launcher in webapp-mgr: $(luna-send -n 1 -w 3000 luna://com.palm.webappmanager/listRunningApps '{}' </dev/null | grep -c '"com.webos.app.home"')"
  tail -n 4 /tmp/cleanyourtv-boot.log ;;
rollback) sh $L/undo-home.sh temp; sleep 3; tail -n 3 /tmp/cleanyourtv-boot.log ;;
sharelog) # the report holds both boxes
  node $L/sharelog.js >/dev/null 2>&1 &
  sleep 8
  u=$(sed -n 's/.*"url":"\([^"]*\)".*/\1/p' /tmp/cytv-sharelog.json)
  curl -s -m 10 "$u" | grep -o 'Black box[^=<]*' | sort -u ;;
icon) # a picture for the Live TV tile through the App icons page, then reset
  printf '\211PNG\r\n\032\n\0\0\0\rIHDR\0\0\0\1\0\0\0\1\10\6\0\0\0\37\25\304\211\0\0\0\rIDATx\234c\370\377\377?\0\5\376\2\376\247\65\201\204\0\0\0\0IEND\256B`\202' > /tmp/live.png
  P=$(api -X POST localhost:8765/api/icons/pair -d '{}')
  C=$(echo "$P" | sed -n 's/.*"code":"\([0-9]*\)".*/\1/p')
  api -X POST -H "x-code: $C" -H 'content-type: image/png' --data-binary @/tmp/live.png 127.0.0.1:8794/api/upload/__live; echo
  api localhost:8765/api/apps | grep -o '"liveIcon":{[^}]*}'
  api -s -o /dev/null -w "GET /icon/__live: %{http_code} %{content_type}\n" localhost:8765/icon/__live ;;
iconreset)
  api -X POST localhost:8765/api/icons/reset -d '{"id":"__live"}'; echo
  api localhost:8765/api/apps | grep -c liveIcon | sed 's/^/liveIcon fields left: /'
  api -X POST localhost:8765/api/icons/pair -d '{"stop":true}' >/dev/null ;;
seasons) # the add-on: what it keeps, and what the launcher gets
  api localhost:8765/api/addons/seasons/status; echo
  api -X POST localhost:8765/api/scenes -d '{"cc":"NLD"}' | cut -c1-300; echo
  du -sh $L/addon-data/seasons 2>/dev/null ;;
preflight) # before a reboot or an install: the Homebrew Channel's failsafe flag must be gone (a reboot before that starts in failsafe mode)
  echo "uptime: $(up)"
  if [ -e /var/luna/preferences/webosbrew_failsafe ]; then echo "STOP: webosbrew_failsafe is still there; wait until it is gone"; else echo "failsafe flag: gone"; fi
  echo "update block: $([ -e /var/luna/preferences/webosbrew_block_updates ] && echo on || echo OFF)"
  echo "source: $(cat $L/source 2>/dev/null)" ;;
standby) # after the remote's power key off and on: the power states, and what the stand-in and the watchdog did
  grep -h NL_POWER_STATE /var/log/messages 2>/dev/null | tail -n 6 | sed 's/.*NL_POWER_STATE //' | cut -c1-120
  grep -E "app manager restarted|nothing on screen|without its stand-in|LG's Home until" /tmp/cleanyourtv-boot.log | tail -n 6
  echo "sam since: $(awk '{print $22/100}' /proc/$(pgrep -x sam | head -n 1)/stat 2>/dev/null) s"
  echo "stand-in running: $(pgrep -f '^/bin/sh /usr/bin/com.webos.app.home' | head -n 1)"
  luna-send -n 1 -w 3000 -f luna://com.webos.applicationManager/getForegroundAppInfo '{}' </dev/null | grep appId ;;
repos) # pull request 169: the shell tool, Lars' repository added (it asks first), what it offers
  node $L/cytv-addons.js shortcut
  api -X POST localhost:8765/api/addons/repos -d '{"add":"larsoss/cleanyourtv-WebOS@tv-addons"}'; echo "  (without confirm: must be refused)"
  node $L/cytv-addons.js repo-add larsoss/cleanyourtv-WebOS@tv-addons -y
  node $L/cytv-addons.js repos
  node $L/cytv-addons.js list ;;
repoinstall) # Seasons from Lars' repository (it replaces the copy from the official catalog), and where it came from
  node $L/cytv-addons.js install seasons larsoss-cleanyourtv-webos -y
  node $L/cytv-addons.js installed
  cat $L/addons/.sources/seasons.json 2>/dev/null || find $L -path '*addons/.sources/seasons.json' -exec cat {} \;; echo ;;
repoupdate) # after a newer Seasons was pushed to the repository: update takes it from there
  node $L/cytv-addons.js update -y
  node $L/cytv-addons.js installed | grep seasons ;;
repophone) # the phone page for adding a repository: port 8799 opens with a code and closes again
  api -X POST localhost:8765/api/addons/repos/phone -d '{}' | sed 's/"code":"[0-9]*"/"code":"(hidden)"/'; echo
  echo "port 8799 listening: $(netstat -ltn 2>/dev/null | grep -c ':8799 ')"
  api -X POST localhost:8765/api/addons/repos/phone -d '{"stop":true}'; echo
  sleep 1; echo "port 8799 after stop: $(netstat -ltn 2>/dev/null | grep -c ':8799 ')" ;;
*) echo "phases: preflight | standby | repos | repoinstall | repoupdate | repophone | boot <n> | home | mark | marked | unmark | box | fill | cost | disable | enable | lg | rollback | sharelog | icon | iconreset | seasons" ;;
esac
