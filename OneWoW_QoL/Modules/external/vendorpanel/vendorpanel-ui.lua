-- OneWoW_QoL Addon File
-- OneWoW_QoL/Modules/external/vendorpanel/vendorpanel-ui.lua
local addonName, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)

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
    local db = (_G.OneWoW and _G.OneWoW.db) or (_G.OneWoW_QoL and _G.OneWoW_QoL.db)
    local factionTheme = db and db.global and db.global.minimap and db.global.minimap.theme or "horde"
    return OneWoW_GUI:GetBrandIcon(factionTheme)
end

local function GetFactionTheme()
    local db = (_G.OneWoW and _G.OneWoW.db) or (_G.OneWoW_QoL and _G.OneWoW_QoL.db)
    return db and db.global and db.global.minimap and db.global.minimap.theme or "horde"
end

function VendorPanel:CreateVendorButton()
    if state.vendorButton then return end

    state.vendorButton = CreateFrame("Button", "OneWoW_QoL_VendorButton", MerchantFrame, "BackdropTemplate")
    state.vendorButton:SetSize(100, 22)
    state.vendorButton:SetPoint("TOPLEFT", MerchantFrame, "TOPLEFT", 60, -28)
    state.vendorButton:SetFrameLevel(MerchantFrame:GetFrameLevel() + 10)
    state.vendorButton:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER)
    state.vendorButton:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
    state.vendorButton:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))

    local fs = state.vendorButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("CENTER")
    fs:SetText("Sell (0/0)")
    fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
    state.vendorButton.fontString = fs

    -- NOTE (kellewic): Not sure why this code sets OnEnter and OnLeave twice since the ones further down overwrite these.
    state.vendorButton:SetScript("OnEnter", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
        fs:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_HIGHLIGHT"))
    end)
    state.vendorButton:SetScript("OnLeave", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
        fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
    end)

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
        fs:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_HIGHLIGHT"))
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
        fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
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

    state.replacementSellButton = CreateFrame("Button", "OneWoW_QoL_ReplacementSellButton", MerchantFrame, "BackdropTemplate")
    state.replacementSellButton:SetSize(blizzButton:GetWidth(), blizzButton:GetHeight())
    state.replacementSellButton:SetPoint("CENTER", blizzButton, "CENTER", 0, 0)
    state.replacementSellButton:SetFrameLevel(blizzButton:GetFrameLevel() + 5)
    state.replacementSellButton:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER)
    state.replacementSellButton:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
    state.replacementSellButton:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))

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

    state.replacementSellButton:SetScript("OnEnter", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
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

    state.replacementSellButton:SetScript("OnLeave", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
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

    local titleBar = OneWoW_GUI:CreateTitleBar(state.junkPreviewPanel, ns.L["VENDOR_TOOLS_TITLE"], {
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

    local vendorDropdown = CreateFrame("Button", "OneWoW_QoL_VendorItemFilter", filterRow, "BackdropTemplate")
    vendorDropdown:SetPoint("LEFT", filterLabel, "RIGHT", OneWoW_GUI:GetSpacing("XS"), 0)
    vendorDropdown:SetPoint("RIGHT", filterRow, "RIGHT", -OneWoW_GUI:GetSpacing("SM"), 0)
    vendorDropdown:SetHeight(22)
    vendorDropdown:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER)
    vendorDropdown:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    vendorDropdown:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local dropText = vendorDropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dropText:SetPoint("LEFT", vendorDropdown, "LEFT", OneWoW_GUI:GetSpacing("SM"), 0)
    dropText:SetPoint("RIGHT", vendorDropdown, "RIGHT", -20, 0)
    dropText:SetJustifyH("LEFT")
    dropText:SetText(state.currentVendorFilter)
    dropText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    vendorDropdown.text = dropText

    local dropArrow = vendorDropdown:CreateTexture(nil, "OVERLAY")
    dropArrow:SetSize(12, 12)
    dropArrow:SetPoint("RIGHT", vendorDropdown, "RIGHT", -OneWoW_GUI:GetSpacing("XS"), 0)
    dropArrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

    vendorDropdown:SetScript("OnEnter", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
    end)
    vendorDropdown:SetScript("OnLeave", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    end)

    local dropdownMenu

    local function SetFilter(filterName)
        state.currentVendorFilter = filterName
        dropText:SetText(filterName == "Cosmetic Items" and "Cosmetics" or filterName)
        if dropdownMenu then dropdownMenu:Hide() end
        if MerchantFrame and MerchantFrame:IsShown() then MerchantFrame_Update() end
    end

    local function CreateDropdownMenu()
        if dropdownMenu then dropdownMenu:Hide(); dropdownMenu = nil end

        dropdownMenu = CreateFrame("Frame", nil, vendorDropdown, "BackdropTemplate")
        dropdownMenu:SetFrameStrata("FULLSCREEN_DIALOG")
        dropdownMenu:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER)
        dropdownMenu:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
        dropdownMenu:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
        dropdownMenu:SetClipsChildren(true)

        local scrollFrame = CreateFrame("ScrollFrame", nil, dropdownMenu, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 2, -2)
        scrollFrame:SetPoint("BOTTOMRIGHT", -2, 2)
        OneWoW_GUI:StyleScrollBar(scrollFrame, { offset = -5 })

        local scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetWidth(1)
        scrollChild:SetHeight(1)
        scrollFrame:SetScrollChild(scrollChild)

        local yOff = 0
        local itemHeight = 22
        local menuWidth = vendorDropdown:GetWidth()

        local function AddItem(text, onClick, isChecked)
            local btn = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
            btn:SetSize(menuWidth - 20, itemHeight)
            btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 2, -yOff)
            btn:SetBackdrop(BACKDROP_SIMPLE)
            btn:SetBackdropColor(0, 0, 0, 0)

            local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            btnText:SetPoint("LEFT", btn, "LEFT", OneWoW_GUI:GetSpacing("SM"), 0)
            btnText:SetText(text)
            btnText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

            if isChecked then
                local check = btn:CreateTexture(nil, "OVERLAY")
                check:SetSize(10, 10)
                check:SetPoint("RIGHT", btn, "RIGHT", -OneWoW_GUI:GetSpacing("XS"), 0)
                check:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            end

            btn:SetScript("OnEnter", function(self)
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
                btnText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
            end)
            btn:SetScript("OnLeave", function(self)
                self:SetBackdropColor(0, 0, 0, 0)
                btnText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end)
            btn:SetScript("OnClick", onClick)
            yOff = yOff + itemHeight
        end

        local function AddHeader(text)
            local header = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            header:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", OneWoW_GUI:GetSpacing("SM"), -yOff - 4)
            header:SetText(text)
            header:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            yOff = yOff + itemHeight + 2
        end

        local function AddSpacer()
            local divider = scrollChild:CreateTexture(nil, "ARTWORK")
            divider:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", OneWoW_GUI:GetSpacing("SM"), -yOff - 4)
            divider:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -OneWoW_GUI:GetSpacing("SM"), -yOff - 4)
            divider:SetHeight(1)
            divider:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            yOff = yOff + 10
        end

        local hasEquipable = state.availableFilters["Equipable"]
        if hasEquipable then
            local checkRow = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
            checkRow:SetSize(menuWidth - 20, itemHeight)
            checkRow:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 2, -yOff)
            checkRow:SetBackdrop(BACKDROP_SIMPLE)
            checkRow:SetBackdropColor(0, 0, 0, 0)

            local checkBox = CreateFrame("CheckButton", nil, checkRow, "UICheckButtonTemplate")
            checkBox:SetSize(18, 18)
            checkBox:SetPoint("LEFT", checkRow, "LEFT", OneWoW_GUI:GetSpacing("XS"), 0)
            checkBox:SetChecked(state.showAllArmor)
            checkBox:SetScript("OnClick", function(self)
                state.showAllArmor = self:GetChecked()
                local settings = GetSettings()
                settings.showAllArmor = state.showAllArmor
                if MerchantFrame and MerchantFrame:IsShown() then MerchantFrame_Update() end
            end)

            local checkLabel = checkRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            checkLabel:SetPoint("LEFT", checkBox, "RIGHT", 2, 0)
            checkLabel:SetText("All Armor Types")
            checkLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

            checkRow:SetScript("OnEnter", function(self)
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
                checkLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
            end)
            checkRow:SetScript("OnLeave", function(self)
                self:SetBackdropColor(0, 0, 0, 0)
                checkLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end)
            checkRow:SetScript("OnClick", function()
                checkBox:SetChecked(not checkBox:GetChecked())
                state.showAllArmor = checkBox:GetChecked()
                local settings = GetSettings()
                settings.showAllArmor = state.showAllArmor
                if MerchantFrame and MerchantFrame:IsShown() then MerchantFrame_Update() end
            end)
            yOff = yOff + itemHeight
            AddSpacer()
        end

        AddItem("Show All", function() SetFilter("Show All") end,
            state.currentVendorFilter == "Show All")

        local collectibles = {"Mounts", "Pets", "Toys", "Cosmetic Items", "Decor", "Housing"}
        local numCollect = 0
        for _, label in ipairs(collectibles) do if state.availableFilters[label] then numCollect = numCollect + 1 end end
        if numCollect > 0 then
            AddSpacer()
            AddHeader("Collectibles")
            for _, label in ipairs(collectibles) do
                if state.availableFilters[label] then
                    AddItem(label, function() SetFilter(label) end, state.currentVendorFilter == label)
                end
            end
        end

        local materials = {"Consumables", "Reagents"}
        local numMat = 0
        for _, label in ipairs(materials) do if state.availableFilters[label] then numMat = numMat + 1 end end
        if numMat > 0 then
            AddSpacer()
            AddHeader("Materials & Consumables")
            for _, label in ipairs(materials) do
                if state.availableFilters[label] then
                    AddItem(label, function() SetFilter(label) end, state.currentVendorFilter == label)
                end
            end
        end

        local equipment = {"Equipable","Head","Neck","Shoulder","Back","Chest","Waist","Legs","Feet","Wrist","Hands","Rings","Trinkets","Weapons"}
        local numEquip = 0
        for _, label in ipairs(equipment) do if state.availableFilters[label] then numEquip = numEquip + 1 end end
        if numEquip > 0 then
            AddSpacer()
            AddHeader("Equipment")
            for _, label in ipairs(equipment) do
                if state.availableFilters[label] then
                    AddItem(label, function() SetFilter(label) end, state.currentVendorFilter == label)
                end
            end
        end

        local professions = {"Alchemy","Blacksmithing","Cooking","Enchanting","Engineering","Inscription","Jewelcrafting","Leatherworking","Tailoring"}
        local numProf = 0
        for _, label in ipairs(professions) do if state.availableFilters[label] then numProf = numProf + 1 end end
        if state.availableFilters["Patterns"] or numProf > 0 then
            AddSpacer()
            AddHeader("Patterns / Recipes")
            if state.availableFilters["Patterns"] then
                AddItem("All Patterns", function() SetFilter("Patterns") end, state.currentVendorFilter == "Patterns")
            end
            for _, label in ipairs(professions) do
                if state.availableFilters[label] then
                    AddItem(label, function() SetFilter(label) end, state.currentVendorFilter == label)
                end
            end
        end

        local totalHeight = yOff + 4
        local maxHeight = 300
        local menuHeight = math.min(totalHeight, maxHeight)
        scrollChild:SetWidth(menuWidth - 20)
        scrollChild:SetHeight(totalHeight)
        dropdownMenu:SetSize(menuWidth, menuHeight)
        dropdownMenu:SetPoint("TOPLEFT", vendorDropdown, "BOTTOMLEFT", 0, -2)

        local elapsed = 0
        dropdownMenu:SetScript("OnUpdate", function(self, dt)
            if self:IsMouseOver() or vendorDropdown:IsMouseOver() then
                elapsed = 0
            else
                elapsed = elapsed + dt
                if elapsed > 0.5 then self:Hide() end
            end
        end)

        dropdownMenu:Show()
    end

    vendorDropdown:SetScript("OnClick", function()
        if dropdownMenu and dropdownMenu:IsShown() then
            dropdownMenu:Hide()
        else
            CreateDropdownMenu()
        end
    end)

    vendorDropdown.RefreshFilters = function()
        dropText:SetText(state.currentVendorFilter == "Cosmetic Items" and "Cosmetics" or state.currentVendorFilter)
    end

    state.junkPreviewPanel.vendorDropdown = vendorDropdown

    local dimKnownRow = CreateFrame("Button", nil, state.junkPreviewPanel, "BackdropTemplate")
    dimKnownRow:SetPoint("TOPLEFT", filterRow, "BOTTOMLEFT", 0, -1)
    dimKnownRow:SetPoint("TOPRIGHT", filterRow, "BOTTOMRIGHT", 0, -1)
    dimKnownRow:SetHeight(24)
    dimKnownRow:SetBackdrop(BACKDROP_SIMPLE)
    dimKnownRow:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))

    local dimCheckBox = CreateFrame("CheckButton", nil, dimKnownRow, "UICheckButtonTemplate")
    dimCheckBox:SetSize(18, 18)
    dimCheckBox:SetPoint("LEFT", dimKnownRow, "LEFT", OneWoW_GUI:GetSpacing("SM"), 0)
    dimCheckBox:SetChecked(state.dimKnownItems)

    local dimLabel = dimKnownRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dimLabel:SetPoint("LEFT", dimCheckBox, "RIGHT", 2, 0)
    dimLabel:SetText(ns.L["VENDOR_DIM_KNOWN"])
    dimLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

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
        dimLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end)
    dimKnownRow:SetScript("OnLeave", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        dimLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    end)

    state.junkPreviewPanel.dimKnownCheckBox = dimCheckBox

    local quickAddBtn = OneWoW_GUI:CreateButton(nil, state.junkPreviewPanel, ns.L["VENDOR_QUICK_ADD"], panelWidth - 16, 26)
    quickAddBtn:SetPoint("TOPLEFT", dimKnownRow, "BOTTOMLEFT", OneWoW_GUI:GetSpacing("SM"), -OneWoW_GUI:GetSpacing("XS"))
    quickAddBtn:SetPoint("TOPRIGHT", dimKnownRow, "BOTTOMRIGHT", -OneWoW_GUI:GetSpacing("SM"), -OneWoW_GUI:GetSpacing("XS"))
    quickAddBtn:SetScript("OnClick", function() VendorPanel:ToggleFiltersDialog() end)
    quickAddBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
        self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(ns.L["VENDOR_QUICK_ADD_FILTERS"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:AddLine(ns.L["UI_VENDOR_FILTER_HINT"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    quickAddBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
        self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
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

    local bottomCloseBtn = OneWoW_GUI:CreateButton(nil, state.junkPreviewPanel, ns.L["VENDOR_CLOSE"], 85, 28)
    bottomCloseBtn:SetPoint("BOTTOMLEFT", state.junkPreviewPanel, "BOTTOMLEFT", OneWoW_GUI:GetSpacing("SM"), 12)
    bottomCloseBtn:SetScript("OnClick", function()
        state.junkPreviewPanel.manuallyHidden = true
        state.junkPreviewPanel:Hide()
        if state.filtersDialog then state.filtersDialog:Hide() end
        VendorPanel:ManageBlizzardSellButton(false)
        VendorPanel:UpdatePanelToggleButton()
    end)
    local origCloseEnter = bottomCloseBtn:GetScript("OnEnter")
    bottomCloseBtn:SetScript("OnEnter", function(self)
        if origCloseEnter then origCloseEnter(self) end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(ns.L["VENDOR_CLOSE_PANEL"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:AddLine(ns.L["VENDOR_HIDES_PANEL"], 1, 1, 1, true)
        GameTooltip:AddLine(ns.L["VENDOR_USE_TOGGLE"], OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        GameTooltip:Show()
    end)
    bottomCloseBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
        self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
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

    local destroyButton = OneWoW_GUI:CreateButton(nil, state.junkPreviewPanel, string.format(ns.L["VENDOR_DESTROY_COUNT"], 0), 110, 28)
    destroyButton:SetPoint("LEFT", bottomCloseBtn, "RIGHT", 3, 0)
    destroyButton.text:SetTextColor(1, 0.5, 0.5, 1)
    destroyButton.fontString = destroyButton.text
    destroyButton:SetScript("OnClick", function() VendorPanel:DestroyNextJunkItem() end)
    destroyButton:SetScript("OnEnter", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(ns.L["VENDOR_DESTROY_NEXT"], 1, 0.3, 0.3)
        GameTooltip:AddLine(ns.L["VENDOR_DESTROY_NO_PRICE"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    destroyButton:SetScript("OnLeave", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
        GameTooltip:Hide()
    end)
    state.junkPreviewPanel.destroyButton = destroyButton

    local sellJunkButton = OneWoW_GUI:CreateButton(nil, state.junkPreviewPanel, string.format(ns.L["VENDOR_SELL_COUNT"], 0), 110, 28)
    sellJunkButton:SetPoint("LEFT", destroyButton, "RIGHT", 3, 0)
    sellJunkButton.fontString = sellJunkButton.text
    sellJunkButton:SetScript("OnClick", function()
        VendorPanel:SellJunkItems()
        C_Timer.After(0.5, function() VendorPanel:UpdateButton(); VendorPanel:UpdatePreviewPanel() end)
    end)
    sellJunkButton:SetScript("OnEnter", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
        self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(ns.L["VENDOR_SELL_JUNK_ITEMS"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:AddLine(ns.L["VENDOR_SELL_WITH_PRICE"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    sellJunkButton:SetScript("OnLeave", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
        self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
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

    state.filtersDialog = CreateFrame("Frame", "OneWoW_QoL_FiltersDialog", UIParent, "BackdropTemplate")
    state.filtersDialog:SetSize(200, 346)
    state.filtersDialog:SetFrameStrata("MEDIUM")
    state.filtersDialog:SetToplevel(true)
    if state.junkPreviewPanel then
        state.filtersDialog:SetFrameLevel(state.junkPreviewPanel:GetFrameLevel() + 1)
    end
    state.filtersDialog:SetClipsChildren(true)
    state.filtersDialog:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER)
    state.filtersDialog:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    state.filtersDialog:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    state.filtersDialog:EnableMouse(true)
    state.filtersDialog:SetMovable(true)
    state.filtersDialog:RegisterForDrag("LeftButton")
    state.filtersDialog:SetScript("OnDragStart", state.filtersDialog.StartMoving)
    state.filtersDialog:SetScript("OnDragStop", state.filtersDialog.StopMovingOrSizing)

    local titleBar = CreateFrame("Frame", nil, state.filtersDialog, "BackdropTemplate")
    titleBar:SetPoint("TOPLEFT", state.filtersDialog, "TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", state.filtersDialog, "TOPRIGHT", -1, -1)
    titleBar:SetHeight(20)
    titleBar:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_SIMPLE)
    titleBar:SetBackdropColor(OneWoW_GUI:GetThemeColor("TITLEBAR_BG"))
    titleBar:SetFrameLevel(state.filtersDialog:GetFrameLevel() + 1)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("LEFT", titleBar, "LEFT", OneWoW_GUI:GetSpacing("SM"), 0)
    titleText:SetText(ns.L["VENDOR_QUICK_ADD_FILTERS"])
    titleText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local closeBtn = OneWoW_GUI:CreateButton(nil, titleBar, "X", 20, 20)
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -OneWoW_GUI:GetSpacing("XS") / 2, 0)
    closeBtn:SetScript("OnClick", function() state.filtersDialog:Hide() end)

    local yOffset = -28

    local reagentsBtn = OneWoW_GUI:CreateButton(nil, state.filtersDialog, ns.L["VENDOR_REAGENTS"], 176, 26)
    reagentsBtn:SetPoint("TOP", state.filtersDialog, "TOP", 0, yOffset)
    reagentsBtn:SetScript("OnClick", function() VendorPanel:AddNonSoulboundReagents() end)
    reagentsBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
        self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(ns.L["UI_VENDOR_REAGENTS_TITLE"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:AddLine(ns.L["UI_VENDOR_REAGENTS"], 1, 1, 1, true)
        GameTooltip:AddLine(ns.L["UI_VENDOR_EXCLUDES"], OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        GameTooltip:Show()
    end)
    reagentsBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
        self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        GameTooltip:Hide()
    end)
    yOffset = yOffset - 28

    local consumablesBtn = OneWoW_GUI:CreateButton(nil, state.filtersDialog, ns.L["UI_VENDOR_CONSUMABLES_TITLE"], 176, 26)
    consumablesBtn:SetPoint("TOP", state.filtersDialog, "TOP", 0, yOffset)
    consumablesBtn:SetScript("OnClick", function() VendorPanel:AddConsumables() end)
    consumablesBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
        self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(ns.L["UI_VENDOR_CONSUMABLES_TITLE"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:AddLine(ns.L["UI_VENDOR_CONSUMABLES"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    consumablesBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
        self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        GameTooltip:Hide()
    end)
    yOffset = yOffset - 28

    local whiteBtn = OneWoW_GUI:CreateButton(nil, state.filtersDialog, ns.L["UI_VENDOR_WHITES_TITLE"], 176, 26)
    whiteBtn:SetPoint("TOP", state.filtersDialog, "TOP", 0, yOffset)
    whiteBtn:SetScript("OnClick", function() VendorPanel:AddWhiteQuality() end)
    whiteBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
        self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(ns.L["UI_VENDOR_WHITES_TITLE"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:AddLine(ns.L["UI_VENDOR_COMMONS"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    whiteBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
        self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        GameTooltip:Hide()
    end)
    yOffset = yOffset - 28

    local clearAllBtn = OneWoW_GUI:CreateButton(nil, state.filtersDialog, ns.L["UI_VENDOR_CLEAR_TITLE"], 176, 26)
    clearAllBtn:SetPoint("TOP", state.filtersDialog, "TOP", 0, yOffset)
    clearAllBtn:SetScript("OnClick", function()
        state.oneTimeItems.ilvlGear = {}; state.oneTimeItems.reagents = {}
        VendorPanel:UpdatePreviewPanel(); VendorPanel:UpdateButton()
        print("OneWoW QoL: Cleared all one-time items from sell list.")
    end)
    clearAllBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
        self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(ns.L["UI_VENDOR_CLEAR_TITLE"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:AddLine(ns.L["UI_VENDOR_REMOVE_CATEGORIES"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    clearAllBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
        self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        GameTooltip:Hide()
    end)
    yOffset = yOffset - 30

    local divider = state.filtersDialog:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("LEFT", state.filtersDialog, "LEFT", 12, yOffset)
    divider:SetPoint("RIGHT", state.filtersDialog, "RIGHT", -12, yOffset)
    divider:SetHeight(1)
    divider:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    yOffset = yOffset - 18

    local ilvlLabel = state.filtersDialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ilvlLabel:SetPoint("TOP", state.filtersDialog, "TOP", 0, yOffset)
    ilvlLabel:SetText("Add Gear Below iLvl")
    ilvlLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - 22

    local ilvlEditBox = CreateFrame("EditBox", nil, state.filtersDialog, "BackdropTemplate")
    ilvlEditBox:SetSize(60, 22)
    ilvlEditBox:SetPoint("TOP", state.filtersDialog, "TOP", -35, yOffset)
    ilvlEditBox:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER)
    ilvlEditBox:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    ilvlEditBox:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    ilvlEditBox:SetFontObject(GameFontHighlight)
    ilvlEditBox:SetAutoFocus(false)
    ilvlEditBox:SetNumeric(true)
    ilvlEditBox:SetMaxLetters(4)
    ilvlEditBox:EnableMouse(true)
    ilvlEditBox:SetTextInsets(OneWoW_GUI:GetSpacing("SM"), OneWoW_GUI:GetSpacing("SM"), 0, 0)
    ilvlEditBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    ilvlEditBox:SetScript("OnEditFocusGained", function(self)
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
    end)
    ilvlEditBox:SetScript("OnEditFocusLost", function(self)
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    end)
    ilvlEditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    state.filtersDialog.ilvlEditBox = ilvlEditBox

    local ilvlBtn = OneWoW_GUI:CreateButton(nil, state.filtersDialog, "Add", 60, 26)
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

    local excludeIlvl1 = CreateFrame("CheckButton", nil, state.filtersDialog, "UICheckButtonTemplate")
    excludeIlvl1:SetPoint("TOP", state.filtersDialog, "TOP", -45, yOffset)
    excludeIlvl1:SetSize(20, 20)
    excludeIlvl1:SetChecked(true)
    state.filtersDialog.excludeIlvl1 = excludeIlvl1

    local excludeLabel = state.filtersDialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    excludeLabel:SetPoint("LEFT", excludeIlvl1, "RIGHT", 2, 0)
    excludeLabel:SetText("Skip iLvl 1 items")
    excludeLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - 26

    local showBlizzJunk = CreateFrame("CheckButton", nil, state.filtersDialog, "UICheckButtonTemplate")
    showBlizzJunk:SetPoint("TOP", state.filtersDialog, "TOP", -45, yOffset)
    showBlizzJunk:SetSize(20, 20)
    showBlizzJunk:SetChecked(GetShowBlizzJunk())
    showBlizzJunk:SetScript("OnClick", function(self)
        local db = _G.OneWoW_QoL.db.global.modules["vendorpanel"]
        if not db.toggles then db.toggles = {} end
        db.toggles.show_blizz_junk = self:GetChecked()
        VendorPanel:UpdatePreviewPanel()
    end)
    state.filtersDialog.showBlizzJunk = showBlizzJunk

    local blizzLabel = state.filtersDialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    blizzLabel:SetPoint("LEFT", showBlizzJunk, "RIGHT", 2, 0)
    blizzLabel:SetText(ns.L["VENDOR_SHOW_BLIZZ_JUNK"])
    blizzLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    showBlizzJunk:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(ns.L["VENDOR_SHOW_BLIZZ_JUNK"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:AddLine(ns.L["VENDOR_SHOW_BLIZZ_JUNK_TT"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    showBlizzJunk:SetScript("OnLeave", function() GameTooltip:Hide() end)
    yOffset = yOffset - 30

    local divider2 = state.filtersDialog:CreateTexture(nil, "ARTWORK")
    divider2:SetPoint("LEFT", state.filtersDialog, "LEFT", 12, yOffset)
    divider2:SetPoint("RIGHT", state.filtersDialog, "RIGHT", -12, yOffset)
    divider2:SetHeight(1)
    divider2:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    yOffset = yOffset - 26

    local neverSellBtn = OneWoW_GUI:CreateButton(nil, state.filtersDialog, "", 176, 26)
    neverSellBtn:SetPoint("TOP", state.filtersDialog, "TOP", 0, yOffset)
    neverSellBtn.text:SetText(string.format(ns.L["VENDOR_PROTECTED_ITEMS"] .. " (%d)", 0))
    state.filtersDialog.neverSellBtnText = neverSellBtn.text
    neverSellBtn:SetScript("OnClick", function() VendorPanel:ToggleNeverSellDialog() end)
    neverSellBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
        self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(ns.L["VENDOR_PROTECTED_ITEMS"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:AddLine(ns.L["VENDOR_VIEW_PROTECTED"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    neverSellBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
        self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        GameTooltip:Hide()
    end)

    state.filtersDialog:Hide()
end

function VendorPanel:CreateNeverSellDialog()
    if state.neverSellDialog then return end

    state.neverSellDialog = CreateFrame("Frame", "OneWoW_QoL_NeverSellDialog", UIParent, "BackdropTemplate")
    state.neverSellDialog:SetSize(350, 400)
    state.neverSellDialog:SetFrameStrata("MEDIUM")
    state.neverSellDialog:SetToplevel(true)
    state.neverSellDialog:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER)
    state.neverSellDialog:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    state.neverSellDialog:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    state.neverSellDialog:EnableMouse(true)
    state.neverSellDialog:SetMovable(true)
    state.neverSellDialog:RegisterForDrag("LeftButton")
    state.neverSellDialog:SetScript("OnDragStart", state.neverSellDialog.StartMoving)
    state.neverSellDialog:SetScript("OnDragStop", state.neverSellDialog.StopMovingOrSizing)

    local titleBar = OneWoW_GUI:CreateTitleBar(state.neverSellDialog, ns.L["VENDOR_PROTECTED_ITEMS"], {
        showBrand = true,
        factionTheme = GetFactionTheme(),
        onClose = function() state.neverSellDialog:Hide() end,
    })
    state.neverSellDialog:SetScript("OnShow", function()
        if titleBar.brandIcon then titleBar.brandIcon:SetTexture(GetBrandIcon()) end
    end)

    local scrollFrame = CreateFrame("ScrollFrame", nil, state.neverSellDialog, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", OneWoW_GUI:GetSpacing("SM"), -OneWoW_GUI:GetSpacing("XS"))
    scrollFrame:SetPoint("BOTTOMRIGHT", state.neverSellDialog, "BOTTOMRIGHT", -OneWoW_GUI:GetSpacing("SM"), 65)
    state.neverSellDialog.scrollFrame = scrollFrame

    OneWoW_GUI:StyleScrollBar(scrollFrame, { offset = -5 })

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(320, 1)
    scrollFrame:SetScrollChild(scrollChild)
    state.neverSellDialog.scrollChild = scrollChild

    local helpText = state.neverSellDialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    helpText:SetPoint("BOTTOM", state.neverSellDialog, "BOTTOM", 0, 48)
    helpText:SetText(ns.L["VENDOR_CLICK_UNPROTECT"])
    helpText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local closeDialogButton = OneWoW_GUI:CreateButton(nil, state.neverSellDialog, ns.L["VENDOR_CLOSE"], 100, 28)
    closeDialogButton:SetPoint("BOTTOM", state.neverSellDialog, "BOTTOM", 0, 12)
    closeDialogButton:SetScript("OnClick", function() state.neverSellDialog:Hide() end)

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

        local clearBtn = OneWoW_GUI:CreateButton(nil, headerFrame, ns.L["VENDOR_CLEAR_ALL"], 60, 20)
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
