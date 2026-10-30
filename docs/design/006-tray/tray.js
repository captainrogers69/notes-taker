// 006 · Hide to tray (throwaway prototype, not app code).
// Mini bar + shared sheet, plus where the bar goes when hidden on each platform:
// macOS menu bar · Windows system tray · Linux top-bar tray · Android notification.
(() => {
  'use strict';

  const { mount, draggable, bindThemeButtons, clamp } = WeaveSheet;
  const $ = (id) => document.getElementById(id);
  const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const svg = (d, w = 1.8) => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round">${d}</svg>`;

  const LOGO = svg('<path d="M3 7l4.5 10L12 7l4.5 10L21 7"/>', 2.6);
  const ICO = {
    wifi: svg('<path d="M2 9a15 15 0 0120 0M5.5 12.5a10 10 0 0113 0M9 16a5 5 0 016 0"/><circle cx="12" cy="19" r=".8"/>'),
    batt: svg('<rect x="2" y="7" width="18" height="10" rx="2"/><path d="M22 11v2"/><rect x="4" y="9" width="11" height="6" rx="1" fill="currentColor"/>'),
    vol: svg('<path d="M4 9h4l5-4v14l-5-4H4z"/><path d="M16 9a4 4 0 010 6"/>'),
    cc: svg('<rect x="3" y="5" width="18" height="6" rx="3"/><rect x="3" y="13" width="18" height="6" rx="3"/><circle cx="8" cy="8" r="1.5"/><circle cx="16" cy="16" r="1.5"/>'),
  };
  const BAR_I = svg('<rect x="3" y="9" width="18" height="6" rx="3"/>');
  const BELL_OFF = svg('<path d="M6 16v-5a6 6 0 0110-4.5M18 11v5l1.5 2H8"/><path d="M10 20.5a2 2 0 004 0M3 3l18 18"/>');
  const BT = svg('<path d="M7 7l10 10-5 4V3l5 4L7 17"/>');
  const MOON = svg('<path d="M20 14.5A8 8 0 019.5 4 8 8 0 1020 14.5z"/>');

  const LABEL = { macos: 'Hide to menu bar', windows: 'Hide to system tray', linux: 'Hide to tray', android: 'Hide to notification' };
  const HOTKEY = { macos: '⌥ Space', windows: 'Alt+Space', linux: 'Alt+Space', android: '' };
  const STEPS = {
    macos: [
      'Tap the bar, then <b>⌄</b> (or ⌘H) to hide it into the <b>menu bar</b>.',
      'Click <b>W</b> in the menu bar: the same sheet drops down, with <b>Show bar</b> and <b>Pause reminders</b>.',
      '⌥Space still opens it while the bar is hidden.',
    ],
    windows: [
      'Tap the bar, then <b>⌄</b> (or Ctrl+H) to hide it into the <b>system tray</b>.',
      'Click <b>W</b> in the tray (bottom right): the sheet opens above the taskbar, with Show bar and Pause reminders.',
      'Windows may tuck new tray icons under <b>^</b>; we ask once to keep Weave visible.',
    ],
    linux: [
      'Tap the bar, then <b>⌄</b> (or Ctrl+H) to hide it into the <b>tray</b> in the top bar.',
      'Click <b>W</b>: the sheet drops down, with Show bar and Pause reminders.',
      'GNOME needs the AppIndicator extension for tray icons. Without one, Alt+Space and the app still work.',
    ],
    android: [
      'Tap the bar, then <b>⌄</b> to hide it into a <b>notification</b> (W appears in the status bar).',
      'Tap the <b>status bar</b> to pull down the shade: Add task, Show bar, Pause 1 h. Tap the card to open the sheet.',
      'The <b>Weave bar</b> quick-settings tile hides or shows the bar from anywhere.',
    ],
  };

  const hash = new URLSearchParams(location.hash.slice(1));
  let os = STEPS[hash.get('os')] ? hash.get('os') : 'macos';
  let hidden = hash.get('hidden') === '1';
  let paused = false;
  let anchor = hidden ? 'tray' : 'bar'; // where the sheet opens from
  let shadeOpen = false;
  let phoneScale = 1;
  let list = null, left = 0;
  const pos = {};

  const desk = $('desk'), phone = $('phone'), bar = $('minibar'), shade = $('shade'), pnotif = $('pnotif');
  const trays = ['macos', 'windows', 'linux'].map((o) => $('tray-' + o));

  document.querySelectorAll('.ti').forEach((e) => { e.innerHTML = LOGO; });
  document.querySelectorAll('.ico').forEach((e) => { const k = [...e.classList].find((c) => ICO[c]); if (k) e.innerHTML = ICO[k]; });
  $('pgrid').innerHTML = '<i></i>'.repeat(12);

  // ---------- Geometry (all in container coordinates) ----------
  const container = () => (os === 'android' ? phone : desk);
  const scale = () => (os === 'android' ? phoneScale : 1);
  const trayEl = () => (os === 'android' ? pnotif : $('tray-' + os));
  function area() {
    if (os === 'android') return { x: 0, y: 44, w: 393, h: 852 - 44 - 24 };
    const W = innerWidth, H = innerHeight;
    if (os === 'macos') return { x: 0, y: 25, w: W, h: H - 25 };
    if (os === 'windows') return { x: 0, y: 0, w: W, h: H - 48 };
    return { x: 0, y: 30, w: W, h: H - 30 };
  }
  function rel(el) {
    const c = container().getBoundingClientRect(), r = el.getBoundingClientRect(), s = scale();
    return { x: (r.left - c.left) / s, y: (r.top - c.top) / s, w: r.width / s, h: r.height / s };
  }
  function applyPos() {
    const a = area();
    const p = pos[os];
    p.x = clamp(p.x, a.x + 12, a.x + a.w - bar.offsetWidth - 12);
    p.y = clamp(p.y, a.y + 12, a.y + a.h - bar.offsetHeight - 12);
    bar.style.left = p.x + 'px';
    bar.style.top = p.y + 'px';
  }
  function fitPhone() {
    phoneScale = Math.min(1, (innerHeight - 40) / 872, (innerWidth - 40) / 413);
    phone.style.transform = `scale(${phoneScale})`;
  }

  function place(win) {
    const w = win.offsetWidth, h = win.offsetHeight, a = area();
    win.classList.toggle('from-tray', anchor === 'tray');
    let x, y, origin, slide = '-8px';
    if (anchor === 'tray' && os === 'android') {
      x = (393 - w) / 2; y = 52; origin = 'center top';
    } else if (anchor === 'tray') {
      const t = rel(trayEl());
      const maxX = innerWidth - w - 8;
      if (os === 'windows') { x = clamp(t.x + t.w - w, 8, maxX); y = a.y + a.h - 8 - h; origin = 'right bottom'; slide = '8px'; }
      else if (os === 'linux') { x = clamp(t.x + t.w / 2 - w / 2, 8, maxX); y = a.y + 6; origin = 'center top'; }
      else { x = clamp(t.x + t.w - w, 8, maxX); y = a.y + 6; origin = 'right top'; }
    } else {
      const r = rel(bar);
      const below = r.y + r.h + 8 + h <= a.y + a.h - 8;
      x = clamp(r.x, a.x + 12, a.x + a.w - w - 12);
      y = below ? r.y + r.h + 8 : Math.max(a.y + 8, r.y - 8 - h);
      origin = `${r.x + 24 - x}px ${below ? 'top' : 'bottom'}`;
      slide = below ? '-8px' : '8px';
    }
    win.style.left = x + 'px';
    win.style.top = y + 'px';
    win.style.setProperty('--origin', origin);
    win.style.setProperty('--slide-y', slide);
  }

  // ---------- Sheet ----------
  const footHtml = () => `
    <button class="fbtn" data-act="showBar">${BAR_I}${hidden ? 'Show bar' : 'Hide bar'}</button>
    <span class="spacer"></span>
    <button class="fbtn ${paused ? 'on' : ''}" data-act="pause">${BELL_OFF}${paused ? 'Paused till 17:20 · Resume' : 'Pause reminders 1 h'}</button>`;

  const sheet = mount({
    trigger: bar,
    container: desk,
    ignore: trays,
    place,
    hideLabel: () => (hidden ? '' : LABEL[os]),
    onHide: () => setHidden(true),
    footer: () => (anchor === 'tray' ? footHtml() : ''),
    onAction(act) {
      if (act === 'showBar') { sheet.close(); setHidden(!hidden); }
      if (act === 'pause') { paused = !paused; sheet.render(); updateTray(); }
    },
    onRender(p, n, color) {
      list = p; left = n;
      bar.style.setProperty('--accent', color);
      $('name').textContent = p.name;
      $('meta').textContent = n ? `${n} left` : 'All done';
      if (!bar.hidden && pos[os]) applyPos();
      updateTray();
    },
  });

  bar.addEventListener('weave:toggle', (e) => {
    trays.forEach((t) => t.classList.toggle('is-open', e.detail && anchor === 'tray' && t === trayEl()));
  });

  // ---------- Bar drag / tap ----------
  let origin = null;
  draggable(bar, {
    onStart(phase) { if (phase === 'down') origin = { ...pos[os] }; else sheet.close(); },
    onMove(dx, dy) { pos[os] = { x: origin.x + dx / scale(), y: origin.y + dy / scale() }; applyPos(); },
    onTap() {
      if (sheet.isOpen() && anchor === 'tray') sheet.close();
      anchor = 'bar';
      sheet.toggle();
    },
  });

  // ---------- Tray icons ----------
  trays.forEach((t) => t.addEventListener('click', () => {
    if (sheet.isOpen() && anchor === 'tray') return sheet.close();
    sheet.close();
    anchor = 'tray';
    sheet.open();
  }));

  function updateTray() {
    trays.forEach((t) => {
      t.querySelector('.tcount').textContent = left || '';
      t.classList.toggle('paused', paused);
    });
    if (shadeOpen) renderShade();
  }

  // ---------- Hide / show ----------
  function flyTransform(b, t) {
    return `translate(${t.x + t.w / 2 - (b.x + b.w / 2)}px, ${t.y + t.h / 2 - (b.y + b.h / 2)}px) scale(.12)`;
  }

  function setHidden(h) {
    const t = trayEl();
    if (h) {
      if (os === 'android') pnotif.classList.add('show');
      const tr = rel(t), b = rel(bar);
      bar.style.transition = 'transform .4s cubic-bezier(.5, 0, .2, 1), opacity .4s';
      bar.style.transform = flyTransform(b, tr);
      bar.style.opacity = '0';
      setTimeout(() => {
        bar.hidden = true;
        bar.style.transition = bar.style.transform = bar.style.opacity = '';
        t.classList.remove('pop'); void t.offsetWidth; t.classList.add('pop');
      }, 400);
    } else {
      const tr = rel(t);
      if (os === 'android') pnotif.classList.remove('show');
      bar.hidden = false;
      applyPos();
      const b = rel(bar);
      bar.style.transition = 'none';
      bar.style.transform = flyTransform(b, tr);
      bar.style.opacity = '0';
      void bar.offsetWidth;
      bar.style.transition = 'transform .4s cubic-bezier(.2, .8, .2, 1), opacity .4s';
      bar.style.transform = '';
      bar.style.opacity = '';
      setTimeout(() => { bar.style.transition = ''; }, 420);
    }
    hidden = h;
    anchor = h ? 'tray' : 'bar';
    sheet.render();
    renderShade();
  }

  // ---------- Android shade ----------
  function renderShade() {
    if (!list) return;
    const open = list.items.filter((i) => !i.d).slice(-2).reverse();
    shade.innerHTML = `
      <div class="qs">
        <button class="qt" data-act="noop">${ICO.wifi}<div>Internet<small>Home Wi-Fi</small></div></button>
        <button class="qt" data-act="noop">${BT}<div>Bluetooth<small>Off</small></div></button>
        <button class="qt" data-act="noop">${MOON}<div>Do Not Disturb<small>Off</small></div></button>
        <button class="qt ${hidden ? '' : 'on'}" data-act="qsWeave">${LOGO}<div>Weave bar<small>${hidden ? 'Hidden' : 'On screen'}</small></div></button>
      </div>
      ${hidden ? `
      <div class="ncard" data-act="nopen">
        <div class="nhead"><span class="ti">${LOGO}</span>Weave · now${paused ? ' · reminders paused' : ''}</div>
        <div class="ntitle">${esc(list.name)} · ${left ? left + ' left' : 'All done'}</div>
        <div class="nbody">${open.map((i) => esc(i.t)).join(' · ') || 'Nothing left'}</div>
        <div class="nacts">
          <button data-act="nadd">Add task</button>
          <button data-act="nshow">Show bar</button>
          <button data-act="npause">${paused ? 'Resume' : 'Pause 1 h'}</button>
        </div>
      </div>` : '<div class="nonotif">No notifications</div>'}
      <div class="shandle"></div>`;
  }
  function setShade(open) {
    shadeOpen = open;
    if (open) { sheet.close(); renderShade(); }
    shade.classList.toggle('open', open);
  }
  const afterShade = (fn) => { setShade(false); setTimeout(fn, 260); };

  $('pstatus').addEventListener('click', () => setShade(!shadeOpen));
  shade.addEventListener('click', (e) => {
    const b = e.target.closest('[data-act]');
    const act = b ? b.dataset.act : 'close';
    if (act === 'noop') return;
    if (act === 'npause') { paused = !paused; renderShade(); updateTray(); return; }
    if (act === 'nopen' || act === 'nadd') return afterShade(() => { anchor = 'tray'; sheet.open(); });
    if (act === 'nshow' || act === 'qsWeave') return afterShade(() => setHidden(act === 'qsWeave' ? !hidden : false));
    setShade(false);
  });
  document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && shadeOpen) setShade(false); });

  // ---------- Platform switch ----------
  function setOs(o) {
    sheet.close();
    setShade(false);
    os = o;
    document.body.className = `os-${o}${o === 'android' ? ' is-phone' : ''}`;
    container().appendChild(bar);
    container().appendChild(sheet.win);
    fitPhone();
    if (!pos[o]) {
      const a = area();
      pos[o] = o === 'android' ? { x: 24, y: 250 } : { x: Math.round(a.w / 2 - 110), y: a.y + 40 };
    }
    $('hotkey').textContent = HOTKEY[o];
    $('hotkey').hidden = !HOTKEY[o];
    pnotif.classList.toggle('show', hidden && o === 'android');
    bar.hidden = hidden;
    anchor = hidden ? 'tray' : 'bar';
    sheet.render();
    if (!hidden) applyPos();
    $('steps').innerHTML = STEPS[o].map((s) => `<li>${s}</li>`).join('');
    document.querySelectorAll('#osCtl [data-os]').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.os === o)));
  }

  $('osCtl').addEventListener('click', (e) => { const b = e.target.closest('[data-os]'); if (b) setOs(b.dataset.os); });
  addEventListener('resize', () => { fitPhone(); if (!bar.hidden) applyPos(); sheet.reposition(); });

  bindThemeButtons();
  setOs(os);
  if (hidden) { const t = trayEl(); t.classList.add('pop'); }
})();
