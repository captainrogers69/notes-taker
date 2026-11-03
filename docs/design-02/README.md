# Weave — Design 02

A redesign of the prototypes in [`docs/design/`](../design/index.html): mini bar + sheet, hide to tray, and the full app. Layouts were rethought, not only restyled. Open [`index.html`](index.html) in a browser.

**Status: proposal.** The [design playbook](../playbook/design-playbook.md) still describes design 01 (Woven). Nothing in it changes until this direction is chosen.

| ID | Prototype | What changed from design 01 |
|---|---|---|
| [01](01-mini-bar/index.html) | Mini bar and sheet | The bar shows the one thing to know: "1 overdue", otherwise "next 17:00". No hotkey chip or colour strip. The sheet orders tasks by time, with times right-aligned. The field reads times as you type ("tomorrow 6pm" → "Due Tomorrow 18:00"). Lists open in a menu instead of a sideways slide. The footer shows sync status. |
| [02](02-tray/index.html) | Hide to tray | The same flow on macOS, Windows and Android. The Android notification lists the next two tasks with times, tick buttons, and a reply field. Linux is left out: it is the same as macOS. |
| [03](03-app/index.html) | Weave app | The app opens on **Up next**: today's tasks from every list, with a **day thread** on top. A list screen is one task card at a reading width; task details open beside it once a task is selected (colour is on the title dot, Pin and Archive in •••). Archive and trash share one screen. Settings use one row per section, with a live preview of the mini bar's opacity. On phones (iOS and Android), a bottom tab bar (Up next · Lists · Search · Settings) replaces the menu, styled to each platform, and the add field sits just above it, near the thumb, instead of a floating button. Linux chrome is dropped. |

## Direction

Dealt by the `design-taste-frontend` skill (app run, `draw.mjs --app --kind workspace`), style **achromatic ledger**, seed `686191426`. Adopted whole; no redraws.

- **The move:** the chrome carries no colour. There is one near-black primary button per screen. The only hue is the current list's own colour, on that list's data: check fills and its marks on the thread.
- **Face (what makes it Weave's):** the list colours (F7) used as the data hue. The ground is a low-chroma paper tone (`#f5f5f3`), not cream.
- **Element only Weave has:** the **day thread**, today from 07:00 to 23:00 on one line. The part already lived is drawn in ink, each due task is a mark in its list's colour, overdue marks are red rings, and done marks are hollow.
- **Type:** Geist 400/500, sizes 13 / 14 / 16 / 24, tabular figures on every time and count. Monospace dropped.
- **Shape:** card radius 8, control radius 6, 1px borders. Shadows only on what floats: bar, sheet, menus, toast.

**Round 1 review fixes** (see [review.md](review.md)): list colour is now a note-paper surface on the bar, the sheet's header, the list's task card and the list tiles on Up next. The day thread leads Up next and appears as one line in the sheet. The sample list "Today" is now "Errands".

**Clutter rules** (design playbook C1–C12, see [declutter.html](declutter.html)): each fact once per screen, a header of date + title + one fact, one field before the first task, one place per action, no group labels or legends the order and marks already carry, counts without progress bars, and a list at a reading width.

## Each screen's question

| Screen | Question it answers first | Main action, one click away |
|---|---|---|
| Mini bar | How much is left, and is anything late or next? | Click → type → Enter |
| Sheet | What's on this list, in time order? | The add field, focused on open |
| Up next | What is due today across every list? | One add field at the top of the Today card, with the list as a chip inside |
| List | What's left on this list? | Add field at the top; tick |
| Task details | When is it due and when will it remind me? | Due, Remind me, Repeat options |
| Settings | Is Weave set up the way I want? | Each control saves itself |

## Differences from the playbook to decide on

- **Font:** Inter → Geist. **Radius:** sheet 12 / bar 10 → 8 / 6. **Light mode is now the default**; dark is still complete.
- **Colour strip** at the top of the bar and sheet removed. The list dot carries identity.
- **Sheet order:** newest first → time order (overdue, then by time, then untimed newest first).
- **Lists view:** sideways slide → a menu from the list name. Backspace in an empty field still opens it.
- **New:** quick-capture parsing (today, tonight, tomorrow, weekdays, 6pm, 18:30, in 2 h) in the sheet, the app and the Android notification.
- **New screen:** Up next, which the app opens on. The old app opened on a list.
- **Purple (`n4`)** stays in the note palette. The skill bans violet as an *accent*, but here it is one of six user-chosen list colours.

## Checks run

- `lint.mjs --app docs/design-02`: 0 FAIL. The remaining warnings are shadows on floating surfaces.
- `inspect.mjs --app` at 1440, 768 and 390: 0 FAIL on every page.
  - Up next, list, settings and index: 0 WARN.
  - Archive and trash: 2 WARN, both accepted. The screen holds two archived lists and one in the trash, so it leaves empty space and its cards end 44px apart; padding them would mean inventing data.
  - 01 and 02 run with `--allow button-fx,hero-void` (01 also `unused-canvas`). The bar is a floating window, so its shadow is real, and the empty area is the user's desktop.
- Clicked through in a headless browser with the console clean: add with parsing, tick and undo, switch list, task details, share menu, search, opacity preview, restore, new list. The data's `console.assert` checks pass.

## Sample data to replace

Everything comes from [`assets/data.js`](assets/data.js): six lists, three devices, and a clock fixed at **Tue 3 Nov 2026, 16:20**. Archive and trash rows are in `03-app/app.js` (`archived`, `trashed`). The account name in the sidebar is the project owner's. Counts, "next" lines and the thread are computed from the items, never typed in.

## Files

`assets/tokens.css` (all tokens, light + dark) · `assets/data.js` (data, parsing, checks) · `assets/icons.js` (one outline set + the W mark) · `assets/weave.css` / `weave.js` (bar + sheet, shared by 01 and 02) · `03-app/` (app). Throwaway prototype code, not app code.
