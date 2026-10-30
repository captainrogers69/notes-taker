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
- **Header (note view):** back `‹` · list name with `▾` (both open lists) · "N left" / "All done".
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

### Color — note palette (F7)

| Token | Light | Dark (⏳ tune for AA) | Use |
|---|---|---|---|
| `yellow` | `#F5C84C` | `#E0B43A` | Default list |
| `blue` | `#6AA6F8` | `#5A93E0` | |
| `green` | `#5DC48A` | `#4DAF78` | |
| `pink` | `#EE7FA8` | `#D86C94` | |
| `purple` | `#A88BEB` | `#9478D6` | |
| `orange` | `#F29A5B` | `#DC874A` | |

- Note color appears as **accent only**: top strip (bar + sheet), dots, check fill, input focus ring, `+`.
- New lists cycle through the palette in order.
- Text on accent (check mark) is `#1B1B1B`. Never put white text on yellow/green.

### Surface tokens

| Token | Light | Dark | Used by |
|---|---|---|---|
| `surface` | white 92% + blur 28 | `#1E1E21` 90% + blur 28 | bar, sheet |
| `line` | black 8% (1 px inset) | white 10% (1 px inset) | bar, sheet |
| `shadow` | `0 24 60 / 35%` | `0 24 60 / 55%` | bar, sheet |
| `text` | `#1D1D1F` | `#F3F3F4` | |
| `muted` | black 42% | white 45% | meta, grip dots, placeholders, check outline |
| `field` | black 5% | white 7% | input, hotkey chip |
| `hover` | black 4.5% | white 6% | rows, icon buttons |

Follows the system light/dark setting (S4 can override).
Blur is a desktop/Android nicety. If the platform can't blur a floating window, use the surface color at 96% opacity.

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
- Radius: sheet 16 · bar 12 · input 10 · rows 9 · icon buttons & hotkey chip 8 · check circle 50%.
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

| Platform | Mini bar | Sheet |
|---|---|---|
| **macOS / Windows / Linux** | Borderless always-on-top window sized to the bar | Second borderless window, positioned by §3 |
| **Android** | Overlay mini bar ("display over other apps"). If permission denied → persistent notification action + home widget | Overlay window |
| **iOS** | None (not allowed). Home / lock-screen widget styled like the bar (dot · name · N left); tick from widget | Main app opens straight to the note view |
| **Web** | In-page bar, top-center by default | In-page sheet |

Desktop bar windows must be click-through outside the bar's shape.

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

## 9. Design Variations

Clickable mockups over a real desktop screenshot. Open [`docs/design/index.html`](../design/index.html) in a browser.

| ID | Name | Trigger | Status |
|---|---|---|---|
| [003](../design/003-mini-bar/index.html) | **Mini bar** | 40 px bar: grip · dot · name · "N left" · `⌥ Space`; same tokens as the sheet; free placement | **Chosen** 2026-10-30 |
| [004](../design/004-weave-bubble/index.html) | Weave bubble | 56 px W bubble, snaps to a side, half-tucks when idle | Not chosen — kept for reference (its sheet is the shared sheet) |
| 001 Bubble · 002 Edge tab | — | — | Removed 2026-10-30 (user) |

Shared code: `docs/design/assets/weave-sheet.{css,js}` = the sheet + drag/tap + keyboard; each page only adds its trigger (throwaway prototype, not app code).

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
