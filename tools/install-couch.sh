#!/bin/sh
# The Couch edition on a TV that already runs CleanYourTV. Run it on the TV, as root:
#   curl -fsSL https://raw.githubusercontent.com/larsoss/cleanyourtv-WebOS/couch/tools/install-couch.sh | sh
#   curl -fsSL https://raw.githubusercontent.com/larsoss/cleanyourtv-WebOS/couch/tools/install-couch.sh | sh -s status
#   curl -fsSL https://raw.githubusercontent.com/larsoss/cleanyourtv-WebOS/couch/tools/install-couch.sh | sh -s undo
# It downloads the couch branch and puts its files where an installed package has them (the manager app's service folder and the
# three apps), then runs that package's own `bootstrap.sh update`, exactly as after an update from the manager app: the service files
# are copied, the launcher is replaced, the service and its watchdog are started again, and a service that does not come up is rolled
# back. The TV then follows this repository (themes, updates) and the Couch theme is chosen.
# The first run keeps a copy of the package and the service folder as they were (backup-couch/package.tgz, service.tgz); "undo" puts
# that back the same way. Nothing outside /media/developer is changed.
set -e
export PATH=/usr/bin:/usr/sbin:/bin:/sbin:$PATH
REPO=${COUCH_REPO:-larsoss/cleanyourtv-WebOS}
BR=${COUCH_BRANCH:-couch}
MD=${COUCH_ROOT:-}/media/developer
D=$MD/cleanyourtv
A=$MD/apps/usr/palm/applications
SVC=$MD/apps/usr/palm/services/com.cleanyourtv.manager.service
INITD=${COUCH_ROOT:-}/var/lib/webosbrew/init.d
B=$D/backup-couch
T=${COUCH_TMP:-/tmp/cytv-couch}

say() { echo "couch: $*"; }
die() {
  echo "couch: $*" >&2
  exit 1
}
has() { grep -q "$1" "$2" 2>/dev/null && echo yes || echo no; }
ver() { sed -n "s/^const VERSION = '\(.*\)';/\1/p" "$1" | head -1; }

if [ "$1" = status ]; then
  say "service:            $(ver $D/helper.js) (package $(ver $SVC/helper/helper.js))"
  say "new apps by itself: $(has '/api/apps/stamp' $D/apps.js)"
  say "Couch look:         $(has 'scene-night' $D/app/index.html)"
  say "following:          $(cat $D/source 2>/dev/null || echo 'the original project')"
  say "service running:    $(pgrep -f '[c]leanyourtv/helper.js' >/dev/null && echo yes || echo no)"
  say "watchdog running:   $(pgrep -f '[c]leanyourtv/watchdog.sh' >/dev/null && echo yes || echo no)"
  say "theme:              $(curl -s -m 5 localhost:8765/api/theme/list | sed -n 's/.*"current":{"id":"\([^"]*\)".*/\1/p')"
  say "backup to go back:  $([ -f $B/package.tgz ] && echo yes || echo no)"
  exit 0
fi

[ -n "${COUCH_ROOT:-}" ] || [ "$(id -u)" = 0 ] || die "run this as root on the TV (ssh root@<tv>)"
[ -f $D/helper.js ] && [ -f $SVC/bootstrap.sh ] || die "CleanYourTV is not set up on this TV: install it and choose Set up now first"

# An earlier version of this installer ran its own watchdog next to the one of the service: stop it, so only one runs
old_watchdog() {
  rm -f $INITD/20-couch-watchdog $D/couch-watchdog.sh
  [ -f /tmp/couch-watchdog.pid ] && kill "$(cat /tmp/couch-watchdog.pid)" 2>/dev/null || true
  rm -f /tmp/couch-watchdog.pid
}
# the package's own update step: copies the service files, the launcher (when its BUILD differs), restarts service and watchdog
update() {
  say "updating the service and the launcher (the screen can blink once)"
  sh $SVC/bootstrap.sh update "$(ver $SVC/helper/helper.js)" || die "the update did not finish; the service files were put back. Details above."
}
theme() {
  curl -s -m 30 -X POST localhost:8765/api/theme/set -d "{\"id\":\"$1\"}" | grep -q "\"current\":{\"id\":\"$1\"" || say "could not choose the theme $1: choose it in Customise > Theme"
}

if [ "$1" = undo ]; then
  [ -f $B/package.tgz ] || die "there is no copy to go back to ($B/package.tgz)"
  say "putting the package back as it was before the first Couch install"
  (cd $MD/apps/usr/palm && tar xzf $B/package.tgz)
  [ -f $B/source ] && cp $B/source $D/source || rm -f $D/source
  old_watchdog
  # the launcher of that package, also when its version is not newer than the one in place
  rm -f $D/app/BUILD $D/app/version.json
  update
  theme classic
  say "done: the original version is back"
  exit 0
fi

say "downloading $REPO ($BR)"
rm -rf $T
mkdir -p $T
curl -fsSL -m 180 "https://codeload.github.com/$REPO/tar.gz/$BR" -o $T/src.tgz || die "download failed: is the TV online?"
tar xzf $T/src.tgz -C $T || die "could not unpack the download"
S=$(ls -d $T/*/ 2>/dev/null | head -n 1)
S=${S%/}
[ -f "$S/app/index.html" ] && [ -f "$S/helper/helper.js" ] && [ -f "$S/scripts/bootstrap.sh" ] || die "the download is not this project"

# the copy to go back to: the package and the service folder as they are before the first run of this version of the installer
if [ ! -f $B/package.tgz ]; then
  say "keeping a copy of the package as it is now in $B"
  mkdir -p $B
  (cd $MD/apps/usr/palm && tar czf $B/package.tgz services/com.cleanyourtv.manager.service applications/com.cleanyourtv.manager applications/com.cleanyourtv.picker applications/com.cleanyourtv.notify 2>/dev/null) || true
  [ -f $D/source ] && [ ! -f $B/source ] && cp $D/source $B/source || true
fi

say "putting the new files into the package"
# a short fingerprint of what is installed: bootstrap.sh replaces the launcher when it differs from the one in place
fp() { cat "$@" | md5sum | cut -c1-12; }
cp $S/scripts/bootstrap.sh $SVC/bootstrap.sh
mkdir -p $SVC/helper $SVC/scripts $SVC/i18n $SVC/payload/app
cp $S/helper/*.js $SVC/helper/
# the folders the service has besides its files (add-ons that ship with it, the pictures of the cards), as the package has them:
# without the sources of an add-on's page (src)
for f in $(cd $S/helper && ls -d */ 2>/dev/null); do
  rm -rf $SVC/helper/$f
  cp -r $S/helper/$f $SVC/helper/
  find $SVC/helper/$f -type d -name src -prune -exec rm -rf {} + 2>/dev/null || true
done
for f in $S/scripts/*; do [ "${f##*/}" = bootstrap.sh ] || cp "$f" $SVC/scripts/; done
cp $S/uninstall.sh $SVC/scripts/uninstall.sh
cp $S/i18n/*.json $S/i18n/runtime.js $SVC/i18n/
cp $S/compat.json $S/config.example.json $SVC/
rm -f $SVC/payload/app/*
for f in $S/app/*; do [ -f "$f" ] && cp "$f" $SVC/payload/app/; done
fp $S/app/index.html $S/app/version.json >$SVC/payload/app/BUILD
fp $S/helper/*.js >$SVC/BUILD
# the apps' pages (their appinfo.json stays: its version is the package's, and the notification window is set per TV)
for a in manager picker notify; do
  [ -d $A/com.cleanyourtv.$a ] || continue
  for f in $S/$a/app/*; do case "$f" in *appinfo.json) ;; *) [ -f "$f" ] && cp "$f" $A/com.cleanyourtv.$a/ ;; esac; done
done
[ -f $S/third-party/qrcode-generator/qrcode.js ] && cp $S/third-party/qrcode-generator/qrcode.js $A/com.cleanyourtv.manager/

# themes and updates from this repository from now on
echo "$REPO $BR" >$D/source
old_watchdog
update
theme couchtv
rm -rf $T
say "done. Version $(ver $D/helper.js); a newly installed app now shows up on Home by itself."
