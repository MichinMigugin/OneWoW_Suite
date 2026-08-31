local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local MEDIA = OneWoW_GUI.Constants.MEDIA_BASE
local Detail = ns.Constants.Detail

ns.UI = ns.UI or {}

-- selectedKey is the canonical collectible KEY string ("mount:2240"), not a
-- numeric id — the whole tab is keyed by strings from OneWoW.Collectibles.
local selectedKey    = nil
local categoryFilter  = "All"
local typeFilter      = "All"
local storageFilter   = "All"
local collectedFilter = "All"   -- All | collected | uncollected (live)
local searchFilter    = ""
local currentSort    = { by = "name", ascending = true }

-- Transmog-set rows are collapsible tree parents: their per-slot member
-- appearances are a live, read-only view (never stored records). Expansion state
-- is view-only and keyed by the set's collectible key; sets default collapsed.
local expandedSets       = {}
local CHILD_ROW_HEIGHT   = 28
local HEADER_ROW_HEIGHT  = 30

local detailPanel    = nil
local emptyMessage   = nil
local leftStatusText = nil

-- Intent is the user's plan for a collectible; stored on the record as a plain
-- token. "none" maps to the Blizzard NONE global; the rest are scoped keys.
-- "delete" is the recycle bin (dimmed, sorted last, TTL-purged).
local INTENT_ORDER = { "none", "want", "spotted", "farming", "delete" }

local function IntentLabel(intent)
    if intent == "want" then
        return L["COLLECTIBLE_INTENT_WANT"]
    elseif intent == "spotted" then
        return L["COLLECTIBLE_INTENT_SPOTTED"]
    elseif intent == "farming" then
        return L["COLLECTIBLE_INTENT_FARMING"]
    elseif intent == "delete" then
        return L["COLLECTIBLE_INTENT_DELETE"]
    end
    return NONE
end

-- Live display comes from core at render time; a record only carries a fallback
-- name for search/sort. Returns name, icon, link, sourceText (any may be nil for
-- an item that has not cached yet — callers must tolerate the partial shape).
local function ResolveRow(key, record)
    local display = OneWoW.Collectibles.ResolveDisplay(key)
    local name = (display and display.name) or (record and record.name) or key
    local icon = (display and display.icon) or "Interface\\Icons\\INV_Misc_QuestionMark"
    local link = display and display.link
    local sourceText = display and display.sourceText
    local complete = display and display.name and display.icon and true or false

    -- A transmog set has no native icon/link. When the teaching ensemble item was
    -- captured from a vendor, prefer that item's icon + link so the set shows the
    -- real ensemble (keeping the set's name as the title). Falls back silently to
    -- the member-appearance icon from core while the item is uncached.
    if record and record.sourceItemID then
        local _, itemLink, _, _, _, _, _, _, _, itemIcon = C_Item.GetItemInfo(record.sourceItemID)
        if itemIcon then icon = itemIcon end
        if itemLink then link = itemLink end
    end

    return name, icon, link, sourceText, complete
end

-- Max vendor rows drawn in the "Sold by" section; extras are summarized by the
-- count in the section header.
local MAX_VENDOR_ROWS = 3

-- Base height of the "Sold by" section (label + fixed row area). The captured
-- purchase-block reason line grows it on demand in PopulateSoldBy.
local SOLD_BY_BASE_HEIGHT = 28 + MAX_VENDOR_ROWS * 30

-- Vendor display entries for a record's stored offers, hydrated from the Catalog
-- vendor store when it is loaded (richer name + a location for the waypoint), or
-- rendered straight from the offer snapshot otherwise (opt-out safe).
local function BuildVendorEntries(record)
    local entries = {}
    local offers = record and record.acquisition and record.acquisition.vendorOffers
    if not offers then return entries end

    local api = OneWoW_CatalogData_Vendors_API
    for _, offer in ipairs(offers) do
        local entry = {
            npcID         = offer.npcID,
            name          = offer.npcName,
            cost          = offer.cost,
            currencies    = offer.currencies,
            isPurchasable = offer.isPurchasable,
            blockReason   = offer.blockReason,
            zone          = offer.location and offer.location.zone,
            mapID         = offer.location and offer.location.mapID,
        }
        if api and api.GetVendor then
            local vendor = api.GetVendor(offer.npcID)
            if vendor then
                entry.vendorRecord = vendor
                entry.name = entry.name or vendor.name
                if vendor.locations then
                    for mID, loc in pairs(vendor.locations) do
                        entry.mapID = entry.mapID or mID
                        entry.zone  = entry.zone or (loc and loc.zone)
                        break
                    end
                end
            end
        end
        entry.name = entry.name or UNKNOWN
        entries[#entries + 1] = entry
    end
    return entries
end

-- Human-readable cost string for one offer entry (gold + currencies).
local function FormatCost(entry)
    local parts = {}
    if entry.cost and entry.cost > 0 then
        parts[#parts + 1] = OneWoW.Format.FormatGold(entry.cost)
    end
    if entry.currencies then
        for _, c in ipairs(entry.currencies) do
            if c.amount and c.amount > 0 then
                parts[#parts + 1] = c.amount .. " " .. (c.name or "")
            end
        end
    end
    return table.concat(parts, "  ")
end

function ns.UI.CreateCollectiblesTab(parent)
    do
        local p = ns.db.global.tabSortPrefs.collectibles
        currentSort.by        = ns.UI.NormalizeSortBy(p.by) or "name"
        currentSort.ascending = p.ascending ~= false
        if p.by == "manual" then
            ns.db.global.tabSortPrefs.collectibles = { by = "custom", ascending = p.ascending ~= false }
        end
    end

    -- Re-resolves display when the item cache fills in (appearance sources are
    -- commonly uncached on first view). Armed while the open editor or any
    -- expanded set member is still missing a name.
    local infoWatcher = CreateFrame("Frame")

    local controlPanel = ns.UI.CreateThemedBar(nil, parent)
    controlPanel:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, 0)
    controlPanel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    controlPanel:SetHeight(45)

    local catDD = ns.UI.CreateThemedDropdown(controlPanel, CATEGORY, 140, 25)
    catDD:SetPoint("TOPLEFT", controlPanel, "TOPLEFT", 10, -10)

    local TYPE_FILTER_OPTS = {
        {text = MOUNTS,                  value = "mount"},
        {text = WARDROBE,                value = "appearance"},
        {text = WARDROBE_SETS,           value = "set"},
        {text = PETS,                    value = "pet"},
        {text = TOY_BOX,                 value = "toy"},
        {text = HEIRLOOMS,               value = "heirloom"},
        {text = CATALOG_SHOP_TYPE_DECOR, value = "decor"},
        {text = AUCTION_CATEGORY_RECIPES, value = "recipe"},
    }

    local snapshot = {}
    local flattenedEntries = {}
    local collectibleBag = {}
    local pooledRows = {}
    local searchLower = ""
    local listNeedsItemInfo = false
    local listAPI
    local reorderCtrl

    local function SyncItemInfoWatcher(editorComplete)
        if editorComplete == false or listNeedsItemInfo then
            infoWatcher:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        else
            infoWatcher:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
        end
    end

    local function EntryMatchesFilters(snap, ignoreDim)
        local record = snap.data
        if categoryFilter ~= "All" and ignoreDim ~= "category"
            and record.category ~= categoryFilter then
            return false
        end
        if typeFilter ~= "All" and ignoreDim ~= "type" then
            if snap.collType ~= typeFilter then
                return false
            end
        end
        if storageFilter ~= "All" and ignoreDim ~= "storage"
            and record.storage ~= storageFilter then
            return false
        end
        if collectedFilter ~= "All" and ignoreDim ~= "status" then
            if collectedFilter == "collected" and not snap.collected then return false end
            if collectedFilter == "uncollected" and snap.collected then return false end
        end
        if searchLower ~= "" then
            if not snap.nameLower:find(searchLower, 1, true) then
                return false
            end
        end
        return true
    end

    local function BuildSnapshot()
        wipe(snapshot)
        searchLower = searchFilter:lower()
        local all = ns.Collectibles:GetAll()
        for key, record in pairs(all) do
            if type(record) == "table" then
                local name, icon = ResolveRow(key, record)
                local descriptor = OneWoW.Collectibles.ParseKey(key)
                local state = OneWoW.Collectibles.GetCollectionState(key)
                snapshot[#snapshot + 1] = {
                    key        = key,
                    data       = record,
                    name       = name,
                    nameLower  = name:lower(),
                    icon       = icon,
                    collType   = descriptor and descriptor.type,
                    descriptor = descriptor,
                    collected  = state and state.collected or false,
                }
            end
        end
    end

    local function CountFromSnapshot(ignoreDim)
        local counts = {
            all = 0,
            byCategory = {},
            byStorage = { All = 0, account = 0, character = 0 },
            byType = { All = 0 },
            byStatus = { All = 0, collected = 0, uncollected = 0 },
        }
        for _, opt in ipairs(TYPE_FILTER_OPTS) do
            counts.byType[opt.value] = 0
        end
        for _, snap in ipairs(snapshot) do
            if EntryMatchesFilters(snap, ignoreDim) then
                counts.all = counts.all + 1
                local cat = snap.data.category or "General"
                counts.byCategory[cat] = (counts.byCategory[cat] or 0) + 1
                local stor = snap.data.storage == "character" and "character" or "account"
                counts.byStorage[stor] = (counts.byStorage[stor] or 0) + 1
                counts.byStorage.All = counts.byStorage.All + 1
                if ignoreDim == "type" then
                    if snap.collType then
                        counts.byType[snap.collType] = (counts.byType[snap.collType] or 0) + 1
                    end
                    counts.byType.All = counts.byType.All + 1
                end
                if ignoreDim == "status" then
                    if snap.collected then
                        counts.byStatus.collected = counts.byStatus.collected + 1
                    else
                        counts.byStatus.uncollected = counts.byStatus.uncollected + 1
                    end
                    counts.byStatus.All = counts.byStatus.All + 1
                end
            end
        end
        return counts
    end

    local function RefreshCatOptions()
        local catCounts = CountFromSnapshot("category")
        local opts = {{
            text = ALL,
            value = "All",
            rightText = ns.UI.FormatSectionCount(catCounts.all),
        }}
        for _, c in ipairs(ns.Collectibles:GetCategories()) do
            opts[#opts + 1] = {
                text = c,
                value = c,
                rightText = ns.UI.FormatSectionCount(catCounts.byCategory[c] or 0),
            }
        end
        catDD:SetOptions(opts)
        catDD:SetSelected(categoryFilter)
    end
    RefreshCatOptions()
    catDD.onSelect = function(value)
        categoryFilter = value
        parent.RefreshCollectiblesList()
    end

    local manageCategoriesBtn = OneWoW_GUI:CreateIconButton(controlPanel, {
        iconTexture = MEDIA .. "icon-gears.png",
        size = 20,
        texCoord = { 0.1, 0.9, 0.1, 0.9 },
        tooltipTitle = L["CATMGR_TITLE"],
        tooltipText = L["UI_MANAGE_CATEGORIES_DESC"],
        onClick = function()
            ns.UI.ShowCategoryManager("collectibles")
        end,
    })
    manageCategoriesBtn:SetPoint("LEFT", catDD, "RIGHT", 4, 0)

    local typeDD = ns.UI.CreateThemedDropdown(controlPanel, TYPE, 120, 25)
    typeDD:SetPoint("LEFT", manageCategoriesBtn, "RIGHT", 4, 0)
    local function RefreshTypeOpts()
        local typeCounts = CountFromSnapshot("type")
        local opts = {{
            text = ALL,
            value = "All",
            rightText = ns.UI.FormatSectionCount(typeCounts.byType.All),
        }}
        for _, opt in ipairs(TYPE_FILTER_OPTS) do
            opts[#opts + 1] = {
                text = opt.text,
                value = opt.value,
                rightText = ns.UI.FormatSectionCount(typeCounts.byType[opt.value] or 0),
            }
        end
        typeDD:SetOptions(opts)
        typeDD:SetSelected(typeFilter)
    end
    RefreshTypeOpts()
    typeDD.onSelect = function(value)
        typeFilter = value
        parent.RefreshCollectiblesList()
    end

    local storeDD = ns.UI.CreateThemedDropdown(controlPanel, L["LABEL_STORAGE"], 130, 25)
    storeDD:SetPoint("LEFT", typeDD, "RIGHT", 4, 0)
    local function RefreshStorageOpts()
        local storCounts = CountFromSnapshot("storage")
        storeDD:SetOptions({
            {text = ALL, value = "All",
                rightText = ns.UI.FormatSectionCount(storCounts.byStorage.All)},
            {text = L["UI_STORAGE_ACCOUNT"], value = "account",
                rightText = ns.UI.FormatSectionCount(storCounts.byStorage.account)},
            {text = CHARACTER, value = "character",
                rightText = ns.UI.FormatSectionCount(storCounts.byStorage.character)},
        })
        storeDD:SetSelected(storageFilter)
    end
    RefreshStorageOpts()
    storeDD.onSelect = function(value)
        storageFilter = value
        parent.RefreshCollectiblesList()
    end

    local collectedDD = ns.UI.CreateThemedDropdown(controlPanel, STATUS, 130, 25)
    collectedDD:SetPoint("LEFT", storeDD, "RIGHT", 4, 0)
    local function RefreshCollectedOpts()
        local statusCounts = CountFromSnapshot("status")
        collectedDD:SetOptions({
            {text = ALL, value = "All",
                rightText = ns.UI.FormatSectionCount(statusCounts.byStatus.All)},
            {text = COLLECTED, value = "collected",
                rightText = ns.UI.FormatSectionCount(statusCounts.byStatus.collected)},
            {text = NOT_COLLECTED, value = "uncollected",
                rightText = ns.UI.FormatSectionCount(statusCounts.byStatus.uncollected)},
        })
        collectedDD:SetSelected(collectedFilter)
    end
    RefreshCollectedOpts()
    collectedDD.onSelect = function(value)
        collectedFilter = value
        parent.RefreshCollectiblesList()
    end

    local sortHandle = OneWoW_GUI:CreateSortControls(controlPanel, {
        sortFields = {
            {key = "name",     label = NAME},
            {key = "category", label = CATEGORY},
            {key = "custom",   label = CUSTOM},
        },
        defaultField  = currentSort.by,
        defaultAsc    = currentSort.ascending,
        dropdownWidth = 100,
        onChange = function(field, ascending)
            currentSort.by        = field
            currentSort.ascending = ascending
            ns.db.global.tabSortPrefs.collectibles = { by = field, ascending = ascending }
            parent.RefreshCollectiblesList()
        end,
    })
    sortHandle.dropdown:SetPoint("LEFT", collectedDD, "RIGHT", 6, 0)
    sortHandle.dirBtn:SetPoint("LEFT", sortHandle.dropdown, "RIGHT", 4, 0)

    local helpButton = CreateFrame("Button", nil, controlPanel)
    helpButton:SetSize(28, 28)
    helpButton:SetPoint("TOPRIGHT", controlPanel, "TOPRIGHT", -10, -10)
    local helpIcon = helpButton:CreateTexture(nil, "ARTWORK")
    helpIcon:SetSize(24, 24)
    helpIcon:SetPoint("CENTER", helpButton, "CENTER", 0, 0)
    helpIcon:SetAtlas("CampaignActiveQuestIcon")
    helpButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["UI_HELP_PANEL_TITLE"], 1, 1, 1)
        GameTooltip:AddLine(L["UI_NOTES_HYPERLINK_HINT"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    helpButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    helpButton:SetScript("OnClick", function()
        if not ns.UI.notesHelpPanel and ns.UI.CreateNotesHelpPanel then
            ns.UI.notesHelpPanel = ns.UI.CreateNotesHelpPanel()
        end
        if ns.UI.notesHelpPanel then
            if ns.UI.notesHelpPanel:IsShown() then
                ns.UI.notesHelpPanel:Hide()
            else
                ns.UI.notesHelpPanel:Show()
            end
        end
    end)

    local listingPanel = ns.UI.CreateThemedPanel(nil, parent)
    listingPanel:SetPoint("TOPLEFT",    controlPanel, "BOTTOMLEFT", 0, -10)
    listingPanel:SetPoint("BOTTOMLEFT", parent,       "BOTTOMLEFT", 0, 35)
    listingPanel:SetWidth(OneWoW_GUI.Constants.GUI.LEFT_PANEL_WIDTH)

    local listingTitle = OneWoW_GUI:CreateFS(listingPanel, 16)
    listingTitle:SetPoint("TOP", listingPanel, "TOP", 0, -10)
    listingTitle:SetText(L["TAB_COLLECTIBLES"])
    listingTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local searchBox = OneWoW_GUI:CreateEditBox(listingPanel, {
        placeholderText = L["SEARCH"],
        onTextChanged = function(text)
            searchFilter = text
            if parent.RefreshCollectiblesList then parent.RefreshCollectiblesList() end
        end,
    })
    searchBox:SetPoint("TOPLEFT",  listingPanel, "TOPLEFT",  8, -30)
    searchBox:SetPoint("TOPRIGHT", listingPanel, "TOPRIGHT", -8, -30)

    local listScroll = ns.UI.CreateCustomScroll(listingPanel)
    listScroll.container:SetPoint("TOPLEFT",     listingPanel, "TOPLEFT",     10, -62)
    listScroll.container:SetPoint("BOTTOMRIGHT", listingPanel, "BOTTOMRIGHT", -10, 10)

    local function IsCollectiblesReorderSuppressed()
        return reorderCtrl and (reorderCtrl:IsActive() or reorderCtrl:ShouldSuppressClick())
    end

    reorderCtrl = ns.UI.CreateNotesListReorderDrag({
        getItems = function()
            local items = {}
            for _, row in ipairs(pooledRows) do
                if row:IsShown() and row._reorderIndex then
                    items[#items + 1] = row
                end
            end
            return items
        end,
        getScrollFrame = function()
            return listScroll.scrollFrame
        end,
        onReorder = function(fromIdx, toIdx, insertBefore)
            if ns.UI.ApplySectionReorder(collectibleBag, fromIdx, toIdx, insertBefore) then
                ns.UI.EnsureCustomSort(sortHandle, currentSort, "collectibles")
                parent.RefreshCollectiblesList()
            end
        end,
    })

    detailPanel = ns.UI.CreateThemedPanel(nil, parent)
    detailPanel:SetPoint("TOPLEFT",     listingPanel, "TOPRIGHT",    10, 0)
    detailPanel:SetPoint("BOTTOMRIGHT", parent,       "BOTTOMRIGHT",  0, 35)
    detailPanel:SetClipsChildren(true)

    emptyMessage = OneWoW_GUI:CreateFS(detailPanel, 16)
    emptyMessage:SetPoint("CENTER", detailPanel, "CENTER")
    emptyMessage:SetText(L["COLLECTIBLES_SELECT"])
    emptyMessage:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local leftStatusBar = ns.UI.CreateThemedBar(nil, parent)
    leftStatusBar:SetPoint("TOPLEFT",  listingPanel, "BOTTOMLEFT",  0, -5)
    leftStatusBar:SetPoint("TOPRIGHT", listingPanel, "BOTTOMRIGHT", 0, -5)
    leftStatusBar:SetHeight(25)

    leftStatusText = OneWoW_GUI:CreateFS(leftStatusBar, 10)
    leftStatusText:SetPoint("LEFT", leftStatusBar, "LEFT", 10, 0)
    leftStatusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    leftStatusText:SetText(string.format(L["UI_COUNT_FORMAT"], L["TAB_COLLECTIBLES"], 0))

    local rightStatusBar = ns.UI.CreateThemedBar(nil, parent)
    rightStatusBar:SetPoint("TOPLEFT",  detailPanel, "BOTTOMLEFT",  0, -5)
    rightStatusBar:SetPoint("TOPRIGHT", detailPanel, "BOTTOMRIGHT", 0, -5)
    rightStatusBar:SetHeight(25)

    local rightStatusText = OneWoW_GUI:CreateFS(rightStatusBar, 10)
    rightStatusText:SetPoint("LEFT", rightStatusBar, "LEFT", 10, 0)
    rightStatusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    rightStatusText:SetText(READY)

    -- Fills the "Sold by" section from the record's vendor offers and re-anchors
    -- the tooltip section below it (or back under the content box when there are
    -- no offers, keeping non-vendor collectibles compact). Live affordability +
    -- waypoints are resolved here, never persisted.
    local function PopulateSoldBy(ec, record)
        local section = ec.soldBySection
        if not section then return end

        local entries = BuildVendorEntries(record)
        local total = #entries

        if total == 0 then
            section:Hide()
            ec.tooltipSection:ClearAllPoints()
            ec.tooltipSection:SetPoint("TOPLEFT",  ec.contentBg, "BOTTOMLEFT",  0, -Detail.SECTION_GAP)
            ec.tooltipSection:SetPoint("TOPRIGHT", ec.contentBg, "BOTTOMRIGHT", 0, -Detail.SECTION_GAP)
            return
        end

        section.label:SetText(string.format("%s (%d)", L["COLLECTIBLE_SOLD_BY"], total))
        section:Show()
        ec.tooltipSection:ClearAllPoints()
        ec.tooltipSection:SetPoint("TOPLEFT",  section, "BOTTOMLEFT",  0, -Detail.SECTION_GAP)
        ec.tooltipSection:SetPoint("TOPRIGHT", section, "BOTTOMRIGHT", 0, -Detail.SECTION_GAP)

        local api = OneWoW_CatalogData_Vendors_API
        for i, row in ipairs(section.rows) do
            local entry = entries[i]
            if entry then
                local nameStr = entry.name or UNKNOWN
                if entry.zone and entry.zone ~= "" then
                    nameStr = nameStr .. "  |cFF808080" .. entry.zone .. "|r"
                end
                row.nameFS:SetText(nameStr)

                local costStr = FormatCost(entry)
                local afford = OneWoW.Collectibles.GetOfferAffordability(entry)
                local colorKey = "TEXT_SECONDARY"
                if afford then
                    colorKey = afford.affordable and "TEXT_FEATURES_ENABLED" or "TEXT_FEATURES_DISABLED"
                end
                row.costFS:SetText(costStr)
                row.costFS:SetTextColor(OneWoW_GUI:GetThemeColor(colorKey))

                if api and api.CreateWaypoint and entry.vendorRecord and entry.mapID then
                    row.wpBtn:Show()
                    row.wpBtn:SetScript("OnClick", function()
                        api.CreateWaypoint(entry.vendorRecord, entry.mapID)
                    end)
                else
                    row.wpBtn:Hide()
                end

                row:Show()
            else
                row:Hide()
            end
        end

        -- Purchase-block reason. `isPurchasable` stays the "can/can't buy" gate;
        -- when it is set we answer "why not?" with the requirement(s) captured at
        -- sighting (`offer.blockReason` — the red merchant-tooltip lines, which the
        -- static C_TooltipInfo item getters do not expose). Collected across the
        -- blocked offers and deduped to one line below the rows. Falls back to the
        -- generic text when the gate is set but no specific reason was captured
        -- (older offer, or a purely availability-side gate such as limited stock).
        local reasonFS = section.reasonFS
        if reasonFS then
            local seen, reasons, anyBlocked = {}, {}, false
            for _, entry in ipairs(entries) do
                if entry.isPurchasable == false then
                    anyBlocked = true
                    if entry.blockReason and entry.blockReason ~= "" then
                        for line in entry.blockReason:gmatch("[^\n]+") do
                            if not seen[line] then
                                seen[line] = true
                                reasons[#reasons + 1] = line
                            end
                        end
                    end
                end
            end
            if #reasons == 0 and anyBlocked then
                reasons[1] = L["COLLECTIBLE_CANT_BUY"]
            end

            if #reasons > 0 then
                reasonFS:SetText(table.concat(reasons, "\n"))
                reasonFS:Show()
                section:SetHeight(SOLD_BY_BASE_HEIGHT + reasonFS:GetStringHeight() + 8)
            else
                reasonFS:SetText("")
                reasonFS:Hide()
                section:SetHeight(SOLD_BY_BASE_HEIGHT)
            end
        end
    end

    -- Fills the (already-built) editor from the live record + core resolution.
    -- Tolerates a nil/partial ResolveDisplay: shows what it has now and arms the
    -- item-info watcher so the panel completes itself once the cache fills.
    local function PopulateEditor()
        local ec = detailPanel.editorContent
        if not ec or not selectedKey then return end

        local record = ns.Collectibles:GetCollectible(selectedKey)
        if not record then return end

        local name, icon, link, sourceText, complete = ResolveRow(selectedKey, record)
        local header = ec.header

        header.iconTexture:SetTexture(icon)
        header.nameText:SetText(name)

        header.iconFrame:SetScript("OnEnter", function(self)
            if link then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(link)
                GameTooltip:Show()
            end
        end)
        header.iconFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

        if sourceText and sourceText ~= "" then
            header.sourceText:SetText(sourceText)
            header.sourceText:Show()
        else
            header.sourceText:SetText("")
            header.sourceText:Hide()
        end

        -- Ensemble/set progress. For a `set` record the progress is the set
        -- itself; for an appearance source it is the set(s) that contain it
        -- (GetContainingSets returns nil for everything else).
        local setLine
        local descriptor = OneWoW.Collectibles.ParseKey(selectedKey)
        local progressSetID
        if descriptor and descriptor.type == "set" then
            progressSetID = descriptor.id
        else
            local setIDs = OneWoW.Collectibles.GetContainingSets(selectedKey)
            progressSetID = setIDs and setIDs[1]
        end
        if progressSetID then
            local progress = OneWoW.Collectibles.GetEnsembleProgress(progressSetID)
            if progress and progress.total > 0 then
                setLine = string.format(L["COLLECTIBLE_SET_PROGRESS"],
                    progress.name or "", progress.collected, progress.total)
            end
        end
        if setLine then
            header.setProgressText:SetText(setLine)
            header.setProgressText:Show()
        else
            header.setProgressText:SetText("")
            header.setProgressText:Hide()
        end

        local state = OneWoW.Collectibles.GetCollectionState(selectedKey)
        if state then
            -- Decor uses a quantity model: when owned, show the owned/placed/
            -- storage breakdown (Blizzard's localized HOUSING_DECOR_OWNED_COUNT_FORMAT)
            -- instead of a bare "Collected". `numOwned` is decor-only.
            local statusStr = state.collected and COLLECTED or NOT_COLLECTED
            if state.numOwned and state.numOwned > 0 then
                statusStr = HOUSING_DECOR_OWNED_COUNT_FORMAT:format(
                    state.numOwned, state.numPlaced or 0, state.numStored or 0)
            end
            header.statusText:SetText(statusStr)
            header.statusText:SetTextColor(OneWoW_GUI:GetThemeColor(
                state.collected and "TEXT_FEATURES_ENABLED" or "TEXT_FEATURES_DISABLED"))
            header.statusText:Show()
        else
            header.statusText:SetText("")
            header.statusText:Hide()
        end

        ec.catDD:SetSelected(record.category or "General")
        ec.intentDD:SetSelected(record.intent or "none")

        if detailPanel.contentEditBox then
            detailPanel.contentEditBox:SetText(record.content or "")
        end
        if ec.tooltipEdits then
            for i = 1, 4 do
                ec.tooltipEdits[i]:SetText((record.tooltipLines and record.tooltipLines[i]) or "")
            end
        end

        PopulateSoldBy(ec, record)

        SyncItemInfoWatcher(complete)
    end

    local function HideEditor()
        if detailPanel.editorContent then
            for _, f in pairs(detailPanel.editorContent) do
                if type(f) == "table" and f.Hide then f:Hide() end
            end
        end
        if detailPanel.contentEditBox then detailPanel.contentEditBox:Hide() end
        emptyMessage:Show()
        SyncItemInfoWatcher(true)
    end

    local function DeleteSelected()
        if not selectedKey then return end
        local key = selectedKey
        StaticPopupDialogs["ONEWOW_NOTES_CONFIRM_DELETE_COLLECTIBLE"] = {
            text = L["POPUP_DELETE_COLLECTIBLE"],
            button1 = DELETE, button2 = CANCEL,
            OnAccept = function()
                ns.Collectibles:RemoveCollectible(key)
                if selectedKey == key then
                    selectedKey = nil
                    HideEditor()
                end
                parent.RefreshCollectiblesList()
            end,
            timeout = 0, whileDead = true, hideOnEscape = true,
        }
        StaticPopup_Show("ONEWOW_NOTES_CONFIRM_DELETE_COLLECTIBLE")
    end

    local function ShowEditor()
        emptyMessage:Hide()

        for _, child in ipairs({detailPanel:GetChildren()}) do
            if child ~= emptyMessage then child:Hide() end
        end

        if not detailPanel.editorContent then
            local editorHeader = ns.UI.CreateDetailHeader(detailPanel)

            local iconFrame = CreateFrame("Frame", nil, editorHeader)
            iconFrame:SetSize(48, 48)
            iconFrame:SetPoint("TOPLEFT", editorHeader, "TOPLEFT", 10, -10)
            iconFrame:EnableMouse(true)
            editorHeader.iconFrame = iconFrame

            local iconTexture = iconFrame:CreateTexture(nil, "ARTWORK")
            iconTexture:SetAllPoints()
            iconTexture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            editorHeader.iconTexture = iconTexture

            local nameText = OneWoW_GUI:CreateFS(editorHeader, 16)
            nameText:SetPoint("TOPLEFT",  iconFrame, "TOPRIGHT", 10, -2)
            nameText:SetPoint("RIGHT",    editorHeader, "RIGHT", -40, 0)
            nameText:SetJustifyH("LEFT")
            nameText:SetWordWrap(false)
            nameText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            editorHeader.nameText = nameText

            local statusText = OneWoW_GUI:CreateFS(editorHeader, 11)
            statusText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -4)
            statusText:SetJustifyH("LEFT")
            editorHeader.statusText = statusText

            local sourceText = OneWoW_GUI:CreateFS(editorHeader, 10)
            sourceText:SetPoint("TOPLEFT", statusText, "BOTTOMLEFT", 0, -2)
            sourceText:SetPoint("RIGHT",   editorHeader, "RIGHT", -12, 0)
            sourceText:SetJustifyH("LEFT")
            sourceText:SetWordWrap(false)
            sourceText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            editorHeader.sourceText = sourceText

            -- Ensemble/set progress (appearances that belong to a transmog set).
            local setProgressText = OneWoW_GUI:CreateFS(editorHeader, 10)
            setProgressText:SetPoint("TOPLEFT", sourceText, "BOTTOMLEFT", 0, -2)
            setProgressText:SetPoint("RIGHT",   editorHeader, "RIGHT", -12, 0)
            setProgressText:SetJustifyH("LEFT")
            setProgressText:SetWordWrap(false)
            setProgressText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
            editorHeader.setProgressText = setProgressText

            local deleteBtn = ns.UI.CreateHeaderIconButton(editorHeader, {
                texture = "icon-trash.png",
            })
            deleteBtn:SetScript("OnClick", DeleteSelected)
            deleteBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(DELETE, 1, 1, 1)
                GameTooltip:AddLine(L["COLLECTIBLE_DELETE_DESC"], 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            deleteBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            editorHeader.deleteBtn = deleteBtn

            local infoBar = ns.UI.CreateThemedBar(nil, detailPanel)
            infoBar:SetPoint("TOPLEFT",  editorHeader, "BOTTOMLEFT",  0, -Detail.SECTION_GAP)
            infoBar:SetPoint("TOPRIGHT", editorHeader, "BOTTOMRIGHT", 0, -Detail.SECTION_GAP)
            infoBar:SetHeight(40)

            local editorCatDD = ns.UI.CreateThemedDropdown(infoBar, CATEGORY, 150, 26)
            editorCatDD:SetPoint("LEFT", infoBar, "LEFT", 8, 0)
            local catOpts = {}
            for _, c in ipairs(ns.Collectibles:GetCategories()) do
                catOpts[#catOpts + 1] = {text = c, value = c}
            end
            editorCatDD:SetOptions(catOpts)
            editorCatDD.onSelect = function(value)
                if not selectedKey then return end
                local record = ns.Collectibles:GetCollectible(selectedKey)
                if record then
                    record.category = value
                    ns.Collectibles:SaveCollectible(selectedKey, record)
                    parent.RefreshCollectiblesList()
                end
            end

            local intentDD = ns.UI.CreateThemedDropdown(infoBar, L["COLLECTIBLE_INTENT_LABEL"], 150, 26)
            intentDD:SetPoint("RIGHT", infoBar, "RIGHT", -8, 0)
            local intentOpts = {}
            for _, v in ipairs(INTENT_ORDER) do
                intentOpts[#intentOpts + 1] = {text = IntentLabel(v), value = v}
            end
            intentDD:SetOptions(intentOpts)
            intentDD.onSelect = function(value)
                if not selectedKey then return end
                -- SetIntent applies recycle-bin bookkeeping (deletedAt + Delete List
                -- category on enter, restore on exit); don't mutate intent directly.
                ns.Collectibles:SetIntent(selectedKey, value)
                parent.RefreshCollectiblesList()
            end

            local body = ns.UI.CreateDetailBody(detailPanel, infoBar, {
                onTextChanged = function(self, userInput)
                    if userInput and selectedKey then
                        local record = ns.Collectibles:GetCollectible(selectedKey)
                        if record then
                            record.content  = self:GetText()
                            record.modified = GetServerTime()
                        end
                    end
                end,
            })
            local contentBg = body.contentBg
            local contentScroll = body.contentScroll
            local contentEditBox = body.contentEditBox
            contentEditBox:SetHyperlinksEnabled(true)
            contentEditBox:SetScript("OnHyperlinkClick", function(_, link, text, button)
                SetItemRef(link, text, button)
            end)
            contentEditBox:SetScript("OnMouseUp", function(self, button)
                if button == "RightButton" and ns.NotesContextMenu then
                    ns.NotesContextMenu:ShowEditBoxContextMenu(self)
                end
            end)
            if ns.NotesHyperlinks then ns.NotesHyperlinks:EnhanceEditBox(contentEditBox) end
            contentEditBox._skipGlobalFont = true
            detailPanel.contentEditBox = contentEditBox

            contentBg:SetScript("OnMouseDown", function(_, button)
                if detailPanel.contentEditBox then
                    detailPanel.contentEditBox:SetFocus()
                    if button == "RightButton" and ns.NotesContextMenu then
                        ns.NotesContextMenu:ShowEditBoxContextMenu(detailPanel.contentEditBox)
                    end
                end
            end)

            -- "Sold by" vendor section. Sits between the content box and
            -- the tooltip lines; shown only when the record carries vendor offers,
            -- so non-vendor collectibles keep the compact layout (tooltipSection is
            -- re-anchored live in PopulateEditor).
            local soldBySection = ns.UI.CreateThemedBar(nil, detailPanel)
            soldBySection:SetPoint("TOPLEFT",  contentBg, "BOTTOMLEFT",  0, -Detail.SECTION_GAP)
            soldBySection:SetPoint("TOPRIGHT", contentBg, "BOTTOMRIGHT", 0, -Detail.SECTION_GAP)
            soldBySection:SetHeight(SOLD_BY_BASE_HEIGHT)

            local soldByLabel = OneWoW_GUI:CreateFS(soldBySection, 12)
            soldByLabel:SetPoint("TOPLEFT", soldBySection, "TOPLEFT", 10, -8)
            soldByLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            soldBySection.label = soldByLabel

            local soldByRows = {}
            for i = 1, MAX_VENDOR_ROWS do
                local row = CreateFrame("Frame", nil, soldBySection)
                row:SetPoint("TOPLEFT",  soldBySection, "TOPLEFT",  10, -26 - (i - 1) * 30)
                row:SetPoint("TOPRIGHT", soldBySection, "TOPRIGHT", -10, -26 - (i - 1) * 30)
                row:SetHeight(28)

                local wpBtn = CreateFrame("Button", nil, row)
                wpBtn:SetSize(20, 20)
                wpBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
                wpBtn:SetNormalTexture(MEDIA .. "icon-pin.png")
                wpBtn:GetNormalTexture():SetTexCoord(0.1, 0.9, 0.1, 0.9)
                wpBtn:SetHighlightTexture(MEDIA .. "icon-pin.png")
                wpBtn:GetHighlightTexture():SetAlpha(0.5)
                wpBtn:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(MAP_PIN, 1, 1, 1)
                    GameTooltip:Show()
                end)
                wpBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
                row.wpBtn = wpBtn

                local nameFS = OneWoW_GUI:CreateFS(row, 11)
                nameFS:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
                nameFS:SetPoint("RIGHT", wpBtn, "LEFT", -6, 0)
                nameFS:SetJustifyH("LEFT")
                nameFS:SetWordWrap(false)
                row.nameFS = nameFS

                local costFS = OneWoW_GUI:CreateFS(row, 10)
                costFS:SetPoint("TOPLEFT", nameFS, "BOTTOMLEFT", 0, -2)
                costFS:SetPoint("RIGHT", wpBtn, "LEFT", -6, 0)
                costFS:SetJustifyH("LEFT")
                costFS:SetWordWrap(false)
                row.costFS = costFS

                row:Hide()
                soldByRows[i] = row
            end
            soldBySection.rows = soldByRows

            -- Live "why can't I buy this" line: the item's current unmet (red)
            -- requirement, shown once beneath the rows. Uses the shared disabled
            -- color (same red the unaffordable cost uses) so nothing is hardcoded.
            local reasonFS = OneWoW_GUI:CreateFS(soldBySection, 10)
            reasonFS:SetPoint("TOPLEFT",  soldBySection, "TOPLEFT",  10, -(26 + MAX_VENDOR_ROWS * 30))
            reasonFS:SetPoint("TOPRIGHT", soldBySection, "TOPRIGHT", -10, -(26 + MAX_VENDOR_ROWS * 30))
            reasonFS:SetJustifyH("LEFT")
            reasonFS:SetWordWrap(true)
            reasonFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
            reasonFS:Hide()
            soldBySection.reasonFS = reasonFS

            local tip = ns.UI.CreateTooltipLinesSection(detailPanel, contentBg, {
                onLineChanged = function(index, text, userInput)
                    if userInput and selectedKey then
                        local record = ns.Collectibles:GetCollectible(selectedKey)
                        if record then
                            if not record.tooltipLines then record.tooltipLines = {"", "", "", ""} end
                            record.tooltipLines[index] = text
                            record.modified = GetServerTime()
                        end
                    end
                end,
            })
            local tooltipSection = tip.section
            local tooltipEdits = tip.edits

            editorHeader.catDD    = editorCatDD
            editorHeader.intentDD = intentDD

            detailPanel.editorContent = {
                header         = editorHeader,
                catDD          = editorCatDD,
                intentDD       = intentDD,
                infoBar        = infoBar,
                contentBg      = contentBg,
                contentScroll  = contentScroll,
                soldBySection  = soldBySection,
                tooltipSection = tooltipSection,
                tooltipEdits   = tooltipEdits,
            }
        end

        for _, f in pairs(detailPanel.editorContent) do
            if type(f) == "table" and f.Show then f:Show() end
        end
        if detailPanel.contentEditBox then detailPanel.contentEditBox:Show() end
        ns.UI.activeContentEditBox = detailPanel.contentEditBox

        PopulateEditor()
    end

    infoWatcher:SetScript("OnEvent", function()
        if selectedKey and detailPanel.editorContent then
            PopulateEditor()
        end
        parent.RefreshCollectiblesList()
    end)

    local function SortCollectibleSnaps(a, b)
        local aDel = a.data.intent == "delete"
        local bDel = b.data.intent == "delete"
        if aDel ~= bDel then return bDel end
        if currentSort.by == "category" then
            local ca = a.data.category or ""
            local cb = b.data.category or ""
            if ca == cb then return a.name < b.name end
            if currentSort.ascending then return ca < cb else return ca > cb end
        elseif currentSort.by == "custom" then
            local sa = a.data.sortOrder or 0
            local sb = b.data.sortOrder or 0
            if sa == sb then return a.name < b.name end
            if currentSort.ascending then return sa < sb else return sa > sb end
        elseif currentSort.by == "modified" then
            if currentSort.ascending then return (a.data.modified or 0) < (b.data.modified or 0)
            else return (a.data.modified or 0) > (b.data.modified or 0) end
        else
            if currentSort.ascending then return a.name < b.name else return a.name > b.name end
        end
    end

    local function RebuildFlattened()
        wipe(collectibleBag)
        wipe(flattenedEntries)
        listNeedsItemInfo = false
        for _, snap in ipairs(snapshot) do
            if EntryMatchesFilters(snap, nil) then
                collectibleBag[#collectibleBag + 1] = snap
            end
        end
        table.sort(collectibleBag, SortCollectibleSnaps)

        if #collectibleBag > 0 then
            flattenedEntries[#flattenedEntries + 1] = {
                kind  = "header",
                title = L["TAB_COLLECTIBLES"],
                count = #collectibleBag,
            }
        end
        for i, snap in ipairs(collectibleBag) do
            local isSet = snap.collType == "set"
            flattenedEntries[#flattenedEntries + 1] = {
                kind         = "item",
                snap         = snap,
                reorderIndex = i,
                isSet        = isSet,
            }
            if isSet and expandedSets[snap.key] and snap.descriptor then
                local members = OneWoW.Collectibles.GetSetMembers(snap.descriptor.id)
                if members then
                    for _, member in ipairs(members) do
                        if not member.name then
                            listNeedsItemInfo = true
                        end
                        flattenedEntries[#flattenedEntries + 1] = {
                            kind   = "member",
                            member = member,
                        }
                    end
                end
            end
        end
    end

    local function CreateCollectibleListRow(rowParent)
        local row = CreateFrame("Button", nil, rowParent, "BackdropTemplate")
        row:SetHeight(ns.UI.LIST_ROW_HEIGHT)
        row:SetBackdrop(BACKDROP_INNER_NO_INSETS)
        row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        row:RegisterForClicks("LeftButtonUp")

        local bar = row:CreateTexture(nil, "ARTWORK")
        bar:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -3)
        bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 2, 3)
        bar:SetWidth(4)
        row.colorBar = bar

        local caret = CreateFrame("Button", nil, row)
        caret:SetSize(16, 20)
        caret:SetPoint("LEFT", row, "LEFT", 6, 0)
        local caretFS = OneWoW_GUI:CreateFS(caret, 12)
        caretFS:SetAllPoints()
        caretFS:SetJustifyH("CENTER")
        caretFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        caret.fs = caretFS
        caret:SetScript("OnClick", function()
            local entry = flattenedEntries[row.entryIndex]
            if not entry or not entry.isSet then return end
            expandedSets[entry.snap.key] = not expandedSets[entry.snap.key]
            parent.RefreshCollectiblesList()
        end)
        caret:SetScript("OnEnter", function(myself)
            GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["COLLECTIBLE_SET_MEMBERS"], 1, 1, 1)
            GameTooltip:Show()
        end)
        caret:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row.expandBtn = caret

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(26, 26)
        icon:SetPoint("LEFT", row, "LEFT", 10, 0)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        row.iconTexture = icon

        local deleteBtn = OneWoW_GUI:CreateIconButton(row, {
            iconTexture = MEDIA .. "icon-trash.png",
            size = 18,
        })
        deleteBtn:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -6, 5)
        deleteBtn:SetScript("OnClick", function()
            local entry = flattenedEntries[row.entryIndex]
            if not entry or entry.kind ~= "item" then return end
            selectedKey = entry.snap.key
            DeleteSelected()
        end)
        deleteBtn:SetScript("OnEnter", function(myself)
            GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
            GameTooltip:SetText(DELETE, 1, 1, 1)
            GameTooltip:AddLine(L["COLLECTIBLE_DELETE_DESC"], 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        deleteBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row.deleteBtn = deleteBtn

        local headerCountFS = OneWoW_GUI:CreateFS(row, 12)
        headerCountFS:SetPoint("RIGHT", row, "RIGHT", -12, 0)
        headerCountFS:SetJustifyH("RIGHT")
        headerCountFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        headerCountFS:Hide()
        row.headerCountFS = headerCountFS

        local memberCheck = row:CreateTexture(nil, "ARTWORK")
        memberCheck:SetSize(16, 16)
        memberCheck:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        memberCheck:Hide()
        row.memberCheck = memberCheck

        local title = OneWoW_GUI:CreateFS(row, 12)
        title:SetPoint("TOPLEFT", row, "TOPLEFT", 12, -7)
        title:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, -7)
        title:SetJustifyH("LEFT")
        title:SetWordWrap(false)
        title:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        row.titleFS = title

        local storageFS = OneWoW_GUI:CreateFS(row, 10)
        storageFS:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 12, 7)
        storageFS:SetJustifyH("LEFT")
        storageFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        row.storageFS = storageFS

        local detail = OneWoW_GUI:CreateFS(row, 10)
        detail:SetPoint("BOTTOMLEFT", storageFS, "TOPLEFT", 0, 1)
        detail:SetPoint("RIGHT", row, "RIGHT", -10, 0)
        detail:SetJustifyH("LEFT")
        detail:SetWordWrap(false)
        detail:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        row.detailFS = detail

        row:SetScript("OnEnter", function(myself)
            if myself._kind == "member" and myself._memberLink then
                GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(myself._memberLink)
                GameTooltip:Show()
            end
            if not myself._rowSelected then
                OneWoW_GUI:ApplyListRowFill(myself, { hover = true })
            end
        end)
        row:SetScript("OnLeave", function(myself)
            GameTooltip:Hide()
            if myself._kind == "member" and listAPI then
                listAPI.Refresh()
            end
            if not myself._rowSelected then
                OneWoW_GUI:ApplyListRowFill(myself, {
                    zebraIndex = myself._zebraIndex,
                    header = myself._kind == "header",
                })
            end
        end)

        pooledRows[#pooledRows + 1] = row
        reorderCtrl:Attach(row)
        return row
    end

    local function BindCollectibleListRow(row, _, entry, state)
        row._kind = entry.kind
        row._rowSelected = state.selected and true or false
        row._notesListSelected = row._rowSelected
        row._memberLink = nil
        row._reorderIndex = nil
        row:SetAlpha(1)

        if entry.kind == "header" then
            row.colorBar:Hide()
            row.expandBtn:Hide()
            row.iconTexture:Hide()
            row.deleteBtn:Hide()
            row.storageFS:Hide()
            row.detailFS:Hide()
            row.memberCheck:Hide()
            row.headerCountFS:Show()
            row.headerCountFS:SetText(ns.UI.FormatSectionCount(entry.count))
            row.titleFS:ClearAllPoints()
            row.titleFS:SetPoint("LEFT", row, "LEFT", 12, 0)
            row.titleFS:SetPoint("RIGHT", row.headerCountFS, "LEFT", -8, 0)
            row.titleFS:SetText(entry.title)
            row.titleFS:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            OneWoW_GUI:ApplyListRowFill(row, { header = true })
            row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            return
        end

        if entry.kind == "member" then
            local member = entry.member
            local display = member.key and OneWoW.Collectibles.ResolveDisplay(member.key)
            local name = (display and display.name) or member.name or UNKNOWN
            local icon = (display and display.icon) or member.icon
            local link = (display and display.link) or member.link
            if not name or name == UNKNOWN then
                listNeedsItemInfo = true
            end
            row.colorBar:Hide()
            row.expandBtn:Hide()
            row.deleteBtn:Hide()
            row.storageFS:Hide()
            row.detailFS:Hide()
            row.headerCountFS:Hide()
            row.memberCheck:Show()
            row.memberCheck:SetTexture(member.collected
                and "Interface\\RaidFrame\\ReadyCheck-Ready"
                or  "Interface\\RaidFrame\\ReadyCheck-NotReady")
            row.iconTexture:Show()
            row.iconTexture:SetSize(20, 20)
            row.iconTexture:ClearAllPoints()
            row.iconTexture:SetPoint("LEFT", row, "LEFT", 18, 0)
            row.iconTexture:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.titleFS:ClearAllPoints()
            row.titleFS:SetPoint("LEFT", row.iconTexture, "RIGHT", 6, 0)
            row.titleFS:SetPoint("RIGHT", row.memberCheck, "LEFT", -6, 0)
            row.titleFS:SetText(name)
            row.titleFS:SetTextColor(OneWoW_GUI:GetThemeColor(
                member.collected and "TEXT_PRIMARY" or "TEXT_MUTED"))
            row._memberLink = link
            OneWoW_GUI:ApplyListRowFill(row, { zebraIndex = state.zebraIndex })
            row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            return
        end

        local snap = entry.snap
        local key = snap.key
        local record = snap.data
        row._reorderIndex = entry.reorderIndex

        local name, icon = ResolveRow(key, record)
        local stateLive = OneWoW.Collectibles.GetCollectionState(key)
        if stateLive then
            local cr, cg, cb = OneWoW_GUI:GetThemeColor(
                stateLive.collected and "TEXT_FEATURES_ENABLED" or "TEXT_FEATURES_DISABLED")
            row.colorBar:Show()
            row.colorBar:SetColorTexture(cr, cg, cb, 1)
        else
            row.colorBar:Hide()
        end

        local hasCaret = entry.isSet
        local caretPad = hasCaret and 18 or 0
        local iconX = 10 + caretPad
        local textX = iconX + 26 + 6
        if hasCaret then
            row.expandBtn:Show()
            row.expandBtn.fs:SetText(expandedSets[key] and "v" or ">")
        else
            row.expandBtn:Hide()
        end

        row.headerCountFS:Hide()
        row.memberCheck:Hide()
        row.iconTexture:Show()
        row.iconTexture:SetSize(26, 26)
        row.iconTexture:ClearAllPoints()
        row.iconTexture:SetPoint("LEFT", row, "LEFT", iconX, 0)
        row.iconTexture:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        row.deleteBtn:Show()

        row.titleFS:ClearAllPoints()
        row.titleFS:SetPoint("TOPLEFT", row, "TOPLEFT", textX, -7)
        row.titleFS:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, -7)
        row.titleFS:SetText(name)
        row.titleFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        row.storageFS:Show()
        row.storageFS:ClearAllPoints()
        row.storageFS:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", textX, 7)
        row.storageFS:SetText(record.storage == "character" and CHARACTER or L["UI_STORAGE_ACCOUNT"])

        local intent = record.intent or "none"
        local detailText = intent ~= "none" and IntentLabel(intent) or nil
        if entry.isSet and stateLive and stateLive.total and stateLive.total > 0 then
            local prog = string.format("%d/%d", stateLive.numCollected or 0, stateLive.total)
            detailText = detailText and (detailText .. "  " .. prog) or prog
        end
        if detailText then
            row.detailFS:Show()
            row.detailFS:ClearAllPoints()
            row.detailFS:SetPoint("BOTTOMLEFT", row.storageFS, "TOPLEFT", 0, 1)
            row.detailFS:SetPoint("RIGHT", row, "RIGHT", -10, 0)
            row.detailFS:SetText(detailText)
        else
            row.detailFS:Hide()
        end

        row:SetAlpha(intent == "delete" and 0.5 or 1)
        OneWoW_GUI:ApplyListRowFill(row, {
            zebraIndex = state.zebraIndex,
            selected = row._rowSelected,
        })
        if row._rowSelected then
            row:SetBackdropBorderColor(1, 0.82, 0, 1)
        else
            row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        end
    end

    listAPI = OneWoW_GUI:CreateVirtualizer(listingPanel, {
        name = "NotesCollectiblesList",
        rowHeight = ns.UI.LIST_ROW_HEIGHT,
        minRowHeight = CHILD_ROW_HEIGHT,
        numVisibleRows = 14,
        rowInset = 0,
        scrollFrame = listScroll.scrollFrame,
        content = listScroll.scrollChild,
        getCount = function()
            return #flattenedEntries
        end,
        getEntry = function(index)
            return flattenedEntries[index]
        end,
        getRowHeight = function(index)
            local entry = flattenedEntries[index]
            if not entry then
                return ns.UI.LIST_ROW_HEIGHT
            end
            if entry.kind == "header" then
                return HEADER_ROW_HEIGHT
            end
            if entry.kind == "member" then
                return CHILD_ROW_HEIGHT
            end
            return ns.UI.LIST_ROW_HEIGHT
        end,
        isSelectable = function(_, entry)
            if IsCollectiblesReorderSuppressed() then
                return false
            end
            return entry and entry.kind == "item"
        end,
        onSelect = function(_, entry)
            if not entry or entry.kind ~= "item" then
                return
            end
            selectedKey = entry.snap.key
            ShowEditor()
        end,
        createRow = CreateCollectibleListRow,
        bindRow = BindCollectibleListRow,
        enableKeyboardNav = true,
        focusCompetitor = searchBox,
    })
    listScroll.scrollFrame:HookScript("OnSizeChanged", function(sf)
        listScroll.scrollChild:SetWidth(math.max(1, sf:GetWidth() - 20))
    end)

    function parent.RefreshCollectiblesList()
        BuildSnapshot()
        RefreshCatOptions()
        RefreshTypeOpts()
        RefreshStorageOpts()
        RefreshCollectedOpts()
        RebuildFlattened()

        if leftStatusText then
            leftStatusText:SetText(string.format(L["UI_COUNT_FORMAT"], L["TAB_COLLECTIBLES"], #collectibleBag))
        end
        if not listAPI then
            return
        end

        local selIdx
        if selectedKey then
            for i, entry in ipairs(flattenedEntries) do
                if entry.kind == "item" and entry.snap.key == selectedKey then
                    selIdx = i
                    break
                end
            end
        end
        if selIdx then
            if listAPI.GetSelectedIndex() ~= selIdx then
                listAPI.SetSelectedIndex(selIdx)
            else
                listAPI.Refresh()
            end
        else
            listAPI.SetSelectedIndex(nil)
        end

        local editorComplete = true
        if selectedKey then
            local record = ns.Collectibles:GetCollectible(selectedKey)
            if record then
                editorComplete = select(5, ResolveRow(selectedKey, record)) and true or false
            end
        end
        SyncItemInfoWatcher(editorComplete)
    end

    local function OpenCollectibleEditor(key)
        key = OneWoW.Collectibles.CanonicalizeKey(key)
        if not key or not ns.Collectibles:GetCollectible(key) then
            return false
        end
        selectedKey     = key
        searchFilter    = ""
        categoryFilter  = "All"
        typeFilter      = "All"
        storageFilter   = "All"
        collectedFilter = "All"
        searchBox:SetText("")
        catDD:SetSelected("All")
        typeDD:SetSelected("All")
        storeDD:SetSelected("All")
        collectedDD:SetSelected("All")
        ShowEditor()
        parent.RefreshCollectiblesList()
        return true
    end

    -- Opens a specific collectible's editor; used by cross-addon navigation
    -- (OneWoW_Notes_API.OpenCollectible).
    function parent.SelectCollectible(key)
        key = OneWoW.Collectibles.CanonicalizeKey(key)
        if not key then return end
        selectedKey = key
        ShowEditor()
        parent.RefreshCollectiblesList()
    end

    function parent.GetNavEntity()
        if selectedKey then
            return "collectible", selectedKey
        end
    end

    function parent.RestoreNavEntity(kind, id)
        if kind == "collectible" then
            parent.SelectCollectible(id)
        end
    end

    ns.UI.RefreshCollectiblesList = parent.RefreshCollectiblesList

    -- Lets the merchant capture listener refresh the open detail in place when a
    -- vendor offer lands on the currently-selected record.
    ns.UI.RefreshCollectiblesDetail = function()
        if selectedKey and detailPanel and detailPanel.editorContent then
            PopulateEditor()
        end
    end

    ns.UI.OpenNotesCollectible = function(key)
        return OpenCollectibleEditor(key)
    end

    function parent.Activate()
        -- Run the recycle-bin sweep when the tab is opened (auto-recycle collected
        -- items + purge expired Delete-List rows), so the list is current on view.
        ns.Collectibles:RunCleanup()
        if ns.pendingCollectibleSelect then
            local key = ns.pendingCollectibleSelect
            ns.pendingCollectibleSelect = nil
            OpenCollectibleEditor(key)
        else
            parent.RefreshCollectiblesList()
        end
    end

    parent.RefreshCollectiblesList()

    if ns.pendingCollectibleSelect then
        local key = ns.pendingCollectibleSelect
        ns.pendingCollectibleSelect = nil
        OpenCollectibleEditor(key)
    end
end
