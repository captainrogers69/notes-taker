// 05 · Widgets and share (throwaway prototype).
// iOS home: a chosen list (tickable, iOS 17+) and Next up. iOS lock screen: the next reminder.
// Android home: the list widget, the fallback when the overlay permission is denied. Share to Weave from another app.
(() => {
  const D = WeaveData, I = WeaveIcons, { esc } = D;
  const hash = new URLSearchParams(location.hash.slice(1));
  const st = { scr: hash.get('scr') || 'ios-home', qa: false, toast: '', share: hash.get('step') || 'page', split: false, target: 1 };
  const phoneEl = document.getElementById('phone');
  const cv = (l) => `--c:${D.color(l)};--ci:${D.ink(l)}`;
  const cur = () => D.lists.find((l) => l.id === st.target);
  const SAY = {
    'ios-home': 'A chosen list you can tick from the home screen, and Next up across every list. + opens the add field straight away.',
    'ios-lock': 'The lock screen shows the next reminder and how many are left today. Lock-screen widgets are tinted by iOS.',
    'android-home': 'The Android list widget: tick, scroll, + to add. It is also the fallback when "display over other apps" is denied.',
    share: 'Select text in any app, Share, Weave. One field, the list as a chip; several lines can become several tasks.',
  };
  // Rows a widget shows: overdue first, then by time, then untimed; done rows stay struck until the widget refreshes.
  function rows(l, n) {
    const open = D.open(l), timed = open.filter((i) => i.due && i.due.t).sort((a, b) => a.due.d - b.due.d || D.toMin(a.due.t) - D.toMin(b.due.t));
    return [...timed, ...open.filter((i) => !(i.due && i.due.t))].slice(0, n);
  }
  const li = (it) => `<li data-id="${it.id}"><button class="check" data-a="tick" data-id="${it.id}" aria-label="Check ${esc(it.t)}">${I.tick}</button><span class="t">${esc(it.t)}</span>${it.due && it.due.t ? (D.isOverdue(it) ? `<span class="when late">${D.lateWhen(D.dueLabel(it.due), I.alert)}</span>` : `<span class="when">${D.dueLabel(it.due)}</span>`) : ''}</li>`;
  function listWidget(l, n, cls) {
    const r = rows(l, n), more = D.open(l).length - r.length;
    return `<section class="w paper ${cls}" style="${cv(l)}" aria-label="Weave widget: ${esc(l.name)}">
      <div class="w-head"><span class="dot"></span><span class="name">${esc(l.name)}</span><span class="left num">${D.leftLabel(l)}</span><button class="wadd" data-a="add" aria-label="Add a task to ${esc(l.name)}">${I.plus}</button></div>
      ${r.length ? `<ul>${r.map(li).join('')}</ul>${more > 0 && cls === 'w-and' ? `<div class="more num">+${more} more in Weave</div>` : ''}` : '<p class="more">All done.</p>'}</section>`; // the medium widget's header count already says how many
  }
  function nextWidget() {
    const all = D.lists.flatMap((l) => D.open(l).filter((i) => i.due && i.due.t && i.due.d === 0).map((it) => ({ it, l })));
    const late = all.filter((x) => D.isOverdue(x.it)).length;
    const nx = all.filter((x) => !D.isOverdue(x.it)).sort((a, b) => D.toMin(a.it.due.t) - D.toMin(b.it.due.t))[0];
    return `<section class="w w-sm" aria-label="Weave widget: next up">
      <div class="k">${I.mark} Next up</div>
      ${nx ? `<div class="big">${nx.it.due.t}</div><div class="what">${esc(nx.it.t)}</div><div class="src" style="${cv(nx.l)}"><span class="dot"></span>${esc(nx.l.name)}${late ? ` · <span class="late">${late} overdue</span>` : ''}</div>` : '<div class="big">—</div><div class="what">Nothing else today</div>'}</section>`;
  }
  const apps = (n) => Array.from({ length: n }, () => '<div class="app"><i></i></div>').join('');
  function iosHome() {
    return `<div class="pstat"><span>16:20</span><span>5G</span></div>
      <div class="home"><div class="span4">${listWidget(cur(), 3, 'w-med')}<div class="wlabel">Weave</div></div>
        <div class="span2">${nextWidget()}<div class="wlabel">Weave</div></div><div class="span2" style="display:grid;grid-template-columns:repeat(2,64px);justify-content:space-between;gap:22px 0">${apps(4)}</div>
        ${apps(8)}</div>${quickAdd()}`;
  }
  function iosLock() {
    const all = D.lists.flatMap((l) => D.open(l).map((it) => ({ it, l })));
    const rem = all.map((x) => ({ ...x, at: D.remindAt(x.it) })).filter((x) => x.at != null && x.at > D.NOW.min).sort((a, b) => a.at - b.at)[0];
    const left = D.today().filter((x) => !x.it.d).length;
    return `<div class="pstat"><span></span><span>5G</span></div>
      <div class="lock-inline">${I.bell}<span class="num">${rem ? `${D.fmtClock(rem.at)} ${esc(rem.it.t)}` : 'No more reminders today'}</span></div>
      <div class="lock-time">16:20</div>
      <div class="lock-row">
        <div class="lw lw-rect" aria-label="Weave: next reminder"><div class="k">${I.bell} Next reminder</div><b class="num">${rem ? D.fmtClock(rem.at) : '—'}</b><b>${rem ? esc(rem.it.t) : 'Nothing else today'}</b></div>
        <div class="lw lw-circ" aria-label="Weave: ${left} left today"><div><b class="num">${left}</b>left today</div></div>
      </div>`;
  }
  function androidHome() {
    return `<div class="pstat"><span class="num">16:20</span><span>5G 82%</span></div>
      <div class="home">${apps(4)}<div class="span4">${listWidget(cur(), 6, 'w-and')}</div>${apps(8)}</div>${quickAdd()}`;
  }
  // The widget's + opens Weave straight on the add field, keyboard up (F6.2).
  function quickAdd() {
    if (!st.qa) return st.toast ? `<div class="toast" role="status">${esc(st.toast)}</div>` : '';
    const l = cur();
    return `<div class="qa-scrim" data-a="closeqa"></div><form class="qa" data-f="qa" role="dialog" aria-label="Add a task"><div class="handle"></div><h2>Add to Weave</h2>
      <div class="field"><input name="t" placeholder="Add a task…" aria-label="Add a task to ${esc(l.name)}" autocomplete="off"><button type="button" class="lchip" data-a="cycle" style="${cv(l)}" aria-label="List: ${esc(l.name)}. Change list"><span class="dot"></span>${esc(l.name)}</button></div>
      <div class="parse" aria-live="polite">Times work too: 6pm, tomorrow, in 2 h</div></form><div class="kb" aria-hidden="true">Keyboard</div>`;
  }
  // ---------- Share to Weave ----------
  const SHARED = '500 g flour\n10 g salt\n7 g yeast';
  function share() {
    const page = `<div class="web"><div class="url">recipes.example.org/weekday-bread</div><h3>A weekday loaf</h3><p>You need very little.</p><p><span class="sel">500 g flour<br>10 g salt<br>7 g yeast</span></p><p>Mix, rest an hour, shape, bake at 230°.</p></div>`;
    if (st.share === 'page') return `<div class="pstat" style="color:#111"><span>16:20</span><span>5G</span></div>${page}
      <div class="os-sheet" role="dialog" aria-label="Share"><div class="peek"><div><b>3 lines selected</b>recipes.example.org</div></div>
        <div class="apps"><button class="sapp" data-a="toweave"><i>${I.mark}</i>Weave</button><button class="sapp"><i></i>Message</button><button class="sapp"><i></i>Mail</button><button class="sapp"><i></i>More</button></div>
        <div class="rowb">Copy</div></div>`;
    if (st.share === 'done') return `<div class="pstat" style="color:#111"><span>16:20</span><span>5G</span></div>${page}<div class="toast" role="status">${esc(st.toast)}</div>`;
    const l = cur(), lines = SHARED.split('\n').length;
    return `<div class="pstat" style="color:#111"><span>16:20</span><span>5G</span></div>${page}<div class="qa-scrim"></div>
      <form class="ext" data-f="share" role="dialog" aria-labelledby="ext-t">
        <div class="top"><button type="button" class="tbtn" data-a="cancelshare">Cancel</button><h2 id="ext-t">Add to Weave</h2><button class="tbtn add">Add</button></div>
        <textarea name="t" aria-label="Task text">${esc(SHARED)}</textarea>
        <div class="link">From recipes.example.org/weekday-bread</div>
        ${lines > 1 ? `<div class="opts" role="group" aria-label="How to add"><button type="button" data-a="split" data-v="0" aria-pressed="${!st.split}">One task</button><button type="button" data-a="split" data-v="1" aria-pressed="${st.split}">${lines} tasks, one per line</button></div>` : ''}
        <div class="bottom"><span class="muted" style="color:var(--muted);font-size:13px">Add to</span><button type="button" class="lchip" data-a="cycle" style="${cv(l)}" aria-label="List: ${esc(l.name)}. Change list"><span class="dot"></span>${esc(l.name)}</button></div>
      </form>`;
  }

  function render() {
    const andr = st.scr === 'android-home';
    phoneEl.className = 'phone' + (andr ? ' android' : '');
    phoneEl.innerHTML = { 'ios-home': iosHome, 'ios-lock': iosLock, 'android-home': androidHome, share }[st.scr]();
    document.getElementById('say').textContent = SAY[st.scr];
    document.querySelectorAll('[data-scr]').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.scr === st.scr)));
    const f = phoneEl.querySelector('.qa input, .ext textarea'); if (f) f.focus({ preventScroll: true });
  }
  let toastT;
  const toast = (m) => { st.toast = m; clearTimeout(toastT); toastT = setTimeout(() => { st.toast = ''; if (st.share === 'done') st.share = 'page'; render(); }, 3000); };
  document.addEventListener('click', (e) => {
    const s = e.target.closest('[data-scr]');
    if (s) { st.scr = s.dataset.scr; st.qa = false; st.share = 'page'; return render(); }
    const b = e.target.closest('[data-a]'); if (!b) return;
    const a = b.dataset.a;
    if (a === 'tick') {
      // Fill, fade, then the widget refreshes without the row (the OS reloads the timeline).
      const it = D.lists.flatMap((l) => l.items).find((i) => i.id === +b.dataset.id);
      const row = b.closest('li'); row.classList.add('is-done');
      setTimeout(() => row.classList.add('is-leaving'), 120);
      setTimeout(() => { it.d = true; render(); }, 260);
    }
    if (a === 'add') { st.qa = true; render(); }
    if (a === 'closeqa') { st.qa = false; render(); }
    if (a === 'cycle') { const i = D.lists.indexOf(cur()); st.target = D.lists[(i + 1) % D.lists.length].id; const keep = phoneEl.querySelector('.qa input, .ext textarea')?.value; render(); const f = phoneEl.querySelector('.qa input, .ext textarea'); if (f && keep != null) f.value = keep; }
    if (a === 'toweave') { st.share = 'ext'; render(); }
    if (a === 'cancelshare') { st.share = 'page'; render(); }
    if (a === 'split') { st.split = b.dataset.v === '1'; const keep = phoneEl.querySelector('.ext textarea').value; render(); phoneEl.querySelector('.ext textarea').value = keep; }
  });
  document.addEventListener('input', (e) => {
    if (!e.target.closest('[data-f="qa"]')) return;
    const p = D.parseQuick(e.target.value);
    phoneEl.querySelector('.qa .parse').textContent = e.target.value.trim() && p.due ? D.parsePreview(p) : 'Times work too: 6pm, tomorrow, in 2 h';
  });
  document.addEventListener('submit', (e) => {
    e.preventDefault();
    const raw = (e.target.elements.t.value || '').trim(); if (!raw) return;
    const l = cur();
    const texts = e.target.matches('[data-f="share"]') && st.split ? raw.split('\n').map((x) => x.trim()).filter(Boolean) : [raw.replace(/\n+/g, ', ')];
    texts.forEach((t) => { const p = D.parseQuick(t); l.items.push({ id: D.id(), type: 'check', t: p.text || t, d: false, indent: 0, due: p.due }); });
    if (e.target.matches('[data-f="qa"]')) { st.qa = false; toast(`Added to ${l.name}`); }
    else { st.share = 'done'; toast(texts.length > 1 ? `Added ${texts.length} tasks to ${l.name}` : `Added to ${l.name}`); }
    render();
  });
  document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && st.qa) { st.qa = false; render(); } });
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
