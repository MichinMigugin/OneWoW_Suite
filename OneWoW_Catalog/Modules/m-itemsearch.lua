local _, ns = ...

local pairs, ipairs = pairs, ipairs
local tinsert, sort, wipe = tinsert, sort, wipe
local C_Item, C_TradeSkillUI = C_Item, C_TradeSkillUI

ns.ItemSearch = {}
local ItemSearch = ns.ItemSearch

local TRADESKILL_PROFS = {
    "Alchemy", "Blacksmithing", "Cooking", "Enchanting", "Engineering",
    "Fishing", "Herbalism", "HousingDyes", "Inscription", "Jewelcrafting",
    "Leatherworking", "Mining", "Skinning", "Tailoring",
}

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
local function GetOwnedItems(shouldYield)
    local owned = {}
    local storageAPI = OneWoW_AltTracker_Storage_API
    if not storageAPI or not storageAPI.Gather then return owned end

    local YieldIfNeeded = OneWoW.ChunkedJob.YieldIfNeeded
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
        YieldIfNeeded(shouldYield)
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

ItemSearch.SOURCE_ADDON_BY_FILTER = {
    drops   = "OneWoW_CatalogData_Journal",
    vendors = "OneWoW_CatalogData_Vendors",
    crafted = "OneWoW_CatalogData_Tradeskills",
    quests  = "OneWoW_CatalogData_Quests",
    owned   = "OneWoW_AltTracker_Storage",
}

-- Fill `results` (array) from sources. `shouldYield` is optional; when provided
-- (ChunkedJob), YieldIfNeeded is called after each candidate so large walks
-- stay off the hitch path. When omitted / always-false, this is synchronous.
local function BuildQueryResults(self, searchTerm, sourceFilter, results, shouldYield)
    wipe(results)
    local yieldCheck = shouldYield or function() return false end
    local YieldIfNeeded = OneWoW.ChunkedJob.YieldIfNeeded

    -- A nil or <2 char term means "no text filter": browse every available source.
    -- An empty Lua pattern still matches every name via string.find(s, "", 1, true),
    -- so the source loops below work unchanged for the browse case.
    local hasFilter = searchTerm ~= nil and #searchTerm >= 2
    local term = hasFilter and searchTerm:lower() or ""
    local exactItemID = hasFilter and tonumber(searchTerm) or nil
    local resultMap = {}
    local count = 0

    -- Gate each source on its backing data actually being present so an unloaded
    -- source contributes nothing. "all" pulls from every available source; a
    -- specific filter pulls only from its own.
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
        YieldIfNeeded(yieldCheck)
    end

    if doJournal then
        -- The Journal store owns this index; it is offline (generated names plus
        -- extras names) so a text search still matches loot the client has never
        -- cached. Icon comes from Instant; the list row loader fills quality.
        for itemID, name in pairs(OneWoW_CatalogData_Journal_API.GetItemNameIndex()) do
            if name:lower():find(term, 1, true) then
                local _, _, _, _, icon = C_Item.GetItemInfoInstant(itemID)
                addOrAnnotate(itemID, name, icon, nil, "isJournal")
            end
            YieldIfNeeded(yieldCheck)
        end
    end

    -- Secondary sources: most itemIDs already exist from the journal walk.
    -- Annotate those without GetItemNameByID (that call was the post-26k stall).
    -- Browse (no text filter) can add unknowns with instant icon only; the list
    -- row loader fills the name asynchronously. Filtered walks still need a name.
    if doVendors then
        local vendorsAPI = OneWoW_CatalogData_Vendors_API
        local vendors = vendorsAPI and vendorsAPI.GetAllVendors()
        if vendors then
            for _, vendor in pairs(vendors) do
                if vendor.items then
                    for itemID in pairs(vendor.items) do
                        if resultMap[itemID] then
                            results[resultMap[itemID]].isVendor = true
                        elseif not hasFilter then
                            local _, _, _, _, icon = C_Item.GetItemInfoInstant(itemID)
                            addOrAnnotate(itemID, nil, icon, nil, "isVendor")
                        else
                            local itemName = C_Item.GetItemNameByID(itemID)
                            if itemName and itemName:lower():find(term, 1, true) then
                                addOrAnnotate(itemID, itemName, nil, nil, "isVendor")
                            end
                        end
                        YieldIfNeeded(yieldCheck)
                    end
                end
            end
        end
    end

    if doCrafted then
        for _, profName in ipairs(TRADESKILL_PROFS) do
            local data = _G["OneWoWTradeskills_" .. profName]
            if data and data.r then
                for _, recipe in pairs(data.r) do
                    local itemID = recipe.item
                    if itemID and itemID > 0 then
                        if resultMap[itemID] then
                            results[resultMap[itemID]].isCrafted = true
                        elseif not hasFilter then
                            local _, _, _, _, icon = C_Item.GetItemInfoInstant(itemID)
                            addOrAnnotate(itemID, nil, icon, nil, "isCrafted")
                        else
                            local itemName = C_Item.GetItemNameByID(itemID)
                            if itemName and itemName:lower():find(term, 1, true) then
                                addOrAnnotate(itemID, itemName, nil, nil, "isCrafted")
                            end
                        end
                    end
                    YieldIfNeeded(yieldCheck)
                end
            end
        end
    end

    if doQuest then
        local questAddon = OneWoW_CatalogData_Quests_API
        if questAddon then
            for _, itemID in ipairs(questAddon.GetRewardItemIDs(yieldCheck)) do
                if resultMap[itemID] then
                    results[resultMap[itemID]].isQuestReward = true
                elseif not hasFilter then
                    local _, _, _, _, icon = C_Item.GetItemInfoInstant(itemID)
                    addOrAnnotate(itemID, nil, icon, nil, "isQuestReward")
                else
                    local itemName = C_Item.GetItemNameByID(itemID)
                    if itemName and itemName:lower():find(term, 1, true) then
                        addOrAnnotate(itemID, itemName, nil, nil, "isQuestReward")
                    end
                end
                YieldIfNeeded(yieldCheck)
            end
        end
    end

    -- Force a slice boundary before Storage.Gather so the UI can paint journal
    -- results; Gather itself is still one sync call (no internal yield points).
    if shouldYield then
        coroutine.yield()
    end
    local ownedMap = GetOwnedItems(yieldCheck)

    if doOwned then
        for itemID, od in pairs(ownedMap) do
            if resultMap[itemID] then
                results[resultMap[itemID]].isOwned = true
            else
                -- Prefer the name persisted at scan time so owned items match offline;
                -- fall back to the live cache only when no stored name exists.
                local itemName = od.name or C_Item.GetItemNameByID(itemID)
                if not hasFilter or (itemName and itemName:lower():find(term, 1, true)) then
                    addOrAnnotate(itemID, itemName, nil, nil, "isOwned")
                end
            end
            YieldIfNeeded(yieldCheck)
        end
    end

    for _, entry in ipairs(results) do
        local od = ownedMap[entry.itemID]
        if od then
            entry.ownedCount = od.total
            entry.isOwned = true
        end
        YieldIfNeeded(yieldCheck)
    end

    OneWoW.ChunkedJob.Sort(results, function(a, b)
        if a.ownedCount > 0 and b.ownedCount == 0 then return true end
        if a.ownedCount == 0 and b.ownedCount > 0 then return false end
        return (a.name or "") < (b.name or "")
    end, shouldYield)
end

--- Synchronous query (small callers / tests). Prefer StartQuery for UI walks.
function ItemSearch:Query(searchTerm, sourceFilter)
    local results = {}
    BuildQueryResults(self, searchTerm, sourceFilter, results, nil)
    return results
end

function ItemSearch:CancelQuery()
    if self._queryJob then
        self._queryJob:Cancel()
        self._queryJob = nil
    end
end

--- Time-sliced query into `outResults` (mutated in place). Cancels any prior job.
---@param searchTerm string|nil
---@param sourceFilter string|nil
---@param outResults table
---@param opts table|nil { onProgress, onComplete, onCancel, finalize, budgetMs }
--- finalize(results, shouldYield) runs inside the job after the walk (e.g. favorites).
---@return table jobHandle
function ItemSearch:StartQuery(searchTerm, sourceFilter, outResults, opts)
    opts = opts or {}
    if type(outResults) ~= "table" then
        error("ItemSearch:StartQuery requires an outResults table", 2)
    end

    self:CancelQuery()
    wipe(outResults)

    local job
    job = OneWoW.ChunkedJob.Start({
        budgetMs = opts.budgetMs,
        run = function(shouldYield)
            BuildQueryResults(self, searchTerm, sourceFilter, outResults, shouldYield)
            if opts.finalize then
                opts.finalize(outResults, shouldYield)
            end
        end,
        onProgress = opts.onProgress,
        onComplete = function()
            if self._queryJob == job then
                self._queryJob = nil
            end
            if opts.onComplete then
                opts.onComplete(outResults)
            end
        end,
        onCancel = function()
            if self._queryJob == job then
                self._queryJob = nil
            end
            if opts.onCancel then
                opts.onCancel()
            end
        end,
    })
    self._queryJob = job
    return job
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

    if OneWoW_CatalogData_Journal_API then
        for _, drop in ipairs(OneWoW_CatalogData_Journal_API.GetItemDropLocations(itemID)) do
            tinsert(detail.drops, {
                instanceName  = drop.instanceName or "",
                encounterName = drop.encounterName,
                difficulties  = drop.difficulties,
            })
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
