/* ---------- Customise > Home Assistant: the cards in the theme's places, chosen with the remote (Couch edition) ----------
   For each place (above the dock, the right column, ...) the kind of card and what it shows: a weather entity and an outside
   temperature sensor, one or more entities, a camera. The entities come from Home Assistant through the service
   (POST /api/cards/ha/entities); the choice is saved with the launcher's settings (cfg.cards, the same as the phone page writes). */
var HAM_PLACES = { greeting: 'Above the clock', 'clock-side': 'Beside the clock', side: 'Right column', row: 'Above the dock' };
var HAM_KINDS = [
  ['none', 'Empty'],
  ['ha-weather', 'Home Assistant weather'],
  ['ha-entity', 'Home Assistant entity'],
  ['ha-entities', 'Home Assistant entities'],
  ['ha-camera', 'Home Assistant camera'],
  ['greeting', 'Greeting'],
];
/* the kinds of entity to choose from for an entity card, in this order */
var HAM_DOMAINS = [
  ['light', 'Lights'],
  ['switch', 'Switches'],
  ['sensor', 'Sensors'],
  ['binary_sensor', 'Binary sensors'],
  ['climate', 'Climate'],
  ['fan', 'Fans'],
  ['cover', 'Covers'],
  ['media_player', 'Media players'],
  ['scene', 'Scenes'],
  ['script', 'Scripts'],
  ['automation', 'Automations'],
  ['input_boolean', 'Helpers'],
];
var hamReady = null; /* Home Assistant set up on the TV? null until asked */
var hamNames = {}; /* entity id -> its name, from the lists already loaded */
function hamPlace(sl) {
  return HAM_PLACES[sl.id] ? t(HAM_PLACES[sl.id]) : sl.id;
}
function hamKind(type) {
  for (var i = 0; i < HAM_KINDS.length; i++) if (HAM_KINDS[i][0] === type) return t(HAM_KINDS[i][1]);
  return type;
}
function hamName(id) {
  return hamNames[id] || (HA.by[id] && HA.by[id].name) || id;
}
/* the card a place shows now: the chosen one, or the theme's own, or none */
function hamCard(sl) {
  var c = (cfg.cards || {})[sl.id];
  if (c && c.type) return c;
  return { type: sl.card || 'none' };
}
function hamSave(sl, c) {
  var all = {},
    k;
  for (k in cfg.cards || {}) all[k] = cfg.cards[k];
  all[sl.id] = c;
  cfg.cards = all;
  saveCfg();
}
/* a copy of the place's card to change (so the menu keeps showing the saved one until it is saved) */
function hamCopy(sl) {
  var c = hamCard(sl),
    o = {},
    k;
  for (k in c) o[k] = c[k];
  return o;
}
/* what a card shows, in a few words, for the row of its place */
function hamSummary(c) {
  if (c.type === 'ha-weather' || c.type === 'ha-entity' || c.type === 'ha-camera')
    return hamKind(c.type) + (c.entity ? ' · ' + hamName(c.entity) : '');
  if (c.type === 'ha-entities') {
    var n = String(c.entities || '')
      .split(/[\s,]+/)
      .filter(function (x) {
        return x;
      }).length;
    return hamKind(c.type) + ' · ' + n;
  }
  return hamKind(c.type);
}
/* Home Assistant's entities of some domains (all with none), then a menu to choose one; extra rows come first */
function hamPick(title, domains, keep, extra, cb) {
  toast(t('Asking Home Assistant...'));
  api('/api/cards/ha/entities', { domains: domains })
    .then(function (r) {
      $('toast').classList.remove('on');
      hamReady = r.ha !== false;
      if (r.error) return toast(t(r.error), true);
      var list = (r.entities || []).filter(function (e) {
        hamNames[e.id] = e.name;
        return !keep || keep(e);
      });
      if (!list.length && !(extra || []).length) return toast(t('Home Assistant has no entities of this kind.'), true);
      openMenu(
        title,
        (extra || []).concat(list).map(function (e) {
          return {
            label: e.name !== undefined ? e.name : e.label,
            sub: e.id ? e.id + (e.unit ? ' · ' + e.unit : '') : '',
            stay: true,
            fn: function () {
              cb(e.id || '');
            },
          };
        })
      );
    })
    .catch(function () {
      toast(t('The service did not answer.'), true);
    });
}
/* first the kind of entity, then the entity */
function hamPickAny(title, cb) {
  openMenu(
    title,
    HAM_DOMAINS.map(function (d) {
      return {
        label: t(d[1]),
        stay: true,
        fn: function () {
          hamPick(t(d[1]), [d[0]], null, null, function (id) {
            cb(id);
            backMenu();
            backMenu();
          });
        },
      };
    })
  );
}
/* Customise > Home Assistant: the places of the theme with what each shows */
function haMenu() {
  if (hamReady === null)
    api('/api/cards/status', {}).then(
      function (s) {
        hamReady = !!s.ha;
        refreshMenu();
      },
      function () {}
    );
  openBuilt('Home Assistant', function () {
    var items = (TH.slots || []).map(function (sl) {
      return {
        label: hamPlace(sl),
        sub: hamSummary(hamCard(sl)),
        stay: true,
        fn: function () {
          hamPlaceMenu(sl);
        },
      };
    });
    if (!items.length)
      items.push({ note: t('This theme has no places for cards. Choose a theme with cards (Lock Screen) in Customise > Theme.') });
    if (hamReady === false)
      items.push(
        { sep: true },
        { note: t('Home Assistant is not set up yet: set its address and token in the manager app, More > Home Assistant.') },
        {
          label: t('More settings...'),
          sub: t('in the CleanYourTV app'),
          fn: function () {
            launch('com.cleanyourtv.manager');
          },
        }
      );
    return items;
  });
}
/* one place: the kind of card, then what it shows */
function hamPlaceMenu(sl) {
  openBuilt(hamPlace(sl), function () {
    var c = hamCard(sl),
      items = [
        {
          label: t('Card'),
          sub: hamKind(c.type),
          stay: true,
          fn: function () {
            hamKindMenu(sl);
          },
        },
      ];
    if (c.type === 'ha-weather') {
      var show = c.show === 'hourly' ? t('The next hours') : c.show === 'none' ? t('None') : t('The next days');
      items.push(
        {
          label: t('Weather entity'),
          sub: c.entity ? hamName(c.entity) : t('Choose...'),
          stay: true,
          fn: function () {
            hamPick(t('Weather entity'), ['weather'], null, null, function (id) {
              var o = hamCopy(sl);
              o.entity = id;
              hamSave(sl, o);
              backMenu();
            });
          },
        },
        {
          label: t('Outside temperature'),
          sub: c.temp ? hamName(c.temp) : t('From the weather entity'),
          stay: true,
          fn: function () {
            hamPick(
              t('Outside temperature'),
              ['sensor'],
              function (e) {
                return /°\s?[CF]$/.test(e.unit);
              },
              [{ label: t('From the weather entity'), id: '' }],
              function (id) {
                var o = hamCopy(sl);
                if (id) o.temp = id;
                else delete o.temp;
                hamSave(sl, o);
                backMenu();
              }
            );
          },
        },
        {
          label: t('Forecast'),
          sub: show,
          stay: true,
          fn: function () {
            var o = hamCopy(sl);
            o.show = !o.show ? 'hourly' : o.show === 'hourly' ? 'none' : '';
            if (!o.show) delete o.show;
            hamSave(sl, o);
          },
        }
      );
    }
    if (c.type === 'ha-entity')
      items.push({
        label: t('Entity'),
        sub: c.entity ? hamName(c.entity) : t('Choose...'),
        stay: true,
        fn: function () {
          hamPickAny(t('Entity'), function (id) {
            var o = hamCopy(sl);
            o.entity = id;
            hamSave(sl, o);
          });
        },
      });
    if (c.type === 'ha-entities') {
      var ids = String(c.entities || '')
        .split(/[\s,]+/)
        .filter(function (x) {
          return x;
        });
      ids.forEach(function (id) {
        items.push({
          label: hamName(id),
          sub: t('OK removes it'),
          stay: true,
          fn: function () {
            var o = hamCopy(sl);
            o.entities = ids
              .filter(function (x) {
                return x !== id;
              })
              .join('\n');
            hamSave(sl, o);
          },
        });
      });
      if (ids.length < 12)
        items.push({
          label: t('Add an entity'),
          stay: true,
          fn: function () {
            hamPickAny(t('Add an entity'), function (id) {
              var o = hamCopy(sl);
              if (ids.indexOf(id) < 0) o.entities = ids.concat(id).join('\n');
              hamSave(sl, o);
            });
          },
        });
    }
    if (c.type === 'ha-camera') {
      var ev = +c.every || 10;
      items.push(
        {
          label: t('Camera'),
          sub: c.entity ? hamName(c.entity) : t('Choose...'),
          stay: true,
          fn: function () {
            hamPick(t('Camera'), ['camera'], null, null, function (id) {
              var o = hamCopy(sl);
              o.entity = id;
              hamSave(sl, o);
              backMenu();
            });
          },
        },
        {
          label: t('New picture'),
          sub: ev === 60 ? t('Every minute') : ev === 30 ? t('Every 30 seconds') : t('Every 10 seconds'),
          stay: true,
          fn: function () {
            var o = hamCopy(sl);
            o.every = ev === 10 ? '30' : ev === 30 ? '60' : '';
            if (!o.every) delete o.every;
            hamSave(sl, o);
          },
        }
      );
    }
    items.push({ sep: true }, { note: t('Names and texts for the other cards are typed on your phone: Cards in the CleanYourTV app.') });
    return items;
  });
}
/* the kind of card for a place; the options stay when the same kind is chosen again */
function hamKindMenu(sl) {
  var cur = hamCard(sl).type;
  openMenu(
    hamPlace(sl),
    HAM_KINDS.map(function (k) {
      return {
        label: t(k[1]),
        sub: k[0] === cur ? '✓' : '',
        stay: true,
        fn: function () {
          if (k[0] !== cur) hamSave(sl, { type: k[0] });
          backMenu();
        },
      };
    }),
    Math.max(
      0,
      HAM_KINDS.map(function (k) {
        return k[0];
      }).indexOf(cur)
    )
  );
}
