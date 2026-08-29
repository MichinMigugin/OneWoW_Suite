local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI

local BACKDROP_EDGE = OneWoW_GUI.Constants.BACKDROP_EDGE

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
local scrollChild    = nil

local MEDIA = OneWoW_GUI.Constants.MEDIA_BASE
local Detail = ns.Constants.Detail

local npcNameCache = {}

local function IsGenericNPCName(name, npcID)
    if not name or name == "" then
        return true
    end
    if name:find("^NPC %d") then
        return true
    end
    return npcID and tonumber(name) == tonumber(npcID)
end

local function ResolveNPCDisplayName(npcID, knownName)
    npcID = tonumber(npcID)
    if not npcID then
        return knownName
    end

    if not IsGenericNPCName(knownName, npcID) then
        return knownName
    end

    if npcNameCache[npcID] then
        return npcNameCache[npcID]
    end

    local tooltipData = C_TooltipInfo.GetHyperlink(
        ("unit:Creature-0-0-0-0-%d-0000000000"):format(npcID)
    )

    if tooltipData and tooltipData.lines and tooltipData.lines[1] then
        local name = tooltipData.lines[1].leftText
        if name and name ~= "" and not name:find("Retrieving") then
            npcNameCache[npcID] = name
            return name
        end
    end

    return knownName
end

function ns.UI.CreateNPCsTab(parent)
    do
        local p = ns.db.global.tabSortPrefs.npcs
        currentSort.by        = ns.UI.NormalizeSortBy(p.by) or "name"
        currentSort.ascending = p.ascending ~= false
        if p.by == "manual" then
            ns.db.global.tabSortPrefs.npcs = { by = "custom", ascending = p.ascending ~= false }
        end
    end

    local controlPanel = ns.UI.CreateThemedBar(nil, parent)
    controlPanel:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, 0)
    controlPanel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    controlPanel:SetHeight(45)

    local addTargetBtn = OneWoW_GUI:CreateFitTextButton(controlPanel, { text = L["BUTTON_ADD_TARGET"], height = 25, minWidth = 80 })
    addTargetBtn:SetPoint("TOPLEFT", controlPanel, "TOPLEFT", 10, -10)
    addTargetBtn:SetScript("OnClick", function()
        if ns.NPCs then
            local npcInfo = ns.NPCs:GetTargetNPCInfo()
            if not npcInfo then
                print("|cFFFFD100OneWoW - NPCs:|r " .. (L["MSG_TARGET_NPC_FIRST"]))
                return
            end
            if ns.NPCs:GetNPC(npcInfo.id) then
                print("|cFFFFD100OneWoW - NPCs:|r " .. (L["NPC_NOTE_ALREADY_EXISTS"]))
                return
            end
            ns.NPCs:AddNPC(npcInfo.id, npcInfo)
            parent.RefreshNPCsList()
            if parent.SelectNPC then parent.SelectNPC(npcInfo.id) end
        end
    end)
    addTargetBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["BUTTON_ADD_TARGET"], 1, 1, 1)
        GameTooltip:AddLine(L["TOOLTIP_BUTTON_ADD_TARGET_NPC_DESC"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    addTargetBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local addManualBtn = OneWoW_GUI:CreateFitTextButton(controlPanel, { text = L["BUTTON_MANUAL_ENTRY"], height = 25, minWidth = 70 })
    addManualBtn:SetPoint("LEFT", addTargetBtn, "RIGHT", 5, 0)
    addManualBtn:SetScript("OnClick", function()
        if ns.UI and ns.UI.ShowManualNPCEntryDialog then
            ns.UI.ShowManualNPCEntryDialog(parent)
        end
    end)
    addManualBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["BUTTON_MANUAL_ENTRY"], 1, 1, 1)
        GameTooltip:AddLine(L["TOOLTIP_BUTTON_MANUAL_ENTRY_NPC_DESC"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    addManualBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local catDD = ns.UI.CreateThemedDropdown(controlPanel, CATEGORY, 140, 25)
    catDD:SetPoint("LEFT", addManualBtn, "RIGHT", 8, 0)
    local storeDD
    local function CountNPCsForFilters(ignoreDim)
        local counts = { all = 0, byCategory = {}, byStorage = { All = 0, account = 0, character = 0 } }
        if not ns.NPCs then return counts end
        local searchLower = (searchFilter or ""):lower()
        local allNPCs = ns.NPCs:GetAllNPCs()
        for npcID, nd in pairs(allNPCs) do
            if type(nd) == "table" then
                local ok = true
                if ignoreDim ~= "category" and categoryFilter ~= "All"
                    and nd.category ~= categoryFilter then
                    ok = false
                end
                if ignoreDim ~= "storage" and storageFilter ~= "All"
                    and nd.storage ~= storageFilter then
                    ok = false
                end
                if searchLower ~= "" then
                    local nameLower = (nd.name or tostring(npcID)):lower()
                    if not nameLower:find(searchLower, 1, true) then
                        ok = false
                    end
                end
                if ok then
                    counts.all = counts.all + 1
                    local cat = nd.category or "General"
                    counts.byCategory[cat] = (counts.byCategory[cat] or 0) + 1
                    local stor = nd.storage == "character" and "character" or "account"
                    counts.byStorage[stor] = (counts.byStorage[stor] or 0) + 1
                    counts.byStorage.All = counts.byStorage.All + 1
                end
            end
        end
        return counts
    end
    local function RefreshCatOpts()
        local catCounts = CountNPCsForFilters("category")
        local opts = {{
            text = ALL,
            value = "All",
            rightText = ns.UI.FormatSectionCount(catCounts.all),
        }}
        if ns.NPCs then
            for _, c in ipairs(ns.NPCs:GetCategories()) do
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
        parent.RefreshNPCsList()
    end

    local manageCategoriesBtn = OneWoW_GUI:CreateIconButton(controlPanel, {
        iconTexture = MEDIA .. "icon-gears.png",
        size = 20,
        texCoord = { 0.1, 0.9, 0.1, 0.9 },
        tooltipTitle = L["CATMGR_TITLE"],
        tooltipText = L["UI_MANAGE_CATEGORIES_DESC"],
        onClick = function()
            ns.UI.ShowCategoryManager("npcs")
        end,
    })
    manageCategoriesBtn:SetPoint("LEFT", catDD, "RIGHT", 4, 0)

    storeDD = ns.UI.CreateThemedDropdown(controlPanel, L["LABEL_STORAGE"], 130, 25)
    storeDD:SetPoint("LEFT", manageCategoriesBtn, "RIGHT", 4, 0)
    local function RefreshStorageOpts()
        local storCounts = CountNPCsForFilters("storage")
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
        parent.RefreshNPCsList()
    end

    local npcSortHandle = OneWoW_GUI:CreateSortControls(controlPanel, {
        sortFields = {
            {key = "name",     label = NAME},
            {key = "zone",     label = ZONE},
            {key = "category", label = CATEGORY},
            {key = "custom",   label = CUSTOM},
        },
        defaultField  = currentSort.by,
        defaultAsc    = currentSort.ascending,
        dropdownWidth = 100,
        onChange = function(field, ascending)
            currentSort.by        = field
            currentSort.ascending = ascending
            ns.db.global.tabSortPrefs.npcs = { by = field, ascending = ascending }
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
    listingTitle:SetText(L["NPCS_LIST"])
    listingTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local searchBox = OneWoW_GUI:CreateEditBox(listingPanel, {
        placeholderText = L["SEARCH"],
        onTextChanged = function(text)
            searchFilter = text
            if parent.RefreshNPCsList then parent.RefreshNPCsList() end
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
                    ns.UI.EnsureCustomSort(npcSortHandle, currentSort, "npcs")
                    parent.RefreshNPCsList()
                end
            end,
        })
        sectionReorders[sectionKey] = ctrl
        return ctrl
    end
    local function IsAnyNPCsReorderActive()
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

    local detailScroll, detailContent = OneWoW_GUI:CreateScrollFrame(detailPanel, {
        name = "OneWoWNotesNPCDetailScroll",
    })
    detailScroll:ClearAllPoints()
    detailScroll:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", 0, 0)
    detailScroll:SetPoint("BOTTOMRIGHT", detailPanel, "BOTTOMRIGHT", -4, 4)
    detailPanel.detailScroll = detailScroll
    detailPanel.detailContent = detailContent

    emptyMessage = OneWoW_GUI:CreateFS(detailPanel, 16)
    emptyMessage:SetPoint("CENTER", detailPanel, "CENTER")
    emptyMessage:SetText(L["NPCS_SELECT"])
    emptyMessage:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local leftStatusBar = ns.UI.CreateThemedBar(nil, parent)
    leftStatusBar:SetPoint("TOPLEFT",  listingPanel, "BOTTOMLEFT",  0, -5)
    leftStatusBar:SetPoint("TOPRIGHT", listingPanel, "BOTTOMRIGHT", 0, -5)
    leftStatusBar:SetHeight(25)

    leftStatusText = OneWoW_GUI:CreateFS(leftStatusBar, 10)
    leftStatusText:SetPoint("LEFT", leftStatusBar, "LEFT", 10, 0)
    leftStatusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    leftStatusText:SetText(string.format(L["UI_COUNT_FORMAT"], L["TAB_NPCS"], 0))

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
            if child ~= emptyMessage and child ~= detailPanel.detailScroll then child:Hide() end
        end
        detailPanel.detailScroll:Show()

        if not detailPanel.editorContent then
            local editorParent = detailPanel.detailContent
            local editorHeader = ns.UI.CreateDetailHeader(editorParent)

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
            categoryLine:SetPoint("BOTTOMRIGHT", editorHeader, "BOTTOMRIGHT", -12, Detail.META_LINE_Y_LOWER)
            categoryLine:SetText("")
            categoryLine:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            categoryLine:SetJustifyH("RIGHT")
            editorHeader.categoryLine = categoryLine

            local ignoreIfDeadCheck = CreateFrame("CheckButton", nil, editorHeader, "InterfaceOptionsCheckButtonTemplate")
            ignoreIfDeadCheck:SetPoint("BOTTOMRIGHT", editorHeader, "BOTTOMRIGHT", -10, 26)
            if ignoreIfDeadCheck.Text then
                ignoreIfDeadCheck.Text:ClearAllPoints()
                ignoreIfDeadCheck.Text:SetPoint("RIGHT", ignoreIfDeadCheck, "LEFT", -2, 0)
                ignoreIfDeadCheck.Text:SetText(L["NPC_IGNORE_IF_DEAD"])
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

            local deleteBtn = ns.UI.CreateHeaderIconButton(editorHeader, {
                texture = "icon-trash.png",
            })
            deleteBtn:SetScript("OnClick", function()
                if selectedNPC then
                    StaticPopupDialogs["ONEWOW_NOTES_CONFIRM_DELETE_NPC"] = {
                        text = string.format(L["POPUP_DELETE_NPC"]),
                        button1 = DELETE, button2 = CANCEL,
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
                GameTooltip:SetText(L["TOOLTIP_NPC_DELETE"], 1, 1, 1)
                GameTooltip:AddLine(L["TOOLTIP_NPC_DELETE_DESC"], 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            deleteBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            editorHeader.deleteBtn = deleteBtn

            local propertiesBtn = ns.UI.CreateHeaderIconButton(editorHeader, {
                texture = "icon-gears.png",
                relativeTo = deleteBtn,
            })
            propertiesBtn:SetScript("OnClick", function()
                if selectedNPC and ns.UI and ns.UI.ShowNPCPropertiesDialog then
                    ns.UI.ShowNPCPropertiesDialog(selectedNPC, parent)
                end
            end)
            propertiesBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["DIALOG_NPC_PROPERTIES"], 1, 1, 1)
                GameTooltip:AddLine(L["TOOLTIP_NPC_PROPERTIES_DESC"], 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            propertiesBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            editorHeader.propertiesBtn = propertiesBtn

            local gotoBtn = ns.UI.CreateHeaderIconButton(editorHeader, {
                texture = "icon-compass.png",
                relativeTo = propertiesBtn,
            })
            gotoBtn:SetScript("OnClick", function()
                if selectedNPC and ns.NPCs then
                    local nd = ns.NPCs:GetNPC(selectedNPC)
                    if nd and nd.mapID and nd.coords then
                        ns.NPCs:CreateWaypoint(selectedNPC, nd)
                    else
                        print("|cFFFFD100OneWoW - NPCs:|r " .. (L["MSG_NPC_NO_LOCATION"]))
                    end
                end
            end)
            gotoBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["UI_NPC_GOTO_TITLE"], 1, 1, 1)
                GameTooltip:AddLine(L["UI_NPC_CREATE_WAYPOINT"], 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            gotoBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            editorHeader.gotoBtn = gotoBtn

            local waypinBtn = ns.UI.CreateHeaderIconButton(editorHeader, {
                texture = "icon-pin.png",
                relativeTo = gotoBtn,
                tooltipTitle = L["TOOLTIP_NPC_SAVE_WAYPIN"],
                tooltipDesc = L["TOOLTIP_NPC_SAVE_WAYPIN_DESC"],
                onClick = function()
                    if selectedNPC and ns.NPCs and ns.WayPins then
                        local nd = ns.NPCs:GetNPC(selectedNPC)
                        if nd and nd.mapID and nd.coords then
                            ns.WayPins:Add({
                                title     = nd.name,
                                mapID     = nd.mapID,
                                x         = nd.coords.x,
                                y         = nd.coords.y,
                                source    = "npc",
                                sourceKey = selectedNPC,
                            })
                        else
                            print("|cFFFFD100OneWoW - NPCs:|r " .. (L["MSG_NPC_NO_LOCATION"]))
                        end
                    end
                end,
            })
            editorHeader.waypinBtn = waypinBtn

            local alertBtn = CreateFrame("CheckButton", nil, editorHeader)
            alertBtn:SetSize(22, 22)
            alertBtn:SetPoint("RIGHT", waypinBtn, "LEFT", -2, 0)
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
                GameTooltip:SetText(L["TOOLTIP_NPC_SOUND"], 1, 1, 1)
                GameTooltip:AddLine(L["TOOLTIP_NPC_SOUND_DESC"], 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            alertBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            editorHeader.alertBtn = alertBtn

            local function ApplyNpcWaypinButton()
                if ns.WayPinsVisual.Enabled() then
                    waypinBtn:Show()
                    alertBtn:ClearAllPoints()
                    alertBtn:SetPoint("RIGHT", waypinBtn, "LEFT", -2, 0)
                else
                    waypinBtn:Hide()
                    alertBtn:ClearAllPoints()
                    alertBtn:SetPoint("RIGHT", gotoBtn, "LEFT", -2, 0)
                end
            end
            ns.UI.ApplyNpcWaypinButton = ApplyNpcWaypinButton
            ApplyNpcWaypinButton()

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
                GameTooltip:SetText(L["TOOLTIP_NPC_FAVORITE"], 1, 1, 1)
                GameTooltip:AddLine(L["TOOLTIP_NPC_FAVORITE_DESC"], 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            favoriteBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            editorHeader.favoriteBtn = favoriteBtn

            local body = ns.UI.CreateDetailBody(editorParent, editorHeader, {
                onTextChanged = function(self, userInput)
                    if userInput and selectedNPC and ns.NPCs then
                        local nd = ns.NPCs:GetNPC(selectedNPC)
                        if nd then nd.content = self:GetText() nd.modified = GetServerTime() end
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

            -- Catalog Quests link directly under the note body
            local associatedSection = ns.UI.CreateThemedBar(nil, editorParent)
            associatedSection:SetPoint("TOPLEFT",  contentBg, "BOTTOMLEFT",  0, -Detail.SECTION_GAP)
            associatedSection:SetPoint("TOPRIGHT", contentBg, "BOTTOMRIGHT", 0, -Detail.SECTION_GAP)
            associatedSection:SetHeight(36)

            local assocLabel = OneWoW_GUI:CreateFS(associatedSection, 12)
            assocLabel:SetPoint("TOPLEFT", associatedSection, "TOPLEFT", 10, -10)
            assocLabel:SetText(L["NOTES_NPC_ASSOC_QUESTS"])
            assocLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

            local catalogLink = OneWoW_GUI:CreateTextLink(associatedSection, {
                text = L["NOTES_OPEN_QUESTS_IN_CATALOG"],
                fontSize = 12,
                nav = true,
                onClick = function()
                    if OneWoW_Catalog_API and OneWoW_Catalog_API.OpenQuestsFiltered and selectedNPC then
                        local note = ns.NPCs and ns.NPCs:GetNPC(selectedNPC)
                        OneWoW_Catalog_API.OpenQuestsFiltered({
                            npcID = selectedNPC,
                            npcName = note and note.name or nil,
                        })
                    end
                end,
            })
            catalogLink:SetPoint("LEFT", assocLabel, "RIGHT", 12, 0)
            associatedSection.label = assocLabel
            associatedSection.catalogLink = catalogLink

            local tip = ns.UI.CreateTooltipLinesSection(editorParent, associatedSection, {
                onLineChanged = function(index, text, userInput)
                    if userInput and selectedNPC and ns.NPCs then
                        local nd = ns.NPCs:GetNPC(selectedNPC)
                        if nd then
                            if not nd.tooltipLines then nd.tooltipLines = {"","","",""} end
                            nd.tooltipLines[index] = text
                        end
                    end
                end,
            })
            local tooltipSection = tip.section
            local tooltipEdits = tip.edits

            detailPanel.editorContent = {
                parent             = editorParent,
                header             = editorHeader,
                contentBg          = contentBg,
                contentScroll      = contentScroll,
                associatedSection  = associatedSection,
                tooltipSection     = tooltipSection,
                tooltipEdits       = tooltipEdits,
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
                local resolvedName = ResolveNPCDisplayName(selectedNPC, nd.name)
                if resolvedName and resolvedName ~= nd.name then
                    nd.name = resolvedName
                    ns.NPCs:SaveNPC(selectedNPC, nd)
                    C_Timer.After(0.05, function()
                        if selectedNPC and parent.RefreshNPCsList then
                            parent.RefreshNPCsList()
                        end
                    end)
                end

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
                        header.locationText:SetText(L["MSG_NPC_NO_LOCATION"])
                        header.locationText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                    end
                end
                if header.categoryLine then
                    header.categoryLine:SetText(string.format(L["UI_CATEGORY_WITH_VALUE"], nd.category or GENERAL))
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

                local assoc = detailPanel.editorContent.associatedSection
                local tipSec = detailPanel.editorContent.tooltipSection
                local contentBg = detailPanel.editorContent.contentBg
                if assoc and tipSec and contentBg then
                    local hasCatalog = OneWoW_Catalog_API and OneWoW_Catalog_API.OpenQuestsFiltered
                    if hasCatalog then
                        assoc:SetHeight(36)
                        assoc:Show()
                        if assoc.label then assoc.label:Show() end
                        if assoc.catalogLink then assoc.catalogLink:Show() end
                        tipSec:ClearAllPoints()
                        tipSec:SetPoint("TOPLEFT",  assoc, "BOTTOMLEFT",  0, -Detail.SECTION_GAP)
                        tipSec:SetPoint("TOPRIGHT", assoc, "BOTTOMRIGHT", 0, -Detail.SECTION_GAP)
                    else
                        assoc:SetHeight(1)
                        assoc:Hide()
                        tipSec:ClearAllPoints()
                        tipSec:SetPoint("TOPLEFT",  contentBg, "BOTTOMLEFT",  0, -Detail.SECTION_GAP)
                        tipSec:SetPoint("TOPRIGHT", contentBg, "BOTTOMRIGHT", 0, -Detail.SECTION_GAP)
                    end
                    if detailPanel.detailContent then
                        local assocH = hasCatalog and (Detail.SECTION_GAP + 36) or 0
                        detailPanel.detailContent:SetHeight(
                            Detail.HEADER_HEIGHT + Detail.SECTION_GAP
                            + Detail.BODY_HEIGHT
                            + assocH
                            + Detail.SECTION_GAP
                            + ns.UI.GetTooltipLinesSectionHeight()
                            + 20
                        )
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
        if ns.pendingNPCSelect then
            local id = ns.pendingNPCSelect
            ns.pendingNPCSelect = nil
            parent.SelectNPC(id)
        end
    end)

    function parent.RefreshNPCsList()
        if scrollChild then
            scrollChild._onewowZebraSeq = nil
        end
        for _, ctrl in pairs(sectionReorders) do
            ctrl:Cancel()
        end
        for _, item in pairs(npcListItems) do item:Hide() end
        npcListItems = {}
        wipe(sectionRowFrames)
        wipe(sectionDataBags)

        if not ns.NPCs then
            if leftStatusText then leftStatusText:SetText(string.format(L["UI_COUNT_FORMAT"], L["TAB_NPCS"], 0)) end
            return
        end

        RefreshCatOpts()
        RefreshStorageOpts()

        local allNPCs = ns.NPCs:GetAllNPCs()
        local npcsList = {}

        for npcID, nd in pairs(allNPCs) do
            if type(nd) == "table" then
                local resolvedName = ResolveNPCDisplayName(npcID, nd.name)
                if resolvedName and resolvedName ~= nd.name then
                    nd.name = resolvedName
                    ns.NPCs:SaveNPC(npcID, nd)
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

        local favorites = {}
        local regular   = {}
        for _, n in ipairs(npcsList) do
            if n.data.favorite then
                table.insert(favorites, n)
            else
                table.insert(regular, n)
            end
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
            elseif currentSort.by == "custom" then
                local sa = a.data.sortOrder or 0
                local sb = b.data.sortOrder or 0
                if sa == sb then return nameA < nameB end
                if currentSort.ascending then return sa < sb else return sa > sb end
            else
                if currentSort.ascending then return nameA < nameB else return nameA > nameB end
            end
        end
        table.sort(favorites, sortNPCs)
        table.sort(regular,   sortNPCs)

        local function CreateSectionHeader(text, yOffset, count)
            local section = OneWoW_GUI:CreateSectionHeader(scrollChild, {
                title = text,
                yOffset = yOffset,
                rightText = ns.UI.FormatSectionCount(count),
            })
            table.insert(npcListItems, section)
            return section
        end

        local function BuildNPCRow(npc, yOffset, sectionKey)
            local rowOpts = {
                yOffset     = yOffset,
                barColor    = { 0.5, 0.5, 0.5 },
                icon        = ns.UI.ResolveNoteIcon(npc.data.iconKey) or "Interface\\GossipFrame\\GossipGossipIcon",
                title       = npc.data.name or ("NPC " .. tostring(npc.id)),
                detail      = npc.data.zone or "",
                storageText = npc.data.storage == "character" and CHARACTER or L["UI_STORAGE_ACCOUNT"],
                selected    = (selectedNPC == npc.id),
                shouldSuppressSelect = IsAnyNPCsReorderActive,
                onSelect    = function()
                    selectedNPC = npc.id
                    ShowEditor()
                    parent.RefreshNPCsList()
                end,
                gotoAction = {
                    tooltip = { title = L["UI_NPC_GOTO_TITLE"], desc = L["UI_NPC_CREATE_WAYPOINT"] },
                    onClick = function()
                        if ns.NPCs then
                            local nd = ns.NPCs:GetNPC(npc.id)
                            if nd and nd.mapID and nd.coords then
                                ns.NPCs:CreateWaypoint(npc.id, nd)
                            else
                                print("|cFFFFD100OneWoW - NPCs:|r " .. (L["MSG_NPC_NO_LOCATION"]))
                            end
                        end
                    end,
                },
                alert = {
                    active  = npc.data.alertOnFound and true or false,
                    tooltip = { title = L["TOOLTIP_NPC_SOUND"], desc = L["TOOLTIP_NPC_SOUND_DESC"] },
                    onToggle = function(state)
                        if not ns.NPCs then return end
                        local nd = ns.NPCs:GetNPC(npc.id)
                        if not nd then return end
                        nd.alertOnFound = state
                        ns.NPCs:SaveNPC(npc.id, nd)
                        if selectedNPC == npc.id and detailPanel.editorContent and detailPanel.editorContent.header then
                            local h = detailPanel.editorContent.header
                            if h.alertBtn then
                                h.alertBtn:GetNormalTexture():SetDesaturated(not state)
                                h.alertBtn:GetNormalTexture():SetAlpha(state and 1.0 or 0.3)
                                h.alertBtn:SetChecked(state)
                            end
                            if h.ignoreIfDeadCheck then
                                if state then h.ignoreIfDeadCheck:Show() else h.ignoreIfDeadCheck:Hide() end
                            end
                        end
                    end,
                },
                fav = {
                    active  = npc.data.favorite and true or false,
                    tooltip = { title = L["TOOLTIP_NPC_FAVORITE"], desc = L["TOOLTIP_NPC_FAVORITE_DESC"] },
                    onToggle = function(state)
                        if not ns.NPCs then return end
                        local nd = ns.NPCs:GetNPC(npc.id)
                        if nd then
                            nd.favorite = state
                            ns.NPCs:SaveNPC(npc.id, nd)
                            parent.RefreshNPCsList()
                        end
                    end,
                },
                props = {
                    tooltip = { title = L["TOOLTIP_NPC_PROPERTIES_DESC"] },
                    onClick = function()
                        if ns.UI.ShowNPCPropertiesDialog then ns.UI.ShowNPCPropertiesDialog(npc.id, parent) end
                    end,
                },
                delete = {
                    tooltip = { title = L["TOOLTIP_NPC_DELETE"], desc = L["TOOLTIP_NPC_DELETE_DESC"] },
                    onClick = function()
                        StaticPopupDialogs["ONEWOW_NOTES_CONFIRM_DELETE_NPC"] = {
                            text = L["POPUP_DELETE_NPC"],
                            button1 = DELETE, button2 = CANCEL,
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
                    end,
                },
            }

            local row = ns.UI.CreateNotesListRow(scrollChild, rowOpts)
            table.insert(npcListItems, row)
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
            for _, npc in ipairs(bag) do
                BuildNPCRow(npc, yOffset, sectionKey)
                yOffset = yOffset - ns.UI.LIST_ROW_SPACING
            end
            return yOffset
        end

        local yOffset = 0
        yOffset = PaintSection("favorites", FAVORITES, favorites, yOffset)
        yOffset = PaintSection("regular", L["TAB_NPCS"], regular, yOffset)

        scrollChild:SetHeight(math.abs(yOffset) + 50)
        if leftStatusText then
            leftStatusText:SetText(string.format(L["UI_COUNT_FORMAT"], L["TAB_NPCS"], #favorites + #regular))
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
        title          = L["NPC_MANUAL_ENTRY_TITLE"],
        width          = 500,
        height         = 420,
        destroyOnClose = true,
        buttons = {
            {
                text = L["BUTTON_ADD_NOTE"],
                onClick = function(dlg)
                    local npcName = dlg._nameInput and dlg._nameInput:GetText() or ""
                    local npcIDText = dlg._idInput and dlg._idInput:GetText() or ""
                    local npcID = tonumber(npcIDText)

                    if npcName == "" then
                        print("|cFFFFD100OneWoW - NPCs:|r " .. (L["NPC_ERROR_NAME_REQUIRED"]))
                        return
                    end

                    if not npcID or npcID <= 0 then
                        npcID = math.floor(GetServerTime() * 1000 + math.random(100, 999))
                    end

                    if ns.NPCs and ns.NPCs:GetNPC(npcID) then
                        print("|cFFFFD100OneWoW - NPCs:|r " .. (L["NPC_NOTE_ALREADY_EXISTS"]))
                        return
                    end

                    local cat   = dlg._catDD   and dlg._catDD:GetValue()   or "General"
                    local store = dlg._storeDD and dlg._storeDD:GetValue() or "account"
                    local noteContent = dlg._noteEditBox and dlg._noteEditBox:GetText() or ""

                    if ns.NPCs then
                        ns.NPCs:AddNPC(npcID, {
                            name = npcName, category = cat, storage = store,
                            content = noteContent,
                        })
                        dlg:Hide()
                        if refreshParent and refreshParent.RefreshNPCsList then refreshParent.RefreshNPCsList() end
                        if refreshParent and refreshParent.SelectNPC then refreshParent.SelectNPC(npcID) end
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

    MakeNPCLabel(content, L["NPC_LABEL_NAME"], COL1_X, yPos)
    dialog._nameInput = MakeNPCInput(content, COL1_X, yPos - LBL_GAP, COL_W)
    dialog._nameInput:SetAutoFocus(true)

    MakeNPCLabel(content, L["LABEL_NPC_ID"], COL2_X, yPos)
    dialog._idInput = MakeNPCInput(content, COL2_X, yPos - LBL_GAP, COL_W)
    dialog._idInput:SetNumeric(true)
    dialog._idInput:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["LABEL_NPC_ID"], 1, 1, 1)
        GameTooltip:AddLine(L["NPC_ID_TOOLTIP"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    dialog._idInput:SetScript("OnLeave", function() GameTooltip:Hide() end)
    yPos = yPos - ROW_H

    MakeNPCLabel(content, CATEGORY, COL1_X, yPos)
    local catDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    catDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos - LBL_GAP)
    local catOpts = {}
    if ns.NPCs then
        for _, c in ipairs(ns.NPCs:GetCategories()) do
            catOpts[#catOpts + 1] = {text = c, value = c}
        end
    end
    catDD:SetOptions(catOpts)
    catDD:SetSelected("General")
    dialog._catDD = catDD

    MakeNPCLabel(content, L["LABEL_STORAGE"], COL2_X, yPos)
    local storeDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    storeDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL2_X, yPos - LBL_GAP)
    storeDD:SetOptions({
        {text = L["UI_STORAGE_ACCOUNT"],   value = "account"},
        {text = CHARACTER, value = "character"},
    })
    storeDD:SetSelected("account")
    dialog._storeDD = storeDD
    yPos = yPos - ROW_H

    MakeNPCLabel(content, L["LABEL_NOTE_CONTENT"], COL1_X, yPos)
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
        height         = 600,
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
        local d = ns.NPCs:GetNPC(npcID)
        if d then
            d[field] = value
            ns.NPCs:SaveNPC(npcID, d)
        end
        if refreshParent and refreshParent.RefreshNPCsList then refreshParent.RefreshNPCsList() end
    end

    local zoneDisplay

    MakeNPCLabel(content, L["NPC_LABEL_NAME"], COL1_X, yPos)
    local nameInput = MakeNPCInput(content, COL1_X, yPos - LBL_GAP, COL_W)
    nameInput:SetText(nd.name or "")
    nameInput:SetScript("OnEnterPressed", function(self)
        local newName = self:GetText()
        if newName ~= "" then SaveField("name", newName) end
        self:ClearFocus()
    end)

    MakeNPCLabel(content, L["LABEL_NPC_ID"], COL2_X, yPos)
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
            print("|cFFFFD100OneWoW - NPCs:|r " .. (L["MSG_NPC_ID_EXISTS"]))
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
        GameTooltip:SetText(L["LABEL_NPC_ID"], 1, 1, 1)
        GameTooltip:AddLine(L["NPC_ID_EDIT_TOOLTIP"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    idInput:SetScript("OnLeave", function() GameTooltip:Hide() end)
    yPos = yPos - ROW_H

    MakeNPCLabel(content, L["NPC_LABEL_ZONE"], COL1_X, yPos)
    zoneDisplay = OneWoW_GUI:CreateFS(content, 12)
    zoneDisplay:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos - 20)
    zoneDisplay:SetText(nd.zone or "?")
    zoneDisplay:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    MakeNPCLabel(content, L["NPC_LABEL_MAP_ID"], COL2_X, yPos)
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

    MakeNPCLabel(content, L["NPC_LABEL_COORD_X"], COL1_X, yPos)
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

    MakeNPCLabel(content, L["NPC_LABEL_COORD_Y"], COL2_X, yPos)
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

    local setLocBtn = OneWoW_GUI:CreateFitTextButton(content, { text = L["NPC_SET_CURRENT"], height = 25, minWidth = 80 })
    setLocBtn:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X + 110, yPos - LBL_GAP)
    setLocBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
        self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["NPC_SET_CURRENT"], 1, 1, 1)
        GameTooltip:AddLine(L["NPC_SET_CURRENT_DESC"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    setLocBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
        self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        GameTooltip:Hide()
    end)
    setLocBtn:SetScript("OnClick", function()
        local mapID, px, py = OneWoW.Location.GetPlayerLocation()
        if mapID and px then
            local d = ns.NPCs:GetNPC(npcID)
            if d then
                d.mapID = mapID
                d.coords = {x = px, y = py}
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

    MakeNPCLabel(content, CATEGORY, COL1_X, yPos)
    local catDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    catDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos - LBL_GAP)
    local catOpts = {}
    if ns.NPCs then
        for _, c in ipairs(ns.NPCs:GetCategories()) do
            catOpts[#catOpts + 1] = {text = c, value = c}
        end
    end
    catDD:SetOptions(catOpts)
    catDD:SetSelected(nd.category or "General")
    catDD.onSelect = function(value) SaveField("category", value) end

    MakeNPCLabel(content, L["LABEL_STORAGE"], COL2_X, yPos)
    local storeDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    storeDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL2_X, yPos - LBL_GAP)
    storeDD:SetOptions({
        {text = L["UI_STORAGE_ACCOUNT"],   value = "account"},
        {text = CHARACTER, value = "character"},
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
    alertCB.Text:SetText(L["TOOLTIP_NPC_SOUND"])
    alertCB.Text:SetFontObject("GameFontNormal")
    alertCB:SetChecked(nd.alertOnFound or false)
    alertCB:SetScript("OnClick", function(self)
        SaveField("alertOnFound", self:GetChecked())
    end)
    alertCB:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["TOOLTIP_NPC_SOUND"], 1, 1, 1)
        GameTooltip:AddLine(L["TOOLTIP_NPC_SOUND_DESC"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    alertCB:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local ignoreCB = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    ignoreCB:SetSize(22, 22)
    ignoreCB:SetPoint("TOPLEFT", content, "TOPLEFT", COL2_X, yPos)
    ignoreCB.Text:SetText(L["NPC_IGNORE_IF_DEAD"])
    ignoreCB.Text:SetFontObject("GameFontNormal")
    ignoreCB:SetChecked(nd.ignoreIfDead or false)
    ignoreCB:SetScript("OnClick", function(self)
        SaveField("ignoreIfDead", self:GetChecked())
    end)
    ignoreCB:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["NPC_IGNORE_IF_DEAD"], 1, 1, 1)
        GameTooltip:AddLine(L["NPC_IGNORE_IF_DEAD_DESC"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    ignoreCB:SetScript("OnLeave", function() GameTooltip:Hide() end)
    yPos = yPos - 30

    MakeNPCLabel(content, L["LABEL_ICON"], COL1_X, yPos)
    local iconPicker = ns.UI.CreateIconPicker(content, {
        selectedKey = nd.iconKey or "gossip",
        onSelect = function(key) SaveField("iconKey", key) end,
    })
    iconPicker:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos - LBL_GAP)
    yPos = yPos - LBL_GAP - iconPicker:GetHeight() - 10

    MakeNPCLabel(content, L["LABEL_NOTE_PREVIEW"], COL1_X, yPos)
    yPos = yPos - LBL_GAP

    local noteBg = ns.UI.CreateThemedBar(nil, content)
    noteBg:SetPoint("TOPLEFT",     content, "TOPLEFT",     COL1_X, yPos)
    noteBg:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -COL1_X, 6)

    local noteScroll, noteEditBox = OneWoW_GUI:CreateScrollEditBox(noteBg, {})
    noteScroll:ClearAllPoints()
    noteScroll:SetPoint("TOPLEFT",     noteBg, "TOPLEFT",     4, -4)
    noteScroll:SetPoint("BOTTOMRIGHT", noteBg, "BOTTOMRIGHT", -26, 4)
    noteEditBox:SetText(nd.content or "")
    noteEditBox:EnableMouse(false)

    dialog:Show()
end
