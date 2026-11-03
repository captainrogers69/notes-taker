// Weave design-02 — the sheet every trigger opens (mini bar, menu bar, tray). Throwaway prototype.
// Needs data.js and icons.js first.
(function () {
  'use strict';
  const D = window.WeaveData, I = window.WeaveIcons;
  const { esc } = D;
  const MOD = /Mac|iPhone|iPad/.test(navigator.platform) ? '⌘' : 'Ctrl+';
  const TAP_SLOP = 5;

  const state = { cur: 1, showDone: false, newItem: null, menu: false };
  const current = () => D.lists.find((l) => l.id === state.cur);

  // Overdue first, then by time, then untimed (newest first) — so the sheet reads as "what's next".
  function ordered(l) {
    const o = D.open(l);
    const timed = o.filter((i) => i.due && i.due.t).sort((a, b) => a.due.d - b.due.d || D.toMin(a.due.t) - D.toMin(b.due.t));
    const untimed = o.filter((i) => !(i.due && i.due.t)).reverse();
    return [...timed, ...untimed];
  }

  // The finding line under the list name: overdue beats next-up.
  function subline(l) {
    const left = D.leftLabel(l);
    const late = D.open(l).filter(D.isOverdue);
    if (late.length) return `${left} · <span class="late">${late.length} overdue</span> since ${late[0].due.t}`;
    const n = D.nextUp(l);
    if (n) return `${left} · next ${D.dueLabel(n.due)} ${esc(n.t)}`;
    return left;
  }

  const itemRow = (it) => `
    <li class="item ${it.d ? 'is-done' : ''} ${it.indent ? 'indent' : ''} ${it.id === state.newItem ? 'is-new' : ''}">
      <button class="check" data-act="tick" data-id="${it.id}" aria-label="${it.d ? 'Uncheck' : 'Check'} ${esc(it.t)}">${I.tick}</button>
      <span class="text">${esc(it.t)}</span>
      ${it.due && !it.d ? (D.isOverdue(it) ? `<span class="when late">${D.lateWhen(D.dueLabel(it.due), I.alert)}</span>` : `<span class="when">${D.dueLabel(it.due)}</span>`) : ''}
    </li>`;

  function body(l) {
    const notes = l.items.filter((i) => i.type === 'text');
    const done = D.done(l);
    const open = ordered(l);
    return `
      ${notes.map((n) => `<p class="note">${esc(n.t)}</p>`).join('')}
      <ul>${open.map(itemRow).join('')}</ul>
      ${!open.length && !done.length ? '<p class="empty">Nothing here yet. Type above and press Enter.</p>' : ''}
      ${!open.length && done.length ? '<p class="empty">All done. Ticked items are below.</p>' : ''}
      ${done.length ? `
        <button class="done-row" data-act="done" aria-expanded="${state.showDone}">${I.chevRight} Done · ${done.length}</button>
        ${state.showDone ? `<ul>${done.map(itemRow).join('')}</ul>` : ''}` : ''}`;
  }

  // The day thread in one line (07:00–23:00): the part already lived in ink, this list's tasks due today
  // as marks — filled in the list colour, a red ring when overdue, hollow when done.
  function strip(l) {
    const due = D.checks(l).filter((i) => i.due && i.due.d === 0 && i.due.t);
    if (!due.length) return '';
    const W = 260, S = 7 * 60, E = 23 * 60;
    const x = (m) => 6 + Math.round(((Math.min(E, Math.max(S, m)) - S) / (E - S)) * (W - 12));
    const nx = x(D.NOW.min);
    const marks = due.map((i) => {
      const cx = x(D.toMin(i.due.t));
      if (i.d) return `<circle cx="${cx}" cy="8" r="3.5" fill="var(--surface)" stroke="var(--muted)" stroke-width="1.5"/>`;
      if (D.isOverdue(i)) return `<circle cx="${cx}" cy="8" r="4" fill="var(--surface)" stroke="var(--negative)" stroke-width="2"/>`;
      return `<circle cx="${cx}" cy="8" r="5" fill="var(--accent)" stroke="var(--accent-ink)"/>`;
    }).join('');
    const said = due.map((i) => `${i.due.t} ${esc(i.t)}${i.d ? ' (done)' : D.isOverdue(i) ? ' (overdue)' : ''}`).join(', ');
    return /* taste-skill-ignore: hour labels, not numbering */ `<div class="strip"><span aria-hidden="true">07</span>
      <svg viewBox="0 0 ${W} 16" height="16" preserveAspectRatio="xMidYMid meet" role="img" aria-label="Today on this list: ${said}. Now ${D.NOW.clock}.">
        <line x1="6" x2="${W - 6}" y1="8" y2="8" stroke="var(--control)" stroke-width="2" stroke-linecap="round"/>
        <line x1="6" x2="${nx}" y1="8" y2="8" stroke="var(--text)" stroke-width="2" stroke-linecap="round"/>
        <line x1="${nx}" x2="${nx}" y1="1" y2="15" stroke="var(--text)" stroke-width="1.5"/>${marks}</svg>
      <span aria-hidden="true">23</span></div>`;
  }

  function menuHtml() {
    return D.lists.map((l) => `
      <button class="mrow ${l.id === state.cur ? 'cur' : ''}" data-act="open" data-id="${l.id}" role="menuitemradio" aria-checked="${l.id === state.cur}">
        <span class="dot" style="--c:${D.color(l)};--ci:${D.ink(l)}"></span>
        <span class="name">${esc(l.name)}</span>
        <span class="n">${D.open(l).length || ''}</span>
        <span class="tick">${l.id === state.cur ? I.check : ''}</span>
      </button>`).join('') + `
      <form data-form="list"><input name="t" autocomplete="off" placeholder="New list…" aria-label="New list name"></form>`;
  }

  // mount({ trigger, place, onRender, hide: { label, run }, move: { label, run }, footer(l), onAction(act, el), ignore, container })
  // move: a one-click alternative to dragging the bar (WCAG 2.5.7).
  function mount({ trigger, place, onRender, hide, move, footer, onAction, ignore = [], container = document.body }) {
    const win = document.createElement('div');
    win.className = 'sheet';
    win.setAttribute('role', 'dialog');
    win.setAttribute('aria-label', 'Weave');
    container.appendChild(win);
    let isOpen = false;

    function render() {
      const l = current();
      win.style.setProperty('--accent', D.color(l));
      win.style.setProperty('--accent-ink', D.ink(l));
      const typed = win.querySelector('.add input')?.value || '';
      win.setAttribute('aria-label', `Weave: ${l.name}`);
      win.innerHTML = `
        <div class="top paper">
        <div class="head">
          <button class="switch" data-act="menu" aria-haspopup="menu" aria-expanded="${state.menu}" title="Switch list">
            <span class="dot" style="--ci:var(--accent-ink)"></span><span class="label">${esc(l.name)}</span>${I.chevDown}
          </button>
          <span class="grow"></span>
          ${hide ? `<button class="icon" data-act="hide" aria-label="${hide.label}" title="${hide.label} (${MOD}H)">${I.hide}</button>` : ''}
          <button class="icon" data-act="app" aria-label="Open in Weave" title="Open in Weave (${MOD}O)">${I.expand}</button>
        </div>
        <div class="sub">${subline(l)}</div>
        ${strip(l)}
        <form class="add" data-form="item">
          <label class="field">
            <input name="t" autocomplete="off" placeholder="Add a task…" aria-label="Add a task to ${esc(l.name)}" value="${esc(typed)}">
            <kbd>↵</kbd>
          </label>
          <div class="parse" aria-live="polite">${I.clock}<span></span></div>
        </form>
        </div>
        <div class="scroll">${body(l)}</div>
        <div class="foot">${footer ? footer(l) : `
          <span class="sync">${I.cloud} Synced · ${D.devices.length} devices</span><span class="grow"></span>${move ? `<button class="fbtn" data-act="move" title="Or drag the bar, or use the arrow keys on it">${I.corner} ${move.label}</button>` : '<kbd>⌥ Space</kbd>'}`}</div>
        <div class="menu ${state.menu ? 'on' : ''}" role="menu" aria-label="Lists">${menuHtml()}</div>`;
      state.newItem = null;
      updateParse();
      if (onRender) onRender(l);
    }

    function updateParse() {
      const input = win.querySelector('.add input');
      const box = win.querySelector('.parse');
      const p = D.parseQuick(input.value);
      const label = input.value.trim() ? D.parsePreview(p) : '';
      box.classList.toggle('on', !!label);
      box.querySelector('span').textContent = label;
    }

    const focusInput = () => {
      const sel = state.menu ? '.menu input' : '.add input';
      const el = win.querySelector(sel);
      if (el) el.focus({ preventScroll: true });
    };

    win.addEventListener('input', (e) => { if (e.target.closest('.add')) updateParse(); });

    win.addEventListener('click', (e) => {
      const b = e.target.closest('[data-act]');
      if (!b) { if (state.menu && !e.target.closest('.menu')) { state.menu = false; render(); } return; }
      const act = b.dataset.act;
      if (act === 'app') return openApp();
      if (act === 'hide') { setOpen(false); return hide.run(); }
      if (act === 'move') { move.run(); place(win); return; }
      if (act === 'menu') { state.menu = !state.menu; render(); return focusInput(); }
      if (act === 'open') { state.cur = +b.dataset.id; state.menu = false; state.showDone = false; win.querySelector('.add input').value = ''; render(); return focusInput(); }
      if (act === 'done') { state.showDone = !state.showDone; render(); return; }
      if (act === 'tick') {
        const it = current().items.find((i) => i.id === +b.dataset.id);
        if (it.d) { it.d = false; render(); return; }
        b.closest('.item').classList.add('is-ticking'); // show the tick for a beat, then move it into Done
        setTimeout(() => { it.d = true; render(); }, 280);
        return;
      }
      if (onAction) onAction(act, b);
    });

    win.addEventListener('submit', (e) => {
      e.preventDefault();
      const input = e.target.elements.t;
      const raw = input.value.trim();
      if (!raw) return;
      if (e.target.dataset.form === 'item') {
        const p = D.parseQuick(raw);
        const it = { id: D.id(), type: 'check', t: p.text || raw, d: false, indent: 0, due: p.due, remind: p.timer ? 'Timer' : null, repeat: null };
        current().items.push(it);
        state.newItem = it.id;
        input.value = '';
      } else {
        const l = { id: D.id(), name: raw, color: D.lists.length % 6, items: [] };
        D.lists.push(l);
        state.cur = l.id;
        state.menu = false;
        win.querySelector('.add input').value = '';
      }
      render();
      focusInput();
    });

    function openApp() {
      setOpen(false);
      location.href = '../03-app/index.html#list=' + current().id;
    }

    win.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') { if (state.menu) { state.menu = false; render(); return focusInput(); } return setOpen(false, { keyboard: true }); }
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'h' && hide) { e.preventDefault(); setOpen(false); return hide.run(); }
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'o') { e.preventDefault(); return openApp(); }
      if (e.key === 'Backspace' && e.target.tagName === 'INPUT' && e.target.value === '') { e.preventDefault(); state.menu = !state.menu; render(); focusInput(); }
      if (state.menu && (e.key === 'ArrowDown' || e.key === 'ArrowUp')) {
        const rows = [...win.querySelectorAll('.menu .mrow, .menu input')];
        const i = rows.indexOf(document.activeElement);
        const n = rows[(i + (e.key === 'ArrowDown' ? 1 : -1) + rows.length) % rows.length];
        e.preventDefault(); n.focus();
      }
    });

    // keyboard: opened or closed from a key (⌥Space, Enter, Escape) appears at once; a click animates.
    function setOpen(v, { keyboard = false } = {}) {
      if (v === isOpen) return;
      isOpen = v;
      win.classList.toggle('no-anim', keyboard);
      if (isOpen) { state.menu = false; render(); place(win); }
      win.classList.toggle('is-open', isOpen);
      trigger.classList.toggle('is-open', isOpen);
      trigger.setAttribute('aria-expanded', String(isOpen));
      if (isOpen) setTimeout(focusInput, 60);
      else if (win.contains(document.activeElement)) document.activeElement.blur();
    }

    document.addEventListener('pointerdown', (e) => {
      if (!isOpen || win.contains(e.target) || trigger.contains(e.target) || e.target.closest('.proto')) return;
      if (ignore.some((el) => el.contains(e.target))) return;
      setOpen(false);
    });
    document.addEventListener('keydown', (e) => { if (e.altKey && e.code === 'Space') { e.preventDefault(); setOpen(!isOpen, { keyboard: true }); } });
    trigger.addEventListener('keydown', (e) => { if (!e.altKey && (e.key === 'Enter' || e.key === ' ')) { e.preventDefault(); setOpen(!isOpen, { keyboard: true }); } });

    render();
    return { open: () => setOpen(true), close: () => setOpen(false), toggle: () => setOpen(!isOpen), isOpen: () => isOpen, render, win, current };
  }

  // Tap vs drag on one handle: movement under TAP_SLOP px counts as a tap.
  function draggable(handle, { onStart, onMove, onDrop, onTap }) {
    let start = null, moved = false;
    handle.addEventListener('pointerdown', (e) => {
      if (e.button !== 0) return;
      start = { x: e.clientX, y: e.clientY }; moved = false;
      handle.setPointerCapture(e.pointerId);
      if (onStart) onStart('down');
    });
    handle.addEventListener('pointermove', (e) => {
      if (!start) return;
      const dx = e.clientX - start.x, dy = e.clientY - start.y;
      if (!moved && Math.hypot(dx, dy) < TAP_SLOP) return;
      if (!moved) { moved = true; handle.classList.add('is-dragging'); if (onStart) onStart('drag'); }
      onMove(dx, dy);
    });
    const end = (e) => {
      if (!start) return;
      start = null;
      handle.classList.remove('is-dragging');
      if (moved) { if (onDrop) onDrop(); } else if (e.type === 'pointerup') onTap();
    };
    handle.addEventListener('pointerup', end);
    handle.addEventListener('pointercancel', end);
  }

  // The bar's text: name, count, and the one thing to know (overdue, or the next time).
  function barMeta(l) {
    const late = D.open(l).filter(D.isOverdue).length;
    const n = D.nextUp(l);
    const left = D.open(l).length;
    const head = left ? `<b class="num">${left}</b> left` : 'All done';
    if (late) return `${head} · <span class="late">${late} overdue</span>`;
    if (n && n.due.d === 0) return `${head} · next <b class="num">${n.due.t}</b>`;
    return head;
  }

  // Mode (light / dark) is remembered across prototypes.
  function bindTheme() {
    const btns = document.querySelectorAll('[data-theme]');
    const apply = () => {
      const forced = new URLSearchParams(location.hash.slice(1)).get('mode');
      const mode = forced ? `t-${forced}` : localStorage.getItem('weave2-mode') || 't-light';
      document.documentElement.classList.remove('t-light', 't-dark');
      document.documentElement.classList.add(mode);
      btns.forEach((x) => x.setAttribute('aria-pressed', String(x.dataset.theme === mode)));
    };
    btns.forEach((b) => b.addEventListener('click', () => { localStorage.setItem('weave2-mode', b.dataset.theme); apply(); }));
    apply();
  }

  const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
  window.WeaveSheet = { mount, draggable, bindTheme, barMeta, clamp, state };
})();
