---
name: wow-tooltip-system
description: Use this skill when authoring or reviewing WoW addon code that creates, hooks, or scans tooltips — anything calling GameTooltip, TooltipDataProcessor, C_TooltipInfo, or walking tooltipData.lines.
---

# WoW Tooltip System Skill

## Context

The tooltip system was rewritten in Dragonflight (10.0.2). Three legacy patterns gone:

- `OnTooltipSetItem` / `OnTooltipSetSpell` script handlers
- GameTooltip native methods for retrieving / populating displayed contents
- Hidden GameTooltip frames for scanning text — replaced by `C_TooltipInfo`

Three modern patterns replace them:

1. **Display** — `GameTooltip:SetOwner` + `:AddLine` + `:Show` for addon-owned tooltips (still works)
2. **Hook** — `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.X, fn)` to add lines to existing tooltips
3. **Scan** — `C_TooltipInfo.Get*` returns structured `tooltipData.lines` without displaying anything

## Authoritative sources

1. `TooltipDataHandler.lua` — `TooltipDataProcessor` + `TooltipDataHandlerMixin` source.
2. `TooltipUtil.lua` — helpers (`FindLinesFromData`, `FindLinesFromGetter`, `GetDisplayedItem/Spell/Unit`).
3. `TooltipInfoDocumentation.lua` — full list of `C_TooltipInfo` getters (`GetBagItem`, `GetItemByID`, `GetHyperlink`, `GetUnit`, `GetGuildBankItem`, etc.).
4. `TooltipInfoSharedDocumentation.lua` — `Enum.TooltipDataType`, `Enum.TooltipDataLineType`, `Enum.TooltipDataItemBinding` field tables. Read first when uncertain about line types or binding values.
5. Use `wow-api-specialist` skill to dig deeper into APIs.

## Patterns

### Display: addon-owned tooltip on hover

```lua
frame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Title", 1, 1, 1)
    GameTooltip:AddLine("Description", nil, nil, nil, true)  -- last arg = wrap
    GameTooltip:AddDoubleLine("Left", "Right", 1,1,1, 0.5,0.5,0.5)
    GameTooltip:Show()
end)
frame:SetScript("OnLeave", GameTooltip_Hide)
```

### Hook: add lines to existing tooltips

```lua
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item,
    function(tooltip, data)
        if tooltip == GameTooltip then           -- scope filter (see anti-pattern #5)
            tooltip:AddLine("My custom line", 0.5, 1, 0.5)
        end
    end
)
```

Variants: `AddTooltipPreCall`, `AddLinePreCall`, `AddLinePostCall` for finer control. Tooltip type values live in `Enum.TooltipDataType` (`Item`, `Spell`, `Unit`, `UnitAura`, `Currency`, `Mount`, `Achievement`, `Quest`, `BattlePet`, `Toy`, `Hyperlink`, `EquipmentSet`, etc.). For all types, use `TooltipDataProcessor.AllTypes` (string `"ALL"`).

Callbacks fire for **every** frame inheriting `GameTooltipTemplate`. Always scope with `tooltip == GameTooltip` (or whatever specific tooltip you care about) unless you genuinely want comparison tooltips, addon tooltips, and custom-templated frames to also fire.

### Scan: read tooltip data without displaying

```lua
local tooltipData = C_TooltipInfo.GetBagItem(bagID, slotID)
if tooltipData then
    for _, line in ipairs(tooltipData.lines) do
        -- line.type, line.leftText, line.rightText, line.bonding, etc.
    end
end
```

Common getters: `GetBagItem(bag, slot)`, `GetItemByID(itemID)`, `GetHyperlink(link)`, `GetUnit(unitToken)`, `GetGuildBankItem(tab, slot)`, `GetSpellByID(id)`. See `TooltipInfoDocumentation.lua` for the full set.

`TooltipUtil.SurfaceArgs` is **not** needed post-10.1.0 — fields are pre-surfaced on the returned data.

### Structured line reading: prefer enum types over text matching

`tooltipData.lines[i].type` is an `Enum.TooltipDataLineType` value (44 values including `ItemBinding`, `ItemLevel`, `SellPrice`, `FlavorText`, `EquipSlot`, `GemSocket`, `TradeTimeRemaining`, etc.). Many lines expose typed structured fields beyond `leftText` — e.g. `ItemBinding` lines populate `line.bonding` with an `Enum.TooltipDataItemBinding` value (`Soulbound`, `BindOnEquip`, `BindToAccount`, `AccountUntilEquipped`, …).

Always reach for the structured field first. Pattern-matching localized text is the fallback, not the default.

```lua
-- GOOD: structured, locale-independent
local TDIB = Enum.TooltipDataItemBinding
local BIND_LINE_TYPE = Enum.TooltipDataLineType.ItemBinding
local data = C_TooltipInfo.GetBagItem(bagID, slotID)
for _, line in ipairs(data.lines) do
    if line.type == BIND_LINE_TYPE and line.bonding then
        if line.bonding == TDIB.Soulbound then ... end
        if line.bonding == TDIB.AccountUntilEquipped then ... end  -- WUE
        break
    end
end
```

### Custom tooltip frames

Custom frames must inherit `GameTooltipTemplate` (which mixes in `GameTooltipDataMixin` to get `TOOLTIP_DATA_UPDATE` handling and the `Set*` accessor methods):

```lua
local tip = CreateFrame("GameTooltip", "MyAddonTooltip", UIParent, "GameTooltipTemplate")
```

### Locale-safe text matching (when structured fields aren't enough)

When you genuinely must pattern-match — e.g. for `ITEM_SPELL_CHARGES` strings that aren't exposed as a structured field — `C_TooltipInfo` line text is **raw WoW markup**. Patterns must match the markup, not the rendered display text.

- Raw markup example: `1 |4Charge:Charges;` (singular/plural form selector). Displayed text is `1 Charge`, but `strfind` sees the markup.
- Use Blizzard global string constants from `GlobalStrings.lua`: `ITEM_SPELL_CHARGES`, `BIND_TRADE_TIME_REMAINING`, `ITEM_UNIQUE`, `ITEM_UNIQUE_EQUIPPABLE`, `ITEM_SPELL_TRIGGER_ONEQUIP`, `USE_COLON`, `ITEM_SPELL_KNOWN`. Never hardcode English literals.
- Use `strfind(text, pattern, 1, true)` with the plain-match flag when no captures are needed (faster, no pattern interpretation).

## Review checklist — anti-patterns to flag

1. **`OnTooltipSetItem` / `OnTooltipSetSpell` hooks.** Removed in 10.0.2. Replace with `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, fn)`.

2. **Hidden GameTooltip for scanning.** Creating an off-screen GameTooltip, calling `:SetBagItem` / `:SetHyperlink`, and reading `_G["MyTipTextLeft"..i]` is the legacy pattern. Replace with `C_TooltipInfo.Get*` returning structured data.

3. **Pattern-matching text when structured data exists.** If `Enum.TooltipDataLineType.X` exists for the line you care about, walk `data.lines` and check `line.type` plus the typed field (e.g. `line.bonding`). Locale-fragile pattern matching is the fallback, not the default.

4. **Hardcoded English strings.** `strfind(text, "Bind on Equip")` breaks in every other locale. Pull from `GlobalStrings.lua` constants.

5. **`TooltipDataProcessor` callbacks without scope check.** Without `if tooltip == GameTooltip then`, the callback fires on comparison tooltips, addon tooltips, item-ref tooltips, and any custom `GameTooltipTemplate` frame. Almost always a bug.

6. **`TooltipUtil.SurfaceArgs` calls.** Unnecessary since 10.1.0 — data is pre-surfaced. Stale code from older addons.

7. **`GetItemInfo` bindType used for current bind state.** Returns the item *template's* bind type, not whether *this specific instance* is currently bound. Warbound, BoE-after-equip, and WUE items are misidentified. Use `C_TooltipInfo.GetBagItem` + the `ItemBinding` line's `line.bonding`.

8. **Custom tooltip frames missing `GameTooltipTemplate` inheritance.** Without it the frame can't dispatch `TOOLTIP_DATA_UPDATE`, doesn't get `Set*` accessors, and can't participate in the data-processor pipeline.

9. **Trying to retrieve tooltip contents via GameTooltip directly.** GameTooltip no longer exposes native get/extract methods for displayed data. Use `tooltip:GetPrimaryTooltipData()` (from the mixin) or call `C_TooltipInfo.Get*` independently.

10. **Pattern-matching display text instead of raw markup.** Patterns written against rendered text (e.g. `"1 Charge"`) won't match the raw markup `C_TooltipInfo` returns (e.g. `"1 |4Charge:Charges;"`).

## Related rules

- `.cursor/rules/WoW-Lua-Addon-Development.mdc` — Section 7.5 lives in the big rule today; this skill replaces it on extraction. Common-mistakes items 7 and 16 reference the same pitfalls.
