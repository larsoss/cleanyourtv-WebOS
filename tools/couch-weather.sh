#!/bin/sh
# Couch edition: puts the Home Assistant weather card in a place on Home, without the phone page. Run it on the TV, as root:
#   curl -fsSL https://raw.githubusercontent.com/larsoss/cleanyourtv-couch/main/tools/couch-weather.sh | sh -s weather.forecast_thuis sensor.knmi_temperatuur
# Arguments: the weather entity, optionally a sensor for the temperature outside, optionally the place (default row, above the dock)
# and the forecast (daily, hourly or none). It opens the cards' phone page for a moment, saves the card the way that page does (the
# other places keep their cards) and closes it again.
export PATH=/usr/bin:/usr/sbin:/bin:/sbin:$PATH
W=$1
S=$2
SLOT=${3:-row}
SHOW=$4
die() {
  echo "couch-weather: $*" >&2
  exit 1
}
echo "$W" | grep -Eq '^weather\.[A-Za-z0-9_]+$' || die "the first argument must be a weather entity, for example weather.forecast_thuis"
[ -z "$S" ] || echo "$S" | grep -Eq '^sensor\.[A-Za-z0-9_]+$' || die "the second argument must be a sensor, for example sensor.knmi_temperatuur"
case "$SHOW" in '' | daily) SHOW='' ;; hourly | none) ;; *) die "the forecast must be daily, hourly or none" ;; esac
CODE=$(curl -s -X POST localhost:8765/api/cards/pair -d '{}' | sed -n 's/.*"code":"\([0-9]*\)".*/\1/p')
[ -n "$CODE" ] || die "the service did not answer; is CleanYourTV running?"
OLD=$(curl -s -H "x-code: $CODE" 127.0.0.1:8792/api/state)
# the cards as they are, with this place replaced (node is on every TV this runs on)
BODY=$(node -e '
  var s = JSON.parse(process.argv[1] || "{}"), c = s.cards || {}, o = { type: "ha-weather", entity: process.argv[2] };
  if (process.argv[3]) o.temp = process.argv[3];
  if (process.argv[5]) o.show = process.argv[5];
  c[process.argv[4]] = o;
  console.log(JSON.stringify({ cards: c }));
  if (s.ha === false) console.error("couch-weather: Home Assistant is not set up on the TV yet (manager app: More > Home Assistant)");
' "$OLD" "$W" "$S" "$SLOT" "$SHOW")
R=$(curl -s -X POST -H "x-code: $CODE" 127.0.0.1:8792/api/save -d "$BODY")
curl -s -X POST localhost:8765/api/cards/pair -d '{"stop":true}' >/dev/null
echo "$R" | grep -q '"ok":true' || die "saving failed: $R"
echo "couch-weather: saved in place $SLOT: $W${S:+ with $S}. Open Home to see it."
