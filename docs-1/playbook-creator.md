# Playbook Creator — Architecture Playbook

Instructions for Claude. Read a project's `requirements.md`, combine it with our [Principles](principles.md), and write an `architecture-playbook.md` for that project.

**Stack:** Flutter only (for now). Other stacks plug in later as new sections under §6.
**Input:** `requirements.md` only, for new or existing projects. Don't scan the codebase.
**Output:** `docs/playbook/architecture-playbook.md` in the target project.

---

## 1. Ground Rules

1. **Principles are the default.** Every rule in [principles.md](principles.md) applies unless the requirements say otherwise.
2. **Non-negotiables never change.** No requirement overrides them (§5).
3. **Discuss, don't guess.** If a requirement's approach conflicts with a principle, stop, explain the conflict to the user, and agree on a decision before writing. Record it in **Deviations**.
4. **Ask, don't assume.** If information is missing or unclear, ask the user. Never fill gaps with assumptions.
5. **No Toskie names.** Turn project-specific names into generic roles (§4).
6. **Only what's needed.** Leave out sections for capabilities the project doesn't need (no media → no media section).

---

## 2. Steps

### Step 1 — Read the inputs

- Read [principles.md](principles.md) in full.
- Read the project's `requirements.md` in full. Note every feature and any approach it states.

### Step 2 — Extract the project facts

Fill this checklist from the requirements. Mark each item **found** (quote the source line) or **missing**.

| Fact               | Why it matters                                     |
| ------------------ | -------------------------------------------------- |
| App name           | Naming of shared classes (`AppLogger`, …)          |
| Platforms          | Android / iOS / web / desktop: responsive + native |
| API type           | GraphQL / REST / both: networking + data folders   |
| Auth               | Token flow, refresh, storage                       |
| Realtime           | Sockets / push: core service needed?               |
| Offline / local DB | Caching + storage layer                            |
| Media              | Upload, picking, rendering                         |
| Analytics          | Whether a separate analytics playbook is needed    |
| Routing needs      | Deep links, guarded routes, nested nav             |
| Flavors / envs     | dev / prod setup                                   |
| Typography / theme | Font family, design system                         |
| Feature list       | Drives the feature map (Step 4)                    |

### Step 3 — Ask, then discuss

Before writing anything:

1. **Ask** about every **missing** fact that affects the structure. Batch the questions into one message.
2. **Discuss** every conflict between a requirement's approach and a principle. Present: the principle, what the requirement says, the trade-off, and your recommendation. Wait for the user's decision.
3. Don't proceed until every structural question is answered.

### Step 4 — Build the feature map

For each feature in the requirements, pick:

- **State tool:** the smallest that fits (hooks → `ChangeNotifier` → `Cubit` → `Bloc`), with a one-line reason.
- **API:** GraphQL / REST / both / none.
- **Shared?** Whether it exposes reusable parts (widgets, cubits, helpers) to other features.

If a feature's size or scope is unclear, ask.

### Step 5 — Write the playbook

- Use the template in §3. Fill each section from principles + project facts + agreed decisions.
- Replace names using §4.
- Check the output path. **If `architecture-playbook.md` already exists, ask before overwriting.**

### Step 6 — Review with the user

Summarise: the feature map, deviations, and anything left out (and why). Apply corrections.

---

## 3. Output Template — `architecture-playbook.md`

```markdown
# <App> — Architecture Playbook

How we build in this project. Follow these for every feature and fix.
Source: requirements.md + team principles.

## 0. Project Snapshot

Platforms · API type · Auth · Realtime · Offline · Flavors — one line each.

## 1. Feature Map

| Feature | State tool | Why | API | Shared parts |

## 2. State Management

Scope → tool table. DI registration rules. Equatable state + derived getters.

## 3. Architecture — Feature-First Clean Architecture

Folder tree (data / domain / presentation). Call flow. UseCase / Repository / DataSource rules.
API ownership per feature (`data/graphql/` and/or `data/rest/`).

## 4. Networking & Data

`ApiService` entry points used by this project (`sendGraphQlRequest` / `sendRequest`) → `ApiResponse<T>`.
Parsing: `fromJson → Entity`, `is` + `tryParse`, no `as` casts, null-safe defaults.
Envelope check. Logging via `AppLogger.forTag`.

## 5. Dependency Injection

One file per feature in `core/di/`. Singleton vs factory rules.

## 6. Helpers & Enums

Shared static helper classes. Enum convention (`fromApi` / `apiValue` / `label`). Extensions.

## 7. Reusable Widgets

Promote-on-second-use rule. Shared widgets this project needs (from requirements).

## 8. UI Rules

Non-negotiables first. Rebuild control. Hook disposal. Responsive helper. Typography.
Dialogs/sheets via `DialogWrapper`. One shared app bar.

## 9. Routing

`go_router`, `AppRoute` enum, typed args via `state.extra`. Project-specific needs (deep links, guards).

## 10. <Capability sections — only if required>

Realtime · Media · Offline · Auth · Flavors — one section each, only when in requirements.

## 11. Naming & Files

## 12. Quality Gate

## Deviations

| Principle | Project decision | Reason | Agreed on |
(Write "None" if empty.)
```

---

## 4. Name Mapping (Toskie → Generic)

| In principles                        | In generated playbook                                   |
| ------------------------------------ | ------------------------------------------------------- |
| `ToskieLogger`                       | `AppLogger`                                             |
| `ToskieAppBar`                       | one shared app bar widget (name it per project)         |
| `DialogWrapper`                      | `DialogWrapper` (keep as is)                            |
| `PresignedUrlCubit`, S3 key handling | **skip**                                                |
| `ProfileImage` / `CachedImageHolder` | only if media is required: shared avatar / image widget |
| `MediaPicker` / `UploadMedia`        | only if media is required                               |
| `GoogleFonts.poppins`                | the project's font (ask if missing)                     |
| `context.res(...)`                   | responsive helper (keep if multiple form factors)       |
| `_revamp` modules                    | only if the requirements describe a migration           |
| Analytics rules                      | skip — separate creator                                 |

---

## 5. Non-Negotiables (Flutter)

Copy into every generated playbook unchanged. Never a deviation.

- No `Widget _buildX()` methods — always a `StatelessWidget`, however small.
- `HookWidget` over `StatefulWidget`, however complex.

---

## 6. Stack Sections

### Flutter (current)

Everything above applies as written.

### Other stacks (later)

Add a section here per stack: its equivalent of each principle, its non-negotiables, and its name mapping.
