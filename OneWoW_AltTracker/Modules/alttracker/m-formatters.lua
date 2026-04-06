local addonName, ns = ...
local L = ns.L

ns.AltTrackerFormatters = ns.AltTrackerFormatters or {}
local Formatters = ns.AltTrackerFormatters

function Formatters:GetCharacterKey(name, realm)
    local OneWoW_GUI = LibStub("OneWoW_GUI-1.0")
    return OneWoW_GUI:GetCharacterKey(name, realm)
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
    local absCopper = math.abs(copper)

    local success, result = pcall(C_CurrencyInfo.GetCoinTextureString, absCopper)
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

local SECONDS_PER_BUBBLE_RESTING = 28800
local MAX_RESTED_MULTIPLIER = 1.5
local MAX_RESTED_MULTIPLIER_PANDAREN = 3

function Formatters:EstimateRestedXP(charData, charKey)
    if not charData or not charData.xp then return 0 end
    if not charData.xp.maxXP or charData.xp.maxXP == 0 then return charData.xp.restedXP or 0 end

    local savedRestedXP = charData.xp.restedXP or 0
    local maxXP = charData.xp.maxXP
    local isResting = charData.xp.isResting
    local race = charData.race or charData.raceName or ""
    local multiplier = (race == "Pandaren") and MAX_RESTED_MULTIPLIER_PANDAREN or MAX_RESTED_MULTIPLIER
    local maxRestedXP = maxXP * multiplier

    local currentCharKey = UnitName("player") .. "-" .. GetRealmName()
    if charKey and charKey == currentCharKey then
        return math.min(savedRestedXP, maxRestedXP)
    end

    local lastUpdate = charData.xp.lastUpdate or charData.lastLogin or 0
    if lastUpdate == 0 then return math.min(savedRestedXP, maxRestedXP) end

    local elapsed = time() - lastUpdate
    if elapsed <= 0 then return math.min(savedRestedXP, maxRestedXP) end

    local oneXPBubble = maxXP / 20
    local numBubbles = elapsed / SECONDS_PER_BUBBLE_RESTING
    local xpEarned = numBubbles * oneXPBubble

    if not isResting then
        xpEarned = xpEarned / 4
    end

    local estimatedTotal = savedRestedXP + xpEarned
    return math.min(estimatedTotal, maxRestedXP)
end

function Formatters:FormatRestedXP(restedXP, maxXP, race)
    if not restedXP or restedXP == 0 then
        return "0%"
    end

    if not maxXP or maxXP == 0 then
        return "0%"
    end

    local percentage = (restedXP / maxXP) * 100
    local multiplier = (race and race == "Pandaren") and MAX_RESTED_MULTIPLIER_PANDAREN or MAX_RESTED_MULTIPLIER
    local maxPercent = multiplier * 100

    return string.format("%.0f%%", math.min(percentage, maxPercent))
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

local COMPACT_CLASS_NAMES = {
    WARRIOR = "War", PALADIN = "Pal", HUNTER = "Hunt",
    ROGUE = "Rog", PRIEST = "Pri", DEATHKNIGHT = "DK",
    SHAMAN = "Sham", MAGE = "Mage", WARLOCK = "Lock",
    MONK = "Mnk", DRUID = "Dru", DEMONHUNTER = "DH",
    EVOKER = "Evo",
}

function Formatters:GetCompactClassName(className)
    local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
    local offset = OneWoW_GUI and OneWoW_GUI:GetFontSizeOffset() or 0
    if offset >= 2 then
        local upper = string.upper(className or "")
        return COMPACT_CLASS_NAMES[upper] or self:FormatClassName(className)
    end
    return self:FormatClassName(className)
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

    if charKey and _G.OneWoW_AltTracker_Storage_DB and _G.OneWoW_AltTracker_Storage_DB.characters then
        local storageData = _G.OneWoW_AltTracker_Storage_DB.characters[charKey]
        if storageData and storageData.mail and storageData.mail.hasNewMail then
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
