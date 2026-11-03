# Design 02 — Review log

Findings from every review pass, newest round last. Fix order: **High → Medium → Low**. Tick an item when it is fixed and re-checked.

Severity: **High** = a user would hit it or call the design generic · **Medium** = a designer would flag it · **Low** = polish.

---

## Round 1 — AI passes (2026-11-03)

| Pass | Tool | Status |
|---|---|---|
| A | `design-taste-frontend` critique (the skill's scoring guide, `references/critique.md`) | Done, below. Caveat: the reviewer also built the design. A designer should re-score it in step 2. |
| B | `ui-ux-pro-max` (accessibility, touch, UX rules) plus an automated browser audit | Done, below |
| C | `design-motion-principles` audit | Reconnaissance done; the full audit waits on the weighting confirmation |
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
| A5 | Medium | **The list page has a hole.** Everything below 560px is empty ground, and the right panel (colour, reminders, pin) is thin. | 03 List | Let the task card run the full height, or move list settings into the title row's menu and give tasks the full width. |
| A6 | Medium | **The sidebar is the stock task-app sidebar** (Pinned / Lists / counts / New list). It works, but it is the most template-looking part. | 03 sidebar | Show each list's progress in its own colour (a short bar, not a number), or mark which list the mini bar shows more strongly. |
| A7 | Low | The mark is a plain W in a yellow square: clean, but not yet a brand. | Everywhere | Draw a proper mark later (a thread, a folded note corner). |

### B · UX and accessibility (`ui-ux-pro-max` plus the browser audit)

Automated audit (CDP, light and dark): **contrast 0 failures**, every control has an accessible name, headings are in order on app screens.

| # | Sev | Rule | Finding | Where |
|---|---|---|---|---|
| B1 | ✅ High | `touch-target-size` | Tick circles are 20×20. Phones need 44×44; desktop web needs 24×24 (WCAG 2.5.8). Ticking is the most frequent action in the app. | Sheet, app rows, Android notification |
| B2 | ✅ High | `color-not-only` | Overdue is shown only by red text ("09:00" in red) in the sheet, the list page and the notification. Colour-blind users get no signal. | `weave.js` itemRow, `app.js` itemRow, `tray.js` |
| B3 | ✅ High | `confirmation-dialogs` | "Delete forever" in Trash deletes at once, with no confirmation and no undo. | `app.js` purge |
| B4 | ✅ High | `dragging-alternative` | The mini bar can only be moved by dragging, and list rows show a drag grip with no keyboard or button alternative (WCAG 2.5.7). | 01 bar, 03 list rows |
| B5 | ✅ Medium | `web-target-size` | Toggles are 32×18 and the details chevron is 28×20; both are under 24px tall. | 03 settings, list |
| B6 | Medium | `contrast` (idle state) | The bar at 50% idle opacity drops its text below 4.5:1 over most wallpapers. It is intended, but a user who needs contrast cannot read the bar without hovering. | 01 bar |
| B7 | Medium | `tab-bar-ios` / `platform-adaptive` | iOS and Android use the same hamburger menu. iOS users expect a tab bar, and Android users expect predictive back. | 03 phone |
| B8 | ✅ Medium | `voiceover-sr` | Colour swatches are announced as "Colour 1…6"; they should be named (Yellow, Blue…). The sheet dialog is labelled "Weave", not the list name. | 03 list, sheet |
| B9 | Low | `truncation-strategy` | Phone thread labels cut off at 14 characters ("Pay electrici…"), with no way to see the full text. | 03 phone thread |
| B10 | Low | `readable-font-size` | Inputs are 14px, so iOS Safari zooms in on focus on the web build. This does not apply to native Flutter. | Web build only |
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

**Still open:**
- A5: the list page's empty space below the task card.
- A6: the sidebar.
- A7: the mark.
- B6: idle opacity versus contrast. This is a product decision: raise the floor to 70%, or keep 50% and add a "never fade" setting.
- B7: iOS tab bar and Android predictive back. This is a layout decision for the phone shell.
- B9: phone thread labels are still cut off at 16 characters.
- B10: 14px web inputs.
- C: the motion audit, which waits on the weighting.

---

## Next

Decide B6 and B7, run the motion audit (C), run round 2 of the AI passes on the new screenshots, then go to designer review (plan step 2).
