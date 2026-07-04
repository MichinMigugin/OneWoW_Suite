local _, ns = ...
local _, L = ns.ModuleRegistry:Current()

local OneWoW_GUI = OneWoW_GUI

local VendorPanel = ns.VendorPanel
local state = ns.VPState
local VPFilters = ns.VPFilters
local function GetItemStatus()
    return OneWoW and OneWoW.ItemStatus
end
local GetShowBlizzJunk = ns.VPGetShowBlizzJunk
local GetShowPanel = ns.VPGetShowPanel
local GetSettings = ns.VPGetSettings
local GetExclusions = ns.VPGetExclusions

local backdropIconEdge = {
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
}

local function GetBrandIcon()
    local factionTheme = (OneWoW_GUI and OneWoW_GUI.GetSetting and OneWoW_GUI:GetSetting("minimap.theme")) or "horde"
    return OneWoW_GUI:GetBrandIcon(factionTheme)
end

local function GetFactionTheme()
    return (OneWoW_GUI.GetSetting and OneWoW_GUI:GetSetting("minimap.theme")) or "horde"
end

function VendorPanel:CreateVendorButton()
    if state.vendorButton then return end

    state.vendorButton = OneWoW_GUI:CreateButton(MerchantFrame, {
        name = "OneWoW_QoL_VendorButton",
        text = VendorPanel:FormatSellCountsText(0, 0),
        width = 100,
        height = 22,
    })
    state.vendorButton:SetPoint("TOPLEFT", MerchantFrame, "TOPLEFT", 60, -28)
    state.vendorButton:SetFrameLevel(MerchantFrame:GetFrameLevel() + 10)

    -- We own the merchant top-left spot. If VendorFilter is loaded, shove its
    -- dropdown up out of the way (above the merchant window) so it no longer
    -- sits under our button.
    if ns.VPIsVendorFilterLoaded() and _G["VendorFilterDropdown"] then
        _G["VendorFilterDropdown"]:ClearAllPoints()
        _G["VendorFilterDropdown"]:SetPoint("BOTTOMLEFT", MerchantFrame, "TOPLEFT", 10, 2)
    end
    state.vendorButton.fontString = state.vendorButton.text
    state.vendorButton.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))

    state.vendorButton:SetScript("OnClick", function(_, button)
        if button == "LeftButton" then
            VendorPanel:SellJunkItems()
            C_Timer.After(0.5, function() VendorPanel:UpdateButton() end)
        elseif button == "RightButton" then
            VendorPanel:TogglePreviewPanel()
        end
    end)

    state.vendorButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    state.vendorButton:SetScript("OnEnter", function(myself)
        myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
        myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
        myself.text:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_HIGHLIGHT"))
        local sellCount, destroyCount = VendorPanel:GetJunkCounts()
        GameTooltip:SetOwner(myself, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L["VENDOR_JUNK_MANAGER"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:AddLine(L["VENDOR_SELL_JUNK"], 1, 1, 1, true)
        GameTooltip:AddLine(L["VENDOR_TOGGLE_PANEL"], 1, 1, 1, true)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine(VendorPanel:FormatCountsLabelText(destroyCount, sellCount), 1, 1, 1)
        GameTooltip:Show()
    end)
    state.vendorButton:SetScript("OnLeave", function(myself)
        myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
        myself.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:Hide()
    end)

    state.vendorButton:Hide()
end

function VendorPanel:EnsureMerchantSidebar()
    return OneWoW_GUI:EnsureSideBar(MerchantFrame, "MerchantFrameTabSideBar")
end

function VendorPanel:RepositionMerchantSidebar()
    OneWoW_GUI:RepositionSideBar(MerchantFrameTabSideBar, {
        hostFrame = MerchantFrame,
        dockedPanel = (state.junkPreviewPanel and state.junkPreviewPanel:IsShown()) and state.junkPreviewPanel or nil,
        anchoredTab = state.panelToggleTab,
    })
end

function VendorPanel:ClosePreviewPanel()
    if state.junkPreviewPanel then
        state.junkPreviewPanel.manuallyHidden = true
        state.junkPreviewPanel:Hide()
    end
    if state.filtersDialog then state.filtersDialog:Hide() end
    if state.optionsDialog then state.optionsDialog:Hide() end
    self:ManageBlizzardSellButton(false)
    if state.panelToggleTab then
        state.panelToggleTab:SetChecked(false)
        state.panelToggleTab:Show()
    end
    if MerchantFrameTabSideBar then
        MerchantFrameTabSideBar.selTab = 0
        MerchantFrameTabSideBar:Show()
    end
    self:RepositionMerchantSidebar()
    self:UpdatePanelToggleButton()
end

function VendorPanel:CreatePanelToggleButton()
    if state.panelToggleTab then return end
    if not MerchantFrame then return end

    local sidebar = self:EnsureMerchantSidebar()
    if not sidebar then return end

    local tab, tabIndex = OneWoW_GUI:CreateSideBarTab(sidebar, {
        icon = GetBrandIcon(),
        tooltip = "|cff00ccffOneWoW Vendor",
        onToggle = function(show)
            if show then
                if not state.junkPreviewPanel then VendorPanel:CreatePreviewPanel() end
                state.junkPreviewPanel.manuallyHidden = false
                state.junkPreviewPanel:Show()
                VendorPanel:UpdatePreviewPanel()
                VendorPanel:ManageBlizzardSellButton(true)
                VendorPanel:RepositionMerchantSidebar()
                VendorPanel:UpdatePanelToggleButton()
            else
                VendorPanel:ClosePreviewPanel()
            end
        end,
    })

    state.panelToggleTab = tab
    state._merchantSidebarIndex = tabIndex
    state._merchantToggleHandler = tab.owToggle
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

    state.replacementSellButton:SetScript("OnClick", function(_, button)
        if button == "LeftButton" then
            VendorPanel:SellJunkItems()
            C_Timer.After(0.5, function() VendorPanel:UpdateButton() end)
        end
    end)

    state.replacementSellButton:HookScript("OnEnter", function(myself)
        local sellCount, destroyCount = VendorPanel:GetJunkCounts()
        GameTooltip:SetOwner(myself, "ANCHOR_TOP")
        GameTooltip:AddTexture(GetBrandIcon())
        GameTooltip:AddLine(L["VENDOR_JUNK_MANAGER"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:AddLine(L["VENDOR_SELL_JUNK"], 1, 1, 1, true)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine(VendorPanel:FormatCountsLabelText(destroyCount, sellCount), 1, 1, 1)
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
    state.junkPreviewPanel:SetPoint("TOPLEFT", MerchantFrame, "TOPRIGHT", 0, 0)
    state.junkPreviewPanel:SetPoint("BOTTOMLEFT", MerchantFrame, "BOTTOMRIGHT", 0, 0)
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
        title = L["VENDOR_TOOLS_TITLE"],
        showBrand = true,
        factionTheme = GetFactionTheme(),
        onClose = function()
            VendorPanel:ClosePreviewPanel()
        end,
    })
    state.junkPreviewPanel:SetScript("OnShow", function()
        if titleBar.brandIcon then titleBar.brandIcon:SetTexture(GetBrandIcon()) end
    end)
    -- When the panel closes, let Blizzard repopulate any merchant slots our grid
    -- filtering cleared so the vendor returns to its normal, unfiltered layout.
    state.junkPreviewPanel:SetScript("OnHide", function()
        if MerchantFrame and MerchantFrame:IsShown() then MerchantFrame_Update() end
    end)

    state.junkPreviewPanel.titleBar = titleBar

    -- Top action row: Quick Add + Options, each opening a docked dialog.
    local quickAddBtn = OneWoW_GUI:CreateFitTextButton(state.junkPreviewPanel, { text = L["VENDOR_QUICK_ADD"], height = 26, minWidth = 80 })
    quickAddBtn:SetScript("OnClick", function() VendorPanel:ToggleFiltersDialog() end)
    quickAddBtn:HookScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_TOP")
        GameTooltip:SetText(L["VENDOR_QUICK_ADD_FILTERS"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:AddLine(L["UI_VENDOR_FILTER_HINT"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    quickAddBtn:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    state.junkPreviewPanel.quickAddSection = quickAddBtn

    local optionsBtn = OneWoW_GUI:CreateFitTextButton(state.junkPreviewPanel, { text = OPTIONS, height = 26, minWidth = 80 })
    optionsBtn:SetScript("OnClick", function() VendorPanel:ToggleOptionsDialog() end)
    optionsBtn:HookScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_TOP")
        GameTooltip:SetText(OPTIONS, OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:AddLine(L["VENDOR_OPTIONS_HINT"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    optionsBtn:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    state.junkPreviewPanel.optionsButton = optionsBtn

    local scrollFrame = CreateFrame("ScrollFrame", nil, state.junkPreviewPanel, "UIPanelScrollFrameTemplate")
    state.junkPreviewPanel.scrollFrame = scrollFrame

    OneWoW_GUI:StyleScrollBar(scrollFrame, { offset = -5 })

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(panelWidth - 28, 1)
    scrollFrame:SetScrollChild(scrollChild)
    state.junkPreviewPanel.scrollChild = scrollChild

    -- Bottom action buttons share a container that RelayoutPreviewPanel centers.
    local bottomRow = CreateFrame("Frame", nil, state.junkPreviewPanel)
    bottomRow:SetHeight(28)
    state.junkPreviewPanel.bottomRow = bottomRow

    local bottomCloseBtn = OneWoW_GUI:CreateFitTextButton(bottomRow, { text = CLOSE, height = 28 })
    bottomCloseBtn:SetScript("OnClick", function()
        VendorPanel:ClosePreviewPanel()
    end)
    bottomCloseBtn:HookScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_TOP")
        GameTooltip:SetText(L["VENDOR_CLOSE_PANEL"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:AddLine(L["VENDOR_HIDES_PANEL"], 1, 1, 1, true)
        GameTooltip:AddLine(L["VENDOR_USE_TOGGLE"], OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        GameTooltip:Show()
    end)
    bottomCloseBtn:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    state.junkPreviewPanel.closeButton = bottomCloseBtn

    local destroyButton = OneWoW_GUI:CreateFitTextButton(bottomRow, { text = VendorPanel:FormatDestroyButtonText(0), height = 28 })
    destroyButton.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
    destroyButton.fontString = destroyButton.text
    destroyButton:SetScript("OnClick", function() VendorPanel:DestroyNextJunkItem() end)
    destroyButton:HookScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_TOP")
        GameTooltip:SetText(L["VENDOR_DESTROY_NEXT"], 1, 0.3, 0.3)
        GameTooltip:AddLine(L["VENDOR_DESTROY_NO_PRICE"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    destroyButton:HookScript("OnLeave", function(myself)
        myself.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
        GameTooltip:Hide()
    end)
    state.junkPreviewPanel.destroyButton = destroyButton

    local sellJunkButton = OneWoW_GUI:CreateFitTextButton(bottomRow, { text = VendorPanel:FormatSellButtonText(0), height = 28 })
    sellJunkButton.text:SetTextColor(VendorPanel:GetSellCountColor())
    sellJunkButton.fontString = sellJunkButton.text
    sellJunkButton:SetScript("OnClick", function()
        VendorPanel:SellJunkItems()
        C_Timer.After(0.5, function() VendorPanel:UpdateButton(); VendorPanel:UpdatePreviewPanel() end)
    end)
    sellJunkButton:HookScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_TOP")
        GameTooltip:SetText(L["VENDOR_SELL_JUNK_ITEMS"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:AddLine(L["VENDOR_SELL_WITH_PRICE"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    sellJunkButton:HookScript("OnLeave", function(myself)
        myself.text:SetTextColor(VendorPanel:GetSellCountColor())
        GameTooltip:Hide()
    end)
    state.junkPreviewPanel.sellJunkButton = sellJunkButton

    local helpText = state.junkPreviewPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    helpText:SetText(L["VENDOR_RIGHT_CLICK_REMOVE"])
    helpText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    state.junkPreviewPanel.helpText = helpText

    local totalValueText = state.junkPreviewPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    totalValueText:SetText("")
    totalValueText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
    state.junkPreviewPanel.totalValueText = totalValueText

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

    state.junkPreviewPanel:SetScript("OnSizeChanged", function(myself, width, _)
        GetSettings().panelWidth = width
        if state.junkPreviewPanel.scrollChild then
            state.junkPreviewPanel.scrollChild:SetWidth(width - 28)
        end
        VendorPanel:RelayoutPreviewPanel()
        if myself.sizeChangedTimer then myself.sizeChangedTimer:Cancel() end
        myself.sizeChangedTimer = C_Timer.NewTimer(0.2, function() VendorPanel:UpdatePreviewPanel() end)
    end)

    -- The panel is docked to MerchantFrame (outside the core window rebuild), so
    -- register it as a font root; RelayoutPreviewPanel re-flows on font/size change.
    OneWoW_GUI:RegisterFontRoot(state.junkPreviewPanel, function() VendorPanel:RelayoutPreviewPanel() end)

    VendorPanel:RelayoutPreviewPanel()
    C_Timer.After(0, function() VendorPanel:RelayoutPreviewPanel() end)

    state.junkPreviewPanel.manuallyHidden = false
    state.junkPreviewPanel:Hide()
end

--- Re-flow the docked panel top-to-bottom so the action buttons stay centered and
--- the scroll area / footer text never overlap at any font size.
function VendorPanel:RelayoutPreviewPanel()
    local panel = state.junkPreviewPanel
    if not panel or not panel.titleBar then return end
    local pad = OneWoW_GUI:GetSpacing("SM")
    local gap = OneWoW_GUI:GetSpacing("XS")

    local qa, opt = panel.quickAddSection, panel.optionsButton
    qa:ClearAllPoints()
    opt:ClearAllPoints()
    qa:SetPoint("TOPLEFT", panel.titleBar, "BOTTOMLEFT", pad, -gap)
    opt:SetPoint("TOPRIGHT", panel.titleBar, "BOTTOMRIGHT", -pad, -gap)

    local closeB, destroyB, sellB = panel.closeButton, panel.destroyButton, panel.sellJunkButton
    local btnGap = 3
    local rowH = math.max(closeB:GetHeight(), destroyB:GetHeight(), sellB:GetHeight())
    local rowW = closeB:GetWidth() + destroyB:GetWidth() + sellB:GetWidth() + btnGap * 2
    local row = panel.bottomRow
    row:SetSize(rowW, rowH)
    row:ClearAllPoints()
    row:SetPoint("BOTTOM", panel, "BOTTOM", 0, 12)
    closeB:ClearAllPoints(); destroyB:ClearAllPoints(); sellB:ClearAllPoints()
    closeB:SetPoint("LEFT", row, "LEFT", 0, 0)
    destroyB:SetPoint("LEFT", closeB, "RIGHT", btnGap, 0)
    sellB:SetPoint("LEFT", destroyB, "RIGHT", btnGap, 0)

    local help = panel.helpText
    local helpH = math.ceil(help:GetStringHeight() or 0)
    if helpH < 12 then helpH = 12 end
    local helpY = 12 + rowH + 6
    help:ClearAllPoints()
    help:SetPoint("BOTTOM", panel, "BOTTOM", 0, helpY)

    local total = panel.totalValueText
    local totalH = math.ceil(total:GetStringHeight() or 0)
    if totalH < 14 then totalH = 14 end
    local totalY = helpY + helpH + 4
    total:ClearAllPoints()
    total:SetPoint("BOTTOM", panel, "BOTTOM", 0, totalY)

    local scroll = panel.scrollFrame
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", qa, "BOTTOMLEFT", 0, -gap)
    scroll:SetPoint("TOPRIGHT", opt, "BOTTOMRIGHT", 0, -gap)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -pad, totalY + totalH + 8)
end

function VendorPanel:CreateOptionsDialog()
    if state.optionsDialog then return end

    local result = OneWoW_GUI:CreateDialog({
        name = "OneWoW_QoL_VendorOptionsDialog",
        title = OPTIONS,
        width = 240,
        height = 360,
        strata = "MEDIUM",
        onClose = function(frame) frame:Hide() end,
        relayout = function() VendorPanel:RelayoutOptionsDialog() end,
    })
    state.optionsDialog = result.frame
    if state.junkPreviewPanel then
        state.optionsDialog:SetFrameLevel(state.junkPreviewPanel:GetFrameLevel() + 1)
    end
    state.optionsDialog:SetClipsChildren(true)

    local content = result.contentFrame
    local d = state.optionsDialog

    -- Filter dropdown (moved out of the panel).
    local filterLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    filterLabel:SetText(L["FILTER"])
    filterLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    d.filterLabel = filterLabel

    local vendorDropdown, dropText = OneWoW_GUI:CreateDropdown(content, {
        height = 22,
        text = state.currentVendorFilter == "Cosmetic Items" and "Cosmetics" or state.currentVendorFilter,
    })
    d.vendorDropdown = vendorDropdown

    local function buildVendorFilterItems()
        local items = {}

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

        local exclusions = GetExclusions()
        local exclusionDefs = {
            { key = "Mounts",    text = MOUNTS },
            { key = "Pets",      text = PETS },
            { key = "Toys",      text = L["VENDOR_EX_TOYS"] },
            { key = "Cosmetics", text = L["VENDOR_EX_COSMETICS"] },
            { key = "Decor",     text = L["DECOR"] },
            { key = "Housing",   text = L["VENDOR_EX_HOUSING"] },
        }
        table.insert(items, { type = "divider" })
        table.insert(items, { type = "header", text = L["VENDOR_ALWAYS_HIDE"] })
        for _, def in ipairs(exclusionDefs) do
            table.insert(items, {
                type = "checkbox",
                text = def.text,
                checked = exclusions[def.key] and true or false,
                onToggle = function(checked)
                    exclusions[def.key] = checked or nil
                    VendorPanel:RerenderMerchantGrid()
                end,
            })
        end

        return items
    end

    OneWoW_GUI:AttachFilterMenu(vendorDropdown, {
        searchable = false,
        menuHeight = 300,
        maxVisible = 50,
        getActiveValue = function() return state.currentVendorFilter end,
        buildItems = buildVendorFilterItems,
        onSelect = function(value, _)
            state.currentVendorFilter = value
            dropText:SetText(value == "Cosmetic Items" and "Cosmetics" or value)
            if MerchantFrame and MerchantFrame:IsShown() then
                MerchantFrame.page = 1
                MerchantFrame_Update()
            end
        end,
    })
    vendorDropdown.RefreshFilters = function()
        dropText:SetText(state.currentVendorFilter == "Cosmetic Items" and "Cosmetics" or state.currentVendorFilter)
    end
    state.vendorDropdown = vendorDropdown

    d.divider1 = OneWoW_GUI:CreateDivider(content, {})

    -- Known-item handling: Dim vs Hide are mutually exclusive.
    local dimCheck = OneWoW_GUI:CreateCheckbox(content, { label = L["VENDOR_DIM_KNOWN"], checked = state.dimKnownItems })
    local hideCheck = OneWoW_GUI:CreateCheckbox(content, { label = L["VENDOR_HIDE_KNOWN"], checked = GetSettings().hideKnownEntirely })
    dimCheck:SetScript("OnClick", function(myself)
        local checked = myself:GetChecked()
        state.dimKnownItems = checked
        GetSettings().dimKnownItems = checked
        if checked then
            hideCheck:SetChecked(false)
            GetSettings().hideKnownEntirely = false
        end
        VendorPanel:RerenderMerchantGrid()
    end)
    hideCheck:SetScript("OnClick", function(myself)
        local checked = myself:GetChecked()
        GetSettings().hideKnownEntirely = checked
        if checked then
            dimCheck:SetChecked(false)
            state.dimKnownItems = false
            GetSettings().dimKnownItems = false
        end
        VendorPanel:RerenderMerchantGrid()
    end)
    d.dimCheck = dimCheck
    d.hideCheck = hideCheck

    d.divider2 = OneWoW_GUI:CreateDivider(content, {})

    -- Persistent Blizzard merchant filter default: ALL vs current Spec.
    local filterModeLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    filterModeLabel:SetText(L["VENDOR_SET_FILTER_TO"])
    filterModeLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    d.filterModeLabel = filterModeLabel

    local allCheck = OneWoW_GUI:CreateCheckbox(content, { label = ALL })
    local specCheck = OneWoW_GUI:CreateCheckbox(content, { label = SPECIALIZATION })
    local function refreshFilterRadios()
        local pref = GetSettings().defaultMerchantFilter or "spec"
        allCheck:SetChecked(pref == "all")
        specCheck:SetChecked(pref ~= "all")
    end
    allCheck:SetScript("OnClick", function()
        GetSettings().defaultMerchantFilter = "all"
        refreshFilterRadios()
        VendorPanel:SyncMerchantSpecFilter()
    end)
    specCheck:SetScript("OnClick", function()
        GetSettings().defaultMerchantFilter = "spec"
        refreshFilterRadios()
        VendorPanel:SyncMerchantSpecFilter()
    end)
    d.allCheck = allCheck
    d.specCheck = specCheck
    d.refreshFilterRadios = refreshFilterRadios

    -- Panel-side armor dim (no longer touches the native merchant filter).
    local allTypesCheck = OneWoW_GUI:CreateCheckbox(content, { label = L["VENDOR_ALL_SPECS_TYPES"], checked = state.showAllArmor })
    allTypesCheck:SetScript("OnClick", function(myself)
        state.showAllArmor = myself:GetChecked()
        GetSettings().showAllArmor = state.showAllArmor
        VendorPanel:RerenderMerchantGrid()
    end)
    d.allTypesCheck = allTypesCheck

    d.divider3 = OneWoW_GUI:CreateDivider(content, {})

    -- Mirror of the QoL Features toggles for this module.
    local showPanelCheck = OneWoW_GUI:CreateCheckbox(content, { label = L["VENDORPANEL_SHOW_PANEL"], checked = GetShowPanel() })
    showPanelCheck:SetScript("OnClick", function(myself)
        ns.ModuleRegistry:SetToggleValue("vendorpanel", "show_panel", myself:GetChecked())
    end)
    d.showPanelCheck = showPanelCheck

    local showBlizzCheck = OneWoW_GUI:CreateCheckbox(content, { label = L["VENDOR_SHOW_BLIZZ_JUNK"], checked = GetShowBlizzJunk() })
    showBlizzCheck:SetScript("OnClick", function(myself)
        ns.ModuleRegistry:SetToggleValue("vendorpanel", "show_blizz_junk", myself:GetChecked())
        VendorPanel:UpdatePreviewPanel()
    end)
    d.showBlizzCheck = showBlizzCheck

    -- Re-sync every control from saved state when the dialog is (re)opened.
    d.Refresh = function()
        dimCheck:SetChecked(state.dimKnownItems)
        hideCheck:SetChecked(GetSettings().hideKnownEntirely or false)
        allTypesCheck:SetChecked(state.showAllArmor)
        showPanelCheck:SetChecked(GetShowPanel())
        showBlizzCheck:SetChecked(GetShowBlizzJunk())
        refreshFilterRadios()
        if vendorDropdown.RefreshFilters then vendorDropdown:RefreshFilters() end
        VendorPanel:RelayoutOptionsDialog()
    end

    VendorPanel:RelayoutOptionsDialog()
    C_Timer.After(0, function() VendorPanel:RelayoutOptionsDialog() end)

    state.optionsDialog:Hide()
end

--- Re-flow the Options dialog rows top-to-bottom with measured heights and size
--- the dialog to fit, so nothing overlaps at any font size.
function VendorPanel:RelayoutOptionsDialog()
    local d = state.optionsDialog
    if not d or not d.filterLabel then return end
    local md = OneWoW_GUI:GetSpacing("MD")
    local gap = OneWoW_GUI:GetSpacing("XS")
    local content = d.filterLabel:GetParent()

    local function measureFS(fs, minH)
        local h = math.ceil(fs:GetStringHeight() or 0)
        if h < minH then h = minH end
        return h
    end

    local y = -OneWoW_GUI:GetSpacing("SM")

    d.filterLabel:ClearAllPoints()
    d.filterLabel:SetPoint("TOPLEFT", content, "TOPLEFT", md, y)
    y = y - measureFS(d.filterLabel, 12) - 4

    d.vendorDropdown:ClearAllPoints()
    d.vendorDropdown:SetPoint("TOPLEFT", content, "TOPLEFT", md, y)
    d.vendorDropdown:SetPoint("TOPRIGHT", content, "TOPRIGHT", -md, y)
    y = y - d.vendorDropdown:GetHeight() - gap

    local function placeDivider(div)
        div:ClearAllPoints()
        div:SetPoint("TOPLEFT", content, "TOPLEFT", md, y)
        div:SetPoint("TOPRIGHT", content, "TOPRIGHT", -md, y)
        y = y - 8
    end
    local function placeCheck(cb)
        cb:ClearAllPoints()
        cb:SetPoint("TOPLEFT", content, "TOPLEFT", md, y)
        y = y - math.max(cb:GetMeasuredHeight(), cb:GetHeight()) - 2
    end

    placeDivider(d.divider1)
    placeCheck(d.dimCheck)
    placeCheck(d.hideCheck)
    y = y - gap

    placeDivider(d.divider2)
    d.filterModeLabel:ClearAllPoints()
    d.filterModeLabel:SetPoint("TOPLEFT", content, "TOPLEFT", md, y)
    y = y - measureFS(d.filterModeLabel, 12) - 2
    placeCheck(d.allCheck)
    placeCheck(d.specCheck)
    placeCheck(d.allTypesCheck)
    y = y - gap

    placeDivider(d.divider3)
    placeCheck(d.showPanelCheck)
    placeCheck(d.showBlizzCheck)

    local titleH = OneWoW_GUI.Constants.GUI.TITLEBAR_HEIGHT or 30
    d:SetHeight(titleH + (-y) + OneWoW_GUI:GetSpacing("SM"))
end

function VendorPanel:CreateFiltersDialog()
    if state.filtersDialog then return end

    local result = OneWoW_GUI:CreateDialog({
        name = "OneWoW_QoL_FiltersDialog",
        title = L["VENDOR_QUICK_ADD_FILTERS"],
        width = 230,
        height = 360,
        strata = "MEDIUM",
        onClose = function(frame) frame:Hide() end,
        relayout = function() VendorPanel:RelayoutFiltersDialog() end,
    })
    state.filtersDialog = result.frame
    local d = state.filtersDialog
    if state.junkPreviewPanel then
        d:SetFrameLevel(state.junkPreviewPanel:GetFrameLevel() + 1)
    end
    d:SetClipsChildren(true)

    local content = result.contentFrame

    local reagentsBtn = OneWoW_GUI:CreateFitTextButton(content, { text = L["VENDOR_REAGENTS"], height = 26 })
    reagentsBtn:SetScript("OnClick", function() VendorPanel:AddNonSoulboundReagents() end)
    reagentsBtn:HookScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["UI_VENDOR_REAGENTS_TITLE"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:AddLine(L["UI_VENDOR_REAGENTS"], 1, 1, 1, true)
        GameTooltip:AddLine(L["UI_VENDOR_EXCLUDES"], OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        GameTooltip:Show()
    end)
    reagentsBtn:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    d.reagentsBtn = reagentsBtn

    local consumablesBtn = OneWoW_GUI:CreateFitTextButton(content, { text = L["UI_VENDOR_CONSUMABLES_TITLE"], height = 26 })
    consumablesBtn:SetScript("OnClick", function() VendorPanel:AddConsumables() end)
    consumablesBtn:HookScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["UI_VENDOR_CONSUMABLES_TITLE"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:AddLine(L["UI_VENDOR_CONSUMABLES"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    consumablesBtn:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    d.consumablesBtn = consumablesBtn

    local whiteBtn = OneWoW_GUI:CreateFitTextButton(content, { text = L["UI_VENDOR_WHITES_TITLE"], height = 26 })
    whiteBtn:SetScript("OnClick", function() VendorPanel:AddWhiteQuality() end)
    whiteBtn:HookScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["UI_VENDOR_WHITES_TITLE"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:AddLine(L["UI_VENDOR_COMMONS"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    whiteBtn:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    d.whiteBtn = whiteBtn

    local soulboundBtn = OneWoW_GUI:CreateFitTextButton(content, { text = L["VENDOR_SOULBOUND_EQUIP"], height = 26 })
    soulboundBtn:SetScript("OnClick", function() VendorPanel:AddSoulboundEquipment() end)
    soulboundBtn:HookScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["VENDOR_SOULBOUND_EQUIP"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:AddLine(L["VENDOR_SOULBOUND_EQUIP_TT"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    soulboundBtn:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    d.soulboundBtn = soulboundBtn

    local clearAllBtn = OneWoW_GUI:CreateFitTextButton(content, { text = L["UI_VENDOR_CLEAR_TITLE"], height = 26 })
    clearAllBtn:SetScript("OnClick", function()
        state.oneTimeItems.ilvlGear = {}; state.oneTimeItems.reagents = {}; state.oneTimeItems.custom = {}
        VendorPanel:UpdatePreviewPanel(); VendorPanel:UpdateButton()
        print("OneWoW QoL: Cleared all one-time items from sell list.")
    end)
    clearAllBtn:HookScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["UI_VENDOR_CLEAR_TITLE"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:AddLine(L["UI_VENDOR_REMOVE_CATEGORIES"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    clearAllBtn:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    d.clearAllBtn = clearAllBtn

    d.divider1 = OneWoW_GUI:CreateDivider(content, {})

    -- Bag-search-syntax filter: reuses the shared PredicateEngine + keyword help.
    local searchLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    searchLabel:SetText(L["VENDOR_SEARCH_FILTER"])
    searchLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    d.searchLabel = searchLabel

    local searchBox = OneWoW_GUI:CreateEditBox(content, {
        height = 24,
        placeholderText = L["VENDOR_SEARCH_PLACEHOLDER"],
    })
    d.searchBox = searchBox

    local searchAddBtn = OneWoW_GUI:CreateFitTextButton(content, { text = ADD, height = 24 })
    searchAddBtn:SetScript("OnClick", function()
        VendorPanel:AddSearchMatches(searchBox:GetSearchText())
    end)
    d.searchAddBtn = searchAddBtn

    searchBox:SetScript("OnEnterPressed", function(myself)
        VendorPanel:AddSearchMatches(myself:GetSearchText())
        myself:ClearFocus()
    end)

    local searchHelpBtn = OneWoW_GUI:CreateKeywordHelpButton(content, {
        editBox = searchBox,
        tooltipTitle = L["VENDOR_SEARCH_FILTER"],
        tooltipDesc = L["VENDOR_SEARCH_HINT"],
    })
    d.searchHelpBtn = searchHelpBtn

    d.divider2 = OneWoW_GUI:CreateDivider(content, {})

    local ilvlLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ilvlLabel:SetText(L["VENDOR_ADD_GEAR_BELOW_ILVL"])
    ilvlLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    d.ilvlLabel = ilvlLabel

    local ilvlEditBox = OneWoW_GUI:CreateEditBox(content, {
        width = 60,
        height = 22,
        maxLetters = 4,
    })
    ilvlEditBox:SetNumeric(true)
    ilvlEditBox:SetText("")
    ilvlEditBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    d.ilvlEditBox = ilvlEditBox

    local ilvlBtn = OneWoW_GUI:CreateFitTextButton(content, { text = ADD, height = 26 })
    ilvlBtn:SetScript("OnClick", function()
        local ilvl = tonumber(state.filtersDialog.ilvlEditBox:GetText())
        if ilvl and ilvl > 0 then
            VendorPanel:AddGearBelowIlvl(ilvl)
            state.filtersDialog.ilvlEditBox:SetText("")
        else
            print("OneWoW QoL: Please enter a valid item level.")
        end
    end)
    d.ilvlBtn = ilvlBtn

    local excludeIlvl1 = OneWoW_GUI:CreateCheckbox(content, { label = L["VENDOR_SKIP_ILVL1"] })
    excludeIlvl1:SetChecked(true)
    d.excludeIlvl1 = excludeIlvl1

    d.divider3 = OneWoW_GUI:CreateDivider(content, {})

    local neverSellBtn = OneWoW_GUI:CreateFitTextButton(content, { text = "", height = 26, minWidth = 176 })
    neverSellBtn.text:SetText(string.format(L["VENDOR_PROTECTED_ITEMS"] .. " (%d)", 0))
    d.neverSellBtnText = neverSellBtn.text
    neverSellBtn:SetScript("OnClick", function() VendorPanel:ToggleNeverSellDialog() end)
    neverSellBtn:HookScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["VENDOR_PROTECTED_ITEMS"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:AddLine(L["VENDOR_VIEW_PROTECTED"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    neverSellBtn:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    d.neverSellBtn = neverSellBtn

    VendorPanel:RelayoutFiltersDialog()
    C_Timer.After(0, function() VendorPanel:RelayoutFiltersDialog() end)

    d:Hide()
end

--- Re-flow the Quick Add dialog rows top-to-bottom with measured heights and size
--- the dialog to fit, so nothing overlaps at any font size.
function VendorPanel:RelayoutFiltersDialog()
    local d = state.filtersDialog
    if not d or not d.reagentsBtn then return end
    local content = d.reagentsBtn:GetParent()
    local pad = OneWoW_GUI:GetSpacing("SM")
    local md = OneWoW_GUI:GetSpacing("MD")
    local y = -pad

    local function centerBtn(btn, spacing)
        btn:ClearAllPoints()
        btn:SetPoint("TOP", content, "TOP", 0, y)
        y = y - btn:GetHeight() - (spacing or 2)
    end
    local function placeDivider(div)
        div:ClearAllPoints()
        div:SetPoint("TOPLEFT", content, "TOPLEFT", md, y)
        div:SetPoint("TOPRIGHT", content, "TOPRIGHT", -md, y)
        y = y - 10
    end

    centerBtn(d.reagentsBtn)
    centerBtn(d.consumablesBtn)
    centerBtn(d.whiteBtn)
    centerBtn(d.soulboundBtn)
    centerBtn(d.clearAllBtn, 6)

    placeDivider(d.divider1)

    d.searchLabel:ClearAllPoints()
    d.searchLabel:SetPoint("TOPLEFT", content, "TOPLEFT", pad, y)
    d.searchHelpBtn:ClearAllPoints()
    d.searchHelpBtn:SetPoint("TOPRIGHT", content, "TOPRIGHT", -pad, y)
    local labelH = math.max(math.ceil(d.searchLabel:GetStringHeight() or 0), d.searchHelpBtn:GetHeight())
    if labelH < 14 then labelH = 14 end
    y = y - labelH - 4

    d.searchAddBtn:ClearAllPoints()
    d.searchAddBtn:SetPoint("TOPRIGHT", content, "TOPRIGHT", -pad, y)
    d.searchBox:ClearAllPoints()
    d.searchBox:SetPoint("TOPLEFT", content, "TOPLEFT", pad, y)
    d.searchBox:SetPoint("RIGHT", d.searchAddBtn, "LEFT", -4, 0)
    y = y - math.max(d.searchBox:GetHeight(), d.searchAddBtn:GetHeight()) - 8

    placeDivider(d.divider2)

    d.ilvlLabel:ClearAllPoints()
    d.ilvlLabel:SetPoint("TOP", content, "TOP", 0, y)
    y = y - math.max(math.ceil(d.ilvlLabel:GetStringHeight() or 0), 14) - 4

    d.ilvlEditBox:ClearAllPoints()
    d.ilvlEditBox:SetPoint("TOPLEFT", content, "TOPLEFT", pad + 20, y)
    d.ilvlBtn:ClearAllPoints()
    d.ilvlBtn:SetPoint("LEFT", d.ilvlEditBox, "RIGHT", 10, 0)
    y = y - math.max(d.ilvlEditBox:GetHeight(), d.ilvlBtn:GetHeight()) - 4

    d.excludeIlvl1:ClearAllPoints()
    d.excludeIlvl1:SetPoint("TOPLEFT", content, "TOPLEFT", pad, y)
    y = y - math.max(d.excludeIlvl1:GetMeasuredHeight(), d.excludeIlvl1:GetHeight()) - 8

    placeDivider(d.divider3)

    d.neverSellBtn:ClearAllPoints()
    d.neverSellBtn:SetPoint("TOP", content, "TOP", 0, y)
    y = y - d.neverSellBtn:GetHeight() - pad

    local titleH = OneWoW_GUI.Constants.GUI.TITLEBAR_HEIGHT or 30
    d:SetHeight(titleH + (-y) + pad)
end

function VendorPanel:CreateNeverSellDialog()
    if state.neverSellDialog then return end

    local result = OneWoW_GUI:CreateDialog({
        name = "OneWoW_QoL_NeverSellDialog",
        title = L["VENDOR_PROTECTED_ITEMS"],
        width = 350,
        height = 400,
        strata = "MEDIUM",
        showBrand = true,
        factionTheme = GetFactionTheme(),
        onClose = function(frame) frame:Hide() end,
        buttons = {
            { text = CLOSE, onClick = function(frame) frame:Hide() end },
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
    helpText:SetText(L["VENDOR_CLICK_UNPROTECT"])
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
        itemFrame:SetScript("OnEnter", function(myself)
            myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
            GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
            if type(itemLink) == "string" then GameTooltip:SetHyperlink(itemLink) else GameTooltip:SetItemByID(itemID) end
            GameTooltip:AddLine(" ", 1, 1, 1)
            GameTooltip:AddLine(L["VENDOR_CLICK_UNPROTECT"], 1, 0.5, 0.5)
            GameTooltip:Show()
        end)
        itemFrame:SetScript("OnLeave", function(myself)
            myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            GameTooltip:Hide()
        end)
        yOffset = yOffset + 34
    end

    if count == 0 then
        local emptyText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        emptyText:SetPoint("CENTER", scrollChild, "CENTER", 0, -20)
        emptyText:SetText(L["VENDOR_NO_PROTECTED"])
        emptyText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    end

    scrollChild:SetHeight(math.max(yOffset, 1))
end

function VendorPanel:GetJunkItemsDetailed()
    local grayItems, markedItems, ilvlGearItems, reagentItems, noValueJunkItems, customItems = {}, {}, {}, {}, {}, {}
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
                        local itemLevel, actualItemLink = 0, itemLink
                        local itemLocation = ItemLocation:CreateFromBagAndSlot(bag, slot)
                        if itemLocation and C_Item.DoesItemExist(itemLocation) then
                            local item = Item:CreateFromItemLocation(itemLocation)
                            if item and item:IsItemDataCached() then
                                itemLevel = item:GetCurrentItemLevel() or 0
                                actualItemLink = item:GetItemLink() or itemLink
                            end
                        end

                        if not self:IsItemInNeverSellList(itemInfo.itemID) then
                            local isUserMarked = GetItemStatus():IsItemJunk(itemInfo.itemID)
                            local isGray = quality == 0
                            local isGameJunk = (classID == Enum.ItemClass.Miscellaneous and subclassID == Enum.ItemMiscellaneousSubclass.Junk)
                            local isIlvlGear = state.oneTimeItems.ilvlGear[itemInfo.itemID]
                            local isReagent = state.oneTimeItems.reagents[itemInfo.itemID]
                            local isCustom = state.oneTimeItems.custom[itemInfo.itemID]
                            local isJunkItem = isUserMarked or isGray or isGameJunk or isIlvlGear or isReagent or isCustom

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
                                elseif isCustom then table.insert(customItems, entry)
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

    if not allCached then return nil, nil, nil, nil, nil, nil, false end
    return grayItems, markedItems, ilvlGearItems, reagentItems, noValueJunkItems, customItems, true
end

function VendorPanel:UpdatePreviewPanel()
    if not state.junkPreviewPanel then return end
    if state.junkPreviewPanel.manuallyHidden then return end
    if not GetShowPanel() then return end

    if state.vendorDropdown and state.vendorDropdown.RefreshFilters then
        state.vendorDropdown:RefreshFilters()
    end

    local grayItems, markedItems, ilvlGearItems, reagentItems, noValueJunkItems, customItems, allCached = self:GetJunkItemsDetailed()
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
    for _, item in ipairs(customItems) do totalValue = totalValue + item.totalValue end
    for _, item in ipairs(noValueJunkItems) do totalValue = totalValue + item.totalValue end

    local yOffset = 0
    if #grayItems > 0 then yOffset = self:CreateCategory(scrollChild, grayItems, yOffset, L["VENDOR_GRAY_ITEMS"], {r=0.7, g=0.7, b=0.7}, "gray", false, false) end
    if #markedItems > 0 then yOffset = self:CreateCategory(scrollChild, markedItems, yOffset, L["VENDOR_MARKED_JUNK"], {r=1, g=0.82, b=0}, "marked", true, false) end
    if #customItems > 0 then yOffset = self:CreateCategory(scrollChild, customItems, yOffset, L["VENDOR_QUICK_ADD_MATCHES"], {r=0.4, g=0.8, b=1}, "custom", false, true) end
    if #ilvlGearItems > 0 then yOffset = self:CreateCategory(scrollChild, ilvlGearItems, yOffset, L["VENDOR_LOW_ILVL"], {r=0.5, g=1, b=0.5}, "ilvlGear", false, true) end
    if #reagentItems > 0 then yOffset = self:CreateCategory(scrollChild, reagentItems, yOffset, L["VENDOR_REAGENTS"], {r=0.5, g=1, b=0.5}, "reagents", false, true) end
    if #noValueJunkItems > 0 then yOffset = self:CreateCategory(scrollChild, noValueJunkItems, yOffset, L["VENDOR_JUNK_NO_VALUE"], {r=1, g=0.4, b=0.4}, "noValueJunk", false, false, true) end

    scrollChild:SetHeight(math.max(yOffset, 1))
    state.junkPreviewPanel.totalValueText:SetText(string.format(L["VENDOR_TOTAL"], VPFilters.FormatMoney(totalValue)))

    local sellableCount, destroyableCount = 0, 0
    for _, list in ipairs({grayItems, markedItems, ilvlGearItems, reagentItems, customItems}) do
        for _, item in ipairs(list) do
            if not item.noSellPrice then sellableCount = sellableCount + 1 else destroyableCount = destroyableCount + 1 end
        end
    end
    for _ = 1, #noValueJunkItems do destroyableCount = destroyableCount + 1 end

    if state.junkPreviewPanel.sellJunkButton and state.junkPreviewPanel.sellJunkButton.fontString then
        state.junkPreviewPanel.sellJunkButton.fontString:SetText(VendorPanel:FormatSellButtonText(sellableCount))
        state.junkPreviewPanel.sellJunkButton.fontString:SetTextColor(VendorPanel:GetSellCountColor())
    end
    if state.junkPreviewPanel.destroyButton then
        if state.junkPreviewPanel.destroyButton.fontString then
            state.junkPreviewPanel.destroyButton.fontString:SetText(VendorPanel:FormatDestroyButtonText(destroyableCount))
            state.junkPreviewPanel.destroyButton.fontString:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
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
        oneTimeLabel:SetText(L["VENDOR_ONETIME_LABEL"])
        oneTimeLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))

        local clearBtn = OneWoW_GUI:CreateFitTextButton(headerFrame, { text = L["VENDOR_CLEAR_ALL"], height = 20 })
        clearBtn:SetPoint("RIGHT", headerFrame, "RIGHT", -3, 0)
        clearBtn:SetScript("OnClick", function(_, button)
            if button == "LeftButton" then
                if category == "ilvlGear" then state.oneTimeItems.ilvlGear = {}
                elseif category == "reagents" then state.oneTimeItems.reagents = {}
                elseif category == "custom" then state.oneTimeItems.custom = {} end
                VendorPanel:UpdatePreviewPanel(); VendorPanel:UpdateButton()
            end
        end)
    end

    if isNoValueJunk then
        local deleteAllBtn = CreateFrame("Button", nil, headerFrame, "BackdropTemplate")
        deleteAllBtn:SetSize(75, 20)
        deleteAllBtn:SetPoint("RIGHT", headerFrame, "RIGHT", -3, 0)
        deleteAllBtn:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER)
        deleteAllBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_NORMAL"))
        deleteAllBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_BORDER"))
        local deleteFS = deleteAllBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        deleteFS:SetPoint("CENTER", deleteAllBtn, "CENTER", 0, 0)
        deleteFS:SetText(DELETE)
        deleteFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
        deleteAllBtn:SetScript("OnClick", function(_, button) if button == "LeftButton" then VendorPanel:DeleteAllNoValueJunk() end end)
        deleteAllBtn:SetScript("OnEnter", function(myself)
            myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_HOVER"))
            GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["VENDOR_DESTROY_ALL_TOOLTIP"], 1, 0.3, 0.3)
            GameTooltip:AddLine(L["VENDOR_WARNING_NOT_JUNK"], 1, 0.5, 0.5, true)
            GameTooltip:AddLine(L["VENDOR_CHECK_BEFORE_DESTROY"], 1, 1, 1, true)
            GameTooltip:AddLine(" ", 1, 1, 1)
            GameTooltip:AddLine(L["VENDOR_CTRL_PROTECT"], OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            GameTooltip:Show()
        end)
        deleteAllBtn:SetScript("OnLeave", function(myself) myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_NORMAL")); GameTooltip:Hide() end)
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
                totalPriceBox:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_NORMAL"))
                totalPriceBox:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_BORDER"))
                local deleteText = totalPriceBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                deleteText:SetPoint("CENTER", totalPriceBox, "CENTER", 0, 0)
                deleteText:SetText(DELETE)
                deleteText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
                totalPriceBox:SetScript("OnClick", function(_, btn)
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
                totalPriceBox:SetScript("OnEnter", function(myself)
                    myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_HOVER"))
                    GameTooltip:SetOwner(myself, "ANCHOR_TOP")
                    GameTooltip:SetText(L["VENDOR_DESTROY_THIS"], 1, 0.3, 0.3)
                    GameTooltip:AddLine(L["VENDOR_CLICK_DESTROY"], 1, 1, 1, true)
                    GameTooltip:Show()
                end)
                totalPriceBox:SetScript("OnLeave", function(myself) myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_NORMAL")); GameTooltip:Hide() end)
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

            itemFrame:SetScript("OnClick", function(_, button)
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
                        elseif category == "reagents" then state.oneTimeItems.reagents[item.itemID] = nil
                        elseif category == "custom" then state.oneTimeItems.custom[item.itemID] = nil end
                        VendorPanel:UpdatePreviewPanel(); VendorPanel:UpdateButton()
                    elseif isMarkedJunk then
                        GetItemStatus():RemoveItemStatus(item.itemID)
                        VendorPanel:UpdatePreviewPanel(); VendorPanel:UpdateButton()
                    end
                end
            end)

            itemFrame:SetScript("OnEnter", function(myself)
                GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(item.link)
                GameTooltip:AddLine(" ", 1, 1, 1)
                if not item.noSellPrice then GameTooltip:AddLine(L["VENDOR_SHIFT_SELL"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT")) end
                if isNoValueJunk then GameTooltip:AddLine(L["VENDOR_MARK_PROTECTED"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
                elseif isOneTime then
                    GameTooltip:AddLine(L["VENDOR_REMOVE_ONETIME"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
                    GameTooltip:AddLine(L["VENDOR_MARK_PROTECTED"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
                elseif isMarkedJunk then
                    GameTooltip:AddLine(L["VENDOR_REMOVE_JUNK"], 0, 1, 0)
                    GameTooltip:AddLine(L["VENDOR_MARK_PROTECTED"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
                else GameTooltip:AddLine(L["VENDOR_MARK_PROTECTED"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT")) end
                GameTooltip:Show()
            end)
            itemFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

            yOffset = yOffset + 26
        end
        yOffset = yOffset + 5
    end

    return yOffset
end
