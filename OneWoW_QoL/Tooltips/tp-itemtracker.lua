local _, ns = ...

local OneWoW = OneWoW

local function GetItemIndex()
    local api = OneWoW_AltTracker_Storage_API
    return api and api.GetItemIndex() or nil
end

local function GetVendorData(itemID)
    local api = OneWoW_CatalogData_Vendors_API
    if api and api.GetVendorsByItem then
        return api.GetVendorsByItem(itemID)
    end
    return {}
end

-- The Journal store owns the drop index and dedupes per instance+encounter, so
-- this only has to supply the tooltip's display fallback.
local function GetInstanceData(itemID)
    local results = {}
    local api = OneWoW_CatalogData_Journal_API
    if not api then
        return results
    end
    for _, drop in ipairs(api.GetItemDropLocations(itemID)) do
        table.insert(results, {
            instanceName  = drop.instanceName or "?",
            encounterName = drop.encounterName,
        })
    end
    return results
end

local function GetCraftData(itemID)
    local results = {}
    local api = OneWoW_CatalogData_Tradeskills_API
    if not api then
        return results
    end
    local seen = {}
    for _, recipe in ipairs(api.GetRecipesByItem(itemID)) do
        local label = recipe.prof or api.GetRecipeProfession(recipe.id)
        if label and not seen[label] then
            seen[label] = true
            results[#results + 1] = { name = label }
        end
    end
    return results
end

local SOURCE_ROW_CAP = 5

local function AppendCappedSourceRows(lines, rows, leftR, leftG, leftB)
    local shown = 0
    for _, row in ipairs(rows) do
        if shown >= SOURCE_ROW_CAP then
            table.insert(lines, { type = "text", text = "  ...", r = 0.7, g = 0.7, b = 0.7 })
            break
        end
        table.insert(lines, {
            type  = "double",
            left  = "    " .. row.left,
            right = row.right,
            lr = leftR, lg = leftG, lb = leftB,
            rr = 0.7, rg = 0.7, rb = 0.7,
        })
        shown = shown + 1
    end
end

local function GetClassColor(class)
    if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
        local c = RAID_CLASS_COLORS[class]
        return c.r, c.g, c.b
    end
    return 0.9, 0.9, 0.9
end

ns.GetClassColor = GetClassColor

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

    local function bucket(key, ownerName, ownerKind, class, locationType, rank, charKey)
        local b = buckets[key]
        if not b then
            b = {
                ownerName    = ownerName,
                ownerKind    = ownerKind,    -- "char" | "warband" | "guild"
                class        = class,
                charKey      = charKey,
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
                    local b = bucket(key, loc.name or loc.charKey, "char", loc.class, locType, rankSlot, loc.charKey)
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
            charKey      = b.charKey,
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

local function ItemTrackerProvider(_, context)
    if not context.itemID then return nil end

    local L   = ns.L
    local cfg = OneWoW.SettingsFeatureRegistry:GetFeatureSettings("tooltips", "itemtracker")

    local showAlts      = cfg.showAlts      ~= false
    local showVendors   = cfg.showVendors   ~= false
    local showInstances = cfg.showInstances ~= false
    local showQuests    = cfg.showQuests    ~= false
    local showCrafted   = cfg.showCrafted   ~= false
    local altScope      = cfg.altScope

    local maxChars     = cfg.characterLimit
    local colorByClass = cfg.colorByClass ~= false

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
                left  = "  " .. L["TIPS_ITEMTRACKER_WHERE_IS"],
                right = string.format(L["TIPS_ITEMTRACKER_TOTAL"], total),
                lr = 0.4, lg = 0.8, lb = 1.0,
                rr = 1.0, rg = 1.0, rb = 1.0,
            })

            local shownChars     = {}
            local shownCharCount = 0
            local capped         = false
            for _, row in ipairs(rows) do
                if row.ownerKind == "char" then
                    if showAlts and OneWoW.AltScope:IsCharIncluded(row.charKey, altScope) then
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

    local sourceBlocks = {}

    if showQuests and OneWoW_CatalogData_Quests_API then
        local questIDs = OneWoW_CatalogData_Quests_API.GetQuestsRewardingItem(context.itemID, false)
        if questIDs then
            local rows = {}
            for _, questID in ipairs(questIDs) do
                local q = OneWoW_CatalogData_Quests_API.GetQuest(questID, false)
                rows[#rows + 1] = {
                    left  = (q and q.name) or tostring(questID),
                    right = BATTLE_PET_SOURCE_2,
                }
            end
            if #rows > 0 then
                sourceBlocks[#sourceBlocks + 1] = { rows = rows, lr = 0.9, lg = 0.85, lb = 0.5 }
            end
        end
    end

    if showVendors and OneWoW_CatalogData_Vendors_API then
        local vendors = GetVendorData(context.itemID)
        if vendors and #vendors > 0 then
            local rows = {}
            for _, vendor in ipairs(vendors) do
                local vendorName = vendor.name or "?"
                local zone
                if vendor.locations then
                    for _, loc in pairs(vendor.locations) do
                        zone = loc.zone or loc.subzone
                        break
                    end
                end
                rows[#rows + 1] = {
                    left  = vendorName,
                    right = zone or BATTLE_PET_SOURCE_3,
                }
            end
            sourceBlocks[#sourceBlocks + 1] = { rows = rows, lr = 0.9, lg = 0.8, lb = 0.5 }
        end
    end

    if showInstances and OneWoW_CatalogData_Journal_API then
        local instEntries = GetInstanceData(context.itemID)
        if instEntries and #instEntries > 0 then
            local rows = {}
            for _, entry in ipairs(instEntries) do
                rows[#rows + 1] = {
                    left  = entry.instanceName,
                    right = entry.encounterName or BATTLE_PET_SOURCE_1,
                }
            end
            sourceBlocks[#sourceBlocks + 1] = { rows = rows, lr = 0.7, lg = 0.9, lb = 0.7 }
        end
    end

    if showCrafted and OneWoW_CatalogData_Tradeskills_API then
        local crafts = GetCraftData(context.itemID)
        if #crafts > 0 then
            local rows = {}
            for _, craft in ipairs(crafts) do
                rows[#rows + 1] = {
                    left  = craft.name,
                    right = BATTLE_PET_SOURCE_4,
                }
            end
            sourceBlocks[#sourceBlocks + 1] = { rows = rows, lr = 0.7, lg = 0.8, lb = 1.0 }
        end
    end

    if #sourceBlocks > 0 then
        table.insert(lines, {
            type = "text",
            text = "  " .. L["TIPS_ITEMTRACKER_WHERE_TO_GET"],
            r = 0.4, g = 0.8, b = 1.0,
        })
        for _, block in ipairs(sourceBlocks) do
            AppendCappedSourceRows(lines, block.rows, block.lr, block.lg, block.lb)
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
-- non-action-bar item tooltip is up. RefreshDataNextUpdate() re-fires every
-- TooltipDataProcessor postcall on the tooltip's next OnUpdate (Blizzard's
-- deferred path), including ours, so the provider can rebuild its lines with
-- the new shift state and produce the compact / expanded view.
--
-- Direct RefreshData() from addon code is unsafe: action-bar tooltips (GetAction)
-- and lines with secret unitToken values error when rebuilt from tainted code.
-- Shift-for-drag off the locked action bar fires MODIFIER_STATE_CHANGED and
-- must be ignored here.
local function RequestItemTrackerTooltipRefresh(tooltip)
    if not tooltip or not tooltip:IsShown() or not tooltip.RefreshDataNextUpdate then
        return
    end

    local data = tooltip.GetPrimaryTooltipData and tooltip:GetPrimaryTooltipData()
    if not data or data.type ~= Enum.TooltipDataType.Item then return end
    if OneWoW.Restriction.IsSecret(data.type) then return end

    local info = tooltip.GetPrimaryTooltipInfo and tooltip:GetPrimaryTooltipInfo()
    if info and info.getterName == "GetAction" then return end

    if GetCursorInfo() then return end

    tooltip:RefreshDataNextUpdate()
end

do
    local f = CreateFrame("Frame")
    f:RegisterEvent("MODIFIER_STATE_CHANGED")
    f:SetScript("OnEvent", function(_, _, key)
        if key ~= "LSHIFT" and key ~= "RSHIFT" then return end
        if OneWoW.Restriction.IsInCombat() then return end
        if not OneWoW.TooltipEngine:IsFeatureEnabled("itemtracker") then return end

        RequestItemTrackerTooltipRefresh(GameTooltip)
        RequestItemTrackerTooltipRefresh(ItemRefTooltip)
    end)
end
