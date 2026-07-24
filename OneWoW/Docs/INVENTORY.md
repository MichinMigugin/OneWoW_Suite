# Inventory Funnel (`OneWoW.Inventory`)

> **See also:** [ARCHITECTURE.md](ARCHITECTURE.md) §8.9 (summary), §3.3
> (`ns.RegisterEvent` multiplexer), and [MERCHANT.md](MERCHANT.md) — the funnel
> shape this mirrors.

One core service owns the **live** bag/bank event funnel for the logged-in
character, plus shared container ID vocabulary and slot iteration helpers.
Cross-alt persistence, Query, and dupes stay in `OneWoW_AltTracker_Storage`.
PredicateEngine stays pull/eval (no bag watches).

**Files:**

- [`OneWoW/Services/Inventory.lua`](../Services/Inventory.lua) — funnel + scan helpers
- [`OneWoW/Services/Inventory/BagTypes.lua`](../Services/Inventory/BagTypes.lua)
- [`OneWoW/Services/Inventory/BankTypes.lua`](../Services/Inventory/BankTypes.lua)

Published as `OneWoW.Inventory` via the Facade (`BagTypes` / `BankTypes` hang off
that table).

## Live vs persisted

| Concern | Owner |
| --- | --- |
| Bag/bank WoW events for this character | `OneWoW.Inventory` |
| Container ID vocabulary + live slot walk | `OneWoW.Inventory` |
| Persist bags/banks/mail across alts | `OneWoW_AltTracker_Storage` |
| Slot enrichment / `#keyword` match | `OneWoW.PredicateEngine` |
| Bag UI layout | `OneWoW_Bags` |

## Ownership (events)

The service is the single owner of these events, registered through the core
multiplexer while at least one consumer is subscribed:

- `BAG_UPDATE` / `BAG_UPDATE_DELAYED`
- `BAG_CONTAINER_UPDATE` / `BAG_UPDATE_COOLDOWN`
- `ITEM_LOCK_CHANGED`
- `BANKFRAME_OPENED` / `BANKFRAME_CLOSED` / `BANK_TABS_CHANGED`
- `PLAYERBANKSLOTS_CHANGED` / `PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED`

Enforced by the `core-event-funnel` pre-commit hook
(`bin/check_no_core_event_bypass.py`, `EVENT_OWNER` → `Inventory.lua`; escape
hatch `-- noqa: core-event-funnel`).

Guild bank and mail events stay with Bags / Storage for now.

## Channels

| API | Callback | Use |
| --- | --- | --- |
| `RegisterDirtyCallback(ownerID, fn)` | `fn(bagID)` | Immediate per-bag dirty (e.g. bank tab incremental paint) |
| `RegisterDelayedCallback(ownerID, fn)` | `fn(dirtyBags)` | Coalesced map `bagID -> true` after `BAG_UPDATE_DELAYED` |
| `RegisterBankOpenCallback(ownerID, fn)` | `fn()` | Character/warband bank opened |
| `RegisterBankClosedCallback(ownerID, fn)` | `fn()` | Bank closed |
| `RegisterBankSlotsCallback(ownerID, fn)` | `fn(event, ...)` | Personal/account bank slot change events |
| `RegisterContainerCallback(ownerID, fn)` | `fn()` | Equipped bag container / slot-count changes |
| `RegisterLockCallback(ownerID, fn)` | `fn(bagID, slotID)` | Item lock changes |
| `RegisterCooldownCallback(ownerID, fn)` | `fn()` | Bag item cooldown pulse |
| `RegisterBankTabsCallback(ownerID, fn)` | `fn(bankType, ...)` | Bank tabs changed |
| `UnregisterCallback(ownerID)` | — | Drops all channels for an owner |
| `IsBankOpen()` | — | Event-tracked bank-open flag for suppress gates |

Re-registering an `ownerID` on a channel replaces the prior handler. Fan-out
uses `Lifecycle.SafeCall` so one bad consumer cannot kill the rest. All channels
share one event refcount (0→1 arm / 1→0 tear-down).

On each `BAG_UPDATE_DELAYED`, Inventory calls `PE:InvalidatePropsCache()` once
before fanning the delayed channel.

## Container types + scan helpers

| API | Use |
| --- | --- |
| `Inventory.BagTypes` | Player bag ID lists / predicates (`IsPlayerBag`, `IsReagentBag`, …) |
| `Inventory.BankTypes` | Personal / warband tab ID lists / predicates |
| `GetBagIDs(scope)` | `"player"` \| `"personal"` \| `"warband"` \| `"bank"` \| dirty map \| bagID array |
| `ForEachSlot(scope, fn)` | `fn(bagID, slotID, containerInfo)`; return `true` from `fn` to stop |

`GetBagName` / `GetTabName` return **locale keys** (e.g. `BAG_BACKPACK`); Bags
resolves them via its own `L`. No core locale entries for those keys.

## Consumers

- `OneWoW_Bags` — delayed / lock / cooldown / bank open-closed / tabs / container (+ types)
- Overlays2 bag/bank surfaces — dirty + delayed + bank open/slots
- `OneWoW_AltTracker_Storage` DataManager — delayed + bank-open (guild/mail local)
- QoL autoopen / bagbar / toast-loot / questitembar / vendorpanel
- ShoppingList alerts / bag overlays; Trackers engine / farmvalue
- DirectDeposit; Accounting BankTracker; Bags integration bank-open
