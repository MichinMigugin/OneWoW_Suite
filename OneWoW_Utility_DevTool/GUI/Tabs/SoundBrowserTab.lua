local ADDON_NAME, Addon = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local L = Addon.L or {}

local format = format
local floor = math.floor
local max = math.max
local tinsert = tinsert
local tonumber = tonumber
local tostring = tostring
local strtrim = strtrim
local pcall = pcall

local SB
local applyListSelection
local refreshListSelection

local BOOKMARK_ICON_PATH = format("Interface\\AddOns\\%s\\Media\\icon-fav.png", ADDON_NAME)

local MANUAL_FDID = "fdid"
local MANUAL_KIT = "kit"
local MANUAL_KEY = "key"
local SEARCH_SCOPE_CURRENT = "current"
local SEARCH_SCOPE_ALL = "all"

local SOUND_CHANNELS = {
    "Master",
    "SFX",
    "Music",
    "Ambience",
    "Dialog",
    "Talking Head",
}

local function getDU()
    return Addon.Constants and Addon.Constants.DEVTOOL_UI or {}
end

local function getSavedSoundChannel()
    local value = Addon.db.global.soundBrowserChannel
    for _, channel in ipairs(SOUND_CHANNELS) do
        if value == channel then
            return channel
        end
    end
    return "SFX"
end

local function scheduleFilterRefresh(tab)
    if tab._filterTicker then
        tab._filterTicker:Cancel()
        tab._filterTicker = nil
    end
    local delay = 0.12
    if SB and SB:IsSearchingAll() then
        delay = 0.2
    end
    tab._filterTicker = C_Timer.NewTimer(delay, function()
        tab._filterTicker = nil
        if not tab.searchBox then return end
        SB:SetFilterText(tab.searchBox:GetSearchText())
        refreshListSelection(tab, true)
    end)
end

local function ensureListRowBookmarkIcon(btn, rowH)
    if btn._soundBmTex then return end
    local DU = getDU()
    local sz = DU.TEXTURE_BROWSER_BOOKMARK_ICON_SIZE or 14
    local pad = DU.TEXTURE_BROWSER_BOOKMARK_ICON_RIGHT_PAD or 8
    rowH = rowH or 22
    local topInset = -floor((rowH - sz) / 2 + 0.5)
    local tex = btn:CreateTexture(nil, "OVERLAY")
    tex:SetSize(sz, sz)
    tex:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -pad, topInset)
    tex:SetTexCoord(0, 1, 0, 1)
    btn._soundBmTex = tex
    btn.bookmarkIcon = tex
end

local function styleListButtonText(btn)
    local fs = btn:GetFontString()
    if not fs then return end
    local DU = getDU()
    local gap = DU.TEXTURE_BROWSER_BOOKMARK_ICON_TEXT_GAP or 4
    local rightPad = DU.TEXTURE_BROWSER_BOOKMARK_ICON_RIGHT_PAD or 8
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("MIDDLE")
    if fs.SetWordWrap then fs:SetWordWrap(false) end
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", btn, "LEFT", 4, 0)
    if btn._soundBmTex and btn._soundBmTex:IsShown() then
        fs:SetPoint("RIGHT", btn._soundBmTex, "LEFT", -gap, 0)
    else
        fs:SetPoint("RIGHT", btn, "RIGHT", -rightPad, 0)
    end
end

function Addon.UI.SoundTab_RefreshList(tab)
    if tab and tab.virtualizedList then
        tab.virtualizedList.Refresh()
    end
end

local SOUND_BAR_ACTIVE_KEY = "_barActive"

local function refreshSoundToolbar(tab)
    if tab.favsBtn then
        tab.favsBtn._barActive = SB.favoritesOnly
        Addon.UI:PaintToolbarBarButton(tab.favsBtn, SOUND_BAR_ACTIVE_KEY)
    end
    if tab.bookmarkBtn and tab.selectedEntry then
        local bm = SB:IsBookmarked(tab.selectedEntry)
        tab.bookmarkBtn._barActive = bm and true or false
        if tab.bookmarkBtn.SetFitText then
            tab.bookmarkBtn:SetFitText(bm and (L["BTN_REMOVE_BOOKMARK"]) or (L["BTN_BOOKMARK"]))
        end
        Addon.UI:PaintToolbarBarButton(tab.bookmarkBtn, SOUND_BAR_ACTIVE_KEY)
    elseif tab.bookmarkBtn then
        tab.bookmarkBtn._barActive = false
        if tab.bookmarkBtn.SetFitText then
            tab.bookmarkBtn:SetFitText(L["BTN_BOOKMARK"])
        end
        Addon.UI:PaintToolbarBarButton(tab.bookmarkBtn, SOUND_BAR_ACTIVE_KEY)
    end
    if tab.manualToggle then
        tab.manualToggle._barActive = tab.manualPanel and tab.manualPanel:IsShown() or false
        Addon.UI:PaintToolbarBarButton(tab.manualToggle, SOUND_BAR_ACTIVE_KEY)
    end
end

local function setCopyBtnEnabled(btn, enabled)
    if not btn then return end
    btn:EnableMouse(enabled)
    if enabled then
        btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
        if btn.text then btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY")) end
    else
        btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        if btn.text then btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED")) end
    end
end

function Addon.UI.SoundTab_StopPlayback(tab)
    if not tab then return end
    local h = tab.activeSoundHandle
    if h then
        pcall(StopSound, h)
        tab.activeSoundHandle = nil
    end
end

function Addon.UI.SoundTab_GlobalStopPlayback()
    local t = Addon.SoundBrowserTab
    if t and t.StopPlayback then
        t:StopPlayback()
    end
end

function Addon.UI.SoundTab_RefreshSoundCvarCheckboxes()
    local t = Addon.SoundBrowserTab
    if not t or not t.soundCvarMusicCb or not t.soundCvarAmbienceCb then return end
    local cm = Addon.Constants.SOUND_CVAR_ENABLE_MUSIC
    local ca = Addon.Constants.SOUND_CVAR_ENABLE_AMBIENCE
    t._syncingSoundCvars = true
    t.soundCvarMusicCb:SetChecked(C_CVar.GetCVar(cm) == "1")
    t.soundCvarAmbienceCb:SetChecked(C_CVar.GetCVar(ca) == "1")
    t._syncingSoundCvars = false
end

local function getSoundChannel(tab)
    return tab.soundChannelValue or "SFX"
end

local function SoundTab_updateLastPlayLine(tab, ok, ref)
    tab.lastPlayOk = ok and true or false
    tab.lastPlayRef = ref
end

local function startPlaySoundFile(tab, fileDataId)
    if type(fileDataId) ~= "number" then return false end
    Addon.UI.SoundTab_StopPlayback(tab)
    tab.manualLastSoundKitId = nil
    local ch = getSoundChannel(tab)
    local willPlay, handle = PlaySoundFile(fileDataId, ch)
    if type(handle) == "number" then
        tab.activeSoundHandle = handle
    end
    return willPlay and true or false, handle
end

local function startPlaySoundKit(tab, kitId)
    if type(kitId) ~= "number" then return false end
    Addon.UI.SoundTab_StopPlayback(tab)
    tab.manualLastSoundKitId = kitId
    local ch = getSoundChannel(tab)
    local willPlay, handle = PlaySound(kitId, ch)
    if type(handle) == "number" then
        tab.activeSoundHandle = handle
    end
    return willPlay and true or false, handle
end

function Addon.UI.SoundTab_PlayListSelection(tab)
    if not tab.selectedEntry then return end
    local id = SB:GetFileDataIdNumber(tab.selectedEntry)
    if not id then return end
    local ok, handle = startPlaySoundFile(tab, id)
    SoundTab_updateLastPlayLine(tab, ok, id)
    Addon.UI.SoundTab_UpdateDetails(tab)
end

function Addon.UI.SoundTab_UpdateDetails(tab)
    if not tab.infoText then return end
    local lines = {}
    local e = tab.selectedEntry
    if not e then
        if SB:IsRebuilding() then
            tab.infoText:SetText(L["SOUND_MSG_SEARCHING"])
        elseif SB:IsSearchingAll() and SB:NeedsSearchTerm() then
            tab.infoText:SetText(format(L["SOUND_MSG_SEARCH_ALL_MIN"], SB:GetAllSearchMinLength()))
        else
            tab.infoText:SetText(L["SOUND_MSG_SELECT"])
        end
        local h = tab.infoText:GetStringHeight()
        tab.infoScroll:GetScrollChild():SetHeight(max(h + 16, tab.infoScroll:GetHeight()))
        return
    end
    local top, sub, fileName, fdidStr = SB:GetEntryInfo(e)
    tinsert(lines, "|cffffd100" .. (L["SOUND_SECTION_FILE"]) .. "|r")
    tinsert(lines, (L["LABEL_NAME"]) .. " " .. tostring(fileName))
    tinsert(lines, "FDID: " .. tostring(fdidStr))
    tinsert(lines, (L["SOUND_LABEL_CATEGORY"]) .. " " .. tostring(top) .. " / " .. tostring(sub))
    tinsert(lines, (L["SOUND_LABEL_PATH"]) .. " " .. SB:GetFullPath(e))
    tinsert(lines, "")
    tinsert(lines, (L["SOUND_LABEL_CHANNEL"]) .. " " .. getSoundChannel(tab))
    if tab.lastPlayRef ~= nil then
        tinsert(lines, "")
        if tab.lastPlayOk then
            tinsert(lines, (L["SOUND_MSG_PLAY_OK"]) .. " (" .. tostring(tab.lastPlayRef) .. ")")
        else
            tinsert(lines, (L["SOUND_MSG_PLAY_FAIL"]) .. " (" .. tostring(tab.lastPlayRef) .. ")")
        end
    end
    if SB:IsBookmarked(e) then
        tinsert(lines, "")
        tinsert(lines, "|cff00ff00" .. (L["LABEL_BOOKMARKED"]) .. "|r")
    end
    tab.infoText:SetText(table.concat(lines, "\n"))
    local h = tab.infoText:GetStringHeight()
    tab.infoScroll:GetScrollChild():SetHeight(max(h + 16, tab.infoScroll:GetHeight()))
end

function Addon.UI.SoundTab_UpdateCopyRow(tab)
    local e = tab.selectedEntry
    setCopyBtnEnabled(tab.copyFdidBtn, e ~= nil)
    setCopyBtnEnabled(tab.copyPathBtn, e ~= nil)
    setCopyBtnEnabled(tab.copySnippetBtn, e ~= nil)
    local kit = tab.manualLastSoundKitId
    local showKit = type(kit) == "number"
    setCopyBtnEnabled(tab.copyKitBtn, showKit)
    setCopyBtnEnabled(tab.copyPlaySoundSnippetBtn, showKit)
end

applyListSelection = function(tab, idx)
    local e = SB:GetFilteredEntry(idx)
    tab.selectedListIndex = idx
    tab.selectedEntry = e
    if e and tab.nameText then
        tab.nameText:SetText(SB:GetFileName(e))
    elseif tab.nameText then
        tab.nameText:SetText("")
    end
    Addon.UI.SoundTab_UpdateDetails(tab)
    Addon.UI.SoundTab_UpdateCopyRow(tab)
    refreshSoundToolbar(tab)
end

refreshListSelection = function(tab, preferFirst)
    if not tab or not tab.virtualizedList then
        return
    end
    Addon.UI.SoundTab_RefreshList(tab)
    local count = SB:GetFilteredCount()
    if count <= 0 then
        tab.virtualizedList.SetSelectedIndex(nil)
        applyListSelection(tab, nil)
        return
    end

    local targetIndex = nil
    local currentKey = tab.selectedEntry and SB:GetBookmarkKey(tab.selectedEntry)
    if currentKey then
        for i = 1, count do
            local entry = SB:GetFilteredEntry(i)
            if entry and SB:GetBookmarkKey(entry) == currentKey then
                targetIndex = i
                break
            end
        end
    end

    if not targetIndex then
        local currentIndex = tab.selectedListIndex
        if type(currentIndex) == "number" and currentIndex >= 1 and currentIndex <= count then
            targetIndex = currentIndex
        elseif preferFirst then
            targetIndex = 1
        end
    end

    if targetIndex then
        tab.virtualizedList.SetSelectedIndex(targetIndex)
    else
        tab.virtualizedList.SetSelectedIndex(nil)
        applyListSelection(tab, nil)
    end
end

local function hookListDoubleClickAndEnter(tab, leftPanel)
    local content = tab.virtualizedList and tab.virtualizedList.listContent
    if not content or content._soundListHooked then return end
    content._soundListHooked = true
    local n = select("#", content:GetChildren())
    for i = 1, n do
        local btn = select(i, content:GetChildren())
        if btn and btn:GetObjectType() == "Button" then
            btn:HookScript("OnDoubleClick", function(b)
                if b.entryIndex and tab.virtualizedList then
                    tab.virtualizedList.SetSelectedIndex(b.entryIndex)
                    Addon.UI.SoundTab_PlayListSelection(tab)
                end
            end)
        end
    end
    leftPanel:HookScript("OnKeyDown", function(self, key)
        if key ~= "ENTER" and key ~= "NUMPADENTER" then
            return
        end
        self:SetPropagateKeyboardInput(false)
        if tab.virtualizedList and tab.selectedEntry then
            Addon.UI.SoundTab_PlayListSelection(tab)
        end
    end)
end

local function refreshTopDropdownLabel(tab)
    local dd = tab.topDropdown
    if not dd or not dd._text then return end
    local t = SB.selectedTop or (L["SOUND_DD_PICK_CATEGORY"])
    dd._text:SetText(t)
end

local function refreshSubDropdownLabel(tab)
    local dd = tab.subDropdown
    if not dd or not dd._text then return end
    local t = SB.selectedSub or (L["SOUND_DD_PICK_SUB"])
    dd._text:SetText(t)
end

local function refreshChannelDropdownLabel(tab)
    local dd = tab.channelDropdown
    if not dd or not dd._text then return end
    dd._text:SetText(getSoundChannel(tab))
end

local function refreshSearchScopeDropdownLabel(tab)
    local dd = tab.searchScopeDropdown
    if not dd or not dd._text then return end
    if SB:IsSearchingAll() then
        dd._text:SetText(L["SOUND_SEARCH_SCOPE_ALL"])
    else
        dd._text:SetText(L["SOUND_SEARCH_SCOPE_CURRENT"])
    end
end

local function soundTabApplyInfoPanelBounds(tab)
    if not tab.infoPanel or not tab.controlsAnchor or not tab.rightPanel then return end
    local du = getDU()
    local strip = du.SOUND_BROWSER_BOTTOM_COPY_STRIP_HEIGHT or 42
    tab.infoPanel:ClearAllPoints()
    tab.infoPanel:SetPoint("TOPLEFT", tab.controlsAnchor, "BOTTOMLEFT", 0, -8)
    if tab.manualPanel and tab.manualPanel:IsShown() then
        tab.infoPanel:SetPoint("BOTTOMLEFT", tab.manualPanel, "TOPLEFT", 0, 8)
        tab.infoPanel:SetPoint("BOTTOMRIGHT", tab.manualPanel, "TOPRIGHT", 0, 8)
    else
        tab.infoPanel:SetPoint("BOTTOMRIGHT", tab.rightPanel, "BOTTOMRIGHT", -6, strip)
    end
end

local function bindSoundCvarCheckboxTooltip(cb, tipText)
    cb:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(tipText, OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        GameTooltip:Show()
    end)
    cb:HookScript("OnLeave", GameTooltip_Hide)
end

local function refreshManualModeDropdownLabel(tab)
    local dd = tab.manualModeDropdown
    if not dd or not dd._text then return end
    local v = tab.manualModeValue or MANUAL_FDID
    if v == MANUAL_KIT then
        dd._text:SetText(L["SOUND_MANUAL_MODE_KIT"])
    elseif v == MANUAL_KEY then
        dd._text:SetText(L["SOUND_MANUAL_MODE_KEY"])
    else
        dd._text:SetText(L["SOUND_MANUAL_MODE_FDID"])
    end
end

local function afterBookmarkToggle(tab)
    if SB.favoritesOnly then
        SB:RebuildFiltered()
        refreshListSelection(tab, true)
    else
        SB:RebuildFiltered()
        refreshListSelection(tab, false)
    end
    refreshSoundToolbar(tab)
end

function Addon.UI:CreateSoundBrowserTab(parent)
    SB = Addon.SoundBrowser
    if not SB then return CreateFrame("Frame", nil, parent) end

    local DU = getDU()
    local ROW_H = DU.SOUND_BROWSER_LIST_ROW_HEIGHT or DU.TEXTURE_BROWSER_LIST_ROW_HEIGHT or 22
    local NUM_ROWS = DU.SOUND_BROWSER_LIST_VISIBLE_ROWS or DU.TEXTURE_BROWSER_LIST_VISIBLE_ROWS or 40
    local LEFT_DEFAULT = DU.SOUND_BROWSER_LEFT_PANE_DEFAULT_WIDTH or DU.TEXTURE_BROWSER_LEFT_PANE_DEFAULT_WIDTH or 300
    local LEFT_MIN = DU.SOUND_BROWSER_LEFT_PANE_MIN_WIDTH or DU.TEXTURE_BROWSER_LEFT_PANE_MIN_WIDTH or 200
    local RIGHT_MIN = DU.SOUND_BROWSER_RIGHT_PANE_MIN_WIDTH or DU.TEXTURE_BROWSER_RIGHT_PANE_MIN_WIDTH or 260
    local DIV_W = DU.FRAME_INSPECTOR_DIVIDER_WIDTH or 6
    local stripH = DU.SOUND_BROWSER_BOTTOM_COPY_STRIP_HEIGHT or 42
    local manualPanelH = DU.SOUND_BROWSER_MANUAL_PANEL_HEIGHT or 92

    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)
    tab:Hide()
    tab.soundChannelValue = getSavedSoundChannel()
    tab.manualModeValue = MANUAL_FDID
    tab.manualLastSoundKitId = nil

    function tab:StopPlayback()
        Addon.UI.SoundTab_StopPlayback(self)
    end

    if not SB:IsDataAvailable() then
        local warn = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        warn:SetPoint("TOPLEFT", tab, "TOPLEFT", 12, -12)
        warn:SetPoint("TOPRIGHT", tab, "TOPRIGHT", -12, -12)
        warn:SetJustifyH("LEFT")
        warn:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        local unloadOn = Addon.UI and Addon.UI.GetUnloadOnDisable and Addon.UI:GetUnloadOnDisable("sounds")
        local msg
        if unloadOn then
            msg = L["SOUND_MSG_UNLOADED"]
        elseif Addon._DevToolSoundAssetsPurgedSession then
            msg = L["SOUND_MSG_RELOAD_RESTORE"]
        else
            msg = L["SOUND_MSG_NO_DATA"]
        end
        warn:SetText(msg)
        function tab:StopPlayback() end
        function tab:Teardown()
            if Addon.SoundBrowserTab == self then
                Addon.SoundBrowserTab = nil
            end
        end
        Addon.SoundBrowserTab = tab
        return tab
    end

    SB:EnsureDefaultCategory()
    SB:SetFilterText("")
    SB:RebuildFiltered()
    SB:SetFilteredReadyCallback(function()
        if Addon.SoundBrowserTab ~= tab then
            return
        end
        refreshListSelection(tab, true)
    end)

    local topDropdown = OneWoW_GUI:CreateDropdown(tab, { width = 140, height = 22, text = "" })
    topDropdown:SetPoint("TOPLEFT", tab, "TOPLEFT", 5, -5)
    OneWoW_GUI:AttachFilterMenu(topDropdown, {
        searchable = true,
        menuHeight = 280,
        getActiveValue = function() return SB.selectedTop end,
        buildItems = function()
            local items = {}
            for _, k in ipairs(SB:GetTopKeys()) do
                tinsert(items, { value = k, text = k })
            end
            return items
        end,
        onSelect = function(value)
            SB:SetCategory(value, nil)
            refreshTopDropdownLabel(tab)
            refreshSubDropdownLabel(tab)
            if SB:IsSearchingAll() then
                refreshListSelection(tab, false)
            else
                tab.selectedListIndex = nil
                tab.selectedEntry = nil
                if tab.nameText then tab.nameText:SetText("") end
                refreshListSelection(tab, true)
            end
            refreshSoundToolbar(tab)
        end,
    })
    tab.topDropdown = topDropdown
    refreshTopDropdownLabel(tab)

    local subDropdown = OneWoW_GUI:CreateDropdown(tab, { width = 160, height = 22, text = "" })
    subDropdown:SetPoint("LEFT", topDropdown, "RIGHT", 6, 0)
    OneWoW_GUI:AttachFilterMenu(subDropdown, {
        searchable = true,
        menuHeight = 320,
        getActiveValue = function() return SB.selectedSub end,
        buildItems = function()
            local items = {}
            local top = SB.selectedTop
            if not top then return items end
            for _, k in ipairs(SB:GetSubKeys(top)) do
                tinsert(items, { value = k, text = k })
            end
            return items
        end,
        onSelect = function(value)
            SB:SetCategory(SB.selectedTop, value)
            refreshSubDropdownLabel(tab)
            if SB:IsSearchingAll() then
                refreshListSelection(tab, false)
            else
                tab.selectedListIndex = nil
                tab.selectedEntry = nil
                if tab.nameText then tab.nameText:SetText("") end
                refreshListSelection(tab, true)
            end
            refreshSoundToolbar(tab)
        end,
    })
    tab.subDropdown = subDropdown
    refreshSubDropdownLabel(tab)

    local searchBox = OneWoW_GUI:CreateEditBox(tab, {
        width = 132,
        height = 22,
        placeholderText = L["LABEL_FILTER"],
        onTextChanged = function()
            scheduleFilterRefresh(tab)
        end,
    })
    searchBox:SetPoint("LEFT", subDropdown, "RIGHT", 6, 0)
    tab.searchBox = searchBox

    local searchScopeDropdown = OneWoW_GUI:CreateDropdown(tab, { width = 110, height = 22, text = "" })
    searchScopeDropdown:SetPoint("LEFT", searchBox, "RIGHT", 6, 0)
    OneWoW_GUI:AttachFilterMenu(searchScopeDropdown, {
        searchable = false,
        menuHeight = 120,
        getActiveValue = function() return SB.searchScope end,
        buildItems = function()
            return {
                { value = SEARCH_SCOPE_CURRENT, text = L["SOUND_SEARCH_SCOPE_CURRENT"] },
                { value = SEARCH_SCOPE_ALL, text = L["SOUND_SEARCH_SCOPE_ALL"] },
            }
        end,
        onSelect = function(value)
            SB:SetSearchScope(value)
            refreshSearchScopeDropdownLabel(tab)
            refreshListSelection(tab, true)
        end,
    })
    tab.searchScopeDropdown = searchScopeDropdown
    refreshSearchScopeDropdownLabel(tab)

    local toolbarBottom = -62

    local savedListW = Addon.db.global.soundBrowserLeftPaneWidth
    local initListW = LEFT_DEFAULT
    if type(savedListW) == "number" and savedListW >= LEFT_MIN then
        initListW = savedListW
    end

    local leftPanel = OneWoW_GUI:CreateFrame(tab, { backdrop = BACKDROP_INNER_NO_INSETS, width = 320, height = 100 })
    leftPanel:ClearAllPoints()
    leftPanel:SetPoint("TOPLEFT", tab, "TOPLEFT", 5, toolbarBottom)
    leftPanel:SetPoint("BOTTOM", tab, "BOTTOM", 0, 5)
    leftPanel:SetWidth(initListW)
    self:StyleContentPanel(leftPanel)

    local listAPI = OneWoW_GUI:CreateVirtualizedList(leftPanel, {
        name = "SoundBrowserListScroll",
        rowHeight = ROW_H,
        numVisibleRows = NUM_ROWS,
        getCount = function() return SB:GetFilteredCount() end,
        getEntry = function(idx) return SB:GetFilteredEntry(idx) end,
        onSelect = function(idx)
            applyListSelection(tab, idx)
        end,
        renderRow = function(btn, idx, entry, isSelected)
            ensureListRowBookmarkIcon(btn, ROW_H)
            if SB:IsBookmarked(entry) then
                btn._soundBmTex:SetTexture(BOOKMARK_ICON_PATH)
                btn._soundBmTex:Show()
            else
                btn._soundBmTex:Hide()
            end
            btn:SetText(SB:GetDisplayName(entry))
            btn._tooltipFullText = SB:GetFileName(entry) .. "\n" .. SB:GetCategoryLabel(entry) .. "\n" .. SB:GetFileDataIdString(entry) .. "\n" .. SB:GetFullPath(entry)
            styleListButtonText(btn)
        end,
        enableKeyboardNav = true,
        focusCompetitor = searchBox,
    })
    tab.virtualizedList = listAPI
    hookListDoubleClickAndEnter(tab, leftPanel)

    local rightPanel = OneWoW_GUI:CreateFrame(tab, { backdrop = BACKDROP_INNER_NO_INSETS, width = 100, height = 100 })
    self:StyleContentPanel(rightPanel)
    tab.rightPanel = rightPanel

    OneWoW_GUI:CreateVerticalPaneResizer({
        parent = tab,
        leftPanel = leftPanel,
        rightPanel = rightPanel,
        dividerWidth = DIV_W,
        leftMinWidth = LEFT_MIN,
        rightMinWidth = RIGHT_MIN,
        splitPadding = DIV_W + 10,
        bottomOuterInset = 5,
        rightOuterInset = 5,
        resizeCap = DU.MAIN_FRAME_RESIZE_CAP or 0.95,
        mainFrame = Addon.UI and Addon.UI.mainFrame,
        onWidthChanged = function(w)
            Addon.db.global.soundBrowserLeftPaneWidth = w
        end,
    })

    tab.nameText = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    tab.nameText:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 8, -16)
    tab.nameText:SetPoint("TOPRIGHT", rightPanel, "TOPRIGHT", -8, -16)
    tab.nameText:SetJustifyH("LEFT")
    tab.nameText:SetWordWrap(true)
    if tab.nameText.SetMaxLines then
        tab.nameText:SetMaxLines(2)
    end
    tab.nameText:SetText("")
    tab.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local channelLabel = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    channelLabel:SetPoint("TOPLEFT", tab.nameText, "BOTTOMLEFT", 0, -18)
    channelLabel:SetText(L["SOUND_LABEL_CHANNEL"])
    channelLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local channelDropdown = OneWoW_GUI:CreateDropdown(rightPanel, { width = 120, height = 22, text = "" })
    channelDropdown:SetPoint("LEFT", channelLabel, "RIGHT", 8, 0)
    tab.channelDropdown = channelDropdown
    OneWoW_GUI:AttachFilterMenu(channelDropdown, {
        searchable = false,
        menuHeight = 200,
        getActiveValue = function() return tab.soundChannelValue end,
        buildItems = function()
            local items = {}
            for _, ch in ipairs(SOUND_CHANNELS) do
                tinsert(items, { value = ch, text = ch })
            end
            return items
        end,
        onSelect = function(value)
            tab.soundChannelValue = value
            Addon.db.global.soundBrowserChannel = value
            refreshChannelDropdownLabel(tab)
            Addon.UI.SoundTab_UpdateDetails(tab)
        end,
    })
    refreshChannelDropdownLabel(tab)

    local musicCb = OneWoW_GUI:CreateCheckbox(rightPanel, { label = L["SOUND_CVAR_MUSIC_LABEL"] })
    musicCb:SetPoint("LEFT", channelDropdown, "RIGHT", 14, 0)
    tab.soundCvarMusicCb = musicCb
    bindSoundCvarCheckboxTooltip(musicCb, L["SOUND_CVAR_MUSIC_TIP"])
    musicCb:SetScript("OnClick", function(self)
        if tab._syncingSoundCvars then return end
        C_CVar.SetCVar(Addon.Constants.SOUND_CVAR_ENABLE_MUSIC, self:GetChecked() and "1" or "0")
    end)

    local ambienceCb = OneWoW_GUI:CreateCheckbox(rightPanel, { label = L["SOUND_CVAR_AMBIENCE_LABEL"] })
    ambienceCb:SetPoint("LEFT", musicCb.label, "RIGHT", 10, 0)
    tab.soundCvarAmbienceCb = ambienceCb
    bindSoundCvarCheckboxTooltip(ambienceCb, L["SOUND_CVAR_AMBIENCE_TIP"])
    ambienceCb:SetScript("OnClick", function(self)
        if tab._syncingSoundCvars then return end
        C_CVar.SetCVar(Addon.Constants.SOUND_CVAR_ENABLE_AMBIENCE, self:GetChecked() and "1" or "0")
    end)

    tab.soundCvarListener = CreateFrame("Frame", nil, tab)
    tab.soundCvarListener:SetScript("OnEvent", function(_, _, cvarName)
        local cm = Addon.Constants.SOUND_CVAR_ENABLE_MUSIC
        local ca = Addon.Constants.SOUND_CVAR_ENABLE_AMBIENCE
        if cvarName ~= cm and cvarName ~= ca then return end
        if not Addon.UI or Addon.UI.currentTabKey ~= "sounds" then return end
        Addon.UI.SoundTab_RefreshSoundCvarCheckboxes()
    end)
    tab.soundCvarListener:RegisterEvent("CVAR_UPDATE")

    local playBtn = OneWoW_GUI:CreateFitTextButton(rightPanel, {
        text = L["SOUND_BTN_PLAY"],
        height = 22,
        minWidth = 48,
    })
    playBtn:SetPoint("TOPLEFT", channelLabel, "BOTTOMLEFT", 0, -12)
    playBtn:SetScript("OnClick", function()
        if not tab.selectedEntry then return end
        Addon.UI.SoundTab_PlayListSelection(tab)
    end)

    local stopBtn = OneWoW_GUI:CreateFitTextButton(rightPanel, {
        text = L["BTN_STOP"],
        height = 22,
        minWidth = 48,
    })
    stopBtn:SetPoint("LEFT", playBtn, "RIGHT", 6, 0)
    stopBtn:SetScript("OnClick", function()
        Addon.UI.SoundTab_StopPlayback(tab)
        SoundTab_updateLastPlayLine(tab, false, nil)
        Addon.UI.SoundTab_UpdateDetails(tab)
    end)

    local controlsAnchor = CreateFrame("Frame", nil, rightPanel)
    controlsAnchor:SetPoint("TOPLEFT", playBtn, "BOTTOMLEFT", 0, -20)
    controlsAnchor:SetPoint("TOPRIGHT", stopBtn, "BOTTOMRIGHT", 0, -20)
    controlsAnchor:SetHeight(1)
    tab.controlsAnchor = controlsAnchor

    tab.manualPanel = CreateFrame("Frame", nil, rightPanel)
    tab.manualPanel:SetPoint("BOTTOMLEFT", rightPanel, "BOTTOMLEFT", 8, stripH)
    tab.manualPanel:SetPoint("BOTTOMRIGHT", rightPanel, "BOTTOMRIGHT", -8, stripH)
    tab.manualPanel:SetHeight(0)
    tab.manualPanel:Hide()

    local manualModeDrop = OneWoW_GUI:CreateDropdown(tab.manualPanel, { width = 130, height = 22, text = "" })
    manualModeDrop:SetPoint("TOPLEFT", tab.manualPanel, "TOPLEFT", 0, 0)
    tab.manualModeDropdown = manualModeDrop
    OneWoW_GUI:AttachFilterMenu(manualModeDrop, {
        searchable = false,
        getActiveValue = function() return tab.manualModeValue end,
        buildItems = function()
            return {
                { value = MANUAL_FDID, text = L["SOUND_MANUAL_MODE_FDID"] },
                { value = MANUAL_KIT, text = L["SOUND_MANUAL_MODE_KIT"] },
                { value = MANUAL_KEY, text = L["SOUND_MANUAL_MODE_KEY"] },
            }
        end,
        onSelect = function(value)
            tab.manualModeValue = value
            refreshManualModeDropdownLabel(tab)
        end,
    })
    refreshManualModeDropdownLabel(tab)

    local manualEdit = OneWoW_GUI:CreateEditBox(tab.manualPanel, {
        width = 200,
        height = 22,
        placeholderText = L["SOUND_MANUAL_PLACEHOLDER"],
    })
    manualEdit:SetPoint("LEFT", manualModeDrop, "RIGHT", 6, 0)
    tab.manualEdit = manualEdit

    local manualPlayBtn = OneWoW_GUI:CreateFitTextButton(tab.manualPanel, {
        text = L["SOUND_BTN_PLAY"],
        height = 22,
        minWidth = 48,
    })
    manualPlayBtn:SetPoint("LEFT", manualEdit, "RIGHT", 6, 0)
    manualPlayBtn:SetScript("OnClick", function()
        local raw = strtrim(manualEdit:GetSearchText() or "")
        local mode = tab.manualModeValue or MANUAL_FDID
        if mode == MANUAL_FDID then
            local n = tonumber(raw)
            if not n then
                Addon:Print(L["SOUND_ERR_BAD_FDID"])
                return
            end
            local ok, handle = startPlaySoundFile(tab, n)
            SoundTab_updateLastPlayLine(tab, ok, n)
            Addon.UI.SoundTab_UpdateDetails(tab)
            Addon.UI.SoundTab_UpdateCopyRow(tab)
            return
        end
        if mode == MANUAL_KIT then
            local n = tonumber(raw)
            if not n then
                Addon:Print(L["SOUND_ERR_BAD_KIT"])
                return
            end
            local ok, handle = startPlaySoundKit(tab, n)
            SoundTab_updateLastPlayLine(tab, ok, n)
            Addon.UI.SoundTab_UpdateDetails(tab)
            Addon.UI.SoundTab_UpdateCopyRow(tab)
            return
        end
        local kitId, err = SB:ParseSoundKitKeyInput(raw)
        if not kitId then
            if err == "empty" then
                Addon:Print(L["SOUND_ERR_EMPTY_KEY"])
            elseif err == "nosoundkit" then
                Addon:Print(L["SOUND_ERR_NO_SOUNDKIT"])
            else
                Addon:Print(L["SOUND_ERR_UNKNOWN_KEY"])
            end
            return
        end
        local ok, handle = startPlaySoundKit(tab, kitId)
        SoundTab_updateLastPlayLine(tab, ok, kitId)
        Addon.UI.SoundTab_UpdateDetails(tab)
        Addon.UI.SoundTab_UpdateCopyRow(tab)
    end)

    local manualCopyKit = OneWoW_GUI:CreateFitTextButton(tab.manualPanel, {
        text = L["SOUND_BTN_COPY_KIT"],
        height = 22,
        minWidth = 56,
    })
    manualCopyKit:SetPoint("TOPLEFT", manualModeDrop, "BOTTOMLEFT", 0, -12)
    manualCopyKit:SetScript("OnClick", function()
        local k = tab.manualLastSoundKitId
        if type(k) == "number" then
            Addon:CopyToClipboard(tostring(k))
        end
    end)
    tab.copyKitBtn = manualCopyKit

    local manualCopyPS = OneWoW_GUI:CreateFitTextButton(tab.manualPanel, {
        text = L["SOUND_BTN_COPY_PLAY_SOUND"],
        height = 22,
        minWidth = 72,
    })
    manualCopyPS:SetPoint("LEFT", manualCopyKit, "RIGHT", 10, 0)
    manualCopyPS:SetScript("OnClick", function()
        local k = tab.manualLastSoundKitId
        if type(k) == "number" then
            Addon:CopyToClipboard(SB:GetPlaySoundSnippet(k, getSoundChannel(tab)))
        end
    end)
    tab.copyPlaySoundSnippetBtn = manualCopyPS

    local infoPanel = OneWoW_GUI:CreateFrame(rightPanel, { backdrop = BACKDROP_INNER_NO_INSETS, width = 100, height = 100 })
    tab.infoPanel = infoPanel
    self:StyleContentPanel(infoPanel)
    soundTabApplyInfoPanelBounds(tab)

    local infoScroll, infoContent = OneWoW_GUI:CreateScrollFrame(infoPanel, {})
    infoScroll:ClearAllPoints()
    infoScroll:SetPoint("TOPLEFT", 4, -4)
    infoScroll:SetPoint("BOTTOMRIGHT", -14, 4)
    infoScroll:HookScript("OnSizeChanged", function(_, w)
        infoContent:SetWidth(w)
    end)
    tab.infoScroll = infoScroll
    tab.infoText = infoContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tab.infoText:SetPoint("TOPLEFT", 2, -2)
    tab.infoText:SetPoint("RIGHT", infoContent, "RIGHT", -2, 0)
    tab.infoText:SetJustifyH("LEFT")
    tab.infoText:SetText("")
    tab.infoText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local copyRowLabel = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    copyRowLabel:SetText(L["SOUND_COPY_ROW_LABEL"])
    copyRowLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
    copyRowLabel:SetPoint("BOTTOMLEFT", rightPanel, "BOTTOMLEFT", 6, 8)

    local copyFdidBtn = OneWoW_GUI:CreateFitTextButton(rightPanel, {
        text = L["SOUND_BTN_COPY_FDID"],
        height = 22,
        minWidth = 44,
    })
    copyFdidBtn:SetPoint("LEFT", copyRowLabel, "RIGHT", 6, -5)
    copyFdidBtn:SetPoint("BOTTOM", rightPanel, "BOTTOM", 0, 6)
    copyFdidBtn:SetScript("OnClick", function()
        local e = tab.selectedEntry
        if e then
            Addon:CopyToClipboard(SB:GetFileDataIdString(e))
        end
    end)
    tab.copyFdidBtn = copyFdidBtn

    local copyPathBtn = OneWoW_GUI:CreateFitTextButton(rightPanel, {
        text = L["SOUND_BTN_COPY_PATH"],
        height = 22,
        minWidth = 44,
    })
    copyPathBtn:SetPoint("LEFT", copyFdidBtn, "RIGHT", 4, 0)
    copyPathBtn:SetScript("OnClick", function()
        local e = tab.selectedEntry
        if e then
            Addon:CopyToClipboard(SB:GetFullPath(e))
        end
    end)
    tab.copyPathBtn = copyPathBtn

    local copySnippetBtn = OneWoW_GUI:CreateFitTextButton(rightPanel, {
        text = L["SOUND_BTN_COPY_SNIPPET"],
        height = 22,
        minWidth = 52,
    })
    copySnippetBtn:SetPoint("LEFT", copyPathBtn, "RIGHT", 4, 0)
    copySnippetBtn:SetScript("OnClick", function()
        local e = tab.selectedEntry
        if e then
            Addon:CopyToClipboard(SB:GetPlaySoundFileSnippet(e, getSoundChannel(tab)))
        end
    end)
    tab.copySnippetBtn = copySnippetBtn

    local favsBtn = OneWoW_GUI:CreateFitTextButton(tab, {
        text = L["BTN_FAVORITES"],
        height = 22,
        minWidth = 64,
    })
    favsBtn:SetPoint("TOPLEFT", tab, "TOPLEFT", 5, -32)
    Addon.UI:BindToolbarBarButtonMouse(favsBtn, SOUND_BAR_ACTIVE_KEY)
    favsBtn:SetScript("OnClick", function()
        SB:SetFavoritesOnly(not SB.favoritesOnly)
        tab.selectedListIndex = nil
        tab.selectedEntry = nil
        afterBookmarkToggle(tab)
    end)
    tab.favsBtn = favsBtn

    local bookmarkBtn = OneWoW_GUI:CreateFitTextButton(tab, {
        text = L["BTN_BOOKMARK"],
        height = 22,
        minWidth = 64,
    })
    bookmarkBtn:SetPoint("LEFT", favsBtn, "RIGHT", 4, 0)
    Addon.UI:BindToolbarBarButtonMouse(bookmarkBtn, SOUND_BAR_ACTIVE_KEY)
    bookmarkBtn:SetScript("OnClick", function()
        if not tab.selectedEntry then return end
        local added = SB:ToggleBookmark(tab.selectedEntry)
        local label = SB:GetFileName(tab.selectedEntry)
        if label == "" then
            label = SB:GetFileDataIdString(tab.selectedEntry)
        end
        if added then
            Addon:Print((L["MSG_BOOKMARKED"]):gsub("{name}", tostring(label)))
        else
            Addon:Print((L["MSG_REMOVED_BOOKMARK"]):gsub("{name}", tostring(label)))
        end
        afterBookmarkToggle(tab)
    end)
    tab.bookmarkBtn = bookmarkBtn

    local manualToggle = OneWoW_GUI:CreateFitTextButton(tab, {
        text = L["SOUND_BTN_MANUAL"],
        height = 22,
        minWidth = 56,
    })
    manualToggle:SetPoint("LEFT", bookmarkBtn, "RIGHT", 6, 0)
    Addon.UI:BindToolbarBarButtonMouse(manualToggle, SOUND_BAR_ACTIVE_KEY)
    manualToggle:SetScript("OnClick", function()
        if tab.manualPanel:IsShown() then
            tab.manualPanel:SetHeight(0)
            tab.manualPanel:Hide()
        else
            tab.manualPanel:SetHeight(manualPanelH)
            tab.manualPanel:Show()
        end
        soundTabApplyInfoPanelBounds(tab)
        refreshSoundToolbar(tab)
    end)
    tab.manualToggle = manualToggle

    tab:SetScript("OnHide", function()
        if tab._filterTicker then
            tab._filterTicker:Cancel()
            tab._filterTicker = nil
        end
        if SB then
            SB:CancelSearch()
        end
        Addon.UI.SoundTab_StopPlayback(tab)
    end)

    function tab:Teardown()
        if self._filterTicker then
            self._filterTicker:Cancel()
            self._filterTicker = nil
        end
        if SB then
            SB:CancelSearch()
            SB:SetFilteredReadyCallback(nil)
        end
        if self.soundCvarListener then
            self.soundCvarListener:UnregisterAllEvents()
            self.soundCvarListener:SetScript("OnEvent", nil)
            self.soundCvarListener = nil
        end
        Addon.UI.SoundTab_StopPlayback(self)
        if Addon.SoundBrowserTab == self then
            Addon.SoundBrowserTab = nil
        end
    end

    Addon.SoundBrowserTab = tab

    Addon.UI.SoundTab_RefreshList(tab)
    if SB:GetFilteredCount() > 0 then
        tab.virtualizedList.SetSelectedIndex(1)
    else
        Addon.UI.SoundTab_UpdateDetails(tab)
        Addon.UI.SoundTab_UpdateCopyRow(tab)
    end
    refreshSoundToolbar(tab)
    Addon.UI.SoundTab_RefreshSoundCvarCheckboxes()

    return tab
end
