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

local function DoGearUpgrade(context)
    local itemLink = ResolveItemLink(context)
    if not itemLink then return nil, "no link" end

    local _, _, _, equipLoc, _, classID = C_Item.GetItemInfoInstant(itemLink)
    if not equipLoc or equipLoc == "" or equipLoc == "INVTYPE_NON_EQUIP" then return nil, "not equip: " .. tostring(equipLoc) end
    if not classID or (classID ~= Enum.ItemClass.Armor and classID ~= Enum.ItemClass.Weapon) then return nil, "not gear: " .. tostring(classID) end

    local UD = OneWoW.UpgradeDetection
    if not UD then return nil, "no UD" end

    local comparison = UD:GetItemComparison(itemLink)
    if not comparison then return nil, "comparison nil" end
    if comparison.unusable then return nil, "unusable" end
    if not comparison.diff then return nil, "no diff" end

    local lines = {}

    local mode = comparison.mode or "ILVL"
    local methodText = "iLvL"
    if mode == "PAWN" then methodText = "Pawn"
    elseif mode == "PAWN>ILVL" then methodText = "Pawn > iLvL"
    end

    lines[#lines + 1] = {
        type = "text",
        text = "Gear Comparison (" .. methodText .. ")",
        r = 0.4, g = 0.8, b = 1.0,
    }

    local statusIcon, colorCode, endIcon = GetIcons(comparison.diff)
    local _, playerClass = UnitClass("player")
    local charName = GetClassColoredName(UnitName("player"), playerClass)

    local percent = 0
    if comparison.equipValue and comparison.equipValue > 0 then
        percent = (comparison.diff / comparison.equipValue) * 100
    end

    local rightText
    if comparison.isDecimal then
        rightText = colorCode .. "This:" .. string.format("%.1f", comparison.thisValue) .. " Equip:" .. string.format("%.1f", comparison.equipValue) .. " Diff:" .. string.format("%+.1f", comparison.diff) .. " (" .. string.format("%+.0f", percent) .. "%%)" .. endIcon .. "|r"
    else
        rightText = colorCode .. "This:" .. tostring(comparison.thisValue) .. " Equip:" .. tostring(comparison.equipValue) .. " Diff:" .. string.format("%+d", comparison.diff) .. " (" .. string.format("%+.0f", percent) .. "%%)" .. endIcon .. "|r"
    end

    lines[#lines + 1] = {
        type = "double",
        left = "  " .. statusIcon .. " " .. charName,
        right = rightText,
        lr = 0.9, lg = 0.9, lb = 0.9,
        rr = 1, rg = 1, rb = 1,
    }

    local charDB = _G.OneWoW_AltTracker_Character_DB
    local charAPI = _G.OneWoW_AltTracker_Character_API
    if charDB and charAPI and charAPI.GetCurrentCharacterKey then
        local currentKey = charAPI.GetCurrentCharacterKey()
        local altCount = 0
        for charKey, charData in pairs(charDB) do
            if charKey ~= currentKey and type(charData) == "table" and charData.class and charData.name and altCount < 10 then
                local altResult = UD:IsItemUpgradeForAlt(context.itemID, itemLink, charData)
                if altResult and altResult.diff then
                    local aIcon, aColor, aEnd = GetIcons(altResult.diff)
                    local aName = GetClassColoredName(charData.name, charData.class)
                    local aPercent = 0
                    if altResult.equipped and altResult.equipped > 0 then
                        aPercent = (altResult.diff / altResult.equipped) * 100
                    end
                    local aRight = aColor .. "This:" .. tostring(altResult.new) .. " Equip:" .. tostring(altResult.equipped) .. " Diff:" .. string.format("%+d", altResult.diff) .. " (" .. string.format("%+.0f", aPercent) .. "%%)" .. aEnd .. "|r"
                    lines[#lines + 1] = {
                        type = "double",
                        left = "  " .. aIcon .. " " .. aName,
                        right = aRight,
                        lr = 0.9, lg = 0.9, lb = 0.9,
                        rr = 1, rg = 1, rb = 1,
                    }
                    altCount = altCount + 1
                end
            end
        end
    end

    return lines, nil
end

local function GearUpgradeProvider(tooltip, context)
    if not context or not context.itemID then return nil end

    local db = OneWoW.db and OneWoW.db.global and OneWoW.db.global.settings
    if not db or not db.overlays or not db.overlays.upgrade then return nil end
    if not db.overlays.upgrade.showInTooltip then return nil end

    local ok, result, debugMsg = pcall(DoGearUpgrade, context)

    if not ok then
        return {
            { type = "text", text = "GearComp ERR: " .. tostring(result), r = 1, g = 0, b = 0 },
        }
    end

    if not result and debugMsg then
        return {
            { type = "text", text = "GearComp skip: " .. debugMsg, r = 1, g = 0.5, b = 0 },
        }
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
