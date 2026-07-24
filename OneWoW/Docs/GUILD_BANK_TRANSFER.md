# Guild Bank Transfer (`OneWoW.GuildBankTransfer`)

> **See also:** [ARCHITECTURE.md](ARCHITECTURE.md) §8.9 (Inventory events),
> [INVENTORY.md](INVENTORY.md) — open/slots bus this service consumes.

Bag → guild-bank **deposit planner + paced execute queue**. Sibling to
Inventory (not folded into it): Inventory owns `GUILDBANK*` events and
`IsGuildBankOpen()`; this service plans partial-stack fills and runs moves.

**File:** [`OneWoW/Services/GuildBankTransfer.lua`](../Services/GuildBankTransfer.lua)

Published as `OneWoW.GuildBankTransfer` via the Facade.

## API

| API | Use |
| --- | --- |
| `PlanDeposits(slots)` | Build `stack` / `fallback` ops from live guild slots |
| `EnsureTabsQueried(wantedItemIDs, onReady)` | `QueryGuildBankTab` viewable tabs, then `onReady` after settle |
| `Enqueue(ops, opts)` | Paced queue; `opts.ownerID`, `intervalSec`, `onProgress`, `onOpComplete`, `onComplete` |
| `Cancel(ownerID?)` | Stop queue (owner-matched when provided) |
| `IsBusy()` | Global queue busy flag |
| `RegisterPlaceCallback(ownerID, fn)` | `fn(tabID, slotID, kind)` before `PickupGuildBankItem` |
| `UnregisterCallback(ownerID)` | Drop place callback; cancel if that owner owns the queue |

**Busy policy:** second `Enqueue` while busy under another owner is rejected.
Same `ownerID` cancels and replaces.

**Execute gates (per tick):** `Inventory.IsGuildBankOpen()`,
`not Restriction.IsProtectedActionBlocked()`, empty cursor, live re-verify.
Default interval ~0.6s.

Live guild APIs only — no Storage SV, no Bags private cache.

## Consumers

- Phase 1: `OneWoW_DirectDeposit` guild auto/manual deposit
- Phase 2 (planned): Bags search / Ctrl+RMB guild deposit + place-callback for refresh tracking
