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
hyperlink → `GetItemByID`. Bag-slot lookup auto-scans bags 0–4 when `itemID` is
given without slot coordinates.

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
| `ScanRedRequirementLines(tooltipData)` | Red merchant gate lines |
| `ScanMerchantBlockReason(index)` | Merchant snapshot + red-line scan |

## Cache invalidation

| Method | When |
| --- | --- |
| `InvalidateTooltipCaches()` | Full wipe (bag + link data and text) |
| `InvalidateBagSlot(slotKey)` | Surgical `"bagID:slotID"` eviction |
| `InvalidateHyperlink(hyperlink)` | Surgical hyperlink eviction |

**PredicateEngine** calls `InvalidateTooltipCaches()` from
`PE:InvalidatePropsCache()` / `PE:InvalidateCache()` and surgical eviction from
`PE:InvalidateItemIDs()`.

## Consumers

| Consumer | Delegation |
| --- | --- |
| `PredicateEngine` | `GetPropsData`, `GetPropsText`, `GetBindState`, `GetLearnSpellID`, `HasUseEffect`, cache invalidation |
| `RecipeKnownUtil` | `ResolveItemData`, `GetLearnSpellID`, `IsAlreadyKnown`, `GetItemByIDData` |
| `Merchant` | `ScanMerchantBlockReason` |

## Design notes

- **Template vs contextual:** `GetItemByID` / `GetHyperlink` omit player-evaluated
  lines (`ITEM_SPELL_KNOWN`, red requirement gates). Prefer bag, merchant, or live
  `tooltipData` when those matter.
- **Recipe IDs vs teach spells:** `GetRecipeInfoForSkillLineAbility` accepts only
  skill-line ability / teach-spell IDs — not trade-skill recipe IDs from profession
  scans (`RecipeKnownUtil` enforces this).
- **Phase 4:** `ResolveTooltipFields` may move more text-pattern scans into
  TooltipScanner; `#usable` / bank parity are separate.
