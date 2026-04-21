local ADDON_NAME, OneWoW = ...

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
        local thisLabel  = L["TIPS_GEARCOMP_THIS"]  or "This"
        local equipLabel = L["TIPS_GEARCOMP_EQUIP"] or "Equip"
        local diffLabel  = L["TIPS_GEARCOMP_DIFF"]  or "Diff"
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

local function DoGearUpgrade(context, onlyUpgrade, detail, showAlts)
    local itemLink = ResolveItemLink(context)
    if not itemLink then return nil, "no link" end

    local _, _, _, equipLoc, _, classID = C_Item.GetItemInfoInstant(itemLink)
    if not equipLoc or equipLoc == "" or equipLoc == "INVTYPE_NON_EQUIP" then return nil, "not equip: " .. tostring(equipLoc) end
    if not classID or (classID ~= Enum.ItemClass.Armor and classID ~= Enum.ItemClass.Weapon) then return nil, "not gear: " .. tostring(classID) end

    local UD = OneWoW.UpgradeDetection
    if not UD then return nil, "no UD" end

    local L = OneWoW.L
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
    local charAPI = _G.OneWoW_AltTracker_Character_API
    if showAlts and charAPI and charAPI.GetAllCharacters then
        local currentKey = charAPI.GetCurrentCharacterKey and charAPI.GetCurrentCharacterKey()
        local entries = charAPI.GetAllCharacters() or {}
        local altCount = 0
        for _, entry in ipairs(entries) do
            if altCount >= 10 then break end
            local charKey = entry.key
            local charData = entry.data
            if charKey and charKey ~= currentKey and type(charData) == "table" then
                local altResult = UD:IsItemUpgradeForAlt(context.itemID, itemLink, charData)
                if altResult and altResult.diff and (not onlyUpgrade or altResult.diff > 0) then
                    altLines[#altLines + 1] = BuildCharLine(
                        altResult.diff,
                        charData.name,
                        charData.class,
                        altResult.equipped,
                        altResult.new,
                        false,
                        detail,
                        L
                    )
                    altCount = altCount + 1
                end
            end
        end
    end

    if not selfLine and #altLines == 0 then
        return nil, "nothing to show"
    end

    local methodText = "iLvL"
    if mode == "PAWN" then methodText = "Pawn"
    elseif mode == "PAWN>ILVL" then methodText = "Pawn > iLvL"
    end

    local headerLabel = L["TIPS_GEARCOMP_HEADER"] or "Gear Comparison"
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

    local db = OneWoW.db and OneWoW.db.global and OneWoW.db.global.settings
    if not db or not db.overlays or not db.overlays.upgrade then return nil end
    if not db.overlays.upgrade.showInTooltip then return nil end

    local onlyUpgrade    = db.overlays.upgrade.tooltipOnlyUpgrade    or false
    local detail         = db.overlays.upgrade.tooltipDetail         or "FULL"
    local showSkipReason = db.overlays.upgrade.tooltipShowSkipReason or false
    local showAlts       = db.overlays.upgrade.tooltipShowAlts       ~= false

    local ok, result, debugMsg = pcall(DoGearUpgrade, context, onlyUpgrade, detail, showAlts)

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
