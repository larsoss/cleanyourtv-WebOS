// What may be closed, and when. This is the whole decision of the add-on, kept apart from the TV so it can be tested without one:
// service.js only watches which app is in front and does what plan() says.
// An app is closed a while after you leave it, not at once: going to Home for a moment, or stepping through the Inputs, must not end
// what you were watching. Coming back to the app before that cancels it.

// never closed, whatever the user chooses: the launcher and its own apps, LG's Home, the Inputs, Live TV and the tuner, and anything
// of the Homebrew Channel (the Hyperion and HyperHDR loaders for ambilight are webOS apps of that family, and closing one ends the
// ambilight for the whole TV, not just a window)
const SAFE = /^(com\.cleanyourtv\.|org\.webosbrew\.|com\.webos\.app\.(home|hdmi|livetv|tvhotkey|tvguide|screensaver|notificationcenter))/;
const DELAYS = [10, 30, 60, 120, 300]; // seconds the add-on waits, the user chooses one
const DEFAULT_DELAY = 30;
const WAITING_MAX = 12; // apps waiting at once: more than that are not open anyway, and the oldest entry goes

const isId = id => typeof id === 'string' && /^[A-Za-z0-9._-]{1,80}$/.test(id);

// the apps the user wants left running: ids only, once each, at most 40
const cleanKeep = list => (Array.isArray(list) ? list : []).filter((id, i, a) => isId(id) && a.indexOf(id) === i).slice(0, 40);

// the settings as they are kept, with every value checked
const cleanSettings = s => {
  const o = s && typeof s === 'object' ? s : {};
  return {
    on: o.on !== false, // the add-on's own switch already decides whether it runs; this one is for turning it off from the page
    delay: DELAYS.indexOf(o.delay) >= 0 ? o.delay : DEFAULT_DELAY,
    keep: cleanKeep(o.keep),
  };
};

// may this app be closed at all?
const closable = (id, keep) => !!id && isId(id) && !SAFE.test(id) && (keep || []).indexOf(id) < 0;

// What to do now that `front` is the app in front. `state` is what the add-on remembers: {front, waiting: [{id, at}]}.
// Answers the new state and, when a wait is over, the app to close (one at a time, the one that has waited longest).
// `now` is a time in milliseconds, `s` the settings.
//
// Every app you left waits for itself. One entry is not enough: leaving an app and then stepping on through Home to an
// input is two changes, and on the TV the second one used to throw the first app's wait away, so it stayed open for good
// (seen on a C1: YouTube left open behind HDMI 2). Each app you leave keeps its own clock until it is closed or you are
// back in it.
function plan(state, front, s, now) {
  const set = cleanSettings(s),
    was = (state && state.front) || '';
  let list = (Array.isArray(state && state.waiting) ? state.waiting : []).filter(x => x && isId(x.id));
  // the TV answers nothing while it is between apps or asleep: keep what we had, decide nothing
  if (!front) return { front: was, waiting: list, close: '' };
  if (!set.on) return { front: front, waiting: [], close: '' };

  // the app in front changed: the one you left starts waiting, if it may be closed and is not already waiting
  if (front !== was && closable(was, set.keep) && !list.some(x => x.id === was))
    list = list.concat([{ id: was, at: now }]).slice(-WAITING_MAX);
  // the app in front is not waiting for anything (you are back in it), and neither is one you have since ticked to keep
  list = list.filter(x => x.id !== front && closable(x.id, set.keep));

  const due = list.filter(x => now - x.at >= set.delay * 1000).sort((a, b) => a.at - b.at)[0];
  if (due) return { front: front, waiting: list.filter(x => x.id !== due.id), close: due.id };
  return { front: front, waiting: list, close: '' };
}

module.exports = { SAFE, DELAYS, DEFAULT_DELAY, WAITING_MAX, isId, cleanKeep, cleanSettings, closable, plan };
