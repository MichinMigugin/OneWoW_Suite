-- OneWoW_QoL Addon File
-- OneWoW_QoL/UI/t-features.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...
local L = ns.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

local selectedModuleId  = nil
local selectedRow       = nil
local modDetailsDialog  = nil
local modDetailsContent = nil

local function ShowDetailPlaceholder(detailScrollChild, message)
    OneWoW_GUI:ClearFrame(detailScrollChild)
    local placeholder = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    placeholder:SetPoint("TOP", detailScrollChild, "TOP", 0, -40)
    placeholder:SetWidth(detailScrollChild:GetWidth() - 20)
    placeholder:SetText(message)
    placeholder:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
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

local function CreateReadOnlyContactBox(parent, label, text, yOffset)
    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
    lbl:SetText(label)
    lbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    yOffset = yOffset - lbl:GetStringHeight() - 2

    local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    box:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
    box:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOffset)
    box:SetHeight(22)
    box:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    box:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    box:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    box:SetFontObject(GameFontHighlight)
    box:SetTextInsets(6, 6, 0, 0)
    box:SetAutoFocus(false)
    box:EnableMouse(true)
    box:SetText(text)
    box:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEditFocusGained", function(self)
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
        self:HighlightText()
    end)
    box:SetScript("OnEditFocusLost", function(self)
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    end)
    box:SetScript("OnMouseUp", function(self)
        self:SetFocus()
        self:HighlightText()
    end)
    return yOffset - 22 - 8
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
        dialog:SetBackdrop(BACKDROP_INNER_NO_INSETS)
        dialog:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
        dialog:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
        tinsert(UISpecialFrames, "OneWoW_QoL_ModuleDetails")

        local titleBar = OneWoW_GUI:CreateTitleBar(dialog, L["FEATURES_DETAILS_TITLE"], { height = 28 })

        local headerDiv = dialog:CreateTexture(nil, "ARTWORK")
        headerDiv:SetHeight(1)
        headerDiv:SetPoint("TOPLEFT", dialog, "TOPLEFT", 1, -29)
        headerDiv:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -1, -29)
        headerDiv:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

        local btnDiv = dialog:CreateTexture(nil, "ARTWORK")
        btnDiv:SetHeight(1)
        btnDiv:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 1, 46)
        btnDiv:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -1, 46)
        btnDiv:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

        local closeBtn = OneWoW_GUI:CreateButton(nil, dialog, L["CLOSE"], 120, 32)
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
    modName:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    yOffset = yOffset - modName:GetStringHeight() - 12

    if module.version then
        local verText = modDetailsContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        verText:SetPoint("TOPLEFT", modDetailsContent, "TOPLEFT", 0, yOffset)
        verText:SetText(L["FEATURES_VERSION_LABEL"] .. " " .. module.version)
        verText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        yOffset = yOffset - verText:GetStringHeight() - 6
    end

    if module.author then
        local authText = modDetailsContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        authText:SetPoint("TOPLEFT", modDetailsContent, "TOPLEFT", 0, yOffset)
        authText:SetText(L["FEATURES_AUTHOR_LABEL"] .. " " .. module.author)
        authText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        yOffset = yOffset - authText:GetStringHeight() - 6
    end

    if module.contact then
        yOffset = CreateReadOnlyContactBox(modDetailsContent, L["FEATURES_CONTACT_LABEL"], module.contact, yOffset)
    end

    if module.link then
        yOffset = CreateReadOnlyContactBox(modDetailsContent, L["FEATURES_LINK_LABEL"], module.link, yOffset)
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
    OneWoW_GUI:ClearFrame(detailScrollChild)

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
    titleLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    if hasDetails then
        local capturedModule = module
        local detailsBtn = OneWoW_GUI:CreateButton(nil, detailScrollChild, L["FEATURES_DETAILS_BTN"], 80, 24)
        detailsBtn:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -12, yOffset)
        detailsBtn:SetScript("OnClick", function() ShowModuleDetailsDialog(capturedModule) end)
    end

    yOffset = yOffset - titleLabel:GetStringHeight() - 8

    local catText = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    catText:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
    catText:SetText(L["FEATURES_CATEGORY_LABEL"] .. " " .. (ns.L["CATEGORY_" .. (module.category or "UTILITY")] or module.category))
    catText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    yOffset = yOffset - catText:GetStringHeight() - 12

    local divider = detailScrollChild:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
    divider:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -12, yOffset)
    divider:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    yOffset = yOffset - 12

    if module.description then
        local descText = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        descText:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
        descText:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -12, yOffset)
        descText:SetJustifyH("LEFT")
        descText:SetWordWrap(true)
        descText:SetSpacing(3)
        descText:SetText(ns.L[module.description] or module.description)
        descText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        yOffset = yOffset - descText:GetStringHeight() - 16
    end

    local isEnabled = ns.ModuleRegistry:IsEnabled(module.id)
    local toggleBtnSets = {}
    local customRefreshCallbacks = {}
    local function registerRefresh(fn) tinsert(customRefreshCallbacks, fn) end

    local statusLabelPrefix = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusLabelPrefix:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
    statusLabelPrefix:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    statusLabelPrefix:SetText("Status: ")

    local statusLabel = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusLabel:SetPoint("LEFT", statusLabelPrefix, "RIGHT", 0, 0)
    if isEnabled then
        statusLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
        statusLabel:SetText(L["FEATURES_ENABLED"])
    else
        statusLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
        statusLabel:SetText(L["FEATURES_DISABLED"])
    end

    local toggleBtn = OneWoW_GUI:CreateButton(nil, detailScrollChild, isEnabled and L["DISABLE"] or L["ENABLE"], 90, 24)
    toggleBtn:SetPoint("LEFT", statusLabel, "RIGHT", 12, 0)
    toggleBtn:SetScript("OnClick", function(self)
        local nowEnabled = ns.ModuleRegistry:IsEnabled(module.id)
        ns.ModuleRegistry:SetEnabled(module.id, not nowEnabled)
        nowEnabled = not nowEnabled
        if nowEnabled then
            statusLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
            statusLabel:SetText(L["FEATURES_ENABLED"])
        else
            statusLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
            statusLabel:SetText(L["FEATURES_DISABLED"])
        end
        self.text:SetText(nowEnabled and L["DISABLE"] or L["ENABLE"])
        if selectedRow and selectedRow.enabledDot then
            if nowEnabled then
                selectedRow.enabledDot:SetVertexColor(OneWoW_GUI:GetThemeColor("DOT_FEATURES_ENABLED"))
            else
                selectedRow.enabledDot:SetVertexColor(OneWoW_GUI:GetThemeColor("DOT_FEATURES_DISABLED"))
            end
        end

        if split.rightStatusText then
            local modName = ns.L[module.title] or module.title
            split.rightStatusText:SetText(modName .. (nowEnabled and " (" .. L["FEATURES_ENABLED"] .. ")" or " (" .. L["FEATURES_DISABLED"] .. ")"))
        end
        if split.leftStatusText then
            local filterText = split.searchBox and split.searchBox:GetText() or ""
            if filterText == L["SEARCH_HINT"] then filterText = "" end
            if #filterText == 0 then
                local allModules = ns.ModuleRegistry:GetAll()
                local enabledCount = 0
                for _, m in ipairs(allModules) do
                    if ns.ModuleRegistry:IsEnabled(m.id) then enabledCount = enabledCount + 1 end
                end
                split.leftStatusText:SetText(string.format(L["FEATURES_STATUS_ENABLED"], enabledCount, #allModules))
            end
        end

        for _, tbs in ipairs(toggleBtnSets) do
            local val = ns.ModuleRegistry:GetToggleValue(module.id, tbs.toggle.id)
            tbs.refresh(nowEnabled, val)
            if nowEnabled then
                tbs.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                tbs.statusPrefix:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                tbs.statusVal:SetText(val and L["FEATURES_ENABLED"] or L["FEATURES_DISABLED"])

                -- Use variable since multiple values can cause problems with SetTextColor() when a ternary is used
                local colorKey = val and "TEXT_FEATURES_ENABLED" or "TEXT_FEATURES_DISABLED"
                tbs.statusVal:SetTextColor(OneWoW_GUI:GetThemeColor(colorKey))
            else
                tbs.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                tbs.statusPrefix:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                tbs.statusVal:SetText(L["FEATURES_DISABLED"])
                tbs.statusVal:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            end
        end
        for _, fn in ipairs(customRefreshCallbacks) do fn() end
    end)

    yOffset = yOffset - 30 - 14

    if module.toggles and #module.toggles > 0 then
        local toggleHeader = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        toggleHeader:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
        toggleHeader:SetText(L["FEATURES_TOGGLES_HEADER"])
        toggleHeader:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
        yOffset = yOffset - toggleHeader:GetStringHeight() - 8

        local toggleDivider = detailScrollChild:CreateTexture(nil, "ARTWORK")
        toggleDivider:SetHeight(1)
        toggleDivider:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
        toggleDivider:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -12, yOffset)
        toggleDivider:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        yOffset = yOffset - 10

        for _, toggle in ipairs(module.toggles) do
            local capturedToggle = toggle
            local capturedModule = module
            local currentVal = ns.ModuleRegistry:GetToggleValue(module.id, toggle.id)

            local rowStatusVal = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            rowStatusVal:SetText(currentVal and L["FEATURES_ENABLED"] or L["FEATURES_DISABLED"])
            do
                -- Need to use a variable here since GetThemeColor() returns an unpacked table, which causes problems with SetTextColor() when a ternary is used
                local colorKey = currentVal and "TEXT_FEATURES_ENABLED" or "TEXT_FEATURES_DISABLED"
                rowStatusVal:SetTextColor(OneWoW_GUI:GetThemeColor(colorKey))
            end

            local onBtn, offBtn, refresh = OneWoW_GUI:CreateOnOffToggleButtons(
                detailScrollChild, yOffset,
                L["FEATURES_ON"], L["FEATURES_OFF"],
                50, 22, isEnabled, currentVal,
                function(newVal)
                    ns.ModuleRegistry:SetToggleValue(capturedModule.id, capturedToggle.id, newVal)
                    rowStatusVal:SetText(newVal and L["FEATURES_ENABLED"] or L["FEATURES_DISABLED"])
                    -- Need to use a variable here since GetThemeColor() returns an unpacked table, which causes problems with SetTextColor() when a ternary is used
                    local colorKey = newVal and "TEXT_FEATURES_ENABLED" or "TEXT_FEATURES_DISABLED"
                    rowStatusVal:SetTextColor(OneWoW_GUI:GetThemeColor(colorKey))
                end
            )

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
                toggleLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                rowStatusPfx:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            else
                toggleLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                rowStatusPfx:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                rowStatusVal:SetText(L["FEATURES_DISABLED"])
                rowStatusVal:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            end

            tinsert(toggleBtnSets, { onBtn = onBtn, offBtn = offBtn, refresh = refresh, label = toggleLabel, statusPrefix = rowStatusPfx, statusVal = rowStatusVal, toggle = capturedToggle })

            yOffset = yOffset - 22 - 4

            if toggle.description then
                local descText = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                descText:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
                descText:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -12, yOffset)
                descText:SetJustifyH("LEFT")
                descText:SetWordWrap(true)
                descText:SetText(ns.L[toggle.description] or toggle.description)
                descText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                yOffset = yOffset - descText:GetStringHeight() - 6
            end

            yOffset = yOffset - 10
        end
    end

    if module.CreateCustomDetail then
        yOffset = module:CreateCustomDetail(detailScrollChild, yOffset, isEnabled, registerRefresh) or yOffset
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
        placeholder:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
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
            catLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
            yOffset = yOffset - catLabel:GetStringHeight() - 4

            for _, module in ipairs(filteredModules) do
                local capturedModule = module
                shownCount = shownCount + 1
                local row = CreateFrame("Button", nil, listScrollChild, "BackdropTemplate")
                row:SetPoint("TOPLEFT", listScrollChild, "TOPLEFT", 4, yOffset)
                row:SetPoint("TOPRIGHT", listScrollChild, "TOPRIGHT", -4, yOffset)
                row:SetHeight(rowHeight)
                row:SetBackdrop(BACKDROP_INNER_NO_INSETS)
                row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

                local rowLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                rowLabel:SetPoint("LEFT", row, "LEFT", 10, 0)
                rowLabel:SetPoint("RIGHT", row, "RIGHT", -24, 0)
                rowLabel:SetJustifyH("LEFT")
                rowLabel:SetText(ns.L[module.title] or module.title)
                rowLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                row.rowLabel = rowLabel

                local enabledDot = row:CreateTexture(nil, "OVERLAY")
                enabledDot:SetSize(8, 8)
                enabledDot:SetPoint("RIGHT", row, "RIGHT", -8, 0)
                enabledDot:SetTexture("Interface\\Buttons\\WHITE8x8")
                if ns.ModuleRegistry:IsEnabled(module.id) then
                    enabledDot:SetVertexColor(OneWoW_GUI:GetThemeColor("DOT_FEATURES_ENABLED"))
                else
                    enabledDot:SetVertexColor(OneWoW_GUI:GetThemeColor("DOT_FEATURES_DISABLED"))
                end
                row.enabledDot = enabledDot

                row:SetScript("OnClick", function(self)
                    if selectedRow and selectedRow ~= self then
                        selectedRow:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                        selectedRow:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                        if selectedRow.rowLabel then
                            selectedRow.rowLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                        end
                    end
                    selectedModuleId = capturedModule.id
                    selectedRow = self
                    ShowModuleDetail(split, capturedModule)
                    self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
                    self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
                    rowLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
                    if split.rightStatusText then
                        local isEnabled = ns.ModuleRegistry:IsEnabled(capturedModule.id)
                        local modName = ns.L[capturedModule.title] or capturedModule.title
                        split.rightStatusText:SetText(modName .. (isEnabled and " (" .. L["FEATURES_ENABLED"] .. ")" or " (" .. L["FEATURES_DISABLED"] .. ")"))
                    end
                end)
                row:SetScript("OnEnter", function(self)
                    if selectedModuleId ~= capturedModule.id then
                        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
                        rowLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
                    end
                end)
                row:SetScript("OnLeave", function(self)
                    if selectedModuleId ~= capturedModule.id then
                        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                        rowLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
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
    local split = OneWoW_GUI:CreateSplitPanel(parent, { showSearch = true })

    split.listTitle:SetText(L["FEATURES_LIST_TITLE"])
    split.detailTitle:SetText(L["FEATURES_DETAIL_TITLE"])

    if split.searchBox then
        split.searchBox:SetText(L["SEARCH_HINT"])
        split.searchBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        split.searchBox:HookScript("OnEditFocusGained", function(self)
            if self:GetText() == L["SEARCH_HINT"] then
                self:SetText("")
                self:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end
        end)
        split.searchBox:HookScript("OnEditFocusLost", function(self)
            if self:GetText() == "" then
                self:SetText(L["SEARCH_HINT"])
                self:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
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
