# CatDB cutover — counts, callers, and 100% plan

Engineering note. Not player wiki. The Catalog pack toggle is gone:
`PackResolver` always returns CatDB. Ricky moved the five
`OneWoW_CatalogData_*` folders out of Suite / AddOns (they sit under
`--Removed Data Addon` only). Do not put them back. Wiki / player
READMEs / sites may still mention leftover names until the ship pass.

**Deletion blockers (runtime / registry / SV / generate / leftoverStores): done.**
Folders are already off the live tree.

Measured **2026-09-01**, client build pin `12.1.0.69497`.

**Sources (do not invent):**

- Workspace `Docs/CATDB_SCOREBOARD.md` — size / shard rows (`python bin/catdb_status.py scoreboard`)
- `bin/catdb_oldpack_backfill_report.md` — apply 2026-09-01 08:20 UTC
- `bin/catdb_validate_report.md` — joins / retired IDs, same timestamp
- `bin/_catdb_cutover_counts.py` — entity counts (this pass)
- Suite grep of Catalog, QoL, Trackers, Notes, ShoppingList, AltTracker,
  DevTool, FirstRun, zip, wiki, docs

**Verdict:** old `OneWoW_CatalogData_*` addons **are already off Suite and
AddOns**. Runtime, Home / Features, Discord zip list, generate path, and
one-shot SV copy no longer require those folders. Remaining work is wiki /
sites / READMEs and optional API stubs — not a delete blocker.

---

## Pack map

| Role (resolver) | Old addon | New addon |
|---|---|---|
| `journal` / `zones` | `OneWoW_CatalogData_Journal` | `OneWoW_CatDB_ZoneDB` |
| `vendors` / `npcs` | `OneWoW_CatalogData_Vendors` | `OneWoW_CatDB_NPCDB` |
| `items` | Journal extras + `JournalItemNames` | `OneWoW_CatDB_ItemDB` |
| `quests` | `OneWoW_CatalogData_Quests` | `OneWoW_CatDB_QuestDBCurrent` |
| `archive` | `OneWoW_CatalogData_Quests_Archive` | `OneWoW_CatDB_QuestDBArchive` |
| `tradeskills` | `OneWoW_CatalogData_Tradeskills` | `OneWoW_CatDB_TradeSkillDB` |

Old packs on disk (only these five): Journal, Vendors, Quests, Quests_Archive,
Tradeskills. **No Collectibles CatalogData pack.**

New packs: ZoneDB, NPCDB, ItemDB, QuestDBCurrent, QuestDBArchive, TradeSkillDB.
CatDB Data total: **89 files, 92.60 MB**. No stub TOCs.

Default path is **CatDB**. `PackResolver` always returns `pack.cat`.
Leftover CatalogData folders may still sit on disk unused.

Size tables live in Workspace `Docs/CATDB_SCOREBOARD.md`. This file owns
entity comparison and the cutover plan.

---

## Generator defaults (Workspace `bin/`)

Suite `OneWoW_CatalogData_*` folders are **thin stubs** (TOC + one Lua). Never
mkdir or write `Data/` there. Fat leftover trees are read-only under
`--Removed Data Addon`. Warehouse `.warehouse/Sources/` stays the pull shelf.

| Role | Write (CatDB) | Old-pack read (backfill only) |
|---|---|---|
| Zones / extras input | `OneWoW_CatDB_ZoneDB/Data` (+ `Generated` intermediates) | `--Removed Data Addon/OneWoW_CatalogData_Journal/Data` |
| NPCs | `OneWoW_CatDB_NPCDB/Data/NpcDB` | `.../OneWoW_CatalogData_Vendors/Data/NpcDB` |
| Items | `OneWoW_CatDB_ItemDB/Data` | extras + names on the Journal shelf |
| Quests | `OneWoW_CatDB_QuestDBCurrent/Data` | `.../OneWoW_CatalogData_Quests/Data` |
| Archive | `OneWoW_CatDB_QuestDBArchive/Data` | `.../OneWoW_CatalogData_Quests_Archive/Data` |
| Tradeskills | `OneWoW_CatDB_TradeSkillDB/Data` | `.../OneWoW_CatalogData_Tradeskills/Data` |

Going-forward emit (from Workspace root):

```
python bin/catdb_zone_emit.py
python bin/catdb_item_emit.py
python bin/catdb_npc_emit.py
python bin/catdb_quest_emit.py
python bin/catdb_tradeskill_emit.py --from-db2
```

Supporting generators (also write CatDB, not stubs):

```
python bin/journal_db2_tools.py generate
python bin/journal_extras.py emit
python bin/quest_db2_tools.py generate
python bin/tradeskill_db2_tools.py generate
python bin/npc_split.py emit
python bin/wowhead/quest-refresh.py ...
```

Old-pack backfill (reads `--Removed Data Addon` only):

```
python bin/catdb_oldpack_backfill.py --dry-run
```

---

## Part A — Count comparison

What “count” means is in the first column. Quest **named** uses shard quest
IDs from the scoreboard / backfill (`name=` on every shard row). The one-shot
script’s `["name"]` regex is inflated by nested fields — do not use those
named totals.

### Size (pointer)

| Pack | Old | Old rows | New | New rows | Delta MB |
|---|---|---:|---|---:|---:|
| Journal | Generated + extras + names 9.40 MB | 59,807 | ZoneDB + ItemDB item-half 13.73 MB | 55,152 | +4.33 |
| NPCs | Vendors 7.24 MB | 5,164 | NPCDB 9.23 MB | 21,746 | +1.99 |
| Quests | Quests + Archive 53.80 MB | 105,956* | QuestDB both 49.84 MB | 101,016* | −3.96 |
| Tradeskills | 3.27 MB | 11,851 | TradeSkillDB 3.27 MB | 11,851 | 0 |
| Items | extras + names 7.54 MB | 58,436 | ItemDB all 23.17 MB | 176,267 | +15.64 |

\*Scoreboard “rows” = shard rows + Generated keyed overlays (old Current overlay
69,700 keyed; new Current and Archive each ship the same 32,065 keyed overlay).
**Shard quest IDs:** old 36,256 vs new 36,886.

### Journal / Zone

| What “count” means | Old | New | Delta |
|---|---:|---:|---:|
| EJ instance cards vs ZoneDB **places** | 217 cards | 407 places | +190 |
| Places by kind | instance cards only | instance 203, delve 32, hub 9, world 4, zone 159 | — |
| Places with uiMapID / mapID | — | 365 unique uiMaps, 271 unique mapIDs | — |
| Places with entrance / lore / art / questIDs | — | 240 / 191 / 212 / 297 | — |
| EJ encounter rows vs ZoneDB encounters | 1,154 named | 4,464 (bosses 1,151, rares 3,030, general 283) | +3,310 |
| Named / nameless encounters | 1,154 named | 1,781 named, **2,683 nameless** (2,400 nameless rares) | — |
| Encounters with pin / npcIDs | — | 3,129 / 4,181 | — |
| Extras rows | 39,368 | folded into encounter loot | — |
| Extras with x/y | **13,415** | pins on encounters (3,129) | — |
| Extras with mapID / unique mapIDs | 15,853 / 232 | 9 extras mapIDs have no ZoneDB uiMap or mapID: 130, 142, 153, 157, 162, 306, 322, 401, 598 | — |
| Extras / loot with `achievementID` | **0** shipped | loot `achievementID` **0** | 0 |
| Extras with npcID / world flag | 18,651 / 29,339 | — | — |
| JournalLoot rows / unique items | 23,913 / 19,068 | encounter loot rows 67,945 / unique 50,407 | +44,032 / +31,339 |
| JournalItemNames | 19,068 | drop names via ZoneDB `GetItemNameIndex` + ItemDB | — |

ZoneDB also ships `Difficulties.lua`, `MapDifficulties.lua`,
`TierMembership.lua`, `ListingOverrides.lua`.

World **cards** = ZoneDB `kind=world` (4). Old extras `world=29,339` are
extras **rows** flagged world, not 4 world cards.

### Vendors / NPC

| What “count” means | Old Vendors | CatDB NPCDB | Delta |
|---|---:|---:|---:|
| NPC rows | 5,164 (all `vendor` role) | **21,746** people | +16,582 |
| Old IDs missing from new | — | **0** | 0 |
| New-only IDs | — | 16,582 | — |
| Roles (a row can have several) | vendor 5,164 | quest_giver 13,530, vendor **5,348**, rare 3,084, boss 1,814, trainer 334, vignette 269 | — |
| Rows with category | 502 (13 keys) | 1,355 (17 keys) | +853 |
| **barbershop** shipped rows | **0** | **0** | UI key exists; live scan can assign |
| Rows with items / locations | 4,919 / 2,780 | 5,134 / 16,790 | +215 / +14,010 |
| placeKeys | 0 | 18,931 | — |
| Stock rows with `cost` (same SKU cites) | 74,775 | 74,775 | 0 |

New category keys old lacked: `quest_giver`, `mount`, `catalyst`, `toy`.
No old-only category keys.

Old category keys (502 rows): pvp 120, quartermaster 8, pet 22,
profession_trainer 5, decor 324, profession_supplies 2, guild_vendor 4,
innkeeper 1, repair 4, stable_master 1, fishing 1, delve 8, food 2.

`GetAllVendors()` is **vendor-role / trainer-that-sells** (`ns.VendorIDs`),
not all 21,746 people. `GetNPC` / `GetVendor` both overlay any row.
There is **no** `GetAllNPCs` / `GetNPCsByRole` yet.

### Quests

Every shard row is named (backfill `name=`). Script `named` counts are
wrong (nested `["name"]`).

| What “count” means | Old Current + Archive | CatDB Current + Archive | Delta |
|---|---:|---:|---:|
| Shard quest IDs (named) | 36,256 | 36,886 | +630 |
| Old-only IDs | 61 | — | `old_quest_unnamed` skip |
| New-only IDs | — | 691 | — |
| starts tables | 29,910 | 27,869 | −2,041 |
| ends tables | 29,949 | 28,692 | −1,257 |

Start/end drop is **by design**: npc pins live on NPCDB; quest `starts` /
`ends` are `{ npcID }` only. Backfill added 826 Journal starts onto QuestDB.

Quest start/end npcIDs → NPCDB: **0 missing** (validate).

Old-only quest samples: 10557, 10710–10712, 11170, 11307, 11719, 12300,
12520, 12645, 25621, 27114, 29433, 29636, 30031, 30047, 31537, 31669,
31944, 32114.

### Tradeskills

**Exact 1:1:** 11,851 recipes, 14 files including Fishing + HousingDyes (93).
Backfill filled 733 recipe `npc`, 375 `map`/`xy`, 98 trainer roles.

Archaeology is not in either pack.

### Items

| What “count” means | Old | New | Delta |
|---|---:|---:|---:|
| Live ItemSparse (+ currencies) | Journal extras ∪ names ∪ JournalLoot | 174,806 items + 1,461 currencies = **176,267** | full Sparse |
| Journal union unique IDs | 50,409 | 50,281 in ItemDB | **128 missing** |

Validate missing joins:

- Encounter loot → ItemDB: **128** unique (121 absent Sparse, 7 skip_name)
- Vendor stock → ItemDB: **11,356** unique (11,332 absent Sparse — retired, still cited; 24 skip_name)
- Tradeskill item/reagents → ItemDB: **83** unique (81 absent Sparse, 2 skip_name)

### Backfill skips (not unique usable old data)

- `item_name_present` 58,301
- `extras_loot_no_enc` 15,456
- `quest_zone_missing` 6,610
- `vendor_zone_missing` 514
- `item_not_in_itemdb` 135
- `old_quest_unnamed` 61
- `recipe_quest_missing` 23
- `journal_loot_no_enc` 2

NPC placeKeys → ZoneDB: 1,150 referenced, **780 missing** (779 `zone:N`
quest/extras maps, 1 `instance:1310`). ZoneDB only ships 407 catalog cards —
**do not invent places**.

### Gaps

**Old had / new lacks (usable shipped data):**

- Not unique extras rows or vendor category keys. Backfill copied what was
  fillable. Skipped extras without an encounter (`extras_loot_no_enc` 15,456)
  are not a second store — they had nowhere to hang.
- 61 unnamed old quests skipped (`old_quest_unnamed`). Not UI-usable.
- 128 journal / 11,356 vendor / 83 recipe itemIDs not in ItemDB = **retired /
  skip_name**, not live retail. Item emit does not add retired Sparse IDs.
- 2,683 nameless encounters (2,400 rares). Names are live tooltip, not shipped.
- **No Barber rows in either pack** (locale + category map exist; 0 shipped).
- **No `achievementID` on extras or ZoneDB loot rows.** `GetAchievementsForItem`
  on CatDB indexes `loot.achievementID` → empty. Old extras also ship 0;
  the old path can still pick up IDs from **live EJ merge**.
- 9 extras mapIDs with no Zone card (listed above).
- Quest start/end **tables** fewer because pins moved to NPCDB.

**New never had on old:**

- 21,746 NPCs (not just 5,164 vendors)
- Full ItemSparse + currencies
- Place lore / art / entrance / questIDs
- Encounter pins / displayIDs / rares / general
- NPC roles beyond vendor (quest_giver, rare, boss, trainer, vignette)
- Category keys `quest_giver`, `mount`, `catalyst`, `toy`

**CatDB API stubs vs old live:**

- `GetScaledLootLink` — old `EJLiveLoot.lua` is real; ZoneDB **always returns
  nil**. `t-journal.lua` calls it for scaled loot links.
- `MergeLiveATTExtras` — ZoneDB stub `return inst ~= nil and false`.
  `t-journal.lua` still calls it. Live ATT overlay is fallback-only per
  Shipped-Data; decide implement vs drop.
- `GetKnownRecipes` — old Tradeskills reads `scanCache`; TradeSkillDB
  **always returns `{}`**. QoL `professionspanel.lua` calls it for alt
  overlays. `IsRecipeKnown` / `GetRecipeKnownBy` already read
  `OneWoW_AltTracker_Professions_API` instead. TradeSkillDB ARCHITECTURE
  says scanCache stays on the old pack until a known-recipe overlay lands.
- `GetAchievementsForItem` — empty until loot rows carry `achievementID` or
  a live EJ join exists.

---

## Part B — Full caller scan

Default: PackResolver always returns CatDB (`pack.cat`).

`WatchCatalogDataReady` remaps the string through `ResolveCatalogPack`, so
hardcoded `OneWoW_CatalogData_Journal` / `_Quests` still work today. After
old folders are gone those strings only resolve via `ADDON_TO_ROLE`. Prefer
roles (`"journal"`, `"quests"`) before delete.

No `OneWoW_Map` addon. Pins = Notes WayPins + Catalog Navigation.
Trackers has **no Lua callers** (docs only). CompletionTracker lives
**inside** the quest packs (old Current + CatDB Current).

### Resolver / toggle (must change on cutover)

| File | What |
|---|---|
| `OneWoW/Core/PackResolver.lua` | `PACKS`, `ResolveCatalogPack`, `GetCatalogPackAPI`, `EnsureCatalogPack`, `IsCatalogPackAvailable` (always CatDB) |
| `OneWoW/Core/Facade.lua` | publishes those names |
| `OneWoW_Catalog/Core/PackResolver.lua` | Catalog wrappers + `GetCatalogItemSearchAddons` |
| `OneWoW_Catalog/Core/API.lua` | pack resolve wrappers (former toggle APIs removed) |
| `OneWoW_Catalog/Core/Database.lua` | Catalog defaults (former CatDB-toggle default removed) |
| `OneWoW_Catalog/UI/t-settings.lua` | checkbox + **hardcoded old DB manager keys** Journal / Vendors / Tradeskills |
| `OneWoW_Utility_DevTool/Core/API.lua`, `Core/Database.lua`, `GUI/Tabs/SettingsTab.lua` | same toggle |
| Locales | former CatDB-toggle keys removed (shared + Catalog + DevTool, all 11) |

### Callers already on PackResolver (keep; hard-point CatDB)

| File | Wants | Resolver? | Old API named? | Papers over? |
|---|---|---|---|---|
| `OneWoW_Catalog.lua` | tab `requiresAddon` | yes, roles | no | no |
| `t-journal.lua` | instances, loot, quests, scaled links, ATT merge | `GetCatalogPackAPI("journal"\|"quests")` | watcher string `OneWoW_CatalogData_Journal` (remapped) | calls stub `GetScaledLootLink` / `MergeLiveATTExtras` on CatDB |
| `t-vendors.lua` | vendor list / stock / pins | `GetCatalogPackAPI("vendors")` + `ResolveCatalogPack("vendors")` | no | `GetAllVendors` = vendor-role only (correct for this tab) |
| `t-quests.lua` | quest rows / completion | `GetCatalogPackAPI("quests")` | watcher string `OneWoW_CatalogData_Quests` (remapped) | no |
| `t-tradeskills.lua` | recipes + trainer names | tradeskills + vendors | no | no |
| `t-itemsearch.lua` | ItemDB pack name | `ResolveCatalogPack("items")` | no | no |
| `m-itemsearch.lua` | drops / vendors / crafted / quests / names | yes | no | drops always require journal **and** ItemDB |
| `DataPackLoader.lua` | EnsureLoaded quests | `ResolveCatalogPack("quests")` | no | no |
| `CatalogTabReady.lua` | remap watcher names | yes | accepts old folder names | remap is the paper-over |
| `QoL/Tooltips/tp-itemtracker.lua` | Where: vendors, journal drops, tradeskills, quests | `EnsureCatalogPack` + `GetCatalogPackAPI` | no | overflow “see Catalog” is a UX cap, not a data fallback |
| `QoL/Portals/portalhub-esc-panels.lua` | `GetInstanceByMapID` | journal | no | no |
| `QoL/Features/toast-instance.lua` | `GetInstanceByMapID` | journal | no | no |
| `QoL/UI/t-tooltips.lua` | require-rows | `IsCatalogPackAvailable` | no | no |
| `QoL/Modules/external/professionspanel/professionspanel.lua` | alt known recipes | tradeskills `GetKnownRecipes` | no | **empty on CatDB** |
| `Notes/UI/t-collectibles.lua` | `GetVendor` | vendors | no | no |
| `Notes/UI/ui-waypin-find.lua` | vendor stock search | vendors | no | no |
| `OneWoW/Features/ContextMenus.lua` | `GetAllVendors` → Open Vendor Details | vendors | no | vendor-role only |
| `ShoppingList/Modules/ShoppingList.lua` | recipes | tradeskills | no | no |
| `ShoppingList/Modules/DataAccess.lua` | recipes + watcher | tradeskills | no | no |
| `AltTracker/Core/CharacterCleanup.lua` | purge quests + tradeskills | yes | no | CatDB `GetKnownRecipes` empty; completion is on QuestDBCurrent SV |
| `AltTracker/UI/t-professions.lua` | tradeskills watcher | `ResolveCatalogPack("tradeskills")` | no | no |
| `AltTracker_Professions` Database / API / ProfessionRecipeCommit | recipe commit | `GetCatalogPackAPI("tradeskills")` | no | no |
| ZoneDB API | drop names + quest text | ItemDB direct + `GetCatalogPackAPI("quests")` | no | `GetItemNameIndex` is drop-only (correct; walking all ItemDB stalled search) |
| NPCDB / TradeSkillDB APIs | item names | `OneWoW_CatDB_ItemDB_API` **direct** | no | correct (item identity) |

### Hardcoded old names (still resolve today)

| File | String | After cutover |
|---|---|---|
| `t-journal.lua` ~3004 | `WatchCatalogDataReady("OneWoW_CatalogData_Journal", …)` | use `"journal"` (another agent owns this file — do not fight) |
| `t-quests.lua` ~5326 | `WatchCatalogDataReady("OneWoW_CatalogData_Quests", …)` | use `"quests"` |
| `t-settings.lua` | DB manager keys Journal / Vendors / Tradeskills | CatDB SV names |
| `OneWoW/UI/t-charprofiles.lua` | CatDB `_DB` names | **done** |
| `OneWoW/Core/AddonLoader.lua` | six CatDB only; `leftoverStores` removed | **done** |
| `OneWoW/Core/FirstRunWizard.lua` | STORE_* + ShoppingList datastore = CatDB | **done** |
| `AltTracker/Core/MigrationFix.lua` | one-shot copy of leftover WTF `Quests_DB.completion` + user vendor categories | **done** (scanCache stays AltTracker Professions) |
| `AltTracker/UI/t-settings.lua` | generate path `OneWoW_CatDB_ZoneDB/Data/Generated/` | **done** |
| `Catalog/Core/VendorCategories.lua` | comment names `OneWoW_CatalogData_Vendors_DB.global.vendors[npcID].category` | NPCDB `vendorCategories` |
| `Catalog/Services/VisibleItemFill.lua` | comment points at old JOURNAL_DATA.md | ZoneDB docs |
| `CatalogData_Journal/Modules/JournalData.lua` | **direct** `OneWoW_CatalogData_Quests_API` | dies with the old pack |

### Helpers that paper over / dual-path

| Helper | What it hides | After cutover |
|---|---|---|
| Former CatDB-toggle APIs | old-vs-new choice | **deleted** |
| PackResolver old-first branch | prefers CatalogData when present | hard-point `pack.cat` |
| `WatchCatalogDataReady` remap | old folder names still work | callers pass roles; remap can stay as a one-release alias then drop |
| `m-itemsearch` `SOURCE_AVAILABILITY.drops` | ItemDB required for drops | always require ItemDB for drops |
| ZoneDB `GetScaledLootLink` | always nil | implement (live EJ) or drop the journal call |
| ZoneDB `MergeLiveATTExtras` | always false | implement (live overlay only) or drop the journal call |
| ZoneDB `GetAchievementsForItem` | empty (0 shipped `achievementID`) | emit join or live EJ; old extras also 0 |
| TradeSkillDB `GetKnownRecipes` | always `{}` | wire to AltTracker Professions (same as `GetRecipeKnownBy`) or port `scanCache` onto TradeSkillDB_DB |
| ZoneDB `ResolveNPCName` | NPCDB live tooltip | keep (correct) |
| Item Search `ResolveSearchItemName` | ItemDB then `C_Item.GetItemNameByID` | keep (live fill) |
| tp-itemtracker “see Catalog” | UX overflow cap | keep |

### Loader / zip / registry / tooling

| Surface | Today | Cutover |
|---|---|---|
| `AddonLoader.lua` Catalog `stores` | six CatDB; `leftoverStores` gone | **done** |
| `STORE_LABEL_KEYS` | CatDB only | **done** |
| FirstRun ShoppingList datastore | `OneWoW_CatDB_TradeSkillDB` | **done** |
| FirstRun STORE_ICONS / DESC / AFFECTED | CatDB | **done** |
| Zip / nightly | `discover_addon_dirs()` — leftover folders already off Suite | **done** |
| Discord `Bot-Titan/data/addon-registry.json` | CatDB six | **done** |
| `.luarc.json` | ignore + globals for old + CatDB APIs | drop old |
| Suite `.pre-commit-config.yaml` | excludes `OneWoW_CatalogData_Quests/Tools/` | drop those excludes with the folder |
| Catalog TOCs | `RequiredDeps: OneWoW`; Journal `OptionalDeps: AllTheThings` | ZoneDB needs the ATT OptionalDeps **only if** live ATT merge is kept |
| Workspace emit scripts | still **read** old packs | keep as history / one-shot until folders are gone, then point at warehouse only |

### SavedVariables

| Old | New | Player data that must move |
|---|---|---|
| `OneWoW_CatalogData_Journal_DB` | `OneWoW_CatDB_ZoneDB_DB` | settings only |
| `OneWoW_CatalogData_Vendors_DB` | `OneWoW_CatDB_NPCDB_DB` | user `category` / `categorySource` on `global.vendors[npcID]`; live `nameCache` / `itemCache` can rebuild. NPCDB also has `vendorCategories` / `vendorVisits` / `nameCache` |
| `OneWoW_CatalogData_Quests_DB` | `OneWoW_CatDB_QuestDBCurrent_DB` | **`completion`** (cross-alt). Archive has no completion tracker |
| `OneWoW_CatalogData_Tradeskills_DB` | `OneWoW_CatDB_TradeSkillDB_DB` | **`scanCache`** — not on TradeSkillDB today. Known-by already prefers AltTracker Professions |
| — | `OneWoW_CatDB_ItemDB_DB` | none player-critical |
| — | `OneWoW_CatDB_QuestDBArchive_DB` | none |
| Catalog / DevTool leftover toggle SV key | delete key | ignore leftover `false` |

---

## API recommendation

**Keep PackResolver. Hard-point to CatDB.** Do not delete the resolver and
scatter `OneWoW_CatDB_*_API` through QoL / Notes / ShoppingList. Those units
need role names plus `EnsureLoaded` / data-ready without a Catalog load.
After cutover `ResolveCatalogPack` always returns `pack.cat`. Optionally
later rename roles `journal` → `zones`, `vendors` → `npcs` (tabs / locales
`TAB_*`).

**Not a new funnel.** Callers already go through PackResolver. The problem
is the old-first branch and a few stubs / empty helpers — not a missing
shared API.

**Do not skip CatDB with helpers.** After cutover every consumer calls the
resolved CatDB `_API`. Item identity is ItemDB (`GetItem` / `GetItemName` /
`GetItemNameIndex`). Where / drops / stock / recipes stay ZoneDB / NPCDB /
QuestDB / TradeSkillDB.

### Old `_API` methods with no real CatDB equivalent

| Old method | CatDB today | Must add or drop |
|---|---|---|
| Journal `GetScaledLootLink` | always nil | implement live EJ or stop calling from `t-journal` |
| Journal `MergeLiveATTExtras` | always false | implement live overlay (fallback only) or stop calling |
| Journal `GetAchievementsForItem` | empty (0 shipped IDs) | emit `loot.achievementID` or live EJ join; old extras also 0 shipped |
| Vendors — all 21k people | `GetAllVendors` is vendor-role only; no `GetAllNPCs` / `GetNPCsByRole` | add if the Vendors tab becomes an NPCs tab; not required to delete old packs |
| Tradeskills `GetKnownRecipes` | `{}` | wire to AltTracker Professions or port `scanCache` onto TradeSkillDB_DB |
| Tradeskills `TradeskillScanner` / `scanCache` | not present | same decision as `GetKnownRecipes` |

Journal-shaped ZoneDB helpers (`GetSortedInstances`, `GetInstanceByMapID`,
`GetItemDropLocations`, `EnsureEncounters`, …) already exist so Catalog can
swap packs. Keep those names through cutover; rename later if tabs rename.

### Helpers that die after cutover

- Former CatDB-toggle APIs (removed)
- Settings + DevTool CatDB checkboxes and their locales (removed)
- `m-itemsearch` CatDB-only ItemDB branch (always require ItemDB for drops)
- PackResolver leftover-pack-first branch (keep `ADDON_TO_ROLE` one
  release if watchers still pass leftover folder names)
- Old pack `_API.lua` files (deleted with the addons)

**No new API for Trackers** (no Lua consumers). Map pins already go through
vendor / journal APIs + Notes.

---

## Part C — Ordered plan (100%, including deleting old addons)

Do **not** start this until Ricky says execute. Another agent may still be
in `t-journal.lua` / `tp-itemtracker.lua`.

### 1. Data gaps that block deleting old packs

**None that are unique usable shipped rows.**

Accept by design:

- Nameless rares (live tooltip)
- No Zone card per extras / quest map (407 places only; do not invent)
- Retired / skip_name itemIDs stay cited, not re-emitted into ItemDB
- 61 unnamed old quests stay dropped
- No Barber rows (neither pack)
- Fewer quest start/end tables (pins on NPCDB)

Optional before ship (not delete-blockers if you accept current CatDB UX):

- Achievement-on-loot emit or live EJ fill for `GetAchievementsForItem`
- Live EJ `GetScaledLootLink`
- Live ATT overlay decision (`MergeLiveATTExtras`)
- `GetKnownRecipes` → AltTracker (or port `scanCache`)

### 2. Code: remove the toggle

**Done.** Resolver always returns CatDB. Settings / DevTool checkboxes
and their locales are gone. Item Search drops always require ItemDB.

### 3. Wire remaining callers to CatDB only (by load unit)

**Catalog**

- Tabs already resolve roles. Change watchers to `"journal"` / `"quests"`
  (do not fight `t-journal.lua` if another agent is in it).
- Settings DB manager → ZoneDB / NPCDB / TradeSkillDB / QuestDB SVs.
- `VendorCategories.lua` comment / any SV path → NPCDB `vendorCategories`.
- Item Search: always require ItemDB for drops.

**Core**

- `AddonLoader` stores = six CatDB only.
- FirstRun STORE_* tables + ShoppingList datastore → TradeSkillDB.
- `t-charprofiles.lua` settings map → CatDB `_DB` names.
- Context menus already resolve `vendors`.

**QoL**

- Already PackResolver. After hard-point they hit CatDB.
- `professionspanel` needs `GetKnownRecipes` fixed or it shows empty alts.

**Notes**

- Collectibles + Find Location already `EnsureCatalogPack("vendors")`.

**ShoppingList**

- Lua already PackResolver. FirstRun datastore is the load-path hole.

**AltTracker**

- Cleanup / professions already PackResolver.
- `MigrationFix.lua` → CatDB SVs + one-shot copy of `completion` /
  `scanCache` / user vendor categories.
- Settings generate path → ZoneDB Generated (or workspace emit).

**Trackers**

- Docs only (`TRACKERS_IDEAS.md`). No Lua.

**DevTool**

- Remove CatDB checkbox. No leftover force-true.

### 4. TOC / OptionalDeps / zip / nightly / Curse / Discord

1. Delete folders: `OneWoW_CatalogData_Journal`, `_Vendors`, `_Quests`,
   `_Quests_Archive`, `_Tradeskills` (and their READMEs / Docs).
2. Nightly zip auto-discovers remaining `OneWoW_*` TOCs — no extra zip
   allow-list if discovery stays as-is.
3. Discord `addon-registry.json` — replace CatalogData five with CatDB six.
4. `.luarc.json` — drop old ignores / globals.
5. Suite `.pre-commit-config.yaml` — drop Quests/Tools excludes.
6. Journal `OptionalDeps: AllTheThings` — move to ZoneDB only if live ATT
   merge is kept.
7. Curse pack list = leftover TOC set after delete.

### 5. Wiki + all docs (list only — do not edit until he says ship)

Wiki dialect (`OneWoW-Wiki.mdc` / `onewow-wiki` skill):

- No leading `#` H1 (GitHub Wiki titles from the filename).
- Players, not APIs / file maps.
- Every content page ends **Related → Sources** with explicit
  `https://github.com/kellewic/OneWoW_Suite/blob/main/…` URLs.
- CHANGELOG owns release notes; wiki `Release-Notes.md` `## Current` is a
  mirror. What’s New reassessment is the changelog pipeline.
- Player names: **Zones / NPCs** vs Journal / Vendors when tabs rename.
  Until then, say the tab the player still sees.

**Wiki pages to update when shipping:**

- `wiki/Catalog.md` — companion packs, tab copy, Sources READMEs
- `wiki/FAQ.md` — `OneWoW_CatalogData_*`
- `wiki/Install.md` — Catalog data row
- `wiki/Developers.md` — data-store bullet
- `wiki/Shopping-List.md` — Tradeskills pack name
- `wiki/Notes.md` — “Catalog Journal, Vendors, and Quests” pin copy
- `wiki/Compare.md` — Journal vs ATT
- `wiki/Getting-Started.md` — companion `*Data*` folders
- `wiki/Home.md` — only if the feature table names CatalogData
- `wiki/Release-Notes.md` `## Current` + in-game What’s New **when he says
  ship** (changelog pipeline; do not lead with wiki)
- `_Sidebar.md` — only if new pages (unlikely)

Do **not** rewrite shipped archive `Release-Notes-R6.*` pages except a
Current index line at ship time.

**Suite READMEs / Docs:**

- Root `README.md` mermaid + table (still lists CatalogData)
- `OneWoW_Catalog/README.md` + this `CATDB.md` (flip “beside” language)
- Five CatalogData READMEs — delete with the packs
- Six CatDB `ARCHITECTURE.md` / `*_DATA.md` — drop “beside / not default”
- `OneWoW/Docs/ARCHITECTURE.md`, `README.md`, `COLLECTIBLES.md`, `ROADMAP.md`
- `OneWoW_Trackers/Docs/TRACKERS_IDEAS.md`
- `OneWoW_ShoppingList/README.md`
- Catalog `VendorCategories.lua` comment

**Websites (wow2 / onewow.net):** 11 locales `Install.md`, `FAQ.md`,
`Catalog.md`, `Shopping-List.md` still say `OneWoW_CatalogData_*`.

**Changelog / What’s New:** only when Ricky says ship. Player-felt: Catalog
now uses Zone / NPC / Item / Quest / TradeSkill databases; companion folder
names change; optional Journal→Zones / Vendors→NPCs tab rename.

### 6. Migration

1. One-shot: copy `OneWoW_CatalogData_Quests_DB.completion` →
   `OneWoW_CatDB_QuestDBCurrent_DB.completion` if the dest bucket is empty.
2. One-shot: `scanCache` → TradeSkillDB **only if** that pack grows a
   scanCache. Preferred: treat AltTracker Professions as the known-recipe
   store and implement `GetKnownRecipes` against it (no SV copy).
3. One-shot: user vendor categories from
   `OneWoW_CatalogData_Vendors_DB.global.vendors[npcID].category` where
   `categorySource == "user"` → NPCDB `vendorCategories`.
4. `MigrationFix.lua` consolidates character keys on the **new** SVs
   (and on old SVs for one release if both exist).
5. Ignore leftover CatDB-toggle SV keys on Catalog / DevTool SVs.
6. Live `nameCache` / `itemCache` rebuild; no copy required.

### 7. Test matrix (old packs **disabled** or missing)

Prove this **before** deleting folders. Old packs still on disk must not
be used.

- Catalog: Journal / Zones, Vendors / NPCs, Tradeskills, Quests (Current +
  Archive expansions), Item Search (drops / vendors / crafted / quests /
  owned / all)
- Item Where tooltip (QoL Item Tracker) — vendors, instances, quests, craft
- Instance toast + ESC instance panel (`GetInstanceByMapID`)
- Map / Save Pin from Journal, Vendors, Quests; Notes Find Location
- ShoppingList Craft + recipe picker (FirstRun BringUp must have loaded
  TradeSkillDB)
- Notes collectibles vendor hydrate
- AltTracker character purge + professions recipe commit
- Quest completion cross-alt (after migration)
- Context menu Open Vendor Details
- QoL professions panel alt known-recipes
- Scaled loot links / ATT extras if those APIs are kept
- DevTool: no CatDB checkbox; no force-true
- Manage Features / FirstRun: CatDB store rows only; ShoppingList pulls
  TradeSkillDB
- Character profiles settings capture uses CatDB `_DB` names

### 8. Rollback

**None once old addons are deleted.**

Must be true first:

1. Toggle gone; resolver CatDB-only.
2. FirstRun / manifest / watchers / settings / MigrationFix updated.
3. `completion` migrated; known-recipes path decided and working.
4. Stubs decided (implement or callers removed).
5. Zip / Discord / wiki / sites / READMEs updated **or** staged in the same
   ship.
6. In-game matrix passed with old packs **disabled**.

Keep old folders on disk until that matrix passes. Then delete. No dual-pack
rollback after delete.

---

## Can old addons be deleted yet?

**Folders are already gone** from Suite root and live AddOns (moved to
`--Removed Data Addon`). Do not recreate them.

| Blocker | Kind |
|---|---|
| Former CatDB toggle / leftover-pack-first resolver | **done** |
| FirstRun ShoppingList datastore / STORE_* | **done** |
| AddonLoader / leftoverStores / ADDON_TO_ROLE / charprofiles | **done** |
| Quest `completion` + user vendor categories one-shot SV copy | **done** (reads leftover WTF if CatDB TOC still declares those SV names) |
| Generate path / journal_db2_tools DEFAULT_OUT | **done** (ZoneDB `Data/Generated`) |
| Discord registry CatDB six | **done** |
| TradeSkillDB `GetKnownRecipes` is `{}`; `scanCache` not on CatDB | API (not a folder blocker; known-by already uses AltTracker Professions) |
| `GetScaledLootLink` / `MergeLiveATTExtras` stubs | API / UX (not a folder blocker) |
| Wiki, root README, Catalog README, onewow.net | ship copy (not a load blocker) |

Data backfill is not the blocker.
