local addonName, ns = ...
local WoWNotes = _G.WoWNotes
local L = ns.L

ns.AltTrackerFormatters = ns.AltTrackerFormatters or {}
local Formatters = ns.AltTrackerFormatters

function Formatters:GetCharacterKey(name, realm)
    name = name or UnitName("player")
    realm = realm or GetRealmName()
    return name .. "-" .. realm
end

function Formatters:GetCurrentCharacterKey()
    if not self.currentCharacterKey then
        self.currentCharacterKey = self:GetCharacterKey()
    end
    return self.currentCharacterKey
end

function Formatters:FormatGold(copper)
    if not copper or type(copper) ~= "number" then
        return C_CurrencyInfo.GetCoinTextureString(0)
    end
    copper = math.floor(tonumber(copper) or 0)
    if copper == 0 then
        return C_CurrencyInfo.GetCoinTextureString(0)
    end

    local isNegative = copper < 0
    local absCoppper = math.abs(copper)

    local success, result = pcall(C_CurrencyInfo.GetCoinTextureString, absCoppper)
    if success then
        if isNegative then
            return "-" .. result
        end
        return result
    else
        return self:FormatGoldSimple(copper)
    end
end

function Formatters:FormatGoldSimple(copper)
    if not copper or copper == 0 then
        return "0g"
    end

    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local copperRem = copper % 100

    if gold > 0 then
        return string.format("%dg", gold)
    elseif silver > 0 then
        return string.format("%ds", silver)
    else
        return string.format("%dc", copperRem)
    end
end

function Formatters:FormatRelativeTime(timestamp)
    if not timestamp then
        return L["FMT_NEVER"]
    end

    local now = time()
    local diff = now - timestamp

    if diff < 0 then
        return L["FMT_NOW"]
    end

    if diff < 60 then
        return L["FMT_NOW"]
    elseif diff < 3600 then
        local mins = math.floor(diff / 60)
        return mins .. "m"
    elseif diff < 86400 then
        local hours = math.floor(diff / 3600)
        return hours .. "h"
    elseif diff < 604800 then
        local days = math.floor(diff / 86400)
        return days .. "d"
    elseif diff < 2592000 then
        local weeks = math.floor(diff / 604800)
        return weeks .. "w"
    else
        local months = math.floor(diff / 2592000)
        return months .. "mo"
    end
end

function Formatters:FormatPlayTime(seconds)
    if not seconds or seconds == 0 then
        return L["FMT_ZERO_MINUTES"]
    end

    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local mins = math.floor((seconds % 3600) / 60)

    local parts = {}
    if days > 0 then
        table.insert(parts, days .. (days == 1 and L["FMT_DAY"] or L["FMT_DAYS"]))
    end
    if hours > 0 then
        table.insert(parts, hours .. (hours == 1 and L["FMT_HOUR"] or L["FMT_HOURS"]))
    end
    if mins > 0 and days == 0 then
        table.insert(parts, mins .. (mins == 1 and L["FMT_MINUTE"] or L["FMT_MINUTES"]))
    end

    if #parts == 0 then
        return L["FMT_LESS_THAN_MINUTE"]
    end

    return table.concat(parts, ", ")
end

function Formatters:FormatRestedXP(restedXP, maxXP, race)
    if not restedXP or restedXP == 0 then
        return "0%"
    end

    local multiplier = 1.5
    if race and race == "Pandaren" then
        multiplier = 3
    end

    if not maxXP or maxXP == 0 then
        local maxLevelRestedXP = 150000
        local percentage = (restedXP / maxLevelRestedXP) * 100
        return string.format("%.0f%%", math.min(percentage, 100))
    end

    local maxRestedXP = maxXP * multiplier
    local percentage = (restedXP / maxRestedXP) * 100

    return string.format("%.0f%%", math.min(percentage, 100))
end

function Formatters:FormatItemLevel(ilvl)
    if not ilvl then
        return 0
    end
    return math.floor(ilvl)
end

local classColors = {
    ["WARRIOR"] = {0.78, 0.61, 0.43},
    ["PALADIN"] = {0.96, 0.55, 0.73},
    ["HUNTER"] = {0.67, 0.83, 0.45},
    ["ROGUE"] = {1.00, 0.96, 0.41},
    ["PRIEST"] = {1.00, 1.00, 1.00},
    ["DEATHKNIGHT"] = {0.77, 0.12, 0.23},
    ["SHAMAN"] = {0.00, 0.44, 0.87},
    ["MAGE"] = {0.25, 0.78, 0.92},
    ["WARLOCK"] = {0.53, 0.53, 0.93},
    ["MONK"] = {0.00, 1.00, 0.59},
    ["DRUID"] = {1.00, 0.49, 0.04},
    ["DEMONHUNTER"] = {0.64, 0.19, 0.79},
    ["EVOKER"] = {0.20, 0.58, 0.50}
}

function Formatters:GetClassColor(className)
    if not className then
        return {1, 1, 1}
    end

    className = string.upper(className)
    className = string.gsub(className, " ", "")
    className = string.gsub(className, "DEATH_KNIGHT", "DEATHKNIGHT")
    className = string.gsub(className, "DEMON_HUNTER", "DEMONHUNTER")

    return classColors[className] or {1, 1, 1}
end

function Formatters:GetClassColoredName(name, className)
    local color = self:GetClassColor(className)
    return string.format("|cFF%02x%02x%02x%s|r", color[1] * 255, color[2] * 255, color[3] * 255, name)
end

function Formatters:FormatClassName(className)
    if not className then
        return L and L["Unknown"] or "Unknown"
    end

    local upperClassName = string.upper(className)

    if LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[upperClassName] then
        return LOCALIZED_CLASS_NAMES_MALE[upperClassName]
    end

    local classDisplayNames = {
        WARRIOR = L["CLASS_WARRIOR"],
        PALADIN = L["CLASS_PALADIN"],
        HUNTER = L["CLASS_HUNTER"],
        ROGUE = L["CLASS_ROGUE"],
        PRIEST = L["CLASS_PRIEST"],
        DEATHKNIGHT = L["CLASS_DEATHKNIGHT"],
        SHAMAN = L["CLASS_SHAMAN"],
        MAGE = L["CLASS_MAGE"],
        WARLOCK = L["CLASS_WARLOCK"],
        MONK = L["CLASS_MONK"],
        DRUID = L["CLASS_DRUID"],
        DEMONHUNTER = L["CLASS_DEMONHUNTER"],
        EVOKER = L["CLASS_EVOKER"],
    }

    if classDisplayNames[upperClassName] then
        return classDisplayNames[upperClassName]
    end

    upperClassName = string.gsub(upperClassName, "DEATHKNIGHT", "Death Knight")
    upperClassName = string.gsub(upperClassName, "DEMONHUNTER", "Demon Hunter")

    return upperClassName:sub(1,1) .. upperClassName:sub(2):lower()
end

function Formatters:GetFactionIcon(faction)
    if faction == "Alliance" then
        return "Interface\\FriendsFrame\\PlusManz-Alliance"
    elseif faction == "Horde" then
        return "Interface\\FriendsFrame\\PlusManz-Horde"
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

function Formatters:GetFactionTexture(faction, size)
    size = size or 16
    local icon = self:GetFactionIcon(faction)
    return string.format("|T%s:%d:%d:0:0|t", icon, size, size)
end

function Formatters:FormatXP(currentXP, maxXP, level)
    local maxLevel = GetMaxPlayerLevel and GetMaxPlayerLevel() or 80
    if not level or level >= maxLevel then
        return "---"
    end

    if not currentXP or not maxXP or maxXP == 0 then
        return "0%"
    end

    local percentage = (currentXP / maxXP) * 100
    return string.format("%.0f%%", percentage)
end

function Formatters:FormatDurability(equipment)
    if not equipment then
        return "---"
    end

    local totalDurability = 0
    local durabilityItems = 0

    for slotId = 1, 19 do
        if slotId ~= 4 and slotId ~= 18 and slotId ~= 19 then
            local item = equipment[slotId]
            if item and item.itemLink then
                if item.durability and item.maxDurability and item.maxDurability > 0 then
                    totalDurability = totalDurability + (item.durability / item.maxDurability * 100)
                    durabilityItems = durabilityItems + 1
                end
            end
        end
    end

    if durabilityItems == 0 then
        return "---"
    end

    local avgDurability = totalDurability / durabilityItems
    return string.format("%.0f%%", avgDurability)
end

function Formatters:FormatBagsFree(bags)
    if not bags then
        return "---"
    end

    local totalFree = 0
    for bagID = 0, 4 do
        if bags[bagID] then
            totalFree = totalFree + (bags[bagID].freeSlots or 0)
        end
    end

    return tostring(totalFree)
end

function Formatters:SortCharacters(charList, sortBy, ascending, pinCurrentChar)
    if not charList or #charList == 0 then
        return charList
    end

    sortBy = sortBy or "name"
    ascending = ascending == nil and true or ascending
    pinCurrentChar = pinCurrentChar == nil and true or pinCurrentChar

    local currentCharKey = self:GetCurrentCharacterKey()

    table.sort(charList, function(a, b)
        if pinCurrentChar then
            if a.key == currentCharKey then return true end
            if b.key == currentCharKey then return false end
        end

        if sortBy == "name" or sortBy == "Character" then
            if ascending then
                return (a.name or "") < (b.name or "")
            else
                return (a.name or "") > (b.name or "")
            end
        elseif sortBy == "level" or sortBy == "Lvl" then
            local aVal = a.level or 0
            local bVal = b.level or 0
            if aVal == bVal then
                return (a.name or "") < (b.name or "")
            end
            if ascending then
                return aVal < bVal
            else
                return aVal > bVal
            end
        elseif sortBy == "class" or sortBy == "Class" then
            local aVal = a.class or ""
            local bVal = b.class or ""
            if aVal == bVal then
                return (a.name or "") < (b.name or "")
            end
            if ascending then
                return aVal < bVal
            else
                return aVal > bVal
            end
        elseif sortBy == "spec" or sortBy == "Spec" then
            local aVal = (a.specialization and a.specialization.name) or ""
            local bVal = (b.specialization and b.specialization.name) or ""
            if aVal == bVal then
                return (a.name or "") < (b.name or "")
            end
            if ascending then
                return aVal < bVal
            else
                return aVal > bVal
            end
        elseif sortBy == "rested" or sortBy == "Rested" then
            local aVal = a.restedXP or 0
            local bVal = b.restedXP or 0
            if aVal == bVal then
                return (a.name or "") < (b.name or "")
            end
            if ascending then
                return aVal < bVal
            else
                return aVal > bVal
            end
        elseif sortBy == "itemLevel" or sortBy == "iLvl" then
            local aVal = a.itemLevel or 0
            local bVal = b.itemLevel or 0
            if aVal == bVal then
                return (a.name or "") < (b.name or "")
            end
            if ascending then
                return aVal < bVal
            else
                return aVal > bVal
            end
        elseif sortBy == "bags" or sortBy == "Bags" then
            local aFree = 0
            local bFree = 0
            if a.bagData and a.bagData.bags then
                for bagID = 0, 4 do
                    if a.bagData.bags[bagID] then
                        aFree = aFree + (a.bagData.bags[bagID].freeSlots or 0)
                    end
                end
            end
            if b.bagData and b.bagData.bags then
                for bagID = 0, 4 do
                    if b.bagData.bags[bagID] then
                        bFree = bFree + (b.bagData.bags[bagID].freeSlots or 0)
                    end
                end
            end
            if aFree == bFree then
                return (a.name or "") < (b.name or "")
            end
            if ascending then
                return aFree < bFree
            else
                return aFree > bFree
            end
        elseif sortBy == "money" or sortBy == "gold" or sortBy == "Gold" then
            local aVal = a.money or 0
            local bVal = b.money or 0
            if aVal == bVal then
                return (a.name or "") < (b.name or "")
            end
            if ascending then
                return aVal < bVal
            else
                return aVal > bVal
            end
        elseif sortBy == "hearthLocation" or sortBy == "Hearth" then
            local aVal = a.hearthLocation or ""
            local bVal = b.hearthLocation or ""
            if aVal == bVal then
                return (a.name or "") < (b.name or "")
            end
            if ascending then
                return aVal < bVal
            else
                return aVal > bVal
            end
        elseif sortBy == "lastLogin" or sortBy == "Last Seen" then
            local aVal = a.lastLogin or 0
            local bVal = b.lastLogin or 0
            if aVal == bVal then
                return (a.name or "") < (b.name or "")
            end
            if ascending then
                return aVal < bVal
            else
                return aVal > bVal
            end
        elseif sortBy == "faction" or sortBy == "F" then
            local aVal = a.faction or ""
            local bVal = b.faction or ""
            if aVal == bVal then
                return (a.name or "") < (b.name or "")
            end
            if ascending then
                return aVal < bVal
            else
                return aVal > bVal
            end
        elseif sortBy == "mail" or sortBy == "M" then
            local aVal = a.mailCount or 0
            local bVal = b.mailCount or 0
            if aVal == bVal then
                return (a.name or "") < (b.name or "")
            end
            if ascending then
                return aVal < bVal
            else
                return aVal > bVal
            end
        elseif sortBy == "rating" or sortBy == "Rating" then
            local aVal = a.mythicPlusRating or 0
            local bVal = b.mythicPlusRating or 0
            if aVal == bVal then
                return (a.name or "") < (b.name or "")
            end
            if ascending then
                return aVal < bVal
            else
                return aVal > bVal
            end
        elseif sortBy == "bestTime" or sortBy == "Best Time" then
            local aVal = a.bestMPlusLevel or 0
            local bVal = b.bestMPlusLevel or 0
            if aVal == bVal then
                return (a.name or "") < (b.name or "")
            end
            if ascending then
                return aVal < bVal
            else
                return aVal > bVal
            end
        elseif sortBy == "star" then
            local aVal = a.bestMPlusLevel or 0
            local bVal = b.bestMPlusLevel or 0
            if aVal == bVal then
                return (a.name or "") < (b.name or "")
            end
            if ascending then
                return aVal < bVal
            else
                return aVal > bVal
            end
        elseif sortBy == "keystone" or sortBy == "KeyStone" then
            local aVal = a.keystoneLevel or 0
            local bVal = b.keystoneLevel or 0
            if aVal == bVal then
                return (a.name or "") < (b.name or "")
            end
            if ascending then
                return aVal < bVal
            else
                return aVal > bVal
            end
        elseif sortBy == "raidProg" or sortBy == "Raid Prog" then
            local aTotal = (a.raidProgressMythic or 0) * 4 + (a.raidProgressHeroic or 0) * 3 + (a.raidProgressNormal or 0) * 2 + (a.raidProgressLFR or 0)
            local bTotal = (b.raidProgressMythic or 0) * 4 + (b.raidProgressHeroic or 0) * 3 + (b.raidProgressNormal or 0) * 2 + (b.raidProgressLFR or 0)
            if aTotal == bTotal then
                return (a.name or "") < (b.name or "")
            end
            if ascending then
                return aTotal < bTotal
            else
                return aTotal > bTotal
            end
        elseif sortBy == "vault" or sortBy == "Vault" then
            local aVault = a.vaultProgress or {}
            local bVault = b.vaultProgress or {}
            local aTotal = (aVault.raid or 0) + (aVault.dungeon or 0) + (aVault.world or 0)
            local bTotal = (bVault.raid or 0) + (bVault.dungeon or 0) + (bVault.world or 0)
            if aTotal == bTotal then
                return (a.name or "") < (b.name or "")
            end
            if ascending then
                return aTotal < bTotal
            else
                return aTotal > bTotal
            end
        elseif sortBy == "durability" or sortBy == "Durability" then
            local aVal = a.durability or 100
            local bVal = b.durability or 100
            if aVal == bVal then
                return (a.name or "") < (b.name or "")
            end
            if ascending then
                return aVal < bVal
            else
                return aVal > bVal
            end
        elseif sortBy == "enchants" or sortBy == "missingEnchants" or sortBy == "Enchants" then
            local aVal = a.missingEnchants or 0
            local bVal = b.missingEnchants or 0
            if aVal == bVal then
                return (a.name or "") < (b.name or "")
            end
            if ascending then
                return aVal < bVal
            else
                return aVal > bVal
            end
        elseif sortBy == "gems" or sortBy == "missingGems" or sortBy == "Gems" then
            local aVal = a.missingGems or 0
            local bVal = b.missingGems or 0
            if aVal == bVal then
                return (a.name or "") < (b.name or "")
            end
            if ascending then
                return aVal < bVal
            else
                return aVal > bVal
            end
        elseif sortBy == "tierSet" or sortBy == "Tier Set" then
            local aVal = a.tierSet or 0
            local bVal = b.tierSet or 0
            if aVal == bVal then
                return (a.name or "") < (b.name or "")
            end
            if ascending then
                return aVal < bVal
            else
                return aVal > bVal
            end
        elseif sortBy == "embellishments" or sortBy == "Embellishments" then
            local aVal = a.embellishments or 0
            local bVal = b.embellishments or 0
            if aVal == bVal then
                return (a.name or "") < (b.name or "")
            end
            if ascending then
                return aVal < bVal
            else
                return aVal > bVal
            end
        elseif sortBy == "status" or sortBy == "Status" then
            local aVal = 0
            local bVal = 0
            if a.lowDurability then aVal = aVal + 100 end
            if a.missingEnchants then aVal = aVal + (a.missingEnchants or 0) * 10 end
            if a.missingGems then aVal = aVal + (a.missingGems or 0) * 10 end
            if b.lowDurability then bVal = bVal + 100 end
            if b.missingEnchants then bVal = bVal + (b.missingEnchants or 0) * 10 end
            if b.missingGems then bVal = bVal + (b.missingGems or 0) * 10 end
            if aVal == bVal then
                return (a.name or "") < (b.name or "")
            end
            if ascending then
                return aVal < bVal
            else
                return aVal > bVal
            end
        elseif sortBy == "primary1" or sortBy == "Primary 1" then
            local aName = ""
            local aSkill = 0
            if a.professions and a.professions.primary and a.professions.primary[1] then
                aName = a.professions.primary[1].name or ""
                aSkill = a.professions.primary[1].skillLevel or 0
            end
            local bName = ""
            local bSkill = 0
            if b.professions and b.professions.primary and b.professions.primary[1] then
                bName = b.professions.primary[1].name or ""
                bSkill = b.professions.primary[1].skillLevel or 0
            end
            if aName == bName then
                if aSkill == bSkill then
                    return (a.name or "") < (b.name or "")
                end
                if ascending then
                    return aSkill < bSkill
                else
                    return aSkill > bSkill
                end
            end
            if ascending then
                return aName < bName
            else
                return aName > bName
            end
        elseif sortBy == "primary2" or sortBy == "Primary 2" then
            local aName = ""
            local aSkill = 0
            if a.professions and a.professions.primary and a.professions.primary[2] then
                aName = a.professions.primary[2].name or ""
                aSkill = a.professions.primary[2].skillLevel or 0
            end
            local bName = ""
            local bSkill = 0
            if b.professions and b.professions.primary and b.professions.primary[2] then
                bName = b.professions.primary[2].name or ""
                bSkill = b.professions.primary[2].skillLevel or 0
            end
            if aName == bName then
                if aSkill == bSkill then
                    return (a.name or "") < (b.name or "")
                end
                if ascending then
                    return aSkill < bSkill
                else
                    return aSkill > bSkill
                end
            end
            if ascending then
                return aName < bName
            else
                return aName > bName
            end
        elseif sortBy == "cooking" or sortBy == "Cooking" then
            local aSkill = 0
            if a.professions and a.professions.secondary then
                for _, prof in ipairs(a.professions.secondary) do
                    if prof.name == "Cooking" then
                        aSkill = prof.skillLevel or 0
                        break
                    end
                end
            end
            local bSkill = 0
            if b.professions and b.professions.secondary then
                for _, prof in ipairs(b.professions.secondary) do
                    if prof.name == "Cooking" then
                        bSkill = prof.skillLevel or 0
                        break
                    end
                end
            end
            if aSkill == bSkill then
                return (a.name or "") < (b.name or "")
            end
            if ascending then
                return aSkill < bSkill
            else
                return aSkill > bSkill
            end
        elseif sortBy == "fishing" or sortBy == "Fishing" then
            local aSkill = 0
            if a.professions and a.professions.secondary then
                for _, prof in ipairs(a.professions.secondary) do
                    if prof.name == "Fishing" then
                        aSkill = prof.skillLevel or 0
                        break
                    end
                end
            end
            local bSkill = 0
            if b.professions and b.professions.secondary then
                for _, prof in ipairs(b.professions.secondary) do
                    if prof.name == "Fishing" then
                        bSkill = prof.skillLevel or 0
                        break
                    end
                end
            end
            if aSkill == bSkill then
                return (a.name or "") < (b.name or "")
            end
            if ascending then
                return aSkill < bSkill
            else
                return aSkill > bSkill
            end
        elseif sortBy == "archeology" or sortBy == "Archeology" then
            local aSkill = 0
            if a.professions and a.professions.secondary then
                for _, prof in ipairs(a.professions.secondary) do
                    if prof.name == "Archaeology" then
                        aSkill = prof.skillLevel or 0
                        break
                    end
                end
            end
            local bSkill = 0
            if b.professions and b.professions.secondary then
                for _, prof in ipairs(b.professions.secondary) do
                    if prof.name == "Archaeology" then
                        bSkill = prof.skillLevel or 0
                        break
                    end
                end
            end
            if aSkill == bSkill then
                return (a.name or "") < (b.name or "")
            end
            if ascending then
                return aSkill < bSkill
            else
                return aSkill > bSkill
            end
        elseif sortBy == "tools" or sortBy == "Tools" then
            local aVal = (a.professions and a.professions.toolsEquipped) and 1 or 0
            local bVal = (b.professions and b.professions.toolsEquipped) and 1 or 0
            if aVal == bVal then
                return (a.name or "") < (b.name or "")
            end
            if ascending then
                return aVal < bVal
            else
                return aVal > bVal
            end
        elseif sortBy == "accessories" or sortBy == "Accessories" then
            local aVal = (a.professions and a.professions.accessoriesEquipped) and 1 or 0
            local bVal = (b.professions and b.professions.accessoriesEquipped) and 1 or 0
            if aVal == bVal then
                return (a.name or "") < (b.name or "")
            end
            if ascending then
                return aVal < bVal
            else
                return aVal > bVal
            end
        elseif sortBy == "lockout1" or sortBy == "Lockout 1" then
            local aName = ""
            local aExpires = 0
            if a.instanceLockouts and a.instanceLockouts[1] then
                aName = a.instanceLockouts[1].instanceName or ""
                aExpires = a.instanceLockouts[1].expiresAt or 0
            end
            local bName = ""
            local bExpires = 0
            if b.instanceLockouts and b.instanceLockouts[1] then
                bName = b.instanceLockouts[1].instanceName or ""
                bExpires = b.instanceLockouts[1].expiresAt or 0
            end
            if aName == bName then
                if aExpires == bExpires then
                    return (a.name or "") < (b.name or "")
                end
                if ascending then
                    return aExpires < bExpires
                else
                    return aExpires > bExpires
                end
            end
            if ascending then
                return aName < bName
            else
                return aName > bName
            end
        elseif sortBy == "lockout2" or sortBy == "Lockout 2" then
            local aName = ""
            local aExpires = 0
            if a.instanceLockouts and a.instanceLockouts[2] then
                aName = a.instanceLockouts[2].instanceName or ""
                aExpires = a.instanceLockouts[2].expiresAt or 0
            end
            local bName = ""
            local bExpires = 0
            if b.instanceLockouts and b.instanceLockouts[2] then
                bName = b.instanceLockouts[2].instanceName or ""
                bExpires = b.instanceLockouts[2].expiresAt or 0
            end
            if aName == bName then
                if aExpires == bExpires then
                    return (a.name or "") < (b.name or "")
                end
                if ascending then
                    return aExpires < bExpires
                else
                    return aExpires > bExpires
                end
            end
            if ascending then
                return aName < bName
            else
                return aName > bName
            end
        elseif sortBy == "lockout3" or sortBy == "Lockout 3" then
            local aName = ""
            local aExpires = 0
            if a.instanceLockouts and a.instanceLockouts[3] then
                aName = a.instanceLockouts[3].instanceName or ""
                aExpires = a.instanceLockouts[3].expiresAt or 0
            end
            local bName = ""
            local bExpires = 0
            if b.instanceLockouts and b.instanceLockouts[3] then
                bName = b.instanceLockouts[3].instanceName or ""
                bExpires = b.instanceLockouts[3].expiresAt or 0
            end
            if aName == bName then
                if aExpires == bExpires then
                    return (a.name or "") < (b.name or "")
                end
                if ascending then
                    return aExpires < bExpires
                else
                    return aExpires > bExpires
                end
            end
            if ascending then
                return aName < bName
            else
                return aName > bName
            end
        elseif sortBy == "lockout4" or sortBy == "Lockout 4" then
            local aName = ""
            local aExpires = 0
            if a.instanceLockouts and a.instanceLockouts[4] then
                aName = a.instanceLockouts[4].instanceName or ""
                aExpires = a.instanceLockouts[4].expiresAt or 0
            end
            local bName = ""
            local bExpires = 0
            if b.instanceLockouts and b.instanceLockouts[4] then
                bName = b.instanceLockouts[4].instanceName or ""
                bExpires = b.instanceLockouts[4].expiresAt or 0
            end
            if aName == bName then
                if aExpires == bExpires then
                    return (a.name or "") < (b.name or "")
                end
                if ascending then
                    return aExpires < bExpires
                else
                    return aExpires > bExpires
                end
            end
            if ascending then
                return aName < bName
            else
                return aName > bName
            end
        elseif sortBy == "expires" or sortBy == "Expires" then
            local aVal = 999999999
            if a.instanceLockouts then
                for _, lockout in ipairs(a.instanceLockouts) do
                    if lockout.expiresAt and lockout.expiresAt < aVal then
                        aVal = lockout.expiresAt
                    end
                end
            end
            local bVal = 999999999
            if b.instanceLockouts then
                for _, lockout in ipairs(b.instanceLockouts) do
                    if lockout.expiresAt and lockout.expiresAt < bVal then
                        bVal = lockout.expiresAt
                    end
                end
            end
            if aVal == bVal then
                return (a.name or "") < (b.name or "")
            end
            if ascending then
                return aVal < bVal
            else
                return aVal > bVal
            end
        end
        return false
    end)

    return charList
end

function Formatters:GetRaceIcon(race, gender)
    if not race then
        return "Interface\\Icons\\INV_Misc_QuestionMark"
    end

    local raceFile = race:gsub(" ", "")
    local genderSuffix = (gender == 3) and "Female" or "Male"

    return string.format("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Races_%s-%s", raceFile, genderSuffix)
end

function Formatters:GetRaceTexture(race, gender, size)
    size = size or 16
    local icon = self:GetRaceIcon(race, gender)
    return string.format("|T%s:%d:%d:0:0|t", icon, size, size)
end

function Formatters:GetMailIcon(mailCount, oldestExpiry, lastCheck, charKey)
    local hasAuctionMail = false
    local hasNewMailFlag = false

    if charKey and ns.AuctionsModule then
        local auctionSummary = ns.AuctionsModule:GetAuctionMailSummary(charKey)
        if auctionSummary and auctionSummary.hasUncollectedMail then
            hasAuctionMail = true
        end
    end

    if charKey and _G.WoWNotes and _G.WoWNotes.db and _G.WoWNotes.db.global and _G.WoWNotes.db.global.altTracker then
        local charData = _G.WoWNotes.db.global.altTracker.characters[charKey]
        if charData and charData.hasNewMail then
            hasNewMailFlag = true
        end
    end

    if (not mailCount or mailCount == 0) and not hasAuctionMail and not hasNewMailFlag then
        return "Interface\\Minimap\\Tracking\\Mailbox", {0.5, 0.5, 0.5}
    end

    local daysRemaining = oldestExpiry or 30
    if lastCheck and oldestExpiry then
        local daysSinceCheck = (time() - lastCheck) / 86400
        daysRemaining = daysRemaining - daysSinceCheck
    end

    if daysRemaining <= 2 then
        return "Interface\\Minimap\\Tracking\\Mailbox", {1, 0, 0}
    elseif hasAuctionMail then
        return "Interface\\Minimap\\Tracking\\Mailbox", {1, 1, 0}
    elseif daysRemaining <= 7 then
        return "Interface\\Minimap\\Tracking\\Mailbox", {1, 1, 0}
    elseif hasNewMailFlag then
        return "Interface\\Minimap\\Tracking\\Mailbox", {0, 1, 0}
    else
        return "Interface\\Minimap\\Tracking\\Mailbox", {1, 1, 1}
    end
end

function Formatters:GetMailTexture(mailCount, oldestExpiry, lastCheck, size)
    size = size or 16
    local icon, color = self:GetMailIcon(mailCount, oldestExpiry, lastCheck)
    return string.format("|T%s:%d:%d:0:0|t", icon, size, size), color
end

function Formatters:GetMythicPlusRatingColor(rating)
    local score = tonumber(rating) or 0

    if score == 0 then
        return {1, 0, 0}
    elseif score >= 1 and score <= 1499 then
        return {0.6, 0.6, 0.6}
    elseif score >= 1500 and score <= 2000 then
        return {1, 1, 1}
    elseif score >= 2000 and score <= 2500 then
        return {0.7, 1, 0.7}
    elseif score >= 2500 and score <= 2999 then
        return {0, 1, 0}
    else
        return {1, 0.82, 0}
    end
end

function Formatters:GetRaidColor(kills, max)
    if kills == 0 then
        return {1, 1, 1}
    elseif kills >= max then
        return {0.2, 1.0, 0.2}
    else
        return {1.0, 1.0, 0.2}
    end
end
