#!/bin/sh
# Puts the Couch look (scenes, glass clock, glass Home Assistant cards) on a TV that already runs CleanYourTV. Run it on the TV, as root:
#   curl -fsSL https://raw.githubusercontent.com/larsoss/cleanyourtv-couch/main/tools/install-couch.sh | sh
#   curl -fsSL https://raw.githubusercontent.com/larsoss/cleanyourtv-couch/main/tools/install-couch.sh | sh -s undo
# It downloads this repository, keeps a copy of what is on the TV now in /media/developer/cleanyourtv/backup-couch, replaces the
# service files and the launcher the way an update from the manager app does, makes the TV follow this repository (themes and updates
# come from here, so an update of the original project does not overwrite it), restarts the service and chooses the Couch theme.
# "undo" puts the copy back, follows the original project again and chooses Classic. Nothing outside /media/developer is changed.
set -e
export PATH=/usr/bin:/usr/sbin:/bin:/sbin:$PATH
REPO=${COUCH_REPO:-larsoss/cleanyourtv-couch}
BR=${COUCH_BRANCH:-main}
D=/media/developer/cleanyourtv
B=$D/backup-couch
T=/tmp/cytv-couch

say() { echo "couch: $*"; }
die() {
  echo "couch: $*" >&2
  exit 1
}
[ "$(id -u)" = 0 ] || die "run this as root on the TV (ssh root@<tv>)"
[ -f $D/helper.js ] && [ -d $D/app ] || die "CleanYourTV is not set up on this TV: install it and choose Set up now first"

restart_service() {
  pkill -f cleanyourtv/helper.js 2>/dev/null || true
  sleep 1
  (cd / && nohup node $D/helper.js >/tmp/cleanyourtv-helper.log 2>&1 </dev/null &)
  for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
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

if [ "$1" = undo ]; then
  [ -d $B/app ] && [ -f $B/helper/helper.js ] || die "there is no copy to go back to ($B)"
  say "putting back the service files and the launcher from before"
  cp $B/helper/*.js $D/
  [ -d $B/i18n ] && cp $B/i18n/* $D/i18n/ 2>/dev/null || true
  rm -rf $D/app.next
  cp -r $B/app $D/app.next
  swap_app $D/app.next
  if [ -f $B/source ]; then cp $B/source $D/source; else rm -f $D/source; fi
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

# the copy to go back to: only the first time, so running this again (an update) keeps the original
if [ ! -f $B/helper/helper.js ]; then
  say "keeping a copy of the current service files and launcher in $B"
  mkdir -p $B/helper $B/i18n
  cp $D/*.js $B/helper/
  [ -d $D/i18n ] && cp $D/i18n/* $B/i18n/ 2>/dev/null || true
  rm -rf $B/app
  cp -r $D/app $B/app
  [ -f $D/source ] && cp $D/source $B/source || true
fi

say "installing the service files"
cp $S/helper/*.js $D/
mkdir -p $D/i18n
cp $S/i18n/*.json $S/i18n/runtime.js $D/i18n/

say "installing the launcher"
rm -rf $D/app.next
mkdir -p $D/app.next
for f in $S/app/*; do [ -f "$f" ] && cp "$f" $D/app.next/; done
swap_app $D/app.next

# themes and updates from this repository from now on
echo "$REPO $BR" >$D/source

say "restarting the service"
restart_service
theme couchtv
sh $D/reload-home.sh >/dev/null 2>&1 || true
rm -rf $T
say "done. Set up the weather card in the manager app: Cards > Set up from your phone"
