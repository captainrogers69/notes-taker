// Weave design-02 — sample data and helpers shared by every prototype (throwaway, not app code).
// Sample content: replace before any user testing. Counts and "next" lines are computed from the
// items below, never typed in, and checked by the assertions at the bottom.
(function () {
  'use strict';

  // The prototype's clock: Tuesday 3 November 2026, 16:20.
  const NOW = { min: 16 * 60 + 20, day: 'Tue 3 Nov', clock: '16:20' };
  const DAYS = ['Today', 'Tomorrow', 'Thu 5 Nov', 'Fri 6 Nov', 'Sat 7 Nov', 'Sun 8 Nov', 'Mon 9 Nov', 'Tue 10 Nov'];
  const TODAY_DOW = 2; // Tuesday (0 = Sunday)

  let seq = 100;
  const id = () => ++seq;
  // A checklist item. due = { d: days from today, t: 'HH:MM' | null }; remind = words shown as they read.
  const C = (t, extra = {}) => ({ id: id(), type: 'check', t, d: false, indent: 0, due: null, remind: null, repeat: null, ...extra });
  const T = (t) => ({ id: id(), type: 'text', t, indent: 0 });

  const lists = [
    { id: 1, name: 'Today', color: 0, pinned: true, onScreen: true, edited: '2 min ago on Pixel 8', items: [
      T('Errands before 18:00, calls after.'),
      C('Pay electricity bill', { due: { d: 0, t: '09:00' }, remind: 'At due time' }),
      C('Reply to design review', { due: { d: 0, t: '17:00' }, remind: '15 min before' }),
      C('Pick up parcel from the locker', { due: { d: 0, t: '18:00' } }),
      C('Call mom', { due: { d: 0, t: '18:20' }, remind: 'In 2 h' }),
      C('Book dentist', { d: true, due: { d: 0, t: '11:00' } }),
    ] },
    { id: 2, name: 'Weave', color: 1, pinned: true, onScreen: false, edited: 'yesterday on MacBook Air', items: [
      C('Review design-02 prototypes', { due: { d: 1, t: '10:00' }, remind: '1 h before' }),
      C('Write the sync-conflict copy'),
      C('Test overlay permission on Android 8', { indent: 0 }),
      C('Denied path shows the home widget', { indent: 1 }),
      C('Pick the floating design', { d: true }),
      C('Finish architecture playbook', { d: true }),
    ] },
    { id: 3, name: 'Groceries', color: 2, pinned: false, onScreen: false, edited: 'this morning on Pixel 8', items: [
      C('Eggs'), C('Coffee beans'), C('Oat milk'), C('Spinach'),
      C('Bread', { d: true }),
    ] },
    { id: 4, name: 'Packing — Goa', color: 3, pinned: false, onScreen: false, edited: 'Sunday on MacBook Air', items: [
      C('Passport', { due: { d: 3, t: '07:00' } }),
      C('Sunscreen'),
      C('Swimwear'),
      C('Phone charger', { d: true }),
    ] },
    { id: 5, name: 'Ideas', color: 4, pinned: false, onScreen: false, edited: '2 Nov on iPad', items: [
      T('Weekend: the bakery that opened on 4th Cross Road.'),
      C('Read "A Pattern Language", ch. 1–3'),
    ] },
    { id: 6, name: 'Weekly reset', color: 5, pinned: false, onScreen: false, edited: 'Sunday on MacBook Air', items: [
      C('Plan the week', { due: { d: 5, t: '19:00' }, repeat: 'Weekly' }),
      C('Clear the inbox', { d: true, repeat: 'Weekly' }),
      C('Water the plants', { d: true, repeat: 'Weekly' }),
    ] },
  ];

  const devices = [
    { name: 'MacBook Air', kind: 'This Mac', seen: 'Now' },
    { name: 'Pixel 8', kind: 'Android', seen: '2 min ago' },
    { name: 'iPad', kind: 'iPadOS', seen: '2 Nov' },
  ];

  // ---------- Helpers ----------
  const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const toMin = (t) => { const [h, m] = t.split(':').map(Number); return h * 60 + m; };
  const checks = (l) => l.items.filter((i) => i.type === 'check');
  const open = (l) => checks(l).filter((i) => !i.d);
  const done = (l) => checks(l).filter((i) => i.d);
  const isOverdue = (it) => !it.d && it.due && it.due.t && it.due.d === 0 && toMin(it.due.t) < NOW.min;
  const leftLabel = (l) => (open(l).length ? `${open(l).length} left` : 'All done');

  // "17:00" today, "Tomorrow 10:00", "Fri 6 Nov".
  function dueLabel(due) {
    if (!due) return '';
    if (due.d === 0) return due.t || 'Today';
    if (due.d === 1) return `Tomorrow${due.t ? ' ' + due.t : ''}`;
    return `${DAYS[due.d] || `In ${due.d} days`}${due.t ? ' ' + due.t : ''}`;
  }

  // The next open item with a time, today or later (overdue items are reported separately).
  function nextUp(l) {
    return open(l)
      .filter((i) => i.due && i.due.t && !isOverdue(i))
      .sort((a, b) => a.due.d - b.due.d || toMin(a.due.t) - toMin(b.due.t))[0] || null;
  }

  // When an item's reminder rings today, in minutes since midnight (null if not today or no reminder).
  function remindAt(it) {
    if (!it.remind || !it.due || it.due.d !== 0 || !it.due.t) return null;
    const due = toMin(it.due.t);
    const off = { 'At due time': 0, '15 min before': 15, '1 h before': 60 }[it.remind];
    if (off != null) return due - off;
    return /^In /.test(it.remind) ? due : null; // timers were stored as their due moment
  }

  // Everything due today across lists, in time order, with its list.
  function today(all = lists) {
    return all.flatMap((l) => checks(l).filter((i) => i.due && i.due.d === 0).map((i) => ({ it: i, list: l })))
      .sort((a, b) => toMin(a.it.due.t) - toMin(b.it.due.t));
  }
  function laterThisWeek(all = lists) {
    return all.flatMap((l) => open(l).filter((i) => i.due && i.due.d > 0).map((i) => ({ it: i, list: l })))
      .sort((a, b) => a.it.due.d - b.it.due.d || toMin(a.it.due.t || '00:00') - toMin(b.it.due.t || '00:00'));
  }

  // Quick capture: "call mom tomorrow 6pm" → { text: 'call mom', due: { d: 1, t: '18:00' } }.
  // Recognises today / tonight / tomorrow, 18:00, 6pm, 6:30pm, and "in 2h" / "in 30 min".
  function parseQuick(raw) {
    let s = ` ${raw} `;
    let d = null, t = null, timer = null;
    const take = (re, fn) => { const m = s.match(re); if (m) { fn(m); s = s.replace(m[0], ' '); } };
    take(/\s(tomorrow|tmrw)\s/i, () => { d = 1; });
    take(/\s(today)\s/i, () => { d = 0; });
    take(/\s(?:on\s+)?(sun|mon|tue|wed|thu|fri|sat)[a-z]*\s/i, (m) => {
      const dow = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'].indexOf(m[1].toLowerCase());
      d = ((dow - TODAY_DOW + 7) % 7) || 7; // "tue" on a Tuesday means next week
    });
    take(/\s(tonight)\s/i, () => { d = 0; t = '20:00'; });
    take(/\sin\s+(\d{1,3})\s*(h|hr|hrs|hours?|m|min|mins|minutes?)\s/i, (m) => {
      const mins = /^h/i.test(m[2]) ? +m[1] * 60 : +m[1];
      timer = mins;
      const at = NOW.min + mins;
      d = Math.floor(at / 1440); t = fmtClock(at % 1440);
    });
    take(/\s(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)\s/i, (m) => {
      let h = +m[1] % 12; if (/pm/i.test(m[3])) h += 12;
      t = fmtClock(h * 60 + (+m[2] || 0));
    });
    take(/\s(?:at\s+)?([01]?\d|2[0-3]):([0-5]\d)\s/, (m) => { t = fmtClock(+m[1] * 60 + +m[2]); });
    const text = s.replace(/\s+/g, ' ').trim();
    if (t && d == null) d = toMin(t) <= NOW.min ? 1 : 0; // a time already past today means tomorrow
    if (d == null && t == null) return { text: raw.trim(), due: null };
    return { text, due: { d, t }, timer };
  }
  function fmtClock(m) { return /* taste-skill-ignore: a clock */ `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`; }
  function parsePreview(p) {
    if (!p.due) return '';
    if (p.timer) return `Reminder in ${p.timer >= 60 ? p.timer / 60 + ' h' : p.timer + ' min'} · ${dueLabel(p.due)}`;
    return `Due ${p.due.d === 0 ? 'today ' + (p.due.t || '') : dueLabel(p.due)}`.trim();
  }

  // ---------- Checks: figures that appear twice must agree ----------
  const sum = (a) => a.reduce((x, y) => x + y, 0);
  console.assert(sum(lists.map((l) => open(l).length + done(l).length)) === sum(lists.map((l) => checks(l).length)), 'open + done = all checks');
  console.assert(today().filter((x) => isOverdue(x.it)).length === 1, 'exactly one overdue item today (the finding)');
  console.assert(nextUp(lists[0]).t === 'Reply to design review', 'next up on Today is the 17:00 reply');
  console.assert(remindAt(lists[0].items[2]) === 16 * 60 + 45, 'reply reminder rings 16:45');
  console.assert(parseQuick('call mom tomorrow 6pm').due.t === '18:00', 'quick capture parses 6pm');
  console.assert(parseQuick('dentist fri 10am').due.d === 3 && parseQuick('dentist fri 10am').text === 'dentist', 'quick capture parses a weekday');

  window.WeaveData = {
    NOW, lists, devices, esc, toMin, checks, open, done, isOverdue, leftLabel, dueLabel, nextUp, today, laterThisWeek,
    parseQuick, parsePreview, fmtClock, id, remindAt,
    color: (l) => `var(--n${l.color % 6})`,
    ink: (l) => `var(--n${l.color % 6}-ink)`,
  };
})();
