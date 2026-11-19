// The Close apps add-on: which app may be closed, how long the TV waits, and that coming back cancels it. The decision is a pure
// function (decide.js), so all of this runs without a TV; the service is driven with a stand-in ctx whose clock and luna calls the
// test holds, so nothing is ever really closed.
const path = require('path');
const { root, ok, run } = require('./lib');

const A = path.join(root, 'addons', 'catalog', 'closeapps');
const decide = require(path.join(A, 'decide.js'));
const service = require(path.join(A, 'service.js'));

// a ctx like the loader's: settings in memory, a clock the test moves, and luna calls written down
function fake(front) {
  const o = {
    now: 1000000,
    front: front || '',
    saved: { on: true, delay: 30, keep: [] },
    calls: [],
    logs: [],
  };
  o.ctx = {
    id: 'closeapps',
    now: () => o.now,
    log: l => o.logs.push(l),
    settings: { get: () => o.saved, set: s => (o.saved = s) },
    luna: async (uri, payload) => {
      o.calls.push({ uri, payload });
      if (/getForegroundAppInfo$/.test(uri)) return { returnValue: true, appId: o.front };
      if (/closeByAppId$/.test(uri)) return { returnValue: true };
      return { returnValue: false };
    },
  };
  return o;
}
const post = async (mod, p, body, method) => {
  let code = 0,
    out = '';
  await mod.handle({ method: method || 'POST' }, { writeHead: c => (code = c), end: s => (out = s) }, p, body);
  return { code: code || 200, j: JSON.parse(out) };
};

run(async () => {
  // ---- what may be closed at all ----
  const keep = ['nl.deltafiber.app.delta'];
  ok(decide.closable('netflix', []) && decide.closable('youtube.leanback.v4', []), 'an ordinary app may be closed');
  ok(
    !decide.closable('com.webos.app.home', []) &&
      !decide.closable('com.webos.app.hdmi1', []) &&
      !decide.closable('com.webos.app.livetv', []),
    "LG's Home, the Inputs and Live TV are never closed"
  );
  ok(
    !decide.closable('com.cleanyourtv.manager', []) && !decide.closable('com.cleanyourtv.picker', []),
    "the launcher's own apps are never closed, so Home does not suffer"
  );
  ok(
    !decide.closable('org.webosbrew.hyperion.ng.loader', []) && !decide.closable('org.webosbrew.hbchannel', []),
    'nor the Homebrew Channel apps: closing the Hyperion loader would end the ambilight for the whole TV'
  );
  ok(!decide.closable('nl.deltafiber.app.delta', keep), 'and not an app the user ticked to leave open');
  ok(!decide.closable('', []) && !decide.closable('../etc/passwd', []), 'something that is not an app id is never closed');

  // ---- the wait ----
  const S = { on: true, delay: 30, keep: [] };
  const ids = x => x.waiting.map(w => w.id).join(',');
  let st = { front: 'netflix', waiting: [] };
  let p = decide.plan(st, 'netflix', S, 0);
  ok(!p.close && !p.waiting.length, 'while one app stays in front nothing waits and nothing closes');

  p = decide.plan(st, 'com.webos.app.home', S, 0);
  ok(ids(p) === 'netflix' && !p.close, 'leaving an app puts it on the clock, it is not closed at once');

  p = decide.plan(p, 'com.webos.app.home', S, 29000);
  ok(!p.close && ids(p) === 'netflix', 'a second before the wait is over it is still running');
  p = decide.plan(p, 'com.webos.app.home', S, 30000);
  ok(p.close === 'netflix' && !p.waiting.length, 'and when the wait is over it is closed once: ' + JSON.stringify(p));

  // what the first test on a TV found: leaving YouTube for Home and walking on to an input threw YouTube's wait away,
  // and it stayed open for good behind HDMI 2. Every app you leave keeps a clock of its own.
  p = decide.plan({ front: 'youtube.leanback.v4', waiting: [] }, 'com.webos.app.home', S, 0);
  p = decide.plan(p, 'com.webos.app.hdmi2', S, 5000);
  ok(ids(p) === 'youtube.leanback.v4', 'walking on to an input keeps the app you left on the clock: ' + ids(p));
  p = decide.plan(p, 'com.webos.app.hdmi2', S, 40000);
  ok(p.close === 'youtube.leanback.v4', 'and it is closed while the TV sits on that input: ' + JSON.stringify(p));

  // two apps left behind: both go, the one you left first ahead of the other
  p = decide.plan({ front: 'netflix', waiting: [] }, 'youtube.leanback.v4', S, 0);
  p = decide.plan(p, 'com.webos.app.home', S, 10000);
  ok(ids(p) === 'netflix,youtube.leanback.v4', 'both apps you left are waiting: ' + ids(p));
  p = decide.plan(p, 'com.webos.app.home', S, 35000);
  ok(p.close === 'netflix' && ids(p) === 'youtube.leanback.v4', 'the one you left first goes first');
  p = decide.plan(p, 'com.webos.app.home', S, 45000);
  ok(p.close === 'youtube.leanback.v4' && !p.waiting.length, 'and the other follows when its own wait is over');

  // coming back cancels it, which is the point of waiting at all
  st = decide.plan({ front: 'netflix', waiting: [] }, 'com.webos.app.home', S, 0);
  st = decide.plan(st, 'netflix', S, 5000);
  ok(!st.waiting.length && !st.close, 'coming back to the app before the wait is over cancels it');

  // ticking an app to stay open takes it off the clock as well
  st = decide.plan({ front: 'netflix', waiting: [] }, 'com.webos.app.home', S, 0);
  st = decide.plan(st, 'com.webos.app.home', { on: true, delay: 30, keep: ['netflix'] }, 40000);
  ok(!st.close && !st.waiting.length, 'an app ticked to stay open while it waits is not closed after all');

  // the TV answers nothing between apps or while it sleeps: that must not look like leaving
  st = decide.plan({ front: 'netflix', waiting: [] }, '', S, 1000);
  ok(st.front === 'netflix' && !st.waiting.length && !st.close, 'no answer from the TV decides nothing');

  // switched off on the page, nothing waits
  st = decide.plan({ front: 'netflix', waiting: [] }, 'com.webos.app.home', { on: false }, 0);
  ok(!st.waiting.length && !st.close, 'with the add-on switched off on its page nothing is closed');

  // ---- the settings are checked before they are kept ----
  const c = decide.cleanSettings({ on: true, delay: 7, keep: ['netflix', 'netflix', '../x', 42] });
  ok(c.delay === decide.DEFAULT_DELAY, 'a wait that is not one of the choices falls back to the default: ' + c.delay);
  ok(c.keep.length === 1 && c.keep[0] === 'netflix', 'the list of apps to leave open holds ids only, once each');

  // ---- the service, with a stand-in TV ----
  const f = fake('netflix'),
    mod = service.create(f.ctx);
  await mod.tick();
  f.front = 'com.webos.app.home';
  await mod.tick();
  ok(!f.calls.some(x => /closeByAppId/.test(x.uri)), 'the service does not close the app the moment you go to Home');
  f.now += 31000;
  await mod.tick();
  const closed = f.calls.filter(x => /closeByAppId/.test(x.uri));
  ok(
    closed.length === 1 && closed[0].payload.id === 'netflix',
    'after the wait it asks the TV to close that one app, once: ' + JSON.stringify(closed)
  );
  f.now += 60000;
  await mod.tick();
  ok(f.calls.filter(x => /closeByAppId/.test(x.uri)).length === 1, 'and it does not keep asking for an app it already closed');

  const state = await post(mod, '/state', null, 'GET');
  ok(
    state.j.front === 'com.webos.app.home' && state.j.closed.length === 1 && state.j.closed[0].id === 'netflix',
    'the page can see what is in front and what was closed: ' + JSON.stringify(state.j.closed)
  );

  const set = await post(mod, '/settings', { delay: 300, keep: ['netflix'] });
  ok(set.j.returnValue && set.j.delay === 300 && set.j.keep[0] === 'netflix', 'the page can change the wait and the list');
  f.front = 'netflix';
  await mod.tick();
  f.front = 'com.webos.app.home';
  await mod.tick();
  f.now += 600000;
  await mod.tick();
  ok(f.calls.filter(x => /closeByAppId/.test(x.uri)).length === 1, 'an app on that list is left running, however long you stay away');

  const bad = await post(mod, '/nope', null, 'GET');
  ok(bad.code === 404, 'an unknown path of the add-on answers 404');
});
