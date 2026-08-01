local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local MEDIA = OneWoW_GUI.Constants.MEDIA_BASE

ns.UI = ns.UI or {}

-- selectedKey is the canonical collectible KEY string ("mount:2240"), not a
-- numeric id — the whole tab is keyed by strings from OneWoW.Collectibles.
local selectedKey    = nil
local collListRows   = {}
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
local CHILD_ROW_SPACING  = 32

local detailPanel    = nil
local emptyMessage   = nil
local leftStatusText = nil
local scrollChild    = nil

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

local function CreateThemedPanel(name, parentFrame)
    local f = CreateFrame("Frame", name, parentFrame, "BackdropTemplate")
    f:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    f:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    f:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    return f
end

local function CreateThemedBar(name, parentFrame)
    local f = CreateFrame("Frame", name, parentFrame, "BackdropTemplate")
    f:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    f:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    f:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    return f
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

-- Human-readable cost string for one offer entry (gold coin string + currencies).
local function FormatCost(entry)
    local parts = {}
    if entry.cost and entry.cost > 0 then
        parts[#parts + 1] = C_CurrencyInfo.GetCoinTextureString(entry.cost)
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

-- A compact, read-only child row for a transmog-set member appearance: indented
-- under its set parent, showing the piece's icon + name and a ready-check glyph
-- for its live collected state (color plus glyph, not color alone). Hovering
-- shows the appearance's item tooltip when a link is available.
local function CreateMemberChildRow(parentFrame, opts)
    local row = CreateFrame("Frame", nil, parentFrame, "BackdropTemplate")
    row:SetPoint("TOPLEFT",  parentFrame, "TOPLEFT",  18, opts.yOffset)
    row:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT", 0,  opts.yOffset)
    row:SetHeight(CHILD_ROW_HEIGHT)
    row:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("LEFT", row, "LEFT", 8, 0)
    icon:SetTexture(opts.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    local check = row:CreateTexture(nil, "ARTWORK")
    check:SetSize(16, 16)
    check:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    check:SetTexture(opts.collected
        and "Interface\\RaidFrame\\ReadyCheck-Ready"
        or  "Interface\\RaidFrame\\ReadyCheck-NotReady")

    local name = OneWoW_GUI:CreateFS(row, 11)
    name:SetPoint("LEFT",  icon, "RIGHT", 6, 0)
    name:SetPoint("RIGHT", check, "LEFT", -6, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    name:SetText(opts.name or UNKNOWN)
    name:SetTextColor(OneWoW_GUI:GetThemeColor(
        opts.collected and "TEXT_PRIMARY" or "TEXT_MUTED"))

    if opts.link then
        row:EnableMouse(true)
        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(opts.link)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    return row
end

function ns.UI.CreateCollectiblesTab(parent)
    do
        local p = ns.db.global.tabSortPrefs.collectibles
        currentSort.by        = p.by or "name"
        currentSort.ascending = p.ascending ~= false
    end

    -- Re-resolves display when the item cache fills in (appearance sources are
    -- commonly uncached on first view). Armed only while the shown editor has
    -- incomplete display data, disarmed once it resolves.
    local infoWatcher = CreateFrame("Frame")

    local controlPanel = CreateThemedBar(nil, parent)
    controlPanel:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, 0)
    controlPanel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    controlPanel:SetHeight(45)

    local catDD = ns.UI.CreateThemedDropdown(controlPanel, CATEGORY, 140, 25)
    catDD:SetPoint("TOPLEFT", controlPanel, "TOPLEFT", 10, -10)
    local function RefreshCatOptions()
        local opts = {{text = ALL, value = "All"}}
        for _, c in ipairs(ns.Collectibles:GetCategories()) do
            table.insert(opts, {text = c, value = c})
        end
        catDD:SetOptions(opts)
        catDD:SetSelected(categoryFilter)
    end
    RefreshCatOptions()
    catDD.onSelect = function(value)
        categoryFilter = value
        parent.RefreshCollectiblesList()
    end

    local manageCategoriesBtn = CreateFrame("Button", nil, controlPanel)
    manageCategoriesBtn:SetSize(20, 20)
    manageCategoriesBtn:SetPoint("LEFT", catDD, "RIGHT", 4, 0)
    manageCategoriesBtn:SetNormalTexture(MEDIA .. "icon-gears.png")
    manageCategoriesBtn:GetNormalTexture():SetTexCoord(0.1, 0.9, 0.1, 0.9)
    manageCategoriesBtn:SetHighlightTexture(MEDIA .. "icon-gears.png")
    manageCategoriesBtn:GetHighlightTexture():SetTexCoord(0.1, 0.9, 0.1, 0.9)
    manageCategoriesBtn:GetHighlightTexture():SetAlpha(0.5)
    manageCategoriesBtn:SetScript("OnClick", function()
        if ns.UI and ns.UI.ShowCategoryManager then
            ns.UI.ShowCategoryManager("collectibles")
        end
    end)
    manageCategoriesBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["CATMGR_TITLE"], 1, 1, 1)
        GameTooltip:AddLine(L["UI_MANAGE_CATEGORIES_DESC"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    manageCategoriesBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Type filter: derived live from the canonical key (mount:… / appearance:…),
    -- not a stored user field. Labels come from Blizzard globals so no new locale
    -- keys are needed. Only resolved types are offered.
    local typeDD = ns.UI.CreateThemedDropdown(controlPanel, TYPE, 120, 25)
    typeDD:SetPoint("LEFT", manageCategoriesBtn, "RIGHT", 4, 0)
    typeDD:SetOptions({
        {text = ALL,                     value = "All"},
        {text = MOUNTS,                  value = "mount"},
        {text = WARDROBE,                value = "appearance"},
        {text = WARDROBE_SETS,           value = "set"},
        {text = PETS,                    value = "pet"},
        {text = TOY_BOX,                 value = "toy"},
        {text = HEIRLOOMS,               value = "heirloom"},
        {text = CATALOG_SHOP_TYPE_DECOR, value = "decor"},
        {text = AUCTION_CATEGORY_RECIPES, value = "recipe"},
    })
    typeDD:SetSelected("All")
    typeDD.onSelect = function(value)
        typeFilter = value
        parent.RefreshCollectiblesList()
    end

    local storeDD = ns.UI.CreateThemedDropdown(controlPanel, L["LABEL_STORAGE"], 130, 25)
    storeDD:SetPoint("LEFT", typeDD, "RIGHT", 4, 0)
    storeDD:SetOptions({
        {text = ALL,                     value = "All"},
        {text = L["UI_STORAGE_ACCOUNT"], value = "account"},
        {text = CHARACTER,               value = "character"},
    })
    storeDD:SetSelected("All")
    storeDD.onSelect = function(value)
        storageFilter = value
        parent.RefreshCollectiblesList()
    end

    -- Collected filter: live state (GetCollectionState), not a stored field. Lets
    -- users who keep everything narrow to what they still need vs. already own.
    local collectedDD = ns.UI.CreateThemedDropdown(controlPanel, STATUS, 130, 25)
    collectedDD:SetPoint("LEFT", storeDD, "RIGHT", 4, 0)
    collectedDD:SetOptions({
        {text = ALL,           value = "All"},
        {text = COLLECTED,     value = "collected"},
        {text = NOT_COLLECTED, value = "uncollected"},
    })
    collectedDD:SetSelected("All")
    collectedDD.onSelect = function(value)
        collectedFilter = value
        parent.RefreshCollectiblesList()
    end

    local sortHandle = OneWoW_GUI:CreateSortControls(controlPanel, {
        sortFields = {
            {key = "name",     label = NAME},
            {key = "category", label = CATEGORY},
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

    local listingPanel = CreateThemedPanel(nil, parent)
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
    scrollChild = listScroll.scrollChild
    listScroll.container:SetPoint("TOPLEFT",     listingPanel, "TOPLEFT",     10, -62)
    listScroll.container:SetPoint("BOTTOMRIGHT", listingPanel, "BOTTOMRIGHT", -10, 10)

    detailPanel = CreateThemedPanel(nil, parent)
    detailPanel:SetPoint("TOPLEFT",     listingPanel, "TOPRIGHT",    10, 0)
    detailPanel:SetPoint("BOTTOMRIGHT", parent,       "BOTTOMRIGHT",  0, 35)
    detailPanel:SetClipsChildren(true)

    emptyMessage = OneWoW_GUI:CreateFS(detailPanel, 16)
    emptyMessage:SetPoint("CENTER", detailPanel, "CENTER")
    emptyMessage:SetText(L["COLLECTIBLES_SELECT"])
    emptyMessage:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local leftStatusBar = CreateThemedBar(nil, parent)
    leftStatusBar:SetPoint("TOPLEFT",  listingPanel, "BOTTOMLEFT",  0, -5)
    leftStatusBar:SetPoint("TOPRIGHT", listingPanel, "BOTTOMRIGHT", 0, -5)
    leftStatusBar:SetHeight(25)

    leftStatusText = OneWoW_GUI:CreateFS(leftStatusBar, 10)
    leftStatusText:SetPoint("LEFT", leftStatusBar, "LEFT", 10, 0)
    leftStatusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    leftStatusText:SetText(string.format(L["UI_COUNT_FORMAT"], L["TAB_COLLECTIBLES"], 0))

    local rightStatusBar = CreateThemedBar(nil, parent)
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
            ec.tooltipSection:SetPoint("TOPLEFT",  ec.contentBg, "BOTTOMLEFT",  0, -10)
            ec.tooltipSection:SetPoint("TOPRIGHT", ec.contentBg, "BOTTOMRIGHT", 0, -10)
            return
        end

        section.label:SetText(string.format("%s (%d)", L["COLLECTIBLE_SOLD_BY"], total))
        section:Show()
        ec.tooltipSection:ClearAllPoints()
        ec.tooltipSection:SetPoint("TOPLEFT",  section, "BOTTOMLEFT",  0, -10)
        ec.tooltipSection:SetPoint("TOPRIGHT", section, "BOTTOMRIGHT", 0, -10)

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

        -- Self-arming: keep listening only while this record's display is partial.
        if complete then
            infoWatcher:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
        else
            infoWatcher:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        end
    end

    local function HideEditor()
        if detailPanel.editorContent then
            for _, f in pairs(detailPanel.editorContent) do
                if type(f) == "table" and f.Hide then f:Hide() end
            end
        end
        if detailPanel.contentEditBox then detailPanel.contentEditBox:Hide() end
        infoWatcher:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
        emptyMessage:Show()
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
            local editorHeader = CreateThemedBar(nil, detailPanel)
            editorHeader:SetPoint("TOPLEFT",  detailPanel, "TOPLEFT",  10, -10)
            editorHeader:SetPoint("TOPRIGHT", detailPanel, "TOPRIGHT", -10, -10)
            editorHeader:SetHeight(90)

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

            local deleteBtn = CreateFrame("Button", nil, editorHeader)
            deleteBtn:SetSize(22, 22)
            deleteBtn:SetPoint("TOPRIGHT", editorHeader, "TOPRIGHT", -12, -12)
            deleteBtn:SetNormalTexture(MEDIA .. "icon-trash.png")
            deleteBtn:SetPushedTexture(MEDIA .. "icon-trash.png")
            deleteBtn:SetHighlightTexture(MEDIA .. "icon-trash.png")
            deleteBtn:GetHighlightTexture():SetAlpha(0.5)
            deleteBtn:SetScript("OnClick", DeleteSelected)
            deleteBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(DELETE, 1, 1, 1)
                GameTooltip:AddLine(L["COLLECTIBLE_DELETE_DESC"], 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            deleteBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            editorHeader.deleteBtn = deleteBtn

            local infoBar = CreateThemedBar(nil, detailPanel)
            infoBar:SetPoint("TOPLEFT",  editorHeader, "BOTTOMLEFT",  0, -10)
            infoBar:SetPoint("TOPRIGHT", editorHeader, "BOTTOMRIGHT", 0, -10)
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

            local contentBg = CreateThemedBar(nil, detailPanel)
            contentBg:SetPoint("TOPLEFT",  infoBar, "BOTTOMLEFT",  0, -10)
            contentBg:SetPoint("TOPRIGHT", infoBar, "BOTTOMRIGHT", 0, -10)
            contentBg:SetHeight(150)
            contentBg:EnableMouse(true)

            local contentScroll = OneWoW_GUI:CreateScrollFrame(contentBg, {})
            contentScroll:SetPoint("TOPLEFT",     contentBg, "TOPLEFT",     4, -4)
            contentScroll:SetPoint("BOTTOMRIGHT", contentBg, "BOTTOMRIGHT", -26, 4)
            contentBg:SetFrameLevel(contentScroll:GetFrameLevel() - 1)

            local contentEditBox = CreateFrame("EditBox", nil, contentScroll)
            contentEditBox:SetMultiLine(true)
            contentEditBox:SetFontObject("ChatFontNormal")
            contentEditBox:SetWidth(contentScroll:GetWidth() - 20)
            contentEditBox:SetAutoFocus(false)
            contentEditBox:SetMaxLetters(0)
            contentEditBox:SetHyperlinksEnabled(true)
            contentEditBox:SetScript("OnHyperlinkClick", function(_, link, text, button)
                SetItemRef(link, text, button)
            end)
            contentEditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
            contentEditBox:SetScript("OnTextChanged", function(self, userInput)
                if userInput and selectedKey then
                    local record = ns.Collectibles:GetCollectible(selectedKey)
                    if record then
                        record.content  = self:GetText()
                        record.modified = GetServerTime()
                    end
                end
            end)
            contentEditBox:SetScript("OnMouseUp", function(self, button)
                if button == "RightButton" and ns.NotesContextMenu then
                    ns.NotesContextMenu:ShowEditBoxContextMenu(self)
                end
            end)
            if ns.NotesHyperlinks then ns.NotesHyperlinks:EnhanceEditBox(contentEditBox) end
            contentScroll:SetScrollChild(contentEditBox)
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
            local soldBySection = CreateThemedBar(nil, detailPanel)
            soldBySection:SetPoint("TOPLEFT",  contentBg, "BOTTOMLEFT",  0, -10)
            soldBySection:SetPoint("TOPRIGHT", contentBg, "BOTTOMRIGHT", 0, -10)
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

            local tooltipSection = CreateThemedBar(nil, detailPanel)
            tooltipSection:SetPoint("TOPLEFT",  contentBg, "BOTTOMLEFT",  0, -10)
            tooltipSection:SetPoint("TOPRIGHT", contentBg, "BOTTOMRIGHT", 0, -10)

            local ttLabel = OneWoW_GUI:CreateFS(tooltipSection, 12)
            ttLabel:SetPoint("TOPLEFT", tooltipSection, "TOPLEFT", 10, -8)
            ttLabel:SetText(L["UI_TOOLTIP_LINES"])
            ttLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

            local tooltipEdits = {}
            for i = 1, 4 do
                local edit = CreateFrame("EditBox", nil, tooltipSection, "InputBoxTemplate")
                edit:SetHeight(22)
                edit:SetPoint("TOPLEFT",  tooltipSection, "TOPLEFT",  10, -30 - (i - 1) * 28)
                edit:SetPoint("TOPRIGHT", tooltipSection, "TOPRIGHT", -10, -30 - (i - 1) * 28)
                edit:SetAutoFocus(false)
                edit:SetMaxLetters(255)
                edit:SetHyperlinksEnabled(true)
                edit:SetScript("OnHyperlinkClick", function(_, link, text, button)
                    SetItemRef(link, text, button)
                end)
                edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
                edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
                edit:SetScript("OnTextChanged", function(self, userInput)
                    if userInput and selectedKey then
                        local record = ns.Collectibles:GetCollectible(selectedKey)
                        if record then
                            if not record.tooltipLines then record.tooltipLines = {"", "", "", ""} end
                            record.tooltipLines[i] = self:GetText()
                            record.modified = GetServerTime()
                        end
                    end
                end)
                edit:SetScript("OnMouseUp", function(self, button)
                    if button == "RightButton" and ns.NotesContextMenu then
                        ns.NotesContextMenu:ShowEditBoxContextMenu(self)
                    end
                end)
                if ns.NotesHyperlinks then ns.NotesHyperlinks:EnhanceEditBox(edit) end
                tooltipEdits[i] = edit
            end
            tooltipSection:SetHeight(38 + 4 * 28)

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

    local function CreateSectionHeader(text, yPos)
        local section = OneWoW_GUI:CreateSectionHeader(scrollChild, { title = text, yOffset = yPos })
        table.insert(collListRows, section)
        return section
    end

    function parent.RefreshCollectiblesList()
        for _, row in pairs(collListRows) do
            row:Hide()
        end
        collListRows = {}

        local all = ns.Collectibles:GetAll()
        local list = {}
        for key, record in pairs(all) do
            if type(record) == "table" then
                local name = select(1, ResolveRow(key, record))
                local matches = true
                if categoryFilter ~= "All" and record.category ~= categoryFilter then matches = false end
                if matches and typeFilter ~= "All" then
                    -- The canonical key is authoritative for type (record.type is a
                    -- create-time convenience copy); derive it live.
                    local descriptor = OneWoW.Collectibles.ParseKey(key)
                    if not descriptor or descriptor.type ~= typeFilter then matches = false end
                end
                if matches and storageFilter ~= "All" and record.storage ~= storageFilter then matches = false end
                if matches and collectedFilter ~= "All" then
                    local state = OneWoW.Collectibles.GetCollectionState(key)
                    local isCollected = state and state.collected or false
                    if collectedFilter == "collected" and not isCollected then matches = false end
                    if collectedFilter == "uncollected" and isCollected then matches = false end
                end
                if matches and searchFilter ~= "" then
                    if not name:lower():find(searchFilter:lower(), 1, true) then matches = false end
                end
                if matches then
                    list[#list + 1] = { key = key, record = record, name = name }
                end
            end
        end

        local function sortEntries(a, b)
            -- Recycle-bin (delete-intent) rows always sink to the bottom, whatever
            -- the active sort; within each group the chosen sort applies.
            local aDel = a.record.intent == "delete"
            local bDel = b.record.intent == "delete"
            if aDel ~= bDel then return bDel end
            if currentSort.by == "category" then
                local ca = a.record.category or ""
                local cb = b.record.category or ""
                if ca == cb then return a.name < b.name end
                if currentSort.ascending then return ca < cb else return ca > cb end
            elseif currentSort.by == "modified" then
                if currentSort.ascending then return (a.record.modified or 0) < (b.record.modified or 0)
                else return (a.record.modified or 0) > (b.record.modified or 0) end
            else
                if currentSort.ascending then return a.name < b.name else return a.name > b.name end
            end
        end
        table.sort(list, sortEntries)

        local yOffset = 0
        if #list > 0 then
            CreateSectionHeader(L["TAB_COLLECTIBLES"], yOffset)
            yOffset = yOffset - 30
        end

        for _, entry in ipairs(list) do
            local _, icon = ResolveRow(entry.key, entry.record)
            local state = OneWoW.Collectibles.GetCollectionState(entry.key)
            local barColor
            if state then
                local cr, cg, cb = OneWoW_GUI:GetThemeColor(
                    state.collected and "TEXT_FEATURES_ENABLED" or "TEXT_FEATURES_DISABLED")
                barColor = { cr, cg, cb }
            end

            local intent = entry.record.intent or "none"
            local detailText = intent ~= "none" and IntentLabel(intent) or nil

            local key = entry.key
            local descriptor = OneWoW.Collectibles.ParseKey(key)
            local isSet = descriptor and descriptor.type == "set"

            -- A set gets an expand caret; the collected/total rolls up onto the
            -- parent's detail line so the count reads at a glance while collapsed.
            local rowDetail = detailText
            if isSet and state and state.total and state.total > 0 then
                local prog = string.format("%d/%d", state.numCollected or 0, state.total)
                rowDetail = detailText and (detailText .. "  " .. prog) or prog
            end

            local rowOpts = {
                yOffset     = yOffset,
                barColor    = barColor,
                icon        = icon,
                title       = entry.name,
                detail      = rowDetail,
                storageText = entry.record.storage == "character" and CHARACTER or L["UI_STORAGE_ACCOUNT"],
                selected    = (selectedKey == key),
                onSelect    = function()
                    selectedKey = key
                    ShowEditor()
                    parent.RefreshCollectiblesList()
                end,
                delete = {
                    tooltip = { title = DELETE, desc = L["COLLECTIBLE_DELETE_DESC"] },
                    onClick = function()
                        selectedKey = key
                        DeleteSelected()
                    end,
                },
            }
            if isSet then
                rowOpts.expand = {
                    expanded = expandedSets[key] == true,
                    tooltip  = { title = L["COLLECTIBLE_SET_MEMBERS"] },
                    onToggle = function()
                        expandedSets[key] = not expandedSets[key]
                        parent.RefreshCollectiblesList()
                    end,
                }
            end

            local row = ns.UI.CreateNotesListRow(scrollChild, rowOpts)
            -- Recycle-bin rows read as "on the way out": dimmed but still fully
            -- interactive (select to restore its intent, or delete now).
            row:SetAlpha(entry.record.intent == "delete" and 0.5 or 1)
            table.insert(collListRows, row)
            yOffset = yOffset - ns.UI.LIST_ROW_SPACING

            -- Expanded set: render its per-slot member appearances as read-only,
            -- live child rows (no records, no selection — the set is the record).
            if isSet and expandedSets[key] then
                local members = OneWoW.Collectibles.GetSetMembers(descriptor.id)
                if members then
                    for _, member in ipairs(members) do
                        local child = CreateMemberChildRow(scrollChild, {
                            yOffset   = yOffset,
                            icon      = member.icon,
                            name      = member.name,
                            link      = member.link,
                            collected = member.collected,
                        })
                        table.insert(collListRows, child)
                        yOffset = yOffset - CHILD_ROW_SPACING
                    end
                end
            end
        end

        scrollChild:SetHeight(math.abs(yOffset) + 50)
        if leftStatusText then
            leftStatusText:SetText(string.format(L["UI_COUNT_FORMAT"], L["TAB_COLLECTIBLES"], #list))
        end
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
