local _, ns = ...
local L = ns.L

-- Each external module's locale strings live in its own scope (per-module locale
-- registered via module.lua/Define), not core ns.L. Resolve module-owned keys (module
-- title/description and toggle label/description/group) against that module's cached
-- scope view (`_view`, set by ModuleRegistry:Define).
local function ML(id, key)
    if not key then return key end
    local m = ns.ModuleRegistry:GetById(id)
    if not m then return key end
    return m._view[key]
end

local OneWoW_GUI = OneWoW_GUI

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

local PREVIEW_MAX_HEIGHT = 200
local PREVIEW_TEXTURE_BASE = "Interface\\AddOns\\OneWoW_QoL\\Modules\\external\\"
local PREVIEW_EXTENSIONS = { ".png", ".blp", ".tga" }

local selectedModuleId  = nil
local selectedRow       = nil
local modDetailsDialog  = nil
local modDetailsContent = nil

-- Session-only collapse memory for Features toggle cards (cleared on /reload).
local collapsedToggleCards = {}

local function QoLUiFavorites()
    local db = ns.db.global
    db.uiFavorites = db.uiFavorites or { features = {}, toggles = {} }
    db.uiFavorites.features = db.uiFavorites.features or {}
    db.uiFavorites.toggles = db.uiFavorites.toggles or {}
    return db.uiFavorites
end

local function IsQoLFeatureFavorite(id)
    local u = QoLUiFavorites()
    return u and id and u.features[id] == true
end

local function SetQoLFeatureFavorite(id, on)
    local u = QoLUiFavorites()
    if u and id then
        u.features[id] = on and true or nil
    end
end

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
                { text = CLOSE, onClick = function(dialog) dialog:Hide() end },
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
    modName:SetText(ML(module.id, module.title) or module.title)
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
    -- Module-owned markers left on the shared scroll child (ClearFrame only
    -- unparents children; it does not wipe custom keys).
    detailScrollChild._qibContainer = nil
    detailScrollChild.UpdateDetailHeight = nil

    -- Module CreateCustomDetail may parent frame extras onto rightStatusBar (e.g.
    -- AutoMount "Mount Status"). Hide those when rebuilding so they do not leak
    -- across modules. rightStatusText is a FontString region, not a child frame.
    local rightStatusBar = split.rightStatusBar
    if rightStatusBar then
        for _, child in ipairs({ rightStatusBar:GetChildren() }) do
            child:Hide()
        end
    end

    local yOffset = -10
    local hasDetails = module.author or module.contact or module.link

    local isEnabled = ns.ModuleRegistry:IsEnabled(module.id)
    local toggleBtnSets = {}
    local customRefreshCallbacks = {}
    local cardsHost
    local belowHost
    local updateDetailHeight

    local function registerRefresh(fn)
        tinsert(customRefreshCallbacks, function()
            fn()
            -- Custom detail may live on belowHost under toggle cards; remeasure
            -- the scroll child after module rebuilds (CardStack collapse/refresh).
            if belowHost then
                updateDetailHeight()
            end
        end)
    end

    local enableBtn, _ = OneWoW_GUI:CreateOnOffToggleButtons(detailScrollChild, {
        value = isEnabled,
        isEnabled = true,
        onLabel = L["FEATURES_ON"],
        offLabel = L["FEATURES_OFF"],
        onValueChange = function(newVal)
            if newVal and module.CanEnable and not module:CanEnable() then
                return false
            end
            ns.ModuleRegistry:SetEnabled(module.id, newVal)
            if module.id == "playmounts" then
                OneWoW.SettingsFeatureRegistry:SetEnabled("tooltips", "playermounts", newVal)
                ns.UI.RefreshTooltipsFeatureDot("playermounts", newVal)
            end
            isEnabled = newVal
            if selectedRow and selectedRow.dot then
                selectedRow.dot:SetStatus(newVal)
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
    })
    enableBtn:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -12, yOffset)

    local titleLabel = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleLabel:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
    titleLabel:SetPoint("TOPRIGHT", enableBtn, "TOPLEFT", -8, 0)
    titleLabel:SetJustifyH("LEFT")
    titleLabel:SetText(ML(module.id, module.title) or module.title)
    titleLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local headerHeight = math.max(titleLabel:GetStringHeight(), enableBtn:GetHeight())
    yOffset = yOffset - headerHeight - 8

    local catText = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    catText:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
    catText:SetText(L["FEATURES_CATEGORY_LABEL"] .. " " .. ns.L["CATEGORY_" .. (module.category or "UTILITY")])
    catText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    yOffset = yOffset - catText:GetStringHeight() - 4

    if hasDetails then
        local capturedModule = module
        local detailsLink = OneWoW_GUI:CreateTextLink(detailScrollChild, {
            text = L["FEATURES_DETAILS_BTN"],
            fontSize = 11,
            onClick = function() ShowModuleDetailsDialog(capturedModule) end,
        })
        detailsLink:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
        yOffset = yOffset - detailsLink:GetHeight() - 10
    else
        yOffset = yOffset - 8
    end

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
        descText:SetText(ML(module.id, module.description) or module.description)
        descText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        yOffset = yOffset - descText:GetStringHeight() - 16
    end

    local headerBottom = yOffset

    updateDetailHeight = function()
        local cardsH = cardsHost and cardsHost:GetHeight() or 0
        local belowH = belowHost and belowHost:GetHeight() or 0
        local gap = (cardsHost and belowHost) and 8 or 0
        local topChrome = math.abs(headerBottom)
        detailScrollChild:SetHeight(topChrome + cardsH + gap + belowH + 20)
        split.UpdateDetailThumb()
    end

    if module.toggles and #module.toggles > 0 then
        local hasGroups = false
        for _, t in ipairs(module.toggles) do
            if t.group and not t.detailOnly then
                hasGroups = true
                break
            end
        end

        local cards = {}
        if not hasGroups then
            local list = {}
            for _, t in ipairs(module.toggles) do
                if not t.detailOnly then
                    tinsert(list, t)
                end
            end
            if #list > 0 then
                tinsert(cards, {
                    key = module.id .. ":toggles",
                    title = L["FEATURES_TOGGLES_HEADER"],
                    toggles = list,
                })
            end
        else
            local lastGroup = nil
            local current = nil
            for _, t in ipairs(module.toggles) do
                if not t.detailOnly then
                    if t.group and t.group ~= lastGroup then
                        lastGroup = t.group
                        current = {
                            key = module.id .. ":group:" .. tostring(t.group),
                            title = ML(module.id, t.group) or t.group,
                            toggles = {},
                        }
                        tinsert(cards, current)
                    end
                    if not current then
                        current = {
                            key = module.id .. ":toggles",
                            title = L["FEATURES_TOGGLES_HEADER"],
                            toggles = {},
                        }
                        tinsert(cards, current)
                    end
                    tinsert(current.toggles, t)
                end
            end
        end

        if #cards > 0 then
            cardsHost = CreateFrame("Frame", nil, detailScrollChild)
            cardsHost:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 0, headerBottom)
            cardsHost:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", 0, headerBottom)

            local stack = OneWoW_GUI:CreateCardStack(cardsHost, {
                getCollapsed = function(key) return collapsedToggleCards[key] end,
                setCollapsed = function(key, collapsed) collapsedToggleCards[key] = collapsed end,
            })
            stack.OnRelayout = updateDetailHeight

            for _, cardDef in ipairs(cards) do
                local toggles = cardDef.toggles
                stack:AddCard(cardDef.key, cardDef.title, function(content, contentWidth)
                    local rowY = 0
                    for _, toggle in ipairs(toggles) do
                        local capturedToggle = toggle
                        local capturedModule = module
                        local currentVal = ns.ModuleRegistry:GetToggleValue(module.id, toggle.id)
                        local rowRefresh
                        rowY, rowRefresh = OneWoW_GUI:CreateToggleRow(content, {
                            yOffset = rowY,
                            contentWidth = contentWidth,
                            label = ML(module.id, toggle.label) or toggle.label,
                            description = toggle.description and (ML(module.id, toggle.description) or toggle.description) or nil,
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
                    return math.max(1, math.abs(rowY))
                end)
            end

            stack:Finish()
        end
    end

    if module.CreateCustomDetail then
        if cardsHost then
            belowHost = CreateFrame("Frame", nil, detailScrollChild)
            belowHost:SetPoint("TOPLEFT", cardsHost, "BOTTOMLEFT", 0, -8)
            belowHost:SetPoint("TOPRIGHT", cardsHost, "BOTTOMRIGHT", 0, -8)
            local customY = 0
            -- Nested CardStacks (e.g. Prey Sample Bar) call this from OnRelayout.
            belowHost.UpdateDetailHeight = updateDetailHeight
            customY = module:CreateCustomDetail(belowHost, customY, isEnabled, registerRefresh, split.rightStatusBar) or customY
            belowHost:SetHeight(math.max(1, math.abs(customY) + 20))
            updateDetailHeight()
        else
            yOffset = module:CreateCustomDetail(detailScrollChild, yOffset, isEnabled, registerRefresh, split.rightStatusBar) or yOffset
            detailScrollChild:SetHeight(math.abs(yOffset) + 20)
            split.UpdateDetailThumb()
        end
    elseif cardsHost then
        updateDetailHeight()
    else
        detailScrollChild:SetHeight(math.abs(yOffset) + 20)
        split.UpdateDetailThumb()
    end
end

local function BuildFeaturesList(split, filterText)
    local listScrollChild = split.listScrollChild
    OneWoW_GUI:ClearFrame(listScrollChild)
    selectedRow = nil
    split.featureRows = {}

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

    local favModules = {}
    for _, module in ipairs(allModules) do
        if IsQoLFeatureFavorite(module.id) then
            if not filter or (ML(module.id, module.title) or module.title):lower():find(filter, 1, true) then
                table.insert(favModules, module)
            end
        end
    end
    table.sort(favModules, function(a, b)
        return (ML(a.id, a.title) or a.title or "") < (ML(b.id, b.title) or b.title or "")
    end)

    if #favModules > 0 then
        local favLabel = listScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        favLabel:SetPoint("TOPLEFT", listScrollChild, "TOPLEFT", 8, yOffset)
        favLabel:SetPoint("TOPRIGHT", listScrollChild, "TOPRIGHT", -8, yOffset)
        favLabel:SetJustifyH("LEFT")
        favLabel:SetText(FAVORITES)
        favLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
        yOffset = yOffset - favLabel:GetStringHeight() - 4

        for _, module in ipairs(favModules) do
            local capturedModule = module
            shownCount = shownCount + 1
            local row = OneWoW_GUI:CreateListRowBasic(listScrollChild, {
                height = rowHeight,
                label = ML(module.id, module.title) or module.title,
                showDot = true,
                dotEnabled = ns.ModuleRegistry:IsEnabled(module.id),
                favoriteToggle = {
                    isFavorite = true,
                    size = 16,
                    tooltipTitle = L["FEATURES_FAVORITE_TT_TITLE"],
                    tooltipText = L["FEATURES_FAVORITE_TT_DESC"],
                    onChange = function(isFav)
                        SetQoLFeatureFavorite(capturedModule.id, isFav)
                        BuildFeaturesList(split, split.searchBox and split.searchBox:GetSearchText() or "")
                    end,
                },
                onClick = function(self)
                    if selectedRow and selectedRow ~= self then
                        selectedRow:SetActive(false)
                    end
                    selectedModuleId = capturedModule.id
                    selectedRow = self
                    ShowModuleDetail(split, capturedModule)
                    self:SetActive(true)
                end,
            })
            row:SetPoint("TOPLEFT", listScrollChild, "TOPLEFT", 4, yOffset)
            row:SetPoint("TOPRIGHT", listScrollChild, "TOPRIGHT", -4, yOffset)
            split.featureRows[capturedModule.id] = row

            yOffset = yOffset - rowHeight - 4
        end

        yOffset = yOffset - 8
    end

    for _, category in ipairs(categories) do
        local catModules = ns.ModuleRegistry:GetByCategory(category)
        local filteredModules = {}
        for _, module in ipairs(catModules) do
            if not IsQoLFeatureFavorite(module.id) then
                if not filter or (ML(module.id, module.title) or module.title):lower():find(filter, 1, true) then
                    table.insert(filteredModules, module)
                end
            end
        end

        if #filteredModules > 0 then
            local catLabel = listScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            catLabel:SetPoint("TOPLEFT", listScrollChild, "TOPLEFT", 8, yOffset)
            catLabel:SetPoint("TOPRIGHT", listScrollChild, "TOPRIGHT", -8, yOffset)
            catLabel:SetJustifyH("LEFT")
            catLabel:SetText(ns.L["CATEGORY_" .. category])
            catLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
            yOffset = yOffset - catLabel:GetStringHeight() - 4

            for _, module in ipairs(filteredModules) do
                local capturedModule = module
                shownCount = shownCount + 1
                local row = OneWoW_GUI:CreateListRowBasic(listScrollChild, {
                    height = rowHeight,
                    label = ML(module.id, module.title) or module.title,
                    showDot = true,
                    dotEnabled = ns.ModuleRegistry:IsEnabled(module.id),
                    favoriteToggle = {
                        isFavorite = false,
                        size = 16,
                        tooltipTitle = L["FEATURES_FAVORITE_TT_TITLE"],
                        tooltipText = L["FEATURES_FAVORITE_TT_DESC"],
                        onChange = function(isFav)
                            SetQoLFeatureFavorite(capturedModule.id, isFav)
                            BuildFeaturesList(split, split.searchBox and split.searchBox:GetSearchText() or "")
                        end,
                    },
                    onClick = function(self)
                        if selectedRow and selectedRow ~= self then
                            selectedRow:SetActive(false)
                        end
                        selectedModuleId = capturedModule.id
                        selectedRow = self
                        ShowModuleDetail(split, capturedModule)
                        self:SetActive(true)
                    end,
                })
                row:SetPoint("TOPLEFT", listScrollChild, "TOPLEFT", 4, yOffset)
                row:SetPoint("TOPRIGHT", listScrollChild, "TOPRIGHT", -4, yOffset)
                split.featureRows[capturedModule.id] = row

                yOffset = yOffset - rowHeight - 4
            end

            yOffset = yOffset - 8
        end
    end

    listScrollChild:SetHeight(math.abs(yOffset) + 10)
    split.UpdateListThumb()

    if split.leftStatusText then
        if filter then
            split.leftStatusText:SetText(string.format(L["TOGGLES_STATUS_FILTERED"], shownCount, totalCount))
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
        hideTitles = true,
    })
    ns.UI._featuresSplit = split

    if split.searchBox then
        split.searchBox:SetScript("OnTextChanged", function(self)
            BuildFeaturesList(split, self:GetSearchText())
        end)
    end

    C_Timer.After(0.1, function()
        BuildFeaturesList(split, "")
    end)
end

function ns.UI.SelectFeature(moduleId)
    if not moduleId then return end

    OneWoW.UI:Show("qol")
    -- Show("qol") only switches to the QoL module — it lands on whatever
    -- sub-tab was last viewed (Toggles, Settings, etc.). Force the
    -- features sub-tab so per-module detail panels are visible.
    OneWoW.UI:SelectSubTab("qol", "features")

    -- Retry-aware navigation: CreateFeaturesTab sets _featuresSplit
    -- immediately, but BuildFeaturesList populates featureRows on a 0.1s
    -- timer, so a fixed delay can race on the first open. Poll briefly until
    -- the row is available, then highlight it.
    local detailShown = false
    local attempts = 0
    local function trySelect()
        attempts = attempts + 1
        local split = ns.UI._featuresSplit
        if not split then
            if attempts < 20 then C_Timer.After(0.05, trySelect) end
            return
        end
        local module = ns.ModuleRegistry:GetById(moduleId)
        if not module then return end

        if not detailShown then
            selectedModuleId = module.id
            if selectedRow then selectedRow:SetActive(false) end
            selectedRow = nil
            ShowModuleDetail(split, module)
            detailShown = true
        end

        if split.featureRows and split.featureRows[moduleId] then
            selectedRow = split.featureRows[moduleId]
            selectedRow:SetActive(true)
        elseif attempts < 20 then
            C_Timer.After(0.05, trySelect)
        end
    end
    C_Timer.After(0.05, trySelect)
end
