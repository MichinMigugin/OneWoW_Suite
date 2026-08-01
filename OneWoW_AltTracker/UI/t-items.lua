local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI
local PE = OneWoW.PredicateEngine
local SE = OneWoW.SearchExpand

ns.UI = ns.UI or {}

local function MatchesSearch(itemData, searchText)
    if not searchText or searchText == "" then return true end
    local itemInfo = {
        hyperlink = itemData.itemLink,
        count = itemData.totalQty or 1,
        quality = itemData.quality,
    }
    if itemData.vendorPrice and itemData.vendorPrice > 0 then
        itemInfo.vendorprice = itemData.vendorPrice
    end
    local ok, matched = pcall(SE.CheckItem, SE, searchText, itemData.itemID, nil, nil, itemInfo)
    if ok then return matched == true end
    local name = itemData.itemName
    return name and name:lower():find(searchText:lower(), 1, true) ~= nil
end

local itemRows = {}
local filterText = ""
local hidebound = false
local hideNoVendor = false
local currentSortColumn = "item"
local currentSortAscending = true

local columnsConfig = {
    {key = "expand", label = "",                      width = 25,  fixed = true,  align = "icon",   sortable = false, ttTitle = L["TT_COL_EXPAND"],          ttDesc = L["TT_COL_EXPAND_DESC"]},
    {key = "favorite", label = L["ITEMS_COL_FAVORITE"], width = 28, fixed = true, align = "center", sortable = false, ttTitle = L["TT_ITEMS_COL_FAVORITE"], ttDesc = L["TT_ITEMS_COL_FAVORITE_DESC"]},
    {key = "item",   label = L["ITEM"],     width = 150, fixed = false, align = "left",                     ttTitle = L["ITEM"],     ttDesc = L["TT_COL_ITEM_DESC"]},
    {key = "total",  label = TOTAL,    width = 45,  fixed = true,  align = "center",                   ttTitle = TOTAL,    ttDesc = L["TT_ITEMS_COL_TOTAL_DESC"]},
    {key = "vendor", label = L["ITEMS_COL_VENDOR"],   width = 80,  fixed = false, align = "right",                    ttTitle = L["TT_ITEMS_COL_VENDOR"],   ttDesc = L["TT_ITEMS_COL_VENDOR_DESC"]},
    {key = "ah",     label = L["ITEMS_COL_AH"],       width = 80,  fixed = false, align = "right",                    ttTitle = L["TT_ITEMS_COL_AH"],       ttDesc = L["TT_ITEMS_COL_AH_DESC"]},
    {key = "lastseen", label = L["COL_LAST_SEEN"], width = 85, fixed = true, align = "center",                  ttTitle = L["COL_LAST_SEEN"], ttDesc = L["TT_ITEMS_COL_LAST_SEEN_DESC"]},
}

local onHeaderCreate = function(btn, col, _)
    if col.key == "expand" then
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(14, 14)
        icon:SetPoint("CENTER")
        icon:SetAtlas("Gamepad_Rev_Plus_64")
        btn.icon = icon
        if btn.text then btn.text:SetText("") end
    elseif col.key == "favorite" then
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(14, 14)
        icon:SetPoint("CENTER")
        OneWoW_GUI:SetFavoriteAtlasTexture(icon)
        if btn.text then btn.text:SetText("") end
    end
end

-- ===========================================================================
-- Duplicate view-mode. Toggling the "Duplicates" control switches the Items tab
-- into a dupe grouping with adaptive columns, driven by the Storage Query API
-- (FindDuplicates). Module-level so RefreshItemsTab can branch on it.
-- ===========================================================================

local dupeMode = false
local dupeSpec  -- lazily seeded from OneWoW_AltTracker_Storage_API.GetDefaultDupeSpec()

local dupeColumnsConfig = {
    {key = "expand",    label = "",                     width = 25,  fixed = true,  align = "icon",   sortable = false, ttTitle = L["TT_COL_EXPAND"],     ttDesc = L["TT_COL_EXPAND_DESC"]},
    {key = "item",      label = L["ITEM"],              width = 140, fixed = false, align = "left",   sortable = false, ttTitle = L["ITEM"],              ttDesc = L["TT_COL_ITEM_DESC"]},
    {key = "itemid",    label = L["ITEMS_COL_ITEMID"],  width = 55,  fixed = true,  align = "center", sortable = false, ttTitle = L["ITEMS_COL_ITEMID"],  ttDesc = L["TT_ITEMS_COL_ITEMID_DESC"]},
    {key = "ilvl",      label = ITEM_LEVEL_ABBR,        width = 55,  fixed = true,  align = "center", sortable = false, ttTitle = ITEM_LEVEL_ABBR,        ttDesc = L["TT_ITEMS_COL_ILVL_DESC"]},
    {key = "copies",    label = L["ITEMS_COL_COPIES"],  width = 50,  fixed = true,  align = "center", sortable = false, ttTitle = L["ITEMS_COL_COPIES"],  ttDesc = L["TT_ITEMS_COL_COPIES_DESC"]},
    {key = "total",     label = TOTAL,                  width = 50,  fixed = true,  align = "center", sortable = false, ttTitle = TOTAL,                  ttDesc = L["TT_ITEMS_COL_TOTAL_DESC"]},
    {key = "primary",   label = PRIMARY,                width = 70,  fixed = true,  align = "center", sortable = false, ttTitle = PRIMARY,                ttDesc = L["TT_ITEMS_COL_PRIMARY_DESC"]},
    {key = "secondary", label = SECONDARY,              width = 80,  fixed = false, align = "left",   sortable = false, ttTitle = SECONDARY,              ttDesc = L["TT_ITEMS_COL_SECONDARY_DESC"]},
    {key = "socket",    label = L["DUPE_OPT_SOCKET"],   width = 50,  fixed = true,  align = "center", sortable = false, ttTitle = L["DUPE_OPT_SOCKET"],   ttDesc = L["TT_ITEMS_COL_SOCKET_DESC"]},
    {key = "track",     label = L["DUPE_OPT_TRACK"],    width = 85,  fixed = true,  align = "center", sortable = false, ttTitle = L["DUPE_OPT_TRACK"],    ttDesc = L["TT_ITEMS_COL_TRACK_DESC"]},
    {key = "lastseen",  label = L["COL_LAST_SEEN"],     width = 85,  fixed = true,  align = "center", sortable = false, ttTitle = L["COL_LAST_SEEN"],     ttDesc = L["TT_ITEMS_COL_LAST_SEEN_DESC"]},
}

local DUPE_PRESETS = {
    {value = "same_item",      key = "DUPE_PRESET_SAME_ITEM",      descKey = "TT_DUPE_PRESET_SAME_ITEM_DESC"},
    {value = "same_item_ilvl", key = "DUPE_PRESET_SAME_ITEM_ILVL", descKey = "TT_DUPE_PRESET_SAME_ITEM_ILVL_DESC"},
    {value = "same_gear",      key = "DUPE_PRESET_SAME_GEAR",      descKey = "TT_DUPE_PRESET_SAME_GEAR_DESC"},
    {value = "similar_gear",   key = "DUPE_PRESET_SIMILAR_GEAR",   descKey = "TT_DUPE_PRESET_SIMILAR_GEAR_DESC"},
}

-- Attach a hover tooltip to a control without clobbering its existing OnEnter
-- (dropdowns set a border-focus handler; HookScript preserves it).
local function AttachTooltip(frame, title, desc)
    frame:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title or "", 1, 1, 1)
        if desc and desc ~= "" then GameTooltip:AddLine(desc, nil, nil, nil, true) end
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

local DUPE_ILVL_MODES = {
    {value = "off",   key = "DUPE_ILVL_OFF"},
    {value = "exact", key = "DUPE_ILVL_EXACT"},
    {value = "range", key = "DUPE_ILVL_RANGE"},
}

local function IlvlModeLabel(mode)
    for _, m in ipairs(DUPE_ILVL_MODES) do
        if m.value == mode then return L[m.key] end
    end
    return L["DUPE_ILVL_RANGE"]
end

-- The grouping-relevant fields decide whether a spec equals a named preset;
-- ilvlTolerance and minCount don't affect identity, so they're left out.
local function SpecMatchesPreset(spec, preset)
    return spec.mode == preset.mode
        and spec.ilvlMode == preset.ilvlMode
        and spec.matchPrimary == preset.matchPrimary
        and spec.matchSecondary == preset.matchSecondary
        and spec.matchSocket == preset.matchSocket
        and (spec.matchTrack and true or false) == (preset.matchTrack and true or false)
end

local function PresetLabelForSpec(spec)
    local api = OneWoW_AltTracker_Storage_API
    local presets = api and api.GetDupePresets and api.GetDupePresets()
    if presets then
        for _, def in ipairs(DUPE_PRESETS) do
            local p = presets[def.value]
            if p and SpecMatchesPreset(spec, p) then return L[def.key] end
        end
    end
    return CUSTOM
end

-- Load the persisted dupe spec (account-wide), seeding from the Storage default
-- on first use and back-filling newly added fields so older saves stay valid.
-- dupeSpec aliases the SavedVariables table, so toggle changes persist directly.
local function EnsureDupeSpec()
    if dupeSpec then return dupeSpec end
    local api = OneWoW_AltTracker_Storage_API
    local defaults = (api and api.GetDefaultDupeSpec and api.GetDefaultDupeSpec()) or {}
    local stored = ns.db.global.dupeSpec
    for k, v in pairs(defaults) do
        if stored[k] == nil then stored[k] = v end
    end
    dupeSpec = stored
    return dupeSpec
end

-- Build the dupe controls row (preset + iLvl mode dropdowns, stat/socket/similar
-- toggles). Lives below the filter bar and is shown only in dupe mode. onChanged
-- is called after any control change so the caller re-renders the dupe view.
function ns.UI.BuildDupeControls(parent, anchorBar, onChanged)
    local api = OneWoW_AltTracker_Storage_API
    EnsureDupeSpec()

    local bar = OneWoW_GUI:CreateFilterBar(parent, { height = 32, anchorBelow = anchorBar, offset = -5 })

    local presetDropdown, presetText
    local ilvlDropdown, ilvlText
    local cbPrimary, cbSecondary, cbSocket, cbSimilar, cbTrack

    local function SyncControls()
        cbPrimary:SetChecked(dupeSpec.matchPrimary)
        cbSecondary:SetChecked(dupeSpec.matchSecondary)
        cbSocket:SetChecked(dupeSpec.matchSocket)
        cbSimilar:SetChecked(dupeSpec.mode == "similar")
        cbTrack:SetChecked(dupeSpec.matchTrack)
        ilvlText:SetText(IlvlModeLabel(dupeSpec.ilvlMode))
        ilvlDropdown._activeValue = dupeSpec.ilvlMode
        presetText:SetText(PresetLabelForSpec(dupeSpec))
    end

    -- descKey of the preset the spec currently matches, or nil when "Custom".
    local function ActivePresetDescKey()
        local presets = api and api.GetDupePresets and api.GetDupePresets()
        if presets then
            for _, def in ipairs(DUPE_PRESETS) do
                local p = presets[def.value]
                if p and SpecMatchesPreset(dupeSpec, p) then return def.descKey end
            end
        end
        return nil
    end

    -- A manual toggle change may no longer match any preset -> relabel to Custom.
    local function OnToggleChanged()
        presetText:SetText(PresetLabelForSpec(dupeSpec))
        if onChanged then onChanged() end
    end

    presetDropdown, presetText = OneWoW_GUI:CreateDropdown(bar, { width = 130, height = 22, text = PresetLabelForSpec(dupeSpec) })
    presetDropdown:SetPoint("LEFT", bar, "LEFT", 8, 0)
    OneWoW_GUI:AttachFilterMenu(presetDropdown, {
        searchable = false,
        buildItems = function()
            local items = {}
            for _, def in ipairs(DUPE_PRESETS) do
                items[#items + 1] = {
                    text = L[def.key], value = def.value,
                    onEnter = function(b)
                        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
                        GameTooltip:SetText(L[def.key], 1, 1, 1)
                        GameTooltip:AddLine(L[def.descKey], nil, nil, nil, true)
                        GameTooltip:Show()
                    end,
                    onLeave = function() GameTooltip:Hide() end,
                }
            end
            return items
        end,
        onSelect = function(value)
            local presets = api and api.GetDupePresets and api.GetDupePresets()
            local preset = presets and presets[value]
            if preset then
                for k, v in pairs(preset) do dupeSpec[k] = v end
            end
            SyncControls()
            if onChanged then onChanged() end
        end,
    })
    -- Closed-control tooltip: explain the currently active preset (or the feature
    -- when the spec is Custom).
    presetDropdown:HookScript("OnEnter", function(self)
        local descKey = ActivePresetDescKey()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["DUPE_TOGGLE"], 1, 1, 1)
        GameTooltip:AddLine(descKey and L[descKey] or L["TT_DUPE_TOGGLE_DESC"], nil, nil, nil, true)
        GameTooltip:Show()
    end)
    presetDropdown:HookScript("OnLeave", function() GameTooltip:Hide() end)

    ilvlDropdown, ilvlText = OneWoW_GUI:CreateDropdown(bar, { width = 95, height = 22, text = IlvlModeLabel(dupeSpec.ilvlMode) })
    ilvlDropdown:SetPoint("LEFT", presetDropdown, "RIGHT", 6, 0)
    ilvlDropdown._activeValue = dupeSpec.ilvlMode
    OneWoW_GUI:AttachFilterMenu(ilvlDropdown, {
        searchable = false,
        getActiveValue = function() return ilvlDropdown._activeValue end,
        buildItems = function()
            local items = {}
            for _, m in ipairs(DUPE_ILVL_MODES) do
                items[#items + 1] = { text = L[m.key], value = m.value }
            end
            return items
        end,
        onSelect = function(value, text)
            dupeSpec.ilvlMode = value
            ilvlText:SetText(text)
            OnToggleChanged()
        end,
    })
    AttachTooltip(ilvlDropdown, ITEM_LEVEL_ABBR, L["TT_DUPE_ILVL_DESC"])

    cbPrimary = OneWoW_GUI:CreateCheckbox(bar, { label = PRIMARY, checked = dupeSpec.matchPrimary })
    cbPrimary:SetPoint("LEFT", ilvlDropdown, "RIGHT", 10, 0)
    cbPrimary:SetScript("OnClick", function(self) dupeSpec.matchPrimary = self:GetChecked() and true or false OnToggleChanged() end)
    AttachTooltip(cbPrimary, PRIMARY, L["TT_ITEMS_COL_PRIMARY_DESC"])

    cbSecondary = OneWoW_GUI:CreateCheckbox(bar, { label = SECONDARY, checked = dupeSpec.matchSecondary })
    cbSecondary:SetPoint("LEFT", cbPrimary.label, "RIGHT", 10, 0)
    cbSecondary:SetScript("OnClick", function(self) dupeSpec.matchSecondary = self:GetChecked() and true or false OnToggleChanged() end)
    AttachTooltip(cbSecondary, SECONDARY, L["TT_ITEMS_COL_SECONDARY_DESC"])

    cbSocket = OneWoW_GUI:CreateCheckbox(bar, { label = L["DUPE_OPT_SOCKET"], checked = dupeSpec.matchSocket })
    cbSocket:SetPoint("LEFT", cbSecondary.label, "RIGHT", 10, 0)
    cbSocket:SetScript("OnClick", function(self) dupeSpec.matchSocket = self:GetChecked() and true or false OnToggleChanged() end)
    AttachTooltip(cbSocket, L["DUPE_OPT_SOCKET"], L["TT_ITEMS_COL_SOCKET_DESC"])

    cbTrack = OneWoW_GUI:CreateCheckbox(bar, { label = L["DUPE_OPT_TRACK"], checked = dupeSpec.matchTrack })
    cbTrack:SetPoint("LEFT", cbSocket.label, "RIGHT", 10, 0)
    cbTrack:SetScript("OnClick", function(self) dupeSpec.matchTrack = self:GetChecked() and true or false OnToggleChanged() end)
    AttachTooltip(cbTrack, L["DUPE_OPT_TRACK"], L["TT_ITEMS_COL_TRACK_DESC"])

    cbSimilar = OneWoW_GUI:CreateCheckbox(bar, { label = L["DUPE_OPT_SIMILAR"], checked = dupeSpec.mode == "similar" })
    cbSimilar:SetPoint("LEFT", cbTrack.label, "RIGHT", 10, 0)
    cbSimilar:SetScript("OnClick", function(self) dupeSpec.mode = self:GetChecked() and "similar" or "item" OnToggleChanged() end)
    AttachTooltip(cbSimilar, L["DUPE_OPT_SIMILAR"], L["TT_DUPE_OPT_SIMILAR_DESC"])

    return bar
end

-- Live refresh: re-render the Items tab when storage changes underneath it (e.g.
-- moving an item bank<->bags), debounced and gated on visibility. Drives both the
-- default and dupe views via RefreshItemsTab's branch.
local itemsTabRef
local itemsRefreshPending = false
local storageSubscribed = false

local function ScheduleItemsRefresh()
    if itemsRefreshPending then return end
    itemsRefreshPending = true
    C_Timer.After(0.3, function()
        itemsRefreshPending = false
        local tab = itemsTabRef
        if tab and tab:IsVisible() then
            ns.UI.RefreshItemsTab(tab)
        end
    end)
end

function ns.UI.CreateItemsTab(parent)
    local SetDupeMode, AnchorRoster, dupeControls
    local overview = OneWoW_GUI:CreateOverviewPanel(parent, {
        height = 70,
        columns = 5,
        stats = {
            {label = L["ITEMS_STAT_UNIQUE"],       value = "0", ttTitle = L["ITEMS_STAT_UNIQUE"],       ttDesc = L["TT_ITEMS_STAT_UNIQUE_DESC"]},
            {label = L["ITEMS_STAT_TOTAL_QTY"],    value = "0", ttTitle = L["TT_ITEMS_STAT_TOTAL_QTY"],    ttDesc = L["TT_ITEMS_STAT_TOTAL_QTY_DESC"]},
            {label = L["ITEMS_STAT_VENDOR_VALUE"],  value = "0", ttTitle = L["TT_ITEMS_STAT_VENDOR_VALUE"], ttDesc = L["TT_ITEMS_STAT_VENDOR_VALUE_DESC"]},
            {label = L["ITEMS_STAT_AH_VALUE"],     value = "0", ttTitle = L["ITEMS_STAT_AH_VALUE"],     ttDesc = L["TT_ITEMS_STAT_AH_VALUE_DESC"]},
            {label = L["ITEMS_STAT_BOUND"],        value = "0", ttTitle = L["ITEMS_STAT_BOUND"],        ttDesc = L["TT_ITEMS_STAT_BOUND_DESC"]},
        },
    })

    local filterBar = OneWoW_GUI:CreateFilterBar(parent, { height = 32, anchorBelow = overview.panel, offset = -8 })

    local searchBox = OneWoW_GUI:CreateEditBox(filterBar, {
        height = 20,
        placeholderText = L["SEARCH_ITEMS"],
        onTextChanged = function(text)
            filterText = text
            if ns.UI.RefreshItemsTab then
                ns.UI.RefreshItemsTab(parent)
            end
        end,
    })
    if OneWoW_GUI.AttachSearchTooltip then
        OneWoW_GUI:AttachSearchTooltip(searchBox)
    end
    local searchHelpBtn
    if OneWoW_GUI.CreateKeywordHelpButton then
        searchHelpBtn = OneWoW_GUI:CreateKeywordHelpButton(filterBar, { editBox = searchBox, size = 20 })
    end

    -- Filter checkboxes sit at the far right; the search box flexes to fill the
    -- space to their left.
    local filterCluster = CreateFrame("Frame", nil, filterBar)
    filterCluster:SetHeight(20)
    filterCluster:SetPoint("RIGHT", filterBar, "RIGHT", -8, 0)

    local checkBound = OneWoW_GUI:CreateCheckbox(filterCluster, { label = L["ITEMS_FILTER_BOUND"] })
    checkBound:SetPoint("LEFT", filterCluster, "LEFT", 0, 0)
    checkBound:SetScript("OnClick", function(self)
        hidebound = self:GetChecked()
        if ns.UI.RefreshItemsTab then
            ns.UI.RefreshItemsTab(parent)
        end
    end)

    local checkVendor = OneWoW_GUI:CreateCheckbox(filterCluster, { label = L["ITEMS_FILTER_NO_VENDOR"] })
    checkVendor:SetPoint("LEFT", checkBound.label, "RIGHT", 15, 0)
    checkVendor:SetScript("OnClick", function(self)
        hideNoVendor = self:GetChecked()
        if ns.UI.RefreshItemsTab then
            ns.UI.RefreshItemsTab(parent)
        end
    end)

    local checkDupes = OneWoW_GUI:CreateCheckbox(filterCluster, { label = L["DUPE_TOGGLE"] })
    checkDupes:SetPoint("LEFT", checkVendor.label, "RIGHT", 15, 0)
    checkDupes:SetScript("OnClick", function(self)
        SetDupeMode(self:GetChecked() and true or false)
    end)
    checkDupes:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["TT_DUPE_TOGGLE"], 1, 1, 1)
        GameTooltip:AddLine(L["TT_DUPE_TOGGLE_DESC"], nil, nil, nil, true)
        GameTooltip:Show()
    end)
    checkDupes:SetScript("OnLeave", function() GameTooltip:Hide() end)
    parent.checkDupes = checkDupes

    -- Size the cluster to its checkboxes so the right anchor lines up; re-measure
    -- once strings/fonts settle (label widths are 0 before first layout).
    local function SizeFilterCluster()
        filterCluster:SetWidth(checkBound:GetMeasuredWidth() + 15 + checkVendor:GetMeasuredWidth() + 15 + checkDupes:GetMeasuredWidth())
    end
    SizeFilterCluster()
    C_Timer.After(0, SizeFilterCluster)

    -- Search box (+ keyword help) flex to fill the space left of the cluster.
    searchBox:SetPoint("LEFT", filterBar, "LEFT", 8, 0)
    if searchHelpBtn then
        searchHelpBtn:SetPoint("RIGHT", filterCluster, "LEFT", -8, 0)
        searchBox:SetPoint("RIGHT", searchHelpBtn, "LEFT", -4, 0)
    else
        searchBox:SetPoint("RIGHT", filterCluster, "LEFT", -8, 0)
    end
    local noticeBar = OneWoW_GUI:CreateFrame(parent, { height = 28, bgColor = "BG_SECONDARY", borderColor = "BORDER_SUBTLE" })
    noticeBar:SetPoint("TOPLEFT", filterBar, "BOTTOMLEFT", 0, -5)
    noticeBar:SetPoint("TOPRIGHT", filterBar, "BOTTOMRIGHT", 0, -5)
    parent.noticeBar = noticeBar

    local noticeText = OneWoW_GUI:CreateFS(noticeBar, 12)
    noticeText:SetPoint("LEFT", noticeBar, "LEFT", 12, 0)
    noticeText:SetPoint("RIGHT", noticeBar, "RIGHT", -12, 0)
    noticeText:SetJustifyH("LEFT")
    noticeText:SetWordWrap(true)
    noticeText:SetText(L["ITEMS_NOTICE"])
    noticeText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
    parent.noticeText = noticeText

    dupeControls = ns.UI.BuildDupeControls(parent, filterBar, function()
        ns.UI.RefreshItemsTab(parent)
    end)
    dupeControls:Hide()
    parent.dupeControls = dupeControls

    local rosterPanel = OneWoW_GUI:CreateRosterPanel(parent, noticeBar)

    -- Re-anchor the roster (table) below whichever bar is active: the notice in
    -- the default view, the dupe controls in dupe mode.
    AnchorRoster = function(anchor)
        rosterPanel:ClearAllPoints()
        rosterPanel:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
        rosterPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -5, 30)
    end

    local dt
    dt = OneWoW_GUI:CreateDataTable(rosterPanel, {
        columns = columnsConfig,
        headerHeight = 26,
        onHeaderCreate = onHeaderCreate,
        onSort = function(sortColumn, sortAscending)
            currentSortColumn = sortColumn
            currentSortAscending = sortAscending
            ns.UI.RefreshItemsTab(parent)
            C_Timer.After(0.1, function() dt.UpdateSortIndicators() end)
        end,
    })

    local status = OneWoW_GUI:CreateStatusBar(parent, rosterPanel, {
        text = "",
    })

    parent.overviewPanel = overview.panel
    parent.statBoxes = overview.statBoxes
    parent.filterBar = filterBar
    parent.searchBox = searchBox
    parent.checkBound = checkBound
    parent.checkVendor = checkVendor
    parent.rosterPanel = rosterPanel
    parent.dataTable = dt
    parent.columnsConfig = columnsConfig
    parent.headerRow = dt.headerRow
    parent.scrollContent = dt.scrollContent
    parent.statusBar = status.bar
    parent.statusText = status.text

    -- Switch the Items tab between the default view and the dupe view: swap the
    -- data table columns, show the matching controls bar, re-anchor the table,
    -- then re-render. The default gather/render path is left entirely intact.
    SetDupeMode = function(on)
        dupeMode = on and true or false
        if dupeMode then
            EnsureDupeSpec()
            noticeBar:Hide()
            dupeControls:Show()
            AnchorRoster(dupeControls)
            dt:SetColumns(dupeColumnsConfig)
        else
            dupeControls:Hide()
            noticeBar:Show()
            AnchorRoster(noticeBar)
            dt:SetColumns(columnsConfig)
        end
        ns.UI.RefreshItemsTab(parent)
    end

    OneWoW_GUI:ApplyFontToFrame(parent)

    -- Subscribe once storage's data is queryable (LoD mid-session load included).
    itemsTabRef = parent
    OneWoW:RegisterDataReadyWatcher("OneWoW_AltTracker_Storage", function()
        if not storageSubscribed and OneWoW_AltTracker_Storage_API
            and OneWoW_AltTracker_Storage_API.RegisterStorageChanged then
            storageSubscribed = true
            OneWoW_AltTracker_Storage_API.RegisterStorageChanged(ScheduleItemsRefresh)
        end
        if ns.UI.RefreshItemsTab then
            ns.UI.RefreshItemsTab(parent)
        end
    end)
end

local function FormatLastSeen(timestamp)
    if not timestamp or timestamp == 0 then return NEVER end
    local hours = (time() - timestamp) / 3600
    if hours < 24 then
        return math.max(1, math.floor(hours)) .. " hr"
    else
        local days = math.floor(hours / 24)
        if days <= 365 then
            return days .. "d"
        else
            return "Over 1yr"
        end
    end
end

local function ResolveItemData(itemData)
    local itemName = itemData.itemName
    local texture  = itemData.texture
    local itemLink = itemData.itemLink
    local vendorPrice = itemData.sellPrice or 0

    -- Prefer a link-based live lookup so the vendor price reflects the
    -- per-variant sell price (bonus IDs, item level, crafted quality),
    -- matching the OneWoW Tooltips "Value" line.
    local lookupKey = itemLink or itemData.itemID
    if lookupKey then
        local name, link, _, _, _, _, _, _, _, tex, sell = C_Item.GetItemInfo(lookupKey)
        if name then
            itemName = itemName or name
            itemLink = itemLink or link
            texture  = texture  or tex
            if sell and sell > 0 then
                vendorPrice = sell
            end
        end
    end

    return itemName, texture, itemLink, vendorPrice
end

local function AddToLocation(item, charName, location, qty)
    local locKey = charName .. "|" .. location
    if not item.locationIndex then item.locationIndex = {} end
    if item.locationIndex[locKey] then
        item.locationIndex[locKey].qty = item.locationIndex[locKey].qty + qty
    else
        local entry = { charName = charName, location = location, qty = qty }
        table.insert(item.locations, entry)
        item.locationIndex[locKey] = entry
    end
end

-- ---------------------------------------------------------------------------
-- Dupe view-mode render path (uses the Storage Query API; default path above
-- is untouched).
-- ---------------------------------------------------------------------------

-- Position a dupe row's cells against the data table's resolved column layout.
-- Same math as the default view's inline block, parameterized by column set.
local function PositionRowCells(itemRow, dt, columns, rowHeight)
    if not (dt and dt.headerRow and dt.headerRow.columnButtons and columns) then return end
    for i, cell in ipairs(itemRow.cells) do
        local btn = dt.headerRow.columnButtons[i]
        if btn and btn.columnWidth and btn.columnX then
            local width = btn.columnWidth
            local x = btn.columnX
            local col = columns[i]
            cell:ClearAllPoints()
            if col and col.align == "icon" then
                cell:SetSize(width, rowHeight)
                cell:SetPoint("LEFT", itemRow, "LEFT", x, 0)
            elseif col and col.align == "center" then
                cell:SetWidth(width - 6)
                cell:SetPoint("CENTER", itemRow, "LEFT", x + width / 2, 0)
            elseif col and col.align == "right" then
                cell:SetWidth(width - 6)
                cell:SetPoint("RIGHT", itemRow, "LEFT", x + width - 3, 0)
            else
                cell:SetWidth(width - 6)
                cell:SetPoint("LEFT", itemRow, "LEFT", x + 3, 0)
            end
        end
    end
end

local function MakeTextCell(row, text, justify)
    local fs = OneWoW_GUI:CreateFS(row, 12)
    fs:SetText(text or "")
    fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    if justify then fs:SetJustifyH(justify) end
    return fs
end

-- Item icon + name (hover tooltip + shift-click link), used by dupe rows.
local function BuildItemCell(itemRow, name, texture, quality, itemLink, rowHeight)
    local itemContainer = CreateFrame("Frame", nil, itemRow)
    itemContainer:SetHeight(rowHeight - 4)

    local iconFrame = OneWoW_GUI:CreateSkinnedIcon(itemContainer, {
        size = rowHeight - 4, preset = "clean", iconTexture = texture, quality = quality,
    })
    iconFrame:SetPoint("LEFT", itemContainer, "LEFT", 2, 0)

    local linkBtn = CreateFrame("Button", nil, itemContainer)
    linkBtn:SetPoint("LEFT", iconFrame, "RIGHT", 4, 0)
    linkBtn:SetPoint("RIGHT", itemContainer, "RIGHT", -4, 0)
    linkBtn:SetHeight(rowHeight - 4)

    local nameText = OneWoW_GUI:CreateFS(linkBtn, 12)
    nameText:SetPoint("LEFT", linkBtn, "LEFT", 0, 0)
    nameText:SetPoint("RIGHT", linkBtn, "RIGHT", 0, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    nameText:SetText(name or "Unknown")

    local function Paint()
        if quality and ITEM_QUALITY_COLORS[quality] then
            local c = ITEM_QUALITY_COLORS[quality]
            nameText:SetTextColor(c.r, c.g, c.b)
        else
            nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
    end
    Paint()

    if itemLink then
        linkBtn:EnableMouse(true)
        linkBtn:SetScript("OnEnter", function(self)
            nameText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(itemLink)
            GameTooltip:Show()
        end)
        linkBtn:SetScript("OnLeave", function()
            Paint()
            GameTooltip:Hide()
        end)
        linkBtn:SetScript("OnClick", function()
            if IsModifiedClick("CHATLINK") then
                ChatEdit_InsertLink(itemLink)
            end
        end)
    end

    return itemContainer
end

local function ResolveDupeRep(inst)
    local name, texture, quality, link = inst.name, inst.texture, inst.quality, inst.itemLink
    local key = inst.itemLink or inst.itemID
    if key then
        local n, l, q, _, _, _, _, _, _, tex = C_Item.GetItemInfo(key)
        name = name or n
        link = link or l
        quality = quality or q
        texture = texture or tex
    end
    return name, texture, quality, link
end

-- Primary stat (the single highest of Int/Str/Agi) as a localized short name.
-- Stamina is a fallback only -- it's on nearly all gear and would otherwise win on
-- raw magnitude, so it shows only when the item has no Int/Str/Agi.
local DUPE_PRIMARY = {
    {field = "statIntellect", short = ITEM_MOD_INTELLECT_SHORT},
    {field = "statStrength",  short = ITEM_MOD_STRENGTH_SHORT},
    {field = "statAgility",   short = ITEM_MOD_AGILITY_SHORT},
}
local function PrimaryDisplay(p)
    local best, bestVal
    for _, s in ipairs(DUPE_PRIMARY) do
        local v = p[s.field] or 0
        if v > 0 and (not bestVal or v > bestVal) then best, bestVal = s.short, v end
    end
    if best then return best end
    if (p.statStamina or 0) > 0 then return ITEM_MOD_STAMINA_SHORT end
    return "-"
end

local DUPE_SECONDARY = {
    {field = "statCrit",        short = ITEM_MOD_CRIT_RATING_SHORT},
    {field = "statHaste",       short = ITEM_MOD_HASTE_RATING_SHORT},
    {field = "statMastery",     short = ITEM_MOD_MASTERY_RATING_SHORT},
    {field = "statVersatility", short = ITEM_MOD_VERSATILITY},
}
local function SecondaryDisplay(p)
    local parts = {}
    for _, s in ipairs(DUPE_SECONDARY) do
        if (p[s.field] or 0) > 0 then parts[#parts + 1] = s.short end
    end
    if #parts == 0 then return "-" end
    return table.concat(parts, "/")
end

-- Location-type -> display label, shared by the default and dupe views (the
-- default view's gather adds the "auction" source the dupe view never groups on).
local LOC_LABEL = {
    bags    = L["BANK_BAGS"],
    bank    = L["BANK_PERSONAL"],
    warband = L["BANK_WARBAND"],
    guild   = GUILD,
    mail    = L["MAIL"],
    auction = L["ITEMS_LOCATION_AH"],
}

-- "Hero 2/6" style track label from PE upgrade props, "-" when the item has no
-- upgrade track. upgradeTrackString is localized by the game.
local function TrackDisplay(p)
    local track = p.upgradeTrackString
    if track and track ~= "" then
        local mx = p.upgradeMax or 0
        if mx > 0 then
            return track .. " " .. (p.upgradeLevel or 0) .. "/" .. mx
        end
        return track
    end
    return "-"
end

-- Expanded copies roll up per location ("location totals"): every copy held in
-- one place becomes a single line with the summed quantity, regardless of
-- ilvl/track differences. Character bags/bank/mail bucket per character; the
-- Warband bank is one shared account-wide bucket (no character name); guild banks
-- bucket per guild (shared across that guild's members, not per alt).
local function LocationSignature(m)
    local w = m.where or {}
    if w.type == "warband" then return "warband" end
    if w.type == "guild" then return "guild|" .. (w.guildName or "?") end
    return (w.charName or w.guildName or "Account") .. "|" .. (w.type or "")
end

-- Display label for a rolled-up location line, matching how the place is owned:
-- Warband is account-wide (no name), guild banks show the guild name (what
-- matters when alts span several guilds), everything else is "Character - Place".
local function LocationLabel(m)
    local w = m.where or {}
    local loc = LOC_LABEL[w.type] or (w.type or "")
    if w.type == "warband" then
        return loc
    elseif w.type == "guild" then
        return (w.guildName or "?") .. " - " .. loc
    end
    return (w.charName or "Account") .. " - " .. loc
end

-- Order rolled-up location lines: character-owned places first (grouped by
-- character), then the shared Warband bank, then guild banks.
local LOC_OWNER_RANK = { warband = 2, guild = 3 }

-- Distinct rolled-up locations in a group == the number of lines the expanded
-- section shows (one per LocationSignature bucket). Drives the "Locs" column so
-- the count always matches what the user sees when they expand the row.
local function CountLocations(group)
    local seen, n = {}, 0
    for _, m in ipairs(group.members) do
        local sig = LocationSignature(m)
        if not seen[sig] then
            seen[sig] = true
            n = n + 1
        end
    end
    return n
end

-- One expand line per rolled-up location: label + summed qty, then the
-- representative copy's detail (ilvl -> fully-upgraded ceiling, track, primary,
-- secondary, socket) so it's clear what the best copy there looks like.
local function ComposeCopyLine(m, qty)
    local storageAPI = OneWoW_AltTracker_Storage_API
    if not storageAPI then return LocationLabel(m) .. "  x" .. qty end
    local p = PE:BuildProps(m.itemID, nil, nil, m.itemLink)

    local ilvl = storageAPI.GetEffectiveILvl(m)
    local ceiling = p.maxLevel or ilvl
    local ilvlStr = tostring(ilvl)
    if ceiling and ceiling > ilvl then ilvlStr = ilvl .. "->" .. ceiling end

    -- Name leads the detail: in Similar mode a group spans different items that
    -- only share a slot, so the row title isn't the copy's actual item.
    local nm = m.name or C_Item.GetItemInfo(m.itemLink or m.itemID)
    local detail = {}
    if nm then detail[#detail + 1] = nm end
    detail[#detail + 1] = "#" .. m.itemID
    detail[#detail + 1] = ilvlStr
    local track = TrackDisplay(p)
    if track ~= "-" then detail[#detail + 1] = track end
    local prim = PrimaryDisplay(p)
    if prim ~= "-" then detail[#detail + 1] = prim end
    local sec = SecondaryDisplay(p)
    if sec ~= "-" then detail[#detail + 1] = sec end
    if p.hasSocket then detail[#detail + 1] = L["DUPE_OPT_SOCKET"] end

    return LocationLabel(m) .. "  x" .. qty .. "   " .. table.concat(detail, ", ")
end

-- Collapse a group's members into one line per character + location, with the
-- quantity summed across every copy there. The representative copy (highest
-- effective ilvl at that location) supplies the differentiating detail, so a
-- location holding mixed-ilvl copies still surfaces the best one. The anchor item
-- (the one the group is titled by) sorts first, then by name -> itemID -> highest
-- ilvl, so related locations sit together -- useful in Similar mode where a group
-- mixes different items sharing a slot.
local function BuildCopyLines(group, anchorName)
    local api = OneWoW_AltTracker_Storage_API
    local order, bySig = {}, {}
    for _, m in ipairs(group.members) do
        local sig = LocationSignature(m)
        local agg = bySig[sig]
        if not agg then
            agg = { m = m, qty = 0, name = m.name or C_Item.GetItemInfo(m.itemLink or m.itemID) or "" }
            bySig[sig] = agg
            order[#order + 1] = agg
        end
        agg.qty = agg.qty + (m.count or 1)
        -- Keep the highest-ilvl copy at this location as the line's representative.
        if api.GetEffectiveILvl(m) > api.GetEffectiveILvl(agg.m) then
            agg.m = m
            agg.name = m.name or agg.name
        end
    end
    table.sort(order, function(a, b)
        local aAnchor = anchorName ~= nil and a.name == anchorName
        local bAnchor = anchorName ~= nil and b.name == anchorName
        if aAnchor ~= bAnchor then return aAnchor end
        local aw, bw = a.m.where or {}, b.m.where or {}
        local ar = LOC_OWNER_RANK[aw.type] or 1
        local br = LOC_OWNER_RANK[bw.type] or 1
        if ar ~= br then return ar < br end
        local an = aw.charName or aw.guildName or ""
        local bn = bw.charName or bw.guildName or ""
        if an ~= bn then return an < bn end
        if (aw.type or "") ~= (bw.type or "") then return (aw.type or "") < (bw.type or "") end
        if a.name ~= b.name then return a.name < b.name end
        return a.m.itemID < b.m.itemID
    end)
    local lines = {}
    for _, agg in ipairs(order) do
        lines[#lines + 1] = { text = ComposeCopyLine(agg.m, agg.qty), link = agg.m.itemLink }
    end
    return lines
end

-- Dupe render: group duplicates via the Storage Query API and lay them out with
-- the adaptive dupe columns. SetDupeMode swaps the table columns before this
-- runs, so the data table headers already match dupeColumnsConfig here.
function ns.UI.RefreshDupeView(itemsTab)
    if not itemsTab then return end
    local storageAPI = OneWoW_AltTracker_Storage_API
    local scrollContent = itemsTab.scrollContent
    if not scrollContent then return end
    local dt = itemsTab.dataTable

    OneWoW_GUI:ClearDataRows(scrollContent)
    wipe(itemRows)
    if dt then dt:ClearRows() end

    if not (storageAPI and storageAPI.FindDuplicates) then
        if itemsTab.statusText then itemsTab.statusText:SetText(L["DUPE_NONE"]) end
        return
    end

    EnsureDupeSpec()

    local groups = storageAPI.FindDuplicates({
        chars = "all",
        containers = { bags = true, personal = true, warband = true, guild = true, mail = true },
        predicate = (filterText ~= "" and filterText) or nil,
        dupe = dupeSpec,
    }) or {}

    table.sort(groups, function(a, b)
        if a.slotCount ~= b.slotCount then return a.slotCount > b.slotCount end
        return (a.key or "") < (b.key or "")
    end)

    if #groups == 0 then
        if itemsTab.statusText then itemsTab.statusText:SetText(L["DUPE_NONE"]) end
        return
    end

    local rowHeight = 30
    local rowGap = 2

    for _, group in ipairs(groups) do
        -- Representative = highest effective-ilvl copy (the "best" one to keep).
        local rep = group.members[1]
        local repIlvl = storageAPI.GetEffectiveILvl(rep)
        local maxLastSeen = rep.lastSeen or 0
        for _, m in ipairs(group.members) do
            local lvl = storageAPI.GetEffectiveILvl(m)
            if lvl > repIlvl then rep, repIlvl = m, lvl end
            if (m.lastSeen or 0) > maxLastSeen then maxLastSeen = m.lastSeen end
        end

        local name, texture, quality, link = ResolveDupeRep(rep)
        local props = PE:BuildProps(rep.itemID, nil, nil, rep.itemLink)

        local itemRow = OneWoW_GUI:CreateDataRow(scrollContent, {
            rowHeight = rowHeight,
            expandedHeight = 60,
            rowGap = rowGap,
            data = { group = group, name = name },
            createDetails = function(ef, d)
                local grid = OneWoW_GUI:CreateExpandedPanelGrid(ef)
                local panel = grid:AddPanel(d.name or "")
                for _, entry in ipairs(BuildCopyLines(d.group, d.name)) do
                    local fs = grid:AddLine(panel, entry.text)
                    -- Invisible hover region over the line so the copy's item
                    -- tooltip shows on mouseover (and shift-click links it).
                    if fs and entry.link then
                        local hover = CreateFrame("Button", nil, panel)
                        hover:SetAllPoints(fs)
                        hover:EnableMouse(true)
                        hover:SetScript("OnEnter", function(self)
                            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                            GameTooltip:SetHyperlink(entry.link)
                            GameTooltip:Show()
                        end)
                        hover:SetScript("OnLeave", function() GameTooltip:Hide() end)
                        hover:SetScript("OnClick", function()
                            if IsModifiedClick("CHATLINK") then ChatEdit_InsertLink(entry.link) end
                        end)
                    end
                end
                grid:Finish()
                OneWoW_GUI:ApplyFontToFrame(ef)
            end,
        })

        local itemContainer = BuildItemCell(itemRow, name, texture, quality, link, rowHeight)
        table.insert(itemRow.cells, itemContainer)

        table.insert(itemRow.cells, MakeTextCell(itemRow, tostring(rep.itemID)))

        local ilvlStr
        local spread = group.ilvlSpread
        if spread and #spread > 1 then
            ilvlStr = spread[1] .. "-" .. spread[#spread]
        elseif repIlvl and repIlvl > 0 then
            ilvlStr = tostring(repIlvl)
        else
            ilvlStr = "-"
        end
        table.insert(itemRow.cells, MakeTextCell(itemRow, ilvlStr))
        table.insert(itemRow.cells, MakeTextCell(itemRow, tostring(CountLocations(group))))
        table.insert(itemRow.cells, MakeTextCell(itemRow, tostring(group.totalCount or group.slotCount)))
        table.insert(itemRow.cells, MakeTextCell(itemRow, PrimaryDisplay(props)))
        table.insert(itemRow.cells, MakeTextCell(itemRow, SecondaryDisplay(props), "LEFT"))
        table.insert(itemRow.cells, MakeTextCell(itemRow, props.hasSocket and YES or NO))
        table.insert(itemRow.cells, MakeTextCell(itemRow, TrackDisplay(props)))
        table.insert(itemRow.cells, MakeTextCell(itemRow, FormatLastSeen(maxLastSeen)))

        PositionRowCells(itemRow, dt, dupeColumnsConfig, rowHeight)

        table.insert(itemRows, itemRow)
        if dt then dt:RegisterRow(itemRow) end
    end

    OneWoW_GUI:LayoutDataRows(scrollContent, { rowHeight = rowHeight, rowGap = rowGap })
    OneWoW_GUI:ApplyFontToFrame(itemsTab)

    if itemsTab.statusText then
        itemsTab.statusText:SetText(string.format(L["DUPE_STATUS"], #groups))
    end
end

function ns.UI.RefreshItemsTab(itemsTab)
    if not itemsTab then return end
    if dupeMode then
        return ns.UI.RefreshDupeView(itemsTab)
    end
    local storageAPI = OneWoW_AltTracker_Storage_API
    if not storageAPI then return end

    do
        local ip = OneWoW.ItemPrices
        local auctionatorActive = ip:IsAuctionatorAHSourceActive()
        local tsmActive = ip:IsTSMAHSourceActive()
        if itemsTab.noticeText then
            local notice = L["ITEMS_NOTICE"]
            if auctionatorActive then
                notice = L["ITEMS_NOTICE_AUCTIONATOR"]
            elseif tsmActive then
                notice = L["ITEMS_NOTICE_TSM"]
            end
            itemsTab.noticeText:SetText(notice)
        end
    end

    local scrollContent = itemsTab.scrollContent
    if not scrollContent then return end

    local dt = itemsTab.dataTable

    OneWoW_GUI:ClearDataRows(scrollContent)
    wipe(itemRows)
    if dt then dt:ClearRows() end

    -- Gather every occupied slot across all characters + account/guild + auctions
    -- through the shared Storage Query layer (one normalized instance per slot),
    -- then aggregate by itemID into the row records the render path below expects.
    -- The dupe view-mode and Bank tab gather through the same layer; only the
    -- by-itemID rollup is unique to this view.
    local items = {}

    local instances = storageAPI.Gather({
        chars = "all",
        containers = { bags = true, personal = true, warband = true, guild = true, mail = true, auction = true },
    })

    for _, inst in ipairs(instances) do
        local itemID = inst.itemID
        local rec = items[itemID]
        if not rec then
            -- Live link lookup for the per-variant sell price / name / icon;
            -- falls back to the instance's stored fields.
            local iName, iTex, iLink, iVend = ResolveItemData({
                itemID   = itemID,
                itemLink = inst.itemLink,
                texture  = inst.texture,
                sellPrice = inst.vendorPrice,
                itemName = inst.name,
            })
            rec = {
                itemID = itemID,
                itemName = iName or inst.name or "Unknown",
                texture = iTex or inst.texture,
                quality = inst.quality,
                itemLink = iLink or inst.itemLink,
                vendorPrice = iVend,
                totalQty = 0,
                isBound = false,
                isWarbound = false,
                locations = {},
                lastSeenTime = 0,
            }
            items[itemID] = rec
        end
        local qty = inst.count or 1
        rec.totalQty = rec.totalQty + qty
        if (inst.lastSeen or 0) > rec.lastSeenTime then rec.lastSeenTime = inst.lastSeen end
        if inst.isBound then rec.isBound = true end
        if inst.isWarbound then rec.isWarbound = true end
        local w = inst.where or {}
        local who = w.charName or w.guildName or "Account"
        AddToLocation(rec, who, LOC_LABEL[w.type] or (w.type or ""), qty)
    end

    local filteredItems = {}
    local totalUniqueItems = 0
    local totalQuantity = 0
    local totalVendorValue = 0
    local totalAHValue = 0
    local totalBoundItems = 0

    for itemID, itemData in pairs(items) do
        totalUniqueItems = totalUniqueItems + 1
        totalQuantity = totalQuantity + itemData.totalQty
        if itemData.vendorPrice and itemData.vendorPrice > 0 then
            totalVendorValue = totalVendorValue + (itemData.vendorPrice * itemData.totalQty)
        end
        -- "Bound" here is the broad sense the filter uses: soulbound OR warbound
        -- (account-bound). The container API's isBound is soulbound-only, so
        -- warbound is tracked separately and folded in for both the count and filter.
        local isBoundish = itemData.isBound or itemData.isWarbound
        if isBoundish then totalBoundItems = totalBoundItems + 1 end

        local shouldInclude = true

        if isBoundish and hidebound then
            shouldInclude = false
        end

        if shouldInclude then
            local hasVendorPrice = itemData.vendorPrice and itemData.vendorPrice > 0
            if hideNoVendor and not hasVendorPrice then
                shouldInclude = false
            end
        end

        if shouldInclude and filterText and filterText ~= "" then
            if not MatchesSearch(itemData, filterText) then
                shouldInclude = false
            end
        end

        if shouldInclude then
            local p, meta = OneWoW.ItemPrices:GetUnitAHPrice(itemID, itemData.itemLink)
            if p and p > 0 then
                itemData.ahPrice = p
                itemData.ahTime = (meta and meta.timestamp) or 0
            else
                itemData.ahPrice = 0
                itemData.ahTime = 0
            end
            if itemData.ahPrice and itemData.ahPrice > 0 then
                totalAHValue = totalAHValue + (itemData.ahPrice * itemData.totalQty)
            end
            table.insert(filteredItems, itemData)
        end
    end

    if itemsTab.statBoxes then
        if itemsTab.statBoxes[1] then
            itemsTab.statBoxes[1].value:SetText(tostring(totalUniqueItems))
        end
        if itemsTab.statBoxes[2] then
            itemsTab.statBoxes[2].value:SetText(tostring(totalQuantity))
        end
        if itemsTab.statBoxes[3] then
            itemsTab.statBoxes[3].value:SetText(ns.AltTrackerFormatters:FormatGold(totalVendorValue))
        end
        if itemsTab.statBoxes[4] then
            itemsTab.statBoxes[4].value:SetText(ns.AltTrackerFormatters:FormatGold(totalAHValue))
        end
        if itemsTab.statBoxes[5] then
            itemsTab.statBoxes[5].value:SetText(tostring(totalBoundItems))
        end
    end

    local function sortWithFavoritesFirst(inner)
        table.sort(filteredItems, function(a, b)
            local fa, fb = ns.IsFavoriteItem(a.itemID), ns.IsFavoriteItem(b.itemID)
            if fa ~= fb then return fa end
            return inner(a, b)
        end)
    end

    if currentSortColumn == "item" then
        sortWithFavoritesFirst(function(a, b)
            if currentSortAscending then return (a.itemName or "") < (b.itemName or "")
            else return (a.itemName or "") > (b.itemName or "") end
        end)
    elseif currentSortColumn == "total" then
        sortWithFavoritesFirst(function(a, b)
            if currentSortAscending then return (a.totalQty or 0) < (b.totalQty or 0)
            else return (a.totalQty or 0) > (b.totalQty or 0) end
        end)
    elseif currentSortColumn == "vendor" then
        sortWithFavoritesFirst(function(a, b)
            if currentSortAscending then return (a.vendorPrice or 0) < (b.vendorPrice or 0)
            else return (a.vendorPrice or 0) > (b.vendorPrice or 0) end
        end)
    elseif currentSortColumn == "ah" then
        sortWithFavoritesFirst(function(a, b)
            if currentSortAscending then return (a.ahPrice or 0) < (b.ahPrice or 0)
            else return (a.ahPrice or 0) > (b.ahPrice or 0) end
        end)
    elseif currentSortColumn == "lastseen" then
        sortWithFavoritesFirst(function(a, b)
            if currentSortAscending then return (a.lastSeenTime or 0) < (b.lastSeenTime or 0)
            else return (a.lastSeenTime or 0) > (b.lastSeenTime or 0) end
        end)
    else
        sortWithFavoritesFirst(function(a, b)
            return (a.itemName or "") < (b.itemName or "")
        end)
    end

    local isUnfiltered = (not filterText or filterText == "") and not hidebound and not hideNoVendor
    if isUnfiltered and #filteredItems > 100 then
        for i = #filteredItems, 101, -1 do
            table.remove(filteredItems, i)
        end
    end

    if #filteredItems == 0 then
        if itemsTab.statusText then
            itemsTab.statusText:SetText(L["ITEMS_NO_ITEMS"])
        end
        return
    end

    local rowHeight = 30
    local rowGap = 2

    for _, itemData in ipairs(filteredItems) do
        local itemRow = OneWoW_GUI:CreateDataRow(scrollContent, {
            rowHeight = rowHeight,
            expandedHeight = 60,
            rowGap = rowGap,
            data = { itemData = itemData },
            createDetails = function(ef, d)
                local grid = OneWoW_GUI:CreateExpandedPanelGrid(ef)
                local p1 = grid:AddPanel(d.itemData.itemName or "")
                for _, locData in ipairs(d.itemData.locations) do
                    grid:AddLine(p1, locData.charName .. " - " .. locData.location .. " x" .. locData.qty)
                end
                grid:Finish()
                OneWoW_GUI:ApplyFontToFrame(ef)
            end,
        })

        local capturedItemID = itemData.itemID
        local favBtn = OneWoW_GUI:CreateFavoriteToggleButton(itemRow, {
            size = 18,
            favorite = ns.IsFavoriteItem(capturedItemID),
            tooltipTitle = L["TT_ITEMS_COL_FAVORITE"],
            tooltipText = L["TT_ITEMS_COL_FAVORITE_DESC"],
            onClick = function(_, isFav)
                ns.SetFavoriteItem(capturedItemID, isFav)
                ns.UI.RefreshItemsTab(itemsTab)
            end,
        })
        table.insert(itemRow.cells, 2, favBtn)

        local itemContainer = CreateFrame("Frame", nil, itemRow)
        itemContainer:SetHeight(rowHeight - 4)

        local iconFrame = OneWoW_GUI:CreateSkinnedIcon(itemContainer, {
            size = rowHeight - 4,
            preset = "clean",
            iconTexture = itemData.texture,
            quality = itemData.quality,
        })
        iconFrame:SetPoint("LEFT", itemContainer, "LEFT", 2, 0)

        local itemLinkFrame = CreateFrame("Button", nil, itemContainer)
        itemLinkFrame:SetPoint("LEFT", iconFrame, "RIGHT", 4, 0)
        itemLinkFrame:SetPoint("RIGHT", itemContainer, "RIGHT", -4, 0)
        itemLinkFrame:SetHeight(rowHeight - 4)

        local itemNameText = OneWoW_GUI:CreateFS(itemLinkFrame, 12)
        itemNameText:SetPoint("LEFT", itemLinkFrame, "LEFT", 0, 0)
        itemNameText:SetPoint("RIGHT", itemLinkFrame, "RIGHT", 0, 0)
        itemNameText:SetJustifyH("LEFT")
        itemNameText:SetWordWrap(false)
        itemNameText:SetText(itemData.itemName or "Unknown")
        if itemData.quality and ITEM_QUALITY_COLORS[itemData.quality] then
            local color = ITEM_QUALITY_COLORS[itemData.quality]
            itemNameText:SetTextColor(color.r, color.g, color.b)
        else
            itemNameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end

        if itemData.itemLink then
            itemLinkFrame:EnableMouse(true)
            itemLinkFrame:SetScript("OnEnter", function(self)
                itemNameText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(itemData.itemLink)
                GameTooltip:Show()
            end)
            itemLinkFrame:SetScript("OnLeave", function()
                if itemData.quality and ITEM_QUALITY_COLORS[itemData.quality] then
                    local color = ITEM_QUALITY_COLORS[itemData.quality]
                    itemNameText:SetTextColor(color.r, color.g, color.b)
                else
                    itemNameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                end
                GameTooltip:Hide()
            end)
            itemLinkFrame:SetScript("OnClick", function()
                if IsModifiedClick("CHATLINK") then
                    ChatEdit_InsertLink(itemData.itemLink)
                end
            end)
        end

        table.insert(itemRow.cells, itemContainer)

        local totalText = OneWoW_GUI:CreateFS(itemRow, 12)
        totalText:SetText(tostring(itemData.totalQty))
        totalText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        table.insert(itemRow.cells, totalText)

        local vendorText = OneWoW_GUI:CreateFS(itemRow, 12)
        if itemData.vendorPrice and itemData.vendorPrice > 0 then
            vendorText:SetText(ns.AltTrackerFormatters:FormatGold(itemData.vendorPrice))
            vendorText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        else
            vendorText:SetText(L["ITEMS_NO_VALUE"])
            vendorText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        end
        table.insert(itemRow.cells, vendorText)

        local ahText = OneWoW_GUI:CreateFS(itemRow, 12)
        if itemData.ahPrice and itemData.ahPrice > 0 then
            ahText:SetText(ns.AltTrackerFormatters:FormatGold(itemData.ahPrice))
            ahText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        else
            ahText:SetText(L["ITEMS_NO_VALUE"])
            ahText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        end
        table.insert(itemRow.cells, ahText)

        local lastSeenText = OneWoW_GUI:CreateFS(itemRow, 12)
        lastSeenText:SetText(FormatLastSeen(itemData.lastSeenTime))
        lastSeenText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        table.insert(itemRow.cells, lastSeenText)

        if dt and dt.headerRow and dt.headerRow.columnButtons and columnsConfig then
            for i, cell in ipairs(itemRow.cells) do
                local btn = dt.headerRow.columnButtons[i]
                if btn and btn.columnWidth and btn.columnX then
                    local width = btn.columnWidth
                    local x = btn.columnX
                    local col = columnsConfig[i]
                    cell:ClearAllPoints()
                    if col and col.align == "icon" then
                        cell:SetSize(width, rowHeight)
                        cell:SetPoint("LEFT", itemRow, "LEFT", x, 0)
                    elseif col and col.align == "center" then
                        cell:SetWidth(width - 6)
                        cell:SetPoint("CENTER", itemRow, "LEFT", x + width / 2, 0)
                    elseif col and col.align == "right" then
                        cell:SetWidth(width - 6)
                        cell:SetPoint("RIGHT", itemRow, "LEFT", x + width - 3, 0)
                    else
                        cell:SetWidth(width - 6)
                        cell:SetPoint("LEFT", itemRow, "LEFT", x + 3, 0)
                    end
                end
            end
        end

        table.insert(itemRows, itemRow)
        if dt then dt:RegisterRow(itemRow) end
    end

    OneWoW_GUI:LayoutDataRows(scrollContent, { rowHeight = rowHeight, rowGap = rowGap })

    OneWoW_GUI:ApplyFontToFrame(itemsTab)

    if itemsTab.statusText then
        local filterState = ""
        if hidebound or hideNoVendor then
            if hidebound and hideNoVendor then
                filterState = " (Bound & No Vendor hidden)"
            elseif hidebound then
                filterState = " (Bound hidden)"
            else
                filterState = " (No Vendor hidden)"
            end
        end
        if filterText and filterText ~= "" then
            filterState = filterState .. " - Search: '" .. filterText .. "'"
        end
        local totalCount = 0
        for _ in pairs(items) do
            totalCount = totalCount + 1
        end
        if totalCount > #filteredItems then
            itemsTab.statusText:SetText(string.format(L["D_OF_D_ITEMS"], #filteredItems, totalCount) .. filterState)
        else
            itemsTab.statusText:SetText(string.format(L["ITEMS_STATUS"], #filteredItems) .. filterState)
        end
    end
end
