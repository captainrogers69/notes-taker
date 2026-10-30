# Weave — Design Playbook

How Weave looks and behaves. Follow this for every screen, widget and floating surface.
Source: [requirements.md](../requirements.md) + [architecture-playbook.md](architecture-playbook.md) + design variations in [`docs/design/`](../design/index.html).

> **Status: chosen — [003 Mini bar](../design/003-mini-bar/index.html).** A faded mini bar that opens the Weave sheet.
> Rules marked **⏳** still need a decision.

---

## 0. Design Intent

Weave is **always within reach and never in the way**. It's a quick launcher for your lists, not a workspace.

| Principle | Means |
|---|---|
| **Glance, tick, add** | Most sessions last seconds. The shortest path: tap the bar → type → Enter. |
| **Quiet when idle** | The bar is faded and small. It shows up fully only on hover, touch or when open. |
| **Never block, never nag** | Draggable, collapsible, hideable in one action. No unasked popups (requirements anti-goals). |
| **Small and obvious** | If a control needs explaining, it doesn't belong. New users get it in < 2 minutes. |
| **One family** | The bar is the sheet's collapsed form: same surface, line, shadow, type and accent. |
| **Same everywhere** | Same sheet, words and colors on every platform. Only how the bar floats adapts to the OS. |

---

## 1. Vocabulary

| User-facing word | Meaning in requirements / code | Notes |
|---|---|---|
| **List** | **Note** (requirements glossary): title + text blocks and/or checklist items + color | UI says "List"; code and requirements keep `Note`. Never "project" — project management is a non-goal |
| **Item** | Checklist item | UI may say "task" in placeholders ("Add a task…") |
| **Lists** (view) | The main list of notes (F8) | |
| **Mini bar** | The floating trigger | Design term; users just see "Weave" |
| **Sheet** | The window the mini bar opens | |
| **Pin to screen** | Note shown floating (F1) | Never just "pin" — "pin to top" is different (F8) |

---

## 2. Anatomy

```
 Mini bar (idle 50%, drag anywhere)
 ┌▔▔▔▔▔▔▔▔▔▔▔▔ list color ▔▔▔▔▔▔▔▔▔▔▔▔┐
 │ ⠿  ● Today   2 left   [⌥ Space]      │  ← 40 px tall, width follows the name
 └──────────────────────────────────────┘
   8 px gap; sheet left-aligned to the bar (opens above if no room below)
 ┌──────────────────────────────┐   ┌──────────────────────────────┐
 │▔▔▔▔▔▔▔ list color ▔▔▔▔▔▔▔▔│   │▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔│
 │ ‹  ● Today ▾         2 left  │   │ ‹  Lists                  │
 │ ┌──────────────────────────┐ │   │ ● Today                 2  ✓ │
 │ │ + Add a task…          ↵ │ │   │ ● Weave                 1    │
 │ └──────────────────────────┘ │   │ ● Groceries             2    │
 │ ○ Buy milk        ← newest   │   │ ┌──────────────────────────┐ │
 │ ○ Reply to design review     │   │ │ + New list…         ↵ │ │
 │ ▸ Done · 1                   │   │ └──────────────────────────┘ │
 └──────────────────────────────┘   └──────────────────────────────┘
   Sheet — note view (320 × 380)      Sheet — lists view
            ◀── slides sideways between the two views ──▶
```

### Mini bar

- **Grip** `⠿` (muted dots) · **color dot** · **list name** (15/600, ellipsis after 160 px) · **"N left" / "All done"** (muted) · **hotkey chip** `⌥ Space`.
- 3 px list-color strip across the top, like the sheet.
- Whole bar is the drag handle and the tap target. No buttons inside it.
- Name, count and color update live as the user ticks, adds or switches list.

### Sheet

- **Color strip:** 3 px of the list color across the top.
- **Header (note view):** back `‹` · list name with `▾` (both open lists) · "N left" / "All done" · **hide** `⌄` · **open-app** `⤢`.
- **Footer (only when opened from the menu bar / tray / notification):** **Show bar** · **Pause reminders 1 h** (→ "Paused till 17:20 · Resume").
- **Input at the top**, focused on open. Enter adds; the new item appears right under it with a short highlight, focus stays for the next one.
- **Open items**, newest first. Round check circles.
- **Done section:** ticked items show the tick for ~0.3 s, then move into a collapsed "Done · N" (F3.4). Tap to expand; tap a done item to untick.
- **Lists view:** `‹` returns to the current list. Rows: dot · name · open count · ✓ on current.
- **New list:** input at the bottom. Enter creates it, **switches to it** and focuses "Add a task…".
- **No close button.** Close by tapping the bar, Esc, or clicking outside.

---

## 3. Interaction Rules

| Action | Behavior |
|---|---|
| **Tap / click bar** | Toggle sheet. Opens in the **note view of the current list** with input focused |
| **Drag bar** | Moves it freely. Movement under **5 px** counts as a tap. Dragging closes an open sheet |
| **Drop bar** | Stays where dropped, clamped 12 px inside the screen. No snapping |
| **Sheet position** | 8 px below the bar, left edges aligned (clamped to the screen); above the bar when there's no room below |
| **Enter in input** | Add item / create list. Empty input does nothing |
| **`‹` / list name** | Lists view; `‹` there returns to the current list |
| **Backspace on empty input** | Switches between note and lists view (keyboard only) |
| **`⤢` / `⌘O` (Ctrl+O)** | Closes the sheet and opens the full app on the same list (§9) |
| **`⌄` / `⌘H` (Ctrl+H)** | **Hides the bar** into the menu bar / tray / notification (§5). Reminders keep ringing |
| **Click tray icon** | Opens the **same sheet** from there, with the tray footer. Click again / Esc / outside closes |
| **Show bar** (tray footer, notification action, Android tile) | Bar flies back to where it was |
| **Pause reminders** | Separate from hiding. 1 h, then resumes on its own. Tray icon dims with a slash while paused |
| **Esc** | Close sheet |
| **Click / tap outside** | Close sheet (user went back to their other app) |
| **Global hotkey** (`⌥ Space` default, S4) | Toggle sheet from anywhere (desktop) |
| **Hide all** | One action hides bar + sheet (F1.5); tray / menu-bar item restores |

Rules:

- **Focus (F1.6):** the bar never takes keyboard focus on its own. The sheet takes focus only when the user opens it.
- **Position is per device** (F1.3): bar position is saved locally, never synced.
- Reopening always lands in the current list's note view, not wherever it was left.
- Every action is undoable via snackbar in the main app (F10); in the sheet, unticking is the undo for ticks.

---

## 4. Visual Language

Bar and sheet share **one set of tokens**. Never style the bar separately.

### Theme — Woven (chosen 2026-10-30)

Crisp cool neutrals, **solid surfaces, no blur** (looks the same on every OS, cheap in Flutter), Inter throughout, plain color strip, solid strike on done items. Light and dark. Mode is stored as `weave-mode` (prototype only).

All tokens live in one file: [`docs/design/assets/tokens.css`](../design/assets/tokens.css). Every prototype (bar, sheet, tray, app) reads it; never hard-code a color in a page.

### Color — note palette (F7)

| Token | Fill (all modes) | Use |
|---|---|---|
| `n0` yellow | `#F5C84C` | Default list, Weave brand |
| `n1` blue | `#6AA6F8` | |
| `n2` green | `#5DC48A` | |
| `n3` pink | `#EE7FA8` | |
| `n4` purple | `#A88BEB` | |
| `n5` orange | `#F29A5B` | |

- **Fill vs ink.** `--nX` is the fill: strip, dots, check fill. `--nX-ink` is the text-safe shade for anything read as text or a thin line: `+`, due chips, focus ring, active icons. In dark mode ink = fill; in light mode ink is darkened to reach ≥ 4.5:1: `#876508 #0B65E0 #2C784D #CD1B5D #794CE0 #AC4F0E`.
- An element sets `--accent` / `--accent-ink` to one pair; children only use those two.
- Note color appears as **accent only**. New lists cycle through the palette in order.
- Text on a fill (check mark) is `#1B1B1B`. Never white on yellow/green.

### Surface tokens

Each mode defines the same names. Values in `tokens.css`:

| Token | Light | Dark |
|---|---|---|
| `canvas` | `#F4F6F9` | `#121418` |
| `side` | `#ECEFF3` | `#171A1F` |
| `surface` (bar, sheet) | `#FFFFFF` | `#1B1F25` |
| `card` | `#FFFFFF` | `#1F242B` |
| `text` | `#161A20` | `#EEF1F5` |
| `muted` | `#5B6471` | `#97A0AC` |
| `line` | `rgba(20,40,70,.11)` | `rgba(200,220,255,.09)` |
| `hover` / `field` / `sel` | same tint at 4.5% / 5.5% / 8% | same tint at 5% / 6.5% / 9% |
| `shadow` | `0 20 50 rgba(20,30,50,.18)` | `0 24 60 rgba(0,0,0,.55)` |

- `text` and `muted` are ≥ 4.5:1 on canvas, side, surface and card in both modes (checked by script). Muted is a solid color, not a % of black/white.
- Follows the system light/dark setting (S4 can override).

### Typography (Inter)

| Role | Size / weight |
|---|---|
| List name (bar + sheet header) | 15 / 600 |
| Item, input | 14 / 400 |
| Meta ("2 left", counts, "Done · N") | 12.5 / 400, muted |
| Hotkey chip, hints | 11 / 400, muted |

Respect the OS text scale; sheet grows in height, never clips text (NFR9).

### Shape & spacing

- 4 px grid. Sheet side padding 10, row padding 8, gap 11 between check and text. Bar gap 10, padding 10 left / 6 right.
- Radius: sheet 12 · bar 10 · input 10 · rows 9 · icon buttons & hotkey chip 8 · check circle 50%.
- Bar **40 px** tall, width follows content. Sheet **320 × 380** fixed (sticky-note feel); list scrolls, header and input stay fixed.

### Opacity (the "faded" look)

| Bar state | Opacity |
|---|---|
| Idle | **50%** |
| Hover / touch / dragging / sheet open | 100% |
| Full-screen app in front (desktop, S4) | hidden |

User setting "floating opacity" (S4) scales the idle value.

### Motion

| Event | Motion |
|---|---|
| Sheet open | fade + scale 0.94 → 1 + 8 px slide from the bar, 160–220 ms, `cubic-bezier(.2,.8,.2,1)` |
| Note ↔ lists | horizontal slide, 260 ms same curve |
| Bar hover | opacity 200 ms |
| Bar drag | scale 1.03 while held |
| Tick | instant fill + strike, item moves to "Done" after ~280 ms |
| New item | 1 s accent highlight fading out |

Respect reduce-motion: all durations → 0.

---

## 5. Platform Mapping

| Platform | Mini bar | Sheet | When hidden (`⌄`) |
|---|---|---|---|
| **macOS** | Borderless always-on-top window sized to the bar | Second borderless window, positioned by §3 | **Menu-bar item** `W 2` (always present). Click → sheet drops down under it |
| **Windows** | Same | Same | **System-tray icon** `W 2` (always present). Click → sheet opens above the taskbar, right-aligned. Ask once to keep it out of the `^` overflow |
| **Linux** | Same | Same | **Tray icon** in the top bar (StatusNotifier/AppIndicator). GNOME needs the AppIndicator extension; without it, hotkey + app only |
| **Android** | Overlay mini bar ("display over other apps"). If permission denied → notification + home widget | Overlay window | **Ongoing notification** (only while hidden): "Today · 2 left", next 2 tasks, actions **Add task · Show bar · Pause 1 h**; W in the status bar. Plus a **"Weave bar" quick-settings tile** |
| **iOS** | None (not allowed). Home / lock-screen widget styled like the bar | Main app opens straight to the note view | **Out of scope for now** (user, 2026-10-30) |
| **Web** | In-page bar, top-center by default | In-page sheet | — |

Desktop bar windows must be click-through outside the bar's shape.
The hide animation flies the bar into its tray spot (≈400 ms) and the tray icon gives one small pop — no repeated attention-grabbing.

---

## 6. Accessibility

- Bar: `role=button`, label "Open Weave", `aria-expanded`. Enter/Space toggles when focused.
- Every icon button has a label + tooltip (`‹` "Switch list", list name "Switch list").
- Check boxes say what they do: "Check Buy milk" / "Uncheck Buy milk".
- WCAG AA contrast for text in both themes; accent used for shapes, not for body text.
- Full keyboard flow: hotkey → type → Enter → Backspace/‹ → arrows (⏳ add arrow nav in lists list) → Esc.

---

## 7. Copy

- Short, lowercase-feeling, no exclamation marks.
- Placeholders say what happens: "Add a task…", "New list…".
- Empty list: "Nothing here yet. Type above and press Enter."
- Counts: "2 left"; zero: "All done".
- All strings go through l10n (NFR10).

---

## 8. Do / Don't

| Do | Don't |
|---|---|
| Keep the bar faded and small when idle | Pulse, bounce or animate the bar to get attention |
| Open straight into typing | Show a menu or home screen first |
| Let the user drop the bar anywhere they want | Force a fixed corner or snap it |
| Style bar and sheet from the same tokens | Give the bar its own colors or radius family |
| Use note color as an accent | Use more than one accent color at once |
| Reuse the same sheet on every platform | Design a different sheet per OS |

---

## 9. Full App

The full app is where lists are managed and edited at length. The mini bar + sheet stay the fast path; the app is the home.
Prototype: [`005-app`](../design/005-app/index.html) — switch platform (macOS, Windows, Linux, Android, iOS) and theme at the top.

Same tokens, type, palette, check circles, Done section and copy as the sheet. Only layout and window chrome change per platform.

### Layouts

| Width / platform | Layout |
|---|---|
| **Desktop** (macOS, Windows, Linux) and tablets ≥ 720 px | **Sidebar 252** · **list 680 max, centered** · **details panel 320** (slides in when a task is selected) |
| **Phone** (Android, iOS) | **Home** (cards) → **List** screen → **bottom sheets** for task details, share, more, color, menu |

```
Desktop                                                     Phone
┌──────────┬──────────────────────────────┬──────────┐      ┌─────────────────┐
│ W Weave ●Synced                         │ Task     │      │ ●Synced    🔍 ☰ │
│ [Search ⌘K]│ ● Today          📌 ▭ ⇪ ⋯ │ details  │      │ Weave           │
│ PINNED   │   4 left · On screen         │ Due      │      │ PINNED          │
│ ● Today 4│ [+ Add a task…          T ]  │ Remind me│      │ ┌─────┐┌─────┐  │
│ ● Weave 4│ ○ Pick up parcel             │ Repeat   │      │ │card ││card │  │
│ LISTS    │ │ Errands before 6pm         │          │      │ └─────┘└─────┘  │
│ ● Groc. 3│ ○ Reply to design review 🔔  │          │      │ LISTS ...       │
│ + New ⌘N │   📅 Tomorrow 17:00 · 1 h    │          │      │            (+)  │
│ Archive  │ ▸ Done · 1      Uncheck all  │          │      └─────────────────┘
│ Trash    │                              │          │      List screen: ‹ … title, tasks,
│ Settings │                              │ Delete   │      "Add a task…" pinned to the bottom
│ Local mode│                             │          │      (near the thumb / keyboard)
└──────────┴──────────────────────────────┴──────────┘
```

### Sidebar (desktop)

Brand + **sync status** (Synced · Syncing · Offline · Sync error, F2.5) · **Search** `⌘K` · **Pinned** lists · **Lists** · **New list** `⌘N` · footer: **Archive**, **Trash**, **Settings**, **account** card ("Local mode — Sign in to sync devices").
Rows: color dot · name · `▭` if on screen · open count. Drag to reorder (F8).

### List screen

- **Header:** color dot (opens palette) · **editable title** · actions: **Pin to top** · **Show on screen** (puts it in the mini bar; iOS: "Add to widget") · **Share** (text / Markdown / image, F11.1) · **More** (pin, show on screen, uncheck all, archive, delete).
- **Meta line:** "N left · On screen · edited just now".
- **Add row** at the top (desktop) / bottom (phone). `T` adds a **text line** (notes can mix text and tasks, F3.1).
- **Tasks are edited inline:** Enter = new task below · Backspace on empty = delete and go up · Tab / Shift+Tab = indent one level (F3.3) · drag grip to reorder (desktop) / long-press (phone).
- **Chips** under a task: 📅 due · 🔔 reminder · ↻ repeat. Tap a chip or the bell to open details.
- **Done section** with **Uncheck all** (reusable lists, F3.5).

### Task details (panel on desktop, bottom sheet on phone)

- Editable task text.
- **Due:** Today · Tomorrow · Next week · None; then time 9:00 · 13:00 · 17:00 · 20:00 (⏳ custom date/time picker).
- **Remind me:** with a due → At due time · 15 min / 1 h / 1 day before (move with the due, F4.2); always → in 1 h · in 2 h · Tomorrow 9:00 (timer / at-time); None.
- **Repeat:** Daily · Weekdays · Weekly · Monthly · Never (⏳ custom interval).
- Footer: **Delete task**.

### Phone home

Large "Weave" title · sync status · search · menu (Archive, Trash, Settings) · **Pinned** and **Lists** as **cards** (2 columns): color strip, name, first 3 open tasks, "N left · +N more", pin / on-screen icons · **FAB `+`** = new list (round on iOS, rounded-square on Android).

### Archive, Trash, Settings

- **Archive:** cards with Restore. "Hidden from your lists, not deleted."
- **Trash:** cards with "Deleted N days ago · empties in N days", Restore, Delete forever (F10).
- **Settings:** Appearance (theme) · Floating (desktop: mini bar on/off, idle opacity, hotkey, hide in full-screen; Android: overlay permission note, notification action; iOS: widgets, Live Activity) · Notifications (on/off, default snooze) · Account & sync (local mode, Continue with Apple / Google / email).
- App-level screens use Weave yellow as the accent; list screens use the list's color.

### Undo

Snackbar with **Undo** after check, delete task, uncheck all, archive and delete list (F10). 4 s, bottom center (above the add bar on phone).

### Platform chrome

| Platform | Chrome |
|---|---|
| macOS | Traffic lights, sidebar runs full height, `⌘` shortcuts |
| Windows | Title bar with logo + "Weave", min / max / close on the right, `Ctrl+` shortcuts |
| Linux (GNOME) | Header bar, centered title, round close button, `Ctrl+` shortcuts |
| iOS | Dynamic Island safe area, large title, home indicator, round FAB |
| Android | Status bar + punch-hole, gesture bar, rounded-square FAB, system back = `‹` |

### Keyboard (desktop)

`⌘K` search · `⌘N` new list · `Enter` / `Backspace` / `Tab` inline editing · `Esc` closes menus and details · `⌥Space` mini bar sheet · `⌘O` from the sheet opens the app.

---

## 10. Design Variations

Clickable mockups over a real desktop screenshot. Open [`docs/design/index.html`](../design/index.html) in a browser.

| ID | Name | Trigger | Status |
|---|---|---|---|
| [005](../design/005-app/index.html) | **Full app** | Desktop + phone layouts, all five platforms (§9) | **Draft** — awaiting review |
| [006](../design/006-tray/index.html) | **Hide to tray** | `⌄` sends the bar to menu bar / tray / notification; same sheet opens from there (macOS, Windows, Linux, Android) | **Draft** — awaiting review |
| [003](../design/003-mini-bar/index.html) | **Mini bar** | 40 px bar: grip · dot · name · "N left" · `⌥ Space`; same tokens as the sheet; free placement | **Chosen** 2026-10-30 |
| [004](../design/004-weave-bubble/index.html) | Weave bubble | 56 px W bubble, snaps to a side, half-tucks when idle | Not chosen — kept for reference (its sheet is the shared sheet) |
| 001 Bubble · 002 Edge tab | — | — | Removed 2026-10-30 (user) |

Shared code: `docs/design/assets/tokens.css` (all tokens) and `docs/design/assets/weave-sheet.{css,js}` = the sheet + drag/tap + keyboard; each page only adds its trigger (throwaway prototype, not app code).

**Naming:** new variations go in `docs/design/NNN-short-name/` with the next free number; never renumber.

Next: add the mini bar + sheet widgets to architecture-playbook §7, and resolve every ⏳ above.

---

## Decisions log

| Date | Decision | Reason |
|---|---|---|
| 2026-10-29 | Floating trigger inspired by mobile quick-launcher buttons, faded when idle | User direction |
| 2026-10-29 | Tap opens a small window straight into typing; back button goes to lists (switch / create) | User direction |
| 2026-10-29 | Inter, 6-color note palette | Architecture playbook + requirements F7 (designer's call) |
| 2026-10-29 | 004 sheet: input on top, newest first, round checks, collapsible Done, color strip | Designer's proposal; user liked it |
| 2026-10-30 | Finalists 003 Mini bar and 004 Weave bubble with the same sheet; 001 and 002 removed | User direction |
| 2026-10-30 | **Mini bar (003) chosen** | User choice |
| 2026-10-30 | Bar restyled with the sheet's tokens (surface, line, shadow, text, muted, field, color strip, 15/600 name, 40 px, radius 12); follows light/dark | User asked to match bar UI with its content UI |
| 2026-10-30 | UI word **"List"** for a note (was "project"); code stays `Note` | Requirements have no "project" (it's a non-goal); "list" fits "lists, checklists, reminders" (G4). User approved |
| 2026-10-30 | Sheet gets `⤢` + `⌘O` to open the full app on the same list | User asked for a way into the whole app |
| 2026-10-30 | **Hide to tray** (006): `⌄` / ⌘H hides the bar to macOS menu bar, Windows tray, Linux tray, Android notification; tray opens the same sheet | User idea. Matches F1.5 (one action hides all) and the requirements' menu-bar / tray fallbacks |
| 2026-10-30 | Hiding ≠ Do Not Disturb: hide keeps reminders; **Pause reminders** is a separate tray action | Designer's call — "DND" means silence on every OS; separate actions avoid surprise |
| 2026-10-30 | iOS left out of hide-to-tray for now; no Live Activity as a permanent tray | User direction; Live Activities are time-limited (~8 h) and meant for events |
| 2026-10-30 | Full app (005): sidebar + list + details on desktop/tablet; cards home + list + bottom sheets on phone; one design across 5 platforms, chrome differs | Designer's proposal, awaiting review |
| 2026-10-30 | Theme audit: old light-mode note colors were 1.6–2.8:1 as text and muted was 3.0:1 — failed AA. Split each color into fill + ink; solid muted per mode | Designer's audit; NFR accessibility |
| 2026-10-30 | One token file (`tokens.css`) for all prototypes; three directions (Glass, Paper, Woven) built in 007 for comparison | User asked to improve the theme |
| 2026-10-30 | **Woven chosen**: Woven colors, Inter, plain strip, solid strike, solid surfaces (no blur), radius sheet 12 / bar 10. Light and dark | User choice after comparing Glass, Paper, Woven |
| 2026-10-30 | Glass and Paper themes and the 007 comparison page removed; one theme only | User direction |
