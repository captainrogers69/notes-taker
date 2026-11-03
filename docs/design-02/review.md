# Design 02 — Review log

Findings from every review pass, newest round last. Fix order: **High → Medium → Low**. Tick an item when it is fixed and re-checked.

Severity: **High** = a user would hit it or call the design generic · **Medium** = a designer would flag it · **Low** = polish.

---

## Round 1 — AI passes (2026-11-03)

| Pass | Tool | Status |
|---|---|---|
| A | `design-taste-frontend` critique (the skill's scoring guide, `references/critique.md`) | Done, below. Caveat: the reviewer also built the design. A designer should re-score it in step 2. |
| B | `ui-ux-pro-max` (accessibility, touch, UX rules) plus an automated browser audit | Done, below |
| C | `design-motion-principles` audit | Done: [`motion-audits/notes-taker-2026-11-03.html`](../../motion-audits/notes-taker-2026-11-03.html). 2 critical · 4 important · 6 opportunities. Waiting on your review. |
| D | `flutter-ux-master` | Skipped: no Flutter screens yet (`lib/main.dart` is the template). Run it once the sheet is built in Flutter. |

### A · Taste critique

```
ROUND 1
Seen in one second: a grey task list with small coloured dots. Not "Weave", not "sticky notes".
Idea (one sentence): today's tasks on a day thread, in each list's own colour.
Live thing: the add field reads times as you type ("tomorrow 6pm" → Due Tomorrow 18:00).
Layout words: Up next = form strip / timeline / list + list / list = list + side panel / settings = rows.
Scores: design 7 · usability 7.5 · creativity 6.5 · content 8 → overall 7.2
Caps applied: none from the inspector (0 FAIL). The page caps for photos and motion do not apply to app screens.
```

Cover-the-logo test (pass 3): **fails.** Put Todoist, Things or Linear's logo on the Up next screen and it still works. That is exactly what people mean by "AI-made": a well-applied kit with no idea of its own. The day thread is the one original element, but it is a small grey strip about 140px tall that nobody would notice.

| # | Sev | Finding | Where | Suggested fix |
|---|---|---|---|---|
| A1 | ✅ High | **The sticky-note idea is gone.** Requirements §1 says notes "behave like sticky notes". Design 02 shows list colour only as 10px dots, so nothing feels like a note you stuck to your screen. | All screens | Give each list a real coloured surface: the sheet's header area, the list page's title area, or the Up next rows tinted by their list. Keep the chrome grey, but make the note itself look like a note. |
| A2 | ✅ High | **The day thread is too small to be the signature.** It is the product's one original element, sized like a footnote. | 03 Up next | Make it the hero of Up next (taller; labels at body size; Now as a clear vertical line). Put it in the mini bar sheet too, as a one-line strip. |
| A3 | ✅ High | **"Today" means three things.** A list called Today, a card called Today on Up next, and a grey "Today" chip on every row. Readers can't tell the list from the date. | 03 Up next, sample data | Rename the sample list (for example "Errands"). Show the list chip only when it adds information. |
| A4 | ✅ Medium | **Quick capture reads as a generic form strip.** A full-width card holding a field, a select, a black button and a hint line looks like every dashboard's search bar. | 03 Up next | Merge capture into the Today card's header (the field as its first row), or into the thread. |
| A5 | ✅ Medium | **The list page has a hole.** Everything below 560px is empty ground, and the right panel (colour, reminders, pin) is thin. | 03 List | Let the task card run the full height, or move list settings into the title row's menu and give tasks the full width. |
| A6 | ✅ Medium | **The sidebar is the stock task-app sidebar** (Pinned / Lists / counts / New list). It works, but it is the most template-looking part. | 03 sidebar | Show each list's progress in its own colour (a short bar, not a number), or mark which list the mini bar shows more strongly. |
| A7 | ✅ Low | The mark is a plain W in a yellow square: clean, but not yet a brand. | Everywhere | Draw a proper mark later (a thread, a folded note corner). |

### B · UX and accessibility (`ui-ux-pro-max` plus the browser audit)

Automated audit (CDP, light and dark): **contrast 0 failures**, every control has an accessible name, headings are in order on app screens.

| # | Sev | Rule | Finding | Where |
|---|---|---|---|---|
| B1 | ✅ High | `touch-target-size` | Tick circles are 20×20. Phones need 44×44; desktop web needs 24×24 (WCAG 2.5.8). Ticking is the most frequent action in the app. | Sheet, app rows, Android notification |
| B2 | ✅ High | `color-not-only` | Overdue is shown only by red text ("09:00" in red) in the sheet, the list page and the notification. Colour-blind users get no signal. | `weave.js` itemRow, `app.js` itemRow, `tray.js` |
| B3 | ✅ High | `confirmation-dialogs` | "Delete forever" in Trash deletes at once, with no confirmation and no undo. | `app.js` purge |
| B4 | ✅ High | `dragging-alternative` | The mini bar can only be moved by dragging, and list rows show a drag grip with no keyboard or button alternative (WCAG 2.5.7). | 01 bar, 03 list rows |
| B5 | ✅ Medium | `web-target-size` | Toggles are 32×18 and the details chevron is 28×20; both are under 24px tall. | 03 settings, list |
| B6 | ⏸ Medium | `contrast` (idle state) | The bar at 50% idle opacity drops its text below 4.5:1 over most wallpapers. It is intended, but a user who needs contrast cannot read the bar without hovering. | 01 bar |
| B7 | ✅ Medium | `tab-bar-ios` / `platform-adaptive` | iOS and Android use the same hamburger menu. iOS users expect a tab bar, and Android users expect predictive back. | 03 phone |
| B8 | ✅ Medium | `voiceover-sr` | Colour swatches are announced as "Colour 1…6"; they should be named (Yellow, Blue…). The sheet dialog is labelled "Weave", not the list name. | 03 list, sheet |
| B9 | ✅ Low | `truncation-strategy` | Phone thread labels cut off at 14 characters ("Pay electrici…"), with no way to see the full text. | 03 phone thread |
| B10 | ✅ Low | `readable-font-size` | Inputs are 14px, so iOS Safari zooms in on focus on the web build. This does not apply to native Flutter. | Web build only |
| B11 | ✅ Low | `keyboard-shortcuts` | The sheet opens with an animation when triggered by ⌥Space. Keyboard-triggered UI should open instantly. | `weave.css` .sheet |

Rejected advice: the skill's own design-system pick for "productivity app" (teal/orange, Plus Jakarta Sans, flat SaaS) is the generic default look we are trying to avoid. Not adopted.

### C · Motion (reconnaissance only)

- **Product type:** productivity tool, glanced at dozens of times a day.
- **Existing style:** CSS transitions of 150–260ms on `cubic-bezier(.2,.8,.2,1)`; reduced-motion is honoured everywhere.
- **Gaps found so far:**
  - The phone bottom sheets and the menu are rebuilt on each render, so they snap instead of sliding.
  - The list-switch menu in the sheet appears with no transition.
  - Ticked rows disappear with no exit.
  - The bar's fly-to-tray animation moves `left`/`top`, which triggers layout on every frame.
- **Proposed weighting:**
  - Emil (restraint) primary.
  - Jakub (polish) secondary.
  - Jhey (play) selective, for first run and empty states only.

### Round 1 fixes (2026-11-03)

✅ marks a fixed item above. What changed:

| # | Fix |
|---|---|
| A1 | List colour is now a surface (`.paper` in `tokens.css`, 22% light / 16% dark): the mini bar, the sheet's header, the list page's task card, and the lists on Up next, which are now coloured note tiles that show "4 left · next 17:00". The chrome stays grey. |
| A2 | The thread is the first card on Up next. Labels are 14px, marks are 15px, the axis is 3px, the Now line runs the full height and the rest of the day is shaded. The sheet has a one-line thread under the list name. |
| A3 | The sample list "Today" is now **Errands**. The list chip on Today rows shows only when today mixes lists. |
| A4 | The add field is the first row of the Today card, and its separate card is gone. |
| B1 | Tick circles stay 18px but sit in a 24px target on desktop and a 44px target on phones and in the Android notification. |
| B2 | Overdue times carry an alert icon and hidden "Overdue," words (sheet, app, notification). Thread labels start with "!". |
| B3 | Delete forever shows an Undo toast. |
| B4 | Mini bar: arrow keys move it (Shift for bigger steps), and the sheet footer has **Move to corner** (01). List rows: Alt+↑/↓ in a task, plus **Move up / Move down** in task details. |
| B5 | Toggles 40×24, details chevron 28×28, colour dot 24, text links and sync line 24px tall. |
| B8 | Colours are named (Yellow, Blue…), and the sheet dialog is named after its list. |
| B11 | The sheet opens and closes with no animation when ⌥Space, Enter or Escape triggers it. |

Re-checked: `lint.mjs` 0 FAIL; `inspect.mjs` 0 FAIL on every page. Up next, list, settings, 01 and 02 have 0 WARN; Archive keeps its 2 accepted WARN. The headless smoke flows pass with a clean console, including new steps for move up/down, Alt+↓, purge then undo, arrow-key bar move, Move to corner, and the keyboard open with no animation.

**Small items, fixed 2026-11-03:**

| # | Fix |
|---|---|
| A5 | On the list page, the note and the rail now end on one line. Any slack in the note becomes ruled lines that put the cursor in the add field when clicked, so empty space is a place to write. The rail gained a one-line **Today** thread for the list, and **Pin to top** moved to its foot. No viewport stretching: the checker rightly flagged that as empty bands. |
| A6 | Sidebar lists show a short progress bar in their own colour (done of total) beside the open count. The list shown in the mini bar is tinted in its note colour. |
| A7 | New mark: a yellow sticky note with a folded corner, and the W as one thread running in from its edge. `markMono` (tray and status bar) is the same shape in outline. |
| B9 | Thread labels carry the full text as a tooltip, and clicking or tapping one opens that task (on phones, its sheet). |
| B10 | On phones, inputs, selects and the editable title are 16px, so iOS Safari no longer zooms on focus. |

| B7 | **Decided: a bottom tab bar on both phones** (2026-11-03): Up next · Lists · Search · Settings, replacing the ☰ menu. iOS uses icon + label with the home-indicator inset and a chevron "‹ Lists" back. Android uses a Material 3 navigation bar (80dp, a pill behind the current tab) and a back arrow. Lists is a new phone screen (note tiles, New list, Archive and trash), and Search has its own screen. A list or Archive opens inside the Lists tab, with the tab still showing. Up next shows a due-today badge. The add field sits just above the tabs. In the Flutter build, Android's back gesture (with predictive back) must pop the same way as the arrow; the HTML prototype can't show the system gesture. |

Checks: `inspect.mjs` 0 FAIL / 0 WARN on Up next, settings and all six lists. The click-through tests pass with a clean console.

**Still open:**
- B6: **decided, keep 50%** (2026-11-03). The bar is meant to recede; it reaches full strength on hover, while open, and while dragging. Not fixing.
- C: motion audit, critical and important items fixed (below). The 6 opportunities are not started.

### Motion audit checklist

From [`motion-audits/notes-taker-2026-11-03.html`](../../motion-audits/notes-taker-2026-11-03.html). Tick an item when it is fixed and re-checked in the browser.

**Critical**
- [x] M1 · Phone bottom sheets and menu snap in and out → slide in 280ms on the iOS sheet curve, out in 200ms (`app.js`, `app.css`)
- [x] M2 · Bar flies into the tray by animating `left`/`top` → transform + opacity only, 260ms, ends on `transitionend` (`tray.js`, `tray.css`)

**Important**
- [x] M3 · Tick holds 280ms, then the row vanishes and the list jolts → 120ms fill, 120ms fade, rows below close up with a 180ms FLIP; rapid ticks don't cancel each other (`weave.js`, `app.js`, `tray.js`)
- [x] M4 · Menus have no enter or exit (list switcher; Share, More, Colour) → 180ms opacity + scale .97 from the trigger, 100ms fade out, instant when opened from the keyboard (`weave.css`/`weave.js`, `app.js`/`app.css`)
- [x] M5 · Exits as heavy as enters (sheet, toast) → exit is a 120–150ms fade with no slide (`weave.css`, `app.css`)
- [x] M6 · Default `ease` and scattered durations → `--dur-fast`, `--dur` and `--ease-out` tokens on every transition (`tokens.css` and all stylesheets)

**Opportunities**
- [ ] M7 · New-task highlight 1.2s → 600ms (`weave.css:117`, `app.css`)
- [ ] M8 · Reserve the height of the parse line under the sheet's field, so the list stops nudging while you type (`weave.css:108`)
- [ ] M9 · "Done · n" section expands with its chevron (180ms `grid-template-rows`) (`weave.js:49`, `app.js`)
- [ ] M10 · Tray icon pop 1.35 → 1.12, 240ms (`tray.css:24`)
- [ ] M11 · Day's-last-tick ink stroke along the thread, once a day, skipped under reduced motion (`app.js` `drawThread`)
- [ ] M12 · First-run bar unroll from the mark, once only (`01-mini-bar`)

### Motion audit fixes: critical (2026-11-03)

| Finding | Fix |
|---|---|
| Phone sheets snap in and out (re-render replaced them) | Each render starts the sheet in the state it was last drawn in, then switches after a reflow. Opening slides up (280ms, `cubic-bezier(.32,.72,0,1)`), and closing slides down in 200ms with its old content still showing. Edits inside an open sheet don't replay the motion. The scrim fades with it. The old ☰ side menu no longer exists (it became the tab bar). `03-app/app.js` `sheetLayer` / `settleSheet`, `03-app/app.css` `.psheet`. |
| Bar flies into the tray by animating `left`/`top` | The bar's `left`/`top` never change during the flight. Only `transform: translate() scale(.4)` and `opacity` animate, over 260ms with an ease-out-quint curve. The animation ends on `transitionend`, with a 320ms fallback for reduced motion, where no transition runs. Showing the bar reverses it from the tray icon. `02-tray/tray.js` `toTray` / `afterFly`, `02-tray/tray.css` `.flying`. |

Verified mid-flight in a headless browser: the sheet is part-way at 70ms on open and 60ms on close; the bar's `left` stays fixed while its transform scales to ~.49 at 90ms (macOS and Windows). All click-through tests pass with a clean console; inspect 0 FAIL / 0 WARN; lint 0 FAIL.

### Motion audit fixes: important (2026-11-03)

| Finding | Fix |
|---|---|
| M3 · Tick holds, then the row vanishes and the list jolts | The circle fills and the text strikes through over 120ms, then the row fades over 120ms. The rows below slide up over 180ms (FLIP: the old position is recorded, the list re-renders, and each row animates from its old offset). The ticking and leaving rows are tracked in sets, so a re-render or a second tick mid-animation doesn't reset the first. Mini-bar sheet, app list, Up next and the Android notification. `assets/weave.js` `flipRender`, `03-app/app.js` `flipRender` / `rowMotion`, `02-tray/tray.js`. |
| M4 · Menus snap open and shut | The list switcher and the Share, More and Colour pops grow from their trigger (opacity plus scale .97, 180ms, transform-origin at the trigger) and fade out over 100ms. A menu opened from the keyboard (Enter or Space, or the Escape and Backspace shortcuts) appears and disappears instantly. `assets/weave.css` `.menu`, `03-app/app.css` `.pop`, `kbd` class in both scripts. |
| M5 · Exits as heavy as enters | The sheet enters from scale .96 (180ms opacity, 200ms transform) and leaves as a 120ms fade at scale .99. Opening it with ⌥Space is instant. The toast rises 16px on enter and leaves as a 150ms fade with no drop. `assets/weave.css` `.sheet.pre`, `03-app/app.css` `.toast.pre`. |
| M6 · Default `ease` and scattered durations | `--dur-fast` (120ms), `--dur` (180ms), `--ease-out` and `--ease-sheet` in `tokens.css`. Every transition in the three stylesheets uses them. The two longer flights (the 260ms tray flight and the 280ms phone sheet) are named exceptions. |

Verified mid-animation in a headless browser: the sheet at 50ms is part-way in (scale .991, opacity .82) and part-way out (opacity .07); a clicked menu is at opacity .82 after 40ms while a keyboard-opened one is instant; two quick ticks both fade and the rows below slide; the toast fades out without moving. The click-through tests pass with a clean console on 01, 02 (macOS, Windows, Android) and 03. Lint 0 FAIL. The inspector gives 0 FAIL / 0 WARN on every screen except one WARN on the phone list page: the space between a short list and the add field pinned above the tab bar. That space is intended.

---

## Next

Decide on the motion audit's opportunities (M7–M12), run round 2 of the AI passes on the new screenshots, then go to designer review (plan step 2).
