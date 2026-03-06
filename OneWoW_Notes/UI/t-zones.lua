-- OneWoW_Notes Addon File
-- OneWoW_Notes/UI/t-zones.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...
local L = ns.L
local T = ns.T
local S = ns.S

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
    -- =============================================
    -- CONTROL PANEL
    -- =============================================
    local controlPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    controlPanel:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, 0)
    controlPanel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    controlPanel:SetHeight(75)
    controlPanel:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = true, tileSize = 16, edgeSize = 1,
    })
    controlPanel:SetBackdropColor(T("BG_SECONDARY"))
    controlPanel:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local controlTitle = controlPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    controlTitle:SetPoint("TOPLEFT", controlPanel, "TOPLEFT", 10, -8)
    controlTitle:SetText(L["ZONES_CONTROLS"] or "Zones Controls")
    controlTitle:SetTextColor(T("TEXT_SECONDARY"))

    -- Add Current Zone
    local addCurrentBtn = ns.UI.CreateButton(nil, controlPanel, L["BUTTON_ADD_CURRENT_ZONE"] or "Add Zone", 110, 25)
    ns.UI.AutoResizeButton(addCurrentBtn, 80, 200)
    addCurrentBtn:SetPoint("TOPLEFT", controlPanel, "TOPLEFT", 10, -28)
    addCurrentBtn:SetScript("OnClick", function()
        if ns.Zones then
            local zoneName = ns.Zones:GetCurrentZoneName()
            if not zoneName or zoneName == "" then
                print("|cFFFFD100OneWoW - Zones:|r " .. (L["MSG_NO_ZONE_DETECTED"] or "Cannot determine zone."))
                return
            end
            local existing = ns.Zones:GetZone(zoneName)
            if existing then
                print("|cFFFFD100OneWoW - Zones:|r " .. string.format(L["MSG_ZONE_EXISTS"] or "Zone exists: %s", zoneName))
                if parent.SelectZone then parent.SelectZone(zoneName) end
                return
            end
            local mapInfo = ns.Zones:GetCurrentMapInfo()
            local zoneData = { content = "", category = "General", storage = "account" }
            if mapInfo then
                zoneData.mapID       = mapInfo.mapID
                zoneData.parentMapID = mapInfo.parentMapID
            end
            ns.Zones:AddZone(zoneName, zoneData)
            print("|cFFFFD100OneWoW - Zones:|r " .. string.format(L["MSG_ZONE_ADDED"] or "Added: %s", zoneName))
            if parent.SelectZone then parent.SelectZone(zoneName) end
        end
    end)
    addCurrentBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["TOOLTIP_BUTTON_ADD_CURRENT_ZONE"] or "Add Current Zone", 1, 1, 1)
        GameTooltip:AddLine(L["TOOLTIP_BUTTON_ADD_CURRENT_ZONE_DESC"] or "Add a note for your current zone.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    addCurrentBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Add Parent Zone
    local addParentBtn = ns.UI.CreateButton(nil, controlPanel, L["ZONE_ADD_PARENT"] or "Add Parent", 100, 25)
    ns.UI.AutoResizeButton(addParentBtn, 80, 200)
    addParentBtn:SetPoint("LEFT", addCurrentBtn, "RIGHT", 5, 0)
    addParentBtn:SetScript("OnClick", function()
        if ns.Zones then
            local parentZoneName = ns.Zones:GetParentZoneName()
            if not parentZoneName or parentZoneName == "" then
                print("|cFFFFD100OneWoW - Zones:|r " .. (L["MSG_NO_PARENT_ZONE"] or "Cannot determine parent zone."))
                return
            end
            local existing = ns.Zones:GetZone(parentZoneName)
            if existing then
                print("|cFFFFD100OneWoW - Zones:|r " .. string.format(L["MSG_ZONE_EXISTS"] or "Zone exists: %s", parentZoneName))
                if parent.SelectZone then parent.SelectZone(parentZoneName) end
                return
            end
            local mapInfo = ns.Zones:GetCurrentMapInfo()
            local zoneData = { content = "", category = "General", storage = "account" }
            if mapInfo and mapInfo.parentMapID and mapInfo.parentMapID > 0 then
                local parentInfo = C_Map.GetMapInfo(mapInfo.parentMapID)
                if parentInfo then
                    zoneData.mapID = mapInfo.parentMapID
                    zoneData.parentMapID = parentInfo.parentMapID
                end
            end
            ns.Zones:AddZone(parentZoneName, zoneData)
            print("|cFFFFD100OneWoW - Zones:|r " .. string.format(L["MSG_ZONE_ADDED"] or "Added: %s", parentZoneName))
            if parent.SelectZone then parent.SelectZone(parentZoneName) end
        end
    end)
    addParentBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["ZONE_ADD_PARENT"] or "Add Parent Zone", 1, 1, 1)
        GameTooltip:AddLine(L["ZONE_ADD_PARENT_DESC"] or "Add a note for the parent zone.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    addParentBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Manual entry
    local addManualBtn = ns.UI.CreateButton(nil, controlPanel, L["BUTTON_MANUAL_ENTRY"] or "Manual", 90, 25)
    ns.UI.AutoResizeButton(addManualBtn, 70, 200)
    addManualBtn:SetPoint("LEFT", addParentBtn, "RIGHT", 5, 0)
    addManualBtn:SetScript("OnClick", function()
        if ns.UI and ns.UI.ShowManualZoneEntryDialog then
            ns.UI.ShowManualZoneEntryDialog(parent)
        end
    end)
    addManualBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["BUTTON_MANUAL_ENTRY"] or "Manual Entry", 1, 1, 1)
        GameTooltip:AddLine(L["TOOLTIP_BUTTON_MANUAL_ENTRY_ZONE_DESC"] or "Enter a zone name manually.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    addManualBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Category dropdown
    local catDD = ns.UI.CreateThemedDropdown(controlPanel, L["LABEL_CATEGORY"], 140, 25)
    catDD:SetPoint("LEFT", addManualBtn, "RIGHT", 8, 0)
    local function RefreshCatOpts()
        local opts = {{text = L["UI_ALL"], value = "All"}}
        if ns.Zones then
            for _, c in ipairs(ns.Zones:GetCategories()) do
                table.insert(opts, {text = c, value = c})
            end
        end
        catDD:SetOptions(opts)
        catDD:SetSelected(categoryFilter)
    end
    RefreshCatOpts()
    catDD.onSelect = function(value)
        categoryFilter = value
        parent.RefreshZonesList()
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
            ns.UI.ShowCategoryManager("zones")
        end
    end)
    manageCategoriesBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["UI_MANAGE_CATEGORIES"], 1, 1, 1)
        GameTooltip:AddLine(L["UI_MANAGE_CATEGORIES_DESC"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    manageCategoriesBtn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)

    -- Storage dropdown
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
        parent.RefreshZonesList()
    end

    -- Help button
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

    -- =============================================
    -- LISTING PANEL
    -- =============================================
    local listingPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    listingPanel:SetPoint("TOPLEFT",  controlPanel, "BOTTOMLEFT",  0, -10)
    listingPanel:SetPoint("BOTTOMLEFT", parent,     "BOTTOMLEFT",  0, 35)
    listingPanel:SetWidth(258)
    listingPanel:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = true, tileSize = 16, edgeSize = 1,
    })
    listingPanel:SetBackdropColor(T("BG_PRIMARY"))
    listingPanel:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local listingTitle = listingPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    listingTitle:SetPoint("TOP", listingPanel, "TOP", 0, -10)
    listingTitle:SetText(L["ZONES_LIST"] or "Zones")
    listingTitle:SetTextColor(T("ACCENT_PRIMARY"))

    local listScroll = ns.UI.CreateCustomScroll(listingPanel)
    scrollFrame = listScroll.scrollFrame
    scrollChild = listScroll.scrollChild
    listScroll.container:SetPoint("TOPLEFT",     listingPanel, "TOPLEFT",     10, -40)
    listScroll.container:SetPoint("BOTTOMRIGHT", listingPanel, "BOTTOMRIGHT", -10, 10)

    -- =============================================
    -- DETAIL PANEL
    -- =============================================
    detailPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    detailPanel:SetPoint("TOPLEFT",     listingPanel, "TOPRIGHT",    10, 0)
    detailPanel:SetPoint("BOTTOMRIGHT", parent,       "BOTTOMRIGHT",  0, 35)
    detailPanel:SetClipsChildren(true)
    detailPanel:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = true, tileSize = 16, edgeSize = 1,
    })
    detailPanel:SetBackdropColor(T("BG_PRIMARY"))
    detailPanel:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    emptyMessage = detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    emptyMessage:SetPoint("CENTER", detailPanel, "CENTER")
    emptyMessage:SetText(L["ZONES_SELECT"] or "Select a zone to view its note.")
    emptyMessage:SetTextColor(0.6, 0.6, 0.7, 1)

    -- =============================================
    -- STATUS BARS
    -- =============================================
    local leftStatusBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    leftStatusBar:SetPoint("TOPLEFT",  listingPanel, "BOTTOMLEFT",  0, -5)
    leftStatusBar:SetPoint("TOPRIGHT", listingPanel, "BOTTOMRIGHT", 0, -5)
    leftStatusBar:SetHeight(25)
    leftStatusBar:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = true, tileSize = 16, edgeSize = 1,
    })
    leftStatusBar:SetBackdropColor(T("BG_SECONDARY"))
    leftStatusBar:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    leftStatusText = leftStatusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    leftStatusText:SetPoint("LEFT", leftStatusBar, "LEFT", 10, 0)
    leftStatusText:SetTextColor(T("TEXT_SECONDARY"))
    leftStatusText:SetText(string.format(L["UI_COUNT_FORMAT"], L["TAB_ZONES"], 0))

    local rightStatusBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    rightStatusBar:SetPoint("TOPLEFT",     detailPanel, "BOTTOMLEFT",  0, -5)
    rightStatusBar:SetPoint("TOPRIGHT",    detailPanel, "BOTTOMRIGHT", 0, -5)
    rightStatusBar:SetHeight(25)
    rightStatusBar:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = true, tileSize = 16, edgeSize = 1,
    })
    rightStatusBar:SetBackdropColor(T("BG_SECONDARY"))
    rightStatusBar:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local rightStatusText = rightStatusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rightStatusText:SetPoint("LEFT", rightStatusBar, "LEFT", 10, 0)
    rightStatusText:SetTextColor(T("TEXT_SECONDARY"))
    rightStatusText:SetText(L["STATUS_READY"])

    -- =============================================
    -- SHOW EDITOR
    -- =============================================
    local function ShowEditor()
        emptyMessage:Hide()
        for _, child in ipairs({detailPanel:GetChildren()}) do
            if child ~= emptyMessage then child:Hide() end
        end

        if not detailPanel.editorContent then
            local editorHeader = CreateFrame("Frame", nil, detailPanel, "BackdropTemplate")
            editorHeader:SetPoint("TOPLEFT",  detailPanel, "TOPLEFT",  10, -10)
            editorHeader:SetPoint("TOPRIGHT", detailPanel, "TOPRIGHT", -10, -10)
            editorHeader:SetHeight(85)
            editorHeader:SetBackdrop({
                bgFile   = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                tile = true, tileSize = 16, edgeSize = 1,
            })
            editorHeader:SetBackdropColor(T("BG_SECONDARY"))
            editorHeader:SetBackdropBorderColor(T("BORDER_DEFAULT"))

            local nameText = editorHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            nameText:SetPoint("TOPLEFT", editorHeader, "TOPLEFT", 12, -12)
            nameText:SetPoint("TOPRIGHT", editorHeader, "TOPRIGHT", -100, -12)
            nameText:SetJustifyH("LEFT")
            nameText:SetText("")
            nameText:SetTextColor(T("ACCENT_PRIMARY"))
            editorHeader.nameText = nameText

            local categoryLine = editorHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            categoryLine:SetPoint("BOTTOMRIGHT", editorHeader, "BOTTOMRIGHT", -12, 8)
            categoryLine:SetText(string.format(L["UI_CATEGORY_WITH_VALUE"], L["UI_GENERAL"]))
            categoryLine:SetTextColor(T("ACCENT_PRIMARY"))
            categoryLine:SetJustifyH("RIGHT")
            editorHeader.categoryLine = categoryLine

            -- Delete
            local deleteBtn = CreateFrame("Button", nil, editorHeader)
            deleteBtn:SetSize(22, 22)
            deleteBtn:SetPoint("TOPRIGHT", editorHeader, "TOPRIGHT", -12, -12)
            deleteBtn:SetNormalTexture(MEDIA .. "icon-trash.png")
            deleteBtn:SetPushedTexture(MEDIA .. "icon-trash.png")
            deleteBtn:SetHighlightTexture(MEDIA .. "icon-trash.png")
            deleteBtn:GetHighlightTexture():SetAlpha(0.5)
            deleteBtn:SetScript("OnClick", function()
                if selectedZone then
                    StaticPopupDialogs["ONEWOW_NOTES_CONFIRM_DELETE_ZONE"] = {
                        text = string.format(L["POPUP_DELETE_ZONE"] or "Delete zone note?"),
                        button1 = L["BUTTON_DELETE"], button2 = L["BUTTON_CANCEL"],
                        OnAccept = function()
                            if ns.Zones then
                                ns.Zones:RemoveZone(selectedZone)
                                selectedZone = nil
                                if detailPanel.editorContent then
                                    for _, f in pairs(detailPanel.editorContent) do
                                        if f and f.Hide then f:Hide() end
                                    end
                                end
                                parent.RefreshZonesList()
                                emptyMessage:Show()
                            end
                        end,
                        timeout = 0, whileDead = true, hideOnEscape = true
                    }
                    StaticPopup_Show("ONEWOW_NOTES_CONFIRM_DELETE_ZONE")
                end
            end)
            deleteBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["TOOLTIP_ZONE_DELETE"] or "Delete Zone", 1, 1, 1)
                GameTooltip:AddLine(L["TOOLTIP_ZONE_DELETE_DESC"] or "Remove this zone note", 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            deleteBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            editorHeader.deleteBtn = deleteBtn

            -- Properties
            local propertiesBtn = CreateFrame("Button", nil, editorHeader)
            propertiesBtn:SetSize(22, 22)
            propertiesBtn:SetPoint("RIGHT", deleteBtn, "LEFT", -2, 0)
            propertiesBtn:SetNormalTexture(MEDIA .. "icon-gears.png")
            propertiesBtn:SetPushedTexture(MEDIA .. "icon-gears.png")
            propertiesBtn:SetHighlightTexture(MEDIA .. "icon-gears.png")
            propertiesBtn:GetHighlightTexture():SetAlpha(0.5)
            propertiesBtn:SetScript("OnClick", function()
                if selectedZone and ns.UI and ns.UI.ShowZonePropertiesDialog then
                    ns.UI.ShowZonePropertiesDialog(selectedZone, parent)
                end
            end)
            propertiesBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["TOOLTIP_ZONE_PROPERTIES"] or "Zone Properties", 1, 1, 1)
                GameTooltip:AddLine(L["TOOLTIP_ZONE_PROPERTIES_DESC"] or "Edit zone settings", 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            propertiesBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            editorHeader.propertiesBtn = propertiesBtn

            -- Alert button
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
                if selectedZone and ns.Zones then
                    local zoneData = ns.Zones:GetZone(selectedZone)
                    if zoneData then
                        zoneData.alertEnabled = not zoneData.alertEnabled
                        aN:SetDesaturated(not zoneData.alertEnabled)
                        aN:SetAlpha(zoneData.alertEnabled and 1.0 or 0.3)
                        self:SetChecked(zoneData.alertEnabled)
                        ns.Zones:SaveZone(selectedZone, zoneData)
                        parent.RefreshZonesList()
                    end
                end
            end)
            alertBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["TOOLTIP_ZONE_SOUND"] or "Zone Alert", 1, 1, 1)
                GameTooltip:AddLine(L["TOOLTIP_ZONE_SOUND_DESC"] or "Alert when entering this zone.", 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            alertBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            editorHeader.alertBtn = alertBtn

            -- Pin button
            local pinBtn = CreateFrame("CheckButton", nil, editorHeader)
            pinBtn:SetSize(22, 22)
            pinBtn:SetPoint("RIGHT", alertBtn, "LEFT", -2, 0)

            local pinNormal = pinBtn:CreateTexture(nil, "BACKGROUND")
            pinNormal:SetAllPoints()
            pinNormal:SetTexture(MEDIA .. "icon-pin.png")
            pinNormal:SetDesaturated(true)
            pinNormal:SetAlpha(0.3)
            pinBtn:SetNormalTexture(pinNormal)

            local pinHL = pinBtn:CreateTexture(nil, "HIGHLIGHT")
            pinHL:SetAllPoints()
            pinHL:SetTexture(MEDIA .. "icon-pin.png")
            pinHL:SetAlpha(0.5)
            pinBtn:SetHighlightTexture(pinHL)

            pinBtn:SetScript("OnClick", function(self)
                if selectedZone and ns.Zones then
                    local zd = ns.Zones:GetZone(selectedZone)
                    if zd then
                        zd.pinEnabled = not zd.pinEnabled
                        pinNormal:SetDesaturated(not zd.pinEnabled)
                        pinNormal:SetAlpha(zd.pinEnabled and 1.0 or 0.3)
                        self:SetChecked(zd.pinEnabled)
                        -- Clear any dismissal so the pin shows immediately
                        zd.dismissedUntil = nil
                        ns.Zones:SaveZone(selectedZone, zd)
                        if zd.pinEnabled and ns.ZonePins then
                            ns.ZonePins:ShowZonePin(selectedZone, zd)
                        elseif not zd.pinEnabled and ns.ZonePins then
                            ns.ZonePins:HideZonePin(selectedZone)
                        end
                        parent.RefreshZonesList()
                    end
                end
            end)
            pinBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["TOOLTIP_ZONE_PIN"] or "Pin Zone", 1, 1, 1)
                GameTooltip:AddLine(L["TOOLTIP_ZONE_PIN_DESC"] or "Show a pinned window for this zone.", 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            pinBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            editorHeader.pinBtn = pinBtn

            -- Favorite button
            local favoriteBtn = CreateFrame("CheckButton", nil, editorHeader)
            favoriteBtn:SetSize(22, 22)
            favoriteBtn:SetPoint("RIGHT", pinBtn, "LEFT", -2, 0)
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
                if selectedZone and ns.Zones then
                    local zoneData = ns.Zones:GetZone(selectedZone)
                    if zoneData then
                        zoneData.favorite = not zoneData.favorite
                        fN:SetDesaturated(not zoneData.favorite)
                        fN:SetAlpha(zoneData.favorite and 1.0 or 0.3)
                        self:SetChecked(zoneData.favorite)
                        ns.Zones:SaveZone(selectedZone, zoneData)
                        parent.RefreshZonesList()
                    end
                end
            end)
            favoriteBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["TOOLTIP_ZONE_FAVORITE"] or "Favorite", 1, 1, 1)
                GameTooltip:AddLine(L["TOOLTIP_ZONE_FAVORITE_DESC"] or "Mark as favorite", 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            favoriteBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            editorHeader.favoriteBtn = favoriteBtn

            -- Content area
            local contentBg = CreateFrame("Frame", nil, detailPanel, "BackdropTemplate")
            contentBg:SetPoint("TOPLEFT",  editorHeader, "BOTTOMLEFT",  0, -10)
            contentBg:SetPoint("TOPRIGHT", editorHeader, "BOTTOMRIGHT", 0, -10)
            contentBg:SetHeight(190)
            contentBg:SetBackdrop({
                bgFile   = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                tile = true, tileSize = 16, edgeSize = 1,
            })
            contentBg:SetBackdropColor(T("BG_SECONDARY"))
            contentBg:SetBackdropBorderColor(T("BORDER_DEFAULT"))
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
                if userInput and selectedZone and ns.Zones then
                    local zoneData = ns.Zones:GetZone(selectedZone)
                    if zoneData then
                        zoneData.content  = self:GetText()
                        zoneData.modified = GetServerTime()
                    end
                end
            end)
            contentEditBox:SetScript("OnReceiveDrag", function(self)
                local cursorType, itemID, itemLink = GetCursorInfo()
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

            -- Todo section
            local todoSection = CreateFrame("Frame", nil, detailPanel)
            todoSection:SetPoint("TOPLEFT",  contentBg, "BOTTOMLEFT",  0, -10)
            todoSection:SetPoint("BOTTOMRIGHT", detailPanel, "BOTTOMRIGHT", -8, 10)
            todoSection:SetClipsChildren(true)

            local todoHeader = CreateFrame("Frame", nil, todoSection)
            todoHeader:SetPoint("TOPLEFT",  todoSection, "TOPLEFT",  0, 0)
            todoHeader:SetPoint("TOPRIGHT", todoSection, "TOPRIGHT", -22, 0)
            todoHeader:SetHeight(30)

            local todoLabel = todoHeader:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            todoLabel:SetPoint("LEFT", todoHeader, "LEFT", 5, 0)
            todoLabel:SetText(L["UI_TASKS"])
            todoLabel:SetTextColor(T("TEXT_PRIMARY"))

            local addTaskBtn = CreateFrame("Button", nil, todoHeader)
            addTaskBtn:SetSize(24, 24)
            addTaskBtn:SetPoint("RIGHT", todoHeader, "RIGHT", 0, 0)
            addTaskBtn:SetNormalTexture(MEDIA .. "icon-add.png")
            addTaskBtn:SetHighlightTexture(MEDIA .. "icon-add.png")
            addTaskBtn:SetPushedTexture(MEDIA .. "icon-add.png")
            addTaskBtn:GetHighlightTexture():SetAlpha(0.5)

            local taskInputBox = CreateFrame("EditBox", nil, todoHeader, "InputBoxTemplate")
            taskInputBox:SetPoint("LEFT",  todoLabel,  "RIGHT", 10, 0)
            taskInputBox:SetPoint("RIGHT", addTaskBtn, "LEFT",  -5, 0)
            taskInputBox:SetHeight(25)
            taskInputBox:SetAutoFocus(false)
            taskInputBox:SetScript("OnEnterPressed", function(self)
                local text = self:GetText()
                if text and text ~= "" and selectedZone and ns.Zones then
                    ns.Zones:AddTodo(selectedZone, text)
                    self:SetText("")
                    if parent.RefreshZoneTodoList then parent.RefreshZoneTodoList() end
                end
                self:ClearFocus()
            end)
            addTaskBtn:SetScript("OnClick", function()
                local text = taskInputBox:GetText()
                if text and text ~= "" and selectedZone and ns.Zones then
                    ns.Zones:AddTodo(selectedZone, text)
                    taskInputBox:SetText("")
                    if parent.RefreshZoneTodoList then parent.RefreshZoneTodoList() end
                end
            end)

            local todoScroll = CreateFrame("ScrollFrame", nil, todoSection, "UIPanelScrollFrameTemplate")
            todoScroll:SetPoint("TOPLEFT",     todoHeader, "BOTTOMLEFT",  0, -5)
            todoScroll:SetPoint("BOTTOMRIGHT", todoSection, "BOTTOMRIGHT", -22, 0)

            todoContainer = CreateFrame("Frame", nil, todoScroll)
            todoContainer:SetSize(todoScroll:GetWidth() - 20, 1)
            todoScroll:SetScrollChild(todoContainer)
            detailPanel.todoContainer = todoContainer

            detailPanel.editorContent = {
                header        = editorHeader,
                contentBg     = contentBg,
                contentScroll = contentScroll,
                todoSection   = todoSection,
            }
        end

        for _, f in pairs(detailPanel.editorContent) do
            if f and f.Show then f:Show() end
        end
        if detailPanel.contentEditBox then detailPanel.contentEditBox:Show() end

        -- Populate from selected zone
        if selectedZone and ns.Zones then
            local zoneData = ns.Zones:GetZone(selectedZone)
            if zoneData then
                local header = detailPanel.editorContent.header

                if header.nameText then
                    header.nameText:SetText(selectedZone)
                end
                if header.categoryLine then
                    header.categoryLine:SetText(string.format(L["UI_CATEGORY_WITH_VALUE"], zoneData.category or L["UI_GENERAL"]))
                end

                -- Color content bg by pinColor
                local pinColor   = zoneData.pinColor  or "hunter"
                local fontColor  = zoneData.fontColor or "match"
                local fontSize   = zoneData.fontSize  or 12
                local opacity    = zoneData.opacity   or 0.9
                local colorConfig = ns.Config:GetResolvedColorConfig(pinColor)
                local bgColor    = colorConfig.background
                local borderColor = colorConfig.border
                local listItemColor = colorConfig.listItem

                header:SetBackdropColor(listItemColor[1], listItemColor[2], listItemColor[3], listItemColor[4] or 0.9)
                header:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], 1)
                if header.nameText then
                    local tc = GetFontColorFromKey(fontColor, pinColor)
                    header.nameText:SetTextColor(tc[1], tc[2], tc[3])
                end

                if detailPanel.editorContent.contentBg then
                    detailPanel.editorContent.contentBg:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], opacity)
                    detailPanel.editorContent.contentBg:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], 1)
                end

                if detailPanel.contentEditBox then
                    local tc = GetFontColorFromKey(fontColor, pinColor)
                    detailPanel.contentEditBox:SetTextColor(tc[1], tc[2], tc[3], 1)
                    local detailFontPath = "Fonts\\FRIZQT__.TTF"
                    if zoneData.fontFamily then
                        local LSM = LibStub("LibSharedMedia-3.0", true)
                        if LSM then
                            local path = LSM:Fetch("font", zoneData.fontFamily)
                            if path then detailFontPath = path end
                        end
                    end
                    detailPanel.contentEditBox:SetFont(detailFontPath, fontSize, zoneData.fontOutline or "")
                    detailPanel.contentEditBox:SetText(zoneData.content or "")
                end

                if header.alertBtn then
                    header.alertBtn:GetNormalTexture():SetDesaturated(not zoneData.alertEnabled)
                    header.alertBtn:GetNormalTexture():SetAlpha(zoneData.alertEnabled and 1.0 or 0.3)
                    header.alertBtn:SetChecked(zoneData.alertEnabled)
                end
                if header.pinBtn then
                    local addon = _G.OneWoW_Notes
                    local pinActive = zoneData.pinEnabled and addon.zonePins and addon.zonePins[selectedZone]
                    header.pinBtn:GetNormalTexture():SetDesaturated(not zoneData.pinEnabled)
                    header.pinBtn:GetNormalTexture():SetAlpha(zoneData.pinEnabled and 1.0 or 0.3)
                    header.pinBtn:SetChecked(zoneData.pinEnabled and true or false)
                end
                if header.favoriteBtn then
                    header.favoriteBtn:GetNormalTexture():SetDesaturated(not zoneData.favorite)
                    header.favoriteBtn:GetNormalTexture():SetAlpha(zoneData.favorite and 1.0 or 0.3)
                    header.favoriteBtn:SetChecked(zoneData.favorite)
                end

                if parent.RefreshZoneTodoList then parent.RefreshZoneTodoList() end
            end
        end
    end

    -- =============================================
    -- RefreshZoneTodoList
    -- =============================================
    function parent.RefreshZoneTodoList()
        if not todoContainer or not selectedZone then return end

        for _, child in ipairs({todoContainer:GetChildren()}) do
            child:Hide()
            child:SetParent(nil)
        end

        if not ns.Zones then return end
        local zoneData = ns.Zones:GetZone(selectedZone)
        if not zoneData or not zoneData.todos then return end

        local yOffset = 0
        for _, todo in ipairs(zoneData.todos) do
            local todoFrame = CreateFrame("Frame", nil, todoContainer)
            todoFrame:SetPoint("TOPLEFT", todoContainer, "TOPLEFT", 0, yOffset)
            todoFrame:SetSize(todoContainer:GetWidth(), 25)

            local checkbox = CreateFrame("CheckButton", nil, todoFrame, "UICheckButtonTemplate")
            checkbox:SetSize(20, 20)
            checkbox:SetPoint("LEFT", todoFrame, "LEFT", 5, 0)
            checkbox:SetChecked(todo.completed)
            checkbox:SetScript("OnClick", function(self)
                if ns.Zones then
                    ns.Zones:UpdateTodo(selectedZone, todo.id, nil, self:GetChecked())
                    parent.RefreshZoneTodoList()
                end
            end)

            local todoEditBox = CreateFrame("EditBox", nil, todoFrame, "InputBoxTemplate")
            todoEditBox:SetPoint("LEFT",  checkbox,  "RIGHT", 10, 0)
            todoEditBox:SetPoint("RIGHT", todoFrame,  "RIGHT", -35, 0)
            todoEditBox:SetHeight(20)
            todoEditBox:SetAutoFocus(false)
            todoEditBox:SetText(todo.text or "")
            todoEditBox:SetTextColor(todo.completed and 0.5 or 1, todo.completed and 0.5 or 1, todo.completed and 0.5 or 1)
            todoEditBox:SetScript("OnEnterPressed", function(self)
                if ns.Zones then ns.Zones:UpdateTodo(selectedZone, todo.id, self:GetText(), todo.completed) end
                self:ClearFocus()
            end)
            todoEditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
            todoEditBox:SetScript("OnEditFocusLost", function(self)
                if ns.Zones then ns.Zones:UpdateTodo(selectedZone, todo.id, self:GetText(), todo.completed) end
            end)
            todoEditBox:SetScript("OnMouseUp", function(self, button)
                if button == "RightButton" and ns.NotesContextMenu then
                    ns.NotesContextMenu:ShowEditBoxContextMenu(self)
                end
            end)
            if ns.NotesHyperlinks then ns.NotesHyperlinks:EnhanceEditBox(todoEditBox) end

            local deleteTodoBtn = CreateFrame("Button", nil, todoFrame)
            deleteTodoBtn:SetSize(16, 16)
            deleteTodoBtn:SetPoint("RIGHT", todoFrame, "RIGHT", -5, 0)
            deleteTodoBtn:SetNormalTexture(MEDIA .. "icon-minus.png")
            deleteTodoBtn:SetPushedTexture(MEDIA .. "icon-minus.png")
            deleteTodoBtn:SetHighlightTexture(MEDIA .. "icon-minus.png")
            deleteTodoBtn:GetHighlightTexture():SetAlpha(0.5)
            deleteTodoBtn:SetScript("OnClick", function()
                if ns.Zones then
                    ns.Zones:RemoveTodo(selectedZone, todo.id)
                    parent.RefreshZoneTodoList()
                end
            end)

            yOffset = yOffset - 30
        end

        todoContainer:SetHeight(math.abs(yOffset) + 50)
    end

    -- =============================================
    -- SelectZone
    -- =============================================
    function parent.SelectZone(zoneName)
        selectedZone = zoneName
        ShowEditor()
        parent.RefreshZonesList()
    end

    -- =============================================
    -- RefreshZonesList
    -- =============================================
    local function CreateSectionHeader(text, yPos)
        local header = CreateFrame("Frame", nil, scrollChild)
        header:SetSize(scrollChild:GetWidth(), 25)
        header:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yPos)

        local bg = header:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetAtlas("UI-CastingBar-Background")
        local frame2 = header:CreateTexture(nil, "BORDER")
        frame2:SetAllPoints()
        frame2:SetAtlas("UI-CastingBar-Full-Glow-Standard")
        local tint = header:CreateTexture(nil, "ARTWORK")
        tint:SetAllPoints()
        tint:SetColorTexture(0, 0, 0, 0.4)

        local headerText = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        headerText:SetPoint("CENTER", header, "CENTER")
        headerText:SetText(text)
        headerText:SetTextColor(1, 0.82, 0)

        table.insert(zoneListItems, header)
        return header
    end

    function parent.RefreshZonesList()
        for _, item in pairs(zoneListItems) do
            item:Hide()
            item:SetParent(nil)
        end
        zoneListItems = {}

        if not ns.Zones then
            if leftStatusText then leftStatusText:SetText(string.format(L["UI_COUNT_FORMAT"], L["TAB_ZONES"], 0)) end
            return
        end

        local allZones = ns.Zones:GetAllZones()
        local zonesList = {}

        for zoneName, zoneData in pairs(allZones) do
            if type(zoneData) == "table" then
                local matches = true
                if categoryFilter ~= "All" and zoneData.category ~= categoryFilter then matches = false end
                if storageFilter  ~= "All" and zoneData.storage  ~= storageFilter  then matches = false end
                if matches then
                    table.insert(zonesList, {name = zoneName, data = zoneData})
                end
            end
        end

        local now = GetServerTime()
        for _, zone in ipairs(zonesList) do
            if zone.data.isNew and zone.data.newTimestamp then
                if (now - zone.data.newTimestamp) > 3600 then
                    zone.data.isNew = false
                    zone.data.newTimestamp = nil
                end
            end
        end

        local newZones  = {}
        local favorites = {}
        local regular   = {}
        for _, zone in ipairs(zonesList) do
            if zone.data.isNew then
                table.insert(newZones, zone)
            elseif zone.data.favorite then
                table.insert(favorites, zone)
            else
                table.insert(regular, zone)
            end
        end

        local function sortByName(a, b) return a.name < b.name end
        table.sort(newZones,  sortByName)
        table.sort(favorites, sortByName)
        table.sort(regular,   sortByName)

        local function BuildZoneRow(zone, yOffset)
            local pinColor    = zone.data.pinColor or "hunter"
            local colorConfig = ns.Config:GetResolvedColorConfig(pinColor)
            local listItemColor = colorConfig.listItem
            local borderColor = colorConfig.border

            local row = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
            row:SetSize(scrollChild:GetWidth(), 50)
            row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yOffset)
            row:SetBackdrop({
                bgFile   = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                tile = true, tileSize = 16, edgeSize = 1,
            })
            row:SetBackdropColor(listItemColor[1], listItemColor[2], listItemColor[3], listItemColor[4])
            row:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], 1)

            local titleText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            titleText:SetPoint("TOPLEFT",  row, "TOPLEFT",  10, -10)
            titleText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, -10)
            titleText:SetJustifyH("LEFT")
            titleText:SetText(zone.name)
            local tc = GetFontColorFromKey(zone.data.fontColor or "match", pinColor)
            titleText:SetTextColor(tc[1], tc[2], tc[3])

            -- Delete
            local deleteBtn = CreateFrame("Button", nil, row)
            deleteBtn:SetSize(18, 18)
            deleteBtn:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -5, 5)
            deleteBtn:SetNormalTexture(MEDIA .. "icon-trash.png")
            deleteBtn:SetPushedTexture(MEDIA .. "icon-trash.png")
            deleteBtn:SetHighlightTexture(MEDIA .. "icon-trash.png")
            deleteBtn:GetHighlightTexture():SetAlpha(0.5)
            deleteBtn:SetScript("OnClick", function()
                StaticPopupDialogs["ONEWOW_NOTES_CONFIRM_DELETE_ZONE"] = {
                    text = string.format(L["POPUP_DELETE_ZONE"] or "Delete zone note?"),
                    button1 = L["BUTTON_DELETE"], button2 = L["BUTTON_CANCEL"],
                    OnAccept = function()
                        if ns.Zones then
                            ns.Zones:RemoveZone(zone.name)
                            if selectedZone == zone.name then
                                selectedZone = nil
                                emptyMessage:Show()
                                if detailPanel.editorContent then
                                    for _, f in pairs(detailPanel.editorContent) do
                                        if f and f.Hide then f:Hide() end
                                    end
                                end
                            end
                            parent.RefreshZonesList()
                        end
                    end,
                    timeout = 0, whileDead = true, hideOnEscape = true,
                }
                StaticPopup_Show("ONEWOW_NOTES_CONFIRM_DELETE_ZONE")
            end)

            -- Properties
            local propertiesBtn = CreateFrame("Button", nil, row)
            propertiesBtn:SetSize(18, 18)
            propertiesBtn:SetPoint("RIGHT", deleteBtn, "LEFT", -2, 0)
            propertiesBtn:SetNormalTexture(MEDIA .. "icon-gears.png")
            propertiesBtn:SetPushedTexture(MEDIA .. "icon-gears.png")
            propertiesBtn:SetHighlightTexture(MEDIA .. "icon-gears.png")
            propertiesBtn:GetHighlightTexture():SetAlpha(0.5)
            propertiesBtn:SetScript("OnClick", function()
                if ns.UI.ShowZonePropertiesDialog then ns.UI.ShowZonePropertiesDialog(zone.name, parent) end
            end)

            -- Alert
            local alertBtn = CreateFrame("CheckButton", nil, row)
            alertBtn:SetSize(18, 18)
            alertBtn:SetPoint("RIGHT", propertiesBtn, "LEFT", -2, 0)
            local aN2 = alertBtn:CreateTexture(nil, "BACKGROUND")
            aN2:SetAllPoints()
            aN2:SetTexture(MEDIA .. "icon-alert.png")
            aN2:SetDesaturated(not zone.data.alertEnabled)
            aN2:SetAlpha(zone.data.alertEnabled and 1.0 or 0.3)
            alertBtn:SetNormalTexture(aN2)
            alertBtn:SetScript("OnClick", function(self)
                if ns.Zones then
                    local zoneData = ns.Zones:GetZone(zone.name)
                    if zoneData then
                        zoneData.alertEnabled = not zoneData.alertEnabled
                        aN2:SetDesaturated(not zoneData.alertEnabled)
                        aN2:SetAlpha(zoneData.alertEnabled and 1.0 or 0.3)
                        ns.Zones:SaveZone(zone.name, zoneData)
                        if selectedZone == zone.name and detailPanel.editorContent and detailPanel.editorContent.header then
                            local h = detailPanel.editorContent.header
                            if h.alertBtn then
                                h.alertBtn:GetNormalTexture():SetDesaturated(not zoneData.alertEnabled)
                                h.alertBtn:GetNormalTexture():SetAlpha(zoneData.alertEnabled and 1.0 or 0.3)
                                h.alertBtn:SetChecked(zoneData.alertEnabled)
                            end
                        end
                    end
                end
            end)

            -- Favorite
            local favBtn = CreateFrame("CheckButton", nil, row)
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
    lbl:SetTextColor(T("TEXT_SECONDARY"))
    return lbl
end

local function MakeZoneInput(parent, x, y, w)
    local input = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    input:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    input:SetSize(w, 26)
    input:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    input:SetBackdropColor(T("BG_SECONDARY"))
    input:SetBackdropBorderColor(T("BORDER_DEFAULT"))
    input:SetFontObject("GameFontNormal")
    input:SetTextColor(T("TEXT_PRIMARY"))
    input:SetTextInsets(6, 6, 4, 4)
    input:SetAutoFocus(false)
    input:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return input
end

local function MakeZoneSlider(parent, name, x, y, w, minV, maxV, defV, fmt)
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    slider:SetWidth(w)
    slider:SetMinMaxValues(minV, maxV)
    slider:SetValue(defV)
    slider:SetValueStep(fmt == "pct" and 0.05 or 1)
    slider:SetObeyStepOnDrag(true)
    local lo  = _G[name .. "Low"]
    local hi  = _G[name .. "High"]
    local txt = _G[name .. "Text"]
    if lo  then lo:SetText(fmt == "pct" and (math.floor(minV * 100) .. "%") or tostring(math.floor(minV))) end
    if hi  then hi:SetText(fmt == "pct" and (math.floor(maxV * 100) .. "%") or tostring(math.floor(maxV))) end
    if txt then txt:SetText(fmt == "pct" and (math.floor(defV * 100 + 0.5) .. "%") or tostring(math.floor(defV + 0.5))) end
    return slider, txt
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
    validationFS:SetTextColor(T("TEXT_MUTED"))

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
    local fontSizeSlider, fontSizeTxt = MakeZoneSlider(content, "OneWoW_ZoneAddFontSize", COL1_X, yPos - LBL_GAP, COL_W, 10, 20, 12, "int")
    fontSizeSlider:SetScript("OnValueChanged", function(self, value)
        local val = math.floor(value + 0.5)
        if fontSizeTxt then fontSizeTxt:SetText(tostring(val)) end
        dialog._fontSize = val
    end)

    MakeZoneLabel(content, L["LABEL_NOTE_FONT"], COL2_X, yPos)
    dialog._fontFamily = nil
    local addPreviewEditBox = nil
    local addLSM = LibStub("LibSharedMedia-3.0", true)
    local addFontList = addLSM and addLSM:List("font") or {}
    table.sort(addFontList)
    local addFontOpts = {}
    for _, fn in ipairs(addFontList) do
        addFontOpts[#addFontOpts + 1] = {text = fn, value = fn}
    end
    addFontOpts[#addFontOpts + 1] = {text = L["FONT_DEFAULT"], value = "default"}
    local addFontDD = ns.UI.CreateFontDropdown(content, COL_W, 26)
    addFontDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL2_X, yPos - LBL_GAP)
    addFontDD:SetOptions(addFontOpts)
    addFontDD:SetSelected("default")
    addFontDD.onSelect = function(value)
        local fontValue = (value == "default") and nil or value
        dialog._fontFamily = fontValue
        if addPreviewEditBox then
            local fp = "Fonts\\FRIZQT__.TTF"
            if fontValue then
                local LSM = LibStub("LibSharedMedia-3.0", true)
                if LSM then
                    local p = LSM:Fetch("font", fontValue)
                    if p then fp = p end
                end
            end
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
            local fp = "Fonts\\FRIZQT__.TTF"
            if dialog._fontFamily then
                local LSM = LibStub("LibSharedMedia-3.0", true)
                if LSM then
                    local p = LSM:Fetch("font", dialog._fontFamily)
                    if p then fp = p end
                end
            end
            addPreviewEditBox:SetFont(fp, dialog._fontSize or 12, value)
        end
    end
    dialog._outlineDD = addOutlineDD

    MakeZoneLabel(content, L["LABEL_OPACITY"], COL1_X, yPos)
    dialog._opacity = 0.9
    local opacitySlider, opacityTxt = MakeZoneSlider(content, "OneWoW_ZoneAddOpacity", COL1_X, yPos - LBL_GAP, COL_W, 0.5, 1.0, 0.9, "pct")
    opacitySlider:SetScript("OnValueChanged", function(self, value)
        local val = math.floor(value * 100 + 0.5)
        if opacityTxt then opacityTxt:SetText(val .. "%") end
        dialog._opacity = value
    end)
    yPos = yPos - ROW_H

    MakeZoneLabel(content, L["LABEL_NOTE_CONTENT"] or "Note:", COL1_X, yPos)
    yPos = yPos - LBL_GAP

    local noteBg = CreateFrame("Frame", nil, content, "BackdropTemplate")
    noteBg:SetPoint("TOPLEFT",     content, "TOPLEFT",     COL1_X, yPos)
    noteBg:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -COL1_X, 6)
    noteBg:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    noteBg:SetBackdropColor(T("BG_SECONDARY"))
    noteBg:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local noteScroll = CreateFrame("ScrollFrame", nil, noteBg, "UIPanelScrollFrameTemplate")
    noteScroll:SetPoint("TOPLEFT",     noteBg, "TOPLEFT",     4, -4)
    noteScroll:SetPoint("BOTTOMRIGHT", noteBg, "BOTTOMRIGHT", -26, 4)

    local noteEditBox = CreateFrame("EditBox", nil, noteScroll)
    noteEditBox:SetMultiLine(true)
    noteEditBox:SetFont("Fonts\\FRIZQT__.TTF", dialog._fontSize or 12, dialog._fontOutline or "")
    noteEditBox:SetAutoFocus(false)
    noteEditBox:SetMaxLetters(0)
    noteScroll:SetScrollChild(noteEditBox)
    noteScroll:HookScript("OnSizeChanged", function(self, w)
        noteEditBox:SetWidth(math.max(1, w))
    end)
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
        validationFS:SetTextColor(T("TEXT_MUTED"))
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
    local fontSizeSlider, fontSizeTxt = MakeZoneSlider(content, "OneWoW_ZonePropFontSize", COL1_X, yPos - LBL_GAP, COL_W, 10, 20, zoneData.fontSize or 12, "int")
    fontSizeSlider:SetScript("OnValueChanged", function(self, value)
        local val = math.floor(value + 0.5)
        if fontSizeTxt then fontSizeTxt:SetText(tostring(val)) end
        SaveField("fontSize", val)
        RefreshEditor()
    end)

    MakeZoneLabel(content, L["LABEL_NOTE_FONT"], COL2_X, yPos)
    local propPreviewEditBox = nil
    local propLSM = LibStub("LibSharedMedia-3.0", true)
    local propFontList = propLSM and propLSM:List("font") or {}
    table.sort(propFontList)
    local propFontOpts = {}
    for _, fn in ipairs(propFontList) do
        propFontOpts[#propFontOpts + 1] = {text = fn, value = fn}
    end
    propFontOpts[#propFontOpts + 1] = {text = L["FONT_DEFAULT"], value = "default"}
    local propFontDD = ns.UI.CreateFontDropdown(content, COL_W, 26)
    propFontDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL2_X, yPos - LBL_GAP)
    propFontDD:SetOptions(propFontOpts)
    propFontDD:SetSelected(zoneData.fontFamily or "default")
    propFontDD.onSelect = function(value)
        local fontValue = (value == "default") and nil or value
        SaveField("fontFamily", fontValue)
        RefreshEditor()
        if propPreviewEditBox then
            local fp = "Fonts\\FRIZQT__.TTF"
            if fontValue then
                local LSM = LibStub("LibSharedMedia-3.0", true)
                if LSM then
                    local p = LSM:Fetch("font", fontValue)
                    if p then fp = p end
                end
            end
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
            local fp = "Fonts\\FRIZQT__.TTF"
            if d and d.fontFamily then
                local LSM = LibStub("LibSharedMedia-3.0", true)
                if LSM then
                    local p = LSM:Fetch("font", d.fontFamily)
                    if p then fp = p end
                end
            end
            propPreviewEditBox:SetFont(fp, d and d.fontSize or 12, value)
        end
    end

    MakeZoneLabel(content, L["LABEL_OPACITY"], COL1_X, yPos)
    local opacitySlider, opacityTxt = MakeZoneSlider(content, "OneWoW_ZonePropOpacity", COL1_X, yPos - LBL_GAP, COL_W, 0.5, 1.0, zoneData.opacity or 0.9, "pct")
    opacitySlider:SetScript("OnValueChanged", function(self, value)
        local val = math.floor(value * 100 + 0.5)
        if opacityTxt then opacityTxt:SetText(val .. "%") end
        SaveField("opacity", value)
        RefreshEditor()
    end)
    yPos = yPos - ROW_H

    MakeZoneLabel(content, L["LABEL_NOTE_PREVIEW"] or "Note:", COL1_X, yPos)
    yPos = yPos - LBL_GAP

    local noteBg = CreateFrame("Frame", nil, content, "BackdropTemplate")
    noteBg:SetPoint("TOPLEFT",     content, "TOPLEFT",     COL1_X, yPos)
    noteBg:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -COL1_X, 6)
    noteBg:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    noteBg:SetBackdropColor(T("BG_SECONDARY"))
    noteBg:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local noteScroll = CreateFrame("ScrollFrame", nil, noteBg, "UIPanelScrollFrameTemplate")
    noteScroll:SetPoint("TOPLEFT",     noteBg, "TOPLEFT",     4, -4)
    noteScroll:SetPoint("BOTTOMRIGHT", noteBg, "BOTTOMRIGHT", -26, 4)

    local noteEditBox = CreateFrame("EditBox", nil, noteScroll)
    noteEditBox:SetMultiLine(true)
    local propInitFontPath = "Fonts\\FRIZQT__.TTF"
    if zoneData.fontFamily then
        local LSM = LibStub("LibSharedMedia-3.0", true)
        if LSM then
            local path = LSM:Fetch("font", zoneData.fontFamily)
            if path then propInitFontPath = path end
        end
    end
    noteEditBox:SetFont(propInitFontPath, zoneData.fontSize or 12, zoneData.fontOutline or "")
    noteEditBox:SetAutoFocus(false)
    noteEditBox:SetMaxLetters(0)
    noteEditBox:SetText(zoneData.content or "")
    propPreviewEditBox = noteEditBox
    noteEditBox:EnableMouse(false)
    noteScroll:SetScrollChild(noteEditBox)
    noteScroll:HookScript("OnSizeChanged", function(self, w)
        noteEditBox:SetWidth(math.max(1, w))
    end)

    dialog:Show()
end
