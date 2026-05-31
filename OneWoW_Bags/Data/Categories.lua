local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local L = OneWoW_Bags.L
local PE = OneWoW_GUI.PredicateEngine
local BagTypes = OneWoW_Bags.BagTypes
local Constants = OneWoW_Bags.Constants

local tinsert, sort, wipe = tinsert, sort, wipe
local ipairs, pairs = ipairs, pairs
local type, time, tostring = type, time, tostring
local strfind = string.find
local C_Item = C_Item
local C_Container = C_Container
local C_NewItems = C_NewItems

OneWoW_Bags.Categories = {}
local Categories = OneWoW_Bags.Categories

-- BumpProfileCounter
-- Increments a marker-style profile counter and, if a current refresh
-- reason has been published by FlushPendingLayoutRefreshes, increments a
-- ".reason.<reason>" sibling counter as well. Lets the dump show both the
-- aggregate hit/miss numbers and the pass-1/pass-2 split without doubling
-- the call sites.
local function BumpProfileCounter(Profile, name)
    if not Profile then return end
    Profile:Start(name)
    Profile:Stop(name)
    local reason = OneWoW_Bags._currentRefreshReason
    if reason then
        local suffixed = name .. ".reason." .. reason
        Profile:Start(suffixed)
        Profile:Stop(suffixed)
    end
end

local CATEGORY_DEFINITIONS = {
    { name = "1W Junk",          priority = 1},
    { name = "1W Upgrades",      priority = 1},
    { name = "Recent Items",     priority = 1},
    { name = "Hearthstone",      priority = 2,   search = "#hearthstone",     searchOrder = 2  },
    { name = "Keystone",         priority = 3,   search = "#keystone",        searchOrder = 8  },
    { name = "Potions",          priority = 4,   search = "#potion",          searchOrder = 9  },
    { name = "Food",             priority = 5,   search = "#food",            searchOrder = 10 },
    { name = "Consumables",      priority = 6,   search = "#consumable",      searchOrder = 16 },
    { name = "Quest Items",      priority = 7,   search = "#quest",           searchOrder = 13 },
    { name = "Equipment Sets",   priority = 8,   search = "#set",             searchOrder = 3  },
    { name = "Weapons",          priority = 9,   search = "#weapon",          searchOrder = 14 },
    { name = "Armor",            priority = 10,  search = "#armor & #gear",   searchOrder = 15 },
    { name = "Mats",             priority = 10.5, search = "#craftingreagent", searchOrder = 10 },
    { name = "Reagents",         priority = 11,  search = "#reagent & !#craftingreagent", searchOrder = 11 },
    { name = "Trade Goods",      priority = 12,  search = "#tradegoods",      searchOrder = 20 },
    { name = "Tradeskill",       priority = 13,  search = "#tradeskill",      searchOrder = 22 },
    { name = "Recipes",          priority = 14,  search = "#recipe",          searchOrder = 21 },
    { name = "Housing",          priority = 15,  search = "#housing",         searchOrder = 1  },
    { name = "Gems",             priority = 16,  search = "#gem",             searchOrder = 17 },
    { name = "Item Enhancement", priority = 17,  search = "#enhancement",     searchOrder = 18 },
    { name = "Containers",       priority = 18,  search = "#container",       searchOrder = 19 },
    { name = "Keys",             priority = 19,  search = "#key",             searchOrder = 7  },
    { name = "Miscellaneous",    priority = 20,  search = "#misc & !#gear",   searchOrder = 6  },
    { name = "Battle Pets",      priority = 21,  search = "#battlepet",       searchOrder = 12 },
    { name = "Toys",             priority = 22,  search = "#toy",             searchOrder = 5  },
    { name = "Junk",             priority = 90,  search = "#poor",            searchOrder = 4  },
    { name = "Other",            priority = 98  },
    { name = "Empty",            priority = 99  },
}

local CATEGORY_DEFAULT_ORDER = {}
for _, def in ipairs(CATEGORY_DEFINITIONS) do
    CATEGORY_DEFAULT_ORDER[def.name] = def.priority
end

local SEARCH_CATEGORIES = {}
for _, def in ipairs(CATEGORY_DEFINITIONS) do
    if def.search and def.searchOrder then
        tinsert(SEARCH_CATEGORIES, def)
    end
end
sort(SEARCH_CATEGORIES, function(a, b) return a.searchOrder < b.searchOrder end)

local recentItems = {}
local recentItemDuration = 120
local recentExpiryTicker = nil

local customCategoriesV2 = {}

-- Precomputed mirror of customCategoriesV2 with slot-invariant fields baked
-- in (filterMode, lowercased itemType/itemSubType, needsExpand flag). Rebuilt
-- whenever customCategoriesV2 mutates so the per-slot
-- CollectCustomPredicateCandidates loop can skip a lot of repeat work.
local precomputedCustomCands = {}

-- Category display name -> 1-based rank from sectionOrder + section.categories.
-- Rebuilt on InvalidateCache so assignment ties follow Category Manager list order.
local categoryListOrderMap = {}
local UNMAPPED_LIST_RANK = 999999

-- C_Item.GetItemClassInfo / GetItemSubClassInfo return localized strings that
-- are stable for the entire session. Cache the lowercased forms so type-mode
-- custom categories don't pay the Blizzard API + :lower() cost per slot.
local classNameLowerCache = {}
local subClassNameLowerCache = {}

-- Two-tier category cache:
--   categoryCache:     slot-keyed final result (per-slot overlays applied).
--                      Hot path for repeat lookups of the same slot.
--   baseCategoryCache: identity+containerType-keyed pre-overlay result. Lets
--                      every slot holding the same item identity skip the
--                      manual-pin / junk / custom-predicate / SEARCH_CATEGORIES
--                      pipeline after the first lookup in that containerType.
local categoryCache = {}
local baseCategoryCache = {}

local function GetDB()
    return OneWoW_Bags:GetDB()
end

local SLOT_NORMALIZE = {
    ["INVTYPE_ROBE"] = "INVTYPE_CHEST",
    ["INVTYPE_RANGEDRIGHT"] = "INVTYPE_RANGED",
}

local function GetSlotCategoryName(equipLoc)
    if not equipLoc or equipLoc == "" then return nil end
    local normalized = SLOT_NORMALIZE[equipLoc] or equipLoc
    local displayName = _G[normalized]
    if displayName and displayName ~= "" then
        return displayName
    end
    return nil
end

local function InferFilterMode(categoryData)
    local fm = categoryData.filterMode
    if fm then return fm end
    if categoryData.searchExpression and categoryData.searchExpression ~= "" then
        return "search"
    end
    return "type"
end

-- True iff the expression references a saved search via SAVED(name). Lets the
-- per-slot loop skip SavedSearches:Expand entirely for expressions that have
-- nothing to expand (the common case for inline expressions).
local function NeedsSavedExpand(expression)
    return type(expression) == "string" and strfind(expression, "SAVED(", 1, true) ~= nil
end

-- Cache C_Item.GetItemClassInfo(classID):lower(). The returned string is a
-- localized name that is stable for the entire session, so the first lookup
-- per classID is the only one that pays the Blizzard API cost. Cached `false`
-- is used to memoize "no name available" so we don't retry every slot.
local function GetClassNameLower(classID)
    if classID == nil then return nil end
    local cached = classNameLowerCache[classID]
    if cached ~= nil then return cached or nil end
    local name = C_Item.GetItemClassInfo(classID)
    classNameLowerCache[classID] = name and name:lower() or false
    return classNameLowerCache[classID] or nil
end

local function GetSubClassNameLower(classID, subClassID)
    if classID == nil or subClassID == nil then return nil end
    local subCache = subClassNameLowerCache[classID]
    if not subCache then
        subCache = {}
        subClassNameLowerCache[classID] = subCache
    end
    local cached = subCache[subClassID]
    if cached ~= nil then return cached or nil end
    local name = C_Item.GetItemSubClassInfo(classID, subClassID)
    subCache[subClassID] = name and name:lower() or false
    return subCache[subClassID] or nil
end

-- Rebuild the precomputed mirror of customCategoriesV2 with slot-invariant
-- fields baked in. Called whenever custom categories mutate (Set, Create,
-- Delete, field edits). Per-slot CollectCustomPredicateCandidates iterates
-- this array instead of the raw map so it doesn't have to recompute
-- InferFilterMode, :lower(), or needsExpand on every slot.
local function RebuildCustomCandsArray()
    wipe(precomputedCustomCands)
    for categoryId, categoryData in pairs(customCategoriesV2) do
        if categoryData.name then
            local fm = InferFilterMode(categoryData)
            local entry = {
                categoryId   = categoryId,
                categoryData = categoryData,
                name         = categoryData.name,
                filterMode   = fm,
            }
            if fm == "search" then
                local expr = categoryData.searchExpression
                if type(expr) == "string" and expr ~= "" then
                    entry.expression  = expr
                    entry.needsExpand = NeedsSavedExpand(expr)
                end
            else
                local hasType    = categoryData.itemType and categoryData.itemType ~= ""
                local hasSubType = categoryData.itemSubType and categoryData.itemSubType ~= ""
                if hasType or hasSubType then
                    entry.hasType          = hasType or false
                    entry.hasSubType       = hasSubType or false
                    entry.lowerItemType    = hasType and categoryData.itemType:lower() or nil
                    entry.lowerItemSubType = hasSubType and categoryData.itemSubType:lower() or nil
                    entry.typeMatchMode    = categoryData.typeMatchMode
                end
            end
            tinsert(precomputedCustomCands, entry)
        end
    end
end

local function AssignListRank(map, name, rank)
    if name and name ~= "" and not map[name] then
        map[name] = rank
        return rank + 1
    end
    return rank
end

-- Walk sectionOrder + categories[], then legacy/fallback sources for unlisted names.
local function RebuildCategoryListOrderMap(g)
    wipe(categoryListOrderMap)
    local rank = 1

    if g.sectionOrder and g.categorySections then
        for _, sid in ipairs(g.sectionOrder) do
            local sec = g.categorySections[sid]
            if sec and sec.categories then
                for _, nm in ipairs(sec.categories) do
                    rank = AssignListRank(categoryListOrderMap, nm, rank)
                end
            end
        end
    end

    local displayOrder = g.displayOrder
    if displayOrder and #displayOrder > 0 then
        for _, entry in ipairs(displayOrder) do
            if entry ~= "----" and entry ~= "section_end" and not entry:find("^section:") then
                rank = AssignListRank(categoryListOrderMap, entry, rank)
            end
        end
    end

    local customRows = {}
    for _, catData in pairs(customCategoriesV2) do
        local nm = catData.name
        if nm and nm ~= "" and not categoryListOrderMap[nm] then
            tinsert(customRows, { name = nm, sortOrder = catData.sortOrder or 0 })
        end
    end
    sort(customRows, function(a, b)
        if a.sortOrder ~= b.sortOrder then
            return a.sortOrder < b.sortOrder
        end
        return a.name < b.name
    end)
    for _, row in ipairs(customRows) do
        rank = AssignListRank(categoryListOrderMap, row.name, rank)
    end

    for _, def in ipairs(SEARCH_CATEGORIES) do
        rank = AssignListRank(categoryListOrderMap, def.name, rank)
    end

    local catOrder = g.categoryOrder
    if catOrder and #catOrder > 0 then
        for _, nm in ipairs(catOrder) do
            rank = AssignListRank(categoryListOrderMap, nm, rank)
        end
    end
end

local function CategoryListOrderIndex(catName)
    return categoryListOrderMap[catName] or UNMAPPED_LIST_RANK
end

local function InvalidateCache()
    wipe(categoryCache)
    wipe(baseCategoryCache)
    RebuildCustomCandsArray()
    RebuildCategoryListOrderMap(GetDB().global)
end

local ALWAYS_APPLY = { ["Other"] = true, ["Empty"] = true }

local function CategoryAppliesTo(catName, containerType, catMods)
    if not containerType then return true end
    if ALWAYS_APPLY[catName] then return true end
    local mod = catMods[catName]
    if mod and mod.appliesIn then
        if mod.appliesIn[containerType] == false then return false end
    end
    return true
end

local function ModPriority(db, catName)
    local mod = db.global.categoryModifications[catName]
    if mod and mod.priority then
        return mod.priority
    end
    return 0
end

local function SectionOrderIndexForCategory(g, catName)
    if not g.sectionOrder or not g.categorySections then
        return 999
    end
    local order = g.sectionOrder
    for i, sid in ipairs(order) do
        local sec = g.categorySections[sid]
        if sec and sec.categories then
            for _, nm in ipairs(sec.categories) do
                if nm == catName then
                    return i
                end
            end
        end
    end
    return #order + 1
end

local function CandidateBeats(a, b, db, g)
    local pa, pb = ModPriority(db, a.name), ModPriority(db, b.name)
    if pa ~= pb then
        return pa > pb
    end
    local ac, bc = a.isCustom, b.isCustom
    if ac ~= bc then
        return ac == true
    end
    local da = a.defaultOrder or 9999
    local db2 = b.defaultOrder or 9999
    if da ~= db2 then
        return da < db2
    end
    local sa, sb = SectionOrderIndexForCategory(g, a.name), SectionOrderIndexForCategory(g, b.name)
    if sa ~= sb then
        return sa < sb
    end
    local la = CategoryListOrderIndex(a.name)
    local lb = CategoryListOrderIndex(b.name)
    if la ~= lb then
        return la < lb
    end
    local oa = a.searchOrder or 9999
    local ob = b.searchOrder or 9999
    if oa ~= ob then
        return oa < ob
    end
    return a.name < b.name
end

local function PickBestCandidate(cands, db, g)
    if not cands or #cands == 0 then
        return nil
    end
    local best = cands[1]
    for i = 2, #cands do
        if CandidateBeats(cands[i], best, db, g) then
            best = cands[i]
        end
    end
    return best
end

local function CollectManualCategoryCandidates(itemID, db, disabled, showPinnedWhenDisabled)
    local idstr = tostring(itemID)
    local cands = {}
    for categoryId, categoryData in pairs(customCategoriesV2) do
        if categoryData.enabled ~= false and categoryData.name and categoryData.items then
            local it = categoryData.items
            if it[idstr] or it[itemID] then
                tinsert(cands, { name = categoryData.name, tieKey = "c:" .. categoryId })
            end
        end
    end
    local catMods = db.global.categoryModifications
    for catName, mod in pairs(catMods) do
        if mod.addedItems and mod.addedItems[idstr] then
            tinsert(cands, { name = catName, tieKey = "b:" .. catName })
        end
    end
    if #cands == 0 then
        return cands
    end
    if not showPinnedWhenDisabled then
        local filtered = {}
        for _, c in ipairs(cands) do
            if not disabled[c.name] then
                tinsert(filtered, c)
            end
        end
        return filtered
    end
    return cands
end

local function ResolveManualCategoryName(itemID, db, disabled, containerType)
    local showPinned = db.global.pinnedCategoryShowsWhenDisabled
    local cands = CollectManualCategoryCandidates(itemID, db, disabled, showPinned)
    if #cands == 0 then
        return nil
    end
    if containerType then
        local catMods = db.global.categoryModifications
        local filtered = {}
        for _, c in ipairs(cands) do
            if CategoryAppliesTo(c.name, containerType, catMods) then
                tinsert(filtered, c)
            end
        end
        cands = filtered
    end
    if #cands == 0 then
        return nil
    end
    local best = PickBestCandidate(cands, db, db.global)
    return best and best.name or nil
end

local function CollectCustomPredicateCandidates(itemID, bagID, slotID, itemInfo, disabled, cands)
    local SavedSearches = OneWoW_Bags.SavedSearches
    for i = 1, #precomputedCustomCands do
        local entry = precomputedCustomCands[i]
        local categoryData = entry.categoryData

        -- Cheap gates first: category-disabled (live ref, no rebuild required
        -- when toggled) and user-disabled (per-pass parameter). These short-
        -- circuit before any predicate evaluation or Blizzard API call.
        if categoryData.enabled ~= false and not disabled[entry.name] then
            if entry.filterMode == "search" then
                local expr = entry.expression
                if expr then
                    if entry.needsExpand and SavedSearches then
                        expr = SavedSearches:Expand(expr)
                    end
                    if PE:CheckItem(expr, itemID, bagID, slotID, itemInfo or {}) then
                        tinsert(cands, { name = entry.name, tieKey = entry.categoryId, isCustom = true })
                    end
                end
            elseif entry.hasType or entry.hasSubType then
                local props = PE:BuildProps(itemID, bagID, slotID, itemInfo)
                local classID, subClassID = props.classID, props.subClassID
                local typeMatch    = not entry.hasType
                local subTypeMatch = not entry.hasSubType
                if entry.hasType and classID ~= nil then
                    local cn = GetClassNameLower(classID)
                    typeMatch = cn ~= nil and cn == entry.lowerItemType
                end
                if entry.hasSubType and classID ~= nil and subClassID ~= nil then
                    local scn = GetSubClassNameLower(classID, subClassID)
                    subTypeMatch = scn ~= nil and scn == entry.lowerItemSubType
                end
                local matched
                if entry.hasType and entry.hasSubType then
                    if entry.typeMatchMode == "or" then
                        matched = typeMatch or subTypeMatch
                    else
                        matched = typeMatch and subTypeMatch
                    end
                elseif entry.hasType then
                    matched = typeMatch
                else
                    matched = subTypeMatch
                end
                if matched then
                    tinsert(cands, { name = entry.name, tieKey = entry.categoryId, isCustom = true })
                end
            end
        end
    end
end

-- ResolveBaseCategory
-- Identity-tier resolver for an item's display category. Runs the
-- classification pipeline (manual pin -> 1W Junk -> custom predicates ->
-- SEARCH_CATEGORIES -> inventory-slot reclassification) and caches the
-- final pre-overlay result keyed by item identity + containerType.
--
-- containerType is part of the key so per-container `appliesIn` filtering can
-- still pick a different "best" candidate per bank type without cross-
-- contaminating the cache. For the dominant case (one bank open at a time),
-- this stays O(unique items) instead of O(slots).
--
-- Slot context (bagID, slotID) is passed to PE:BuildProps / PE:CheckItem so
-- the lazy tooltip resolver can read the bag tooltip (via
-- C_TooltipInfo.GetBagItem) instead of the hyperlink tooltip (via
-- C_TooltipInfo.GetHyperlink). The bag tooltip carries contextual lines like
-- "<Right Click to Open>", "Already Known", and tradeable-loot timers that
-- the hyperlink tooltip omits, so tooltip-text predicates (#openable,
-- #alreadyknown, #tradeableloot, tooltip~"...") behave identically to the
-- search bar. The verdict is still cached by identity + containerType: for
-- any stack of the same item identity in the same container, every slot's
-- bag tooltip body is identical, so the predicate sweep is identity-invariant
-- and the cached verdict is correct for the remaining slots.
--
-- Slot-dependent categories (1W Upgrades, Recent Items) live in
-- GetItemCategory's overlay block and never enter this cache.
-- Returns (category, tentative). `tentative` is true when the verdict was
-- computed against partial data (item info still streaming, or tooltip data
-- not yet available). Callers should NOT persist tentative results in any
-- cache, so the next refresh re-evaluates with full data.
local function ResolveBaseCategory(itemID, hyperlink, containerType, itemInfo, bagID, slotID)
    local db = GetDB()
    local Profile = OneWoW_Bags.Profile
    local disabled = db.global.disabledCategories
    local catMods = db.global.categoryModifications

    if itemID then
        local manualName = ResolveManualCategoryName(itemID, db, disabled, containerType)
        if manualName then
            return manualName, false
        end
    end

    local junkCatEnabled = db.global.enableJunkCategory and not disabled["1W Junk"]
    if junkCatEnabled and itemID and CategoryAppliesTo("1W Junk", containerType, catMods) then
        if PE:BuildProps(itemID, bagID, slotID, itemInfo).isJunk then
            return "1W Junk", false
        end
    end

    if not hyperlink then
        return "Other", false
    end

    -- Phase 4: Option A gate. When full item info hasn't streamed yet,
    -- skip the expensive predicate pipeline entirely. Predicates that
    -- depend on tooltip lines / vendor price / bind state / stats would
    -- evaluate against partial data and likely fall to "Other"; defer
    -- until GET_ITEM_INFO_RECEIVED arrives and the next refresh runs.
    if itemID and not C_Item.IsItemDataCachedByID(itemID) then
        if Profile then Profile:Start("Categories:GetItemCategory.requestLoadItemData") end
        C_Item.RequestLoadItemDataByID(itemID)
        if Profile then Profile:Stop("Categories:GetItemCategory.requestLoadItemData") end
        if Profile then
            Profile:Start("Categories:GetItemCategory.itemInfoDeferred")
            Profile:Stop("Categories:GetItemCategory.itemInfoDeferred")
        end
        -- Tell the tooltip-catchup pass that at least one slot was provisional
        -- so the deferred refresh is still worth doing. Cleared by the catchup
        -- when it runs.
        OneWoW_Bags._hasPendingTentatives = true
        return "Other", true
    end

    local idKey = PE:GetItemIdentityKey(itemID, hyperlink) .. "|" .. (containerType or "")
    local cached = baseCategoryCache[idKey]
    if cached then
        BumpProfileCounter(Profile, "Categories:GetItemCategory.baseCategoryCacheHit")
        return cached, false
    end

    BumpProfileCounter(Profile, "Categories:GetItemCategory.fullPipeline")

    if Profile then Profile:Start("Categories.fullPipeline.buildProps") end
    local props = PE:BuildProps(itemID, bagID, slotID, itemInfo)
    if Profile then Profile:Stop("Categories.fullPipeline.buildProps") end

    -- Clear any leftover sticky-failure flag from a prior evaluation so we
    -- only observe failures originating in THIS evaluation window. The
    -- lazy resolver in propsMT.__index will re-set the flag if any
    -- tooltip-field access in the predicates below comes back empty.
    rawset(props, "_tooltipDataMissing", nil)

    local allCands = {}

    if itemID then
        if Profile then Profile:Start("Categories.fullPipeline.customCands") end
        CollectCustomPredicateCandidates(itemID, bagID, slotID, itemInfo, disabled, allCands)
        if Profile then Profile:Stop("Categories.fullPipeline.customCands") end
    end

    if Profile then Profile:Start("Categories.fullPipeline.searchCats") end
    for _, def in ipairs(SEARCH_CATEGORIES) do
        if not disabled[def.name] then
            if PE:CheckItem(def.search, itemID, bagID, slotID, itemInfo) then
                tinsert(allCands, {
                    name = def.name,
                    tieKey = def.name,
                    isCustom = false,
                    defaultOrder = def.priority,
                    searchOrder = def.searchOrder,
                })
            end
        end
    end
    if Profile then Profile:Stop("Categories.fullPipeline.searchCats") end

    if containerType then
        local applicable = {}
        for _, c in ipairs(allCands) do
            if CategoryAppliesTo(c.name, containerType, catMods) then
                tinsert(applicable, c)
            end
        end
        allCands = applicable
    end

    local category = "Other"
    if #allCands > 0 then
        if Profile then Profile:Start("Categories.fullPipeline.pickBest") end
        local best = PickBestCandidate(allCands, db, db.global)
        if Profile then Profile:Stop("Categories.fullPipeline.pickBest") end
        if best then
            category = best.name
        end
    end

    if db.global.enableInventorySlots then
        if category == "Weapons" or category == "Armor" then
            local equipLoc = props.equipLoc
            if equipLoc and equipLoc ~= "" then
                local slotName = GetSlotCategoryName(equipLoc)
                if slotName and CategoryAppliesTo(slotName, containerType, catMods) then
                    category = slotName
                end
            end
        end
    end

    if disabled[category] then
        category = "Other"
    end

    -- If any predicate evaluation triggered a tooltip lookup that came back
    -- empty (cold streaming, hyperlink-tooltip not yet cached), the verdict
    -- is suspect. Return tentative so the caller (and the slot-level cache)
    -- skips persisting; the next refresh re-evaluates.
    local tentative = rawget(props, "_tooltipDataMissing") == true
    if tentative then
        if Profile then
            Profile:Start("Categories:GetItemCategory.tooltipDeferred")
            Profile:Stop("Categories:GetItemCategory.tooltipDeferred")
        end
        OneWoW_Bags._hasPendingTentatives = true
        return category, true
    end

    baseCategoryCache[idKey] = category
    return category, false
end

--- Resolve the display category for an item slot.
--- Applies manual pins, OneWoW feature categories, custom predicate categories,
--- built-in search categories, optional equipment-slot splitting, and cache
--- reuse for stable item links.
---@param bagID number
---@param slotID number
---@param itemInfo table|nil
---@return string categoryName
function Categories:GetItemCategory(bagID, slotID, itemInfo)
    if not itemInfo then return "Other" end

    local Profile = OneWoW_Bags.Profile
    if Profile then Profile:Start("Categories:GetItemCategory") end

    local db = GetDB()
    local itemID = itemInfo.itemID
    local hyperlink = itemInfo.hyperlink
    local disabled = db.global.disabledCategories
    local containerType = BagTypes:GetContainerType(bagID)
    local catMods = db.global.categoryModifications

    -- Slot-keyed final-result cache (covers slot-overlay outcomes too).
    local cacheKey = PE:GetItemCacheKey(itemID, bagID, slotID, hyperlink)
    if cacheKey then
        local cached = categoryCache[cacheKey]
        if cached then
            BumpProfileCounter(Profile, "Categories:GetItemCategory.categoryCacheHit")
            if Profile then Profile:Stop("Categories:GetItemCategory") end
            return cached
        end
    end

    -- Slot-overlay #1: "1W Upgrades" (depends on ItemLocation / equipped state).
    if itemID and hyperlink and db.global.enableUpgradeCategory and not disabled["1W Upgrades"]
       and CategoryAppliesTo("1W Upgrades", containerType, catMods) then
        local UD = OneWoW and OneWoW.UpgradeDetection
        if UD and UD.CheckItemUpgrade then
            local itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
            local upgrade
            if itemLocation and C_Item.DoesItemExist(itemLocation) then
                upgrade = UD:CheckItemUpgrade(hyperlink, itemLocation)
            else
                upgrade = UD:CheckItemUpgrade(hyperlink)
            end
            if upgrade then
                if cacheKey then categoryCache[cacheKey] = "1W Upgrades" end
                if Profile then
                    Profile:Start("Categories:GetItemCategory.slotOverlayHit")
                    Profile:Stop("Categories:GetItemCategory.slotOverlayHit")
                    Profile:Stop("Categories:GetItemCategory")
                end
                return "1W Upgrades"
            end
        end
    end

    -- Slot-overlay #2: "Recent Items" (depends on slot-recent tracking).
    if itemID and not disabled["Recent Items"]
       and CategoryAppliesTo("Recent Items", containerType, catMods)
       and self:SlotMatchesRecent(itemID, bagID, slotID) then
        if cacheKey then categoryCache[cacheKey] = "Recent Items" end
        if Profile then
            Profile:Start("Categories:GetItemCategory.slotOverlayHit")
            Profile:Stop("Categories:GetItemCategory.slotOverlayHit")
            Profile:Stop("Categories:GetItemCategory")
        end
        return "Recent Items"
    end

    -- Fall through to identity-tier base resolver.
    local category, tentative = ResolveBaseCategory(itemID, hyperlink, containerType, itemInfo, bagID, slotID)

    -- Tentative verdicts mean the predicate pipeline ran without full item
    -- info or tooltip data. Persisting them would freeze items in the wrong
    -- category until something invalidates the slot. Leave the slot uncached
    -- so the next refresh re-evaluates once data has streamed in.
    if cacheKey and hyperlink and not tentative then
        categoryCache[cacheKey] = category
    end

    if Profile then Profile:Stop("Categories:GetItemCategory") end
    return category
end

function Categories:GetCategoryDefaultOrder(categoryName)
    return CATEGORY_DEFAULT_ORDER[categoryName] or 50
end

function Categories:SortCategories(categoryList, sortMode)
    if sortMode == "alphabetical" then
        sort(categoryList, function(a, b)
            local aName = type(a) == "table" and a.name or a
            local bName = type(b) == "table" and b.name or b

            if aName == "Empty" then return false end
            if bName == "Empty" then return true end

            if aName == "Other" then return false end
            if bName == "Other" then return true end

            if aName == "Junk" then return false end
            if bName == "Junk" then return true end

            if aName == "Recent Items" then return true end
            if bName == "Recent Items" then return false end

            return aName < bName
        end)
    else
        local db = GetDB()
        local customOrderMap = {}
        for _, catData in pairs(customCategoriesV2) do
            if catData.name and catData.sortOrder then
                customOrderMap[catData.name] = catData.sortOrder
            end
        end
        local catMods = db.global.categoryModifications
        sort(categoryList, function(a, b)
            local aName = type(a) == "table" and a.name or a
            local bName = type(b) == "table" and b.name or b

            local aOrder = self:GetCategoryDefaultOrder(aName)
            local bOrder = self:GetCategoryDefaultOrder(bName)

            local aMod = catMods[aName]
            local bMod = catMods[bName]
            if aMod and aMod.priority then aOrder = aOrder + aMod.priority end
            if bMod and bMod.priority then bOrder = bOrder + bMod.priority end

            if aOrder ~= bOrder then
                return aOrder < bOrder
            end

            local aCustomSort = customOrderMap[aName] or 999
            local bCustomSort = customOrderMap[bName] or 999
            if aCustomSort ~= bCustomSort then
                return aCustomSort < bCustomSort
            end

            return aName < bName
        end)
    end
end

function Categories:SlotMatchesRecent(itemID, bagID, slotID)
    if not itemID or not bagID or not slotID then return false end
    local itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
    if itemLocation and itemLocation:IsValid() and C_Item.DoesItemExist(itemLocation) then
        ---@cast itemLocation ItemLocation
        local guid = C_Item.GetItemGUID(itemLocation)
        if guid and recentItems[guid] then
            local currentTime = time()
            if currentTime - recentItems[guid] < recentItemDuration then
                return true
            else
                recentItems[guid] = nil
            end
        end
    end
    return false
end

function Categories:AddRecentItem(itemGUID)
    if not itemGUID then return end
    recentItems[itemGUID] = time()
end

function Categories:CleanExpiredRecent()
    local currentTime = time()
    local removed = false
    for guid, timestamp in pairs(recentItems) do
        if currentTime - timestamp >= recentItemDuration then
            recentItems[guid] = nil
            removed = true
        end
    end
    return removed
end

function Categories:BeginRecentExpiryTicker()
    if recentExpiryTicker then
        recentExpiryTicker:Cancel()
        recentExpiryTicker = nil
    end
    local interval = Constants.GUI.RECENT_EXPIRY_TICK_INTERVAL or 2
    recentExpiryTicker = C_Timer.NewTicker(interval, function()
        local gui = OneWoW_Bags.GUI
        if not gui or not gui:IsShown() then
            Categories:EndRecentExpiryTicker()
            return
        end
        if Categories:CleanExpiredRecent() then
            OneWoW_Bags:RequestLayoutRefresh("all")
        end
    end)
end

function Categories:EndRecentExpiryTicker()
    if recentExpiryTicker then
        recentExpiryTicker:Cancel()
        recentExpiryTicker = nil
    end
    self:CleanExpiredRecent()
end

function Categories:SetRecentItemDuration(duration)
    recentItemDuration = duration or 120
end

function Categories:SetRecentItems(saved)
    if saved then
        recentItems = saved
    end
end

function Categories:OnPlayerBagDirtySnapshot(dirtyBags)
    if not dirtyBags then return end
    self:CleanExpiredRecent()
    for bagID in pairs(dirtyBags) do
        if BagTypes:IsPlayerBag(bagID) then
            local numSlots = C_Container.GetContainerNumSlots(bagID)
            for slotID = 1, numSlots do
                if C_NewItems.IsNewItem(bagID, slotID) then
                    local loc = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
                    if loc and loc:IsValid() and C_Item.DoesItemExist(loc) then
                        ---@cast loc ItemLocation
                        local guid = C_Item.GetItemGUID(loc)
                        if guid then
                            self:AddRecentItem(guid)
                        end
                    end
                end
            end
        end
    end
end

--- Return the winning custom predicate category for an item, if any.
---@param itemID number|nil
---@param bagID number|nil
---@param slotID number|nil
---@param itemInfo table|nil
---@return string|nil categoryName
---@return string|nil categoryID
function Categories:GetCustomCategoryForItem(itemID, bagID, slotID, itemInfo)
    if not itemID then return nil end

    local db = GetDB()
    local disabled = db.global.disabledCategories
    local cands = {}
    CollectCustomPredicateCandidates(itemID, bagID, slotID, itemInfo, disabled, cands)
    if #cands == 0 then
        return nil, nil
    end
    local best = PickBestCandidate(cands, db, db.global)
    if not best then
        return nil, nil
    end
    return best.name, best.tieKey
end

--- Find whether an item is manually pinned to a custom or built-in category.
---@param itemID number|nil
---@return table|nil pin
---@return string|nil pin.kind
---@return string|nil pin.categoryId
---@return string|nil pin.categoryName
---@return string|nil pin.displayName
function Categories:FindManualPinForItem(itemID)
    if not itemID then return nil end
    local idstr = tostring(itemID)
    for categoryId, categoryData in pairs(customCategoriesV2) do
        if categoryData.items and (categoryData.items[idstr] or categoryData.items[itemID]) then
            return {
                kind = "custom",
                categoryId = categoryId,
                displayName = categoryData.name or categoryId,
            }
        end
    end
    local db = GetDB()
    for catName, mod in pairs(db.global.categoryModifications) do
        if mod.addedItems and mod.addedItems[idstr] then
            return {
                kind = "builtin",
                categoryName = catName,
                displayName = catName,
            }
        end
    end
    return nil
end

--- Create a custom category entry.
---@param name string
---@return string|nil categoryID
function Categories:CreateCustomCategory(name)
    if not name or name == "" then
        return nil
    end

    local categoryId = "custom_" .. time() .. "_" .. math.random(1000, 9999)

    customCategoriesV2[categoryId] = {
        name = name,
        items = {},
        created = time(),
        enabled = true,
    }

    InvalidateCache()

    return categoryId
end

--- Manually pin an item ID to a custom category.
---@param categoryID string
---@param itemID number|string
---@return boolean ok
function Categories:AddItemToCustomCategory(categoryID, itemID)
    if not categoryID or not customCategoriesV2[categoryID] or not itemID then
        return false
    end

    local idstr = tostring(itemID)
    customCategoriesV2[categoryID].items = customCategoriesV2[categoryID].items or {}
    customCategoriesV2[categoryID].items[idstr] = true

    InvalidateCache()

    return true
end

--- Remove a manual item pin from a custom category.
---@param categoryID string
---@param itemID number|string
---@return boolean ok
function Categories:RemoveItemFromCustomCategory(categoryID, itemID)
    if not categoryID or not customCategoriesV2[categoryID] or not itemID then
        return false
    end

    local idstr = tostring(itemID)
    local items = customCategoriesV2[categoryID].items
    if items then
        items[idstr] = nil
        items[itemID] = nil
    end

    InvalidateCache()

    return true
end

--- Delete a custom category entry.
---@param categoryID string
---@return boolean ok
function Categories:DeleteCustomCategory(categoryID)
    if not categoryID or not customCategoriesV2[categoryID] then
        return false
    end

    customCategoriesV2[categoryID] = nil

    InvalidateCache()

    return true
end

--- Return the live custom category table.
--- Callers that mutate this table must invalidate categorization afterwards.
---@return table<string, table> customCategories
function Categories:GetAllCustomCategories()
    return customCategoriesV2
end

--- Replace the in-memory custom category table from SavedVariables.
---@param saved table<string, table>|nil
function Categories:SetCustomCategories(saved)
    if saved then
        customCategoriesV2 = saved
    end
    RebuildCustomCandsArray()
    RebuildCategoryListOrderMap(GetDB().global)
end

--- Return the custom category table for SavedVariables serialization.
---@return table<string, table> customCategories
function Categories:GetCustomCategoriesForSave()
    return customCategoriesV2
end

--- Clear cached item-to-category resolutions.
function Categories:InvalidateCache()
    InvalidateCache()
end

--- Surgical per-itemID invalidation for category caches. Paired with
--- PE:InvalidateItemIDs so we don't re-walk propsCache: the caller passes
--- the slot keys PE already evicted, and we evict our slot-keyed final
--- results for those keys. We still walk baseCategoryCache + identity-keyed
--- categoryCache once (both prefix their keys with "<itemID>|").
---@param idSet table<number, boolean>|nil
---@param evictedSlotKeys table<string, boolean>|nil
function Categories:InvalidateItemIDs(idSet, evictedSlotKeys)
    if not idSet then return end

    if evictedSlotKeys then
        for slotKey in pairs(evictedSlotKeys) do
            categoryCache[slotKey] = nil
        end
    end

    for key in pairs(baseCategoryCache) do
        local id = tonumber(key:match("^(%d+)|"))
        if id and idSet[id] then
            baseCategoryCache[key] = nil
        end
    end

    -- Identity-keyed entries in categoryCache (rare; only happens when
    -- GetItemCategory is reached without slot coords). Same "<itemID>|"
    -- prefix shape; slot-keyed entries use "<bagID>:<slotID>" and won't match.
    for key in pairs(categoryCache) do
        local id = tonumber(key:match("^(%d+)|"))
        if id and idSet[id] then
            categoryCache[key] = nil
        end
    end
end

--- Return built-in category names in definition order.
---@return string[] names
function Categories:GetAllCategoryNames()
    local names = {}
    for _, def in ipairs(CATEGORY_DEFINITIONS) do
        tinsert(names, def.name)
    end
    return names
end

--- Return built-in category definition records.
---@return table[] definitions
function Categories:GetCategoryDefinitions()
    return CATEGORY_DEFINITIONS
end

--- Return built-in categories backed by PredicateEngine search expressions.
---@return table[] searchCategories
function Categories:GetSearchCategories()
    return SEARCH_CATEGORIES
end

function Categories:AddItemToBuiltinCategory(categoryName, itemID)
    if not categoryName or not itemID then return false end

    local pin = self:FindManualPinForItem(itemID)
    if pin then
        if pin.kind == "builtin" and pin.categoryName == categoryName then
            return true
        end
        return false, pin.displayName
    end

    local addedItems = OneWoW_Bags:EnsureBuiltinCategoryAddedItems(categoryName)
    if not addedItems then return false end
    addedItems[tostring(itemID)] = true
    InvalidateCache()
    return true
end

function Categories:RemoveItemFromBuiltinCategory(categoryName, itemID)
    if not categoryName or not itemID then return false end

    local db = GetDB()
    if not db.global.categoryModifications then return false end
    local mod = db.global.categoryModifications[categoryName]
    if not mod or not mod.addedItems then return false end
    mod.addedItems[tostring(itemID)] = nil
    InvalidateCache()
    return true
end

function Categories:GetCategoryDescription(categoryName)
    local descKeys = {
        ["1W Junk"] = "CAT_DESC_1W_JUNK",
        ["1W Upgrades"] = "CAT_DESC_1W_UPGRADES",
        ["Recent Items"] = "CAT_DESC_RECENT_ITEMS",
        ["Hearthstone"] = "CAT_DESC_HEARTHSTONE",
        ["Keystone"] = "CAT_DESC_KEYSTONE",
        ["Potions"] = "CAT_DESC_POTIONS",
        ["Food"] = "CAT_DESC_FOOD",
        ["Consumables"] = "CAT_DESC_CONSUMABLES",
        ["Quest Items"] = "CAT_DESC_QUEST_ITEMS",
        ["Equipment Sets"] = "CAT_DESC_EQUIPMENT_SETS",
        ["Weapons"] = "CAT_DESC_WEAPONS",
        ["Armor"] = "CAT_DESC_ARMOR",
        ["Mats"] = "CAT_DESC_MATS",
        ["Reagents"] = "CAT_DESC_REAGENTS",
        ["Trade Goods"] = "CAT_DESC_TRADE_GOODS",
        ["Tradeskill"] = "CAT_DESC_TRADESKILL",
        ["Recipes"] = "CAT_DESC_RECIPES",
        ["Housing"] = "CAT_DESC_HOUSING",
        ["Gems"] = "CAT_DESC_GEMS",
        ["Item Enhancement"] = "CAT_DESC_ITEM_ENHANCEMENT",
        ["Containers"] = "CAT_DESC_CONTAINERS",
        ["Keys"] = "CAT_DESC_KEYS",
        ["Miscellaneous"] = "CAT_DESC_MISCELLANEOUS",
        ["Battle Pets"] = "CAT_DESC_BATTLE_PETS",
        ["Toys"] = "CAT_DESC_TOYS",
        ["Other"] = "CAT_DESC_OTHER",
        ["Junk"] = "CAT_DESC_JUNK",
    }
    local key = descKeys[categoryName]
    return key and L[key] or nil
end

--- Check whether a category is configured to apply to a container type.
---@param catName string
---@param containerType string|nil
---@return boolean applies
function Categories:CategoryAppliesTo(catName, containerType)
    local db = GetDB()
    return CategoryAppliesTo(catName, containerType, db.global.categoryModifications)
end

PE:RegisterKeyword("recent", function(p)
    if not p.id then return false end
    return Categories:SlotMatchesRecent(p.id, p._bagID, p._slotID)
end)
