// The Close apps add-on: an app you left is closed a while later, so the TV gets its memory back.
// webOS keeps an app you walked away from in memory, and this TV has about 1 GB for everything: with two or three apps left open the
// kernel spends its time swapping to the eMMC and the whole TV turns slow. The add-on watches which app is in front
// (applicationManager/getForegroundAppInfo), and when you go somewhere else it closes the one you left after the wait you chose
// (closeByAppId, the call the launcher's own Running apps menu uses). Come back before the wait is over and nothing happens.
// The user chooses on the add-on's page which apps are left running; the launcher's own apps, LG's Home, the Inputs, Live TV and the
// Homebrew Channel's apps (the Hyperion and HyperHDR loaders for ambilight) are never closed, whatever is chosen (decide.js).
//   GET  /api/addons/closeapps/state                 what it does now and what it last closed
//   POST /api/addons/closeapps/settings {on, delay, keep}
const decide = require('./decide');

const TICK = 5000; // how often the app in front is asked
const LOG_KEEP = 10;

function create(ctx) {
  const state = { front: '', waiting: [] };
  const closed = []; // the last ones, newest first: {id, at}
  let timer = null,
    busy = false,
    lastError = '';

  const settings = () => decide.cleanSettings(ctx.settings.get());
  const now = () => (ctx.now ? ctx.now() : Date.now());

  async function front() {
    const r = await ctx.luna('luna://com.webos.applicationManager/getForegroundAppInfo', {});
    if (!r || r.returnValue === false) return '';
    // webOS 6 answers appId; newer ones a list of windows, the full-screen one first
    if (r.appId) return String(r.appId);
    const list = Array.isArray(r.foregroundAppInfo) ? r.foregroundAppInfo : [];
    for (const w of list) if (w && w.appId && (!w.windowType || w.windowType === '_WEBOS_WINDOW_TYPE_CARD')) return String(w.appId);
    return list.length && list[0].appId ? String(list[0].appId) : '';
  }

  async function close(id) {
    let r = await ctx.luna('luna://com.webos.applicationManager/closeByAppId', { id });
    if (!r || r.returnValue === false) r = await ctx.luna('luna://com.webos.applicationManager/close', { id });
    const ok = !!(r && r.returnValue !== false);
    if (ok) {
      closed.unshift({ id, at: now() });
      closed.length = Math.min(closed.length, LOG_KEEP);
      ctx.log('closed ' + id + ' (left ' + Math.round(settings().delay) + 's ago)');
    } else {
      lastError = (r && r.errorText) || 'closeByAppId failed';
      ctx.log('could not close ' + id + ': ' + lastError);
    }
    return ok;
  }

  async function tick() {
    if (busy) return;
    busy = true;
    try {
      const id = await front(),
        p = decide.plan(state, id, settings(), now());
      state.front = p.front;
      state.waiting = p.waiting;
      if (p.close) await close(p.close);
      lastError = '';
    } catch (e) {
      lastError = String((e && e.message) || e);
    } finally {
      busy = false;
    }
  }

  return {
    start: () => {
      timer = setInterval(tick, TICK);
      if (timer.unref) timer.unref();
    },
    stop: () => {
      if (timer) clearInterval(timer);
      timer = null;
    },
    tick, // the tests step it themselves
    handle: async (req, res, p, body) => {
      const json = (o, code) => {
        res.writeHead(code || 200, { 'content-type': 'application/json' });
        res.end(JSON.stringify(o));
      };
      if (p === '/state') {
        const s = settings(),
          soon = state.waiting.slice().sort((a, b) => a.at - b.at)[0]; // the next one to go
        return json({
          on: s.on,
          delay: s.delay,
          delays: decide.DELAYS,
          keep: s.keep,
          front: state.front,
          waiting: soon ? soon.id : '',
          waitingFor: soon ? Math.max(0, Math.round((now() - soon.at) / 1000)) : 0,
          waitingAll: state.waiting.map(x => x.id),
          closed: closed.slice(),
          error: lastError,
        });
      }
      if (p === '/settings' && req.method === 'POST') {
        const b = body && typeof body === 'object' ? body : {};
        const cur = settings();
        const next = decide.cleanSettings({
          on: typeof b.on === 'boolean' ? b.on : cur.on,
          delay: typeof b.delay === 'number' ? b.delay : cur.delay,
          keep: Array.isArray(b.keep) ? b.keep : cur.keep,
        });
        ctx.settings.set(next);
        if (!next.on) state.waiting = [];
        return json({ returnValue: true, on: next.on, delay: next.delay, keep: next.keep });
      }
      return json({ error: 'not found' }, 404);
    },
  };
}

module.exports = { create };
