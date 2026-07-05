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
local categoryFilter = "All"
local typeFilter     = "All"
local storageFilter  = "All"
local searchFilter   = ""
local currentSort    = { by = "name", ascending = true }

local detailPanel    = nil
local emptyMessage   = nil
local leftStatusText = nil
local scrollChild    = nil

-- Intent is the user's plan for a collectible; stored on the record as a plain
-- token. "none" maps to the Blizzard NONE global; the rest are scoped keys.
local INTENT_ORDER = { "none", "want", "spotted", "farming" }

local function IntentLabel(intent)
    if intent == "want" then
        return L["COLLECTIBLE_INTENT_WANT"]
    elseif intent == "spotted" then
        return L["COLLECTIBLE_INTENT_SPOTTED"]
    elseif intent == "farming" then
        return L["COLLECTIBLE_INTENT_FARMING"]
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
    return name, icon, link, sourceText, complete
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
    controlPanel:SetHeight(75)

    local controlTitle = OneWoW_GUI:CreateFS(controlPanel, 10)
    controlTitle:SetPoint("TOPLEFT", controlPanel, "TOPLEFT", 10, -8)
    controlTitle:SetText(L["COLLECTIBLES_CONTROLS"])
    controlTitle:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local catDD = ns.UI.CreateThemedDropdown(controlPanel, CATEGORY, 140, 25)
    catDD:SetPoint("TOPLEFT", controlPanel, "TOPLEFT", 10, -30)
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
        {text = ALL,      value = "All"},
        {text = MOUNTS,   value = "mount"},
        {text = WARDROBE, value = "appearance"},
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
    sortHandle.dropdown:SetPoint("LEFT", storeDD, "RIGHT", 6, 0)
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
    listingPanel:SetWidth(258)

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

        -- Ensemble progress: only meaningful for an appearance source that belongs
        -- to a transmog set. GetContainingSets returns nil for everything else.
        local setLine
        local setIDs = OneWoW.Collectibles.GetContainingSets(selectedKey)
        if setIDs and setIDs[1] then
            local progress = OneWoW.Collectibles.GetEnsembleProgress(setIDs[1])
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
            header.statusText:SetText(state.collected and COLLECTED or NOT_COLLECTED)
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
                local record = ns.Collectibles:GetCollectible(selectedKey)
                if record then
                    record.intent = value
                    ns.Collectibles:SaveCollectible(selectedKey, record)
                    parent.RefreshCollectiblesList()
                end
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
                if matches and searchFilter ~= "" then
                    if not name:lower():find(searchFilter:lower(), 1, true) then matches = false end
                end
                if matches then
                    list[#list + 1] = { key = key, record = record, name = name }
                end
            end
        end

        local function sortEntries(a, b)
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
            local row = ns.UI.CreateNotesListRow(scrollChild, {
                yOffset     = yOffset,
                barColor    = barColor,
                icon        = icon,
                title       = entry.name,
                detail      = detailText,
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
            })
            table.insert(collListRows, row)
            yOffset = yOffset - ns.UI.LIST_ROW_SPACING
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
        selectedKey    = key
        searchFilter   = ""
        categoryFilter = "All"
        typeFilter     = "All"
        storageFilter  = "All"
        searchBox:SetText("")
        catDD:SetSelected("All")
        typeDD:SetSelected("All")
        storeDD:SetSelected("All")
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

    ns.UI.OpenNotesCollectible = function(key)
        return OpenCollectibleEditor(key)
    end

    function parent.Activate()
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
