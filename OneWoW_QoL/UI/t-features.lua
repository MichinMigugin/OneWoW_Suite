-- OneWoW_QoL Addon File
-- OneWoW_QoL/UI/t-features.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...
local L = ns.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

local PREVIEW_MAX_HEIGHT = 200
local PREVIEW_TEXTURE_BASE = "Interface\\AddOns\\OneWoW_QoL\\Modules\\external\\"
local PREVIEW_EXTENSIONS = { ".png", ".blp", ".tga" }

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
    OneWoW_GUI:ClearFrame(modDetailsContent)
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

local DETAILS_HEIGHT_DEFAULT = 280
local DETAILS_HEIGHT_PREVIEW = 470

local function ShowModuleDetailsDialog(module)
    if not modDetailsDialog then
        local result = OneWoW_GUI:CreateDialog({
            name = "OneWoW_QoL_ModuleDetails",
            title = L["FEATURES_DETAILS_TITLE"],
            width = 340,
            height = DETAILS_HEIGHT_DEFAULT,
            showScrollFrame = true,
            buttons = {
                { text = L["CLOSE"], onClick = function(dialog) dialog:Hide() end },
            },
        })

        modDetailsContent = result.scrollContent
        modDetailsDialog  = result.frame
    end

    ClearModDetailsContent()

    local hasPreviewImage = false
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

    if module.preview then
        local basePath = PREVIEW_TEXTURE_BASE .. module.id .. "\\preview"
        local resolvedPath = nil

        local probe = modDetailsContent:CreateTexture(nil, "BACKGROUND")
        probe:SetSize(1, 1)
        probe:SetAlpha(0)
        for _, ext in ipairs(PREVIEW_EXTENSIONS) do
            probe:SetTexture(basePath .. ext)
            if probe:GetTexture() then
                resolvedPath = basePath .. ext
                break
            end
        end
        probe:SetTexture(nil)
        probe:Hide()

        if resolvedPath then
            hasPreviewImage = true
            yOffset = yOffset - 4

            local previewLabel = modDetailsContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            previewLabel:SetPoint("TOPLEFT", modDetailsContent, "TOPLEFT", 0, yOffset)
            previewLabel:SetText(L["FEATURES_PREVIEW_LABEL"])
            previewLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            yOffset = yOffset - previewLabel:GetStringHeight() - 4

            local container = CreateFrame("Frame", nil, modDetailsContent, "BackdropTemplate")
            container:SetBackdrop(BACKDROP_INNER_NO_INSETS)
            container:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            container:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            container:SetPoint("TOPLEFT", modDetailsContent, "TOPLEFT", 0, yOffset)
            container:SetPoint("TOPRIGHT", modDetailsContent, "TOPRIGHT", 0, yOffset)
            container:SetHeight(PREVIEW_MAX_HEIGHT)

            local img = container:CreateTexture(nil, "ARTWORK")
            img:SetPoint("TOPLEFT", container, "TOPLEFT", 2, -2)
            img:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -2, 2)
            img:SetTexture(resolvedPath)
            img:SetTexCoord(0, 1, 0, 1)

            yOffset = yOffset - PREVIEW_MAX_HEIGHT - 8
        end
    end

    modDetailsContent:SetHeight(math.abs(yOffset) + 10)
    modDetailsDialog:SetHeight(hasPreviewImage and DETAILS_HEIGHT_PREVIEW or DETAILS_HEIGHT_DEFAULT)

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
        local detailsBtn = OneWoW_GUI:CreateFitTextButton(detailScrollChild, { text = L["FEATURES_DETAILS_BTN"], height = 24 })
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

    yOffset, _ = OneWoW_GUI:CreateToggleRow(detailScrollChild, {
        yOffset = yOffset,
        label = "",
        align = "left",
        value = isEnabled,
        isEnabled = true,
        onValueChange = function(newVal)
            ns.ModuleRegistry:SetEnabled(module.id, newVal)
            if module.id == "playmounts" and _G.OneWoW and _G.OneWoW.SettingsFeatureRegistry then
                _G.OneWoW.SettingsFeatureRegistry:SetEnabled("tooltips", "playermounts", newVal)
                if _G.OneWoW.GUI and _G.OneWoW.GUI.RefreshTooltipsFeatureDot then
                    _G.OneWoW.GUI:RefreshTooltipsFeatureDot("playermounts", newVal)
                end
            end
            isEnabled = newVal
            if selectedRow and selectedRow.dot then
                selectedRow.dot:SetStatus(newVal)
            end

            if split.rightStatusText then
                local modName = ns.L[module.title] or module.title
                split.rightStatusText:SetText(modName .. (newVal and " (" .. L["FEATURES_ENABLED"] .. ")" or " (" .. L["FEATURES_DISABLED"] .. ")"))
            end
            if split.leftStatusText then
                local filterText = split.searchBox and split.searchBox:GetSearchText() or ""
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
                tbs.refresh(newVal, val)
            end
            for _, fn in ipairs(customRefreshCallbacks) do fn() end
        end,
        onLabel = L["FEATURES_ON"],
        offLabel = L["FEATURES_OFF"],
    })

    if module.toggles and #module.toggles > 0 then
        local lastGroup = nil
        local hasGroups = false
        for _, t in ipairs(module.toggles) do
            if t.group then hasGroups = true; break end
        end

        if not hasGroups then
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
        end

        for _, toggle in ipairs(module.toggles) do
            if hasGroups and toggle.group and toggle.group ~= lastGroup then
                lastGroup = toggle.group
                if lastGroup ~= module.toggles[1].group then
                    yOffset = yOffset - 6
                end
                local groupHeader = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                groupHeader:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
                groupHeader:SetText(ns.L[toggle.group] or toggle.group)
                groupHeader:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
                yOffset = yOffset - groupHeader:GetStringHeight() - 8

                local groupDivider = detailScrollChild:CreateTexture(nil, "ARTWORK")
                groupDivider:SetHeight(1)
                groupDivider:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
                groupDivider:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -12, yOffset)
                groupDivider:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                yOffset = yOffset - 10
            end

            local capturedToggle = toggle
            local capturedModule = module
            local currentVal = ns.ModuleRegistry:GetToggleValue(module.id, toggle.id)

            local rowRefresh
            yOffset, rowRefresh, _ = OneWoW_GUI:CreateToggleRow(detailScrollChild, {
                yOffset = yOffset,
                label = ns.L[toggle.label] or toggle.label,
                description = toggle.description and (ns.L[toggle.description] or toggle.description) or nil,
                value = currentVal,
                isEnabled = isEnabled,
                onValueChange = function(newVal)
                    ns.ModuleRegistry:SetToggleValue(capturedModule.id, capturedToggle.id, newVal)
                end,
                onLabel = L["FEATURES_ON"],
                offLabel = L["FEATURES_OFF"],
                buttonWidth = 50,
            })

            tinsert(toggleBtnSets, { refresh = rowRefresh, toggle = capturedToggle })
        end
    end

    if module.CreateCustomDetail then
        yOffset = module:CreateCustomDetail(detailScrollChild, yOffset, isEnabled, registerRefresh, split.rightStatusBar) or yOffset
    end

    detailScrollChild:SetHeight(math.abs(yOffset) + 20)
    split.UpdateDetailThumb()
end

local function BuildFeaturesList(split, filterText)
    local listScrollChild = split.listScrollChild
    OneWoW_GUI:ClearFrame(listScrollChild)
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
                local row = OneWoW_GUI:CreateListRowBasic(listScrollChild, {
                    height = rowHeight,
                    label = ns.L[module.title] or module.title,
                    showDot = true,
                    dotEnabled = ns.ModuleRegistry:IsEnabled(module.id),
                    onClick = function(self)
                        if selectedRow and selectedRow ~= self then
                            selectedRow:SetActive(false)
                        end
                        selectedModuleId = capturedModule.id
                        selectedRow = self
                        ShowModuleDetail(split, capturedModule)
                        self:SetActive(true)
                        if split.rightStatusText then
                            local isEnabled = ns.ModuleRegistry:IsEnabled(capturedModule.id)
                            local modName = ns.L[capturedModule.title] or capturedModule.title
                            split.rightStatusText:SetText(modName .. (isEnabled and " (" .. L["FEATURES_ENABLED"] .. ")" or " (" .. L["FEATURES_DISABLED"] .. ")"))
                        end
                    end,
                })
                row:SetPoint("TOPLEFT", listScrollChild, "TOPLEFT", 4, yOffset)
                row:SetPoint("TOPRIGHT", listScrollChild, "TOPRIGHT", -4, yOffset)

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

function ns.UI.RefreshModuleDot(moduleId, value)
    if selectedModuleId == moduleId and selectedRow and selectedRow.dot then
        selectedRow.dot:SetStatus(value)
    end
end

function ns.UI.CreateFeaturesTab(parent)
    local split = OneWoW_GUI:CreateSplitPanel(parent, {
        showSearch = true,
        searchPlaceholder = L["SEARCH_HINT"],
    })

    split.listTitle:SetText(L["FEATURES_LIST_TITLE"])
    split.detailTitle:SetText(L["FEATURES_DETAIL_TITLE"])

    if split.searchBox then
        split.searchBox:SetScript("OnTextChanged", function(self)
            BuildFeaturesList(split, self:GetSearchText())
        end)
    end

    C_Timer.After(0.1, function()
        BuildFeaturesList(split, "")
    end)
end
