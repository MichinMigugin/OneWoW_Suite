local _, ns = ...

-- ============================================================================
-- Collectibles — punch-list contents maps
-- ============================================================================
-- Blizzard "Contains one of the following items:" tooltips (punch-list /
-- voidcache) list content as name-only lines with no itemIDs. This curated
-- map is cacheItemID → candidate content itemIDs (armor/weapons only —
-- rings/necks/trinkets are not transmog-collectible and are omitted).
--
-- Matching is locale-safe: candidate names come from C_Item.GetItemNameByID
-- at call time; tooltip lines after PUNCH_LIST_ITEM_CACHE_TOOLTIP are
-- matched by stripped display name. Uncached candidates are requested and
-- the live GameTooltip is rebuilt once names land. See Docs/COLLECTIBLES.md.
-- ============================================================================

local Collectibles = ns.Collectibles

--- Curated punch-list contents. Extend with more cache itemIDs as needed.
--- Values are armor/weapon itemIDs only (no rings / necks / trinkets).
local PUNCH_LIST_CONTENTS = {
    -- Nebulous Voidcache: Prey — Preyseeker armor + weapons (all armor types)
    -- https://www.wowhead.com/items/name:preyseeker/quality:2:3:4/slot:16:5:8:10:1:23:7:21:22:13:15:26:14:4:3:19:17:6:9?filter=195:251;1:2;0:0#items;0+2+20
    [269768] = {
        -- Cloth (Refined)
        259909, -- Shawl
        259917, -- Vestments
        259918, -- Slippers
        259919, -- Gloves
        259920, -- Crown
        259921, -- Tights
        259922, -- Epaulet
        259923, -- Cord
        259924, -- Cuffs
        -- Leather (Sleek)
        259910, -- Capelet
        259925, -- Jerkin
        259926, -- Boots
        259927, -- Gauntlets
        259928, -- Mask
        259929, -- Trousers
        259930, -- Shoulderpads
        259931, -- Belt
        259932, -- Armlets
        -- Mail (Rugged)
        258532, -- Stole
        259933, -- Haubergeon
        259934, -- Sabatons
        259935, -- Grips
        259936, -- Plume
        259937, -- Legguards
        259938, -- Shoulderguards
        259939, -- Clasp
        259940, -- Bindings
        -- Plate (Polished)
        258533, -- Cloak
        259941, -- Brigandine
        259942, -- Greatboots
        259943, -- Handguards
        259944, -- Helmet
        259945, -- Tassets
        259946, -- Pauldrons
        259947, -- Greatbelt
        259948, -- Vambraces
        -- Weapons / off-hands
        259949, -- Hatchet
        259950, -- Kukri
        259951, -- Shiv
        259952, -- Cudgel
        259953, -- Scepter
        259955, -- Hammer
        259956, -- Scimitar
        259957, -- Ritual Blade
        259958, -- Longsword
        259959, -- Warglaive
        259960, -- Longbow
        259961, -- Spear
        259962, -- Staff
        259963, -- Spire
        259964, -- Falchion
        259965, -- Lantern
        259966, -- Tower Shield
    },
}

local LINE_NONE = Enum.TooltipDataLineType.None
local LINE_BLANK = Enum.TooltipDataLineType.Blank

-- In-flight ContinueOnItemLoad batches keyed by cache itemID (avoid re-arm storms).
local punchListLoadPending = {}

--- Normalize apostrophes so tooltip lines match C_Item names (’ vs ').
---@param s string
---@return string
local function NormalizeItemName(s)
    return (s:gsub("’", "'"):gsub("‘", "'"))
end

--- Strip tooltip markup and a punch-list bullet prefix ("- Name" → "Name").
---@param leftText string
---@return string
local function StripPunchListName(leftText)
    local text = leftText:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = strtrim(text)
    -- ASCII hyphen, en-dash, em-dash, or bullet
    local stripped = text:match("^[-–—•]%s*(.+)$")
    return NormalizeItemName(stripped or text)
end

--- Rebuild the open GameTooltip once candidate names for this cache are ready.
---@param cacheItemID number
local function SchedulePunchListTooltipRefresh(cacheItemID)
    if punchListLoadPending[cacheItemID] then return end
    punchListLoadPending[cacheItemID] = true

    local candidates = PUNCH_LIST_CONTENTS[cacheItemID]
    if not candidates then
        punchListLoadPending[cacheItemID] = nil
        return
    end

    local pending = 0
    local function onOneLoaded()
        pending = pending - 1
        if pending > 0 then return end
        punchListLoadPending[cacheItemID] = nil
        if not GameTooltip:IsShown() then return end
        local _, link = GameTooltip:GetItem()
        local tipItemID = link and C_Item.GetItemInfoInstant(link)
        if tipItemID ~= cacheItemID then return end
        if GameTooltip.RebuildFromTooltipInfo then
            GameTooltip:RebuildFromTooltipInfo()
        end
    end

    for i = 1, #candidates do
        local itemID = candidates[i]
        if not C_Item.IsItemDataCachedByID(itemID) then
            pending = pending + 1
            C_Item.RequestLoadItemDataByID(itemID)
            local item = Item:CreateFromItemID(itemID)
            item:ContinueOnItemLoad(onOneLoaded)
        end
    end

    if pending == 0 then
        punchListLoadPending[cacheItemID] = nil
    end
end

--- Build localized name → itemID for a candidate list.
---@param candidates number[]
---@return table<string, number> index
---@return boolean anyUncached true when at least one candidate name was missing
local function BuildNameIndex(candidates)
    local index = {}
    local anyUncached = false
    for i = 1, #candidates do
        local itemID = candidates[i]
        local name = C_Item.GetItemNameByID(itemID)
        if not name then
            name = C_Item.GetItemInfo(itemID)
        end
        if name and name ~= "" then
            index[NormalizeItemName(name)] = itemID
        else
            anyUncached = true
            if not C_Item.IsItemDataCachedByID(itemID) then
                C_Item.RequestLoadItemDataByID(itemID)
            end
        end
    end
    return index, anyUncached
end

--- Collect display names listed under the punch-list header in tooltipData.
---@param tooltipData table
---@return string[]|nil names ordered as on the tooltip, or nil if no punch list
local function ExtractPunchListNames(tooltipData)
    local lines = tooltipData and tooltipData.lines
    if not lines then return nil end

    local collecting = false
    local names = {}
    for i = 1, #lines do
        local line = lines[i]
        local left = line.leftText
        if not collecting then
            if left == PUNCH_LIST_ITEM_CACHE_TOOLTIP then
                collecting = true
            end
        elseif line.type == LINE_BLANK then
            break
        elseif left and left ~= "" and (line.type == LINE_NONE or line.type == nil) then
            names[#names + 1] = StripPunchListName(left)
        elseif not left or left == "" then
            break
        else
            break
        end
    end

    if not collecting then return nil end
    return names
end

--- Resolve punch-list tooltip rows for a known cache.
--- Returns nil when not applicable (unknown cache, no punch-list header yet,
--- or no listed row resolved as a collectible). Uncached candidates arm a
--- one-shot tooltip rebuild.
---@param cacheItemID number
---@param tooltipData table|nil live or C_TooltipInfo tooltip data
---@return table|nil summary `{ cacheName, missing = { { itemID, name }, ... } }`
---  `missing` is empty when every matched collectible is already owned
function Collectibles.GetPunchListSummary(cacheItemID, tooltipData)
    cacheItemID = tonumber(cacheItemID)
    if not cacheItemID then return nil end

    local candidates = PUNCH_LIST_CONTENTS[cacheItemID]
    if not candidates then return nil end

    local listedNames = ExtractPunchListNames(tooltipData)
    if not listedNames or #listedNames == 0 then return nil end

    local nameIndex, anyUncached = BuildNameIndex(candidates)
    if anyUncached then
        SchedulePunchListTooltipRefresh(cacheItemID)
    end

    local missing = {}
    local matched = 0
    for i = 1, #listedNames do
        local name = listedNames[i]
        local itemID = nameIndex[name]
        if itemID then
            local status = Collectibles.GetItemCollectionStatus(itemID, nil, { light = true })
            if status then
                matched = matched + 1
                if not status.collected then
                    missing[#missing + 1] = { itemID = itemID, name = name }
                end
            end
        end
    end

    -- Wait for names / a real collectible match before claiming complete.
    if matched == 0 then return nil end

    local cacheName = C_Item.GetItemNameByID(cacheItemID) or C_Item.GetItemInfo(cacheItemID)
    if not cacheName or cacheName == "" then
        cacheName = tostring(cacheItemID)
    end

    return {
        cacheName = cacheName,
        missing = missing,
    }
end
