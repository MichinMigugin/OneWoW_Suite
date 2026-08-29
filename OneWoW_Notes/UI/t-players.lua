local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI

local BACKDROP_SIMPLE = OneWoW_GUI.Constants.BACKDROP_SIMPLE

ns.UI = ns.UI or {}

local selectedPlayer  = nil
local playerListItems = {}
local categoryFilter  = "All"
local storageFilter   = "All"
local searchFilter    = ""
local currentSort     = { by = "name", ascending = true }

local detailPanel    = nil
local emptyMessage   = nil
local leftStatusText = nil
local scrollChild    = nil

local MEDIA = OneWoW_GUI.Constants.MEDIA_BASE
local Detail = ns.Constants.Detail

function ns.UI.CreatePlayersTab(parent)
    do
        local p = ns.db.global.tabSortPrefs.players
        currentSort.by        = ns.UI.NormalizeSortBy(p.by) or "name"
        currentSort.ascending = p.ascending ~= false
        if p.by == "manual" then
            ns.db.global.tabSortPrefs.players = { by = "custom", ascending = p.ascending ~= false }
        end
    end

    local controlPanel = ns.UI.CreateThemedBar(nil, parent)
    controlPanel:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, 0)
    controlPanel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    controlPanel:SetHeight(45)

    local addTargetBtn = OneWoW_GUI:CreateFitTextButton(controlPanel, { text = L["BUTTON_ADD_TARGET"], height = 25, minWidth = 80 })
    addTargetBtn:SetPoint("TOPLEFT", controlPanel, "TOPLEFT", 10, -10)
    addTargetBtn:SetScript("OnClick", function()
        if ns.Players then
            local playerInfo = ns.Players:GetTargetPlayerInfo()
            if not playerInfo then
                print("|cFFFFD100OneWoW - Players:|r " .. (L["MSG_TARGET_PLAYER_FIRST"]))
                return
            end
            if ns.Players:GetPlayer(playerInfo.fullName) then
                print("|cFFFFD100OneWoW - Players:|r " .. (L["MSG_PLAYER_EXISTS"]))
                return
            end
            local fullName = ns.Players:AddPlayer(playerInfo.fullName, playerInfo)
            parent.RefreshPlayersList()
            if parent.SelectPlayer and fullName then parent.SelectPlayer(fullName) end
        end
    end)
    addTargetBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["BUTTON_ADD_TARGET"], 1, 1, 1)
        GameTooltip:AddLine(L["TOOLTIP_BUTTON_ADD_TARGET_PLAYER_DESC"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    addTargetBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local addManualBtn = OneWoW_GUI:CreateFitTextButton(controlPanel, { text = L["BUTTON_MANUAL_ENTRY"], height = 25, minWidth = 70 })
    addManualBtn:SetPoint("LEFT", addTargetBtn, "RIGHT", 5, 0)
    addManualBtn:SetScript("OnClick", function()
        if ns.UI and ns.UI.ShowManualPlayerEntryDialog then
            ns.UI.ShowManualPlayerEntryDialog(parent)
        end
    end)
    addManualBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["BUTTON_MANUAL_ENTRY"], 1, 1, 1)
        GameTooltip:AddLine(L["TOOLTIP_BUTTON_MANUAL_ENTRY_PLAYER_DESC"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    addManualBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local addAltsBtn = OneWoW_GUI:CreateFitTextButton(controlPanel, { text = L["PLAYER_ADD_ALTS"], height = 25, minWidth = 70 })
    addAltsBtn:SetPoint("LEFT", addManualBtn, "RIGHT", 5, 0)

    local function CharacterRosterReady()
        return OneWoW_AltTracker_Character_API ~= nil
    end

    local function ApplyAddAltsEnabled()
        if CharacterRosterReady() then
            addAltsBtn:Enable()
            addAltsBtn:SetAlpha(1)
        else
            addAltsBtn:Disable()
            addAltsBtn:SetAlpha(0.4)
        end
    end

    ApplyAddAltsEnabled()
    OneWoW:RegisterDataReadyWatcher("OneWoW_AltTracker_Character", ApplyAddAltsEnabled)

    addAltsBtn:SetScript("OnClick", function()
        if not CharacterRosterReady() then
            print("|cFFFFD100OneWoW - Players:|r " .. (L["PLAYER_ALTS_NO_DATA"]))
            return
        end
        if ns.UI and ns.UI.ShowAddAltsDialog then
            ns.UI.ShowAddAltsDialog(parent)
        end
    end)
    addAltsBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["PLAYER_ADD_ALTS"], 1, 1, 1)
        if CharacterRosterReady() then
            GameTooltip:AddLine(L["PLAYER_ADD_ALTS_DESC"], 0.8, 0.8, 0.8, true)
        else
            GameTooltip:AddLine(L["PLAYER_ALTS_NOT_INSTALLED"], 1.0, 0.3, 0.3, true)
        end
        GameTooltip:Show()
    end)
    addAltsBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local addGuildBtn = OneWoW_GUI:CreateFitTextButton(controlPanel, { text = L["PLAYER_ADD_GUILD"], height = 25, minWidth = 70 })
    addGuildBtn:SetPoint("LEFT", addAltsBtn, "RIGHT", 5, 0)
    addGuildBtn:SetScript("OnClick", function()
        if ns.UI and ns.UI.ShowAddGuildDialog then
            ns.UI.ShowAddGuildDialog(parent)
        end
    end)
    addGuildBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["PLAYER_ADD_GUILD"], 1, 1, 1)
        GameTooltip:AddLine(L["PLAYER_ADD_GUILD_DESC"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    addGuildBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local catDD = ns.UI.CreateThemedDropdown(controlPanel, CATEGORY, 140, 25)
    catDD:SetPoint("LEFT", addGuildBtn, "RIGHT", 8, 0)
    local storeDD
    local function CountPlayersForFilters(ignoreDim)
        local counts = { all = 0, byCategory = {}, byStorage = { All = 0, account = 0, character = 0 } }
        if not ns.Players then return counts end
        local searchLower = (searchFilter or ""):lower()
        local allPlayers = ns.Players:GetAllPlayers()
        for fullName, pd in pairs(allPlayers) do
            if type(pd) == "table" then
                local ok = true
                if ignoreDim ~= "category" and categoryFilter ~= "All"
                    and pd.category ~= categoryFilter then
                    ok = false
                end
                if ignoreDim ~= "storage" and storageFilter ~= "All"
                    and pd.storage ~= storageFilter then
                    ok = false
                end
                if searchLower ~= "" then
                    local nameLower = (pd.name or fullName):lower()
                    if not nameLower:find(searchLower, 1, true) then
                        ok = false
                    end
                end
                if ok then
                    counts.all = counts.all + 1
                    local cat = pd.category or "General"
                    counts.byCategory[cat] = (counts.byCategory[cat] or 0) + 1
                    local stor = pd.storage == "character" and "character" or "account"
                    counts.byStorage[stor] = (counts.byStorage[stor] or 0) + 1
                    counts.byStorage.All = counts.byStorage.All + 1
                end
            end
        end
        return counts
    end
    local function RefreshCatOpts()
        local catCounts = CountPlayersForFilters("category")
        local opts = {{
            text = ALL,
            value = "All",
            rightText = ns.UI.FormatSectionCount(catCounts.all),
        }}
        if ns.Players then
            for _, c in ipairs(ns.Players:GetCategories()) do
                opts[#opts + 1] = {
                    text = c,
                    value = c,
                    rightText = ns.UI.FormatSectionCount(catCounts.byCategory[c] or 0),
                }
            end
        end
        catDD:SetOptions(opts)
        catDD:SetSelected(categoryFilter)
    end
    RefreshCatOpts()
    catDD.onSelect = function(value)
        categoryFilter = value
        parent.RefreshPlayersList()
    end

    local manageCategoriesBtn = OneWoW_GUI:CreateIconButton(controlPanel, {
        iconTexture = MEDIA .. "icon-gears.png",
        size = 20,
        texCoord = { 0.1, 0.9, 0.1, 0.9 },
        tooltipTitle = L["CATMGR_TITLE"],
        tooltipText = L["UI_MANAGE_CATEGORIES_DESC"],
        onClick = function()
            ns.UI.ShowCategoryManager("players")
        end,
    })
    manageCategoriesBtn:SetPoint("LEFT", catDD, "RIGHT", 4, 0)

    storeDD = ns.UI.CreateThemedDropdown(controlPanel, L["LABEL_STORAGE"], 130, 25)
    storeDD:SetPoint("LEFT", manageCategoriesBtn, "RIGHT", 4, 0)
    local function RefreshStorageOpts()
        local storCounts = CountPlayersForFilters("storage")
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
        parent.RefreshPlayersList()
    end

    local playerSortHandle = OneWoW_GUI:CreateSortControls(controlPanel, {
        sortFields = {
            {key = "name",     label = NAME},
            {key = "class",    label = CLASS},
            {key = "faction",  label = FACTION},
            {key = "level",    label = LEVEL},
            {key = "category", label = CATEGORY},
            {key = "custom",   label = CUSTOM},
        },
        defaultField  = currentSort.by,
        defaultAsc    = currentSort.ascending,
        dropdownWidth = 100,
        onChange = function(field, ascending)
            currentSort.by        = field
            currentSort.ascending = ascending
            ns.db.global.tabSortPrefs.players = { by = field, ascending = ascending }
            parent.RefreshPlayersList()
        end,
    })
    playerSortHandle.dropdown:SetPoint("LEFT", storeDD, "RIGHT", 6, 0)
    playerSortHandle.dirBtn:SetPoint("LEFT", playerSortHandle.dropdown, "RIGHT", 4, 0)

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
    listingPanel:SetPoint("TOPLEFT",  controlPanel, "BOTTOMLEFT",  0, -10)
    listingPanel:SetPoint("BOTTOMLEFT", parent,     "BOTTOMLEFT",  0, 35)
    listingPanel:SetWidth(OneWoW_GUI.Constants.GUI.LEFT_PANEL_WIDTH)

    local listingTitle = OneWoW_GUI:CreateFS(listingPanel, 16)
    listingTitle:SetPoint("TOP", listingPanel, "TOP", 0, -10)
    listingTitle:SetText(L["PLAYERS_LIST"])
    listingTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local searchBox = OneWoW_GUI:CreateEditBox(listingPanel, {
        placeholderText = L["SEARCH"],
        onTextChanged = function(text)
            searchFilter = text
            if parent.RefreshPlayersList then parent.RefreshPlayersList() end
        end,
    })
    searchBox:SetPoint("TOPLEFT",  listingPanel, "TOPLEFT",  8, -30)
    searchBox:SetPoint("TOPRIGHT", listingPanel, "TOPRIGHT", -8, -30)

    local listScroll = ns.UI.CreateCustomScroll(listingPanel)
    scrollChild = listScroll.scrollChild
    listScroll.container:SetPoint("TOPLEFT",     listingPanel, "TOPLEFT",     10, -62)
    listScroll.container:SetPoint("BOTTOMRIGHT", listingPanel, "BOTTOMRIGHT", -10, 10)

    local sectionRowFrames = {}
    local sectionDataBags = {}
    local sectionReorders = {}
    local function GetOrCreateSectionReorder(sectionKey)
        if sectionReorders[sectionKey] then
            return sectionReorders[sectionKey]
        end
        local ctrl = ns.UI.CreateNotesListReorderDrag({
            getItems = function()
                return sectionRowFrames[sectionKey]
            end,
            getScrollFrame = function()
                return listScroll.scrollFrame
            end,
            onReorder = function(fromIdx, toIdx, insertBefore)
                local bag = sectionDataBags[sectionKey]
                if ns.UI.ApplySectionReorder(bag, fromIdx, toIdx, insertBefore) then
                    ns.UI.EnsureCustomSort(playerSortHandle, currentSort, "players")
                    parent.RefreshPlayersList()
                end
            end,
        })
        sectionReorders[sectionKey] = ctrl
        return ctrl
    end
    local function IsAnyPlayersReorderActive()
        for _, ctrl in pairs(sectionReorders) do
            if ctrl:IsActive() or ctrl:ShouldSuppressClick() then
                return true
            end
        end
        return false
    end

    detailPanel = ns.UI.CreateThemedPanel(nil, parent)
    detailPanel:SetPoint("TOPLEFT",     listingPanel, "TOPRIGHT",    10, 0)
    detailPanel:SetPoint("BOTTOMRIGHT", parent,       "BOTTOMRIGHT",  0, 35)
    detailPanel:SetClipsChildren(true)

    emptyMessage = OneWoW_GUI:CreateFS(detailPanel, 16)
    emptyMessage:SetPoint("CENTER", detailPanel, "CENTER")
    emptyMessage:SetText(L["PLAYERS_SELECT"])
    emptyMessage:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local leftStatusBar = ns.UI.CreateThemedBar(nil, parent)
    leftStatusBar:SetPoint("TOPLEFT",  listingPanel, "BOTTOMLEFT",  0, -5)
    leftStatusBar:SetPoint("TOPRIGHT", listingPanel, "BOTTOMRIGHT", 0, -5)
    leftStatusBar:SetHeight(25)

    leftStatusText = OneWoW_GUI:CreateFS(leftStatusBar, 10)
    leftStatusText:SetPoint("LEFT", leftStatusBar, "LEFT", 10, 0)
    leftStatusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    leftStatusText:SetText(string.format(L["UI_COUNT_FORMAT"], L["TAB_PLAYERS"], 0))

    local rightStatusBar = ns.UI.CreateThemedBar(nil, parent)
    rightStatusBar:SetPoint("TOPLEFT",     detailPanel, "BOTTOMLEFT",  0, -5)
    rightStatusBar:SetPoint("TOPRIGHT",    detailPanel, "BOTTOMRIGHT", 0, -5)
    rightStatusBar:SetHeight(25)

    local rightStatusText = OneWoW_GUI:CreateFS(rightStatusBar, 10)
    rightStatusText:SetPoint("LEFT", rightStatusBar, "LEFT", 10, 0)
    rightStatusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    rightStatusText:SetText(READY)

    local function ShowEditor()
        emptyMessage:Hide()
        for _, child in ipairs({detailPanel:GetChildren()}) do
            if child ~= emptyMessage then child:Hide() end
        end

        if not detailPanel.editorContent then
            local editorHeader = ns.UI.CreateDetailHeader(detailPanel)

            local nameServerLine = OneWoW_GUI:CreateFS(editorHeader, 16)
            nameServerLine:SetPoint("TOPLEFT", editorHeader, "TOPLEFT", 12, -12)
            nameServerLine:SetPoint("TOPRIGHT", editorHeader, "TOPRIGHT", -100, -12)
            nameServerLine:SetJustifyH("LEFT")
            nameServerLine:SetText("")
            nameServerLine:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            editorHeader.nameServerLine = nameServerLine

            local levelClassRaceLine = OneWoW_GUI:CreateFS(editorHeader, 12)
            levelClassRaceLine:SetPoint("TOPLEFT", nameServerLine, "BOTTOMLEFT", 0, -4)
            levelClassRaceLine:SetText("")
            levelClassRaceLine:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            editorHeader.levelClassRaceLine = levelClassRaceLine

            local guildLine = OneWoW_GUI:CreateFS(editorHeader, 12)
            guildLine:SetPoint("TOPLEFT", levelClassRaceLine, "BOTTOMLEFT", 0, -2)
            guildLine:SetText("")
            guildLine:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            editorHeader.guildLine = guildLine

            local categoryLine = OneWoW_GUI:CreateFS(editorHeader, 10)
            categoryLine:SetPoint("BOTTOMRIGHT", editorHeader, "BOTTOMRIGHT", -12, Detail.META_LINE_Y_UPPER)
            categoryLine:SetText(string.format(L["UI_CATEGORY_WITH_VALUE"], GENERAL))
            categoryLine:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            categoryLine:SetJustifyH("RIGHT")
            editorHeader.categoryLine = categoryLine

            local professionsLine = OneWoW_GUI:CreateFS(editorHeader, 10)
            professionsLine:SetPoint("BOTTOMRIGHT", editorHeader, "BOTTOMRIGHT", -12, Detail.META_LINE_Y_LOWER)
            professionsLine:SetText("")
            professionsLine:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            professionsLine:SetJustifyH("RIGHT")
            editorHeader.professionsLine = professionsLine

            local deleteBtn = ns.UI.CreateHeaderIconButton(editorHeader, {
                texture = "icon-trash.png",
            })
            deleteBtn:SetScript("OnClick", function()
                if selectedPlayer then
                    StaticPopupDialogs["ONEWOW_NOTES_CONFIRM_DELETE_PLAYER"] = {
                        text = string.format(L["POPUP_DELETE_PLAYER"]),
                        button1 = DELETE, button2 = CANCEL,
                        OnAccept = function()
                            if ns.Players then
                                ns.Players:RemovePlayer(selectedPlayer)
                                selectedPlayer = nil
                                if detailPanel.editorContent then
                                    for _, f in pairs(detailPanel.editorContent) do
                                        if f and f.Hide then f:Hide() end
                                    end
                                end
                                parent.RefreshPlayersList()
                                emptyMessage:Show()
                            end
                        end,
                        timeout = 0, whileDead = true, hideOnEscape = true
                    }
                    StaticPopup_Show("ONEWOW_NOTES_CONFIRM_DELETE_PLAYER")
                end
            end)
            deleteBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["TOOLTIP_PLAYER_DELETE"], 1, 1, 1)
                GameTooltip:AddLine(L["TOOLTIP_PLAYER_DELETE_DESC"], 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            deleteBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            editorHeader.deleteBtn = deleteBtn

            local propertiesBtn = ns.UI.CreateHeaderIconButton(editorHeader, {
                texture = "icon-gears.png",
                relativeTo = deleteBtn,
            })
            propertiesBtn:SetScript("OnClick", function()
                if selectedPlayer and ns.UI and ns.UI.ShowPlayerPropertiesDialog then
                    ns.UI.ShowPlayerPropertiesDialog(selectedPlayer, parent)
                end
            end)
            propertiesBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["DIALOG_PLAYER_PROPERTIES"], 1, 1, 1)
                GameTooltip:AddLine(L["TOOLTIP_PLAYER_PROPERTIES_DESC"], 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            propertiesBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            editorHeader.propertiesBtn = propertiesBtn

            local alertBtn = CreateFrame("CheckButton", nil, editorHeader)
            alertBtn:SetSize(22, 22)
            alertBtn:SetPoint("RIGHT", propertiesBtn, "LEFT", -2, 0)
            local aN = alertBtn:CreateTexture(nil, "BACKGROUND")
            aN:SetAllPoints()
            aN:SetTexture(MEDIA .. "icon-alert.png")
            aN:SetDesaturated(true)
            aN:SetAlpha(0.3)
            alertBtn:SetNormalTexture(aN)
            local aHL = alertBtn:CreateTexture(nil, "HIGHLIGHT")
            aHL:SetAllPoints()
            aHL:SetTexture(MEDIA .. "icon-alert.png")
            aHL:SetAlpha(0.5)
            alertBtn:SetHighlightTexture(aHL)
            alertBtn:SetScript("OnClick", function(self)
                if selectedPlayer and ns.Players then
                    local pd = ns.Players:GetPlayer(selectedPlayer)
                    if pd then
                        pd.soundEnabled = not pd.soundEnabled
                        aN:SetDesaturated(not pd.soundEnabled)
                        aN:SetAlpha(pd.soundEnabled and 1.0 or 0.3)
                        self:SetChecked(pd.soundEnabled)
                        ns.Players:SavePlayer(selectedPlayer, pd)
                        parent.RefreshPlayersList()
                    end
                end
            end)
            alertBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["TOOLTIP_PLAYER_SOUND"], 1, 1, 1)
                GameTooltip:AddLine(L["TOOLTIP_PLAYER_SOUND_DESC"], 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            alertBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            editorHeader.alertBtn = alertBtn

            local favoriteBtn = CreateFrame("CheckButton", nil, editorHeader)
            favoriteBtn:SetSize(22, 22)
            favoriteBtn:SetPoint("RIGHT", alertBtn, "LEFT", -2, 0)
            local fN = favoriteBtn:CreateTexture(nil, "BACKGROUND")
            fN:SetAllPoints()
            fN:SetTexture(MEDIA .. "icon-fav.png")
            fN:SetDesaturated(true)
            fN:SetAlpha(0.3)
            favoriteBtn:SetNormalTexture(fN)
            local fC = favoriteBtn:CreateTexture(nil, "BACKGROUND")
            fC:SetAllPoints()
            fC:SetTexture(MEDIA .. "icon-fav.png")
            favoriteBtn:SetCheckedTexture(fC)
            local fHL = favoriteBtn:CreateTexture(nil, "HIGHLIGHT")
            fHL:SetAllPoints()
            fHL:SetTexture(MEDIA .. "icon-fav.png")
            fHL:SetAlpha(0.5)
            favoriteBtn:SetHighlightTexture(fHL)
            favoriteBtn:SetScript("OnClick", function(self)
                if selectedPlayer and ns.Players then
                    local pd = ns.Players:GetPlayer(selectedPlayer)
                    if pd then
                        pd.favorite = not pd.favorite
                        fN:SetDesaturated(not pd.favorite)
                        fN:SetAlpha(pd.favorite and 1.0 or 0.3)
                        self:SetChecked(pd.favorite)
                        ns.Players:SavePlayer(selectedPlayer, pd)
                        parent.RefreshPlayersList()
                    end
                end
            end)
            favoriteBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["TOOLTIP_PLAYER_FAVORITE"], 1, 1, 1)
                GameTooltip:AddLine(L["TOOLTIP_PLAYER_FAVORITE_DESC"], 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            favoriteBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            editorHeader.favoriteBtn = favoriteBtn

            local body = ns.UI.CreateDetailBody(detailPanel, editorHeader, {
                onTextChanged = function(self, userInput)
                    if userInput and selectedPlayer and ns.Players then
                        local pd = ns.Players:GetPlayer(selectedPlayer)
                        if pd then pd.content = self:GetText() pd.modified = GetServerTime() end
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
            contentEditBox:SetScript("OnReceiveDrag", function(self)
                local cursorType, _, itemLink = GetCursorInfo()
                if cursorType == "item" and itemLink then self:Insert(itemLink) ClearCursor() end
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

            local tip = ns.UI.CreateTooltipLinesSection(detailPanel, contentBg, {
                onLineChanged = function(index, text, userInput)
                    if userInput and selectedPlayer and ns.Players then
                        local pd = ns.Players:GetPlayer(selectedPlayer)
                        if pd then
                            if not pd.tooltipLines then pd.tooltipLines = {"","","",""} end
                            pd.tooltipLines[index] = text
                        end
                    end
                end,
            })
            local tooltipSection = tip.section
            local tooltipEdits = tip.edits

            detailPanel.editorContent = {
                header         = editorHeader,
                contentBg      = contentBg,
                contentScroll  = contentScroll,
                tooltipSection = tooltipSection,
                tooltipEdits   = tooltipEdits,
            }
        end

        for _, f in pairs(detailPanel.editorContent) do
            if f and f.Show then f:Show() end
        end
        if detailPanel.contentEditBox then detailPanel.contentEditBox:Show() end
        ns.UI.activeContentEditBox = detailPanel.contentEditBox

        if selectedPlayer and ns.Players then
            local pd = ns.Players:GetPlayer(selectedPlayer)
            if pd then
                local pinColorKey = ns.Players:GetPinColorKey(pd.class)
                local colorConfig = ns.Config.PIN_COLORS[pinColorKey] or ns.Config.PIN_COLORS["hunter"]
                local listItemColor = colorConfig.listItem
                local borderColor   = colorConfig.border

                local header = detailPanel.editorContent.header
                header:SetBackdropColor(listItemColor[1], listItemColor[2], listItemColor[3], listItemColor[4] or 0.9)
                header:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], 1)

                if header.nameServerLine then
                    local nameText = (pd.name or "Unknown") .. "-" .. (pd.realm or "Unknown")
                    header.nameServerLine:SetText(nameText)
                    header.nameServerLine:SetTextColor(borderColor[1], borderColor[2], borderColor[3])
                end
                if header.levelClassRaceLine then
                    local txt = ""
                    if pd.level and pd.level > 0 then txt = "Level " .. pd.level .. " " end
                    txt = txt .. (pd.class or "") .. " " .. (pd.race or "")
                    header.levelClassRaceLine:SetText(txt)
                end
                if header.guildLine then
                    if pd.guild and pd.guild ~= "" then
                        header.guildLine:SetText("<" .. pd.guild .. ">")
                        header.guildLine:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
                    else
                        header.guildLine:SetText(L["UI_GUILD_NONE"])
                        header.guildLine:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                    end
                end
                if header.categoryLine then
                    header.categoryLine:SetText(string.format(L["UI_CATEGORY_WITH_VALUE"], pd.category or GENERAL))
                    header.categoryLine:SetTextColor(borderColor[1], borderColor[2], borderColor[3])
                end
                if header.professionsLine then
                    local parts = {}
                    if pd.profession1 then parts[#parts + 1] = pd.profession1 end
                    if pd.profession2 then parts[#parts + 1] = pd.profession2 end
                    if #parts > 0 then
                        local list = parts[1]
                        if parts[2] then list = list .. ", " .. parts[2] end
                        header.professionsLine:SetText(string.format(L["UI_PROFESSIONS_WITH_VALUE"], list))
                    else
                        header.professionsLine:SetText("")
                    end
                    header.professionsLine:SetTextColor(borderColor[1], borderColor[2], borderColor[3])
                end
                if header.alertBtn then
                    header.alertBtn:GetNormalTexture():SetDesaturated(not pd.soundEnabled)
                    header.alertBtn:GetNormalTexture():SetAlpha(pd.soundEnabled and 1.0 or 0.3)
                    header.alertBtn:SetChecked(pd.soundEnabled)
                end
                if header.favoriteBtn then
                    header.favoriteBtn:GetNormalTexture():SetDesaturated(not pd.favorite)
                    header.favoriteBtn:GetNormalTexture():SetAlpha(pd.favorite and 1.0 or 0.3)
                    header.favoriteBtn:SetChecked(pd.favorite)
                end
                if detailPanel.contentEditBox then
                    detailPanel.contentEditBox:SetText(pd.content or "")
                end
                if detailPanel.editorContent.tooltipEdits and pd.tooltipLines then
                    for i = 1, 4 do
                        if detailPanel.editorContent.tooltipEdits[i] then
                            detailPanel.editorContent.tooltipEdits[i]:SetText(pd.tooltipLines[i] or "")
                        end
                    end
                end
            end
        end
    end

    function parent.SelectPlayer(fullName)
        selectedPlayer = fullName
        ShowEditor()
        parent.RefreshPlayersList()
    end

    function parent.GetNavEntity()
        if selectedPlayer then
            return "player", selectedPlayer
        end
    end

    function parent.RestoreNavEntity(kind, id)
        if kind == "player" then
            parent.SelectPlayer(id)
        end
    end

    parent:HookScript("OnShow", function()
        if ns.pendingPlayerSelect then
            local name = ns.pendingPlayerSelect
            ns.pendingPlayerSelect = nil
            parent.SelectPlayer(name)
        end
    end)

    local function CreateSectionHeader(text, yPos, count)
        local section = OneWoW_GUI:CreateSectionHeader(scrollChild, {
            title = text,
            yOffset = yPos,
            rightText = ns.UI.FormatSectionCount(count),
        })
        table.insert(playerListItems, section)
        return section
    end

    function parent.RefreshPlayersList()
        if scrollChild then
            scrollChild._onewowZebraSeq = nil
        end
        for _, ctrl in pairs(sectionReorders) do
            ctrl:Cancel()
        end
        for _, item in pairs(playerListItems) do item:Hide() end
        playerListItems = {}
        wipe(sectionRowFrames)
        wipe(sectionDataBags)

        if not ns.Players then
            if leftStatusText then leftStatusText:SetText(string.format(L["UI_COUNT_FORMAT"], L["TAB_PLAYERS"], 0)) end
            return
        end

        RefreshCatOpts()
        RefreshStorageOpts()

        local allPlayers = ns.Players:GetAllPlayers()
        local playersList = {}

        for fullName, pd in pairs(allPlayers) do
            if type(pd) == "table" then
                local matches = true
                if categoryFilter ~= "All" and pd.category ~= categoryFilter then matches = false end
                if storageFilter  ~= "All" and pd.storage  ~= storageFilter  then matches = false end
                if searchFilter ~= "" then
                    local nameLower = (pd.name or fullName):lower()
                    if not nameLower:find(searchFilter:lower(), 1, true) then matches = false end
                end
                if matches then
                    table.insert(playersList, {fullName = fullName, data = pd})
                end
            end
        end

        local favorites  = {}
        local regular    = {}
        for _, p in ipairs(playersList) do
            if p.data.favorite then
                table.insert(favorites, p)
            else
                table.insert(regular, p)
            end
        end

        local function sortPlayers(a, b)
            local nameA = a.data.name or a.id or ""
            local nameB = b.data.name or b.id or ""
            if currentSort.by == "class" then
                local ca = a.data.class or ""
                local cb = b.data.class or ""
                if ca == cb then return nameA < nameB end
                if currentSort.ascending then return ca < cb else return ca > cb end
            elseif currentSort.by == "faction" then
                local fa = a.data.faction or ""
                local fb = b.data.faction or ""
                if fa == fb then return nameA < nameB end
                if currentSort.ascending then return fa < fb else return fa > fb end
            elseif currentSort.by == "level" then
                local la = a.data.level or 0
                local lb = b.data.level or 0
                if la == lb then return nameA < nameB end
                if currentSort.ascending then return la < lb else return la > lb end
            elseif currentSort.by == "category" then
                local ca = a.data.category or ""
                local cb = b.data.category or ""
                if ca == cb then return nameA < nameB end
                if currentSort.ascending then return ca < cb else return ca > cb end
            elseif currentSort.by == "modified" then
                if currentSort.ascending then return (a.data.modified or 0) < (b.data.modified or 0)
                else return (a.data.modified or 0) > (b.data.modified or 0) end
            elseif currentSort.by == "custom" then
                local sa = a.data.sortOrder or 0
                local sb = b.data.sortOrder or 0
                if sa == sb then return nameA < nameB end
                if currentSort.ascending then return sa < sb else return sa > sb end
            else
                if currentSort.ascending then return nameA < nameB else return nameA > nameB end
            end
        end
        table.sort(favorites,  sortPlayers)
        table.sort(regular,    sortPlayers)

        local function BuildPlayerRow(player, yOffset, sectionKey)
            local classFile = player.data.class
            local barColor
            if classFile and RAID_CLASS_COLORS[classFile] then
                local c = RAID_CLASS_COLORS[classFile]
                barColor = { c.r * 0.7, c.g * 0.7, c.b * 0.7 }
            end
            local classAtlas
            if classFile and classFile ~= "" then
                classAtlas = "classicon-" .. classFile:lower()
            end

            local detail = ""
            if player.data.realm and player.data.realm ~= "" then detail = player.data.realm .. " " end
            if player.data.class and player.data.class ~= "" then detail = detail .. player.data.class end

            local rowOpts = {
                yOffset     = yOffset,
                barColor    = barColor,
                iconAtlas   = classAtlas,
                icon        = "Interface\\Icons\\INV_Misc_QuestionMark",
                title       = player.data.name or player.fullName,
                detail      = detail,
                storageText = player.data.storage == "character" and CHARACTER or L["UI_STORAGE_ACCOUNT"],
                selected    = (selectedPlayer == player.fullName),
                shouldSuppressSelect = IsAnyPlayersReorderActive,
                onSelect    = function()
                    selectedPlayer = player.fullName
                    ShowEditor()
                    parent.RefreshPlayersList()
                end,
                alert = {
                    active  = player.data.soundEnabled and true or false,
                    tooltip = { title = L["TOOLTIP_PLAYER_SOUND"], desc = L["TOOLTIP_PLAYER_SOUND_DESC"] },
                    onToggle = function(state)
                        if not ns.Players then return end
                        local pd = ns.Players:GetPlayer(player.fullName)
                        if not pd then return end
                        pd.soundEnabled = state
                        ns.Players:SavePlayer(player.fullName, pd)
                        if selectedPlayer == player.fullName and detailPanel.editorContent and detailPanel.editorContent.header then
                            local h = detailPanel.editorContent.header
                            if h.alertBtn then
                                h.alertBtn:GetNormalTexture():SetDesaturated(not state)
                                h.alertBtn:GetNormalTexture():SetAlpha(state and 1.0 or 0.3)
                                h.alertBtn:SetChecked(state)
                            end
                        end
                    end,
                },
                fav = {
                    active  = player.data.favorite and true or false,
                    tooltip = { title = L["TOOLTIP_PLAYER_FAVORITE"], desc = L["TOOLTIP_PLAYER_FAVORITE_DESC"] },
                    onToggle = function(state)
                        if not ns.Players then return end
                        local pd = ns.Players:GetPlayer(player.fullName)
                        if pd then
                            pd.favorite = state
                            ns.Players:SavePlayer(player.fullName, pd)
                            parent.RefreshPlayersList()
                        end
                    end,
                },
                props = {
                    tooltip = { title = L["TOOLTIP_PLAYER_PROPERTIES_DESC"] },
                    onClick = function()
                        if ns.UI.ShowPlayerPropertiesDialog then ns.UI.ShowPlayerPropertiesDialog(player.fullName, parent) end
                    end,
                },
                delete = {
                    tooltip = { title = L["TOOLTIP_PLAYER_DELETE"], desc = L["TOOLTIP_PLAYER_DELETE_DESC"] },
                    onClick = function()
                        StaticPopupDialogs["ONEWOW_NOTES_CONFIRM_DELETE_PLAYER"] = {
                            text = string.format(L["POPUP_DELETE_PLAYER"]),
                            button1 = DELETE, button2 = CANCEL,
                            OnAccept = function()
                                if ns.Players then
                                    ns.Players:RemovePlayer(player.fullName)
                                    if selectedPlayer == player.fullName then
                                        selectedPlayer = nil
                                        emptyMessage:Show()
                                        if detailPanel.editorContent then
                                            for _, f in pairs(detailPanel.editorContent) do
                                                if f and f.Hide then f:Hide() end
                                            end
                                        end
                                    end
                                    parent.RefreshPlayersList()
                                end
                            end,
                            timeout = 0, whileDead = true, hideOnEscape = true,
                        }
                        StaticPopup_Show("ONEWOW_NOTES_CONFIRM_DELETE_PLAYER")
                    end,
                },
            }

            local row = ns.UI.CreateNotesListRow(scrollChild, rowOpts)
            table.insert(playerListItems, row)
            local frames = sectionRowFrames[sectionKey]
            frames[#frames + 1] = row
            GetOrCreateSectionReorder(sectionKey):Attach(row, #frames)
        end

        local function PaintSection(sectionKey, title, bag, yOffset)
            if #bag == 0 then
                return yOffset
            end
            sectionDataBags[sectionKey] = bag
            sectionRowFrames[sectionKey] = {}
            CreateSectionHeader(title, yOffset, #bag)
            yOffset = yOffset - 30
            for _, player in ipairs(bag) do
                BuildPlayerRow(player, yOffset, sectionKey)
                yOffset = yOffset - ns.UI.LIST_ROW_SPACING
            end
            return yOffset
        end

        local yOffset = 0
        yOffset = PaintSection("favorites", FAVORITES, favorites, yOffset)
        yOffset = PaintSection("regular", L["TAB_PLAYERS"], regular, yOffset)

        scrollChild:SetHeight(math.abs(yOffset) + 50)
        if leftStatusText then
            leftStatusText:SetText(string.format(L["UI_COUNT_FORMAT"], L["TAB_PLAYERS"], #favorites + #regular))
        end
    end

    parent.RefreshPlayersList()
end

local PLAYER_RACES = {
    "Human", "Orc", "Dwarf", "Night Elf", "Undead", "Tauren", "Gnome", "Troll",
    "Goblin", "Blood Elf", "Draenei", "Worgen", "Pandaren", "Nightborne",
    "Highmountain Tauren", "Void Elf", "Lightforged Draenei", "Zandalari Troll",
    "Kul Tiran", "Dark Iron Dwarf", "Vulpera", "Mechagnome", "Dracthyr", "Earthen"
}

local PLAYER_CLASSES = {
    "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT",
    "SHAMAN", "MAGE", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER"
}

local CLASS_DISPLAY_NAMES = {
    WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue",
    PRIEST = "Priest", DEATHKNIGHT = "Death Knight", SHAMAN = "Shaman", MAGE = "Mage",
    WARLOCK = "Warlock", MONK = "Monk", DRUID = "Druid", DEMONHUNTER = "Demon Hunter",
    EVOKER = "Evoker"
}

local PLAYER_PROFESSIONS = {
    "None", "Alchemy", "Blacksmithing", "Enchanting", "Engineering",
    "Herbalism", "Inscription", "Jewelcrafting", "Leatherworking",
    "Mining", "Skinning", "Tailoring",
}

local function MakeDialogLabel(parentFrame, text, x, y)
    local lbl = OneWoW_GUI:CreateFS(parentFrame, 12)
    lbl:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", x, y)
    lbl:SetText(text)
    lbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    return lbl
end

local function MakeDialogInput(parentFrame, x, y, w)
    local input = OneWoW_GUI:CreateEditBox(parentFrame, {
        width = w,
        height = 26,
    })
    input:ClearAllPoints()
    input:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", x, y)
    input:SetAutoFocus(false)
    input:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return input
end

function ns.UI.ShowManualPlayerEntryDialog(refreshParent)
    local COL1_X = 10
    local COL2_X = 300
    local COL_W  = 260
    local ROW_H  = 50
    local LBL_GAP = 18

    local dialog = ns.UI.CreateThemedDialog({
        name           = "OneWoW_NotesManualPlayerEntry",
        title          = L["PLAYER_MANUAL_ENTRY_TITLE"],
        width          = 580,
        height         = 580,
        destroyOnClose = true,
        buttons = {
            {
                text = L["BUTTON_ADD_NOTE"],
                onClick = function(dlg)
                    local name  = dlg._nameInput  and dlg._nameInput:GetText()  or ""
                    local realm = dlg._realmInput and dlg._realmInput:GetText() or ""
                    if name == "" then
                        print("|cFFFFD100OneWoW - Players:|r " .. (L["PLAYER_ERROR_NAME_REQUIRED"]))
                        return
                    end
                    if realm == "" then realm = GetRealmName() or "Unknown" end
                    local fullName = name .. "-" .. realm

                    if ns.Players and ns.Players:GetPlayer(fullName) then
                        print("|cFFFFD100OneWoW - Players:|r " .. (L["MSG_PLAYER_EXISTS"]))
                        return
                    end

                    local levelText = dlg._levelInput and dlg._levelInput:GetText() or "1"
                    local level = tonumber(levelText) or 1
                    local guild = dlg._guildInput and dlg._guildInput:GetText() or ""
                    local race  = dlg._raceDD  and dlg._raceDD:GetValue()  or ""
                    local class = dlg._classDD and dlg._classDD:GetValue() or ""
                    local cat   = dlg._catDD   and dlg._catDD:GetValue()   or "General"
                    local store = dlg._storeDD and dlg._storeDD:GetValue() or "account"
                    local prof1 = dlg._prof1DD and dlg._prof1DD:GetValue() or "None"
                    local prof2 = dlg._prof2DD and dlg._prof2DD:GetValue() or "None"
                    local noteContent = dlg._noteEditBox and dlg._noteEditBox:GetText() or ""

                    if ns.Players then
                        ns.Players:AddPlayer(fullName, {
                            name = name, realm = realm, fullName = fullName,
                            level = level, guild = guild, race = race, class = class,
                            category = cat, storage = store,
                            profession1 = prof1 ~= "None" and prof1 or nil,
                            profession2 = prof2 ~= "None" and prof2 or nil,
                            content = noteContent,
                        })
                        dlg:Hide()
                        if refreshParent and refreshParent.RefreshPlayersList then
                            refreshParent.RefreshPlayersList()
                        end
                        if refreshParent and refreshParent.SelectPlayer then
                            refreshParent.SelectPlayer(fullName)
                        end
                    end
                end,
            },
            { text = CANCEL, onClick = function(dlg) dlg:Hide() end },
        },
    })

    if dialog.built then dialog:Show() return end
    dialog.built = true

    local content = dialog.content
    local yPos = -10

    MakeDialogLabel(content, L["LABEL_NAME"], COL1_X, yPos)
    dialog._nameInput = MakeDialogInput(content, COL1_X, yPos - LBL_GAP, COL_W)
    dialog._nameInput:SetAutoFocus(true)

    MakeDialogLabel(content, L["PLAYER_LABEL_LEVEL"], COL2_X, yPos)
    dialog._levelInput = MakeDialogInput(content, COL2_X, yPos - LBL_GAP, COL_W)
    dialog._levelInput:SetNumeric(true)
    dialog._levelInput:SetText("1")
    yPos = yPos - ROW_H

    MakeDialogLabel(content, L["LABEL_SERVER"], COL1_X, yPos)
    dialog._realmInput = MakeDialogInput(content, COL1_X, yPos - LBL_GAP, COL_W)
    dialog._realmInput:SetText(GetRealmName() or "")

    MakeDialogLabel(content, L["GUILD"], COL2_X, yPos)
    dialog._guildInput = MakeDialogInput(content, COL2_X, yPos - LBL_GAP, COL_W)
    yPos = yPos - ROW_H

    MakeDialogLabel(content, L["RACE"], COL1_X, yPos)
    local raceDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    raceDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos - LBL_GAP)
    local raceOpts = {{text = "", value = ""}}
    for _, r in ipairs(PLAYER_RACES) do
        raceOpts[#raceOpts + 1] = {text = r, value = r}
    end
    raceDD:SetOptions(raceOpts)
    raceDD:SetSelected("")
    dialog._raceDD = raceDD

    MakeDialogLabel(content, L["PLAYER_LABEL_CLASS"], COL2_X, yPos)
    local classDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    classDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL2_X, yPos - LBL_GAP)
    local classOpts = {{text = "", value = ""}}
    for _, c in ipairs(PLAYER_CLASSES) do
        classOpts[#classOpts + 1] = {text = CLASS_DISPLAY_NAMES[c] or c, value = c}
    end
    classDD:SetOptions(classOpts)
    classDD:SetSelected("")
    dialog._classDD = classDD
    yPos = yPos - ROW_H

    MakeDialogLabel(content, CATEGORY, COL1_X, yPos)
    local catDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    catDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos - LBL_GAP)
    local catOpts = {}
    if ns.Players then
        for _, c in ipairs(ns.Players:GetCategories()) do
            catOpts[#catOpts + 1] = {text = c, value = c}
        end
    end
    catDD:SetOptions(catOpts)
    catDD:SetSelected("General")
    dialog._catDD = catDD

    MakeDialogLabel(content, L["LABEL_STORAGE"], COL2_X, yPos)
    local storeDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    storeDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL2_X, yPos - LBL_GAP)
    storeDD:SetOptions({
        {text = L["UI_STORAGE_ACCOUNT"],   value = "account"},
        {text = CHARACTER, value = "character"},
    })
    storeDD:SetSelected("account")
    dialog._storeDD = storeDD
    yPos = yPos - ROW_H

    MakeDialogLabel(content, L["LABEL_PROFESSION_1"], COL1_X, yPos)
    local prof1DD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    prof1DD:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos - LBL_GAP)
    local profOpts = {}
    for _, p in ipairs(PLAYER_PROFESSIONS) do
        profOpts[#profOpts + 1] = {text = p, value = p}
    end
    prof1DD:SetOptions(profOpts)
    prof1DD:SetSelected("None")
    dialog._prof1DD = prof1DD

    MakeDialogLabel(content, L["LABEL_PROFESSION_2"], COL2_X, yPos)
    local prof2DD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    prof2DD:SetPoint("TOPLEFT", content, "TOPLEFT", COL2_X, yPos - LBL_GAP)
    prof2DD:SetOptions(profOpts)
    prof2DD:SetSelected("None")
    dialog._prof2DD = prof2DD
    yPos = yPos - ROW_H

    MakeDialogLabel(content, L["LABEL_NOTE_CONTENT"], COL1_X, yPos)
    yPos = yPos - LBL_GAP

    local noteBg = ns.UI.CreateThemedBar(nil, content)
    noteBg:SetPoint("TOPLEFT",     content, "TOPLEFT",     COL1_X, yPos)
    noteBg:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -COL1_X, 6)

    local noteScroll, noteEditBox = OneWoW_GUI:CreateScrollEditBox(noteBg, {})
    noteScroll:ClearAllPoints()
    noteScroll:SetPoint("TOPLEFT",     noteBg, "TOPLEFT",     4, -4)
    noteScroll:SetPoint("BOTTOMRIGHT", noteBg, "BOTTOMRIGHT", -26, 4)
    dialog._noteEditBox = noteEditBox

    dialog:Show()
end

function ns.UI.ShowPlayerPropertiesDialog(fullName, refreshParent)
    if not fullName or not ns.Players then return end
    local pd = ns.Players:GetPlayer(fullName)
    if not pd then return end

    local COL1_X = 10
    local COL2_X = 300
    local COL_W  = 260
    local ROW_H  = 50
    local LBL_GAP = 18

    local dialog = ns.UI.CreateThemedDialog({
        name           = "OneWoW_NotesPlayerProperties",
        title          = (L["DIALOG_PLAYER_PROPERTIES"]) .. ": " .. (pd.name or fullName),
        width          = 580,
        height         = 580,
        destroyOnClose = true,
        buttons = {
            { text = CLOSE, onClick = function(dlg) dlg:Hide() end },
        },
    })

    if dialog.built then dialog:Show() return end
    dialog.built = true

    local content = dialog.content
    local yPos = -10

    local function SaveField(field, value)
        local d = ns.Players:GetPlayer(fullName)
        if d then
            d[field] = value
            ns.Players:SavePlayer(fullName, d)
        end
        -- Refresh list + detail header (category, professions, etc.)
        if refreshParent and refreshParent.SelectPlayer then
            refreshParent.SelectPlayer(fullName)
        elseif refreshParent and refreshParent.RefreshPlayersList then
            refreshParent.RefreshPlayersList()
        end
    end

    MakeDialogLabel(content, L["LABEL_NAME"], COL1_X, yPos)
    local nameInput = MakeDialogInput(content, COL1_X, yPos - LBL_GAP, COL_W)
    nameInput:SetText(pd.name or "")
    nameInput:SetScript("OnEnterPressed", function(self)
        local newName = self:GetText()
        if newName ~= "" then
            local d = ns.Players:GetPlayer(fullName)
            if d then d.name = newName ns.Players:SavePlayer(fullName, d) end
            if refreshParent and refreshParent.RefreshPlayersList then refreshParent.RefreshPlayersList() end
        end
        self:ClearFocus()
    end)

    MakeDialogLabel(content, L["PLAYER_LABEL_LEVEL"], COL2_X, yPos)
    local levelInput = MakeDialogInput(content, COL2_X, yPos - LBL_GAP, COL_W)
    levelInput:SetNumeric(true)
    levelInput:SetText(tostring(pd.level or 0))
    levelInput:SetScript("OnEnterPressed", function(self)
        SaveField("level", tonumber(self:GetText()) or 0)
        self:ClearFocus()
    end)
    yPos = yPos - ROW_H

    MakeDialogLabel(content, L["LABEL_SERVER"], COL1_X, yPos)
    local realmInput = MakeDialogInput(content, COL1_X, yPos - LBL_GAP, COL_W)
    realmInput:SetText(pd.realm or "")
    realmInput:SetScript("OnEnterPressed", function(self)
        SaveField("realm", self:GetText())
        self:ClearFocus()
    end)

    MakeDialogLabel(content, L["GUILD"], COL2_X, yPos)
    local guildInput = MakeDialogInput(content, COL2_X, yPos - LBL_GAP, COL_W)
    guildInput:SetText(pd.guild or "")
    guildInput:SetScript("OnEnterPressed", function(self)
        SaveField("guild", self:GetText())
        self:ClearFocus()
    end)
    yPos = yPos - ROW_H

    MakeDialogLabel(content, L["RACE"], COL1_X, yPos)
    local raceDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    raceDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos - LBL_GAP)
    local raceOpts = {{text = "", value = ""}}
    for _, r in ipairs(PLAYER_RACES) do
        raceOpts[#raceOpts + 1] = {text = r, value = r}
    end
    raceDD:SetOptions(raceOpts)
    raceDD:SetSelected(pd.race or "")
    raceDD.onSelect = function(value) SaveField("race", value) end

    MakeDialogLabel(content, L["PLAYER_LABEL_CLASS"], COL2_X, yPos)
    local classDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    classDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL2_X, yPos - LBL_GAP)
    local classOpts = {{text = "", value = ""}}
    for _, c in ipairs(PLAYER_CLASSES) do
        classOpts[#classOpts + 1] = {text = CLASS_DISPLAY_NAMES[c] or c, value = c}
    end
    classDD:SetOptions(classOpts)
    classDD:SetSelected(pd.class or "")
    classDD.onSelect = function(value) SaveField("class", value) end
    yPos = yPos - ROW_H

    MakeDialogLabel(content, CATEGORY, COL1_X, yPos)
    local catDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    catDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos - LBL_GAP)
    local catOpts = {}
    if ns.Players then
        for _, c in ipairs(ns.Players:GetCategories()) do
            catOpts[#catOpts + 1] = {text = c, value = c}
        end
    end
    catDD:SetOptions(catOpts)
    catDD:SetSelected(pd.category or "General")
    catDD.onSelect = function(value) SaveField("category", value) end

    MakeDialogLabel(content, L["LABEL_STORAGE"], COL2_X, yPos)
    local storeDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    storeDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL2_X, yPos - LBL_GAP)
    storeDD:SetOptions({
        {text = L["UI_STORAGE_ACCOUNT"],   value = "account"},
        {text = CHARACTER, value = "character"},
    })
    storeDD:SetSelected(pd.storage or "account")
    storeDD.onSelect = function(value)
        local d = ns.Players:GetPlayer(fullName)
        if d then
            local oldDB = ns.Players:GetNotesDB(d.storage or "account")
            if oldDB then oldDB[fullName] = nil end
            d.storage = value
            ns.Players:SavePlayer(fullName, d)
        end
        if refreshParent and refreshParent.RefreshPlayersList then refreshParent.RefreshPlayersList() end
    end
    yPos = yPos - ROW_H

    MakeDialogLabel(content, L["LABEL_PROFESSION_1"], COL1_X, yPos)
    local prof1DD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    prof1DD:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos - LBL_GAP)
    local profOpts = {}
    for _, p in ipairs(PLAYER_PROFESSIONS) do
        profOpts[#profOpts + 1] = {text = p, value = p}
    end
    prof1DD:SetOptions(profOpts)
    prof1DD:SetSelected(pd.profession1 or "None")
    prof1DD.onSelect = function(value)
        SaveField("profession1", value ~= "None" and value or nil)
    end

    MakeDialogLabel(content, L["LABEL_PROFESSION_2"], COL2_X, yPos)
    local prof2DD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    prof2DD:SetPoint("TOPLEFT", content, "TOPLEFT", COL2_X, yPos - LBL_GAP)
    prof2DD:SetOptions(profOpts)
    prof2DD:SetSelected(pd.profession2 or "None")
    prof2DD.onSelect = function(value)
        SaveField("profession2", value ~= "None" and value or nil)
    end
    yPos = yPos - ROW_H

    local alertCB = OneWoW_GUI:CreateCheckbox(content, { label = L["TOOLTIP_PLAYER_SOUND"] })
    alertCB:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos)
    alertCB:SetChecked(pd.soundEnabled or false)
    alertCB:SetScript("OnClick", function(self)
        SaveField("soundEnabled", self:GetChecked())
    end)
    alertCB:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["TOOLTIP_PLAYER_SOUND"], 1, 1, 1)
        GameTooltip:AddLine(L["TOOLTIP_PLAYER_SOUND_DESC"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    alertCB:SetScript("OnLeave", function() GameTooltip:Hide() end)
    yPos = yPos - 30

    MakeDialogLabel(content, L["LABEL_NOTE_PREVIEW"], COL1_X, yPos)
    yPos = yPos - LBL_GAP

    local noteBg = ns.UI.CreateThemedBar(nil, content)
    noteBg:SetPoint("TOPLEFT",     content, "TOPLEFT",     COL1_X, yPos)
    noteBg:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -COL1_X, 6)

    local noteScroll, noteEditBox = OneWoW_GUI:CreateScrollEditBox(noteBg, {})
    noteScroll:ClearAllPoints()
    noteScroll:SetPoint("TOPLEFT",     noteBg, "TOPLEFT",     4, -4)
    noteScroll:SetPoint("BOTTOMRIGHT", noteBg, "BOTTOMRIGHT", -26, 4)
    noteEditBox:SetText(pd.content or "")
    noteEditBox:EnableMouse(false)

    dialog:Show()
end

function ns.UI.ShowAddAltsDialog(refreshParent)
    if not OneWoW_AltTracker_Character_API then
        print("|cFFFFD100OneWoW - Players:|r " .. (L["PLAYER_ALTS_NO_DATA"]))
        return
    end

    local altsToAdd = {}
    for charKey, charData in pairs(OneWoW_AltTracker_Character_API.GetAllCharacters()) do
        if type(charData) == "table" then
            local name  = charData.name
            local realm = charData.realm
            if not name and charKey:find("-") then
                name, realm = strsplit("-", charKey)
            end
            if name and realm then
                local fullName = name .. "-" .. realm
                if not ns.Players:GetPlayer(fullName) then
                    local guildName = ""
                    if type(charData.guild) == "table" then
                        guildName = charData.guild.name or ""
                    elseif type(charData.guild) == "string" then
                        guildName = charData.guild
                    end

                    table.insert(altsToAdd, {
                        fullName    = fullName,
                        name        = name,
                        realm       = realm,
                        level       = charData.level or 0,
                        class       = charData.class or "",
                        className   = charData.className or (CLASS_DISPLAY_NAMES[charData.class] or charData.class or ""),
                        race        = charData.race or "",
                        raceName    = charData.raceName or charData.race or "",
                        guild       = guildName,
                        faction     = charData.faction or "",
                        checked     = false,
                    })
                end
            end
        end
    end

    if #altsToAdd == 0 then
        print("|cFFFFD100OneWoW - Players:|r " .. (L["PLAYER_ALTS_NONE_NEW"]))
        return
    end

    table.sort(altsToAdd, function(a, b) return a.name < b.name end)

    local dialog = ns.UI.CreateThemedDialog({
        name           = "OneWoW_NotesAddAlts",
        title          = L["PLAYER_ADD_ALTS"],
        width          = 520,
        height         = 480,
        destroyOnClose = true,
        buttons = {
            {
                text = L["PLAYER_ADD_SELECTED"],
                onClick = function(dlg)
                    local count = 0
                    for _, alt in ipairs(altsToAdd) do
                        if alt.checked then
                            ns.Players:AddPlayer(alt.fullName, {
                                name = alt.name, realm = alt.realm, fullName = alt.fullName,
                                level = alt.level, class = alt.class, race = alt.race,
                                guild = alt.guild, faction = alt.faction,
                                category = "General", storage = "account",
                            })
                            count = count + 1
                        end
                    end
                    if count > 0 then
                        if refreshParent and refreshParent.RefreshPlayersList then
                            refreshParent.RefreshPlayersList()
                        end
                    end
                    dlg:Hide()
                end,
            },
            { text = CANCEL, onClick = function(dlg) dlg:Hide() end },
        },
    })

    if dialog.built then dialog:Show() return end
    dialog.built = true

    local content = dialog.content
    local allCheckboxes = {}

    local selectAllBtn = OneWoW_GUI:CreateButton(content, { text = L["BUTTON_SELECT_ALL"], width = 100, height = 25 })
    selectAllBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 8, -8)
    selectAllBtn:SetScript("OnClick", function()
        for _, entry in ipairs(altsToAdd) do entry.checked = true end
        for _, cb in ipairs(allCheckboxes) do cb:SetChecked(true) end
    end)

    local deselectAllBtn = OneWoW_GUI:CreateButton(content, { text = L["BUTTON_DESELECT_ALL"], width = 100, height = 25 })
    deselectAllBtn:SetPoint("LEFT", selectAllBtn, "RIGHT", 6, 0)
    deselectAllBtn:SetScript("OnClick", function()
        for _, entry in ipairs(altsToAdd) do entry.checked = false end
        for _, cb in ipairs(allCheckboxes) do cb:SetChecked(false) end
    end)

    local scroll = ns.UI.CreateCustomScroll(content)
    scroll.container:SetPoint("TOPLEFT", content, "TOPLEFT", 8, -40)
    scroll.container:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -8, 4)

    local ROW_H = 28
    local yPos = 0

    for _, alt in ipairs(altsToAdd) do
        local row = CreateFrame("Frame", nil, scroll.scrollChild, "BackdropTemplate")
        row:SetPoint("TOPLEFT", scroll.scrollChild, "TOPLEFT", 0, -yPos)
        row:SetPoint("TOPRIGHT", scroll.scrollChild, "TOPRIGHT", 0, -yPos)
        row:SetHeight(ROW_H)
        row:SetBackdrop(BACKDROP_SIMPLE)
        row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))

        local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        cb:SetSize(20, 20)
        cb:SetPoint("LEFT", row, "LEFT", 4, 0)
        cb:SetScript("OnClick", function(self) alt.checked = self:GetChecked() end)
        allCheckboxes[#allCheckboxes + 1] = cb

        local nameFS = OneWoW_GUI:CreateFS(row, 12)
        nameFS:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        nameFS:SetText(alt.name)
        nameFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local infoFS = OneWoW_GUI:CreateFS(row, 10)
        infoFS:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        local infoText = ""
        if alt.level and alt.level > 0 then infoText = "Lv" .. alt.level .. " " end
        if alt.className and alt.className ~= "" then
            infoText = infoText .. alt.className
        elseif alt.class and alt.class ~= "" then
            infoText = infoText .. (CLASS_DISPLAY_NAMES[alt.class] or alt.class)
        end
        if alt.realm and alt.realm ~= "" then infoText = infoText .. " - " .. alt.realm end
        infoFS:SetText(infoText)
        infoFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        row:EnableMouse(true)
        row:SetScript("OnMouseDown", function()
            alt.checked = not alt.checked
            cb:SetChecked(alt.checked)
        end)

        yPos = yPos + ROW_H + 2
    end

    scroll.scrollChild:SetHeight(math.max(1, yPos))
    scroll.UpdateThumb()
    dialog:Show()
end

function ns.UI.ShowAddGuildDialog(refreshParent)
    if not IsInGuild() then
        print("|cFFFFD100OneWoW - Players:|r " .. (L["PLAYER_GUILD_NOT_IN"]))
        return
    end

    local guildMembers = {}
    local numTotal = GetNumGuildMembers()
    for i = 1, numTotal do
        local name, rankName, _, level, _, _, _, _, isOnline, _, classFile = GetGuildRosterInfo(i)
        if name then
            local charName, realm = strsplit("-", name)
            if not realm or realm == "" then realm = GetRealmName() or "Unknown" end
            local fullName = charName .. "-" .. realm
            if not ns.Players:GetPlayer(fullName) then
                table.insert(guildMembers, {
                    fullName  = fullName,
                    name      = charName,
                    realm     = realm,
                    level     = level or 0,
                    class     = classFile or "",
                    rank      = rankName or "",
                    isOnline  = isOnline,
                    checked   = false,
                })
            end
        end
    end

    if #guildMembers == 0 then
        print("|cFFFFD100OneWoW - Players:|r " .. (L["PLAYER_GUILD_NONE_NEW"]))
        return
    end

    table.sort(guildMembers, function(a, b) return a.name < b.name end)

    local dialog = ns.UI.CreateThemedDialog({
        name           = "OneWoW_NotesAddGuild",
        title          = L["PLAYER_ADD_GUILD_TITLE"],
        width          = 520,
        height         = 480,
        destroyOnClose = true,
        buttons = {
            {
                text = L["PLAYER_ADD_SELECTED"],
                onClick = function(dlg)
                    local count = 0
                    for _, member in ipairs(guildMembers) do
                        if member.checked then
                            ns.Players:AddPlayer(member.fullName, {
                                name = member.name, realm = member.realm, fullName = member.fullName,
                                level = member.level, class = member.class,
                                guild = GetGuildInfo("player") or "",
                                category = "Guild Member", storage = "account",
                            })
                            count = count + 1
                        end
                    end
                    if count > 0 then
                        if refreshParent and refreshParent.RefreshPlayersList then
                            refreshParent.RefreshPlayersList()
                        end
                    end
                    dlg:Hide()
                end,
            },
            { text = CANCEL, onClick = function(dlg) dlg:Hide() end },
        },
    })

    if dialog.built then dialog:Show() return end
    dialog.built = true

    local content = dialog.content
    local allCheckboxes = {}

    local selectAllBtn = OneWoW_GUI:CreateButton(content, { text = L["BUTTON_SELECT_ALL"], width = 100, height = 25 })
    selectAllBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 8, -8)
    selectAllBtn:SetScript("OnClick", function()
        for _, entry in ipairs(guildMembers) do entry.checked = true end
        for _, cb in ipairs(allCheckboxes) do cb:SetChecked(true) end
    end)

    local deselectAllBtn = OneWoW_GUI:CreateButton(content, { text = L["BUTTON_DESELECT_ALL"], width = 100, height = 25 })
    deselectAllBtn:SetPoint("LEFT", selectAllBtn, "RIGHT", 6, 0)
    deselectAllBtn:SetScript("OnClick", function()
        for _, entry in ipairs(guildMembers) do entry.checked = false end
        for _, cb in ipairs(allCheckboxes) do cb:SetChecked(false) end
    end)

    local scroll = ns.UI.CreateCustomScroll(content)
    scroll.container:SetPoint("TOPLEFT", content, "TOPLEFT", 8, -40)
    scroll.container:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -8, 4)

    local ROW_H = 28
    local yPos = 0

    for _, member in ipairs(guildMembers) do
        local row = CreateFrame("Frame", nil, scroll.scrollChild, "BackdropTemplate")
        row:SetPoint("TOPLEFT", scroll.scrollChild, "TOPLEFT", 0, -yPos)
        row:SetPoint("TOPRIGHT", scroll.scrollChild, "TOPRIGHT", 0, -yPos)
        row:SetHeight(ROW_H)
        row:SetBackdrop(BACKDROP_SIMPLE)
        row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))

        local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        cb:SetSize(20, 20)
        cb:SetPoint("LEFT", row, "LEFT", 4, 0)
        cb:SetScript("OnClick", function(self) member.checked = self:GetChecked() end)
        allCheckboxes[#allCheckboxes + 1] = cb

        local nameFS = OneWoW_GUI:CreateFS(row, 12)
        nameFS:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        nameFS:SetText(member.name)
        if member.isOnline then
            nameFS:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        else
            nameFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end

        local rankFS = OneWoW_GUI:CreateFS(row, 10)
        rankFS:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        local infoText = ""
        if member.level and member.level > 0 then infoText = "Lv" .. member.level .. " " end
        if member.class and member.class ~= "" then infoText = infoText .. (CLASS_DISPLAY_NAMES[member.class] or member.class) .. " " end
        if member.rank and member.rank ~= "" then infoText = infoText .. "(" .. member.rank .. ")" end
        rankFS:SetText(infoText)
        rankFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        row:EnableMouse(true)
        row:SetScript("OnMouseDown", function()
            member.checked = not member.checked
            cb:SetChecked(member.checked)
        end)

        yPos = yPos + ROW_H + 2
    end

    scroll.scrollChild:SetHeight(math.max(1, yPos))
    scroll.UpdateThumb()
    dialog:Show()
end
