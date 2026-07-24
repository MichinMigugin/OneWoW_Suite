# Inventory Funnel (`OneWoW.Inventory`)

> **See also:** [ARCHITECTURE.md](ARCHITECTURE.md) §8.9 (summary), §3.3
> (`ns.RegisterEvent` multiplexer), and [MERCHANT.md](MERCHANT.md) — the funnel
> shape this mirrors.

One core service owns the **live** bag/bank event funnel for the logged-in
character. Cross-alt persistence, Query, and dupes stay in
`OneWoW_AltTracker_Storage`. PredicateEngine stays pull/eval (no bag watches).

**File:** [`OneWoW/Services/Inventory.lua`](../Services/Inventory.lua), published
as `OneWoW.Inventory` via the Facade.

## Live vs persisted

| Concern | Owner |
| --- | --- |
| Bag/bank WoW events for this character | `OneWoW.Inventory` |
| Persist bags/banks/mail across alts | `OneWoW_AltTracker_Storage` |
| Slot enrichment / `#keyword` match | `OneWoW.PredicateEngine` |
| Bag UI layout | `OneWoW_Bags` |

## Ownership (Phase 1)

The service registers these events through the core multiplexer while at least
one consumer is subscribed:

- `BAG_UPDATE`
- `BAG_UPDATE_DELAYED`
- `BANKFRAME_OPENED` / `BANKFRAME_CLOSED`
- `PLAYERBANKSLOTS_CHANGED`
- `PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED`

**Not yet enforced** by `core-event-funnel` — Bags and Storage still register
overlapping events until later migration phases. Dual registration during the
transition is expected (same pattern as the Merchant cutover).

Guild bank and mail events stay with their current owners for now.

## Channels

| API | Callback | Use |
| --- | --- | --- |
| `RegisterDirtyCallback(ownerID, fn)` | `fn(bagID)` | Immediate per-bag dirty (e.g. bank tab incremental paint) |
| `RegisterDelayedCallback(ownerID, fn)` | `fn(dirtyBags)` | Coalesced map `bagID -> true` after `BAG_UPDATE_DELAYED` |
| `RegisterBankOpenCallback(ownerID, fn)` | `fn()` | Character/warband bank opened |
| `RegisterBankClosedCallback(ownerID, fn)` | `fn()` | Bank closed |
| `RegisterBankSlotsCallback(ownerID, fn)` | `fn(event, ...)` | Personal/account bank slot change events |
| `UnregisterCallback(ownerID)` | — | Drops all channels for an owner |
| `IsBankOpen()` | — | Event-tracked bank-open flag for suppress gates |

Re-registering an `ownerID` on a channel replaces the prior handler. Fan-out
uses `Lifecycle.SafeCall` so one bad consumer cannot kill the rest. All channels
share one event refcount (0→1 arm / 1→0 tear-down).

On each `BAG_UPDATE_DELAYED`, Inventory calls `PE:InvalidatePropsCache()` once
before fanning the delayed channel.

## Phase 1 consumers

- QoL `autoopen` — delayed + `IsBankOpen()`; mail/guild suppress stay local
- QoL `bagbar` — delayed
- QoL `toast-loot` — delayed
- Overlays2 bag/bank surfaces — dirty + delayed + bank open/slots

## Later

- Shared `BagTypes` / `BankTypes` + `ForEachSlot` (Phase 2)
- Storage DataManager arming (Phase 3)
- Bags event migration + `core-event-funnel` seed (Phase 4)
