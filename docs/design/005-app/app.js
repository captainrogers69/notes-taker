// Weave full app prototype (throwaway, not app code).
// One state, two layouts: desktop (sidebar · list · details) and phone (home · list · bottom sheets).
(() => {
  'use strict';

  // ---------- Icons ----------
  const svg = (d, fill = 'none') => `<svg viewBox="0 0 24 24" fill="${fill}" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">${d}</svg>`;
  const I = {
    logo: svg('<path d="M3 7l4.5 10L12 7l4.5 10L21 7"/>').replace('<svg', '<svg class="logo"'),
    search: svg('<circle cx="11" cy="11" r="6.5"/><path d="M16 16l4.5 4.5"/>'),
    pin: svg('<path d="M9 4h6l-1 5 3 3H7l3-3-1-5z"/><path d="M12 12v8"/>'),
    float: svg('<rect x="3" y="4" width="18" height="14" rx="2"/><rect x="11" y="7" width="7" height="4" rx="1"/>'),
    share: svg('<path d="M12 15V4M8 8l4-4 4 4"/><path d="M5 12v7a1 1 0 001 1h12a1 1 0 001-1v-7"/>'),
    more: svg('<circle cx="5" cy="12" r="1.4"/><circle cx="12" cy="12" r="1.4"/><circle cx="19" cy="12" r="1.4"/>', 'currentColor'),
    bell: svg('<path d="M6 16v-5a6 6 0 1112 0v5l1.5 2h-15L6 16z"/><path d="M10 20.5a2 2 0 004 0"/>'),
    cal: svg('<rect x="4" y="5" width="16" height="15" rx="2"/><path d="M4 10h16M9 3v4M15 3v4"/>'),
    repeat: svg('<path d="M17 2l3 3-3 3"/><path d="M4 11V9a4 4 0 014-4h12M7 22l-3-3 3-3"/><path d="M20 13v2a4 4 0 01-4 4H4"/>'),
    text: svg('<path d="M5 7V5h14v2M12 5v14M9 19h6"/>'),
    x: svg('<path d="M6 6l12 12M18 6L6 18"/>'),
    back: svg('<path d="M15 5l-7 7 7 7"/>'),
    plus: svg('<path d="M12 5v14M5 12h14"/>'),
    archive: svg('<rect x="3" y="4" width="18" height="5" rx="1"/><path d="M5 9v10h14V9M10 13h4"/>'),
    trash: svg('<path d="M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3"/>'),
    gear: svg('<circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9L7 7M17 17l2.1 2.1M4.9 19.1L7 17M17 7l2.1-2.1"/>'),
    user: svg('<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0116 0"/>'),
    copy: svg('<rect x="8" y="8" width="12" height="12" rx="2"/><path d="M16 8V5a1 1 0 00-1-1H5a1 1 0 00-1 1v10a1 1 0 001 1h3"/>'),
    md: svg('<rect x="3" y="6" width="18" height="12" rx="2"/><path d="M7 15V9l2.5 3L12 9v6M16 9v6M14 13l2 2 2-2"/>'),
    image: svg('<rect x="3" y="4" width="18" height="16" rx="2"/><circle cx="9" cy="10" r="2"/><path d="M21 17l-5-5-9 8"/>'),
    undo: svg('<path d="M9 14L4 9l5-5"/><path d="M4 9h11a5 5 0 010 10h-3"/>'),
    menu: svg('<path d="M4 7h16M4 12h16M4 17h16"/>'),
  };
  const winMin = '<svg viewBox="0 0 12 12"><path d="M1 6h10" stroke="currentColor"/></svg>';
  const winMax = '<svg viewBox="0 0 12 12"><rect x="1.5" y="1.5" width="9" height="9" fill="none" stroke="currentColor"/></svg>';
  const winX = '<svg viewBox="0 0 12 12"><path d="M1 1l10 10M11 1L1 11" stroke="currentColor"/></svg>';

  // ---------- Data ----------
  // Note colors come from tokens.css: --nX = fill, --nX-ink = text-safe shade.
  const COLORS = [0, 1, 2, 3, 4, 5].map((i) => `var(--n${i})`);
  let nextId = 1000;
  const id = () => ++nextId;
  const C = (t, extra = {}) => ({ id: id(), type: 'check', t, d: false, indent: 0, ...extra });
  const T = (t) => ({ id: id(), type: 'text', t, indent: 0 });

  const lists = [
    { id: 1, name: 'Today', color: 0, pinned: true, onScreen: true, items: [
      T('Errands before 6pm, calls after.'),
      C('Reply to design review', { dueDay: 'Today', dueTime: '17:00', rem: '15 min before' }),
      C('Buy milk'),
      C('Call mom', { rem: 'in 2 h' }),
      C('Book dentist', { d: true }),
    ] },
    { id: 2, name: 'Weave', color: 1, pinned: true, items: [
      C('Pick the floating design', { d: true }),
      C('Design the full app'),
      C('Choose a backend', { dueDay: 'Next week', dueTime: '9:00' }),
      C('Write the sync tests'),
      C('Two-device convergence', { indent: 1 }),
      C('Finish architecture playbook', { d: true }),
    ] },
    { id: 3, name: 'Groceries', color: 2, items: [
      C('Eggs'), C('Coffee beans'), C('Oat milk'), C('Bread', { d: true }),
    ] },
    { id: 4, name: 'Packing — Goa', color: 3, items: [
      C('Passport', { d: true }), C('Sunscreen', { d: true }), C('Chargers'), C('Swimwear', { d: true }), C('Sunglasses'),
    ] },
    { id: 5, name: 'Ideas', color: 4, items: [
      T('Widget that shows only the next 3 tasks.'),
      T('Shake to undo on mobile?'),
    ] },
    { id: 6, name: 'Weekly reset', color: 5, items: [
      C('Plan the week', { dueDay: 'Next week', dueTime: '9:00', repeat: 'Weekly', rem: 'At due time' }),
      C('Water plants', { repeat: 'Weekly' }),
      C('Pay rent', { dueDay: 'Next week', dueTime: '9:00', repeat: 'Monthly', rem: '1 day before' }),
    ] },
  ];
  const archived = [
    { id: 7, name: 'Sprint 12', color: 1, pinned: false, items: [C('Ship onboarding', { d: true }), C('Retro notes', { d: true })] },
  ];
  const trashed = [
    { id: 8, name: 'Old draft', color: 5, pinned: false, deletedDaysAgo: 3, items: [T('Scratch text')] },
  ];

  // ---------- State ----------
  const hash = new URLSearchParams(location.hash.slice(1));
  const state = {
    os: hash.get('os') || (/Mac/.test(navigator.platform) ? 'macos' : /Win/.test(navigator.platform) ? 'windows' : 'linux'),
    theme: hash.get('mode') || (localStorage.getItem('weave-mode') || 't-dark').replace('t-', ''),
    cur: (lists.find((l) => l.name === hash.get('list')) || lists[0]).id,
    view: 'list',        // desktop main: list | search | archive | trash | settings
    screen: 'home',      // phone: home | list | search | archive | trash | settings
    sel: null,           // item id shown in details
    menu: null,          // desktop popover: color | share | more
    psheet: null,        // phone bottom sheet: details | color | share | more | menu
    showDone: false,
    query: '',
    sync: 'synced',
    newItem: null,
    toast: null,
  };
  if (hash.get('list')) state.screen = 'list';

  const isPhone = () => state.os === 'ios' || state.os === 'android';
  const mod = () => (state.os === 'macos' || state.os === 'ios' ? '⌘' : 'Ctrl+');
  const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const col = (l) => COLORS[l.color % COLORS.length];
  const ink = (l) => `var(--n${l.color % COLORS.length}-ink)`;
  const cur = () => lists.find((l) => l.id === state.cur) || lists[0];
  const openCount = (l) => l.items.filter((i) => i.type === 'check' && !i.d).length;
  const findItem = (iid) => {
    for (const l of lists) { const it = l.items.find((i) => i.id === iid); if (it) return { l, it }; }
    return {};
  };
  const SYNC = { synced: 'Synced', syncing: 'Syncing…', offline: 'Offline', error: 'Sync error' };
  const floatLabel = () => (state.os === 'ios' ? 'Add to widget' : 'Show on screen (mini bar)');

  // ---------- Shared fragments ----------
  const syncBtn = () => `<button class="sync s-${state.sync}" data-act="sync" title="Sync status (click to cycle for demo)"><i></i>${SYNC[state.sync]}</button>`;

  function chips(it) {
    const c = [];
    if (it.dueDay) c.push(`<button class="chip due" data-act="details" data-id="${it.id}">${I.cal}${it.dueDay} ${it.dueTime || ''}</button>`);
    if (it.rem) c.push(`<button class="chip" data-act="details" data-id="${it.id}">${I.bell}${it.rem}</button>`);
    if (it.repeat) c.push(`<button class="chip" data-act="details" data-id="${it.id}">${I.repeat}${it.repeat}</button>`);
    return c.length ? `<div class="chips">${c.join('')}</div>` : '';
  }

  const row = (it) => `
    <li class="row type-${it.type} ${it.d ? 'is-done' : ''} ${it.indent ? 'ind' : ''} ${state.sel === it.id ? 'is-sel' : ''} ${state.newItem === it.id ? 'new' : ''}" data-id="${it.id}">
      <span class="grip" title="Drag to reorder"></span>
      ${it.type === 'check'
        ? `<button class="check" data-act="tick" data-id="${it.id}" aria-label="${it.d ? 'Uncheck' : 'Check'} ${esc(it.t)}"></button>`
        : '<span class="spacer"></span>'}
      <div class="body">
        <div class="txt" contenteditable="true" spellcheck="false" data-edit="${it.id}">${esc(it.t)}</div>
        ${chips(it)}
      </div>
      ${it.type === 'check' ? `<button class="iconbtn rowbtn" data-act="details" data-id="${it.id}" title="Due, reminder, repeat">${I.bell}</button>` : ''}
    </li>`;

  function itemsHtml(l) {
    const open = l.items.filter((i) => !(i.type === 'check' && i.d));
    const done = l.items.filter((i) => i.type === 'check' && i.d);
    return `
      <ul class="items">${open.map(row).join('')}</ul>
      ${!l.items.length ? '<p class="empty">Nothing here yet.<br>Type above and press Enter.</p>' : ''}
      ${done.length ? `
        <div class="donebar">
          <button data-act="doneToggle">${state.showDone ? '▾' : '▸'} Done · ${done.length}</button>
          <span class="sep"></span>
          <button data-act="uncheckAll" title="For reusable lists">Uncheck all</button>
        </div>
        ${state.showDone ? `<ul class="items">${done.map(row).join('')}</ul>` : ''}` : ''}`;
  }

  const menuItems = {
    color: (l) => `<div class="swatches">${COLORS.map((c, i) => `<button class="sw ${l.color === i ? 'on' : ''}" style="--c:${c}" data-act="setColor" data-i="${i}" aria-label="Color ${i + 1}"></button>`).join('')}</div>`,
    share: () => `
      <button class="mi" data-act="share" data-how="text">${I.copy}Copy as text</button>
      <button class="mi" data-act="share" data-how="Markdown">${I.md}Copy as Markdown</button>
      <button class="mi" data-act="share" data-how="image">${I.image}Share as image…</button>`,
    more: (l) => `
      <button class="mi" data-act="pinTop">${I.pin}${l.pinned ? 'Unpin from top' : 'Pin to top'}</button>
      <button class="mi" data-act="float">${I.float}${l.onScreen && state.os !== 'ios' ? 'Hide from screen' : floatLabel()}</button>
      <button class="mi" data-act="uncheckAll">${I.undo}Uncheck all</button>
      <div class="msep"></div>
      <button class="mi" data-act="archiveList">${I.archive}Archive</button>
      <button class="mi danger" data-act="deleteList">${I.trash}Delete</button>`,
    menu: () => `
      <button class="mi" data-act="nav" data-view="archive">${I.archive}Archive<span class="r">${archived.length}</span></button>
      <button class="mi" data-act="nav" data-view="trash">${I.trash}Trash<span class="r">${trashed.length}</span></button>
      <button class="mi" data-act="nav" data-view="settings">${I.gear}Settings</button>`,
  };

  function listHeader(l) {
    const desk = !isPhone();
    return `
      <div class="lhead">
        <div class="pop-anchor">
          <button class="cdot" data-act="menu" data-menu="color" aria-label="List color" title="Color"></button>
          ${desk && state.menu === 'color' ? `<div class="menu left">${menuItems.color(l)}</div>` : ''}
        </div>
        <h1 class="ltitle" contenteditable="true" spellcheck="false" data-title>${esc(l.name)}</h1>
        ${desk ? `
        <div class="actions pop-anchor">
          <button class="iconbtn ${l.pinned ? 'on' : ''}" data-act="pinTop" title="${l.pinned ? 'Unpin from top' : 'Pin to top'}">${I.pin}</button>
          <button class="iconbtn ${l.onScreen ? 'on' : ''}" data-act="float" title="${floatLabel()}">${I.float}</button>
          <button class="iconbtn" data-act="menu" data-menu="share" title="Share">${I.share}</button>
          <button class="iconbtn" data-act="menu" data-menu="more" title="More">${I.more}</button>
          ${state.menu === 'share' ? `<div class="menu">${menuItems.share()}</div>` : ''}
          ${state.menu === 'more' ? `<div class="menu">${menuItems.more(l)}</div>` : ''}
        </div>` : ''}
      </div>
      <div class="lmeta">${openCount(l) ? openCount(l) + ' left' : 'All done'}${l.onScreen ? (state.os === 'ios' ? ' · In widget' : ' · On screen') : ''} · edited just now</div>`;
  }

  const addRow = () => `
    <form class="addrow" data-form="add">
      <span class="plus">+</span>
      <input name="t" autocomplete="off" placeholder="Add a task…" aria-label="Add a task">
      <button type="button" class="iconbtn sm" data-act="addText" title="Add a text line">${I.text}</button>
    </form>`;

  function detailsHtml(it) {
    const opt = (field, val, label = val) => `<button class="opt ${(it[field] || '') === val ? 'on' : ''}" data-act="set" data-field="${field}" data-val="${val}">${label}</button>`;
    return `
      <div class="dhead"><span>Task details</span><button class="iconbtn sm" data-act="closeDetails" aria-label="Close">${I.x}</button></div>
      <div class="dtxt" contenteditable="true" spellcheck="false" data-edit="${it.id}">${esc(it.t)}</div>
      <div class="dsec">
        <div class="dlabel">${I.cal}Due</div>
        <div class="opts">${['Today', 'Tomorrow', 'Next week'].map((d) => opt('dueDay', d)).join('')}${opt('dueDay', '', 'None')}</div>
        ${it.dueDay ? `<div class="opts">${['9:00', '13:00', '17:00', '20:00'].map((t) => opt('dueTime', t)).join('')}</div>` : ''}
      </div>
      <div class="dsec">
        <div class="dlabel">${I.bell}Remind me</div>
        ${it.dueDay ? `<div class="opts">${['At due time', '15 min before', '1 h before', '1 day before'].map((r) => opt('rem', r)).join('')}</div>` : ''}
        <div class="opts">${['in 1 h', 'in 2 h', 'Tomorrow 9:00'].map((r) => opt('rem', r)).join('')}${opt('rem', '', 'None')}</div>
        <div class="dnote">${it.dueDay ? '"Before" reminders move with the due time.' : 'Set a due time to get "before due" reminders.'} Rings on every signed-in device; done on one clears the others.</div>
      </div>
      <div class="dsec">
        <div class="dlabel">${I.repeat}Repeat</div>
        <div class="opts">${['Daily', 'Weekdays', 'Weekly', 'Monthly'].map((r) => opt('repeat', r)).join('')}${opt('repeat', '', 'Never')}</div>
      </div>
      <div class="dfoot"><button class="textbtn danger" data-act="deleteItem" data-id="${it.id}">Delete task</button></div>`;
  }

  function searchResults(q) {
    if (!q) return '<p class="empty">Search titles, text and tasks.<br>Works offline.</p>';
    const re = new RegExp(q.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'ig');
    const hl = (s) => esc(s).replace(new RegExp(esc(q).replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'ig'), (m) => `<mark>${m}</mark>`);
    const groups = lists.map((l) => {
      const nameHit = re.test(l.name); re.lastIndex = 0;
      const hits = l.items.filter((i) => { const h = re.test(i.t); re.lastIndex = 0; return h; });
      if (!nameHit && !hits.length) return '';
      return `
        <h4><span class="dot" style="--c:${col(l)}"></span>${hl(l.name)}</h4>
        ${hits.map((i) => `<button class="srow" data-act="open" data-id="${l.id}"><span class="muted">${i.type === 'check' ? (i.d ? '✓' : '○') : '¶'}</span><span>${hl(i.t)}</span></button>`).join('')}
        ${!hits.length ? `<button class="srow" data-act="open" data-id="${l.id}"><span class="muted">${openCount(l)} left</span></button>` : ''}`;
    }).join('');
    return `<div class="sres">${groups || `<p class="empty">Nothing matches "${esc(q)}".</p>`}</div>`;
  }

  function card(l, mode) {
    const open = l.items.filter((i) => !(i.type === 'check' && i.d));
    const preview = open.slice(0, 3).map((i) => `<li class="${i.type === 'text' ? 't' : ''}">${esc(i.t)}</li>`).join('');
    const more = open.length > 3 ? ` · +${open.length - 3} more` : '';
    const foot = mode === 'archive'
      ? `<div class="cacts"><span class="textbtn" data-act="restore" data-from="archive" data-id="${l.id}">Restore</span></div>`
      : mode === 'trash'
        ? `<div class="cfoot">Deleted ${l.deletedDaysAgo || 0} days ago · empties in ${30 - (l.deletedDaysAgo || 0)} days</div>
           <div class="cacts"><span class="textbtn" data-act="restore" data-from="trash" data-id="${l.id}">Restore</span><span class="textbtn danger" data-act="purge" data-id="${l.id}">Delete forever</span></div>`
        : `<div class="cfoot">${openCount(l) ? openCount(l) + ' left' : 'All done'}${more}</div>`;
    const tag = mode ? 'div' : 'button';
    return `<${tag} class="card" ${mode ? '' : `data-act="open" data-id="${l.id}"`} style="--c:${col(l)}">
      <div class="cname"><span class="dot"></span><span>${esc(l.name || 'Untitled list')}</span>${l.pinned && !mode ? I.pin : ''}${l.onScreen && !mode ? I.float : ''}</div>
      <ul>${preview}</ul>${foot}</${tag}>`;
  }

  function settingsHtml() {
    const tg = (on) => `<button class="tg ${on ? 'on' : ''}" data-act="toggle" role="switch" aria-checked="${on}"></button>`;
    const theme = (v, label) => `<button class="opt ${state.theme === v ? 'on' : ''}" data-act="theme" data-val="${v}">${label}</button>`;
    const floating = {
      macos: `<div class="set-row"><div>Mini bar<small>Faded bar that floats over other apps</small></div>${tg(true)}</div>
              <div class="set-row"><div>Idle opacity</div><input class="slider" type="range" min="20" max="100" value="50"></div>
              <div class="set-row"><div>Quick-open hotkey</div><kbd>⌥ Space</kbd></div>
              <div class="set-row"><div>Hide in full-screen apps</div>${tg(true)}</div>`,
      android: `<div class="set-row"><div>Floating mini bar<small>Needs "Display over other apps". Everything else works without it.</small></div>${tg(true)}</div>
                <div class="set-row"><div>"Add to Weave" in notifications</div>${tg(false)}</div>
                <div class="set-row"><div>Idle opacity</div><input class="slider" type="range" min="20" max="100" value="50"></div>`,
      ios: `<div class="set-row"><div>Widgets<small>iOS can't float over apps. Add Weave widgets from the home or lock screen.</small></div><span class="muted">How?</span></div>
            <div class="set-row"><div>Live Activity for today's reminders</div>${tg(false)}</div>`,
    };
    floating.windows = floating.macos.replace('⌥ Space', 'Alt+Space');
    floating.linux = floating.windows;
    return `
      <div class="set">
        ${isPhone() ? '' : '<h2>Settings</h2>'}
        <div class="set-sec"><h3>Appearance</h3>
          <div class="set-row"><div>Theme</div><div class="opts" style="margin:0">${theme('system', 'System')}${theme('light', 'Light')}${theme('dark', 'Dark')}</div></div>
        </div>
        <div class="set-sec"><h3>${state.os === 'ios' ? 'Widgets' : 'Floating'}</h3>${floating[state.os]}</div>
        <div class="set-sec"><h3>Notifications</h3>
          <div class="set-row"><div>Reminders</div>${tg(true)}</div>
          <div class="set-row"><div>Default snooze</div><div class="opts" style="margin:0"><button class="opt on">10 min</button><button class="opt">1 h</button><button class="opt">Tomorrow</button></div></div>
        </div>
        <div class="set-sec"><h3>Account & sync</h3>
          <div class="set-row"><div>Local mode<small>Everything stays on this device. Sign in to sync, end-to-end encrypted.</small></div></div>
          <div class="authbtns">
            <button class="authbtn" data-act="signin">Continue with Apple</button>
            <button class="authbtn" data-act="signin">Continue with Google</button>
            <button class="authbtn" data-act="signin">Continue with email</button>
          </div>
        </div>
      </div>`;
  }

  // ---------- Desktop ----------
  function sideHtml() {
    const sideRow = (l) => `
      <li><button class="srow-l ${state.view === 'list' && state.cur === l.id ? 'on' : ''}" data-act="open" data-id="${l.id}">
        <span class="dot" style="--c:${col(l)}"></span><span class="name">${esc(l.name || 'Untitled list')}</span>
        ${l.onScreen ? `<span class="fl" title="On screen">${I.float}</span>` : ''}
        <span class="n">${openCount(l) || ''}</span>
      </button></li>`;
    const nav = (v, icon, label, n) => `<button class="navrow ${state.view === v ? 'on' : ''}" data-act="nav" data-view="${v}">${icon}${label}${n != null ? `<span class="n" style="margin-left:auto">${n}</span>` : ''}</button>`;
    return `
      <div class="brand">${I.logo}<b>Weave</b>${syncBtn()}</div>
      <label class="search">${I.search}<input id="q" placeholder="Search" value="${esc(state.query)}" autocomplete="off"><kbd>${mod()}K</kbd></label>
      <div class="group">Pinned</div>
      <ul>${lists.filter((l) => l.pinned).map(sideRow).join('')}</ul>
      <div class="group">Lists</div>
      <ul>${lists.filter((l) => !l.pinned).map(sideRow).join('')}</ul>
      <button class="newlist" data-act="newList">${I.plus}New list<kbd>${mod()}N</kbd></button>
      <div class="sfoot">
        ${nav('archive', I.archive, 'Archive', archived.length)}
        ${nav('trash', I.trash, 'Trash', trashed.length)}
        ${nav('settings', I.gear, 'Settings')}
        <div class="acct" data-act="nav" data-view="settings"><span class="av">${I.user}</span><div><b>Local mode</b><small>Sign in to sync devices</small></div></div>
      </div>`;
  }

  function deskMainHtml() {
    if (state.view === 'search') return `<div class="main-inner"><h1 class="ltitle" style="margin-bottom:6px">Search</h1>${searchResults(state.query)}</div>`;
    if (state.view === 'archive') return `<div class="main-inner"><h1 class="ltitle">Archive</h1><p class="lmeta" style="margin-left:0">Hidden from your lists, not deleted.</p><div class="cards">${archived.map((l) => card(l, 'archive')).join('') || '<p class="empty">Nothing archived.</p>'}</div></div>`;
    if (state.view === 'trash') return `<div class="main-inner"><h1 class="ltitle">Trash</h1><p class="lmeta" style="margin-left:0">Lists here are deleted for good after 30 days.</p><div class="cards">${trashed.map((l) => card(l, 'trash')).join('') || '<p class="empty">Trash is empty.</p>'}</div></div>`;
    if (state.view === 'settings') return `<div class="main-inner">${settingsHtml()}</div>`;
    const l = cur();
    return `<div class="main-inner">${listHeader(l)}${addRow()}${itemsHtml(l)}</div>`;
  }

  function chromeHtml() {
    if (state.os === 'macos') return '<div class="titlebar"><div class="lights"><i></i><i></i><i></i></div></div>';
    if (state.os === 'windows') return `<div class="titlebar">${I.logo}Weave<div class="winctl"><span>${winMin}</span><span>${winMax}</span><span>${winX}</span></div></div>`;
    return `<div class="titlebar">Weave<span class="gtkclose">${winX}</span></div>`;
  }

  // ---------- Phone ----------
  function phoneScreenHtml() {
    const l = cur();
    const bar = (left, right = '') => `<div class="pbar">${left}<span class="grow"></span>${right}</div>`;
    const backBtn = `<button class="iconbtn" data-act="back" aria-label="Back">${I.back}</button>`;
    switch (state.screen) {
      case 'list':
        return `
          ${bar(backBtn, `
            <button class="iconbtn ${l.onScreen ? 'on' : ''}" data-act="float" title="${floatLabel()}">${I.float}</button>
            <button class="iconbtn" data-act="menu" data-menu="share" title="Share">${I.share}</button>
            <button class="iconbtn" data-act="menu" data-menu="more" title="More">${I.more}</button>`)}
          <div class="pscroll">${listHeader(l)}${itemsHtml(l)}</div>
          <div class="paddbar">${addRow()}</div>`;
      case 'search':
        return `
          ${bar(backBtn)}
          <label class="search">${I.search}<input id="q" placeholder="Search" value="${esc(state.query)}" autocomplete="off"></label>
          <div class="pscroll" id="presults">${searchResults(state.query)}</div>`;
      case 'archive':
      case 'trash':
        return `
          ${bar(backBtn)}
          <div class="pbig"><h1>${state.screen === 'archive' ? 'Archive' : 'Trash'}</h1></div>
          <div class="pscroll"><div class="cards">${(state.screen === 'archive' ? archived : trashed).map((x) => card(x, state.screen)).join('') || '<p class="empty">Empty.</p>'}</div></div>`;
      case 'settings':
        return `${bar(backBtn)}<div class="pbig"><h1>Settings</h1></div><div class="pscroll" style="padding:0 20px 60px">${settingsHtml()}</div>`;
      default:
        return `
          ${bar(syncBtn(), `
            <button class="iconbtn" data-act="phoneSearch" aria-label="Search">${I.search}</button>
            <button class="iconbtn" data-act="menu" data-menu="menu" aria-label="Menu">${I.menu}</button>`)}
          <div class="pbig"><h1>Weave</h1></div>
          <div class="pscroll">
            <div class="group">Pinned</div>
            <div class="cards">${lists.filter((x) => x.pinned).map((x) => card(x)).join('')}</div>
            <div class="group">Lists</div>
            <div class="cards">${lists.filter((x) => !x.pinned).map((x) => card(x)).join('')}</div>
          </div>
          <button class="fab" data-act="newList" aria-label="New list">${I.plus}</button>`;
    }
  }

  function psheetHtml() {
    if (!state.psheet) return '';
    let body = '';
    if (state.psheet === 'details') { const { it } = findItem(state.sel); body = it ? detailsHtml(it) : ''; }
    else if (state.psheet === 'color') body = menuItems.color(cur());
    else body = menuItems[state.psheet](cur());
    return `<div class="psheet" data-act="closeSheet"><div class="sh" data-stop><div class="grabber"></div>${body}</div></div>`;
  }

  // ---------- Render ----------
  const frame = document.getElementById('frame');
  let builtFor = null;
  let els = {};

  function build() {
    builtFor = state.os;
    frame.className = `frame os-${state.os}`;
    if (isPhone()) {
      const time = '9:41';
      frame.innerHTML = `
        <div class="phone app-root">
          <div class="island"></div>
          <div class="status"><span>${time}</span><span class="sicons"><i style="width:17px;height:10px"></i><i style="width:24px;height:11px;border-radius:3px"></i></span></div>
          <div class="screen" id="screen"></div>
          <div id="psheet"></div>
          <div class="toast" id="toast"></div>
          <div class="homebar"></div>
        </div>`;
      els = { root: frame.firstElementChild, screen: frame.querySelector('#screen'), psheet: frame.querySelector('#psheet'), toast: frame.querySelector('#toast') };
    } else {
      frame.innerHTML = `
        <div class="window app-root">
          ${chromeHtml()}
          <div class="app">
            <aside class="side" id="side"></aside>
            <main class="main" id="main"></main>
            <aside class="details" id="details"><div class="details-inner" id="detailsInner"></div></aside>
          </div>
          <div class="toast" id="toast"></div>
        </div>`;
      els = { root: frame.firstElementChild, side: frame.querySelector('#side'), main: frame.querySelector('#main'), details: frame.querySelector('#details'), detailsInner: frame.querySelector('#detailsInner'), toast: frame.querySelector('#toast') };
    }
    fit();
  }

  function applyTheme() {
    const t = state.theme === 'system' ? (matchMedia('(prefers-color-scheme: light)').matches ? 'light' : 'dark') : state.theme;
    els.root.classList.remove('t-dark', 't-light');
    els.root.classList.add('t-' + t);
    // List screens take the list's color; app-level screens use Weave yellow.
    const onList = isPhone() ? state.screen === 'list' : state.view === 'list';
    els.root.style.setProperty('--accent', onList ? col(cur()) : COLORS[0]);
    els.root.style.setProperty('--accent-ink', onList ? ink(cur()) : 'var(--n0-ink)');
    document.querySelectorAll('#themeCtl button').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.theme === t)));
    document.querySelectorAll('#osCtl button').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.os === state.os)));
  }

  function renderSide() { if (!isPhone()) els.side.innerHTML = sideHtml(); }
  function renderMain() {
    if (isPhone()) { els.screen.innerHTML = phoneScreenHtml(); els.psheet.innerHTML = psheetHtml(); }
    else els.main.innerHTML = deskMainHtml();
    state.newItem = null;
  }
  function renderDetails() {
    if (isPhone()) { els.psheet.innerHTML = psheetHtml(); return; }
    const { it } = findItem(state.sel);
    els.details.classList.toggle('open', !!it);
    els.detailsInner.innerHTML = it ? detailsHtml(it) : '';
  }
  function render() {
    if (builtFor !== state.os) build();
    applyTheme();
    renderSide();
    renderMain();
    renderDetails();
  }

  function fit() {
    const stage = document.getElementById('stage');
    const w = isPhone() ? 413 : 1220, h = isPhone() ? 872 : 780;
    const s = Math.min(1, (stage.clientWidth - 24) / w, (stage.clientHeight - 24) / h);
    frame.style.transform = `scale(${s})`;
  }
  addEventListener('resize', fit);

  // ---------- Toast ----------
  let toastTimer = null;
  function toast(msg, undo) {
    state.toast = { msg, undo };
    els.toast.innerHTML = `<span>${esc(msg)}</span>${undo ? '<button data-act="undo">Undo</button>' : ''}`;
    els.toast.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => els.toast.classList.remove('show'), 4000);
  }

  // ---------- Editing helpers ----------
  function focusEdit(iid, atStart = false) {
    const el = frame.querySelector(`.items [data-edit="${iid}"]`);
    if (!el) return;
    el.focus();
    const r = document.createRange();
    r.selectNodeContents(el);
    r.collapse(atStart);
    const s = getSelection();
    s.removeAllRanges();
    s.addRange(r);
  }
  const focusAdd = () => { const i = frame.querySelector('.addrow input'); if (i) i.focus(); };

  // ---------- Actions ----------
  function openList(lid) {
    state.cur = lid; state.view = 'list'; state.screen = 'list';
    state.sel = null; state.menu = null; state.psheet = null; state.showDone = false;
    render();
  }

  const acts = {
    open: (b) => openList(+b.dataset.id),
    back: () => { state.screen = 'home'; state.psheet = null; state.sel = null; render(); },
    phoneSearch: () => { state.screen = 'search'; render(); frame.querySelector('#q').focus(); },
    nav: (b) => {
      state.view = b.dataset.view; state.screen = b.dataset.view;
      state.sel = null; state.menu = null; state.psheet = null; render();
    },
    sync: () => {
      const order = ['synced', 'syncing', 'offline', 'error'];
      state.sync = order[(order.indexOf(state.sync) + 1) % order.length];
      render();
    },
    tick: (b) => {
      const { l, it } = findItem(+b.dataset.id);
      const done = () => { it.d = !it.d; render(); };
      if (!it.d) {
        b.closest('.row').classList.add('is-ticking');
        setTimeout(done, 280);
        toast(`Checked "${it.t}"`, () => { it.d = false; render(); });
      } else done();
      void l;
    },
    details: (b) => {
      state.sel = +b.dataset.id;
      if (isPhone()) state.psheet = 'details';
      renderMain(); renderDetails();
    },
    closeDetails: () => { state.sel = null; state.psheet = null; renderMain(); renderDetails(); },
    closeSheet: (b, e) => { if (e.target.closest('[data-stop]')) return; state.psheet = null; state.sel = null; renderMain(); },
    set: (b) => {
      const { it } = findItem(state.sel);
      const f = b.dataset.field, v = b.dataset.val;
      it[f] = v || undefined;
      if (f === 'dueDay' && v && !it.dueTime) it.dueTime = '9:00';
      if (f === 'dueDay' && !v) { it.dueTime = undefined; if (/before|At due/.test(it.rem || '')) it.rem = undefined; }
      renderMain(); renderDetails();
    },
    deleteItem: (b) => {
      const { l, it } = findItem(+b.dataset.id);
      const idx = l.items.indexOf(it);
      l.items.splice(idx, 1);
      state.sel = null; state.psheet = null;
      render();
      toast('Task deleted', () => { l.items.splice(idx, 0, it); render(); });
    },
    addText: () => {
      const t = T('');
      cur().items.unshift(t);
      render();
      focusEdit(t.id);
    },
    menu: (b) => {
      const m = b.dataset.menu;
      if (isPhone()) { state.psheet = m; renderMain(); return; }
      state.menu = state.menu === m ? null : m;
      renderMain();
    },
    setColor: (b) => { cur().color = +b.dataset.i; state.menu = null; state.psheet = null; render(); },
    pinTop: () => { const l = cur(); l.pinned = !l.pinned; state.menu = null; state.psheet = null; render(); toast(l.pinned ? 'Pinned to top' : 'Unpinned'); },
    float: () => {
      const l = cur();
      state.menu = null; state.psheet = null;
      if (state.os === 'ios') { render(); return toast('Long-press the home screen → add the Weave widget'); }
      l.onScreen = !l.onScreen; render();
      toast(l.onScreen ? `"${l.name}" is on screen in the mini bar` : 'Hidden from screen');
    },
    share: (b) => { state.menu = null; state.psheet = null; renderMain(); toast(b.dataset.how === 'image' ? 'Opening share sheet…' : `Copied as ${b.dataset.how}`); },
    uncheckAll: () => {
      const l = cur();
      const was = l.items.filter((i) => i.d);
      was.forEach((i) => { i.d = false; });
      state.menu = null; state.psheet = null; render();
      toast(`Unchecked ${was.length}`, () => { was.forEach((i) => { i.d = true; }); render(); });
    },
    archiveList: () => moveList(archived, 'Archived'),
    deleteList: () => moveList(trashed, 'Moved to Trash'),
    restore: (b) => {
      const from = b.dataset.from === 'archive' ? archived : trashed;
      const l = from.find((x) => x.id === +b.dataset.id);
      from.splice(from.indexOf(l), 1);
      lists.push(l);
      render(); toast(`Restored "${l.name}"`);
    },
    purge: (b) => {
      const l = trashed.find((x) => x.id === +b.dataset.id);
      trashed.splice(trashed.indexOf(l), 1);
      render(); toast('Deleted forever');
    },
    newList: () => {
      const l = { id: id(), name: '', color: lists.length + archived.length, pinned: false, items: [] };
      lists.push(l);
      openList(l.id);
      frame.querySelector('[data-title]').focus();
    },
    doneToggle: () => { state.showDone = !state.showDone; renderMain(); },
    toggle: (b) => { b.classList.toggle('on'); b.setAttribute('aria-checked', String(b.classList.contains('on'))); },
    theme: (b) => { state.theme = b.dataset.val; if (b.dataset.val !== 'system') localStorage.setItem('weave-mode', 't-' + b.dataset.val); render(); },
    signin: () => toast('Sign-in isn\'t part of this prototype'),
    undo: () => { const u = state.toast && state.toast.undo; els.toast.classList.remove('show'); if (u) u(); },
  };

  function moveList(to, msg) {
    const l = cur();
    const idx = lists.indexOf(l);
    lists.splice(idx, 1);
    to.unshift(l);
    state.menu = null; state.psheet = null; state.sel = null;
    state.cur = (lists[Math.max(0, idx - 1)] || lists[0] || {}).id;
    if (isPhone()) state.screen = 'home';
    render();
    toast(`${msg} "${l.name || 'Untitled list'}"`, () => {
      to.splice(to.indexOf(l), 1); lists.splice(idx, 0, l); openList(l.id);
    });
  }

  // ---------- Events ----------
  frame.addEventListener('click', (e) => {
    const b = e.target.closest('[data-act]');
    if (state.menu && !e.target.closest('.pop-anchor')) { state.menu = null; renderMain(); }
    if (!b || !frame.contains(b)) return;
    const fn = acts[b.dataset.act];
    if (fn) fn(b, e);
  });

  frame.addEventListener('submit', (e) => {
    e.preventDefault();
    const input = e.target.elements.t;
    const v = input.value.trim();
    if (!v) return;
    const it = C(v);
    cur().items.unshift(it);
    state.newItem = it.id;
    renderMain(); renderSide();
    focusAdd();
  });

  frame.addEventListener('input', (e) => {
    const t = e.target;
    if (t.dataset.edit) {
      const { it } = findItem(+t.dataset.edit);
      if (!it) return;
      it.t = t.textContent;
      frame.querySelectorAll(`[data-edit="${it.id}"]`).forEach((o) => { if (o !== t) o.textContent = it.t; });
    } else if (t.hasAttribute('data-title')) {
      cur().name = t.textContent;
      renderSide();
    } else if (t.id === 'q') {
      state.query = t.value;
      if (isPhone()) { frame.querySelector('#presults').innerHTML = searchResults(state.query); return; }
      state.view = state.query ? 'search' : 'list';
      renderMain();
    }
  });

  frame.addEventListener('keydown', (e) => {
    const t = e.target;
    if (t.hasAttribute && t.hasAttribute('data-title') && e.key === 'Enter') { e.preventDefault(); focusAdd(); return; }
    if (!t.dataset || !t.dataset.edit || !t.closest('.items')) return;
    const { l, it } = findItem(+t.dataset.edit);
    if (!it) return;
    const idx = l.items.indexOf(it);
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      const n = it.type === 'text' ? T('') : C('', { indent: it.indent });
      l.items.splice(idx + 1, 0, n);
      renderMain();
      focusEdit(n.id);
    } else if (e.key === 'Backspace' && t.textContent === '') {
      e.preventDefault();
      l.items.splice(idx, 1);
      const prev = l.items[idx - 1];
      renderMain(); renderSide();
      if (prev) focusEdit(prev.id); else focusAdd();
    } else if (e.key === 'Tab' && it.type === 'check') {
      e.preventDefault();
      it.indent = e.shiftKey ? 0 : 1; // one level of sub-items (F3.3)
      renderMain();
      focusEdit(it.id);
    }
  });

  document.addEventListener('keydown', (e) => {
    const m = e.metaKey || e.ctrlKey;
    if (m && e.key.toLowerCase() === 'k') { e.preventDefault(); if (isPhone()) acts.phoneSearch(); else frame.querySelector('#q').focus(); }
    if (m && e.key.toLowerCase() === 'n') { e.preventDefault(); acts.newList(); }
    if (e.key === 'Escape') {
      if (state.menu || state.sel || state.psheet) { state.menu = null; state.sel = null; state.psheet = null; renderMain(); renderDetails(); }
    }
  });

  document.getElementById('osCtl').addEventListener('click', (e) => {
    const b = e.target.closest('[data-os]');
    if (!b) return;
    state.os = b.dataset.os; state.menu = null; state.psheet = null; state.sel = null;
    render();
  });
  document.getElementById('themeCtl').addEventListener('click', (e) => {
    const b = e.target.closest('[data-theme]');
    if (b) { state.theme = b.dataset.theme; localStorage.setItem('weave-mode', 't-' + b.dataset.theme); render(); }
  });

  render();
})();
