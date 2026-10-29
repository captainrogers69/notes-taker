# Weave — Requirements

| | |
|---|---|
| **Status** | Draft v0.2 |
| **Owner** | Mayank Yadav |
| **Last updated** | 2026-10-29 |
| **App ID** | `com.rogers.weave` |

---

## 1. What Weave is

Weave is a simple notes, task and reminder app that is **always within reach** and **the same on every device**.

Notes behave like sticky notes: they float on screen above other apps, so a to-do list or reminder is one glance away instead of buried inside an app. Anything you change on one device appears on the others within seconds.

### Why

Task apps tend to fail in one of two ways:

1. **Out of sight, out of mind.** The list lives inside an app you have to remember to open.
2. **Too complex.** Projects, boards, labels and workflows turn a quick list into a chore.

Weave fixes both: notes stay visible, and the feature set stays deliberately small.

### Success looks like

- You jot a task on your phone and it is on your laptop's floating note before you sit down.
- You tick something off without opening an app.
- A new user understands the whole app in under 2 minutes.

---

## 2. Goals, non-goals, anti-goals

### Goals

- **G1.** Notes visible and accessible at all times (floating or widget, depending on platform).
- **G2.** Reliable, near-instant sync across all of the user's devices, including offline edits.
- **G3.** Fast capture: a new note or task in about 2 seconds.
- **G4.** A small, obvious feature set: lists, checklists, reminders, links.
- **G5.** Private by default: synced data is end-to-end encrypted, so the server cannot read it.
- **G6.** Fully useful without an account: floating notes, lists and reminders work locally on one device.

### Non-goals (v1)

- Live co-editing of a note with other people. Planned for later (F11.3); v1 data model must allow it.
- Rich documents: tables, embeds, file attachments, markdown editor.
- Project management: boards, Kanban, assignees, priorities, Gantt.
- Third-party integrations: calendars, Slack, email.
- AI features.

### Anti-goals (failure, even if it technically works)

- **Losing or silently overwriting a user's edit** during sync.
- **Being annoying**: floating notes that block content, can't be moved or hidden, or nag with notifications.
- **Getting complex**: if a feature needs a tutorial, it doesn't belong in v1.
- **Duplicate reminders**: the same reminder firing several times across devices after it was dismissed.

---

## 3. Users

**Primary user:** an individual who works across several devices (phone plus laptop/desktop) and wants personal tasks and reminders always visible.

**Usage pattern:** many short interactions a day (glance, tick, add) rather than long editing sessions.

---

## 4. Platforms

Weave is a Flutter app targeting Android, iOS, macOS, Windows, Linux and web. Platforms differ in what "floating" can mean:

| Platform | Floating notes | Glanceable fallback | Quick capture | Priority |
|---|---|---|---|---|
| **Android** | Overlay bubble or mini-note over other apps ("display over other apps" permission) | Home-screen widget | Widget, share sheet, notification action | P0 |
| **iOS** | **Not possible** (Apple forbids drawing over other apps) | Home-screen and lock-screen widgets; Live Activity for the next due item | Widget, share sheet | P0 |
| **macOS** | Borderless, always-on-top windows, one per pinned note | Menu-bar item | Global hotkey | P0 |
| **Windows** | Borderless, always-on-top windows | System-tray item | Global hotkey | P1 |
| **Linux** | Always-on-top windows (behavior varies by desktop environment) | Tray item where supported | Global hotkey where supported | P2 |
| **Web** | None | Normal tab | Keyboard shortcut in app | P2 |

P0 = launch platforms; P1 = soon after; P2 = best effort.

---

## 5. Features

Priority: **Must** = v1 launch, **Should** = v1 if time allows, **Could** = later.

### ⭐ Star features

#### F1. Floating sticky notes — Must

Notes can be "pinned to screen" so they stay visible above other apps.

- **F1.1** Any note can be pinned or unpinned from screen.
- **F1.2** Pinned notes can be dragged, resized and collapsed to a small handle or bubble.
- **F1.3** Size, position and collapsed state are remembered per device (not synced, since screens differ).
- **F1.4** Checklist items can be ticked and new items added directly on the floating note without opening the main app.
- **F1.5** One action hides or shows all floating notes.
- **F1.6** Floating notes never steal keyboard focus unless the user taps or clicks into them.
- **F1.7** On iOS, F1 is covered by widgets (F1-iOS below).

**F1-iOS. Widgets**

- Home-screen widget showing a chosen note or "next up" tasks; items can be ticked from the widget (interactive widgets, iOS 17+).
- Lock-screen widget showing the next reminder.
- Should: Live Activity for a reminder that is due today.

**Acceptance:** on macOS and Android, a pinned checklist stays visible while using another app, and ticking an item there is reflected on other devices within the sync target (NFR1).

#### F2. Sync across devices — Must

- **F2.1** Signed-in users see the same notes, tasks and reminders on every device.
- **F2.2** Changes reach other online devices within 3 seconds (p95).
- **F2.3** Everything works offline: create, edit, tick, delete. Changes sync automatically when back online.
- **F2.4** Concurrent edits never silently lose data. Edits to different fields or items merge; a true conflict on the same text keeps both versions and tells the user.
- **F2.5** A small indicator shows sync status: synced, syncing, offline, error.
- **F2.6** Deleting a note on one device deletes it everywhere (moves it to trash, see F10).
- **F2.7** All synced content is end-to-end encrypted (see section 6, Privacy and encryption). Because the server cannot read notes, merging happens on devices, not on the server.

**Acceptance:** edit the same checklist on two devices while one is offline; after reconnecting, both devices show all edits and nothing is lost.

### 👍 Good features

#### F3. Notes, lists and checklists — Must

- **F3.1** A note has a title (optional), and a body made of text blocks and checklist items.
- **F3.2** Checklist items can be checked/unchecked; checked items show strike-through.
- **F3.3** Items can be reordered by drag and indented one level (sub-items).
- **F3.4** Checked items can be collapsed to the bottom of the list or hidden.
- **F3.5** "Uncheck all" for reusable lists (e.g., packing, groceries).

#### F4. Reminders and schedules — Must

- **F4.1** A note or a single checklist item can have a **due date/time** and one or more **reminders**.
- **F4.2** Reminder types:
  - **At a time:** "Tomorrow 9:00".
  - **T-minus:** an offset before the due time, e.g. "1 day before", "1 hour before", "15 min before". Changing the due time moves its T-minus reminders with it.
  - **Timer:** "in 2 hours" from now.
- **F4.3** Repeat options: daily, weekdays, weekly, monthly, custom interval. T-minus reminders repeat with their due time.
- **F4.4** Reminders notify on every signed-in device that has notifications enabled.
- **F4.5** Notification actions: mark done, snooze (10 min, 1 hour, tomorrow), open.
- **F4.6** Done or snoozed on one device clears the notification on the others.
- **F4.7** Reminders fire even when the device is offline (scheduled locally on each device).
- **F4.8** Time zones: "at a time" and due times keep their clock time when the user changes time zone (9:00 stays 9:00 local). Timers ("in 2 hours") are a fixed moment and are not shifted.

#### F5. Linking with @ — Should

- **F5.1** Typing `@` in a note offers a search of other notes and checklist items; picking one inserts a link.
- **F5.2** Tapping a link opens the target note, scrolled to the item.
- **F5.3** Each note shows "Linked from" (backlinks).
- **F5.4** A link to a deleted note shows as broken rather than disappearing.

#### F6. Quick capture — Must

- **F6.1** Desktop: a global hotkey opens a small capture box from anywhere; Enter saves to a default note or a new note.
- **F6.2** Mobile: widget button and share sheet ("Share to Weave") create a note or add an item.
- **F6.3** Android: a persistent notification action "Add to Weave" (opt-in).
- **F6.4** Capture to save in under 2 seconds on a warm app.

#### F11. Sharing with other people — staged

Notes are personal; sharing with others is outward-only at first and grows in stages.

- **F11.1 Share out — Must (v1).** Share a note, or selected items, through the OS share sheet as plain text, Markdown, or an image of the sticky note. No account or server needed.
- **F11.2 Share link — Should (v1.1).** Create a read-only web link to a snapshot of a note. The decryption key lives only in the link's `#fragment`, which browsers never send to the server, so the link stays end-to-end encrypted. Links can expire and be revoked.
- **F11.3 Shared notes — Could (later).** Invite another Weave user to a note; both can edit and sync live. Each note has its own encryption key, which is shared with members' devices. The v1 data model must support per-note keys and note membership even though only the owner uses them.

### ✨ Small features

#### F7. Note colors — Must
A small fixed palette (6 to 8 colors) that works in light and dark mode.

#### F8. Pin and order — Must
Pin notes to the top of the main list; reorder notes by drag.

#### F9. Search — Must
Search titles, text and checklist items across all notes; works offline.

#### F10. Archive and trash — Must
- Archive hides a note without deleting it.
- Delete moves to trash; trash is emptied after 30 days.
- Undo snackbar after delete, archive and check actions.

### 🔧 Support features

#### S1. Account and sign-in — Must
- **Local mode (no account):** the full app works on one device: floating notes, lists, reminders, search, share out. Nothing leaves the device.
- Sign in with Apple, Google, and email (magic link or password) to turn on sync.
- Signing in later uploads existing local notes (encrypted).
- Sign out removes local data from that device after confirmation.
- Delete account and all data from within the app (required by App Store and Play Store).

#### S2. Offline mode — Must
Covered by F2.3 and F4.6; the app is fully usable with no network.

#### S3. Export and backup — Should
- Export all notes as JSON and as Markdown.
- Import from a Weave JSON export.

#### S4. Settings — Must
- Theme: light, dark, system.
- Notifications: on/off, default snooze, quiet hours (Should).
- Floating notes: default size, opacity, auto-hide in full-screen apps (desktop).
- Quick-capture hotkey and default target note.

#### S5. Plans and limits (monetization-ready) — Must (architecture only)
Pricing is undecided, so v1 ships with everything unlocked, but the app must be able to add paid tiers later without a rewrite.
- Every feature that could be limited (sync, number of devices, floating notes, share links, history) is checked through one **entitlements** service, never with scattered `if` checks.
- Limits and plan definitions come from server config, so they change without an app release.
- Hitting a limit never deletes or hides existing data; it only blocks adding more.
- Room for store purchases (App Store, Play Store) and a web/desktop payment provider.

---

## 6. Privacy and encryption

Users may store sensitive data (password hints, health, finances), so synced data is **end-to-end encrypted (E2EE)**: it is encrypted on the device and only the user's devices hold the keys.

- **E1.** Note content, titles, items, tags, links, colors and reminder times are encrypted before leaving the device. The server sees only opaque blobs plus minimal metadata (IDs, timestamps, sizes) needed to sync.
- **E2.** Each note has its own key (enables F11.3 later); note keys are wrapped by the user's account key.
- **E3.** Adding a new device requires either approving it from an existing device (e.g., scanning a QR code) or entering the recovery key.
- **E4.** A **recovery key** is shown once at setup for the user to save. Weave cannot recover data without it: losing every device and the recovery key means the synced data is gone (Q7).
- **E5.** Local data at rest is protected by the OS (Keychain/Keystore for keys; encrypted local database where available). Optional app lock with biometrics/PIN — Should.
- **E6.** Consequences accepted: no server-side search, no server-side merging, no server-generated notification text. Search and merging run on devices (already required for offline use); notifications are built on the device.

---

## 7. Non-functional requirements

| ID | Area | Requirement |
|---|---|---|
| NFR1 | Sync latency | p95 under 3 seconds between two online devices |
| NFR2 | Durability | No acknowledged edit is ever lost; local writes persist before UI confirms |
| NFR3 | Startup | Cold start to usable list under 2 seconds on a mid-range phone |
| NFR4 | Interaction | Tick, add and edit feel instant (local-first; UI never waits on network) |
| NFR5 | Scale | Smooth with 2,000 notes and 20,000 checklist items per user |
| NFR6 | Battery | Floating notes and sync add no noticeable battery drain when idle |
| NFR7 | Security | End-to-end encryption (section 6); TLS in transit; per-user data isolation; audited, standard crypto libraries only (no home-made crypto) |
| NFR8 | Privacy | No selling or ad-tracking of user data; minimal analytics, opt-out available |
| NFR9 | Accessibility | Screen-reader labels, dynamic text size, WCAG AA contrast, full keyboard use on desktop |
| NFR10 | Localization | English at launch; all strings externalized for later translation |

---

## 8. Constraints

- **Single codebase:** Flutter for all platforms; native code only where a platform feature requires it (overlays, widgets, global hotkeys).
- **iOS cannot float** over other apps; widgets and Live Activities are the substitute.
- **Android overlays** need the "display over other apps" permission, and the Play Store reviews its use; the app must work fully if the permission is denied.
- **Background limits:** mobile OSes restrict background work, so reminders must be scheduled locally rather than pushed only from a server.
- **Store rules:** in-app account deletion; privacy labels; Sign in with Apple required on iOS if other social logins are offered.
- **E2EE:** the backend can only store and relay encrypted data; any feature needing the server to read content is out of scope.
- **Minimum OS:** iOS 17, Android 8 (API 26), macOS 12, Windows 10.

---

## 9. Release scope

| Release | Contents |
|---|---|
| **MVP (v1.0)** | F1 (macOS + Android floating, iOS widgets), F2 with E2EE, F3, F4, F6, F7–F10, F11.1, S1 (incl. local mode), S2, S4, S5 (entitlements plumbing, all unlocked) on Android, iOS, macOS |
| **v1.1** | F5 linking, F11.2 share links, S3 export/import, Windows floating, iOS Live Activity, app lock |
| **Later** | F11.3 shared notes, Linux and web polish, paid plans, quiet hours, more languages |

---

## 10. Decisions and open questions

### Decided

| ID | Question | Decision |
|---|---|---|
| Q1 | Sharing with other people? | Personal-first. Staged sharing: share out (v1) → read-only E2EE links (v1.1) → shared notes (later). See F11. |
| Q2 | Use without an account? | Yes. Local mode has every non-sync feature, including floating notes. See S1. |
| Q3 | Free, paid, or freemium? | Undecided; v1 all unlocked, but entitlements built in from day one. See S5. |
| Q4 | Backend for sync and auth? | Must support E2EE: server stores and relays encrypted blobs only. Specific backend chosen in the architecture docs. |
| Q5 | Reminder time zones? | Clock times stay local (9:00 stays 9:00); timers are fixed moments; T-minus reminders added. See F4. |
| Q6 | Minimum OS versions? | iOS 17, Android 8 (API 26), macOS 12, Windows 10. |
| Q7 | Data recovery if a user loses all devices and the recovery key? | No server-held recovery: the data is lost. Recovery key only, with clear warnings at setup and periodic prompts to save it. May revisit later. |

### Open

None.

---

## 11. Glossary

| Term | Meaning |
|---|---|
| **Note** | The main unit: a title plus text blocks and/or checklist items, with a color |
| **Item** | One checklist line inside a note; can be checked, nested once, and have a reminder |
| **Pinned to screen** | A note shown as a floating window or bubble above other apps |
| **Pinned to top** | A note kept at the top of the main list (different from pinned to screen) |
| **Due time** | When a note or item is due; T-minus reminders are relative to it |
| **Reminder** | A scheduled notification attached to a note or an item: at a time, T-minus, or timer |
| **Link** | An `@` reference from one note to another note or item |
| **Local mode** | Using Weave without an account; data stays on one device |
| **E2EE** | End-to-end encryption: data is readable only on the user's own devices |
| **Recovery key** | A secret the user saves at setup; the only way to restore data without an existing device |
| **Entitlement** | A check of whether the current plan allows a feature or limit |
