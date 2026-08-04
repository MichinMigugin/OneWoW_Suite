# TooltipScanner (`OneWoW.TooltipScanner`)

> **See also:** [ARCHITECTURE.md](ARCHITECTURE.md) §6 (core service roster),
> [PREDICATE_ENGINE.md](PREDICATE_ENGINE.md) (lazy tooltip fields / keywords),
> `.cursor/skills/wow-tooltip-system/SKILL.md` (Blizzard tooltip API patterns).

Central owner of `C_TooltipInfo` routing, tooltip-data caches, and structured line
extraction. **PredicateEngine**, **RecipeKnownUtil**, and **Merchant** delegate
here instead of calling `C_TooltipInfo` directly.

**File:** [`OneWoW/Services/TooltipScanner.lua`](../Services/TooltipScanner.lua),
published as `OneWoW.TooltipScanner` via the Facade.

**Load order:** before `PredicateEngine.lua` (`OneWoW.toc` — PE captures
`ns.TooltipScanner` at file scope).

## Context routing

| Kind | API | Cached |
| --- | --- | --- |
| Bag slot | `GetBagItemData(bagID, slotID)` | Per `bagID:slotID` |
| Hyperlink (identity) | `GetHyperlinkData(hyperlink)` | Per hyperlink |
| Item template | `GetItemByIDData(itemID)` | No |
| Merchant row | `GetMerchantItemData(index)` | No (ephemeral) |
| Unified | `ResolveItemData(context)` | Uses tiers above |

`context` table: `{ itemID?, hyperlink?, bagID?, slotID?, tooltipData?, merchantIndex? }`.

Precedence for `ResolveItemData`: live `tooltipData` → bag slot → merchant →
hyperlink → `GetItemByID`. Bag-slot lookup auto-scans bags 0–5 and bank tabs
6–17 when `itemID` is given without slot coordinates.

`GetPropsData(props)` — PredicateEngine shape: bag slot first, then
`props.hyperlink`.

## Text extraction

| Function | Returns |
| --- | --- |
| `GetBagItemText(bagID, slotID)` | Concatenated `leftText` lines |
| `GetHyperlinkText(hyperlink)` | Same, hyperlink tier |
| `GetPropsText(props)` | Bag text, then hyperlink fallback |

Empty strings are **not** cached so pre-streaming evaluations can retry.

## Structured extractors

| Function | Use |
| --- | --- |
| `GetLearnSpellID(tooltipData)` | `ItemSpellTriggerLearn` spell ID (`#teachable`) |
| `IsAlreadyKnown(tooltipData)` | `ITEM_SPELL_KNOWN` line (structured) |
| `IsAlreadyKnownText(text)` | Same, concatenated body |
| `HasUseEffect(text)` | `USE_COLON` line present |
| `HasEquipEffect(text)` | `ITEM_SPELL_TRIGGER_ONEQUIP` line present |
| `GetBindState(tooltipData)` | `ItemBinding` line → `Enum.TooltipDataItemBinding` |
| `GetUsageRequirements(tooltipData)` | `UsageRequirement` lines |
| `GetAllowedClassIDs(tooltipData)` | `UsageRequirement` + `ITEM_CLASSES_ALLOWED` → `{ [classID]=true }` for `#myclass` / `forclass=` (nil when no Classes line; ignores red/white) |
| `ScanRedRequirementLines(tooltipData)` | Red unmet-requirement lines (bag, merchant, …). `ErrorLine`/`DisabledLine` only count when **red** — grey `DisabledLine`s are inactive off-spec stat variants, not failures |
| `GetUsabilityFacts(tooltipData)` | Single-pass `{ learnSpellID?, directUse, unmetRequirements }` for `#usable` fallback. `unmetRequirements` is red-colored lines only. Combine items are **not** detectable from tooltip data (reagent lists on live tooltips are addon-injected); PE detects them via `GetItemSpell` → `GetRecipeSchematic` |
| `HasItemInAccessibleBags(itemID)` | Copy in backpack / bags / reagent bag (0–5) |
| `NeedsUsabilityFallback(bagID, itemID)` | Bank-only `IsUsableItem` false-negative gate |
| `ScanMerchantBlockReason(index)` | Merchant snapshot + red-line scan |
| `PopulateTooltipProps(props, opts?)` | Fill lazy PE tooltip fields (`hasUseAbility`, `isAlreadyKnown`, `isTradeableLoot` via `TradeTimeRemaining`, …); optional `opts.recipeAlreadyKnown` bridge |

## Locale-safe GlobalStrings patterns

`PopulateTooltipProps` / charges matching must not assume enUS format shapes:

| Concern | Approach |
| --- | --- |
| `#charges` (`ITEM_SPELL_CHARGES`) | `BuildChargesSearchPattern`: `|4` locales → raw markup `(%d+) \|4` + first form; plain `%d` locales (zhCN/zhTW/koKR) → placeholder-first escape → `(%d+)…` |
| `#tradeableloot` | `Enum.TooltipDataLineType.TradeTimeRemaining` (structured; no `BIND_TRADE_TIME_REMAINING` text scrape) |
| `#onuse` / `#onequip` / unique | Direct `USE_COLON` / `ITEM_SPELL_TRIGGER_ONEQUIP` / `ITEM_UNIQUE*` globals (exist in all 11 locales) |
| `GetAllowedClassIDs` (`ITEM_CLASSES_ALLOWED`) | Capture pattern from the GlobalString; map localized `C_CreatureInfo` class names as whole list segments |

**Gate:** `bin/check_tooltip_patterns.py` — pre-commit `tooltip-globalstrings-patterns` (fires when `TooltipScanner.lua`, the checker, or GlobalStrings docs change). Suite `locale-parity` does not cover Blizzard GlobalStrings.

## Cache invalidation

| Method | When |
| --- | --- |
| `InvalidateTooltipCaches()` | Full wipe (bag + link data and text) — character-context changes, full resets |
| `InvalidateSlotTooltipCaches()` | Slot tier only (bag data + text) — frequent bag updates; link-tier template tooltips don't change when bag contents move |
| `InvalidateBagSlot(slotKey)` | Surgical `"bagID:slotID"` eviction |
| `InvalidateHyperlink(hyperlink)` | Surgical hyperlink eviction |

**PredicateEngine** calls `InvalidateSlotTooltipCaches()` from
`PE:InvalidatePropsCache()` (e.g. `BAG_UPDATE_DELAYED`), the full
`InvalidateTooltipCaches()` from `PE:InvalidateCharacterContext()` /
`PE:InvalidateCache()`, and surgical eviction from `PE:InvalidateItemIDs()`.

## Consumers

| Consumer | Delegation |
| --- | --- |
| `PredicateEngine` | `GetPropsData`, `GetPropsText`, `PopulateTooltipProps`, `GetBindState`, `GetLearnSpellID`, `HasUseEffect`, cache invalidation |
| `RecipeKnownUtil` | `ResolveItemData`, `GetLearnSpellID`, `IsAlreadyKnown`, `GetItemByIDData` |
| `Merchant` | `ScanMerchantBlockReason` |

## Design notes

- **Template vs contextual:** `GetItemByID` / `GetHyperlink` omit player-evaluated
  lines (`ITEM_SPELL_KNOWN`, red requirement gates). Prefer bag, merchant, or live
  `tooltipData` when those matter.
- **Recipe IDs vs teach spells:** `GetRecipeInfoForSkillLineAbility` accepts only
  skill-line ability / teach-spell IDs — not trade-skill recipe IDs from profession
  scans (`RecipeKnownUtil` enforces this).
- **Phase 4:** `PopulateTooltipProps` owns tooltip-field population; `#usable` uses PE's lazy `ResolveCharacterUsable` (`IsUsableItem` fast path; bank-only fallback = combine-schematic check first, then one contextual tooltip fetch + `GetUsabilityFacts` single pass, identity-cached for non-combine items).
