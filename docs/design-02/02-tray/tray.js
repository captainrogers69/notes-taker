// 02 · Hide to tray. The bar hides into the OS's own place (macOS menu bar, Windows tray,
// Android ongoing notification); the same sheet opens from there. Prototype only.
(() => {
  const { mount, draggable, bindTheme, barMeta, clamp } = WeaveSheet;
  const D = WeaveData, I = WeaveIcons;
  const EDGE = 12, GAP = 8;
  const hash = new URLSearchParams(location.hash.slice(1));
  const st = {
    os: hash.get('os') || 'macos',
    hidden: hash.get('hidden') === '1',
    paused: null,          // "17:20" while reminders are paused
    from: 'bar',           // what opened the sheet
    replying: false,
    sent: '',
  };
  const bar = document.getElementById('minibar');
  const trays = { macos: document.getElementById('tray-macos'), windows: document.getElementById('tray-windows') };
  document.getElementById('grip').innerHTML = I.grip;
  document.getElementById('pmark').innerHTML = I.markMono;

  let pos = { x: Math.round(innerWidth / 2 - 120), y: 96 };
  let origin = pos;
  function applyPos() {
    pos.x = clamp(pos.x, EDGE, innerWidth - bar.offsetWidth - EDGE);
    pos.y = clamp(pos.y, 40, innerHeight - bar.offsetHeight - 60);
    bar.style.left = pos.x + 'px';
    bar.style.top = pos.y + 'px';
  }

  const pauseLabel = () => (st.paused ? `Paused till ${st.paused} · Resume` : 'Pause reminders 1 h');

  const sheet = mount({
    trigger: bar,
    ignore: Object.values(trays),
    hide: { get label() { return st.os === 'windows' ? 'Hide to tray' : st.os === 'android' ? 'Hide to notification' : 'Hide to menu bar'; }, run: hideBar },
    footer: () => (st.from === 'tray' ? `
      ${st.hidden ? `<button class="fbtn" data-act="show">${I.show} Show bar</button>` : ''}
      <button class="fbtn" data-act="pause">${I.pause} ${pauseLabel()}</button>` : `
      <span class="sync">${I.cloud} Synced · ${D.devices.length} devices</span><span class="grow"></span><kbd>⌥ Space</kbd>`),
    onAction(act) {
      if (act === 'show') { sheet.close(); showBar(); }
      if (act === 'pause') { togglePause(); sheet.render(); }
    },
    place(win) {
      const h = Math.min(win.scrollHeight, 460), w = win.offsetWidth;
      if (st.from === 'tray') {
        const r = trays[st.os].getBoundingClientRect();
        if (st.os === 'macos') { // drops down under the menu bar item
          win.style.left = clamp(r.right - w, EDGE, innerWidth - w - EDGE) + 'px';
          win.style.top = r.bottom + 6 + 'px';
          win.style.setProperty('--slide-y', '-6px');
          win.style.setProperty('--origin', 'right top');
        } else { // rises above the taskbar, right-aligned
          win.style.left = innerWidth - w - EDGE + 'px';
          win.style.top = r.top - 10 - h + 'px';
          win.style.setProperty('--slide-y', '6px');
          win.style.setProperty('--origin', 'right bottom');
        }
        return;
      }
      const r = bar.getBoundingClientRect();
      const below = r.bottom + GAP + h <= innerHeight - EDGE;
      const x = clamp(r.left, EDGE, innerWidth - w - EDGE);
      win.style.left = x + 'px';
      win.style.top = (below ? r.bottom + GAP : Math.max(EDGE, r.top - GAP - h)) + 'px';
      win.style.setProperty('--slide-y', below ? '-6px' : '6px');
      win.style.setProperty('--origin', `${r.left + 24 - x}px ${below ? 'top' : 'bottom'}`);
    },
    onRender(l) {
      bar.style.setProperty('--accent', D.color(l));
      document.getElementById('dot').style.setProperty('--ci', D.ink(l));
      document.getElementById('name').textContent = l.name;
      document.getElementById('meta').innerHTML = barMeta(l);
      renderTrays(l);
      renderShade(l);
      if (!st.hidden) applyPos();
    },
  });

  function renderTrays(l) {
    const n = D.open(l).length;
    Object.values(trays).forEach((t) => {
      t.innerHTML = `${I.markMono}<span>${n || ''}</span>`;
      t.classList.toggle('paused', !!st.paused);
      t.setAttribute('aria-label', `Weave, ${l.name}, ${D.leftLabel(l)}${st.paused ? ', reminders paused' : ''}`);
    });
  }

  function togglePause() {
    st.paused = st.paused ? null : D.fmtClock(D.NOW.min + 60);
    sheet.render();
  }

  // ---------- Hide and show the bar ----------
  function hideBar() {
    const t = trays[st.os];
    if (st.os === 'android') { st.hidden = true; sheet.render(); return; }
    const r = t.getBoundingClientRect();
    bar.classList.add('flying');
    bar.style.left = r.left + 'px';
    bar.style.top = r.top + 'px';
    setTimeout(() => {
      bar.classList.remove('flying'); bar.classList.add('gone');
      st.hidden = true;
      t.classList.add('pop'); setTimeout(() => t.classList.remove('pop'), 400);
      steps();
    }, 400);
  }
  function showBar() {
    st.hidden = false;
    if (st.os !== 'android') {
      const r = trays[st.os].getBoundingClientRect();
      bar.classList.remove('gone');
      bar.style.left = r.left + 'px'; bar.style.top = r.top + 'px';
      bar.classList.add('flying');
      requestAnimationFrame(() => requestAnimationFrame(() => { bar.classList.remove('flying'); applyPos(); }));
    }
    sheet.render();
    steps();
  }

  // ---------- Android: quick-settings tile + ongoing notification (only while hidden) ----------
  function renderShade(l) {
    const shade = document.getElementById('shade');
    const late = D.open(l).filter(D.isOverdue);
    const next = D.open(l).filter((i) => i.due && i.due.t).sort((a, b) => D.toMin(a.due.t) - D.toMin(b.due.t)).slice(0, 2);
    const sub = late.length ? `${D.leftLabel(l)} · <span class="late">${late.length} overdue</span>` : D.leftLabel(l);
    shade.innerHTML = `
      <div class="qs">
        <button class="tile">Wi-Fi</button><button class="tile">Bluetooth</button><button class="tile">Torch</button>
        <button class="tile ${st.hidden ? '' : 'on'}" data-a="tile" aria-pressed="${!st.hidden}">Weave bar</button>
      </div>
      ${st.hidden ? `
      <article class="notif" style="--accent:${D.color(l)};--accent-ink:${D.ink(l)}">
        <div class="top">${I.mark} Weave · ${st.paused ? `reminders paused till ${st.paused}` : 'now'}</div>
        <h2><span class="dot" style="--c:${D.color(l)};--ci:${D.ink(l)}"></span>${D.esc(l.name)}</h2>
        <div class="sub">${sub}</div>
        <ul>${next.map((it) => `
          <li class="${it.d ? 'is-done' : ''}">
            <button class="check" data-a="tick" data-id="${it.id}" aria-label="Check ${D.esc(it.t)}">${I.tick}</button>
            <span class="t">${D.esc(it.t)}</span>
            ${D.isOverdue(it) ? `<span class="when late">${D.lateWhen(it.due.t, I.alert)}</span>` : `<span class="when">${it.due.t}</span>`}
          </li>`).join('')}</ul>
        <div class="acts">
          <button data-a="reply">Add task</button>
          <button data-a="show">Show bar</button>
          <button data-a="pause">${st.paused ? 'Resume' : 'Pause 1 h'}</button>
        </div>
        <form class="reply ${st.replying ? 'on' : ''}" data-a="send"><input name="t" placeholder="Add to ${D.esc(l.name)}…" aria-label="Add a task to ${D.esc(l.name)}" autocomplete="off"><button>Add</button></form>
        ${st.sent ? `<p class="sentnote">Added "${D.esc(st.sent)}"</p>` : ''}
      </article>` : `<p class="empty-shade">The bar is on screen, so Weave shows no notification. Turn the tile off, or tap ⌄ in the sheet, to hide it here.</p>`}`;
  }
  document.getElementById('shade').addEventListener('click', (e) => {
    const b = e.target.closest('[data-a]');
    if (!b || b.tagName === 'FORM') return;
    const a = b.dataset.a;
    const l = sheet.current();
    if (a === 'tile') { st.hidden = !st.hidden; st.replying = false; sheet.render(); steps(); }
    if (a === 'show') { st.hidden = false; sheet.render(); steps(); }
    if (a === 'pause') togglePause();
    if (a === 'reply') { st.replying = true; renderShade(l); document.querySelector('.reply input').focus(); }
    if (a === 'tick') {
      const it = l.items.find((i) => i.id === +b.dataset.id);
      b.closest('li').classList.add('is-done');
      setTimeout(() => { it.d = true; sheet.render(); }, 280);
    }
  });
  document.getElementById('shade').addEventListener('submit', (e) => {
    e.preventDefault();
    const raw = e.target.elements.t.value.trim();
    if (!raw) return;
    const p = D.parseQuick(raw);
    sheet.current().items.push({ id: D.id(), type: 'check', t: p.text || raw, d: false, indent: 0, due: p.due });
    st.sent = p.text || raw; st.replying = false;
    sheet.render();
  });

  // ---------- Tray clicks, OS switch, steps ----------
  Object.values(trays).forEach((t) => t.addEventListener('click', () => {
    const wasTray = st.from === 'tray';
    st.from = 'tray';
    if (sheet.isOpen() && wasTray) return sheet.close();
    sheet.close(); sheet.open();
    t.classList.add('is-open');
  }));
  bar.addEventListener('pointerdown', () => { st.from = 'bar'; });
  draggable(bar, {
    onStart(phase) { if (phase === 'down') origin = { ...pos }; else sheet.close(); },
    onMove(dx, dy) { pos = { x: origin.x + dx, y: origin.y + dy }; applyPos(); },
    onTap: () => { st.from = 'bar'; sheet.toggle(); },
  });
  // Keyboard alternative to dragging (WCAG 2.5.7): arrow keys move the focused bar, Shift for bigger steps.
  bar.addEventListener('keydown', (e) => {
    const step = e.shiftKey ? 64 : 16;
    const d = { ArrowLeft: [-step, 0], ArrowRight: [step, 0], ArrowUp: [0, -step], ArrowDown: [0, step] }[e.key];
    if (!d) return;
    e.preventDefault(); sheet.close();
    pos = { x: pos.x + d[0], y: pos.y + d[1] }; applyPos();
  });
  new MutationObserver(() => { if (!sheet.isOpen()) Object.values(trays).forEach((t) => t.classList.remove('is-open')); })
    .observe(sheet.win, { attributes: true, attributeFilter: ['class'] });

  const STEPS = {
    macos: ['Click ⌄ in the sheet (or ⌘H): the bar flies into the menu bar as the W and its count.', 'Click the W: the same sheet drops down, with Show bar and Pause reminders at the bottom.', 'Pause dims the W until it resumes on its own after an hour.'],
    windows: ['Click ⌄ in the sheet (or Ctrl+H): the bar flies into the tray.', 'Click the W in the tray: the sheet rises above the taskbar, right-aligned.', 'Show bar puts it back where you left it.'],
    android: ['Weave shows a notification only while the bar is hidden. It lists the next two tasks with their times.', 'Tick from the notification, or Add task to type straight into it ("milk tomorrow 9am" works).', 'The Weave bar tile in quick settings shows or hides the bar.'],
  };
  function steps() { document.getElementById('steps').innerHTML = STEPS[st.os].map((s) => `<li>${s}</li>`).join(''); }

  function setOS(os) {
    st.os = os;
    document.body.className = 'os-' + os;
    document.querySelectorAll('[data-os]').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.os === os)));
    sheet.close();
    if (os !== 'android') bar.classList.toggle('gone', st.hidden);
    steps();
    sheet.render();
  }
  document.querySelectorAll('[data-os]').forEach((b) => b.addEventListener('click', () => setOS(b.dataset.os)));

  bindTheme();
  setOS(st.os);
  applyPos();
  if (hash.get('open') === 'tray' && st.os !== 'android') trays[st.os].click();
})();
