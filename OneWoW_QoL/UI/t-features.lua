-- OneWoW_QoL Addon File
-- OneWoW_QoL/UI/t-features.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...
local L = ns.L
local T = ns.T
local S = ns.S

local selectedModuleId  = nil
local selectedRow       = nil
local modDetailsDialog  = nil
local modDetailsContent = nil

local function ClearDetailPanel(detailScrollChild)
    for _, child in ipairs({ detailScrollChild:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end
    for _, child in ipairs({ detailScrollChild:GetRegions() }) do
        child:Hide()
    end
end

local function ShowDetailPlaceholder(detailScrollChild, message)
    ClearDetailPanel(detailScrollChild)
    local placeholder = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    placeholder:SetPoint("TOP", detailScrollChild, "TOP", 0, -40)
    placeholder:SetWidth(detailScrollChild:GetWidth() - 20)
    placeholder:SetText(message)
    placeholder:SetTextColor(T("TEXT_MUTED"))
    placeholder:SetJustifyH("CENTER")
    detailScrollChild:SetHeight(math.max(100, placeholder:GetStringHeight() + 60))
end

local function ClearModDetailsContent()
    if not modDetailsContent then return end
    for _, child in ipairs({ modDetailsContent:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end
    for _, region in ipairs({ modDetailsContent:GetRegions() }) do
        region:Hide()
    end
end

local function ShowModuleDetailsDialog(module)
    if not modDetailsDialog then
        local dialog = CreateFrame("Frame", "OneWoW_QoL_ModuleDetails", UIParent, "BackdropTemplate")
        dialog:SetSize(340, 280)
        dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        dialog:SetFrameStrata("DIALOG")
        dialog:SetToplevel(true)
        dialog:SetMovable(true)
        dialog:SetClampedToScreen(true)
        dialog:EnableMouse(true)
        dialog:RegisterForDrag("LeftButton")
        dialog:SetScript("OnDragStart", function(self) self:StartMoving() end)
        dialog:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        dialog:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        dialog:SetBackdropColor(T("BG_PRIMARY"))
        dialog:SetBackdropBorderColor(T("BORDER_DEFAULT"))
        tinsert(UISpecialFrames, "OneWoW_QoL_ModuleDetails")

        local titleBar = CreateFrame("Frame", nil, dialog, "BackdropTemplate")
        titleBar:SetPoint("TOPLEFT", dialog, "TOPLEFT", 1, -1)
        titleBar:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -1, -1)
        titleBar:SetHeight(28)
        titleBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        titleBar:SetBackdropColor(T("TITLEBAR_BG"))

        local titleBarText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        titleBarText:SetPoint("LEFT", titleBar, "LEFT", 12, 0)
        titleBarText:SetText(L["FEATURES_DETAILS_TITLE"])
        titleBarText:SetTextColor(T("ACCENT_PRIMARY"))

        local headerDiv = dialog:CreateTexture(nil, "ARTWORK")
        headerDiv:SetHeight(1)
        headerDiv:SetPoint("TOPLEFT", dialog, "TOPLEFT", 1, -29)
        headerDiv:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -1, -29)
        headerDiv:SetColorTexture(T("BORDER_SUBTLE"))

        local btnDiv = dialog:CreateTexture(nil, "ARTWORK")
        btnDiv:SetHeight(1)
        btnDiv:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 1, 46)
        btnDiv:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -1, 46)
        btnDiv:SetColorTexture(T("BORDER_SUBTLE"))

        local closeBtn = ns.UI.CreateButton(nil, dialog, L["CLOSE"], 120, 32)
        closeBtn:SetPoint("BOTTOM", dialog, "BOTTOM", 0, 8)
        closeBtn:SetScript("OnClick", function() dialog:Hide() end)

        local content = CreateFrame("Frame", nil, dialog)
        content:SetPoint("TOPLEFT", dialog, "TOPLEFT", 20, -38)
        content:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -20, -38)
        content:SetHeight(180)
        modDetailsContent = content
        modDetailsDialog  = dialog
    end

    ClearModDetailsContent()

    local yOffset = 0

    local modName = modDetailsContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    modName:SetPoint("TOPLEFT", modDetailsContent, "TOPLEFT", 0, yOffset)
    modName:SetPoint("TOPRIGHT", modDetailsContent, "TOPRIGHT", 0, yOffset)
    modName:SetJustifyH("CENTER")
    modName:SetText(ns.L[module.title] or module.title)
    modName:SetTextColor(T("ACCENT_PRIMARY"))
    yOffset = yOffset - modName:GetStringHeight() - 12

    if module.version then
        local verText = modDetailsContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        verText:SetPoint("TOPLEFT", modDetailsContent, "TOPLEFT", 0, yOffset)
        verText:SetText(L["FEATURES_VERSION_LABEL"] .. " " .. module.version)
        verText:SetTextColor(T("TEXT_SECONDARY"))
        yOffset = yOffset - verText:GetStringHeight() - 6
    end

    if module.author then
        local authText = modDetailsContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        authText:SetPoint("TOPLEFT", modDetailsContent, "TOPLEFT", 0, yOffset)
        authText:SetText(L["FEATURES_AUTHOR_LABEL"] .. " " .. module.author)
        authText:SetTextColor(T("TEXT_SECONDARY"))
        yOffset = yOffset - authText:GetStringHeight() - 6
    end

    if module.contact then
        local contactLbl = modDetailsContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        contactLbl:SetPoint("TOPLEFT", modDetailsContent, "TOPLEFT", 0, yOffset)
        contactLbl:SetText(L["FEATURES_CONTACT_LABEL"])
        contactLbl:SetTextColor(T("TEXT_SECONDARY"))
        yOffset = yOffset - contactLbl:GetStringHeight() - 2

        local contactBox = CreateFrame("EditBox", nil, modDetailsContent, "BackdropTemplate")
        contactBox:SetPoint("TOPLEFT", modDetailsContent, "TOPLEFT", 0, yOffset)
        contactBox:SetPoint("TOPRIGHT", modDetailsContent, "TOPRIGHT", 0, yOffset)
        contactBox:SetHeight(22)
        contactBox:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        contactBox:SetBackdropColor(T("BG_SECONDARY"))
        contactBox:SetBackdropBorderColor(T("BORDER_SUBTLE"))
        contactBox:SetFontObject(GameFontHighlight)
        contactBox:SetTextInsets(6, 6, 0, 0)
        contactBox:SetAutoFocus(false)
        contactBox:EnableMouse(true)
        contactBox:SetText(module.contact)
        contactBox:SetTextColor(T("TEXT_PRIMARY"))
        contactBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        contactBox:SetScript("OnEditFocusGained", function(self)
            self:SetBackdropBorderColor(T("BORDER_ACCENT"))
            self:HighlightText()
        end)
        contactBox:SetScript("OnEditFocusLost", function(self)
            self:SetBackdropBorderColor(T("BORDER_SUBTLE"))
        end)
        contactBox:SetScript("OnMouseUp", function(self)
            self:SetFocus()
            self:HighlightText()
        end)
        yOffset = yOffset - 22 - 8
    end

    if module.link then
        local linkLbl = modDetailsContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        linkLbl:SetPoint("TOPLEFT", modDetailsContent, "TOPLEFT", 0, yOffset)
        linkLbl:SetText(L["FEATURES_LINK_LABEL"])
        linkLbl:SetTextColor(T("TEXT_SECONDARY"))
        yOffset = yOffset - linkLbl:GetStringHeight() - 2

        local linkBox = CreateFrame("EditBox", nil, modDetailsContent, "BackdropTemplate")
        linkBox:SetPoint("TOPLEFT", modDetailsContent, "TOPLEFT", 0, yOffset)
        linkBox:SetPoint("TOPRIGHT", modDetailsContent, "TOPRIGHT", 0, yOffset)
        linkBox:SetHeight(22)
        linkBox:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        linkBox:SetBackdropColor(T("BG_SECONDARY"))
        linkBox:SetBackdropBorderColor(T("BORDER_SUBTLE"))
        linkBox:SetFontObject(GameFontHighlight)
        linkBox:SetTextInsets(6, 6, 0, 0)
        linkBox:SetAutoFocus(false)
        linkBox:EnableMouse(true)
        linkBox:SetText(module.link)
        linkBox:SetTextColor(T("TEXT_PRIMARY"))
        linkBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        linkBox:SetScript("OnEditFocusGained", function(self)
            self:SetBackdropBorderColor(T("BORDER_ACCENT"))
            self:HighlightText()
        end)
        linkBox:SetScript("OnEditFocusLost", function(self)
            self:SetBackdropBorderColor(T("BORDER_SUBTLE"))
        end)
        linkBox:SetScript("OnMouseUp", function(self)
            self:SetFocus()
            self:HighlightText()
        end)
        yOffset = yOffset - 22 - 8
    end

    modDetailsDialog:Show()
    modDetailsDialog:Raise()
end

local function ShowModuleDetail(split, module)
    local detailScrollChild = split.detailScrollChild
    local fw = split.detailScrollFrame:GetWidth()
    if fw > 0 then
        detailScrollChild:SetWidth(fw)
    end
    ClearDetailPanel(detailScrollChild)

    local yOffset = -10
    local hasDetails = module.author or module.contact or module.link

    local titleLabel = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleLabel:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
    if hasDetails then
        titleLabel:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -96, yOffset)
    else
        titleLabel:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -12, yOffset)
    end
    titleLabel:SetJustifyH("LEFT")
    titleLabel:SetText(ns.L[module.title] or module.title)
    titleLabel:SetTextColor(T("ACCENT_PRIMARY"))

    if hasDetails then
        local capturedModule = module
        local detailsBtn = ns.UI.CreateButton(nil, detailScrollChild, L["FEATURES_DETAILS_BTN"], 80, 24)
        detailsBtn:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -12, yOffset)
        detailsBtn:SetScript("OnClick", function() ShowModuleDetailsDialog(capturedModule) end)
    end

    yOffset = yOffset - titleLabel:GetStringHeight() - 8

    local catText = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    catText:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
    catText:SetText(L["FEATURES_CATEGORY_LABEL"] .. " " .. (ns.L["CATEGORY_" .. (module.category or "UTILITY")] or module.category))
    catText:SetTextColor(T("TEXT_SECONDARY"))
    yOffset = yOffset - catText:GetStringHeight() - 12

    local divider = detailScrollChild:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
    divider:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -12, yOffset)
    divider:SetColorTexture(T("BORDER_SUBTLE"))
    yOffset = yOffset - 12

    if module.description then
        local descText = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        descText:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
        descText:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -12, yOffset)
        descText:SetJustifyH("LEFT")
        descText:SetWordWrap(true)
        descText:SetSpacing(3)
        descText:SetText(ns.L[module.description] or module.description)
        descText:SetTextColor(T("TEXT_PRIMARY"))
        yOffset = yOffset - descText:GetStringHeight() - 16
    end

    local isEnabled = ns.ModuleRegistry:IsEnabled(module.id)
    local toggleBtnSets = {}

    local statusLabelPrefix = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusLabelPrefix:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
    statusLabelPrefix:SetTextColor(T("TEXT_PRIMARY"))
    statusLabelPrefix:SetText("Status: ")

    local statusLabel = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusLabel:SetPoint("LEFT", statusLabelPrefix, "RIGHT", 0, 0)
    if isEnabled then
        statusLabel:SetTextColor(0.2, 1, 0.2)
        statusLabel:SetText(L["FEATURES_ENABLED"])
    else
        statusLabel:SetTextColor(1, 0.2, 0.2)
        statusLabel:SetText(L["FEATURES_DISABLED"])
    end

    local toggleBtn = ns.UI.CreateButton(nil, detailScrollChild, isEnabled and L["DISABLE"] or L["ENABLE"], 90, 24)
    toggleBtn:SetPoint("LEFT", statusLabel, "RIGHT", 12, 0)
    toggleBtn:SetScript("OnClick", function(self)
        local nowEnabled = ns.ModuleRegistry:IsEnabled(module.id)
        ns.ModuleRegistry:SetEnabled(module.id, not nowEnabled)
        nowEnabled = not nowEnabled
        if nowEnabled then
            statusLabel:SetTextColor(0.2, 1, 0.2)
            statusLabel:SetText(L["FEATURES_ENABLED"])
        else
            statusLabel:SetTextColor(1, 0.2, 0.2)
            statusLabel:SetText(L["FEATURES_DISABLED"])
        end
        self.text:SetText(nowEnabled and L["DISABLE"] or L["ENABLE"])
        if selectedRow and selectedRow.enabledDot then
            if nowEnabled then
                selectedRow.enabledDot:SetVertexColor(0.35, 0.70, 0.35, 1.0)
            else
                selectedRow.enabledDot:SetVertexColor(0.70, 0.30, 0.30, 1.0)
            end
        end
        for _, tbs in ipairs(toggleBtnSets) do
            if nowEnabled then
                tbs.onBtn:EnableMouse(true)
                tbs.offBtn:EnableMouse(true)
                tbs.label:SetTextColor(T("TEXT_PRIMARY"))
                tbs.statusPrefix:SetTextColor(T("TEXT_PRIMARY"))
                local val = ns.ModuleRegistry:GetToggleValue(module.id, tbs.toggle.id)
                if val then
                    tbs.onBtn.isActive = true
                    tbs.offBtn.isActive = false
                    tbs.onBtn:SetBackdropColor(T("BG_ACTIVE"))
                    tbs.onBtn:SetBackdropBorderColor(T("BORDER_ACCENT"))
                    tbs.onBtn.text:SetTextColor(T("TEXT_ACCENT"))
                    tbs.offBtn:SetBackdropColor(T("BTN_NORMAL"))
                    tbs.offBtn:SetBackdropBorderColor(T("BTN_BORDER"))
                    tbs.offBtn.text:SetTextColor(T("TEXT_MUTED"))
                    tbs.statusVal:SetText(L["FEATURES_ENABLED"])
                    tbs.statusVal:SetTextColor(0.2, 1, 0.2)
                else
                    tbs.offBtn.isActive = true
                    tbs.onBtn.isActive = false
                    tbs.offBtn:SetBackdropColor(T("BG_ACTIVE"))
                    tbs.offBtn:SetBackdropBorderColor(T("BORDER_ACCENT"))
                    tbs.offBtn.text:SetTextColor(T("TEXT_ACCENT"))
                    tbs.onBtn:SetBackdropColor(T("BTN_NORMAL"))
                    tbs.onBtn:SetBackdropBorderColor(T("BTN_BORDER"))
                    tbs.onBtn.text:SetTextColor(T("TEXT_MUTED"))
                    tbs.statusVal:SetText(L["FEATURES_DISABLED"])
                    tbs.statusVal:SetTextColor(1, 0.2, 0.2)
                end
            else
                tbs.onBtn.isActive = false
                tbs.offBtn.isActive = false
                tbs.onBtn:EnableMouse(false)
                tbs.offBtn:EnableMouse(false)
                tbs.label:SetTextColor(T("TEXT_MUTED"))
                tbs.statusPrefix:SetTextColor(T("TEXT_MUTED"))
                tbs.statusVal:SetText(L["FEATURES_DISABLED"])
                tbs.statusVal:SetTextColor(T("TEXT_MUTED"))
                tbs.onBtn:SetBackdropColor(T("BG_SECONDARY"))
                tbs.onBtn:SetBackdropBorderColor(T("BORDER_SUBTLE"))
                tbs.onBtn.text:SetTextColor(T("TEXT_MUTED"))
                tbs.offBtn:SetBackdropColor(T("BG_SECONDARY"))
                tbs.offBtn:SetBackdropBorderColor(T("BORDER_SUBTLE"))
                tbs.offBtn.text:SetTextColor(T("TEXT_MUTED"))
            end
        end
    end)

    yOffset = yOffset - 30 - 14

    if module.toggles and #module.toggles > 0 then
        local toggleHeader = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        toggleHeader:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
        toggleHeader:SetText(L["FEATURES_TOGGLES_HEADER"])
        toggleHeader:SetTextColor(T("ACCENT_SECONDARY"))
        yOffset = yOffset - toggleHeader:GetStringHeight() - 8

        local toggleDivider = detailScrollChild:CreateTexture(nil, "ARTWORK")
        toggleDivider:SetHeight(1)
        toggleDivider:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
        toggleDivider:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -12, yOffset)
        toggleDivider:SetColorTexture(T("BORDER_SUBTLE"))
        yOffset = yOffset - 10

        for _, toggle in ipairs(module.toggles) do
            local capturedToggle = toggle
            local capturedModule = module
            local currentVal = ns.ModuleRegistry:GetToggleValue(module.id, toggle.id)

            local onBtn = ns.UI.CreateButton(nil, detailScrollChild, L["FEATURES_ON"], 50, 22)
            onBtn:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -12, yOffset)

            local offBtn = ns.UI.CreateButton(nil, detailScrollChild, L["FEATURES_OFF"], 50, 22)
            offBtn:SetPoint("RIGHT", onBtn, "LEFT", -4, 0)

            local rowStatusVal = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            rowStatusVal:SetPoint("RIGHT", offBtn, "LEFT", -6, 0)

            local rowStatusPfx = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            rowStatusPfx:SetPoint("RIGHT", rowStatusVal, "LEFT", -2, 0)
            rowStatusPfx:SetText("Status:")

            local toggleLabel = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            toggleLabel:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
            toggleLabel:SetPoint("RIGHT", rowStatusPfx, "LEFT", -8, 0)
            toggleLabel:SetJustifyH("LEFT")
            toggleLabel:SetText(ns.L[toggle.label] or toggle.label)

            if isEnabled then
                toggleLabel:SetTextColor(T("TEXT_PRIMARY"))
                rowStatusPfx:SetTextColor(T("TEXT_PRIMARY"))
                if currentVal then
                    onBtn.isActive = true
                    offBtn.isActive = false
                    onBtn:SetBackdropColor(T("BG_ACTIVE"))
                    onBtn:SetBackdropBorderColor(T("BORDER_ACCENT"))
                    onBtn.text:SetTextColor(T("TEXT_ACCENT"))
                    offBtn:SetBackdropColor(T("BTN_NORMAL"))
                    offBtn:SetBackdropBorderColor(T("BTN_BORDER"))
                    offBtn.text:SetTextColor(T("TEXT_MUTED"))
                    rowStatusVal:SetText(L["FEATURES_ENABLED"])
                    rowStatusVal:SetTextColor(0.2, 1, 0.2)
                else
                    offBtn.isActive = true
                    onBtn.isActive = false
                    offBtn:SetBackdropColor(T("BG_ACTIVE"))
                    offBtn:SetBackdropBorderColor(T("BORDER_ACCENT"))
                    offBtn.text:SetTextColor(T("TEXT_ACCENT"))
                    onBtn:SetBackdropColor(T("BTN_NORMAL"))
                    onBtn:SetBackdropBorderColor(T("BTN_BORDER"))
                    onBtn.text:SetTextColor(T("TEXT_MUTED"))
                    rowStatusVal:SetText(L["FEATURES_DISABLED"])
                    rowStatusVal:SetTextColor(1, 0.2, 0.2)
                end
            else
                onBtn.isActive = false
                offBtn.isActive = false
                toggleLabel:SetTextColor(T("TEXT_MUTED"))
                rowStatusPfx:SetTextColor(T("TEXT_MUTED"))
                rowStatusVal:SetText(L["FEATURES_DISABLED"])
                rowStatusVal:SetTextColor(T("TEXT_MUTED"))
                onBtn:EnableMouse(false)
                offBtn:EnableMouse(false)
                onBtn:SetBackdropColor(T("BG_SECONDARY"))
                onBtn:SetBackdropBorderColor(T("BORDER_SUBTLE"))
                onBtn.text:SetTextColor(T("TEXT_MUTED"))
                offBtn:SetBackdropColor(T("BG_SECONDARY"))
                offBtn:SetBackdropBorderColor(T("BORDER_SUBTLE"))
                offBtn.text:SetTextColor(T("TEXT_MUTED"))
            end

            local function applyToggleHover(btn)
                if btn.isActive then
                    btn:SetBackdropBorderColor(T("BORDER_FOCUS"))
                else
                    btn:SetBackdropColor(T("BTN_HOVER"))
                    btn:SetBackdropBorderColor(T("BTN_BORDER_HOVER"))
                    btn.text:SetTextColor(T("TEXT_SECONDARY"))
                end
            end
            local function applyToggleNormal(btn)
                if btn.isActive then
                    btn:SetBackdropColor(T("BG_ACTIVE"))
                    btn:SetBackdropBorderColor(T("BORDER_ACCENT"))
                    btn.text:SetTextColor(T("TEXT_ACCENT"))
                else
                    btn:SetBackdropColor(T("BTN_NORMAL"))
                    btn:SetBackdropBorderColor(T("BTN_BORDER"))
                    btn.text:SetTextColor(T("TEXT_MUTED"))
                end
            end
            onBtn:HookScript("OnEnter",   function(self) applyToggleHover(self)  end)
            onBtn:HookScript("OnLeave",   function(self) applyToggleNormal(self) end)
            onBtn:HookScript("OnMouseUp", function(self) applyToggleNormal(self) end)
            offBtn:HookScript("OnEnter",   function(self) applyToggleHover(self)  end)
            offBtn:HookScript("OnLeave",   function(self) applyToggleNormal(self) end)
            offBtn:HookScript("OnMouseUp", function(self) applyToggleNormal(self) end)

            tinsert(toggleBtnSets, { onBtn = onBtn, offBtn = offBtn, label = toggleLabel, statusPrefix = rowStatusPfx, statusVal = rowStatusVal, toggle = capturedToggle })

            onBtn:SetScript("OnClick", function(self)
                ns.ModuleRegistry:SetToggleValue(capturedModule.id, capturedToggle.id, true)
                onBtn.isActive = true
                offBtn.isActive = false
                self:SetBackdropColor(T("BG_ACTIVE"))
                self:SetBackdropBorderColor(T("BORDER_ACCENT"))
                self.text:SetTextColor(T("TEXT_ACCENT"))
                offBtn:SetBackdropColor(T("BTN_NORMAL"))
                offBtn:SetBackdropBorderColor(T("BTN_BORDER"))
                offBtn.text:SetTextColor(T("TEXT_MUTED"))
                rowStatusVal:SetText(L["FEATURES_ENABLED"])
                rowStatusVal:SetTextColor(0.2, 1, 0.2)
            end)
            offBtn:SetScript("OnClick", function(self)
                ns.ModuleRegistry:SetToggleValue(capturedModule.id, capturedToggle.id, false)
                offBtn.isActive = true
                onBtn.isActive = false
                self:SetBackdropColor(T("BG_ACTIVE"))
                self:SetBackdropBorderColor(T("BORDER_ACCENT"))
                self.text:SetTextColor(T("TEXT_ACCENT"))
                onBtn:SetBackdropColor(T("BTN_NORMAL"))
                onBtn:SetBackdropBorderColor(T("BTN_BORDER"))
                onBtn.text:SetTextColor(T("TEXT_MUTED"))
                rowStatusVal:SetText(L["FEATURES_DISABLED"])
                rowStatusVal:SetTextColor(1, 0.2, 0.2)
            end)

            yOffset = yOffset - 22 - 4

            if toggle.description then
                local descText = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                descText:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
                descText:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -12, yOffset)
                descText:SetJustifyH("LEFT")
                descText:SetWordWrap(true)
                descText:SetText(ns.L[toggle.description] or toggle.description)
                descText:SetTextColor(T("TEXT_MUTED"))
                yOffset = yOffset - descText:GetStringHeight() - 6
            end

            yOffset = yOffset - 10
        end
    end

    if module.CreateCustomDetail then
        yOffset = module:CreateCustomDetail(detailScrollChild, yOffset, isEnabled) or yOffset
    end

    detailScrollChild:SetHeight(math.abs(yOffset) + 20)
    split.UpdateDetailThumb()
end

local function BuildFeaturesList(split, filterText)
    local listScrollChild = split.listScrollChild
    for _, child in ipairs({ listScrollChild:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end
    for _, r in ipairs({ listScrollChild:GetRegions() }) do
        r:Hide()
    end
    selectedRow = nil

    local allModules = ns.ModuleRegistry:GetAll()
    if #allModules == 0 then
        local placeholder = listScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        placeholder:SetPoint("TOP", listScrollChild, "TOP", 0, -30)
        placeholder:SetWidth(listScrollChild:GetWidth() - 10)
        placeholder:SetText(L["FEATURES_EMPTY"])
        placeholder:SetTextColor(T("TEXT_MUTED"))
        placeholder:SetJustifyH("CENTER")
        listScrollChild:SetHeight(80)
        ShowDetailPlaceholder(split.detailScrollChild, L["FEATURES_EMPTY"])
        if split.leftStatusText then split.leftStatusText:SetText("") end
        return
    end

    local filter     = (filterText and #filterText > 0) and filterText:lower() or nil
    local shownCount = 0
    local totalCount = #allModules

    local yOffset = -5
    local categories = ns.ModuleRegistry:GetCategories()
    local rowHeight = 32

    for _, category in ipairs(categories) do
        local catModules = ns.ModuleRegistry:GetByCategory(category)
        local filteredModules = {}
        for _, module in ipairs(catModules) do
            if not filter or (ns.L[module.title] or module.title):lower():find(filter, 1, true) then
                table.insert(filteredModules, module)
            end
        end

        if #filteredModules > 0 then
            local catLabel = listScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            catLabel:SetPoint("TOPLEFT", listScrollChild, "TOPLEFT", 8, yOffset)
            catLabel:SetPoint("TOPRIGHT", listScrollChild, "TOPRIGHT", -8, yOffset)
            catLabel:SetJustifyH("LEFT")
            catLabel:SetText(ns.L["CATEGORY_" .. category] or category)
            catLabel:SetTextColor(T("ACCENT_SECONDARY"))
            yOffset = yOffset - catLabel:GetStringHeight() - 4

            for _, module in ipairs(filteredModules) do
                local capturedModule = module
                shownCount = shownCount + 1
                local row = CreateFrame("Button", nil, listScrollChild, "BackdropTemplate")
                row:SetPoint("TOPLEFT", listScrollChild, "TOPLEFT", 4, yOffset)
                row:SetPoint("TOPRIGHT", listScrollChild, "TOPRIGHT", -4, yOffset)
                row:SetHeight(rowHeight)
                row:SetBackdrop({
                    bgFile   = "Interface\\Buttons\\WHITE8x8",
                    edgeFile = "Interface\\Buttons\\WHITE8x8",
                    edgeSize = 1,
                })
                row:SetBackdropColor(T("BG_SECONDARY"))
                row:SetBackdropBorderColor(T("BORDER_SUBTLE"))

                local rowLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                rowLabel:SetPoint("LEFT", row, "LEFT", 10, 0)
                rowLabel:SetPoint("RIGHT", row, "RIGHT", -24, 0)
                rowLabel:SetJustifyH("LEFT")
                rowLabel:SetText(ns.L[module.title] or module.title)
                rowLabel:SetTextColor(T("TEXT_PRIMARY"))
                row.rowLabel = rowLabel

                local enabledDot = row:CreateTexture(nil, "OVERLAY")
                enabledDot:SetSize(8, 8)
                enabledDot:SetPoint("RIGHT", row, "RIGHT", -8, 0)
                enabledDot:SetTexture("Interface\\Buttons\\WHITE8x8")
                if ns.ModuleRegistry:IsEnabled(module.id) then
                    enabledDot:SetVertexColor(0.35, 0.70, 0.35, 1.0)
                else
                    enabledDot:SetVertexColor(0.70, 0.30, 0.30, 1.0)
                end
                row.enabledDot = enabledDot

                row:SetScript("OnClick", function(self)
                    if selectedRow and selectedRow ~= self then
                        selectedRow:SetBackdropColor(T("BG_SECONDARY"))
                        selectedRow:SetBackdropBorderColor(T("BORDER_SUBTLE"))
                        if selectedRow.rowLabel then
                            selectedRow.rowLabel:SetTextColor(T("TEXT_PRIMARY"))
                        end
                    end
                    selectedModuleId = capturedModule.id
                    selectedRow = self
                    ShowModuleDetail(split, capturedModule)
                    self:SetBackdropColor(T("BG_ACTIVE"))
                    self:SetBackdropBorderColor(T("BORDER_ACCENT"))
                    rowLabel:SetTextColor(T("TEXT_ACCENT"))
                    if split.rightStatusText then
                        local isEnabled = ns.ModuleRegistry:IsEnabled(capturedModule.id)
                        local modName = ns.L[capturedModule.title] or capturedModule.title
                        split.rightStatusText:SetText(modName .. (isEnabled and " (" .. L["FEATURES_ENABLED"] .. ")" or " (" .. L["FEATURES_DISABLED"] .. ")"))
                    end
                end)
                row:SetScript("OnEnter", function(self)
                    if selectedModuleId ~= capturedModule.id then
                        self:SetBackdropColor(T("BG_HOVER"))
                        rowLabel:SetTextColor(T("TEXT_ACCENT"))
                    end
                end)
                row:SetScript("OnLeave", function(self)
                    if selectedModuleId ~= capturedModule.id then
                        self:SetBackdropColor(T("BG_SECONDARY"))
                        rowLabel:SetTextColor(T("TEXT_PRIMARY"))
                    end
                end)

                yOffset = yOffset - rowHeight - 4
            end

            yOffset = yOffset - 8
        end
    end

    listScrollChild:SetHeight(math.abs(yOffset) + 10)
    split.UpdateListThumb()

    if split.leftStatusText then
        if filter then
            split.leftStatusText:SetText(string.format(L["FEATURES_STATUS_FILTERED"], shownCount, totalCount))
        else
            local enabledCount = 0
            for _, m in ipairs(allModules) do
                if ns.ModuleRegistry:IsEnabled(m.id) then enabledCount = enabledCount + 1 end
            end
            split.leftStatusText:SetText(string.format(L["FEATURES_STATUS_ENABLED"], enabledCount, totalCount))
        end
    end

    if not selectedModuleId then
        ShowDetailPlaceholder(split.detailScrollChild, L["FEATURES_NO_SELECTION"])
    end
end

function ns.UI.CreateFeaturesTab(parent)
    local split = ns.UI.CreateSplitPanel(parent, true)

    split.listTitle:SetText(L["FEATURES_LIST_TITLE"])
    split.detailTitle:SetText(L["FEATURES_DETAIL_TITLE"])

    if split.searchBox then
        split.searchBox:SetText(L["SEARCH_HINT"])
        split.searchBox:SetTextColor(T("TEXT_MUTED"))
        split.searchBox:HookScript("OnEditFocusGained", function(self)
            if self:GetText() == L["SEARCH_HINT"] then
                self:SetText("")
                self:SetTextColor(T("TEXT_PRIMARY"))
            end
        end)
        split.searchBox:HookScript("OnEditFocusLost", function(self)
            if self:GetText() == "" then
                self:SetText(L["SEARCH_HINT"])
                self:SetTextColor(T("TEXT_MUTED"))
            end
        end)
        split.searchBox:SetScript("OnTextChanged", function(self)
            local text = self:GetText()
            if text == L["SEARCH_HINT"] then text = "" end
            BuildFeaturesList(split, text)
        end)
    end

    C_Timer.After(0.1, function()
        BuildFeaturesList(split, "")
    end)
end
