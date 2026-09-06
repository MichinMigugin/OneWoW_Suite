local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local C_Item = C_Item
local C_Map = C_Map
local C_WeeklyRewards = C_WeeklyRewards
local C_PerksActivities = C_PerksActivities
local C_PerksProgram = C_PerksProgram
local C_NeighborhoodInitiative = C_NeighborhoodInitiative
local CreateFrame = CreateFrame
local ipairs, pairs, type = ipairs, pairs, type
local tinsert = tinsert

local L = ns.Locale:GetTable("OneWoW")
local C = OneWoW_GUI.Constants
local GUI = C.GUI

local StatusCards = {}
ns.StatusCards = StatusCards

local PANEL_PADDING = GUI.PADDING
local PORTRAIT_SIZE = 56
local CHIP_RESERVE = 78
local DURABILITY_ALERT_PCT = 25
local COLLECT_ROW_H = 22
local STAT_BAR_H = C.PROGRESS_BAR.HEIGHT
local VAULT_TRACK_GAP = 6
local LIST_HIT_TOOLTIP_MAX = 8
local ZONE_NOTES_HEADER_GAP = 8
local CHARINFO_MIN_HEIGHT = 240

local COLLECT_DEFS = {
    { key = "tmogs",   special = "TMog",    fmt = "STATUSCARD_TMOGS_FORMAT",   icon = "lootroll-icon-transmog", atlas = true },
    { key = "mounts",  special = "Mount",   fmt = "STATUSCARD_MOUNTS_FORMAT",  icon = "icon-mount" },
    { key = "pets",    special = "Pet",     fmt = "STATUSCARD_PETS_FORMAT",    icon = "icon-pet" },
    { key = "toys",    special = "Toy",     fmt = "STATUSCARD_TOYS_FORMAT",    icon = "icon-toy" },
    { key = "recipes", special = "Recipe",  fmt = "STATUSCARD_RECIPES_FORMAT", icon = "icon-recipe" },
    { key = "housing", special = "Housing", fmt = "STATUSCARD_HOUSING_FORMAT", icon = "shop-icon-housing-beds-selected", atlas = true },
    { key = "quests",  special = "Quest",   fmt = "STATUSCARD_QUESTS_FORMAT",  icon = "Quest-Campaign-Available", atlas = true },
}

local function PaintCard(panel, hover)
    if hover then
        panel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
        panel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
    else
        panel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
        panel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    end
    if panel.accent then
        panel.accent:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    end
end

local function CreateThemedCard(parent, opts)
    opts = opts or {}
    local asButton = opts.interactive == true
    local panel = CreateFrame(asButton and "Button" or "Frame", opts.name, parent, "BackdropTemplate")
    panel:SetSize(opts.width or 350, opts.height or 140)
    panel:SetBackdrop(C.BACKDROP_SOFT)
    PaintCard(panel, false)

    local accent = panel:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -4)
    accent:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 4, 4)
    accent:SetWidth(3)
    accent:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    panel.accent = accent
    panel._width = opts.width or 350
    panel.interactive = asButton

    if asButton then
        panel:RegisterForClicks("LeftButtonUp")
        panel:SetScript("OnClick", function()
            if panel.onCardClick then
                panel.onCardClick(panel)
            end
        end)
        panel:SetScript("OnEnter", function(myself)
            PaintCard(myself, true)
            if myself.suppressCardTooltip then
                return
            end
            if myself.clickTooltip then
                GameTooltip:SetOwner(myself, "ANCHOR_LEFT")
                local r, g, b = OneWoW_GUI:GetThemeColor("TEXT_PRIMARY")
                GameTooltip:SetText(myself.clickTooltip, r, g, b)
                GameTooltip:Show()
            end
        end)
        panel:SetScript("OnLeave", function(myself)
            PaintCard(myself, false)
            if not myself.suppressCardTooltip then
                GameTooltip:Hide()
            end
        end)
    end
    return panel
end

local function EquippedDurabilityPercent()
    local cur, max = 0, 0
    for slot = 1, 19 do
        local c, m = GetInventoryItemDurability(slot)
        if c and m and m > 0 then
            cur = cur + c
            max = max + m
        end
    end
    if max == 0 then
        return nil
    end
    return math.floor((cur / max) * 100 + 0.5)
end

local function CountVaultTrack(thresholdType)
    local activities = C_WeeklyRewards.GetActivities(thresholdType)
    if type(activities) ~= "table" or #activities == 0 then
        return 0, 0
    end
    local unlocked = 0
    local slots = #activities
    for i = 1, slots do
        local act = activities[i]
        local need = act.threshold or 0
        if need > 0 and (act.progress or 0) >= need then
            unlocked = unlocked + 1
        end
    end
    return unlocked, slots
end

local function CollectVault()
    local thresholdEnum = Enum.WeeklyRewardChestThresholdType
    local raidU, raidS = CountVaultTrack(thresholdEnum.Raid)
    local dungU, dungS = CountVaultTrack(thresholdEnum.Activities)
    local worldU, worldS = CountVaultTrack(thresholdEnum.World)
    if raidS == 0 and dungS == 0 and worldS == 0 then
        return nil
    end
    return {
        ready = C_WeeklyRewards.HasAvailableRewards() and true or false,
        tracks = {
            { name = RAID, current = raidU, maximum = raidS > 0 and raidS or 3 },
            { name = DUNGEONS, current = dungU, maximum = dungS > 0 and dungS or 3 },
            { name = WORLD, current = worldU, maximum = worldS > 0 and worldS or 3 },
        },
    }
end

local function CollectTradingPost()
    local info = C_PerksActivities.GetPerksActivitiesInfo()
    if not info then
        return nil
    end
    local points, thresholdMax = 0, 0
    if info.activities then
        for _, activity in pairs(info.activities) do
            if activity.completed then
                points = points + (activity.thresholdContributionAmount or 0)
            end
        end
    end
    if info.thresholds then
        for _, threshold in pairs(info.thresholds) do
            local need = threshold.requiredContributionAmount or 0
            if need > thresholdMax then
                thresholdMax = need
            end
        end
    end
    if thresholdMax == 0 then
        return nil
    end
    if points > thresholdMax then
        points = thresholdMax
    end
    local ready = false
    local pending = C_PerksProgram.GetPendingChestRewards()
    if pending then
        for _ in pairs(pending) do
            ready = true
            break
        end
    end
    return { points = points, maximum = thresholdMax, ready = ready }
end

local function CollectEndeavor(request)
    if not C_NeighborhoodInitiative.IsInitiativeEnabled() then
        return nil
    end
    if not C_NeighborhoodInitiative.PlayerHasInitiativeAccess() then
        return nil
    end
    if not C_NeighborhoodInitiative.PlayerMeetsRequiredLevel() then
        return nil
    end
    if request then
        C_NeighborhoodInitiative.RequestNeighborhoodInitiativeInfo()
    end
    local info = C_NeighborhoodInitiative.GetNeighborhoodInitiativeInfo()
    if not info or not info.isLoaded or (info.initiativeID or 0) == 0 then
        return nil
    end
    local maximum = 0
    local milestones = info.milestones
    if milestones and #milestones > 0 then
        maximum = milestones[#milestones].requiredContributionAmount or 0
    end
    if maximum <= 0 then
        maximum = info.progressRequired or 0
    end
    if maximum <= 0 then
        return nil
    end
    local current = info.currentProgress or 0
    if current > maximum then
        current = maximum
    end
    return { current = current, maximum = maximum }
end

function StatusCards:CollectYou(opts)
    opts = opts or {}
    local name = UnitName("player")
    local realm = GetRealmName()
    local className, classFile = UnitClass("player")
    local specName
    local specIndex = C_SpecializationInfo.GetSpecialization()
    if specIndex then
        specName = select(2, C_SpecializationInfo.GetSpecializationInfo(specIndex))
    end
    local guild, _, guildRank = GetGuildInfo("player")
    local _, itemLevelEquipped = GetAverageItemLevel()
    return {
        name = name,
        realm = realm,
        className = className,
        classFile = classFile,
        specName = specName,
        level = UnitLevel("player"),
        faction = UnitFactionGroup("player"),
        guild = guild,
        guildRank = guildRank,
        itemLevel = math.floor(itemLevelEquipped or 0),
        mythicPlusRating = C_ChallengeMode.GetOverallDungeonScore() or 0,
        money = GetMoney(),
        hasMail = HasNewMail() and true or false,
        durability = EquippedDurabilityPercent(),
        vault = opts.vault ~= false and CollectVault() or nil,
        trading = opts.cache ~= false and CollectTradingPost() or nil,
        endeavor = opts.endeavors and CollectEndeavor(opts.requestEndeavors ~= false) or nil,
    }
end

function StatusCards:CollectAlerts()
    local rows = {}
    if OneWoW:IsAddonEnabled("OneWoW_AltTracker") then
        OneWoW:BringUp("OneWoW_AltTracker")
        local api = OneWoW_AltTracker_API
        if api and api.GetAttentionSummary then
            local sum = api.GetAttentionSummary()
            if sum.expiring > 0 then
                rows[#rows + 1] = {
                    key = "ah_expiring",
                    icon = "Interface\\Icons\\INV_Misc_Coin_01",
                    text = string.format(L["STATUSCARD_AUCTIONS_EXPIRING_FORMAT"], sum.expiring),
                }
            end
            if sum.expired > 0 then
                rows[#rows + 1] = {
                    key = "ah_expired",
                    icon = "Interface\\Icons\\INV_Misc_Coin_01",
                    text = string.format(L["STATUSCARD_AUCTIONS_EXPIRED_FORMAT"], sum.expired),
                }
            end
            if sum.goldWaiting > 0 then
                rows[#rows + 1] = {
                    key = "ah_gold",
                    icon = "Interface\\Icons\\INV_Misc_Coin_01",
                    text = string.format(L["STATUSCARD_AUCTIONS_GOLD_FORMAT"], ns.Format.FormatGold(sum.goldWaiting)),
                }
            end
            if sum.altsWithMail > 0 then
                rows[#rows + 1] = {
                    key = "alts_mail",
                    icon = "Interface\\Minimap\\Tracking\\Mailbox",
                    text = string.format(L["STATUSCARD_ALTS_MAIL_FORMAT"], sum.altsWithMail),
                }
            end
        end
    end
    return rows
end

local function MapParent(mapID)
    local info = C_Map.GetMapInfo(mapID)
    return info and info.parentMapID or nil
end

local function NpcOnPlaceMaps(npc, seeds)
    if not npc or not npc.locations then
        return false
    end
    local seedSet, seedParentSet = {}, {}
    for i = 1, #seeds do
        local id = seeds[i]
        if id then
            seedSet[id] = true
            local parent = MapParent(id)
            if parent then
                seedParentSet[parent] = true
            end
        end
    end
    for mapID in pairs(npc.locations) do
        if type(mapID) == "number" then
            if seedSet[mapID] or seedParentSet[mapID] then
                return true
            end
            local locParent = MapParent(mapID)
            if locParent and seedSet[locParent] then
                return true
            end
        end
    end
    return false
end

local function ItemDisplayName(itemID)
    local name = C_Item.GetItemNameByID(itemID)
    if (not name or name == "") and OneWoW_Catalog_API then
        name = OneWoW_Catalog_API.GetCachedItemName(itemID)
    end
    if name and name ~= "" then
        return name
    end
    return "#" .. itemID
end

local function CollectShoppingHits(place)
    local hits = {}
    if not OneWoW:IsAddonEnabled("OneWoW_ShoppingList") then
        return hits
    end
    OneWoW:BringUp("OneWoW_ShoppingList")
    local sl = OneWoW_ShoppingList_API
    if not sl then
        return hits
    end
    local seen = {}
    local function AddHit(itemID)
        itemID = tonumber(itemID)
        if not itemID or seen[itemID] or not sl.IsStillNeeded(itemID) then
            return
        end
        seen[itemID] = true
        local lists = {}
        local onList, listNames = sl.IsOnAnyList(itemID)
        if onList then
            lists = listNames
        end
        hits[#hits + 1] = { id = itemID, name = ItemDisplayName(itemID), lists = lists }
    end

    local instData = place and place.data
    if instData then
        for _, enc in ipairs(instData.encounters or {}) do
            for _, item in ipairs(enc.items or {}) do
                AddHit(item.itemID)
            end
        end
    end
    local needed = sl.GetStillNeededItemIDs()
    if #needed == 0 then
        return hits
    end
    if OneWoW:IsCatalogPackAvailable("vendors") then
        OneWoW:EnsureCatalogPack("vendors")
    end
    local npcAPI = OneWoW:GetCatalogPackAPI("vendors")
    if not npcAPI then
        return hits
    end
    local seeds = {}
    local uiMapID = C_Map.GetBestMapForUnit("player")
    if uiMapID then
        seeds[#seeds + 1] = uiMapID
    end
    if place and place.mapID then
        seeds[#seeds + 1] = place.mapID
    end
    for i = 1, #needed do
        local itemID = needed[i]
        if not seen[itemID] then
            local npcs = npcAPI.GetNPCsByItem(itemID)
            for j = 1, #npcs do
                if NpcOnPlaceMaps(npcs[j], seeds) then
                    AddHit(itemID)
                    break
                end
            end
        end
    end
    return hits
end

local function NoteSnippet(text)
    if not text or text == "" then
        return ""
    end
    text = text:gsub("%s+", " ")
    if #text > 80 then
        return text:sub(1, 77) .. "..."
    end
    return text
end

local function CollectZoneNoteAlerts(matches)
    local hits = {}
    for i = 1, #(matches or {}) do
        local row = matches[i]
        local data = row and row.data
        if data then
            local hasBody = data.content and data.content ~= ""
            local todos = {}
            for _, todo in ipairs(data.todos or {}) do
                if not todo.completed and todo.text and todo.text ~= "" then
                    todos[#todos + 1] = todo.text
                end
            end
            if hasBody or #todos > 0 then
                local title = data.zone or ""
                if data.subzone and data.subzone ~= "" then
                    title = title .. " - " .. data.subzone
                end
                hits[#hits + 1] = {
                    id = row.id,
                    title = title,
                    snippet = NoteSnippet(data.content),
                    todos = todos,
                }
            end
        end
    end
    return hits
end

local function CollectFarmingAlerts(place)
    if not OneWoW:IsAddonEnabled("OneWoW_Notes") then
        return {}
    end
    OneWoW:BringUp("OneWoW_Notes")
    local api = OneWoW_Notes_API
    if not api or not api.FindFarmingNotesForPlace then
        return {}
    end
    local names = {}
    local zoneText = GetZoneText()
    if zoneText and zoneText ~= "" then
        names[#names + 1] = zoneText
    end
    local instName = GetInstanceInfo()
    if instName and instName ~= "" then
        names[#names + 1] = instName
    end
    if place and place.liveName and place.liveName ~= "" then
        names[#names + 1] = place.liveName
    end
    local instData = place and place.data
    if instData and instData.name and instData.name ~= "" then
        names[#names + 1] = instData.name
    end
    local raw = api.FindFarmingNotesForPlace(names)
    local hits = {}
    for i = 1, #raw do
        local row = raw[i]
        hits[#hits + 1] = {
            id = row.id,
            title = row.title or "",
            itemName = row.itemName or "",
            snippet = NoteSnippet(row.content),
        }
    end
    return hits
end

local function CollectTrackerAlerts(place)
    if not OneWoW:IsAddonEnabled("OneWoW_Trackers") then
        return {}
    end
    OneWoW:BringUp("OneWoW_Trackers")
    local api = OneWoW_Trackers_API
    if not api or not api.GetIncompleteHitsForMap then
        return {}
    end
    local mapIDs = {}
    local uiMapID = C_Map.GetBestMapForUnit("player")
    if uiMapID then
        mapIDs[#mapIDs + 1] = uiMapID
        local parent = MapParent(uiMapID)
        if parent then
            mapIDs[#mapIDs + 1] = parent
        end
    end
    if place and place.mapID then
        mapIDs[#mapIDs + 1] = place.mapID
    end
    return api.GetIncompleteHitsForMap(mapIDs)
end

local function ResolveCurrentPlace()
    OneWoW:EnsureCatalogPack("items")
    OneWoW:EnsureCatalogPack("journal")
    local api = OneWoW:GetCatalogPackAPI("journal")
    if not api then
        return nil
    end
    local instName, instanceType, _, diffName, _, _, _, instanceMapID = GetInstanceInfo()
    local uiMapID = C_Map.GetBestMapForUnit("player")
    local instData
    if instanceMapID and instanceType and instanceType ~= "none" and api.GetInstanceByMapID then
        instData = api.GetInstanceByMapID(instanceMapID)
    end
    if not instData and uiMapID and api.GetZoneInstance then
        instData = api.GetZoneInstance(nil, uiMapID)
    end
    if not instData and instanceMapID and api.GetInstanceByMapID then
        instData = api.GetInstanceByMapID(instanceMapID)
    end
    if not instData then
        return nil
    end
    if api.EnsureEncounters then
        api.EnsureEncounters(instData)
    end
    return {
        data = instData,
        api = api,
        liveName = instName,
        instanceType = instanceType,
        diffName = diffName,
        mapID = instData.mapID or instData.uiMapID or uiMapID or instanceMapID,
    }
end

local function PlaceTypeLabel(instData)
    local itype = instData and instData.instanceType
    if itype == "party" then
        return MAP_LEGEND_DUNGEON
    elseif itype == "raid" then
        return MAP_LEGEND_RAID
    elseif itype == "delve" then
        return MAP_LEGEND_DELVE
    elseif itype == "zone" then
        if instData.isCity then
            return L["STATUSCARD_CITY"]
        end
        return ZONE
    elseif itype == "world" then
        return WORLD
    end
    return L["STATUSCARD_INSTANCE"]
end

local function CountPlaceCollections(instData, api)
    local counts = {}
    local keyMap = {}
    for i = 1, #COLLECT_DEFS do
        counts[COLLECT_DEFS[i].key] = { current = 0, total = 0 }
        keyMap[COLLECT_DEFS[i].special] = COLLECT_DEFS[i].key
    end
    for _, enc in ipairs(instData.encounters or {}) do
        for _, item in ipairs(enc.items or {}) do
            local key = keyMap[item.special]
            if key then
                local row = counts[key]
                row.total = row.total + 1
                if api.IsItemCollected(item.itemID, item.itemData, item.special) then
                    row.current = row.current + 1
                end
            end
        end
    end
    return counts
end

function StatusCards:CollectHere(opts)
    opts = opts or {}
    if OneWoW:IsAddonEnabled("OneWoW_Notes") then
        OneWoW:BringUp("OneWoW_Notes")
    end
    local place = ResolveCurrentPlace()
    local zoneText = GetZoneText() or ""
    local subZoneText = GetSubZoneText() or ""
    if subZoneText == zoneText then
        subZoneText = ""
    end
    local displayZone = zoneText
    local api = OneWoW_Notes_API
    if api and api.GetCurrentZoneName then
        local currentName = api.GetCurrentZoneName()
        if currentName and currentName ~= "" then
            displayZone = currentName
        end
    end
    local zoneMatches = (api and api.FindMatchingZoneNotes) and api.FindMatchingZoneNotes(zoneText, subZoneText) or {}
    local first = zoneMatches[1]
    local mapID = C_Map.GetBestMapForUnit("player")
    local pins = (api and api.GetWayPinsForMap and mapID) and api.GetWayPinsForMap(mapID) or {}
    return {
        place = place,
        displayZone = displayZone,
        alerts = {
            shopping = CollectShoppingHits(place),
            notes = CollectZoneNoteAlerts(zoneMatches),
            farming = CollectFarmingAlerts(place),
            trackers = CollectTrackerAlerts(place),
        },
        noteId = first and first.id or nil,
        zoneData = first and first.data or nil,
        pins = pins,
    }
end

local function AlertSourceTitle(sourceKey)
    if sourceKey == "shopping" then
        return L["MODULE_SHOPPINGLIST"]
    end
    if sourceKey == "notes" then
        return L["STATUSCARD_NOTES_HERE"]
    end
    if sourceKey == "trackers" then
        return L["MODULE_TRACKERS"]
    end
    return L["FARMING"]
end

local function ShowItemAlertTooltip(btn, interactive)
    GameTooltip:SetOwner(btn, "ANCHOR_LEFT")
    local r, g, b = OneWoW_GUI:GetThemeColor("TEXT_PRIMARY")
    local sr, sg, sb = OneWoW_GUI:GetThemeColor("TEXT_SECONDARY")
    local title = AlertSourceTitle(btn.sourceKey)
    GameTooltip:SetText(title, r, g, b)
    local hits = btn.hits
    if not hits or #hits == 0 then
        GameTooltip:AddLine(L["STATUSCARD_SOURCE_EMPTY"], sr, sg, sb, true)
        GameTooltip:Show()
        return
    end
    local shown = 0
    if btn.sourceKey == "shopping" then
        local listsSeen = {}
        for i = 1, #hits do
            for _, listName in ipairs(hits[i].lists or {}) do
                if listName ~= "" and not listsSeen[listName] then
                    listsSeen[listName] = true
                    GameTooltip:AddLine(listName, r, g, b)
                end
            end
        end
        for i = 1, #hits do
            if shown >= LIST_HIT_TOOLTIP_MAX then
                GameTooltip:AddLine(string.format(L["STATUSCARD_LISTS_MORE_FORMAT"], #hits - shown), sr, sg, sb)
                break
            end
            GameTooltip:AddLine(hits[i].name, sr, sg, sb)
            shown = shown + 1
        end
    elseif btn.sourceKey == "notes" then
        for i = 1, #hits do
            if shown >= LIST_HIT_TOOLTIP_MAX then
                GameTooltip:AddLine(string.format(L["STATUSCARD_LISTS_MORE_FORMAT"], #hits - shown), sr, sg, sb)
                break
            end
            local row = hits[i]
            GameTooltip:AddLine(row.title, r, g, b)
            if row.snippet ~= "" then
                GameTooltip:AddLine(row.snippet, sr, sg, sb, true)
            end
            for t = 1, #row.todos do
                GameTooltip:AddLine("  - " .. row.todos[t], sr, sg, sb)
            end
            shown = shown + 1
        end
    elseif btn.sourceKey == "farming" then
        for i = 1, #hits do
            if shown >= LIST_HIT_TOOLTIP_MAX then
                GameTooltip:AddLine(string.format(L["STATUSCARD_LISTS_MORE_FORMAT"], #hits - shown), sr, sg, sb)
                break
            end
            local row = hits[i]
            GameTooltip:AddLine(row.title, r, g, b)
            if row.itemName ~= "" then
                GameTooltip:AddLine(row.itemName, sr, sg, sb)
            end
            if row.snippet ~= "" then
                GameTooltip:AddLine(row.snippet, sr, sg, sb, true)
            end
            shown = shown + 1
        end
    else
        for i = 1, #hits do
            if shown >= LIST_HIT_TOOLTIP_MAX then
                GameTooltip:AddLine(string.format(L["STATUSCARD_LISTS_MORE_FORMAT"], #hits - shown), sr, sg, sb)
                break
            end
            local row = hits[i]
            GameTooltip:AddLine(row.title, r, g, b)
            for s = 1, #row.steps do
                GameTooltip:AddLine(row.steps[s], sr, sg, sb)
            end
            shown = shown + 1
        end
    end
    if interactive then
        GameTooltip:AddLine(string.format(L["STATUSCARD_CLICK_OPEN_FORMAT"], title), sr, sg, sb, true)
    end
    GameTooltip:Show()
end

local function WireItemAlertRow(panel, row)
    row:ForEachIcon(function(btn)
        btn:SetScript("OnEnter", function(myself)
            panel.suppressCardTooltip = true
            GameTooltip:Hide()
            ShowItemAlertTooltip(myself, panel.interactive)
        end)
        btn:SetScript("OnLeave", function()
            panel.suppressCardTooltip = false
            GameTooltip:Hide()
        end)
    end)
end

local function LayoutSectionHeader(panel, label, readyFS, y, ready)
    label:ClearAllPoints()
    label:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_PADDING + 4, -y)
    if ready then
        readyFS:ClearAllPoints()
        readyFS:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PANEL_PADDING, -y)
        readyFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
        readyFS:Show()
        label:SetPoint("TOPRIGHT", readyFS, "TOPLEFT", -6, 0)
    else
        readyFS:Hide()
        label:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PANEL_PADDING, -y)
    end
    label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    label:Show()
    return y + (label:GetStringHeight() or 10) + 3
end

local function EnsureWeeklyChrome(panel)
    if panel.vaultTracks then
        return
    end
    local vaultLabel = OneWoW_GUI:CreateFS(panel, 10)
    vaultLabel:SetJustifyH("LEFT")
    vaultLabel:SetWordWrap(false)
    vaultLabel:SetText(DELVES_GREAT_VAULT_LABEL)
    panel.vaultLabel = vaultLabel

    local vaultReady = OneWoW_GUI:CreateFS(panel, 10)
    vaultReady:SetJustifyH("RIGHT")
    vaultReady:SetWordWrap(false)
    vaultReady:SetText(CLAIM_REWARD)
    panel.vaultReady = vaultReady

    panel.vaultTracks = {}
    for i = 1, 3 do
        local col = CreateFrame("Frame", nil, panel)
        col:EnableMouse(false)
        local label = OneWoW_GUI:CreateFS(col, 10)
        label:SetPoint("TOPLEFT", col, "TOPLEFT", 0, 0)
        label:SetPoint("TOPRIGHT", col, "TOPRIGHT", 0, 0)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        col.label = label
        local bar = OneWoW_GUI:CreateProgressBar(col, { height = STAT_BAR_H, min = 0, max = 3, value = 0 })
        bar:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -3)
        bar:SetPoint("TOPRIGHT", label, "BOTTOMRIGHT", 0, -3)
        bar:EnableMouse(false)
        col.bar = bar
        panel.vaultTracks[i] = col
    end

    local tradingLabel = OneWoW_GUI:CreateFS(panel, 10)
    tradingLabel:SetJustifyH("LEFT")
    tradingLabel:SetWordWrap(false)
    tradingLabel:SetText(MONTHLY_ACTIVITIES_POINTS)
    panel.tradingLabel = tradingLabel

    local tradingReady = OneWoW_GUI:CreateFS(panel, 10)
    tradingReady:SetJustifyH("RIGHT")
    tradingReady:SetWordWrap(false)
    tradingReady:SetText(L["STATUSCARD_CACHE_AVAILABLE"])
    panel.tradingReady = tradingReady

    local tradingBar = OneWoW_GUI:CreateProgressBar(panel, { height = STAT_BAR_H, min = 0, max = 1, value = 0 })
    tradingBar:EnableMouse(false)
    panel.tradingBar = tradingBar
end

local function EnsureEndeavorChrome(panel)
    if panel.endeavorBar then
        return
    end
    local endeavorLabel = OneWoW_GUI:CreateFS(panel, 10)
    endeavorLabel:SetJustifyH("LEFT")
    endeavorLabel:SetWordWrap(false)
    endeavorLabel:SetText(HOUSING_DASHBOARD_ENDEAVOR)
    panel.endeavorLabel = endeavorLabel
    local endeavorBar = OneWoW_GUI:CreateProgressBar(panel, { height = STAT_BAR_H, min = 0, max = 1, value = 0 })
    endeavorBar:EnableMouse(false)
    panel.endeavorBar = endeavorBar
end

function StatusCards:CreateYou(parent, opts)
    opts = opts or {}
    local panel = CreateThemedCard(parent, {
        name = opts.name,
        width = opts.width,
        height = CHARINFO_MIN_HEIGHT,
        interactive = opts.interactive,
    })
    panel.onCardClick = opts.onYouClick
    panel.clickTooltip = opts.interactive and L["STATUSCARD_CLICK_CHARACTER"] or nil
    panel.showMail = opts.mail ~= false
    panel.showDurability = opts.durability ~= false
    panel.showVault = opts.vault ~= false
    panel.showCache = opts.cache ~= false
    panel.showEndeavors = opts.endeavors ~= false
    panel.showTimer = opts.timer == true

    local chips = CreateFrame("Frame", nil, panel)
    chips:SetSize(CHIP_RESERVE, 36)
    chips:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PANEL_PADDING, -PANEL_PADDING)
    chips:EnableMouse(false)
    panel.chips = chips

    local duraText = OneWoW_GUI:CreateFS(chips, 11)
    duraText:SetPoint("TOPRIGHT", chips, "TOPRIGHT", 0, 0)
    duraText:SetJustifyH("RIGHT")
    duraText:SetWordWrap(false)
    panel.duraText = duraText

    local mailIcon = chips:CreateTexture(nil, "ARTWORK")
    mailIcon:SetSize(16, 16)
    mailIcon:SetPoint("TOPRIGHT", duraText, "TOPLEFT", -6, 1)
    mailIcon:SetTexture("Interface\\Minimap\\Tracking\\Mailbox")
    mailIcon:Hide()
    panel.mailIcon = mailIcon

    if panel.showTimer then
        local timerText = OneWoW_GUI:CreateFS(chips, 11)
        timerText:SetPoint("TOPRIGHT", duraText, "BOTTOMRIGHT", 0, -4)
        timerText:SetJustifyH("RIGHT")
        timerText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        panel.timerText = timerText
    end

    panel.portraitFrame = OneWoW_GUI:CreatePortraitWithFaction(panel, { size = PORTRAIT_SIZE })
    panel.portraitFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_PADDING + 4, -PANEL_PADDING)

    local nameText = OneWoW_GUI:CreateFS(panel, 15)
    nameText:SetPoint("TOPLEFT", panel.portraitFrame, "TOPRIGHT", 10, -2)
    nameText:SetPoint("TOPRIGHT", chips, "TOPLEFT", -8, -2)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    panel.nameText = nameText

    local specText = OneWoW_GUI:CreateFS(panel, 11)
    specText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -4)
    specText:SetPoint("TOPRIGHT", nameText, "BOTTOMRIGHT", 0, -4)
    specText:SetJustifyH("LEFT")
    specText:SetWordWrap(false)
    panel.specText = specText

    local guildText = OneWoW_GUI:CreateFS(panel, 11)
    guildText:SetPoint("TOPLEFT", specText, "BOTTOMLEFT", 0, -3)
    guildText:SetPoint("TOPRIGHT", specText, "BOTTOMRIGHT", 0, -3)
    guildText:SetJustifyH("LEFT")
    guildText:SetWordWrap(false)
    panel.guildText = guildText

    local strip = OneWoW_GUI:CreateSummaryStrip(panel, {
        height = GUI.SUMMARY_STRIP_HEIGHT,
        insetX = PANEL_PADDING,
        yOffset = -(PANEL_PADDING + PORTRAIT_SIZE + 20),
        items = {
            { value = "", label = STAT_AVERAGE_ITEM_LEVEL, valueColor = "TEXT_ACCENT" },
            { value = "", label = DUNGEON_SCORE, valueColor = "TEXT_ACCENT" },
            { value = "", label = MONEY, valueColor = "TEXT_ACCENT" },
        },
    })
    strip:EnableMouse(false)
    panel.statStrip = strip
    EnsureWeeklyChrome(panel)
    return panel
end

function StatusCards:SetYouTimer(panel, elapsed)
    if not panel.timerText then
        return
    end
    local minutes = math.floor(elapsed / 60)
    local seconds = math.floor(elapsed % 60)
    panel.timerText:SetFormattedText(L["STATUSCARD_AFK_TIME"], string.format("%02d:%02d", minutes, seconds))
end

function StatusCards:RefreshYou(panel, data)
    PaintCard(panel, false)
    panel.portraitFrame:SetUnit("player")
    panel.portraitFrame:SetFaction(data.faction)
    panel.portraitFrame:SetClassBorder(data.classFile)

    local classColor = (data.classFile and RAID_CLASS_COLORS[data.classFile]) or { r = 1, g = 1, b = 1 }
    if panel.showMail and data.hasMail then
        panel.mailIcon:Show()
    else
        panel.mailIcon:Hide()
    end

    if panel.showDurability and data.durability then
        panel.duraText:SetFormattedText("%d%%", data.durability)
        if data.durability <= DURABILITY_ALERT_PCT then
            panel.duraText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
        else
            panel.duraText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        end
        panel.duraText:Show()
    else
        panel.duraText:Hide()
    end

    panel.nameText:SetFormattedText("%s-%s", data.name, data.realm)
    panel.nameText:SetTextColor(classColor.r, classColor.g, classColor.b, 1)

    local classPart = data.className or ""
    if data.specName and data.specName ~= "" then
        classPart = data.specName .. " " .. classPart
    end
    panel.specText:SetFormattedText(DUNGEON_SCORE_LINK_LEVEL_CLASS_FORMAT_STRING, data.level, classPart)
    panel.specText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    if data.guild and data.guildRank then
        panel.guildText:SetFormattedText("<%s> - %s", data.guild, data.guildRank)
    elseif data.guild then
        panel.guildText:SetFormattedText("<%s>", data.guild)
    else
        panel.guildText:SetText(L["STATUSCARD_NO_GUILD"])
    end
    panel.guildText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    panel.statStrip:SetItemValue(1, tostring(data.itemLevel))
    panel.statStrip:SetItemValue(2, tostring(data.mythicPlusRating))
    panel.statStrip:SetItemValue(3, ns.Format.FormatGold(data.money))

    local identityH = math.max(
        PORTRAIT_SIZE + 8,
        (panel.nameText:GetStringHeight() or 16) + 4
            + (panel.specText:GetStringHeight() or 12) + 3
            + (panel.guildText:GetStringHeight() or 12)
    )
    local stripTop = PANEL_PADDING + identityH + 10
    panel.statStrip:ClearAllPoints()
    panel.statStrip:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_PADDING, -stripTop)
    panel.statStrip:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PANEL_PADDING, -stripTop)
    if panel.statStrip._relayout then
        panel.statStrip._relayout()
    end
    local stripH = panel.statStrip.GetMeasuredHeight and panel.statStrip:GetMeasuredHeight() or GUI.SUMMARY_STRIP_HEIGHT
    local y = stripTop + stripH + 8

    EnsureWeeklyChrome(panel)
    if panel.showVault and data.vault then
        panel.vaultReady:SetText(CLAIM_REWARD)
        y = LayoutSectionHeader(panel, panel.vaultLabel, panel.vaultReady, y, data.vault.ready)
        local innerW = panel._width - 2 * (PANEL_PADDING + 4)
        local colW = (innerW - VAULT_TRACK_GAP * 2) / 3
        local colH = 0
        for i = 1, 3 do
            local col = panel.vaultTracks[i]
            local track = data.vault.tracks[i]
            col:ClearAllPoints()
            col:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_PADDING + 4 + (i - 1) * (colW + VAULT_TRACK_GAP), -y)
            col:SetSize(colW, 28)
            col.label:SetText(track.name)
            col.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            col.bar:UpdateProgress(track.current, track.maximum)
            col:Show()
            colH = math.max(colH, (col.label:GetStringHeight() or 10) + 3 + STAT_BAR_H)
        end
        for i = 1, 3 do
            panel.vaultTracks[i]:SetHeight(colH)
        end
        y = y + colH + 8
    else
        panel.vaultLabel:Hide()
        panel.vaultReady:Hide()
        for i = 1, #panel.vaultTracks do
            panel.vaultTracks[i]:Hide()
        end
    end

    if panel.showCache and data.trading then
        panel.tradingReady:SetText(L["STATUSCARD_CACHE_AVAILABLE"])
        y = LayoutSectionHeader(panel, panel.tradingLabel, panel.tradingReady, y, data.trading.ready)
        panel.tradingBar:ClearAllPoints()
        panel.tradingBar:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_PADDING + 4, -y)
        panel.tradingBar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PANEL_PADDING, -y)
        panel.tradingBar:UpdateProgress(data.trading.points, data.trading.maximum)
        panel.tradingBar:Show()
        y = y + STAT_BAR_H
    else
        panel.tradingLabel:Hide()
        panel.tradingReady:Hide()
        panel.tradingBar:Hide()
    end

    if panel.showEndeavors and data.endeavor then
        EnsureEndeavorChrome(panel)
        if data.trading then
            y = y + 8
        end
        panel.endeavorLabel:ClearAllPoints()
        panel.endeavorLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_PADDING + 4, -y)
        panel.endeavorLabel:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PANEL_PADDING, -y)
        panel.endeavorLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        panel.endeavorLabel:Show()
        y = y + (panel.endeavorLabel:GetStringHeight() or 10) + 3
        panel.endeavorBar:ClearAllPoints()
        panel.endeavorBar:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_PADDING + 4, -y)
        panel.endeavorBar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PANEL_PADDING, -y)
        panel.endeavorBar:UpdateProgress(data.endeavor.current, data.endeavor.maximum)
        panel.endeavorBar:Show()
        y = y + STAT_BAR_H
    elseif panel.endeavorLabel then
        panel.endeavorLabel:Hide()
        panel.endeavorBar:Hide()
    end

    panel:SetHeight(math.max(CHARINFO_MIN_HEIGHT, y + PANEL_PADDING))
    panel:Show()
    return panel
end

local function ApplyCardHeight(panel, contentH)
    if panel.fixedHeight then
        panel:SetHeight(math.max(panel.fixedHeight, contentH))
    else
        panel:SetHeight(contentH)
    end
end

function StatusCards:CreateAlerts(parent, opts)
    opts = opts or {}
    local panel = CreateThemedCard(parent, {
        name = opts.name,
        width = opts.width,
        height = opts.height or 80,
        interactive = false,
    })
    panel.keepVisible = opts.keepVisible == true
    panel.fixedHeight = opts.fixedHeight
    local header = OneWoW_GUI:CreateFS(panel, 12)
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_PADDING + 4, -PANEL_PADDING)
    header:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PANEL_PADDING, -PANEL_PADDING)
    header:SetJustifyH("LEFT")
    header:SetText(L["STATUSCARD_ALERTS"])
    header:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    panel.header = header
    local emptyText = OneWoW_GUI:CreateFS(panel, 11)
    emptyText:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -8)
    emptyText:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -8)
    emptyText:SetJustifyH("LEFT")
    emptyText:SetText(L["STATUSCARD_NO_ALERTS"])
    emptyText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    emptyText:Hide()
    panel.emptyText = emptyText
    panel.rows = {}
    return panel
end

function StatusCards:RefreshAlerts(panel, rows)
    PaintCard(panel, false)
    for i = 1, #panel.rows do
        panel.rows[i]:Hide()
    end
    local headerH = PANEL_PADDING + (panel.header:GetStringHeight() or 12) + 8
    if not rows or #rows == 0 then
        if not panel.keepVisible then
            panel:Hide()
            return nil
        end
        panel.emptyText:Show()
        ApplyCardHeight(panel, headerH + (panel.emptyText:GetStringHeight() or 12) + PANEL_PADDING)
        panel:Show()
        return panel
    end
    panel.emptyText:Hide()
    local y = headerH
    for i = 1, #rows do
        local row = panel.rows[i]
        if not row then
            row = CreateFrame("Frame", nil, panel)
            row:SetHeight(22)
            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetSize(18, 18)
            icon:SetPoint("LEFT", row, "LEFT", 0, 0)
            row.icon = icon
            local text = OneWoW_GUI:CreateFS(row, 11)
            text:SetPoint("LEFT", icon, "RIGHT", 8, 0)
            text:SetPoint("RIGHT", row, "RIGHT", 0, 0)
            text:SetJustifyH("LEFT")
            text:SetWordWrap(false)
            row.text = text
            panel.rows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_PADDING + 4, -y)
        row:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PANEL_PADDING, -y)
        row.icon:SetTexture(rows[i].icon)
        row.text:SetText(rows[i].text)
        row.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        row:Show()
        y = y + 24
    end
    ApplyCardHeight(panel, y + PANEL_PADDING)
    panel:Show()
    return panel
end

local function ApplyCollectIcon(texture, def)
    if def.atlas then
        texture:SetTexture(nil)
        texture:SetAtlas(def.icon)
    else
        OneWoW.OverlayIcons:ApplyToTexture(texture, def.icon)
    end
end

local function AcquireCollectRow(panel, index)
    local row = panel.collectRows[index]
    if row then
        return row
    end
    row = CreateFrame("Frame", nil, panel)
    row:SetHeight(COLLECT_ROW_H)
    row:EnableMouse(false)
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.icon = icon
    local label = OneWoW_GUI:CreateFS(row, 11)
    label:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    row.label = label
    local bar = OneWoW_GUI:CreateProgressBar(row, { height = 8, min = 0, max = 1, value = 0 })
    bar:SetPoint("LEFT", row, "LEFT", 150, 0)
    bar:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    if bar._text then
        bar._text:Hide()
    end
    bar:EnableMouse(false)
    row.bar = bar
    panel.collectRows[index] = row
    return row
end

function StatusCards:CreateHere(parent, opts)
    opts = opts or {}
    local panel = CreateThemedCard(parent, {
        name = opts.name,
        width = opts.width,
        height = 140,
        interactive = opts.interactive,
    })
    panel.onCardClick = opts.onHereClick
    panel.onAlertClick = opts.onAlertClick
    panel.onManageZone = opts.onManageZone
    panel.clickTooltip = opts.interactive and L["STATUSCARD_CLICK_CATALOG"] or nil
    panel.showCollections = opts.collections ~= false
    panel.showZoneNotes = opts.zoneNotes == true
    panel.flexHeight = opts.flexHeight
    panel.fixedHeight = opts.fixedHeight

    local header = OneWoW_GUI:CreateFS(panel, 16)
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_PADDING + 4, -PANEL_PADDING)
    header:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PANEL_PADDING, -PANEL_PADDING)
    header:SetJustifyH("LEFT")
    header:SetWordWrap(false)
    panel.headerText = header

    local meta = OneWoW_GUI:CreateFS(panel, 11)
    meta:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    meta:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -4)
    meta:SetJustifyH("LEFT")
    meta:SetWordWrap(false)
    panel.metaText = meta

    local counts = OneWoW_GUI:CreateFS(panel, 11)
    counts:SetJustifyH("LEFT")
    counts:SetWordWrap(true)
    panel.countsText = counts

    panel.alertRow = OneWoW_GUI:CreateItemAlertRow(panel, {
        interactive = opts.interactive,
        manyLabel = L["STATUSCARD_ITEM_ALERT_MANY"],
        onClick = function(sourceKey, hits)
            if panel.onAlertClick then
                panel.onAlertClick(sourceKey, hits)
            end
        end,
    })
    WireItemAlertRow(panel, panel.alertRow)

    local overall = OneWoW_GUI:CreateProgressBar(panel, { height = 10, min = 0, max = 1, value = 0 })
    overall:EnableMouse(false)
    panel.overallBar = overall

    local emptyText = OneWoW_GUI:CreateFS(panel, 11)
    emptyText:SetJustifyH("LEFT")
    emptyText:SetWordWrap(true)
    emptyText:Hide()
    panel.emptyText = emptyText
    panel.collectRows = {}

    if panel.showZoneNotes then
        local notesHeader = OneWoW_GUI:CreateFS(panel, 12)
        notesHeader:SetJustifyH("LEFT")
        notesHeader:SetWordWrap(false)
        notesHeader:SetText(L["STATUSCARD_ZONE_NOTES"])
        panel.notesHeader = notesHeader
        panel.contentTexts = {}
        panel.waypinBtns = {}
        local scrollFrame, scrollChild = OneWoW_GUI:CreateScrollFrame(panel, {})
        scrollChild:SetWidth((opts.width or 350) - 40)
        panel.scrollFrame = scrollFrame
        panel.scrollChild = scrollChild
        local actionBtn = OneWoW_GUI:CreateFitTextButton(panel, { text = L["OVR_CARD_MANAGE"], height = 22, minWidth = 100 })
        actionBtn:SetScript("OnClick", function()
            if panel.onManageZone then
                panel.onManageZone(panel)
            end
        end)
        panel.actionBtn = actionBtn
    end
    return panel
end

local function FillZoneNotes(panel, zoneData, pins)
    for _, fs in pairs(panel.contentTexts) do
        fs:Hide()
    end
    for _, btn in ipairs(panel.waypinBtns) do
        btn:Hide()
    end
    local contentY = -5
    local fsIndex = 1
    local width = panel._width - 50

    if zoneData then
        panel.actionBtn:SetFitText(L["OVR_CARD_MANAGE"])
        if zoneData.content and zoneData.content ~= "" then
            if not panel.contentTexts[fsIndex] then
                panel.contentTexts[fsIndex] = OneWoW_GUI:CreateFS(panel.scrollChild, 12)
            end
            local fs = panel.contentTexts[fsIndex]
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", panel.scrollChild, "TOPLEFT", 5, contentY)
            fs:SetWidth(width)
            fs:SetJustifyH("LEFT")
            fs:SetWordWrap(true)
            fs:SetText(zoneData.content)
            fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            fs:Show()
            contentY = contentY - fs:GetStringHeight() - 8
            fsIndex = fsIndex + 1
        end
        local hasIncomplete = false
        for _, todo in ipairs(zoneData.todos or {}) do
            if not todo.completed then
                hasIncomplete = true
                break
            end
        end
        if hasIncomplete then
            if not panel.contentTexts[fsIndex] then
                panel.contentTexts[fsIndex] = OneWoW_GUI:CreateFS(panel.scrollChild, 12)
            end
            local todosHeader = panel.contentTexts[fsIndex]
            todosHeader:ClearAllPoints()
            todosHeader:SetPoint("TOPLEFT", panel.scrollChild, "TOPLEFT", 5, contentY)
            todosHeader:SetText(L["STATUSCARD_ZONE_TODOS"])
            todosHeader:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            todosHeader:Show()
            contentY = contentY - 18
            fsIndex = fsIndex + 1
            for _, todo in ipairs(zoneData.todos) do
                if not todo.completed and todo.text and todo.text ~= "" then
                    if not panel.contentTexts[fsIndex] then
                        panel.contentTexts[fsIndex] = OneWoW_GUI:CreateFS(panel.scrollChild, 12)
                    end
                    local fs = panel.contentTexts[fsIndex]
                    fs:ClearAllPoints()
                    fs:SetPoint("TOPLEFT", panel.scrollChild, "TOPLEFT", 15, contentY)
                    fs:SetWidth(width - 10)
                    fs:SetJustifyH("LEFT")
                    fs:SetText("  - " .. todo.text)
                    fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                    fs:Show()
                    contentY = contentY - 18
                    fsIndex = fsIndex + 1
                end
            end
        end
    else
        panel.actionBtn:SetFitText(L["STATUSCARD_ADD_ZONE_NOTE"])
        if not panel.contentTexts[fsIndex] then
            panel.contentTexts[fsIndex] = OneWoW_GUI:CreateFS(panel.scrollChild, 12)
        end
        local emptyText = panel.contentTexts[fsIndex]
        emptyText:ClearAllPoints()
        emptyText:SetPoint("TOPLEFT", panel.scrollChild, "TOPLEFT", 5, contentY)
        emptyText:SetWidth(width)
        emptyText:SetJustifyH("LEFT")
        emptyText:SetText(L["STATUSCARD_NO_ZONE_NOTES"])
        emptyText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        emptyText:Show()
        contentY = contentY - 24
        fsIndex = 2
    end

    if #pins > 0 then
        if not panel.contentTexts[fsIndex] then
            panel.contentTexts[fsIndex] = OneWoW_GUI:CreateFS(panel.scrollChild, 12)
        end
        local pinsHeader = panel.contentTexts[fsIndex]
        pinsHeader:ClearAllPoints()
        pinsHeader:SetPoint("TOPLEFT", panel.scrollChild, "TOPLEFT", 5, contentY)
        pinsHeader:SetText(L["STATUSCARD_WAYPINS"])
        pinsHeader:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        pinsHeader:Show()
        contentY = contentY - 18
        for i, pin in ipairs(pins) do
            local btn = panel.waypinBtns[i]
            if not btn then
                btn = CreateFrame("Button", nil, panel.scrollChild)
                btn:SetHeight(18)
                local fs = OneWoW_GUI:CreateFS(btn, 11)
                fs:SetAllPoints()
                fs:SetJustifyH("LEFT")
                fs:SetWordWrap(false)
                btn.label = fs
                btn:SetScript("OnClick", function(myself)
                    if myself.pinID and OneWoW_Notes_API and OneWoW_Notes_API.TrackWayPin then
                        OneWoW_Notes_API.TrackWayPin(myself.pinID)
                    end
                end)
                btn:SetScript("OnEnter", function(myself)
                    myself.label:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                end)
                btn:SetScript("OnLeave", function(myself)
                    myself.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                end)
                panel.waypinBtns[i] = btn
            end
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", panel.scrollChild, "TOPLEFT", 15, contentY)
            btn:SetPoint("TOPRIGHT", panel.scrollChild, "TOPRIGHT", -5, contentY)
            btn.pinID = pin.id
            btn.label:SetText(pin.title or "")
            btn.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            btn:Show()
            contentY = contentY - 18
        end
    end
    panel.scrollChild:SetHeight(math.abs(contentY) + 10)
end

function StatusCards:HereHasContent(data)
    if data.place then
        return true
    end
    local alerts = data.alerts
    if alerts.shopping and #alerts.shopping > 0 then
        return true
    end
    if alerts.notes and #alerts.notes > 0 then
        return true
    end
    if alerts.farming and #alerts.farming > 0 then
        return true
    end
    if alerts.trackers and #alerts.trackers > 0 then
        return true
    end
    return false
end

function StatusCards:RefreshHere(panel, data)
    PaintCard(panel, false)
    local place = data.place
    local instData = place and place.data
    local title
    if instData then
        title = instData.name
        if (not title or title == "") and place.liveName and place.liveName ~= "" then
            title = place.liveName
        end
    end
    if not title or title == "" then
        title = (data.displayZone ~= "" and data.displayZone) or L["STATUSCARD_INSTANCE"]
    end
    panel.headerText:SetText(title)
    panel.headerText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    panel.currentNoteId = data.noteId
    panel.openSpec = nil
    if place then
        panel.openSpec = {
            mapID = place.mapID,
            instanceID = instData.instanceID,
            placeKey = instData.placeKey,
        }
    end

    if instData then
        local metaParts = {}
        if instData.expansionName and instData.expansionName ~= "" then
            tinsert(metaParts, instData.expansionName)
        end
        tinsert(metaParts, PlaceTypeLabel(instData))
        if place.diffName and place.diffName ~= "" and place.instanceType ~= "none" then
            tinsert(metaParts, place.diffName)
        end
        panel.metaText:SetText(table.concat(metaParts, " | "))
        panel.metaText:Show()
    else
        panel.metaText:SetText("")
        panel.metaText:Hide()
    end
    panel.metaText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local y = PANEL_PADDING + (panel.headerText:GetStringHeight() or 16)
    if panel.metaText:IsShown() then
        y = y + 4 + (panel.metaText:GetStringHeight() or 12)
    end

    local collected, total = 0, 0
    local visible = {}
    if panel.showCollections and place and instData then
        local catalogData = CountPlaceCollections(instData, place.api)
        for i = 1, #COLLECT_DEFS do
            local def = COLLECT_DEFS[i]
            local row = catalogData[def.key]
            if row and row.total > 0 then
                collected = collected + row.current
                total = total + row.total
                tinsert(visible, { def = def, current = row.current, total = row.total })
            end
        end
    end

    local countParts = {}
    if instData then
        local bossCount = instData.bossCount or 0
        local rareCount = instData.rareCount or 0
        if bossCount > 0 then
            tinsert(countParts, string.format("%s %d", BOSSES, bossCount))
        end
        if rareCount > 0 then
            tinsert(countParts, string.format(L["STATUSCARD_RARES_FORMAT"], rareCount))
        end
        if total > 0 then
            tinsert(countParts, string.format(L["STATUSCARD_COLLECTED_FORMAT"], collected, total))
            local missing = total - collected
            if missing > 0 then
                tinsert(countParts, string.format(L["STATUSCARD_MISSING_FORMAT"], missing))
            end
        end
    end
    if #countParts > 0 then
        panel.countsText:ClearAllPoints()
        panel.countsText:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_PADDING + 4, -y - 3)
        panel.countsText:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PANEL_PADDING, -y - 3)
        panel.countsText:SetText(table.concat(countParts, " | "))
        panel.countsText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        panel.countsText:Show()
        y = y + 3 + (panel.countsText:GetStringHeight() or 12)
    else
        panel.countsText:Hide()
    end

    panel.alertRow:ClearAllPoints()
    panel.alertRow:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_PADDING + 4, -(y + 4))
    panel.alertRow:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PANEL_PADDING, -(y + 4))
    panel.alertRow:SetLabel(L["STATUSCARD_ITEM_ALERT"])
    y = y + 4 + panel.alertRow:SetHits(data.alerts)

    if panel.showCollections and total > 0 then
        panel.emptyText:Hide()
        panel.overallBar:Show()
        panel.overallBar:ClearAllPoints()
        panel.overallBar:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_PADDING + 4, -(y + 8))
        panel.overallBar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PANEL_PADDING, -(y + 8))
        panel.overallBar:UpdateProgress(collected, total)
        if panel.overallBar._text then
            panel.overallBar._text:SetText(string.format("%d/%d", collected, total))
            panel.overallBar._text:Show()
        end
        y = y + 8 + 10
        for i, entry in ipairs(visible) do
            local row = AcquireCollectRow(panel, i)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_PADDING + 4, -(y + 8))
            row:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PANEL_PADDING, -(y + 8))
            ApplyCollectIcon(row.icon, entry.def)
            row.label:SetFormattedText(L[entry.def.fmt], entry.current, entry.total)
            if entry.current >= entry.total then
                row.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
            else
                row.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end
            row.bar:UpdateProgress(entry.current, entry.total)
            row:Show()
            y = y + 8 + COLLECT_ROW_H
        end
        for i = #visible + 1, #panel.collectRows do
            panel.collectRows[i]:Hide()
        end
    else
        panel.overallBar:Hide()
        for i = 1, #panel.collectRows do
            panel.collectRows[i]:Hide()
        end
        if panel.showCollections and place then
            panel.emptyText:Show()
            panel.emptyText:ClearAllPoints()
            panel.emptyText:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_PADDING + 4, -(y + 8))
            panel.emptyText:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PANEL_PADDING, -(y + 8))
            panel.emptyText:SetText(L["STATUSCARD_NO_COLLECTIONS"])
            panel.emptyText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            y = y + 8 + (panel.emptyText:GetStringHeight() or 12)
        else
            panel.emptyText:Hide()
        end
    end

    local collectionsH = y + PANEL_PADDING
    if panel.showZoneNotes then
        local notesTop = collectionsH
        panel.notesHeader:ClearAllPoints()
        panel.notesHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_PADDING + 4, -notesTop)
        panel.notesHeader:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PANEL_PADDING, -notesTop)
        panel.notesHeader:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        panel.notesHeader:Show()
        local notesHeaderH = panel.notesHeader:GetStringHeight() or 12
        local scrollTop = notesTop + notesHeaderH + ZONE_NOTES_HEADER_GAP
        panel.actionBtn:ClearAllPoints()
        panel.actionBtn:SetPoint("BOTTOM", panel, "BOTTOM", 0, 8)
        panel.actionBtn:Show()
        panel.scrollFrame:ClearAllPoints()
        panel.scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -scrollTop)
        panel.scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -14, 35)
        panel.scrollFrame:Show()
        FillZoneNotes(panel, data.zoneData, data.pins or {})
        ApplyCardHeight(panel, collectionsH + math.max(80, panel.flexHeight or 80))
    else
        if panel.notesHeader then
            panel.notesHeader:Hide()
            panel.scrollFrame:Hide()
            panel.actionBtn:Hide()
        end
        ApplyCardHeight(panel, collectionsH)
    end
    panel:Show()
    return panel
end

local TASKLIST_MAX_H = 220

local function AcquireTaskText(panel, index, size)
    local fs = panel.contentTexts[index]
    if fs then
        return fs
    end
    fs = OneWoW_GUI:CreateFS(panel.scrollChild, size or 12)
    panel.contentTexts[index] = fs
    return fs
end

local function FitTaskList(panel, contentH)
    local headerH = 0
    if panel.header:IsShown() and panel.header:GetText() ~= "" then
        headerH = (panel.header:GetStringHeight() or 12) + 8
    end
    local body = math.max(22, contentH)
    local contentH = PANEL_PADDING + headerH + body + 8
    if panel.fixedHeight then
        panel:SetHeight(math.max(panel.fixedHeight, contentH))
        return
    end
    local maxH = panel.maxHeight or TASKLIST_MAX_H
    panel:SetHeight(math.min(maxH, contentH))
end

function StatusCards:CreateTaskList(parent, opts)
    opts = opts or {}
    local panel = CreateThemedCard(parent, {
        name = opts.name,
        width = opts.width,
        height = opts.height or 48,
        interactive = false,
    })
    panel.maxHeight = opts.maxHeight or TASKLIST_MAX_H
    panel.fixedHeight = opts.fixedHeight
    local header = OneWoW_GUI:CreateFS(panel, 12)
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_PADDING + 4, -PANEL_PADDING)
    header:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PANEL_PADDING, -PANEL_PADDING)
    header:SetJustifyH("LEFT")
    header:SetText(opts.header or "")
    header:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    panel.header = header
    if not opts.header or opts.header == "" then
        header:Hide()
    end
    panel.contentTexts = {}
    local scrollFrame, scrollChild = OneWoW_GUI:CreateScrollFrame(panel, { width = opts.width or 350 })
    scrollFrame:ClearAllPoints()
    if header:IsShown() then
        scrollFrame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", -4, -6)
    else
        scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -PANEL_PADDING)
    end
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -14, 8)
    panel.scrollFrame = scrollFrame
    panel.scrollChild = scrollChild
    return panel
end

local function WriteTaskNotes(panel, notes, y, fsIndex, width)
    if not notes or #notes == 0 then
        local empty = AcquireTaskText(panel, fsIndex, 12)
        empty:ClearAllPoints()
        empty:SetPoint("TOPLEFT", panel.scrollChild, "TOPLEFT", 5, y)
        empty:SetWidth(width)
        empty:SetText(L["STATUSCARD_NO_NOTES"])
        empty:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        empty:Show()
        return y - 22, fsIndex + 1
    end
    for _, note in ipairs(notes) do
        local title = AcquireTaskText(panel, fsIndex, 12)
        title:ClearAllPoints()
        title:SetPoint("TOPLEFT", panel.scrollChild, "TOPLEFT", 5, y)
        title:SetWidth(width)
        title:SetText(note.title)
        title:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        title:Show()
        y = y - 20
        fsIndex = fsIndex + 1
        for _, task in ipairs(note.tasks or {}) do
            local fs = AcquireTaskText(panel, fsIndex, 11)
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", panel.scrollChild, "TOPLEFT", 15, y)
            fs:SetWidth(width - 10)
            fs:SetText("  - " .. task)
            fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            fs:Show()
            y = y - 18
            fsIndex = fsIndex + 1
        end
        y = y - 8
    end
    return y, fsIndex
end

function StatusCards:RefreshTaskList(panel, notes)
    PaintCard(panel, false)
    for _, fs in pairs(panel.contentTexts) do
        fs:Hide()
    end
    local y, fsIndex = WriteTaskNotes(panel, notes, -5, 1, panel._width - 50)
    panel.scrollChild:SetHeight(math.abs(y) + 10)
    FitTaskList(panel, math.abs(y) + 10)
    panel:Show()
    return panel
end

function StatusCards:RefreshGroupedTaskList(panel, groups)
    PaintCard(panel, false)
    for _, fs in pairs(panel.contentTexts) do
        fs:Hide()
    end
    panel.header:Hide()
    panel.scrollFrame:ClearAllPoints()
    panel.scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -PANEL_PADDING)
    panel.scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -14, 8)

    local y = -2
    local fsIndex = 1
    local width = panel._width - 50
    for i = 1, #groups do
        local group = groups[i]
        local header = AcquireTaskText(panel, fsIndex, 12)
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", panel.scrollChild, "TOPLEFT", 5, y)
        header:SetWidth(width)
        header:SetText(group.header)
        header:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        header:Show()
        y = y - 20
        fsIndex = fsIndex + 1
        y, fsIndex = WriteTaskNotes(panel, group.notes, y, fsIndex, width)
        if i < #groups then
            y = y - 6
        end
    end
    panel.scrollChild:SetHeight(math.abs(y) + 10)
    FitTaskList(panel, math.abs(y) + 10)
    panel:Show()
    return panel
end
