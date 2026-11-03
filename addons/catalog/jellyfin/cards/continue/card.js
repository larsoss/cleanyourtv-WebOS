/* The Continue watching card (ES5: it runs on Chromium 68 too). Everything comes in the message of the launcher: m.data is what the
   Jellyfin add-on's service said, the pictures as data: addresses (the frame has no network). Each title is a button for the remote:
   the launcher puts a target over it, and OK sends the add-on open1, open2 ... which opens the Jellyfin app. */
var M = null,
  D = null,
  last = '';

function el(tag, cls, text) {
  var e = document.createElement(tag);
  if (cls) e.className = cls;
  if (text !== undefined) e.textContent = text;
  return e;
}
/* the size of a tile: as high as the card allows (two lines of text under the picture), narrower when they do not fit side by side;
   the text follows the size of the tiles */
function sizes(n, poster) {
  var W = window.innerWidth,
    H = window.innerHeight,
    ratio = poster ? 2 / 3 : 16 / 9,
    rem = H * 0.1,
    z = null;
  for (var k = 0; k < 2; k++) {
    var text = rem * (0.78 * 1.3 + 0.62 * 1.3 + 0.25),
      gap = Math.round(rem * 0.6),
      h = Math.max(10, H - text),
      w = h * ratio;
    if (n * w + (n - 1) * gap > W) {
      w = (W - (n - 1) * gap) / n;
      h = w / ratio;
    }
    z = { w: Math.floor(w), h: Math.floor(h), gap: gap, rem: rem, top: Math.max(0, Math.floor((H - h - text) / 2)) };
    rem = Math.min(H * 0.1, Math.max(9, w * (poster ? 0.11 : 0.075)));
  }
  return z;
}
function draw() {
  var row = document.getElementById('row'),
    msg = document.getElementById('msg');
  document.documentElement.dir = M.dir || 'ltr';
  document.body.style.color = M.ink || '#fff';
  if (M.font) document.body.style.fontFamily = M.font;
  row.textContent = '';
  msg.textContent = '';
  var items = (D && D.items) || [];
  if (!D) return buttons([]);
  if (!items.length) {
    msg.textContent = D.connected === false ? D.hint || '' : D.error || D.empty || '';
    return buttons([]);
  }
  var poster = D.style === 'poster',
    z = sizes(items.length, poster),
    W = window.innerWidth,
    H = window.innerHeight,
    out = [];
  document.documentElement.style.fontSize = z.rem.toFixed(1) + 'px';
  row.style.top = z.top + 'px';
  items.forEach(function (it, i) {
    var tile = el('div', 'tile'),
      pic = el('div', 'pic');
    tile.style.width = z.w + 'px';
    if (i) tile.style[M.dir === 'rtl' ? 'marginRight' : 'marginLeft'] = z.gap + 'px';
    pic.style.height = z.h + 'px';
    if (it.pic) {
      var im = el('img');
      im.src = it.pic;
      pic.appendChild(im);
    } else pic.appendChild(el('div', 'nopic', it.title));
    if (it.pct > 0) {
      var bar = el('div', 'bar'),
        fill = el('i');
      fill.style.width = Math.max(2, Math.min(100, it.pct)) + '%';
      bar.appendChild(fill);
      pic.appendChild(bar);
    }
    tile.appendChild(pic);
    tile.appendChild(el('div', 't', it.title));
    tile.appendChild(el('div', 's', it.left ? it.sub + (it.sub ? ' · ' : '') + it.left : it.sub));
    row.appendChild(tile);
    /* the target of the remote: the picture of this title, in percent of the card */
    var x = M.dir === 'rtl' ? W - (i + 1) * z.w - i * z.gap : i * (z.w + z.gap);
    out.push({ name: 'open' + (i + 1), x: (x / W) * 100, y: (z.top / H) * 100, w: (z.w / W) * 100, h: (z.h / H) * 100 });
  });
  buttons(out);
}
function buttons(list) {
  var k = JSON.stringify(list);
  if (k === last) return;
  last = k;
  parent.postMessage({ cytvCard: 'buttons', buttons: list }, '*');
}
window.addEventListener('message', function (e) {
  var m = e.data && e.data.cytvCard;
  if (!m || typeof m !== 'object') return;
  M = m;
  D = m.data || null;
  draw();
});
window.addEventListener('resize', function () {
  if (M) draw();
});
parent.postMessage({ cytvCard: 'ready' }, '*');
