local ADDON_NAME, OneWoW = ...

local GUI = OneWoW.GUI
local L    = OneWoW.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local BACKDROP_SIMPLE = OneWoW_GUI.Constants.BACKDROP_SIMPLE

local OVERLAY_SETTINGS_IDS = {
    consumables  = true,
    housingdecor = true,
    itemlevel    = true,
    junk         = true,
    knownitems   = true,
    mounts       = true,
    pets         = true,
    protected    = true,
    quest        = true,
    reagents     = true,
    recipe       = true,
    soulbound    = true,
    toys         = true,
    unknownitems = true,
    upgrade      = true,
    warbound     = true,
}

local POSITIONS = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }

local PositionOffsets = {
    TOPLEFT     = { 1, -1},
    TOPRIGHT    = {-1, -1},
    BOTTOMLEFT  = { 1,  1},
    BOTTOMRIGHT = {-1,  1},
    BOTTOM      = { 0,  1},
    TOP         = { 0, -1},
    LEFT        = { 1,  0},
    RIGHT       = {-1,  0},
    CENTER      = { 0,  0},
}

local PREVIEW_SLOT_SIZE = 74

local ICON_CATEGORIES = {
    {
        nameKey = "OVR_ICON_CAT_CUSTOM",
        icons   = {
            "icon-add", "icon-alert", "icon-alliance", "icon-compass", "icon-fav",
            "icon-flag", "icon-gears", "icon-horde", "icon-minus", "icon-mount",
            "icon-pet", "icon-pin", "icon-recipe", "icon-toy", "icon-trash",
        },
    },
    {
        nameKey = "OVR_ICON_CAT_MAP",
        icons   = {
            "VignetteKill", "VignetteEvent-SuperTracked",
            "map-icon-ignored-blueexclaimation", "map-icon-ignored-bluequestion",
            "UI-QuestPoiImportant-OuterGlow",
        },
    },
    {
        nameKey = "OVR_ICON_CAT_QUEST",
        icons   = {
            "Quest-Campaign-Available", "Quest-DailyCampaign-Available",
            "QuestArtifactTurnin", "QuestLegendary",
            "questlog-questtypeicon-lock", "questlog-questtypeicon-questfailed",
        },
    },
    {
        nameKey = "OVR_ICON_CAT_WAYPOINTS",
        icons   = {
            "poi-door-arrow-up", "poi-traveldirections-arrow", "talents-arrow-line-red",
        },
    },
    {
        nameKey = "OVR_ICON_CAT_BAGS",
        icons   = {
            "bags-junkcoin", "bags-newitem",
        },
    },
    {
        nameKey = "OVR_ICON_CAT_STATUS",
        icons   = {
            "groupfinder-icon-role-large-tank", "soulbinds_tree_conduit_icon_protect",
            "Bonus-Objective-Star", "collections-icon-favorites",
            "worldquest-icon-petbattle", "mechagon-projects", "ui-achievement-shield-2",
        },
    },
    {
        nameKey = "OVR_ICON_CAT_WARBAND",
        icons   = {
            "greatvault-dragonflight-32x32", "warband-completed-icon", "warbands-icon",
            "Warfronts-BaseMapIcons-Horde-Workshop-Minimap",
            "Warfronts-BaseMapIcons-Alliance-Workshop-Minimap",
        },
    },
    {
        nameKey = "OVR_ICON_CAT_HOUSING",
        icons   = {
            "shop-icon-housing-beds-selected", "shop-icon-housing-mounts-up",
            "shop-icon-housing-pets-selected", "Perks-ShoppingCart",
        },
    },
    {
        nameKey = "OVR_ICON_CAT_GLOWS",
        icons   = {
            "bags-glow-white", "bags-glow-purple", "bags-glow-blue",
            "bags-glow-green", "bags-glow-orange", "bags-glow-artifact",
            "bags-glow-heirloom",
        },
    },
}

local PICKER_MAX_HEIGHT = 220
local PICKER_ROW_HEIGHT = 24
local PICKER_HDR_HEIGHT = 22
local PICKER_ICON_SIZE  = 16

local function CreateIconPicker(parent, initialIcon, onChange)
    local currentSelected = initialIcon or "VignetteEvent-SuperTracked"

    local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    container:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    container:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    container:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local sbw = 10

    local scrollFrame = CreateFrame("ScrollFrame", nil, container)
    scrollFrame:SetPoint("TOPLEFT",     container, "TOPLEFT",     0,    0)
    scrollFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -sbw, 0)
    scrollFrame:EnableMouseWheel(true)

    local scrollBar = CreateFrame("Slider", nil, container, "BackdropTemplate")
    scrollBar:SetPoint("TOPLEFT",    scrollFrame, "TOPRIGHT",    0, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 0, 0)
    scrollBar:SetWidth(sbw)
    scrollBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    scrollBar:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    scrollBar:SetMinMaxValues(0, 1)
    scrollBar:SetValue(0)
    scrollBar:SetScript("OnValueChanged", function(_, value)
        scrollFrame:SetVerticalScroll(value)
    end)

    local thumb = scrollBar:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(8, 20)
    thumb:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    scrollBar:SetThumbTexture(thumb)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    scrollFrame:HookScript("OnSizeChanged", function(self, w)
        scrollChild:SetWidth(w)
    end)

    scrollFrame:SetScript("OnMouseWheel", function(self, direction)
        local cur = scrollFrame:GetVerticalScroll()
        local max = math.max(0, scrollChild:GetHeight() - scrollFrame:GetHeight())
        local new = math.max(0, math.min(max, cur - direction * 28))
        scrollFrame:SetVerticalScroll(new)
        scrollBar:SetValue(new)
    end)

    local catExpanded = {}
    local headers     = {}
    local allItemRows = {}

    for catIdx, cat in ipairs(ICON_CATEGORIES) do
        catExpanded[catIdx] = (catIdx == 1)

        local hdr = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
        hdr:SetHeight(PICKER_HDR_HEIGHT)
        hdr:SetBackdrop(BACKDROP_INNER_NO_INSETS)
        hdr:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        hdr:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        hdr:Hide()

        local hdrArrow = hdr:CreateTexture(nil, "OVERLAY")
        hdrArrow:SetSize(12, 12)
        hdrArrow:SetPoint("LEFT", hdr, "LEFT", 5, 0)
        if catIdx == 1 then
            hdrArrow:SetAtlas("UI-HUD-ActionBar-PageDownArrow-Up", false)
        else
            hdrArrow:SetAtlas("UI-HUD-ActionBar-PageNextButton-Up", false)
        end

        local hdrLabel = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hdrLabel:SetPoint("LEFT", hdr, "LEFT", 20, 0)
        hdrLabel:SetText(L[cat.nameKey] or cat.nameKey)
        hdrLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

        local catRows = {}
        for _, iconName in ipairs(cat.icons) do
            local row = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
            row:SetHeight(PICKER_ROW_HEIGHT)
            row:SetBackdrop(BACKDROP_SIMPLE)
            row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
            row:Hide()

            local icoFrame = CreateFrame("Frame", nil, row)
            icoFrame:SetSize(PICKER_ICON_SIZE, PICKER_ICON_SIZE)
            icoFrame:SetPoint("LEFT", row, "LEFT", 22, 0)
            local icoTex = icoFrame:CreateTexture(nil, "ARTWORK")
            icoTex:SetAllPoints(icoFrame)
            OneWoW.OverlayIcons:ApplyToTexture(icoTex, iconName)

            local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lbl:SetPoint("LEFT", icoFrame, "RIGHT", 5, 0)
            lbl:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            lbl:SetJustifyH("LEFT")
            lbl:SetText(OneWoW.OverlayIcons:GetDisplayName(iconName))
            lbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

            table.insert(catRows,    { iconName = iconName, frame = row, label = lbl })
            table.insert(allItemRows, { iconName = iconName, frame = row, label = lbl })
        end

        headers[catIdx] = { frame = hdr, arrow = hdrArrow, items = catRows }
    end

    local function LayoutPicker()
        local yPos = -2

        for catIdx, cat in ipairs(ICON_CATEGORIES) do
            local hdrData = headers[catIdx]
            local hdr     = hdrData.frame

            hdr:ClearAllPoints()
            hdr:SetPoint("TOPLEFT",  scrollChild, "TOPLEFT",  2, yPos)
            hdr:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -2, yPos)
            hdr:Show()
            yPos = yPos - (PICKER_HDR_HEIGHT + 2)

            if catExpanded[catIdx] then
                hdrData.arrow:SetAtlas("UI-HUD-ActionBar-PageDownArrow-Up", false)
            else
                hdrData.arrow:SetAtlas("UI-HUD-ActionBar-PageNextButton-Up", false)
            end

            for _, rowData in ipairs(hdrData.items) do
                if catExpanded[catIdx] then
                    rowData.frame:ClearAllPoints()
                    rowData.frame:SetPoint("TOPLEFT",  scrollChild, "TOPLEFT",  2, yPos)
                    rowData.frame:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -2, yPos)
                    rowData.frame:Show()
                    yPos = yPos - (PICKER_ROW_HEIGHT + 2)

                    if rowData.iconName == currentSelected then
                        rowData.frame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
                        rowData.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
                    else
                        rowData.frame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
                        rowData.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                    end
                else
                    rowData.frame:Hide()
                end
            end
        end

        local totalH = math.abs(yPos) + 4
        scrollChild:SetHeight(totalH)

        local frameH = math.min(PICKER_MAX_HEIGHT, math.max(PICKER_HDR_HEIGHT + 4, totalH))
        container:SetHeight(frameH)

        local maxScroll = math.max(0, totalH - frameH)
        scrollBar:SetMinMaxValues(0, maxScroll)
        if scrollFrame:GetVerticalScroll() > maxScroll then
            scrollFrame:SetVerticalScroll(maxScroll)
            scrollBar:SetValue(maxScroll)
        end
    end

    for catIdx in ipairs(ICON_CATEGORIES) do
        local capturedIdx = catIdx
        headers[catIdx].frame:SetScript("OnClick", function()
            catExpanded[capturedIdx] = not catExpanded[capturedIdx]
            LayoutPicker()
        end)
    end

    for _, rowData in ipairs(allItemRows) do
        local capturedName  = rowData.iconName
        local capturedFrame = rowData.frame
        local capturedLabel = rowData.label

        capturedFrame:SetScript("OnEnter", function(self)
            if capturedName ~= currentSelected then
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
                capturedLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
            end
        end)
        capturedFrame:SetScript("OnLeave", function(self)
            if capturedName ~= currentSelected then
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
                capturedLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end
        end)
        capturedFrame:SetScript("OnClick", function()
            currentSelected = capturedName
            LayoutPicker()
            onChange(capturedName)
        end)
    end

    LayoutPicker()
    return container
end

local function CreateSlotPreview(parent, featureId, reg)
    local SLOT_SIZE = PREVIEW_SLOT_SIZE

    local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    container:SetSize(SLOT_SIZE + 6, SLOT_SIZE + 6)
    container:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    container:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    container:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    local slotFrame = CreateFrame("Frame", nil, container, "BackdropTemplate")
    slotFrame:SetSize(SLOT_SIZE, SLOT_SIZE)
    slotFrame:SetPoint("CENTER", container, "CENTER", 0, 0)
    slotFrame:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    slotFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    slotFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    local itemTex = slotFrame:CreateTexture(nil, "ARTWORK")
    itemTex:SetPoint("TOPLEFT",     slotFrame, "TOPLEFT",     1, -1)
    itemTex:SetPoint("BOTTOMRIGHT", slotFrame, "BOTTOMRIGHT", -1,  1)
    itemTex:SetTexture("Interface\\Icons\\INV_Misc_Bag_07")

    local overlayFrame = CreateFrame("Frame", nil, slotFrame)
    overlayFrame:SetFrameLevel(slotFrame:GetFrameLevel() + 3)
    overlayFrame:EnableMouse(false)

    local overlayTex = overlayFrame:CreateTexture(nil, "OVERLAY", nil, 3)
    overlayTex:SetAllPoints(overlayFrame)

    local function Refresh()
        local icon     = reg:GetOverlaySetting(featureId, "icon")     or "VignetteEvent-SuperTracked"
        local position = reg:GetOverlaySetting(featureId, "position") or "TOPRIGHT"
        local scale    = reg:GetOverlaySetting(featureId, "scale")    or 1.0
        local alpha    = reg:GetOverlaySetting(featureId, "alpha")    or 1.0
        local offsets  = PositionOffsets[position] or {0, 0}
        local baseSize = SLOT_SIZE * 0.54
        local finalSize = baseSize * scale

        overlayFrame:ClearAllPoints()
        overlayFrame:SetPoint(position, slotFrame, position, offsets[1], offsets[2])
        overlayFrame:SetSize(finalSize, finalSize)
        OneWoW.OverlayIcons:ApplyToTexture(overlayTex, icon)
        overlayTex:SetAlpha(alpha)
        overlayFrame:Show()
    end

    Refresh()

    return container, Refresh
end

local function ShowGeneralDetail(split, dsc, selectedRow)
    local yOffset = -10

    local titleLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleLabel:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    titleLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    titleLabel:SetJustifyH("LEFT")
    titleLabel:SetText(L["OVR_GENERAL_TITLE"])
    titleLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    yOffset = yOffset - titleLabel:GetStringHeight() - 8

    local div = dsc:CreateTexture(nil, "ARTWORK")
    div:SetHeight(1)
    div:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    div:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    div:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    yOffset = yOffset - 12

    local descLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    descLabel:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    descLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    descLabel:SetJustifyH("LEFT")
    descLabel:SetWordWrap(true)
    descLabel:SetSpacing(3)
    descLabel:SetText(L["OVR_GENERAL_DESC"])
    descLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - descLabel:GetStringHeight() - 16

    local isEnabled = OneWoW.SettingsFeatureRegistry:IsEnabled("overlays", "general")

    local statusPrefix = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusPrefix:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    statusPrefix:SetText(L["FEATURE_STATUS_LABEL"])
    statusPrefix:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local statusValue = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusValue:SetPoint("LEFT", statusPrefix, "RIGHT", 4, 0)
    if isEnabled then
        statusValue:SetText(L["FEATURE_ENABLED"])
        statusValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
    else
        statusValue:SetText(L["FEATURE_DISABLED"])
        statusValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
    end

    local toggleBtn = OneWoW_GUI:CreateButton(nil, dsc, isEnabled and L["FEATURE_DISABLE_BTN"] or L["FEATURE_ENABLE_BTN"], 90, 24)
    toggleBtn:SetPoint("LEFT", statusValue, "RIGHT", 12, 0)
    toggleBtn:SetScript("OnClick", function(self)
        local nowEnabled = OneWoW.SettingsFeatureRegistry:IsEnabled("overlays", "general")
        OneWoW.SettingsFeatureRegistry:SetEnabled("overlays", "general", not nowEnabled)
        nowEnabled = not nowEnabled
        if nowEnabled then
            statusValue:SetText(L["FEATURE_ENABLED"])
            statusValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
        else
            statusValue:SetText(L["FEATURE_DISABLED"])
            statusValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
        end
        self.text:SetText(nowEnabled and L["FEATURE_DISABLE_BTN"] or L["FEATURE_ENABLE_BTN"])
        if selectedRow and selectedRow.dot then
            selectedRow.dot:SetStatus(nowEnabled)
        end
    end)

    yOffset = yOffset - 30 - 20

    local noteLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    noteLabel:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    noteLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    noteLabel:SetJustifyH("LEFT")
    noteLabel:SetWordWrap(true)
    noteLabel:SetSpacing(3)
    noteLabel:SetText(L["OVR_GENERAL_NOTE"])
    noteLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    yOffset = yOffset - noteLabel:GetStringHeight() - 20

    local intDiv = dsc:CreateTexture(nil, "ARTWORK")
    intDiv:SetHeight(1)
    intDiv:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    intDiv:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    intDiv:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    yOffset = yOffset - 14

    local intHeader = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    intHeader:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    intHeader:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    intHeader:SetJustifyH("LEFT")
    intHeader:SetText(L["OVR_INTEGRATIONS_HEADER"])
    intHeader:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    yOffset = yOffset - intHeader:GetStringHeight() - 6

    local intDesc = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    intDesc:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    intDesc:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    intDesc:SetJustifyH("LEFT")
    intDesc:SetWordWrap(true)
    intDesc:SetSpacing(3)
    intDesc:SetText(L["OVR_INTEGRATIONS_DESC"])
    intDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    yOffset = yOffset - intDesc:GetStringHeight() - 10

    local arkDetected  = C_AddOns.IsAddOnLoaded("ArkInventory")
    local ovDB         = OneWoW.db and OneWoW.db.global and OneWoW.db.global.settings and OneWoW.db.global.settings.overlays
    local arkEnabled   = not (ovDB and ovDB.integrations and ovDB.integrations.arkinventory and ovDB.integrations.arkinventory.enabled == false)

    local arkRow = CreateFrame("Frame", nil, dsc, "BackdropTemplate")
    arkRow:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    arkRow:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    arkRow:SetHeight(30)
    arkRow:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    arkRow:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    arkRow:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local arkName = arkRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    arkName:SetPoint("LEFT", arkRow, "LEFT", 10, 0)
    arkName:SetText("ArkInventory")
    arkName:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local arkStatusLabel = arkRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    arkStatusLabel:SetPoint("LEFT", arkName, "RIGHT", 16, 0)
    arkStatusLabel:SetText(L["FEATURE_STATUS_LABEL"])
    arkStatusLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local arkStatusValue = arkRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    arkStatusValue:SetPoint("LEFT", arkStatusLabel, "RIGHT", 4, 0)

    if not arkDetected then
        arkStatusValue:SetText(L["OVR_INT_NOT_DETECTED"])
        arkStatusValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    else
        if arkEnabled then
            arkStatusValue:SetText(L["OVR_INT_DETECTED"] .. " (" .. L["FEATURE_ENABLED"] .. ")")
            arkStatusValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
        else
            arkStatusValue:SetText(L["OVR_INT_DETECTED"] .. " (" .. L["FEATURE_DISABLED"] .. ")")
            arkStatusValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
        end

        local arkToggleBtn = OneWoW_GUI:CreateButton(nil, arkRow, arkEnabled and L["FEATURE_DISABLE_BTN"] or L["FEATURE_ENABLE_BTN"], 90, 22)
        arkToggleBtn:SetPoint("RIGHT", arkRow, "RIGHT", -6, 0)
        arkToggleBtn:SetScript("OnClick", function(self)
            local db = OneWoW.db.global.settings.overlays
            db.integrations = db.integrations or {}
            db.integrations.arkinventory = db.integrations.arkinventory or {}
            local nowEnabled = db.integrations.arkinventory.enabled ~= false
            db.integrations.arkinventory.enabled = not nowEnabled
            nowEnabled = not nowEnabled
            if nowEnabled then
                arkStatusValue:SetText(L["OVR_INT_DETECTED"] .. " (" .. L["FEATURE_ENABLED"] .. ")")
                arkStatusValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
            else
                arkStatusValue:SetText(L["OVR_INT_DETECTED"] .. " (" .. L["FEATURE_DISABLED"] .. ")")
                arkStatusValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
            end
            self.text:SetText(nowEnabled and L["FEATURE_DISABLE_BTN"] or L["FEATURE_ENABLE_BTN"])
            OneWoW.OverlayEngine:Refresh()
        end)
    end

    yOffset = yOffset - 34

    local bagDetected  = C_AddOns.IsAddOnLoaded("Baganator")
    local bagEnabled   = not (ovDB and ovDB.integrations and ovDB.integrations.baganator and ovDB.integrations.baganator.enabled == false)

    local bagRow = CreateFrame("Frame", nil, dsc, "BackdropTemplate")
    bagRow:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    bagRow:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    bagRow:SetHeight(30)
    bagRow:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    bagRow:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    bagRow:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local bagName = bagRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bagName:SetPoint("LEFT", bagRow, "LEFT", 10, 0)
    bagName:SetText("Baganator")
    bagName:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local bagStatusLabel = bagRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bagStatusLabel:SetPoint("LEFT", bagName, "RIGHT", 16, 0)
    bagStatusLabel:SetText(L["FEATURE_STATUS_LABEL"])
    bagStatusLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local bagStatusValue = bagRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bagStatusValue:SetPoint("LEFT", bagStatusLabel, "RIGHT", 4, 0)

    if not bagDetected then
        bagStatusValue:SetText(L["OVR_INT_NOT_DETECTED"])
        bagStatusValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    else
        if bagEnabled then
            bagStatusValue:SetText(L["OVR_INT_DETECTED"] .. " (" .. L["FEATURE_ENABLED"] .. ")")
            bagStatusValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
        else
            bagStatusValue:SetText(L["OVR_INT_DETECTED"] .. " (" .. L["FEATURE_DISABLED"] .. ")")
            bagStatusValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
        end

        local bagToggleBtn = OneWoW_GUI:CreateButton(nil, bagRow, bagEnabled and L["FEATURE_DISABLE_BTN"] or L["FEATURE_ENABLE_BTN"], 90, 22)
        bagToggleBtn:SetPoint("RIGHT", bagRow, "RIGHT", -6, 0)
        bagToggleBtn:SetScript("OnClick", function(self)
            local db = OneWoW.db.global.settings.overlays
            db.integrations = db.integrations or {}
            db.integrations.baganator = db.integrations.baganator or {}
            local nowEnabled = db.integrations.baganator.enabled ~= false
            db.integrations.baganator.enabled = not nowEnabled
            nowEnabled = not nowEnabled
            if nowEnabled then
                bagStatusValue:SetText(L["OVR_INT_DETECTED"] .. " (" .. L["FEATURE_ENABLED"] .. ")")
                bagStatusValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
            else
                bagStatusValue:SetText(L["OVR_INT_DETECTED"] .. " (" .. L["FEATURE_DISABLED"] .. ")")
                bagStatusValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
            end
            self.text:SetText(nowEnabled and L["FEATURE_DISABLE_BTN"] or L["FEATURE_ENABLE_BTN"])
            OneWoW.OverlayEngine:Refresh()
        end)
    end

    yOffset = yOffset - 34

    local bgnDetected = C_AddOns.IsAddOnLoaded("Bagnon")

    local bgnRow = CreateFrame("Frame", nil, dsc, "BackdropTemplate")
    bgnRow:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    bgnRow:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    bgnRow:SetHeight(30)
    bgnRow:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    bgnRow:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    bgnRow:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local bgnName = bgnRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bgnName:SetPoint("LEFT", bgnRow, "LEFT", 10, 0)
    bgnName:SetText("Bagnon")
    bgnName:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local bgnStatusLabel = bgnRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bgnStatusLabel:SetPoint("LEFT", bgnName, "RIGHT", 16, 0)
    bgnStatusLabel:SetText(L["FEATURE_STATUS_LABEL"])
    bgnStatusLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local bgnStatusValue = bgnRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bgnStatusValue:SetPoint("LEFT", bgnStatusLabel, "RIGHT", 4, 0)

    if not bgnDetected then
        bgnStatusValue:SetText(L["OVR_INT_NOT_DETECTED"])
        bgnStatusValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    else
        bgnStatusValue:SetText(L["OVR_INT_DETECTED"] .. " (" .. L["OVR_INT_NOT_COMPATIBLE"] .. ")")
        bgnStatusValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
    end

    yOffset = yOffset - 34

    local bbDetected = C_AddOns.IsAddOnLoaded("BetterBags")
    local bbEnabled  = not (ovDB and ovDB.integrations and ovDB.integrations.betterbags and ovDB.integrations.betterbags.enabled == false)

    local bbRow = CreateFrame("Frame", nil, dsc, "BackdropTemplate")
    bbRow:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    bbRow:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    bbRow:SetHeight(30)
    bbRow:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    bbRow:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    bbRow:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local bbName = bbRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bbName:SetPoint("LEFT", bbRow, "LEFT", 10, 0)
    bbName:SetText("BetterBags")
    bbName:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local bbStatusLabel = bbRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bbStatusLabel:SetPoint("LEFT", bbName, "RIGHT", 16, 0)
    bbStatusLabel:SetText(L["FEATURE_STATUS_LABEL"])
    bbStatusLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local bbStatusValue = bbRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bbStatusValue:SetPoint("LEFT", bbStatusLabel, "RIGHT", 4, 0)

    if not bbDetected then
        bbStatusValue:SetText(L["OVR_INT_NOT_DETECTED"])
        bbStatusValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    else
        if bbEnabled then
            bbStatusValue:SetText(L["OVR_INT_DETECTED"] .. " (" .. L["FEATURE_ENABLED"] .. ")")
            bbStatusValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
        else
            bbStatusValue:SetText(L["OVR_INT_DETECTED"] .. " (" .. L["FEATURE_DISABLED"] .. ")")
            bbStatusValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
        end

        local bbToggleBtn = OneWoW_GUI:CreateButton(nil, bbRow, bbEnabled and L["FEATURE_DISABLE_BTN"] or L["FEATURE_ENABLE_BTN"], 90, 22)
        bbToggleBtn:SetPoint("RIGHT", bbRow, "RIGHT", -6, 0)
        bbToggleBtn:SetScript("OnClick", function(self)
            local db = OneWoW.db.global.settings.overlays
            db.integrations = db.integrations or {}
            db.integrations.betterbags = db.integrations.betterbags or {}
            local nowEnabled = db.integrations.betterbags.enabled ~= false
            db.integrations.betterbags.enabled = not nowEnabled
            nowEnabled = not nowEnabled
            if nowEnabled then
                bbStatusValue:SetText(L["OVR_INT_DETECTED"] .. " (" .. L["FEATURE_ENABLED"] .. ")")
                bbStatusValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
            else
                bbStatusValue:SetText(L["OVR_INT_DETECTED"] .. " (" .. L["FEATURE_DISABLED"] .. ")")
                bbStatusValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
            end
            self.text:SetText(nowEnabled and L["FEATURE_DISABLE_BTN"] or L["FEATURE_ENABLE_BTN"])
            OneWoW.OverlayEngine:Refresh()
        end)
    end

    yOffset = yOffset - 34

    local owbDetected = C_AddOns.IsAddOnLoaded("OneWoW_Bags")
    local owbEnabled  = not (ovDB and ovDB.integrations and ovDB.integrations.onewow_bags and ovDB.integrations.onewow_bags.enabled == false)

    local owbRow = CreateFrame("Frame", nil, dsc, "BackdropTemplate")
    owbRow:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    owbRow:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    owbRow:SetHeight(30)
    owbRow:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    owbRow:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    owbRow:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local owbName = owbRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    owbName:SetPoint("LEFT", owbRow, "LEFT", 10, 0)
    owbName:SetText("OneWoW Bags")
    owbName:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local owbStatusLabel = owbRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    owbStatusLabel:SetPoint("LEFT", owbName, "RIGHT", 16, 0)
    owbStatusLabel:SetText(L["FEATURE_STATUS_LABEL"])
    owbStatusLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local owbStatusValue = owbRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    owbStatusValue:SetPoint("LEFT", owbStatusLabel, "RIGHT", 4, 0)

    if not owbDetected then
        owbStatusValue:SetText(L["OVR_INT_NOT_DETECTED"])
        owbStatusValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    else
        if owbEnabled then
            owbStatusValue:SetText(L["OVR_INT_DETECTED"] .. " (" .. L["FEATURE_ENABLED"] .. ")")
            owbStatusValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
        else
            owbStatusValue:SetText(L["OVR_INT_DETECTED"] .. " (" .. L["FEATURE_DISABLED"] .. ")")
            owbStatusValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
        end

        local owbToggleBtn = OneWoW_GUI:CreateButton(nil, owbRow, owbEnabled and L["FEATURE_DISABLE_BTN"] or L["FEATURE_ENABLE_BTN"], 90, 22)
        owbToggleBtn:SetPoint("RIGHT", owbRow, "RIGHT", -6, 0)
        owbToggleBtn:SetScript("OnClick", function(self)
            local db = OneWoW.db.global.settings.overlays
            db.integrations = db.integrations or {}
            db.integrations.onewow_bags = db.integrations.onewow_bags or {}
            local nowEnabled = db.integrations.onewow_bags.enabled ~= false
            db.integrations.onewow_bags.enabled = not nowEnabled
            nowEnabled = not nowEnabled
            if nowEnabled then
                owbStatusValue:SetText(L["OVR_INT_DETECTED"] .. " (" .. L["FEATURE_ENABLED"] .. ")")
                owbStatusValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
            else
                owbStatusValue:SetText(L["OVR_INT_DETECTED"] .. " (" .. L["FEATURE_DISABLED"] .. ")")
                owbStatusValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
            end
            self.text:SetText(nowEnabled and L["FEATURE_DISABLE_BTN"] or L["FEATURE_ENABLE_BTN"])
            OneWoW.OverlayEngine:Refresh()
        end)
    end

    yOffset = yOffset - 34

    local elvDetected = C_AddOns.IsAddOnLoaded("ElvUI")
    local elvEnabled  = not (ovDB and ovDB.integrations and ovDB.integrations.elvui and ovDB.integrations.elvui.enabled == false)

    local elvRow = CreateFrame("Frame", nil, dsc, "BackdropTemplate")
    elvRow:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    elvRow:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    elvRow:SetHeight(30)
    elvRow:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    elvRow:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    elvRow:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local elvName = elvRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    elvName:SetPoint("LEFT", elvRow, "LEFT", 10, 0)
    elvName:SetText("ElvUI")
    elvName:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local elvStatusLabel = elvRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    elvStatusLabel:SetPoint("LEFT", elvName, "RIGHT", 16, 0)
    elvStatusLabel:SetText(L["FEATURE_STATUS_LABEL"])
    elvStatusLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local elvStatusValue = elvRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    elvStatusValue:SetPoint("LEFT", elvStatusLabel, "RIGHT", 4, 0)

    if not elvDetected then
        elvStatusValue:SetText(L["OVR_INT_NOT_DETECTED"])
        elvStatusValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    else
        if elvEnabled then
            elvStatusValue:SetText(L["OVR_INT_DETECTED"] .. " (" .. L["FEATURE_ENABLED"] .. ")")
            elvStatusValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
        else
            elvStatusValue:SetText(L["OVR_INT_DETECTED"] .. " (" .. L["FEATURE_DISABLED"] .. ")")
            elvStatusValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
        end

        local elvToggleBtn = OneWoW_GUI:CreateButton(nil, elvRow, elvEnabled and L["FEATURE_DISABLE_BTN"] or L["FEATURE_ENABLE_BTN"], 90, 22)
        elvToggleBtn:SetPoint("RIGHT", elvRow, "RIGHT", -6, 0)
        elvToggleBtn:SetScript("OnClick", function(self)
            local db = OneWoW.db.global.settings.overlays
            db.integrations = db.integrations or {}
            db.integrations.elvui = db.integrations.elvui or {}
            local nowEnabled = db.integrations.elvui.enabled ~= false
            db.integrations.elvui.enabled = not nowEnabled
            nowEnabled = not nowEnabled
            if nowEnabled then
                elvStatusValue:SetText(L["OVR_INT_DETECTED"] .. " (" .. L["FEATURE_ENABLED"] .. ")")
                elvStatusValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
            else
                elvStatusValue:SetText(L["OVR_INT_DETECTED"] .. " (" .. L["FEATURE_DISABLED"] .. ")")
                elvStatusValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
            end
            self.text:SetText(nowEnabled and L["FEATURE_DISABLE_BTN"] or L["FEATURE_ENABLE_BTN"])
            OneWoW.OverlayEngine:Refresh()
        end)
    end

    yOffset = yOffset - 34

    dsc:SetHeight(math.abs(yOffset) + 20)
    GUI:ApplyFontToFrame(dsc)
    split.UpdateDetailThumb()
end

local function ShowOverlayDetail(split, feature, selectedRow)
    local dsc = split.detailScrollChild
    OneWoW_GUI:ClearFrame(dsc)

    local featureId = feature.id
    local reg       = OneWoW.SettingsFeatureRegistry

    if featureId == "general" then
        ShowGeneralDetail(split, dsc, selectedRow)
        return
    end

    local yOffset = -10

    local titleLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleLabel:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    titleLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    titleLabel:SetJustifyH("LEFT")
    titleLabel:SetText(L[feature.title] or feature.title)
    titleLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    yOffset = yOffset - titleLabel:GetStringHeight() - 8

    local div = dsc:CreateTexture(nil, "ARTWORK")
    div:SetHeight(1)
    div:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    div:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    div:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    yOffset = yOffset - 12

    local descLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    descLabel:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    descLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    descLabel:SetJustifyH("LEFT")
    descLabel:SetWordWrap(true)
    descLabel:SetSpacing(3)
    descLabel:SetText(L[feature.description] or feature.description)
    descLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - descLabel:GetStringHeight() - 16

    local isEnabled = reg:IsEnabled("overlays", featureId)

    local statusPrefix = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusPrefix:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    statusPrefix:SetText(L["FEATURE_STATUS_LABEL"])
    statusPrefix:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local statusValue = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusValue:SetPoint("LEFT", statusPrefix, "RIGHT", 4, 0)
    if isEnabled then
        statusValue:SetText(L["FEATURE_ENABLED"])
        statusValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
    else
        statusValue:SetText(L["FEATURE_DISABLED"])
        statusValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
    end

    local toggleBtn = OneWoW_GUI:CreateButton(nil, dsc, isEnabled and L["FEATURE_DISABLE_BTN"] or L["FEATURE_ENABLE_BTN"], 90, 24)
    toggleBtn:SetPoint("LEFT", statusValue, "RIGHT", 12, 0)
    toggleBtn:SetScript("OnClick", function(self)
        local nowEnabled = reg:IsEnabled("overlays", featureId)
        reg:SetEnabled("overlays", featureId, not nowEnabled)
        nowEnabled = not nowEnabled
        if nowEnabled then
            statusValue:SetText(L["FEATURE_ENABLED"])
            statusValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
        else
            statusValue:SetText(L["FEATURE_DISABLED"])
            statusValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
        end
        self.text:SetText(nowEnabled and L["FEATURE_DISABLE_BTN"] or L["FEATURE_ENABLE_BTN"])
        if selectedRow and selectedRow.dot then
            selectedRow.dot:SetStatus(nowEnabled)
        end
    end)

    yOffset = yOffset - 30 - 20

    if not OVERLAY_SETTINGS_IDS[featureId] then
        dsc:SetHeight(math.abs(yOffset) + 20)
        split.UpdateDetailThumb()
        return
    end

    local secDiv = dsc:CreateTexture(nil, "ARTWORK")
    secDiv:SetHeight(1)
    secDiv:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    secDiv:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    secDiv:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    yOffset = yOffset - 14

    if featureId == "quest" then
        local questNote = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        questNote:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
        questNote:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
        questNote:SetJustifyH("LEFT")
        questNote:SetWordWrap(true)
        questNote:SetSpacing(3)
        questNote:SetText(L["OVR_QUEST_NOTE"])
        questNote:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        yOffset = yOffset - questNote:GetStringHeight() - 16

        local vendorCb = OneWoW_GUI:CreateCheckbox(nil, dsc, L["OVR_VENDOR_LABEL"])
        vendorCb:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
        vendorCb:SetChecked(reg:GetOverlaySetting(featureId, "applyToVendorItems") or false)
        vendorCb:SetScript("OnClick", function(self)
            reg:SetOverlaySetting(featureId, "applyToVendorItems", self:GetChecked())
        end)
        yOffset = yOffset - 30

        local ahCb = OneWoW_GUI:CreateCheckbox(nil, dsc, L["OVR_AH_LABEL"])
        ahCb:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
        ahCb:SetChecked(reg:GetOverlaySetting(featureId, "applyToAuctionHouse") or false)
        ahCb:SetScript("OnClick", function(self)
            reg:SetOverlaySetting(featureId, "applyToAuctionHouse", self:GetChecked())
        end)
        yOffset = yOffset - 30 - 10

        dsc:SetHeight(math.abs(yOffset) + 20)
        split.UpdateDetailThumb()
        return
    end

    local settingsHdr = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    settingsHdr:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    settingsHdr:SetText(L["OVR_SETTINGS_HEADER"])
    settingsHdr:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    yOffset = yOffset - settingsHdr:GetStringHeight() - 10

    if featureId == "itemlevel" then
        local rightY = yOffset

        local posLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        posLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
        posLabel:SetText(L["OVR_POSITION_LABEL"])
        posLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        yOffset = yOffset - posLabel:GetStringHeight() - 6

        local currentPos = reg:GetOverlaySetting(featureId, "position") or "TOPRIGHT"
        local posDD, posDDText = OneWoW_GUI:CreateDropdown(dsc, { width = 160, text = currentPos })
        OneWoW_GUI:AttachFilterMenu(posDD, posDDText, {
            searchable = false,
            buildItems = function()
                local items = {}
                for _, opt in ipairs(POSITIONS) do
                    table.insert(items, { text = opt, value = opt })
                end
                return items
            end,
            onSelect = function(value, text)
                posDDText:SetText(text)
                reg:SetOverlaySetting(featureId, "position", value)
            end,
            getActiveValue = function() return reg:GetOverlaySetting(featureId, "position") end,
        })
        posDD:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
        yOffset = yOffset - 26 - 16

        local qualCb = OneWoW_GUI:CreateCheckbox(nil, dsc, L["OVR_QUALITY_COLORS_LABEL"])
        qualCb:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
        qualCb:SetChecked(reg:GetOverlaySetting(featureId, "useQualityColors") or false)
        qualCb:SetScript("OnClick", function(self)
            reg:SetOverlaySetting(featureId, "useQualityColors", self:GetChecked())
        end)
        yOffset = yOffset - 30 - 16

        local vendorCb2 = OneWoW_GUI:CreateCheckbox(nil, dsc, L["OVR_VENDOR_LABEL"])
        vendorCb2:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
        vendorCb2:SetChecked(reg:GetOverlaySetting(featureId, "applyToVendorItems") ~= false)
        vendorCb2:SetScript("OnClick", function(self)
            reg:SetOverlaySetting(featureId, "applyToVendorItems", self:GetChecked())
        end)
        yOffset = yOffset - 30

        local ahCb2 = OneWoW_GUI:CreateCheckbox(nil, dsc, L["OVR_AH_LABEL"])
        ahCb2:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
        ahCb2:SetChecked(reg:GetOverlaySetting(featureId, "applyToAuctionHouse") or false)
        ahCb2:SetScript("OnClick", function(self)
            reg:SetOverlaySetting(featureId, "applyToAuctionHouse", self:GetChecked())
        end)
        yOffset = yOffset - 30 - 16

        local fsLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fsLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
        fsLabel:SetText(L["OVR_FONTSIZE_LABEL"])
        fsLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        yOffset = yOffset - fsLabel:GetStringHeight() - 6

        local currentFS = reg:GetOverlaySetting(featureId, "fontSize") or 10
        local fsSlider = OneWoW_GUI:CreateSlider(dsc, 7, 20, 1, currentFS, function(val)
            reg:SetOverlaySetting(featureId, "fontSize", val)
        end, 240, "%d")
        fsSlider:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
        yOffset = yOffset - 36 - 10

        local LSM = LibStub("LibSharedMedia-3.0", true)
        local fontList = {}
        if LSM then
            fontList = LSM:List("font") or {}
        end
        table.sort(fontList)

        local fontLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fontLabel:SetPoint("TOPLEFT", dsc, "TOP", 20, rightY)
        fontLabel:SetText(L["OVR_FONT_LABEL"] or "Font")
        fontLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        rightY = rightY - fontLabel:GetStringHeight() - 6

        local currentFont = reg:GetOverlaySetting(featureId, "fontFamily") or "Friz Quadrata TF"
        local fontDD, fontDDText = OneWoW_GUI:CreateDropdown(dsc, { width = 240, text = currentFont })
        OneWoW_GUI:AttachFilterMenu(fontDD, fontDDText, {
            searchable = true,
            buildItems = function()
                local items = {}
                for _, name in ipairs(fontList) do
                    table.insert(items, { text = name, value = name })
                end
                return items
            end,
            onSelect = function(value, text)
                fontDDText:SetText(text)
                reg:SetOverlaySetting(featureId, "fontFamily", value)
                OneWoW.OverlayEngine:Refresh()
            end,
            getActiveValue = function() return reg:GetOverlaySetting(featureId, "fontFamily") end,
        })
        fontDD:SetPoint("TOPLEFT",  dsc, "TOP",      20,  rightY)
        fontDD:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, rightY)
        rightY = rightY - 26 - 16

        local outlineLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        outlineLabel:SetPoint("TOPLEFT", dsc, "TOP", 20, rightY)
        outlineLabel:SetText("Font Outline")
        outlineLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        rightY = rightY - outlineLabel:GetStringHeight() - 6

        local outlineOptions = {"None", "Outline", "Thick Outline"}
        local currentOutline = reg:GetOverlaySetting(featureId, "fontOutline") or "OUTLINE"
        local outlineDisplayMap = {[""] = "None", ["OUTLINE"] = "Outline", ["THICKOUTLINE"] = "Thick Outline"}
        local outlineValueMap = {["None"] = "", ["Outline"] = "OUTLINE", ["Thick Outline"] = "THICKOUTLINE"}
        local outlineDD, outlineDDText = OneWoW_GUI:CreateDropdown(dsc, { width = 240, text = outlineDisplayMap[currentOutline] })
        OneWoW_GUI:AttachFilterMenu(outlineDD, outlineDDText, {
            searchable = false,
            buildItems = function()
                local items = {}
                for _, opt in ipairs(outlineOptions) do
                    table.insert(items, { text = opt, value = opt })
                end
                return items
            end,
            onSelect = function(value, text)
                outlineDDText:SetText(text)
                reg:SetOverlaySetting(featureId, "fontOutline", outlineValueMap[value])
                OneWoW.OverlayEngine:Refresh()
            end,
            getActiveValue = function()
                local cur = reg:GetOverlaySetting(featureId, "fontOutline") or "OUTLINE"
                return outlineDisplayMap[cur]
            end,
        })
        outlineDD:SetPoint("TOPLEFT",  dsc, "TOP",      20,  rightY)
        outlineDD:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, rightY)
        rightY = rightY - 26 - 10

        yOffset = math.min(yOffset, rightY)
        dsc:SetHeight(math.abs(yOffset) + 20)
        split.UpdateDetailThumb()
        return
    end

    local currentIcon = reg:GetOverlaySetting(featureId, "icon") or "VignetteEvent-SuperTracked"

    local previewContainer, RefreshPreview = CreateSlotPreview(dsc, featureId, reg)
    local rightY = yOffset

    local previewFrame = CreateFrame("Frame", nil, dsc)
    previewFrame:SetSize(20, 20)
    previewFrame:SetPoint("TOPLEFT", dsc, "TOP", 20, rightY)
    local previewTex = previewFrame:CreateTexture(nil, "ARTWORK")
    previewTex:SetAllPoints(previewFrame)
    OneWoW.OverlayIcons:ApplyToTexture(previewTex, currentIcon)

    local previewName = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    previewName:SetPoint("LEFT", previewFrame, "RIGHT", 6, 0)
    previewName:SetText(OneWoW.OverlayIcons:GetDisplayName(currentIcon))
    previewName:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    rightY = rightY - 24 - 6

    previewContainer:SetPoint("TOPLEFT", dsc, "TOP", 20, rightY)
    rightY = rightY - previewContainer:GetHeight() - 10

    local posLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    posLabel:SetPoint("TOPLEFT", dsc, "TOP", 20, rightY)
    posLabel:SetText(L["OVR_POSITION_LABEL"])
    posLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    rightY = rightY - posLabel:GetStringHeight() - 6

    local currentPos = reg:GetOverlaySetting(featureId, "position") or "TOPRIGHT"
    local posDropdown, posDropdownText = OneWoW_GUI:CreateDropdown(dsc, { width = 160, text = currentPos })
    OneWoW_GUI:AttachFilterMenu(posDropdown, posDropdownText, {
        searchable = false,
        buildItems = function()
            local items = {}
            for _, opt in ipairs(POSITIONS) do
                table.insert(items, { text = opt, value = opt })
            end
            return items
        end,
        onSelect = function(value, text)
            posDropdownText:SetText(text)
            reg:SetOverlaySetting(featureId, "position", value)
            RefreshPreview()
        end,
        getActiveValue = function() return reg:GetOverlaySetting(featureId, "position") end,
    })
    posDropdown:SetPoint("TOPLEFT",  dsc, "TOP",      20,  rightY)
    posDropdown:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, rightY)
    rightY = rightY - 26 - 10

    local scaleLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    scaleLabel:SetPoint("TOPLEFT", dsc, "TOP", 20, rightY)
    scaleLabel:SetText(L["OVR_SCALE_LABEL"])
    scaleLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    rightY = rightY - scaleLabel:GetStringHeight() - 6

    local currentScale = reg:GetOverlaySetting(featureId, "scale") or 1.0
    local scaleSlider  = OneWoW_GUI:CreateSlider(dsc, 0.5, 2.0, 0.1, currentScale, function(val)
        reg:SetOverlaySetting(featureId, "scale", val)
        RefreshPreview()
    end, 160)
    scaleSlider:SetPoint("TOPLEFT",  dsc, "TOP",      20,  rightY)
    scaleSlider:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, rightY)
    rightY = rightY - 36 - 10

    local alphaLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    alphaLabel:SetPoint("TOPLEFT", dsc, "TOP", 20, rightY)
    alphaLabel:SetText(L["OVR_ALPHA_LABEL"])
    alphaLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    rightY = rightY - alphaLabel:GetStringHeight() - 6

    local currentAlpha = reg:GetOverlaySetting(featureId, "alpha") or 1.0
    local alphaSlider  = OneWoW_GUI:CreateSlider(dsc, 0.1, 1.0, 0.1, currentAlpha, function(val)
        reg:SetOverlaySetting(featureId, "alpha", val)
        RefreshPreview()
    end, 160)
    alphaSlider:SetPoint("TOPLEFT",  dsc, "TOP",      20,  rightY)
    alphaSlider:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, rightY)
    rightY = rightY - 36 - 16

    local iconLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    iconLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    iconLabel:SetText(L["OVR_ICON_LABEL"])
    iconLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - 18 - 4

    local picker = CreateIconPicker(dsc, currentIcon, function(iconName)
        reg:SetOverlaySetting(featureId, "icon", iconName)
        OneWoW.OverlayIcons:ApplyToTexture(previewTex, iconName)
        previewName:SetText(OneWoW.OverlayIcons:GetDisplayName(iconName))
        RefreshPreview()
    end)
    picker:SetPoint("TOPLEFT",  dsc, "TOPLEFT", 12,  yOffset)
    picker:SetPoint("TOPRIGHT", dsc, "TOP",     -20, yOffset)
    yOffset = yOffset - picker:GetHeight() - 16

    yOffset = math.min(yOffset, rightY)

    local vendorCb = OneWoW_GUI:CreateCheckbox(nil, dsc, L["OVR_VENDOR_LABEL"])
    vendorCb:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    local vendorEnabled = reg:GetOverlaySetting(featureId, "applyToVendorItems") or false
    vendorCb:SetChecked(vendorEnabled)
    vendorCb:SetScript("OnClick", function(self)
        reg:SetOverlaySetting(featureId, "applyToVendorItems", self:GetChecked())
    end)
    yOffset = yOffset - 30

    local ahCb = OneWoW_GUI:CreateCheckbox(nil, dsc, L["OVR_AH_LABEL"])
    ahCb:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    local ahEnabled = reg:GetOverlaySetting(featureId, "applyToAuctionHouse") or false
    ahCb:SetChecked(ahEnabled)
    ahCb:SetScript("OnClick", function(self)
        reg:SetOverlaySetting(featureId, "applyToAuctionHouse", self:GetChecked())
    end)
    yOffset = yOffset - 30 - 10

    if featureId == "junk" or featureId == "protected" then
        local tooltipCb = OneWoW_GUI:CreateCheckbox(nil, dsc, L["OVR_TOOLTIP_LABEL"])
        tooltipCb:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
        tooltipCb:SetChecked(reg:GetOverlaySetting(featureId, "showInTooltip") ~= false)
        tooltipCb:SetScript("OnClick", function(self)
            reg:SetOverlaySetting(featureId, "showInTooltip", self:GetChecked())
        end)
        yOffset = yOffset - 30 - 10
    end

    dsc:SetHeight(math.abs(yOffset) + 20)
    GUI:ApplyFontToFrame(dsc)
    split.UpdateDetailThumb()
end

local function BuildFeatureList(split, tabName)
    local lsc = split.listScrollChild
    local features = OneWoW.SettingsFeatureRegistry:GetByTab(tabName)
    local selectedRow = nil
    local allRows = {}

    local function RenderRows(filterText)
        OneWoW_GUI:ClearFrame(lsc)
        selectedRow = nil
        allRows = {}
        local yOffset = -5
        local filter = (filterText or ""):lower()

        for _, feature in ipairs(features) do
            local displayName = L[feature.title] or feature.title
            if filter == "" or displayName:lower():find(filter, 1, true) then
                local capturedFeature = feature
                local isEnabled = OneWoW.SettingsFeatureRegistry:IsEnabled(tabName, feature.id)

                local row = OneWoW_GUI:CreateListRowBasic(lsc, {
                    height = 30,
                    label = displayName,
                    showDot = true,
                    dotEnabled = isEnabled,
                    onClick = function(self)
                        if selectedRow and selectedRow ~= self then
                            selectedRow:SetActive(false)
                        end
                        selectedRow = self
                        self:SetActive(true)
                        ShowOverlayDetail(split, capturedFeature, self)
                        if split.rightStatusText then
                            local fe = OneWoW.SettingsFeatureRegistry:IsEnabled("overlays", capturedFeature.id)
                            split.rightStatusText:SetText(displayName .. (fe and " (Enabled)" or " (Disabled)"))
                        end
                    end,
                })
                row:SetPoint("TOPLEFT", lsc, "TOPLEFT", 4, yOffset)
                row:SetPoint("TOPRIGHT", lsc, "TOPRIGHT", -4, yOffset)
                table.insert(allRows, row)
                yOffset = yOffset - 34
            end
        end

        lsc:SetHeight(math.abs(yOffset) + 10)
        if #allRows > 0 and not selectedRow then
            allRows[1]:Click()
        end
    end

    RenderRows("")

    if split.searchBox then
        split.searchBox:SetScript("OnTextChanged", function(self)
            local text = self:GetSearchText()
            RenderRows(text)
        end)
    end

    local enabledCount = 0
    for _, f in ipairs(features) do
        if OneWoW.SettingsFeatureRegistry:IsEnabled("overlays", f.id) then
            enabledCount = enabledCount + 1
        end
    end
    split.leftStatusText:SetText(string.format("Features: %d/%d", enabledCount, #features))
end

function GUI:CreateOverlaysTab(parent)
    local split = OneWoW_GUI:CreateSplitPanel(parent, { showSearch = true, searchPlaceholder = L["SEARCH_PLACEHOLDER"] or "Search..." })
    split.listTitle:SetText(L["OVERLAYS_LIST_TITLE"])
    split.detailTitle:SetText(L["OVERLAYS_DETAIL_TITLE"])

    C_Timer.After(0.1, function()
        BuildFeatureList(split, "overlays")
        GUI:ApplyFontToFrame(parent)
    end)
end
