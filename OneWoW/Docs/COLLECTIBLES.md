# Collectibles (`OneWoW.Collectibles`)

> **See also:** [ARCHITECTURE.md](ARCHITECTURE.md) §6 (core service roster), §6/§7
> (LOD + cross-unit sharing model this builds on). Direction parking lot (not
> committed scope): [COLLECTIBLES_IDEAS.md](COLLECTIBLES_IDEAS.md); executable
> plans: [TRACKERS_IDEAS.md](../../OneWoW_Trackers/Docs/TRACKERS_IDEAS.md).

One core service owns collectible **identity**: it turns a stable collectible
key string into live display data and live collection state, and defines the key
grammar every other unit uses to reference a collectible across load-unit
boundaries. It holds **no SavedVariables** — user content (categories, intent,
notes) lives in `OneWoW_Notes`, executable plans live in `OneWoW_Trackers`, and
both key their rows by these strings.

**File:** [`OneWoW/Services/Collectibles.lua`](../Services/Collectibles.lua),
published as `OneWoW.Collectibles` via the Facade.

## LOD split

| Layer | Owns | Keyed by |
| --- | --- | --- |
| `OneWoW.Collectibles` (core, always loaded) | Identity, key grammar, live display + collection state | — |
| `OneWoW_Notes` (LoD) | User content: category, intent, note body, acquisition metadata; per-player `collectibleRefs` (sightings) | collectible key |
| `OneWoW_Trackers` (LoD) | Executable acquisition plans | collectible key |

Passive display resolves against core only. Writes to user content go through
the owning unit's `_API` after `OneWoW:BringUp("OneWoW_Notes")` on a **user**
action — never on a passive resolve.

## Key grammar: `type[:subtype]:id`

Each type carries at most one subtype segment; `id` is always the trailing
positive integer. The grammar is complete for every planned type, so a key built
today stays valid as resolution is extended to more types.

| type | key | Collection query |
| --- | --- | --- |
| mount | `mount:<mountID>` | `C_MountJournal.GetMountInfoByID` |
| appearance | `appearance:source:<sourceID>` | `PlayerHasTransmogItemModifiedAppearance` |
| appearance (alt) | `appearance:ima:<imaID>` | reserved (grammar only) |
| appearance (item) | `appearance:item:<itemID>` | stored keys only (`PlayerHasTransmog`); `ResolveKeyFromItem` no longer mints these |
| pet | `pet:<speciesID>` | `C_PetJournal.GetNumCollectedInfo` |
| toy | `toy:<itemID>` | `PlayerHasToy` |
| heirloom | `heirloom:<itemID>` | `C_Heirloom` |
| set | `set:<setID>` | `C_TransmogSets.GetSetInfo(...).collected` (rolled up from members) |
| decor | `decor:<recordID>` | `C_HousingCatalog.GetCatalogEntryInfoByRecordID` owned counts (`entryType` = Decor) |
| recipe | `recipe:<itemID>` | recipe known via `ns.RecipeKnownUtil:IsRecipeKnown(itemID, context)` (tooltip `ItemSpellTriggerLearn` → recipe spell → ProfessionRecipe scan cache / AltTracker / `GetRecipeInfo(...).learned`; contextual bag/slot/live `tooltipData` for legacy books) |
| campsite | `campsite:<sceneID>` | `C_WarbandScene` |

`sourceID` and `itemModifiedAppearanceID` are the same identifier; the `source`
subtype uses it directly.

**Resolved today:** `mount`, `appearance:source`, `appearance:item` (stored
keys only; not minted from items), `pet`, `toy`, `heirloom`,
`set` (transmog set / "ensemble"), `decor` (housing catalog), and `recipe`
(profession recipe items). `campsite` is a
valid key with no `ResolveDisplay` / `GetCollectionState` implementation yet — it
returns `nil` for an unresolved type.

### `set` is an acquisition record, not a new collection primitive

A transmog set is the single thing a vendor sells and the thing a note links to,
so it is a **first-class acquisition key** (`set:<setID>`) that owns its own
record, vendor offers, and detail view. Collection **truth** for a set stays a
*view*, never a stored flag: `GetCollectionState("set:…")` derives from the set's
member appearances. Members themselves are **not** fanned out into records —
they are a live, read-only view (`GetSetMembers`); the set is the only stored key.
This is the deliberate split behind the design anchor "ensembles/achievements/
filters are views, not primary keys": that still holds for *collection state*,
while a set is a legitimate *acquisition* key (unlike a filter or achievement,
which never becomes a record).

### heirloom vs. appearance — `IsItemHeirloom` is the gate, not item quality

`ResolveKeyFromItem` classifies heirlooms with `C_Heirloom.IsItemHeirloom(itemID)`
(the same authoritative check Blizzard's own `MerchantFrame.lua` uses), **never**
item quality. Some legacy vendor items (e.g. Enchanter Erodin's Dreadmist pieces)
render at heirloom quality (Q7) but are pre-upgrade-system transmog-source tokens:
`IsItemHeirloom` returns `false`, they never enter the heirloom collection, and
they only grant a transmog appearance. Those correctly fall through the heirloom
gate to `appearance:source`, which yields real, resolvable collection state —
whereas keying them as heirlooms would make `PlayerHasHeirloom` report them
"uncollected" forever. Do not trust quality color over the API.

## API

| Function | Returns | Notes |
| --- | --- | --- |
| `BuildKey(type, [subtype,] id)` | canonical key string or `nil` | Validates type + integer id |
| `ParseKey(key)` | `{ type, subtype?, id, key }` or `nil` | `key` is re-canonicalized |
| `CanonicalizeKey(key)` | canonical key string or `nil` | Trims + lowercases untrusted input |
| `BuildLink(key)` | `(collectible=<key>)` token or `nil` | Token grammar only; Notes renders the clickable link |
| `ResolveDisplay(key)` | `{ name, icon, link, sourceText?, type }` or `nil` | Live per-type resolution |
| `GetCollectionState(key)` | type-specific table or `nil` | Live; never persisted |
| `GetItemCollectionStatus(itemID, hyperlink?, context?)` | `{ applicable, collected, collectedByAlt?, key, type, … }` or `nil` | Item-facing facade. `nil` when the item has no collection relationship. `{ applicable = false, collected = false, type = "appearance" }` when a transmog source exists but cannot enter the wardrobe (tooltip Not Collectable; not `#transmog` / `#uncollected`). Otherwise `applicable = true`. Optional `context` = `{ bagID?, slotID?, tooltipData?, hyperlink? }` for player-evaluated tooltip lines (recipe “Already known”, legacy profession books). `collectedByAlt` is recipe-only |
| `ResolveKeyFromItem(itemID, hyperlink?)` | canonical key string or `nil`; second return `true` when a transmog source exists but cannot enter the wardrobe | Maps an item → the collectible it grants (mount/toy/pet/heirloom/**recipe**/**set**/**decor**/appearance) |
| `ResolveTransmogSourceID(itemID, hyperlink?)` | `sourceID` or `nil` | `itemModifiedAppearanceID` via GetItemInfo, TryOn, or artifact link synthesis; `nil` when the source is `NotValidForTransmog` or `CantCollect` |
| `GetOfferAffordability(offer)` | `{ affordable, requirements = { … } }` or `nil` | Live check of a vendor offer vs. player gold / currencies / items; never persisted |
| `GetEnsembleMemberKeys(setID)` | `{ "appearance:source:<id>", … }` or `nil` | All set sources (incl. alternates) as collectible keys |
| `GetEnsembleProgress(setID)` | `{ collected, total, name }` or `nil` | Live set completion; matches Blizzard's Sets tab (primary appearances) |
| `GetSetMembers(setID)` | `{ { key?, name?, icon?, link?, collected }, … }` or `nil` | Live, read-only per-slot member rows for the set's detail/tree view (never persisted) |
| `GetContainingSets(key)` | `{ setID, … }` or `nil` | Sets that contain an `appearance:source` key |
| `GetPunchListSummary(cacheItemID, tooltipData?)` | `{ cacheName, missing = { { itemID, name }, … } }` or `nil` | Container footers: class-filtered content group via `punchList` (tooltip name match) or `direct` (full pool). `missing` empty when every evaluated collectible is owned (see Punch-list / container contents) |

`GetCollectionState` always returns a table with a common `collected` boolean
plus type-specific detail (so callers never branch on the return **type**):

- `mount` → `{ collected }`
- `appearance:source` → `{ collected, bySource, byItem? }` (`collected == bySource`)
- `appearance:item` → `{ collected, byItem }` (`collected == byItem`; stored keys only)
- `pet` → `{ collected, numCollected, limit? }` (`collected == numCollected > 0`)
- `toy` → `{ collected }`
- `heirloom` → `{ collected }`
- `set` → `{ collected, numCollected, total }` (`collected` == whole set owned)
- `decor` → `{ collected, numOwned, numStored, numPlaced }` (`collected` == `numOwned > 0`; quantity model — owned across storage + placed, matching Blizzard's `GetEntryTotalOwned`)
- `recipe` → `{ collected }` (`collected` == the taught recipe is known)

## Ensemble / transmog-set rollups

An ensemble is a transmog **set** — a bundle of appearance sources. These are
pure live views over `C_TransmogSets` with **no SavedVariables**:

- `GetEnsembleMemberKeys(setID)` enumerates **all** the set's sources
  (`C_TransmogSets.GetAllSourceIDs`, including each slot's alternate sources) as
  canonical `appearance:source` keys. This is a *superset* of the set's primary
  appearances, so its count is larger than Blizzard's completion figure — use it
  only when you need every source key that belongs to the set.
- `GetEnsembleProgress(setID)` returns `{ collected, total, name }` counted over
  the set's **primary appearances** (`C_TransmogSets.GetSetPrimaryAppearances`,
  one per slot), so it matches the "x/y" Blizzard shows in Appearances > Sets.
  Each primary appearance carries its own live `collected` flag.
- `GetContainingSets(key)` bridges the other way: given an `appearance:source`
  key it returns the set ids that contain it, so a consumer (e.g. the Notes
  Collectibles detail panel) can show set progress without touching
  `C_TransmogSets` directly.

Progress and member keys deliberately use **different** set APIs:
`GetSetPrimaryAppearances` (per-slot, Blizzard-parity count) for the displayed
completion, and `GetAllSourceIDs` (every source, incl. alternates) for the full
member-key list. Counting completion over `GetAllSourceIDs` roughly doubles the
total (each slot's alternate sources) and disagrees with Blizzard's UI.

## Collection state is live

`GetCollectionState` queries the Blizzard journals on every call. Collection
status is **never** persisted as truth in SavedVariables — a note may record
that a collectible is wanted, but whether it is *collected* is always answered
live so it can never drift from the game state.

`GetItemCollectionStatus(itemID, hyperlink?, context?)` is the item-facing entry point:
tooltips, `#collected` / `#collectionknown`, `#altcollected`, and
`props.isCollected` all read through it (key resolution via `ResolveKeyFromItem`,
state via `GetCollectionState`). Callers that mean "this is a collectible" must
check `status.applicable`. Pass `context` when the caller has bag/slot or
live tooltip data — required for legacy recipe items (e.g. Master Cookbook **27736**)
where `C_TooltipInfo.GetItemByID` omits player-evaluated `ITEM_SPELL_KNOWN` lines.
For recipes, `collected` is the logged-in character only; `collectedByAlt` is true
when a scoped alt in Recipe Knowledge's `altScope` knows the recipe and you do not.

Appearance resolution in `ResolveKeyFromItem` uses the same lookup as
`Collectibles.ResolveTransmogSourceID(itemID, hyperlink)`: hyperlink, bare
itemID, DressUpModel TryOn (Remix / poisoned links), then artifact link
synthesis when quality is Artifact. A resolved source whose
`GetSourceInfo().sourceType` is `Enum.TransmogSource.NotValidForTransmog` or
`CantCollect` is not a wardrobe collectible (starter profession tools still
have a preview source): no collectible key, overlay/`#transmog` stay off, and
`GetItemCollectionStatus` returns `applicable = false` so a tooltip can show Not Collectable when QoL Tooltips > Collections > Show status for non-collectable items is on. `C_Item.IsDressableItemByID` is not collectability and
does not mint `appearance:item` keys. TryOn falls back to
`C_Transmog.GetSlotForInventoryType` for inv types outside the static slot map
(via `C_Item.GetItemInventoryTypeByID` → `C_Transmog.GetSlotForInventoryType`).

## Punch-list / container contents

[`CollectiblesPunchLists.lua`](../Services/CollectiblesPunchLists.lua) maps
container itemIDs to a shared **content group** (e.g. Preyseeker armor/weapons)
plus a **mode**:

| Mode | Containers | Evaluation |
| --- | --- | --- |
| `punchList` | Nebulous Voidcache: Prey (`269768`); Nebulous Voidcache: Delver's Trove (`268969`) | Match Blizzard `PUNCH_LIST_ITEM_CACHE_TOOLTIP` name-only lines against the class-filtered pool |
| `direct` | Preyseeker Adventurer / Veteran / Champion chests (`257023`, `257026`, `262346`); Bulging Ethereal Pack (`278026`); Bulging Winter Pack (`278027`) | No punch-list lines; evaluate every class-filtered ID |

Contents are armor/weapons only (rings/necks/trinkets omitted). Candidates are
filtered once per group with [`OneWoW.GearProficiency`](GEAR_PROFICIENCY.md)
(`ClassAllowsItem` — class weapon/armor proficiency + cloaks/holdables; not
`PlayerCanCollectSource` or `DoesItemContainSpec`). Lazy session cache, no login
preload. `GetPunchListSummary` returns `{ cacheName, missing }` (rows include
`quality` for tooltip coloring)
for the QoL Collections tooltip footer (`missing` empty → “All items collected
from …”). Uncached item data arms `ContinueOnItemLoad` +
`GameTooltip:RebuildFromTooltipInfo`. Unknown containers return `nil`; punch-list
mode also returns `nil` when the header is missing or no collectible matched yet.
Extend `CONTENT_GROUPS` / `CACHE_ENTRIES` — do not scrape English names as keys.

## Secret-value caveat (12.0)

When a key is derived from a unit's aura (e.g. identifying a mount from the
target in instanced content), the source spellID may be a **secret value** that
cannot be branched on or concatenated into a key from tainted code. Callers must
gate on resolvable (non-secret) data and bail with a user-visible message rather
than building a bad key. Core resolution itself takes only plain numeric ids.

## Ingest paths & Notes-side views

These live in consumers, not this service, but complete the picture:

- **InspectMog → appearance:** with the InspectMog module's *Add
  appearances to Collectibles* toggle on, shift-clicking an inspected slot
  upserts an `appearance:source:<sourceID>` collectible via
  `OneWoW_Notes_API.BuildAppearanceSourceKey` + `UpsertCollectible` instead of a
  legacy numeric Item note. **Both click zones route** when the toggle is on: the
  item-name zone adds the item's *own* appearance (`baseSourceID`), the transmog
  zone adds the *applied* appearance (`appearanceSourceID`). This resolves the
  two-zone confusion — one toggle flips the whole panel into collectible-capture
  mode, and each zone's tooltip states which appearance it adds. (No core
  `rowData` helper — the existing source-id→key builder already covers it, so
  core stays uncoupled from the inspect-scanner row shape.)
- **Collectibles tab type filter:** the Notes tab filters rows by
  `ParseKey(key).type`; labels reuse Blizzard globals (`ALL`, `MOUNTS`,
  `WARDROBE`, …). Now offers every resolved type (see the recycle-bin section
  below for the current type + collected filters).
- **Player `collectibleRefs` / sightings:** `OneWoW_Notes` stores a
  structured `{ key, spellID?, addedAt }` list per player note.
  `OneWoW_Notes_API.AddPlayerCollectibleRef` / `PlayerHasCollectibleRef` replace
  the old "search the note body for the link substring" dedup used by the
  *Add Mount Info* context menu (the content check remains a backward-compat
  fallback for legacy notes). Secret spellIDs (another unit's aura in
  instanced content) are dropped, per the caveat above.

## Merchant funnel & vendor offers

Vendor-discovered collectible capture (seeing an item at a vendor you cannot buy
yet) rides the core `OneWoW.Merchant` scan funnel, not this service.
`OneWoW_Notes/Core/CollectiblesMerchant.lua` subscribes to that funnel and, per
the **Vendor Collectible Capture** setting, turns any scanned item whose
`ResolveKeyFromItem(itemID)` maps to an *uncollected* collectible into a `want`
record carrying a slim vendor-offer junction:

```
record.acquisition.vendorOffers[] =
  { npcID, npcName, itemID, cost, currencies, isPurchasable, blockReason, location, lastSeen }
```

Capture is a **subscription decision**, not a handler-side gate:

- `off` — not subscribed (manual add only).
- `prompt` — subscribed; a per-vendor confirm before capturing genuinely new
  offers (`HasVendorOffer` filters already-known ones so repeat visits don't nag).
- `auto` — subscribed; silently upserts. The scan can be re-delivered, so every
  path is idempotent (`MergeVendorOffer` dedupes by `npcID + itemID`).

The Notes Collectibles detail panel renders a **Sold by** section from those
offers (hydrated with `OneWoW_CatalogData_Vendors_API` for name + waypoint when
that store is loaded, else straight from the offer snapshot). Live affordability
per offer comes from `OneWoW.Collectibles.GetOfferAffordability`, which compares
the offer's gold/currency/item costs against the player's current holdings — a
live view, never persisted.

The captured `isPurchasable` flag stays the "can / can't buy" gate. When it is
`false`, the panel answers **why** with the offer's `blockReason` line beneath the
vendor rows: the red (unmet-requirement) lines of the **merchant** tooltip,
captured at sighting by `OneWoW.Merchant` (`C_TooltipInfo.GetMerchantItem`). This
capture is deliberate — those player-evaluated requirement lines are added only by
the fully-rendered merchant tooltip; the template-only `C_TooltipInfo.GetItemByID`
/ `GetHyperlink` getters omit them, so a consumer viewing the offer later (away
from the vendor) cannot re-derive them. `blockReason` is a sighting snapshot that
pairs with `isPurchasable`: both refresh on the next visit (and clear once the row
becomes purchasable). Reasons are collected across blocked offers and deduped to
one line; if the gate is set but no reason was captured (an older offer, or a
purely availability-side gate like limited stock) it falls back to the generic
"couldn't buy when last seen" text. The currency coloring plus the requirement
line together explain "this is why you can't buy it."

**Ensembles at vendors.** An ensemble item resolves (via
`ResolveKeyFromItem` → `C_Item.GetItemLearnTransmogSet`) to a `set:<setID>` key,
so the *set* is captured as the buyable/want record and carries the vendor offer
— never the individual member appearances. Capture also stamps the teaching
`record.sourceItemID` so the set's row/detail can show the real ensemble item's
icon + link (a set has neither natively; core falls back to a member appearance's
icon). In the Notes Collectibles list a set is a **collapsible tree parent**: its
per-slot members render as live, read-only child rows (`GetSetMembers`) with a
collected/total roll-up on the parent — the members are views, so they are never
stored and are not individually selectable.

**Housing decor at vendors.** Because capture is generic
(`ResolveKeyFromItem` → `GetCollectionState`), housing decor sold at a merchant is
captured with **no capture-side change**: a decor item resolves to
`decor:<recordID>` (via `C_HousingCatalog.GetCatalogEntryInfoByItem`), and decor
you own zero of counts as "uncollected" so it lands on the want list with a vendor
offer. The detail view shows the localized owned breakdown
(`HOUSING_DECOR_OWNED_COUNT_FORMAT`: total / placed / storage) for the quantity
model, and the Collectibles type filter gains a **Decor** option
(`CATALOG_SHOP_TYPE_DECOR`).

**Recipes at vendors.** A recipe item (item class `Enum.ItemClass.Recipe` —
"Recipe:/Technique:/Pattern: …") resolves to `recipe:<itemID>`, keyed by the item
because that is what the vendor sells and what the merchant funnel sees. The class
is checked **before** the decor branch, so a *housing-decor recipe* is captured as
the recipe you buy — not the crafted decor it teaches (the recipe item does not map
to the decor's catalog entry). `collected` means the taught recipe is already
known, answered by the canonical **`ns.RecipeKnownUtil:IsRecipeKnown(itemID)`**: it
maps the recipe *item* to candidate spell/recipe IDs via the tooltip's
`ItemSpellTriggerLearn` line and the scan-built `recipeItemMap` (**not**
`C_Item.GetItemSpell`, which on e.g. an enchant "Formula:" returns the illusion
*Use* spell, not the teach spell), then answers known from the ProfessionRecipe
scan cache / AltTracker data / `GetRecipeInfo(...).learned` /
`C_SpellBook.IsSpellKnown`. Legacy profession books (e.g. removed TBC master
trainers) often expose a teach *spell* ID on the tooltip that differs from the
trade-skill *recipe* ID stored by AltTracker; both are checked. The type filter
gains a **Recipes** option (`AUCTION_CATEGORY_RECIPES`). This is why decor *recipes* at a
mixed vendor were not being captured before recipes were wired up: they are recipe
items, and had no resolved key.

## Recycle bin: intents, auto-delete & the collected filter

All of this lives in `OneWoW_Notes` (records + settings + UI), not the core
service — the recycle bin is *user content*, and collection state stays live.

**`delete` intent = the recycle bin.** The record intents are
`none | want | spotted | farming | delete`. `delete` is a soft, reversible
"marked for removal" state: those rows always sort to the **bottom** of the
Collectibles list (whatever the active sort) and render **dimmed** but fully
interactive (select to change the intent back, or delete now). `ns.Collectibles:SetIntent(key, intent)`
owns the bookkeeping, mirroring how capture files a want under "Want List":

- entering `delete` stamps `record.deletedAt` (the purge clock) and files the
  record under the **"Delete List"** category, stashing the prior category in
  `record.prevCategory` so a later restore is lossless;
- leaving `delete` restores `prevCategory` and clears both fields.

Never mutate `record.intent` directly — always go through `SetIntent` so the
timestamp/category stay consistent.

**Auto-delete (opt-in, default off).** `collectibleAutoDelete` + `collectiblePurgeTTLDays`
(account SavedVariables, default TTL 7 days; `0` = Immediate) drive a two-step
sweep, `ns.Collectibles:RunCleanup()`:

1. **Auto-recycle** — a *collected* record with an **active** intent (`want`,
   `spotted`, `farming`; a `none` library entry is left alone) is moved to the
   Delete List. Collection state is read live from core, so a journal that has
   not finished loading simply defers the recycle to a later sweep — it can never
   wrongly recycle an uncollected item.
2. **Purge** — a Delete-List record whose `deletedAt` is older than the TTL is
   **permanently removed** (`Immediate` purges on the same sweep it is recycled).
   Purge only ever touches the `delete` intent — the recycle bin is the sole
   destructive zone.

The sweep runs on **login** (initial `PLAYER_ENTERING_WORLD`) and whenever the
**Collectibles tab is opened** (`tab.Activate`); there is no background timer. A
manual **Empty Delete List** button (Settings → Collectibles) purges the whole
bin on demand via `ns.Collectibles:EmptyDeleteList()`, independent of the toggle.

**Collected filter.** The Collectibles tab has a `STATUS` dropdown
(All | `COLLECTED` | `NOT_COLLECTED`) that filters rows against live
`GetCollectionState(key).collected`, for players who keep everything but want to
narrow to what they still need vs. already own. Combined with the type filter,
which now offers **every resolved type** (mount, appearance, set, pet, toy,
heirloom, decor, recipe) using Blizzard-global labels.

**Settings rename.** The former "Vendor Collectible Capture" settings section is
now titled **Collectibles** (`TAB_COLLECTIBLES`); the capture mode dropdown keeps
its own "Vendor Collectible Capture" row label beneath it.
