# Weave 7-Day Working Model — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A working Weave on macOS, Windows, iOS and Android in 7 days. Lists and tasks are managed locally and synced between one user's devices through Supabase in under 3 s. It has the design-02 app screens, local reminders, and the desktop mini bar.

**Architecture:** Local-first, as in the architecture playbook. The Drift DB is the source of truth. Every write updates the row, its per-field HLC and an outbox entry in **one transaction**. A `SyncEngine`, running in the main engine only, pushes the outbox to a Supabase `changes` table, pulls by sequence number, and merges each field by HLC (last writer wins). When the same task text is edited on two devices, it keeps both versions. A realtime insert on `changes` triggers a pull. Payloads go through a `PayloadCipher` seam: pass-through now, libsodium in the E2EE phase.

**Tech Stack:**

- Flutter 3.44 / Dart 3.12
- State: flutter_bloc, bloc_concurrency, equatable, flutter_hooks
- Infrastructure: get_it, go_router
- Storage: drift, sqlite3_flutter_libs
- Sync and auth: supabase_flutter
- Platform: uuid, connectivity_plus, device_info_plus, flutter_local_notifications, timezone, flutter_timezone
- Desktop: window_manager, desktop_multi_window, tray_manager, hotkey_manager
- Testing: bloc_test, mocktail

**Spec:**

- `docs/requirements.md` (F2, F3, F4, F6, F7, F8, F9, F10, S1, S2, S4, NFR1–NFR5)
- `docs/playbook/architecture-playbook.md`
- `docs/playbook/design-playbook.md`
- the locked prototypes in `docs/design-02/`: 01 mini bar, 03 app. When the playbook and a prototype disagree, the prototype wins.

---

## Progress

| Checkpoint | Date | State |
|---|---|---|
| 1 | 2026-11-05 | **Tasks 1–3 done, reviewed and staged** (setup + flavors + Supabase migration; theme tokens + Geist; ids, HLC, fractional index). `flutter analyze` 0 issues, 23/23 tests. Supabase done by the user (migration live, email + password auth, test user, `config/dev.json`); verified by sign-in and reads of `changes` and `devices`. **Still waiting on the user:** a Windows build check. Next: Task 4. |
| 2 | 2026-11-05 | **Tasks 4–8 done, reviewed and staged** (Day 2 complete): database + change log (clock saved across restarts), task and list data, quick-capture parsing, lists repository (undo of delete forever restores tasks), items repository + Up next + search (tie-safe reordering, conflict resolution in one transaction). `flutter analyze` 0 issues, 99/99 tests. Supabase verified live. Quick-capture fixes (user request): "tonight" after 20:00 → tomorrow 20:00; punctuation after a date or time no longer drops the due. **Still waiting on the user:** Windows build check. Next: Task 9 (sync transport). |
| 3 | 2026-11-05 | **Tasks 9–10 done, reviewed and staged.** Transport interface + in-memory transport + cipher seam (reproduces the late-commit skip). ChangeMerger after 4 fix rounds and 3 reviews: text conflicts detected by base HLC (`b`), greater HLC wins on every device, every loser kept (JSON arrays with device name + HLC, same set on all devices), same-device chains don't conflict; delete forever remembered on the deleting device (`purged.<id>`, incl. purgeTrash, mini bar removed, undo unmarks); trash older than a local edit is undone; malformed HLCs ignored; clock overflow carries instead of throwing; one synced-field map. Two- and three-device convergence tests, no ping-pong. `flutter analyze` 0 issues, 184/184 tests. **Still waiting on the user:** Windows build check. Next: Task 11 (sync engine) — read the Task 11 items in "Carried into" first. |
| 4 | 2026-11-05 | **Task 11 done, reviewed and staged.** SyncEngine: pull (seq order across pages, re-read window cursor−100, applied-id dedupe + cursor in the same transaction as the merge, bounded markers) then push (oldest first, batches of 200, delete only acked). Quarantine of unreadable changes blocks only that entity; other apply errors stop the pull at that row but still push, then back off 2…60 s. One pass at a time; stop/start resets connectivity; `unregisterSync` for sign-out (Task 13). Local device-name cache. `SyncStatusCubit` global, `localOnly` when signed out. Not yet wired into bootstrap — Task 12 does that with the Supabase transport. `flutter analyze` 0 issues, 226/226 tests. **Still waiting on the user:** Windows build check. Next: Task 12 (Supabase transport, realtime hints, devices — Day 3 gate). |
| 5 | 2026-11-06 | **Task 12 done, reviewed and staged — Day 3 gate passed.** Supabase transport on the real dev project: A→B in 1588 / 1761 / 1729 / 1791 / 1810 ms (NFR1 < 3 s), offline-edit case converges. Push relies on RLS + `auth.uid()` default (no client `user_id`); realtime hints per device channel, token set before join, reopen on user change / error / server close; network, timeout and offline session refresh → offline, server errors → error; per-request timeouts, no hidden retries. Pull pages report `full` / `lastSeq` so a malformed row never stalls catch-up. Device names cached from `devices` (outside the merge transaction, stopped at sign-out). Sync wired in the main entrypoint, local-only fallback without Supabase or session. No migration needed. Run: `flutter test integration_test/sync_supabase_test.dart -d macos --flavor dev --dart-define-from-file=config/dev.json`. `flutter analyze` 0 issues, 255/255 tests. **Still waiting on the user:** Windows build check. Next: Task 13 (auth, session, bulk upload, sign out, delete account) — it calls `startSync` after sign-in and `unregisterSync` on sign-out. |

Carried into later tasks from reviews:
- Task 10: the merger takes `ChangeWriter`; applying a list purge also deletes its tasks; late changes never bring back a purged list or task.
- Task 11 logs remote clocks more than 24 h ahead.
- Task 11: the engine records applied change ids and skips ones already applied (each sync re-reads recent changes as a safety net; without this, an out-of-order redelivery could raise a stale conflict). Save the pull cursor in the same transaction as the apply.
- Task 11: `deviceName` must be a local lookup (cache), never network, since it runs inside the merge transaction. The cache includes this device.
- Task 11: apply pulled rows strictly in ascending `seq` order, across pages too. Record a change id as applied even when the result is `ignored`. Rule 6 relies on a create preceding its edits in `seq` order. If a change is quarantined, also quarantine later changes for that entity id (do not mark them applied), so a fixed cipher can replay them. Malformed HLCs are not errors: the merger skips the field or returns `ignored`.
- Known limit: cross-device undo of delete forever after the marker was pushed is not supported.
- Task 12: `unregisterSync` unregisters the transport without disposing it; the Supabase transport must close its realtime channel (dispose it in `unregisterSync`'s `_drop<SyncTransport>` or in the engine's `dispose`).
- Known limit: after a pull fails at a row, push still runs; a stuck remote text change without `b` (old format) is then treated as sequential because the outbox is empty. No such payloads exist yet.
- Task 13: the device id is captured by the clock, writer, `DeviceNames`, `ChangeMerger` and `SyncEngine`. On sign-out: `unregisterSync(sl)` (disposes the engine, unregisters the transport, cipher, `DeviceNames` and `ChangeMerger`; detaches the `SyncStatusCubit`), then wipe, then re-register `DeviceId`, `HlcClock` and `ChangeWriter` with the new id, then `registerSync` again. The global `SyncStatusCubit` is kept (widgets hold one instance) and `registerSync` re-attaches it to the new engine's status.
- Tasks 14 and 15 refresh list and Up next streams every minute and on app resume (overdue is computed when a stream starts).
- Logo locked 2026-11-05 (`docs/logo/kit`): Task 14 uses the mark in the sidebar brand and Windows title bar; Task 24 uses the tray template; Platform app icons are already in place (2026-11-05: Android legacy + adaptive with monochrome on paper #F5F5F3, iOS without alpha, macOS on the 824/1024 grid, Windows .ico, web incl. maskable and apple-touch, Linux window icon from `assets/brand/app_icon.png`); Task 26 only verifies them in release builds. Brand assets for the UI and tray are in `assets/brand/`.
- Task 14 wires `weaveTheme` into `WeaveApp`. Add a `tick` colour token before Task 15.

## Phases

| Phase                          | Day | Outcome at end of day                                                                                                       | Tasks |
| ------------------------------ | --- | --------------------------------------------------------------------------------------------------------------------------- | ----- |
| 0 · Foundation                 | 1   | App boots on all 4 platforms with the design-02 theme. DB writes produce outbox entries. Supabase schema is live            | 1–4   |
| 1 · Tasks and lists core       | 2   | All list and task rules work in tests: add, tick, order, due, reminders, repeat, archive, trash, quick parse                | 5–8   |
| 2 · **Sync** (priority)        | 3   | **Gate:** two engines on one real Supabase account converge, offline edits included. Sign in, sign out and bulk upload work | 9–13  |
| 3 · App screens I              | 4   | Shell (sidebar / tab bar), Up next with day thread, list screen. Usable daily on all 4 platforms                            | 14–16 |
| 4 · App screens II + reminders | 5   | Task details, list options, conflict row, archive and trash, search, settings and account, local reminders                  | 17–21 |
| 5 · Desktop mini bar           | 6   | One floating bar per list on macOS and Windows, with the sheet, tray / menu bar, ⌥Space / Ctrl+Space                        | 22–24 |
| 6 · Ship                       | 7   | Two-device acceptance matrix passes; release builds for 4 platforms                                                         | 25–26 |

**Cut order if behind:** cut from the bottom. Task 24 goes first, then 23, then 19 (search half). Sync (9–13) and the list and task screens (15–17) never slip. The Day 3 gate must pass before Day 4 starts; if it fails, Day 4 goes to sync.

**Later phases (not in these 7 days):**

- E2EE: libsodium `PayloadCipher`, recovery key, QR device approval, SQLCipher at rest
- Apple / Google sign-in and magic links
- Notification actions (Mark done / Snooze / Open)
- Widgets and Share to Weave
- Android overlay and the "Add to Weave" notification
- First run
- FTS5 search
- Localization: move strings to ARB (NFR10)
- Windows / macOS auto-update

## Global Constraints

- Design-02 is locked. Screens, copy, sizes and motion come from `docs/playbook/design-playbook.md` and `docs/design-02/`. Any visual change needs a flagged proposal (playbook §10).
- Clutter rules C1–C12 (design playbook §0) apply to every screen.
- Typography: Geist 400/500 only, bundled from `assets/fonts/`; tabular figures for times and counts.
- Tokens: every colour, radius, size and duration comes from `lib/core/theme/` and mirrors `docs/design-02/assets/tokens.css`. No raw hex in features.
- Sizes:
  - row 44
  - control 36 (small 30)
  - field 40 (phone add bar 44)
  - bar 40
  - radius 8 cards / 6 controls
  - sidebar 256 (224 under 1100 px)
  - list reading width 760
- Motion: `--dur-fast` 120 ms, `--dur` 180 ms. Keyboard-triggered UI is instant. Exits are faster than enters. Respect reduced motion (`MediaQuery.disableAnimations`).
- Platforms and minimum OS: iOS 17, Android 8 (API 26), macOS 12, Windows 10.
- App IDs: `com.rogers.weave` (prod) and `com.rogers.weave.dev` (dev).
- Local-first:
  - Repositories touch only the local DB.
  - UI never awaits the network (NFR4).
  - Synced writes go through `ChangeWriter`, which writes the row and the outbox in one transaction (NFR2).
- No `as` casts when parsing; null-safe defaults. Never log task text, list names or tokens. Log ids and counts only.
- Widgets are `HookWidget`s (no `StatefulWidget`) and have no `_buildX` methods. User-facing strings are plain English literals for now; localization is deferred (D9).
- Glossary terms in code: `pinnedToTop` and `showInMiniBar`. Never a bare `pinned`.
- Before every checkpoint, `flutter analyze` reports zero issues and `dart format` is clean.
- **Commits:** the user commits. Each task ends with a checkpoint that lists the files to stage. Commit only if the user says so.

### Decisions made for the 7-day build

Task 1 logs these as deviations D2–D9 in the architecture playbook.

| ID  | Decision                                                                                            | Instead of        | Back in                    |
| --- | --------------------------------------------------------------------------------------------------- | ----------------- | -------------------------- |
| D2  | Backend is **Supabase** (Postgres `changes` table, Realtime, Auth)                                  | ⏳ pending        | —                          |
| D3  | `PayloadCipher` pass-through (JSON → base64). Interface ready for libsodium                         | E2EE              | E2EE phase                 |
| D4  | Plain SQLite via `sqlite3_flutter_libs`                                                             | SQLCipher         | E2EE phase                 |
| D5  | Email + password sign-in only. The Apple and Google buttons and the magic-link option are not shown | All providers     | Auth phase                 |
| D6  | Search uses `LIKE` over task text and list names                                                    | FTS5              | Later                      |
| D7  | `showInMiniBar` and bar geometry are device-only (table `mini_bars`)                                | Synced list field | —                          |
| D8  | Settings hides "Recovery key" and "Add a device"; notifications have no action buttons              | E3/E4, F4.5       | E2EE / notifications phase |
| D9  | No localization: English string literals in widgets; no ARB / gen-l10n | NFR10 (externalized strings) | Later |

## Review Focus

1. **Rows committed out of sequence order.** Postgres identity values can commit out of order, so a pull that saves `max(seq)` can skip a row that becomes visible later with a lower `seq`. Each pull re-reads the last 100 sequence numbers (`seq > cursor - 100`); applying a change is idempotent. _Test in Task 11:_ `late commit with lower seq is still applied`.
2. **The same task text edited offline on two devices.** Neither edit may be lost silently. The greater HLC wins on every device; the other text becomes `conflictText` with the name of the device that wrote it. Several concurrent losers are all kept. _Test in Task 10:_ `concurrent text edits keep both`.
3. **A device clock that is an hour fast or slow.** HLC `receive` must move the local clock past any remote HLC it has seen, so a later edit on the slow device still wins. _Test in Task 3:_ `receive moves clock past a remote clock that is ahead`.
4. **The app is killed or the network fails mid-push.** Outbox rows are deleted only after the server acknowledges them, and the next start pushes them again. _Test in Task 11:_ `push failure keeps outbox rows`.
5. **Signing out, then into a different account.** No data or cursor from the first account may leak. Sign-out wipes every table and resets `sync.cursor`. _Test in Task 13:_ `sign out wipes lists, items, outbox and cursor`.

---

## File Structure

```
supabase/migrations/20261106000000_init.sql  # changes, devices, RLS, realtime, delete_account()
assets/fonts/Geist-Regular.ttf, Geist-Medium.ttf
lib/
  main_dev.dart, main_prod.dart          # flavor entrypoints → app/bootstrap.dart
  app/  bootstrap.dart  app_config.dart  weave_app.dart  router.dart
  core/
    di/            core_di.dart lists_di.dart items_di.dart sync_di.dart account_di.dart
    ids/           new_id.dart                          # UUID v7
    sync/          hlc.dart hlc_clock.dart change_writer.dart entity_type.dart
                   sync_transport.dart in_memory_sync_transport.dart supabase_sync_transport.dart
                   payload_cipher.dart change_merger.dart sync_engine.dart sync_status.dart
                   bulk_uploader.dart
    helpers/       fractional_index.dart quick_parse.dart reminder_times.dart due_label.dart
    database/      weave_database.dart tables.dart
    auth/          auth_gateway.dart supabase_auth_gateway.dart
    notifications/ reminder_scheduler.dart
    platform/      mini_bar_host.dart desktop_mini_bar_host.dart cross_window_bus.dart tray_host.dart hotkey_host.dart
    theme/         weave_tokens.dart weave_theme.dart note_color.dart
    widgets/       quick_capture_field.dart item_tile.dart day_thread.dart day_strip.dart
                   sync_status_badge.dart undo_toast.dart weave_dialog.dart
  features/
    lists/   domain/{entities/task_list.dart, repositories/lists_repository.dart, usecases/*}
             data/lists_repository_impl.dart   presentation/{cubit/*, pages/list_page.dart, widgets/*}
    items/   domain/{entities/item.dart, due_spec.dart, reminder_spec.dart, repeat_rule.dart, repositories/items_repository.dart, usecases/*}
             data/items_repository_impl.dart   presentation/{task_details/*}
    up_next/ presentation/{up_next_cubit.dart, up_next_page.dart}
    archive_trash/ presentation/*
    search/  presentation/*
    settings/ presentation/*  data/prefs.dart
    account/ presentation/{session_cubit.dart, account_dialogs/*}
    mini_bar/ presentation/{mini_bar_app.dart, bar.dart, sheet.dart}
  entrypoints/mini_bar_main.dart
test/  (mirrors lib/)
integration_test/sync_supabase_test.dart
```

---

## Phase 0 · Foundation (Day 1)

### Task 1: Project setup, flavors, platform config, Supabase schema

**Files:**

- Modify: `pubspec.yaml`, `analysis_options.yaml`, `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`, `ios/Podfile`, `ios/Runner.xcodeproj` (deployment target 17), `macos/Runner/*.entitlements`, `macos/Podfile` (12.0), `docs/playbook/architecture-playbook.md` (Deviations D2–D8)
- Create: `lib/main_dev.dart`, `lib/main_prod.dart`, `lib/app/bootstrap.dart`, `lib/app/app_config.dart`, `lib/app/weave_app.dart`, `supabase/config.toml` (from `supabase init`), `supabase/migrations/20261106000000_init.sql`, `config/dev.example.json`, `.gitignore` (add `config/*.json` and keep `!config/*.example.json`), `assets/fonts/Geist-{Regular,Medium}.ttf`, `README.md` (run section)
- Delete: `lib/main.dart`, `test/widget_test.dart`

**Interfaces:**

- Produces:
  - `enum Flavor { dev, prod }`
  - `class AppConfig { final Flavor flavor; final String supabaseUrl; final String supabaseAnonKey; final String profile; static AppConfig fromEnvironment(Flavor f); }`. It reads `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `WEAVE_PROFILE` (default `'default'`) from `--dart-define-from-file=config/<flavor>.json`. That file is git-ignored; `config/dev.example.json` holds the keys with empty values. A missing URL throws at startup with a clear message. `profile` names the DB folder, so two copies can run on one machine.
  - `Future<void> bootstrap(AppConfig config)`

- [x] **Step 1:** Add the dependencies from the Tech Stack line, at the latest stable versions. Add `drift_dev` and `build_runner` as dev dependencies. Register the Geist font family (400 and 500) under `flutter: fonts:`.
- [x] **Step 2: Platform config.**
  - Android:
    - `minSdk 26`
    - `productFlavors` dev / prod, with `applicationIdSuffix ".dev"` and app name "Weave Dev"
    - permissions `INTERNET`, `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`
  - iOS: deployment target 17.
  - macOS:
    - deployment target 12
    - entitlements `com.apple.security.network.client = true` in both Debug and Release
    - keychain sharing for `supabase_flutter` session storage
  - Windows: no change.
- [x] **Step 3:** Install the CLI (`brew install supabase/tap/supabase`) and run `supabase init` at the repo root. The GitHub integration reads `supabase/`, so check that its working directory is set to `.`. Write `supabase/migrations/20261106000000_init.sql` exactly. The name must be `<timestamp>_name.sql`, or the integration skips it:

```sql
create table public.changes (
  seq bigint generated always as identity primary key,
  change_id uuid not null unique,
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  entity_type text not null check (entity_type in ('list','item')),
  entity_id uuid not null,
  device_id text not null,
  hlc text not null,
  payload text not null,
  created_at timestamptz not null default now()
);
create index changes_user_seq on public.changes (user_id, seq);
alter table public.changes enable row level security;
create policy changes_own on public.changes for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create table public.devices (
  id text primary key,
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  name text not null,
  platform text not null,
  last_seen_at timestamptz not null default now()
);
alter table public.devices enable row level security;
create policy devices_own on public.devices for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

alter publication supabase_realtime add table public.changes;

create function public.delete_account() returns void
language sql security definer set search_path = public as $$
  delete from auth.users where id = auth.uid();
$$;
revoke all on function public.delete_account() from public, anon;
grant execute on function public.delete_account() to authenticated;
```

- [x] **Step 4 (user, done 2026-11-05):** The migration deploys through the GitHub integration when it is merged to the production branch. **That deploy is the user's push.** Before pushing, run `supabase link --project-ref <ref>` and then `supabase db push --dry-run` to see the SQL that would apply. Under Auth, the user turns email + password on and sets "Confirm email" off for development. The user copies the project URL and the anon (publishable) key into `config/dev.json`. Never commit the service-role key or put it in the app.
  - Verify: `select count(*) from public.changes;` returns 0. `select * from pg_publication_tables where tablename='changes';` returns 1 row.
- [x] **Step 5:** In `bootstrap`:
  1. Call `WidgetsFlutterBinding.ensureInitialized()`.
  2. `Supabase.initialize(url, anonKey)`.
  3. `tz` init.
  4. `registerCore(sl, config)`.
  5. `runApp(const WeaveApp())`.

  `WeaveApp` is a `MaterialApp.router` with an empty home for now.

- [x] **Step 6:** Add Deviations D2–D8 (table above) to the architecture playbook. Set §0 "API type" to Supabase.
- [x] **Step 7: Verify.** `flutter analyze` reports 0 issues. Then run `flutter run -t lib/main_dev.dart --flavor dev --dart-define-from-file=config/dev.json` on macOS, an iOS simulator, an Android emulator and Windows. Each opens a blank window with no exceptions.
- [x] **Step 8: Checkpoint.** Stage pubspec.\_, the platform folders, lib/app, lib/main\_\_.dart, supabase/, assets/fonts, README.md and the playbook.

### Task 2: Theme tokens, note colours, Geist

**Files:**

- Create: `lib/core/theme/weave_tokens.dart`, `lib/core/theme/weave_theme.dart`, `lib/core/theme/note_color.dart`
- Test: `test/core/theme/weave_theme_test.dart`

**Interfaces:**

- Produces:
  - `class WeaveTokens extends ThemeExtension<WeaveTokens>`. It holds one field per CSS custom property in `docs/design-02/assets/tokens.css`, with camelCase names (`--surface` → `surface`, `--dur-fast` → `durFast`), plus `static const light` and `static const dark`.
  - `ThemeData weaveTheme(Brightness b)`
  - `enum NoteColor { … }`, with the palette names from tokens.css, plus `Color fill(Brightness b)`, `Color ink(Brightness b)`, `String get apiValue`, and `static NoteColor fromApi(String? v)` (unknown → the first value).
  - `extension WeaveTokensX on BuildContext { WeaveTokens get tokens; }`

- [x] **Step 1: Write the failing test.**
  - `WeaveTokens.light.surface` equals the light `--surface` hex in tokens.css.
  - `WeaveTokens.dark.text` equals the dark `--text`.
  - `WeaveTokens.light.durFast == Duration(milliseconds: 120)` and `dur == 180 ms`.
  - `weaveTheme(Brightness.light).textTheme.bodyMedium!.fontFamily == 'Geist'`.
  - `NoteColor.fromApi('nope') == NoteColor.values.first`.
  - Every `NoteColor`'s light ink on the light surface has a contrast of at least 4.5. Use a `contrast(Color, Color)` helper in the test.
- [x] **Step 2:** Run `flutter test test/core/theme`. Expected: FAIL (undefined).
- [x] **Step 3:** Implement, copying the values from tokens.css by hand. Text styles use `FontFeature.tabularFigures()` through a `numeric` style that times and counts use.
- [x] **Step 4:** Run the tests. Expected: PASS.
- [x] **Step 5: Checkpoint.**

### Task 3: Ids, hybrid logical clock, fractional index

**Files:**

- Create: `lib/core/ids/new_id.dart`, `lib/core/sync/hlc.dart`, `lib/core/sync/hlc_clock.dart`, `lib/core/helpers/fractional_index.dart`
- Test: `test/core/sync/hlc_test.dart`, `test/core/helpers/fractional_index_test.dart`

**Interfaces:**

- Produces:
  - `String newId()`: UUID v7.
  - `class Hlc implements Comparable<Hlc> { final int millis; final int counter; final String node; String pack(); static Hlc parse(String s); }`. The packed form is `'${millis:15 digits}-${counter:5 digits}-$node'`, so string order equals HLC order.
  - `class HlcClock { HlcClock(String node, {int Function()? now}); Hlc tick(); Hlc receive(Hlc remote); }`. Counter overflow carries into millis (the clock never issues counter `Hlc.maxCounter`); it never throws.
  - `String keyBetween(String? before, String? after)`: base-62 fractional key. `null` means open-ended.

- [x] **Step 1: Write the failing tests.**
  - `tick is strictly increasing when wall time stands still`: fixed `now`, three ticks, and `a < b < c`.
  - `pack/parse round-trip and string order equals compare order`, over 50 random HLCs.
  - `receive moves clock past a remote clock that is ahead`:
    1. Local `now` = 1000.
    2. Receive a remote with millis 3_600_000.
    3. The next `tick()` is greater than the remote.
  - `keyBetween(null, null)` is non-empty.
  - For 200 random inserts between neighbours, `a < keyBetween(a, b) < b`.
  - `keyBetween(a, null) > a`.
  - Throws `ArgumentError` if `a >= b`.
- [x] **Step 2:** Run `flutter test test/core`. Expected: FAIL.
- [x] **Step 3:** Implement.
  - HLC: the standard algorithm. `tick` sets `millis = max(now, last.millis)` and bumps `counter` when `millis` did not change. `receive` sets `millis = max(now, last, remote)`, with counter rules as in Kulkarni et al.
  - `keyBetween`: midpoint over the base-62 alphabet `0-9A-Za-z`.
- [x] **Step 4:** Run the tests. Expected: PASS.
- [x] **Step 5: Checkpoint.**

### Task 4: Database schema and `ChangeWriter`

**Files:**

- Create: `lib/core/database/tables.dart`, `lib/core/database/weave_database.dart`, `lib/core/sync/entity_type.dart`, `lib/core/sync/change_writer.dart`, `lib/core/di/core_di.dart`
- Test: `test/core/sync/change_writer_test.dart`

**Interfaces:**

- Produces:
  - **Drift tables:**
    - `Lists` (data class `ListRow`): `id` text PK, `name`, `color`, `sortKey`, `pinnedToTop` bool, `hideDone` bool, `dueDate` text?, `dueMinutes` int?, `archivedAt` int?, `deletedAt` int?, and `fieldHlcs` text (a JSON map from field to packed HLC).
    - `Items` (data class `ItemRow`): `id` PK, `listId`, `kind` (`'task' | 'text'`), `text`, `done` bool, `doneAt` int?, `indent` int (0 or 1), `sortKey`, `dueDate` text? (`yyyy-MM-dd`, local), `dueMinutes` int? (minutes after local midnight), `reminders` text (a JSON list of encoded specs), `repeat` text?, `conflictText` text?, `conflictFrom` text?, `deletedAt` int?, `fieldHlcs` text.
    - `Outbox`: `changeId` PK, `entityType`, `entityId`, `fields` text (JSON `{field: {"v": value, "h": hlc}}`), `createdAt` int.
    - `Kv`: `key` PK, `value`.
    - `MiniBars` (device-only): `listId` PK, `x`, `y`, `w`, `h` real?, `collapsed` bool.
  - **Synced field names** are the column names above, except `id`, `fieldHlcs`, `conflictText` and `conflictFrom`, which are never sent.
  - `enum EntityType { list, item }` with `apiValue` and `fromApi`.
  - `class WeaveDatabase extends _$WeaveDatabase`:
    - `WeaveDatabase(QueryExecutor e)`
    - `static WeaveDatabase open(String profile)`: file `weave_<profile>.sqlite` in the app support dir, WAL on
    - `WeaveDatabase.memory()` for tests
    - `Future<void> wipe()`, which clears every table
    - `schemaVersion = 1`
  - `class ChangeWriter`:
    - `ChangeWriter(WeaveDatabase db, HlcClock clock)`
    - `Future<void> write(EntityType type, String id, Map<String, Object?> fields)`. It upserts the row, sets `fieldHlcs[f] = hlc` for each field, and inserts one `Outbox` row. All of this is in one transaction, and every field in one call shares one `tick()`.
    - `Future<void> writeLocalOnly(...)` for fields that are never synced (`conflictText`, `conflictFrom`).
  - `HlcClock` node = device id. On first launch the device id is a `newId()` stored in `Kv('device.id')`.

- [x] **Step 1: Write the failing tests.**
  - `write inserts row, field hlcs and one outbox entry`: write `{'name': 'Errands', 'color': 'sun', 'sortKey': 'a0'}`. Then the list row exists, `fieldHlcs` has those 3 keys, and there is 1 outbox row whose `fields` JSON has `name.v == 'Errands'`.
  - `second write to one field updates only that field's hlc`.
  - `failed write rolls back row and outbox`: pass a field that does not exist, expect `ArgumentError`, and then 0 rows in both tables.
  - `wipe empties every table`.
- [x] **Step 2:** Run `dart run build_runner build -d && flutter test test/core/sync/change_writer_test.dart`. Expected: FAIL.
- [x] **Step 3:** Implement. A per-type field→column map converts the `fields` map into a companion; an unknown key throws `ArgumentError` inside the transaction. Register `WeaveDatabase`, `HlcClock` and `ChangeWriter` as lazy singletons in `registerCore`.
- [x] **Step 4:** Run the tests. Expected: PASS.
- [x] **Step 5: Checkpoint.**

---

## Phase 1 · Tasks and lists core (Day 2)

### Task 5: Domain entities and spec codecs

**Files:**

- Create: `lib/features/lists/domain/entities/task_list.dart`, `lib/features/items/domain/entities/{item.dart,due_spec.dart,reminder_spec.dart,repeat_rule.dart}`
- Test: `test/features/items/domain/specs_test.dart`

**Interfaces:**

- Produces (all `Equatable`):
  - `TaskList { id, name, NoteColor color, sortKey, pinnedToTop, hideDone, DueSpec? due, DateTime? archivedAt, DateTime? deletedAt, int openCount, int overdueCount }`. The counts are filled in by queries.
  - `enum ItemKind { task, text }`
  - `Item { id, listId, ItemKind kind, text, done, DateTime? doneAt, int indent, sortKey, DueSpec? due, List<ReminderSpec> reminders, RepeatRule? repeat, List<ItemConflict> conflicts, DateTime? deletedAt }`. `conflicts` is in arrival order (may differ between devices).
  - `DueSpec { DateTime date /* local midnight */, int? minutes; DateTime? at() /* local DateTime or null if no time */; String encodeDate(); static DueSpec? decode(String? date, int? minutes); }`
  - `sealed class ReminderSpec`, with `AtDue()`, `Before(Duration offset)` and `AtTime(DateTime local)`:
    - `String encode()` gives `'due' | 'before:<minutes>' | 'at:<yyyy-MM-ddTHH:mm>'`
    - `static ReminderSpec? decode(String)`
  - `RepeatRule { RepeatUnit unit /* day, weekdays, week, month */, int every }`:
    - encodes as `'day:1' | 'weekdays' | 'week:2' | 'month:1'`
    - has `DueSpec next(DueSpec from)`
  - `ItemConflict { String otherText, String fromDevice }`

- [x] **Step 1: Write the failing tests.**
  - Encode/decode round-trip for every spec variant.
  - `decode('garbage') == null`.
  - `RepeatRule(weekdays).next(Fri 2026-11-06) == Mon 2026-11-09`, with the time kept.
  - `RepeatRule(month,1).next(2026-01-31) == 2026-02-28`, clamped to the month's last day.
  - `RepeatRule(day,3).next(d) == d + 3 days`.
- [x] **Step 2:** Run the tests. Expected: FAIL.
- [x] **Step 3:** Implement. Domain imports nothing from Flutter or Drift.
- [x] **Step 4:** Run the tests. Expected: PASS.
- [x] **Step 5: Checkpoint.**

### Task 6: QuickParse and labels

**Files:**

- Create: `lib/core/helpers/quick_parse.dart`, `lib/core/helpers/due_label.dart`
- Test: `test/core/helpers/quick_parse_test.dart`

**Interfaces:**

- Consumes: `DueSpec` (Task 5)
- Produces:
  - `class ParsedCapture { final String text; final DueSpec? due; }`
  - `ParsedCapture quickParse(String raw, DateTime now)`: a port of `parseQuick` in `docs/design-02/assets/data.js:112`
  - `String dueLabel(DueSpec due, DateTime now)`: "Today 17:00", "Tomorrow 18:00", "Fri 10:00", "Thu 12 Nov"; any date more than 6 days away uses the `dateLabel` form.
  - `String parseReadBack(ParsedCapture p, DateTime now)` gives "Due Tomorrow 18:00".

- [x] **Step 1: Write the failing tests.** Use `now = 2026-11-05 15:00` (a Thursday).
  - `'call mom tomorrow 6pm'` → text `'call mom'`, due 2026-11-06 18:00.
  - `'dentist fri 10am'` → `'dentist'`, 2026-11-06 10:00.
  - `'buy milk tonight'` → 20:00 today.
  - `'standup 9:30'` → 2026-11-06 09:30, because that time today has passed.
  - `'review 18:00'` → today 18:00.
  - `'stretch in 2 h'` → today 17:00.
  - `'tea in 30 min'` → 15:30.
  - `'plain task'` → due null.
  - `dueLabel(2026-11-12)` → `'Thu 12 Nov'`.
- [x] **Step 2:** Run the tests. Expected: FAIL.
- [x] **Step 3:** Implement by porting the regex set from data.js; keep its token list (today, tonight, tomorrow, weekday names and 3-letter forms, `h:mm`, `ham/pm`, `in N h|min`).
- [x] **Step 4:** Run the tests. Expected: PASS.
- [x] **Step 5: Checkpoint.**

### Task 7: Lists repository and use cases

**Files:**

- Create: `lib/features/lists/domain/repositories/lists_repository.dart`, `lib/features/lists/data/lists_repository_impl.dart`, `lib/features/lists/domain/usecases/{create_list,update_list,archive_list,restore_list,trash_list,delete_list_forever,reorder_list}.dart`, `lib/core/di/lists_di.dart`
- Test: `test/features/lists/lists_repository_test.dart`

**Interfaces:**

- Consumes: `ChangeWriter.write`, `WeaveDatabase`, `TaskList`, `keyBetween`
- Produces:
  - `abstract class ListsRepository`:
    - `Stream<List<TaskList>> watchActive()`: not archived and not deleted. Pinned first, then by `sortKey`. Has `openCount` and `overdueCount`.
    - `Stream<List<TaskList>> watchArchived()`
    - `Stream<List<TaskList>> watchTrashed()`
    - `Stream<TaskList?> watch(String id)`
    - `Future<String> create(String name, NoteColor color)`: `sortKey` goes after the last list.
    - `Future<void> update(String id, Map<String, Object?> fields)`
    - `Future<void> purgeTrash(DateTime now)`: hard-deletes lists and their items whose `deletedAt` is more than 30 days old. Each such list is purged like delete forever: pending outbox rows for the list and its items are dropped, the purge marker (`deletedAt = 0`) is sent, the rows and `mini_bars` row are removed, and every id is recorded as `purged.<id>`.
  - Use cases are `call(...)` wrappers, one per file. `TrashList` sets `deletedAt` to now; `RestoreList` sets `deletedAt` and `archivedAt` to null; `DeleteListForever` writes `deletedAt = 0`, the purge marker, removes the rows locally and records purged ids; undo (`restoreSnapshot`) unmarks them and drops a not-yet-pushed marker. Cross-device undo after the marker was pushed is not supported. Each returns what Undo needs, the previous field values as `Map<String, Object?>`.

- [x] **Step 1: Write the failing tests** (in-memory DB).
  - `create then watchActive emits list with openCount 0`.
  - `archive hides from active and shows in archived`.
  - `trash then restore returns list to active`.
  - `pinnedToTop sorts first`.
  - `overdueCount counts open tasks due before now`.
  - `purgeTrash removes lists trashed > 30 days ago and their items`.
  - `undo map from TrashList restores exact previous fields`.
- [x] **Step 2:** Run the tests. Expected: FAIL.
- [x] **Step 3:** Implement. Counts come from one grouped Drift query joined to the list stream, with no query per list (NFR5).
- [x] **Step 4:** Run the tests. Expected: PASS.
- [x] **Step 5: Checkpoint.**

### Task 8: Items repository, task rules, Up next query

**Files:**

- Create: `lib/features/items/domain/repositories/items_repository.dart`, `lib/features/items/data/items_repository_impl.dart`, `lib/features/items/domain/usecases/{add_item,edit_text,toggle_done,set_due,set_reminders,set_repeat,move_item,indent_item,delete_item,uncheck_all,resolve_conflict}.dart`, `lib/core/di/items_di.dart`
- Test: `test/features/items/items_rules_test.dart`

**Interfaces:**

- Consumes: `ChangeWriter`, `Item`, `DueSpec`, `ReminderSpec`, `RepeatRule`, `quickParse`, `keyBetween`
- Produces:
  - `abstract class ItemsRepository`:
    - `Stream<List<Item>> watchList(String listId)`. Order: text lines first, by `sortKey`; then open tasks (overdue first, then by due ascending, then untimed by `sortKey` with newest first); then done tasks by `doneAt` descending.
    - `Stream<List<Item>> watchUpNext(DateTime now)`: open tasks due today or earlier, from lists that are not archived and not deleted.
    - `Stream<List<Item>> watchLaterThisWeek(DateTime now)`: open tasks due after today and within 6 days.
    - `Stream<List<Item>> search(String q)`: `LIKE %q%`, case-insensitive, at most 100 results.
    - `Future<void> update(String id, Map<String, Object?> fields)`
  - Use cases:
    - `AddItem.call(String listId, String raw, DateTime now)`: parses with `quickParse` and returns the new id.
    - `ToggleDone.call(String id, DateTime now)`. **If `repeat != null` and the task is being ticked, it does not mark the task done:** it sets `due = repeat.next(due)` and keeps the task open. `Before` reminders move with the due, as stored offsets.
    - `SetDue.call(id, DueSpec?)`: `Before` reminders are kept, and they shift automatically because they are offsets (F4.2).
    - `UncheckAll.call(listId)`: one `write` per done item.
    - `MoveItem.call(id, {String? afterId, String? beforeId})`
    - `IndentItem.call(id, int indent)`: 0 or 1.
    - `ResolveConflict.call(id, ConflictChoice c, {int index = 0})`, with `enum ConflictChoice { keepBoth, keepMine, keepTheirs }`. `Item.conflicts` lists the losers, each `(otherText, fromDevice)`:
      - `keepMine` keeps the current `text`.
      - `keepTheirs` takes the loser at `index` as the text.
      - `keepBoth` adds the loser at `index` as a new task right after the item.
      - Every choice clears `conflictText` and `conflictFrom` through `writeLocalOnly`.
    - Each mutating use case returns the previous field map for Undo.

- [x] **Step 1: Write the failing tests.**
  - `add parses due from raw text`
  - `watchList orders overdue, timed, untimed, then done`
  - `ticking repeating weekly task moves due +7 days and stays open`
  - `SetDue keeps Before reminders`
  - `uncheckAll clears every done item in list only`
  - `upNext excludes archived lists and future tasks`
  - `laterThisWeek includes day +6, excludes day +7`
  - `resolve keepBoth inserts new task after original and clears conflict`
  - `search matches case-insensitively across lists`
- [x] **Step 2:** Run the tests. Expected: FAIL.
- [x] **Step 3:** Implement. Orders are done in SQL (`ORDER BY` with CASE), not in Dart.
- [x] **Step 4:** Run the tests. Expected: PASS.
- [x] **Step 5: Checkpoint.** End of Day 2.

---

## Phase 2 · Sync (Day 3, the priority)

### Task 9: Transport interface, in-memory transport, payload cipher seam

**Files:**

- Create: `lib/core/sync/sync_transport.dart`, `lib/core/sync/in_memory_sync_transport.dart`, `lib/core/sync/payload_cipher.dart`
- Test: `test/core/sync/in_memory_transport_test.dart`

**Interfaces:**

- Produces:
  - `class RemoteChange { final String changeId; final EntityType type; final String entityId; final String deviceId; final String hlc; final String payload; }`
  - `class PulledChange { final int seq; final RemoteChange change; }`
  - `abstract class SyncTransport`:
    - `Future<void> push(List<RemoteChange> changes)`: idempotent on `changeId`.
    - `Future<List<PulledChange>> pull({required int afterSeq, int limit = 500})`: ordered by `seq`.
    - `Stream<void> hints()`: emits when another device inserts.
    - `Future<void> touchDevice(String id, String name, String platform)`
    - `Future<List<DeviceInfo>> devices()`
  - `class DeviceInfo { id, name, platform, DateTime lastSeen }`
  - `abstract class PayloadCipher { Future<String> seal(EntityType t, String entityId, Map<String, FieldValue> fields); Future<Map<String, FieldValue>> open(EntityType t, String entityId, String payload); }`
  - `class FieldValue { final Object? v; final String h; }`
  - `class PassthroughPayloadCipher implements PayloadCipher`: JSON, then base64. `open` throws `FormatException` on bad input.
  - `class InMemorySyncTransport implements SyncTransport`:
    - a shared static store, created per test with `InMemorySyncTransport.newServer()`, that returns a factory
    - `bool offline`: when true, push and pull throw `SyncOfflineException`
    - `void commitOutOfOrder()`: a test hook that makes the next push's rows visible only after a later push

- [x] **Step 1: Write the failing tests.**
  - `pushing same changeId twice stores once`
  - `pull afterSeq returns only newer rows in order`
  - `hints fire for other clients, not the pusher`
  - `offline throws SyncOfflineException`
  - `cipher round-trip`
  - `cipher open on garbage throws FormatException`
- [x] **Step 2:** Run the tests. Expected: FAIL.
- [x] **Step 3:** Implement.
- [x] **Step 4:** Run the tests. Expected: PASS.
- [x] **Step 5: Checkpoint.**

### Task 10: ChangeMerger (applying remote changes)

**Files:**

- Create: `lib/core/sync/change_merger.dart`
- Test: `test/core/sync/change_merger_test.dart`

**Interfaces:**

- Consumes: `WeaveDatabase`, `HlcClock.receive`, `FieldValue`, `EntityType`
- Produces: `class ChangeMerger { ChangeMerger(WeaveDatabase db, HlcClock clock, ChangeWriter writer, Future<String> Function(String deviceId) deviceName); Future<MergeResult> apply(RemoteChange meta, Map<String, FieldValue> fields); }` with `enum MergeResult { applied, ignored, conflict, resurrected }`.

**Rules, in order, inside one transaction:**

1. Call `clock.receive` with the newest of `meta.hlc` and every field's `h` (counter overflow carries into millis; never throws). An HLC (`meta.hlc`, a field `h`, or `b`) that does not parse, whose counter is at or above `Hlc.maxCounter`, or whose millis are at or above 10^14 (no real clock; it would push the clock past the 15-digit packed form) is malformed; a malformed `b` counts as absent; such a field is skipped, and a malformed `meta.hlc` makes the change `ignored` with nothing touched.
2. For each field, if the remote `h` is greater than the local `fieldHlcs[f]` (or there is none), set the column and the field's HLC. Otherwise skip it.
3. **Text conflict (base version):** every `text` write carries `b`, the text HLC it was made on top of. The device also keeps the base of its current text in `fieldHlcs['text.b']` (local only, never synced, never a field). For an incoming `text` (`h`, `b`, value) against local text HLC `L`, base `Lb`:
   - no `L` → apply (rule 2);
   - `h == L` or `h == Lb` → already seen, skip;
   - same device (node) as `L`: older → skip (ancestor or a loser already kept), newer → apply, no conflict. Relies on node = device id and a device id never being reused with a reset clock;
   - `b == L` → made on top of ours: rule 2, no conflict;
   - otherwise the edits are concurrent. Same value → rule 2, no conflict. Different values → the greater HLC wins on every device (no re-write, no new outbox entry) and the loser becomes `conflictText`, with `conflictFrom` = the device that wrote the loser. Result `conflict`. An unresolved conflict is never overwritten: a new loser is appended, in arrival order (may differ between devices). Each loser keeps its text, device name and HLC: `conflictText` is a JSON array of texts and `conflictFrom` is `{"from": [...], "hlc": [...]}`, read and written only through `lib/core/sync/conflict_losers.dart`; a legacy plain string reads as one loser.
   - **Loser set rules (same set on every device):** an edit made on top of a kept loser (`b` equals its HLC), or on top of a later edit by that loser's device, replaces it (as a loser if it loses, or by becoming the text). An incoming loser older than a kept loser from the same device is ignored. A loser already kept (exact text) is not added again, so redelivery is ignored. Whenever the merger sets the text, a loser equal to it is dropped. The result is `conflict` only when a new loser is stored; otherwise `applied` (text changed or losers dropped) or `ignored`.
   - Conflict columns are never synced: Resolving on one device doesn't clear the other's conflict rows, except that a loser identical to the current text is dropped automatically.
   - A payload without `b` (older format), or with a `b` not older than its `h`, counts as concurrent only while a local text edit is pending in the outbox; otherwise as sequential.
4. **Edit vs delete:** if the row has `deletedAt != null` and the incoming change touches any field other than `deletedAt`, with an HLC greater than `fieldHlcs['deletedAt']`, set `deletedAt = null` (written through the writer so other devices follow) and return `resurrected`.
5. **Trash vs newer edit:** an incoming trash (`deletedAt` > 0) is not applied when the row has any synced field newer than it; instead `deletedAt = null` is written through the writer and the result is `resurrected`.
6. Missing row plus a remote change: insert it, with default values for absent fields. An item insert with no `listId`, or whose list is purged, is ignored (no orphans).
7. `deletedAt == 0` (purge marker): hard-delete locally (a list takes its items and its `mini_bars` row), drop pending outbox rows for those ids, and record `purged.<id>` for each. Late changes for a purged id or a purged list are ignored. Delete forever and trash purge on the deleting device do the same.

Field maps live once in `lib/core/sync/synced_fields.dart`; purge keys and clean-up in `lib/core/sync/purge_log.dart`.

- [x] **Step 1: Write the failing tests.**
  - `newer remote field wins, older ignored`
  - `different fields from two devices both survive`
  - `concurrent text edits keep both`: newer HLC wins, loser in `conflictText` (with `conflictFrom`), result `conflict`
  - `remote text edit without pending local edit just applies`
  - `edit after delete resurrects`
  - `purge marker deletes row`
  - `unknown field in payload is ignored, not thrown`: forward compatibility
  - `apply is idempotent`: the same change twice leaves the same row
- [x] **Step 2:** Run the tests. Expected: FAIL.
- [x] **Step 3:** Implement.
- [x] **Step 4:** Run the tests. Expected: PASS.
- [x] **Step 5: Checkpoint.**

### Task 11: SyncEngine and status

**Files:**

- Create: `lib/core/sync/sync_engine.dart`, `lib/core/sync/sync_status.dart`, `lib/core/di/sync_di.dart`
- Test: `test/core/sync/sync_engine_test.dart`

**Interfaces:**

- Consumes: `SyncTransport`, `PayloadCipher`, `ChangeMerger`, `WeaveDatabase` (Outbox, Kv), connectivity_plus
- Produces:
  - `enum SyncStatus { localOnly, synced, syncing, offline, error }`
  - `class SyncEngine`:
    - `SyncEngine({required WeaveDatabase db, required SyncTransport transport, required PayloadCipher cipher, required ChangeMerger merger, required String deviceId})`
    - `Stream<SyncStatus> get status`
    - `Stream<MergeEvent> get events`, where `MergeEvent(conflict | resurrected, entityId)` feeds a toast
    - `Future<void> syncNow()`
    - `void start()`: subscribes to outbox inserts (debounced 300 ms), `transport.hints()`, connectivity regained, and a 60 s fallback timer
    - `Future<void> stop()`
  - `syncNow` does, **pull first, then push**. Conflicts are detected by base HLC (`b`), not by the outbox. Pull first is kept so old-format payloads without `b` still see the pending local edit, and so one pass converges.
    1. **Pull:** loop `pull(afterSeq: max(0, cursor - 100))` until there are fewer than 500 rows. Skip rows where `deviceId == self`. `open`, then `merger.apply`. Store `Kv('sync.cursor') = max seq seen`.
    2. **Push:** read the outbox oldest first, in batches of 200. `seal` each, `push`, and **delete only the acked batch**.
    3. A single `FormatException` from `open` → log the id, put the change in `Kv('sync.quarantine.<changeId>')`, and continue.
  - Status mapping: `SyncOfflineException` or no connectivity → `offline`. Other errors → `error`, with exponential backoff of 2, 4, 8 … 60 s. A successful pass with an empty outbox → `synced`.
  - `class SyncStatusCubit extends Cubit<SyncStatus>`: global; mirrors `status`, and `localOnly` when signed out.
- **Implementation decisions (Task 11):**
  - Dedupe: `Kv('sync.applied.<changeId>') = seq`, written with the cursor in the row's transaction (the merger's transaction nests as a drift savepoint). Pruned after each pull for `seq < cursor - 100` (below the re-read window), so at most ~100 + one page are kept. No schema change.
  - Quarantine: `Kv('sync.quarantine.<changeId>')` = JSON of the raw row plus `reason` (`unreadable` | `blocked`). Later-`seq` changes for a quarantined entity id are quarantined too, across passes. The cursor advances past them. Replay is not built yet.
  - Device names: `DeviceNames` (`lib/core/sync/device_names.dart`) reads `Kv('device.name.<id>')`. It returns this device's own name, or "Another device" as a fallback. Task 12 calls `upsert` with names from the devices table.
  - Apply errors: an error from `cipher.open` other than `FormatException`, or any error from the merger, is transient. It is not quarantined, since a transient DB error would park valid changes with no replay. The pull stops at that row, so the cursor does not pass it, and push still runs. The pass then ends as `error` with backoff, and the next pass retries the row.
  - Known limit (multi-page catch-up): a late commit that lands deep in an early page of a long catch-up can fall below the final `cursor - 100` and is never read. Accepted for the 7-day build. Task 12 should keep server-side commit lag small, e.g. short insert transactions.
  - Connectivity: `start()` asks for the current connectivity once before the first pass, because plugin streams need not replay it. `stop()` forgets connectivity and backoff, so a later `start()` never keeps a stale `offline`. The first connectivity report after `start()` does not add a pass; only a regain (false → true) does. `SyncOfflineException` schedules a retry with the same backoff, and the status stays `offline`.
  - Status: the engine starts as `syncing`. `stop()` leaves the status as it was, so a pass cut short stays `syncing`. That is harmless because `stop()` is only used for sign-out and dispose, and the cubit shows `localOnly` once signed out. `dispose()` = `stop()` + closing the streams.
  - Concurrency: one pass at a time; a `syncNow` during a pass makes that pass run once more and returns its future. `stop()` cancels triggers and awaits the pass, which stops at the next row/batch boundary. Automatic triggers (outbox insert, hint, 60 s tick) share the 300 ms debounce and are held while an error retry is pending. Connectivity regained runs at once.
  - Engine extras: `connectivity` (`Stream<bool>`), `SyncTiming`, `now` and `log` are injectable. `current` and `retryIn` getters exist. `MergeEvent(MergeKind, entityId)` is emitted after commit.
  - Wiring: `registerSync(sl, transport: …)` / `unregisterSync(sl)` in `lib/core/di/sync_di.dart`. It is not called yet: Task 12 calls it from `bootstrap` (main engine only) with the Supabase transport, and Task 13 passes `signedIn`/`signedInNow`. Until then the cubit stays `localOnly`.

- [x] **Step 1: Write the failing tests.** Two engines, A and B, each with its own in-memory DB and the same `InMemorySyncTransport` server.
  - `two engines converge on lists and items`: A creates a list and 3 items; `syncNow` on both; B sees the same rows.
  - `offline edits converge when back online`:
    1. B is offline.
    2. A and B each edit different items.
    3. B goes online.
    4. Sync both twice.
    5. Both are equal.
  - `concurrent text edits keep both across devices`: both edit the same item while offline, then sync. Both devices end with the same `text` (the greater HLC) and the same set of losers (order may differ), each with the device that wrote it.
  - `push failure keeps outbox rows`: the transport throws on push → outbox count is unchanged and status is `error`.
  - `late commit with lower seq is still applied`: use `commitOutOfOrder()`; after two syncs B has both changes.
  - `delete on A trashes on B`
  - `status goes syncing → synced`
  - `pull runs before push`: a transport spy records the call order `[pull, push]`
- [x] **Step 2:** Run the tests. Expected: FAIL.
- [x] **Step 3:** Implement. Only the main engine registers `SyncEngine` (not `entrypoints/mini_bar_main.dart`).
- [x] **Step 4:** Run the tests. Expected: PASS.
- [x] **Step 5: Checkpoint.**

### Task 12: Supabase transport, realtime hints, devices — **Day 3 gate**

**Files:**

- Create: `lib/core/sync/supabase_sync_transport.dart`
- Test: `integration_test/sync_supabase_test.dart`

**Interfaces:**

- Consumes: `SupabaseClient`, `SyncTransport` (Task 9)
- Produces: `class SupabaseSyncTransport implements SyncTransport { SupabaseSyncTransport(SupabaseClient c); }`
  - `push` → `from('changes').upsert(rows, onConflict: 'change_id', ignoreDuplicates: true)`
  - `pull` → `select().gt('seq', afterSeq).order('seq').limit(limit)`. Map rows with `is` checks; skip malformed rows.
  - `hints` → a `channel('changes')` subscription to `postgres_changes` INSERT on `public.changes`, filtered on `user_id=eq.<uid>`. Emit only when `device_id != self`. Resubscribe when the auth user changes.
  - `touchDevice` → upsert on `devices`
  - Network `SocketException`, `ClientException` or a timeout of 10 s → `SyncOfflineException`

- **Implementation decisions (Task 12):**
  - Transport: `SupabaseSyncTransport(client, deviceId: …)` (the self id is needed for hint filtering). Push upserts with `defaultToNull: false` so `user_id` takes its `auth.uid()` default. Pull and `devices()` turn off PostgREST's built-in GET retries (1 + 2 + 4 s) so offline shows at once and the engine's backoff is the only retry. `IOException` (incl. `SocketException`), http `ClientException` and a 10 s timeout → `SyncOfflineException`; server errors (e.g. `PostgrestException`) stay errors. Malformed rows are skipped and logged by seq. `pull` returns a `PulledPage` (`rows`, `full` = raw row count reached the limit, `lastSeq` = highest raw seq); the engine pages on while `full` and continues from `lastSeq`, so a malformed row never stalls a catch-up (no extra request). `AuthRetryableFetchException` (session refresh offline) → `SyncOfflineException`. Every request carries the 10 s timeout as its own request timeout (aborts a stalled request); an outer 15 s `Future.timeout` is a backstop.
  - Hints: one realtime channel per transport, topic `changes:<deviceId>` (two transports on one client must not share a topic). Open only while `hints()` has listeners; reopened when the auth user changes (current user re-read per auth event, since the auth stream replays) and after `channelError`/`timedOut` or a server-side `closed` while that channel is current (5 s doubling to 60 s); our own closes bump a generation first, so they stay quiet. Closing on the last listener's cancel is queued with the reopens, so cancel-then-listen always ends with one channel. The realtime token is set before joining. It also emits once per (re)subscribe, so inserts missed while disconnected are pulled. Hints use the engine's 300 ms debounce (Task 11); measured A→B latency 1.6–1.8 s.
  - Dispose: `unregisterSync` disposes the transport (`SupabaseSyncTransport.dispose`: channel, auth listener, hints stream); `registerSync` takes ownership of the transport.
  - Device names: `DeviceDirectory` (`lib/core/sync/device_directory.dart`). `startSync(sl)` starts the engine and, in the background, `touchDevice` + one devices read into `DeviceNames`. The engine's new `onForeignDevices` hook passes each pulled page's other device ids before applying; the directory refreshes only for an id not seen in the table, at most once per 30 s, and waits for a refresh already in flight. Errors never fail a pass. `unregisterSync` disposes it, so an in-flight read never writes the old account's names after sign-out.
  - Bootstrap (main entrypoint only): Supabase init failure or empty URL/key → local-only (a plain `SyncStatusCubit`, `localOnly`). Otherwise `registerSync` with the Supabase transport and `signedIn` from auth; `startSync` only when a session was restored. Task 13 calls `startSync(sl)` after sign-in. `AppConfig.fromEnvironment` still throws when the defines are missing (Task 1 behaviour).
  - The flavored macOS project needs `--flavor dev` (see Steps 2 and 4). The migration needed no change.

- [x] **Step 1: Write the integration test.** It is skipped unless `config/dev.json` also defines `TEST_EMAIL` and `TEST_PASSWORD`, for a dedicated test user.
  1. Sign in.
  2. Create 2 `SyncEngine`s with different device ids, different in-memory DBs and the real transport.
  3. A creates a list.
  4. B receives a hint and pulls.
  5. Assert B has the list **within 3 s** (NFR1).
  6. Then run the offline-edit case from Task 11 with the real backend.
  7. Clean up: delete the user's `changes` rows.
- [x] **Step 2:** Run `flutter test integration_test/sync_supabase_test.dart -d macos --flavor dev --dart-define-from-file=config/dev.json`. Expected: FAIL.
- [x] **Step 3:** Implement.
- [x] **Step 4:** Run it (same command, with `--flavor dev`). Expected: PASS, with the measured latency printed.
- [x] **Step 5: Checkpoint. Gate:** do not start Phase 3 until this passes.

### Task 13: Auth gateway, session, bulk upload, sign out, delete account

**Files:**

- Create: `lib/core/auth/auth_gateway.dart`, `lib/core/auth/supabase_auth_gateway.dart`, `lib/core/sync/bulk_uploader.dart`, `lib/features/account/presentation/session_cubit.dart`, `lib/core/di/account_di.dart`
- Test: `test/features/account/session_cubit_test.dart`

**Interfaces:**

- Produces:
  - `abstract class AuthGateway`:
    - `Stream<AuthUser?> get user`
    - `AuthUser? get current`
    - `Future<void> signIn(String email, String password)`: throws `AuthFailure(AuthError code)`
    - `Future<void> signUp(String email, String password)`
    - `Future<void> signOut()`
    - `Future<void> deleteAccount()`: `rpc('delete_account')`, then sign out
  - `class AuthUser { id, email }`
  - `enum AuthError { wrongPassword, emailInUse, weakPassword, network, unknown }`
  - `sealed class SessionState`: `LocalSession()`, `Uploading(int done, int total)`, `SignedIn(AuthUser)`, `SigningOut()`
  - `class SessionCubit extends Cubit<SessionState>`, with `signIn(email, password)`, `signUp(...)`, `signOut()` and `deleteAccount()`
  - `class BulkUploader { Future<int> enqueueAll(); }` writes one outbox change per existing list and item, with all fields and current HLCs. It returns the count. Progress is `total - outboxCount`.
- Rules:
  - Sign in when local data exists: `enqueueAll`, then `Uploading` until the outbox is empty, then `SignedIn`, then `syncEngine.start()`. That run pulls the account's existing data, and the merge combines them.
  - Sign out: `syncEngine.stop()`, then `db.wipe()` (which includes `Kv`), then cancel all notifications, then `auth.signOut()`, then `LocalSession`. A new device id is generated on the next sign-in.
  - Delete account: `auth.deleteAccount()`, then the same wipe, then `LocalSession`.
  - App start with a stored Supabase session → `SignedIn` with no upload.

- [ ] **Step 1: Write the failing tests** (fake `AuthGateway`, in-memory transport).
  - `signIn with local data emits Uploading then SignedIn`
  - `sign out wipes lists, items, outbox and cursor`
  - `deleteAccount calls gateway and wipes`
  - `wrong password surfaces AuthError.wrongPassword and stays LocalSession`
  - `local mode never touches transport`: a transport spy records 0 calls
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3:** Implement. `supabase_flutter` persists the session on its own.
- [ ] **Step 4:** Run the tests. Expected: PASS.
- [ ] **Step 5: Checkpoint.** End of Day 3.

---

## Phase 3 · App screens I (Day 4)

General rule for every UI task:

- Match the prototype at `docs/design-02/03-app/index.html` (desktop) and its phone views (`#os=ios`, `#os=android`).
- Read `app.js` and `app.css` for the exact copy, order and sizes.
- Widget tests check the copy and behaviour that the playbook pins, not pixels.
- Before each checkpoint, compare by hand with the prototype at 1440 px and on a phone.

### Task 14: App shell, routing, sync badge, undo toast

**Files:**

- Create: `lib/app/router.dart`, `lib/app/shell/desktop_shell.dart`, `lib/app/shell/phone_shell.dart`, `lib/app/shell/sidebar.dart`, `lib/app/shell/tab_bar.dart`, `lib/core/widgets/sync_status_badge.dart`, `lib/core/widgets/undo_toast.dart`
- Test: `test/app/shell_test.dart`

**Interfaces:**

- Consumes: `ListsRepository.watchActive`, `SyncStatusCubit`, `SessionCubit`
- Produces:
  - `enum AppRoute { upNext('/'), list('/list/:id'), archive('/archive'), search('/search'), settings('/settings'), lists('/lists') }`. `lists` is phone-only.
  - `class UndoToast { static void show(BuildContext c, String message, Future<void> Function() undo); }`: 4 s, bottom centre, above the add bar on phones (playbook §9 Undo).
  - `SyncStatusBadge` copy:
    - "Synced · N devices"
    - "Syncing…"
    - "Offline · saved here"
    - "Can't sync" + Retry
    - "On this Mac only" / "On this PC only" / "On this phone only" when `localOnly`
  - Layout switch: width ≥ 720 → `DesktopShell` (sidebar 256 / 224 under 1100); otherwise `PhoneShell` with the tab bar Up next · Lists · Search · Settings. The tab bar uses iOS styling (filled icon for the current tab) or Material styling (pill) from `defaultTargetPlatform`.
  - Sidebar: search field (⌘K / Ctrl+K), Up next, lists (dot, name, open count), "New list" (⌘N / Ctrl+N), Archive and trash, the sync line, and the user row.

- [ ] **Step 1: Write the failing tests.**
  - `wide layout shows sidebar with lists and counts`
  - `narrow layout shows 4 tabs`
  - `badge shows "Offline · saved here" for offline`
  - `undo toast calls undo when tapped and disappears after 4 s`
  - `Ctrl+K focuses search`
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the tests. Expected: PASS. Then run the app on macOS and an Android emulator and compare with the prototype.
- [ ] **Step 5: Checkpoint.**

### Task 15: Up next screen with day thread and quick capture

**Files:**

- Create: `lib/features/up_next/presentation/{up_next_cubit.dart,up_next_page.dart}`, `lib/core/widgets/{quick_capture_field.dart,day_thread.dart,item_tile.dart}`
- Test: `test/features/up_next/up_next_test.dart`, `test/core/widgets/quick_capture_field_test.dart`

**Interfaces:**

- Consumes: `ItemsRepository.watchUpNext/watchLaterThisWeek`, `AddItem`, `ToggleDone`, `quickParse`, `parseReadBack`
- Produces:
  - `QuickCaptureField({required String? listId, required ValueChanged<String> onListChange, required Future<void> Function(String raw) onSubmit})`:
    - height 40 (44 for the phone add bar)
    - list chip inside the field
    - a parse line below whose height is always reserved: the hint "Times work too: 6pm, tomorrow, in 2 h" while it is empty and focused, and the read-back once there is text
    - Enter submits and clears; there is no Add button
    - its default list is the `capture` pref (Task 20) or the first list
  - `ItemTile({required Item item, required String? listName, VoidCallback? onTap})`: the checkbox ticks; the time is right-aligned and red when overdue; done tasks show a solid strike.
  - `DayThread({required List<Item> today, required DateTime now})`: 07:00–23:00, the lived part in ink, filled / red-ring / hollow marks. On phones it becomes the one-line strip (C9).

- [ ] **Step 1: Write the failing tests.**
  - `typing "tomorrow 6pm" shows "Due Tomorrow 18:00" before Enter`
  - `Enter adds to chosen list and clears field`
  - `up next lists overdue first in red with list name`
  - `ticking shows undo toast and undo reopens task`
  - `empty state copy from prototype when nothing is due`
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the tests. Expected: PASS.
- [ ] **Step 5: Checkpoint.**

### Task 16: List screen

**Files:**

- Create: `lib/features/lists/presentation/{list_cubit.dart,list_page.dart,widgets/list_header.dart,widgets/list_more_menu.dart,widgets/done_group.dart,widgets/color_picker.dart}`, `lib/features/lists/presentation/new_list_dialog.dart`
- Test: `test/features/lists/list_page_test.dart`

**Interfaces:**

- Consumes: `ListsRepository`, `ItemsRepository.watchList`, the item use cases (Task 8), `QuickCaptureField`, `ItemTile`, `UndoToast`
- Produces:
  - `ListCubit(listId)` with state `{TaskList list, List<Item> items, String? selectedItemId, bool showHidden}`
  - The list page:
    - 760 px reading width
    - title dot (opens the colour picker) and editable title
    - the add field at the top
    - items in repository order
    - a collapsed **Done · N** group, or, when `hideDone` is on, a "N done, hidden · Show" line
    - inline editing: Enter adds the next item, Backspace on empty deletes, Tab / Shift+Tab indents, Alt+↑/↓ moves
    - drag to reorder
  - `ListMoreMenu` (•••): Rename · Colour · Pin to top · **Show in mini bar** (desktop only, writes `MiniBars`) · Due date for the list · Hide done tasks · Uncheck all · Archive · Delete. Archive, Delete and Uncheck all show an Undo toast.
  - A selected task opens the details panel beside the list on desktop and a bottom sheet on phones (Task 17).

- [ ] **Step 1: Write the failing tests.**
  - `add field adds parsed task at correct position`
  - `Done group collapsed shows count`
  - `hide done replaces group with "2 done, hidden · Show"`
  - `Alt+Down moves item below next`
  - `Tab indents to 1, Shift+Tab back to 0`
  - `archive from menu navigates to Up next and shows undo`
  - `uncheck all reopens all done`
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the tests. Expected: PASS. **Manual check on two devices:** macOS dev profile plus Android, both signed in. Ticking on one shows up on the other within 3 s.
- [ ] **Step 5: Checkpoint.** End of Day 4.

---

## Phase 4 · App screens II and reminders (Day 5)

### Task 17: Task details

**Files:**

- Create: `lib/features/items/presentation/task_details/{task_details_cubit.dart,task_details_panel.dart,due_section.dart,remind_section.dart,repeat_section.dart}`
- Test: `test/features/items/task_details_test.dart`

**Interfaces:**

- Consumes: `SetDue`, `SetReminders`, `SetRepeat`, `MoveItem`, `DeleteItem`, `dueLabel`
- Produces: `TaskDetailsPanel({required String itemId})`, following design playbook §9 "Task details" and the 03 prototype:
  - **Due:** Today · Tomorrow · Next Mon · None, then 09:00 · 13:00 · 17:00 · 20:00 · Other date (`showDatePicker`) · Other time (`showTimePicker`).
  - **Remind me:** a multi-select with `aria-pressed` semantics (`Semantics(toggled:)`). With a due: At due time · 15 min / 1 h / 1 day before. Always: In 1 h (stored as `AtTime(now + 1h)`) · Tomorrow 09:00 · At a time. None clears.
  - **Repeat:** Daily · Weekdays · Weekly · Monthly · Never · Custom ("Every [n] [days/weeks/months]").
  - Order: Move up / Move down. Footer: Delete task, with Undo.
  - Desktop: a panel with a close button. Phone: a modal bottom sheet. Esc closes it.

- [ ] **Step 1: Write the failing tests.**
  - `choosing Tomorrow then 17:00 sets due`
  - `selecting two reminders stores both; None clears`
  - `"15 min before" disabled when no due`
  - `custom repeat every 2 weeks stores week:2`
  - `Esc closes panel`
  - `delete shows undo and undo restores`
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the tests. Expected: PASS.
- [ ] **Step 5: Checkpoint.**

### Task 18: Conflict row and merge notices

**Files:**

- Create: `lib/features/items/presentation/conflict_row.dart`
- Modify: `lib/core/widgets/item_tile.dart`, `lib/app/shell/sidebar.dart`
- Test: `test/features/items/conflict_row_test.dart`

**Interfaces:**

- Consumes: `Item.conflicts`, `ResolveConflict`, `SyncEngine.events`
- Produces:
  - An `ItemTile` with a conflict shows both versions. Label `text` by the node of `fieldHlcs['text']` ("This Mac" / "This PC" / "This phone" when it is this device) and each loser by its own device name ("This Mac" etc. when it equals this device). Several losers show one row each (from `Item.conflicts`), and the resolve buttons pass that loser's `index`. Each version has **Keep both** and a **Keep only this** button per version, as in the 03 Groceries sample.
  - Undo restores the conflict.
  - Resolving on one device doesn't clear the other's conflict rows, except that a loser identical to the current text is dropped automatically.
  - The sidebar sync line reads "1 conflict in Groceries" and links to the list.
  - A `resurrected` event shows a toast: "A task you deleted was edited on another device, so it's back".

- [ ] **Step 1: Write the failing tests.**
  - `conflict row shows both texts with sources`
  - `Keep only this (theirs) sets text and clears conflict`
  - `sidebar shows conflict line linking to list`
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the tests. Expected: PASS.
- [ ] **Step 5: Checkpoint.**

### Task 19: Archive and trash; search

**Files:**

- Create: `lib/features/archive_trash/presentation/{archive_trash_cubit.dart,archive_trash_page.dart}`, `lib/features/search/presentation/{search_cubit.dart,search_page.dart}`
- Test: `test/features/archive_trash/archive_trash_test.dart`, `test/features/search/search_test.dart`

**Interfaces:**

- Consumes: `ListsRepository.watchArchived/watchTrashed/purgeTrash`, `RestoreList`, `DeleteListForever`, `ItemsRepository.search`
- Produces:
  - **Archive and trash:** one screen with two cards, and the copy "Archived lists are hidden, not deleted. Trash empties itself after 30 days."
    - Archive rows: dot · name · "7 items · Archived 28 Oct" · Restore.
    - Trash rows: "Deleted 2 days ago · empties in 28 days" · Restore · Delete forever, with Undo.
    - `purgeTrash(now)` runs on app start.
    - An item added or edited in a list that was concurrently trashed stays inside the trashed list; the trash view must show it and warn before purge.
  - **Search:** `restartable()` with a 150 ms debounce. Results are grouped by list, with matches highlighted, and the copy "N results for "x" across M lists. Works offline."
    - Desktop: the sidebar field turns the canvas into results.
    - Phone: the Search tab.

- [ ] **Step 1: Write the failing tests.**
  - `restore archived list returns to sidebar`
  - `delete forever then undo restores`
  - `trash row shows days left`
  - `search shows count and highlights match`
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the tests. Expected: PASS.
- [ ] **Step 5: Checkpoint.**

### Task 20: Settings, account dialogs, devices

**Files:**

- Create: `lib/features/settings/data/prefs.dart`, `lib/features/settings/presentation/{settings_cubit.dart,settings_page.dart}`, `lib/features/account/presentation/account_dialogs/{sign_in_dialog.dart,sign_out_dialog.dart,delete_account_dialog.dart,upload_progress.dart}`, `lib/core/widgets/weave_dialog.dart`
- Test: `test/features/settings/settings_test.dart`, `test/features/account/account_dialogs_test.dart`

**Interfaces:**

- Consumes: `SessionCubit`, `SyncTransport.devices`, `MiniBars` table
- Produces:
  - `class Prefs`: `Kv`-backed and device-only. Fields: `ThemeMode theme`, `double barOpacity` (0.2–1.0), `bool hideInFullscreen`, `bool reminders`, `Duration defaultSnooze`, `String? captureListId`.
  - **Settings** (one row per section, saved as you change it):
    - Appearance
    - Mini bar (desktop only): show, opacity with live preview, hotkey label, hide in full screen
    - Notifications
    - Quick capture: "New tasks go to"
    - Account and sync: a devices table (name, last seen) and Sign out…
    - Delete account…
    - In local mode, Account shows **Sign in** instead, and Delete account is hidden.
  - **Dialogs** (copy from the 03 prototype's `dialog()` cases):
    - Sign in: an email + password form, with "Create account" as a link that switches to sign-up.
    - Upload progress: "Uploading 18 of 42". It cannot be dismissed.
    - Sign out: notes leave this device and stay in your account.
    - Delete account: the red button is enabled only when the typed email matches.
  - Esc and the scrim cancel every dialog except upload progress.

- [ ] **Step 1: Write the failing tests.**
  - `changing theme persists to Kv`
  - `"New tasks go to" sets captureListId used by QuickCaptureField`
  - `delete account button disabled until email typed exactly`
  - `local mode shows Sign in and hides Delete account`
  - `wrong password shows inline error under field`
  - `upload dialog ignores Esc`
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the tests. Expected: PASS.
- [ ] **Step 5: Checkpoint.**

### Task 21: Local reminders

**Files:**

- Create: `lib/core/helpers/reminder_times.dart`, `lib/core/notifications/reminder_scheduler.dart`
- Test: `test/core/helpers/reminder_times_test.dart`, `test/core/notifications/reminder_scheduler_test.dart`

**Interfaces:**

- Consumes: `Item`, `ItemsRepository`, `Prefs.reminders`, `flutter_local_notifications`, `timezone`
- Produces:
  - `List<DateTime> reminderTimes(Item item, DateTime now, {int occurrences = 3})`: future fire times only. `AtDue` and `Before` resolve against `due.at()` in the **current local zone** (floating time, F4.8). `AtTime` is a local wall-clock time. For a repeating item, the next `occurrences` dues come from `repeat.next`.
  - `int notificationId(String itemId, DateTime fireAt)`: a stable FNV-1a 31-bit hash of `'$itemId@${fireAt.toIso8601String()}'`.
  - `class ReminderScheduler { ReminderScheduler(ItemsRepository r, FlutterLocalNotificationsPlugin p, Prefs prefs); Future<void> reconcile(DateTime now); void start(); }`:
    - **`reconcile`:** computes the wanted set over open items, cancels pending ids that are not wanted, and schedules the missing ones. The title is the task text; the body is "list · time". Payload: `weave://item/<id>`.
    - **`start`:** reconciles on start, on any `Items` table change (debounced 1 s; this covers changes that arrive by sync, **so a task ticked on another device cancels its reminder here**), and on resume.
    - **Limits:** at most 60 pending (iOS limit 64), nearest first.
    - **Permissions:** asked the first time a reminder is set (iOS / macOS / Android 13+). Android uses exact alarms.

- [ ] **Step 1: Write the failing tests.**
  - `at due and 15 min before give two times`
  - `past times are dropped`
  - `weekly repeat yields 3 occurrences`
  - `notificationId is stable and positive`
  - `reconcile cancels reminders of a task done elsewhere`: fake plugin; the item is marked done in the DB → cancel is called with its id
  - `reconcile caps at 60`
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3:** Implement. Tapping a notification opens the app at the list with the item selected.
- [ ] **Step 4:** Run the tests. Expected: PASS. Manually set a reminder 1 minute out on each of the 4 platforms; it fires.
- [ ] **Step 5: Checkpoint.** End of Day 5.

---

## Phase 5 · Desktop mini bar (Day 6; macOS and Windows)

### Task 22: Multi-window host and cross-window DB bus (spike first)

**Files:**

- Create: `lib/core/platform/{mini_bar_host.dart,desktop_mini_bar_host.dart,cross_window_bus.dart}`, `lib/entrypoints/mini_bar_main.dart`
- Modify: `macos/Runner/MainFlutterWindow.swift`, `windows/runner/main.cpp` (plugin registration for sub-windows, as the `desktop_multi_window` README says)
- Test: `test/core/platform/cross_window_bus_test.dart`

**Interfaces:**

- Produces:
  - `abstract class MiniBarHost { Future<void> show(String listId); Future<void> hide(String listId); Future<void> hideAll(); Future<void> showAll(); Future<void> openSheet(String listId); }`
  - `class CrossWindowBus { void broadcastDbChanged(Set<String> tables); Stream<Set<String>> get dbChanged; }`. It is backed by `DesktopMultiWindow.invokeMethod` to every window id. When a message is received, the receiver calls `db.notifyUpdates` for those tables, so Drift streams refresh.
  - `mini_bar_main.dart`:
    1. Parses `{"listId": …, "profile": …}` from the window args.
    2. Opens its own `WeaveDatabase.open(profile)` on the same file (WAL).
    3. Registers a reduced DI with **no SyncEngine and no ReminderScheduler**.
    4. Writes through `ChangeWriter`, then calls `broadcastDbChanged`.
  - In the main engine, `dbChanged` from a bar triggers `syncEngine.syncNow()` (debounced 300 ms).
- **Spike rule:** spend the first 2 hours proving that a frameless, transparent, always-on-top sub-window opens and writes to the DB on both macOS and Windows.
  - **If it fails, fall back:** the main window gets a "bar mode" (`windowManager.setAlwaysOnTop`, resized to the bar), with one bar only. Log it as D10 and tell the user.

- [ ] **Step 1: Write the failing test.**
  - `bus message refreshes drift stream in other database connection`: two `WeaveDatabase` instances on one temp file. A writes; the bus is simulated by calling `B.notifyUpdates`. B's `watchActive` emits the new list.
- [ ] **Step 2:** Run the test. Expected: FAIL.
- [ ] **Step 3:** Implement and run the spike on macOS and Windows.
- [ ] **Step 4:** Run the test. Expected: PASS. Manual: the bar window opens above other apps; a tick in it shows up in the main window within 1 s.
- [ ] **Step 5: Checkpoint.**

### Task 23: Mini bar and sheet UI

**Files:**

- Create: `lib/features/mini_bar/presentation/{mini_bar_app.dart,bar.dart,sheet.dart,bar_menu.dart,mini_bar_cubit.dart}`
- Test: `test/features/mini_bar/bar_test.dart`

**Interfaces:**

- Consumes: `ListsRepository.watch`, `ItemsRepository.watchList`, item use cases, `QuickCaptureField`, `ItemTile`, `DayStrip` (create it in `lib/core/widgets/day_strip.dart`, sharing its mark logic with `DayThread`), and the `MiniBars` table
- Produces, following design playbook §2 "Mini bar" and "Sheet", §3 interaction and `docs/design-02/01-mini-bar` (`assets/weave.{js,css}`):
  - **Bar:** 40 px tall; its width follows the text; grip · dot · name (ellipsis after 150 px) · meta. Meta is "4 left · **1 overdue**" (red), or "4 left · next **17:00**", or "4 left", or "All done". The surface is note paper. The bar sits at `barOpacity` when idle and is opaque on hover.
  - **Drag and position:** movement under 5 px counts as a tap. The bar is clamped 12 px inside the screen. Arrow keys move it 16 px (Shift: 64). Its position is saved to `MiniBars`.
  - **Tap:** the window grows to hold the sheet below the bar (or above it, when there is no room). The bar's meta fades out.
  - **Sheet:**
    - header: list switch ▾, hide ⌄, open in app ⤢
    - subline, day strip, add field focused on open, parse line
    - items in time order, Done · N
    - footer: sync status
    - resize grip: width 300–560, height 300–720, saved per list
    - closes on Esc, a click outside (window blur), or a tap on the bar
  - **Bar menu** (right-click, or Shift+F10): Collapse to a 28 px handle (dot + count; ✓ when all done; red when overdue) · Take off screen (clears `showInMiniBar`) · Hide all.
  - **Open in app** focuses the main window at that list.

- [ ] **Step 1: Write the failing tests** (widget tests on `MiniBarApp` with an in-memory DB).
  - `meta shows "1 overdue" in red when overdue exists`
  - `meta shows next time when nothing overdue`
  - `tap under 5px movement opens sheet; 6px drag does not`
  - `Esc closes sheet`
  - `collapse shows handle with count`
  - `sheet add field adds parsed task`
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the tests. Expected: PASS. Compare by hand with `01-mini-bar/index.html#open` on macOS and Windows.
- [ ] **Step 5: Checkpoint.**

### Task 24: Tray / menu bar, hotkey, close to tray

**Files:**

- Create: `lib/core/platform/{tray_host.dart,hotkey_host.dart}`
- Modify: `lib/app/bootstrap.dart`
- Test: manual (plugin-only code)

**Interfaces:**

- Consumes: `MiniBarHost`, `Prefs`
- Produces:
  - Tray / menu-bar icon: the Weave mark outline template (`docs/logo/kit/png/weaveTemplate.png` + `@2x`, set as a template image on macOS). Menu: Open Weave · Show bars / Hide bars · Pause reminders 1 h · Quit.
  - Global hotkey: ⌥Space on macOS, Ctrl+Space on Windows. It opens the sheet of the last-used bar, or the main window's add field if there is no bar.
  - Closing the main window hides it, so bars and sync keep running; Quit is in the tray menu.
  - "Hide in full-screen apps": macOS window collection behavior `fullScreenAuxiliary` off; on Windows, skipped (log it).

- [ ] **Step 1:** Implement.
- [ ] **Step 2: Manual check on macOS and Windows.**
  - Hide bars / show bars works.
  - The hotkey opens the sheet from another app.
  - Closing the main window leaves the bars working.
  - A tick in a bar reaches Android within 3 s.
- [ ] **Step 3: Checkpoint.** End of Day 6.

---

## Phase 6 · Ship (Day 7)

### Task 25: Acceptance matrix and scale check

**Files:**

- Create: `test/perf/seed_scale_test.dart`, `docs/impl-plan/acceptance-2026-11.md`

- [ ] **Step 1: Write the scale test.** Seed 2,000 lists and 20,000 items (NFR5). Assert that `watchActive` first emit, `watchList` for a 200-item list, `watchUpNext` and `search('milk')` each take under 100 ms on desktop.
- [ ] **Step 2:** Run `flutter test test/perf`. Expected: PASS. If not, add indexes on `items(list_id, deleted_at, done)` and `items(due_date)`, add a migration test, and rerun.
- [ ] **Step 3:** Run the manual matrix and record pass or fail per cell in `acceptance-2026-11.md`. Devices: macOS, Windows, iPhone (or simulator) and Android, on one account.
  1. Add on X → visible on Y in under 3 s.
  2. Tick on X → reminder cancelled on Y.
  3. Both offline, edit different tasks, reconnect → both kept.
  4. Both offline, edit the same task text → conflict row on both devices, nothing lost.
  5. Delete a list on X → in trash on Y; restore on Y → back on X.
  6. Sign out on X → X is empty, Y is unaffected.
  7. Local mode with 10 tasks → sign in → tasks reach Y.
  8. Mini bar tick (desktop) → phone.
  9. Kill the app mid-sync → restart → nothing lost.
- [ ] **Step 4:** Fix any failure, sync first. Re-run the failed cells.
- [ ] **Step 5: Checkpoint.**

### Task 26: Release builds and docs

**Files:**

- Modify: `README.md`, `docs/design/design-checklist.md` (add a "Built" column or note), `docs/playbook/architecture-playbook.md` (mark ⏳ items resolved by D2)
- Create: app icons (`flutter_launcher_icons` config in `pubspec.yaml`)

- [ ] **Step 1: Builds.**
  - `flutter build macos --flavor prod -t lib/main_prod.dart`
  - `flutter build windows -t lib/main_prod.dart`
  - `flutter build apk --flavor prod -t lib/main_prod.dart`
  - `flutter build ios --flavor prod -t lib/main_prod.dart --no-codesign` (TestFlight needs the user's Apple account)

  Expected: all succeed. Release builds use `--dart-define-from-file=config/prod.json`.

- [ ] **Step 2:** Run `flutter analyze` and `flutter test`. Expected: 0 issues, all pass.
- [ ] **Step 3:** Update the README with run and build commands, the `--dart-define` keys and the Supabase setup. Write the next-phase list (Later phases above) into the README "Roadmap".
- [ ] **Step 4: Checkpoint.** Day 7 done.
