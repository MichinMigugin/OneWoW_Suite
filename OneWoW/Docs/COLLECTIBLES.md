# Collectibles (`OneWoW.Collectibles`)

> **See also:** [ARCHITECTURE.md](ARCHITECTURE.md) §6 (core service roster), §6/§7
> (LOD + cross-unit sharing model this builds on).

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
| pet | `pet:<speciesID>` | `C_PetJournal.GetNumCollectedInfo` |
| toy | `toy:<itemID>` | `PlayerHasToy` |
| heirloom | `heirloom:<itemID>` | `C_Heirloom` |
| decor | `decor:<recordID>` | `C_HousingCatalog` counts |
| campsite | `campsite:<sceneID>` | `C_WarbandScene` |

`sourceID` and `itemModifiedAppearanceID` are the same identifier; the `source`
subtype uses it directly.

**Resolved today (v1):** `mount`, `appearance:source`. The rest are valid keys
with no `ResolveDisplay` / `GetCollectionState` implementation yet — both return
`nil` for an unresolved type.

## API

| Function | Returns | Notes |
| --- | --- | --- |
| `BuildKey(type, [subtype,] id)` | canonical key string or `nil` | Validates type + integer id |
| `ParseKey(key)` | `{ type, subtype?, id, key }` or `nil` | `key` is re-canonicalized |
| `CanonicalizeKey(key)` | canonical key string or `nil` | Trims + lowercases untrusted input |
| `BuildLink(key)` | `(collectible=<key>)` token or `nil` | Token grammar only; Notes renders the clickable link |
| `ResolveDisplay(key)` | `{ name, icon, link, sourceText?, type }` or `nil` | Live per-type resolution |
| `GetCollectionState(key)` | type-specific table or `nil` | Live; never persisted |
| `GetEnsembleMemberKeys(setID)` | `{ "appearance:source:<id>", … }` or `nil` | All set sources (incl. alternates) as collectible keys |
| `GetEnsembleProgress(setID)` | `{ collected, total, name }` or `nil` | Live set completion; matches Blizzard's Sets tab (primary appearances) |
| `GetContainingSets(key)` | `{ setID, … }` or `nil` | Sets that contain an `appearance:source` key |

`GetCollectionState` always returns a table with a common `collected` boolean
plus type-specific detail (so callers never branch on the return **type**):

- `mount` → `{ collected }`
- `appearance:source` → `{ collected, bySource, byItem? }` (`collected == bySource`)

## Ensemble / transmog-set rollups (v2-B)

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

## Secret-value caveat (12.0)

When a key is derived from a unit's aura (e.g. identifying a mount from the
target in instanced content), the source spellID may be a **secret value** that
cannot be branched on or concatenated into a key from tainted code. Callers must
gate on resolvable (non-secret) data and bail with a user-visible message rather
than building a bad key. Core resolution itself takes only plain numeric ids.

## Ingest paths & Notes-side views (v2-A / v2-C)

These live in consumers, not this service, but complete the picture:

- **InspectMog → appearance (v2-A):** with the InspectMog module's *Add
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
- **Collectibles tab type filter (v2-A):** the Notes tab filters rows by
  `ParseKey(key).type` (All | Mounts | Appearances); labels reuse Blizzard
  globals (`ALL`, `MOUNTS`, `WARDROBE`).
- **Player `collectibleRefs` / sightings (v2-C):** `OneWoW_Notes` stores a
  structured `{ key, spellID?, addedAt }` list per player note.
  `OneWoW_Notes_API.AddPlayerCollectibleRef` / `PlayerHasCollectibleRef` replace
  the old "search the note body for the link substring" dedup used by the
  *Add Mount Info* context menu (the content check remains a backward-compat
  fallback for pre-v2-C notes). Secret spellIDs (another unit's aura in
  instanced content) are dropped, per the caveat above.

## Merchant funnel (v2)

Vendor-discovered collectible capture (seeing an item at a vendor you cannot buy
yet) rides the core `OneWoW.Merchant` funnel, not this service. See the
Collectibles roadmap and the future `MERCHANT.md`; `OneWoW.Collectibles` gains a
`ResolveKeyFromItem(itemID)` helper at that stage.
