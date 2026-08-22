# OneWoW - Extended Data

**Optional extra catalog data. Not in the main Suite / CurseForge zip.**

Adds leftover older quests (Classic through Dragonflight) that the default
Quests pack does not ship. Midnight and The War Within stay complete in
`OneWoW_CatalogData_Quests`. Later packs (NPCs, items) can land in
`Data/NPCs/` and `Data/Items/`.

Catalog, the Quests tab, and completion tracking work without this addon.

---

## What This Addon Does

- Queues leftover quest shards at load
- Registers them into the Quests store when `OneWoW_CatalogData_Quests` is ready
- Does nothing useful for quests if Quests is disabled (future packs will not need Quests)

No standalone UI. No SavedVariables.

---

## Installation

1. Copy `OneWoW_ExtendedData` into `Interface\AddOns\`
2. Keep `OneWoW` and (for leftover quests) `OneWoW_CatalogData_Quests` enabled
3. `/reload`

This folder is excluded from the Suite zip. Get it from the Suite git repo or a
separate download.

---

## If This Module Is Disabled

Older leftover quests disappear from Catalog search. Midnight, The War Within,
story/campaign chains, and quest completion stay in the default Quests pack.

---

**Author:** MichinMuggin / Ricky

**Website:** https://onewow.net/
