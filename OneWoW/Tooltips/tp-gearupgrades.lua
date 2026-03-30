local ADDON_NAME, OneWoW = ...

local function GetClassColor(class)
    if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
        local c = RAID_CLASS_COLORS[class]
        return c.r, c.g, c.b
    end
    return 0.9, 0.9, 0.9
end

local function GearUpgradeProvider(tooltip, context)
    if not context.itemID or not context.itemLink then return nil end

    local UD = OneWoW.UpgradeDetection
    if not UD then return nil end

    local db = OneWoW.db and OneWoW.db.global and OneWoW.db.global.settings
    local ovCfg = db and db.overlays and db.overlays.upgrade
    if not ovCfg or not ovCfg.showInTooltip then return nil end

    local config = OneWoW.TooltipEngine.TOOLTIP_CONFIG
    local L = OneWoW.L or {}
    local lines = {}

    local selfResult = UD:CheckItemUpgradeDetailed(context.itemLink)

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
        text = L["TIPS_GEARUPGRADES_HEADER"] or "Gear Upgrades",
        r = config.subHeaderColor[1],
        g = config.subHeaderColor[2],
        b = config.subHeaderColor[3],
    }

    if selfResult then
        local upgradeText
        if selfResult.mode == "PAWN" and selfResult.pawnScore then
            local eqScore = selfResult.equippedPawnScore or 0
            local diff = selfResult.pawnScore - eqScore
            upgradeText = string.format(
                L["TIPS_GEARUPGRADES_PAWN_LINE"] or "+%d ilvl (%s) | Pawn: %.1f vs %.1f (+%.1f)",
                selfResult.diff, selfResult.slotName, selfResult.pawnScore, eqScore, diff
            )
        else
            upgradeText = string.format(
                L["TIPS_GEARUPGRADES_ILVL_LINE"] or "+%d ilvl (%s)",
                selfResult.diff, selfResult.slotName
            )
        end

        local _, playerClass = UnitClass("player")
        local cr, cg, cb = GetClassColor(playerClass)
        local playerName = UnitName("player")

        lines[#lines + 1] = {
            type = "double",
            left = playerName,
            right = upgradeText,
            lr = cr, lg = cg, lb = cb,
            rr = 0.2, rg = 1.0, rb = 0.2,
        }
    end

    for _, alt in ipairs(altUpgrades) do
        local cr, cg, cb = GetClassColor(alt.class)
        local altText = string.format(
            L["TIPS_GEARUPGRADES_ALT_LINE"] or "+%d ilvl (%s)",
            alt.diff, alt.slotName
        )
        lines[#lines + 1] = {
            type = "double",
            left = alt.character,
            right = altText,
            lr = cr, lg = cg, lb = cb,
            rr = 0.6, rg = 0.8, rb = 0.6,
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
