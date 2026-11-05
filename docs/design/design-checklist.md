# Weave — Design Checklist

Design gaps found by checking [requirements.md](../requirements.md) and the [design playbook](../playbook/design-playbook.md) against the prototypes.
Prototypes are now the locked **design 02** ([`docs/design-02/`](../design-02/index.html)); design 01 (003–006 in this folder) is superseded.
Tick an item when it has a prototype in `docs/design-02/` (built in the design 02 style, passing the clutter check) and a rule in the design playbook.

Last reviewed: 2026-11-05 (re-checked against design 02)

---

## v1 Must — missing or partial

- [x] **1. Several lists on screen** (F1, F1.2) — 01: one bar per list; right-click or Shift+F10 on a bar for Collapse / Take off screen; resize grip on the sheet
  - [x] More than one list floating at once (one bar per list, or one bar that holds several)
  - [x] Resize the sheet
  - [x] Collapse a note to a small handle
- [x] **2. Reminder notifications** (F4.5, F4.6) — 04
  - [x] Android notification: Mark done · Snooze (10 min / 1 h / tomorrow) · Open
  - [x] macOS notification
  - [x] Windows notification
  - [x] Done or snoozed on one device clears it on the others
- [x] **3. iOS widgets** (F1-iOS) — 05
  - [x] Home-screen widget: chosen list or "next up", items tickable
  - [x] Lock-screen widget: next reminder
- [x] **4. Android home widget** (fallback when overlay permission is denied) — 05; offered in 06 denied path
- [x] **5. Sync conflict** (F2.4): keep both versions and tell the user — 03 Groceries (Keep both / Keep only this)
- [x] **6. Encryption setup** (E3, E4) — 03 Settings → Account (Show again, Check it, Add a device) and sign-in flow
  - [x] Recovery key screen: shown once, with a clear warning
  - [x] Periodic prompt to save the recovery key
  - [x] New-device approval: QR from an existing device, or enter the recovery key
- [x] **7. Account** (S1) — 03: Sign in (local mode `#account=local`), Sign out…, Delete account…
  - [x] Email sign-in (magic link or password)
  - [x] First sign-in: uploading local notes
  - [x] Sign out (03 Settings: "Removes your notes from this Mac") — confirmation dialog in 03 (Settings → Sign out…)
  - [x] Delete account and all data (03 Settings danger zone, type your email to confirm)
- [x] **8. Mobile quick capture** (F6.2, F6.3) — 05 (share, widget +), 04 (Android "Add to Weave")
  - [x] "Share to Weave" target from the OS share sheet
  - [x] Widget `+` button
  - [x] Android opt-in permanent "Add to Weave" notification (separate from the hidden-bar notification)
- [x] **9. Settings** (S4): default list for quick capture — 03 Settings → "New tasks go to"
- [x] **10. First run** (G: understand in < 2 min) — 06
  - [x] Onboarding
  - [x] Android "display over other apps" permission ask, and the denied path

## Smaller gaps in existing designs

- [x] Task details: custom date/time picker (F4)
- [x] Task details: custom repeat interval (F4.3)
- [x] More than one reminder per task (F4.1)
- [x] Due date / reminder on a whole list, not only a task (F4.1)
- [x] Option to hide checked items, not only collapse into "Done" (F3.4)
- [x] Sync status in the sheet, not only in the full app (F2.5) — sheet footer
- [x] Sheet shows a list's text lines, not only its tasks (F3.1)
- [x] Arrow-key navigation in the sheet's lists menu (NFR9; playbook §6)
- [x] Sheet error and offline states (empty and all-done states are drawn) — 01 proto: Sync → Offline / Error (Retry)

## Later releases (not needed for v1)

- [ ] @ links, "Linked from", broken links (F5 — v1.1)
- [ ] Share link (F11.2 — v1.1)
- [ ] Export / import (S3 — v1.1)
- [ ] App lock with biometrics / PIN (E5 — v1.1)
- [ ] iOS Live Activity for today's reminder (v1.1)
- [ ] Quiet hours (S4 — later)
- [ ] "Limit reached" screen for paid plans (S5 — later)
- [ ] Web layout (P2)
- [ ] iOS hide-to-tray (left out for now, user 2026-10-30)

## Docs

- [x] Architecture playbook §7: add the mini bar and sheet widgets (plus `QuickCaptureField`, `DayThread`, tab bar, sidebar)
- [x] Design playbook synced to design 02 (2026-11-05)
