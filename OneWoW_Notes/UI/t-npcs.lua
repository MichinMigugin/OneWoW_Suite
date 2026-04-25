-- OneWoW_Notes Addon File
-- OneWoW_Notes/UI/t-npcs.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...
local L = ns.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_EDGE = OneWoW_GUI.Constants.BACKDROP_EDGE
local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

ns.UI = ns.UI or {}

local selectedNPC   = nil
local npcListItems  = {}
local categoryFilter = "All"
local storageFilter  = "All"
local searchFilter   = ""
local currentSort   = { by = "name", ascending = true }

local detailPanel    = nil
local emptyMessage   = nil
local leftStatusText = nil
local scrollFrame    = nil
local scrollChild    = nil

local MEDIA = "Interface\\AddOns\\OneWoW_Notes\\Media\\"

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

function ns.UI.CreateNPCsTab(parent)
    do
        local a = _G.OneWoW_Notes
        if a and a.db and a.db.global.tabSortPrefs and a.db.global.tabSortPrefs.npcs then
            local p = a.db.global.tabSortPrefs.npcs
            currentSort.by        = p.by or "name"
            currentSort.ascending = p.ascending ~= false
        end
    end

    local controlPanel = CreateThemedBar(nil, parent)
    controlPanel:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, 0)
    controlPanel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    controlPanel:SetHeight(75)

    local controlTitle = OneWoW_GUI:CreateFS(controlPanel, 10)
    controlTitle:SetPoint("TOPLEFT", controlPanel, "TOPLEFT", 10, -8)
    controlTitle:SetText(L["NPCS_CONTROLS"] or "NPCs Controls")
    controlTitle:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local addTargetBtn = OneWoW_GUI:CreateFitTextButton(controlPanel, { text = L["BUTTON_ADD_TARGET"] or "Add Target", height = 25, minWidth = 80 })
    addTargetBtn:SetPoint("TOPLEFT", controlPanel, "TOPLEFT", 10, -28)
    addTargetBtn:SetScript("OnClick", function()
        if ns.NPCs then
            local npcInfo = ns.NPCs:GetTargetNPCInfo()
            if not npcInfo then
                print("|cFFFFD100OneWoW - NPCs:|r " .. (L["MSG_TARGET_NPC_FIRST"] or "Target an NPC first."))
                return
            end
            if ns.NPCs:GetNPC(npcInfo.id) then
                print("|cFFFFD100OneWoW - NPCs:|r " .. (L["MSG_NPC_EXISTS"] or "NPC note already exists."))
                return
            end
            ns.NPCs:AddNPC(npcInfo.id, npcInfo)
            print("|cFFFFD100OneWoW - NPCs:|r " .. string.format(L["MSG_NPC_ADDED"] or "Added: %s", npcInfo.name or npcInfo.id))
            parent.RefreshNPCsList()
            if parent.SelectNPC then parent.SelectNPC(npcInfo.id) end
        end
    end)
    addTargetBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["TOOLTIP_BUTTON_ADD_TARGET"] or "Add Target", 1, 1, 1)
        GameTooltip:AddLine(L["TOOLTIP_BUTTON_ADD_TARGET_NPC_DESC"] or "Add a note for your current NPC target.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    addTargetBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local addManualBtn = OneWoW_GUI:CreateFitTextButton(controlPanel, { text = L["BUTTON_MANUAL_ENTRY"] or "Manual", height = 25, minWidth = 70 })
    addManualBtn:SetPoint("LEFT", addTargetBtn, "RIGHT", 5, 0)
    addManualBtn:SetScript("OnClick", function()
        if ns.UI and ns.UI.ShowManualNPCEntryDialog then
            ns.UI.ShowManualNPCEntryDialog(parent)
        end
    end)
    addManualBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["BUTTON_MANUAL_ENTRY"] or "Manual Entry", 1, 1, 1)
        GameTooltip:AddLine(L["TOOLTIP_BUTTON_MANUAL_ENTRY_NPC_DESC"] or "Enter an NPC ID manually.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    addManualBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local catDD = ns.UI.CreateThemedDropdown(controlPanel, L["LABEL_CATEGORY"], 140, 25)
    catDD:SetPoint("LEFT", addManualBtn, "RIGHT", 8, 0)
    local function RefreshCatOpts()
        local opts = {{text = L["UI_ALL"], value = "All"}}
        if ns.NPCs then
            for _, c in ipairs(ns.NPCs:GetCategories()) do opts[#opts + 1] = {text = c, value = c} end
        end
        catDD:SetOptions(opts)
        catDD:SetSelected(categoryFilter)
    end
    RefreshCatOpts()
    catDD.onSelect = function(value)
        categoryFilter = value
        parent.RefreshNPCsList()
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
            ns.UI.ShowCategoryManager("npcs")
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
        parent.RefreshNPCsList()
    end

    local npcSortHandle = OneWoW_GUI:CreateSortControls(controlPanel, {
        sortFields = {
            {key = "name",     label = L["NOTE_SORT_NAME"]},
            {key = "zone",     label = L["NOTE_SORT_ZONE"]},
            {key = "category", label = L["NOTE_SORT_CATEGORY"]},
            {key = "manual",   label = L["NOTE_SORT_MANUAL"]},
        },
        defaultField  = currentSort.by,
        defaultAsc    = currentSort.ascending,
        dropdownWidth = 100,
        onChange = function(field, ascending)
            currentSort.by        = field
            currentSort.ascending = ascending
            local a = _G.OneWoW_Notes
            if a and a.db and a.db.global.tabSortPrefs then
                a.db.global.tabSortPrefs.npcs = { by = field, ascending = ascending }
            end
            parent.RefreshNPCsList()
        end,
    })
    npcSortHandle.dropdown:SetPoint("LEFT", storeDD, "RIGHT", 6, 0)
    npcSortHandle.dirBtn:SetPoint("LEFT", npcSortHandle.dropdown, "RIGHT", 4, 0)

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

    local listingTitle = OneWoW_GUI:CreateFS(listingPanel, 16)
    listingTitle:SetPoint("TOP", listingPanel, "TOP", 0, -10)
    listingTitle:SetText(L["NPCS_LIST"] or "NPCs")
    listingTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local searchBox = OneWoW_GUI:CreateEditBox(listingPanel, {
        placeholderText = L["UI_SEARCH_PLACEHOLDER"],
        onTextChanged = function(text)
            searchFilter = text
            if parent.RefreshNPCsList then parent.RefreshNPCsList() end
        end,
    })
    searchBox:SetPoint("TOPLEFT",  listingPanel, "TOPLEFT",  8, -30)
    searchBox:SetPoint("TOPRIGHT", listingPanel, "TOPRIGHT", -8, -30)

    local listScroll = ns.UI.CreateCustomScroll(listingPanel)
    scrollFrame = listScroll.scrollFrame
    scrollChild = listScroll.scrollChild
    listScroll.container:SetPoint("TOPLEFT",     listingPanel, "TOPLEFT",     10, -62)
    listScroll.container:SetPoint("BOTTOMRIGHT", listingPanel, "BOTTOMRIGHT", -10, 10)

    detailPanel = CreateThemedPanel(nil, parent)
    detailPanel:SetPoint("TOPLEFT",     listingPanel, "TOPRIGHT",    10, 0)
    detailPanel:SetPoint("BOTTOMRIGHT", parent,       "BOTTOMRIGHT",  0, 35)
    detailPanel:SetClipsChildren(true)

    emptyMessage = OneWoW_GUI:CreateFS(detailPanel, 16)
    emptyMessage:SetPoint("CENTER", detailPanel, "CENTER")
    emptyMessage:SetText(L["NPCS_SELECT"] or "Select an NPC to view their note.")
    emptyMessage:SetTextColor(0.6, 0.6, 0.7, 1)

    local leftStatusBar = CreateThemedBar(nil, parent)
    leftStatusBar:SetPoint("TOPLEFT",  listingPanel, "BOTTOMLEFT",  0, -5)
    leftStatusBar:SetPoint("TOPRIGHT", listingPanel, "BOTTOMRIGHT", 0, -5)
    leftStatusBar:SetHeight(25)

    leftStatusText = OneWoW_GUI:CreateFS(leftStatusBar, 10)
    leftStatusText:SetPoint("LEFT", leftStatusBar, "LEFT", 10, 0)
    leftStatusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    leftStatusText:SetText(string.format(L["UI_COUNT_FORMAT"], L["TAB_NPCS"], 0))

    local rightStatusBar = CreateThemedBar(nil, parent)
    rightStatusBar:SetPoint("TOPLEFT",     detailPanel, "BOTTOMLEFT",  0, -5)
    rightStatusBar:SetPoint("TOPRIGHT",    detailPanel, "BOTTOMRIGHT", 0, -5)
    rightStatusBar:SetHeight(25)

    local rightStatusText = OneWoW_GUI:CreateFS(rightStatusBar, 10)
    rightStatusText:SetPoint("LEFT", rightStatusBar, "LEFT", 10, 0)
    rightStatusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
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
            editorHeader:SetHeight(85)

            local portraitFrame = CreateFrame("Frame", nil, editorHeader, "BackdropTemplate")
            portraitFrame:SetSize(60, 60)
            portraitFrame:SetPoint("TOPLEFT", editorHeader, "TOPLEFT", 10, -10)
            portraitFrame:SetBackdrop(BACKDROP_EDGE)
            portraitFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

            local portrait = CreateFrame("PlayerModel", nil, portraitFrame)
            portrait:SetAllPoints(portraitFrame)
            portrait:SetCamera(0)
            portrait:SetPortraitZoom(0.8)
            editorHeader.portrait      = portrait
            editorHeader.portraitFrame = portraitFrame

            local nameText = OneWoW_GUI:CreateFS(editorHeader, 16)
            nameText:SetPoint("TOPLEFT",  portraitFrame, "TOPRIGHT",    10, 0)
            nameText:SetPoint("TOPRIGHT", editorHeader,  "TOPRIGHT",   -100, 0)
            nameText:SetJustifyH("LEFT")
            nameText:SetText("")
            nameText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            editorHeader.nameText = nameText

            local idText = OneWoW_GUI:CreateFS(editorHeader, 12)
            idText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -4)
            idText:SetText("")
            idText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            editorHeader.idText = idText

            local locationText = OneWoW_GUI:CreateFS(editorHeader, 10)
            locationText:SetPoint("TOPLEFT", idText, "BOTTOMLEFT", 0, -2)
            locationText:SetText("")
            locationText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            editorHeader.locationText = locationText

            local categoryLine = OneWoW_GUI:CreateFS(editorHeader, 10)
            categoryLine:SetPoint("BOTTOMRIGHT", editorHeader, "BOTTOMRIGHT", -12, 8)
            categoryLine:SetText("")
            categoryLine:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            categoryLine:SetJustifyH("RIGHT")
            editorHeader.categoryLine = categoryLine

            local ignoreIfDeadCheck = CreateFrame("CheckButton", nil, editorHeader, "InterfaceOptionsCheckButtonTemplate")
            ignoreIfDeadCheck:SetPoint("BOTTOMRIGHT", editorHeader, "BOTTOMRIGHT", -10, 26)
            if ignoreIfDeadCheck.Text then
                ignoreIfDeadCheck.Text:ClearAllPoints()
                ignoreIfDeadCheck.Text:SetPoint("RIGHT", ignoreIfDeadCheck, "LEFT", -2, 0)
                ignoreIfDeadCheck.Text:SetText(L["NPC_IGNORE_IF_DEAD"] or "Ignore if dead")
                ignoreIfDeadCheck.Text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
                ignoreIfDeadCheck.Text:SetJustifyH("RIGHT")
            end
            ignoreIfDeadCheck:SetScript("OnClick", function(self)
                if selectedNPC and ns.NPCs then
                    local nd = ns.NPCs:GetNPC(selectedNPC)
                    if nd then nd.ignoreIfDead = self:GetChecked() ns.NPCs:SaveNPC(selectedNPC, nd) end
                end
            end)
            ignoreIfDeadCheck:Hide()
            editorHeader.ignoreIfDeadCheck = ignoreIfDeadCheck

            local deleteBtn = CreateFrame("Button", nil, editorHeader)
            deleteBtn:SetSize(22, 22)
            deleteBtn:SetPoint("TOPRIGHT", editorHeader, "TOPRIGHT", -12, -12)
            deleteBtn:SetNormalTexture(MEDIA .. "icon-trash.png")
            deleteBtn:SetPushedTexture(MEDIA .. "icon-trash.png")
            deleteBtn:SetHighlightTexture(MEDIA .. "icon-trash.png")
            deleteBtn:GetHighlightTexture():SetAlpha(0.5)
            deleteBtn:SetScript("OnClick", function()
                if selectedNPC then
                    StaticPopupDialogs["ONEWOW_NOTES_CONFIRM_DELETE_NPC"] = {
                        text = string.format(L["POPUP_DELETE_NPC"] or "Delete NPC note?"),
                        button1 = L["BUTTON_DELETE"], button2 = L["BUTTON_CANCEL"],
                        OnAccept = function()
                            if ns.NPCs then
                                ns.NPCs:RemoveNPC(selectedNPC)
                                selectedNPC = nil
                                if detailPanel.editorContent then
                                    for _, f in pairs(detailPanel.editorContent) do
                                        if f and f.Hide then f:Hide() end
                                    end
                                end
                                parent.RefreshNPCsList()
                                emptyMessage:Show()
                            end
                        end,
                        timeout = 0, whileDead = true, hideOnEscape = true
                    }
                    StaticPopup_Show("ONEWOW_NOTES_CONFIRM_DELETE_NPC")
                end
            end)
            deleteBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["TOOLTIP_NPC_DELETE"] or "Delete NPC", 1, 1, 1)
                GameTooltip:AddLine(L["TOOLTIP_NPC_DELETE_DESC"] or "Remove this NPC note", 0.8, 0.8, 0.8, true)
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
                if selectedNPC and ns.UI and ns.UI.ShowNPCPropertiesDialog then
                    ns.UI.ShowNPCPropertiesDialog(selectedNPC, parent)
                end
            end)
            propertiesBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["TOOLTIP_NPC_PROPERTIES"] or "NPC Properties", 1, 1, 1)
                GameTooltip:AddLine(L["TOOLTIP_NPC_PROPERTIES_DESC"] or "Edit NPC settings", 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            propertiesBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            editorHeader.propertiesBtn = propertiesBtn

            local gotoBtn = CreateFrame("Button", nil, editorHeader)
            gotoBtn:SetSize(22, 22)
            gotoBtn:SetPoint("RIGHT", propertiesBtn, "LEFT", -2, 0)
            gotoBtn:SetNormalTexture(MEDIA .. "icon-compass.png")
            gotoBtn:SetPushedTexture(MEDIA .. "icon-compass.png")
            gotoBtn:SetHighlightTexture(MEDIA .. "icon-compass.png")
            gotoBtn:GetHighlightTexture():SetAlpha(0.5)
            gotoBtn:SetScript("OnClick", function()
                if selectedNPC and ns.NPCs then
                    local nd = ns.NPCs:GetNPC(selectedNPC)
                    if nd and nd.mapID and nd.coords then
                        ns.NPCs:CreateWaypoint(selectedNPC, nd)
                    else
                        print("|cFFFFD100OneWoW - NPCs:|r " .. (L["MSG_NPC_NO_LOCATION"] or "No location stored for this NPC."))
                    end
                end
            end)
            gotoBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["UI_NPC_GOTO_TITLE"] or "Create Waypoint", 1, 1, 1)
                GameTooltip:AddLine(L["UI_NPC_CREATE_WAYPOINT"] or "Set a TomTom/map waypoint for this NPC.", 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            gotoBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            editorHeader.gotoBtn = gotoBtn

            local alertBtn = CreateFrame("CheckButton", nil, editorHeader)
            alertBtn:SetSize(22, 22)
            alertBtn:SetPoint("RIGHT", gotoBtn, "LEFT", -2, 0)
            local aN = alertBtn:CreateTexture(nil, "BACKGROUND")
            aN:SetAllPoints() aN:SetTexture(MEDIA .. "icon-alert.png")
            aN:SetDesaturated(true) aN:SetAlpha(0.3)
            alertBtn:SetNormalTexture(aN)
            local aHL = alertBtn:CreateTexture(nil, "HIGHLIGHT")
            aHL:SetAllPoints() aHL:SetTexture(MEDIA .. "icon-alert.png") aHL:SetAlpha(0.5)
            alertBtn:SetHighlightTexture(aHL)
            alertBtn:SetScript("OnClick", function(self)
                if selectedNPC and ns.NPCs then
                    local nd = ns.NPCs:GetNPC(selectedNPC)
                    if nd then
                        nd.alertOnFound = not nd.alertOnFound
                        aN:SetDesaturated(not nd.alertOnFound)
                        aN:SetAlpha(nd.alertOnFound and 1.0 or 0.3)
                        self:SetChecked(nd.alertOnFound)
                        if editorHeader.ignoreIfDeadCheck then
                            if nd.alertOnFound then editorHeader.ignoreIfDeadCheck:Show()
                            else editorHeader.ignoreIfDeadCheck:Hide() end
                        end
                        ns.NPCs:SaveNPC(selectedNPC, nd)
                        parent.RefreshNPCsList()
                    end
                end
            end)
            alertBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["TOOLTIP_NPC_SOUND"] or "Alert on Target", 1, 1, 1)
                GameTooltip:AddLine(L["TOOLTIP_NPC_SOUND_DESC"] or "Alert when you target this NPC.", 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            alertBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            editorHeader.alertBtn = alertBtn

            local favoriteBtn = CreateFrame("CheckButton", nil, editorHeader)
            favoriteBtn:SetSize(22, 22)
            favoriteBtn:SetPoint("RIGHT", alertBtn, "LEFT", -2, 0)
            local fN = favoriteBtn:CreateTexture(nil, "BACKGROUND")
            fN:SetAllPoints() fN:SetTexture(MEDIA .. "icon-fav.png")
            fN:SetDesaturated(true) fN:SetAlpha(0.3)
            favoriteBtn:SetNormalTexture(fN)
            local fC = favoriteBtn:CreateTexture(nil, "BACKGROUND")
            fC:SetAllPoints() fC:SetTexture(MEDIA .. "icon-fav.png")
            favoriteBtn:SetCheckedTexture(fC)
            local fHL = favoriteBtn:CreateTexture(nil, "HIGHLIGHT")
            fHL:SetAllPoints() fHL:SetTexture(MEDIA .. "icon-fav.png") fHL:SetAlpha(0.5)
            favoriteBtn:SetHighlightTexture(fHL)
            favoriteBtn:SetScript("OnClick", function(self)
                if selectedNPC and ns.NPCs then
                    local nd = ns.NPCs:GetNPC(selectedNPC)
                    if nd then
                        nd.favorite = not nd.favorite
                        fN:SetDesaturated(not nd.favorite)
                        fN:SetAlpha(nd.favorite and 1.0 or 0.3)
                        self:SetChecked(nd.favorite)
                        ns.NPCs:SaveNPC(selectedNPC, nd)
                        parent.RefreshNPCsList()
                    end
                end
            end)
            favoriteBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["TOOLTIP_NPC_FAVORITE"] or "Favorite", 1, 1, 1)
                GameTooltip:AddLine(L["TOOLTIP_NPC_FAVORITE_DESC"] or "Mark as favorite", 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            favoriteBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            editorHeader.favoriteBtn = favoriteBtn

            local contentBg = CreateThemedBar(nil, detailPanel)
            contentBg:SetPoint("TOPLEFT",  editorHeader, "BOTTOMLEFT",  0, -10)
            contentBg:SetPoint("TOPRIGHT", editorHeader, "BOTTOMRIGHT", 0, -10)
            contentBg:SetHeight(160)
            contentBg:EnableMouse(true)

            local contentScroll, contentScrollChild = OneWoW_GUI:CreateScrollFrame(contentBg, {})
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
                if userInput and selectedNPC and ns.NPCs then
                    local nd = ns.NPCs:GetNPC(selectedNPC)
                    if nd then nd.content = self:GetText() nd.modified = GetServerTime() end
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

            local ttLabel = OneWoW_GUI:CreateFS(tooltipSection, 12)
            ttLabel:SetPoint("TOPLEFT", tooltipSection, "TOPLEFT", 10, -8)
            ttLabel:SetText(L["UI_TOOLTIP_LINES"] or "Tooltip Lines:")
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
                edit:SetScript("OnHyperlinkClick", function(self, link, text, button)
                    SetItemRef(link, text, button)
                end)
                edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
                edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
                edit:SetScript("OnTextChanged", function(self, userInput)
                    if userInput and selectedNPC and ns.NPCs then
                        local nd = ns.NPCs:GetNPC(selectedNPC)
                        if nd then
                            if not nd.tooltipLines then nd.tooltipLines = {"","","",""} end
                            nd.tooltipLines[i] = self:GetText()
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
        ns.UI.activeContentEditBox = detailPanel.contentEditBox

        if selectedNPC and ns.NPCs then
            local nd = ns.NPCs:GetNPC(selectedNPC)
            if nd then
                local header = detailPanel.editorContent.header

                if header.nameText then
                    header.nameText:SetText(nd.name or ("NPC " .. selectedNPC))
                end
                if header.idText then
                    local idStr = "ID: " .. selectedNPC
                    if nd.zone and nd.zone ~= "" then idStr = idStr .. "  Zone: " .. nd.zone end
                    header.idText:SetText(idStr)
                end
                if header.locationText then
                    if nd.mapID and nd.coords then
                        header.locationText:SetText(string.format("Map %d  %.1f, %.1f", nd.mapID, nd.coords.x, nd.coords.y))
                        header.locationText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
                    else
                        header.locationText:SetText(L["MSG_NPC_NO_LOCATION"] or "Location not recorded")
                        header.locationText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                    end
                end
                if header.categoryLine then
                    header.categoryLine:SetText(string.format(L["UI_CATEGORY_WITH_VALUE"], nd.category or "Other"))
                end
                if header.alertBtn then
                    header.alertBtn:GetNormalTexture():SetDesaturated(not nd.alertOnFound)
                    header.alertBtn:GetNormalTexture():SetAlpha(nd.alertOnFound and 1.0 or 0.3)
                    header.alertBtn:SetChecked(nd.alertOnFound)
                end
                if header.ignoreIfDeadCheck then
                    if nd.alertOnFound then
                        header.ignoreIfDeadCheck:SetChecked(nd.ignoreIfDead or false)
                        header.ignoreIfDeadCheck:Show()
                    else
                        header.ignoreIfDeadCheck:Hide()
                    end
                end
                if header.favoriteBtn then
                    header.favoriteBtn:GetNormalTexture():SetDesaturated(not nd.favorite)
                    header.favoriteBtn:GetNormalTexture():SetAlpha(nd.favorite and 1.0 or 0.3)
                    header.favoriteBtn:SetChecked(nd.favorite)
                end

                if header.portrait and type(selectedNPC) == "number" and selectedNPC > 0 and selectedNPC <= 2147483647 then
                    C_Timer.After(0.1, function()
                        if header.portrait and header.portrait.SetCreature then
                            header.portrait:SetCreature(selectedNPC)
                        end
                    end)
                end

                if detailPanel.contentEditBox then
                    detailPanel.contentEditBox:SetText(nd.content or "")
                end
                if detailPanel.editorContent.tooltipEdits and nd.tooltipLines then
                    for i = 1, 4 do
                        if detailPanel.editorContent.tooltipEdits[i] then
                            detailPanel.editorContent.tooltipEdits[i]:SetText(nd.tooltipLines[i] or "")
                        end
                    end
                end
            end
        end
    end

    function parent.SelectNPC(npcID)
        selectedNPC = tonumber(npcID)
        ShowEditor()
        parent.RefreshNPCsList()
    end

    parent:HookScript("OnShow", function()
        local notes = _G.OneWoW_Notes
        if notes and notes.pendingNPCSelect then
            local id = notes.pendingNPCSelect
            notes.pendingNPCSelect = nil
            parent.SelectNPC(id)
        end
    end)

    function parent.RefreshNPCsList()
        for _, item in pairs(npcListItems) do item:Hide() end
        npcListItems = {}

        if not ns.NPCs then
            if leftStatusText then leftStatusText:SetText(string.format(L["UI_COUNT_FORMAT"], L["TAB_NPCS"], 0)) end
            return
        end

        local allNPCs = ns.NPCs:GetAllNPCs()
        local npcsList = {}
        local now = GetServerTime()

        for npcID, nd in pairs(allNPCs) do
            if type(nd) == "table" then
                if nd.isNew and nd.newTimestamp and (now - nd.newTimestamp) > 3600 then
                    nd.isNew = false nd.newTimestamp = nil
                end
                local matches = true
                if categoryFilter ~= "All" and nd.category ~= categoryFilter then matches = false end
                if storageFilter  ~= "All" and nd.storage  ~= storageFilter  then matches = false end
                if searchFilter ~= "" then
                    local nameLower = (nd.name or tostring(npcID)):lower()
                    if not nameLower:find(searchFilter:lower(), 1, true) then matches = false end
                end
                if matches then table.insert(npcsList, {id = npcID, data = nd}) end
            end
        end

        local newNPCs   = {}
        local favorites = {}
        local regular   = {}
        for _, n in ipairs(npcsList) do
            if n.data.isNew then table.insert(newNPCs, n)
            elseif n.data.favorite then table.insert(favorites, n)
            else table.insert(regular, n) end
        end

        local function sortNPCs(a, b)
            local nameA = a.data.name or ("NPC " .. tostring(a.id))
            local nameB = b.data.name or ("NPC " .. tostring(b.id))
            if currentSort.by == "zone" then
                local za = a.data.zone or ""
                local zb = b.data.zone or ""
                if za == zb then return nameA < nameB end
                if currentSort.ascending then return za < zb else return za > zb end
            elseif currentSort.by == "category" then
                local ca = a.data.category or ""
                local cb = b.data.category or ""
                if ca == cb then return nameA < nameB end
                if currentSort.ascending then return ca < cb else return ca > cb end
            elseif currentSort.by == "modified" then
                if currentSort.ascending then return (a.data.modified or 0) < (b.data.modified or 0)
                else return (a.data.modified or 0) > (b.data.modified or 0) end
            elseif currentSort.by == "manual" then
                local sa = a.data.sortOrder or 0
                local sb = b.data.sortOrder or 0
                if sa == sb then return nameA < nameB end
                if currentSort.ascending then return sa < sb else return sa > sb end
            else
                if currentSort.ascending then return nameA < nameB else return nameA > nameB end
            end
        end
        table.sort(newNPCs,   sortNPCs)
        table.sort(favorites, sortNPCs)
        table.sort(regular,   sortNPCs)

        local function BuildNPCRow(npc, yOffset, groupArray, groupIndex)
            local row = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
            row:SetSize(scrollChild:GetWidth(), 50)
            row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yOffset)
            row:SetBackdrop(BACKDROP_INNER_NO_INSETS)
            row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

            local nameText = OneWoW_GUI:CreateFS(row, 12)
            nameText:SetPoint("TOPLEFT",  row, "TOPLEFT",  10, -10)
            nameText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -27, -10)
            nameText:SetJustifyH("LEFT")
            nameText:SetText(npc.data.name or ("NPC " .. tostring(npc.id)))
            nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

            local subText = OneWoW_GUI:CreateFS(row, 10)
            subText:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 10, 8)
            subText:SetText(npc.data.zone or "")
            subText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

            local deleteBtn = CreateFrame("Button", nil, row)
            deleteBtn:SetSize(18, 18)
            deleteBtn:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -27, 5)
            deleteBtn:SetNormalTexture(MEDIA .. "icon-trash.png")
            deleteBtn:SetPushedTexture(MEDIA .. "icon-trash.png")
            deleteBtn:SetHighlightTexture(MEDIA .. "icon-trash.png")
            deleteBtn:GetHighlightTexture():SetAlpha(0.5)
            deleteBtn:SetScript("OnClick", function()
                StaticPopupDialogs["ONEWOW_NOTES_CONFIRM_DELETE_NPC"] = {
                    text = L["POPUP_DELETE_NPC"] or "Delete NPC note?",
                    button1 = L["BUTTON_DELETE"], button2 = L["BUTTON_CANCEL"],
                    OnAccept = function()
                        if ns.NPCs then
                            ns.NPCs:RemoveNPC(npc.id)
                            if selectedNPC == npc.id then
                                selectedNPC = nil
                                emptyMessage:Show()
                                if detailPanel.editorContent then
                                    for _, f in pairs(detailPanel.editorContent) do
                                        if f and f.Hide then f:Hide() end
                                    end
                                end
                            end
                            parent.RefreshNPCsList()
                        end
                    end,
                    timeout = 0, whileDead = true, hideOnEscape = true,
                }
                StaticPopup_Show("ONEWOW_NOTES_CONFIRM_DELETE_NPC")
            end)

            local propBtn = CreateFrame("Button", nil, row)
            propBtn:SetSize(18, 18)
            propBtn:SetPoint("RIGHT", deleteBtn, "LEFT", -2, 0)
            propBtn:SetNormalTexture(MEDIA .. "icon-gears.png")
            propBtn:SetPushedTexture(MEDIA .. "icon-gears.png")
            propBtn:SetHighlightTexture(MEDIA .. "icon-gears.png")
            propBtn:GetHighlightTexture():SetAlpha(0.5)
            propBtn:SetScript("OnClick", function()
                if ns.UI.ShowNPCPropertiesDialog then ns.UI.ShowNPCPropertiesDialog(npc.id, parent) end
            end)

            local gotoBtn2 = CreateFrame("Button", nil, row)
            gotoBtn2:SetSize(18, 18)
            gotoBtn2:SetPoint("RIGHT", propBtn, "LEFT", -2, 0)
            gotoBtn2:SetNormalTexture(MEDIA .. "icon-compass.png")
            gotoBtn2:SetPushedTexture(MEDIA .. "icon-compass.png")
            gotoBtn2:SetHighlightTexture(MEDIA .. "icon-compass.png")
            gotoBtn2:GetHighlightTexture():SetAlpha(0.5)
            gotoBtn2:SetScript("OnClick", function()
                if ns.NPCs then
                    local nd = ns.NPCs:GetNPC(npc.id)
                    if nd and nd.mapID and nd.coords then
                        ns.NPCs:CreateWaypoint(npc.id, nd)
                    else
                        print("|cFFFFD100OneWoW - NPCs:|r " .. (L["MSG_NPC_NO_LOCATION"] or "No location stored."))
                    end
                end
            end)

            local alertBtn2 = CreateFrame("CheckButton", nil, row)
            alertBtn2:SetSize(18, 18)
            alertBtn2:SetPoint("RIGHT", gotoBtn2, "LEFT", -2, 0)
            local aN2 = alertBtn2:CreateTexture(nil, "BACKGROUND")
            aN2:SetAllPoints() aN2:SetTexture(MEDIA .. "icon-alert.png")
            aN2:SetDesaturated(not npc.data.alertOnFound)
            aN2:SetAlpha(npc.data.alertOnFound and 1.0 or 0.3)
            alertBtn2:SetNormalTexture(aN2)
            alertBtn2:SetScript("OnClick", function(self)
                if ns.NPCs then
                    local nd = ns.NPCs:GetNPC(npc.id)
                    if nd then
                        nd.alertOnFound = not nd.alertOnFound
                        aN2:SetDesaturated(not nd.alertOnFound)
                        aN2:SetAlpha(nd.alertOnFound and 1.0 or 0.3)
                        ns.NPCs:SaveNPC(npc.id, nd)
                        if selectedNPC == npc.id and detailPanel.editorContent and detailPanel.editorContent.header then
                            local h = detailPanel.editorContent.header
                            if h.alertBtn then
                                h.alertBtn:GetNormalTexture():SetDesaturated(not nd.alertOnFound)
                                h.alertBtn:GetNormalTexture():SetAlpha(nd.alertOnFound and 1.0 or 0.3)
                                h.alertBtn:SetChecked(nd.alertOnFound)
                            end
                            if h.ignoreIfDeadCheck then
                                if nd.alertOnFound then h.ignoreIfDeadCheck:Show() else h.ignoreIfDeadCheck:Hide() end
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
            fN2:SetDesaturated(not npc.data.favorite)
            fN2:SetAlpha(npc.data.favorite and 1.0 or 0.3)
            favBtn2:SetNormalTexture(fN2)
            favBtn2:SetScript("OnClick", function(self)
                if ns.NPCs then
                    local nd = ns.NPCs:GetNPC(npc.id)
                    if nd then
                        nd.favorite = not nd.favorite
                        fN2:SetDesaturated(not nd.favorite)
                        fN2:SetAlpha(nd.favorite and 1.0 or 0.3)
                        ns.NPCs:SaveNPC(npc.id, nd)
                        parent.RefreshNPCsList()
                    end
                end
            end)

            local canMoveUp   = groupArray ~= nil and groupIndex ~= nil and groupIndex > 1
            local canMoveDown = groupArray ~= nil and groupIndex ~= nil and groupIndex < #groupArray

            local upBtn = CreateFrame("Button", nil, row)
            upBtn:SetSize(18, 22)
            upBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", -4, -3)
            upBtn:SetNormalAtlas("common-button-collapseExpand-up")
            upBtn:SetHighlightAtlas("common-button-collapseExpand-up")
            if upBtn:GetNormalTexture()    then upBtn:GetNormalTexture():SetVertexColor(1, 0.82, 0, 1) end
            if upBtn:GetHighlightTexture() then upBtn:GetHighlightTexture():SetVertexColor(1, 1, 0, 0.7) end
            if canMoveUp then upBtn:Show() else upBtn:Hide() end
            upBtn:SetScript("OnClick", function()
                if not canMoveUp then return end
                if currentSort.by ~= "manual" then
                    currentSort.by = "manual"
                    currentSort.ascending = true
                    npcSortHandle:SetSort("manual", true)
                    local a = _G.OneWoW_Notes
                    if a and a.db and a.db.global.tabSortPrefs then
                        a.db.global.tabSortPrefs.npcs = { by = "manual", ascending = true }
                    end
                end
                for i, item in ipairs(groupArray) do item.data.sortOrder = i end
                groupArray[groupIndex].data.sortOrder     = groupIndex - 1
                groupArray[groupIndex - 1].data.sortOrder = groupIndex
                parent.RefreshNPCsList()
            end)

            local downBtn = CreateFrame("Button", nil, row)
            downBtn:SetSize(18, 22)
            downBtn:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -4, 3)
            downBtn:SetNormalAtlas("common-button-collapseExpand-down")
            downBtn:SetHighlightAtlas("common-button-collapseExpand-down")
            if downBtn:GetNormalTexture()    then downBtn:GetNormalTexture():SetVertexColor(1, 0.82, 0, 1) end
            if downBtn:GetHighlightTexture() then downBtn:GetHighlightTexture():SetVertexColor(1, 1, 0, 0.7) end
            if canMoveDown then downBtn:Show() else downBtn:Hide() end
            downBtn:SetScript("OnClick", function()
                if not canMoveDown then return end
                if currentSort.by ~= "manual" then
                    currentSort.by = "manual"
                    currentSort.ascending = true
                    npcSortHandle:SetSort("manual", true)
                    local a = _G.OneWoW_Notes
                    if a and a.db and a.db.global.tabSortPrefs then
                        a.db.global.tabSortPrefs.npcs = { by = "manual", ascending = true }
                    end
                end
                for i, item in ipairs(groupArray) do item.data.sortOrder = i end
                groupArray[groupIndex].data.sortOrder     = groupIndex + 1
                groupArray[groupIndex + 1].data.sortOrder = groupIndex
                parent.RefreshNPCsList()
            end)

            row:EnableMouse(true)
            row:SetScript("OnMouseDown", function()
                selectedNPC = npc.id
                ShowEditor()
                parent.RefreshNPCsList()
            end)
            row:SetScript("OnEnter", function(self)
                if selectedNPC ~= npc.id then self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER")) end
            end)
            row:SetScript("OnLeave", function(self)
                if selectedNPC ~= npc.id then self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY")) end
            end)
            if selectedNPC == npc.id then
                row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
                row:SetBackdropBorderColor(1, 0.82, 0, 1)
            end

            table.insert(npcListItems, row)
        end

        local yOffset = 0

        if #newNPCs > 0 then
            local sh = OneWoW_GUI:CreateSectionHeader(scrollChild, { title = L["NOTES_SECTION_NEW"] or "New", yOffset = yOffset })
            table.insert(npcListItems, sh)
            yOffset = yOffset - 30
        end
        for i, n in ipairs(newNPCs) do BuildNPCRow(n, yOffset, newNPCs, i) yOffset = yOffset - 55 end

        if #favorites > 0 then
            local sh = OneWoW_GUI:CreateSectionHeader(scrollChild, { title = L["NOTES_SECTION_FAVORITES"] or "Favorites", yOffset = yOffset })
            table.insert(npcListItems, sh)
            yOffset = yOffset - 30
        end
        for i, n in ipairs(favorites) do BuildNPCRow(n, yOffset, favorites, i) yOffset = yOffset - 55 end

        if #regular > 0 then
            local sh = OneWoW_GUI:CreateSectionHeader(scrollChild, { title = L["TAB_NPCS"], yOffset = yOffset })
            table.insert(npcListItems, sh)
            yOffset = yOffset - 30
        end
        for i, n in ipairs(regular) do BuildNPCRow(n, yOffset, regular, i) yOffset = yOffset - 55 end

        scrollChild:SetHeight(math.abs(yOffset) + 50)
        if leftStatusText then
            leftStatusText:SetText(string.format(L["UI_COUNT_FORMAT"], L["TAB_NPCS"], #newNPCs + #favorites + #regular))
        end
    end

    parent.RefreshNPCsList()
end

local function MakeNPCLabel(parent, text, x, y)
    local lbl = OneWoW_GUI:CreateFS(parent, 12)
    lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    lbl:SetText(text)
    lbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    return lbl
end

local function MakeNPCInput(parent, x, y, w)
    local input = OneWoW_GUI:CreateEditBox(parent, {
        width = w,
        height = 26,
    })
    input:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    input:SetFontObject("GameFontNormal")
    input:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    input:SetTextInsets(6, 6, 4, 4)
    input.placeholderText = ""
    input:SetText("")
    input:SetScript("OnEditFocusGained", function(self)
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
    end)
    input:SetScript("OnEditFocusLost", function(self)
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    end)
    input:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return input
end

function ns.UI.ShowManualNPCEntryDialog(refreshParent)
    local COL1_X  = 10
    local COL2_X  = 260
    local COL_W   = 230
    local ROW_H   = 50
    local LBL_GAP = 18

    local dialog = ns.UI.CreateThemedDialog({
        name           = "OneWoW_NotesManualNPCEntry",
        title          = L["NPC_MANUAL_ENTRY_TITLE"] or "Add NPC",
        width          = 500,
        height         = 420,
        destroyOnClose = true,
        buttons = {
            {
                text = L["BUTTON_ADD_NOTE"] or "Add",
                onClick = function(dlg)
                    local npcName = dlg._nameInput and dlg._nameInput:GetText() or ""
                    local npcIDText = dlg._idInput and dlg._idInput:GetText() or ""
                    local npcID = tonumber(npcIDText)

                    if npcName == "" then
                        print("|cFFFFD100OneWoW - NPCs:|r " .. (L["NPC_ERROR_NAME_REQUIRED"] or "NPC name is required."))
                        return
                    end

                    if not npcID or npcID <= 0 then
                        npcID = math.floor(GetServerTime() * 1000 + math.random(100, 999))
                    end

                    if ns.NPCs and ns.NPCs:GetNPC(npcID) then
                        print("|cFFFFD100OneWoW - NPCs:|r " .. (L["MSG_NPC_EXISTS"] or "NPC note already exists."))
                        return
                    end

                    local cat   = dlg._catDD   and dlg._catDD:GetValue()   or "Other"
                    local store = dlg._storeDD and dlg._storeDD:GetValue() or "account"
                    local noteContent = dlg._noteEditBox and dlg._noteEditBox:GetText() or ""

                    if ns.NPCs then
                        ns.NPCs:AddNPC(npcID, {
                            name = npcName, category = cat, storage = store,
                            content = noteContent,
                        })
                        print("|cFFFFD100OneWoW - NPCs:|r " .. string.format(L["MSG_NPC_ADDED"] or "Added NPC: %s", npcName))
                        dlg:Hide()
                        if refreshParent and refreshParent.RefreshNPCsList then refreshParent.RefreshNPCsList() end
                        if refreshParent and refreshParent.SelectNPC then refreshParent.SelectNPC(npcID) end
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

    MakeNPCLabel(content, L["NPC_LABEL_NAME"] or "NPC Name:", COL1_X, yPos)
    dialog._nameInput = MakeNPCInput(content, COL1_X, yPos - LBL_GAP, COL_W)
    dialog._nameInput:SetAutoFocus(true)

    MakeNPCLabel(content, L["LABEL_NPC_ID"] or "NPC ID:", COL2_X, yPos)
    dialog._idInput = MakeNPCInput(content, COL2_X, yPos - LBL_GAP, COL_W)
    dialog._idInput:SetNumeric(true)
    dialog._idInput:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["LABEL_NPC_ID"] or "NPC ID", 1, 1, 1)
        GameTooltip:AddLine(L["NPC_ID_TOOLTIP"] or "Leave blank to auto-generate. Find IDs on WoWHead.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    dialog._idInput:SetScript("OnLeave", function() GameTooltip:Hide() end)
    yPos = yPos - ROW_H

    MakeNPCLabel(content, L["LABEL_CATEGORY"], COL1_X, yPos)
    local catDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    catDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos - LBL_GAP)
    local catOpts = {}
    if ns.NPCs then
        for _, c in ipairs(ns.NPCs:GetCategories()) do
            catOpts[#catOpts + 1] = {text = c, value = c}
        end
    end
    catDD:SetOptions(catOpts)
    catDD:SetSelected("Other")
    dialog._catDD = catDD

    MakeNPCLabel(content, L["LABEL_STORAGE"], COL2_X, yPos)
    local storeDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    storeDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL2_X, yPos - LBL_GAP)
    storeDD:SetOptions({
        {text = L["STORAGE_ACCOUNT_WIDE"],   value = "account"},
        {text = L["STORAGE_TYPE_CHARACTER"], value = "character"},
    })
    storeDD:SetSelected("account")
    dialog._storeDD = storeDD
    yPos = yPos - ROW_H

    MakeNPCLabel(content, L["LABEL_NOTE_CONTENT"] or "Note:", COL1_X, yPos)
    yPos = yPos - LBL_GAP

    local noteBg = CreateThemedBar(nil, content)
    noteBg:SetPoint("TOPLEFT",     content, "TOPLEFT",     COL1_X, yPos)
    noteBg:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -COL1_X, 6)

    local noteScroll, noteScrollChild = OneWoW_GUI:CreateScrollFrame(noteBg, {})
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

function ns.UI.ShowNPCPropertiesDialog(npcID, refreshParent)
    if not npcID or not ns.NPCs then return end
    npcID = tonumber(npcID)
    if not npcID then return end
    local nd = ns.NPCs:GetNPC(npcID)
    if not nd then return end

    local COL1_X  = 10
    local COL2_X  = 260
    local COL_W   = 230
    local ROW_H   = 50
    local LBL_GAP = 18

    local dialog = ns.UI.CreateThemedDialog({
        name           = "OneWoW_NotesNPCProperties",
        title          = L["DIALOG_NPC_PROPERTIES"] .. ": " .. (nd.name or "NPC ") .. npcID,
        width          = 500,
        height         = 520,
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
        local d = ns.NPCs:GetNPC(npcID)
        if d then
            d[field] = value
            ns.NPCs:SaveNPC(npcID, d)
        end
        if refreshParent and refreshParent.RefreshNPCsList then refreshParent.RefreshNPCsList() end
    end

    local zoneDisplay

    MakeNPCLabel(content, L["NPC_LABEL_NAME"] or "NPC Name:", COL1_X, yPos)
    local nameInput = MakeNPCInput(content, COL1_X, yPos - LBL_GAP, COL_W)
    nameInput:SetText(nd.name or "")
    nameInput:SetScript("OnEnterPressed", function(self)
        local newName = self:GetText()
        if newName ~= "" then SaveField("name", newName) end
        self:ClearFocus()
    end)

    MakeNPCLabel(content, L["LABEL_NPC_ID"] or "NPC ID:", COL2_X, yPos)
    local idInput = MakeNPCInput(content, COL2_X, yPos - LBL_GAP, 120)
    idInput:SetNumeric(true)
    idInput:SetText(tostring(npcID))
    idInput:SetScript("OnEnterPressed", function(self)
        local newID = tonumber(self:GetText())
        if not newID or newID <= 0 then
            self:SetText(tostring(npcID))
            self:ClearFocus()
            return
        end
        if newID == npcID then self:ClearFocus() return end
        if ns.NPCs:GetNPC(newID) then
            print("|cFFFFD100OneWoW - NPCs:|r " .. (L["MSG_NPC_ID_EXISTS"] or "An NPC with that ID already exists."))
            self:SetText(tostring(npcID))
            self:ClearFocus()
            return
        end
        local d = ns.NPCs:GetNPC(npcID)
        if d then
            ns.NPCs:RemoveNPC(npcID)
            ns.NPCs:AddNPC(newID, d)
            npcID = newID
            if refreshParent and refreshParent.RefreshNPCsList then refreshParent.RefreshNPCsList() end
        end
        self:ClearFocus()
    end)
    idInput:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["LABEL_NPC_ID"] or "NPC ID", 1, 1, 1)
        GameTooltip:AddLine(L["NPC_ID_EDIT_TOOLTIP"] or "Change the NPC ID. Find correct IDs on WoWHead.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    idInput:SetScript("OnLeave", function() GameTooltip:Hide() end)
    yPos = yPos - ROW_H

    MakeNPCLabel(content, L["NPC_LABEL_ZONE"] or "Zone:", COL1_X, yPos)
    zoneDisplay = OneWoW_GUI:CreateFS(content, 12)
    zoneDisplay:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos - 20)
    zoneDisplay:SetText(nd.zone or "?")
    zoneDisplay:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    MakeNPCLabel(content, L["NPC_LABEL_MAP_ID"] or "Map ID:", COL2_X, yPos)
    local mapIDInput = MakeNPCInput(content, COL2_X, yPos - LBL_GAP, 100)
    mapIDInput:SetNumeric(true)
    mapIDInput:SetText(nd.mapID and tostring(nd.mapID) or "")
    mapIDInput:SetScript("OnEnterPressed", function(self)
        local newMapID = tonumber(self:GetText())
        if newMapID then
            SaveField("mapID", newMapID)
            local mapInfo = C_Map.GetMapInfo(newMapID)
            if mapInfo then
                SaveField("zone", mapInfo.name)
                if zoneDisplay then zoneDisplay:SetText(mapInfo.name) end
            end
        end
        self:ClearFocus()
    end)
    yPos = yPos - ROW_H

    MakeNPCLabel(content, L["NPC_LABEL_COORD_X"] or "Coord X:", COL1_X, yPos)
    local xInput = MakeNPCInput(content, COL1_X, yPos - LBL_GAP, 100)
    xInput:SetText(nd.coords and string.format("%.1f", nd.coords.x) or "")
    xInput:SetScript("OnEnterPressed", function(self)
        local newX = tonumber(self:GetText())
        if newX then
            local d = ns.NPCs:GetNPC(npcID)
            if d then
                if not d.coords then d.coords = {x = 0, y = 0} end
                d.coords.x = newX
                d.modified = GetServerTime()
                ns.NPCs:SaveNPC(npcID, d)
            end
            if refreshParent and refreshParent.RefreshNPCsList then refreshParent.RefreshNPCsList() end
        end
        self:ClearFocus()
    end)

    MakeNPCLabel(content, L["NPC_LABEL_COORD_Y"] or "Coord Y:", COL2_X, yPos)
    local yInput = MakeNPCInput(content, COL2_X, yPos - LBL_GAP, 100)
    yInput:SetText(nd.coords and string.format("%.1f", nd.coords.y) or "")
    yInput:SetScript("OnEnterPressed", function(self)
        local newY = tonumber(self:GetText())
        if newY then
            local d = ns.NPCs:GetNPC(npcID)
            if d then
                if not d.coords then d.coords = {x = 0, y = 0} end
                d.coords.y = newY
                d.modified = GetServerTime()
                ns.NPCs:SaveNPC(npcID, d)
            end
            if refreshParent and refreshParent.RefreshNPCsList then refreshParent.RefreshNPCsList() end
        end
        self:ClearFocus()
    end)

    local setLocBtn = OneWoW_GUI:CreateFitTextButton(content, { text = L["NPC_SET_CURRENT"] or "Set Current", height = 25, minWidth = 80 })
    setLocBtn:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X + 110, yPos - LBL_GAP)
    setLocBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
        self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["NPC_SET_CURRENT"] or "Set Current", 1, 1, 1)
        GameTooltip:AddLine(L["NPC_SET_CURRENT_DESC"] or "Set location to your current position.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    setLocBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
        self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        GameTooltip:Hide()
    end)
    setLocBtn:SetScript("OnClick", function()
        local mapID = C_Map.GetBestMapForUnit("player")
        local coords = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
        if mapID and coords then
            local d = ns.NPCs:GetNPC(npcID)
            if d then
                d.mapID = mapID
                d.coords = {x = coords.x * 100, y = coords.y * 100}
                local mapInfo = C_Map.GetMapInfo(mapID)
                if mapInfo then d.zone = mapInfo.name end
                d.modified = GetServerTime()
                ns.NPCs:SaveNPC(npcID, d)
                mapIDInput:SetText(tostring(mapID))
                xInput:SetText(string.format("%.1f", d.coords.x))
                yInput:SetText(string.format("%.1f", d.coords.y))
                if zoneDisplay then zoneDisplay:SetText(d.zone or "?") end
                if refreshParent and refreshParent.RefreshNPCsList then refreshParent.RefreshNPCsList() end
            end
        end
    end)
    yPos = yPos - ROW_H

    MakeNPCLabel(content, L["LABEL_CATEGORY"], COL1_X, yPos)
    local catDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    catDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos - LBL_GAP)
    local catOpts = {}
    if ns.NPCs then
        for _, c in ipairs(ns.NPCs:GetCategories()) do
            catOpts[#catOpts + 1] = {text = c, value = c}
        end
    end
    catDD:SetOptions(catOpts)
    catDD:SetSelected(nd.category or "Other")
    catDD.onSelect = function(value) SaveField("category", value) end

    MakeNPCLabel(content, L["LABEL_STORAGE"], COL2_X, yPos)
    local storeDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    storeDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL2_X, yPos - LBL_GAP)
    storeDD:SetOptions({
        {text = L["STORAGE_ACCOUNT_WIDE"],   value = "account"},
        {text = L["STORAGE_TYPE_CHARACTER"], value = "character"},
    })
    storeDD:SetSelected(nd.storage or "account")
    storeDD.onSelect = function(value)
        local d = ns.NPCs:GetNPC(npcID)
        if d then
            local oldDB = ns.NPCs:GetNotesDB(d.storage or "account")
            if oldDB then oldDB[npcID] = nil end
            d.storage = value
            ns.NPCs:SaveNPC(npcID, d)
        end
        if refreshParent and refreshParent.RefreshNPCsList then refreshParent.RefreshNPCsList() end
    end
    yPos = yPos - ROW_H

    local alertCB = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    alertCB:SetSize(22, 22)
    alertCB:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos)
    alertCB.Text:SetText(L["TOOLTIP_NPC_SOUND"] or "Alert on Target")
    alertCB.Text:SetFontObject("GameFontNormal")
    alertCB:SetChecked(nd.alertOnFound or false)
    alertCB:SetScript("OnClick", function(self)
        SaveField("alertOnFound", self:GetChecked())
    end)
    alertCB:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["TOOLTIP_NPC_SOUND"] or "Alert on Target", 1, 1, 1)
        GameTooltip:AddLine(L["TOOLTIP_NPC_SOUND_DESC"] or "Play a sound alert when you target this NPC.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    alertCB:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local ignoreCB = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    ignoreCB:SetSize(22, 22)
    ignoreCB:SetPoint("TOPLEFT", content, "TOPLEFT", COL2_X, yPos)
    ignoreCB.Text:SetText(L["NPC_IGNORE_IF_DEAD"] or "Ignore if dead")
    ignoreCB.Text:SetFontObject("GameFontNormal")
    ignoreCB:SetChecked(nd.ignoreIfDead or false)
    ignoreCB:SetScript("OnClick", function(self)
        SaveField("ignoreIfDead", self:GetChecked())
    end)
    ignoreCB:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["NPC_IGNORE_IF_DEAD"] or "Ignore if dead", 1, 1, 1)
        GameTooltip:AddLine(L["NPC_IGNORE_IF_DEAD_DESC"] or "Do not alert if this NPC is dead when targeted.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    ignoreCB:SetScript("OnLeave", function() GameTooltip:Hide() end)
    yPos = yPos - 30

    MakeNPCLabel(content, L["LABEL_NOTE_PREVIEW"] or "Note:", COL1_X, yPos)
    yPos = yPos - LBL_GAP

    local noteBg = CreateThemedBar(nil, content)
    noteBg:SetPoint("TOPLEFT",     content, "TOPLEFT",     COL1_X, yPos)
    noteBg:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -COL1_X, 6)

    local noteScroll, noteScrollChild = OneWoW_GUI:CreateScrollFrame(noteBg, {})
    noteScroll:SetPoint("TOPLEFT",     noteBg, "TOPLEFT",     4, -4)
    noteScroll:SetPoint("BOTTOMRIGHT", noteBg, "BOTTOMRIGHT", -26, 4)

    local noteEditBox = CreateFrame("EditBox", nil, noteScroll)
    noteEditBox:SetMultiLine(true)
    noteEditBox:SetFontObject("ChatFontNormal")
    noteEditBox:SetAutoFocus(false)
    noteEditBox:SetMaxLetters(0)
    noteEditBox:SetText(nd.content or "")
    noteEditBox:EnableMouse(false)
    noteScroll:SetScrollChild(noteEditBox)
    noteScroll:HookScript("OnSizeChanged", function(self, w)
        noteEditBox:SetWidth(math.max(1, w))
    end)

    dialog:Show()
end
