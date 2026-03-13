-- OneWoW_QoL Addon File
-- OneWoW_QoL/Modules/external/vendorpanel/vendorpanel-ui.lua
local addonName, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local VendorPanel = ns.VendorPanel
local state = ns.VPState
local VPFilters = ns.VPFilters
local function GetItemStatus()
    return _G.OneWoW and _G.OneWoW.ItemStatus
end
local GetShowBlizzJunk = ns.VPGetShowBlizzJunk
local GetShowPanel = ns.VPGetShowPanel
local GetSettings = ns.VPGetSettings

local BACKDROP_SIMPLE = OneWoW_GUI.Constants.BACKDROP_SIMPLE

local backdropIconEdge = {
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
}

local function GetBrandIcon()
    local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
    local factionTheme = (OneWoW_GUI and OneWoW_GUI.GetSetting and OneWoW_GUI:GetSetting("minimap.theme")) or "horde"
    return OneWoW_GUI:GetBrandIcon(factionTheme)
end

local function GetFactionTheme()
    local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
    return (OneWoW_GUI and OneWoW_GUI.GetSetting and OneWoW_GUI:GetSetting("minimap.theme")) or "horde"
end

function VendorPanel:CreateVendorButton()
    if state.vendorButton then return end

    state.vendorButton = OneWoW_GUI:CreateButton(MerchantFrame, { name = "OneWoW_QoL_VendorButton", text = "Sell (0/0)", width = 100, height = 22 })
    state.vendorButton:SetPoint("TOPLEFT", MerchantFrame, "TOPLEFT", 60, -28)
    state.vendorButton:SetFrameLevel(MerchantFrame:GetFrameLevel() + 10)
    state.vendorButton.fontString = state.vendorButton.text
    state.vendorButton.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))

    state.vendorButton:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            VendorPanel:SellJunkItems()
            C_Timer.After(0.5, function() VendorPanel:UpdateButton() end)
        elseif button == "RightButton" then
            VendorPanel:TogglePreviewPanel()
        end
    end)

    state.vendorButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    state.vendorButton:SetScript("OnEnter", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
        self.text:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_HIGHLIGHT"))
        local junkCount = VendorPanel:GetJunkItemCount()
        local destroyCount = VendorPanel:GetDestroyableItemCount()
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(ns.L["VENDOR_JUNK_MANAGER"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:AddLine(ns.L["VENDOR_SELL_JUNK"], 1, 1, 1, true)
        GameTooltip:AddLine(ns.L["VENDOR_TOGGLE_PANEL"], 1, 1, 1, true)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine(string.format(ns.L["VENDOR_COUNTS_LABEL"], junkCount, destroyCount), OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        GameTooltip:Show()
    end)
    state.vendorButton:SetScript("OnLeave", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
        self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:Hide()
    end)

    state.vendorButton:Hide()
end

function VendorPanel:CreatePanelToggleButton()
    if state.panelToggleButton then return end

    state.panelToggleButton = CreateFrame("Button", "OneWoW_QoL_PanelToggle", MerchantFrame)
    state.panelToggleButton:SetSize(26, 26)
    state.panelToggleButton:SetPoint("TOPRIGHT", MerchantFrame, "TOPRIGHT", 32, -30)
    state.panelToggleButton:SetFrameLevel(MerchantFrame:GetFrameLevel() + 10)

    local icon = state.panelToggleButton:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(GetBrandIcon())
    state.panelToggleButton.icon = icon
    state.panelToggleButton:SetScript("OnShow", function() icon:SetTexture(GetBrandIcon()) end)

    state.panelToggleButton:SetScript("OnClick", function() VendorPanel:TogglePreviewPanel() end)

    state.panelToggleButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(ns.L["VENDOR_TOGGLE_PANEL_TOOLTIP"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        if state.junkPreviewPanel and state.junkPreviewPanel:IsShown() then
            GameTooltip:AddLine(ns.L["VENDOR_HIDE_PANEL"], 1, 1, 1, true)
        else
            GameTooltip:AddLine(ns.L["VENDOR_SHOW_PANEL"], 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)

    state.panelToggleButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    state.panelToggleButton:Hide()
end

function VendorPanel:CreateReplacementSellButton()
    if state.replacementSellButton then return end
    local blizzButton = _G["MerchantSellAllJunkButton"]
    if not blizzButton then return end

    state.replacementSellButton = OneWoW_GUI:CreateButton(MerchantFrame, { name = "OneWoW_QoL_ReplacementSellButton", text = "", width = blizzButton:GetWidth(), height = blizzButton:GetHeight() })
    state.replacementSellButton:SetPoint("CENTER", blizzButton, "CENTER", 0, 0)
    state.replacementSellButton:SetFrameLevel(blizzButton:GetFrameLevel() + 5)
    state.replacementSellButton.text:Hide()

    local icon = state.replacementSellButton:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", state.replacementSellButton, "TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", state.replacementSellButton, "BOTTOMRIGHT", -3, 3)
    icon:SetTexture(GetBrandIcon())
    state.replacementSellButton.icon = icon
    state.replacementSellButton:SetScript("OnShow", function() icon:SetTexture(GetBrandIcon()) end)

    state.replacementSellButton:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            VendorPanel:SellJunkItems()
            C_Timer.After(0.5, function() VendorPanel:UpdateButton() end)
        end
    end)

    state.replacementSellButton:HookScript("OnEnter", function(self)
        local junkCount = VendorPanel:GetJunkItemCount()
        local destroyCount = VendorPanel:GetDestroyableItemCount()
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddTexture(GetBrandIcon())
        GameTooltip:AddLine(ns.L["VENDOR_JUNK_MANAGER"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:AddLine(ns.L["VENDOR_SELL_JUNK"], 1, 1, 1, true)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine(string.format(ns.L["VENDOR_COUNTS_LABEL"], junkCount, destroyCount), OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        GameTooltip:Show()
    end)

    state.replacementSellButton:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    state.replacementSellButton:Hide()
end

function VendorPanel:CreatePreviewPanel()
    if state.junkPreviewPanel then return end

    local panelWidth = GetSettings().panelWidth or 320

    state.junkPreviewPanel = CreateFrame("Frame", "OneWoW_QoL_JunkPreviewPanel", MerchantFrame, "BackdropTemplate")
    state.junkPreviewPanel:SetWidth(panelWidth)
    state.junkPreviewPanel:SetPoint("TOPLEFT", MerchantFrame, "TOPRIGHT", 5, 0)
    state.junkPreviewPanel:SetPoint("BOTTOMLEFT", MerchantFrame, "BOTTOMRIGHT", 5, 0)
    state.junkPreviewPanel:SetFrameStrata("MEDIUM")
    state.junkPreviewPanel:SetToplevel(true)
    state.junkPreviewPanel:SetFrameLevel(MerchantFrame:GetFrameLevel() + 5)
    state.junkPreviewPanel:SetClipsChildren(true)
    state.junkPreviewPanel:SetResizable(true)
    state.junkPreviewPanel:SetResizeBounds(250, 100, 600, 2000)
    state.junkPreviewPanel:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER)
    state.junkPreviewPanel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    state.junkPreviewPanel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    local titleBar = OneWoW_GUI:CreateTitleBar(state.junkPreviewPanel, {
        title = ns.L["VENDOR_TOOLS_TITLE"],
        showBrand = true,
        factionTheme = GetFactionTheme(),
        onClose = function()
            state.junkPreviewPanel.manuallyHidden = true
            state.junkPreviewPanel:Hide()
            if state.filtersDialog then state.filtersDialog:Hide() end
            VendorPanel:ManageBlizzardSellButton(false)
            VendorPanel:UpdatePanelToggleButton()
        end,
    })
    state.junkPreviewPanel:SetScript("OnShow", function()
        if titleBar.brandIcon then titleBar.brandIcon:SetTexture(GetBrandIcon()) end
    end)

    local filterRow = CreateFrame("Frame", nil, state.junkPreviewPanel, "BackdropTemplate")
    filterRow:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, -1)
    filterRow:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, -1)
    filterRow:SetHeight(28)
    filterRow:SetBackdrop(BACKDROP_SIMPLE)
    filterRow:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))

    local filterLabel = filterRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    filterLabel:SetPoint("LEFT", filterRow, "LEFT", OneWoW_GUI:GetSpacing("SM"), 0)
    filterLabel:SetText(ns.L["VENDOR_FILTER_LABEL"])
    filterLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local vendorDropdown, dropText = OneWoW_GUI:CreateDropdown(filterRow, {
        height = 22,
        text = state.currentVendorFilter == "Cosmetic Items" and "Cosmetics" or state.currentVendorFilter,
    })
    vendorDropdown:SetPoint("LEFT", filterLabel, "RIGHT", OneWoW_GUI:GetSpacing("XS"), 0)
    vendorDropdown:SetPoint("RIGHT", filterRow, "RIGHT", -OneWoW_GUI:GetSpacing("SM"), 0)

    local function buildVendorFilterItems()
        local items = {}

        if state.availableFilters["Equipable"] then
            table.insert(items, {
                type = "checkbox",
                text = "All Armor Types",
                checked = state.showAllArmor,
                onToggle = function(checked)
                    state.showAllArmor = checked
                    local settings = GetSettings()
                    settings.showAllArmor = state.showAllArmor
                    if MerchantFrame and MerchantFrame:IsShown() then MerchantFrame_Update() end
                end,
            })
            table.insert(items, { type = "divider" })
        end

        table.insert(items, { text = "Show All", value = "Show All" })

        local collectibles = {"Mounts", "Pets", "Toys", "Cosmetic Items", "Decor", "Housing"}
        local numCollect = 0
        for _, label in ipairs(collectibles) do if state.availableFilters[label] then numCollect = numCollect + 1 end end
        if numCollect > 0 then
            table.insert(items, { type = "divider" })
            table.insert(items, { type = "header", text = "Collectibles" })
            for _, label in ipairs(collectibles) do
                if state.availableFilters[label] then
                    table.insert(items, { text = label, value = label })
                end
            end
        end

        local materials = {"Consumables", "Reagents"}
        local numMat = 0
        for _, label in ipairs(materials) do if state.availableFilters[label] then numMat = numMat + 1 end end
        if numMat > 0 then
            table.insert(items, { type = "divider" })
            table.insert(items, { type = "header", text = "Materials & Consumables" })
            for _, label in ipairs(materials) do
                if state.availableFilters[label] then
                    table.insert(items, { text = label, value = label })
                end
            end
        end

        local equipment = {"Equipable","Head","Neck","Shoulder","Back","Chest","Waist","Legs","Feet","Wrist","Hands","Rings","Trinkets","Weapons"}
        local numEquip = 0
        for _, label in ipairs(equipment) do if state.availableFilters[label] then numEquip = numEquip + 1 end end
        if numEquip > 0 then
            table.insert(items, { type = "divider" })
            table.insert(items, { type = "header", text = "Equipment" })
            for _, label in ipairs(equipment) do
                if state.availableFilters[label] then
                    table.insert(items, { text = label, value = label })
                end
            end
        end

        local professions = {"Alchemy","Blacksmithing","Cooking","Enchanting","Engineering","Inscription","Jewelcrafting","Leatherworking","Tailoring"}
        local numProf = 0
        for _, label in ipairs(professions) do if state.availableFilters[label] then numProf = numProf + 1 end end
        if state.availableFilters["Patterns"] or numProf > 0 then
            table.insert(items, { type = "divider" })
            table.insert(items, { type = "header", text = "Patterns / Recipes" })
            if state.availableFilters["Patterns"] then
                table.insert(items, { text = "All Patterns", value = "Patterns" })
            end
            for _, label in ipairs(professions) do
                if state.availableFilters[label] then
                    table.insert(items, { text = label, value = label })
                end
            end
        end

        return items
    end

    OneWoW_GUI:AttachFilterMenu(vendorDropdown, {
        searchable = false,
        menuHeight = 300,
        maxVisible = 50,
        getActiveValue = function() return state.currentVendorFilter end,
        buildItems = buildVendorFilterItems,
        onSelect = function(value, text)
            state.currentVendorFilter = value
            dropText:SetText(value == "Cosmetic Items" and "Cosmetics" or value)
            if MerchantFrame and MerchantFrame:IsShown() then MerchantFrame_Update() end
        end,
    })

    vendorDropdown.RefreshFilters = function()
        dropText:SetText(state.currentVendorFilter == "Cosmetic Items" and "Cosmetics" or state.currentVendorFilter)
    end

    state.junkPreviewPanel.vendorDropdown = vendorDropdown

    local dimKnownRow = CreateFrame("Button", nil, state.junkPreviewPanel, "BackdropTemplate")
    dimKnownRow:SetPoint("TOPLEFT", filterRow, "BOTTOMLEFT", 0, -1)
    dimKnownRow:SetPoint("TOPRIGHT", filterRow, "BOTTOMRIGHT", 0, -1)
    dimKnownRow:SetHeight(24)
    dimKnownRow:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_SIMPLE)
    dimKnownRow:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))

    local dimCheckBox = OneWoW_GUI:CreateCheckbox(dimKnownRow, { label = ns.L["VENDOR_DIM_KNOWN"] })
    dimCheckBox:SetSize(18, 18)
    dimCheckBox:SetPoint("LEFT", dimKnownRow, "LEFT", OneWoW_GUI:GetSpacing("SM"), 0)
    dimCheckBox:SetChecked(state.dimKnownItems)
    dimCheckBox.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local function ToggleDimKnown()
        state.dimKnownItems = dimCheckBox:GetChecked()
        local settings = GetSettings()
        settings.dimKnownItems = state.dimKnownItems
        if MerchantFrame and MerchantFrame:IsShown() then MerchantFrame_Update() end
    end

    dimCheckBox:SetScript("OnClick", ToggleDimKnown)
    dimKnownRow:SetScript("OnClick", function()
        dimCheckBox:SetChecked(not dimCheckBox:GetChecked())
        ToggleDimKnown()
    end)
    dimKnownRow:SetScript("OnEnter", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
        dimCheckBox.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(ns.L["VENDOR_DIM_KNOWN_TT"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:AddLine(ns.L["VENDOR_DIM_KNOWN_TT_DESC"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    dimKnownRow:SetScript("OnLeave", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        dimCheckBox.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        GameTooltip:Hide()
    end)

    state.junkPreviewPanel.dimKnownCheckBox = dimCheckBox

    local quickAddBtn = OneWoW_GUI:CreateFitTextButton(state.junkPreviewPanel, { text = ns.L["VENDOR_QUICK_ADD"], height = 26, minWidth = panelWidth - 16 })
    quickAddBtn:SetPoint("TOPLEFT", dimKnownRow, "BOTTOMLEFT", OneWoW_GUI:GetSpacing("SM"), -OneWoW_GUI:GetSpacing("XS"))
    quickAddBtn:SetPoint("TOPRIGHT", dimKnownRow, "BOTTOMRIGHT", -OneWoW_GUI:GetSpacing("SM"), -OneWoW_GUI:GetSpacing("XS"))
    quickAddBtn:SetScript("OnClick", function() VendorPanel:ToggleFiltersDialog() end)
    quickAddBtn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(ns.L["VENDOR_QUICK_ADD_FILTERS"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:AddLine(ns.L["UI_VENDOR_FILTER_HINT"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    quickAddBtn:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    state.junkPreviewPanel.quickAddSection = quickAddBtn

    local scrollFrame = CreateFrame("ScrollFrame", nil, state.junkPreviewPanel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", quickAddBtn, "BOTTOMLEFT", 0, -OneWoW_GUI:GetSpacing("XS"))
    scrollFrame:SetPoint("BOTTOMRIGHT", state.junkPreviewPanel, "BOTTOMRIGHT", -OneWoW_GUI:GetSpacing("SM"), 80)
    state.junkPreviewPanel.scrollFrame = scrollFrame

    OneWoW_GUI:StyleScrollBar(scrollFrame, { offset = -5 })

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(panelWidth - 28, 1)
    scrollFrame:SetScrollChild(scrollChild)
    state.junkPreviewPanel.scrollChild = scrollChild

    local bottomCloseBtn = OneWoW_GUI:CreateFitTextButton(state.junkPreviewPanel, { text = ns.L["VENDOR_CLOSE"], height = 28 })
    bottomCloseBtn:SetPoint("BOTTOMLEFT", state.junkPreviewPanel, "BOTTOMLEFT", OneWoW_GUI:GetSpacing("SM"), 12)
    bottomCloseBtn:SetScript("OnClick", function()
        state.junkPreviewPanel.manuallyHidden = true
        state.junkPreviewPanel:Hide()
        if state.filtersDialog then state.filtersDialog:Hide() end
        VendorPanel:ManageBlizzardSellButton(false)
        VendorPanel:UpdatePanelToggleButton()
    end)
    bottomCloseBtn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(ns.L["VENDOR_CLOSE_PANEL"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:AddLine(ns.L["VENDOR_HIDES_PANEL"], 1, 1, 1, true)
        GameTooltip:AddLine(ns.L["VENDOR_USE_TOGGLE"], OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        GameTooltip:Show()
    end)
    bottomCloseBtn:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local helpText = state.junkPreviewPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    helpText:SetPoint("BOTTOM", state.junkPreviewPanel, "BOTTOM", 0, 48)
    helpText:SetText(ns.L["VENDOR_RIGHT_CLICK_REMOVE"])
    helpText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local totalValueText = state.junkPreviewPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    totalValueText:SetPoint("BOTTOM", state.junkPreviewPanel, "BOTTOM", 0, 62)
    totalValueText:SetText("")
    totalValueText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
    state.junkPreviewPanel.totalValueText = totalValueText

    local destroyButton = OneWoW_GUI:CreateFitTextButton(state.junkPreviewPanel, { text = string.format(ns.L["VENDOR_DESTROY_COUNT"], 0), height = 28 })
    destroyButton:SetPoint("LEFT", bottomCloseBtn, "RIGHT", 3, 0)
    destroyButton.text:SetTextColor(1, 0.5, 0.5, 1)
    destroyButton.fontString = destroyButton.text
    destroyButton:SetScript("OnClick", function() VendorPanel:DestroyNextJunkItem() end)
    destroyButton:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(ns.L["VENDOR_DESTROY_NEXT"], 1, 0.3, 0.3)
        GameTooltip:AddLine(ns.L["VENDOR_DESTROY_NO_PRICE"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    destroyButton:HookScript("OnLeave", function(self)
        self.text:SetTextColor(1, 0.5, 0.5, 1)
        GameTooltip:Hide()
    end)
    state.junkPreviewPanel.destroyButton = destroyButton

    local sellJunkButton = OneWoW_GUI:CreateFitTextButton(state.junkPreviewPanel, { text = string.format(ns.L["VENDOR_SELL_COUNT"], 0), height = 28 })
    sellJunkButton:SetPoint("LEFT", destroyButton, "RIGHT", 3, 0)
    sellJunkButton.fontString = sellJunkButton.text
    sellJunkButton:SetScript("OnClick", function()
        VendorPanel:SellJunkItems()
        C_Timer.After(0.5, function() VendorPanel:UpdateButton(); VendorPanel:UpdatePreviewPanel() end)
    end)
    sellJunkButton:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(ns.L["VENDOR_SELL_JUNK_ITEMS"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:AddLine(ns.L["VENDOR_SELL_WITH_PRICE"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    sellJunkButton:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    state.junkPreviewPanel.sellJunkButton = sellJunkButton

    local resizeButton = CreateFrame("Button", nil, state.junkPreviewPanel)
    resizeButton:SetSize(16, 16)
    resizeButton:SetPoint("BOTTOMRIGHT", state.junkPreviewPanel, "BOTTOMRIGHT", -2, 2)
    resizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeButton:SetScript("OnMouseDown", function() state.junkPreviewPanel:StartSizing("BOTTOMRIGHT") end)
    resizeButton:SetScript("OnMouseUp", function()
        state.junkPreviewPanel:StopMovingOrSizing()
        C_Timer.After(0.1, function() VendorPanel:UpdatePreviewPanel() end)
    end)

    state.junkPreviewPanel:SetScript("OnSizeChanged", function(self, width, height)
        GetSettings().panelWidth = width
        if state.junkPreviewPanel.scrollChild then
            state.junkPreviewPanel.scrollChild:SetWidth(width - 28)
        end
        if self.sizeChangedTimer then self.sizeChangedTimer:Cancel() end
        self.sizeChangedTimer = C_Timer.NewTimer(0.2, function() VendorPanel:UpdatePreviewPanel() end)
    end)

    state.junkPreviewPanel.manuallyHidden = false
    state.junkPreviewPanel:Hide()
end

function VendorPanel:CreateFiltersDialog()
    if state.filtersDialog then return end

    local result = OneWoW_GUI:CreateDialog({
        name = "OneWoW_QoL_FiltersDialog",
        title = ns.L["VENDOR_QUICK_ADD_FILTERS"],
        width = 200,
        height = 346,
        strata = "MEDIUM",
        onClose = function(frame) frame:Hide() end,
    })
    state.filtersDialog = result.frame
    if state.junkPreviewPanel then
        state.filtersDialog:SetFrameLevel(state.junkPreviewPanel:GetFrameLevel() + 1)
    end
    state.filtersDialog:SetClipsChildren(true)

    local content = result.contentFrame
    local yOffset = 0

    local reagentsBtn = OneWoW_GUI:CreateFitTextButton(content, { text = ns.L["VENDOR_REAGENTS"], height = 26 })
    reagentsBtn:SetPoint("TOP", content, "TOP", 0, yOffset)
    reagentsBtn:SetScript("OnClick", function() VendorPanel:AddNonSoulboundReagents() end)
    reagentsBtn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(ns.L["UI_VENDOR_REAGENTS_TITLE"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:AddLine(ns.L["UI_VENDOR_REAGENTS"], 1, 1, 1, true)
        GameTooltip:AddLine(ns.L["UI_VENDOR_EXCLUDES"], OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        GameTooltip:Show()
    end)
    reagentsBtn:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    yOffset = yOffset - 28

    local consumablesBtn = OneWoW_GUI:CreateFitTextButton(content, { text = ns.L["UI_VENDOR_CONSUMABLES_TITLE"], height = 26 })
    consumablesBtn:SetPoint("TOP", content, "TOP", 0, yOffset)
    consumablesBtn:SetScript("OnClick", function() VendorPanel:AddConsumables() end)
    consumablesBtn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(ns.L["UI_VENDOR_CONSUMABLES_TITLE"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:AddLine(ns.L["UI_VENDOR_CONSUMABLES"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    consumablesBtn:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    yOffset = yOffset - 28

    local whiteBtn = OneWoW_GUI:CreateFitTextButton(content, { text = ns.L["UI_VENDOR_WHITES_TITLE"], height = 26 })
    whiteBtn:SetPoint("TOP", content, "TOP", 0, yOffset)
    whiteBtn:SetScript("OnClick", function() VendorPanel:AddWhiteQuality() end)
    whiteBtn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(ns.L["UI_VENDOR_WHITES_TITLE"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:AddLine(ns.L["UI_VENDOR_COMMONS"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    whiteBtn:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    yOffset = yOffset - 28

    local clearAllBtn = OneWoW_GUI:CreateFitTextButton(content, { text = ns.L["UI_VENDOR_CLEAR_TITLE"], height = 26 })
    clearAllBtn:SetPoint("TOP", content, "TOP", 0, yOffset)
    clearAllBtn:SetScript("OnClick", function()
        state.oneTimeItems.ilvlGear = {}; state.oneTimeItems.reagents = {}
        VendorPanel:UpdatePreviewPanel(); VendorPanel:UpdateButton()
        print("OneWoW QoL: Cleared all one-time items from sell list.")
    end)
    clearAllBtn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(ns.L["UI_VENDOR_CLEAR_TITLE"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:AddLine(ns.L["UI_VENDOR_REMOVE_CATEGORIES"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    clearAllBtn:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    yOffset = yOffset - 30

    OneWoW_GUI:CreateDivider(content, { yOffset = yOffset })
    yOffset = yOffset - 18

    local ilvlLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ilvlLabel:SetPoint("TOP", content, "TOP", 0, yOffset)
    ilvlLabel:SetText("Add Gear Below iLvl")
    ilvlLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - 22

    local ilvlEditBox = OneWoW_GUI:CreateEditBox(content, {
        width = 60,
        height = 22,
        maxLetters = 4,
    })
    ilvlEditBox:SetPoint("TOP", content, "TOP", -35, yOffset)
    ilvlEditBox:SetNumeric(true)
    ilvlEditBox:SetText("")
    ilvlEditBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    state.filtersDialog.ilvlEditBox = ilvlEditBox

    local ilvlBtn = OneWoW_GUI:CreateFitTextButton(content, { text = "Add", height = 26 })
    ilvlBtn:SetPoint("LEFT", ilvlEditBox, "RIGHT", 10, 0)
    ilvlBtn:SetScript("OnClick", function()
        local ilvl = tonumber(state.filtersDialog.ilvlEditBox:GetText())
        if ilvl and ilvl > 0 then
            VendorPanel:AddGearBelowIlvl(ilvl)
            state.filtersDialog.ilvlEditBox:SetText("")
        else
            print("OneWoW QoL: Please enter a valid item level.")
        end
    end)
    yOffset = yOffset - 26

    local excludeIlvl1 = OneWoW_GUI:CreateCheckbox(content, { label = "Skip iLvl 1 items" })
    excludeIlvl1:SetPoint("TOP", content, "TOP", -45, yOffset)
    excludeIlvl1:SetSize(20, 20)
    excludeIlvl1:SetChecked(true)
    state.filtersDialog.excludeIlvl1 = excludeIlvl1
    yOffset = yOffset - 26

    local showBlizzJunk = OneWoW_GUI:CreateCheckbox(content, { label = ns.L["VENDOR_SHOW_BLIZZ_JUNK"] })
    showBlizzJunk:SetPoint("TOP", content, "TOP", -45, yOffset)
    showBlizzJunk:SetSize(20, 20)
    showBlizzJunk:SetChecked(GetShowBlizzJunk())
    showBlizzJunk:SetScript("OnClick", function(self)
        local db = _G.OneWoW_QoL.db.global.modules["vendorpanel"]
        if not db.toggles then db.toggles = {} end
        db.toggles.show_blizz_junk = self:GetChecked()
        VendorPanel:UpdatePreviewPanel()
    end)
    state.filtersDialog.showBlizzJunk = showBlizzJunk

    showBlizzJunk:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(ns.L["VENDOR_SHOW_BLIZZ_JUNK"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:AddLine(ns.L["VENDOR_SHOW_BLIZZ_JUNK_TT"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    showBlizzJunk:SetScript("OnLeave", function() GameTooltip:Hide() end)
    yOffset = yOffset - 30

    OneWoW_GUI:CreateDivider(content, { yOffset = yOffset })
    yOffset = yOffset - 26

    local neverSellBtn = OneWoW_GUI:CreateFitTextButton(content, { text = "", height = 26, minWidth = 176 })
    neverSellBtn:SetPoint("TOP", content, "TOP", 0, yOffset)
    neverSellBtn.text:SetText(string.format(ns.L["VENDOR_PROTECTED_ITEMS"] .. " (%d)", 0))
    state.filtersDialog.neverSellBtnText = neverSellBtn.text
    neverSellBtn:SetScript("OnClick", function() VendorPanel:ToggleNeverSellDialog() end)
    neverSellBtn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(ns.L["VENDOR_PROTECTED_ITEMS"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:AddLine(ns.L["VENDOR_VIEW_PROTECTED"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    neverSellBtn:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    state.filtersDialog:Hide()
end

function VendorPanel:CreateNeverSellDialog()
    if state.neverSellDialog then return end

    local result = OneWoW_GUI:CreateDialog({
        name = "OneWoW_QoL_NeverSellDialog",
        title = ns.L["VENDOR_PROTECTED_ITEMS"],
        width = 350,
        height = 400,
        strata = "MEDIUM",
        showBrand = true,
        factionTheme = GetFactionTheme(),
        onClose = function(frame) frame:Hide() end,
        buttons = {
            { text = ns.L["VENDOR_CLOSE"], onClick = function(frame) frame:Hide() end },
        },
    })
    state.neverSellDialog = result.frame
    state.neverSellDialog:SetScript("OnShow", function()
        if result.titleBar.brandIcon then result.titleBar.brandIcon:SetTexture(GetBrandIcon()) end
    end)

    local content = result.contentFrame

    local scrollFrame = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", content, "TOPLEFT", OneWoW_GUI:GetSpacing("SM"), -OneWoW_GUI:GetSpacing("XS"))
    scrollFrame:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -OneWoW_GUI:GetSpacing("SM"), 20)
    state.neverSellDialog.scrollFrame = scrollFrame

    OneWoW_GUI:StyleScrollBar(scrollFrame, { offset = -5 })

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(320, 1)
    scrollFrame:SetScrollChild(scrollChild)
    state.neverSellDialog.scrollChild = scrollChild

    local helpText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    helpText:SetPoint("BOTTOM", content, "BOTTOM", 0, 4)
    helpText:SetText(ns.L["VENDOR_CLICK_UNPROTECT"])
    helpText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    state.neverSellDialog:Hide()
end

function VendorPanel:UpdateNeverSellDialog()
    if not state.neverSellDialog or not state.neverSellDialog.scrollChild then return end
    local scrollChild = state.neverSellDialog.scrollChild

    for _, child in ipairs({scrollChild:GetChildren()}) do
        child:Hide(); child:SetParent(nil)
    end

    local neverSellList = self:GetNeverSellList()
    local yOffset, count = 0, 0

    for itemID, itemLink in pairs(neverSellList) do
        count = count + 1
        local itemName, _, _, _, _, _, _, _, _, itemTexture = C_Item.GetItemInfo(itemID)
        if not itemName then itemName = "Item " .. itemID; C_Item.RequestLoadItemDataByID(itemID) end
        if not itemTexture then itemTexture = "Interface\\Icons\\INV_Misc_QuestionMark" end

        local itemFrame = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
        itemFrame:SetSize(295, 32)
        itemFrame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, -yOffset)
        itemFrame:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER)
        itemFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        itemFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

        local iconFrame = CreateFrame("Frame", nil, itemFrame, "BackdropTemplate")
        iconFrame:SetSize(24, 24)
        iconFrame:SetPoint("LEFT", itemFrame, "LEFT", 4, 0)
        iconFrame:SetBackdrop(backdropIconEdge)
        iconFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

        local icon = iconFrame:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints(iconFrame)
        icon:SetTexture(itemTexture)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

        local text = itemFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("LEFT", iconFrame, "RIGHT", 6, 0)
        text:SetPoint("RIGHT", itemFrame, "RIGHT", -10, 0)
        text:SetText(type(itemLink) == "string" and itemLink or itemName)
        text:SetJustifyH("LEFT")

        itemFrame:SetScript("OnClick", function()
            VendorPanel:RemoveFromNeverSellList(itemID)
            VendorPanel:UpdateNeverSellDialog()
            VendorPanel:UpdatePreviewPanel()
        end)
        itemFrame:SetScript("OnEnter", function(self)
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if type(itemLink) == "string" then GameTooltip:SetHyperlink(itemLink) else GameTooltip:SetItemByID(itemID) end
            GameTooltip:AddLine(" ", 1, 1, 1)
            GameTooltip:AddLine(ns.L["VENDOR_CLICK_UNPROTECT"], 1, 0.5, 0.5)
            GameTooltip:Show()
        end)
        itemFrame:SetScript("OnLeave", function(self)
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            GameTooltip:Hide()
        end)
        yOffset = yOffset + 34
    end

    if count == 0 then
        local emptyText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        emptyText:SetPoint("CENTER", scrollChild, "CENTER", 0, -20)
        emptyText:SetText(ns.L["VENDOR_NO_PROTECTED"])
        emptyText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    end

    scrollChild:SetHeight(math.max(yOffset, 1))
end

function VendorPanel:GetJunkItemsDetailed()
    local grayItems, markedItems, ilvlGearItems, reagentItems, noValueJunkItems = {}, {}, {}, {}, {}
    local allCached = true

    for bag = 0, NUM_BAG_SLOTS + 1 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
                if itemInfo and itemInfo.itemID then
                    local itemName, itemLink, quality, _, _, _, _, _, _, itemTexture, sellPrice, classID, subclassID = C_Item.GetItemInfo(itemInfo.itemID)
                    if not itemName then
                        allCached = false
                        C_Item.RequestLoadItemDataByID(itemInfo.itemID)
                    else
                        local itemLevel, actualQuality, actualItemLink = 0, quality, itemLink
                        local itemLocation = ItemLocation:CreateFromBagAndSlot(bag, slot)
                        if itemLocation and C_Item.DoesItemExist(itemLocation) then
                            local item = Item:CreateFromItemLocation(itemLocation)
                            if item and item:IsItemDataCached() then
                                itemLevel = item:GetCurrentItemLevel() or 0
                                actualQuality = item:GetItemQuality() or quality
                                actualItemLink = item:GetItemLink() or itemLink
                            end
                        end

                        if not self:IsItemInNeverSellList(itemInfo.itemID) then
                            local isUserMarked = GetItemStatus():IsItemJunk(itemInfo.itemID)
                            local isGray = quality == 0
                            local isGameJunk = (classID == Enum.ItemClass.Miscellaneous and subclassID == Enum.ItemMiscellaneousSubclass.Junk)
                            local isIlvlGear = state.oneTimeItems.ilvlGear[itemInfo.itemID]
                            local isReagent = state.oneTimeItems.reagents[itemInfo.itemID]
                            local isJunkItem = isUserMarked or isGray or isGameJunk or isIlvlGear or isReagent

                            if GetItemStatus():IsItemProtected(itemInfo.itemID) then isJunkItem = false end

                            if isJunkItem then
                                local canSell = not itemInfo.hasNoValue
                                local hasSellPrice = canSell and sellPrice and sellPrice > 0
                                local entry = {
                                    link = actualItemLink, stackCount = itemInfo.stackCount or 1,
                                    itemID = itemInfo.itemID, icon = itemTexture,
                                    sellPrice = hasSellPrice and sellPrice or 0,
                                    totalValue = hasSellPrice and (sellPrice * (itemInfo.stackCount or 1)) or 0,
                                    isUserMarked = isUserMarked, itemLevel = itemLevel or 0,
                                    noSellPrice = not hasSellPrice
                                }
                                if isUserMarked then table.insert(markedItems, entry)
                                elseif isIlvlGear then table.insert(ilvlGearItems, entry)
                                elseif isReagent then table.insert(reagentItems, entry)
                                elseif not hasSellPrice and (isGray or isGameJunk) then table.insert(noValueJunkItems, entry)
                                elseif isGray then table.insert(grayItems, entry)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if not allCached then return nil, nil, nil, nil, nil, false end
    return grayItems, markedItems, ilvlGearItems, reagentItems, noValueJunkItems, true
end

function VendorPanel:UpdatePreviewPanel()
    if not state.junkPreviewPanel then return end
    if state.junkPreviewPanel.manuallyHidden then return end
    if not GetShowPanel() then return end

    if state.junkPreviewPanel.vendorDropdown and state.junkPreviewPanel.vendorDropdown.RefreshFilters then
        state.junkPreviewPanel.vendorDropdown:RefreshFilters()
    end

    local grayItems, markedItems, ilvlGearItems, reagentItems, noValueJunkItems, allCached = self:GetJunkItemsDetailed()
    if not allCached then
        C_Timer.After(0.3, function() self:UpdatePreviewPanel() end)
        return
    end

    if not GetShowBlizzJunk() then noValueJunkItems = {} end

    state.junkPreviewPanel:Show()
    self:ManageBlizzardSellButton(true)

    local scrollChild = state.junkPreviewPanel.scrollChild
    for _, child in ipairs({scrollChild:GetChildren()}) do child:Hide(); child:SetParent(nil) end

    local totalValue = 0
    for _, item in ipairs(grayItems) do totalValue = totalValue + item.totalValue end
    for _, item in ipairs(markedItems) do totalValue = totalValue + item.totalValue end
    for _, item in ipairs(ilvlGearItems) do totalValue = totalValue + item.totalValue end
    for _, item in ipairs(reagentItems) do totalValue = totalValue + item.totalValue end
    for _, item in ipairs(noValueJunkItems) do totalValue = totalValue + item.totalValue end

    local yOffset = 0
    if #grayItems > 0 then yOffset = self:CreateCategory(scrollChild, grayItems, yOffset, ns.L["VENDOR_GRAY_ITEMS"], {r=0.7, g=0.7, b=0.7}, "gray", false, false) end
    if #markedItems > 0 then yOffset = self:CreateCategory(scrollChild, markedItems, yOffset, ns.L["VENDOR_MARKED_JUNK"], {r=1, g=0.82, b=0}, "marked", true, false) end
    if #ilvlGearItems > 0 then yOffset = self:CreateCategory(scrollChild, ilvlGearItems, yOffset, ns.L["VENDOR_LOW_ILVL"], {r=0.5, g=1, b=0.5}, "ilvlGear", false, true) end
    if #reagentItems > 0 then yOffset = self:CreateCategory(scrollChild, reagentItems, yOffset, ns.L["VENDOR_REAGENTS"], {r=0.5, g=1, b=0.5}, "reagents", false, true) end
    if #noValueJunkItems > 0 then yOffset = self:CreateCategory(scrollChild, noValueJunkItems, yOffset, ns.L["VENDOR_JUNK_NO_VALUE"], {r=1, g=0.4, b=0.4}, "noValueJunk", false, false, true) end

    scrollChild:SetHeight(math.max(yOffset, 1))
    state.junkPreviewPanel.totalValueText:SetText(string.format(ns.L["VENDOR_TOTAL"], VPFilters.FormatMoney(totalValue)))

    local sellableCount, destroyableCount = 0, 0
    for _, list in ipairs({grayItems, markedItems, ilvlGearItems, reagentItems}) do
        for _, item in ipairs(list) do
            if not item.noSellPrice then sellableCount = sellableCount + 1 else destroyableCount = destroyableCount + 1 end
        end
    end
    for _, item in ipairs(noValueJunkItems) do destroyableCount = destroyableCount + 1 end

    if state.junkPreviewPanel.sellJunkButton and state.junkPreviewPanel.sellJunkButton.fontString then
        state.junkPreviewPanel.sellJunkButton.fontString:SetText(string.format(ns.L["VENDOR_SELL_COUNT"], sellableCount))
    end
    if state.junkPreviewPanel.destroyButton then
        if state.junkPreviewPanel.destroyButton.fontString then
            state.junkPreviewPanel.destroyButton.fontString:SetText(string.format(ns.L["VENDOR_DESTROY_COUNT"], destroyableCount))
        end
        state.junkPreviewPanel.destroyButton:SetAlpha(destroyableCount > 0 and 1.0 or 0.5)
    end
end

function VendorPanel:CreateCategory(parent, items, yOffset, title, color, category, isMarkedJunk, isOneTime, isNoValueJunk)
    local headerFrame = CreateFrame("Button", nil, parent, "BackdropTemplate")
    local parentWidth = parent:GetWidth()
    headerFrame:SetSize(parentWidth - 8, 28)
    headerFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -yOffset)
    headerFrame:RegisterForClicks("LeftButtonUp")
    headerFrame:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER)
    headerFrame:SetBackdropColor(color.r * 0.15, color.g * 0.15, color.b * 0.15, 0.95)
    headerFrame:SetBackdropBorderColor(color.r * 0.9, color.g * 0.9, color.b * 0.9, 1)

    local indicator = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    indicator:SetPoint("LEFT", headerFrame, "LEFT", 8, 0)
    indicator:SetText(state.collapsedCategories[category] and "[+]" or "[-]")
    indicator:SetTextColor(color.r * 1.1, color.g * 1.1, color.b * 1.1, 1)

    local categoryTotal = 0
    for _, item in ipairs(items) do categoryTotal = categoryTotal + item.totalValue end

    local headerText = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerText:SetPoint("LEFT", indicator, "RIGHT", 5, 0)
    headerText:SetText(title .. " (" .. #items .. ") - " .. VPFilters.FormatMoney(categoryTotal))
    headerText:SetTextColor(color.r * 1.1, color.g * 1.1, color.b * 1.1, 1)

    if isOneTime then
        local oneTimeLabel = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        oneTimeLabel:SetPoint("LEFT", headerText, "RIGHT", 5, 0)
        oneTimeLabel:SetText(ns.L["VENDOR_ONETIME_LABEL"])
        oneTimeLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))

        local clearBtn = OneWoW_GUI:CreateFitTextButton(headerFrame, { text = ns.L["VENDOR_CLEAR_ALL"], height = 20 })
        clearBtn:SetPoint("RIGHT", headerFrame, "RIGHT", -3, 0)
        clearBtn:SetScript("OnClick", function(self, button)
            if button == "LeftButton" then
                if category == "ilvlGear" then state.oneTimeItems.ilvlGear = {}
                elseif category == "reagents" then state.oneTimeItems.reagents = {} end
                VendorPanel:UpdatePreviewPanel(); VendorPanel:UpdateButton()
            end
        end)
    end

    if isNoValueJunk then
        local deleteAllBtn = CreateFrame("Button", nil, headerFrame, "BackdropTemplate")
        deleteAllBtn:SetSize(75, 20)
        deleteAllBtn:SetPoint("RIGHT", headerFrame, "RIGHT", -3, 0)
        deleteAllBtn:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER)
        deleteAllBtn:SetBackdropColor(0.2, 0.05, 0.05, 0.9)
        deleteAllBtn:SetBackdropBorderColor(0.7, 0.2, 0.2, 1)
        local deleteFS = deleteAllBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        deleteFS:SetPoint("CENTER", deleteAllBtn, "CENTER", 0, 0)
        deleteFS:SetText(ns.L["VENDOR_DESTROY_ALL"])
        deleteFS:SetTextColor(1, 0.5, 0.5, 1)
        deleteAllBtn:SetScript("OnClick", function(self, button) if button == "LeftButton" then VendorPanel:DeleteAllNoValueJunk() end end)
        deleteAllBtn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.3, 0.08, 0.08, 0.95)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(ns.L["VENDOR_DESTROY_ALL_TOOLTIP"], 1, 0.3, 0.3)
            GameTooltip:AddLine(ns.L["VENDOR_WARNING_NOT_JUNK"], 1, 0.5, 0.5, true)
            GameTooltip:AddLine(ns.L["VENDOR_CHECK_BEFORE_DESTROY"], 1, 1, 1, true)
            GameTooltip:AddLine(" ", 1, 1, 1)
            GameTooltip:AddLine(ns.L["VENDOR_CTRL_PROTECT"], OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            GameTooltip:Show()
        end)
        deleteAllBtn:SetScript("OnLeave", function(self) self:SetBackdropColor(0.2, 0.05, 0.05, 0.9); GameTooltip:Hide() end)
    end

    headerFrame:SetScript("OnClick", function()
        state.collapsedCategories[category] = not state.collapsedCategories[category]
        VendorPanel:UpdatePreviewPanel()
    end)

    yOffset = yOffset + 30

    if not state.collapsedCategories[category] then
        for _, item in ipairs(items) do
            local itemFrame = CreateFrame("Button", nil, parent, "BackdropTemplate")
            itemFrame:SetSize(parentWidth - 10, 32)
            itemFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -yOffset)
            itemFrame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            itemFrame:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER)
            itemFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            itemFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

            local highlight = itemFrame:CreateTexture(nil, "HIGHLIGHT")
            highlight:SetAllPoints(itemFrame)
            highlight:SetColorTexture(OneWoW_GUI:GetThemeColor("BG_HOVER"))
            highlight:SetBlendMode("ADD")

            local iconFrame = CreateFrame("Frame", nil, itemFrame, "BackdropTemplate")
            iconFrame:SetSize(24, 24)
            iconFrame:SetPoint("LEFT", itemFrame, "LEFT", 4, 0)
            iconFrame:SetBackdrop(backdropIconEdge)
            iconFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

            local icon = iconFrame:CreateTexture(nil, "ARTWORK")
            icon:SetAllPoints(iconFrame)
            icon:SetTexture(item.icon)
            icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

            local displayText = item.link
            if item.stackCount > 1 then displayText = displayText .. " x" .. item.stackCount end
            if item.itemLevel and item.itemLevel > 0 and (category == "ilvlGear" or category == "marked") then
                displayText = displayText .. " (ilvl " .. item.itemLevel .. ")"
            end

            local text = itemFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            text:SetPoint("LEFT", iconFrame, "RIGHT", 6, 0)
            text:SetText(displayText)
            text:SetJustifyH("LEFT")

            local totalPriceBox
            if item.noSellPrice then
                totalPriceBox = CreateFrame("Button", nil, itemFrame, "BackdropTemplate")
                totalPriceBox:SetSize(55, 20)
                totalPriceBox:SetPoint("RIGHT", itemFrame, "RIGHT", -4, 0)
                totalPriceBox:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER)
                totalPriceBox:SetBackdropColor(0.25, 0.05, 0.05, 0.95)
                totalPriceBox:SetBackdropBorderColor(0.7, 0.2, 0.2, 1)
                local deleteText = totalPriceBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                deleteText:SetPoint("CENTER", totalPriceBox, "CENTER", 0, 0)
                deleteText:SetText(ns.L["VENDOR_DESTROY_ALL"])
                deleteText:SetTextColor(1, 0.5, 0.5, 1)
                totalPriceBox:SetScript("OnClick", function(self, btn)
                    if btn == "LeftButton" then
                        for bag = 0, NUM_BAG_SLOTS + 1 do
                            local numSlots = C_Container.GetContainerNumSlots(bag)
                            if numSlots then
                                for slot = 1, numSlots do
                                    local info = C_Container.GetContainerItemInfo(bag, slot)
                                    if info and info.itemID == item.itemID then
                                        ClearCursor(); C_Container.PickupContainerItem(bag, slot); DeleteCursorItem()
                                        C_Timer.After(0.1, function() VendorPanel:UpdatePreviewPanel(); VendorPanel:UpdateButton() end)
                                        return
                                    end
                                end
                            end
                        end
                    end
                end)
                totalPriceBox:SetScript("OnEnter", function(self)
                    self:SetBackdropColor(0.35, 0.08, 0.08, 0.95)
                    GameTooltip:SetOwner(self, "ANCHOR_TOP")
                    GameTooltip:SetText(ns.L["VENDOR_DESTROY_THIS"], 1, 0.3, 0.3)
                    GameTooltip:AddLine(ns.L["VENDOR_CLICK_DESTROY"], 1, 1, 1, true)
                    GameTooltip:Show()
                end)
                totalPriceBox:SetScript("OnLeave", function(self) self:SetBackdropColor(0.25, 0.05, 0.05, 0.95); GameTooltip:Hide() end)
            else
                local totalPriceText = itemFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                totalPriceText:SetText(VPFilters.FormatMoney(item.totalValue))
                totalPriceText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
                local totalWidth = totalPriceText:GetStringWidth() + 12
                totalPriceBox = CreateFrame("Frame", nil, itemFrame, "BackdropTemplate")
                totalPriceBox:SetSize(totalWidth, 20)
                totalPriceBox:SetPoint("RIGHT", itemFrame, "RIGHT", -4, 0)
                totalPriceBox:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER)
                totalPriceBox:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
                totalPriceBox:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                totalPriceText:SetParent(totalPriceBox)
                totalPriceText:SetPoint("CENTER", totalPriceBox, "CENTER", 0, 0)
            end

            text:SetWidth(itemFrame:GetWidth() - iconFrame:GetWidth() - totalPriceBox:GetWidth() - 20)

            if item.stackCount > 1 and not item.noSellPrice then
                local eaPriceText = itemFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                eaPriceText:SetText(VPFilters.FormatMoney(item.sellPrice) .. " ea")
                eaPriceText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
                local eaWidth = eaPriceText:GetStringWidth() + 10
                local eaPriceBox = CreateFrame("Frame", nil, itemFrame, "BackdropTemplate")
                eaPriceBox:SetSize(eaWidth, 18)
                eaPriceBox:SetPoint("RIGHT", totalPriceBox, "LEFT", -2, 0)
                eaPriceBox:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER)
                eaPriceBox:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                eaPriceBox:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
                eaPriceText:SetParent(eaPriceBox)
                eaPriceText:SetPoint("CENTER", eaPriceBox, "CENTER", 0, 0)
                text:SetWidth(itemFrame:GetWidth() - iconFrame:GetWidth() - totalPriceBox:GetWidth() - eaPriceBox:GetWidth() - 28)
            end

            itemFrame:SetScript("OnClick", function(self, button)
                if button == "LeftButton" and IsShiftKeyDown() then
                    if not item.noSellPrice then
                        for bag = 0, NUM_BAG_SLOTS + 1 do
                            local numSlots = C_Container.GetContainerNumSlots(bag)
                            if numSlots then
                                for slot = 1, numSlots do
                                    local info = C_Container.GetContainerItemInfo(bag, slot)
                                    if info and info.itemID == item.itemID then
                                        C_Container.UseContainerItem(bag, slot)
                                        C_Timer.After(0.2, function() VendorPanel:UpdatePreviewPanel(); VendorPanel:UpdateButton() end)
                                        return
                                    end
                                end
                            end
                        end
                    end
                elseif button == "RightButton" then
                    if IsControlKeyDown() then
                        VendorPanel:AddToNeverSellList(item.itemID, item.link)
                        VendorPanel:UpdatePreviewPanel(); VendorPanel:UpdateButton()
                    elseif isOneTime then
                        if category == "ilvlGear" then state.oneTimeItems.ilvlGear[item.itemID] = nil
                        elseif category == "reagents" then state.oneTimeItems.reagents[item.itemID] = nil end
                        VendorPanel:UpdatePreviewPanel(); VendorPanel:UpdateButton()
                    elseif isMarkedJunk then
                        GetItemStatus():RemoveItemStatus(item.itemID)
                        VendorPanel:UpdatePreviewPanel(); VendorPanel:UpdateButton()
                    end
                end
            end)

            itemFrame:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(item.link)
                GameTooltip:AddLine(" ", 1, 1, 1)
                if not item.noSellPrice then GameTooltip:AddLine(ns.L["VENDOR_SHIFT_SELL"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT")) end
                if isNoValueJunk then GameTooltip:AddLine(ns.L["VENDOR_MARK_PROTECTED"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
                elseif isOneTime then
                    GameTooltip:AddLine(ns.L["VENDOR_REMOVE_ONETIME"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
                    GameTooltip:AddLine(ns.L["VENDOR_MARK_PROTECTED"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
                elseif isMarkedJunk then
                    GameTooltip:AddLine(ns.L["VENDOR_REMOVE_JUNK"], 0, 1, 0)
                    GameTooltip:AddLine(ns.L["VENDOR_MARK_PROTECTED"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
                else GameTooltip:AddLine(ns.L["VENDOR_MARK_PROTECTED"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT")) end
                GameTooltip:Show()
            end)
            itemFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

            yOffset = yOffset + 26
        end
        yOffset = yOffset + 5
    end

    return yOffset
end
