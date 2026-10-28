#!/bin/sh
# Puts the Couch look (scenes, glass clock, glass Home Assistant cards) on a TV that already runs CleanYourTV. Run it on the TV, as root:
#   curl -fsSL https://raw.githubusercontent.com/larsoss/cleanyourtv-WebOS/couch/tools/install-couch.sh | sh
#   curl -fsSL https://raw.githubusercontent.com/larsoss/cleanyourtv-WebOS/couch/tools/install-couch.sh | sh -s undo
#   curl -fsSL https://raw.githubusercontent.com/larsoss/cleanyourtv-WebOS/couch/tools/install-couch.sh | sh -s status
# It downloads this repository, keeps a copy of what is on the TV now in /media/developer/cleanyourtv/backup-couch, replaces the
# service files and the launcher the way an update from the manager app does, makes the TV follow this repository (themes and updates
# come from here, so an update of the original project does not overwrite it), restarts the service and chooses the Couch theme.
# The same files also go into the installed package (the manager app's service folder): the setup and a repair copy the service files
# from there, so without this a repair from the manager app would bring the original service back (the scenes and the glass clock
# would disappear while the theme stays chosen).
# "undo" puts the copies back, follows the original project again and chooses Classic. "status" only reports. Nothing outside
# /media/developer is changed.
set -e
export PATH=/usr/bin:/usr/sbin:/bin:/sbin:$PATH
REPO=${COUCH_REPO:-larsoss/cleanyourtv-WebOS}
BR=${COUCH_BRANCH:-couch}
D=/media/developer/cleanyourtv
SVC=/media/developer/apps/usr/palm/services/com.cleanyourtv.manager.service
MGR=/media/developer/apps/usr/palm/applications/com.cleanyourtv.manager
B=$D/backup-couch
T=/tmp/cytv-couch

say() { echo "couch: $*"; }
die() {
  echo "couch: $*" >&2
  exit 1
}
has() { grep -q "$1" "$2" 2>/dev/null && echo yes || echo no; }

if [ "$1" = status ]; then
  say "service files with Couch:      $(has "'clock.style'" $D/themeschema.js)"
  say "package files with Couch:      $(has "'clock.style'" $SVC/helper/themeschema.js)"
  say "launcher with Couch:           $(has 'scene-night' $D/app/index.html)"
  say "following:                     $(cat $D/source 2>/dev/null || echo 'the original project')"
  say "service running:               $(pgrep -f cleanyourtv/helper.js >/dev/null && echo yes || echo no)"
  say "theme the service hands out:   $(curl -s localhost:8765/api/theme/list | grep -o '"current":{[^}]*}')"
  say "last error:                    $(cat $D/last-error.txt 2>/dev/null || echo none)"
  say "watchdog:                      $(pgrep -f '[c]leanyourtv/watchdog.sh' >/dev/null && echo running || echo 'not running (starts at the next boot)')"
  tail -n 5 /tmp/cleanyourtv-helper.log 2>/dev/null | sed 's/^/couch: log: /'
  exit 0
fi

[ "$(id -u)" = 0 ] || die "run this as root on the TV (ssh root@<tv>)"
[ -f $D/helper.js ] && [ -d $D/app ] || die "CleanYourTV is not set up on this TV: install it and choose Set up now first"

# the service, started the way the boot script and an update start it
restart_service() {
  pkill -f "[c]leanyourtv/helper.js" 2>/dev/null || true
  sleep 1
  sh $D/10-cleanyourtv-home keep </dev/null >/dev/null 2>&1 || (cd / && nohup node $D/helper.js >/tmp/cleanyourtv-helper.log 2>&1 </dev/null &)
  for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    curl -s -o /dev/null localhost:8765/api/theme/list && return 0
    sleep 1
  done
  die "the service did not start; see /tmp/cleanyourtv-helper.log (undo: run this script with undo)"
}
# the launcher, as the manager app installs one: the new folder in, the old one kept as app.prev, Home rebuilt and reloaded
swap_app() {
  rm -rf $D/app.prev
  mv $D/app $D/app.prev
  mv "$1" $D/app
  sh $D/stage-home.sh
}
theme() {
  curl -s -X POST localhost:8765/api/theme/set -d "{\"id\":\"$1\"}" | grep -q "\"current\":{\"id\":\"$1\"" || say "could not choose the theme $1: choose it in Customise > Theme"
}
# copy the files of a folder (no subfolders) into another one
files() {
  mkdir -p "$2"
  for f in "$1"/*; do [ -f "$f" ] && cp "$f" "$2"/; done
  return 0
}

if [ "$1" = undo ]; then
  [ -d $B/app ] && [ -f $B/helper/helper.js ] || die "there is no copy to go back to ($B)"
  say "putting back the service files and the launcher from before"
  cp $B/helper/*.js $D/
  [ -d $B/i18n ] && files $B/i18n $D/i18n
  if [ -f $B/svc/helper/helper.js ]; then
    files $B/svc/helper $SVC/helper
    [ -d $B/svc/i18n ] && files $B/svc/i18n $SVC/i18n
    [ -d $B/svc/app ] && files $B/svc/app $SVC/payload/app
  fi
  [ -f $B/manager-index.html ] && cp $B/manager-index.html $MGR/index.html
  rm -rf $D/app.next
  cp -r $B/app $D/app.next
  swap_app $D/app.next
  if [ -f $B/source ]; then cp $B/source $D/source; else rm -f $D/source; fi
  rm -f /var/lib/webosbrew/init.d/20-couch-watchdog
  [ -f /tmp/couch-watchdog.pid ] && kill "$(cat /tmp/couch-watchdog.pid)" 2>/dev/null || true
  rm -f /tmp/couch-watchdog.pid $D/couch-watchdog.sh
  restart_service
  theme classic
  sh $D/reload-home.sh >/dev/null 2>&1 || true
  say "done: the original launcher and service are back"
  exit 0
fi

say "downloading $REPO ($BR)"
rm -rf $T
mkdir -p $T
curl -fsSL -m 120 "https://codeload.github.com/$REPO/tar.gz/$BR" -o $T/src.tgz || die "download failed: is the TV online?"
tar xzf $T/src.tgz -C $T || die "could not unpack the download"
S=$(ls -d $T/*/ 2>/dev/null | head -n 1)
S=${S%/}
[ -f "$S/app/index.html" ] && [ -f "$S/helper/helper.js" ] && [ -f "$S/app/scene-night.jpg" ] || die "the download is not this project"

# the copies to go back to: only the first time, so running this again (an update) keeps the originals
if [ ! -f $B/helper/helper.js ]; then
  say "keeping a copy of the current service files and launcher in $B"
  mkdir -p $B/helper $B/i18n
  cp $D/*.js $B/helper/
  [ -d $D/i18n ] && files $D/i18n $B/i18n
  rm -rf $B/app
  cp -r $D/app $B/app
  [ -f $D/source ] && cp $D/source $B/source || true
fi
if [ -f $SVC/helper/helper.js ] && [ ! -f $B/svc/helper/helper.js ] && ! grep -q "'clock.style'" $SVC/helper/themeschema.js; then
  say "keeping a copy of the installed package's files in $B/svc"
  files $SVC/helper $B/svc/helper
  [ -d $SVC/i18n ] && files $SVC/i18n $B/svc/i18n
  [ -d $SVC/payload/app ] && files $SVC/payload/app $B/svc/app
fi
if [ -f $MGR/index.html ] && [ ! -f $B/manager-index.html ] && ! grep -q "open === 'ha'" $MGR/index.html; then
  cp $MGR/index.html $B/manager-index.html
fi

say "installing the service files"
cp $S/helper/*.js $D/
files $S/i18n $D/i18n
if [ -d $SVC/helper ]; then
  say "updating the installed package too, so a setup or repair keeps Couch"
  files $S/helper $SVC/helper
  [ -d $SVC/i18n ] && files $S/i18n $SVC/i18n
  [ -d $SVC/payload/app ] && files $S/app $SVC/payload/app
fi

# the manager app's page: it can open its Home Assistant screen for the launcher's Customise > Home Assistant > Connection
[ -f $MGR/index.html ] && [ -f $S/manager/app/index.html ] && cp $S/manager/app/index.html $MGR/index.html

say "installing the launcher"
rm -rf $D/app.next
files $S/app $D/app.next
swap_app $D/app.next

# themes and updates from this repository from now on
echo "$REPO $BR" >$D/source

# the boot script and its watchdog (scripts/watchdog.sh, proposed upstream): it starts the service again if it stops. An earlier
# version of this installer used a separate 20-couch-watchdog; that one goes, so two watchdogs never race.
cp $S/scripts/10-cleanyourtv-home $S/scripts/watchdog.sh $D/
rm -f /var/lib/webosbrew/init.d/20-couch-watchdog $D/couch-watchdog.sh
[ -f /tmp/couch-watchdog.pid ] && kill "$(cat /tmp/couch-watchdog.pid)" 2>/dev/null || true
rm -f /tmp/couch-watchdog.pid
pgrep -f "[c]leanyourtv/watchdog.sh" >/dev/null || (sh $D/watchdog.sh </dev/null >/dev/null 2>&1 &)

say "restarting the service"
restart_service
theme couchtv
sh $D/reload-home.sh >/dev/null 2>&1 || true
rm -rf $T
say "done. Choose the cards on Home: Customise > Home Assistant"
