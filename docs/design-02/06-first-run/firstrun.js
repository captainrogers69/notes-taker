// 06 · First run (throwaway prototype). Understand Weave in under 2 minutes; ask for each permission
// only when it is about to be used, with Weave's reason first and the OS dialog second.
(() => {
  const D = WeaveData, I = WeaveIcons;
  const hash = new URLSearchParams(location.hash.slice(1));
  const st = { os: hash.get('os') || 'macos', step: hash.get('step') || 'welcome', overlay: false, done: '' };
  const stage = document.getElementById('stage');
  const SAY = {
    welcome: 'One screen: what Weave is, three things to know, one button. No account needed.',
    bar: 'The bar unrolls from its dot, once. Clicking it opens the sheet (the 01 prototype, first-run mode).',
    notify: 'Asked the first time a task gets a time, not at launch: Weave says why, then the OS asks.',
    osnotify: "The OS's own dialog. Weave only shows it after its own one-line reason.",
    overlay: 'Android needs "Display over other apps" for the bar. Weave explains, then opens the setting.',
    settings: "Android's settings page. Turn the switch on, or go back without it.",
    on: 'Allowed: the bar appears over other apps.',
    denied: 'Not allowed: nothing breaks. Weave offers the home widget, and a notification while the bar is off.',
    pinwidget: "Android's own dialog for adding a widget.",
    widget: 'iOS cannot float over other apps, so the home-screen widget is Weave\'s way to stay in view.',
    done: '',
  };
  const mono = (s) => `<span class="kbd">${s}</span>`;
  const welcome = () => {
    const phone = st.os !== 'macos';
    const pts = [
      st.os === 'ios' ? ['Your list on the home screen', 'Tick from the widget; + adds a task.'] : ['A small bar floats above your apps', `${phone ? 'Tap' : 'Click'} it to see your list and tick things off.`],
      ['Type, then Enter', '"call mom 6pm" becomes a task that reminds you at 18:00.'],
      phone ? ['No account needed', 'Sign in later, from Settings, to sync your devices.'] : [`${mono('⌥ Space')} from anywhere`, 'Opens your list, ready to type.'],
    ];
    return `<div class="big-mark">${I.mark}</div><h2>Lists that stay in reach</h2><p class="lede">Weave keeps a short list where you can see it, and reminds you when it matters.</p>
      <ol>${pts.map(([b, s], i) => `<li class="pt"><i>${i + 1}</i><div><b>${b}</b><span>${s}</span></div></li>`).join('')}</ol>
      <div class="acts"><button class="btn primary" data-go="${st.os === 'macos' ? 'bar' : st.os === 'android' ? 'overlay' : 'widget'}">Start</button></div>
      ${phone ? '' : '<p class="fine">No account needed. Sign in later from Settings to sync your devices.</p>'}`;
  };
  const notifyAsk = () => `<h2 style="margin-top:0">Remind you at 18:00?</h2><p class="lede">"Call mom" has a time. Weave needs to send notifications to remind you. You can turn them off in Settings.</p>
    <div class="acts"><button class="btn primary" data-go="osnotify">Continue</button><button class="btn ghost" data-go="done" data-v="Reminders stay in the list; nothing will ring.">Not now</button></div>`;
  const osNotify = () => st.os === 'macos'
    ? `<div class="osalert mac" role="alertdialog"><div class="bd"><b>"Weave" would like to send you notifications</b>Notifications may include alerts, sounds and badges.</div><div class="bt"><button data-go="done" data-v="Reminders stay in the list; nothing will ring.">Don't Allow</button><button data-go="done" data-v="Reminders are on.">Allow</button></div></div>`
    : `<div class="osalert" role="alertdialog"><div class="bd"><b>"Weave" Would Like to Send You Notifications</b>Notifications may include alerts, sounds and icon badges.</div><div class="bt"><button data-go="done" data-v="Reminders stay in the list; nothing will ring.">Don't Allow</button><button data-go="done" data-v="Reminders are on.">Allow</button></div></div>`;
  const homeBg = (inner) => `<div class="home">${Array.from({ length: 12 }, () => '<div class="app"><i></i></div>').join('')}</div>${inner || ''}`;

  function macos() {
    const s = st.step;
    let body = '';
    if (s === 'welcome') body = `<div class="win fr" role="dialog" aria-label="Welcome to Weave">${welcome()}</div>`;
    if (s === 'bar') body = `<a class="mbar" href="../01-mini-bar/index.html#first" style="left:50%;top:72px;transform:translateX(-50%);text-decoration:none" aria-label="Open Weave">${I.grip}<span class="dot" style="width:10px;height:10px;border-radius:50%;background:var(--c);border:1px solid var(--ci)"></span><b style="font-weight:500">My list</b><span class="m">Nothing yet</span></a>
      <div class="win fr" style="top:auto;bottom:40px;transform:translateX(-50%);width:380px;padding:16px 20px"><p class="lede" style="margin:0 0 12px">That's your bar. Drag it anywhere; it fades when you're not using it.</p><div class="acts"><button class="btn" data-go="notify">Next: add a task with a time</button></div></div>`;
    if (s === 'notify') body = `<div class="win fr" role="dialog" aria-label="Allow reminders">${notifyAsk()}</div>`;
    if (s === 'osnotify') body = osNotify();
    if (s === 'done') body = `<div class="win fr"><h2 style="margin-top:0">You're set</h2><p class="lede">${st.done} Press ${mono('⌥ Space')} any time to add something.</p><div class="acts"><a class="btn primary" href="../01-mini-bar/index.html#first" style="text-decoration:none">Open the bar</a></div></div>`;
    return `<div class="desk"><div class="menubar"><b>Finder</b><span>File</span><span class="grow"></span><span class="num">Tue 3 Nov&nbsp;&nbsp;16:20</span></div>${body}</div>`;
  }

  function android() {
    const s = st.step;
    let body = '';
    if (s === 'welcome') body = `<div class="scr fr">${welcome()}</div>`;
    if (s === 'overlay') body = `<div class="scr fr"><h2 style="margin-top:0">Let Weave float over your apps</h2><p class="lede">The bar sits on top of whatever app you're in, so your list is one tap away. Android calls this "Display over other apps". Weave uses it only for the bar.</p>
      <div class="demo-app" aria-hidden="true">${[30, 56, 82, 108, 134, 160].map((t, i) => `<i class="ln" style="top:${t}px;right:${60 + (i % 3) * 40}px"></i>`).join('')}<div class="mbar" style="left:24px;top:76px">${I.grip}<span class="dot" style="width:10px;height:10px;border-radius:50%;background:var(--c);border:1px solid var(--ci)"></span><b style="font-weight:500">My list</b><span class="m">2 left</span></div></div>
      <div class="acts"><button class="btn primary" data-go="settings">Open settings</button><button class="btn ghost" data-go="denied">Not now</button></div></div>`;
    if (s === 'settings') body = `<div class="sys" role="dialog" aria-label="Display over other apps"><div class="bar"><button data-go="${st.overlay ? 'on' : 'denied'}" aria-label="Back">${I.back}</button>Display over other apps</div>
      <div class="appid">${I.mark}Weave</div>
      <div class="sw"><span>Allow display over other apps</span><button role="switch" aria-checked="${st.overlay}" data-sw aria-label="Allow display over other apps"></button></div>
      <p class="note">This permission allows an app to display on top of other apps you're using.</p></div>`;
    if (s === 'on') body = `${homeBg(`<div class="mbar home-bar">${I.grip}<span class="dot" style="width:10px;height:10px;border-radius:50%;background:var(--c);border:1px solid var(--ci)"></span><b style="font-weight:500">My list</b><span class="m">Nothing yet</span></div>`)}
      <div class="scr fr" style="top:auto;height:auto;border-radius:24px 24px 0 0;padding-bottom:32px"><h2 style="margin-top:0">Your bar is on</h2><p class="lede">Drag it anywhere. To hide it, use the Weave bar tile in quick settings.</p><div class="acts"><button class="btn primary" data-go="done" data-v="">Done</button></div></div>`;
    if (s === 'denied') body = `<div class="scr fr"><h2 style="margin-top:0">No problem</h2><p class="lede">Weave works without floating. Keep your list in view another way:</p>
      <div class="widget-pick">${widgetPreview()}</div>
      <div class="ok-row">${I.bell}<span>While the bar is off, a quiet notification shows what's next. Change it in Settings.</span></div>
      <div class="acts"><button class="btn primary" data-go="pinwidget">Add the widget</button><button class="btn ghost" data-go="done" data-v="">Maybe later</button></div>
      <p class="fine">You can turn the bar on any time: Settings → Mini bar.</p></div>`;
    if (s === 'pinwidget') body = `<div class="scr fr" style="opacity:.5"></div><div class="osalert and" role="alertdialog"><div class="bd"><b>Add to home screen?</b><div style="margin:12px 0">${widgetPreview()}</div>Touch and hold to place it.</div><div class="bt"><button data-go="denied">Cancel</button><button data-go="done" data-v="The widget is on your home screen.">Add</button></div></div>`;
    if (s === 'done') body = `<div class="scr fr"><h2 style="margin-top:0">You're set</h2><p class="lede">${st.done || 'Add your first task: tap the bar or the widget\'s +.'}</p><div class="acts"><a class="btn primary" href="../03-app/index.html#os=android" style="text-decoration:none">Open Weave</a></div></div>`;
    return `<div class="phone android"><div class="pstat"><span class="num">16:20</span><span>5G 82%</span></div>${body}</div>`;
  }

  function ios() {
    const s = st.step;
    let body = '';
    if (s === 'welcome') body = `<div class="scr fr">${welcome()}</div>`;
    if (s === 'widget') body = `<div class="scr fr"><h2 style="margin-top:0">Put your list on the home screen</h2><p class="lede">iPhone doesn't let apps float over each other, so Weave lives in a widget you can tick from.</p>
      <div class="widget-pick">${widgetPreview()}</div>
      <ol>${[['Touch and hold', 'an empty spot on your home screen.'], ['Tap Edit, then Add Widget', 'and search for Weave.'], ['Pick a size', 'and choose which list it shows.']].map(([b, t], i) => `<li class="pt"><i>${i + 1}</i><div><b>${b}</b><span>${t}</span></div></li>`).join('')}</ol>
      <div class="acts"><button class="btn primary" data-go="notify">Done</button><button class="btn ghost" data-go="notify">Later</button></div></div>`;
    if (s === 'notify') body = `<div class="scr fr">${notifyAsk()}</div>`;
    if (s === 'osnotify') body = `<div class="scr fr" style="opacity:.5"></div>${osNotify()}`;
    if (s === 'done') body = `<div class="scr fr"><h2 style="margin-top:0">You're set</h2><p class="lede">${st.done} Add from the widget's +, or from Share in any app.</p><div class="acts"><a class="btn primary" href="../03-app/index.html#os=ios" style="text-decoration:none">Open Weave</a></div></div>`;
    return `<div class="phone"><div class="pstat"><span>16:20</span><span>5G</span></div>${body}</div>`;
  }
  // A starter widget: the empty first list, to show what will appear.
  function widgetPreview() {
    return `<div class="w paper w-med" style="--c:var(--n0);--ci:var(--n0-ink);width:300px;height:auto" aria-label="Weave widget preview"><div class="w-head"><span class="dot"></span><span class="name">My list</span><span class="left">2 left</span><span class="wadd" aria-hidden="true">${I.plus}</span></div>
      <ul><li><span class="check" aria-hidden="true">${I.tick}</span><span class="t">Call mom</span><span class="when">18:00</span></li><li><span class="check" aria-hidden="true">${I.tick}</span><span class="t">Buy milk</span></li></ul></div>`;
  }

  function render() {
    stage.innerHTML = { macos, android, ios }[st.os]();
    document.getElementById('say').textContent = SAY[st.step] || '';
    document.querySelectorAll('[data-os]').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.os === st.os)));
    const f = stage.querySelector('.osalert button:last-child, .fr .btn.primary, [data-sw]'); if (f) f.focus({ preventScroll: true });
  }
  document.addEventListener('click', (e) => {
    const g = e.target.closest('[data-go]');
    if (g) { if (g.dataset.v != null) st.done = g.dataset.v; st.step = g.dataset.go; return render(); }
    if (e.target.closest('[data-sw]')) { st.overlay = !st.overlay; return render(); }
    const o = e.target.closest('[data-os]');
    if (o) { st.os = o.dataset.os; st.step = 'welcome'; st.overlay = false; return render(); }
    if (e.target.closest('[data-restart]')) { st.step = 'welcome'; st.overlay = false; render(); }
  });
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
