# Item Button Callback API

OneWoW Bags exposes a small callback API so other addons can attach overlays,
badges, or other decorations to bag/bank item buttons. Your callback fires once
per visible item button after each layout refresh; OneWoW Bags hands you the
button frame and the `(bagID, slotID)` it currently represents, and you do the
rest.

This document is the source of truth for the callback contract. The
implementation lives in
[`OneWoW_Bags/Integrations/OneWoWBagsIntegration.lua`](../Integrations/OneWoWBagsIntegration.lua);
the button mixin lives in
[`OneWoW_Bags/Modules/ItemButton.lua`](../Modules/ItemButton.lua).

---

## API at a Glance

```lua
if OneWoW_Bags then
    OneWoW_Bags:RegisterItemButtonCallback("MyAddon", function(button, bagID, slotID)
        -- Decorate `button` for the item at (bagID, slotID).
    end)
end

-- Later, if you want to detach:
OneWoW_Bags:UnregisterItemButtonCallback("MyAddon")
```

OneWoW Bags is published on the global table as `OneWoW_Bags`. Always
guard your registration with `if OneWoW_Bags then ... end` so your addon
keeps working when OneWoW Bags is not installed.

---

## Functions

### `OneWoW_Bags:RegisterItemButtonCallback(name, callback)`

Registers a callback under a string key. Re-registering the same `name`
replaces the previous callback for that key.

| Parameter | Type | Description |
|---|---|---|
| `name` | `string` | Unique identifier. Convention is your addon's folder name. |
| `callback` | `function` | Receives `(button, bagID, slotID)`. See [Callback Contract](#callback-contract). |

**Errors:** if `callback` is not a function, the call **raises a Lua error**
(`"InvalidCallback: callback must be a function"`). It is not silently logged
— a bad registration will surface immediately.

**Returns:** nothing.

### `OneWoW_Bags:UnregisterItemButtonCallback(name)`

Removes the callback registered under `name`. Safe to call when nothing is
registered for that name (no-op).

**Returns:** nothing.

---

## Callback Contract

```lua
function YourCallback(button, bagID, slotID)
    -- ...
end
```

### `button`

The pooled item button frame. It is created from
`ContainerFrameItemButtonTemplate` and recycled across layout refreshes by
[`Modules/ItemPool.lua`](../Modules/ItemPool.lua), so:

- The same `button` instance may represent different `(bagID, slotID)` pairs
  on subsequent calls. Always re-read the item from the bagID/slotID
  arguments — do not cache item state on the button without invalidating it.
- Treat the button as **opaque**. Do not call `:SetSize`, `:SetTexture`,
  `:SetAlpha`, etc. on it directly — OneWoW Bags rewrites those during
  `OWB_FullUpdate`. Attach a child frame instead (see
  [Adding an Overlay](#adding-an-overlay)).
- The button is guaranteed to be visible (`button:IsVisible() == true`) at
  the moment the dispatcher invokes your callback. You do not need to check.

The button does carry some internal state under an `owb_` prefix
(`owb_bagID`, `owb_slotID`, `owb_hasItem`, `owb_itemInfo`, etc.). These are
**implementation details** — they are not part of the public callback API and
may change without notice. Use the `bagID` and `slotID` arguments instead.

### `bagID`

The container index that contains this slot. Possible values come from
`Enum.BagIndex` (Retail). The exact set varies by client patch; in 12.0:

- `Enum.BagIndex.Backpack` (`0`)
- `Enum.BagIndex.Bag_1` … `Bag_4` (`1`–`4`)
- `Enum.BagIndex.ReagentBag` (`5`)
- `Enum.BagIndex.Bank`, `BankBag_*`, account-bank tab indices, and the
  warband/character bank tab indices added with the 11.x bank rework.

Don't hardcode numeric ranges; if you need to filter by bag type, use
`Enum.BagIndex` constants or `OneWoW_Bags.BagTypes:IsPlayerBag(bagID)`.

### `slotID`

The 1-based slot index inside `bagID`. Combined with `bagID`, it identifies
the slot you can query with `C_Container.GetContainerItemInfo(bagID, slotID)`,
`C_Container.GetContainerItemLink(bagID, slotID)`, or
`ItemLocation:CreateFromBagAndSlot(bagID, slotID)`.

---

## When Callbacks Fire

OneWoW Bags hooks the three window refresh entry points and dispatches
callbacks ~50 ms later (after the layout has settled):

| Window | Hook | Dispatch | Gating |
|---|---|---|---|
| Bags (`OneWoW_Bags.GUI`) | `RefreshLayout` | `FireCallbacksOnAllButtons` | Always (when window built) |
| Personal/Warband Bank (`OneWoW_Bags.BankGUI`) | `RefreshLayout` | `FireCallbacksOnBankButtons` | Only when `BankController:Get("overlays")` is true (`enableBankOverlays` in personal bank mode, `enableWarbandBankOverlays` when `bankShowWarband`) |
| Guild Bank (`OneWoW_Bags.GuildBankGUI`) | `RefreshLayout` | *(no callback dispatch)* | When **`db.global.enableBankOverlays`** is true, OneWoW overlays are **cleared** via `ClearGuildBankOverlays` (same global key as personal bank overlays—not the warband-specific overlay toggle) |

Bank dispatch is also fired on `BANKFRAME_OPENED` (after a 100 ms delay) when
the active bank mode's overlay toggle allows it (`BankController:Get("overlays")`).

The dispatcher iterates only buttons where `button:IsVisible() == true` and
the slot has been bound (`owb_bagID` / `owb_slotID` set), so empty layout
slots are skipped automatically.

### Junk-strip suppression

When **Strip Junk Overlays** is enabled (`db.global.stripJunkOverlays`) and
Alt-Show is not active, `FireItemButtonCallback` **returns early** for slots
where `button._owb_isJunk` is true (the internal flag OneWoW Bags sets from
PredicateEngine junk state during `OWB_FullUpdate`), and the OneWoW
`OverlayEngine:CleanButton` is invoked instead. If your overlay does not appear on grey items in this configuration,
this is the reason — it is intentional, so the user's "hide everything on
junk" preference is honored across integrations.

### Frequency

Callbacks fire on every layout refresh — bag updates, search input, view-mode
changes, settings toggles, etc. Keep them lightweight. Pre-compute lookup
tables, reuse frame objects, and avoid expensive scans inside the callback
body.

### Error handling

The dispatcher wraps each callback invocation in `pcall`. On failure, the
error is forwarded to the game's **`geterrorhandler()`** (same pipeline as
Blizzard's normal Lua errors), prefixed with the callback registration key so
you can identify which integration broke. Other addons' callbacks still run.

You do not need to add a defensive `pcall` of your own unless you want to
recover locally without surfacing to the global error handler.

---

## Adding an Overlay

### Pattern

Create a child frame on the button on first call, reuse it on subsequent
calls, and toggle visibility based on item state.

```lua
local ADDON_NAME = ...

if OneWoW_Bags then
    local function UpdateButton(button, bagID, slotID)
        if not button.MyAddonOverlay then
            button.MyAddonOverlay = CreateFrame("Frame", nil, button)
            button.MyAddonOverlay:SetAllPoints(button)
            button.MyAddonOverlay:SetFrameLevel(button:GetFrameLevel() + 1)
        end
        local overlay = button.MyAddonOverlay

        local itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
        if not C_Item.DoesItemExist(itemLocation) then
            overlay:Hide()
            return
        end

        local itemLink = C_Item.GetItemLink(itemLocation)
        local containerInfo = C_Container.GetContainerItemInfo(bagID, slotID)
        if not itemLink or not containerInfo then
            overlay:Hide()
            return
        end

        -- Apply your overlay logic here, then:
        overlay:Show()
    end

    OneWoW_Bags:RegisterItemButtonCallback(ADDON_NAME, UpdateButton)
end
```

### Conventions

- **Namespace your attachment.** Use `button.YourAddonName` (or similar) so
  you don't collide with another integration's overlay. Never use generic
  names like `button.overlay`.
- **Don't mutate the button.** No `SetSize`, `SetTexture`, `SetAlpha`,
  `SetFrameLevel`, etc. on the button itself — those are owned by OneWoW
  Bags. Mutate your child frame instead.
- **Reuse, don't recreate.** Allocate textures and font strings once and
  reuse them across updates. The button can be reassigned to different slots
  but it is not destroyed; your child frame persists with it.
- **Hide for empty slots.** When `C_Item.DoesItemExist` returns false, hide
  your overlay and return early. Otherwise the previous slot's decoration
  will linger on the recycled button.

---

## Working with Items

### Get the item link / location

```lua
local itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
if not C_Item.DoesItemExist(itemLocation) then return end

local itemLink = C_Item.GetItemLink(itemLocation)
local itemID   = C_Item.GetItemID(itemLocation)
```

### Container info

`C_Container.GetContainerItemInfo(bagID, slotID)` returns a table (or `nil`
for empty slots). The fields available in 12.0 are:

| Field | Type | Description |
|---|---|---|
| `iconFileID` | `number` | Icon file ID |
| `stackCount` | `number` | Stack size in the slot |
| `isLocked` | `boolean` | Slot is locked (mid-pickup, etc.) |
| `quality` | `number` | Item rarity (`Enum.ItemQuality.*`) |
| `isReadable` | `boolean` | Item has readable text |
| `hasLoot` | `boolean` | Lootable container |
| `hyperlink` | `string` | Item link |
| `isFiltered` | `boolean` | Filtered by Blizzard's combined-bags filter |
| `hasNoValue` | `boolean` | Item has no vendor value |
| `itemID` | `number` | Item ID |
| `isBound` | `boolean` | Item is soulbound to the player |

There is no separate `rarity` or `inventoryType` field — use `quality` and
look up `inventoryType` via `C_Item.GetItemInventoryTypeByID(itemID)` if you
need it.

### Item details by ID

Use `C_Item.GetItemInfo` (the legacy global `GetItemInfo` was removed in
12.0):

```lua
local name, link, quality, ilvl, minLevel, type, subType,
      stackCount, equipLoc, iconFileID, sellPrice, classID, subClassID,
      bindType, expacID, setID, isCraftingReagent
    = C_Item.GetItemInfo(itemID)
```

Item info is cached lazily by the client. If `name` comes back `nil` on the
first call, the engine has issued a server fetch — listen for
`GET_ITEM_INFO_RECEIVED` if you need to refresh decorations once the data
arrives.

### Quality values

```
Enum.ItemQuality.Poor       = 0
Enum.ItemQuality.Common     = 1
Enum.ItemQuality.Uncommon   = 2
Enum.ItemQuality.Rare       = 3
Enum.ItemQuality.Epic       = 4
Enum.ItemQuality.Legendary  = 5
Enum.ItemQuality.Artifact   = 6
Enum.ItemQuality.Heirloom   = 7
Enum.ItemQuality.WoWToken   = 8
```

---

## Setup Checklist

1. Add your integration file to your addon's `.toc`:
   ```
   Integrations\OneWoWBags.lua
   ```
2. Wrap the registration in `if OneWoW_Bags then ... end` so your addon
   loads cleanly when OneWoW Bags is absent.
3. Use a unique `name` (your addon folder name is a safe default) when
   calling `RegisterItemButtonCallback`.
4. Attach overlays as child frames on the button, namespaced by your addon.

---

## Troubleshooting

### My callback isn't firing

- Verify OneWoW Bags is loaded: `print(OneWoW_Bags ~= nil)` from `/run`.
- Make sure your integration file is listed in your `.toc` and your
  registration is reached at file load.
- Bank window: callbacks are gated on `BankController:Get("overlays")`. The
  user can disable bank overlays in OneWoW Bags settings; this is expected.
- Guild bank: callbacks are not dispatched; overlay clearing runs only when **`enableBankOverlays`** is true in SavedVariables (see [When Callbacks Fire](#when-callbacks-fire)).

### My overlay doesn't appear on grey/junk items

This is intentional when the user has **Strip Junk Overlays** enabled. See
[Junk-strip suppression](#junk-strip-suppression).

### My overlay flickers or shows the wrong item

You're probably caching item state on the button. The button is recycled
across slots; always re-read `bagID` / `slotID` from the callback arguments
on each call.

### `C_Item.GetItemLink` returns nil

Item info isn't cached yet. Either skip the slot this call (your callback
will be re-invoked on the next refresh, or sooner if a `BAG_UPDATE` fires),
or listen for `GET_ITEM_INFO_RECEIVED` and refresh once the data arrives.

### Items aren't updating when contents change

OneWoW Bags refreshes layouts on `BAG_UPDATE_DELAYED`, which fires once per
batch of `BAG_UPDATE` events. Your callback will be re-invoked then. If your
overlay depends on data outside the bag (vendor prices, transmog
collections, etc.), call your own update path on the relevant event and
either invalidate your cache or trigger a re-render of the affected slots.

---

## Related WoW APIs

- `ItemLocation:CreateFromBagAndSlot(bagID, slotID)`
- `C_Item.DoesItemExist(itemLocation)`
- `C_Item.GetItemLink(itemLocation)`
- `C_Item.GetItemID(itemLocation)`
- `C_Item.GetItemInfo(itemIDOrLink)`
- `C_Container.GetContainerItemInfo(bagID, slotID)`
- `C_Container.GetContainerItemLink(bagID, slotID)`
- `C_Container.GetContainerNumSlots(bagID)`
- `Enum.BagIndex`, `Enum.ItemQuality`

---

## See Also

- [`ARCHITECTURE.md`](ARCHITECTURE.md) — full OneWoW_Bags architecture, including
  the layout/refresh pipeline that drives callback dispatch.
- [`../API/Examples/`](../API/Examples/) — copy-paste integration templates
  (`Basic.lua`, `ColorOverlay.lua`, `TextBadge.lua`, `TransmogLootHelper.lua`).
