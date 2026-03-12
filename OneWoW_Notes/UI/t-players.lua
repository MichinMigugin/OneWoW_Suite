-- OneWoW_Notes Addon File
-- OneWoW_Notes/UI/t-players.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...
local L = ns.L
local T = ns.T

ns.UI = ns.UI or {}

local lib = LibStub("OneWoW_GUI-1.0", true)

local selectedPlayer  = nil
local playerListItems = {}
local categoryFilter  = "All"
local storageFilter   = "All"

local detailPanel    = nil
local emptyMessage   = nil
local leftStatusText = nil
local scrollFrame    = nil
local scrollChild    = nil

local MEDIA = "Interface\\AddOns\\OneWoW_Notes\\Media\\"

local BACKDROP_STANDARD = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    tile = true, tileSize = 16, edgeSize = 1,
}

local function CreateThemedPanel(name, parentFrame)
    local f = CreateFrame("Frame", name, parentFrame, "BackdropTemplate")
    f:SetBackdrop(BACKDROP_STANDARD)
    f:SetBackdropColor(T("BG_PRIMARY"))
    f:SetBackdropBorderColor(T("BORDER_DEFAULT"))
    return f
end

local function CreateThemedBar(name, parentFrame)
    local f = CreateFrame("Frame", name, parentFrame, "BackdropTemplate")
    f:SetBackdrop(BACKDROP_STANDARD)
    f:SetBackdropColor(T("BG_SECONDARY"))
    f:SetBackdropBorderColor(T("BORDER_DEFAULT"))
    return f
end

function ns.UI.CreatePlayersTab(parent)
    local controlPanel = CreateThemedBar(nil, parent)
    controlPanel:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, 0)
    controlPanel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    controlPanel:SetHeight(75)

    local controlTitle = controlPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    controlTitle:SetPoint("TOPLEFT", controlPanel, "TOPLEFT", 10, -8)
    controlTitle:SetText(L["PLAYERS_CONTROLS"] or "Players Controls")
    controlTitle:SetTextColor(T("TEXT_SECONDARY"))

    local addTargetBtn = ns.UI.CreateButton(nil, controlPanel, L["BUTTON_ADD_TARGET"] or "Add Target", 100, 25)
    ns.UI.AutoResizeButton(addTargetBtn, 80, 200)
    addTargetBtn:SetPoint("TOPLEFT", controlPanel, "TOPLEFT", 10, -28)
    addTargetBtn:SetScript("OnClick", function()
        if ns.Players then
            local playerInfo = ns.Players:GetTargetPlayerInfo()
            if not playerInfo then
                print("|cFFFFD100OneWoW - Players:|r " .. (L["MSG_TARGET_PLAYER_FIRST"] or "Target a player first."))
                return
            end
            if ns.Players:GetPlayer(playerInfo.fullName) then
                print("|cFFFFD100OneWoW - Players:|r " .. (L["MSG_PLAYER_EXISTS"] or "Player note already exists."))
                return
            end
            local fullName = ns.Players:AddPlayer(playerInfo.fullName, playerInfo)
            print("|cFFFFD100OneWoW - Players:|r " .. string.format(L["MSG_PLAYER_ADDED"] or "Added: %s", playerInfo.name or fullName))
            parent.RefreshPlayersList()
            if parent.SelectPlayer and fullName then parent.SelectPlayer(fullName) end
        end
    end)
    addTargetBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["TOOLTIP_BUTTON_ADD_TARGET"] or "Add Target", 1, 1, 1)
        GameTooltip:AddLine(L["TOOLTIP_BUTTON_ADD_TARGET_PLAYER_DESC"] or "Add a note for your current target.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    addTargetBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local addManualBtn = ns.UI.CreateButton(nil, controlPanel, L["BUTTON_MANUAL_ENTRY"] or "Manual", 90, 25)
    ns.UI.AutoResizeButton(addManualBtn, 70, 200)
    addManualBtn:SetPoint("LEFT", addTargetBtn, "RIGHT", 5, 0)
    addManualBtn:SetScript("OnClick", function()
        if ns.UI and ns.UI.ShowManualPlayerEntryDialog then
            ns.UI.ShowManualPlayerEntryDialog(parent)
        end
    end)
    addManualBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["BUTTON_MANUAL_ENTRY"] or "Manual Entry", 1, 1, 1)
        GameTooltip:AddLine(L["TOOLTIP_BUTTON_MANUAL_ENTRY_PLAYER_DESC"] or "Enter a player name manually.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    addManualBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local altTrackerLoaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("OneWoW_AltTracker_Character")
    local addAltsBtn = ns.UI.CreateButton(nil, controlPanel, L["PLAYER_ADD_ALTS"] or "Add Alts", 80, 25)
    ns.UI.AutoResizeButton(addAltsBtn, 70, 200)
    addAltsBtn:SetPoint("LEFT", addManualBtn, "RIGHT", 5, 0)
    if not altTrackerLoaded then
        addAltsBtn:Disable()
        addAltsBtn:SetAlpha(0.4)
    end
    addAltsBtn:SetScript("OnClick", function()
        if not altTrackerLoaded and not _G.OneWoW_AltTracker_Character_DB then
            print("|cFFFFD100OneWoW - Players:|r " .. (L["PLAYER_ALTS_NO_DATA"] or "AltTracker not detected."))
            return
        end
        if ns.UI and ns.UI.ShowAddAltsDialog then
            ns.UI.ShowAddAltsDialog(parent)
        end
    end)
    addAltsBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["PLAYER_ADD_ALTS"] or "Add Alts", 1, 1, 1)
        if altTrackerLoaded then
            GameTooltip:AddLine(L["PLAYER_ADD_ALTS_DESC"] or "Add your alts from AltTracker data.", 0.8, 0.8, 0.8, true)
        else
            GameTooltip:AddLine(L["PLAYER_ALTS_NOT_INSTALLED"] or "Requires OneWoW AltTracker to be installed.", 1.0, 0.3, 0.3, true)
        end
        GameTooltip:Show()
    end)
    addAltsBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local addGuildBtn = ns.UI.CreateButton(nil, controlPanel, L["PLAYER_ADD_GUILD"] or "Add Guild", 90, 25)
    ns.UI.AutoResizeButton(addGuildBtn, 70, 200)
    addGuildBtn:SetPoint("LEFT", addAltsBtn, "RIGHT", 5, 0)
    addGuildBtn:SetScript("OnClick", function()
        if ns.UI and ns.UI.ShowAddGuildDialog then
            ns.UI.ShowAddGuildDialog(parent)
        end
    end)
    addGuildBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["PLAYER_ADD_GUILD"] or "Add Guild Members", 1, 1, 1)
        GameTooltip:AddLine(L["PLAYER_ADD_GUILD_DESC"] or "Add guild members to player notes.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    addGuildBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local catDD = ns.UI.CreateThemedDropdown(controlPanel, L["LABEL_CATEGORY"], 140, 25)
    catDD:SetPoint("LEFT", addGuildBtn, "RIGHT", 8, 0)
    local function RefreshCatOpts()
        local opts = {{text = L["UI_ALL"], value = "All"}}
        if ns.Players then
            for _, c in ipairs(ns.Players:GetCategories()) do
                opts[#opts + 1] = {text = c, value = c}
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
            ns.UI.ShowCategoryManager("players")
        end
    end)
    manageCategoriesBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["UI_MANAGE_CATEGORIES"], 1, 1, 1)
        GameTooltip:AddLine(L["UI_MANAGE_CATEGORIES_DESC"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    manageCategoriesBtn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)

    local storeDD = ns.UI.CreateThemedDropdown(controlPanel, L["LABEL_STORAGE"], 130, 25)
    storeDD:SetPoint("LEFT", manageCategoriesBtn, "RIGHT", 4, 0)
    storeDD:SetOptions({
        {text = L["UI_ALL"],               value = "All"},
        {text = L["UI_STORAGE_ACCOUNT"],   value = "account"},
        {text = L["UI_STORAGE_CHARACTER"], value = "character"},
    })
    storeDD:SetSelected("All")
    storeDD.onSelect = function(value)
        storageFilter = value
        parent.RefreshPlayersList()
    end

    local helpButton = CreateFrame("Button", nil, controlPanel)
    helpButton:SetSize(28, 28)
    helpButton:SetPoint("TOPRIGHT", controlPanel, "TOPRIGHT", -10, -10)
    local helpIcon = helpButton:CreateTexture(nil, "ARTWORK")
    helpIcon:SetSize(24, 24)
    helpIcon:SetPoint("CENTER", helpButton, "CENTER", 0, 0)
    helpIcon:SetAtlas("CampaignActiveQuestIcon")
    helpButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["UI_NOTES_HYPERLINK_TITLE"], 1, 1, 1)
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
    listingPanel:SetPoint("TOPLEFT",  controlPanel, "BOTTOMLEFT",  0, -10)
    listingPanel:SetPoint("BOTTOMLEFT", parent,     "BOTTOMLEFT",  0, 35)
    listingPanel:SetWidth(258)

    local listingTitle = listingPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    listingTitle:SetPoint("TOP", listingPanel, "TOP", 0, -10)
    listingTitle:SetText(L["PLAYERS_LIST"] or "Players")
    listingTitle:SetTextColor(T("ACCENT_PRIMARY"))

    local listScroll = ns.UI.CreateCustomScroll(listingPanel)
    scrollFrame = listScroll.scrollFrame
    scrollChild = listScroll.scrollChild
    listScroll.container:SetPoint("TOPLEFT",     listingPanel, "TOPLEFT",     10, -40)
    listScroll.container:SetPoint("BOTTOMRIGHT", listingPanel, "BOTTOMRIGHT", -10, 10)

    detailPanel = CreateThemedPanel(nil, parent)
    detailPanel:SetPoint("TOPLEFT",     listingPanel, "TOPRIGHT",    10, 0)
    detailPanel:SetPoint("BOTTOMRIGHT", parent,       "BOTTOMRIGHT",  0, 35)
    detailPanel:SetClipsChildren(true)

    emptyMessage = detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    emptyMessage:SetPoint("CENTER", detailPanel, "CENTER")
    emptyMessage:SetText(L["PLAYERS_SELECT"] or "Select a player to view their note.")
    emptyMessage:SetTextColor(0.6, 0.6, 0.7, 1)

    local leftStatusBar = CreateThemedBar(nil, parent)
    leftStatusBar:SetPoint("TOPLEFT",  listingPanel, "BOTTOMLEFT",  0, -5)
    leftStatusBar:SetPoint("TOPRIGHT", listingPanel, "BOTTOMRIGHT", 0, -5)
    leftStatusBar:SetHeight(25)

    leftStatusText = leftStatusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    leftStatusText:SetPoint("LEFT", leftStatusBar, "LEFT", 10, 0)
    leftStatusText:SetTextColor(T("TEXT_SECONDARY"))
    leftStatusText:SetText(string.format(L["UI_COUNT_FORMAT"], L["TAB_PLAYERS"], 0))

    local rightStatusBar = CreateThemedBar(nil, parent)
    rightStatusBar:SetPoint("TOPLEFT",     detailPanel, "BOTTOMLEFT",  0, -5)
    rightStatusBar:SetPoint("TOPRIGHT",    detailPanel, "BOTTOMRIGHT", 0, -5)
    rightStatusBar:SetHeight(25)

    local rightStatusText = rightStatusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rightStatusText:SetPoint("LEFT", rightStatusBar, "LEFT", 10, 0)
    rightStatusText:SetTextColor(T("TEXT_SECONDARY"))
    rightStatusText:SetText(L["STATUS_READY"])

    local function ShowEditor()
        emptyMessage:Hide()
        for _, child in ipairs({detailPanel:GetChildren()}) do
            if child ~= emptyMessage then child:Hide() end
        end

        if not detailPanel.editorContent then
            local editorHeader = CreateThemedBar(nil, detailPanel)
            editorHeader:SetPoint("TOPLEFT",  detailPanel, "TOPLEFT",  10, -10)
            editorHeader:SetPoint("TOPRIGHT", detailPanel, "TOPRIGHT", -10, -10)
            editorHeader:SetHeight(95)

            local nameServerLine = editorHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            nameServerLine:SetPoint("TOPLEFT", editorHeader, "TOPLEFT", 12, -12)
            nameServerLine:SetPoint("TOPRIGHT", editorHeader, "TOPRIGHT", -100, -12)
            nameServerLine:SetJustifyH("LEFT")
            nameServerLine:SetText("")
            nameServerLine:SetTextColor(T("ACCENT_PRIMARY"))
            editorHeader.nameServerLine = nameServerLine

            local levelClassRaceLine = editorHeader:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            levelClassRaceLine:SetPoint("TOPLEFT", nameServerLine, "BOTTOMLEFT", 0, -4)
            levelClassRaceLine:SetText("")
            levelClassRaceLine:SetTextColor(T("TEXT_SECONDARY"))
            editorHeader.levelClassRaceLine = levelClassRaceLine

            local guildLine = editorHeader:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            guildLine:SetPoint("TOPLEFT", levelClassRaceLine, "BOTTOMLEFT", 0, -2)
            guildLine:SetText("")
            guildLine:SetTextColor(T("TEXT_MUTED"))
            editorHeader.guildLine = guildLine

            local categoryLine = editorHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            categoryLine:SetPoint("BOTTOMRIGHT", editorHeader, "BOTTOMRIGHT", -12, 8)
            categoryLine:SetText(string.format(L["UI_CATEGORY_WITH_VALUE"], L["UI_GENERAL"]))
            categoryLine:SetTextColor(T("ACCENT_PRIMARY"))
            categoryLine:SetJustifyH("RIGHT")
            editorHeader.categoryLine = categoryLine

            local deleteBtn = CreateFrame("Button", nil, editorHeader)
            deleteBtn:SetSize(22, 22)
            deleteBtn:SetPoint("TOPRIGHT", editorHeader, "TOPRIGHT", -12, -12)
            deleteBtn:SetNormalTexture(MEDIA .. "icon-trash.png")
            deleteBtn:SetPushedTexture(MEDIA .. "icon-trash.png")
            deleteBtn:SetHighlightTexture(MEDIA .. "icon-trash.png")
            deleteBtn:GetHighlightTexture():SetAlpha(0.5)
            deleteBtn:SetScript("OnClick", function()
                if selectedPlayer then
                    StaticPopupDialogs["ONEWOW_NOTES_CONFIRM_DELETE_PLAYER"] = {
                        text = string.format(L["POPUP_DELETE_PLAYER"] or "Delete player note?"),
                        button1 = L["BUTTON_DELETE"], button2 = L["BUTTON_CANCEL"],
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
                GameTooltip:SetText(L["TOOLTIP_PLAYER_DELETE"] or "Delete Player", 1, 1, 1)
                GameTooltip:AddLine(L["TOOLTIP_PLAYER_DELETE_DESC"] or "Remove this player note", 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            deleteBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            editorHeader.deleteBtn = deleteBtn

            local propertiesBtn = CreateFrame("Button", nil, editorHeader)
            propertiesBtn:SetSize(22, 22)
            propertiesBtn:SetPoint("RIGHT", deleteBtn, "LEFT", -2, 0)
            propertiesBtn:SetNormalTexture(MEDIA .. "icon-gears.png")
            propertiesBtn:SetPushedTexture(MEDIA .. "icon-gears.png")
            propertiesBtn:SetHighlightTexture(MEDIA .. "icon-gears.png")
            propertiesBtn:GetHighlightTexture():SetAlpha(0.5)
            propertiesBtn:SetScript("OnClick", function()
                if selectedPlayer and ns.UI and ns.UI.ShowPlayerPropertiesDialog then
                    ns.UI.ShowPlayerPropertiesDialog(selectedPlayer, parent)
                end
            end)
            propertiesBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["TOOLTIP_PLAYER_PROPERTIES"] or "Player Properties", 1, 1, 1)
                GameTooltip:AddLine(L["TOOLTIP_PLAYER_PROPERTIES_DESC"] or "Edit player settings", 0.8, 0.8, 0.8, true)
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
                GameTooltip:SetText(L["TOOLTIP_PLAYER_SOUND"] or "Alert on Sight", 1, 1, 1)
                GameTooltip:AddLine(L["TOOLTIP_PLAYER_SOUND_DESC"] or "Alert when you target this player.", 0.8, 0.8, 0.8, true)
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
                GameTooltip:SetText(L["TOOLTIP_PLAYER_FAVORITE"] or "Favorite", 1, 1, 1)
                GameTooltip:AddLine(L["TOOLTIP_PLAYER_FAVORITE_DESC"] or "Mark as favorite", 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            favoriteBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            editorHeader.favoriteBtn = favoriteBtn

            local contentBg = CreateThemedBar(nil, detailPanel)
            contentBg:SetPoint("TOPLEFT",  editorHeader, "BOTTOMLEFT",  0, -10)
            contentBg:SetPoint("TOPRIGHT", editorHeader, "BOTTOMRIGHT", 0, -10)
            contentBg:SetHeight(160)
            contentBg:EnableMouse(true)

            local contentScroll = CreateFrame("ScrollFrame", nil, contentBg, "UIPanelScrollFrameTemplate")
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
            contentEditBox:SetScript("OnHyperlinkClick", function(self, link, text, button)
                SetItemRef(link, text, button)
            end)
            contentEditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
            contentEditBox:SetScript("OnTextChanged", function(self, userInput)
                if userInput and selectedPlayer and ns.Players then
                    local pd = ns.Players:GetPlayer(selectedPlayer)
                    if pd then pd.content = self:GetText() pd.modified = GetServerTime() end
                end
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
            contentScroll:SetScrollChild(contentEditBox)
            detailPanel.contentEditBox = contentEditBox

            contentBg:SetScript("OnMouseDown", function(self, button)
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

            local ttLabel = tooltipSection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            ttLabel:SetPoint("TOPLEFT", tooltipSection, "TOPLEFT", 10, -8)
            ttLabel:SetText(L["UI_TOOLTIP_LINES"] or "Tooltip Lines:")
            ttLabel:SetTextColor(T("ACCENT_PRIMARY"))

            local tooltipEdits = {}
            for i = 1, 4 do
                local edit = lib:CreateEditBox(nil, tooltipSection, {
                    height = 22,
                    maxLetters = 255,
                })
                edit:ClearAllPoints()
                edit:SetPoint("TOPLEFT",  tooltipSection, "TOPLEFT",  10, -30 - (i - 1) * 28)
                edit:SetPoint("TOPRIGHT", tooltipSection, "TOPRIGHT", -10, -30 - (i - 1) * 28)
                edit:SetAutoFocus(false)
                edit:SetHyperlinksEnabled(true)
                edit:SetScript("OnHyperlinkClick", function(self, link, text, button)
                    SetItemRef(link, text, button)
                end)
                edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
                edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
                edit:SetScript("OnTextChanged", function(self, userInput)
                    if userInput and selectedPlayer and ns.Players then
                        local pd = ns.Players:GetPlayer(selectedPlayer)
                        if pd then
                            if not pd.tooltipLines then pd.tooltipLines = {"","","",""} end
                            pd.tooltipLines[i] = self:GetText()
                        end
                    end
                end)
                edit:SetScript("OnReceiveDrag", function(self)
                    local cursorType, _, itemLink = GetCursorInfo()
                    if cursorType == "item" and itemLink then self:Insert(itemLink) ClearCursor() end
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
                        header.guildLine:SetTextColor(T("ACCENT_SECONDARY"))
                    else
                        header.guildLine:SetText(L["UI_GUILD_NONE"] or "<No Guild>")
                        header.guildLine:SetTextColor(T("TEXT_MUTED"))
                    end
                end
                if header.categoryLine then
                    header.categoryLine:SetText(string.format(L["UI_CATEGORY_WITH_VALUE"], pd.category or L["UI_GENERAL"]))
                    header.categoryLine:SetTextColor(borderColor[1], borderColor[2], borderColor[3])
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

    parent:HookScript("OnShow", function()
        local notes = _G.OneWoW_Notes
        if notes and notes.pendingPlayerSelect then
            local name = notes.pendingPlayerSelect
            notes.pendingPlayerSelect = nil
            parent.SelectPlayer(name)
        end
    end)

    local function CreateSectionHeader(text, yPos)
        local section = lib:CreateSectionHeader(scrollChild, text, yPos)
        section:ClearAllPoints()
        section:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yPos)
        section:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, yPos)
        table.insert(playerListItems, section)
        return section
    end

    function parent.RefreshPlayersList()
        for _, item in pairs(playerListItems) do item:Hide() item:SetParent(nil) end
        playerListItems = {}

        if not ns.Players then
            if leftStatusText then leftStatusText:SetText(string.format(L["UI_COUNT_FORMAT"], L["TAB_PLAYERS"], 0)) end
            return
        end

        local allPlayers = ns.Players:GetAllPlayers()
        local playersList = {}
        local now = GetServerTime()

        for fullName, pd in pairs(allPlayers) do
            if type(pd) == "table" then
                if pd.isNew and pd.newTimestamp and (now - pd.newTimestamp) > 3600 then
                    pd.isNew = false pd.newTimestamp = nil
                end
                local matches = true
                if categoryFilter ~= "All" and pd.category ~= categoryFilter then matches = false end
                if storageFilter  ~= "All" and pd.storage  ~= storageFilter  then matches = false end
                if matches then
                    table.insert(playersList, {fullName = fullName, data = pd})
                end
            end
        end

        local newPlayers = {}
        local favorites  = {}
        local regular    = {}
        for _, p in ipairs(playersList) do
            if p.data.isNew then table.insert(newPlayers, p)
            elseif p.data.favorite then table.insert(favorites, p)
            else table.insert(regular, p) end
        end

        local function sortByName(a, b)
            return (a.data.name or a.fullName) < (b.data.name or b.fullName)
        end
        table.sort(newPlayers, sortByName)
        table.sort(favorites,  sortByName)
        table.sort(regular,    sortByName)

        local function BuildPlayerRow(player, yOffset)
            local pinColorKey = ns.Players:GetPinColorKey(player.data.class)
            local colorConfig = ns.Config.PIN_COLORS[pinColorKey] or ns.Config.PIN_COLORS["hunter"]
            local listItemColor = colorConfig.listItem
            local borderColor   = colorConfig.border

            local row = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
            row:SetSize(scrollChild:GetWidth(), 50)
            row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yOffset)
            row:SetBackdrop(BACKDROP_STANDARD)
            row:SetBackdropColor(listItemColor[1], listItemColor[2], listItemColor[3], listItemColor[4])
            row:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], 1)

            local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            nameText:SetPoint("TOPLEFT",  row, "TOPLEFT",  10, -10)
            nameText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, -10)
            nameText:SetJustifyH("LEFT")
            nameText:SetText(player.data.name or player.fullName)
            nameText:SetTextColor(borderColor[1], borderColor[2], borderColor[3])

            local subText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            subText:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 10, 8)
            local sub = ""
            if player.data.realm and player.data.realm ~= "" then sub = player.data.realm .. " " end
            if player.data.class and player.data.class ~= "" then sub = sub .. player.data.class end
            subText:SetText(sub)
            subText:SetTextColor(T("TEXT_MUTED"))

            local deleteBtn = CreateFrame("Button", nil, row)
            deleteBtn:SetSize(18, 18)
            deleteBtn:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -5, 5)
            deleteBtn:SetNormalTexture(MEDIA .. "icon-trash.png")
            deleteBtn:SetPushedTexture(MEDIA .. "icon-trash.png")
            deleteBtn:SetHighlightTexture(MEDIA .. "icon-trash.png")
            deleteBtn:GetHighlightTexture():SetAlpha(0.5)
            deleteBtn:SetScript("OnClick", function()
                StaticPopupDialogs["ONEWOW_NOTES_CONFIRM_DELETE_PLAYER"] = {
                    text = string.format(L["POPUP_DELETE_PLAYER"] or "Delete player note?"),
                    button1 = L["BUTTON_DELETE"], button2 = L["BUTTON_CANCEL"],
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
            end)

            local propBtn = CreateFrame("Button", nil, row)
            propBtn:SetSize(18, 18)
            propBtn:SetPoint("RIGHT", deleteBtn, "LEFT", -2, 0)
            propBtn:SetNormalTexture(MEDIA .. "icon-gears.png")
            propBtn:SetPushedTexture(MEDIA .. "icon-gears.png")
            propBtn:SetHighlightTexture(MEDIA .. "icon-gears.png")
            propBtn:GetHighlightTexture():SetAlpha(0.5)
            propBtn:SetScript("OnClick", function()
                if ns.UI.ShowPlayerPropertiesDialog then ns.UI.ShowPlayerPropertiesDialog(player.fullName, parent) end
            end)

            local alertBtn2 = CreateFrame("CheckButton", nil, row)
            alertBtn2:SetSize(18, 18)
            alertBtn2:SetPoint("RIGHT", propBtn, "LEFT", -2, 0)
            local aN2 = alertBtn2:CreateTexture(nil, "BACKGROUND")
            aN2:SetAllPoints() aN2:SetTexture(MEDIA .. "icon-alert.png")
            aN2:SetDesaturated(not player.data.soundEnabled)
            aN2:SetAlpha(player.data.soundEnabled and 1.0 or 0.3)
            alertBtn2:SetNormalTexture(aN2)
            alertBtn2:SetScript("OnClick", function(self)
                if ns.Players then
                    local pd = ns.Players:GetPlayer(player.fullName)
                    if pd then
                        pd.soundEnabled = not pd.soundEnabled
                        aN2:SetDesaturated(not pd.soundEnabled)
                        aN2:SetAlpha(pd.soundEnabled and 1.0 or 0.3)
                        ns.Players:SavePlayer(player.fullName, pd)
                        if selectedPlayer == player.fullName and detailPanel.editorContent and detailPanel.editorContent.header then
                            local h = detailPanel.editorContent.header
                            if h.alertBtn then
                                h.alertBtn:GetNormalTexture():SetDesaturated(not pd.soundEnabled)
                                h.alertBtn:GetNormalTexture():SetAlpha(pd.soundEnabled and 1.0 or 0.3)
                                h.alertBtn:SetChecked(pd.soundEnabled)
                            end
                        end
                    end
                end
            end)

            local favBtn2 = CreateFrame("CheckButton", nil, row)
            favBtn2:SetSize(18, 18)
            favBtn2:SetPoint("RIGHT", alertBtn2, "LEFT", -2, 0)
            local fN2 = favBtn2:CreateTexture(nil, "BACKGROUND")
            fN2:SetAllPoints() fN2:SetTexture(MEDIA .. "icon-fav.png")
            fN2:SetDesaturated(not player.data.favorite)
            fN2:SetAlpha(player.data.favorite and 1.0 or 0.3)
            favBtn2:SetNormalTexture(fN2)
            favBtn2:SetScript("OnClick", function(self)
                if ns.Players then
                    local pd = ns.Players:GetPlayer(player.fullName)
                    if pd then
                        pd.favorite = not pd.favorite
                        fN2:SetDesaturated(not pd.favorite)
                        fN2:SetAlpha(pd.favorite and 1.0 or 0.3)
                        ns.Players:SavePlayer(player.fullName, pd)
                        parent.RefreshPlayersList()
                    end
                end
            end)

            row:EnableMouse(true)
            row:SetScript("OnMouseDown", function()
                selectedPlayer = player.fullName
                ShowEditor()
                parent.RefreshPlayersList()
            end)
            row:SetScript("OnEnter", function(self)
                if selectedPlayer ~= player.fullName then
                    self:SetBackdropColor(listItemColor[1] * 1.2, listItemColor[2] * 1.2, listItemColor[3] * 1.2, listItemColor[4] + 0.1)
                end
            end)
            row:SetScript("OnLeave", function(self)
                if selectedPlayer ~= player.fullName then
                    self:SetBackdropColor(listItemColor[1], listItemColor[2], listItemColor[3], listItemColor[4])
                end
            end)

            if selectedPlayer == player.fullName then
                row:SetBackdropColor(listItemColor[1] + 0.15, listItemColor[2] + 0.15, listItemColor[3] + 0.15, 0.9)
                row:SetBackdropBorderColor(1, 0.82, 0, 1)
            end

            table.insert(playerListItems, row)
        end

        local yOffset = 0

        if #newPlayers > 0 then
            CreateSectionHeader(L["NOTES_SECTION_NEW"] or "New", yOffset) yOffset = yOffset - 30
        end
        for _, p in ipairs(newPlayers) do BuildPlayerRow(p, yOffset) yOffset = yOffset - 55 end

        if #favorites > 0 then
            CreateSectionHeader(L["NOTES_SECTION_FAVORITES"] or "Favorites", yOffset) yOffset = yOffset - 30
        end
        for _, p in ipairs(favorites) do BuildPlayerRow(p, yOffset) yOffset = yOffset - 55 end

        if #regular > 0 then
            CreateSectionHeader(L["TAB_PLAYERS"], yOffset) yOffset = yOffset - 30
        end
        for _, p in ipairs(regular) do BuildPlayerRow(p, yOffset) yOffset = yOffset - 55 end

        scrollChild:SetHeight(math.abs(yOffset) + 50)
        if leftStatusText then
            leftStatusText:SetText(string.format(L["UI_COUNT_FORMAT"], L["TAB_PLAYERS"], #newPlayers + #favorites + #regular))
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
    local lbl = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", x, y)
    lbl:SetText(text)
    lbl:SetTextColor(T("TEXT_SECONDARY"))
    return lbl
end

local function MakeDialogInput(parentFrame, x, y, w)
    local input = lib:CreateEditBox(nil, parentFrame, {
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
        title          = L["PLAYER_MANUAL_ENTRY_TITLE"] or "Add Player",
        width          = 580,
        height         = 580,
        destroyOnClose = true,
        buttons = {
            {
                text = L["BUTTON_ADD_NOTE"] or "Add",
                onClick = function(dlg)
                    local name  = dlg._nameInput  and dlg._nameInput:GetText()  or ""
                    local realm = dlg._realmInput and dlg._realmInput:GetText() or ""
                    if name == "" then
                        print("|cFFFFD100OneWoW - Players:|r " .. (L["PLAYER_ERROR_NAME_REQUIRED"] or "Player name is required."))
                        return
                    end
                    if realm == "" then realm = GetRealmName() or "Unknown" end
                    local fullName = name .. "-" .. realm

                    if ns.Players and ns.Players:GetPlayer(fullName) then
                        print("|cFFFFD100OneWoW - Players:|r " .. (L["MSG_PLAYER_EXISTS"] or "Player note already exists."))
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
                        print("|cFFFFD100OneWoW - Players:|r " .. string.format(L["MSG_PLAYER_ADDED"] or "Added: %s", name))
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
            { text = L["BUTTON_CANCEL"], onClick = function(dlg) dlg:Hide() end },
        },
    })

    if dialog.built then dialog:Show() return end
    dialog.built = true

    local content = dialog.content
    local yPos = -10

    MakeDialogLabel(content, L["LABEL_NAME"] or "Name:", COL1_X, yPos)
    dialog._nameInput = MakeDialogInput(content, COL1_X, yPos - LBL_GAP, COL_W)
    dialog._nameInput:SetAutoFocus(true)

    MakeDialogLabel(content, L["PLAYER_LABEL_LEVEL"] or "Level:", COL2_X, yPos)
    dialog._levelInput = MakeDialogInput(content, COL2_X, yPos - LBL_GAP, COL_W)
    dialog._levelInput:SetNumeric(true)
    dialog._levelInput:SetText("1")
    yPos = yPos - ROW_H

    MakeDialogLabel(content, L["LABEL_SERVER"] or "Server:", COL1_X, yPos)
    dialog._realmInput = MakeDialogInput(content, COL1_X, yPos - LBL_GAP, COL_W)
    dialog._realmInput:SetText(GetRealmName() or "")

    MakeDialogLabel(content, L["PLAYER_LABEL_GUILD"] or "Guild:", COL2_X, yPos)
    dialog._guildInput = MakeDialogInput(content, COL2_X, yPos - LBL_GAP, COL_W)
    yPos = yPos - ROW_H

    MakeDialogLabel(content, L["PLAYER_LABEL_RACE"] or "Race:", COL1_X, yPos)
    local raceDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    raceDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos - LBL_GAP)
    local raceOpts = {{text = "", value = ""}}
    for _, r in ipairs(PLAYER_RACES) do
        raceOpts[#raceOpts + 1] = {text = r, value = r}
    end
    raceDD:SetOptions(raceOpts)
    raceDD:SetSelected("")
    dialog._raceDD = raceDD

    MakeDialogLabel(content, L["PLAYER_LABEL_CLASS"] or "Class:", COL2_X, yPos)
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

    MakeDialogLabel(content, L["LABEL_CATEGORY"], COL1_X, yPos)
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
        {text = L["STORAGE_ACCOUNT_WIDE"],   value = "account"},
        {text = L["STORAGE_TYPE_CHARACTER"], value = "character"},
    })
    storeDD:SetSelected("account")
    dialog._storeDD = storeDD
    yPos = yPos - ROW_H

    MakeDialogLabel(content, L["LABEL_PROFESSION_1"] or "Profession 1:", COL1_X, yPos)
    local prof1DD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    prof1DD:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos - LBL_GAP)
    local profOpts = {}
    for _, p in ipairs(PLAYER_PROFESSIONS) do
        profOpts[#profOpts + 1] = {text = p, value = p}
    end
    prof1DD:SetOptions(profOpts)
    prof1DD:SetSelected("None")
    dialog._prof1DD = prof1DD

    MakeDialogLabel(content, L["LABEL_PROFESSION_2"] or "Profession 2:", COL2_X, yPos)
    local prof2DD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    prof2DD:SetPoint("TOPLEFT", content, "TOPLEFT", COL2_X, yPos - LBL_GAP)
    prof2DD:SetOptions(profOpts)
    prof2DD:SetSelected("None")
    dialog._prof2DD = prof2DD
    yPos = yPos - ROW_H

    MakeDialogLabel(content, L["LABEL_NOTE_CONTENT"] or "Note:", COL1_X, yPos)
    yPos = yPos - LBL_GAP

    local noteBg = CreateThemedBar(nil, content)
    noteBg:SetPoint("TOPLEFT",     content, "TOPLEFT",     COL1_X, yPos)
    noteBg:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -COL1_X, 6)

    local noteScroll = CreateFrame("ScrollFrame", nil, noteBg, "UIPanelScrollFrameTemplate")
    noteScroll:SetPoint("TOPLEFT",     noteBg, "TOPLEFT",     4, -4)
    noteScroll:SetPoint("BOTTOMRIGHT", noteBg, "BOTTOMRIGHT", -26, 4)

    local noteEditBox = CreateFrame("EditBox", nil, noteScroll)
    noteEditBox:SetMultiLine(true)
    noteEditBox:SetFontObject("ChatFontNormal")
    noteEditBox:SetAutoFocus(false)
    noteEditBox:SetMaxLetters(0)
    noteScroll:SetScrollChild(noteEditBox)
    noteScroll:HookScript("OnSizeChanged", function(self, w)
        noteEditBox:SetWidth(math.max(1, w))
    end)
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
        title          = (L["DIALOG_PLAYER_PROPERTIES"] or "Player Properties") .. ": " .. (pd.name or fullName),
        width          = 580,
        height         = 580,
        destroyOnClose = true,
        buttons = {
            { text = L["BUTTON_CLOSE"], onClick = function(dlg) dlg:Hide() end },
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
        if refreshParent and refreshParent.RefreshPlayersList then refreshParent.RefreshPlayersList() end
    end

    MakeDialogLabel(content, L["LABEL_NAME"] or "Name:", COL1_X, yPos)
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

    MakeDialogLabel(content, L["PLAYER_LABEL_LEVEL"] or "Level:", COL2_X, yPos)
    local levelInput = MakeDialogInput(content, COL2_X, yPos - LBL_GAP, COL_W)
    levelInput:SetNumeric(true)
    levelInput:SetText(tostring(pd.level or 0))
    levelInput:SetScript("OnEnterPressed", function(self)
        SaveField("level", tonumber(self:GetText()) or 0)
        self:ClearFocus()
    end)
    yPos = yPos - ROW_H

    MakeDialogLabel(content, L["LABEL_SERVER"] or "Server:", COL1_X, yPos)
    local realmInput = MakeDialogInput(content, COL1_X, yPos - LBL_GAP, COL_W)
    realmInput:SetText(pd.realm or "")
    realmInput:SetScript("OnEnterPressed", function(self)
        SaveField("realm", self:GetText())
        self:ClearFocus()
    end)

    MakeDialogLabel(content, L["PLAYER_LABEL_GUILD"] or "Guild:", COL2_X, yPos)
    local guildInput = MakeDialogInput(content, COL2_X, yPos - LBL_GAP, COL_W)
    guildInput:SetText(pd.guild or "")
    guildInput:SetScript("OnEnterPressed", function(self)
        SaveField("guild", self:GetText())
        self:ClearFocus()
    end)
    yPos = yPos - ROW_H

    MakeDialogLabel(content, L["PLAYER_LABEL_RACE"] or "Race:", COL1_X, yPos)
    local raceDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    raceDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos - LBL_GAP)
    local raceOpts = {{text = "", value = ""}}
    for _, r in ipairs(PLAYER_RACES) do
        raceOpts[#raceOpts + 1] = {text = r, value = r}
    end
    raceDD:SetOptions(raceOpts)
    raceDD:SetSelected(pd.race or "")
    raceDD.onSelect = function(value) SaveField("race", value) end

    MakeDialogLabel(content, L["PLAYER_LABEL_CLASS"] or "Class:", COL2_X, yPos)
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

    MakeDialogLabel(content, L["LABEL_CATEGORY"], COL1_X, yPos)
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
        {text = L["STORAGE_ACCOUNT_WIDE"],   value = "account"},
        {text = L["STORAGE_TYPE_CHARACTER"], value = "character"},
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

    MakeDialogLabel(content, L["LABEL_PROFESSION_1"] or "Profession 1:", COL1_X, yPos)
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

    MakeDialogLabel(content, L["LABEL_PROFESSION_2"] or "Profession 2:", COL2_X, yPos)
    local prof2DD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    prof2DD:SetPoint("TOPLEFT", content, "TOPLEFT", COL2_X, yPos - LBL_GAP)
    prof2DD:SetOptions(profOpts)
    prof2DD:SetSelected(pd.profession2 or "None")
    prof2DD.onSelect = function(value)
        SaveField("profession2", value ~= "None" and value or nil)
    end
    yPos = yPos - ROW_H

    local alertCB = lib:CreateCheckbox(nil, content, L["TOOLTIP_PLAYER_SOUND"] or "Alert on Target")
    alertCB:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos)
    alertCB:SetChecked(pd.soundEnabled or false)
    alertCB:SetScript("OnClick", function(self)
        SaveField("soundEnabled", self:GetChecked())
    end)
    alertCB:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["TOOLTIP_PLAYER_SOUND"] or "Alert on Target", 1, 1, 1)
        GameTooltip:AddLine(L["TOOLTIP_PLAYER_SOUND_DESC"] or "Play a sound alert when you target this player.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    alertCB:SetScript("OnLeave", function() GameTooltip:Hide() end)
    yPos = yPos - 30

    MakeDialogLabel(content, L["LABEL_NOTE_PREVIEW"] or "Note:", COL1_X, yPos)
    yPos = yPos - LBL_GAP

    local noteBg = CreateThemedBar(nil, content)
    noteBg:SetPoint("TOPLEFT",     content, "TOPLEFT",     COL1_X, yPos)
    noteBg:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -COL1_X, 6)

    local noteScroll = CreateFrame("ScrollFrame", nil, noteBg, "UIPanelScrollFrameTemplate")
    noteScroll:SetPoint("TOPLEFT",     noteBg, "TOPLEFT",     4, -4)
    noteScroll:SetPoint("BOTTOMRIGHT", noteBg, "BOTTOMRIGHT", -26, 4)

    local noteEditBox = CreateFrame("EditBox", nil, noteScroll)
    noteEditBox:SetMultiLine(true)
    noteEditBox:SetFontObject("ChatFontNormal")
    noteEditBox:SetAutoFocus(false)
    noteEditBox:SetMaxLetters(0)
    noteEditBox:SetText(pd.content or "")
    noteEditBox:EnableMouse(false)
    noteScroll:SetScrollChild(noteEditBox)
    noteScroll:HookScript("OnSizeChanged", function(self, w)
        noteEditBox:SetWidth(math.max(1, w))
    end)

    dialog:Show()
end

function ns.UI.ShowAddAltsDialog(refreshParent)
    local altDB = _G.OneWoW_AltTracker_Character_DB
    if not altDB or not altDB.characters then
        print("|cFFFFD100OneWoW - Players:|r " .. (L["PLAYER_ALTS_NO_DATA"] or "AltTracker data not found."))
        return
    end

    local altsToAdd = {}
    for charKey, charData in pairs(altDB.characters) do
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
        print("|cFFFFD100OneWoW - Players:|r " .. (L["PLAYER_ALTS_NONE_NEW"] or "No new alts found to add."))
        return
    end

    table.sort(altsToAdd, function(a, b) return a.name < b.name end)

    local dialog = ns.UI.CreateThemedDialog({
        name           = "OneWoW_NotesAddAlts",
        title          = L["PLAYER_ADD_ALTS_TITLE"] or "Add Alts from AltTracker",
        width          = 520,
        height         = 480,
        destroyOnClose = true,
        buttons = {
            {
                text = L["PLAYER_ADD_SELECTED"] or "Add Selected",
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
                        print("|cFFFFD100OneWoW - Players:|r " .. string.format(L["PLAYER_ALTS_ADDED_COUNT"] or "Added %d alts.", count))
                        if refreshParent and refreshParent.RefreshPlayersList then
                            refreshParent.RefreshPlayersList()
                        end
                    end
                    dlg:Hide()
                end,
            },
            { text = L["BUTTON_CANCEL"], onClick = function(dlg) dlg:Hide() end },
        },
    })

    if dialog.built then dialog:Show() return end
    dialog.built = true

    local content = dialog.content
    local allCheckboxes = {}

    local selectAllBtn = ns.UI.CreateButton(nil, content, L["BUTTON_SELECT_ALL"] or "Select All", 100, 25)
    selectAllBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 8, -8)
    selectAllBtn:SetScript("OnClick", function()
        for _, entry in ipairs(altsToAdd) do entry.checked = true end
        for _, cb in ipairs(allCheckboxes) do cb:SetChecked(true) end
    end)

    local deselectAllBtn = ns.UI.CreateButton(nil, content, L["BUTTON_DESELECT_ALL"] or "Deselect All", 100, 25)
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

    for i, alt in ipairs(altsToAdd) do
        local row = CreateFrame("Frame", nil, scroll.scrollChild, "BackdropTemplate")
        row:SetPoint("TOPLEFT", scroll.scrollChild, "TOPLEFT", 0, -yPos)
        row:SetPoint("TOPRIGHT", scroll.scrollChild, "TOPRIGHT", 0, -yPos)
        row:SetHeight(ROW_H)
        row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        row:SetBackdropColor(T("BG_PRIMARY"))

        local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        cb:SetSize(20, 20)
        cb:SetPoint("LEFT", row, "LEFT", 4, 0)
        cb:SetScript("OnClick", function(self) alt.checked = self:GetChecked() end)
        allCheckboxes[#allCheckboxes + 1] = cb

        local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameFS:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        nameFS:SetText(alt.name)
        nameFS:SetTextColor(T("TEXT_PRIMARY"))

        local infoFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
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
        infoFS:SetTextColor(T("TEXT_SECONDARY"))

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
        print("|cFFFFD100OneWoW - Players:|r " .. (L["PLAYER_GUILD_NOT_IN"] or "You are not in a guild."))
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
        print("|cFFFFD100OneWoW - Players:|r " .. (L["PLAYER_GUILD_NONE_NEW"] or "No new guild members to add."))
        return
    end

    table.sort(guildMembers, function(a, b) return a.name < b.name end)

    local dialog = ns.UI.CreateThemedDialog({
        name           = "OneWoW_NotesAddGuild",
        title          = L["PLAYER_ADD_GUILD_TITLE"] or "Add Guild Members",
        width          = 520,
        height         = 480,
        destroyOnClose = true,
        buttons = {
            {
                text = L["PLAYER_ADD_SELECTED"] or "Add Selected",
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
                        print("|cFFFFD100OneWoW - Players:|r " .. string.format(L["PLAYER_GUILD_ADDED_COUNT"] or "Added %d guild members.", count))
                        if refreshParent and refreshParent.RefreshPlayersList then
                            refreshParent.RefreshPlayersList()
                        end
                    end
                    dlg:Hide()
                end,
            },
            { text = L["BUTTON_CANCEL"], onClick = function(dlg) dlg:Hide() end },
        },
    })

    if dialog.built then dialog:Show() return end
    dialog.built = true

    local content = dialog.content
    local allCheckboxes = {}

    local selectAllBtn = ns.UI.CreateButton(nil, content, L["BUTTON_SELECT_ALL"] or "Select All", 100, 25)
    selectAllBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 8, -8)
    selectAllBtn:SetScript("OnClick", function()
        for _, entry in ipairs(guildMembers) do entry.checked = true end
        for _, cb in ipairs(allCheckboxes) do cb:SetChecked(true) end
    end)

    local deselectAllBtn = ns.UI.CreateButton(nil, content, L["BUTTON_DESELECT_ALL"] or "Deselect All", 100, 25)
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

    for i, member in ipairs(guildMembers) do
        local row = CreateFrame("Frame", nil, scroll.scrollChild, "BackdropTemplate")
        row:SetPoint("TOPLEFT", scroll.scrollChild, "TOPLEFT", 0, -yPos)
        row:SetPoint("TOPRIGHT", scroll.scrollChild, "TOPRIGHT", 0, -yPos)
        row:SetHeight(ROW_H)
        row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        row:SetBackdropColor(T("BG_PRIMARY"))

        local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        cb:SetSize(20, 20)
        cb:SetPoint("LEFT", row, "LEFT", 4, 0)
        cb:SetScript("OnClick", function(self) member.checked = self:GetChecked() end)
        allCheckboxes[#allCheckboxes + 1] = cb

        local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameFS:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        nameFS:SetText(member.name)
        if member.isOnline then
            nameFS:SetTextColor(T("ACCENT_PRIMARY"))
        else
            nameFS:SetTextColor(T("TEXT_PRIMARY"))
        end

        local rankFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        rankFS:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        local infoText = ""
        if member.level and member.level > 0 then infoText = "Lv" .. member.level .. " " end
        if member.class and member.class ~= "" then infoText = infoText .. (CLASS_DISPLAY_NAMES[member.class] or member.class) .. " " end
        if member.rank and member.rank ~= "" then infoText = infoText .. "(" .. member.rank .. ")" end
        rankFS:SetText(infoText)
        rankFS:SetTextColor(T("TEXT_SECONDARY"))

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
