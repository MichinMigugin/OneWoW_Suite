local _, ns = ...
local _, L = ns.ModuleRegistry:Current()

local OneWoW_GUI = OneWoW_GUI

local VendorPanel = ns.VendorPanel
local state = ns.VPState
local VPFilters = ns.VPFilters
local function GetItemStatus()
    return OneWoW.ItemStatus
end
local GetShowBlizzJunk = ns.VPGetShowBlizzJunk
local GetShowPanel = ns.VPGetShowPanel
local GetSettings = ns.VPGetSettings
local GetExclusions = ns.VPGetExclusions

local backdropIconEdge = {
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
}

local SEARCH_PREVIEW_HEIGHT = 132
local SEARCH_PREVIEW_DEBOUNCE = 0.2

local function StyleVendorTab(btn, selected)
    if selected then
        btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
        btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
        btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
    else
        btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
        btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    end
end

function VendorPanel:SetVendorTab(tabId)
    if not state.junkPreviewPanel or not state.junkPreviewPanel.tabSell then return end
    state.activePanelTab = tabId
    local panel = state.junkPreviewPanel

    if tabId == "add" and not state.addTab then self:CreateAddTabContent() end
    if tabId == "options" and not state.optionsTab then self:CreateOptionsTabContent() end

    local isSell = tabId == "sell"
    local isAdd = tabId == "add"
    local isOpt = tabId == "options"

    panel.sellTabContent:SetShown(isSell)
    panel.addTabContent:SetShown(isAdd)
    panel.optionsTabContent:SetShown(isOpt)

    panel.helpText:SetShown(isSell)
    panel.totalValueText:SetShown(isSell)
    panel.destroyButton:SetShown(isSell)
    panel.sellJunkButton:SetShown(isSell)

    StyleVendorTab(panel.tabSell, isSell)
    StyleVendorTab(panel.tabAdd, isAdd)
    StyleVendorTab(panel.tabOptions, isOpt)

    if isAdd then
        self:RefreshCustomFilterButtons()
        self:RefreshGearButton()
        self:UpdateSearchPreview()
    elseif isOpt and state.optionsTab and state.optionsTab.Refresh then
        self:UpdateNeverSellButtonCount()
        state.optionsTab.Refresh()
    end

    self:RelayoutPreviewPanel()
end

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
    if state.addTab and state.addTab._searchPreviewTimer then
        state.addTab._searchPreviewTimer:Cancel()
    end
    state.activePanelTab = "sell"
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
                VendorPanel:SetVendorTab("sell")
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
    -- When the user closes the side panel while the merchant stays open, let
    -- Blizzard repopulate slots our grid filtering may have remapped. Skip during
    -- OnMerchantClosed teardown (_closingMerchant) and when the module is off.
    state.junkPreviewPanel:SetScript("OnHide", function()
        if state._closingMerchant or not state.moduleActive then return end
        if MerchantFrame and MerchantFrame:IsShown() then MerchantFrame_Update() end
    end)

    state.junkPreviewPanel.titleBar = titleBar

    state.activePanelTab = "sell"

    local tabBar = CreateFrame("Frame", nil, state.junkPreviewPanel)
    state.junkPreviewPanel.tabBar = tabBar

    local function makeTab(text, tabId)
        local btn = OneWoW_GUI:CreateFitTextButton(tabBar, { text = text, height = 24, minWidth = 56 })
        btn:SetScript("OnClick", function() VendorPanel:SetVendorTab(tabId) end)
        return btn
    end

    state.junkPreviewPanel.tabSell = makeTab(L["VENDOR_TAB_SELL"], "sell")
    state.junkPreviewPanel.tabAdd = makeTab(L["VENDOR_TAB_ADD"], "add")
    state.junkPreviewPanel.tabOptions = makeTab(OPTIONS, "options")

    local contentHost = CreateFrame("Frame", nil, state.junkPreviewPanel)
    state.junkPreviewPanel.contentHost = contentHost

    local sellTabContent = CreateFrame("Frame", nil, contentHost)
    sellTabContent:SetAllPoints(contentHost)
    state.junkPreviewPanel.sellTabContent = sellTabContent

    local addTabContent = CreateFrame("Frame", nil, contentHost)
    addTabContent:SetAllPoints(contentHost)
    addTabContent:Hide()
    state.junkPreviewPanel.addTabContent = addTabContent

    local addScroll = CreateFrame("ScrollFrame", nil, addTabContent, "UIPanelScrollFrameTemplate")
    addScroll:SetPoint("TOPLEFT", addTabContent, "TOPLEFT", 0, 0)
    addScroll:SetPoint("BOTTOMRIGHT", addTabContent, "BOTTOMRIGHT", 0, 0)
    OneWoW_GUI:StyleScrollBar(addScroll, { offset = -5 })
    local addScrollChild = CreateFrame("Frame", nil, addScroll)
    addScrollChild:SetWidth(panelWidth - 28)
    addScroll:SetScrollChild(addScrollChild)
    state.junkPreviewPanel.addTabScroll = addScroll
    state.junkPreviewPanel.addTabScrollChild = addScrollChild

    local optionsTabContent = CreateFrame("Frame", nil, contentHost)
    optionsTabContent:SetAllPoints(contentHost)
    optionsTabContent:Hide()
    state.junkPreviewPanel.optionsTabContent = optionsTabContent

    local optionsScroll = CreateFrame("ScrollFrame", nil, optionsTabContent, "UIPanelScrollFrameTemplate")
    optionsScroll:SetPoint("TOPLEFT", optionsTabContent, "TOPLEFT", 0, 0)
    optionsScroll:SetPoint("BOTTOMRIGHT", optionsTabContent, "BOTTOMRIGHT", 0, 0)
    OneWoW_GUI:StyleScrollBar(optionsScroll, { offset = -5 })
    local optionsScrollChild = CreateFrame("Frame", nil, optionsScroll)
    optionsScrollChild:SetWidth(panelWidth - 28)
    optionsScroll:SetScrollChild(optionsScrollChild)
    state.junkPreviewPanel.optionsTabScroll = optionsScroll
    state.junkPreviewPanel.optionsTabScrollChild = optionsScrollChild

    local scrollFrame = CreateFrame("ScrollFrame", nil, sellTabContent, "UIPanelScrollFrameTemplate")
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
        if state.junkPreviewPanel.addTabScrollChild then
            state.junkPreviewPanel.addTabScrollChild:SetWidth(width - 28)
        end
        if state.junkPreviewPanel.optionsTabScrollChild then
            state.junkPreviewPanel.optionsTabScrollChild:SetWidth(width - 28)
        end
        VendorPanel:RelayoutPreviewPanel()
        if myself.sizeChangedTimer then myself.sizeChangedTimer:Cancel() end
        myself.sizeChangedTimer = C_Timer.NewTimer(0.2, function() VendorPanel:UpdatePreviewPanel() end)
    end)

    -- The panel is docked to MerchantFrame (outside the core window rebuild), so
    -- register it as a font root; RelayoutPreviewPanel re-flows on font/size change.
    OneWoW_GUI:RegisterFontRoot(state.junkPreviewPanel, function()
        VendorPanel:RelayoutPreviewPanel()
        if state.addTab then VendorPanel:RelayoutAddTab() end
        if state.optionsTab then VendorPanel:RelayoutOptionsTab() end
    end)

    VendorPanel:RelayoutPreviewPanel()
    C_Timer.After(0, function() VendorPanel:RelayoutPreviewPanel() end)

    VendorPanel:SetVendorTab("sell")

    state.junkPreviewPanel.manuallyHidden = false
    state.junkPreviewPanel:Hide()
end

--- Re-flow the docked panel top-to-bottom so the action buttons stay centered and
--- the scroll area / footer text never overlap at any font size.
function VendorPanel:RelayoutPreviewPanel()
    local panel = state.junkPreviewPanel
    if not panel or not panel.titleBar or not panel.tabBar then return end
    local pad = OneWoW_GUI:GetSpacing("SM")
    local gap = OneWoW_GUI:GetSpacing("XS")
    local tabGap = 2
    local tabH = 24

    local tabBar = panel.tabBar
    tabBar:ClearAllPoints()
    tabBar:SetPoint("TOPLEFT", panel.titleBar, "BOTTOMLEFT", pad, -gap)
    tabBar:SetPoint("TOPRIGHT", panel.titleBar, "BOTTOMRIGHT", -pad, -gap)
    tabBar:SetHeight(tabH)

    local tabs = { panel.tabSell, panel.tabAdd, panel.tabOptions }
    local barW = tabBar:GetWidth()
    if barW < 1 then barW = (panel:GetWidth() or 320) - pad * 2 end
    local tabW = (barW - tabGap * 2) / 3
    for i, tab in ipairs(tabs) do
        tab:ClearAllPoints()
        tab:SetSize(tabW, tabH)
        tab:SetPoint("TOPLEFT", tabBar, "TOPLEFT", (i - 1) * (tabW + tabGap), 0)
    end

    local closeB, destroyB, sellB = panel.closeButton, panel.destroyButton, panel.sellJunkButton
    local btnGap = 3
    local rowH = math.max(closeB:GetHeight(), destroyB:GetHeight(), sellB:GetHeight())
    local isSell = state.activePanelTab == "sell"
    local rowW = isSell and (closeB:GetWidth() + destroyB:GetWidth() + sellB:GetWidth() + btnGap * 2) or closeB:GetWidth()
    local row = panel.bottomRow
    row:SetSize(rowW, rowH)
    row:ClearAllPoints()
    row:SetPoint("BOTTOM", panel, "BOTTOM", 0, 12)
    closeB:ClearAllPoints(); destroyB:ClearAllPoints(); sellB:ClearAllPoints()
    if isSell then
        closeB:SetPoint("LEFT", row, "LEFT", 0, 0)
        destroyB:SetPoint("LEFT", closeB, "RIGHT", btnGap, 0)
        sellB:SetPoint("LEFT", destroyB, "RIGHT", btnGap, 0)
    else
        closeB:SetPoint("CENTER", row, "CENTER", 0, 0)
    end

    local contentBottom = 12 + rowH + 8
    if isSell then
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
        contentBottom = totalY + totalH + 8
    end

    local contentHost = panel.contentHost
    contentHost:ClearAllPoints()
    contentHost:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -gap)
    contentHost:SetPoint("TOPRIGHT", tabBar, "BOTTOMRIGHT", 0, -gap)
    contentHost:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -pad, contentBottom)

    local scroll = panel.scrollFrame
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", panel.sellTabContent, "TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", panel.sellTabContent, "BOTTOMRIGHT", 0, 0)
end

function VendorPanel:CreateOptionsTabContent()
    if state.optionsTab then return end
    local panel = state.junkPreviewPanel
    if not panel or not panel.optionsTabScrollChild then return end

    local content = panel.optionsTabScrollChild
    local d = { content = content }
    state.optionsTab = d

    -- Filter dropdown (moved out of the panel).
    local filterLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    filterLabel:SetText(L["FILTER"])
    filterLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    d.filterLabel = filterLabel

    local vendorDropdown, dropText = OneWoW_GUI:CreateDropdown(content, {
        height = 22,
        text = VendorPanel:GetVendorFilterDisplayLabel(
            state.currentVendorFilter == "Cosmetic Items" and "Cosmetic Items" or state.currentVendorFilter
        ),
    })
    d.vendorDropdown = vendorDropdown

    local function buildVendorFilterItems()
        local items = {}

        table.insert(items, { text = VendorPanel:GetVendorFilterDisplayLabel("Show All"), value = "Show All" })

        local collectibles = {"Mounts", "Pets", "Toys", "Cosmetic Items", "Decor", "Housing"}
        local numCollect = 0
        for _, label in ipairs(collectibles) do if state.availableFilters[label] then numCollect = numCollect + 1 end end
        if numCollect > 0 then
            table.insert(items, { type = "divider" })
            table.insert(items, { type = "header", text = L["VENDOR_FILTER_SECTION_COLLECTIBLES"] })
            for _, label in ipairs(collectibles) do
                if state.availableFilters[label] then
                    table.insert(items, { text = VendorPanel:GetVendorFilterDisplayLabel(label), value = label })
                end
            end
        end

        local materials = {"Consumables", "Reagents"}
        local numMat = 0
        for _, label in ipairs(materials) do if state.availableFilters[label] then numMat = numMat + 1 end end
        if numMat > 0 then
            table.insert(items, { type = "divider" })
            table.insert(items, { type = "header", text = L["VENDOR_FILTER_SECTION_MATERIALS"] })
            for _, label in ipairs(materials) do
                if state.availableFilters[label] then
                    table.insert(items, { text = VendorPanel:GetVendorFilterDisplayLabel(label), value = label })
                end
            end
        end

        local equipment = {"Equipable","Head","Neck","Shoulder","Back","Chest","Waist","Legs","Feet","Wrist","Hands","Rings","Trinkets","Weapons"}
        local numEquip = 0
        for _, label in ipairs(equipment) do if state.availableFilters[label] then numEquip = numEquip + 1 end end
        if numEquip > 0 then
            table.insert(items, { type = "divider" })
            table.insert(items, { type = "header", text = L["VENDOR_FILTER_SECTION_EQUIPMENT"] })
            for _, label in ipairs(equipment) do
                if state.availableFilters[label] then
                    table.insert(items, { text = VendorPanel:GetVendorFilterDisplayLabel(label), value = label })
                end
            end
        end

        local professions = {"Alchemy","Blacksmithing","Cooking","Enchanting","Engineering","Inscription","Jewelcrafting","Leatherworking","Tailoring"}
        local numProf = 0
        for _, label in ipairs(professions) do if state.availableFilters[label] then numProf = numProf + 1 end end
        if state.availableFilters["Patterns"] or numProf > 0 then
            table.insert(items, { type = "divider" })
            table.insert(items, { type = "header", text = L["VENDOR_FILTER_SECTION_PATTERNS"] })
            if state.availableFilters["Patterns"] then
                table.insert(items, { text = VendorPanel:GetVendorFilterDisplayLabel("Patterns"), value = "Patterns" })
            end
            for _, label in ipairs(professions) do
                if state.availableFilters[label] then
                    table.insert(items, { text = VendorPanel:GetVendorFilterDisplayLabel(label), value = label })
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
            dropText:SetText(VendorPanel:GetVendorFilterDisplayLabel(value))
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

    d.divider4 = OneWoW_GUI:CreateDivider(content, {})

    d.gearIlvlLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    d.gearIlvlLabel:SetText(L["VENDOR_GEAR_ILVL_LABEL"])
    d.gearIlvlLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    d.gearIlvlEditBox = OneWoW_GUI:CreateEditBox(content, {
        width = 60,
        height = 22,
        maxLetters = 4,
    })
    d.gearIlvlEditBox:SetNumeric(true)
    d.gearIlvlEditBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    d.gearIlvlHint = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    d.gearIlvlHint:SetText(L["VENDOR_GEAR_ILVL_HINT"])
    d.gearIlvlHint:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    d.gearIlvlHint:SetJustifyH("LEFT")

    d.gearIlvlEditBox:SetScript("OnTextChanged", function(myself)
        local n = tonumber(myself:GetText())
        GetSettings().gearButtonIlvl = n
        VendorPanel:RefreshGearButton()
    end)

    d.excludeIlvl1 = OneWoW_GUI:CreateCheckbox(content, { label = L["VENDOR_SKIP_ILVL1"] })
    d.excludeIlvl1:SetScript("OnClick", function(myself)
        GetSettings().gearSkipIlvl1 = myself:GetChecked()
    end)

    d.divider5 = OneWoW_GUI:CreateDivider(content, {})

    d.neverSellBtn = OneWoW_GUI:CreateFitTextButton(content, { text = "", height = 26, minWidth = 176 })
    d.neverSellBtnText = d.neverSellBtn.text
    d.neverSellBtnText:SetText(string.format(L["VENDOR_PROTECTED_ITEMS_COUNT"], 0))
    d.neverSellBtn:SetScript("OnClick", function() VendorPanel:ToggleNeverSellDialog() end)
    d.neverSellBtn:HookScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["VENDOR_PROTECTED_ITEMS"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:AddLine(L["VENDOR_VIEW_PROTECTED"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    d.neverSellBtn:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local gearIlvl = GetSettings().gearButtonIlvl
    d.gearIlvlEditBox:SetText(gearIlvl and gearIlvl > 0 and tostring(gearIlvl) or "")
    d.excludeIlvl1:SetChecked(GetSettings().gearSkipIlvl1 ~= false)

    -- Re-sync every control from saved state when the dialog is (re)opened.
    d.Refresh = function()
        dimCheck:SetChecked(state.dimKnownItems)
        hideCheck:SetChecked(GetSettings().hideKnownEntirely or false)
        allTypesCheck:SetChecked(state.showAllArmor)
        showPanelCheck:SetChecked(GetShowPanel())
        showBlizzCheck:SetChecked(GetShowBlizzJunk())
        refreshFilterRadios()
        if vendorDropdown.RefreshFilters then vendorDropdown:RefreshFilters() end
        gearIlvl = GetSettings().gearButtonIlvl
        d.gearIlvlEditBox:SetText(gearIlvl and gearIlvl > 0 and tostring(gearIlvl) or "")
        d.excludeIlvl1:SetChecked(GetSettings().gearSkipIlvl1 ~= false)
        VendorPanel:UpdateNeverSellButtonCount()
        VendorPanel:RefreshGearButton()
        VendorPanel:RelayoutOptionsTab()
    end

    VendorPanel:RelayoutOptionsTab()
    C_Timer.After(0, function() VendorPanel:RelayoutOptionsTab() end)
end

--- Re-flow the Options tab rows top-to-bottom with measured heights.
function VendorPanel:RelayoutOptionsTab()
    local d = state.optionsTab
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
    y = y - gap

    placeDivider(d.divider4)
    d.gearIlvlLabel:ClearAllPoints()
    d.gearIlvlLabel:SetPoint("TOPLEFT", content, "TOPLEFT", md, y)
    y = y - measureFS(d.gearIlvlLabel, 12) - 4

    d.gearIlvlEditBox:ClearAllPoints()
    d.gearIlvlEditBox:SetPoint("TOPLEFT", content, "TOPLEFT", md, y)
    y = y - d.gearIlvlEditBox:GetHeight() - 4

    d.gearIlvlHint:ClearAllPoints()
    d.gearIlvlHint:SetPoint("TOPLEFT", content, "TOPLEFT", md, y)
    d.gearIlvlHint:SetPoint("TOPRIGHT", content, "TOPRIGHT", -md, y)
    y = y - measureFS(d.gearIlvlHint, 12) - 4

    placeCheck(d.excludeIlvl1)
    y = y - gap

    placeDivider(d.divider5)

    d.neverSellBtn:ClearAllPoints()
    d.neverSellBtn:SetPoint("TOPLEFT", content, "TOPLEFT", md, y)
    d.neverSellBtn:SetPoint("TOPRIGHT", content, "TOPRIGHT", -md, y)
    y = y - d.neverSellBtn:GetHeight() - gap

    content:SetHeight(math.max(-y, 1))
end

function VendorPanel:CreateAddTabContent()
    if state.addTab then return end
    local panel = state.junkPreviewPanel
    if not panel or not panel.addTabScrollChild then return end

    local content = panel.addTabScrollChild
    local d = { content = content }
    state.addTab = d

    local rowH = 22
    local clearW = 22
    d.customSlotBtns = {}
    d.customClearBtns = {}

    for slotIndex = 1, ns.VPCustomFilterSlotCount do
        local slotBtn = OneWoW_GUI:CreateFitTextButton(content, {
            text = self:GetCustomFilterSlotLabel(slotIndex),
            height = rowH,
        })
        slotBtn:SetScript("OnClick", function()
            VendorPanel:ApplyCustomFilterSlot(slotIndex)
        end)
        slotBtn:HookScript("OnEnter", function(myself)
            local slot = ns.VPGetCustomFilters()[slotIndex]
            GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
            GameTooltip:SetText(VendorPanel:GetCustomFilterSlotLabel(slotIndex), OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
            if slot and slot.expr and slot.expr ~= "" then
                GameTooltip:AddLine(slot.expr, 1, 1, 1, true)
                GameTooltip:AddLine(L["VENDOR_CUSTOM_SLOT_APPLY"], OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            else
                GameTooltip:AddLine(L["VENDOR_SLOT_EMPTY"], OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            end
            GameTooltip:Show()
        end)
        slotBtn:HookScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        d.customSlotBtns[slotIndex] = slotBtn

        local clearBtn = OneWoW_GUI:CreateFitTextButton(content, { text = L["VENDOR_SLOT_CLEAR"], height = rowH, minWidth = clearW })
        clearBtn:SetScript("OnClick", function()
            if not VendorPanel:CustomFilterSlotIsEmpty(slotIndex) then
                VendorPanel:ClearCustomFilterSlot(slotIndex)
                VendorPanel:RefreshCustomFilterButtons()
            end
        end)
        clearBtn:HookScript("OnEnter", function(myself)
            GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["VENDOR_SLOT_CLEAR_TT"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
            GameTooltip:Show()
        end)
        clearBtn:HookScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        d.customClearBtns[slotIndex] = clearBtn
    end

    d.gearBtn = OneWoW_GUI:CreateFitTextButton(content, {
        text = self:GetGearButtonLabel(),
        height = rowH,
    })
    d.gearBtn:SetScript("OnClick", function()
        VendorPanel:AddGearFromGearButton()
    end)
    d.gearBtn:HookScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["VENDOR_GEAR_BUTTON_TT_TITLE"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:AddLine(L["VENDOR_GEAR_ILVL_HINT"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    d.gearBtn:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    d.gearHelpBtn = OneWoW_GUI:CreateKeywordHelpButton(content, {
        tooltipTitle = L["VENDOR_GEAR_BUTTON_TT_TITLE"],
        tooltipDesc = L["VENDOR_GEAR_ILVL_HELP"],
    })
    d.gearHelpBtn:SetScript("OnClick", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["VENDOR_GEAR_BUTTON_TT_TITLE"], 1, 1, 1)
        GameTooltip:AddLine(L["VENDOR_GEAR_ILVL_HELP"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)

    d.clearAllBtn = OneWoW_GUI:CreateFitTextButton(content, { text = L["UI_VENDOR_CLEAR_TITLE"], height = rowH })
    d.clearAllBtn:SetScript("OnClick", function()
        state.oneTimeItems.ilvlGear = {}; state.oneTimeItems.reagents = {}; state.oneTimeItems.custom = {}
        VendorPanel:ClearAddTabSearch()
        VendorPanel:UpdatePreviewPanel(); VendorPanel:UpdateButton()
        print("OneWoW QoL: " .. L["VENDOR_CLEAR_ONETIME_DONE"])
    end)
    d.clearAllBtn:HookScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["UI_VENDOR_CLEAR_TITLE"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:AddLine(L["UI_VENDOR_REMOVE_CATEGORIES"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    d.clearAllBtn:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    d.divider1 = OneWoW_GUI:CreateDivider(content, {})

    d.searchLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    d.searchLabel:SetText(L["VENDOR_SEARCH_FILTER"])
    d.searchLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    d.searchAddingLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    d.searchAddingLabel:SetText(string.format(L["VENDOR_SEARCH_ADDING"], 0))
    d.searchAddingLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    d.searchAddingLabel:SetJustifyH("RIGHT")

    d.searchBox = OneWoW_GUI:CreateEditBox(content, {
        height = 24,
        placeholderText = L["VENDOR_SEARCH_PLACEHOLDER"],
    })

    d.searchHelpBtn = OneWoW_GUI:CreateKeywordHelpButton(content, {
        editBox = d.searchBox,
        tooltipTitle = L["VENDOR_SEARCH_FILTER"],
        tooltipDesc = L["VENDOR_SEARCH_HINT"],
    })

    d.searchAddBtn = OneWoW_GUI:CreateFitTextButton(content, { text = L["VENDOR_ADD_ITEMS"], height = rowH })
    d.searchAddBtn:SetScript("OnClick", function()
        VendorPanel:AddSearchMatches(d.searchBox:GetSearchText())
    end)

    d.saveFilterBtn = OneWoW_GUI:CreateFitTextButton(content, { text = L["VENDOR_SAVE_FILTER"], height = rowH })
    d.saveFilterBtn:SetScript("OnClick", function()
        VendorPanel:OpenSaveFilterDialog()
    end)

    d.searchBox:SetScript("OnEnterPressed", function(myself)
        VendorPanel:AddSearchMatches(myself:GetSearchText())
        myself:ClearFocus()
    end)

    d.searchBox:SetScript("OnTextChanged", function()
        if d._searchPreviewTimer then d._searchPreviewTimer:Cancel() end
        d._searchPreviewTimer = C_Timer.NewTimer(SEARCH_PREVIEW_DEBOUNCE, function()
            VendorPanel:UpdateSearchPreview()
        end)
    end)
    d.searchBox:HookScript("OnEditFocusGained", function()
        VendorPanel:UpdateSearchPreview()
    end)
    d.searchBox:HookScript("OnEditFocusLost", function()
        C_Timer.After(0, function() VendorPanel:UpdateSearchPreview() end)
    end)

    d.searchPreviewSection = CreateFrame("Frame", nil, content)
    d.searchPreviewSection:Hide()

    d.searchPreviewHeader = d.searchPreviewSection:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    d.searchPreviewHeader:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    d.searchPreviewHeader:SetJustifyH("LEFT")

    d.searchPreviewScroll = CreateFrame("ScrollFrame", nil, d.searchPreviewSection, "UIPanelScrollFrameTemplate")
    OneWoW_GUI:StyleScrollBar(d.searchPreviewScroll, { offset = -4 })

    d.searchPreviewScrollChild = CreateFrame("Frame", nil, d.searchPreviewScroll)
    d.searchPreviewScrollChild:SetWidth(190)
    d.searchPreviewScroll:SetScrollChild(d.searchPreviewScrollChild)

    VendorPanel:CreateSaveFilterDialog()
    VendorPanel:RelayoutAddTab()
    C_Timer.After(0, function() VendorPanel:RelayoutAddTab() end)
end

function VendorPanel:ClearAddTabSearch()
    local d = state.addTab
    if not d or not d.searchBox then return end
    d.searchBox:SetText("")
    d.searchBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    self:UpdateSearchPreview()
end

function VendorPanel:ApplyFixedWidthButtonText(btn, text, btnWidth)
    local fs = btn.text
    local textWidth = math.max((btnWidth or btn:GetWidth()) - 8, 24)
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", btn, "LEFT", 4, 0)
    fs:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
    fs:SetWordWrap(false)
    fs:SetMaxLines(1)
    fs:SetJustifyH("CENTER")
    fs:SetText(text or "")
    if fs:GetStringWidth() > textWidth then
        local ellipsis = "…"
        for i = #text, 1, -1 do
            local candidate = text:sub(1, i) .. ellipsis
            fs:SetText(candidate)
            if fs:GetStringWidth() <= textWidth then
                return
            end
        end
        fs:SetText(ellipsis)
    end
end

function VendorPanel:RefreshCustomFilterButtons()
    if state.addTab then
        self:RelayoutAddTab()
    end
end

function VendorPanel:CreateSaveFilterDialog()
    if state.saveFilterDialog then return end

    local result = OneWoW_GUI:CreateDialog({
        name = "OneWoW_QoL_SaveFilterDialog",
        title = L["VENDOR_SAVE_FILTER_TITLE"],
        width = 320,
        height = 330,
        strata = "DIALOG",
        onClose = function(frame) frame:Hide() end,
        buttons = {
            { text = CANCEL, onClick = function(frame) frame:Hide() end },
            { text = SAVE, onClick = function() VendorPanel:ConfirmSaveFilterDialog() end },
        },
    })
    state.saveFilterDialog = result.frame
    local content = result.contentFrame
    local sd = { frame = state.saveFilterDialog, content = content, selectedSlot = nil }
    state.saveFilterDialogData = sd

    sd.hint = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sd.hint:SetText(L["VENDOR_SAVE_FILTER_PICK"])
    sd.hint:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    sd.hint:SetJustifyH("LEFT")

    sd.slotBtns = {}
    for slotIndex = 1, ns.VPCustomFilterSlotCount do
        local slotBtn = OneWoW_GUI:CreateFitTextButton(content, {
            text = self:GetCustomFilterSlotLabel(slotIndex),
            height = 24,
            toggleable = true,
        })
        slotBtn:SetScript("OnClick", function()
            sd.selectedSlot = slotIndex
            for i, b in ipairs(sd.slotBtns) do
                b:SetActive(i == slotIndex)
            end
            local slot = ns.VPGetCustomFilters()[slotIndex]
            if slot and slot.name and slot.name ~= "" then
                sd.titleBox:SetText(slot.name)
                sd.titleBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                sd.replaceHint:SetText(string.format(L["VENDOR_FILTER_REPLACE_HINT"], slot.name))
                sd.replaceHint:Show()
            else
                sd.titleBox:SetText("")
                sd.replaceHint:Hide()
            end
            VendorPanel:RelayoutSaveFilterDialog()
        end)
        sd.slotBtns[slotIndex] = slotBtn
    end

    sd.nameLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sd.nameLabel:SetText(L["VENDOR_FILTER_NAME_LABEL"])
    sd.nameLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    sd.titleBox = OneWoW_GUI:CreateEditBox(content, {
        height = 24,
        maxLetters = 32,
    })

    sd.replaceHint = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sd.replaceHint:SetText("")
    sd.replaceHint:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
    sd.replaceHint:Hide()

    VendorPanel:RelayoutSaveFilterDialog()
    state.saveFilterDialog:Hide()
    state.saveFilterDialog:HookScript("OnShow", function()
        VendorPanel:RelayoutSaveFilterDialog()
    end)
end

function VendorPanel:RelayoutSaveFilterDialog()
    local sd = state.saveFilterDialogData
    if not sd or not sd.hint then return end
    local content = sd.content
    local pad = OneWoW_GUI:GetSpacing("SM")
    local colGap = 4
    local y = -pad
    local contentW = content:GetWidth()
    if contentW < 1 then contentW = 280 end
    local colW = (contentW - pad * 2 - colGap) / 2

    sd.hint:ClearAllPoints()
    sd.hint:SetPoint("TOPLEFT", content, "TOPLEFT", pad, y)
    sd.hint:SetPoint("TOPRIGHT", content, "TOPRIGHT", -pad, y)
    y = y - math.max(math.ceil(sd.hint:GetStringHeight() or 0), 14) - 8

    local slotRows = math.ceil(ns.VPCustomFilterSlotCount / 2)
    for slotIndex, btn in ipairs(sd.slotBtns) do
        local col = (slotIndex - 1) % 2
        local row = math.floor((slotIndex - 1) / 2)
        btn:ClearAllPoints()
        btn:SetSize(colW, 24)
        btn:SetPoint("TOPLEFT", content, "TOPLEFT", pad + col * (colW + colGap), y - row * 26)
    end
    y = y - slotRows * 26 - 8

    sd.nameLabel:ClearAllPoints()
    sd.nameLabel:SetPoint("TOPLEFT", content, "TOPLEFT", pad, y)
    y = y - math.max(math.ceil(sd.nameLabel:GetStringHeight() or 0), 12) - 4

    sd.titleBox:ClearAllPoints()
    sd.titleBox:SetPoint("TOPLEFT", content, "TOPLEFT", pad, y)
    sd.titleBox:SetPoint("TOPRIGHT", content, "TOPRIGHT", -pad, y)
    y = y - sd.titleBox:GetHeight() - 4

    sd.replaceHint:ClearAllPoints()
    sd.replaceHint:SetPoint("TOPLEFT", content, "TOPLEFT", pad, y)
    sd.replaceHint:SetPoint("TOPRIGHT", content, "TOPRIGHT", -pad, y)
end

function VendorPanel:OpenSaveFilterDialog()
    if not state.addTab or not state.addTab.searchBox then return end
    local expr = state.addTab.searchBox:GetSearchText()
    if expr == "" then
        print("OneWoW QoL: " .. L["VENDOR_SEARCH_EMPTY"])
        return
    end
    local result = self:GetSearchMatches(expr, 0)
    if result.empty or not result.valid then
        print("OneWoW QoL: " .. L["VENDOR_SEARCH_INVALID"] .. (result.error and (" " .. result.error) or ""))
        return
    end

    if not state.saveFilterDialog then self:CreateSaveFilterDialog() end
    local sd = state.saveFilterDialogData
    sd.selectedSlot = nil
    sd.titleBox:SetText("")
    sd.replaceHint:Hide()
    for i, btn in ipairs(sd.slotBtns) do
        btn:SetActive(false)
        if btn.SetFitText then
            btn:SetFitText(self:GetCustomFilterSlotLabel(i))
        else
            btn.text:SetText(self:GetCustomFilterSlotLabel(i))
        end
    end
    self:RelayoutSaveFilterDialog()
    state.saveFilterDialog:Show()
end

function VendorPanel:ConfirmSaveFilterDialog()
    local sd = state.saveFilterDialogData
    if not sd or not state.addTab or not state.addTab.searchBox then return end
    if not sd.selectedSlot then
        print("OneWoW QoL: " .. L["VENDOR_SAVE_FILTER_PICK"])
        return
    end

    local expr = state.addTab.searchBox:GetSearchText()
    if expr == "" then
        print("OneWoW QoL: " .. L["VENDOR_SEARCH_EMPTY"])
        return
    end

    local name = strtrim(sd.titleBox:GetSearchText())
    if name == "" then
        print("OneWoW QoL: " .. L["VENDOR_SAVE_NEED_TITLE"])
        return
    end

    local slotIndex = sd.selectedSlot
    if not self:CustomFilterSlotIsEmpty(slotIndex) then
        local existing = self:GetCustomFilterSlotLabel(slotIndex)
        state._pendingFilterSave = { slotIndex = slotIndex, name = name, expr = expr }
        local popup = StaticPopupDialogs["ONEWOW_VP_REPLACE_FILTER"]
        popup.text = string.format(L["VENDOR_FILTER_REPLACE"], existing)
        StaticPopup_Show("ONEWOW_VP_REPLACE_FILTER")
        return
    end

    self:SaveCustomFilterSlot(slotIndex, name, expr)
    self:RefreshCustomFilterButtons()
    state.saveFilterDialog:Hide()
    print("OneWoW QoL: " .. string.format(L["VENDOR_FILTER_SAVED"], name))
end

function VendorPanel:UpdateSearchAddingCount(count)
    local d = state.addTab
    if not d or not d.searchAddingLabel then return end
    d.searchAddingLabel:SetText(string.format(L["VENDOR_SEARCH_ADDING"], count or 0))
end

function VendorPanel:ShouldShowSearchPreview()
    local d = state.addTab
    if not d or not d.searchBox then return false end
    if d.searchBox:GetSearchText() ~= "" then return true end
    return d.searchBox:HasFocus()
end

function VendorPanel:ClearSearchPreviewRows()
    local d = state.addTab
    if not d or not d.searchPreviewScrollChild then return end
    for _, child in ipairs({ d.searchPreviewScrollChild:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end
end

function VendorPanel:UpdateSearchPreview()
    local d = state.addTab
    if not d or not d.searchPreviewSection then return end

    local expr = d.searchBox:GetSearchText()
    local show = self:ShouldShowSearchPreview()
    if not show then
        d.searchPreviewSection:Hide()
        if expr == "" then
            self:UpdateSearchAddingCount(0)
        else
            local result = self:GetSearchMatches(expr, 0)
            self:UpdateSearchAddingCount(result.valid and result.totalCount or 0)
        end
        self:RelayoutAddTab()
        return
    end

    d.searchPreviewSection:Show()
    self:RelayoutAddTab()
    self:ClearSearchPreviewRows()

    local header = d.searchPreviewHeader
    header:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    if expr == "" then
        header:SetText(L["VENDOR_SEARCH_PREVIEW_HINT"])
        self:UpdateSearchAddingCount(0)
        d.searchPreviewScrollChild:SetHeight(1)
        self:RelayoutAddTab()
        return
    end

    local result = self:GetSearchMatches(expr)
    if not result.valid then
        header:SetText(L["VENDOR_SEARCH_INVALID"])
        header:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
        self:UpdateSearchAddingCount(0)
        d.searchPreviewScrollChild:SetHeight(1)
        self:RelayoutAddTab()
        return
    end

    if result.totalCount == 0 then
        header:SetText(string.format(L["VENDOR_SEARCH_NONE"], expr))
        self:UpdateSearchAddingCount(0)
        d.searchPreviewScrollChild:SetHeight(1)
        self:RelayoutAddTab()
        return
    end

    header:SetText(string.format(L["VENDOR_SEARCH_PREVIEW_COUNT"], result.totalCount))
    self:UpdateSearchAddingCount(result.totalCount)

    local scrollChild = d.searchPreviewScrollChild
    local rowWidth = math.max((d.searchPreviewSection:GetWidth() or 190) - 4, 160)
    scrollChild:SetWidth(rowWidth)
    local yOffset = 0

    for _, item in ipairs(result.items) do
        local itemFrame = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
        itemFrame:SetSize(rowWidth, 24)
        itemFrame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yOffset)
        itemFrame:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER)
        itemFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        itemFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

        local iconFrame = CreateFrame("Frame", nil, itemFrame, "BackdropTemplate")
        iconFrame:SetSize(20, 20)
        iconFrame:SetPoint("LEFT", itemFrame, "LEFT", 3, 0)
        iconFrame:SetBackdrop(backdropIconEdge)
        iconFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

        local icon = iconFrame:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints(iconFrame)
        icon:SetTexture(item.icon)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

        local displayText = item.link or ("Item " .. item.itemID)
        if item.stackCount > 1 then displayText = displayText .. " x" .. item.stackCount end
        if item.itemLevel and item.itemLevel > 0 then
            displayText = displayText .. " (" .. item.itemLevel .. ")"
        end

        local text = itemFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("LEFT", iconFrame, "RIGHT", 4, 0)
        text:SetPoint("RIGHT", itemFrame, "RIGHT", -4, 0)
        text:SetText(displayText)
        text:SetJustifyH("LEFT")

        itemFrame:SetScript("OnEnter", function(myself)
            myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
            GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
            if item.link then GameTooltip:SetHyperlink(item.link) else GameTooltip:SetItemByID(item.itemID) end
            GameTooltip:Show()
        end)
        itemFrame:SetScript("OnLeave", function(myself)
            myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            GameTooltip:Hide()
        end)

        yOffset = yOffset + 26
    end

    if result.totalCount > #result.items then
        local moreText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        moreText:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, -yOffset)
        moreText:SetText(string.format(L["VENDOR_SEARCH_PREVIEW_MORE"], result.totalCount - #result.items))
        moreText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        yOffset = yOffset + 18
    end

    scrollChild:SetHeight(math.max(yOffset, 1))
    self:RelayoutAddTab()
end

--- Re-flow the Add tab rows top-to-bottom with measured heights.
function VendorPanel:RelayoutAddTab()
    local d = state.addTab
    if not d or not d.customSlotBtns then return end
    local content = d.content or d.customSlotBtns[1]:GetParent()
    local pad = OneWoW_GUI:GetSpacing("SM")
    local md = OneWoW_GUI:GetSpacing("MD")
    local rowGap = 2
    local rowH = 22
    local clearW = 22
    local slotClearGap = 4
    local colGap = 8
    local y = -pad
    local contentW = content:GetWidth()
    if contentW < 1 and state.junkPreviewPanel then
        contentW = (state.junkPreviewPanel:GetWidth() or 320) - 28
    end
    local columnW = (contentW - pad * 2 - colGap) / 2
    local slotW = columnW - clearW - slotClearGap

    local function measureBtnHeight(btn, label, width)
        if label and width then
            self:ApplyFixedWidthButtonText(btn, label, width)
        end
        local textH = math.ceil(btn.text:GetStringHeight() or 0)
        if textH < 12 then textH = 12 end
        return math.max(rowH, textH + 8)
    end

    local function placeSlotPair(leftIndex, rightIndex, rowY, pairH)
        local leftBtn = d.customSlotBtns[leftIndex]
        local leftClear = d.customClearBtns[leftIndex]
        leftBtn:SetHeight(pairH)
        leftClear:SetHeight(pairH)
        leftBtn:ClearAllPoints()
        leftClear:ClearAllPoints()
        leftBtn:SetPoint("TOPLEFT", content, "TOPLEFT", pad, rowY)
        leftBtn:SetWidth(slotW)
        self:ApplyFixedWidthButtonText(leftBtn, self:GetCustomFilterSlotLabel(leftIndex), slotW)
        leftClear:SetPoint("LEFT", leftBtn, "RIGHT", slotClearGap, 0)
        leftClear:SetWidth(clearW)

        local rightBtn = d.customSlotBtns[rightIndex]
        local rightClear = d.customClearBtns[rightIndex]
        rightBtn:SetHeight(pairH)
        rightClear:SetHeight(pairH)
        rightBtn:ClearAllPoints()
        rightClear:ClearAllPoints()
        local x = pad + columnW + colGap
        rightBtn:SetPoint("TOPLEFT", content, "TOPLEFT", x, rowY)
        rightBtn:SetWidth(slotW)
        self:ApplyFixedWidthButtonText(rightBtn, self:GetCustomFilterSlotLabel(rightIndex), slotW)
        rightClear:SetPoint("LEFT", rightBtn, "RIGHT", slotClearGap, 0)
        rightClear:SetWidth(clearW)
    end

    local h0 = math.max(
        measureBtnHeight(d.customSlotBtns[1], self:GetCustomFilterSlotLabel(1), slotW),
        measureBtnHeight(d.customSlotBtns[2], self:GetCustomFilterSlotLabel(2), slotW)
    )
    local rowY = y
    placeSlotPair(1, 2, rowY, h0)
    rowY = rowY - h0 - rowGap

    local h1 = math.max(
        measureBtnHeight(d.customSlotBtns[3], self:GetCustomFilterSlotLabel(3), slotW),
        measureBtnHeight(d.customSlotBtns[4], self:GetCustomFilterSlotLabel(4), slotW)
    )
    placeSlotPair(3, 4, rowY, h1)
    rowY = rowY - h1 - rowGap

    local h2 = math.max(
        measureBtnHeight(d.customSlotBtns[5], self:GetCustomFilterSlotLabel(5), slotW),
        measureBtnHeight(d.gearBtn, self:GetGearButtonLabel(), slotW)
    )
    do
        local slotBtn = d.customSlotBtns[5]
        local clearBtn = d.customClearBtns[5]
        slotBtn:SetHeight(h2)
        clearBtn:SetHeight(h2)
        slotBtn:ClearAllPoints()
        clearBtn:ClearAllPoints()
        slotBtn:SetPoint("TOPLEFT", content, "TOPLEFT", pad, rowY)
        slotBtn:SetWidth(slotW)
        self:ApplyFixedWidthButtonText(slotBtn, self:GetCustomFilterSlotLabel(5), slotW)
        clearBtn:SetPoint("LEFT", slotBtn, "RIGHT", slotClearGap, 0)
        clearBtn:SetWidth(clearW)

        d.gearBtn:SetHeight(h2)
        d.gearHelpBtn:SetSize(clearW, h2)
        d.gearBtn:ClearAllPoints()
        d.gearHelpBtn:ClearAllPoints()
        local x = pad + columnW + colGap
        d.gearBtn:SetPoint("TOPLEFT", content, "TOPLEFT", x, rowY)
        d.gearBtn:SetWidth(slotW)
        self:ApplyFixedWidthButtonText(d.gearBtn, self:GetGearButtonLabel(), slotW)
        d.gearHelpBtn:SetPoint("LEFT", d.gearBtn, "RIGHT", slotClearGap, 0)
    end
    y = rowY - h2 - 6

    local clearH = measureBtnHeight(d.clearAllBtn)
    d.clearAllBtn:SetHeight(clearH)
    d.clearAllBtn:ClearAllPoints()
    d.clearAllBtn:SetPoint("TOPLEFT", content, "TOPLEFT", pad, y)
    d.clearAllBtn:SetPoint("TOPRIGHT", content, "TOPRIGHT", -pad, y)
    y = y - clearH - 8

    local function placeDivider(div)
        div:ClearAllPoints()
        div:SetPoint("TOPLEFT", content, "TOPLEFT", md, y)
        div:SetPoint("TOPRIGHT", content, "TOPRIGHT", -md, y)
        y = y - 10
    end

    placeDivider(d.divider1)

    d.searchLabel:ClearAllPoints()
    d.searchLabel:SetPoint("TOPLEFT", content, "TOPLEFT", pad, y)
    d.searchAddingLabel:ClearAllPoints()
    d.searchAddingLabel:SetPoint("TOPRIGHT", content, "TOPRIGHT", -pad, y)
    d.searchAddingLabel:SetPoint("LEFT", d.searchLabel, "RIGHT", 8, 0)
    local labelH = math.max(
        math.ceil(d.searchLabel:GetStringHeight() or 0),
        math.ceil(d.searchAddingLabel:GetStringHeight() or 0),
        14
    )
    y = y - labelH - 4

    d.searchHelpBtn:ClearAllPoints()
    d.searchHelpBtn:SetPoint("TOPRIGHT", content, "TOPRIGHT", -pad, y)
    d.searchBox:ClearAllPoints()
    d.searchBox:SetPoint("TOPLEFT", content, "TOPLEFT", pad, y)
    d.searchBox:SetPoint("RIGHT", d.searchHelpBtn, "LEFT", -4, 0)
    y = y - math.max(d.searchBox:GetHeight(), d.searchHelpBtn:GetHeight()) - 4

    local actionW = (contentW - pad * 2 - colGap) / 2
    d.searchAddBtn:ClearAllPoints()
    d.searchAddBtn:SetPoint("TOPLEFT", content, "TOPLEFT", pad, y)
    d.searchAddBtn:SetWidth(actionW)
    d.saveFilterBtn:ClearAllPoints()
    d.saveFilterBtn:SetPoint("TOPLEFT", content, "TOPLEFT", pad + actionW + colGap, y)
    d.saveFilterBtn:SetWidth(actionW)
    y = y - math.max(d.searchAddBtn:GetHeight(), d.saveFilterBtn:GetHeight()) - 4

    if d.searchPreviewSection and d.searchPreviewSection:IsShown() then
        d.searchPreviewSection:ClearAllPoints()
        d.searchPreviewSection:SetPoint("TOPLEFT", content, "TOPLEFT", pad, y)
        d.searchPreviewSection:SetPoint("TOPRIGHT", content, "TOPRIGHT", -pad, y)
        d.searchPreviewSection:SetHeight(SEARCH_PREVIEW_HEIGHT)

        d.searchPreviewHeader:ClearAllPoints()
        d.searchPreviewHeader:SetPoint("TOPLEFT", d.searchPreviewSection, "TOPLEFT", 0, 0)
        d.searchPreviewHeader:SetPoint("TOPRIGHT", d.searchPreviewSection, "TOPRIGHT", 0, 0)
        local headerH = math.max(math.ceil(d.searchPreviewHeader:GetStringHeight() or 0), 12)

        d.searchPreviewScroll:ClearAllPoints()
        d.searchPreviewScroll:SetPoint("TOPLEFT", d.searchPreviewSection, "TOPLEFT", 0, -(headerH + 2))
        d.searchPreviewScroll:SetPoint("BOTTOMRIGHT", d.searchPreviewSection, "BOTTOMRIGHT", -4, 0)
        if d.searchPreviewScrollChild then
            d.searchPreviewScrollChild:SetWidth(d.searchPreviewSection:GetWidth())
        end

        y = y - SEARCH_PREVIEW_HEIGHT - pad
    end

    content:SetHeight(math.max(-y, 1))
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
                    local itemName, itemLink, quality, _, _, _, _, _, _, itemTexture, sellPrice, classID, subclassID = VPFilters.GetItemInfoForSlot(itemInfo, bag, slot)
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
                        if actualItemLink then
                            local instanceSell = select(11, C_Item.GetItemInfo(actualItemLink))
                            if instanceSell ~= nil then sellPrice = instanceSell end
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
    if not state.moduleActive then return end
    if not state.junkPreviewPanel then return end
    if state.junkPreviewPanel.manuallyHidden then return end
    if not GetShowPanel() then return end
    -- Do not require MerchantFrame:IsShown() here: MERCHANT_SHOW (OnMerchantShow)
    -- can run before the frame reports shown; gating on it left the tab without a panel
    -- and skipped FadeMerchantGrid (known-item dim).

    if state.vendorDropdown and state.vendorDropdown.RefreshFilters then
        state.vendorDropdown:RefreshFilters()
    end

    local grayItems, markedItems, ilvlGearItems, reagentItems, noValueJunkItems, customItems, allCached = self:GetJunkItemsDetailed()
    if not allCached then
        C_Timer.After(0.3, function()
            if not state.moduleActive then return end
            if not OneWoW.Merchant.IsMerchantOpen() then return end
            self:UpdatePreviewPanel()
        end)
        return
    end

    if not GetShowBlizzJunk() then noValueJunkItems = {} end

    state.junkPreviewPanel:Show()
    self:ManageBlizzardSellButton(true)
    -- MerchantFrame_Update often runs before this Show; re-apply fade/dim now
    -- that the panel is visible (DispatchMerchantGridUpdate requires IsShown).
    self:RefreshMerchantGrid()
    if (state.dimKnownItems or GetSettings().hideKnownEntirely) and not state._knownDimRetryScheduled then
        -- Recipe / collectible known checks can miss on cold tooltip data.
        -- Separate from ScheduleMerchantGridRefresh so link-load retries are not cancelled.
        state._knownDimRetryScheduled = true
        C_Timer.After(0.4, function()
            if not state.moduleActive then return end
            if not OneWoW.Merchant.IsMerchantOpen() then return end
            self:RefreshMerchantGrid()
        end)
    end

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
    state.junkPreviewPanel.totalValueText:SetText(string.format(L["VENDOR_TOTAL"], OneWoW.Format.FormatGold(totalValue)))

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
    headerText:SetText(title .. " (" .. #items .. ") - " .. OneWoW.Format.FormatGold(categoryTotal))
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
                totalPriceText:SetText(OneWoW.Format.FormatGold(item.totalValue))
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
                eaPriceText:SetText(OneWoW.Format.FormatGold(item.sellPrice) .. " ea")
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
