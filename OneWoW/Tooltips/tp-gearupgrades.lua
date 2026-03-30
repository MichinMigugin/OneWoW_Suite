local ADDON_NAME, OneWoW = ...

local ICON_UPGRADE   = CreateTextureMarkup("Interface\\Buttons\\UI-MicroStream-Green", 64, 64, 14, 14, 0, 1, 1, 0)
local ICON_DOWNGRADE = CreateTextureMarkup("Interface\\Buttons\\UI-MicroStream-Red",   64, 64, 14, 14, 0, 1, 0, 1)
local ICON_EQUAL     = CreateTextureMarkup("Interface\\RaidFrame\\ReadyCheck-Ready",    64, 64, 14, 14, 0, 1, 0, 1)

local function GetClassColor(class)
    if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
        local c = RAID_CLASS_COLORS[class]
        return c.r, c.g, c.b
    end
    return 0.9, 0.9, 0.9
end

local function FormatComparison(result)
    local icon, diffText, cr, cg, cb

    if result.isUpgrade then
        icon = ICON_UPGRADE
        cr, cg, cb = 0.0, 1.0, 0.0
        if result.diff > 0 then
            diffText = string.format("+%d ilvl", result.diff)
        else
            diffText = "Empty slot"
        end
    elseif result.isDowngrade then
        icon = ICON_DOWNGRADE
        cr, cg, cb = 1.0, 0.2, 0.2
        diffText = string.format("%d ilvl", result.diff)
    else
        icon = ICON_EQUAL
        cr, cg, cb = 0.8, 0.8, 0.8
        diffText = "Same ilvl"
    end

    local comparison = string.format("%d vs %d", result.itemIlvl, result.equippedIlvl)
    local text = string.format("%s %s (%s) %s", icon, diffText, result.slotName, icon)

    if result.pawnScore and result.equippedPawnScore then
        local pawnDiff = result.pawnScore - result.equippedPawnScore
        local pawnSign = pawnDiff >= 0 and "+" or ""
        text = text .. string.format("  Pawn: %.1f vs %.1f (%s%.1f)", result.pawnScore, result.equippedPawnScore, pawnSign, pawnDiff)
    end

    return text, cr, cg, cb
end

local function GearUpgradeProvider(tooltip, context)
    if not context.itemID or not context.itemLink then return nil end

    local UD = OneWoW.UpgradeDetection
    if not UD then return nil end

    local db = OneWoW.db and OneWoW.db.global and OneWoW.db.global.settings
    local ovCfg = db and db.overlays and db.overlays.upgrade
    if not ovCfg or not ovCfg.showInTooltip then return nil end

    local config = OneWoW.TooltipEngine.TOOLTIP_CONFIG
    local lines = {}

    local selfResult = UD:GetItemComparison(context.itemLink)
    if selfResult and selfResult.unusable then
        return nil
    end

    local altUpgrades = {}
    local charAPI = _G.OneWoW_AltTracker_Character_API
    local charDB = _G.OneWoW_AltTracker_Character_DB
    if charAPI and charDB then
        local currentKey = charAPI.GetCurrentCharacterKey and charAPI.GetCurrentCharacterKey()
        for charKey, charData in pairs(charDB) do
            if charKey ~= currentKey and charData and charData.class and charData.name then
                local altResult = UD:IsItemUpgradeForAlt(context.itemID, context.itemLink, charData)
                if altResult then
                    altResult.character = charData.name
                    altResult.class = charData.class
                    altUpgrades[#altUpgrades + 1] = altResult
                end
            end
        end
        table.sort(altUpgrades, function(a, b) return (a.diff or 0) > (b.diff or 0) end)
    end

    if not selfResult and #altUpgrades == 0 then return nil end

    lines[#lines + 1] = {
        type = "header",
        text = "Gear Comparison",
        r = config.subHeaderColor[1],
        g = config.subHeaderColor[2],
        b = config.subHeaderColor[3],
    }

    if selfResult then
        local compText, cr, cg, cb = FormatComparison(selfResult)
        local _, playerClass = UnitClass("player")
        local lcr, lcg, lcb = GetClassColor(playerClass)

        lines[#lines + 1] = {
            type = "double",
            left = UnitName("player"),
            right = compText,
            lr = lcr, lg = lcg, lb = lcb,
            rr = cr, rg = cg, rb = cb,
        }
    end

    for _, alt in ipairs(altUpgrades) do
        local cr, cg, cb = GetClassColor(alt.class)
        local altIcon = ICON_UPGRADE
        local altText = string.format("%s +%d ilvl (%s) %s", altIcon, alt.diff, alt.slotName, altIcon)
        lines[#lines + 1] = {
            type = "double",
            left = alt.character,
            right = altText,
            lr = cr, lg = cg, lb = cb,
            rr = 0.0, rg = 1.0, rb = 0.0,
        }
    end

    return #lines > 0 and lines or nil
end

OneWoW.TooltipEngine:RegisterProvider({
    id           = "gearupgrades",
    order        = 25,
    featureId    = nil,
    tooltipTypes = {"item"},
    callback     = GearUpgradeProvider,
})
