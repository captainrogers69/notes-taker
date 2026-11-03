// 03 · Weave app (throwaway prototype, not app code).
// Desktop: sidebar · canvas (Up next, a list, Archive & trash, Settings, search).
// Phone: top bar · screen · add bar pinned to the bottom · bottom sheets.
(function () {
  'use strict';
  const D = window.WeaveData, I = window.WeaveIcons, { esc } = D;
  const hash = new URLSearchParams(location.hash.slice(1));

  const archived = [
    { id: 91, name: 'Diwali shopping', color: 3, n: 7, when: 'Archived 28 Oct' },
    { id: 92, name: 'Flat viewing questions', color: 1, n: 4, when: 'Archived 12 Oct' },
  ];
  const trashed = [
    { id: 93, name: 'Old packing list', color: 5, n: 9, ago: 2 },
  ];

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
    pop: null,          // desktop floating menu: { kind, x, y }
    floatOpacity: 50,
    theme: 'system',
  };
  const SYNC = { synced: `Synced · ${D.devices.length} devices`, syncing: 'Syncing…', offline: 'Offline · changes saved here', error: 'Sync error · retrying' };
  const isPhoneOS = () => state.os === 'ios' || state.os === 'android';
  const bare = () => innerWidth < 720;
  const phone = () => isPhoneOS() || bare();
  const mod = () => (state.os === 'macos' || state.os === 'ios' ? '⌘' : 'Ctrl+');
  const cur = () => D.lists.find((l) => l.id === state.cur) || D.lists[0];
  const listOf = (it) => D.lists.find((l) => l.items.includes(it));
  const findItem = (iid) => { for (const l of D.lists) { const it = l.items.find((i) => i.id === iid); if (it) return it; } return null; };
  const cvars = (l) => `--c:${D.color(l)};--ci:${D.ink(l)};--c-ink:${D.ink(l)}`;
  const dot = (l) => `<span class="dot" style="${cvars(l)}"></span>`;

  // ---------- Shared fragments ----------
  function capture(target, { phoneBar = false } = {}) {
    const select = target ? '' : `
      <select name="list" aria-label="Add to list">${D.lists.map((l) => `<option value="${l.id}" ${l.id === 1 ? 'selected' : ''}>${esc(l.name)}</option>`).join('')}</select>`;
    return `
      <form class="capture" data-form="capture" ${target ? `data-list="${target.id}"` : ''}>
        <label class="field">${I.plus}<input name="t" autocomplete="off" placeholder="${target ? 'Add a task…' : 'Add a task… try “dentist fri 10am”'}" aria-label="Add a task${target ? ' to ' + esc(target.name) : ''}"></label>
        ${select}
        ${phoneBar ? '' : `<button class="btn primary">Add</button>`}
      </form>
      <div class="parse" aria-live="polite">${phoneBar ? '' : HINT}</div>`;
  }
  const HINT = `<span>Times and days are understood: 6pm, 18:30, tomorrow, tonight, in 2 h.</span>`;

  const itemWhen = (it) => (!it.due ? '' : D.isOverdue(it)
    ? `<span class="when late">${D.lateWhen(D.dueLabel(it.due), I.alert)}</span>`
    : `<span class="when">${D.dueLabel(it.due)}</span>`);

  function agendaRow(x, { showList = true } = {}) {
    const { it, list } = x;
    return `
      <li class="row ${it.d ? 'is-done' : ''}" style="${cvars(list)}">
        <button class="check" data-act="tick" data-id="${it.id}" aria-label="${it.d ? 'Uncheck' : 'Check'} ${esc(it.t)}">${I.tick}</button>
        <button class="rowbtn" data-act="goto" data-list="${list.id}" data-id="${it.id}">
          <span class="t">${esc(it.t)}</span>
          ${showList ? `<span class="src">${dot(list)}${esc(list.name)}</span>` : ''}
        </button>
        ${itemWhen(it)}
      </li>`;
  }

  // ---------- Up next ----------
  function upNextFinding() {
    const today = D.today();
    const open = today.filter((x) => !x.it.d);
    const late = open.filter((x) => D.isOverdue(x.it));
    const parts = [`${D.NOW.day}`, `<b class="num">${open.length}</b> due today`];
    if (late.length) parts.push(`<span class="late">${late.length} overdue since ${late[0].it.due.t}</span> · ${esc(late[0].it.t)}`);
    else if (open.length) parts.push(`next ${open[0].it.due.t} · ${esc(open[0].it.t)}`);
    else parts.push('nothing left for today');
    return parts.join(' · ');
  }

  function todayCard({ withCapture = false } = {}) {
    const t = D.today();
    const late = t.filter((x) => D.isOverdue(x.it));
    const upcoming = t.filter((x) => !x.it.d && !D.isOverdue(x.it));
    const done = t.filter((x) => x.it.d);
    // The list chip only earns its place when today mixes lists.
    const showList = new Set(t.map((x) => x.list.id)).size > 1;
    const row = (x) => agendaRow(x, { showList });
    return `
      <section class="card" aria-labelledby="h-today">
        <header><h2 id="h-today">Today</h2><span class="meta num">${upcoming.length + late.length} open · ${done.length} done</span></header>
        ${withCapture ? `<div class="capturebox">${capture(null)}</div>` : ''}
        ${late.length ? `<div class="subhead late">Overdue</div><ul class="rows">${late.map(row).join('')}</ul>` : ''}
        ${upcoming.length ? `<div class="subhead">Still to do</div><ul class="rows">${upcoming.map(row).join('')}</ul>` : ''}
        ${!upcoming.length && !late.length ? '<p class="empty">Nothing left for today.</p>' : ''}
        ${done.length ? `<div class="subhead">Done today</div><ul class="rows">${done.map(row).join('')}</ul>` : ''}
      </section>`;
  }

  function laterCard() {
    const later = D.laterThisWeek();
    return `
      <section class="card" aria-labelledby="h-later">
        <header><h2 id="h-later">Later this week</h2><span class="meta num">${later.length}</span></header>
        ${later.length ? `<ul class="rows">${later.map((x) => agendaRow(x)).join('')}</ul>` : '<p class="empty">Nothing scheduled after today.</p>'}
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

  // The bar's own words, as the mini bar shows them (same rule as assets/weave.js barMeta).
  function WeaveBarMeta(l) {
    const late = D.open(l).filter(D.isOverdue).length, n = D.nextUp(l), left = D.open(l).length;
    const head = left ? `<span class="num" style="color:var(--text)">${left}</span> left` : 'All done';
    if (late) return `${head} · <span class="late">${late} overdue</span>`;
    if (n && n.due.d === 0) return `${head} · next <span class="num" style="color:var(--text)">${n.due.t}</span>`;
    return head;
  }

  // The next reminder that will ring today, across lists: "16:45 · Reply to design review".
  function nextReminder() {
    const r = D.lists.flatMap((l) => D.open(l)).map((it) => ({ it, at: D.remindAt(it) }))
      .filter((x) => x.at != null && x.at > D.NOW.min).sort((a, b) => a.at - b.at)[0];
    return r ? `${D.fmtClock(r.at)} · ${esc(r.it.t)}` : '—';
  }

  function floatCard() {
    const l = D.lists.find((x) => x.onScreen) || D.lists[0];
    return `
      <section class="card" aria-labelledby="h-float">
        <header><h2 id="h-float">On screen</h2><button class="link" data-act="nav" data-view="settings">Mini bar settings</button></header>
        <dl class="kv">
          <dt>Mini bar shows</dt><dd><span style="display:inline-flex;gap:8px;align-items:center">${dot(l)}${esc(l.name)}</span></dd>
          <dt>Next reminder</dt><dd class="num">${nextReminder()}</dd>
          <dt>Hotkey</dt><dd><span class="kbd">⌥ Space</span></dd>
          <dt>Sync</dt><dd>${SYNC[state.sync]}</dd>
        </dl>
        <div class="preview onscreen-prev" role="img" aria-label="The mini bar as it looks now: ${esc(l.name)}, ${esc(D.leftLabel(l))}">
          <div class="pbar paper" style="${cvars(l)}" aria-hidden="true">${dot(l)}<b style="font-weight:500">${esc(l.name)}</b><span class="m">${WeaveBarMeta(l)}</span></div></div>
      </section>`;
  }

  function threadCard() {
    return `
      <section class="card thread" aria-labelledby="h-thread">
        <header><h2 id="h-thread">Today's thread</h2><span class="meta">${D.NOW.day}, 07:00 to 23:00</span>
          <span class="legend">
            <span><svg width="10" height="10"><circle cx="5" cy="5" r="4" fill="var(--surface)" stroke="var(--muted)" stroke-width="1.5"/></svg>Done</span>
            <span><svg width="10" height="10"><circle cx="5" cy="5" r="4.5" fill="var(--n0)" stroke="var(--n0-ink)"/></svg>Due</span>
            <span><svg width="10" height="10"><circle cx="5" cy="5" r="4" fill="var(--surface)" stroke="var(--negative)" stroke-width="2"/></svg>! Overdue</span>
          </span>
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

  function nextScreen() {
    if (phone()) return `
      <h1>Up next</h1><p class="subline">${upNextFinding()}</p>
      ${threadCard()}${todayCard()}${laterCard()}`;
    return `
      <div class="titlerow"><div class="tt"><h1>Up next</h1><p class="subline">${upNextFinding()}</p></div></div>
      <div class="grid eq">
        <div class="span-12">${threadCard()}</div>
        <div class="span-8 stack">${todayCard({ withCapture: true })}${laterCard()}</div>
        <div class="span-4 stack">${listsCard()}${floatCard()}</div>
      </div>`;
  }

  // ---------- A list ----------
  function listSubline(l) {
    const o = D.open(l).length, all = D.checks(l).length;
    const parts = [o ? `<b class="num">${o}</b> left of ${all}` : 'All done'];
    const late = D.open(l).filter(D.isOverdue);
    if (late.length) parts.push(`<span class="late">${late.length} overdue</span>`);
    if (l.onScreen) parts.push(state.os === 'ios' ? 'in the widget' : 'in the mini bar');
    parts.push(`edited ${l.edited || 'just now'}`);
    return parts.join(' · ');
  }

  function itemRow(it) {
    if (it.type === 'text') return `<li class="noteline"><input class="ed" data-edit="${it.id}" value="${esc(it.t)}" aria-label="Text line"></li>`;
    const chips = [
      it.remind ? `<span title="Reminder: ${esc(it.remind)}">${I.bell}</span>` : '',
      it.repeat ? `<span title="Repeats ${esc(it.repeat)}">${I.repeat}</span>` : '',
      it.due && !it.d ? itemWhen(it) : '',
    ].join('');
    return `
      <li class="row ${it.d ? 'is-done' : ''} ${it.indent ? 'indent' : ''} ${state.sel === it.id ? 'sel' : ''} ${state.newItem === it.id ? 'is-new' : ''}">
        ${phone() ? '' : `<span class="grip" title="Drag to reorder, or Alt+↑ / Alt+↓" aria-hidden="true">${I.grip}</span>`}
        <button class="check" data-act="tick" data-id="${it.id}" aria-label="${it.d ? 'Uncheck' : 'Check'} ${esc(it.t)}">${I.tick}</button>
        ${phone() ? `<button class="ed rowbtn" style="min-height:0" data-act="select" data-id="${it.id}">${esc(it.t)}</button>`
                  : `<input class="ed" data-edit="${it.id}" value="${esc(it.t)}" aria-label="Task. Alt+Up or Alt+Down moves it." data-act-focus="select" data-id="${it.id}">`}
        ${chips ? `<span class="chips">${chips}</span>` : ''}
        ${phone() ? '' : `<button class="ibtn chev" data-act="select" data-id="${it.id}" aria-label="Details for ${esc(it.t)}">${I.chevRight}</button>`}
      </li>`;
  }

  function itemsBlock(l) {
    const open = l.items.filter((i) => i.type === 'text' || !i.d);
    const done = D.done(l);
    return `
      <ul class="rows items">${open.map(itemRow).join('')}</ul>
      ${phone() ? '' : `<button class="ruled" data-act="focusadd"><i>Add a task…</i>${'<i aria-hidden="true"></i>'.repeat(8)}</button>`}
      ${!D.checks(l).length ? '<p class="empty">Nothing here yet. Type above and press Enter.</p>' : ''}
      ${done.length ? `<div class="donefoot">
        <div class="donebar">
          <button class="toggle" data-act="done" aria-expanded="${state.showDone}">${I.chevRight} Done · ${done.length}</button>
          <span class="grow"></span><button class="btn ghost sm" data-act="uncheckall">Uncheck all</button>
        </div>
        ${state.showDone ? `<ul class="rows items">${done.map(itemRow).join('')}</ul>` : ''}</div>` : ''}`;
  }

  // Today on one list, as one line (07:00–23:00): the lived part in ink, its tasks as marks.
  function listStrip(l) {
    const due = D.checks(l).filter((i) => i.due && i.due.d === 0 && i.due.t);
    if (!due.length) return '<p class="muted" style="margin:0">Nothing timed today.</p>';
    const W = 300, S = 7 * 60, E = 23 * 60;
    const x = (m) => 6 + Math.round(((Math.min(E, Math.max(S, m)) - S) / (E - S)) * (W - 12));
    const nx = x(D.NOW.min);
    const marks = due.map((i) => {
      const cx = x(D.toMin(i.due.t));
      if (i.d) return `<circle cx="${cx}" cy="9" r="4" fill="var(--surface)" stroke="var(--muted)" stroke-width="1.5"/>`;
      if (D.isOverdue(i)) return `<circle cx="${cx}" cy="9" r="4.5" fill="var(--surface)" stroke="var(--negative)" stroke-width="2"/>`;
      return `<circle cx="${cx}" cy="9" r="5.5" fill="${D.color(l)}" stroke="${D.ink(l)}"/>`;
    }).join('');
    const said = due.map((i) => `${i.due.t} ${esc(i.t)}${i.d ? ' (done)' : D.isOverdue(i) ? ' (overdue)' : ''}`).join(', ');
    return /* taste-skill-ignore: hour labels, not numbering */ `<div class="lstrip"><span aria-hidden="true">07</span>
      <svg viewBox="0 0 ${W} 18" height="18" role="img" aria-label="Today on ${esc(l.name)}: ${said}. Now ${D.NOW.clock}.">
        <line x1="6" x2="${W - 6}" y1="9" y2="9" stroke="var(--control)" stroke-width="2" stroke-linecap="round"/>
        <line x1="6" x2="${nx}" y1="9" y2="9" stroke="var(--text)" stroke-width="2" stroke-linecap="round"/>
        <line x1="${nx}" x2="${nx}" y1="1" y2="17" stroke="var(--text)" stroke-width="1.5"/>${marks}</svg>
      <span aria-hidden="true">23</span></div>`;
  }

  function listInfo(l) {
    const reminders = D.open(l).filter((i) => i.remind);
    return `
      <section class="card railcard" aria-labelledby="h-info">
        <header><h2 id="h-info">This list</h2></header>
        <span class="field-label">Colour</span>
        <div class="swatches" role="radiogroup" aria-label="List colour">${[0, 1, 2, 3, 4, 5].map((c) => `
          <button class="swatch ${l.color === c ? 'on' : ''}" role="radio" aria-checked="${l.color === c}" aria-label="${D.COLOR_NAMES[c]}" data-act="color" data-c="${c}" style="--c:var(--n${c});--ci:var(--n${c}-ink)">${l.color === c ? I.tick : ''}</button>`).join('')}</div>
        <span class="field-label">Today</span>
        ${listStrip(l)}
        <span class="field-label">Reminders <span class="muted num" style="font-weight:400">${reminders.length}</span></span>
        ${reminders.length ? `<dl class="kv">${reminders.map((i) => `<dt>${esc(i.t)}</dt><dd class="num muted">${esc(i.remind)}</dd>`).join('')}</dl>` : '<p class="empty">No reminders on this list.</p>'}
        <div class="railfoot"><span class="field-label">Order</span>
        <div class="switchrow"><span class="lbl"><b>Pin to top</b><small>Keeps it first in your lists.</small></span>
          <button class="tg" role="switch" aria-checked="${!!l.pinned}" data-act="pinned" aria-label="Pin to top"></button></div></div>
      </section>`;
  }

  function details(it) {
    const opt = (field, val, label = val, on) => `<button class="opt ${on ? 'on' : ''}" data-act="set" data-field="${field}" data-val="${esc(val)}">${label}</button>`;
    const d = it.due ? it.due.d : null, t = it.due ? it.due.t : null;
    const l = listOf(it);
    return `
      <section class="card" aria-labelledby="h-task">
        <header><h2 id="h-task">Task</h2><span class="meta">in ${esc(l.name)}</span><span class="grow"></span>
          ${phone() ? '' : `<button class="ibtn" style="width:28px;height:28px;margin:-4px -6px 0 0" data-act="deselect" aria-label="Close details">${I.close}</button>`}</header>
        <input class="textin" data-edit="${it.id}" value="${esc(it.t)}" aria-label="Task text">
        <span class="field-label">Due</span>
        <div class="opts">${opt('day', '0', 'Today', d === 0)}${opt('day', '1', 'Tomorrow', d === 1)}${opt('day', '6', 'Next Mon', d === 6)}${opt('day', '', 'None', d == null)}</div>
        ${d != null ? `<div class="opts" style="margin-top:6px">${['09:00', '13:00', '17:00', '20:00'].map((v) => opt('time', v, v, t === v)).join('')}</div>` : ''}
        <span class="field-label">Remind me</span>
        <div class="opts">${(d != null ? ['At due time', '15 min before', '1 h before', '1 day before'] : []).concat(['In 1 h', 'Tomorrow 09:00']).map((v) => opt('remind', v, v, it.remind === v)).join('')}${opt('remind', '', 'None', !it.remind)}</div>
        ${d != null ? '<p class="muted" style="margin:8px 0 0;font-size:12px">"Before" reminders move with the due time.</p>' : ''}
        <span class="field-label">Repeat</span>
        <div class="opts">${['Daily', 'Weekdays', 'Weekly', 'Monthly'].map((v) => opt('repeat', v, v, it.repeat === v)).join('')}${opt('repeat', '', 'Never', !it.repeat)}</div>
        <span class="field-label">Order</span>
        <div class="opts"><button class="opt" data-act="move" data-dir="-1" data-id="${it.id}">Move up</button><button class="opt" data-act="move" data-dir="1" data-id="${it.id}">Move down</button></div>
        <div style="margin-top:20px;display:flex"><button class="btn danger" data-act="delete" data-id="${it.id}">${I.trash} Delete task</button></div>
      </section>`;
  }

  function listScreen() {
    const l = cur();
    const sel = state.sel && findItem(state.sel);
    const title = `<h1><button class="dotbtn" data-act="colormenu" aria-label="Change colour">${dot(l)}</button><span data-rename contenteditable="plaintext-only" spellcheck="false" aria-label="List name, editable">${esc(l.name)}</span></h1>`;
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
        <section class="card span-8 paper notecard" style="${cvars(l)}" aria-label="Tasks">${capture(l)}<div style="height:8px"></div>${itemsBlock(l)}</section>
        <div class="span-4">${sel ? details(sel) : listInfo(l)}</div>
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
    const P = settingsScreen.p || (settingsScreen.p = { bar: true, fullscreen: true, notif: true, snooze: '10m' });
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
        <section class="srow"><div><h2>${state.os === 'ios' ? 'Widgets' : 'Mini bar'}</h2><p class="desc">How Weave stays within reach without getting in the way.</p>${state.os === 'ios' ? '' : `<p class="desc">Now: ${settingsScreen.p && !settingsScreen.p.bar ? 'hidden' : 'shown'}, <span class="num">${state.floatOpacity}%</span> when idle${isPhoneOS() ? '' : ', ⌥ Space to open'}.</p>`}</div>
          <div class="panel">${floatPanel}</div></section>
        <section class="srow"><div><h2>Notifications</h2><p class="desc">Reminders ring on every signed-in device. Done or snoozed on one clears the rest.</p></div>
          <div class="panel">
            <div class="switchrow"><span class="lbl"><b>Reminders</b><small>Scheduled on this device, so they ring offline too.</small></span>${tg('notif', P.notif, 'Reminders')}</div>
            <div class="switchrow" style="display:block"><span class="lbl"><b>Default snooze</b></span><div style="margin-top:10px">${seg('snooze', P.snooze, [['10m', '10 min'], ['1h', '1 hour'], ['tmrw', 'Tomorrow']])}</div></div>
          </div></section>
        <section class="srow"><div><h2>Account and sync</h2><p class="desc">Notes are encrypted on this device before they sync. Weave's server cannot read them.</p><p class="desc">Your recovery key is the only way back in if you lose every device.</p></div>
          <div class="panel">
            <table class="devtable"><thead><tr><th>Device</th><th>Last seen</th></tr></thead><tbody>
              ${D.devices.map((d) => `<tr><td><span class="dn">${d.kind === 'This Mac' ? I.laptop : I.device}${esc(d.name)} <span class="muted">${esc(d.kind)}</span></span></td><td class="num muted">${esc(d.seen)}</td></tr>`).join('')}
            </tbody></table>
            <div class="switchrow" style="margin-top:8px"><span class="lbl"><b>Recovery key</b><small>Saved 12 Oct. We'll remind you to check it every 6 months.</small></span><button class="btn sm">${I.key} Show again</button></div>
            <div class="switchrow"><span class="lbl"><b>Add a device</b><small>Scan the code from the new device, or enter the recovery key there.</small></span><button class="btn sm">Show code</button></div>
            <div class="switchrow"><span class="lbl"><b>Sign out</b><small>Removes your notes from this Mac. They stay on your other devices.</small></span><button class="btn sm">Sign out…</button></div>
          </div></section>
        <section class="srow danger-zone"><div><h2>Delete account</h2><p class="desc">Deletes every note on every device and on the server.</p></div>
          <div class="panel"><p>This cannot be undone. You will type your email to confirm.</p><button class="btn danger">Delete account…</button></div></section>
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
  function sidebar() {
    const nav = (v, icon, label, n) => `<button class="navrow ${state.view === v && !state.query ? 'on' : ''}" data-act="nav" data-view="${v}">${icon}<span class="label">${label}</span>${n != null ? `<span class="n">${n}</span>` : ''}</button>`;
    const lrow = (l) => {
      const all = D.checks(l).length, done = D.done(l).length;
      const pct = all ? Math.round((done / all) * 100) : 0;
      return `<button class="navrow ${state.view === 'list' && state.cur === l.id && !state.query ? 'on' : ''} ${l.onScreen ? 'inbar' : ''}" style="${cvars(l)}" data-act="open" data-list="${l.id}"><span class="ndot">${dot(l)}</span><span class="label">${esc(l.name)}</span>${l.onScreen ? `<span class="onscreen" title="In the mini bar">${I.screen}<span class="sr">In the mini bar</span></span>` : ''}<span class="prog" style="--p:${pct}%" title="${done} of ${all} done" aria-hidden="true"></span><span class="n">${D.open(l).length || ''}</span></button>`;
    };
    const dueToday = D.today().filter((x) => !x.it.d).length;
    return `
      <nav class="side" aria-label="Weave">
        <div class="brand">${I.mark}<b>Weave</b></div>
        <button class="syncline s-${state.sync}" data-act="sync" title="Sync status (click to cycle, demo)">${I.cloud}${SYNC[state.sync]}</button>
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
          <div class="userrow"><span class="avatar">MY</span><span class="who">Mayank Yadav<small>End-to-end encrypted</small></span></div>
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
    const sel = state.sel && findItem(state.sel);
    const inList = state.view === 'list';
    const sub = inList || state.view === 'archive'; // pushed inside the Lists tab
    // Back: iOS shows a chevron with the parent's name; Android a plain arrow (the system back gesture does the same).
    const back = state.os === 'android'
      ? `<button class="ibtn" data-act="nav" data-view="lists" aria-label="Back to Lists">${I.back}</button>`
      : `<button class="backlink" data-act="nav" data-view="lists">${I.back}Lists</button>`;
    const top = sub
      ? `${back}<span class="ttl"></span>${inList ? `<button class="ibtn" data-act="psheet" data-sheet="share" aria-label="Share">${I.share}</button><button class="ibtn" data-act="psheet" data-sheet="more" aria-label="More">${I.more}</button>` : ''}`
      : `<span class="ttl"><span style="display:inline-flex;align-items:center;gap:8px">${I.mark}Weave</span></span>`;
    const tab = sub ? 'lists' : state.view;
    const tabs = [['next', I.sun, 'Up next'], ['lists', I.list, 'Lists'], ['search', I.search, 'Search'], ['settings', I.gear, 'Settings']];
    const dueToday = D.today().filter((x) => !x.it.d).length;
    const tabbar = `<nav class="ptabs" aria-label="Main">${tabs.map(([v, icon, label]) => `
      <button data-act="nav" data-view="${v}" ${tab === v ? 'aria-current="page"' : ''}><span class="ic">${icon}${v === 'next' && dueToday ? `<span class="badge num">${dueToday}</span>` : ''}</span><span class="tl">${label}</span></button>`).join('')}</nav>`;
    const showAdd = state.view === 'next' || inList;
    const sheet = state.psheet === 'item' && sel ? details(sel).replace('class="card"', 'class=""')
      : state.psheet === 'share' ? `<h2>Share ${esc(l.name)}</h2><div class="sharerow"><button class="btn" data-act="share" data-as="Text">Text</button><button class="btn" data-act="share" data-as="Markdown">Markdown</button><button class="btn" data-act="share" data-as="Image">Image</button></div>`
      : state.psheet === 'more' ? `<h2>${esc(l.name)}</h2>
          <div class="switchrow"><span class="lbl"><b>${state.os === 'ios' ? 'Show in widget' : 'Show in the bar'}</b></span><button class="tg" role="switch" aria-checked="${!!l.onScreen}" data-act="onscreen" aria-label="${state.os === 'ios' ? 'Show in widget' : 'Show in the bar'}"></button></div>
          <div class="switchrow"><span class="lbl"><b>Pin to top</b></span><button class="tg" role="switch" aria-checked="${!!l.pinned}" data-act="pinned" aria-label="Pin to top"></button></div>
          <span class="field-label">Colour</span><div class="swatches">${[0, 1, 2, 3, 4, 5].map((c) => `<button class="swatch ${l.color === c ? 'on' : ''}" aria-label="${D.COLOR_NAMES[c]}" aria-pressed="${l.color === c}" data-act="color" data-c="${c}" style="--c:var(--n${c});--ci:var(--n${c}-ink)">${l.color === c ? I.tick : ''}</button>`).join('')}</div>
          <div style="display:flex;gap:8px;margin-top:20px"><button class="btn" data-act="uncheckall">Uncheck all</button><button class="btn" data-act="archive">Archive</button><button class="btn danger" data-act="dellist">Delete</button></div>` : '';
    return `
      <div class="phonestage"><div class="device"><div class="pscreen">
        <div class="pstatus"><span>16:20</span><span>${state.os === 'ios' ? '' : '5G 82%'}</span></div>
        <div class="ptop">${top}</div>
        <main class="pbody">${{ next: nextScreen, lists: phoneLists, search: phoneSearch, list: listScreen, settings: settingsScreen, archive: archiveScreen }[state.view]()}</main>
        ${showAdd ? `<div class="paddbar">${capture(inList ? l : null, { phoneBar: true })}</div>` : ''}
        ${tabbar}
        <div class="homebar"></div>
        ${sheetLayer(sheet)}
      </div></div></div>`;
  }

  // ---------- Render ----------
  const app = document.getElementById('app');
  function render() {
    const ph = phone();
    document.body.className = `os-${state.os} ${ph ? 'lay-phone' : 'lay-desk'} ${bare() ? 'bare' : ''}`;
    const l = cur();
    document.documentElement.style.setProperty('--accent', state.view === 'list' ? D.color(l) : 'var(--n0)');
    document.documentElement.style.setProperty('--accent-ink', state.view === 'list' ? D.ink(l) : 'var(--n0-ink)');
    const focused = document.activeElement && document.activeElement.matches('[data-search]');
    app.innerHTML = ph ? phoneShell() : `${chrome()}<div class="desk">${sidebar()}<main class="canvas">${screen()}</main></div>`;
    if (focused) { const s = app.querySelector('[data-search]'); if (s) { s.focus(); s.setSelectionRange(s.value.length, s.value.length); } }
    state.newItem = null;
    if (ph) settleSheet(); else lastSheet = { open: false, html: '' };
    document.querySelectorAll('[data-os]').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.os === state.os)));
    document.fonts.ready.then(() => app.querySelectorAll('[data-thread]').forEach(drawThread));
    renderPop();
  }

  // ---------- Floating menus (desktop) ----------
  const popEl = document.createElement('div');
  popEl.className = 'pop';
  popEl.hidden = true;
  document.body.appendChild(popEl);
  function renderPop() {
    if (!state.pop) { popEl.hidden = true; return; }
    const l = cur();
    const items = {
      share: `<button data-act="share" data-as="Text">${I.text} Copy as text</button><button data-act="share" data-as="Markdown">${I.list} Copy as Markdown</button><button data-act="share" data-as="Image">${I.share} Share as image…</button>`,
      more: `<button data-act="pinned">${I.pin} ${l.pinned ? 'Unpin from top' : 'Pin to top'}</button><button data-act="uncheckall">${I.repeat} Uncheck all</button><hr><button data-act="archive">${I.archive} Archive</button><button class="danger" data-act="dellist">${I.trash} Delete list…</button>`,
      color: [0, 1, 2, 3, 4, 5].map((c) => `<button data-act="color" data-c="${c}"><span class="dot" style="--c:var(--n${c});--ci:var(--n${c}-ink)"></span>${D.COLOR_NAMES[c]}${l.color === c ? ' (current)' : ''}</button>`).join(''),
    }[state.pop.kind];
    popEl.innerHTML = items;
    popEl.hidden = false;
    popEl.style.left = Math.min(state.pop.x, innerWidth - 240) + 'px';
    popEl.style.top = state.pop.y + 'px';
    popEl.querySelector('button').focus();
  }
  function openPop(kind, el) {
    const r = el.getBoundingClientRect();
    state.pop = { kind, x: kind === 'color' ? r.left : r.right - 220, y: r.bottom + 6 };
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
        if (!it.d && row) { row.classList.add('is-ticking'); setTimeout(() => { it.d = true; render(); toast(`Checked "${it.t}"`, () => { it.d = false; }); }, 280); return; }
        it.d = !it.d; break;
      }
      case 'focusadd': { const i = app.querySelector('.notecard .capture input'); if (i) i.focus(); return; }
      case 'move': { moveItem(findItem(+b.dataset.id), +b.dataset.dir); break; }
      case 'select': state.sel = +b.dataset.id; if (phone()) state.psheet = 'item'; break;
      case 'deselect': state.sel = null; break;
      case 'done': state.showDone = !state.showDone; break;
      case 'uncheckall': { const was = D.done(l); was.forEach((i) => { i.d = false; }); state.psheet = null; render(); toast(`Unchecked ${was.length} in ${l.name}`, () => was.forEach((i) => { i.d = true; })); return; }
      case 'set': {
        const it = findItem(state.sel); const v = b.dataset.val;
        if (b.dataset.field === 'day') it.due = v === '' ? null : { d: +v, t: (it.due && it.due.t) || '09:00' };
        if (b.dataset.field === 'time') it.due = { ...(it.due || { d: 0 }), t: v };
        if (b.dataset.field === 'remind') it.remind = v || null;
        if (b.dataset.field === 'repeat') it.repeat = v || null;
        break;
      }
      case 'delete': { const it = findItem(+b.dataset.id); const owner = listOf(it); const idx = owner.items.indexOf(it); owner.items.splice(idx, 1); state.sel = null; state.psheet = null; render(); toast(`Deleted "${it.t}"`, () => owner.items.splice(idx, 0, it)); return; }
      case 'color': l.color = +b.dataset.c; state.pop = null; break;
      case 'onscreen': D.lists.forEach((x) => { if (x !== l) x.onScreen = false; }); l.onScreen = !l.onScreen; break;
      case 'pinned': l.pinned = !l.pinned; state.pop = null; break;
      case 'share': state.pop = null; state.psheet = null; render(); toast(b.dataset.as === 'Image' ? `Sharing ${l.name} as an image…` : `Copied ${l.name} as ${b.dataset.as}`); return;
      case 'sharemenu': openPop('share', b); return;
      case 'more': openPop('more', b); return;
      case 'colormenu': if (phone()) { state.psheet = 'more'; break; } openPop('color', b); return;
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
      case 'pref': { const p = settingsScreen.p; p[b.dataset.key] = !p[b.dataset.key]; break; }
      case 'seg': { if (b.dataset.key === 'theme') { state.theme = b.dataset.val; applyTheme(); } else settingsScreen.p[b.dataset.key] = b.dataset.val; break; }
      case 'psheet': state.psheet = b.dataset.sheet; break;
      case 'closesheet': state.psheet = null; state.sel = null; break;
      case 'pmenu': state.pmenu = !state.pmenu; break;
      default: return;
    }
    render();
  }

  document.addEventListener('click', (e) => {
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
    if (t.matches('[data-range="opacity"]')) { state.floatOpacity = +t.value; const p = app.querySelector('.preview .pbar'); p.style.opacity = state.floatOpacity / 100; t.nextElementSibling.textContent = state.floatOpacity + '%'; }
  });
  document.addEventListener('submit', (e) => {
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
    if (e.key === 'Escape') { if (state.pop) { state.pop = null; renderPop(); return; } if (state.psheet || state.sel) { state.psheet = null; state.sel = null; render(); } return; }
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
