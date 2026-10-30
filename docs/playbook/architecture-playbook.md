# Weave — Architecture Playbook

How we build in this project. Follow these for every feature and fix.
Source: [requirements.md](../requirements.md) (Draft v0.2) + team principles.

> **Pending inputs.** This playbook was written before `principles.md` and the backend choice were available.
> Sections marked **⏳ Pending** get filled in when those land. Everything else is binding now.
>
> - `principles.md` — team principles (exact DI, helper, enum and widget conventions may be refined).
> - **Backend** (auth, blob store, realtime relay, entitlement config) — undecided (requirements Q4). The Flutter app talks to it only through the interfaces in §4 and §10.2, so the choice does not change any feature code.

---

## 0. Project Snapshot

| | |
|---|---|
| **App** | Weave (`com.rogers.weave`) |
| **Platforms** | Android, iOS, macOS = P0 · Windows = P1 · Linux, web = P2. Min OS: iOS 17, Android 8 (API 26), macOS 12, Windows 10 |
| **API type** | ⏳ Pending (backend undecided). App-facing contract: `SyncTransport` + `AuthGateway` interfaces |
| **Auth** | Optional. Local mode (no account) is a full app. Sign in with Apple, Google, email (magic link / password) turns on sync |
| **Realtime** | Yes — changes reach other online devices in < 3 s p95 (NFR1). Transport ⏳ Pending |
| **Offline** | Local-first. Everything works offline; local DB is the source of truth. Drift + SQLCipher |
| **Encryption** | End-to-end. Per-note keys wrapped by account key; server sees opaque blobs only |
| **Native code** | Android overlay, iOS/Android home-screen widgets, desktop always-on-top windows, global hotkeys, tray/menu-bar |
| **Flavors** | `dev`, `prod` |
| **Typography** | Inter (bundled, works offline) |
| **Localization** | English at launch; all strings externalized (ARB) |

---

## 1. Feature Map

Release: **v1** = MVP, **v1.1**, **later** (requirements §9).

| Feature | Release | State tool | Why | API | Shared parts |
|---|---|---|---|---|---|
| `notes` — list, pin to top, order, color (F3 list, F7, F8) | v1 | `Cubit` | Streams from DB + a few intents (reorder, pin, color); no event history needed | Sync | `NoteCard`, `NoteColor` enum, `NotesRepository` |
| `note_editor` — blocks, checklist, indent, reorder, collapse, uncheck all (F3) | v1 | `Bloc` | Many distinct events, undo stack, debounced persistence → event transformers | Sync | `ChecklistItemTile`, `StrikeText` |
| `floating_notes` — pin to screen, drag/resize/collapse, hide all (F1) | v1 (macOS, Android) · v1.1 Windows · later Linux | `Cubit` per window | Each window shows one note stream + tick/add; geometry is local-only | Sync (via notes) | Reuses `ChecklistItemTile` |
| `glance_widgets` — iOS/Android home & lock-screen widgets, Live Activity (F1-iOS) | v1 · Live Activity v1.1 | none (core `WidgetBridge`) | No Flutter UI; native widget reads a snapshot | none | — |
| `sync` — status indicator (F2) | v1 | `Cubit` (`SyncStatusCubit`, global) | Single enum-like status from `SyncEngine` stream | Sync | `SyncStatusBadge` |
| `reminders` — due, at-time / T-minus / timer, repeat, snooze (F4) | v1 | `Cubit` | Reminder editor form with derived preview text | Sync | `ReminderChip`, `DueDateText`, `RepeatRule` |
| `search` (F9) | v1 | `Cubit` | Query → FTS results; debounce in hook on the field | none (local FTS) | Reuses `NoteCard` |
| `archive_trash` (F10) | v1 | `Cubit` | List + restore/delete intents | Sync | `UndoSnackBar` |
| `quick_capture` — hotkey box, share-in, notification action (F6) | v1 | hooks | One text field + one use case call; must be < 2 s | Sync (via notes) | — |
| `share_out` — text / Markdown / image (F11.1) | v1 | hooks | Format + hand to OS share sheet, no lasting state | none | `NoteShareFormatter` helper |
| `account` — sign in/out, device approval (QR), recovery key, delete account (S1, E3, E4) | v1 | `Bloc` | Multi-step flows with branching (new account / add device / recover) | Auth | — |
| `session` — signed-in vs local mode (S1) | v1 | `Cubit` (global) | App-wide read-only state consumed by router and sync | Auth | — |
| `settings` — theme, notifications, floating defaults, hotkey (S4) | v1 | `Cubit` | Flat form backed by local prefs | none | — |
| `entitlements` — plan checks (S5) | v1 (plumbing, all unlocked) | `Cubit` (global) over core `EntitlementsService` | Widgets need to react when limits change | Config ⏳ | `EntitlementGate` widget |
| `links` — `@` mentions, backlinks, broken links (F5) | v1.1 | `Cubit` | Suggestion list driven by query | none (local) | `NoteLinkSpan` |
| `share_link` — read-only E2EE web link (F11.2) | v1.1 | `Cubit` | Create / list / revoke links | Sync ⏳ | — |
| `export_import` — JSON, Markdown (S3) | v1.1 | `Cubit` | Progress + result state | none | — |
| `app_lock` — biometrics / PIN (E5) | v1.1 | `Cubit` | Locked/unlocked gate | none | — |
| `shared_notes` — membership, live co-edit (F11.3) | later | — | Data model only in v1 (§10.1) | Sync ⏳ | — |

**API column:** *Sync* = data goes through the local DB and `SyncEngine` (never called directly). *Auth* = `AuthGateway`. *none* = device-only.

---

## 2. State Management

### Scope → tool

Pick the smallest tool that fits. Move up only when the lower one hurts.

| Scope | Tool | Use when |
|---|---|---|
| Widget-local, ephemeral | **flutter_hooks** (`useState`, `useTextEditingController`, `useAnimationController`, `useFocusNode`) | Text fields, animations, toggles, debouncing input |
| Small shared object, no async flow | `ChangeNotifier` | Rare. Prefer Cubit if it touches a repository |
| Screen / feature state | **`Cubit`** | Default for features |
| Many events, ordering/debounce matters, undo | **`Bloc`** | `note_editor`, `account` flows |
| App-wide | Global `Cubit` registered as singleton | `SessionCubit`, `SyncStatusCubit`, `EntitlementsCubit`, `SettingsCubit` |

### Rules

- State classes extend `Equatable`; all fields `final`; `copyWith` for updates.
- Put derived values in **getters on the state** (`bool get hasChecked => items.any((i) => i.checked)`), never as stored fields that can drift.
- Cubits/Blocs **subscribe to repository streams** (Drift `watch()` queries). They never cache a copy that can go stale — the DB is the truth.
- Writes are **fire-and-forget to the local DB**; UI updates from the stream. Never `await` network in a cubit (NFR4).
- Blocs use `bloc_concurrency` transformers: `sequential()` for edits, `restartable()` for search-like events, `droppable()` for submit buttons.
- Close every subscription in `close()`.
- Cubits are registered in DI (§5) and provided with `BlocProvider` at the route that owns them.

---

## 3. Architecture — Feature-First Clean Architecture (local-first)

### Folder tree

```
lib/
  main_dev.dart                # flavor entrypoints (§10.8)
  main_prod.dart
  app/                         # WeaveApp, bootstrap, router, theme wiring
  core/
    di/                        # one file per feature + core.dart (§5)
    database/                  # Drift DB, tables, DAOs, migrations, FTS
    crypto/                    # CryptoService, KeyStore, key wrapping (§10.3)
    sync/                      # SyncEngine, SyncTransport (interface), outbox, merge, HLC (§10.2)
    auth/                      # AuthGateway (interface), session storage
    entitlements/              # EntitlementsService, Feature enum (§10.6)
    notifications/             # ReminderScheduler, notification actions (§10.4)
    platform/                  # native bridges: overlay, desktop_windows, hotkey, tray, widget_bridge (§10.5)
    logging/                   # AppLogger
    routing/                   # AppRoute enum, router config
    theme/                     # colors, NoteColor palette, typography (Inter)
    responsive/                # context.res(...)
    l10n/                      # ARB files + generated
    helpers/                   # static helper classes (§6)
    extensions/
    widgets/                   # shared widgets (§7)
  features/
    <feature>/
      data/
        local/                 # Drift DAO wrappers (<feature>_local_data_source.dart)
        models/                # DB row ↔ entity mappers, sync payload codecs
        repositories/          # <feature>_repository_impl.dart
      domain/
        entities/
        repositories/          # abstract <feature>_repository.dart
        usecases/
      presentation/
        cubit/ | bloc/
        pages/
        widgets/
  entrypoints/
    floating_window_main.dart  # desktop floating-note window engine
    overlay_main.dart          # Android overlay engine (@pragma('vm:entry-point'))
    capture_main.dart          # desktop quick-capture box engine
```

### Call flow

```
Widget ─▶ Cubit/Bloc ─▶ UseCase ─▶ Repository (abstract)
                                        │
                                        ▼
                               RepositoryImpl ─▶ LocalDataSource (Drift)
                                        │            │  writes row + outbox entry in ONE transaction
                                        │            ▼
                                        │        SQLCipher DB ──watch()──▶ Repository stream ─▶ Cubit
                                        │
                     (no remote call here) ◀── SyncEngine (core) reads outbox, encrypts, pushes;
                                               pulls remote changes, decrypts, merges into DB
```

### Rules

- **Repositories only touch the local DB.** They never call the network. Remote work belongs to `SyncEngine` (Deviation D1).
- Every write that must sync goes into the **outbox in the same Drift transaction** as the row change. No transaction, no sync — no lost edits (NFR2).
- **UseCase**: one public `call()`; holds business rules (e.g. "moving due time shifts T-minus reminders", "uncheck all"). Thin pass-through use cases are fine for consistency.
- **Repository interface** lives in `domain/`, returns entities and `Stream<…>` for reads, `Future<Result<…>>` for writes.
- **LocalDataSource** wraps a Drift DAO; returns DB rows. Mapping row → entity happens in `data/models/`.
- Domain layer imports nothing from Flutter, Drift, or platform packages.
- Features don't import each other's `data/` or `presentation/`. Cross-feature use goes through `domain/` (repository interface / use case) or shared widgets in `core/widgets/`.

---

## 4. Networking & Data

### ⏳ Pending — remote API

Backend is undecided. Until it is chosen:

- The app talks to the server **only** through two interfaces in `core/`:
  - `SyncTransport` — `push(List<EncryptedChange>)`, `pull(since: cursor)`, `Stream<RemoteChangeHint> watch()`, `uploadKeyBundle(...)`.
  - `AuthGateway` — `signInWithApple/Google/Email`, `signOut`, `deleteAccount`, `Stream<AuthUser?> user`.
- Implementations go in `core/sync/transport/<backend>_sync_transport.dart` and `core/auth/<backend>_auth_gateway.dart`.
- Dev builds use `InMemorySyncTransport` (two app instances share it in tests) so sync logic is fully testable now.
- When the backend is picked, fill in: `ApiService` entry points (`sendRequest` / `sendGraphQlRequest` / SDK), `ApiResponse<T>`, envelope check, retries.

### Data rules (apply now)

- Every remote payload is an **encrypted blob** plus plaintext metadata only: `id`, `noteId`, `entityType`, `hlc`, `deviceId`, `size`, `deleted`. Nothing else plaintext (E1).
- Parsing: `fromJson → Entity`. Use `is` checks and `tryParse`; **no `as` casts**; null-safe defaults for every field.
- Decryption failure or unknown schema version → log, quarantine the change, **never** drop or overwrite local data.
- Logging via `AppLogger.forTag('Sync')` etc. **Never log decrypted content, keys, or recovery key.** Log IDs and sizes only.

### Local DB (Drift + SQLCipher)

- One `WeaveDatabase` in `core/database/`; tables per entity; DAOs per feature.
- Encryption key for SQLCipher lives in Keychain/Keystore (`flutter_secure_storage`), generated on first launch (E5). Web: unencrypted IndexedDB/wasm (P2, documented limitation).
- **FTS5** virtual table over title, text blocks, item text for search (F9). Kept in sync by triggers.
- Indexes for list queries; target NFR5 (2,000 notes / 20,000 items) — add a seeded perf test.
- Migrations: every schema change bumps `schemaVersion` with a tested `MigrationStrategy` step. Never destructive.
- Multiple engines (floating windows, overlay, capture box) **share one DB**: open in WAL mode; the main engine hosts a `DriftIsolate`; secondary engines connect to it when reachable, else open their own connection. Changes from other engines trigger stream refresh via table-update notifications.

---

## 5. Dependency Injection

- `get_it` service locator. ⏳ Exact conventions may be refined by `principles.md`.
- One file per feature in `core/di/` (`notes_di.dart`, `reminders_di.dart`, …) plus `core_di.dart`. Each exposes `void register<Feature>(GetIt sl)`.
- **Singleton (lazy):** database, `CryptoService`, `KeyStore`, `SyncEngine`, `SyncTransport`, `AuthGateway`, `ReminderScheduler`, `EntitlementsService`, `WidgetBridge`, repositories, data sources, global cubits (`SessionCubit`, `SyncStatusCubit`, `EntitlementsCubit`, `SettingsCubit`).
- **Factory:** use cases, screen-level cubits/blocs.
- Each secondary engine entrypoint (§3 `entrypoints/`) calls a reduced `registerForWindow()` — no `SyncEngine`, no `ReminderScheduler` there; only the main engine runs those.
- Flavor-specific bindings (transport, config) are registered in `main_<flavor>.dart`, not inside features.

---

## 6. Helpers & Enums

### Helpers

Static, stateless classes in `core/helpers/`, one concern each:

| Helper | Purpose |
|---|---|
| `HlcClock` (core/sync) | Hybrid logical clock for ordering edits across devices |
| `FractionalIndex` | Order keys for notes/items so reorders merge without conflicts |
| `ReminderTimeHelper` | Wall-clock ↔ instant conversion, next occurrence, T-minus offset (F4.8) |
| `NoteShareFormatter` | Note → plain text / Markdown (F11.1) |
| `DateLabelHelper` | "Tomorrow 9:00", "in 2 hours" labels (localized) |

### Enums

Convention for every enum that is persisted or synced:

- `fromApi(String)` → enum (unknown → safe default, never throw).
- `apiValue` → stable string stored in DB / payload. **Never** use `.name` or index for storage.
- `label(BuildContext)` → localized display string.

Project enums: `NoteColor`, `ReminderKind` (atTime, tMinus, timer), `RepeatRule` kind, `SyncStatus` (synced, syncing, offline, error), `NoteBlockType` (text, checklistItem), `Feature` (entitlements), `NoteMemberRole` (owner — editor/viewer later).

### Extensions

In `core/extensions/`: `DateTime`, `BuildContext` (`theme`, `l10n`, `res`), `Iterable` helpers. No business logic in extensions.

---

## 7. Reusable Widgets

**Promote on second use:** a widget lives inside its feature until a second feature needs it; then move it to `core/widgets/` unchanged.

Known shared widgets from requirements:

| Widget | Used by |
|---|---|
| One shared app bar (`WeaveAppBar`) | all main-app pages |
| `NoteCard` | notes list, search, archive/trash |
| `ChecklistItemTile` | note editor, floating notes |
| `NoteColorPicker` + `NoteColor` swatches (light/dark aware) | editor, list |
| `SyncStatusBadge` | app bar, floating note handle |
| `UndoSnackBar` (via helper `showUndo(...)`) | delete, archive, check (F10) |
| `ReminderChip` / `DueDateText` | editor, list, floating notes |
| `EntitlementGate` | any limited feature |
| `EmptyState` | list, search, trash |

---

## 8. UI Rules

### Non-negotiables

- No `Widget _buildX()` methods — always a `StatelessWidget`, however small.
- `HookWidget` over `StatefulWidget`, however complex.

### Rebuild control

- `BlocSelector` / `context.select` for the exact field a widget needs; avoid whole-state `BlocBuilder` on large screens.
- Lists use `ListView.builder` / `SliverList` with stable `ValueKey(id)` (NFR5).
- `const` constructors everywhere possible.

### Hooks

- Controllers, focus nodes, animation controllers only via hooks (auto-disposed). Never create them in `build` manually.
- Floating notes: `useFocusNode` with `canRequestFocus` only after a tap/click (F1.6).

### Responsive

- Use `context.res(mobile: …, tablet: …, desktop: …)` for any size-dependent value. Phones, tablets, desktop windows and tiny floating windows all exist.
- Floating windows have their own compact layout; test at the minimum window size.

### Typography & theme

- Inter, bundled as an asset (no runtime font download — offline first).
- Text styles only from `Theme.of(context).textTheme`; no inline `TextStyle(fontSize: …)`.
- Theme modes: light, dark, system (S4). Note colors come from `NoteColor` with light/dark variants meeting WCAG AA (NFR9).

### Dialogs & sheets

- All dialogs and bottom sheets go through `DialogWrapper`.
- Destructive confirmations (sign out wipes data, delete account, empty trash) use one shared confirm dialog with explicit wording.

### Accessibility & l10n

- Every icon button and checkbox has a `Semantics` label / tooltip.
- Support dynamic text size; no fixed-height text containers.
- Full keyboard use on desktop: `Shortcuts` + `Actions` for new note, search, tick, hide floating notes.
- No hard-coded user-facing strings — `context.l10n.*` only (NFR10).

---

## 9. Routing

- `go_router`; routes declared via an `AppRoute` enum (`path`, `name`). Navigate with `context.goNamed(AppRoute.x.name, extra: args)`.
- Typed args through `state.extra` with a dedicated args class per route; pages also accept path params so deep links work without `extra`.

### Project needs

| Need | Rule |
|---|---|
| Deep links | `weave://note/<noteId>?item=<itemId>` — opens note scrolled to item. Used by widgets, notification "open", `@` links (F5.2), share-in |
| Guards | No auth guard on main app (local mode is full app). Guard only account-only screens (devices, recovery key, delete account) via `SessionCubit` |
| Mandatory flows | Recovery-key save screen after first sign-in cannot be skipped silently (E4) |
| Separate engines | Floating windows, Android overlay and capture box are **separate entrypoints**, not routes. They open the main app with a deep link when the user wants the full editor |
| Web | Path URL strategy |

---

## 10. Capability Sections

### 10.1 Offline & data model

- Local DB is the source of truth; app is fully usable with no network (F2.3, S2).
- Every synced entity has: `id` (UUID v7), `noteId`, `hlc` per mutable field, `deleted` tombstone, `updatedByDevice`.
- Notes and checklist items are **separate records** (item-level merge). Order via `FractionalIndex`.
- **Per-note key + membership tables exist from v1** (`note_keys`, `note_members` with only the owner) so F11.3 needs no migration of existing data.
- Trash: `deletedAt`; purge after 30 days on device; purge propagates as tombstone (F10, F2.6).
- Device-only tables (never synced): floating window geometry (F1.3), settings that are per-device, outbox, sync cursor.

### 10.2 Sync (F2)

- `SyncEngine` runs only in the main engine. Triggers: app start, outbox write (debounced ~300 ms), remote change hint, connectivity regained, periodic backoff retry.
- **Merge on device** (F2.7):
  - Different fields / different items → field-level last-writer-wins by HLC. Never loses edits to other fields.
  - Same text field edited on two devices since last common version → **keep both**: local wins in place, remote kept as a conflict copy block, user notified (F2.4).
  - Delete vs edit → edit resurrects from trash, user notified.
- Outbox entries are removed **only after server ack**. Pushes are idempotent (change ID).
- `SyncStatusCubit` maps engine state → `SyncStatus` for the indicator (F2.5).
- Sign-in with existing local data → bulk encrypt + upload (S1).
- Transport + realtime channel ⏳ Pending backend.
- Required test: two `SyncEngine`s over `InMemorySyncTransport`, one offline, concurrent edits → both converge, nothing lost (F2 acceptance).

### 10.3 E2EE & keys (§6 of requirements)

- Audited libraries only (libsodium via `sodium_libs`, or `cryptography` with platform-native backends). **No home-made crypto** (NFR7).
- Keys: account key → wraps per-note keys. Note payloads encrypted with the note key (AEAD; metadata bound as associated data).
- Keys stored in Keychain/Keystore via `KeyStore`; never in the Drift DB, prefs, or logs.
- New device: QR approval from an existing device (key handoff over an encrypted channel) or recovery key entry (E3).
- Recovery key shown once at setup + periodic reminder prompts to confirm it was saved (E4, Q7).
- `CryptoService` is the only class that touches raw keys. Everything else handles opaque `EncryptedBlob`.

### 10.4 Reminders & notifications (F4)

- Scheduled **locally on every device** (`flutter_local_notifications` + `timezone`) — never depend on server push (F4.7).
- Storage: at-time and due times store **wall-clock local time + "floating" flag** (9:00 stays 9:00 across time zones); timers store a **UTC instant** (F4.8). T-minus stores an offset from the due time.
- `ReminderScheduler` reconciles the OS schedule from DB state on: app start, reminder change (local or synced), time-zone change, reboot (Android `BOOT_COMPLETED`).
- Notification IDs are **deterministic** from `reminderId + occurrence` so rescheduling never duplicates.
- Done / snooze from a notification action writes to DB → syncs → other devices' schedulers cancel the same ID (F4.6, anti-goal: duplicates).
- Notification text is built on device after decryption (E6).
- Only schedule the next N occurrences per repeating reminder (OS limits, e.g. iOS 64 pending).

### 10.5 Platform integrations (F1, F6)

All native code sits behind a Dart interface in `core/platform/`; features use the interface, never a plugin directly.

| Interface | Android | iOS | macOS / Windows / Linux | Web |
|---|---|---|---|---|
| `FloatingNotesHost` | Overlay window (`SYSTEM_ALERT_WINDOW`), separate engine | — (unsupported) | Borderless always-on-top window per pinned note (multi-window) | — |
| `WidgetBridge` | Home-screen widget | Home + lock-screen widgets (App Intents for ticking), Live Activity (v1.1) | — | — |
| `GlobalHotkey` | — | — | Quick capture box | In-app shortcut |
| `TrayHost` | Persistent "Add to Weave" notification (opt-in) | — | Menu-bar / system-tray item | — |
| `ShareIntake` | Share target | Share extension | — | — |

Rules:

- Capability detection via `PlatformCapabilities` (e.g. `canFloat`, `hasOverlayPermission`). UI hides what the platform can't do. **App works fully if overlay permission is denied** (constraints).
- Widgets read a **snapshot** written by `WidgetBridge` into the shared app-group/container (OS-protected, minimal content). Widget actions (tick) are queued there and applied by the app on next launch/background wake — widgets never open the SQLCipher DB.
- "Hide/show all" floating notes is one call on `FloatingNotesHost` (F1.5). Auto-hide in full-screen apps on desktop (S4).
- Idle floating windows do no polling — streams only (NFR6).

### 10.6 Entitlements (S5)

- `EntitlementsService.can(Feature)` and `limitOf(Feature)` are the **only** gate. No scattered `if (isPro)` checks.
- Plan/limit config fetched from server config (⏳ backend), cached locally, default = everything unlocked.
- Hitting a limit **blocks adding**, never hides or deletes existing data.
- `EntitlementGate` widget wraps limited UI entry points.
- Purchase providers (App Store, Play, web/desktop) plug in later behind a `PurchaseGateway` interface — not built in v1.

### 10.7 Auth & account (S1)

- `SessionCubit`: `local` | `signedIn(user)` | `signingOut`. Local mode never hits the network.
- Sign in with Apple **required on iOS** when Google is offered.
- Sign out: confirm → wipe local DB, keys, widget snapshots, scheduled notifications on this device.
- Delete account: in-app, confirm, calls `AuthGateway.deleteAccount` then wipes local (store rule).
- Provider SDKs ⏳ Pending backend.

### 10.8 Flavors

- `dev` and `prod`: `main_dev.dart`, `main_prod.dart`; Android `productFlavors`, iOS/macOS schemes + xcconfig.
- App ID: `com.rogers.weave` (prod), `com.rogers.weave.dev` (dev). App name suffix "Dev".
- `AppConfig` (flavor, backend endpoints ⏳, log level) injected in DI. No `if (kDebugMode)` for environment switching.
- Dev may use `InMemorySyncTransport` until a backend exists.

---

## 11. Naming & Files

- Files `snake_case.dart`; one public class per file; file name = class name.
- Suffixes: `_page`, `_cubit` / `_state`, `_bloc` / `_event` / `_state`, `_use_case`, `_repository` (abstract), `_repository_impl`, `_local_data_source`, `_model`, `_dao`, `_table`, `_di`.
- Entities have no suffix (`Note`, `ChecklistItem`, `Reminder`).
- Use cases are verb phrases: `ToggleItem`, `MoveDueTime`, `UncheckAll`, `PinToScreen`.
- Feature folder names match the Feature Map (§1).
- Glossary terms are binding in code: *pinned to screen* (`pinnedToScreen`) vs *pinned to top* (`pinnedToTop`) — never just `pinned`.

---

## 12. Quality Gate

Before every merge:

- [ ] `flutter analyze` — zero issues; `dart format` clean.
- [ ] Non-negotiables respected (no `_buildX` methods, `HookWidget` not `StatefulWidget`).
- [ ] No hard-coded user-facing strings; semantics labels on interactive widgets.
- [ ] Repositories don't call the network; synced writes go through the outbox in one transaction.
- [ ] No `as` casts in parsing; enums use `fromApi` / `apiValue`.
- [ ] No content, keys, or recovery key in logs.
- [ ] Limited features go through `EntitlementsService`.
- [ ] Tests:
  - Unit: use cases, mappers, `HlcClock`, `FractionalIndex`, `ReminderTimeHelper` (time zones, DST, T-minus shift).
  - Merge/sync: two-engine convergence tests incl. offline and same-field conflicts.
  - Crypto: encrypt/decrypt round-trip, wrong-key failure, no plaintext in payload.
  - `bloc_test` for every cubit/bloc.
  - Widget tests for shared widgets and floating-note compact layout.
  - DB: migration tests for every schema bump; seeded NFR5 perf test.
- [ ] Platform-specific change tested on every P0 platform it touches (Android, iOS, macOS).

---

## Deviations

| ID | Principle | Project decision | Reason | Agreed on |
|---|---|---|---|---|
| D1 | Repository → remote DataSource via `ApiService` | **Local-first:** repositories read/write the local Drift DB only; a core `SyncEngine` owns all remote traffic (encrypt, push, pull, merge) | Offline-first, UI never waits on network (NFR2, NFR4), E2EE requires merging on device (F2.7) | 2026-10-29 |
