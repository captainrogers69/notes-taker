// 04 · Notifications (throwaway prototype). A reminder rings on this device and on another signed-in device.
// Mark done / Snooze / Open on one clears both (F4.5, F4.6). Notification text is built on the device (E6).
(() => {
  const D = WeaveData, I = WeaveIcons, { esc } = D;
  const hash = new URLSearchParams(location.hash.slice(1));
  const list = D.lists[0];
  const it = list.items.find((i) => i.t === 'Reply to design review');
  const st = { os: hash.get('os') || 'macos', ringing: true, snoozeOpen: false, capture: hash.has('capture'), sent: '', outcome: '' };
  const SNOOZE = [['10 min', 10], ['1 hour', 60], ['Tomorrow', null]];
  const other = () => (st.os === 'android' ? { name: 'MacBook Air', kind: 'macos' } : { name: 'Pixel 8', kind: 'android' });
  const hereName = () => ({ macos: 'This Mac', windows: 'This PC', android: 'This phone (Pixel 8)' }[st.os]);
  const when = () => `${it.due.t} · ${esc(list.name)} · in 15 min`;

  // One notification, drawn in each OS's frame.
  function notif(kind) {
    if (!st.ringing) return '';
    const snz = st.snoozeOpen === kind ? `<div class="snz" role="group" aria-label="Snooze for">${SNOOZE.map(([l]) => `<button data-a="snooze" data-v="${l}">${l}</button>`).join('')}</div>` : '';
    const head = `<div class="n-head">${I.mark}<div class="txt"><div class="n-app"><span>Weave</span><span class="grow"></span><span>now</span></div><div class="n-title">${esc(it.t)}</div><div class="n-body num">${when()}</div></div></div>`;
    if (kind === 'macos') return `<div class="mac-n arrive" role="alert" data-k="macos">${head}
      <div class="mac-acts"><button data-a="done" data-k="macos">Mark done</button><button data-a="snzmenu" data-k="macos" aria-expanded="${st.snoozeOpen === 'macos'}">Snooze</button><button data-a="open">Open</button></div>${snz}</div>`;
    if (kind === 'windows') return `<div class="win-n arrive" role="alert" data-k="windows">${head}
      <div class="win-acts"><button data-a="done" data-k="windows">Mark done</button><button data-a="snzmenu" data-k="windows" aria-expanded="${st.snoozeOpen === 'windows'}">Snooze</button><button data-a="open">Open</button></div>${snz}</div>`;
    return `<div class="and-n arrive" role="alert" data-k="android" style="--accent:${D.color(list)}">${head}
      <div class="and-acts"><button data-a="done" data-k="android">Mark done</button><button data-a="snzmenu" data-k="android" aria-expanded="${st.snoozeOpen === 'android'}">Snooze</button><button data-a="open">Open</button></div>${snz}</div>`;
  }
  // Opt-in, silent, always there (F6.3). Separate from the hidden-bar notification in 02.
  function captureNotif() {
    if (!st.capture) return '';
    const l = D.lists[0];
    return `<div class="and-n quiet" data-k="capture">
      <div class="n-head">${I.mark}<div class="txt"><div class="n-app"><span>Weave</span><span class="grow"></span><span>Quick add</span></div><div class="n-title">Add to Weave</div><div class="n-sub"><span class="dot" style="--c:${D.color(l)};--ci:${D.ink(l)}"></span>Goes to ${esc(l.name)}. Times work: "milk 6pm".</div></div></div>
      <form class="reply" data-f="cap"><input name="t" aria-label="Add a task to ${esc(l.name)}" placeholder="Add a task…" autocomplete="off"><button>Add</button></form>
      <div class="parse" aria-live="polite">${st.sent ? `Added "${esc(st.sent)}"` : ''}</div></div>`;
  }
  function desk(kind) {
    return `<div class="screen desk">${kind === 'macos'
      ? `<div class="menubar"><b>Code</b><span>File</span><span>Edit</span><span class="grow"></span><span class="num">Tue 3 Nov&nbsp;&nbsp;16:45</span></div>`
      : `<div class="taskbar"><span class="num">16:45<br>03-11-2026</span></div>`}${notif(kind)}</div>`;
  }
  function phone(kind) {
    return `<div class="screen phone"><div class="pstat"><span class="num">16:45</span><span>5G 82%</span></div>
      <div class="lock-time num">16:45</div><div class="lock-date">Tuesday 3 November</div>${notif(kind)}${captureNotif()}</div>`;
  }
  function render() {
    document.body.className = 'os-' + st.os;
    const o = other();
    document.getElementById('h-here').textContent = hereName();
    document.getElementById('h-other').textContent = `${o.name}, signed in to the same account`;
    document.getElementById('here').outerHTML = `<div id="here">${st.os === 'android' ? phone('android') : desk(st.os)}</div>`;
    document.getElementById('other').outerHTML = `<div id="other">${o.kind === 'android' ? phone('android') : desk('macos')}</div>`;
    document.querySelectorAll('[data-os]').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.os === st.os)));
    document.querySelector('[data-capture]').setAttribute('aria-pressed', String(st.capture));
  }
  // Acting on either device clears the reminder on both: the one acted on fades at once, the other a moment later (sync).
  function resolve(fromEl, outcome) {
    const here = fromEl.closest('#here') ? 'here' : 'other';
    const there = here === 'here' ? 'other' : 'here';
    const a = document.querySelector(`#${here} [role="alert"]`), b = document.querySelector(`#${there} [role="alert"]`);
    st.snoozeOpen = false;
    if (a) a.classList.add('leaving');
    const actor = here === 'here' ? hereName().replace(/^This/, 'this') : other().name;
    document.getElementById('cap-' + here).textContent = outcome;
    setTimeout(() => { if (b) b.classList.add('leaving'); document.getElementById('cap-' + there).textContent = `Cleared: ${outcome.charAt(0).toLowerCase() + outcome.slice(1)} on ${actor}.`; }, 700);
    setTimeout(() => { st.ringing = false; render(); }, 900);
  }
  document.addEventListener('click', (e) => {
    const b = e.target.closest('[data-a]');
    if (b) {
      const a = b.dataset.a;
      if (a === 'done') { it.d = true; return resolve(b, `Marked done`); }
      if (a === 'snzmenu') { st.snoozeOpen = st.snoozeOpen === b.dataset.k ? false : b.dataset.k; const el = b.closest('[role="alert"]'); el.classList.remove('arrive'); render(); document.querySelectorAll('[role="alert"]').forEach((x) => x.classList.remove('arrive')); const f = document.querySelector('.snz button'); if (f) f.focus(); return; }
      if (a === 'snooze') { const v = SNOOZE.find(([l]) => l === b.dataset.v); return resolve(b, v[1] ? `Snoozed till ${D.fmtClock(16 * 60 + 45 + v[1])}` : 'Snoozed till tomorrow 09:00'); }
      if (a === 'open') { location.href = `../03-app/index.html#os=${st.os}&list=${list.id}`; return; }
    }
    if (e.target.closest('[data-replay]')) { it.d = false; st.ringing = true; st.snoozeOpen = false; document.getElementById('cap-here').textContent = ''; document.getElementById('cap-other').textContent = ''; render(); }
    if (e.target.closest('[data-capture]')) { st.capture = !st.capture; if (st.os !== 'android') st.os = 'android'; render(); }
    const osb = e.target.closest('[data-os]');
    if (osb) { st.os = osb.dataset.os; st.snoozeOpen = false; render(); }
  });
  document.addEventListener('input', (e) => {
    if (!e.target.closest('[data-f="cap"]')) return;
    const p = D.parseQuick(e.target.value);
    e.target.closest('.and-n').querySelector('.parse').textContent = e.target.value.trim() && p.due ? D.parsePreview(p) : '';
  });
  document.addEventListener('submit', (e) => {
    if (!e.target.matches('[data-f="cap"]')) return;
    e.preventDefault();
    const raw = e.target.elements.t.value.trim(); if (!raw) return;
    const p = D.parseQuick(raw);
    D.lists[0].items.push({ id: D.id(), type: 'check', t: p.text || raw, d: false, indent: 0, due: p.due });
    st.sent = (p.text || raw) + (p.due ? ` · ${D.dueLabel(p.due)}` : '');
    render();
  });
  // Mode (light / dark) is shared with the other prototypes.
  const apply = () => {
    const forced = hash.get('mode');
    const mode = forced ? `t-${forced}` : localStorage.getItem('weave2-mode') || 't-light';
    document.documentElement.className = mode;
    document.querySelectorAll('[data-theme]').forEach((x) => x.setAttribute('aria-pressed', String(x.dataset.theme === mode)));
  };
  document.querySelectorAll('[data-theme]').forEach((b) => b.addEventListener('click', () => { localStorage.setItem('weave2-mode', b.dataset.theme); apply(); }));
  apply();
  render();
})();
