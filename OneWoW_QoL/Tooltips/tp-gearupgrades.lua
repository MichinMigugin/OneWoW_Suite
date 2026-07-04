local _, ns = ...
local OneWoW = OneWoW

local sort = sort

-- Alt list ordering. Equal-key rows fall back to name so the list does not
-- jitter between hovers. UPGRADE_DESC (biggest upgrade first) is the default.
local ALT_SORT_COMPARATORS = {
    UPGRADE_DESC = function(a, b) return a.diff > b.diff end,
    UPGRADE_ASC  = function(a, b) return a.diff < b.diff end,
    NAME_ASC     = function(a, b) return (a.name or "") < (b.name or "") end,
    ILVL_DESC    = function(a, b) return (a.itemLevel or 0) > (b.itemLevel or 0) end,
    LOGIN_DESC   = function(a, b) return (a.lastLogin or 0) > (b.lastLogin or 0) end,
}

local function SortAltMatches(matches, sortMode)
    local cmp = ALT_SORT_COMPARATORS[sortMode] or ALT_SORT_COMPARATORS.UPGRADE_DESC
    sort(matches, function(a, b)
        if cmp(a, b) then return true end
        if cmp(b, a) then return false end
        return (a.name or "") < (b.name or "")
    end)
end

local function GetClassColoredName(name, class)
    if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
        local c = RAID_CLASS_COLORS[class]
        return string.format("|cFF%02x%02x%02x%s|r", c.r * 255, c.g * 255, c.b * 255, name)
    end
    return name
end

local function GetIcons(diff)
    if diff > 0 then
        local icon = CreateTextureMarkup("Interface\\Buttons\\UI-MicroStream-Green", 64, 64, 16, 16, 0, 1, 1, 0)
        return icon, "|cFF00FF00", " " .. icon
    elseif diff < 0 then
        local icon = CreateTextureMarkup("Interface\\Buttons\\UI-MicroStream-Red", 64, 64, 16, 16, 0, 1, 0, 1)
        return icon, "|cFFFF0000", " " .. icon
    else
        local icon = CreateTextureMarkup("Interface\\RaidFrame\\ReadyCheck-Ready", 64, 64, 16, 16, 0, 1, 0, 1)
        return icon, "|cFFFFFFFF", " " .. icon
    end
end

local function ResolveItemLink(context)
    if context.itemLink then return context.itemLink end
    if context.itemID then
        local _, link = C_Item.GetItemInfo(context.itemID)
        return link
    end
    return nil
end

local function BuildRightText(colorCode, endIcon, diffVal, equipVal, thisVal, isDecimal, detail, L)
    local percent = 0
    if equipVal and equipVal > 0 then
        percent = (diffVal / equipVal) * 100
    end

    if detail == "MINIMUM" then
        return nil
    elseif detail == "SIMPLE" then
        if isDecimal then
            return colorCode .. string.format("%+.1f", diffVal) .. " (" .. string.format("%+.0f", percent) .. "%%)" .. endIcon .. "|r"
        else
            return colorCode .. string.format("%+d", diffVal) .. " (" .. string.format("%+.0f", percent) .. "%%)" .. endIcon .. "|r"
        end
    else
        local thisLabel  = L["TIPS_GEARCOMP_THIS"]
        local equipLabel = L["TIPS_GEARCOMP_EQUIP"]
        local diffLabel  = L["TIPS_GEARCOMP_DIFF"]
        if isDecimal then
            return colorCode .. thisLabel .. ":" .. string.format("%.1f", thisVal) .. " " .. equipLabel .. ":" .. string.format("%.1f", equipVal) .. " " .. diffLabel .. ":" .. string.format("%+.1f", diffVal) .. " (" .. string.format("%+.0f", percent) .. "%%)" .. endIcon .. "|r"
        else
            return colorCode .. thisLabel .. ":" .. tostring(thisVal) .. " " .. equipLabel .. ":" .. tostring(equipVal) .. " " .. diffLabel .. ":" .. string.format("%+d", diffVal) .. " (" .. string.format("%+.0f", percent) .. "%%)" .. endIcon .. "|r"
        end
    end
end

local function BuildCharLine(diff, name, class, equipped, new, isDecimal, detail, L)
    local icon, colorCode, endIcon = GetIcons(diff)
    local coloredName = GetClassColoredName(name, class)
    local rightText = BuildRightText(colorCode, endIcon, diff, equipped, new, isDecimal, detail, L)
    if rightText then
        return {
            type = "double",
            left = "  " .. icon .. " " .. coloredName,
            right = rightText,
            lr = 0.9, lg = 0.9, lb = 0.9,
            rr = 1, rg = 1, rb = 1,
        }
    end
    return {
        type = "text",
        text = "  " .. icon .. " " .. coloredName,
        r = 0.9, g = 0.9, b = 0.9,
    }
end

-- Shopping/comparison tooltips (ShoppingTooltip1/2, ItemRefShoppingTooltip1/2)
-- show the player's currently-equipped item next to a hovered item. Cross-
-- character alt upgrade info doesn't belong on those — it belongs on the
-- tooltip for the candidate item only.
local function IsComparisonTooltip(tooltip)
    local name = tooltip and tooltip.GetName and tooltip:GetName()
    if not name then return false end
    return name:find("^ShoppingTooltip%d") ~= nil
        or name:find("^ItemRefShoppingTooltip%d") ~= nil
end

local function ResolveItemLocation(tooltip)
    if not tooltip or not tooltip.GetOwner then return nil end
    local owner = tooltip:GetOwner()
    if not owner then return nil end
    local bagID  = owner.GetBagID and owner:GetBagID()
    local slotID = owner.GetID and owner:GetID()
    if not bagID or not slotID then return nil end
    local loc = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
    if loc and C_Item.DoesItemExist(loc) then return loc end
    return nil
end

local function IsItemStrictlySoulbound(itemLink, itemLocation)
    if not itemLocation then return false end
    if not C_Item.IsBound(itemLocation) then return false end
    if C_Item.IsItemBindToAccountUntilEquip(itemLink) then return false end
    if C_Bank.IsItemAllowedInBankType(Enum.BankType.Account, itemLocation) then
        return false
    end
    return true
end

local function DoGearUpgrade(tooltip, context, onlyUpgrade, detail, showAlts, altOptions)
    local itemLink = ResolveItemLink(context)
    if not itemLink then return nil, "no link" end

    local _, _, _, equipLoc, _, classID = C_Item.GetItemInfoInstant(itemLink)
    if not equipLoc or equipLoc == "" or equipLoc == "INVTYPE_NON_EQUIP" then return nil, "not equip: " .. tostring(equipLoc) end
    if not classID or (classID ~= Enum.ItemClass.Armor and classID ~= Enum.ItemClass.Weapon) then return nil, "not gear: " .. tostring(classID) end

    local UD = OneWoW.UpgradeDetection
    if not UD then return nil, "no UD" end

    local L = ns.L
    local comparison = UD:GetItemComparison(itemLink)

    local selfLine
    local mode = comparison and comparison.mode or "ILVL"

    if comparison and comparison.diff and not comparison.unusable then
        if not onlyUpgrade or comparison.diff > 0 then
            local _, playerClass = UnitClass("player")
            selfLine = BuildCharLine(
                comparison.diff,
                UnitName("player"),
                playerClass,
                comparison.equipValue,
                comparison.thisValue,
                comparison.isDecimal,
                detail,
                L
            )
        end
    end

    local altLines = {}
    local effectiveShowAlts = showAlts

    if effectiveShowAlts and altOptions and not altOptions.ignoreSoulbound then
        local itemLocation = ResolveItemLocation(tooltip)
        if IsItemStrictlySoulbound(itemLink, itemLocation) then
            effectiveShowAlts = false
        end
    end

    local charAPI = OneWoW_AltTracker_Character_API
    if effectiveShowAlts and charAPI and charAPI.GetAllCharacters then
        local currentKey = charAPI.GetCurrentCharacterKey and charAPI.GetCurrentCharacterKey()
        local characters = charAPI.GetAllCharacters() or {}

        local limit = (altOptions and altOptions.limit) or 10
        local scope = altOptions and altOptions.scope

        -- Collect every matching alt first, then sort, THEN cap. Applying the
        -- limit mid-scan over unordered pairs() is what made the list look
        -- randomly ordered and could hide the biggest upgrades entirely.
        local matches = {}
        for charKey, charData in pairs(characters) do
            if charKey and charKey ~= currentKey and type(charData) == "table"
               and OneWoW.AltScope:IsCharIncluded(charKey, scope) then
                local altResult = UD:IsItemUpgradeForAlt(context.itemID, itemLink, charData)
                if altResult and altResult.diff and (not onlyUpgrade or altResult.diff > 0) then
                    matches[#matches + 1] = {
                        diff      = altResult.diff,
                        name      = charData.name,
                        class     = charData.class,
                        equipped  = altResult.equipped,
                        new       = altResult.new,
                        itemLevel = charData.itemLevel or 0,
                        lastLogin = charData.lastLogin or 0,
                    }
                end
            end
        end

        SortAltMatches(matches, altOptions and altOptions.sort)

        local shown = (limit and limit > 0) and math.min(#matches, limit) or #matches
        for i = 1, shown do
            local m = matches[i]
            altLines[#altLines + 1] = BuildCharLine(
                m.diff, m.name, m.class, m.equipped, m.new, false, detail, L
            )
        end
    end

    if not selfLine and #altLines == 0 then
        return nil, "nothing to show"
    end

    local methodText = "iLvL"
    if mode == "PAWN" then methodText = "Pawn"
    elseif mode == "PAWN>ILVL" then methodText = "Pawn > iLvL"
    end

    local headerLabel = L["TIPS_GEARCOMP_HEADER"]
    local lines = {
        {
            type = "text",
            text = headerLabel .. " (" .. methodText .. ")",
            r = 0.4, g = 0.8, b = 1.0,
        },
    }

    if selfLine then lines[#lines + 1] = selfLine end
    for _, line in ipairs(altLines) do
        lines[#lines + 1] = line
    end

    return lines, nil
end

local function GearUpgradeProvider(tooltip, context)
    if not context or not context.itemID then return nil end
    if IsComparisonTooltip(tooltip) then return nil end

    -- gearupgrades mirrors overlays/upgrade storage (settingsTab/settingsId).
    local up = OneWoW.SettingsFeatureRegistry:GetFeatureSettings("tooltips", "gearupgrades")
    if not up.showInTooltip then return nil end
    local onlyUpgrade    = up.tooltipOnlyUpgrade    or false
    local detail         = up.tooltipDetail         or "FULL"
    local showSkipReason = up.tooltipShowSkipReason or false
    local showAlts       = up.tooltipShowAlts       ~= false

    local altOptions = {
        ignoreSoulbound    = up.tooltipIgnoreSoulbound,
        limit              = up.tooltipAltLimit,
        scope              = up.altScope,
        sort               = up.tooltipAltSort,
    }

    local ok, result, debugMsg = pcall(DoGearUpgrade, tooltip, context, onlyUpgrade, detail, showAlts, altOptions)

    if not ok then
        return {
            { type = "text", text = "GearComp ERR: " .. tostring(result), r = 1, g = 0, b = 0 },
        }
    end

    if not result then
        if showSkipReason and debugMsg then
            return {
                { type = "text", text = "GearComp skip: " .. debugMsg, r = 1, g = 0.5, b = 0 },
            }
        end
        return nil
    end

    return result
end

OneWoW.TooltipEngine:RegisterProvider({
    id           = "gearupgrades",
    order        = 910,
    featureId    = nil,
    tooltipTypes = {"item"},
    callback     = GearUpgradeProvider,
})
