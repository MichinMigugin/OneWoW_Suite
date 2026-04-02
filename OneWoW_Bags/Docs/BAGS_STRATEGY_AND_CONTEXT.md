# OneWoW_Bags — Strategy, Comparisons & Context

Living document for maintainers and LLM sessions. Update as the addon’s direction is decided.

---

## Purpose of this file

- Capture **competitive analysis** (Baganator, ArkInventory, Vendor reference) vs OneWoW_Bags.
- Record **suite split of responsibilities** (AltTracker, Storage, DirectDeposit, Catalog) so Bags does not duplicate them.
- Note **future suite plans** (Ledger, Postal, Vendor, shared matching) and **integration principles**.
- Provide **initial context** when starting new discovery or implementation work.

---

## OneWoW_Bags — Current state (summary)

- **Role:** Suite-native bag/bank/guild bank UI on **OneWoW_GUI**: list / category / bag views, bars, settings, locales, themes.
- **Categorization:** Built-in categories in `Data/Categories.lua` (priorities + optional `search` strings); custom categories (`customCategoriesV2`); drag/drop and item ID assignment patterns in DB.
- **Matching / search:** `Data/SearchEngine.lua` — boolean expressions (`&` `|` `!` `~`), `#keywords`, name fragments, ilvl compares/ranges; many predicates in `CheckKeyword` (toys, pets, mounts, tooltip-derived bind info, etc.). **Bar vs categories:** documented in **Categorization & search syntax** (later in this file).
- **Integrations:** TSM; documented **item button callback API** (`Integrations/OneWoWBagsIntegration.lua`, `API/`); **OneWoW** hub (e.g. `UpgradeDetection`, overlay engine, minimap).
- **Not in scope today:** User-authored **Lua rule scripts** with sell/keep/destroy **precedence** like Vendor; **Syndicator-style** library as a separate published API; **full transfer automation** (mail/trade/sort) like Baganator Transfers.

---

## Comparison: Baganator (+ Syndicator)

**What Baganator does well**

- **Syndicator:** Cross-character inventory, shared **search keywords**, alt-wide context for tooltips and search.
- **Plugins:** Junk plugins, upgrade plugins (e.g. Pawn) as first-class policy hooks.
- **Transfers:** Mail, trade, vendor, guild, bag-to-bag, sorting — **logistics hub** beyond display.
- **Presentation:** Skins (ElvUI, NDui, …), customise dialog for categories (import/export, sections), **search help** UI documenting operators and keywords.

**What OneWoW_Bags does better (for the suite)**

- **OneWoW suite integration:** Themes, hub registration, upgrade hooks, overlay callbacks — one coherent product.
- **Documented overlay API** for third-party / internal addons (`API/`, `RegisterItemButtonCallback`).
- **Search engine** in-repo is substantial (boolean logic, ilvl, rich keywords) without Ark-level blueprint complexity.

**Takeaways for Bags**

- Prefer **API hooks** (junk/upgrade-style) over inlining every policy.
- Consider **in-client help** for search syntax (Baganator-style discoverability).
- **Do not** rebuild Syndicator inside Bags; use suite **Storage + ItemIndex** (see below).

---

## Categorization & search syntax (OneWoW_Bags vs Baganator)

### OneWoW_Bags — same `SearchEngine` when expressions run

- **Built-in categories:** Each `CATEGORY_DEFINITIONS` entry with a `search` string uses `SearchEngine:CheckItem(def.search, …)` after enrichment (`Data/Categories.lua`).
- **Custom categories:** `searchExpression` (search / hybrid mode) uses the same `CheckItem` path; **type/subclass** mode uses `C_Item` class info, not search syntax.
- **Precedence before keyword buckets:** Junk, upgrades, explicit custom lists, `categoryModifications.addedItems`, **Recent Items** can win before the ordered `SEARCH_CATEGORIES` loop. Optional **inventory slot** sub-labels post-process Weapons/Armor.
- **Info bar / main bags / bank:** User text is passed to `CheckItem` **only if** the string contains `#` or any of `& | ! ~ ( )` (`GUI/MainWindow.lua`, `GUI/BankWindow.lua`). Otherwise the UI uses **plain substring match on item name** and **does not** call `SearchEngine:Compile` / `CheckItem`.
- **Expansion filter:** Applied after search, via enriched `_expansionID`, not as part of the search string.

**Implication:** Category rules and the bar use **one language** (`SearchEngine`) when the bar is in “expression” mode; **casual bar typing** without `#`/operators is **name-only** and can behave differently from a category rule like `#potion`.

### Baganator (+ Syndicator) — always through `CheckItem`

- **Bag** item buttons call `Syndicator.Search.CheckItem(self.BGR, text)` for every non-empty search (`Baganator/ItemViewCommon/ItemButton.lua` → `SearchCheck`).
- **Syndicator** `ProcessTerms`: if the string has no `~ & | ( ) !`, it uses **`ApplyKeyword(text)`** only; otherwise it tokenizes and applies boolean composition (`Syndicator/Search/CheckItem.lua`).
- **`ApplyKeyword`:** Resolves registered **keywords** / **patterns** when possible; if nothing matches the registry, it falls back to **`MatchesText`** (substring on loaded item name, same practical effect as OneWoW’s name-only bar path).
- **Categories:** Stored `search` strings live in the same keyword / operator world as the bag search box (import/export in customise dialog).

**Comparison table**

| | OneWoW_Bags | Baganator / Syndicator |
|--|-------------|-------------------------|
| Bar search entry | **Two paths:** expression → `CheckItem`; else name substring only | **Single path:** always `CheckItem` |
| Plain text `"foo"` | Bypasses `SearchEngine` | `CheckItem` → `ApplyKeyword` → often `MatchesText` |
| Built-in / custom category rules | `CheckItem` on `search` / `searchExpression` | Same Syndicator stack as bar |
| `#keywords` / operators | `SearchEngine` tokenizer | Syndicator `ProcessTerms` / keywords |

**Possible product direction:** Route **all** bar text through `SearchEngine:CheckItem` (like Syndicator) so plain text and categories stay aligned; or document the dual behavior clearly in UI help.

---

## Comparison: ArkInventory

**What Ark does well**

- **Depth:** Category sets, layouts, designs, blueprints, PeriodicTable-class data.
- **Rules:** Loadable **ArkInventoryRules** — `AppliesToItem` with caching; **manual assignment** can override rules (`ItemCategoryGetPrimary` flow).
- **Exemptions:** Damaged/disabled rules, validation concepts.

**Tradeoff**

- Very high **configuration and maintenance** surface; steep onboarding.

**Takeaways for Bags**

- Borrow **precedence ideas** (manual assignment wins over auto bucket) where it matches product goals.
- **Rule damage / validation:** if script-like rules are added later, validate on edit and disable broken rules safely.

---

## Comparison: Vendor (reference addon)

**Architecture (useful for future OneWoW_Vendor + shared logic)**

- **ItemProperties:** Normalize items to a stable struct (GUID, link, location, tooltip data, counts).
- **RuleManager + ordered rule types:** Locked keep/sell/destroy lists vs keep vs destroy vs sell — **clear precedence**.
- **Rules.SystemRules:** Named definitions with `Script`, `Params`, `ScriptText`, `Locked`, per-flavor `Supported`.
- **RuleSystem:RegisterFunctions:** Extensible functions + documentation for the script environment.
- **Evaluation:** Maps outcomes to actions; **GUID caching** where appropriate.

**Shared “matching engine” idea (Bags + Vendor)**

- **Core:** One enriched **item property** layer used everywhere.
- **Bags:** Search expressions / categories compile to predicates (current direction).
- **Vendor:** Ordered rules with actions + lists.
- **Shared primitives:** Same fields for quality, bind, etc., so `#soulbound` and Vendor rules do not disagree.

**Avoid:** Forcing every user to write Lua for categories; keep **search-like** defaults.

---

## Suite: AltTracker, Storage, DirectDeposit (why not in Bags)

**Design:** Bags = **live** bag/bank/guild **UI**. Account-wide snapshots and **bank deposit automation** live elsewhere.

### OneWoW_AltTracker_Storage

- **SavedVariables:** `OneWoW_AltTracker_Storage_DB` — per-character bags, personal bank, mail; **warband** and **guild** banks; settings.
- **DataManager:** Collects on bag/bank/guild/mail events (`Modules/DataManager.lua`).
- **`_G.StorageAPI`:** `GetBags`, `GetPersonalBank`, `GetWarbandBank`, `GetWarbandBankGold`, `GetGuildBank`, `GetGuildBankGold`, `GetMail` (`Core/API.lua`).
- **ItemIndex:** Rebuilds **itemID → locations + totalCount** across storage, equipment, auctions (`Modules/ItemIndex.lua`); `GetTooltipData(itemID)` for aggregate display.

**Parity with Syndicator:** Same *job* — “where is this item account-wide?” — implemented as **suite snapshots**, not the Syndicator library. Bags should **optional-hook** Storage/ItemIndex for tooltips or search modes, not reimplement storage.

### OneWoW_AltTracker (UI)

- **Items tab:** Aggregates from `OneWoW_AltTracker_Storage_DB` (and auctions DB) — unique items, totals, vendor/AH value, filters.
- **Bank tab:** Per-character browse: personal / warband / guild / bags with search.

**ShoppingList** already uses `_G.OneWoW_AltTracker_Storage` in `DataAccess.lua` for alt quantities.

### OneWoW_DirectDeposit

- On bank open: optional **warband gold** normalize; **deposit configured itemIDs** to personal/warband/guild (`Modules/DirectDeposit.lua`).
- **Not** Baganator’s full transfers (mail, trade, restack, sort).

### OneWoW_Bags (existing hooks)

- `GUI/BagsBar.lua`: **`OneWoW_AltTracker_Character_API`** + **`StorageAPI.GetWarbandBankGold`** for gold tooltip; locales mention installing AltTracker for alt gold details.

**Principle:** Extend **Character_API / StorageAPI / ItemIndex** patterns for optional enrichment; do **not** duplicate AltTracker Items UI or DirectDeposit loops inside Bags.

---

## Suite: Catalog & CatalogData (optional enrichment)

**OneWoW_Bags** does not currently reference Catalog in Lua; integration remains **optional**.

| Module | Use for Bags (if integrated) |
|--------|------------------------------|
| **Catalog `ItemSearch`** (`Modules/m-itemsearch.lua`) | Already merges **Storage + auctions** with journal/vendor/crafted search; model for “meta” search, not a second full UI inside Bags. |
| **CatalogData_Journal** | `OneWoWItems_<Expansion>` — names, icons, quality, **drop locations**; hub/tooltips may already consume; Bags inherits tooltips on items. |
| **CatalogData_Tradeskills** | Recipe/reagent graphs; **ShoppingList** uses `OneWoW_CatalogData_Tradeskills` / `recipeIndex`. Enables predicates like “crafting reagent” / profession filters without duplicating data. |
| **CatalogData_Vendors** | Vendor/seller metadata; synergy with future **OneWoW_Vendor** (rules + “sold by”). |
| **CatalogData_Quests** | Completion tracking; lower priority for Bags unless quest-aware rules are required. |
| **`OneWoW_Catalog_TradeskillAPI`** | `RegisterRecipeCallback` — links recipe UI to extensions; relevant if Bags deep-links to Catalog recipes. |

**Principle:** Optional **predicates, tooltips, badges** via globals; prefer a future thin **facade** in OneWoW if direct `CatalogData_*` sprawl becomes noisy. Do not fork **Catalog’s item search UI** inside Bags.

---

## Planned / mentioned suite work (for alignment)

- **OneWoW_Ledger** — evolution of AltTracker financials (broader than Bags).
- **OneWoW_Postal** — mail addon (Bags should not own mail moves).
- **OneWoW_Vendor** — QoL vendor extracted + Vendor-addon-style rules; **shared item properties / rule precedence** with Bags categorization where sensible.
- **Optional:** Central **item knowledge** API (properties + CatalogData accessors) consumed by Bags, Vendor, ShoppingList.

---

## Gaps and risks (watch list)

- **Tooltip scanning** in `SearchEngine` for bindings: prefer **`C_TooltipInfo`** where possible for consistency, performance, and secret-value behavior.
- **TOC / Libs:** Ensure embedded `Libs` and TOC stay in sync (avoid broken loads).
- **Combat/secure:** Any future mass-move features need the same constraints as Baganator-style transfers; keep them in **Postal / DirectDeposit / Vendor**, not scattered in Bags.

---

## What to build in Bags vs connect

| Build in Bags | Connect via API / other addons |
|----------------|--------------------------------|
| Bag/bank/guild **UI**, views, themes | Account-wide inventory **Storage + ItemIndex** |
| **SearchEngine**, categories, custom groups | **Syndicator** — not required; suite replaces with Storage |
| **Item button overlays** (documented callbacks) | **UpgradeDetection**, TSM, future Vendor |
| Local **sort/display** options | **DirectDeposit** bank automation; **Postal** mail |
| Optional **alt gold** line (current) | **Character_API**, **StorageAPI** |

---

## Reference locations (codebase)

- Bags: `OneWoW_Bags/Data/Categories.lua`, `Data/SearchEngine.lua`, `GUI/MainWindow.lua`, `GUI/BankWindow.lua`, `Core/Database.lua`, `Integrations/`, `API/`.
- Storage: `OneWoW_AltTracker_Storage/Core/API.lua`, `Modules/ItemIndex.lua`, `Modules/DataManager.lua`.
- Catalog item search: `OneWoW_Catalog/Modules/m-itemsearch.lua`.
- ShoppingList + CatalogData: `OneWoW_ShoppingList/Modules/DataAccess.lua`.

---

## Changelog (manual)

| Date | Notes |
|------|--------|
| 2026-03-31 | Initial compile from competitive analysis, suite split, Catalog notes, and roadmap threads. |
| 2026-03-31 | Categorization vs bar search: shared `SearchEngine` vs name-only shortcut; Baganator always uses `Syndicator.Search.CheckItem` with `MatchesText` fallback. |
