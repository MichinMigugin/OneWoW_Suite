local _, ns = ...

local pairs, ipairs = pairs, ipairs
local tinsert, sort = tinsert, sort
local C_Item, C_TradeSkillUI = C_Item, C_TradeSkillUI

ns.ItemSearch = {}
local ItemSearch = ns.ItemSearch

local EXPANSION_NAMES = {
    "Classic", "BurningCrusade", "WrathoftheLichKing", "Cataclysm",
    "MistsofPandaria", "WarlordsofDraenor", "Legion", "BattleforAzeroth",
    "Shadowlands", "Dragonflight", "TheWarWithin", "Midnight",
}

local TRADESKILL_PROFS = {
    "Alchemy", "Blacksmithing", "Cooking", "Enchanting", "Engineering",
    "Fishing", "Herbalism", "HousingDyes", "Inscription", "Jewelcrafting",
    "Leatherworking", "Mining", "Skinning", "Tailoring",
}

local MAX_RESULTS = 200

local function GetRecipeKnownByFromAltTracker(itemID)
    local profsAPI = OneWoW_AltTracker_Professions_API
    if not profsAPI then return nil end
    local profChars = profsAPI.GetAllCharacters()

    local recipeItemMap = profsAPI.GetRecipeItemMap()
    local recipeSpellID
    if recipeItemMap and recipeItemMap[itemID] then
        recipeSpellID = recipeItemMap[itemID]
    end

    if not recipeSpellID then
        local _, spellID = C_Item.GetItemSpell(itemID)
        if spellID then recipeSpellID = spellID end
    end

    local knownBy = {}
    local seen = {}

    if recipeSpellID then
        for charKey, charData in pairs(profChars) do
            if charData.recipes then
                for _, recipeSet in pairs(charData.recipes) do
                    if recipeSet[recipeSpellID] and not seen[charKey] then
                        seen[charKey] = true
                        tinsert(knownBy, charKey)
                    end
                end
            end
        end
    end

    if #knownBy == 0 then
        local itemName = C_Item.GetItemNameByID(itemID)
        if itemName then
            local craftedName = itemName:match("^%S+:%s*(.+)$") or itemName
            for charKey, charData in pairs(profChars) do
                if charData.recipes and not seen[charKey] then
                    for _, recipeSet in pairs(charData.recipes) do
                        for storedID in pairs(recipeSet) do
                            local info = C_TradeSkillUI.GetRecipeInfo(storedID)
                            if info and info.name == craftedName then
                                profsAPI.SetRecipeItemMapEntry(itemID, storedID)
                                if not seen[charKey] then
                                    seen[charKey] = true
                                    tinsert(knownBy, charKey)
                                end
                                break
                            end
                        end
                        if seen[charKey] then break end
                    end
                end
            end
        end
    end

    sort(knownBy)
    return knownBy
end

-- The localized item name is embedded in every hyperlink's "[Name]" segment, so
-- it can be recovered offline without touching the live item cache.
local function NameFromLink(itemLink)
    if type(itemLink) ~= "string" then return nil end
    return itemLink:match("%[(.-)%]")
end

-- Storage location type -> the locLabel key the item-search UI displays. The
-- Storage Query layer emits "auction"; the UI's label map uses "ah". Types not
-- listed here (bags/bank/mail/guild) pass through unchanged.
local LOC_TYPE_TO_LABEL = {
    auction = "ah",
}

-- Owned-item rollup for the search + detail views. Rather than re-walking every
-- container by hand, this reuses the shared Storage Query layer (the same
-- Gather + normalization the AltTracker Items/Bank tabs use) so the traversal
-- lives in exactly one place. We only aggregate the normalized instances by
-- itemID into the { total, name, locations } shape those views expect.
local function GetOwnedItems()
    local owned = {}
    local storageAPI = OneWoW_AltTracker_Storage_API
    if not storageAPI or not storageAPI.Gather then return owned end

    local instances = storageAPI.Gather({
        chars = "all",
        containers = { bags = true, personal = true, warband = true, guild = true, mail = true, auction = true },
    })

    for _, inst in ipairs(instances) do
        local itemID = inst.itemID
        if itemID then
            local where = inst.where or {}
            local locType = where.type
            local locLabel = LOC_TYPE_TO_LABEL[locType] or locType

            -- Account/guild containers don't carry a per-character name; keep the
            -- same display strings the previous hand-walk produced.
            local charName
            if locType == "warband" then
                charName = "Warband"
            elseif locType == "guild" then
                charName = where.guildName
            else
                charName = where.charName
            end

            local count = inst.count or 1
            local rec = owned[itemID]
            if not rec then
                rec = { total = 0, locations = {} }
                owned[itemID] = rec
            end
            rec.total = rec.total + count

            -- Name is used for offline owned-search matching. MakeInstance carries
            -- the stored itemName; fall back to the link's "[Name]" like before.
            if not rec.name then
                local name = inst.name or NameFromLink(inst.itemLink)
                if name and name ~= "" then
                    rec.name = name
                end
            end

            tinsert(rec.locations, { charName = charName, locLabel = locLabel, count = count })
        end
    end

    return owned
end

-- Per-filter data availability. "all" is always available (the tab-level
-- placeholder covers the no-sources case); every other filter maps to the data
-- it reads. Shared by Query (source gating) and the UI (button enable state) so
-- the two can never drift. The Owned source depends on Storage (GetOwnedItems
-- early-returns without it).
local SOURCE_AVAILABILITY = {
    all     = function() return true end,
    drops   = function() return OneWoW_CatalogData_Journal_API ~= nil end,
    vendors = function() return OneWoW_CatalogData_Vendors_API ~= nil end,
    crafted = function() return OneWoW_CatalogData_Tradeskills_API ~= nil end,
    owned   = function() return OneWoW_AltTracker_Storage_API ~= nil end,
    quests  = function() return OneWoW_CatalogData_Quests_API ~= nil end,
}

function ItemSearch:IsSourceAvailable(sourceKey)
    local fn = SOURCE_AVAILABILITY[sourceKey]
    if not fn then return true end
    return fn() and true or false
end

-- The backing data addons this tab aggregates. Single source of truth: reused
-- for the tab's `requiresAnyAddon` gate (OneWoW_Catalog.lua) and for the
-- data-ready watchers that refresh the source buttons (t-itemsearch.lua).
ItemSearch.SOURCE_ADDONS = {
    "OneWoW_CatalogData_Journal",
    "OneWoW_CatalogData_Vendors",
    "OneWoW_CatalogData_Tradeskills",
    "OneWoW_CatalogData_Quests",
    "OneWoW_AltTracker_Storage",
}

function ItemSearch:Query(searchTerm, sourceFilter)
    -- A nil or <2 char term means "no text filter": browse every available source.
    -- An empty Lua pattern still matches every name via string.find(s, "", 1, true),
    -- so the source loops below work unchanged for the browse case.
    local hasFilter = searchTerm ~= nil and #searchTerm >= 2
    local term = hasFilter and searchTerm:lower() or ""
    local exactItemID = hasFilter and tonumber(searchTerm) or nil
    local results = {}
    local resultMap = {}
    local count = 0
    local limitReached = false

    -- Gate each source on its backing data actually being present so an unloaded
    -- source contributes nothing and never consumes the result cap. "all" pulls
    -- from every available source; a specific filter pulls only from its own.
    local doJournal = (sourceFilter == "all" or sourceFilter == "drops")   and self:IsSourceAvailable("drops")
    local doVendors = (sourceFilter == "all" or sourceFilter == "vendors") and self:IsSourceAvailable("vendors")
    local doCrafted = (sourceFilter == "all" or sourceFilter == "crafted") and self:IsSourceAvailable("crafted")
    local doOwned   = (sourceFilter == "all" or sourceFilter == "owned")   and self:IsSourceAvailable("owned")
    local doQuest   = (sourceFilter == "all" or sourceFilter == "quests")  and self:IsSourceAvailable("quests")

    local function addOrAnnotate(itemID, name, icon, quality, sourceKey)
        if resultMap[itemID] then
            results[resultMap[itemID]][sourceKey] = true
            return
        end
        if count >= MAX_RESULTS then
            limitReached = true
            return
        end
        count = count + 1
        local entry = {
            itemID    = itemID,
            name      = name,
            icon      = icon,
            quality   = quality or 1,
            ownedCount = 0,
            isJournal = false,
            isVendor  = false,
            isCrafted = false,
            isOwned   = false,
            isQuestReward = false,
            isExactMatch  = false,
        }
        entry[sourceKey] = true
        results[count] = entry
        resultMap[itemID] = count
    end

    if exactItemID then
        local sourceKey = "isQuestReward"
        if sourceFilter == "drops" then
            sourceKey = "isJournal"
        elseif sourceFilter == "vendors" then
            sourceKey = "isVendor"
        elseif sourceFilter == "crafted" then
            sourceKey = "isCrafted"
        elseif sourceFilter == "owned" then
            sourceKey = "isOwned"
        end

        local exactName = C_Item.GetItemNameByID(exactItemID)
        local _, _, _, _, exactIcon = C_Item.GetItemInfoInstant(exactItemID)
        addOrAnnotate(exactItemID, exactName, exactIcon, nil, sourceKey)
        if resultMap[exactItemID] then
            results[resultMap[exactItemID]].isExactMatch = true
        end
    end

    if doJournal then
        for _, expName in ipairs(EXPANSION_NAMES) do
            local items = _G["OneWoWItems_" .. expName]
            if items then
                for itemID, idata in pairs(items) do
                    if idata.name and idata.name:lower():find(term, 1, true) then
                        addOrAnnotate(itemID, idata.name, idata.icon, idata.quality, "isJournal")
                        if limitReached then break end
                    end
                end
            end
            if limitReached then break end
        end
    end

    if doVendors and not limitReached then
        local vendorsAPI = OneWoW_CatalogData_Vendors_API
        local vendors = vendorsAPI and vendorsAPI.GetAllVendors()
        if vendors then
            for _, vendor in pairs(vendors) do
                if vendor.items then
                    for itemID in pairs(vendor.items) do
                        local itemName = C_Item.GetItemNameByID(itemID)
                        if itemName and itemName:lower():find(term, 1, true) then
                            addOrAnnotate(itemID, itemName, nil, nil, "isVendor")
                            if limitReached then break end
                        end
                    end
                end
                if limitReached then break end
            end
        end
    end

    if doCrafted and not limitReached then
        for _, profName in ipairs(TRADESKILL_PROFS) do
            local data = _G["OneWoWTradeskills_" .. profName]
            if data and data.r then
                for _, recipe in pairs(data.r) do
                    if recipe.item and recipe.item > 0 then
                        local itemName = C_Item.GetItemNameByID(recipe.item)
                        if itemName and itemName:lower():find(term, 1, true) then
                            addOrAnnotate(recipe.item, itemName, nil, nil, "isCrafted")
                            if limitReached then break end
                        end
                    end
                end
            end
            if limitReached then break end
        end
    end

    if doQuest and not limitReached then
        local questAddon = OneWoW_CatalogData_Quests_API
        if questAddon then
            for _, itemID in ipairs(questAddon.GetRewardItemIDs()) do
                local itemName = C_Item.GetItemNameByID(itemID)
                if itemName and itemName:lower():find(term, 1, true) then
                    addOrAnnotate(itemID, itemName, nil, nil, "isQuestReward")
                    if limitReached then break end
                end
            end
        end
    end

    local ownedMap = GetOwnedItems()

    if doOwned and not limitReached then
        for itemID, od in pairs(ownedMap) do
            -- Prefer the name persisted at scan time so owned items match offline;
            -- fall back to the live cache only when no stored name exists.
            local itemName = od.name or C_Item.GetItemNameByID(itemID)
            if itemName and itemName:lower():find(term, 1, true) then
                addOrAnnotate(itemID, itemName, nil, nil, "isOwned")
                if limitReached then break end
            end
        end
    end

    for _, entry in ipairs(results) do
        local od = ownedMap[entry.itemID]
        if od then
            entry.ownedCount = od.total
            entry.isOwned = true
        end
    end

    sort(results, function(a, b)
        if a.ownedCount > 0 and b.ownedCount == 0 then return true end
        if a.ownedCount == 0 and b.ownedCount > 0 then return false end
        return (a.name or "") < (b.name or "")
    end)

    return results, limitReached
end

function ItemSearch:GetDetail(itemID)
    local isRecipe = OneWoW.PredicateEngine:IsRecipeItem(itemID)

    local detail = {
        drops        = {},
        vendors      = {},
        crafted      = {},
        owned        = {},
        questRewards = {},
        isRecipe     = isRecipe,
        recipeKnownBy = isRecipe and GetRecipeKnownByFromAltTracker(itemID) or nil,
    }

    for _, expName in ipairs(EXPANSION_NAMES) do
        local items      = _G["OneWoWItems_"      .. expName]
        local instances  = _G["OneWoWInstances_"  .. expName]
        local encounters = _G["OneWoWEncounters_" .. expName]

        if items and items[itemID] and instances and encounters then
            local idata = items[itemID]
            if idata.locations then
                for _, loc in ipairs(idata.locations) do
                    local instInfo = loc.instanceID and instances[loc.instanceID]
                    local instName = instInfo and instInfo.name or ""
                    local encName
                    if loc.encounterID and loc.encounterID ~= 0 then
                        local encInfo = encounters[loc.encounterID]
                        encName = encInfo and encInfo.name
                    end
                    tinsert(detail.drops, {
                        instanceName  = instName,
                        encounterName = encName,
                        difficulties  = loc.difficulties,
                    })
                end
            end
        end
    end

    local vendorsAPI = OneWoW_CatalogData_Vendors_API
    local sellingVendors = vendorsAPI and vendorsAPI.GetVendorsByItem(itemID)
    if sellingVendors then
        for _, vendor in ipairs(sellingVendors) do
            local mapID, loc
            if vendor.locations then
                for mID, l in pairs(vendor.locations) do
                    mapID = mID
                    loc = l
                    break
                end
            end
            local itemEntry = vendor.items and vendor.items[itemID]
            tinsert(detail.vendors, {
                name  = vendor.name,
                npcID = vendor.npcID,
                zone  = loc and loc.zone,
                mapID = mapID,
                cost  = itemEntry and itemEntry.cost,
            })
        end
    end

    for _, profName in ipairs(TRADESKILL_PROFS) do
        local data = _G["OneWoWTradeskills_" .. profName]
        if data and data.r then
            for recipeID, recipe in pairs(data.r) do
                if recipe.item == itemID then
                    local knownBy
                    local tsAddon = OneWoW_CatalogData_Tradeskills_API
                    if tsAddon then
                        knownBy = tsAddon.GetRecipeKnownBy(recipeID)
                    end
                    tinsert(detail.crafted, {
                        recipeID  = recipeID,
                        profName  = recipe.prof or profName,
                        expansion = recipe.exp,
                        knownBy   = knownBy,
                    })
                end
            end
        end
    end

    local ownedMap = GetOwnedItems()
    local od = ownedMap[itemID]
    if od then
        local byCharLoc = {}
        for _, loc in ipairs(od.locations) do
            local key = loc.charName .. "|" .. loc.locLabel
            if not byCharLoc[key] then
                byCharLoc[key] = { charName = loc.charName, locLabel = loc.locLabel, count = 0 }
                tinsert(detail.owned, byCharLoc[key])
            end
            byCharLoc[key].count = byCharLoc[key].count + loc.count
        end
    end

    local questAddon = OneWoW_CatalogData_Quests_API
    if questAddon then
        local questIDs = questAddon.GetQuestsRewardingItem(itemID)
        if questIDs then
            for _, questID in ipairs(questIDs) do
                local q = questAddon.GetQuest(questID)
                tinsert(detail.questRewards, { questID = questID, questName = q and q.name })
            end
        end
    end

    return detail
end
