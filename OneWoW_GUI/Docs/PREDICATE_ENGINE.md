# PredicateEngine

PredicateEngine is a shared expression engine published by the `OneWoW_GUI-1.0` library as `OneWoW_GUI.PredicateEngine`. It turns textual expressions such as `#epic & ilvl>=600` or `haste>=200` into compiled predicate functions over a rich per-item property table. Any OneWoW addon that has `OneWoW_GUI` as a dependency can use it.

Source: [`OneWoW_GUI/PredicateEngine.lua`](../PredicateEngine.lua).

For the user-facing expression syntax (the full keyword catalog, operator semantics, examples), see [`OneWoW_Bags/Docs/SEARCH_SYNTAX.md`](../../OneWoW_Bags/Docs/SEARCH_SYNTAX.md). This document is the **developer reference** for the API surface, caches, and extension points.

---

## Acquiring the engine

```lua
local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end
local PE = OneWoW_GUI.PredicateEngine
```

If `OneWoW_GUI` is a hard dependency of your addon (`## RequiredDeps: OneWoW_GUI`), the engine is guaranteed to be available by the time your file loads.

---

## Architecture

Two layers:

- **Layer 1 — `BuildProps`:** enriches an item (by `itemID`, and optionally a bag slot via `bagID/slotID`, plus an optional `itemInfo` hint) into a flat property table. It uses a two-tier cache: shared identity props first, then a per-slot overlay when slot context is supplied. Tooltip-derived, bind, and stat fields are resolved **lazily** through a metatable on first access.
- **Layer 2 — Tokenizer + Parser:** scans an expression string into a token array, then a recursive-descent parser produces a cached `function(props) -> bool`. Operators: `&` / `and`, `|` / `or`, `!` / `not`, parentheses. Comparisons: `==`, `!=`, `<`, `<=`, `>`, `>=`, and `~` (contains) / `~~` (Lua pattern). Numeric ranges: `min-max`. Shorthand numeric comparisons bind to `ilvl` when bare (e.g. `>600`, `200-300`); bare money tokens (`100g`, `10s-50s`) bind to `vendorprice`.

### Design decisions (from the module header)

- Structured tooltip bind detection via `Enum.TooltipDataItemBinding` (line type 20).
- Strict soulbound: character-only; account-bound does **not** match `#soulbound`.
- `~` is literal string-contains only. Negation uses `!` or `not`.
- `${CONSTANT}` curly-brace syntax for named constants and parameters (e.g. `quality==${EPIC}` resolves to `quality==4` before tokenizing).
- Lazy tooltip metatable for the few remaining tooltip-only fields. The same metatable also drives lazy bind resolution and lazy stat resolution (`C_Item.GetItemStats` on first access).

### Tokenizer notes

- String-property comparisons accept unquoted single-token values or quoted string literals for phrases containing spaces.
- Standalone quoted `~"…"` / `~'…'` is treated as shorthand for `name~…`.
- `~` remains literal contains; `~~` uses Lua pattern matching, and malformed patterns fail safely as non-matches.
- Bare numeric sugar: `>600` → `ilvl>600`, `200-300` → `ilvl:200-300`. Bare money sugar: `>100g` → `vendorprice>1000000`, `10s-50s` → `vendorprice:1000-5000`. Money parsing accepts combinations like `5g50s10c`.
- The WoW pipe escape `||` is consumed as a single OR token.
- `PE._STRICT_TOKENIZER` (false by default): when set truthy on the engine table, the tokenizer raises an error if it ever stalls on a character it cannot consume. Useful for catching grammar regressions in tests; leave off in production.

### Bind detection (source-aware)

`ResolveBind` consults `Enum.TooltipDataItemBinding` from a structured tooltip line. The mapping is **source-aware** so the same enum value carries different semantics depending on where the tooltip came from:

| Source | API | `BindOnPickup` interpretation |
|---|---|---|
| `"bag"` | `C_TooltipInfo.GetBagItem(bagID, slotID)` | The item is in the player's possession; `BindOnPickup` is observed only for tradeable BoP loot inside the trade timer, so it is treated as **currently bound** (`isSoulbound = true`). Preserves historical `#bop` / `#soulbound` matching. |
| `"link"` | `C_TooltipInfo.GetHyperlink(hyperlink)` | The item is being inspected out-of-container (vendor / loot / Great Vault). `BindOnPickup` is the **policy line** for unowned items; the player isn't bound to it yet, so `#bop` / `#soulbound` deliberately do **not** match. |

Other binding values (`BindOnEquip`, `BindOnUse`, `Soulbound`, account variants, `AccountUntilEquipped`) carry the same meaning in both modes.

**Asymmetry note:** in tooltip-only (link) mode, `#boe` / `#bou` / `#warbound` / `#wue` match because the policy-line state is well-defined; `#bop` / `#soulbound` do not, because we cannot infer current-bound state for an item the player does not own.

---

## Caches and invalidation

| Cache | Key | Contents | Cleared by |
|---|---|---|---|
| `propsCache` | `"bagID:slotID"` (slot context) or item-identity key (no slot) | Result of `BuildProps`: per-slot props or identity-only props | `InvalidatePropsCache`, `InvalidateCache`, matching entries in `InvalidateItemIDs` |
| `identityPropsCache` | item-identity key | Slot-independent base props shared by every slot holding the same item identity | `InvalidatePropsCache`, `InvalidateCache`, matching entries in `InvalidateItemIDs` |
| `tooltipCache` | `"bagID:slotID"` | Concatenated bag-tooltip left-text | `InvalidatePropsCache`, `InvalidateCache`, matching entries in `InvalidateItemIDs` |
| `tooltipTextLinkCache` | hyperlink | Concatenated hyperlink-tooltip left-text | `InvalidatePropsCache`, `InvalidateCache`, matching entries in `InvalidateItemIDs` |
| `tooltipDataCache` | `"bagID:slotID"` | Raw `TooltipData` from `C_TooltipInfo.GetBagItem` | `InvalidatePropsCache`, `InvalidateCache`, matching entries in `InvalidateItemIDs` |
| `tooltipDataLinkCache` | hyperlink | Raw `TooltipData` from `C_TooltipInfo.GetHyperlink` | `InvalidatePropsCache`, `InvalidateCache`, matching entries in `InvalidateItemIDs` |
| `compiledCache` | Expression string | Compiled `function(props) -> bool` | `InvalidateCache`, `RegisterKeyword`, `RegisterProperty` |
| `knownProfs` | (single set) | Lowercase profession-name set used by `#myprofs` | `InvalidateCache`, `InvalidateKnownProfessions` |

The slot/identity key strategy for `propsCache`:

- When `bagID`/`slotID` are present, the key is `"bagID:slotID"` so slot-state fields (durability, `isNew`, `isLocked`, current bind state, equipment-set membership, `isRefundable`, `isScrappable`, etc.) can vary per slot.
- Otherwise the key is an **identity key** (`itemID|hyperlink` for normal items; `itemID|species:level:quality:health:power:speed` for caged battle pets; `itemID|` fallback when no hyperlink is available) so independent calls for the same item share work.

`BuildProps` first populates or reuses `identityPropsCache`, then shallow-copies those base props into the final props table. Slot-only fields such as count, lock state, durability, equipment-set membership, refund/scrap state, quest slot fallback, and battle-pay state are applied on top. Lazy tooltip, bind, and stat fields are written to the final props table, not the shared identity base.

Use `PE:GetItemCacheKey` / `PE:GetItemIdentityKey` to compute these keys yourself.

### Invalidation methods

| Method | Effect |
|---|---|
| `PE:InvalidatePropsCache()` | Wipes props, identity-props, tooltip-text, and tooltip-data caches. Appropriate when item/slot state changed but the set of registered keywords/properties did not (e.g. `BAG_UPDATE_DELAYED`). |
| `PE:InvalidateCache()` | Wipes props, identity-props, tooltip-text, tooltip-data, and compiled caches, and clears `knownProfs`. Use when keyword set changed or for a full reset. |
| `PE:InvalidateItemIDs(idSet) -> evictedSlotKeys` | Surgically evicts cached props and tooltip data for item IDs in `idSet` and returns the evicted `"bagID:slotID"` keys. Used by item-info streaming paths to avoid wiping unrelated cache entries. |
| `PE:InvalidateKnownProfessions()` | Clears the cached "known professions" set used by `#myprofs`. Call on `SKILL_LINES_CHANGED`. |

`RegisterKeyword` and `RegisterProperty` automatically wipe `compiledCache` (so future evaluations recompile against the new grammar) but leave item and tooltip caches intact.

---

## Public API

All functions are method-style (`PE:Func(...)`). Exported constants use dot syntax (`PE.Field`).

### Item evaluation

| Function | Purpose |
|---|---|
| `PE:BuildProps(itemID, bagID?, slotID?, itemInfo?) -> props` | Build (and cache) the enriched property table for an item. When `bagID`/`slotID` are supplied, slot-specific fields (`isNew`, `isLocked`, `count`, `isInEquipmentSet`, durability, `isRefundable`, `isScrappable`, `isBattlePayItem`, quest slot info, etc.) become available. `itemInfo` may be a hyperlink string, a container-info-shaped table with `.hyperlink`, or `nil`. Bag/slot-derived hyperlinks take precedence over `itemInfo`. Returns `{}` when no usable identity can be resolved. |
| `PE:CheckItem(expr, itemID, bagID?, slotID?, itemInfo?) -> bool` | Compile the expression (cached) and evaluate it against `BuildProps`. Returns `false` for empty `expr`, missing `itemID`, or compile failure. |
| `PE:Compile(expr) -> compiled, errorMessage?` | Compile an expression to a cached predicate function. Returns `nil` on empty input; returns `nil, errorMessage` on tokenize/parse failure (otherwise the second return is `nil`). Single-keyword and `! #keyword` expressions take a fast path that bypasses tokenization. |
| `PE:SafeEvaluate(compiled, props) -> result, errorMessage?` | Evaluate a compiled predicate inside `pcall`. Returns `false, errorMessage` on error (otherwise the second return is `nil`). |
| `PE:ResolveParams(expr, params?) -> expr'` | Substitute `${NAME}` placeholders in `expr`. The `params` table (`{ NAME = { value = ..., default = ... } }`) is consulted first, then the built-in `CONSTANT_MAP` (item-quality and expansion constants such as `EPIC`, `LEGENDARY`, `WARWITHIN`, `MIDNIGHT`). Pass `nil` to skip the params pass and resolve constants only. |

### Registries

| Function | Purpose |
|---|---|
| `PE:RegisterKeyword(nameOrNames, func)` | Register a `#keyword` (or a list of aliases — first name is canonical). `func(props)` returns truthy to match. Wipes `compiledCache`. Re-registering the same predicate function under a new name keeps the existing canonical entry. |
| `PE:RegisterProperty(nameOrNames, def)` | Register a numeric or string property for comparison syntax (e.g. `haste>=200`). `def = { field = "fieldName", type = "number"\|"string", unit = "money"? }`. `unit = "money"` enables money parsing (`100g`, `5s50c`) on the RHS for number-typed properties. Wipes `compiledCache`. |
| `PE:GetAllKeywords() -> { canonical, aliases[] }[]` | Every registered keyword in registration order. `aliases` excludes the canonical name and is alphabetically sorted. Intended for help/reference UIs. |
| `PE:GetMatchingKeywords(itemID, bagID?, slotID?, itemInfo?) -> string[]` | Return canonical names of every registered keyword that matches this item, in registration order. With only hyperlink context, policy bind keywords such as `#boe`, `#bou`, `#warbound`, and `#wue` can still match via tooltip fallback, while current-bound state (`#bop` / `#soulbound` / `#bound`) cannot be inferred. Current slot-state keywords such as `#new`, `#locked`, `#tradeableloot`, durability, equipment-set membership, count, refund/scrap state, and battle-pay state require `bagID`/`slotID`. |

### Item helpers

| Function | Purpose |
|---|---|
| `PE:GetItemCacheKey(itemID, bagID?, slotID?, hyperlink?) -> key` | Stable cache key keyed on item identity + slot context (`"bagID:slotID"` when both slot coordinates are present, otherwise identity key). |
| `PE:GetItemIdentityKey(itemID, hyperlink?) -> key` | Identity key for grouping/stacking (ignores slot). Uses `itemID|hyperlink` for normal items, `itemID|species:level:quality:health:power:speed` for caged battle pets, and `itemID|` as the fallback when no hyperlink is provided. |
| `PE:ParseItemLink(link) -> table\|nil` | Parse a full hyperlink or bare `item:...` string into a structured table (`itemID`, `enchantID`, `gems[]`, `suffixID`, `bonusIDs[]`, `modifiers`, `relicBonusIDs[1..3]`, `crafterGUID`, `extraEnchantID`, `quality`, `name`, etc.). Returns `nil` for inputs that do not match the item-link grammar. |
| `PE:GetBattlePetData(itemID, hyperlink) -> table\|nil` | Extract battle-pet fields (`speciesID`, `petName`, `petLevel`, `petQuality`, `petMaxHealth`, `petPower`, `petSpeed`, `petType`, `isWild`, `canBattle`, `isTradeable`, `isUnique`, `numCollected`, `limit`). Returns `nil` for items with no associated species. |
| `PE:GetTooltipText(bagID, slotID) -> string` | Concatenated bag-tooltip left-text for the slot, cached when non-empty. Returns `""` when bag/slot are missing or no tooltip data is available. |
| `PE:CanClassEquip(itemID?, hyperlink?, class?) -> bool` | Whether an item can be equipped by the given class. Pass a class token (`"WARRIOR"`, `"PALADIN"`, ...) to check an alt; pass `nil` to check the current player. Hyperlink is preferred over itemID because it carries modified-itemID context for reworked/tokenized gear. Treats universal gear (empty spec list) as usable; correctly rejects class-locked drops. |

### Exported constants

- `PE.BATTLE_PET_CAGE_ID` — item ID of the battle pet cage item (`82800`).
- `PE.BattlePetTypes` — map of pet family name to numeric family ID (`Humanoid = 1`, `Dragonkin = 2`, …).
- `PE.ClassID` — map of class token (`"WARRIOR"`, `"PALADIN"`, …) to numeric `classID` used by `C_Item.DoesItemContainSpec`. Useful for alt eligibility checks where the input is a stored class string.
- `PE.ParseMoney(str) -> copper\|nil` — parser that converts `"100g"`, `"5s50c"`, `"5g50s10c"`, etc. into copper. Returns `nil` for inputs without unit suffixes.

---

## Lazy field resolution

`BuildProps` returns a table with a permanent metatable that lazily populates three groups of fields on first read. This avoids paying for tooltip parsing, tooltip-data fetches, or `C_Item.GetItemStats` for items whose predicate never reads those fields.

| Group | Fields | Resolver | Marker flag |
|---|---|---|---|
| Tooltip | `tooltipText`, `hasCharges`, `hasUseAbility`, `hasEquipAbility`, `isAlreadyKnown`, `isTradeableLoot`, `isUnique`, `isUniqueEquipped` | `ResolveTooltipFields` | `_tooltipResolved` on success; `_tooltipDataMissing` on failure |
| Bind | `currentbind`, `isSoulbound`, `isBOE`, `isBOA`, `isBOU`, `isWUE`, `isWarbound` | `ResolveBind` (source-aware; see Architecture) | `_bindResolved` |
| Stats | `statIntellect`, `statAgility`, `statStrength`, `statStamina`, `statCrit`, `statHaste`, `statMastery`, `statVersatility`, `statSpeed`, `statLeech`, `statAvoidance`, `statArmor`, plus all `socket*` counters (`socketPrismatic`, `socketMeta`, color sockets, `socketCogwheel`, `socketHydraulic`, `socketDomination`, `socketCypher`, `socketTinker`, `socketPrimordial`, `socketFragrance`, `socketFiber`, punchcard sockets, and singing sockets) | `ResolveStats` (`C_Item.GetItemStats`) | `_statsResolved` |

Each group resolves all of its fields on the first read of any field in that group. The marker flag is set on the props table so subsequent reads skip the resolver. Tooltip resolution is the exception when no tooltip data is available: it writes safe false/empty defaults, sets `_tooltipDataMissing`, and leaves `_tooltipResolved` unset so later reads can retry after item data streams in. The metatable is left attached for the lifetime of the cached props entry.

`_bagID` / `_slotID` are stored on the props table so resolvers that need slot context (tooltip scan, bag-mode bind resolution) can recover it. Tooltip and bind resolvers prefer bag-tooltip data when slot context is available, then fall back to hyperlink-tooltip data when a caller only supplied an item identity.

---

## Optional cross-addon hooks

`BuildProps` and a few keywords consult optional globals when resolving item properties. Each check is guarded at **call time**, so any of these addons may be absent without errors.

| Hook | Used by | Effect if missing |
|---|---|---|
| `_G.OneWoW.ItemStatus:IsItemJunk(itemID)` | `props.isJunk` (in addition to `quality == Poor`) | `isJunk` reflects only the quality check. |
| `_G.TransmogUpgradeMaster_API.IsAppearanceMissing(hyperlink)` | `props.isCatalyst`, `props.isCatalystUpgrade` (and the `#catalyst` / `#catalystupgrade` keywords that read them) | Both fields stay `false`; the keywords therefore never match. |
| `_G.OneWoW_RecipeKnownUtil:IsRecipeKnown(itemID, hyperlink)` | `props.isAlreadyKnown` for recipe items, when the tooltip's `ITEM_SPELL_KNOWN` line is absent | Falls back to tooltip-text detection only. |

### Keywords registered by external modules

Some keywords are registered at runtime by other addons via `PE:RegisterKeyword`, so PE has no hardcoded dependency on them:

| Keyword | Registered by | Effect if module missing |
|---|---|---|
| `#upgrade` | `OneWoW.UpgradeDetection:Initialize()` → calls `OneWoW.UpgradeDetection:CheckItemUpgrade(hyperlink, itemLocation?)` | Keyword is unregistered; predicates using it evaluate to `false`. |

---

## Extending the engine

### Adding a keyword

```lua
PE:RegisterKeyword({ "mykeyword", "mykw" }, function(props)
    if not props.hyperlink then return false end
    return MyAddon:SomeCheck(props.hyperlink)
end)
```

- Keyword callbacks are invoked with only `props`. If the callback needs slot context, read `props._bagID` / `props._slotID` (set when `BuildProps` was called with slot context).
- Avoid load-time gating on third-party globals. Always register the keyword, and check for the optional dependency **inside** the callback so load-order variability across `OptionalDeps` does not silently drop the keyword.
- The first name in the list is treated as canonical for `GetAllKeywords` and `GetMatchingKeywords`.

### Adding a property

```lua
PE:RegisterProperty("mystat", { field = "myStat", type = "number" })
PE:RegisterProperty("mygold", { field = "myGold", type = "number", unit = "money" })
PE:RegisterProperty("myname", { field = "myName", type = "string" })
```

Then `mystat>=200`, `mygold>100g`, `myname~foo` become valid expression tokens. The engine reads `props.<field>` at evaluation time; your addon is responsible for populating that field — typically by attaching values via a wrapper that calls `BuildProps` and then layers extra fields, or by populating fields in a custom keyword's resolver path.

String-typed properties support `=` / `==` (exact, case-insensitive), `!=`, `~` (literal contains), and `~~` (Lua pattern; malformed patterns return false). Numeric properties support `==`, `!=`, `<`, `<=`, `>`, `>=`, and the `prop:low-high` range form. With `unit = "money"`, numeric RHS values may also be money strings (`100g`, `5s50c`, `200g50s`).

---

## Performance notes

- Compiled predicate functions are cached. Recompile cost is only paid on the first evaluation of a new expression or after an invalidation.
- `BuildProps` is cached per slot-or-identity key and reused across `CheckItem`, `GetMatchingKeywords`, and direct-read call sites. Call `InvalidatePropsCache` when slot contents change.
- The lazy-resolution metatable means a predicate that never references stat / bind / tooltip fields never pays for `C_Item.GetItemStats`, `C_TooltipInfo.GetBagItem`, or tooltip text concatenation.
- Registering a new keyword or property wipes `compiledCache` (future evaluations recompile). Props and tooltip caches are untouched.
- `GetMatchingKeywords` and `GetAllKeywords` iterate every registered keyword. Use them for tooltip/diagnostic paths and help UIs, not for hot filter loops — use `CheckItem` with a targeted expression there.
