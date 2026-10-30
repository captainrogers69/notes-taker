// Shared Weave sheet: the window every trigger opens (throwaway prototype, not app code).
// A design page supplies the trigger element and where to place the sheet;
// this file owns the sheet content, open/close, keyboard, and drag-vs-tap.
(function () {
  'use strict';

  const COLORS = ['#F5C84C', '#6AA6F8', '#5DC48A', '#EE7FA8', '#A88BEB', '#F29A5B'];
  const BACK = '<svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M10 3.5 5.5 8l4.5 4.5"/></svg>';
  const TAP_SLOP = 5;

  const state = {
    view: 'note',
    currentId: 1,
    showDone: false,
    newItem: null,
    lists: [
      { id: 1, name: 'Today', color: 0, items: [
        { id: 11, t: 'Reply to design review', d: false },
        { id: 12, t: 'Buy milk', d: false },
        { id: 13, t: 'Book dentist', d: true },
      ] },
      { id: 2, name: 'Weave', color: 1, items: [
        { id: 21, t: 'Pick the floating design', d: false },
        { id: 22, t: 'Finish architecture playbook', d: true },
      ] },
      { id: 3, name: 'Groceries', color: 2, items: [
        { id: 31, t: 'Eggs', d: false },
        { id: 32, t: 'Coffee beans', d: false },
      ] },
    ],
  };

  const esc = (s) => s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
  const current = () => state.lists.find((p) => p.id === state.currentId);
  const openItems = (p) => p.items.filter((i) => !i.d);
  const color = (p) => COLORS[p.color % COLORS.length];

  const itemRow = (it) => `
    <li class="item ${it.d ? 'is-done' : ''} ${it.id === state.newItem ? 'is-new' : ''}">
      <button class="check" data-act="tick" data-id="${it.id}" aria-label="${it.d ? 'Uncheck' : 'Check'} ${esc(it.t)}"></button>
      <span class="text">${esc(it.t)}</span>
    </li>`;

  function noteHtml() {
    const p = current();
    const open = openItems(p).slice().reverse(); // newest first, right under the input
    const done = p.items.filter((i) => i.d);
    return `
      <header>
        <button class="icon" data-act="lists" aria-label="Switch list" title="Lists">${BACK}</button>
        <button class="pname" data-act="lists" title="Switch list">
          <span class="dot"></span><span class="label">${esc(p.name)}</span><span class="caret">▾</span>
        </button>
        <span class="count">${open.length ? open.length + ' left' : 'All done'}</span>
      </header>
      <form class="add" data-form="item">
        <span class="plus">+</span>
        <input name="t" autocomplete="off" placeholder="Add a task…" aria-label="Add a task to ${esc(p.name)}">
        <kbd>↵</kbd>
      </form>
      <div class="scroll">
        <ul>${open.map(itemRow).join('')}</ul>
        ${!p.items.length ? '<p class="empty">Nothing here yet.<br>Type above and press Enter.</p>' : ''}
        ${done.length ? `
          <button class="done-toggle" data-act="done" aria-expanded="${state.showDone}">
            ${state.showDone ? '▾' : '▸'} Done · ${done.length}
          </button>
          ${state.showDone ? `<ul>${done.map(itemRow).join('')}</ul>` : ''}` : ''}
      </div>`;
  }

  function listsHtml() {
    return `
      <header>
        <button class="icon" data-act="note" aria-label="Back to ${esc(current().name)}">${BACK}</button>
        <span class="title">Lists</span>
      </header>
      <div class="scroll">
        <ul>${state.lists.map((p) => `
          <li>
            <button class="row ${p.id === state.currentId ? 'is-current' : ''}" data-act="open" data-id="${p.id}">
              <span class="dot" style="--c:${color(p)}"></span>
              <span class="name">${esc(p.name)}</span>
              <span class="n">${openItems(p).length || ''}</span>
              <span class="tick">${p.id === state.currentId ? '✓' : ''}</span>
            </button>
          </li>`).join('')}
        </ul>
      </div>
      <form class="add" data-form="list">
        <span class="plus">+</span>
        <input name="t" autocomplete="off" placeholder="New list…" aria-label="New list name">
        <kbd>↵</kbd>
      </form>
      <div class="hint">Enter creates it and opens it.</div>`;
  }

  // Wires a trigger to the sheet.
  //   place(win)                   positions the sheet next to the trigger
  //   onRender(list, left, c)   lets the trigger show name / count / color
  function mount({ trigger, place, onRender }) {
    const win = document.createElement('div');
    win.className = 'win';
    win.setAttribute('role', 'dialog');
    win.setAttribute('aria-label', 'Weave');
    win.innerHTML = '<div class="views"><section class="view"></section><section class="view" inert></section></div>';
    document.body.appendChild(win);
    const [noteView, projView] = win.querySelectorAll('.view');
    let isOpen = false;

    function render() {
      const p = current();
      win.style.setProperty('--accent', color(p));
      noteView.innerHTML = noteHtml();
      projView.innerHTML = listsHtml();
      const inLists = state.view === 'lists';
      win.classList.toggle('show-lists', inLists);
      noteView.inert = inLists;
      projView.inert = !inLists;
      state.newItem = null;
      if (onRender) onRender(p, openItems(p).length, color(p));
    }

    const focusInput = () => {
      const input = (state.view === 'note' ? noteView : projView).querySelector('input');
      // preventScroll: the hidden view sits off to the side; don't let focus scroll it in.
      if (input) input.focus({ preventScroll: true });
    };
    const go = (view) => { state.view = view; render(); focusInput(); };

    win.addEventListener('click', (e) => {
      const b = e.target.closest('[data-act]');
      if (!b) return;
      const act = b.dataset.act;
      if (act === 'lists') return go('lists');
      if (act === 'note') return go('note');
      if (act === 'open') { state.currentId = +b.dataset.id; state.showDone = false; return go('note'); }
      if (act === 'done') { state.showDone = !state.showDone; render(); return focusInput(); }
      if (act === 'tick') {
        const it = current().items.find((i) => i.id === +b.dataset.id);
        if (it.d) { it.d = false; render(); return focusInput(); }
        // Show the tick for a beat before the item moves into "Done".
        b.closest('.item').classList.add('is-ticking');
        setTimeout(() => { it.d = true; render(); focusInput(); }, 280);
      }
    });

    win.addEventListener('submit', (e) => {
      e.preventDefault();
      const v = e.target.elements.t.value.trim();
      if (!v) return;
      const id = Date.now();
      if (e.target.dataset.form === 'item') {
        current().items.push({ id, t: v, d: false });
        state.newItem = id;
      } else {
        state.lists.push({ id, name: v, color: state.lists.length, items: [] });
        state.currentId = id;
        state.view = 'note';
      }
      render();
      focusInput();
    });

    win.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') return setOpen(false);
      if (e.key === 'Backspace' && e.target.tagName === 'INPUT' && e.target.value === '') {
        e.preventDefault();
        go(state.view === 'note' ? 'lists' : 'note');
      }
    });

    function setOpen(v) {
      if (v === isOpen) return;
      isOpen = v;
      if (isOpen) { state.view = 'note'; render(); place(win); }
      win.classList.toggle('is-open', isOpen);
      trigger.classList.toggle('is-open', isOpen);
      trigger.setAttribute('aria-expanded', String(isOpen));
      if (isOpen) setTimeout(focusInput, 60);
      else if (win.contains(document.activeElement)) document.activeElement.blur();
      trigger.dispatchEvent(new CustomEvent('weave:toggle', { detail: isOpen }));
    }

    // pointerdown, not click: re-renders can detach the click target.
    document.addEventListener('pointerdown', (e) => {
      if (isOpen && !win.contains(e.target) && !trigger.contains(e.target) && !e.target.closest('.caption')) setOpen(false);
    });
    document.addEventListener('keydown', (e) => {
      if (e.altKey && e.code === 'Space') { e.preventDefault(); setOpen(!isOpen); }
    });
    trigger.addEventListener('keydown', (e) => {
      if (e.altKey) return; // ⌥Space handled above
      if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); setOpen(!isOpen); }
    });

    render();
    return {
      open: () => setOpen(true),
      close: () => setOpen(false),
      toggle: () => setOpen(!isOpen),
      isOpen: () => isOpen,
      reposition: () => { if (isOpen) place(win); },
    };
  }

  // Tap vs drag on one handle: movement under TAP_SLOP px counts as a tap.
  function draggable(handle, { onStart, onMove, onDrop, onTap }) {
    let start = null;
    let moved = false;
    handle.addEventListener('pointerdown', (e) => {
      if (e.button !== 0) return;
      start = { x: e.clientX, y: e.clientY };
      moved = false;
      handle.setPointerCapture(e.pointerId);
      if (onStart) onStart('down');
    });
    handle.addEventListener('pointermove', (e) => {
      if (!start) return;
      const dx = e.clientX - start.x;
      const dy = e.clientY - start.y;
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

  function bindThemeButtons() {
    const buttons = document.querySelectorAll('[data-theme]');
    buttons.forEach((b) => b.addEventListener('click', () => {
      document.documentElement.className = b.dataset.theme;
      buttons.forEach((x) => x.setAttribute('aria-pressed', String(x === b)));
    }));
    document.documentElement.className = 't-dark';
  }

  window.WeaveSheet = { mount, draggable, bindThemeButtons, clamp };
})();
