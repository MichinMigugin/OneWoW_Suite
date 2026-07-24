# Guild Bank Transfer (`OneWoW.GuildBankTransfer`)

> **See also:** [ARCHITECTURE.md](ARCHITECTURE.md) §8.10 (summary), §8.9
> (Inventory events / `IsGuildBankOpen`), [INVENTORY.md](INVENTORY.md).

Bag → guild-bank **deposit planner + paced execute queue**. Sibling to
Inventory — **moves ≠ events**:

| Layer | Owns |
| --- | --- |
| `OneWoW.Inventory` | `GUILDBANK*` funnel, `IsGuildBankOpen()`, slots/tabs/money channels |
| `OneWoW.GuildBankTransfer` | Plan + enqueue bag→guild deposits |
| Consumers | Policy (which bag slots); call plan / enqueue |

**File:** [`OneWoW/Services/GuildBankTransfer.lua`](../Services/GuildBankTransfer.lua)

Published as `OneWoW.GuildBankTransfer` via the Facade.

## API

| API | Use |
| --- | --- |
| `PlanDeposits(slots)` | Build `stack` / `empty` / `fallback` ops from live guild slots |
| `EnsureTabsQueried(wantedItemIDs, onReady)` | `QueryGuildBankTab` viewable tabs, then `onReady` after settle |
| `Enqueue(ops, opts)` | Paced queue; `opts.ownerID`, `intervalSec`, `onProgress`, `onOpComplete`, `onComplete` |
| `Cancel(ownerID?)` | Stop queue (owner-matched when provided) |
| `IsBusy()` | Global queue busy flag |
| `RegisterPlaceCallback(ownerID, fn)` | `fn(tabID, slotID, kind)` before `PickupGuildBankItem` (`kind` = `"stack"` \| `"empty"`) |
| `UnregisterCallback(ownerID)` | Drop place callback; cancel if that owner owns the queue |

**Busy policy:** second `Enqueue` while busy under another owner is rejected.
Same `ownerID` cancels and replaces.

**Execute gates (per tick):** `Inventory.IsGuildBankOpen()`,
`not Restriction.IsProtectedActionBlocked()`, empty cursor, live re-verify.
Default interval ~0.6s.

## Plan order

1. **Partial stacks** — greedy fill existing stacks (tab/slot order) via split +
   `PickupGuildBankItem`
2. **Empty slots** — overflow onto free depositable slots the same way
3. **Fallback** — `UseContainerItem` only if no empty slot remained at plan time

`SetCurrentGuildBankTab` runs before each targeted place (required for Bags /
multi-tab correctness). Live guild APIs only — no Storage SV, no Bags private
cache.

## Consumers

- `OneWoW_DirectDeposit` — guild auto/manual deposit
- `OneWoW_Bags` — search transfer + Ctrl+RMB while guild bank open; place-callback
  for transfer-tab / merge tracking

## Out of scope

- Guild → bags withdraw planner
- `GUILDBANKLOG_UPDATE` (Bags `GuildBankLog` only)
- Mail funnel
