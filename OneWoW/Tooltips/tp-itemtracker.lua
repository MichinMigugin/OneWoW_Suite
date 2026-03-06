local ADDON_NAME, OneWoW = ...

local JOURNAL_EXPANSIONS = {
    "Classic", "BurningCrusade", "WrathoftheLichKing", "Cataclysm",
    "MistsofPandaria", "WarlordsofDraenor", "Legion", "BattleforAzeroth",
    "Shadowlands", "Dragonflight", "TheWarWithin", "Midnight",
}

local function GetTrackerData(itemID)
    local storage = _G.OneWoW_AltTracker_Storage
    if storage and storage.ItemIndex then
        return storage.ItemIndex:GetTooltipData(itemID)
    end
    return nil
end

local function GetVendorData(itemID)
    local api = _G.OneWoW_CatalogData_Vendors_API
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

local function AggregateLocations(locations, cfg)
    local chars   = {}
    local warband = 0
    local guilds  = {}

    local showBags     = cfg == nil or cfg.showBags        ~= false
    local showBank     = cfg == nil or cfg.showBank        ~= false
    local showEquipped = cfg == nil or cfg.showEquipped    ~= false
    local showAuctions = cfg == nil or cfg.showAuctions    ~= false
    local showWarband  = cfg == nil or cfg.showWarbandBank ~= false
    local showGuilds   = cfg == nil or cfg.showGuildBanks  ~= false

    for _, loc in ipairs(locations) do
        if loc.locationType == "warband" then
            if showWarband then
                warband = warband + (loc.count or 0)
            end
        elseif loc.locationType == "guild" then
            if showGuilds then
                local gn = loc.guildName or "?"
                guilds[gn] = (guilds[gn] or 0) + (loc.count or 0)
            end
        elseif loc.charKey then
            if not chars[loc.charKey] then
                chars[loc.charKey] = {
                    name     = loc.name,
                    realm    = loc.realm,
                    class    = loc.class,
                    bags     = 0,
                    bank     = 0,
                    equipped = 0,
                    auctions = 0,
                }
            end
            local cd = chars[loc.charKey]
            if     loc.locationType == "bags"     and showBags     then cd.bags     = cd.bags     + (loc.count or 0)
            elseif loc.locationType == "bank"     and showBank     then cd.bank     = cd.bank     + (loc.count or 0)
            elseif loc.locationType == "equipped" and showEquipped then cd.equipped = cd.equipped + 1
            elseif loc.locationType == "auction"  and showAuctions then cd.auctions = cd.auctions + (loc.count or 0)
            end
        end
    end

    local sorted = {}
    for charKey, cd in pairs(chars) do
        local total = cd.bags + cd.bank + cd.equipped + cd.auctions
        table.insert(sorted, { charKey = charKey, data = cd, total = total })
    end
    table.sort(sorted, function(a, b)
        if a.total == b.total then return (a.data.name or "") < (b.data.name or "") end
        return a.total > b.total
    end)

    return sorted, warband, guilds
end

local function FormatLocationText(cd, L)
    local parts = {}
    if cd.bags     > 0 then table.insert(parts, L["TIPS_ITEMTRACKER_BAGS"]    .. ": " .. cd.bags)     end
    if cd.bank     > 0 then table.insert(parts, L["TIPS_ITEMTRACKER_BANK"]    .. ": " .. cd.bank)     end
    if cd.equipped > 0 then table.insert(parts, L["TIPS_ITEMTRACKER_EQUIPPED"])                        end
    if cd.auctions > 0 then table.insert(parts, L["TIPS_ITEMTRACKER_AUCTION"] .. ": " .. cd.auctions) end
    return table.concat(parts, ", ")
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

    local data = GetTrackerData(context.itemID)
    if data then
        local sortedChars, warbandCount, guilds = AggregateLocations(data.locations, cfg)

        local trackerRows = {}

        if showAlts then
            local shown = 0
            for _, entry in ipairs(sortedChars) do
                if shown >= maxChars then
                    table.insert(trackerRows, { type = "text", text = "  ...", r = 0.7, g = 0.7, b = 0.7 })
                    break
                end
                local cd           = entry.data
                local locationText = FormatLocationText(cd, L)
                if locationText ~= "" then
                    local r, g, b = 0.9, 0.9, 0.9
                    if colorByClass and cd.class then
                        r, g, b = GetClassColor(cd.class)
                    end
                    table.insert(trackerRows, {
                        type  = "double",
                        left  = "  " .. (cd.name or entry.charKey),
                        right = locationText,
                        lr = r,   lg = g,   lb = b,
                        rr = 1.0, rg = 1.0, rb = 1.0,
                    })
                    shown = shown + 1
                end
            end
        end

        if warbandCount > 0 then
            local icon = CreateAtlasMarkup("warband-icon", 16, 16)
            table.insert(trackerRows, {
                type  = "double",
                left  = "  " .. icon .. " " .. L["TIPS_ITEMTRACKER_WARBAND"],
                right = L["TIPS_ITEMTRACKER_BANK"] .. ": " .. warbandCount,
                lr = 0.7, lg = 0.7, lb = 0.7,
                rr = 1.0, rg = 1.0, rb = 1.0,
            })
        end

        for guildName, count in pairs(guilds) do
            local icon = CreateAtlasMarkup("communities-icon-guild", 16, 16)
            table.insert(trackerRows, {
                type  = "double",
                left  = "  " .. icon .. " " .. guildName,
                right = L["TIPS_ITEMTRACKER_BANK"] .. ": " .. count,
                lr = 0.7, lg = 0.7, lb = 0.7,
                rr = 1.0, rg = 1.0, rb = 1.0,
            })
        end

        if #trackerRows > 0 then
            table.insert(lines, {
                type  = "double",
                left  = "  " .. L["TIPS_ITEMTRACKER_HEADER"],
                right = string.format(L["TIPS_ITEMTRACKER_TOTAL"], data.totalCount),
                lr = 0.4, lg = 0.8, lb = 1.0,
                rr = 1.0, rg = 1.0, rb = 1.0,
            })
            for _, row in ipairs(trackerRows) do
                table.insert(lines, row)
            end
        end
    end

    if showVendors and _G.OneWoW_CatalogData_Vendors_API then
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

    if showInstances and _G.OneWoW_CatalogData_Journal then
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
