local ADDON_NAME, OneWoW = ...

local JOURNAL_EXPANSIONS = {
    "Classic", "BurningCrusade", "WrathoftheLichKing", "Cataclysm",
    "MistsofPandaria", "WarlordsofDraenor", "Legion", "BattleforAzeroth",
    "Shadowlands", "Dragonflight", "TheWarWithin", "Midnight",
}

local function GetItemIndex()
    local storage = OneWoW_AltTracker_Storage
    return storage and storage.ItemIndex or nil
end

local function GetVendorData(itemID)
    local api = OneWoW_CatalogData_Vendors_API
    if api and api.GetVendorsByItem then
        return api.GetVendorsByItem(itemID)
    end
    return {}
end

local function GetInstanceData(itemID)
    local results = {}
    local seen = {}
    for _, expName in ipairs(JOURNAL_EXPANSIONS) do
        local items = _G["OneWoWItems_" .. expName]
        if items and items[itemID] then
            local idata = items[itemID]
            if idata.locations then
                local encounters = _G["OneWoWEncounters_" .. expName]
                local instances  = _G["OneWoWInstances_"  .. expName]
                for _, loc in ipairs(idata.locations) do
                    local instID = loc.instanceID
                    local encID  = loc.encounterID or 0
                    local key    = instID .. ":" .. encID
                    if not seen[key] then
                        seen[key] = true
                        local instName = instances and instances[instID] and instances[instID].name or "?"
                        local encName
                        if encID ~= 0 then
                            encName = encounters and encounters[encID] and encounters[encID].name or nil
                        end
                        table.insert(results, { instanceName = instName, encounterName = encName })
                    end
                end
            end
        end
    end
    return results
end

local function GetClassColor(class)
    if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
        local c = RAID_CLASS_COLORS[class]
        return c.r, c.g, c.b
    end
    return 0.9, 0.9, 0.9
end

OneWoW.GetClassColor = GetClassColor

-- Aggregate a flat family-location list into one row per (owner, location[, rank])
-- bucket. Owner is the character (by charKey), the warband, or a guild bank.
--
-- When `groupByRank` is true, each rank becomes its own row (Shift breakdown).
-- When false, all ranks for a given (owner, location) collapse into one row
-- whose count is the sum across the whole item family.
--
-- Honors cfg.showBags / showBank / showEquipped / showAuctions / showWarbandBank /
-- showGuildBanks toggles. Entries whose locationType is filtered out are dropped.
local function AggregateFamilyRows(locations, cfg, L, groupByRank)
    local showBags     = cfg == nil or cfg.showBags        ~= false
    local showBank     = cfg == nil or cfg.showBank        ~= false
    local showEquipped = cfg == nil or cfg.showEquipped    ~= false
    local showAuctions = cfg == nil or cfg.showAuctions    ~= false
    local showWarband  = cfg == nil or cfg.showWarbandBank ~= false
    local showGuilds   = cfg == nil or cfg.showGuildBanks  ~= false

    local locLabels = {
        bags     = L["TIPS_ITEMTRACKER_BAGS"],
        bank     = L["TIPS_ITEMTRACKER_BANK"],
        equipped = L["TIPS_ITEMTRACKER_EQUIPPED"],
        auction  = L["TIPS_ITEMTRACKER_AUCTION"],
        warband  = L["TIPS_ITEMTRACKER_BANK"],
        guild    = L["TIPS_ITEMTRACKER_BANK"],
    }

    local buckets = {}
    local order   = {}

    local function bucket(key, ownerName, ownerKind, class, locationType, rank)
        local b = buckets[key]
        if not b then
            b = {
                ownerName    = ownerName,
                ownerKind    = ownerKind,    -- "char" | "warband" | "guild"
                class        = class,
                locationType = locationType,
                rank         = rank,
                count        = 0,
            }
            buckets[key] = b
            table.insert(order, key)
        end
        return b
    end

    for _, loc in ipairs(locations) do
        local locType = loc.locationType
        local allowed =
            (locType == "bags"     and showBags)     or
            (locType == "bank"     and showBank)     or
            (locType == "equipped" and showEquipped) or
            (locType == "auction"  and showAuctions) or
            (locType == "warband"  and showWarband)  or
            (locType == "guild"    and showGuilds)

        if allowed then
            -- In ranked mode, drop entries that have no decoded rank (we don't
            -- want bogus "R?" rows). In total mode, all family entries count.
            local rankSlot
            if groupByRank then
                if not loc.rank then
                    allowed = false
                else
                    rankSlot = loc.rank
                end
            end

            if allowed then
                if locType == "warband" then
                    local key = "WARBAND|" .. (rankSlot or "_")
                    local b = bucket(key, L["TIPS_ITEMTRACKER_WARBAND"], "warband", nil, locType, rankSlot)
                    b.count = b.count + (loc.count or 0)
                elseif locType == "guild" then
                    local gn = loc.guildName or "?"
                    local key = "GUILD|" .. gn .. "|" .. (rankSlot or "_")
                    local b = bucket(key, gn, "guild", nil, locType, rankSlot)
                    b.count = b.count + (loc.count or 0)
                elseif loc.charKey then
                    local key = loc.charKey .. "|" .. locType .. "|" .. (rankSlot or "_")
                    local b = bucket(key, loc.name or loc.charKey, "char", loc.class, locType, rankSlot)
                    b.count = b.count + (loc.count or 0)
                end
            end
        end
    end

    -- Display order: chars first (alpha), then warband, then guilds.
    -- Within an owner: location asc, then rank asc.
    table.sort(order, function(a, b)
        local ea, eb = buckets[a], buckets[b]
        local kindOrder = { char = 1, warband = 2, guild = 3 }
        local ka, kb = kindOrder[ea.ownerKind] or 9, kindOrder[eb.ownerKind] or 9
        if ka ~= kb then return ka < kb end
        if (ea.ownerName or "") ~= (eb.ownerName or "") then
            return (ea.ownerName or "") < (eb.ownerName or "")
        end
        if (ea.locationType or "") ~= (eb.locationType or "") then
            return (ea.locationType or "") < (eb.locationType or "")
        end
        return (ea.rank or 0) < (eb.rank or 0)
    end)

    local rows  = {}
    local total = 0
    for _, key in ipairs(order) do
        local b = buckets[key]
        total = total + b.count
        table.insert(rows, {
            ownerName    = b.ownerName,
            ownerKind    = b.ownerKind,
            class        = b.class,
            locationType = b.locationType,
            label        = locLabels[b.locationType] or b.locationType,
            rank         = b.rank,
            count        = b.count,
        })
    end

    return rows, total
end

-- Render one tracker row to a tooltip line of the shape:
--   "  OwnerName       Loc xN"      (groupByRank = false)
--   "  OwnerName       Loc R# xN"   (groupByRank = true)
-- Warband / guild owners get the matching atlas icon prefixed.
local function FormatTrackerRow(row, colorByClass)
    local right = row.label
    if row.rank then
        right = right .. "  R" .. row.rank
    end
    right = right .. " x" .. row.count

    if row.ownerKind == "char" then
        local r, g, b = 0.9, 0.9, 0.9
        if colorByClass and row.class then r, g, b = GetClassColor(row.class) end
        return {
            type  = "double",
            left  = "  " .. row.ownerName,
            right = right,
            lr = r,   lg = g,   lb = b,
            rr = 1.0, rg = 1.0, rb = 1.0,
        }
    elseif row.ownerKind == "warband" then
        local icon = CreateAtlasMarkup("warband-icon", 16, 16)
        return {
            type  = "double",
            left  = "  " .. icon .. " " .. row.ownerName,
            right = right,
            lr = 0.7, lg = 0.7, lb = 0.7,
            rr = 1.0, rg = 1.0, rb = 1.0,
        }
    elseif row.ownerKind == "guild" then
        local icon = CreateAtlasMarkup("communities-icon-guild", 16, 16)
        return {
            type  = "double",
            left  = "  " .. icon .. " " .. row.ownerName,
            right = right,
            lr = 0.7, lg = 0.7, lb = 0.7,
            rr = 1.0, rg = 1.0, rb = 1.0,
        }
    end
end

local function ItemTrackerProvider(tooltip, context)
    if not context.itemID then return nil end

    local L   = OneWoW.L
    local db  = OneWoW.db and OneWoW.db.global and OneWoW.db.global.settings
    local cfg = db and db.tooltips and db.tooltips.itemtracker

    local showAlts      = cfg == nil or cfg.showAlts      ~= false
    local showVendors   = cfg == nil or cfg.showVendors   ~= false
    local showInstances = cfg == nil or cfg.showInstances ~= false

    local maxChars     = cfg and cfg.characterLimit or 10
    local colorByClass = cfg == nil or cfg.colorByClass ~= false

    local lines = {}

    -- The "item family" = hovered itemID + all sibling rank itemIDs of the same
    -- crafted item. Tooltip behavior is identical regardless of which rank is
    -- hovered; Shift switches between family-totals and per-rank breakdown.
    local idx        = GetItemIndex()
    local familyLocs = idx and idx:GetFamilyLocations(context.itemID) or nil

    if familyLocs then
        -- Count distinct decoded ranks across the family. The Shift breakdown
        -- only makes sense when ≥ 2 ranks exist; otherwise the hint is hidden.
        local rankSet = {}
        for _, loc in ipairs(familyLocs) do
            if loc.rank then rankSet[loc.rank] = true end
        end
        local distinctRanks = 0
        for _ in pairs(rankSet) do distinctRanks = distinctRanks + 1 end
        local hasMultipleRanks = distinctRanks > 1
        local shiftExpand      = hasMultipleRanks and IsShiftKeyDown()

        local rows, total = AggregateFamilyRows(familyLocs, cfg, L, shiftExpand)

        if rows and #rows > 0 then
            table.insert(lines, {
                type  = "double",
                left  = "  " .. L["TIPS_ITEMTRACKER_HEADER"],
                right = string.format(L["TIPS_ITEMTRACKER_TOTAL"], total),
                lr = 0.4, lg = 0.8, lb = 1.0,
                rr = 1.0, rg = 1.0, rb = 1.0,
            })

            local shownChars     = {}
            local shownCharCount = 0
            local capped         = false
            for _, row in ipairs(rows) do
                if row.ownerKind == "char" then
                    if showAlts then
                        if not shownChars[row.ownerName] then
                            if shownCharCount >= maxChars then
                                capped = true
                                break
                            end
                            shownChars[row.ownerName] = true
                            shownCharCount = shownCharCount + 1
                        end
                        table.insert(lines, FormatTrackerRow(row, colorByClass))
                    end
                else
                    table.insert(lines, FormatTrackerRow(row, colorByClass))
                end
            end

            if capped then
                table.insert(lines, { type = "text", text = "  ...", r = 0.7, g = 0.7, b = 0.7 })
            end

            if hasMultipleRanks and not shiftExpand then
                table.insert(lines, {
                    type = "text",
                    text = "  " .. L["TIPS_ITEMTRACKER_HOLD_SHIFT"],
                    r = 0.5, g = 0.5, b = 0.5,
                })
            end
        end
    end

    if showVendors and OneWoW_CatalogData_Vendors_API then
        local vendors = GetVendorData(context.itemID)
        if vendors and #vendors > 0 then
            table.insert(lines, {
                type = "text",
                text = "  " .. L["TIPS_ITEMTRACKER_VENDORS_HEADER"],
                r = 0.4, g = 0.8, b = 1.0,
            })
            local shownV = 0
            for _, vendor in ipairs(vendors) do
                if shownV >= 5 then
                    table.insert(lines, { type = "text", text = "  ...", r = 0.7, g = 0.7, b = 0.7 })
                    break
                end
                local vendorName = vendor.name or "?"
                local zone
                if vendor.locations then
                    for _, loc in pairs(vendor.locations) do
                        zone = loc.zone or loc.subzone
                        break
                    end
                end
                if zone then
                    table.insert(lines, {
                        type  = "double",
                        left  = "    " .. vendorName,
                        right = zone,
                        lr = 0.9, lg = 0.8, lb = 0.5,
                        rr = 0.7, rg = 0.7, rb = 0.7,
                    })
                else
                    table.insert(lines, {
                        type = "text",
                        text = "    " .. vendorName,
                        r = 0.9, g = 0.8, b = 0.5,
                    })
                end
                shownV = shownV + 1
            end
        end
    end

    if showInstances and OneWoW_CatalogData_Journal then
        local instEntries = GetInstanceData(context.itemID)
        if instEntries and #instEntries > 0 then
            table.insert(lines, {
                type = "text",
                text = "  " .. L["TIPS_ITEMTRACKER_INSTANCES_HEADER"],
                r = 0.4, g = 0.8, b = 1.0,
            })
            local shownI = 0
            for _, entry in ipairs(instEntries) do
                if shownI >= 5 then
                    table.insert(lines, { type = "text", text = "  ...", r = 0.7, g = 0.7, b = 0.7 })
                    break
                end
                local rightText = entry.encounterName or L["TIPS_ITEMTRACKER_GENERAL_LOOT"]
                table.insert(lines, {
                    type  = "double",
                    left  = "    " .. entry.instanceName,
                    right = rightText,
                    lr = 0.7, lg = 0.9, lb = 0.7,
                    rr = 0.7, rg = 0.7, rb = 0.7,
                })
                shownI = shownI + 1
            end
        end
    end

    if #lines == 0 then return nil end

    return lines
end

OneWoW.TooltipEngine:RegisterProvider({
    id           = "itemtracker",
    order        = 20,
    featureId    = "itemtracker",
    tooltipTypes = {"item"},
    callback     = ItemTrackerProvider,
})

-- Re-run the tooltip data pipeline whenever Shift state changes while a
-- tooltip is up. RefreshData() re-fires every TooltipDataProcessor postcall,
-- including ours, so the provider can rebuild its lines with the new shift
-- state and produce the compact / expanded view.
do
    local f = CreateFrame("Frame")
    f:RegisterEvent("MODIFIER_STATE_CHANGED")
    f:SetScript("OnEvent", function(_, _, key)
        if key ~= "LSHIFT" and key ~= "RSHIFT" then return end
        if GameTooltip and GameTooltip:IsShown() and GameTooltip.RefreshData then
            GameTooltip:RefreshData()
        end
        if ItemRefTooltip and ItemRefTooltip:IsShown() and ItemRefTooltip.RefreshData then
            ItemRefTooltip:RefreshData()
        end
    end)
end
