# Merchant Funnel (`OneWoW.Merchant`)

> **See also:** [ARCHITECTURE.md](ARCHITECTURE.md) §8.8 (summary + roster), §3.3
> (the `ns.RegisterEvent` core event multiplexer this builds on), and
> [PROFESSION_RECIPE.md](PROFESSION_RECIPE.md) — the recipe funnel this mirrors.

One core service owns the merchant-window event funnel for the whole suite.
Before it, every merchant listener (`VendorScanner`, `overlay-engine`, Accounting
`VendorTracker`, `OneWoW_Bags`, QoL auto-repair / auto-open / vendor-panel) spun
up its own frame with its own `MERCHANT_*` registration and ad-hoc debounce. The
Catalog `VendorScanner`'s `scanInProgress` flag in particular was set and cleared
synchronously and never actually debounced, so `MERCHANT_SHOW`'s 0.5s scan and
`MERCHANT_UPDATE` scans routinely double-fired.

**File:** [`OneWoW/Services/Merchant.lua`](../Services/Merchant.lua), published as
`OneWoW.Merchant` via the Facade.

## Ownership

The service is the single owner of these events, registered through the core
`ns.RegisterEvent` multiplexer only while at least one consumer is subscribed:

- `MERCHANT_SHOW`
- `MERCHANT_UPDATE`
- `MERCHANT_CLOSED`

No other file in the suite may register these — enforced by the
`core-event-funnel` pre-commit hook (`bin/check_no_core_event_bypass.py`, an
`EVENT_OWNER` registry seeded with `MERCHANT_*`→`Merchant.lua`; escape hatch
`-- noqa: core-event-funnel`). Events are registered on 0→1 subscribers and torn
down on 1→0. All channels share **one** refcount — a show/closed-only subscriber
still keeps the events live. `overlay-engine` holds a standing subscription
(registered at login), so in practice the events stay registered near-permanently
and the lazy lifecycle is a correctness / single-owner mechanism rather than a
perf win, exactly as `RecipeKnownUtil` does for the recipe funnel.

## Channels

| API | Callback | Use |
| --- | --- | --- |
| `RegisterScanCallback(ownerID, fn)` | `fn(scan)` | Vendor data consumers (item map + costs), debounced |
| `RegisterShowCallback(ownerID, fn)` | `fn()` | Fired **synchronously on `MERCHANT_SHOW`, no debounce** — repair, gold snapshot, panel anchoring |
| `RegisterClosedCallback(ownerID, fn)` | `fn()` | Transient-state teardown on `MERCHANT_CLOSED` |
| `UnregisterCallback(ownerID)` | — | Drops all channels for an owner |
| `GetLastScan()` | — | The most recent ephemeral snapshot (sync UI helper) |
| `IsMerchantOpen()` | — | Live `MerchantFrame:IsShown()` wrapper — lets state-flag consumers drop their `merchantOpen` booleans without a subscription |

Re-registering an `ownerID` on a channel replaces the prior handler (no
stacking). Fan-out order within a channel is undefined (`pairs`) — consumers must
not depend on cross-owner ordering (identical to the previous independent-frame
dispatch, no regression). Show callbacks fire before any scan in a given open.

## Scan behavior

`MERCHANT_SHOW` / `MERCHANT_UPDATE` coalesce into one re-armed ~0.25s debounce
(replacing the old synchronous `scanInProgress` flag). The snapshot is
**ephemeral** — core persists nothing; it is cleared on `MERCHANT_CLOSED` and
when the last subscriber leaves:

```lua
{
  npcID        = <number>,
  name         = "<vendor name>",
  creatureType = "<UnitCreatureType>",
  classification = "normal" | "elite" | …,
  level        = <number>,
  displayID    = <number> | nil,   -- PlayerModel:SetUnit("npc"):GetDisplayInfo(); nil triggers retry
  subtitle     = "<NPC SubName>" | nil,  -- C_TooltipInfo.GetUnit("npc") line after name
  canRepair    = <bool>,           -- CanMerchantRepair()
  location     = { mapID, zone, subzone, x, y } | nil,
  items = {
    [itemID] = {
      cost          = <copper>,            -- gold price
      limited       = <bool>,              -- numAvailable > 0
      maxStack      = <number>,
      isPurchasable = <bool>,              -- false = "saw it, can't buy yet"
      isUsable      = <bool>,
      blockReason   = "<red requirement lines>" | nil,  -- only when not purchasable; from GetMerchantItem tooltip
      lastSeen      = <time()>,
      currencies    = { { amount, texture, currencyID?/itemID?, name }, ... },
    }, ...
  },
  scannedAt = <time()>,
}
```

`displayID` / `subtitle` / `canRepair` are optional extras for consumers (Catalog
vendor portraits + auto-category). Other subscribers may ignore them.

`displayID` is captured via an off-screen shown `PlayerModel` (`SetUnit("npc")`,
then `SetCreature(npcID)` fallback). A fully hidden model often returns `0` from
`GetDisplayInfo` even when the rest of the scan succeeds; missing IDs still arm
the existing one-shot rescan.

### First-visit retry

On a first-ever vendor visit item links and cost-item names may still be
loading. Where `GetMerchantItemLink(i)` is nil the scan falls back to
`GetMerchantItemID(i)` (works uncached) + `C_Item.RequestLoadItemDataByID`, so
the row is captured rather than silently dropped. One deferred rescan pass
(~0.5s) is scheduled per merchant session to re-fire the snapshot with the now
cached data. Because catch-up subscriptions and this retry both re-deliver the
same vendor, **scan consumers must be idempotent**.

### Known limitation (document, don't fix)

`GetMerchantNumItems()` reflects the merchant frame's active filter, so a
filtered view scans a subset of the vendor's stock.

## No SavedVariables

Core holds only the ephemeral `lastScan`. Vendor catalogs live in
`OneWoW_CatDB_NPCDB_DB`; collectible wishlist records live in
`OneWoW_Notes_DB`. Each consumer resolves and stores in its own scope.

## Consumers (LoD-safe)

| Consumer | Channel | Responsibility |
| --- | --- | --- |
| `CatDB_NPCDB` `VendorScanner` | scan | Merge into the vendor DB (npc record, locations, item map with costs + `isPurchasable`/`isUsable`), then its own `_API.RegisterScanCallback` fan-out for Catalog UI |
| `overlay-engine` (core) | show + scan | Vendor overlay refresh (standing subscription at login) |
| Accounting `VendorTracker` | show + `IsMerchantOpen()` | Gold-before-repair snapshot; frame keeps `UPDATE_INVENTORY_DURABILITY` |
| `OneWoW_Bags` | show + closed | Vendor-mode enter/exit (`Events:OnMerchantShow` / `OnMerchantClosed`) |
| QoL auto-repair / vendor-panel | show (+ closed) | Repair on open / panel anchoring; module lifecycle = subscribe/`UnregisterCallback` |
| QoL auto-open | `IsMerchantOpen()` | Pure state read, no subscription |
| `OneWoW_Notes` collectibles (`CollectiblesMerchant`) | scan | Upsert uncollected vendor items as wishlist `vendorOffers` (+ `blockReason` from the merchant tooltip) |

The subscription decision is driven entirely by **consumer settings / module
lifecycle** — there is no core-level "enable scanning" flag. Toggling a consumer
off calls `UnregisterCallback`; toggling on re-subscribes (0→1 catch-up scans an
already-open merchant). No handler-side enable gates.
