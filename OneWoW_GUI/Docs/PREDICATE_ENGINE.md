# PredicateEngine

PredicateEngine is a shared expression engine published by the `OneWoW_GUI-1.0` library as `OneWoW_GUI.PredicateEngine`. It turns textual expressions such as `#epic & ilvl>=600` or `haste>=200` into compiled predicate functions over a rich per-item property table. Any OneWoW addon that has `OneWoW_GUI` as a dependency can use it.

Source: [`OneWoW_GUI/PredicateEngine.lua`](../PredicateEngine.lua).

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

- **Layer 1 — `BuildProps`:** enriches an item (by `itemID`, and optionally a bag slot via `bagID/slotID`, plus an optional `itemInfo`/`containerInfo` table) into a flat property table. Tooltip-derived, bind, and stat fields are resolved lazily through a metatable on first access.
- **Layer 2 — Compiler:** tokenizes and parses the expression into a cached `function(props) -> bool`. Operators: `&` / `and`, `|` / `or`, `!` / `not`, parentheses. Comparisons: `==`, `!=`, `<`, `<=`, `>`, `>=`, and `~` (contains) / `~~` (Lua pattern). Numeric ranges: `min-max`. Shorthand numeric comparisons bind to `ilvl` when bare (e.g. `>600`, `200-300`).

### Design decisions (from the module header)

- Structured tooltip bind detection via `TooltipDataItemBinding`.
- Strict soulbound: character-only; account-bound does **not** match `#soulbound`.
- `~` is literal string-contains only. Negation uses `!` or `not`.
- `${CONSTANT}` curly-brace syntax for named constants and parameters (e.g. `quality==${EPIC}` resolves to `quality==4` before tokenizing).
- Lazy tooltip metatable for the few remaining tooltip-only fields.

### Tokenizer notes

- String-property comparisons accept unquoted single-token values or quoted string literals for phrases containing spaces.
- Standalone quoted `~"…"` / `~'…'` is treated as shorthand for `name~…`.
- `~` remains literal contains; `~~` uses Lua pattern matching, and malformed patterns fail safely as non-matches.

---

## Caches and invalidation

| Cache | Key | Contents | Cleared by |
|---|---|---|---|
| `propsCache` | `"bagID:slotID"` | Result of `BuildProps` for that slot | `InvalidatePropsCache`, `InvalidateCache` |
| `tooltipCache` | `"bagID:slotID"` | Concatenated tooltip left-text | `InvalidatePropsCache`, `InvalidateCache` |
| `compiledCache` | Expression string | Compiled `function(props) -> bool` | `InvalidateCache`, `RegisterKeyword`, `RegisterProperty` |

- `PE:InvalidatePropsCache()` — wipes props + tooltip caches only. Appropriate when slot contents changed but the set of registered keywords/properties did not (e.g. `BAG_UPDATE_DELAYED`).
- `PE:InvalidateCache()` — wipes all three caches. Appropriate when keyword set changed or when full reset is desired.
- `PE:InvalidateKnownProfessions()` — clears the cached "known professions" set used by `#myprofs`. Call on `SKILL_LINES_CHANGED`.

---

## Public API

All functions are method-style (`PE:Func(...)`). Exported constants use dot syntax (`PE.Field`).

### Item evaluation

| Function | Purpose |
|---|---|
| `PE:BuildProps(itemID, bagID?, slotID?, itemInfo?) -> props` | Build (and cache) the enriched property table for an item. When `bagID`/`slotID` are supplied, slot-specific fields (`isNew`, `isLocked`, tooltip-bound fields, quest slot info, etc.) become available. `itemInfo` may carry `hyperlink`, `quality`, `count`, etc. as hints. |
| `PE:CheckItem(expr, itemID, bagID?, slotID?, itemInfo?) -> bool` | Compile the expression (cached) and evaluate it against `BuildProps`. |
| `PE:Compile(expr) -> compiled` | Compile an expression to a cached predicate function. Returns a function usable with `SafeEvaluate`. |
| `PE:SafeEvaluate(compiled, props) -> bool` | Evaluate a compiled predicate inside `pcall`; returns `false` on error. |
| `PE:ResolveParams(expr, params) -> expr'` | Substitute `${NAME}` placeholders in `expr` using the given `params` table (or the built-in constant map for `EPIC`, `LEGENDARY`, expansion IDs, etc.). |

### Registries

| Function | Purpose |
|---|---|
| `PE:RegisterKeyword(nameOrNames, func)` | Register a `#keyword` (or a list of aliases). `func(props)` returns truthy to match. Wipes `compiledCache`. |
| `PE:RegisterProperty(nameOrNames, def)` | Register a numeric or string property for comparison syntax (e.g. `haste>=200`). `def = { field = "fieldName", type = "number"\|"string" }`. Wipes `compiledCache`. |
| `PE:GetMatchingKeywords(itemID, bagID?, slotID?, itemInfo?) -> string[]` | Return canonical names of every registered keyword that matches this item, in registration order. Slot-specific keywords (`#recent`, `#new`, `#locked`, bind-state keywords) only match when `bagID`/`slotID` are supplied. |

### Item helpers

| Function | Purpose |
|---|---|
| `PE:GetItemCacheKey(itemID, bagID?, slotID?, hyperlink?) -> key` | Stable cache key for classification/caching keyed on item identity + slot context. |
| `PE:GetItemIdentityKey(itemID, hyperlink?) -> key` | Identity key for grouping/stacking (ignores slot). |
| `PE:ParseItemLink(link) -> parts...` | Parse an item link into its numeric components. |
| `PE:GetBattlePetData(itemID, hyperlink) -> table` | Extract battle-pet fields (species ID, pet name, level, quality, breed, etc.). |
| `PE:GetTooltipText(bagID, slotID) -> string` | Concatenated tooltip left-text for the slot, cached. |
| `PE:GetExpansionID(itemID, hyperlink?) -> number` | Expansion ID for an item. |
| `PE:GetExpansionName(expID) -> string` | Localized expansion name for an ID (convenience wrapper over `_G["EXPANSION_NAME" .. expID]`). |

### Exported constants

- `PE.BATTLE_PET_CAGE_ID` — item ID of the battle pet cage item (`82800`).
- `PE.BattlePetTypes` — map of pet family name to numeric family ID.
- `PE.ParseMoney` — parser that converts `"100g"`, `"5s50c"`, etc. into copper.

---

## Optional cross-addon hooks

Inside `BuildProps`, the engine consults a few optional globals when resolving item properties. Each check is guarded at **call time**, so any of these addons may be absent without errors.

| Hook | Used by | Effect if missing |
|---|---|---|
| `_G.OneWoW.ItemStatus:IsItemJunk(itemID)` | `props.isJunk` (in addition to `quality == Poor`) | `isJunk` reflects only the quality check. |
| `_G.TransmogUpgradeMaster_API.IsAppearanceMissing(hyperlink)` | `#catalyst`, `#catalystupgrade` keywords | The keywords register as no-ops (always `false`). |

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

### Adding a property

```lua
PE:RegisterProperty("mystat", { field = "myStat", type = "number" })
```

Then `mystat>=200` becomes a valid expression token. The engine reads `props.myStat` at evaluation time; your addon is responsible for populating that field (typically by attaching values to `itemInfo` before calling `BuildProps`, or by adding a computed field via its own wrapper on top of `BuildProps`).

---

## Performance notes

- Compiled predicate functions are cached. Recompile cost is only paid on the first evaluation of a new expression or after an invalidation.
- `BuildProps` is cached per `"bagID:slotID"` and reused across `CheckItem`, `GetMatchingKeywords`, and direct-read call sites. Call `InvalidatePropsCache` when slot contents change.
- Registering a new keyword or property wipes `compiledCache` (future evaluations recompile). Props and tooltip caches are untouched.
- `GetMatchingKeywords` iterates every registered keyword. Use it for tooltip/diagnostic paths, not for hot filter loops — use `CheckItem` with a targeted expression there.
