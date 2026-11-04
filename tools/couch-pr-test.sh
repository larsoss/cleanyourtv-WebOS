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
  head -c 71680 /dev/zero | tr '\0' 'x' | fold -w 99 >> $L/blackbox.log; echo "filled: $(wc -c < $L/blackbox.log)" ;;
cost) # what top costs every 30 seconds
  a=$(cut -d' ' -f1 /proc/uptime)
  for i in 1 2 3 4 5; do top -b -n 1 >/dev/null 2>&1; done
  b=$(cut -d' ' -f1 /proc/uptime)
  t=$(awk -v a=$a -v b=$b 'BEGIN{printf "%.3f", (b-a)/5}')
  echo "top -b -n 1: $t s per run (wall time, 5 runs), $(awk -v t=$t 'BEGIN{printf "%.2f", t/30*100}')% of one core at one run per 30 s"
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
*) echo "phases: boot <n> | home | mark | marked | unmark | box | fill | cost | disable | enable | lg | rollback | sharelog | icon | iconreset | seasons" ;;
esac
