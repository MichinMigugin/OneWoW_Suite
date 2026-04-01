local _, OneWoW_Bags = ...

OneWoW_Bags.SearchEngine = {}
local SE = OneWoW_Bags.SearchEngine

local compiledCache = {}
local itemMatchCache = {}

local BATTLE_PET_CAGE_ID = 82800

local equipSetItemCache = {}
local equipSetCacheTime = 0

local EXPANSION_IDS = {
    ["classic"]       = 0, ["vanilla"] = 0,
    ["tbc"]           = 1, ["burningcrusade"] = 1,
    ["wrath"]         = 2, ["wotlk"] = 2,
    ["cata"]          = 3, ["cataclysm"] = 3,
    ["mists"]         = 4, ["mop"] = 4, ["pandaria"] = 4,
    ["warlords"]      = 5, ["wod"] = 5, ["draenor"] = 5,
    ["legion"]        = 6,
    ["bfa"]           = 7, ["battleforazeroth"] = 7,
    ["shadowlands"]   = 8, ["sl"] = 8,
    ["dragonflight"]  = 9, ["df"] = 9,
    ["warwithin"]     = 10, ["tww"] = 10, ["thewarwithin"] = 10,
    ["midnight"]      = 11,
}

local QUALITY_MAP = {
    ["poor"]      = 0, ["junk"] = 0, ["grey"] = 0, ["gray"] = 0, ["trash"] = 0,
    ["common"]    = 1, ["white"] = 1,
    ["uncommon"]  = 2, ["green"] = 2,
    ["rare"]      = 3, ["blue"] = 3,
    ["epic"]      = 4, ["purple"] = 4,
    ["legendary"] = 5, ["orange"] = 5,
    ["artifact"]  = 6,
    ["heirloom"]  = 7,
}

local SLOT_MAP = {
    ["head"] = "INVTYPE_HEAD", ["helm"] = "INVTYPE_HEAD", ["helmet"] = "INVTYPE_HEAD",
    ["neck"] = "INVTYPE_NECK", ["necklace"] = "INVTYPE_NECK", ["amulet"] = "INVTYPE_NECK",
    ["shoulder"] = "INVTYPE_SHOULDER", ["shoulders"] = "INVTYPE_SHOULDER",
    ["chest"] = "INVTYPE_CHEST", ["robe"] = "INVTYPE_ROBE",
    ["waist"] = "INVTYPE_WAIST", ["belt"] = "INVTYPE_WAIST",
    ["legs"] = "INVTYPE_LEGS", ["pants"] = "INVTYPE_LEGS",
    ["feet"] = "INVTYPE_FEET", ["boots"] = "INVTYPE_FEET",
    ["wrist"] = "INVTYPE_WRIST", ["bracers"] = "INVTYPE_WRIST", ["bracer"] = "INVTYPE_WRIST",
    ["hands"] = "INVTYPE_HAND", ["gloves"] = "INVTYPE_HAND",
    ["finger"] = "INVTYPE_FINGER", ["ring"] = "INVTYPE_FINGER",
    ["trinket"] = "INVTYPE_TRINKET",
    ["back"] = "INVTYPE_CLOAK", ["cloak"] = "INVTYPE_CLOAK", ["cape"] = "INVTYPE_CLOAK",
    ["mainhand"] = "INVTYPE_WEAPONMAINHAND",
    ["offhand"] = "INVTYPE_WEAPONOFFHAND", ["holdable"] = "INVTYPE_HOLDABLE",
    ["shield"] = "INVTYPE_SHIELD",
    ["ranged"] = "INVTYPE_RANGED", ["wand"] = "INVTYPE_RANGEDRIGHT",
    ["tabard"] = "INVTYPE_TABARD",
    ["shirt"] = "INVTYPE_BODY",
}

local ARMOR_SUBCLASS_MAP = {
    ["cloth"]   = 1,
    ["leather"] = 2,
    ["mail"]    = 3,
    ["plate"]   = 4,
}

local tooltipCache = {}

local function GetTooltipText(bagID, slotID)
    local cacheKey = bagID .. ":" .. slotID
    if tooltipCache[cacheKey] then return tooltipCache[cacheKey] end

    local tooltipData = C_TooltipInfo.GetBagItem(bagID, slotID)
    if not tooltipData then
        tooltipCache[cacheKey] = ""
        return ""
    end

    TooltipUtil.SurfaceArgs(tooltipData)
    local text = ""
    for _, line in ipairs(tooltipData.lines) do
        TooltipUtil.SurfaceArgs(line)
        text = text .. (line.leftText or "") .. "\n"
    end
    tooltipCache[cacheKey] = text
    return text
end

function SE:ClearTooltipCache()
    wipe(tooltipCache)
end

function SE:GetTooltipText(bagID, slotID)
    return GetTooltipText(bagID, slotID)
end

local function CheckKeyword(keyword, itemID, bagID, slotID, itemInfo)
    if not keyword or keyword == "" then return false end

    local kw = string.lower(keyword)

    local classID = itemInfo._classID
    local subClassID = itemInfo._subClassID
    local quality = itemInfo.quality
    local equipLoc = itemInfo._equipLoc

    if kw == "pet" or kw == "battlepet" then
        if itemID == BATTLE_PET_CAGE_ID then return true end
        if classID == Enum.ItemClass.Battlepet then return true end
        if classID == Enum.ItemClass.Miscellaneous and subClassID == Enum.ItemMiscellaneousSubclass.CompanionPet then return true end
        return false
    end

    if kw == "mount" then
        if classID == Enum.ItemClass.Miscellaneous and subClassID == Enum.ItemMiscellaneousSubclass.Mount then return true end
        return false
    end

    if kw == "toy" then
        if C_ToyBox and C_ToyBox.GetToyInfo then
            local toyInfo = C_ToyBox.GetToyInfo(itemID)
            if toyInfo then return true end
        end
        return false
    end

    if kw == "collected" then
        if itemID == BATTLE_PET_CAGE_ID and itemInfo.hyperlink then
            local petID = itemInfo.hyperlink:match("battlepet:(%d+)")
            if petID then
                local speciesID = tonumber(petID)
                if speciesID and C_PetJournal and C_PetJournal.GetNumCollectedInfo then
                    local numCollected = C_PetJournal.GetNumCollectedInfo(speciesID)
                    if numCollected and numCollected > 0 then return true end
                end
            end
        end
        if C_ToyBox and C_ToyBox.GetToyInfo then
            local toyInfo = C_ToyBox.GetToyInfo(itemID)
            if toyInfo then
                if C_ToyBox.PlayerHasToy and C_ToyBox.PlayerHasToy(itemID) then return true end
            end
        end
        if classID == Enum.ItemClass.Miscellaneous and subClassID == Enum.ItemMiscellaneousSubclass.Mount then
            local mountIDs = C_MountJournal and C_MountJournal.GetMountIDs and C_MountJournal.GetMountIDs()
            if mountIDs then
                for _, mountID in ipairs(mountIDs) do
                    local _, _, _, _, _, _, _, _, _, _, isCollected, _, itemIDMount = C_MountJournal.GetMountInfoByID(mountID)
                    if itemIDMount == itemID and isCollected then return true end
                end
            end
        end
        return false
    end

    if kw == "uncollected" then
        return not CheckKeyword("collected", itemID, bagID, slotID, itemInfo)
    end

    if kw == "soulbound" or kw == "bound" then
        if bagID and slotID then
            local tt = GetTooltipText(bagID, slotID)
            if tt:find(ITEM_SOULBOUND) or tt:find(ITEM_ACCOUNTBOUND or "Account Bound") or tt:find(ITEM_BNETACCOUNTBOUND or "Blizzard Account Bound") then
                return true
            end
        end
        return false
    end

    if kw == "boe" or kw == "bindonequip" then
        if bagID and slotID then
            local tt = GetTooltipText(bagID, slotID)
            if tt:find(ITEM_BIND_ON_EQUIP) then return true end
        end
        return false
    end

    if kw == "boa" or kw == "accountbound" then
        if bagID and slotID then
            local tt = GetTooltipText(bagID, slotID)
            if tt:find(ITEM_ACCOUNTBOUND or "Account Bound") or tt:find(ITEM_BNETACCOUNTBOUND or "Blizzard Account Bound") then
                return true
            end
        end
        return false
    end

    if kw == "bou" or kw == "bindonuse" then
        if bagID and slotID then
            local tt = GetTooltipText(bagID, slotID)
            if tt:find(ITEM_BIND_ON_USE) then return true end
        end
        return false
    end

    if kw == "junk" or kw == "trash" then
        if quality == Enum.ItemQuality.Poor then return true end
        if _G.OneWoW and _G.OneWoW.ItemStatus and _G.OneWoW.ItemStatus:IsItemJunk(itemID) then return true end
        return false
    end

    if kw == "equipment" or kw == "gear" or kw == "equippable" then
        if IsEquippableItem and IsEquippableItem(itemID) then return true end
        return false
    end

    if kw == "weapon" then
        return classID == Enum.ItemClass.Weapon
    end

    if kw == "armor" then
        return classID == Enum.ItemClass.Armor
    end

    if kw == "consumable" then
        return classID == Enum.ItemClass.Consumable
    end

    if kw == "potion" then
        return classID == Enum.ItemClass.Consumable and (subClassID == 1 or subClassID == 2 or subClassID == 3)
    end

    if kw == "food" then
        return classID == Enum.ItemClass.Consumable and subClassID == 5
    end

    if kw == "reagent" then
        return classID == Enum.ItemClass.Reagent
    end

    if kw == "tradegoods" or kw == "tradegood" then
        return classID == Enum.ItemClass.Tradegoods
    end

    if kw == "recipe" then
        return classID == Enum.ItemClass.Recipe
    end

    if kw == "gem" then
        return classID == Enum.ItemClass.Gem
    end

    if kw == "questitem" or kw == "quest" then
        return classID == Enum.ItemClass.Questitem
    end

    if kw == "container" or kw == "bag" then
        return classID == Enum.ItemClass.Container
    end

    if kw == "key" then
        return classID == Enum.ItemClass.Key
    end

    if kw == "miscellaneous" or kw == "misc" then
        return classID == Enum.ItemClass.Miscellaneous
    end

    if kw == "profession" or kw == "tradeskill" then
        return classID == Enum.ItemClass.Profession
    end

    if kw == "itemenhancement" or kw == "enhancement" then
        return classID == Enum.ItemClass.ItemEnhancement
    end

    if kw == "housing" then
        if Enum.ItemClass.Housing then
            return classID == Enum.ItemClass.Housing
        end
        return false
    end

    if kw == "cosmetic" then
        return classID == Enum.ItemClass.Armor and subClassID == 5
    end

    if kw == "hearthstone" then
        local HS_IDS = {
            [6948]=true,[64488]=true,[54452]=true,[93672]=true,[110560]=true,
            [140192]=true,[141605]=true,[162973]=true,[163045]=true,[165669]=true,
            [165670]=true,[165802]=true,[166746]=true,[166747]=true,[168907]=true,
            [172179]=true,[180290]=true,[182773]=true,[183716]=true,[184353]=true,
            [188952]=true,[190196]=true,[193588]=true,[200630]=true,[206195]=true,
            [208704]=true,[209035]=true,[210455]=true,[212337]=true,[228940]=true,
        }
        if HS_IDS[itemID] then return true end
        if C_ToyBox and C_ToyBox.GetToyInfo then
            local toyInfo = C_ToyBox.GetToyInfo(itemID)
            if toyInfo then
                local itemName = C_Item.GetItemNameByID(itemID)
                if itemName and itemName:lower():find("hearthstone") then return true end
            end
        end
        return false
    end

    if kw == "keystone" then
        return itemID == 180653 or itemID == 158923 or itemID == 138019
    end

    if kw == "unique" then
        if bagID and slotID then
            local tt = GetTooltipText(bagID, slotID)
            if tt:find(ITEM_UNIQUE or "Unique") then return true end
        end
        return false
    end

    if kw == "usable" then
        if IsUsableItem then
            local usable, noMana = IsUsableItem(itemID)
            return usable == true
        end
        return true
    end

    if kw == "unusable" then
        if IsUsableItem then
            local usable = IsUsableItem(itemID)
            return usable == false
        end
        return false
    end

    if kw == "equipmentset" or kw == "set" then
        local now = GetTime()
        if now - equipSetCacheTime > 5 then
            wipe(equipSetItemCache)
            equipSetCacheTime = now
            if C_EquipmentSet and C_EquipmentSet.GetEquipmentSetIDs then
                local setIDs = C_EquipmentSet.GetEquipmentSetIDs()
                if setIDs then
                    for _, setID in ipairs(setIDs) do
                        local ids = C_EquipmentSet.GetItemIDs(setID)
                        if ids then
                            for _, id in pairs(ids) do
                                if id and id > 0 then
                                    equipSetItemCache[id] = true
                                end
                            end
                        end
                    end
                end
            end
        end
        return equipSetItemCache[itemID] or false
    end

    if kw == "locked" then
        if bagID and slotID then
            local tt = GetTooltipText(bagID, slotID)
            if tt and tt:find(LOCKED or "Locked") then return true end
        end
        return false
    end

    if kw == "charges" then
        if bagID and slotID then
            local tt = GetTooltipText(bagID, slotID)
            if tt and tt:match("%d+ Charges?") then return true end
        end
        return false
    end

    local qualityLevel = QUALITY_MAP[kw]
    if qualityLevel then
        return quality == qualityLevel
    end

    local slotType = SLOT_MAP[kw]
    if slotType then
        return equipLoc == slotType
    end

    local armorSub = ARMOR_SUBCLASS_MAP[kw]
    if armorSub then
        return classID == Enum.ItemClass.Armor and subClassID == armorSub
    end

    local expID = EXPANSION_IDS[kw]
    if expID ~= nil then
        local itemExpID = itemInfo._expansionID
        return itemExpID == expID
    end

    return false
end

local function Tokenize(searchStr)
    local tokens = {}
    local i = 1
    local len = #searchStr

    while i <= len do
        local c = searchStr:sub(i, i)

        if c == "(" or c == ")" or c == "&" or c == "|" or c == "!" or c == "~" then
            tinsert(tokens, { type = "op", value = c })
            i = i + 1
        elseif c == "#" then
            local j = i + 1
            while j <= len do
                local ch = searchStr:sub(j, j)
                if ch == "(" or ch == ")" or ch == "&" or ch == "|" or ch == "!" or ch == "~" or ch == " " then
                    break
                end
                j = j + 1
            end
            local keyword = searchStr:sub(i + 1, j - 1)
            if keyword ~= "" then
                tinsert(tokens, { type = "keyword", value = keyword })
            end
            i = j
        elseif c == " " or c == "\t" then
            i = i + 1
        elseif c == ">" or c == "<" then
            local j = i + 1
            if j <= len and searchStr:sub(j, j) == "=" then j = j + 1 end
            while j <= len and searchStr:sub(j, j):match("%d") do j = j + 1 end
            tinsert(tokens, { type = "ilvl_compare", value = searchStr:sub(i, j - 1) })
            i = j
        elseif c:match("%d") then
            local j = i
            while j <= len and searchStr:sub(j, j):match("%d") do j = j + 1 end
            if j <= len and searchStr:sub(j, j) == "-" then
                local k = j + 1
                while k <= len and searchStr:sub(k, k):match("%d") do k = k + 1 end
                tinsert(tokens, { type = "ilvl_range", value = searchStr:sub(i, k - 1) })
                i = k
            else
                tinsert(tokens, { type = "ilvl_compare", value = searchStr:sub(i, j - 1) })
                i = j
            end
        else
            local j = i
            while j <= len do
                local ch = searchStr:sub(j, j)
                if ch == "(" or ch == ")" or ch == "&" or ch == "|" or ch == "!" or ch == "~" or ch == "#" or ch == " " then
                    break
                end
                j = j + 1
            end
            local text = searchStr:sub(i, j - 1)
            if text ~= "" then
                tinsert(tokens, { type = "text", value = text })
            end
            i = j
        end
    end

    return tokens
end

local ParseExpression, ParseAnd, ParseNot, ParsePrimary

ParseExpression = function(tokens, pos)
    local left, newPos = ParseAnd(tokens, pos)
    while newPos <= #tokens and tokens[newPos].type == "op" and tokens[newPos].value == "|" do
        newPos = newPos + 1
        local right
        right, newPos = ParseAnd(tokens, newPos)
        local captLeft, captRight = left, right
        left = function(itemID, bagID, slotID, itemInfo)
            return captLeft(itemID, bagID, slotID, itemInfo) or captRight(itemID, bagID, slotID, itemInfo)
        end
    end
    return left, newPos
end

ParseAnd = function(tokens, pos)
    local left, newPos = ParseNot(tokens, pos)
    while newPos <= #tokens and tokens[newPos].type == "op" and tokens[newPos].value == "&" do
        newPos = newPos + 1
        local right
        right, newPos = ParseNot(tokens, newPos)
        local captLeft, captRight = left, right
        left = function(itemID, bagID, slotID, itemInfo)
            return captLeft(itemID, bagID, slotID, itemInfo) and captRight(itemID, bagID, slotID, itemInfo)
        end
    end
    return left, newPos
end

ParseNot = function(tokens, pos)
    if pos <= #tokens and tokens[pos].type == "op" and (tokens[pos].value == "!" or tokens[pos].value == "~") then
        local inner, newPos = ParseNot(tokens, pos + 1)
        local captInner = inner
        return function(itemID, bagID, slotID, itemInfo)
            return not captInner(itemID, bagID, slotID, itemInfo)
        end, newPos
    end
    return ParsePrimary(tokens, pos)
end

ParsePrimary = function(tokens, pos)
    if pos > #tokens then
        return function() return false end, pos
    end

    local token = tokens[pos]

    if token.type == "op" and token.value == "(" then
        local inner, newPos = ParseExpression(tokens, pos + 1)
        if newPos <= #tokens and tokens[newPos].type == "op" and tokens[newPos].value == ")" then
            newPos = newPos + 1
        end
        return inner, newPos
    end

    if token.type == "keyword" then
        local kw = token.value
        return function(itemID, bagID, slotID, itemInfo)
            return CheckKeyword(kw, itemID, bagID, slotID, itemInfo)
        end, pos + 1
    end

    if token.type == "text" then
        local searchText = string.lower(token.value)
        return function(itemID, bagID, slotID, itemInfo)
            local itemName = C_Item.GetItemNameByID(itemID)
            if itemName and string.find(string.lower(itemName), searchText, 1, true) then
                return true
            end
            return false
        end, pos + 1
    end

    if token.type == "ilvl_compare" then
        local val = token.value
        local op, num
        if val:sub(1, 2) == ">=" then
            op = ">="
            num = tonumber(val:sub(3))
        elseif val:sub(1, 2) == "<=" then
            op = "<="
            num = tonumber(val:sub(3))
        elseif val:sub(1, 1) == ">" then
            op = ">"
            num = tonumber(val:sub(2))
        elseif val:sub(1, 1) == "<" then
            op = "<"
            num = tonumber(val:sub(2))
        else
            num = tonumber(val)
            op = "="
        end
        if not num then return function() return false end, pos + 1 end
        return function(itemID, bagID, slotID, itemInfo)
            local ilvl = itemInfo._ilvl or 0
            if op == ">=" then return ilvl >= num
            elseif op == "<=" then return ilvl <= num
            elseif op == ">" then return ilvl > num
            elseif op == "<" then return ilvl < num
            else return ilvl == num end
        end, pos + 1
    end

    if token.type == "ilvl_range" then
        local low, high = token.value:match("^(%d+)-(%d+)$")
        low, high = tonumber(low), tonumber(high)
        if not low or not high then return function() return false end, pos + 1 end
        return function(itemID, bagID, slotID, itemInfo)
            local ilvl = itemInfo._ilvl or 0
            return ilvl >= low and ilvl <= high
        end, pos + 1
    end

    return function() return false end, pos + 1
end

function SE:Compile(searchStr)
    if not searchStr or searchStr == "" then return nil end

    if compiledCache[searchStr] then
        return compiledCache[searchStr]
    end

    local tokens = Tokenize(searchStr)
    if #tokens == 0 then return nil end

    local checkFunc = ParseExpression(tokens, 1)
    compiledCache[searchStr] = checkFunc
    return checkFunc
end

function SE:CheckItem(searchStr, itemID, bagID, slotID, itemInfo)
    if not searchStr or searchStr == "" or not itemID then return false end

    local checkFunc = self:Compile(searchStr)
    if not checkFunc then return false end

    local enriched = itemInfo
    if not enriched._classID then
        enriched = SE:EnrichItemInfo(itemID, bagID, slotID, itemInfo)
    end

    return checkFunc(itemID, bagID, slotID, enriched)
end

function SE:EnrichItemInfo(itemID, bagID, slotID, itemInfo)
    if not itemInfo then itemInfo = {} end
    if itemInfo._enriched then return itemInfo end

    local hyperlink = itemInfo.hyperlink

    if hyperlink then
        local _, _, quality, ilvl, _, _, _, _, equipLoc, _, _, classID, subClassID, _, expacID = C_Item.GetItemInfo(hyperlink)
        itemInfo._classID = classID
        itemInfo._subClassID = subClassID
        itemInfo._equipLoc = equipLoc or ""
        itemInfo._ilvl = ilvl or 0
        itemInfo._expansionID = expacID

        if not quality and itemInfo.quality then
            quality = itemInfo.quality
        end
        if quality then
            itemInfo.quality = quality
        end
    else
        itemInfo._classID = nil
        itemInfo._subClassID = nil
        itemInfo._equipLoc = ""
        itemInfo._ilvl = 0
        itemInfo._expansionID = nil
    end

    if itemID == BATTLE_PET_CAGE_ID then
        itemInfo._classID = Enum.ItemClass.Battlepet
    end

    itemInfo._enriched = true
    return itemInfo
end

function SE:InvalidateCache()
    wipe(compiledCache)
    wipe(itemMatchCache)
    wipe(tooltipCache)
    wipe(equipSetItemCache)
    equipSetCacheTime = 0
end

function SE:InvalidateEquipSetCache()
    wipe(equipSetItemCache)
    equipSetCacheTime = 0
end

function SE:GetExpansionID(itemID, hyperlink)
    if not hyperlink then return nil end
    local _, _, _, _, _, _, _, _, _, _, _, _, _, _, expacID = C_Item.GetItemInfo(hyperlink)
    return expacID
end

function SE:GetExpansionName(expID)
    if not expID then return nil end
    return _G["EXPANSION_NAME" .. expID]
end

SE.BATTLE_PET_CAGE_ID = BATTLE_PET_CAGE_ID
