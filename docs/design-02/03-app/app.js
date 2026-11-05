// 03 · Weave app (throwaway prototype, not app code).
// Desktop: sidebar · canvas (Up next, a list, Archive & trash, Settings, search).
// Phone: top bar · screen · add bar pinned to the bottom · bottom sheets.
(function () {
  'use strict';
  const D = window.WeaveData, I = window.WeaveIcons, { esc } = D;
  const hash = new URLSearchParams(location.hash.slice(1));
  // #marks pins the declutter study's numbered badges (review.md D1–D13); #embed hides the prototype toolbar.
  const MARKS = hash.has('marks'), EMBED = hash.has('embed');

  const archived = [
    { id: 91, name: 'Diwali shopping', color: 3, n: 7, when: 'Archived 28 Oct' },
    { id: 92, name: 'Flat viewing questions', color: 1, n: 4, when: 'Archived 12 Oct' },
  ];
  const trashed = [
    { id: 93, name: 'Old packing list', color: 5, n: 9, ago: 2 },
  ];

  // A true conflict (F2.4): one task edited on two devices while one was offline. Both versions are kept.
  (() => {
    const g = D.lists.find((l) => l.id === 3);
    const i = g.items.findIndex((x) => x.t === 'Oat milk');
    Object.assign(g.items[i], { t: 'Oat milk, unsweetened', conflict: 1, from: 'This Mac' });
    g.items.splice(i + 1, 0, { id: D.id(), type: 'check', t: 'Oat milk, 2 cartons', d: false, indent: 0, due: null, remind: null, repeat: null, conflict: 1, from: 'Pixel 8' });
  })();
  const EMAIL = 'mayank@example.com'; // taste-skill-ignore: reserved demo domain, never a real mailbox
  const prefs = { bar: true, fullscreen: true, notif: true, snooze: '10m', capture: 1 };

  const state = {
    os: hash.get('os') || localStorage.getItem('weave2-os') || 'macos',
    view: hash.get('list') ? 'list' : (hash.get('view') || 'next'),
    cur: +(hash.get('list') || 1),
    sel: null,          // selected item id (details)
    showDone: false,
    newItem: null,
    sync: 'synced',
    query: '',
    psheet: null,       // phone bottom sheet: 'item' | 'share' | 'more'
    pmenu: false,
    pop: null,          // desktop floating menu: { kind, x, y, kbd }
    ticking: new Set(), // rows whose tick is filling (kept through re-renders)
    leaving: new Set(), // rows fading out after a tick
    floatOpacity: 50,
    theme: 'system',
    modal: hash.get('modal') || null, // signout · delacct · signin · keycheck · adddevice · newkey
    step: hash.get('step') || null,   // the step inside a multi-step dialog
    account: hash.get('account') === 'local' ? 'local' : 'in', // local mode = no account (S1)
    existing: hash.has('existing'),   // signing in on a new device of an existing account (E3)
    email: '',
    up: 0,                            // lists uploaded so far (first sign-in)
    keyErr: false,
  };
  const SYNC = { synced: `Synced · ${D.devices.length} devices`, syncing: 'Syncing…', offline: 'Offline · changes saved here', error: 'Sync error · retrying' };
  const isPhoneOS = () => state.os === 'ios' || state.os === 'android';
  const here = () => (state.os === 'ios' || state.os === 'android' ? 'this phone' : state.os === 'windows' ? 'this PC' : 'this Mac');
  const bare = () => innerWidth < 720;
  const phone = () => isPhoneOS() || bare();
  const mod = () => (state.os === 'macos' || state.os === 'ios' ? '⌘' : 'Ctrl+');
  const cur = () => D.lists.find((l) => l.id === state.cur) || D.lists[0];
  const listOf = (it) => D.lists.find((l) => l.items.includes(it));
  const findItem = (iid) => { for (const l of D.lists) { const it = l.items.find((i) => i.id === iid); if (it) return it; } return null; };
  const cvars = (l) => `--c:${D.color(l)};--ci:${D.ink(l)};--c-ink:${D.ink(l)}`;
  const dot = (l) => `<span class="dot" style="${cvars(l)}"></span>`;

  // ---------- Shared fragments ----------
  const HINT = `<span>Times and days are understood: 6pm, 18:30, tomorrow, tonight, in 2 h.</span>`;
  // One field (playbook C3): Enter adds; the list is a small chip inside the field; the hint shows only on focus.
  function capture(target, { phoneBar = false, inline = false } = {}) {
    const chip = target ? '' : `<select class="lchip" name="list" aria-label="Add to list">${D.lists.map((l) => `<option value="${l.id}" ${l.id === prefs.capture ? 'selected' : ''}>${esc(l.name)}</option>`).join('')}</select>`;
    return `
      <form class="capture ${inline ? 'inline' : ''}" data-form="capture" ${target ? `data-list="${target.id}"` : ''}>
        <div class="field">${I.plus}<input name="t" autocomplete="off" placeholder="${target ? 'Add a task…' : 'Add a task… try “dentist fri 10am”'}" aria-label="Add a task${target ? ' to ' + esc(target.name) : ''}">${chip}</div>
      </form>
      <div class="parse onfocus" aria-live="polite">${phoneBar ? '' : HINT}</div>`;
  }

  const rowMotion = (it) => `${state.ticking.has(it.id) ? 'is-ticking' : ''} ${state.leaving.has(it.id) ? 'is-leaving' : ''}`;
  const itemWhen = (it) => (!it.due ? '' : D.isOverdue(it)
    ? `<span class="when late">${D.lateWhen(D.dueLabel(it.due), I.alert)}</span>`
    : `<span class="when">${D.dueLabel(it.due)}</span>`);

  function agendaRow(x, { showList = true } = {}) {
    const { it, list } = x;
    return `
      <li class="row ${it.d ? 'is-done' : ''} ${rowMotion(it)}" data-id="${it.id}" style="${cvars(list)}">
        <button class="check" data-act="tick" data-id="${it.id}" aria-label="${it.d ? 'Uncheck' : 'Check'} ${esc(it.t)}">${I.tick}</button>
        <button class="rowbtn" data-act="goto" data-list="${list.id}" data-id="${it.id}">
          <span class="t">${esc(it.t)}</span>
          ${showList ? `<span class="src">${dot(list)}${esc(list.name)}</span>` : ''}
        </button>
        ${itemWhen(it)}
      </li>`;
  }

  // ---------- Up next ----------

  // Header (C2): the date above the title, one fact under it.
  function upNextFinding() {
    const open = D.today().filter((x) => !x.it.d);
    const next = open.find((x) => !D.isOverdue(x.it));
    if (!open.length) return 'Nothing left for today';
    return `<b class="num">${open.length}</b> left today${next ? ` · next ${esc(next.it.t)} at <span class="num">${next.it.due.t}</span>` : ''}`;
  }
  const pageTitle = (h) => `<p class="eyebrow">${D.NOW.day}</p><h1>${h}</h1><p class="subline">${upNextFinding()}</p>`;

  // Today across every list as one line (the mini-bar sheet's strip), for the phone's Today card.
  function dayStrip() {
    const due = D.today();
    if (!due.length) return '';
    const W = 300, S = 7 * 60, E = 23 * 60;
    const x = (m) => 6 + Math.round(((Math.min(E, Math.max(S, m)) - S) / (E - S)) * (W - 12));
    const nx = x(D.NOW.min);
    const marks = due.map(({ it, list }) => {
      const cx = x(D.toMin(it.due.t));
      if (it.d) return `<circle cx="${cx}" cy="9" r="4" fill="var(--surface)" stroke="var(--muted)" stroke-width="1.5"/>`;
      if (D.isOverdue(it)) return `<circle cx="${cx}" cy="9" r="4.5" fill="var(--surface)" stroke="var(--negative)" stroke-width="2"/>`;
      return `<circle cx="${cx}" cy="9" r="5.5" fill="${D.color(list)}" stroke="${D.ink(list)}"/>`;
    }).join('');
    const said = due.map(({ it }) => `${it.due.t} ${esc(it.t)}${it.d ? ' (done)' : D.isOverdue(it) ? ' (overdue)' : ''}`).join(', ');
    return /* taste-skill-ignore: hour labels, not numbering */ `<div class="lstrip daystrip"><span aria-hidden="true">07</span>
      <svg viewBox="0 0 ${W} 18" height="18" role="img" aria-label="Today: ${said}. Now ${D.NOW.clock}.">
        <line x1="6" x2="${W - 6}" y1="9" y2="9" stroke="var(--control)" stroke-width="2" stroke-linecap="round"/>
        <line x1="6" x2="${nx}" y1="9" y2="9" stroke="var(--text)" stroke-width="2" stroke-linecap="round"/>
        <line x1="${nx}" x2="${nx}" y1="1" y2="17" stroke="var(--text)" stroke-width="1.5"/>${marks}</svg>
      <span aria-hidden="true">23</span></div>`;
  }


  // One list, no group labels (C5): overdue first with its red time, then the rest, done rows last and struck through.
  function todayCard({ withCapture = false } = {}) {
    const t = D.today();
    const late = t.filter((x) => !x.it.d && D.isOverdue(x.it));
    const upcoming = t.filter((x) => !x.it.d && !D.isOverdue(x.it));
    const done = t.filter((x) => x.it.d);
    const showList = new Set(t.map((x) => x.list.id)).size > 1;
    const rows = [...late, ...upcoming, ...done];
    return `
      <section class="card" aria-labelledby="h-today">
        <header><h2 id="h-today">Today</h2></header>
        ${phone() ? dayStrip() : ''}
        ${withCapture ? `<div class="capturebox">${capture(null)}</div>` : ''}
        ${rows.length ? `<ul class="rows">${rows.map((x) => agendaRow(x, { showList })).join('')}</ul>` : '<p class="empty">Nothing left for today.</p>'}
      </section>`;
  }

  function laterCard() {
    const later = D.laterThisWeek();
    return `
      <section class="card" aria-labelledby="h-later">
        <header><h2 id="h-later">Later this week</h2><span class="meta num">${later.length}</span></header>
        ${later.length ? `<ul class="rows">${later.map((x) => agendaRow(x, { showList: false })).join('')}</ul>` : '<p class="empty">Nothing scheduled after today.</p>'}
      </section>`;
  }

  function listsCard() {
    return `
      <section class="card" aria-labelledby="h-lists">
        <header><h2 id="h-lists">Lists</h2><span class="meta num">${D.lists.length}</span><button class="link" data-act="newlist">New list</button></header>
        <ul class="notes">${D.lists.map((l) => {
          const n = D.nextUp(l), late = D.open(l).filter(D.isOverdue).length;
          const line = late ? `<span class="late">${I.alert}${late} overdue</span>` : n ? `next ${D.dueLabel(n.due)}` : D.open(l).length ? 'no times set' : 'nothing left';
          return `
          <li><button class="note paper" style="${cvars(l)}" data-act="open" data-list="${l.id}">
            <span class="nn"><span class="name">${esc(l.name)}</span>${l.onScreen ? `<span class="onscreen" title="In the mini bar">${I.screen}<span class="sr">In the mini bar</span></span>` : ''}</span>
            <span class="nl num"><b>${D.open(l).length ? `${D.open(l).length} left` : 'All done'}</b> · ${line}</span>
          </button></li>`;
        }).join('')}</ul>
      </section>`;
  }




  function threadCard() {
    return `
      <section class="card thread" aria-labelledby="h-thread">
        <header><h2 id="h-thread">Today's thread</h2><span class="meta">07:00 to 23:00</span>
        </header>
        <div data-thread></div>
      </section>`;
  }

  // The day thread: 07:00–23:00, elapsed part in ink, each due item as a mark in its list's colour.
  function drawThread(host) {
    const W = host.clientWidth;
    if (!W) return;
    const compact = W < 520;
    const START = 7 * 60, END = 23 * 60, ROW = compact ? 20 : 24;
    const x = (m) => Math.round(((m - START) / (END - START)) * (W - 12)) + 6;
    const ctx = drawThread.ctx || (drawThread.ctx = document.createElement('canvas').getContext('2d'));
    ctx.font = '14px Geist, Inter, system-ui, sans-serif';
    const short = (s, n) => (s.length > n ? s.slice(0, n - 1).trimEnd() + '…' : s);
    const dots = D.today().map(({ it, list }) => ({ it, list, m: D.toMin(it.due.t), cx: x(D.toMin(it.due.t)) })).sort((a, b) => a.m - b.m);
    // Marks closer than 14px share one label ("Pick up parcel… +1"), so every label keeps a clear leader.
    const marks = [];
    dots.forEach((d) => { const last = marks[marks.length - 1]; if (last && d.cx - last.cx < 14) last.more.push(d); else marks.push({ ...d, more: [] }); });
    marks.forEach((mk) => {
      const extra = mk.more.length ? ` +${mk.more.length}` : '';
      mk.label = (compact ? short(mk.it.t, 16) : `${mk.it.due.t} ${short(mk.it.t, 28)}`) + extra;
      mk.w = ctx.measureText((D.isOverdue(mk.it) ? '! ' : '') + mk.label).width;
    });
    // Label rows above the axis: lowest free row whose span is clear and whose lower rows don't cover this leader.
    // Placed right to left: a label runs right from its mark, so lower rows only ever hold marks to the right,
    // and no leader line passes through a label. Capped at 8 rows so the loop always ends.
    const rows = [];
    [...marks].reverse().forEach((mk) => {
      const s = Math.max(0, Math.min(W - mk.w, mk.cx - 4)), e = s + mk.w;
      let r = 0;
      while (r < 8) {
        const row = rows[r] || (rows[r] = []);
        const clear = row.every((b) => e + 10 < b.s || s > b.e + 10);
        const leaderClear = rows.slice(0, r).every((rw) => rw.every((b) => mk.cx < b.s - 4 || mk.cx > b.e + 4));
        if (clear && leaderClear) break;
        r++;
      }
      (rows[r] || (rows[r] = [])).push({ s, e }); mk.row = r; mk.s = s;
    });
    const nRows = rows.length;
    const axisY = 8 + nRows * ROW + 16;
    const H = axisY + 34;
    const nowX = x(D.NOW.min);
    const step = compact ? 240 : 120;
    const hours = [];
    for (let m = START; m <= END; m += step) hours.push(m);
    const nowLbl = `Now ${D.NOW.clock}`;
    ctx.font = '13px Geist, Inter, system-ui, sans-serif';
    const nowW = ctx.measureText(nowLbl).width + 8;
    const nowS = Math.max(0, Math.min(W - nowW, nowX - nowW / 2));
    let svg = `<svg width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" role="img" aria-label="Today from 07:00 to 23:00: ${dots.map((m) => `${m.it.due.t} ${esc(m.it.t)}${m.it.d ? ' (done)' : D.isOverdue(m.it) ? ' (overdue)' : ''}`).join(', ')}. Now ${D.NOW.clock}.">`;
    svg += `<rect x="${nowX}" y="0" width="${W - nowX}" height="${axisY + 8}" fill="var(--hover)" rx="4"/>`; // the rest of today
    svg += `<line x1="6" x2="${W - 6}" y1="${axisY}" y2="${axisY}" stroke="var(--control)" stroke-width="3" stroke-linecap="round"/>`;
    svg += `<line x1="6" x2="${nowX}" y1="${axisY}" y2="${axisY}" stroke="var(--text)" stroke-width="3" stroke-linecap="round"/>`;
    hours.forEach((m) => {
      const hx = x(m);
      const lbl = D.fmtClock(m);
      const lw = ctx.measureText(lbl).width;
      const anchor = m === START ? 'start' : m === END ? 'end' : 'middle';
      const ls = anchor === 'start' ? hx : anchor === 'end' ? hx - lw : hx - lw / 2;
      if (ls + lw > nowS - 6 && ls < nowS + nowW + 6) return; // the Now label wins the lane
      svg += `<line x1="${hx}" x2="${hx}" y1="${axisY + 4}" y2="${axisY + 7}" stroke="var(--control)"/>`;
      svg += `<text x="${anchor === 'start' ? hx - 6 : anchor === 'end' ? hx + 6 : hx}" y="${axisY + 26}" text-anchor="${anchor}" class="num">${lbl}</text>`;
    });
    // The day's last tick: ink runs along the rest of today once, then fades (see dayDone). Hidden without motion.
    if (drawThread.finale) svg += `<line class="finale" pathLength="1" x1="${nowX}" x2="${W - 6}" y1="${axisY}" y2="${axisY}" stroke="var(--text)" stroke-width="3" stroke-linecap="round"/>`;
    svg += `<line x1="${nowX}" x2="${nowX}" y1="0" y2="${axisY + 10}" stroke="var(--text)" stroke-width="1.5"/>`;
    svg += `<text x="${nowS + nowW / 2}" y="${axisY + 26}" text-anchor="middle" class="now num">${nowLbl}</text>`;
    marks.forEach((mk) => {
      const ly = 8 + (nRows - 1 - mk.row) * ROW + 14; // row 0 sits nearest the axis
      const late = D.isOverdue(mk.it);
      svg += `<line x1="${mk.cx}" x2="${mk.cx}" y1="${ly + 5}" y2="${axisY - 8}" stroke="var(--control)"/>`;
      const full = [mk, ...mk.more].map((d) => `${d.it.due.t} ${d.it.t}`).join(' · ');
      svg += `<text x="${mk.s}" y="${ly}" class="lbl ${mk.it.d ? 'done' : late ? 'late' : ''}" data-act="goto" data-list="${mk.list.id}" data-id="${mk.it.id}"><title>${esc(full)}</title>${late ? '! ' : ''}${esc(mk.label)}</text>`;
      [...mk.more].reverse().concat([mk]).forEach((d) => {
        if (d.it.d) svg += `<circle cx="${d.cx}" cy="${axisY}" r="5" fill="var(--surface)" stroke="var(--muted)" stroke-width="1.5"/>`;
        else if (D.isOverdue(d.it)) svg += `<circle cx="${d.cx}" cy="${axisY}" r="6" fill="var(--surface)" stroke="var(--negative)" stroke-width="2.5"/>`;
        else svg += `<circle cx="${d.cx}" cy="${axisY}" r="7.5" fill="${D.color(d.list)}" stroke="${D.ink(d.list)}"/>`;
      });
    });
    host.innerHTML = svg + '</svg>';
  }

  // Once a day, when the last task due today is ticked with the thread on screen, the next draw plays the finale.
  function dayDone() {
    const today = D.today();
    if (!today.length || !today.every(({ it }) => it.d) || !app.querySelector('[data-thread]')) return;
    if (matchMedia('(prefers-reduced-motion: reduce)').matches) return;
    const key = 'weave-finale', day = new Date().toDateString();
    try { if (localStorage.getItem(key) === day) return; localStorage.setItem(key, day); } catch { /* storage off: still play */ }
    drawThread.finale = true;
    setTimeout(() => { drawThread.finale = false; }, 2000); // later redraws are plain
  }

  function nextScreen() {
    if (phone()) return `${pageTitle('Up next')}${todayCard()}${laterCard()}`;
    return `
      <div class="titlerow"><div class="tt">${pageTitle('Up next')}</div></div>
      <div class="grid eq">
        <div class="span-12">${threadCard()}</div>
        <div class="span-8">${todayCard({ withCapture: true })}</div>
        <div class="span-4">${laterCard()}</div> <!-- ragged bottoms on purpose: C12, no padding a card to match its neighbour -->
      </div>`;
  }

  // ---------- A list ----------
  // One fact (C2), and not the overdue count: the overdue row already leads the list in red (C1).
  function listSubline(l) {
    const o = D.open(l).length, n = D.nextUp(l);
    if (!o) return 'All done';
    const when = n ? (n.due.d === 0 ? `at <span class="num">${n.due.t}</span>` : `· <span class="num">${D.dueLabel(n.due)}</span>`) : '';
    return `<b class="num">${o}</b> left${n ? ` · next ${esc(n.t)} ${when}` : ''}`;
  }

  function itemRow(it) {
    if (it.type === 'text') return `<li class="noteline"><input class="ed" data-edit="${it.id}" value="${esc(it.t)}" aria-label="Text line"></li>`;
    const chips = [
      remindsOf(it).length ? `<span class="bells" title="Reminders: ${esc(remindsOf(it).join(', '))}">${I.bell}${remindsOf(it).length > 1 ? `<span class="num">${remindsOf(it).length}</span>` : ''}</span>` : '',
      it.repeat ? `<span title="Repeats ${esc(it.repeat)}">${I.repeat}</span>` : '',
      it.due && !it.d ? itemWhen(it) : '',
    ].join('');
    return `
      <li class="row ${it.d ? 'is-done' : ''} ${it.indent ? 'indent' : ''} ${state.sel === it.id ? 'sel' : ''} ${state.newItem === it.id ? 'is-new' : ''} ${rowMotion(it)}" data-id="${it.id}">
        ${phone() ? '' : `<span class="grip" title="Drag to reorder, or Alt+↑ / Alt+↓" aria-hidden="true">${I.grip}</span>`}
        <button class="check" data-act="tick" data-id="${it.id}" aria-label="${it.d ? 'Uncheck' : 'Check'} ${esc(it.t)}">${I.tick}</button>
        ${phone() ? `<button class="ed rowbtn" style="min-height:0" data-act="select" data-id="${it.id}">${esc(it.t)}</button>`
                  : `<input class="ed" data-edit="${it.id}" value="${esc(it.t)}" aria-label="Task. Alt+Up or Alt+Down moves it." data-act-focus="select" data-id="${it.id}">`}
        ${it.conflict ? `<span class="from">${esc(it.from)}</span><button class="btn ghost sm" data-act="keep" data-id="${it.id}">Keep only this</button>` : chips ? `<span class="chips">${chips}</span>` : ''}
        ${phone() ? '' : `<button class="ibtn chev" data-act="select" data-id="${it.id}" aria-label="Details for ${esc(it.t)}">${I.chevRight}</button>`}
      </li>`;
  }

  // Two versions of one task (F2.4): a note above them says what happened; each version can be kept alone.
  function conflictRows(rows) {
    const seen = new Set();
    return rows.map((it) => {
      if (!it.conflict || seen.has(it.conflict)) return itemRow(it);
      seen.add(it.conflict);
      const froms = rows.filter((x) => x.conflict === it.conflict).map((x) => x.from);
      return `<li class="conflict" role="note">${I.alert}<span class="grow">Changed on ${froms.map((f) => esc(f.replace(/^This/, 'this'))).join(' and ')} while one was offline. Both versions are kept.</span><button class="link" data-act="keep" data-group="${it.conflict}">Keep both</button></li>${itemRow(it)}`;
    }).join('');
  }

  function itemsBlock(l) {
    const open = l.items.filter((i) => i.type === 'text' || !i.d);
    const done = D.done(l);
    return `
      <ul class="rows items">${conflictRows(open)}</ul>
      ${phone() ? '' : `<div class="ruled">${capture(l, { inline: true })}${'<i aria-hidden="true"></i>'.repeat(8)}</div>`}
      ${!D.checks(l).length ? '<p class="empty">Nothing here yet. Type below and press Enter.</p>' : ''}
      ${done.length && l.hideDone ? `<div class="donebar"><span class="muted" style="font-size:13px">${done.length} done, hidden</span><span class="grow"></span><button class="btn ghost sm" data-act="hidedone">Show</button></div>` : ''}
      ${done.length && !l.hideDone ? `<div class="donefoot">
        <div class="donebar">
          <button class="toggle" data-act="done" aria-expanded="${state.showDone}">${I.chevRight} Done · ${done.length}</button>
          <span class="grow"></span><button class="btn ghost sm" data-act="uncheckall">Uncheck all</button>
        </div>
        <div class="donewrap ${state.showDone ? 'open' : ''}" ${state.showDone ? '' : 'inert'}><ul class="rows items">${done.map(itemRow).join('')}</ul></div></div>` : ''}`;
  }

  // Today on one list, as one line (07:00–23:00): the lived part in ink, its tasks as marks.


  // Dates: the prototype's day 0 is Tue 3 Nov 2026.
  const DATE0 = new Date(2026, 10, 3);
  const isoOf = (d) => { const x = new Date(DATE0); x.setDate(x.getDate() + d); return `${x.getFullYear()}-${String(x.getMonth() + 1).padStart(2, '0')}-${String(x.getDate()).padStart(2, '0')}`; };
  const daysTo = (iso) => Math.round((new Date(iso + 'T00:00') - DATE0) / 864e5);
  const remindsOf = (o) => o.reminds || (o.remind ? [o.remind] : []);
  const PRESET_DAYS = [0, 1, 6], PRESET_TIMES = ['09:00', '13:00', '17:00', '20:00'];

  // Due, Remind me and Repeat — the same fields for a task and for a whole list (F4.1).
  function whenFields(o) {
    const opt = (field, val, label = val, on, multi) => `<button class="opt ${on ? 'on' : ''}" data-act="set" data-field="${field}" data-val="${esc(val)}" ${multi ? `aria-pressed="${!!on}"` : ''}>${label}</button>`;
    const d = o.due ? o.due.d : null, t = o.due ? o.due.t : null;
    const rs = remindsOf(o);
    const every = /^Every (\d+) (\w+)/.exec(o.repeat || '');
    const fixedRem = (d != null ? ['At due time', '15 min before', '1 h before', '1 day before'] : []).concat(['In 1 h', 'Tomorrow 09:00']);
    return `
        <span class="field-label">Due</span>
        <div class="opts">${opt('day', '0', 'Today', d === 0)}${opt('day', '1', 'Tomorrow', d === 1)}${opt('day', '6', 'Next Mon', d === 6)}<label class="opt addtime ${d != null && !PRESET_DAYS.includes(d) ? 'on' : ''}">${I.clock}<span>${d != null && !PRESET_DAYS.includes(d) ? D.dueLabel({ d, t: null }) : 'Other date'}</span><input type="date" data-pick="date" value="${isoOf(d != null ? d : 0)}" min="${isoOf(0)}" aria-label="Pick a due date"></label>${opt('day', '', 'None', d == null)}</div>
        ${d != null ? `<div class="opts" style="margin-top:6px">${PRESET_TIMES.map((v) => opt('time', v, v, t === v)).join('')}<label class="opt addtime ${t && !PRESET_TIMES.includes(t) ? 'on' : ''}">${I.clock}<span>${t && !PRESET_TIMES.includes(t) ? t : 'Other time'}</span><input type="time" data-pick="time" value="${t || '09:00'}" aria-label="Pick a due time"></label></div>` : ''}
        <span class="field-label">Remind me</span>
        <div class="opts">${fixedRem.map((v) => opt('remind', v, v, rs.includes(v), true)).join('')}${rs.filter((r) => !fixedRem.includes(r)).map((r) => opt('remind', r, r, true, true)).join('')}<label class="opt addtime">${I.plus}<span>At a time</span><input type="time" data-pick="remind" aria-label="Add a reminder at a time"></label>${opt('remind', '', 'None', !rs.length)}</div>
        <p class="muted fine">${rs.length > 1 ? `${rs.length} reminders. ` : 'Pick as many as you like. '}${d != null ? '"Before" reminders move with the due time.' : ''}</p>
        <span class="field-label">Repeat</span>
        <div class="opts">${['Daily', 'Weekdays', 'Weekly', 'Monthly'].map((v) => opt('repeat', v, v, o.repeat === v)).join('')}${opt('repeat', 'custom', 'Custom', !!every)}${opt('repeat', '', 'Never', !o.repeat)}</div>
        ${every ? `<div class="every"><span>Every</span><input type="number" class="textin num" min="1" max="99" value="${every[1]}" data-pick="every" aria-label="Repeat every how many"><select class="textin" data-pick="every" aria-label="Repeat unit">${['days', 'weeks', 'months'].map((u) => `<option ${every[2] === u ? 'selected' : ''}>${u}</option>`).join('')}</select></div>` : ''}`;
  }

  const closeDetails = () => (phone() ? '' : `<button class="ibtn" style="width:28px;height:28px;margin:-4px -6px 0 0" data-act="deselect" aria-label="Close details">${I.close}</button>`);
  function details(it) {
    const l = listOf(it);
    return `
      <section class="card" aria-labelledby="h-task">
        <header><h2 id="h-task">Task</h2><span class="meta">in ${esc(l.name)}</span><span class="grow"></span>${closeDetails()}</header>
        <input class="textin" data-edit="${it.id}" value="${esc(it.t)}" aria-label="Task text">
        ${whenFields(it)}
        <span class="field-label">Order</span>
        <div class="opts"><button class="opt" data-act="move" data-dir="-1" data-id="${it.id}">Move up</button><button class="opt" data-act="move" data-dir="1" data-id="${it.id}">Move down</button></div>
        <div style="margin-top:20px;display:flex"><button class="btn danger" data-act="delete" data-id="${it.id}">${I.trash} Delete task</button></div>
      </section>`;
  }
  // The whole list's due date and reminders (F4.1), e.g. "pack by Friday".
  function listDetails(l) {
    return `
      <section class="card" aria-labelledby="h-ldue">
        <header><h2 id="h-ldue">Whole list</h2><span class="meta">${esc(l.name)}</span><span class="grow"></span>${closeDetails()}</header>
        <p class="muted fine" style="margin:0">For a deadline that belongs to the list, not one task.</p>
        ${whenFields(l)}
      </section>`;
  }
  const target = () => (state.sel === 'list' ? cur() : findItem(state.sel));

  function listScreen() {
    const l = cur();
    const sel = state.sel === 'list' ? 'list' : state.sel && findItem(state.sel);
    const ldue = l.due ? `<button class="tchip" data-act="listdue" title="The list's due date and reminders">${I.clock}<span class="num">Due ${D.dueLabel(l.due)}</span>${remindsOf(l).length ? I.bell : ''}</button>` : '';
    const title = `<h1><button class="dotbtn" data-act="colormenu" aria-label="Change colour">${dot(l)}</button><span data-rename contenteditable="plaintext-only" spellcheck="false" aria-label="List name, editable">${esc(l.name)}</span>${ldue}</h1>`;
    if (phone()) return `${title}<p class="subline">${listSubline(l)}</p><section class="card paper notecard" style="${cvars(l)}">${itemsBlock(l)}</section>`;
    return `
      <div class="titlerow">
        <div class="tt">${title}<p class="subline">${listSubline(l)}</p></div>
        <div class="actions">
          <button class="btn" data-act="onscreen" aria-pressed="${!!l.onScreen}">${l.onScreen ? I.check : I.screen} ${l.onScreen ? (state.os === 'ios' ? 'In widget' : 'In mini bar') : (state.os === 'ios' ? 'Add to widget' : 'Show in mini bar')}</button>
          <button class="btn" data-act="sharemenu">${I.share} Share</button>
          <button class="ibtn" data-act="more" aria-label="More">${I.more}</button>
        </div>
      </div>
      <div class="grid listgrid">
        <section class="card ${sel ? 'span-8' : 'span-12'} paper notecard" style="${cvars(l)}" aria-label="Tasks">${itemsBlock(l)}</section>
        ${sel ? `<div class="span-4">${sel === 'list' ? listDetails(l) : details(sel)}</div>` : ''}
      </div>`;
  }

  // ---------- Archive & trash ----------
  function archiveScreen() {
    const card = (title, rows, empty, kind) => `
      <section class="card" style="grid-column:span 6" aria-label="${title}">
        <header><h2>${title}</h2><span class="meta num">${rows.length}</span></header>
        ${rows.length ? `<ul class="rows">${rows.map((r) => `
          <li class="row" style="${cvars(r)}">
            ${dot(r)}<span class="t">${esc(r.name)}<br><span class="muted" style="font-size:12px">${kind === 'trash' ? `Deleted ${r.ago} days ago · empties in ${30 - r.ago} days` : `${r.n} items · ${r.when}`}</span></span>
            <button class="btn sm" data-act="restore" data-kind="${kind}" data-id="${r.id}">Restore</button>
            ${kind === 'trash' ? `<button class="btn danger sm" data-act="purge" data-id="${r.id}">Delete forever</button>` : ''}
          </li>`).join('')}</ul>` : `<p class="empty">${empty}</p>`}
      </section>`;
    return `
      <div class="titlerow"><div class="tt"><h1>Archive and trash</h1><p class="subline">Archived lists are hidden, not deleted. Trash empties itself after 30 days.</p></div></div>
      <div class="${phone() ? '' : 'grid'}">${card('Archive', archived, 'Nothing archived.', 'archive')}${card('Trash', trashed, 'Trash is empty.', 'trash')}</div>`;
  }

  // ---------- Settings ----------
  function settingsScreen() {
    const tg = (key, on, label) => `<button class="tg" role="switch" aria-checked="${on}" data-act="pref" data-key="${key}" aria-label="${label}"></button>`;
    const seg = (key, val, opts) => `<div class="seg" role="group">${opts.map(([v, lbl]) => `<button aria-pressed="${val === v}" data-act="seg" data-key="${key}" data-val="${v}">${lbl}</button>`).join('')}</div>`;
    const P = prefs;
    const capRow = `<div class="switchrow"><span class="lbl"><b>New tasks go to</b><small>${isPhoneOS() ? 'From the widget, Share to Weave and the notification.' : 'From the hotkey and Up next, unless you pick another list there.'}</small></span><select class="selin" data-pref="capture" aria-label="New tasks go to">${D.lists.map((l) => `<option value="${l.id}" ${l.id === P.capture ? 'selected' : ''}>${esc(l.name)}</option>`).join('')}</select></div>`;
    const floatPanel = state.os === 'ios' ? `
        <div class="switchrow"><span class="lbl"><b>Home-screen widget</b><small>iOS cannot float notes over other apps. The widget shows a chosen list, and items tick from there.</small></span>${tg('bar', P.bar, 'Widget')}</div>` : `
        <div class="switchrow"><span class="lbl"><b>Show the mini bar</b><small>${state.os === 'android' ? 'Needs "Display over other apps". Without it, Weave uses a notification and the home widget.' : 'A small bar above every app. Click it to open the sheet.'}</small></span>${tg('bar', P.bar, 'Show the mini bar')}</div>
        <div class="switchrow" style="display:block"><span class="lbl"><b>Opacity when idle</b><small>Full strength on hover, while dragging, and while open.</small></span>
          <div class="range" style="margin-top:12px"><input type="range" min="20" max="100" step="5" value="${state.floatOpacity}" data-range="opacity" aria-label="Opacity when idle"><span class="num" style="width:40px;text-align:right">${state.floatOpacity}%</span></div>
          <div class="preview" aria-hidden="true"><div class="pbar" style="opacity:${state.floatOpacity / 100}"><span class="dot"></span><b style="font-weight:500">Errands</b><span class="m"><span class="num" style="color:var(--text)">4</span> left</span></div></div></div>
        ${isPhoneOS() ? '' : `<div class="switchrow"><span class="lbl"><b>Quick-capture hotkey</b><small>Opens the sheet from anywhere, ready to type.</small></span><span class="kbd" style="padding-top:2px">⌥ Space</span></div>
        <div class="switchrow"><span class="lbl"><b>Hide in full-screen apps</b><small>Films and presentations stay clean.</small></span>${tg('fullscreen', P.fullscreen, 'Hide in full-screen apps')}</div>`}`;
    return `
      <div class="titlerow"><div class="tt"><h1>Settings</h1><p class="subline">Saved as you change them, on this device. Mini bar position and size are never synced.</p></div></div>
      <div class="settings">
        <section class="srow"><div><h2>Appearance</h2><p class="desc">Follows your system unless you pick one.</p></div>
          <div class="panel">${seg('theme', state.theme, [['system', 'System'], ['light', 'Light'], ['dark', 'Dark']])}</div></section>
        <section class="srow"><div><h2>${state.os === 'ios' ? 'Widgets' : 'Mini bar'}</h2><p class="desc">How Weave stays within reach without getting in the way.</p></div>
          <div class="panel">${floatPanel}${capRow}</div></section>
        <section class="srow"><div><h2>Notifications</h2><p class="desc">Reminders ring on every signed-in device. Done or snoozed on one clears the rest.</p></div>
          <div class="panel">
            <div class="switchrow"><span class="lbl"><b>Reminders</b><small>Scheduled on this device, so they ring offline too.</small></span>${tg('notif', P.notif, 'Reminders')}</div>
            <div class="switchrow" style="display:block"><span class="lbl"><b>Default snooze</b></span><div style="margin-top:10px">${seg('snooze', P.snooze, [['10m', '10 min'], ['1h', '1 hour'], ['tmrw', 'Tomorrow']])}</div></div>
          </div></section>
        ${state.account === 'local' ? `<section class="srow"><div><h2>Account and sync</h2><p class="desc">Weave works fully without an account. Sign in to see your lists on every device, end-to-end encrypted.</p></div>
          <div class="panel"><div class="switchrow"><span class="lbl"><b>Sync is off</b><small>Your ${D.lists.length} lists are on ${here()} only. Nothing leaves it.</small></span><button class="btn primary" data-act="modal" data-m="signin">Sign in</button></div></div></section>` : `
        <section class="srow"><div><h2>Account and sync</h2><p class="desc">Notes are encrypted on this device before they sync. Weave's server cannot read them.</p><p class="desc">Your recovery key is the only way back in if you lose every device.</p></div>
          <div class="panel">
            <table class="devtable"><thead><tr><th>Device</th><th>Last seen</th></tr></thead><tbody>
              ${D.devices.map((d) => `<tr><td><span class="dn">${d.kind === 'This Mac' ? I.laptop : I.device}${esc(d.name)} <span class="muted">${esc(d.kind)}</span></span></td><td class="num muted">${esc(d.seen)}</td></tr>`).join('')}
            </tbody></table>
            <div class="switchrow" style="margin-top:8px"><span class="lbl"><b>Recovery key</b><small>Made 12 Oct and shown once. We ask you to check it every 6 months.</small></span><button class="btn sm" data-act="modal" data-m="keycheck">${I.key} Check it</button></div>
            <div class="switchrow"><span class="lbl"><b>Add a device</b><small>Sign in on the new device, then let it in from here.</small></span><button class="btn sm" data-act="modal" data-m="adddevice">Add a device</button></div>
            <div class="switchrow"><span class="lbl"><b>Sign out</b><small>Removes your notes from ${here()}. They stay on your other devices.</small></span><button class="btn sm" data-act="modal" data-m="signout">Sign out…</button></div>
          </div></section>
        <section class="srow danger-zone"><div><h2>Delete account</h2><p class="desc">Deletes every note on every device and on the server.</p></div>
          <div class="panel"><p>This cannot be undone. You will type your email to confirm.</p><button class="btn danger" data-act="modal" data-m="delacct">Delete account…</button></div></section>`}
      </div>`;
  }

  // ---------- Search ----------
  function searchScreen() {
    const q = state.query.trim().toLowerCase();
    const hits = D.lists.flatMap((l) => l.items.filter((i) => i.t.toLowerCase().includes(q)).map((it) => ({ it, list: l })));
    const hl = (s) => esc(s).replace(new RegExp(esc(q).replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'ig'), (m) => `<mark>${m}</mark>`);
    return `
      <div class="titlerow"><div class="tt"><h1>Search</h1><p class="subline num">${hits.length} result${hits.length === 1 ? '' : 's'} for “${esc(state.query)}” across ${D.lists.length} lists. Works offline.</p></div></div>
      <section class="card" style="max-width:742px">${hits.length ? `<ul class="rows">${hits.map(({ it, list }) => `
        <li class="row" style="${cvars(list)}"><button class="rowbtn" data-act="goto" data-list="${list.id}" data-id="${it.id}"><span class="t">${hl(it.t)}</span><span class="src">${dot(list)}${esc(list.name)}</span></button>${it.type === 'check' ? itemWhen(it) : ''}</li>`).join('')}</ul>` : '<p class="empty">No matches. Try fewer letters.</p>'}</section>`;
  }

  // ---------- Desktop shell ----------
  const conflictList = () => D.lists.find((l) => l.items.some((i) => i.conflict));
  function sidebar() {
    const nav = (v, icon, label, n) => `<button class="navrow ${state.view === v && !state.query ? 'on' : ''}" data-act="nav" data-view="${v}">${icon}<span class="label">${label}</span>${n != null ? `<span class="n">${n}</span>` : ''}</button>`;
    const lrow = (l) => {
      return `<button class="navrow ${state.view === 'list' && state.cur === l.id && !state.query ? 'on' : ''} ${l.onScreen ? 'inbar' : ''}" style="${cvars(l)}" data-act="open" data-list="${l.id}"><span class="ndot">${dot(l)}</span><span class="label">${esc(l.name)}</span>${l.onScreen ? `<span class="onscreen" title="In the mini bar">${I.screen}<span class="sr">In the mini bar</span></span>` : ''}<span class="n">${D.open(l).length || ''}</span></button>`;
    };
    const dueToday = D.today().filter((x) => !x.it.d).length;
    return `
      <nav class="side" aria-label="Weave">
        <div class="brand">${I.mark}<b>Weave</b></div>
        ${state.account === 'local' ? `<span class="syncline">${I.laptop}On ${here()} only</span>` : conflictList() ? `<button class="syncline s-conflict" data-act="open" data-list="${conflictList().id}" title="Open ${esc(conflictList().name)}">${I.cloud}Synced · <span class="late">1 conflict</span></button>`
          : `<button class="syncline s-${state.sync}" data-act="sync" title="Sync status (click to cycle, demo)">${I.cloud}${SYNC[state.sync]}</button>`}
        <label class="search">${I.search}<input data-search placeholder="Search" value="${esc(state.query)}" aria-label="Search notes"><kbd>${mod()}K</kbd></label>
        ${nav('next', I.sun, 'Up next', dueToday)}
        <div class="group">Pinned</div>
        ${D.lists.filter((l) => l.pinned).map(lrow).join('')}
        <div class="group">Lists</div>
        ${D.lists.filter((l) => !l.pinned).map(lrow).join('')}
        <button class="navrow" data-act="newlist">${I.plus}<span class="label muted">New list</span><span class="kbd">${mod()}N</span></button>
        <div class="foot">
          ${nav('archive', I.archive, 'Archive and trash', archived.length + trashed.length)}
          ${nav('settings', I.gear, 'Settings')}
          ${state.account === 'local'
            ? `<button class="userrow local" data-act="modal" data-m="signin"><span class="avatar">${I.laptop}</span><span class="who">Local mode<small>Sign in to sync devices</small></span></button>`
            : `<div class="userrow"><span class="avatar">MY</span><span class="who">Mayank Yadav<small>End-to-end encrypted</small></span></div>`}
        </div>
      </nav>`;
  }

  function screen() {
    if (state.view === 'lists' || state.view === 'search') state.view = 'next'; // phone-only tabs
    if (state.query) return searchScreen();
    return { next: nextScreen, list: listScreen, settings: settingsScreen, archive: archiveScreen }[state.view]();
  }

  function chrome() {
    if (state.os === 'windows') return `<div class="chrome">${I.mark}<span class="wtitle">Weave</span><span class="grow"></span><span class="wctl"><i aria-hidden="true">${I.s('<path d="M4 8h8"/>', 12)}</i><i aria-hidden="true">${I.s('<rect x="4" y="4" width="8" height="8" rx=".5"/>', 12)}</i><i aria-hidden="true">${I.s('<path d="M4.5 4.5l7 7M11.5 4.5l-7 7"/>', 12)}</i></span></div>`;
    return `<div class="chrome"><span class="lights"><i></i><i></i><i></i></span><span class="grow"></span></div>`;
  }

  // ---------- Phone tabs: Lists and Search ----------
  function phoneLists() {
    const open = D.lists.reduce((n, l) => n + D.open(l).length, 0);
    return `
      <h1>Lists</h1><p class="subline num">${D.lists.length} lists · ${open} open</p>
      <section class="card" aria-label="Your lists">${listsCard().replace(/^[\s\S]*?<ul class="notes">/, '<ul class="notes">').replace(/<\/section>\s*$/, '')}</section>
      <div class="card" style="padding:4px 8px">
        <button class="navrow" data-act="newlist">${I.plus}<span class="label">New list</span></button>
        <button class="navrow" data-act="nav" data-view="archive">${I.archive}<span class="label">Archive and trash</span><span class="n">${archived.length + trashed.length}</span></button>
      </div>`;
  }

  function phoneSearch() {
    const q = state.query.trim();
    const box = `<label class="search psearch">${I.search}<input data-search placeholder="Search every list" value="${esc(state.query)}" aria-label="Search notes"></label>`;
    if (!q) return `<h1>Search</h1>${box}<p class="subline">Searches every task and note, offline too.</p>`;
    return box + searchScreen().replace(/<div class="titlerow">[\s\S]*?<\/div><\/div>/, (m) => m.replace('<h1>Search</h1>', '')).replace('style="max-width:742px"', '');
  }

  // The phone sheet survives re-renders by starting in the state it was last drawn in, then switching
  // to the new one after a reflow — so opening slides up and closing slides down (with its old content),
  // and edits inside an open sheet don't replay the motion.
  let lastSheet = { open: false, html: '' };
  function sheetLayer(html) {
    const open = !!state.psheet;
    const body = open ? html : lastSheet.html;
    const was = lastSheet.open;
    lastSheet = { open, html: open ? html : '' };
    return `
        <div class="psheet-scrim ${was ? 'on' : ''}" data-act="closesheet" data-to="${open ? 'on' : ''}"></div>
        <div class="psheet ${was ? 'on' : ''}" role="dialog" aria-label="Details" aria-hidden="${!open}" data-to="${open ? 'on' : ''}"><div class="handle"></div>${body}</div>`;
  }
  function settleSheet() {
    app.querySelectorAll('.psheet, .psheet-scrim').forEach((el) => {
      void el.offsetHeight; // commit the starting state so the change below transitions
      el.classList.toggle('on', el.dataset.to === 'on');
    });
  }

  // ---------- Phone shell ----------
  function phoneShell() {
    const l = cur();
    const sel = typeof state.sel === 'number' && findItem(state.sel);
    const inList = state.view === 'list';
    const sub = inList || state.view === 'archive'; // pushed inside the Lists tab
    // Back: iOS shows a chevron with the parent's name; Android a plain arrow (the system back gesture does the same).
    const back = state.os === 'android'
      ? `<button class="ibtn" data-act="nav" data-view="lists" aria-label="Back to Lists">${I.back}</button>`
      : `<button class="backlink" data-act="nav" data-view="lists">${I.back}Lists</button>`;
    const top = sub
      ? `${back}<span class="ttl"></span>${inList ? `<button class="ibtn" data-act="psheet" data-sheet="share" aria-label="Share">${I.share}</button><button class="ibtn" data-act="psheet" data-sheet="more" aria-label="More">${I.more}</button>` : ''}`
      : '';
    const tab = sub ? 'lists' : state.view;
    const tabs = [['next', I.sun, 'Up next'], ['lists', I.list, 'Lists'], ['search', I.search, 'Search'], ['settings', I.gear, 'Settings']];
    const dueToday = D.today().filter((x) => !x.it.d).length;
    const tabbar = `<nav class="ptabs" aria-label="Main">${tabs.map(([v, icon, label]) => `
      <button data-act="nav" data-view="${v}" ${tab === v ? 'aria-current="page"' : ''}><span class="ic">${icon}${v === 'next' && dueToday ? `<span class="badge num">${dueToday}</span>` : ''}</span><span class="tl">${label}</span></button>`).join('')}</nav>`;
    const showAdd = state.view === 'next' || inList;
    const sheet = state.psheet === 'item' && sel ? details(sel).replace('class="card"', 'class=""')
      : state.psheet === 'listdue' ? listDetails(l).replace('class="card"', 'class=""')
      : state.psheet === 'share' ? `<h2>Share ${esc(l.name)}</h2><div class="sharerow"><button class="btn" data-act="share" data-as="Text">Text</button><button class="btn" data-act="share" data-as="Markdown">Markdown</button><button class="btn" data-act="share" data-as="Image">Image</button></div>`
      : state.psheet === 'more' ? `<h2>${esc(l.name)}</h2>
          <div class="switchrow"><span class="lbl"><b>${state.os === 'ios' ? 'Show in widget' : 'Show in the bar'}</b></span><button class="tg" role="switch" aria-checked="${!!l.onScreen}" data-act="onscreen" aria-label="${state.os === 'ios' ? 'Show in widget' : 'Show in the bar'}"></button></div>
          <div class="switchrow"><span class="lbl"><b>Pin to top</b></span><button class="tg" role="switch" aria-checked="${!!l.pinned}" data-act="pinned" aria-label="Pin to top"></button></div>
          <div class="switchrow"><span class="lbl"><b>Hide done tasks</b></span><button class="tg" role="switch" aria-checked="${!!l.hideDone}" data-act="hidedone" aria-label="Hide done tasks"></button></div>
          <div class="switchrow"><span class="lbl"><b>Due date for the list</b><small>${l.due ? 'Due ' + D.dueLabel(l.due) : 'None'}</small></span><button class="btn sm" data-act="listdue">${l.due ? 'Change' : 'Set'}</button></div>
          <span class="field-label">Colour</span><div class="swatches">${[0, 1, 2, 3, 4, 5].map((c) => `<button class="swatch ${l.color === c ? 'on' : ''}" aria-label="${D.COLOR_NAMES[c]}" aria-pressed="${l.color === c}" data-act="color" data-c="${c}" style="--c:var(--n${c});--ci:var(--n${c}-ink)">${l.color === c ? I.tick : ''}</button>`).join('')}</div>
          <div style="display:flex;gap:8px;margin-top:20px"><button class="btn" data-act="archive">Archive</button><button class="btn danger" data-act="dellist">Delete</button></div><p class="muted" style="margin:16px 0 0;font-size:var(--fs-small)">Edited ${esc(l.edited || 'just now')}</p>` : '';
    return `
      <div class="phonestage"><div class="device"><div class="pscreen">
        <div class="pstatus"><span>16:20</span><span>${state.os === 'ios' ? '' : '5G 82%'}</span></div>
        <div class="ptop ${top ? '' : 'empty'}">${top}</div>
        <main class="pbody">${{ next: nextScreen, lists: phoneLists, search: phoneSearch, list: listScreen, settings: settingsScreen, archive: archiveScreen }[state.view]()}</main>
        ${showAdd ? `<div class="paddbar">${capture(inList ? l : null, { phoneBar: true })}</div>` : ''}
        ${tabbar}
        <div class="homebar"></div>
        ${sheetLayer(sheet)}
        ${modalLayer()}
      </div></div></div>`;
  }

  // ---------- Confirm dialogs (destructive account actions) ----------
  const KEY = ['WV7K', '3MPQ', '9XHT', '2RDA', 'LC4E', '8NUF'];
  const PAIR = '482 913';
  const others = () => D.devices.slice(1).map((d) => d.name);
  // A pairing code drawn as a grid (prototype stand-in for a real QR code).
  function qr() {
    let x = 7, cells = '';
    for (let r = 0; r < 21; r++) for (let c = 0; c < 21; c++) {
      const finder = (r < 7 && c < 7) || (r < 7 && c > 13) || (r > 13 && c < 7);
      const on = finder ? (Math.max(Math.abs(r % 14 - 3), Math.abs(c % 14 - 3)) !== 2 && !(r === 7 || c === 7 || r === 13 || c === 13)) : ((x = (x * 73 + r * 31 + c * 17) % 101) % 3 === 0);
      if (on) cells += `<rect x="${c}" y="${r}" width="1" height="1"/>`;
    }
    return `<svg class="qr" viewBox="-1 -1 23 23" role="img" aria-label="Pairing code. Or type ${PAIR} on your other device.">${cells}</svg>`;
  }
  const keyBox = () => `<div class="keybox num" aria-label="Recovery key ${KEY.join(' ')}">${KEY.map((g) => `<span>${g}</span>`).join('')}</div>
    <div class="keyacts"><button class="btn sm" data-act="copykey">Copy</button><button class="btn sm" data-act="copykey" data-as="file">Save as file</button><button class="btn sm" data-act="copykey" data-as="print">Print</button></div>
    <label class="ack"><input type="checkbox" data-ack> I've saved it somewhere safe, not only on ${here()}</label>`;

  // Every dialog: { t, body, ok, act, danger, off, cancel, wide }. Multi-step flows pick their step from state.step.
  function dialog() {
    const st = state.step;
    switch (state.modal) {
      case 'signout': return { t: `Sign out on ${here()}?`, body: `<p>Your notes are removed from ${here()}. They stay on your other ${D.devices.length - 1} devices and come back when you sign in here again.</p><p class="muted">Anything not yet synced is sent first. Weave waits for it.</p>`, ok: 'Sign out', act: 'dosignout' };
      case 'delacct': return { t: 'Delete your account?', body: `<p>This deletes every list on all ${D.devices.length} devices and on Weave's server, and it cannot be undone. Lists you want to keep: share them out first.</p><label class="fl" for="dlg-email">Type <b>${EMAIL}</b> to confirm</label><input id="dlg-email" class="textin" data-confirm autocomplete="off" spellcheck="false">`, ok: 'Delete account', act: 'dodelacct', danger: true, off: true };
      case 'signin':
        if (!st || st === 'choose') return { t: 'Sync your lists', body: `<p>Sign in or create an account. Lists are encrypted on ${here()} before they leave it, so Weave's server can't read them.</p>
          <div class="authbtns"><button class="btn wide" data-act="step" data-s="${state.existing ? 'approve' : 'upload'}">Continue with Apple</button><button class="btn wide" data-act="step" data-s="${state.existing ? 'approve' : 'upload'}">Continue with Google</button></div>
          <div class="or"><span>or with email</span></div>
          <form data-form="email" class="emailform"><label class="sr" for="dlg-em">Email</label><input id="dlg-em" class="textin" type="email" name="em" placeholder="you@example.com" autocomplete="email"> <!-- taste-skill-ignore: reserved demo domain --><button class="btn primary wide">Email me a sign-in link</button></form>
          <p class="fine muted">Prefer a password? <button class="link" data-act="step" data-s="password">Use a password</button></p>`, ok: null };
        if (st === 'password') return { t: 'Sign in with a password', body: `<form data-form="email" class="emailform"><label class="fl" for="dlg-em">Email</label><input id="dlg-em" class="textin" type="email" name="em" autocomplete="email"><label class="fl" for="dlg-pw">Password</label><input id="dlg-pw" class="textin" type="password" autocomplete="current-password"><button class="btn primary wide" style="margin-top:16px">Sign in</button></form>
          <p class="fine muted">Forgot it? <button class="link" data-act="step" data-s="choose">Email me a link instead</button>. Your lists stay encrypted either way.</p>`, ok: null };
        if (st === 'sent') return { t: 'Check your email', body: `<p>We sent a sign-in link to <b>${esc(state.email)}</b>. Open it on ${here()}. It works for 15 minutes.</p><p class="fine muted">Nothing there? Check spam, or <button class="link" data-act="step" data-s="sent">send it again</button>.</p>`, ok: 'I opened the link', okClass: 'demo', act: 'step', s: state.existing ? 'approve' : 'upload' };
        if (st === 'upload') {
          const n = D.lists.length, going = state.up > 0, u = Math.floor(state.up);
          return { t: `Bring your ${n} lists along?`, body: `<p>They're encrypted on ${here()}, then uploaded. Only your devices can read them.</p>
            <ul class="uplist">${D.lists.map((l, k) => `<li style="${cvars(l)}">${dot(l)}<span class="grow">${esc(l.name)}</span><span class="muted fine0">${k < u ? 'Uploaded' : going && k === u ? 'Encrypting…' : `${D.checks(l).length} tasks`}</span></li>`).join('')}</ul>
            ${going ? `<div class="bar" role="progressbar" aria-valuemin="0" aria-valuemax="${n}" aria-valuenow="${u}"><i style="width:${(u / n) * 100}%"></i></div>` : ''}`,
            ok: going ? `Uploading ${Math.min(u + 1, n)} of ${n}…` : 'Encrypt and upload', act: 'upload', off: going };
        }
        if (st === 'recovery') return { t: 'Save your recovery key', body: `<p>If you lose every device, this key is the only way back into your lists. Weave can't reset it or read your lists without it.</p>${keyBox()}<p class="fine muted">You'll see it once. You can make a new one in Settings.</p>`, ok: 'Done', act: 'finishsignin', off: true, nocancel: true };
        if (st === 'approve') return { t: `Let ${here()} in`, body: `<p>Your lists are encrypted, so a device you already use has to approve this one.</p>
          <div class="qrwrap">${qr()}<ol><li>Open Weave on ${others().join(' or ')}.</li><li>Settings → Account and sync → <b>Add a device</b>.</li><li>Scan this code, or type <b class="num">${PAIR}</b>.</li></ol></div>
          <p class="fine muted">No other device? <button class="link" data-act="step" data-s="keyentry">Use your recovery key</button></p>`, ok: `Approved on ${others()[0]}`, okClass: 'demo', act: 'finishsignin' };
        if (st === 'keyentry') return { t: 'Enter your recovery key', body: `<p>The 24-character key you saved when you set up sync.</p><label class="sr" for="dlg-key">Recovery key</label><input id="dlg-key" class="textin num keyin" placeholder="XXXX-XXXX-XXXX-XXXX-XXXX-XXXX" autocomplete="off" spellcheck="false" data-keyfull>
          ${state.keyErr ? '<p class="err">That key doesn\'t match. Check each group; 0 and O are different.</p>' : ''}`, ok: 'Open my lists', act: 'checkkeyfull' };
        break;
      case 'keycheck':
        return { t: 'Do you still have your recovery key?', body: `<p>It's been 6 months. If you lose every device, the key is the only way back in, so check that you can still find it.</p><label class="fl" for="dlg-k4">Type its last group of 4 characters</label><input id="dlg-k4" class="textin num" maxlength="4" autocomplete="off" spellcheck="false" style="width:120px;text-transform:uppercase" data-k4>
          ${state.keyErr ? '<p class="err">That doesn\'t match. Look again, or make a new key if it\'s lost.</p>' : ''}
          <p class="fine muted">Can't find it? <button class="link" data-act="modal" data-m="newkey">Make a new key</button></p>`, ok: 'Check', act: 'checkkey', cancel: 'Later' };
      case 'newkey':
        return { t: 'Your new recovery key', body: `<p>Your old key stops working now. Save this one instead: it's the only way back in if you lose every device.</p>${keyBox()}`, ok: 'Done', act: 'closemodal', off: true, nocancel: true };
      case 'adddevice':
        if (!st) return { t: 'Add a device', body: `<p>Sign in on the new device first. It then shows a code.</p>${isPhoneOS()
          ? `<div class="viewfinder" role="img" aria-label="Camera view"><i></i><span>Point at the code on the new device</span></div><p class="fine muted">Or <button class="link" data-act="step" data-s="type">type the code instead</button></p>`
          : `<form data-form="pair"><label class="fl" for="dlg-pair">Type the 6-digit code shown on the new device</label><input id="dlg-pair" class="textin num" inputmode="numeric" placeholder="000 000" autocomplete="off" style="width:160px"></form>`}`,
          ok: isPhoneOS() ? 'Code scanned' : 'Continue', okClass: isPhoneOS() ? 'demo' : '', act: 'step', s: 'confirm' };
        if (st === 'type') return { t: 'Add a device', body: `<form data-form="pair"><label class="fl" for="dlg-pair">Type the 6-digit code shown on the new device</label><input id="dlg-pair" class="textin num" inputmode="numeric" placeholder="000 000" autocomplete="off" style="width:160px"></form>`, ok: 'Continue', act: 'step', s: 'confirm' };
        return { t: 'Let this device read your lists?', body: `<div class="devconfirm">${I.laptop}<div><b>MacBook Pro</b><br><span class="muted">macOS · asked just now · Bengaluru</span></div></div><p>It will be able to read and change every list. Only approve a device you're holding right now.</p>`, ok: 'Approve', act: 'approvedev', cancel: "Don't allow" };
    }
    return null;
  }

  function modalLayer() {
    const M = dialog();
    if (!M) return '';
    return `<div class="mscrim" ${M.nocancel ? '' : 'data-act="closemodal"'}></div>
      <div class="dlg" role="alertdialog" aria-modal="true" aria-labelledby="dlg-t"><h2 id="dlg-t">${M.t}</h2>${M.body}
        ${M.ok || !M.nocancel ? `<div class="dlgacts">${M.nocancel ? '' : `<button class="btn ${M.ok ? '' : 'ghost'}" data-act="closemodal">${M.cancel || 'Cancel'}</button>`}${M.ok ? `<button class="btn ${M.danger ? 'dangerfill' : M.okClass === 'demo' ? 'demo' : 'primary'}" data-act="${M.act}" ${M.s ? `data-s="${M.s}"` : ''} ${M.off ? 'disabled' : ''}>${M.ok}</button>` : ''}</div>` : ''}</div>`;
  }

  // ---------- Render ----------
  const app = document.getElementById('app');
  function render() {
    const ph = phone();
    document.body.className = `os-${state.os} ${ph ? 'lay-phone' : 'lay-desk'} ${bare() ? 'bare' : ''} ${EMBED ? 'embed' : ''}`;
    const l = cur();
    document.documentElement.style.setProperty('--accent', state.view === 'list' ? D.color(l) : 'var(--n0)');
    document.documentElement.style.setProperty('--accent-ink', state.view === 'list' ? D.ink(l) : 'var(--n0-ink)');
    const focused = document.activeElement && document.activeElement.matches('[data-search]');
    app.innerHTML = ph ? phoneShell() : `${chrome()}<div class="desk">${sidebar()}<main class="canvas">${screen()}</main></div>${modalLayer()}`;
    const dlg = app.querySelector('.dlg'); if (dlg && !dlg.contains(document.activeElement)) { const f = dlg.querySelector('input:not([type=checkbox])') || dlg.querySelector('[data-act="closemodal"]') || dlg.querySelector('button'); if (f) f.focus({ preventScroll: true }); }
    if (focused) { const s = app.querySelector('[data-search]'); if (s) { s.focus(); s.setSelectionRange(s.value.length, s.value.length); } }
    state.newItem = null;
    if (ph) settleSheet(); else lastSheet = { open: false, html: '' };
    document.querySelectorAll('[data-os]').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.os === state.os)));
    document.fonts.ready.then(() => { app.querySelectorAll('[data-thread]').forEach(drawThread); placeMarks(); });
    renderPop();
  }

  // #marks: numbered badges (review.md D1–D13) on whatever each item changes, in either version.
  const MARK_AT = [
    ['D1', 'next', '.subline'], ['D3', 'next', '.daystrip'], ['D4', 'next', '.card:has(#h-today) .rows'],
    ['D5', 'next', '.lay-desk .card:has(#h-later)'], ['D7', 'next', '.capturebox'],
    ['D9', 'list', '.ruled .capture'], ['D11', 'list', '.subline'], ['D13', '*', '.side .navrow.inbar .n', true],
  ];
  const markLayer = document.createElement('div');
  markLayer.className = 'marks';
  function placeMarks() {
    if (!MARKS) return;
    if (!markLayer.isConnected) document.body.appendChild(markLayer);
    const html = [];
    MARK_AT.forEach(([id, view, sel, firstOnly]) => {
      if (view !== '*' && view !== state.view) return;
      (firstOnly ? [app.querySelector(sel)].filter(Boolean) : app.querySelectorAll(sel)).forEach((el) => {
        const r = el.getBoundingClientRect();
        if (!r.width) return;
        html.push(`<span class="mk" style="left:${Math.max(2, r.left - 12)}px;top:${Math.max(2, r.top - 10)}px">${id}</span>`);
        html.push(`<span class="mkbox" style="left:${r.left - 3}px;top:${r.top - 3}px;width:${r.width + 6}px;height:${r.height + 6}px"></span>`);
      });
    });
    markLayer.innerHTML = html.join('');
  }
  if (MARKS) { addEventListener('resize', placeMarks); addEventListener('scroll', placeMarks, true); }

  // Re-render, then slide rows that moved from where they were (FLIP), so nothing jumps.
  function flipRender(skipId) {
    const before = new Map();
    app.querySelectorAll('.row[data-id]').forEach((el) => before.set(el.dataset.id, el.getBoundingClientRect().top));
    render();
    app.querySelectorAll('.row[data-id]').forEach((el) => {
      const top = before.get(el.dataset.id);
      if (top == null || +el.dataset.id === skipId) return;
      const dy = top - el.getBoundingClientRect().top;
      if (!dy) return;
      el.style.transition = 'none';
      el.style.transform = `translateY(${dy}px)`;
      void el.offsetHeight;
      el.style.transition = 'transform var(--dur) var(--ease-out)';
      el.style.transform = '';
    });
  }

  // ---------- Floating menus (desktop): grow from their trigger, fade out; instant from the keyboard ----------
  const popEl = document.createElement('div');
  popEl.className = 'pop';
  document.body.appendChild(popEl);
  function renderPop() {
    if (!state.pop) { popEl.classList.remove('on'); return; }
    const l = cur();
    const items = {
      share: `<button data-act="share" data-as="Text">${I.text} Copy as text</button><button data-act="share" data-as="Markdown">${I.list} Copy as Markdown</button><button data-act="share" data-as="Image">${I.share} Share as image…</button>`,
      more: `<button data-act="pinned">${I.pin} ${l.pinned ? 'Unpin from top' : 'Pin to top'}</button><button data-act="listdue">${I.clock} ${l.due ? 'Change the list\'s due date' : 'Due date for the list'}</button><button data-act="hidedone">${I.check} ${l.hideDone ? 'Show done tasks' : 'Hide done tasks'}</button><hr><button data-act="archive">${I.archive} Archive</button><button class="danger" data-act="dellist">${I.trash} Delete list…</button><p class="popnote">Edited ${esc(l.edited || 'just now')}</p>`,
      color: [0, 1, 2, 3, 4, 5].map((c) => `<button data-act="color" data-c="${c}"><span class="dot" style="--c:var(--n${c});--ci:var(--n${c}-ink)"></span>${D.COLOR_NAMES[c]}${l.color === c ? ' (current)' : ''}</button>`).join(''),
    }[state.pop.kind];
    popEl.innerHTML = items;
    popEl.style.transformOrigin = state.pop.kind === 'color' ? 'left top' : 'right top';
    popEl.classList.toggle('kbd', !!state.pop.kbd);
    popEl.classList.add('on');
    popEl.style.left = Math.min(state.pop.x, innerWidth - 240) + 'px';
    popEl.style.top = state.pop.y + 'px';
    popEl.querySelector('button').focus();
  }
  function openPop(kind, el, e) {
    const r = el.getBoundingClientRect();
    state.pop = { kind, x: kind === 'color' ? r.left : r.right - 220, y: r.bottom + 6, kbd: !!e && e.detail === 0 };
    renderPop();
  }

  // ---------- Toast ----------
  const toastEl = document.createElement('div');
  toastEl.className = 'toast';
  toastEl.setAttribute('role', 'status');
  document.body.appendChild(toastEl);
  let toastT;
  function toast(msg, undo) {
    toastEl.innerHTML = `<span>${esc(msg)}</span>${undo ? '<button>Undo</button>' : ''}`;
    if (!toastEl.classList.contains('on')) { toastEl.classList.add('pre'); void toastEl.offsetHeight; toastEl.classList.remove('pre'); }
    toastEl.classList.add('on');
    if (undo) toastEl.querySelector('button').onclick = () => { undo(); toastEl.classList.remove('on'); render(); };
    clearTimeout(toastT);
    toastT = setTimeout(() => toastEl.classList.remove('on'), 4000);
  }

  // Move a task one place among its list's tasks (text lines stay where they are).
  function moveItem(it, dir) {
    const owner = listOf(it);
    const peers = owner.items.filter((i) => i.type === 'check' && i.d === it.d);
    const j = peers.indexOf(it) + dir;
    if (j < 0 || j >= peers.length) return false;
    const a = owner.items.indexOf(it), b = owner.items.indexOf(peers[j]);
    [owner.items[a], owner.items[b]] = [owner.items[b], owner.items[a]];
    return true;
  }

  // ---------- Actions ----------
  function act(a, b, e) {
    const l = cur();
    if (a !== 'share' && popEl.contains(b)) state.pop = null;
    switch (a) {
      case 'nav': state.view = b.dataset.view; state.query = ''; state.sel = null; state.pmenu = false; state.psheet = null; break;
      case 'open': state.view = 'list'; state.cur = +b.dataset.list; state.sel = null; state.query = ''; state.pmenu = false; state.showDone = false; break;
      case 'goto': state.view = 'list'; state.cur = +b.dataset.list; state.sel = +b.dataset.id; state.query = ''; if (phone()) state.psheet = 'item'; break;
      case 'tick': {
        const it = findItem(+b.dataset.id);
        const row = b.closest('.row');
        if (!it.d && row) {
          // Fill (120ms), fade the row (120ms), then the rows below close up (FLIP). Ticking several rows quickly never cancels one.
          state.ticking.add(it.id); row.classList.add('is-ticking');
          setTimeout(() => { state.leaving.add(it.id); app.querySelectorAll(`.row[data-id="${it.id}"]`).forEach((r) => r.classList.add('is-leaving')); }, 120);
          setTimeout(() => { it.d = true; state.ticking.delete(it.id); state.leaving.delete(it.id); dayDone(); flipRender(it.id); toast(`Checked "${it.t}"`, () => { it.d = false; }); }, 240);
          return;
        }
        it.d = !it.d; break;
      }
      case 'move': { moveItem(findItem(+b.dataset.id), +b.dataset.dir); break; }
      case 'select': state.sel = +b.dataset.id; if (phone()) state.psheet = 'item'; break;
      case 'deselect': state.sel = null; break;
      case 'listdue': state.sel = 'list'; state.pop = null; if (phone()) state.psheet = 'listdue'; break;
      case 'hidedone': l.hideDone = !l.hideDone; state.pop = null; break;
      case 'keep': {
        const owner = D.lists.find((x) => x.items.some((i) => i.conflict)); if (!owner) return;
        const g = b.dataset.group ? +b.dataset.group : findItem(+b.dataset.id).conflict;
        const snap = owner.items.map((i) => [i, i.conflict, i.from]);
        if (!b.dataset.group) owner.items = owner.items.filter((i) => i.conflict !== g || i.id === +b.dataset.id);
        owner.items.forEach((i) => { if (i.conflict === g) { delete i.conflict; delete i.from; } });
        render(); toast(b.dataset.group ? 'Kept both versions' : `Kept "${owner.items.find((i) => i.id === +b.dataset.id).t}"`, () => { owner.items = snap.map(([i, c, f]) => { if (c) { i.conflict = c; i.from = f; } return i; }); });
        return;
      }
      case 'modal': state.modal = b.dataset.m; state.step = null; state.keyErr = false; state.up = 0; break;
      case 'closemodal': state.modal = null; state.step = null; break;
      case 'step': state.step = b.dataset.s; state.keyErr = false; break;
      case 'upload': {
        state.up = 0.001; render();
        const n = D.lists.length;
        const tick = () => { state.up = Math.floor(state.up) + 1; if (state.up >= n) { state.step = 'recovery'; state.up = 0; } render(); if (state.step === 'upload') setTimeout(tick, 320); };
        setTimeout(tick, 320); return;
      }
      case 'copykey': toast(b.dataset.as === 'file' ? 'Saved Weave recovery key.txt' : b.dataset.as === 'print' ? 'Opening the print dialog…' : 'Recovery key copied. Paste it somewhere safe.'); return;
      case 'finishsignin': state.modal = null; state.step = null; state.account = 'in'; render(); toast(state.existing ? `Approved. Your lists are arriving on ${here()}.` : 'Sync is on. Your lists are encrypted and backed up.'); return;
      case 'checkkey': {
        const v = (app.querySelector('[data-k4]').value || '').trim().toUpperCase();
        if (v === KEY[KEY.length - 1]) { state.modal = null; render(); toast("That's the one. We'll ask again in 6 months."); return; }
        state.keyErr = true; break;
      }
      case 'checkkeyfull': {
        const v = (app.querySelector('[data-keyfull]').value || '').replace(/[^A-Z0-9]/gi, '').toUpperCase();
        if (v === KEY.join('')) { act('finishsignin', b); return; }
        state.keyErr = true; break;
      }
      case 'approvedev': state.modal = null; state.step = null; render(); toast('MacBook Pro can now read your lists.'); return;
      case 'dosignout': state.modal = null; render(); toast(`Signed out on ${here()}. Your lists are safe on your other devices.`); return;
      case 'dodelacct': state.modal = null; state.account = 'local'; render(); toast('Account deleted. Weave is back in local mode.'); return;
      case 'done': { // in place, so the rows grow open with the chevron
        state.showDone = !state.showDone;
        app.querySelectorAll('.donefoot').forEach((f) => {
          f.querySelector('[data-act="done"]').setAttribute('aria-expanded', String(state.showDone));
          const w = f.querySelector('.donewrap'); w.classList.toggle('open', state.showDone); w.inert = !state.showDone;
        });
        return;
      }
      case 'uncheckall': { const was = D.done(l); was.forEach((i) => { i.d = false; }); state.psheet = null; render(); toast(`Unchecked ${was.length} in ${l.name}`, () => was.forEach((i) => { i.d = true; })); return; }
      case 'set': {
        const it = target(); const v = b.dataset.val;
        if (b.dataset.field === 'day') it.due = v === '' ? null : { d: +v, t: (it.due && it.due.t) || '09:00' };
        if (b.dataset.field === 'time') it.due = { ...(it.due || { d: 0 }), t: v };
        if (b.dataset.field === 'remind') {
          const rs = remindsOf(it);
          it.reminds = v === '' ? [] : rs.includes(v) ? rs.filter((r) => r !== v) : [...rs, v];
          it.remind = it.reminds[0] || null;
        }
        if (b.dataset.field === 'repeat') it.repeat = v === 'custom' ? (/^Every/.test(it.repeat || '') ? it.repeat : 'Every 2 weeks') : v || null;
        break;
      }
      case 'delete': { const it = findItem(+b.dataset.id); const owner = listOf(it); const idx = owner.items.indexOf(it); owner.items.splice(idx, 1); state.sel = null; state.psheet = null; render(); toast(`Deleted "${it.t}"`, () => owner.items.splice(idx, 0, it)); return; }
      case 'color': l.color = +b.dataset.c; state.pop = null; break;
      case 'onscreen': l.onScreen = !l.onScreen; break; // several lists can float at once (F1)
      case 'pinned': l.pinned = !l.pinned; state.pop = null; break;
      case 'share': state.pop = null; state.psheet = null; render(); toast(b.dataset.as === 'Image' ? `Sharing ${l.name} as an image…` : `Copied ${l.name} as ${b.dataset.as}`); return;
      case 'sharemenu': openPop('share', b, e); return;
      case 'more': openPop('more', b, e); return;
      case 'colormenu': if (phone()) { state.psheet = 'more'; break; } openPop('color', b, e); return;
      case 'archive': case 'dellist': {
        const idx = D.lists.indexOf(l); D.lists.splice(idx, 1);
        if (a === 'archive') archived.unshift({ id: l.id, name: l.name, color: l.color, n: D.checks(l).length, when: 'Archived just now' });
        else trashed.unshift({ id: l.id, name: l.name, color: l.color, n: D.checks(l).length, ago: 0 });
        state.view = 'next'; state.psheet = null; state.pop = null; render();
        toast(a === 'archive' ? `Archived ${l.name}` : `Moved ${l.name} to trash`, () => { D.lists.splice(idx, 0, l); (a === 'archive' ? archived : trashed).shift(); state.view = 'list'; state.cur = l.id; });
        return;
      }
      case 'restore': { const arr = b.dataset.kind === 'trash' ? trashed : archived; const i = arr.findIndex((r) => r.id === +b.dataset.id); const [r] = arr.splice(i, 1); render(); toast(`Restored ${r.name}`); return; }
      case 'purge': { const i = trashed.findIndex((r) => r.id === +b.dataset.id); const [r] = trashed.splice(i, 1); render(); toast(`Deleted ${r.name}`, () => trashed.splice(i, 0, r)); return; }
      case 'newlist': {
        const nl = { id: D.id(), name: 'Untitled list', color: D.lists.length % 6, pinned: false, onScreen: false, edited: 'just now', items: [] };
        D.lists.push(nl); state.view = 'list'; state.cur = nl.id; state.pmenu = false; render();
        const r = app.querySelector('[data-rename]'); r.focus(); const rg = document.createRange(); rg.selectNodeContents(r); const sl = getSelection(); sl.removeAllRanges(); sl.addRange(rg); return;
      }
      case 'sync': { const k = Object.keys(SYNC); state.sync = k[(k.indexOf(state.sync) + 1) % k.length]; break; }
      case 'pref': { prefs[b.dataset.key] = !prefs[b.dataset.key]; break; }
      case 'seg': { if (b.dataset.key === 'theme') { state.theme = b.dataset.val; applyTheme(); } else prefs[b.dataset.key] = b.dataset.val; break; }
      case 'psheet': state.psheet = b.dataset.sheet; break;
      case 'closesheet': state.psheet = null; state.sel = null; break;
      case 'pmenu': state.pmenu = !state.pmenu; break;
      default: return;
    }
    render();
  }

  document.addEventListener('click', (e) => {
    if (e.target.matches('.addtime input')) { try { e.target.showPicker(); } catch { /* older browsers: the field takes typing */ } return; }
    const b = e.target.closest('[data-act]');
    if (!b) { if (state.pop && !popEl.contains(e.target)) { state.pop = null; renderPop(); } return; }
    if (b.closest('.proto')) return;
    act(b.dataset.act, b, e);
  });

  // Quick capture: parse as you type, add on Enter.
  document.addEventListener('input', (e) => {
    const t = e.target;
    if (t.matches('.capture input')) {
      const box = t.closest('.capture').nextElementSibling;
      const p = D.parseQuick(t.value);
      const hint = t.closest('.paddbar') ? '' : HINT;
      box.innerHTML = t.value.trim() && p.due ? `${I.clock}<span>${esc(D.parsePreview(p))} · adds as “${esc(p.text)}”</span>` : hint;
    }
    if (t.matches('[data-edit]')) { const it = findItem(+t.dataset.edit); if (it) it.t = t.value; }
    if (t.matches('[data-rename]')) { cur().name = t.textContent.trim() || 'Untitled list'; const side = app.querySelector('.side'); if (side) side.outerHTML = sidebar(); }
    if (t.matches('[data-search]')) { state.query = t.value; render(); }
    if (t.matches('[data-confirm]')) app.querySelector('[data-act="dodelacct"]').disabled = t.value.trim().toLowerCase() !== EMAIL;
    if (t.matches('[data-range="opacity"]')) { state.floatOpacity = +t.value; const p = app.querySelector('.preview .pbar'); p.style.opacity = state.floatOpacity / 100; t.nextElementSibling.textContent = state.floatOpacity + '%'; }
  });
  document.addEventListener('change', (e) => {
    const t = e.target;
    if (t.matches('[data-pref="capture"]')) { prefs.capture = +t.value; return; }
    if (t.matches('[data-ack]')) { app.querySelector('.dlg .dlgacts button:last-child').disabled = !t.checked; return; }
    if (!t.matches('[data-pick]') || !t.value) return;
    const o = target(); if (!o) return;
    const k = t.dataset.pick;
    if (k === 'date') o.due = { d: Math.max(0, daysTo(t.value)), t: (o.due && o.due.t) || '09:00' };
    if (k === 'time') o.due = { ...(o.due || { d: 0 }), t: t.value };
    if (k === 'remind') { const r = `At ${t.value}`; const rs = remindsOf(o); if (!rs.includes(r)) { o.reminds = [...rs, r]; o.remind = o.reminds[0]; } }
    if (k === 'every') { const w = t.closest('.every'); o.repeat = `Every ${Math.max(1, +w.querySelector('input').value || 1)} ${w.querySelector('select').value}`; }
    render();
  });
  document.addEventListener('submit', (e) => {
    if (e.target.matches('[data-form="email"]')) { e.preventDefault(); state.email = e.target.elements.em.value.trim() || 'you@example.com' /* taste-skill-ignore: reserved demo domain */; state.step = state.step === 'password' ? (state.existing ? 'approve' : 'upload') : 'sent'; render(); return; }
    if (e.target.matches('[data-form="pair"]')) { e.preventDefault(); state.step = 'confirm'; render(); return; }
    const f = e.target.closest('[data-form="capture"]');
    if (!f) return;
    e.preventDefault();
    const raw = f.elements.t.value.trim();
    if (!raw) return;
    const target = D.lists.find((l) => l.id === +(f.dataset.list || f.elements.list.value));
    const p = D.parseQuick(raw);
    const it = { id: D.id(), type: 'check', t: p.text || raw, d: false, indent: 0, due: p.due, remind: p.timer ? `In ${p.timer >= 60 ? p.timer / 60 + ' h' : p.timer + ' min'}` : null, repeat: null };
    const firstCheck = target.items.findIndex((i) => i.type === 'check');
    target.items.splice(firstCheck < 0 ? target.items.length : firstCheck, 0, it); // newest first
    state.newItem = it.id;
    render();
    const again = app.querySelector('.capture input'); if (again) again.focus();
    if (!f.dataset.list) toast(`Added to ${target.name}${p.due ? ' · ' + D.parsePreview(p) : ''}`);
  });
  // Inline editing on desktop: Enter adds below, Backspace on empty removes, Tab indents.
  document.addEventListener('keydown', (e) => {
    const t = e.target;
    if (e.key === 'Escape' && state.modal) { if (!(dialog() || {}).nocancel) { state.modal = null; state.step = null; render(); } return; }
    if (e.key === 'Escape') { if (state.pop) { popEl.classList.add('kbd'); state.pop = null; renderPop(); return; } if (state.psheet || state.sel) { state.psheet = null; state.sel = null; render(); } return; }
    if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') { e.preventDefault(); const s = app.querySelector('[data-search]'); if (s) s.focus(); return; }
    if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'n') { e.preventDefault(); act('newlist'); return; }
    if (!t.matches('.items [data-edit]')) return;
    const it = findItem(+t.dataset.edit), owner = listOf(it), idx = owner.items.indexOf(it);
    if (e.altKey && (e.key === 'ArrowUp' || e.key === 'ArrowDown') && it.type === 'check') {
      e.preventDefault();
      if (moveItem(it, e.key === 'ArrowUp' ? -1 : 1)) { render(); app.querySelector(`[data-edit="${it.id}"]`).focus(); }
      return;
    }
    if (e.key === 'Enter') {
      e.preventDefault();
      const n = { id: D.id(), type: 'check', t: '', d: false, indent: it.indent, due: null, remind: null, repeat: null };
      owner.items.splice(idx + 1, 0, n); render();
      app.querySelector(`[data-edit="${n.id}"]`).focus();
    } else if (e.key === 'Backspace' && t.value === '') {
      e.preventDefault();
      owner.items.splice(idx, 1); render();
      const prev = owner.items[idx - 1]; if (prev) { const p = app.querySelector(`[data-edit="${prev.id}"]`); if (p) p.focus(); }
    } else if (e.key === 'Tab' && it.type === 'check') {
      e.preventDefault();
      it.indent = e.shiftKey ? 0 : 1; render();
      app.querySelector(`[data-edit="${it.id}"]`).focus();
    }
  });
  document.addEventListener('focusin', (e) => {
    const t = e.target;
    if (t.matches('[data-act-focus="select"]') && !phone() && state.sel !== +t.dataset.id) {
      state.sel = +t.dataset.id;
      const rail = app.querySelector('.grid > .span-4');
      if (rail) rail.innerHTML = details(findItem(state.sel));
      app.querySelectorAll('.items .row').forEach((r) => r.classList.toggle('sel', r.contains(t)));
    }
  });

  // ---------- Theme and platform ----------
  function applyTheme() {
    const forced = hash.get('mode');
    const mode = state.theme === 'system' ? (forced ? `t-${forced}` : localStorage.getItem('weave2-mode') || 't-light') : `t-${state.theme}`;
    document.documentElement.classList.remove('t-light', 't-dark');
    document.documentElement.classList.add(mode);
    document.querySelectorAll('[data-theme]').forEach((x) => x.setAttribute('aria-pressed', String(x.dataset.theme === mode)));
  }
  document.querySelectorAll('[data-theme]').forEach((b) => b.addEventListener('click', () => { localStorage.setItem('weave2-mode', b.dataset.theme); state.theme = 'system'; applyTheme(); render(); }));
  document.querySelectorAll('[data-os]').forEach((b) => b.addEventListener('click', () => { state.os = b.dataset.os; localStorage.setItem('weave2-os', state.os); state.psheet = null; state.pmenu = false; render(); }));
  let rz;
  addEventListener('resize', () => { clearTimeout(rz); rz = setTimeout(render, 80); });

  applyTheme();
  render();
})();
