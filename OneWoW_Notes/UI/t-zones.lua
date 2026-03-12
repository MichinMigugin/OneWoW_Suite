-- OneWoW_Notes Addon File
-- OneWoW_Notes/UI/t-zones.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...
local L = ns.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local BACKDROP_SIMPLE = OneWoW_GUI.Constants.BACKDROP_SIMPLE

local backdrop = {
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    tile = true, tileSize = 16, edgeSize = 1,
}

ns.UI = ns.UI or {}

local selectedZone  = nil
local zoneListItems = {}
local categoryFilter = "All"
local storageFilter  = "All"

local detailPanel    = nil
local emptyMessage   = nil
local leftStatusText = nil
local scrollFrame    = nil
local scrollChild    = nil
local todoContainer  = nil

local MEDIA = "Interface\\AddOns\\OneWoW_Notes\\Media\\"

local function GetFontColorFromKey(fontColorKey, pinColorKey)
    return ns.Config:GetResolvedFontColor(fontColorKey, pinColorKey)
end

function ns.UI.CreateZonesTab(parent)
    local controlPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    controlPanel:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, 0)
    controlPanel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    controlPanel:SetHeight(75)
    controlPanel:SetBackdrop(backdrop)
    controlPanel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    controlPanel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    local controlTitle = controlPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    controlTitle:SetPoint("TOPLEFT", controlPanel, "TOPLEFT", 10, -8)
    controlTitle:SetText(L["ZONES_CONTROLS"] or "Zones Controls")
    controlTitle:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local addZoneBtn = ns.UI.CreateButton(nil, controlPanel, L["BUTTON_ADD_ZONE"] or "Add Zone", 100, 25)
    ns.UI.AutoResizeButton(addZoneBtn, 80, 200)
    addZoneBtn:SetPoint("TOPLEFT", controlPanel, "TOPLEFT", 10, -28)
    addZoneBtn:SetScript("OnClick", function()
        ns.UI.ShowManualZoneEntryDialog(parent)
    end)

    local detectBtn = ns.UI.CreateButton(nil, controlPanel, L["BUTTON_DETECT_ZONE"] or "Detect Zone", 100, 25)
    ns.UI.AutoResizeButton(detectBtn, 80, 200)
    detectBtn:SetPoint("LEFT", addZoneBtn, "RIGHT", 6, 0)
    detectBtn:SetScript("OnClick", function()
        local mapID = C_Map.GetBestMapForUnit("player")
        if not mapID then
            print("|cFFFFD100OneWoW - Zones:|r " .. (L["ZONE_DETECT_FAIL"] or "Could not detect zone."))
            return
        end
        local mapInfo = C_Map.GetMapInfo(mapID)
        if not mapInfo or not mapInfo.name then
            print("|cFFFFD100OneWoW - Zones:|r " .. (L["ZONE_DETECT_FAIL"] or "Could not detect zone."))
            return
        end

        local zoneName = mapInfo.name
        if ns.Zones and ns.Zones:GetZone(zoneName) then
            selectedZone = zoneName
            parent.RefreshZonesList()
            if parent.SelectZone then parent.SelectZone(zoneName) end
            print("|cFFFFD100OneWoW - Zones:|r " .. string.format(L["MSG_ZONE_EXISTS"] or "Zone exists: %s", zoneName))
            return
        end

        if ns.Zones then
            ns.Zones:AddZone(zoneName, { content = "", category = "General", storage = "account", pinColor = "sync", fontColor = "match", mapID = mapID })
            selectedZone = zoneName
            parent.RefreshZonesList()
            if parent.SelectZone then parent.SelectZone(zoneName) end
            print("|cFFFFD100OneWoW - Zones:|r " .. string.format(L["MSG_ZONE_ADDED"] or "Added: %s", zoneName))
        end
    end)

    local categoryDropdown = ns.UI.CreateThemedDropdown(controlPanel, L["LABEL_CATEGORY"], 140, 25)
    categoryDropdown:SetPoint("LEFT", detectBtn, "RIGHT", 8, 0)
    local function RefreshCatOpts()
        local catOpts = {{text = L["UI_ALL"] or "All", value = "All"}}
        if ns.Zones then
            for _, c in ipairs(ns.Zones:GetCategories()) do
                catOpts[#catOpts + 1] = {text = c, value = c}
            end
        end
        categoryDropdown:SetOptions(catOpts)
        categoryDropdown:SetSelected(categoryFilter)
    end
    RefreshCatOpts()
    categoryDropdown.onSelect = function(value)
        categoryFilter = value
        parent.RefreshZonesList()
    end

    local manageCategoriesBtn = CreateFrame("Button", nil, controlPanel)
    manageCategoriesBtn:SetSize(20, 20)
    manageCategoriesBtn:SetPoint("LEFT", categoryDropdown, "RIGHT", 4, 0)
    manageCategoriesBtn:SetNormalTexture(MEDIA .. "icon-gears.png")
    manageCategoriesBtn:GetNormalTexture():SetTexCoord(0.1, 0.9, 0.1, 0.9)
    manageCategoriesBtn:SetHighlightTexture(MEDIA .. "icon-gears.png")
    manageCategoriesBtn:GetHighlightTexture():SetTexCoord(0.1, 0.9, 0.1, 0.9)
    manageCategoriesBtn:GetHighlightTexture():SetAlpha(0.5)
    manageCategoriesBtn:SetScript("OnClick", function()
        if ns.UI and ns.UI.ShowCategoryManager then
            ns.UI.ShowCategoryManager("zones")
        end
    end)
    manageCategoriesBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["UI_MANAGE_CATEGORIES"] or "Manage Categories", 1, 1, 1)
        GameTooltip:AddLine(L["UI_MANAGE_CATEGORIES_DESC"] or "Add, remove, and organize categories.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    manageCategoriesBtn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)

    local storageDropdown = ns.UI.CreateThemedDropdown(controlPanel, L["LABEL_STORAGE"], 130, 25)
    storageDropdown:SetPoint("LEFT", manageCategoriesBtn, "RIGHT", 4, 0)
    storageDropdown:SetOptions({
        {text = L["UI_ALL"] or "All",                         value = "All"},
        {text = L["UI_STORAGE_ACCOUNT"] or "Account",         value = "account"},
        {text = L["UI_STORAGE_CHARACTER"] or "Character",     value = "character"},
    })
    storageDropdown:SetSelected("All")
    storageDropdown.onSelect = function(value)
        storageFilter = value
        parent.RefreshZonesList()
    end

    local helpButton = CreateFrame("Button", nil, controlPanel)
    helpButton:SetSize(28, 28)
    helpButton:SetPoint("TOPRIGHT", controlPanel, "TOPRIGHT", -10, -10)
    local helpIcon = helpButton:CreateTexture(nil, "ARTWORK")
    helpIcon:SetSize(24, 24)
    helpIcon:SetPoint("CENTER", helpButton, "CENTER", 0, 0)
    helpIcon:SetAtlas("CampaignActiveQuestIcon")
    helpButton:SetScript("OnClick", function()
        if not ns.UI.zonesHelpPanel and ns.UI.CreateZonesHelpPanel then
            ns.UI.zonesHelpPanel = ns.UI.CreateZonesHelpPanel()
        end
        if ns.UI.zonesHelpPanel then
            if ns.UI.zonesHelpPanel:IsShown() then
                ns.UI.zonesHelpPanel:Hide()
            else
                ns.UI.zonesHelpPanel:Show()
            end
        end
    end)
    helpButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["UI_ZONES_HELP_TITLE"] or "Zones Help", 1, 1, 1)
        GameTooltip:AddLine(L["UI_ZONES_HELP_HINT"] or "Click for zones help.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    helpButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local listingPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    listingPanel:SetPoint("TOPLEFT", controlPanel, "BOTTOMLEFT", 0, -10)
    listingPanel:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 35)
    listingPanel:SetWidth(350)
    listingPanel:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    listingPanel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    listingPanel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    local listTitle = listingPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listTitle:SetPoint("TOPLEFT", listingPanel, "TOPLEFT", 10, -10)
    listTitle:SetText(L["TAB_ZONES"] or "Zones")
    listTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local scrollData = ns.UI.CreateCustomScroll(listingPanel)
    local listContainer = scrollData.container
    listContainer:SetPoint("TOPLEFT", listingPanel, "TOPLEFT", 8, -32)
    listContainer:SetPoint("BOTTOMRIGHT", listingPanel, "BOTTOMRIGHT", -8, 8)
    scrollFrame = scrollData.scrollFrame
    scrollChild = scrollData.scrollChild

    detailPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    detailPanel:SetPoint("TOPLEFT", listingPanel, "TOPRIGHT", 10, 0)
    detailPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 35)
    detailPanel:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    detailPanel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    detailPanel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    emptyMessage = detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    emptyMessage:SetPoint("CENTER", detailPanel, "CENTER", 0, 0)
    emptyMessage:SetText(L["ZONES_SELECT_PROMPT"] or "Select a zone to view its content")
    emptyMessage:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local leftStatusBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    leftStatusBar:SetPoint("TOPLEFT", listingPanel, "BOTTOMLEFT", 0, -5)
    leftStatusBar:SetPoint("TOPRIGHT", listingPanel, "BOTTOMRIGHT", 0, -5)
    leftStatusBar:SetHeight(25)
    leftStatusBar:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    leftStatusBar:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    leftStatusBar:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    leftStatusText = leftStatusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    leftStatusText:SetPoint("LEFT", leftStatusBar, "LEFT", 10, 0)
    leftStatusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    leftStatusText:SetText("")

    local function ShowEditor()
        if not selectedZone or not ns.Zones then return end
        local zoneData = ns.Zones:GetZone(selectedZone)
        if not zoneData then return end

        if OneWoW_GUI then OneWoW_GUI:ClearFrame(detailPanel) end
        emptyMessage:Hide()

        local detailScroll = ns.UI.CreateCustomScroll(detailPanel)
        local detailContainer = detailScroll.container
        detailContainer:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", 8, -8)
        detailContainer:SetPoint("BOTTOMRIGHT", detailPanel, "BOTTOMRIGHT", -8, 8)
        local detailScrollChild = detailScroll.scrollChild

        local yPos = 0

        local zoneTitleFS = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        zoneTitleFS:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 10, yPos)
        zoneTitleFS:SetText(selectedZone)
        zoneTitleFS:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

        local propertiesBtn = ns.UI.CreateButton(nil, detailScrollChild, L["ZONE_PROPERTIES"] or "Properties", 100, 22)
        ns.UI.AutoResizeButton(propertiesBtn, 80, 200)
        propertiesBtn:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -10, yPos)
        propertiesBtn:SetScript("OnClick", function()
            ns.UI.ShowZonePropertiesDialog(selectedZone, parent)
        end)

        yPos = yPos - 30

        local resolvedColor = ns.Config:GetResolvedColorConfig(zoneData.pinColor)
        local pinR, pinG, pinB = resolvedColor.bg[1], resolvedColor.bg[2], resolvedColor.bg[3]

        local colorBar = CreateFrame("Frame", nil, detailScrollChild, "BackdropTemplate")
        colorBar:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 0, yPos)
        colorBar:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", 0, yPos)
        colorBar:SetHeight(4)
        colorBar:SetBackdrop(BACKDROP_SIMPLE)
        colorBar:SetBackdropColor(pinR, pinG, pinB, 1)

        yPos = yPos - 14

        local infoLine = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        infoLine:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 10, yPos)
        local catText = zoneData.category or "General"
        local storeText = zoneData.storage == "character" and (L["STORAGE_TYPE_CHARACTER"] or "Character") or (L["STORAGE_ACCOUNT_WIDE"] or "Account")
        infoLine:SetText(catText .. "  |  " .. storeText)
        infoLine:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        if zoneData.mapID then
            local mapInfo = C_Map.GetMapInfo(zoneData.mapID)
            if mapInfo then
                local mapLabel = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                mapLabel:SetPoint("LEFT", infoLine, "RIGHT", 10, 0)
                mapLabel:SetText("Map: " .. mapInfo.name .. " (" .. zoneData.mapID .. ")")
                mapLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            end
        end

        yPos = yPos - 20

        OneWoW_GUI:CreateDivider(detailScrollChild, yPos)
        yPos = yPos - 10

        local contentLabel = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        contentLabel:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 10, yPos)
        contentLabel:SetText(L["LABEL_NOTE_CONTENT"] or "Note Content")
        contentLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        local pinBtn = ns.UI.CreateButton(nil, detailScrollChild, L["ZONE_PIN_BUTTON"] or "Pin", 60, 22)
        ns.UI.AutoResizeButton(pinBtn, 50, 120)
        pinBtn:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -80, yPos + 4)
        pinBtn:SetScript("OnClick", function()
            if ns.ZonePins then
                ns.ZonePins:TogglePin(selectedZone)
            end
        end)

        local deleteBtn = ns.UI.CreateButton(nil, detailScrollChild, L["BUTTON_DELETE"] or "Delete", 60, 22)
        ns.UI.AutoResizeButton(deleteBtn, 50, 120)
        deleteBtn:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -10, yPos + 4)
        deleteBtn:SetScript("OnClick", function()
            if not selectedZone then return end
            local zName = selectedZone

            local confirmResult = OneWoW_GUI:CreateConfirmDialog({
                name = "OneWoW_NotesDeleteZoneConfirm",
                title = L["DIALOG_CONFIRM_DELETE"] or "Confirm Delete",
                message = string.format(L["ZONE_CONFIRM_DELETE"] or "Delete zone: %s?", zName),
                buttons = {
                    {
                        text = L["BUTTON_DELETE"] or "Delete",
                        color = {0.8, 0.2, 0.2},
                        onClick = function(dlg)
                            if ns.ZonePins then ns.ZonePins:RemovePin(zName) end
                            if ns.Zones then ns.Zones:RemoveZone(zName) end
                            selectedZone = nil
                            OneWoW_GUI:ClearFrame(detailPanel)
                            emptyMessage:Show()
                            parent.RefreshZonesList()
                            dlg:Hide()
                        end,
                    },
                    { text = L["BUTTON_CANCEL"] or "Cancel", onClick = function(dlg) dlg:Hide() end },
                },
            })
            confirmResult.frame:Show()
        end)

        yPos = yPos - 24

        local noteBg = CreateFrame("Frame", nil, detailScrollChild, "BackdropTemplate")
        noteBg:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 10, yPos)
        noteBg:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -10, yPos)
        noteBg:SetHeight(200)
        noteBg:SetBackdrop(BACKDROP_INNER_NO_INSETS)
        noteBg:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        noteBg:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

        local noteScroll = CreateFrame("ScrollFrame", nil, noteBg, "UIPanelScrollFrameTemplate")
        noteScroll:SetPoint("TOPLEFT", noteBg, "TOPLEFT", 4, -4)
        noteScroll:SetPoint("BOTTOMRIGHT", noteBg, "BOTTOMRIGHT", -26, 4)

        local fontPath = ns.Config:ResolveFontPath(zoneData.fontFamily)

        local noteEditBox = CreateFrame("EditBox", nil, noteScroll)
        noteEditBox._skipGlobalFont = true
        noteEditBox:SetMultiLine(true)
        noteEditBox:SetFont(fontPath, zoneData.fontSize or 12, zoneData.fontOutline or "")
        noteEditBox:SetAutoFocus(false)
        noteEditBox:SetMaxLetters(0)
        noteEditBox:SetText(zoneData.content or "")
        noteScroll:SetScrollChild(noteEditBox)
        noteScroll:HookScript("OnSizeChanged", function(self, w)
            noteEditBox:SetWidth(math.max(1, w))
        end)

        local fontColorR, fontColorG, fontColorB, fontColorA = GetFontColorFromKey(zoneData.fontColor, zoneData.pinColor)
        noteEditBox:SetTextColor(fontColorR, fontColorG, fontColorB, fontColorA or 1)

        local saveTimer = nil
        noteEditBox:SetScript("OnTextChanged", function(self, userInput)
            if userInput then
                if saveTimer then saveTimer:Cancel() end
                saveTimer = C_Timer.NewTimer(1.0, function()
                    local d = ns.Zones:GetZone(selectedZone)
                    if d then
                        d.content = self:GetText()
                        ns.Zones:SaveZone(selectedZone, d)
                        if ns.ZonePins then ns.ZonePins:RefreshZonePinContent(selectedZone) end
                    end
                end)
            end
        end)

        yPos = yPos - 210

        OneWoW_GUI:CreateDivider(detailScrollChild, yPos)
        yPos = yPos - 10

        todoContainer = CreateFrame("Frame", nil, detailScrollChild)
        todoContainer:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 10, yPos)
        todoContainer:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -10, yPos)

        local todoLabel = todoContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        todoLabel:SetPoint("TOPLEFT", todoContainer, "TOPLEFT", 0, 0)
        todoLabel:SetText(L["ZONE_TODO_HEADER"] or "Checklist")
        todoLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        local addTodoBtn = ns.UI.CreateButton(nil, todoContainer, "+", 22, 22)
        addTodoBtn:SetPoint("LEFT", todoLabel, "RIGHT", 6, 0)
        addTodoBtn:SetScript("OnClick", function()
            local d = ns.Zones:GetZone(selectedZone)
            if not d then return end
            d.todos = d.todos or {}
            table.insert(d.todos, { text = "", done = false })
            ns.Zones:SaveZone(selectedZone, d)
            ShowEditor()
        end)

        local todoY = -24
        local todos = zoneData.todos or {}
        for i, todo in ipairs(todos) do
            local todoRow = CreateFrame("Frame", nil, todoContainer, "BackdropTemplate")
            todoRow:SetPoint("TOPLEFT", todoContainer, "TOPLEFT", 0, todoY)
            todoRow:SetPoint("TOPRIGHT", todoContainer, "TOPRIGHT", 0, todoY)
            todoRow:SetHeight(26)
            todoRow:SetBackdrop(BACKDROP_INNER_NO_INSETS)
            todoRow:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            todoRow:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

            local cb = CreateFrame("CheckButton", nil, todoRow, "UICheckButtonTemplate")
            cb:SetSize(20, 20)
            cb:SetPoint("LEFT", todoRow, "LEFT", 4, 0)
            cb:SetChecked(todo.done)
            cb:SetScript("OnClick", function(self)
                local d = ns.Zones:GetZone(selectedZone)
                if d and d.todos and d.todos[i] then
                    d.todos[i].done = self:GetChecked()
                    ns.Zones:SaveZone(selectedZone, d)
                end
            end)

            local todoInput = CreateFrame("EditBox", nil, todoRow, "BackdropTemplate")
            todoInput:SetPoint("LEFT", cb, "RIGHT", 4, 0)
            todoInput:SetPoint("RIGHT", todoRow, "RIGHT", -30, 0)
            todoInput:SetHeight(20)
            todoInput:SetFontObject("GameFontNormal")
            todoInput:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            todoInput:SetAutoFocus(false)
            todoInput:SetText(todo.text or "")
            todoInput:SetScript("OnEnterPressed", function(self)
                local d = ns.Zones:GetZone(selectedZone)
                if d and d.todos and d.todos[i] then
                    d.todos[i].text = self:GetText()
                    ns.Zones:SaveZone(selectedZone, d)
                end
                self:ClearFocus()
            end)
            todoInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

            if todo.done then
                todoInput:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            end

            local removeBtn = CreateFrame("Button", nil, todoRow)
            removeBtn:SetSize(16, 16)
            removeBtn:SetPoint("RIGHT", todoRow, "RIGHT", -6, 0)
            removeBtn:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
            removeBtn:SetScript("OnClick", function()
                local d = ns.Zones:GetZone(selectedZone)
                if d and d.todos then
                    table.remove(d.todos, i)
                    ns.Zones:SaveZone(selectedZone, d)
                    ShowEditor()
                end
            end)

            todoY = todoY - 28
        end

        local totalTodoH = math.abs(todoY) + 24
        todoContainer:SetHeight(totalTodoH)

        yPos = yPos - totalTodoH - 10
        detailScrollChild:SetHeight(math.abs(yPos) + 50)
    end

    parent.SelectZone = function(zoneName)
        selectedZone = zoneName
        ShowEditor()
        parent.RefreshZonesList()
    end

    parent.RefreshZonesList = function()
        for _, item in ipairs(zoneListItems) do
            item:Hide()
            item:SetParent(nil)
        end
        wipe(zoneListItems)

        local regions = { scrollChild:GetRegions() }
        for _, r in ipairs(regions) do r:Hide() end
        local children = { scrollChild:GetChildren() }
        for _, c in ipairs(children) do c:Hide() c:SetParent(nil) end

        if not ns.Zones then return end

        RefreshCatOpts()

        local allZones = ns.Zones:GetAllZones()
        local filtered = {}
        for name, data in pairs(allZones) do
            local passCategory = (categoryFilter == "All") or (data.category == categoryFilter)
            local passStorage  = (storageFilter == "All") or (data.storage == storageFilter)
            if passCategory and passStorage then
                filtered[#filtered + 1] = { name = name, data = data }
            end
        end

        table.sort(filtered, function(a, b) return a.name < b.name end)

        local newZones  = {}
        local favorites = {}
        local regular   = {}
        for _, zone in ipairs(filtered) do
            if zone.data.isNew then
                newZones[#newZones + 1] = zone
            elseif zone.data.favorite then
                favorites[#favorites + 1] = zone
            else
                regular[#regular + 1] = zone
            end
        end

        local function CreateSectionHeader(title, yOfs)
            local section = OneWoW_GUI:CreateSectionHeader(scrollChild, title, yOfs)
            table.insert(zoneListItems, section)
            return section
        end

        local function BuildZoneRow(zone, yOfs)
            local listItemColor = {T("BG_SECONDARY")}
            local resolvedColor = ns.Config:GetResolvedColorConfig(zone.data.pinColor)
            local cR, cG, cB = resolvedColor.bg[1], resolvedColor.bg[2], resolvedColor.bg[3]

            local row = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
            row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 8, yOfs)
            row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -8, yOfs)
            row:SetHeight(50)
            row:SetBackdrop(BACKDROP_INNER_NO_INSETS)
            row:SetBackdropColor(listItemColor[1], listItemColor[2], listItemColor[3], listItemColor[4])
            row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

            local colorStrip = row:CreateTexture(nil, "ARTWORK")
            colorStrip:SetSize(4, 46)
            colorStrip:SetPoint("LEFT", row, "LEFT", 2, 0)
            colorStrip:SetColorTexture(cR, cG, cB, 1)

            local titleFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            titleFS:SetPoint("TOPLEFT", row, "TOPLEFT", 12, -6)
            titleFS:SetPoint("TOPRIGHT", row, "TOPRIGHT", -80, -6)
            titleFS:SetJustifyH("LEFT")
            titleFS:SetText(zone.name)
            titleFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

            local catFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            catFS:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 12, 6)
            catFS:SetText(zone.data.category or "General")
            catFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

            local storageFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            storageFS:SetPoint("LEFT", catFS, "RIGHT", 8, 0)
            local stText = zone.data.storage == "character" and (L["STORAGE_TYPE_CHARACTER"] or "Char") or (L["STORAGE_ACCOUNT_WIDE"] or "Acct")
            storageFS:SetText(stText)
            storageFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

            local alertBtn = CreateFrame("Button", nil, row)
            alertBtn:SetSize(18, 18)
            alertBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -6)
            local aN = alertBtn:CreateTexture(nil, "BACKGROUND")
            aN:SetAllPoints()
            aN:SetTexture(MEDIA .. "icon-alert.png")
            aN:SetDesaturated(not zone.data.isNew)
            aN:SetAlpha(zone.data.isNew and 1.0 or 0.3)
            alertBtn:SetNormalTexture(aN)
            alertBtn:SetScript("OnClick", function(self)
                if ns.Zones then
                    local zoneData = ns.Zones:GetZone(zone.name)
                    if zoneData then
                        zoneData.isNew = not zoneData.isNew
                        aN:SetDesaturated(not zoneData.isNew)
                        aN:SetAlpha(zoneData.isNew and 1.0 or 0.3)
                        ns.Zones:SaveZone(zone.name, zoneData)
                        parent.RefreshZonesList()
                    end
                end
            end)

            local favBtn = CreateFrame("Button", nil, row)
            favBtn:SetSize(18, 18)
            favBtn:SetPoint("RIGHT", alertBtn, "LEFT", -2, 0)
            local fN2 = favBtn:CreateTexture(nil, "BACKGROUND")
            fN2:SetAllPoints()
            fN2:SetTexture(MEDIA .. "icon-fav.png")
            fN2:SetDesaturated(not zone.data.favorite)
            fN2:SetAlpha(zone.data.favorite and 1.0 or 0.3)
            favBtn:SetNormalTexture(fN2)
            favBtn:SetScript("OnClick", function(self)
                if ns.Zones then
                    local zoneData = ns.Zones:GetZone(zone.name)
                    if zoneData then
                        zoneData.favorite = not zoneData.favorite
                        fN2:SetDesaturated(not zoneData.favorite)
                        fN2:SetAlpha(zoneData.favorite and 1.0 or 0.3)
                        ns.Zones:SaveZone(zone.name, zoneData)
                        parent.RefreshZonesList()
                    end
                end
            end)

            row:EnableMouse(true)
            row:SetScript("OnMouseDown", function()
                selectedZone = zone.name
                ShowEditor()
                parent.RefreshZonesList()
            end)
            row:SetScript("OnEnter", function(self)
                if selectedZone ~= zone.name then
                    self:SetBackdropColor(listItemColor[1] * 1.2, listItemColor[2] * 1.2, listItemColor[3] * 1.2, listItemColor[4] + 0.1)
                end
            end)
            row:SetScript("OnLeave", function(self)
                if selectedZone ~= zone.name then
                    self:SetBackdropColor(listItemColor[1], listItemColor[2], listItemColor[3], listItemColor[4])
                end
            end)

            if selectedZone == zone.name then
                row:SetBackdropColor(listItemColor[1] + 0.15, listItemColor[2] + 0.15, listItemColor[3] + 0.15, 0.9)
                row:SetBackdropBorderColor(1, 0.82, 0, 1)
            end

            table.insert(zoneListItems, row)
        end

        local yOffset = 0

        if #newZones > 0 then
            CreateSectionHeader(L["NOTES_SECTION_NEW"] or "New", yOffset)
            yOffset = yOffset - 30
        end
        for _, zone in ipairs(newZones) do BuildZoneRow(zone, yOffset) yOffset = yOffset - 55 end

        if #favorites > 0 then
            CreateSectionHeader(L["NOTES_SECTION_FAVORITES"] or "Favorites", yOffset)
            yOffset = yOffset - 30
        end
        for _, zone in ipairs(favorites) do BuildZoneRow(zone, yOffset) yOffset = yOffset - 55 end

        if #regular > 0 then
            CreateSectionHeader(L["TAB_ZONES"], yOffset)
            yOffset = yOffset - 30
        end
        for _, zone in ipairs(regular) do BuildZoneRow(zone, yOffset) yOffset = yOffset - 55 end

        scrollChild:SetHeight(math.abs(yOffset) + 50)
        if leftStatusText then
            leftStatusText:SetText(string.format(L["UI_COUNT_FORMAT"], L["TAB_ZONES"], #newZones + #favorites + #regular))
        end
    end

    parent.RefreshZonesList()
end

local function MakeZoneLabel(parent, text, x, y)
    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    lbl:SetText(text)
    lbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    return lbl
end

local function MakeZoneInput(parent, x, y, w)
    local box = OneWoW_GUI:CreateEditBox(nil, parent, {
        width = w,
        height = 26,
        placeholderText = "",
    })
    box:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    box:SetText("")
    box:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEditFocusGained", function(self)
        self:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end)
    box:SetScript("OnEditFocusLost", function(self)
        if self:GetText() == "" then
            self:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end
    end)
    return box
end

local function MakeZoneSlider(parent, name, x, y, w, minV, maxV, defV, fmt)
    local step = (fmt == "pct") and 0.05 or 1
    local fmtStr = (fmt == "pct") and "%d%%" or "%d"
    local currentDisplay = defV
    local container = OneWoW_GUI:CreateSlider(parent, minV, maxV, step, defV, function() end, w, fmtStr)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    return container, nil, container
end

function ns.UI.ShowManualZoneEntryDialog(refreshParent)
    local COL1_X = 10
    local COL2_X = 300
    local COL_W  = 260
    local ROW_H   = 50
    local LBL_GAP = 18

    local dialog = ns.UI.CreateThemedDialog({
        name            = "OneWoW_NotesManualZoneEntry",
        title           = L["ZONE_MANUAL_ENTRY_TITLE"] or "Add Zone",
        width           = 580,
        height          = 610,
        destroyOnClose  = true,
        buttons = {
            {
                text = L["BUTTON_ADD_NOTE"] or "Add",
                onClick = function(dlg)
                    local name = dlg._nameInput and dlg._nameInput:GetText() or ""
                    if name == "" then
                        print("|cFFFFD100OneWoW - Zones:|r " .. (L["ZONE_ERROR_NAME_REQUIRED"] or "Zone name is required."))
                        return
                    end

                    if ns.Zones and ns.Zones:GetZone(name) then
                        print("|cFFFFD100OneWoW - Zones:|r " .. string.format(L["MSG_ZONE_EXISTS"] or "Zone exists: %s", name))
                        return
                    end

                    local cat        = dlg._catDD      and dlg._catDD:GetValue()      or "General"
                    local store      = dlg._storeDD    and dlg._storeDD:GetValue()    or "account"
                    local pinColor   = dlg._colorDD    and dlg._colorDD:GetValue()    or "hunter"
                    local fontCol    = dlg._fontColDD  and dlg._fontColDD:GetValue()  or "match"
                    local fontFamily = dlg._fontFamily or nil
                    local fontSize   = dlg._fontSize   or 12
                    local opacity    = dlg._opacity    or 0.9

                    local noteContent = dlg._noteEditBox and dlg._noteEditBox:GetText() or ""

                    local mapID = dlg._validatedMapID
                    if ns.Zones then
                        ns.Zones:AddZone(name, {
                            content = noteContent, category = cat, storage = store,
                            pinColor = pinColor, fontColor = fontCol,
                            fontFamily = fontFamily,
                            fontSize = fontSize, opacity = opacity,
                            mapID = mapID,
                        })
                        print("|cFFFFD100OneWoW - Zones:|r " .. string.format(L["MSG_ZONE_ADDED"] or "Added: %s", name))
                        dlg:Hide()
                        if refreshParent and refreshParent.RefreshZonesList then refreshParent.RefreshZonesList() end
                        if refreshParent and refreshParent.SelectZone then refreshParent.SelectZone(name) end
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

    MakeZoneLabel(content, L["LABEL_ZONE_NAME"] or "Zone Name:", COL1_X, yPos)
    dialog._nameInput = MakeZoneInput(content, COL1_X, yPos - LBL_GAP, COL_W * 2 + (COL2_X - COL1_X - COL_W))
    dialog._nameInput:SetAutoFocus(true)
    yPos = yPos - ROW_H

    MakeZoneLabel(content, L["LABEL_MAP_ID_OPTIONAL"] or "Map ID (optional):", COL1_X, yPos)
    local mapIDInput = MakeZoneInput(content, COL1_X, yPos - LBL_GAP, 120)
    mapIDInput:SetNumeric(true)
    dialog._validatedMapID = nil

    local validateBtn = ns.UI.CreateButton(nil, content, L["BUTTON_VALIDATE"] or "Validate", 80, 26)
    validateBtn:SetPoint("LEFT", mapIDInput, "RIGHT", 6, 0)
    ns.UI.AutoResizeButton(validateBtn, 70, 150)

    local validationFS = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    validationFS:SetPoint("LEFT", validateBtn, "RIGHT", 8, 0)
    validationFS:SetText(L["ZONE_VALIDATE_HINT"] or "Enter ID & click Validate")
    validationFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    validateBtn:SetScript("OnClick", function()
        local mapID = tonumber(mapIDInput:GetText())
        if not mapID or mapID <= 0 then
            validationFS:SetText(L["ZONE_INVALID_MAP_ID"] or "Enter a valid number.")
            validationFS:SetTextColor(0.8, 0.2, 0.2, 1)
            dialog._validatedMapID = nil
            return
        end
        local mapInfo = C_Map.GetMapInfo(mapID)
        if mapInfo and mapInfo.name then
            validationFS:SetText(mapInfo.name)
            validationFS:SetTextColor(0.2, 1.0, 0.2, 1)
            dialog._nameInput:SetText(mapInfo.name)
            dialog._validatedMapID = mapID
        else
            validationFS:SetText(L["ZONE_MAP_NOT_FOUND"] or "Map ID not found.")
            validationFS:SetTextColor(0.8, 0.2, 0.2, 1)
            dialog._validatedMapID = nil
        end
    end)
    yPos = yPos - ROW_H

    MakeZoneLabel(content, L["LABEL_CATEGORY"], COL1_X, yPos)
    local catDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    catDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos - LBL_GAP)
    local catOpts = {}
    if ns.Zones then
        for _, c in ipairs(ns.Zones:GetCategories()) do
            catOpts[#catOpts + 1] = {text = c, value = c}
        end
    end
    catDD:SetOptions(catOpts)
    catDD:SetSelected("General")
    dialog._catDD = catDD

    MakeZoneLabel(content, L["LABEL_STORAGE"], COL2_X, yPos)
    local storeDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    storeDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL2_X, yPos - LBL_GAP)
    storeDD:SetOptions({
        {text = L["STORAGE_ACCOUNT_WIDE"],   value = "account"},
        {text = L["STORAGE_TYPE_CHARACTER"], value = "character"},
    })
    storeDD:SetSelected("account")
    dialog._storeDD = storeDD
    yPos = yPos - ROW_H

    MakeZoneLabel(content, L["LABEL_NOTE_COLOR"], COL1_X, yPos)
    local colorDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    colorDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos - LBL_GAP)
    local colorOpts = {}
    for key, colorData in pairs(ns.Config.PIN_COLORS) do
        colorOpts[#colorOpts + 1] = {text = colorData.name, value = key}
    end
    table.sort(colorOpts, function(a, b) return a.text < b.text end)
    colorDD:SetOptions(colorOpts)
    colorDD:SetSelected("hunter")
    dialog._colorDD = colorDD

    MakeZoneLabel(content, L["LABEL_FONT_COLOR"], COL2_X, yPos)
    local fontColDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    fontColDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL2_X, yPos - LBL_GAP)
    fontColDD:SetOptions({
        {text = "OneWoW Sync",                value = "sync"},
        {text = L["FONT_COLOR_MATCHING"],    value = "match"},
        {text = L["FONT_COLOR_WHITE"],      value = "white"},
        {text = L["FONT_COLOR_BLACK"],      value = "black"},
    })
    fontColDD:SetSelected("match")
    dialog._fontColDD = fontColDD
    yPos = yPos - ROW_H

    MakeZoneLabel(content, L["LABEL_FONT_SIZE"], COL1_X, yPos)
    dialog._fontSize = 12
    local fontSizeSlider, fontSizeTxt, fontSizeContainer = MakeZoneSlider(content, "OneWoW_ZoneAddFontSize", COL1_X, yPos - LBL_GAP, COL_W, 10, 20, 12, "int")
    if fontSizeContainer then
        local sliderChild = select(1, fontSizeContainer:GetChildren())
        if sliderChild then
            sliderChild:SetScript("OnValueChanged", function(self, value)
                local val = math.floor(value + 0.5)
                dialog._fontSize = val
            end)
        end
    elseif fontSizeSlider.SetScript then
        fontSizeSlider:SetScript("OnValueChanged", function(self, value)
            local val = math.floor(value + 0.5)
            if fontSizeTxt then fontSizeTxt:SetText(tostring(val)) end
            dialog._fontSize = val
        end)
    end

    MakeZoneLabel(content, L["LABEL_NOTE_FONT"], COL2_X, yPos)
    dialog._fontFamily = nil
    local addPreviewEditBox = nil
    local addFontOpts = ns.Config:GetFontOptions()
    local addFontDD = ns.UI.CreateFontDropdown(content, COL_W, 26)
    addFontDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL2_X, yPos - LBL_GAP)
    addFontDD:SetOptions(addFontOpts)
    addFontDD:SetSelected("default")
    addFontDD.onSelect = function(value)
        local fontValue = (value == "default") and nil or value
        dialog._fontFamily = fontValue
        if addPreviewEditBox then
            local fp = ns.Config:ResolveFontPath(fontValue)
            addPreviewEditBox:SetFont(fp, dialog._fontSize or 12, dialog._fontOutline or "")
        end
    end
    dialog._fontFamilyDD = addFontDD
    yPos = yPos - ROW_H

    MakeZoneLabel(content, "Font Outline", COL2_X, yPos)
    dialog._fontOutline = ""
    local addOutlineDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    addOutlineDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL2_X, yPos - LBL_GAP)
    addOutlineDD:SetOptions({
        {text = "None", value = ""},
        {text = "Outline", value = "OUTLINE"},
        {text = "Thick Outline", value = "THICKOUTLINE"},
    })
    addOutlineDD:SetSelected("")
    addOutlineDD.onSelect = function(value)
        dialog._fontOutline = value
        if addPreviewEditBox then
            local fp = ns.Config:ResolveFontPath(dialog._fontFamily)
            addPreviewEditBox:SetFont(fp, dialog._fontSize or 12, value)
        end
    end
    dialog._outlineDD = addOutlineDD

    MakeZoneLabel(content, L["LABEL_OPACITY"], COL1_X, yPos)
    dialog._opacity = 0.9
    local opacitySlider, opacityTxt, opacityContainer = MakeZoneSlider(content, "OneWoW_ZoneAddOpacity", COL1_X, yPos - LBL_GAP, COL_W, 0.5, 1.0, 0.9, "pct")
    if opacityContainer then
        local sliderChild = select(1, opacityContainer:GetChildren())
        if sliderChild then
            sliderChild:SetScript("OnValueChanged", function(self, value)
                local val = math.floor(value * 100 + 0.5)
                dialog._opacity = value
            end)
        end
    elseif opacitySlider.SetScript then
        opacitySlider:SetScript("OnValueChanged", function(self, value)
            local val = math.floor(value * 100 + 0.5)
            if opacityTxt then opacityTxt:SetText(val .. "%") end
            dialog._opacity = value
        end)
    end
    yPos = yPos - ROW_H

    MakeZoneLabel(content, L["LABEL_NOTE_CONTENT"] or "Note:", COL1_X, yPos)
    yPos = yPos - LBL_GAP

    local noteBg = CreateFrame("Frame", nil, content, "BackdropTemplate")
    noteBg:SetPoint("TOPLEFT",     content, "TOPLEFT",     COL1_X, yPos)
    noteBg:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -COL1_X, 6)
    noteBg:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    noteBg:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    noteBg:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    local noteScroll = CreateFrame("ScrollFrame", nil, noteBg, "UIPanelScrollFrameTemplate")
    noteScroll:SetPoint("TOPLEFT",     noteBg, "TOPLEFT",     4, -4)
    noteScroll:SetPoint("BOTTOMRIGHT", noteBg, "BOTTOMRIGHT", -26, 4)

    local noteEditBox = CreateFrame("EditBox", nil, noteScroll)
    noteEditBox:SetMultiLine(true)
    noteEditBox:SetFont(ns.Config:ResolveFontPath(dialog._fontFamily), dialog._fontSize or 12, dialog._fontOutline or "")
    noteEditBox:SetAutoFocus(false)
    noteEditBox:SetMaxLetters(0)
    noteScroll:SetScrollChild(noteEditBox)
    noteScroll:HookScript("OnSizeChanged", function(self, w)
        noteEditBox:SetWidth(math.max(1, w))
    end)
    noteEditBox._skipGlobalFont = true
    addPreviewEditBox = noteEditBox
    dialog._noteEditBox = noteEditBox

    dialog:Show()
end

function ns.UI.ShowZonePropertiesDialog(zoneName, refreshParent)
    if not zoneName or not ns.Zones then return end
    local zoneData = ns.Zones:GetZone(zoneName)
    if not zoneData then return end

    local COL1_X  = 10
    local COL2_X  = 300
    local COL_W   = 260
    local ROW_H   = 50
    local LBL_GAP = 18

    local dialog = ns.UI.CreateThemedDialog({
        name            = "OneWoW_NotesZoneProperties",
        title           = (L["DIALOG_ZONE_PROPERTIES"] or "Zone Properties") .. ": " .. zoneName,
        width           = 580,
        height          = 600,
        destroyOnClose  = true,
        buttons = {
            { text = L["BUTTON_CLOSE"], onClick = function(dlg) dlg:Hide() end },
        },
    })

    if dialog.built then dialog:Show() return end
    dialog.built = true

    local content = dialog.content
    local yPos = -10

    local function SaveField(field, value)
        local d = ns.Zones:GetZone(zoneName)
        if d then
            d[field] = value
            ns.Zones:SaveZone(zoneName, d)
        end
        if refreshParent and refreshParent.RefreshZonesList then refreshParent.RefreshZonesList() end
    end

    local function RefreshEditor()
        if refreshParent and refreshParent.SelectZone then
            refreshParent.SelectZone(zoneName)
        end
        if ns.ZonePins and ns.ZonePins.RefreshZonePinColors then
            ns.ZonePins:RefreshZonePinColors(zoneName)
        end
    end

    MakeZoneLabel(content, L["LABEL_ZONE_NAME"] or "Zone Name:", COL1_X, yPos)
    local nameInput = MakeZoneInput(content, COL1_X, yPos - LBL_GAP, COL_W * 2 + (COL2_X - COL1_X - COL_W))
    nameInput:SetText(zoneName)
    nameInput:SetScript("OnEnterPressed", function(self)
        local newName = self:GetText()
        if newName ~= "" and newName ~= zoneName then
            local d = ns.Zones:GetZone(zoneName)
            if d then
                ns.Zones:RemoveZone(zoneName)
                ns.Zones:AddZone(newName, d)
                zoneName = newName
                if refreshParent and refreshParent.RefreshZonesList then refreshParent.RefreshZonesList() end
                if refreshParent and refreshParent.SelectZone then refreshParent.SelectZone(newName) end
            end
        end
        self:ClearFocus()
    end)
    yPos = yPos - ROW_H

    MakeZoneLabel(content, L["LABEL_MAP_ID_OPTIONAL"] or "Map ID:", COL1_X, yPos)
    local mapIDInput = MakeZoneInput(content, COL1_X, yPos - LBL_GAP, 120)
    mapIDInput:SetNumeric(true)
    mapIDInput:SetText(zoneData.mapID and tostring(zoneData.mapID) or "")

    local validateBtn = ns.UI.CreateButton(nil, content, L["BUTTON_VALIDATE"] or "Validate", 80, 26)
    validateBtn:SetPoint("LEFT", mapIDInput, "RIGHT", 6, 0)
    ns.UI.AutoResizeButton(validateBtn, 70, 150)

    local validationFS = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    validationFS:SetPoint("LEFT", validateBtn, "RIGHT", 8, 0)
    if zoneData.mapID then
        local mapInfo = C_Map.GetMapInfo(zoneData.mapID)
        if mapInfo then
            validationFS:SetText(mapInfo.name)
            validationFS:SetTextColor(0.2, 1.0, 0.2, 1)
        else
            validationFS:SetText(L["ZONE_MAP_NOT_FOUND"] or "Map ID not found.")
            validationFS:SetTextColor(0.8, 0.2, 0.2, 1)
        end
    else
        validationFS:SetText(L["ZONE_VALIDATE_HINT"] or "Enter ID & click Validate")
        validationFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    end

    validateBtn:SetScript("OnClick", function()
        local mapID = tonumber(mapIDInput:GetText())
        if not mapID or mapID <= 0 then
            validationFS:SetText(L["ZONE_INVALID_MAP_ID"] or "Enter a valid number.")
            validationFS:SetTextColor(0.8, 0.2, 0.2, 1)
            return
        end
        local mapInfo = C_Map.GetMapInfo(mapID)
        if mapInfo and mapInfo.name then
            validationFS:SetText(mapInfo.name)
            validationFS:SetTextColor(0.2, 1.0, 0.2, 1)
            SaveField("mapID", mapID)
            nameInput:SetText(mapInfo.name)
            local d = ns.Zones:GetZone(zoneName)
            if d then
                ns.Zones:RemoveZone(zoneName)
                ns.Zones:AddZone(mapInfo.name, d)
                zoneName = mapInfo.name
                if refreshParent and refreshParent.RefreshZonesList then refreshParent.RefreshZonesList() end
                RefreshEditor()
            end
        else
            validationFS:SetText(L["ZONE_MAP_NOT_FOUND"] or "Map ID not found.")
            validationFS:SetTextColor(0.8, 0.2, 0.2, 1)
        end
    end)
    yPos = yPos - ROW_H

    MakeZoneLabel(content, L["LABEL_CATEGORY"], COL1_X, yPos)
    local catDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    catDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos - LBL_GAP)
    local catOpts = {}
    if ns.Zones then
        for _, c in ipairs(ns.Zones:GetCategories()) do
            catOpts[#catOpts + 1] = {text = c, value = c}
        end
    end
    catDD:SetOptions(catOpts)
    catDD:SetSelected(zoneData.category or "General")
    catDD.onSelect = function(value) SaveField("category", value) end

    MakeZoneLabel(content, L["LABEL_STORAGE"], COL2_X, yPos)
    local storeDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    storeDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL2_X, yPos - LBL_GAP)
    storeDD:SetOptions({
        {text = L["STORAGE_ACCOUNT_WIDE"],   value = "account"},
        {text = L["STORAGE_TYPE_CHARACTER"], value = "character"},
    })
    storeDD:SetSelected(zoneData.storage or "account")
    storeDD.onSelect = function(value)
        local d = ns.Zones:GetZone(zoneName)
        if d then d.storage = value ns.Zones:SaveZone(zoneName, d) end
        if refreshParent and refreshParent.RefreshZonesList then refreshParent.RefreshZonesList() end
    end
    yPos = yPos - ROW_H

    MakeZoneLabel(content, L["LABEL_NOTE_COLOR"], COL1_X, yPos)
    local colorDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    colorDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos - LBL_GAP)
    local colorOpts = {}
    for key, colorData in pairs(ns.Config.PIN_COLORS) do
        colorOpts[#colorOpts + 1] = {text = colorData.name, value = key}
    end
    table.sort(colorOpts, function(a, b) return a.text < b.text end)
    colorDD:SetOptions(colorOpts)
    colorDD:SetSelected(zoneData.pinColor or "hunter")
    colorDD.onSelect = function(value)
        SaveField("pinColor", value)
        RefreshEditor()
    end

    MakeZoneLabel(content, L["LABEL_FONT_COLOR"], COL2_X, yPos)
    local fontColorDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    fontColorDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL2_X, yPos - LBL_GAP)
    fontColorDD:SetOptions({
        {text = "OneWoW Sync",                value = "sync"},
        {text = L["FONT_COLOR_MATCHING"],    value = "match"},
        {text = L["FONT_COLOR_WHITE"],      value = "white"},
        {text = L["FONT_COLOR_BLACK"],      value = "black"},
    })
    fontColorDD:SetSelected(zoneData.fontColor or "match")
    fontColorDD.onSelect = function(value)
        SaveField("fontColor", value)
        RefreshEditor()
    end
    yPos = yPos - ROW_H

    MakeZoneLabel(content, L["LABEL_FONT_SIZE"], COL1_X, yPos)
    local propFontSizeSlider, propFontSizeTxt, propFontSizeContainer = MakeZoneSlider(content, "OneWoW_ZonePropFontSize", COL1_X, yPos - LBL_GAP, COL_W, 10, 20, zoneData.fontSize or 12, "int")
    if propFontSizeContainer then
        local sliderChild = select(1, propFontSizeContainer:GetChildren())
        if sliderChild then
            sliderChild:SetScript("OnValueChanged", function(self, value)
                local val = math.floor(value + 0.5)
                SaveField("fontSize", val)
                RefreshEditor()
            end)
        end
    elseif propFontSizeSlider.SetScript then
        propFontSizeSlider:SetScript("OnValueChanged", function(self, value)
            local val = math.floor(value + 0.5)
            if propFontSizeTxt then propFontSizeTxt:SetText(tostring(val)) end
            SaveField("fontSize", val)
            RefreshEditor()
        end)
    end

    MakeZoneLabel(content, L["LABEL_NOTE_FONT"], COL2_X, yPos)
    local propPreviewEditBox = nil
    local propFontOpts = ns.Config:GetFontOptions()
    local propFontDD = ns.UI.CreateFontDropdown(content, COL_W, 26)
    propFontDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL2_X, yPos - LBL_GAP)
    propFontDD:SetOptions(propFontOpts)
    propFontDD:SetSelected(zoneData.fontFamily or "default")
    propFontDD.onSelect = function(value)
        local fontValue = (value == "default") and nil or value
        SaveField("fontFamily", fontValue)
        RefreshEditor()
        if propPreviewEditBox then
            local fp = ns.Config:ResolveFontPath(fontValue)
            local d = ns.Zones:GetZone(zoneName)
            propPreviewEditBox:SetFont(fp, d and d.fontSize or 12, d and d.fontOutline or "")
        end
    end
    yPos = yPos - ROW_H

    MakeZoneLabel(content, "Font Outline", COL2_X, yPos)
    local propOutlineDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    propOutlineDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL2_X, yPos - LBL_GAP)
    propOutlineDD:SetOptions({
        {text = "None", value = ""},
        {text = "Outline", value = "OUTLINE"},
        {text = "Thick Outline", value = "THICKOUTLINE"},
    })
    propOutlineDD:SetSelected(zoneData.fontOutline or "")
    propOutlineDD.onSelect = function(value)
        SaveField("fontOutline", value)
        RefreshEditor()
        if propPreviewEditBox then
            local d = ns.Zones:GetZone(zoneName)
            local fp = ns.Config:ResolveFontPath(d and d.fontFamily)
            propPreviewEditBox:SetFont(fp, d and d.fontSize or 12, value)
        end
    end

    MakeZoneLabel(content, L["LABEL_OPACITY"], COL1_X, yPos)
    local propOpacitySlider, propOpacityTxt, propOpacityContainer = MakeZoneSlider(content, "OneWoW_ZonePropOpacity", COL1_X, yPos - LBL_GAP, COL_W, 0.5, 1.0, zoneData.opacity or 0.9, "pct")
    if propOpacityContainer then
        local sliderChild = select(1, propOpacityContainer:GetChildren())
        if sliderChild then
            sliderChild:SetScript("OnValueChanged", function(self, value)
                SaveField("opacity", value)
                RefreshEditor()
            end)
        end
    elseif propOpacitySlider.SetScript then
        propOpacitySlider:SetScript("OnValueChanged", function(self, value)
            local val = math.floor(value * 100 + 0.5)
            if propOpacityTxt then propOpacityTxt:SetText(val .. "%") end
            SaveField("opacity", value)
            RefreshEditor()
        end)
    end
    yPos = yPos - ROW_H

    MakeZoneLabel(content, L["LABEL_NOTE_PREVIEW"] or "Note:", COL1_X, yPos)
    yPos = yPos - LBL_GAP

    local noteBg = CreateFrame("Frame", nil, content, "BackdropTemplate")
    noteBg:SetPoint("TOPLEFT",     content, "TOPLEFT",     COL1_X, yPos)
    noteBg:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -COL1_X, 6)
    noteBg:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    noteBg:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    noteBg:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    local noteScroll = CreateFrame("ScrollFrame", nil, noteBg, "UIPanelScrollFrameTemplate")
    noteScroll:SetPoint("TOPLEFT",     noteBg, "TOPLEFT",     4, -4)
    noteScroll:SetPoint("BOTTOMRIGHT", noteBg, "BOTTOMRIGHT", -26, 4)

    local noteEditBox = CreateFrame("EditBox", nil, noteScroll)
    noteEditBox:SetMultiLine(true)
    local propInitFontPath = ns.Config:ResolveFontPath(zoneData.fontFamily)
    noteEditBox:SetFont(propInitFontPath, zoneData.fontSize or 12, zoneData.fontOutline or "")
    noteEditBox:SetAutoFocus(false)
    noteEditBox:SetMaxLetters(0)
    noteEditBox:SetText(zoneData.content or "")
    noteEditBox._skipGlobalFont = true
    propPreviewEditBox = noteEditBox
    noteEditBox:EnableMouse(false)
    noteScroll:SetScrollChild(noteEditBox)
    noteScroll:HookScript("OnSizeChanged", function(self, w)
        noteEditBox:SetWidth(math.max(1, w))
    end)

    dialog:Show()
end
