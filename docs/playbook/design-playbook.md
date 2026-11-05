# Weave — Design Playbook

How Weave looks and behaves. Follow this for every screen, widget and floating surface.
Source: [requirements.md](../requirements.md) + [architecture-playbook.md](architecture-playbook.md) + the locked prototypes in [`docs/design-02/`](../design-02/index.html).

> **Status: locked — [design 02](../design-02/index.html) (2026-11-05).** Mini bar + sheet, hide to tray, and the full app, in the "achromatic ledger" style. Build from design 02; when this playbook and the prototype disagree, the prototype wins and this file gets fixed.
> Design 01 ([`docs/design/`](../design/index.html), Woven theme, Inter) is superseded and kept for history only.
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
| **One family** | The bar is the sheet's collapsed form: same surface, shadow, type and list colour. |
| **Same everywhere** | Same sheet, words and colours on every platform. Only how the bar floats and the window chrome adapt to the OS. |
| **The chrome holds no colour** | The only hue on a screen is the list's own colour, on that list's things: its note paper, check fills and marks on the day thread. |


### Clutter rules (critical: apply to every screen)

Weave is glanced at dozens of times a day, so every extra word, label and control costs time on every glance. These rules came from the declutter study (2026-11-03, [`docs/design-02/declutter.html`](../design-02/declutter.html), review items D1–D13). Check every new or changed screen against them before review.

| # | Rule | Means | Example (study item) |
|---|---|---|---|
| C1 | **Say each fact once per screen** | Before adding a count, status or list, check whether the screen already shows it. If it does, keep the place where it is acted on and delete the other. | Overdue was in the header and leads the list (D1). The Lists card repeated the sidebar (D5). "In the mini bar" was in the subline and on the button (D11). The rail's Today strip and Reminders repeated the rows (D12). |
| C2 | **Header = date, title, one fact** | Date small above the title. Under it, one line with the single most useful fact: what's left and what's next. No sentence that strings every status together. | "4 left today · next Reply to design review at 17:00" (D1). |
| C3 | **Nothing between the title and the first task except one field** | One input. Enter adds, so there is no Add button. Choices with a sensible default (which list) sit inside the field as a small chip. Hints appear on focus, not permanently. | Field + dropdown + Add + helper line became one field with a list chip (D7). |
| C4 | **One place per action** | If two controls do the same thing on one screen, keep one. The add row lives at the end of the list. | The top add box and the ruled "Add a task…" area (D9). |
| C5 | **Order and style group rows; labels are the last resort** | Overdue rows come first with a red time and alert icon; done rows come last, struck through. Add a group heading only when order and style can't carry the grouping (large or mixed sets). | "Overdue / Still to do / Done today" for five rows (D4). |
| C6 | **No legend for labelled marks** | A key is only for marks that carry no label of their own. The screen-reader text keeps the full meaning. | The thread's Done / Due / Overdue legend (D6). |
| C7 | **One signal per number** | Show a number once, in one form: a count *or* a bar *or* a ring, never two side by side. | Sidebar count + progress bar (D13). |
| C8 | **A row is a title plus at most one meta line** | Secondary controls (chevron, grip, more) appear on hover, keyboard focus and selection. On touch, where there is no hover, the whole row is the target and those controls don't render. | The chevron on every row (D10). |
| C9 | **Truncated text means the wrong form** | If labels cut off at a width, don't shrink further. Switch to the compact form made for that width (the one-line strip, the label-free version), or let the text wrap. | The phone thread with "Reply to design…" labels became the one-line strip (D3). |
| C10 | **Columns fit their content at each width** | A column sized for the longest desktop value ("Tomorrow 10:00") must not hold that width where values are short. Size to content on the phone. On wide screens a list keeps a reading width (760 px) instead of stretching to the canvas, so each time stays near its task. | A 116 px time column cut "Pick up parcel from the locker" for "18:00" (D8). |
| C11 | **Chrome earns its row** | A bar or header that only repeats where you are goes. The tab bar already names the screen; the brand belongs on the sidebar and splash, not on top of every phone screen. | The phone's "Weave" logo row (D2). |
| C12 | **Every card does a job on this screen** | A card that only reads back settings or mirrors navigation belongs in Settings or nowhere. Fill the space it leaves with the screen's main job, not with a new card. | The "On screen" settings readout on Up next (D5). |

**Clutter check, before any review:**
1. Count the facts that appear twice on the screen (C1). The answer should be zero.
2. Count the controls above the first task (C3). The answer should be one.
3. Look for truncated text at phone, tablet and desktop widths (C9, C10).
4. For every heading, legend and label, ask whether order, colour or position already says it (C5, C6).
5. For every card, name its job in one verb (C12).
6. Judge the change **visually, side by side**: build the proposal behind a URL flag (as `#lean` was), with numbered markers on each change, and compare it with the current screen at desktop and phone width. Don't decide clutter from a written list.

---

## 1. Vocabulary

| User-facing word | Meaning in requirements / code | Notes |
|---|---|---|
| **List** | **Note** (requirements glossary): title + text blocks and/or checklist items + colour | UI says "List"; code and requirements keep `Note`. Never "project" — project management is a non-goal |
| **Task** | Checklist item | Placeholders say "Add a task…" |
| **Lists** | The main list of notes (F8) | A phone tab; the sidebar on desktop |
| **Up next** | Everything due today across lists, plus later this week | The screen the app opens on |
| **Day thread** | Today 07:00–23:00 drawn as one line with each due task as a mark | Design term; Weave's signature element |
| **Mini bar** | The floating trigger | Design term; users just see "Weave" |
| **Sheet** | The window the mini bar (or tray) opens | |
| **Show in mini bar** | Note shown floating (F1) | iOS: "Add to widget". Never just "pin" — "Pin to top" is different (F8) |

---

## 2. Anatomy

```
 Mini bar (idle 50%, drag anywhere; list colour as paper)
 ┌──────────────────────────────────────┐
 │ ⠿  ● Errands   4 left · 1 overdue    │  ← 40 px tall, width follows the text
 └──────────────────────────────────────┘
   8 px gap; sheet left-aligned to the bar (opens above if no room below)
 ┌──────────────────────────────────┐
 │ ● Errands ▾                ⌄  ⤢  │ ┐
 │ 4 left · next 17:00 Reply to…    │ │ header on the list's note paper
 │ 07 ━━━━━━━━│──●────○────── 23    │ │ one-line day thread (only if due today)
 │ ┌──────────────────────────────┐ │ │
 │ │ Add a task…                ↵ │ │ │
 │ └──────────────────────────────┘ │ │
 │ Times work too: 6pm, tomorrow…   │ ┘ parse line (height always reserved)
 │ ○ Pay electricity bill  ⚠ 09:00  │  overdue first, red + icon
 │ ○ Reply to design review   17:00 │  then by time
 │ ○ Buy milk                       │  then untimed, newest first
 │ › Done · 2                       │
 ├──────────────────────────────────┤
 │ ☁ Synced · 3 devices   ⌥ Space   │  footer
 └──────────────────────────────────┘
   Sheet 340 wide, up to 460 tall
```

### Mini bar

- **Grip** `⠿` (faint) · **colour dot** · **list name** (500, ellipsis after 150 px) · **meta** (muted).
- Meta is the one thing to know: "4 left · **1 overdue**" (red) → otherwise "4 left · next **17:00**" (next time today) → otherwise "4 left" → "All done". No hotkey chip, no colour strip.
- The bar's surface is the list's **note paper** (its colour mixed into the surface).
- Whole bar is the drag handle and the tap target. No buttons inside it.
- While the sheet is open the meta fades out (the sheet header says it, C1); the bar keeps its width.
- Name, count and colour update live as the user ticks, adds or switches list.

### Sheet

- **Header on note paper:** list switch (dot · name 16/500 · `▾`, opens the lists menu) · **hide** `⌄` · **open in app** `⤢`.
- **Subline:** one fact — "4 left · next 17:00 Reply to design review". Never the overdue count: the overdue row already leads the list in red (C1).
- **Day strip:** today 07–23 on one line, lived part in ink, this list's tasks due today as marks (filled = to do, red ring = overdue, hollow = done). Hidden when nothing on the list is due today.
- **Add field** (40 px), focused on open. Enter adds; no Add button. Under it a **parse line** whose height is always reserved: the hint "Times work too: 6pm, tomorrow, in 2 h" while empty and focused, the read-back ("Due Tomorrow 18:00") once you type.
- **Body:** the list's text lines, then open tasks in **time order** (overdue → by time → untimed newest first), times right-aligned, then a collapsed **Done · N**.
- **Lists menu** (from the name or Backspace in an empty field): dot · name · open count · ✓ on current, and a "New list…" field at the bottom. Enter creates the list and switches to it.
- **Footer:** opened from the bar → sync status ("Synced · 3 devices") + `⌥ Space`. Opened from the tray → **Show bar** (if hidden) + **Pause reminders 1 h** (→ "Paused till 17:20 · Resume").
- **No close button.** Close by tapping the bar, Esc, or clicking outside.

### Quick capture (sheet, app, Android notification)

The add field reads dates and times as you type: today, tonight (20:00), tomorrow, weekday names, 18:00, 6pm, 6:30pm, in 2 h, in 30 min. A time already past today means tomorrow. The read-back appears under the field before Enter.

---

## 3. Interaction Rules

| Action | Behavior |
|---|---|
| **Tap / click bar** | Toggle sheet. Opens on the current list with the field focused |
| **Drag bar** | Moves it freely. Movement under **5 px** counts as a tap. Dragging closes an open sheet |
| **Drop bar** | Stays where dropped, clamped 12 px inside the screen. No snapping |
| **Arrow keys on focused bar** | Move it 16 px (Shift: 64 px). Keyboard alternative to dragging (WCAG 2.5.7) |
| **Move to corner** (sheet footer) | One-click alternative to dragging: next corner, clockwise |
| **Sheet position** | 8 px below the bar, left edges aligned (clamped); above the bar when there's no room below |
| **Enter in field** | Add task / create list. Empty field does nothing |
| **List name / Backspace on empty field** | Opens the lists menu; ↑ ↓ move through it; Esc closes it |
| **`⤢` / `⌘O` (Ctrl+O)** | Closes the sheet and opens the app on the same list |
| **`⌄` / `⌘H` (Ctrl+H)** | **Hides the bar** to the menu bar / tray / notification (§5). Reminders keep ringing |
| **Click tray icon** | Opens the **same sheet** under / above it, with the tray footer. Click again / Esc / outside closes |
| **Show bar** (tray footer, notification action, Android tile) | Bar flies back to where it was |
| **Pause reminders** | Separate from hiding. 1 h, then resumes on its own. Tray icon dims while paused |
| **Esc / click outside** | Close sheet |
| **Global hotkey** (`⌥ Space` default, S4) | Toggle sheet from anywhere (desktop) |
| **Tick** | Fill, fade, rows close up (§4). Ticking a done item unticks it |

Rules:

- **Focus (F1.6):** the bar never takes keyboard focus on its own. The sheet takes focus only when the user opens it.
- **Position is per device** (F1.3): bar position is saved locally, never synced.
- Reopening always lands on the current list, not wherever it was left.
- In the app every destructive or bulk action shows an **Undo** toast (F10); in the sheet, unticking is the undo for ticks.

---

## 4. Visual Language

Bar, sheet, tray and app share **one token file**: [`docs/design-02/assets/tokens.css`](../design-02/assets/tokens.css). Never hard-code a colour in a component.

### Style — achromatic ledger (locked 2026-11-05)

Dealt by the taste skill's app draw (seed `686191426`) and adopted whole.

- Neutral, low-chroma chrome; **solid surfaces, no blur**.
- **One near-black primary button per screen** (white label). Everything else is secondary (grey fill), ghost or danger.
- **Light and dark are both complete.** The app follows the system unless the user picks one (S4); light is the reference mode the screens are designed in first.
- **1 px borders**; **shadows only on what floats** (bar, sheet, menus, toast, phone sheet). Cards never get a shadow.
- **Note paper:** a list's colour mixed into the surface (22% light, 16% dark) marks "this is the note". Used on the bar, the sheet header, a list's task card, list tiles, and the sidebar row of the list in the mini bar. Nowhere else.

### Colour — note palette (F7)

| Token | Fill (all modes) | Ink, light mode | Name |
|---|---|---|---|
| `n0` | `#F5C84C` | `#876508` | Yellow (default list, Weave brand) |
| `n1` | `#6AA6F8` | `#0B65E0` | Blue |
| `n2` | `#5DC48A` | `#2C784D` | Green |
| `n3` | `#EE7FA8` | `#CD1B5D` | Pink |
| `n4` | `#A88BEB` | `#794CE0` | Purple |
| `n5` | `#F29A5B` | `#AC4F0E` | Orange |

- **Fill vs ink.** `--nX` is the fill: dots, check fill, thread marks, paper. `--nX-ink` is the edge and text-safe shade (≥ 3:1 for marks, ≥ 4.5:1 as text). In dark mode ink = fill.
- A component sets `--accent` / `--accent-ink` (or `--c` / `--ci`) to one pair; children use only those.
- App-level screens (Up next, Settings, Archive) use yellow; a list screen uses its list's colour.
- The tick mark on a fill is `#111`. Never white on yellow or green.
- New lists cycle through the palette in order. Purple stays: it is a user-chosen list colour, not a UI accent.

### Neutral tokens

| Token | Light | Dark | Use |
|---|---|---|---|
| `ground` | `#f5f5f3` | `#0f0f0f` | Page / canvas |
| `surface` | `#ffffff` | `#171717` | Cards, bar, sheet |
| `raised` | `#eeeeee` | `#262626` | Secondary button, active nav row, selected row |
| `hover` | `#f3f3f2` | `#1f1f1f` | Row hover |
| `border` / `rule` | `#e6e6e6` / `#f0f0f0` | `#2a2a2a` / `#212121` | Card edge / row divider |
| `control` | `#d4d4d4` | `#444444` | Field and check outlines, thread axis |
| `text` | `#0a0a0a` | `#f2f2f2` | |
| `muted` | `#5f5f5f` | `#b4b4b4` | Meta, times (6.4:1 on white) |
| `faint` | `#6b6b6b` | `#949494` | Placeholders, grip, kbd hints |
| `primary` / `on-primary` | `#141414` / `#fff` | `#f2f2f2` / `#0a0a0a` | The one filled button, toast |
| `negative` | `#c4242a` | `#ef6b6b` | Overdue, delete |
| `float-shadow` | `0 12 32 rgba(0,0,0,.14)` + 1 px ring | `0 16 40 rgba(0,0,0,.6)` + 1 px ring | Only on what floats |

`text`, `muted` and `faint` meet 4.5:1 on ground and surface in both modes.

### Typography — Geist

**Geist**, weights **400 and 500** only (no bold), bundled with the app. Fallback: Inter, then the system UI font. **Tabular figures on every time and count.** No monospace face: hotkeys are set in Geist.

| Role | Size / weight |
|---|---|
| Screen title (h1) | 24 / 500, −0.01em |
| Card title, sheet list name | 16 / 500 |
| Body, tasks, fields | 14 / 400 |
| Meta, times, sublines, buttons | 13 / 400 (buttons 500) |
| Kbd hints, day-strip hours, fine print | 12 / 400 |
| Phone tab labels | 11 (iOS) / 12 (Android), 500 |

Respect the OS text scale; the sheet grows in height, never clips text (NFR9).

### Shape & spacing

- Radius: **cards, bar, sheet, menus 8** · **controls (buttons, fields, rows) 6** · chips 4 · checks 50% · phone sheet 16 (top corners).
- 4 px grid. Card padding 20, grid gap 12, page padding 24–32.
- Heights: row **44** · control 36 (small 30) · field 40 (phone add bar 44) · bar **40**.
- Sheet **340 wide, up to 460 tall**; header and footer fixed, the list scrolls.
- Sidebar 256 (224 under 1100 px).
- **Tick:** an 18 px circle inside a 24 px target on desktop (WCAG 2.5.8), 44 px on phones and in the Android notification.
- **Overdue** is always red **plus** an alert icon, never colour alone.

### Opacity (the "faded" look)

| Bar state | Opacity |
|---|---|
| Idle | **50%** |
| Hover / focus / dragging / sheet open | 100% |
| Full-screen app in front (desktop, S4) | hidden |

User setting "Opacity when idle" (S4, 20–100%) replaces the idle value; Settings shows a live preview of the bar.

### Motion

Weighting: restraint first (a productivity tool used dozens of times a day), production polish second, play only for rare moments. Source: the motion audit of 2026-11-03 (`motion-audits/notes-taker-2026-11-03.html`, M1–M12), as built in `docs/design-02`.

**Tokens** (`tokens.css`); every transition uses these, never the browser's default `ease`:

| Token | Value | Use |
|---|---|---|
| `--dur-fast` | 120 ms | Exits, tick fill and fade |
| `--dur` | 180 ms | Enters, menus, row slides, expanding sections |
| `--ease-out` | `cubic-bezier(.23, 1, .32, 1)` | Everything on screen, entering and leaving |
| `--ease-sheet` | `cubic-bezier(.32, .72, 0, 1)` | Phone bottom sheets only (iOS sheet curve) |

Named exceptions, longer because they travel further: the bar's flight to the tray (260 ms) and the phone sheet (280 ms).

| Event | Motion |
|---|---|
| Sheet open (click) | Fade in over 180 ms; scale .96 → 1 with a 6 px slide from the bar's side over 200 ms; transform-origin at the bar |
| Sheet open (⌥ Space / Enter) | Instant: keyboard-triggered UI never animates |
| Sheet close | 120 ms fade at scale .99, no slide back |
| List switcher, Share, More, Colour menus | Grow from their trigger: opacity + scale .97 with a 4 px drop, 180 ms; close with a 100 ms fade. Instant when opened or closed from the keyboard |
| Bar hover / focus | Opacity 50 % → 100 % over 180 ms |
| Bar drag | Scale 1.03 while held |
| Tick | Circle fills and text strikes through (120 ms), the row fades (120 ms), then the rows below slide up (180 ms, FLIP). Quick successive ticks never cancel each other |
| New item | Accent highlight fading out over 600 ms |
| Typing in the sheet | The parse line under the field keeps its height whether shown or not, so the list never nudges |
| "Done · n" section | Opens and closes with its chevron: rows grow from 0 to full height over 180 ms (`grid-template-rows`) |
| Toast | Rises 16 px and fades in (200 ms); leaves with a 150 ms fade, no drop |
| Phone bottom sheet | Slides up over 280 ms on `--ease-sheet`; slides down over 200 ms with its content still showing. Edits inside an open sheet don't replay the motion. The scrim fades with it |
| Hide to tray | The bar flies into the tray icon with transform + opacity only (translate + scale .4, 260 ms); its position is never animated. Showing it reverses the flight |
| Tray icon | One pop to 1.12 over 240 ms when the bar arrives; never repeats |
| Day's last tick | Ink runs along the rest of today's thread (600 ms) and fades by 1 s. Once a day, only when the thread is on screen |
| First run | The bar unrolls rightward from its colour dot (420 ms), then the name and count fade in. Once ever |

Rules:
- **Exits are faster and simpler than enters.** A fade, no reverse slide.
- **Keyboard-triggered UI is instant.** That covers the hotkey, Enter, Space, Escape and Backspace.
- **Animate transform and opacity only.** Never `left`, `top`, `width` or `height` (the Done section's grid-row growth is the one exception).
- **Re-renders must not snap or replay motion.** Start from the state last drawn, then change after a reflow.
- **Never depend on `transitionend` alone.** Always pair it with a fallback timer.
- **Delight is rare.** Only the day's last tick and the first run get expressive motion, and each plays at most once a day or once ever.

Respect reduce-motion: all durations → 0. The day's-last-tick stroke and the first-run unroll are skipped entirely.


---

## 5. Platform Mapping

| Platform | Mini bar | Sheet | When hidden (`⌄`) |
|---|---|---|---|
| **macOS** | Borderless always-on-top window sized to the bar | Second borderless window, positioned by §3 | **Menu-bar item**: the W mark and the open count. Click → the sheet drops down under it, right-aligned |
| **Windows** | Same | Same | **System-tray icon** with the count. Click → the sheet rises above the taskbar, right-aligned. Ask once to keep it out of the `^` overflow |
| **Linux** | Same as macOS | Same | **Tray icon** (StatusNotifier/AppIndicator), behaves as macOS. GNOME needs the AppIndicator extension; without it, hotkey + app only. Not prototyped |
| **Android** | Overlay mini bar ("display over other apps"). If permission denied → notification + home widget | Overlay window | **Ongoing notification, only while hidden:** list name, "4 left · 1 overdue", the next two timed tasks with tick buttons and times, actions **Add task** (inline reply field that parses times) · **Show bar** · **Pause 1 h**. Plus a **"Weave bar" quick-settings tile** |
| **iOS** | None (not allowed). Home / lock-screen widget styled like the bar | The app's list screen | **Out of scope for now** (user, 2026-10-30) |
| **Web** | In-page bar, top-centre by default | In-page sheet | — |

Desktop bar windows must be click-through outside the bar's shape.
Hiding flies the bar into its tray spot and the tray icon pops once (§4 Motion). No repeated attention-grabbing.

---

## 6. Accessibility

- Bar: `role=button`, label "Open Weave. Arrow keys move the bar.", `aria-expanded`. Enter/Space toggles when focused; arrow keys move it; **Move to corner** in the sheet is the one-click alternative to dragging (WCAG 2.5.7).
- Sheet: `role=dialog`, labelled "Weave: *list name*". Lists menu is `role=menu` with `menuitemradio` rows.
- Every icon button has a label and tooltip with its shortcut ("Hide to menu bar (⌘H)", "Open in Weave (⌘O)").
- Checks say what they do: "Check Buy milk" / "Uncheck Buy milk". Targets 24 px desktop, 44 px touch.
- Overdue = red **and** an alert icon. Colour swatches are named (Yellow, Blue…), not numbered.
- The day thread and strip carry a full text label ("Today: 09:00 Pay electricity bill (overdue), …. Now 16:20.").
- The parse line is `aria-live="polite"`; the toast is `role=status`.
- WCAG AA contrast in both modes, checked by script. Visible focus ring: 2 px in `text` colour.
- Reorder rows without dragging: Alt+↑ / Alt+↓, or Move up / Move down in task details.
- Reduce motion: see §4 Motion.
- ⏸ The idle bar at 50% opacity can fall below 4.5:1 over busy wallpapers. Accepted: the opacity setting goes to 100% (review B6).

---

## 7. Copy

- Short, plain, no exclamation marks. Say the fact, not the feature.
- Placeholders say what happens: "Add a task…", "New list…". Up next's field: "Add a task… try “dentist fri 10am”".
- Counts: "4 left"; zero: "All done". Next: "next 17:00" (bar), "next Reply to design review at 17:00" (screens).
- Times: 24-hour, tabular. "17:00" today, "Tomorrow 10:00", "Fri 6 Nov".
- Empty list: "Nothing here yet. Type above and press Enter." (sheet) / "…Type below…" (app list, field at the end).
- Toasts name the thing and offer Undo: “Checked "Buy milk"” + Undo, "Archived Errands  Undo".
- All strings go through l10n (NFR10).

---

## 8. Do / Don't

| Do | Don't |
|---|---|
| Keep the bar faded and small when idle | Pulse, bounce or animate the bar to get attention |
| Open straight into typing | Show a menu or home screen first |
| Let the user drop the bar anywhere | Force a fixed corner or snap it |
| Style bar, sheet and app from the same tokens | Give the bar its own colours or radius family |
| Put colour only on the list's own things (paper, checks, marks) | Colour the chrome, or use two list colours as accents at once |
| Order rows to group them (overdue → time → done) | Add group headings and legends the order already says (C5, C6) |
| Reuse the same sheet on every platform | Design a different sheet per OS |
| Use one primary button per screen | Add shadows to cards, gradients or tinted icon squares |

---

## 9. Full App

The app is where lists are managed and edited at length. The mini bar + sheet stay the fast path.
Prototype: [`03-app`](../design-02/03-app/index.html) — switch platform (macOS, Windows, iOS, Android) and theme at the top.

Same tokens, type, palette, checks, Done section, quick capture and copy as the sheet. Only layout and window chrome change per platform.

### Layouts

| Width / platform | Layout |
|---|---|
| **Desktop** (macOS, Windows, Linux) and tablets ≥ 720 px | **Sidebar 256** · **canvas** (12-column grid, gap 12). A list keeps a **760 px reading width**; task details open beside it (8 + 4 columns) when a task is selected |
| **Phone** (Android, iOS) and < 720 px | **Bottom tab bar** (Up next · Lists · Search · Settings) · screen · **add bar pinned above the tabs** (Up next and list screens) · **bottom sheets** for task details, share and more |

```
Desktop                                                       Phone
┌────────────┬────────────────────────────────────────────┐   ┌───────────────────┐
│ W Weave    │ Tue 3 Nov                                  │   │ Tue 3 Nov         │
│ Synced     │ Up next                                    │   │ Up next           │
│ Search  K  │ 4 left today · next Reply… at 17:00        │   │ 4 left today · …  │
│ Up next  4 │ ┌ Today's thread ───── 07:00 to 23:00 ┐    │   │ ┌ Today ─────────┐│
│ PINNED     │ │ labels over marks on the day line   │    │   │ │ 07 ━━│─●──○ 23 ││
│ Errands  4 │ │ ━━━━━━━━━━━━━│──●────●──────○──   │    │   │ │ o Pay bill ! 09││
│ LISTS      │ └─────────────────────────────────────┘    │   │ │ o Reply…  17:00││
│ Grocery  3 │ ┌ Today ───────────────┐ ┌ Later ───────┐  │   │ └────────────────┘│
│ + New list │ │ [Add a task… Errands]│ │ o Dentist Fri│  │   │ ┌ Later this week┐│
│            │ │ o Pay bill   ! 09:00 │ │ o Rent   Mon │  │   │ └────────────────┘│
│ Archive    │ │ o Reply…       17:00 │ └──────────────┘  │   │                   │
│ Settings   │ │ x Buy milk           │                   │   │ [Add a task…    ] │
│ MY Mayank  │ └──────────────────────┘                   │   │ Up Lists Find Set │
└────────────┴────────────────────────────────────────────┘   └───────────────────┘
```

### Sidebar (desktop)

Brand (W mark + "Weave") · **sync line** (Synced · 3 devices / Syncing… / Offline · changes saved here / Sync error · retrying, F2.5) · **Search** `⌘K` · **Up next** with today's open count · **Pinned** · **Lists** · **New list** `⌘N` · footer: **Archive and trash** (count), **Settings**, account row ("End-to-end encrypted").
List rows: colour dot · name · screen icon if in the mini bar · open count. **Counts only, no progress bars** (C7). The list in the mini bar sits on its note paper.

### Up next (the app opens here)

- **Header (C2):** date small above, **Up next**, then one fact: "4 left today · next Reply to design review at 17:00".
- **Desktop:** the **day thread** card full width (07:00 to 23:00; lived part in ink; the rest of today shaded; each due task a mark in its list's colour with its label above; overdue = red ring + "!" label; done = hollow; close marks share a label "+1"). Below it, **Today** (8 columns) and **Later this week** (4 columns, count in its header). The two cards end at different heights on purpose (C12).
- **Today card:** the one add field first (list as a chip inside it; hint on focus), then one list: overdue, upcoming, done (struck through). No group labels (C5). A row shows its list name only when today spans more than one list.
- **Phone:** title, then the Today card with the one-line day strip in place of the thread (C9), then Later this week. The add field is the add bar at the bottom.

### List screen

- **Title row:** colour dot (opens the colour menu) · **editable title** · subline "4 left · next Reply to design review at 17:00" (C2; no overdue count, no "edited"). Actions: **Show in mini bar** (pressed: "In mini bar"; iOS: "Add to widget") · **Share** (Copy as text · Copy as Markdown · Share as image…, F11.1) · **•••** (Pin to top · Archive · Delete list… · "Edited …" note).
- **Task card on note paper**, 760 px reading width. Rows: grip (hover) · check · inline-editable text · chips (🔔 reminder, ↻ repeat, due time) · details chevron on hover/focus only (C8). Text lines (F3.1) sit between tasks.
- **Add row at the end of the list** ("Add a task…", Enter adds and stays for the next one). Phone: the add bar at the bottom instead.
- **Inline editing:** Enter = new task below · Backspace on empty = delete and go up · Tab / Shift+Tab = indent one level (F3.3) · Alt+↑ / ↓ or drag the grip = reorder (phone: long-press).
- **Done · N** footer with **Uncheck all** (reusable lists, F3.5). Uncheck all lives only here.
- **Phone:** back (iOS: "‹ Lists"; Android: ← arrow) · Share · •••; ••• opens a sheet with Show in the bar, Pin to top, Colour swatches, Archive, Delete and "Edited …".

### Task details (panel on desktop, bottom sheet on phone)

- Header "Task · in *list*" with close (desktop). Editable task text.
- **Due:** Today · Tomorrow · Next Mon · None; then 09:00 · 13:00 · 17:00 · 20:00 (⏳ custom date/time picker).
- **Remind me:** with a due → At due time · 15 min / 1 h / 1 day before ("Before" reminders move with the due time, F4.2); always → In 1 h · Tomorrow 09:00 · None.
- **Repeat:** Daily · Weekdays · Weekly · Monthly · Never (⏳ custom interval).
- **Order:** Move up · Move down. Footer: **Delete task** (Undo toast).

### Archive and trash

One screen, two cards. "Archived lists are hidden, not deleted. Trash empties itself after 30 days."
Archive rows: dot · name · "7 items · Archived 28 Oct" · Restore. Trash rows: "Deleted 2 days ago · empties in 28 days" · Restore · **Delete forever** (Undo toast).

### Search

Desktop: the sidebar field (`⌘K`) turns the canvas into results: matches highlighted, each with its list. “N results for "x" across 6 lists. Works offline.” Phone: the Search tab.

### Settings

Saved as you change them. One row per section: heading + one-line description on the left, controls on the right.
- **Appearance:** System · Light · Dark.
- **Mini bar** (iOS: **Widgets**): Show the mini bar (Android: needs "Display over other apps", else notification + widget) · Opacity when idle (20–100%, live bar preview) · Quick-capture hotkey `⌥ Space` · Hide in full-screen apps.
- **Notifications:** Reminders on/off · Default snooze 10 min / 1 hour / Tomorrow.
- **Account and sync:** devices table (device, last seen) · Recovery key (Show again) · Add a device (Show code) · Sign out.
- **Delete account** (danger zone; type your email to confirm).

### Undo

Toast with **Undo** after check, delete task, uncheck all, archive list, delete list and delete forever (F10). 4 s, bottom centre (above the add bar on phone), on the primary colour.

### Platform chrome

| Platform | Chrome |
|---|---|
| macOS | Traffic lights, sidebar runs full height, `⌘` shortcuts |
| Windows | Title bar with W mark + "Weave", min / max / close on the right, `Ctrl+` shortcuts |
| Linux | ⏳ Not prototyped. Use the desktop layout with the system's own title bar, `Ctrl+` shortcuts |
| iOS | Dynamic Island safe area, iOS tab bar (filled icon for the current tab), back = "‹ Lists", home indicator |
| Android | Status bar, Material tab bar (pill behind the current icon), back = ← and the system back gesture, gesture bar |

No floating action button on any platform: the add bar is always at the thumb.

### Keyboard (desktop)

`⌘K` search · `⌘N` new list · `Enter` / `Backspace` / `Tab` / `Alt+↑↓` inline editing · `Esc` closes menus, details and phone sheets · `⌥ Space` mini bar sheet · `⌘O` from the sheet opens the app · `⌘H` from the sheet hides the bar.

---

## 10. Prototypes

Clickable prototypes over a real desktop screenshot. Open [`docs/design-02/index.html`](../design-02/index.html) in a browser.

| ID | Name | What it shows | Status |
|---|---|---|---|
| [01](../design-02/01-mini-bar/index.html) | **Mini bar and sheet** | Bar, sheet, quick capture, lists menu, move, first-run unroll (`#first`) | **Locked** 2026-11-05 |
| [02](../design-02/02-tray/index.html) | **Hide to tray** | macOS menu bar, Windows tray, Android notification + tile | **Locked** 2026-11-05 |
| [03](../design-02/03-app/index.html) | **Weave app** | Up next, list, details, archive and trash, search, settings; desktop + phone, 4 platforms | **Locked** 2026-11-05 |
| [declutter](../design-02/declutter.html) | Declutter study | Before / after for D1–D13, with markers | Reference |
| [review.md](../design-02/review.md) | Review log | Round 1 findings, motion audit M1–M12, declutter D1–D13, E1–E9 | Reference |

Shared code: `assets/tokens.css` (all tokens), `assets/data.js` (sample data, quick-capture parser, checks), `assets/icons.js` (one outline icon set + the W mark), `assets/weave.{css,js}` (bar + sheet, shared by 01 and 02). Throwaway prototype code, not app code.

Design 01 ([`docs/design/`](../design/index.html): 003 mini bar, 004 bubble, 005 app, 006 tray; Woven theme) is **superseded** by design 02 and kept for history.

**Changing a locked design:** propose the change behind a URL flag in the prototype, compare it side by side with the current screen (as the declutter study did), run the clutter check (§0), and log the decision below before editing this playbook.

Open design work is tracked in [`docs/design/design-checklist.md`](../design/design-checklist.md). Resolve every ⏳ above.

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
| 2026-11-03 | **Clutter rules applied to the whole UI** (design-02, D1–D13 and E1–E6). List screen has no side panel: colour on the title dot, Pin in ••• (C4, C12). Sidebar shows counts only (C7). The list keeps a 760 px reading width | User: "let's follow this updated design playbook on the whole UI"; D12 and D13 decided by the rules |
| 2026-11-03 | **Motion table rewritten** to the audited values: `--dur-fast` 120 / `--dur` 180 / `--ease-out` tokens, instant keyboard UI, fade-only exits, FLIP tick, 260 ms tray flight, two once-only delights | Motion audit M1–M12 (2026-11-03) fixed and verified in design-02; the old table (280 ms tick, 1 s highlight, `cubic-bezier(.2,.8,.2,1)`) no longer matched |
| 2026-11-03 | **Clutter rules C1–C12** added to §0 and made mandatory for every screen, with a clutter check before review | Declutter study against a before/after reference (design-02 `declutter.html`, D1–D13). User: "these are very critical" |
| 2026-11-05 | **Design 02 locked** and this playbook synced to it: achromatic ledger style, **Geist** (400/500, tabular figures) replaces Inter, light default, radius 8 / 6, no colour strip (list colour as note paper), sheet in time order with quick-capture parsing, lists menu instead of a sideways slide, app opens on Up next with the day thread, phone tab bar + bottom add bar instead of cards home + FAB, archive and trash on one screen. Design 01 superseded | User: "we are locking the design-02" |
