local _, ns = ...

-- ============================================================================
-- Collectibles — container contents maps (punch-list + direct)
-- ============================================================================
-- Shared content groups (e.g. Preyseeker armor/weapons) are referenced by
-- container itemIDs in two modes:
--   punchList — Blizzard "Contains one of the following items:" name-only
--               lines matched against a class-filtered candidate pool
--   direct    — no punch-list lines; evaluate the whole class-filtered pool
--
-- Candidates are filtered once per group via OneWoW.GearProficiency
-- (class weapon/armor proficiency + cloaks/holdables). Lazy session cache.
-- Rings/necks/trinkets stay off the lists. See Docs/COLLECTIBLES.md.
-- ============================================================================

local Collectibles = ns.Collectibles
local GearProficiency = ns.GearProficiency

-- https://www.wowhead.com/items/name:preyseeker/quality:2:3:4/slot:16:5:8:10:1:23:7:21:22:13:15:26:14:4:3:19:17:6:9?filter=195:251;1:2;0:0#items;0+2+20
local PREYSEEKER_CONTENTS = {
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
}

-- Midnight delve gear (Nebulous Voidcache: Delver's Trove punch-list pool).
-- Jewelry (rings/necks/trinkets) omitted — same policy as Preyseeker.
local DELVERS_TROVE_CONTENTS = {
    -- Cloaks
    249619, -- Sprawling Mycoshroud
    249624, -- Osseoclad Paledrape
    249625, -- Elder Mossveil
    249628, -- Rampant Bramblecloak
    -- Cloth (Sprawling)
    249629, -- Rootunic
    249630, -- Rootpads
    249631, -- Tendrils
    249632, -- Stoloncollar
    249633, -- Rootstockings
    249634, -- Fibershells
    249635, -- Rhizomecord
    249636, -- Wristroots
    -- Leather (Osseoclad)
    249637, -- Marrowvest
    249638, -- Bonecrushers
    249639, -- Spinegrapplers
    249640, -- Saberteeth
    249641, -- Bonesteppers
    249642, -- Razorspaulders
    249643, -- Waistbone
    249644, -- Ivory Wrist
    -- Mail (Elder Moss)
    249645, -- Mossmail
    249646, -- Mossclogs
    249647, -- Mossfeelers
    249648, -- Mosshorns
    249649, -- Mossvein Breeches
    249650, -- Mossvein Greatleaves
    249651, -- Mosscinch
    249652, -- Mossbands
    -- Plate (Rampant Bramble)
    249653, -- Brambleplate
    249654, -- Thistlestompers
    249655, -- Creepers
    249656, -- Briarhelm
    249657, -- Bramblegreaves
    249658, -- Thornmantles
    249659, -- Thornstrap
    249660, -- Briarcuffs
    -- Weapons / off-hands / shield
    249610, -- Resinous Blossomblade
    249661, -- Root Sculptor's Verdaxe
    249662, -- Wild Fiberknife
    249664, -- Gnarled Thornmace
    249665, -- Blooming Seedpod
    249667, -- Barbed Rootwand
    249669, -- Organ Piercer's Briarspear
    249670, -- Elderoot Spire
    249671, -- Gnarlroot Spinecleaver
    249672, -- Elderbloom Lantern
    249676, -- Bramblebarricade
    249677, -- Twinthorn Wildglaive
    251884, -- Abyss Sabre
    251885, -- Radiant Foil
    251935, -- Lightgrasp Worldroot
    259462, -- Thorneedle
    260187, -- Underbrush Render
    260188, -- Savage Briaredge
    260189, -- Rootkeeper's Dancing Needle
    262729, -- Hand of the Rootkeeper
    262731, -- Wildthorn Razorfang
    262732, -- Heavy Bramblebolter
}

-- Bulging Ethereal Pack weapons / off-hands / shield
local ETHEREAL_PACK_CONTENTS = {
    274877, -- Phaseblade Headsplitter
    274878, -- Hal'hadar Shadowripper's Blade
    274879, -- Mana-Amplified Crusher
    274880, -- Hal'hadar Adjutant's Gavel
    274881, -- Phase Igniter
    274882, -- Hal'hadar Pulse Rifle
    274883, -- Hal'hadar Warpguard's Poleaxe
    274884, -- Arcanografter's Beacon
    274885, -- Phase-Edged Falchion
    274886, -- Eradicator's Censer
    274887, -- Mana-Overloaded Bulwark
    274888, -- Hal'hadar Legion Glaives
    274889, -- Hal'hadar Darkblade's Edge
}

-- Bulging Winter Pack armor (+ cloak)
local WINTER_PACK_CONTENTS = {
    249755, -- Void-Touched Winter Hood
    249756, -- Void-Touched Winter Pauldrons
    249757, -- Void-Touched Winter Tunic
    249758, -- Void-Touched Winter Belt
    249759, -- Void-Touched Winter Leggings
    249760, -- Void-Touched Winter Boots
    249761, -- Void-Touched Winter Gloves
    249762, -- Void-Touched Winter Cloak
    249864, -- Void-Touched Winter Spaulders
}

local CONTENT_GROUPS = {
    preyseeker = { contents = PREYSEEKER_CONTENTS },
    delversTrove = { contents = DELVERS_TROVE_CONTENTS },
    etherealPack = { contents = ETHEREAL_PACK_CONTENTS },
    winterPack = { contents = WINTER_PACK_CONTENTS },
}

--- cacheItemID → { group, mode }  mode = "punchList" | "direct"
local CACHE_ENTRIES = {
    [269768] = { group = "preyseeker", mode = "punchList" }, -- Nebulous Voidcache: Prey
    [268969] = { group = "delversTrove", mode = "punchList" }, -- Nebulous Voidcache: Delver's Trove
    [257023] = { group = "preyseeker", mode = "direct" },    -- Preyseeker's Adventurer Chest
    [257026] = { group = "preyseeker", mode = "direct" },    -- Preyseeker's Veteran Chest
    [262346] = { group = "preyseeker", mode = "direct" },    -- Preyseeker's Champion Chest
    [278026] = { group = "etherealPack", mode = "direct" },  -- Bulging Ethereal Pack
    [278027] = { group = "winterPack", mode = "direct" },    -- Bulging Winter Pack
}

local LINE_NONE = Enum.TooltipDataLineType.None
local LINE_BLANK = Enum.TooltipDataLineType.Blank

-- Lazy class-filtered contents keyed by group id (class cannot change mid-session).
local filteredByGroup = {}
-- In-flight ContinueOnItemLoad batches keyed by hovered cache itemID.
local loadPendingByCache = {}

---@param itemID number
---@param name string
---@return table row `{ itemID, name, quality }`
local function MissingRow(itemID, name)
    return {
        itemID = itemID,
        name = name,
        quality = C_Item.GetItemQualityByID(itemID),
    }
end

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
    local stripped = text:match("^[-–—•]%s*(.+)$")
    return NormalizeItemName(stripped or text)
end

---@param cacheItemID number
---@return string
local function ResolveCacheName(cacheItemID)
    local cacheName = C_Item.GetItemNameByID(cacheItemID) or C_Item.GetItemInfo(cacheItemID)
    if not cacheName or cacheName == "" then
        return tostring(cacheItemID)
    end
    return cacheName
end

--- Rebuild the open GameTooltip once group content item data is ready.
---@param cacheItemID number
---@param rawContents number[]
local function ScheduleTooltipRefresh(cacheItemID, rawContents)
    if loadPendingByCache[cacheItemID] then return end
    loadPendingByCache[cacheItemID] = true

    local pending = 0
    local function onOneLoaded()
        pending = pending - 1
        if pending > 0 then return end
        loadPendingByCache[cacheItemID] = nil
        local entry = CACHE_ENTRIES[cacheItemID]
        if entry then
            filteredByGroup[entry.group] = nil
        end
        if not GameTooltip:IsShown() then return end
        local _, link = GameTooltip:GetItem()
        local tipItemID = link and C_Item.GetItemInfoInstant(link)
        if tipItemID ~= cacheItemID then return end
        if GameTooltip.RebuildFromTooltipInfo then
            GameTooltip:RebuildFromTooltipInfo()
        end
    end

    for i = 1, #rawContents do
        local itemID = rawContents[i]
        if not C_Item.IsItemDataCachedByID(itemID) then
            pending = pending + 1
            C_Item.RequestLoadItemDataByID(itemID)
            local item = Item:CreateFromItemID(itemID)
            item:ContinueOnItemLoad(onOneLoaded)
        end
    end

    if pending == 0 then
        loadPendingByCache[cacheItemID] = nil
    end
end

--- Class-filtered contents for a group.
---@param groupId string
---@return number[]|nil filtered
local function GetFilteredContents(groupId)
    local cached = filteredByGroup[groupId]
    if cached then return cached end

    local group = CONTENT_GROUPS[groupId]
    if not group then return nil end
    local raw = group.contents

    local filtered = {}
    for i = 1, #raw do
        local itemID = raw[i]
        if GearProficiency.ClassAllowsItem(itemID) then
            filtered[#filtered + 1] = itemID
        end
    end
    filteredByGroup[groupId] = filtered
    return filtered
end

--- Build localized name → itemID for a candidate list.
---@param candidates number[]
---@return table<string, number> index
---@return boolean anyUncached
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
---@return string[]|nil
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

---@param candidates number[]
---@param tooltipData table|nil
---@param cacheItemID number
---@return table|nil summary
local function SummarizePunchList(candidates, tooltipData, cacheItemID)
    local listedNames = ExtractPunchListNames(tooltipData)
    if not listedNames or #listedNames == 0 then return nil end

    local nameIndex, anyUncached = BuildNameIndex(candidates)
    if anyUncached then
        ScheduleTooltipRefresh(cacheItemID, candidates)
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
                    missing[#missing + 1] = MissingRow(itemID, name)
                end
            end
        end
    end

    if matched == 0 then return nil end

    return {
        cacheName = ResolveCacheName(cacheItemID),
        missing = missing,
    }
end

---@param candidates number[]
---@param cacheItemID number
---@return table|nil summary
local function SummarizeDirect(candidates, cacheItemID)
    local missing = {}
    local matched = 0
    local anyUncachedName = false

    for i = 1, #candidates do
        local itemID = candidates[i]
        local name = C_Item.GetItemNameByID(itemID) or C_Item.GetItemInfo(itemID)
        if not name or name == "" then
            anyUncachedName = true
        end
        local status = Collectibles.GetItemCollectionStatus(itemID, nil, { light = true })
        if status then
            matched = matched + 1
            if not status.collected then
                missing[#missing + 1] = MissingRow(
                    itemID,
                    (name and name ~= "") and name or ("item:" .. itemID)
                )
            end
        end
    end

    if anyUncachedName then
        ScheduleTooltipRefresh(cacheItemID, candidates)
    end

    if matched == 0 then return nil end

    return {
        cacheName = ResolveCacheName(cacheItemID),
        missing = missing,
    }
end

--- Resolve container tooltip collection summary for a known cache/chest.
--- Returns nil when not applicable. `missing` is empty when every evaluated
--- collectible is already owned.
---@param cacheItemID number
---@param tooltipData table|nil
---@return table|nil summary `{ cacheName, missing = { { itemID, name, quality }, ... } }`
function Collectibles.GetPunchListSummary(cacheItemID, tooltipData)
    cacheItemID = tonumber(cacheItemID)
    if not cacheItemID then return nil end

    local entry = CACHE_ENTRIES[cacheItemID]
    if not entry then return nil end

    local filtered = GetFilteredContents(entry.group)
    if not filtered then return nil end
    if #filtered == 0 then return nil end

    if entry.mode == "direct" then
        return SummarizeDirect(filtered, cacheItemID)
    end
    return SummarizePunchList(filtered, tooltipData, cacheItemID)
end

-- ---------------------------------------------------------------------------
-- DEBUG: punch-list / direct contents dump (/owpunch, /owpunchlist)
-- ---------------------------------------------------------------------------

local PUNCH_DEBUG_PREFIX = "|cFF55CCFFPunchList|r"

local function PunchDebugPrint(msg)
    print(PUNCH_DEBUG_PREFIX .. ": " .. msg)
end

local function ResolvePunchDumpTarget(msg)
    msg = strtrim(msg or "")
    if msg ~= "" then
        local hyperlink = msg:match("(|c.-|Hitem:.-|h.-|h|r)")
        if not hyperlink and msg:find("item:", 1, true) then
            hyperlink = msg
        end
        if hyperlink then
            return C_Item.GetItemInfoInstant(hyperlink)
        end
        local itemID = tonumber(msg)
        if itemID then
            return itemID
        end
    end

    local _, link = GameTooltip:GetItem()
    if link then
        return C_Item.GetItemInfoInstant(link)
    end

    local infoType, itemID = GetCursorInfo()
    if infoType == "item" and itemID then
        return itemID
    end
end

--- Chat dump: class filter + collection status for every group candidate.
---@param cacheItemID number|nil
function Collectibles.DumpPunchListDebug(cacheItemID)
    cacheItemID = tonumber(cacheItemID)
    if not cacheItemID then
        PunchDebugPrint("hover a cache/chest tooltip, or pass itemID (e.g. /1wpunch 257026)")
        return
    end

    local entry = CACHE_ENTRIES[cacheItemID]
    local cacheName = ResolveCacheName(cacheItemID)
    local _, classToken, classID = UnitClass("player")
    PunchDebugPrint("=== Punch-list debug ===")
    PunchDebugPrint(format(
        "cacheItemID=%d name=%q class=%s classID=%s",
        cacheItemID, cacheName, tostring(classToken), tostring(classID)
    ))

    if not entry then
        PunchDebugPrint("no CACHE_ENTRIES for this itemID")
        return
    end

    PunchDebugPrint(format("group=%s mode=%s", entry.group, entry.mode))
    local group = CONTENT_GROUPS[entry.group]
    if not group then
        PunchDebugPrint("missing CONTENT_GROUPS." .. entry.group)
        return
    end

    filteredByGroup[entry.group] = nil

    local raw = group.contents
    local passFilter, failFilter = 0, 0
    local noStatus, collectedN, missingN = 0, 0, 0
    PunchDebugPrint(format("rawContents=%d — per-item:", #raw))

    for i = 1, #raw do
        local itemID = raw[i]
        local name = C_Item.GetItemNameByID(itemID) or C_Item.GetItemInfo(itemID) or "?"
        local flag = GearProficiency.GetItemFlag(itemID)
        local flagName = GearProficiency.GetFlagName(flag) or "nil"
        local allowed = GearProficiency.ClassAllowsItem(itemID)
        local status = Collectibles.GetItemCollectionStatus(itemID, nil, { light = true })
        local statusBits
        if status then
            statusBits = format("status collected=%s", tostring(status.collected))
            if status.collected then
                collectedN = collectedN + 1
            else
                missingN = missingN + 1
            end
        else
            statusBits = "status=nil"
            noStatus = noStatus + 1
        end

        if allowed then
            passFilter = passFilter + 1
        else
            failFilter = failFilter + 1
        end

        PunchDebugPrint(format(
            "  [%d] %d %q flag=%s allowed=%s %s",
            i, itemID, name, flagName, tostring(allowed), statusBits
        ))
    end

    local filtered = GetFilteredContents(entry.group)
    PunchDebugPrint(format(
        "filter: allowed=%d denied=%d filtered=%s",
        passFilter, failFilter, filtered and tostring(#filtered) or "nil"
    ))
    PunchDebugPrint(format(
        "collection among raw: collected=%d missing=%d noStatus=%d",
        collectedN, missingN, noStatus
    ))

    if filtered then
        local summary
        if entry.mode == "direct" then
            summary = SummarizeDirect(filtered, cacheItemID)
        else
            local tipData = GameTooltip.GetTooltipData and GameTooltip:GetTooltipData()
            summary = SummarizePunchList(filtered, tipData, cacheItemID)
        end
        if not summary then
            PunchDebugPrint("GetPunchListSummary result=nil")
        else
            PunchDebugPrint(format(
                "summary cacheName=%q missingCount=%d",
                summary.cacheName, #summary.missing
            ))
            for i = 1, #summary.missing do
                local row = summary.missing[i]
                PunchDebugPrint(format(
                    "  missing[%d] %d %q quality=%s",
                    i, row.itemID, row.name, tostring(row.quality)
                ))
            end
            if #summary.missing == 0 then
                PunchDebugPrint("(empty missing → tooltip shows All collected)")
            end
        end
    end
end

SLASH_OW_PUNCH_DUMP1 = "/1wpunch"
SLASH_OW_PUNCH_DUMP2 = "/1wpunchlist"
SlashCmdList["OW_PUNCH_DUMP"] = function(msg)
    Collectibles.DumpPunchListDebug(ResolvePunchDumpTarget(msg))
end
