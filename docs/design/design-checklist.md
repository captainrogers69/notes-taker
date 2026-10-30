# Weave — Design Checklist

Design gaps found by checking [requirements.md](../requirements.md) and the [design playbook](../playbook/design-playbook.md) against the prototypes (003–006).
Tick an item when it has a prototype in `docs/design/NNN-*` and a rule in the design playbook.

Last reviewed: 2026-10-30

---

## v1 Must — missing or partial

- [ ] **1. Several lists on screen** (F1, F1.2)
  - [ ] More than one list floating at once (one bar per list, or one bar that holds several)
  - [ ] Resize the sheet
  - [ ] Collapse a note to a small handle
- [ ] **2. Reminder notifications** (F4.5, F4.6)
  - [ ] Android notification: Mark done · Snooze (10 min / 1 h / tomorrow) · Open
  - [ ] macOS notification
  - [ ] Windows notification
  - [ ] Done or snoozed on one device clears it on the others
- [ ] **3. iOS widgets** (F1-iOS)
  - [ ] Home-screen widget: chosen list or "next up", items tickable
  - [ ] Lock-screen widget: next reminder
- [ ] **4. Android home widget** (fallback when overlay permission is denied)
- [ ] **5. Sync conflict** (F2.4): keep both versions and tell the user
- [ ] **6. Encryption setup** (E3, E4)
  - [ ] Recovery key screen: shown once, with a clear warning
  - [ ] Periodic prompt to save the recovery key
  - [ ] New-device approval: QR from an existing device, or enter the recovery key
- [ ] **7. Account** (S1)
  - [ ] Email sign-in (magic link or password)
  - [ ] First sign-in: uploading local notes
  - [ ] Sign out, with confirmation (removes local data)
  - [ ] Delete account and all data (store requirement)
- [ ] **8. Mobile quick capture** (F6.2, F6.3)
  - [ ] "Share to Weave" target from the OS share sheet
  - [ ] Widget `+` button
  - [ ] Android opt-in permanent "Add to Weave" notification (separate from the hidden-bar notification)
- [ ] **9. Settings** (S4): default list for quick capture
- [ ] **10. First run** (G: understand in < 2 min)
  - [ ] Onboarding
  - [ ] Android "display over other apps" permission ask, and the denied path

## Smaller gaps in existing designs

- [ ] Task details: custom date/time picker (F4)
- [ ] Task details: custom repeat interval (F4.3)
- [ ] More than one reminder per task (F4.1)
- [ ] Due date / reminder on a whole list, not only a task (F4.1)
- [ ] Option to hide checked items, not only collapse into "Done" (F3.4)
- [ ] Sync status in the sheet, not only in the full app (F2.5)
- [ ] Sheet shows a list's text lines, not only its tasks (F3.1)
- [ ] Arrow-key navigation in the sheet's lists view (NFR9; playbook §6)
- [ ] Sheet empty, error and offline states

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

- [ ] Architecture playbook §7: add the mini bar and sheet widgets
